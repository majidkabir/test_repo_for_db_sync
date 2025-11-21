SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_609DecodeSKUSP01                                      */  
/* Copyright: LF Logistics                                                    */  
/*                                                                            */  
/* Purpose: Decode SKU barcode                                                */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 13-09-2016  James     1.0   WMS288 Created                                 */  
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_609DecodeSKUSP01] (  
   @nMobile      INT,  
   @nFunc        INT,  
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,  
   @nInputKey    INT,  
   @cStorerKey   NVARCHAR( 15),  
   @cReceiptKey  NVARCHAR( 10),  
   @cPOKey       NVARCHAR( 10),  
   @cBarcode     NVARCHAR( 60),  
   @cLOC         NVARCHAR( 10)  OUTPUT,  
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

   IF @cBarcode = ''  
      GOTO Quit

   IF @nFunc = 609 -- Normal receiving  
   BEGIN  
      IF @nStep = 2  
      BEGIN  
         -- Barcode format:  
         -- store code * SKU * Weight  
           
         -- Detect 1st delimeter '/'  
         DECLARE @nPOS1 INT  
         SET @nPOS1 = CHARINDEX( '/', @cBarcode)  
         IF @nPOS1 = 0  
            RETURN  
  
         -- Detect 2nd delimeter '/'  
         DECLARE @nPOS2 INT  
         SET @nPOS2 = CHARINDEX( '/', @cBarcode, @nPOS1+1)  
         IF @nPOS2 = 0  
            RETURN  
              
         -- Get receipt info  
         DECLARE @cUDF03 NVARCHAR(30)  
         SELECT @cUDF03 = UserDefine03 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey  
         SET @cUDF03 = SUBSTRING( @cUDF03, 3, LEN( @cUDF03))  
  
         -- LOC as Store code  
         SET @cLOC = SUBSTRING( @cBarcode, 1, @nPOS1-1)  
              
         -- ID as store code + UDF03  
         SET @cID = LEFT( @cLOC + @cUDF03, 18)  
              
         -- SKU  
         SET @cSKU = SUBSTRING( @cBarcode, @nPOS1+1, @nPOS2-@nPOS1-1)  
  
         -- Get SKU info  
         DECLARE @nShelfLife INT  
         SET @nShelfLife = 0  
         SELECT @nShelfLife = ShelfLife FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU  
           
         -- L01  
         SET @cLottable01 = @cUDF03  
           
         -- L04  
         DECLARE @dDate DATETIME  
         SET @dDate = CONVERT( DATETIME, CONVERT( NVARCHAR(10), GETDATE(), 120), 120)  
         IF @nShelfLife > 0  
            SET @dDate = DATEADD( dd, @nShelfLife, @dDate)  
         SET @dLottable04 = @dDate  
           
         -- QTY  
         SET @nQTY = SUBSTRING( @cBarcode, @nPOS2+1, LEN( @cBarcode))  
         
--         insert into traceinfo (tracename, timein, col1, col2, col3, col4, step1, step2) values 
--         ('609', getdate(), @cLOC, @cID, @cSKU, @nQTY, @cLottable01, @dLottable04)
      END  
   END  
  
Quit:  
  
END  

GO