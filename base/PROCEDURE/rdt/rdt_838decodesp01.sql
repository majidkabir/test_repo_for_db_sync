SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispDysonLBLNoDecode                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Default QTY base on Receipt.DocType                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 04-05-2017  1.0  Ung         WMS-1817 Created                        */
/* 10-03-2020  1.1  Pakyuen     INC1070450-Do not return the value(py01)*/
/* 20-03-2023  1.2  Ung         WMS-21946 Add SerialNo param            */
/* 2024-10-22  1.3  PXL009     FCR-759 ID and UCC Length Issue          */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_838DecodeSP01]
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
            -- IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND SerialNoCapture = '1')  py01
            --    SET @nQTY = 1
         END
      END
   END

Quit:

END

GO