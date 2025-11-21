SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRVWAV23                                          */  
/* Creation Date: 27-Feb-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-8017 - CN Fabory reverse task                            */
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

CREATE PROCEDURE [dbo].[ispRVWAV23]      
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
            @n_cnt INT,
            @c_otherwavekey NVARCHAR(10)
                   
    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT @n_debug = 0
    
    DECLARE @c_Storerkey NVARCHAR(15)
           ,@c_Sku NVARCHAR(20)
           ,@c_Lot NVARCHAR(10)
           ,@c_ToLoc NVARCHAR(10)
           ,@c_ToID NVARCHAR(18)
           ,@n_Qty INT
           ,@c_Taskdetailkey NVARCHAR(10)
           ,@c_facility NVARCHAR(5)  
           ,@c_authority NVARCHAR(10)
    	     ,@c_FromLoc nvarchar(10)
    	     ,@c_FromID  nvarchar(18)     	             	            

    SELECT TOP 1 @c_StorerKey = O.Storerkey,
                 @c_Facility = O.Facility 
    FROM WAVEDETAIL WD (NOLOCK)
    JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)
    WHERE WD.Wavekey = @c_Wavekey  

    ----reject if wave not yet release      
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                       WHERE TD.Wavekey = @c_Wavekey AND TD.SourceType = 'ispRLWAV23'
                       AND TD.TaskType IN('FPK','FCP'))
        BEGIN                                          
          SELECT @n_continue = 3  
          SELECT @n_err = 81010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV23)'         
        END                 
    END

    ----reject if any task was started
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = 'ispRLWAV22'
                   AND  TD.TaskType IN('FPK','FCP')
                   AND TD.Status <> '0')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV23)'       
        END                 
    END
    
    BEGIN TRAN
    	    
    ----delete tasks
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
         DELETE TASKDETAIL
         WHERE TASKDETAIL.Wavekey = @c_Wavekey 
         AND TASKDETAIL.Sourcetype = 'ispRLWAV23'
         AND TASKDETAIL.TaskType IN('FPK','FCP')
         AND TASKDETAIL.Status = '0'
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV23)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 
    END
          
    ----Remove taskdetailkey from pickdetail of the wave
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN    	
  	   	 DECLARE cur_task CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  	   	    SELECT TD.Taskdetailkey, SUM(PD.Qty)
  	   	    FROM WAVEDETAIL WD (NOLOCK)
  	   	    JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
  	   	    JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey
  	   	    WHERE WD.Wavekey = @c_Wavekey
  	   	    AND TD.Sourcetype = 'ispRLWAV23'  	   	    
  	   	    GROUP BY TD.Taskdetailkey
  	   	    UNION ALL
  	   	    SELECT DISTINCT TD.Taskdetailkey, 0    
  	   	    FROM TASKDETAIL TD (NOLOCK)
  	   	    LEFT JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey
  	   	    WHERE TD.Wavekey = @c_Wavekey
  	   	    AND PD.Taskdetailkey IS NULL
  	   	    AND TD.Sourcetype = 'ispRLWAV23'
  	   	             
         OPEN cur_task  
            
         FETCH NEXT FROM cur_task INTO @c_Taskdetailkey, @n_Qty
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
         	  SET @c_otherwavekey = ''
         	  
         	  SELECT TOP 1 @c_otherwavekey = WD.Wavekey
         	  FROM PICKDETAIL PD (NOLOCK)
         	  JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = PD.Orderkey
         	  JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey
         	  WHERE TD.Taskdetailkey = @c_Taskdetailkey
         	  AND WD.Wavekey <> @c_Wavekey
         	  
         	  IF ISNULL(@c_otherwavekey,'') <> ''
         	  BEGIN         	  	          	  	           	  	        	  	 
         	  	 UPDATE TASKDETAIL WITH (ROWLOCK)
         	  	 SET SystemQty = SystemQty - @n_Qty,
         	  	     Message03 = CASE WHEN Message03 = 'WV:' + @c_Wavekey THEN '' ELSE Message03 END,
         	  	     Message02 = 'RVWV:' + @c_Wavekey, 
         	  	     Wavekey = CASE WHEN Wavekey = @c_Wavekey THEN @c_OtherWavekey ELSE Wavekey END,
         	  	     trafficcop = NULL
         	  	 WHERE Taskdetailkey = @c_Taskdetailkey

               SELECT @n_err = @@ERROR
               IF @n_err <> 0 
               BEGIN
                 SELECT @n_continue = 3  
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetail Table Failed. (ispRVWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END               
         	  END   
         	  ELSE
         	  BEGIN
               DELETE TASKDETAIL
               WHERE Taskdetailkey = @c_Taskdetailkey         
               
               SELECT @n_err = @@ERROR
               IF @n_err <> 0 
               BEGIN
                 SELECT @n_continue = 3  
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END
         	  END      	           	  
         	  
            FETCH NEXT FROM cur_task INTO @c_Taskdetailkey, @n_Qty         	
         END
         CLOSE cur_task
         DEALLOCATE  cur_task
         
         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET Message03 = '',
             Message02 = 'RVWV:' + @c_Wavekey, 
             trafficcop = NULL
         WHERE SourceType = 'ispRLWAV23'
         AND LEFT(Message03,13) = 'WV:' + @c_Wavekey
    END
    
    /*
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
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV23)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END          
    END       
    */
     
    
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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV23)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
       	  UPDATE ORDERS WITH (ROWLOCK)
       	  SET SOStatus = '0',
       	      TrafficCop = NULL,
       	      EditWho = SUSER_SNAME(),
       	      EditDate = GETDATE()
       	  WHERE Userdefine09 = @c_Wavekey
       	  AND SOStatus = 'TSRELEASED'
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV23"  
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