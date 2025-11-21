SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DecodeSP11                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Decode for PMI case                                         */
/*                                                                      */
/* Date        Author   Ver.  Purposes                                  */
/* 2024-10-17  PXL009   1.0   FCR-759 ID and UCC Length Issue           */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_838DecodeSP11]
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cFacility           NVARCHAR( 5),
   @cStorerKey          NVARCHAR( 15),
   @cPickSlipNo         NVARCHAR( 10),
   @cFromDropID         NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cBarcode2           NVARCHAR( 60),
   @cSKU                NVARCHAR( 20)  OUTPUT,
   @nQTY                INT            OUTPUT,
   @cPackDtlRefNo       NVARCHAR( 20)  OUTPUT,
   @cPackDtlRefNo2      NVARCHAR( 20)  OUTPUT,
   @cPackDtlUPC         NVARCHAR( 30)  OUTPUT,
   @cPackDtlDropID      NVARCHAR( 20)  OUTPUT,
   @cSerialNo           NVARCHAR( 30)  OUTPUT,
   @cFromDropIDDecode   NVARCHAR( 20)  OUTPUT,
   @cToDropIDDecode     NVARCHAR( 20)  OUTPUT,
   @cUCCNo              NVARCHAR( 20)  OUTPUT,
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUCC     NVARCHAR( 20)
   DECLARE @cID      NVARCHAR( 18)

   IF @nFunc = 838
   BEGIN
      IF @nStep = 1  -- FromDropID/ToDropID
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @cID = ''
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cID     = @cID        OUTPUT,
                  @nErrNo  = @nErrNo      OUTPUT,
                  @cErrMsg = @cErrMsg     OUTPUT,
                  @cType   = 'ID'

               IF @nErrNo <> 0
                  GOTO Quit

               SET @cFromDropIDDecode = @cID
            END

            IF @cBarcode2 <> ''
            BEGIN
               SET @cID = ''
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode2,
                  @cID     = @cID         OUTPUT,
                  @nErrNo  = @nErrNo      OUTPUT,
                  @cErrMsg = @cErrMsg     OUTPUT,
                  @cType   = 'ID'

               IF @nErrNo <> 0
                  GOTO Quit

               SET @cToDropIDDecode = @cID
            END

            GOTO Quit
         END
      END

      IF @nStep = 8  -- UCC
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @cUCC = ''
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cUCCNo  = @cUCC        OUTPUT,
                  @nErrNo  = @nErrNo      OUTPUT,
                  @cErrMsg = @cErrMsg     OUTPUT,
                  @cType   = 'UCCNo'

               IF @nErrNo <> 0
                  GOTO Quit

               SET @cUCCNo = @cUCC
            END

            GOTO Quit
         END
      END
   END

Quit:

END

GO