SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_Strategy] 
AS 
SELECT [StrategyKey]
, [Descr]
, [PreAllocateStrategyKey]
, [AllocateStrategyKey]
, [ReplenishmentStrategyKey]
, [PutawayStrategyKey]
, [PickStrategyKey]
, [TTMStrategyKey]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
, [VASStrategyKey]
, [ABCPAStrategyKey]
, [TransferStrategyKey]
FROM [Strategy] (NOLOCK) 


GO