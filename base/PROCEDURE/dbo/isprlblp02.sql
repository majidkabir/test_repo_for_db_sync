SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLBLP02                                          */  
/* Creation Date: 27-Jun-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-5329 - CN Skechers TJ Robot Build load release repl task */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 14/08/2018   NJOW01   1.0  Fix filter facility                        */
/* 15/08/2018   NJOW02   1.1  Fix @c_lot2 variable conflic issue and     */
/*                            include loc.locationtype='PICK' for replen */ 
/*                            and fix lot available qty                  */
/* 12/03/2019   Wan01    1.2  Fixed.                                     */
/* 29/03/2019   NJOW03   1.3  WMS-8432 Auto trigger Robot interface      */
/*************************************************************************/  
  
CREATE PROC [dbo].[ispRLBLP02]  
   @c_LoadKey     NVARCHAR(10),  
   @b_Success     INT = 1            OUTPUT,
   @n_err         INT = 0            OUTPUT,  
   @c_ErrMsg      NVARCHAR(250) = '' OUTPUT,
   @c_Storerkey   NVARCHAR(15) = '' 
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE   @n_continue       INT  
            ,@n_StartTranCnt   INT  
            ,@c_Sku            NVARCHAR(20)
            ,@c_Loc            NVARCHAR(10)
            ,@c_Lot            NVARCHAR(10)
            ,@c_Lot2           NVARCHAR(10)
            ,@c_FromLoc        NVARCHAR(10)
            ,@c_ToLoc          NVARCHAR(10)
            ,@c_ID             NVARCHAR(18)
            ,@c_ToID           NVARCHAR(18)
            ,@n_Qty            INT
            ,@n_QtyReplen      INT
            ,@c_UOM            NVARCHAR(10)
            ,@c_TaskType       NVARCHAR(10)            
            ,@c_PickMethod     NVARCHAR(10)
            ,@c_SourceType     NVARCHAR(30)   
            ,@c_Facility       NVARCHAR(5) 
            ,@c_PickDetailKey  NVARCHAR(10)
            ,@n_UOMQty         NVARCHAR(10)
            ,@c_TaskDetailkey  NVARCHAR(10)
            ,@c_Pickslipno     NVARCHAR(10)
            ,@c_RobotStaging   NVARCHAR(10)
            ,@c_PackStation    NVARCHAR(10)
            ,@c_Message03      NVARCHAR(20) 
            ,@n_TotCtn         INT
            ,@n_CaseCnt        INT                
            ,@c_Priority       NVARCHAR(10)
            ,@n_QtyShort       INT
            ,@n_QtyAvailable   INT
            ,@n_InsertQty      INT
            ,@c_LinkTaskToPick_SQL NVARCHAR(4000)
            ,@n_LotQtyReplen   INT
            ,@c_PrevLot        NVARCHAR(10)
            ,@n_LotQtyReplen_Tmp INT
            ,@n_QtyExpected      INT
            ,@c_LotAvailable     NVARCHAR(10)
            ,@c_IDAvailable      NVARCHAR(18)
              ,@c_TargetLot        NVARCHAR(10)  
              ,@n_PickQty          INT
              ,@n_SplitQty         INT
              ,@c_NewPickdetailKey NVARCHAR(10)
              ,@n_QtySwap          INT
              ,@n_QtyBal           INT
              ,@c_TrafficCop       NVARCHAR(10)
              ,@b_debug            INT
              ,@c_Status           NVARCHAR(10)
              
   IF @n_err = 1
      SET @b_debug = 1
   ELSE
      SET @b_debug = 0          
                                             
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1 ,@n_err = 0 ,@c_ErrMsg = '', @b_Success = 1   
   
   SET @c_SourceType = 'RLBLP02' + @c_Loadkey
   SET @c_TaskType = 'RPF'
   SET @n_UOMQty = 0
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN

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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_Loadkey) +' Has nothing to release. (ispRLBLP02)'       
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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_Loadkey) + ' has beed released. (ispRLBLP02)'       
       END                 
   END

   -----Get Storerkey, facility
   IF  (@n_continue = 1 OR @n_continue = 2)
   BEGIN
       SELECT TOP 1 @c_Storerkey = O.Storerkey,
                    @c_Facility = O.Facility
       FROM LOADPLAN L (NOLOCK)
       JOIN LOADPLANDETAIL LD(NOLOCK) ON L.Loadkey = LD.Loadkey
       JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
       WHERE L.Loadkey = @c_Loadkey       
       
       CREATE TABLE #TMP_LOTMOVEIN (Lot NVARCHAR(10), PendingMoveIn INT, QtyExpected INT, QtyAvailable INT, Targeted NCHAR(1))
   END    
   
   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)               
                WHERE PD.WIP_RefNo = @c_SourceType)
      BEGIN
           DELETE PickDetail_WIP 
           FROM PickDetail_WIP (NOLOCK)
          WHERE PickDetail_WIP.WIP_RefNo = @c_SourceType
      END 
      
      INSERT INTO PickDetail_WIP 
      (
         PickDetailKey,      CaseID,             PickHeaderKey,
         OrderKey,           OrderLineNumber, Lot,
         Storerkey,          Sku,                AltSku,     UOM,
         UOMQty,              Qty,               QtyMoved,   [Status],
         DropID,              Loc,             ID,        PackKey,
         UpdateSource,       CartonGroup,     CartonType,
         ToLoc,               DoReplenish,     ReplenishZone,
         DoCartonize,        PickMethod,      WaveKey,
         EffectiveDate,      AddDate,         AddWho,
         EditDate,           EditWho,         TrafficCop,
         ArchiveCop,         OptimizeCop,     ShipFlag,
         PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,
         Notes,               MoveRefKey,        WIP_RefNo
      )
      SELECT PD.PickDetailKey,  CaseID,                     PD.PickHeaderKey, 
         PD.OrderKey,                PD.OrderLineNumber,  PD.Lot,
         PD.Storerkey,               PD.Sku,             PD.AltSku,        PD.UOM,
         PD.UOMQty,                  PD.Qty,             PD.QtyMoved,      PD.[Status],
         PD.DropID,                  PD.Loc,             PD.ID,             PD.PackKey,
         PD.UpdateSource,            PD.CartonGroup,      PD.CartonType,
         PD.ToLoc,                   PD.DoReplenish,      PD.ReplenishZone,
         PD.DoCartonize,             PD.PickMethod,       PD.Wavekey,
         PD.EffectiveDate,           PD.AddDate,           PD.AddWho,
         PD.EditDate,                PD.EditWho,           PD.TrafficCop,
         PD.ArchiveCop,              PD.OptimizeCop,      PD.ShipFlag,
         PD.PickSlipNo,              PD.TaskDetailKey,    PD.TaskManagerReasonKey,
         PD.Notes,                   PD.MoveRefKey,       @c_SourceType 
      FROM LOADPLANDETAIL LD (NOLOCK) 
      JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      WHERE LD.Loadkey = @c_Loadkey     
      
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. Error Insert PickDetail_WIP Table. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END      
   END       

   --Remove taskdetailkey 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL_WIP WITH (ROWLOCK) 
      SET PICKDETAIL_WIP.TaskdetailKey = '',
          PICKDETAIL_WIP.TrafficCop = NULL
      WHERE PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. Update Pickdetail_WIP Table Failed. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END

   --Get Robot Staging 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_RobotStaging = ''       
        SELECT @c_RobotStaging = CL.Long
        FROM CODELKUP CL (NOLOCK)              
        JOIN LOC (NOLOCK) ON CL.Long = LOC.Loc
        WHERE CL.Listname = 'ROBOTLOC'
        AND CL.Storerkey = @c_Storerkey
        AND CL.Code2 = @c_Facility 
        AND CL.Code = '7'
              
      IF ISNULL(@c_RobotStaging,'') = ''
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. Invalid Robot Staging setup at listname ROBOTLOC. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END

   --Get Packstation
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_PackStation = ''     
        SELECT @c_PackStation = CL.Long
        FROM CODELKUP CL (NOLOCK)              
        JOIN LOC (NOLOCK) ON CL.Long = LOC.Loc
        WHERE CL.Listname = 'ROBOTLOC'
        AND CL.Storerkey = @c_Storerkey
        AND CL.Code2 = @c_Facility 
        AND CL.Code = '2'
              
      IF ISNULL(@c_RobotStaging,'') = ''
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Load# ' + RTRIM(@c_Loadkey) + '. Invalid PackStation setup at listname ROBOTLOC. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END

   --Create case pick task
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN                     
      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty, 
                PACK.CaseCnt
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
         JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE LPD.Loadkey = @c_Loadkey
         AND PD.Status = '0'
         AND PD.WIP_RefNo = @c_SourceType
         --AND SL.LocationType NOT IN('PICK','CASE')
         --AND LOC.LocationType NOT IN ('ROBOTSTG','DYNPPICK','DYNPICKP','PICK')
         --AND LOC.LocationCategory NOT IN('ROBOT')
         AND LOC.Loc <> @c_PackStation
         AND PD.UOM = '2' 
         GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, PACK.CaseCnt
         ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot       
      
      OPEN cur_pick  
      
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @n_CaseCnt
           
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN              
          SET @c_ToLoc = @c_PackStation
          SET @c_Message03 = 'PACKSTATION' 
          SET @c_Priority = '9'
          SET @c_PickMethod = 'PP'
           SET @n_TotCtn = FLOOR(@n_Qty / @n_CaseCnt)              

           --additional condition to search pickdetail
         SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM' 
                         
           WHILE @n_TotCtn > 0 AND @n_continue IN(1,2)            
           BEGIN
              EXEC isp_InsertTaskDetail   
                @c_TaskType              = @c_TaskType             
               ,@c_Storerkey             = @c_Storerkey
               ,@c_Sku                   = @c_Sku
               ,@c_Lot                   = @c_Lot 
               ,@c_UOM                   = @c_UOM      
               ,@n_UOMQty                = @n_CaseCnt     
               ,@n_Qty                   = @n_CaseCnt      
               ,@c_FromLoc               = @c_Fromloc      
               ,@c_LogicalFromLoc        = @c_FromLoc 
               ,@c_FromID                = @c_ID     
               ,@c_ToLoc                 = @c_ToLoc       
               ,@c_LogicalToLoc          = @c_ToLoc 
               ,@c_ToID                  = @c_ID       
               ,@c_PickMethod            = @c_PickMethod
               ,@c_Priority              = @c_Priority     
               ,@c_SourcePriority        = '9'      
               ,@c_SourceType            = @c_SourceType      
               ,@c_SourceKey             = @c_Loadkey      
               ,@c_LoadKey               = @c_Loadkey      
               ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
               ,@c_Message03             = @c_Message03
               ,@c_CallSource            = 'LOADPLAN'
               ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
               ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
               ,@c_WIP_RefNo             = @c_SourceType
               ,@b_Success               = @b_Success OUTPUT
               ,@n_Err                   = @n_err OUTPUT 
               ,@c_ErrMsg                = @c_errmsg OUTPUT          
            
             IF @b_Success <> 1 
             BEGIN
                SELECT @n_continue = 3  
             END
            
              SET @n_TotCtn = @n_TotCtn - 1
           END
                        
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @n_CaseCnt
      END 
      CLOSE cur_pick  
      DEALLOCATE cur_pick                                                
   END        
   
   -----Swap pickdetail lot for non-robot pick
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
        IF @b_debug = 1                                                                  
         PRINT 'Swap pickdetail lot for pick face' 
      
        --Retrieve the skuxloc for the load having multiple lots overallocated.
        DECLARE CUR_SKUXLOC_MULTILOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT LLI.Storerkey, LLI.SKU, LLI.Loc
           FROM LOTXLOCXID LLI (NOLOCK)
         JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc         
           JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         WHERE SL.LocationType IN ('PICK','CASE')
         AND LOC.Facility = @c_Facility
         AND LLI.QtyExpected > 0
         AND EXISTS(SELECT 1 
                    FROM PICKDETAIL PD (NOLOCK)
                    JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.Orderkey = LPD.Orderkey
                    WHERE LPD.Loadkey = @c_Loadkey
                    AND PD.Storerkey = LLI.Storerkey
                    AND PD.Sku = LLI.Sku
                    AND PD.Loc = LLI.Loc)                
         GROUP BY LLI.Storerkey, LLI.SKU, LLI.Loc            
         HAVING COUNT(DISTINCT LLI.Lot) > 1
      
      OPEN CUR_SKUXLOC_MULTILOT
      
      FETCH FROM CUR_SKUXLOC_MULTILOT INTO @c_Storerkey, @c_Sku, @c_Loc
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
        IF @b_debug = 1                                                                  
           PRINT 'Pick Face @c_Sku:' + RTRIM(@c_Sku) + ' @c_Loc:' + RTRIM(@c_Loc) 

          --Retrieve pendingmove and qtyexpected for all the lots from pick. Qty available for the lot.
          DELETE FROM #TMP_LOTMOVEIN          
             SELECT LLI.LOT, SUM(LLI.PendingMoveIn), SUM(LLI.QtyExpected), ISNULL(LOT.LotQtyAvailable,0) - ISNULL(ROBOTLOT.RobotQtyAvailable,0) , 'N' --NJOW02
             FROM LOTXLOCXID LLI(NOLOCK)
            JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc         
             JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
             LEFT JOIN (SELECT LLI.Lot, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS LotQtyAvailable 
                       FROM LOTXLOCXID LLI (NOLOCK)          
                       JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
                       JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
                       JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                       JOIN ID (NOLOCK) ON LLI.Id = ID.Id
                       WHERE LOT.STATUS = 'OK'  
                       AND LOC.STATUS = 'OK' 
                       AND ID.STATUS = 'OK'  
                       AND LOC.LocationFlag = 'NONE' 
                       AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) <> 0
                       AND LLI.Storerkey = @c_Storerkey
                       AND LLI.Sku = @c_SKU
                       AND LOC.Facility = @c_Facility
                       GROUP BY LLI.Lot) AS LOT ON LLI.Lot = LOT.Lot     
            LEFT JOIN (SELECT LLI.Lot, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS RobotQtyAvailable      
                       FROM LOTXLOCXID LLI (NOLOCK)
                       JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                       WHERE LOC.LocationCategory = 'ROBOT'
                       AND LLI.Storerkey = @c_Storerkey
                       AND LLI.Sku = @c_SKU 
                       AND LOC.Facility = @c_Facility
                       AND LOC.STATUS = 'OK' 
                       AND LOC.LocationFlag = 'NONE' 
                       GROUP BY LLI.Lot
                       HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0) AS ROBOTLOT ON LLI.Lot = ROBOTLOT.Lot                        
             WHERE LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
            AND SL.LocationType IN ('PICK','CASE')
            AND LOC.Facility = @c_Facility            
             AND (LLI.QtyExpected > 0 OR LLI.PendingMoveIn > 0)
             GROUP BY LLI.Lot, ISNULL(LOT.LotQtyAvailable,0), ISNULL(ROBOTLOT.RobotQtyAvailable,0) --LOT.Qty, LOT.QtyAllocated, LOT.QtyPicked  --NJOW02
             
          /*INSERT INTO #TMP_LOTMOVEIN (Lot, PendingMoveIn, QtyExpected, QtyAvailable, Targeted)
             SELECT LLI.LOT, SUM(LLI.PendingMoveIn), SUM(LLI.QtyExpected), (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked), 'N'
             FROM LOTXLOCXID LLI(NOLOCK)
            JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc         
             JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
             JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
             WHERE LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
            AND SL.LocationType IN ('PICK','CASE')
            AND LOC.Facility = @c_Facility            
             AND (LLI.QtyExpected > 0 OR LLI.PendingMoveIn > 0)
             GROUP BY LLI.Lot, LOT.Qty, LOT.QtyAllocated, LOT.QtyPicked*/
             
                  
          --Swap pickdetail lot&id to other available lot of same loc
          DECLARE CUR_LOT_Expected CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT LLI.LOT, LLI.ID, LLI.QtyExpected
             FROM LOTXLOCXID LLI(NOLOCK)
             JOIN #TMP_LOTMOVEIN LM (NOLOCK) ON LLI.Lot = LM.Lot
              LEFT JOIN PICKDETAIL PD (NOLOCK) ON LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.ID = PD.Id AND PD.Status >= '3'  
             WHERE LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
             AND LLI.Loc = @c_Loc
             AND LLI.QtyExpected > 0
             AND LM.QtyExpected - LM.PendingMoveIn > 0 --exclude lot already waiting replenish      
             GROUP BY LLI.Lot, LLI.ID, LLI.QtyExpected, LLI.Qty, LM.QtyExpected, LM.PendingMoveIn, LLI.QtyPicked, PD.Lot
             ORDER BY CASE WHEN PD.Lot IS NULL THEN 1 WHEN MAX(ISNULL(PD.Status,'')) < '5' THEN 2 ELSE 3 END, CASE WHEN LM.PendingMoveIn = 0 THEN 1 ELSE 2 END, LLI.Qty, LLI.Lot DESC, LLI.ID
             --ORDER BY CASE WHEN PD.Lot IS NULL THEN 1 ELSE 2 END, CASE WHEN LM.PendingMoveIn = 0 THEN 1 ELSE 2 END, LLI.Qty, LLI.Lot DESC, LLI.ID

         OPEN CUR_LOT_Expected
         
         FETCH FROM CUR_LOT_Expected INTO @c_Lot, @c_ID, @n_QtyExpected
         
         SET @c_TargetLot = ''
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
         BEGIN
              IF @b_debug = 1                                                                  
                 PRINT 'EXP LOT @c_Lot:' + RTRIM(@c_Lot) + ' @c_ID:' + RTRIM(@c_ID) +  ' @n_QtyExpected:' + CAST(@n_QtyExpected AS NVARCHAR)
                 
              IF EXISTS (SELECT 1 FROM #TMP_LOTMOVEIN WHERE Lot = @c_Lot AND Targeted = 'Y')
                 GOTO NEXT_LOT_REC
            
            WHILE @n_QtyExpected > 0 
            BEGIN
                SET @c_LotAvailable = ''
                SET @n_QtyAvailable = 0
                SET @c_IDAvailable = ''
                            
                 SELECT TOP 1 @c_LotAvailable = LLI.Lot,
                              @c_IDAvailable = LLI.Id, 
                              @n_QtyAvailable = LM.QtyAvailable
                 FROM LOTXLOCXID LLI (NOLOCK)
                 JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
                 JOIN #TMP_LOTMOVEIN LM (NOLOCK) ON LOT.Lot = LM.Lot
               LEFT JOIN PICKDETAIL PD (NOLOCK) ON LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.ID = PD.Id AND PD.Status >= '3'  
                 WHERE LLI.Storerkey = @c_Storerkey
                 AND LLI.Sku = @c_Sku
                 AND LLI.Loc = @c_Loc
                 AND LLI.Lot <> @c_Lot
                 AND (LLI.Lot = @c_TargetLot OR @c_TargetLot = '')
                 AND LLI.QtyExpected > 0 
                 AND LM.QtyAvailable > 0
                 ORDER BY CASE WHEN ISNULL(PD.Status,'') >= '5' THEN 1 WHEN ISNULL(PD.Status,'') IN('3','4') THEN 2 ELSE 3 END, CASE WHEN LM.PendingMoveIn > 0 THEN 1 ELSE 2 END,
                          LM.QtyAvailable DESC,                         
                          CASE WHEN LLI.Qty > 0 THEN 1 ELSE 2 END, LLI.Lot, LLI.Id
                 --ORDER BY CASE WHEN PD.Lot IS NOT NULL THEN 1 ELSE 2 END, CASE WHEN LM.PendingMoveIn > 0 THEN 1 ELSE 2 END,
                 --         LM.QtyAvailable DESC,                       
                 --         CASE WHEN LLI.Qty > 0 THEN 1 ELSE 2 END, LLI.Lot, LLI.Id
                                  
                 IF ISNULL(@C_LotAvailable,'') <> ''
                 BEGIN
                    IF @c_TargetLot = ''
                       SET @c_TargetLot = @c_LotAvailable
                       
                    IF @n_QtyAvailable >= @n_QtyExpected    
                      SET @n_QtySwap = @n_QtyExpected
                    ELSE
                    BEGIN
                       SET @n_QtySwap = @n_QtyAvailable
                       SET @c_TargetLot = ''
                    END

                    SET @n_QtyExpected = @n_QtyExpected - @n_QtySwap           

                   IF @b_debug = 1                                                                   
                      PRINT 'Target LOT @c_LotAvailable:' + RTRIM(@c_LotAvailable) + ' @c_IDAvailable:' + RTRIM(@c_IDAvailable) + ' @n_QtyAvailable:' + CAST(@n_QtyAvailable AS NVARCHAR) + ' @n_QtySwap:' + CAST(@n_QtySwap AS NVARCHAR)
                    
                    -----UPDATE PICKDETAIL                    
                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                      SET @n_QtyBal = @n_QtySwap
                      
                     INSERT INTO PickDetail_WIP 
                      (
                        PickDetailKey,      CaseID,             PickHeaderKey,
                        OrderKey,           OrderLineNumber, Lot,
                        Storerkey,          Sku,                AltSku,     UOM,
                        UOMQty,              Qty,               QtyMoved,   [Status],
                        DropID,              Loc,             ID,        PackKey,
                        UpdateSource,       CartonGroup,     CartonType,
                        ToLoc,               DoReplenish,     ReplenishZone,
                        DoCartonize,        PickMethod,      WaveKey,
                        EffectiveDate,      AddDate,         AddWho,
                        EditDate,           EditWho,         TrafficCop,
                        ArchiveCop,         OptimizeCop,     ShipFlag,
                        PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,
                        Notes,               MoveRefKey,        WIP_RefNo
                      )
                      SELECT PD.PickDetailKey,  CaseID,                    PD.PickHeaderKey, 
                        PD.OrderKey,                PD.OrderLineNumber,  PD.Lot,
                        PD.Storerkey,               PD.Sku,             PD.AltSku,        PD.UOM,
                        PD.UOMQty,                  PD.Qty,             PD.QtyMoved,      PD.[Status],
                        PD.DropID,                  PD.Loc,             PD.ID,             PD.PackKey,
                        PD.UpdateSource,            PD.CartonGroup,      PD.CartonType,
                        PD.ToLoc,                   PD.DoReplenish,      PD.ReplenishZone,
                        PD.DoCartonize,             PD.PickMethod,       PD.Wavekey,
                        PD.EffectiveDate,           PD.AddDate,           PD.AddWho,
                        PD.EditDate,                PD.EditWho,           PD.TrafficCop,
                        PD.ArchiveCop,              PD.OptimizeCop,      PD.ShipFlag,
                        PD.PickSlipNo,              PD.TaskDetailKey,    PD.TaskManagerReasonKey,
                        PD.Notes,                   PD.MoveRefKey,       @c_SourceType 
                      FROM LOADPLANDETAIL LD (NOLOCK) 
                      JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
                      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc                      
                      WHERE LD.Loadkey <> @c_Loadkey       
                      AND PD.Lot = @c_Lot                       
                      AND PD.Loc = @c_Loc                       
                      AND PD.Id = @c_ID     
                      AND PD.Status NOT IN('4','9')              
                      AND NOT EXISTS(SELECT 1 FROM PickDetail_WIP WHERE PickDetail_WIP.WIP_RefNo = @c_SourceType AND PD.Pickdetailkey = PickDetail_WIP.Pickdetailkey)      
                                                 
                     DECLARE CUR_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                        SELECT PD.Pickdetailkey, PD.Qty
                        FROM PICKDETAIL_WIP PD (NOLOCK)
                        WHERE PD.WIP_RefNo = @c_SourceType          
                        AND PD.Lot = @c_Lot
                        AND PD.Loc = @c_Loc
                        AND PD.Id = @c_ID
                        ORDER BY PD.Status, CASE WHEN PD.UOM = '7' THEN 1 ELSE 2 END              
                     
                     OPEN CUR_Pick  
                     
                     FETCH NEXT FROM CUR_Pick INTO @c_Pickdetailkey, @n_PickQty
                     
                     WHILE @@FETCH_STATUS = 0 AND @n_QtyBal > 0 AND @n_continue IN(1,2) 
                     BEGIN            
                          IF @b_debug = 1                                                                  
                             PRINT 'Swap Pick @c_Pickdetailkey:' + RTRIM(@c_Pickdetailkey) + ' @n_PickQty:' + CAST(@n_PickQty AS NVARCHAR)
                        
                        IF @n_PickQty <= @n_QtyBal
                        BEGIN
                            UPDATE PICKDETAIL_WIP WITH (ROWLOCK)
                            SET Qty = 0,
                                TrafficCop = 'N'
                            FROM PICKDETAIL_WIP
                           WHERE PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
                           AND PICKDETAIL_WIP.Pickdetailkey = @c_Pickdetailkey                           
                                                       
                           SELECT @n_err = @@ERROR

                           IF @n_err <> 0 
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   
                              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                              BREAK
                          END 

                          EXECUTE nspg_GetKey      
                             'PICKDETAILKEY',      
                             10,      
                             @c_NewPickdetailKey OUTPUT,         
                             @b_success OUTPUT,      
                             @n_err OUTPUT,      
                             @c_errmsg OUTPUT      
                        
                          IF NOT @b_success = 1      
                          BEGIN
                             SELECT @n_continue = 3      
                          END                  

                          INSERT INTO PICKDETAIL_WIP 
                                     (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                      Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                      DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                      WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                      TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo, TrafficCop)               
                          SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_LotAvailable,                                      
                                 Storerkey, Sku, AltSku, UOM,  UOMQty, @n_PickQty, QtyMoved, Status,       
                                 DropID, @c_Loc, @c_IDAvailable, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                               
                                 WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                                 TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo, 'N'                                          
                          FROM PICKDETAIL_WIP (NOLOCK)                                                                                             
                          WHERE PickdetailKey = @c_PickdetailKey 

                          SELECT @n_QtyBal = @n_QtyBal - @n_PickQty
                        END
                        ELSE
                        BEGIN  -- pickqty > n_QtyBal   
                           SELECT @n_SplitQty = @n_PickQty - @n_QtyBal
                           
                           EXECUTE nspg_GetKey      
                              'PICKDETAILKEY',      
                              10,      
                              @c_NewPickdetailKey OUTPUT,         
                              @b_success OUTPUT,      
                              @n_err OUTPUT,      
                              @c_errmsg OUTPUT      
                        
                           IF NOT @b_success = 1      
                           BEGIN
                              SELECT @n_continue = 3      
                           END                  
                           
                           INSERT INTO PICKDETAIL_WIP (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                                       TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo, TrafficCop)               
                                            SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_LotAvailable,                                      
                                                   Storerkey, Sku, AltSku, UOM, UOMQty, @n_QtyBal, QtyMoved, Status,       
                                                   DropID, @c_Loc, @c_IDAvailable, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                                   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                               
                                                   WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                                                   TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo, 'N'                                                           
                                            FROM PICKDETAIL_WIP (NOLOCK)                                                                                             
                                            WHERE PickdetailKey = @c_PickdetailKey
           
                                              
                           SELECT @n_err = @@ERROR
                           
                           IF @n_err <> 0     
                           BEGIN     
                              SELECT @n_continue = 3      
                              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   
                              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                              BREAK    
                           END
                           
                            UPDATE PICKDETAIL_WIP WITH (ROWLOCK)
                            SET Qty = @n_SplitQty,
                                TrafficCop = 'N'                            
                            FROM PICKDETAIL_WIP
                           WHERE PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
                           AND PICKDETAIL_WIP.Pickdetailkey = @c_Pickdetailkey
                                                       
                           SELECT @n_err = @@ERROR

                           IF @n_err <> 0 
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   
                              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                              BREAK
                          END 
                                          
                           SELECT @n_QtyBal = 0
                        END     
                     
                        FETCH NEXT FROM CUR_Pick INTO @c_Pickdetailkey, @n_PickQty
                     END -- While QtyBal > 0
                     CLOSE CUR_Pick
                     DEALLOCATE CUR_Pick
                  END        
                    
                    UPDATE #TMP_LOTMOVEIN 
                    SET QtyAvailable = QtyAvailable - @n_QtySwap,
                        QtyExpected = QtyExpected + @n_QtySwap,
                        Targeted = 'Y'   
                    WHERE Lot = @C_LotAvailable                                                          
                 END
                 ELSE
                 BEGIN
                    SET @c_TargetLot = ''
                    BREAK
                 END
              END
               
            NEXT_LOT_REC:
             
            FETCH FROM CUR_LOT_Expected INTO @c_Lot, @c_ID, @n_QtyExpected
         END
         CLOSE CUR_LOT_Expected
         DEALLOCATE CUR_LOT_Expected
          
         FETCH FROM CUR_SKUXLOC_MULTILOT INTO @c_Storerkey, @c_Sku, @c_Loc
      END
      CLOSE CUR_SKUXLOC_MULTILOT
      DEALLOCATE CUR_SKUXLOC_MULTILOT                   
   END    
   
   -----Create replenishment task for non-robot pick   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
       --Retrieve all lot of the load from pick loc
      SELECT DISTINCT LLI.Lot             
      INTO #TMP_LOADPICKLOT
      FROM PICKDETAIL PD (NOLOCK)
      JOIN SKUXLOC SXL (NOLOCK) ON PD.Storerkey = SXL.Storerkey AND PD.Sku = SXL.Sku AND PD.Loc = SXL.Loc
      JOIN LOTXLOCXID LLI (NOLOCK) ON PD.Storerkey = LLI.Storerkey AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.Loc = LLI.Loc AND PD.ID = LLI.ID
      JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
      WHERE O.Loadkey = @c_Loadkey
      AND SXL.LocationType IN('PICK','CASE')        
      AND LLI.QtyExpected > 0
                         
       --Retreive pick loc with overallocated
      DECLARE cur_PickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) AS Qty,
                PACK.CaseCnt
         FROM LOTXLOCXID LLI (NOLOCK)          
         JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         JOIN #TMP_LOADPICKLOT ON LLI.Lot = #TMP_LOADPICKLOT.Lot 
         WHERE SL.LocationType IN('PICK','CASE')
         AND LLI.Storerkey = @c_Storerkey
         AND LOC.Facility = @c_Facility       
         GROUP BY LLI.Storerkey, LLI.Sku, LLI.Lot, LLI.Loc, LLI.Id, PACK.CaseCnt 
         HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked + LLI.PendingMoveIn) < 0  --overallocate

      OPEN cur_PickLoc
      
      FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN                           
          SET @c_Message03 = 'PICKLOC' 
          SET @c_Priority = '9'
          SET @c_PickMethod = 'PP'
         
           IF @n_QtyShort < 0
              SET @n_QtyShort = @n_QtyShort * -1
              
           SET @n_QtyReplen = @n_QtyShort   
           
           --retrieve stock from bulk 
         DECLARE cur_Bulk CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT LLI.Lot, LLI.Loc, LLI.Id, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) AS QtyAvailable
            FROM LOTXLOCXID LLI (NOLOCK)          
            JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
            JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
            JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
            JOIN ID (NOLOCK) ON LLI.Id = ID.Id
            WHERE SL.LocationType NOT IN('PICK','CASE')
            AND LOC.LocationType NOT IN ('ROBOTSTG','DYNPPICK','DYNPICKP','PICK')
            AND LOC.LocationCategory NOT IN('ROBOT')            
            AND LOT.STATUS = 'OK' 
            AND LOC.STATUS = 'OK' 
            AND ID.STATUS = 'OK'  
            AND LOC.LocationFlag = 'NONE' 
            AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
            AND LLI.Storerkey = @c_Storerkey
            AND LLI.Sku = @c_Sku
            AND LLI.Lot = @c_Lot
            AND LOC.Facility = @c_Facility  --NJOW01
            ORDER BY LOC.LocationGroup, LOC.Loclevel, QtyAvailable, LOC.Logicallocation, LOC.Loc
            
         OPEN cur_Bulk
        
         FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_QtyReplen > 0             
         BEGIN          
            IF @n_QtyAvailable >= @n_QtyReplen             
               SET @n_TotCtn = CEILING(@n_QtyReplen / (@n_CaseCnt * 1.00))
            ELSE
               SET @n_TotCtn = CEILING(@n_QtyAvailable / (@n_CaseCnt * 1.00))  --(Wan01)
               --SET @n_TotCtn = FLOOR(@n_QtyAvailable / (@n_CaseCnt * 1.00))  --(Wan01) 
            
             WHILE @n_TotCtn > 0 AND @n_QtyReplen > 0 AND @n_continue IN(1,2)             
             BEGIN
                 IF @n_QtyReplen >= @n_CaseCnt
                    SET @n_InsertQty = @n_CaseCnt
                 ELSE
                    SET @n_InsertQty = @n_QtyReplen
                    
                 IF @n_QtyAvailable >= @n_CaseCnt
                    SET @n_Qty = @n_CaseCnt
                 ELSE   
                    SET @n_Qty = @n_QtyAvailable    
                                      
                 SET @n_QtyReplen = @n_QtyReplen - @n_InsertQty
                 SET @n_QtyAvailable = @n_QtyAvailable - @n_Qty
                           
                EXEC isp_InsertTaskDetail   
                   @c_TaskType              = @c_TaskType             
                  ,@c_Storerkey             = @c_Storerkey
                  ,@c_Sku                   = @c_Sku
                  ,@c_Lot                   = @c_Lot 
                  ,@c_UOM                   = '2'      
                  ,@n_UOMQty                = @n_InsertQty     
                  ,@n_Qty                   = @n_Qty      
                  ,@c_FromLoc               = @c_Fromloc      
                  ,@c_LogicalFromLoc        = @c_FromLoc 
                  ,@c_FromID                = @c_ID     
                  ,@c_ToLoc                 = @c_ToLoc       
                  ,@c_LogicalToLoc          = @c_ToLoc 
                  ,@c_ToID                  = @c_ToID       
                  ,@c_PickMethod            = @c_PickMethod
                  ,@c_Priority              = @c_Priority     
                  ,@c_SourcePriority        = '9'      
                  ,@c_CallSource            = 'LOADPLAN'
                  ,@c_SourceType            = @c_SourceType      
                  ,@c_SourceKey             = @c_Loadkey      
                  ,@c_LoadKey               = @c_Loadkey      
                  ,@c_AreaKey               = '?F'      -- ?F=Get from location areakey 
                  ,@c_Message03             = 'PICKLOC'
                  ,@n_SystemQty             = -1        -- if systemqty is zero/not provided it always copy from @n_Qty as default. if want to force it to zero, pass in negative value e.g. -1
                  --,@c_RoundUpQty            = 'FC'      -- FC=Round up qty to full carton by packkey
                  ,@n_QtyReplen             = @n_Qty --NJOW02
                  ,@c_ReserveQtyReplen      = 'TASKQTY' -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid 
                  ,@c_ReservePendingMoveIn  =  'Y'      -- Y=Update @n_qty to @n_PendingMoveIn
                  ,@b_Success               = @b_Success OUTPUT
                  ,@n_Err                   = @n_err OUTPUT 
                  ,@c_ErrMsg                = @c_errmsg OUTPUT          
                            
               IF @b_Success <> 1 
               BEGIN
                  SELECT @n_continue = 3  
               END

                 SET @n_TotCtn = @n_TotCtn - 1                
            END
             
            FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable
         END
         CLOSE cur_Bulk
         DEALLOCATE cur_Bulk
         
         FETCH FROM cur_PickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyShort, @n_CaseCnt
      END
      CLOSE cur_PickLoc
      DEALLOCATE cur_PickLoc          
   END    

   -----Swap pickdetail lot for robot pick   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
        IF @b_debug = 1                                                                  
         PRINT 'Swap pickdetail lot for robot pick' 
        --Retrieve the skuxloc for the load having multiple lots overallocated.
        DECLARE CUR_SKUXLOC_MULTILOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT LLI.Storerkey, LLI.SKU, LLI.Loc
           FROM LOTXLOCXID LLI (NOLOCK)
           JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         WHERE LOC.LocationType IN ('DYNPPICK','DYNPICKP')
         AND LOC.LocationCategory = 'ROBOT'
         AND LOC.Facility = @c_Facility
         AND LLI.QtyExpected > 0
         AND EXISTS(SELECT 1 
                    FROM PICKDETAIL PD (NOLOCK)
                    JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.Orderkey = LPD.Orderkey
                    WHERE LPD.Loadkey = @c_Loadkey
                    AND PD.Storerkey = LLI.Storerkey
                    AND PD.Sku = LLI.Sku
                    AND PD.Loc = LLI.Loc)                
         GROUP BY LLI.Storerkey, LLI.SKU, LLI.Loc            
         HAVING COUNT(DISTINCT LLI.Lot) > 1
      
      OPEN CUR_SKUXLOC_MULTILOT
       
      FETCH FROM CUR_SKUXLOC_MULTILOT INTO @c_Storerkey, @c_Sku, @c_Loc
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
           IF @b_debug = 1                                                                  
              PRINT 'Robot Pick @c_Sku:' + RTRIM(@c_Sku) + ' @c_Loc:' + RTRIM(@c_Loc) 
  
          --Retrieve pendingmove and qtyexpected for all the lots from robot pick and robot staging. Qty available for the lot.
          DELETE FROM #TMP_LOTMOVEIN
          INSERT INTO #TMP_LOTMOVEIN (Lot, PendingMoveIn, QtyExpected, QtyAvailable, Targeted)
             SELECT LLI.LOT, SUM(LLI.PendingMoveIn), SUM(LLI.QtyExpected), ISNULL(LOT.LotQtyAvailable,0), 'N' --NJOW02
             FROM LOTXLOCXID LLI(NOLOCK)
             JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
             LEFT JOIN (SELECT LLI.Lot, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS LotQtyAvailable 
                       FROM LOTXLOCXID LLI (NOLOCK)          
                       JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
                       JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
                       JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                       JOIN ID (NOLOCK) ON LLI.Id = ID.Id
                       WHERE LOT.STATUS = 'OK' 
                       AND LOC.STATUS = 'OK' 
                       AND ID.STATUS = 'OK'  
                       AND LOC.LocationFlag = 'NONE' 
                       AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) <> 0
                       AND LLI.Storerkey = @c_Storerkey
                       AND LLI.Sku = @c_SKU
                       AND LOC.Facility = @c_Facility
                       GROUP BY LLI.Lot) AS LOT ON LLI.Lot = LOT.Lot           
             WHERE LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
            AND LOC.LocationType IN ('DYNPPICK','DYNPICKP','ROBOTSTG')
            AND LOC.LocationCategory = 'ROBOT'
            AND LOC.Facility = @c_Facility            
             AND (LLI.QtyExpected > 0 OR LLI.PendingMoveIn > 0)
             GROUP BY LLI.Lot, ISNULL(LOT.LotQtyAvailable,0) --NJOW02
             
             /*SELECT LLI.LOT, SUM(LLI.PendingMoveIn), SUM(LLI.QtyExpected), (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked), 'N'
             FROM LOTXLOCXID LLI(NOLOCK)
             JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
             JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
             WHERE LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
            AND LOC.LocationType IN ('DYNPPICK','DYNPICKP','ROBOTSTG')
            AND LOC.LocationCategory = 'ROBOT'
            AND LOC.Facility = @c_Facility            
             AND (LLI.QtyExpected > 0 OR LLI.PendingMoveIn > 0)
             GROUP BY LLI.Lot, LOT.Qty, LOT.QtyAllocated, LOT.QtyPicked*/            
                  
          --Swap pickdetail lot&id to other available lot of same loc
          DECLARE CUR_LOT_Expected CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT LLI.LOT, LLI.ID, LLI.QtyExpected
             FROM LOTXLOCXID LLI(NOLOCK)            
             JOIN #TMP_LOTMOVEIN LM (NOLOCK) ON LLI.Lot = LM.Lot
             LEFT JOIN PICKDETAIL PD (NOLOCK) ON LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.ID = PD.Id AND PD.Status >= '3'  
             WHERE LLI.Storerkey = @c_Storerkey
             AND LLI.Sku = @c_Sku
             AND LLI.Loc = @c_Loc
             AND LLI.QtyExpected > 0
             AND LM.QtyExpected - LM.PendingMoveIn > 0 --exclude lot already waiting replenish      
             GROUP BY LLI.Lot, LLI.ID, LLI.QtyExpected, LLI.Qty, LM.QtyExpected, LM.PendingMoveIn, LLI.QtyPicked, PD.Lot
             ORDER BY CASE WHEN PD.Lot IS NULL THEN 1 WHEN MAX(ISNULL(PD.Status,'')) < '5' THEN 2 ELSE 3 END, CASE WHEN LM.PendingMoveIn = 0 THEN 1 ELSE 2 END, LLI.Qty, LLI.Lot DESC, LLI.ID

         OPEN CUR_LOT_Expected
         
         FETCH FROM CUR_LOT_Expected INTO @c_Lot, @c_ID, @n_QtyExpected
         
         SET @c_TargetLot = ''
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
         BEGIN                                                              
              IF @b_debug = 1                                                                  
                 PRINT 'EXP LOT @c_Lot:' + RTRIM(@c_Lot) + ' @c_ID:' + RTRIM(@c_ID) +  ' @n_QtyExpected:' + CAST(@n_QtyExpected AS NVARCHAR)

              IF EXISTS (SELECT 1 FROM #TMP_LOTMOVEIN WHERE Lot = @c_Lot AND Targeted = 'Y')
                 GOTO NEXT_LOT
            
            WHILE @n_QtyExpected > 0 
            BEGIN
                SET @c_LotAvailable = ''
                SET @n_QtyAvailable = 0
                SET @c_IDAvailable = ''
                            
                 SELECT TOP 1 @c_LotAvailable = LLI.Lot,
                              @c_IDAvailable = LLI.Id, 
                              @n_QtyAvailable = LM.QtyAvailable
                 FROM LOTXLOCXID LLI (NOLOCK)
                 JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
                 JOIN #TMP_LOTMOVEIN LM (NOLOCK) ON LOT.Lot = LM.Lot
                 LEFT JOIN PICKDETAIL PD (NOLOCK) ON LLI.Lot = PD.Lot AND LLI.Loc = PD.Loc AND LLI.ID = PD.Id AND PD.Status >= '3'  
                 WHERE LLI.Storerkey = @c_Storerkey
                 AND LLI.Sku = @c_Sku
                 AND LLI.Loc = @c_Loc
                 AND LLI.Lot <> @c_Lot
                 AND (LLI.Lot = @c_TargetLot OR @c_TargetLot = '')
                 AND LLI.QtyExpected > 0 
                 AND LM.QtyAvailable > 0
                 ORDER BY CASE WHEN ISNULL(PD.Status,'') >= '5' THEN 1 WHEN ISNULL(PD.Status,'') IN('3','4') THEN 2 ELSE 3 END, CASE WHEN LM.PendingMoveIn > 0 THEN 1 ELSE 2 END,
                          LM.QtyAvailable DESC,                         
                          CASE WHEN LLI.Qty > 0 THEN 1 ELSE 2 END, LLI.Lot, LLI.Id
                                  
                 IF ISNULL(@C_LotAvailable,'') <> ''
                 BEGIN
                    IF @c_TargetLot = ''
                       SET @c_TargetLot = @c_LotAvailable
                       
                    IF @n_QtyAvailable >= @n_QtyExpected    
                      SET @n_QtySwap = @n_QtyExpected
                    ELSE
                    BEGIN
                       SET @n_QtySwap = @n_QtyAvailable
                       SET @c_TargetLot = ''
                    END

                    SET @n_QtyExpected = @n_QtyExpected - @n_QtySwap           

                   IF @b_debug = 1                                                                   
                      PRINT 'Target LOT @c_LotAvailable:' + RTRIM(@c_LotAvailable) + ' @c_IDAvailable:' + RTRIM(@c_IDAvailable) + ' @n_QtyAvailable:' + CAST(@n_QtyAvailable AS NVARCHAR) + ' @n_QtySwap:' + CAST(@n_QtySwap AS NVARCHAR)
                    
                    -----UPDATE PICKDETAIL                    
                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                      SET @n_QtyBal = @n_QtySwap
                      
                     INSERT INTO PickDetail_WIP 
                      (
                        PickDetailKey,      CaseID,             PickHeaderKey,
                        OrderKey,           OrderLineNumber, Lot,
                        Storerkey,          Sku,                AltSku,     UOM,
                        UOMQty,              Qty,               QtyMoved,   [Status],
                        DropID,              Loc,             ID,        PackKey,
                        UpdateSource,       CartonGroup,     CartonType,
                        ToLoc,               DoReplenish,     ReplenishZone,
                        DoCartonize,        PickMethod,      WaveKey,
                        EffectiveDate,      AddDate,         AddWho,
                        EditDate,           EditWho,         TrafficCop,
                        ArchiveCop,         OptimizeCop,     ShipFlag,
                        PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,
                        Notes,               MoveRefKey,        WIP_RefNo
                      )
                      SELECT PD.PickDetailKey,  CaseID,                    PD.PickHeaderKey, 
                        PD.OrderKey,                PD.OrderLineNumber,  PD.Lot,
                        PD.Storerkey,               PD.Sku,             PD.AltSku,        PD.UOM,
                        PD.UOMQty,                  PD.Qty,             PD.QtyMoved,      PD.[Status],
                        PD.DropID,                  PD.Loc,             PD.ID,             PD.PackKey,
                        PD.UpdateSource,            PD.CartonGroup,      PD.CartonType,
                        PD.ToLoc,                   PD.DoReplenish,      PD.ReplenishZone,
                        PD.DoCartonize,             PD.PickMethod,       PD.Wavekey,
                        PD.EffectiveDate,           PD.AddDate,           PD.AddWho,
                        PD.EditDate,                PD.EditWho,           PD.TrafficCop,
                        PD.ArchiveCop,              PD.OptimizeCop,      PD.ShipFlag,
                        PD.PickSlipNo,              PD.TaskDetailKey,    PD.TaskManagerReasonKey,
                        PD.Notes,                   PD.MoveRefKey,       @c_SourceType 
                      FROM LOADPLANDETAIL LD (NOLOCK) 
                      JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
                      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc                      
                      WHERE LD.Loadkey <> @c_Loadkey       
                      AND PD.Lot = @c_Lot                       
                      AND PD.Loc = @c_Loc                       
                      AND PD.Id = @c_ID     
                      AND PD.Status NOT IN('4','9')              
                      AND NOT EXISTS(SELECT 1 FROM PickDetail_WIP WHERE PickDetail_WIP.WIP_RefNo = @c_SourceType AND PD.Pickdetailkey = PickDetail_WIP.Pickdetailkey)      
                                                 
                     DECLARE CUR_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                        SELECT PD.Pickdetailkey, PD.Qty
                        FROM PICKDETAIL_WIP PD (NOLOCK)
                        WHERE PD.WIP_RefNo = @c_SourceType          
                        AND PD.Lot = @c_Lot
                        AND PD.Loc = @c_Loc
                        AND PD.Id = @c_ID
                        ORDER BY PD.Status, CASE WHEN PD.UOM = '7' THEN 1 ELSE 2 END              
                     
                     OPEN CUR_Pick  
                     
                     FETCH NEXT FROM CUR_Pick INTO @c_Pickdetailkey, @n_PickQty
                     
                     WHILE @@FETCH_STATUS = 0 AND @n_QtyBal > 0 AND @n_continue IN(1,2) 
                     BEGIN                                  
                        IF @b_debug = 1                                                                    
                             PRINT 'Swap Pick @c_Pickdetailkey:' + RTRIM(@c_Pickdetailkey) + ' @n_PickQty:' + CAST(@n_PickQty AS NVARCHAR)
                        
                        IF @n_PickQty <= @n_QtyBal
                        BEGIN
                            UPDATE PICKDETAIL_WIP WITH (ROWLOCK)
                            SET Qty = 0,
                                TrafficCop = 'N'
                            FROM PICKDETAIL_WIP
                           WHERE PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
                           AND PICKDETAIL_WIP.Pickdetailkey = @c_Pickdetailkey                           
                                                       
                           SELECT @n_err = @@ERROR

                           IF @n_err <> 0 
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   
                              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                              BREAK
                          END 

                          EXECUTE nspg_GetKey      
                             'PICKDETAILKEY',      
                             10,      
                             @c_NewPickdetailKey OUTPUT,         
                             @b_success OUTPUT,      
                             @n_err OUTPUT,      
                             @c_errmsg OUTPUT      
                        
                          IF NOT @b_success = 1      
                          BEGIN
                             SELECT @n_continue = 3      
                          END                  

                          INSERT INTO PICKDETAIL_WIP 
                                     (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                      Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                      DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                      WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                      TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo, TrafficCop)               
                          SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_LotAvailable,                                      
                                 Storerkey, Sku, AltSku, UOM,  UOMQty, @n_PickQty, QtyMoved, Status,       
                                 DropID, @c_Loc, @c_IDAvailable, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                               
                                 WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                                 TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo, 'N'                                          
                          FROM PICKDETAIL_WIP (NOLOCK)                                                                                             
                          WHERE PickdetailKey = @c_PickdetailKey 

                          SELECT @n_QtyBal = @n_QtyBal - @n_PickQty
                        END
                        ELSE
                        BEGIN  -- pickqty > n_QtyBal   
                           SELECT @n_SplitQty = @n_PickQty - @n_QtyBal
                           
                           EXECUTE nspg_GetKey      
                              'PICKDETAILKEY',      
                              10,      
                              @c_NewPickdetailKey OUTPUT,         
                              @b_success OUTPUT,      
                              @n_err OUTPUT,      
                              @c_errmsg OUTPUT      
                        
                           IF NOT @b_success = 1      
                           BEGIN
                              SELECT @n_continue = 3      
                           END                  
                           
                           INSERT INTO PICKDETAIL_WIP (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                                                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                                                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                                                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                                                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                                                       TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo, TrafficCop)               
                                            SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_LotAvailable,                                      
                                                   Storerkey, Sku, AltSku, UOM, UOMQty, @n_QtyBal, QtyMoved, Status,       
                                                   DropID, @c_Loc, @c_IDAvailable, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                                                   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                               
                                                   WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                                                   TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_RefNo, 'N'                                                           
                                            FROM PICKDETAIL_WIP (NOLOCK)                                                                                             
                                            WHERE PickdetailKey = @c_PickdetailKey
                                                         
                           SELECT @n_err = @@ERROR
                           
                           IF @n_err <> 0     
                           BEGIN     
                              SELECT @n_continue = 3      
                              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   
                              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                              BREAK    
                           END
                           
                            UPDATE PICKDETAIL_WIP WITH (ROWLOCK)
                            SET Qty = @n_SplitQty,
                                TrafficCop = 'N'                            
                            FROM PICKDETAIL_WIP
                           WHERE PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
                           AND PICKDETAIL_WIP.Pickdetailkey = @c_Pickdetailkey
                                                       
                           SELECT @n_err = @@ERROR

                           IF @n_err <> 0 
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   
                              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLBLP02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                              BREAK
                          END 
                                          
                           SELECT @n_QtyBal = 0
                        END     
                     
                        FETCH NEXT FROM CUR_Pick INTO @c_Pickdetailkey, @n_PickQty
                     END -- While QtyBal > 0
                     CLOSE CUR_Pick
                     DEALLOCATE CUR_Pick
                  END        
                    
                    UPDATE #TMP_LOTMOVEIN 
                    SET QtyAvailable = QtyAvailable - @n_QtySwap,
                        QtyExpected = QtyExpected + @n_QtySwap,
                        Targeted = 'Y'   
                    WHERE Lot = @C_LotAvailable                                                          
                 END
                 ELSE
                 BEGIN
                    SET @c_TargetLot = ''
                    BREAK
                 END
              END
               
            NEXT_LOT:
             
            FETCH FROM CUR_LOT_Expected INTO @c_Lot, @c_ID, @n_QtyExpected
         END
         CLOSE CUR_LOT_Expected
         DEALLOCATE CUR_LOT_Expected
          
         FETCH FROM CUR_SKUXLOC_MULTILOT INTO @c_Storerkey, @c_Sku, @c_Loc
      END
      CLOSE CUR_SKUXLOC_MULTILOT
      DEALLOCATE CUR_SKUXLOC_MULTILOT                   
   END    
   
   -----Create replenishment task for robot pick   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
        --Retrieve all lot of the load from robot pick with overallocated
      SELECT PD.Lot          
      INTO #TMP_LOT
      FROM PICKDETAIL PD (NOLOCK)
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.Orderkey = LPD.Orderkey
      WHERE LPD.Loadkey = @c_Loadkey
      AND LOC.LocationType IN ('DYNPPICK','DYNPICKP')
      AND LOC.LocationCategory = 'ROBOT'            
      AND LOC.Facility = @c_Facility --NJOW1
      GROUP BY PD.Lot

      SELECT LLI.Lot, SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn) * -1 AS QtyExpected          
      INTO #TMP_LOADROBOTLOT
      FROM #TMP_LOT TL (NOLOCK)
      JOIN LOTXLOCXID LLI (NOLOCK) ON TL.Lot = LLI.Lot
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      WHERE LOC.LocationType IN ('DYNPPICK','DYNPICKP')
      AND LOC.LocationCategory = 'ROBOT'            
      AND LOC.Facility = @c_Facility --NJOW1
      GROUP BY LLI.Lot
      HAVING SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn) < 0  --overallocate
      
     --Retrieve lot available include pendingmovein at robot staging     
      SELECT LLI.Lot, SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) + LLI.PendingMoveIn) AS QtyAvailable          
      INTO #TMP_ROBOTSTAGELOT
      FROM LOTXLOCXID LLI (NOLOCK)
      JOIN #TMP_LOADROBOTLOT TL ON LLI.Lot = TL.Lot  
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      WHERE LOC.LocationType = 'ROBOTSTG'
      AND LOC.LocationCategory = 'ROBOT'  
      AND LOC.Facility = @c_Facility --NJOW01          
      GROUP BY LLI.Lot
      HAVING SUM((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) + LLI.PendingMoveIn) > 0         
                         
       --Retreive robot pick require replenish after deduct from robot stage. 
      DECLARE cur_RobotPickLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.Storerkey, LLI.Sku, LLI.Lot, 
                LLI.Loc, LLI.Id, ((LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn) * -1 AS QtyReplen, --Qty of the lot,loc,id overallocated at robot pick need replenish 
                ISNULL(LOTREP.LotQtyReplen,0) AS LotQtyReplen, --Qty of the lot overalloated need replenish but deducted pending move in at robot stage
                PACK.CaseCnt
         FROM LOTXLOCXID LLI (NOLOCK)          
         JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         JOIN (SELECT RP.Lot, RP.QtyExpected - ISNULL(RS.QtyAvailable,0) AS LotQtyReplen  
               FROM #TMP_LOADROBOTLOT RP (NOLOCK)
               LEFT JOIN #TMP_ROBOTSTAGELOT RS (NOLOCK) ON RP.Lot = RS.Lot       
               WHERE RP.QtyExpected - ISNULL(RS.QtyAvailable,0) > 0) AS LOTREP ON LLI.Lot = LOTREP.Lot 
         WHERE LOC.LocationType IN ('DYNPPICK','DYNPICKP')
         AND LOC.LocationCategory IN('ROBOT')            
         AND LLI.Storerkey = @c_Storerkey
         AND LOC.Facility = @c_Facility       
         AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + LLI.PendingMoveIn < 0
         ORDER BY LLI.Lot
   
      OPEN cur_RobotPickLoc
      
      FETCH FROM cur_RobotPickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyReplen, @n_LotQtyReplen, @n_CaseCnt
      
      SELECT @c_PrevLot = ''
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN                           
          SET @c_Message03 = 'ROBOTLOC' 
          SET @c_Priority = '9'
          SET @c_PickMethod = 'PP'
          SET @c_ToLoc = @c_RobotStaging --overallocate at robot pick and replenish to robot stage
          
           IF @c_Lot <> @c_PrevLot
           BEGIN
             SET @n_LotQtyReplen_Tmp = @n_LotQtyReplen  --get the qtyreplen of the lot from first record of same lot. it could have multiple records with diffrent id,loc
           END
           ELSE IF @n_LotQtyReplen_Tmp <= 0  --qtyreplen of the lot already fulfill, the following id,lot of the lot no need replenish.
              GOTO NEXT_REC
         
           --IF @n_QtyShort < 0
           --   SET @n_QtyShort = @n_QtyShort * -1
              
           --SET @n_QtyReplen = @n_QtyShort   
           
           --retrieve stock from bulk 
         DECLARE cur_Bulk CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT LLI.Lot, LLI.Loc, LLI.Id, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) AS QtyAvailable
            FROM LOTXLOCXID LLI (NOLOCK)          
            JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
            JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
            JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
            JOIN ID (NOLOCK) ON LLI.Id = ID.Id
            WHERE SL.LocationType NOT IN('PICK','CASE')
            AND LOC.LocationType NOT IN ('ROBOTSTG','DYNPPICK','DYNPICKP','PICK')
            AND LOC.LocationCategory NOT IN('ROBOT')            
            AND LOT.STATUS = 'OK' 
            AND LOC.STATUS = 'OK' 
            AND ID.STATUS = 'OK'  
            AND LOC.LocationFlag = 'NONE' 
            AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
            AND LLI.Storerkey = @c_Storerkey
            AND LLI.Sku = @c_Sku
            AND LLI.Lot = @c_Lot
            AND LOC.Facility = @c_Facility --NJOW1            
            ORDER BY LOC.LocationGroup, LOC.Loclevel, QtyAvailable, LOC.Logicallocation, LOC.Loc
            
         OPEN cur_Bulk
        
         FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_QtyReplen > 0             
         BEGIN                        
            IF @n_QtyAvailable >= @n_QtyReplen             
               SET @n_TotCtn = CEILING(@n_QtyReplen / (@n_CaseCnt * 1.00))
            ELSE
               SET @n_TotCtn = CEILING(@n_QtyAvailable / (@n_CaseCnt * 1.00))
               --SET @n_TotCtn = FLOOR(@n_QtyAvailable / (@n_CaseCnt * 1.00))
            
             WHILE @n_TotCtn > 0 AND @n_QtyReplen > 0 AND @n_continue IN(1,2)             
             BEGIN
                 --IF @n_QtyReplen >= @n_CaseCnt
                 --   SET @n_InsertQty = @n_CaseCnt
                 --ELSE
                 --   SET @n_InsertQty = @n_QtyReplen
                    
                 IF @n_QtyAvailable >= @n_CaseCnt
                    SET @n_Qty = @n_CaseCnt
                 ELSE   
                    SET @n_Qty = @n_QtyAvailable
                                                        
                 SET @n_QtyAvailable = @n_QtyAvailable - @n_Qty
                 SET @n_QtyReplen = @n_QtyReplen - @n_Qty
                                                            
                EXEC isp_InsertTaskDetail   
                   @c_TaskType              = @c_TaskType             
                  ,@c_Storerkey             = @c_Storerkey
                  ,@c_Sku                   = @c_Sku
                  ,@c_Lot                   = @c_Lot 
                  ,@c_UOM                   = '2'      
                  ,@n_UOMQty                = @n_CaseCnt     
                  ,@n_Qty                   = @n_Qty      
                  ,@c_FromLoc               = @c_Fromloc      
                  ,@c_LogicalFromLoc        = @c_FromLoc 
                  ,@c_FromID                = @c_ID     
                  ,@c_ToLoc                 = @c_ToLoc       
                  ,@c_LogicalToLoc          = @c_ToLoc 
                  ,@c_ToID                  = @c_ToID       
                  ,@c_PickMethod            = @c_PickMethod
                  ,@c_Priority              = @c_Priority     
                  ,@c_SourcePriority        = '9'      
                  ,@c_CallSource            = 'LOADPLAN'
                  ,@c_SourceType            = @c_SourceType      
                  ,@c_SourceKey             = @c_Loadkey      
                  ,@c_LoadKey               = @c_Loadkey      
                  ,@c_AreaKey               = '?F'      -- ?F=Get from location areakey 
                  ,@c_Message03             = @c_Message03
                  ,@n_SystemQty             = -1        -- if systemqty is zero/not provided it always copy from @n_Qty as default. if want to force it to zero, pass in negative value e.g. -1
                  --,@c_RoundUpQty            = 'FC'      -- FC=Round up qty to full carton by packkey
                  ,@n_QtyReplen             = @n_Qty --NJOW02
                  ,@c_ReserveQtyReplen      = 'TASKQTY' -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid 
                  ,@c_ReservePendingMoveIn  =  'Y'      -- Y=Update @n_qty to @n_PendingMoveIn
                  ,@b_Success               = @b_Success OUTPUT
                  ,@n_Err                   = @n_err OUTPUT 
                  ,@c_ErrMsg                = @c_errmsg OUTPUT          
                            
               IF @b_Success <> 1 
               BEGIN
                  SELECT @n_continue = 3  
               END

                 SET @n_TotCtn = @n_TotCtn - 1                
            END
   
            SET @n_LotQtyReplen_Tmp = @n_LotQtyReplen_Tmp - @n_Qty 
                 
              IF @n_LotQtyReplen_Tmp <= 0
              BEGIN             
               CLOSE cur_Bulk
               DEALLOCATE cur_Bulk
                 GOTO NEXT_REC
              END          
          
            FETCH FROM cur_Bulk INTO @c_Lot, @c_FromLoc, @c_ID, @n_QtyAvailable
         END
         CLOSE cur_Bulk
         DEALLOCATE cur_Bulk
         
         --if bulk no stock replen from pick to robot
         IF @n_QtyReplen > 0
         BEGIN
             --retrieve stock from pick 
            DECLARE cur_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT LLI.Lot, LLI.Loc, LLI.Id, (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) AS QtyAvailable
               FROM LOTXLOCXID LLI (NOLOCK)          
               JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
               JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
               JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
               JOIN ID (NOLOCK) ON LLI.Id = ID.Id
               WHERE (SL.LocationType IN('PICK','CASE') OR LOC.LocationType = 'PICK')
               AND LOT.STATUS = 'OK' 
               AND LOC.STATUS = 'OK' 
               AND ID.STATUS = 'OK'  
               AND LOC.LocationFlag = 'NONE' 
               AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen) > 0
               AND LLI.Storerkey = @c_Storerkey
               AND LLI.Sku = @c_Sku
               AND LLI.Lot = @c_Lot
               AND LOC.Facility = @c_Facility --NJOW1
               ORDER BY LOC.LocationGroup, LOC.Loclevel, QtyAvailable, LOC.Logicallocation, LOC.Loc
               
            OPEN cur_Pick
            
            FETCH FROM cur_Pick INTO @c_Lot2, @c_FromLoc, @c_ID, @n_QtyAvailable
            
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_QtyReplen > 0             
            BEGIN          
               IF @n_QtyAvailable >= @n_QtyReplen
                  SET @n_Qty = @n_QtyReplen
               ELSE
                  SET @n_Qty = @n_QtyAvailable
                  
                  SET @n_QtyReplen = @n_QtyReplen - @n_Qty

                EXEC isp_InsertTaskDetail   
                   @c_TaskType              = @c_TaskType             
                  ,@c_Storerkey             = @c_Storerkey
                  ,@c_Sku                   = @c_Sku
                  ,@c_Lot                   = @c_Lot2 
                  ,@c_UOM                   = '6'      
                  ,@n_UOMQty                = @n_QtyReplen
                  ,@n_Qty                   = @n_Qty      
                  ,@c_FromLoc               = @c_Fromloc      
                  ,@c_LogicalFromLoc        = @c_FromLoc 
                  ,@c_FromID                = @c_ID     
                  ,@c_ToLoc                 = @c_ToLoc       
                  ,@c_LogicalToLoc          = @c_ToLoc 
                  ,@c_ToID                  = @c_ToID       
                  ,@c_PickMethod            = @c_PickMethod
                  ,@c_Priority              = @c_Priority     
                  ,@c_SourcePriority        = '9'      
                  ,@c_CallSource            = 'LOADPLAN'
                  ,@c_SourceType            = @c_SourceType      
                  ,@c_SourceKey             = @c_Loadkey      
                  ,@c_LoadKey               = @c_Loadkey      
                  ,@c_AreaKey               = '?F'      -- ?F=Get from location areakey 
                  ,@c_Message03             = @c_Message03
                  ,@n_SystemQty             = -1        -- if systemqty is zero/not provided it always copy from @n_Qty as default. if want to force it to zero, pass in negative value e.g. -1
                  --,@c_RoundUpQty            = 'FC'      -- FC=Round up qty to full carton by packkey
                  ,@c_ReserveQtyReplen      = 'TASKQTY' -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid 
                  ,@c_ReservePendingMoveIn  =  'Y'      -- Y=Update @n_qty to @n_PendingMoveIn
                  ,@b_Success               = @b_Success OUTPUT
                  ,@n_Err                   = @n_err OUTPUT 
                  ,@c_ErrMsg                = @c_errmsg OUTPUT          
                            
               IF @b_Success <> 1 
               BEGIN
                  SELECT @n_continue = 3  
               END

               SET @n_LotQtyReplen_Tmp = @n_LotQtyReplen_Tmp - @n_Qty 
                 
                IF @n_LotQtyReplen_Tmp <= 0
                 BEGIN             
                  CLOSE cur_Pick
                  DEALLOCATE cur_Pick
                    GOTO NEXT_REC
                 END          
                                  
               FETCH FROM cur_Pick INTO @c_Lot2, @c_FromLoc, @c_ID, @n_QtyAvailable
            END
            CLOSE cur_Pick
            DEALLOCATE cur_Pick           
         END
         
         NEXT_REC:
         
         SET @c_PrevLot = @c_Lot
         
         FETCH FROM cur_RobotPickLoc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_QtyReplen, @n_LotQtyReplen, @n_CaseCnt
      END
      CLOSE cur_RobotPickLoc
      DEALLOCATE cur_RobotPickLoc          
   END    
    
   -----Update pickdetail_WIP work in progress staging table back to pickdetail                                             
   IF @n_continue = 1 or @n_continue = 2                                                                                    
   BEGIN                                                                                                                           
      DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                                     
      SELECT PickDetail_WIP.PickDetailKey, PickDetail_WIP.Qty, PickDetail_WIP.UOMQty,                                       
             PickDetail_WIP.TaskDetailKey, PickDetail_WIP.Pickslipno, PickDetail_WIP.TrafficCop,
             PickDetail_WIP.Status                             
      FROM PickDetail_WIP (NOLOCK)                                                                                          
      WHERE PICKDETAIL_WIP.WIP_RefNo = @c_SourceType            
      ORDER BY CASE WHEN PickDetail_WIP.Trafficcop = 'N' THEN 1 ELSE 2 END, CASE WHEN PickDetail_WIP.Qty = 0 THEN 1 ELSE 2 END, PickDetail_WIP.PickDetailKey                                                                                 
                                                                                                                            
      OPEN cur_PickDetailKey                                                                                                
                                                                                                                            
      FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_PickslipNo, @c_TrafficCop, @c_Status                
                                                                                                                            
      WHILE @@FETCH_STATUS = 0                                                                                                    
      BEGIN 
          IF @b_debug = 1
              SELECT * FROM PickDetail_WIP (NOLOCK) WHERE Pickdetailkey = @c_PickDetailKey                                                                                          

         IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK)                                                                   
                   WHERE PickDetailKey = @c_PickDetailKey)                                                                  
         BEGIN 
             IF ISNULL(@c_Trafficcop,'') = 'N'
             BEGIN                                                                                                             
                UPDATE PICKDETAIL WITH (ROWLOCK)                                                                                
                SET Qty = @n_Qty,                                                                                               
                    UOMQty = @n_UOMQty,                                                                                         
                    TaskDetailKey = @c_TaskDetailKey,                                                                           
                    PickslipNo = @c_Pickslipno,                                                                                 
                    EditDate = GETDATE()                                                                                    
                WHERE PickDetailKey = @c_PickDetailKey
           END                         
           ELSE
           BEGIN
                UPDATE PICKDETAIL WITH (ROWLOCK)                                                                                
                SET Qty = @n_Qty,                                                                                               
                    UOMQty = @n_UOMQty,                                                                                         
                    TaskDetailKey = @c_TaskDetailKey,                                                                           
                    PickslipNo = @c_Pickslipno,                                                                                 
                    EditDate = GETDATE(),                                                                                         
                    TrafficCop = NULL                                                                                           
                WHERE PickDetailKey = @c_PickDetailKey
           END                                                            
                                                                                                                            
           SELECT @n_err = @@ERROR                                                                                         
                                                                                                                           
           IF @n_err <> 0                                                                                                  
           BEGIN                                                                                                           
              SELECT @n_continue = 3                                                                                       
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   -- Should Be Set To The SQL Errmessage but
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLBLP02)' + ' ( ' 
           END
           
           IF @n_Qty = 0
           BEGIN
              DELETE PICKDETAIL
              WHERE PICKDETAILKEY = @c_PickDetailKey
              
              SELECT @n_err = @@ERROR                                                                                         
                                                                                                                              
              IF @n_err <> 0                                                                                                  
              BEGIN                                                                                                           
                 SELECT @n_continue = 3                                                                                       
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83065   -- Should Be Set To The SQL Errmessage but
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickdetail Table Failed. (ispRLBLP02)' + ' ( ' 
              END
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
                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, CASE WHEN STATUS >= '3' AND ISNULL(@c_TrafficCop,'') = 'N' THEN '0' ELSE Status END,                                               
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                          
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                               
                  WaveKey, EffectiveDate, CASE WHEN ISNULL(@c_TrafficCop,'') = 'N' THEN NULL ELSE '9' END, ShipFlag, PickSlipNo,                                                        
                  Taskdetailkey, TaskManagerReasonkey, Notes                                                                
            FROM PICKDETAIL_WIP WITH (NOLOCK)                                                                               
            WHERE PickDetailKey = @c_PickDetailKey        
            AND PickDetail_WIP.WIP_RefNo = @c_SourceType                                                                  
                                                                                                                            
            SELECT @n_err = @@ERROR                                                                                         
                                                                                                                            
            IF @n_err <> 0                                                                                                  
            BEGIN                                                                                                           
               SELECT @n_continue = 3                                                                                       
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070   -- Should Be Set To The SQL Errmessage but
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLBLP02)' + ' ( ' 
             END                                                                                                             
         END                        
         
         IF ISNULL(@c_Trafficcop,'') = 'N' AND @c_Status >= '3' 
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET Status = @c_Status
            WHERE Pickdetailkey = @c_Pickdetailkey

            SELECT @n_err = @@ERROR                                                                                         
                                                                                                                            
            IF @n_err <> 0                                                                                                  
            BEGIN                                                                                                           
               SELECT @n_continue = 3                                                                                       
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080   -- Should Be Set To The SQL Errmessage but
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLBLP02)' + ' ( ' 
            END                                                                                                                         
         END                                                                                                             
                                                                                                                                                                                                  
          FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno, @c_TrafficCop, @c_Status             
      END                                                                                                                   
      CLOSE cur_PickDetailKey                                                                                               
      DEALLOCATE cur_PickDetailKey                                                                                                                                                                                                                      
   END                                    
   
   --NJOW03
   IF @n_continue = 1 or @n_continue = 2 
   BEGIN
      EXEC isp_RobotLoadITF_Wrapper
         @c_Loadkey = @c_Loadkey
         , @b_Success = @b_Success OUTPUT  
         , @n_Err = @n_err OUTPUT
         , @c_ErrMsg = @c_errmsg OUTPUT         
   END
   
    -----Generate Pickslip No------
    /*IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       EXEC isp_CreatePickSlip
            @c_Loadkey = @c_Loadkey
           ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
           ,@b_Success = @b_Success OUTPUT
           ,@n_Err = @n_err OUTPUT 
           ,@c_ErrMsg = @c_errmsg OUTPUT        
       
       IF @b_Success = 0
          SELECT @n_continue = 3    
    END*/                                                                                    
                                                                                                                          
   RETURN_SP:  
   
   IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)
             WHERE PD.WIP_RefNo = @c_SourceType)
   BEGIN
        DELETE PickDetail_WIP 
        FROM PickDetail_WIP (NOLOCK)
      WHERE PickDetail_WIP.WIP_RefNo = @c_SourceType            
   END
   
   IF @n_continue IN(1,2)
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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090   -- Should Be Set To The SQL Errmessage but
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LoadPlan Table Failed. (ispRLBLP02)'  
      END                                                                                                                    
   END
         
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTranCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV16"  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
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