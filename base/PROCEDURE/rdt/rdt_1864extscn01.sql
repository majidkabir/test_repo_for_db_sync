SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1864ExtScn01                                    */  
/*                                                                      */  
/* Purpose:       Peru - Hicense - Short Pick New Screen                */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-08-26 1.0  LJQ006     FCR-735 init                              */  
/************************************************************************/  
  
CREATE   PROC  [RDT].[rdt_1864ExtScn01] (
   @nMobile          INT,           
   @nFunc            INT,           
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,           
   @nScn             INT,           
   @nInputKey        INT,           
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15), 
   @tExtScnData     VariableTable READONLY,
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
   @nAction          INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
   @nAfterScn        INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cOption        NVARCHAR( 1)

   DECLARE
      @cShortOption    NVARCHAR( 1),
      @cID             NVARCHAR( 18),
      @cPickSlipNo     NVARCHAR( 10),
      @cPickZone       NVARCHAR( 10),
      @cLOC            NVARCHAR( 10),
      @nTaskQTY        INT,
      @nPTaskQTY       INT,
      @nMTaskQTY       INT,
      @cLottableCode   NVARCHAR( 20),
      @cSKUDescr       NVARCHAR( 60),
      @cMUOM_Desc      NVARCHAR( 5),
      @cPUOM_Desc      NVARCHAR( 5),
      @nPUOM_Div       INT,
      @cPUOM           NVARCHAR( 1),
      @cSuggLOC        NVARCHAR( 10),
      @cSuggID         NVARCHAR( 18),
      @cSKU            NVARCHAR( 20),
      @cPickConfirmStatus NVARCHAR( 1)
   
   SELECT
   @nScn             = Scn,
   @nStep            = Step
   FROM rdt.RDTMOBREC
   WHERE Mobile = @nMobile

   SELECT @cPickSlipNo     = Value FROM @tExtScnData WHERE Variable = '@cPickSlipNo'
   SELECT @cLOC            = Value FROM @tExtScnData WHERE Variable = '@cLOC'
   SELECT @nTaskQTY        = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nTaskQTY'
   SELECT @nPTaskQTY       = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nPTaskQTY'
   SELECT @nMTaskQTY       = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nMTaskQTY'
   SELECT @cLottableCode   = Value FROM @tExtScnData WHERE Variable = '@cLottableCode'
   SELECT @cSKUDescr       = Value FROM @tExtScnData WHERE Variable = '@cSKUDescr'
   SELECT @cMUOM_Desc      = Value FROM @tExtScnData WHERE Variable = '@cMUOM_Desc'
   SELECT @cPUOM_Desc      = Value FROM @tExtScnData WHERE Variable = '@cPUOM_Desc'
   SELECT @nPUOM_Div       = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nPUOM_Div'
   SELECT @cPickZone       = Value FROM @tExtScnData WHERE Variable = '@cPickZone'
   SELECT @cPUOM           = Value FROM @tExtScnData WHERE Variable = '@cPUOM'
   SELECT @cSuggLOC        = Value FROM @tExtScnData WHERE Variable = '@cSuggLOC'
   SELECT @cSuggID         = Value FROM @tExtScnData WHERE Variable = '@cSuggID'
   SELECT @cSKU            = Value FROM @tExtScnData WHERE Variable = '@cSKU'

   SET @cShortOption = ISNULL(rdt.RDTGetConfig( @nFunc, 'ShortOption', @cStorerKey), '')
   IF @cShortOption = '0'
      SET @cShortOption = ''
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   DECLARE
      @nStep_ID      INT,
      @nScn_ID       INT,
      @nStep_ExtScn  INT, 
      @nScn_ExtScn   INT,
      @nStep_SkipTask INT,
      @nScn_SkipTask INT  

   SELECT
   @nStep_ID               = 3,  @nScn_ID             = 6262,
   @nStep_SkipTask         = 4,  @nScn_SkipTask       = 6263,
   @nStep_ExtScn           = 99, @nScn_ExtScn         = 6419

   IF @nFunc = 1864
   BEGIN
      IF @nStep = 3
      BEGIN
         IF @nAction = 0
         BEGIN
            -- When entered with an empty id
            IF @nInputKey = 1
            BEGIN
               IF @cShortOption = '1'
               BEGIN
                  -- Go to extend screen process
                  SET @nAfterStep = @nStep_ExtScn
                  SET @nAfterScn = @nScn_ExtScn
                  GOTO Quit
               END
               ELSE
               BEGIN
                  GOTO Quit
               END
            END
         END
      END
      ELSE IF @nStep = 99
      BEGIN
         IF @nScn = 6419
         BEGIN
            IF @nInputKey = 0 -- ESC
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cSuggID
               SET @cOutField02 = @cSKU
               SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
               SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
               SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))
               SET @cOutField10 = @cPUOM_Desc
               SET @cOutField11 = @cMUOM_Desc
               SET @cOutField12 = CASE WHEN @nPTaskQTY = 0 THEN '' ELSE CAST( @nPTaskQTY AS NVARCHAR( 5)) END
               SET @cOutField13 = CAST( @nMTaskQTY AS NVARCHAR( 5))
               SET @cOutField14 = '' -- ID
               SET @cOutField15 = '' -- ExtendedInfo
               -- Back to ID screen
               SET @nAfterScn = @nScn_ID
               SET @nAfterStep = @nStep_ID
               GOTO Quit
            END  
            -- if press enter
            ELSE IF @nInputKey = 1
            BEGIN
               SET @cID = @cSuggID
               -- screen mapping
               SET @cOption = @cInField01
               -- Validate blank
               IF @cOption = ''
               BEGIN
                  SET @nErrNo = 222801
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need option
                  GOTO Short_Option_Fail
               END

               -- Validate option
               IF @cOption NOT IN ('1', '2')
               BEGIN
                  SET @nErrNo = 222802
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
                  GOTO Short_Option_Fail
               END

               -- Short Pick
               IF @cOption = '1'
               BEGIN
               
                  BEGIN TRY
                  -- Confirm PickDetail
                  UPDATE pd SET
                     pd.Status = 4,
                     pd.EditDate = GETDATE(),
                     pd.EditWho  = SUSER_SNAME()
                  FROM dbo.PICKDETAIL pd WITH(NOLOCK)
                  INNER JOIN dbo.PickHeader ph WITH(NOLOCK) ON ph.OrderKey = pd.OrderKey
                  INNER JOIN dbo.LOC loc WITH(NOLOCK) ON pd.Loc = loc.Loc
                  WHERE pd.Status <> 4
                  AND ph.PickHeaderKey = @cPickSlipNo
                  AND pd.ID = @cID
                  AND pd.Loc = @cLoc
                  AND pd.Status < @cPickConfirmStatus
                  END TRY
                  BEGIN CATCH
                     SET @nErrNo = 222807
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                     GOTO Quit
                  END CATCH

                  -- Go to next screen
                  EXEC rdt.rdt_PickPallet_GoToNextScreen @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, 
                     @cPUOM, @cPickSlipNo, @cPickZone, @cLOC, @cID, 
                     @cSuggLOC   OUTPUT,  @cSuggID     OUTPUT,  @cSKU         OUTPUT,    
                     @nTaskQTY   OUTPUT,  @nPTaskQTY   OUTPUT,  @nMTaskQTY    OUTPUT,  @cLottableCode OUTPUT,
                     @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01   OUTPUT,
                     @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02   OUTPUT,
                     @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03   OUTPUT,
                     @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04   OUTPUT,
                     @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05   OUTPUT,
                     @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06   OUTPUT,
                     @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07   OUTPUT,
                     @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08   OUTPUT,
                     @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09   OUTPUT,
                     @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10   OUTPUT,
                     @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11   OUTPUT,
                     @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12   OUTPUT,
                     @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13   OUTPUT,
                     @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14   OUTPUT,
                     @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15   OUTPUT,
                     @cSKUDescr  OUTPUT,  @cMUOM_Desc  OUTPUT,  @cPUOM_Desc   OUTPUT,  @nPUOM_Div     OUTPUT,
                     @nStep      OUTPUT,  @nScn        OUTPUT,  @nErrNo       OUTPUT,  @cErrMsg       OUTPUT

                  SET @nAfterScn = @nScn
                  SET @nAfterStep = @nStep
                  GOTO Quit
               END
               -- Skip Task
               IF @cOption = '2'
               BEGIN
                  -- skip task here
                  -- Go to next screen
                  EXEC rdt.rdt_PickPallet_GoToNextScreen @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, 
                     @cPUOM, @cPickSlipNo, @cPickZone, @cLOC, @cID, 
                     @cSuggLOC   OUTPUT,  @cSuggID     OUTPUT,  @cSKU         OUTPUT,    
                     @nTaskQTY   OUTPUT,  @nPTaskQTY   OUTPUT,  @nMTaskQTY    OUTPUT,  @cLottableCode OUTPUT,
                     @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01   OUTPUT,
                     @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02   OUTPUT,
                     @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03   OUTPUT,
                     @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04   OUTPUT,
                     @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05   OUTPUT,
                     @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06   OUTPUT,
                     @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07   OUTPUT,
                     @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08   OUTPUT,
                     @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09   OUTPUT,
                     @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10   OUTPUT,
                     @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11   OUTPUT,
                     @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12   OUTPUT,
                     @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13   OUTPUT,
                     @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14   OUTPUT,
                     @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15   OUTPUT,
                     @cSKUDescr  OUTPUT,  @cMUOM_Desc  OUTPUT,  @cPUOM_Desc   OUTPUT,  @nPUOM_Div     OUTPUT,
                     @nStep      OUTPUT,  @nScn        OUTPUT,  @nErrNo       OUTPUT,  @cErrMsg       OUTPUT

                  SET @nAfterScn = @nScn
                  SET @nAfterStep = @nStep

                  GOTO Quit
               END
            END
         END
      END
   END
END

Short_Option_Fail:
BEGIN
   SET @cOutField01 = '' -- Option
   GOTO Quit
END

Quit:

GO