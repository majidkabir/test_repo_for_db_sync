SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/    
/* Stored Procedure: ispRVWAV44                                             */    
/* Creation Date: 22-JUL-2021                                               */    
/* Copyright: LFL                                                           */    
/* Written by: WLChooi                                                      */    
/*                                                                          */    
/* Purpose: WMS-17548 - CN LULULEMON Reverse Wave Release                   */  
/*                                                                          */    
/* Called By: Wave                                                          */    
/*                                                                          */    
/* GitLab Version: 1.0                                                      */    
/*                                                                          */    
/* Version: 7.0                                                             */    
/*                                                                          */    
/* Data Modifications:                                                      */    
/*                                                                          */    
/* Updates:                                                                 */    
/* Date        Author   Ver  Purposes                                       */    
/****************************************************************************/        
CREATE PROCEDURE [dbo].[ispRVWAV44]          
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
           @c_Replenishmentkey NVARCHAR(10),  
           @c_Loadkey NVARCHAR(10),  
           @c_authority NVARCHAR(30)  
                      
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0    
   SELECT @n_debug = 0    
       
   DECLARE @c_Storerkey    NVARCHAR(15)    
          ,@c_facility     NVARCHAR(5)      
          ,@c_WaveType     NVARCHAR(10)  
   
   SELECT TOP 1 @c_Storerkey     = O.Storerkey,   
                @c_Facility      = O.Facility,  
                @c_WaveType      = W.Wavetype     
   FROM WAVE W (NOLOCK)  
   JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey  
   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
   AND W.Wavekey = @c_Wavekey   
         
   ----reject if wave not yet release     
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      IF NOT EXISTS (SELECT 1 FROM REPLENISHMENT RP (NOLOCK)     
                     WHERE RP.Wavekey = @c_Wavekey AND RP.OriginalFromLoc = 'ispRLWAV44')                   
      BEGIN                                              
         SELECT @n_continue = 3      
         SELECT @n_err = 81010      
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to reverse. (ispRVWAV44)'             
      END                     
   END    
   
   ----reject if any task was started    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      IF EXISTS (SELECT 1 FROM REPLENISHMENT RP (NOLOCK)
                 WHERE RP.Wavekey = @c_Wavekey AND RP.OriginalFromLoc = 'ispRLWAV44'  
                 AND RP.Confirmed <> 'N')  
      BEGIN    
         SELECT @n_continue = 3      
         SELECT @n_err = 81020      
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV44)'           
      END                     
   END    
       
   BEGIN TRAN    
      
   ----delete replenishment   
   IF (@n_continue = 1 OR @n_continue = 2)   
   BEGIN    
      DECLARE CUR_REPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Replenishmentkey  
         FROM REPLENISHMENT (NOLOCK)  
         WHERE Wavekey = @c_Wavekey  
         AND OriginalFromLoc = 'ispRLWAV44'  
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
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Replenishment Table Failed. (ispRVWAV44)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
         END     
           
         UPDATE PICKDETAIL WITH (ROWLOCK)  
         SET PICKDETAIL.MoveRefkey = '',  
             PICKDETAIL.TrafficCop = NULL  
         FROM WAVEDETAIL (NOLOCK)  
         JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey  
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey  
         AND PICKDETAIL.MoveRefkey = @c_Replenishmentkey   
 
         SELECT @n_err = @@ERROR    
           
         IF @n_err <> 0     
         BEGIN    
            SELECT @n_continue = 3      
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81031   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV44)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
         END     
                              
         FETCH NEXT FROM CUR_REPL INTO @c_Replenishmentkey  
      END  
      CLOSE CUR_REPL  
      DEALLOCATE CUR_REPL          
   END    
                                                                                
   -----Reverse wave status------    
   IF @n_continue = 1 or @n_continue = 2      
   BEGIN                
      UPDATE WAVE  
      SET TMReleaseFlag = 'N'                 
       ,  TrafficCop = NULL                   
       ,  EditWho = SUSER_SNAME()            
       ,  EditDate= GETDATE()                 
      WHERE WAVEKEY = @c_wavekey           
                  
      SELECT @n_err = @@ERROR      
      IF @n_err <> 0      
      BEGIN      
         SELECT @n_continue = 3      
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV44)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV44"      
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