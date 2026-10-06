# Only the disposable local Phase 3/4 project. No cloud target or real account.
# Run from the repository root after db reset and pgTAP checks.
$ErrorActionPreference = 'Stop'
$container = 'supabase_db_peksen_gida_phase3_local'
$oldHashes = $null
$testExit = 1
function Invoke-LocalSql([string]$sql) {
  $result = $sql | docker exec -i $container psql -U postgres -d postgres -X -q -t -A -v ON_ERROR_STOP=1 2>$null
  if ($LASTEXITCODE -ne 0) { throw 'Local SQL check failed (details suppressed).' }
  return $result
}
try {
  # CLI output can contain credentials. Capture it, never print it.
  # CLI emits harmless disabled-service warnings on stderr in Windows PowerShell.
  $ErrorActionPreference = 'Continue'
  $statusText = & npx.cmd --yes supabase@2.119.0 status -o json 2>$null
  $ErrorActionPreference = 'Stop'
  if ($LASTEXITCODE -ne 0) { throw 'Local Supabase is not running.' }
  $status = ($statusText -join "`n") | ConvertFrom-Json
  if ($status.API_URL -ne 'http://127.0.0.1:55321') { throw 'Unexpected local target.' }
  $fixtureCount = Invoke-LocalSql "select count(*) from auth.users where id::text like '30000000-0000-4000-8000-00000000000_' and email like '%@peksen.invalid';"
  if ([int]$fixtureCount -ne 8) { throw 'Reset the synthetic local seed first.' }
  $oldHashes = Invoke-LocalSql "select id::text || '|' || encrypted_password from auth.users where id::text like '30000000-0000-4000-8000-00000000000_' and email like '%@peksen.invalid' order by id;"
  $randomInput = [Guid]::NewGuid().ToString() + [Guid]::NewGuid().ToString()
  $null = Invoke-LocalSql "update auth.users set encrypted_password=extensions.crypt('$randomInput',extensions.gen_salt('bf')) where id::text like '30000000-0000-4000-8000-00000000000_' and email like '%@peksen.invalid';"
  $env:PEKSEN_AUTH_TEST_URL = $status.API_URL
  $env:PEKSEN_AUTH_TEST_KEY = $status.ANON_KEY
  $env:PEKSEN_AUTH_TEST_INPUT = $randomInput
  & flutter test supabase/tests/client/auth_session_test.dart --reporter expanded
  $testExit = $LASTEXITCODE
} catch {
  # Never render exception request bodies/headers or generated credentials.
  Write-Output 'Local auth check could not complete. Inspect runtime/seed prerequisites; sensitive details suppressed.'
  $testExit = 1
} finally {
  foreach ($variable in 'PEKSEN_AUTH_TEST_URL','PEKSEN_AUTH_TEST_KEY','PEKSEN_AUTH_TEST_INPUT') {
    Remove-Item -LiteralPath "Env:$variable" -ErrorAction SilentlyContinue
  }
  if ($oldHashes) {
    try {
      foreach ($row in $oldHashes) {
        $parts = $row.Split('|',2)
        if ($parts[0] -notmatch '^30000000-0000-4000-8000-00000000000[1-8]$') { throw 'Unexpected fixture.' }
        $hashLiteral = $parts[1].Replace("'", "''")
        $null = Invoke-LocalSql "update auth.users set encrypted_password='$hashLiteral' where id='$($parts[0])';"
      }
      Write-Output 'Synthetic credential hashes restored; no credentials written to files.'
    } catch {
      Write-Output 'Fixture restoration failed. Run db reset --local before continuing.'
      $testExit = 1
    }
  }
}
Write-Output "EXIT_CODE: $testExit"
exit $testExit
