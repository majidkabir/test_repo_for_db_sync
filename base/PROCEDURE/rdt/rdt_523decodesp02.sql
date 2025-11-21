SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523DecodeSP02                                   */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: decode IT69 label and return sku, lottable01-04             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2022-12-06  1.0  James       WMS-21272 Created                       */ 
/* 2024-10-24  1.1  ShaoAn      Extended parameter definition           */ 
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_523DecodeSP02
   @nMobile           INT,           
   @nFunc             INT,           
   @cLangCode         NVARCHAR( 3),  
   @nStep             INT,           
   @nInputKey         INT,           
   @cFacility         NVARCHAR( 5),  
   @cStorerKey        NVARCHAR( 15), 
   @cBarcode          NVARCHAR( 60), 
   @cBarcodeUCC       NVARCHAR( 60), 
   @cID               NVARCHAR( 18)  OUTPUT, 
   @cUCC              NVARCHAR( 20)  OUTPUT, 
   @cLOC              NVARCHAR( 10)  OUTPUT, 
   @cSKU              NVARCHAR( 20)  OUTPUT, 
   @nQTY              INT            OUTPUT, 
   @cLottable01       NVARCHAR( 18)  OUTPUT, 
   @cLottable02       NVARCHAR( 18)  OUTPUT, 
   @cLottable03       NVARCHAR( 18)  OUTPUT, 
   @dLottable04       DATETIME       OUTPUT, 
   @nErrNo            INT            OUTPUT, 
   @cErrMsg           NVARCHAR( 20)  OUTPUT    
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nLblLength              INT,
           @cTempOrderKey           NVARCHAR( 10),       
           @cTempSKU                NVARCHAR( 20),
           @cTempLottable02         NVARCHAR( 18),
           @cShowErrMsgInNewScn     NVARCHAR( 1),       
           @cDecodeUCCNo            NVARCHAR( 1),
           @cPickSlipNO             NVARCHAR(20)      
   
   DECLARE @cLot02_1    NVARCHAR( 18)
   DECLARE @cLot02_2    NVARCHAR( 18)
   DECLARE @cLot        NVARCHAR( 10)
   
   SET @nErrNo = 0
            
   IF @nStep = 2 -- SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- SKU  
         SET @cSKU = SUBSTRING( RTRIM( @cBarcode), 3, 13)  
  
         --Lottable02  
         SET @cLot02_1 = SUBSTRING( RTRIM( @cBarcode), 16, 12)  
         SET @cLot02_2 = SUBSTRING( RTRIM( @cBarcode), 28, 2)  
         SET @cLottable02 = RTRIM( @cLot02_1) + '-' + RTRIM( @cLot02_2)  
  
         -- Get Lot#  
         SELECT TOP 1 @cLot = LLI.Lot
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)   
         WHERE LLI.StorerKey = @cStorerkey  
         AND   LLI.SKU = @cSKU
         AND   LLI.Id = @cID
         AND   LLI.Loc = @cLOC  
         AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - ABS( LLI.QTYReplen)) > 0
         AND   LA.Lottable02 = @cLottable02  
         ORDER BY 1
      
         SELECT 
            @cLottable01 = Lottable01,
            @cLottable03 = Lottable03,
            @dLottable04 = Lottable04
         FROM dbo.LotAttribute WITH (NOLOCK)   
         WHERE Lot = @cLot  
      END
   END

Quit:
END

GO