SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetSNFRLBL01                                        */
/* Creation Date: 25-JAN-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-7669 - [CN] Doterra - Doterra ECOM Packing_CR           */
/*        :                                                             */
/* Called By:                                                           */
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
CREATE PROC [dbo].[isp_GetSNFRLBL01]
           @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_ScanLabel       NVARCHAR(60)
         , @c_SerialNo        NVARCHAR(30)   OUTPUT
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

         , @n_Cnt             INT = 0
         , @c_SerialNo_Sku    NVARCHAR(20)   = ''
         , @c_SerialNo_Return NVARCHAR(30)   = ''

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_SerialNo = ''

   IF LEN(@c_ScanLabel) <= 22
   BEGIN
      GOTO QUIT_SP
   END 

   SET @c_SerialNo_Return = REPLACE(@c_ScanLabel, 'http://ty.doterra.cn/', '')

   IF @c_SerialNo_Return <> ''
   BEGIN
      SET @n_Cnt = 0
      SET @c_SerialNo_Sku = ''
      SELECT @n_Cnt = 1
         ,   @c_SerialNo_Sku = SN.Sku 
      FROM SERIALNO SN WITH (NOLOCK)
      WHERE SN.Storerkey = @c_Storerkey
      AND   SN.Serialno  = @c_SerialNo_Return
      AND   SN.[Status]  < '6'

      IF @n_Cnt = 1 AND @c_SerialNo_Sku = @c_Sku
      BEGIN
         SET @c_SerialNo = @c_SerialNo_Return

         --Add SerialNo Validation
         IF EXISTS ( SELECT 1 FROM PACKSERIALNO PSN WITH (NOLOCK) 
                     JOIN PACKHEADER PH WITH (NOLOCK) ON (PSN.PickSlipNo = PH.PickSlipNo)
                     WHERE PSN.SerialNo= @c_SerialNo
                     AND PSN.Storerkey = @c_Storerkey
                     AND PH.[Status] < '9'
                   )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 69010
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Serial # has been scanned & packed. (isp_GetSNFRLBL01)'   
         END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetSNFRLBL01'
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