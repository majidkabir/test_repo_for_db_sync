SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveMoveOrderToNewMBOL                          */                                                                                  
/* Creation Date: 2019-04-23                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( Move Order to other/New MBOL )                          */
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
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveMoveOrderToNewMBOL]                                                                                                                     
      @c_WaveKey              NVARCHAR(10)
   ,  @c_MBOLkey              NVARCHAR(10)  
   ,  @c_MBOLLineNumber       NVARCHAR(5)  
   ,  @c_ToMBOLKey            NVARCHAR(10) = '' OUTPUT
   ,  @c_CreateNew            CHAR(1)      = 'Y'
   ,  @n_TotalSelectedKeys    INT = 1
   ,  @n_KeyCount             INT = 1           OUTPUT
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT   
   ,  @n_WarningNo            INT          = 0  OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                
   ,  @c_UserName             NVARCHAR(50) = ''                                                                                                                         
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt      INT = @@TRANCOUNT  
         ,  @n_Continue       INT = 1

         ,  @n_Cnt            INT = 0

         ,  @c_Orderkey       NVARCHAR(10)  = ''

         ,  @c_TableName      NVARCHAR(50)   = 'MBOLDETAIL'
         ,  @c_SourceType     NVARCHAR(50)   = 'lsp_WaveMoveOrderToNewMBOL'

   SET @b_Success = 1
   SET @n_Err     = 0
   SET @n_ErrGroupKey = 0
               
   SET @n_Err = 0 
   --(mingle01) - START   
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
   --(mingle01) - END
   
   --(mingle01) - START
   BEGIN TRY
      SET @c_ToMBOLKey = ISNULL(@c_ToMBOLKey,'')
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         IF @c_CreateNew <> 'Y' 
         BEGIN
            IF @c_ToMBOLKey = ''
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 556551
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': To Ship Reference Unit key is required. (lsp_WaveMoveOrderToNewMBOL)'  
               
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_MBOLkey
                  ,  @c_Refkey3     = @c_MBOLLineNumber
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT              

            END                  
            ELSE
            BEGIN
               SELECT @n_Cnt = 1
               FROM MBOL MB WITH (NOLOCK)
               WHERE MB.MBOLkey = @c_ToMBOLKey

               IF @n_Cnt = 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 556552
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Invalid To Ship Reference Unit key.'
                                + ' To Ship Reference Unit key ' + @c_ToMBOLKey + ' not found. (lsp_WaveMoveOrderToNewMBOL) |' +@c_ToMBOLKey

                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_MBOLkey
                     ,  @c_Refkey3     = @c_MBOLLineNumber
                     ,  @c_WriteType   = 'ERROR' 
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   OUTPUT 
                     ,  @n_err         = @n_err       OUTPUT 
                     ,  @c_errmsg      = @c_errmsg    OUTPUT                   
                END
            END
         END

         IF @n_Continue = 3
         BEGIN
            GOTO EXIT_SP      
         END

         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Confirm to move order(s) to other/new Shipment Reference Unit ?'
         GOTO EXIT_SP  
      END

      BEGIN TRY
         EXEC [dbo].[isp_MoveOrdersToMBOL]  
              @c_MBOLkey   = @c_MBOLkey
            , @c_MBOLLineNumber = @c_MBOLLineNumber
            , @c_ToMBOLKey = @c_ToMBOLKey    OUTPUT
            , @b_Success   = @b_Success      OUTPUT
            , @n_Err       = @n_Err          OUTPUT 
            , @c_ErrMsg    = @c_ErrMsg       OUTPUT 
      END TRY

      BEGIN CATCH

         SET @n_Err = 556553
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_MoveOrdersToMBOL. (lsp_WaveMoveOrderToNewMBOL)'   
                        + '(' + @c_ErrMsg + ')'  

         IF (XACT_STATE()) = -1  
         BEGIN
            ROLLBACK TRAN

            WHILE @@TRANCOUNT < @n_StartTCnt
            BEGIN
               BEGIN TRAN
            END
         END  

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = @c_MBOLkey
            ,  @c_Refkey3     = @c_MBOLLineNumber
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT 
            
         SET @n_Continue = 3
         GOTO EXIT_MOVE                        
      END CATCH
           
      IF @b_Success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_MOVE   
      END

      SET @c_errmsg = 'Successfully Move Order to To Other/New Shipment Reference Unit: ' + @c_ToMBOLKey  
      EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_WaveKey
         ,  @c_Refkey2     = @c_MBOLkey
         ,  @c_Refkey3     = @c_MBOLLineNumber
         ,  @c_WriteType   = 'MESSAGE'  
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success   OUTPUT 
         ,  @n_err         = @n_err       OUTPUT 
         ,  @c_errmsg      = @c_errmsg    OUTPUT 

   EXIT_MOVE:    
      --IF @n_KeyCount = @n_TotalSelectedKeys
      --BEGIN
      --   SET @c_ErrMsg = 'Move Order(s) To Other/New Shipment Reference Unit is/are done.'
      --END

      IF @n_KeyCount < @n_TotalSelectedKeys
      BEGIN
         SET @n_KeyCount = @n_KeyCount + 1
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END

EXIT_SP:

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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveMoveOrderToNewMBOL'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
         
   REVERT
END

GO