# Safe post-SMS login diagnosis. Aggregate counters only; no phone, OTP, JWT, proof or keys.
# No HTTP request and NO SMS generated.
param([ValidateRange(5,120)][int]$Minutes=60)
$ErrorActionPreference='Stop'
$otp='fin25-test-otp-1'
$identity='maqwati-identity-p0-identity-1'
function Inspect([string]$name){
 $raw=& docker inspect --format '{{.State.Status}}' $name
 if($LASTEXITCODE -ne 0){throw "Docker inspect failed for $name"}
 $state=($raw|Select-Object -Last 1).Trim()
 Write-Host "$name STATUS=$state"
 if($state -ne 'running'){throw "$name not running"}
}
Inspect $otp
Inspect $identity
$otpJs=@'
import pg from 'pg';
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL,connectionTimeoutMillis:3500,max:1});
try{
const minutes=Number(process.env.DIAG_MINUTES);
const q=await pool.query(
"SELECT count(*)::int AS requests, "+
"count(*) FILTER (WHERE c.consumed_at IS NOT NULL)::int AS otp_verified, "+
"count(*) FILTER (WHERE c.proof_redeemed_at IS NOT NULL)::int AS proof_redeemed_by_identity, "+
"count(*) FILTER (WHERE c.consumed_at IS NULL AND c.attempts>0)::int AS verification_failed_attempts, "+
"count(*) FILTER (WHERE c.consumed_at IS NOT NULL AND c.proof_redeemed_at IS NULL)::int AS verified_but_not_redeemed, "+
"count(*) FILTER (WHERE j.status IN ('sent','delivered'))::int AS sms_sent_ack, "+
"count(*) FILTER (WHERE j.status='failed')::int AS sms_failed, "+
"count(*) FILTER (WHERE j.status='leased')::int AS sms_leased, "+
"count(*) FILTER (WHERE j.status='pending')::int AS sms_pending "+
"FROM fin25_otp_challenges c LEFT JOIN fin25_sms_jobs j ON j.challenge_id=c.id "+
"WHERE c.created_at>=now()-($1::int * interval '1 minute')",[minutes]);
console.log('OTP_AGGREGATE='+JSON.stringify(q.rows[0]));
}catch(e){console.error('OTP_AGGREGATE=UNAVAILABLE ERROR_CATEGORY='+e.name);process.exitCode=1}
finally{await pool.end()}
'@
$identityJs=@'
import pg from 'pg';
const pool=new pg.Pool({connectionString:process.env.IDENTITY_DATABASE_URL,connectionTimeoutMillis:3500,max:1});
try{
const minutes=Number(process.env.DIAG_MINUTES);
const q=await pool.query(
"SELECT count(*) FILTER (WHERE created_at>=now()-($1::int * interval '1 minute'))::int AS registered_recently, "+
"count(*) FILTER (WHERE created_at>=now()-($1::int * interval '1 minute') AND finance_provisioned_at IS NULL)::int AS recent_finance_pending, "+
"count(*) FILTER (WHERE last_login_at>=now()-($1::int * interval '1 minute'))::int AS signed_in_recently, "+
"count(*) FILTER (WHERE finance_provisioned_at IS NULL)::int AS total_finance_pending FROM identity_accounts",[minutes]);
console.log('IDENTITY_AGGREGATE='+JSON.stringify(q.rows[0]));
}catch(e){console.error('IDENTITY_AGGREGATE=UNAVAILABLE ERROR_CATEGORY='+e.name);process.exitCode=1}
finally{await pool.end()}
'@
function RunCode([string]$name,[string]$script){
 $output=$script | & docker exec -i -e "DIAG_MINUTES=$Minutes" -w /app $name node --input-type=module -
 if($LASTEXITCODE -ne 0){throw "Read-only aggregate failed in $name (nothing changed)"}
 $output|ForEach-Object{Write-Host $_}
}
Write-Host "DIAGNOSTIC_WINDOW_MINUTES=$Minutes"
RunCode $otp $otpJs
RunCode $identity $identityJs
Write-Host 'SAFE_DIAGNOSIS=PASS NO_PHONE_OR_CODE_EXPOSED NO_SMS_CREATED NO_DATABASE_CHANGES'
