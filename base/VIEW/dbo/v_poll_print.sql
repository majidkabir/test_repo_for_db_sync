SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_POLL_PRINT] 
AS 
SELECT [printtype]
, [orderkey]
, [caseid]
, [dropid]
, [status]
, [EffectiveDate]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [POLL_PRINT] (NOLOCK) 

GO