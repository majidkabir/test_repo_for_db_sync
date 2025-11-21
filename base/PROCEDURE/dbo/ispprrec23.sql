SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC23                                            */
/* Creation Date: 24-Jan-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-18788 - Nike BZ - ASN pre-finalize SP                      */                               
/*        : Before finalize ASN                                            */
/*                                                                         */
/* Called By: ispPreFinalizeReceiptWrapper                                 */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 24-Jan-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE PROC [dbo].[ispPRREC23]  
(     @c_Receiptkey         NVARCHAR(10)  
  ,   @c_ReceiptLineNumber  NVARCHAR(5) = ''      
  ,   @b_Success            INT           OUTPUT
  ,   @n_Err                INT           OUTPUT
  ,   @c_ErrMsg             NVARCHAR(255) OUTPUT   
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
         , @c_GetRecKey          NVARCHAR(10) = ''
         , @c_GetRecLineNumber   NVARCHAR(5)  = ''
         , @c_Lottable02         NVARCHAR(30) = ''
         , @c_Lottable03         NVARCHAR(30) = ''
         , @c_Lottable08         NVARCHAR(30) = ''
         , @c_Lottable09         NVARCHAR(30) = ''
         , @c_Lottable10         NVARCHAR(30) = ''
         , @c_Storerkey          NVARCHAR(15)
         , @c_DocType            NVARCHAR(10)
         , @c_DuplicateFrom      NVARCHAR(5)
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   IF @n_Continue IN (1,2)
   BEGIN        
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RD.ReceiptKey, RD.ReceiptLineNumber
              , RD.Lottable02, RD.Lottable03, RD.Lottable08
              , RD.Lottable09, RD.Lottable10
         FROM RECEIPTDETAIL RD (NOLOCK)
         WHERE RD.ReceiptKey = @c_ReceiptKey
         AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') = '' 
                                         THEN RD.ReceiptLineNumber 
                                         ELSE @c_ReceiptLineNumber END
         GROUP BY RD.ReceiptKey, RD.ReceiptLineNumber
                , RD.Lottable02, RD.Lottable03, RD.Lottable08
                , RD.Lottable09, RD.Lottable10
         ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
      
      OPEN CUR_RECDET  
      
      FETCH NEXT FROM CUR_RECDET INTO @c_GetRecKey, @c_GetRecLineNumber
                                    , @c_Lottable02, @c_Lottable03, @c_Lottable08
                                    , @c_Lottable09, @c_Lottable10
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
      BEGIN
         UPDATE dbo.RECEIPTDETAIL
         SET UserDefine02 = @c_Lottable02
           , UserDefine03 = @c_Lottable03
           , UserDefine04 = @c_Lottable08
           , UserDefine05 = @c_Lottable09
           , UserDefine10 = @c_Lottable10
         WHERE ReceiptKey = @c_GetRecKey
         AND ReceiptLineNumber = @c_GetRecLineNumber

         SET @n_err = @@ERROR    
           
         IF @n_err <> 0     
         BEGIN    
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 82010      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC23)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         END 

         UPDATE dbo.RECEIPTDETAIL
         SET Lottable02 = ''
           , Lottable03 = ''
           , Lottable08 = ''
           , Lottable09 = ''
           , Lottable10 = ''
         WHERE ReceiptKey = @c_GetRecKey
         AND ReceiptLineNumber = @c_GetRecLineNumber
  
         SET @n_err = @@ERROR    
           
         IF @n_err <> 0     
         BEGIN    
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 82015      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC23)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         END 
         
         FETCH NEXT FROM CUR_RECDET INTO @c_GetRecKey, @c_GetRecLineNumber
                                       , @c_Lottable02, @c_Lottable03, @c_Lottable08
                                       , @c_Lottable09, @c_Lottable10
      END            
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET 
   END   
   
   IF @n_Continue IN (1,2)
   BEGIN        
      DECLARE CUR_DUPLICATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RD.DuplicateFrom, RD.ReceiptLineNumber, R.Storerkey, R.DocType
         FROM RECEIPT R (NOLOCK)
         JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
         WHERE RD.Receiptkey = @c_Receiptkey
         AND RD.ReceiptLineNumber = CASE WHEN ISNULL(RTRIM(@c_ReceiptLineNumber),'') = '' 
                                           THEN RD.ReceiptLineNumber ELSE @c_ReceiptLineNumber END
         AND ISNULL(RD.DuplicateFrom,'') <> ''
      
      OPEN CUR_DUPLICATE  
      
      FETCH NEXT FROM CUR_DUPLICATE INTO @c_DuplicateFrom, @c_GetRecLineNumber
                                       , @c_Storerkey, @c_DocType
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
      BEGIN
         UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
         SET RECEIPTDETAIL.Lottable01 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable01,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE01' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable01 ELSE RECEIPTDETAIL.Lottable01 END
           , RECEIPTDETAIL.Lottable02 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable02,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE02' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable02 ELSE RECEIPTDETAIL.Lottable02 END
           , RECEIPTDETAIL.Lottable03 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable03,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE03' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable03 ELSE RECEIPTDETAIL.Lottable03 END
           , RECEIPTDETAIL.Lottable04 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable04 ,112)='19000101' OR RECEIPTDETAIL.Lottable04 IS NULL 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE04' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable04 ELSE RECEIPTDETAIL.Lottable04 END
           , RECEIPTDETAIL.Lottable05 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable05 ,112)='19000101' OR RECEIPTDETAIL.Lottable05 IS NULL 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE05' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable05 ELSE RECEIPTDETAIL.Lottable05 END
           , RECEIPTDETAIL.Lottable06 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable06,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE06' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable06 ELSE RECEIPTDETAIL.Lottable06 END
           , RECEIPTDETAIL.Lottable07 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable07,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE07' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable07 ELSE RECEIPTDETAIL.Lottable07 END
           , RECEIPTDETAIL.Lottable08 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable08,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE08' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable08 ELSE RECEIPTDETAIL.Lottable08 END
           , RECEIPTDETAIL.Lottable09 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable09,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE09' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable09 ELSE RECEIPTDETAIL.Lottable09 END
           , RECEIPTDETAIL.Lottable10 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable10,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE10' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable10 ELSE RECEIPTDETAIL.Lottable10 END
           , RECEIPTDETAIL.Lottable11 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable11,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE11' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable11 ELSE RECEIPTDETAIL.Lottable11 END
           , RECEIPTDETAIL.Lottable12 = CASE WHEN ISNULL(RECEIPTDETAIL.Lottable12,'') = '' 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE12' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable12 ELSE RECEIPTDETAIL.Lottable12 END
           , RECEIPTDETAIL.Lottable13 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable13 ,112)='19000101' OR RECEIPTDETAIL.Lottable13 IS NULL 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE13' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable13 ELSE RECEIPTDETAIL.Lottable13 END
           , RECEIPTDETAIL.Lottable14 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable14 ,112)='19000101' OR RECEIPTDETAIL.Lottable14 IS NULL 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE14' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable14 ELSE RECEIPTDETAIL.Lottable14 END
           , RECEIPTDETAIL.Lottable15 = CASE WHEN CONVERT(VARCHAR(8) ,RECEIPTDETAIL.Lottable15 ,112)='19000101' OR RECEIPTDETAIL.Lottable15 IS NULL 
                                        AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'RECDTUPD' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE15' AND Code2 = @c_DocType) 
                                        THEN RDF.Lottable15 ELSE RECEIPTDETAIL.Lottable15 END
           , RECEIPTDETAIL.TrafficCop = NULL
           , RECEIPTDETAIL.EditWho = SUSER_SNAME()
           , RECEIPTDETAIL.EditDate = GETDATE()
         FROM RECEIPTDETAIL 
         JOIN RECEIPTDETAIL RDF (NOLOCK) ON RECEIPTDETAIL.Receiptkey = RDF.ReceiptKey
         WHERE RECEIPTDETAIL.Receiptkey = @c_Receiptkey
         AND RECEIPTDETAIL.ReceiptLineNumber = @c_GetRecLineNumber
         AND RDF.ReceiptLineNumber = @c_DuplicateFrom

         SET @n_err = @@ERROR    
           
         IF @n_err <> 0     
         BEGIN    
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 82020      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC23)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         END 
         
         FETCH NEXT FROM CUR_DUPLICATE INTO @c_DuplicateFrom, @c_GetRecLineNumber
                                          , @c_Storerkey, @c_DocType
      END            
      CLOSE CUR_DUPLICATE
      DEALLOCATE CUR_DUPLICATE 
   END
    
   QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_RECDET') IN (0 , 1)
   BEGIN
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_DUPLICATE') IN (0 , 1)
   BEGIN
      CLOSE CUR_DUPLICATE
      DEALLOCATE CUR_DUPLICATE   
   END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC23'
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