SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_BILLING_DETAIL_CUT] 
AS 
SELECT [StorerKey]
, [Sku]
, [Lot]
, [Qty]
, [EffectiveDate]
, [Flag]
, [TranType]
, [RunningTotal]
FROM [BILLING_DETAIL_CUT] (NOLOCK) 

GO