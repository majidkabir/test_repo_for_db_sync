SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW V_AllocationStrategy_Detail AS 
SELECT s.StrategyKey, '01_PreAllocStg' AS StrategyType, 
s.PreAllocateStrategyKey AS SubStrategyKey, 
pas.PreAllocateStrategyLineNumber AS LineNumber, pas.UOM, pas.PreAllocatePickCode AS [PickCode], '' AS LocationTypeOverride
FROM Strategy AS s WITH(NOLOCK)  
JOIN PreAllocateStrategyDetail AS pas WITH(NOLOCK) ON pas.PreAllocateStrategyKey = s.PreAllocateStrategyKey 
UNION ALL
SELECT s.StrategyKey, '02_AllocStg' AS StgType, ASD.AllocateStrategyKey, ASD.AllocateStrategyLineNumber, ASD.UOM, ASD.PickCode, asd.LocationTypeOverride
FROM Strategy AS s WITH(NOLOCK) 
JOIN AllocateStrategyDetail AS ASD WITH(NOLOCK) ON ASD.AllocateStrategyKey = s.AllocateStrategyKey 



GO