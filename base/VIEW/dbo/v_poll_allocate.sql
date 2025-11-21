SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_POLL_ALLOCATE] 
AS 
SELECT [orderkey]
, [EffectiveDate]
, [RetryCount]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
, [TimeStamp]
FROM [POLL_ALLOCATE] (NOLOCK) 

GO