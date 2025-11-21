SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/  
/* Stored Procedure: ispRLBLP05                                             */  
/* Creation Date: 31-Mar-2020                                               */  
/* Copyright: LFL                                                           */  
/* Written by: WLChooi                                                      */  
/*                                                                          */  
/* Purpose: WMS-12529 - CN DYSON Release Build Load                         */
/*                                                                          */
/* Config Key = 'BuildLoadReleaseTask_SP'                                   */  
/*                                                                          */  
/* Called By: isp_BuildLoadReleaseTask_Wrapper                              */  
/*                                                                          */  
/* PVCS Version: 1.0                                                        */  
/*                                                                          */  
/* Version: 7.0                                                             */  
/*                                                                          */  
/* Data Modifications:                                                      */  
/*                                                                          */  
/* Updates:                                                                 */  
/* Date         Author   Ver  Purposes                                      */
/* 2020-07-21   WLChooi  1.1  Fix Taskdetailkey not updating to Pickdetail  */
/*                            (WL01)                                        */  
/* 2020-07-21   WLChooi  1.2  Add Message02 = Orderkey for FCP (WL02)       */
/* 2020-07-29   WLChooi  1.3  Fix Groupkey = Loadkey (WL03)                 */
/****************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLBLP05]      
  @c_Loadkey      NVARCHAR(10)  
 ,@b_Success      INT        OUTPUT  
 ,@n_err          INT        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT
 ,@c_Storerkey    NVARCHAR(15) = '' 
   
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE @n_continue int,    
           @n_starttcnt int,         -- Holds the current transaction count  
           @n_debug int,
           @n_cnt int
            
   SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
   SELECT  @n_debug = 0

   DECLARE  @c_Facility NVARCHAR(5)
           ,@c_SourceType NVARCHAR(30)
           ,@c_PickDetailKey NVARCHAR(10)            
           ,@c_OrderGroup NVARCHAR(10)
           ,@c_Short_group NVARCHAR(10)

   DECLARE   @c_TaskType            NVARCHAR(10)     
            ,@c_Priority            NVARCHAR(10)
            ,@c_Toloc               NVARCHAR(10)
            ,@c_PickMethod          NVARCHAR(10)
            ,@c_Message03           NVARCHAR(20)
            ,@c_PickCondition_SQL   NVARCHAR(4000)
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
            ,@c_ToLoc_Strategy      NVARCHAR(30)
            ,@c_ToLoc_StrategyParam NVARCHAR(4000)
            ,@c_DropID              NVARCHAR(20)
            ,@n_QtyShort            INT
            ,@n_QtyAvailable        INT
            ,@n_QtyReplen           INT
            ,@c_Sku                 NVARCHAR(20)
            ,@c_Lot                 NVARCHAR(10)
            ,@c_FromLoc             NVARCHAR(10)
            ,@c_ID                  NVARCHAR(18)
            ,@c_ToID                NVARCHAR(18)
            ,@n_Qty                 INT
            ,@n_CaseCnt             INT
            ,@c_UOM                 NVARCHAR(10)
            ,@n_UOMQty              INT
            ,@c_SourcePriority      NVARCHAR(10)
            ,@n_PickBalQty          INT = 0
            ,@n_Pallet              INT
            ,@n_MaxPallet           INT
            ,@c_ToLoc_P             NVARCHAR(50)
            ,@c_SQL                 NVARCHAR(MAX)
            ,@c_Orderkey            NVARCHAR(10)
            ,@c_LocationGroup       NVARCHAR(10)
            ,@c_ReplenishmentKey    NVARCHAR(10)
            ,@c_Packkey             NVARCHAR(10)
            ,@c_NoGenFCPTask        NVARCHAR(10)

    SET @c_SourceType = 'ispRLBLP05'   

    -----Load Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM LOADPLANDETAIL LD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType 
                                                      AND TD.Tasktype IN ('FPK','FCP','RPF')
                      WHERE LD.Loadkey = @c_Loadkey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_Loadkey) +' has nothing to release. (ispRLBLP05)'      
       END      
    END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
       IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Loadkey = @c_Loadkey
                  AND TD.Sourcetype = @c_SourceType
                  AND TD.Tasktype IN('RPF','FPK','FCP'))
       BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Load# ' + RTRIM(@c_Loadkey) + ' has been released. (ispRLBLP05)'       
       END                 
   END

    --Create pickdetail Work in progress temporary table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       CREATE TABLE #PickDetail_WIP(
          [PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,
          [CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),
          [PickHeaderKey] [nvarchar](18) NOT NULL,
          [OrderKey] [nvarchar](10) NOT NULL,
          [OrderLineNumber] [nvarchar](5) NOT NULL,
          [Lot] [nvarchar](10) NOT NULL,
          [Storerkey] [nvarchar](15) NOT NULL,
          [Sku] [nvarchar](20) NOT NULL,
          [AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),
          [UOM] [nvarchar](10) NOT NULL DEFAULT (' '),
          [UOMQty] [int] NOT NULL DEFAULT ((0)),
          [Qty] [int] NOT NULL DEFAULT ((0)),
          [QtyMoved] [int] NOT NULL DEFAULT ((0)),
          [Status] [nvarchar](10) NOT NULL DEFAULT ('0'),
          [DropID] [nvarchar](20) NOT NULL DEFAULT (''),
          [Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),
          [ID] [nvarchar](18) NOT NULL DEFAULT (' '),
          [PackKey] [nvarchar](10) NULL DEFAULT (' '),
          [UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),
          [CartonGroup] [nvarchar](10) NULL,
          [CartonType] [nvarchar](10) NULL,
          [ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
          [DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
          [ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
          [DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
          [PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
          [WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
          [EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [EditDate] [datetime] NOT NULL DEFAULT (getdate()),
          [EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [TrafficCop] [nvarchar](1) NULL,
          [ArchiveCop] [nvarchar](1) NULL,
          [OptimizeCop] [nvarchar](1) NULL,
          [ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
          [PickSlipNo] [nvarchar](10) NULL,
          [TaskDetailKey] [nvarchar](10) NULL,
          [TaskManagerReasonKey] [nvarchar](10) NULL,
          [Notes] [nvarchar](4000) NULL,
          [MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
          [WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
          [Channel_ID] [bigint] NULL DEFAULT ((0)))    	
    END
          
    IF @@TRANCOUNT = 0
       BEGIN TRAN
                    
    -----Get Storerkey and facility
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
       SELECT TOP 1 @c_Storerkey = O.Storerkey,
                    @c_Facility = O.Facility,
                    @c_ToLoc_P = ISNULL(CL.Short,'')
       FROM LOADPLAN L (NOLOCK)
       JOIN LOADPLANDETAIL LD(NOLOCK) ON L.Loadkey = LD.Loadkey
       JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
       LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'DICSEPKMTD' AND CL.Code = L.DispatchPalletPickMethod AND CL.Storerkey = O.Storerkey
       WHERE L.Loadkey = @c_Loadkey      
    END    

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 
                 FROM LOADPLANDETAIL LPD (NOLOCK)
                 JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
                 WHERE LPD.Loadkey = @c_Loadkey
                 AND O.Status = '0')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83030    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow to release. Found some order in the load is not allocated yet. (ispRLBLP05)'       
      END
   END   

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF ISNULL(@c_ToLoc_P,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83030    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ToLoc is empty or NULL. (ispRLBLP05)'       
      END
   END  

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      CREATE TABLE #TMP_LLI (
         LOC NVARCHAR(10)
      )
   END

    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = @c_Loadkey
           ,@c_Wavekey               = ''  
           ,@c_WIP_RefNo             = @c_SourceType 
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT 
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
        IF @b_Success <> 1
        BEGIN
           SET @n_continue = 3
        END          
    END

   /*--Find all Overallocated Lot
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT DISTINCT LLI.Lot             
      INTO #TMP_LOADPICKLOT
      FROM PICKDETAIL PD (NOLOCK)
      JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
      JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
      WHERE LPD.Loadkey = @c_Loadkey
      AND SXL.LocationType IN ('PICK','CASE')    	 
      AND LLI.QtyExpected > 0
   END*/

   CREATE TABLE #TMP_LOADPICKLOC (SortSeq INT, LOC NVARCHAR(30) )

   --Find all Overallocated Loc
   /*IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      INSERT INTO #TMP_LOADPICKLOC
      SELECT DISTINCT 1 AS SortSeq, LLI.Loc            
      FROM PICKDETAIL PD (NOLOCK)
      JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
      JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      JOIN LoadPlanDetail LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
      JOIN LOC L (NOLOCK) ON LLI.LOC = L.LOC
      WHERE LPD.Loadkey = @c_Loadkey
      AND SXL.LocationType IN ('PICK','CASE')  
      AND L.LocationCategory = 'PICK'  	 
      AND LLI.QtyExpected > 0
      UNION ALL --Find all Loc belongs to the wave
      SELECT DISTINCT 2 AS SortSeq, LLI.Loc            
      FROM PICKDETAIL PD (NOLOCK)
      JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
      JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      JOIN LoadPlanDetail LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
      JOIN LOC L (NOLOCK) ON LLI.LOC = L.LOC
      WHERE LPD.Loadkey = @c_Loadkey
   END*/

   CREATE TABLE #TEMP_TOLOC (
      FromLoc      NVARCHAR(50),
      ToLoc        NVARCHAR(50),
      Storerkey    NVARCHAR(50),
      SKU          NVARCHAR(50),
      Qty          INT
   )

   SELECT @c_NoGenFCPTask = ISNULL(CL.Long,'Y')
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.Listname = 'DYSONTASK' AND CL.Code = 'FCP'
   AND CL.Storerkey = 'dyson'

   --RPF - Replenish to Pick face (Overallocated)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --From daily replenishment
      INSERT INTO #TEMP_TOLOC
      SELECT TD.FromLoc, TD.Message03, TD.Storerkey, TD.SKU, TD.Qty
      FROM TASKDETAIL TD (NOLOCK)
      WHERE TD.Message03 = @c_Toloc AND TD.Storerkey = @c_Storerkey
      AND TD.SKU = @c_Sku

      --Retrieve all lot of the wave from pick loc
      SELECT DISTINCT LLI.Lot             
      INTO #TMP_LoadPICKLOT
      FROM PICKDETAIL PD (NOLOCK)
      JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
      JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
      WHERE LPD.Loadkey = @c_Loadkey
      AND SXL.LocationType IN('PICK','CASE')    	 
      AND LLI.QtyExpected > 0
     
      DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) 
             + (SELECT ISNULL(SUM(tl.Qty),0) FROM #TEMP_TOLOC tl WHERE tl.ToLoc = LLI.LOC AND tl.SKU = LLI.SKU AND tl.Storerkey = LLI.Storerkey)
             AS Qty
      FROM LOTXLOCXID LLI (NOLOCK)          
      JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
      JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      JOIN #TMP_LoadPICKLOT ON LLI.Lot = #TMP_LoadPICKLOT.Lot 
      JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = LLI.LOT
      --OUTER APPLY (SELECT SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked + LOTXLOCXID.PendingMoveIn) AS Qty FROM LOTXLOCXID (NOLOCK)
      --             WHERE LOTXLOCXID.LOT = #TMP_LoadPICKLOT.Lot  AND LOTXLOCXID.LOC = 'RYRP' AND LOTXLOCXID.ID = LLI.ID
      --             AND LOTXLOCXID.Storerkey = @c_Storerkey AND LOTXLOCXID.SKU = LLI.SKU) AS RYRPLLI
      WHERE SL.LocationType IN ('PICK','CASE')  
      AND LLI.Storerkey = @c_Storerkey
      AND LOC.Facility = @c_Facility  
      AND LOC.LocationCategory = 'PICK'  	 
      GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, PACK.CaseCnt 
      HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn)
             + (SELECT ISNULL(SUM(tl.Qty),0) FROM #TEMP_TOLOC tl WHERE tl.ToLoc = LLI.LOC AND tl.SKU = LLI.SKU AND tl.Storerkey = LLI.Storerkey)
             < 0  --overallocate
      ORDER BY MAX(LOTT.Lottable05)

      OPEN cur_PickLoc
       
      FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         IF @n_QtyShort < 0
            SET @n_QtyShort = @n_QtyShort * -1
       	     
         SET @n_QtyReplen = @n_QtyShort 
         
         --retrieve pallet from bulk 
         DECLARE cur_BulkPallet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT LLI.Lot, LLI.Loc, LLI.Id, LLI.Qty 
         FROM LOTXLOCXID LLI (NOLOCK)          
         JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         JOIN SKU (NOLOCK) ON SKU.Storerkey = LLI.Storerkey AND SKU.SKU = LLI.SKU
         JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey
         JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = LLI.LOT
         WHERE SL.LocationType NOT IN ('PICK','CASE')
         --AND LOC.LocationType = 'BULK' 
         AND LOC.LocationCategory IN ('SHUTTLE','VNA') 
         AND (LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyReplen) = 0
         AND LLI.Storerkey = @c_Storerkey
         AND LLI.Sku = @c_Sku
         AND LLI.LOC <> 'RYRP'
         --AND LOC.LocationFlag = 'NONE'
         AND LLI.Qty = CASE WHEN ISNULL(PACK.Pallet,0) > 0 THEN PACK.Pallet ELSE LLI.Qty END
         ORDER BY CASE WHEN LOC.LocationGroup = 'E' THEN 1 ELSE 2 END, LOTT.Lottable05, SL.Qty, LOC.Logicallocation, LOC.Loc, LLI.Lot

         OPEN cur_BulkPallet
         
         FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty

         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_QtyReplen > 0 
         BEGIN
            SET @c_Priority = '9'  
            SET @c_SourcePriority = '9'
            SET @c_UOM = '7'
            SET @c_PickMethod = 'FP'
            SET @c_TaskType = 'RPF' 

            EXEC isp_InsertTaskDetail   
                 @c_TaskType              = @c_TaskType        
                ,@c_Storerkey             = @c_Storerkey
                ,@c_Sku                   = @c_Sku
                ,@c_Lot                   = @c_Lot 
                ,@c_UOM                   = @c_UOM     
                ,@n_UOMQty                = 1      
                ,@n_Qty                   = @n_Qty      
                ,@c_FromLoc               = @c_Fromloc      
                ,@c_FromID                = @c_ID     
                ,@c_ToLoc                 = 'RYRP'   
                ,@c_Message03             = @c_Toloc    
                ,@c_ToID                  = @c_ID       
                ,@c_PickMethod            = @c_PickMethod
                ,@c_Priority              = @c_Priority     
                ,@c_SourcePriority        = @c_SourcePriority      
                ,@c_SourceType            = @c_SourceType      
                ,@c_SourceKey             = @c_Loadkey      
                ,@c_WaveKey               = ''  
                ,@c_Loadkey               = @c_Loadkey
                ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                ,@c_ReservePendingMoveIn  = 'Y' --Y=Update @n_qty to @n_PendingMoveIn
                ,@c_ReserveQtyReplen      = 'TASKQTY'  --TASKQTY=Reserve all task qty for replenish at Lotxlocxid
                ,@c_CallSource            = 'LOADPLAN'
                ,@c_LinkTaskToPick        = 'WIP'  --WIP=Update taskdetailkey to pickdetail_wip
                ,@c_LinkTaskToPick_SQL    = 'PICKDETAIL.UOM = @c_UOM '
                ,@b_Success               = @b_Success OUTPUT
                ,@n_Err                   = @n_err OUTPUT 
                ,@c_ErrMsg                = @c_errmsg OUTPUT       	
          	 
            IF @b_Success <> 1 
            BEGIN
               SELECT @n_continue = 3  
            END

            --EXEC rdt.rdt_Putaway_PendingMoveIn   
            --     @cUserName = ''  
            --    ,@cType = 'LOCK'  
            --    ,@cFromLoc = 'RYRP'  
            --    ,@cFromID = @c_ID  
            --    ,@cToID = @c_ID 
            --    ,@cSuggestedLOC = @c_ToLoc  
            --    ,@cStorerKey = @c_Storerkey  
            --    ,@nErrNo = @n_Err OUTPUT  
            --    ,@cErrMsg = @c_Errmsg OUTPUT  
            --    ,@cSKU = @c_Sku  
            --    ,@nPutawayQTY    = @n_Qty  
            --    ,@cFromLOT       = @c_LOT  
            --    ,@cTaskDetailKey = ''  
            --    ,@nFunc = 0  
            --    ,@nPABookingKey = 0  
            --    ,@cMoveQTYAlloc = '1'                                                                                                                                                                                
                                                                                                                     
            --IF @n_err <> 0                                                                                     
            --BEGIN                                                                                              
            --   SELECT @n_continue = 3  
            --         ,@n_err = 67994   
            --   SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
            --                      ':  Execute rdt.rdt_Putaway_PendingMoveIn Failed! (ispRLBLP05)'  
            --END 

            --Check if still need replenish
            IF( @n_QtyReplen >= @n_Qty )
               SET @n_QtyReplen = @n_QtyReplen - @n_Qty   
            ELSE
               SET @n_QtyReplen = 0   

            FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty
         END
         CLOSE cur_BulkPallet
         DEALLOCATE cur_BulkPallet

         FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort
      END
      CLOSE cur_PickLoc
      DEALLOCATE cur_PickLoc
   END

   TRUNCATE TABLE #TEMP_TOLOC
   --SELECT * FROM #TEMP_TOLOC

   --GOTO RETURN_SP

   --RPF - Replenish to Pick face
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT DISTINCT PD.LOC
      INTO #TEMPLOADLOC
      FROM PICKDETAIL PD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON PD.Orderkey = OH.Orderkey
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      WHERE LPD.Loadkey = @c_Loadkey

      --From daily replenishment
      INSERT INTO #TEMP_TOLOC
      SELECT TD.FromLoc, TD.Message03, TD.Storerkey, TD.SKU, TD.Qty
      FROM TASKDETAIL TD (NOLOCK)
      WHERE TD.Message03 = @c_Toloc AND TD.Storerkey = @c_Storerkey
      AND TD.SKU = @c_Sku

      --Retreive pick loc with qty < maxpallet
      DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LLI.Storerkey, LLI.Sku, LLI.Loc, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn)
             + (SELECT ISNULL(SUM(tl.Qty),0) FROM #TEMP_TOLOC tl WHERE tl.ToLoc = LLI.LOC AND tl.SKU = LLI.SKU AND tl.Storerkey = LLI.Storerkey)
             AS Qty,
             PACK.Pallet, LOC.MaxPallet 
      FROM LOTXLOCXID LLI (NOLOCK)          
      JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
      JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey          
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      JOIN #TEMPLOADLOC t ON t.Loc = LOC.Loc
      JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = LLI.LOT
      WHERE SL.LocationType IN( 'PICK','CASE')
      AND LLI.Storerkey = @c_Storerkey       
      AND (LOC.MaxPallet - 1) > 0
      AND PACK.Pallet > 0
      AND LOC.LocationCategory = 'PICK'
      GROUP BY LLI.Storerkey, LLI.Sku, LLI.Loc, PACK.Pallet, LOC.MaxPallet
      HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) 
             + (SELECT ISNULL(SUM(tl.Qty),0) FROM #TEMP_TOLOC tl WHERE tl.ToLoc = LLI.LOC AND tl.SKU = LLI.SKU AND tl.Storerkey = LLI.Storerkey)
             <= ((LOC.MaxPallet - 1) * PACK.Pallet)
      ORDER BY MAX(LOTT.Lottable05), LLI.LOC

      OPEN cur_PickLoc
       
      FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_ToLoc, @n_PickBalQty, @n_Pallet, @n_MaxPallet
       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         --retrieve pallet from bulk 
         DECLARE cur_BulkPallet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT LLI.Lot, LLI.Loc, LLI.Id, LLI.Qty 
         FROM LOTXLOCXID LLI (NOLOCK)          
         JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         JOIN SKU (NOLOCK) ON SKU.Storerkey = LLI.Storerkey AND SKU.SKU = LLI.SKU
         JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey
         JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = LLI.LOT
         WHERE SL.LocationType NOT IN ('PICK','CASE')
         --AND LOC.LocationType = 'BULK' 
         AND LOC.LocationCategory IN ('SHUTTLE','VNA') 
         AND (LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyReplen) = 0
         AND LLI.Storerkey = @c_Storerkey
         AND LLI.Sku = @c_Sku
         AND LLI.LOC <> 'RYRP'
         --AND LOC.LocationFlag = 'NONE'
         AND LLI.Qty = CASE WHEN ISNULL(PACK.Pallet,0) > 0 THEN PACK.Pallet ELSE LLI.Qty END
         ORDER BY CASE WHEN LOC.LocationGroup = 'E' THEN 1 ELSE 2 END, LOTT.Lottable05, SL.Qty, LOC.Logicallocation, LOC.Loc, LLI.Lot

         OPEN cur_BulkPallet
         
         FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty

         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_PickBalQty <= ((@n_MaxPallet - 1) * @n_Pallet)
         BEGIN
            SET @n_PickBalQty = @n_PickBalQty + @n_Qty
            SET @c_Priority = '9'  
            SET @c_SourcePriority = '9'
            SET @c_UOM = '1'
            SET @c_PickMethod = 'FP'
            SET @c_TaskType = 'RPF' 

            EXEC isp_InsertTaskDetail   
                 @c_TaskType              = @c_TaskType        
                ,@c_Storerkey             = @c_Storerkey
                ,@c_Sku                   = @c_Sku
                ,@c_Lot                   = @c_Lot 
                ,@c_UOM                   = @c_UOM     
                ,@n_UOMQty                = 1      
                ,@n_Qty                   = @n_Qty      
                ,@c_FromLoc               = @c_Fromloc      
                ,@c_FromID                = @c_ID     
                ,@c_ToLoc                 = 'RYRP' 
                ,@c_Message03             = @c_Toloc          
                ,@c_ToID                  = @c_ID       
                ,@c_PickMethod            = @c_PickMethod
                ,@c_Priority              = @c_Priority     
                ,@c_SourcePriority        = @c_SourcePriority      
                ,@c_SourceType            = @c_SourceType      
                ,@c_SourceKey             = @c_Loadkey      
                ,@c_WaveKey               = ''  
                ,@c_Loadkey               = @c_Loadkey
                ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                ,@c_ReservePendingMoveIn  = 'Y' --Y=Update @n_qty to @n_PendingMoveIn
                ,@c_ReserveQtyReplen      = 'TASKQTY'  --TASKQTY=Reserve all task qty for replenish at Lotxlocxid
                ,@c_CallSource            = 'LOADPLAN'
                ,@c_LinkTaskToPick        = 'WIP'  --WIP=Update taskdetailkey to pickdetail_wip
                ,@c_LinkTaskToPick_SQL    = 'PICKDETAIL.UOM = @c_UOM '
                ,@b_Success               = @b_Success OUTPUT
                ,@n_Err                   = @n_err OUTPUT 
                ,@c_ErrMsg                = @c_errmsg OUTPUT       	
          	 
            IF @b_Success <> 1 
            BEGIN
               SELECT @n_continue = 3  
            END

            --EXEC rdt.rdt_Putaway_PendingMoveIn   
            --     @cUserName = ''  
            --    ,@cType = 'LOCK'  
            --    ,@cFromLoc = 'RYRP'  
            --    ,@cFromID = @c_ID  
            --    ,@cToID = @c_ID 
            --    ,@cSuggestedLOC = @c_ToLoc  
            --    ,@cStorerKey = @c_Storerkey  
            --    ,@nErrNo = @n_Err OUTPUT  
            --    ,@cErrMsg = @c_Errmsg OUTPUT  
            --    ,@cSKU = @c_Sku  
            --    ,@nPutawayQTY    = @n_Qty  
            --    ,@cFromLOT       = @c_LOT  
            --    ,@cTaskDetailKey = ''  
            --    ,@nFunc = 0  
            --    ,@nPABookingKey = 0  
            --    ,@cMoveQTYAlloc = '1'                                                                                                                                                                                
                                                                                                                     
            --IF @n_err <> 0                                                                                     
            --BEGIN                                                                                              
            --   SELECT @n_continue = 3  
            --         ,@n_err = 67994   
            --   SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
            --                      ':  Execute rdt.rdt_Putaway_PendingMoveIn Failed! (ispRLBLP05)'  
            --END 

            FETCH FROM cur_BulkPallet INTO @c_Lot, @c_FromLoc, @c_ID, @n_Qty
         END
         CLOSE cur_BulkPallet
         DEALLOCATE cur_BulkPallet

         FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_ToLoc, @n_PickBalQty, @n_Pallet, @n_MaxPallet
      END
      CLOSE cur_PickLoc
      DEALLOCATE cur_PickLoc
   END

   TRUNCATE TABLE #TEMP_TOLOC

   --FPK - UOM1
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      SET @c_PickCondition_SQL  = 'AND PICKDETAIL.UOM = ''1'' AND SKUXLOC.LocationType NOT IN (''PICK'',''CASE'')'           
      SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ISNULL(ORDERS.Orderkey,'''') = @c_Orderkey' 
      SET @c_PickMethod = 'FP'
      SET @c_TaskType = 'FPK' 
      SET @c_Priority = '9'  
      SET @c_SourcePriority = '9'

      EXEC isp_CreateTaskByPick  
            @c_TaskType              = @c_TaskType  
           ,@c_Loadkey               = @c_Loadkey    
           ,@c_ToLoc                 = @c_ToLoc_P --Get from above Codelkup         
           ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)  
           ,@c_Priority              = @c_Priority        
           ,@c_SourcePriority        = @c_SourcePriority                   
           ,@c_SourceType            = @c_SourceType        
           ,@c_SourceKey             = @c_Loadkey           
           ,@c_CallSource            = 'LOADPLAN' -- WAVE / LOADPLAN   
           ,@c_PickCondition_SQL     = @c_PickCondition_SQL   -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LoctionType = 'OTHER'  
           ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip  
           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY  
           ,@c_ReserveQtyReplen      = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)  
           ,@c_ReservePendingMoveIn  = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn 
           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP  
           ,@c_RoundUpQty            = 'N'    -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty  
           ,@c_SplitTaskByCase       = 'N'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.  
           ,@c_ZeroSystemQty         = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.  
           ,@c_SplitTaskByOrder      = 'Y'    -- N=No slip by order Y=Split TASK by Order.  
           ,@c_SplitTaskByLoad       = 'N'    -- N=No slip by load Y=Split TASK by load. Usually applicable when create task by wave.              
           ,@b_Success               = @b_Success OUTPUT  
           ,@n_Err                   = @n_Err     OUTPUT          
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT  
             
      IF @b_Success <> 1  
      BEGIN  
         SET @n_continue = 3  
      END                                  
   END

   --FCP UOM 6
   IF (@n_continue = 1 or @n_continue = 2) AND @c_NoGenFCPTask <> 'N'
   BEGIN
      SET @c_SQL = '  
          DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR    
            SELECT PD.Storerkey, PD.Sku, MAX(PD.Lot), PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,    
                   PD.UOM, SUM(PD.UOMQty) AS UOMQty, ISNULL(O.Loadkey,''''),
                   O.Orderkey   --WL02
             FROM LOADPLANDETAIL LPD (NOLOCK)  
             JOIN LOADPLAN L (NOLOCK) ON LPD.Loadkey = L.Loadkey  
             JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey  
             JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
             JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
             JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey    
             JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
             JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot  
             WHERE LPD.Loadkey = @c_Loadkey
             AND PD.Status = ''0''  
             AND PD.WIP_RefNo = @c_SourceType  
             AND PD.UOM = ''6''          
             AND LOC.LocationGroup = CASE WHEN LOC.LocationCategory = ''PICK'' THEN O.DocType ELSE LOC.LocationGroup END
             GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, ISNULL(O.Loadkey,''''), O.Orderkey   --WL02
             ORDER BY MAX(LA.Lottable05), Loc.LogicalLocation, PD.Loc '         
      
          EXEC sp_executesql @c_SQL,  
             N'@c_Loadkey NVARCHAR(10), @c_SourceType NVARCHAR(30)',   
             @c_Loadkey,  
             @c_SourceType  
               
      OPEN cur_pick

      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Loadkey, @c_Orderkey  

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2) 
      BEGIN
         IF @c_UOM = '6'
         BEGIN
            SET @c_TaskType = 'FCP'  
            SET @c_PickMethod = 'PP'  
            SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'  
            SET @c_Priority = '9'  
            SET @c_SourcePriority = '9' 
            
            EXEC isp_InsertTaskDetail     
                  @c_TaskType              = @c_TaskType               
                 ,@c_Storerkey             = @c_Storerkey  
                 ,@c_Sku                   = @c_Sku  
                 --,@c_Lot                   = @c_Lot  --WL01
                 ,@c_UOM                   = @c_UOM        
                 ,@n_UOMQty                = @n_UOMQty       
                 ,@n_Qty                   = @n_Qty        
                 ,@c_FromLoc               = @c_Fromloc        
                 ,@c_LogicalFromLoc        = @c_FromLoc   
                 ,@c_FromID                = @c_ID     --WL01       
                 ,@c_ToLoc                 = @c_ToLoc_P         
                 ,@c_LogicalToLoc          = @c_ToLoc_P   
                 --,@c_ToID                  = @c_ID         
                 ,@c_PickMethod            = @c_PickMethod  
                 ,@c_Priority              = @c_Priority       
                 ,@c_SourcePriority        = @c_SourcePriority        
                 ,@c_SourceType            = @c_SourceType        
                 ,@c_SourceKey             = @c_Loadkey        
                 ,@c_OrderKey              = ''       
                 ,@c_WaveKey               = ''        
                 ,@c_Loadkey               = @c_Loadkey  
                 ,@c_Groupkey              = @c_Loadkey   --@c_Orderkey   --WL02   --WL03
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey   
                 ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
                 ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   
                 ,@c_Message02             = @c_Orderkey   --WL02 
                 ,@c_WIP_RefNo             = @c_SourceType  
                 ,@b_Success               = @b_Success OUTPUT  
                 ,@n_Err                   = @n_err OUTPUT   
                 ,@c_ErrMsg                = @c_errmsg OUTPUT          
                
            IF @b_Success <> 1   
            BEGIN
               SELECT @n_continue = 3    
            END 
         END

         FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Loadkey, @c_Orderkey  
      END
      CLOSE cur_pick  
      DEALLOCATE cur_pick 
   END

   --FCP UOM 7
   IF (@n_continue = 1 or @n_continue = 2) AND @c_NoGenFCPTask <> 'N'
   BEGIN
      SET @c_SQL = '  
          DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR    
            SELECT PD.Storerkey, PD.Sku, MAX(PD.Lot), PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,    
                   PD.UOM, SUM(PD.UOMQty) AS UOMQty, ISNULL(O.Loadkey,''''),
                   O.Orderkey   --WL02
             FROM LOADPLANDETAIL LPD (NOLOCK)  
             JOIN LOADPLAN L (NOLOCK) ON LPD.Loadkey = L.Loadkey  
             JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey  
             JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
             JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
             JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey    
             JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
             JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot  
             WHERE LPD.Loadkey = @c_Loadkey
             AND PD.Status = ''0''  
             AND PD.WIP_RefNo = @c_SourceType  
             AND PD.UOM = ''7''    
             --AND LOC.LocationGroup = CASE WHEN LOC.LocationCategory = ''PICK'' THEN O.DocType ELSE LOC.LocationGroup END      
             AND LOC.LocationGroup = O.DocType
             GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, ISNULL(O.Loadkey,''''), O.Orderkey   --WL02
             ORDER BY MAX(LA.Lottable05), Loc.LogicalLocation, PD.Loc '         
      
          EXEC sp_executesql @c_SQL,  
             N'@c_Loadkey NVARCHAR(10), @c_SourceType NVARCHAR(30)',   
             @c_Loadkey,  
             @c_SourceType  
               
      OPEN cur_pick

      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Loadkey, @c_Orderkey  

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2) 
      BEGIN
         IF @c_UOM = '7'
         BEGIN
            SET @c_TaskType = 'FCP'  
            SET @c_PickMethod = 'PP'  
            SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'  
            SET @c_Priority = '9'  
            SET @c_SourcePriority = '9' 
            
            EXEC isp_InsertTaskDetail     
                  @c_TaskType              = @c_TaskType               
                 ,@c_Storerkey             = @c_Storerkey  
                 ,@c_Sku                   = @c_Sku  
                 --,@c_Lot                   = @c_Lot  --WL01
                 ,@c_UOM                   = @c_UOM        
                 ,@n_UOMQty                = @n_UOMQty       
                 ,@n_Qty                   = @n_Qty        
                 ,@c_FromLoc               = @c_Fromloc        
                 ,@c_LogicalFromLoc        = @c_FromLoc   
                 ,@c_FromID                = @c_ID     --WL01        
                 ,@c_ToLoc                 = @c_ToLoc_P         
                 ,@c_LogicalToLoc          = @c_ToLoc_P   
                 --,@c_ToID                  = @c_ID         
                 ,@c_PickMethod            = @c_PickMethod  
                 ,@c_Priority              = @c_Priority       
                 ,@c_SourcePriority        = @c_SourcePriority        
                 ,@c_SourceType            = @c_SourceType        
                 ,@c_SourceKey             = @c_Loadkey        
                 ,@c_OrderKey              = ''       
                 ,@c_WaveKey               = ''        
                 ,@c_Loadkey               = @c_Loadkey  
                 ,@c_Groupkey              = @c_Loadkey   --@c_Orderkey   --WL02   --WL03
                 ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey   
                 ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
                 ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   
                 ,@c_Message02             = @c_Orderkey   --WL02  
                 ,@c_WIP_RefNo             = @c_SourceType  
                 ,@b_Success               = @b_Success OUTPUT  
                 ,@n_Err                   = @n_err OUTPUT   
                 ,@c_ErrMsg                = @c_errmsg OUTPUT          
                
            IF @b_Success <> 1   
            BEGIN
               SELECT @n_continue = 3    
            END 
         END

         FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Loadkey, @c_Orderkey  
      END
      CLOSE cur_pick  
      DEALLOCATE cur_pick 
   END

   --Replenishment of UOM 7 (Over-allocation)
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE CUR_PICKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty,
             LOC.LocationGroup, SKU.Packkey, PACK.PACKUOM3
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON O.Orderkey = LPD.Orderkey
      JOIN PICKDETAIL PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey
      JOIN LOTXLOCXID LLI (NOLOCK) ON LLI.Sku = PD.Sku AND LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.ID = PD.ID
      JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.Storerkey = PD.Storerkey
      JOIN LOC (NOLOCK) ON LLI.LOC = LOC.LOC
      JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey
      JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = LLI.LOT
      WHERE LPD.Loadkey = @c_Loadkey
      AND PD.UOM = '7'
      AND NOT EXISTS (SELECT 1 FROM TASKDETAIL (NOLOCK) WHERE SourceType = 'ispRLBLP05' AND SourceKey = @c_Loadkey 
                                                          AND UOM = '7' AND TaskType = 'RPF'
                                                          AND SKU = LLI.SKU AND Storerkey = LLI.StorerKey
                                                          AND Lot = LLI.Lot)
      GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id,
               LOC.LocationGroup, SKU.Packkey, PACK.PACKUOM3
      HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) < 0  --overallocate    
      ORDER BY MAX(LOTT.Lottable05)

      OPEN CUR_PICKDET  
  
      FETCH NEXT FROM CUR_PICKDET INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty, @c_LocationGroup, @c_Packkey, @c_UOM
         
      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)  
      BEGIN 
         TRUNCATE TABLE #TMP_LLI

         SET @c_FromLoc = ''
             
         IF @n_Qty < 0
            SET @n_Qty = @n_Qty * -1

         INSERT INTO #TMP_LLI
         SELECT LLI.LOC
         FROM LOTxLOCxID LLI (NOLOCK) 
         JOIN LOC (NOLOCK) ON LLI.LOC = LOC.LOC  
         JOIN SKUXLOC (NOLOCK) ON SKUXLOC.LOC = LOC.LOC       
         WHERE LLI.STORERKEY = @c_StorerKey  
         AND LLI.SKU = @c_Sku  
         --AND SKUxLOC.LocationType = 'PICK'  
         AND LOC.facility = @c_Facility                      
         AND LOC.LocationGroup <> @c_LocationGroup --Another block
         AND LOC.LOC <> 'RYRP'
         GROUP BY LLI.LOC
         HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) >= @n_Qty

         SELECT TOP 1 @c_FromLoc = LOC FROM #TMP_LLI

         IF ISNULL(@c_FromLoc,'') = ''
         BEGIN  
            GOTO NEXT_LOOP
         END 

         EXECUTE nspg_getkey  
             'REPLENISHKEY'  
             , 10  
             , @c_ReplenishmentKey OUTPUT  
             , @b_success OUTPUT  
             , @n_err OUTPUT  
             , @c_errmsg OUTPUT  
               
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  

         INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,  
                     StorerKey,      SKU,         FromLOC,         ToLOC,  
                     Lot,            Id,          Qty,             UOM,  
                     PackKey,        Priority,    QtyMoved,        QtyInPickLOC,  
                     RefNo,          Confirmed,   ReplenNo,        Loadkey,  
                     Remark,         OriginalQty, OriginalFromLoc, ToID,
                     QtyReplen,      PendingMoveIn)
         VALUES (  
                     @c_ReplenishmentKey,         @c_Loadkey, 
                     @c_StorerKey,   @c_Sku,      @c_FromLoc,      'RYRP',  
                     @c_Lot,         @c_Id,       @n_Qty,          @c_UOM,  
                     @c_Packkey,     '99999',     @n_Qty,          @n_Qty,  
                     '',             'N',         '',              @c_Loadkey,  
                     '',             @n_Qty,      'ispRLBLP05',    '',
                     @n_Qty,         @n_Qty)  
NEXT_LOOP:
         FETCH NEXT FROM CUR_PICKDET INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty, @c_LocationGroup, @c_Packkey, @c_UOM
      END
      CLOSE CUR_PICKDET
      DEALLOCATE CUR_PICKDET    
   END     
   -----Generate Pickslip No------    
   IF @n_continue = 1 or @n_continue = 2 
   BEGIN
      --IF dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AutoScanIn') = '1' 
      --BEGIN           	
      EXEC isp_CreatePickSlip
            @c_Loadkey = @c_Loadkey
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@c_ConsolidateByLoad = 'N'
           ,@c_AutoScanIn = 'N'   --Y=Auto scan in the pickslip N=Not auto scan in   
           ,@b_Success = @b_Success OUTPUT
           ,@n_Err = @n_err OUTPUT 
           ,@c_ErrMsg = @c_errmsg OUTPUT       	
       
      IF @b_Success = 0
         SELECT @n_continue = 3
     --END
   END
               
   -----Update Load Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN
      UPDATE LOADPLAN WITH (ROWLOCK)
      SET Status = '3',
          TrafficCop = NULL
      WHERE Loadkey = @c_Loadkey
      AND Status IN('1','2')
       
      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on LoadPlan Table Failed (ispRLBLP05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  
   
RETURN_SP:

    -----Delete pickdetail_WIP work in progress staging table
   IF @n_continue IN (1,2)
   BEGIN
      EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = @c_Loadkey
            ,@c_Wavekey               = ''  
            ,@c_WIP_RefNo             = @c_SourceType 
            ,@c_PickCondition_SQL     = ''
            ,@c_Action                = 'D'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
            ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT 
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END             
   END
    
   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
      DROP TABLE #PICKDETAIL_WIP

QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRLBLP05"  
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
      RETURN  
   END      
END --sp end

GO