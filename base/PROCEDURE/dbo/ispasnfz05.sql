SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispASNFZ05                                                       */
/* Creation Date: 19-AUG-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Delete ReceiptDetail line where ExpectedQty = 0             */                                                            
/*        : during ReceiptHeader Finalization                           */
/* Called By:  ispFinalizeReceipt                                       */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2019-11-01  Wan01    1.1   Fixed Deadlock. delete by Primary key     */ 
/************************************************************************/
CREATE PROC [dbo].[ispASNFZ05] 
            @c_ReceiptKey        NVARCHAR(10)
         ,  @c_ReceiptLineNumber NVARCHAR(10)
         ,  @b_Success           INT = 0  OUTPUT 
         ,  @n_err               INT = 0  OUTPUT 
         ,  @c_errmsg            NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
   
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)

         , @c_ReceiptLineNo   NVARCHAR(5)    --(Wan01)
         , @CUR_DEL           CURSOR         --(Wan01)
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN -- Optional if PB Transaction is AUTOCOMMIT = FALSE. No harm to always start BEGIN TRAN in begining of SP

   IF ISNULL(RTRIM(@c_ReceiptLineNumber),'') = ''
   BEGIN
      --(Wan01) - START
      SET @CUR_DEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT ReceiptLineNo = RD.ReceiptLineNumber
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND   RD.QtyExpected = 0
      AND   RD.BeforeReceivedQty = 0
      AND   RD.QtyReceived = 0
      AND   RD.Finalizeflag <> 'Y'

      OPEN @CUR_DEL
   
      FETCH NEXT FROM @CUR_DEL INTO @c_ReceiptLineNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE RECEIPTDETAIL --WITH (ROWLOCK)        --(Wan01)
         WHERE ReceiptKey = @c_Receiptkey
         AND   ReceiptLineNumber = @c_ReceiptLineNo   --(Wan01)
         AND   QtyExpected = 0                      
         AND   BeforeReceivedQty = 0              
         AND   QtyReceived = 0                    
         AND   Finalizeflag <> 'Y'                

         SET @n_err = @@ERROR   

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61005  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete RECEIPTDETAIL Failed. (ispASNFZ05)' 
            GOTO QUIT  
         END 

         FETCH NEXT FROM @CUR_DEL INTO @c_ReceiptLineNo
      END
      CLOSE @CUR_DEL
      DEALLOCATE @CUR_DEL  
      --(Wan01) - END
   END
   ELSE
   BEGIN
      SET @c_Storerkey = ''
      SET @c_Sku = ''
      SELECT @c_Storerkey = Storerkey
            ,@c_Sku       = Sku
      FROM RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @c_Receiptkey
      AND ReceiptLineNumber = @c_ReceiptLineNumber

      --(Wan01) - START
      SET @CUR_DEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT ReceiptLineNo = RD.ReceiptLineNumber
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND   RD.Storerkey  = @c_Storerkey
      AND   RD.Sku        = @c_Sku
      AND   RD.QtyExpected= 0
      AND   RD.BeforeReceivedQty = 0
      AND   RD.QtyReceived = 0
      AND   RD.Finalizeflag <> 'Y'  

      OPEN @CUR_DEL
   
      FETCH NEXT FROM @CUR_DEL INTO @c_ReceiptLineNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE RECEIPTDETAIL --WITH (ROWLOCK)        --(Wan01)
         WHERE ReceiptKey = @c_Receiptkey
         AND   ReceiptLineNumber = @c_ReceiptLineNo   --(Wan01)
         AND   Storerkey  = @c_Storerkey
         AND   Sku        = @c_Sku
         AND   QtyExpected= 0
         AND   BeforeReceivedQty = 0
         AND   QtyReceived = 0
         AND   Finalizeflag <> 'Y'  

         SET @n_err = @@ERROR   

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete RECEIPTDETAIL Failed. (ispASNFZ05)' 
            GOTO QUIT  
         END

         FETCH NEXT FROM @CUR_DEL INTO @c_ReceiptLineNo
      END
      CLOSE @CUR_DEL
      DEALLOCATE @CUR_DEL  
      --(Wan01) - END
   END
 QUIT:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispASNFZ05'
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