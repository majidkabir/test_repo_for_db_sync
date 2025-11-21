SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_RetailSKU                             */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Verify RetailSKU setting                                    */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 18-07-2016  1.0  Ung          SOS373327. Created                     */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_RetailSKU]
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

   DECLARE @cBUSR10     NVARCHAR(30)
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Get SKU info
      SET @cBUSR10 = ''
      SELECT @cBUSR10 = BUSR10 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   
      IF @cBUSR10 = 'Y'
         SET @nErrNo = -1
   END

   /***********************************************************************************************
                                                 UPDATE
   ***********************************************************************************************/
   -- Check SKU setting
   IF @cType = 'UPDATE'
   BEGIN
      DECLARE @cChkSKU     NVARCHAR(20)
      DECLARE @cChkAltSKU  NVARCHAR(20)
      DECLARE @nSKUCnt     INT
      DECLARE @bSuccess    INT
      DECLARE @nRowCount   INT
   
      -- Get SKU info
      SELECT @cBUSR10 = BUSR10 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   
      IF @cBUSR10 = 'Y'
      BEGIN
         -- Check blank
         IF @cValue = ''
         BEGIN
            SET @nErrNo = 102451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Barcode
            GOTO Fail
         END
         
         -- Get SKU barcode
         SELECT @cChkAltSKU = ISNULL( AltSKU, '') FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
         SET @nRowCount = @@ROWCOUNT
         
         -- SKU with barcode
         IF @cChkAltSKU <> ''
         BEGIN
            -- Check other SKU using same barcode
            SET @cChkSKU = ''
            SELECT @cChkSKU = SKU FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND AltSKU = @cValue
            SET @nRowCount = @@ROWCOUNT
   
            -- Check multi SKU barcode
            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 102452
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarcod
               GOTO Fail
            END
         END
         
         -- SKU No barcode
         IF @cChkAltSKU = ''
         BEGIN
            -- Check other SKU using same barcode
            SET @cChkSKU = ''
            SELECT @cChkSKU = SKU FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND AltSKU = @cValue
            SET @nRowCount = @@ROWCOUNT
      
            -- Check multi SKU barcode
            IF @nRowCount > 0
            BEGIN
               SET @nErrNo = 102453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BarcodeAdyUsed
               GOTO Fail
            END
         END
   
         -- Update SKU
         UPDATE SKU SET
            RetailSKU = @cValue,
            AltSKU = '',
            BUSR10 = 'N'
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Fail
         END
      END
   END
   
Fail:
   
END

GO