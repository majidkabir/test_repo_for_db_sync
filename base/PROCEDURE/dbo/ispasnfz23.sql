SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ23                                            */
/* Creation Date: 23-Apr-2021                                              */
/* Copyright: LF                                                           */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-16736 - [CN]NIKE_GWP_RFID_Receiving_CR                     */
/*                                                                         */
/* Called By: ispPostFinalizeReceiptWrapper                                */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 17-Aug-2022  WLChooi 1.1   JSM-88504 - Only copy if DocType = R (WL01)  */
/* 17-Aug-2022  WLChooi 1.1   DevOps Combine Script                        */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ23]  
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
      
   DECLARE @n_Continue           INT,
           @n_StartTranCount     INT,
           @c_ExternOrderkey     NVARCHAR(50),
           @c_ExternReceiptkey   NVARCHAR(50),
           @c_Storerkey          NVARCHAR(15),
           @c_SKU                NVARCHAR(20),
           @n_QtyReceived        INT

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT                                                     

   --WL01 S
   --Validation
   IF @n_Continue IN (1,2)
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM RECEIPT R WITH (NOLOCK)
                     WHERE R.ReceiptKey = @c_Receiptkey
                     AND R.DOCTYPE = 'R')
      BEGIN
         GOTO QUIT_SP
      END
   END
   --WL01 E

   --Main Process
   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.SKU, RD.QtyReceived
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE ReceiptLineNumber END
      AND ((RD.UserDefine08 IS NOT NULL AND RD.UserDefine08 <> '') OR (RD.UserDefine09 IS NOT NULL AND RD.UserDefine09 <> '') )

      OPEN CUR_RD 

      FETCH NEXT FROM CUR_RD INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_SKU, @n_QtyReceived

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
         SET UserDefine10 = @n_QtyReceived
           , TrafficCop   = NULL
           , EditWho      = SUSER_SNAME()
           , EditDate     = GETDATE()
         WHERE ReceiptKey = @c_Receiptkey
         AND ReceiptLineNumber = @c_ReceiptLineNumber
         AND SKU = @c_SKU
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update RECEIPTDETAIL Failed! (ispASNFZ23)' + ' ( '
                            +'SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END 

         FETCH NEXT FROM CUR_RD INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_SKU, @n_QtyReceived
      END
      CLOSE CUR_RD
      DEALLOCATE CUR_RD

   END 

QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ23'
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