SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PreAllocateStrategy] 
AS 
SELECT [PreAllocateStrategyKey]
, [Descr]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [PreAllocateStrategy] (NOLOCK) 

GO