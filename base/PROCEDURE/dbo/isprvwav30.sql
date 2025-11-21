SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRVWAV30                                              */
/* Creation Date: 03-SEPT-2019                                          */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  WMS-10158 - NIKE - PH Wave Release Task Enhancement        */
/*        :                                                             */
/* Called By: ReverseWave_SP                                            */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2019-10-16  Wan01    1.1   Delete Taskdetail Handling at Custom SP   */
/*                            ispTSKD05 Call from Delete Trigger        */
/* 2020-03-23  Wan02    1.2   WMS-12136 - NIKE - PH Cartonization       */
/* 2020-03-30  Wan03    1.2   WMS-12269 - [PH] - NIKE - Picking Task    */
/*                            Dispatch                                  */  
/* 2020-04-01  Wan04    1.3   Sync Exceed & SCE                         */   
/************************************************************************/
CREATE PROC [dbo].[ispRVWAV30]
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

         , @c_SourceType_Repl NVARCHAR(30) = 'ispRLWAV20-REPLEN'  --Wan01
         , @c_Wavekey_Share   NVARCHAR(10) = ''                   --Wan01                      
         , @c_UOM             NVARCHAR(10) = ''                   --Wan01
         , @b_Delete          BIT = 0                             --Wan01

         , @c_SourceType_CPK  NVARCHAR(30) = 'ispRLWAV20-CPK'     --(Wan02)
         , @c_TaskType        NVARCHAR(10) = ''                   --(Wan02)
         , @c_PickSlipNo      NVARCHAR(10) = ''                   --(Wan02)
         , @n_CartonNo        INT          = 0                    --(Wan02)
         , @c_LabelNo         NVARCHAR(20) = ''                   --(Wan02)
         , @c_LabelLine       NVARCHAR(5) = ''                    --(Wan02)

         , @CUR_TD            CURSOR                
         , @CUR_PD            CURSOR    
         
         , @CUR_DELPCK        CURSOR                              --(Wan02)  

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
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid DispatchPiecePickMethod. (ispRVWAV30)'
      GOTO QUIT_SP
   END 

   SET @c_SourceType= 'ispRLWAV20-' + @c_DispatchPiecePickMethod          

   --(Wan03) - START
   IF NOT EXISTS (SELECT TOP 1 TD.Tasktype FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Wavekey = @c_Wavekey
                  AND TD.Sourcetype IN ( @c_SourceType, @c_SourceType_Repl )     --(Wan01) 
                  AND TD.Tasktype = 'RPF'
                  UNION
                  SELECT TOP 1 TD.Tasktype FROM TASKDETAIL TD (NOLOCK) 
                  WHERE TD.Wavekey = @c_Wavekey
                  AND TD.Sourcetype IN ( @c_SourceType_CPK )     
                  AND TD.Tasktype = 'CPK'
                  ) 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 81010
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Released Task Not Found. (ispRVWAV30)'
      GOTO QUIT_SP
   END

   --(Wan03) - START 
   --IF EXISTS ( SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
   --            WHERE TD.Wavekey = @c_Wavekey
   --            AND   TD.Sourcetype IN ( @c_SourceType, @c_SourceType_Repl )      --(Wan01)     
   --            AND   TD.Tasktype  = 'RPF'
   --            AND   TD.Status <> '0' 
   --            AND   TD.Status <> 'X') 
   --            )  
   IF (  SELECT ISNULL(MAX(CASE WHEN Tasktype  = 'RPF' THEN 1 
                      WHEN TaskType  = 'CPK' AND TD.Status <> 'H' THEN 1
                      ELSE 0 END),0)
         FROM TASKDETAIL TD (NOLOCK)   
         WHERE TD.Wavekey = @c_Wavekey  
         AND   TD.Sourcetype IN ( @c_SourceType, @c_SourceType_Repl, @c_SourceType_CPK )        
         AND   TD.Status <> '0'   
         AND   TD.Status <> 'X' 
      ) = 1   
   --(Wan03) - END       
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 81020
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Released Task is in progress. Reverse reject. (ispRVWAV30)'
      GOTO QUIT_SP
   END
   
   BEGIN TRAN

   ---------------------------------------------------
   -- Delete PackDetail
   ---------------------------------------------------
   SET @CUR_DELPCK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
          PCK.PickSlipNo
         ,PCK.CartonNo
         ,PCK.LabelNo
         ,PCK.LabelLine
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN PICKDETAIL PD WITH (NOLOCK)  ON WD.Orderkey = PD.Orderkey
   JOIN PACKDETAIL PCK WITH (NOLOCK) ON PD.PickSlipNo = PCK.PickSlipNo
   WHERE WD.Wavekey = @c_Wavekey
   AND PCK.PickSlipNo <> ''
   ORDER BY PCK.PickSlipNo
         ,  PCK.CartonNo

   OPEN @CUR_DELPCK

   FETCH NEXT FROM @CUR_DELPCK INTO @c_PickSlipNo
                                 ,  @n_CartonNo
                                 ,  @c_LabelNo
                                 ,  @c_LabelLine

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE PACKDETAIL 
      WHERE PickSlipNo = @c_PickSlipNo
      AND   CartonNo   = @n_CartonNo
      AND   LabelNo    = @c_LabelNo
      AND   LabelLine  = @c_LabelLine

      SET @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 82030 
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKDETAIL Failed. (ispRVWAV30)' 
         GOTO QUIT_SP
      END 
      FETCH NEXT FROM @CUR_DELPCK INTO @c_PickSlipNo
                                    ,  @n_CartonNo
                                    ,  @c_LabelNo
                                    ,  @c_LabelLine
   END
   CLOSE @CUR_DELPCK
   DEALLOCATE @CUR_DELPCK 
   -- Initialize TaskDetailKey & Wavekey in PickDetail

   
   ---Wan01 (START)
   SET @CUR_TD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TD.TaskDetailKey
         ,TD.UOM
         ,TD.TaskType                                                               --(Wan03) 
   FROM TASKDETAIL TD WITH (NOLOCK)
   WHERE TD.Wavekey = @c_Wavekey
   AND   TD.Tasktype IN ( 'RPF', 'CPK')                                             --(Wan03) 
   AND   TD.[Status] NOT IN ('X')                                                   --(Wan03) 
   AND   TD.SourceType IN ( @c_SourceType, @c_SourceType_Repl, @c_SourceType_CPK )  --(Wan03) 
   AND   TD.TaskDetailKey <> ''

   OPEN @CUR_TD

   FETCH NEXT FROM @CUR_TD INTO  @c_TaskDetailKey
                              ,  @c_UOM
                              ,  @c_TaskType                                        --(Wan02)

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @b_Delete = 1

      IF @c_UOM = '7' AND @c_TaskType = 'RPF'     --Only Check UCC that go down to Home Pick Loc   --(Wan02)
      BEGIN
         -- Check if other wave that share the same taskdetailkey had released wave
         SET @c_Wavekey_Share = ''
         SELECT TOP 1
               @c_Wavekey_Share = PD.Wavekey
         FROM PICKDETAIL PD WITH (NOLOCK) 
         JOIN LOC L WITH (NOLOCK) ON PD.Loc = L.Loc
         LEFT JOIN TASKDETAIL TD WITH (NOLOCK)
                              ON  TD.Storerkey = PD.Storerkey
                              AND TD.Wavekey   = PD.Wavekey
                              AND TD.TaskType  = 'RPF'
         WHERE PD.TaskDetailKey = @c_TaskDetailkey
         AND PD.Wavekey <> @c_Wavekey
         AND PD.[Status] < '3'
         AND L.LocationType NOT IN ( 'DYNPPICK', 'DYNPICKP' )
         AND TD.TaskDetailKey IS NOT NULL
         ORDER BY TD.PickDetailKey
            
         IF @c_Wavekey_Share <> ''
         BEGIN
            SET @b_Delete = 0
         END
      END

      IF @b_Delete = 1
      BEGIN
         DELETE TASKDETAIL WITH (ROWLOCK)
         WHERE TaskDetailkey = @c_TaskDetailkey

         SET @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err = 81040
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': DELETE Taskdetail Table Failed. (ispRVWAV30)' 
            GOTO QUIT_SP
         END

         SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey
         FROM PICKDETAIL PD WITH (NOLOCK)
         WHERE PD.TaskDetailKey = @c_TaskDetailKey
         AND   PD.TaskDetailKey IS NOT NULL 
         AND   PD.TaskDetailKey <> '' 
         AND   PD.[Status] < '9'

         OPEN @CUR_PD

         FETCH NEXT FROM @CUR_PD INTO  @c_PickDetailKey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET TaskDetailKey = ''
               ,TrafficCop    = NULL
               ,EditWho = SUSER_NAME()
               ,EditDate= GETDATE()
            WHERE PickDetailkey = @c_PickDetailKey

            SET @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
               SET @n_continue = 3
               SET @n_err = 81035
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV30)' 
               GOTO QUIT_SP
            END

            FETCH NEXT FROM @CUR_PD INTO  @c_PickDetailKey
         END 
      END 
      ELSE
      BEGIN
         ----------------------------------------------------
         -- Change the Task to Share Wave instead of deleting
         ----------------------------------------------------
         UPDATE TASKDETAIL 
            SET Wavekey = @c_Wavekey_Share
               ,Trafficcop = NULL
               ,EditDate = GETDATE()
               ,EditWho  = SUSER_SNAME()
         WHERE TaskDetailkey = @c_TaskDetailkey

         SET @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err = 81050
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Taskdetail Table Failed. (ispRVWAV30)' 
            GOTO QUIT_SP
         END
      END    
      FETCH NEXT FROM @CUR_TD INTO  @c_TaskDetailKey
                                 ,  @c_UOM  
                                 ,  @c_TaskType                                           --(Wan02)      
   END
   CLOSE @CUR_TD
   DEALLOCATE @CUR_TD

   /*
   SET @CUR_TD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TD.TaskDetailKey
   FROM TASKDETAIL TD WITH (NOLOCK)
   WHERE TD.Wavekey = @c_Wavekey
   AND   TD.Tasktype= 'RPF'
   AND   TD.[Status] = '0' 

   OPEN @CUR_TD

   FETCH NEXT FROM @CUR_TD INTO  @c_TaskDetailKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_TaskDetailKey <> ''
      BEGIN
         SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey
         FROM PICKDETAIL PD WITH (NOLOCK)
         WHERE PD.TaskDetailKey = @c_TaskDetailKey
         AND   PD.TaskDetailKey IS NOT NULL 
         AND   PD.TaskDetailKey <> '' 
         AND   PD.[Status] < '9'

         OPEN @CUR_PD

         FETCH NEXT FROM @CUR_PD INTO  @c_PickDetailKey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET TaskDetailKey = ''
               --,Wavekey       = ''
               ,TrafficCop    = NULL
               ,EditWho = SUSER_NAME()
               ,EditDate= GETDATE()
            WHERE PickDetailkey = @c_PickDetailKey

            SET @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
               SET @n_continue = 3
               SET @n_err = 81035
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV30)' 
               GOTO QUIT_SP
            END
            FETCH NEXT FROM @CUR_PD INTO  @c_PickDetailKey
         END     
         CLOSE @CUR_PD    
         DEALLOCATE @CUR_PD

         IF EXISTS ( SELECT 1
                     FROM TASKDETAIL WITH (NOLOCK)
                     WHERE TaskDetailkey = @c_TaskDetailkey
                     AND TaskType = 'RPF'
                     AND SourceType IN ( @c_SourceType  )      
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
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': DELETE Taskdetail Table Failed. (ispRVWAV30)' 
               GOTO QUIT_SP
            END 
         END
      END
      FETCH NEXT FROM @CUR_TD INTO @c_TaskDetailKey
   END            
   CLOSE @CUR_TD
   DEALLOCATE @CUR_TD
   ---Wan01 (END) ---*/

   UPDATE WAVE WITH (ROWLOCK)
      --SET Status = '0' -- Released      --(Wan04) 
      --,Trafficcop = NULL                --(Wan04) 
      --,EditWho = SUSER_NAME()           --(Wan04) 
      SET TMReleaseFlag = 'N'             --(Wan04) 
      ,  TrafficCop = NULL                --(Wan04) 
      ,  EditWho = SUSER_SNAME()          --(Wan04) 
      ,  EditDate= GETDATE()              --(Wan04)       
   WHERE Wavekey = @c_Wavekey 
   
   SET @n_err = @@ERROR
   IF @n_err <> 0 
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81100  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Wave Table Failed. (ispRVWAV30)' 
      GOTO QUIT_SP
   END     
QUIT_SP:

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRVWAV30'
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