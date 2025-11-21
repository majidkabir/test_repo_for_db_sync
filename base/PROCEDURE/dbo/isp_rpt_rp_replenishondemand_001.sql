SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_RP_REPLENISHONDEMAND_001                    */
/* Creation Date: 09-Mar-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-21903 - Convert r_dw_replenishondemand_rpt to Logi Report*/
/*          Copy and modify from isp_ReplenishOnDemand_rpt               */
/*                                                                       */
/* Called By: Report                                                     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 09-Mar-2023  WLChooi  1.0  DevOps Combine Script                      */
/*************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RPT_RP_REPLENISHONDEMAND_001]
(
   @c_Storerkey     NVARCHAR(15)
 , @dt_deliveryfrom DATETIME
 , @dt_deliveryto   DATETIME
 , @c_SKUGroup      NVARCHAR(10)
 , @c_Lottable01    NVARCHAR(18) = ''
 , @c_Lottable02    NVARCHAR(18) = ''
 , @c_Lottable03    NVARCHAR(18) = ''
 , @c_Facility      NVARCHAR(5)  = ''
 , @c_PAZoneFrom    NVARCHAR(10) = ''
 , @c_PAZoneTo      NVARCHAR(10) = ''
 , @c_ShowBCode     NVARCHAR(1)  = 'N'
 , @c_EmptyPickloc  NVARCHAR(1)  = 'N'
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SKU NVARCHAR(20)
         , @c_PrevSKU NVARCHAR(20)
         , @c_FromLOC NVARCHAR(10)
         , @c_FromID NVARCHAR(18)
         , @c_FromLOTLOCID NVARCHAR(38)
         , @n_QTYtoReplen INT
         , @n_QTYAvail INT
         , @c_GetLottable01 NVARCHAR(18)
         , @c_GetLottable02 NVARCHAR(18)
         , @c_GetLottable03 NVARCHAR(18)
         , @c_RetVal NVARCHAR(255)

   EXEC dbo.isp_GetCompanyInfo @c_Storerkey = @c_Storerkey
                             , @c_Type = N'1'
                             , @c_DataWindow = N'RPT_RP_REPLENISHONDEMAND_001'
                             , @c_RetVal = @c_RetVal OUTPUT
   
   -- Order demand        
   SELECT od.StorerKey
        , od.Sku
        , COUNT(DISTINCT o.OrderKey) NoOfOrder
        , SUM(od.OriginalQty) OrderQTY
        , SPACE(10) ToLoc
        , 0 PFAvail
        , 0 BulkAvail
        , 0 QTYtoReplen
        , SKU.DESCR
        , PACK.PackUOM3
        , @c_ShowBCode AS ShowBCode --WL01
   INTO #Demand
   FROM ORDERS o (NOLOCK)
   INNER JOIN ORDERDETAIL od (NOLOCK) ON (o.OrderKey = od.OrderKey)
   INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = od.StorerKey AND SKU.Sku = od.Sku)
   INNER JOIN PACK (NOLOCK) ON (SKU.PACKKey = PACK.PackKey)
   WHERE o.StorerKey = @c_Storerkey
   AND   o.Status = '0'
   AND   DATEDIFF(DAY, @dt_deliveryfrom, o.DeliveryDate) >= 0
   AND   DATEDIFF(DAY, o.DeliveryDate, @dt_deliveryto) >= 0
   AND   SKU.SKUGROUP = @c_SKUGroup
   AND   o.Facility = @c_Facility
   GROUP BY od.StorerKey
          , od.Sku
          , SKU.DESCR
          , PACK.PackUOM3
   ORDER BY od.StorerKey
          , od.Sku

   -- Update PF loc (mezzanine floor)        
   UPDATE #Demand
   SET ToLoc = sl.loc
   FROM #Demand d (NOLOCK)
   INNER JOIN (  SELECT sl.StorerKey
                      , sl.Sku
                      , MIN(sl.loc) loc -- sku could have multi pick face, use min()  
                 FROM SKUxLOC sl (NOLOCK)
                 INNER JOIN LOC (NOLOCK) ON (sl.Loc = LOC.Loc)
                 WHERE sl.StorerKey = @c_Storerkey
                 AND   sl.LocationType IN ( 'case', 'pick' )
                 AND   LOC.PutawayZone <> 'adidas'
                 AND   LOC.Facility = @c_Facility
                 AND   LOC.PutawayZone BETWEEN @c_PAZoneFrom AND @c_PAZoneTo
                 GROUP BY sl.StorerKey
                        , sl.Sku) sl ON (d.StorerKey = sl.StorerKey AND d.Sku = sl.Sku)

   -- Update PF avail        
   UPDATE #Demand
   SET PFAvail = sl.PFAvail
   FROM #Demand r (NOLOCK)
   INNER JOIN (  SELECT sl.StorerKey
                      , sl.Sku
                      , SUM(sl.Qty - sl.QtyAllocated - sl.QtyPicked) PFAvail
                 FROM SKUxLOC sl (NOLOCK)
                 INNER JOIN LOC (NOLOCK) ON (sl.Loc = LOC.Loc)
                 WHERE sl.StorerKey = @c_Storerkey
                 AND   (sl.LocationType IN ( 'case', 'pick' ))
                 AND   (sl.Qty - sl.QtyAllocated - sl.QtyPicked) > 0
                 AND   LOC.LocationFlag NOT IN ( 'HOLD', 'DAMAGE' )
                 AND   LOC.Status <> 'HOLD'
                 AND   LOC.Facility = @c_Facility --NJOW01  
                 AND   LOC.PutawayZone BETWEEN @c_PAZoneFrom AND @c_PAZoneTo
                 GROUP BY sl.StorerKey
                        , sl.Sku) sl ON (r.StorerKey = sl.StorerKey AND r.Sku = sl.Sku)

   -- Update bulk avail        
   UPDATE #Demand
   SET BulkAvail = sl.BulkAvail
   FROM #Demand r (NOLOCK)
   INNER JOIN (  SELECT sl.StorerKey
                      , sl.Sku
                      , SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS BulkAvail
                 FROM SKUxLOC sl (NOLOCK)
                 INNER JOIN LOC (NOLOCK) ON (sl.Loc = LOC.Loc)
                 INNER JOIN LOTxLOCxID lli (NOLOCK) ON (   lli.StorerKey = sl.StorerKey
                                                       AND lli.Sku = sl.Sku
                                                       AND lli.Loc = sl.Loc)
                 INNER JOIN LOTATTRIBUTE l (NOLOCK) ON (l.Lot = lli.Lot)
                 WHERE sl.StorerKey = @c_Storerkey
                 AND   sl.LocationType NOT IN ( 'case', 'pick' )
                 AND   (lli.Qty - lli.QtyAllocated - lli.QtyPicked) > 0
                 AND   LOC.LocationFlag NOT IN ( 'HOLD', 'DAMAGE' )
                 AND   LOC.Status <> 'HOLD'
                 AND   (l.Lottable01 = @c_Lottable01 OR ISNULL(@c_Lottable01, '') = '')
                 AND   (l.Lottable02 = @c_Lottable02 OR ISNULL(@c_Lottable02, '') = '')
                 AND   (l.Lottable03 = @c_Lottable03 OR ISNULL(@c_Lottable03, '') = '')
                 AND   LOC.Facility = @c_Facility
                 GROUP BY sl.StorerKey
                        , sl.Sku) sl ON (r.StorerKey = sl.StorerKey AND r.Sku = sl.Sku)

   -- update QtytoReplen        
   UPDATE #Demand
   SET QTYtoReplen = OrderQTY - PFAvail
   WHERE (OrderQTY - PFAvail) > 0

   --  delete those don't need replen  
   IF ISNULL(@c_EmptyPickloc, 'N') = 'N'
   BEGIN
      DELETE #Demand
      WHERE QTYtoReplen = 0 OR ISNULL(ToLoc, '') = ''
   END
   ELSE
   BEGIN
      DELETE #Demand
      WHERE QTYtoReplen = 0
   END

   -- create blank #replen        
   SELECT lli.StorerKey
        , lli.Sku
        , lli.Loc
        , lli.Id
        , lli.Qty
        , l.Lottable01
        , l.Lottable02
        , l.Lottable03
   INTO #Replen
   FROM LOTxLOCxID lli (NOLOCK)
   JOIN LOTATTRIBUTE l (NOLOCK) ON lli.Lot = l.Lot
   WHERE 1 = 0

   DECLARE cur_Demand CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT StorerKey
        , Sku
        , QTYtoReplen
   FROM #Demand
   ORDER BY StorerKey
          , Sku

   OPEN cur_Demand

   FETCH NEXT FROM cur_Demand
   INTO @c_Storerkey
      , @c_SKU
      , @n_QTYtoReplen
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @c_PrevSKU <> @c_SKU
      BEGIN
         SET @c_FromLOTLOCID = N''
         SET @c_FromLOC = N''
         SET @c_FromID = N''
         SET @c_PrevSKU = @c_SKU
      END

      SELECT TOP 1 @c_FromLOTLOCID = REPLICATE(
                                        '0', 5 - LEN(CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR)))
                                     + CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR) + lli.Loc
                                     + lli.Id + lli.Lot
                 , @c_FromLOC = lli.Loc
                 , @c_FromID = lli.Id
                 , @n_QTYAvail = SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked)
                 , @c_GetLottable01 = l.Lottable01
                 , @c_GetLottable02 = l.Lottable02
                 , @c_GetLottable03 = l.Lottable03
      FROM LOTxLOCxID lli (NOLOCK)
      INNER JOIN SKUxLOC sl (NOLOCK) ON (lli.StorerKey = sl.StorerKey AND lli.Sku = sl.Sku AND lli.Loc = sl.Loc)
      INNER JOIN LOC (NOLOCK) ON (sl.Loc = LOC.Loc)
      INNER JOIN LOTATTRIBUTE l (NOLOCK) ON (l.Lot = lli.Lot)
      WHERE sl.StorerKey = @c_Storerkey
      AND   sl.Sku = @c_SKU
      AND   sl.LocationType NOT IN ( 'pick', 'case' )
      AND   (lli.Qty - lli.QtyAllocated - lli.QtyPicked) > 0
      AND   LOC.LocationFlag NOT IN ( 'HOLD', 'DAMAGE' )
      AND   LOC.Status <> 'HOLD'
      AND   (l.Lottable01 = @c_Lottable01 OR ISNULL(@c_Lottable01, '') = '')
      AND   (l.Lottable02 = @c_Lottable02 OR ISNULL(@c_Lottable02, '') = '')
      AND   (l.Lottable03 = @c_Lottable03 OR ISNULL(@c_Lottable03, '') = '')
      AND   LOC.Facility = @c_Facility
      GROUP BY lli.Loc
             , lli.Id
             , lli.Lot
             , lli.Loc
             , lli.Id
             , l.Lottable01
             , l.Lottable02
             , l.Lottable03
      HAVING REPLICATE('0', 5 - LEN(CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR)))
             + CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR) + lli.Loc + lli.Id + lli.Lot > @c_FromLOTLOCID
      ORDER BY REPLICATE('0', 5 - LEN(CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR)))
               + CAST(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS VARCHAR) + lli.Loc + lli.Id + lli.Lot

      IF @n_QTYAvail IS NULL
         FETCH NEXT FROM cur_Demand
         INTO @c_Storerkey
            , @c_SKU
            , @n_QTYtoReplen
      ELSE
      BEGIN
         IF @n_QTYtoReplen <= @n_QTYAvail
         BEGIN
            INSERT INTO #Replen (StorerKey, Sku, Loc, Id, Qty, Lottable01, Lottable02, Lottable03)
            VALUES (@c_Storerkey, @c_SKU, UPPER(@c_FromLOC), @c_FromID, @n_QTYtoReplen, @c_GetLottable01
                  , @c_GetLottable02, @c_GetLottable03)
            FETCH NEXT FROM cur_Demand
            INTO @c_Storerkey
               , @c_SKU
               , @n_QTYtoReplen
         END
         ELSE
         BEGIN
            INSERT INTO #Replen (StorerKey, Sku, Loc, Id, Qty, Lottable01, Lottable02, Lottable03)
            VALUES (@c_Storerkey, @c_SKU, UPPER(@c_FromLOC), @c_FromID, @n_QTYAvail, @c_GetLottable01, @c_GetLottable02
                  , @c_GetLottable03)
            SET @n_QTYtoReplen = @n_QTYtoReplen - @n_QTYAvail
         END
      END
   END
   CLOSE cur_Demand
   DEALLOCATE cur_Demand

   SELECT d.StorerKey
        , d.Sku
        , d.DESCR
        , d.PackUOM3
        , d.ToLoc
        , r.Loc
        , r.Id
        , r.Qty
        , r.Lottable01
        , r.Lottable02
        , r.Lottable03
        , d.ShowBCode
        , ISNULL(@c_RetVal,'') AS Logo
   FROM #Demand d
   LEFT JOIN #Replen r ON (r.StorerKey = d.StorerKey AND r.Sku = d.Sku)
   ORDER BY r.Loc

   IF CURSOR_STATUS('LOCAL', 'cur_Demand') IN ( 0, 1 )
   BEGIN
      CLOSE cur_Demand
      DEALLOCATE cur_Demand
   END

   IF OBJECT_ID('tempdb..#Demand') IS NOT NULL
      DROP TABLE #Demand

   IF OBJECT_ID('tempdb..#Replen') IS NOT NULL
      DROP TABLE #Replen
END

GO