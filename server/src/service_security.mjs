// Shared startup and connection bounds for existing Identity/FIN25 services.
export function databaseTls(env, flag = 'PG_SSL', connectionString =
  flag === 'IDENTITY_PG_SSL' ? env.IDENTITY_DATABASE_URL : env.DATABASE_URL) {
  if (env.NODE_ENV === 'production' && env[flag] !== 'true') {
    throw new Error(`Production requires ${flag}=true with certificate verification`);
  }
  if (env[flag] === 'true' && connectionString !== undefined) {
    // node-postgres reparses connectionString after its explicit ssl option.
    // URL SSL parameters could otherwise disable TLS or certificate checks.
    let parsed;
    try {
      parsed = new URL(connectionString);
      if (!['postgres:', 'postgresql:'].includes(parsed.protocol)) throw new Error();
    } catch {
      throw new Error('A valid PostgreSQL URL is required for verified TLS');
    }
    for (const key of parsed.searchParams.keys()) {
      if (key.toLowerCase().startsWith('ssl') || key.toLowerCase() === 'uselibpqcompat') {
        // Never include the URL, parameter values, credentials, or query in errors.
        throw new Error('PostgreSQL URL TLS overrides are forbidden; use verified TLS configuration');
      }
    }
  }
  return env[flag] === 'true' ? {rejectUnauthorized:true} : undefined;
}
export function boundHttpServer(server) {
  server.headersTimeout = 10000;
  server.requestTimeout = 15000;
  server.keepAliveTimeout = 5000;
  server.maxRequestsPerSocket = 100;
  return server;
}
