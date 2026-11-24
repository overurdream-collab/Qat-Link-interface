import { Pool } from 'pg';
import { createVerifier } from './auth.mjs';
import { Fin08Store } from './store.mjs';
import { createApi } from './http.mjs';
import { createRequestMonitor } from './monitoring.mjs';

const required=['DATABASE_URL','AUTH_PUBLIC_KEY_PEM','AUTH_ISSUER','AUTH_AUDIENCE','CURSOR_SECRET'];
for(const name of required) if(!process.env[name]) throw new Error(`Missing required configuration: ${name}`);
// Production must fail closed if the database connection could be plaintext.
// Private-network isolation alone does not substitute for authenticated TLS.
if (process.env.NODE_ENV === 'production' && process.env.PG_SSL !== 'true') {
  throw new Error('Production requires PG_SSL=true with certificate verification');
}
const pool=new Pool({connectionString:process.env.DATABASE_URL,ssl:process.env.PG_SSL==='true'?{rejectUnauthorized:true}:undefined,max:10,connectionTimeoutMillis:5000,query_timeout:10000,statement_timeout:10000});
const verify=createVerifier({
  publicKey:process.env.AUTH_PUBLIC_KEY_PEM.replace(/\\n/g,'\n'),
  issuer:process.env.AUTH_ISSUER,
  audience:process.env.AUTH_AUDIENCE
});
const monitor=createRequestMonitor();
const api=createApi({store:new Fin08Store(pool,{cursorSecret:process.env.CURSOR_SECRET}),verify,monitor,
  readiness:()=>pool.query('SELECT 1 FROM financial_movements LIMIT 0')});
// Internal stdout only: fixed-shape aggregate counters, no payloads or labels.
const metricsTimer=setInterval(()=>console.info(JSON.stringify({event:'api_metrics',...monitor.drain(),pool_total:pool.totalCount,pool_idle:pool.idleCount,pool_waiting:pool.waitingCount})),60000);
metricsTimer.unref();
const port=Number(process.env.PORT??8080);
if(!Number.isInteger(port)||port<1||port>65535) throw new Error('PORT must be valid');
// Listen on localhost by default; container/proxy deployments must opt in
// explicitly to wider bind addresses and restrict exposure at the firewall.
const bindHost = process.env.FIN08_BIND_HOST ?? '127.0.0.1';
if (!['127.0.0.1', '::1', '0.0.0.0', '::'].includes(bindHost)) {
  throw new Error('Invalid FIN08_BIND_HOST; use explicit allowed address');
}
if (['0.0.0.0', '::'].includes(bindHost) && process.env.FIN08_ALLOW_ANY_BIND !== 'true') {
  throw new Error('Non-local binding requires FIN08_ALLOW_ANY_BIND=true and a private firewall');
}
api.listen(port, bindHost, () => console.info(
  `FIN08 backend listening on ${bindHost}:${port} (authenticated requests only)`));
const shutdown=()=>{clearInterval(metricsTimer);api.close(()=>pool.end());};
process.on('SIGTERM',shutdown);process.on('SIGINT',shutdown);
