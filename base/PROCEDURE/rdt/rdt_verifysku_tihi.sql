SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_TiHi                                  */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Verify pallet Ti Hi setting                                 */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 31-07-2015  1.0  Ung          SOS347397. Created                     */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_TiHi]
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

   DECLARE @nPalletTi  INT
   DECLARE @nPalletHi  INT
   DECLARE @nPalletCNT FLOAT
   DECLARE @cPalletTi  NVARCHAR(10)
   DECLARE @cPalletHi  NVARCHAR(10)
   DECLARE @nPos       INT
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Get TiHi
      SELECT 
         @nPalletTi = PACK.PalletTi, 
         @nPalletHi = PACK.PalletHi, 
         @nPalletCNT = PACK.Pallet
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU
         
      -- Check not setup
      IF @nPalletTi = 0 OR @nPalletHi = 0 OR @nPalletCNT = 0
         SET @nErrNo = -1 --Need setup
      ELSE
         SET @cValue = 
            CAST( @nPalletTi AS NVARCHAR(5)) + 'x' + 
            CAST( @nPalletHi AS NVARCHAR(5))

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
         SET @nErrNo = 55651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Ti x Hi
         GOTO Fail
      END
      
      -- Get delimeter position
      SET @nPos = CHARINDEX( 'X', @cValue) 
      
      -- Check delimeter
      IF @nPos = 0
      BEGIN
         SET @nErrNo = 55652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         GOTO Fail
      END
      
      -- Get Ti Hi
      SET @cPalletTi = SUBSTRING( @cValue, 1, @nPos - 1)
      SET @cPalletHi = SUBSTRING( @cValue, @nPos + 1, LEN( @cValue))
      
      -- Check blank Ti
      IF @cPalletTi = ''
      BEGIN
         SET @nErrNo = 55653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Ti
         GOTO Fail
      END
      
      -- Check blank Hi
      IF @cPalletHi = ''
      BEGIN
         SET @nErrNo = 55654
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Hi
         GOTO Fail
      END
      
      -- Check valid Ti
      IF rdt.rdtIsValidQTY( @cPalletTi, 1) = 0
      BEGIN
         SET @nErrNo = 55655
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Ti
         GOTO Fail
      END

      -- Check valid Hi
      IF rdt.rdtIsValidQTY( @cPalletHi, 1) = 0
      BEGIN
         SET @nErrNo = 55656
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Hi
         GOTO Fail
      END

      -- Update
      UPDATE Pack SET
         PACK.PalletTi = @cPalletTi, 
         PACK.PalletHi = @cPalletHi, 
         PACK.Pallet = CAST( @cPalletTi AS INT) * CAST( @cPalletHi AS INT)
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU

      IF @@ERROR <> 0
         GOTO Fail
   END
   
Fail:
   
END

GO