# loSQLSPTr001

![SQL Server](https://img.shields.io/badge/SQL%20Server-Express%202022-CC2927?logo=microsoftsqlserver&logoColor=white)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2025-0078D4?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE?logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

Pipeline de automação para importação diária de dados do **Print Tracker** no **SQL Server Express**, com instância dedicada, deduplicação automática, log de execução mensal e suporte a consultas externas.

---

## Índice


- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Scripts SQL — O que cada um faz](#scripts-sql--o-que-cada-um-faz)
- [Scripts PowerShell — O que cada um faz](#scripts-powershell--o-que-cada-um-faz)
- [Fluxo da Automação Diária](#fluxo-da-automação-diária)
- [Integrações Externas](#integrações-externas)
- [Troubleshooting](#troubleshooting)
- [Licença](#licença)

---

## Visão Geral


O **Print Tracker** exporta diariamente um arquivo `001.csv` contendo todas as impressoras que ficaram offline por mais de 72 horas. O CSV tem 11 colunas: `Entity`, `Make`, `Model`, `Serial Number`, `Asset ID`, `IP Address`, `Mac Address`, `Created`, `Check-in`, `Offline` e `Link`.

Este pipeline automatiza o ciclo completo: recebe o CSV, importa os dados para o SQL Server, elimina duplicatas e disponibiliza tudo para consultas e dashboards externos — sem intervenção manual.

---


## Arquitetura

```
Windows Server 2025
│
├── SQL Server Express 2025
│   └── Instância: loSQLS                  ← dedicada a este projeto
│       └── Banco: loSQLSPTr001
│           └── Tabela: dbo.OfflinePrinters
│               ├── Índice: IX_Serial      ← deduplicação e buscas por serial
│               ├── Índice: IX_Entity      ← filtros e GROUP BY por cliente
│               └── Índice: IX_Offline     ← ordenação por criticidade (DESC)
│
├── C:\PrintTracker\
│   ├── incoming\    ← deposite o 001.csv aqui todo dia
│   ├── import\      ← cópia de trabalho lida pelo BULK INSERT
│   ├── logs\        ← log mensal (import_YYYY-MM.log)
│   ├── sql\         ← scripts SQL (01 ao 07)
│   └── scripts\     ← scripts PowerShell
│
└── Windows Task Scheduler
    └── "PrintTracker - Importacao Diaria"
        └── Diariamente às 08:30 — NT AUTHORITY\SYSTEM
```

---


## Pré-requisitos

| Componente | Versão | Observação |
|---|---|---|
| Windows Server | 2025 | — |
| SQL Server Express | 2025 | Instância nomeada `loSQLS` |
| `sqlcmd` | — | Incluído no SQL Server |
| PowerShell | 5.1+ | Nativo no Windows Server 2025 |
| ODBC Driver for SQL Server | 13 ou 18 | Apenas nas máquinas clientes |

---


## Estrutura do Projeto

```
loSQLSPTr001/
│
├── sql/
│   ├── 01_create_database.sql       ← cria o banco loSQLSPTr001
│   ├── 02_configure_server.sql      ← habilita Ad Hoc Distributed Queries
│   ├── 03_create_table.sql          ← tabela + 3 índices de performance
│   ├── 04_import_csv.sql            ← importação diária (staging → insert)
│   ├── 05_queries.sql               ← consultas analíticas Q1–Q7
│   ├── 06_maintenance.sql           ← purge, tamanho, rebuild, diagnóstico
│   └── 07_create_readonly_user.sql  ← usuário de leitura para integração externa
│
├── scripts/
│   ├── Import-PrintTracker.ps1      ← automação diária da importação
│   └── Register-ScheduledTask.ps1   ← registra a tarefa no Task Scheduler
│
└── README.md
```

---


## Scripts SQL — O que cada um faz

### `01_create_database.sql`
Cria o banco `loSQLSPTr001` do zero na instância `loSQLS`.

### `02_configure_server.sql`
Habilita `Ad Hoc Distributed Queries` via `sp_configure`. Execução única, requer `sysadmin`. Sem esse passo, o `BULK INSERT` retorna o erro `Cannot obtain the required interface (IID_IColumnsInfo)`.

### `03_create_table.sql`
Cria `dbo.OfflinePrinters` com 14 colunas: 11 vindas do CSV e 3 de controle interno (`ID`, `ImportedAt`, `SourceFile`). Idempotente — verifica existência antes de criar. Ao final, cria três índices non-clustered para acelerar as operações mais frequentes.

**Esquema completo da tabela:**

| Coluna | Tipo | Origem | Descrição |
|---|---|---|---|
| `ID` | `INT IDENTITY` | Automático | Chave primária auto-incrementada |
| `Entity` | `NVARCHAR(255)` | CSV | Cliente ou localidade |
| `Make` | `NVARCHAR(100)` | CSV | Fabricante |
| `Model` | `NVARCHAR(100)` | CSV | Modelo do equipamento |
| `SerialNumber` | `NVARCHAR(100)` | CSV | Número de série — chave anti-duplicata |
| `AssetID` | `NVARCHAR(100)` | CSV | Patrimônio interno |
| `IPAddress` | `NVARCHAR(50)` | CSV | Endereço IP |
| `MacAddress` | `NVARCHAR(50)` | CSV | Endereço MAC |
| `Created` | `DATETIME2` | CSV | Data de cadastro no Print Tracker |
| `CheckIn` | `DATETIME2` | CSV | Último contato — chave anti-duplicata |
| `Offline` | `INT` | CSV | Dias offline (`"3 days"` → `3`) |
| `Link` | `NVARCHAR(1000)` | CSV | URL direta no Print Tracker |
| `ImportedAt` | `DATETIME2` | Automático | Timestamp UTC da importação |
| `SourceFile` | `NVARCHAR(260)` | Script | Nome do arquivo CSV de origem |

**Índices criados:**

| Nome | Coluna | Por que existe |
|---|---|---|
| `PK_OfflinePrinters` | `ID` | Acesso direto por ID (clustered) |
| `IX_Serial` | `SerialNumber` | Deduplicação e buscas pontuais |
| `IX_Entity` | `Entity` | Filtros e GROUP BY por cliente |
| `IX_Offline` | `Offline DESC` | Ordenação por criticidade |

### `04_import_csv.sql`
Script de importação diária em 4 etapas: criação do `#Staging` → `BULK INSERT` → `INSERT com deduplicação` → `DROP`. As transformações aplicadas na etapa de INSERT são: `LTRIM/RTRIM` em todos os textos, `TRY_CAST` para datas (retorna `NULL` em vez de erro se o formato for inválido), e `REPLACE('days','') + TRY_CAST AS INT` para extrair o número de dias offline.

> **Atenção ao `ROWTERMINATOR`:** o valor `'0x0a'` corresponde ao caractere LF, padrão em arquivos gerados no Linux e pela maioria das exportações web. Se o CSV usar CRLF (gerado no Windows Notepad, por exemplo), troque para `'0x0d0a'`.

### `05_queries.sql`

| Query | Descrição | Quando usar |
|---|---|---|
| Q1 | Espelho exato do CSV | Validação pós-importação |
| Q2 | Impressoras por criticidade | Triagem diária de suporte |
| Q3 | Resumo por cliente (total, min, max, média) | Relatórios gerenciais |
| Q4 | Filtro por `@Dias` (parâmetro ajustável) | Alertas por SLA |
| Q5 | Histórico completo de um serial | Diagnóstico de falha recorrente |
| Q6 | Auditoria de importações por arquivo e data | Monitoramento de operação |
| Q7 | Registros das últimas 24h | Confirmação pós-importação |

### `06_maintenance.sql`

| Script | Descrição | Frequência recomendada |
|---|---|---|
| M1 | Remove registros com mais de 90 dias (`@DiasRetencao` ajustável) | Mensal |
| M2 | Exibe tamanho da tabela em linhas e MB | Sob demanda |
| M3 | Rebuild de todos os índices (elimina fragmentação) | Mensal, após M1 |
| M4 | Detecta duplicatas por `SerialNumber + CheckIn` | Sob demanda / diagnóstico |

### `07_create_readonly_user.sql`
Cria o login `user001` na instância `loSQLS` com `SELECT` exclusivo em `dbo.OfflinePrinters`. Idempotente — verifica existência separadamente no nível de servidor (login) e no nível de banco (usuário). A senha de placeholder **deve ser trocada** antes de executar em produção.

---


## Scripts PowerShell — O que cada um faz

### `Import-PrintTracker.ps1`

| Etapa | O que acontece |
|---|---|
| 1 | Garante a existência de todas as 5 subpastas necessárias |
| 2 | Verifica `001.csv` em `incoming\` — encerra com `exit 1` se ausente |
| 3 | Copia para `import\`, substituindo o arquivo anterior |
| 4 | Localiza `sqlcmd.exe` em 5 caminhos padrão + fallback via `$PATH` |
| 5 | Executa `04_import_csv.sql` na instância `loSQLS` via sqlcmd |
| 6 | Registra toda a saída no log mensal com níveis INFO / WARN / ERROR |

**Flags do sqlcmd utilizadas:**

| Flag | Por que está aqui |
|---|---|
| `-E` | Autenticação Windows — usa a conta NT AUTHORITY\SYSTEM, sem senha |
| `-b` | Retorna exit code ≠ 0 se o SQL falhar — sem isso o erro passaria silencioso |
| `-No` | Desabilita criptografia obrigatória — Express usa certificado auto-assinado |
| `-C` | Confia no certificado auto-assinado do SQL Server |

**Códigos de saída:**

| Código | Significado |
|---|---|
| `0` | Sucesso completo |
| `1` | CSV não encontrado em `incoming\` |
| `2` | `sqlcmd.exe` não localizado |
| `3` | sqlcmd executou mas o SQL retornou erro |
| `99` | Exceção inesperada no PowerShell |

**Exemplo de log bem-sucedido:**
```
[2026-03-04 06:00:01] [INFO] === Iniciando importação diária do Print Tracker ===
[2026-03-04 06:00:01] [INFO] Instância : localhost\loSQLS
[2026-03-04 06:00:01] [INFO] Banco     : loSQLSPTr001
[2026-03-04 06:00:02] [INFO] Arquivo encontrado: C:\PrintTracker\incoming\001.csv
[2026-03-04 06:00:02] [INFO] Arquivo copiado para: C:\PrintTracker\import\001.csv
[2026-03-04 06:00:02] [INFO] sqlcmd localizado: C:\Program Files\...\sqlcmd.exe
[2026-03-04 06:00:02] [INFO] Executando script SQL: C:\PrintTracker\sql\04_import_csv.sql
[2026-03-04 06:00:03] [INFO]   [SQL] LinhasCarregadasNaStaging: 142
[2026-03-04 06:00:03] [INFO]   [SQL] RegistrosNovosInseridos: 38
[2026-03-04 06:00:03] [INFO] Importação concluída com sucesso.
[2026-03-04 06:00:03] [INFO] === Finalizado ===
```

### `Register-ScheduledTask.ps1`

Registra a tarefa no Windows Task Scheduler. Deve ser executado uma única vez como Administrador.

| Parâmetro | Valor configurado |
|---|---|
| Nome | `PrintTracker - Importacao Diaria` |
| Execução | Diariamente às 06:00 |
| Conta | `NT AUTHORITY\SYSTEM` |
| Timeout | 30 minutos |
| Retry | 2 tentativas, intervalo de 5 minutos |
| StartWhenAvailable | Sim — executa se o horário foi perdido |
| RequiresNetwork | Não — SQL é local |

---


## Fluxo da Automação Diária

```
06:00 — Task Scheduler dispara Import-PrintTracker.ps1
               ↓
   Verifica 001.csv em C:\PrintTracker\incoming\
               ↓
   Copia para C:\PrintTracker\import\
               ↓
   Executa 04_import_csv.sql via sqlcmd
   instância loSQLS | banco loSQLSPTr001
               ↓
   #Staging ← BULK INSERT ← 001.csv
               ↓
   INSERT INTO OfflinePrinters
   (com limpeza + conversão + deduplicação)
               ↓
   DROP TABLE #Staging
               ↓
   Log salvo em C:\PrintTracker\logs\import_YYYY-MM.log
```

---


## Integrações Externas

 **Abra **Fontes de Dados ODBC (64 bits)** (`odbcad32.exe`), acesse a aba **DSN do Sistema**, clique em **Adicionar** e selecione **ODBC Driver 18 for SQL Server**. Preencha com servidor `IP_DO_SERVIDOR\loSQLS,1434`, autenticação SQL com `user001` e senha, banco padrão `loSQLSPTr001`. Em configurações avançadas, defina `TrustServerCertificate = Yes`.**

**Query recomendada:**
```sql
SELECT
    Entity        AS Cliente,
    Make          AS Marca,
    Model         AS Modelo,
    SerialNumber  AS Serial,
    AssetID       AS Patrimonio,
    IPAddress     AS IP,
    MacAddress    AS MAC,
    Created       AS Criado,
    CheckIn       AS UltimoContato,
    Offline       AS DiasOffline,
    Link          AS LinkPrintTracker
FROM loSQLSPTr001.dbo.OfflinePrinters
ORDER BY Offline DESC
```

**String de conexão JDBC:**
```
jdbc:sqlserver://IP_DO_SERVIDOR:1434;databaseName=loSQLSPTr001;
user=user001;password=SuaSenha;
encrypt=true;trustServerCertificate=true
```

---


## Troubleshooting

| Erro / Sintoma | Causa | Solução |
|---|---|---|
| `Cannot obtain the required interface (IID_IColumnsInfo)` | Ad Hoc Distributed Queries desabilitado | Execute `02_configure_server.sql` como sysadmin na instância `loSQLS` |
| `SSL certificate chain issued by untrusted authority` | ODBC Driver 18 exige certificado válido por padrão | Use `-No -C` no sqlcmd ou `TrustServerCertificate=Yes` na string de conexão |
| `Login failed for user 'user001'` | Modo misto desabilitado na instância | Habilite **SQL Server and Windows Authentication** nas propriedades da instância `loSQLS` no SSMS |
| `Password validation failed` | Senha não atende à política de complexidade | Use senha com maiúsculas, minúsculas, números e símbolos (ex: `PrintReader@2025!`) |
| `Nome da fonte de dados não encontrado` no ODBC | Driver ausente na máquina cliente | Instale o [ODBC Driver 18](https://aka.ms/downloadmsodbcsql) na máquina de destino |
| Power BI não conecta remotamente | TCP/IP desabilitado ou porta bloqueada | Habilite TCP/IP para `loSQLS` no SQL Server Configuration Manager, porta 1434, e libere no firewall |
| `Offline = NULL` após importação | Formato inesperado no campo do CSV | Consulte o `#Staging` antes da conversão em `04_import_csv.sql` para ver o valor bruto |
| `RegistrosNovosInseridos = 0` | CSV igual ao do dia anterior ou importado duas vezes | Comportamento esperado quando não há registros novos — não é erro |
| Instância `loSQLS` não encontrada | Serviço parado ou TCP/IP desabilitado | Verifique no SQL Server Configuration Manager se `SQL Server (loSQLS)` está rodando |
| Tarefa agendada não executa | Script bloqueado pela ExecutionPolicy | O `Register-ScheduledTask.ps1` já configura `-ExecutionPolicy Bypass` — verifique se foi registrado corretamente |

**Formato esperado do CSV:**
```
Entity,Make,Model,Serial Number,Asset ID,IP Address,Mac Address,Created,Check-in,Offline,Link
CLIENTE A,Ricoh,MP 2014,ABC123,PAT001,192.168.1.10,AA:BB:CC:DD:EE:FF,2025-01-15,2026-02-28,3 days,https://app.printtracker.com/...
```

---


## Licença

MIT — livre para uso e modificação.
