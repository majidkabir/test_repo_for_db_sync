SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_Locbak] 
AS 
SELECT [Loc]
, [LocationType]
, [PutawayZone]
, [InventoryDate]
, [Adddate]
, [Addwho]
, [Editdate]
, [Editwho]
FROM [Locbak] (NOLOCK) 

GO