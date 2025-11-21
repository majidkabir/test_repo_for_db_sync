SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PickByCartonID                                     */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-03-18  1.0  Ung      WMS-8284 Created                                 */
/* 2019-08-19  1.1  Ung      WMS-10176 Add fully scan auto go to next screen  */
/* 2022-04-04  1.2  Ung      WMS-18892 Wave optional                          */
/*                           Add 1 carton don't need confirm carton ID        */
/* 2022-10-03  1.3  Ung      WMS-20841 Add skip LOC screen                    */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PickByCartonID] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @bSuccess         INT,
   @nTranCount       INT, 
   @cSQL             NVARCHAR(MAX),
   @cSQLParam        NVARCHAR(MAX),
   @nCartonIDCount   INT, 
   @cFlowThruScreen  NVARCHAR(1), 
   @tVar             VariableTable

-- RDT.RDTMobRec variable
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR(3),
   @nInputKey        INT,
   @nMenu            INT,

   @cStorerKey       NVARCHAR(15),
   @cFacility        NVARCHAR(5),
   @cUserName        NVARCHAR(15),

   @cWaveKey         NVARCHAR(10), 
   @cPWZone          NVARCHAR(10), 
   @cCartonID        NVARCHAR(20),
   @cLOC             NVARCHAR(10), 
   @cID              NVARCHAR(18),
   @cSKU             NVARCHAR(20),
   @cSKUDescr        NVARCHAR(60),
   @cLottable01      NVARCHAR(18),
   @cLottable02      NVARCHAR(18),
   @cLottable03      NVARCHAR(18),
   @dLottable04      DATETIME,
   @nTaskQTY         INT, 
   @nQTY             INT,

   @cSuggLOC         NVARCHAR(10),
   @cSuggSKU         NVARCHAR(20),
   @cPosition        NVARCHAR(10),

   @cCartonID1       NVARCHAR(20), 
   @cCartonID2       NVARCHAR(20),
   @cCartonID3       NVARCHAR(20),
   @cCartonID4       NVARCHAR(20),
   @cCartonID5       NVARCHAR(20),
   @cCartonID6       NVARCHAR(20),
   @cCartonID7       NVARCHAR(20),
   @cCartonID8       NVARCHAR(20),
   @cCartonID9       NVARCHAR(20),

   @cExtendedValidateSP NVARCHAR(20),
   @cExtendedUpdateSP   NVARCHAR(20),
   @cExtendedInfoSP     NVARCHAR(20),
   @cExtendedInfo       NVARCHAR(20),
   @cWaveOptional       NVARCHAR(1),

   @nTotalQTY           INT,   -- Total QTY to pick for a LOC, SKU, lottable (across all cartons)

   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),   @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),   @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),   @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),   @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),   @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60),   @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60),   @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60),   @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60),   @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60),   @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60),   @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60),   @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60),   @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60),   @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60),   @cFieldAttr15 NVARCHAR( 1)

-- Load RDT.RDTMobRec
SELECT
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,
                  
   @cStorerKey    = StorerKey,
   @cFacility     = Facility,
   @cUserName     = UserName,
                  
   @cWaveKey      = V_WaveKey,
   @cPWZone       = V_Zone,
   @cCartonID     = V_CaseID,
   @cLOC          = V_LOC,
   @cID           = V_ID, 
   @cSKU          = V_SKU,
   @cSKUDescr     = V_SKUDescr,
   @cLottable01   = V_Lottable01,
   @cLottable02   = V_Lottable02,
   @cLottable03   = V_Lottable03,
   @dLottable04   = V_Lottable04,
   @nTaskQTY      = V_TaskQTY,
   @nQTY          = V_QTY,
   
   @cSuggLOC      = V_String1,
   @cSuggSKU      = V_String2,  
   @cPosition     = V_String3,  
   
   @cCartonID1    = V_String10,
   @cCartonID2    = V_String11,
   @cCartonID3    = V_String12,
   @cCartonID4    = V_String13,
   @cCartonID5    = V_String14,
   @cCartonID6    = V_String15,
   @cCartonID7    = V_String16,
   @cCartonID8    = V_String17,
   @cCartonID9    = V_String18,

   @cExtendedValidateSP = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedInfoSP     = V_String23,
   @cExtendedInfo       = V_String24,
   @cWaveOptional       = V_String25,

   @nTotalQTY     = V_Integer1,

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
IF @nFunc = 831 -- Pick by carton ID
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 831
   IF @nStep = 1 GOTO Step_1   -- Scn = 5350. WaveKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 5351. PutawayZone
   IF @nStep = 3 GOTO Step_3   -- Scn = 5352. CartonID 1..9
   IF @nStep = 4 GOTO Step_4   -- Scn = 5353. LOC
   IF @nStep = 5 GOTO Step_5   -- Scn = 5354. SKU, QTY
   IF @nStep = 6 GOTO Step_6   -- Scn = 5355. Carton ID
   IF @nStep = 7 GOTO Step_7   -- Scn = 5356. Confirm Short Pick?
   IF @nStep = 8 GOTO Step_8   -- Scn = 5357. Skip LOC?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 831)
********************************************************************************/
Step_0:
BEGIN
   -- Get StorerConfig
   SET @cWaveOptional = rdt.rdtGetConfig( @nFunc, 'WaveOptional', @cStorerKey)

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   -- Prepare next screen var
   SET @cOutField01 = '' -- WaveKey
   SET @cOutField02 = '' -- PutawayZone

   -- Set the entry point
   SET @nScn = 5350
   SET @nStep = 1

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 5350
   WAVEKEY  (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWaveKey = @cInField01

      -- Check blank
      IF @cWaveKey = ''
      BEGIN
         IF @cWaveOptional = '0'
         BEGIN
            SET @nErrNo = 136251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need WAVEKEY
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
            GOTO Quit
         END
      END

      -- Check wave valid
      IF @cWaveKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.WaveDetail WITH (NOLOCK) WHERE WaveKey = @cWaveKey)
         BEGIN
            SET @nErrNo = 136252
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad WAVEKEY
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Check diff storer
         IF EXISTS (SELECT 1 
            FROM dbo.WaveDetail WD WITH (NOLOCK) 
               JOIN Orders O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
            WHERE WD.WaveKey = @cWaveKey
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 136265
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- WaveKey
            SET @cOutField01 = ''
            GOTO Quit
         END
      END
      
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = '' -- PWZone

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
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
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
END
GOTO Quit



/********************************************************************************
Step 2. Screen = 5351
   WAVEKEY  (field01)
   PWAYZONE (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPWZone = @cInField02

      IF @cPWZone <> ''
      BEGIN
         -- Get putawayzone info
         DECLARE @cChkFacility NVARCHAR(5)
         SELECT @cChkFacility = Facility FROM dbo.PutawayZone WITH (NOLOCK) WHERE PutawayZone = @cPWZone

         -- Check putaway zone valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 136254
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad PWZONE
            SET @cOutField02 = ''
            GOTO Quit
         END
         
         -- Check diff facility
         IF @cFacility <> @cChkFacility 
         BEGIN
            SET @nErrNo = 136267
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            SET @cOutField02 = ''
            GOTO Quit
         END
      END

      SET @cCartonID1 = ''
      SET @cCartonID2 = ''
      SET @cCartonID3 = ''
      SET @cCartonID4 = ''
      SET @cCartonID5 = ''
      SET @cCartonID6 = ''
      SET @cCartonID7 = ''
      SET @cCartonID8 = ''
      SET @cCartonID9 = ''

      -- Prep next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' --WaveKey

      -- Go to WaveKey screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 5351
   CartonID1 (field01, input)
   CartonID2 (field02, input)
   CartonID3 (field03, input)
   CartonID4 (field04, input)
   CartonID5 (field05, input)
   CartonID6 (field06, input)
   CartonID7 (field07, input)
   CartonID8 (field08, input)
   CartonID9 (field09, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Retain key-in value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03
      SET @cOutField04 = @cInField04
      SET @cOutField05 = @cInField05
      SET @cOutField06 = @cInField06
      SET @cOutField07 = @cInField07
      SET @cOutField08 = @cInField08
      SET @cOutField09 = @cInField09

      -- Validate blank
      IF @cInField01 = '' AND
         @cInField02 = '' AND
         @cInField03 = '' AND
         @cInField04 = '' AND
         @cInField05 = '' AND
         @cInField06 = '' AND
         @cInField07 = '' AND
         @cInField08 = '' AND
         @cInField09 = ''
      BEGIN
         SET @nErrNo = 136255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartonID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Put all PickSlipNo into temp table
      DECLARE @tCatonID TABLE (CartonID NVARCHAR( 20), Position INT)
      INSERT INTO @tCatonID (CartonID, Position) VALUES (@cInField01, 1)
      INSERT INTO @tCatonID (CartonID, Position) VALUES (@cInField02, 2)
      INSERT INTO @tCatonID (CartonID, Position) VALUES (@cInField03, 3)
      INSERT INTO @tCatonID (CartonID, Position) VALUES (@cInField04, 4)
      INSERT INTO @tCatonID (CartonID, Position) VALUES (@cInField05, 5)
      INSERT INTO @tCatonID (CartonID, Position) VALUES (@cInField06, 6)
      INSERT INTO @tCatonID (CartonID, Position) VALUES (@cInField07, 7)
      INSERT INTO @tCatonID (CartonID, Position) VALUES (@cInField08, 8)
      INSERT INTO @tCatonID (CartonID, Position) VALUES (@cInField09, 9)

      -- Validate PickSlipNo scanned more than once
      SELECT @nCartonIDCount = MAX( Position)
      FROM @tCatonID
      WHERE CartonID <> '' AND CartonID IS NOT NULL
      GROUP BY CartonID
      HAVING COUNT( CartonID) > 1

      IF @@ROWCOUNT <> 0
      BEGIN
         SET @nErrNo = 136256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Dup CartonID
         EXEC rdt.rdtSetFocusField @nMobile, @nCartonIDCount
         GOTO Quit
      END

      -- Validate if anything changed
      IF @cCartonID1 <> @cInField01 OR
         @cCartonID2 <> @cInField02 OR
         @cCartonID3 <> @cInField03 OR
         @cCartonID4 <> @cInField04 OR
         @cCartonID5 <> @cInField05 OR
         @cCartonID6 <> @cInField06 OR
         @cCartonID7 <> @cInField07 OR
         @cCartonID8 <> @cInField08 OR
         @cCartonID9 <> @cInField09

      -- There are changes, remain in current screen
      BEGIN
         DECLARE @cInField NVARCHAR( 20)

         -- Check newly scanned Carton ID
         SET @nCartonIDCount = 1
         WHILE @nCartonIDCount <= 9
         BEGIN
            IF @nCartonIDCount = 1 SELECT @cInField = @cInField01, @cCartonID = @cCartonID1 ELSE
            IF @nCartonIDCount = 2 SELECT @cInField = @cInField02, @cCartonID = @cCartonID2 ELSE
            IF @nCartonIDCount = 3 SELECT @cInField = @cInField03, @cCartonID = @cCartonID3 ELSE
            IF @nCartonIDCount = 4 SELECT @cInField = @cInField04, @cCartonID = @cCartonID4 ELSE
            IF @nCartonIDCount = 5 SELECT @cInField = @cInField05, @cCartonID = @cCartonID5 ELSE
            IF @nCartonIDCount = 6 SELECT @cInField = @cInField06, @cCartonID = @cCartonID6 ELSE
            IF @nCartonIDCount = 7 SELECT @cInField = @cInField07, @cCartonID = @cCartonID7 ELSE
            IF @nCartonIDCount = 8 SELECT @cInField = @cInField08, @cCartonID = @cCartonID8 ELSE
            IF @nCartonIDCount = 9 SELECT @cInField = @cInField09, @cCartonID = @cCartonID9

            -- Value changed
            IF @cInField <> @cCartonID
            BEGIN
               -- Consist a new value
               IF @cInField <> ''
               BEGIN
                  -- Validate carton ID
                  SET @nErrNo = 0
                  EXEC rdt.rdt_PickByCartonID_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                     @cWaveKey,
                     @cPWZone,
                     @cInField, -- Entered carton ID
                     @nErrNo    OUTPUT,
                     @cErrMsg   OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     -- Error, clear the field
                     IF @nCartonIDCount = 1 SELECT @cCartonID1 = '', @cInField01 = '', @cOutField01 = '' ELSE
                     IF @nCartonIDCount = 2 SELECT @cCartonID2 = '', @cInField02 = '', @cOutField02 = '' ELSE
                     IF @nCartonIDCount = 3 SELECT @cCartonID3 = '', @cInField03 = '', @cOutField03 = '' ELSE
                     IF @nCartonIDCount = 4 SELECT @cCartonID4 = '', @cInField04 = '', @cOutField04 = '' ELSE
                     IF @nCartonIDCount = 5 SELECT @cCartonID5 = '', @cInField05 = '', @cOutField05 = '' ELSE
                     IF @nCartonIDCount = 6 SELECT @cCartonID6 = '', @cInField06 = '', @cOutField06 = '' ELSE
                     IF @nCartonIDCount = 7 SELECT @cCartonID7 = '', @cInField07 = '', @cOutField07 = '' ELSE
                     IF @nCartonIDCount = 8 SELECT @cCartonID8 = '', @cInField08 = '', @cOutField08 = '' ELSE
                     IF @nCartonIDCount = 9 SELECT @cCartonID9 = '', @cInField09 = '', @cOutField09 = ''

                     EXEC rdt.rdtSetFocusField @nMobile, @nCartonIDCount
                     GOTO Quit
                  END
               END

               -- Save to PickSlipNo variable
               IF @nCartonIDCount = 1 SET @cCartonID1 = @cInField01 ELSE
               IF @nCartonIDCount = 2 SET @cCartonID2 = @cInField02 ELSE
               IF @nCartonIDCount = 3 SET @cCartonID3 = @cInField03 ELSE
               IF @nCartonIDCount = 4 SET @cCartonID4 = @cInField04 ELSE
               IF @nCartonIDCount = 5 SET @cCartonID5 = @cInField05 ELSE
               IF @nCartonIDCount = 6 SET @cCartonID6 = @cInField06 ELSE
               IF @nCartonIDCount = 7 SET @cCartonID7 = @cInField07 ELSE
               IF @nCartonIDCount = 8 SET @cCartonID8 = @cInField08 ELSE
               IF @nCartonIDCount = 9 SET @cCartonID9 = @cInField09
            END
            SET @nCartonIDCount = @nCartonIDCount + 1
         END

         -- Position cursor on next empty field
         IF @cInField01 = '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
         IF @cInField02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
         IF @cInField03 = '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
         IF @cInField04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
         IF @cInField05 = '' EXEC rdt.rdtSetFocusField @nMobile, 5 ELSE
         IF @cInField06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
         IF @cInField07 = '' EXEC rdt.rdtSetFocusField @nMobile, 7 ELSE
         IF @cInField08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 ELSE
         IF @cInField09 = '' EXEC rdt.rdtSetFocusField @nMobile, 9

         GOTO Quit
      END

      -- Get 1st suggested pick LOC
      SET @cSuggLOC = ''
      EXEC rdt.rdt_PickByCartonID_GetNextLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cWaveKey,
         @cPWZone,
         @cCartonID1,
         @cCartonID2,
         @cCartonID3,
         @cCartonID4,
         @cCartonID5,
         @cCartonID6,
         @cCartonID7,
         @cCartonID8,
         @cCartonID9,
         '',      -- Current location
         @cSuggLOC  OUTPUT,
         @nErrNo    OUTPUT,
         @cErrMsg   OUTPUT

      -- Check if no more pick LOC
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = @cSuggLOC
      SET @cOutField02 = '' -- LOC

      -- Go to LOC screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = '' -- PutawayZone

      -- Go to PWZone screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

Step_3_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN       
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, ' + 
            ' @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, ' + 
            ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cWaveKey       NVARCHAR( 10), ' +
            ' @cPWZone        NVARCHAR( 10), ' +
            ' @cCartonID1     NVARCHAR( 20), ' +
            ' @cCartonID2     NVARCHAR( 20), ' +
            ' @cCartonID3     NVARCHAR( 20), ' +
            ' @cCartonID4     NVARCHAR( 20), ' +
            ' @cCartonID5     NVARCHAR( 20), ' +
            ' @cCartonID6     NVARCHAR( 20), ' +
            ' @cCartonID7     NVARCHAR( 20), ' +
            ' @cCartonID8     NVARCHAR( 20), ' +
            ' @cCartonID9     NVARCHAR( 20), ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cPosition      NVARCHAR( 10), ' +
            ' @cSuggLOC       NVARCHAR( 10), ' +
            ' @cSuggSKU       NVARCHAR( 20), ' +
            ' @nTaskQTY       INT,           ' +
            ' @nTotalQTY      INT,           ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @nQTY           INT,           ' +
            ' @cLottable01    NVARCHAR( 18), ' +
            ' @cLottable02    NVARCHAR( 18), ' +
            ' @cLottable03    NVARCHAR( 18), ' +
            ' @dLottable04    DATETIME,      ' +
            ' @tVar           VariableTable  READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, 
            @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
            @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         SET @cOutField15 = @cExtendedInfo 
      END
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen 5352
   LOC (Field01)
   LOC (Field02, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField02

      -- Check blank
      IF @cLOC <> ''
      BEGIN
         IF @cLOC <> @cSuggLOC
         BEGIN
        SET @nErrNo = 136257
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different LOC
            SET @cOutField02 = '' -- LOC
            GOTO Quit
         END
      END

      -- Confirm Skip LOC
      IF @cLOC = ''
      BEGIN
         SET @cOutField01 = '' -- Option

         -- Go to skip LOC screen
         SET @nScn  = @nScn + 4
         SET @nStep = @nStep + 4
         
         GOTO Quit
      END

      -- Get next task
      SELECT @cSKU = '', @cLottable01 = '', @cLottable02 = '', @cLottable03 = '', @dLottable04 = NULL, @cCartonID = '', @nTotalQTY = 0
      EXEC rdt.rdt_PickByCartonID_GetNextTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cWaveKey,
         @cPWZone,
         @cCartonID1,
         @cCartonID2,
         @cCartonID3,
         @cCartonID4,
         @cCartonID5,
         @cCartonID6,
         @cCartonID7,
         @cCartonID8,
         @cCartonID9,
         @cLOC,
         @cID           OUTPUT,
         @cPosition     OUTPUT,
         @cCartonID     OUTPUT,
         @cSKU          OUTPUT,
         @cSKUDescr     OUTPUT,
         @cLottable01   OUTPUT,
         @cLottable02   OUTPUT,
         @cLottable03   OUTPUT,
         @dLottable04   OUTPUT,
         @nTaskQTY      OUTPUT,
         @nTotalQTY     OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      SET @nQTY = 0

      -- Prep next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)
      SET @cOutField05 = @cLottable01
      SET @cOutField06 = @cLottable02
      SET @cOutField07 = @cLottable03
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField09 = @nTaskQTY
      SET @cOutField10 = '0' -- QTY
      SET @cOutField11 = ''  -- SKU
      SET @cOutField12 = CAST( @nTotalQTY AS NVARCHAR( 5))
      SET @cOutField13 = LEFT( @cPosition, 2)

      -- Go to SKU, QTY screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep previous screen var
      SET @cOutField01 = @cCartonID1
      SET @cOutField02 = @cCartonID2
      SET @cOutField03 = @cCartonID3
      SET @cOutField04 = @cCartonID4
      SET @cOutField05 = @cCartonID5
      SET @cOutField06 = @cCartonID6
      SET @cOutField07 = @cCartonID7
      SET @cOutField08 = @cCartonID8
      SET @cOutField09 = @cCartonID9

      EXEC rdt.rdtSetFocusField @nMobile, 1
      
      -- Go to carton ID screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

Step_4_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN       
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, ' + 
            ' @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, ' + 
            ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cWaveKey       NVARCHAR( 10), ' +
            ' @cPWZone        NVARCHAR( 10), ' +
            ' @cCartonID1     NVARCHAR( 20), ' +
            ' @cCartonID2     NVARCHAR( 20), ' +
            ' @cCartonID3     NVARCHAR( 20), ' +
            ' @cCartonID4     NVARCHAR( 20), ' +
            ' @cCartonID5     NVARCHAR( 20), ' +
            ' @cCartonID6     NVARCHAR( 20), ' +
            ' @cCartonID7     NVARCHAR( 20), ' +
            ' @cCartonID8     NVARCHAR( 20), ' +
            ' @cCartonID9     NVARCHAR( 20), ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cPosition      NVARCHAR( 10), ' +
            ' @cSuggLOC       NVARCHAR( 10), ' +
            ' @cSuggSKU       NVARCHAR( 20), ' +
            ' @nTaskQTY       INT,           ' +
            ' @nTotalQTY      INT,           ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @nQTY           INT,           ' +
            ' @cLottable01    NVARCHAR( 18), ' +
            ' @cLottable02    NVARCHAR( 18), ' +
            ' @cLottable03    NVARCHAR( 18), ' +
            ' @dLottable04    DATETIME,      ' +
            ' @tVar           VariableTable  READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, 
            @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
            @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         SET @cOutField15 = @cExtendedInfo 
      END
   END
END
GOTO Quit


/********************************************************************************
Step 5. Screen 5353
   SKU       (Field02)
   SKU Desc1 (Field03)
   SKU Desc2 (Field04)
   PPK       (Field12)
   Lottable1 (Field05)
   Lottable2 (Field06)
   Lottable3 (Field07)
   Lottable4 (Field08)
   PICKQTY   (Field09)
   ACT QTY   (Field10, input)
   SKU/UPC   (Field11, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      DECLARE @cUPC NVARCHAR( 30)

      -- Screen mapping
      SET @cUPC = LEFT( @cInField11, 30)

      -- Barcode scanned
      IF @cUPC <> ''
      BEGIN
         -- Get SKU/UPC
         DECLARE @nSKUCnt INT
         SET @nSKUCnt = 0
         EXEC rdt.rdt_GETSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC
            ,@nSKUCnt     = @nSKUCnt   OUTPUT
            ,@bSuccess    = @bSuccess  OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT

         -- Check SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 136259
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            SET @cOutField11 = '' -- SKU
            GOTO Quit
         END

         -- Get SKU
         IF @nSKUCnt = 1
         BEGIN
            EXEC rdt.rdt_GETSKU
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cUPC      OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT
         END

         -- Check multi barcode SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 136260
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU
            SET @cOutField11 = '' -- SKU
            GOTO Quit
         END

         -- Check SKU match
         IF @cSKU <> @cUPC
         BEGIN
            SET @nErrNo = 136261
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SKU
            SET @cOutField11 = '' -- SKU
            GOTO Quit
         END

         -- Top up QTY
         SET @nQTY = @nQTY + 1

         -- SKU not fully scan, remain in current screen
         IF @nQTY < @nTaskQTY
         BEGIN
            SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))
            SET @cOutField11 = '' -- SKU
            
            GOTO Quit
         END
      END

      -- Short pick
      IF @nQTY < @nTaskQTY
      BEGIN
         SET @cOutField01 = '' -- Option
         
         -- Go to confirm short screen
         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cPosition
         SET @cOutField02 = @cCartonID -- Suggest carton ID
         SET @cOutField03 = '' -- Carton ID

         -- Go to carton ID screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1

         -- Flow thru if only 1 carton
         SET @nCartonIDCount = 0
         IF @cCartonID1 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID2 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID3 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID4 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID5 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID6 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID7 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID8 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID9 <> '' SET @nCartonIDCount += 1 
         IF @nCartonIDCount = 1  
         BEGIN
            SET @cFlowThruScreen = '1'
            SET @cInField03 = @cCartonID
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep prev screen var
      SET @cOutField01 = @cSuggLOC
      SET @cOutField02 = ''

      -- Go to LOC screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   
Step_5_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN       
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, ' + 
            ' @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, ' + 
            ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cWaveKey       NVARCHAR( 10), ' +
            ' @cPWZone        NVARCHAR( 10), ' +
            ' @cCartonID1     NVARCHAR( 20), ' +
            ' @cCartonID2     NVARCHAR( 20), ' +
            ' @cCartonID3     NVARCHAR( 20), ' +
            ' @cCartonID4     NVARCHAR( 20), ' +
            ' @cCartonID5     NVARCHAR( 20), ' +
            ' @cCartonID6     NVARCHAR( 20), ' +
            ' @cCartonID7     NVARCHAR( 20), ' +
            ' @cCartonID8     NVARCHAR( 20), ' +
            ' @cCartonID9     NVARCHAR( 20), ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cPosition      NVARCHAR( 10), ' +
            ' @cSuggLOC       NVARCHAR( 10), ' +
            ' @cSuggSKU       NVARCHAR( 20), ' +
            ' @nTaskQTY       INT,           ' +
            ' @nTotalQTY      INT,           ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @nQTY           INT,           ' +
            ' @cLottable01    NVARCHAR( 18), ' +
            ' @cLottable02    NVARCHAR( 18), ' +
            ' @cLottable03    NVARCHAR( 18), ' +
            ' @dLottable04    DATETIME,      ' +
            ' @tVar           VariableTable  READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 5, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, 
            @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
            @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         SET @cOutField15 = @cExtendedInfo 
      END
   END
   
   IF @cFlowThruScreen = '1'
      IF @nStep = 6
         GOTO Step_6 
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 5355
   POSITION   (Field01)
   CARTON ID  (Field02)
   CARTON ID  (Field03, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cActCartonID NVARCHAR(20)
      
      -- Screen mapping
      SET @cActCartonID = @cInField03

      -- Check blank
      IF @cActCartonID = ''
      BEGIN
         SET @nErrNo = 136264
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need carton ID
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Check blank
      IF @cCartonID <> @cActCartonID
      BEGIN
         SET @nErrNo = 136266
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff carton ID
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Confirm
      EXEC rdt.rdt_PickByCartonID_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cWaveKey,
         @cPWZone,
         @cCartonID,
         @cLOC,
         @cID, 
         @cSKU,
         @cLottable01,
         @cLottable02,
         @cLottable03,
         @dLottable04,
         @nQTY,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get next task in same LOC
      EXEC rdt.rdt_PickByCartonID_GetNextTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cWaveKey,
         @cPWZone,
         @cCartonID1,
         @cCartonID2,
         @cCartonID3,
         @cCartonID4,
         @cCartonID5,
         @cCartonID6,
         @cCartonID7,
         @cCartonID8,
         @cCartonID9,
         @cLOC,
         @cID           OUTPUT,
         @cPosition     OUTPUT,
         @cCartonID     OUTPUT,
         @cSKU          OUTPUT,
         @cSKUDescr     OUTPUT,
         @cLottable01   OUTPUT,
         @cLottable02   OUTPUT,
         @cLottable03   OUTPUT,
         @dLottable04   OUTPUT,
         @nTaskQTY      OUTPUT, 
         @nTotalQTY     OUTPUT, 
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT

      IF @nErrNo = 0 -- More task
      BEGIN
         SET @nQTY = 0

         -- Prepare previous screen var
         SET @cOutField01 = @cID
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)
         SET @cOutField05 = @cLottable01
         SET @cOutField06 = @cLottable02
         SET @cOutField07 = @cLottable03
         SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
         SET @cOutField09 = @nTaskQTY
         SET @cOutField10 = '0'-- QTY
         SET @cOutField11 = '' -- SKU
         SET @cOutField12 = CAST( @nTotalQTY AS NVARCHAR( 5))
         SET @cOutField13 = LEFT( @cPosition, 2)

         -- Go to SKU, QTY screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         GOTO Quit
      END
      
      -- Get task in next LOC
      ELSE
      BEGIN
         -- If no task at same location, check if any different loc to pick
         SET @cSuggLOC = ''
         EXEC rdt.rdt_PickByCartonID_GetNextLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cWaveKey,
            @cPWZone,
            @cCartonID1,
            @cCartonID2,
            @cCartonID3,
            @cCartonID4,
            @cCartonID5,
            @cCartonID6,
            @cCartonID7,
            @cCartonID8,
            @cCartonID9,
            @cLOC,   -- Current location
            @cSuggLOC  OUTPUT,
            @nErrNo    OUTPUT,
            @cErrMsg   OUTPUT

         IF @nErrNo = 0
         BEGIN
            -- Still have task, go to next LOC
            SET @cOutField01 = @cSuggLOC
            SET @cOutField02 = '' -- LOC

            -- Go to LOC screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END
         ELSE
         BEGIN
            -- No more task, go to carton ID screen
            SET @cOutField01 = @cCartonID1
            SET @cOutField02 = @cCartonID2
            SET @cOutField03 = @cCartonID3
            SET @cOutField04 = @cCartonID4
            SET @cOutField05 = @cCartonID5
            SET @cOutField06 = @cCartonID6
            SET @cOutField07 = @cCartonID7
            SET @cOutField08 = @cCartonID8
            SET @cOutField09 = @cCartonID9

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonID1

            -- Go to carton ID screen
            SET @nScn = @nScn - 3
            SET @nStep = @nStep - 3
         END
      END

      -- Clean up err msg (otherwise appear on destination screen)
      SET @nErrNo = 0
      SET @cErrMsg = ''
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)
      SET @cOutField05 = @cLottable01
      SET @cOutField06 = @cLottable02
      SET @cOutField07 = @cLottable03
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField09 = @nTaskQTY
      SET @cOutField10 = @nQTY
      SET @cOutField11 = '' -- SKU
      SET @cOutField12 = CAST( @nTotalQTY AS NVARCHAR( 5))
      SET @cOutField13 = LEFT( @cPosition, 2)

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

Step_6_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN       
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, ' + 
            ' @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, ' + 
            ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cWaveKey       NVARCHAR( 10), ' +
            ' @cPWZone        NVARCHAR( 10), ' +
            ' @cCartonID1     NVARCHAR( 20), ' +
            ' @cCartonID2     NVARCHAR( 20), ' +
            ' @cCartonID3     NVARCHAR( 20), ' +
            ' @cCartonID4     NVARCHAR( 20), ' +
            ' @cCartonID5     NVARCHAR( 20), ' +
            ' @cCartonID6     NVARCHAR( 20), ' +
            ' @cCartonID7     NVARCHAR( 20), ' +
            ' @cCartonID8     NVARCHAR( 20), ' +
            ' @cCartonID9     NVARCHAR( 20), ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cPosition      NVARCHAR( 10), ' +
            ' @cSuggLOC       NVARCHAR( 10), ' +
            ' @cSuggSKU       NVARCHAR( 20), ' +
            ' @nTaskQTY       INT,           ' +
            ' @nTotalQTY      INT,           ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @nQTY           INT,           ' +
            ' @cLottable01    NVARCHAR( 18), ' +
            ' @cLottable02    NVARCHAR( 18), ' +
            ' @cLottable03    NVARCHAR( 18), ' +
            ' @dLottable04    DATETIME,      ' +
            ' @tVar           VariableTable  READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, 
            @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
            @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         SET @cOutField15 = @cExtendedInfo 
      END
   END
END
GOTO Quit


/********************************************************************************
Scn = 5356. Confirm Short Pick?
   OPTION   (field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 1)

      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 136262
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option require
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 136263
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      IF @cOption = '1' -- Yes
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cPosition
         SET @cOutField02 = @cCartonID -- Suggest carton ID
         SET @cOutField03 = '' -- Carton ID

         -- Go to carton ID screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1

         -- Flow thru if only 1 carton
         SET @nCartonIDCount = 0
         IF @cCartonID1 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID2 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID3 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID4 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID5 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID6 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID7 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID8 <> '' SET @nCartonIDCount += 1 
         IF @cCartonID9 <> '' SET @nCartonIDCount += 1 
         IF @nCartonIDCount = 1  
         BEGIN
            SET @cFlowThruScreen = '1'
            SET @cInField03 = @cCartonID
         END
         
         GOTO Step_7_Quit
      END
   END
   
   -- Prep next screen var
   SET @cOutField01 = @cID
   SET @cOutField02 = @cSKU
   SET @cOutField03 = SUBSTRING(@cSKUDescr, 1, 20)
   SET @cOutField04 = SUBSTRING(@cSKUDescr, 21, 20)
   SET @cOutField05 = @cLottable01
   SET @cOutField06 = @cLottable02
   SET @cOutField07 = @cLottable03
   SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
   SET @cOutField09 = @nTaskQTY
   SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))
   SET @cOutField11 = ''  -- SKU
   SET @cOutField12 = CAST( @nTotalQTY AS NVARCHAR( 5))
   SET @cOutField13 = LEFT( @cPosition, 2)

   -- Go to SKU QTY screen
   SET @nScn  = @nScn - 2
   SET @nStep = @nStep - 2

Step_7_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN       
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, ' + 
            ' @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, ' + 
            ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cWaveKey       NVARCHAR( 10), ' +
            ' @cPWZone        NVARCHAR( 10), ' +
            ' @cCartonID1     NVARCHAR( 20), ' +
            ' @cCartonID2     NVARCHAR( 20), ' +
            ' @cCartonID3     NVARCHAR( 20), ' +
            ' @cCartonID4     NVARCHAR( 20), ' +
            ' @cCartonID5     NVARCHAR( 20), ' +
            ' @cCartonID6     NVARCHAR( 20), ' +
            ' @cCartonID7     NVARCHAR( 20), ' +
            ' @cCartonID8     NVARCHAR( 20), ' +
            ' @cCartonID9     NVARCHAR( 20), ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cPosition      NVARCHAR( 10), ' +
            ' @cSuggLOC       NVARCHAR( 10), ' +
            ' @cSuggSKU       NVARCHAR( 20), ' +
            ' @nTaskQTY       INT,           ' +
            ' @nTotalQTY      INT,           ' +
            ' @cLOC           NVARCHAR( 10), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @nQTY           INT,           ' +
            ' @cLottable01    NVARCHAR( 18), ' +
            ' @cLottable02    NVARCHAR( 18), ' +
            ' @cLottable03    NVARCHAR( 18), ' +
            ' @dLottable04    DATETIME,      ' +
            ' @tVar           VariableTable  READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 7, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cWaveKey, @cPWZone, @cCartonID1, @cCartonID2, @cCartonID3, @cCartonID4, @cCartonID5, @cCartonID6, @cCartonID7, @cCartonID8, @cCartonID9, 
            @cCartonID, @cPosition, @cSuggLOC, @cSuggSKU, @nTaskQTY, @nTotalQTY, @cLOC, @cSKU, @nQTY, @cLottable01, @cLottable02, @cLottable03, @dLottable04, 
            @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      
         SET @cOutField15 = @cExtendedInfo 
      END
   END

   IF @cFlowThruScreen = '1'
      IF @nStep = 6
         GOTO Step_6 
END
GOTO Quit


/********************************************************************************
Scn = 5357. Skip LOC?
   Option (field01)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 136268
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option require
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 136269
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         -- Get next loc if ConfirmLoc is blank
         EXEC rdt.rdt_PickByCartonID_GetNextLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cWaveKey,
            @cPWZone,
            @cCartonID1,
            @cCartonID2,
            @cCartonID3,
            @cCartonID4,
            @cCartonID5,
            @cCartonID6,
            @cCartonID7,
            @cCartonID8,
            @cCartonID9,
            @cSuggLOC,
            @cSuggLOC  OUTPUT,
            @nErrNo    OUTPUT,
            @cErrMsg   OUTPUT

         -- No more loc
         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   -- Prepare next screen var
   SET @cOutField01 = @cSuggLOC
   SET @cOutField02 = '' -- LOC

   -- Go to LOC screen
   SET @nScn = @nScn - 4
   SET @nStep = @nStep - 4
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg   = @cErrMsg,
      Func     = @nFunc,
      Step     = @nStep,
      Scn      = @nScn,

      V_WaveKey    = @cWaveKey,
      V_Zone       = @cPWZone,
      V_CaseID     = @cCartonID,
      V_LOC        = @cLOC,
      V_ID         = @cID, 
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKUDescr,
      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_TaskQTY    = @nTaskQTY,
      V_QTY        = @nQTY,

      V_String1    = @cSuggLOC,
      V_String2    = @cSuggSKU,
      V_String3    = @cPosition,  

      V_String10   = @cCartonID1,
      V_String11   = @cCartonID2,
      V_String12   = @cCartonID3,
      V_String13   = @cCartonID4,
      V_String14   = @cCartonID5,
      V_String15   = @cCartonID6,
      V_String16   = @cCartonID7,
      V_String17   = @cCartonID8,
      V_String18   = @cCartonID9,

      V_String21   = @cExtendedValidateSP,
      V_String22   = @cExtendedUpdateSP,
      V_String23   = @cExtendedInfoSP,
      V_String24   = @cExtendedInfo,
      V_String25   = @cWaveOptional,

      V_Integer1   = @nTotalQTY,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO