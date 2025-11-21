SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_MASTERAIRWAYBILLDETAIL] 
AS 
SELECT [MAWBKEY]
, [MAWBLineNumber]
, [HAWBKEY]
, [NumberOfPieces]
, [GrossWeight]
, [UOMWeight]
, [RateClass]
, [Sku]
, [SkuDescription]
, [ChargeableWeight]
, [Rate]
, [Extension]
, [UOMVolume]
, [Length]
, [Width]
, [Height]
, [Notes]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
, [TimeStamp]
FROM [MASTERAIRWAYBILLDETAIL] (NOLOCK) 

GO