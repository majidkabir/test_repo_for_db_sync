SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_ASNValidateSku01                               */
/* Creation Date: 2020-Dec-01                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-14739 - CN NIKE O2 WMS RFID Receiving Module           */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 01-DEC-2020 Wan      1.0   Created                                   */
/* 20-JAN-2021 Wan01    1.1   WMS-16143 - NIKE_O2_RFID_Receiving_CR V1.0*/
/* 06-JUL-2021 WLChooi  1.2   WMS-17404 - Skip RFID Validation for      */
/*                            Outlet ASN (WL01)                         */
/* 05-Jan-2023 Wan02    1.3   WMS-21467-[CN]NIKE_Ecom_NFC RFID Receiving-CR*/
/*                            DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC isp_RFID_ASNValidateSku01
           @c_Receiptkey   NVARCHAR(10) = ''  
         , @c_Storerkey    NVARCHAR(15) = '' 
         , @c_SKU          NVARCHAR(20) = ''
         , @b_ReadRFIDTag  INT          = 0  OUTPUT      --(Wan01) 
         , @b_Success      INT          = 1  OUTPUT      --2: Question
         , @n_Err          INT          = 0  OUTPUT
         , @c_ErrMsg       NVARCHAR(255)= '' OUTPUT
         , @c_Tag_Reader   NVARCHAR(10) = '' OUTPUT      --(Wan02)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
        
         , @n_NikeSet         INT = 0

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @b_ReadRFIDTag = ISNULL(@b_ReadRFIDTag,0)
   SET @c_Tag_Reader = ''                                --(Wan02)
                                                         --   
   IF NOT EXISTS ( SELECT 1 
                   FROM RECEIPTDETAIL RD WITH (NOLOCK)
                   WHERE RD.ReceiptKey = @c_Receiptkey
                   AND RD.Storerkey = @c_Storerkey
                   AND RD.Sku = @c_SKU
                  )
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 83010   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Sku not found in ASN#: ' + @c_Receiptkey
                     +'. (isp_RFID_ASNValidateSku01)'   
      GOTO QUIT_SP
   END

   SELECT @c_errmsg= @c_errmsg + 'BP#1 SKU'
   FROM SKUINFO SIF WITH (NOLOCK) 
   WHERE SIF.Storerkey = @c_Storerkey
   AND   SIF.Sku       = @c_Sku
   AND   SIF.ExtendedField01 = 'BP1'

   SELECT @c_errmsg= @c_errmsg + CASE WHEN @c_errmsg = '' THEN '' ELSE ', ' END +  'BP#2 SKU'
   FROM SKUINFO SIF WITH (NOLOCK) 
   WHERE SIF.Storerkey = @c_Storerkey
   AND   SIF.Sku       = @c_Sku
   AND   SIF.ExtendedField02 = 'BP2'

   SELECT @c_errmsg= @c_errmsg + CASE WHEN @c_errmsg = '' THEN '' ELSE ', ' END 
                   + UPPER(SIF.ExtendedField03)                                  --(Wan02)
         ,@b_ReadRFIDTag = 1                                                     --(Wan01)
         ,@c_Tag_Reader  = LOWER(SIF.ExtendedField03)                            --(Wan02)
   FROM SKUINFO SIF WITH (NOLOCK) 
   WHERE SIF.Storerkey = @c_Storerkey
   AND   SIF.Sku       = @c_Sku
   AND   SIF.ExtendedField03 IN ('NFC', 'RFID')                                  --(Wan02)

   SELECT @c_errmsg= @c_errmsg + CASE WHEN @c_errmsg = '' THEN '' ELSE ', ' END + 'SET SKU'
         ,@n_NikeSet  = 1
   FROM SKU SKU WITH (NOLOCK) 
   WHERE SKU.Storerkey = @c_Storerkey
   AND   SKU.Sku       = @c_Sku
   AND   SKU.LottableCode = 'NIKESET'
   
   IF @n_NikeSet = 1 
   BEGIN
      SET @c_errmsg = @c_errmsg + '. Accept SET Sku?'
      SET @b_Success = 2
   END 

   --WL01 S
   IF EXISTS (SELECT 1 
              FROM RECEIPT R (NOLOCK)
              JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'NIKESoldTo' AND CL.Notes = R.UserDefine03 AND CL.Long = 'OUTLET'
                                       AND CL.Storerkey = R.StorerKey
              WHERE R.ReceiptKey = @c_ReceiptKey )
   BEGIN
      SET @b_ReadRFIDTag = 0
   END
   --WL01 E

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_ASNValidateSku01'
   END
   ELSE
   BEGIN
      IF @b_Success < 2
      BEGIN
         SET @b_Success = 1
      END
      
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO