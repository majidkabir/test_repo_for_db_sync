SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829DecodeSP01                                        */
/* Purpose: Validate ASN & UCC scanned in                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-Jan-05 1.0  James    WMS8010 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829DecodeSP01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR( 15),
   @cParam1      NVARCHAR( 20),
   @cParam2      NVARCHAR( 20),
   @cParam3      NVARCHAR( 20),
   @cParam4      NVARCHAR( 20),
   @cParam5      NVARCHAR( 20),
   @cBarcode     NVARCHAR( 60),
   @cUCCNo       NVARCHAR( 20)   OUTPUT,
   @nErrNo       INT             OUTPUT,
   @cErrMsg      NVARCHAR(20)    OUTPUT
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @bSuccess       INT
   DECLARE @nSKUCnt        INT

   SET @nErrNo = 0
   
   IF @nStep = 2 -- SKU/UCC
   BEGIN
      EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUCCNo
         ,@nSKUCnt     = @nSKUCnt      OUTPUT
         ,@bSuccess    = @bSuccess     OUTPUT
         ,@nErr        = @nErrNo       OUTPUT
         ,@cErrMsg     = @cErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 135101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU/UPC
         GOTO Quit
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 135102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO Quit
      END

      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUCCNo       OUTPUT
         ,@bSuccess    = @bSuccess     OUTPUT
         ,@nErr        = @nErrNo       OUTPUT
         ,@cErrMsg     = @cErrMsg      OUTPUT
   END

   Quit:



GO