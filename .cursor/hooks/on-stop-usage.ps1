$ErrorActionPreference = "Stop"

function Out-Empty {
  [Console]::Out.WriteLine("{}")
}

function Read-TokenCount($payload, $name) {
  $prop = $payload.PSObject.Properties[$name]
  if ($null -eq $prop -or $null -eq $prop.Value -or [string]$prop.Value -eq "") {
    return $null
  }
  return [int64]$prop.Value
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
  $inputTokens = Read-TokenCount $payload "input_tokens"
  $outputTokens = Read-TokenCount $payload "output_tokens"
  $cacheRead = Read-TokenCount $payload "cache_read_tokens"
  $cacheWrite = Read-TokenCount $payload "cache_write_tokens"
  if ($null -eq $inputTokens -and $null -eq $outputTokens) { Out-Empty; exit 0 }

  $root = $env:CURSOR_PROJECT_DIR
  if ([string]::IsNullOrWhiteSpace($root)) {
    $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
  }
  $journal = Join-Path $root "journal\log.md"
  if (-not (Test-Path -LiteralPath $journal)) { Out-Empty; exit 0 }

  $utf8 = New-Object System.Text.UTF8Encoding $false
  $generation = [string]$payload.generation_id
  $seenPath = Join-Path $root ".cursor\cache\usage-ids.txt"
  if (-not [string]::IsNullOrWhiteSpace($generation) -and (Test-Path -LiteralPath $seenPath)) {
    $seen = [System.IO.File]::ReadAllLines($seenPath, $utf8)
    if ($seen -contains $generation) { Out-Empty; exit 0 }
  }

  $bits = New-Object System.Collections.Generic.List[string]
  if ($null -ne $inputTokens) { [void]$bits.Add("вход $inputTokens токенов (включая кэш)") }
  if ($null -ne $outputTokens) { [void]$bits.Add("выход $outputTokens токенов") }
  if ($null -ne $cacheRead) { [void]$bits.Add("чтение кэша $cacheRead токенов") }
  if ($null -ne $cacheWrite) { [void]$bits.Add("запись кэша $cacheWrite токенов") }

  $model = [string]$payload.model
  if ([string]::IsNullOrWhiteSpace($model)) { $model = "не названа" }
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $nl = "`n"
  $existing = [System.IO.File]::ReadAllText($journal, $utf8)
  if ($existing.Contains("`r`n")) { $nl = "`r`n" }

  $entry = @(
    "## $stamp расход"
    ""
    "Сделано: записан расход хода"
    "Расход: $($bits -join ', ')"
    "Основание: хук stop, модель $model"
    "Стоимость: не измерялась."
    ""
  ) -join $nl

  if ($existing.EndsWith($nl + $nl)) {
    $prefix = ""
  } elseif ($existing.EndsWith($nl)) {
    $prefix = $nl
  } else {
    $prefix = $nl + $nl
  }
  [System.IO.File]::AppendAllText($journal, ($prefix + $entry), $utf8)

  if (-not [string]::IsNullOrWhiteSpace($generation)) {
    $cacheDir = Split-Path $seenPath -Parent
    if (-not (Test-Path -LiteralPath $cacheDir)) {
      New-Item -ItemType Directory -Path $cacheDir | Out-Null
    }
    [System.IO.File]::AppendAllText($seenPath, $generation + $nl, $utf8)
  }

  Out-Empty
  exit 0
} catch {
  [Console]::Error.WriteLine($_.Exception.Message)
  Out-Empty
  exit 0
}
