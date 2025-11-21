SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ12_CN                                         */
/* Creation Date: 30-Oct-2017                                              */
/* Copyright: LF                                                           */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
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
/* 16-Dec-2018  TLTING01 1.1  Missing NOLOCK                               */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ12_CN]  
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
           @c_Storerkey NVARCHAR(15),

         @cReceiptkey NVARCHAR(20),
         @cExternReceiptkey NVARCHAR(20),
         @cReceiptLineNumber NVARCHAR(20),
         @cSKU NVARCHAR(20),

         @nExternReceiptkey NVARCHAR(20),
         @nRecType        NVARCHAR(20),

         @nLottable05        DateTime,
         @nStorerKey      NVARCHAR(20)

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT              

   IF @n_continue IN (1,2)
   BEGIN
        Declare RD_CUR Cursor Fast_forward Read_only For
     SELECT Receiptkey,ExternReceiptkey,ReceiptLineNumber,SKU 
     FROM RECEIPTDETAIL WITH (NOLOCK)
     WHERE RECEIPTKEY = @c_Receiptkey AND ISNULL(EXTERNRECEIPTKEY,'') = '' AND ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE ReceiptLineNumber END

     OPEN RD_CUR FETCH NEXT FROM RD_CUR INTO @cReceiptkey,@cExternReceiptkey,@cReceiptLineNumber,@cSKU

     WHILE @@FETCH_STATUS<>-1

     BEGIN
        --tlting01
      IF EXISTS (SELECT 1 FROM RECEIPTDETAIL (NOLOCK) WHERE RECEIPTKEY = @cReceiptkey AND ReceiptLineNumber <> @cReceiptLineNumber AND ISNULL(EXTERNRECEIPTKEY,'') <> '' AND SKU = @cSKU)
         BEGIN
            --tlting01
            SET @nExternReceiptkey = (SELECT TOP 1 ExternReceiptkey FROM RECEIPTDETAIL (NOLOCK) WHERE RECEIPTKEY = @cReceiptkey AND ReceiptLineNumber <> @cReceiptLineNumber AND ISNULL(EXTERNRECEIPTKEY,'') <> '' AND SKU = @cSKU)
            UPDATE RECEIPTDETAIL SET EXTERNRECEIPTKEY = @nExternReceiptkey WHERE RECEIPTKEY = @cReceiptkey AND ReceiptLineNumber = @cReceiptLineNumber
         END
      ELSE
         BEGIN
            SET @nExternReceiptkey = (SELECT TOP 1 ExternReceiptkey FROM RECEIPTDETAIL WHERE RECEIPTKEY = @cReceiptkey AND ISNULL(EXTERNRECEIPTKEY,'') <> '' )
            UPDATE RECEIPTDETAIL SET EXTERNRECEIPTKEY = @nExternReceiptkey WHERE RECEIPTKEY = @cReceiptkey AND ReceiptLineNumber = @cReceiptLineNumber
         END

         SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
           SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63521
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ExtenReceiptKey Failed! (ispASNFZ12_CN)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                GOTO QUIT_SP
            END 
      FETCH NEXT FROM RD_CUR INTO @cReceiptkey,@cExternReceiptkey,@cReceiptLineNumber,@cSKU
     END
     CLOSE RD_CUR
     DEALLOCATE RD_CUR
   END
   
   SELECT @nRecType = RecType ,@nStorerKey = STORERKEY FROM RECEIPT WITH (NOLOCK) WHERE RECEIPTKEY = @c_Receiptkey
   

   IF @n_continue IN (1,2) and @nRecType = 'GRN'
   BEGIN
         --tlting01
     SELECT @nLottable05 = OPTION1 FROM STORERCONFIG (NOLOCK) WHERE STORERKEY = @nStorerKey AND CONFIGKEY = 'PreFinalizeReceiptSP' AND SVALUE = 'ispASNFZ12_CN'

        Declare RT_CUR Cursor Fast_forward Read_only For
     SELECT Receiptkey,ReceiptLineNumber 
     FROM RECEIPTDETAIL WITH (NOLOCK)
     WHERE RECEIPTKEY = @c_Receiptkey 

     OPEN RT_CUR FETCH NEXT FROM RT_CUR INTO @cReceiptkey,@cReceiptLineNumber

     WHILE @@FETCH_STATUS <> -1

     BEGIN
      UPDATE RECEIPTDETAIL SET LOTTABLE05 = @nLottable05 WHERE RECEIPTKEY = @c_Receiptkey AND ReceiptLineNumber = @cReceiptLineNumber

      SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63522
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Lottable05 Failed! (ispASNFZ12_CN)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                GOTO QUIT_SP
            END

      FETCH NEXT FROM RT_CUR INTO @cReceiptkey,@cReceiptLineNumber
     END
     CLOSE RT_CUR
     DEALLOCATE RT_CUR
   END

   
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ12_CN'
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