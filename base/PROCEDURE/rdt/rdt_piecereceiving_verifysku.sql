SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PieceReceiving_VerifySKU                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Verify SKU setting                                          */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-04-2013  1.0  Ung         SOS276703. Created                      */
/* 28-08-2014  1.1  James       SOS315958 - Bug fix on get null value   */
/*                              when update weight (james01)            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_PieceReceiving_VerifySKU]
   @nMobile    INT, 
   @nFucn      INT, 
   @cLangCode  NVARCHAR( 3), 
   @cStorerKey NVARCHAR( 15),  
   @cSKU       NVARCHAR( 20),  
   @cType      NVARCHAR( 10),  
   @cWeight    NVARCHAR( 10)    OUTPUT, 
   @cCube      NVARCHAR( 10)    OUTPUT, 
   @cLength    NVARCHAR( 10)    OUTPUT, 
   @cWidth     NVARCHAR( 10)    OUTPUT, 
   @cHeight    NVARCHAR( 10)    OUTPUT,  
   @cInnerPack NVARCHAR( 10)    OUTPUT, 
   @cCaseCount NVARCHAR( 10)    OUTPUT,  
   @cPalletCount NVARCHAR( 10)  OUTPUT, 
   @nErrNo     INT          OUTPUT, 
   @cErrMsg    NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPackKey        NVARCHAR( 10)
   DECLARE @fWeight         FLOAT
   DECLARE @fCube           FLOAT
   DECLARE @fLength         FLOAT
   DECLARE @fWidth          FLOAT
   DECLARE @fHeight         FLOAT
   DECLARE @fInnerPack      FLOAT
   DECLARE @fCaseCount      FLOAT
   DECLARE @fPalletCount    FLOAT

   DECLARE @cChkWeight      NVARCHAR( 1) 
   DECLARE @cChkCube        NVARCHAR( 1) 
   DECLARE @cChkLength      NVARCHAR( 1) 
   DECLARE @cChkWidth       NVARCHAR( 1) 
   DECLARE @cChkHeight      NVARCHAR( 1)  
   DECLARE @cChkInnerPack   NVARCHAR( 1) 
   DECLARE @cChkCaseCount   NVARCHAR( 1)  
   DECLARE @cChkPalletCount NVARCHAR( 1)
   DECLARE @cQty            NVARCHAR( 5)  
   DECLARE @cOutField12     NVARCHAR( 20)  

   SELECT @cOutField12 = O_Field12 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = sUser_sName()
   IF ISNULL( @cOutField12, '') <> ''
   BEGIN
      IF rdt.rdtIsValidQty( @cOutField12, 21) = 1
         SET @cQty = @cOutField12
   END

   -- Get SKU info
   SELECT
      @fWeight      = SKU.STDGrossWGT, 
      @fCube        = SKU.STDCube, 
      @fLength      = Pack.LengthUOM3, 
      @fWidth       = Pack.WidthUOM3,
      @fHeight      = Pack.HeightUOM3,  
      @fInnerPack   = Pack.InnerPack, 
      @fCaseCount   = Pack.CaseCnt,
      @fPalletCount = Pack.Pallet, 
      @cPackKey     = Pack.PackKey
   FROM dbo.SKU WITH (NOLOCK)
      JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Get check field setting
   SET @cChkWeight      = '' 
   SET @cChkCube        = '' 
   SET @cChkLength      = '' 
   SET @cChkWidth       = '' 
   SET @cChkHeight      = ''  
   SET @cChkInnerPack   = '' 
   SET @cChkCaseCount   = ''  
   SET @cChkPalletCount = ''
   
   SELECT @cChkWeight      = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Weight'
   SELECT @cChkCube        = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Cube'
   SELECT @cChkLength      = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Length'
   SELECT @cChkWidth       = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Width'
   SELECT @cChkHeight      = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Height'
   SELECT @cChkInnerPack   = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Inner'
   SELECT @cChkCaseCount   = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Case'
   SELECT @cChkPalletCount = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Pallet'
      
   -- Check SKU setting
   IF @cType = 'CHECK'
   BEGIN
      -- Return setting
      SET @cWeight      = CAST( @fWeight      AS NVARCHAR( 10))
      SET @cCube        = CAST( @fCube        AS NVARCHAR( 10))
      SET @cLength      = CAST( @fLength      AS NVARCHAR( 10))
      SET @cWidth       = CAST( @fWidth       AS NVARCHAR( 10))
      SET @cHeight      = CAST( @fHeight      AS NVARCHAR( 10))
      SET @cInnerPack   = CAST( @fInnerPack   AS NVARCHAR( 10))
      SET @cCaseCount   = CAST( @fCaseCount   AS NVARCHAR( 10))
      SET @cPalletCount = CAST( @fPalletCount AS NVARCHAR( 10))
      
      -- Check weight
      IF @cChkWeight = '1' AND @fWeight = 0
      BEGIN
         SET @nErrNo = 80951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Weight
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight
         GOTO Fail
      END

      -- Check cube
      IF @cChkCube = '1' AND @fCube = 0
      BEGIN
         SET @nErrNo = 80952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Cube
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Cube
         GOTO Fail
      END
      
      -- Check length
      IF @cChkLength = '1' AND @fLength = 0
      BEGIN
         SET @nErrNo = 80953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Length
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Length
         GOTO Fail
      END

      -- Check width
      IF @cChkWidth = '1' AND @fWidth = 0
      BEGIN
         SET @nErrNo = 80954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Width
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- Width
         GOTO Fail
      END

      -- Check Height
      IF @cChkHeight = '1' AND @fHeight = 0
      BEGIN
         SET @nErrNo = 80955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Height
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- Height
         GOTO Fail
      END

      -- Check inner
      IF @cChkInnerPack = '1' AND @fInnerPack = 0
      BEGIN
         SET @nErrNo = 80956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Inner
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- Inner
         GOTO Fail
      END

      -- Check case
      IF @cChkCaseCount = '1' AND @fCaseCount = 0
      BEGIN
         SET @nErrNo = 80957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Case
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- Case
         GOTO Fail
      END

      -- Check pallet
      IF @cChkPalletCount = '1' AND @fPalletCount = 0
      BEGIN
         SET @nErrNo = 80958
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Pallet
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- Pallet
         GOTO Fail
      END
   END

   -- Update SKU setting
   IF @cType = 'UPDATE'
   BEGIN
      -- Check weight
      IF @cChkWeight = '1' AND rdt.rdtIsValidQty( @cWeight, 21) = 0
      BEGIN
         SET @nErrNo = 80959
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Weight
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight
         GOTO Fail
      END
      
      -- Check cube
      IF @cChkCube = '1' AND rdt.rdtIsValidQty( @cCube, 21) = 0
      BEGIN
         SET @nErrNo = 80960
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Cube
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Cube
         GOTO Fail
      END
      
      -- Check length
      IF @cChkLength = '1' AND rdt.rdtIsValidQty( @cLength, 21) = 0
      BEGIN
         SET @nErrNo = 80961
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Length
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Length
         GOTO Fail
      END

      -- Check width
      IF @cChkWidth = '1' AND rdt.rdtIsValidQty( @cWidth, 21) = 0
      BEGIN
         SET @nErrNo = 80962
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Width
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- Width
         GOTO Fail
      END
      
      -- Check height
      IF @cChkHeight = '1' AND rdt.rdtIsValidQty( @cHeight, 21) = 0
      BEGIN
         SET @nErrNo = 80963
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Height
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- Height
         GOTO Fail
      END

      -- Check inner
      IF @cChkInnerPack = '1' AND rdt.rdtIsValidQty( @cInnerPack, 1) = 0
      BEGIN
         SET @nErrNo = 80964
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Inner
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- Inner
         GOTO Fail
      END

      -- Check case
      IF @cChkCaseCount = '1' AND rdt.rdtIsValidQty( @cCaseCount, 1) = 0
      BEGIN
         SET @nErrNo = 80965
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Case
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- Case
         GOTO Fail
      END
      
      -- Check pallet
      IF @cChkPalletCount = '1' AND rdt.rdtIsValidQty( @cPalletCount, 1) = 0
      BEGIN
         SET @nErrNo = 80966
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Pallet
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- Pallet
         GOTO Fail
      END
      
      -- Check update pack setting with inventory balance
      IF (@cChkInnerPack   = '1' AND @cInnerPack   <> @fInnerPack) OR
         (@cChkCaseCount   = '1' AND @cCaseCount   <> @fCaseCount) OR
         (@cChkPalletCount = '1' AND @cPalletCount <> @fPalletCount)
      BEGIN
         IF EXISTS( SELECT TOP 1 1 FROM dbo.SKUxLOC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND QTY > 0)
         BEGIN
            SET @nErrNo = 80967
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoChg,HvInvBal
            GOTO Fail
         END
      END

      -- Update SKU setting (james01)
      UPDATE dbo.SKU SET
         STDGrossWGT = CASE WHEN @cChkWeight = '1' THEN 
                            CASE WHEN ISNULL( @cQty, '') <> '' THEN CAST( @cWeight AS FLOAT)/ CAST( @cQty AS INT) ELSE @cWeight END ELSE STDGrossWGT END, 
         STDCube     = CASE WHEN @cChkCube   = '1' THEN @cCube   ELSE STDCube     END
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 80968
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SKU Fail
         GOTO Fail
      END

      -- Update Pack setting
      UPDATE dbo.Pack SET
         LengthUOM3 = CASE WHEN @cChkLength      = '1' THEN @cLength      ELSE LengthUOM3 END, 
         WidthUOM3  = CASE WHEN @cChkWidth       = '1' THEN @cWidth       ELSE WidthUOM3  END, 
         HeightUOM3 = CASE WHEN @cChkHeight      = '1' THEN @cHeight      ELSE HeightUOM3 END, 
         InnerPack  = CASE WHEN @cChkInnerPack   = '1' THEN @cInnerPack   ELSE InnerPack  END, 
         CaseCNT    = CASE WHEN @cChkCaseCount   = '1' THEN @cCaseCount   ELSE CaseCNT    END, 
         Pallet     = CASE WHEN @cChkPalletCount = '1' THEN @cPalletCount ELSE Pallet     END  
      WHERE PackKey = @cPackKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 80969
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Pack Fail
         GOTO Fail
      END
   END
   
Fail:

END -- End Procedure


GO