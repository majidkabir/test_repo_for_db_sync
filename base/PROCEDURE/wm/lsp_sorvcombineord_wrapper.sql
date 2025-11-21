SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_SORVCombineORD_Wrapper                       */                                                                                  
/* Creation Date: 2021-04-13                                            */                                                                                  
/* Copyright: Maersk                                                    */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2713 - UAT [CN] LULU_Reverse_Combined_Order            */
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
/* 2021-04-13  Wan      1.0   Created.                                  */
/* 2023-05-15  Wan01    1.1   LFWM-4033 - CN UAT  Shipment order reverse*/
/*                            combined order display error&Batch reverse*/
/*                            Devops Conbine Script                     */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_SORVCombineORD_Wrapper] 
      @c_OrderKeys            NVARCHAR(MAX)              -- Orderkey Seperated by | --(Wan01)           
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT 
   ,  @n_WarningNo            INT          = 0  OUTPUT   -- SCE to Pass in initial Value '0', and continue to pass in its output value for the same orderkey if SP Increase warningno
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'         -- Pass In 'Y' if continue to call SP when increased warning # return             
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT   --Capture Warnings/Questions/Errors/Meassage into WMS_ERROR_LIST Table
   ,  @c_SearchSQL            NVARCHAR(MAX)= ''                                     --(WAN01)
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt                  INT            = @@TRANCOUNT  
         ,  @n_Continue                   INT            = 1

         ,  @c_TableName                  NVARCHAR(50)   = 'ORDERS'
         ,  @c_SourceType                 NVARCHAR(50)   = 'lsp_SORVCombineORD_Wrapper'

         ,  @c_SQL                        NVARCHAR(4000) = ''
         ,  @c_SQLParms                   NVARCHAR(4000) = ''

         ,  @c_Facility                   NVARCHAR(5)    = ''
         ,  @c_Storerkey                  NVARCHAR(15)   = ''
         ,  @c_Orderkey                   NVARCHAR(10)   = ''                       --(Wan01)
         
         ,  @n_BackEndProcess             INT            = 0                        --(Wan01)
         ,  @c_ProcessType                NVARCHAR(10)  = 'RVCombORD'               --(Wan01)   
         ,  @c_DocumentKey1               NVARCHAR(50)  = ''                        --(Wan01)
         ,  @c_CallType                   NVARCHAR(50)  = ''                        --(Wan01)    
         ,  @c_ExecCmd                    NVARCHAR(MAX) = ''                        --(Wan01)
         ,  @c_RVOrderkey                 NVARCHAR(10)  = ''                        --(Wan01) 
   
         ,  @c_RVCombineOrd_SP            NVARCHAR(30)   = ''
         
         ,  @CUR_RVORD                    CURSOR

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
   
   BEGIN TRY
      IF OBJECT_ID('tempdb..#FROMORD','U') IS NOT NULL                              --(Wan01) - START
      BEGIN
         DROP TABLE #RVORD
      END

      CREATE TABLE #RVORD
         (  RowID    INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY
         ,  Orderkey NVARCHAR(10)   NOT NULL DEFAULT('')
         ) 
         
      IF @c_OrderKeys = ''                                                           
      BEGIN
         SELECT @c_SearchSQL = dbo.fnc_ParseSearchSQL(@c_SearchSQL, 'SELECT ORDERS.Orderkey') 
         
         IF @c_SearchSQL = ''
         BEGIN
            GOTO EXIT_SP
         END        

         INSERT INTO #RVORD (  OrderKey )   
         EXEC sp_ExecuteSQL @c_SearchSQL
         
         IF @@ROWCOUNT = 0
         BEGIN
            SET @n_Continue = 3  
            SET @n_err = 559405  
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': No Search record found'      
                          + '. (lsp_SORVCombineORD_Wrapper)'  
                          
            EXEC [WM].[lsp_WriteError_List]   
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT   
               ,  @c_TableName   = @c_TableName  
               ,  @c_SourceType  = @c_SourceType  
               ,  @c_Refkey1     = ''  
               ,  @c_Refkey2     = ''  
               ,  @c_Refkey3     = ''   
               ,  @c_WriteType   = 'ERROR'   
               ,  @n_err2        = @n_err   
               ,  @c_errmsg2     = @c_errmsg   
               ,  @b_Success     = @b_Success      
               ,  @n_err         = @n_err          
               ,  @c_errmsg      = @c_errmsg      
            GOTO EXIT_SP  
         END
      END
      ELSE
      BEGIN
         INSERT INTO #RVORD (  OrderKey ) 
         SELECT ss.[value] FROM STRING_SPLIT(@c_OrderKeys, '|') AS ss                                           
         --VALUES (@c_OrderKey)
      END   

      --SELECT @c_Facility    = OH.Facility
      --   ,   @c_Storerkey   = OH.Storerkey
      --FROM ORDERS OH WITH (NOLOCK)
      --WHERE OH.Orderkey = @c_OrderKey      
      SELECT @c_Storerkey = ISNULL(CASE WHEN MIN(o.Storerkey) = MAX(o.Storerkey) THEN MIN(o.Storerkey)
                                        ELSE '' END,'')
         ,   @c_Facility  = ISNULL(CASE WHEN MIN(o.Facility) = MAX(o.Facility) THEN MIN(o.Facility)
                                        ELSE '' END,'')                         
      FROM #RVORD AS r JOIN dbo.ORDERS AS o (NOLOCK) ON o.OrderKey = r.Orderkey
      
      IF @c_Storerkey = ''
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 559406
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Different Storer found in Order lists'    
                       + '. (lsp_SORVCombineORD_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = ''
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg    
      END 
  
      IF @c_Facility = ''
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 559407
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Different Facility found in Order lists'  
                     + '. (lsp_SORVCombineORD_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = ''
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg    
      END
                                                      
      SELECT @c_RVCombineOrd_SP = Authority FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'RevCombineOrderSP')

      IF @c_RVCombineOrd_SP IN ( '0','1','' )
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 559401
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Custom Reverse CombineOrder SP Not setup'  
                     + '. (lsp_SORVCombineORD_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_OrderKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg    
      END
      ELSE IF NOT EXISTS (SELECT 1 FROM SYS.OBJECTS WITH (NOLOCK) WHERE [Name] = @c_RVCombineOrd_SP AND [Type] = 'P' )
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 559402
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Custom Reverse Combine Order SP: ' + @c_RVCombineOrd_SP + ' not found'  
                     + '. (lsp_SORVCombineORD_Wrapper) |' + @c_RVCombineOrd_SP

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_OrderKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = '' 
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success    
            ,  @n_err         = @n_err        
            ,  @c_errmsg      = @c_errmsg  
      END
      
      IF @n_Continue = 3
      BEGIN
         GOTO EXIT_SP
      END
         
      SET @CUR_RVORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                      --(Wan01) - START
      SELECT r.OrderKey
      FROM #RVORD AS r
      ORDER BY r.RowID

      OPEN @CUR_RVORD

      FETCH NEXT FROM @CUR_RVORD INTO @c_RVOrderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN   
         SELECT @n_BackEndProcess = 1                                               
         FROM  dbo.QCmd_TransmitlogConfig qcfg WITH (NOLOCK)  
         WHERE qcfg.TableName      = 'BackEndProcessQueue'
         AND   qcfg.[App_Name]     = 'WMS'  
         AND   qcfg.DataStream     = @c_ProcessType   
         AND   qcfg.StorerKey IN (@c_Storerkey, 'ALL')
         
         IF @n_BackEndProcess = 1  
         BEGIN
            SET @c_CallType = 'WM.lsp_SORVCombineORD_Wrapper'
            SET @c_ExecCmd = @c_RVCombineOrd_SP 
                           + ' @c_OrderKey = ''' + @c_RVOrderkey + ''''
                           + ',@b_Success = @b_Success OUTPUT'
                           + ',@n_Err = @n_Err OUTPUT'
                           + ',@c_ErrMsg = @c_Errmsg OUTPUT'
  
            SET @c_DocumentKey1 = @c_RVOrderkey
 
            EXEC [WM].[lsp_BackEndProcess_Submit]                                                                                                                     
               @c_Storerkey      = @c_Storerkey
            ,  @c_ModuleID       = 'Orders' 
            ,  @c_DocumentKey1   = @c_DocumentKey1  
            ,  @c_DocumentKey2   = ''      
            ,  @c_DocumentKey3   = ''      
            ,  @c_ProcessType    = @c_ProcessType   
            ,  @c_SourceType     = @c_SourceType    
            ,  @c_CallType       = @c_CallType
            ,  @c_RefKey1        = ''      
            ,  @c_RefKey2        = ''      
            ,  @c_RefKey3        = ''   
            ,  @c_ExecCmd        = @c_ExecCmd  
            ,  @c_StatusMsg      = 'Submitted to BackEndProcessQueue.'
            ,  @b_Success        = @b_Success   OUTPUT  
            ,  @n_err            = @n_err       OUTPUT                                                                                                             
            ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT  
            ,  @c_UserName       = '' 
         
            IF @b_Success = 0 
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 559404
               SET @c_ErrMsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing WM.lsp_BackEndProcess_Submit'
                     + '. (lsp_SORVCombineORD_Wrapper) ( ' + @c_ErrMsg + ' )'
               
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_RVOrderkey
                  ,  @c_Refkey2     = ''
                  ,  @c_Refkey3     = '' 
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success    
                  ,  @n_err         = @n_err        
                  ,  @c_errmsg      = @c_errmsg  

               GOTO EXIT_SP
            END
   
         END
         ELSE
         BEGIN
            BEGIN TRY
               SET @b_Success = 1
               SET @n_err = 0
         
               SET @c_SQL= N'EXEC ' + @c_RVCombineOrd_SP 
                           + ' @c_OrderKey = @c_RVOrderkey' 
                           + ',@b_Success  = @b_Success'  
                           + ',@n_err      = @n_err'      
                           + ',@c_errmsg   = @c_errmsg'                                
         
               SET @c_SQLParms = N'@c_RVOrderkey  NVARCHAR(10)'
                               + ',@b_Success   INT            OUTPUT'
                               + ',@n_err       INT            OUTPUT'
                               + ',@c_errmsg    NVARCHAR(255)  OUTPUT'
                                                         
               EXEC sp_ExecuteSql @c_SQL
                                 ,@c_SQLParms
                                 ,@c_RVOrderkey
                                 ,@b_Success     = @b_Success   OUTPUT
                                 ,@n_Err         = @n_Err       OUTPUT
                                 ,@c_ErrMsg      = @c_ErrMsg    OUTPUT
            END TRY

            BEGIN CATCH
               SET @n_err = 559403
               SET @c_ErrMsg = ERROR_MESSAGE()
            END CATCH

            IF @b_Success = 0
            BEGIN
               SET @n_err = 559403
            END

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing ' + @c_RVCombineOrd_SP + '. (lsp_SORVCombineORD_Wrapper)'
                           + ' ( ' + @c_ErrMsg + ' )'

               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_RVOrderkey
                  ,  @c_Refkey2     = ''
                  ,  @c_Refkey3     = '' 
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success    
                  ,  @n_err         = @n_err        
                  ,  @c_errmsg      = @c_errmsg   
                   
               GOTO EXIT_SP   
            END
         END
         FETCH NEXT FROM @CUR_RVORD INTO @c_RVOrderkey
      END
      CLOSE @CUR_RVORD
      DEALLOCATE @CUR_RVORD                                                         --(Wan01) - END
      
      IF @n_Continue = 1 AND @n_BackEndProcess = 0                                  --(Wan01)
      BEGIN
         SET @c_errmsg = 'Reverse Combine Order SuccessFully.'

         EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_OrderKey
         ,  @c_Refkey2     = ''
         ,  @c_Refkey3     = '' 
         ,  @c_WriteType   = 'MESSAGE' 
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success    
         ,  @n_err         = @n_err        
         ,  @c_errmsg      = @c_errmsg  
      END 
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH

   EXIT_SP:
   
   IF OBJECT_ID('tempdb..#RVORD','U') IS NOT NULL                                   --(Wan01) - START
   BEGIN
      DROP TABLE #RVORD
   END                                                                              --(Wan01) - END
   
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
      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_SORVCombineORD_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
      
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END

   REVERT
END

GO