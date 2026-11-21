# Автотесты на копии учебной БП 3.0, два прогона: на типовых правилах обмена и с расширением из build.
# База восстанавливается из эталона до прогонов, между ними и после.
# Пример: tools\test.ps1 -Base C:\1C\BP_demo -Reference C:\1C\BP_ref\1Cv8.1CD -Build
param(
    [string]$Base = $env:BP_BASE,
    [string]$Reference = $env:BP_REFERENCE,
    [switch]$Build, [int]$TimeoutMin = 20,
    [string]$User = "Администратор",
    [string]$Platform = "C:\Program Files (x86)\1cv8t\8.5.1.1150\bin\1cv8t.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot
$name = "НоменклатураБезДублей"
$epf = "$root\tests\build\ТестыСопоставления.epf"
$cfe = "$root\build\$name.cfe"

$busy = @(Get-CimInstance Win32_Process -Filter "Name like '1cv8%'" | Where-Object { $_.CommandLine -like "*$Base*" })
if ($busy.Count) { "Закройте 1С с базой ${Base}: учебная версия пускает одно подключение к базе"; exit 1 }

function Invoke-Designer([string]$Command) {
    $log = Join-Path $env:TEMP ("designer_" + [guid]::NewGuid().ToString("N") + ".log")
    $argLine = "DESIGNER /F `"$Base`" /N `"$User`" /DisableStartupDialogs /DisableStartupMessages /Out `"$log`" $Command"
    $p = Start-Process $Platform -ArgumentList $argLine -PassThru
    $null = $p.Handle
    if (-not $p.WaitForExit(600000)) { Stop-Process -Id $p.Id -Force; throw "Конфигуратор не закрылся: $Command" }
    $text = if (Test-Path $log) { [IO.File]::ReadAllText($log).Trim() } else { "" }
    Remove-Item $log -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0) { throw "Конфигуратор вернул код $($p.ExitCode): $Command`n$text" }
}

# ОтключитьЛогикуНачалаРаботыСистемы: параметр БСП, без него учебная БП при старте показывает
# предложение обновить версию и стартовую страницу, и пакетный запуск ждёт ответа.
function Invoke-Tests([string]$Params) {
    $argLine = "ENTERPRISE /F `"$Base`" /N `"$User`" /DisableStartupDialogs /DisableStartupMessages /Execute `"$epf`" /C `"$Params;ОтключитьЛогикуНачалаРаботыСистемы`""
    $p = Start-Process $Platform -ArgumentList $argLine -PassThru
    if (-not $p.WaitForExit($TimeoutMin * 60000)) { Stop-Process -Id $p.Id -Force; Start-Sleep 2; "TIMEOUT" }
}

function Read-Report([string]$Path) {
    if (Test-Path $Path) { [IO.File]::ReadAllText($Path).Trim() } else { "НЕТ ОТЧЁТА: $Path" }
}

if ($Build) {
    Copy-Item $Reference "$Base\1Cv8.1CD" -Force
    & "$PSScriptRoot\build.ps1" -Base $Base -User $User -Platform $Platform
}

$withoutExt = "$root\tests\run_without_extension.txt"
$withExt = "$root\tests\run_with_extension.txt"
$prepare = "$root\tests\prepare.txt"
Remove-Item $withoutExt, $withExt, $prepare -ErrorAction SilentlyContinue
try {
    Copy-Item $Reference "$Base\1Cv8.1CD" -Force
    Invoke-Tests "Тесты;$root;$withoutExt"
    Invoke-Designer "/LoadCfg `"$cfe`" -Extension $name"
    Invoke-Designer "/UpdateDBCfg -Extension $name"
    Invoke-Tests "СнятьБезопасныйРежим;$prepare"
    Invoke-Tests "Тесты;$root;$withExt"
}
finally {
    Copy-Item $Reference "$Base\1Cv8.1CD" -Force
    "база восстановлена из эталона"
}

$report = (Read-Report $withoutExt) + "`r`n`r`n" + ("=" * 72) + "`r`n`r`n" + (Read-Report $withExt)
[IO.File]::WriteAllText("$root\tests\last_run.txt", $report, (New-Object Text.UTF8Encoding($true)))
Remove-Item $withoutExt, $withExt, $prepare -ErrorAction SilentlyContinue
$report
if (($report -split "`n" | Where-Object { $_ -match "не пройдено: [1-9]|НЕТ ОТЧЁТА|СБОЙ" }).Count) { exit 1 }
