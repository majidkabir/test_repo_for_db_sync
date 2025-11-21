SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RFID_ASNGetGiftSku01                                */
/* Creation Date: 2021-Apr-21                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-16736 - [CN]NIKE_GWP_RFID_Receiving_CR                 */
/*        :  Copy from isp_RFID_ASNValidateSku01 and modify             */
/* Called By:                                                           */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-Apr-21 WLChooi  1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[isp_RFID_ASNGetGiftSku01]
           @c_Receiptkey         NVARCHAR(10)  
         , @c_Storerkey          NVARCHAR(15)  
         , @c_SKU                NVARCHAR(20)          OUTPUT
         , @b_ReadRFIDTag        INT            = 0    OUTPUT
         , @c_GiftSKU            NVARCHAR(50)   = ''   OUTPUT
         , @b_GiftSKUFlag        INT            = 0    OUTPUT
         , @b_Success            INT            = 1    OUTPUT   --2: Question
         , @n_Err                INT            = 0    OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  = ''   OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
        
         , @c_UDF08           NVARCHAR(100) = ''
         , @c_UDF09           NVARCHAR(100) = ''

   SET @n_err          = 0
   SET @c_errmsg       = ''
   SET @b_GiftSKUFlag  = 0

   SET @b_ReadRFIDTag = ISNULL(@b_ReadRFIDTag,0)

   SELECT @c_UDF08 = ISNULL(RD.Userdefine08,'') 
        , @c_UDF09 = ISNULL(RD.Userdefine09,'') 
   FROM RECEIPTDETAIL RD WITH (NOLOCK)
   WHERE RD.ReceiptKey = @c_Receiptkey
   AND RD.Storerkey = @c_Storerkey
   AND RD.Sku = @c_SKU

   IF @c_UDF08 <> '' OR @c_UDF09 <> ''
   BEGIN
      SET @b_GiftSKUFlag = 1
      SET @c_GiftSKU     = @c_UDF08
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_ASNGetGiftSku01'
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