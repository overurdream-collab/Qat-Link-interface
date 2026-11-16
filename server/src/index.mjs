import { Pool } from 'pg';
import { createVerifier } from './auth.mjs';
import { Fin08Store } from './store.mjs';
import { createApi } from './http.mjs';

const required=['DATABASE_URL','AUTH_PUBLIC_KEY_PEM','AUTH_ISSUER','AUTH_AUDIENCE','CURSOR_SECRET'];
for(const name of required) if(!process.env[name]) throw new Error(`Missing required configuration: ${name}`);
const pool=new Pool({connectionString:process.env.DATABASE_URL,ssl:process.env.PG_SSL==='true'?{rejectUnauthorized:true}:undefined,max:10});
const verify=createVerifier({
  publicKey:process.env.AUTH_PUBLIC_KEY_PEM.replace(/\\n/g,'\n'),
  issuer:process.env.AUTH_ISSUER,
  audience:process.env.AUTH_AUDIENCE
});
const api=createApi({store:new Fin08Store(pool,{cursorSecret:process.env.CURSOR_SECRET}),verify});
const port=Number(process.env.PORT??8080);
if(!Number.isInteger(port)||port<1||port>65535) throw new Error('PORT must be valid');
api.listen(port,()=>console.info(`FIN08 backend listening on :${port} (authenticated requests only)`));
const shutdown=()=>{api.close(()=>pool.end());};
process.on('SIGTERM',shutdown);process.on('SIGINT',shutdown);