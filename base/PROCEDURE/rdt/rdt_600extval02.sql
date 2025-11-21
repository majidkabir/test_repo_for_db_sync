SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_600ExtVal02                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check empty pallet                                          */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-11-23 1.0  Ung        SOS357362 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_600ExtVal02] (
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
               DECLARE @cCurrentZone NVARCHAR(10)
               DECLARE @cOtherZone NVARCHAR(10)
               DECLARE @cSKUGroup NVARCHAR(10)

               -- Get SKU info
               SELECT 
                  @cCurrentZone = PutawayZone, 
                  @cSKUGroup = SKUGroup
               FROM SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND SKU = @cSKU
               
               -- Check more then 3 SKU / pallet
               IF EXISTS( SELECT 1 
                  FROM ReceiptDetail WITH (NOLOCK) 
                  WHERE ReceiptKey = @cReceiptKey 
                     AND ToID = @cID 
                     AND BeforeReceivedQTY > 0 
                     AND SKU <> @cSKU
                  HAVING COUNT( DISTINCT SKU) >= 3)
               BEGIN
                  SET @nErrNo = 58451
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID max 3 SKU
                  GOTO Fail
               END
               
               -- Check mix SKU for same brand
               IF EXISTS( SELECT 1 
                  FROM ReceiptDetail RD WITH (NOLOCK) 
                     JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = RD.StorerKey AND SKU.SKU = RD.SKU)
                  WHERE ReceiptKey = @cReceiptKey 
                     AND ToID = @cID 
                     AND BeforeReceivedQTY > 0 
                     AND SKUGroup <> @cSKUGroup)
               BEGIN
                  SET @nErrNo = 58452
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixSKUinBrand
                  GOTO Fail
               END
               
               -- Check mix zone (AIRCOND or AMBIENT) on same ID
               IF @cCurrentZone = 'AIRCOND' OR @cCurrentZone = 'AMBIENT'
               BEGIN
                  IF @cCurrentZone = 'AIRCOND'
                     SET @cOtherZone = 'AMBIENT'
                  ELSE
                     SET @cOtherZone = 'AIRCOND'

                  IF EXISTS( SELECT 1 
                     FROM ReceiptDetail RD WITH (NOLOCK) 
                        JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
                     WHERE ReceiptKey = @cReceiptKey 
                        AND ToID = @cID
                        AND RD.BeforeReceivedQTY > 0
                        AND SKU.PutawayZone = @cOtherZone)
                  BEGIN
                     SET @nErrNo = 58453
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix AC/Ambient
                     GOTO Fail
                  END
               END
            END
         END
      END
      
      IF @nStep = 6 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cID <> '' -- Receive to ID
            BEGIN
               -- Check mix BOND / NON-BOND
               IF @cLottable06 <> '' 
               BEGIN
                  -- Get current L06 is bond / non-bond
                  DECLARE @cCurrentL06 NVARCHAR(10)
                  SET @cCurrentL06 = ''
                  SELECT @cCurrentL06 = ISNULL( Short, '')
                  FROM CodeLKUP WITH (NOLOCK) 
                  WHERE ListName = 'BONDFAC' 
                     AND StorerKey = @cStorerKey
                     AND Code = @cLottable06
                  
                  IF @cCurrentL06 <> '' AND (@cCurrentL06 = 'BONDED' OR @cCurrentL06 = 'UNBONDED')
                  BEGIN
                     DECLARE @cOtherL06 NVARCHAR(10)
                     IF @cCurrentL06 = 'BONDED'
                        SET @cOtherL06  = 'UNBONDED'
                     ELSE
                        SET @cOtherL06  = 'BONDED'
                     
                     -- Check mix L06 (bond / non-bond)
                     IF EXISTS( SELECT 1 
                        FROM ReceiptDetail RD WITH (NOLOCK) 
                        WHERE ReceiptKey = @cReceiptKey 
                           AND ToID = @cID
                           AND Lottable06 <> ''
                           AND EXISTS(
                              SELECT 1
                              FROM CodeLKUP WITH (NOLOCK) 
                              WHERE ListName = 'BONDFAC' 
                                 AND StorerKey = @cStorerKey
                                 AND Code = RD.Lottable06
                                 AND Short = @cOtherL06))
                     BEGIN
                        SET @nErrNo = 58454
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixBond/Unbond
                        GOTO Fail
                     END
                  END
               END

               -- Check mix plant code
               IF @cLottable07 <> '' 
               BEGIN
                  IF EXISTS( SELECT 1 
                     FROM ReceiptDetail RD WITH (NOLOCK) 
                        JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = RD.StorerKey AND SKU.SKU = RD.SKU)
                     WHERE ReceiptKey = @cReceiptKey 
                        AND ToID = @cID 
                        AND BeforeReceivedQTY > 0 
                        AND Lottable07 <> @cLottable07)
                  BEGIN
                     SET @nErrNo = 58455
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix plant code
                     GOTO Fail
                  END
               END

               -- Check mix batch
               IF @cLottable01 <> '' 
               BEGIN
                  IF EXISTS( SELECT 1 
                     FROM ReceiptDetail RD WITH (NOLOCK) 
                        JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = RD.StorerKey AND SKU.SKU = RD.SKU)
                     WHERE ReceiptKey = @cReceiptKey 
                        AND ToID = @cID 
                        AND BeforeReceivedQTY > 0 
                        AND Lottable01 <> @cLottable01)
                  BEGIN
                     SET @nErrNo = 58456
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix batch
                     GOTO Fail
                  END
               END

               -- Check stock status
               IF @cLottable03 <> '' 
               BEGIN
                  IF EXISTS( SELECT 1 
                     FROM ReceiptDetail RD WITH (NOLOCK) 
                        JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = RD.StorerKey AND SKU.SKU = RD.SKU)
                     WHERE ReceiptKey = @cReceiptKey 
                        AND ToID = @cID 
                        AND BeforeReceivedQTY > 0 
                        AND Lottable03 <> @cLottable03)
                  BEGIN
                     SET @nErrNo = 58457
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixStockStatus
                     GOTO Fail
                  END
               END
               

            END
         END
      END
   END

Fail:
Quit:

GO