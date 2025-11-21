SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC06                                            */
/* Creation Date: 15-APR-2013                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-5599 JP Fanatics pre-finalize validate and Update TOID     */                               
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
CREATE PROC [dbo].[ispPRREC06]  
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
         , @c_Storerkey          NVARCHAR(10)
         , @c_RegExpPattern      NVARCHAR(250)
         , @c_ToId               NVARCHAR(18)

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   IF NOT EXISTS( SELECT 1
                  FROM RECEIPT WITH (NOLOCK)
                  WHERE ReceiptKey = @c_Receiptkey
                  AND DocType = 'A'
                )
   BEGIN
      GOTO QUIT_SP        
   END

   SELECT @c_Storerkey = Storerkey
   FROM RECEIPT (NOLOCK) 
   WHERE Receiptkey = @c_Receiptkey   

   SELECT TOP 1 @c_RegExpPattern = Long 
   FROM CODELKUP (NOLOCK) 
   WHERE ListName = 'IDFormat'              
   AND StorerKey = @c_StorerKey
   ORDER BY Long DESC
          
   IF ISNULL(@c_RegExpPattern,'') <> ''
   BEGIN
   	  SELECT TOP 1 @c_ToID = RD.ToID
   	  FROM RECEIPT R (NOLOCK)
   	  JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
   	  WHERE R.Receiptkey = @c_Receiptkey
   	  AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RD.ReceiptLineNumber END  
   	  AND master.dbo.RegExIsMatch(@c_RegExpPattern, RD.ToID, 0) = 0  
   	  ORDER BY RD.ToID
   	  
   	  IF ISNULL(@c_ToID,'') <> ''
   	  BEGIN
         SET @n_continue = 3  
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
         SET @n_err = 81005    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found invalid ID format ''' + RTRIM(@c_ToID) + '''' + '. RegExp:' + RTRIM(@c_RegExpPattern) + ' (ispPRREC06)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         GOTO QUIT_SP
   	  END   	    	    
   END 

   UPDATE RECEIPTDETAIL WITH (ROWLOCK)
   SET  --UserDefine01 = CASE WHEN ToID Like 'FJ%' THEN ToID ELSE UserDefine01 END
        UserDefine01 = ToID 
      , ToID         = CASE WHEN ToID = 'SSCC' THEN LTRIM(RIGHT(RTRIM(UserDefine01),18)) ELSE ToID END --NJOW01
      , EditDate = GETDATE()
      , EditWho  = SUSER_NAME()
      , Trafficcop = NULL
   WHERE ReceiptKey = @c_Receiptkey
   --AND   (ToID Like 'HM%' OR ToID = 'SSCC')

   SET @n_err = @@ERROR  
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
      SET @n_err = 81010    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC06)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
      GOTO QUIT_SP
   END  

   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      RETURN
   END 
END

GO