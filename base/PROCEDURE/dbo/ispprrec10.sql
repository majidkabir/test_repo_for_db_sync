SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC10                                            */
/* Creation Date: 01-OCT-2018                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-6456 - PH Alcon finalize validation                        */                               
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
CREATE PROC [dbo].[ispPRREC10]  
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
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   IF NOT EXISTS( SELECT 1 
                  FROM RECEIPT R (NOLOCK)
                  JOIN CODELKUP CL (NOLOCK) ON R.Storerkey = CL.Storerkey
                                            AND R.RecType = CL.Code
                                            AND CL.Listname = 'RECTYPE'
                                            AND UDF01 = 'Y'
                  WHERE R.Receiptkey = @c_Receiptkey                                    
                )
   BEGIN
      GOTO QUIT_SP        
   END
   
   IF @n_Continue IN(1,2)
   BEGIN        	
       SELECT RD.Lottable02, 
              MAX(LA.Lottable07) AS Lottable07,
              COUNT(DISTINCT LA.Lottable07) AS L7Cnt,
              RD.SKU
       INTO #TMP_LOT27       
       FROM RECEIPTDETAIL RD (NOLOCK)
       JOIN LOTATTRIBUTE LA (NOLOCK) ON RD.Lottable02 = LA.Lottable02 AND RD.Storerkey = LA.Storerkey AND RD.Sku = LA.Sku
       JOIN LOT  (NOLOCK) ON LA.Lot = LOT.Lot
       WHERE RD.Receiptkey = @c_Receiptkey
       AND LOT.Qty > 0
       AND LA.Lottable07 <> ''
       GROUP BY RD.Lottable02, RD.Sku
       
       SELECT TOP 1 @c_ReceiptLineNumber = RD.ReceiptLineNumber
       FROM RECEIPTDETAIL RD (NOLOCK) 
       JOIN #TMP_LOT27 T ON RD.Lottable02 = T.Lottable02 AND RD.Sku = T.Sku
       WHERE RD.Receiptkey = @c_Receiptkey
       AND (RD.Lottable07 <> T.Lottable07
            OR T.L7Cnt > 1)
       ORDER BY RD.ReceiptLineNumber
       
       IF ISNULL(@c_ReceiptLineNumber,'') <> ''
       BEGIN
          SET @n_continue = 3  
          SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
          SET @n_err = 82000    
          SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Receipt Line: ' + RTRIM(@c_ReceiptLineNumber) + ' Lottable07 not match with inventory lottable07 of same Lottable02. (ispPRREC10)' 
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
       END   	
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC10'
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