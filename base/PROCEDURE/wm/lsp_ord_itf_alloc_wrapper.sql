SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_ORD_ITF_Alloc_Wrapper                        */                                                                                  
/* Creation Date: 2022-04-22                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3373 - UAT - TW  Missing Menu from Shipment Order      */
/*        : Generate Interface Record                                   */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2022-04-22  Wan01    1.0   Created.                                  */
/* 2022-04-22  Wan01    1.0   DevOps Combine Script.                    */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_ORD_ITF_Alloc_Wrapper]                                                                                                                     
      @c_Orderkey             NVARCHAR(250)  = '' 
   ,  @b_Success              INT = 1              OUTPUT  
   ,  @n_err                  INT = 0              OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)  = ''  OUTPUT 
   ,  @c_UserName             NVARCHAR(128)  = '' 
   ,  @n_WarningNo            INT            = 0   OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)        = 'N' --Passin 'Y' after user answer to proceed
   ,  @n_ErrGroupKey          INT            = 0   OUTPUT                                                                                                                              
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt            INT = @@TRANCOUNT  
         ,  @n_Continue             INT = 1
         
         ,  @c_TableName            NVARCHAR(50)   = 'ORDITFAlloc'
         ,  @c_SourceType           NVARCHAR(50)   = 'lsp_ORD_ITF_Alloc_Wrapper'
         ,  @c_Refkey1              NVARCHAR(20)   = ''                      
         ,  @c_Refkey2              NVARCHAR(20)   = ''                      
         ,  @c_Refkey3              NVARCHAR(20)   = ''    
         ,  @c_WriteType            NVARCHAR(10)   = ''          
         ,  @n_LogWarningNo         INT            = 0  
         
         ,  @c_Facility             NVARCHAR(5) = ''
         ,  @c_Storerkey            NVARCHAR(15)= ''
         ,  @c_Status               NVARCHAR(10)= '0'
         ,  @c_SOStatus             NVARCHAR(10)= '0'
         
         ,  @c_InterfaceKey         NVARCHAR(30)= ''
         ,  @c_SOALLocLog           NVARCHAR(30)= ''
         ,  @c_SOALLocLogKey        NVARCHAR(5) = ''  
         
         , @CUR_ERRLIST             CURSOR
                
   DECLARE  @t_WMSErrorList   TABLE                                 
         (  RowID                INT            IDENTITY(1,1)     PRIMARY KEY    
         ,  TableName            NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  SourceType           NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  Refkey1              NVARCHAR(20)   NOT NULL DEFAULT('')  
         ,  Refkey2              NVARCHAR(20)   NOT NULL DEFAULT('')  
         ,  Refkey3              NVARCHAR(20)   NOT NULL DEFAULT('')  
         ,  WriteType            NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  LogWarningNo         INT            NOT NULL DEFAULT(0)  
         ,  ErrCode              INT            NOT NULL DEFAULT(0)  
         ,  Errmsg               NVARCHAR(255)  NOT NULL DEFAULT('')    
         )           

   SET @b_Success = 1
   SET @n_Err     = 0
   
   SET @n_Err = 0 
 
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END

   BEGIN TRAN  
     
   BEGIN TRY
      SET @n_ErrGroupKey = 0
      SELECT @c_Facility = o.Facility
            ,@c_Storerkey= o.StorerKey
            ,@c_Status   = o.[Status]
            ,@c_SOStatus = o.SOStatus
      FROM dbo.ORDERS AS o WITH (NOLOCK)
      WHERE o.OrderKey = @c_Orderkey
      
      IF @n_WarningNo < 1
      BEGIN
         SELECT @c_SOALLocLog = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'SOALLOCLOG')
     
         IF  @c_SOALLocLog = '0' 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 560701
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Storerconfig: SOALLOCLOG is not turn on for Interface Transmitlog3 (SOALLOCLOG) records'
                          + '. (lsp_ORD_ITF_Alloc_Wrapper)'
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
            VALUES ( @c_TableName, @c_SourceType, @c_Orderkey, '', '', 'ERROR', 0, @n_Err, @c_ErrMsg ) 
            GOTO EXIT_SP
         END 
      
         IF  @c_Status NOT IN ('1', '2')
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 560702
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Order Status:' + @c_Status + '. It is not eligible for Interface Transmitlog3 (SOALLOCLOG) records'
                          + '. (lsp_ORD_ITF_Alloc_Wrapper)'
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
            VALUES ( @c_TableName, @c_SourceType, @c_Orderkey, '', '', 'ERROR', 0, @n_Err, @c_ErrMsg ) 
            GOTO EXIT_SP
         END 
      
         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Are you sure you want to create Transmitlog3 (SOALLOCLOG) record?'
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
         VALUES ( @c_TableName, @c_SourceType, @c_Orderkey, '', '', 'QUESTION', @n_WarningNo, 0, @c_ErrMsg ) 
         GOTO EXIT_SP
      END
      
      EXEC dbo.nspg_GetKey
            @KeyName       = N'BMISOALLOCLOG'
          , @fieldlength   = 5
          , @keystring     = @c_SOAllocLogKey   OUTPUT
          , @b_Success     = @b_Success         OUTPUT
          , @n_err         = @n_err             OUTPUT
          , @c_errmsg      = @c_errmsg          OUTPUT
          , @b_resultset   = 0
          , @n_batch       = 0                
      
      IF  @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
         VALUES ( @c_TableName, @c_SourceType, @c_Orderkey, '', '', 'ERROR', 0, @n_Err, @c_ErrMsg ) 
         GOTO EXIT_SP
      END 
 
      EXEC dbo.ispGenTransmitLog3
            @c_TableName = N'SOALLOCLOG'
          , @c_Key1 = @c_Orderkey
          , @c_Key2 = @c_SOAllocLogKey
          , @c_Key3 = @c_Storerkey
          , @c_TransmitBatch = N''
          , @b_Success  = @b_Success   OUTPUT
          , @n_err      = @n_err       OUTPUT
          , @c_errmsg   = @c_errmsg    OUTPUT

      IF  @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
         VALUES ( @c_TableName, @c_SourceType, @c_Orderkey, '', '', 'ERROR', 0, @n_Err, @c_ErrMsg ) 
         GOTO EXIT_SP
      END
      
      IF @c_SOStatus < '2'
      BEGIN
         UPDATE dbo.ORDERS WITH (ROWLOCK) 
            SET SOStatus = '2'
               ,EditWho = SUSER_SNAME()
               ,EditDate= GETDATE()          
               ,Trafficcop = NULL 
         WHERE OrderKey = @c_Orderkey
         AND SOStatus < '2'
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 560703
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Update Orders table fail. (lsp_ORD_ITF_Alloc_Wrapper)'
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
            VALUES ( @c_TableName, @c_SourceType, @c_Orderkey, '', '', 'ERROR', 0, @n_Err, @c_ErrMsg ) 
            GOTO EXIT_SP
         END
      END
      
      SET @c_ErrMsg = 'Interface Transmitlog3 (SOALLOCLOG) records are created successfully.'
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
      VALUES ( @c_TableName, @c_SourceType, @c_Orderkey, '', '', 'MESSAGE', 0, 0, @c_ErrMsg ) 
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
      VALUES ( @c_TableName, @c_SourceType, @c_Orderkey, '', '', 'ERROR', 0, 0, @c_ErrMsg ) 
      GOTO EXIT_SP
   END CATCH

EXIT_SP:
   IF (XACT_STATE()) = -1                                     
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END 

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt      
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ORD_ITF_Alloc_Wrapper'
      SET @n_WarningNo = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT   twl.TableName           
         ,  twl.SourceType          
         ,  twl.Refkey1             
         ,  twl.Refkey2             
         ,  twl.Refkey3             
         ,  twl.WriteType           
         ,  twl.LogWarningNo        
         ,  twl.ErrCode             
         ,  twl.Errmsg                 
   FROM @t_WMSErrorList AS twl  
   ORDER BY twl.RowID  
     
   OPEN @CUR_ERRLIST  
     
   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName           
                                     , @c_SourceType          
                                     , @c_Refkey1             
                                     , @c_Refkey2             
                                     , @c_Refkey3             
                                     , @c_WriteType           
                                     , @n_LogWarningNo        
                                     , @n_Err             
                                     , @c_Errmsg              
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      EXEC [WM].[lsp_WriteError_List]   
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT   
      ,  @c_TableName   = @c_TableName  
      ,  @c_SourceType  = @c_SourceType  
      ,  @c_Refkey1     = @c_Refkey1  
      ,  @c_Refkey2     = @c_Refkey2  
      ,  @c_Refkey3     = @c_Refkey3  
      ,  @n_LogWarningNo= @n_LogWarningNo  
      ,  @c_WriteType   = @c_WriteType  
      ,  @n_err2        = @n_err   
      ,  @c_errmsg2     = @c_errmsg   
      ,  @b_Success     = @b_Success      
      ,  @n_err         = @n_err          
      ,  @c_errmsg      = @c_errmsg           
       
      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName           
                                        , @c_SourceType          
                                        , @c_Refkey1             
                                        , @c_Refkey2             
                                        , @c_Refkey3             
                                        , @c_WriteType           
                                        , @n_LogWarningNo        
                                        , @n_Err             
                                        , @c_Errmsg       
   END  
   CLOSE @CUR_ERRLIST  
   DEALLOCATE @CUR_ERRLIST 
    
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
         
   REVERT
END

GO