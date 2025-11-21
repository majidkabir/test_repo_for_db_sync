SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_534DecodeSP02                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Decode Label No Scanned                                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 07-08-2018  1.0  James       INC0341989 Created (Ad hoc)             */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_534DecodeSP02] (
   @nMobile      INT,
   @nFunc        INT,
   @nStep        INT,
   @nInputKey    INT,
   @cLangCode    NVARCHAR( 3),
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),
   @cFromLoc     NVARCHAR( 10),
   @cToID        NVARCHAR( 18),
   @cBarcode     NVARCHAR( 20),
   @cUPC         NVARCHAR( 20) OUTPUT,
   @nQTY         INT           OUTPUT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSKU        NVARCHAR( 20),  
           @cLot01      NVARCHAR( 18),   
           @cLot02      NVARCHAR( 18),   
           @cLot02_1    NVARCHAR( 18),   
           @cLot02_2    NVARCHAR( 18),   
           @cLot        NVARCHAR( 10)
  
   IF ISNULL( @cBarcode, '') = ''  
      GOTO Quit  
  
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1 
      BEGIN
         -- Lottable01  
         SET @cLot01 = SUBSTRING( RTRIM( @cBarcode), 1, 2)  
  
         -- SKU  
         SET @cSKU = SUBSTRING( RTRIM( @cBarcode), 3, 13)  
  
         --Lottable02  
         SET @cLot02_1 = SUBSTRING( RTRIM( @cBarcode), 16, 12)  
         SET @cLot02_2 = SUBSTRING( RTRIM( @cBarcode), 28, 2)  
         SET @cLot02 = RTRIM( @cLot02_1) + '-' + RTRIM( @cLot02_1)  
  
         -- Get Lot#  
         SELECT TOP 1 @cLot = LOT   
         FROM dbo.LotAttribute WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND   SKU = @cSKU  
         AND   Lottable01 = @cLot01  
         AND   Lottable02 = @cLot02  
     
         SET @cUPC = @cSKU  
         SET @nQTY = 0
      END
   END
QUIT:  
END -- End Procedure  
      

GO