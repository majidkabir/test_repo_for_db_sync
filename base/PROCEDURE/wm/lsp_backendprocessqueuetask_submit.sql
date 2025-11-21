SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_BackEndProcessQueueTask_Submit               */                                                                                  
/* Creation Date: 2023-02-24                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose:                                                             */
/*                                                                      */                                                                                  
/* Purpose: LFWM-3699 - CLONE - [CN]NIKE_TRADE RETURN_Suggest PA loc    */
/*        : (Pre-finalize)by batch ASN                                  */                                                                                 
/* PVCS Version: 1.1                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2022-12-12  Wan      1.0   Created & DevOps Combine Script           */
/* 2023-04-11  Wan01    1.1   LFWM-4153 - UAT - CN  All Generating Ecom */
/*                            Replenishment                             */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_BackEndProcessQueueTask_Submit]                                                                                                                     
   @c_Storerkey   NVARCHAR(15) = ''
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt   INT            = @@TRANCOUNT 
         ,  @n_Continue    INT            = 1
         
         ,  @b_Success     INT            = 1
         ,  @n_Err         INT            = 0 
         ,  @c_ErrMsg      NVARCHAR(255)  = ''

         ,  @n_ProcessID         BIGINT       = 0
         ,  @c_ProcessType       NVARCHAR(30) = ''
                  
         ,  @n_ThreadPerAcct     INT          = 0
         ,  @n_ThreadPerStream   INT          = 0
         ,  @n_MilisecondDelay   INT          = 0
         ,  @c_APP_DB_Name       NVARCHAR(20) = ''
         ,  @c_DataStream        NVARCHAR(10) = ''
         ,  @c_IP                NVARCHAR(20) = ''
         ,  @c_PORT              NVARCHAR(5)  = ''
         ,  @c_IniFilePath       NVARCHAR(200)= ''
         ,  @c_CmdType           NVARCHAR(10) = ''
         ,  @c_TaskType          NVARCHAR(1)  = ''
         ,  @n_Priority          NVARCHAR(10) = ''
         
         ,  @n_QueueID           BIGINT       = 0
         ,  @c_QCommand          NVARCHAR(1024)= ''

                
         ,  @CUR_PROC      CURSOR
         ,  @CUR_SBM       CURSOR
 
   SET @CUR_PROC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT b.Storerkey
         ,b.ProcessType
   FROM dbo.BackEndProcessQueue b WITH (NOLOCK)
   WHERE QueueID = 0
   GROUP BY b.Storerkey
         ,  b.ProcessType

   OPEN @CUR_PROC
      
   FETCH NEXT FROM @CUR_PROC INTO @c_Storerkey, @c_ProcessType
      
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   
      SET @n_Continue = 1
      SET @b_Success  = 1
      IF NOT EXISTS (SELECT 1  
                     FROM dbo.BackEndProcessQueue bepq WITH (NOLOCK)
                     WHERE bepq.QueueID > 0
                     AND bepq.Storerkey = @c_Storerkey
                     AND bepq.ProcessType = @c_ProcessType
                     AND bepq.[Status] >= '0'
                     )
      BEGIN 
         BEGIN TRY 
            BEGIN TRAN
      
            SELECT TOP 1                                                     
                  @c_APP_DB_Name     = ISNULL(qcfg.APP_DB_Name,'')  
               ,  @c_DataStream      = qcfg.DataStream     
               ,  @n_ThreadPerAcct   = qcfg.ThreadPerAcct  
               ,  @n_ThreadPerStream = qcfg.ThreadPerStream  
               ,  @n_MilisecondDelay = qcfg.MilisecondDelay  
               ,  @c_IP              = IIF(qcfg.StorerKey IN (@c_Storerkey, 'ALL'), qcfg.[IP], '')          
               ,  @c_PORT            = IIF(qcfg.StorerKey IN (@c_Storerkey, 'ALL'), qcfg.[PORT], '')       
               ,  @c_IniFilePath     = qcfg.IniFilePath    
               ,  @c_CmdType         = qcfg.CmdType        
               ,  @c_TaskType        = qcfg.TaskType       
               ,  @n_Priority        = qcfg.[Priority]     
            FROM  dbo.QCmd_TransmitlogConfig qcfg WITH (NOLOCK)  
            WHERE qcfg.TableName      = 'BackEndProcessQueue'
            AND   qcfg.[App_Name]     = 'WMS'  
            AND   qcfg.DataStream     = @c_ProcessType               --Wan01  Fixed to get rec by processtype 
            AND   qcfg.StorerKey IN (@c_Storerkey, 'ALL')
            ORDER BY CASE WHEN qcfg.StorerKey = @c_Storerkey THEN 1              
                          WHEN qcfg.StorerKey = 'ALL' THEN 2 ELSE 3              
                          END                                                    
                  , qcfg.RowRefNo                                                
            
            IF @c_IP = '' OR @c_PORT = ''
            BEGIN
               SET @n_Continue = 3
            END
       
            IF @n_Continue IN (1,2)
            BEGIN  
               SET @b_Success= 1
               SET @n_Err    = 0
               SET @c_ErrMsg = ''
               SET @n_QueueID= 0
               
               SET @c_QCommand = 'EXEC WM.lsp_BackEndProcess_ExecCmd @c_Storerkey=''' + @c_Storerkey 
                               + ''', @c_ProcessType='''+ @c_ProcessType + ''''    
               EXEC isp_QCmd_SubmitTaskToQCommander
                    @cTaskType         = @c_TaskType
                  , @cStorerKey        = @c_StorerKey
                  , @cDataStream       = @c_DataStream
                  , @cCmdType          = 'SQL'
                  , @cCommand          = @c_QCommand
                  , @cTransmitlogKey   = @n_ProcessID
                  , @nThreadPerAcct    = @n_ThreadPerAcct
                  , @nThreadPerStream  = @n_ThreadPerStream
                  , @nMilisecondDelay  = @n_MilisecondDelay
                  , @nSeq              = 1
                  , @cIP               = @c_IP
                  , @cPORT             = @c_PORT
                  , @cIniFilePath      = @c_IniFilePath
                  , @cAPPDBName        = @c_APP_DB_Name
                  , @bSuccess          = @b_Success   OUTPUT
                  , @nErr              = @n_Err       OUTPUT
                  , @cErrMsg           = @c_ErrMsg    OUTPUT
                  , @nPriority         = @n_Priority 
                  , @nQueueID          = @n_QueueID   OUTPUT             

               IF @n_Err <> 0 AND ISNULL(@c_ErrMsg,'') <> ''
               BEGIN
                  SET @n_Continue = 3
               END
            END
      
            SET @CUR_SBM = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT bepq.ProcessID
            FROM dbo.BackEndProcessQueue bepq WITH (NOLOCK)
            WHERE bepq.QueueID = 0
            AND bepq.Storerkey = @c_Storerkey
            AND bepq.ProcessType = @c_ProcessType
            AND bepq.[Status] = '0'
            ORDER BY bepq.ProcessID   
            OPEN @CUR_SBM
      
            FETCH NEXT FROM @CUR_SBM INTO @n_ProcessID
      
            WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
            BEGIN
               SET @b_Success= 1
               SET @n_Err    = 0
               SET @c_ErrMsg = ''
               EXEC [WM].[lsp_BackEndProcess_StatusUpd]                                                                                                                     
                  @n_ProcessID   = @n_ProcessID
               ,  @c_Status      = '1'                   -- Submitted to TCPSocket_QueueTask
               ,  @c_StatusMsg   = 'Back End Process submitted to TCPSocket_QueueTask.'
               ,  @n_QueueID     = @n_QueueID
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_Err         = @n_Err       OUTPUT
               ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT
              
               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
               END
       
               FETCH NEXT FROM @CUR_SBM INTO @n_ProcessID
            END 
            CLOSE @CUR_SBM
            DEALLOCATE @CUR_SBM
         END TRY
         BEGIN CATCH 
            SET @n_Continue = 3
            SET @c_ErrMsg = ERROR_MESSAGE()
         END CATCH 
       
            IF @n_Continue = 3
            BEGIN
               IF @@TRANCOUNT > 0 
               BEGIN
                  ROLLBACK TRAN
               END
            END
            ELSE
            BEGIN
               WHILE @@TRANCOUNT > 0
               BEGIN
                  COMMIT TRAN
               END   
            END
      END
      FETCH NEXT FROM @CUR_PROC INTO @c_Storerkey, @c_ProcessType
   END 
   CLOSE @CUR_PROC
   DEALLOCATE @CUR_PROC
  
EXIT_SP:

   IF @n_Continue = 3
   BEGIN
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'WM.lsp_BackEndProcessQueueTask_Submit'
   END

END

GO