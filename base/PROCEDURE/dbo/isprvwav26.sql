SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRVWAV26                                          */  
/* Creation Date: 09-May-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-8760 - BBGCN Reverse Wave                                */
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
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */  
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRVWAV26]      
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
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @n_cnt int
            
    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0, @n_debug = 0

    DECLARE @c_Storerkey NVARCHAR(15)
           ,@c_Sku NVARCHAR(20)
           ,@c_Lot NVARCHAR(10)
           ,@c_ToLoc NVARCHAR(10)
           ,@c_ToID NVARCHAR(18)
           ,@n_Qty INT
           ,@c_Taskdetailkey NVARCHAR(10)
           ,@c_UCCNo NVARCHAR(20) = ''

    ----reject if wave not yet release      
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype IN ('ispRLWAV26') 
                   AND TD.Tasktype IN ('RPF')) 
        BEGIN
           SELECT @n_continue = 3  
           SELECT @n_err = 81010  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV26)'    
        END                 
    END

    ----reject if any task was started
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Wavekey = @c_Wavekey
                  AND TD.Sourcetype IN ('ispRLWAV26')
                  AND TD.Status <> '0'
                  AND TD.Tasktype IN ('RPF'))
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV26)'       
       END                 
    END
     
    ------Reverse UCC Status to 1 for UOM = 7 only------
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN 
       DECLARE cur_Pickdetail CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT UCCNo
       FROM UCC (NOLOCK)
       JOIN TASKDETAIL TD (NOLOCK) ON UCC.UCCNo = TD.CaseID AND TD.Storerkey = UCC.Storerkey
       WHERE TD.WAVEKEY = @c_Wavekey AND TD.UOM = '7' AND TD.TaskType = 'RPF' AND TD.SourceType = 'ispRLWAV26'
       
       OPEN cur_Pickdetail
       
       FETCH NEXT FROM cur_Pickdetail INTO @c_UCCNo
       
       WHILE @@FETCH_STATUS <> -1
       BEGIN
          UPDATE UCC WITH (ROWLOCK)
          SET Status = '1'
          WHERE UCCNo = @c_UCCNo
          
          SELECT @n_err = @@ERROR  
          
          IF @n_err <> 0  
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on UCC Failed (ispRVWAV26)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END 
          
       FETCH NEXT FROM cur_Pickdetail INTO @c_UCCNo   	
       END
       CLOSE cur_Pickdetail
       DEALLOCATE cur_Pickdetail
       
    END

    BEGIN TRAN
                
    ----delete replenishment
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       DELETE TASKDETAIL
       WHERE TASKDETAIL.Wavekey = @c_Wavekey 
       AND TASKDETAIL.Sourcetype IN ('ispRLWAV26')
       AND TASKDETAIL.Tasktype IN ('RPF') 
       
       SELECT @n_err = @@ERROR
       IF @n_err <> 0 
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV26)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV26)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV26)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV26"  
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