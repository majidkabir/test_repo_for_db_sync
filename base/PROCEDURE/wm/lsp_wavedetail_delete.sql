SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveDetail_Delete                               */                                                                                  
/* Creation Date: 2019-04-23                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( Delete Wave Detail )                                    */
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
/* 27-Oct-2020 LZG      1.1   Extended @c_UserName length to 128 (ZG01) */
/* 04-Jan-2021 SWT02    1.1   Do not execute login if user already      */
/*                            changed                                   */
/* 15-Jan-2021 Wan01    1.2   Add Big Outer Begin try/Catch             */
/* 2022-09-02  Wan02    1.3   LFWM-3602 - [CN]NIKE_Wave control_remove  */
/*                            orderkey from wavekey and please keep     */
/*                            orderkey in loadkey                       */
/*                            DevOps Combine Script                     */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveDetail_Delete] 
      @c_WaveKey              NVARCHAR(10)                                                                                                                    
   ,  @c_WaveDetailKey        NVARCHAR(10)  = ''        
   ,  @n_TotalSelectedKeys    INT = 1
   ,  @n_KeyCount             INT = 1                 OUTPUT
   ,  @b_Success              INT = 1                 OUTPUT  
   ,  @n_err                  INT = 0                 OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= ''       OUTPUT 
   ,  @n_WarningNo            INT          = 0        OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                     
   ,  @c_UserName             NVARCHAR(128) = ''                  -- ZG01                                                                                                           
   ,  @n_ErrGroupKey          INT          = 0        OUTPUT
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt               INT = @@TRANCOUNT  
         ,  @n_Continue                INT = 1

         ,  @b_Deleted                 BIT = 0
         ,  @b_ReturnCode              INT = 0

         ,  @c_Orderkey                NVARCHAR(10)   = ''  
         ,  @c_Loadkey                 NVARCHAR(10)   = ''
         ,  @c_LoadLineNumber          NVARCHAR(5)    = ''
         ,  @c_MBOLkey                 NVARCHAR(10)   = ''
         ,  @c_MBOLLineNumber          NVARCHAR(5)    = ''            
         ,  @c_TableName               NVARCHAR(50)   = 'WAVEDETAIL'
         ,  @c_SourceType              NVARCHAR(50)   = 'lsp_WaveDetail_Delete'
         
         ,  @c_Facility                NVARCHAR(5)    = ''                                --(Wan02) 
         ,  @c_Storerkey               NVARCHAR(15)   = ''                                --(Wan02) 
         ,  @c_SCEWavCustomDel         NVARCHAR(30)   = ''                                --(Wan02) 
         ,  @c_SCEWavCustomDel_Opt5    NVARCHAR(1000) = ''                                --(Wan02) 
         ,  @c_RemainOrderInLoad       NVARCHAR(1)    = 'N'                               --(Wan02) 

         ,  @CUR_DETAIL                CURSOR
   SET @b_Success = 1
   SET @n_Err     = 0
               
   SET @n_Err = 0 
   EXEC [WM].[lsp_SetUser] 
         @c_UserName = @c_UserName  OUTPUT
      ,  @n_Err      = @n_Err       OUTPUT
      ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

   IF @n_Err <> 0 
   BEGIN
      GOTO EXIT_SP
   END 
                   
   -- SWT02
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXECUTE AS LOGIN = @c_UserName      
   END

   BEGIN TRY --(Wan01) - START
      IF @n_ErrGroupKey IS NULL
      BEGIN 
         SET @n_ErrGroupKey = 0
      END

      SET @c_Orderkey = ''
      SET @c_Loadkey = ''
      SET @c_MBOLkey = ''
      SELECT @c_Orderkey = WD.Orderkey
            ,@c_Loadkey  = ISNULL(OH.Loadkey,'')
            ,@c_MBOLkey  = ISNULL(OH.MBOLkey,'')
            ,@c_Facility = OH.Facility             --(Wan02)
            ,@c_Storerkey= OH.Storerkey            --(Wan02)
      FROM WAVEDETAIL WD WITH (NOLOCK) 
      JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
      WHERE WaveDetailKey = @c_WaveDetailKey
      
      --(Wan02) - START
      SELECT @c_SCEWavCustomDel = fgr.Authority
            ,@c_SCEWavCustomDel_Opt5 = fgr.Option5
      FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'SCEWavCustomDel') AS fgr
      
      IF @c_SCEWavCustomDel = '1'
      BEGIN
         SELECT @c_RemainOrderInLoad = dbo.fnc_GetParamValueFromString('@c_RemainOrderInLoad', @c_SCEWavCustomDel_Opt5, @c_RemainOrderInLoad)
      END
      --(Wan02) - END

      IF @c_MBOLkey <> ''
      BEGIN
         SET @c_MBOLLineNumber = ''
         SELECT @c_MBOLLineNumber = MD.MBOLLineNumber
         FROM MBOLDETAIL MD WITH (NOLOCK)
         WHERE MD.MBOLkey = @c_MBOLkey
         AND   MD.Orderkey= @c_Orderkey

         IF @c_MBOLLineNumber <> ''
         BEGIN
            BEGIN TRY
               DELETE FROM MBOLDETAIL
               WHERE MBOLkey = @c_MBOLkey
               AND  MBOLLineNumber = @c_MBOLLineNumber
            END TRY

            BEGIN CATCH
               SET @n_Continue=3                --(Wan01)
               SET @n_Err = 557001
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Delete MBOLDETAIL Fail. (lsp_WaveDetail_Delete)'   
                              + '(' + @c_ErrMsg + ')' 
                    
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_WaveDetailkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT

               IF (XACT_STATE()) = -1  
               BEGIN
                  ROLLBACK TRAN

                  WHILE @@TRANCOUNT < @n_StartTCnt
                  BEGIN
                     BEGIN TRAN
                  END
               END 
               GOTO EXIT_SP
            END CATCH
         END
      END

      IF @c_Loadkey <> '' AND @c_RemainOrderInLoad = 'N'             --(Wan02)
      BEGIN
         SET @c_LoadLineNumber = ''
         SELECT @c_LoadLineNumber = LPD.LoadLineNumber
         FROM LOADPLANDETAIL LPD WITH (NOLOCK)
         WHERE LPD.Loadkey = @c_Loadkey
         AND   LPD.Orderkey= @c_Orderkey

         IF @c_LoadLineNumber <> ''
         BEGIN
            BEGIN TRY
               DELETE FROM LOADPLANDETAIL
               WHERE Loadkey = @c_Loadkey
               AND  LoadLineNumber = @c_LoadLineNumber
            END TRY

            BEGIN CATCH
               SET @n_Continue=3                --(Wan01)
               SET @n_Err = 557002
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Delete LOADPLANDETAIL Fail. (lsp_WaveDetail_Delete)'   
                              + '(' + @c_ErrMsg + ')' 
                    
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_WaveKey
                  ,  @c_Refkey2     = @c_WaveDetailkey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR' 
                  ,  @n_err2        = @n_err 
                  ,  @c_errmsg2     = @c_errmsg 
                  ,  @b_Success     = @b_Success   OUTPUT 
                  ,  @n_err         = @n_err       OUTPUT 
                  ,  @c_errmsg      = @c_errmsg    OUTPUT

               IF (XACT_STATE()) = -1  
               BEGIN
                  ROLLBACK TRAN

                  WHILE @@TRANCOUNT < @n_StartTCnt
                  BEGIN
                     BEGIN TRAN
                  END
               END 
               GOTO EXIT_SP
            END CATCH
         END
      END

      BEGIN TRY
         SET @b_Deleted = 1

         DELETE WAVEDETAIL 
         WHERE WaveDetailKey = @c_WaveDetailKey

      END TRY

      BEGIN CATCH
         SET @n_Continue=3                --(Wan01)
         SET @n_Err = 557003
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Delete WAVEDETAIL Fail. (lsp_WaveDetail_Delete)'   
                        + '(' + @c_ErrMsg + ')' 
                    
         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_WaveKey
            ,  @c_Refkey2     = @c_WaveDetailkey
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT

         IF (XACT_STATE()) = -1  
         BEGIN
            ROLLBACK TRAN

            WHILE @@TRANCOUNT < @n_StartTCnt
            BEGIN
               BEGIN TRAN
            END
         END 
      END CATCH
   END TRY
   
   BEGIN CATCH
      SET @n_Continue=3 
      SET @c_ErrMsg = ERROR_MESSAGE()  
      GOTO EXIT_SP             
   END CATCH
   --(Wan01) - END
EXIT_SP:
   IF @b_Deleted = 1
   BEGIN     
      IF @n_KeyCount = @n_TotalSelectedKeys
      BEGIN
         SET @c_ErrMsg = 'Delete Wave detail is/are done.'

         IF @n_ErrGroupKey > 0 
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg = 'Process Delete Selected Wave Detail is/are done with error(s).'
         END
      END

      IF @n_KeyCount < @n_TotalSelectedKeys
      BEGIN
         SET @n_KeyCount = @n_KeyCount + 1

         IF @n_ErrGroupKey > 0 AND  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
         BEGIN
            ROLLBACK TRAN
         END
      END
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
      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveDetail_Delete'
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