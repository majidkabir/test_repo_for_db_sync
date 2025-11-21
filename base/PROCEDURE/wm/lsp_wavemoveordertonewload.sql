SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveMoveOrderToNewLoad                          */                                                                                  
/* Creation Date: 2019-04-05                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( Processing View OrdersLoadShipRefUnit)                  */
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
/* 2019-04-05  Wan      1.0   Created.                                  */
/* 2021-01-15  Wan01    1.1   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveMoveOrderToNewLoad]                                                                                                                     
      @c_WaveKey              NVARCHAR(10)
   ,  @c_Loadkey              NVARCHAR(10)  
   ,  @c_LoadLineNumber       NVARCHAR(5)  
   ,  @c_ToLoadKey            NVARCHAR(10) = '' OUTPUT
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

         ,  @c_TableName      NVARCHAR(50)   = 'LOADPLANDETAIL'
         ,  @c_SourceType     NVARCHAR(50)   = 'lsp_WaveMoveOrderToNewLoad'

   SET @b_Success = 1
   SET @n_Err     = 0
   SET @n_ErrGroupKey = 0
          
   --(Wan01) - START   
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
   --(Wan01) - END

   --(Wan01) - START
   BEGIN TRY
      SET @c_ToLoadKey = ISNULL(@c_ToLoadKey,'')
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         IF @c_CreateNew <> 'Y' 
         BEGIN
            IF @c_ToLoadKey = ''
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 556451
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': To Load key is required. (lsp_WaveMoveOrderToNewLoad)'  
            
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_Loadkey
                  ,  @c_Refkey3     = @c_LoadLineNumber
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
               FROM LOADPLAN LP WITH (NOLOCK)
               WHERE LP.Loadkey = @c_ToLoadKey

               IF @n_Cnt = 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 556452
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Invalid To Load key.'
                                + ' To Load Key ' + @c_ToLoadKey + ' not found. (lsp_WaveMoveOrderToNewLoad) |' +@c_ToLoadKey

                  EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_WaveKey
                     ,  @c_Refkey2     = @c_Loadkey
                     ,  @c_Refkey3     = @c_LoadLineNumber
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
         SET @c_ErrMsg = 'Confirm to move order(s) to other/new Shipment Reference ?'
         GOTO EXIT_SP  
      END

      SET @n_Cnt = 0
      SELECT @c_Orderkey = LPD.Orderkey
            ,@n_Cnt = 1
      FROM MBOLDETAIL MBD WITH (NOLOCK)
      JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON ( MBD.Orderkey = LPD.Orderkey )
      WHERE LPD.Loadkey = @c_Loadkey
      AND   LPD.LoadLineNumber = @c_LoadLineNumber

      IF @n_Cnt = 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 556453
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Load Order #:' + @c_Orderkey
                       + ' had been populated to Ship Reference Unit. (lsp_WaveMoveOrderToNewLoad) |' + @c_Orderkey

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = @c_Loadkey
            ,  @c_Refkey3     = @c_LoadLineNumber
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT 

         GOTO EXIT_MOVE                              
      END                     

      BEGIN TRY
         EXEC [dbo].[isp_MoveOrderToLoad]  
              @c_Loadkey   = @c_Loadkey
            , @c_LoadLineNumber = @c_LoadLineNumber
            , @c_ToLoadkey = @c_ToLoadkey    OUTPUT
            , @b_Success   = @b_Success      OUTPUT
            , @n_Err       = @n_Err          OUTPUT 
            , @c_ErrMsg    = @c_ErrMsg       OUTPUT 
      END TRY

      BEGIN CATCH
         SET @n_Err = 556454
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_MoveOrderToLoad. (lsp_WaveMoveOrderToNewLoad)'   
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
            ,  @c_Refkey2     = @c_Loadkey
            ,  @c_Refkey3     = @c_LoadLineNumber
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
   
      SET @c_errmsg = 'Successfully Move Order(s) To Other/New Load plan: ' + @c_ToLoadKey

      EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_WaveKey
         ,  @c_Refkey2     = @c_Loadkey
         ,  @c_Refkey3     = @c_LoadLineNumber
         ,  @c_WriteType   = 'MESSAGE' 
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success   OUTPUT 
         ,  @n_err         = @n_err       OUTPUT 
         ,  @c_errmsg      = @c_errmsg    OUTPUT 
         
      EXIT_MOVE:    
      --IF @n_KeyCount = @n_TotalSelectedKeys
      --BEGIN
      --   SET @c_ErrMsg = 'Move Order(s) To Other/New Load plan is/are done.'
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
   --(Wan01) - END
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveMoveOrderToNewLoad'
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