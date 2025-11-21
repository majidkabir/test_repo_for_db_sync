SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_550ExtVal02                                     */
/* Purpose: Update DropID                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* To check if over receive by ASN + pallet id + SKU.                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-04-07 1.0  James      SOS305458.                                */
/* 2014-11-26 1.1  Ung        SOS326375 Modify parameters               */
/*                            rename from rdt_MHDCheckPltID_02          */
/************************************************************************/

CREATE PROC [RDT].[rdt_550ExtVal02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @cLottable01  NVARCHAR(18),
   @cLottable02  NVARCHAR(18),
   @cLottable03  NVARCHAR(18),
   @dLottable04  DATETIME,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQty_Received     INT,
           @nQty_Expected     INT

   IF @nFunc = 550 -- Normal receiving
   BEGIN
      IF @nStep = 5 -- U0M, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- If no pallet ID just ignore
            IF ISNULL( @cID, '') = ''
               GOTO Quit

            SELECT @nQty_Received = ISNULL( SUM( BeforeReceivedQty), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   ToID = @cID
            AND   SKU = @cSKU
            AND   StorerKey = @cStorerKey
            AND   FinalizeFlag = 'N'

            SELECT @nQty_Expected = ISNULL( SUM( QtyExpected), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   ToID = @cID
            AND   SKU = @cSKU
            AND   StorerKey = @cStorerKey
            AND   FinalizeFlag = 'N'

            IF @nQty_Received + @nQty > @nQty_Expected
            BEGIN
               SET @nErrNo = 92201
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OVER RECEIVED
               EXEC rdt.rdtSetFocusField @nMobile, 6
               GOTO Quit
            END
         END
      END
   END
Quit:


GO