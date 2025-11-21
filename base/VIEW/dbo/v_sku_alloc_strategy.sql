SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_SKU_ALLOC_STRATEGY]
AS
SELECT S.StorerKey, S.SKU, S.StrategyKey, PST.PreAllocateStrategyKey as AllocateStrategyKey,
       'PR' AS [StrategyType], PST.PreAllocateStrategyLineNumber As StrategyLineNumber,
       UOM, PreAllocatePickCode As PickCode,
       '' AS LocationTypeOverride
FROM   SKU S WITH (NOLOCK)
JOIN   Strategy ST WITH (NOLOCK) ON S.StrategyKey = ST.StrategyKey
JOIN   PreAllocateStrategyDetail PST WITH (NOLOCK) ON ST.PreAllocateStrategyKey = PST.PreAllocateStrategyKey
UNION ALL
SELECT S.StorerKey, S.SKU, S.StrategyKey, AST.AllocateStrategyKey as AllocateStrategyKey,
       'AL' AS [StrategyType],
       AST.AllocateStrategyLineNumber As StrategyLineNumber,
       UOM, AST.PickCode As PickCode,
       LocationTypeOverride
FROM   SKU S WITH (NOLOCK)
JOIN   Strategy ST WITH (NOLOCK) ON S.StrategyKey = ST.StrategyKey
JOIN   AllocateStrategyDetail AST WITH (NOLOCK) ON ST.AllocateStrategyKey = AST.AllocateStrategyKey


GO