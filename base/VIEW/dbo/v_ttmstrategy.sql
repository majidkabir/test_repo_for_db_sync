SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TTMStrategy] 
AS 
SELECT [TTMStrategyKey]
, [Descr]
, [InterleaveTasks]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [TTMStrategy] (NOLOCK) 

GO