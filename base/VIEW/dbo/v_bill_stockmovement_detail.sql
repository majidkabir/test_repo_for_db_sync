SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_BILL_STOCKMOVEMENT_DETAIL] 
AS 
SELECT [StorerKey]
, [Company]
, [Sku]
, [Descr]
, [Lot]
, [Qty]
, [EffectiveDate]
, [Flag]
, [TranType]
, [RunningTotal]
, [record_number]
FROM [BILL_STOCKMOVEMENT_DETAIL] (NOLOCK) 

GO