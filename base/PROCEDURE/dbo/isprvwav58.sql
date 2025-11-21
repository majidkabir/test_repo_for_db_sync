SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispRLWAV58                                              */
/* Creation Date: 19-Apr-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22210 - AESOP Release Wave (Reverse)                    */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 19-Apr-2023 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispRVWAV58]
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
      
   IF EXISTS (SELECT 1 FROM dbo.WAVE AS w (NOLOCK) WHERE w.WaveKey = @c_Wavekey AND w.TMReleaseFlag = 'R')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69005
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release/Reverse Task is in progress, TMReleaseFlag = ''R''. Reverse reject. (ispRVWAV58)'
      GOTO QUIT_SP
   END
   
   UPDATE WAVE WITH (ROWLOCK)  
   SET TMReleaseFlag = 'R'               
      ,Trafficcop = NULL  
      ,EditWho = SUSER_SNAME()  
      ,EditDate= GETDATE()  
   WHERE Wavekey = @c_Wavekey   
   
   INSERT INTO @t_TaskDetail (TaskDetailKey, TaskType, [Status], UOM, CaseID)
   SELECT td.TaskDetailKey, td.TaskType, td.[Status], td.UOM, td.Caseid
   FROM dbo.TaskDetail AS td (NOLOCK)
   WHERE td.Wavekey = @c_Wavekey
   AND td.Sourcetype LIKE 'ispRLWAV58_%'
         
   IF EXISTS (SELECT 1 
              FROM @t_TaskDetail AS ttd
              WHERE ttd.TaskType IN ( 'CPK' )
              AND ttd.[Status] BETWEEN '1' AND '9'
              )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69010
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Released Task is in progress or Done. Reverse reject. (ispRVWAV58)'
      GOTO QUIT_SP
   END

   INSERT INTO @t_PackHeader ( PickSlipNo, [STATUS] )
   SELECT ph.PickSlipNo, ph.[Status] 
   FROM dbo.WAVEDETAIL AS w  WITH (NOLOCK)
   JOIN dbo.PackHeader AS ph WITH (NOLOCK) ON ph.OrderKey = w.OrderKey
   WHERE w.Wavekey = @c_Wavekey

   IF EXISTS (SELECT 1 
              FROM @t_PackHeader AS tph
              WHERE tph.[Status] = '9'
              )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 69020
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Packing is Done. Reverse reject. (ispRVWAV58)'
      GOTO QUIT_SP
   END
   
   INSERT INTO @t_PickDetail (PickDetailKey, DocType, Orderkey)
   SELECT p.PickDetailKey, o.DocType, o.OrderKey 
   FROM @t_TaskDetail AS ttd
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.TaskDetailkey = ttd.TaskDetailkey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey
   WHERE ttd.TaskType IN ( 'CPK' )
   
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
      SET @n_err = 69030   
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PackDetail Table Failed. (ispRVWAV58)'   
      GOTO QUIT_SP      
   END

   ;WITH delpif ( PickSlipNo, CartonNo ) AS 
   (  SELECT pd.PickSlipNo, pd.CartonNo
      FROM @t_PackHeader tph
      JOIN dbo.PackDetail AS pd ON pd.PickSlipNo = tph.PickSlipNo
   )
   DELETE pif WITH (ROWLOCK)
   FROM delpif dpif
   JOIN dbo.PACKINFO AS pif ON pif.PickSlipNo = dpif.PickSlipNo
                           AND pif.CartonNo = dpif.CartonNo                                                   
   SET @n_err = @@ERROR
   IF @n_Err <> 0 
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 69040   
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PackDetail Table Failed. (ispRVWAV58)'   
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
         SET @n_err = 69050   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PackHeader Table Failed. (ispRVWAV58)'   
         GOTO QUIT_SP      
      END
   END
   
   UPDATE p WITH (ROWLOCK)
      SET p.CaseID = ''
         ,p.PickSlipNo = ''
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
      SET @n_err = 69050    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PickDetail Table Failed. (ispRVWAV58)'   
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
      SET @n_Err = 69060
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV58)'
      GOTO QUIT_SP     
   END 

   --For PK
   ;WITH ORD (Orderkey) AS (
      SELECT DISTINCT Orderkey
      FROM WAVEDETAIL (NOLOCK)
      WHERE WaveKey = @c_Wavekey
   )
   UPDATE O WITH (ROWLOCK)
   SET B_Fax2 = ''
     , BilledContainerQty = 0
   FROM ORD
   JOIN ORDERS O ON O.Orderkey = ORD.Orderkey
                                                        
   SET @n_err = @@ERROR
   IF @n_Err <> 0 
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 69070   
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orders Table Failed. (ispRVWAV58)'   
      GOTO QUIT_SP      
   END

   UPDATE WAVE WITH (ROWLOCK)  
   SET TMReleaseFlag = 'N'               
      ,Trafficcop = NULL  
      ,EditWho = SUSER_SNAME()  
      ,EditDate= GETDATE()  
      ,UserDefine09 = ''   --For PK
   WHERE Wavekey = @c_Wavekey   
     
   SET @n_err = @@ERROR  
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 69080    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update WAVE Table Failed. (ispRLWAV58)'   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRVWAV58'
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