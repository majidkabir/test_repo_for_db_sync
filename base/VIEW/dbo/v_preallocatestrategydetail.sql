SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PreAllocateStrategyDetail] 
AS 
SELECT [PreAllocateStrategyKey]
, [PreAllocateStrategyLineNumber]
, [DESCR]
, [UOM]
, [PreAllocatePickCode]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [PreAllocateStrategyDetail] (NOLOCK) 

GO