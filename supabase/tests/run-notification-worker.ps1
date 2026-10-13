param([switch]$Watch)
# Local-only trusted dispatcher. Credentials remain in memory; never echo status.
# No Firebase identity means inbox collection only, no attempted FCM send.
$ErrorActionPreference = 'Stop'
try {
  $ErrorActionPreference = 'Continue'
  $raw = & npx.cmd --yes supabase@2.119.0 status -o json 2>$null
  $statusCode = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($statusCode -ne 0) { throw 'Local runtime unavailable' }
  $state = ($raw -join "`n") | ConvertFrom-Json
  if ($state.API_URL -ne 'http://127.0.0.1:55321') { throw 'Unexpected target' }
  do {
    $result = Invoke-RestMethod -Method Post -Uri "$($state.API_URL)/functions/v1/push-dispatch" -Headers @{
      Authorization = "Bearer $($state.SERVICE_ROLE_KEY)"
    } -ContentType 'application/json' -Body '{}' -TimeoutSec 90
    if (-not $result.ok) { throw 'Worker failed' }
    Write-Output "Collected=$($result.collected); finished=$($result.finished); push=$($result.push)"
    if ($Watch) { Start-Sleep -Seconds 15 }
  } while ($Watch)
} catch {
  Write-Output 'Local notification worker failed; sensitive request/response details suppressed.'
  exit 1
} finally { $state=$null; $raw=$null }
exit 0
