SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_CC_Error] 
AS 
SELECT [StorerKey]
, [Sku]
, [Lot]
, [ID]
, [Loc]
, [Qty]
, [Remark]
, [AddDate]
FROM [CC_Error] (NOLOCK) 

GO