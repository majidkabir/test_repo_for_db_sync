SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_GrossWgt                              */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Verify pallet Ti Hi setting                                 */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 31-07-2015  1.0  Ung          SOS347397. Created                     */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_GrossWgt]
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

   DECLARE @nGrossWgt    FLOAT
   DECLARE @nSTDGrossWgt FLOAT
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Get NetWgt
      SELECT @nGrossWgt = ISNULL( SKU.GrossWgt, 0)
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU
         
      -- Check not setup
      IF @nGrossWgt = 0
         SET @nErrNo = -1 --Need setup
      ELSE
         SET @cValue = rdt.rdtFormatFloat( @nGrossWgt)
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
         SET @nErrNo = 56051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need GrossWgt
         GOTO Fail
      END
      
      -- Check valid
      IF rdt.rdtIsValidQTY( @cValue, 21) = 0
      BEGIN
         SET @nErrNo = 56052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Wgt
         GOTO Fail
      END
      
      -- Get Pack info
      DECLARE @nCaseCNT FLOAT
      SELECT @nCaseCNT = PACK.CaseCNT
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU
      
      -- Calc value
      SET @nGrossWgt = CAST( @cValue AS FLOAT)
      IF @nCaseCNT > 0
         SET @nSTDGrossWgt = ROUND( @nGrossWgt / @nCaseCNT, 3)
      ELSE
         SET @nSTDGrossWgt = 0

      -- Update
      UPDATE SKU SET
         GrossWgt = @nGrossWgt, 
         STDGrossWGT = CASE WHEN @nSTDGrossWgt = 0 THEN STDGrossWGT ELSE @nSTDGrossWgt END
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU

      IF @@ERROR <> 0
         GOTO Fail
   END
   
Fail:
   
END

GO