SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TRANSMITLOG] 
AS 
SELECT [transmitlogkey]
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
FROM [TRANSMITLOG] (NOLOCK) 

GO