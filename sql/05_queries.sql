--  Consultas analíticas para suporte, monitoramento e integração.

--            ||ÍNDICE DE CONSULTAS||
--            Q1 — Espelho do CSV: reproduz o arquivo original;
--            Q2 — Painel de criticidade: todas as impressoras por dias offline;
--            Q3 — Resumo por cliente: totais, mínimo, máximo e média;
--            Q4 — Alerta por limiar: impressoras acima de X dias offline;
--            Q5 — Histórico de serial: todo o histórico de uma impressora;
--            Q6 — Auditoria de importações: o que entrou, quando e de onde;
--            Q7 — Validação pós-importação: o que chegou nas últimas 24h;


USE loSQLSPTr001;
GO


-- Q1
SELECT
    Entity          AS [Entity],
    Make            AS [Make],
    Model           AS [Model],
    SerialNumber    AS [Serial Number],
    AssetID         AS [Asset ID],
    IPAddress       AS [IP Address],
    MacAddress      AS [Mac Address],
    Created         AS [Created],
    CheckIn         AS [Check-in],
    Offline         AS [Offline],
    Link            AS [Link]
FROM   dbo.OfflinePrinters
ORDER  BY ImportedAt DESC,   
          ID         ASC;    
GO


-- Q2
SELECT
    Entity          AS Cliente,
    Make            AS Marca,
    Model           AS Modelo,
    SerialNumber    AS Serial,
    IPAddress       AS IP,
    CheckIn         AS UltimoContato,
    Offline         AS DiasOffline
FROM   dbo.OfflinePrinters
ORDER  BY Offline DESC,
          Entity  ASC;
GO


-- Q3
SELECT
    Entity                                                      AS Cliente,
    COUNT(*)                                                    AS TotalImpressoras,
    MIN(Offline)                                                AS MinimoOffline,
    MAX(Offline)                                                AS MaximoOffline,
    CAST( AVG( CAST(Offline AS FLOAT) ) AS DECIMAL(10,1) )     AS MediaOffline
FROM   dbo.OfflinePrinters
GROUP  BY Entity
ORDER  BY MaximoOffline DESC;   -- clientes com pior situação primeiro
GO


-- Q4
DECLARE @Dias INT = 7;  -- ← ajuste aqui o limiar de dias

SELECT
    Entity          AS Cliente,
    Make            AS Marca,
    Model           AS Modelo,
    SerialNumber    AS Serial,
    IPAddress       AS IP,
    Offline         AS DiasOffline,
    Link            AS LinkPrintTracker
FROM   dbo.OfflinePrinters
WHERE  Offline > @Dias
ORDER  BY Offline DESC;
GO


-- Q5
DECLARE @Serial NVARCHAR(100) = 'SEU_SERIAL_AQUI';  -- ← substitua aqui

SELECT
    Entity,
    Make,
    Model,
    SerialNumber,
    IPAddress,
    CheckIn         AS UltimoContato,
    Offline         AS DiasOffline,
    Link,
    ImportedAt      AS ImportadoEm,
    SourceFile      AS ArquivoOrigem
FROM   dbo.OfflinePrinters
WHERE  SerialNumber = @Serial
ORDER  BY ImportedAt DESC;   
GO


-- Q6
SELECT
    SourceFile                          AS Arquivo,
    CAST(ImportedAt AS DATE)            AS DataImportacao,
    COUNT(*)                            AS TotalRegistros,
    MIN(ImportedAt)                     AS PrimeiraInsercao,
    MAX(ImportedAt)                     AS UltimaInsercao
FROM   dbo.OfflinePrinters
GROUP  BY SourceFile,
          CAST(ImportedAt AS DATE)
ORDER  BY DataImportacao DESC;   -- dias mais recentes primeiro
GO


-- Q7
SELECT
    Entity,
    Make,
    Model,
    SerialNumber,
    IPAddress,
    Offline         AS DiasOffline,
    ImportedAt      AS ImportadoEm
FROM   dbo.OfflinePrinters
WHERE  ImportedAt >= DATEADD(HOUR, -24, SYSUTCDATETIME())
ORDER  BY ImportedAt DESC;
GO
