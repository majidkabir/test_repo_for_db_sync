SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveFinalization                                */                                                                                  
/* Creation Date: 2019-03-19                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1651 - Wave Summary - Wave Control - Finalize MBOL     */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.3                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2020-07-08  Wan01    1.0   LFWM-2193 - Ship Reference Unit  Stored   */
/*                            ProceduresSQL queries                     */
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-12-13  Wan02    1.2   LFWM-3249 - UAT RG  Dock door booking     */
/*                            backend + SP                              */
/*                            DevOps Combine Order                      */
/* 2022-08-19  Wan03    1.3   LFWM-3698 - [PH] - NIKEPH Doorbooking     */
/*                            Testing_MBOLToTransportOrder Config       */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveFinalization] 
      @c_WaveKey              NVARCHAR(10)  
   ,  @c_LoadKey              NVARCHAR(10)               --IF Finalize By LOAD, mandatory to pass in LoadKey                                                                                                                          
   ,  @c_MBOLKey              NVARCHAR(10)               --IF Finalize By MBOL & Re-Finalize, mandatory to pass in MBOLKey 
   ,  @n_TotalSelectedKeys    INT = 1                    --Pass in the Total Selected Key Count value
   ,  @n_KeyCount             INT = 1           OUTPUT   --Initial pass in value @n_keyCount = 1, Counting Finalize document Key
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT 
   ,  @n_WarningNo            INT          = 0  OUTPUT   --Initial to Pass in '1', Pass In the value return By SP except RE-Finalize. RE-Finalize get logwarningno to pass in
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                     
   ,  @c_UserName             NVARCHAR(128) = ''                                                                                                                         
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT   --Capture Warnings/Questions/Errors/Meassage into WMS_ERROR_LIST Table
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt      INT            = @@TRANCOUNT  
         ,  @n_Continue       INT            = 1
         ,  @n_SeqNo          INT            = 0

         ,  @c_FNZType        NVARCHAR(15)   = ''
         ,  @c_TableName      NVARCHAR(50)   = 'Loadplan'
         ,  @c_SourceType     NVARCHAR(50)   = 'lsp_WaveFinalization'

         ,  @b_ContFinalize   INT            = 0   
         ,  @b_ReturnCode     INT            = 0
         ,  @n_LogWarningNo   INT            = 0
         
         
         ,  @c_Refkey1        NVARCHAR(20)   = ''                    --(Wan02)
         ,  @c_Refkey2        NVARCHAR(20)   = ''                    --(Wan02)
         ,  @c_Refkey3        NVARCHAR(20)   = ''                    --(Wan02)
         ,  @c_WriteType      NVARCHAR(50)   = ''                    --(Wan02)
         
         ,  @CUR_ERRLIST      CURSOR                                 --(Wan02)
         
   DECLARE  @t_WMSErrorList   TABLE                                  --(Wan02)
         (  RowID             INT            IDENTITY(1,1) 
         ,  TableName         NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')  
         )


   SET @b_Success = 1
   SET @n_Err     = 0
               
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
   BEGIN TRAN              --(Wan02)
   BEGIN TRY
      IF @n_ErrGroupKey IS NULL
      BEGIN
         SET @n_ErrGroupKey = 0
      END
      
      SET @c_WaveKey = ISNULL(@c_WaveKey, '')
      SET @c_LoadKey = ISNULL(@c_LoadKey, '')
      SET @c_MBOLKey = ISNULL(@c_MBOLKey, '')
      IF @c_LoadKey <> '' 
      BEGIN
         SET @c_FNZType = 'LOADPLAN'
         SET @c_TableName = 'Loadplan'
      END

      IF @c_MBOLKey <> '' 
      BEGIN
         SET @c_FNZType = 'MBOL'
         SET @c_TableName = 'MBOL'
      END

      IF @c_ProceedWithWarning = 'Y' AND @n_WarningNo < 1 
      BEGIN
         --SET @n_ErrGroupKey = 0      --(Wan01) 1 click 1 ErrGroupKey for Multiple Load / MBOL
         IF @c_FNZType = 'LOADPLAN' 
         BEGIN
            IF EXISTS( SELECT 1 FROM LOADPLAN WITH (NOLOCK)
                        WHERE LoadKey = @c_LoadKey
                        AND   FinalizeFlag = 'Y' )
            BEGIN
               SET @n_continue = 3
               SET @n_err = 556202
               SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(6),@n_err)
                             + ': Load Plan has been finalized. (lsp_WaveFinalization)'

               --(Wan02) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'ERROR', 0, @n_err, @c_errmsg)
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_Loadkey
               --   ,  @c_Refkey3     = @c_MBOLKey
               --   ,  @c_WriteType   = 'ERROR' 
               --   ,  @n_err2        = @n_err 
               --   ,  @c_errmsg2     = @c_errmsg 
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT 
               --(Wan02) - END
            END

            IF NOT EXISTS( SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK)
                           WHERE LoadKey = @c_LoadKey )
            BEGIN
               SET @n_continue = 3
               SET @n_err = 556203
               SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(6),@n_err)
                             + ': No Load Plan detail to Finalize. (lsp_WaveFinalization)'

               --(Wan02) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'ERROR', 0, @n_err, @c_errmsg)
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_LoadKey
               --   ,  @c_Refkey3     = @c_MBOLKey
               --   ,  @c_WriteType   = 'ERROR' 
               --   ,  @n_err2        = @n_err 
               --   ,  @c_errmsg2     = @c_errmsg 
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT
               --(Wan02) - END
            END

            IF @n_continue = 3
            BEGIN
               GOTO EXIT_SP 
            END

            GOTO FINALIZE_LOADPLAN
         END

         IF @c_FNZType = 'MBOL' 
         BEGIN
            IF EXISTS( SELECT 1 FROM MBOL MB WITH (NOLOCK)
                        WHERE MB.MBOLKey = @c_MBOLKey
                        AND   MB.FinalizeFlag = 'Y' )
            BEGIN
               SET @n_continue = 3
               SET @n_err = 556205
               SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(6),@n_err)
                             + ': MBOL has been finalized. (lsp_WaveFinalization)'

               --(Wan02) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'ERROR', 0, @n_err, @c_errmsg)
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_Loadkey
               --   ,  @c_Refkey3     = @c_MBOLKey 
               --   ,  @c_WriteType   = 'ERROR' 
               --   ,  @n_err2        = @n_err 
               --   ,  @c_errmsg2     = @c_errmsg 
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT  
               --(Wan02) - END
            END

            IF NOT EXISTS( SELECT 1 FROM MBOLDETAIL WITH (NOLOCK)
                           WHERE MBOLKey = @c_MBOLKey )
            BEGIN
               SET @n_continue = 3
               SET @n_err = 556206
               SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(6),@n_err)
                             + ': No Ship Ref. Unit detail to Finalize. (lsp_WaveFinalization)'
                             
               --(Wan02) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'ERROR', 0, @n_err, @c_errmsg)
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_Loadkey
               --   ,  @c_Refkey3     = @c_MBOLKey
               --   ,  @c_WriteType   = 'ERROR' 
               --   ,  @n_err2        = @n_err 
               --   ,  @c_errmsg2     = @c_errmsg 
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT
               --(Wan02) - END 
            END

            IF @n_continue = 3
            BEGIN
               GOTO EXIT_SP 
            END

            GOTO FINALIZE_MBOL
         END
      END

      FINALIZE_LOADPLAN:

      IF @c_FNZType = 'LOADPLAN' 
      BEGIN
         BEGIN TRY
            EXEC  [dbo].[ispFinalizeLoadPlan]  
                 @c_LoadKey = @c_LoadKey    
               , @b_Success = @b_Success OUTPUT
               , @n_Err     = @n_Err     OUTPUT 
               , @c_ErrMsg  = @c_ErrMsg  OUTPUT 
         END TRY
         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_Err = 556204
            SET @c_ErrMsg = ERROR_MESSAGE()   
                                             
         END CATCH

         IF @b_Success = 0 OR @n_Continue = 3
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing ispFinalizeLoadPlan. (lsp_WaveFinalization)'   
                           + '(' + @c_ErrMsg + ')' 
            
            --(Wan02) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'ERROR', 0, @n_err, @c_errmsg)  
         
            --EXEC [WM].[lsp_WriteError_List] 
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_WaveKey
            --   ,  @c_Refkey2     = @c_LoadKey
            --   ,  @c_Refkey3     = @c_MBOLKey
            --   ,  @c_WriteType   = 'ERROR' 
            --   ,  @n_err2        = @n_err 
            --   ,  @c_errmsg2     = @c_errmsg 
            --   ,  @b_Success     = @b_Success   OUTPUT 
            --   ,  @n_err         = @n_err       OUTPUT 
            --   ,  @c_errmsg      = @c_errmsg    OUTPUT  
            --(Wan02) - END     
            GOTO EXIT_SP    
         END 

         SET @c_ErrMsg = 'Finalize Loadplan is done.'
         --(Wan02) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'MESSAGE', 0, @n_err, @c_errmsg)  
         --EXEC [WM].[lsp_WriteError_List] 
         --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         --   ,  @c_TableName   = @c_TableName
         --   ,  @c_SourceType  = @c_SourceType
         --   ,  @c_Refkey1     = @c_WaveKey
         --   ,  @c_Refkey2     = @c_Loadkey
         --   ,  @c_Refkey3     = @c_MBOLKey
         --   ,  @c_WriteType   = 'MESSAGE' 
         --   ,  @n_err2        = @n_err 
         --   ,  @c_errmsg2     = @c_errmsg 
         --   ,  @b_Success     = @b_Success   OUTPUT 
         --   ,  @n_err         = @n_err       OUTPUT 
         --   ,  @c_errmsg      = @c_errmsg    OUTPUT 
         --(Wan02) - END
         GOTO FINALIZE_END
      END
  
      FINALIZE_MBOL:
      IF @c_FNZType = 'MBOL' 
      BEGIN
         SET @b_ContFinalize = 0

         IF @n_WarningNo = 2 
         BEGIN
            SET @b_ContFinalize = 1         
         END

         BEGIN TRY
            EXEC  [dbo].[ispFinalizeMBOL]  
                 @c_MBOLKey      = @c_MBOLKey    
               , @b_Success      = @b_Success OUTPUT
               , @n_Err          = @n_Err     OUTPUT 
               , @c_ErrMsg       = @c_ErrMsg  OUTPUT 
               , @b_ReturnCode   = @b_ReturnCode OUTPUT
               , @b_ContFinalize = @b_ContFinalize  
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_Err = 556207
            SET @c_ErrMsg = ERROR_MESSAGE()              --(Wan03)
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing ispFinalizeMBOL. (lsp_WaveFinalization)'   
                          + '(' + @c_ErrMsg + ')' 
         END CATCH                                       --(Wan03)
         IF @b_Success = 0 OR @n_Continue = 3            --(Wan03)
         BEGIN
            SET @n_Continue = 3                          --(Wan03)

            --(Wan02) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'ERROR', 0, @n_err, @c_errmsg)             
            --EXEC [WM].[lsp_WriteError_List] 
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_WaveKey
            --   ,  @c_Refkey2     = @c_LoadKey
            --   ,  @c_Refkey3     = @c_MBOLKey
            --   ,  @c_WriteType   = 'ERROR' 
            --   ,  @n_err2        = @n_err 
            --   ,  @c_errmsg2     = @c_errmsg 
            --   ,  @b_Success     = @b_Success   OUTPUT 
            --   ,  @n_err         = @n_err       OUTPUT 
            --   ,  @c_errmsg      = @c_errmsg    OUTPUT 
            -- (Wan02) - END 
            GOTO EXIT_SP                                               
         END                                             --(Wan03)            

         IF @b_Success = 0 AND @b_ReturnCode = 1 -- Validate MBOL with Warning
         BEGIN
            SET @n_SeqNo = 0

            WHILE 1 = 1
            BEGIN
               SET @c_errmsg = ''
               SELECT @n_SeqNo  = MER.SeqNo
                  ,   @c_errmsg = MER.LineText
               FROM MBOLErrorReport MER WITH (NOLOCK)
               WHERE MER.MBOLKey = @c_MBOLKey
               AND   MER.SeqNo > @n_SeqNo

               IF @@ROWCOUNT = 0
               BEGIN
                  BREAK
               END

               SET @n_LogWarningNo = 2

               --(Wan02) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'ERROR', @n_LogWarningNo, @n_err, @c_errmsg)   
            
               --EXEC [WM].[lsp_WriteError_List] 
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_WaveKey
               --   ,  @c_Refkey2     = @c_Loadkey
               --   ,  @c_Refkey3     = @c_MBOLKey 
               --   ,  @n_LogWarningNo= @n_LogWarningNo
               --   ,  @c_WriteType   = 'WARNING' 
               --   ,  @n_err2        = @n_err 
               --   ,  @c_errmsg2     = @c_errmsg 
               --   ,  @b_Success     = @b_Success   OUTPUT 
               --   ,  @n_err         = @n_err       OUTPUT 
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT   
               --(Wan02) - END
            END
         END
         ELSE IF @b_Success = 0 AND @b_ReturnCode < 0      -- Validate MBOL with Error
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 556208
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Validate MBOL fail. (lsp_WaveFinalization)'   
                           + '(' + @c_ErrMsg + ')' 

            --(Wan02) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'ERROR', 0, @n_err, @c_errmsg)   
            --EXEC [WM].[lsp_WriteError_List] 
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_WaveKey
            --   ,  @c_Refkey2     = @c_LoadKey
            --   ,  @c_Refkey3     = @c_MBOLKey 
            --   ,  @c_WriteType   = 'ERROR' 
            --   ,  @n_err2        = @n_err 
            --   ,  @c_errmsg2     = @c_errmsg 
            --   ,  @b_Success     = @b_Success   OUTPUT 
            --   ,  @n_err         = @n_err       OUTPUT 
            --   ,  @c_errmsg      = @c_errmsg    OUTPUT 
            --(Wan02) - END 
            GOTO EXIT_SP                
         END
         ELSE IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 556209
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Finalize MBOL fail. (lsp_WaveFinalization)'   
                           + '(' + @c_ErrMsg + ')' 

            --(Wan02) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'ERROR', 0, @n_err, @c_errmsg)   
            --EXEC [WM].[lsp_WriteError_List] 
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_WaveKey
            --   ,  @c_Refkey2     = @c_Loadkey
            --   ,  @c_Refkey3     = @c_MBOLKey
            --   ,  @c_WriteType   = 'ERROR' 
            --   ,  @n_err2        = @n_err 
            --   ,  @c_errmsg2     = @c_errmsg 
            --   ,  @b_Success     = @b_Success   OUTPUT 
            --   ,  @n_err         = @n_err       OUTPUT 
            --   ,  @c_errmsg      = @c_errmsg    OUTPUT 
           --(Wan02) - END
            GOTO EXIT_SP                    
         END

         --(Wan02) - START
         IF @n_LogWarningNo = 0 
         BEGIN
            SET @c_ErrMsg = 'Finalize MBOL is done.'
         
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_WaveKey, @c_Loadkey, @c_MBOLKey, 'MESSAGE', 0, @n_err, @c_errmsg)   
         
            --EXEC [WM].[lsp_WriteError_List] 
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_WaveKey
            --   ,  @c_Refkey2     = @c_Loadkey
            --   ,  @c_Refkey3     = @c_MBOLKey
            --   ,  @c_WriteType   = 'MESSAGE' 
            --   ,  @n_err2        = @n_err 
            --   ,  @c_errmsg2     = @c_errmsg 
            --   ,  @b_Success     = @b_Success   OUTPUT 
            --   ,  @n_err         = @n_err       OUTPUT 
            --   ,  @c_errmsg      = @c_errmsg    OUTPUT 
         END
         --(Wan02) - END
      END
 
      FINALIZE_END:
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

   --(Wan02) - START
   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue=3
      ROLLBACK TRAN
   END  
   --(Wan02) - END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt               --(Wan02)
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveFinalization'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
      
   --(Wan02) - START
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