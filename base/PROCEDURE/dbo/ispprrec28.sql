SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC28                                            */
/* Creation Date: 10-MAR-2023                                              */
/* Copyright: LF                                                           */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-21870 PH MHPI Return ASN update lottable05 to oldest       */
/*          lottable05 date of the sku                                     */
/*                                                                         */
/* Called By: ispPreFinalizeReceiptWrapper                                 */
/*            Storerconfig: PreFinalizeReceiptSP                           */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 10-MAR-2023  NJOW    1.0   DEVOPS combine script                        */
/***************************************************************************/  
CREATE   PROC [dbo].[ispPRREC28]  
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
      
   DECLARE @n_Continue           INT,
           @n_StartTranCount     INT,
           @c_ReceiptLineNumber2 NVARCHAR(5),
           @dt_Lottable05        DATETIME 
           
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT                                                     

   --Main Process
   IF @n_Continue IN (1,2) 
   BEGIN
   	  IF EXISTS(SELECT 1 FROM RECEIPT (NOLOCK) WHERE Receiptkey = @c_Receiptkey AND DocType = 'R')
   	  BEGIN   	  	   	  	
         DECLARE CUR_REC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RD.ReceiptLineNumber, LOTATTR.Lottable05 - 1
            FROM RECEIPTDETAIL RD (NOLOCK)
            CROSS APPLY (SELECT TOP 1 LA.Lottable05 FROM LOTATTRIBUTE LA (NOLOCK)
                         WHERE RD.Storerkey = LA.Storerkey AND RD.Sku = LA.Sku
                         ORDER BY LA.Lottable05)AS LOTATTR
            WHERE RD.ReceiptKey = @c_Receiptkey
            AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RD.ReceiptLineNumber END
         
         OPEN CUR_REC 
         
         FETCH NEXT FROM CUR_REC INTO @c_ReceiptLineNumber2, @dt_Lottable05
         
         WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN(1,2)
         BEGIN
            UPDATE RECEIPTDETAIL WITH (ROWLOCK)
            SET Lottable05 = @dt_Lottable05
              , TrafficCop   = NULL
              , EditWho      = SUSER_SNAME()
              , EditDate     = GETDATE()
            WHERE Receiptkey = @c_Receiptkey
            AND ReceiptLineNumber = @c_ReceiptLineNumber2
            
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63510
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update RECEIPTDETAIL Table Failed! (ispPRREC28)' + ' ( '
                               +'SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END 
         
            FETCH NEXT FROM CUR_REC INTO @c_ReceiptLineNumber2, @dt_Lottable05
         END
         CLOSE CUR_REC
         DEALLOCATE CUR_REC
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPRREC28'
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