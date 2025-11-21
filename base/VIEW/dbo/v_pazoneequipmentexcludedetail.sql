SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PAZoneEquipmentExcludeDetail] 
AS 
SELECT [PutawayZone]
, [EquipmentProfileKey]
, [Descr]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [PAZoneEquipmentExcludeDetail] (NOLOCK) 

GO