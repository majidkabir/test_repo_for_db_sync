SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TaskManagerUserDetail] 
AS 
SELECT [UserKey]
, [UserLineNumber]
, [PermissionType]
, [AreaKey]
, [Permission]
, [Descr]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [TaskManagerUserDetail] (NOLOCK) 

GO