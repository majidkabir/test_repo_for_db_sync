SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_600ExtVal13                                     */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: Check pallet same SKUGroup and max 4 SKU                    */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-04-13 1.0  Ung        WMS-22201 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_600ExtVal13] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
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
   @cReceiptLineNumber NVARCHAR( 10), 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cID <> ''
            BEGIN
               -- Get SKU info
               DECLARE @cSKUGroup NVARCHAR(10)
               SELECT @cSKUGroup = SKUGroup
               FROM SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND SKU = @cSKU

               -- Check mix SKUGroup on pallet
               IF EXISTS( SELECT 1 
                  FROM ReceiptDetail RD WITH (NOLOCK) 
                     JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = RD.StorerKey AND SKU.SKU = RD.SKU)
                  WHERE ReceiptKey = @cReceiptKey 
                     AND ToID = @cID 
                     AND BeforeReceivedQTY > 0 
                     AND SKUGroup <> @cSKUGroup)
               BEGIN
                  SET @nErrNo = 199551
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff SKUGroup
                  GOTO Fail
               END

               -- Check more then 4 SKU in pallet
               IF EXISTS( SELECT 1 
                  FROM ReceiptDetail WITH (NOLOCK) 
                  WHERE ReceiptKey = @cReceiptKey 
                     AND ToID = @cID 
                     AND BeforeReceivedQTY > 0 
                     AND SKU <> @cSKU
                  HAVING COUNT( DISTINCT SKU) >= 4)
               BEGIN
                  SET @nErrNo = 199552
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID max 4 SKU
                  GOTO Fail
               END
            END
         END
      END
   END

Fail:
Quit:

GO