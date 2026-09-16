# Run a .sql file against the database and print the result. PowerShell version
# of scripts/query.sh, for running from a normal Windows terminal.
#
#   .\scripts\query.ps1 queries\ex1.sql
#   .\scripts\query.ps1 queries\ex1.sql | Tee-Object results\ex1.txt
#
# In PowerShell, `bash` resolves to WSL's bash, which has no access to Docker
# unless WSL integration is switched on in Docker Desktop. This script avoids
# bash entirely.

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$File
)

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path $File)) {
  Write-Error "no such file: $File"
  exit 2
}

# Read .env into a hashtable, skipping comments and blank lines.
$cfg = @{}
foreach ($line in Get-Content .env) {
  if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
  $k, $v = $line -split '=', 2
  $cfg[$k.Trim()] = $v.Trim()
}

# \timing is a psql meta-command, not a command-line flag, so it is prepended
# to the stream. The file is piped in because queries/ is not mounted into the
# container.
$sql = "\timing on`n" + (Get-Content $File -Raw)

$sql | docker compose exec -T -e "PGPASSWORD=$($cfg['POSTGRES_PASSWORD'])" db `
  psql -v ON_ERROR_STOP=1 -U $cfg['POSTGRES_USER'] -d $cfg['POSTGRES_DB']
