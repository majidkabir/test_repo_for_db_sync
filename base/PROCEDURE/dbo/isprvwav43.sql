SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRVWAV43                                              */
/* Creation Date: 2021-07-15                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-15  Wan      1.0   Created.                                  */
/* 2021-09-28  Wan      1.0   DevOps Combine Script.                    */
/* 2021-11-17  Wan01    1.1   Update TMRelaseFlag to 'R' to prevent     */
/*                            ReReverse & ReRelease before their process*/
/*                            End                                       */
/************************************************************************/

CREATE PROC [dbo].[ispRVWAV43]
   @c_Wavekey     NVARCHAR(10) 
,  @c_Orderkey    NVARCHAR(10)   = ''
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT   = @@TRANCOUNT
         , @n_Continue        INT   = 1
         
         , @c_Storerkey       NVARCHAR(15) = ''

   DECLARE @t_TaskDetail      TABLE 
         ( TaskDetailKey      NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY
         , TaskType           NVARCHAR(10)   NOT NULL DEFAULT('')
         , [Status]           NVARCHAR(10)   NOT NULL DEFAULT('')
         , UOM                NVARCHAR(10)   NOT NULL DEFAULT('')  
         , CaseID             NVARCHAR(20)   NOT NULL DEFAULT('')                   
         )
   
   DECLARE @t_PickDetail      TABLE 
      ( PickDetailKey         NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY
      , DocType               NVARCHAR(10)   NOT NULL DEFAULT('')
      , Orderkey              NVARCHAR(10)   NOT NULL DEFAULT('')      
      )  
      
   DECLARE @t_PackHeader      TABLE 
      ( PickSlipNo            NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY
      , [Status]              NVARCHAR(10)   NOT NULL DEFAULT('')   
      )     
       
   SELECT TOP 1 @c_Storerkey = o.Storerkey
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w.OrderKey
   WHERE w.WaveKey = @c_Wavekey
   ORDER BY w.WaveDetailKey
      
   --(Wan01) - START
   IF EXISTS (SELECT 1 FROM dbo.WAVE AS w (NOLOCK) WHERE w.WaveKey = @c_Wavekey AND w.TMReleaseFlag = 'R')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69005
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release/Reverse Task is in progress, TMReleaseFlag = ''R''. Reverse reject. (ispRVWAV43)'
      GOTO QUIT_SP
   END
   
   UPDATE WAVE WITH (ROWLOCK)  
   SET TMReleaseFlag = 'R'               
      ,Trafficcop = NULL  
      ,EditWho = SUSER_SNAME()  
      ,EditDate= GETDATE()  
   WHERE Wavekey = @c_Wavekey   
   --(Wan01) - END
   
   INSERT INTO @t_TaskDetail (TaskDetailKey, TaskType, [Status], UOM, CaseID)
   SELECT td.TaskDetailKey, td.TaskType, td.[Status], td.UOM, td.Caseid
   FROM dbo.TaskDetail AS td (NOLOCK)
   WHERE td.Wavekey = @c_Wavekey
   AND td.Sourcetype LIKE 'ispRLWAV43_%'
         
   --Reverse RPF Task
   IF EXISTS (SELECT 1 
              FROM @t_TaskDetail AS ttd
              WHERE ttd.TaskType IN ( 'RPF', 'CPK', 'ASTCPK' )       --CR 2.2
              AND ttd.[Status] BETWEEN '1' AND '9'
              )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69010
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Released Task is in progress or Done. Reverse reject. (ispRVWAV43)'
      GOTO QUIT_SP
   END
   
   IF EXISTS (SELECT 1 
              FROM @t_TaskDetail AS ttd
              WHERE ttd.TaskType IN ( 'RPF' )       
              AND ttd.UOM = '7'
              AND EXISTS ( SELECT 1 FROM dbo.PICKDETAIL AS p WITH (NOLOCK)
                           JOIN dbo.WAVEDETAIL AS w WITH (NOLOCK) ON w.OrderKey = p.OrderKey
                           WHERE p.DropID = ttd.CaseID
                           AND p.Storerkey = @c_Storerkey
                           AND p.[Status] < '5'
                           AND w.Wavekey  <> @c_Wavekey
                           )
              )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69020
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found UCC # allocated for other Wave #. Reverse reject. (ispRVWAV43)'
      GOTO QUIT_SP
   END
   
   INSERT INTO @t_PackHeader ( PickSlipNo, [STATUS] )
   SELECT ph.PickSlipNo, ph.[Status] 
   FROM dbo.WAVEDETAIL AS w  WITH (NOLOCK)
   JOIN dbo.PackHeader AS ph WITH (NOLOCK) ON ph.OrderKey = w.OrderKey
   WHERE w.Wavekey = @c_Wavekey

   --Reverse RPF Task
   IF EXISTS (SELECT 1 
              FROM @t_PackHeader AS tph
              WHERE tph.[Status] = '9'
              )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69030
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Packing is Done. Reverse reject. (ispRVWAV43)'
      GOTO QUIT_SP
   END
   
   INSERT INTO @t_PickDetail (PickDetailKey, DocType, Orderkey)
   SELECT p.PickDetailKey, o.DocType, o.OrderKey   
   FROM dbo.WAVEDETAIL AS w  (NOLOCK)
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w.OrderKey 
   JOIN dbo.PackTask AS pt WITH (NOLOCK) ON pt.OrderKey = o.OrderKey
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = o.OrderKey
   WHERE w.Wavekey = @c_Wavekey
   UNION
   SELECT p.PickDetailKey, o.DocType, o.OrderKey
   FROM @t_TaskDetail AS ttd
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.TaskDetailKey = ttd.TaskDetailKey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey
   WHERE ttd.TaskType = 'RPF'
   UNION
   SELECT p.PickDetailKey, o.DocType, o.OrderKey 
   FROM @t_TaskDetail AS ttd
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.TaskDetailkey = ttd.TaskDetailkey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey
   WHERE ttd.TaskType IN ( 'CPK', 'ASTCPK' )       --CR 2.2

   ;WITH PTASK ( RowRef ) AS
   (  SELECT pt.RowRef
      FROM @t_PickDetail AS tpd
      JOIN dbo.PackTask AS pt WITH (NOLOCK) ON pt.Orderkey = tpd.OrderKey
      WHERE tpd.DocType = 'E'
      GROUP BY pt.RowRef
   )
   DELETE pt WITH (ROWLOCK)
   FROM dbo.PackTask AS pt
   JOIN PTASK ON pt.RowRef = PTASK.RowRef

   SET @n_err = @@ERROR
   IF @n_Err <> 0 
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 69040   
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PackTask Table Failed. (ispRVWAV43)'   
      GOTO QUIT_SP      
   END
   
   ;WITH delpd ( PickSlipNo, CartonNo, LabelNo, LabelLine ) AS 
   (  SELECT pd.PickSlipNo, pd.CartonNo, pd.LabelNo, pd.LabelLine
      FROM @t_PackHeader tph
      JOIN dbo.PackDetail AS pd ON pd.PickSlipNo = tph.PickSlipNo
   )
   DELETE pd WITH (ROWLOCK)
   FROM delpd dpd
   JOIN dbo.PackDetail AS pd ON pd.PickSlipNo = dpd.PickSlipNo
                            AND pd.CartonNo = dpd.CartonNo
                            AND pd.LabelNo  = dpd.LabelNo
                            AND pd.LabelLine= dpd.LabelLine                                                        
   SET @n_err = @@ERROR
   IF @n_Err <> 0 
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 69050   
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PackDetail Table Failed. (ispRVWAV43)'   
      GOTO QUIT_SP      
   END
   
   IF EXISTS ( SELECT 1 FROM @t_PackHeader AS tph
               JOIN dbo.PackHeader AS ph WITH (NOLOCK) ON ph.PickSlipNo = tph.PickSlipNo
              )
   BEGIN
      DELETE ph WITH (ROWLOCK)
      FROM @t_PackHeader AS tph
      JOIN dbo.PackHeader AS ph ON ph.PickSlipNo = tph.PickSlipNo

      IF @n_Err <> 0 
      BEGIN
         SET @n_continue = 3  
         SET @n_err = 69060   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PackHeader Table Failed. (ispRVWAV43)'   
         GOTO QUIT_SP      
      END
   END
   
   UPDATE p WITH (ROWLOCK)
      SET p.CaseID = ''
         ,p.PickSlipNo = ''
         ,p.Notes = CASE WHEN tpd.DocType = 'E' THEN '' ELSE p.Notes END
         ,p.TaskDetailKey = ''
         ,p.EditWho = SUSER_SNAME()
         ,p.EditDate = GETDATE()
         ,p.TrafficCop = NULL
   FROM @t_PickDetail AS tpd
   JOIN dbo.PICKDETAIL p ON p.PickdetailKey = tpd.PickDetailKey
   
   SET @n_err = @@ERROR
   IF @n_Err <> 0 
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 69070    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PickDetail Table Failed. (ispRVWAV43)'   
      GOTO QUIT_SP      
   END
    
   --delete Tasks
   DELETE td WITH (ROWLOCK)
   FROM @t_TaskDetail AS ttd
   JOIN dbo.TaskDetail AS td  ON td.TaskdetailKey = ttd.TaskdetailKey
      
   SET @n_err = @@ERROR
   IF @n_err <> 0 
   BEGIN
      SET @n_continue = 3  
      SET @n_Err = 69080
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV43)'
      GOTO QUIT_SP     
   END 
   
   UPDATE WAVE WITH (ROWLOCK)  
   SET TMReleaseFlag = 'N'               
      ,Trafficcop = NULL  
      ,EditWho = SUSER_SNAME()  
      ,EditDate= GETDATE()  
   WHERE Wavekey = @c_Wavekey   
     
   SET @n_err = @@ERROR  
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 69090    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update WAVE Table Failed. (ispRLWAV43)'   
      GOTO QUIT_SP  
   END   
   
   QUIT_SP:

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRVWAV43'
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
END   

GO