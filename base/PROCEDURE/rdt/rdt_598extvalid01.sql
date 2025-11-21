SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_598ExtValid01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2021-07-08  James     1.0   WMS-17264. Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_598ExtValid01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cRefNo       NVARCHAR( 20),
   @cColumnName  NVARCHAR( 20),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   @nQTY         INT,
   @cReasonCode  NVARCHAR( 10),
   @cSuggToLOC   NVARCHAR( 10),
   @cFinalLOC    NVARCHAR( 10),
   @cReceiptKey  NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cRD_SKUGroup      NVARCHAR( 10)
   DECLARE @cSKUGroup         NVARCHAR( 10)
   DECLARE @nSUM_BeforeReceivedQty  INT
   DECLARE @nSUM_QtyExpected        INT
   
   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @nSUM_BeforeReceivedQty = ISNULL( SUM( RD.BeforeReceivedQty), 0), 
                   @nSUM_QtyExpected = ISNULL( SUM( RD.QtyExpected), 0)
            FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   RD.Sku = @cSKU
            
            -- Check over received. This storer configure flow thru (piece receiving)
            IF ( @nSUM_BeforeReceivedQty + 1) > @nSUM_QtyExpected
            BEGIN
               SET @nErrNo = 170751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Received
               GOTO Quit
            END

            SELECT TOP 1 @cRD_SKUGroup = SKU.SKUGROUP
            FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( RD.StorerKey = SKU.StorerKey AND RD.Sku = SKU.Sku)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   RD.ToId = @cID
            AND   RD.BeforeReceivedQty > 0
            ORDER BY 1

            -- Not yet received anything onto this pallet, no need further check
            IF @@ROWCOUNT = 0
               GOTO Quit
               
            SELECT @cSKUGroup = SKUGROUP
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   Sku = @cSKU
            
            IF @cRD_SKUGroup <> @cSKUGroup
            BEGIN
               SET @nErrNo = 170752
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Mix Dvs
               GOTO Quit
            END
         END
      END
   END

Quit:
END

GO