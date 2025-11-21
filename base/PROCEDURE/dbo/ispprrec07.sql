SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC07                                            */
/* Creation Date: 27-Jul-2018                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-5848 CN IKEA Pre-finalize add current date to lottable13   */                               
/*        : Before finalize ASN                                            */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 27-Aug-2018  NJOW01  1.0   WMS-5848 copy lottable to userdefine. Same   */
/*                            sku & pallet with diffrent line show different*/
/*                            time.                                        */
/***************************************************************************/  
CREATE PROC [dbo].[ispPRREC07]  
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
         , @dt_Lottable13        DATETIME
         , @c_Sku                NVARCHAR(20)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable07         NVARCHAR(30)
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   /*IF NOT EXISTS( SELECT 1
                  FROM RECEIPT WITH (NOLOCK)
                  WHERE ReceiptKey = @c_Receiptkey
                  AND DocType = 'A'
                )
   BEGIN
      GOTO QUIT_SP        
   END*/
   
   SELECT @dt_Lottable13 = CONVERT(DATETIME, CONVERT(NVARCHAR, GETDATE(), 112) + ' ' + LEFT(CONVERT(NVARCHAR, GETDATE(), 114),5))
   
   UPDATE RECEIPTDETAIL WITH (ROWLOCK)
   SET Lottable13 = @dt_Lottable13,
       Userdefine01 = CASE WHEN ISNULL(Userdefine01,'') = '' THEN Lottable02 ELSE Userdefine01 END,  --NJOW01
       Userdefine08 = CASE WHEN ISNULL(Userdefine08,'') = '' THEN Lottable01 ELSE Userdefine08 END  --NJOW01
   WHERE Receiptkey = @c_Receiptkey
   AND (ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')

   SET @n_err = @@ERROR  
   
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
      SET @n_err = 82000    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC07)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
      GOTO QUIT_SP
   END  

   --same pallet(lottable02) of a sku have multiple line(lottable07)
   DECLARE CUR_REC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT Sku, Lottable02 
     FROM RECEIPTDETAIL (NOLOCK)
     WHERE Receiptkey = @c_Receiptkey
     AND (ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
     AND Lottable02 <> '' 
     AND Lottable02 IS NOT NULL
     GROUP BY Sku, Lottable02
     HAVING COUNT(DISTINCT Lottable07) > 1
       
   OPEN CUR_REC  
          
   FETCH NEXT FROM CUR_REC INTO @c_Sku, @c_Lottable02
          
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN
   	  --line of sku of the pallet
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT Lottable07
         FROM RECEIPTDETAIL (NOLOCK)
         WHERE Receiptkey = @c_Receiptkey
         AND Sku = @c_Sku
         AND Lottable02 = @c_Lottable02
         ORDER BY Lottable07
      
      OPEN CUR_RECDET  
      
      FETCH NEXT FROM CUR_RECDET INTO @c_Lottable07
      
      SET @n_cnt = 1
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
   	  BEGIN
   	  	 --update time of each line with different second
         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
            SET Lottable13 =  DATEADD(ss, @n_cnt, Lottable13) 
            WHERE Receiptkey = @c_Receiptkey
            AND Sku = @c_Sku
            AND Lottable02 = @c_Lottable02
            AND Lottable07 = @c_Lottable07

         SET @n_err = @@ERROR  
         
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 82010    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC07)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         END  
         
         SET @n_cnt = @n_cnt + 1   

         FETCH NEXT FROM CUR_RECDET INTO @c_Lottable07
   	  END
   	  CLOSE CUR_RECDET
   	  DEALLOCATE CUR_RECDET                                 
   	
      FETCH NEXT FROM CUR_REC INTO @c_Sku, @c_Lottable02
   END
   CLOSE CUR_REC
   DEALLOCATE CUR_REC          	 
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC07'
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