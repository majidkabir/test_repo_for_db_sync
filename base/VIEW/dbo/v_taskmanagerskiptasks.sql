SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TaskManagerSkipTasks] 
AS 
SELECT [USERID]
, [TaskDetailKey]
, [TaskType]
, [Caseid]
, [Lot]
, [FromLoc]
, [ToLoc]
, [FromId]
, [ToId]
, [adddate]
FROM [TaskManagerSkipTasks] (NOLOCK) 

GO