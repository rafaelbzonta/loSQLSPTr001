-- Criação da tabela principal e dos índices de performance
USE loSQLSPTr001;
GO

    CREATE TABLE dbo.OfflinePrinters (

        ID              INT             IDENTITY(1,1)   NOT NULL,
        Entity          NVARCHAR(255)                   NULL,
        Make            NVARCHAR(100)                   NULL,      
        Model           NVARCHAR(100)                   NULL,       
        SerialNumber    NVARCHAR(100)                   NULL,
        AssetID         NVARCHAR(100)                   NULL,       
        IPAddress       NVARCHAR(50)                    NULL,       
        MacAddress      NVARCHAR(50)                    NULL,        
        Created         DATETIME2                       NULL,    
        CheckIn         DATETIME2                       NULL,        
        Offline         INT                             NULL,     
        Link            NVARCHAR(1000)                  NULL,      
        
		ImportedAt      DATETIME2       NOT NULL
                        CONSTRAINT DF_OfflinePrinters_ImportedAt
                            DEFAULT (SYSUTCDATETIME()),      
        
		SourceFile      NVARCHAR(260)                   NULL,
        
        CONSTRAINT PK_OfflinePrinters
            PRIMARY KEY CLUSTERED (ID)
    );

    CREATE NONCLUSTERED INDEX IX_Serial
        ON dbo.OfflinePrinters (SerialNumber);
  
    CREATE NONCLUSTERED INDEX IX_Entity
        ON dbo.OfflinePrinters (Entity);
    
    CREATE NONCLUSTERED INDEX IX_Offline
        ON dbo.OfflinePrinters (Offline DESC);

GO
