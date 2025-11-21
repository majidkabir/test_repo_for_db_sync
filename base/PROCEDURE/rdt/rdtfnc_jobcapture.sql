SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_JobCapture                                         */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Serial no capture by ext orderkey + sku                           */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 30-08-2018  1.0  Ung       WMS-6051 Created                                */
/* 13-02-2019  1.1  James     WMS-7795 Add capture reference (james01)        */
/* 11-04-2019  1.2  James     WMS-8603 Enable capture reference field         */
/*                            repeatly until press esc (james02)              */
/* 02-07-2019  1.3  James     WMS-9493 Add display jobtype (james03)          */
/* 25-05-2021  1.4  Chermaine WMS-17049 Add codelkup to validate              */
/*                            column in scn6 (cc01)                           */
/* 10-09-2020  1.5  YeeKung   WMS-15084 Change username and loc length        */
/*                            (yeekung01)                                     */
/* 27-07-2021  1.7  YeeKung   JSM-11627 go through step 1 to ref screen       */
/*                            (yeekung02)                                     */
/* 23-08-2021  1.8  Ung       WMS-18427                                       */
/*                            Add QTY UOM                                     */
/*                            Add CaptureQTY = M                              */ 
/*                            Add CaptureData = M                             */ 
/*                            Add Confirm end job to all scenario             */
/*                            Change CaptureData = 1, confirm end job flow    */
/*                            Clean up source                                 */
/* 14-06-2022  1.9  Ung       WMS-19943 Add JobCapColC.Notes as script        */
/* 13-12-2022  2.0  Ung       WMS-21400 Add ExtendedValidateSP at step 1      */  
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_JobCapture] (
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc var
DECLARE
   @nRowRef     INT,
   @cSQL        NVARCHAR( MAX),
   @cSQLParam   NVARCHAR( MAX), 
   @tVar        VariableTable

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @cUserName   NVARCHAR( 10),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),

   @cQTYUOM     NVARCHAR( 10), 
   @nFromStep   INT, 
   @nFromScn    INT, 

   @cUserID       NVARCHAR( 30), 
   @cJobType      NVARCHAR( 20),
   @cLOC          NVARCHAR( 30), 
   @cQTY          NVARCHAR( 5),
   @cCaptureLOC   NVARCHAR( 1),
   @cCaptureQTY   NVARCHAR( 1),
   @cStart        NVARCHAR( 10),
   @cEnd          NVARCHAR( 10),
   @cDuration     NVARCHAR( 5),
   @cShort        NVARCHAR( 10), 
   @cUDF01        NVARCHAR( 60),
   @cUDF02        NVARCHAR( 60),
   @cUDF03        NVARCHAR( 60),
   @cUDF04        NVARCHAR( 60),
   @cUDF05        NVARCHAR( 60),
   @cCaptureData  NVARCHAR( 60),
   @cColVal       NVARCHAR( 10),

   @cExtendedValidateSP NVARCHAR( 20),

   @cRef01        NVARCHAR( 60),
   @cRef02        NVARCHAR( 60),
   @cRef03        NVARCHAR( 60),
   @cRef04        NVARCHAR( 60),
   @cRef05        NVARCHAR( 60),

   @nRecCount     INT, 

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
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,
   @cUserName   = UserName,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,

   @cQTYUOM     = V_UOM, 
   @nFromStep   = V_FromStep, 
   @nFromScn    = V_FromScn, 
   
   @cUserID       = V_String1,
   @cJobType      = V_String2,
   @cLOC          = V_String3,
   @cQTY          = V_String4,
   @cCaptureLOC   = V_String5,
   @cCaptureQTY   = V_String6,
   @cStart        = V_String7,
   @cEnd          = V_String8,
   @cDuration     = V_String9,
   @cShort        = V_String10,

   @cUDF01        = V_String11,
   @cUDF02        = V_String12,
   @cUDF03        = V_String13,
   @cUDF04        = V_String14,
   @cUDF05        = V_String15,
   @cCaptureData  = V_String16,
   @cColVal       = V_String17, 

   @cExtendedValidateSP = V_String21,

   @cRef01        = V_String41,
   @cRef02        = V_String42,
   @cRef03        = V_String43,
   @cRef04        = V_String44,
   @cRef05        = V_String45,
   
   @nRecCount     = V_Integer1, 

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

FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_UserID           INT,  @nScn_UserID         INT,
   @nStep_JobType          INT,  @nScn_JobType        INT,
   @nStep_JobLOC           INT,  @nScn_JobLOC         INT,
   @nStep_CaptureQTY       INT,  @nScn_CaptureQTY     INT,
   @nStep_ConfirmJobEnd    INT,  @nScn_ConfirmJobEnd  INT,
   @nStep_CaptureData      INT,  @nScn_CaptureData    INT

SELECT
   @nStep_UserID           = 1,  @nScn_UserID         = 5220,
   @nStep_JobType          = 2,  @nScn_JobType        = 5221,
   @nStep_JobLOC           = 3,  @nScn_JobLOC         = 5222,
   @nStep_CaptureQTY       = 4,  @nScn_CaptureQTY     = 5223,
   @nStep_ConfirmJobEnd    = 5,  @nScn_ConfirmJobEnd  = 5224,
   @nStep_CaptureData      = 6,  @nScn_CaptureData    = 5225

IF @nFunc = 705 -- Job capture
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start          -- Func = 705
   IF @nStep = 1 GOTO Step_UserID         -- 5220 User ID
   IF @nStep = 2 GOTO Step_JobType        -- 5221 Job type
   IF @nStep = 3 GOTO Step_JobLOC         -- 5222 Job LOC
   IF @nStep = 4 GOTO Step_CaptureQTY     -- 5223 Capture QTY
   IF @nStep = 5 GOTO Step_ConfirmJobEnd  -- 5224 Confirm job end?
   IF @nStep = 6 GOTO Step_CaptureData    -- 5225 Capture data
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 705. Menu
********************************************************************************/
Step_Start:
BEGIN
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
      
   -- Set the entry point
   SET @nScn = @nScn_UserID
   SET @nStep = @nStep_UserID

   -- Prepare next screen var
   SET @cOutField01 = '' -- User ID

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 5220. User ID
   User ID  (Field01, input)
********************************************************************************/
Step_UserID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUserID = @cInField01

      -- Check blank
      IF @cUserID = ''
      BEGIN
         SET @nErrNo = 128501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need UserID
         GOTO Quit
      END

      -- Clear variable here, user might not go back to menu screen
      -- before start using with another user id
      SET @cJobType = ''
      SET @cLOC = ''
      SET @cQTY = ''
      SET @cRef01 = ''
      SET @cRef02 = ''
      SET @cRef03 = ''
      SET @cRef04 = ''
      SET @cRef05 = ''
      SET @cStart = ''

      -- Get user info
      DECLARE @cStatus NVARCHAR(10)
      SELECT @cStatus = Short
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'JOBCapUser'
         AND Code = @cUserID
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility

      -- Check order valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 128502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UserID
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check status
      IF @cStatus = '9'
      BEGIN
         SET @nErrNo = 128503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive user
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cUserID',      @cUserID),
               ('@cJobType',     @cJobType),
               ('@cQTY',         @cQTY),
               ('@cLOC',         @cLOC),
               ('@cStart',       @cStart),
               ('@cEnd',         @cEnd),
               ('@cDuration',    @cDuration),
               ('@cRef01',       @cRef01),
               ('@cRef02',       @cRef02),
               ('@cRef03',       @cRef03),
               ('@cRef04',       @cRef04),
               ('@cRef05',       @cRef05)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@tVar            VariableTable READONLY, ' +
               '@nErrNo          INT           OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cOutField01 = '' -- User ID
               GOTO Quit
            END
         END
      END

      -- Get job info
      DECLARE @dStart DATETIME
      SELECT
         @nRowRef = RowRef,
         @cJobType = TaskCode,
         @cLOC = Location,
         @cQTY = QTY,
         @cStatus = Status, 
         @dStart = StartDate
      FROM rdt.rdtWATLog WITH (NOLOCK)
      WHERE Module = 'JOBCAPTURE'
         AND UserName = @cUserID
         AND StorerKey = @cStorerKey
         AND Facility = @cFacility
         AND Status = '0'

      -- No open job, start a new one
      IF @@ROWCOUNT = 0
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cUserID
         SET @cOutField02 = '' -- JobType

         SET @nScn = @nScn_JobType
         SET @nStep = @nStep_JobType
         
         GOTO Quit
      END
      
      ELSE -- A job had opened
      BEGIN
         -- Format start
         SET @cStart = SUBSTRING( CONVERT( NVARCHAR(30), @dStart, 0), 5, 2) + ' ' + RIGHT( CONVERT( NVARCHAR(20), @dStart, 0), 7)
         SET @nRecCount = 0

         -- Get job type
         SELECT
            @cCaptureQTY = UDF02,
            @cCaptureData = UDF03,
            @cShort = ISNULL( Short, '')
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'JOBCapType'
            AND Code = @cJobType
            AND StorerKey = @cStorerKey
            AND Code2 = @cFacility

         -- Close job if already captured some data
         IF @cCaptureData = 'M'
         BEGIN
           -- Get captured data count
            SELECT @nRecCount = COUNT(1)
            FROM rdt.rdtWATLog WITH (NOLOCK)
            WHERE Module = 'JOBCAPTURE'
               AND UserName = @cUserID
               AND StorerKey = @cStorerKey
               AND Facility = @cFacility
               AND TaskCode = @cJobType
               AND Status = '3'

            IF @nRecCount > 0
            BEGIN
               -- Confirm job end
               IF CHARINDEX( 'C', @cShort) > 0
               BEGIN
                  -- Prep next screen var
                  SET @cOutField01 = '' -- Option
                  SET @cOutField02 = @cJobType

                  SET @nFromScn = @nScn_UserID
                  SET @nFromStep = @nStep_UserID

                  SET @nScn = @nScn_ConfirmJobEnd
                  SET @nStep = @nStep_ConfirmJobEnd
   
                  GOTO Quit
               END
               ELSE
               BEGIN
                  -- Confirm
                  EXEC rdt.rdt_JobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'END',
                     @cUserID   = @cUserID,
                     @cJobType  = @cJobType,
                     @cQTY      = @cQTY,
                     @cLOC      = @cLOC,
                     @cStart    = @cStart    OUTPUT,
                     @cEnd      = @cEnd      OUTPUT,
                     @cDuration = @cDuration OUTPUT,
                     @nErrNo    = @nErrNo    OUTPUT,
                     @cErrMsg   = @cErrMsg   OUTPUT
                  IF @nErrNo <> 0
                     GOTO Quit

                  -- Prep next screen var
                  SET @cOutField01 = '' --  UserID
                  SET @cOutField02 = @cStart
                  SET @cOutField03 = @cEnd
                  SET @cOutField04 = @cDuration
                  SET @cOutField05 = @cJobType

                  SET @nScn = @nScn_UserID
                  SET @nStep = @nStep_UserID

                  GOTO Quit
               END
            END
         END
         
         -- Job that need to capture QTY
         IF @cCaptureQTY IN ('1', 'M')
         BEGIN
            SET @cQTYUOM = ''
            SELECT @cQTYUOM = ISNULL( Short, '')
            FROM CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'JOBCapQTY'
               AND Code = @cJobType
               AND StorerKey = @cStorerKey
               AND Code2 = @cFacility
            
            -- Prep next screen var
            SET @cOutField01 = @cUserID
            SET @cOutField02 = @cJobType
            SET @cOutField03 = @cLOC
            SET @cOutField04 = '' -- QTY
            SET @cOutField05 = @cQTYUOM

            SET @nScn = @nScn_CaptureQTY
            SET @nStep = @nStep_CaptureQTY

            GOTO Quit
         END
         
         -- Job that need to capture data (1 OR multiple records)
         ELSE IF @cCaptureData IN ('1', 'M')
         BEGIN
            -- Get data columns
            SELECT
               @cUDF01 = UDF01,
               @cUDF02 = UDF02,
               @cUDF03 = UDF03,
               @cUDF04 = UDF04,
               @cUDF05 = UDF05,
               @cColVal = ISNULL( Short, 0)
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'JOBCapCol'
               AND Code = @cJobType
               AND StorerKey = @cStorerKey
               AND Code2 = @cFacility

            -- Check data column had setup
            IF ISNULL( @cUDF01, '') = '' AND
               ISNULL( @cUDF02, '') = '' AND
               ISNULL( @cUDF03, '') = '' AND
               ISNULL( @cUDF04, '') = '' AND
               ISNULL( @cUDF05, '') = ''
            BEGIN
               SET @nErrNo = 128510
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Column
               GOTO Quit
            END

            -- Get statistics
            IF @cCaptureData = '1'
               SET @nRecCount = 0
            ELSE
               -- Get captured data count
               SELECT @nRecCount = COUNT(1)
               FROM rdt.rdtWATLog WITH (NOLOCK)
               WHERE Module = 'JOBCAPTURE'
                  AND UserName = @cUserID
                  AND StorerKey = @cStorerKey
                  AND Facility = @cFacility
                  AND TaskCode = @cJobType
                  AND Status = '3'

            -- Prepare next screen var
            SET @cOutField01 = @cUDF01
            SET @cOutField02 = ''
            SET @cOutField03 = @cUDF02
            SET @cOutField04 = ''
            SET @cOutField05 = @cUDF03
            SET @cOutField06 = ''
            SET @cOutField07 = @cUDF04
            SET @cOutField08 = ''
            SET @cOutField09 = @cUDF05
            SET @cOutField10 = ''
            SET @cOutField11 = CASE WHEN @nRecCount > 0 THEN CAST( @nRecCount AS NVARCHAR( 5)) ELSE '' END

            -- Enable / disable field
            SET @cFieldAttr02 = CASE WHEN ISNULL( @cUDF01, '') = '' THEN 'O' ELSE '' END
            SET @cFieldAttr04 = CASE WHEN ISNULL( @cUDF02, '') = '' THEN 'O' ELSE '' END
            SET @cFieldAttr06 = CASE WHEN ISNULL( @cUDF03, '') = '' THEN 'O' ELSE '' END
            SET @cFieldAttr08 = CASE WHEN ISNULL( @cUDF04, '') = '' THEN 'O' ELSE '' END
            SET @cFieldAttr10 = CASE WHEN ISNULL( @cUDF05, '') = '' THEN 'O' ELSE '' END

            IF @cFieldAttr02 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 2  ELSE
            IF @cFieldAttr04 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 4  ELSE
            IF @cFieldAttr06 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 6  ELSE
            IF @cFieldAttr08 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 8  ELSE
            IF @cFieldAttr10 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 10 

            SET @nScn = @nScn_CaptureData
            SET @nStep = @nStep_CaptureData

            GOTO Quit
         END
         
         -- Job that don't need capture anything
         ELSE
         BEGIN
            -- Confirm job end
            IF CHARINDEX( 'C', @cShort) > 0
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = '' -- Option
               SET @cOutField02 = @cJobType

               SET @nFromScn = @nScn_UserID
               SET @nFromStep = @nStep_UserID

               SET @nScn = @nScn_ConfirmJobEnd
               SET @nStep = @nStep_ConfirmJobEnd
            END
            ELSE
            BEGIN
               -- Confirm
               EXEC rdt.rdt_JobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'END',
                  @cUserID   = @cUserID,
                  @cJobType  = @cJobType,
                  @cQTY      = @cQTY,
                  @cLOC      = @cLOC,
                  @cStart    = @cStart    OUTPUT,
                  @cEnd      = @cEnd      OUTPUT,
                  @cDuration = @cDuration OUTPUT,
                  @nErrNo    = @nErrNo    OUTPUT,
                  @cErrMsg   = @cErrMsg   OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit

               -- Prep next screen var
               SET @cOutField01 = '' --  UserID
               SET @cOutField02 = @cStart
               SET @cOutField03 = @cEnd
               SET @cOutField04 = @cDuration
               SET @cOutField05 = @cJobType

               SET @nScn = @nScn_UserID  
               SET @nStep = @nStep_UserID
            END
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
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 5221. Job type
   USER ID  (Field01)
   JOB TYPE (Field02, input)
********************************************************************************/
Step_JobType:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cJobType = @cInField02

      -- Check blank
      IF @cJobType = ''
      BEGIN
         SET @nErrNo = 128504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need JobType
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get job type
      SELECT @cCaptureLOC = UDF01
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'JOBCapType'
         AND Code = @cJobType
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility

      -- Check SKU valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 128505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidJobType
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cUserID',      @cUserID),
               ('@cJobType',     @cJobType),
               ('@cQTY',         @cQTY),
               ('@cLOC',         @cLOC),
               ('@cStart',       @cStart),
               ('@cEnd',         @cEnd),
               ('@cDuration',    @cDuration),
               ('@cRef01',       @cRef01),
               ('@cRef02',       @cRef02),
               ('@cRef03',       @cRef03),
               ('@cRef04',       @cRef04),
               ('@cRef05',       @cRef05)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@tVar            VariableTable READONLY, ' +
               '@nErrNo          INT           OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cOutField02 = ''
               GOTO Quit
            END
         END
      END

      -- Job (start) need to capture location
      IF @cCaptureLOC = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cUserID
         SET @cOutField02 = @cJobType
         SET @cOutField03 = '' -- LOC

         SET @nScn = @nScn_JobLOC
         SET @nStep = @nStep_JobLOC

         GOTO Quit
      END

      -- Confirm
      EXEC rdt.rdt_JobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'START',
         @cUserID   = @cUserID,
         @cJobType  = @cJobType,
         @cStart    = @cStart    OUTPUT,
         @cEnd      = @cEnd      OUTPUT,
         @cDuration = @cDuration OUTPUT,
         @nErrNo    = @nErrNo    OUTPUT,
         @cErrMsg   = @cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = '' -- UserID
      SET @cOutField02 = @cStart
      SET @cOutField03 = @cEnd
      SET @cOutField04 = @cDuration
      SET @cOutField05 = @cJobType

      SET @nScn = @nScn_UserID
      SET @nStep = @nStep_UserID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- UserID
      SET @cOutField02 = '' -- Start
      SET @cOutField03 = '' -- End
      SET @cOutField04 = '' -- Duration
      SET @cOutField05 = '' -- JobType

      SET @nScn = @nScn_UserID
      SET @nStep = @nStep_UserID
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 5222. LOC
   USER ID  (Field01)
   JOB TYPE (Field02)
   LOC      (Field03, input)
********************************************************************************/
Step_JobLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField03

      -- Check blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 128506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Check LOC valid
      IF NOT EXISTS( SELECT TOP 1 1
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'JOBCapLOC'
            AND Code = @cLOC
            AND StorerKey = @cStorerKey
            AND Code2 = @cFacility)
      BEGIN
         SET @nErrNo = 128507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Confirm
      EXEC rdt.rdt_JobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'START',
         @cUserID   = @cUserID,
         @cJobType  = @cJobType,
         @cLOC      = @cLOC,
         @cStart    = @cStart    OUTPUT,
         @cEnd      = @cEnd      OUTPUT,
         @cDuration = @cDuration OUTPUT,
         @nErrNo    = @nErrNo    OUTPUT,
         @cErrMsg   = @cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = '' -- UserID
      SET @cOutField02 = @cStart
      SET @cOutField03 = @cEnd
      SET @cOutField04 = @cDuration
      SET @cOutField05 = @cJobType

      SET @nScn = @nScn_UserID
      SET @nStep = @nStep_UserID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cUserID
      SET @cOutField02 = '' -- JobType

      SET @nScn  = @nScn_JobType
      SET @nStep = @nStep_JobType
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 5223. QTY
   USER ID  (Field01)
   JOB TYPE (Field02)
   LOC      (Field03)
   QTY      (Field04, input)
********************************************************************************/
Step_CaptureQTY:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cQTY = @cInField04

      -- Check blank
      IF @cQTY = ''
      BEGIN
         SET @nErrNo = 128508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY
         GOTO Quit
      END

      -- Check QTY valid
      IF rdt.rdtIsValidQty( @cQTY, 1) = 0
      BEGIN
         SET @nErrNo = 128509
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END

      -- Job that need to capture data (1 OR multiple records)
      IF @cCaptureData IN ('1', 'M')
      BEGIN
         -- Get data columns
         SELECT
            @cUDF01 = UDF01,
            @cUDF02 = UDF02,
            @cUDF03 = UDF03,
            @cUDF04 = UDF04,
            @cUDF05 = UDF05,
            @cColVal = ISNULL( Short, 0)
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'JOBCapCol'
            AND Code = @cJobType
            AND StorerKey = @cStorerKey
            AND Code2 = @cFacility

         -- Check data column had setup
         IF ISNULL( @cUDF01, '') = '' AND
            ISNULL( @cUDF02, '') = '' AND
            ISNULL( @cUDF03, '') = '' AND
            ISNULL( @cUDF04, '') = '' AND
            ISNULL( @cUDF05, '') = ''
         BEGIN
            SET @nErrNo = 128510
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Column
            GOTO Quit
         END

         -- Prepare next screen var
         SET @cOutField01 = @cUDF01
         SET @cOutField02 = ''
         SET @cOutField03 = @cUDF02
         SET @cOutField04 = ''
         SET @cOutField05 = @cUDF03
         SET @cOutField06 = ''
         SET @cOutField07 = @cUDF04
         SET @cOutField08 = ''
         SET @cOutField09 = @cUDF05
         SET @cOutField10 = ''
         SET @cOutField11 = CASE WHEN @nRecCount > 0 THEN CAST( @nRecCount AS NVARCHAR( 5)) ELSE '' END
   
         -- Enable / disable field
         SET @cFieldAttr02 = CASE WHEN ISNULL( @cUDF01, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN ISNULL( @cUDF02, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr06 = CASE WHEN ISNULL( @cUDF03, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr08 = CASE WHEN ISNULL( @cUDF04, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr10 = CASE WHEN ISNULL( @cUDF05, '') = '' THEN 'O' ELSE '' END

         IF @cFieldAttr02 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 2  ELSE
         IF @cFieldAttr04 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 4  ELSE
         IF @cFieldAttr06 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 6  ELSE
         IF @cFieldAttr08 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 8  ELSE
         IF @cFieldAttr10 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 10 

         SET @nScn = @nScn_CaptureData
         SET @nStep = @nStep_CaptureData

         GOTO Quit
      END

      -- Confirm job end
      IF CHARINDEX( 'C', @cShort) > 0
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = '' -- Option
         SET @cOutField02 = @cJobType

         SET @nFromScn = @nScn_CaptureQTY
         SET @nFromStep = @nStep_CaptureQTY

         SET @nScn = @nScn_ConfirmJobEnd
         SET @nStep = @nStep_ConfirmJobEnd
         
         GOTO Quit
      END
      
      -- Confirm
      EXEC rdt.rdt_JobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'END',
         @cUserID   = @cUserID,
         @cJobType  = @cJobType,
         @cQTY      = @cQTY,
         @cLOC      = @cLOC,
         @cStart    = @cStart    OUTPUT,
         @cEnd      = @cEnd      OUTPUT,
         @cDuration = @cDuration OUTPUT,
         @nErrNo    = @nErrNo    OUTPUT,
         @cErrMsg   = @cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = '' -- UserID
      SET @cOutField02 = @cStart
      SET @cOutField03 = @cEnd
      SET @cOutField04 = @cDuration
      SET @cOutField05 = @cJobType

      SET @nScn = @nScn_UserID
      SET @nStep = @nStep_UserID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- User ID
      SET @cOutField02 = @cStart
      SET @cOutField03 = '' -- End
      SET @cOutField04 = '' -- Duration
      SET @cOutField05 = @cJobType

      -- Go back user ID screen
      SET @nScn  = @nScn_UserID
      SET @nStep = @nStep_UserID
   END
END
GOTO Quit


/********************************************************************************
Step 5. Screen = 5224. Confirm job end
   CONFIRM JOB END?
   OPTION (Field01, input)
********************************************************************************/
Step_ConfirmJobEnd:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR(1)

      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 128513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need option
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 128514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cOption = '1' -- YES
      BEGIN
         IF @cCaptureData = '1'
         BEGIN
            -- Confirm
            EXEC rdt.rdt_JobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'DATA',
               @cUserID   = @cUserID,
               @cJobType  = @cJobType,
               @cStart    = @cStart    OUTPUT,
               @cEnd      = @cEnd      OUTPUT,
               @cDuration = @cDuration OUTPUT,
               @nErrNo    = @nErrNo    OUTPUT,
               @cErrMsg   = @cErrMsg   OUTPUT,
               @cRef01    = @cRef01,
               @cRef02    = @cRef02,
               @cRef03    = @cRef03,
               @cRef04    = @cRef04,
               @cRef05    = @cRef05, 
               @cQTY      = @cQTY         
            IF @nErrNo <> 0
               GOTO Quit
         END
         
         -- Confirm
         EXEC rdt.rdt_JobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'END',
            @cUserID   = @cUserID,
            @cJobType  = @cJobType,
            @cQTY      = @cQTY,
            @cLOC      = @cLOC,
            @cStart    = @cStart    OUTPUT,
            @cEnd      = @cEnd      OUTPUT,
            @cDuration = @cDuration OUTPUT,
            @nErrNo    = @nErrNo    OUTPUT,
            @cErrMsg   = @cErrMsg   OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare next screen var
         SET @cOutField01 = '' -- UserID
         SET @cOutField02 = @cStart
         SET @cOutField03 = @cEnd
         SET @cOutField04 = @cDuration
         SET @cOutField05 = @cJobType

         SET @nScn = @nScn_UserID
         SET @nStep = @nStep_UserID

         GOTO Quit
      END

      IF @cOption = '9' -- NO
      BEGIN
         IF @nFromStep = @nStep_UserID
         BEGIN
            -- Job need capture QTY
            IF @cCaptureQTY = 'M'
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = @cUserID
               SET @cOutField02 = @cJobType
               SET @cOutField03 = @cLOC
               SET @cOutField04 = '' --@cQTY
               SET @cOutField05 = @cQTYUOM

               SET @nScn = @nScn_CaptureQTY
               SET @nStep = @nStep_CaptureQTY
               
               GOTO Quit
            END
            
            -- Job need capture data
            IF @cCaptureData = 'M'
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cUDF01
               SET @cOutField02 = ''
               SET @cOutField03 = @cUDF02
               SET @cOutField04 = ''
               SET @cOutField05 = @cUDF03
               SET @cOutField06 = ''
               SET @cOutField07 = @cUDF04
               SET @cOutField08 = ''
               SET @cOutField09 = @cUDF05
               SET @cOutField10 = ''
               SET @cOutField11 = CASE WHEN @nRecCount > 0 THEN CAST( @nRecCount AS NVARCHAR( 5)) ELSE '' END
               
               -- Enable / disable field
               SET @cFieldAttr02 = CASE WHEN ISNULL( @cUDF01, '') = '' THEN 'O' ELSE '' END
               SET @cFieldAttr04 = CASE WHEN ISNULL( @cUDF02, '') = '' THEN 'O' ELSE '' END
               SET @cFieldAttr06 = CASE WHEN ISNULL( @cUDF03, '') = '' THEN 'O' ELSE '' END
               SET @cFieldAttr08 = CASE WHEN ISNULL( @cUDF04, '') = '' THEN 'O' ELSE '' END
               SET @cFieldAttr10 = CASE WHEN ISNULL( @cUDF05, '') = '' THEN 'O' ELSE '' END

               IF @cFieldAttr02 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 2  ELSE
               IF @cFieldAttr04 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 4  ELSE
               IF @cFieldAttr06 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 6  ELSE
               IF @cFieldAttr08 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 8  ELSE
               IF @cFieldAttr10 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 10 

               SET @nScn = @nScn_CaptureData
               SET @nStep = @nStep_CaptureData

               GOTO Quit
            END
         END
      END
   END

   IF @nFromStep = @nStep_CaptureData
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cUDF01
      SET @cOutField02 = @cRef01
      SET @cOutField03 = @cUDF02
      SET @cOutField04 = @cRef02
      SET @cOutField05 = @cUDF03
      SET @cOutField06 = @cRef03
      SET @cOutField07 = @cUDF04
      SET @cOutField08 = @cRef04
      SET @cOutField09 = @cUDF05
      SET @cOutField10 = @cRef05
      SET @cOutField11 = CASE WHEN @nRecCount > 0 THEN CAST( @nRecCount AS NVARCHAR( 5)) ELSE '' END
   
      -- Enable / disable field
      SET @cFieldAttr02 = CASE WHEN ISNULL( @cUDF01, '') = '' THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN ISNULL( @cUDF02, '') = '' THEN 'O' ELSE '' END
      SET @cFieldAttr06 = CASE WHEN ISNULL( @cUDF03, '') = '' THEN 'O' ELSE '' END
      SET @cFieldAttr08 = CASE WHEN ISNULL( @cUDF04, '') = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN ISNULL( @cUDF05, '') = '' THEN 'O' ELSE '' END

      IF @cFieldAttr02 <> 'O' AND @cRef01 = '' EXEC rdt.rdtSetFocusField @nMobile, 2  ELSE
      IF @cFieldAttr04 <> 'O' AND @cRef02 = '' EXEC rdt.rdtSetFocusField @nMobile, 4  ELSE
      IF @cFieldAttr06 <> 'O' AND @cRef03 = '' EXEC rdt.rdtSetFocusField @nMobile, 6  ELSE
      IF @cFieldAttr08 <> 'O' AND @cRef04 = '' EXEC rdt.rdtSetFocusField @nMobile, 8  ELSE
      IF @cFieldAttr10 <> 'O' AND @cRef05 = '' EXEC rdt.rdtSetFocusField @nMobile, 10 
      
      SET @nStep = @nStep_CaptureData
      SET @nScn = @nScn_CaptureData
   END
   
   ELSE IF @nFromStep = @nStep_CaptureQTY
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cUserID
      SET @cOutField02 = @cJobType
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cQTY
      SET @cOutField05 = @cQTYUOM

      SET @nScn = @nScn_CaptureQTY
      SET @nStep = @nStep_CaptureQTY
   END
   
   ELSE IF @nFromStep = @nStep_UserID
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- User ID
      SET @cOutField02 = @cStart
      SET @cOutField03 = '' -- End
      SET @cOutField04 = '' -- Duration
      SET @cOutField05 = @cJobType

      SET @nScn = @nScn_UserID
      SET @nStep = @nStep_UserID
   END
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 5225. Capture data
   Label1 (field01)
   Data1  (field02, input)
   Label2 (field03)
   Data2  (field04, input)
   Label3 (field05)
   Data3  (field06, input)
   Label4 (field07)
   Data4  (field08, input)
   Label5 (field09)
   Data5  (field10, input)
********************************************************************************/
Step_CaptureData:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cRef01 = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cRef02 = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cRef03 = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END
      SET @cRef04 = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE @cOutField08 END
      SET @cRef05 = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE @cOutField10 END

      -- Retain key-in value
      SET @cOutField02 = @cRef01
      SET @cOutField04 = @cRef02
      SET @cOutField06 = @cRef03
      SET @cOutField08 = @cRef04
      SET @cOutField10 = @cRef05

      -- Check blank
      IF ISNULL( @cRef01, '') = '' AND
         ISNULL( @cRef02, '') = '' AND
         ISNULL( @cRef03, '') = '' AND
         ISNULL( @cRef04, '') = '' AND
         ISNULL( @cRef05, '') = ''
      BEGIN
         SET @nErrNo = 128511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value Required
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Validate field
      IF @cColVal = 'V' -- V=Validate
      BEGIN
         DECLARE @cCode       NVARCHAR( 10)
         DECLARE @cCheck      NVARCHAR( 20)
         DECLARE @cData       NVARCHAR( 60)
         DECLARE @curData     CURSOR
         DECLARE @nCursorPos  INT

         SET @curData = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Code, Short, ISNULL( Notes, '')
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'JOBCapColC' -- Note: there is a C suffix, not the usual JOBCapCol
               AND Storerkey = @cStorerKey
               AND Code IN (@cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05)
               AND Code2 = @nFunc
            ORDER BY 
               CASE WHEN Code = @cUDF01 THEN 1
                    WHEN Code = @cUDF02 THEN 2
                    WHEN Code = @cUDF03 THEN 3
                    WHEN Code = @cUDF04 THEN 4
                    WHEN Code = @cUDF05 THEN 5
                    ELSE 6
               END
         OPEN @curData
         FETCH NEXT FROM @curData INTO @cCode, @cCheck, @cSQL
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get data
            IF @cCode = @cUDF01 SELECT @cData = @cRef01, @nCursorPos = 2  ELSE
            IF @cCode = @cUDF02 SELECT @cData = @cRef02, @nCursorPos = 4  ELSE
            IF @cCode = @cUDF03 SELECT @cData = @cRef03, @nCursorPos = 6  ELSE
            IF @cCode = @cUDF04 SELECT @cData = @cRef04, @nCursorPos = 8  ELSE
            IF @cCode = @cUDF05 SELECT @cData = @cRef05, @nCursorPos = 10

            -- Check require field
            IF @cCheck <> ''
            BEGIN
               -- Check blank
               IF CHARINDEX( 'R', @cCheck) > 0 AND @cData = ''
               BEGIN
                  SET @nErrNo = 128512
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need data
                  EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                  GOTO Quit
               END

               -- Check format
               IF CHARINDEX( 'F', @cCheck) > 0
               BEGIN
                  IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Data' + @cCode, @cData) = 0
                  BEGIN
                     SET @nErrNo = 128515
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
                     EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                     GOTO Quit
                  END
               END
            END
            
            IF @cSQL <> ''
            BEGIN
               DELETE @tVar
               INSERT INTO @tVar (Variable, Value) VALUES
                  ('@cUserID',      @cUserID),
                  ('@cJobType',     @cJobType),
                  ('@cQTY',         @cQTY),
                  ('@cLOC',         @cLOC),
                  ('@cStart',       @cStart),
                  ('@cEnd',         @cEnd),
                  ('@cDuration',    @cDuration),
                  ('@cCode',        @cCode), 
                  ('@cRef01',       @cRef01),
                  ('@cRef02',       @cRef02),
                  ('@cRef03',       @cRef03),
                  ('@cRef04',       @cRef04),
                  ('@cRef05',       @cRef05)

               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@tVar            VariableTable READONLY, ' +
                  '@nErrNo          INT           OUTPUT,   ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT    '

               BEGIN TRY
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                     GOTO Quit
                  END
               END TRY
               BEGIN CATCH
                  SET @nErrNo = 128516
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Script error
                  EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                  GOTO Quit
               END CATCH
            END

            FETCH NEXT FROM @curData INTO @cCode, @cCheck, @cSQL
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            DELETE @tVar
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cUserID',      @cUserID),
               ('@cJobType',     @cJobType),
               ('@cQTY',         @cQTY),
               ('@cLOC',         @cLOC),
               ('@cStart',       @cStart),
               ('@cEnd',         @cEnd),
               ('@cDuration',    @cDuration),
               ('@cRef01',       @cRef01),
               ('@cRef02',       @cRef02),
               ('@cRef03',       @cRef03),
               ('@cRef04',       @cRef04),
               ('@cRef05',       @cRef05)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@tVar            VariableTable READONLY, ' +
               '@nErrNo          INT           OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cOutField02 = ''
               GOTO Quit
            END
         END
      END

      -- Job need capture data
      IF @cCaptureData = '1' -- Single record
      BEGIN
         -- Confirm end job
         IF CHARINDEX( 'C', @cShort) > 0
         BEGIN
            -- Enable field
            SET @cFieldAttr02 = ''
            SET @cFieldAttr04 = ''
            SET @cFieldAttr06 = ''
            SET @cFieldAttr08 = ''
            SET @cFieldAttr10 = ''  

            -- Prep next screen var
            SET @cOutField01 = '' -- Option
            SET @cOutField02 = @cJobType

            SET @nFromScn = @nScn_CaptureData
            SET @nFromStep = @nStep_CaptureData

            SET @nScn = @nScn_ConfirmJobEnd
            SET @nStep = @nStep_ConfirmJobEnd
            
            GOTO Quit
         END
      END
      
      -- Confirm
      EXEC rdt.rdt_JobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'DATA',
         @cUserID   = @cUserID,
         @cJobType  = @cJobType,
         @cStart    = @cStart    OUTPUT,
         @cEnd      = @cEnd      OUTPUT,
         @cDuration = @cDuration OUTPUT,
         @nErrNo    = @nErrNo    OUTPUT,
         @cErrMsg   = @cErrMsg   OUTPUT,
         @cRef01    = @cRef01,
         @cRef02    = @cRef02,
         @cRef03    = @cRef03,
         @cRef04    = @cRef04,
         @cRef05    = @cRef05, 
         @cQTY      = @cQTY         
      IF @nErrNo <> 0
         GOTO Quit

      SET @nRecCount = @nRecCount + 1

      -- Job need capture data
      IF @cCaptureData = '1' -- Single record
      BEGIN
         -- Confirm
         EXEC rdt.rdt_JobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'END',
            @cUserID   = @cUserID,
            @cJobType  = @cJobType,
            @cQTY      = @cQTY,
            @cLOC      = @cLOC,
            @cStart    = @cStart    OUTPUT,
            @cEnd      = @cEnd      OUTPUT,
            @cDuration = @cDuration OUTPUT,
            @nErrNo    = @nErrNo    OUTPUT,
            @cErrMsg   = @cErrMsg   OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Enable field
         SET @cFieldAttr02 = ''
         SET @cFieldAttr04 = ''
         SET @cFieldAttr06 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr10 = ''  

         -- Prepare next screen var
         SET @cOutField01 = '' -- User ID
         SET @cOutField02 = @cStart
         SET @cOutField03 = @cEnd
         SET @cOutField04 = @cDuration
         SET @cOutField05 = @cJobType

         SET @nScn = @nScn_UserID
         SET @nStep = @nStep_UserID
      END

      ELSE IF @cCaptureQTY = 'M'
      BEGIN
         -- Enable field
         SET @cFieldAttr02 = ''
         SET @cFieldAttr04 = ''
         SET @cFieldAttr06 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr10 = ''  
            
         -- Prep next screen var
         SET @cOutField01 = @cUserID
         SET @cOutField02 = @cJobType
         SET @cOutField03 = @cLOC
         SET @cOutField04 = '' -- @cQTY
         SET @cOutField05 = @cQTYUOM

         SET @nScn = @nScn_CaptureQTY
         SET @nStep = @nStep_CaptureQTY
      END
      
      ELSE IF @cCaptureData = 'M'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cUDF01
         SET @cOutField02 = ''
         SET @cOutField03 = @cUDF02
         SET @cOutField04 = ''
         SET @cOutField05 = @cUDF03
         SET @cOutField06 = ''
         SET @cOutField07 = @cUDF04
         SET @cOutField08 = ''
         SET @cOutField09 = @cUDF05
         SET @cOutField10 = ''
         SET @cOutField11 = CASE WHEN @nRecCount > 0 THEN CAST( @nRecCount AS NVARCHAR( 5)) ELSE '' END

         -- Enable / disable field
         SET @cFieldAttr02 = CASE WHEN ISNULL( @cUDF01, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN ISNULL( @cUDF02, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr06 = CASE WHEN ISNULL( @cUDF03, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr08 = CASE WHEN ISNULL( @cUDF04, '') = '' THEN 'O' ELSE '' END
         SET @cFieldAttr10 = CASE WHEN ISNULL( @cUDF05, '') = '' THEN 'O' ELSE '' END

         IF @cFieldAttr02 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 2  ELSE
         IF @cFieldAttr04 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 4  ELSE
         IF @cFieldAttr06 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 6  ELSE
         IF @cFieldAttr08 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 8  ELSE
         IF @cFieldAttr10 <> 'O' EXEC rdt.rdtSetFocusField @nMobile, 10 
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''         

      /*
         1 QTY, 1 DATA              --> Back to QTY screen
         1 QTY, M Data, no data yet --> Back to QTY screen
         1 QTY, M Data, have data   --> Back to user screen
         M QTY, 1 Data              --> Back to QTY screen
         M QTY, M Data              --> Back to QTY screen
         No QTY                     --> Back to user screen
      */
      IF @cCaptureQTY = '' OR
        (@cCaptureQTY = '1' AND @nRecCount > 0)
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- User ID
         SET @cOutField02 = @cStart
         SET @cOutField03 = '' -- End
         SET @cOutField04 = '' -- Duration
         SET @cOutField05 = @cJobType

         SET @nScn = @nScn_UserID
         SET @nStep = @nStep_UserID
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cUserID
         SET @cOutField02 = @cJobType
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cQTY
         SET @cOutField05 = @cQTYUOM

         SET @nScn = @nScn_CaptureQTY
         SET @nStep = @nStep_CaptureQTY
      END
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,

      V_UOM      = @cQTYUOM, 
      V_FromStep = @nFromStep,
      V_FromScn  = @nFromScn,
                 
      V_String1  = @cUserID,
      V_String2  = @cJobType,
      V_String3  = @cLOC,
      V_String4  = @cQTY,
      V_String5  = @cCaptureLOC,
      V_String6  = @cCaptureQTY,
      V_String7  = @cStart,
      V_String8  = @cEnd,
      V_String9  = @cDuration,
      V_String10 = @cShort,
      V_String11 = @cUDF01,
      V_String12 = @cUDF02,
      V_String13 = @cUDF03,
      V_String14 = @cUDF04,
      V_String15 = @cUDF05,
      V_String16 = @cCaptureData,
      V_String17 = @cColVal,

      V_String21 = @cExtendedValidateSP,

      V_String41 = @cRef01,
      V_String42 = @cRef02,
      V_String43 = @cRef03,
      V_String44 = @cRef04,
      V_String45 = @cRef05,

      V_Integer1 = @nRecCount, 

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