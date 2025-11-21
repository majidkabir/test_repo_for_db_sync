SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispPOTRFAD                                                  */
/* Creation Date: 21-Nov-2014                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Temp SP to correct wrongly updated Qty for multi SKU UCC    */
/* Called By: ispPostFinalizeTransferWrapper                            */
/*          : Transferdetail del Trigger if AllowDelReleasedTransferID  */
/*          : is turn on                                                */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE   PROC [dbo].[ispPOTRFAD]
(     @c_Transferkey          NVARCHAR(10)
  ,   @b_Success              INT           OUTPUT
  ,   @n_Err                  INT           OUTPUT
  ,   @c_ErrMsg               NVARCHAR(255) OUTPUT
  ,   @c_TransferLineNumber   NVARCHAR(5)   = ''
  ,   @c_ID                   NVARCHAR(18)  = ''
  ,   @c_UpdateToID           NVARCHAR(1)   = 'Y'
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
         , @n_StartTCount        INT

         , @c_FromID             NVARCHAR(18)
         , @c_ToID               NVARCHAR(18)

         , @c_PalletFlag         NVARCHAR(30)
         , @c_Hold               NVARCHAR(10)

         , @c_InvHoldStatus      NVARCHAR(10)
         , @cUCCNo               NVARCHAR(40)
         
   SET @b_Success = 1
   SET @n_Err     = 0
   SET @c_ErrMsg  = ''
   SET @b_Debug   = '0'
   SET @n_Continue= 1
   SET @n_StartTCount = @@TRANCOUNT

   DECLARE CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   
   SELECT CASE WHEN LEFT(UCCNo,1) = 'Y' THEN '0' + RIGHT(UCCNo,LEN(UCCNo)-1) ELSE UCCNo END AS UCCNo FROM UCC U (NOLOCK)
   CROSS APPLY (
       SELECT UserDefine01, SUM(QtyReceived) 'QtyReceived'
       FROM AUARCHIVE..V_ReceiptDetail RD (NOLOCK)
       WHERE StorerKey = 'ADIDAS'
       AND RD.ReceiptKey = U.ReceiptKey
       AND RD.UserDefine01 = CASE WHEN LEFT(U.UCCNO,1) = 'Y' THEN '0' + RIGHT(U.UCCNO,LEN(U.UCCNO)-1) ELSE U.UCCNO END
       GROUP BY UserDefine01
   ) RD
   WHERE StorerKey = 'ADIDAS'
   AND Status = '1'
   AND Loc NOT LIKE 'WES%'
   AND LEN(UCCNo) >= 20
   AND SourceKey = @c_Transferkey
   AND QtyReceived > 0
   GROUP BY CASE WHEN LEFT(UCCNo,1) = 'Y' THEN '0' + RIGHT(UCCNo,LEN(UCCNo)-1) ELSE UCCNo END, QtyReceived--,RECCOUNT
   HAVING COUNT(1) > 1 AND SUM(Qty) <> QtyReceived
   
   OPEN CUR
   FETCH NEXT FROM CUR INTO @cUCCNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   
       UPDATE UCC SET UserDefined04 = Qty, Qty = RD.QtyReceived, ArchiveCop = NULL, TrafficCop = NULL 
       FROM UCC (NOLOCK)
       JOIN AUARCHIVE..V_ReceiptDetail RD (NOLOCK) ON RD.ReceiptKey = UCC.ReceiptKey AND RD.ReceiptLineNumber = UCC.ReceiptLineNumber
       WHERE UCCNo = @cUCCNo
   
   FETCH NEXT FROM CUR INTO @cUCCNo
   END

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CUR') in (0 , 1)
   BEGIN
      CLOSE CUR
      DEALLOCATE CUR
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCount
         BEGIN
            COMMIT TRAN
         END
      END
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOTRFAD'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCount
      BEGIN
         COMMIT TRAN
      END

      RETURN
   END
END


GO