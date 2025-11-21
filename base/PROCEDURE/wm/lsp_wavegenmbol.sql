SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveGenMBOL                                     */                                                                                  
/* Creation Date: 2019-03-19                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1651 - SWave Summary - Wave Control - Generate MBOL    */
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
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-02-24  Wan01    1.2   Fixed Pass into Sub SP to check if to execute*/
/*                            login if @c_UserName <> SUSER_SNAME()     */
/* 2021-09-22  Wan02    1.3   DevOps Combine Script                     */
/* 2021-09-22  Wan02    1.3   LFWM-3074 - TW  Wave Planning Skip Load Plan*/
/*                            Validation to Create MBOL                 */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_WaveGenMBOL]                                                                                                                     
      @c_WaveKey           NVARCHAR(10)
   ,  @b_Success           INT = 1           OUTPUT  
   ,  @n_err               INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg            NVARCHAR(255)= '' OUTPUT               
   ,  @c_UserName          NVARCHAR(128)= ''                                                                                                                         
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt         INT = @@TRANCOUNT  
         ,  @n_Continue          INT = 1

         ,  @b_InsertMBOL        BIT = 0

         ,  @n_totweight         FLOAT = 0.00 
         ,  @n_totcube           FLOAT = 0.00 
         ,  @d_OrderDate         DATETIME  
         ,  @d_Delivery_Date     DATETIME

         ,  @c_Facility          NVARCHAR(5)  = ''
         ,  @c_Storerkey         NVARCHAR(15) = ''
         ,  @c_Orderkey          NVARCHAR(10) = ''
         ,  @c_MBOLKey           NVARCHAR(10) = ''
         ,  @c_Loadkey           NVARCHAR(10) = ''
         ,  @c_ExternOrderkey    NVARCHAR(30) = ''
         ,  @c_Route             NVARCHAR(10) = ''

         ,  @c_OTMITFMBOL        NVARCHAR(30) = ''
         ,  @c_SPCode            NVARCHAR(30) = ''
         ,  @c_SCEMBOLShipWOLoad NVARCHAR(30) = ''       --(Wan02)
         ,  @CUR_WAVEORD         CURSOR

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
   BEGIN TRY
      IF NOT EXISTS( SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
                     WHERE WaveKey = @c_WaveKey )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 555701
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                       + ': No Orders populates to Wave. (lsp_WaveGenMBOL)'
         GOTO EXIT_SP
      END
      
      --(Wan02) - START
      SET @c_Storerkey= ''             --Move Up
      SET @c_Facility = ''
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
            , @c_Facility = OH.Facility
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
      WHERE WD.Wavekey = @c_WaveKey  
      ORDER BY WD.WaveDetailKey  
      
      SELECT @c_SCEMBOLShipWOLoad = sgr.Authority                             
      FROM fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'SCEMBOLShipWOLoad') sgr
      
      IF @c_SCEMBOLShipWOLoad = 0
      BEGIN
         IF EXISTS(  SELECT 1 FROM WAVEDETAIL WD WITH (NOLOCK)
                     JOIN ORDERS OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
                     WHERE WD.WaveKey = @c_WaveKey
                     AND (OH.Loadkey = '' OR OH.Loadkey IS NULL) )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 555702
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                          + ': Loadplan has not builded yet. (lsp_WaveGenMBOL)'
            GOTO EXIT_SP
         END
      END
      --(Wan02) - END

      SELECT @c_OTMITFMBOL = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'OTMITFMBOL')

      IF @c_OTMITFMBOL = '1'
      BEGIN
         GOTO EXIT_SP
      END
        
      SELECT @c_SPCode = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WAVEGENMBOL_SP')
      
      BEGIN TRAN        --(Wan02)   
      IF @c_SPCode NOT IN ( '0', '1' ) 
      BEGIN
         -- Call Custom SP if SP steup in StorerConfig
         BEGIN TRY
            EXEC [dbo].[isp_WaveGenMBOL_Wrapper]  
                 @c_WaveKey = @c_WaveKey    
               , @b_Success = @b_Success OUTPUT
               , @n_Err     = @n_Err     OUTPUT 
               , @c_ErrMsg  = @c_ErrMsg  OUTPUT 
         END TRY
         BEGIN CATCH
            SET @n_Err = 555703
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_WaveGenMbol_Wrapper. (lsp_WaveGenMBOL)' 
                           + '(' + @c_ErrMsg + ')'   
         END CATCH
            
         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
         END
            
         GOTO EXIT_SP                      
      END

      -- Standard Wave Build MBOL
      -- IF No custom SP Setup in Storerconfig, Call SCE Build MBOL SP Base on 1) Build MBOL Parm Key 2) Default Build MBOL By Consigneekey
      EXEC [WM].[lsp_Wave_BuildMBOL]  
        @c_WaveKey   = @c_WaveKey
      , @c_Facility  = @c_Facility                                                                                                                            
      , @c_StorerKey = @c_StorerKey           
      , @b_Success   = @b_Success   OUTPUT
      , @n_Err       = @n_Err       OUTPUT 
      , @c_ErrMsg    = @c_ErrMsg    OUTPUT
      , @c_UserName  = @c_UserName              -- (Wan01) Fixed Pass into Sub SP to check if to execute login if @c_UserName <> SUSER_SNAME()
       
      IF @b_Success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 555704
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing WM.lsp_Wave_BuildMBOL. (lsp_WaveGenMBOL)' 
                       + '(' + @c_ErrMsg + ')'   
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END 
EXIT_SP:
   IF (XACT_STATE()) = -1  
   BEGIN
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveGenMBOL'
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