SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PreAllocatePickDetail] 
AS 
SELECT [PreAllocatePickDetailKey]
, [OrderKey]
, [OrderLineNumber]
, [Storerkey]
, [Sku]
, [Lot]
, [UOM]
, [UOMQty]
, [Qty]
, [Packkey]
, [WaveKey]
, [PreAllocateStrategyKey]
, [PreAllocatePickCode]
, [DoCartonize]
, [PickMethod]
, [RunKey]
, [EffectiveDate]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [PreAllocatePickDetail] (NOLOCK) 

GO