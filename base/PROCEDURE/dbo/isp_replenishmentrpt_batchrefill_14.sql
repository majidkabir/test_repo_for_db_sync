SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_ReplenishmentRpt_BatchRefill_14                */  
/* Creation Date: 13-Jun-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: Replensihment Report - Over Allocate & Normal for IDSMY     */  
/*          Start Light (46210)                                         */  
/*          SOS#280047: StartLight                                      */  
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
/* Date         Author  Ver.  Purposes                                  */  
/* 29-Nov-2013  NJOW01  1.0   296409-Show all qty as EA if casecnt is   */  
/*                            not set in pack                           */  
/* 04-Aug-2014  Audrey  1.1   SOS317723 - Alias Name different   (ang01)*/
/* 05-MAR-2018 Wan01    1.2   WM - Add Functype                         */
/* 13-Mar-2019  TLTING  1.2   Missing nolock                            */
/************************************************************************/  
CREATE PROC  [dbo].[isp_ReplenishmentRpt_BatchRefill_14]  
               @c_Zone01      NVARCHAR(10)   -- Facility  
,              @c_Zone02      NVARCHAR(10)   -- All PutawayZone   
,              @c_Zone03      NVARCHAR(10)  
,              @c_Zone04      NVARCHAR(10)  
,              @c_Zone05      NVARCHAR(10)  
,              @c_Zone06      NVARCHAR(10)  
,              @c_Zone07      NVARCHAR(10)  
,              @c_Zone08      NVARCHAR(10)  
,              @c_Zone09      NVARCHAR(10)   --Sku  
,              @c_Zone10      NVARCHAR(10)   --Sku  
,              @c_Zone11      NVARCHAR(10)   --Aisle    
,              @c_Zone12      NVARCHAR(10)   --Aisle  
,              @c_storerkey   NVARCHAR(15)    
,              @c_ReplGrp     NVARCHAR(10)   
,              @c_Functype    NCHAR(1) = ''  --(Wan01)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue           INT          /* continuation flag  
                                                1=Continue  
                                                2=failed but continue processsing  
                                                3=failed do not continue processing  
                                                4=successful but skip furthur processing */  
         , @n_StartTCnt          INT  
         , @b_debug              INT   
         , @b_success            INT   
         , @n_err                INT   
         , @c_errmsg             NVARCHAR(255)    
           
         , @c_SQLStatement       NVARCHAR(MAX)  
         , @c_SQLConditions      NVARCHAR(MAX)  
  
   DECLARE @n_RowRef             INT   
         , @n_Row                INT  
         , @n_ReplenishmentKey   INT   
         , @c_ReplenishmentKey   NVARCHAR(10)   
         , @c_ReplenishmentGrp   NVARCHAR(10)  
           
   DECLARE @c_CurrentStorer      NVARCHAR(15)   
         , @c_CurrentSku         NVARCHAR(20)  
         , @c_CurrentLOC         NVARCHAR(10)   
         , @c_CurrentPriority    NVARCHAR(5)   
         , @c_FromLoc            NVARCHAR(10)     
         , @c_FromLot            NVARCHAR(10)   
         , @c_FromID             NVARCHAR(18)  
         , @c_Packkey            NVARCHAR(10)   
         , @c_UOM                NVARCHAR(10)  
         , @c_LocationType       NVARCHAR(10)  
  
  
         , @n_OnHandQty          INT  
         , @n_RemainingQty       INT    
         , @n_QtyToReplen        INT    
         , @n_FromQty            INT      
         , @n_Qty                INT  
         , @n_QtyAllocated       INT  
         , @n_QtyPicked          INT  
         , @n_QtyExpected        INT  
         , @n_QtyExpectedToTake  INT  
         , @n_QtyAvailable       INT   
         , @n_ReplenQty          INT  
         , @n_QtyLocationMinimum INT  
         , @n_QtyLocationLimit   INT  
         , @n_LotSKUQTY          INT  
         , @n_Casecnt            INT  
         , @n_Pallet             INT  
         , @n_FullPackQty        INT  
--         , @n_PossibleCases      INT   
  
         , @c_PickCode           NVARCHAR(10)  
         , @c_SortColumn         NVARCHAR(20)  
  
   SET @n_Continue         = 1  
   SET @n_StartTCnt        = @@TRANCOUNT   
   SET @b_debug            = 0  
   SET @b_success          = 1  
   SET @n_err              = 0  
   SET @c_errmsg           = ''  
  
   SET @c_SQLStatement     = ''  
   SET @c_SQLConditions    = ''  
  
   SET @n_RowRef           = 0  
   SET @n_Row              = 0  
   SET @n_ReplenishmentKey = 0  
   SET @c_ReplenishmentKey = ''  
   SET @c_ReplenishmentGrp = 'NORMAL'  
  
   SET @c_CurrentStorer    = ''  
   SET @c_CurrentSku       = ''   
   SET @c_CurrentLOC       = ''  
   SET @c_CurrentPriority  = ''  
   SET @c_FromLoc          = ''  
   SET @c_FromID           = ''  
   SET @c_Packkey          = ''  
   SET @c_UOM              = ''  
  
   SET @n_OnHandQty        = 0  
   SET @n_RemainingQty     = 0  
   SET @n_QtyToReplen      = 0  
   SET @n_FromQty          = 0  
   SET @n_Qty              = 0  
   SET @n_QtyAllocated     = 0  
   SET @n_QtyPicked        = 0  
   SET @n_QtyExpected      = 0  
   SET @n_QtyExpectedToTake= 0  
   SET @n_QtyAvailable     = 0  
   SET @n_ReplenQty        = 0  
   SET @n_QtyLocationMinimum= 0  
   SET @n_QtyLocationLimit = 0  
  
   SET @n_LotSKUQTY        = 0  
   SET @n_Casecnt          = 0  
   SET @n_Pallet           = 0  
   SET @n_FullPackQty      = 0  
   --SET @n_PossibleCases    = 0  
  
   SET @c_PickCode         = ''  
   SET @c_SortColumn       = ''  
  
   IF @c_Zone10 = ''  
      SET @c_Zone10 = 'ZZZZZZZZZZ'  
   IF @c_Zone12 = ''  
      SET @c_Zone12 = 'ZZZZZZZZZZ'  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
 
   IF @c_FuncType IN ( '','G' )                                      --(Wan01)
   BEGIN                                                             --(Wan01)    
      CREATE TABLE #REPLENISHMENT  
         (       
            RowRef            INT IDENTITY(1,1) NOT NULL PRIMARY KEY   
         ,  ReplenishmentGrp  NVARCHAR(10)   NOT NULL    DEFAULT ''   
         ,  StorerKey         NVARCHAR(20)   NOT NULL  
         ,  SKU               NVARCHAR(20)   NOT NULL  
         ,  FromLoc           NVARCHAR(10)   NOT NULL  
         ,  ToLoc             NVARCHAR(10)   NOT NULL  
         ,  LOT               NVARCHAR(10)   NOT NULL  
         ,  ID                NVARCHAR(18)   NOT NULL  
         ,  QTY               INT            NOT NULL  
         ,  QtyMoved          INT            NOT NULL  
         ,  QtyInPickLOC      INT            NOT NULL  
         ,  Priority          NVARCHAR(5)       
         ,  UOM               NVARCHAR(10)   NOT NULL  
         ,  Packkey           NVARCHAR(10)   NOT NULL   
            )  
  
      CREATE TABLE #LOT_SORT  
      (  
         Lot               NVARCHAR(10)   
      ,  SortColumn        NVARCHAR(20)  
      )  
           
      IF @c_Storerkey <> 'ALL'  
      BEGIN  
         SET @c_SQLConditions = ' AND SKUxLOC.Storerkey = N''' + RTRIM(@c_Storerkey) + ''''  
      END  
  
      IF (@c_Zone02 <> 'ALL')  
      BEGIN  
         SET @c_SQLConditions = @c_SQLConditions   
                              + ' AND LOC.PutawayZone IN ( N''' + RTRIM(@c_Zone02) + ''''  
                              +                          ',N''' + RTRIM(@c_Zone03) + ''''  
                              +                          ',N''' + RTRIM(@c_Zone04) + ''''  
                              +                          ',N''' + RTRIM(@c_Zone05) + ''''  
                              +                          ',N''' + RTRIM(@c_Zone06) + ''''  
                              +                          ',N''' + RTRIM(@c_Zone07) + ''')'  
  
      END   
  
      SET @c_SQLConditions = @c_SQLConditions   
                           + ' AND SKUxLOC.Sku BETWEEN N''' + RTRIM(@c_Zone09)  + ''' AND N''' + RTRIM(@c_Zone10) + ''''  
                           + ' AND LOC.LocAisle BETWEEN N''' + RTRIM(@c_Zone11) + ''' AND N''' + RTRIM(@c_Zone12) + ''''  
  
      SET @c_SQLStatement     = N'DECLARE CUR_SKUxLOC CURSOR FAST_FORWARD READ_ONLY FOR'    
                              + ' SELECT ReplenishmentPriority = ISNULL(RTRIM(SKUxLOC.ReplenishmentPriority),'''')'   
                              + ',StorerKey = ISNULL(RTRIM(SKUxLOC.StorerKey),'''')'  
                              + ',Sku = ISNULL(RTRIM(SKUxLOC.SKU),'''')'   
                              + ',Loc = ISNULL(RTRIM(SKUxLOC.LOC),'''')'   
                              + ',Qty = ISNULL(SKUxLOC.Qty,0)'   
                              + ',QtyPicked = ISNULL(SKUxLOC.QtyPicked,0)'   
                              + ',QtyAllocated = ISNULL(SKUxLOC.QtyAllocated,0)'   
                              + ',QtyLocationLimit = ISNULL(SKUxLOC.QtyLocationLimit,0)'   
                              + ',QtyLocationMinimum = ISNULL(SKUxLOC.QtyLocationMinimum,0)'   
                              + ',CaseCnt = ISNULL(PACK.CaseCnt,0.00)'   
                              + ',Pallet = ISNULL(PACK.Pallet,0.00)'   
                              + ',PickCode = ISNULL(RTRIM(SKU.PickCode),'''')'   
                              + ',LocationType = ISNULL(RTRIM(SKUxLOC.LocationType),'''')'  
                              + ' FROM    SKUxLOC WITH (NOLOCK)'   
                              + ' JOIN    LOC WITH ( NOLOCK ) ON (SKUxLOC.Loc = LOC.Loc)'   
                              + ' JOIN    SKU WITH ( NOLOCK ) ON (SKU.StorerKey = SKUxLOC.StorerKey)'   
                              +                             ' AND(SKU.SKU = SKUxLOC.SKU)'    
                              + ' JOIN    PACK WITH( NOLOCK ) ON (PACK.PackKey = SKU.PACKKey)'   
                              + ' WHERE   LOC.Facility = N''' + ISNULL(RTRIM(@c_Zone01),'') + ''' '   
                              + ' AND SKUxLOC.LocationType IN ( ''PICK'', ''CASE'' )'   
                              + ' AND LOC.LocationFlag NOT IN ( ''DAMAGE'', ''HOLD'' )'   
                              + RTRIM(ISNULL(@c_SQLConditions,''))   
                              + ' ORDER BY ISNULL(RTRIM(SKUxLOC.ReplenishmentPriority),''''), ISNULL(RTRIM(SKUxLOC.LOC),'''')'   
  
      EXEC(@c_SQLStatement)  
  
      OPEN CUR_SKUxLOC    
  
      FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentPriority  
                                    ,  @c_CurrentStorer  
                                    ,  @c_CurrentSku  
                                    ,  @c_CurrentLoc   
                                    ,  @n_Qty  
                                    ,  @n_QtyPicked  
                                    ,  @n_QtyAllocated  
                                    ,  @n_QtyLocationLimit  
                                    ,  @n_QtyLocationMinimum  
                                    ,  @n_CaseCnt  
                                    ,  @n_Pallet  
                                    ,  @c_PickCode  
                                    ,  @c_LocationType  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN  
         SET @c_ReplenishmentGrp = 'NORMAL'  
         IF EXISTS(SELECT 1 FROM REPLENISHMENT R WITH (NOLOCK)  
                   WHERE R.Storerkey = @c_CurrentStorer    
                   AND  R.Sku = @c_CurrentSku    
                   AND  R.ToLoc = @c_CurrentLoc  
                   AND  R.Confirmed = 'N')  
         BEGIN  
            IF @b_debug = 1  
            BEGIN  
               PRINT 'Deleting Previous Replenishment Record'  
               PRINT '  SKU: ' + @c_CurrentSKU   
               PRINT '  LOC: ' + @c_CurrentLOC   
            END  
          
            DELETE REPLENISHMENT  
            FROM REPLENISHMENT R  
            JOIN SKUxLOC SL WITH (NOLOCK) ON (SL.StorerKey = R.Storerkey)   
                                          AND(SL.Sku = R.Sku)  
                                          AND(SL.Loc = R.ToLoc)  
            WHERE R.Storerkey = @c_CurrentStorer    
            AND   R.Sku = @c_CurrentSKU   
            AND   R.ToLoc = @c_CurrentLOC    
            AND   R.Confirmed = 'N'    
            AND   SL.LocationType = @c_LocationType   
            AND  (R.ReplenishmentGroup NOT IN('DYNAMIC')  
            AND  (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL'))  
   
         END  
         IF @n_CaseCnt = 0 SET @n_CaseCnt = 1  
  
         SELECT @n_QtyExpectedToTake = ISNULL(SUM(CEILING((((QtyAllocated + QtyPicked) - Qty)/(@n_CaseCnt*1.00))) * @n_CaseCnt),0)  
               ,@n_QtyExpected       = ISNULL(SUM((QtyAllocated + QtyPicked) - Qty),0)  
         FROM LOTxLOCxID WITH (NOLOCK)   
         WHERE Storerkey = @c_CurrentStorer   
         AND Sku = @c_CurrentSku  
         AND Loc = @c_CurrentLoc   
         AND (QtyAllocated + QtyPicked) - Qty > 0   
  
         SET @n_QtyAvailable = ( @n_Qty - @n_QtyAllocated - @n_QtyPicked ) + @n_QtyExpected  
  
         IF @n_QtyAvailable > @n_QtyLocationMinimum  AND @n_QtyExpected <= 0   
         BEGIN           
            GOTO NEXT_RECORD  
         END    
  
         IF @n_QtyAvailable <= @n_QtyLocationMinimum   
         BEGIN   
   --         SET @n_ReplenQty = (FLOOR((@n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + (@n_QtyAllocated - @n_QtyExpected))))/(@n_Casecnt * 1.00))  * @n_CaseCnt)  
   --                          + @n_QtyExpectedToTake  
            SET @n_ReplenQty = @n_QtyLocationLimit - (@n_Qty - (@n_QtyPicked + (@n_QtyAllocated - @n_QtyExpected)))  
                             + @n_QtyExpectedToTake  
   --         IF @n_Qty - (@n_QtyPicked + @n_QtyAllocated) < 0 -- With OverAllocated Qty  
   --         BEGIN  
   --             SET @n_ReplenQty = @n_QtyLocationLimit + (CEILING((@n_QtyPicked + @n_QtyAllocated - @n_Qty)/(@n_Casecnt * 1.00)) * @n_CaseCnt)  
   --         END  
   --         ELSE  
   --         BEGIN  
   --            SET @n_ReplenQty = FLOOR((@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked - @n_QtyAllocated))/(@n_Casecnt * 1.00)) * @n_CaseCnt  
   --         END    
         END  
         ELSE  
         BEGIN  
            SET @n_ReplenQty = @n_QtyExpectedToTake          
         END  
  
         IF @n_ReplenQty < 0   
         BEGIN  
            SET @n_ReplenQty = CASE WHEN @c_LocationType = 'PICK' THEN @n_QtyLocationLimit  
                                    WHEN @c_LocationType = 'CASE' THEN @n_Pallet  
                                    END   
         END  
  
         --SET @n_RemainingQty = FLOOR(@n_ReplenQty/(@n_CaseCnt*1.00)) * @n_CaseCnt  
         SET @n_RemainingQty = @n_ReplenQty  
         --IF @n_RemainingQty = 0   
         IF @n_RemainingQty < @n_CaseCnt  
         BEGIN  
            GOTO NEXT_RECORD  
         END  
     
         DELETE #LOT_SORT  
     
         INSERT INTO #LOT_SORT  
            (  
               LOT  
            ,  SortColumn  
            )  
         SELECT DISTINCT LLL.LOT, ''  
         FROM LOTxLOCxID LLL WITH (NOLOCK)  
         WHERE LLL.StorerKey = @c_CurrentStorer  
         AND   LLL.SKU = @c_CurrentSKU  
         AND   LLL.LOC = @c_CurrentLOC  
         AND   LLL.Qty - QtyAllocated - QtyPicked < 0  
         ORDER BY LLL.Lot  
  
         IF LEFT(@c_PickCode,5) = 'nspRP'  
         BEGIN  
            INSERT INTO #LOT_SORT (LOT, SortColumn)  
            EXEC(@c_PickCode + ' N''' + @c_CurrentStorer + ''''  
                             + ',N''' + @c_CurrentSKU    + ''''  
                             + ',N''' + @c_CurrentLOC    + ''''  
                             + ',N''' + @c_Zone01        + ''''  
                             + ', ''''' )  
         END  
         ELSE  
         BEGIN  
            INSERT INTO #LOT_SORT (LOT, SortColumn)  
            SELECT DISTINCT  
                   LLI.LOT   
                 , SortColumn = CONVERT(CHAR(8), ISNULL(LA.Lottable04,'19000101') ,112)  
                              + CONVERT(CHAR(8), ISNULL(LA.Lottable05,'19000101') ,112)   
            FROM LOTxLOCxID   LLI WITH (NOLOCK)  
            JOIN LOC          LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
            JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.LOT = LA.LOT)  
            JOIN LOT          LOT WITH (NOLOCK) ON (LLI.LOT = LOT.LOT)  
            JOIN ID           ID  WITH (NOLOCK) ON (LLI.ID = ID.ID)     
            JOIN SKUxLOC      SL  WITH (NOLOCK) ON (LLI.StorerKey = LLI.StorerKey)  
                                                AND(LLI.SKU = SL.SKU)  
                                                AND(LLI.LOC = SL.LOC)  
            WHERE SL.StorerKey = @c_CurrentStorer   
            AND  SL.SKU = @c_CurrentSku  
            AND  LOC.LocationFlag <> 'DAMAGE'    
            AND  LOC.LocationFlag <> 'HOLD'    
            AND  LOC.Facility = @c_Zone01   
            AND  LOC.Status = 'OK'    
            AND  LOT.Status = 'OK'    
            AND  ID.Status = 'OK'   
            AND  LOC.Status <> 'HOLD'    
            AND  LOC.Locationtype NOT IN ('CASE','PICK')    
            AND  SL.LOC <> @c_CurrentLOC    
            AND (SL.Qty - SL.QtyPicked - SL.QtyAllocated) > 0   
            AND  SL.Locationtype <> 'CASE'   
            AND  SL.Locationtype <> 'PICK'   
            AND  NOT EXISTS(SELECT 1 FROM #LOT_SORT L WHERE L.LOT = LLI.LOT) --ang01 
            ORDER BY SortColumn  
         END  
        
         IF NOT EXISTS ( SELECT 1 FROM #LOT_SORT )  
         BEGIN  
            GOTO NEXT_RECORD  
         END  
         IF @b_debug = 1  
         BEGIN  
            Print 'Working on @c_CurrentPriority: ' +  RTRIM(@c_CurrentPriority) +   
                  ', @c_CurrentStorer:' + RTRIM(@c_CurrentStorer) +  
                  ', @c_CurrentSku:' + RTRIM(@c_CurrentSku) +  
                  ', @c_CurrentLOC:' + RTRIM(@c_CurrentLOC) +  
                  ', @n_Qty:' + Convert(VARCHAR(10),@n_Qty) +  
                  ', @n_QtyPicked:' + Convert(VARCHAR(10),@n_QtyPicked) +  
                  ', @n_QtyAllocated:' + Convert(VARCHAR(10),@n_QtyAllocated) +  
                  ', @n_QtyLocationLimit:' + Convert(VARCHAR(10),@n_QtyLocationLimit) +  
                  ', @n_QtyLocationMinimum:' + Convert(VARCHAR(10),@n_QtyLocationMinimum) +  
                  ', @n_CaseCnt:' + Convert(VARCHAR(10),@n_CaseCnt) +  
                  ', @n_Pallet:' + Convert(VARCHAR(10),@n_Pallet) +  
                  ', @c_PickCode:' + RTRIM(@c_PickCode) +  
                  ', @c_LocationType:' + RTRIM(@c_LocationType)  
         END   
  
         DECLARE CUR_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT  
               Lot  
              ,SortColumn  
         FROM #LOT_SORT  
         ORDER BY SortColumn  
     
         OPEN CUR_LOT  
     
         FETCH NEXT FROM CUR_LOT INTO @c_FromLot  
                                    , @c_SortColumn  
     
         WHILE @@FETCH_STATUS <> -1 AND @n_RemainingQty > 0  
         BEGIN  
            SET @n_QtyToReplen = @n_RemainingQty  
  
            IF @c_SortColumn = ''  
            BEGIN  
               -- Exclude other Over Allocated Qty in the same skuxloc to calc qty to replenish  
               SELECT @n_QtyToReplen       = @n_RemainingQty - @n_QtyExpectedToTake   
                                           + ISNULL(SUM(CEILING((((QtyAllocated + QtyPicked) - Qty)/(@n_CaseCnt*1.00))) * @n_CaseCnt),0)  
                     ,@n_QtyExpectedToTake = @n_QtyExpectedToTake   
                                           - ISNULL(SUM(CEILING((((QtyAllocated + QtyPicked) - Qty)/(@n_CaseCnt*1.00))) * @n_CaseCnt),0)   
               FROM LOTxLOCxID WITH (NOLOCK)   
               WHERE Lot = @c_FromLot  
               AND   Loc = @c_CurrentLoc  
               AND   Storerkey = @c_CurrentStorer   
               AND   Sku = @c_CurrentSku   
               AND  (QtyAllocated + QtyPicked) - Qty > 0   
            END  
  
            DECLARE CUR_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT LLI.LOC   
                  ,LLI.ID   
                  ,OnHandQty = (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated)    
            FROM LOTxLOCxID LLI WITH (NOLOCK)  
            JOIN LOC LOC        WITH (NOLOCK) ON (LLI.LOC = LOC.Loc)  
            JOIN ID  ID         WITH (NOLOCK) ON (LLI.ID = ID.Id)  
            JOIN SKUxLOC SL     WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey)   
                                              AND(LLI.SKU = SL.SKU)  
                                              AND(LLI.LOC = SL.LOC)  
            WHERE LOT = @c_FromLot   
            AND   LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')   
            AND   LOC.Facility = @c_Zone01  
            AND   LOC.Status = 'OK'   
            AND   ID.Status = 'OK'   
            AND   LOC.Locationtype NOT IN ('CASE','PICK')    
            AND   SL.Locationtype <> 'CASE'     
            AND   SL.Locationtype <> 'PICK'    
            AND  (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0  
            ORDER BY OnHandQty  
                  ,  LOC.LogicalLocation  
  
            OPEN CUR_REPLEN  
  
            FETCH NEXT FROM CUR_REPLEN INTO @c_FromLoc  
                                          , @c_FromID  
                                          , @n_OnHandQty  
  
            WHILE @@FETCH_STATUS <> -1 AND @n_QtyToReplen > 0  
            BEGIN  
               SET @n_LotSKUQTY = 0  
  
               SELECT @n_LotSKUQTY =ISNULL(SUM(QTY) ,0)  
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
               BEGIN              
                  GOTO NEXT_LOT  
               END  
  
                
               IF @b_debug = 1   
               BEGIN  
                  PRINT '>>>  On Hand Qty: ' + CONVERT(NVARCHAR(10), @n_OnHandQty)   
                  PRINT '     Case Cnt:' + CONVERT(NVARCHAR(10), @n_CaseCnt)  
                  PRINT '>>>  Remaining Qty: ' + CONVERT(NVARCHAR(10), @n_RemainingQty)   
                  PRINT '     Qty To Replen: ' + CONVERT(NVARCHAR(10), @n_QtyToReplen)  
               END  
  
               ----------------------------------------------------------------------------------------------------        
  
               SET @n_FromQty = CASE WHEN @n_OnHandQty <= @n_QtyToReplen THEN @n_OnHandQty  
                                     WHEN @n_OnHandQty >  @n_QtyToReplen AND @n_OnHandQty < @n_CaseCnt THEN 0  
                                     ELSE FLOOR(@n_QtyToReplen / (@n_CaseCnt * 1.00)) * @n_CaseCnt   
                                     END           
  
               SET @n_QtyToReplen  = @n_QtyToReplen  - @n_FromQty  
               SET @n_RemainingQty = @n_RemainingQty - @n_FromQty   
               ----------------------------------------------------------------------------------------------------  
               IF @b_debug = 1   
               BEGIN  
                  PRINT '>>>  @n_FromQty: ' + CONVERT(NVARCHAR(10), @n_FromQty)   
                  PRINT '>>>  Remaining Qty: ' + CONVERT(NVARCHAR(10), @n_RemainingQty)   
                  PRINT '     Qty To Replen: ' + CONVERT(NVARCHAR(10), @n_QtyToReplen)  
               END  
               IF @n_FromQty > 0  
               BEGIN  
                  SELECT @c_Packkey = PACK.PackKey,  
                         @c_UOM = PACK.PackUOM3  
                  FROM SKU  WITH (NOLOCK)  
                  JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.Packkey)  
                  WHERE SKU.StorerKey = @c_CurrentStorer  
                  AND   SKU.Sku = @c_CurrentSku  
  
                  IF EXISTS (SELECT 1 FROM #LOT_SORT WHERE SortColumn = '' )  
                  BEGIN  
                     SET @c_ReplenishmentGrp = 'OVERALLOC'  
                  END  
  
  
                 INSERT #REPLENISHMENT   
                        (  ReplenishmentGrp  
                        ,  StorerKey   
                        ,  SKU   
                        ,  FromLOC   
                        ,  ToLOC   
                        ,  Lot   
                        ,  Id   
                        ,  Qty   
                        ,  UOM   
                        ,  PackKey   
                        ,  Priority   
                        ,  QtyMoved   
                        ,  QtyInPickLOC  
                        )  
                  VALUES(  
                           @c_ReplenishmentGrp  
                        ,  @c_CurrentStorer  
                        ,  @c_CurrentSku  
                        ,  @c_FromLoc  
                        ,  @c_CurrentLOC  
                        ,  @c_FromLot  
                        ,  @c_FromID  
                        ,  @n_FromQty  
                        ,  @c_UOM  
                        ,  @c_Packkey  
                        ,  @c_CurrentPriority  
                        ,  0  
                        ,  0  
                        )  
                  SET @n_Row = @n_Row + 1  
  
               END  
  
               FETCH NEXT FROM CUR_REPLEN INTO  @c_FromLoc  
                                             ,  @c_FromID  
                                             ,  @n_OnHandQty  
            END  
            NEXT_LOT:  
            CLOSE CUR_REPLEN  
            DEALLOCATE CUR_REPLEN  
  
            FETCH NEXT FROM CUR_LOT INTO @c_FromLot  
                                       , @c_SortColumn  
         END  
         CLOSE CUR_LOT  
         DEALLOCATE CUR_LOT  
      
         NEXT_RECORD:  
         FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentPriority  
                                       ,  @c_CurrentStorer  
                                       ,  @c_CurrentSku  
                                       ,  @c_CurrentLoc   
                                       ,  @n_Qty  
                                       ,  @n_QtyPicked  
                                       ,  @n_QtyAllocated  
                                       ,  @n_QtyLocationLimit  
                                       ,  @n_QtyLocationMinimum  
                                       ,  @n_CaseCnt  
                                       ,  @n_Pallet  
                                       ,  @c_PickCode  
                                       ,  @c_LocationType  
      END  
      CLOSE CUR_SKUxLOC  
      DEALLOCATE CUR_SKUxLOC  
  
      IF @n_Continue=1 OR @n_Continue=2  
      BEGIN  
         /* Update the column QtyInPickLOC in the Replenishment Table */  
         UPDATE #REPLENISHMENT   
         SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked  
         FROM  SKUxLOC WITH (NOLOCK)  
         WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey    
         AND   #REPLENISHMENT.Sku = SKUxLOC.Sku    
      END  
  
      WHILE @@TRANCOUNT > 0   
      BEGIN  
         COMMIT TRAN  
      END  
  
      SELECT @n_Row = COUNT(1) FROM #REPLENISHMENT   
      WHERE (ReplenishmentGrp = @c_ReplGrp OR (@c_ReplGrp = 'ALL'))  
  
      IF ISNULL(@n_Row,0) = 0    
      BEGIN  
         GOTO QUIT  
      END  
  
      IF @n_Continue=1 OR @n_Continue=2   
      BEGIN   
         BEGIN TRAN  
                 
         EXECUTE nspg_GetKey  
                  'REPLENISHKEY'   
               ,  10   
               ,  @c_ReplenishmentKey  OUTPUT   
               ,  @b_success           OUTPUT   
               ,  @n_err               OUTPUT   
               ,  @c_errmsg            OUTPUT   
               ,  0   
               ,  @n_Row  
  
         IF NOT @b_success = 1  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err = 63529   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': Fail to get REPLENISHKEY. (isp_ReplenishmentRpt_BatchRefill_14)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO QUIT  
         END  
      
         COMMIT TRAN  
      END       
  
    
      IF @n_Continue=1 OR @n_Continue=2  
      BEGIN     
         /* Insert Into Replenishment Table Now */  
  
         --SET @n_ReplenishmentKey = CONVERT(INT, @c_ReplenishmentKey)  
         BEGIN TRAN  
  
         INSERT REPLENISHMENT   
            (  
               Replenishmentgroup   
            ,  ReplenishmentKey   
            ,  StorerKey   
            ,  Sku   
            ,  FromLoc   
            ,  ToLoc   
            ,  Lot   
            ,  Id   
            ,  Qty   
            ,  UOM   
            ,  PackKey   
            ,  Confirmed  
            )  
         SELECT  
               CASE WHEN @c_ReplGrp = 'ALL' THEN @c_ReplGrp   
                    ELSE R.ReplenishmentGrp END  
            ,  RIGHT ( '000000000' + LTRIM(RTRIM(STR( CAST(@c_ReplenishmentKey AS INT) +   
                                            (SELECT COUNT(DISTINCT RowRef)   
                                             FROM #REPLENISHMENT AS RANK   
                                             WHERE RANK.RowRef < MIN(R.RowRef)  
                                             AND (RANK.ReplenishmentGrp = @c_ReplGrp OR @c_ReplGrp = 'ALL'))   
                   ))),10)   
            ,  R.StorerKey   
            ,  R.Sku   
            ,  R.FromLoc   
            ,  R.ToLoc   
            ,  R.Lot   
            ,  R.Id   
            ,  R.Qty    
            ,  R.UOM   
            ,  R.PackKey   
            ,  'N'  
         FROM #REPLENISHMENT R    
         WHERE (R.ReplenishmentGrp = @c_ReplGrp OR (@c_ReplGrp = 'ALL'))  
         GROUP BY ReplenishmentGrp  
               ,  StorerKey   
               ,  SKU   
               ,  FromLOC   
               ,  ToLOC   
               ,  Lot   
               ,  Id   
               ,  Qty   
               ,  UOM   
               ,  PackKey   
               ,  Priority   
               ,  QtyMoved   
               ,  QtyInPickLOC  
  
         IF @n_err <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET  @n_err = 63531   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)  
                          + ': Insert into Replenishment table failed. (isp_ReplenishmentRpt_BatchRefill_14)'   
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO QUIT  
         END  
         COMMIT TRAN  
  
         -- End Insert Replenishment  
      END  
   END                                                               --(Wan01)       
   QUIT:     
   --(Wan01) - START
   IF @c_FuncType IN ( 'P')  -- Call By SCE                                            
   BEGIN
      SELECT  R.ReplenishmentGroup  
            , R.ReplenishmentKey  
            , R.StorerKey  
            , R.Sku  
            , SKU.Descr  
            , R.Lot  
            , R.FromLoc  
            , R.ToLoc  
            , R.Id  
            , ReplQtyCS = CASE WHEN PK.CaseCnt > 0 THEN FLOOR(R.Qty / ISNULL(PK.CaseCnt,1)) ELSE 0 END  --NJOW01  
            , ReplQtyEA = CASE WHEN PK.CaseCnt > 0 THEN R.Qty % CONVERT(INT, ISNULL(PK.CaseCnt,1)) ELSE R.Qty END --NJOW01  
            , R.PackKey  
            , R.Priority  
            , L2.PutawayZone  
            , PK.CaseCnt  
            , PK.PackUOM1  
            , PK.PackUOM3  
            , QtyAvailableCS = CASE WHEN PK.CaseCnt > 0 THEN FLOOR((LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) / ISNULL(PK.CaseCnt,1)) ELSE 0 END --NJOW01  
            , QtyAvailableEA = CASE WHEN PK.CaseCnt > 0 THEN (LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) % CONVERT(INT, ISNULL(PK.CaseCnt,1)) ELSE (LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) END --NJOW01  
            , LA.Lottable02  
            , LA.Lottable04  
      FROM  REPLENISHMENT R  (NOLOCK)  
      JOIN  SKU  SKU  WITH (NOLOCK) ON (R.Storerkey = SKU.Storerkey) AND (R.Sku = SKU.Sku)  
      JOIN  PACK PK   WITH (NOLOCK) ON (SKU.Packkey = PK.Packkey)  
      JOIN  LOC  L1   WITH (NOLOCK) ON (R.ToLoc = L1.Loc)  
      JOIN  LOC  L2   WITH (NOLOCK) ON (R.FromLoc = L2.Loc)  
      JOIN  LOTxLOCxID   LLT WITH (NOLOCK) ON (R.Lot = LLT.Lot) AND (R.FromLoc = LLT.Loc AND R.ID = LLT.ID)  
      JOIN  LotAttribute LA  WITH (NOLOCK) ON (R.Lot = LA.Lot)   
      WHERE(L1.Facility = @c_Zone01)  
      AND  (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  
      AND  (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  
      AND  (R.confirmed = 'N')  
      ORDER BY L1.PutawayZone  
            ,  R.FromLoc  
            ,  R.Storerkey   
            ,  R.Sku  

   END    
   ELSE IF @c_FuncType IN ('')   --Call by Exceed                                         
   BEGIN
      SELECT  R.ReplenishmentGroup  
            , R.ReplenishmentKey  
            , R.StorerKey  
            , R.Sku  
            , SKU.Descr  
            , R.Lot  
            , R.FromLoc  
            , R.ToLoc  
            , R.Id  
            , ReplQtyCS = CASE WHEN PK.CaseCnt > 0 THEN FLOOR(R.Qty / ISNULL(PK.CaseCnt,1)) ELSE 0 END  --NJOW01  
            , ReplQtyEA = CASE WHEN PK.CaseCnt > 0 THEN R.Qty % CONVERT(INT, ISNULL(PK.CaseCnt,1)) ELSE R.Qty END --NJOW01  
            , R.PackKey  
            , R.Priority  
            , L2.PutawayZone  
            , PK.CaseCnt  
            , PK.PackUOM1  
            , PK.PackUOM3  
            , QtyAvailableCS = CASE WHEN PK.CaseCnt > 0 THEN FLOOR((LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) / ISNULL(PK.CaseCnt,1)) ELSE 0 END --NJOW01  
            , QtyAvailableEA = CASE WHEN PK.CaseCnt > 0 THEN (LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) % CONVERT(INT, ISNULL(PK.CaseCnt,1)) ELSE (LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) END --NJOW01  
            , LA.Lottable02  
            , LA.Lottable04  
      FROM  REPLENISHMENT R  (NOLOCK)  
      JOIN  SKU  SKU  WITH (NOLOCK) ON (R.Storerkey = SKU.Storerkey) AND (R.Sku = SKU.Sku)  
      JOIN  PACK PK   WITH (NOLOCK) ON (SKU.Packkey = PK.Packkey)  
      JOIN  LOC  L1   WITH (NOLOCK) ON (R.ToLoc = L1.Loc)  
      JOIN  LOC  L2   WITH (NOLOCK) ON (R.FromLoc = L2.Loc)  
      JOIN  LOTxLOCxID   LLT WITH (NOLOCK) ON (R.Lot = LLT.Lot) AND (R.FromLoc = LLT.Loc AND R.ID = LLT.ID)  
      JOIN  LotAttribute LA  WITH (NOLOCK) ON (R.Lot = LA.Lot)   
      WHERE(L1.Facility = @c_Zone01)  
      AND  (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  
      AND  (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')  
      AND  (R.confirmed = 'N')  
      AND  EXISTS (SELECT 1 FROM #REPLENISHMENT T WHERE T.Storerkey = R.Storerkey   
                                                   AND   T.Sku = R.Sku            
                                                   AND   T.Lot = R.Lot              
                                                   AND   T.FromLoc = R.FromLoc      
                                                   AND   T.ToLoc   = R.ToLoc        
                                                   AND   T.ID      = R.ID)        
      ORDER BY L1.PutawayZone  
            ,  R.FromLoc  
            ,  R.Storerkey   
            ,  R.Sku  

   END                                                              
   --(Wan01) - END
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
  
   IF @n_Continue=3  -- Error Occured - Process AND Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ReplenishmentRpt_BatchRefill_14'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END  

GO