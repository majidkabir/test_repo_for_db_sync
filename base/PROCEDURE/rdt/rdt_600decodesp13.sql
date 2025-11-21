SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600DecodeSP13                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 07-06-2022  yeekung   1.0   WMS-18007 Created                              */
/* 05-05-2023  YeeKung   1.1   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP13] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 2000)  OUTPUT,
   @cFieldName   NVARCHAR( 10),
   @cID          NVARCHAR( 18)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nQTY         INT            OUTPUT,
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @dLottable04  DATETIME       OUTPUT,
   @dLottable05  DATETIME       OUTPUT,
   @cLottable06  NVARCHAR( 30)  OUTPUT,
   @cLottable07  NVARCHAR( 30)  OUTPUT,
   @cLottable08  NVARCHAR( 30)  OUTPUT,
   @cLottable09  NVARCHAR( 30)  OUTPUT,
   @cLottable10  NVARCHAR( 30)  OUTPUT,
   @cLottable11  NVARCHAR( 30)  OUTPUT,
   @cLottable12  NVARCHAR( 30)  OUTPUT,
   @dLottable13  DATETIME       OUTPUT,
   @dLottable14  DATETIME       OUTPUT,
   @dLottable15  DATETIME       OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cPalleSSCC  NVARCHAR(20)
   DECLARE @cCaseSSCC   NVARCHAR(20)
   DECLARE @cErrMsg1    NVARCHAR( 125)
   DECLARE @cErrMsg2    NVARCHAR( 125)
   
   SET @cErrMsg1 = '' 
   SET @cErrMsg2 = ''
   	
   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               --1.SKU
               IF EXISTS (SELECT 1
                           FROM SKU S WITH (NOLOCK) 
                           JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = S.StorerKey AND RD.SKU = S.SKU) 
                           WHERE RD.StorerKey = @cStorerKey 
                           AND (S.sku = @cBarcode
                           OR S.Altsku = @cBarcode 
                           OR S.MANUFACTURERSKU = @cBarcode 
                           OR S.RetailSku = @cBarcode)
                           AND RD.ReceiptKey = @cReceiptKey)
               BEGIN
               	SELECT 
               	   @cSku = S.SKU
               	FROM SKU S WITH (NOLOCK) 
                  JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = S.StorerKey AND RD.SKU = S.SKU) 
                  WHERE RD.StorerKey = @cStorerKey 
                  AND (S.sku = @cBarcode
                  OR S.Altsku = @cBarcode 
                  OR S.MANUFACTURERSKU = @cBarcode 
                  OR S.RetailSku = @cBarcode)
                  AND RD.ReceiptKey = @cReceiptKey
               	
               	IF NOT EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND sku = @cSku AND LOTTABLE09LABEL <> 'SSCC')
               	BEGIN
               		SET @nErrNo = 176601  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ScanPlTSSCC 
                     GOTO Quit
               	END
               END
               Else
               BEGIN
               	----2.Pallet SSCC (00)030244808343339608(93) 
                  IF left( @cBarcode,2) = '00' 
                  BEGIN
               	   --IF SUBSTRING( @cBarcode, 21, 2) = '93'
               	   IF LEN(@cBarcode)-2 = 18
               	   BEGIN
               		   SET @cPalleSSCC = SUBSTRING( @cBarcode,  3, 18)
               		   
               		   IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND LOTTABLE09LABEL <> 'SSCC')
               		   BEGIN
               		      SET @nErrNo = 176603  
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PltSSCCNotReq 
                           GOTO Quit
               		   END
               		
               		   IF NOT EXISTS (SELECT 1 
               		                  FROM receiptDetail RD WITH (NOLOCK)
               		                  JOIN UCC U WITH (NOLOCK) ON (RD.StorerKey = U.Storerkey AND RD.ExternReceiptKey = U.ExternKey AND RD.Lottable09 = U.Userdefined03)
               		                  WHERE RD.StorerKey = @cStorerKey
               		                  AND RD.ReceiptKey = @cReceiptKey
               		                  AND RD.Lottable09 = @cPalleSSCC 
               		                  AND RD.FinalizeFlag <> 'Y')
                        BEGIN
                     	   SET @nErrNo = 176602  
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletSSCCErr 
                           GOTO Quit
                        END    
                        ELSE
                        BEGIN
                     	   SELECT TOP 1
                     	      @cSKU = RD.SKU,
                     	      @cLottable09 = @cPalleSSCC,
                              @nQTY = QtyReceived
               		      FROM receiptDetail RD WITH (NOLOCK)
               		      JOIN UCC U WITH (NOLOCK) ON (RD.StorerKey = U.Storerkey AND RD.ExternReceiptKey = U.ExternKey AND RD.Lottable09 = U.Userdefined03)
               		      WHERE RD.StorerKey = @cStorerKey
               		      AND RD.ReceiptKey = @cReceiptKey
               		      AND RD.Lottable09 = @cPalleSSCC
                           AND RD.FinalizeFlag <> 'Y'
                           ORDER BY RD.ReceiptLineNumber
               		      
               		      IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND LOTTABLE09LABEL <> 'SSCC')
               		      BEGIN
               		         SET @nErrNo = 176603  
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PltSSCCNotReq 
                              GOTO Quit
               		      END
                        END       
               	   END
               	   ELSE
               	   BEGIN
               		   SET @nErrNo = 176604  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletSSCCErr 
                        --SET @nErrNo = 176605 
                        --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ScanCaseSSCC 
                        GOTO Quit
               	   END
                  END 
                  ELSE
                  --3.caseSSCC (95)030244893132694952             	
                  BEGIN
                  	IF left( @cBarcode,2) = '95'
                  	BEGIN
                  		IF LEN(RIGHT(@cBarcode,LEN(@cBarcode)-(PATINDEX ('95%',@cBarcode)+1))) <> 18
                  	   BEGIN
                  		   SET @nErrNo = 176606 
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CaseSSCCErr
                           GOTO Quit
                  	   END
                  	
                  	   SET @cCaseSSCC = SUBSTRING( @cBarcode,  3, 18)
                     
                        IF NOT EXISTS (SELECT 1 
               		                  FROM UCC WITH (NOLOCK)
               		                  WHERE UccNo = @cCaseSSCC
               		                  AND storerKey = @cStorerKey
               		                  AND STATUS = '0' )
                        BEGIN
                     	   SET @nErrNo = 176607  
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CaseSSCCErr 
                           GOTO Quit
                        END   
                        ELSE
                        BEGIN
                     	   SELECT TOP 1
                     	      @cSKU = SKU,
                              @nQTY = qty
               		      FROM UCC
               		      WHERE UccNo = @cCaseSSCC
               		      AND storerKey = @cStorerKey
               		      AND STATUS = '0' 
                        END  
                  	END 
                  	ELSE
                  	BEGIN
                  		SET @nErrNo = 176608  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletSSCCErr 
                        GOTO Quit
                  	END
                  	              	   
                  END
               END
               
               --IF @cErrMsg1 <> '' OR @cErrMsg2 <> ''
               --BEGIN
         	     -- SET @nErrNo = 0
         	     -- SET @cSKU = ''
         	     -- SET @cLottable09 = ''
         	     -- EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
         	     -- GOTO Quit
               --END
             
            END
         END
      END
   END

Quit:

END

GO