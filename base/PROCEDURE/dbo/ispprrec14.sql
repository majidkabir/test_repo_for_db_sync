SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispPRREC14                                            */  
/* Creation Date: 30-SEP-2019                                              */  
/* Copyright: LFL                                                          */  
/* Written by:  CSCHONG                                                    */  
/*                                                                         */  
/* Purpose: WMS-10634 - CN_PVH QHW_Exceed_PreFinalizeReceiptSP_SP          */  
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.1                                                       */  
/*                                                                         */  
/* Version: 7.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/* 17-Aug-2022  WLChooi 1.1   WMS-20520 - No copy Doctype if RecType = NIF */
/*                            (WL01)                                       */
/* 17-Aug-2022  WLChooi 1.1   DevOps Combine Script                        */
/***************************************************************************/    
CREATE PROC [dbo].[ispPRREC14]    
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
         , @n_Cnt                INT  
         , @n_Continue           INT   
         , @n_StartTranCount     INT   

         , @c_Lottable02         NVARCHAR(18) = ''
         , @c_SKU                NVARCHAR(20) = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_RecDoctype         NVARCHAR(10) = ''
         , @c_ExternReceiptKey   NVARCHAR(20) = ''
         , @c_CUDF01             NVARCHAR(60) = ''
         , @c_CUDF02             NVARCHAR(60) = '' 
         , @c_code2              NVARCHAR(30) = ''
         , @c_RDUDF01            NVARCHAR(30) = ''
         , @c_Toid               NVARCHAR(18) = ''
         , @c_GetRecKey          NVARCHAR(20) = ''
         , @c_GetRecLineNo       NVARCHAR(10) = ''
         , @c_getRDUDF01         NVARCHAR(50) = ''
         , @c_GetTOid            NVARCHAR(18) = ''
         , @c_RecType            NVARCHAR(20) = ''   --WL01

   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
   SET @b_Debug = 0 
   SET @n_Continue = 1    
   SET @n_StartTranCount = @@TRANCOUNT    

   SELECT @c_RecDoctype = REC.Doctype
         ,@c_ExternReceiptKey = REC.ExternReceiptkey
         ,@c_code2 = ISNULL(C.code2,'')
         ,@c_CUDF01 = ISNULL(C.UDF01,'')
         ,@c_CUDF02 = ISNULL(C.UDF02,'')
         ,@c_RecType = REC.RECType   --WL01
   FROM RECEIPT REC WITH (NOLOCK)
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'PVHQHWASN'
                           AND C.Short = REC.DocType
                           AND C.Long  = REC.ReceiptGroup
   WHERE REC.Receiptkey = @c_Receiptkey

   UPDATE RECEIPTDETAIL WITH (ROWLOCK)
   SET  Lottable02 = CASE WHEN @c_RecType = 'NIF' THEN Lottable02 ELSE @c_RecDoctype END   --WL01
       ,ExternReceiptKey = CASE WHEN ISNULL(ExternReceiptKey,'') = '' THEN @c_ExternReceiptKey ELSE ExternReceiptKey END
       ,Lottable07 = CASE WHEN @c_code2 = '1' AND ISNULL(Lottable07,'') = '' THEN @c_CUDF01 ELSE Lottable07 END
       ,Lottable08 = CASE WHEN @c_code2 = '1' AND ISNULL(Lottable08,'') = '' THEN @c_CUDF02 ELSE Lottable08 END
     -- ,Userdefine02 = CASE WHEN LEFT(ToID, 3) = 'QHW' THEN Userdefine01 ELSE Userdefine02 END
      --,Userdefine01 = CASE WHEN LEFT(ToID, 3) = 'QHW' THEN ToId ELSE Userdefine01 END
       ,Lottable09 = CASE WHEN BeforeReceivedQty > 0 THEN @c_Receiptkey ELSE Lottable09 END
   WHERE Receiptkey = @c_Receiptkey
   AND (ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
   
   SET @n_err = @@ERROR  
   
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
      SET @n_err = 82006    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC14)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
      GOTO QUIT_SP
   END     

   DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT ReceiptKey ,ReceiptLineNumber, UserDefine01,ToID  
      FROM RECEIPTDETAIL (NOLOCK)  
      WHERE Receiptkey = @c_Receiptkey  
      ORDER BY ReceiptKey ,ReceiptLineNumber
        
   OPEN CUR_RECDET    
     
   FETCH NEXT FROM CUR_RECDET INTO @c_GetRecKey, @c_GetRecLineNo, @c_getRDUDF01 , @c_GetTOid
     
   SET @n_cnt = 1  
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)            
   BEGIN

   --IF @b_debug = '1'
   --BEGIN 
   --  SELECT @c_GetRecKey '@c_GetRecKey',@c_GetRecLineNo '@c_GetRecLineNo',@c_getRDUDF01 '@c_getRDUDF01',@c_GetTOid '@c_GetTOid'
   --END
   
   IF LEFT(@c_GetTOid,3) = 'QHW'
   BEGIN
        
      UPDATE RECEIPTDETAIL WITH (ROWLOCK)
      SET  Userdefine02 = @c_getRDUDF01
           ,Userdefine01 = @c_GetTOid
      WHERE Receiptkey = @c_GetRecKey
      AND ReceiptLineNumber = @c_GetRecLineNo
   
      SET @n_err = @@ERROR  
   
       IF @n_err <> 0   
       BEGIN  
         SET @n_continue = 3  
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
         SET @n_err = 82007    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC14)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         --ROLLBACK TRAN        
         GOTO QUIT_SP
       END   
       
       --IF @b_debug='1'
       --BEGIN
       --  SELECT Userdefine02,Userdefine01,ToID,* FROM RECEIPTDETAIL (NOLOCK) WHERE Receiptkey = @c_GetRecKey
         --AND ReceiptLineNumber = @c_GetRecLineNo
       --END 
       --ELSE
       --BEGIN
       --   WHILE @@TRANCOUNT > 0 
       --   COMMIT TRAN
       --END 
   
   END

   FETCH NEXT FROM CUR_RECDET INTO @c_GetRecKey, @c_GetRecLineNo, @c_getRDUDF01 , @c_GetTOid
   END  
   CLOSE CUR_RECDET  
   DEALLOCATE CUR_RECDET  

   
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC14'  
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