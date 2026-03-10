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

-- Remove registros cujo SerialNumber não existe mais no CSV. Impressoras que voltaram online deixam de aparecer na exportação do Print Tracker e devem sair do banco.
DELETE FROM dbo.OfflinePrinters
WHERE SerialNumber NOT IN (
    SELECT LTRIM(RTRIM(SerialNumber))
    FROM   #Staging
    WHERE  LTRIM(RTRIM(SerialNumber)) <> ''
);
GO

DECLARE @RegistrosDeletados INT = @@ROWCOUNT;
SELECT @RegistrosDeletados AS RegistrosRemovidosPorAusencia;
GO

MERGE dbo.OfflinePrinters AS Target
USING (
    SELECT
        LTRIM(RTRIM(Entity))                                            AS Entity,
        LTRIM(RTRIM(Make))                                              AS Make,
        LTRIM(RTRIM(Model))                                             AS Model,
        LTRIM(RTRIM(SerialNumber))                                      AS SerialNumber,
        LTRIM(RTRIM(AssetID))                                           AS AssetID,
        LTRIM(RTRIM(IPAddress))                                         AS IPAddress,
        LTRIM(RTRIM(MacAddress))                                        AS MacAddress,
        TRY_CAST(LTRIM(RTRIM(Created)) AS DATETIME2)                    AS Created,
        TRY_CAST(LTRIM(RTRIM(CheckIn)) AS DATETIME2)                    AS CheckIn,
        TRY_CAST(
            LTRIM(RTRIM(REPLACE(REPLACE(Offline, 'days', ''), 'day', '')))
            AS INT
        )                                                               AS Offline,
        LTRIM(RTRIM(Link))                                              AS Link
    FROM #Staging
    WHERE LTRIM(RTRIM(SerialNumber)) <> ''
) AS Source
ON Target.SerialNumber = Source.SerialNumber

WHEN MATCHED THEN
    UPDATE SET
        Target.Entity     = Source.Entity,
        Target.Make       = Source.Make,
        Target.Model      = Source.Model,
        Target.AssetID    = Source.AssetID,
        Target.IPAddress  = Source.IPAddress,
        Target.MacAddress = Source.MacAddress,
        Target.Created    = Source.Created,
        Target.CheckIn    = Source.CheckIn,
        Target.Offline    = Source.Offline,
        Target.Link       = Source.Link,
        Target.ImportedAt = GETUTCDATE(),
        Target.SourceFile = '001.csv'

WHEN NOT MATCHED BY TARGET THEN
    INSERT (
        Entity, Make, Model, SerialNumber, AssetID,
        IPAddress, MacAddress, Created, CheckIn,
        Offline, Link, ImportedAt, SourceFile
    )
    VALUES (
        Source.Entity, Source.Make, Source.Model, Source.SerialNumber,
        Source.AssetID, Source.IPAddress, Source.MacAddress,
        Source.Created, Source.CheckIn, Source.Offline, Source.Link,
        GETUTCDATE(), '001.csv'
    );
GO

SELECT COUNT(*) AS RegistrosNovosInseridos
FROM dbo.OfflinePrinters
WHERE ImportedAt >= DATEADD(MINUTE, -1, SYSUTCDATETIME());
GO

-- Remove a tabela temporária de staging
DROP TABLE #Staging;
GO

