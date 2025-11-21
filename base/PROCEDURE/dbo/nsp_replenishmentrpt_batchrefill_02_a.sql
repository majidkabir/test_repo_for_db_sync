SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/  
/* Store Procedure:  nsp_ReplenishmentRpt_BatchRefill_02_A                      */  
/* Creation Date: 05-Aug-2008                                                   */  
/* Copyright: IDS                                                               */  
/* Written by: MaryVong                                                         */  
/*                                                                              */  
/* Purpose:  NIKE China Wave Replenishment Report (LoadPlan)                    */  
/*                                                                              */  
/* Input Parameters: @c_Zone01, - Facility                                      */  
/*                   @c_Zone02, - can be 'ALL' or PutawayZone                   */  
/*                   @c_Zone03,                                                 */  
/*                   @c_Zone04,                                                 */  
/*                   @c_Zone05,                                                 */  
/*                   @c_Zone06,                                                 */  
/*                   @c_Zone07,                                                 */  
/*                   @c_Zone08,                                                 */  
/*                   @c_Zone09,                                                 */  
/*                   @c_Zone10,                                                 */  
/*                   @c_Zone11,                                                 */  
/*                   @c_Zone12,                                                 */  
/*                                                                              */  
/* Output Parameters:                                                           */  
/*                                                                              */  
/* Called By: r_replenishment_report02_a                                        */  
/*                                                                              */  
/* PVCS Version: 1.6                                                            */  
/*                                                                              */  
/* Version: 5.4                                                                 */  
/*                                                                              */  
/* Data Modifications:                                                          */  
/*                                                                              */  
/* Updates:                                                                     */  
/* Date         Author   Ver   Purposes                                         */  
/* 2008-11-03   Shong          Trigger replenishment for stock without ucc      */  
/* 2008-11-03   Shong01        SOS120759 - Remove LocGroup & LocLevel           */  
/* 2009-02-17   Leong          SOS129128 -For monitoring Purpose only           */  
/*                                       (remove)                               */  
/* 2009-02-25   Leong          SOS129861 - Filter by DYNAMICPK LocationType     */  
/* 19-Mar-2010  Leong    1.4   Bug Fix: Change GetKey from REPLENISHMENT to     */  
/*                                     REPLENISHKEY (Leong01)                   */  
/* 05-MAR-2018  Wan02    1.5   WM - Add Functype                                */  
/* 05-OCT-2018  CZTENG01 1.6   WM - Add StorerKey,ReplGrp                       */  
/********************************************************************************/  
CREATE PROC  [dbo].[nsp_ReplenishmentRpt_BatchRefill_02_A]  
      @c_Zone01      NVARCHAR(10)  
   ,  @c_Zone02      NVARCHAR(10)  
   ,  @c_Zone03      NVARCHAR(10)  
   ,  @c_Zone04      NVARCHAR(10)  
   ,  @c_Zone05      NVARCHAR(10)  
   ,  @c_Zone06      NVARCHAR(10)  
   ,  @c_Zone07      NVARCHAR(10)  
   ,  @c_Zone08      NVARCHAR(10)  
   ,  @c_Zone09      NVARCHAR(10)  
   ,  @c_Zone10      NVARCHAR(10)  
   ,  @c_Zone11      NVARCHAR(10)  
   ,  @c_Zone12      NVARCHAR(10)  
   ,  @c_storerkey   NVARCHAR(15) = 'ALL'       --(CZTENG01)  
   ,  @c_ReplGrp     NVARCHAR(30) = 'ALL'       --(CZTENG01)  
   ,  @c_Functype    NCHAR(1) = ''              --(Wan01)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
      @n_continue int,  /* continuation flag  
      1=Continue  
      2=failed but continue processsing  
      3=failed do not continue processing  
      4=successful but skip furthur processing */  
      @n_starttcnt   int,  
      @b_success     int,  
      @n_err         int,  
      @c_errmsg      NVARCHAR(215),  
      @b_debug       int,  
      @c_ReplenishmentKey NVARCHAR(10),  
      @c_ReplenishGroup   NVARCHAR(10),  
      @n_cnt              int  
  
   DECLARE @nQtyPendingMoveOut int,  
           @nQtyPendingMoveIn  int,  
           @cLOT               NVARCHAR(10),  
           @cFromLOC           NVARCHAR(10),  
           @nQty               int,  
           @cUOM               NVARCHAR(5),  
           @cReplenishmentKey  NVARCHAR(10),  
           @cID                NVARCHAR(18),  
           @cPackKey           NVARCHAR(10)  
          --,@cLottable02        NVARCHAR(10) -- SOS129128  
  
   DECLARE @cStorerKey NVARCHAR(15),  
           @cSKU       NVARCHAR(20),  
           @cLOC       NVARCHAR(10),  
           @nReplenQty INT  
             
   --(Wan01) - START  
   IF ISNULL(@c_ReplGrp,'') = ''  
   BEGIN  
      SET @c_ReplGrp = 'ALL'  
   END  
   --(Wan01) - END             
  
   SET @n_continue =  1                                              --(Wan01)  
   IF @c_FuncType IN ( '','G' )                                      --(Wan01)  
   BEGIN                                                             --(Wan01)     
      DECLARE CurReplenisment CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT SL.StorerKey, SL.SKU, SL.LOC,  
             (SL.QtyAllocated + SL.QtyPicked) - (SL.Qty + ISNULL(RPL.Qty, 0)) AS QtyReplen  
      FROM   SKUxLOC SL WITH (NOLOCK)  
      JOIN   LOC WITH (NOLOCK) ON LOC.LOC = SL.LOC  
      LEFT OUTER JOIN ( SELECT StorerKey, SKU, TOLOC, SUM(Qty) As Qty  
                        FROM   REPLENISHMENT RP WITH (NOLOCK)  
                        JOIN   LOC WITH (NOLOCK) ON LOC.LOC = RP.TOLOC  
                        WHERE  Confirmed = 'L'  
                           AND LOC.Facility = @c_Zone01  
                        GROUP BY StorerKey, SKU, TOLOC) AS RPL  
                        ON RPL.StorerKey = SL.StorerKey AND RPL.SKU = SL.SKU AND RPL.TOLOC = SL.LOC  
      WHERE LOC.Facility = @c_Zone01  
        AND (SL.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')     --(Wan01)  
        AND SL.LocationType IN ('PICK', 'CASE')  
        AND (SL.QtyAllocated + SL.QtyPicked) > SL.Qty + ISNULL(RPL.Qty, 0)  
      ORDER BY SL.StorerKey, SL.SKU  
  
      OPEN CurReplenisment  
  
      FETCH NEXT FROM CurReplenisment INTO @cStorerKey, @cSKU, @cLOC, @nReplenQty  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SELECT @nQtyPendingMoveOut = ISNULL(SUM(Qty), 0)  
         FROM REPLENISHMENT (NOLOCK )  
         WHERE Confirmed IN ('W', 'S')  
           AND StorerKey = @cStorerKey  
           AND SKU = @cSKU  
           AND FromLOC = @cLOC  
  
         SELECT @nQtyPendingMoveIn = ISNULL(SUM(Qty),0)  
         FROM REPLENISHMENT (NOLOCK )  
         WHERE Confirmed IN ('W', 'S')  
            AND StorerKey = @cStorerKey  
            AND SKU = @cSKU  
            AND ToLOC = @cLOC  
  
  
         IF @nQtyPendingMoveOut > @nQtyPendingMoveIn  
            SET @nReplenQty = @nReplenQty + (@nQtyPendingMoveOut - @nQtyPendingMoveIn )  
         ELSE  
            SET @nReplenQty = @nReplenQty - (@nQtyPendingMoveIn - @nQtyPendingMoveOut)  
  
         -- select  @cStorerKey, @cSKU, @cLOC, @nReplenQty, @nQtyPendingMoveOut, @nQtyPendingMoveIn  
  
         IF @nReplenQty > 0  
         BEGIN  
            DECLARE CUR_LooseUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT LLL.LOT, LLL.LOC, LLL.ID, LLL.Qty - LLL.QtyAllocated - LLL.QtyPicked, PACK.PackKey, PACK.PackUOM3  
                  --,LA.Lottable02 -- SOS129128  
            FROM   LOTxLOCxID LLL WITH (NOLOCK)  
            JOIN   LOTATTRIBUTE LA WITH (NOLOCK) ON LA.LOT = LLL.LOT  
            JOIN   SKUxLOC WITH (NOLOCK) ON SKUxLOC.StorerKey = LLL.StorerKey  
                                        AND SKUxLOC.SKU = LLL.SKU  
                                        AND SKUxLOC.LOC = LLL.LOC  
            JOIN   LOC LOC WITH (NOLOCK) ON LLL.Loc = LOC.LOC  
            JOIN   LOT LOT WITH (NOLOCK) ON LLL.LOT = LOT.LOT  
            JOIN   ID  ID WITH (NOLOCK) ON LLL.ID = ID.ID  
            JOIN   SKU WITH (NOLOCK) ON SKU.StorerKey = LLL.StorerKey AND SKU.SKU = LLL.SKU  
            JOIN   PACK WITH (NOLOCK) ON PACK.PackKey = SKU.PackKey  
            LEFT OUTER JOIN UCC WITH (NOLOCK)  
                       ON LLL.LOT = UCC.LOT AND LLL.LOC = UCC.LOC AND LLL.ID = UCC.ID AND UCC.Status = '1'  
            WHERE  SKUxLOC.StorerKey = @cStorerKey  
              AND  SKUxLOC.SKU = @cSKU  
              AND  SKUxLOC.LocationType NOT IN ('CASE','PICK')  
              AND  LOC.LocationType <> 'DYNAMICPK' -- SOS129861  
              AND  LLL.Qty - LLL.QtyAllocated - LLL.QtyPicked > 0  
              -- AND  LLL.Qty - LLL.QtyAllocated - LLL.QtyPicked < PACK.CaseCnt  
              AND  LOC.Facility = @c_Zone01  
              AND  LOC.Locationflag <>'HOLD'  
              AND  LOC.Locationflag <> 'DAMAGE'  
              AND  LOC.Status <> 'HOLD'  
              AND  LOT.Status = 'OK'  
              AND  ID.Status = 'OK'  
              AND  UCC.LOT IS NULL  
              AND  LA.Lottable02 IN (SELECT CODE FROM CODELKUP (NOLOCK) WHERE Listname = 'GRADE_A')  
  
            OPEN CUR_LooseUCC  
  
            FETCH NEXT FROM CUR_LooseUCC INTO @cLOT, @cFromLOC, @cID, @nQty, @cPackkey, @cUOM--, @cLottable02 -- SOS129128  
  
            WHILE @@FETCH_STATUS <> -1 AND @nReplenQty > 0  
            BEGIN  
               IF @nQty > @nReplenQty  
                  SET @nQty = @nReplenQty  
  
               EXECUTE nspg_GetKey  
                  @keyname       = 'REPLENISHKEY', --Leong01  
                  @fieldlength   = 10,  
                  @keystring     = @cReplenishmentKey  OUTPUT,  
                  @b_success     = @b_success   OUTPUT,  
                  @n_err         = @n_err       OUTPUT,  
                  @c_errmsg      = @c_errmsg    OUTPUT  
  
               IF NOT @b_success = 1  
               BEGIN  
                  SELECT @n_continue = 3  
               END  
               ELSE  
               BEGIN  
                  -- SOS129128 Start  
   --               IF ISNULL(RTRIM(@cLottable02),'') <> '01000'  
   --               BEGIN  
   --                  INSERT TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5)  
   --                  VALUEs ('nsp_ReplenishmentRpt_BatchRefill_02_A', GetDate(), @cSKU, @cLOT, @cFromLOC, @cID, @cLottable02)  
   --               END  
                  -- SOS129128 End  
  
                  INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,  
                      StorerKey,      SKU,       FromLOC,      ToLOC,  
                      Lot,            Id,        Qty,          UOM,  
                      PackKey,        Priority,  QtyMoved,     QtyInPickLOC,  
                      RefNo,          Confirmed, ReplenNo,     Remark,  
                      LoadKey )  
                  VALUES (  
                      @cReplenishmentKey,        '',  
                      @cStorerKey,   @cSKU,      @cFromLOC,       @cLOC,  
                      @cLOT,         @cID,       @nQty,           @cUOM,  
                      @cPackkey,     '1',        0,               0,  
                      '',            'L',        '',              'BULK to PP',  
                      --''  )  
                      '2A'  ) -- SOS129861: 2A --> to trace the records is inserted from this script  
  
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63507   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Replenishment Failed! (nsp_ReplenishmentRpt_BatchRefill_02_A)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                  END  
               END  
  
   --                SELECT @cReplenishmentKey '@cReplenishmentKey',  
   --                @cStorerKey '@cStorerKey',   @cSKU '@cSKU',      @cFromLOC '@cFromLOC',  @cLOC '@cLOC',  
   --                @cLOT '@cLOT',         @cID '@cID',    @nQty '@nQty',        @cUOM '@cUOM',  
   --                @cPackkey '@cPackkey'  
  
               SET @nReplenQty = @nReplenQty - @nQty  
  
               FETCH NEXT FROM CUR_LooseUCC INTO @cLOT, @cFromLOC, @cID, @nQty, @cPackkey, @cUOM--, @cLottable02 -- SOS129128  
            END  
            CLOSE CUR_LooseUCC  
            DEALLOCATE CUR_LooseUCC  
         END  
         FETCH NEXT FROM CurReplenisment INTO @cStorerKey, @cSKU, @cLOC, @nReplenQty  
      END  
      CLOSE CurReplenisment  
      DEALLOCATE CurReplenisment  
  
      SELECT  
         @n_continue = 1,  
         @b_debug    = 0,  
         @c_ReplenishmentKey = '',  
         @c_ReplenishGroup   = ''  
  
      IF (@c_Zone02 = 'ALL')  
      BEGIN  
         IF EXISTS (SELECT 1 FROM REPLENISHMENT RPL WITH (NOLOCK)  
                    JOIN LOC WITH (NOLOCK) ON (RPL.ToLoc = LOC.LOC)  
                    WHERE RPL.Confirmed = 'L'  
                    AND   RPL.ReplenishmentGroup = ''  
                    AND   LOC.Facility = @c_Zone01)  
         BEGIN  
            SELECT @b_success = 1  
            EXECUTE nspg_GetKey  
               @keyname       = 'REPLENISHGROUP',  
               @fieldlength   = 10,  
               @keystring     = @c_ReplenishGroup OUTPUT,  
               @b_success     = @b_success        OUTPUT,  
               @n_err         = @n_err            OUTPUT,  
               @c_errmsg      = @c_errmsg         OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
            END  
         END  
      END  
      ELSE -- @c_Zone02 <> 'ALL'  
      BEGIN  
         IF EXISTS (SELECT 1 FROM REPLENISHMENT RPL WITH (NOLOCK)  
                    JOIN LOC WITH (NOLOCK) ON (RPL.ToLoc = LOC.LOC)  
                    WHERE RPL.Confirmed = 'L'  
                    AND   RPL.ReplenishmentGroup = ''  
                    AND   LOC.Facility = @c_Zone01  
                    AND   LOC.PutawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07,  
                                              @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12) )  
         BEGIN  
            SELECT @b_success = 1  
            EXECUTE nspg_GetKey  
               @keyname       = 'REPLENISHGROUP',  
               @fieldlength   = 10,  
               @keystring     = @c_ReplenishGroup OUTPUT,  
               @b_success     = @b_success        OUTPUT,  
               @n_err         = @n_err            OUTPUT,  
               @c_errmsg      = @c_errmsg         OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
            END  
         END  
      END  
  
      BEGIN TRAN  
  
      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN  
         IF (@c_Zone02 = 'ALL')  
         BEGIN  
            DECLARE cur_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT RPL.ReplenishmentKey  
            FROM REPLENISHMENT RPL WITH (NOLOCK)  
            JOIN LOC WITH (NOLOCK) ON (RPL.ToLoc = LOC.LOC)  
            WHERE RPL.Confirmed = 'L'  
            AND   RPL.ReplenishmentGroup = ''  
            AND   LOC.Facility = @c_Zone01  
            ORDER BY RPL.ReplenishmentKey  
  
            OPEN cur_REPLEN  
            FETCH NEXT FROM cur_REPLEN INTO @c_ReplenishmentKey  
  
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               -- Update ReplenishmentGroup  
               UPDATE REPLENISHMENT WITH (ROWLOCK)  
               SET ReplenishmentGroup = @c_ReplenishGroup  
               WHERE ReplenishmentKey = @c_ReplenishmentKey  
  
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Replenishment table failed. (nsp_ReplenishmentRpt_BatchRefill_02_A)'  
                                    + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                  ROLLBACK TRAN  
                  GOTO RETURN_SP  
               END  
  
               FETCH NEXT FROM cur_REPLEN INTO @c_ReplenishmentKey  
            END  
            CLOSE cur_REPLEN  
            DEALLOCATE cur_REPLEN  
         END  
         ELSE -- @c_Zone02 <> 'ALL'  
         BEGIN  
            DECLARE cur_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT RPL.ReplenishmentKey  
            FROM REPLENISHMENT RPL WITH (NOLOCK)  
            JOIN LOC WITH (NOLOCK) ON (RPL.ToLoc = LOC.LOC)  
            WHERE RPL.Confirmed = 'L'  
            AND   RPL.ReplenishmentGroup = ''  
            AND   LOC.Facility = @c_Zone01  
            AND   LOC.PutawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07,  
                                      @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)  
            ORDER BY RPL.ReplenishmentKey  
  
            OPEN cur_REPLEN  
            FETCH NEXT FROM cur_REPLEN INTO @c_ReplenishmentKey  
  
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               -- Update ReplenishmentGroup  
               UPDATE REPLENISHMENT WITH (ROWLOCK)  
               SET ReplenishmentGroup = @c_ReplenishGroup  
               WHERE ReplenishmentKey = @c_ReplenishmentKey  
  
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Replenishment table failed. (nsp_ReplenishmentRpt_BatchRefill_02_A)'  
                                    + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                  ROLLBACK TRAN  
                  GOTO RETURN_SP  
               END  
  
               FETCH NEXT FROM cur_REPLEN INTO @c_ReplenishmentKey  
            END  
            CLOSE cur_REPLEN  
            DEALLOCATE cur_REPLEN  
         END  
      END  
  
      IF @@TRANCOUNT > 0  
         COMMIT TRAN  
  
   END                                                               --(Wan01)  
   --(Wan01) - START  
   IF @c_FuncType = 'G'                                                
   BEGIN                                                               
      GOTO RETURN_SP  
   END                                                                
   --(Wan01) - END  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF (@c_Zone02 = 'ALL')  
      BEGIN  
         SELECT R.FromLoc,  
            R.Id,  
            R.ToLoc,  
            R.Sku,  
            SUM(R.Qty) AS Qty,  
            R.StorerKey,  
            R.Lot,  
            R.PackKey,  
            SKU.Descr,  
            R.Priority,  
            LOC.PutawayZone,  
            PACK.CaseCnt,  
            PACK.PackUOM1,  
            PACK.PackUOM3,  
            '' AS ReplenishmentKey,  
            SUM(R.Qty) AS Qty,  
            LA.Lottable02,  
            LA.Lottable04,  
            R.ReplenishmentGroup,  
            -- LEFT(LOC.LOC, 7) As LocGroup,  -- Shong01  
            -- LOC.LOCLevel  
            '' As LocGroup,  
            0  AS LOCLevel  
         FROM REPLENISHMENT R WITH (NOLOCK)  
         JOIN SKU  WITH (NOLOCK) ON (SKU.SKU = R.SKU AND SKU.StorerKey = R.StorerKey)  
         JOIN LOC  WITH (NOLOCK) ON (LOC.LOC = R.ToLoc)  
         JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey )  
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (R.Lot = LA.LOT)  
         WHERE R.Confirmed = 'L'  
         AND LOC.Facility = @c_Zone01  
         AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)  
         AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)  
         GROUP BY R.FromLoc,  
            R.Id,  
            R.ToLOC,  
            R.SKU,  
            R.StorerKey,  
            R.Lot,  
            R.PackKey,  
            SKU.Descr,  
            R.Priority,  
            LOC.PutawayZone,  
            PACK.CaseCnt,  
            PACK.PackUOM1,  
            PACK.PackUOM3,  
            LA.Lottable02,  
            LA.Lottable04,  
            R.ReplenishmentGroup  
            --,LEFT(LOC.LOC, 7) -- Shong01  
            --,LOC.LOCLevel  
            -- ORDER BY LOC.PutawayZone, R.FromLoc, R.Priority  
      END  
      ELSE  
      BEGIN  
         SELECT R.FromLoc,  
            R.Id,  
            R.ToLoc,  
            R.Sku,  
            SUM(R.Qty) As Qty,  
            R.StorerKey,  
            R.Lot,  
            R.PackKey,  
            SKU.Descr,  
            R.Priority,  
            LOC.PutawayZone,  
            PACK.CaseCnt,  
            PACK.PackUOM1,  
            PACK.PackUOM3,  
            '' AS ReplenishmentKey,  
            SUM(R.Qty) AS Qty,  
            LA.Lottable02,  
            LA.Lottable04,  
            R.ReplenishmentGroup,  
            -- LEFT(LOC.LOC, 7) As LocGroup, -- Shong01  
            -- LOC.LOCLevel  
            ''  As LocGroup,  
            0   AS LOCLevel  
         FROM  REPLENISHMENT R WITH (NOLOCK)  
         JOIN  SKU  WITH (NOLOCK) ON (SKU.StorerKey = R.StorerKey AND SKU.SKU = R.SKU)  
         JOIN  LOC  WITH (NOLOCK) ON (LOC.LOC = R.ToLoc)  
         JOIN  PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
         JOIN  LOTATTRIBUTE LA WITH (NOLOCK) ON (R.Lot = LA.LOT)  
         WHERE R.Confirmed = 'L'  
         AND LOC.Facility = @c_Zone01  
         AND LOC.PutawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07,  
                                 @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)  
         AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan01)  
         AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan01)  
         GROUP BY R.FromLoc,  
            R.Id,  
            R.ToLoc,  
            R.SKU,  
            R.StorerKey,  
            R.Lot,  
            R.PackKey,  
            SKU.Descr,  
            R.Priority,  
            LOC.PutawayZone,  
            PACK.CaseCnt,  
            PACK.PackUOM1,  
            PACK.PackUOM3,  
            LA.Lottable02,  
            LA.Lottable04,  
            R.ReplenishmentGroup  
            -- LEFT(LOC.LOC, 7), -- Shong01  
            -- LOC.LOCLevel  
         -- ORDER BY LOC.PutawayZone, R.FromLoc, R.Priority  
      END  
   END  
  
   RETURN_SP:  
  
   IF @n_continue = 3  -- Error Occured - Process and Return  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishmentRpt_BatchRefill_02_A'  
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
END  

GO