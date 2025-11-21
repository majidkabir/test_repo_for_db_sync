SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ07                                            */
/* Creation Date: 02-Dec-2015                                              */
/* Copyright: LF                                                           */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: SOS#358139 - ASN Pre-finalize update UCC status and copy       */
/*                       receiptkey to lottable06                          */
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
CREATE PROC [dbo].[ispASNFZ07]  
(     @c_Receiptkey  NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
  ,   @c_ReceiptLineNumber NVARCHAR(5)=''
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue INT,
           @n_StartTranCount INT,
           @c_Userdefine01 NVARCHAR(30),
           @c_Storerkey NVARCHAR(15)

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT              

   IF @n_continue IN (1,2)
   BEGIN
   	  DECLARE CUR_MIXSKUUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT Userdefine01, Storerkey
   	     FROM RECEIPTDETAIL(NOLOCK)
   	     WHERE Receiptkey = @c_Receiptkey
   	     AND ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE ReceiptLineNumber END
   	     GROUP BY Userdefine01, Storerkey
         HAVING COUNT(DISTINCT Sku) > 1

      OPEN CUR_MIXSKUUCC
      
      FETCH NEXT FROM CUR_MIXSKUUCC INTO @c_userdefine01, @c_Storerkey

      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN      	 
      	 UPDATE UCC WITH (ROWLOCK)
      	 SET Status = '6'
      	 WHERE Storerkey = @c_Storerkey
      	 AND UCCNo = @c_Userdefine01

    	   SELECT @n_err = @@ERROR
	   	   IF @n_err <> 0
	   	   BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63510
           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Table Failed! (ispASNFZ07)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
			   	 GOTO QUIT_SP
			   END      	 
      	 
         FETCH NEXT FROM CUR_MIXSKUUCC INTO @c_userdefine01, @c_Storerkey
      END	
      CLOSE CUR_MIXSKUUCC
      DEALLOCATE CUR_MIXSKUUCC        	 
   END
   
   IF @n_continue IN (1,2)
   BEGIN
   	  UPDATE RECEIPTDETAIL WITH (ROWLOCK)
   	  SET Lottable06 = Receiptkey,
   	      Lottable09 = Externreceiptkey
   	  WHERE Receiptkey = @c_Receiptkey
   	  AND ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE ReceiptLineNumber END
   	  
      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update RECEIPTDETAIL Table Failed! (ispASNFZ07)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
   END
      
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ07'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO