SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_600ExtVal03                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check if sku received already has inventory. prompt error   */
/*          if inventory exists. Check LotxLocxID and current ASN only  */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-09-05 1.0  James      WMS256 Created                            */
/************************************************************************/

CREATE PROC [RDT].[rdt_600ExtVal03] (
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

   DECLARE @cItemclass     NVARCHAR( 10)

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 6 -- Qty
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get SKU info
            SELECT @cItemclass = Itemclass
            FROM SKU WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            AND   SKU = @cSKU

            -- If itemclass <> 'Y' then no checking
            IF ISNULL( @cItemclass, '') <> 'Y'
            BEGIN
               SET @nErrNo = 0
               GOTO Quit
            END

            IF ISNULL( @nQTY, 0) > 1
            BEGIN
               SET @nErrNo = 103651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NOT ALLOW > 1
               GOTO Fail
            END

            -- Check if stock exists in inventory
            IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                        JOIN LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
                        WHERE LLI.StorerKey = @cStorerKey
                        AND   LLI.SKU = @cSKU
                        AND   (Qty - QtyAllocated - QtyPicked) > 0
                        AND    Facility = @cFacility)
            BEGIN
               SET @nErrNo = 103652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- STOCK EXISTS
               GOTO Fail
            END
            
            -- Check current ASN if stock received before
            IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                        WHERE ReceiptKey = @cReceiptKey
                        AND   StorerKey = @cStorerKey 
                        AND   SKU = @cSKU
                        AND   ( QtyReceived + BeforeReceivedQty) > 0)
            BEGIN
               SET @nErrNo = 103653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- STOCK RECEIVED
               GOTO Fail
            END                        
         END   -- ENTER
      END      -- Qty
   END         -- Normal receiving

   Fail:
   Quit:


GO