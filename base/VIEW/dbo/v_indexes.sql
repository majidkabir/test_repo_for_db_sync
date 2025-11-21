SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_Indexes] 
AS 
SELECT [vcTableName]
, [nmPriority]
, [dtLastUpdated]
FROM [Indexes] (NOLOCK) 

GO