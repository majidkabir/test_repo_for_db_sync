SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC20                                            */
/* Creation Date: 15-SEP-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:CHONGCS                                                      */
/*                                                                         */
/* Purpose: WMS-17880 - [CN] HONMA_PreFinalizeReceiptSP                    */                               
/*        : Before finalize ASN                                            */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 14-OCT-2021  CSCHONG 1.0   Devops Scripts Combine                       */
/* 14-OCT-2021  CSCHONG 1.1   WMS-17880 revised report logic (CS01)        */
/* 16-Feb-2022  WLChooi 1.2   WMS-18932 - Add check condition (WL01)       */
/***************************************************************************/  
CREATE PROC [dbo].[ispPRREC20]  
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
         , @c_CLKCode            NVARCHAR(20)
         , @c_GetToid            NVARCHAR(18)
         , @c_UpdateLot03        NVARCHAR(5)
         , @c_UserDefine01       NVARCHAR(50)   --WL01
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   --WL01 S
   --Validation
   IF @n_Continue IN (1,2)
   BEGIN
      SELECT @c_UserDefine01 = R.UserDefine01
           , @c_Storerkey    = R.StorerKey
      FROM RECEIPT R (NOLOCK)
      WHERE R.ReceiptKey = @c_Receiptkey

      IF EXISTS (SELECT 1
                 FROM CODELKUP (NOLOCK)
                 WHERE LISTNAME = 'HONRECTYPE'
                 AND Storerkey = @c_Storerkey
                 AND Code = @c_UserDefine01)
      BEGIN
         GOTO QUIT_SP
      END
   END
   --WL01 E

   IF @n_Continue IN(1,2)
   BEGIN          
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ToID, ReceiptLineNumber, Storerkey
         FROM RECEIPTDETAIL (NOLOCK)
         WHERE Receiptkey = @c_Receiptkey
         AND (ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
         --AND SUBSTRING(toid,4,2) <> 'AP'                          --CS01
         ORDER BY ReceiptLineNumber
      
      OPEN CUR_RECDET  
      
      FETCH NEXT FROM CUR_RECDET INTO @c_ToID, @c_ReceiptLineNumber, @c_Storerkey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
      BEGIN
 
         SET @c_CLKCode = ''
         SET @c_GetToid = ''
         SET @c_Lottable03 = ''

         SET @c_GetToid =  SUBSTRING(@c_ToID,4,2)

         IF EXISTS (SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)
                    WHERE C.listname = 'HMALOC' AND C.Storerkey = @c_Storerkey
                    AND C.short = @c_GetToid ) --AND @c_GetToid <> 'AP'   --CS01
         BEGIN
            SELECT  @c_CLKCode = C.code
            FROM dbo.CODELKUP C WITH (NOLOCK)
            WHERE C.listname = 'HMALOC' AND C.Storerkey = @c_Storerkey
            AND C.short = @c_GetToid

            SET @c_Lottable03 = ISNULL(@c_CLKCode,'')
                   
            UPDATE RECEIPTDETAIL WITH (ROWLOCK)
            SET Lottable03 =   @c_Lottable03
            WHERE Receiptkey = @c_Receiptkey
            AND ReceiptLineNumber = @c_ReceiptLineNumber
            
            SET @n_err = @@ERROR  
         
            IF @n_err <> 0   
            BEGIN  
               SET @n_continue = 3  
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
               SET @n_err = 82010    
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC20)' 
                            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            END   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC20'
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