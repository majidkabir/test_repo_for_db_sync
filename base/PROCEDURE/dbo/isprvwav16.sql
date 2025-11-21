SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRVWAV16                                          */  
/* Creation Date: 23-APR-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-4345 - CN UA Reverse Released Wave (B2B)                 */  
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
/* Date         Author   Ver  Purposes                                   */ 
/* 15-Aug-2019  NJOW01   1.0  WMS-9825 reverse replenishment records by  */
/*                            ucc for manual replenshment as backup plan */
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRVWAV16]      
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
           ,@c_WaveConsoAllocation NVARCHAR(10)
           ,@c_facility NVARCHAR(5)
           ,@c_WaveType NVARCHAR(18) 
           ,@c_Replenishmentkey NVARCHAR(10)
           ,@c_Pickdetailkey NVARCHAR(10)
           ,@c_UCCNo NVARCHAR(20)

     SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                  @c_Facility = O.Facility,
                  @c_WaveType = ISNULL(W.WaveType,'') --NJOW01
     FROM WAVE W (NOLOCK)
     JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
     JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
     AND W.Wavekey = @c_Wavekey 
        
    SELECT @c_WaveConsoAllocation = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveConsoAllocation')   

    ----reject if wave not yet release      
    IF (@n_continue = 1 OR @n_continue = 2) 
    BEGIN
        IF @c_WaveType = 'PAPER' --NJOW01
        BEGIN
          IF NOT EXISTS(SELECT 1 FROM REPLENISHMENT (NOLOCK) 
                        WHERE Wavekey = @c_Wavekey
                        AND Storerkey = @c_Storerkey
                        AND Confirmed = 'N')
           BEGIN               
              SELECT @n_continue = 3  
              SELECT @n_err = 81010  
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released for paper replenishment. (ispRVWAV16)'    
           END                             
        END
        ELSE
        BEGIN
           IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                      WHERE TD.Wavekey = @c_Wavekey
                      AND TD.Sourcetype IN ('ispRLWAV16') 
                      AND TD.Tasktype IN ('RPF')) 
           BEGIN
              IF NOT EXISTS (SELECT 1
                             FROM RDT.rdtPTLStationLog (NOLOCK)
                             WHERE RDT.rdtPTLStationLog.Wavekey = @c_Wavekey 
                             AND RDT.rdtPTLStationLog.SourceType = 'ispRLWAV16') AND @c_WaveConsoAllocation = '1' 
              BEGIN               
                 SELECT @n_continue = 3  
                 SELECT @n_err = 81020  
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV16)'    
              END     
           END  
        END               
    END

    ----reject if any task was started
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF @c_WaveType = 'PAPER' --NJOW01
       BEGIN
         IF EXISTS(SELECT 1 FROM REPLENISHMENT (NOLOCK) 
                   WHERE Wavekey = @c_Wavekey
                   AND Storerkey = @c_Storerkey
                   AND Confirmed <> 'N')
          BEGIN               
             SELECT @n_continue = 3  
             SELECT @n_err = 81030  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some replenishment have been started. Not allow to Reverse (ispRVWAV16)'       
          END                                      
       END
       ELSE
       BEGIN      
          IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                     WHERE TD.Wavekey = @c_Wavekey
                     AND TD.Sourcetype IN ('ispRLWAV16')
                     AND TD.Status <> '0'
                     AND TD.Tasktype IN ('RPF'))
          BEGIN
             SELECT @n_continue = 3  
             SELECT @n_err = 81040  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV16)'       
          END
       END                 
    END
    
    BEGIN TRAN
                
    ----delete replenishment
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF @c_WaveType = 'PAPER' --NJOW01
       BEGIN
          DECLARE cur_Repl CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
             SELECT Replenishmentkey, Sku
             FROM REPLENISHMENT (NOLOCK) 
            WHERE Wavekey = @c_Wavekey
            AND Storerkey = @c_Storerkey
            AND Confirmed = 'N'
            ORDER BY Replenishmentkey          

          OPEN cur_Repl 
          
          FETCH NEXT FROM cur_Repl INTO @c_Replenishmentkey, @c_Sku
          
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
           BEGIN
             UPDATE UCC WITH (ROWLOCK)
             SET Status = '1',
                 userdefined10 = ''
             WHERE Userdefined10 = @c_Replenishmentkey
             AND Storerkey = @c_Storerkey 
             AND Sku = @c_Sku

             SELECT @n_err = @@ERROR
             IF @n_err <> 0 
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispRVWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END 
             
             DELETE REPLENISHMENT 
            WHERE Replenishmentkey = @c_Replenishmentkey
            
             SELECT @n_err = @@ERROR
             IF @n_err <> 0 
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Replenishment Table Failed. (ispRVWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END 

             FETCH NEXT FROM cur_Repl INTO @c_Replenishmentkey, @c_Sku                 
           END
           CLOSE cur_Repl
           DEALLOCATE cur_Repl
       END
       ELSE
       BEGIN               
          DELETE TASKDETAIL
          WHERE TASKDETAIL.Wavekey = @c_Wavekey 
          AND TASKDETAIL.Sourcetype IN ('ispRLWAV16')
          AND TASKDETAIL.Tasktype IN ('RPF') 
          
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END 
       END
    END

    ----delete PTL booking for retail new Launch
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       DELETE RDT.rdtPTLStationLog
       WHERE RDT.rdtPTLStationLog.Wavekey = @c_Wavekey 
       AND RDT.rdtPTLStationLog.SourceType = 'ispRLWAV16'
       
       SELECT @n_err = @@ERROR
       IF @n_err <> 0 
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete rdtPTLStationLog Table Failed. (ispRVWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END 
    END
    
    ----Remove taskdetailkey from pickdetail of the wave
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
         DECLARE cur_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.Pickdetailkey, UCC.UccNo
            FROM PICKDETAIL PD (NOLOCK)
            JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey
            LEFT JOIN UCC (NOLOCK) ON PD.Lot = UCC.Lot AND PD.Loc = UCC.Loc AND PD.Id = UCC.Id AND UCC.UCCNo = PD.DropID      
            WHERE WD.Wavekey = @c_Wavekey
         
         OPEN cur_PICK
          
         FETCH NEXT FROM cur_PICK INTO @c_Pickdetailkey, @c_UCCNo
          
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
          BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK) 
             SET PICKDETAIL.TaskdetailKey = '',     
                 MoveRefkey = '',
                 DropID = CASE WHEN ISNULL(@c_UCCNo,'') <> '' THEN '' ELSE DropID END,                          
                 TrafficCop = NULL
            WHERE Pickdetailkey = @c_Pickdetailkey 
            
            SELECT @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END          
            
            FETCH NEXT FROM cur_PICK INTO @c_Pickdetailkey, @c_UCCNo
          END
          CLOSE cur_PICK
          DEALLOCATE cur_PICK                             
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV16)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV16"  
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