SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_BILLING_SUMMARY_CUT] 
AS 
SELECT [StorerKey]
, [Sku]
, [Lot]
, [Qty]
, [EffectiveDate]
, [Flag]
, [TranType]
, [RunningTotal]
, [AddWho]
FROM [BILLING_SUMMARY_CUT] (NOLOCK) 

GO