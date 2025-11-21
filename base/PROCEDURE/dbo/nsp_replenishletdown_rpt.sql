SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure: nsp_ReplenishLetdown_rpt                            */  
/* Creation Date: 11-Aug-2004                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: Generate Replenishment Let Down report                      */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.8                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*     (FBR:NIKECN - Wave Replenishement & letdown Report)              */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* 18-Oct-2004  Jeff       THis is the modified version - If anything   */  
/*                         happens to this script, put back the old one */  
/*                         Filename for backup (original copy) -        */  
/*                         nsp_ReplenishmentLetdown_rptbk.              */  
/* 19-Oct-2004  June       - (SOS#28521).                               */  
/* 07-DEC-2004  YTWan      - Replenishment to BBA.                      */  
/*                         - Insert lot into each temp table /          */  
/*                           include Lot - (FBR#012)                    */  
/* 25-Jan-2005  YTWAN      Bug Fix for Replenish to BBA Loc, which      */  
/*                         belong to different Facility.                */  
/* 16-Feb-2005  June       Bug Fix for BBA replenish, Group by Loc      */  
/*                         instead of Loc + ID - (SOS#31880).           */  
/* June-2005    ONG        - NSC Project Change Request - (SOS#).       */  
/* 19-Sep-2006  MaryVong   SOS58469 Add Lottable02                      */  
/* 05-Apr-2012  NJOW01     SOS240309-VF replenishment report for CN Vans*/  
/* 19-Aug-2016  MTTEY      IN00127096-Error in the order by clause MT02 */  
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_ReplenishLetdown_rpt] (@c_facility     NVARCHAR(5)  
,     @c_loadkeystart NVARCHAR(10)  
,     @c_loadkeyend   NVARCHAR(10) )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
 DECLARE @c_storerkey NVARCHAR(15),  
     @c_sku   NVARCHAR(20),  
     @c_id     NVARCHAR(18),  
     @c_lot   NVARCHAR(10),  
     @c_loc   NVARCHAR(10),  
     @c_toloc  NVARCHAR(10),  
     @n_qtyrepl   int,  
     @n_svalue  int,  
     @c_ReplenishmentKey NVARCHAR(10),  
     @c_uom   NVARCHAR(10),  
     @c_packkey NVARCHAR(10),  
     @b_success   int,  
     @n_err    int,  
     @n_continue  int,  
     @c_errmsg  NVARCHAR(255),  
     @n_starttcnt int  
  
  
SELECT PD.Storerkey, PD.Sku, PD.Loc, PD.ID, SUM(PD.Qty) PickQty, PD.Lot, LA.Lottable02  
INTO #temppick  
FROM PICKDETAIL PD (NOLOCK)  
JOIN LOADPLANDETAIL LPD(NOLOCK)  ON LPD.Orderkey = PD.Orderkey  
JOIN LOADPLAN LP (NOLOCK)        ON LPD.Loadkey = LP.Loadkey  
JOIN SKUxLOC SL(NOLOCK)    ON PD.Storerkey = SL.Storerkey  
           AND PD.Sku      = SL.Sku  
           AND PD.Loc      = SL.Loc  
JOIN LOC L (NOLOCK)      ON L.Loc    = SL.LOC  
-- SOS58469  
JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.LOT = LA.LOT  
WHERE LP.LoadKey >= @c_loadkeystart  
AND   LP.LoadKey <= @c_loadkeyend  
AND   LP.Facility = @c_facility  
AND   SL.LocationType <> 'CASE'  
AND   SL.LocationType <> 'PICK'  
AND   PD.Status < '5'  
--AND   L.LocationType <> 'BBA'  
GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID, PD.Lot, LA.Lottable02  
  
SELECT RP.Storerkey, RP.Sku, RP.FromLoc, RP.ID, RP.ToLoc, SUM(RP.Qty) ReplQty, RP.Lot  
INTO #temprepl  
FROM REPLENISHMENT RP(NOLOCK)  
JOIN SKUxLOC SL(NOLOCK)  ON  RP.Storerkey = SL.Storerkey  
         AND RP.Sku       = SL.Sku  
         AND RP.FromLoc   = SL.Loc  
JOIN LOC L (NOLOCK) ON  RP.FromLoc   = L.Loc  
WHERE SL.LocationType <> 'CASE'  
AND   SL.LocationType <> 'PICK'  
AND   RP.Confirmed = 'N'  
AND   RP.ReplenNo <> 'Y'  
AND  L.Facility = @c_facility  
--AND   L.LocationType <> 'BBA'  
GROUP BY RP.Storerkey, RP.Sku, RP.FromLoc, RP.ToLoc, RP.ID, RP.Lot  
  
SELECT DISTINCT LLI.Storerkey, LLI.Sku, LLI.Loc, LLI.ID, LLI.Qty, PK.Packkey, PK.CaseCnt, LLI.Lot, tp.Lottable02  
INTO #tempskuxloc  
FROM #temppick tp  
JOIN SKUXLOC SL(NOLOCK) ON  SL.Storerkey = tp.storerkey -- ISNULL(tp.Storerkey, rp.storerkey)  
        AND SL.Loc       = tp.loc -- ISNULL(tp.Loc, rp.fromloc)  
        AND SL.Sku     = tp.Sku -- SOS28521  
JOIN LOC L (NOLOCK) ON L.Loc = SL.Loc  
JOIN SKU S(NOLOCK) ON  S.Storerkey  = SL.Storerkey  
       AND S.Sku      = SL.Sku  
JOIN PACK PK(NOLOCK) ON  S.Packkey    = PK.Packkey  
JOIN (SELECT Storerkey,  
   Sku,  
   Loc,  
   ID,  
   SUM(Qty-QtyAllocated-QtyPicked ) Qty,  
   SUM(Qty) StockQty,  
       Lot  
  FROM LOTxLOCxID (NOLOCK)  
  GROUP BY Storerkey, Sku, Loc, ID, Lot) LLI  
  ON  LLI.Storerkey = SL.Storerkey  
  AND LLI.Sku   = SL.Sku  
  AND LLI.Loc   = SL.Loc  
WHERE SL.LocationType <> 'CASE'  
AND   SL.LocationType <> 'PICK'  
AND   LLI.StockQty > 0  
--AND   L.LocationType <> 'BBA'  
-- Start : Changed by June 19.Oct.04 SOS28521  
/*  
UNION  
SELECT DISTINCT trep.Storerkey, trep.Sku, trep.FromLoc, Trep.ID, Trep.ReplQty, PK.Packkey, PK.CaseCnt  
FROM #temprepl trep  
JOIN SKU SKU (NOLOCK) ON trep.sku = sku.sku and trep.storerkey = sku.storerkey  
JOIN PACK PK (NOLOCK) ON sku.packkey = pk.packkey  
*/  
  
-- ReplenbutNotPick: Get records that need to Replenish but not Pick in the LP  
SELECT DISTINCT trep.Storerkey, trep.Sku, trep.FromLoc as Loc, Trep.ID, Trep.ReplQty as Qty, Trep.Lot  
INTO #temprp  
FROM #temprepl trep  
LEFT OUTER JOIN #tempskuxloc tsl ON  trep.Storerkey = tsl.Storerkey  
   AND trep.Sku       = tsl.Sku  
   AND trep.FromLoc   = tsl.Loc  
   AND trep.ID        = tsl.ID  
WHERE tsl.loc IS NULL AND tsl.sku IS NULL  
  
  
-- Get Qty avail for ReplenbutNotPick records & Insert these records into #TempSKUXLOC  
INSERT INTO #tempskuxloc (Storerkey, Sku, Loc, ID, Qty, Packkey, Casecnt, Lot, Lottable02)  
SELECT DISTINCT LLI.Storerkey, LLI.Sku, LLI.Loc, LLI.ID, LLI.Qty, PK.Packkey, PK.CaseCnt, LLI.Lot, LA.Lottable02  
FROM #temprp trp  
JOIN SKU S(NOLOCK) ON  S.Storerkey  = trp.Storerkey  
   AND S.Sku   = trp.Sku  
JOIN PACK PK(NOLOCK) ON S.Packkey   = PK.Packkey  
JOIN (SELECT Storerkey,  
   Sku,  
   Loc,  
   ID,  
   SUM(Qty-QtyAllocated-QtyPicked ) Qty,  
   SUM(Qty) StockQty,  
       Lot  
  FROM LOTxLOCxID (NOLOCK)  
  GROUP BY Storerkey, Sku, Loc, ID, Lot) LLI  
  ON  LLI.Storerkey = trp.Storerkey  
  AND LLI.Sku = trp.Sku  
  AND LLI.Loc = trp.Loc  
  AND LLI.ID  = trp.ID  
-- SOS58469  
JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.LOT = LA.LOT  
WHERE LLI.StockQty > 0  
  
-- NoReplnPick: Get other SKU wh has no Replen & Pick But sit at loc that has Pick/Replen  
SELECT DISTINCT LOC  
INTO #tempsameloc  
FROM #tempskuxloc  
  
INSERT INTO #tempskuxloc (Storerkey, Sku, Loc, ID, Qty, Packkey, Casecnt, Lot, Lottable02)  
SELECT LLI.Storerkey, LLI.Sku, LLI.LOC, LLI.ID, IsNull(LLI.Qty, 0) as Qty, S.Packkey, PK.Casecnt, LLI.Lot, LA.Lottable02  
FROM #tempskuxloc sl  
RIGHT OUTER JOIN (SELECT LLI.Storerkey, LLI.Sku, LLI.LOC, LLI.ID, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked ) as Qty, Lot  
      FROM #tempsameloc tsl  
      JOIN LOTXLOCXID LLI (NOLOCK) ON tsl.Loc = LLI.Loc  
      GROUP BY LLI.Storerkey, LLI.Sku, LLI.LOC, LLI.ID, LLI.Lot) AS LLI  
       ON LLI.Storerkey = sl.Storerkey  
       AND LLI.Sku = sl.Sku  
       AND LLI.Loc = sl.Loc  
       AND LLI.ID = sl.ID  
-- SOS58469  
INNER JOIN LOTATTRIBUTE LA ON LLI.LOT = LA.LOT  
JOIN SKU S(NOLOCK) ON  S.Storerkey  = LLI.Storerkey AND S.Sku = LLI.Sku  
JOIN PACK PK(NOLOCK) ON S.Packkey   = PK.Packkey  
WHERE sl.SKU IS NULL  
-- End : Changed by June 19.Oct.04 SOS28521  
  
  
/* Remarked by Jeff  
      SELECT  DISTINCT LLI.Storerkey, LLI.Sku, LLI.Loc, LLI.ID, LLI.Qty, PK.Packkey, PK.CaseCnt  
      INTO #tempskuxloc  
      FROM #temppick tp  
 LEFT OUTER JOIN #temprepl rp   ON  tp.Storerkey = rp.Storerkey  
 AND tp.Sku       = rp.Sku  
 AND tp.Loc       = rp.FromLoc  
      JOIN SKUxLOC SL(NOLOCK) ON  SL.Storerkey = ISNULL(tp.Storerkey, rp.storerkey)  
 AND SL.Loc       = ISNULL(tp.Loc, rp.fromloc)  
            JOIN SKU S(NOLOCK)  
  ON  S.Storerkey  = SL.Storerkey  
 AND S.Sku     = SL.Sku  
  
            JOIN PACK PK(NOLOCK)     ON  S.Packkey    = PK.Packkey  
            JOIN (SELECT Storerkey,  
         Sku,  
         Loc,  
         ID,  
         SUM(Qty-QtyAllocated-QtyPicked ) Qty,  
         SUM(Qty) StockQty  
        FROM LOTxLOCxID (NOLOCK)  
        GROUP BY Storerkey, Sku, Loc, ID) LLI  
ON  LLI.Storerkey = SL.Storerkey  
AND LLI.Sku   = SL.Sku  
AND LLI.Loc   = SL.Loc  
WHERE SL.LocationType <> 'CASE'  
      AND   SL.LocationType <> 'PICK'  
  AND   LLI.StockQty > 0  
Remarked by Jeff */  
  
-- Start : Changed by June 19.Oct.04 SOS28521  
SELECT Storerkey, Sku, Loc, ID, QTY = SUM(Qty), Packkey, CaseCnt, Lot, Lottable02 -- SOS58469  
INTO  #RESULT  
FROM  #tempskuxloc  
GROUP BY Storerkey, Sku, Loc, ID, Packkey, Casecnt, Lot, Lottable02  
-- End : Changed by June 19.Oct.04 SOS28521  
  
  SELECT MIN(TSL.Storerkey) Storerkey,  
     TSL.Sku,  
             TSL.Loc,  
     TSL.ID,  
             CASE TSL.CaseCnt WHEN 0  
                  THEN 0  
                  ELSE CAST(SUM(ISNULL(TSL.Qty,0)+ISNULL(TP.PickQty,0)) / TSL.CaseCnt AS Int)  
--      ELSE CAST(SUM(ISNULL(TSL.Qty,0)) / TSL.CaseCnt AS Int)  
             END Qty,  
             CASE TSL.CaseCnt WHEN 0  
              THEN -- Start : Changed by June 19.Oct.04 SOS28521  
           -- SUM(TSL.Qty + TP.PickQty)  
      SUM(TSL.Qty + ISNULL(TP.PickQty, 0))  
      -- End : Changed by June 19.Oct.04 SOS28521  
                  ELSE SUM(ISNULL(TSL.Qty,0)+ISNULL(TP.PickQty,0)) % CAST(TSL.CaseCnt AS Int)  
--      ELSE SUM(ISNULL(TSL.Qty,0)) % CAST(TSL.CaseCnt AS Int)  
             END QtyInEA,  
             TSL.Packkey,  
             TSL.CaseCnt,  
      -- Start : Changed by June 19.Oct.04 SOS28521  
            -- CAST(SUM(ISNULL(TP.PickQty,0)) / TSL.CaseCnt AS int) PickQty,  
             CASE TSL.CaseCnt WHEN 0  
                  THEN SUM(ISNULL(TP.PickQty,0))  
      ELSE CAST(SUM(ISNULL(TP.PickQty,0)) / TSL.CaseCnt AS int)  
      END as PickQty,  
      -- End : Changed by June 19.Oct.04 SOS28521  
             CASE TSL.CaseCnt WHEN 0  
                  THEN 0  
                  ELSE CAST(SUM(ISNULL(TRP.ReplQty,0)) / TSL.CaseCnt AS int)  
             END ReplQty,  
             CASE TSL.CaseCnt WHEN 0  
                  THEN SUM(TRP.ReplQty)  
                  ELSE SUM(ISNULL(TRP.ReplQty,0)) % CAST(TSL.CaseCnt AS int)  
             END ReplQtyInEA,  
             ISNULL(TRP.ToLoc, '') AS ToLoc, -- SOS28251  
             CASE TSL.CaseCnt WHEN 0  
                THEN 0  
                  ELSE CAST(SUM((ISNULL(TSL.Qty,0)+ ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))/ TSL.CaseCnt AS Int)  
             END CaseBalRtnToRack,  
             CASE TSL.CaseCnt WHEN 0  
   -- Changed by June 19.Oct.04 SOS28521  
                  -- THEN SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) + ISNULL(TP.PickQty,0) + ISNULL(TRP.ReplQty,0))  
       THEN SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) - ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))  
               ELSE (SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0))- ISNULL(TP.PickQty,0) - ISNULL(TRP.ReplQty,0))) % CAST(TSL.CaseCnt AS Int)  
             END CaseBalRtnToRackInEA,  
           --  '________________' MoveToLoc,  
     '            ' MoveToLoc,  
             @c_facility facility,  
             @c_loadkeystart loadkeystart,  
             @c_loadkeyend loadkeyend,  
             TSL.Lot,  
             -- SOS58469  
             TSL.Lottable02  
-- Start : Changed by June 19.Oct.04 SOS28521  
  
--      FROM  #tempskuxloc  TSL  
        INTO  #RESULT2  
        FROM  #RESULT TSL  
-- End : SOS28521  
            LEFT OUTER JOIN #temppick TP  ON  TP.Storerkey  = TSL.Storerkey  
                                          AND TP.Sku        = TSL.Sku  
                                          AND TP.Loc        = TSL.Loc  
              AND TP.ID         = TSL.ID  
              AND TP.Lot   = TSL.Lot  
    LEFT OUTER JOIN #temprepl TRP ON  TRP.Storerkey = TSL.Storerkey  
                                          AND TRP.Sku       = TSL.Sku  
                                          AND TRP.FromLoc   = TSL.Loc  
              AND TRP.ID        = TSL.ID  
              AND TRP.Lot   = TSL.Lot  
  GROUP BY  TSL.Sku, TSL.Loc, TSL.ID, TSL.Packkey, TSL.CaseCnt, TRP.ToLoc, TSL.Lot, TSL.Lottable02  
  HAVING SUM(ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) > 0  
    OR SUM(ISNULL(TP.PickQty,0)) > 0  
    OR SUM(ISNULL(TRP.ReplQty,0)) > 0  
    OR SUM((ISNULL(TSL.Qty,0) + ISNULL(TP.PickQty,0)) + ISNULL(TP.PickQty,0) + ISNULL(TRP.ReplQty,0)) > 0  
      ORDER BY  TSL.Loc, TSL.ID, TSL.Sku, CaseBalRtnToRack  
  
      -- 7 DEC 2004 YTWan FBR012 - Replenishment to BBA - START  
  SELECT @n_continue = 1, @n_starttcnt= @@TRANCOUNT  
  BEGIN TRANSACTION  
  SELECT @c_toloc = ''  
  
  IF NOT EXISTS (SELECT 1 FROM REPLENISHMENT (NOLOCK), #RESULT2  
       WHERE REPLENISHMENT.replenishmentgroup = 'IDS'  
       AND   REPLENISHMENT.Storerkey = #RESULT2.Storerkey  
       AND   REPLENISHMENT.FromLoc = #RESULT2.Loc  
       AND   REPLENISHMENT.ID = #RESULT2.ID  
       AND   REPLENISHMENT.Confirmed = 'N'  
       AND   REPLENISHMENT.ReplenNo  = 'Y' )  
  BEGIN  
   DECLARE Cursor_BBA CURSOR FAST_FORWARD READ_ONLY FOR  
    -- SOS31880  
    SELECT #RESULT2.Storerkey, #RESULT2.Loc --, #RESULT2.ID  
      --, SC.sValue, SUM(#RESULT2.CaseBalRtnToRack)  
    FROM #RESULT2  
      INNER JOIN StorerConfig SC (NOLOCK) ON (SC.Storerkey = #RESULT2.Storerkey) And  
                     (ISNULL(SValue, 0) BETWEEN 1 AND 999) And  
                     (Configkey = 'RESIDBAL')  
      INNER JOIN LOC L (NOLOCK) ON (L.Loc = #RESULT2.Loc) AND  
                 (L.LocationType <> 'BBA')  
    -- SOS31880  
    -- GROUP BY #RESULT2.Storerkey, #RESULT2.Loc, #RESULT2.ID, SC.sValue  
    GROUP BY #RESULT2.Storerkey, #RESULT2.Loc, SC.sValue  
    HAVING SUM(CaseBalRtnToRack) < SC.sValue  
   OPEN Cursor_BBA  
   WHILE (1 = 1) AND (@n_continue = 1)  
   BEGIN  
    -- SOS31880  
    -- FETCH NEXT FROM Cursor_BBA INTO @c_storerkey, @c_loc, @c_id  
    FETCH NEXT FROM Cursor_BBA INTO @c_storerkey, @c_loc  
  
    IF @@FETCH_STATUS <> 0 BREAK  
  
    SET ROWCOUNT 1  
    SELECT @c_toloc = LOC.Loc  
    FROM LOC (NOLOCK)  
    LEFT OUTER JOIN SKUxLOC SL (NOLOCK) ON (SL.Loc = LOC.Loc) And  
                 (SL.Storerkey = @c_storerkey)  
    WHERE LOC.LocationType = 'BBA'  
    AND   ISNULL(SL.Qty,0) - ISNULL(SL.Qtypicked,0) = 0  
    AND NOT EXISTS ( SELECT 1 FROM #RESULT2 WHERE  MoveToloc = LOC.LOC)  
    AND LOC.Facility = @c_facility   --25Jan2005 YTWAN Bug Fix for Replenish to BBA Loc which belong to different Facility  
    ORDER BY LogicalLocation, LOC.Loc  
    SET ROWCOUNT 0  
  
    DECLARE Cursor_Repl CURSOR FAST_FORWARD READ_ONLY FOR  
     SELECT #RESULT2.Sku, #RESULT2.Lot, #RESULT2.PackKey, PACK.PACKUOM3, #RESULT2.CaseBalRtnToRack * ISNULL(PACK.CaseCnt,0)  
       , #RESULT2.ID -- SOS31880  
     FROM #RESULT2  
       INNER JOIN PACK (NOLOCK) ON (Pack.Packkey = #RESULT2.Packkey)  
     WHERE #RESULT2.Storerkey = @c_Storerkey  
     AND   #RESULT2.Loc     = @c_loc  
     -- SOS31880  
       -- AND #RESULT2.ID    = @c_id  
     AND   #RESULT2.CaseBalRtnToRack > 0  
    OPEN Cursor_Repl  
    WHILE (1 = 1) AND (@n_continue = 1)  
    BEGIN  
     -- SOS31880  
     -- FETCH NEXT FROM Cursor_Repl INTO @c_sku, @c_lot, @c_PackKey, @c_uom, @n_qtyrepl  
     FETCH NEXT FROM Cursor_Repl INTO @c_sku, @c_lot, @c_PackKey, @c_uom, @n_qtyrepl, @c_id  
     IF @@FETCH_STATUS <> 0 BREAK  
  
     -- generate repl key  
  
     EXECUTE nspg_GetKey  
     "REPLENISHKEY",  
     10,  
     @c_ReplenishmentKey OUTPUT,  
     @b_success OUTPUT,  
     @n_err OUTPUT,  
     @c_errmsg OUTPUT  
  
     IF NOT @b_success = 1 BREAK  
  
     -- insert into repl table  
             IF @b_success = 1  
             BEGIN  
                INSERT REPLENISHMENT (replenishmentgroup,  
                ReplenishmentKey,  
                StorerKey,  
                Sku,  
                FromLoc,  
                ToLoc,  
                Lot,  
                Id,  
                Qty,  
                UOM,  
                PackKey,  
                Confirmed,  
                ReplenNo)  
                VALUES ('IDS',  
                @c_ReplenishmentKey,  
                @c_Storerkey,  
                @c_SKU,  
                @c_LOC,  
                @c_ToLOC,  
                @c_Lot,  
                @c_Id,  
                @n_QtyRepl,  
                @c_UOM,  
                @c_PackKey,  
                'N',  
                'Y')  
                SELECT @n_err = @@ERROR  
                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into Replenishment table failed. (nsp_ReplenishmentRpt_BatchRefill_02)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
                END  
             END -- IF @b_success = 1  
    END  
    DEALLOCATE Cursor_Repl  
    IF @n_continue = 1  
    BEGIN  
     UPDATE #RESULT2  
     SET   MoveToLoc = @c_toloc  
     WHERE Storerkey = @c_storerkey  
     AND   Loc    = @c_Loc  
     AND   ID    = @c_ID  
     AND   EXISTS ( SELECT 1 FROM REPLENISHMENT (NOLOCK)  
          WHERE Fromloc = @c_Loc  
          AND   ToLoc   = @c_toloc  
          AND   ID      = @c_ID  
          AND   Storerkey = @c_storerkey  
          AND   Confirmed = 'N'  
          AND   ReplenNo  = 'Y')  
    END  
   END  -- End While  
   DEALLOCATE Cursor_BBA  
  END  
  ELSE  
  BEGIN  
   IF @n_continue = 1  
       BEGIN  
    UPDATE #RESULT2  
     SET   MoveToLoc = RP.ToLoc+'HH'  
    FROM  #RESULT2 , REPLENISHMENT RP(NOLOCK)  
    WHERE #RESULT2.Storerkey = RP.storerkey  
    AND   #RESULT2.Loc    = RP.FromLoc  
    AND   #RESULT2.ID    = RP.ID  
    AND   RP.Confirmed     = 'N'  
    AND   RP.ReplenNo    = 'Y'  
    AND   RP.replenishmentgroup = 'IDS'  
   END  
  END  -- END NOT EXISTS BBA REplenishment Record  
  
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishLetdown_rpt'  
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
  
  
  SELECT #RESULT2.Storerkey,  
       CASE WHEN ISNULL(SKU.Susr5,'') <> '' AND ISNULL(SC.SValue,'0') = '1' THEN  --NJOW01  
                 RTRIM(SKU.Susr5) + '-' + SKU.Size  
              WHEN ISNULL(SKU.Susr5,'') = '' AND (ISNULL(SKU.Style,'') <> '' OR ISNULL(SKU.Color,'') <> '')  AND ISNULL(SC.SValue,'0') = '1' THEN  
                 RTRIM(ISNULL(SKU.Style,'')) + '-' + RTRIM(ISNULL(SKU.Color,'')) + '-' + SKU.Size  
         ELSE  
         LEFT(#RESULT2.SKu,6)+'-'+SUBSTRING(#RESULT2.SKu,7,3)+'-'+SUBSTRING(#RESULT2.SKu,10,5)  
         END AS Sku,  
       #RESULT2.Lottable02,  -- SOS58469  
     #RESULT2.Loc, #RESULT2.ID, SUM(#RESULT2.Qty) Qty, Sum(#RESULT2.QtyInEA) QtyInEA,  
             #RESULT2.Packkey, #RESULT2.CaseCnt, SUM(#RESULT2.PickQty) PickQty, Sum(#RESULT2.ReplQty) ReplQty, Sum(#RESULT2.ReplQtyInEA) ReplQtyInEA, #RESULT2.ToLoc,  
     Sum(#RESULT2.CaseBalRtnToRack) CaseBalRtnToRack, Sum(#RESULT2.CaseBalRtnToRackInEA) CaseBalRtnToRackInEA,  
     #RESULT2.MoveToLoc, #RESULT2.facility, #RESULT2.loadkeystart, #RESULT2.loadkeyend, pack.packuom3 as uom  
  FROM #RESULT2 LEFT JOIN pack ON #RESULT2.Packkey = pack.packkey  
  JOIN SKU (NOLOCK) ON #RESULT2.Storerkey = SKU.Storerkey AND #RESULT2.SKu = SKU.Sku  
  LEFT JOIN V_STORERCONFIG2 SC ON ( #RESULT2.Storerkey = SC.Storerkey AND SC.Configkey = 'VFCNSKU')  
  GROUP BY #RESULT2.Storerkey,  
           CASE WHEN ISNULL(SKU.Susr5,'') <> '' AND ISNULL(SC.SValue,'0') = '1' THEN  
                     RTRIM(SKU.Susr5) + '-' + SKU.Size  
                  WHEN ISNULL(SKU.Susr5,'') = '' AND (ISNULL(SKU.Style,'') <> '' OR ISNULL(SKU.Color,'') <> '')  AND ISNULL(SC.SValue,'0') = '1' THEN  
                     RTRIM(ISNULL(SKU.Style,'')) + '-' + RTRIM(ISNULL(SKU.Color,'')) + '-' + SKU.Size  
             ELSE  
             LEFT(#RESULT2.SKu,6)+'-'+SUBSTRING(#RESULT2.SKu,7,3)+'-'+SUBSTRING(#RESULT2.SKu,10,5)  
             END,  
             #RESULT2.Lottable02,  
           #RESULT2.Loc, #RESULT2.ID, #RESULT2.Packkey, #RESULT2.CaseCnt,  
           #RESULT2.ToLoc, #RESULT2.MoveToLoc, #RESULT2.facility, #RESULT2.loadkeystart, #RESULT2.loadkeyend, pack.packuom3  
  ORDER BY #RESULT2.Loc, #RESULT2.ID, 2--, #RESULT2.CaseBalRtnToRack   -- MT02 --  
  
  -- 7 DEC 2004 YTWan FBR012 - Replenishment to BBA - END  
  
   Drop table #tempskuxloc  
   Drop table #temppick  
 Drop table #temprepl  
 -- SOS28521  
 Drop table #temprp  
 Drop table #tempsameloc  
 Drop table #result  
END  
  

GO