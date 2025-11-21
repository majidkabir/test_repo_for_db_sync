SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: nspLPVTSK13                                         */  
/* Creation Date: 02-Sep-2024                                            */  
/* Copyright: MAERSK                                                     */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-26098 - [AU] HPAU XDock Pick Tasks Wave - Reverse        */
/*                                                                       */  
/* Called By: Load                                                       */  
/*                                                                       */  
/* Github Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 02-Sep-2024  WLChooi  1.0  DevOps Combine Script                      */
/*************************************************************************/  
CREATE   PROCEDURE [dbo].[nspLPVTSK13]    
    @c_Loadkey      NVARCHAR(10)  
  , @b_Success      INT            OUTPUT  
  , @n_Err          INT            OUTPUT  
  , @c_Errmsg       NVARCHAR(250)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE @n_Continue        INT    
         , @n_StartTCnt       INT         -- Holds the current transaction count  
         , @n_debug           INT
         , @n_cnt             INT
         , @c_Taskdetailkey   NVARCHAR(10) = ''
         , @c_SourceType      NVARCHAR(20) = 'nspLPRTSK13'
            
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @b_success = 1, @n_Err = 0, @c_Errmsg = '', @n_cnt = 0
   SELECT @n_debug = 0

   ----reject if load not yet release      
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                      WHERE TD.Loadkey = @c_Loadkey 
                      AND TD.SourceType = @c_SourceType)
      BEGIN
         SELECT @n_Continue = 3  
         SELECT @n_err = 81010  
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err) + ': This Load has not been released. (nspLPVTSK13)'         
      END                 
   END

   ----reject if any task was started
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF EXISTS ( SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Loadkey = @c_Loadkey
                  AND TD.Sourcetype = @c_SourceType
                  AND TD.[Status] <> '0' )
      BEGIN
         SELECT @n_Continue = 3  
         SELECT @n_err = 81020  
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err) + ': Some Tasks have been started. Not allow to Reverse Load Released (nspLPVTSK13)'       
      END                 
   END

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      BEGIN TRAN

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TD.Taskdetailkey
      FROM TASKDETAIL TD (NOLOCK)
      WHERE TD.LoadKey = @c_Loadkey
      AND TD.SourceType = @c_SourceType
      AND TD.[Status] = '0'

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_Taskdetailkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM dbo.TaskDetail
         WHERE TaskDetailKey = @c_Taskdetailkey

         SET @n_Err = @@ERROR

         IF @n_Err <> 0    
         BEGIN  
            SELECT @n_Continue = 3    
            SELECT @c_Errmsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_Errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ': Delete Taskdetail Failed. (nspLPVTSK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_Errmsg) + ' ) '    
            
            GOTO QUIT_SP  
         END

         FETCH NEXT FROM CUR_LOOP INTO @c_Taskdetailkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END

   ----Remove taskdetailkey from pickdetail of the load
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      BEGIN TRAN

      UPDATE PICKDETAIL WITH (ROWLOCK) 
       SET PICKDETAIL.TaskdetailKey = '',
          TrafficCop = NULL
      FROM LOADPLANDETAIL (NOLOCK)  
      JOIN PICKDETAIL ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey
      WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey 
      
      SELECT @n_err = @@ERROR

      IF @n_err <> 0 
      BEGIN
        SELECT @n_Continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (nspLPVTSK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
        
        GOTO QUIT_SP 
      END
      
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END  

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_Err, @c_Errmsg, 'nspLPVTSK13'  
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END   
   END    
   
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN
END --sp end

GO