SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_Clock_In_Out                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2009-06-08   1.0  Vicky      Created                                 */
/* 2014-02-06   1.1  James      SOS301379 - Hide long msg scn (james01) */
/* 2014-08-14   1.2  James      SOS317982-Add extended validate(james02)*/
/* 2016-09-30   1.3  Ung        Performance tuning                      */
/* 2018-10-17   1.4  Tung GH    Performance                             */
/* 2023-08-22   1.5  James      WMS-23368 Add EventLog (james03)        */
/************************************************************************/
CREATE   PROC [RDT].[rdtfnc_Clock_In_Out] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variables
DECLARE
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 250),
   @i              INT,
   @nTask          INT,
   @cParentScn     NVARCHAR( 3),
   @cOption        NVARCHAR( 1),
   @cXML           NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @nPrevScn            INT,
   @nPrevStep           INT,

   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),

   @cLocation           NVARCHAR( 32),
   @cUserID             NVARCHAR( 18),
   @cClickCnt           NVARCHAR(  1),

   @cErrMsg1            NVARCHAR(20),
   @cErrMsg2            NVARCHAR(20),
   @cErrMsg3            NVARCHAR(20),
   @cErrMsg4            NVARCHAR(20),

   @cExtendedValidateSP NVARCHAR( 20), -- (jame02)
   @cExtendedUpdateSP   NVARCHAR( 20), -- (jame02)
   @cSQL                NVARCHAR( MAX),-- (jame02)
   @cSQLParam           NVARCHAR( MAX),-- (jame02)
   @nNextScn            INT,           -- (jame02)
   @nNextStep           INT,           -- (jame02)


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

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,


   @cLocation        = V_LOC,
   @cClickCnt        = V_String1,

   @cExtendedValidateSP = V_String2, -- (james02)
   @cExtendedUpdateSP   = V_String3, -- (james02)

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

   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_1          INT,  @nScn_1          INT,
   @nStep_2          INT,  @nScn_2          INT

SELECT
   @nStep_1          = 1,  @nScn_1          = 704,
   @nStep_2          = 2,  @nScn_2          = 705



IF @nFunc = 701
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 715
   IF @nStep = 1  GOTO Step_1           -- Scn = 704. Location
   IF @nStep = 2  GOTO Step_2           -- Scn = 705. USER ID
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 715
********************************************************************************/
Step_Start:
BEGIN

   -- (james02)
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   -- Prepare label screen var
   SET @cOutField01 = ''

   SET @cFieldAttr01 = ''
   SET @cFieldAttr02 = ''
   SET @cFieldAttr03 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr05 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr07 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr09 = ''
   SET @cFieldAttr10 = ''
   SET @cFieldAttr11 = ''
   SET @cFieldAttr12 = ''
   SET @cFieldAttr13 = ''
   SET @cFieldAttr14 = ''
   SET @cFieldAttr15 = ''

   SET @cClickCnt = 0

   -- Go to Label screen
   SET @nScn = @nScn_1
   SET @nStep = @nStep_1

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
         
   GOTO Quit

   Step_Start_Fail:
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- LOC
   END
END
GOTO Quit



/***********************************************************************************
Scn = 704. LOC screen
   Location       (field01)
***********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLocation = @cInField01 -- SKU

      -- Extended validate (james02)
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cLocation, @cUserID, @cClickCnt, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@nInputKey      INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cLocation      NVARCHAR( 10), ' +
               '@cUserID        NVARCHAR( 18), ' +
               '@cClickCnt      NVARCHAR( 1),  ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cLocation, @cUserID, @cClickCnt, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtGetMessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_1_Fail
            END
         END
      END

      -- Prep USERID screen var
      SET @cOutField01 = ''

      -- Go to USERID screen
      SET @nScn = @nScn_2
      SET @nStep = @nStep_2

      EXEC RDT.rdt_STD_EventLog
       @cActionType = '16',   -- Activity tracking
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep_1,
       @cLocation   = @cLocation
   END

   IF @nInputKey = 0 -- Esc or No
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
      SET @cOutField01 = '' -- Option
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = '' -- SKU
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU
      GOTO Quit
   END

END
GOTO Quit


/********************************************************************************
Scn = 704. USER ID screen
   USER ID       (field01)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN

      -- Screen mapping
      SET @cUserID = @cInField01 -- SKU

      -- Extended validate (james02)
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cLocation, @cUserID, @cClickCnt, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@nInputKey      INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cLocation      NVARCHAR( 10), ' +
               '@cUserID        NVARCHAR( 18), ' +
               '@cClickCnt      NVARCHAR( 1),  ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cLocation, @cUserID, @cClickCnt, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtGetMessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_2_Fail
            END
         END
      END

      -- Extended update (james02)
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cLocation, @cUserID, @cClickCnt, @nNextScn OUTPUT, @nNextStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,       '     +
               '@nFunc        INT,       '     +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,       '     +
               '@nInputKey    INT,       '     +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cLocation    NVARCHAR( 10), ' +
               '@cUserID      NVARCHAR( 18), ' +
               '@cClickCnt    NVARCHAR( 1),  ' +
               '@nNextScn         INT OUTPUT, ' +
               '@nNextStep        INT OUTPUT, ' +
               '@nErrNo       INT OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cLocation, @cUserID, @cClickCnt, @nNextScn OUTPUT, @nNextStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtGetMessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_2_Fail
            END
            ELSE
            BEGIN
               SET @nScn = @nNextScn
               SET @nStep = @nNextStep
            END
         END
      END
      ELSE
      BEGIN
         IF @cClickCnt = 0
         BEGIN
            IF EXISTS ( SELECT 1 FROM RDT.rdtWATLog WITH (NOLOCK)
                        WHERE UserName = @cUserID
                        AND   Location = @cLocation
                        AND   STATUS = '0')
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'ShowMsgInNewScn', @cStorerKey) = 1
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg1 = '50024'
                  SET @cErrMsg2 = 'CLOCKED-IN'
                  SET @cErrMsg3 = 'ENTER TO CONFIRM'
                  SET @cErrMsg4 = 'CLOCK-OUT'
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                     SET @cErrMsg4 = ''
                  END
                  SET @cClickCnt = 1
                  GOTO Step_2_Continue
               END

               UPDATE RDT.rdtWATLog WITH (ROWLOCK)
               SET STATUS = '9',
                   EndDate = GETDATE()
               WHERE UserName = @cUserID
               AND   Location = @cLocation
               AND   Status = '0'

               SET @cErrMsg = 'Goodbye ' + RTRIM(@cUserID)

               SET @cClickCnt = 0

               -- Initialize
               SET @cUserID = ''
               SET @cOutField01 = ''

               -- Screen mapping
               SET @nScn = @nScn
               SET @nStep = @nStep

               GOTO Quit
            END
            ELSE IF EXISTS ( SELECT 1 FROM RDT.rdtWATLog WITH (NOLOCK)
                             WHERE UserName = @cUserID
                             AND   STATUS = '9')
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'ShowMsgInNewScn', @cStorerKey) = 1
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg1 = '50025'
                  SET @cErrMsg2 = 'CLOCKED-OUT'
                  SET @cErrMsg3 = 'ENTER TO CONFIRM'
                  SET @cErrMsg4 = 'CLOCK-IN'
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                     SET @cErrMsg4 = ''
                  END

                  SET @cClickCnt = 2
                  GOTO Step_2_Continue
               END
               ELSE
               BEGIN
                  INSERT INTO RDT.rdtWATLog (Module, UserName, Location, EndDate, StorerKey)
                  VALUES ('CLK', @cUserID, @cLocation, '', @cStorerKey)

                  SET @cErrMsg = 'Welcome ' + RTRIM(@cUserID)

                  SET @cClickCnt = 0

                  -- Initialize
                  SET @cUserID = ''
                  SET @cOutField01 = ''

                  -- Screen mapping
                  SET @nScn = @nScn
                  SET @nStep = @nStep

                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               SET @cClickCnt = 2
            END
         END

         -- Insert rdtWATLog
         IF @cClickCnt = 1
         BEGIN
            UPDATE RDT.rdtWATLog WITH (ROWLOCK)
            SET STATUS = '9',
                EndDate = GETDATE()
            WHERE UserName = @cUserID
            AND   Location = @cLocation
            AND   Status = '0'

            SET @cErrMsg = 'Goodbye ' + RTRIM(@cUserID)

            SET @cClickCnt = 0
         END
         ELSE IF @cClickCnt = 2
         BEGIN
            INSERT INTO RDT.rdtWATLog (Module, UserName, Location, EndDate, StorerKey)
            VALUES ('CLK', @cUserID, @cLocation, '', @cStorerKey)

            SET @cErrMsg = 'Welcome ' + RTRIM(@cUserID)

            SET @cClickCnt = 0
         END

         -- Initialize
         SET @cUserID = ''
         SET @cOutField01 = ''

         -- Screen mapping
         SET @nScn = @nScn
         SET @nStep = @nStep
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare SKU screen var
      SET @cOutField01 = '' -- LOC
      SET @cLocation = ''

      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU

      -- Go to prev screen
      SET @nScn = @nScn_1
      SET @nStep = @nStep_1
   END
   GOTO Quit

   Step_2_Continue:
   BEGIN
      SET @cOutField01 = @cUserID -- UserID
      EXEC rdt.rdtSetFocusField @nMobile, 1
      SET @nScn = @nScn
      SET @nStep = @nStep
      GOTO Quit
   END

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = '' -- UserID
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO Quit
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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,

      V_LOC          = @cLocation,
      V_String1      = @cClickCnt,
      V_String2      = @cExtendedValidateSP, -- (james02)
      V_String3      = @cExtendedUpdateSP,   -- (james02)

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

      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15
   WHERE Mobile = @nMobile

END



GO