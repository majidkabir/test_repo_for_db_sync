SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRVWAV55                                         */  
/* Creation Date: 25-Aug-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20606 - ID-PUMA-Replenishment Strategy - Reverse        */ 
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
/* 25-Aug-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispRVWAV55]      
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
          ,@c_Pickdetailkey   NVARCHAR(10)
          ,@c_facility        NVARCHAR(5)  
          ,@c_authority       NVARCHAR(10)
          ,@c_FromLoc         NVARCHAR(10)
          ,@c_FromID          NVARCHAR(18)    
          ,@c_AllTaskType     NVARCHAR(500)
          ,@c_Pickslipno      NVARCHAR(10)

   SELECT TOP 1 @c_StorerKey = O.Storerkey,
                @c_Facility  = O.Facility 
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey  

   --Reject if wave not yet release      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     IF NOT EXISTS (SELECT 1 FROM WAVE W (NOLOCK) 
                    WHERE W.Wavekey = @c_Wavekey
                    AND W.TMReleaseFlag IN ('Y'))
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 67715    
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV55)'     
         GOTO QUIT_SP 
      END                
   END

   --Reject if any task was confirmed
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM REPLENISHMENT RP (NOLOCK) 
                 WHERE RP.Wavekey = @c_Wavekey
                 AND RP.Confirmed = 'Y')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 67720  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Replenishment have been confirmed. ' +
                          + 'Not allow to Reverse Wave Released (ispRVWAV55)'       
      END                 
   END

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   --Delete REPLENISHMENT tasks
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE dbo.REPLENISHMENT
      WHERE REPLENISHMENT.Wavekey = @c_Wavekey 
      AND REPLENISHMENT.Confirmed = 'N'
        
      SELECT @n_err = @@ERROR

      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67725   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete REPLENISHMENT Table Failed. (ispRVWAV55)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END

   ----Remove data from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK) 
      SET PICKDETAIL.Pickslipno    = ''
        , PICKDETAIL.DropID        = ''
        , PICKDETAIL.TrafficCop    = NULL
        , PICKDETAIL.EditDate      = GETDATE()
        , PICKDETAIL.EditWho       = SUSER_SNAME()
      FROM WAVEDETAIL (NOLOCK)  
      JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
      
      SELECT @n_err = @@ERROR

      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67726   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END          
   END   
   
   --Delete PICKHEADER data
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PH.Pickheaderkey
      FROM PICKHEADER PH (NOLOCK) 
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = PH.OrderKey
      WHERE WD.WaveKey = @c_Wavekey

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_Pickslipno

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM PICKHEADER WHERE PickHeaderKey = @c_Pickslipno

         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67727   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickheader Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
           GOTO QUIT_SP
         END   

         FETCH NEXT FROM CUR_LOOP INTO @c_Pickslipno
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   --Delete PICKHEADER BY WAVE data
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      DECLARE CUR_LOOP_WAVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PH.PickHeaderKey
      FROM PICKHEADER PH (NOLOCK) 
      WHERE PH.WaveKey = @c_Wavekey

      OPEN CUR_LOOP_WAVE

      FETCH NEXT FROM CUR_LOOP_WAVE INTO @c_Pickslipno

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM PICKHEADER WHERE PickHeaderKey = @c_Pickslipno

         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67727   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickheader Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
           GOTO QUIT_SP
         END   

         FETCH NEXT FROM CUR_LOOP_WAVE INTO @c_Pickslipno
      END
      CLOSE CUR_LOOP_WAVE
      DEALLOCATE CUR_LOOP_WAVE
   END

   --Delete RefKeyLookup data
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      DECLARE CUR_RKL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PD.PickDetailKey
      FROM PICKDETAIL PD (NOLOCK) 
      JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = PD.OrderKey
      WHERE WD.WaveKey = @c_Wavekey

      OPEN CUR_RKL

      FETCH NEXT FROM CUR_RKL INTO @c_Pickdetailkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM RefKeyLookup WHERE PickDetailkey = @c_Pickdetailkey

         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67728   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete RefKeyLookup Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
           GOTO QUIT_SP
         END   

         FETCH NEXT FROM CUR_RKL INTO @c_Pickdetailkey
      END
      CLOSE CUR_RKL
      DEALLOCATE CUR_RKL
   END

   -----Reverse wave status------
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      UPDATE WAVE 
      SET TMReleaseFlag = 'N'      
       ,  TrafficCop    = NULL        
       ,  EditWho       = SUSER_SNAME()  
       ,  EditDate      = GETDATE() 
      WHERE WAVEKEY = @c_Wavekey  

      SELECT @n_err = @@ERROR
        
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67730   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV55)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END 
   
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
                  
   QUIT_SP:
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_LOOP')) >=0 
   BEGIN
      CLOSE CUR_LOOP           
      DEALLOCATE CUR_LOOP      
   END 

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_RKL')) >=0 
   BEGIN
      CLOSE CUR_RKL           
      DEALLOCATE CUR_RKL      
   END
   
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_LOOP_WAVE')) >=0 
   BEGIN
      CLOSE CUR_LOOP_WAVE           
      DEALLOCATE CUR_LOOP_WAVE      
   END 
   
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRVWAV55'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      --RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      --RETURN  
   END   
   
   WHILE @@TRANCOUNT < @n_starttcnt
      BEGIN TRAN
END --sp end

GO