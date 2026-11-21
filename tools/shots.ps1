# Снимки для README: что стало с номенклатурой БП после загрузки из УНФ без расширения и с расширением.
# Обработка тестов заводит товары бухгалтера, загружает сообщение tests\fixtures\ed_unf_items.xml
# и показывает таблицу с новыми и изменёнными товарами. База восстанавливается из эталона до, между и после.
# Пример: tools\shots.ps1 -Base C:\1C\BP_demo -Reference C:\1C\BP_ref\1Cv8.1CD
param(
    [string]$Base = $env:BP_BASE,
    [string]$Reference = $env:BP_REFERENCE,
    [string]$User = "Администратор",
    [string]$Platform = "C:\Program Files (x86)\1cv8t\8.5.1.1150\bin\1cv8t.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot
$name = "НоменклатураБезДублей"
$epf = "$root\tests\build\ТестыСопоставления.epf"
$busy = @(Get-CimInstance Win32_Process -Filter "Name like '1cv8%'" | Where-Object { $_.CommandLine -like "*$Base*" })
if ($busy.Count) { "Закройте 1С с базой ${Base}: учебная версия пускает одно подключение к базе"; exit 1 }
$common = "ENTERPRISE /F `"$Base`" /N `"$User`" /DisableStartupDialogs /DisableStartupMessages /Execute `"$epf`""

function Invoke-Designer([string]$Command) {
    $p = Start-Process $Platform -ArgumentList "DESIGNER /F `"$Base`" /N `"$User`" /DisableStartupDialogs /DisableStartupMessages $Command" -PassThru
    $null = $p.Handle
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw "Конфигуратор вернул код $($p.ExitCode): $Command" }
}

function Shot([string]$Out) {
    $p = Start-Process $Platform -ArgumentList "$common /C `"Показать;$root;ОтключитьЛогикуНачалаРаботыСистемы`"" -PassThru
    Start-Sleep 25
    & "$PSScriptRoot\capture.ps1" -Title "Бухгалтерия" -Out $Out -Width 1700 -Height 560 -ProcessId $p.Id
    Stop-Process -Id $p.Id -Force
    Start-Sleep 3
}

New-Item -ItemType Directory -Force "$root\screens" | Out-Null
try {
    Copy-Item $Reference "$Base\1Cv8.1CD" -Force
    Shot "$root\screens\1_bez_rasshireniya.png"
    Copy-Item $Reference "$Base\1Cv8.1CD" -Force
    Invoke-Designer "/LoadCfg `"$root\build\$name.cfe`" -Extension $name"
    Invoke-Designer "/UpdateDBCfg -Extension $name"
    $p = Start-Process $Platform -ArgumentList "$common /C `"СнятьБезопасныйРежим;$env:TEMP\shots_prepare.txt;ОтключитьЛогикуНачалаРаботыСистемы`"" -PassThru
    $p.WaitForExit(300000) | Out-Null
    Shot "$root\screens\2_s_rasshireniem.png"
}
finally {
    Copy-Item $Reference "$Base\1Cv8.1CD" -Force
    "база восстановлена из эталона"
}
