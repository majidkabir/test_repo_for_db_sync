SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: ispPieceRcvExtInfo11                                   */
/* Copyright      : LFLogistics                                            */
/*                                                                         */
/* Purpose: Display Count                                                  */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-03-09 1.0  Ung        WMS-19006 Created                            */
/***************************************************************************/

CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo11] (
  @cReceiptKey   NVARCHAR( 10),
  @cPOKey        NVARCHAR( 10),
  @cLOC          NVARCHAR( 10),
  @cToID         NVARCHAR( 18),
  @cLottable01   NVARCHAR( 18),
  @cLottable02   NVARCHAR( 18),
  @cLottable03   NVARCHAR( 18),
  @dLottable04   DATETIME,
  @cStorer       NVARCHAR( 15),
  @cSKU          NVARCHAR( 20),
  @cExtendedInfo NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLangCode  NVARCHAR( 3)
   DECLARE @nFunc      INT
   DECLARE @nStep      INT
   DECLARE @nInputKey  INT
   DECLARE @nCartonQTY INT

   SELECT TOP 1 
      @cLangCode = Lang_Code, 
      @nFunc = Func, 
      @nStep = Step, 
      @nInputKey = InputKey
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE UserName = SUSER_SNAME()

   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      IF @nStep = 5 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @nCartonQTY = ISNULL( SUM( BeforeReceivedQty), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE Receiptkey = @cReceiptKey
               AND ToLOC = @cLOC
               AND ToID = @cToID
               AND Storerkey  = @cStorer
               AND SKU = @cSKU
               AND Lottable01 = @cLottable01

            DECLARE @cMsg NVARCHAR( 20)
            SET @cMsg = rdt.rdtgetmessage( 184001, @cLangCode, 'DSP') --CARTON QTY:
            
            SET @cExtendedInfo = RTRIM( @cMsg) + ' ' + CAST( @nCartonQTY AS NVARCHAR(5))
         END
      END
   END

END

GO