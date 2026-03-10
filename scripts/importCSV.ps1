#  Automação da importação diária do Print Tracker
#
#  Instância  : loSQLS
#  Banco      : loSQLSPTr001
#
#    FLUXO DE EXECUÇÃO
#    1. Garante que todas as pastas necessárias existam
#    2. Verifica se 001.csv está disponível em incoming\
#    3. Copia o CSV para import\ (pasta lida pelo BULK INSERT)
#    4. Localiza o executável sqlcmd automaticamente
#    5. Executa 04_import_csv.sql via sqlcmd
#    6. Registra cada etapa no log mensal

#    LOG
#    C:\PrintTracker\logs\import_YYYY-MM.log
#    Um arquivo por mês — não cresce indefinidamente.

#    CÓDIGOS DE SAÍDA (exit codes)
#    0  → sucesso completo
#    1  → CSV não encontrado em incoming\
#    2  → sqlcmd não localizado no servidor
#    3  → sqlcmd executou mas o SQL retornou erro
#    99 → exceção inesperada no PowerShell

Set-StrictMode -Version Latest


$ErrorActionPreference = 'Stop'

$Servidor   = 'localhost\loSQLS'                        # instância SQL dedicada
$Banco      = 'loSQLSPTr001'                            # banco do projeto
$PastaBase  = 'C:\PrintTracker'                         # raiz do projeto em disco


$CSVOrigem  = Join-Path $PastaBase 'incoming\001.csv'   # onde o CSV chega
$CSVDestino = Join-Path $PastaBase 'import\001.csv'     # onde o BULK INSERT lê
$ScriptSQL  = Join-Path $PastaBase 'sql\04_import_csv.sql'
$PastaLogs  = Join-Path $PastaBase 'logs'

$LogArquivo = Join-Path $PastaLogs ("import_" + (Get-Date -Format 'yyyy-MM') + ".log")

function Write-Log {
    param(
        [string] $Mensagem,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string] $Nivel = 'INFO'   # padrão INFO quando não especificado
    )

    # Formato: [2026-03-04 06:00:01] [INFO] mensagem aqui
    $linha = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Nivel] $Mensagem"

    Write-Host   $linha              # exibe na tela (útil ao rodar manualmente)
    Add-Content -Path $LogArquivo `
                -Value $linha `
                -Encoding UTF8       # UTF-8 preserva acentos no log
}

try {

    Write-Log "=== Iniciando importação diária do Print Tracker ==="
    Write-Log "Instância : $Servidor"
    Write-Log "Banco     : $Banco"

    foreach ($subpasta in @('incoming', 'import', 'logs', 'sql', 'scripts')) {

        $caminho = Join-Path $PastaBase $subpasta

        if (-not (Test-Path $caminho)) {
            New-Item -ItemType Directory -Path $caminho -Force | Out-Null
            Write-Log "Pasta criada: $caminho"
        }

    }

    if (-not (Test-Path $CSVOrigem)) {
        Write-Log "Arquivo não encontrado: $CSVOrigem" 'WARN'
        Write-Log "Deposite o 001.csv em incoming\ e execute novamente." 'WARN'
        exit 1
    }

    Write-Log "Arquivo encontrado: $CSVOrigem"

    Copy-Item -Path $CSVOrigem -Destination $CSVDestino -Force
    Write-Log "Arquivo copiado para: $CSVDestino"

    $CaminhosSqlcmd = @(
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\160\Tools\Binn\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\150\Tools\Binn\sqlcmd.exe',
        'C:\Program Files\Microsoft SQL Server\140\Tools\Binn\sqlcmd.exe'
    )

    $sqlcmd = $CaminhosSqlcmd | Where-Object { Test-Path $_ } | Select-Object -First 1

    # Fallback: procura sqlcmd no PATH do sistema operacional
    if (-not $sqlcmd) {
        $sqlcmdObj = Get-Command sqlcmd -ErrorAction SilentlyContinue
        $sqlcmd    = if ($sqlcmdObj) { $sqlcmdObj.Source } else { $null }
    }

    if (-not $sqlcmd) {
        Write-Log "sqlcmd não encontrado. Verifique a instalação do SQL Server." 'ERROR'
        exit 2
    }

    Write-Log "sqlcmd localizado: $sqlcmd"

    Write-Log "Executando script SQL: $ScriptSQL"

    $saida = & $sqlcmd `
        -S $Servidor `
        -d $Banco    `
        -E           `
        -b           `
        -No          `
        -C           `
        -i $ScriptSQL 2>&1

    $saida | ForEach-Object { Write-Log "  [SQL] $_" }

    if ($LASTEXITCODE -ne 0) {
        Write-Log "sqlcmd encerrou com código de erro: $LASTEXITCODE" 'ERROR'
        exit 3
    }

    Write-Log "Importação concluída com sucesso."

} catch {

    Write-Log "EXCEÇÃO NÃO TRATADA: $($_.Exception.Message)" 'ERROR'
    exit 99

} finally {

    Write-Log "=== Finalizado ==="

}
