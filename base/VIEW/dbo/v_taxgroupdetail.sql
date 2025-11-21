SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TaxGroupDetail] 
AS 
SELECT [TaxGroupKey]
, [TaxRateKey]
, [GLDistributionKey]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
FROM [TaxGroupDetail] (NOLOCK) 

GO