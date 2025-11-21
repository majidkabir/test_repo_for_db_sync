SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_inventory_summary                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nsp_inventory_summary] (
@c_storer_start NVARCHAR(15),
@c_storer_end	 NVARCHAR(15),
@c_sku_start	 NVARCHAR(20),
@c_sku_end		 NVARCHAR(20),
@c_facility_start NVARCHAR(5),
@c_facility_end 	 NVARCHAR(5)
)
AS
BEGIN -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT LOT.Storerkey, LOT.SKU,
   CASE WHEN LOT.Status <> 'OK' THEN SUM(LOT.QTY)
   WHEN SUM(LOT.Qtyonhold) > 0 THEN SUM(LOT.Qtyonhold)
ELSE 0 END as Onholdqty
   INTO #TEMPLOT
   FROM LOT (NOLOCK)
   GROUP BY LOT.Storerkey, LOT.SKU, LOT.Status

   SELECT SKU.Storerkey,
   SKU.Sku,
   LOC.Facility,
   PACK.PACKUOM3,
   QTY = SUM(SKUXLOC.QTY),
   Qtyallocated = SUM(SKUXLOC.QtyAllocated),
   QtyPicked = SUM(SKUXLOC.QtyPicked),
   QtyPickInProcess = SUM(SKUXLOC.QtyPickInProcess),
   PreallocQty = ISNULL(MAX(P.PreallocQty), 0),
CASE WHEN S.Svalue = '1' AND LOC.Facility = '3106' THEN SUM(SKUXLOC.QTY) ELSE 0 END	as DamagedQty,
CASE WHEN S.Svalue = '0' THEN ISNULL(MAX(T.Onholdqty), 0) ELSE 0 END AS Onholdqty,
   SKU.SkuGroup,
   Susr3 = ISNULL(SKU.Susr3,''),
   SKU.Class,
   SKU.ItemClass,
   Descr = MAX(SKU.Descr)
   INTO #RESULT
   FROM SKU (NOLOCK)
   JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey
   JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = SKU.Storerkey AND SKUXLOC.SKU = SKU.SKU
   JOIN LOC (NOLOCK) ON LOC.LOC = SKUXLOC.LOC
   LEFT OUTER JOIN STORERCONFIG S (NOLOCK) ON S.Storerkey = SKUXLOC.Storerkey AND S.Configkey = 'OWITF'
   LEFT OUTER JOIN (SELECT P.Storerkey, P.SKU, PreallocQty = SUM(P.QTY) FROM PreallocatePickdetail P (NOLOCK) GROUP BY P.Storerkey, P.SKU) as P
   ON P.Storerkey = SKUXLOC.Storerkey AND P.SKU = SKUXLOC.SKU
   LEFT OUTER JOIN #TEMPLOT T (NOLOCK) ON T.Storerkey = SKUXLOC.Storerkey AND T.Sku = SKUXLOC.Sku
   WHERE SKUXLOC.QTY > 0
   AND   SKUXLOC.Storerkey between @c_storer_start and @c_storer_end
   AND   SKUXLOC.Sku between @c_sku_start and @c_sku_end
   AND   LOC.Facility between @c_facility_start and @c_facility_end
   GROUP BY	SKU.Storerkey,
   SKU.Sku,
   LOC.Facility,
   PACK.PACKUOM3,
   S.Svalue,
   SKU.SkuGroup,
   SKU.Susr3,
   SKU.Class,
   SKU.ItemClass
   ORDER BY SKU.Sku, LOC.Facility

   SELECT * FROM #RESULT

   /*
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE TYPE = 'U' AND NAME = 'TEMPLOT')
   BEGIN
   DROP TABLE TEMPLOT
   END
   */

   DROP TABLE #TEMPLOT
   DROP TABLE #RESULT

   SET NOCOUNT OFF
END -- MAIN

GO