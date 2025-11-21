SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DecodeSP08                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Return PackKey.CaseCNT, if login DefaultUOM = 2             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-09-13  1.0  Ung         WMS-20521 Created                       */
/* 2023-03-20  1.1  Ung         WMS-21946 Add SerialNo param            */
/* 2024-10-25  1.2  PXL009      FCR-759 ID and UCC Length Issue         */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_838DecodeSP08
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

   IF @nFunc = 838
   BEGIN
      IF @nStep = 3  -- SKU QTY
      BEGIN
         IF @nInputKey = 1
         BEGIN

            DECLARE @bSuccess INT
            DECLARE @cUPC NVARCHAR( 30)
            DECLARE @cPUOM NVARCHAR( 1)

            -- Get session info
            SELECT @cPUOM = V_UOM FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
            
            -- Default UOM
            IF @cPUOM = '2' -- Case
            BEGIN
               SELECT @cUPC = LEFT( @cBarcode, 30)
               
               -- Get SKU
               EXEC rdt.rdt_GetSKU
                  @cStorerKey  = @cStorerKey
                  ,@cSKU        = @cUPC      OUTPUT
                  ,@bSuccess    = @bSuccess  OUTPUT
                  ,@nErr        = @nErrNo    OUTPUT
                  ,@cErrMsg     = @cErrMsg   OUTPUT
               IF @bSuccess <> 1
                  GOTO Quit
                  
               SET @cSKU = @cUPC
                  
               -- Get SKU info
               SELECT @nQTY = Pack.CaseCNT 
               FROM SKU WITH (NOLOCK) 
                  JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE StorerKey = @cStorerKey 
                  AND SKU = @cSKU
            END
         END
      END
   END

Quit:

END

GO