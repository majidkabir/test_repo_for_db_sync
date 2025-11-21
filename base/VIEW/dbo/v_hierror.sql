SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_HIERROR] 
AS 
SELECT [HiErrorGroup]
, [ErrorText]
, [ErrorType]
, [SourceKey]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [TimeStamp]
FROM [HIERROR] (NOLOCK) 

GO