import { execFileSync } from 'node:child_process';
import { randomBytes, X509Certificate } from 'node:crypto';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const directory = join(root, '.local', 'signing');
const keystore = join(directory, 'broget-release.p12');
const properties = join(root, 'android', 'key.properties');
if (existsSync(keystore) || existsSync(properties)) {
  if (!existsSync(keystore) || !existsSync(properties)) throw new Error('Signing files are incomplete. Restore the original files; do not generate a new identity.');
  console.log('Existing signing identity preserved.');
  process.exit(0);
}
mkdirSync(directory, { recursive: true });
const keytool = join(process.env.JAVA_HOME || 'C:/Program Files/Android/Android Studio/jbr', 'bin', 'keytool.exe');
const password = randomBytes(32).toString('hex');
const env = { ...process.env, BROGET_SIGNING_PASSWORD: password };
const args = ['-keystore', keystore, '-storepass:env', 'BROGET_SIGNING_PASSWORD'];
execFileSync(keytool, ['-genkeypair', ...args, '-storetype', 'PKCS12', '-alias', 'broget', '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000', '-dname', 'CN=BROGET Health AI', '-keypass:env', 'BROGET_SIGNING_PASSWORD'], { env, stdio: 'pipe' });
writeFileSync(properties, `storePassword=${password}\nkeyPassword=${password}\nkeyAlias=broget\nstoreFile=${keystore.replaceAll('\\', '/')}\n`, { mode: 0o600 });
const certificate = execFileSync(keytool, ['-exportcert', ...args, '-alias', 'broget', '-rfc'], { env, stdio: 'pipe' });
const x509 = new X509Certificate(certificate);
writeFileSync(join(directory, 'certificate.json'), JSON.stringify({ sha256: x509.fingerprint256, sha1: x509.fingerprint }, null, 2));
console.log('Created release signing identity in ignored .local/signing and android/key.properties. Back up both privately.');
console.log(`Release certificate SHA-256: ${x509.fingerprint256}`);
