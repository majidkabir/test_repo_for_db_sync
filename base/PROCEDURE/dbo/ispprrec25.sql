SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC25                                            */
/* Creation Date: 08-Mar-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-18992 - [CN] Columbia_AddUCCFromLOT01                      */
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
/* 08-Mar-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE PROC [dbo].[ispPRREC25]  
(     @c_Receiptkey        NVARCHAR(10)  
  ,   @c_ReceiptLineNumber NVARCHAR(5) = ''      
  ,   @b_Success           INT           OUTPUT
  ,   @n_Err               INT           OUTPUT
  ,   @c_ErrMsg            NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue           INT,
           @n_StartTranCount     INT,
           @c_SKU                NVARCHAR(20),
           @c_Lottable01         NVARCHAR(18),
           @c_Lottable10         NVARCHAR(30),
           @c_Storerkey          NVARCHAR(15),
           @c_ToLot              NVARCHAR(10),
           @c_ToLoc              NVARCHAR(10),
           @c_ToID               NVARCHAR(18),
           @n_QtyReceived        INT

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT   

   --Main Process
   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT RD.ReceiptLineNumber, RD.Lottable01
      FROM RECEIPTDETAIL RD (NOLOCK)
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND (RD.ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
      ORDER BY RD.ReceiptLineNumber

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_ReceiptLineNumber, @c_Lottable01

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
      BEGIN
         UPDATE RECEIPTDETAIL WITH (ROWLOCK)
         SET Lottable10 = @c_Lottable01
           , Lottable01 = ''
           , TrafficCop = NULL
           , EditDate   = GETDATE()
           , EditWho    = SUSER_SNAME()
         WHERE ReceiptKey = @c_Receiptkey
         AND ReceiptLineNumber = @c_ReceiptLineNumber

         SELECT @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63540
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update RECEIPTDETAIL Failed! (ispPRREC25)' + ' ( '
                            +'SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END 

         FETCH NEXT FROM CUR_LOOP INTO @c_ReceiptLineNumber, @c_Lottable01
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC25'
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