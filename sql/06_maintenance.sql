-- Manutenção periódica do banco loSQLSPTr001

USE loSQLSPTr001;
GO


--  M1 — Purge: remoção de registros antigos
DECLARE @DiasRetencao INT = 90;   -- ← ajuste aqui o período de retenção

DELETE FROM dbo.OfflinePrinters
WHERE  ImportedAt < DATEADD(DAY, -@DiasRetencao, SYSUTCDATETIME());

PRINT CONCAT('[M1] Purge concluído. Registros removidos: ', @@ROWCOUNT);
GO


--  M2 — Tamanho atual da tabela
SELECT
    t.name                                                      AS Tabela,
    p.rows                                                      AS TotalLinhas,
    CAST( SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(10,2) )   AS TamanhoTotalMB,
    CAST( SUM(a.used_pages)  * 8.0 / 1024 AS DECIMAL(10,2) )   AS TamanhoUsadoMB
FROM   sys.tables           AS t
JOIN   sys.indexes          AS i
    ON t.object_id  = i.object_id
JOIN   sys.partitions       AS p
    ON i.object_id  = p.object_id
   AND i.index_id   = p.index_id
JOIN   sys.allocation_units AS a
    ON p.partition_id = a.container_id
WHERE  t.name = 'OfflinePrinters'
GROUP  BY t.name,
          p.rows;
GO


--  M3 — Rebuild de índices
ALTER INDEX ALL
    ON dbo.OfflinePrinters
    REBUILD;

PRINT '[M3] Rebuild de índices concluído.';
GO


--  M4 — Diagnóstico de duplicatas
SELECT
    SerialNumber,
    CheckIn,
    COUNT(*)    AS Ocorrencias
FROM   dbo.OfflinePrinters
GROUP  BY SerialNumber,
          CheckIn
HAVING COUNT(*) > 1
ORDER  BY Ocorrencias DESC;

-- Resultado esperado: 0 linhas retornadas.
-- Se retornar linhas, investigue antes de executar a próxima importação.
GO
