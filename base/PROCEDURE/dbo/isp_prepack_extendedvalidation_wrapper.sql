SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PrePack_ExtendedValidation_Wrapper                  */
/* Creation Date: 20-AUG-2019                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-9973 - [MY] PrePack Extended Validation                 */
/*                                                                      */
/* Called By: nep_w_scannpack.em_pickslipno.ue_prepackvalidation        */
/*          : nep_w_packing_maintenance.dw_header.ue_prepackvalidation  */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 03-Jul-2023 WLChooi  1.1   Bug Fix (WL01)                            */
/* 03-Jul-2023 WLChooi  1.1   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_PrePack_ExtendedValidation_Wrapper]
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

         , @c_GetAuthority    NVARCHAR(50)

         , @n_IsConso         INT = 0
         , @c_Configkey       NVARCHAR(50)

 

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

      SET @n_IsConso = 1
      SET @c_Configkey = 'PrePackConsoExtValidation'
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
      SET @n_IsConso = 0
      SET @c_Facility = ''
      SET @c_Storerkey= ''
      SET @c_Configkey = 'PrePackDiscreteExtValidation'

      SELECT @c_Facility = OH.Facility
         ,   @c_Storerkey= OH.Storerkey
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey
   END

   SET @b_Success = 1
   SET @c_GetAuthority = ''

   EXEC nspGetRight      
         @c_Facility  = @c_Facility     
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = @c_Configkey     
      ,  @b_Success   = @b_Success  OUTPUT      
      ,  @c_authority = @c_GetAuthority   OUTPUT      
      ,  @n_err       = @n_err      OUTPUT      
      ,  @c_errmsg    = @c_errmsg   OUTPUT

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61000
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Error Executing nspGetRight. (isp_PrePack_ExtendedValidation_Wrapper)'  
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_GetAuthority),'') IN ('0','')   --WL01
   BEGIN 
      GOTO QUIT_SP
   END    
   ELSE
   BEGIN
      EXEC isp_PrePack_ExtendedValidation
        @c_Pickslipno             = @c_Pickslipno
      , @c_PrePACKValidationRules = @c_GetAuthority
      , @b_Success                = @b_Success  OUTPUT
      , @c_ErrMsg                 = @c_ErrMsg   OUTPUT
      , @b_IsConso                = @n_IsConso

      IF @b_success <> 1  
      BEGIN  
         SET @n_Continue = 3
         SET @n_Err = 61005
         SET @c_ErrMsg = @c_ErrMsg + CHAR(13) + 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Error Executing isp_PrePack_ExtendedValidation. (isp_PrePack_ExtendedValidation_Wrapper)'  
         GOTO QUIT_SP
      END
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PrePack_ExtendedValidation_Wrapper'
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