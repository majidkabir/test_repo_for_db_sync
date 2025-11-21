SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRVWAV32                                          */  
/* Creation Date: 13-Feb-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-11399 - CN Puma Reverse Released wave                    */
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
/* 02-07-2020  Wan01    1.1   Sync Exceed & SCE                          */
/*************************************************************************/   
CREATE PROCEDURE [dbo].[ispRVWAV32]        
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
            @n_starttcnt int,          
            @n_debug int,  
            @n_cnt INT,
            @c_authority NVARCHAR(30),
            @c_Replenishmentkey NVARCHAR(10),
            @c_Pickdetailkey NVARCHAR(10),
            @c_FromLoc NVARCHAR(10),
            @c_FromID NVARCHAR(18)
                     
    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0  
    SELECT @n_debug = 0  
      
    DECLARE @c_Storerkey    NVARCHAR(15)  
           ,@c_facility     NVARCHAR(5)    
           ,@c_WaveTypeLong NVARCHAR(10)
  
    SELECT TOP 1 @c_Storerkey     = O.Storerkey, 
                 @c_Facility      = O.Facility,
                 @c_WaveTypeLong  = ISNULL(CL.Long, '0')  --0=Monkey picking 1=DPP picking 2=pick face picking    
    FROM WAVE W (NOLOCK)
    JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey
    JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
    JOIN CODELKUP CL (NOLOCK) ON W.Wavetype = CL.Code AND CL.Listname = 'WAVETYPE' 
    AND W.Wavekey = @c_Wavekey 
    
    --reject if wave type 0                
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN  
        IF @c_WaveTypeLong NOT IN('1','2')
        BEGIN                                            
          SELECT @n_continue = 3    
          SELECT @n_err = 81010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Release & Reverse for this wave type. (ispRVWAV32)'           
        END                   
    END  
    
    ----reject if wave not yet release   
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN  
        IF NOT EXISTS (SELECT 1 FROM REPLENISHMENT RP (NOLOCK)   
                       WHERE RP.Wavekey = @c_Wavekey AND RP.OriginalFromLoc = 'ispRLWAV32')  
        BEGIN                                            
          SELECT @n_continue = 3    
          SELECT @n_err = 81020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to reverse. (ispRVWAV32)'           
        END                   
    END  
  
    ----reject if any task was started  
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN  
        IF EXISTS (SELECT 1 FROM REPLENISHMENT RP (NOLOCK)   
                   WHERE RP.Wavekey = @c_Wavekey AND RP.OriginalFromLoc = 'ispRLWAV32'
                   AND RP.Confirmed <> 'N')
        BEGIN  
          SELECT @n_continue = 3    
          SELECT @n_err = 81030    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV32)'         
        END                   
    END  
      
    BEGIN TRAN  
    	
    ----delete replenishment for 1=DPP picking
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveTypeLong = '1'  
    BEGIN  
       DECLARE CUR_REPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Replenishmentkey, FromLoc, ID
         FROM REPLENISHMENT (NOLOCK)
         WHERE Wavekey = @c_Wavekey
         AND OriginalFromLoc = 'ispRLWAV32'
         AND Confirmed = 'N'

       OPEN CUR_REPL  
         
       FETCH NEXT FROM CUR_REPL INTO @c_Replenishmentkey, @c_FromLoc, @c_FromID
         
       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
       BEGIN
       	  DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
       	     SELECT Pickdetailkey
       	     FROM WAVEDETAIL WD (NOLOCK) 
       	     JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
       	     JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
       	     WHERE WD.Wavekey = @c_Wavekey
       	     AND PD.ReplenishZone = @c_Replenishmentkey
       	     AND LOC.LocationType = 'DYNPPICK'
       	     AND PD.Status < '5'

          OPEN CUR_PICK  
       	     
          FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey
          
          WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
          BEGIN          	
          	 UPDATE PICKDETAIL WITH (ROWLOCK)
          	 SET Loc = @c_FromLoc,
          	     ID = @c_FromID,
          	     ReplenishZone = ''
          	 WHERE Pickdetailkey = @c_Pickdetailkey    
          	     
             SELECT @n_err = @@ERROR  
             
             IF @n_err <> 0   
             BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. Pickdetailkey:' + RTRIM(@c_Pickdetailkey)+ ' (ispRVWAV32)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
             END   
          	              	
             FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey          	
          END
          CLOSE CUR_PICK
          DEALLOCATE CUR_PICK
                                     	            	  
       	  DELETE FROM REPLENISHMENT 
       	  WHERE Replenishmentkey = @c_Replenishmentkey       	

          SELECT @n_err = @@ERROR  
          
          IF @n_err <> 0   
          BEGIN  
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Replenishment Table Failed. (ispRVWAV32)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
          END   
       	       	          	  
          FETCH NEXT FROM CUR_REPL INTO @c_Replenishmentkey, @c_FromLoc, @c_FromID
       END
       CLOSE CUR_REPL
       DEALLOCATE CUR_REPL    	   
    END  
    	           
    ----delete replenishment for 2=pick face picking
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveTypeLong = '2'  
    BEGIN  
       DECLARE CUR_REPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Replenishmentkey
         FROM REPLENISHMENT (NOLOCK)
         WHERE Wavekey = @c_Wavekey
         AND OriginalFromLoc = 'ispRLWAV32'
         AND Confirmed = 'N'

       OPEN CUR_REPL  
         
       FETCH NEXT FROM CUR_REPL INTO @c_Replenishmentkey
         
       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
       BEGIN
       	  DELETE FROM REPLENISHMENT 
       	  WHERE Replenishmentkey = @c_Replenishmentkey       	

          SELECT @n_err = @@ERROR  
          
          IF @n_err <> 0   
          BEGIN  
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Replenishment Table Failed. (ispRVWAV32)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
          END   
       	       	          	  
          FETCH NEXT FROM CUR_REPL INTO @c_Replenishmentkey
       END
       CLOSE CUR_REPL
       DEALLOCATE CUR_REPL    	   
    END  
                      
    -----Reverse wave status------  
    IF @n_continue = 1 or @n_continue = 2    
    BEGIN  
       --(Wan01) - START
       --UPDATE WAVE   
       --   SET STATUS = '0' -- Normal  
       --WHERE WAVEKEY = @c_wavekey 
      
       
       UPDATE WAVE
          SET TMReleaseFlag = 'N'               
           ,  TrafficCop = NULL                 
           ,  EditWho = SUSER_SNAME()          
           ,  EditDate= GETDATE()               
       WHERE WAVEKEY = @c_wavekey
       --(Wan01) - END
         
                 
       SELECT @n_err = @@ERROR    
       IF @n_err <> 0    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV32)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV32"    
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