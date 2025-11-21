SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC08                                            */
/* Creation Date: 14-Aug-2018                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-5981 CN PVH Pre-finalize update userdefine 1 & 2           */                               
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
/* 2021-03-16   WLChooi 1.1   WMS-16573 - Avoid updating Receiptdetail     */
/*                                        table multiple times (WL01)      */
/* 2022-05-25   WLChooi 1.2   DevOps Combine Script                        */
/* 2022-05-25   WLChooi 1.2   WMS-19738 - Add new logic (WL02)             */
/* 2023-03-15   NJOW01  1.3   WMS-21966 Skip update lottable09 by codelkup */
/***************************************************************************/  
CREATE   PROC [dbo].[ispPRREC08]  
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
         , @c_GetReceiptLineNumber  NVARCHAR(5)    --WL02
         , @c_ExternReceiptkey      NVARCHAR(50)   --WL02
         , @c_CLUDF01               NVARCHAR(50)   --WL02
         , @c_Code2                 NVARCHAR(30)   --WL02
         , @c_UpdLottable09         NVARCHAR(1)='Y'  --NJOW01
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   --WL02 S
   --IF NOT EXISTS( SELECT 1
   --               FROM RECEIPT WITH (NOLOCK)
   --               WHERE ReceiptKey = @c_Receiptkey
   --               AND DocType = 'A'
   --             )
   --BEGIN
   --   GOTO QUIT_SP        
   --END
   --WL02 E
   
   --NJOW01
   IF EXISTS(SELECT 1 
             FROM RECEIPT R (NOLOCK)
             JOIN CODELKUP CL (NOLOCK) ON R.RecType = CL.Code AND CL.ListName = 'PVHNOUPD'
             WHERE R.Receiptkey = @c_Receiptkey)
   BEGIN
   	  SET @c_UpdLottable09 = 'N'
   END          

   IF EXISTS(SELECT 1 
             FROM RECEIPT R (NOLOCK)
             JOIN CODELKUP CL (NOLOCK) ON R.Storerkey = CL.Storerkey AND R.Userdefine10 = CL.Short AND CL.Listname = 'ID2UDF01'
             WHERE R.Receiptkey = @c_Receiptkey)
   BEGIN
      --WL02 S
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT RD.ReceiptLineNumber
      FROM RECEIPTDETAIL RD (NOLOCK) 
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') = '' 
                                      THEN RD.ReceiptLineNumber 
                                      ELSE @c_ReceiptLineNumber END
      AND LEFT(RD.ToID, 2) = 'PS'
      AND ISNULL(RD.Userdefine02, '') = ''
      ORDER BY RD.ReceiptLineNumber

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_GetReceiptLineNumber

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
   	   SET Userdefine02  = Userdefine01,
   	       Userdefine01  = ToId,
             Lottable09    = CASE WHEN @c_UpdLottable09 = 'Y' THEN @c_Receiptkey ELSE Lottable09 END,  --WL02   --NJOW01
             TrafficCop    = NULL,           --WL02
             EditDate      = GETDATE(),      --WL02
             EditWho       = SUSER_SNAME()   --WL02
   	   WHERE Receiptkey = @c_Receiptkey
         AND ReceiptLineNumber = @c_GetReceiptLineNumber
   	   --AND LEFT(ToID, 2) = 'PS'   --WL02
   	   --AND ISNULL(Userdefine02, '') = ''   --WL01   --WL02

         SET @n_err = @@ERROR  
   
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 82000    
            SET @c_errmsg ='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC08)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            GOTO QUIT_SP
         END 
         FETCH NEXT FROM CUR_LOOP INTO @c_GetReceiptLineNumber
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP                   
   END

   IF EXISTS(SELECT 1 
             FROM RECEIPT R (NOLOCK)
             JOIN CODELKUP CL (NOLOCK) ON R.Storerkey = CL.Storerkey AND R.Userdefine10 = CL.Long AND CL.Listname = 'PVHBRAND'
             WHERE R.Receiptkey = @c_Receiptkey
             AND CL.Code2 = 'SAP')
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT RD.ReceiptLineNumber
                    , CASE WHEN ISNULL(RD.ExternReceiptkey,'') = '' 
                           THEN R.ExternReceiptKey 
                           ELSE '' END
                    , ISNULL(C1.UDF01,'')
                    , ISNULL(C1.Code2,'')
      FROM RECEIPTDETAIL RD (NOLOCK) 
      JOIN RECEIPT R (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
      LEFT JOIN CODELKUP C1 (NOLOCK) ON R.Storerkey = C1.Storerkey 
                                    AND R.ReceiptGroup = C1.Long 
                                    AND R.DOCTYPE = C1.Short
                                    AND C1.Listname = 'PVHASN'
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') = '' 
                                      THEN RD.ReceiptLineNumber 
                                      ELSE @c_ReceiptLineNumber END
      ORDER BY RD.ReceiptLineNumber

      OPEN CUR_UPD

      FETCH NEXT FROM CUR_UPD INTO @c_GetReceiptLineNumber, @c_ExternReceiptkey, @c_CLUDF01, @c_Code2

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
   	   SET ExternReceiptKey = CASE WHEN @c_ExternReceiptkey = '' THEN ExternReceiptKey ELSE @c_ExternReceiptkey END,
   	       Lottable07       = CASE WHEN @c_Code2 = '1' AND ISNULL(Lottable07,'') = '' AND ISNULL(@c_CLUDF01,'') <> '' 
                                     THEN @c_CLUDF01 ELSE Lottable07 END,
             Lottable09       = CASE WHEN @c_UpdLottable09 = 'Y' THEN @c_Receiptkey ELSE Lottable09 END, --NJOW01
             TrafficCop       = NULL,        
             EditDate         = GETDATE(),   
             EditWho          = SUSER_SNAME()
   	   WHERE Receiptkey = @c_Receiptkey
         AND ReceiptLineNumber = @c_GetReceiptLineNumber

         SET @n_err = @@ERROR  
   
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 82005    
            SET @c_errmsg ='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC08)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            GOTO QUIT_SP
         END 
         FETCH NEXT FROM CUR_UPD INTO @c_GetReceiptLineNumber, @c_ExternReceiptkey, @c_CLUDF01, @c_Code2
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD 
   END
   --WL02 E

   QUIT_SP:
   --WL02 S
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_UPD') IN (0 , 1)
   BEGIN
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD   
   END
   --WL02 E
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC08'
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