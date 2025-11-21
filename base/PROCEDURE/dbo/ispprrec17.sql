SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC17                                            */
/* Creation Date: 19-FEB-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-16389 - CN Sanrio copy toid to lottable                    */                               
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
CREATE PROC [dbo].[ispPRREC17]  
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
         , @c_ToID               NVARCHAR(18)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Lottable03         NVARCHAR(18)
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   IF @n_Continue IN(1,2)
   BEGIN        	
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ToID, ReceiptLineNumber, Storerkey
         FROM RECEIPTDETAIL (NOLOCK)
         WHERE Receiptkey = @c_Receiptkey
         AND (ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
         AND SUBSTRING(ToID,3,2) IN ('CP','BP') 
         ORDER BY ReceiptLineNumber
      
      OPEN CUR_RECDET  
      
      FETCH NEXT FROM CUR_RECDET INTO @c_ToID, @c_ReceiptLineNumber, @c_Storerkey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
   	  BEGIN
   	  	 SET @c_Lottable03 = SUBSTRING(@c_ToID,3,2)
   	  	    	  	 
         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
         SET Lottable03 =  @c_Lottable03,
             Lottable09  = CASE WHEN @c_Storerkey IN('1001','1002') THEN @c_Lottable03 ELSE Lottable09 END
         WHERE Receiptkey = @c_Receiptkey
         AND ReceiptLineNumber = @c_ReceiptLineNumber
            
         SET @n_err = @@ERROR  
         
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 82010    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC17)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         END  
         
         FETCH NEXT FROM CUR_RECDET INTO @c_ToID, @c_ReceiptLineNumber, @c_Storerkey
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC17'
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