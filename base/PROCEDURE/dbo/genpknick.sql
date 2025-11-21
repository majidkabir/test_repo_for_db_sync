SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: GENPKNick                             */                                                                                  
/* Creation Date: 2019-03-19                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1794 - SPs for Wave Control Screens                    */
/*          - ( Generate Pack From Pick )                               */
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
CREATE PROC [dbo].[GENPKNick]                                                                                                                     
      @c_WaveKey              NVARCHAR(10)
   ,  @c_Loadkey              NVARCHAR(10) = ''
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)=''  OUTPUT 
   ,  @n_WarningNo            INT          = 0  OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                   
   ,  @c_UserName             NVARCHAR(50) = ''                                                                                                                         

AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt            INT = @@TRANCOUNT  
         ,  @n_Continue             INT = 1

         ,  @n_PickedCnt            INT = 0

         ,  @c_Facility             NVARCHAR(5)  = ''
         ,  @c_Storerkey            NVARCHAR(15) = ''

         ,  @c_Configkey            NVARCHAR(30) = ''
         ,  @c_PackFromPicked_SP    NVARCHAR(30) = ''


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
      SET @c_Loadkey = ISNULL(@c_Loadkey, '')
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN 
         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Do you want to generate pack from picked '
                       + CASE WHEN @c_Loadkey = '' THEN 'By Wave' ELSE 'By Load' END
                       + ' ?' 
         GOTO EXIT_SP
      END

      IF @c_Loadkey = ''
      BEGIN
         SET @c_Facility = ''
         SET @c_Storerkey= ''
         SELECT TOP 1 
                  @c_Facility = OH.Facility
               , @c_Storerkey= OH.Storerkey
         FROM WAVEDETAIL WD WITH (NOLOCK)  
         JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
         WHERE WD.Wavekey = @c_Wavekey
         ORDER BY WD.WaveDetailKey

         SET @c_Configkey = 'WAVGENPACKFROMPICKED_SP'
         SELECT @c_PackFromPicked_SP  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', @c_Configkey)

         SET @n_PickedCnt = 0
         SELECT @n_PickedCnt = 1 
         FROM WAVEDETAIL WD WITH (NOLOCK)
         JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
         WHERE WD.WaveKey = @c_WaveKey
      END
      ELSE
      BEGIN
         SET @c_Facility = ''
         SET @c_Storerkey= ''
         SELECT TOP 1 
                 @c_Facility = OH.Facility
               , @c_Storerkey= OH.Storerkey
         FROM LOADPLANDETAIL LPD WITH (NOLOCK)  
         JOIN ORDERS OH WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
         WHERE LPD.LoadKey = @c_LoadKey
         ORDER BY LPD.LoadLineNumber

         SET @c_Configkey = 'LPGENPACKFROMPICKED'
         SELECT @c_PackFromPicked_SP  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', @c_Configkey)

         SET @n_PickedCnt = 0
         SELECT @n_PickedCnt = 1 
         FROM LOADPLANDETAIL LPD WITH (NOLOCK)
         JOIN PICKDETAIL PD WITH (NOLOCK) ON LPD.Orderkey = PD.Orderkey
         WHERE LPD.LoadKey = @c_LoadKey
      END


      IF @c_PackFromPicked_SP <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_PackFromPicked_SP) AND type = 'P')
         BEGIN
            SET @n_continue = 3
            SET @n_err = 555901
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                           + ': Storerconfigkey: ' + @c_Configkey + ' must be assigned with valid stored proc name to use this function'
                           + '. (GENPKNick)'
                           + '|' + @c_Configkey
            GOTO EXIT_SP
         END 
      END

      IF @n_PickedCnt = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 555902
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                        + ': No Picks to generate pack. (GENPKNick)'
         GOTO EXIT_SP
      END

      
      IF @c_Loadkey = ''
      BEGIN
         BEGIN TRY
            EXEC  [dbo].[isp_WAVGenPackFromPicked_Wrapper]  
                 @c_WaveKey = @c_WaveKey    
               , @b_Success = @b_Success OUTPUT
               , @n_Err     = @n_Err     OUTPUT 
               , @c_ErrMsg  = @c_ErrMsg  OUTPUT 
         END TRY
         BEGIN CATCH
            SET @n_Err = 555903
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_WAVGenPackFromPicked_Wrapper. (GENPKNick)'   
                          + '(' + @c_ErrMsg + ')'          
         END CATCH
            
         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP
         END
      END
      ELSE
      BEGIN
         BEGIN TRY
            EXEC  [dbo].[isp_LPGenPackFromPicked_Wrapper]  
                    @c_LoadKey = @c_LoadKey    
                  , @b_Success = @b_Success OUTPUT
                  , @n_Err     = @n_Err     OUTPUT 
                  , @c_ErrMsg  = @c_ErrMsg  OUTPUT 
         END TRY
         BEGIN CATCH
            SET @n_Err = 555904
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_LPGenPackFromPicked_Wrapper. (GENPKNick)'   
                          + '(' + @c_ErrMsg + ')'          
         END CATCH
            
         IF @b_Success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP
         END
      END

      SET @c_ErrMsg = 'Generate Pack Completed.'
      
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'GENPKNick'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
      
   REVERT
END

GO