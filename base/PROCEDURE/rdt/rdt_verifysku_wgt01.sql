SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_Wgt01                                 */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Force to show case count field for every sku received       */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 26-08-2015  1.0  James        SOS350478. Created                     */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_Wgt01]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 3), 
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @cType            NVARCHAR( 15),
   @cLabel           NVARCHAR( 30)  OUTPUT,  
   @cShort           NVARCHAR( 10)  OUTPUT, 
   @cValue           NVARCHAR( MAX) OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @fWeight        FLOAT,
           @cUpdateWeight  NVARCHAR( 1)
   
   SET @nErrNo = 0
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      SELECT @fWeight = SKU.STDGrossWGT
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
      
      IF @fWeight > 0
      BEGIN
         SET @cShort = 'O'
         SET @nErrNo = 0 
      END
      ELSE 
         SET @nErrNo = -1 --Need setup     
         
      GOTO Fail 
   END

   IF @cType = 'UPDATE'
   BEGIN
      SELECT @fWeight = SKU.STDGrossWGT
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
      
      IF @fWeight > 0
      BEGIN
         SET @cUpdateWeight = 'N'
         GOTO Fail
      END
      
      IF rdt.rdtIsValidQty( @cValue, 21) = 0
      BEGIN
         SET @nErrNo = 55751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Weight
         GOTO Fail
      END

      -- Value changed
      IF @fWeight <> CAST( @cValue AS FLOAT)
      BEGIN
         SET @fWeight = CAST( @cValue AS FLOAT)
         SET @cUpdateWeight = 'Y'
      END

      UPDATE dbo.SKU SET
            STDGrossWGT = CASE WHEN @cUpdateWeight    = 'Y' THEN @fWeight    ELSE STDGrossWGT END 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 55763
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SKU Fail
         GOTO Fail
      END
               
   END
   
Fail:
   
END

GO