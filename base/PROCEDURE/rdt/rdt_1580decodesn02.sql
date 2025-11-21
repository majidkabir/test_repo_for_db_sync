SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1580DecodeSN02                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Insert serial no into rdtReceiveSerialNoLog                 */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 2023-03-27  1.0  James        WMS-21945. Created                     */
/* 2023-04-25  1.1  James        Addhoc fix check barcode len (james01) */
/* 2023-05-03  1.2  James        WMS-22488 Enhance serial check(james02)*/
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1580DecodeSN02]
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cSKU        NVARCHAR( 20),
   @cBarcode    NVARCHAR( MAX),
   @cSerialNo   NVARCHAR( 30)  OUTPUT,
   @nSerialQTY  INT            OUTPUT,
   @nBulkSNO    INT            OUTPUT,
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUCC     NVARCHAR( 20)
   DECLARE @nUCCQty  INT = 0
   DECLARE @nRcvQty  INT = 0
   DECLARE @cStatus  NVARCHAR( 10) = ''
   
   IF LEN( RTRIM( @cBarcode)) <> 24
   BEGIN
      SET @nErrNo = 198306
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Serial#
      GOTO Quit
   END

   SELECT @cStatus = [Status] 
   FROM dbo.SerialNo WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SerialNo = @cBarcode
   
   IF ISNULL( @cStatus, '') <> ''
   BEGIN
      SET @nErrNo = 198301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SerialNo Exists
      GOTO Quit
   END

   IF @cStatus = '1'
   BEGIN
      SET @nErrNo = 198308
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNo Received
      GOTO Quit
   END

   IF EXISTS( SELECT 1
              FROM dbo.ReceiptSerialNo WITH (NOLOCK)
              WHERE StorerKey = @cStorerKey
              AND   SerialNo = @cBarcode) AND ISNULL( @cStatus, '') = ''
   BEGIN
      SET @nErrNo = 198309
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNo Exists
      GOTO Quit
   END

   SET @cSKU = SUBSTRING( @cBarcode, 1, 18)

   IF NOT EXISTS ( SELECT 1 
                   FROM dbo.SKU WITH (NOLOCK)
                   WHERE StorerKey = @cStorerKey
                   AND   Sku = @cSKU)
   BEGIN
      SET @nErrNo = 198302
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Serial#
      GOTO Quit
   END

   SELECT @cUCC = V_Barcode
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF NOT EXISTS ( SELECT 1 
                   FROM dbo.UCC WITH (NOLOCK)
                   WHERE Storerkey = @cStorerKey
                   AND   UCCNo = @cUCC
                   AND   SKU = @cSKU)
   BEGIN
      SET @nErrNo = 198303
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not In UCC
      GOTO Quit
   END

   SELECT @nUCCQty = ISNULL( SUM( Qty), 0)
   FROM dbo.UCC WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND   UCCNo = @cUCC
   
   SELECT @nRcvQty = ISNULL( SUM( Qty), 0)
   FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
   WHERE Mobile = @nMobile
   AND   Func = @nFunc
   AND   SKU = @cSKU

   IF ( @nRcvQty + 1) > @nUCCQty
   BEGIN
      SET @nErrNo = 198307
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty Not Tally
      GOTO Quit
   END

   IF NOT EXISTS ( SELECT 1 
                   FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
                   WHERE Mobile = @nMobile
                   AND   Func = @nFunc
                   AND   SKU = @cSKU
                   AND   SerialNo = @cBarcode)
   BEGIN
      INSERT INTO rdt.rdtReceiveSerialNoLog 
      (Mobile, Func, StorerKey, SKU, SerialNo, QTY) 
      VALUES 
      (@nMobile, @nFunc, @cStorerKey, @cSKU, @cBarcode, 1)
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 198304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert Log Err
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      SET @nErrNo = 198305
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SerialNo Exists
      GOTO Quit
   END
Quit:

END

GO