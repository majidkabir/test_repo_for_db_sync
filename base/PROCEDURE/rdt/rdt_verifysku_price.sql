SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_Price                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 26-10-2018  1.0  James        WMS-6665. Created                      */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_Price]
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
   DECLARE @cLastReceivedSKU  NVARCHAR( 20)
   DECLARE @cOnScreenSKU      NVARCHAR( 20)
   DECLARE @cReceiptKey       NVARCHAR( 10)
   DECLARE @nSKUPrice         FLOAT
   DECLARE @bSuccess          INT
   
   IF @nFunc = 608
      SELECT @cReceiptKey = V_ReceiptKey
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Check if previously received sku is different with current sku
      -- If yes then need show verify sku screen ato capture sku price

      SELECT @cLastReceivedSKU = I_Field03, 
             @cOnScreenSKU = V_String20
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorerKey
        ,@cSKU        = @cLastReceivedSKU OUTPUT
        ,@bSuccess    = @bSuccess         OUTPUT
        ,@nErr        = @nErrNo           OUTPUT
        ,@cErrMsg     = @cErrMsg          OUTPUT

      IF @cLastReceivedSKU <> ''
      BEGIN
         
         --SELECT TOP 1 @cLastReceivedSKU = SKU
         --FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         --WHERE ReceiptKey = @cReceiptKey
         --AND   ( QtyReceived  + BeforeReceivedQty) > 0
         --ORDER BY EditDate DESC
                  INSERT INTO TRACEINFO (TraceName, TimeIn, COL1, COL2) VALUES ('6082', GETDATE(), @cOnScreenSKU, @cLastReceivedSKU)
         -- On screen sku = last scan sku
         IF @cOnScreenSKU <> @cLastReceivedSKU
            SET @nErrNo = -1 --Need show
      END
      ELSE
         SET @nErrNo = -1 --SKU not keyed in yet, Need show
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
         SET @nErrNo = 130801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value
         GOTO Fail
      END
      
      -- Get SKU info
      SELECT @nSKUPrice = ISNULL( Price, 0)
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Check ALTSKU
      IF @nSKUPrice <> CAST( @cValue AS FLOAT)
      BEGIN
         SET @nErrNo = 130802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Price
         GOTO Fail
      END
   END
   
Fail:
   
END

GO