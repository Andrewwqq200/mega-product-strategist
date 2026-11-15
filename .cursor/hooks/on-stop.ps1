$ErrorActionPreference = "Stop"

function Out-Empty {
  [Console]::Out.WriteLine("{}")
}

try {
  $parts = New-Object System.Collections.Generic.List[string]
  foreach ($item in $input) {
    if ($null -ne $item) { [void]$parts.Add([string]$item) }
  }
  $raw = -join $parts
  if ([string]::IsNullOrWhiteSpace($raw) -and [Console]::IsInputRedirected) {
    $raw = [Console]::In.ReadToEnd()
  }
  if ([string]::IsNullOrWhiteSpace($raw)) { Out-Empty; exit 0 }

  $payload = $raw | ConvertFrom-Json
  if ([string]$payload.status -ne "aborted") { Out-Empty; exit 0 }

  $root = $env:CURSOR_PROJECT_DIR
  if ([string]::IsNullOrWhiteSpace($root)) {
    $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
  }
  $path = Join-Path $root "task\state.md"
  if (-not (Test-Path -LiteralPath $path)) { Out-Empty; exit 0 }

  $utf8 = New-Object System.Text.UTF8Encoding $false
  $text = [System.IO.File]::ReadAllText($path, $utf8)
  $lines = [regex]::Split($text, "\r?\n")
  if ($lines.Length -eq 0) { Out-Empty; exit 0 }
  $first = $lines[0].TrimStart([char]0xFEFF)
  if ($first -ne "Статус: в работе") { Out-Empty; exit 0 }

  $lines[0] = "Статус: остановлена"
  $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
  [System.IO.File]::WriteAllText($path, ($lines -join $nl), $utf8)
  Out-Empty
  exit 0
} catch {
  [Console]::Error.WriteLine($_.Exception.Message)
  Out-Empty
  exit 0
}
