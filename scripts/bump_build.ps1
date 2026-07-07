$pubspec = Join-Path $PSScriptRoot '..\pubspec.yaml'
$content = Get-Content -Raw -LiteralPath $pubspec

if ($content -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
  Write-Error 'Cannot find version: x.y.z+n in pubspec.yaml'
  exit 1
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = [int]$Matches[4] + 1
$next = "version: $major.$minor.$patch+$build"

$updated = [regex]::Replace(
  $content,
  '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$',
  $next,
  1
)

Set-Content -LiteralPath $pubspec -Value $updated -NoNewline
Write-Host "Bumped Flutter build number to $major.$minor.$patch+$build"
