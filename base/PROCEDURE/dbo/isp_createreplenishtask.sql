SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CreateReplenishTask                            */
/* Creation Date: 07-Nov-2017                                           */
/* Copyright: LFL                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: WMS-3179 PH-Create Replenishment Task                       */   
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 01/09/2018   NJOW01   1.0  Ehancements. Add @c_CasecntbyLocUCC,      */
/*                            @c_message03, @c_pickmethod               */
/* 03/06/2021   NJOW02   1.1  WMS-17192 add @c_ReplenWithExtra and      */
/*                            @c_ReplenIncludeLocNoTrans                */
/************************************************************************/

CREATE PROC [dbo].[isp_CreateReplenishTask]
    @c_Storerkey                NVARCHAR(15) = ''   --if empty storerkey replenish for all storer      
   ,@c_Facility                 NVARCHAR(5) = ''    --if empty facility replenish for all facilities   
   ,@c_PutawayZones             NVARCHAR(1000) = '' --putawayzone list to filter delimited by comma e.g. Zone1, Zone3, Bulkarea, Pickarea
   ,@c_SQLCondition             NVARCHAR(3000) = '' --additional condition to filter the pick/dynamic loc. e.g. LOC.locationhandling = '1' AND SKUXLOC.Locationtype = 'PICK'
   ,@c_CaseLocRoundUpQty        NVARCHAR(10) = 'FC' --case pick loc round up qty replen from bulk. FC=Round up to full case  FP=Round up to full pallet  FL=Round up to full location qty
   ,@c_PickLocRoundUpQty        NVARCHAR(10) = 'FC' --pick/dynamic loc round up qty replen from bulk. FC=Round up to full case  FP=Round up to full pallet  FL=Round up to full location qty
   ,@c_CaseLocReplenPickCode    NVARCHAR(10) = ''   --custom replen pickcode for case loc lot sorting. the sp name must start from 'nspRP'. Put 'NOPICKCODE' to use standard lot sorting. put empty to use pickcode from sku table.
   ,@c_PickLocReplenPickCode    NVARCHAR(10) = ''   --custom replen pickcode for pick/dynamic loc lot sorting. the sp name must start from 'nspRP'. Put 'NOPICKCODE' to use standard lot sorting. put empty to use pickcode from sku table.
   ,@c_QtyReplenFormula         NVARCHAR(2000) = '' --custom formula to calculate the qty to replenish. e.g. (@n_QtyLocationLimit - (@n_Qty - @n_QtyPicked)) - @n_PendingMoveIn 
                                                    --the formula is a stadard sql statement and can apply below variables to calculate. the above example is the default.                                                    
                                                    --@n_Qty, @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit, @n_CaseCnt, @n_Pallet, n_QtyExpected, @n_PendingMoveIn, @n_QtyExpectedFinal, @c_LocationType, @c_LocLocationType
                                                    --it can pass in preset formula code. QtyExpectedFitLocLimit=try fit the overallocaton qty to location limit. usually apply when @c_BalanceExclQtyAllocated = 'Y' and do not want to replen overallocate qty exceed limit
                                                    --QtyExpectedNoLocLimit=replenish overallocated qty without check location limit
   ,@c_Priority                 NVARCHAR(10) = ''   --task priority default is 5 ?LOC=get the priority from skuxloc.ReplenishmentPriority  ?STOCK=calculate priority by on hand stock level against limit. if empty default is 5.
   ,@c_SplitTaskByCarton        NVARCHAR(5)  = 'N'  --Y=Slplit the task by carton. Casecnt must set and not applicable if roundupqty is FP,FL. 
   ,@c_CasecntbyLocUCC          NVARCHAR(5)  = 'N'  --N=Get casecnt by packkey Y=Get casecnt by UCC Qty of the lot,loc & ID. All UCC must have same qty.
   ,@c_OverAllocateOnly         NVARCHAR(5)  = 'N'  --Y=Only replenish pick/dynamic loc with overallocated qty  N=replen loc with overallocated qty and below minimum qty.
                                                    --Dynamic loc only replenish when overallocated.
   ,@c_BalanceExclQtyAllocated  NVARCHAR(5)  = 'N'  --Y=the qtyallocated is deducted when calculate loc balance. N=the qtyallocated is not deducated.
   ,@c_TaskType                 NVARCHAR(10) = 'RPF'
   ,@c_Wavekey                  NVARCHAR(10) = ''   --set to replenish only pick/dynamic loc involved by the wave
   ,@c_Loadkey                  NVARCHAR(10) = ''   --set to replenish only pick/dynamic loc involved by the load
   ,@c_SourceType               NVARCHAR(30) = 'isp_CreateReplenishmentTask'
   ,@c_Message03                NVARCHAR(20) = ''
   ,@c_PickMethod               NVARCHAR(10) = '?TASKQTY' --?=Auto determine task FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  
   ,@c_ReplenWithExtra          NVARCHAR(5) = 'N'   --N=No extra Y=Make sure the pick loc have balance after replenish qty - Demand(allocated) qty. Usually apply to @c_OverAllocateOnly to ensure the loc have balance after pickded. if bal qty is 0 without overallocated also replen extra --NJOW02
   ,@c_ReplenIncludeLocNoTrans  NVARCHAR(5) = 'N'   --N=Not include pick loc without any pickdetail of the wave/load  Y=Include pick location without pickdetail of the wave/load. Usually apply for wave/load to trigger replen by sku of the wave/load  --NJOW02
   ,@b_Success                  INT  = 1            OUTPUT
   ,@n_Err                      INT  = 0            OUTPUT 
   ,@c_ErrMsg                   NVARCHAR(250) = ''  OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue                  INT,
           @n_Cnt                       INT,
           @n_StartTCnt                 INT,
           @c_ZoneList                  NVARCHAR(1000),
           @c_SQL                       NVARCHAR(Max),
           @c_Condition                 NVARCHAR(2000),
           @c_ReplenCondition           NVARCHAR(2000),
           @c_CurrentStorerKey          NVARCHAR(15), 
           @c_CurrentFacility           NVARCHAR(5),
           @c_SKU                       NVARCHAR(20), 
           @c_Loc                       NVARCHAR(10),
           @c_FromLoc                   NVARCHAR(10), 
           @c_FromLot                   NVARCHAR(10),
           @c_FromID                    NVARCHAR(18),
           @n_Qty                       INT, 
           @n_QtyPicked                 INT, 
           @n_QtyAllocated              INT, 
           @n_QtyLocationLimit          INT, 
           @n_QtyLocationMinimum        INT,
           @c_ReplenishmentPriority     NVARCHAR(10),
           @n_CaseCnt                   INT, 
           @n_Pallet                    INT, 
           @c_PickCode                  NVARCHAR(10),
           @c_LocationType              NVARCHAR(10), 
           @c_ReplExclProdNearExpiry    NVARCHAR(10),
           @n_NearExpiryDay             INT,
           @c_SourceKey                 NVARCHAR(30),
           @n_InsertQty                 INT,
           @n_ReplenQty                 INT,
           @n_RemainingQty              INT,
           @n_OnHandQty                 INT,
           @n_QtyTake                   INT,
           @n_TotCtn                    INT,
           @c_RoundUpQty                NVARCHAR(10),
           @n_PendingMoveIn             INT,
           @c_LocLocationType           NVARCHAR(10),
           @n_NetQtyExpected            INT,
           @n_QtyExpected               INT,
           @n_QtyExpectedFinal          INT,  --for qtyexpected - pendingmovein
           @c_CallSource                NVARCHAR(20),
           @c_PriorityMethod            NVARCHAR(10),
           @n_StockLevel                FLOAT,
           @c_SortColumn                NVARCHAR(20),
           @c_CombineTasks              NVARCHAR(5),
           @n_UCCQty                    INT,
           @n_CaseCntFinal              INT,
           @n_DemandQty                 INT,
           @c_Taskdetailkey             NVARCHAR(10),
           @n_InsertQtyRoundup          INT,
           @c_CheckReplenWithExtra      NVARCHAR(5) --NJOW02
                                                                     
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 
   CREATE TABLE #LOT_SORT
   (
      LOT           NVARCHAR(10),
      SortColumn    NVARCHAR(20),
      QtyExpected   INT DEFAULT(0),
      PendingMoveIn INT DEFAULT(0)
   )
    
	 IF @n_continue IN(1,2)
	 BEGIN
	 	  SET @c_SourceKey = ''
	    SET @c_ZoneList = ''
 	 	  SET @c_Condition = '' 
 	 	  SET @c_CallSource = ''	 	 
 	 	  
	 	  SET @c_PriorityMethod = @c_Priority

      IF ISNULL(@c_Priority,'') = ''
         SET @c_Priority = '5'

	 	  IF ISNULL(@c_CaseLocRoundUpQty,'') NOT IN('FC','FP','FL')
	 	     SET @c_CaseLocRoundUpQty = 'FC'

	 	  IF ISNULL(@c_PickLocRoundUpQty,'') NOT IN('FC','FP','FL')
	 	     SET @c_PickLocRoundUpQty = 'FC'
	 	  
	 	  IF ISNULL(@c_TaskType,'') = ''
	 	     SET @c_TaskType = 'RPF'

	 	  IF ISNULL(@c_SourceType,'') = ''
	 	     SET @c_SourceType = 'isp_CreateReplenishmentTask'

	 	  IF ISNULL(@c_PickMethod,'') = ''
	 	     SET @c_PickMethod = '?TASKQTY'
	 	  
	 	  IF ISNULL(@c_CasecntbyLocUCC,'') = ''
	 	     SET @c_CasecntbyLocUCC = 'N'
	 	     
	 	  IF ISNULL(@c_SQLCondition,'') <> ''
	 	     SET @c_Condition = RTRIM(@c_Condition) + ' AND ' + RTRIM(@c_SQLCondition)
	 	     
      --only get the pick/dynamic loc the wave involved
	 	  IF ISNULL(@c_Wavekey,'') <> ''
	 	  BEGIN 	 
	 	  	 SET @c_CallSource = 'WAVE'
	 	     SET @c_Sourcekey = @c_Wavekey	 	     
	 	     SET @c_Condition = RTRIM(@c_Condition) + ' AND EXISTS(SELECT 1 FROM WAVEDETAIL WD (NOLOCK) JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey '	+
	 	         ' WHERE WD.Wavekey = @c_Wavekey AND PD.Storerkey = SKUxLOC.Storerkey AND PD.Sku = SKUxLOC.Sku ' + CASE WHEN @c_ReplenIncludeLocNoTrans ='Y' THEN ') ' ELSE ' AND PD.Loc = SKUxLOC.Loc) ' END --NJOW02
	 	  END   

      --only get the pick/dynamic loc the load involved
	 	  IF ISNULL(@c_Loadkey,'') <> ''
	 	  BEGIN
	 	  	 SET @c_CallSource = 'LOADPLAN'
	 	     SET @c_Sourcekey = @c_Loadkey	 	     
	 	     SET @c_Condition = RTRIM(@c_Condition) + ' AND EXISTS(SELECT 1 FROM LOADPLANDETAIL LD (NOLOCK) JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey '	+
	 	         ' WHERE LD.Loadkey = @c_Loadkey AND PD.Storerkey = SKUxLOC.Storerkey AND PD.Sku = SKUxLOC.Sku ' + CASE WHEN @c_ReplenIncludeLocNoTrans ='Y' THEN ') ' ELSE ' AND PD.Loc = SKUxLOC.Loc) ' END --NJOW02
	 	  END   

      --set replenishment triggering condition depend on @c_BalanceExclQtyAllocated flag
      IF @c_OverAllocateOnly = 'Y'
	 	     SET @c_ReplenCondition = ' HAVING (SUM(IIF(ISNULL(LOTXLOCXID.PendingMoveIn,0) < ISNULL(LOTXLOCXID.QtyExpected,0), 1, 0)) > 0 AND (SUM(ISNULL(LOTXLOCXID.QtyExpected,0)) > 0))' +  --NJOW02 moved up
	 	                              CASE WHEN @c_ReplenWithExtra = 'Y' THEN ' OR (SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIn,0)) = 0 ' ELSE '' END --NJOW02
      ELSE IF @c_BalanceExclQtyAllocated = 'Y' --pick loc balance calculation exclude qtyallocated. default is 'N'
	 	     SET @c_ReplenCondition = ' HAVING (SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIn,0)) <= SKUxLOC.QtyLocationMinimum 
	 	                                        OR (SUM(IIF(ISNULL(LOTXLOCXID.PendingMoveIn,0) < ISNULL(LOTXLOCXID.QtyExpected,0), 1, 0)) > 0 
	 	                                           AND (SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked) <= SKUxLOC.QtyLocationMinimum) '
      ELSE	 	                                       
	 	     SET @c_ReplenCondition = ' HAVING (SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIn,0)) <= SKUxLOC.QtyLocationMinimum 
	 	                                        OR (SUM(IIF(ISNULL(LOTXLOCXID.PendingMoveIn,0) < ISNULL(LOTXLOCXID.QtyExpected,0), 1, 0)) > 0 
	 	                                            AND (SKUxLOC.Qty - SKUxLOC.QtyPicked) <= SKUxLOC.QtyLocationMinimum) '

      --only replensh overallocated pick/dynamic loc
	 	  --IF @c_OverAllocateOnly = 'Y'    --NJOW02 moved up
	 	  --   SET @c_ReplenCondition = RTRIM(@c_ReplenCondition) + ' AND (SUM(ISNULL(LOTXLOCXID.QtyExpected,0)) > 0)'	 	  
	 	     --SET @c_Condition = RTRIM(@c_Condition) + ' AND SKUXLOC.QtyExpected > 0'	 	  
	 	  
	 	  --assign the formula to calculate qty to replenish depend on @c_BalanceExclQtyAllocated flag
	 	  IF ISNULL(@c_QtyReplenFormula,'') = ''
	 	  BEGIN
 	       SELECT @c_QtyReplenFormula = '(@n_QtyLocationLimit - (@n_Qty - ' + IIF(@c_BalanceExclQtyAllocated = 'Y','@n_QtyAllocated -','') + ' @n_QtyPicked)) - @n_PendingMoveIn'
 	    END     
 	    ELSE
 	    BEGIN
         IF @c_QtyReplenFormula = 'QtyExpectedFitLocLimit'         
         BEGIN
            SELECT @c_QtyReplenFormula = 'CASE WHEN @n_QtyExpectedFinal > 0 AND @n_QtyExpectedFinal <= @n_QtyLocationLimit THEN @n_QtyLocationLimit
                                               WHEN @n_QtyExpectedFinal > 0 AND @n_QtyExpectedFinal > @n_QtyLocationLimit THEN @n_QtyExpectedFinal
                                          ELSE (@n_QtyLocationLimit - (@n_Qty - ' + IIF(@c_BalanceExclQtyAllocated = 'Y','@n_QtyAllocated -','') + ' @n_QtyPicked) - @n_PendingMoveIn) END'
         END              
                            
         IF @c_QtyReplenFormula = 'QtyExpectedNoLocLimit'         
         BEGIN
            SELECT @c_QtyReplenFormula = 'CASE WHEN @n_QtyExpectedFinal > 0 THEN @n_QtyExpectedFinal
                                          ELSE (@n_QtyLocationLimit - (@n_Qty - ' + IIF(@c_BalanceExclQtyAllocated = 'Y','@n_QtyAllocated -','') + ' @n_QtyPicked) - @n_PendingMoveIn) END'
         END                                 
	 	  END	 	  
	 	               	 	              
	 	  --get putawayzone to filter             	 	     
	 	  IF ISNULL(@c_Putawayzones,'') <> ''
	 	  BEGIN
	 	     SELECT @c_ZoneList = @c_ZoneList + '''' + RTRIM(ISNULL(ColValue,'')) + ''','
	 	     FROM dbo.fnc_DelimSplit(',', @c_Putawayzones)
	 	     ORDER BY SeqNo
	 	     
	 	     IF ISNULL(@c_ZoneList,'') <> ''
	 	     BEGIN
	 	        SET @c_ZoneList = LEFT(@c_ZoneList, LEN(@c_ZoneList) - 1)
	 	     
	 	        SELECT @c_Condition = @c_Condition + ' AND LOC.PutawayZone IN ('+ RTRIM(@c_ZoneList) +')'
         END               
      END           
      
      IF @c_SplitTaskByCarton = 'Y'
      BEGIN
      	 SET @c_CombineTasks = 'N'
      END                        
      ELSE
      BEGIN 
      	 SET @c_CombineTasks = 'M' --M=Combine task of same lot,from/to loc and id without checking extra qty. direct merge.
      END  	                                  	 
	 END
   	 
	 IF @n_continue IN(1,2)
	 BEGIN	 
	 	  --retrieve pick or dynamic loc that need replenishment
		  SELECT @c_SQL = 'DECLARE Cur_ReplenPickLoc CURSOR FAST_FORWARD READ_ONLY FOR ' +
                         'SELECT LOC.Facility, ' +
                         'SKUxLOC.StorerKey, '+
                         'SKUxLOC.SKU, ' +
                         'SKUxLOC.LOC, ' +
                         'SKUxLOC.Qty, ' +
                         'SKUxLOC.QtyPicked, ' +
                         'SKUxLOC.QtyAllocated, ' +
                         'SKUxLOC.QtyLocationLimit, ' +
                         'SKUxLOC.QtyLocationMinimum, ' +
                         'SKUxLOC.ReplenishmentPriority, ' +
                         'PACK.CaseCnt, ' +
                         'PACK.Pallet, ' +
                         'SKU.PickCode, ' +
                         'SKUxLOC.LocationType, ' +
                         'SC2.Svalue, ' +
                         'SUM(ISNULL(LOTXLOCXID.QtyExpected,0)), ' +
                         'SUM(ISNULL(LOTXLOCXID.PendingMoveIn,0)), ' +
                         'SUM(ISNULL(LOTXLOCXID.QtyExpected,0)-ISNULL(LOTXLOCXID.PendingMoveIn,0)),' +
                         'LOC.LocationType ' +
                         'FROM SKUxLOC (NOLOCK) ' +
                         'LEFT JOIN LOTXLOCXID (NOLOCK) ON LOTXLOCXID.Storerkey = SKUxLOC.Storerkey AND LOTXLOCXID.Sku = SKUxLOC.Sku AND LOTXLOCXID.Loc = SKUxLOC.Loc ' +
                         'JOIN LOC WITH ( NOLOCK ) ON SKUxLOC.Loc = LOC.Loc ' +
                         'JOIN SKU WITH ( NOLOCK ) ON SKU.StorerKey = SKUxLOC.StorerKey AND ' +
                         '                            SKU.SKU = SKUxLOC.SKU ' +
                         'JOIN PACK WITH ( NOLOCK ) ON PACK.PackKey = SKU.PACKKey ' +
                         'LEFT JOIN V_STORERCONFIG2 SC2 ON SKUXLOC.Storerkey = SC2.Storerkey AND SC2.Configkey = ''REPLEXCLPRODNEAREXPIRY_DAY'' ' +  --storerconfig to exclude near expiry stock
                         'WHERE (LOC.Facility = @c_Facility OR ISNULL(@c_Facility,'''') = '''') ' +
                         'AND (SKUxLOC.Storerkey = @c_Storerkey OR ISNULL(@c_Storerkey,'''') = '''') ' +
                         'AND (SKUxLOC.LocationType IN ( ''PICK'', ''CASE'' ) ' +
                         '   OR (LOC.LocationType IN(''DYNPPICK'',''DYNPICKP'',''DYNPICKR'') AND SKUxLOC.QtyExpected > 0)) ' +   --DYNAMIC pick Loc only replen overallocated qty
                         'AND LOC.LocationFlag NOT IN ( ''DAMAGE'', ''HOLD'' ) ' +
                         --'AND (LOTXLOCXID.Qty > 0 OR LOTXLOCXID.QtyExpected > 0 OR LOTXLOCXID.PendingMoveIn > 0) ' +
                         RTRIM(ISNULL(@c_Condition,'')) + ' ' + --condition to filter pick or dynamic loc
                         'GROUP BY LOC.Facility, SKUxLOC.StorerKey, SKUxLOC.SKU, SKUxLOC.LOC, SKUxLOC.Qty, SKUxLOC.QtyPicked, SKUxLOC.QtyAllocated, ' +
                              'SKUxLOC.QtyAllocated, SKUxLOC.QtyLocationLimit, SKUxLOC.QtyLocationMinimum, SKUxLOC.ReplenishmentPriority, PACK.CaseCnt, SKUxLOC.LocationType, '+         
                              'PACK.Pallet, SKU.PickCode, SKU.PickCode, SC2.Svalue, LOC.LocationType ' +
                         RTRIM(ISNULL(@c_ReplenCondition,'')) + ' ' +  --condition to trigger replenishment
                         'ORDER BY SKUxLOC.ReplenishmentPriority, SKUxLOC.Loc ' 

      EXEC sp_executesql @c_SQL,
           N'@c_Storerkey NVARCHAR(15), @c_Facility NVARCHAR(5), @c_Wavekey NVARCHAR(10), @c_Loadkey NVARCHAR(10)', 
           @c_Storerkey,
           @c_Facility,
           @c_Wavekey,
           @c_Loadkey
      
      OPEN Cur_ReplenPickLoc
      FETCH NEXT FROM Cur_ReplenPickLoc INTO @c_CurrentFacility, @c_CurrentStorerkey, @c_SKU, @c_Loc, @n_Qty, @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit,
                                             @n_QtyLocationMinimum, @c_ReplenishmentPriority, @n_CaseCnt, @n_Pallet, @c_PickCode, @c_LocationType, @c_ReplExclProdNearExpiry,
                                             @n_QtyExpected, @n_PendingMoveIn, @n_QtyExpectedFinal, @c_LocLocationType 

      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN		
      	 SET @n_ReplenQty = 0
      	 SET @n_NetQtyExpected = 0
      	 SET @c_CheckReplenWithExtra =  @c_ReplenWithExtra --NJOW02
      	 
      	 --Get priority from skuxloc.replenishmentpriority
      	 IF @c_PriorityMethod = '?LOC'
      	    SET @c_Priority = @c_ReplenishmentPriority
      	 
      	 --Calculate priority by stock level   
      	 IF @c_PriorityMethod = '?STOCK'       	    
      	 BEGIN
      	    IF @n_QtyLocationLimit > 0
      	    BEGIN
      	 	     SELECT @n_StockLevel = (@n_Qty - IIF(@c_BalanceExclQtyAllocated = 'Y', @n_QtyAllocated, 0) - @n_QtyPicked)  /  (@n_QtyLocationLimit * 1.00)
      	 	     
      	 	     IF @n_StockLevel < 0
      	       	 SET @c_Priority = '0'
      	       ELSE
      	         SET @c_Priority = FLOOR(@n_StockLevel * 10)      	      	 
      	    END
      	    ELSE
      	       SET @c_Priority = '5'
      	 END
      	 
      	 --assign lot sorting pickcode by location type. if not set will use pickcode from sku master or standard query
      	 IF ISNULL(@c_CaseLocReplenPickCode,'') <> '' AND (@c_LocationType = 'CASE' OR @c_LocLocationType = 'CASE')
      	    SET @c_PickCode = @c_CaseLocReplenPickCode

      	 IF ISNULL(@c_PickLocReplenPickCode,'') <> '' AND @c_LocationType <> 'CASE' AND @c_LocLocationType <> 'CASE'
      	    SET @c_PickCode = @c_PickLocReplenPickCode
      	    
      	 --assign round up qty method by location type  
      	 IF @c_LocationType = 'CASE' OR @c_LocLocationType = 'CASE'
      	    SET @c_RoundUpQty = @c_CaseLocRoundUpQty 
      	 ELSE
      	    SET @c_RoundUpQty = @c_PickLocRoundUpQty 
      	          
         DELETE #LOT_SORT
         
         --Get overallocated lots
			   INSERT INTO #LOT_SORT (LOT, SortColumn, QtyExpected, PendingMoveIn)
			      SELECT LLI.Lot, '', SUM(LLI.QtyExpected), SUM(LLI.PendingMoveIn)
			      FROM LOTxLOCxID LLI WITH (NOLOCK)
			      WHERE LLI.StorerKey = @c_CurrentStorerkey
			      AND   LLI.SKU = @c_SKU
			      AND   LLI.LOC = @c_Loc
			      AND   (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn < 0
			      GROUP BY LLI.Lot
         
         --Get overallocated qty exclude pendingmovein       
         SELECT @n_NetQtyExpected = SUM(QtyExpected - PendingMoveIn)
         FROM #LOT_SORT
                           
         --Calculate replenishment qty by custom formula
         SELECT @c_SQL = 'SELECT @n_ReplenQty = (' + RTRIM(@c_QtyReplenFormula) + ')' + 
                        CASE WHEN CHARINDEX('PendingMoveIn', @c_QtyReplenFormula) = 0 THEN ' - @n_PendingMoveIn'  ELSE '' END  --must deduct pendingmovein becuase already have replenish task for it.
         
         EXEC sp_executesql @c_SQL,
           N'@n_Qty INT, @n_QtyPicked INT, @n_QtyAllocated INT, @n_QtyLocationMinimum INT, @n_QtyLocationLimit INT, @n_CaseCnt INT, @n_Pallet INT, 
             @n_QtyExpected INT, @n_PendingMoveIn INT, @n_QtyExpectedFinal INT, @c_LocationType NVARCHAR(10), @c_LocLocationType NVARCHAR(10), @n_ReplenQty INT OUTPUT', 
           @n_Qty, 
           @n_QtyPicked, 
           @n_QtyAllocated, 
           @n_QtyLocationMinimum,
           @n_QtyLocationLimit, 
           @n_CaseCnt, 
           @n_Pallet, 
           @n_QtyExpected,
           @n_PendingMoveIn,
           @n_QtyExpectedFinal,  --for Qtyexpected - Pendingmovin
           @c_LocationType, --SKUXLOC.Locationtype
           @c_LocLocationType,  --LOC.Locationtype
           @n_ReplenQty OUTPUT
                    
         IF @n_ReplenQty < @n_NetQtyExpected --if multi lots, the pendingmovein qty might apply to diffent lot cuased the replenqty less, so have make sure at least replen overallocate qty.
         	  SET @n_ReplenQty = @n_NetQtyExpected
         
         IF @c_CheckReplenWithExtra = 'Y' AND @n_ReplenQty <= 0  --NJOW02
         BEGIN
            SET @n_ReplenQty = 1
            SET @c_CheckReplenWithExtra = 'N' --added extra qty here, the following process no need to check again.
         END
         ELSE IF @n_ReplenQty <= 0  
         BEGIN
            GOTO NEXT_PICKLOC
         END
         
         --Retrieve available lots sorting by pickcode or standard sql
			   IF LEFT(@c_PickCode,5) = 'nspRP'
			   BEGIN
			      INSERT INTO #LOT_SORT (LOT, SortColumn)
			      EXEC(@c_PickCode + ' ''' + @c_CurrentStorerkey + ''','
                             + ' ''' + @c_SKU + ''','
                             + ' ''' + @c_LOC + ''','
                             + ' ''' + @c_CurrentFacility + ''','
                             + ' ''''' )
			   END
			   ELSE
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
               JOIN   LOT WITH (NOLOCK) ON LOT.LOT = LOTxLOCxID.LOT
               JOIN   ID WITH (NOLOCK) ON ID.ID = LOTxLOCxID.ID
               JOIN   SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = LOTxLOCxID.StorerKey
                                               AND SL.SKU = LOTxLOCxID.SKU
                                               AND SL.LOC = LOTxLOCxID.LOC
               WHERE  LOTxLOCxID.StorerKey = @c_CurrentStorerkey AND
                      LOTxLOCxID.SKU = @c_SKU AND
                      LOC.LocationFlag <> 'DAMAGE' AND
                      LOC.LocationFlag <> 'HOLD' AND
                      LOC.Facility = @c_CurrentFacility AND
                      LOC.Status = 'OK' AND
                      LOT.Status = 'OK' AND
                      ID.Status = 'OK' AND
                      LOC.Status <> 'HOLD' AND
                      LOC.Locationtype NOT IN ('PICK','CASE','DYNPPICK','DYNPICKP','DYNPICKR') AND 
                      LOTxLOCxID.LOC <> @c_LOC AND
                      (LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen) > 0 AND
                      SL.Locationtype NOT IN('CASE','PICK') AND
                      NOT EXISTS(SELECT 1 FROM #LOT_SORT L WHERE L.LOT = LOTxLOCxID.LOT)
               ORDER BY SortColumn
			   END
         
         --remove near expiry lots
         SET @n_NearExpiryDay = 0
			   IF ISNULL(@c_ReplExclProdNearExpiry,'0') <> '0' AND ISNUMERIC(@c_ReplExclProdNearExpiry) = 1
			   BEGIN
			   	  SET @n_NearExpiryDay = CONVERT(INT, @c_ReplExclProdNearExpiry) * -1 
			   	  DELETE #LOT_SORT 
			   	  FROM #LOT_SORT 
			   	  JOIN LOTATTRIBUTE LA (NOLOCK) ON #LOT_SORT.Lot = LA.Lot
			   	  WHERE ISNULL(#LOT_SORT.SortColumn,'') <> ''  --Exclude overallocation lot
			   	  AND DATEADD(Day, @n_NearExpiryDay, LA.Lottable04) <= GETDATE()
			   END

         --retrieve lots to replenish
			   DECLARE cur_REPLENLOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			   SELECT DISTINCT LOT, SortColumn
			   FROM #LOT_SORT
			   ORDER BY SortColumn, Lot
         
			   OPEN cur_REPLENLOT
         
			   FETCH NEXT FROM cur_REPLENLOT INTO @c_FromLot, @c_SortColumn 
                                                                       
         SET @n_RemainingQty = @n_ReplenQty
         
         --NJOW02 order qty short in pick loc that require to replenish
         IF (@n_Qty + @n_PendingMoveIn) - @n_QtyAllocated - @n_QtyPicked > 0 --NJOW02
            SET @n_DemandQty = @n_QtyAllocated - ((@n_Qty + @n_PendingMoveIn) - @n_QtyAllocated - @n_QtyPicked)  
         ELSE 
            SET @n_DemandQty = @n_QtyAllocated - @n_Qty  
            
			   WHILE @@FETCH_STATUS <> -1 AND @n_RemainingQty > 0 AND @n_continue IN(1,2)
			   BEGIN         
			   	  --retrieve bulk locations of the lot to replenish 
			      DECLARE CUR_LLI_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                SELECT LLI.LOC,
                       LLI.ID,
                       (LLI.QTY - LLI.QTYPICKED - LLI.QTYALLOCATED - LLI.QtyReplen) AS OnHandQty
                FROM LOTxLOCxID LLI WITH (NOLOCK)
                JOIN LOC WITH (NOLOCK) ON LLI.LOC = LOC.Loc
                JOIN ID WITH (NOLOCK) ON LLI.ID = ID.Id
                JOIN SKUxLOC SL WITH (NOLOCK) ON SL.StorerKey = LLI.StorerKey AND
                                                 SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC
                WHERE LOT = @c_FromLot AND
                      LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD') AND
                      LOC.LocationFlag = 'NONE' AND
                      LOC.Facility = @c_CurrentFacility AND
                      LOC.Status = 'OK' AND
                      ID.Status = 'OK' AND 
                      LOC.Locationtype NOT IN ('PICK','CASE','DYNPPICK','DYNPICKP','DYNPICKR') AND 
                      SL.Locationtype NOT IN('CASE','PICK')  AND
                      (LLI.QTY - LLI.QTYPICKED - LLI.QTYALLOCATED - LLI.QtyReplen) > 0
                ORDER BY OnHandQty, LOC.LogicalLocation, LOC.Loc
         
            OPEN CUR_LLI_REPLEN
            
            FETCH NEXT FROM CUR_LLI_REPLEN INTO  @c_FromLoc, @c_FromID, @n_OnHandQty
            
            WHILE @@FETCH_STATUS <> -1 AND @n_RemainingQty > 0 AND @n_continue IN(1,2)
            BEGIN
            	 SET @n_CaseCntFinal = @n_CaseCnt
            	 
               --Get casecnt from ucc qty by location 
               IF @c_CasecntbyLocUCC = 'Y'
               BEGIN                 
               	  SET @n_UCCQty = 0
                  SELECT @n_UCCQty = MAX(UCC.Qty)
                  FROM UCC (NOLOCK)
                  WHERE UCC.Storerkey = @c_CurrentStorerkey
                  AND UCC.Sku = @c_Sku
                  AND UCC.Lot = @c_FromLot
                  AND UCC.Loc = @c_FromLoc
                  AND UCC.ID = @c_FromID
                  AND UCC.Status <= '3'
                  
                  IF ISNULL(@n_UCCQty,0) > 0
                     SET @n_CaseCntFinal = @n_UCCQty
               END
                  	
               IF @n_OnHandQty >= @n_RemainingQty                          
                  SET @n_QtyTake = @n_RemainingQty
               ELSE
                  SET @n_QtyTake = @n_OnHandQty   
            	
               IF @n_CaseCntFinal > 0 AND @c_SplitTaskByCarton = 'Y' AND @c_RoundUpQty NOT IN('FP','FL')
                  SET @n_TotCtn = CEILING(@n_QtyTake / (@n_CaseCntFinal * 1.00))
               ELSE
                  SET @n_TotCtn = 1
               
       	  	   WHILE @n_TotCtn > 0 AND @n_QtyTake > 0 AND @n_continue IN(1,2)       	  	
       	  	   BEGIN      
       	  	   	  IF @n_QtyTake >= @n_CaseCntFinal AND @c_SplitTaskByCarton = 'Y' AND @c_RoundUpQty NOT IN('FP','FL')
       	  	   	     SET @n_InsertQty = @n_CaseCntFinal
       	  	   	  ELSE 
       	  	   	     SET @n_InsertQty = @n_QtyTake
       	  	   	     
       	  	   	  SET @n_QtyTake = @n_QtyTake - @n_InsertQty
                  SET @n_RemainingQty = @n_RemainingQty - @n_InsertQty
                                              	                                              	   
            	    SET @c_Taskdetailkey = ''
            	    SET @n_InsertQtyRoundup = 0
            	    
       	  	      EXEC isp_InsertTaskDetail
       	  	          @c_Taskdetailkey         = @c_Taskdetailkey OUTPUT  --NJOW02   
                     ,@c_TaskType              = @c_TaskType             
                     ,@c_Storerkey             = @c_CurrentStorerkey
                     ,@c_Sku                   = @c_Sku
                     ,@c_Lot                   = @c_FromLot 
                     ,@c_UOM                   = ''      
                     ,@n_UOMQty                = 0     
                     ,@n_Qty                   = @n_InsertQty      
                     ,@c_FromLoc               = @c_FromLoc      
                     ,@c_LogicalFromLoc        = @c_FromLoc 
                     ,@c_FromID                = @c_FromID     
                     ,@c_ToLoc                 = @c_Loc       
                     ,@c_LogicalToLoc          = @c_Loc 
                     ,@c_ToID                  = ''--@c_FromID   --only work for loseid pick loc
                     ,@c_PickMethod            = @c_PickMethod --determine FP/PP by inv qty available ?TASKQTY=(Qty available - taskqty) 
                     ,@c_Priority              = @c_Priority                          
                     ,@c_SourcePriority        = '9'      
                     ,@c_SourceType            = @c_SourceType      
                     ,@c_SourceKey             = @c_SourceKey
                     ,@c_CallSource            = @c_CallSource
                     ,@c_Message03             = @c_Message03
                     ,@c_Wavekey               = @c_Wavekey
                     ,@c_Loadkey               = @c_Loadkey
                     ,@c_AreaKey               = '?F'      -- ?F=Get from location areakey 
                     ,@n_SystemQty             = -1        -- if systemqty is zero/not provided it always copy from @n_Qty as default. if want to force it to zero, pass in negative value e.g. -1
                     ,@c_RoundUpQty            = @c_RoundUpQty  -- FC=Round up qty to full carton by packkey  FP=Round up qty to full pallet by packkey  FL=Full Location Qty
                     ,@c_ReserveQtyReplen      = 'TASKQTY' -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid 
                     ,@c_ReservePendingMoveIn  = 'Y'      -- Y=Update @n_qty to @n_PendingMoveIn
                     ,@c_CasecntbyLocUCC       = @c_CasecntbyLocUCC                                                 --                        
                     ,@c_CombineTasks          = @c_CombineTasks      --M=Combine task of same lot,from/to loc and id without checking extra qty. direct merge.
                     ,@b_Success               = @b_Success OUTPUT
                     ,@n_Err                   = @n_err OUTPUT 
                     ,@c_ErrMsg                = @c_errmsg OUTPUT       	
          	                	 
                  IF @b_Success <> 1 
                  BEGIN
                     SELECT @n_continue = 3  
                  END
                  
                  --NJOW02 S
                  SELECT @n_InsertQtyRoundup = Qty
                  FROM TASKDETAIL (NOLOCK)
                  WHERE Taskdetailkey = @c_Taskdetailkey
                  
                  IF @n_InsertQtyRoundup > @n_InsertQty
                  BEGIN
                  	 SET @n_RemainingQty = @n_RemainingQty - (@n_InsertQtyRoundup - @n_InsertQty)
                  END
                  
                  IF @c_CheckReplenWithExtra = 'Y'
                  BEGIN
                     SET @n_DemandQty = @n_DemandQty - @n_InsertQtyRoundup                 
                     IF @n_DemandQty = 0 AND @n_RemainingQty = 0
                        SET @n_RemainingQty = @n_RemainingQty + 1
                  END
                  --NJOW02 E
                     
                  SET @n_TotCtn = @n_TotCtn - 1          
               END               	
            	 
               FETCH NEXT FROM CUR_LLI_REPLEN INTO  @c_FromLoc, @c_FromID, @n_OnHandQty
            END
            CLOSE CUR_LLI_REPLEN
            DEALLOCATE CUR_LLI_REPLEN
            
            FETCH NEXT FROM cur_REPLENLOT INTO @c_FromLot, @c_SortColumn           
			   END
			   CLOSE cur_REPLENLOT
			   DEALLOCATE cur_REPLENLOT
			   
			   NEXT_PICKLOC:			  
			    
         FETCH NEXT FROM Cur_ReplenPickLoc INTO @c_CurrentFacility, @c_CurrentStorerkey, @c_SKU, @c_Loc, @n_Qty, @n_QtyPicked, @n_QtyAllocated, @n_QtyLocationLimit,
                                                @n_QtyLocationMinimum, @c_ReplenishmentPriority, @n_CaseCnt, @n_Pallet, @c_PickCode, @c_LocationType, @c_ReplExclProdNearExpiry,
                                                @n_QtyExpected, @n_PendingMoveIn, @n_QtyExpectedFinal, @c_LocLocationType 
      END              
      CLOSE Cur_ReplenPickLoc
      DEALLOCATE Cur_ReplenPickLoc
   END
      	   
   QUIT_SP:
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'isp_CreateReplenishTask'		
	    RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	    WHILE @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	COMMIT TRAN
	    END
	    RETURN
	 END  
END  

GO