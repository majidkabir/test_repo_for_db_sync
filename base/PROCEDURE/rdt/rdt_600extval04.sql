SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_600ExtVal04                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check serial no only allow key-in 1 QTY                     */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 01-03-2017 1.0  Ung        WMS-1241 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_600ExtVal04] (
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
      IF @nStep = 6 -- Qty
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cLottable02Label NVARCHAR( 20)

            -- Get SKU info
            SELECT @cLottable02Label = Lottable02Label
            FROM SKU WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
               AND SKU = @cSKU

            -- Check 1 serial no SKU, 1 QTY
            IF @cLottable02Label <> '' AND @nQTY <> 1
            BEGIN
               SET @nErrNo = 106451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NOT ALLOW > 1
               GOTO Fail
            END
         END
      END
   END

Fail:
Quit:


GO