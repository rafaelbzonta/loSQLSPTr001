# Registro da tarefa agendada de importação diária

$NomeTarefa  = "PrintTracker - Importacao Diaria"
$Descricao   = "Importa o CSV diario do Print Tracker para o SQL Server " + "(instancia loSQLS / banco loSQLSPTr001)"
$ScriptPS    = "C:\PrintTracker\scripts\importCSV.ps1"

$acao = New-ScheduledTaskAction `
    -Execute  "powershell.exe" `
    -Argument "-NonInteractive -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPS`""

$gatilho = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -RepetitionDuration (New-TimeSpan -Hours 24) `
    -Once `
    -At "00:00"

$config = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit        (New-TimeSpan -Minutes 30) `
    -RestartCount              2                          `
    -RestartInterval           (New-TimeSpan -Minutes 5)  `
    -StartWhenAvailable                                   `
    -RunOnlyIfNetworkAvailable:$false

Register-ScheduledTask `
    -TaskName    $NomeTarefa `
    -Description $Descricao  `
    -Action      $acao        `
    -Trigger     $gatilho     `
    -Settings    $config      `
    -User        "NT AUTHORITY\SYSTEM" `
    -RunLevel    Highest       `
    -Force
