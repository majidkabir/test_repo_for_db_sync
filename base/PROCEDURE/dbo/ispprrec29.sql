SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC29                                            */
/* Creation Date: 27-JUN-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-22938 KR UA Update altsku to toid                          */
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
/* 27-JUN-2023  NJOW    1.0   DEVOPS combine script                        */
/***************************************************************************/  
CREATE   PROC [dbo].[ispPRREC29]  
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
           @c_AltSku             NVARCHAR(20) 
           
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT                                                     

   --Main Process
   IF @n_Continue IN (1,2) 
   BEGIN
   	  IF EXISTS(SELECT 1 FROM RECEIPT (NOLOCK) WHERE Receiptkey = @c_Receiptkey AND RecType IN('RTN','PRE') AND ReceiptGroup = 'B2B')
   	  BEGIN   	  	   	  	
         DECLARE CUR_REC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RD.ReceiptLineNumber, SKU.AltSku
            FROM RECEIPT R (NOLOCK)
            JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
            JOIN SKU (NOLOCK) ON RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku
            WHERE R.ReceiptKey = @c_Receiptkey
            AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RD.ReceiptLineNumber END
         
         OPEN CUR_REC 
         
         FETCH NEXT FROM CUR_REC INTO @c_ReceiptLineNumber2, @c_AltSku
         
         WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN(1,2)
         BEGIN
            UPDATE RECEIPTDETAIL WITH (ROWLOCK)
            SET ToID = @c_AltSku
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
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update RECEIPTDETAIL Table Failed! (ispPRREC29)' + ' ( '
                               +'SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END 
         
            FETCH NEXT FROM CUR_REC INTO @c_ReceiptLineNumber2, @c_AltSku
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPRREC29'
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