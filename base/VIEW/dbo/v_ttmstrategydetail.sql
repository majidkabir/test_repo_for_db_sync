SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_TTMStrategyDetail] 
AS 
SELECT [TTMStrategyKey]
, [TTMStrategyLineNumber]
, [Descr]
, [TaskType]
, [TTMPickCode]
, [TTMOverride]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [TTMStrategyDetail] (NOLOCK) 

GO