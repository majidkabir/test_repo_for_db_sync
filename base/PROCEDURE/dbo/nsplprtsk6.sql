SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: nspLPRTSK6                                          */  
/* Creation Date: 09-Jun-2017                                            */  
/* Copyright: LF                                                         */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-1965 - TW NIKE Release replenishment tasks               */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/  
  
CREATE PROC [dbo].[nspLPRTSK6]  
   @c_LoadKey     NVARCHAR(10),  
   @n_err         INT          OUTPUT,  
   @c_ErrMsg      NVARCHAR(250) OUTPUT,
   @c_Storerkey   NVARCHAR(15) = '' 
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  @c_Sku             NVARCHAR(20)
            ,@c_Lot            NVARCHAR(10)
            ,@c_FromLoc        NVARCHAR(10)
            ,@c_ToLoc          NVARCHAR(10)
            ,@c_ID             NVARCHAR(18)
            ,@n_Qty            INT
            ,@n_QtyBalance     INT
            ,@n_QtyOrder       INT
            ,@n_QtyReplen      INT
            ,@c_UOM            NVARCHAR(10)
            ,@c_TaskType       NVARCHAR(10)            
            ,@c_PickMethod     NVARCHAR(10)
            ,@c_AreaKey        NVARCHAR(10)            
            ,@c_SourceType     NVARCHAR(30)   
            ,@c_Facility       NVARCHAR(5) 
            ,@c_LoadPickMethod NVARCHAR(10)
            ,@c_Load_Userdef1  NVARCHAR(100)
            ,@c_PickDetailKey  NVARCHAR(10)
            ,@n_UOMQty         NVARCHAR(10)
            ,@c_TaskDetailkey  NVARCHAR(10)
            ,@c_Pickslipno     NVARCHAR(10)
            ,@c_Orderkey       NVARCHAR(10)
            ,@n_OrderPercent   DECIMAL(12,2)
            ,@c_SKUMaterial    NVARCHAR(20)
            ,@c_RoundUpQty     NVARCHAR(5)
                               
   DECLARE  @n_continue        INT  
           ,@b_success         INT  
           ,@n_StartTranCnt    INT  
  
   SELECT @n_continue = 1 ,@n_err = 0 ,@c_ErrMsg = '', @b_Success = 1
   
   SET @c_SourceType = 'nspLPRTSK6'
   SET @c_TaskType = 'RPF'
   SET @n_UOMQty = 0
           
   SET @n_StartTranCnt = @@TRANCOUNT  

   -----Load Validation-----            
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      IF NOT EXISTS (SELECT 1 
                     FROM LOADPLANDETAIL LD (NOLOCK)
                     JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
                     LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype = 'RPF'
                     WHERE LD.Loadkey = @c_Loadkey                   
                     AND PD.Status = '0'
                     AND TD.Taskdetailkey IS NULL
                    )
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83000  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (nspLPRTSK6)'       
      END
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
       IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Loadkey = @c_Loadkey
                  AND TD.Sourcetype = @c_SourceType
                  AND TD.Tasktype = 'RPF')
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Load has beed released. (nspLPRTSK6)'       
       END                 
   END

   -----Get Storerkey, facility, loadpickmethod and Load_Userdef1 (order percentage)
   IF  (@n_continue = 1 OR @n_continue = 2)
   BEGIN
       SELECT TOP 1 @c_Storerkey = O.Storerkey,
                    @c_Facility = O.Facility,         
                    @c_LoadPickMethod = L.LoadPickMethod,
                    @c_Load_Userdef1 = ISNULL(CASE WHEN ISNUMERIC(L.Load_Userdef1) = 1 THEN L.Load_Userdef1 ELSE CL.Long END, '0')
       FROM LOADPLAN L (NOLOCK)
       JOIN LOADPLANDETAIL LD(NOLOCK) ON L.Loadkey = LD.Loadkey
       JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
       LEFT JOIN STORERCONFIG SC (NOLOCK) ON SC.Configkey = 'LOADPLANDEFAULT' AND SC.Storerkey = O.Storerkey
       LEFT JOIN CODELKUP CL (NOLOCK) ON SC.Svalue = CL.Listname AND CL.Code = 'Load_Userdef1' AND CL.Storerkey = O.Storerkey
       WHERE L.Loadkey = @c_Loadkey 
      
      IF ISNUMERIC(@c_Load_Userdef1) = 0 OR @c_Load_Userdef1 = '0'
      BEGIN
        SELECT @n_continue = 3  
        SELECT @n_err = 83020    
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Please key-in valid order percentage(Userdefined #01). (nspLPRTSK6)'       
      END                         
   END    
   
   --Check launch order location
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_LoadPickMethod = 'L-ORDER' 
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM LOC(NOLOCK) WHERE LOC = 'NIKFAST')
      BEGIN
        SELECT @n_continue = 3  
        SELECT @n_err = 83025    
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': L-ORDER must setup NIKFAST Location. (nspLPRTSK6)'             	    
      END      	  
   END

   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
                WHERE O.Loadkey = @c_Loadkey
                AND PD.WIP_RefNo = @c_SourceType)
      BEGIN
      	  DELETE PickDetail_WIP 
      	  FROM PickDetail_WIP (NOLOCK)
      	  JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey         	  
          WHERE ORDERS.Loadkey = @c_Loadkey
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType
      END 
      
      INSERT INTO PickDetail_WIP 
      (
      	PickDetailKey,      CaseID,      		 PickHeaderKey,
      	OrderKey,           OrderLineNumber, Lot,
      	Storerkey,          Sku,      	   	 AltSku,     UOM,
      	UOMQty,      	      Qty,      	   	 QtyMoved,   [Status],
      	DropID,      	      Loc,      	     ID,      	 PackKey,
      	UpdateSource,       CartonGroup,     CartonType,
      	ToLoc,      	      DoReplenish,     ReplenishZone,
      	DoCartonize,        PickMethod,      WaveKey,
      	EffectiveDate,      AddDate,      	 AddWho,
      	EditDate,           EditWho,      	 TrafficCop,
      	ArchiveCop,         OptimizeCop,     ShipFlag,
      	PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,
      	Notes,      	      MoveRefKey,			 WIP_RefNo
      )
      SELECT PD.PickDetailKey,  CaseID,   						PD.PickHeaderKey, 
      	PD.OrderKey,         		 PD.OrderLineNumber,  PD.Lot,
      	PD.Storerkey,        		 PD.Sku,      	      PD.AltSku,        PD.UOM,
      	PD.UOMQty,      	   		 PD.Qty,      	      PD.QtyMoved,      PD.[Status],
      	PD.DropID,      	   		 PD.Loc,      	      PD.ID,      	    PD.PackKey,
      	PD.UpdateSource,     		 PD.CartonGroup,      PD.CartonType,
      	PD.ToLoc,      	     		 PD.DoReplenish,      PD.ReplenishZone,
      	PD.DoCartonize,      		 PD.PickMethod,       PD.Wavekey,
      	PD.EffectiveDate,    		 PD.AddDate,      	  PD.AddWho,
      	PD.EditDate,         		 PD.EditWho,      	  PD.TrafficCop,
      	PD.ArchiveCop,       		 PD.OptimizeCop,      PD.ShipFlag,
      	PD.PickSlipNo,       		 PD.TaskDetailKey,    PD.TaskManagerReasonKey,
      	PD.Notes,      	     		 PD.MoveRefKey,       @c_SourceType 
      FROM LOADPLANDETAIL LD (NOLOCK) 
      JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'NIKREPLN' AND CL.Code = LOC.Putawayzone
      WHERE LD.Loadkey = @c_Loadkey     
      
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table. (nspLPRTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END      
   END       

   --Remove taskdetailkey 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL_WIP WITH (ROWLOCK) 
      SET PICKDETAIL_WIP.TaskdetailKey = '',
          PICKDETAIL_WIP.TrafficCop = NULL
      FROM LOADPLANDETAIL (NOLOCK)  
      JOIN PICKDETAIL_WIP ON LOADPLANDETAIL.Orderkey = PICKDETAIL_WIP.Orderkey
      WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
      AND PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (nspLPRTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END
   
   --Find out material need replenish all from bulk for Launch order only
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_LoadPickMethod = 'L-ORDER'
   BEGIN
   	   --total order qty
   	   SELECT LEFT(PD.Sku,9) AS SKUM, SUM(PD.Qty) AS QtyOrder
   	   INTO #TMP_ORDQTY
   	   FROM LOADPLANDETAIL LD (NOLOCK)
   	   JOIN PickDetail_WIP PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
   	   WHERE LD.Loadkey = @c_Loadkey
   	   GROUP BY LEFT(PD.Sku,9)
   	   
   	   --total balance
   	   SELECT LEFT(LLI.Sku,9) AS SKUM, SUM(LLI.Qty - LLI.Qtyallocated - LLI.QtyPicked) AS QtyBal
   	   INTO #TMP_INVQTY 
   	   FROM LOTXLOCXID LLI (NOLOCK)
   	   JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
   	   JOIN ID (NOLOCK) ON LLI.Id = ID.Id
   	   JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc   	   
       JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'NIKREPLN' AND CL.Code = LOC.Putawayzone
   	   WHERE LLI.Storerkey = @c_Storerkey   	   
   	   AND LOT.Status = 'OK'   	   
   	   AND ID.Status = 'OK'
   	   AND LOC.Status = 'OK'
   	   AND LOC.LocationFlag = 'NONE'
   	   AND LOC.Facility = @c_Facility 
   	   AND (LLI.Qty - LLI.Qtyallocated - LLI.QtyPicked) > 0
   	   AND LEFT(LLI.SKU,9) IN (SELECT DISTINCT LEFT(OD.Sku,9) FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey 
   	                   WHERE O.Loadkey = @c_Loadkey)
   	   GROUP BY LEFT(LLI.Sku,9)
   	   
   	   IF ISNUMERIC(@c_Load_Userdef1) = 1
   	      SET @n_OrderPercent = CAST(@c_Load_Userdef1 AS DECIMAL(12,2))
       ELSE 
          SET @n_OrderPercent = 60.00   	      
   	   
   	   --retrieve material order qty greater than order% based on current available qty.
       SELECT OQ.SKUM AS SKUM
       INTO #TMP_REPLENALL
       FROM #TMP_ORDQTY OQ 
       JOIN #TMP_INVQTY IQ ON OQ.SKUM = IQ.SKUM
       WHERE ((OQ.QtyOrder / ((IQ.QtyBal + OQ.QtyOrder) * 1.00)) * 100) >= @n_OrderPercent  --IQ.QtyBal + OQ.QtyOrder (qty available before allocate this load)
   END

   --Find out destination location
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_LoadPickMethod = 'L-ORDER' 
      BEGIN
      	 SET @c_ToLoc = 'NIKFAST'
      END 
      ELSE
      BEGIN
      	 SELECT TOP 1 @c_ToLoc = LOC.Loc
      	 FROM LOC (NOLOCK)
      	 LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey
      	 WHERE LOC.Putawayzone = 'NIKPKAREA'      	 
      	 GROUP BY LOC.Loc
      	 HAVING SUM(ISNULL(LLI.Qty,0) + ISNULL(LLI.PendingMoveIn,0)) = 0
      	 ORDER BY LOC.Loc
      	 
      	 IF ISNULL(@c_Toloc,'') = ''
      	 BEGIN
           SELECT @n_continue = 3  
           SELECT @n_err = 83050    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable to find empty Pick Area for this load plan. (nspLPRTSK6)'             	    
      	 END      	  
      END
   END
      
   -----Create Replenishment task 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN    	           	     	
   	  IF @c_LoadPickMethod = 'L-ORDER' --for launch orders only
   	  BEGIN
   	  	 --Retrieve material need to replenish all 
   	     DECLARE cur_Material CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   	        SELECT SKUM 
   	        FROM #TMP_REPLENALL
   	        ORDER BY SKUM
      
         OPEN cur_Material  
         
         FETCH NEXT FROM cur_Material INTO @c_SKUMaterial
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
         	   --Retrieve all sku of the material need to replenish all
      	   	 DECLARE cur_ReplenAll CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	           SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.ID, 
   	                 (LLI.Qty - LLI.QtyPicked) AS QtyOnHand,
   	                 (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) AS QtyBalance,   	                    	                  
   	                 SUM(CASE WHEN O.Orderkey IS NOT NULL THEN WIP.Qty ELSE 0 END) AS QtyOrder --qty allocated by this load
               FROM LOTXLOCXID LLI (NOLOCK)
               LEFT JOIN PICKDETAIL_WIP WIP (NOLOCK) ON LLI.Lot = WIP.Lot AND LLI.Loc = WIP.Loc AND LLI.Id = WIP.Id AND WIP.WIP_RefNo = @c_SourceType  
               LEFT JOIN ORDERS O (NOLOCK) ON WIP.Orderkey = O.Orderkey AND O.Loadkey = @c_Loadkey               
   	           JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
   	           JOIN ID (NOLOCK) ON LLI.Id = ID.Id
   	           JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc   	   
               JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'NIKREPLN' AND CL.Code = LOC.Putawayzone
               WHERE LLI.Storerkey = @c_Storerkey
   	           AND LOT.Status = 'OK'   	   
   	           AND ID.Status = 'OK'
   	           AND LOC.Status = 'OK'
   	           AND LOC.LocationFlag = 'NONE'
   	           AND LOC.Facility = @c_Facility 
               AND LEFT(LLI.Sku,9) = @c_SKUMaterial
               AND (LLI.Qty - LLI.QtyPicked - LLI.QtyReplen) > 0
   	           GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.ID,  LLI.Qty, LLI.QtyAllocated, LLI.QtyPicked, LLI.QtyReplen
               ORDER BY LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id
                        
            OPEN cur_ReplenAll  
            
            FETCH NEXT FROM cur_ReplenAll INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @n_QtyBalance, @n_QtyOrder
            
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
            BEGIN             
            	
            	 SET @n_QtyReplen = @n_QtyBalance + @n_QtyOrder
            	
            	 IF @n_Qty = @n_QtyReplen
            	 BEGIN
            	 	  --qty on hand(exclude picked) fully replen by this load 
            	    SET @c_UOM = ''
            	    SET @c_RoundUpQty = ''
            	    SET @c_PickMethod = 'FP'
            	 END                 
            	 ELSE 
            	 BEGIN
            	 	  --the pallet include qty allocated or replen by other load 
            	    SET @c_UOM = '2'
            	    SET @c_RoundUpQty = 'FC'
            	    SET @c_PickMethod = '?ROUNDUP'
            	 END

               EXEC isp_InsertTaskDetail   
                         @c_TaskType              = @c_TaskType             
                        ,@c_Storerkey             = @c_Storerkey
                        ,@c_Sku                   = @c_Sku
                        ,@c_Lot                   = @c_Lot 
                        ,@c_UOM                   = @c_UOM      
                        ,@n_UOMQty                = @n_UOMQty      
                        ,@n_Qty                   = @n_QtyReplen      
                        ,@n_SystemQty             = @n_QtyOrder
                        ,@c_FromLoc               = @c_Fromloc      
                        ,@c_LogicalFromLoc        = @c_FromLoc                           
                        ,@c_FromID                = @c_ID     
                        ,@c_ToLoc                 = @c_ToLoc       
                        ,@c_LogicalToLoc          = @c_ToLoc 
                        ,@c_ToID                  = @c_ID       
                        ,@c_PickMethod            = @c_PickMethod 
                        ,@c_SourcePriority        = '9'      
                        ,@c_SourceType            = @c_SourceType      
                        ,@c_SourceKey             = @c_loadkey      
                        ,@c_LoadKey               = @c_Loadkey
                        ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                        ,@c_CallSource            = 'LOADPLAN'
                        ,@c_LinkTaskToPick        = 'WIP'     -- WIP=Update taskdetailkey to pickdetail_wip
                        ,@c_WIP_RefNo             = @c_SourceType
                        ,@c_RoundUpQty            = @c_RoundUpQty      -- FC=Round up qty to full carton by packkey 
                        ,@c_ReserveQtyReplen      = 'ROUNDUP' -- ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
                        ,@c_ReservePendingMoveIn  = 'Y'       -- Y=Update @n_qty to @n_PendingMoveIn
                        ,@c_CombineTasks          = 'Y'       -- Y=Combine task of same lot,from/to loc and id
                        ,@b_Success               = @b_Success OUTPUT
                        ,@n_Err                   = @n_err OUTPUT 
                        ,@c_ErrMsg                = @c_errmsg OUTPUT       	

               IF @b_Success <> 1 
               BEGIN
                  SELECT @n_continue = 3  
               END            	
            	       
               FETCH NEXT FROM cur_ReplenAll INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @n_QtyBalance, @n_QtyOrder
            END
            CLOSE cur_ReplenAll
            DEALLOCATE cur_ReplenAll

            FETCH NEXT FROM cur_Material INTO @c_SKUMaterial
         END
         CLOSE cur_Material
         DEALLOCATE cur_Material          	                                  	     	          	          	       
   	  END
   	  
   	  IF @c_LoadPickMethod = 'L-ORDER' 
   	  BEGIN
         DECLARE cur_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    	  	
   	        SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty
            FROM LOADPLANDETAIL LD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
            JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
            WHERE LD.Loadkey = @c_Loadkey
            AND PD.Status = '0'
            AND LEFT(PD.Sku,9) NOT IN (SELECT SKUM FROM #TMP_REPLENALL)
            GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation
            ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot          	  	
   	  END
   	  ELSE
   	  BEGIN
         DECLARE cur_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    	  	
   	        SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty
            FROM LOADPLANDETAIL LD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
            JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
            WHERE LD.Loadkey = @c_Loadkey
            AND PD.Status = '0'
            GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation
            ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot          	  	
   	  END
   	     
      OPEN cur_pick  
      
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN          	       	  
         EXEC isp_InsertTaskDetail   
                   @c_TaskType              = @c_TaskType             
                  ,@c_Storerkey             = @c_Storerkey
                  ,@c_Sku                   = @c_Sku
                  ,@c_Lot                   = @c_Lot 
                  ,@c_UOM                   = @c_UOM      
                  ,@n_UOMQty                = @n_UOMQty      
                  ,@n_Qty                   = @n_Qty      
                  ,@n_SystemQty             = @n_Qty
                  ,@c_FromLoc               = @c_Fromloc      
                  ,@c_LogicalFromLoc        = @c_FromLoc                           
                  ,@c_FromID                = @c_ID     
                  ,@c_ToLoc                 = @c_ToLoc       
                  ,@c_LogicalToLoc          = @c_ToLoc 
                  ,@c_ToID                  = @c_ID       
                  ,@c_PickMethod            = '?ROUNDUP' -- ?ROUNDUP=Qty available - (qty - systemqty)
                  ,@c_Priority              = '5'     
                  ,@c_SourcePriority        = '9'      
                  ,@c_SourceType            = @c_SourceType      
                  ,@c_SourceKey             = @c_loadkey      
                  ,@c_LoadKey               = @c_Loadkey
                  ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                  ,@c_CallSource            = 'LOADPLAN'
                  ,@c_LinkTaskToPick        = 'WIP'     -- WIP=Update taskdetailkey to pickdetail_wip
                  ,@c_WIP_RefNo             = @c_SourceType
                  ,@c_RoundUpQty            = 'FC'      -- FC=Round up qty to full carton by packkey 
                  ,@c_ReserveQtyReplen      = 'ROUNDUP' -- ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
                  ,@c_ReservePendingMoveIn  = 'Y'       -- Y=Update @n_qty to @n_PendingMoveIn
                  ,@c_CombineTasks          = 'Y'       -- Y=Combine task of same lot,from/to loc and id
                  ,@b_Success               = @b_Success OUTPUT
                  ,@n_Err                   = @n_err OUTPUT 
                  ,@c_ErrMsg                = @c_errmsg OUTPUT       	
         
         IF @b_Success <> 1 
         BEGIN
            SELECT @n_continue = 3  
         END            	
               	                             	  	   
         FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty
      END 
      CLOSE cur_pick  
      DEALLOCATE cur_pick                                                
   END       
            
   -----Generate Pickslip No-------
   /*
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN
      DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Orderkey
         FROM   LOADPLANDETAIL (NOLOCK)  
         WHERE  LOADPLANDETAIL.Loadkey = @c_Loadkey   
         ORDER BY Orderkey
  
      OPEN CUR_ORDER  
  
      FETCH NEXT FROM CUR_ORDER INTO @c_Orderkey
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SET @c_PickSlipno = ''      
         SELECT @c_PickSlipno = PickheaderKey  
         FROM   PICKHEADER (NOLOCK)  
         WHERE  Orderkey = @c_Orderkey
                            
         -- Create Pickheader      
         IF ISNULL(@c_PickSlipno, '') = ''  
         BEGIN  
            EXECUTE nspg_GetKey   
            'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT      
               
            SELECT @c_Pickslipno = 'P' + @c_Pickslipno      
                       
            INSERT INTO PICKHEADER  
              (PickHeaderKey, Wavekey, Orderkey, ExternOrderkey ,PickType, Zone, TrafficCop)  
            VALUES  
              (@c_Pickslipno, '', @c_Orderkey, '', '0' ,'3', '')      
              
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed. (nspLPRTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
            END  
         END 
      
         UPDATE PICKDETAIL_WIP WITH (ROWLOCK)  
         SET    PICKDETAIL_WIP.PickSlipNo = @c_PickSlipNo  
               ,TrafficCop = NULL  
         WHERE Orderkey = @c_Orderkey
           
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed (nspLPRTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END  
         
         /*
         IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookUp WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
         BEGIN
            INSERT INTO dbo.RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
            SELECT PickdetailKey, PickSlipNo, OrderKey, OrderLineNumber 
            FROM PICKDETAIL_WIP (NOLOCK)  
            WHERE PickSlipNo = @c_PickSlipNo  
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed. (nspLPRTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            END   
         END
         */        
           
         FETCH NEXT FROM CUR_ORDER INTO @c_OrderKey      
      END   
      CLOSE CUR_ORDER  
      DEALLOCATE CUR_ORDER 
   END      
   */
   -----Update pickdetail_WIP work in progress staging table back to pickdetail                                             
   IF @n_continue = 1 or @n_continue = 2                                                                                    
   BEGIN                                                                                                                    
      DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                                     
      SELECT PickDetail_WIP.PickDetailKey, PickDetail_WIP.Qty, PickDetail_WIP.UOMQty,                                       
             PickDetail_WIP.TaskDetailKey, PickDetail_WIP.Pickslipno                                                        
      FROM PickDetail_WIP (NOLOCK)                                                                                          
      JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey                                                     
      WHERE ORDERS.Loadkey = @c_Loadkey                                                                                
      AND PICKDETAIL_WIP.WIP_RefNo = @c_SourceType            
      ORDER BY PickDetail_WIP.PickDetailKey                                                                                 
                                                                                                                            
      OPEN cur_PickDetailKey                                                                                                
                                                                                                                            
      FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_PickslipNo                
                                                                                                                            
      WHILE @@FETCH_STATUS = 0                                                                                              
      BEGIN                                                                                                                 
         IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK)                                                                   
                   WHERE PickDetailKey = @c_PickDetailKey)                                                                  
         BEGIN                                                                                                              
         	 UPDATE PICKDETAIL WITH (ROWLOCK)                                                                                
         	 SET Qty = @n_Qty,                                                                                               
         	     UOMQty = @n_UOMQty,                                                                                         
         	     TaskDetailKey = @c_TaskDetailKey,                                                                           
         	     PickslipNo = @c_Pickslipno,                                                                                 
         	     EditDate = GETDATE(),   	   		        	                                                                   
         	     TrafficCop = NULL                                                                                           
         	 WHERE PickDetailKey = @c_PickDetailKey                                                                          
                                                                                                                            
            SELECT @n_err = @@ERROR                                                                                         
                                                                                                                            
            IF @n_err <> 0                                                                                                  
            BEGIN                                                                                                           
               SELECT @n_continue = 3                                                                                       
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090   -- Should Be Set To The SQL Errmessage but
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (nspLPRTSK6)' + ' ( ' 
	  	       END   		                                                                                                       
         END                                                                                                                
         ELSE                                                                                                               
         BEGIN          	                                                                                                   
            INSERT INTO PICKDETAIL                                                                                          
                 (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                     
                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,                                               
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                          
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                               
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,                                                
                  Taskdetailkey, TaskManagerReasonkey, Notes )                                                              
            SELECT PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                    
                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,                                               
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                          
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                               
                  WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                        
                  Taskdetailkey, TaskManagerReasonkey, Notes                                                                
            FROM PICKDETAIL_WIP WITH (NOLOCK)                                                                               
            WHERE PickDetailKey = @c_PickDetailKey        
            AND PickDetail_WIP.WIP_RefNo = @c_SourceType                                                                  
                                                                                                                            
            SELECT @n_err = @@ERROR                                                                                         
                                                                                                                            
            IF @n_err <> 0                                                                                                  
            BEGIN                                                                                                           
               SELECT @n_continue = 3                                                                                       
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83100   -- Should Be Set To The SQL Errmessage but
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (nspLPRTSK6)' + ' ( ' 
	  	       END                                                                                                             
         END                                                                                                                
                                                                                                                            
      	  FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno             
      END                                                                                                                   
      CLOSE cur_PickDetailKey                                                                                               
      DEALLOCATE cur_PickDetailKey                                                                                                                                                                                                                      
   END                                                                                                                      
                                                                                                                          
   RETURN_SP:  
   
   IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
             JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey 
             WHERE O.Loadkey = @c_Loadkey
             AND PD.WIP_RefNo = @c_SourceType)
   BEGIN
   	  DELETE PickDetail_WIP 
   	  FROM PickDetail_WIP (NOLOCK)
   	  JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey         	  
      WHERE ORDERS.Loadkey = @c_Loadkey
      AND PickDetail_WIP.WIP_RefNo = @c_SourceType            
   END 
                                                                            
   IF @n_continue <> 3
   BEGIN
       WHILE @@TRANCOUNT > @n_StartTranCnt  
          COMMIT TRAN  
   END
END

GO