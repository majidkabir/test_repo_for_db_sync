SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRVWAV07                                              */
/* Creation Date: 21-FEB-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  WMS-1107 - CN-Nike SDC WMS Release Wave                    */
/*        :                                                             */
/* Called By: ReleaseWave_SP                                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 01-04-2020  Wan01    1.2   Sync Exceed & SCE                         */   
/************************************************************************/
CREATE PROC [dbo].[ispRVWAV07]
        @c_Wavekey      NVARCHAR(10)  
       ,@c_Orderkey     NVARCHAR(10) = ''
       ,@b_Success      INT            OUTPUT  
       ,@n_err          INT            OUTPUT  
       ,@c_errmsg       NVARCHAR(250)  OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_DispatchPiecePickMethod NVARCHAR(10)
         , @c_SourceType      NVARCHAR(30)
         , @c_PickDetailKey   NVARCHAR(10)
         , @c_TaskDetailKey   NVARCHAR(10)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_DispatchPiecePickMethod = ''
   SELECT @c_DispatchPiecePickMethod = ISNULL(RTRIM(DispatchPiecePickMethod),'')
   FROM WAVE WITH (NOLOCK)
   WHERE Wavekey = @c_Wavekey

   IF @c_DispatchPiecePickMethod NOT IN ('INLINE', 'DTC')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 81000
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid DispatchPiecePickMethod. (ispRVWAV07)'
      GOTO QUIT_SP
   END 

   SET @c_SourceType = 'ispRLWAV07-' + @c_DispatchPiecePickMethod

   IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Wavekey = @c_Wavekey
                  AND TD.Sourcetype = @c_SourceType
                  AND TD.Tasktype = 'RPF') 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 81010
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Released Task Not Found. (ispRVWAV07)'
      GOTO QUIT_SP
   END

   IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
               WHERE TD.Wavekey = @c_Wavekey
               AND TD.Sourcetype= @c_SourceType
               AND TD.Tasktype  = 'RPF'
               AND TD.Status <> '0' 
               AND TD.Status <> 'X') 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 81020
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Released Task is in progress. Reverse reject. (ispRVWAV07)'
      GOTO QUIT_SP
   END
   
   BEGIN TRAN

   -- Initialize TaskDetailKey & Wavekey in PickDetail
   DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PD.PickDetailKey
         ,PD.TaskDetailKey
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PD.Orderkey = WD.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey
   AND (ISNULL(PD.Taskdetailkey,'') <> '' OR ISNULL(PD.Wavekey,'') <> '')
   OPEN CUR_UPD

   FETCH NEXT FROM CUR_UPD INTO  @c_PickDetailKey
                              ,  @c_TaskDetailKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET TaskDetailKey = ''
         ,Wavekey       = ''
         ,TrafficCop    = NULL
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
      WHERE PickDetailkey = @c_PickDetailKey

      SET @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81030
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV07)' 
         GOTO QUIT_SP
      END 
      
      IF EXISTS ( SELECT 1
                  FROM TASKDETAIL WITH (NOLOCK)
                  WHERE TaskDetailkey = @c_TaskDetailkey
                  AND TaskType = 'RPF'
                  AND SourceType = @c_SourceType
                  AND Status = '0'
                 )
      BEGIN
         DELETE TASKDETAIL WITH (ROWLOCK)
         WHERE TaskDetailkey = @c_TaskDetailkey

         SET @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err = 81040
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': DELETE Taskdetail Table Failed. (ispRVWAV07)' 
            GOTO QUIT_SP
         END 
      END

      FETCH NEXT FROM CUR_UPD INTO  @c_PickDetailKey
                                 ,  @c_TaskDetailKey
   END            
   CLOSE CUR_UPD
   DEALLOCATE CUR_UPD

   -- Delete Residual from TASKDETAIL table
   DECLARE CUR_DEL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TD.TaskDetailKey
   FROM TASKDETAIL TD WITH (NOLOCK)
   WHERE Wavekey = @c_Wavekey
   AND TaskType  = 'RPF'
   AND SourceType = @c_SourceType
   AND Status = '0'

   OPEN CUR_DEL

   FETCH NEXT FROM CUR_DEL INTO  @c_TaskDetailKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE TASKDETAIL WITH (ROWLOCK)
      WHERE TaskDetailkey = @c_TaskDetailkey

      SET @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81100   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': DELETE Taskdetail Table Failed. (ispRVWAV07)' 
         GOTO QUIT_SP
      END 

      FETCH NEXT FROM CUR_DEL INTO  @c_TaskDetailKey
   END            
   CLOSE CUR_DEL
   DEALLOCATE CUR_DEL

   UPDATE WAVE WITH (ROWLOCK)
   
   --SET Status = '0' -- Released      --(Wan01)
   --   ,Trafficcop = NULL             --(Wan01)
   --   ,EditWho = SUSER_NAME()        --(Wan01)
   SET TMReleaseFlag = 'N'             --(Wan01) 
   ,  TrafficCop = NULL                --(Wan01) 
   ,  EditWho = SUSER_SNAME()          --(Wan01) 
   ,  EditDate= GETDATE()              --(Wan01)      
   WHERE Wavekey = @c_Wavekey 
   
   SET @n_err = @@ERROR
   IF @n_err <> 0 
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81100  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV07)' 
      GOTO QUIT_SP
   END     
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_UPD') in (0 , 1)  
   BEGIN
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_DEL') in (0 , 1)  
   BEGIN
      CLOSE CUR_DEL
      DEALLOCATE CUR_DEL
   END


   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRVWAV07'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO