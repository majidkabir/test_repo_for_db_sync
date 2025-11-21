SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PutawayByDropID                              */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Putaway by Drop ID                                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2023-10-13 1.0  Ung      WMS-23390 Created                           */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PutawayByDropID] (
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @nTranCount          INT, 
   @bSuccess            INT, 
   @cSQL                NVARCHAR( MAX), 
   @cSQLParam           NVARCHAR( MAX)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerGroup        NVARCHAR( 20),
   @cFacility           NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10),
   @cUserName           NVARCHAR( 18),

   @cStorerKey          NVARCHAR( 15),
   @cDropID             NVARCHAR( 20), 
   
   @cSuggLOC            NVARCHAR( 10), 
   @cPickAndDropLOC     NVARCHAR( 10), 
   @cToLOC              NVARCHAR( 10), 
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @nPABookingKey       INT, 
   @cDefaultToLOC       NVARCHAR( 1), 
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cLOCLookupSP        NVARCHAR( 20),
   @cPAMatchSuggestLOC  NVARCHAR( 1), 
   @cOption             NVARCHAR( 1),

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)

-- Load RDT.RDTMobRec
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerGroup     = StorerGroup, 
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,

   @cStorerKey       = V_StorerKey,
   @cDropID          = V_DropID,

   @cSuggLOC            = V_String1,
   @cPickAndDropLOC     = V_String2,
   @cToLOC              = V_String3,
   @cExtendedValidateSP = V_String4,
   @cExtendedUpdateSP   = V_String5,
   @cExtendedInfoSP     = V_String6,
   @cExtendedInfo       = V_String7,
   @cDefaultToLOC       = V_String9, 
   @cDecodeSP           = V_String10,
   @cLOCLookupSP        = V_String18,
   @cPAMatchSuggestLOC  = V_String19,

   @nPABookingKey       = V_Integer1,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1742
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1742
   IF @nStep = 1 GOTO Step_1   -- Scn = 6300. From ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 6301. Suggest LOC, TO LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 6302. Loc not match. Proceed?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Initialize
********************************************************************************/
Step_0:
BEGIN
   -- Storer config
   SET @cLOCLookupSP = rdt.rdtGetConfig( @nFunc, 'LOCLookupSP', @cStorerKey)
   SET @cPAMatchSuggestLOC = rdt.RDTGetConfig( @nFunc, 'PutawayMatchSuggestLOC', @cStorerKey)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- Prepare next screen var
   SET @cOutField01 = '' -- @cDropID

   -- Set the entry point
   SET @nScn  = 6300
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 6300
   FROM ID      (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropID = @cInField01
      SET @cBarcode = @cInField01

      -- Check blank
      IF @cDropID = ''
      BEGIN
         SET @nErrNo = 207451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Drop ID needed
         GOTO Step_1_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cID     = @cDropID OUTPUT, 
               --@nErrNo  = @nErrNo  OUTPUT, 
               --@cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'ID'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cDropID OUTPUT, @cLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg  OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cDropID      NVARCHAR( 20)  OUTPUT, ' +
               ' @cLOC         NVARCHAR( 10)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, 
               @cDropID OUTPUT, @cToLOC   OUTPUT, @nErrNo   OUTPUT, @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END
      
      -- Check ID valid (with QTY to move)
      IF NOT EXISTS( SELECT 1 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND PD.DropID = @cDropID
            AND PD.Status <> '4'
            AND PD.Status < '9'
            AND PD.QTY > 0)
      BEGIN
         SET @nErrNo = 207452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_1_Fail
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- Get storer
         DECLARE @cChkStorerKey NVARCHAR(15)
         SELECT TOP 1 @cChkStorerKey = PD.StorerKey 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND PD.ID = @cDropID
            AND PD.Status <> '4'
            AND PD.Status < '9'
            AND PD.QTY > 0
         
         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 207453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            GOTO Step_1_Fail
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
      END

      -- Get storer configure
      SET @cDefaultToLOC = rdt.rdtGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''
      SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
      SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PutawayByDropID -- For rollback or commit only our own transaction

      -- Get suggest LOC
      DECLARE @nPAErrNo INT
      SET @nPAErrNo = 0
      SET @nPABookingKey = 0
      EXEC rdt.rdt_PutawayByDropID_GetSuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility
         ,@cDropID
         ,@cSuggLOC        OUTPUT
         ,@cPickAndDropLOC OUTPUT
         ,@nPABookingKey   OUTPUT
         ,@nPAErrNo        OUTPUT
         ,@cErrMsg         OUTPUT
      IF @nPAErrNo <> 0 AND
         @nPAErrNo <> -1 -- No suggested LOC
      BEGIN
         SET @nErrNo = @nPAErrNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         
         ROLLBACK TRAN rdtfnc_PutawayByDropID -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_1_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_PutawayByDropID -- Only rollback change made here
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_1_Fail
            END
         END
      END
      
      -- Check no suggest LOC (but allow user go to next screen scan another LOC)
      IF @nPAErrNo = -1
      BEGIN
         SET @nErrNo = 207454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoSuitableLOC
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Prepare next screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggLOC ELSE @cPickAndDropLOC END
      SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cOutField02 ELSE '' END -- Final LOC
      SET @cOutField15 = '' -- ExtendedInfo

      -- Go to Suggest LOC screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, ' + 
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cDropID = ''
      SET @cOutField01 = '' -- FromID
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen 6301. TO LOC
   FROM ID     (Field01, input)
   Suggest LOC (Field02)
   TO LOC      (Field03)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField03

      -- Check blank
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 207455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TO LOC
         GOTO Step_2_Fail
      END

      -- LOC lookup     
      IF @cLOCLookupSP = 1              
      BEGIN              
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,               
            @cToLOC     OUTPUT,               
            @nErrNo     OUTPUT,               
            @cErrMsg    OUTPUT              

         IF @nErrNo <> 0              
            GOTO Step_2_Fail              
      END 

      -- Check TO LOC valid
      IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC)
      BEGIN
         SET @nErrNo = 207456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_2_Fail
      END

      -- Check if suggested LOC match
      IF (@cToLOC <> @cSuggLOC AND @cSuggLOC <> '') OR            -- Not match suggested LOC
         (@cToLOC <> @cPickAndDropLOC AND @cPickAndDropLOC <> '') -- Not match PND LOC
      BEGIN
         IF @cPAMatchSuggestLOC = '1'
         BEGIN
            SET @nErrNo = 207457
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC Not Match
            GOTO Step_2_Fail
         END
         ELSE IF @cPAMatchSuggestLOC = '2'
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- Option
            
            -- Go to LOC not match screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            
            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PutawayByDropID -- For rollback or commit only our own transaction

      -- Confirm task         
      EXEC rdt.rdt_PutawayByDropID_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility
         ,@cDropID
         ,@cSuggLOC
         ,@cPickAndDropLOC
         ,@cToLOC
         ,@nPABookingKey OUTPUT
         ,@nErrNo        OUTPUT
         ,@cErrMsg       OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_PutawayByDropID -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_PutawayByDropID -- Only rollback change made here
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_2_Fail
            END
         END
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cToLocation   = @cToLOC,
         @cDropID       = @cDropID

      -- Prepare next screen var
      SET @cOutField01 = '' -- FromID

      -- Go to FromID screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Unlock current session suggested LOC
      IF @nPABookingKey <> 0
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
            ,'' --FromLOC
            ,'' --FromID
            ,'' --cSuggLOC
            ,'' --Storer
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0  
            GOTO Step_2_Fail
         
         SET @nPABookingKey = 0
      END

      -- Prepare next screen var
      SET @cOutField01 = '' --FromID

      -- Go to FromID screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField03 = '' -- TOLOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 6302.
   LOC not match. Proceed?
   1 = YES
   2 = NO
   OPTION (Input, Field01)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 207458
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --Option req
         GOTO Quit
      END
      
      -- Check optin valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 207459
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --Invalid Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            IF @nErrNo <> 0
            BEGIN
               SET @cOutField01 = ''
               GOTO Quit
            END
         END
      END

      IF @cOption = '1' -- YES
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_PutawayByDropID -- For rollback or commit only our own transaction

         -- Confirm task         
         EXEC rdt.rdt_PutawayByDropID_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility
            ,@cDropID
            ,@cSuggLOC
            ,@cPickAndDropLOC
            ,@cToLOC
            ,@nPABookingKey OUTPUT
            ,@nErrNo        OUTPUT
            ,@cErrMsg       OUTPUT
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_PutawayByDropID -- Only rollback change made here
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
                  ' @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' + 
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cDropID         NVARCHAR( 20), ' +
                  '@cSuggLOC        NVARCHAR( 10), ' +
                  '@cPickAndDropLOC NVARCHAR( 10), ' +
                  '@cToLOC          NVARCHAR( 10), ' +
                  '@nErrNo          INT           OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT  '
      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_PutawayByDropID -- Only rollback change made here
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  SET @cOutField01 = ''
                  GOTO Quit
               END
            END
         END

         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- Logging
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cToLocation   = @cToLOC,
            @cDropID       = @cDropID

         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- FromID

            -- Go to FromID screen
            SET @nScn  = @nScn - 2
            SET @nStep = @nStep - 2
         END
      END

      IF @cOption = '2' -- No
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cDropID
         SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggLOC ELSE @cPickAndDropLOC END
         SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cOutField02 ELSE '' END -- Final LOC
         SET @cOutField15 = '' -- ExtendedInfo

         -- Go to Suggest LOC screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggLOC ELSE @cPickAndDropLOC END
      SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cOutField02 ELSE '' END -- Final LOC
      SET @cOutField15 = '' -- ExtendedInfo

      -- Go to Suggest LOC screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

   Step_3_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, ' + 
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSuggLOC        NVARCHAR( 10), ' +
               '@cPickAndDropLOC NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cDropID, @cSuggLOC, @cPickAndDropLOC, @cToLOC, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nStep = 2
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      V_StorerKey = @cStorerKey, 
      V_DropID    = @cDropID,

      V_String1  = @cSuggLOC,
      V_String2  = @cPickAndDropLOC,
      V_String3  = @cToLOC,
      V_String4  = @cExtendedValidateSP,
      V_String5  = @cExtendedUpdateSP,
      V_String6  = @cExtendedInfoSP,
      V_String7  = @cExtendedInfo,
      V_String9  = @cDefaultToLOC, 
      V_String10 = @cDecodeSP,
      V_String18 = @cLOCLookupSP,
      V_String19 = @cPAMatchSuggestLOC,

      V_Integer1 = @nPABookingKey, 

      I_Field01 = '',  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = '',  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = '',  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = '',  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = '',  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = '',  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = '',  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = '',  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = '',  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = '',  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = '',  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = '',  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = '',  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = '',  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = '',  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO