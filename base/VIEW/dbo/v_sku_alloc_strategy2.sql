SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_SKU_ALLOC_STRATEGY2]
AS
SELECT S.StorerKey, S.Sku, S.StrategyKey, 'PR' AS [StrategyType]
      , ISNULL(RTRIM(PST.PreAllocateStrategyKey),'') AS AllocateStrategyKey
      , ISNULL(RTRIM(PST.PreAllocateStrategyLineNumber),'') AS StrategyLineNumber
      , CASE WHEN ISNULL(RTRIM(PST.UOM),'') = '1' THEN 'Pallet'
             WHEN ISNULL(RTRIM(PST.UOM),'') = '2' THEN 'Case'
             WHEN ISNULL(RTRIM(PST.UOM),'') = '3' THEN 'InnerPack'
             WHEN ISNULL(RTRIM(PST.UOM),'') IN ('6','7') THEN 'Piece'
             WHEN ISNULL(RTRIM(PST.UOM),'') IN ('4','5','8','9') THEN 'OtherUnit'
             ELSE ''
        END AS UOM
      , ISNULL(RTRIM(PST.PreAllocatePickCode),'') AS PickCode
      , '' AS LocationTypeOverride
FROM   SKU S WITH (NOLOCK)
LEFT JOIN   Strategy ST WITH (NOLOCK) ON S.StrategyKey = ST.StrategyKey
LEFT JOIN   PreAllocateStrategyDetail PST WITH (NOLOCK) ON ST.PreAllocateStrategyKey = PST.PreAllocateStrategyKey
UNION ALL
SELECT S.StorerKey, S.Sku, S.StrategyKey, 'AL' AS [StrategyType]
      , ISNULL(RTRIM(AST.AllocateStrategyKey),'') AS AllocateStrategyKey
      , ISNULL(RTRIM(AST.AllocateStrategyLineNumber),'') AS StrategyLineNumber
      , CASE WHEN ISNULL(RTRIM(AST.UOM),'') = '1' THEN 'Pallet'
             WHEN ISNULL(RTRIM(AST.UOM),'') = '2' THEN 'Case'
             WHEN ISNULL(RTRIM(AST.UOM),'') = '3' THEN 'InnerPack'
             WHEN ISNULL(RTRIM(AST.UOM),'') IN ('6','7') THEN 'Piece'
             WHEN ISNULL(RTRIM(AST.UOM),'') IN ('4','5','8','9') THEN 'OtherUnit'
             ELSE ''
        END AS UOM
      , ISNULL(RTRIM(AST.PickCode),'') AS PickCode
      , ISNULL(RTRIM(AST.LocationTypeOverride),'') AS LocationTypeOverride
FROM   SKU S WITH (NOLOCK)
LEFT JOIN   Strategy ST WITH (NOLOCK) ON S.StrategyKey = ST.StrategyKey
LEFT JOIN   AllocateStrategyDetail AST WITH (NOLOCK) ON ST.AllocateStrategyKey = AST.AllocateStrategyKey

GO