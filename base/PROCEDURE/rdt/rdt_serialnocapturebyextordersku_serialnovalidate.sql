SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SerialNoCaptureByExtOrderSKU_SerialNoValidate   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Validate serial No                                          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2023-12-14  1.0  Ung         WMS-24364 Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_SerialNoCaptureByExtOrderSKU_SerialNoValidate] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT,
   @cFacility                 NVARCHAR( 5),
   @cStorerkey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cExternOrderKey           NVARCHAR( 50),
   @cSKU                      NVARCHAR( 20),
   @cSerialNo                 NVARCHAR( 30),
   @nSerialQTY                INT,
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   -- Get RDT storer configure
   DECLARE @cSerialNoValidateSP NVARCHAR(20)
   SET @cSerialNoValidateSP = rdt.RDTGetConfig( @nFunc, 'SerialNoValidateSP', @cStorerKey)
   IF @cSerialNoValidateSP = '0'
      SET @cSerialNoValidateSP = ''

   /***********************************************************************************************
                                              Custom validate
   ***********************************************************************************************/
   -- Check validate SP blank
   IF @cSerialNoValidateSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSerialNoValidateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSerialNoValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cOrderKey, @cExternOrderKey, @cSKU, @cSerialNo, @nSerialQTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile           INT,                  ' + 
            ' @nFunc             INT,                  ' + 
            ' @cLangCode         NVARCHAR( 3),         ' + 
            ' @nStep             INT,                  ' + 
            ' @nInputKey         INT,                  ' + 
            ' @cFacility         NVARCHAR( 5),         ' + 
            ' @cStorerkey        NVARCHAR( 15),        ' + 
            ' @cOrderKey         NVARCHAR( 10),        ' + 
            ' @cExternOrderKey   NVARCHAR( 50),        ' + 
            ' @cSKU              NVARCHAR( 20),        ' + 
            ' @cSerialNo         NVARCHAR( 30),        ' + 
            ' @nSerialQTY        INT,                  ' + 
            ' @nErrNo            INT           OUTPUT, ' + 
            ' @cErrMsg           NVARCHAR( 20) OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cOrderKey, @cExternOrderKey, @cSKU, @cSerialNo, @nSerialQTY, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT 

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard validate
   ***********************************************************************************************/
   DECLARE @cRetailSKU        NVARCHAR( 20)
   DECLARE @cAltSKU           NVARCHAR( 20)
   DECLARE @cManufacturerSKU  NVARCHAR( 20)

   -- Check format
   IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIALNO', @cSerialNo) = 0
   BEGIN
      SET @nErrNo = 209901
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
      SET @nErrNo = 209902
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SNO
      GOTO Quit
   END
   
   -- Check serial no is UPC barcode
   IF EXISTS( SELECT TOP 1 1 FROM UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND UPC = @cSerialNo)
   BEGIN
      SET @nErrNo = 209903
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

   -- Check double scanned
   IF @@ROWCOUNT > 0
   BEGIN
      -- Check double scan
      IF @cStatus IN ('5', '6')
      BEGIN
         SET @nErrNo = 209904
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO scanned
         GOTO Quit
      END
   END

Quit:

END

GO