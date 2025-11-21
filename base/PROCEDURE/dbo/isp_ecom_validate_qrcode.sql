SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ECOM_Validate_QRCode                                */
/* Creation Date: 2020-AUG-06                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-14315 - [CN] NIKE_O2_Ecom Packing_CR                    */
/*        :                                                             */
/* Called By: nep_n_cst_packqrf_ecom.of_policy_validate_qrcode          */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ECOM_Validate_QRCode]
           @c_PickSlipNo   NVARCHAR(10)
         , @n_CartonNo     INT
         , @c_LabelLine    NVARCHAR(5)
         , @c_QRCode       NVARCHAR(100)
         , @c_RegExp       NVARCHAR(100)  OUTPUT
         , @b_Success      INT            OUTPUT
         , @n_Err          INT            OUTPUT
         , @c_ErrMsg       NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1

         , @c_Storerkey       NVARCHAR(15) = ''

   SET @c_Storerkey = ''
   SELECT @c_Storerkey = PH.Storerkey
   FROM PACKHEADER PH WITH (NOLOCK)
   WHERE PH.PickSlipNo = @c_PickSlipNo
          
   IF EXISTS ( SELECT 1
               FROM PACKHEADER PH WITH (NOLOCK)
               JOIN PACKQRF PQRF WITH (NOLOCK) ON PH.PickSlipNo = PQRF.PickSlipNo
               WHERE PQRF.QRCode = @c_QRCode
               AND   PH.Storerkey= @c_Storerkey
               AND   PH.[Status] < '9'
               ) 
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 80010   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Disallow to pack duplicate QRCode. (isp_ECOM_Validate_QRCode)'   
      GOTO QUIT_SP  
   END        
   
   IF EXISTS ( SELECT 1
               FROM ExternOrdersDetail EOD WITH (NOLOCK)
               WHERE EOD.QRCode  = @c_QRCode
               AND EOD.Storerkey = @c_Storerkey 
               AND EOD.[Status] <> '9'
               ) 
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 80020   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Disallow to pack unshipped QRCode. (isp_ECOM_Validate_QRCode)'   
      GOTO QUIT_SP  
   END 
          
   SET @c_regexp = '^\d{13}?$'

   SELECT @c_regexp = ISNULL(CL.Long,'') 
   FROM CODELKUP CL(NOLOCK)
   WHERE CL.Listname = 'REQEXP'
   AND CL.Storerkey = @c_Storerkey
   AND CL.Code = 'QRCode'

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ECOM_Validate_QRCode'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO