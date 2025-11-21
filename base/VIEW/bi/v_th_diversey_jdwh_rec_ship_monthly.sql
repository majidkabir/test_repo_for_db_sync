SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog  https://jiralfl.atlassian.net/browse/WMS-18745
/* Date         Author      Ver.  Purposes									                  */
/* 12-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_DIVERSEY_JDWH_REC_SHIP_MONTHLY]
AS
SELECT
  A.DeliveryDate_d,
  A.Externorderkey,
  A.storerkey,
  A.consigneekey,
  A.mbolkey,
  A.orderkey,
  [type],
  Total_Full_PL = SUM(A.FP1),
  Loose_Case = SUM(A.lc1),
  Loose_piece = SUM(A.l_e),
  Mixed_Pallet = SUM(A.m_p1),
  Total_Ship_Ctn = SUM(A.TTC1),
  Qty_Dsp = SUM(A.QtyShip)

FROM (SELECT
  oh.storerkey,
  oh.Externorderkey,
  oh.mbolkey,
  oh.orderkey,
  oh.type,
  oh.consigneekey,
  DeliveryDate_d = CONVERT(char(10), oh.DeliveryDate, 111),
  s.susr3,
  od.SKU,
  CaseCnt = CAST(p.caseCnt AS int),
  Pallet = CAST(p.pallet AS int),
  QTYShip = SUM(od.shippedqty),
  TTC1 = SUM(od.shippedqty) / (CASE
    WHEN p.casecnt = 0 THEN 1
    ELSE CAST(p.casecnt AS int)
  END),
  FP1 = SUM(od.shippedqty) / (CASE
    WHEN p.pallet = 0 THEN 1
    ELSE CAST(p.pallet AS int)
  END),
  LC1 = (SUM(od.shippedqty) % CASE
    WHEN p.pallet = 0 THEN 1
    ELSE CAST(p.pallet AS int)
  END) / (CASE
    WHEN p.casecnt = 0 THEN 1
    ELSE CAST(p.casecnt AS int)
  END),
  M_P1 = ROUND((SUM(od.shippedqty) / CAST((CASE
    WHEN p.pallet = 0 THEN 1
    ELSE CAST(p.pallet AS int)
  END) AS decimal)), 2) - (SUM(od.shippedqty) / CAST((CASE
    WHEN p.pallet = 0 THEN 1
    ELSE CAST(p.pallet AS int)
  END) AS int)),
  L_E = (SUM(od.shippedqty)
  - (p.pallet * (SUM(od.shippedqty) / (CASE
    WHEN p.pallet = 0 THEN 1
    ELSE CAST(p.pallet AS int)
  END)))
  - (p.casecnt * (SUM(od.shippedqty) % CASE
    WHEN p.pallet = 0 THEN 1
    ELSE CAST(p.pallet AS int)
  END) / (CASE
    WHEN p.casecnt = 0 THEN 1
    ELSE CAST(p.casecnt AS int)
  END))
  )
FROM dbo.orders oh WITH (NOLOCK)
JOIN dbo.orderdetail od WITH (NOLOCK) ON oh.orderkey = od.orderkey
JOIN dbo.pack p WITH (NOLOCK) ON od.packkey = p.packkey
JOIN dbo.sku s WITH (NOLOCK) ON od.storerkey = s.storerkey AND od.sku = s.sku
WHERE oh.storerkey = '06700'
AND oh.status = '9'
AND  oh.DeliveryDate > CONVERT(char(10), GETDATE() - 33, 111)
AND oh.DeliveryDate< CONVERT(char(10), GETDATE(), 111)

GROUP BY CONVERT(char(10), oh.DeliveryDate, 111),
         oh.Externorderkey,
         oh.storerkey,
         oh.mbolkey,
         oh.type,
         oh.consigneekey,
         oh.orderkey,
         od.sku,
         s.susr3,
         p.casecnt,
         p.pallet) AS A

GROUP BY A.DeliveryDate_d,
         A.Externorderkey,
         A.storerkey,
         A.consigneekey,
         A.mbolkey,
         A.orderkey,
         A.type
--ORDER BY DeliveryDate_d

GO