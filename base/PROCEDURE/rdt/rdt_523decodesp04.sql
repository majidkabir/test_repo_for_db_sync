SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/
/* Store procedure: rdt_523DecodeSP04                                          */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Decode For PMI case                                               */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2024-10-22  ShaoAn    1.0   FCR-759-999 ID and UCC Length Issue            */
/* 2024-10-24            1.0.1 Extended parameter definition                  */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_523DecodeSP04] (
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
   @cErrMsg           NVARCHAR( 120)  OUTPUT    
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cBarcode = LTRIM(RTRIM(@cBarcode))
   IF @nFunc = 523
   BEGIN
      IF @nStep = 1 
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            If @cBarcode <> ''  -- ID  Decode
            BEGIN
               IF LEN(@cBarcode) = 18  
               BEGIN
                  SET @cID = @cBarcode
                  GOTO Quit
               END
               IF LEN(@cBarcode) <> 25
               BEGIN
                  SET @nErrNo = 227101
                  SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid ID(25 digit)
                  GOTO Quit
               END
               SET @cID = RIGHT(@cBarcode, 18)
            END

            If @cBarcodeUCC <> '' -- UCC  Decode
            BEGIN
               IF LEN(@cBarcodeUCC) = 20
               BEGIN
                  SET @cUCC = @cBarcodeUCC
                  GOTO Quit
               END
               IF LEN(@cBarcodeUCC) <> 40
               BEGIN
                  SET @nErrNo = 227102
                  SET @cErrMsg = [rdt].[rdtgetmessage]( @nErrNo, @cLangCode, N'DSP') -- Invalid UCC(40 digit)
                  GOTO Quit
               END
               SET @cUCC = RIGHT(@cBarcodeUCC, 20)
               GOTO Quit
            END
         END
      END
   END

   Quit:
END


GO