# Registro da tarefa agendada de importação diária

$NomeTarefa  = "PrintTracker - Importacao Diaria"
$Descricao   = "Importa o CSV diario do Print Tracker para o SQL Server " + "(instancia loSQLS / banco loSQLSPTr001)"
$ScriptPS    = "C:\PrintTracker\scripts\ScheduledTask.ps1"
$HorarioExec = "08:30"   # formato HH:mm — 24 horas

if (Get-ScheduledTask -TaskName $NomeTarefa -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $NomeTarefa -Confirm:$false
    Write-Host "[Registro] Tarefa anterior removida para recriação limpa."
}

$acao = New-ScheduledTaskAction `
    -Execute  "powershell.exe" `
    -Argument "-NonInteractive -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPS`""

$gatilho = New-ScheduledTaskTrigger `
    -Daily `
    -At $HorarioExec

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

Write-Host ""
Write-Host "[Registro] Tarefa '$NomeTarefa' registrada com sucesso."
Write-Host "[Registro] Execução: diariamente às $HorarioExec via NT AUTHORITY\SYSTEM"
Write-Host ""
Write-Host "Para testar agora (sem esperar às $HorarioExec):"
Write-Host "  Start-ScheduledTask -TaskName '$NomeTarefa'"
Write-Host ""
Write-Host "Para verificar o status:"
Write-Host "  Get-ScheduledTask -TaskName '$NomeTarefa' | Select-Object TaskName, State"
Write-Host ""
Write-Host "Para ver o histórico de execuções (última linha = mais recente):"
Write-Host "  Get-Content 'C:\PrintTracker\logs\import_$(Get-Date -Format 'yyyy-MM').log' -Tail 20"
