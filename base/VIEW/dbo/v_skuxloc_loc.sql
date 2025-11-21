SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_skuxloc_loc]
AS
SELECT     dbo.LOC.Facility
         , dbo.LOC.Loc
         , dbo.LOC.LocationType
         , dbo.LOC.LogicalLocation
         , ISNULL(SL.NoOfSkuAssigned, 0) AS NoOfSkuAssigned
         , ISNULL(SL.SkuAssigned, 0) AS SkuAssigned
         , dbo.LOC.PutawayZone
         , ISNULL((SELECT     SUM(Qty) AS Expr1
                   FROM         dbo.SKUxLOC AS SXL WITH (NOLOCK)
                   WHERE     (Loc = dbo.LOC.Loc)), 0) AS Qty
         , ABC                --(Wan01)
           FROM dbo.LOC WITH (NOLOCK) LEFT OUTER JOIN
        (SELECT     Loc, COUNT(DISTINCT Sku) AS NoOfSkuAssigned, CASE WHEN SL1.SKU IS NOT NULL THEN '1' ELSE '0' END AS SkuAssigned
         FROM          dbo.SKUxLOC AS SL1 WITH (NOLOCK)
         WHERE      (LocationType IN ('PICK', 'CASE'))
         GROUP BY Loc, CASE WHEN SL1.SKU IS NOT NULL THEN '1' ELSE '0' END)
     AS SL ON SL.Loc = dbo.LOC.Loc


GO