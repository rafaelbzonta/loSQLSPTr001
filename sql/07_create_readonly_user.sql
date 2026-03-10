-- Criação do usuário somente leitura para sistemas externos

--   Cria o LOGIN no servidor (instância loSQLS)
--   CHECK_POLICY = ON
--   CHECK_EXPIRATION = OFF


-- sys.server_principals lista todos os logins do servidor. Verificamos antes de criar para tornar o script idempotente.
USE master;
GO

IF NOT EXISTS (
    SELECT 1
    FROM   sys.server_principals
    WHERE  name = 'user001'
)
BEGIN

    CREATE LOGIN user001
    WITH PASSWORD        = 'TROQUE_ESTA_SENHA@2025!',   -- ← substitua aqui
         CHECK_POLICY     = ON,
         CHECK_EXPIRATION = OFF;

    PRINT '[07] Login user001 criado na instância loSQLS.';

END
ELSE
    PRINT '[07] Login user001 já existe no servidor — nenhuma alteração feita.';
GO

-- Criar o USUÁRIO no banco loSQLSPTr001
USE loSQLSPTr001;
GO

IF NOT EXISTS (
    SELECT 1
    FROM   sys.database_principals
    WHERE  name = 'user001'
)
BEGIN

    CREATE USER user001
        FOR LOGIN user001;

    PRINT '[07] Usuário user001 criado no banco loSQLSPTr001.';

END
ELSE
    PRINT '[07] Usuário user001 já existe no banco — nenhuma alteração feita.';
GO


-- Conceder permissão SELECT na tabela
GRANT SELECT
    ON dbo.OfflinePrinters
    TO user001;

PRINT '[07] Permissão SELECT concedida em dbo.OfflinePrinters para user001.';
PRINT '[07] Usuário pronto para Power BI, Soft Expert e demais sistemas externos.';
GO
