SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: mspRVWAV02                                          */    
/* Creation Date: 2024-05-15                                             */
/* Copyright: Maersk                                                     */    
/* Written by: Supriya Sangeetham                                        */    
/*                                                                       */    
/* Purpose: UWP-18823 - cancel replenishment post wave cancellation      */  
/*                                                                       */  
/*                                                                       */    
/* Called By: Wave Release                                               */    
/*                                                                       */    
/* PVCS Version: 1.0                                                     */    
/*                                                                       */    
/* Version: 7.0                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date        Author   Ver   Purposes                                   */
/* 2024-11-11  SSA01    1.1   Updated to restrict release for already    */
/*                            started tasks                              */
/*************************************************************************/     
CREATE   PROCEDURE [dbo].[mspRVWAV02]        
 @c_wavekey      NVARCHAR(10) 
,@c_Orderkey     NVARCHAR(10) = ''     
,@b_Success      int             OUTPUT    
,@n_err          int             OUTPUT    
,@c_errmsg       NVARCHAR(250)   OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
      
   DECLARE @n_continue       int = 1      
         , @n_starttcnt      int = @@TRANCOUNT        -- Holds the current transaction count    
         , @n_debug          int = 0  
         , @n_cnt            INT = 0  
         , @c_otherwavekey   NVARCHAR(10) = '' 
         , @c_TaskType       NVARCHAR(10) = 'RPF'
         , @n_AllowToRev     INT          = 0  
         , @c_Storerkey      NVARCHAR(15) = '' 
         , @c_facility       NVARCHAR(5)  = ''  
         , @c_Taskdetailkey  NVARCHAR(10) = '' 
         , @c_PickDetailKey  NVARCHAR(10) = '' 
         , @c_authority      NVARCHAR(10) = '' 
         , @c_SourceType     NVARCHAR(30) = 'mspRLWAV02'
         , @CUR_DELTASK      CURSOR
         , @CUR_DELPICK      CURSOR
                     
   SET @b_success=0
   SET @n_err=0
   SET @c_errmsg=''
   SET @n_cnt=0  

   -----Get Storerkey and facility 
   SELECT TOP 1 @c_StorerKey = O.Storerkey,  
               @c_Facility = O.Facility   
   FROM WAVEDETAIL WD (NOLOCK)  
   JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)  
   WHERE WD.Wavekey = @c_Wavekey    
  
   ----reject if wave not yet release        
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                     WHERE TD.Wavekey = @c_Wavekey AND TD.SourceType = @c_SourceType
                     AND TD.TaskType = @c_TaskType)  
      BEGIN                                            
         SET @n_continue = 3    
         SET @n_err = 81010    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (mspRVWAV02)'           
      END                   
   END  
  
   ----reject if any task was started  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN
    --(SSA01)
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)
                     WHERE TD.Wavekey = @c_Wavekey
                     AND  TD.Sourcetype = @c_SourceType
                     AND  TD.TaskType = @c_TaskType
                     AND  TD.[Status]  NOT IN ('0','X'))
      BEGIN
          SET @n_continue = 3    
          SET @n_err = 81020    
          SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (mspRVWAV02)'         
      END                   
   END  
      
   BEGIN TRAN  
            
   ----delete tasks  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      SET @CUR_DELTASK = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT TaskDetailKey = CASE WHEN TD.TaskType = @c_TaskType AND TD.[Status] IN ('0','X') 
                                 THEN TD.TaskDetailkey
                                 ELSE ''
                                 END
      FROM TASKDETAIL TD (NOLOCK)   
      WHERE TD.Wavekey = @c_Wavekey  
      AND  TD.Sourcetype = @c_SourceType 
      AND  TD.TaskType = @c_TaskType
      AND  TD.[Status] IN ('0','X')
      ORDER BY 1 DESC

      OPEN @CUR_DELTASK

      FETCH NEXT FROM @CUR_DELTASK INTO @c_TaskDetailKey

      WHILE @@FETCH_STATUS = 0 AND @c_TaskDetailKey <> '' AND @n_Continue = 1
      BEGIN
         DELETE TASKDETAIL  
         WHERE TASKDETAIL.TaskDetailKey = @c_TaskDetailKey   
         AND TASKDETAIL.Sourcetype = @c_SourceType 
         AND TASKDETAIL.TaskType = @c_TaskType 
         AND TASKDETAIL.Status IN ('0','X') 
           
         SET @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (mspRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END 
         FETCH NEXT FROM @CUR_DELTASK INTO @c_TaskDetailKey
      END
      CLOSE @CUR_DELTASK
      DEALLOCATE @CUR_DELTASK
   END  
            
   ----Remove taskdetailkey from pickdetail of the wave  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      SET @CUR_DELPICK = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey = PICKDETAIL.PickDetailKey
      FROM WAVEDETAIL (NOLOCK)    
      JOIN PICKDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey  
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey
      ORDER BY PICKDETAIL.PickDetailKey

      OPEN @CUR_DELPICK

      FETCH NEXT FROM @CUR_DELPICK INTO @c_PickDetailKey

      WHILE @@FETCH_STATUS = 0 AND @c_PickDetailKey <> '' AND @n_Continue = 1
      BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK)   
            SET PICKDETAIL.TaskdetailKey = ''   
               ,TrafficCop = NULL  
         WHERE PICKDETAIL.PickDetailKey = @c_PickDetailKey   
           
         SET @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (mspRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END 
         FETCH NEXT FROM @CUR_DELPICK INTO @c_PickDetailKey
      END
      CLOSE @CUR_DELPICK
      DEALLOCATE @CUR_DELPICK
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
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (mspRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
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
      SET @b_success = 0    
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
      execute nsp_logerror @n_err, @c_errmsg, "mspRVWAV02"    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SET @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END       
END --sp end  

GO