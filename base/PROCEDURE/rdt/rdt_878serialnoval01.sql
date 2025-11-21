SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_878SerialNoVal01                                   */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2023-12-15 1.0  Ung     WMS-24364 Created                               */
/***************************************************************************/

CREATE   PROCEDURE rdt.rdt_878SerialNoVal01
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5), 
   @cStorerkey       NVARCHAR( 15),
   @cOrderKey        NVARCHAR( 10),
   @cExternOrderKey  NVARCHAR( 50),
   @cSKU             NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cRetailSKU        NVARCHAR( 20)
   DECLARE @cAltSKU           NVARCHAR( 20)
   DECLARE @cManufacturerSKU  NVARCHAR( 20)

   -- Check format
   IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIALNO', @cSerialNo) = 0
   BEGIN
      SET @nErrNo = 209851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
      GOTO Quit
   END

   -- Get SKU info
   SELECT 
      @cAltSKU = AltSKU, 
      @cRetailSKU = RetailSKU, 
      @cManufacturerSKU = ManufacturerSKU
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Check serial no is SKU barcode
   IF @cSKU = @cSerialNo OR
      @cAltSKU = @cSerialNo OR
      @cRetailSKU = @cSerialNo OR
      @cManufacturerSKU = @cSerialNo
   BEGIN
      SET @nErrNo = 209852
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SNO
      GOTO Quit
   END
   
   -- Check serial no is UPC barcode
   IF EXISTS( SELECT TOP 1 1 FROM UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND UPC = @cSerialNo)
   BEGIN
      SET @nErrNo = 209853
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SNO
      GOTO Quit
   END

   -- Get serial no info
   DECLARE @cStatus NVARCHAR( 10)
   SELECT @cStatus = Status
   FROM dbo.SerialNo WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND SKU = @cSKU 
      AND SerialNo = @cSerialNo

   -- Existing serial no
   IF @@ROWCOUNT > 0
   BEGIN
      -- Check double scan
      IF @cStatus IN ('5', '6')
      BEGIN
         SET @nErrNo = 209854
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO scanned
         GOTO Quit
      END
   END

   -- Prompt to confirm serial no
   IF LEFT( @cSerialNo, 6) <> @cSKU AND
      LEFT( @cSerialNo, 10) <> @cSKU
      SET @nErrNo = -1  

Quit:

END

GO