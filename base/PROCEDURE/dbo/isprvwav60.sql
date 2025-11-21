SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRVWAV60                                          */  
/* Creation Date: 22-MAY-2023                                            */  
/* Copyright: MAERSK                                                     */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-22603 MY Puma Reverse Released wave                      */
/*                                                                       */  
/* Called By: Wave                                                       */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver   Purposes                                  */  
/* 22-MAY-2023  NJOW     1.0   DevOps Combine Script                     */
/*************************************************************************/ 

CREATE   PROCEDURE [dbo].[ispRVWAV60]      
    @c_wavekey      NVARCHAR(10)  
   ,@c_Orderkey     NVARCHAR(10) = ''              
   ,@b_Success      INT             OUTPUT  
   ,@n_err          INT             OUTPUT  
   ,@c_errmsg       NVARCHAR(250)   OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,    
           @n_starttcnt     INT,         -- Holds the current transaction count  
           @n_debug         INT,
           @n_cnt           INT,
           @c_authority     NVARCHAR(30),
           @c_Pickdetailkey NVARCHAR(10),         
           @c_Taskdetailkey NVARCHAR(10)
                  
   SELECT @n_starttcnt = @@TRANCOUNT , @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = '', @n_cnt = 0
   SELECT @n_debug = 0
   
   DECLARE @c_Storerkey       NVARCHAR(15)
          ,@c_facility        NVARCHAR(5)  

   SELECT TOP 1 @c_StorerKey = O.Storerkey,
                @c_Facility = O.Facility 
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey  

   ----reject if wave not yet release      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                     WHERE TD.Wavekey = @c_Wavekey AND TD.SourceType = 'ispRLWAV60'
                     AND TD.TaskType IN ('RPF') 
                     )
      BEGIN                                          
         SELECT @n_continue = 3  
         SELECT @n_err = 81010  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV60)'         
      END                 
   END

   ----reject if any task was started
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                 WHERE TD.Wavekey = @c_Wavekey
                 AND TD.Sourcetype = 'ispRLWAV60'
                 AND TD.TaskType IN ('RPF')
                 AND TD.Status <> '0')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 81020  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV60)'       
      END                 
   END
   
   BEGIN TRAN
         
   ----delete tasks
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_TASKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Taskdetailkey 
         FROM TASKDETAIL (NOLOCK)
         WHERE Wavekey = @c_Wavekey
         AND SourceType = 'ispRLWAV60'
         AND Status = '0'
         AND TaskType IN ('RPF')

      OPEN CUR_TASKDET  
      
      FETCH NEXT FROM CUR_TASKDET INTO @c_Taskdetailkey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN    
      	 DELETE FROM TASKDETAIL
      	 WHERE Taskdetailkey = @c_Taskdetailkey

         SELECT @n_err = @@ERROR
         
         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV60)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 
      	 
         FETCH NEXT FROM CUR_TASKDET INTO @c_Taskdetailkey
      END
      CLOSE CUR_TASKDET
      DEALLOCATE CUR_TASKDET          
   END
         
   ----Remove taskdetailkey from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_PICKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Pickdetailkey 
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
         WHERE WD.Wavekey = @c_Wavekey

      OPEN CUR_PICKDET  
      
      FETCH NEXT FROM CUR_PICKDET INTO @c_Pickdetailkey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN    
      	 UPDATE PICKDETAIL WITH (ROWLOCK)
      	 SET Taskdetailkey = '',
      	     TrafficCop = NULL
      	 WHERE Pickdetailkey = @c_Pickdetailkey

         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV60)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END          
      	 
         FETCH NEXT FROM CUR_PICKDET INTO @c_Pickdetailkey
      END                 
      CLOSE CUR_PICKDET
      DEALLOCATE CUR_PICKDET                       
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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV60)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRVWAV60'  
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