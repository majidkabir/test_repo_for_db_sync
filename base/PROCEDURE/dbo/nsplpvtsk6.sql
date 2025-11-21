SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspLPVTSK6                                          */  
/* Creation Date: 29-Aug-2017                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-1965 - TW NIKE reverse replenishment tasks               */            
/*                                                                       */  
/* Called By: load plan RCM                                              */  
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

CREATE PROCEDURE [dbo].[nspLPVTSK6]      
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
           ,@c_Sku NVARCHAR(20)
           ,@c_Lot NVARCHAR(10)
           ,@c_ToLoc NVARCHAR(10)
           ,@c_ToID NVARCHAR(18)
           ,@n_Qty INT
           ,@c_Taskdetailkey NVARCHAR(10)
           ,@c_facility NVARCHAR(5)  
           ,@c_authority NVARCHAR(10)
           ,@c_otherloadkey NVARCHAR(10)           

    SELECT TOP 1 @c_StorerKey = O.Storerkey,
                 @c_Facility = O.Facility 
    FROM LOADPLANDETAIL LD (NOLOCK)
    JOIN ORDERS O (NOLOCK) ON (LD.Orderkey = O.Orderkey)
    WHERE LD.Loadkey = @c_Loadkey  

    ----reject if load not yet release      
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Loadkey = @c_Loadkey AND TD.SourceType = 'nspLPRTSK6')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Load has not been released. (nspLPVTSK6)'         
        END                 
    END

    ----reject if any task was started
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Loadkey = @c_Loadkey
                   AND TD.Sourcetype = 'nspLPRTSK6' 
                   AND TD.Status <> '0')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Load Released (nspLPVTSK6)'       
        END                 
    END
    
    BEGIN TRAN
    
    ----delete tasks
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
  	   	 DECLARE cur_task CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  	   	    SELECT TD.Taskdetailkey, SUM(PD.Qty)
  	   	    FROM LOADPLANDETAIL LP (NOLOCK)
  	   	    JOIN PICKDETAIL PD (NOLOCK) ON LP.Orderkey = PD.Orderkey
  	   	    JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey
  	   	    WHERE LP.Loadkey = @c_Loadkey
  	   	    AND TD.Sourcetype = 'nspLPRTSK6'  	   	    
  	   	    GROUP BY TD.Taskdetailkey
  	   	    UNION ALL
  	   	    SELECT DISTINCT TD.Taskdetailkey, 0    -- L-ORDER replen all same sku material if order qty more than 60% from bulk
  	   	    FROM TASKDETAIL TD (NOLOCK)
  	   	    LEFT JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey
  	   	    WHERE TD.Loadkey = @c_Loadkey
  	   	    AND PD.Taskdetailkey IS NULL
  	   	    AND TD.Sourcetype = 'nspLPRTSK6'
         
         OPEN cur_task  
            
         FETCH NEXT FROM cur_task INTO @c_Taskdetailkey, @n_Qty
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
         	  SET @c_otherloadkey = ''
         	  
         	  SELECT TOP 1 @c_otherloadkey = LD.Loadkey
         	  FROM PICKDETAIL PD (NOLOCK)
         	  JOIN LOADPLANDETAIL LD (NOLOCK) ON LD.Orderkey = PD.Orderkey
         	  JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey
         	  WHERE TD.Taskdetailkey = @c_Taskdetailkey
         	  AND LD.Loadkey <> @c_Loadkey
         	  
         	  IF ISNULL(@c_Otherloadkey,'') <> ''
         	  BEGIN         	  	          	  	           	  	        	  	 
         	  	 UPDATE TASKDETAIL WITH (ROWLOCK)
         	  	 SET SystemQty = SystemQty - @n_Qty,
         	  	     Message03 = CASE WHEN Message03 = 'LP:' + @c_Loadkey THEN '' ELSE Message03 END,
         	  	     Message02 = 'RVLP:' + @c_Loadkey, 
         	  	     Loadkey = CASE WHEN Loadkey = @c_loadkey THEN @c_Otherloadkey ELSE Loadkey END,
         	  	     trafficcop = NULL
         	  	 WHERE Taskdetailkey = @c_Taskdetailkey

               SELECT @n_err = @@ERROR
               IF @n_err <> 0 
               BEGIN
                 SELECT @n_continue = 3  
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetail Table Failed. (nspLPVTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81041   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (nspLPVTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END
         	  END      	           	  
         	  
            FETCH NEXT FROM cur_task INTO @c_Taskdetailkey, @n_Qty         	
         END
         CLOSE cur_task
         DEALLOCATE  cur_task
         
         --reverse L-ORDER same sku material with order qty more than 60% replen from bulk and combine to replen task of other load
         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET Message03 = '',
             Message02 = 'RVLP:' + @c_Loadkey, 
             trafficcop = NULL
         WHERE SourceType = 'nspLPRTSK6'
         AND LEFT(Message03,13) = 'LP:' + @c_Loadkey
                         
         /*
         DELETE TASKDETAIL
         WHERE TASKDETAIL.Loadkey = @c_Loadkey          
         AND TASKDETAIL.Sourcetype LIKE 'nspLPRTSK%'
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (nspLPVTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END
         */ 
    END
    
    ----Remove taskdetailkey from pickdetail of the load
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK) 
          SET PICKDETAIL.TaskdetailKey = '',
             TrafficCop = NULL
         FROM LOADPLANDETAIL (NOLOCK)  
         JOIN PICKDETAIL ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey
         WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey 
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (nspLPVTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END          
    END        
    
    -----Reverse load status------
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       UPDATE LOADPLAN 
          SET ProcessFlag = 'N' 
       WHERE Loadkey = @c_Loadkey  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (nspLPVTSK6)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
       	  WHERE Loadkey = @c_Loadkey
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
       execute nsp_logerror @n_err, @c_errmsg, "nspLPVTSK6"  
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