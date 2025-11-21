SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC16                                            */
/* Creation Date: 23-SEP-2020                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-15316 - CN Natual Beauty Translate Lot2 to Lot11           */                               
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
/***************************************************************************/  
CREATE PROC [dbo].[ispPRREC16]  
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
         , @n_Continue           INT 
         , @n_StartTranCount     INT         
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable11         NVARCHAR(30)
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   IF @n_Continue IN(1,2)
   BEGIN        	
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Lottable02, ReceiptLineNumber
         FROM RECEIPTDETAIL (NOLOCK)
         WHERE Receiptkey = @c_Receiptkey
         AND (ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
         AND Lottable02 <> '' 
         AND Lottable02 IS NOT NULL
         ORDER BY ReceiptLineNumber
      
      OPEN CUR_RECDET  
      
      FETCH NEXT FROM CUR_RECDET INTO @c_Lottable02, @c_ReceiptLineNumber
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
   	  BEGIN
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable02,'1','A')
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable11,'2','B')
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable11,'3','C')
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable11,'4','D')
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable11,'5','E')
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable11,'6','F')
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable11,'7','G')
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable11,'8','H')
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable11,'9','I')
   	  	 SET @c_Lottable11 = REPLACE(@c_Lottable11,'0','J')
   	  	 
         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
         SET Lottable11 =  @c_Lottable11 
         WHERE Receiptkey = @c_Receiptkey
         AND ReceiptLineNumber = @c_ReceiptLineNumber
            
         SET @n_err = @@ERROR  
         
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 82010    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC16)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         END  
         
         FETCH NEXT FROM CUR_RECDET INTO @c_Lottable02, @c_ReceiptLineNumber
   	  END
   	  CLOSE CUR_RECDET
   	  DEALLOCATE CUR_RECDET                                    
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC16'
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