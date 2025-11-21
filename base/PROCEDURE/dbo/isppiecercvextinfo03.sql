SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispPieceRcvExtInfo03                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Piece Receiving show extended info @ step5              */
/*          Show SKU Received over total SKU per ASN                    */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-04-2016  1.0  James       SOS367156. Created                      */
/* 04-07-2016  1.1  SPChin      IN00080638 - Bug Fixed                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo03]
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

   DECLARE @nTotalQty      INT,
           @nReceivedQty   INT,
           @nQty           INT,
           @nStep          INT,
           @cQty           NVARCHAR( 5)

   -- Get user input qty here as not a pass in value
   SELECT @nStep = Step,
          @cQty = I_Field05
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE UserName = sUser_sName()

   IF @nStep = 5
   BEGIN
      -- Verify qty here because in piece receiving module
      -- verify qty come after the extended info
      IF rdt.rdtIsValidQty( @cQty, 1) = 0
         SET @nQty = 0
      ELSE
         SET @nQty = CAST( @cQty AS INT)
   END
   ELSE
      SET @nQty = 0

   SET @nTotalQty = 0
   SET @nReceivedQty = 0
   SELECT @nReceivedQty = ISNULL(
          CASE WHEN FinalizeFlag = 'Y' THEN SUM( QtyReceived)
          ELSE SUM( BeforeReceivedQty) END, 0),
          @nTotalQty = SUM( QtyExpected)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey
   AND   ReceiptKey = @c_ReceiptKey
   AND   SKU = @c_SKU
   GROUP BY FinalizeFlag

   -- Get SKU info
   SELECT @c_oFieled01 = 'S:' +
      CAST( @nReceivedQty + @nQty AS NVARCHAR( 5)) +	--IN00080638
      '/' +
      CAST( @nTotalQty AS NVARCHAR( 5))					--IN00080638

   SET @c_oFieled01 = @c_oFieled01 + ' '
   SET @nTotalQty = 0
   SET @nReceivedQty = 0
   SELECT @nReceivedQty = ISNULL(
          CASE WHEN FinalizeFlag = 'Y' THEN SUM( QtyReceived)
          ELSE SUM( BeforeReceivedQty) END, 0),
          @nTotalQty = SUM( QtyExpected)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey
   AND   ReceiptKey = @c_ReceiptKey
   GROUP BY FinalizeFlag

   -- Get ASN info
   SELECT @c_oFieled01 = @c_oFieled01 + 'A:' +
      CAST( @nReceivedQty + @nQty AS NVARCHAR( 5)) +	--IN00080638
      '/' +
      CAST( @nTotalQty AS NVARCHAR( 5))					--IN00080638

QUIT:
END -- End Procedure

GO