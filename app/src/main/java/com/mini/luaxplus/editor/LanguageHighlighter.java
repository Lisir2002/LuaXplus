package com.mini.luaxplus.editor;

import b.b.a.b.h;

/**
 * 轻量多语言高亮规则。
 *
 * 运行时编辑器的高亮器按词法扫描，只内置了 Lua 规则。这里沿用同一套扫描器，
 * 按文件类型提供关键字、内建名、行注释和块注释边界，不替换编辑器本身。
 */
public class LanguageHighlighter extends h {
    private final String id;
    private final String lineComment;
    private final String blockStart;
    private final String blockEnd;
    private final boolean singleQuote;
    private final boolean doubleQuote;
    private final boolean backtick;

    public LanguageHighlighter(String language) {
        id = normalize(language);
        String[] keywords = new String[0];
        String[] builtins = new String[0];
        String line = null;
        String start = null;
        String end = null;
        boolean single = true;
        boolean doub = true;
        boolean tick = false;

        if ("java".equals(id)) {
            keywords = words("abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public record return sealed short static strictfp super switch synchronized this throw throws transient try var void volatile while yield true false null permits non-sealed");
            builtins = words("String Object System Math Integer Long Double Float Boolean Character Byte Short Void List Map Set ArrayList HashMap HashSet LinkedList TreeMap TreeSet Optional Stream Collections Arrays Objects StringBuilder StringBuffer Thread Runnable Exception RuntimeException Throwable Error Class Method Field Constructor Package Module Record Enum Iterable Iterator Comparator");
            line = "//"; start = "/*"; end = "*/";
        } else if ("kotlin".equals(id)) {
            keywords = words("as break class continue do else false for fun if in interface is null object package return super this throw true try typealias typeof val var when while by catch constructor delegate dynamic field file finally get import init param property receiver set setparam where actual abstract annotation companion const crossinline data enum expect external final infix inline inner internal lateinit noinline open operator out override private protected public reified sealed suspend tailrec vararg it");
            builtins = words("String Int Long Double Float Boolean Char Short Byte Any Unit Nothing List MutableList Map MutableMap Set MutableSet Array IntArray LongArray DoubleArray FloatArray BooleanArray Pair Triple Sequence Flow Result Lazy Regex");
            line = "//"; start = "/*"; end = "*/";
        } else if ("javascript".equals(id) || "typescript".equals(id)) {
            keywords = words("as async await break case catch class const continue debugger default delete do else enum export extends false finally for from function get if implements import in instanceof interface let new null of package private protected public readonly return set static super switch this throw true try type typeof undefined var void while with yield abstract any boolean constructor declare infer is keyof module namespace never number object override require string symbol unique unknown satisfies");
            builtins = words("Array ArrayBuffer Boolean DataView Date Error EvalError Function Infinity JSON Map Math NaN Number Object Promise Proxy RangeError ReferenceError Reflect RegExp Set String Symbol SyntaxError TypeError URIError WeakMap WeakSet console document window globalThis Intl BigInt parseInt parseFloat isNaN isFinite encodeURI decodeURI setTimeout clearTimeout setInterval clearInterval");
            line = "//"; start = "/*"; end = "*/"; tick = true;
        } else if ("python".equals(id)) {
            keywords = words("False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case");
            builtins = words("abs all any ascii bin bool bytearray bytes callable chr classmethod compile complex delattr dict dir divmod enumerate eval exec filter float format frozenset getattr globals hasattr hash help hex id input int isinstance issubclass iter len list locals map max memoryview min next object oct open ord pow print property range repr reversed round set setattr slice sorted staticmethod str sum super tuple type vars zip __import__ self cls");
            line = "#"; single = true; doub = true;
        } else if ("c".equals(id) || "cpp".equals(id) || "objectivec".equals(id)) {
            keywords = words("auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while class namespace template typename public private protected virtual override final new delete this true false null nullptr constexpr decltype using throw try catch operator friend explicit mutable export import module concept requires co_await co_return co_yield");
            builtins = words("size_t ptrdiff_t int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t std string vector map set list deque array pair make_pair unique_ptr shared_ptr weak_ptr cout cin cerr endl printf malloc free memcpy memset strlen strcmp");
            line = "//"; start = "/*"; end = "*/";
        } else if ("csharp".equals(id)) {
            keywords = words("abstract as base bool break byte case catch char checked class const continue decimal default delegate do double else enum event explicit extern false finally fixed float for foreach goto if implicit in int interface internal is lock long namespace new null object operator out override params private protected public readonly ref return sbyte sealed short sizeof stackalloc static string struct switch this throw true try typeof uint ulong unchecked unsafe ushort using var virtual void volatile while async await record init required");
            builtins = words("String Object Boolean Byte Char Int16 Int32 Int64 UInt16 UInt32 UInt64 Single Double Decimal DateTime TimeSpan Guid List Dictionary HashSet IEnumerable IList ICollection Task Action Func Exception Console Math Convert");
            line = "//"; start = "/*"; end = "*/";
        } else if ("go".equals(id)) {
            keywords = words("break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var true false nil iota");
            builtins = words("bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr any comparable make new len cap append copy delete panic recover print println close complex real imag");
            line = "//"; start = "/*"; end = "*/"; tick = true;
        } else if ("rust".equals(id)) {
            keywords = words("as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while union macro_rules");
            builtins = words("i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str String Vec Option Result Box Rc Arc RefCell Cell HashMap HashSet BTreeMap BTreeSet Some None Ok Err println format vec panic assert");
            line = "//"; start = "/*"; end = "*/";
        } else if ("swift".equals(id)) {
            keywords = words("associatedtype class deinit enum extension fileprivate func import init inout internal let open operator private protocol public rethrows static struct subscript typealias var break case continue default defer do else fallthrough for guard if in repeat return switch where while as catch false is nil super self Self throw throws true try weak unowned lazy mutating override required convenience final indirect");
            builtins = words("String Int Double Float Bool Character Array Dictionary Set Optional Result Void Any AnyObject Error Codable Equatable Hashable Comparable Sequence Collection Range ClosedRange");
            line = "//"; start = "/*"; end = "*/"; tick = true;
        } else if ("php".equals(id)) {
            keywords = words("abstract and array as break callable case catch class clone const continue declare default die do echo else elseif empty enddeclare endfor endforeach endif endswitch endwhile eval exit extends final finally fn for foreach function global goto if implements include include_once instanceof insteadof interface isset list match namespace new or print private protected public readonly require require_once return static switch throw trait try unset use var while xor yield true false null");
            builtins = words("ArrayObject DateTime Exception Generator Iterator JsonSerializable Stringable Throwable Closure stdClass PDO mysqli strlen count array_map array_filter array_merge in_array sprintf printf var_dump print_r");
            line = "//"; start = "/*"; end = "*/"; single = true; doub = true;
        } else if ("ruby".equals(id)) {
            keywords = words("alias and begin break case class def defined do else elsif end ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield require require_relative attr_reader attr_writer attr_accessor include extend private protected public");
            builtins = words("Array Hash String Symbol Integer Float Range Regexp Proc Lambda Time File Dir IO Math Kernel Object Class Module Enumerable Comparable Struct Data puts print p lambda proc");
            line = "#"; tick = false;
        } else if ("shell".equals(id)) {
            keywords = words("if then else elif fi for while do done case esac function in select until time coproc true false export local readonly declare typeset unset shift return break continue source alias");
            builtins = words("echo printf read cd pwd ls cp mv rm mkdir rmdir touch cat head tail grep sed awk find xargs sort uniq wc chmod chown ps kill sleep test expr");
            line = "#";
        } else if ("sql".equals(id)) {
            keywords = words("add all alter and any as asc authorization backup begin between by case check column commit constraint create cross current_date current_time current_timestamp database default delete desc distinct drop else end escape except exists foreign from full grant group having in index inner insert intersect into is join key left like limit natural not null on or order outer primary procedure references right rollback select set table then to top transaction trigger union unique update user values view when where with");
            builtins = words("int integer smallint bigint decimal numeric float real char varchar text date time timestamp datetime boolean blob clob count sum avg min max abs round now coalesce isnull ifnull cast convert substring trim upper lower length");
            line = "--"; start = "/*"; end = "*/";
        } else if ("html".equals(id) || "xml".equals(id)) {
            keywords = words("html head body title meta link style script div span p a img ul ol li table thead tbody tr td th form input button select option textarea label header footer section article nav main aside h1 h2 h3 h4 h5 h6 pre code strong em b i br hr svg path g rect circle line polyline polygon text defs use symbol");
            builtins = words("id class style href src alt title type name value placeholder action method target rel lang charset content width height viewBox fill stroke xmlns");
            start = "<!--"; end = "-->"; single = false; doub = true;
        } else if ("css".equals(id)) {
            keywords = words("color background background-color background-image border border-radius margin padding width height min-width max-width min-height max-height display position top right bottom left z-index font font-size font-weight font-family line-height text-align text-decoration overflow opacity transform transition animation flex grid gap align-items justify-content box-shadow content cursor visibility white-space box-sizing");
            builtins = words("auto none inherit initial unset block inline inline-block flex grid absolute relative fixed sticky center left right top bottom middle solid dashed dotted hidden visible red blue green black white transparent rgba rgb hsl calc var important");
            start = "/*"; end = "*/";
        } else if ("json".equals(id)) {
            keywords = words("true false null");
            builtins = new String[0]; single = false; doub = true;
        } else if ("yaml".equals(id)) {
            keywords = words("true false null yes no on off");
            line = "#";
        } else if ("markdown".equals(id)) {
            keywords = words("true false null");
            line = "#";
        } else if ("groovy".equals(id)) {
            keywords = words("abstract as assert break case catch class const continue def default do else enum extends final finally for goto if implements import in instanceof interface native new package private protected public return static strictfp super switch synchronized this throw throws trait transient try var volatile while true false null");
            builtins = words("String Object Integer Long Double Float Boolean List Map Set ArrayList HashMap Closure Range File println print");
            line = "//"; start = "/*"; end = "*/";
        } else if ("dart".equals(id)) {
            keywords = words("abstract as assert async await break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for function get if implements import in interface is late library mixin new null on operator part required rethrow return set show static super switch sync this throw true try typedef var void while with yield");
            builtins = words("String int double num bool List Map Set Iterable Future Stream Object Function Duration DateTime RegExp Exception Error print");
            line = "//"; start = "/*"; end = "*/";
        } else if ("plain".equals(id)) {
            single = false; doub = false;
        } else {
            // 未知类型按纯文本处理，避免把普通文本误判成字符串或注释
            single = false; doub = false;
        }

        this.lineComment = line;
        this.blockStart = start;
        this.blockEnd = end;
        this.singleQuote = single;
        this.doubleQuote = doub;
        this.backtick = tick;

        A(keywords);
        B(builtins);
        C(new char[]{'(', ')', '{', '}', '.', ',', ';', '=', '+', '-', '/', '*', '&', '!', '|', ':', '[', ']', '<', '>', '?', '~', '%', '^'});
    }

    private static String normalize(String language) {
        if (language == null) return "plain";
        String value = language.trim().toLowerCase();
        if ("ts".equals(value) || "tsx".equals(value) || "jsx".equals(value) || "mjs".equals(value) || "cjs".equals(value)) {
            return "typescript";
        }
        if ("c++".equals(value) || "cc".equals(value) || "cxx".equals(value) || "hpp".equals(value)) return "cpp";
        if ("c#".equals(value) || "cs".equals(value)) return "csharp";
        if ("sh".equals(value) || "bash".equals(value) || "zsh".equals(value)) return "shell";
        if ("xml".equals(value) || "svg".equals(value) || "vue".equals(value) || "svelte".equals(value)) return "html";
        if ("scss".equals(value) || "less".equals(value)) return "css";
        if ("yml".equals(value)) return "yaml";
        if ("md".equals(value)) return "markdown";
        return value;
    }

    private static String[] words(String source) {
        if (source == null || source.length() == 0) return new String[0];
        return source.split("\\s+");
    }

    @Override
    public boolean n(char c) {
        return false;
    }

    @Override
    public boolean p(char first, char second) {
        if (lineComment == null) return false;
        if (lineComment.length() == 1) return first == lineComment.charAt(0);
        return first == lineComment.charAt(0) && second == lineComment.charAt(1);
    }

    @Override
    public boolean r(char first, char second) {
        if (blockStart == null) return false;
        if (blockStart.length() == 2) return first == blockStart.charAt(0) && second == blockStart.charAt(1);
        if (blockStart.length() == 4) return first == blockStart.charAt(0) && second == blockStart.charAt(1);
        return false;
    }

    @Override
    public boolean q(char first, char second) {
        if (blockEnd == null) return false;
        if (blockEnd.length() == 2) return first == blockEnd.charAt(0) && second == blockEnd.charAt(1);
        if (blockEnd.length() == 3) return first == blockEnd.charAt(1) && second == blockEnd.charAt(2);
        return false;
    }

    @Override
    public boolean j(char c) {
        return (doubleQuote && c == '"') || (backtick && c == '`');
    }

    @Override
    public boolean k(char c) {
        return singleQuote && c == '\'';
    }

    @Override
    public boolean l(char c) {
        return c == '\\';
    }

    @Override
    public boolean u() {
        return true;
    }
}
