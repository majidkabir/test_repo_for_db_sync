SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRVWAV01                                          */  
/* Creation Date: 12-Apr-2013                                            */  
/* Copyright: IDS                                                        */  
/* Written by: NJOW                                                      */  
/*                                                                       */  
/* Purpose: SOS#256796 - Reverse Replenishmnt Task                       */  
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.4                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 05-Nov-2013 Chee01   1.0   Delete RefKeyLookUp                        */  
/* 28-Apr-2014 NJOW01   1.1   309316-Reverse XDOCK staging to            */
/*                            induction move task                        */
/* 09-Jul-2015 NJOW06   1.2   343964-amend the logic                     */
/* 03-Oct-2019 NJOW17   1.3   WMS-9533 Add Ecom order handlig            */
/* 01-04-2020  Wan01    1.4   Sync Exceed & SCE                          */
/*************************************************************************/   
CREATE PROCEDURE [dbo].[ispRVWAV01]      
  @c_wavekey      NVARCHAR(10)  
 ,@c_Orderkey     NVARCHAR(10) = ''
 ,@b_Success      int        OUTPUT  
 ,@n_err          int        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE        @n_continue int,    
                   @n_starttcnt int,         -- Holds the current transaction count  
                   @n_debug int,
                   @n_cnt int
    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT @n_debug = 0
    
    DECLARE @c_Storerkey NVARCHAR(15)
           ,@c_Sku NVARCHAR(20)
           ,@c_Lot NVARCHAR(10)
           ,@c_ToLoc NVARCHAR(10)
           ,@c_ToID NVARCHAR(18)
           ,@n_Qty INT
           ,@c_Taskdetailkey NVARCHAR(10)

    ----reject if wave not yet release      
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype IN ('ispRLWAV01-LAUNCH','ispRLWAV01-RETAIL','ispRLWAV01-XDOCK','ispRLWAV01-REPLEN','ispRLWAV01-ECOM') --NJOW01
                   AND TD.Tasktype IN ('RPF','MVF'))  --NJOW01
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV01)'         
        END                 
    END

    ----reject if any task was started
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype IN ('ispRLWAV01-LAUNCH','ispRLWAV01-RETAIL','ispRLWAV01-XDOCK','ispRLWAV01-REPLEN','ispRLWAV01-ECOM') --NJOW01
                   AND TD.Status <> '0'
                   AND TD.Tasktype IN ('RPF','MVF')) --NJOW01
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV01)'       
        END                 
    END
    
    BEGIN TRAN

    ----reverse pending move-in at DPP
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       DECLARE cur_tasks CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT TD.Taskdetailkey, TD.Storerkey, TD.Sku, TD.Lot, TD.Toloc, TD.ToID, TD.Qty 
          FROM TASKDETAIL TD (NOLOCK)
          JOIN LOC (NOLOCK) ON TD.ToLoc = LOC.Loc
          WHERE TD.Wavekey = @c_Wavekey
          AND TD.Sourcetype IN ('ispRLWAV01-LAUNCH','ispRLWAV01-RETAIL','ispRLWAV01-REPLEN','ispRLWAV01-ECOM')
          AND TD.Status = '0'
          AND TD.Tasktype = 'RPF'
          AND LOC.LocationType = 'DYNPPICK'

       OPEN cur_tasks  
       FETCH NEXT FROM cur_tasks INTO @c_Taskdetailkey, @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_Qty 
                     
       WHILE @@FETCH_STATUS = 0  
       BEGIN    
         UPDATE LOTXLOCXID WITH (ROWLOCK)
          SET PendingMoveIN = PendingMoveIN - @n_Qty
          WHERE Storerkey = @c_Storerkey
          AND Sku = @c_Sku
          AND Lot = @c_Lot
          AND Loc = @c_ToLoc
          AND ID = @c_ToID
          AND PendingMoveIN > 0

          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LOTXLOCXID Table Failed. (ispRVWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END 
          
          FETCH NEXT FROM cur_tasks INTO @c_Taskdetailkey, @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ToID, @n_Qty 
       END
       CLOSE cur_tasks  
       DEALLOCATE cur_tasks                                    
    END             
    
    ----delete replenishment/xdock move tasks
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
         DELETE TASKDETAIL
         WHERE TASKDETAIL.Wavekey = @c_Wavekey 
         AND TASKDETAIL.Sourcetype IN ('ispRLWAV01-LAUNCH','ispRLWAV01-RETAIL','ispRLWAV01-XDOCK','ispRLWAV01-ECOM') --NJOW01
         AND TASKDETAIL.Tasktype IN ('RPF','MVF') --NJOW01
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 
    END
    
    ----Remove taskdetailkey from pickdetail of the wave
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK) 
          SET PICKDETAIL.TaskdetailKey = '',
             TrafficCop = NULL
         FROM WAVEDETAIL (NOLOCK)  
         JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 
         
         -- Chee01
         DELETE RKLKUP FROM dbo.RefKeyLookUp RKLKUP
         JOIN WAVEDETAIL WD ON (RKLKUP.OrderKey = WD.OrderKey)
         WHERE WD.Wavekey = @c_Wavekey

         SELECT @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
           SELECT @n_continue = 3    
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81051   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete RefKeyLookUp Table Failed. (ispRVWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END  
    END        
    
    -----Reverse wave status------
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       UPDATE WAVE 
          --SET STATUS = '0' -- Normal          --(Wan01)
          SET TMReleaseFlag = 'N'               --(Wan01) 
           ,  TrafficCop = NULL                 --(Wan01) 
           ,  EditWho = SUSER_SNAME()           --(Wan01) 
           ,  EditDate= GETDATE()               --(Wan01) 
       WHERE WAVEKEY = @c_wavekey  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
    
           
RETURN_SP:

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV01"  
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