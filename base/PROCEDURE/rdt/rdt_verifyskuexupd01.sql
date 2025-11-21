SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKUExUpd01                                */
/* Copyright      : LF Logistic                                         */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 08-09-2014  1.0  Ung          SOS320350. Created                     */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_VerifySKUExUpd01]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @cStorerKey      NVARCHAR( 15),
   @cSKU            NVARCHAR( 20),
   @cType           NVARCHAR( 10),
   @cVerifySKUInfo  NVARCHAR( 20) OUTPUT,
   @cWeight         NVARCHAR( 10) OUTPUT,
   @cCube           NVARCHAR( 10) OUTPUT,
   @cLength         NVARCHAR( 10) OUTPUT,
   @cWidth          NVARCHAR( 10) OUTPUT,
   @cHeight         NVARCHAR( 10) OUTPUT,
   @cInnerPack      NVARCHAR( 10) OUTPUT,
   @cCaseCount      NVARCHAR( 10) OUTPUT,
   @cPalletCount    NVARCHAR( 10) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cBUSR10     NVARCHAR(30)
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
      IF @cVerifySKUInfo = ''
      BEGIN
         SET @nErrNo = 91851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Barcode
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- VerifySKUInfo
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
         SELECT @cChkSKU = SKU FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND AltSKU = @cVerifySKUInfo
         SET @nRowCount = @@ROWCOUNT

         -- Check multi SKU barcode
         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 91852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarcod
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- VerifySKUInfo
            GOTO Fail
         END
      END
      
      -- SKU No barcode
      IF @cChkAltSKU = ''
      BEGIN
         -- Check other SKU using same barcode
         SET @cChkSKU = ''
         SELECT @cChkSKU = SKU FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND AltSKU = @cVerifySKUInfo
         SET @nRowCount = @@ROWCOUNT
   
         -- Check multi SKU barcode
         IF @nRowCount > 0
         BEGIN
            SET @nErrNo = 91853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BarcodeAdyUsed
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- VerifySKUInfo
            GOTO Fail
         END
      END

      -- Update SKU
      UPDATE SKU SET
         RetailSKU = @cVerifySKUInfo,
         AltSKU = '',
         BUSR10 = 'N'
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

   END

Fail:
END -- End Procedure

GO