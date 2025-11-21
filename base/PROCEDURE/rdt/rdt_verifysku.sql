SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_VerifySKU                                       */
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
/* Date        Rev  Author       Purposes                               */
/* 30-04-2013  1.0  Ung          SOS317798. Created                     */
/* 08-09-2014  1.1  Ung          SOS320350                              */
/*                               Add VerifySKUExtValSP                  */
/*                               Add VerifySKUExtUpdSP                  */
/*                               Add Enable / disable fields            */
/* 16-01-2015  1.2  Ung          SOS326375 Fix float out of range       */
/* 18-11-2019  1.3  Ung          WMS-10643 Add function ID              */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_VerifySKU]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @cType            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10) OUTPUT,
   @cCube            NVARCHAR( 10) OUTPUT,
   @cLength          NVARCHAR( 10) OUTPUT,
   @cWidth           NVARCHAR( 10) OUTPUT,
   @cHeight          NVARCHAR( 10) OUTPUT,
   @cInnerPack       NVARCHAR( 10) OUTPUT,
   @cCaseCount       NVARCHAR( 10) OUTPUT,
   @cPalletCount     NVARCHAR( 10) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT, 
   @cVerifySKUInfo   NVARCHAR( 20) = '' OUTPUT
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
   DECLARE @cPackUOM2       NVARCHAR( 10)
   DECLARE @cPackUOM1       NVARCHAR( 10)
   DECLARE @cPackUOM4       NVARCHAR( 10)

   DECLARE @cChkInfo        NVARCHAR( 1)
   DECLARE @cChkWeight      NVARCHAR( 1)
   DECLARE @cChkCube        NVARCHAR( 1)
   DECLARE @cChkLength      NVARCHAR( 1)
   DECLARE @cChkWidth       NVARCHAR( 1)
   DECLARE @cChkHeight      NVARCHAR( 1)
   DECLARE @cChkInnerPack   NVARCHAR( 1)
   DECLARE @cChkCaseCount   NVARCHAR( 1)
   DECLARE @cChkPalletCount NVARCHAR( 1)

   DECLARE @cInnerUDF01     NVARCHAR( 10)
   DECLARE @cCaseUDF01      NVARCHAR( 10)
   DECLARE @cPalletUDF01    NVARCHAR( 10)

   DECLARE @cSQL            NVARCHAR(MAX)
   DECLARE @cSQLParam       NVARCHAR(MAX)

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
      @cPackKey     = Pack.PackKey, 
      @cPackUOM2    = Pack.PackUOM2, 
      @cPackUOM1    = Pack.PackUOM1, 
      @cPackUOM4    = Pack.PackUOM4  
   FROM dbo.SKU WITH (NOLOCK)
      JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   SET @cVerifySKUInfo = ISNULL( @cVerifySKUInfo, '')

   -- Get check field setting
   SET @cChkWeight      = ''
   SET @cChkCube        = ''
   SET @cChkLength      = ''
   SET @cChkWidth       = ''
   SET @cChkHeight      = ''
   SET @cChkInnerPack   = ''
   SET @cChkCaseCount   = ''
   SET @cChkPalletCount = ''
   SET @cChkInfo        = ''

   SELECT TOP 1 @cChkInfo        = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Info'   AND Code2 IN ('', @nFunc) ORDER BY Code2 DESC
   SELECT TOP 1 @cChkWeight      = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Weight' AND Code2 IN ('', @nFunc) ORDER BY Code2 DESC
   SELECT TOP 1 @cChkCube        = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Cube'   AND Code2 IN ('', @nFunc) ORDER BY Code2 DESC
   SELECT TOP 1 @cChkLength      = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Length' AND Code2 IN ('', @nFunc) ORDER BY Code2 DESC
   SELECT TOP 1 @cChkWidth       = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Width'  AND Code2 IN ('', @nFunc) ORDER BY Code2 DESC
   SELECT TOP 1 @cChkHeight      = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Height' AND Code2 IN ('', @nFunc) ORDER BY Code2 DESC
   SELECT TOP 1 @cChkInnerPack   = Short, @cInnerUDF01  = UDF01 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Inner'  AND Code2 IN ('', @nFunc) ORDER BY Code2 DESC
   SELECT TOP 1 @cChkCaseCount   = Short, @cCaseUDF01   = UDF01 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Case'   AND Code2 IN ('', @nFunc) ORDER BY Code2 DESC
   SELECT TOP 1 @cChkPalletCount = Short, @cPalletUDF01 = UDF01 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Pallet' AND Code2 IN ('', @nFunc) ORDER BY Code2 DESC

   -- Check SKU setting
   IF @cType = 'CHECK'
   BEGIN
      -- Return setting
      SET @cWeight      = rdt.rdtFormatFloat( @fWeight)
      SET @cCube        = rdt.rdtFormatFloat( @fCube)
      SET @cLength      = rdt.rdtFormatFloat( @fLength)
      SET @cWidth       = rdt.rdtFormatFloat( @fWidth)
      SET @cHeight      = rdt.rdtFormatFloat( @fHeight)
      SET @cInnerPack   = rdt.rdtFormatFloat( @fInnerPack)
      SET @cCaseCount   = rdt.rdtFormatFloat( @fCaseCount)
      SET @cPalletCount = rdt.rdtFormatFloat( @fPalletCount)

/*
      -- Check info
      IF @cChkInfo = '1' AND @cVerifySKUInfo = ''
      BEGIN
         SET @nErrNo = 80970
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU Info
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- VerifySKUInfo
         GOTO Fail
      END
*/
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

      DECLARE @cVerifySKUExtValSP NVARCHAR(20)
      SET @cVerifySKUExtValSP = rdt.RDTGetConfig( @nFunc, 'VerifySKUExtValSP', @cStorerKey)
      IF @cVerifySKUExtValSP = '0'
         SET @cVerifySKUExtValSP = ''

      -- Extended validate
      IF @cVerifySKUExtValSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cVerifySKUExtValSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cVerifySKUExtValSP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cSKU, @cType, ' +
               ' @cVerifySKUInfo, @cWeight, @cCube, @cLength, @cWidth, @cHeight, @cInnerPack, @cCaseCount, @cPalletCount, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,                  ' +
               '@nFunc           INT,                  ' +
               '@cLangCode       NVARCHAR( 3),         ' +
               '@cStorerKey      NVARCHAR( 15),        ' +
               '@cSKU            NVARCHAR( 20),        ' +
               '@cType           NVARCHAR( 10),        ' +
               '@cVerifySKUInfo  NVARCHAR( 20) OUTPUT, ' +
               '@cWeight         NVARCHAR( 10) OUTPUT, ' +
               '@cCube           NVARCHAR( 10) OUTPUT, ' +
               '@cLength         NVARCHAR( 10) OUTPUT, ' +
               '@cWidth          NVARCHAR( 10) OUTPUT, ' +
               '@cHeight         NVARCHAR( 10) OUTPUT, ' +
               '@cInnerPack      NVARCHAR( 10) OUTPUT, ' +
               '@cCaseCount      NVARCHAR( 10) OUTPUT, ' +
               '@cPalletCount    NVARCHAR( 10) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cStorerKey, @cSKU, @cType,
               @cVerifySKUInfo, @cWeight, @cCube, @cLength, @cWidth, @cHeight, @cInnerPack, @cCaseCount, @cPalletCount, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Fail
         END
      END
   END

   -- Update SKU setting
   IF @cType = 'UPDATE'
   BEGIN
/*
      -- Check info
      IF @cChkInfo = '1' AND @cVerifySKUInfo = ''
      BEGIN
         SET @nErrNo = 80971
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU Info
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- VerifySKUInfo
         GOTO Fail
      END
*/
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
      IF @cChkInnerPack = '1' AND rdt.rdtIsValidQty( @cInnerPack, 1) = 0 -- not check for zero
      BEGIN
         SET @nErrNo = 80964
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Inner
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- Inner
         GOTO Fail
      END

      -- Check case
      IF @cChkCaseCount = '1' AND rdt.rdtIsValidQty( @cCaseCount, 1) = 0 -- not check for zero
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

      -- Update SKU setting
      UPDATE dbo.SKU SET
         STDGrossWGT = CASE WHEN @cChkWeight = '1' THEN @cWeight ELSE STDGrossWGT END,
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
         Pallet     = CASE WHEN @cChkPalletCount = '1' THEN @cPalletCount ELSE Pallet     END, 
         PackUOM2   = CASE WHEN @cChkInnerPack   = '1' AND @cPackUOM2 = '' THEN @cInnerUDF01  ELSE @cPackUOM2 END,
         PackUOM1   = CASE WHEN @cChkCaseCount   = '1' AND @cPackUOM1 = '' THEN @cCaseUDF01   ELSE @cPackUOM1 END,
         PackUOM4   = CASE WHEN @cChkPalletCount = '1' AND @cPackUOM4 = '' THEN @cPalletUDF01 ELSE @cPackUOM4 END
      WHERE PackKey = @cPackKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 80969
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Pack Fail
         GOTO Fail
      END

      DECLARE @cVerifySKUExtUpdSP NVARCHAR(20)
      SET @cVerifySKUExtUpdSP = rdt.RDTGetConfig( @nFunc, 'VerifySKUExtUpdSP', @cStorerKey)
      IF @cVerifySKUExtUpdSP = '0'
         SET @cVerifySKUExtUpdSP = ''

      -- Extended validate
      IF @cVerifySKUExtValSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cVerifySKUExtUpdSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cVerifySKUExtUpdSP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cSKU, @cType, ' +
               ' @cVerifySKUInfo, @cWeight, @cCube, @cLength, @cWidth, @cHeight, @cInnerPack, @cCaseCount, @cPalletCount, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,                  ' +
               '@nFunc           INT,                  ' +
               '@cLangCode       NVARCHAR( 3),         ' +
               '@cStorerKey      NVARCHAR( 15),        ' +
               '@cSKU            NVARCHAR( 20),        ' +
               '@cType           NVARCHAR( 10),        ' +
               '@cVerifySKUInfo  NVARCHAR( 20) OUTPUT, ' +
               '@cWeight         NVARCHAR( 10) OUTPUT, ' +
               '@cCube           NVARCHAR( 10) OUTPUT, ' +
               '@cLength         NVARCHAR( 10) OUTPUT, ' +
               '@cWidth          NVARCHAR( 10) OUTPUT, ' +
               '@cHeight         NVARCHAR( 10) OUTPUT, ' +
               '@cInnerPack      NVARCHAR( 10) OUTPUT, ' +
               '@cCaseCount      NVARCHAR( 10) OUTPUT, ' +
               '@cPalletCount    NVARCHAR( 10) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cStorerKey, @cSKU, @cType,
               @cVerifySKUInfo, @cWeight, @cCube, @cLength, @cWidth, @cHeight, @cInnerPack, @cCaseCount, @cPalletCount, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Fail
         END
      END


   END

Fail:

END -- End Procedure


GO