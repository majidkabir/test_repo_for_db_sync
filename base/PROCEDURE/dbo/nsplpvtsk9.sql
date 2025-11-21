SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspLPVTSK9                                          */  
/* Creation Date: 25-Jul-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-9045 - ID Fonterra load plan reverse pick task           */
/*                                                                       */  
/* Called By: load plan RCM                                              */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/*************************************************************************/   

CREATE PROCEDURE [dbo].[nspLPVTSK9]      
  @c_loadkey      NVARCHAR(10)  
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
           ,@c_facility NVARCHAR(5)  
           ,@c_Taskdetailkey NVARCHAR(10)
           ,@c_Pickdetailkey NVARCHAR(10)
           ,@c_authority NVARCHAR(30)
           ,@c_Orderkey NVARCHAR(10)

    SELECT TOP 1 @c_StorerKey = O.Storerkey,
                 @c_Facility = O.Facility 
    FROM LOADPLANDETAIL LD (NOLOCK)
    JOIN ORDERS O (NOLOCK) ON (LD.Orderkey = O.Orderkey)
    WHERE LD.Loadkey = @c_Loadkey  

    ----reject if load not yet release      
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Loadkey = @c_Loadkey AND TD.SourceType = 'nspLPRTSK9')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Load has not been released. (nspLPVTSK9)'         
        END                 
    END

    ----reject if any task was started
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Loadkey = @c_Loadkey
                   AND TD.Sourcetype = 'nspLPRTSK9' 
                   AND TD.Status <> '0')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Load Released (nspLPVTSK9)'       
        END                 
    END
    
    BEGIN TRAN
    
    ----delete tasks
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
  	   DECLARE cur_task CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  	      SELECT TASKDETAIL.Taskdetailkey
  	      FROM TASKDETAIL (NOLOCK)  	      
          WHERE TASKDETAIL.Loadkey = @c_Loadkey 
          AND TASKDETAIL.Sourcetype = 'nspLPRTSK9'
          AND TASKDETAIL.TaskType IN('FCP','FPK')
          AND TASKDETAIL.Status = '0'
       
       OPEN cur_task  
          
       FETCH NEXT FROM cur_task INTO @c_Taskdetailkey
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
          DELETE TASKDETAIL
          WHERE Taskdetailkey = @c_Taskdetailkey         
          
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81041   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (nspLPVTSK9)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END
       	  
          FETCH NEXT FROM cur_task INTO @c_Taskdetailkey      	
       END
       CLOSE cur_task
       DEALLOCATE  cur_task
    END
    
    ----Remove taskdetailkey from pickdetail of the load
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       DECLARE cur_rvpick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT PD.Pickdetailkey
          FROM PICKDETAIL PD (NOLOCK)
          JOIN LOADPLANDETAIL LD (NOLOCK) ON PD.Orderkey = LD.Orderkey
          WHERE LD.Loadkey = @c_Loadkey
    	      
       OPEN cur_rvpick  
          
       FETCH NEXT FROM cur_rvpick INTO @c_Pickdetailkey
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN    	
         UPDATE PICKDETAIL WITH (ROWLOCK) 
          SET PICKDETAIL.TaskdetailKey = '',
             TrafficCop = NULL
         WHERE PICKDETAIL.Pickdetailkey = @c_Pickdetailkey
         
         SELECT @n_err = @@ERROR
         
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (nspLPVTSK9)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END        
         
         FETCH NEXT FROM cur_rvpick INTO @c_Pickdetailkey
       END
       CLOSE cur_rvpick
       DEALLOCATE cur_rvpick    
    END        
    
    -----Reverse load status------
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       UPDATE LOADPLAN WITH (ROWLOCK)
          SET ProcessFlag = 'N' 
       WHERE Loadkey = @c_Loadkey
         
       SELECT @n_err = @@ERROR
         
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (nspLPVTSK9)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
    
    -----Reverse SOStatus---------
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       EXECUTE nspGetRight 
          @c_facility,  
          @c_StorerKey,              
          '', --sku
          'UpdateSOReleaseTaskStatus', -- Configkey
          @b_success    OUTPUT,
          @c_authority  OUTPUT,
          @n_err        OUTPUT,
          @c_errmsg     OUTPUT    	

       IF @b_success = 1 AND @c_authority = '1' 
       BEGIN
          DECLARE cur_rvpick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT O.Orderkey
             FROM ORDERS O (NOLOCK)
             JOIN LOADPLANDETAIL LD (NOLOCK) ON O.Orderkey = LD.Orderkey
             WHERE LD.Loadkey = @c_Loadkey
    	         
          OPEN cur_order
             
          FETCH NEXT FROM cur_order INTO @c_Orderkey
       
          WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
          BEGIN       	
       	     UPDATE ORDERS WITH (ROWLOCK)
       	     SET SOStatus = '0',
       	         TrafficCop = NULL,
       	         EditWho = SUSER_SNAME(),
       	         EditDate = GETDATE()
       	     WHERE Orderkey = @c_Orderkey
       	     AND SOStatus = 'TSRELEASED'

             SELECT @n_err = @@ERROR
               
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on ORDERS Failed (nspLPVTSK9)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END  

             FETCH NEXT FROM cur_order INTO @c_Orderkey       	     
       	  END
       	  CLOSE cur_order
       	  DEALLOCATE cur_order
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
       execute nsp_logerror @n_err, @c_errmsg, "nspLPVTSK9"  
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