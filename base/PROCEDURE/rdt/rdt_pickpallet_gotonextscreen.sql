SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PickPallet_GoToNextScreen                       */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Get task, go to next screen                                 */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-05-2023  1.0  Ung         WMS-22370 Created                       */
/* 28-05-2024  1.1  Ung         UWP-19424 Fix suggested ID sequence     */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_PickPallet_GoToNextScreen
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   -- @nStep            INT, -- moved towards end for output
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15),  
   @cPUOM            NVARCHAR( 10),
   @cPickSlipNo      NVARCHAR( 10),
   @cPickZone        NVARCHAR( 10),
   @cLOC             NVARCHAR( 10), 
   @cID              NVARCHAR( 18) OUTPUT, 
   @cSuggLOC         NVARCHAR( 10) OUTPUT, 
   @cSuggID          NVARCHAR( 18) OUTPUT, 
   @cSKU             NVARCHAR( 20) OUTPUT,  
   @nTaskQTY         INT           OUTPUT,
   @nPTaskQTY        INT           OUTPUT, 
   @nMTaskQTY        INT           OUTPUT, 
   @cLottableCode    NVARCHAR( 30) OUTPUT, 
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @cSKUDescr        NVARCHAR( 60) OUTPUT, 
   @cMUOM_Desc       NVARCHAR( 5)  OUTPUT, 
   @cPUOM_Desc       NVARCHAR( 5)  OUTPUT, 
   @nPUOM_Div        INT           OUTPUT, 
   @nStep            INT           OUTPUT,
   @nScn             INT           OUTPUT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nMorePage INT
   DECLARE @cSuggestLOC NVARCHAR(1)

   -- Screen constant
   DECLARE
      @nStep_PickSlipNo       INT,  @nScn_PickSlipNo     INT,
      @nStep_LOC              INT,  @nScn_LOC            INT,
      @nStep_ID               INT,  @nScn_ID             INT,
      @nStep_SkipTask         INT,  @nScn_SkipTask       INT,
      @nStep_ToLOC            INT,  @nScn_ToLOC          INT

   SELECT
      @nStep_PickSlipNo       = 1,  @nScn_PickSlipNo     = 6260,
      @nStep_LOC              = 2,  @nScn_LOC            = 6261,
      @nStep_ID               = 3,  @nScn_ID             = 6262,
      @nStep_SkipTask         = 4,  @nScn_SkipTask       = 6263,
      @nStep_ToLOC            = 5,  @nScn_ToLOC          = 6264
   
   -- Get task in same LOC
   EXEC rdt.rdt_PickPallet_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPUOM, 4, @cPickSlipNo, @cPickZone, @cLOC, @cID, 
      @cSuggID      OUTPUT, @cSKU         OUTPUT, @nTaskQTY     OUTPUT,
      @cLottable01  OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT,
      @cLottable06  OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT,
      @cLottable11  OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT,
      @cLottableCode OUTPUT,
      @cSKUDescr    OUTPUT,
      @cMUOM_Desc   OUTPUT,
      @cPUOM_Desc   OUTPUT,
      @nPUOM_Div    OUTPUT,
      @nErrNo       OUTPUT,
      @cErrMsg      OUTPUT
   IF @nErrNo <> 0 AND
      @nErrNo <> -1
      GOTO Quit
   
   -- Goto ID screen
   IF @nErrNo = 0
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPTaskQTY = 0
         SET @nMTaskQTY = @nTaskQTY
      END
      ELSE
      BEGIN
         SET @nPTaskQTY = @nTaskQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMTaskQTY = @nTaskQTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cSuggID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))
      SET @cOutField10 = @cPUOM_Desc
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CASE WHEN @nPTaskQTY = 0 THEN '' ELSE CAST( @nPTaskQTY AS NVARCHAR( 5)) END
      SET @cOutField13 = CAST( @nMTaskQTY AS NVARCHAR( 5))
      SET @cOutField14 = '' -- ID
      SET @cOutField15 = '' -- ExtendedInfo

      -- Goto ID screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
      GOTO Quit
   END

   -- Get storer configure
   SET @cSuggestLOC = rdt.RDTGetConfig( @nFunc, 'SuggestLOC', @cStorerKey)

   -- Not suggest next LOC
   IF @cSuggestLOC = '0'
   BEGIN
      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = CASE WHEN @cSuggestLOC = '1' THEN @cSuggLOC ELSE '' END
      SET @cOutField04 = '' -- LOC

      -- Go to LOC screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
      GOTO Quit
   END

   -- Get next LOC
   SET @nErrNo = 0
   SET @cErrMsg = ''
   EXEC rdt.rdt_PickPallet_SuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
      @cPickSlipNo,
      @cPickZone, 
      @cLOC,
      @cSuggLOC OUTPUT,
      @nErrNo   OUTPUT,
      @cErrMsg  OUTPUT
   IF @nErrNo <> 0 AND
      @nErrNo <> -1
      GOTO Quit
   
   -- Go to LOC screen
   IF @nErrNo = 0
   BEGIN
      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = CASE WHEN @cSuggestLOC = '1' THEN @cSuggLOC ELSE '' END
      SET @cOutField04 = '' -- LOC

      -- Go to LOC screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
      GOTO Quit
   END
   
   -- Search from begining
   SET @nErrNo = 0
   SET @cErrMsg = ''
   EXEC rdt.rdt_PickPallet_SuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
      @cPickSlipNo, 
      @cPickZone, 
      '', -- @cLOC, 
      @cSuggLOC OUTPUT, 
      @nErrNo   OUTPUT, 
      @cErrMsg  OUTPUT
   IF @nErrNo <> 0 AND
      @nErrNo <> -1
      GOTO Quit

   -- Go to LOC screen
   IF @nErrNo = 0
   BEGIN
      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = CASE WHEN @cSuggestLOC = '1' THEN @cSuggLOC ELSE '' END
      SET @cOutField04 = '' -- LOC

      -- Go to LOC screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
      GOTO Quit
   END
   
   -- Goto pick slip screen
   IF @nErrNo = -1
   BEGIN
      -- Prepare LOC screen var
      SET @cOutField01 = '' -- PickSlipNo

      -- Go to LOC screen
      SET @nScn = @nScn_PickSlipNo
      SET @nStep = @nStep_PickSlipNo

      -- Scan out        
      SET @nErrNo = 0        
      EXEC rdt.rdt_PickPallet_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey        
         ,@cPickSlipNo        
         ,@nErrNo       OUTPUT        
         ,@cErrMsg      OUTPUT        
      IF @nErrNo <> 0        
         GOTO Quit  
         
      GOTO Quit
   END

Quit:

END

GO