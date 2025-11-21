SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1584ExtVal01                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check QTY expected exact match with actual QTY              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-03-03 1.0  Ung        WMS-21709 base onrdt_600ExtVal01          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1584ExtVal01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cRefNo       NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cPalletSSCC  NVARCHAR( 30), 
   @cCaseSSCC    NVARCHAR( 30), 
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
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1584 -- SSCC receiving1
   BEGIN
      IF @nStep = 3 -- ToID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Receive to ID
            IF @cID <> ''
            BEGIN
               -- New ID
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
                     SET @nErrNo = 197501
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Non empty PL
                     GOTO Fail
                  END
               
                  -- Check ID on hold
                  IF EXISTS( SELECT 1 FROM InventoryHold WITH (NOLOCK) WHERE ID = @cID AND Hold = '1')
                  BEGIN
                     SET @nErrNo = 197502
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID on hold
                     GOTO Fail
                  END
               END
               ELSE
               BEGIN
                  -- Check ID in multi LOC
                  IF EXISTS( SELECT 1 
                     FROM ReceiptDetail WITH (NOLOCK) 
                     WHERE ReceiptKey = @cReceiptKey 
                        AND ToID = @cID 
                        AND ToLOC <> @cLOC 
                        AND BeforeReceivedQTY > 0)
                  BEGIN
                     SET @nErrNo = 197503
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID in multiLOC
                     GOTO Fail
                  END
               END
            END
         END
      END

      IF @nStep = 5 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cID <> ''
            BEGIN
               DECLARE @cCurrentZone NVARCHAR(10)
               DECLARE @cOtherZone NVARCHAR(10)
               DECLARE @cSKUStatus NVARCHAR(10)

               -- Get SKU info
               SELECT 
                  @cCurrentZone = PutawayZone, 
                  @cSKUStatus = SKUStatus
               FROM SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND SKU = @cSKU
               
               -- Check SKU status
               IF @cSKUStatus = 'SUSPENDED'
               BEGIN
                  SET @nErrNo = 197504
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU suspended
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
                     SET @nErrNo = 197505
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix AC/Ambient
                     GOTO Fail
                  END
               END
               
               -- Check mix zone on same pallet
               DECLARE @cMixZonePallet NVARCHAR(1)
               SET @cMixZonePallet = rdt.RDTGetConfig( @nFunc, 'MixZonePallet', @cStorerKey)
               IF @cMixZonePallet <> '1'
               BEGIN
                  IF EXISTS( SELECT 1 
                     FROM ReceiptDetail RD WITH (NOLOCK)
                        JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
                     WHERE RD.ReceiptKey = @cReceiptKey
                        AND RD.ToID = @cID
                        AND RD.BeforeReceivedQTY > 0
                        AND SKU.PutawayZone <> @cCurrentZone)
                  BEGIN
                     SET @nErrNo = 197506
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletMixZone
                     GOTO Fail
                  END
               END
            END
         END
      END
      
      IF @nStep = 7 -- QTY
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
                        SET @nErrNo = 197507
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
                  SET @nErrNo = 197508
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix Cond Code
                  GOTO Fail
               END
               
               
               /************************************ Check weight ********************************/
               DECLARE @cMaxWeight   NVARCHAR(10)
               DECLARE @nMaxWeight   DECIMAL( 10, 3) -- Note: float is approximate value, 
               DECLARE @nSTDGrossWGT DECIMAL( 10, 3) -- cannot use for compare later
               DECLARE @nIDWeight    DECIMAL( 10, 3)

               -- Get SKU weight
               SELECT @nSTDGrossWGT = STDGROSSWGT FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
               
               -- SKU weight is setup
               IF @nSTDGrossWGT > 0
               BEGIN
                  -- Get pallet max weight
                  SELECT TOP 1 @cMaxWeight = UDF01 
                  FROM CodeLKUP WITH (NOLOCK) 
                  WHERE ListName = 'PALLETSPEC' 
                     AND PATINDEX( Code + '%', @cID) > 0
                  
                  -- Max weight is setup
                  IF rdt.rdtIsValidQTY( @cMaxWeight, 21) <> 0
                  BEGIN
                     SET @nMaxWeight = CAST( @cMaxWeight AS FLOAT)
                  
                     -- Get existing pallet weight
                     SELECT @nIDWeight = ISNULL( SUM( BeforeReceivedQTY * SKU.STDGROSSWGT), 0)
                     FROM ReceiptDetail RD WITH (NOLOCK) 
                        JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
                     WHERE ReceiptKey = @cReceiptKey 
                        AND ToID = @cID
                     
                     -- Check over max weight
                     IF @nIDWeight + (@nSTDGrossWGT * @nQTY) > @nMaxWeight
                     BEGIN
                        SET @nErrNo = 197509
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID over weight
                        GOTO Fail
                     END
                  END
               END
            
               DECLARE @nQTYExp INT = 0
               
               -- Pallet SSCC
               IF @cPalletSSCC <> ''
               BEGIN
            	   -- Pallet with SSCC SKU
            	   SELECT TOP 1
            	      @nQTYExp = RD.QTYExpected - RD.BeforeReceivedQTY
         	      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         	         JOIN dbo.UCC WITH (NOLOCK) ON (RD.StorerKey = UCC.Storerkey AND RD.SKU = UCC.SKU AND RD.ExternReceiptKey = UCC.ExternKey AND RD.Lottable09 = UCC.UserDefined03)
         	      WHERE RD.ReceiptKey = @cReceiptKey
         		      AND RD.Lottable09 = @cPalletSSCC
            	      AND RD.SKU = @cSKU
                     AND RD.FinalizeFlag <> 'Y'
                     AND RD.QTYExpected > RD.BeforeReceivedQTY -- line with balance
                  ORDER BY RD.ReceiptLineNumber

         	      IF @@ROWCOUNT = 0
               	   -- Pallet with non SSCC SKU
               	   SELECT TOP 1
               	      @nQTYExp = QTYExpected - BeforeReceivedQTY
         		      FROM dbo.ReceiptDetail WITH (NOLOCK)
         		      WHERE ReceiptKey = @cReceiptKey
            		      AND Lottable09 = @cPalletSSCC
            	         AND SKU = @cSKU
                        AND FinalizeFlag <> 'Y'
                        AND QTYExpected > BeforeReceivedQTY -- line with balance
                     ORDER BY ReceiptLineNumber

                  -- Check QTY match
                  IF @nQTY > @nQTYExp
                  BEGIN
                     SET @nErrNo = 197510
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY over
                     GOTO Fail
                  END
               END
               
               -- Case SSCC
               IF @cCaseSSCC <> ''
               BEGIN
                  -- Get case info
                  SELECT @nQTYExp = QTY
                  FROM dbo.UCC WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND UCCNo = @cCaseSSCC
                     
                  -- Check QTY match
                  IF @nQTY > @nQTYExp
                  BEGIN
                     SET @nErrNo = 197511
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY over
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