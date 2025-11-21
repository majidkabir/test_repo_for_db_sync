SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_CC] 
AS 
SELECT [CCKey]
, [Storerkey]
, [Sku]
, [Loc]
, [TaskDetailKey]
, [Status]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
, [Timestamp]
, [Facility]
FROM [CC] (NOLOCK) 

GO