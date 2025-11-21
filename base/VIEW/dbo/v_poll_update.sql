SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_POLL_UPDATE] 
AS 
SELECT [PollUpdateKey]
, [UpdateString]
, [Status]
, [RetryCount]
, [EffectiveDate]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [POLL_UPDATE] (NOLOCK) 

GO