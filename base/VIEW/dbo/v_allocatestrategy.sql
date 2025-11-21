SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_AllocateStrategy] 
AS 
SELECT [AllocateStrategyKey]
, [Descr]
, [RetryIfQtyRemain]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [AllocateStrategy] (NOLOCK) 

GO