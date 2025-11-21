SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: nsp_ReplenishmentRpt_BatchRefill_04                */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Replensihment Report for IDSTW Unilever principle due to    */  
/*          diff LOT Allocation Sorting By SHONG on 11-Sep-2004         */  
/*          Version 1.0                                                 */  
/*          By SHONG 28th Mar 2003                                      */  
/*          Make use of SKU.PickCode for replenishment lot sorting      */  
/*                                                                      */  
/*                                                                      */  
/* Input Parameters:  @c_zone01                                         */  
/*                    @c_zone02                                         */  
/*                    @c_zone03                                         */  
/*                    @c_zone04                                         */  
/*                    @c_zone05                                         */  
/*                    @c_zone06                                         */  
/*                    @c_zone07                                         */  
/*                    @c_zone08                                         */  
/*                    @c_zone09                                         */  
/*                    @c_zone10                                         */  
/*                    @c_zone11                                         */  
/*                    @c_zone12                                         */  
/*                                                                      */  
/* PVCS Version: 1.6                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 01-Mar-2010  YTwan     1.2   SOS#162220 NiveaCN replenish from CASE  */  
/*                              location. (Wan01)                       */  
/* 17-Feb-2012  TLTING    1.3   Reduce blokcing                         */  
/* 03-SEP-2014  YTWan     1.4   SOS#319853 - CR for NIVEA Replenishment */  
/*                              Report-Config to sort by Loc level.Wan02*/  
/* 05-MAR-2018 Wan03      1.5   WM - Add Functype                       */  
/* 05-OCT-2018 CZTENG01   1.6   WM - Add StorerKey,ReplGrp              */  
/************************************************************************/  
  
CREATE PROC  [dbo].[nsp_ReplenishmentRpt_BatchRefill_04]  
               @c_zone01      NVARCHAR(10)  
,              @c_zone02      NVARCHAR(10)  
,              @c_zone03      NVARCHAR(10)  
,              @c_zone04      NVARCHAR(10)  
,              @c_zone05      NVARCHAR(10)  
,              @c_zone06      NVARCHAR(10)  
,              @c_zone07      NVARCHAR(10)  
,              @c_zone08      NVARCHAR(10)  
,              @c_zone09      NVARCHAR(10)  
,              @c_zone10      NVARCHAR(10)  
,              @c_zone11      NVARCHAR(10)  
,              @c_zone12      NVARCHAR(10)  
,              @c_storerkey   NVARCHAR(15) = 'ALL' --(CZTENG01)  
,              @c_ReplGrp     NVARCHAR(30) = 'ALL' --(CZTENG01)  
,              @c_Functype    NCHAR(1) = ''        --(Wan03)   
AS  
BEGIN  
   SET NOCOUNT ON   
 SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE        @n_continue int          /* continuation flag  
   1=Continue  
   2=failed but continue processsing  
   3=failed do not continue processing  
   4=successful but skip furthur processing */  
   ,               @n_starttcnt   int  
  
   DECLARE @b_debug int,  
   @c_Packkey NVARCHAR(10),  
   @c_UOM     NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)  
   @n_qtytaken int,  
   @n_SerialNo int,  
   @n_ROWREF   INT,  
   @n_Rowcnt   INT,  
   @n_ReplenishmentKey INT    
  
  
   SELECT @n_continue=1, @b_debug = 0  
   SELECT @n_starttcnt=@@TRANCOUNT  
     
   IF @c_zone12 <> '' AND ISNUMERIC(@c_zone12) = 1  
      SELECT @b_debug = CAST( @c_zone12 AS int)  
  
   DECLARE @c_priority  NVARCHAR(5)  
  
   --(Wan01) - Start  
   DECLARE @b_GetBulkLoc   INT  
   SET   @b_GetBulkLoc = 0  
   --(Wan01) - End  
  
   DECLARE @n_ReplByLocLevel  INT          --(Wan02)  
         , @n_LocLevel        INT          --(Wan02)  
           
   --(Wan03) - START  
   IF ISNULL(@c_ReplGrp,'') = ''  
   BEGIN  
      SET @c_ReplGrp = 'ALL'  
   END  
   --(Wan03) - END      
  
   IF @c_FuncType IN ( '','G' )                                      --(Wan03)  
   BEGIN                                                             --(Wan03)     
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  
  
  
      CREATE TABLE #REPLENISHMENT  
      (       
            ROWREF   INT IDENTITY(1,1) NOT NULL Primary Key,  
            REPLENISHMENT NVARCHAR(10) NOT NULL DEFAULT '',  
            StorerKey NVARCHAR(20) NOT NULL,  
            SKU      NVARCHAR(20)  NOT NULL,  
            FROMLOC  NVARCHAR(10)  NOT NULL,  
            ToLOC    NVARCHAR(10)  NOT NULL,  
            LOT      NVARCHAR(10)  NOT NULL,  
            ID       NVARCHAR(18)  NOT NULL,  
            QTY      INT          NOT NULL,  
            QtyMoved INT          NOT NULL,  
            QtyInPickLOC INT      NOT NULL,  
            Priority  NVARCHAR(5),  
            UOM       NVARCHAR(10) NOT NULL,  
            PACKKEY   NVARCHAR(10) NOT NULL   
            )  
           
      CREATE TABLE #TempSKUxLOC  
      (  
            ROWREF   INT IDENTITY(1,1) NOT NULL Primary Key,  
            ReplenishmentPriority NVARCHAR(5) NOT NULL,   
            ReplenishmentSeverity INT  NOT NULL,  
            StorerKey             NVARCHAR(15) NOT NULL,  
            SKU                   NVARCHAR(20) NOT NULL,  
            LOC                   NVARCHAR(10),  
            ReplenishmentCasecnt  INT NOT NULL  
      )  
     
         /*  
      SELECT StorerKey,   
             SKU,   
             LOC as FromLOC,   
             LOC as ToLOC,   
             Lot,   
             Id,   
             Qty,   
             Qty as QtyMoved,   
             Qty as QtyInPickLOC,  
             @c_priority as Priority,   
             Lot as UOM,   
             Lot PackKey  
      INTO #REPLENISHMENT  
      FROM LOTxLOCxID WITH (NOLOCK)  
      WHERE 1 = 2  
      */  
      IF @n_continue = 1 or @n_continue = 2  
      BEGIN  
         DECLARE @c_CurrentSKU NVARCHAR(20), @c_CurrentStorer NVARCHAR(15),  
         @c_CurrentLOC NVARCHAR(10), @c_CurrentPriority NVARCHAR(5),  
         @n_CurrentFullCase int, @n_CurrentSeverity int,  
         @c_FromLOC NVARCHAR(10), @c_fromlot NVARCHAR(10), @c_fromid NVARCHAR(18),  
         @n_FromQty int, @n_remainingqty int, @n_PossibleCases int ,  
         @n_remainingcases int, @n_OnHandQty int, @n_fromcases int ,  
         @c_ReplenishmentKey NVARCHAR(10), @n_numberofrecs int, @n_limitrecs int,  
         @c_fromlot2 NVARCHAR(10),  
         @b_DoneCheckOverAllocatedLots int,  
         @n_SKULocAvailableQty int  
  
         DECLARE @c_PickCode NVARCHAR(10)  
  
         SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),  
         @c_CurrentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),  
         @n_CurrentFullCase = 0   , @n_CurrentSeverity = 9999999 ,  
         @n_FromQty = 0, @n_remainingqty = 0, @n_PossibleCases = 0,  
         @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,  
         @n_limitrecs = 5  
        
         /* Make a temp version of SKUxLOC */  
   /*      SELECT ReplenishmentPriority,   
                ReplenishmentSeverity,StorerKey,  
                SKU, LOC, ReplenishmentCasecnt  
         INTO #TempSKUxLOC  
         FROM SKUxLOC WITH (NOLOCK)  
         WHERE 1=2  
     */      
         IF (@c_zone02 = 'ALL')  
         BEGIN  
            INSERT #TempSKUxLOC  
            SELECT SKUxLOC.ReplenishmentPriority,  
            ReplenishmentSeverity =  
                  CASE WHEN PACK.CaseCnt > 0   
                     THEN FLOOR( ( CONVERT(real,QtyLocationLimit) -   
                                      ( CONVERT(real,SKUxLOC.Qty) -   
                                        CONVERT(real,SKUxLOC.QtyPicked) -   
                                        CONVERT(real,SKUxLOC.QtyAllocated) )   
                                   ) / CONVERT(real,PACK.CaseCnt) )  
                     ELSE QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))  
                  END,  
            SKUxLOC.StorerKey,  
            SKUxLOC.SKU,  
            SKUxLOC.LOC,  
            ReplenishmentCasecnt =   
               CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt  
                  ELSE 1  
               END  
            FROM SKUxLOC WITH (NOLOCK), LOC WITH (NOLOCK), SKU WITH (NOLOCK), PACK WITH (NOLOCK)  
            WHERE SKUxLOC.LOC = LOC.LOC  
            AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')  
            AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')  
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated < SKUxLOC.QtyLocationMinimum )  
            AND  LOC.FACILITY = @c_zone01  
            AND  SKUxLOC.StorerKey = SKU.StorerKey  
            AND  SKUxLOC.SKU = SKU.SKU  
            AND  SKU.PackKey = PACK.PACKKey  
            AND  EXISTS( SELECT 1 FROM SKUxLOC SL WITH (NOLOCK) WHERE SL.StorerKey = SKUxLOC.StorerKey   
                          AND SL.SKU = SKUxLOC.SKU AND SL.Qty - SL.QtyPicked - SL.QtyAllocated > 0   
                          AND SL.LOC <> SKUxLOC.LOC )  
            AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') --(Wan03)  
         END  
         ELSE  
         BEGIN  
            INSERT #TempSKUxLOC  
            SELECT SKUxLOC.ReplenishmentPriority,  
            ReplenishmentSeverity =  
                  CASE WHEN PACK.CaseCnt > 0   
                     THEN FLOOR( ( CONVERT(real,QtyLocationLimit) -   
                                      ( CONVERT(real,SKUxLOC.Qty) -   
                                        CONVERT(real,SKUxLOC.QtyPicked) -   
                                        CONVERT(real,SKUxLOC.QtyAllocated) )   
                                   ) / CONVERT(real,PACK.CaseCnt) )  
                     ELSE QtyLocationLimit - ( SKUxLOC.Qty - (SKUxLOC.QtyPicked + SKUxLOC.QtyAllocated ))  
                  END,  
            SKUxLOC.StorerKey,  
            SKUxLOC.SKU,  
            SKUxLOC.LOC,  
            ReplenishmentCasecnt =   
               CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt  
                  ELSE 1  
               END  
            FROM SKUxLOC WITH (NOLOCK), LOC WITH (NOLOCK), SKU WITH (NOLOCK), PACK WITH (NOLOCK)  
            WHERE SKUxLOC.LOC = LOC.LOC  
            AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')  
            AND (SKUxLOC.LocationType = 'PICK' or SKUxLOC.LocationType = 'CASE')  
            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked - SKUxLOC.QtyAllocated < SKUxLOC.QtyLocationMinimum )  
            AND  LOC.FACILITY = @c_zone01  
            AND  SKUxLOC.StorerKey = SKU.StorerKey  
            AND  SKUxLOC.SKU = SKU.SKU  
            AND  SKU.PackKey = PACK.PACKKey  
            AND  EXISTS( SELECT 1 FROM SKUxLOC SL WITH (NOLOCK) WHERE SL.StorerKey = SKUxLOC.StorerKey   
                          AND SL.SKU = SKUxLOC.SKU AND SL.Qty - SL.QtyPicked - SL.QtyAllocated > 0   
              AND SL.LOC <> SKUxLOC.LOC )  
            -- Remark by June 1.Aug.02  
            --  AND  SKUxLOC.QtyAllocated > 0  
            AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)  
            AND (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') --(Wan03)  
         END  
         IF @b_debug = 1  
         BEGIN  
            SELECT 'TEMPSKUxLOC table'  
            SELECT * FROM #TEMPSKUxLOC (NOLOCK)  
         END  
  
        
         BEGIN TRANSACTION  
         WHILE (1=1) -- while 1  
         BEGIN  
            SET ROWCOUNT 1  
            SELECT @c_CurrentPriority = ReplenishmentPriority  
            FROM #TempSKUxLOC  
            WHERE ReplenishmentPriority > @c_CurrentPriority  
            AND  ReplenishmentCasecnt > 0  
            ORDER BY ReplenishmentPriority  
            IF @@ROWCOUNT = 0  
            BEGIN  
               SET ROWCOUNT 0  
               BREAK  
            END  
            IF @b_debug = 1  
            BEGIN  
               Print 'Working on @c_CurrentPriority:' + dbo.fnc_RTrim(@c_CurrentPriority)  
            END   
            SET ROWCOUNT 0  
            /* Loop through SKUxLOC for the currentSKU, current storer */  
            /* to pickup the next severity */  
            SELECT @n_CurrentSeverity = 999999999  
            WHILE (1=1) -- while 2  
            BEGIN  
               SET ROWCOUNT 1  
               SELECT @n_CurrentSeverity = ReplenishmentSeverity  
               FROM #TempSKUxLOC  
               WHERE ReplenishmentSeverity < @n_CurrentSeverity  
               AND ReplenishmentPriority = @c_CurrentPriority  
               AND  ReplenishmentCasecnt > 0  
               ORDER BY ReplenishmentSeverity DESC  
  
               IF @@ROWCOUNT = 0  
               BEGIN  
                  SET ROWCOUNT 0  
                  BREAK  
               END  
               SET ROWCOUNT 0  
               IF @b_debug = 1  
               BEGIN  
                  Print 'Working on @n_CurrentSeverity:' + dbo.fnc_RTrim(@n_CurrentSeverity)  
               END   
  
               /* Now - for this priority, this severity - find the next storer row */  
               /* that matches */  
               SELECT @c_CurrentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),  
               @c_CurrentLOC = SPACE(10)  
               WHILE (1=1) -- while 3  
               BEGIN  
                  IF dbo.fnc_RTrim(@c_zone11) IS NOT NULL AND dbo.fnc_RTrim(@c_zone11) <> ''  
                  BEGIN  
                     SET ROWCOUNT 1  
                     SELECT @c_CurrentStorer = StorerKey  
                     FROM #TempSKUxLOC  
                     WHERE StorerKey > @c_CurrentStorer  
                     AND ReplenishmentSeverity = @n_CurrentSeverity  
                     AND ReplenishmentPriority = @c_CurrentPriority  
                     AND StorerKey Like @c_zone11  
                     ORDER BY StorerKey  
                  END  
                  ELSE  
                  BEGIN  
                     SET ROWCOUNT 1  
                     SELECT @c_CurrentStorer = StorerKey  
                     FROM #TempSKUxLOC  
                     WHERE StorerKey > @c_CurrentStorer  
                     AND ReplenishmentSeverity = @n_CurrentSeverity  
                     AND ReplenishmentPriority = @c_CurrentPriority  
                     ORDER BY StorerKey  
                  END   
                 
                  IF @@ROWCOUNT = 0  
                  BEGIN  
                     SET ROWCOUNT 0  
                     BREAK  
                  END  
                  SET ROWCOUNT 0  
                  IF @b_debug = 1  
                  BEGIN  
                     Print 'Working on @c_CurrentStorer:' + dbo.fnc_RTrim(@c_CurrentStorer)  
                  END   
  
  
                  --(Wan02) - START  
                  SET @n_ReplByLocLevel = 0  
                  SELECT @n_ReplByLocLevel = MAX(CASE WHEN Code = 'ReplByLocLevel' THEN 1 ELSE 0 END)  
                  FROM CODELKUP WITH (NOLOCK)  
                  WHERE ListName = 'REPORTCFG'  
                  AND   StorerKey = @c_CurrentStorer  
                  AND   Long = 'r_replenishment_report04'    
                  AND   (Short <> 'N' OR Short IS NULL)                
                  --(Wan02) - END  
  
                  /* Now - for this priority, this severity - find the next SKU row */  
                  /* that matches */  
                  SELECT @c_CurrentSKU = SPACE(20),  
                  @c_CurrentLOC = SPACE(10)  
                  WHILE (1=1) -- while 4  
                  BEGIN  
                     SET ROWCOUNT 1  
                     SELECT @c_CurrentStorer = StorerKey ,  
                           @c_CurrentSKU = SKU,  
                           @c_CurrentLOC = LOC,  
                           @n_currentFullCase = ReplenishmentCasecnt  
                     FROM #TempSKUxLOC  
                     WHERE SKU > @c_CurrentSKU   
                     AND StorerKey = @c_CurrentStorer  
                     AND ReplenishmentSeverity = @n_CurrentSeverity  
                     AND ReplenishmentPriority = @c_CurrentPriority  
                     ORDER BY SKU  
                     IF @@ROWCOUNT = 0  
                     BEGIN  
                        SET ROWCOUNT 0  
                        BREAK  
                     END  
                     SET ROWCOUNT 0  
                    
                     IF @b_debug = 1  
                     BEGIN  
                        Print 'Working on @c_CurrentSKU:' + dbo.fnc_RTrim(@c_CurrentSKU) + ' @c_CurrentLOC:' + dbo.fnc_RTrim(@c_CurrentLOC)   
                     END   
                     /* We now have a pickLocation that needs to be replenished! */  
                     /* Figure out which Locations in the warehouse to pull this product from */  
                     /* End figure out which Locations in the warehouse to pull this product from */  
                    
                     SELECT @c_FromLOC = SPACE(10),    
                            @c_fromlot = SPACE(10),   
                            @c_fromid = SPACE(18),  
                            @n_FromQty = 0, @n_PossibleCases = 0,  
                            @n_remainingqty = @n_CurrentSeverity * @n_CurrentFullCase, -- by jeff, used to calculate qty required per LOT, rather than from SKUxLOC  
                            @n_remainingcases = @n_CurrentSeverity,  
                            @c_fromlot2 = SPACE(10),  
                            @b_DoneCheckOverAllocatedLots = 0,  
                            @n_SerialNo = 0  
  
                     CREATE TABLE #LOT (SerialNo   int IDENTITY(1,1),  
                                   Lot        NVARCHAR(10),   
                                   SortDate   NVARCHAR(20) NULL,  
                                   Qty        int  )   
                 
                     --(Wan02) - START  
                     CREATE TABLE #LOT2 (SerialNo  int IDENTITY(1,1),  
                                   Lot             NVARCHAR(10),   
                                   LocLevel        INT,  
                                   SortDate        NVARCHAR(20) NULL,  
                                   Qty             int  )   
                     --(Wan02) - END  
  
                     WHILE (1=1)  -- while 5  
                     BEGIN  
                        SELECT @c_PickCode = PickCode  
                        FROM  SKU WITH (NOLOCK)  
                        WHERE StorerKey = @c_CurrentStorer  
                        AND   SKU = @c_CurrentSKU  
  
                        /* See if there are any lots where the QTY is overalLOCated... */  
                        /* if Yes then uses this lot first... */  
                        -- That means that the last try at this section of code was successful therefore try again.  
                        IF @b_DoneCheckOverAllocatedLots = 0  
                        BEGIN  
                           SET ROWCOUNT 1  
  
                           SELECT @c_fromlot2 = LOTxLOCxID.LOT   
                           FROM LOTxLOCxID WITH (NOLOCK), LOC WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK)  
                           WHERE LOTxLOCxID.LOT > @c_fromlot2 --or LOTxLOCxID.LOT < (@c_fromlot2))  
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer  
                           AND LOTxLOCxID.SKU = @c_CurrentSKU  
                           AND LOTxLOCxID.LOC = LOC.LOC  
                           AND LOC.LocationFlag <> 'DAMAGE'  
                           AND LOC.LocationFlag <> 'HOLD'  
                           AND  LOC.Status <> 'HOLD'  
                           AND ((LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) - LOTxLOCxID.qty) > 0 -- SOS 6217  
                           AND LOTxLOCxID.LOC = @c_CurrentLOC  
                           AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT  
                           AND LOTxLOCxID.STORERKEY = LOTATTRIBUTE.STORERKEY  
                           AND LOTxLOCxID.SKU = LOTATTRIBUTE.SKU  
                           AND LOC.Facility = @c_zone01  
                      
  
                           IF @@ROWCOUNT = 0  
                           BEGIN  
                              SELECT @b_DoneCheckOverAllocatedLots = 1  
                              SET ROWCOUNT 0  
                              IF @b_debug = 1  
                              BEGIN  
                                 Print 'Not Lot Found! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' @c_CurrentLOC: ' + dbo.fnc_RTrim(@c_CurrentLOC) + ' @c_fromlot2: ' + ISNULL(dbo.fnc_RTrim(@c_fromlot2), '')  
                              END  
                              SELECT @c_fromlot = SPACE(10)  
                           END  
                           ELSE  
                           BEGIN  
                              SELECT @c_fromlot = @c_fromlot2  
                           END  
                        END -- done checkoverallocatedlots = 0  
  
                        /* End see if there are any lots where the QTY is overalLOCated... */  
                        SET ROWCOUNT 0  
                        /* If there are not lots overallocated in the candidate Location, simply pull lots into the Location by lot # */  
                        IF @b_DoneCheckOverAllocatedLots = 1  
                        BEGIN  
                           /* SELECT any lot if no lot was over alLOCated */  
                           IF dbo.fnc_RTrim(@c_PickCode) IS NOT NULL AND dbo.fnc_RTrim(@c_PickCode) <> ''  
                           BEGIN  
                              INSERT INTO #LOT (Lot, SortDate, Qty)   
                             
                              EXEC(@c_PickCode + ' N''' + @c_CurrentStorer + ''','  
                                               + ' N''' + @c_CurrentSKU + ''','  
                                               + ' N''' + @c_CurrentLOC + ''','  
                                               + ' N''' + @c_zone01 + ''','  
                                               + ' N''' + @c_fromlot2 + '''' )  
                              IF @b_debug = 1  
                              BEGIN  
                                  print 'EXEC ' + @c_PickCode + ' N''' + dbo.fnc_RTrim(@c_CurrentStorer) + ''','  
                                               + ' N''' + dbo.fnc_RTrim(@c_CurrentSKU) + ''','  
                                               + ' N''' + dbo.fnc_RTrim(@c_CurrentLOC) + ''','  
                                               + ' N''' + dbo.fnc_RTrim(@c_zone01) + ''','  
                                               + ' N''' + dbo.fnc_RTrim(@c_fromlot2) + ''''  
                              END   
                           END  
                           ELSE   
                           BEGIN  
                              INSERT INTO #LOT (Lot, SortDate, Qty)  
                              SELECT DISTINCT LOTxLOCxID.LOT, LOTTABLE05, 0   
                              FROM LOTxLOCxID WITH (NOLOCK), LOC WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK), LOT WITH (NOLOCK)   
               WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer  
                              AND LOTxLOCxID.SKU = @c_CurrentSKU  
                              AND LOTxLOCxID.LOC = LOC.LOC  
                              AND LOC.LocationFlag <> 'DAMAGE'  
                              AND LOC.LocationFlag <> 'HOLD'  
                              AND LOC.Status <> 'HOLD'  
                              AND LOC.Facility = @c_zone01  
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC  
                              AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT  
                              AND LOT.LOT = LOTxLOCxID.LOT  
                              AND LOT.Status <> 'HOLD'   
                              AND LOTxLOCxID.LOT <> ISNULL(@c_fromlot2, '')  
                              AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0   
                              ORDER BY LOTxLOCxID.LOT  
  
                           END  
  
                           IF (SELECT COUNT(1) FROM #LOT) = 0  
                           BEGIN  
                              IF @b_debug = 1  
                                 print 'Not Lot Available! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' LOC:' + dbo.fnc_RTrim(@c_CurrentLOC)  
                              BREAK  
                           END  
                           ELSE  
                           BEGIN  
                              IF @b_debug = 1  
                              BEGIN  
                                 print '*** Lot picked from LOTxLOCxID : ' + dbo.fnc_RTrim(@c_fromlot)  
                              END  
                           END   
                           IF @b_debug = 1  
                           BEGIN  
                              print '*** Selected Lot: ' + dbo.fnc_RTrim(@c_fromlot)  
                           END  
  
                           --(Wan02) -- START  
                           IF @n_ReplByLocLevel = 1   
                           BEGIN  
                              INSERT INTO #Lot2 ( Lot, LocLevel, SortDate, Qty )  
                              SELECT #LOT.Lot  
                                    ,LOC.LocLevel  
                                    ,LOTATTRIBUTE.Lottable04  
                                    ,#LOT.Qty  
                              FROM   #LOT  
                              JOIN   LOTxLOCxID   WITH (NOLOCK) ON (#LOT.Lot = LOTxLOCxID.Lot)  
                              JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (#LOT.Lot = LOTATTRIBUTE.Lot)  
                              JOIN   LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)  
                              WHERE  LOC.LocationFlag <> 'DAMAGE'  
                              AND LOC.LocationFlag <> 'HOLD'  
                              AND LOC.Status       <> 'HOLD'  
                              AND LOC.Facility     = @c_zone01  
                              AND LOTxLOCxID.LOC   <> @c_CurrentLOC  
                              ORDER BY LOC.LocLevel  
                                     , LOTATTRIBUTE.Lottable04   
  
                           END  
  
                           SELECT @b_DoneCheckOverAllocatedLots = 2  
                        END -- IF @b_DoneCheckOverAllocatedLots = 1  
                        ELSE   
                        IF @b_DoneCheckOverAllocatedLots = 0  
                        BEGIN  
                           --(Wan02) -- START  
                           IF @n_ReplByLocLevel = 1   
                           BEGIN  
                              SET @n_LocLevel = 0  
                              SELECT TOP 1 @n_LocLevel = LOC.LocLevel  
                              FROM   LOTxLOCxID   WITH (NOLOCK)    
                              JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)  
                              JOIN   LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)  
                              WHERE  LOTxLOCxID.lot = @c_fromLot  
                              AND LOC.LocationFlag <> 'DAMAGE'  
             AND LOC.LocationFlag <> 'HOLD'  
                              AND LOC.Status       <> 'HOLD'  
                              AND LOC.Facility     = @c_zone01  
                              AND LOTxLOCxID.LOC   <> @c_CurrentLOC  
                              AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0   
                              ORDER BY LOC.LocLevel  
                                     , LOTATTRIBUTE.Lottable04   
                           END  
                           --(Wan02) --END  
  
                           SELECT @b_DoneCheckOverAllocatedLots = 1  
                        END   
  
                        IF @b_DoneCheckOverAllocatedLots = 2   
                        BEGIN  
                           SET ROWCOUNT 1  
                           --(Wan02) -- START  
                           SET @n_LocLevel = ''  
                           IF @n_ReplByLocLevel = 1   
                           BEGIN  
                              SELECT @c_FromLot  = LOT  
                                    ,@n_LocLevel = LocLevel  
                                    ,@n_SerialNo = SerialNo   
                              FROM   #LOT2  
                              WHERE  SerialNo > @n_SerialNo   
                           END  
                           ELSE  
                           BEGIN  
                           --(Wan02) -- END  
                              SELECT @c_FromLot = LOT,  
                                     @n_SerialNo = SerialNo   
                              FROM   #LOT  
                              WHERE  SerialNo > @n_SerialNo   
                           END   --(Wan02)  
  
                           IF @@ROWCOUNT = 0   
                           BEGIN  
                              SET ROWCOUNT 0   
                              IF @b_debug = 1  
                                 Print 'Not Lot Available! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' LOC:' + dbo.fnc_RTrim(@c_CurrentLOC)  
                              BREAK  
                           END  
                           ELSE  
                           BEGIN  
                              IF @b_debug = 1  
                              BEGIN  
                                 Print '*** Lot picked from LOTxLOCxID=' + dbo.fnc_RTrim(@c_fromlot)  
                              END  
                           END   
                           IF @b_debug = 1  
                           BEGIN  
                              Print 'SELECTed Lot =' + @c_fromlot  
                           END  
                           SET ROWCOUNT 0   
                        END  
  
                        SET @b_GetBulkLoc = 0                              --(Wan01)   
                        SELECT @c_FromLOC = SPACE(10)  
                        WHILE (1=1 AND @n_remainingqty > 0)  
                        BEGIN  
                           SET ROWCOUNT 1  
                           --(Wan01) - START  
                           IF @b_GetBulkLoc = 0  
                           BEGIN  
                              SELECT @c_FromLOC = LOTxLOCxID.LOC  
                              FROM LOTxLOCxID WITH (NOLOCK)  
                              JOIN LOC WITH (NOLOCK)  
                              ON (LOTxLOCxID.LOC = LOC.LOC)   
                              JOIN SKUxLOC WITH (NOLOCK)  
                              ON  (LOTxLOCxID.Storerkey = SKUxLOC.Storerkey)   
                              AND (LOTxLOCxID.Sku = SKUxLOC.Sku)   
                              AND (LOTxLOCxID.LOC = SKUxLOC.LOC)   
                              WHERE LOT = @c_fromlot  
                              AND LOTxLOCxID.LOC > @c_FromLOC  
                              AND LOTxLOCxID.StorerKey = @c_CurrentStorer  
                              AND LOTxLOCxID.SKU = @c_CurrentSKU  
                              AND LOTxLOCxID.LOC = LOC.LOC  
                              AND LOC.LocationFlag <> 'DAMAGE'  
                              AND LOC.LocationFlag <> 'HOLD'  
                AND LOC.Status <> 'HOLD'  
                              AND LOC.Facility = @c_zone01  
                              AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.QtyAllocated > 0  
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND  
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC  
                              AND SKUxLOC.LocationType = 'CASE'  
                              --(Wan02) - START  
                              AND LOC.LocLevel = CASE WHEN @n_ReplByLocLevel = 1 THEN @n_LocLevel ELSE LOC.LocLevel END  
                              --(Wan02) - END  
                              ORDER BY LOTxLOCxID.LOC  
  
                              IF @@ROWCOUNT = 0  
                              BEGIN  
                                 SET @b_GetBulkLoc = 1  
                                 SET @c_FromLOC = ''  
                              END  
                           END  
  
                           IF @b_GetBulkLoc = 1    
                           BEGIN  
                           --(Wan01) - END  
                              SELECT @c_FromLOC = LOTxLOCxID.LOC  
                              FROM LOTxLOCxID WITH (NOLOCK)  
                              JOIN LOC WITH (NOLOCK)                          --(Wan01)  
                              ON (LOTxLOCxID.LOC = LOC.LOC)                   --(Wan01)  
                              JOIN SKUxLOC WITH (NOLOCK)                      --(Wan01)  
                              ON  (LOTxLOCxID.Storerkey = SKUxLOC.Storerkey)  --(Wan01)   
                              AND (LOTxLOCxID.Sku = SKUxLOC.Sku)              --(Wan01)  
                              AND (LOTxLOCxID.LOC = SKUxLOC.LOC)              --(Wan01)  
                              WHERE LOT = @c_fromlot  
                              AND LOTxLOCxID.LOC > @c_FromLOC  
                              AND LOTxLOCxID.StorerKey = @c_CurrentStorer  
                              AND LOTxLOCxID.SKU = @c_CurrentSKU  
                              AND LOTxLOCxID.LOC = LOC.LOC  
                              AND LOC.LocationFlag <> 'DAMAGE'  
                              AND LOC.LocationFlag <> 'HOLD'  
                              AND LOC.Status <> 'HOLD'  
                              AND LOC.Facility = @c_zone01  
                              AND LOTxLOCxID.qty - LOTxLOCxID.qtypicked - LOTxLOCxID.QtyAllocated > 0  
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND  
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC  
                              AND SKUxLOC.LocationType <> 'CASE'              --(Wan01)  
                              --(Wan02) - START  
                              --(Wan02) - START  
                              AND LOC.LocLevel = CASE WHEN @n_ReplByLocLevel = 1 THEN @n_LocLevel ELSE LOC.LocLevel END  
                              --(Wan02) - END  
                              ORDER BY LOTxLOCxID.LOC  
  
                              IF @@ROWCOUNT = 0  
                              BEGIN  
                                 SET ROWCOUNT 0  
                                 IF @b_debug = 1  
                                 BEGIN  
                                    Print 'No LOC Selected!'  
                                 END  
                                 BREAK  
                              END  
                           END                                                --(Wan01)  
  
                           SET ROWCOUNT 0  
                           IF @b_debug = 1  
                           BEGIN  
                              Print 'Location Selected = ' + @c_FromLOC  
                           END  
  
                           SELECT @c_fromid = replicate('Z',18)  
                           WHILE (1=1 AND @n_remainingqty > 0)  
                BEGIN  
                              SET ROWCOUNT 1  
                              SELECT @c_fromid = ID,  
                              @n_OnHandQty = LOTxLOCxID.QTY - QTYPICKED - QtyAllocated  
                              FROM LOTxLOCxID WITH (NOLOCK), LOC WITH (NOLOCK)  
                              WHERE LOT = @c_fromlot  
                              AND LOTxLOCxID.LOC = LOC.LOC  
                              AND LOTxLOCxID.LOC = @c_FromLOC  
                              AND id < @c_fromid  
                              AND StorerKey = @c_CurrentStorer  
                              AND SKU = @c_CurrentSKU  
                              AND LOC.LocationFlag <> 'DAMAGE'  
                              AND LOC.LocationFlag <> 'HOLD'  
                              AND LOC.Status <> 'HOLD'  
                              AND LOC.Facility = @c_zone01  
                              AND LOTxLOCxID.qty - qtypicked - QtyAllocated > 0  
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND  
                              AND LOTxLOCxID.LOC <> @c_CurrentLOC  
                              ORDER BY ID DESC  
                              IF @@ROWCOUNT = 0  
                              BEGIN  
                                 IF @b_debug = 1  
                                 BEGIN  
                                    Print 'Stop because No Pallet Found! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_FromLOC  
                                    + ' From ID = ' + @c_fromid  
                                 END  
                                 SET ROWCOUNT 0  
                                 BREAK  
                              END  
                              SET ROWCOUNT 0  
                              IF @b_debug = 1  
                              BEGIN  
                                 Print 'ID SELECTed:'+ @c_fromid + ' Onhandqty:' + cast(@n_onhandqty as NVARCHAR(10))  
                              END  
                              /* We have a candidate FROM record */  
                              /* Verify that the cANDidate ID is not on HOLD */  
                              /* We could have done this in the SQL statements above */  
                              /* But that would have meant a 5-way join.             */  
                              /* SQL SERVER seems to work best on a maximum of a     */  
                              /* 4-way join.                                        */  
                              IF EXISTS(SELECT 1 FROM ID WITH (NOLOCK) WHERE ID = @c_fromid  
                              AND STATUS = 'HOLD')  
                              BEGIN  
                                 IF @b_debug = 1  
                                 BEGIN  
                                    Print 'Stop because Location Status = HOLD! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU + ' ID = ' + @c_fromid  
                                 END  
                                 BREAK -- Get out of loop, so that next cANDidate can be evaluated  
                              END  
                              /* Verify that the from Location is not overalLOCated in SKUxLOC */  
                              IF EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)  
                              WHERE StorerKey = @c_CurrentStorer  
                              AND SKU = @c_CurrentSKU  
                              AND LOC = @c_FromLOC  
                              AND QTYEXPECTED > 0  
                              )  
                              BEGIN  
                                 IF @b_debug = 1  
                                 BEGIN  
                                    Print 'Stop because Qty Expected > 0! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU  
                                 END  
                                 BREAK -- Get out of loop, so that next cANDidate can be evaluated  
                              END  
                              IF @b_GetBulkLoc = 0  -- Get From CASE Location  
                              BEGIN  
                                 IF EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)  
                                 WHERE StorerKey = @c_CurrentStorer  
                                 AND SKU = @c_CurrentSKU  
                                 AND LOC = @c_CurrentLOC  
                                 AND LocationType = 'CASE'  
                                 )  
                                 BEGIN  
                                    IF @b_debug = 1  
                                    BEGIN  
                                       Print 'Stop because From Loc and To Loc''s Location Type = CASE! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU  
                                    END  
                                    BREAK -- Get out of loop, so that next cANDidate can be evaluated  
                                 END  
                              END  
                              ELSE  
                              BEGIN  -- Get From BULK/PIECE Location  
                                 /* Verify that the FROM Location is not the */  
                                 /* PIECE PICK Location for this product.    */  
                                 IF EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)  
                                 WHERE StorerKey = @c_CurrentStorer  
                                 AND SKU = @c_CurrentSKU  
                                 AND LOC = @c_FromLOC  
                                 AND LocationType = 'PICK'  
                                 )  
                                 BEGIN  
                                    IF @b_debug = 1  
                                    BEGIN  
                                       Print 'Stop because Location Type = PICK! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU  
                                    END  
                                    BREAK -- Get out of loop, so that next cANDidate can be evaluated  
                                 END  
                                 /* Verify that the FROM Location is not the */  
                                 /* CASE PICK Location for this product.     */  
                                 IF EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)  
                                 WHERE StorerKey = @c_CurrentStorer  
                                 AND SKU = @c_CurrentSKU  
                                 AND LOC = @c_FromLOC  
                                 AND LocationType = 'CASE'  
                                 )  
                                 BEGIN  
                                    IF @b_debug = 1  
                                    BEGIN  
                                       Print 'Stop because Location Type = CASE! LOC = ' + @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU  
                                    END  
                                    BREAK -- Get out of loop, so that next cANDidate can be evaluated  
                                 END  
                              END  
                              /* At this point, get the available qty from  */  
                              /* the SKUxLOC record.                        */  
                              /* If it's less than what was taken from the  */  
                              /* LOTxLOCxID record, then use it.            */  
                              /* How many cases can I get from this record? */  
                              SELECT @n_PossibleCases = floor(@n_OnHandQty / @n_CurrentFullCase)  
  
                              IF @b_debug = 1  
                              BEGIN  
                                 Print '@n_OnHandQty  = ' + cast(@n_OnHandQty as NVARCHAR(10))  + ' @n_RemainingQty  =' + cast(@n_RemainingQty as NVARCHAR(10))  
                                 Print '@n_possiblecases =' + cast(@n_possiblecases as NVARCHAR(10)) + ' @n_currentFullCase = ' + cast(@n_currentFullCase as NVARCHAR(10))  
                              END  
                              /* How many do we take? */  
                              IF @n_OnHandQty > @n_RemainingQty  
                              BEGIN  
                                 -- Modify by SHONG for full carton only  
                                 SELECT @n_FromQty = @n_RemainingQty  
                                 SELECT @n_RemainingQty = 0  
                                 /* -- minus off the qtyexpected for a lot (in to loc)  
                                 SELECT @n_qtytaken = QtyExpected  
                                 FROM LOTxLOCxID (NOLOCK)  
                                 WHERE Storerkey = @c_currentstorer  
                                 AND SKU = @c_CurrentSKU  
                                 AND LOC = @c_CurrentLOC  
                                 AND LOT = @c_fromlot  
                                 SELECT @n_remainingQty = @n_remainingQty - @n_qtytaken  
                                 */  
                              END  
                              ELSE  
                              BEGIN  
                                 -- Modify by shong for full carton only  
  
                                 IF @n_OnHandQty > @n_CurrentFullCase  
                                 BEGIN   
                                    SELECT @n_FromQty = (@n_PossibleCases * @n_CurrentFullCase)  
                                 END  
                                 ELSE  
                                 BEGIN  
                                    SELECT @n_FromQty = @n_OnHandQty  
                                 END  
                                 SELECT @n_remainingqty = @n_remainingqty - @n_FromQty  
                               
                                 IF @b_debug = 1  
                                 BEGIN  
                                    print 'Checking possible cases AND current full case available - @n_RemainingQty > @n_FromQty'  
                                    Print '@n_possiblecases:' + cast(@n_possiblecases as NVARCHAR(10)) + ' @n_currentFullCase:' + cast(@n_currentFullCase as NVARCHAR(10)) + '@n_FromQty:' + cast(@n_FromQty as NVARCHAR(10))  
                                 END  
                              END  
                              /*  
                              IF @n_FromQty = 0  
                              BEGIN  
                                 SELECT @n_FromQty =   
                                 LOTxLOCxID.QTY - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYEXPECTED  
                                 FROM LOTxLOCxID (NOLOCK)  
                                 WHERE LOTxLOCxID.LOC = @c_FromLOC  
                                 AND LOTxLOCxID.LOT = @c_fromlot  
                                 AND LOTxLOCxID.SKU =@c_CurrentSKU  
                                 AND LOTxLOCxID.STORERKEY = @c_currentstorer  
                              END  
                              */  
  
                              IF @n_FromQty > 0  
                              BEGIN  
                                 SELECT @c_Packkey = PACK.PackKey,  
                                        @c_UOM = PACK.PackUOM3  
                                 FROM   SKU WITH (NOLOCK), PACK WITH (NOLOCK)  
                                 WHERE  SKU.PackKey = PACK.Packkey  
                                 AND    SKU.StorerKey = @c_CurrentStorer  
                                 AND    SKU.SKU = @c_CurrentSKU  
  
                                 -- print 'before insert into replenishment'  
                                 -- SELECT @n_fromqty 'fromqty', @n_possiblecases 'possiblecases', @n_remainingqty 'remainingqty'  
                                 IF @n_continue = 1 or @n_continue = 2  
                                 BEGIN  
                                    INSERT #REPLENISHMENT (  
                                       StorerKey,  
                                       SKU,  
                              FromLOC,  
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
                                       @c_CurrentSKU,  
                                       @c_FromLOC,  
                                       @c_CurrentLOC,  
                                       @c_fromlot,  
                                       @c_fromid,  
                                       @n_FromQty,  
                                       @c_UOM,  
                                       @c_Packkey,  
                                       @c_CurrentPriority,  
                                       0,0)  
                                 END  
                                 SELECT @n_numberofrecs = @n_numberofrecs + 1  
                              END -- if from qty > 0  
  
                              IF @b_debug = 1  
                              BEGIN  
                                 SELECT @c_CurrentSKU ' SKU', @c_CurrentLOC 'LOC', @c_CurrentPriority 'priority', @n_CurrentFullCase 'full case', @n_CurrentSeverity 'severity'  
                                 -- SELECT @n_FromQty 'qty', @c_FromLOC 'fromLOC', @c_fromlot 'from lot', @n_PossibleCases 'possible cases'  
                                 SELECT @n_remainingqty '@n_remainingqty', @c_CurrentLOC + ' SKU = ' + @c_CurrentSKU, @c_fromlot 'from lot', @c_fromid  
                              END  
                              IF @c_fromid = '' OR @c_fromid IS NULL OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromId)) = ''  
                              BEGIN  
                                 -- SELECT @n_remainingqty=0  
                                 BREAK  
                              END  
                           END -- SCAN LOT for ID  
                           SET ROWCOUNT 0  
                           --IF @b_GetBulkLoc = 0   
                           --BEGIN  
                           --   SET @c_FromLoc = ''  
                           --   SET @b_GetBulkLoc = 1  
                           --END  
                        END -- SCAN LOT for LOC  
                        SET ROWCOUNT 0  
                     END -- SCAN LOT FOR LOT  
                     DROP TABLE #LOT  
                     DROP TABLE #LOT2                             --(Wan02)  
                     SET ROWCOUNT 0  
                  END -- FOR SKU  
                  SET ROWCOUNT 0  
               END -- FOR STORER  
               SET ROWCOUNT 0  
            END -- FOR SEVERITY  
            SET ROWCOUNT 0  
         END  -- (WHILE 1=1 on SKUxLOC FOR PRIORITY )  
         SET ROWCOUNT 0  
      END  
  
      IF @n_continue=1 OR @n_continue=2  
      BEGIN  
         /* Update the column QtyInPickLOC in the Replenishment Table */  
         IF @n_continue = 1 or @n_continue = 2  
         BEGIN  
            UPDATE #REPLENISHMENT SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked  
            FROM SKUxLOC WITH (NOLOCK)  
            WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey AND  
            #REPLENISHMENT.SKU = SKUxLOC.SKU AND  
            #REPLENISHMENT.toLOC = SKUxLOC.LOC  
         END  
      END  
  
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  
     
        
      IF @n_continue=1 OR @n_continue=2  
      BEGIN   
         SET @n_Rowcnt = 0  
         SELECT    @n_Rowcnt = Count(1)  
         FROM   #REPLENISHMENT R  
        
         IF ISNULL(@n_Rowcnt, 0) > 0  
         BEGIN  
               -- Get Key by BATCH  
            DECLARE @b_success int,  
            @n_err     int,  
            @c_errmsg  NVARCHAR(255)     
           
            BEGIN TRAN  
                    
            EXECUTE nspg_GetKey  
            'REPLENISHKEY',  
            10,  
            @c_ReplenishmentKey OUTPUT,  
            @b_success OUTPUT,  
            @n_err OUTPUT,  
            @c_errmsg OUTPUT,  
            0,  
            @n_Rowcnt  
            IF NOT @b_success = 1  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63529   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to get REPLENISHKEY. (nsp_ReplenishmentRpt_BatchRefill_04)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            END      
            ELSE  
            BEGIN   
               COMMIT TRAN  
            END       
         END  
      END     
     
      IF @n_continue=1 OR @n_continue=2  
      BEGIN     
         /* Insert Into Replenishment Table Now */  
  
         SET @n_ReplenishmentKey = CAST(@c_ReplenishmentKey as INT)  
        
         BEGIN TRAN  
         DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT R.ROWREF  
         FROM   #REPLENISHMENT R  
         OPEN CUR1  
  
         FETCH NEXT FROM CUR1 INTO @n_ROWREF   
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
          
           SET @c_ReplenishmentKey = dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(CHAR(10),@n_ReplenishmentKey)))   
           SET @c_ReplenishmentKey = RIGHT(dbo.fnc_RTrim(Replicate('0',10) + @c_ReplenishmentKey),10)  
           
           INSERT INTO REPLENISHMENT   
            (replenishmentgroup,            ReplenishmentKey,            StorerKey,  
               Sku,            FromLoc,            ToLoc,  
               Lot,            Id,                 Qty,  
               UOM,            PackKey,            Confirmed)  
            SELECT 'IDS',      @c_ReplenishmentKey,       R.StorerKey,   
               R.Sku,          R.FromLoc,          R.ToLoc,  
               R.Lot,          R.Id,               R.Qty,   
               R.UOM,          R.PackKey,          'N'  
            FROM #REPLENISHMENT R (NOLOCK)  
            WHERE R.ROWREF = @n_ROWREF  
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63528   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert into  Replenishment table failed. (nsp_ReplenishmentRpt_BatchRefill_04)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            END  
           
            Set @n_ReplenishmentKey = @n_ReplenishmentKey + 1  
           
            FETCH NEXT FROM CUR1 INTO  @n_ROWREF  
         END -- While  
         CLOSE CUR1   
         DEALLOCATE CUR1  
             
         COMMIT TRAN  
      END     
  
      IF @n_continue=1 OR @n_continue=2  
      BEGIN   
         WHILE @@TRANCOUNT > 0  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      WHILE @@TRANCOUNT < @n_starttcnt  
      BEGIN  
         BEGIN TRAN  
      END  
                             
      -- End Insert Replenishment  
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_ReplenishmentRpt_Alloc'  
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
         -- RETURN  
      END  
   END                                                               --(Wan03)  
   --(Wan03) - START  
   IF @c_FuncType = 'G'                                                
   BEGIN                                                               
      GOTO QUIT_SP  
   END                                                                
   --(Wan03) - END  
   IF ( @c_zone02 = 'ALL')  
   BEGIN  
      SELECT R.FromLoc,   
               R.Id,   
               R.ToLoc,   
               R.Sku,   
               R.Qty,   
               R.StorerKey,   
               R.Lot,   
               R.PackKey,  
               SKU.Descr,   
               R.Priority,   
               L2.PutawayZone,   
               PACK.CASECNT,   
               PACK.PACKUOM1,   
               PACK.PACKUOM3,   
               R.ReplenishmentKey,   
               (LT.Qty - LT.QtyAllocated - LT.QtyPicked) As QtyAvailable,   
               LA.Lottable02,   
               LA.Lottable04  
      FROM  REPLENISHMENT R WITH (NOLOCK)  
      JOIN  SKU    WITH (NOLOCK) ON ( SKU.StorerKey = R.StorerKey )  
                                 AND( SKU.Sku = R.Sku )   
      JOIN  LOC L1 WITH (NOLOCK) ON ( L1.Loc = R.ToLoc )  
      JOIN  PACK   WITH (NOLOCK) ON ( SKU.PackKey = PACK.PackKey )  
      JOIN  LOC L2 WITH (nolock) ON ( L2.Loc = R.FromLoc )   
      JOIN  LOTxLOCxID LT WITH (nolock) ON ( LT.Lot = R.Lot )  
                                          AND( LT.Loc = R.FromLoc )  
                                          AND( LT.ID  = R.ID )  
      JOIN  LOTATTRIBUTE LA WITH (NOLOCK) ON (LT.LOT = LA.LOT)  
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  ( CL.ListName = 'REPORTCFG' )             --(Wan02)  
                                          AND ( CL.StorerKey = LT.Storerkey )           --(Wan02)  
                                          AND ( CL.Long = 'r_replenishment_report04' )  --(Wan02)  
                                          AND ( CL.Short <> 'N' OR CL.Short IS NULL)    --(Wan02)   
      WHERE R.confirmed = 'N'  
      AND  L1.Facility = @c_zone01  
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan03)  
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan03)  
      ORDER BY L1.PutawayZone  
            , CASE WHEN CL.CODE IS NULL THEN 999999 ELSE L2.LocLevel END                           --(Wan02)  
            , CASE WHEN CL.CODE IS NULL THEN CONVERT(DATETIME,'2199/01/01') ELSE LA.Lottable04 END --(Wan02)  
            , CASE WHEN CL.CODE IS NULL THEN L2.LogicalLocation ELSE ''   END                      --(Wan02)  
            , CASE WHEN CL.CODE IS NULL THEN R.FromLoc ELSE '' END                                 --(Wan02)  
            , R.SKU,  LA.Lottable02, LA.Lottable04  
   END  
   ELSE  
   BEGIN  
      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,  
      SKU.Descr, R.Priority, L2.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey,   
      (LT.Qty - LT.QtyAllocated - LT.QtyPicked) As QtyAvailable, LA.Lottable02, LA.Lottable04  
      FROM  REPLENISHMENT R WITH (NOLOCK)  
      JOIN SKU WITH (NOLOCK)    ON ( SKU.StorerKey = R.StorerKey )  
                                 AND( SKU.Sku = R.Sku )   
      JOIN LOC L1 WITH (NOLOCK) ON ( L1.Loc = R.ToLoc )  
      JOIN LOC L2 WITH (nolock) ON ( L2.Loc = R.FromLoc )  
      JOIN PACK WITH (NOLOCK)   ON ( SKU.PackKey = PACK.PackKey )  
      JOIN LOTxLOCxID LT WITH (nolock)  ON ( LT.Lot = R.Lot )  
                                          AND( LT.Loc = R.FromLoc )  
                                          AND( LT.ID  = R.ID )  
      JOIN LOTATTRIBUTE LA WITH (NOLOCK)  ON (LT.LOT = LA.LOT)  
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  ( CL.ListName = 'REPORTCFG' )             --(Wan02)  
                                          AND ( CL.StorerKey = LT.Storerkey )           --(Wan02)  
                                          AND ( CL.Long = 'r_replenishment_report04' )  --(Wan02)  
                                     AND ( CL.Short <> 'N' OR CL.Short IS NULL)    --(Wan02)   
      WHERE SKU.Sku = R.Sku  
      AND   SKU.StorerKey = R.StorerKey  
      AND   L1.Loc = R.ToLoc  
      AND   L2.Loc = R.FromLoc  
      AND   LT.Lot = R.Lot  
      AND   LT.Loc = R.FromLoc  
      AND   LT.ID = R.ID  
      AND   LT.LOT = LA.LOT  
      AND   LT.SKU = LA.SKU  
      AND   LT.STORERKEY = LA.STORERKEY  
      AND   SKU.PackKey = PACK.PackKey  
      AND   R.confirmed = 'N'  
      AND   L1.Facility = @c_zone01  
      AND   L1.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)  
      AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       --(Wan03)  
      AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  --(Wan03)  
      ORDER BY L1.PutawayZone  
      , CASE WHEN CL.CODE IS NULL THEN 999999 ELSE L2.LocLevel END                           --(Wan02)  
      , CASE WHEN CL.CODE IS NULL THEN CONVERT(DATETIME,'2199/01/01') ELSE LA.Lottable04 END --(Wan02)  
      , CASE WHEN CL.CODE IS NULL THEN L2.LogicalLocation ELSE ''   END                      --(Wan02)  
      , CASE WHEN CL.CODE IS NULL THEN R.FromLoc ELSE '' END                                 --(Wan02)  
      , R.SKU, LA.Lottable02, LA.Lottable04  
   END  
  
   QUIT_SP:                                                          --(Wan03)  
END  

GO