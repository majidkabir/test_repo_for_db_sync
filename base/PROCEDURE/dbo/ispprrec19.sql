SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC19                                            */
/* Creation Date: 06-JUL-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-17404 - [CN]NIKE_PHC_Outlets_RFID_Receiving_CR             */                               
/*        : Before finalize ASN                                            */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispPRREC19]  
(     @c_Receiptkey  NVARCHAR(10)  
  ,   @c_ReceiptLineNumber  NVARCHAR(5) = ''      
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT
         , @n_Cnt                INT
         , @n_Continue           INT 
         , @n_StartTranCount     INT 
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   IF EXISTS ( SELECT 1
               FROM RECEIPT WITH (NOLOCK)
               JOIN RECEIPTDETAIL WITH (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
               WHERE RECEIPT.ReceiptKey = @c_Receiptkey
               AND (ISNULL(RECEIPTDETAIL.UserDefine02,'') = '' AND ISNULL(RECEIPTDETAIL.UserDefine04,'') = '') )
   BEGIN
      SET @n_continue = 3  
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
      SET @n_err = 62505    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UserDefine02 & UserDefine04 is Blank! Unable to finalize. (ispPRREC19)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
      GOTO QUIT_SP      
   END

   QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCount
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC19'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount
      BEGIN
         COMMIT TRAN
      END
   END
END

GO