# Controlled one-time SMS request for the isolated Android real-login pilot.
# Invoke from Windows PowerShell. NEVER expose /v1/auth/otp/request publicly.
$ErrorActionPreference='Stop'
$phone=(Read-Host 'Receiving Yemen phone (+967XXXXXXXXX)').Trim()
if($phone -cnotmatch '^\+967[0-9]{9}$'){throw 'Invalid Yemen phone number'}
$ok=Read-Host 'Send exactly ONE real SMS from FIN25? Enter YES'
if($ok -cne 'YES'){Write-Host 'CANCELLED: no SMS requested';return}
Write-Host '=== ONE FIN25 OTP REQUEST ==='
docker exec fin25-test-otp-1 node -e "fetch('http://127.0.0.1:8083/v1/auth/otp/request',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({phone:process.argv[1]})}).then(async r=>{let b=await r.json();console.log('HTTP='+r.status);if(r.status===202&&typeof b.requestId==='string'){console.log('REQUEST_ID='+b.requestId);console.log('EXPIRES_IN_SECONDS='+b.expiresInSeconds)}else{console.log('REQUEST_FAILED='+r.status)}if(!r.ok)process.exitCode=1}).catch(e=>{console.error('LOCAL_OTP_REQUEST_FAILED');process.exitCode=1})" $phone
if($LASTEXITCODE -ne 0){throw 'FIN25 OTP request failed. Do not automatically retry.'}
Write-Host 'Paste REQUEST_ID into the Android login pilot and type the SMS code ONLY into the phone app.'
