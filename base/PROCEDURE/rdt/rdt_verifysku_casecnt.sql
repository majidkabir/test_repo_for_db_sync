SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_CaseCNT                               */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Verify pallet Ti Hi setting                                 */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 18-01-2016  1.0  Ung          SOS361177. Created                     */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_CaseCNT]
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

   DECLARE @fCaseCount  FLOAT
   DECLARE @cPackKey    NVARCHAR(10)
   DECLARE @cPackUOM1   NVARCHAR(10)
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Get NetWgt
      SELECT @fCaseCount = Pack.CaseCnt
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         
      -- Check not setup
      IF @fCaseCount = 0
         SET @nErrNo = -1 --Need setup
      ELSE
         SET @cValue = rdt.rdtFormatFloat( @fCaseCount)
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
         SET @nErrNo = 59701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CaseCount
         GOTO Fail
      END
      
      -- Check valid
      IF rdt.rdtIsValidQty( @cValue, 1) = 0 -- not check for zero
      BEGIN
         SET @nErrNo = 59702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CaseCnt
         GOTO Fail
      END
      
      -- Get SKU info
      SELECT 
         @cPackKey = Pack.PackKey, 
         @cPackUOM1 = Pack.PackUOM1, 
         @fCaseCount = Pack.CaseCnt
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
      
      -- Check value changed
      IF @fCaseCount <> CAST( @cValue AS FLOAT)
      BEGIN
         -- Check inventory balance
         IF EXISTS( SELECT TOP 1 1 
            FROM dbo.SKUxLOC SL WITH (NOLOCK) 
               JOIN SKU WITH (NOLOCK) ON (SL.StorerKey = SKU.StorerKey AND SL.SKU = SKU.SKU)
               JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE Pack.PackKey = @cPackKey 
               AND SL.QTY > 0)
         BEGIN
            SET @nErrNo = 59703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChg,HvInvBal
            GOTO Fail
         END

         -- Value changed
         SET @fCaseCount = CAST( @cValue AS FLOAT)
         
         -- Get default UOM
         IF @cPackUOM1 = ''
            SELECT @cPackUOM1 = UDF04
            FROM CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'VerifySKU'
               AND Code2 = @nFunc
               AND StorerKey = @cStorerKey

         -- Update Pack setting
         UPDATE dbo.Pack SET
            PackUOM1 = @cPackUOM1, 
            CaseCNT = @fCaseCount
         WHERE PackKey = @cPackKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 59704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PkKey Fail
            GOTO Fail
         END
      END
   END
   
Fail:
   
END

GO