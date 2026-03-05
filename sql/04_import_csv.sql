-- Importação diária do CSV para a tabela OfflinePrinters
USE loSQLSPTr001;
GO

IF OBJECT_ID('tempdb..#Staging') IS NOT NULL
    DROP TABLE #Staging;

CREATE TABLE #Staging (
    Entity          NVARCHAR(255)   COLLATE Latin1_General_CI_AI,
    Make            NVARCHAR(100)   COLLATE Latin1_General_CI_AI,
    Model           NVARCHAR(100)   COLLATE Latin1_General_CI_AI,
    SerialNumber    NVARCHAR(100)   COLLATE Latin1_General_CI_AI,
    AssetID         NVARCHAR(100)   COLLATE Latin1_General_CI_AI,
    IPAddress       NVARCHAR(50)    COLLATE Latin1_General_CI_AI,
    MacAddress      NVARCHAR(50)    COLLATE Latin1_General_CI_AI,
    Created         NVARCHAR(50)    COLLATE Latin1_General_CI_AI,
    CheckIn         NVARCHAR(50)    COLLATE Latin1_General_CI_AI,
    Offline         NVARCHAR(50)    COLLATE Latin1_General_CI_AI,
    Link            NVARCHAR(1000)  COLLATE Latin1_General_CI_AI
);
GO

BULK INSERT #Staging
FROM 'C:\PrintTracker\import\001.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    FIRSTROW        = 2,
    CODEPAGE        = '65001',
    TABLOCK
);
GO

SELECT COUNT(*) AS LinhasCarregadasNaStaging
FROM #Staging;
GO

INSERT INTO dbo.OfflinePrinters (
    Entity,
    Make,
    Model,
    SerialNumber,
    AssetID,
    IPAddress,
    MacAddress,
    Created,
    CheckIn,
    Offline,
    Link,
    SourceFile
)
SELECT
    -- Limpeza de espaços em todos os campos de texto
    LTRIM(RTRIM( s.Entity       )),
    LTRIM(RTRIM( s.Make         )),
    LTRIM(RTRIM( s.Model        )),
    LTRIM(RTRIM( s.SerialNumber )),
    LTRIM(RTRIM( s.AssetID      )),
    LTRIM(RTRIM( s.IPAddress    )),
    LTRIM(RTRIM( s.MacAddress   )),

    -- Conversão segura de data: retorna NULL se inválida
    TRY_CAST( LTRIM(RTRIM( s.Created )) AS DATETIME2 ),
    TRY_CAST( LTRIM(RTRIM( s.CheckIn )) AS DATETIME2 ),

    -- Extrai o número inteiro de "X days" ou "X day"
    TRY_CAST(
        LTRIM(RTRIM(
            REPLACE(
                REPLACE( s.Offline, 'days', '' ),   
            'day', '' )                            
        ))
    AS INT),

    LTRIM(RTRIM( s.Link )),

    -- Registra o nome do arquivo de origem para rastreabilidade
    '001.csv'

FROM #Staging AS s

-- Deduplicação: só insere se a combinação serial + check-in, ainda não existir na tabela principal
WHERE NOT EXISTS (
    SELECT 1
    FROM   dbo.OfflinePrinters AS p
    WHERE  p.SerialNumber = LTRIM(RTRIM( s.SerialNumber ))
      AND  p.CheckIn      = TRY_CAST( LTRIM(RTRIM( s.CheckIn )) AS DATETIME2 )
);
GO

SELECT COUNT(*) AS RegistrosNovosInseridos
FROM dbo.OfflinePrinters
WHERE ImportedAt >= DATEADD(MINUTE, -1, SYSUTCDATETIME());
GO

-- Remove a tabela temporária de staging

DROP TABLE #Staging;
GO

