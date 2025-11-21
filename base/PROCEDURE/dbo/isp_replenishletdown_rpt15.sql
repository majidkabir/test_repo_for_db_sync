SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure: isp_ReplenishLetdown_rpt15                          */  
/* Creation Date: 18-May-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-17054 - [CN] Converse Letdown View Report CR            */    
/*                     (Duplicate from isp_ReplenishLetdown_rpt14)      */  
/*                                                                      */  
/* Input Parameters: Facility, WavekeyStart, WavekeyEnd                 */  
/*                                                                      */  
/* Output Parameters: Report                                            */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: r_dw_replenishletdown_rpt15                               */  
/*                                                                      */  
/* GitLab Version: 1.3                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver. Purposes                                 */  
/* 2021-07-27   WLChooi   1.0  Fix - Modify Filter (WL01)               */
/* 2021-07-28   WLChooi   1.1  Fix - Modify Logic advised by LIT (WL02) */
/* 2021-07-29   WLChooi   1.2  Fix - Modify Logic advised by LIT (WL03) */
/* 2021-11-08   WLChooi   1.3  DevOps Combine Script                    */
/* 2021-11-08   WLChooi   1.3  WMS-18271 - Modify Logic (WL04)          */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ReplenishLetdown_rpt15] (
         @c_Facility     NVARCHAR(5)  
       , @c_Wavekey      NVARCHAR(10)  )
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_starttcnt          INT  
         , @n_continue           INT  
         , @b_success            INT   
         , @n_err                INT   
         , @c_errmsg             NVARCHAR(255)   
  
         , @c_ReplenishmentKey   NVARCHAR(10)   
         , @c_storerkey          NVARCHAR(15)  
         , @c_sku                NVARCHAR(20)  
         , @c_lot                NVARCHAR(10)   
         , @c_loc                NVARCHAR(10)  
         , @c_id                 NVARCHAR(18)  
         , @c_packkey            NVARCHAR(10)   
         , @c_uom                NVARCHAR(10)   
         , @c_toloc              NVARCHAR(10)  
         , @n_qtyrepl            INT   
  
  
   SET @n_starttcnt        = @@TRANCOUNT  
   SET @n_continue         = ''  
   SET @b_success          = 1  
   SET @n_err              = 0  
   SET @c_errmsg           = ''  
  
   SET @c_ReplenishmentKey = ''  
   SET @c_storerkey        = ''  
   SET @c_sku              = ''  
   SET @c_lot              = ''  
   SET @c_loc              = ''  
   SET @c_id               = ''  
   SET @c_packkey          = ''  
   SET @c_uom              = ''  
   SET @c_toloc            = ''  
   SET @n_qtyrepl          = 0  
   
   SELECT ISNULL(RTRIM(PD.Storerkey),'')  AS Storerkey  
        , ISNULL(RTRIM(PD.Sku),'')        AS Sku  
        , ISNULL(RTRIM(PD.Loc),'')        AS Loc  
        , ISNULL(RTRIM(PD.ID),'')         AS ID  
        , ISNULL(SUM(CASE WHEN PD.UOM = 6 AND WV.WAVETYPE = '1' THEN 0 ELSE PD.Qty END),0) AS PickQty   --WL02
        , ISNULL(RTRIM(PD.Lot),'')        AS Lot  
        , ISNULL(RTRIM(LA.Lottable02),'') AS Lottable02  
        , ISNULL(SUM(CASE WHEN PD.UOM = 6 AND WV.WAVETYPE = '1' THEN PD.Qty ELSE 0 END),0) AS RplQty   --WL02
        , ISNULL(SUM(PD.Qty),0) AS TotalPick   --WL04
   INTO #temppick  
   FROM WAVEDETAIL WD WITH (NOLOCK) 
   JOIN PICKDETAIL PD WITH (NOLOCK)       ON (PD.Orderkey  = WD.Orderkey)  
   JOIN SKUxLOC    SL WITH (NOLOCK)       ON (SL.Storerkey = PD.Storerkey)   
                                          AND(SL.Sku       = PD.Sku)   
                                          AND(SL.Loc       = PD.Loc)  
   JOIN ORDERS     OH WITH (NOLOCK)       ON (OH.OrderKey  = WD.OrderKey)
   JOIN LOTATTRIBUTE LA WITH (NOLOCK)     ON (LA.LOT       = PD.LOT)  
   JOIN WAVE WV WITH (NOLOCK)             ON (WD.WAVEKEY   = WV.WAVEKEY)   --WL02
   WHERE WD.WaveKey  = @c_Wavekey  
   AND   OH.Facility = @c_Facility   
   AND   SL.LocationType <> 'CASE'  
   AND   SL.LocationType <> 'PICK'  
   --AND   PD.Status < '5'  
   AND   LA.Lottable01 IN ('10','20','30')  
   GROUP BY ISNULL(RTRIM(PD.Storerkey),'')  
          , ISNULL(RTRIM(PD.Sku),'')  
          , ISNULL(RTRIM(PD.Loc),'')  
          , ISNULL(RTRIM(PD.ID),'')  
          , ISNULL(RTRIM(PD.Lot),'')  
          , ISNULL(RTRIM(LA.Lottable02),'')  

   --WL04 S
   ------NEW ADD HISTORERY PICK   
   SELECT ISNULL(RTRIM(PD.Storerkey),'')  AS Storerkey  
        , ISNULL(RTRIM(PD.Sku),'')        AS Sku  
        , ISNULL(RTRIM(PD.Loc),'')        AS Loc  
        , ISNULL(RTRIM(PD.ID),'')         AS ID  
        , ISNULL(SUM(CASE WHEN PD.UOM = 6 AND WV.WAVETYPE = '1' THEN 0 ELSE PD.Qty END),0) AS PickQty
        , ISNULL(RTRIM(PD.Lot),'')        AS Lot  
        , ISNULL(RTRIM(LA.Lottable02),'') AS Lottable02  
        , ISNULL(SUM(CASE WHEN PD.UOM = 6 AND WV.WAVETYPE = '1' THEN PD.Qty ELSE 0 END),0) AS RplQty 
        , ISNULL(SUM(PD.Qty),0) AS TotalPick    
   INTO #temppick_His  
   FROM WAVEDETAIL WD WITH (NOLOCK) 
   JOIN PICKDETAIL PD WITH (NOLOCK)       ON (PD.Orderkey  = WD.Orderkey)  
   JOIN SKUxLOC    SL WITH (NOLOCK)       ON (SL.Storerkey = PD.Storerkey)   
                                          AND(SL.Sku       = PD.Sku)   
                                          AND(SL.Loc       = PD.Loc)  
   JOIN ORDERS     OH WITH (NOLOCK)       ON (OH.OrderKey  = WD.OrderKey)
   JOIN LOTATTRIBUTE LA WITH (NOLOCK)     ON (LA.LOT       = PD.LOT)  
   JOIN WAVE WV WITH (NOLOCK)             ON (WD.WAVEKEY   = WV.WAVEKEY)   --WL02
   WHERE WD.WaveKey  <> @c_Wavekey  
   AND   OH.Facility = @c_Facility   
   AND   SL.LocationType <> 'CASE'  
   AND   SL.LocationType <> 'PICK'  
   AND   PD.[Status] < '9'  
   AND   LA.Lottable01 IN ('10','20','30')  
   GROUP BY ISNULL(RTRIM(PD.Storerkey),'')  
          , ISNULL(RTRIM(PD.Sku),'')  
          , ISNULL(RTRIM(PD.Loc),'')  
          , ISNULL(RTRIM(PD.ID),'')  
          , ISNULL(RTRIM(PD.Lot),'')  
          , ISNULL(RTRIM(LA.Lottable02),'')  
   --WL04 E
  
   SELECT ISNULL(RTRIM(RP.Storerkey),'')  AS Storerkey  
        , ISNULL(RTRIM(RP.Sku),'')        AS Sku  
        , ISNULL(RTRIM(RP.FromLoc),'')    AS FromLoc  
        , ISNULL(RTRIM(RP.ID),'')         AS ID  
        , ISNULL(RTRIM(RP.ToLoc),'')      AS ToLoc  
        , ISNULL(SUM(RP.Qty),0)           AS ReplQty  
        , ISNULL(RTRIM(RP.Lot),'')        AS Lot  
   INTO #temprepl  
   FROM REPLENISHMENT RP WITH (NOLOCK)  
   JOIN SKUxLOC SL WITH (NOLOCK)    ON (SL.Storerkey = RP.Storerkey)   
                                    AND(SL.Sku       = RP.Sku)   
                                    AND(SL.Loc       = RP.FromLoc)  
   JOIN LOC L WITH (NOLOCK)         ON (L.Loc        = RP.FromLoc)  
   WHERE SL.LocationType <> 'CASE'  
   AND   SL.LocationType <> 'PICK'  
   AND   RP.Confirmed = 'N'  
   AND   RP.ReplenNo <> 'Y'   
   AND   L.Facility = @c_Facility  
   GROUP BY ISNULL(RTRIM(RP.Storerkey),'')  
          , ISNULL(RTRIM(RP.Sku),'')  
          , ISNULL(RTRIM(RP.FromLoc),'')  
          , ISNULL(RTRIM(RP.ID),'')  
          , ISNULL(RTRIM(RP.ToLoc),'')  
          , ISNULL(RTRIM(RP.Lot),'')  
  
   SELECT DISTINCT   
          ISNULL(RTRIM(LLI.Storerkey),'') AS Storerkey  
        , ISNULL(RTRIM(LLI.Sku),'')       AS Sku  
        , ISNULL(RTRIM(LLI.Loc),'')       AS Loc  
        , ISNULL(RTRIM(LLI.ID),'')        AS ID  
        --, ISNULL(LLI.Qty-LLI.QtyAllocated-LLI.QtyPicked,0)   AS Qty   --WL04  
        , ISNULL(LLI.Qty,0)               AS Qty   --WL04
        , ISNULL(RTRIM(PK.Packkey),'')    AS Packkey  
        , ISNULL(PK.CaseCnt,0)            AS CaseCnt  
        , ISNULL(RTRIM(LLI.Lot),'')       AS Lot  
        , ISNULL(RTRIM(tp.Lottable02),'') AS Lottable02  
   INTO #tempskuxloc  
   FROM #temppick tp  
   JOIN SKUXLOC SL WITH (NOLOCK) ON (SL.Storerkey = tp.Storerkey)    
                                 AND(SL.Loc       = tp.loc)     
                                 AND(SL.Sku       = tp.Sku)   
   JOIN SKU S WITH (NOLOCK)      ON (S.Storerkey  = SL.Storerkey)   
                                 AND(S.Sku        = SL.Sku)   
   JOIN PACK PK WITH (NOLOCK)    ON (S.Packkey    = PK.Packkey)  
   JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.Storerkey = SL.Storerkey)   
                                     AND(LLI.Sku         = SL.Sku)  
                                     AND(LLI.Loc         = SL.Loc)  
   WHERE SL.LocationType <> 'CASE'  
   AND   SL.LocationType <> 'PICK'  
   --AND   LLI.Qty > 0   --WL04  
   AND   (LLI.Qty + LLI.QtyAllocated + LLI.QtyPicked) > 0   --WL04
   --AND tp.PickQty % CAST(ISNULL(PK.CaseCnt,0) AS INT)  = 0  --WL04
  
  
   -- ReplenbutNotPick: Get records that need to Replenish but not Pick in the Wave  
   SELECT DISTINCT   
          ISNULL(RTRIM(trep.Storerkey),'')AS Storerkey  
         ,ISNULL(RTRIM(trep.Sku),'')      AS Sku   
         ,ISNULL(RTRIM(trep.FromLoc),'')  AS Loc  
         ,ISNULL(RTRIM(Trep.ID),'')       AS ID  
         ,ISNULL(Trep.ReplQty,0)          AS Qty  
         ,ISNULL(RTRIM(Trep.Lot),'')      AS Lot  
   INTO #temprp  
   FROM #temprepl trep  
   LEFT OUTER JOIN #tempskuxloc tsl ON (tsl.Storerkey = trep.Storerkey)  
                                    AND(tsl.Sku       = trep.Sku)  
                                    AND(tsl.Loc       = trep.FromLoc)  
                                    AND(tsl.ID        = trep.ID)  
   WHERE tsl.loc IS NULL AND tsl.sku IS NULL  
  
   -- Get Qty avail for ReplenbutNotPick records & Insert these records into #TempSKUXLOC  
   INSERT INTO #tempskuxloc (Storerkey, Sku, Loc, ID, Qty, Packkey, Casecnt, Lot, Lottable02)  
   SELECT DISTINCT   
          ISNULL(RTRIM(LLI.Storerkey),'') AS Storerkey  
         ,ISNULL(RTRIM(LLI.Sku),'')       AS Sku  
         ,ISNULL(RTRIM(LLI.Loc),'')       AS Loc  
         ,ISNULL(RTRIM(LLI.ID),'')        AS ID  
         --,ISNULL(LLI.Qty-LLI.QtyAllocated-LLI.QtyPicked,0) AS Qty   --WL04  
         ,ISNULL(LLI.Qty,0)               AS Qty   --WL04
         ,ISNULL(RTRIM(PK.Packkey),'')    AS Packkey  
         ,ISNULL(PK.CaseCnt,0)            AS CaseCnt  
         ,ISNULL(RTRIM(LLI.Lot),'')       AS Lot  
         ,ISNULL(RTRIM(LA.Lottable02),'') AS Lottable02     
   FROM #temprp trp  
   JOIN SKU S   WITH (NOLOCK) ON (S.Storerkey = trp.Storerkey)   
                              AND(S.Sku       = trp.Sku)   
   JOIN PACK PK WITH (NOLOCK) ON (PK.Packkey  = S.Packkey)  
   JOIN LOTxLOCxID LLI  WITH (NOLOCK) ON (LLI.Storerkey = trp.Storerkey)   
                                      AND(LLI.Sku = trp.Sku)  
                                      AND(LLI.Loc = trp.Loc)  
                                      AND(LLI.ID  = trp.ID)  
   JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)  
   WHERE  (LLI.Qty + LLI.QtyAllocated + LLI.QtyPicked) > 0      --WL04
  
   -- NoReplnPick: Get other SKU wh has no Replen & Pick But sit at loc that has Pick/Replen  
   SELECT DISTINCT LOC   
   INTO #tempsameloc   
   FROM #tempskuxloc   
  
   INSERT INTO #tempskuxloc (Storerkey, Sku, Loc, ID, Qty, Packkey, Casecnt, Lot, Lottable02)  
   SELECT ISNULL(RTRIM(LLI.Storerkey),'') AS Storerkey  
         ,ISNULL(RTRIM(LLI.Sku),'')       AS Sku   
         ,ISNULL(RTRIM(LLI.LOC),'')       AS LOC  
         ,ISNULL(RTRIM(LLI.ID),'')        AS ID  
         --,ISNULL(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked, 0) AS Qty   --WL04  
         ,ISNULL(LLI.Qty, 0)              AS Qty   --WL04  
         ,ISNULL(RTRIM(S.Packkey),'')     AS Packkey  
         ,ISNULL(PK.Casecnt,0)            AS Casecnt  
         ,ISNULL(RTRIM(LLI.Lot),'')       AS Lot    
         ,ISNULL(RTRIM(LA.Lottable02),'') AS Lottable02  
   FROM #tempsameloc tsl  
   JOIN LOTXLOCXID LLI  WITH (NOLOCK) ON (LLI.Loc = tsl.Loc)  
   JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.LOT  = LLI.LOT)  
   JOIN SKU S     WITH (NOLOCK)  ON (S.Storerkey  = LLI.Storerkey) AND (S.Sku = LLI.Sku)   
   JOIN PACK PK   WITH (NOLOCK)  ON (PK.Packkey   = S.Packkey)  
   LEFT JOIN #tempskuxloc sl     ON (sl.Storerkey = LLI.Storerkey)   
                                 AND(sl.Sku = LLI.Sku)  
                                 AND(sl.Loc = LLI.Loc)   
                                 AND(sl.ID = LLI.ID)  
   WHERE sl.SKU IS NULL
    
   SELECT ISNULL(RTRIM(Storerkey),'')  AS Storerkey  
         ,ISNULL(RTRIM(Sku),'')        AS Sku  
         ,ISNULL(RTRIM(Loc),'')        AS Loc  
         ,ISNULL(RTRIM(ID),'')         AS ID  
         ,ISNULL(SUM(Qty),0)           AS Qty  
         ,ISNULL(RTRIM(Packkey),'')    AS Packkey  
         ,ISNULL(CaseCnt,0)            AS CaseCnt  
         ,ISNULL(RTRIM(Lot),'')        AS Lot  
         ,ISNULL(RTRIM(Lottable02),'') AS Lottable02     
   INTO  #RESULT  
   FROM  #tempskuxloc  
   GROUP BY ISNULL(RTRIM(Storerkey),'')   
           ,ISNULL(RTRIM(Sku),'')          
           ,ISNULL(RTRIM(Loc),'')          
           ,ISNULL(RTRIM(ID),'')          
           ,ISNULL(RTRIM(Packkey),'')      
           ,ISNULL(CaseCnt,0)              
           ,ISNULL(RTRIM(Lot),'')         
           ,ISNULL(RTRIM(Lottable02),'')   
  
   SELECT ISNULL(MIN(RTRIM(TSL.Storerkey)),'') AS Storerkey   
         ,ISNULL(RTRIM(TSL.Sku),'')       AS Sku   
         ,ISNULL(RTRIM(TSL.Loc),'')       AS Loc   
         ,ISNULL(RTRIM(TSL.ID),'')        AS ID  
         ,CASE ISNULL(TSL.CaseCnt,0) WHEN 0  
               THEN 0   
               ---ELSE CAST(ISNULL(SUM(ISNULL(TSL.Qty,0)+ISNULL(TP.PickQty,0)),0) / ISNULL(TSL.CaseCnt,0) AS INT)      --WL04
			   ELSE CAST((ISNULL(SUM(ISNULL(TSL.Qty,0)),0)-ISNULL(SUM(TS.TotalPick),0)) / ISNULL(TSL.CaseCnt,0) AS INT)   --WL04   
          END                             AS Qty   
         ,CASE ISNULL(TSL.CaseCnt,0) WHEN 0  
               THEN ISNULL(SUM(ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)),0)  
               ELSE ISNULL(SUM(ISNULL(TSL.Qty,0)),0) % CAST(ISNULL(TSL.CaseCnt,0) AS INT)   --WL04 
          END                             AS QtyInEA  
         ,ISNULL(RTRIM(TSL.Packkey),'')   AS Packkey  
         ,ISNULL(TSL.CaseCnt,0)           AS CaseCnt  
         ,CASE ISNULL(TSL.CaseCnt,0) WHEN 0  
               THEN ISNULL(SUM(TP.PickQty),0)   
               ELSE CAST(ISNULL(SUM(TP.PickQty),0) / ISNULL(TSL.CaseCnt,0) AS INT)   
           END                            AS PickQty  
         ,CASE ISNULL(TSL.CaseCnt,0) WHEN 0  
               THEN 0   
               ELSE CAST(ISNULL(SUM(ISNULL(TRP.ReplQty,0)),0) / ISNULL(TSL.CaseCnt,0) AS INT)  
          END                             AS ReplQty  
         ,CASE ISNULL(TSL.CaseCnt,0) WHEN 0  
               THEN ISNULL(SUM(TRP.ReplQty),0)  
               ELSE ISNULL(SUM(ISNULL(TRP.ReplQty,0)),0) % CAST(ISNULL(TSL.CaseCnt,0) AS INT)   
          END                             AS ReplQtyInEA   
         ,ISNULL(RTRIM(TRP.ToLoc), '')    AS ToLoc   
         ,CASE ISNULL(TSL.CaseCnt,0) WHEN 0  
               THEN 0  
               --ELSE CAST(ISNULL(SUM((ISNULL(TSL.Qty,0)+ ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0)),0)/ ISNULL(TSL.CaseCnt,0) AS INT)   --WL04                     
			   ELSE CAST((CAST(ISNULL(SUM(ISNULL(TSL.Qty,0)),0) AS INT) - CAST(ISNULL(SUM(TS.TotalPick),0) AS INT) - CAST(ISNULL(SUM(TP.PickQty),0) AS INT) -   --WL04 
                 CAST(ISNULL(SUM(ISNULL(TRP.ReplQty,0)),0) AS INT)) / ISNULL(TSL.CaseCnt,0) AS INT)   --WL04 
          END                             AS CaseBalRtnToRack  
         ,CASE ISNULL(TSL.CaseCnt,0) WHEN 0  
               THEN ISNULL(SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0)),0)  
               --ELSE ISNULL(SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0)),0) % CAST(ISNULL(TSL.CaseCnt,0) AS INT)   --WL03   --WL04 
			   ELSE (CAST(ISNULL(SUM(ISNULL(TSL.Qty,0)),0) AS INT)- CAST(ISNULL(SUM(TS.TotalPick),0) AS INT) - CAST(ISNULL(SUM(TP.PickQty),0) AS INT) -    --WL04 
                 CAST(ISNULL(SUM(ISNULL(TRP.ReplQty,0)),0) AS INT)) % CAST(ISNULL(TSL.CaseCnt,0)  AS INT)   --WL04 
          END                             AS CaseBalRtnToRackInEA    
         ,'            '                  AS MoveToLoc  
         ,@c_Facility                     AS facility  
         ,@c_Wavekey                      AS WavekeyStart  
         ,@c_Wavekey                      AS WavekeyEnd  
         --,ISNULL(RTRIM(TSL.Lot),'')       AS Lot   --WL04   
         ,ISNULL(RTRIM(TSL.Lottable02),'')AS Lottable02      
   INTO  #RESULT2  
   FROM  #RESULT TSL    
   LEFT OUTER JOIN #temppick TP  ON (TP.Storerkey  = TSL.Storerkey)  
                                 AND(TP.Sku        = TSL.Sku)  
                                 AND(TP.Loc        = TSL.Loc)  
                                 AND(TP.ID         = TSL.ID)  
                                 AND(TP.Lot        = TSL.Lot)  
   LEFT OUTER JOIN #temprepl TRP ON (TRP.Storerkey = TSL.Storerkey)  
                                 AND(TRP.Sku       = TSL.Sku)  
                                 AND(TRP.FromLoc   = TSL.Loc)  
                                 AND(TRP.ID        = TSL.ID)  
                                 AND(TRP.Lot       = TSL.Lot)  
   LEFT JOIN LOTATTRIBUTE(NOLOCK) AS LA ON TSL.LOT=LA.LOT
   LEFT JOIN LOC(NOLOCK) AS LOC ON TSL.Loc=LOC.LOC   
   LEFT JOIN #temppick_His AS TS  ON (TSL.Storerkey  = TS.Storerkey)   --WL04 
                                 AND(TSL.Sku        = TS.Sku)  
                                 AND(TSL.Loc        = TS.Loc)  
                                 AND(TSL.ID         = TS.ID)  
                                 AND(TSL.Lot        = TS.Lot) 
   WHERE LA.LOTTABLE01 IN ('10','20','30') AND LOC.LOCATIONGROUP<>'VIRTUAL'  
   GROUP BY ISNULL(RTRIM(TSL.Sku),'')      
         ,  ISNULL(RTRIM(TSL.Loc),'')       
         ,  ISNULL(RTRIM(TSL.ID),'')  
         ,  ISNULL(RTRIM(TSL.Packkey),'')   
         ,  ISNULL(TSL.CaseCnt,0)        
         ,  ISNULL(RTRIM(TRP.ToLoc), '')  
         --,  ISNULL(RTRIM(TSL.Lot),'')   --WL04  
         ,  ISNULL(RTRIM(TSL.Lottable02),'')  
   HAVING ISNULL(SUM(ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)),0) > 0   
       OR ISNULL(SUM(ISNULL(TP.PickQty,0)),0) > 0   
       OR ISNULL(SUM(ISNULL(TRP.ReplQty,0)),0) > 0   
       OR ISNULL(SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) + ISNULL(TP.PickQty,0) + ISNULL(TRP.ReplQty,0)),0) > 0  
   ORDER BY ISNULL(RTRIM(TSL.Loc),'')       
         ,  ISNULL(RTRIM(TSL.ID),'')  
         ,  ISNULL(RTRIM(TSL.Sku),'')  
         ,  CaseBalRtnToRack  
 
   --WL04 S 
   /*
   BEGIN TRANSACTION  
   SET @c_toloc = ''  
  
   IF NOT EXISTS (SELECT 1 FROM #RESULT2  
                  JOIN REPLENISHMENT WITH (NOLOCK) ON (REPLENISHMENT.Storerkey = #RESULT2.Storerkey)  
                                                   AND(REPLENISHMENT.FromLoc = #RESULT2.Loc)  
                                                   AND(REPLENISHMENT.ID = #RESULT2.ID)  
                  WHERE REPLENISHMENT.ReplenishmentGroup = 'IDS'  
                  AND   REPLENISHMENT.Confirmed = 'N'  
                  AND   REPLENISHMENT.ReplenNo  = 'Y' )  
   BEGIN  
      DECLARE Cursor_BBA CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT #RESULT2.Storerkey  
            ,#RESULT2.Loc   
      FROM #RESULT2  
      INNER JOIN StorerConfig SC WITH (NOLOCK) ON (SC.Storerkey = #RESULT2.Storerkey)   
                                               AND(ISNULL(SValue, 0) BETWEEN 1 AND 999)    
                                               AND(Configkey = 'RESIDBAL')  
      INNER JOIN LOC L WITH (NOLOCK) ON (L.Loc = #RESULT2.Loc)   
                                     AND(L.LocationType <> 'BBA')  
      GROUP BY #RESULT2.Storerkey  
             , #RESULT2.Loc  
             , ISNULL(SC.sValue,0)  
      HAVING ISNULL(SUM(CaseBalRtnToRack),0) < ISNULL(SC.sValue,0)  
      OPEN Cursor_BBA  
  
      WHILE (1 = 1) AND (@n_continue = 1)  
      BEGIN  
         FETCH NEXT FROM Cursor_BBA INTO @c_storerkey, @c_loc  
  
         IF @@FETCH_STATUS <> 0 BREAK  
  
         SET ROWCOUNT 1  
         SELECT @c_toloc = ISNULL(RTRIM(LOC.Loc),'')  
         FROM LOC WITH (NOLOCK)  
         LEFT OUTER JOIN SKUxLOC SL WITH (NOLOCK) ON (SL.Storerkey = @c_storerkey)   
                                                  AND(SL.Loc = LOC.Loc)  
         WHERE LOC.LocationType = 'BBA'  
         AND   ISNULL(SL.Qty,0) - ISNULL(SL.Qtypicked,0) = 0  
         AND NOT EXISTS (SELECT 1 FROM #RESULT2 WHERE MoveToloc = LOC.LOC)  
         AND LOC.Facility = @c_Facility    
         ORDER BY ISNULL(RTRIM(LogicalLocation),'')  
                , ISNULL(RTRIM(LOC.Loc),'')  
  
         SET ROWCOUNT 0  
  
         DECLARE Cursor_Repl CURSOR FAST_FORWARD READ_ONLY FOR  
         SELECT #RESULT2.Sku  
              , #RESULT2.Lot  
              , #RESULT2.PackKey  
              , ISNULL(RTRIM(PACK.PACKUOM3),'')  
              , ISNULL(#RESULT2.CaseBalRtnToRack,0) * ISNULL(PACK.CaseCnt,0)  
              , #RESULT2.ID  
         FROM #RESULT2  
         INNER JOIN PACK WITH (NOLOCK) ON (Pack.Packkey = #RESULT2.Packkey)  
         WHERE #RESULT2.Storerkey = @c_Storerkey  
         AND   #RESULT2.Loc       = @c_loc  
         AND   #RESULT2.CaseBalRtnToRack > 0   
  
         OPEN Cursor_Repl  
         WHILE (1 = 1) AND (@n_continue = 1)  
         BEGIN  
            -- FETCH NEXT FROM Cursor_Repl INTO @c_sku, @c_lot, @c_PackKey, @c_uom, @n_qtyrepl  
            FETCH NEXT FROM Cursor_Repl INTO @c_sku, @c_lot, @c_PackKey, @c_uom, @n_qtyrepl, @c_id  
            IF @@FETCH_STATUS <> 0 BREAK  
  
            -- generate repl key  
              
            EXECUTE nspg_GetKey  
                   'REPLENISHKEY'  
                 , 10  
                 , @c_ReplenishmentKey OUTPUT  
                 , @b_success OUTPUT  
                 , @n_err OUTPUT  
                 , @c_errmsg OUTPUT  
              
            IF NOT @b_success = 1 BREAK  
  
            -- insert into repl table  
            IF @b_success = 1  
            BEGIN  
               INSERT REPLENISHMENT (replenishmentgroup  
                     ,ReplenishmentKey  
                     ,StorerKey  
                     ,Sku  
                     ,FromLoc  
                     ,ToLoc  
                     ,Lot  
                     ,Id  
                     ,Qty  
                     ,UOM  
                     ,PackKey  
                     ,Confirmed  
                     ,ReplenNo)  
               VALUES ('IDS'  
                     ,@c_ReplenishmentKey  
                     ,@c_Storerkey  
                     ,@c_SKU  
                     ,@c_LOC                
                     ,@c_ToLOC  
                     ,@c_Lot  
                     ,@c_Id  
                     ,@n_QtyRepl  
                     ,@c_UOM  
                     ,@c_PackKey  
                     ,'N'  
                     ,'Y')  
  
               SET @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err = 65000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into Replenishment table failed. (isp_ReplenishLetdown_rpt15)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
               END  
            END -- IF @b_success = 1  
         END   
         CLOSE Cursor_Repl  
         DEALLOCATE Cursor_Repl  
  
         IF @n_continue = 1   
         BEGIN  
            UPDATE #RESULT2  
            SET   MoveToLoc = @c_toloc  
            WHERE Storerkey = @c_storerkey  
            AND   Loc       = @c_Loc  
            AND   ID        = @c_ID  
            AND   EXISTS ( SELECT 1 FROM REPLENISHMENT WITH (NOLOCK)   
                           WHERE Fromloc = @c_Loc  
                           AND   ToLoc   = @c_toloc  
                           AND   ID      = @c_ID  
                           AND   Storerkey = @c_storerkey  
                           AND   Confirmed = 'N'  
                           AND   ReplenNo  = 'Y')  
         END  
      END  -- End While  
      CLOSE Cursor_BBA  
      DEALLOCATE Cursor_BBA  
   END  
   ELSE  
   BEGIN  
      IF @n_continue = 1   
      BEGIN  
         UPDATE #RESULT2  
            SET MoveToLoc = RP.ToLoc+'HH'  
         FROM  #RESULT2   
         JOIN  REPLENISHMENT RP WITH (NOLOCK) ON (RP.Storerkey = #RESULT2.storerkey)  
                                              AND(RP.FromLoc   = #RESULT2.Loc)  
                                              AND(RP.ID        = #RESULT2.ID)  
         WHERE RP.Confirmed = 'N'  
         AND   RP.ReplenNo  = 'Y'  
         AND   RP.replenishmentgroup = 'IDS'  
      END   
   END  -- END NOT EXISTS BBA REplenishment Record  
  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ReplenishLetdown_rpt15'  
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
   END */
   --WL04 E
    
   SELECT #RESULT2.Storerkey  
        , #RESULT2.Sku  
        , #RESULT2.Lottable02    
        , #RESULT2.Loc  
        , #RESULT2.ID  
        , ISNULL(SUM(#RESULT2.Qty),0)                 AS Qty  
        , ISNULL(SUM(#RESULT2.QtyInEA),0)             AS QtyInEA   
        , #RESULT2.Packkey  
        , #RESULT2.CaseCnt  
        , ISNULL(SUM(#RESULT2.PickQty),0)             AS PickQty  
        , CASE WHEN ISNULL(SUM(#RESULT2.ReplQty),0)='0' THEN '' ELSE ISNULL(SUM(#RESULT2.ReplQty),0) END AS ReplQty   --WL04  
        , CASE WHEN ISNULL(SUM(#RESULT2.ReplQtyInEA),0)=0  THEN '' ELSE ISNULL(SUM(#RESULT2.ReplQtyInEA),0) END AS ReplQtyInEA   --WL04     
        , #RESULT2.ToLoc   
        , ISNULL(SUM(#RESULT2.CaseBalRtnToRack),0)    AS CaseBalRtnToRack  
        , ISNULL(SUM(#RESULT2.CaseBalRtnToRackInEA),0)AS CaseBalRtnToRackInEA   
        , #RESULT2.MoveToLoc  
        , #RESULT2.facility  
        , #RESULT2.WavekeyStart 
        , #RESULT2.WavekeyEnd  
        , ISNULL(RTRIM(pack.packuom3),'')             AS UOM   
        , ISNULL(RTRIM(SKU.Style),'')                 AS Style  
        , ISNULL(RTRIM(SKU.Color),'')                 AS Color  
        , ISNULL(RTRIM(SKU.Size),'')                  AS Size  
   FROM #RESULT2   
   INNER JOIN SKU WITH (NOLOCK) ON (#RESULT2.Storerkey = SKU.Storerkey) AND (#RESULT2.Sku = SKU.Sku)  
   LEFT JOIN Pack WITH (NOLOCK) ON (#RESULT2.Packkey = pack.packkey)  
   --WHERE  CaseBalRtnToRackInEA <= QtyInEA AND CaseBalRtnToRackInEA >= 0   --WL01   --WL02
   GROUP BY #RESULT2.Storerkey  
          , #RESULT2.Sku  
          , #RESULT2.Lottable02  
          , #RESULT2.Loc  
          , #RESULT2.ID  
          , #RESULT2.Packkey  
          , #RESULT2.CaseCnt  
          , #RESULT2.ToLoc  
          , #RESULT2.MoveToLoc  
          , #RESULT2.facility  
          , #RESULT2.WavekeyStart  
          , #RESULT2.WavekeyEnd  
          , ISNULL(RTRIM(Pack.packuom3),'')  
          , ISNULL(RTRIM(SKU.Style),'')  
          , ISNULL(RTRIM(SKU.Color),'')  
          , ISNULL(RTRIM(SKU.Size),'')   
   --HAVING (SUM(ReplQty) + SUM(ReplQtyInEA)) > 0 OR (SUM(PickQty)) > 0   --WL04 
   ORDER BY #RESULT2.Loc, #RESULT2.ID  
          , ISNULL(RTRIM(SKU.Style),'')  
          , ISNULL(RTRIM(SKU.Color),'')  
          , ISNULL(RTRIM(SKU.Size),'')      
          , CaseBalRtnToRack
   
   IF OBJECT_ID('tempdb..#tempskuxloc') IS NOT NULL
      DROP TABLE #tempskuxloc
   IF OBJECT_ID('tempdb..#temppick') IS NOT NULL
      DROP TABLE #temppick
   IF OBJECT_ID('tempdb..#temprepl') IS NOT NULL
      DROP TABLE #temprepl
   IF OBJECT_ID('tempdb..#temprp') IS NOT NULL
      DROP TABLE #temprp
   IF OBJECT_ID('tempdb..#tempsameloc') IS NOT NULL
      DROP TABLE #tempsameloc
   IF OBJECT_ID('tempdb..#result') IS NOT NULL
      DROP TABLE #result
   IF OBJECT_ID('tempdb..#temppick_His') IS NOT NULL   --WL04
      DROP TABLE #temppick_His
END  

GO