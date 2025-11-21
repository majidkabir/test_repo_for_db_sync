SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispASNFZ19                                              */
/* Creation Date: 24-SEP-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: [CN]Doterra_Exceed_Finalize Return ASN_CR                   */
/*        :                                                             */
/* Called By: ispPostFinalizeReceiptWrapper                             */
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
CREATE PROC [dbo].[ispASNFZ19]
           @c_Receiptkey         NVARCHAR(10)
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
         , @c_ReceiptLineNumber  NVARCHAR(5) = ''   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT      = @@TRANCOUNT 
         , @n_Continue           INT      = 1

         , @c_SerialNoKey        NVARCHAR(10) = ''    
         , @c_SerialNo           NVARCHAR(30) = ''
         , @c_Storerkey          NVARCHAR(30) = ''
         , @cur_RS               CURSOR

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_ReceiptLineNumber = ISNULL(@c_ReceiptLineNumber,'')


   --SELECT RS.SerialNo
   --   ,   RD.Storerkey
   --FROM RECEIPTDETAIL   RD WITH (NOLOCK)
   --JOIN RECEIPTSERIALNO RS WITH (NOLOCK) ON RD.ReceiptKey = RS.ReceiptKey AND RD.ReceiptLineNumber = RS.ReceiptLineNumber
   --WHERE RD.ReceiptKey = @c_Receiptkey
   --AND   ( @c_ReceiptLineNumber = '' OR 
   --       (@c_ReceiptLineNumber <> '' AND RD.ReceiptLineNumber = @c_ReceiptLineNumber)
   --      )
   --AND RD.FinalizeFlag = 'Y'

   BEGIN TRAN

   SET @cur_RS = CURSOR FAST_FORWARD READ_ONLY FOR   
   SELECT RS.SerialNo
      ,   RD.Storerkey
   FROM RECEIPTDETAIL   RD WITH (NOLOCK)
   JOIN RECEIPTSERIALNO RS WITH (NOLOCK) ON RD.ReceiptKey = RS.ReceiptKey AND RD.ReceiptLineNumber = RS.ReceiptLineNumber
   WHERE RD.ReceiptKey = @c_Receiptkey
   AND   ( @c_ReceiptLineNumber = '' OR 
          (@c_ReceiptLineNumber <> '' AND RD.ReceiptLineNumber = @c_ReceiptLineNumber)
         )
   AND RD.FinalizeFlag = 'Y'

   OPEN @cur_RS
   FETCH NEXT FROM @cur_RS INTO @c_SerialNo, @c_Storerkey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_SerialNoKey = ''
      SELECT @c_SerialNoKey = SN.SerialNoKey
      FROM SERIALNO SN WITH (NOLOCK)
      WHERE SN.Storerkey = @c_Storerkey
      AND   SN.SerialNo  = @c_SerialNo
select @c_SerialNoKey
      IF @c_SerialNoKey <> '' 
      BEGIN
select 'update'
         UPDATE SERIALNO  
         SET [Status] = '1'
            , EditWho = SUSER_SNAME()
            , EditDate= GETDATE()
         WHERE SerialNoKey = @c_SerialNoKey
      
         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 61000
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Update SerialNo table fail. (ispASNFZ19)'
            GOTO QUIT_SP
         END
      END
      FETCH NEXT FROM @cur_RS INTO @c_SerialNo, @c_Storerkey
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispASNFZ19'
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