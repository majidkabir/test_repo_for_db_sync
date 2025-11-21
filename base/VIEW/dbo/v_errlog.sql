SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ERRLOG] 
AS 
SELECT [LogDate]
, [UserId]
, [ErrorID]
, [SystemState]
, [Module]
, [ErrorText]
, [TrafficCop]
FROM [ERRLOG] (NOLOCK) 

GO