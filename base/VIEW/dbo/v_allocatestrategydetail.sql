SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_AllocateStrategyDetail] 
AS 
SELECT [AllocateStrategyKey]
, [AllocateStrategyLineNumber]
, [DESCR]
, [UOM]
, [PickCode]
, [LocationTypeOverride]
, [LocationTypeOverRideStripe]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [AllocateStrategyDetail] (NOLOCK) 

GO