SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: ispRVWAV42                                          */    
/* Creation Date: 27-May-2021                                            */    
/* Copyright: LFL                                                        */    
/* Written by: WLChooi                                                   */   
/*                                                                       */    
/* Purpose: WMS-17089 - [CN] Coach - Reverse Wave Released               */      
/*                                                                       */    
/* Called By: Wave                                                       */    
/*                                                                       */    
/* GitLab Version: 1.0                                                   */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/*************************************************************************/     
CREATE PROCEDURE [dbo].[ispRVWAV42]      
    @c_wavekey      NVARCHAR(10)  
   ,@c_Orderkey     NVARCHAR(10) = ''
   ,@b_Success      INT            OUTPUT    
   ,@n_err          INT            OUTPUT    
   ,@c_errmsg       NVARCHAR(250)  OUTPUT    
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE @n_continue  INT,    
           @n_starttcnt INT,         -- Holds the current transaction count  
           @n_debug     INT,
           @n_cnt       INT
            
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
   SELECT @n_debug = 0
    
   DECLARE @c_Storerkey NVARCHAR(15)
          ,@c_Sku NVARCHAR(20)
          ,@c_Lot NVARCHAR(10)
          ,@c_ToLoc NVARCHAR(10)
          ,@c_ToID NVARCHAR(18)
          ,@n_Qty INT
          ,@c_Taskdetailkey NVARCHAR(10)
          ,@c_GetOrderkey NVARCHAR(10)
          ,@c_GetStorerkey NVARCHAR(15)

   --reject if wave not yet release      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                     WHERE TD.Wavekey = @c_Wavekey
                     AND TD.Sourcetype IN ('ispRLWAV42')
                     AND TD.Tasktype IN ('RPF','FCP'))
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 81010  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV42)'         
      END                 
   END

   --reject if any task was started
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype IN ('ispRLWAV42')
                   AND TD.[Status] NOT IN ('0', 'X')
                   AND TD.Tasktype IN ('RPF','FCP'))
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 81020  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV42)'       
      END                 
   END
    
   BEGIN TRAN

   --Delete Pickheader 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_Orders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OH.OrderKey, OH.StorerKey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = WD.OrderKey
      WHERE WD.Wavekey = @c_wavekey
   
      OPEN CUR_Orders
   
      FETCH NEXT FROM CUR_Orders INTO @c_GetOrderkey, @c_GetStorerkey
   
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM PICKHEADER
         WHERE OrderKey = @c_GetOrderkey AND Storerkey = @c_GetStorerkey
   
         FETCH NEXT FROM CUR_Orders INTO @c_GetOrderkey, @c_GetStorerkey
      END
      CLOSE CUR_Orders
      DEALLOCATE CUR_Orders   
   END
               
   --delete replenishment
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE TASKDETAIL
      WHERE TASKDETAIL.Wavekey = @c_Wavekey 
      AND TASKDETAIL.Sourcetype IN ('ispRLWAV42')
      AND TASKDETAIL.Tasktype IN ('RPF','FCP')
        
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV42)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END
   
   --Remove taskdetailkey from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK) 
      SET TaskdetailKey = ''
        , TrafficCop    = NULL
        , EditWho       = SUSER_SNAME()           
        , EditDate      = GETDATE()  
      FROM WAVEDETAIL (NOLOCK)  
      JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
        
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV42)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END          
   END    
   
   --Update status back to 2
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_GetOrderkey = ''
      
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Orderkey
      FROM WAVEDETAIL (NOLOCK)
      WHERE Wavekey = @c_wavekey
   
      OPEN CUR_LOOP
   
      FETCH NEXT FROM CUR_LOOP INTO @c_GetOrderkey
   
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE ORDERS
         SET [Status] = CASE WHEN [Status] = '3' THEN '2' ELSE [Status] END
         WHERE Orderkey = @c_GetOrderkey
   
         FETCH NEXT FROM CUR_LOOP INTO @c_GetOrderkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END    
   
   --Reverse wave status
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV42)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  
   
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP    
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_Orders') IN (0 , 1)
   BEGIN
      CLOSE CUR_Orders
      DEALLOCATE CUR_Orders    
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV42"  
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