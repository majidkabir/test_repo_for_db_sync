SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

--(Wan01) 30-OCT-2013 Add Fields ABCEA, ABCCS
CREATE   VIEW [dbo].[V_skuxloc_sku]
AS
SELECT     dbo.SKU.StorerKey
         , dbo.SKU.Sku
         , dbo.SKU.DESCR
         , dbo.SKU.SUSR3
         , dbo.SKU.CLASS
         , dbo.SKU.SKUGROUP
         , dbo.SKU.itemclass
         , ISNULL(SL1.LocAssigned, 0) AS LocAssigned
         , ISNULL(SL1.NoOfLocAssigned, 0) AS NoOfLocAssigned
         , ISNULL ((SELECT     SUM(Qty) AS Expr1
                    FROM         dbo.SKUxLOC AS SXL WITH (NOLOCK)
                    WHERE     (StorerKey = dbo.SKU.StorerKey) AND (Sku = dbo.SKU.Sku)), 0) AS Qty
         , dbo.SKU.ABCEA     --(Wan01)
         , dbo.SKU.ABCCS     --(Wan01)
         FROM dbo.SKU WITH (NOLOCK) LEFT OUTER JOIN
        (SELECT     StorerKey, Sku, CASE WHEN SL.LOC IS NOT NULL THEN '1' ELSE '0' END AS LocAssigned, COUNT(DISTINCT Loc) AS NoOfLocAssigned
         FROM          dbo.SKUxLOC AS SL WITH (NOLOCK)
         WHERE      (LocationType IN ('CASE', 'PICK'))
         GROUP BY StorerKey, Sku, CASE WHEN SL.LOC IS NOT NULL THEN '1' ELSE '0' END)
         AS SL1 ON SL1.StorerKey = dbo.SKU.StorerKey AND SL1.Sku = dbo.SKU.Sku




GO