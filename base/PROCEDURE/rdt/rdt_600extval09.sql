SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_600ExtVal09                                     */  
/* Copyright: LF Logistics                                              */  
/*                                                                      */  
/* Purpose: Check empty pallet                                          */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-01-11 1.0  Chermaine  WMS-15955 Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_600ExtVal09] (  
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
                     SET @nErrNo = 162151  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Non empty PL  
                     GOTO Fail  
                  END  
                 
                  -- Check ID on hold  
                  IF EXISTS( SELECT 1 FROM InventoryHold WITH (NOLOCK) WHERE ID = @cID AND Hold = '1')  
                  BEGIN  
                     SET @nErrNo = 162153  
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
                     SET @nErrNo = 162152  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID in multiLOC  
                     GOTO Fail  
                  END  
               END              END  
         END  
      END  
  
      IF @nStep = 4 -- SKU  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
         	--(cc01) to check decode upc vs pack.casecnt
         	DECLARE @cUPC NVARCHAR(30) 
            DECLARE @cScanQty NVARCHAR(5) 
            DECLARE @cBarcode NVARCHAR(2000) 
            
            SELECT @cBarcode = V_String42 FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE mobile = @nMobile
            
            IF @cBarcode LIKE '02%'
            BEGIN
            	SET @cScanQty = RIGHT(@cBarcode , CHARINDEX ('73' ,REVERSE(@cBarcode))-1)
               SET @cUPC = SUBSTRING(@cBarcode,3,LEN(@cBarcode)-LEN(@cScanQty)-4)
            		
               --if upc, need to compare scan qty vs pack.casecnt
               IF EXISTS (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC = @cUPC AND sku = @cSKU)
               BEGIN
            	   SELECT TOP 1
            		   @nQTY =P.CaseCnt 
            	   FROM UPC U WITH (NOLOCK)
            	   JOIN PACK P WITH (NOLOCK) ON (U.PackKey = P.PackKey)
            	   WHERE U.UPC = @cUPC
            	   AND U.StorerKey = @cStorerKey
            	   AND sku = @cSKU
            		   
            	   IF @cScanQty <> @nQTY
            	   BEGIN
            		   SET @nErrNo = 162160
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
                     GOTO Quit
            	   END
               END
            END
            
               
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
                  SET @nErrNo = 162159  
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
                     SET @nErrNo = 162154  
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
                     SET @nErrNo = 162157  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletMixZone  
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
                        SET @nErrNo = 162155  
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
                  SET @nErrNo = 162156  
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
                        SET @nErrNo = 162158  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID over weight  
                        GOTO Fail  
                     END  
                  END  
               END  
            END  
         END  
      END  
   END  
  
Fail:  
Quit:  


GO