# Собирает расширение build\НоменклатураБезДублей.cfe и обработку тестов tests\build\ТестыСопоставления.epf
# из XML-исходников конфигуратором. Расширение при сборке загружается в базу, поэтому берите копию базы БП 3.0.
# Пример: tools\build.ps1 -Base C:\1C\BP_demo
param(
    [string]$Base = $env:BP_BASE,
    [string]$User = "Администратор",
    [int]$TimeoutSec = 600,
    [string]$Platform = "C:\Program Files (x86)\1cv8t\8.5.1.1150\bin\1cv8t.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot
$name = "НоменклатураБезДублей"

function Invoke-Designer([string]$Command) {
    $log = Join-Path $env:TEMP ("designer_" + [guid]::NewGuid().ToString("N") + ".log")
    $argLine = "DESIGNER /F `"$Base`" /N `"$User`" /DisableStartupDialogs /DisableStartupMessages /Out `"$log`" $Command"
    $p = Start-Process $Platform -ArgumentList $argLine -PassThru
    $null = $p.Handle   # без этого ExitCode у Start-Process -PassThru остаётся пустым
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        Stop-Process -Id $p.Id -Force
        throw "Конфигуратор не закрылся за $TimeoutSec с: $Command"
    }
    $text = if (Test-Path $log) { [IO.File]::ReadAllText($log).Trim() } else { "" }
    Remove-Item $log -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0) { throw "Конфигуратор вернул код $($p.ExitCode): $Command`n$text" }
    if ($text) { $text }
}

New-Item -ItemType Directory -Force "$root\build" | Out-Null
Invoke-Designer "/LoadConfigFromFiles `"$root\src\$name`" -Extension $name"
Invoke-Designer "/DumpCfg `"$root\build\$name.cfe`" -Extension $name"
"OK $root\build\$name.cfe " + (Get-Item "$root\build\$name.cfe").Length + " bytes"
& "$PSScriptRoot\build_epf.ps1" -Src "$root\tests\src\ТестыСопоставления.xml" -Out "$root\tests\build\ТестыСопоставления.epf" `
    -Base $Base -User $User -Platform $Platform | Select-Object -Last 1
