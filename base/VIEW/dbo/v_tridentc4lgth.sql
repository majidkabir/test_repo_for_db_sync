SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TRIDENTC4LGTH] 
AS 
SELECT [TridentSchedulerKey]
, [Hikey]
, [HiImpExp]
, [NextRunDate]
, [LastRunDate]
, [Frequency]
, [StartWindow]
, [StartString]
, [EnableFlag]
, [SkipDays]
, [SkipTime]
, [AddDate]
, [AddWho]
FROM [TRIDENTC4LGTH] (NOLOCK) 

GO