package com.mini.luaxplus;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.Charset;
import java.util.zip.CRC32;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

/**
 * 打包成品的归档整理。
 *
 * 系统要求目标版本 30 以上的安装包把资源表以不压缩方式写入，并保持四字节对齐，
 * 否则会被判定为不兼容。这里在签名之前重排归档，顺便丢掉旧的签名文件。
 */
public final class ApkPreparer {

    private static final String RESOURCE_TABLE = "resources.arsc";

    private ApkPreparer() {
    }

    public static void prepare(File input, File output) throws IOException {
        ZipInputStream source = new ZipInputStream(
                new BufferedInputStream(new FileInputStream(input), 1 << 16));
        FileOutputStream fileOut = new FileOutputStream(output);
        BufferedOutputStream buffered = new BufferedOutputStream(fileOut, 1 << 16);
        ZipOutputStream target = new ZipOutputStream(buffered);

        try {
            ZipEntry entry = source.getNextEntry();
            while (entry != null) {
                String name = entry.getName();
                if (!shouldKeep(name)) {
                    source.closeEntry();
                    entry = source.getNextEntry();
                    continue;
                }
                if (entry.isDirectory()) {
                    source.closeEntry();
                    entry = source.getNextEntry();
                    continue;
                }

                byte[] data = readAll(source);
                source.closeEntry();

                if (RESOURCE_TABLE.equals(name)) {
                    writeAligned(target, buffered, fileOut, name, data);
                } else {
                    writeCompressed(target, name, data);
                }
                entry = source.getNextEntry();
            }
        } finally {
            try {
                target.close();
            } catch (IOException ignored) {
                // 关闭失败交由上层处理产物校验
            }
            source.close();
        }
    }

    private static boolean shouldKeep(String name) {
        if (name.startsWith("META-INF/")) {
            String upper = name.toUpperCase();
            if (upper.equals("META-INF/MANIFEST.MF")
                    || upper.endsWith(".SF")
                    || upper.endsWith(".RSA")
                    || upper.endsWith(".DSA")) {
                return false;
            }
        }
        return true;
    }

    private static void writeCompressed(ZipOutputStream target, String name, byte[] data)
            throws IOException {
        ZipEntry entry = new ZipEntry(name);
        entry.setMethod(ZipEntry.DEFLATED);
        target.putNextEntry(entry);
        target.write(data);
        target.closeEntry();
    }

    /** 资源表不压缩写入，并用额外字段补齐到四字节边界 */
    private static void writeAligned(ZipOutputStream target, OutputStream buffered,
                                     FileOutputStream fileOut, String name, byte[] data)
            throws IOException {
        target.flush();
        buffered.flush();
        long position = fileOut.getChannel().position();

        int nameLength = name.getBytes(Charset.forName("UTF-8")).length;
        long headerLength = 30L + nameLength;
        // 补齐字段本身占四个字节，因此按 4~7 字节补，保证内容仍是合法的附加信息结构
        int padding = 4 + (int) ((4L - ((position + headerLength + 4L) & 3L)) & 3L);

        CRC32 crc = new CRC32();
        crc.update(data);

        ZipEntry entry = new ZipEntry(name);
        entry.setMethod(ZipEntry.STORED);
        entry.setSize(data.length);
        entry.setCompressedSize(data.length);
        entry.setCrc(crc.getValue());
        entry.setExtra(alignmentExtra(padding));
        target.putNextEntry(entry);
        target.write(data);
        target.closeEntry();
    }

    /** 构造只用于占位的附加信息：标识 0xD935，内容为零字节 */
    private static byte[] alignmentExtra(int totalLength) {
        byte[] extra = new byte[totalLength];
        extra[0] = 0x35;
        extra[1] = (byte) 0xD9;
        int payload = totalLength - 4;
        extra[2] = (byte) (payload & 0xFF);
        extra[3] = (byte) ((payload >> 8) & 0xFF);
        return extra;
    }

    private static byte[] readAll(InputStream stream) throws IOException {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream(1 << 16);
        byte[] chunk = new byte[1 << 16];
        int read;
        while ((read = stream.read(chunk)) > 0) {
            buffer.write(chunk, 0, read);
        }
        return buffer.toByteArray();
    }
}
