export function databaseSsl(databaseUrl: string) {
  if (databaseUrl.includes('localhost') || databaseUrl.includes('127.0.0.1')) {
    return undefined;
  }

  const encodedCa = process.env.DATABASE_CA_CERT_BASE64;
  
  if (!encodedCa) {
    // Si no hay CA personalizado (ej. TiDB Cloud usa certificados públicos), 
    // confiamos en los certificados raíz del sistema operativo.
    return {
      rejectUnauthorized: true,
    };
  }

  return {
    rejectUnauthorized: true,
    ca: Buffer.from(encodedCa, 'base64').toString('utf8'),
  };
}
