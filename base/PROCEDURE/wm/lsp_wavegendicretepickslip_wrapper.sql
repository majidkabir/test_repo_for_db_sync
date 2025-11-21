SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveGenDicretePickSlip_Wrapper                  */                                                                                  
/* Creation Date: 2020-08-03                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2218- UATAdd 2 button into Generate dropdown           */
/*           (Orders and Wave Control)                                  */
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
CREATE PROC [WM].[lsp_WaveGenDicretePickSlip_Wrapper]                                                                                                                     
      @c_WaveKey           NVARCHAR(10)
   ,  @c_Orderkey          NVARCHAR(10)= ''  --Optional, If @c_orderkey = '', Generate Dicrete Pickslip By Wave
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

   DECLARE  @n_StartTCnt            INT = @@TRANCOUNT  
         ,  @n_Continue             INT = 1

         ,  @c_SQL                  NVARCHAR(2000) = ''
         ,  @c_SQLParms             NVARCHAR(2000) = ''

         ,  @c_Facility             NVARCHAR(5)  = ''  
         ,  @c_Storerkey            NVARCHAR(15) = ''  

         ,  @c_GenDicretePickSlip_SP  NVARCHAR(30) = ''

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
      SET @c_Orderkey = ISNULL(@c_Orderkey,'')

      SET @c_Storerkey= ''
      SET @c_Facility = ''

      IF @c_Orderkey = ''
      BEGIN
         SELECT TOP 1 
                  @c_Storerkey = OH.Storerkey
               ,  @c_Facility = OH.Facility
         FROM WAVEDETAIL WD WITH (NOLOCK)
         JOIN ORDERS OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
         WHERE WD.Wavekey = @c_Wavekey
         ORDER BY WD.WaveDetailKey 

         IF @c_Storerkey = ''
         BEGIN     
            SET @n_continue = 3
            SET @n_err = 558501
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                          + ': Wave Order not found. (lsp_WaveGenDicretePickSlip_Wrapper)'
            GOTO EXIT_SP
         END 
      END 
      ELSE
      BEGIN
         SELECT TOP 1 
                  @c_Storerkey = OH.Storerkey
               ,  @c_Facility = OH.Facility
         FROM ORDERS OH WITH (NOLOCK) 
         WHERE OH.Orderkey = @c_Orderkey
      END

      SELECT @c_GenDicretePickSlip_SP = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WaveGenDicretePickSlip')

      IF @c_GenDicretePickSlip_SP IN ( '0', '')
      BEGIN
         SET @n_Err = 0
         BEGIN TRY
         EXEC [dbo].[isp_CreatePickSlip]     
                @c_Orderkey            = @c_Orderkey         
               ,@c_Loadkey             = ''           --Create discrete or conso load determine by @c_ConsolidateByLoad setting  
               ,@c_Wavekey             = @c_Wavekey   --Create discrete or conso load of the wave determine by @c_ConsolidateByLoad setting     
               ,@c_PickslipType        = '3'           --Discrete('8', '3', 'D')  Conso('5','6','7','9','C')  Xdock ('XD','LB','LP')  
               ,@c_ConsolidateByLoad   = 'N'          --Y=Create load consolidate pickslip  N=create discrete pickslip  
               ,@c_Refkeylookup        = 'N'          --Y=Create refkeylookup records  N=Not create  
               ,@c_LinkPickSlipToPick  = 'N'          --Y=Update pickslipno to pickdetail.pickslipno  N=Not update to pickdetail  
               ,@c_AutoScanIn          = 'N'          --Y=Auto scan in the pickslip N=Not auto scan in                                              
               ,@b_Success             = @b_Success   OUTPUT  
               ,@n_Err                 = @n_Err       OUTPUT   
               ,@c_ErrMsg              = @c_ErrMsg    OUTPUT  
         END TRY

         BEGIN CATCH
            SET @n_err = 558502
            SET @c_errmsg = ERROR_MESSAGE()
         END CATCH

         IF @b_Success = 0  
         BEGIN
            SET @n_err = 558502
         END   

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing isp_CreatePickSlip. (lsp_WaveGenDicretePickSlip_Wrapper) '
                           + '( ' + @c_errmsg + ' )'
         END 

         GOTO EXIT_SP
      END
    
      IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_GenDicretePickSlip_SP) AND type = 'P')  
      BEGIN  
         SET @n_continue = 3
         SET @n_err = 558503
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                       + ': Invalid Stored Procedure: ' + @c_GenDicretePickSlip_SP + '. (lsp_WaveGenDicretePickSlip_Wrapper)'
         GOTO EXIT_SP
      END 

      SET @c_SQL = 'EXEC ' + @c_GenDicretePickSlip_SP 
                 + ' @c_WaveKey = @c_Wavekey'
                 + ',@c_Orderkey= @c_Orderkey'
                 + ',@b_Success = @b_Success OUTPUT'
                 + ',@n_Err     = @n_Err     OUTPUT' 
                 + ',@c_ErrMsg  = @c_ErrMsg  OUTPUT'  
          
      SET @c_SQLParms= N'@c_WaveKey  NVARCHAR(10)'
                     + ',@c_Orderkey NVARCHAR(10)'
                     + ',@b_Success  INT OUTPUT'
                     + ',@n_Err      INT OUTPUT'
                     + ',@c_ErrMsg   NVARCHAR(250) OUTPUT'
      BEGIN TRY
      EXEC sp_executesql @c_SQL   
                       , @c_SQLParms  
                       , @c_WaveKey  
                       , @c_Orderkey
                       , @b_Success OUTPUT                       
                       , @n_Err     OUTPUT  
                       , @c_ErrMsg  OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 558504
         SET @c_errmsg = ERROR_MESSAGE()
      END CATCH

      IF @b_Success = 0  
      BEGIN
         SET @n_err = 558504
      END   

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err) + ': Error Executing SP: ' + @c_GenDicretePickSlip_SP + '. (lsp_WaveGenDicretePickSlip_Wrapper) '
                        + '( ' + @c_errmsg + ' )'
         GOTO EXIT_SP
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WaveGenLoadPlan'
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