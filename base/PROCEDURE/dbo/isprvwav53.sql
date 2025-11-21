SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRVWAV53                                         */  
/* Creation Date: 27-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19669 - CN - Columbia B2B Release Wave (Reverse)        */ 
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
/* 27-May-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispRVWAV53] 
     @c_Wavekey      NVARCHAR(10)  
   , @c_Orderkey     NVARCHAR(10) = ''
   , @b_Success      INT        OUTPUT  
   , @n_err          INT        OUTPUT  
   , @c_errmsg       NVARCHAR(250)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue        INT,    
           @n_starttcnt       INT,         -- Holds the current transaction count  
           @n_debug           INT,
           @n_cnt             INT,
           @c_Pickdetailkey   NVARCHAR(10),
           @c_UCCNo           NVARCHAR(50),
           @c_Pickslipno      NVARCHAR(10)
           
   SELECT @n_starttcnt = @@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0, @n_debug = 0

   ----reject if wave not yet release      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     IF NOT EXISTS (SELECT 1 FROM WAVE W (NOLOCK) 
                    WHERE W.Wavekey = @c_Wavekey
                    AND W.TMReleaseFlag IN ('Y')) 
     BEGIN
        SELECT @n_continue = 3  
        SELECT @n_err = 63115  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV53)'    
     END                 
   END

   ----reject if any task was started
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                 WHERE TD.Wavekey = @c_Wavekey
                 AND TD.Sourcetype IN ('ispRLWAV53')
                 AND TD.Status NOT IN ('0','X')
                 AND TD.Tasktype IN ('RPF'))
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 63120  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV53)'       
      END                 
   END

   ----Reject if pack confirmed
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM WAVEDETAIL WD (NOLOCK) 
                 JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = WD.OrderKey
                 WHERE WD.Wavekey = @c_Wavekey
                 AND PH.[Status] = '9' )
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 63121  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some orders were pack confirmed. Not allow to Reverse Wave Released (ispRVWAV53)'       
      END                 
   END
     
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   ----Update UCC.Status = 1
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT UCC.UCCNo
      FROM UCC (NOLOCK)
      JOIN TASKDETAIL TD (NOLOCK) ON UCC.UCCNo = TD.CaseID AND TD.Storerkey = UCC.Storerkey
      WHERE TD.WAVEKEY = @c_Wavekey 
      AND TD.TaskType = 'RPF' 
      AND TD.SourceType = 'ispRLWAV53'
      
      OPEN CUR_UCC
      
      FETCH NEXT FROM CUR_UCC INTO @c_UCCNo
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE UCC WITH (ROWLOCK)
         SET [Status] = '1'
         WHERE UCCNo = @c_UCCNo

         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63125   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 

         FETCH NEXT FROM CUR_UCC INTO @c_UCCNo
      END
      CLOSE CUR_UCC
      DEALLOCATE CUR_UCC
   END
                
   ----delete replenishment
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE TASKDETAIL
      WHERE TASKDETAIL.Wavekey = @c_Wavekey 
      AND TASKDETAIL.Sourcetype IN ('ispRLWAV53')
      AND TASKDETAIL.Tasktype IN ('RPF') 
      
      SELECT @n_err = @@ERROR

      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END
   
   ----Remove data from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK) 
       SET PICKDETAIL.TaskdetailKey = ''
         , PICKDETAIL.Pickslipno    = ''
         , PICKDETAIL.CaseID        = ''
         , PICKDETAIL.Notes         = ''
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
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63135   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END          
   END   
   
   --Delete pack data
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PH.Pickheaderkey
      FROM PICKHEADER PH (NOLOCK) 
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = PH.OrderKey
      JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'CSDEFLOC' 
                               AND CL.Storerkey = PD.Storerkey 
                               AND CL.Code = OH.Facility
                               AND CL.Long = PD.Loc
      WHERE PH.WaveKey = @c_Wavekey AND PD.UOM = '2'

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_Pickslipno

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM PACKDETAIL WHERE PickSlipNo = @c_Pickslipno

         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63136   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Packdetail Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
           GOTO RETURN_SP
         END      
         
         DELETE FROM PACKHEADER WHERE PickSlipNo = @c_Pickslipno

         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63136   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Packheader Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
           GOTO RETURN_SP
         END   

         DELETE FROM PICKHEADER WHERE PickHeaderKey = @c_Pickslipno

         SELECT @n_err = @@ERROR

         IF @n_err <> 0 
         BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63136   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickheader Failed. (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
           GOTO RETURN_SP
         END   

         FETCH NEXT FROM CUR_LOOP INTO @c_Pickslipno
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  
              
RETURN_SP:

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_UCC')) >=0 
   BEGIN
      CLOSE CUR_UCC           
      DEALLOCATE CUR_UCC      
   END 

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_LOOP')) >=0 
   BEGIN
      CLOSE CUR_LOOP           
      DEALLOCATE CUR_LOOP      
   END 

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRVWAV53'  
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