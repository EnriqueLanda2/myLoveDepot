export function databaseSsl(databaseUrl: string) {
  if (databaseUrl.includes('localhost') || databaseUrl.includes('127.0.0.1')) {
    return undefined;
  }

  const encodedCa = process.env.DATABASE_CA_CERT_BASE64;
  if (!encodedCa) {
    throw new Error(
      'Falta DATABASE_CA_CERT_BASE64 para verificar el certificado TLS de MySQL',
    );
  }

  return {
    rejectUnauthorized: true,
    ca: Buffer.from(encodedCa, 'base64').toString('utf8'),
  };
}
