SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Trolley_Putaway                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-01-09 1.0  Ung        SOS259764. Created                        */
/* 2014-01-22 1.1  Ung        SOS300984 Show UCC QTY                    */
/* 2014-01-29 1.2  Ung        SOS300988 Add EventLog                    */
/* 2015-08-09 1.3  Ung        SOS347869 Add QTY, change screen flow     */
/* 2015-09-11 1.4  Ung        SOS352648 Change to sort by PALogicalLOC  */
/* 2016-09-30 1.5  Ung        Performance tuning                        */   
/* 2017-03-24 1.6  James      WMS1399-Add VerifyFakeQty config (james01)*/   
/*                            Add ExtendedValidateSP                    */ 
/* 2017-06-15 1.7  James      WMS2245-Add config to skip qty screen     */
/*                            (james02)                                 */  
/* 2018-01-16 1.8  James      WMS3770-Add ExtendedInfoSP (james03)      */
/* 2018-10-02 1.9  Gan        Performance tuning                        */
/* 2019-11-07 2.0  James      WMS-11033 Add ExtendedUpdateSP (james04)  */
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_Trolley_Putaway] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @cUCC          NVARCHAR( 20),
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX)

-- rdt.rdtMobRec variable
DECLARE
   @nFunc           INT,
   @nScn            INT,
   @nStep           INT,
   @nMenu           INT,
   @cLangCode       NVARCHAR( 3),
   @nInputKey       INT,

   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cUserName       NVARCHAR(18),
   @cPrinter        NVARCHAR( 10),

   @cSuggestedUCC   NVARCHAR (20), 
   @cSuggestedLOC   NVARCHAR( 10),
   @cTrolleyNo      NVARCHAR( 10),
   @cPosition       NVARCHAR( 1), 
   @cVerifyLOC      NVARCHAR( 10),
   @cDefVerifyLOC   NVARCHAR( 10),
   @cVerifyFakeQTY  NVARCHAR( 1),      -- (james01)
   @cExtendedValidateSP NVARCHAR( 20), -- (james01)
   @cSkipQtyScn     NVARCHAR( 1),      -- (james02)
   @cExtendedInfoSP NVARCHAR( 20),     -- (james03)
   @cExtendedInfo   NVARCHAR( 20),     -- (james03)
   @nUCCQTY         INT,
   @cQTY            NVARCHAR( 5),
   @cVerifyQTY      NVARCHAR( 5),
   @tExtUpdVar      VariableTable,   -- (james04)
   @cExtendedUpdateSP NVARCHAR( 20), -- (james04)
   @nTranCount      INT,             -- (james04)
      
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1),
   @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1),
   @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,
   @nInputKey  = InputKey,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cSuggestedUCC = V_UCC, 
   @cSuggestedLOC = V_LOC,

   @cTrolleyNo    = V_String1,
   @cPosition     = V_String2,
   @cVerifyLOC    = V_String3,
   @cDefVerifyLOC = V_String4,
   @cVerifyFakeQTY= V_String5,         -- (james01)
   @cExtendedValidateSP = V_String6,   -- (james01)
   @cSkipQtyScn   = V_String7,         -- (james02)
   @cExtendedInfoSP  = V_String8,      -- (james03)
   @cExtendedInfo    = V_String9,      -- (james03)
   @cExtendedUpdateSP= V_String10,     -- (james04)

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,

   @cFieldAttr01 = FieldAttr01,
   @cFieldAttr02 = FieldAttr02,
   @cFieldAttr03 = FieldAttr03,
   @cFieldAttr04 = FieldAttr04,
   @cFieldAttr05 = FieldAttr05

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc in (741)
BEGIN
   IF @nStep = 0 GOTO Step_0  -- Menu. Func = 741
   IF @nStep = 1 GOTO Step_1  -- Scn = 3410. Trolley
   IF @nStep = 2 GOTO Step_2  -- Scn = 3411. UCC
   IF @nStep = 3 GOTO Step_3  -- Scn = 3422. QTY
   IF @nStep = 4 GOTO Step_4  -- Scn = 3423. LOC
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 741
********************************************************************************/
Step_0:
BEGIN
   -- Init var
   SET @cUCC = ''

   -- Get storer config
   SET @cDefVerifyLOC = rdt.RDTGetConfig( @nFunc, 'VerifyLOC', @cStorerKey)
   IF @cDefVerifyLOC = '0'
      SET @cDefVerifyLOC = 'TPAQC-LOC'

   SET @cVerifyFakeQTY = rdt.RDTGetConfig( @nFunc, 'VerifyFakeQTY', @cStorerKey)

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''

   -- (james02)
   SET @cSkipQtyScn = rdt.RDTGetConfig( @nFunc, 'SkipQtyScn', @cStorerKey)

   -- (james03)
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- (james04)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign in function
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep
   
   -- Go to next screen
   SET @nScn = 3410
   SET @nStep = 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3410. Trolley screen
   TROLLEY NO (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      -- Screen mapping
      SET @cTrolleyNo = @cInField01 --TrolleyNo

      -- Check blank
      IF @cTrolleyNo = ''
      BEGIN
         SET @nErrNo = 79101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need TrolleyNo
         GOTO Step_1_Fail
      END

      -- Check trolley valid
      IF NOT EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE TrolleyNo = @cTrolleyNo)
      BEGIN
         SET @nErrNo = 79102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidTrolley
         GOTO Step_1_Fail
      END
      
      -- Check trolley status
      IF NOT EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE TrolleyNo = @cTrolleyNo AND Status = '1')
      BEGIN
         SET @nErrNo = 79103
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- TrolleyNoClose
         GOTO Step_1_Fail
      END
      
      -- Get task
      SELECT TOP 1 
         @cSuggestedLOC = T.LOC, 
         @cSuggestedUCC = UCCNo, 
         @cPosition = Position
      FROM rdt.rdtTrolleyLog T WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (T.LOC = LOC.LOC)
      WHERE TrolleyNo = @cTrolleyNo
      ORDER BY LOC.PALogicalLoc, LOC.LOC

      -- Extended info (james03)
      SET @cExtendedInfo = ''
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cTrolleyNo, @cLOC, @cUCC, @cPosition, @nQty, @cExtendedInfo OUTPUT' 
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTrolleyNo      NVARCHAR( 5),  ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cUCC            NVARCHAR( 20), ' +
               '@cPosition       NVARCHAR( 1),  ' +
               '@nQty            INT,           ' +
               '@cExtendedInfo   NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cTrolleyNo, @cSuggestedLOC, @cSuggestedUCC, @cPosition, @cQty, @cExtendedInfo OUTPUT
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cTrolleyNo
      SET @cOutField02 = @cSuggestedUCC
      SET @cOutField03 = '' --UCC
      SET @cOutField04 = @cPosition
      SET @cOutField05 = @cExtendedInfo

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep
      
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
      SET @cTrolleyNo = ''
      SET @cOutField01 = '' --TrolleyNo
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3411. UCC screen
   TROLLEY NO    (field01)
   SUGGESTED UCC (field02)
   UCC           (field03)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField03 -- UCC

      -- Check blank
      IF @cUCC = ''
      BEGIN
         SET @nErrNo = 79104
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC needed
         GOTO Step_2_Fail
      END

      -- Check UCC different
      IF @cUCC <> @cSuggestedUCC
      BEGIN
         SET @nErrNo = 79105
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC different
         GOTO Step_2_Fail
      END
      -- (james02)
      -- Go to QTY screen 
      IF @cSkipQtyScn <> '1' 
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cTrolleyNo
         SET @cOutField02 = @cSuggestedUCC
         SET @cOutField03 = '' -- QTY

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         SET @cVerifyLOC = @cSuggestedLOC

         -- Prepare next screen var
         SET @cOutField01 = @cTrolleyNo
         SET @cOutField02 = @cSuggestedUCC
         SET @cOutField03 = ''
         SET @cOutField04 = @cVerifyLOC
         SET @cOutField05 = '' -- LOC

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cTrolleyNo
   
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField03 = '' --UCC
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 3412. QTY screen
   TROLLEY NO    (field01)
   SUGGESTED UCC (field02)
   QTY           (field03)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQTY = @cInField03 -- QTY

      -- Check blank
      IF @cQTY = ''
      BEGIN
         SET @nErrNo = 79106
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY
         GOTO Step_3_Fail
      END

      -- Check QTY valid
      IF rdt.rdtIsValidQTY( @cQTY, 1) = 0
      BEGIN
         SET @nErrNo = 79107
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid QTY
         GOTO Step_3_Fail
      END

      -- Verify qty turn on only then check fake qty (james01)
      IF @cVerifyFakeQTY = '1'
      BEGIN
         -- Get UCC info
         SELECT 
            @nUCCQTY = QTY, 
            @cVerifyQTY = LEFT( UserDefined08, 5)
         FROM UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cSuggestedUCC

         -- Check verify QTY
         IF @cVerifyQTY = ''
         BEGIN
            IF @cQTY = CAST( @nUCCQTY AS NVARCHAR(5))
               SET @cVerifyLOC = @cSuggestedLOC
            ELSE
               SET @cVerifyLOC = @cDefVerifyLOC
         END
         ELSE
         BEGIN
            IF @cQTY = CAST( @cVerifyQTY AS NVARCHAR(5))
               SET @cVerifyLOC = @cSuggestedLOC
            ELSE
               SET @cVerifyLOC = @cDefVerifyLOC
         END
      END
      ELSE
      BEGIN
         SET @cVerifyLOC = @cSuggestedLOC
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTrolleyNo, ' + 
               ' @cUCC, @nQTY, @cSuggestedLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTrolleyNo      NVARCHAR( 5),  ' +
               '@cUCC            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' + 
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
               
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTrolleyNo, 
               @cSuggestedUCC, @cQTY, @cSuggestedLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
            IF @nErrNo <> 0 
            BEGIN
               -- If qty cannot pass extendedvalidatesp and 
               -- config verifyloc is setup meaning need verify loc.
               -- Then set the verifyloc with the svalue else return errmsg
               IF ISNULL (@cDefVerifyLOC, '') <> ''
               BEGIN
                  SET @cVerifyLOC = @cDefVerifyLOC
                  SET @nErrNo = 0
                  SET @cErrMsg = ''
               END
               ELSE
                  GOTO Step_3_Fail 
            END
         END
      END 

      -- Prepare next screen var
      SET @cOutField01 = @cTrolleyNo
      SET @cOutField02 = @cSuggestedUCC
      SET @cOutField03 = @cQTY
      SET @cOutField04 = @cVerifyLOC
      SET @cOutField05 = '' -- LOC

      -- Go to LOC screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cTrolleyNo
      SET @cOutField02 = @cSuggestedUCC
      SET @cOutField03 = ''
      SET @cOutField04 = @cPosition
      SET @cOutField05 = @cExtendedInfo
   
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cQTY = ''
      SET @cOutField03 = '' --UCC
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 3413. LOC
   TROLLEY NO    (field01)
   UCC           (field02)
   QTY           (field03)
   SUGGESTED LOC (field04)
   LOC           (field05, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cLOC NVARCHAR( 10)

      -- Screen mapping
      SET @cLOC = @cInField05 -- LOC

      -- Check option blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 79108
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LOC Required
         GOTO Step_4_Fail
      END

      -- Check loc different
      IF @cLOC <> @cVerifyLOC
      BEGIN
         SET @nErrNo = 79109
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LOC different
         GOTO Step_4_Fail
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_Trolley_Putaway_Confirm
   
      -- Putaway
      EXEC rdt.rdt_Trolley_Putaway_Confirm @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cUserName
         ,@cTrolleyNo
         ,@cSuggestedUCC
         ,@cSuggestedLOC
         ,@nErrNo     OUTPUT 
         ,@cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Trolley_Putaway_RollBackTran

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTrolleyNo, ' + 
               ' @cUCC, @nQTY, @cSuggestedLOC, @tExtUpdVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTrolleyNo      NVARCHAR( 5),  ' +
               '@cUCC            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@tExtUpdVar      VariableTable READONLY, ' +   
               '@nErrNo          INT           OUTPUT, ' + 
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
               
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTrolleyNo, 
               @cSuggestedUCC, @cQTY, @cSuggestedLOC, @tExtUpdVar, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
            IF @nErrNo <> 0 
               GOTO Trolley_Putaway_RollBackTran 
         END
      END 

      GOTO Trolley_Putaway_Confirm

      Trolley_Putaway_RollBackTran:
      ROLLBACK TRAN rdt_Trolley_Putaway_Confirm
      
      Trolley_Putaway_Confirm:         
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
      
      IF @nErrNo <> 0
         GOTO Step_4_Fail

      IF EXISTS( SELECT 1 FROM rdt.rdtTrolleyLog WITH (NOLOCK) WHERE TrolleyNo = @cTrolleyNo AND Status = '1')
      BEGIN 
         -- Get next task
         SELECT TOP 1 
            @cSuggestedLOC = T.LOC, 
            @cSuggestedUCC = UCCNo, 
            @cPosition = Position
         FROM rdt.rdtTrolleyLog T WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (T.LOC = LOC.LOC)
         WHERE TrolleyNo = @cTrolleyNo
         ORDER BY LOC.PALogicalLoc, LOC.LOC

         -- Extended info (james03)
         SET @cExtendedInfo = ''
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cTrolleyNo, @cLOC, @cUCC, @cPosition, @nQty, @cExtendedInfo OUTPUT' 
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' + 
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cTrolleyNo      NVARCHAR( 5),  ' +
                  '@cLOC            NVARCHAR( 10), ' +
                  '@cUCC            NVARCHAR( 20), ' +
                  '@cPosition       NVARCHAR( 1),  ' +
                  '@nQty            INT,           ' +
                  '@cExtendedInfo   NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cTrolleyNo, @cSuggestedLOC, @cSuggestedUCC, @cPosition, @cQty, @cExtendedInfo OUTPUT
            END
         END

         -- Prepare next screen var
         SET @cOutField01 = @cTrolleyNo
         SET @cOutField02 = @cSuggestedUCC
         SET @cOutField03 = '' --UCC
         SET @cOutField04 = @cPosition
         SET @cOutField05 = @cExtendedInfo
   
         -- Go to UCC screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
      ELSE
      BEGIN      
         -- Go to Trolley screen
         SET @cTrolleyNo = ''
         SET @cOutField01 = '' -- TrolleyNo
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- (james02)
      -- Go to QTY screen 
      IF @cSkipQtyScn <> '1' 
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cTrolleyNo
         SET @cOutField02 = @cSuggestedUCC
         SET @cOutField03 = '' --QTY
   
         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cTrolleyNo
         SET @cOutField02 = @cSuggestedUCC
         SET @cOutField03 = '' --UCC
         SET @cOutField04 = @cPosition
         SET @cOutField05 = @cExtendedInfo

         -- Go to prev screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END
   GOTO Quit

   Step_4_Fail:
      SET @cLOC = ''
      SET @cOutField05 = '' --LOC
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      Printer   = @cPrinter,
      -- UserName  = @cUserName,

      V_UCC     = @cSuggestedUCC, 
      V_LOC     = @cSuggestedLOC,

      V_String1 = @cTrolleyNo,
      V_String2 = @cPosition,
      V_String3 = @cVerifyLOC, 
      V_String4 = @cDefVerifyLOC, 
      V_String5 = @cVerifyFakeQTY,        -- (james01)
      V_String6 = @cExtendedValidateSP,   -- (james01)
      V_String7 = @cSkipQtyScn,           -- (james02)
      V_String8 = @cExtendedInfoSP,       -- (james03)
      V_String9 = @cExtendedInfo,         -- (james03)
      V_String10= @cExtendedUpdateSP,     -- (james04)

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,

      FieldAttr01  = @cFieldAttr01,
      FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,
      FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05

   WHERE Mobile = @nMobile
END

GO