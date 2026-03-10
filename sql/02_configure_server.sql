-- Configuração da instância para suporte ao BULK INSERT
USE master;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

-- Habilita consultas distribuídas ad hoc, valor 1 = habilitado | Valor 0 = desabilitado (padrão)
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO
