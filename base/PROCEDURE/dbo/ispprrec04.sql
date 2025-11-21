SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC04                                            */
/* Creation Date: 03-Jan-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-845 CN MATA -  Trade Return for Mast Backroom.             */                               
/*        : Copy lottable before finalize ASN                              */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispPRREC04]  
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

   
   IF NOT EXISTS( SELECT 1
                  FROM RECEIPT WITH (NOLOCK)
                  WHERE ReceiptKey = @c_Receiptkey
                  AND DocType = 'R'
                )
   BEGIN
      GOTO QUIT_SP        
   END   
      
   UPDATE RECEIPTDETAIL WITH (ROWLOCK)
   SET  RECEIPTDETAIL.Lottable03 = RECEIPT.Userdefine02
      , RECEIPTDETAIL.Userdefine01 = RECEIPTDETAIL.Lottable09   
      , RECEIPTDETAIL.QtyExpected = RECEIPTDETAIL.BeforeReceivedQty
      , RECEIPTDETAIL.Lottable10 = RTRIM(LTRIM(CONVERT(NVARCHAR(10),RECEIPTDETAIL.BeforeReceivedQty)))
      , RECEIPTDETAIL.EditDate = GETDATE()
      , RECEIPTDETAIL.EditWho  = SUSER_SNAME()
      , RECEIPTDETAIL.Trafficcop = NULL
   FROM RECEIPTDETAIL 
   JOIN RECEIPT (NOLOCK) ON RECEIPTDETAIL.Receiptkey = RECEIPT.Receiptkey
   WHERE RECEIPTDETAIL.ReceiptKey = @c_Receiptkey
   AND RECEIPTDETAIL.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN 
                                             @c_ReceiptLineNumber 
                                         ELSE RECEIPTDETAIL.ReceiptLineNumber END
   AND RECEIPTDETAIL.FinalizeFlag <> 'Y'                                         

   SET @n_err = @@ERROR  
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
      SET @n_err = 81010    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC04)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
      GOTO QUIT_SP
   END  

   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      RETURN
   END 
END

GO