package com.mini.luaxplus;

import android.content.Context;
import android.util.Log;

import com.android.apksig.ApkSigner;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Collections;

/**
 * 打包成品的签名入口。
 *
 * 内置打包组件只提供 v1 签名，目标系统版本较高的安装包会被系统判为不兼容，
 * 因此这里改用完整的 v1 + v2 + v3 方案，密钥沿用工程内置的测试密钥。
 */
public final class PackSigner {

    private static final String TAG = "PackSigner";
    private static final String KEY_ASSET = "keys/testkey.pk8";
    private static final String CERT_ASSET = "keys/testkey.x509.pem";
    private static final String CERT_ALIAS = "Mini-LuaXPLUS-Maker";

    private PackSigner() {
    }

    /** 签名 in 指向的 apk，产出 out；失败抛出异常由调用方回退。 */
    public static void sign(Context context, String in, String out) throws Exception {
        File input = new File(in);
        File output = new File(out);
        File staging = new File(output.getParentFile(), output.getName() + ".signing");
        if (staging.exists() && !staging.delete()) {
            throw new IOException("无法清理待签名文件 " + staging.getAbsolutePath());
        }

        // 先重排归档：资源表不压缩且四字节对齐，否则系统会判为不兼容
        File prepared = new File(output.getParentFile(), output.getName() + ".prepared");
        if (prepared.exists() && !prepared.delete()) {
            throw new IOException("无法清理整理产物 " + prepared.getAbsolutePath());
        }
        ApkPreparer.prepare(input, prepared);

        PrivateKey key = loadPrivateKey(context);
        X509Certificate cert = loadCertificate(context);

        ApkSigner.SignerConfig config = new ApkSigner.SignerConfig.Builder(
                CERT_ALIAS, key, Collections.singletonList(cert)).build();

        new ApkSigner.Builder(Collections.singletonList(config))
                .setInputApk(prepared)
                .setOutputApk(staging)
                .setV1SigningEnabled(true)
                .setV2SigningEnabled(true)
                .setV3SigningEnabled(true)
                .build()
                .sign();

        prepared.delete();
        if (output.exists() && !output.delete()) {
            throw new IOException("无法覆盖旧安装包 " + output.getAbsolutePath());
        }
        if (!staging.renameTo(output)) {
            throw new IOException("签名产物落位失败 " + output.getAbsolutePath());
        }
        Log.i(TAG, "打包签名完成，v1/v2/v3 已开启：" + output.getName()
                + " 大小=" + output.length());
    }

    private static PrivateKey loadPrivateKey(Context context) throws Exception {
        byte[] der = readAsset(context, KEY_ASSET);
        return KeyFactory.getInstance("RSA")
                .generatePrivate(new PKCS8EncodedKeySpec(der));
    }

    private static X509Certificate loadCertificate(Context context) throws Exception {
        try (InputStream stream = context.getAssets().open(CERT_ASSET)) {
            CertificateFactory factory = CertificateFactory.getInstance("X.509");
            return (X509Certificate) factory.generateCertificate(stream);
        }
    }

    private static byte[] readAsset(Context context, String name) throws IOException {
        try (InputStream stream = context.getAssets().open(name)) {
            byte[] buffer = new byte[stream.available() > 0 ? stream.available() : 8192];
            int offset = 0;
            int read;
            while ((read = stream.read(buffer, offset, buffer.length - offset)) > 0) {
                offset += read;
                if (offset == buffer.length) {
                    byte[] grown = new byte[buffer.length * 2];
                    System.arraycopy(buffer, 0, grown, 0, offset);
                    buffer = grown;
                }
            }
            byte[] result = new byte[offset];
            System.arraycopy(buffer, 0, result, 0, offset);
            return result;
        }
    }
}
