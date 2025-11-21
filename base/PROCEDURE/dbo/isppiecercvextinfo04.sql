SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispPieceRcvExtInfo04                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Piece Receiving show extended info @ step5              */
/*          Show SKU Received over total SKU per ID                     */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2017-08-16  1.0  James        WMS2584. Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo04]
   @c_ReceiptKey     NVARCHAR(10),
   @c_POKey          NVARCHAR(10),
   @c_ToLOC          NVARCHAR(10),
   @c_ToID           NVARCHAR(18),
   @c_Lottable01     NVARCHAR(18),
   @c_Lottable02     NVARCHAR(18),
   @c_Lottable03     NVARCHAR(18),
   @d_Lottable04     DATETIME,
   @c_StorerKey      NVARCHAR(15),
   @c_SKU            NVARCHAR(20),
   @c_oFieled01      NVARCHAR(20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_TotalQty      INT,
           @n_ReceivedQty   INT,
           @n_Qty           INT,
           @n_Step          INT,
           @c_Qty           NVARCHAR( 5),
           @c_ExtASN        NVARCHAR( 20)

   -- Get user input qty here as not a pass in value
   SELECT @n_Step = Step,
          @c_Qty = I_Field05,
          @c_ExtASN = V_String26
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE UserName = sUser_sName()

   IF @n_Step = 5
   BEGIN
      -- Verify qty here because in piece receiving module
      -- verify qty come after the extended info
      IF rdt.rdtIsValidQty( @c_Qty, 1) = 0
         SET @n_Qty = 0
      ELSE
         SET @n_Qty = CAST( @c_Qty AS INT)
   END
   ELSE
      SET @n_Qty = 0

   SET @n_TotalQty = 0
   SET @n_ReceivedQty = 0
   SELECT @n_ReceivedQty = ISNULL(
          CASE WHEN FinalizeFlag = 'Y' THEN SUM( QtyReceived)
          ELSE SUM( BeforeReceivedQty) END, 0),
          @n_TotalQty = SUM( QtyExpected)
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
   JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
   WHERE R.StorerKey = @c_StorerKey
   AND   R.ReceiptKey = @c_ReceiptKey
   AND   ((@c_POKey = '') OR ( RD.POKey = @c_POKey))
   AND   R.ASNStatus = '0'
   AND   RD.SKU = @c_SKU
   AND   RD.ExternReceiptKey = @c_ExtASN
   GROUP BY FinalizeFlag

   -- Get SKU info
   SELECT @c_oFieled01 = 'S:' +
      CAST( @n_ReceivedQty + @n_Qty AS NVARCHAR( 5)) +
      '/' +
      CAST( @n_TotalQty AS NVARCHAR( 5))					

   SELECT TOP 1 @c_ToID = ToID
   FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
   JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
   WHERE R.StorerKey = @c_StorerKey
   AND   R.ReceiptKey = @c_ReceiptKey
   AND   ((@c_POKey = '') OR ( RD.POKey = @c_POKey))
   AND   R.ASNStatus = '0'
   AND   RD.ToLoc = @c_ToLOC
   AND   RD.SKU = @c_SKU
   AND   RD.ExternReceiptKey = @c_ExtASN
   AND   RD.BeforeReceivedQty < RD.QtyExpected
   ORDER BY RD.ReceiptLineNumber

   SET @c_oFieled01 = @c_oFieled01 + ' '
   SET @n_TotalQty = 0
   SET @n_ReceivedQty = 0
   SELECT @n_ReceivedQty = ISNULL(
          CASE WHEN FinalizeFlag = 'Y' THEN SUM( QtyReceived)
          ELSE SUM( BeforeReceivedQty) END, 0),
          @n_TotalQty = SUM( QtyExpected)
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
   JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
   WHERE R.StorerKey = @c_StorerKey
   AND   R.ReceiptKey = @c_ReceiptKey
   AND   ((@c_POKey = '') OR ( RD.POKey = @c_POKey))
   AND   R.ASNStatus = '0'
   AND   RD.SKU = @c_SKU
   AND   RD.ExternReceiptKey = @c_ExtASN
   AND   RD.ToID = @c_ToID
   GROUP BY FinalizeFlag

   -- Get ASN info
   SELECT @c_oFieled01 = @c_oFieled01 + 'I:' +
      CAST( @n_ReceivedQty + @n_Qty AS NVARCHAR( 5)) +
      '/' +
      CAST( @n_TotalQty AS NVARCHAR( 5))					

QUIT:
END -- End Procedure

GO