SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1829DecodeSP02                                        */
/* Purpose: Validate ASN & UCC scanned in                                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-11-15 1.0  Ung      WMS-5728 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829DecodeSP02] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cParam1      NVARCHAR( 20), 
   @cParam2      NVARCHAR( 20), 
   @cParam3      NVARCHAR( 20), 
   @cParam4      NVARCHAR( 20), 
   @cParam5      NVARCHAR( 20), 
   @cBarcode     NVARCHAR( 60), 
   @cUCCNo       NVARCHAR( 20)  OUTPUT, 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @bSuccess    INT
   DECLARE @cReceiptKey NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cAuthority  NVARCHAR( 1)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cUCC        NVARCHAR( 1)

   -- Get session info
   SELECT 
      @cFacility = Facility, 
      @cReceiptKey = V_String1
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   SELECT @bSuccess = 0
   EXECUTE nspGetRight
      @c_Facility    = @cFacility,
      @c_StorerKey   = @cStorerKey,
      @c_SKU         = NULL,
      @c_ConfigKey   = 'UCC',
      @b_success     = @bSuccess    OUTPUT,
      @c_authority   = @cAuthority  OUTPUT,
      @n_err         = @nErrNo      OUTPUT,
      @c_errmsg      = @cErrMsg     OUTPUT

   IF @bSuccess = '1' AND @cAuthority = '1'
      SET @cUCC = '1'
   ELSE 
      SET @cUCC = ''

   -- By SKU
   IF @cUCC = ''
   BEGIN
      SET @cSKU = @cUCCNo

      -- Get SKU/UPC
      DECLARE @nSKUCnt INT
      SET @nSKUCnt = 0

      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 131751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Quit
      END

      -- Validate SKU/UPC
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 131752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO Quit
      END

      IF @nSKUCnt = 1
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @bSuccess      OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU in ASN
      IF NOT EXISTS( SELECT 1
         FROM dbo.Receiptdetail WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU)
      BEGIN
         SET @nErrNo = 131753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not in ASN
         GOTO Quit
      END
      
      -- Check over receive
      IF NOT EXISTS( SELECT 1
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND QTYExpected > BeforeReceivedQTY)
      BEGIN
         SET @nErrNo = 131754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over receive
         GOTO Quit
      END
      
      SET @cUCCNo = @cSKU
   END

Quit:


GO