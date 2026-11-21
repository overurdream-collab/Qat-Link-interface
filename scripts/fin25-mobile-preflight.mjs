// Read-only diagnostic, executed inside the EXISTING OTP container.
// Never prints connection strings, keys, full phone numbers or message bodies.
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import pg from 'pg';

const report = {
  checkedAtUtc: new Date().toISOString(),
  flags: {
    OTP_ENABLED: process.env.OTP_ENABLED === 'true',
    FIN25_SMS_DISPATCH_ENABLED: process.env.FIN25_SMS_DISPATCH_ENABLED === 'true',
  },
  liveSmsTest: 'NOT_RUN',
  financialLogin: 'NOT_VERIFIED',
};
const pool = new pg.Pool({connectionString: process.env.DATABASE_URL,
  connectionTimeoutMillis: 5000, max: 1});
let client;
try {
  const source = await readFile('/app/src/fin25_otp_transport.mjs');
  report.otpSourceSha256 = createHash('sha256').update(source).digest('hex');
  client = await pool.connect();
  await client.query('BEGIN READ ONLY');
  await client.query("SET LOCAL statement_timeout = '5s'");
  report.devices = (await client.query(`
    SELECT device_id, status, last_seen_at,
      last_seen_at > now() - interval '90 seconds' AS heartbeat_recent
    FROM fin25_gateway_devices ORDER BY last_seen_at DESC NULLS LAST LIMIT 20
  `)).rows;
  report.queue = (await client.query(`
    SELECT j.status, count(*)::int AS count,
      count(*) FILTER (WHERE c.expires_at > now())::int AS unexpired,
      count(*) FILTER (WHERE j.status='leased' AND j.lease_until < now())::int AS uncertain_expired_leases
    FROM fin25_sms_jobs j JOIN fin25_otp_challenges c ON c.id=j.challenge_id
    GROUP BY j.status ORDER BY j.status
  `)).rows;
  report.latestJobs = (await client.query(`
    SELECT j.id AS job_id, j.challenge_id AS request_id, j.status,
      j.device_id, j.sim_slot, j.attempts, j.created_at, j.sent_at,
      c.expires_at, c.consumed_at IS NOT NULL AS otp_verified
    FROM fin25_sms_jobs j JOIN fin25_otp_challenges c ON c.id=j.challenge_id
    ORDER BY j.created_at DESC LIMIT 10
  `)).rows;
  await client.query('ROLLBACK');
  report.review = {
    activeDeviceWithRecentHeartbeat: report.devices.some(d => d.status === 'active' && d.heartbeat_recent),
    unexpiredPendingJobs: report.queue.find(q => q.status === 'pending')?.unexpired ?? 0,
    leasedJobs: report.queue.find(q => q.status === 'leased')?.count ?? 0,
    decision: 'READ_ONLY_SNAPSHOT_NOT_AUTHORIZATION_TO_SEND',
  };
  console.log(JSON.stringify(report, null, 2));
} catch {
  // pg errors can include connection information: expose no raw exception.
  console.error('FIN25_PREFLIGHT_FAILED: check container identity, schema and database access locally.');
  process.exitCode = 1;
} finally {
  if (client) { await client.query('ROLLBACK').catch(() => {}); client.release(); }
  await pool.end();
}
