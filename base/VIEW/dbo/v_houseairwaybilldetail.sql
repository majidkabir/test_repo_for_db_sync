SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_HOUSEAIRWAYBILLDETAIL] 
AS 
SELECT [HAWBKEY]
, [HAWBLineNumber]
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
FROM [HOUSEAIRWAYBILLDETAIL] (NOLOCK) 

GO