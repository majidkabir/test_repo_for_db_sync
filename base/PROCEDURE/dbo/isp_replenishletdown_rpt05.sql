SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_ReplenishLetdown_rpt05                          */
/* Creation Date: 28-Sep-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#225978 - UMBRO Replenishment Let down report            */
/*                     - Combination of Consolidated pick and           */
/*                       Replenishment report                           */
/*                                                                      */
/* Called By: r_dw_replenishmentletdown_rpt05                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/

CREATE PROC [dbo].[isp_ReplenishLetdown_rpt05] (
            @c_Storerkey    NVARCHAR(15)
          , @c_facility     NVARCHAR(5)
          , @c_loadkeystart NVARCHAR(10)
          , @c_loadkeyend   NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_sku              NVARCHAR(20)  
         , @c_id               NVARCHAR(18)  
         , @c_lot              NVARCHAR(10)  
         , @c_loc              NVARCHAR(10)  
         , @c_toloc            NVARCHAR(10)  
         , @n_qtyrepl          INT       
         , @n_svalue           INT       
         , @c_RepLenishmentKey NVARCHAR(10)  
         , @c_uom              NVARCHAR(10)  
         , @c_packkey          NVARCHAR(10)  
         , @b_success          INT       
         , @n_err              INT       
         , @n_continue         INT  
         , @c_errmsg           NVARCHAR(255) 
         , @n_starttcnt        INT

   SELECT Storerkey  = ISNULL(RTRIM(PD.Storerkey),'')
         ,Sku        = ISNULL(RTRIM(PD.Sku),'')
         ,Loc        = ISNULL(RTRIM(PD.Loc),'')
         ,ID         = ISNULL(RTRIM(PD.ID),'')
         ,PickQty    = ISNULL(SUM(PD.Qty),0) 
         ,Lot        = ISNULL(RTRIM(PD.Lot),'')
   INTO #temppick
   FROM PICKDETAIL   PD WITH (NOLOCK)
   JOIN ORDERDETAIL  OD WITH (NOLOCK)  ON (OD.Orderkey = PD.Orderkey)
                                       AND(OD.OrderLineNumber = PD.OrderLineNumber)
                                       AND(OD.sku  = PD.sku)
                                       AND(OD.Storerkey = PD.Storerkey)
   JOIN ORDERS ORD      WITH (NOLOCK)  ON (OD.Orderkey = ORD.Orderkey)
   JOIN SKUxLOC SL      WITH (NOLOCK)  ON (PD.Storerkey = SL.Storerkey)
                                       AND(PD.Sku = SL.Sku)
                                       AND(PD.Loc = SL.Loc)
   JOIN LOC L           WITH (NOLOCK)  ON (L.Loc = SL.LOC)
   WHERE ORD.LoadKey >= @c_loadkeystart
   AND   ORD.LoadKey <= @c_loadkeyend
   AND   ORD.Facility = @c_facility
   AND   ORD.Status in ('1','2')
   AND   SL.LocationType <> 'PICK'
   AND   PD.StorerKey = @c_storerkey
   GROUP BY ISNULL(RTRIM(PD.Storerkey),'')
         ,  ISNULL(RTRIM(PD.Sku),'')
         ,  ISNULL(RTRIM(PD.Loc),'')
         ,  ISNULL(RTRIM(PD.ID),'')
         ,  ISNULL(RTRIM(PD.Lot),'')


   SELECT Storerkey  = ISNULL(RTRIM(RP.Storerkey),'')
         ,Sku        = ISNULL(RTRIM(RP.Sku),'')
         ,FromLoc    = ISNULL(RTRIM(RP.FromLoc),'')   
         ,ID         = ISNULL(RTRIM(RP.ID),'')   
         ,ToLoc      = ISNULL(RTRIM(RP.ToLoc),'')   
         ,ReplQty    = ISNULL(SUM(RP.Qty),0) 
         ,Lot        = ISNULL(RTRIM(RP.Lot),'')  
   INTO #temprepl
   FROM REPLENISHMENT RP WITH (NOLOCK) 
   JOIN SKUxLOC SL       WITH (NOLOCK) ON (RP.Storerkey = SL.Storerkey)
                                       AND(RP.Sku       = SL.Sku)
                                       AND(RP.FromLoc   = SL.Loc)
   JOIN LOC L            WITH (NOLOCK) ON (RP.FromLoc   = L.Loc)
   WHERE SL.LocationType <> 'PICK'
   AND   RP.Confirmed = 'N'
   AND   RP.RepLENNo <> 'Y'
   AND   RP.StorerKey = @c_Storerkey
   AND   L.Facility = @c_facility
   GROUP BY ISNULL(RTRIM(RP.Storerkey),'') 
         ,  ISNULL(RTRIM(RP.Sku),'')
         ,  ISNULL(RTRIM(RP.FromLoc),'')
         ,  ISNULL(RTRIM(RP.ID),'')
         ,  ISNULL(RTRIM(RP.ToLoc),'') 
         ,  ISNULL(RTRIM(RP.Lot),'')


   SELECT DISTINCT 
          Storerkey  = ISNULL(RTRIM(LLI.Storerkey),'') 
         ,Sku        = ISNULL(RTRIM(LLI.Sku),'') 
         ,Loc        = ISNULL(RTRIM(LLI.Loc),'') 
         ,ID         = ISNULL(RTRIM(LLI.ID),'') 
         ,Qty        = ISNULL(LLI.Qty,0)
         ,Packkey    = ISNULL(RTRIM(PK.Packkey),'') 
         ,CaseCnt    = ISNULL(PK.CaseCnt,0)
         ,Lot        = ISNULL(RTRIM(LLI.Lot),'') 
   INTO #tempskuxloc
   FROM #temppick tp
   JOIN SKUXLOC SL WITH (NOLOCK) ON (SL.Storerkey = tp.storerkey) 
                                 AND(SL.Sku = tp.Sku) 
                                 AND(SL.Loc = tp.loc) 
   JOIN LOC L      WITH (NOLOCK) ON (L.Loc = SL.Loc)
   JOIN SKU S      WITH (NOLOCK) ON (S.Storerkey  = SL.Storerkey)
                                 AND(S.Sku = SL.Sku)
   JOIN PACK PK    WITH (NOLOCK) ON (S.Packkey = PK.Packkey)
   JOIN (SELECT Storerkey= ISNULL(RTRIM(Storerkey),'') 
               ,Sku      = ISNULL(RTRIM(Sku),'') 
               ,Loc      = ISNULL(RTRIM(Loc),'') 
               ,ID       = ISNULL(RTRIM(ID),'') 
               ,Qty      = ISNULL(SUM(Qty-QtyAllocated-QtyPicked),0) 
               ,StockQty = ISNULL(SUM(Qty),0)  
               ,Lot      = ISNULL(RTRIM(Lot),'')
         FROM LOTxLOCxID WITH (NOLOCK)
         GROUP BY ISNULL(RTRIM(Storerkey),'')
               ,  ISNULL(RTRIM(Sku),'') 
               ,  ISNULL(RTRIM(Lot),'')
               ,  ISNULL(RTRIM(Loc),'')
               ,  ISNULL(RTRIM(ID),'')) LLI
                                 ON  (LLI.Storerkey = SL.Storerkey)
                                 AND (LLI.Sku = SL.Sku)
                                 AND (LLI.Loc = SL.Loc)
   WHERE SL.LocationType <> 'PICK'
     AND LLI.StockQty > 0

   -- RepLENbutNotPick: Get records that need to RepLENish but not Pick in the LP
   SELECT DISTINCT 
           Storerkey = ISNULL(RTRIM(trep.Storerkey),'')
         , Sku       = ISNULL(RTRIM(trep.Sku),'') 
         , Loc       = ISNULL(RTRIM(trep.FromLoc),'')  
         , ID        = ISNULL(RTRIM(Trep.ID),'') 
         , Qty       = ISNULL(Trep.ReplQty,0) 
         , Lot       = ISNULL(RTRIM(Trep.Lot),'') 
   INTO #temprp
   FROM #temprepl trep
   LEFT OUTER JOIN #tempskuxloc tsl ON (trep.Storerkey = tsl.Storerkey)
                                    AND(trep.Sku       = tsl.Sku)
                                    AND(trep.FromLoc   = tsl.Loc)
                                    AND(trep.ID        = tsl.ID)
   WHERE tsl.loc IS NULL AND tsl.sku IS NULL

   -- Get Qty avail for RepLENbutNotPick records & Insert these records into #TempSKUXLOC
   INSERT INTO #tempskuxloc (Storerkey, Sku, Loc, ID, Qty, Packkey, Casecnt, Lot)
   SELECT DISTINCT 
          Storerkey  = ISNULL(RTRIM(LLI.Storerkey),'') 
         ,Sku        = ISNULL(RTRIM(LLI.Sku),'') 
         ,Loc        = ISNULL(RTRIM(LLI.Loc),'') 
         ,ID         = ISNULL(RTRIM(LLI.ID),'') 
         ,Qty        = ISNULL(LLI.Qty,0)
         ,Packkey    = ISNULL(RTRIM(PK.Packkey),'') 
         ,CaseCnt    = ISNULL(PK.CaseCnt,0)
         ,Lot        = ISNULL(RTRIM(LLI.Lot),'') 
   FROM #temprp trp
   JOIN SKU S     WITH (NOLOCK)  ON (S.Storerkey = trp.Storerkey)
                                 AND(S.Sku       = trp.Sku) 
   JOIN PACK PK   WITH (NOLOCK)  ON (S.Packkey   = PK.Packkey)
   JOIN (SELECT Storerkey= ISNULL(RTRIM(Storerkey),'') 
               ,Sku      = ISNULL(RTRIM(Sku),'') 
               ,Loc      = ISNULL(RTRIM(Loc),'') 
               ,ID       = ISNULL(RTRIM(ID),'') 
               ,Qty      = ISNULL(SUM(Qty-QtyAllocated-QtyPicked),0) 
               ,StockQty = ISNULL(SUM(Qty),0)  
               ,Lot      = ISNULL(RTRIM(Lot),'')
         FROM LOTxLOCxID WITH (NOLOCK)
         GROUP BY ISNULL(RTRIM(Storerkey),'')
               ,  ISNULL(RTRIM(Sku),'') 
               ,  ISNULL(RTRIM(Loc),'')
               ,  ISNULL(RTRIM(ID),'')
               ,  ISNULL(RTRIM(Lot),'')) LLI 
                                 ON (LLI.Storerkey = trp.Storerkey)
                                 AND(LLI.Sku       = trp.Sku)
                                 AND(LLI.Loc       = trp.Loc)
                                -- AND(LLI.ID        = trp.ID)
   WHERE LLI.StockQty > 0

   SELECT Storerkey  = ISNULL(RTRIM(Storerkey),'')
         ,Sku        = ISNULL(RTRIM(Sku),'') 
         ,Loc        = ISNULL(RTRIM(Loc),'') 
         ,ID         = ISNULL(RTRIM(ID),'') 
         ,QTY        = ISNULL(SUM(Qty),0)
         ,Packkey    = ISNULL(RTRIM(Packkey),'')
         ,CaseCnt    = ISNULL(CaseCnt,0)
         ,Lot        = ISNULL(RTRIM(Lot),'') 
   INTO  #RESULT
   FROM  #tempskuxloc
   GROUP BY ISNULL(RTRIM(Storerkey),'')
         ,  ISNULL(RTRIM(Sku),'')
         ,  ISNULL(RTRIM(Loc),'')
         ,  ISNULL(RTRIM(ID),'')
         ,  ISNULL(RTRIM(Packkey),'')
         ,  ISNULL(CaseCnt,0)
         ,  ISNULL(RTRIM(Lot),'') 
   

   SELECT SKU = ISNULL(RTRIM(TSL.SKU),'')
               /*CASE WHEN LEN(ISNULL(RTRIM(TSL.SKU),'')) <= 6
                     THEN ISNULL(RTRIM(TSL.SKU),'')
                     ELSE SUBSTRING(ISNULL(RTRIM(TSL.SKU),''),1,LEN(ISNULL(RTRIM(TSL.SKU),'')) - 6) 
                  + '-' + SUBSTRING(ISNULL(RTRIM(TSL.SKU),''),LEN(ISNULL(RTRIM(TSL.SKU),''))-5,2)
                  + '-' + SUBSTRING(ISNULL(RTRIM(TSL.SKU),''),LEN(ISNULL(RTRIM(TSL.SKU),''))-3,4)
                    END*/
         ,SkuDescr = ISNULL(RTRIM(SKU.Descr),'')     
         ,Loc = ISNULL(RTRIM(TSL.Loc),'') 
         ,CaseCnt = ISNULL(TSL.CaseCnt,0)
         ,Qty = CASE ISNULL(TSL.CaseCnt,0) 
                    WHEN 0 THEN 0
                           ELSE CAST(SUM(ISNULL(TSL.Qty,0)+ISNULL(TP.PickQty,0)) / ISNULL(TSL.CaseCnt,0) AS Int)
                    END 
         ,QtyInEA = CASE ISNULL(TSL.CaseCnt,0)
                    WHEN 0 THEN SUM(TSL.Qty + ISNULL(TP.PickQty, 0))
                           ELSE SUM(ISNULL(TSL.Qty,0)+ISNULL(TP.PickQty,0)) % CAST(ISNULL(TSL.CaseCnt,0) AS Int)
                    END 
         ,PickQty = CASE ISNULL(TSL.CaseCnt,0)
                    WHEN 0 THEN SUM(ISNULL(TP.PickQty,0))
                           ELSE CAST(SUM(ISNULL(TP.PickQty,0)) / ISNULL(TSL.CaseCnt,0) AS Int)
                    END 
         ,ReplQty = CASE ISNULL(TSL.CaseCnt,0)
                    WHEN 0 THEN 0
                           ELSE CAST(SUM(ISNULL(TRP.ReplQty,0)) / ISNULL(TSL.CaseCnt,0) AS Int)
                    END  
         ,ReplQtyInEA = CASE ISNULL(TSL.CaseCnt,0)
                        WHEN 0 THEN SUM(TRP.ReplQty)
                               ELSE SUM(ISNULL(TRP.ReplQty,0)) % CAST(ISNULL(TSL.CaseCnt,0) AS Int)
                        END 
         ,ToLoc = ISNULL(MAX(RTRIM(TRP.ToLoc)), '') 
         ,CaseBalRtnToRack  = CASE ISNULL(TSL.CaseCnt,0)
                              WHEN 0 THEN 0
                                     ELSE CAST(SUM((ISNULL(TSL.Qty,0)+ ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))/ ISNULL(TSL.CaseCnt,0) AS Int)
                              END
         ,CaseBalRtnToRackInEA = CASE ISNULL(TSL.CaseCnt,0)
                                 WHEN 0 THEN SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))
                                        ELSE (SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0))- ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))) % CAST(ISNULL(TSL.CaseCnt,0) AS Int)
                                 END 
         ,Storerkey    = @c_Storerkey 
         ,facility     = @c_facility      
         ,loadkeystart = @c_loadkeystart  
         ,loadkeyend   = @c_loadkeyend    
         ,Counter      = (Select Count(distinct(#result.loc)) from #result WITH (NOLOCK))
   INTO #RESULT2
   FROM #RESULT TSL
   LEFT OUTER JOIN #temppick TP     ON (TP.Storerkey = TSL.Storerkey)
                                    AND(TP.Sku = TSL.Sku)
                                    AND(TP.Lot = TSL.Lot)
                                    AND(TP.Loc = TSL.Loc)
                                    AND(TP.ID  = TSL.ID)

   LEFT OUTER JOIN #temprepl TRP       
                                    ON (TRP.Storerkey = TSL.Storerkey)
                                    AND(TRP.Sku       = TSL.Sku)
                                    AND(TRP.Lot       = TSL.Lot)
                                    AND(TRP.FromLoc   = TSL.Loc)
                                    AND(TRP.ID        = TSL.ID)

   INNER JOIN SKU SKU WITH (NOLOCK) ON (SKU.Storerkey = TSL.Storerkey)
                                    AND(SKU.Sku       = TSL.Sku)
   GROUP BY ISNULL(RTRIM(TSL.SKU),'')
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  ISNULL(RTRIM(TSL.Loc),'')
         ,  ISNULL(TSL.CaseCnt,0)
         --,  ISNULL(RTRIM(TRP.ToLoc),'')
   HAVING SUM(ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) > 0
   OR SUM(ISNULL(TP.PickQty,0)) > 0
   OR SUM(ISNULL(TRP.ReplQty,0)) > 0
   OR SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) + ISNULL(TP.PickQty,0) + ISNULL(TRP.ReplQty,0)) > 0
   ORDER BY ISNULL(RTRIM(TSL.Loc),'')
         ,  ISNULL(RTRIM(TSL.SKU),'')
         --,  ISNULL(RTRIM(TRP.ToLoc),'')

   IF @n_continue=3  -- Error Occured - Process AND Return
      BEGIN
         SET @b_success = 0
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ReplenishLetdown_rpt05'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END

   SELECT #RESULT2.Storerkey
         ,#RESULT2.Sku
         ,#RESULT2.SkuDescr
         ,#RESULT2.Loc
         ,#RESULT2.CaseCnt
         ,#RESULT2.PickQty
         ,#RESULT2.ReplQty
         ,#RESULT2.ReplQtyInEA
         ,#RESULT2.ToLoc
         ,#RESULT2.CaseBalRtnToRack
         ,#RESULT2.CaseBalRtnToRackInEA
         ,#RESULT2.facility
         ,#RESULT2.loadkeystart
         ,#RESULT2.loadkeyend
         ,#RESULT2.Counter
   FROM #RESULT2 
   ORDER BY #RESULT2.Loc
         ,  #RESULT2.Sku
         ,  #RESULT2.ToLoc

   Drop table #tempskuxloc
   Drop table #temppick
   Drop table #temprepl
   Drop table #temprp
   Drop table #result

END -- End Procedure

GO