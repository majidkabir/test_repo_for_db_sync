SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ITRNHDR] 
AS 
SELECT [HeaderType]
, [ItrnKey]
, [HeaderKey]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [ITRNHDR] (NOLOCK) 

GO