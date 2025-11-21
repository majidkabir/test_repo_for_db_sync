SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_MultiSKUExtLOT                               */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Prompt multi SKU that share same barcode for selection      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 23-Mar-2023 1.0  yeekung   WMS-21873 Created                         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_MultiSKUExtLOT]
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @cInField01 NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,
   @cInField02 NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,
   @cInField03 NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,
   @cInField04 NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,
   @cInField05 NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,
   @cInField06 NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,
   @cInField07 NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,
   @cInField08 NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,
   @cInField09 NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,
   @cInField10 NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,
   @cInField11 NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,
   @cInField12 NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,
   @cInField13 NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,
   @cInField14 NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,
   @cInField15 NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,
   @cType      NVARCHAR( 10),
   @cMasterLOT NVARCHAR( 60),
   @cStorerKey NVARCHAR( 15) OUTPUT,
   @cSKU       NVARCHAR( 20) OUTPUT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCurrentSKU NVARCHAR(20)
   DECLARE @cCurrentStorer NVARCHAR(15)
   SET @cCurrentStorer = ''
   SET @cCurrentSKU = ''

   /*-------------------------------------------------------------------------------

                                  Validate option

   -------------------------------------------------------------------------------*/
   IF @cType = 'CHECK'
   BEGIN
      DECLARE @cStorer1 NVARCHAR(15)
      DECLARE @cStorer2 NVARCHAR(15)
      DECLARE @cSKU1    NVARCHAR(20)
      DECLARE @cSKU2    NVARCHAR(20)
      DECLARE @cOption  NVARCHAR(2)

      -- Screen mapping
      SET @cStorer1 = @cOutField01
      SET @cSKU1    = @cOutField02
      SET @cStorer2 = @cOutField06
      SET @cSKU2    = @cOutField07
      SET @cOption  = @cInField13

      -- Check invalid option
      IF @cOption NOT IN ('1', '2', '')
      BEGIN
         SET @nErrNo = 198451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Fail
      END

      -- Check option 1
      IF @cOption = '1'
      BEGIN
         IF @cSKU1 = ''
         BEGIN
            SET @nErrNo = 198452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU1 blank
            GOTO Fail
         END
         SET @cStorerKey = @cStorer1
         SET @cSKU = @cSKU1
         GOTO Quit
      END

      -- Check option 2
      IF @cOption = '2'
      BEGIN
         IF @cSKU2 = ''
         BEGIN
            SET @nErrNo = 198453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU2 blank
            GOTO Fail
         END
         SET @cStorerKey = @cStorer2
         SET @cSKU = @cSKU2
         GOTO Quit
      END

      -- Check option ENTER
      IF @cOption = ''
      BEGIN
         -- Check no more record
         IF @cSKU2 = ''
         BEGIN
            SET @nErrNo = 198455
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more SKU
            GOTO Fail
         END

         -- Get last SKU on screen
         SET @cCurrentSKU = LEFT( @cSKU2 + SPACE(20), 20)
         SET @cCurrentStorer = LEFT( @cStorer2 + SPACE(15), 20)

         SET @nErrNo = -1 -- Stay in MultiSKU screen
      END
   END


   /*-------------------------------------------------------------------------------

                                  Populate screen

   -------------------------------------------------------------------------------*/
   DECLARE @cStorerCode NVARCHAR(15)
   DECLARE @cSKUCode    NVARCHAR(20)
   DECLARE @cSKUDesc1   NVARCHAR(20)
   DECLARE @cSKUDesc2   NVARCHAR(20)
   DECLARE @cSKUDesc3   NVARCHAR(20)
   DECLARE @nCount      INT
   DECLARE @cStorerKeyInDoc NVARCHAR(20)
   DECLARE @cSKUInDoc   NVARCHAR(20)
   DECLARE @cZone       NVARCHAR(18)
   DECLARE @cStatus     NVARCHAR(1)
   DECLARE @cBusr10     NVARCHAR(20)  --(cc01)

   DECLARE @cPH_OrderKey   NVARCHAR( 10)
   DECLARE @cPH_LoadKey    NVARCHAR( 10)
   DECLARE @nRowCount   INT

   SET @nCount = 1

   DECLARE @curSKU CURSOR
   SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT StorerKey, SKU
      FROM LotAttribute WITH (NOLOCK)
      WHERE lottable07 = @cMasterLOT
         AND StorerKey = @cStorerKey
         AND SKU > @cCurrentSKU
      ORDER BY SKU
   OPEN @curSKU
   FETCH NEXT FROM @curSKU INTO @cStorerCode, @cSKUCode
   WHILE @nCount < 3
   BEGIN
      -- Get SKU info
      IF @@FETCH_STATUS = 0
         SELECT
            @cSKUDesc1 = SUBSTRING( Descr , 1, 20),
            @cSKUDesc2 = SUBSTRING( Descr , 21, 20),
            @cSKUDesc3 = SUBSTRING( Descr , 41, 20),
            @cBusr10 =  SUBSTRING( Busr10 , 1, 20)
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerCode
            AND SKU = @cSKUCode

      IF @nCount = 1
      BEGIN
         SET @cOutField01 = CASE WHEN @@FETCH_STATUS = 0 THEN @cStorerCode ELSE '' END
         SET @cOutField02 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUCode    ELSE '' END
         SET @cOutField03 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc1   ELSE '' END
         SET @cOutField04 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc2   ELSE '' END
         SET @cOutField05 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc3   ELSE '' END
         SET @cOutField11 = CASE WHEN @@FETCH_STATUS = 0 THEN @cBusr10     ELSE '' END
      END
      IF @nCount = 2
      BEGIN
         SET @cOutField06 = CASE WHEN @@FETCH_STATUS = 0 THEN @cStorerCode ELSE '' END
         SET @cOutField07 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUCode    ELSE '' END
         SET @cOutField08 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc1   ELSE '' END
         SET @cOutField09 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc2   ELSE '' END
         SET @cOutField10 = CASE WHEN @@FETCH_STATUS = 0 THEN @cSKUDesc3   ELSE '' END
         SET @cOutField12 = CASE WHEN @@FETCH_STATUS = 0 THEN @cBusr10     ELSE '' END
      END
      SET @nCount = @nCount + 1
      FETCH NEXT FROM @curSKU INTO @cStorerCode, @cSKUCode
   END

   SET @cOutField13 = ''   -- Option

   -- Check no more record
   IF @nCount = 1
   BEGIN
      SET @nErrNo = 198456
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more record
      GOTO Fail
   END

Fail:
Quit:
END -- End Procedure


GO