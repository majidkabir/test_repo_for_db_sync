SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_help] 
AS 
SELECT [topic]
, [context]
, [langid]
, [shorthelp]
, [extendedhelpurl]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [help] (NOLOCK) 

GO