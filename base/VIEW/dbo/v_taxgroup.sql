SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TaxGroup] 
AS 
SELECT [TaxGroupKey]
, [SupportFlag]
, [Descrip]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
FROM [TaxGroup] (NOLOCK) 

GO