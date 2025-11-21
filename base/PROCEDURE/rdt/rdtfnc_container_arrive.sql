SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_Container_Arrive                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: To Track the time the Container Arrive at Guard House       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2009-10-14   1.0  Vicky      Created                                 */
/* 2014-06-12   1.1  James      Change function id due to conflict with */
/*                              other module (james01)                  */
/* 2016-10-05   1.2  James      Perf tuning                             */
/* 2018-10-30   1.3  TungGH     Performance                             */
/* 2019-01-02   1.4  Leong      INC0527496 - Bug Fix.                   */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_Container_Arrive] (
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

   @cContainerNo        NVARCHAR( 20),
   @cUserID             NVARCHAR( 18),
   @cTrailerNo          NVARCHAR( 20),
   @cDriverLicenseNo    NVARCHAR( 20),

   @cErrMsg1            NVARCHAR(20),
   @cErrMsg2            NVARCHAR(20),
   @cErrMsg3            NVARCHAR(20),
   @cErrMsg4            NVARCHAR(20),

   @cMenutype           NVARCHAR(1),

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

   @cContainerNo      = V_String1,
   @cTrailerNo        = V_String2,
   @cDriverLicenseNo  = V_String3,

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
   @nStep_1 INT, @nScn_1 INT

SELECT
   @nStep_1 = 1, @nScn_1 = 2130


IF @nFunc = 856   -- (james01)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 856
   IF @nStep = 1  GOTO Step_1           -- Scn = 2130. Container #
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 856
********************************************************************************/
Step_Start:
BEGIN
   -- Prepare label screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''

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

   IF @nMenu = 55
   BEGIN
     SET @cMenuType = 'I'
   END
   ELSE IF @nMenu = 56
   BEGIN
     SET @cMenuType = 'O'
   END

   EXEC RDT.rdt_STD_EventLog
     @cActionType   = '1', -- Sign In function
     @cUserID       = @cUserName,
     @nMobileNo     = @nMobile,
     @nFunctionID   = @nFunc,
     @cFacility     = @cFacility,
     @cStorerKey    = '',
     @cRefNo4       = @cMenuType,
     @nStep         = @nStep

   -- Go to Label screen
   SET @nScn = @nScn_1
   SET @nStep = @nStep_1
   GOTO Quit

   Step_Start_Fail:
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit

/***********************************************************************************
Scn = 2137. Container # screen
   CONTAINER NO       (field01)
   TRAILER NO         (field02)
   DRIVER LICENSE NO  (field03)
***********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN

     -- Screen mapping
     SET @cContainerNo = RTRIM(@cInField01)
     SET @cTrailerNo   = RTRIM(@cInField02)
     SET @cDriverLicenseNo = RTRIM(@cInField03)

     IF ISNULL(RTRIM(@cContainerNo), '') = ''
     BEGIN
         SET @nErrNo = 67916
         SET @cErrMsg = rdt.rdtgetmessage( 67916, @cLangCode, 'DSP') -- Container Req -- INC0527496
         GOTO Step_ContainerNo_Fail
     END

     IF ISNULL(RTRIM(@cTrailerNo), '') = ''
     BEGIN
         SET @nErrNo = 67917
         SET @cErrMsg = rdt.rdtgetmessage( 67917, @cLangCode, 'DSP') -- Trailer# Req -- INC0527496
         GOTO Step_TrailerNo_Fail
     END

     IF @nMenu = 55
     BEGIN
       SET @cMenuType = 'I'
     END
     ELSE IF @nMenu = 56
     BEGIN
       SET @cMenuType = 'O'
     END

     IF NOT EXISTS (SELECT 1 FROM RDT.rdtSTDEventLog WITH (NOLOCK)
                    WHERE EventType = 9 AND ActionType = 13
                    AND ContainerNo = RTRIM(@cContainerNo) -- INC0527496
                    AND TruckID = RTRIM(@cTrailerNo))      -- INC0527496
     BEGIN
         EXEC RDT.rdt_STD_EventLog
             @cActionType      = '13', -- Container Arrive
             @cUserID          = @cUserName,
             @nMobileNo        = @nMobile,
             @nFunctionID      = @nFunc,
             @cFacility        = @cFacility,
             @cStorerKey       = '',
             @cContainerNo     = @cContainerNo,
             @cTruckID         = @cTrailerNo,
             @cLicenseNo       = @cDriverLicenseNo,
             @cRefNo4          = @cMenuType,
             @nStep            = @nStep

             SET @nErrNo = 67918
             SET @cErrMsg = rdt.rdtgetmessage( 67918, @cLangCode, 'DSP') -- Container Arrived
     END
     ELSE
     BEGIN
         SET @nErrNo = 67919
         SET @cErrMsg = rdt.rdtgetmessage( 67919, @cLangCode, 'DSP') -- Container Exists
         GOTO Step_1_Fail
     END

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      SET @cContainerNo = ''
      SET @cTrailerNo = ''
      SET @cDriverLicenseNo = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

     -- Screen mapping
     SET @nScn = @nScn
     SET @nStep = @nStep
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      SET @cContainerNo = ''
      SET @cTrailerNo = ''
      SET @cDriverLicenseNo = ''

      IF @nMenu = 55
      BEGIN
        SET @cMenuType = 'I'
      END
      ELSE IF @nMenu = 56
      BEGIN
        SET @cMenuType = 'O'
      END

      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '9', -- Sign Out function
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = '',
         @cRefNo4       = @cMenuType,
         @nStep         = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

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

   Step_ContainerNo_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cContainerNo = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO Quit
   END

   Step_TrailerNo_Fail:
   BEGIN
      SET @cOutField01 = @cContainerNo
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      SET @cTrailerNo = ''

      EXEC rdt.rdtSetFocusField @nMobile, 2
      GOTO Quit
   END

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      SET @cContainerNo = ''
      SET @cTrailerNo = ''
      SET @cDriverLicenseNo = ''

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
      --UserName       = @cUserName,

      V_String1      = @cContainerNo,
      V_String2      = @cTrailerNo,
      V_String3      = @cDriverLicenseNo,

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