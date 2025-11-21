SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store Procedure: isp_RepLENishLetdown_rpt03                          */      
/* Creation Date: 04-Feb-2009                                           */      
/* Copyright: IDS                                                       */      
/* Written by: Rick Liew                                                */      
/*                                                                      */      
/* Purpose: Generate RepLENishment Let Down report                      */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.2                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*     (FBR:PUMACN - Wave RepLENishement & letdown Report)              */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author     Purposes                                     */      
/* 24-Apr-09    Rick Liew  Modify the SKU field for SOS#134744          */      
/* 10-Aug-09    Leong      SOS# 134744 - Bug fix for Sku.Busr6          */      
/* 18-Aug-09    Leong      SOS# 145326 - Include OrderLine# for data    */      
/*                                       extraction                     */      
/* 25-May-16    TLTING01   SQL2014 Bug fix - Order by column miss match */      
/* 06-APR-17    CSCHONG    WMS-1567 Add report config (CS01)            */      
/* 02-JUL-17    CSCHONG    WMS-2398 - Add new report config (CS02)      */      
/* 20-SEP-17    CSCHONG    WMS-2946 - Add new report config (CS03)      */     
/* 01-JUL-17    KuanYee    INC0759140 - FixBug (KY01)                   */ 
/* 12-May-20    WLChooi    WMS-13081 - Add ReportCFG (WL01)             */ 
/* 26-Apr-22    Shong      WMS-19555 - Allow Blank Storerkey            */  
/************************************************************************/      
      
CREATE PROC [dbo].[isp_RepLENishLetdown_rpt03] (      
            @c_Storerkey    NVARCHAR(15)      
          , @c_facility     NVARCHAR(5)      
          , @c_loadkeystart NVARCHAR(10)      
          , @c_loadkeyend   NVARCHAR(10) )      
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
     @c_showField        NVARCHAR(5),                --CS01      
     @c_showskufield     NVARCHAR(5),                --CS02      
     @c_showdiffskuformat NVARCHAR(5),               --CS03   
     @c_ShowPackCaseCnt  NVARCHAR(10)                --WL01   
           
   --Shong
   IF IsNull(@c_Storerkey,'') = ''  
   BEGIN  
      SELECT TOP 1 @c_Storerkey = OD.StorerKey   
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
      JOIN dbo.ORDERS OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey  
      WHERE LPD.LoadKey >= @c_loadkeystart  
      AND   LPD.LoadKey <= @c_loadkeyend  
      AND   OD.Facility = @c_facility  
   END 

   /*CS01 Start*/      
   SET @c_showField = 'N'       
            
   SELECT @c_ShowField = CASE WHEN (CL.Short IS NULL OR CL.Short = 'N') THEN 'N' ELSE 'Y' END      
   FROM CODELKUP CL WITH (NOLOCK)       
   WHERE CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_replenishletdown_rpt03'      
   AND CL.Code = 'SHOWFIELD' AND CL.Storerkey =@c_Storerkey      
   /*CS01 End*/      
           
   /*CS02 Start*/      
   SET @c_showskufield = 'N'       
            
   SELECT @c_showskufield = CASE WHEN (CL.Short IS NULL OR CL.Short = 'N') THEN 'N' ELSE 'Y' END      
   FROM CODELKUP CL WITH (NOLOCK)       
   WHERE CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_replenishletdown_rpt03'      
   AND CL.Code = 'SHOWSKUFIELD' AND CL.Storerkey =@c_Storerkey      
   /*CS02 End*/      
           
   /*CS02 Start*/      
   SET @c_showdiffskuformat = 'N'       
            
   SELECT @c_showdiffskuformat = CASE WHEN (CL.Short IS NULL OR CL.Short = 'N') THEN 'N' ELSE 'Y' END      
   FROM CODELKUP CL WITH (NOLOCK)       
   WHERE CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_replenishletdown_rpt03'      
   AND CL.Code = 'SHOWDIFFSKUFORMAT' AND CL.Storerkey =@c_Storerkey      
   /*CS02 End*/    
   
   --WL01 START   
   SET @c_ShowPackCaseCnt = 'N'       
            
   SELECT @c_ShowPackCaseCnt = ISNULL(CL.Short,'N')    
   FROM CODELKUP CL WITH (NOLOCK)       
   WHERE CL.ListName = 'REPORTCFG' AND CL.Long = 'r_dw_replenishletdown_rpt03'      
   AND CL.Code = 'ShowPackCaseCnt' AND CL.Storerkey = @c_Storerkey      
   AND CL.Code2 = @c_facility
   --WL01 END     
      
   SELECT PD.Storerkey, PD.Sku, PD.Loc, PD.ID, SUM(PD.Qty) PickQty, PD.Lot      
   INTO #temppick      
   FROM PICKDETAIL PD WITH (NOLOCK)      
   JOIN ORDERDETAIL OD WITH (NOLOCK)      
     ON OD.Orderkey = PD.Orderkey      
    AND OD.OrderLineNumber = PD.OrderLineNumber -- SOS# 145326      
    AND OD.sku  = PD.sku      
    AND OD.Storerkey = PD.Storerkey      
   JOIN ORDERS ORD WITH (NOLOCK) ON OD.Orderkey = ORD.Orderkey      
   JOIN SKUxLOC SL WITH (NOLOCK)      
     ON PD.Storerkey = SL.Storerkey      
    AND PD.Sku = SL.Sku      
    AND PD.Loc = SL.Loc      
   JOIN LOC L WITH (NOLOCK) ON L.Loc = SL.LOC      
   JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON PD.LOT = LA.LOT      
   WHERE ORD.LoadKey >= @c_loadkeystart      
   AND   ORD.LoadKey <= @c_loadkeyend      
   AND   ORD.Facility = @c_facility      
   AND   ORD.Status in ('1','2')      
   AND   SL.LocationType <> 'PICK'      
   --AND   PD.Status < '5'      
   AND   PD.StorerKey = @c_storerkey      
   GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID, PD.Lot      
         
   SELECT RP.Storerkey, RP.Sku, RP.FromLoc, RP.ID, RP.ToLoc, SUM(RP.Qty) ReplQty, RP.Lot      
   INTO #temprepl      
   FROM REPLENISHMENT RP WITH (NOLOCK)      
   JOIN SKUxLOC SL WITH (NOLOCK)      
    ON  RP.Storerkey = SL.Storerkey      
    AND RP.Sku       = SL.Sku      
    AND RP.FromLoc   = SL.Loc      
   JOIN LOC L WITH (NOLOCK) ON  RP.FromLoc = L.Loc      
   WHERE SL.LocationType <> 'PICK'      
   AND   RP.Confirmed = 'N'      
   AND   RP.RepLENNo <> 'Y'      
   AND   RP.StorerKey = @c_Storerkey      
   AND   L.Facility = @c_facility      
   GROUP BY RP.Storerkey, RP.Sku, RP.FromLoc, RP.ToLoc, RP.ID, RP.Lot      
         
   SELECT DISTINCT LLI.Storerkey, LLI.Sku, LLI.Loc, LLI.ID, LLI.Qty, PK.Packkey, PK.CaseCnt, LLI.Lot,S.size      
   INTO #tempskuxloc      
   FROM #temppick tp      
   JOIN SKUXLOC SL WITH (NOLOCK)      
    ON  SL.Storerkey = tp.storerkey -- ISNULL(tp.Storerkey, rp.storerkey)      
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
   LEFT OUTER JOIN #tempskuxloc tsl      
     ON trep.Storerkey = tsl.Storerkey      
    AND trep.Sku       = tsl.Sku      
    AND trep.FromLoc   = tsl.Loc      
    AND trep.ID        = tsl.ID      
   WHERE tsl.loc IS NULL AND tsl.sku IS NULL      
         
   -- Get Qty avail for RepLENbutNotPick records & Insert these records into #TempSKUXLOC      
   INSERT INTO #tempskuxloc (Storerkey, Sku, Loc, ID, Qty, Packkey, Casecnt, Lot,Size)      
   SELECT DISTINCT LLI.Storerkey, LLI.Sku, LLI.Loc, LLI.ID, LLI.Qty, PK.Packkey, PK.CaseCnt, LLI.Lot,S.size      
   FROM #temprp trp      
   JOIN SKU S WITH (NOLOCK)      
     ON S.Storerkey = trp.Storerkey      
    AND S.Sku   = trp.Sku      
   JOIN PACK PK WITH (NOLOCK)      
     ON S.Packkey = PK.Packkey      
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
   JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.LOT = LA.LOT      
   WHERE LLI.StockQty > 0      
         
   SELECT Storerkey, Sku, Loc, ID, QTY = SUM(Qty), Packkey, CaseCnt, Lot,Size-- SOS58469      
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
             ELSE CAST(SUM((ISNULL(TSL.Qty,0)+ ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))/ TSL.CaseCnt AS Int)      
          END CaseBalRtnToRack,      
          CASE TSL.CaseCnt WHEN 0      
             THEN SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))      
             ELSE (SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0))- ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))) % CAST(TSL.CaseCnt AS Int)      
          END CaseBalRtnToRackInEA,      
          '            ' MoveToLoc,      
          @c_Storerkey    storerkey,      
          @c_facility     facility,      
          @c_loadkeystart loadkeystart,      
          @c_loadkeyend   loadkeyend,      
          TSL.Lot,      
          TSL.Size,      
          (Select Count(distinct(#result.loc)) from #result WITH (NOLOCK)) Counter,      
          /* -- SOS# 134744 Start      
                    '['  + SUBSTRING(SKU.busr6,1,3)  + '-' + SUBSTRING (SKU.busr6,4, LEN(SKU.busr6) -7)      
                    +'-' + SUBSTRING(SKU.busr6,LEN(SKU.busr6) - 3 , 2)+'-' + SUBSTRING(SKU.busr6, LEN(SKU.busr6) -1,2)      
                    +'(' + SUBSTRING(SKU.DESCR,1,3) + ')' +']'As OldSku      
          */      
          /*CS01 start*/      
          CASE WHEN @c_showskufield = 'N'   THEN --CS02      
       CASE WHEN @c_showField ='N' THEN      
        CASE WHEN ISNULL(RTRIM(SKU.busr6),'') <> ''      
         THEN '[' + SUBSTRING(SKU.busr6,1,3) + '-'      
            + SUBSTRING (SKU.busr6,4, ABS(LEN(SKU.busr6) -7)) + '-'     --(KY01)  
            + SUBSTRING(SKU.busr6,LEN(SKU.busr6) - 3 , 2)+ '-'      
            + SUBSTRING(SKU.busr6, LEN(SKU.busr6) -1,2)      
            +'(' + SUBSTRING(RTRIM(LTRIM(SKU.DESCR)),1,3) + ')' +      
          ']'      
         ELSE '[' + ISNULL(RTRIM(SKU.busr6),'') + '(' + SUBSTRING(RTRIM(LTRIM(SKU.DESCR)),1,3) + ')' + ']'      
        END      
        ELSE      
                 
             '[' + LEFT (SKU.BUSR1, 10) + ']'      
                 
        END          
        ELSE '' END As OldSku        --CS02      
          /*CS01 End*/      
          -- SOS# 134744 End      
   INTO  #RESULT2      
   FROM  #RESULT TSL      
   LEFT OUTER JOIN #temppick TP      
     ON TP.Storerkey = TSL.Storerkey      
    AND TP.Sku = TSL.Sku      
    AND TP.Loc = TSL.Loc      
    AND TP.ID  = TSL.ID      
    AND TP.Lot = TSL.Lot      
   LEFT OUTER JOIN #temprepl TRP      
     ON TRP.Storerkey = TSL.Storerkey      
    AND TRP.Sku       = TSL.Sku      
    AND TRP.FromLoc   = TSL.Loc      
    AND TRP.ID        = TSL.ID      
    AND TRP.Lot       = TSL.Lot      
   INNER JOIN SKU SKU ON  SKU.Storerkey = TSL.Storerkey      
     AND SKU.Sku      = TSL.Sku      
   GROUP BY  TSL.Sku, TSL.Loc, TSL.ID, TSL.Packkey, TSL.CaseCnt, TRP.ToLoc, TSL.Lot,TSL.Size,sku.busr6,sku.descr      
   ,LEFT (SKU.BUSR1, 10)                                          --(CS01)      
   HAVING SUM(ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) > 0      
   OR SUM(ISNULL(TP.PickQty,0)) > 0      
   OR SUM(ISNULL(TRP.ReplQty,0)) > 0      
   OR SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) + ISNULL(TP.PickQty,0) + ISNULL(TRP.ReplQty,0)) > 0      
   ORDER BY  TSL.Loc, TSL.ID, TSL.Sku, CaseBalRtnToRack      
         
         
   IF @n_continue=3  -- Error Occured - Process AND Return      
      BEGIN      
         SELECT @b_success = 0      
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_RepLENishLetdown_rpt03'       --WL01
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
   END      
         
   SELECT #RESULT2.Storerkey, #RESULT2.SKu,      
          #RESULT2.Loc,      
          CASE WHEN @c_ShowPackCaseCnt = 'Y' THEN CAST(pack.Casecnt AS NVARCHAR(10)) ELSE CAST(#RESULT2.Packkey AS NVARCHAR(10)) END AS Packkey,   --WL01
          SUM(#RESULT2.PickQty) PickQty, Sum(#RESULT2.ReplQty) ReplQty,      
          Sum(#RESULT2.ReplQtyInEA) ReplQtyInEA, #RESULT2.ToLoc,      
          Sum(#RESULT2.CaseBalRtnToRack) CaseBalRtnToRack, Sum(#RESULT2.CaseBalRtnToRackInEA) CaseBalRtnToRackInEA,      
          #RESULT2.facility, #RESULT2.loadkeystart, #RESULT2.loadkeyend,      
          #RESULT2.size,#RESULT2.Counter,#RESULT2.OldSku,
          @c_ShowPackCaseCnt AS ShowPackCaseCnt    --WL01      
   FROM #RESULT2
   LEFT JOIN pack ON #RESULT2.Packkey = pack.packkey      
   GROUP BY #RESULT2.Storerkey, #RESULT2.Sku,      
   #RESULT2.Loc, #RESULT2.ID,
   CASE WHEN @c_ShowPackCaseCnt = 'Y' THEN CAST(pack.Casecnt AS NVARCHAR(10)) ELSE CAST(#RESULT2.Packkey AS NVARCHAR(10)) END,   --WL01  
   #RESULT2.ToLoc, #RESULT2.facility, #RESULT2.loadkeystart, #RESULT2.loadkeyend,      
   #RESULT2.size,#RESULT2.Counter,#RESULT2.OldSku      
   ORDER BY #RESULT2.Loc, #RESULT2.ID, #RESULT2.Sku, Sum(#RESULT2.CaseBalRtnToRack) -- TLTING01      
         
   Drop table #tempskuxloc      
   Drop table #temppick      
   Drop table #temprepl      
   Drop table #temprp      
   Drop table #result      
      
END -- End Procedure   

GO