SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TRIGANTICLOG] 
AS 
SELECT [TriganticlogKey]
, [tablename]
, [key1]
, [key2]
, [key3]
, [transmitflag]
, [transmitbatch]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [TRIGANTICLOG] (NOLOCK) 

GO