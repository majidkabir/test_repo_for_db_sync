SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRVWAV50                                         */  
/* Creation Date: 12-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19079 - CN NIKE PHC RELEASE TASK (Reverse)              */ 
/*                                                                      */
/* Called By: Wave                                                      */ 
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 12-Apr-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispRVWAV50]      
     @c_wavekey      NVARCHAR(10)  
   , @c_Orderkey     NVARCHAR(10) = ''              
   , @b_Success      INT             OUTPUT  
   , @n_err          INT             OUTPUT  
   , @c_errmsg       NVARCHAR(250)   OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue     INT,    
           @n_starttcnt    INT,         -- Holds the current transaction count  
           @n_debug        INT,
           @n_cnt          INT
                  
   SELECT @n_starttcnt = @@TRANCOUNT , @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = '', @n_cnt = 0
   SELECT @n_debug = 0
   
   DECLARE @c_Storerkey       NVARCHAR(15)
          ,@c_Sku             NVARCHAR(20)
          ,@c_Lot             NVARCHAR(10)
          ,@c_ToLoc           NVARCHAR(10)
          ,@c_ToID            NVARCHAR(18)
          ,@n_Qty             INT
          ,@c_Taskdetailkey   NVARCHAR(10)
          ,@c_facility        NVARCHAR(5)  
          ,@c_authority       NVARCHAR(10)
          ,@c_FromLoc         NVARCHAR(10)
          ,@c_FromID          NVARCHAR(18)    
          ,@c_AllTaskType     NVARCHAR(500)

   SELECT TOP 1 @c_StorerKey = O.Storerkey,
                @c_Facility  = O.Facility 
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey  
   
   BEGIN TRAN

   ----reject if wave not yet release      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     IF NOT EXISTS (SELECT 1 FROM WAVE W (NOLOCK) 
                    WHERE W.Wavekey = @c_Wavekey
                    AND W.TMReleaseFlag IN ('Y')) 
     BEGIN
        SELECT @n_continue = 3  
        SELECT @n_err = 61040  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV50)'    
     END                 
   END

   --reject if any task was started
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                 WHERE TD.Wavekey = @c_Wavekey
                 AND TD.Sourcetype = 'ispRLWAV50'
                 AND TD.Tasktype IN ('RPF')
                 AND TD.[Status] NOT IN ('0','H'))
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 61045  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV50)'       
      END                 
   END

   --delete tasks
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE TASKDETAIL
      WHERE TASKDETAIL.Wavekey = @c_Wavekey 
      AND TASKDETAIL.Sourcetype = 'ispRLWAV50'
      AND TASKDETAIL.Tasktype IN ('RPF')
      AND TASKDETAIL.[Status] IN ('0','H')
        
      SELECT @n_err = @@ERROR

      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 61050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END
         
   --Remove taskdetailkey from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK) 
      SET PICKDETAIL.TaskdetailKey  = '',
          PICKDETAIL.TrafficCop     = NULL,
          PICKDETAIL.EditDate       = GETDATE(),
          PICKDETAIL.EditWho        = SUSER_SNAME()
      FROM WAVEDETAIL (NOLOCK)  
      JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
        
      SELECT @n_err = @@ERROR

      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 61055   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END          
   END

   --Remove CaseID from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK) 
       SET PICKDETAIL.CaseID      = ''
         , PICKDETAIL.TrafficCop  = NULL
         , PICKDETAIL.EditWho     = SUSER_SNAME()
         , PICKDETAIL.EditDate    = GETDATE()
         --, PICKDETAIL.DropID      = ''
         --, PICKDETAIL.MoveRefKey  = ''
      FROM WAVEDETAIL (NOLOCK)  
      JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 61060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END          
   END     
   
   --Delete Replenishment
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE dbo.REPLENISHMENT
      WHERE REPLENISHMENT.Wavekey = @c_Wavekey 
      AND REPLENISHMENT.RefNo = 'ispRLWAV50'
      AND REPLENISHMENT.Confirmed = 'N'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 61060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Replenishment Table Failed. (ispRVWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END          
   END  
   
   -----Reverse wave status------
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE WAVE 
      SET TMReleaseFlag = 'N'      
       ,  TrafficCop    = NULL        
       ,  EditWho       = SUSER_SNAME()  
       ,  EditDate      = GETDATE() 
      WHERE WAVEKEY = @c_wavekey  

      SELECT @n_err = @@ERROR
        
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 61065   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV50)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRVWAV50'  
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