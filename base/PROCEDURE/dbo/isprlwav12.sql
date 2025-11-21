SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/    
/* Stored Procedure: ispRLWAV12                                          */    
/* Creation Date: 21-Nov-2017                                            */    
/* Copyright: LFL                                                        */    
/* Written by:                                                           */    
/*                                                                       */    
/* Purpose: WMS-3330 - SG Triple Release Wave                            */  
/*                                                                       */    
/* Called By: wave                                                       */    
/*                                                                       */    
/* PVCS Version: 1.1                                                     */    
/*                                                                       */    
/* Version: 7.0                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date        Author   Ver   Purposes                                   */    
/* 10-Jun-2019 NJOW01   1.0   Fix qty replen                             */  
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */
/*************************************************************************/     
  
CREATE PROCEDURE [dbo].[ispRLWAV12]        
  @c_wavekey      NVARCHAR(10)    
 ,@b_Success      int        OUTPUT    
 ,@n_err          int        OUTPUT    
 ,@c_errmsg       NVARCHAR(250)  OUTPUT    
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
  
    DECLARE  @c_Storerkey NVARCHAR(15)  
            ,@c_Facility NVARCHAR(5)  
            ,@c_Sku NVARCHAR(20)  
            ,@c_Lot NVARCHAR(10)  
            ,@c_FromLoc NVARCHAR(10)  
            ,@c_ID NVARCHAR(18)  
            ,@c_ToID NVARCHAR(18)  
            ,@n_Qty INT  
            ,@c_SourceType NVARCHAR(30)  
            ,@c_TaskType NVARCHAR(10)  
            ,@c_UOM NVARCHAR(10)  
            ,@n_UOMQty INT  
            ,@c_PickMethod NVARCHAR(10)              
            ,@c_Priority NVARCHAR(10)  
            ,@c_Toloc NVARCHAR(10)  
            ,@c_Taskdetailkey NVARCHAR(10)    
            ,@c_LinkTaskToPick NVARCHAR(10)  
            ,@c_LinkTaskToPick_SQL NVARCHAR(4000)  
            ,@c_PickDetailKey NVARCHAR(10)  
            ,@c_Userdefine02 NVARCHAR(20)  
            ,@c_Userdefine03 NVARCHAR(20)              
            ,@c_PTSLOC NVARCHAR(10)  
            ,@c_PickslipNo NVARCHAR(10)              
            ,@c_LocationCategory NVARCHAR(10)  
            ,@c_Style NVARCHAR(20)  
            ,@c_ReserveQtyReplen NVARCHAR(10)  
            ,@n_SystemQty INT              
            ,@n_UCCQty INT  
            ,@n_FullPackQty INT  
            ,@n_RoundUpQty INT  
            ,@n_QtyAvailable INT        
            ,@c_LoadPlanGroup NVARCHAR(10)  
            ,@c_LocationType NVARCHAR(10)  
            ,@c_CallFrom NVARCHAR(10)  
            ,@c_pickdetailReplenishZone NVARCHAR(10)  
            ,@c_ReservePendingMoveIn  NVARCHAR(5)          
            ,@c_PickLoc NVARCHAR(10)  
            ,@c_Pickdetailloc NVARCHAR(10)  
            ,@c_pickdetailID NVARCHAR(18)  
            ,@c_pickdetailtoloc NVARCHAR(10)  
            ,@c_Loadkey NVARCHAR(10)  
            ,@n_QtyReplen INT --NJOW01  
            ,@c_ZeroSystemQty NVARCHAR(5) --NJOW01  
                      
    SET @c_SourceType = 'ispRLWAV12'      
  
    -----Wave Validation-----              
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN   
       IF NOT EXISTS (SELECT 1   
                      FROM WAVEDETAIL WD (NOLOCK)  
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType AND TD.Tasktype IN('FCP','RPF')  
                      WHERE WD.Wavekey = @c_Wavekey                     
                      AND PD.Status = '0'  
                      AND TD.Taskdetailkey IS NULL  
                     )  
       BEGIN  
          SELECT @n_continue = 3    
          SELECT @n_err = 83000    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV12)'         
       END        
    END  
      
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN  
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                   WHERE TD.Wavekey = @c_Wavekey  
                   AND TD.Sourcetype = @c_SourceType  
                   AND TD.Tasktype IN('FCP','RPF')  
                   AND TD.Status <> 'X')  
        BEGIN  
          SELECT @n_continue = 3    
          SELECT @n_err = 83010      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV12)'         
        END                   
    END  
            
    -----Get Storerkey, facility, PTS loc range   
    IF  (@n_continue = 1 OR @n_continue = 2)  
    BEGIN  
        SELECT @c_Storerkey = MAX(O.Storerkey),   
               @c_Facility = MAX(O.Facility),  
               @c_Userdefine02 = W.UserDefine02,  
               @c_Userdefine03 = W.UserDefine03,  
               @c_LoadPlanGroup = W.LoadPlanGroup  
        FROM WAVE W (NOLOCK)  
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey  
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
        AND W.Wavekey = @c_Wavekey   
        GROUP BY  W.UserDefine02, W.UserDefine03,W.LoadPlanGroup  
                  
        IF (ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '') AND @c_LoadPlanGroup ='WVLPGRP03'  
        BEGIN           
           SELECT @n_continue = 3    
           SELECT @n_err = 83020      
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Mmut key-in flowrack location range at userdefine02&03. (ispRLWAV12)'         
           GOTO RETURN_SP                        
        END                 
          
       CREATE TABLE #PTS_LOCASSIGNED (RowId BIGINT Identity(1,1) PRIMARY KEY  
                                      ,STORERKEY NVARCHAR(15) NULL  
                                      ,SKU NVARCHAR(20) NULL  
                                      ,TOLOC NVARCHAR(10) NULL)                                  
    END      
      
    BEGIN TRAN  
      
    ----Consolidate pick and stamp conso carton(multi orders full carton)  
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       EXEC isp_ConsolidatePickdetail  
        @c_Loadkey = ''  
       ,@c_Wavekey = @c_Wavekey   
       ,@c_UOM = '2'  --carton consolidation  
       ,@c_GroupFieldList = 'ORDERS.Orderkey'  --field to determine the full carton is single order  
       ,@c_SQLCondition = 'SKUXLOC.LocationType NOT IN (''CASE'',''PICK'') AND LOC.LocationCategory IN (''RACK'',''RACKING'') '  
       ,@c_CaseCntByUCC = 'N' --Get casecnt by ucc qty of the location. all UCC of the sku mush have same qty at the location.  
       ,@b_Success = @b_Success OUTPUT    
       ,@n_Err = @n_err OUTPUT    
       ,@c_ErrMsg = @c_errmsg OUTPUT    
         
       IF @b_success = 0   
          SELECT @n_continue = 3             
    END  
  
    -----Generate Pickslip No------  
    IF @n_continue = 1 or @n_continue = 2   
    BEGIN  
       IF @c_LoadPlanGroup = 'WVLPGRP03'  
       BEGIN  
          --create load conso pickslip for the wave  
          EXEC isp_CreatePickSlip  
               @c_Wavekey = @c_Wavekey  
              ,@c_ConsolidateByLoad = 'Y'  --Y=Create load consolidate pickslip  
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno   
              ,@b_Success = @b_Success OUTPUT  
              ,@n_Err = @n_err OUTPUT   
              ,@c_ErrMsg = @c_errmsg OUTPUT          
            
          IF @b_Success = 0  
             SELECT @n_continue = 3              
       END         
       ELSE  
       BEGIN   
          EXEC isp_CreatePickSlip  
               @c_Wavekey = @c_Wavekey  
              ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno   
              ,@b_Success = @b_Success OUTPUT  
              ,@n_Err = @n_err OUTPUT   
              ,@c_ErrMsg = @c_errmsg OUTPUT          
            
          IF @b_Success = 0  
             SELECT @n_continue = 3      
       END  
    END  
  
    --Initialize Pickdetail work in progress staging table  
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN  
       IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)  
                 JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey  
                 JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey   
                 WHERE WD.Wavekey = @c_Wavekey  
                 AND PD.WIP_RefNo = @c_SourceType)  
       BEGIN  
          DELETE PickDetail_WIP   
          FROM PickDetail_WIP (NOLOCK)  
          JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey   
          JOIN WAVEDETAIL WD (NOLOCK) ON ORDERS.Orderkey = WD.Orderkey  
          WHERE WD.Wavekey = @c_Wavekey   
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType  
       END   
         
       INSERT INTO PickDetail_WIP   
       (  
        PickDetailKey,      CaseID,         PickHeaderKey,  
        OrderKey,           OrderLineNumber, Lot,  
        Storerkey,          Sku,            AltSku,     UOM,  
        UOMQty,             Qty,            QtyMoved,   [Status],  
        DropID,             Loc,            ID,        PackKey,  
        UpdateSource,       CartonGroup,     CartonType,  
        ToLoc,             DoReplenish,     ReplenishZone,  
        DoCartonize,        PickMethod,      WaveKey,  
        EffectiveDate,      AddDate,        AddWho,  
        EditDate,           EditWho,        TrafficCop,  
        ArchiveCop,         OptimizeCop,     ShipFlag,  
        PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,  
        Notes,             MoveRefKey,    WIP_RefNo   
       )  
       SELECT PD.PickDetailKey,  CaseID,         PD.PickHeaderKey,   
        PD.OrderKey,            PD.OrderLineNumber,  PD.Lot,  
        PD.Storerkey,           PD.Sku,             PD.AltSku,        PD.UOM,  
        PD.UOMQty,             PD.Qty,             PD.QtyMoved,      PD.[Status],  
        PD.DropID,             PD.Loc,             PD.ID,           PD.PackKey,  
        PD.UpdateSource,        PD.CartonGroup,      PD.CartonType,  
        PD.ToLoc,               PD.DoReplenish,      PD.ReplenishZone,  
        PD.DoCartonize,         PD.PickMethod,       WD.Wavekey,  
        PD.EffectiveDate,       PD.AddDate,         PD.AddWho,  
        PD.EditDate,            PD.EditWho,         PD.TrafficCop,  
        PD.ArchiveCop,          PD.OptimizeCop,      PD.ShipFlag,  
        PD.PickSlipNo,          PD.TaskDetailKey,    PD.TaskManagerReasonKey,  
        PD.Notes,               PD.MoveRefKey,    @c_SourceType   
       FROM WAVEDETAIL WD (NOLOCK)   
       JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey  
       WHERE WD.Wavekey = @c_Wavekey  
         
       SET @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83030     -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table. (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
       END        
    END  
  
    --Remove taskdetailkey   
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN  
       UPDATE PICKDETAIL_WIP WITH (ROWLOCK)   
       SET PICKDETAIL_WIP.TaskdetailKey = '',  
           PICKDETAIL_WIP.TrafficCop = NULL  
       FROM WAVEDETAIL (NOLOCK)    
       JOIN PICKDETAIL_WIP ON WAVEDETAIL.Orderkey = PICKDETAIL_WIP.Orderkey  
       WHERE WAVEDETAIL.Wavekey = @c_Wavekey   
       AND PICKDETAIL_WIP.WIP_RefNo = @c_SourceType  
         
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0   
       BEGIN  
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail_WIP Table Failed. (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
       END   
    END  
                  
    -----Create pick task(FCP) to PTS for full and conso carton. Replenish loose with full carton to pick and pick to PTS  
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN              
       DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, LOC.LocationCategory, SKU.Style, SUM(PD.Qty) AS Qty, PD.UOM, SUM(PD.UOMQty) AS UOMQty, SL.LocationType, O.Loadkey  
          FROM WAVEDETAIL WD (NOLOCK)  
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
          JOIN PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey   
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
          JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc  
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey  
          WHERE WD.Wavekey = @c_Wavekey  
          AND PD.Status = '0'  
          AND PD.WIP_RefNo = @c_SourceType  
          GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation, LOC.LocationCategory, SKU.Style, SL.LocationType, O.Loadkey  
          ORDER BY PD.Storerkey, PD.Sku, LOC.LogicalLocation, PD.Lot         
         
       OPEN cur_pick    
         
       FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @c_LocationCategory, @c_Style, @n_Qty, @c_UOM, @n_UOMQty, @c_LocationType, @c_Loadkey  
         
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
       BEGIN              
        SET @n_SystemQty = @n_Qty             
        SET @c_Toloc = ''  
        SET @c_ToID = @c_ID  
           
         /*                    
         IF @c_LocationCategory  ='SHELVING' AND @c_LocationType IN('PICK','CASE')   
            SET @c_PickMethod = 'PP'  
         ELSE IF @c_UOM = '1'  
            SET @c_PickMethod = 'FP'  
         ELSE      
            SET @c_PickMethod = '?ROUNDUP' --?ROUNDUP=Qty available - (qty - systemqty)   
         */  
           
         SET @c_PickMethod = 'PP'  
  
          SELECT @n_UCCQty = PACK.CaseCnt  
          FROM SKU (NOLOCK)   
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey  
          WHERE SKU.Storerkey = @c_Storerkey  
          AND SKU.Sku = @c_Sku            
  
          /*  
          SELECT TOP 1 @n_UCCQty = Qty  --Expect the location have same UCC qty  
          FROM UCC (NOLOCK)  
          WHERE Storerkey = @c_Storerkey  
          AND Sku = @c_Sku  
          AND Lot = @c_Lot  
          AND Loc = @c_FromLoc  
          AND Id = @c_Id  
          AND Status < '3'       
          ORDER BY Qty DESC  
          */  
            
          IF @c_LocationCategory = 'SHELVING' AND @c_LocationType IN('PICK','CASE')  
             SET @n_UOMQty = 0  
          ELSE      
             SET @n_UOMQty = @n_UCCQty  
               
          SET @n_UOMQty = ISNULL(@n_UOMQty, 1)     
              
          IF @c_LocationCategory = 'RACK' AND @c_LocationType NOT IN('PICK','CASE') AND @c_UOM = '6'    
          BEGIN     
            --loose from rack to be replenish to pick loc and 2nd task pick to flowrack               
            IF @n_UCCQty > 0   
            BEGIN  
                SET @n_FullPackQty = CEILING(@n_Qty / (@n_UCCQty * 1.00)) * @n_UCCQty               
  
                SET @n_RoundUpQty = @n_FullPackQty - @n_SystemQty  
                  
                IF @n_RoundUpQty > 0  
                BEGIN           
                   SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked - QtyReplen)   
                   FROM LOTXLOCXID (NOLOCK)             
                   WHERE Storerkey = @c_Storerkey  
                   AND Sku = @c_Sku  
                   AND Lot = @c_Lot   
                   AND Loc = @c_FromLoc  
                   AND ID = @c_ID          
                     
                   IF @n_QtyAvailable >= @n_RoundUpQty  
                   BEGIN  
                      SET @n_Qty = @n_FullPackQty                
                   END  
                END         
             END                                         
              
            --find pick loc  
            SET @c_PickLoc = ''  
            SELECT TOP 1 @c_PickLoc = Loc   
            FROM SKUXLOC (NOLOCK)  
            WHERE Storerkey = @c_Storerkey  
            AND Sku = @c_Sku  
            AND LocationType IN('PICK','CASE')              
              
            IF ISNULL(@c_PickLoc,'') = ''  
            BEGIN  
                SELECT @n_continue = 3    
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable find pick loc of Sku ' + RTRIM(@c_Sku) + ' for replenishment. (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                GOTO RETURN_SP    
            END                 
                                      
             --Create replenishment task   
             --SET @c_ReserveQtyReplen = 'ROUNDUP'  --ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)  
             SET @c_ReserveQtyReplen = 'N' --NJOW01  
             SET @n_QtyReplen = @n_Qty --NJOW01  
             SET @c_ReservePendingMoveIn = 'Y'    --Y=Update @n_qty to @n_PendingMoveIn  
             SET @c_TaskType = 'RPF'  
             SET @c_Priority = '5'  
             SET @c_LinkTaskToPick = 'N'   
            SET @c_LinkTaskToPick_SQL = ''  
           SET @c_CallFrom = '1'  
           SET @c_ToLoc = @c_Pickloc             
           SET @c_ZeroSystemQty = 'Y' --NJOW01  
     
             GOTO INSERT_TASK  
            INSERT_TASK_RTN1:                
                                         
            --move pick to pick loc  
             IF EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE Loc = @c_ToLoc AND loseid = '1')  
               SET @c_ToID = ''  --Pick loc will lose id  
  
             --Move the replenish pickdetail to pick with overallocation (allow overallocate must be enabled and skuxloc.locationtype must be pick or case)  
             UPDATE PICKDETAIL_WIP  
             SET PICKDETAIL_WIP.Loc = @c_ToLoc,  
                 PICKDETAIL_WIP.Toloc = @c_FromLoc, --store as previous loc(bulk) after move to pick for reversal use  
                 PICKDETAIL_WIP.ReplenishZone = RIGHT(RTRIM(@c_ID),10), --storer as previous id(bulk) after move to pick with loose id for revseral use  
                 PICKDETAIL_WIP.Id = @c_ToID  
             FROM PICKDETAIL_WIP   
             WHERE PICKDETAIL_WIP.Lot = @c_Lot  
             AND PICKDETAIL_WIP.Loc = @c_FromLoc  
             AND PICKDETAIL_WIP.ID = @c_ID  
             AND PICKDETAIL_WIP.UOM IN ('6','7')  
             AND PICKDETAIL_WIP.Wavekey = @c_Wavekey  
             AND PICKDETAIL_WIP.WIP_Refno = @c_SourceType     
  
            --create pick task from pick loc after replen to PTS  
             SET @c_ReserveQtyReplen = 'N'    
             SET @n_QtyReplen = 0 --NJOW01  
             SET @c_ReservePendingMoveIn = 'N'      
             SET @c_TaskType = 'FCP'  
             SET @c_Priority = '9'  
             SET @c_LinkTaskToPick = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
            SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM' --additional condition to search pickdetail  
           SET @c_CallFrom = '2'              
           SET @c_ZeroSystemQty = 'N' --NJOW01             
                          
            SET @n_Qty = @n_SystemQty --replen qty from bulk to pick loc already convert to full case, now from Pick to PTS convert back to actual order(pick) qty  
            SET @c_FromLoc = @c_PickLoc --pick from pick location after replenish as above  
            SET @c_ID = @c_ToID  
  
           IF @c_LoadPlanGroup = 'WVLPGRP03' --Conso for TH   
              SET @c_ToLoc = @c_Userdefine02  
           ELSE  
           BEGIN  
               GOTO FIND_PTS_LOC  
              FIND_PTS_LOC_RTN2:     
           END  
  
             GOTO INSERT_TASK  
           INSERT_TASK_RTN2:  
          END     
          ELSE  
          BEGIN     
            --Full carton, conso carton from rack and loose from pick loc  
            SET @c_ReserveQtyReplen = 'N'  
             SET @n_QtyReplen = 0 --NJOW01  
             SET @c_ReservePendingMoveIn = 'N'    
             SET @c_TaskType = 'FCP'  
             SET @c_Priority = '9'  
             SET @c_LinkTaskToPick = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
            SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM' --additional condition to search pickdetail  
           SET @c_CallFrom = '3'  
           SET @c_ZeroSystemQty = 'N' --NJOW01  
  
           IF @c_LoadPlanGroup = 'WVLPGRP03' --Conso for TH   
              SET @c_ToLoc = @c_Userdefine02  
           ELSE  
           BEGIN  
              GOTO FIND_PTS_LOC  
              FIND_PTS_LOC_RTN3:     
           END  
                     
           --create task  
           GOTO INSERT_TASK  
           INSERT_TASK_RTN3:                
         END              
                                                       
          FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @c_LocationCategory, @c_Style, @n_Qty, @c_UOM, @n_UOMQty, @c_LocationType, @c_Loadkey  
       END   
       CLOSE cur_pick    
       DEALLOCATE cur_pick                                                  
    END       
                  
    -----Update pickdetail_WIP work in progress staging table back to pickdetail   
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT PickDetail_WIP.PickDetailKey, PickDetail_WIP.Qty, PickDetail_WIP.UOMQty,   
                 PickDetail_WIP.TaskDetailKey, PickDetail_WIP.Pickslipno, PickDetail_WIP.ReplenishZone,  
                 PickDetail_WIP.Loc, PickDetail_WIP.ID, PickDetail_WIP.ToLoc  
          FROM PickDetail_WIP (NOLOCK)  
          JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey  
          JOIN WAVEDETAIL WD (NOLOCK) ON ORDERS.Orderkey = WD.Orderkey  
          WHERE WD.Wavekey = @c_Wavekey   
          AND PickDetail_WIP.WIP_RefNo = @c_SourceType  
          ORDER BY PickDetail_WIP.PickDetailKey   
         
       OPEN cur_PickDetailKey  
         
       FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_PickslipNo, @c_pickdetailreplenishzone, @c_Pickdetailloc, @c_pickdetailID, @c_pickdetailtoloc  
         
       WHILE @@FETCH_STATUS = 0  
       BEGIN  
          IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK)   
                    WHERE PickDetailKey = @c_PickDetailKey)  
          BEGIN               
            IF EXISTS(SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE Pickdetailkey = @c_PickDetailkey AND Loc <> @c_Pickdetailloc) --pickdetail change location  
            BEGIN  
              --IF EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE Loc = @c_Pickdetailloc AND loseid = '1')  
                --   SET @c_ID = ''  --Pick loc will lose id  
                --ELSE  
                --   SET @c_ID = @c_pickdetailID     
               
               --need to create dummy lotxlocxid and skuxloc if not exist for overallocation  
               IF NOT EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK) WHERE lot = @c_Lot AND loc = @c_pickdetailloc AND Id = @c_pickdetailID  )  
               BEGIN  
                 INSERT INTO LOTXLOCXID (Storerkey, Sku, Lot, Loc, Id, Qty)  
                 VALUES (@c_Storerkey, @c_Sku, @c_Lot, @c_PickdetailLoc, @c_pickdetailID  , 0)  
                   
                   SELECT @n_err = @@ERROR  
               
                   IF @n_err <> 0  
                   BEGIN  
                      SELECT @n_continue = 3    
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Lotxlocxid Table Failed. (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                    
                  END                       
               END  
  
               IF NOT EXISTS(SELECT 1 FROM SKUXLOC (NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku AND loc = @c_pickdetailloc)  
               BEGIN  
                 INSERT INTO SKUXLOC (Storerkey, Sku, Loc, Qty)  
                 VALUES (@c_Storerkey, @c_Sku, @c_PickdetailLoc, 0)  
                   
                   SELECT @n_err = @@ERROR  
               
                   IF @n_err <> 0  
                   BEGIN  
                      SELECT @n_continue = 3    
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Skuxloc Table Failed. (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                    
                  END                       
               END  
                 
               UPDATE PICKDETAIL WITH (ROWLOCK)   
               SET Loc = @c_Pickdetailloc,  
                   ID = @c_pickdetailid,   
                   ToLoc = @c_pickdetailtoloc,  
                   ReplenishZone = @c_pickdetailreplenishzone  
               WHERE PickDetailKey = @c_PickDetailKey    
  
                SELECT @n_err = @@ERROR  
               
                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3    
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                    
               END                       
            END                              
  
            UPDATE PICKDETAIL WITH (ROWLOCK)   
            SET Qty = @n_Qty,   
                UOMQty = @n_UOMQty,   
                TaskDetailKey = @c_TaskDetailKey,  
                PickslipNo = @c_Pickslipno,  
                WaveKey = @c_Wavekey,  
                EditDate = GETDATE(),                           
                TrafficCop = NULL  
            WHERE PickDetailKey = @c_PickDetailKey    
               
             SELECT @n_err = @@ERROR  
               
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3    
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                    
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
               
             SELECT @n_err = @@ERROR  
               
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3    
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                    
            END           
          END  
         
          FETCH FROM cur_PickDetailKey INTO @c_PickDetailKey, @n_Qty, @n_UOMQty, @c_TaskDetailkey, @c_Pickslipno, @c_pickdetailreplenishzone, @c_Pickdetailloc, @c_pickdetailID, @c_pickdetailtoloc  
       END     
       CLOSE cur_PickDetailKey  
       DEALLOCATE cur_PickDetailKey               
    END  
        
    -----Validation taskdetail at pickdetail-----  
    /*IF @n_continue = 1 or @n_continue = 2    
    BEGIN        
       IF EXISTS(SELECT 1   
                 FROM TASKDETAIL TD (NOLOCK)  
                 LEFT JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey   
                 WHERE TD.Wavekey = @c_Wavekey                     
                 AND TD.Sourcetype = @c_SourceType   
                 AND TD.Tasktype IN('FCP','RPF')                   
                 AND PD.Taskdetailkey IS NULL)  
       BEGIN  
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetailkey To Pickdetail Failed. (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                              
       END            
    END*/  
              
    -----Update Wave Status-----  
    IF @n_continue = 1 or @n_continue = 2    
    BEGIN    
       UPDATE WAVE   
          --SET STATUS = '1' -- Released        --(Wan01) 
          SET TMReleaseFlag = 'Y'               --(Wan01) 
           ,  TrafficCop = NULL                 --(Wan01) 
           ,  EditWho = SUSER_SNAME()           --(Wan01) 
           ,  EditDate= GETDATE()               --(Wan01) 
       WHERE WAVEKEY = @c_wavekey    
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
       END    
    END    
     
RETURN_SP:  
  
    IF EXISTS(SELECT 1 FROM PickDetail_WIP PD (NOLOCK)  
              JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey  
              JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey   
              WHERE WD.Wavekey = @c_Wavekey  
              AND PD.WIP_RefNo = @c_SourceType)  
    BEGIN  
      DELETE PickDetail_WIP   
      FROM PickDetail_WIP (NOLOCK)  
      JOIN ORDERS (NOLOCK) ON PickDetail_WIP.Orderkey = ORDERS.Orderkey             
      JOIN WAVEDETAIL WD (NOLOCK) ON ORDERS.Orderkey = WD.Orderkey   
       WHERE WD.Wavekey = @c_Wavekey   
       AND PickDetail_WIP.WIP_RefNo = @c_SourceType         
    END          
  
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV12"    
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
      
    --------Insert Task function---------  
    INSERT_TASK:  
                
    EXEC isp_InsertTaskDetail     
    @c_TaskType              = @c_TaskType               
   ,@c_Storerkey             = @c_Storerkey  
   ,@c_Sku                   = @c_Sku  
   ,@c_Lot                   = @c_Lot   
   ,@c_UOM                   = @c_UOM        
   ,@n_UOMQty                = @n_UOMQty    
   ,@n_SystemQty             = @n_SystemQty  
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
   ,@c_SourceType            = @c_SourceType        
   ,@c_SourceKey             = @c_Wavekey        
   ,@c_WaveKey               = @c_Wavekey        
   ,@c_Loadkey               = @c_Loadkey  
   ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey   
   ,@c_Message01             = @c_Style    
   ,@c_LinkTaskToPick        = @c_LinkTaskToPick  
   ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL    
   ,@n_QtyReplen             = @n_QtyReplen --NJOW01  
   ,@c_ReserveQtyReplen      = @c_ReserveQtyReplen    
   ,@c_ReservePendingMoveIn  = @c_ReservePendingMoveIn  
   ,@c_ZeroSystemQty         = @c_ZeroSystemQty --NJOW01  
   ,@c_WIP_RefNo             = @c_SourceType               
   ,@b_Success               = @b_Success OUTPUT  
   ,@n_Err                   = @n_err OUTPUT   
   ,@c_ErrMsg                = @c_errmsg OUTPUT          
     
   IF @b_Success <> 1   
   BEGIN  
      SELECT @n_continue = 3    
   END  
     
   IF @c_callfrom = '1'  
      GOTO INSERT_TASK_RTN1  
   IF @c_callfrom = '2'  
      GOTO INSERT_TASK_RTN2  
   IF @c_callfrom = '3'  
      GOTO INSERT_TASK_RTN3  
        
  
   --------Find flowrack PTS location---------  
   FIND_PTS_LOC:  
     
   SET @c_PTSLoc = ''  
     
    -- Assign loc with same sku already assigned in current wave      
   IF ISNULL(@c_PTSLoc,'')=''  
   BEGIN  
       SELECT TOP 1 @c_PTSLoc = PTS.ToLoc  
       FROM #PTS_LOCASSIGNED PTS  
       JOIN LOC (NOLOCK) ON LOC.Loc = PTS.ToLoc  
       WHERE PTS.Storerkey = @c_Storerkey  
       AND PTS.Sku = @c_Sku  
       ORDER BY LOC.LogicalLocation, PTS.ToLoc  
   END     
     
    -- Assign new PTS location  
   IF ISNULL(@c_PTSLoc,'')=''  
   BEGIN    
      SELECT TOP 1 @c_PTSLoc = Loc  
      FROM LOC(NOLOCK)  
      WHERE Loc >= @c_Userdefine02  
      AND Loc <= @c_Userdefine03   
      AND LocationCategory = 'FLOWRACK'  
      AND Facility = @c_Facility  
      AND Loc NOT IN(SELECT TOLOC FROM #PTS_LOCASSIGNED)  
      ORDER BY Putawayzone, LogicalLocation, Loc  
   END  
                    
   -- Terminate. Can't find any PTS location  
   IF ISNULL(@c_PTSLoc,'')=''  
   BEGIN  
      SELECT @n_continue = 3    
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTS Location Not Setup / Not enough PTS Location. (ispRLWAV12)(' + RTRIM(@c_callfrom) + ') ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '         
      GOTO RETURN_SP  
   END  
        
   SELECT @c_ToLoc = @c_PTSLoc  
              
   --Insert current location assigned  
   IF NOT EXISTS (SELECT 1 FROM #PTS_LOCASSIGNED  
                  WHERE Storerkey = @c_Storerkey  
                  AND Sku = @c_Sku  
                  AND ToLoc = @c_ToLoc)  
   BEGIN  
      INSERT INTO #PTS_LOCASSIGNED (Storerkey, Sku, ToLoc)  
      VALUES (@c_Storerkey, @c_Sku, @c_Toloc )  
   END                
     
   IF @c_callfrom = '2'  
      GOTO FIND_PTS_LOC_RTN2  
   IF @c_callfrom = '3'  
      GOTO FIND_PTS_LOC_RTN3  
 END  
 --sp end  

GO