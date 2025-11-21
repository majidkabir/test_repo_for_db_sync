SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Stored Procedure: isp_ReplenishmentRpt_BatchRefill_20                   */  
/* Creation Date: 2020-07-23                                               */  
/* Copyright: LFL                                                          */  
/* Written by: WLChooi                                                     */  
/*                                                                         */  
/* Purpose: WMS-14125 - TH-Nespresso customize allocation/replenish for    */  
/*                      PTL pickface Order                                 */  
/*                                                                         */  
/* Called By: r_replenishment_report20                                     */  
/*                                                                         */  
/* GitLab Version: 1.3                                                     */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author   Ver   Purposes                                     */  
/* 02-Dec-2020 LZG      1.1   INC1369468 - Remove hardcoded SKU (ZG01)     */
/* 05-May-2021 WLChooi  1.2   WMS-16971 - Add TotalIDQty and modify sorting*/
/*                            (WL01)                                       */
/* 29-Jul-2022 WLChooi  1.3   DevOps Combine Script                        */
/* 29-Jul-2022 WLChooi  1.3   WMS-20329 Enhance REPLEXCLPRODNEAREXPIRY_DAY */
/*                            (WL02)                                       */
/***************************************************************************/  
  
CREATE PROC [dbo].[isp_ReplenishmentRpt_BatchRefill_20]
   @c_zone01      NVARCHAR(10),  
   @c_zone02      NVARCHAR(10),  
   @c_zone03      NVARCHAR(10),  
   @c_zone04      NVARCHAR(10),  
   @c_zone05      NVARCHAR(10),  
   @c_zone06      NVARCHAR(10),  
   @c_zone07      NVARCHAR(10),  
   @c_zone08      NVARCHAR(10),  
   @c_zone09      NVARCHAR(10),  
   @c_zone10      NVARCHAR(10),  
   @c_zone11      NVARCHAR(10),  
   @c_zone12      NVARCHAR(10),  
   @c_storerkey   NVARCHAR(15),  
   @c_ReplGrp     NVARCHAR(30) = 'ALL'  
,  @c_Functype    NCHAR(1) = ''         
AS   
   BEGIN  
      SET NOCOUNT ON   
      SET QUOTED_IDENTIFIER OFF   
      SET CONCAT_NULL_YIELDS_NULL OFF  
      DECLARE @n_continue INT          /* continuation flag   
 1=Continue  
 2=failed but continue processsing   
 3=failed do not continue processing   
 4=successful but skip furthur processing */,  
              @n_starttcnt INT   
   SELECT @n_starttcnt = @@TRANCOUNT  
   DECLARE @b_debug INT,  
           @c_Packkey NVARCHAR(10),  
           @c_UOM NVARCHAR(10),
           @n_qtytaken INT,  
           @n_Pallet INT,   
           @n_FullPackQty INT,  
           @c_LocationType NVARCHAR(10)  
  
   DECLARE @b_success INT,  
           @n_err INT,  
           @c_errmsg NVARCHAR(255),  
           @n_StartTranCnt INT  
                    
   SELECT @n_continue = 1,  
          @b_debug = 0,  
          @n_StartTranCnt = @@TRANCOUNT  
  
   IF ISNULL(@c_ReplGrp,'') = ''  
   BEGIN  
      SET @c_ReplGrp = 'ALL'  
   END     
  
   IF @c_ReplGrp NOT IN ('1','2','ALL')  
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @n_err = 63520  
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ReplenishmentGroup = ' + @c_ReplGrp + '. ' +   
                       'ReplenishmentGroup MUST = 1 OR 2 for PTL, ALL for non-PTL. (isp_ReplenishmentRpt_BatchRefill_20)'  
      GOTO QUIT_SP  
   END  
     
   IF @c_FuncType IN ( '','G' ) 
   BEGIN                           
      IF @c_ReplGrp = 'ALL'  
      BEGIN  
         EXEC dbo.isp_GenReplenishment  
            @c_zone01 = @c_zone01,  
            @c_zone02 = @c_zone02,   
            @c_zone03 = @c_zone03,  
            @c_zone04 = @c_zone04,  
            @c_zone05 = @c_zone05,  
            @c_zone06 = @c_zone06,  
            @c_zone07 = @c_zone07,  
            @c_zone08 = @c_zone08,  
            @c_zone09 = @c_zone09,  
            @c_zone10 = @c_zone10,  
            @c_zone11 = @c_zone11,  
            @c_zone12 = @c_zone12,  
            @c_ReplenFlag = 'WHC',  
            @c_storerkey  = @c_storerkey  
  
         GOTO RESULT  
      END  
  
      DECLARE @n_FullPackQtyPP      INT,  
              @c_Facility           NVARCHAR(5),  
              @n_Qty                INT,  
              @n_QtyLocationLimit   INT,  
              @n_QtyPicked          INT,  
              @n_QtyAllocated       INT,  
              @n_QtyLocationMinimum INT,  
              @n_CaseCnt            INT,  
              @n_ReplenQty          INT,  
              @c_PickCode           NVARCHAR(10),  
              @c_LogicalLocation    NVARCHAR(20),  
              @c_SortColumn         NVARCHAR(30),  
              @n_Cnt                INT,  
              @n_QtyAvailable       INT,  
              @c_priority           NVARCHAR(5),  
              @c_ReplenQtyFlag      NVARCHAR(1),  
              @c_ReplenishmentGroup NVARCHAR(10),  
              @c_ReplExclProdNearExpiry   NVARCHAR(10),   
              @n_NearExpiryDay      INT,   
              @c_ReplenFlag         NVARCHAR(10) = 'WHC'  
      
      SET @c_Facility = @c_Zone01  
      SET @c_ReplenQtyFlag = '0'  
      
      SET @c_ReplenishmentGroup = @c_ReplGrp  
        
      IF ISNUMERIC(@c_Zone12) = 1 AND @c_Zone12 <> ''  
      BEGIN  
         SELECT @b_debug = CAST(@c_Zone12 AS INT)  
      END  
  
      IF ISNULL(RTRIM(@c_storerkey),'') = ''   
      BEGIN  
         SELECT @c_storerkey = 'ALL'  
      END  
     
      CREATE TABLE #REPLENISHMENT  
      (  
         StorerKey    NVARCHAR(15),  
         SKU          NVARCHAR(20),  
         FromLOC      NVARCHAR(10),  
         ToLOC        NVARCHAR(10),  
         Lot          NVARCHAR(10),  
         Id           NVARCHAR(18),  
         Qty          INT,  
         QtyMoved     INT,  
         QtyInPickLOC INT,  
         Priority     NVARCHAR(10),  
         UOM          NVARCHAR(10),  
         PackKey      NVARCHAR(10)  
      )  
        
      CREATE TABLE #LOT_SORT  
      (  
         LOT        NVARCHAR(10),  
         SortColumn NVARCHAR(20)  
      )  
  
      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN  
         DECLARE @c_CurrentSKU                 NVARCHAR(20),  
                 @c_CurrentStorer              NVARCHAR(15),  
                 @c_CurrentLOC                 NVARCHAR(10),  
                 @c_CurrentPriority            NVARCHAR(5),  
                 @n_CurrentFullCase            INT,  
                 @n_CurrentSeverity            INT,  
                 @c_FromLOC                    NVARCHAR(10),  
                 @c_FromLot                    NVARCHAR(10),  
                 @c_FromId                     NVARCHAR(18),  
                 @n_FromQty                    INT,  
                 @n_RemainingQty               INT,  
                 @n_PossibleCases              INT,  
                 @n_remainingcases             INT,  
                 @n_OnHandQty                  INT,  
                 @n_fromcases                  INT,  
                 @c_ReplenishmentKey           NVARCHAR(10),  
                 @n_numberofrecs               INT,  
                 @n_limitrecs                  INT,  
                 @c_FromLot2                   NVARCHAR(10),  
                 @b_DoneCheckOverAllocatedLots INT,  
                 @n_SKULocAvailableQty         INT,  
                 @n_LotSKUQTY                  INT,  
                 @c_SQLStatement               NVARCHAR(4000),  
                 @c_SQLCondition               NVARCHAR(2000),  
                 @c_SQLStatement1              NVARCHAR(4000),  
                 @c_SQLStatement2              NVARCHAR(4000)  
           
         SELECT  @c_CurrentSKU      = SPACE(20),  
                 @c_CurrentStorer   = SPACE(15),  
                 @c_CurrentLOC      = SPACE(10),  
                 @c_CurrentPriority = SPACE(5),  
                 @n_CurrentFullCase = 0,  
                 @n_CurrentSeverity = 9999999,  
                 @n_FromQty         = 0,  
                 @n_RemainingQty    = 0,  
                 @n_PossibleCases   = 0,  
                 @n_remainingcases  = 0,  
                 @n_fromcases       = 0,  
                 @n_numberofrecs    = 0,  
                 @n_limitrecs       = 5,  
                 @n_LotSKUQTY       = 0,  
                 @c_SQLCondition    = '' --NJOW02  
           
         IF @c_Storerkey <> 'ALL'  
         BEGIN  
           SELECT @c_SQLCondition = @c_SQLCondition + ' AND SKUxLOC.StorerKey = ''' + RTRIM(@c_storerkey) + ''''  
         END  
           
         IF @c_Zone02 <> 'ALL'  
         BEGIN  
            SELECT @c_SQLCondition = @c_SQLCondition + ' AND LOC.PutawayZone IN ( '''+RTRIM(ISNULL(@c_Zone02,'')) +''',''' +   
                                                                                      RTRIM(ISNULL(@c_Zone03,'')) +''',''' +    
                                                                                      RTRIM(ISNULL(@c_Zone04,'')) +''',''' +    
                                                                                      RTRIM(ISNULL(@c_Zone05,'')) +''',''' +    
                                                                                      RTRIM(ISNULL(@c_Zone06,'')) +''',''' +    
                                                                                      RTRIM(ISNULL(@c_Zone07,'')) +''',''' +    
                                                                                      RTRIM(ISNULL(@c_Zone08,'')) +''',''' +    
                                                                                      RTRIM(ISNULL(@c_Zone09,'')) +''',''' +    
                                                                                      RTRIM(ISNULL(@c_Zone10,'')) +''',''' +    
                                                                                      RTRIM(ISNULL(@c_Zone11,'')) +''',''' +    
                                                                                      RTRIM(ISNULL(@c_Zone12,'')) +''')'          
         END  
  
         IF @c_ReplenishmentGroup = '1'  
         BEGIN  
            SELECT @c_SQLCondition = @c_SQLCondition + ' AND LOC.Putawayzone NOT LIKE ''PTLB2CZON%'' AND LOC.LocLevel = 1 '  
         END  
         ELSE IF @c_ReplenishmentGroup = '2'  
         BEGIN  
            SELECT @c_SQLCondition = @c_SQLCondition + ' AND LOC.Putawayzone LIKE ''PTLB2CZON%'''-- AND SKUXLOC.SKU = ''7711.40'' '  -- ZG01
         END  
                           
         SELECT @c_SQLStatement = 'DECLARE Cur_ReplenSkuLoc CURSOR FAST_FORWARD READ_ONLY FOR ' +  
                                  'SELECT SKUxLOC.ReplenishmentPriority, ' +  
                                  'SKUxLOC.StorerKey, '+  
                                  'SKUxLOC.SKU, ' +  
                                  'SKUxLOC.LOC, ' +  
                                  'SKUxLOC.Qty, ' +  
                                  'SKUxLOC.QtyPicked, ' +  
                                  'SKUxLOC.QtyAllocated, ' +  
                                  'SKUxLOC.QtyLocationLimit, ' +  
                                  'SKUxLOC.QtyLocationMinimum, ' +  
                                  'PACK.CaseCnt, ' +  
                                  'PACK.Pallet, ' +  
                                  'SKU.PickCode, ' +  
                                  'SKUxLOC.LocationType, ' +  
                                  'SC2.Svalue '  +   
                                  'FROM    SKUxLOC (NOLOCK) ' +  
                                  'JOIN    LOC WITH ( NOLOCK ) ON SKUxLOC.Loc = LOC.Loc ' +  
                                  'JOIN    SKU WITH ( NOLOCK ) ON SKU.StorerKey = SKUxLOC.StorerKey AND ' +  
                                  '                               SKU.SKU = SKUxLOC.SKU ' +  
                                  'JOIN    PACK WITH ( NOLOCK ) ON PACK.PackKey = SKU.PACKKey ' +  
                                  'LEFT JOIN V_STORERCONFIG2 SC2 ON SKUXLOC.Storerkey = SC2.Storerkey AND SC2.Configkey = ''REPLEXCLPRODNEAREXPIRY_DAY'' ' +   
                                  'WHERE   LOC.Facility = ''' + RTRIM(ISNULL(@c_Facility,'')) +''' ' +  
                                  'AND SKUxLOC.LocationType IN ( ''PICK'', ''CASE'' ) ' +  
                                  'AND LOC.LocationFlag NOT IN ( ''DAMAGE'', ''HOLD'' ) ' +  
                                  RTRIM(ISNULL(@c_SQLCondition,'')) + ' ' +  
                                  'ORDER BY SKUxLOC.ReplenishmentPriority, SKUxLOC.Loc '   
           
         EXEC(@c_SQLStatement)  
           
         OPEN Cur_ReplenSkuLoc  
         FETCH NEXT FROM cur_ReplenSkuLoc INTO @c_CurrentPriority, @c_CurrentStorer, @c_CurrentSKU, @c_CurrentLoc, @n_Qty,  
                                               @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit, @n_QtyLocationMinimum,  
                                               @n_CaseCnt, @n_Pallet, @c_PickCode, @c_LocationType, @c_ReplExclProdNearExpiry   
           
         WHILE @@FETCH_STATUS <> -1  
         BEGIN    
            SET @c_ReplenQtyFlag = '0'  
           
            IF EXISTS(SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK)   
                      WHERE TD.Status IN ( '0','3')   
                        AND TD.TaskType = 'DRP'   
                        AND TD.ToLoc = @c_CurrentLoc   
                        AND TD.Storerkey = @c_CurrentStorer    
                        AND TD.Sku       = @c_CurrentSKU)  
            BEGIN  
               IF @b_debug = 1  
               BEGIN  
                  PRINT 'Skip Replenishement, Work In Progress TM task found'  
                  PRINT '  SKU: ' + @c_CurrentSKU   
                  PRINT '  LOC: ' + @c_CurrentLOC   
               END  
                   
               GOTO GET_NEXT_RECORD   
            END  
                        
            IF EXISTS(SELECT 1 FROM REPLENISHMENT R WITH (NOLOCK)  
                      WHERE R.Storerkey = @c_CurrentStorer AND  
                            R.Sku = @c_CurrentSKU AND  
                            R.ToLoc = @c_CurrentLOC AND  
                            R.Confirmed = 'N')  
            BEGIN  
               IF @b_debug = 1  
               BEGIN  
                  PRINT 'Deleting Previous Replenishment Record'  
                  PRINT '  SKU: ' + @c_CurrentSKU   
                  PRINT '  LOC: ' + @c_CurrentLOC   
               END  
                 
               DELETE REPLENISHMENT  
               FROM REPLENISHMENT R  
               JOIN SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = R.Storerkey AND  
                                              SL.Sku = R.Sku AND SL.Loc = R.ToLoc  
               WHERE R.Storerkey = @c_CurrentStorer AND  
                     R.Sku = @c_CurrentSKU AND  
                     R.ToLoc = @c_CurrentLOC AND  
                     R.Confirmed = 'N' AND  
                     SL.LocationType = @c_LocationType AND  
                     R.ReplenishmentGroup NOT IN('DYNAMIC')  
            END           
           
            SET @n_ReplenQty = @n_QtyLocationLimit - ( @n_Qty - @n_QtyPicked )  
           
            SET @n_QtyAvailable = ( @n_Qty - @n_QtyPicked )  
              
            IF @c_ReplenFlag = 'W' OR @c_ReplenFlag = 'WHC' -- Wave Replen for Healthcare TH  
            BEGIN  
               IF @n_Qty - (@n_QtyPicked + @n_QtyAllocated) < 0   
               BEGIN  
                  SET @n_ReplenQty = @n_QtyLocationLimit + ( (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) * -1 )     
               END  
               ELSE  
               BEGIN  
                  SET @n_ReplenQty = @n_QtyLocationLimit - ( (@n_Qty - (@n_QtyPicked + @n_QtyAllocated)) )             
               END  
                       
               IF @n_ReplenQty < 0   
               BEGIN  
                  SET @c_ReplenQtyFlag = '1'  
                  IF @c_LocationType = 'PICK' and (@c_ReplenFlag IN ('WHC','PPHC','W','N'))  
                  BEGIN  
                     SET @n_ReplenQty = @n_QtyLocationLimit  
                  END  
                  ELSE   
                  BEGIN  
                     SET @n_ReplenQty = @n_Pallet  
                  END         
               END     
               SET @n_QtyAvailable = ( @n_QtyAvailable - @n_QtyAllocated )            
            END  
            ELSE IF @c_ReplenFlag = 'PP'   
            BEGIN  
               SET @n_ReplenQty = @n_ReplenQty + @n_QtyAllocated         
               SET @n_QtyAvailable = ( @n_QtyAvailable - @n_QtyAllocated )  
            END   
            ELSE IF @c_ReplenFlag = 'PPHC' -- For Healthcare TH  
            BEGIN  
               SET @n_ReplenQty = @n_ReplenQty + @n_QtyAllocated   
               SET @n_QtyAvailable = ( @n_QtyAvailable - @n_QtyAllocated )  
            END   

            IF @b_debug = 1  
            BEGIN  
               PRINT '**'  
               PRINT '   Storer :' + @c_CurrentStorer   
               PRINT '   SKU: ' + @c_CurrentSKU  
               PRINT '   Loc: ' +  @c_CurrentLoc   
               PRINT '   Qty Replen: ' + CONVERT(NVARCHAR(10), @n_ReplenQty)  
               PRINT '   Qty Available: ' + CONVERT(NVARCHAR(10), @n_QtyAvailable)   
               PRINT '   Qty Location Minimum: ' + CONVERT(NVARCHAR(10), @n_QtyLocationMinimum)  
               PRINT '   Replen Qty Flag : ' + @c_ReplenQtyFlag + ' '   
               PRINT '   Location Limit: ' + CONVERT(NVARCHAR(10), @n_QtyLocationLimit)  
               PRINT '   Case Qty: ' +  CONVERT(NVARCHAR(10), @n_CaseCnt)   
               PRINT '   Pallet Qty: ' + CONVERT(NVARCHAR(10), @n_Pallet)  
               PRINT '   Location Type: ' + @c_LocationType  
               PRINT ''  
            END  
           
            IF @n_QtyAvailable > @n_QtyLocationMinimum  
               GOTO GET_NEXT_RECORD  
                                  
            SET @n_RemainingQty = @n_ReplenQty  
              
            DELETE #LOT_SORT  
              
            IF @c_ReplenishmentGroup = '1'  
            BEGIN  
               INSERT INTO #LOT_SORT (  
             LOT, SortColumn  
            )  
               SELECT DISTINCT LOT, ''  
               FROM dbo.LOTxLOCxID LLL WITH (NOLOCK)  
               JOIN LOC (NOLOCK) ON LLL.LOC = LOC.LOC  
               WHERE LLL.StorerKey = @c_CurrentStorer  
               AND   LLL.SKU = @c_CurrentSKU  
               AND   LLL.LOC = @c_CurrentLOC  
               AND   LLL.Qty - QtyAllocated - QtyPicked < 0  
               AND   LOC.LocLevel > 1 AND Loc.Putawayzone NOT LIKE 'PICK2PLTZ%'  
            END  
            ELSE IF @c_ReplenishmentGroup = '2'  
            BEGIN  
               INSERT INTO #LOT_SORT (  
             LOT, SortColumn  
            )  
               SELECT DISTINCT LOT, ''  
               FROM dbo.LOTxLOCxID LLL WITH (NOLOCK)  
               JOIN LOC (NOLOCK) ON LLL.LOC = LOC.LOC  
               WHERE LLL.StorerKey = @c_CurrentStorer  
               AND   LLL.SKU = @c_CurrentSKU  
               AND   LLL.LOC = @c_CurrentLOC  
               AND   LLL.Qty - QtyAllocated - QtyPicked < 0  
               AND   LOC.LocLevel = 1 AND Loc.Putawayzone LIKE 'PICK2PLTZ%'  
            END  

            IF @b_debug = 1  
            BEGIN  
               PRINT '***'  
               PRINT '>>> Current LOC: ' + @c_CurrentLOC  
            END  

            IF @c_ReplenishmentGroup = '1'  
            BEGIN  
               INSERT INTO #LOT_SORT (LOT, SortColumn)  
               SELECT DISTINCT  
                      LOTxLOCxID.LOT,  
                      CASE WHEN LOTTABLE04 IS NULL THEN '00000000'  
                           ELSE CONVERT(CHAR(4), DATEPART(year, LOTTABLE04)) +  
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(month, LOTTABLE04)),2) +  
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(day, LOTTABLE04)),2)  
                      END +  
                      CASE WHEN LOTTABLE05 IS NULL THEN '00000000'  
                           ELSE CONVERT(NVARCHAR(4), DATEPART(year, LOTTABLE05)) +  
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(month, LOTTABLE05)),2) +  
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(day, LOTTABLE05)),2)  
                      END AS SortColumn  
               FROM   LOTxLOCxID WITH ( NOLOCK )  
               JOIN   LOC WITH ( NOLOCK ) ON LOTxLOCxID.LOC = LOC.LOC  
               JOIN   LOTATTRIBUTE WITH ( NOLOCK ) ON LOTxLOCxID.LOT = LOTATTRIBUTE.LOT  
               JOIN   dbo.LOT LOT WITH (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT  
               JOIN   dbo.ID ID WITH (NOLOCK) ON ID.ID = LOTxLOCxID.ID  
               JOIN   dbo.SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = LOTxLOCxID.StorerKey  
                                                  AND SL.SKU = LOTxLOCxID.SKU  
                                                  AND SL.LOC = LOTxLOCxID.LOC  
               WHERE  LOTxLOCxID.StorerKey = @c_CurrentStorer AND  
                      LOTxLOCxID.SKU = @c_CurrentSKU AND  
                      LOC.LocationFlag <> 'DAMAGE' AND  
                      LOC.LocationFlag <> 'HOLD' AND  
                      LOC.Facility = @c_Facility AND  
                      LOC.Status = 'OK' AND  
                      LOT.Status = 'OK' AND  
                      ID.Status = 'OK' AND  
                      LOC.Status <> 'HOLD' AND  
                      LOC.Locationtype NOT IN ('CASE','PICK') AND 
                      LOTxLOCxID.LOC <> @c_CurrentLOC AND  
                      (LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated) > 0 AND  
                      SL.Locationtype <> 'CASE' AND 
                      SL.Locationtype <> 'PICK' AND
                      NOT EXISTS(SELECT 1 FROM #LOT_SORT L WHERE L.LOT = LOTxLOCxID.LOT) AND  
                      LOC.LocLevel > 1 AND Loc.Putawayzone NOT LIKE 'PICK2PLTZ%'  
                      ORDER BY SortColumn  
            END  
            ELSE IF @c_ReplenishmentGroup = '2'  
            BEGIN  
               INSERT INTO #LOT_SORT (LOT, SortColumn)  
               SELECT DISTINCT  
                      LOTxLOCxID.LOT,  
                      CASE WHEN LOTTABLE04 IS NULL THEN '00000000'  
                           ELSE CONVERT(CHAR(4), DATEPART(year, LOTTABLE04)) +  
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(month, LOTTABLE04)),2) +  
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(day, LOTTABLE04)),2)  
                      END +  
                      CASE WHEN LOTTABLE05 IS NULL THEN '00000000'  
                           ELSE CONVERT(NVARCHAR(4), DATEPART(year, LOTTABLE05)) +  
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(month, LOTTABLE05)),2) +  
                                RIGHT('0' + CONVERT(NVARCHAR(2), DATEPART(day, LOTTABLE05)),2)  
                      END AS SortColumn  
               FROM   LOTxLOCxID WITH ( NOLOCK )  
               JOIN   LOC WITH ( NOLOCK ) ON LOTxLOCxID.LOC = LOC.LOC  
               JOIN   LOTATTRIBUTE WITH ( NOLOCK ) ON LOTxLOCxID.LOT = LOTATTRIBUTE.LOT  
               JOIN   dbo.LOT LOT WITH (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT  
               JOIN   dbo.ID ID WITH (NOLOCK) ON ID.ID = LOTxLOCxID.ID  
               JOIN   dbo.SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = LOTxLOCxID.StorerKey  
                                                  AND SL.SKU = LOTxLOCxID.SKU  
                                                  AND SL.LOC = LOTxLOCxID.LOC  
               WHERE  LOTxLOCxID.StorerKey = @c_CurrentStorer AND  
                      LOTxLOCxID.SKU = @c_CurrentSKU AND  
                      LOC.LocationFlag <> 'DAMAGE' AND  
                      LOC.LocationFlag <> 'HOLD' AND  
                      LOC.Facility = @c_Facility AND  
                      LOC.Status = 'OK' AND  
                      LOT.Status = 'OK' AND  
                      ID.Status = 'OK' AND  
                      LOC.Status <> 'HOLD' AND  
                      LOTxLOCxID.LOC <> @c_CurrentLOC AND  
                      (LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated) > 0 AND  
                      NOT EXISTS(SELECT 1 FROM #LOT_SORT L WHERE L.LOT = LOTxLOCxID.LOT) AND  
                      LOC.LocLevel = 1 AND Loc.Putawayzone LIKE 'PICK2PLTZ%'  
                      ORDER BY SortColumn  
            END  
 
         SET @n_NearExpiryDay = 0  
         IF ISNULL(@c_ReplExclProdNearExpiry,'0') <> '0' AND ISNUMERIC(@c_ReplExclProdNearExpiry) = 1  
         BEGIN  
            --WL02 S
            --SET @n_NearExpiryDay = CONVERT(INT, @c_ReplExclProdNearExpiry) * -1   
            --DELETE #LOT_SORT   
            --FROM #LOT_SORT   
            --JOIN LOTATTRIBUTE LA (NOLOCK) ON #LOT_SORT.Lot = LA.Lot  
            --WHERE ISNULL(#LOT_SORT.SortColumn,'') <> ''  --Exclude overallocation lot  
            --AND DATEADD(Day, @n_NearExpiryDay, LA.Lottable04) <= GETDATE()  
            
            SET @n_NearExpiryDay = CONVERT(INT, @c_ReplExclProdNearExpiry)

            DELETE #LOT_SORT   
            FROM #LOT_SORT   
            JOIN LOTATTRIBUTE LA (NOLOCK) ON #LOT_SORT.Lot = LA.Lot  
            WHERE ISNULL(#LOT_SORT.SortColumn,'') <> ''  --Exclude overallocation lot  
            AND DATEDIFF(d, GETDATE(), LA.Lottable04) <= @n_NearExpiryDay
            --WL02 E
         END  
           
            SELECT @n_Cnt = COUNT(1) FROM #LOT_SORT  
           
            IF @b_debug = 1   
            BEGIN  
               IF @n_Cnt = 0   
               BEGIN  
                  PRINT '**** No Stock Available'   
               END  
            END  
              
            IF @n_Cnt = 0  
               GOTO GET_NEXT_RECORD  
           
               DECLARE cur_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT DISTINCT LOT, SortColumn  
         FROM   #LOT_SORT  
         ORDER BY SortColumn  
              
         OPEN cur_LOT  
              
         FETCH NEXT FROM cur_LOT INTO @c_FromLot, @c_SortColumn  
              
         WHILE @@FETCH_STATUS <> -1 AND @n_RemainingQty > 0  
         BEGIN  
            IF @b_debug = 1  
            BEGIN  
               PRINT '****'  
               PRINT '>>> LOT : ' + @c_FromLOT  
            END  
            
            IF @c_ReplenishmentGroup = '1'  
            BEGIN  
               DECLARE CUR_LOTxLOCxID_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT   LLI.LOC,  
                        LLI.ID,  
                        (LLI.QTY - LLI.QTYPICKED - LLI.QTYALLOCATED) AS OnHandQty,  
                        LOC.LogicalLocation  
               FROM     dbo.LOTxLOCxID LLI (NOLOCK)  
               JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.Loc  
               JOIN dbo.ID ID WITH (NOLOCK) ON LLI.ID = ID.Id  
               JOIN dbo.SKUxLOC SL WITH (nolock) ON SL.StorerKey = LLI.StorerKey AND  
                                                    SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC  
               WHERE    LOT = @c_FromLot AND  
                        LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') AND  
                        LOC.Facility = @c_Facility AND  
                        LOC.Status = 'OK' AND  
                        ID.Status = 'OK' AND   
                        LOC.Locationtype NOT IN ('CASE','PICK') AND  
                        SL.Locationtype <> 'CASE' AND 
                        SL.Locationtype <> 'PICK' AND  
                        (LLI.QTY - LLI.QTYPICKED - LLI.QTYALLOCATED) > 0 AND  
                        LOC.PUTAWAYZONE = CASE WHEN @c_ReplenFlag = 'FP+PARM2' THEN @c_Zone02 ELSE LOC.PUTAWAYZONE END AND  
                        LOC.LocLevel > 1 AND Loc.Putawayzone NOT LIKE 'PICK2PLTZ%'  
               ORDER BY OnHandQty, LOC.LogicalLocation  
            END  
            ELSE IF @c_ReplenishmentGroup = '2'  
            BEGIN  
               DECLARE CUR_LOTxLOCxID_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT   LLI.LOC,  
                        LLI.ID,  
                        (LLI.QTY - LLI.QTYPICKED - LLI.QTYALLOCATED) AS OnHandQty,  
                        LOC.LogicalLocation  
               FROM     dbo.LOTxLOCxID LLI (NOLOCK)  
               JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.Loc  
               JOIN dbo.ID ID WITH (NOLOCK) ON LLI.ID = ID.Id  
               JOIN dbo.SKUxLOC SL WITH (nolock) ON SL.StorerKey = LLI.StorerKey AND  
                                                    SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC  
               WHERE    LOT = @c_FromLot AND  
                        LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') AND  
                        LOC.Facility = @c_Facility AND  
                        LOC.Status = 'OK' AND  
                        ID.Status = 'OK' AND   
                        (LLI.QTY - LLI.QTYPICKED - LLI.QTYALLOCATED) > 0 AND  
                        LOC.PUTAWAYZONE = CASE WHEN @c_ReplenFlag = 'FP+PARM2' THEN @c_Zone02 ELSE LOC.PUTAWAYZONE END AND  
                        LOC.LocLevel = 1 AND Loc.Putawayzone LIKE 'PICK2PLTZ%'  
               ORDER BY OnHandQty, LOC.LogicalLocation  
            END  
              
            OPEN CUR_LOTxLOCxID_REPLEN  
              
            FETCH NEXT FROM CUR_LOTxLOCxID_REPLEN INTO  
            @c_FromLoc, @c_FromID, @n_OnHandQty, @c_LogicalLocation  
              
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               -- **** Update OnHandQTY to avoid getting the same OnHandQTY when loop into 2nd Pick Location with same SKU *** --  
               SET @n_LotSKUQTY = 0  
               SELECT @n_LotSKUQTY = SUM(QTY)   
               From #Replenishment (NOLOCK)   
               Where Lot = @c_FromLot   
               AND FromLOC = @c_FromLoc   
               AND ID = @c_FromId   
               
               If @b_debug = 1  
               BEGIN  
                   PRINT '*****'  
                   SELECT 'Original Lot QTY: ' , @n_OnHandQty, 'Located Replen QTY: ' , @n_LotSKUQTY  
               END  
               
               SET @n_OnHandQty = @n_OnHandQty - ISNULL(@n_LotSKUQTY,0)  
               
               IF @n_OnHandQTy <= 0  
                  GOTO GET_NEXT_LOT  
                    
               IF @c_ReplenFlag IN ('FP+PARM') AND @n_OnHandQty  > @n_RemainingQty  
               BEGIN  
                  SET @n_RemainingQty  = 0  
                  BREAK  
               END                       
               
               IF @b_debug = 1  
               BEGIN  
                 SELECT   @c_FromLOC 'From Loc',  
                          @c_FromLot 'From lot',  
                          @c_FromId  'From ID',  
                          @n_OnHandQty '@n_OnHandQty'  
               END  
                 
               IF @n_CaseCnt IS NULL OR @n_CaseCnt = 0  
                  SET @n_CaseCnt = 1  
               
               IF @n_OnHandQty < @n_RemainingQty  
                  SET  @n_PossibleCases = FLOOR(@n_OnHandQty / @n_CaseCnt)  
               ELSE  
                  SET  @n_PossibleCases = CEILING(@n_RemainingQty / (@n_CaseCnt * 1.00) )  
                 
               If @b_debug = 1   
               BEGIN  
                  PRINT '>>>  On Hand Qty: ' + CONVERT(NVARCHAR(10), @n_OnHandQty)   
                  PRINT '     Case Cnt:' + CONVERT(NVARCHAR(10), @n_CaseCnt)  
                  PRINT '>>>  Remaining Qty: ' + CONVERT(NVARCHAR(10), @n_RemainingQty)   
                  PRINT '     Possible Cases: ' + CONVERT(NVARCHAR(10), @n_PossibleCases)  
               END  
               
               SELECT   @c_Packkey = PACK.PackKey,  
                        @c_UOM = PACK.PackUOM3  
               FROM     SKU (NOLOCK),  
                        PACK (NOLOCK)  
               WHERE    SKU.PackKey = PACK.Packkey AND  
                        SKU.StorerKey = @c_CurrentStorer AND  
                        SKU.SKU = @c_CurrentSKU  
               
               IF @c_LocationType = 'PICK'  
               BEGIN  
                  IF @c_ReplenFlag IN ('PPHC','WHC')  
                  BEGIN  
                     IF @c_ReplenQtyFlag = '1'  
                     BEGIN  
                        SET @n_FullPackQty = @n_QtyLocationLimit  
                     END  
                     ELSE  
                     BEGIN           
                         SET @n_FullPackQty = @n_OnHandQty  
                     END      
                  END  
                  ELSE IF @c_ReplenFlag IN ('W','N')  
                  BEGIN  
                     IF @n_QtyLocationLimit = 0 AND @n_CaseCnt > 1    
                     BEGIN  
                        SET @n_FullPackQty = @n_CaseCnt   
                     END  
                     ELSE  
                     BEGIN  
                        SET @n_FullPackQty = @n_OnHandQty
                     END  
                  END                  
                  ELSE  
                  BEGIN  
                      SET @n_FullPackQty = @n_OnHandQty  
                  END  
               END   
               ELSE --none pick  
               BEGIN  
                  SET @n_FullPackQty = @n_Pallet  
               END  
               
               ----------------------------------------------------------------------------------------------------  
               If @b_debug = 1   
               BEGIN  
                  PRINT '>>>  Full Pack Qty: ' + CONVERT(NVARCHAR(10), @n_FullPackQty)  
               END  
                                                                                                        
               IF ( @n_OnHandQty <= @n_FullPackQty ) AND  
                  ( @n_OnHandQty <= @n_RemainingQty )   
               BEGIN  
                  IF @c_LocationType = 'PICK' AND (@c_ReplenFlag = 'WHC' OR @c_ReplenFlag = 'PPHC')  
                  BEGIN  
                     SET @n_FromQty = @n_OnHandQty  
                  END  
                  ELSE  
                  BEGIN  
                     IF @n_PossibleCases > 0  
                        IF @c_ReplenFlag = 'WHC' OR @c_ReplenFlag = 'PPHC'   
                           SELECT @n_FromQty = @n_CaseCnt * @n_PossibleCases  
                        ELSE  
                           SELECT @n_FromQty = @n_OnHandQty  
                     ELSE  
                        IF @c_ReplenFlag = 'N' OR @c_ReplenFlag = 'W'  
                           SELECT @n_FromQty = @n_OnHandQty                
                        ELSE   
                           SELECT @n_FromQty = 0  
                  END  
              
                  SELECT   @n_RemainingQty = @n_RemainingQty - @n_FromQty  
               END  
               ELSE   
               BEGIN   
                  -- Case Pick Location   
                  -- Only Allow Full Pallet, if 90%, Let it go   
                  IF @c_LocationType = 'CASE'  
                  BEGIN   
                     IF @c_ReplenFlag = 'WHC' OR @c_ReplenFlag = 'PPHC'  
                     BEGIN  
                       IF  (@n_OnHandQty %  @n_CaseCnt) > 0  
                       BEGIN    
                          IF @n_OnHandQty < @n_CaseCnt  
                             SELECT  @n_FromQty = 0  
                          ELSE   
                             SELECT  @n_FromQty = @n_OnHandQty - ( @n_OnHandQty % @n_CaseCnt )    
                       END  
                       ELSE    
                       BEGIN  
                          SELECT  @n_FromQty = @n_OnHandQty  
                       END  
                     END  
                     ELSE  
                     BEGIN  
                       IF FLOOR(@n_OnHandQty / @n_CaseCnt) > 0  
                          SELECT  @n_FromQty = @n_OnHandQty  
                       ELSE    
                          SELECT  @n_FromQty = 0  
                     END      
                  END  
                  ELSE  
                  BEGIN  
                    IF ( @n_OnHandQty >= @n_FullPackQty )  
                       IF @c_ReplenFlag = 'PPHC' OR @c_ReplenFlag = 'WHC'  
                       BEGIN  
                          SET @n_FromQty = @n_RemainingQty  
                       END  
                    ELSE  
                    BEGIN  
                       SET @n_FromQty = @n_FullPackQty   
                    END  
                    ELSE  
                    BEGIN  
                      IF @c_ReplenFlag = 'PPHC' OR @c_ReplenFlag = 'WHC'  
                      BEGIN  
                         SET @n_FromQty = @n_RemainingQty  
                      END  
                      ELSE  
                      BEGIN  
                         SET @n_FromQty = 0   
                      END                   
                    END    
                  END  
                    
                  SELECT @n_RemainingQty = @n_RemainingQty - @n_FromQty                         
               END  
              
               IF @b_debug = 1  
               BEGIN  
                  PRINT 'Possible CASE: ' + CAST(@n_PossibleCases AS NVARCHAR(10))  
                  PRINT 'Qty To Take: ' + CAST(@n_FromQty AS NVARCHAR(10))  
               END  
                        
               IF @n_FromQty > 0  
               BEGIN  
                  IF @n_continue = 1 OR @n_continue = 2  
                  BEGIN  
                     INSERT   #REPLENISHMENT  
                              (  
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
                                QtyInPickLOC  
                              )  
                     VALUES   (  
                                @c_CurrentStorer,  
                                @c_CurrentSKU,  
                                @c_FromLOC,  
                                @c_CurrentLOC,  
                                @c_FromLot,  
                                @c_FromId,  
                                @n_FromQty,  
                                @c_UOM,  
                                @c_Packkey,  
                                @c_CurrentPriority,  
                                0,  
                                0 )  
                  END  
                  SELECT   @n_numberofrecs = @n_numberofrecs + 1  
               END -- if from qty > 0  
              
               IF @n_RemainingQty <= 0  
                  BREAK  
              
               -- If the remaining qty < 90% of the Case then Break  
               IF @c_LocationType = 'PICK' AND  
                  ( (@n_RemainingQty / (@n_CaseCnt * 1.00)) * 100 ) < 90  
               BEGIN  
                  SET @n_RemainingQty = 0  
                  BREAK  
               END  
              
               GET_NEXT_LOT:
               FETCH NEXT FROM CUR_LOTxLOCxID_REPLEN INTO  
                      @c_FromLoc, @c_FromID, @n_OnHandQty, @c_LogicalLocation  
                END -- while CUR_LOTxLOCxID_REPLEN  
                CLOSE CUR_LOTxLOCxID_REPLEN  
                DEALLOCATE CUR_LOTxLOCxID_REPLEN  
              
             IF @n_RemainingQty = 0  
                BREAK  
              
             FETCH NEXT FROM cur_LOT INTO @c_FromLot, @c_SortColumn  
         END --while cur_LOT  
         CLOSE cur_LOT  
         DEALLOCATE cur_LOT  
              
         GET_NEXT_RECORD:  
         FETCH NEXT FROM cur_ReplenSkuLoc INTO @c_CurrentPriority, @c_CurrentStorer, @c_CurrentSKU, @c_CurrentLoc, @n_Qty,  
                                               @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit, @n_QtyLocationMinimum,  
                                               @n_CaseCnt, @n_Pallet, @c_PickCode, @c_LocationType, @c_ReplExclProdNearExpiry            
      END -- while cur_replenskuloc  
      CLOSE Cur_ReplenSkuLoc  
      DEALLOCATE Cur_ReplenSkuLoc  
              
      IF @n_continue = 1 OR  
         @n_continue = 2  
      BEGIN  
         /* Update the column QtyInPickLOC in the Replenishment Table */  
         IF @n_continue = 1 OR  
            @n_continue = 2  
         BEGIN  
            UPDATE   #REPLENISHMENT  
            SET      QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked  
            FROM     SKUxLOC (NOLOCK)  
            WHERE    #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey AND  
                     #REPLENISHMENT.SKU = SKUxLOC.SKU AND  
                     #REPLENISHMENT.toLOC = SKUxLOC.LOC  
         END  
      END --continue end  
      /* Insert Into Replenishment Table Now */  
           
      DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY  
      FOR SELECT  R.FromLoc,  
                     R.Id,  
                     R.ToLoc,  
                     R.Sku,  
                     R.Qty,  
                     R.StorerKey,  
                     R.Lot,  
                     R.PackKey,  
                     R.Priority,  
                     R.UOM  
             FROM    #REPLENISHMENT R  
      OPEN CUR1  
      FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromId, @c_CurrentLoc,  
         @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey,  
         @c_Priority, @c_UOM  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         EXECUTE nspg_GetKey 'REPLENISHKEY', 10, @c_ReplenishmentKey OUTPUT,  
            @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT  
         IF NOT @b_success = 1  
            BEGIN  
               BREAK  
            END  
         IF @b_success = 1  
            BEGIN  
               INSERT   REPLENISHMENT  
                        (  
                          replenishmentgroup,  
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
                          Confirmed  
                        )  
               VALUES   (  
                          @c_ReplenishmentGroup,  
                          @c_ReplenishmentKey,  
                          @c_CurrentStorer,  
                          @c_CurrentSku,  
                          @c_FromLoc,  
                          @c_CurrentLoc,  
                          @c_FromLot,  
                          @c_FromId,  
                          @n_FromQty,  
                          @c_UOM,  
                          @c_PackKey,  
                          'N' )  
               SELECT   @n_err = @@ERROR  
               IF @n_err <> 0  
                  BEGIN  
                     SELECT   @n_continue = 3  
                     SELECT   @c_errmsg = CONVERT(CHAR(250), @n_err),  
                              @n_err = 63524   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT   @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) +  
                              ': Insert into live pickdetail table failed.  Preallocated QTY Needs to be Manually Adjusted! (nspOrderProcessing)' +  
                              ' ( ' + ' SQLSvr MESSAGE=' +  
                              LTrim(RTrim(@c_errmsg)) +  
                              ' ) '  
                  END  
            END -- IF @b_success = 1  
         FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromId, @c_CurrentLoc,  
            @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot,  
            @c_PackKey, @c_Priority, @c_UOM  
      END -- While CUR1  
      CLOSE CUR1  
      DEALLOCATE CUR1  
   END --Continue end  
   END                                                                 

RESULT:    
   IF @c_FuncType = 'G'                                                
   BEGIN                                                               
      GOTO QUIT_SP  
   END                                                                
  
   IF ( @c_zone02 = 'ALL' )   
   BEGIN    
      IF (@c_Storerkey = 'ALL' OR @c_Storerkey = '')  
      BEGIN  
         SELECT   R.FromLoc,  
                  R.Id,  
                  R.ToLoc,  
                  R.Sku,  
                  R.Qty,  
                  R.StorerKey,  
                  R.Lot,  
                  R.PackKey,  
                  SKU.Descr,  
                  R.Priority,  
                  L1.PutawayZone,  
                  PACK.CASECNT,  
                  PACK.PACKUOM1,  
                  PACK.PACKUOM3,  
                  R.ReplenishmentKey,  
                  ( LT.Qty - LT.QtyAllocated - LT.QtyPicked ),  
                  LA.Lottable02,  
                  LA.Lottable04,
                  (SELECT SUM(LLI.Qty) FROM LOTxLOCxID LLI (NOLOCK) WHERE R.LOT = LLI.LOT AND R.FromLOC = LLI.LOC AND R.SKU = LLI.SKU AND R.Storerkey = LLI.StorerKey) AS TotalIDQty   --WL01 
         FROM     REPLENISHMENT R WITH (NOLOCK),   
                  SKU (NOLOCK),  
                  LOC L1 ( NOLOCK ),  
                  PACK (NOLOCK),  
                  LOC L2 ( NOLOCK ),  
                  LOTxLOCxID LT ( NOLOCK ),  
                  LOTATTRIBUTE LA ( NOLOCK )
         WHERE    SKU.Sku = R.Sku AND  
                  SKU.StorerKey = R.StorerKey AND  
                  L1.Loc = R.ToLoc AND  
                  L2.Loc = R.FromLoc AND  
                  LT.Lot = R.Lot AND  
                  LT.Loc = R.FromLoc AND  
                  LT.ID = R.ID AND  
                  LT.LOT = LA.LOT AND  
                  LT.SKU = LA.SKU AND  
                  LT.STORERKEY = LA.STORERKEY AND  
                  SKU.PackKey = PACK.PackKey AND  
                  R.confirmed = 'N' AND  
                  L1.Facility = @c_zone01  
             AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')     
         ORDER BY --L1.PutawayZone,   --WL01    
                  R.Sku,   --WL01
                  LA.Lottable04,   --WL01
                  LA.Lottable02,   --WL01
                  R.FromLoc   --WL01
      END       
      ELSE  
      BEGIN  
         SELECT   R.FromLoc,  
                  R.Id,  
                  R.ToLoc,  
                  R.Sku,  
                  R.Qty,  
                  R.StorerKey,  
                  R.Lot,  
                  R.PackKey,  
                  SKU.Descr,  
                  R.Priority,  
                  L1.PutawayZone,  
                  PACK.CASECNT,  
                  PACK.PACKUOM1,  
                  PACK.PACKUOM3,  
                  R.ReplenishmentKey,  
                  ( LT.Qty - LT.QtyAllocated - LT.QtyPicked ),  
                  LA.Lottable02,  
                  LA.Lottable04,
                  (SELECT SUM(LLI.Qty) FROM LOTxLOCxID LLI (NOLOCK) WHERE R.LOT = LLI.LOT AND R.FromLOC = LLI.LOC AND R.SKU = LLI.SKU AND R.Storerkey = LLI.StorerKey) AS TotalIDQty   --WL01 
         FROM     REPLENISHMENT R WITH (NOLOCK),
                  SKU (NOLOCK),  
                  LOC L1 ( NOLOCK ),  
                  PACK (NOLOCK),  
                  LOC L2 ( NOLOCK ),  
                  LOTxLOCxID LT ( NOLOCK ),  
                  LOTATTRIBUTE LA ( NOLOCK )
         WHERE    SKU.Sku = R.Sku AND  
                  SKU.StorerKey = R.StorerKey AND  
                  L1.Loc = R.ToLoc AND  
                  L2.Loc = R.FromLoc AND  
                  LT.Lot = R.Lot AND  
                  LT.Loc = R.FromLoc AND  
                  LT.ID = R.ID AND  
                  LT.LOT = LA.LOT AND  
                  LT.SKU = LA.SKU AND  
             LT.STORERKEY = LA.STORERKEY AND  
                  SKU.PackKey = PACK.PackKey AND  
                  R.confirmed = 'N' AND  
                  L1.Facility = @c_zone01 AND   
                  LT.STorerkey = @c_storerkey  
             AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')     
         ORDER BY --L1.PutawayZone,   --WL01   
                  R.Sku,   --WL01
                  LA.Lottable04,   --WL01
                  LA.Lottable02,   --WL01
                  R.FromLoc   --WL01
      END          
   END  
   ELSE   
   BEGIN  
      IF (@c_Storerkey = 'ALL' OR @c_Storerkey = '')  
      BEGIN  
         SELECT   R.FromLoc,  
                  R.Id,  
                  R.ToLoc,  
                  R.Sku,  
                  R.Qty,  
                  R.StorerKey,  
                  R.Lot,  
                  R.PackKey,  
                  SKU.Descr,  
                  R.Priority,  
                  L1.PutawayZone,  
                  PACK.CASECNT,  
                  PACK.PACKUOM1,  
                  PACK.PACKUOM3,  
                  R.ReplenishmentKey,  
                  ( LT.Qty - LT.QtyAllocated - LT.QtyPicked ),  
                  LA.Lottable02,  
                  LA.Lottable04,
                  (SELECT SUM(LLI.Qty) FROM LOTxLOCxID LLI (NOLOCK) WHERE R.LOT = LLI.LOT AND R.FromLOC = LLI.LOC AND R.SKU = LLI.SKU AND R.Storerkey = LLI.StorerKey) AS TotalIDQty   --WL01 
         FROM     REPLENISHMENT R WITH (NOLOCK), 
                  SKU (NOLOCK),  
                  LOC L1 ( NOLOCK ),  
                  LOC L2 ( NOLOCK ),  
                  PACK (NOLOCK),  
                  LOTxLOCxID LT ( NOLOCK ),  
                  LOTATTRIBUTE LA ( NOLOCK ) 
         WHERE    SKU.Sku = R.Sku AND  
                  SKU.StorerKey = R.StorerKey AND  
                  L1.Loc = R.ToLoc AND  
                  L2.Loc = R.FromLoc AND  
                  LT.Lot = R.Lot AND  
                  LT.Loc = R.FromLoc AND  
                  LT.ID = R.ID AND  
                  LT.LOT = LA.LOT AND  
                  LT.SKU = LA.SKU AND  
                  LT.STORERKEY = LA.STORERKEY AND  
                  SKU.PackKey = PACK.PackKey AND  
                  R.confirmed = 'N' AND  
                  L1.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,  
                                       @c_zone05, @c_zone06, @c_zone07,  
                                       @c_zone08, @c_zone09, @c_zone10,  
                                       @c_zone11, @c_zone12 ) AND  
                  L1.Facility = @c_zone01   
             AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')     
         ORDER BY --L1.PutawayZone,   --WL01   
                  R.Sku,   --WL01
                  LA.Lottable04,   --WL01
                  LA.Lottable02,   --WL01
                  R.FromLoc   --WL01
      END           
      ELSE  
      BEGIN  
         SELECT   R.FromLoc,  
                  R.Id,  
                  R.ToLoc,  
                  R.Sku,  
                  R.Qty,  
                  R.StorerKey,  
                  R.Lot,  
                  R.PackKey,  
                  SKU.Descr,  
                  R.Priority,  
                  L1.PutawayZone,  
                  PACK.CASECNT,  
                  PACK.PACKUOM1,  
                  PACK.PACKUOM3,  
                  R.ReplenishmentKey,  
                  ( LT.Qty - LT.QtyAllocated - LT.QtyPicked ),  
                  LA.Lottable02,  
                  LA.Lottable04,
                  (SELECT SUM(LLI.Qty) FROM LOTxLOCxID LLI (NOLOCK) WHERE R.LOT = LLI.LOT AND R.FromLOC = LLI.LOC AND R.SKU = LLI.SKU AND R.Storerkey = LLI.StorerKey) AS TotalIDQty   --WL01 
         FROM     REPLENISHMENT R WITH (NOLOCK), 
                  SKU (NOLOCK),  
                  LOC L1 ( NOLOCK ),  
                  LOC L2 ( NOLOCK ),  
                  PACK (NOLOCK),  
                  LOTxLOCxID LT ( NOLOCK ),  
                  LOTATTRIBUTE LA ( NOLOCK )
         WHERE    SKU.Sku = R.Sku AND  
                  SKU.StorerKey = R.StorerKey AND  
                  L1.Loc = R.ToLoc AND  
                  L2.Loc = R.FromLoc AND  
                  LT.Lot = R.Lot AND  
                  LT.Loc = R.FromLoc AND  
                  LT.ID = R.ID AND  
                  LT.LOT = LA.LOT AND  
                  LT.SKU = LA.SKU AND  
                  LT.STORERKEY = LA.STORERKEY AND  
                  SKU.PackKey = PACK.PackKey AND  
                  R.confirmed = 'N' AND  
                  L1.putawayzone IN ( @c_zone02, @c_zone03, @c_zone04,  
                                      @c_zone05, @c_zone06, @c_zone07,  
                                      @c_zone08, @c_zone09, @c_zone10,  
                                      @c_zone11, @c_zone12 ) AND  
                  L1.Facility = @c_zone01  AND   
                  LT.STORERKEY = @c_storerkey  
             AND (R.Replenishmentgroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  
         ORDER BY --L1.PutawayZone,   --WL01  
                  R.Sku,   --WL01
                  LA.Lottable04,   --WL01
                  LA.Lottable02,   --WL01
                  R.FromLoc   --WL01
      END    
   END  
QUIT_SP:                                                    
   IF @n_continue=3 -- Error Occured - Process And Return  
   BEGIN  
       SELECT @b_success = 0  
       IF @@TRANCOUNT=1  
          AND @@TRANCOUNT > @n_StartTranCnt  
       BEGIN  
           ROLLBACK TRAN  
       END  
       ELSE  
       BEGIN  
           WHILE @@TRANCOUNT>@n_StartTranCnt  
           BEGIN  
               COMMIT TRAN  
           END  
       END  
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ReplenishmentRpt_BatchRefill_20'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN  
   END  
   ELSE  
   BEGIN  
       SELECT @b_success = 1  
       WHILE @@TRANCOUNT > @n_StartTranCnt  
       BEGIN  
           COMMIT TRAN  
       END  
       RETURN  
   END  
END  

GO