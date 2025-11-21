SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PutawayTask] 
AS 
SELECT [Transkey]
, [TaskDetailKey]
, [ID]
, [SKU]
, [FromLoc]
, [ToLoc]
, [Status]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
FROM [PutawayTask] (NOLOCK) 

GO