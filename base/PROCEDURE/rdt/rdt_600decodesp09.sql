SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_600DecodeSP09                                         */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Purpose: Extended putaway                                                  */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 19-04-2021  Chermaine 1.0   WMS-16598 Created                              */  
/* 05-05-2023  YeeKung   1.1   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP09] (
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
  
   IF @nFunc = 600 -- Normal receiving  
   BEGIN  
      IF @nStep = 4 -- SKU  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
         	DECLARE @nMaxLen  INT
         	DECLARE @nDecodeLen1 INT
         	DECLARE @nDecodeLen2 INT
         	DECLARE @nDecodeLen3 INT
         	DECLARE @nDecodeLen4 INT
         	
         	SELECT @nMaxLen = SUM(MaxLength) 
         	FROM BarcodeConfigDetail WITH (NOLOCK) 
         	WHERE decodeCode = 'UNILEVER_IB01'
         	         	
         	SELECT @nDecodeLen1 = SUM(MaxLength) 
         	FROM BarcodeConfigDetail WITH (NOLOCK) 
         	WHERE decodeCode = 'UNILEVER_IB01'
         	AND DecodeLineNumber = '00001'
         	
         	SELECT @nDecodeLen2 = SUM(MaxLength) 
         	FROM BarcodeConfigDetail WITH (NOLOCK) 
         	WHERE decodeCode = 'UNILEVER_IB01'
         	AND DecodeLineNumber = '00002'
         	
         	SELECT @nDecodeLen3 = SUM(MaxLength) 
         	FROM BarcodeConfigDetail WITH (NOLOCK) 
         	WHERE decodeCode = 'UNILEVER_IB01'
         	AND DecodeLineNumber = '00003'
         	
         	SELECT @nDecodeLen4 = SUM(MaxLength) 
         	FROM BarcodeConfigDetail WITH (NOLOCK) 
         	WHERE decodeCode = 'UNILEVER_IB01'
         	AND DecodeLineNumber = '00004'
         	
         	--Barcode: sku [space] lottable02 [space] lottable13 [space] lottable04
            IF @cBarcode <> ''  AND LEN (@cBarcode) >= @nMaxLen --(cc01)  
            BEGIN  
               DECLARE @nRowcount      INT  
               DECLARE @cFacility      NVARCHAR(5) 
               DECLARE @nBeforeRecQty  INT 
               DECLARE @nQtyExpected   INT
               DECLARE @cLottable13    NVARCHAR(10)
               DECLARE @cLottable04    NVARCHAR(10)

               SET @cBarcode = REPLACE(@cBarcode,' ',';')
               	
               -- Column 1: SKU  
               SET @cSKU = rdt.rdtGetParsedString( @cBarcode, 1, ';')  
               IF @cSKU = ''  
               BEGIN  
                  SET @nErrNo = 166201  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Require SKU  
                  GOTO Quit  
               END 
               ELSE IF LEN(@cSKU) <> @nDecodeLen1
               BEGIN
               	SET @nErrNo = 166205  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
                  GOTO Quit
               END
                  
               -- Column 2: Lottable02  
               SET @cLottable02 = rdt.rdtGetParsedString( @cBarcode, 2, ';')  
               IF @cLottable02 = ''  
               BEGIN  
                  SET @nErrNo = 166202  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Require L02  
                  GOTO Quit  
               END
               ELSE IF LEN(@cLottable02) <> @nDecodeLen2
               BEGIN
               	SET @nErrNo = 166206  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L02  
                  GOTO Quit
               END  
                  
               -- Column 3: Lottable13 --YYMM00->dmy
               SET @cLottable13 = rdt.rdtGetParsedString( @cBarcode, 3, ';')  
               IF @cLottable13 = ''  
               BEGIN  
                  SET @nErrNo = 166203  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Require L13  
                  GOTO Quit  
               END 
               ELSE
               BEGIN
               	IF LEN(@cLottable13) <> @nDecodeLen3
                  BEGIN
               	   SET @nErrNo = 166207  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L13
                     GOTO Quit
                  END 
                  ELSE
                  BEGIN
                  	SET @dLottable13 = rdt.rdtConvertToDate2(LEFT(YEAR(GETDATE()),2) + @cLottable13,'ymd')
                  END
               END
                  	
               -- Column 4: Lottable04 --YYMM00
               SET @cLottable04 = rdt.rdtGetParsedString( @cBarcode, 4, ';')  
               IF @cLottable04 = ''  
               BEGIN  
                  SET @nErrNo = 166204  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Require L04  
                  GOTO Quit  
               END 
               ELSE
               BEGIN
               	IF LEN(@cLottable04) <> @nDecodeLen4
                  BEGIN
               	   SET @nErrNo = 166208  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L04
                     GOTO Quit
                  END 
                  ELSE
                  BEGIN
                  	SET @dLottable04 =  rdt.rdtConvertToDate2(LEFT(YEAR(GETDATE()),2) + @cLottable04,'ymd')
                  END                  
               END
            END  
            ELSE
            BEGIN
               SET @cSKU = @cBarcode
            END
         END  
      END  
   END  
  
Quit:  
  
END 

GO