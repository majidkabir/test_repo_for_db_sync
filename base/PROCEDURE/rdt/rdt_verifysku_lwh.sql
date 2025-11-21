SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_LWH                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Verify pallet Ti Hi setting                                 */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 04-08-2015  1.0  Ung          SOS347397. Created                     */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_LWH]
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

   DECLARE @cLength  NVARCHAR(5)
   DECLARE @cWidth   NVARCHAR(5)
   DECLARE @cHeight  NVARCHAR(5)
   DECLARE @fLength  FLOAT
   DECLARE @fWidth   FLOAT
   DECLARE @fHeight  FLOAT
   DECLARE @fSTDCube FLOAT
   DECLARE @nPOS1    INT
   DECLARE @nPOS2    INT
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Get TiHi
      SELECT 
         @fLength = Length, 
         @fWidth = Width, 
         @fHeight = Height, 
         @fSTDCube = STDCube
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU
         
      -- Check not setup
      IF @fLength = 0 OR @fWidth = 0 OR @fHeight = 0 OR @fSTDCube = 0
         SET @nErrNo = -1 --Need setup
      ELSE
         SET @cValue = 
            rdt.rdtFormatFloat( @fLength) + 'x' + 
            rdt.rdtFormatFloat( @fWidth)  + 'x' + 
            rdt.rdtFormatFloat( @fHeight)
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
         SET @nErrNo = 55701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need L x W x H
         GOTO Fail
      END
      
      -- Check 1st delimeter
      SET @nPos1 = CHARINDEX( 'X', @cValue) 
      IF @nPos1 = 0
      BEGIN
         SET @nErrNo = 55702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         GOTO Fail
      END
      
      -- Check 2nd delimeter
      SET @nPos2 = CHARINDEX( 'X', @cValue, @nPOS1 + 1) 
      IF @nPos2 = 0
      BEGIN
         SET @nErrNo = 55703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         GOTO Fail
      END

      -- Get L W H
      SET @cLength = SUBSTRING( @cValue, 1, @nPos1 - 1)
      SET @cWidth = SUBSTRING( @cValue, @nPos1 + 1, @nPos2 - @nPos1 - 1)
      SET @cHeight = SUBSTRING( @cValue, @nPos2 + 1, LEN( @cValue))
      
      -- Check blank length
      IF @cLength = ''
      BEGIN
         SET @nErrNo = 55704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need length
         GOTO Fail
      END
      
      -- Check blank width
      IF @cWidth = ''
      BEGIN
         SET @nErrNo = 55705
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need width
         GOTO Fail
      END

      -- Check blank height
      IF @cHeight = ''
      BEGIN
         SET @nErrNo = 55706
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need height
         GOTO Fail
      END
            
      -- Check valid length
      IF rdt.rdtIsValidQTY( @cLength, 21) = 0
      BEGIN
         SET @nErrNo = 55707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid length
         GOTO Fail
      END

      -- Check valid width
      IF rdt.rdtIsValidQTY( @cWidth, 21) = 0
      BEGIN
         SET @nErrNo = 55708
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid width
         GOTO Fail
      END

      -- Check valid height
      IF rdt.rdtIsValidQTY( @cHeight, 21) = 0
      BEGIN
         SET @nErrNo = 55709
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid height
         GOTO Fail
      END
      
      -- Update
      UPDATE SKU SET
         Length = @cLength, 
         Width = @cWidth, 
         Height = @cHeight, 
         STDCube = CAST( @cLength AS FLOAT) * CAST( @cWidth AS FLOAT) * CAST( @cHeight AS FLOAT)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU

      IF @@ERROR <> 0
         GOTO Fail
   END
   
Fail:
   
END

GO