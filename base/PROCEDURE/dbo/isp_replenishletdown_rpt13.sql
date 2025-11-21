SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_ReplenishLetdown_rpt13                          */
/* Creation Date: 09-Apr-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-12773 - CN PUMA replenishment report                    */
/*                                                                      */
/* Called By: r_dw_replenishletdown_rpt13                               */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.  Purposes                                 */
/* 2020-05-27   WLChooi  1.1   Fix - Remove Order Status filter and add */
/*                             filter by Wavekey (WL01)                 */
/* 2022-01-10   SYChua   1.2   JSM-45009 - Fix no PickQty Display by    */
/*                             ordering PickQty in DESC (SY01)          */
/************************************************************************/

CREATE PROC [dbo].[isp_ReplenishLetdown_rpt13] (
            @c_Storerkey    NVARCHAR(15)
          , @c_facility     NVARCHAR(5)
          , @c_wavekey      NVARCHAR(10) )
          --, @c_wavekeyend   NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE --@c_storerkey NVARCHAR(15),
     @c_sku              NVARCHAR(20),
     @c_id               NVARCHAR(18),
     @c_lot              NVARCHAR(10),
     @c_loc              NVARCHAR(10),
     @c_toloc            NVARCHAR(10),
     @n_qtyrepl          Int,
     @n_svalue           Int,
     @c_RepLenishmentKey NVARCHAR(10),
     @c_uom              NVARCHAR(10),
     @c_packkey          NVARCHAR(10),
     @b_success          Int,
     @n_err              Int,
     @n_continue         Int,
     @c_errmsg           NVARCHAR(255),
     @n_starttcnt        INT,
     @c_showField        NVARCHAR(5),
     @c_showskufield     NVARCHAR(5),
     @c_showdiffskuformat NVARCHAR(5)


   SET @c_showField = 'N'

   SELECT @c_ShowField = CASE WHEN (CL.Short IS NULL OR CL.Short = 'N') THEN 'N' ELSE 'Y' END
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_replenishletdown_rpt13'
   AND CL.Code = 'SHOWFIELD' AND CL.Storerkey = @c_Storerkey


   SET @c_showskufield = 'N'

   SELECT @c_showskufield = CASE WHEN (CL.Short IS NULL OR CL.Short = 'N') THEN 'N' ELSE 'Y' END
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_replenishletdown_rpt13'
   AND CL.Code = 'SHOWSKUFIELD' AND CL.Storerkey = @c_Storerkey

   SET @c_showdiffskuformat = 'N'

   SELECT @c_showdiffskuformat = CASE WHEN (CL.Short IS NULL OR CL.Short = 'N') THEN 'N' ELSE 'Y' END
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_replenishletdown_rpt13'
   AND CL.Code = 'SHOWDIFFSKUFORMAT' AND CL.Storerkey = @c_Storerkey

   --From
   SELECT PD.Storerkey, PD.Sku, PD.Loc, PD.ID, SUM(PD.Qty) PickQty, PD.Lot
   INTO #temppick
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
                                    AND OD.sku  = PD.sku
                                    AND OD.Storerkey = PD.Storerkey
   JOIN ORDERS ORD WITH (NOLOCK) ON OD.Orderkey = ORD.Orderkey
   JOIN SKUxLOC SL WITH (NOLOCK) ON PD.Storerkey = SL.Storerkey
                                AND PD.Sku = SL.Sku
                                AND PD.Loc = SL.Loc
   JOIN LOC L WITH (NOLOCK) ON L.Loc = SL.LOC
   JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON PD.LOT = LA.LOT
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.Orderkey = ORD.Orderkey
   WHERE WD.WaveKey = @c_wavekey
   AND   ORD.Facility = @c_facility
   --AND   ORD.Status in ('1','2')   --WL01
   AND   SL.LocationType <> 'PICK'
   --AND   PD.Status < '5'
   AND   PD.StorerKey = @c_storerkey
   GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID, PD.Lot

    --To
   SELECT RP.Storerkey, RP.Sku, RP.FromLoc, RP.ID, RP.ToLoc, SUM(RP.Qty) ReplQty, RP.Lot, L.Pickzone
   INTO #temprepl
   FROM REPLENISHMENT RP WITH (NOLOCK)
   JOIN SKUxLOC SL WITH (NOLOCK) ON  RP.Storerkey = SL.Storerkey
                                 AND RP.Sku       = SL.Sku
                                 AND RP.FromLoc   = SL.Loc
   JOIN LOC L WITH (NOLOCK) ON  RP.FromLoc = L.Loc
   --WHERE SL.LocationType <> 'PICK'
   --AND
   WHERE RP.Confirmed = 'N'
   AND   RP.RepLENNo <> 'Y'
   AND   RP.StorerKey = @c_Storerkey
   AND   RP.Wavekey =  @c_wavekey   --WL01
   AND   L.Facility = @c_facility
   GROUP BY RP.Storerkey, RP.Sku, RP.FromLoc, RP.ToLoc, RP.ID, RP.Lot, L.Pickzone

   SELECT DISTINCT LLI.Storerkey, LLI.Sku, LLI.Loc, LLI.ID, LLI.Qty, PK.Packkey, PK.CaseCnt, LLI.Lot,S.size
   INTO #tempskuxloc
   FROM #temppick tp
   JOIN SKUXLOC SL WITH (NOLOCK) ON  SL.Storerkey = tp.storerkey -- ISNULL(tp.Storerkey, rp.storerkey)
                                 AND SL.Loc = tp.loc -- ISNULL(tp.Loc, rp.fromloc)
                                 AND SL.Sku = tp.Sku
   JOIN LOC L WITH (NOLOCK) ON L.Loc = SL.Loc
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey  = SL.Storerkey
                           AND S.Sku = SL.Sku
   JOIN PACK PK WITH (NOLOCK) ON S.Packkey = PK.Packkey
   JOIN (SELECT Storerkey,
                Sku,
                Loc,
                ID,
                SUM(Qty-QtyAllocated-QtyPicked ) Qty,
                SUM(Qty) StockQty,
                Lot
                FROM LOTxLOCxID WITH (NOLOCK)
                GROUP BY Storerkey, Sku, Loc, ID, Lot) LLI
   ON  LLI.Storerkey = SL.Storerkey
   AND LLI.Sku = SL.Sku
   AND LLI.Loc = SL.Loc
   WHERE SL.LocationType <> 'PICK'
   AND LLI.StockQty > 0

   -- RepLENbutNotPick: Get records that need to RepLENish but not Pick in the LP
   SELECT DISTINCT trep.Storerkey, trep.Sku, trep.FromLoc as Loc, Trep.ID, Trep.ReplQty as Qty, Trep.Lot
   INTO #temprp
   FROM #temprepl trep
   LEFT OUTER JOIN #tempskuxloc tsl ON trep.Storerkey = tsl.Storerkey
                                   AND trep.Sku       = tsl.Sku
                                   AND trep.FromLoc   = tsl.Loc
                                   AND trep.ID        = tsl.ID
   WHERE tsl.loc IS NULL AND tsl.sku IS NULL

   -- Get Qty avail for RepLENbutNotPick records & Insert these records into #TempSKUXLOC
   INSERT INTO #tempskuxloc (Storerkey, Sku, Loc, ID, Qty, Packkey, Casecnt, Lot,Size)
   SELECT DISTINCT LLI.Storerkey, LLI.Sku, LLI.Loc, LLI.ID, LLI.Qty, PK.Packkey, PK.CaseCnt, LLI.Lot,S.size
   FROM #temprp trp
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = trp.Storerkey AND S.Sku   = trp.Sku
   JOIN PACK PK WITH (NOLOCK) ON S.Packkey = PK.Packkey
   JOIN (SELECT Storerkey,
                Sku,
                Loc,
                ID,
                SUM(Qty-QtyAllocated-QtyPicked ) Qty,
                SUM(Qty) StockQty,
                Lot
                FROM LOTxLOCxID WITH (NOLOCK)
                GROUP BY Storerkey, Sku, Loc, ID, Lot) LLI
   ON LLI.Storerkey = trp.Storerkey
   AND LLI.Sku       = trp.Sku
   AND LLI.Loc       = trp.Loc
   AND LLI.ID        = trp.ID
   AND LLI.Lot       = trp.Lot  --WL
   JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.LOT = LA.LOT
   WHERE LLI.StockQty > 0

   SELECT Storerkey, Sku, Loc, ID, QTY = SUM(Qty), Packkey, CaseCnt, Lot,Size
   INTO  #RESULT
   FROM  #tempskuxloc
   GROUP BY Storerkey, Sku, Loc, ID, Packkey, Casecnt, Lot,size

   SELECT CASE WHEN @c_showskufield = 'N' THEN
               CASE WHEN @c_showdiffskuformat = 'N' THEN
               SUBSTRING(TSL.sku,1,LEN(TSL.sku) - 6) +'-'+SUBSTRING(TSL.sku,LEN(TSL.sku)-5,2)+'-'+SUBSTRING(TSL.sku,LEN(TSL.sku)-3,4)
               ELSE LEFT(TSL.sku,7) +'-'+SUBSTRING(TSL.sku,8,3)+'-'+right(TSL.Sku, len(TSL.Sku)-charindex('-',TSL.Sku)) END
                 ELSE TSL.sku END As SKU,--SOS#134744    --CS02
          TSL.Loc,
          TSL.ID,
          CASE TSL.CaseCnt WHEN 0
             THEN 0
             ELSE CAST(SUM(ISNULL(TSL.Qty,0)+ISNULL(TP.PickQty,0)) / TSL.CaseCnt AS Int)
          END Qty,
          CASE TSL.CaseCnt WHEN 0
             THEN SUM(TSL.Qty + ISNULL(TP.PickQty, 0))
             ELSE SUM(ISNULL(TSL.Qty,0)+ISNULL(TP.PickQty,0)) % CAST(TSL.CaseCnt AS Int)
          END QtyInEA,
          TSL.Packkey,
          TSL.CaseCnt,
          CASE TSL.CaseCnt WHEN 0
             THEN SUM(ISNULL(TP.PickQty,0))
             ELSE CAST(SUM(ISNULL(TP.PickQty,0)) / TSL.CaseCnt AS Int)
          END as PickQty,
          CASE TSL.CaseCnt WHEN 0
             THEN 0
             ELSE CAST(SUM(ISNULL(TRP.ReplQty,0)) / TSL.CaseCnt AS Int)
          END ReplQty,
          CASE TSL.CaseCnt WHEN 0
             THEN SUM(TRP.ReplQty)
             ELSE SUM(ISNULL(TRP.ReplQty,0)) % CAST(TSL.CaseCnt AS Int)
          END ReplQtyInEA,
          ISNULL(TRP.ToLoc, '') AS ToLoc, -- SOS28251
          CASE TSL.CaseCnt WHEN 0
             THEN 0
             --ELSE CAST(SUM((ISNULL(TSL.Qty,0)+ ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))/ TSL.CaseCnt AS Int)
             ELSE CAST((SELECT SUM(Qty - QtyAllocated - QtyPicked - QtyReplen + PendingMoveIN) FROM LOTxLOCxID L (NOLOCK) WHERE L.Loc = TSL.Loc AND L.SKU = TSL.SKU) / TSL.CaseCnt AS Int)
          END CaseBalRtnToRack,
          CASE TSL.CaseCnt WHEN 0
             THEN SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))
             --ELSE (SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0))- ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))) % CAST(TSL.CaseCnt AS Int)
             ELSE (SELECT SUM(Qty - QtyAllocated - QtyPicked - QtyReplen + PendingMoveIN) FROM LOTxLOCxID L (NOLOCK) WHERE L.Loc = TSL.Loc AND L.SKU = TSL.SKU) % CAST(TSL.CaseCnt AS Int)
          END CaseBalRtnToRackInEA,
          '            ' MoveToLoc,
@c_Storerkey    storerkey,
          @c_facility     facility,
          @c_wavekey wavekeystart,
          @c_wavekey wavekeyend,
          TSL.Lot,
          TSL.Size,
          (Select Count(distinct(#result.loc)) from #result WITH (NOLOCK)) Counter,
          CASE WHEN @c_showskufield = 'N'   THEN
             CASE WHEN @c_showField ='N' THEN
                CASE WHEN ISNULL(RTRIM(SKU.busr6),'') <> ''
                THEN '[' + SUBSTRING(SKU.busr6,1,3) + '-'
                + SUBSTRING (SKU.busr6,4, ABS(LEN(SKU.busr6) -7)) + '-'
                + SUBSTRING(SKU.busr6,LEN(SKU.busr6) - 3 , 2)+ '-'
                + SUBSTRING(SKU.busr6, LEN(SKU.busr6) -1,2)
                +'(' + SUBSTRING(RTRIM(LTRIM(SKU.DESCR)),1,3) + ')'
                +']'
                ELSE '[' + ISNULL(RTRIM(SKU.busr6),'') + '(' + SUBSTRING(RTRIM(LTRIM(SKU.DESCR)),1,3) + ')' + ']' END
             ELSE
                '[' + LEFT (SKU.BUSR1, 10) + ']'

          END
          ELSE '' END As OldSku,
          (SELECT LTRIM(RTRIM(ISNULL(Pickzone,''))) FROM LOC (NOLOCK) WHERE LOC = TSL.Loc ) AS FromPickZone,
          (SELECT LTRIM(RTRIM(ISNULL(Pickzone,''))) FROM LOC (NOLOCK) WHERE LOC = LTRIM(RTRIM(ISNULL(TRP.ToLoc, '')))) AS ToPickZone,
          (SELECT LTRIM(RTRIM(ISNULL(LocationRoom,''))) FROM LOC (NOLOCK) WHERE LOC = TSL.Loc) AS FromLocationRoom,
          (SELECT LTRIM(RTRIM(ISNULL(LocationRoom,''))) FROM LOC (NOLOCK) WHERE LOC = LTRIM(RTRIM(ISNULL(TRP.ToLoc, '')))) AS ToLocationRoom,
          (SELECT LTRIM(RTRIM(ISNULL(LocationGroup,''))) FROM LOC (NOLOCK) WHERE LOC = TSL.Loc) AS FromLocationGroup,
          (SELECT LTRIM(RTRIM(ISNULL(LocationGroup,''))) FROM LOC (NOLOCK) WHERE LOC = LTRIM(RTRIM(ISNULL(TRP.ToLoc, '')))) AS ToLocationGroup,
          (SELECT LTRIM(RTRIM(ISNULL(LocationType,''))) FROM LOC (NOLOCK) WHERE LOC = TSL.Loc) AS FromLocationType,
          (SELECT LTRIM(RTRIM(ISNULL(LocationType,''))) FROM LOC (NOLOCK) WHERE LOC = LTRIM(RTRIM(ISNULL(TRP.ToLoc, '')))) AS ToLocationType
   INTO  #RESULT2
   FROM  #RESULT TSL
   LEFT OUTER JOIN #temppick TP ON TP.Storerkey = TSL.Storerkey
                               AND TP.Sku = TSL.Sku
                               AND TP.Loc = TSL.Loc
                               AND TP.ID  = TSL.ID
                               AND TP.Lot = TSL.Lot
   LEFT OUTER JOIN #temprepl TRP ON TRP.Storerkey = TSL.Storerkey
                                AND TRP.Sku       = TSL.Sku
                                AND TRP.FromLoc   = TSL.Loc
                                AND TRP.ID        = TSL.ID
                                AND TRP.Lot       = TSL.Lot
   INNER JOIN SKU SKU ON  SKU.Storerkey = TSL.Storerkey AND SKU.Sku      = TSL.Sku
   GROUP BY  TSL.Sku, TSL.Loc, TSL.ID, TSL.Packkey, TSL.CaseCnt, TRP.ToLoc, TSL.Lot,TSL.Size,sku.busr6,sku.descr,LEFT (SKU.BUSR1, 10)
   HAVING SUM(ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) > 0
   OR SUM(ISNULL(TP.PickQty,0)) > 0
   OR SUM(ISNULL(TRP.ReplQty,0)) > 0
   OR SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) + ISNULL(TP.PickQty,0) + ISNULL(TRP.ReplQty,0)) > 0
   ORDER BY  TSL.Loc, TSL.ID, TSL.Sku, CaseBalRtnToRack

   SELECT Storerkey, SKU, Loc, Packkey, SUM(PickQty) AS PickQty, Sum(ReplQty) AS ReplQty
        , Sum(ReplQtyInEA) AS ReplQtyInEA
        , ToLoc
        , CaseBalRtnToRack AS CaseBalRtnToRack
        , CaseBalRtnToRackInEA AS CaseBalRtnToRackInEA
        , Facility, Wavekeystart, Wavekeyend
        , Size, [Counter], OldSku
        , ISNULL(FromPickZone,'') AS FromPickZone
        , ISNULL(ToPickZone,'') AS ToPickZone
        , ISNULL(FromLocationRoom,'') AS FromLocationRoom
        , ISNULL(ToLocationRoom,'') AS ToLocationRoom
        , ISNULL(FromLocationGroup,'') AS FromLocationGroup
        , ISNULL(ToLocationGroup,'') AS ToLocationGroup
        , ISNULL(FromLocationType,'') AS FromLocationType
        , ISNULL(ToLocationType,'') AS ToLocationType
   FROM #RESULT2 L
   --WHERE LOC =   '848-40-05'
   GROUP BY Storerkey, SKU, Loc, Packkey, ToLoc
          , Facility, Wavekeystart, Wavekeyend
          , Size, [Counter], OldSku
          , ISNULL(FromPickZone,'')
          , ISNULL(ToPickZone,'')
          , ISNULL(FromLocationRoom,'')
          , ISNULL(ToLocationRoom,'')
          , ISNULL(FromLocationGroup,'')
          , ISNULL(ToLocationGroup,'')
          , ISNULL(FromLocationType,'')
          , ISNULL(ToLocationType,'')
          , CaseBalRtnToRack
          , CaseBalRtnToRackInEA
   HAVING (SUM(PickQty) + SUM(ReplQty) + SUM(ReplQtyInEA) +
           SUM(CaseBalRtnToRack) + SUM(CaseBalRtnToRackInEA) ) > 0
   ORDER BY ISNULL(FromLocationRoom,''),ISNULL(FromLocationGroup,''),
            ISNULL(FromLocationType,''),
            Loc, Sku, SUM(PickQty) DESC, Sum(CaseBalRtnToRack)  --SY01


   --select LLI.Loc, LLI.SKU, CAST(SUM(LLI.Qty-QtyAllocated-QtyPicked-QtyReplen+PendingMoveIn) / PACK.CASECNT AS INT)  from lotxlocxid lli (nolock)
   --Join #RESULT2 L (NOLOCK) ON L.Loc = LLI.LOC
   --JOIN PACK (NOLOCK) ON PACK.PACKKEY = L.Packkey
   --group by LLI.LOC, LLI.sku,PACK.CASECNT
   --ORDER BY LLI.LOC, LLI.SKU

   --SELECT #RESULT2.Storerkey, #RESULT2.SKU,
   --       #RESULT2.Loc,
   --       #RESULT2.Packkey, SUM(#RESULT2.PickQty) PickQty, Sum(#RESULT2.ReplQty) ReplQty,
   --       Sum(#RESULT2.ReplQtyInEA) ReplQtyInEA, #RESULT2.ToLoc,
   --       Sum(#RESULT2.CaseBalRtnToRack) CaseBalRtnToRack, Sum(#RESULT2.CaseBalRtnToRackInEA) CaseBalRtnToRackInEA,
   --       #RESULT2.facility, #RESULT2.Wavekeystart, #RESULT2.Wavekeyend,
   --       #RESULT2.size,#RESULT2.Counter,#RESULT2.OldSku,
   --       ISNULL(#RESULT2.FromPickZone,'')  AS FromPickZone,
   --       ISNULL(#RESULT2.ToPickZone,'')    AS ToPickZone,
   --       ISNULL(#RESULT2.FromLocationRoom,'')  AS FromLocationRoom,
   --       ISNULL(#RESULT2.ToLocationRoom,'')  AS ToLocationRoom,
   --       ISNULL(#RESULT2.FromLocationGroup,'') AS FromLocationGroup,
   --       ISNULL(#RESULT2.ToLocationGroup,'') AS ToLocationGroup,
   --       ISNULL(#RESULT2.FromLocationType,'') AS FromLocationType,
   --       ISNULL(#RESULT2.ToLocationType,'') AS ToLocationType
   --FROM #RESULT2
   --LEFT JOIN pack ON #RESULT2.Packkey = pack.packkey
   --WHERE #RESULT2.LOC =   '0008-1037'
   --GROUP BY #RESULT2.Storerkey, #RESULT2.Sku,
   --         #RESULT2.Loc, #RESULT2.ID, #RESULT2.Packkey,
   --         #RESULT2.ToLoc, #RESULT2.facility, #RESULT2.Wavekeystart, #RESULT2.Wavekeyend,
   --         #RESULT2.size,#RESULT2.Counter,#RESULT2.OldSku,
   --         ISNULL(#RESULT2.FromPickZone,''),
   --         ISNULL(#RESULT2.ToPickZone,''),
   --         ISNULL(#RESULT2.FromLocationRoom,''),
   --         ISNULL(#RESULT2.ToLocationRoom,''),
   --         ISNULL(#RESULT2.FromLocationGroup,''),
   --         ISNULL(#RESULT2.ToLocationGroup,''),
   --         ISNULL(#RESULT2.FromLocationType,''),
   --         ISNULL(#RESULT2.ToLocationType,'')
   ----ORDER BY ISNULL(#RESULT2.FromLocationRoom,''),ISNULL(#RESULT2.ToLocationRoom,''),ISNULL(#RESULT2.FromLocationGroup,''),ISNULL(#RESULT2.ToLocationGroup,''),
   ----         --ISNULL(#RESULT2.FromPickZone,''),ISNULL(#RESULT2.ToPickZone,''),
   ----         ISNULL(#RESULT2.FromLocationType,''),ISNULL(#RESULT2.ToLocationType,''),
   ----         #RESULT2.Loc, #RESULT2.ID, #RESULT2.Sku, Sum(#RESULT2.CaseBalRtnToRack)
   --HAVING (SUM(#RESULT2.PickQty) + SUM(#RESULT2.ReplQty) + SUM(#RESULT2.ReplQtyInEA) +
   --        SUM(#RESULT2.CaseBalRtnToRack) + SUM(#RESULT2.CaseBalRtnToRackInEA) ) > 0
   --ORDER BY ISNULL(#RESULT2.FromLocationRoom,''),ISNULL(#RESULT2.FromLocationGroup,''),
   --         ISNULL(#RESULT2.FromLocationType,''),
   --         #RESULT2.Loc, #RESULT2.ID, #RESULT2.Sku, Sum(#RESULT2.CaseBalRtnToRack)

   IF OBJECT_ID('tempdb..#tempskuxloc') IS NOT NULL
      DROP TABLE #tempskuxloc

   IF OBJECT_ID('tempdb..#temppick') IS NOT NULL
      DROP TABLE #temppick

   IF OBJECT_ID('tempdb..#temprepl') IS NOT NULL
      DROP TABLE #temprepl

   IF OBJECT_ID('tempdb..#temprp') IS NOT NULL
      DROP TABLE #temprp

   IF OBJECT_ID('tempdb..#result') IS NOT NULL
      DROP TABLE #result

   IF OBJECT_ID('tempdb..#result2') IS NOT NULL
      DROP TABLE #result2

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, "isp_ReplenishLetdown_rpt13"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End Procedure

GO