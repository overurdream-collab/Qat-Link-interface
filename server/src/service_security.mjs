// Shared startup and connection bounds for existing Identity/FIN25 services.
export function databaseTls(env, flag = 'PG_SSL') {
  if (env.NODE_ENV === 'production' && env[flag] !== 'true') {
    throw new Error(`Production requires ${flag}=true with certificate verification`);
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
