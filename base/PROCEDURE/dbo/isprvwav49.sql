SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRVWAV49                                          */  
/* Creation Date: 26-Jan-2022                                            */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-18741 - [TW]LOR_WaveReleaseTask_CR - Reverse             */
/*          Copy and modified from ispRVWAV15                            */  
/*                                                                       */  
/* Called By: Wave                                                       */  
/*                                                                       */  
/* GitLab Version: 1.1                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver   Purposes                                  */  
/* 26-Jan-2022  WLChooi  1.0   DevOps Combine Script                     */
/* 29-Apr-2022  WLChooi  1.1   Bug Fix - Fix TaskType = FCP for non PTL  */
/*                             (WL01)                                    */
/*************************************************************************/ 

CREATE PROCEDURE [dbo].[ispRVWAV49]      
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
   
   DECLARE @n_continue     INT,    
           @n_starttcnt    INT,         -- Holds the current transaction count  
           @n_debug        INT,
           @n_cnt          INT,
           @c_otherwavekey NVARCHAR(10)
                  
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
                @c_Facility = O.Facility 
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey  

   SELECT @c_AllTaskType = STUFF((SELECT DISTINCT ',' + RTRIM(CL.code2) 
                                  FROM CODELKUP CL (NOLOCK)
                                  WHERE CL.Listname = 'LORBRAND' AND CL.Storerkey = @c_Storerkey
                                  ORDER BY 1 FOR XML PATH('')),1,1,'' )
   
   ----reject if wave not yet release      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                     WHERE TD.Wavekey = @c_Wavekey AND TD.SourceType = 'ispRLWAV49'
                     AND (TD.Tasktype IN (SELECT DISTINCT ColValue FROM dbo.fnc_DelimSplit(',', @c_AllTaskType)) 
                          OR TD.TaskType IN ('FCP') )   --WL01
                     )
      BEGIN                                          
         SELECT @n_continue = 3  
         SELECT @n_err = 81010  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV49)'         
      END                 
   END

   ----reject if any task was started
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                 WHERE TD.Wavekey = @c_Wavekey
                 AND TD.Sourcetype = 'ispRLWAV49'
                 AND (TD.Tasktype IN (SELECT DISTINCT ColValue FROM dbo.fnc_DelimSplit(',', @c_AllTaskType))
                      OR TD.TaskType IN ('FCP') )   --WL01
                 AND TD.Status <> '0')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 81020  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV49)'       
      END                 
   END
   
   BEGIN TRAN
         
   ----delete tasks
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE TASKDETAIL
      WHERE TASKDETAIL.Wavekey = @c_Wavekey 
      AND TASKDETAIL.Sourcetype = 'ispRLWAV49'
      AND (TASKDETAIL.Tasktype IN (SELECT DISTINCT ColValue FROM dbo.fnc_DelimSplit(',', @c_AllTaskType))
           OR TASKDETAIL.TaskType IN ('FCP') )   --WL01
      AND TASKDETAIL.Status = '0'
        
      SELECT @n_err = @@ERROR

      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV49)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV49)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
        END          
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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV49)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRVWAV49'  
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