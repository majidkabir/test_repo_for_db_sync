SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600DecodeSP10                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 05-10-2021  Chermaine 1.0   WMS-18007 Created                              */
/* 30-05-2022  Ung       1.1   WMS-19757 Scan case SSCC, auto retrieve QTY    */
/*                             and its pallet SSCC at Lottable09              */
/* 02-06-2022  Ung       1.2   WMS-19808 Map case SSCC to ReceiptDetail       */
/* 29-08-2022  Ung       1.3   WMS-20644 Add SSCC pallet with multi lines     */
/* 14-09-2022  Ung       1.4   WMS-20760 Add pallet with non SSCC SKU         */
/* 05-05-2023  YeeKung   1.5   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP10] (
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
               	SELECT TOP 1 
               	   @cSku = S.SKU, 
            	      @cLottable01 = RD.Lottable01, 
            	      @cLottable02 = RD.Lottable02, 
            	      @cLottable03 = RD.Lottable03, 
                     @cLottable09 = RD.Lottable09
               	FROM SKU S WITH (NOLOCK)
                     JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = S.StorerKey AND RD.SKU = S.SKU)
                  WHERE RD.ReceiptKey = @cReceiptKey
                     AND RD.StorerKey = @cStorerKey
                     AND @cBarcode IN (S.SKU, S.AltSKU, S.MANUFACTURERSKU, S.RetailSKU)
                     AND RD.FinalizeFlag <> 'Y'
                     AND RD.QTYExpected > RD.BeforeReceivedQTY -- line with balance
                  ORDER BY RD.ReceiptLineNumber

               	IF NOT EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND sku = @cSku AND LOTTABLE09LABEL <> 'SSCC')
               	BEGIN
               		SET @nErrNo = 176601
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ScanPlTSSCC
                     GOTO Quit
               	END
               END
               ELSE
               BEGIN
               	----2.Pallet SSCC (00)030244808343339608(93)
                  IF left( @cBarcode,2) = '00'
                  BEGIN
               	   IF SUBSTRING( @cBarcode, 21, 2) = '93'
               	   BEGIN
               		   SET @cPalleSSCC = SUBSTRING( @cBarcode,  3, 18)

               		   -- Check pallet valid
               		   IF NOT EXISTS( SELECT 1
   		                  FROM receiptDetail RD WITH (NOLOCK)
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
                     	   -- Pallet with SSCC SKU
                     	   SELECT TOP 1
                     	      @cSKU = RD.SKU,
                     	      @cLottable01 = RD.Lottable01, 
                     	      @cLottable02 = RD.Lottable02, 
                     	      @cLottable03 = RD.Lottable03, 
                     	      @cLottable09 = RD.Lottable09
               		      FROM receiptDetail RD WITH (NOLOCK)
               		         JOIN UCC WITH (NOLOCK) ON (RD.StorerKey = UCC.Storerkey AND RD.SKU = UCC.SKU AND RD.ExternReceiptKey = UCC.ExternKey AND RD.Lottable09 = UCC.Userdefined03)
               		      WHERE RD.StorerKey = @cStorerKey
                  		      AND RD.ReceiptKey = @cReceiptKey
                  		      AND RD.Lottable09 = @cPalleSSCC
                              AND RD.FinalizeFlag <> 'Y'
                              AND RD.QTYExpected > RD.BeforeReceivedQTY -- line with balance
                           ORDER BY RD.ReceiptLineNumber

               		      IF @@ROWCOUNT = 0
                        	   -- Pallet with non SSCC SKU
                        	   SELECT TOP 1
                        	      @cSKU = RD.SKU,
                        	      @cLottable01 = RD.Lottable01, 
                        	      @cLottable02 = RD.Lottable02, 
                        	      @cLottable03 = RD.Lottable03, 
                        	      @cLottable09 = RD.Lottable09
                  		      FROM receiptDetail RD WITH (NOLOCK)
                  		      WHERE RD.StorerKey = @cStorerKey
                     		      AND RD.ReceiptKey = @cReceiptKey
                     		      AND RD.Lottable09 = @cPalleSSCC
                                 AND RD.FinalizeFlag <> 'Y'
                                 AND RD.QTYExpected > RD.BeforeReceivedQTY -- line with balance
                              ORDER BY RD.ReceiptLineNumber

                           /*
                  		      IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND LOTTABLE09LABEL <> 'SSCC')
                  		      BEGIN
                  		         SET @nErrNo = 176603
                                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PltSSCCNotReq
                                 GOTO Quit
                  		      END
                           */
                        END
               	   END
               	   ELSE
               	   BEGIN
               		   SET @nErrNo = 176604
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletSSCCErr
                        GOTO Quit
               	   END
                  END
                  
                  --3.caseSSCC (95)030244893132694952
                  ELSE
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

                        /*
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
                        */
                        BEGIN
                     	   SELECT TOP 1
                     	      @cSKU = SKU,
                     	      @nQTY = QTY
               		      FROM UCC WITH (NOLOCK)
               		      WHERE UccNo = @cCaseSSCC
               		      AND storerKey = @cStorerKey
               		      AND STATUS = '0'

                     	   -- Get pallet SSCC
                     	   IF @@ROWCOUNT = 1
                        	   SELECT TOP 1
                        	      @cLottable01 = RD.Lottable01, 
                        	      @cLottable02 = RD.Lottable02, 
                        	      @cLottable03 = RD.Lottable03, 
                        	      @cLottable09 = RD.Lottable09
                        	   FROM UCC WITH (NOLOCK)
                        	      JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.StorerKey = UCC.Storerkey  
                        	         AND RD.SKU = UCC.SKU  
                        	         AND UCC.UserDefined01 = RD.Lottable02  
                        	         AND UCC.userDefined03 = RD.Lottable09)
                              WHERE UCC.UCCNo = @cCaseSSCC
                                 AND RD.ReceiptKey = @cReceiptKey
                                 AND ISNULL( RD.DuplicateFrom, '') = '' -- Original line
                        END
                  	END
                  	ELSE
                  	BEGIN
                  		SET @nErrNo = 176608
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid data
                        GOTO Quit
                  	END
                  END
               END
            END
         END
      END
   END

Quit:

END

GO