#include <android/log.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <unwind.h>
#include <dlfcn.h>
#include <jni.h>

#define TAG "CrashGuard"
#define MAX_FRAMES 64
#define MAX_DIRS 2
#define ALT_STACK_SIZE (64 * 1024)

static char g_log_dirs[MAX_DIRS][512];
static int g_log_dir_count = 0;
static char g_alt_stack[ALT_STACK_SIZE];
static struct sigaction g_old_actions[NSIG];
static volatile int g_handling = 0;

static const int FATAL_SIGNALS[] = {
        SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP
#ifdef SIGSYS
        , SIGSYS
#endif
};

struct BacktraceState {
    uintptr_t *frames;
    int count;
    int max;
};

static _Unwind_Reason_Code unwind_callback(struct _Unwind_Context *context, void *arg) {
    struct BacktraceState *state = (struct BacktraceState *) arg;
    uintptr_t ip = (uintptr_t) _Unwind_GetIP(context);
    if (ip != 0 && state->count < state->max) {
        state->frames[state->count++] = ip;
    }
    return _URC_NO_REASON;
}

static void append_text(int fd, const char *text) {
    if (text != NULL) {
        write(fd, text, strlen(text));
    }
}

static void signal_name(int sig, char *buffer, size_t size) {
    switch (sig) {
        case SIGABRT:
            snprintf(buffer, size, "SIGABRT(6)");
            break;
        case SIGSEGV:
            snprintf(buffer, size, "SIGSEGV(11)");
            break;
        case SIGBUS:
            snprintf(buffer, size, "SIGBUS(7)");
            break;
        case SIGILL:
            snprintf(buffer, size, "SIGILL(4)");
            break;
        case SIGFPE:
            snprintf(buffer, size, "SIGFPE(8)");
            break;
        case SIGTRAP:
            snprintf(buffer, size, "SIGTRAP(5)");
            break;
#ifdef SIGSYS
        case SIGSYS:
            snprintf(buffer, size, "SIGSYS(31)");
            break;
#endif
        default:
            snprintf(buffer, size, "SIG%d", sig);
            break;
    }
}

static void write_ready_to_dir(const char *dir) {
    char path[640];
    char line[256];
    int fd;
    mkdir(dir, 0771);
    snprintf(path, sizeof(path), "%s/native_guard_ready.log", dir);
    fd = open(path, O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd < 0) {
        return;
    }
    snprintf(line, sizeof(line), "时间: %ld\n进程: %d\n说明: 原生崩溃守卫已装载\n",
             (long) time(NULL), getpid());
    append_text(fd, line);
    close(fd);
}

static void crash_path(const char *dir, int sig, const char *when,
                       char *path, size_t size) {
    mkdir(dir, 0771);
    snprintf(path, size, "%s/native_crash_%s_%d_%d.log",
             dir, when, getpid(), sig);
}

static void write_crash_header_to_dir(const char *dir, int sig, siginfo_t *info,
                                      const char *name, const char *when) {
    char path[640];
    char line[256];
    int fd;

    crash_path(dir, sig, when, path, sizeof(path));
    fd = open(path, O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd < 0) {
        return;
    }

    snprintf(line, sizeof(line), "时间: %ld\n进程: %d\n线程: %d\n信号: %d (%s)\n",
             (long) time(NULL), getpid(), gettid(), sig, name);
    append_text(fd, line);
    if (info != NULL) {
        snprintf(line, sizeof(line), "信号码: %d\n出错地址: %p\n",
                 info->si_code, info->si_addr);
        append_text(fd, line);
    } else {
        append_text(fd, "信号码: unknown\n出错地址: unknown\n");
    }
    append_text(fd, "说明: 原生层致命信号，Java 未捕获异常处理器无法接管\n"
                    "调用栈: 处理中\n");
    close(fd);
    __android_log_print(ANDROID_LOG_FATAL, TAG, "fatal signal %s, log=%s", name, path);
}

static void append_crash_frames_to_dir(const char *dir, int sig, const char *when,
                                       uintptr_t *frames, int frame_count) {
    char path[640];
    char line[256];
    int fd;
    int index;

    crash_path(dir, sig, when, path, sizeof(path));
    fd = open(path, O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd < 0) {
        return;
    }

    append_text(fd, "调用栈(地址):\n");
    if (frame_count <= 0) {
        append_text(fd, "调用栈: 获取失败\n");
    } else {
        for (index = 0; index < frame_count; index++) {
            Dl_info info;
            if (dladdr((void *) frames[index], &info) != 0 && info.dli_fname != NULL) {
                unsigned long offset = (unsigned long) frames[index]
                        - (unsigned long) info.dli_fbase;
                snprintf(line, sizeof(line), "#%02d %p %s+0x%lx %s\n",
                         index, (void *) frames[index], info.dli_fname, offset,
                         info.dli_sname == NULL ? "?" : info.dli_sname);
            } else {
                snprintf(line, sizeof(line), "#%02d %p ?\n", index, (void *) frames[index]);
            }
            append_text(fd, line);
        }
    }
    close(fd);
}

static void write_crash_log(int sig, siginfo_t *info) {
    char name[32];
    char when[64];
    time_t now = time(NULL);
    struct tm local;
    uintptr_t frames[MAX_FRAMES];
    struct BacktraceState state;
    int index;

    signal_name(sig, name, sizeof(name));
    if (localtime_r(&now, &local) != NULL) {
        strftime(when, sizeof(when), "%Y%m%d_%H%M%S", &local);
    } else {
        snprintf(when, sizeof(when), "unknown_time");
    }

    // 先落最小快照，再尝试回溯；回溯本身异常也不能让崩溃文件丢失
    for (index = 0; index < g_log_dir_count; index++) {
        if (g_log_dirs[index][0] != '\0') {
            write_crash_header_to_dir(g_log_dirs[index], sig, info, name, when);
        }
    }

    state.frames = frames;
    state.count = 0;
    state.max = MAX_FRAMES;
    _Unwind_Backtrace(unwind_callback, &state);

    for (index = 0; index < g_log_dir_count; index++) {
        if (g_log_dirs[index][0] != '\0') {
            append_crash_frames_to_dir(g_log_dirs[index], sig, when,
                                       frames, state.count);
        }
    }
    if (g_log_dir_count == 0) {
        __android_log_print(ANDROID_LOG_FATAL, TAG,
                            "fatal signal %s but no writable log directory", name);
    }
}

static void crash_handler(int sig, siginfo_t *info, void *context) {
    (void) context;
    if (g_handling != 0) {
        signal(sig, SIG_DFL);
        raise(sig);
        return;
    }
    g_handling = 1;
    write_crash_log(sig, info);

    struct sigaction old = g_old_actions[sig];
    if (old.sa_flags & SA_SIGINFO) {
        sigaction(sig, &old, NULL);
    } else if (old.sa_handler != SIG_DFL && old.sa_handler != SIG_IGN) {
        sigaction(sig, &old, NULL);
    } else {
        signal(sig, SIG_DFL);
    }
    raise(sig);
}

static void set_dir(int index, JNIEnv *env, jstring value) {
    const char *text;
    if (env == NULL || value == NULL || index < 0 || index >= MAX_DIRS) {
        return;
    }
    text = (*env)->GetStringUTFChars(env, value, NULL);
    if (text == NULL) {
        return;
    }
    strncpy(g_log_dirs[index], text, sizeof(g_log_dirs[index]) - 1);
    g_log_dirs[index][sizeof(g_log_dirs[index]) - 1] = '\0';
    (*env)->ReleaseStringUTFChars(env, value, text);
}

JNIEXPORT void JNICALL
Java_com_mini_luaxplus_NativeCrashGuard_installNative(JNIEnv *env, jclass clazz,
                                                       jstring primary,
                                                       jstring secondary) {
    struct sigaction action;
    size_t index;
    static char alt_stack_ready = 0;

    (void) clazz;
    set_dir(0, env, primary);
    set_dir(1, env, secondary);
    g_log_dir_count = g_log_dirs[1][0] != '\0' ? 2 : (g_log_dirs[0][0] != '\0' ? 1 : 0);
    for (index = 0; index < (size_t) g_log_dir_count; index++) {
        if (g_log_dirs[index][0] != '\0') {
            write_ready_to_dir(g_log_dirs[index]);
        }
    }

    memset(&action, 0, sizeof(action));
    action.sa_sigaction = crash_handler;
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
    sigemptyset(&action.sa_mask);
    for (index = 0; index < sizeof(FATAL_SIGNALS) / sizeof(FATAL_SIGNALS[0]); index++) {
        int sig = FATAL_SIGNALS[index];
        sigaction(sig, &action, &g_old_actions[sig]);
    }

    if (!alt_stack_ready) {
        stack_t stack;
        memset(&stack, 0, sizeof(stack));
        stack.ss_sp = g_alt_stack;
        stack.ss_size = ALT_STACK_SIZE;
        stack.ss_flags = 0;
        sigaltstack(&stack, NULL);
        alt_stack_ready = 1;
    }
}
