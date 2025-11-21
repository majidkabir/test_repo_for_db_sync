SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispASNFZ13                                              */
/* Creation Date: 17-AUG-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2625 - [TW] QKS StorerConfig for update POD             */
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
CREATE PROC [dbo].[ispASNFZ13]
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
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_ExternReceiptkey   NVARCHAR(30)
         , @c_MBOLKey            NVARCHAR(10)
         , @c_MBOLLineNumber     NVARCHAR(5)

         , @cur_POD              CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_ExternReceiptkey = ''
   SELECT @c_ExternReceiptkey = ExternReceiptkey
   FROM RECEIPT WITH (NOLOCK)
   WHERE Receiptkey = @c_Receiptkey

   BEGIN TRAN

   SET @cur_POD = CURSOR FAST_FORWARD READ_ONLY FOR   
   SELECT MBOLKey
      ,  MBOLLineNumber
   FROM POD WITH (NOLOCK)
   WHERE Orderkey = @c_ExternReceiptkey

   OPEN @cur_POD
   FETCH NEXT FROM @cur_POD INTO @c_MBOLKey, @c_MBOLLineNumber
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE POD WITH (ROWLOCK)
      SET Status = '2'
      WHERE MBOLKey = @c_MBOLKey
      AND   MBOLLineNumber = @c_MBOLLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 61000
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Update POD table fail (ispASNFZ13)'
         GOTO QUIT_SP
      END
      FETCH NEXT FROM @cur_POD INTO @c_MBOLKey, @c_MBOLLineNumber
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispASNFZ13'
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