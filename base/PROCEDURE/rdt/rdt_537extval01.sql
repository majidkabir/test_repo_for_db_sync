SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_537ExtVal01                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check empty pallet. Build pallet rules                      */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-03-11 1.0  Ung        SOS315431 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_537ExtVal01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cFacility    NVARCHAR( 5), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @cReasonCode  NVARCHAR( 10), 
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
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 537 -- Line receiving
   BEGIN
      IF @nStep = 3 -- ToID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Receive to ID
            IF @cID <> ''
            BEGIN
               -- ID not in current ASN
               IF NOT EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ToID = @cID)   
               BEGIN
                  -- Check empty pallet (in ASRS)
                  IF EXISTS( SELECT 1 
                     FROM LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
                     WHERE LOC.Facility = @cFacility
                        AND ID = @cID 
                        AND QTY > 0)
                  BEGIN
                     SET @nErrNo = 52501
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Non empty PL
                     GOTO Fail
                  END
               
                  /*
                  -- Check empty pallet (at stage)
                  IF EXISTS( SELECT 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cID AND Status <> '9')
                  BEGIN
                     SET @nErrNo = 52502
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Non empty PL
                     GOTO Fail
                  END
                  */
               
                  -- Check ID on hold
                  IF EXISTS( SELECT 1 FROM InventoryHold WITH (NOLOCK) WHERE ID = @cID AND Hold = '1')
                  BEGIN
                     SET @nErrNo = 52503
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID on hold
                     GOTO Fail
                  END
               END
            END
         END
      END

      IF @nStep = 4 -- LineNo
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cID <> ''
            BEGIN
               DECLARE @cCurrentZone NVARCHAR(10)
               DECLARE @cOtherZone NVARCHAR(10)

               -- Get SKU info
               SELECT @cCurrentZone = PutawayZone FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
               
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
                        AND SKU.PutawayZone = @cOtherZone)
                  BEGIN
                     SET @nErrNo = 52504
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
                        SET @nErrNo = 52505
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MixBond/Unbond
                        GOTO Fail
                     END
                  END
               END

               -- Check mix condition code
               DECLARE @nMix INT
               SET @nMix = 0
               IF @cReasonCode = '' OR @cReasonCode = 'OK'
               BEGIN
                  IF EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ToID = @cID AND ConditionCode <> 'OK')
                     SET @nMix = 1
               END
               ELSE
               BEGIN
                  IF EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ToID = @cID AND ConditionCode = 'OK')
                     SET @nMix = 1
               END

               IF @nMix = 1
               BEGIN
                  SET @nErrNo = 52506
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix Cond Code
                  GOTO Fail
               END
            END
         END
      END
   END

Fail:
Quit:


GO