package com.mini.luaxplus;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.zip.CRC32;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * 在打包阶段把 resources.arsc 的资源包名改成成品包名。
 * 资源 ID 的 0x7f 命名空间不变，只替换资源表里的 128 字符包名。
 */
public final class ArscPackage {

    private static final int RES_TABLE_TYPE = 0x0002;
    private static final int RES_TABLE_PACKAGE_TYPE = 0x0200;
    private static final int PACKAGE_NAME_CHARS = 128;
    private static final int PACKAGE_NAME_BYTES = PACKAGE_NAME_CHARS * 2;

    private ArscPackage() {
    }

    public static void copyAndRename(InputStream input, OutputStream output, String packageName)
            throws IOException {
        byte[] data = readAll(input);
        rename(data, packageName);
        output.write(data);
    }

    /**
     * 以 STORED 方式写入 resources.arsc。资源表需要保持未压缩，
     * 否则部分安装器会把它当作不兼容包。
     */
    public static void writeStored(ZipOutputStream output, String entryName,
            InputStream input, String packageName) throws IOException {
        byte[] data = readAll(input);
        rename(data, packageName);

        CRC32 crc = new CRC32();
        crc.update(data, 0, data.length);

        ZipEntry entry = new ZipEntry(entryName);
        entry.setMethod(ZipEntry.STORED);
        entry.setSize(data.length);
        entry.setCompressedSize(data.length);
        entry.setCrc(crc.getValue());
        output.putNextEntry(entry);
        output.write(data);
        output.closeEntry();
    }

    public static void rename(byte[] data, String packageName) {
        if (packageName == null || packageName.length() == 0
                || packageName.length() > PACKAGE_NAME_CHARS) {
            throw new IllegalArgumentException("invalid package name");
        }
        if (data.length < 12 || readU16(data, 0) != RES_TABLE_TYPE) {
            throw new IllegalArgumentException("not a resources.arsc table");
        }

        int offset = 12;
        while (offset + 8 <= data.length) {
            int type = readU16(data, offset);
            int headerSize = readU16(data, offset + 2);
            int size = readU32(data, offset + 4);
            if (size <= 0 || headerSize < 8 || offset + size > data.length) {
                break;
            }
            if (type == RES_TABLE_PACKAGE_TYPE) {
                int nameOffset = offset + 12;
                if (nameOffset + PACKAGE_NAME_BYTES > data.length) {
                    throw new IllegalArgumentException("truncated package name");
                }
                byte[] encoded = packageName.getBytes(java.nio.charset.StandardCharsets.UTF_16LE);
                System.arraycopy(encoded, 0, data, nameOffset, encoded.length);
                java.util.Arrays.fill(data, nameOffset + encoded.length,
                        nameOffset + PACKAGE_NAME_BYTES, (byte) 0);
                return;
            }
            offset += size;
        }
        throw new IllegalArgumentException("package chunk not found");
    }

    private static byte[] readAll(InputStream input) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int count;
        while ((count = input.read(buffer)) > 0) {
            output.write(buffer, 0, count);
        }
        return output.toByteArray();
    }

    private static int readU16(byte[] data, int offset) {
        return (data[offset] & 0xff) | ((data[offset + 1] & 0xff) << 8);
    }

    private static int readU32(byte[] data, int offset) {
        return (data[offset] & 0xff)
                | ((data[offset + 1] & 0xff) << 8)
                | ((data[offset + 2] & 0xff) << 16)
                | ((data[offset + 3] & 0xff) << 24);
    }
}
