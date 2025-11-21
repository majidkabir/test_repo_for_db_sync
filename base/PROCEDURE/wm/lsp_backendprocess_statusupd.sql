SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_BackEndProcess_StstusUpd                     */                                                                                  
/* Creation Date: 2023-02-24                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3699 - CLONE - [CN]NIKE_TRADE RETURN_Suggest PA loc    */
/*        : (Pre-finalize)by batch ASN                                  */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.1                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2023-02-24  Wan01    1.0   Created & DevOps Combine Script.          */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_BackEndProcess_StatusUpd]                                                                                                                     
   @n_ProcessID   BIGINT
,  @c_Status      NVARCHAR(10)   = '0'
,  @c_StatusMsg   NVARCHAR(255)  = ''
,  @n_QueueID     BIGINT         = 0
,  @b_Success     INT            = 1   OUTPUT
,  @n_err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt   INT            = @@TRANCOUNT  
         ,  @n_Continue    INT            = 1
         
   BEGIN TRAN         
   IF @c_Status < '5'
   BEGIN
      UPDATE dbo.BackEndProcessQueue WITH (ROWLOCK)
      SET [Status]   = @c_Status  
         , StatusMsg = @c_StatusMsg
         , QueueID   = IIF(@n_QueueID > 0, @n_QueueID, QueueID)
      WHERE ProcessID= @n_ProcessID
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
      END
   END
   ELSE
   BEGIN
      INSERT INTO dbo.BackEndProcessQueue_Log 
         (  ProcessID
         ,  Storerkey  
         ,  ModuleID                
         ,  DocumentKey1               
         ,  DocumentKey2               
         ,  DocumentKey3               
         ,  ProcessType                
         ,  SourceType                 
         ,  CallType
         ,  [Priority]                             
         ,  RefKey1                    
         ,  RefKey2                    
         ,  RefKey3                    
         ,  QueueID                    
         ,  ExecCmd                    
         ,  [Status]                   
         ,  StatusMsg                  
         ,  AddWho                     
         ,  AddDate                    
         ,  EditWho                    
         ,  EditDate
         )
      SELECT
            bepq.ProcessID
         ,  bepq.Storerkey   
         ,  bepq.ModuleID               
         ,  bepq.DocumentKey1               
         ,  bepq.DocumentKey2               
         ,  bepq.DocumentKey3               
         ,  bepq.ProcessType                
         ,  bepq.SourceType                 
         ,  bepq.CallType
         ,  bepq.[Priority]                    
         ,  bepq.RefKey1                    
         ,  bepq.RefKey2                    
         ,  bepq.RefKey3                    
         ,  bepq.QueueID                    
         ,  bepq.ExecCmd                    
         ,  [Status] = @c_Status                  
         ,  StatusMsg= @c_StatusMsg                  
         ,  bepq.AddWho                     
         ,  bepq.AddDate                    
         ,  SUSER_SNAME()                    
         ,  GETDATE()
      FROM dbo.BackEndProcessQueue bepq WITH (NOLOCK)
      WHERE bepq.ProcessID = @n_ProcessID
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
      END
               
      DELETE dbo.BackEndProcessQueue WITH (ROWLOCK)
      WHERE ProcessID = @n_ProcessID 
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
      END      
   END
EXIT_SP:   
   IF @n_Continue = 3
   BEGIN
      IF @n_StartTCnt = 1 AND @@TRANCOUNT > 0 
      BEGIN
         ROLLBACK TRAN
      END 
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_BackEndProcessQueue_StstusUpd'
      SET @b_Success = 0
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      SET @b_Success = 1
   END
END

GO