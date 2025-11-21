SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRECD10                                          */
/* Creation Date: 14-Nov-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21164 - SG - PMI - Populate trade return from orders    */   
/*                                                                      */
/* Called By:isp_ReceiptDetailTrigger_Wrapper from Receiptdetail Trigger*/
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 14-Nov-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE PROC [dbo].[ispRECD10]
   @c_Action      NVARCHAR(10),
   @c_Storerkey   NVARCHAR(15),  
   @b_Success     INT   OUTPUT,
   @n_Err         INT   OUTPUT, 
   @c_ErrMsg      NVARCHAR(250)  OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue              INT,
           @n_StartTCnt             INT,
           @c_Receiptkey            NVARCHAR(10),
           @c_ReceiptLineNumber     NVARCHAR(5),
           @c_ALTSKU                NVARCHAR(20),
           @c_Type                  NVARCHAR(30),
           @c_Consigneekey          NVARCHAR(15)
                                   
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN ('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   

   IF @c_Action IN ('INSERT') 
   BEGIN   
      IF EXISTS (SELECT 1 
                 FROM #INSERTED I
                 JOIN RECEIPT R (NOLOCK) ON R.ReceiptKey = I.Receiptkey
                 JOIN ORDERS OH (NOLOCK) ON OH.Storerkey = R.StorerKey
                                        AND OH.OrderKey = R.POKey
                                        AND OH.ExternOrderKey = R.ExternReceiptKey
                 WHERE R.RECType = 'GRN'
                 AND R.DOCTYPE = 'R'
                 AND I.Storerkey = @c_Storerkey)
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT I.Receiptkey, I.ReceiptLineNumber, OD.ALTSKU, OH.[Type], OH.ConsigneeKey
         FROM #INSERTED I
         JOIN RECEIPT R (NOLOCK) ON R.ReceiptKey = I.Receiptkey 
         JOIN ORDERS OH (NOLOCK) ON OH.Storerkey = R.StorerKey
                                AND OH.OrderKey = R.POKey
                                AND OH.ExternOrderKey = R.ExternReceiptKey
         JOIN ORDERDETAIL OD (NOLOCK) ON OD.Storerkey = I.StorerKey
                                     AND OD.SKU = I.SKU
                                     AND OD.ExternLineNo = I.ExternLineNo
                                     AND OD.OrderKey = OH.OrderKey
         WHERE R.RECType = 'GRN'
         AND R.DOCTYPE = 'R'
         AND I.Storerkey = @c_Storerkey
      
         OPEN CUR_LOOP
      
         FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_ALTSKU, @c_Type, @c_Consigneekey
      
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE RECEIPTDETAIL
            SET AltSku = TRIM(@c_ALTSKU)
              , Lottable07 = @c_Receiptkey
              , Lottable08 = @c_Type
              , TrafficCop = NULL
              , EditDate   = GETDATE()
              , EditWho    = SUSER_SNAME()
            WHERE ReceiptKey = @c_Receiptkey
            AND ReceiptLineNumber = @c_ReceiptLineNumber

            IF @@ERROR <> 0
            BEGIN    
               SET @n_continue = 3    
               SET @n_err = 65055   -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
               SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update RECEIPTDETAIL Failed. (ispRECD10)'   
               
               GOTO QUIT_SP
            END     

            UPDATE RECEIPT
            SET CarrierKey = @c_Consigneekey
              , TrafficCop = NULL
              , EditDate   = GETDATE()
              , EditWho    = SUSER_SNAME()
            WHERE ReceiptKey = @c_Receiptkey

            IF @@ERROR <> 0
            BEGIN    
               SET @n_continue = 3    
               SET @n_err = 65060   -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
               SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update RECEIPT Failed. (ispRECD10)'   
               
               GOTO QUIT_SP
            END    
      
            FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_ALTSKU, @c_Type, @c_Consigneekey
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP   
      END
   END
  
   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   
   IF @n_Continue = 3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispRECD10'      
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END  

GO