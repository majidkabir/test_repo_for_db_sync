SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispASNSRQtyChk01                                   */
/* Creation Date: 17-Jul-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-23094 - CN Anta ASN Serial no qty tally check by receipt*/
/*          type.                                                       */
/*                                                                      */
/* Called By: ntrReceiptDetailUpdate                                    */
/*            Storerconfig: BYPASSRECEIPTSERIALQTYTALLYCHK              */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 17-Jul-2023  NJOW     1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE   PROCEDURE [dbo].[ispASNSRQtyChk01]
   @cDocNo          NVARCHAR( 10),  --receiptkey   
   @cDocLineNo      NVARCHAR( 5),   --receiptlinenumber
   @cDocType        NVARCHAR( 1),   
   @cSKU            NVARCHAR( 20),
   @nQty            INT,          
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue       INT
         , @n_StartTCnt      INT
         , @n_TotalSerialNo  INT = 0
         , @c_Option5        NVARCHAR(2000) = ''
         , @c_ExcludeRecType NVARCHAR(2000) = ''
         , @c_Storerkey      NVARCHAR(15)
         , @c_Facility       NVARCHAR(5)

   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @nErrNo = 0, @cErrMsg = ''

   SELECT @c_Storerkey = Storerkey,
          @c_Facility = Facility
   FROM RECEIPT (NOLOCK)
   WHERE Receiptkey = @cDocNo

   SELECT @c_Option5 = SC.Option5
   FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey,'','BYPASSRECEIPTSERIALQTYTALLYCHK') AS SC
   
   SELECT @c_ExcludeRecType = dbo.fnc_GetParamValueFromString('@c_ExcludeRecType', @c_Option5, @c_ExcludeRecType)
   
   IF EXISTS(SELECT 1 
             FROM RECEIPT (NOLOCK)
             WHERE Receiptkey = @cDocNo
             AND RecType IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ExcludeRecType))
            )
   BEGIN
      GOTO QUIT_SP
   END
   
   SELECT @n_TotalSerialNo = ISNULL(SUM(Qty), 0)      
   FROM RECEIPTSERIALNO (NOLOCK)
   WHERE ReceiptKey = @cDocNo      
   AND ReceiptLineNumber = @cDocLineNo
   
   IF @n_TotalSerialNo <> @nQty
   BEGIN      	
      SELECT @n_Continue = 3
      SELECT @nErrNo = 38000
      SELECT @cErrMsg = CONVERT(CHAR(5), @nErrNo) + ': ReceiptSerialNo Qty is not tally (line=' + RTRIM(ISNULL(@cDocLineNo,'')) + ') (ispASNSRQtyChk01)'   	
   END

   QUIT_SP:

   IF @n_Continue = 3 -- Error Occured - Process AND Return
   BEGIN
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
      EXECUTE dbo.nsp_logerror @nErrNo, @cErrMsg, 'ispASNSRQtyChk01'
      RAISERROR (@cErrmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO