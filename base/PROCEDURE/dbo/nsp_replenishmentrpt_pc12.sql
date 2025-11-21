SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: nsp_ReplenishmentRpt_PC12                                   */  
/* Creation Date: 05-Aug-2002                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Wave Replenishment Report                                   */  
/*                                                                      */  
/* Called By: Replenishment entry's RCM                                 */  
/*                                                                      */  
/* PVCS Version: 1.7                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* UPDATEs:                                                             */  
/* Date         Author   Ver. Purposes                                  */  
/* 13-Dec-2002  Wally         SOS8935 - UOM in Replenishment            */  
/* 12-Aug-2003  June          SOS13417 - avoid replen from diff facility*/  
/* 15-Oct-2004  Mohit         Change cursor type                        */  
/* 30-Mar-2005  June          SOS33782                                  */  
/*                            Avoid suggesting same record twice        */  
/* 13-Jul-2005  June          SOS38086 - filter by facility             */  
/* 18-Jul-2005  MaryVong      SOS38137 Fixed empty replenishment and    */  
/*                            replenish on-hold stock issues            */  
/* 19-Mar-2009  NJOW01   1.0  128651 Shell Replenishment for a pick loc */  
/*                            only from a bulk loc(a pallet id) and     */  
/*                            disregard remaining qty if insufficient   */  
/* 30-Jun-2009  NJOW02   1.1  remove the multi pick loc checking and    */  
/*                            skip the plt id cannot fulfill pick loc   */  
/*                            expected replenishment qty                */  
/* 14-Aug-2009  ChewKP01 1.2  Replenishment Logic Change.  Re-write     */  
/*                            entire code. SOS#143482                   */  
/* 09-Dec-2010  LimKH01  1.3  Allow multiple pallet per pick location   */  
/* 27-Sep-2012  KHLim    1.4  SOS257066 Check Current Qty & QtyMax(KH02)*/  
/* 05-Jun-2013 NJOW01   1.5  280021-Change sorting, add lot2 and remove*/
/*                            lot3 filter.                              */
/* 18-JAN-2019  Wan01    1.7   WM - Add ReplCgrp & Functype             */
/************************************************************************/  
  
CREATE PROC  [dbo].[nsp_ReplenishmentRpt_PC12]  
    @c_zone01      NVARCHAR(10)   
   ,@c_zone02      NVARCHAR(10)   
   ,@c_zone03      NVARCHAR(10)   
   ,@c_zone04      NVARCHAR(10)   
   ,@c_zone05      NVARCHAR(10)   
   ,@c_zone06      NVARCHAR(10)   
   ,@c_zone07      NVARCHAR(10)   
   ,@c_zone08      NVARCHAR(10)   
   ,@c_zone09      NVARCHAR(10)   
   ,@c_zone10      NVARCHAR(10)   
   ,@c_zone11      NVARCHAR(10)   
   ,@c_zone12      NVARCHAR(10)   
   ,@c_Storerkey   NVARCHAR(15) 
   ,@c_ReplGrp     NVARCHAR(30) = 'ALL' --(Wan01)   
   ,@c_Functype    NCHAR(1)     = ''    --(Wan01)     

AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE        @n_continue int          /* continuation flag   
   1=Continue  
   2=failed but continue processsing   
   3=failed do not continue processing   
   4=successful but skip furthur processing */  
   DECLARE @b_debug int,  
     @c_Packkey NVARCHAR(10),  
     @c_UOM     NVARCHAR(10) -- SOS 8935 wally 13.dec.2002 FROM NVARCHAR(5) to NVARCHAR(10)  
   SELECT @n_continue=1, @b_debug = 0  
    
    
   -- DECLARE @n_qty int   -- SOS33782 - June 30.Mar.2005  
    
   IF @c_zone12 <> ''   
      SELECT @b_debug = CAST( @c_zone12 AS int)  
      -- create temp LOTXLOCXID  
      --SELECT lot, rowid=newid(), linenum=0  
      --INTO #Temp_LOTXLOCXID  
      --FROM LOTXLOCXID (NOLOCK)  
   --WHERE 1 = 2  
    
   --(Wan01) -- START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
      
   IF @c_Functype = 'P'                            
   BEGIN
      GOTO QUIT_SP
   END
   --(Wan01) -- END


   CREATE TABLE #T_LOTXLOCXID (  
      RowID  int IDENTITY,  
      Lot                  NVARCHAR(10),   
      Loc                  NVARCHAR(10),   
      sku                  NVARCHAR(20),   
      Storerkey            NVARCHAR(15),  
      Qty                  int         --  LimKH01  
   )  
  
   DECLARE @c_priority  NVARCHAR(5)  
   SELECT StorerKey, SKU, LOC FROMLOC, LOC ToLOC, Lot, Id, Qty, Qty QtyMoved, Qty QtyInPickLOC,  
         @c_priority Priority, Lot UOM, Lot PackKey  
   INTO #REPLENISHMENT  
   FROM LOTXLOCXID (NOLOCK)  
   WHERE 1 = 2  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      DECLARE @c_CurrentSKU NVARCHAR(20), @c_CurrentStorer NVARCHAR(15),  
      @c_CurrentLOC NVARCHAR(10), @c_CurrentPriority NVARCHAR(5),  
      @n_CurrentFullcase int, @n_CurrentSeverity int,  
      @n_CurrentQty        int, @n_CurrentQtyLocMax   int,  --KH02  
      @n_CurrentQtyLocMin  int, @n_CurrentMaxPallet   int,  -- LimKH01  
      @c_FromLOC NVARCHAR(10), @c_FromLOT NVARCHAR(10), @c_FromID NVARCHAR(18),  
      @n_FromQty int, @n_RemainingQty int, @n_PossibleCases int ,  
      @n_RemainingCases int, @n_OnHandQty int, @n_FromCases int ,  
      @c_ReplenishmentKey NVARCHAR(10), @n_NumberOfRecs int, @n_limitrecs int,  
      @c_FromLOT2 NVARCHAR(10),  
      @b_DoneCheckOverallocatedLots int,  
      @n_SKULOCavailableqty int,  
      @n_qtyrepl int  
        
      ---  
      ,@c_SKU           NVARCHAR(20)   
      ,@c_ToLOC         NVARCHAR(10)   
      ,@c_ToLOT         NVARCHAR(10)   
      ,@c_ID            NVARCHAR(10)  
      ,@c_Lottable04    NVARCHAR(14)  
      ,@c_Lottable05    NVARCHAR(14)  
      ,@c_QTY           int  
      ,@c_PickedQTY     int  
      ,@c_AllocatedQTY  int  
        
      --,@c_SKU           NVARCHAR(20)   
      ,@c_RToLOC        NVARCHAR(10)   
      ,@c_RToLOT        NVARCHAR(10)   
      ,@c_RID           NVARCHAR(10)  
      ,@c_RLottable04   NVARCHAR(14)  
      ,@c_RLottable05   NVARCHAR(14)  
      ,@c_RQTY          int  
      ,@c_RPickedQTY    int  
      ,@c_RAllocatedQTY int  
      ---  
      ,@c_ExecArguments       nvarchar(4000)   
               ,@cExecStatements      nvarchar(4000)  
               ,@c_storerFlag    int  
                 
      SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),  
      @c_CurrentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),  
      @n_CurrentFullcase = 0   , @n_CurrentSeverity = 9999999 ,  
      @n_FromQty = 0, @n_RemainingQty = 0, @n_PossibleCases = 0,   
      @n_RemainingCases =0, @n_FromCases = 0, @n_NumberOfRecs = 0,                   
      @n_limitrecs = 5, @n_qtyrepl = 0  
   /* Make a temp version of SKUxLOC */  
   --   SELECT ReplenishmentPriority, ReplenishmentSeverity, StorerKey,    --  not in use. LimKH01  
   --      SKU, LOC, ReplenishmentCasecnt  
   --   INTO #TempSKUxLOC  
   --   FROM SKUxLOC (NOLOCK)  
   --   WHERE 1=2  
  
      SET @c_storerFlag = 0  
      
                                       -- LimKH01  
      SET @cExecStatements =    N' DECLARE C_SKUXLOC CURSOR FAST_FORWARD READ_ONLY FOR  ' +  
                              ' SELECT SKUxLOC.storerkey, SKUxLOC.sku, SKUxLOC.loc , SKUxLOC.ReplenishmentPriority ,' +  
                              ' SKUxLOC.Qty-SKUxLOC.QtyPicked, SKUxLOC.QtyLocationLimit, ' +  --KH02
                              ' SKUxLOC.ReplenishmentSeverity ,SKUxLOC.ReplenishmentCasecnt, SKUxLOC.QtyLocationMinimum, LOC.MaxPallet ' +  
                              ' FROM SKUxLOC (NOLOCK), LOC (NOLOCK)' +  
                              ' WHERE SKUxLOC.LOC = LOC.LOC' +  
                              ' AND   SKUxLOC.ReplenishmentCasecnt > 0' +  
                              ' AND (SKUxLOC.LocationType = ''PICK'' OR SKUxLOC.LocationType = ''CASE'')' +  
                              ' AND   LOC.LocationFlag NOT IN ("DAMAGE", "HOLD")' + -- SOS38137  
                              ' AND  LOC.Status <> ''HOLD'' ' + -- SOS38137  
                              ' AND   ReplenishmentSeverity > 0' +  
                              ' AND   SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum' +   
                              ' AND   SKUxLOC.QtyExpected <= 0' +   
                              ' AND   LOC.FACILITY = @c_zone01'   
     
      SET @c_ExecArguments =  N'@c_zone01 NVARCHAR(10) '   
                                    
     
      IF @c_storerkey <> 'ALL'   
      BEGIN  
         SET @cExecStatements = @cExecStatements + ' AND   SKUxLOC.STORERKEY = @c_Storerkey'   
       
         SET @c_ExecArguments = @c_ExecArguments + ',@c_Storerkey NVARCHAR(15) '   
       
         SET @c_storerFlag = 1  
      END -- @c_storerkey <> 'ALL'   
           
      IF @c_zone02 <> 'ALL'  
      BEGIN  
         SET @cExecStatements = @cExecStatements + ' AND   LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, ' +  
            ' @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12) '   
              
         SET @c_ExecArguments =  @c_ExecArguments + ',@c_zone02 NVARCHAR(10) ' +  
                                 ',@c_zone03 NVARCHAR(10) ' +  
                                 ',@c_zone04 NVARCHAR(10) ' +  
                                 ',@c_zone05 NVARCHAR(10) ' +  
                                 ',@c_zone06 NVARCHAR(10) ' +  
                                 ',@c_zone07 NVARCHAR(10) ' +  
                                 ',@c_zone08 NVARCHAR(10) ' +  
                                 ',@c_zone09 NVARCHAR(10) ' +  
                                 ',@c_zone10 NVARCHAR(10) ' +  
                                 ',@c_zone11 NVARCHAR(10) ' +  
                                 ',@c_zone12 NVARCHAR(10) '   
      END -- @c_zone02 <> 'ALL'  
       
       
      SET @cExecStatements = @cExecStatements +  ' ORDER BY SKUxLOC.STORERKEY , SKUxLOC.SKU, SKUxLOC.LOC, SKUxLOC.ReplenishmentPriority , SKUxLOC.ReplenishmentSeverity desc'   
       
      If @b_debug = 1   
         Print @cExecStatements  
                            
      IF (@c_zone02 = 'ALL')  
      BEGIN        
         IF @c_storerFlag = 1  
         BEGIN  
            EXEC sp_ExecuteSql @cExecStatements   
                       , @c_ExecArguments    
                       , @c_zone01   
                       , @c_storerkey  
                         
            If @b_debug = 1   
            Print 'ALL - 1'                         
         END  
         ELSE  
         BEGIN  
            EXEC sp_ExecuteSql @cExecStatements   
                       , @c_ExecArguments    
                       , @c_zone01   
                 
            If @b_debug = 1   
               Print 'ALL - 0'                                 
         END   
      END                  
      ELSE  
      BEGIN  
         IF @c_storerFlag = 1  
         BEGIN   
            EXEC sp_ExecuteSql @cExecStatements   
                       , @c_ExecArguments    
                       , @c_zone01   
                       , @c_storerkey  
                       , @c_zone02  
                       , @c_zone03  
                       , @c_zone04  
                       , @c_zone05  
                       , @c_zone06  
                       , @c_zone07  
                       , @c_zone08  
                       , @c_zone09  
                       , @c_zone10  
                       , @c_zone11  
                       , @c_zone12  
                 
               If @b_debug = 1   
            Print 'NOT ALL - 1'                                 
         END  
         ELSE  
         BEGIN  
            EXEC sp_ExecuteSql @cExecStatements   
                       , @c_ExecArguments    
                       , @c_zone01   
                       , @c_zone02  
                       , @c_zone03  
                       , @c_zone04  
                       , @c_zone05  
                       , @c_zone06  
                       , @c_zone07  
                       , @c_zone08  
                       , @c_zone09  
                       , @c_zone10  
                       , @c_zone11  
                       , @c_zone12  
                         
            If @b_debug = 1   
               Print 'NOT ALL - 0'                                 
         END              
      END -- (@c_zone02 = 'ALL')  
       
       
       /*INSERT #TempSKUxLOC  
        SELECT ReplenishmentPriority, ReplenishmentSeverity, StorerKey,  
           SKU, LOC.LOC, ReplenishmentCasecnt  
        FROM SKUxLOC (NOLOCK), LOC (NOLOCK)  
        WHERE SKUxLOC.LOC = LOC.LOC  
       AND (SKUxLOC.LocationType = "PICK" OR SKUxLOC.LocationType = "CASE")  
       AND   LOC.LocationFlag NOT IN ("DAMAGE", "HOLD")  
       AND  LOC.Status <> 'HOLD' -- SOS38137  
       AND   ReplenishmentSeverity > 0  
       AND   SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtylocationMinimum  
       AND   LOC.FACILITY = @c_zone01  
       AND   LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07,   
               @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)*/  
        
      /*DECLARE C_SKUXLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT SKUxLOC.storerkey, SKUxLOC.sku, SKUxLOC.loc , SKUxLOC.ReplenishmentPriority ,  
      SKUxLOC.ReplenishmentSeverity ,SKUxLOC.ReplenishmentCasecnt   
      FROM SKUxLOC (NOLOCK), LOC (NOLOCK)  
      WHERE SKUxLOC.LOC = LOC.LOC  
      AND   SKUxLOC.ReplenishmentCasecnt > 0  
      AND (SKUxLOC.LocationType = "PICK" OR SKUxLOC.LocationType = "CASE")  
      AND   LOC.LocationFlag NOT IN ("DAMAGE", "HOLD") -- SOS38137  
      AND  LOC.Status <> 'HOLD' -- SOS38137  
      AND   ReplenishmentSeverity > 0  
      AND   SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum  
      AND   SKUxLOC.QtyExpected <= 0  
      AND   LOC.FACILITY = @c_zone01  
      AND   LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07,   
               @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)  
      ORDER BY SKUxLOC.STORERKEY , SKUxLOC.SKU, SKUxLOC.LOC, SKUxLOC.ReplenishmentPriority , SKUxLOC.ReplenishmentSeverity desc           
        
      END*/  
     
     
      OPEN C_SKUXLOC  
  
      FETCH NEXT FROM C_SKUXLOC INTO @c_CurrentStorer,   @c_CurrentSKU,    @c_FromLOC,    @c_CurrentPriority,  
                                     @n_CurrentQty,      @n_CurrentQtyLocMax,    --KH02
                                     @n_CurrentSeverity, @n_CurrentFullcase, @n_CurrentQtyLocMin, @n_CurrentMaxPallet   --  LimKH01  
                                       
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN -- while header C_SKUXLOC  
         If @b_debug = 1  
            Select '@c_CurrentStorer',@c_CurrentStorer  
           
         IF (@c_zone02 = 'ALL')  
         BEGIN  
            DECLARE C_LOTXLOCXID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT LOTXLOCXID.SKU, LOTXLOCXID.LOC, LOTXLOCXID.LOT, LOTXLOCXID.ID, Lottable04, Lottable05,  
                  LOTXLOCXID.QTY , LOTXLOCXID.QtyPicked , LOTXLOCXID.QtyAllocated  
            --rowid=newid(), linenum=0  
            FROM  LOTXLOCXID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK),  
                  LOT (NOLOCK) -- SOS38137 Added LOT  
            WHERE    LOTXLOCXID.StorerKey = @c_CurrentStorer  
               AND   LOTXLOCXID.SKU    = @c_CurrentSKU  
               AND   LOTXLOCXID.LOC    = LOC.LOC  
               AND   LOC.LocationFlag  <> 'DAMAGE'  
               AND   LOC.LocationFlag  <> 'HOLD'  
               AND   LOC.Status        <> 'HOLD' -- SOS38137  
               AND   LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated > 0  
               AND   LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND   
               AND   LOTXLOCXID.LOC    <> @c_FromLOC  
               AND   LOTATTRIBUTE.LOT  = LOTXLOCXID.LOT  
               -- SOS38137 -Start  
               AND   LOTXLOCXID.LOT    = LOT.LOT  
               AND   LOT.Status        = 'OK'  
               -- End  
               --AND   (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR   --NJOW01
               --       LOTATTRIBUTE.Lottable03 = 'ULP-01' OR  
               --       LOTATTRIBUTE.Lottable03 = '')  
               -- SOS38137  
               AND   LOC.LOCATIONTYPE  <> 'CASE'  AND   LOC.LOCATIONTYPE <> 'PICK'   
               AND   LOC.FACILITY      = @c_zone01  
            GROUP BY LOTXLOCXID.LOT, Lottable04, Lottable05 -- SOS33782  
                  ,LOTXLOCXID.StorerKey, LOTXLOCXID.SKU, LOTXLOCXID.QTY  
                  ,LOTXLOCXID.QtyPicked, LOTXLOCXID.QtyAllocated, LOTXLOCXID.LOC, LOTXLOCXID.ID  
            ORDER BY Lottable04, (LOTXLOCXID.QTY - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated), Lottable05, LOTXLOCXID.LOT --NJOW01  
            --ORDER BY (LOTXLOCXID.QTY - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated), Lottable04, Lottable05, LOTXLOCXID.LOT  
         END  
         ELSE  
         BEGIN  
            DECLARE C_LOTXLOCXID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT LOTXLOCXID.SKU, LOTXLOCXID.LOC, LOTXLOCXID.LOT, LOTXLOCXID.ID, Lottable04, Lottable05,  
                  LOTXLOCXID.QTY , LOTXLOCXID.QtyPicked , LOTXLOCXID.QtyAllocated  
            --rowid=newid(), linenum=0  
            FROM  LOTXLOCXID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK),  
                  LOT (NOLOCK) -- SOS38137 Added LOT  
            WHERE    LOTXLOCXID.StorerKey = @c_CurrentStorer  
               AND   LOTXLOCXID.SKU    = @c_CurrentSKU  
               AND   LOTXLOCXID.LOC    = LOC.LOC  
               AND   LOC.LocationFlag  <> "DAMAGE"  
               AND   LOC.LocationFlag  <> "HOLD"  
               AND   LOC.Status        <> "HOLD" -- SOS38137  
               AND   LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated > 0  
               AND   LOTXLOCXID.QtyExpected = 0 -- make sure we aren't going to try to pull from a location that needs stuff to satisfy existing demAND   
               AND   LOTXLOCXID.LOC    <> @c_FromLOC  
               AND   LOTATTRIBUTE.LOT  = LOTXLOCXID.LOT  
               -- SOS38137 -Start  
               AND   LOTXLOCXID.LOT    = LOT.LOT  
               AND   LOT.Status        = 'OK'  
               -- End  
               --AND   (LOTATTRIBUTE.Lottable03 = 'BIC-01' OR  --NJOW01
               --       LOTATTRIBUTE.Lottable03 = 'ULP-01' OR  
               --       LOTATTRIBUTE.Lottable03 = '')  
                 -- SOS38137  
               AND   LOC.LOCATIONTYPE  <> 'CASE'  AND   LOC.LOCATIONTYPE <> 'PICK'   
               AND   LOC.FACILITY      = @c_zone01  
               AND   LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07,   
                  @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)  
            GROUP BY LOTXLOCXID.LOT, Lottable04, Lottable05 -- SOS33782  
                  ,LOTXLOCXID.StorerKey, LOTXLOCXID.SKU, LOTXLOCXID.QTY, LOC.PUTAWAYZONE  
                  ,LOTXLOCXID.QtyPicked, LOTXLOCXID.QtyAllocated, LOTXLOCXID.LOC, LOTXLOCXID.ID  
            ORDER BY Lottable04, (LOTXLOCXID.QTY - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated), Lottable05, LOTXLOCXID.LOT  --NJOW01
            --ORDER BY (LOTXLOCXID.QTY - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyAllocated),  Lottable04, Lottable05, LOTXLOCXID.LOT  
         END -- (@c_zone02 = 'ALL')  
           
         OPEN C_LOTXLOCXID  
  
         FETCH NEXT FROM C_LOTXLOCXID INTO   
                  @c_SKU                  ,@c_ToLOC               ,@c_ToLOT           
                  ,@c_ID                  ,@c_Lottable04          ,@c_Lottable05      
                  ,@c_QTY                 ,@c_PickedQTY           ,@c_AllocatedQTY  
                           
         WHILE (@@FETCH_STATUS <> -1)  
         BEGIN -- while header C_LOTXLOCXID  
                          
            --- Verification Start ---  
              
            IF NOT EXISTS(SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_ID AND STATUS = "HOLD")  
            BEGIN  
            
             /***************************************************/  
             /*  For Multiple Pick Location Checking (ChewKP01) */   
             /*  Do Not Suggest Same Location for Replenishment */  
             /*  1. If there is a qualify location:             */  
             /*     a. Insert into #REPLENISHMENT               */  
             /*     b. Insert into #T_LOTXLOCXID                */  
             /***************************************************/  
               
             /***************************************************/  
             /* (START)                                         */  
             /***************************************************/  
               
               IF  NOT EXISTS (SELECT 1 FROM #T_LOTXLOCXID 
                               WHERE SKU = @c_SKU AND Storerkey = @c_CurrentStorer  
                               GROUP BY SKU, StorerKey  
                               HAVING SUM(Qty) + @n_CurrentQty          > @n_CurrentQtyLocMin ) --KH02: if Qty still not exceed Minimum, allow replenishment
               AND NOT EXISTS (SELECT 1 FROM #T_LOTXLOCXID 
                               WHERE SKU = @c_SKU AND Storerkey = @c_CurrentStorer  
                               GROUP BY SKU, StorerKey  
                               HAVING SUM(Qty) + @n_CurrentQty + @c_QTY > @n_CurrentQtyLocMax ) --KH02: if Qty will not exceed Maximum, allow replenishment
               BEGIN  
     
                  SELECT @c_Packkey = PACK.PackKey,  
                  @c_UOM = PACK.PackUOM3  
                  FROM SKU (NOLOCK), PACK (NOLOCK)  
                  WHERE SKU.PackKey = PACK.Packkey  
                  AND   SKU.StorerKey = @c_CurrentStorer  
                  AND   SKU.SKU = @c_CurrentSKU  
                   
                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN  
                     INSERT #REPLENISHMENT (  
                        StorerKey,   
                        SKU,  
                        FROMLOC,   
                        ToLOC,   
                        Lot,  
                        Id,   
                        Qty,  
                        UOM,  
                        PackKey,  
                        Priority,  
                        QtyMoved,  
                        QtyInPickLOC)   
                                          VALUES (  
                        @c_CurrentStorer,   
                        @c_SKU,   
                        @c_ToLOC,   
                        @c_FromLOC,   
                        @c_ToLOT,  
                        @c_ID,  
                        @c_QTY,  
                        @c_UOM,  
                        @c_Packkey,  
                        @c_CurrentPriority,  
                        @c_AllocatedQTY,  
                        @c_PickedQTY)      
                     --- Insert into #REPLENISHMENT (End) ---  
               
                     --- Insert into #T_LOTXLOCXID (Start) ---  
                     INSERT #T_LOTXLOCXID (  
                        Lot,   
                        Loc,  
                        sku,   
                        storerkey,  
                        qty)            --  LimKH01  
                     VALUES (  
                        @c_ToLOT,   
                        @c_ToLOC,   
                        @c_SKU,   
                        @c_CurrentStorer,  
                        @c_QTY)         --  LimKH01  
                     ---  Insert into #T_LOTXLOCXID (End)  ---      
                                 
                  END -- INSERT INTO #REPLENISHMENT  
              
                  IF @b_debug = 1  
                  BEGIN  
                     Select   
                        '@c_CurrentStorer', @c_CurrentStorer,  
                        '@c_SKU', @c_SKU,   
                        '@c_FromLOC', @c_FromLOC,   
                        '@c_ToLOC', @c_ToLOC,   
                        '@c_FromLOT',@c_ToLOT,  
                        '@c_ID',@c_ID,  
                        '@c_QTY',@c_QTY,  
                        '@c_UOM',@c_UOM,  
                        '@c_Packkey',@c_Packkey,  
                        '@c_CurrentPriority',@c_CurrentPriority,  
                        '@c_AllocatedQTY',@c_AllocatedQTY,  
                        '@c_PickedQTY',@c_PickedQTY            
                  END  

                  IF @n_CurrentMaxPallet <= 1   -- LimKH01  
                  BEGIN  
                     BREAK    
                  END  
                  --- EXIT LOOP SINCE Had Found a Location For Replenishment             
               END -- IF NOT EXISTS (SELECT 1 FROM #T_LOTXLOCXID WHERE Lot = @c_ToLOT   
            
          /***************************************************/  
          /* (END)                                           */  
          /***************************************************/  
                              
            END -- IF NOT EXISTS(SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_ID AND STATUS = "HOLD")  
            
           
            --- Verification End ---  
                          
                          
                          
            FETCH NEXT FROM C_LOTXLOCXID INTO   
                     @c_SKU                  ,@c_ToLOC               ,@c_ToLOT           
                     ,@c_ID                  ,@c_Lottable04          ,@c_Lottable05      
                     ,@c_QTY                 ,@c_PickedQTY           ,@c_AllocatedQTY  
         END -- while header C_LOTXLOCXID  
         CLOSE C_LOTXLOCXID  
         DEALLOCATE C_LOTXLOCXID      
           
      FETCH NEXT FROM C_SKUXLOC INTO @c_CurrentStorer,   @c_CurrentSKU,    @c_FromLOC,    @c_CurrentPriority,  
                                     @n_CurrentQty,      @n_CurrentQtyLocMax,    --KH02
                                     @n_CurrentSeverity, @n_CurrentFullcase, @n_CurrentQtyLocMin, @n_CurrentMaxPallet      --  LimKH01  
                                          
      END -- C_SKUXLOC                                 
      CLOSE C_SKUXLOC  
      DEALLOCATE C_SKUXLOC                       
        
      IF @n_continue=1 OR @n_continue=2  
      BEGIN  
         /* Update the column QtyInPickLOC in the Replenishment Table */  
         UPDATE #REPLENISHMENT SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked  
         FROM SKUxLOC (NOLOCK)  
         WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey AND  
         #REPLENISHMENT.SKU = SKUxLOC.SKU AND  
         #REPLENISHMENT.toLOC = SKUxLOC.LOC   
      
      
         /* Insert into Replenishment Table Now */  
         DECLARE @b_success int,  
         @n_err     int,  
         @c_errmsg  NVARCHAR(255)  
           
         DECLARE CUR1 CURSOR  FAST_FORWARD READ_ONLY FOR   
         SELECT R.FROMLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM  
         FROM #REPLENISHMENT R  
             
         OPEN CUR1  
         FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLOC, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLOT, @c_PackKey, @c_Priority, @c_UOM  
           
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            EXECUTE nspg_GetKey  
                "REPLENISHKEY",  
                10,  
                @c_ReplenishmentKey OUTPUT,  
                @b_success OUTPUT,  
                @n_err OUTPUT,  
                @c_errmsg OUTPUT  
            IF NOT @b_success = 1  
            BEGIN  
               BREAK  
            END  
                 
                    
            IF @b_success = 1  
            BEGIN   
                  
  
                                   
               INSERT REPLENISHMENT (replenishmentgroup,   
                     ReplenishmentKey,  
                     StorerKey,  
                     Sku,  
                     FROMLoc,  
                     ToLoc,  
                     Lot,  
                     Id,  
                     Qty,  
                     UOM,  
                     PackKey,  
                     Confirmed)  
               VALUES ('IDS',   
                     @c_ReplenishmentKey,  
                     @c_CurrentStorer,  
                     @c_CurrentSKU,  
                     @c_FromLOC,  
                     @c_CurrentLOC,  
                     @c_FromLOT,  
                     @c_FromID,  
                     @n_FromQty,  
                     @c_UOM,  
                     @c_PackKey,  
                     'N')  
                    
                    
               SELECT @n_err = @@ERROR  
  
               
            END -- IF @b_success = 1  
               
               
            FETCH NEXT FROM CUR1 INTO @c_FromLOC, @c_FromID, @c_CurrentLOC, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLOT, @c_PackKey, @c_Priority, @c_UOM  
         END -- WHILE  
         DEALLOCATE CUR1  
     
         -- End Insert Replenishment  
        
      END -- @n_continue = 1 OR @n_continue = 2  
   END -- END OF PROGRAM      
     
   DROP TABLE #T_LOTXLOCXID  
   DROP TABLE #REPLENISHMENT   -- LimKH01  
   --DROP TABLE #TempSKUxLOC  
  

   --(Wan01) - START
   QUIT_SP:
   IF @c_Functype = 'G'
   BEGIN
      RETURN
   END
   --(Wan01) - END

   IF ( @c_zone02 = 'ALL')  
   BEGIN               
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,   
            SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, 
            L.Lottable02  --NJOW01
      FROM REPLENISHMENT R (NOLOCK)
      JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey 
      JOIN LOC (NOLOCK) ON LOC.Loc = R.ToLoc 
      JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey  
      JOIN LOTATTRIBUTE L (NOLOCK) ON L.Lot = R.Lot 
      WHERE R.Confirmed    = 'N'  
      AND LOC.Facility   = @c_zone01 -- SOS38086  
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')          --(Wan01)  
      AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')     --(Wan01)  
      ORDER BY LOC.PutawayZone, R.Priority  
   END  
   ELSE  
   BEGIN  
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,   
            SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey,
            L.Lottable02 --NJOW01  
      FROM REPLENISHMENT R (NOLOCK)
      JOIN SKU (NOLOCK) ON SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey 
      JOIN LOC (NOLOCK) ON LOC.Loc = R.ToLoc 
      JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey  
      JOIN LOTATTRIBUTE L (NOLOCK) ON L.Lot = R.Lot 
      WHERE R.Confirmed    = 'N'  
      AND LOC.Facility   = @c_zone01 -- SOS38086  
      AND LOC.putawayzone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07,   
             @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)  
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')          --(Wan01)  
      AND (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')     --(Wan01)  
      ORDER BY LOC.PutawayZone, R.Priority  
   END  
   SET NOCOUNT OFF  
END  

GO