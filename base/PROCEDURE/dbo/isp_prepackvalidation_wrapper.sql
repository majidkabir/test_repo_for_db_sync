SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PrePackValidation_Wrapper                           */
/* Creation Date: 26-FEB-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4051 - [TW] Packing Module Validation                   */
/*                                                                      */
/* Called By: nep_w_scannpack.em_pickslipno.ue_prepackvalidation        */
/*          : nep_w_packing_maintenance.dw_header.ue_prepackvalidation  */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_PrePackValidation_Wrapper]
           @c_PickSlipNo      NVARCHAR(10)
         , @c_SourceType      NVARCHAR(30)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SQL             NVARCHAR(4000) 
         , @c_SQLArgument     NVARCHAR(4000) 

         , @c_Orderkey        NVARCHAR(10)
         , @c_Loadkey         NVARCHAR(10)

         , @c_Facility        NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)

         , @c_SPCode          NVARCHAR(30)

 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Orderkey = ''

   SELECT @c_Orderkey = ISNULL(RTRIM(PH.Orderkey),'')
   FROM PICKHEADER PH WITH (NOLOCK)
   WHERE PH.PickHeaderKey = @c_PickSlipNo

   IF @c_Orderkey = ''
   BEGIN
      SET @c_Loadkey = ''
      SELECT TOP 1 @c_Loadkey = CASE WHEN ISNULL(RTRIM(PH.ExternOrderkey),'') = ''
                                     THEN ISNULL(RTRIM(PH.Loadkey),'')
                                     ELSE ISNULL(RTRIM(PH.ExternOrderkey),'')
                                     END
      FROM PICKHEADER PH WITH (NOLOCK)
      WHERE PH.PickHeaderKey = @c_PickSlipNo

      IF @c_Loadkey = ''
      BEGIN
         GOTO QUIT_SP
      END

      SET @c_Facility = ''
      SET @c_Storerkey= ''
      SELECT TOP 1 @c_Facility = LP.Facility
               ,   @c_Storerkey= OH.Storerkey
      FROM LOADPLAN LP WITH (NOLOCK)
      JOIN ORDERS   OH WITH (NOLOCK) ON (LP.Loadkey = OH.Loadkey)
      WHERE LP.Loadkey = @c_Loadkey
   END
   ELSE
   BEGIN
      SET @c_Facility = ''
      SET @c_Storerkey= ''
      SELECT @c_Facility = OH.Facility
         ,   @c_Storerkey= OH.Storerkey
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey
   END

   SET @b_Success = 1
   SET @c_SPCode = ''
   EXEC nspGetRight      
         @c_Facility  = @c_Facility     
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'PrePackValidation_SP'      
      ,  @b_Success   = @b_Success  OUTPUT      
      ,  @c_authority = @c_SPCode   OUTPUT      
      ,  @n_err       = @n_err      OUTPUT      
      ,  @c_errmsg    = @c_errmsg   OUTPUT

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61000
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Error Executing nspGetRight. (isp_PrePackValidation_Wrapper)'  
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN 
      GOTO QUIT_SP
   END    

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_SQL = N'EXEC ' + @c_SPCode 
              + ' @c_PickSlipNo    = @c_PickSlipNo'
              + ',@c_SourceType    = @c_SourceType'
              + ',@b_Success       = @b_Success OUTPUT'
              + ',@n_Err           = @n_Err     OUTPUT'
              + ',@c_ErrMsg        = @c_ErrMsg  OUTPUT'

   SET @c_SQLArgument= N'@c_PickSlipNo    NVARCHAR(10)'
                     + ',@c_SourceType    NVARCHAR(30)'
                     + ',@b_Success       INT            OUTPUT'
                     + ',@n_Err           INT            OUTPUT'
                     + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT'

   EXEC sp_ExecuteSql @c_SQL 
         , @c_SQLArgument
         , @c_PickSlipNo      
         , @c_SourceType 
         , @b_Success   OUTPUT
         , @n_Err       OUTPUT
         , @c_ErrMsg    OUTPUT      
        
   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      IF @c_ErrMsg = ''
      BEGIN
         SET @n_Err = 61010
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Error Executing ' + RTRIM(@c_SPCode)+ '. (isp_PrePackValidation_Wrapper)'  
      END
      GOTO QUIT_SP
   END

QUIT_SP:
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PrePackValidation_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = @n_Continue
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO