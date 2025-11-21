SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_PickCode]
AS
SELECT StorerKey, SKU, SKU.StrategyKey, 'PreallocateStrategy ' AS Strategy, PreallocateStrategyDetail.PreAllocateStrategyKey,
       PreAllocateStrategyLineNumber AS StrategyLineNumber, PreallocateStrategyDetail.UOM, PreAllocatePickCode, '' AS RetryIfQtyRemain
from SKU (NOLOCK)
JOIN Strategy (NOLOCK) ON SKU.StrategyKey = Strategy.StrategyKey
JOIN PreallocateStrategyDetail (NOLOCK) ON (Strategy.PreAllocateStrategyKey = PreallocateStrategyDetail.PreAllocateStrategyKey)
UNION ALL
SELECT StorerKey, SKU, SKU.StrategyKey, 'AllocateStrategy ' AS Strategy, AllocateStrategyDetail.AllocateStrategyKey,
       AllocateStrategyLineNumber, AllocateStrategyDetail.UOM, AllocateStrategyDetail.PickCode, RetryIfQtyRemain
from SKU (NOLOCK)
JOIN Strategy (NOLOCK) ON SKU.StrategyKey = Strategy.StrategyKey
JOIN AllocateStrategy (NOLOCK) ON (Strategy.AllocateStrategyKey = AllocateStrategy.AllocateStrategyKey)
JOIN AllocateStrategyDetail (NOLOCK) ON (Strategy.AllocateStrategyKey = AllocateStrategyDetail.AllocateStrategyKey)




GO