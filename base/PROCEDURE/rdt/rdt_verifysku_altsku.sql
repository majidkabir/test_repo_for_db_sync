SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_AltSKU                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 29-03-2018  1.0  Ung          WMS-4378. Created                      */
/* 01-03-2019  1.1  James        WMS-8111. Add Retail & ManufacturerSKU */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_AltSKU]
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility   NVARCHAR( 3), 
   @cStorerKey  NVARCHAR( 15),
   @cSKU        NVARCHAR( 20),
   @cType       NVARCHAR( 15),
   @cLabel      NVARCHAR( 30)  OUTPUT, 
   @cShort      NVARCHAR( 10)  OUTPUT, 
   @cValue      NVARCHAR( MAX) OUTPUT, 
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSUSR4   NVARCHAR(18)
   DECLARE @cAltSKU  NVARCHAR(20)
   DECLARE @cRetSKU  NVARCHAR(20)
   DECLARE @cManSKU  NVARCHAR(20)
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Get SKU info
      SELECT 
         @cSUSR4 = ISNULL( SUSR4, ''), 
         @cAltSKU = ISNULL( AltSKU, '')
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         
      -- Check not setup
      IF @cSUSR4 = 'Y' AND @cAltSKU <> ''
         SET @nErrNo = -1 --Need setup
      ELSE
         SET @cValue = '' -- Default value
   END

   /***********************************************************************************************
                                                 UPDATE
   ***********************************************************************************************/
   -- Check SKU setting
   IF @cType = 'UPDATE'
   BEGIN
      -- Check blank
      IF @cValue = ''
      BEGIN
         SET @nErrNo = 122151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ALT SKU
         GOTO Fail
      END
      
      -- Get SKU info
      SELECT @cAltSKU = AltSKU,
             @cRetSKU = RETAILSKU,
             @cManSKU = MANUFACTURERSKU
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
      
      -- Check ALTSKU
      IF @cManSKU <> @cValue
      BEGIN
         IF @cRetSKU <> @cValue
         BEGIN
            IF @cAltSKU <> @cValue
            BEGIN
               SET @nErrNo = 122152
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ALTSKU
               GOTO Fail
            END
         END
      END
   END
   
Fail:
   
END

GO