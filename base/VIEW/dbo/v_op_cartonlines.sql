SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_OP_CARTONLINES] 
AS 
SELECT [Cartonbatch]
, [PickDetailKey]
, [PickHeaderKey]
, [OrderKey]
, [OrderLineNumber]
, [Storerkey]
, [Sku]
, [Loc]
, [lot]
, [id]
, [caseid]
, [uom]
, [uomqty]
, [qty]
, [packkey]
, [cartongroup]
, [cartontype]
, [DoReplenish]
, [ReplenishZone]
, [DoCartonize]
, [PickMethod]
, [EffectiveDate]
, [Archivecop]
FROM [OP_CARTONLINES] (NOLOCK) 

GO