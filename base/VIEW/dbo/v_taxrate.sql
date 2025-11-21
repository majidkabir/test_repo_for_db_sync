SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TaxRate] 
AS 
SELECT [TaxRateKey]
, [TaxAuthority]
, [SupportFlag]
, [Rate]
, [ExternTaxRateKey]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
FROM [TaxRate] (NOLOCK) 

GO