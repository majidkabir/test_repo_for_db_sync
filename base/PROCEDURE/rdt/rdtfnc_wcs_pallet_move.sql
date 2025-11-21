SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_WCS_Pallet_Move                              */
/* Copyright      : IDS                                                 */
/* FBR: 116248                                                          */
/* Purpose: WCS Pallet floor move                                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 15-Sep-2008  1.0  James      Created                                 */
/* 18-Mar-2016  1.1  James      Add Pallet ID validation (james01)      */
/* 30-Sep-2016  1.2  Ung        Performance tuning                      */
/* 25-Oct-2018  1.3  Gan        Performance tuning                      */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_WCS_Pallet_Move](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep  INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,
   @nCurScn        INT,  -- Current screen variable
   @nCurStep       INT,  -- Current step variable
   @bSuccess       INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cPrinter       NVARCHAR( 10),
   @cID            NVARCHAR( 18),
   @cFromLoc       NVARCHAR( 10),
   @cToLoc         NVARCHAR( 10),
   @cFromFloor     NVARCHAR( 3),
   @cToFloor       NVARCHAR( 3),
   @cStorerGroup   NVARCHAR( 20),
   
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

DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),
   @cDecodeLabelNo       NVARCHAR( 20),
   @c_LabelNo            NVARCHAR( 32)

DECLARE @c_ExecStatements     nvarchar(4000)
      , @c_ExecArguments      nvarchar(4000)

-- Getting Mobile information
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
   @cID              = V_ID,

   @cFromLoc         = V_String1,
   @cToLoc           = V_String2,

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

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1821  -- WCS Pallet Floor Move
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0   GOTO Step_0 -- Menu. Func = 1821
   IF @nStep = 1   GOTO Step_1 -- Scn = 4240. Pallet, From Loc, To Loc

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1620
********************************************************************************/
Step_0:
BEGIN

   -- Prepare next screen var
   SET @cOutField01 = '' -- ID
   SET @cOutField02 = '' -- From Loc
   SET @cOutField03 = '' -- To Loc

   -- Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Go to WaveKey screen
   SET @nScn = 4240
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 1870
   ID          (field01, input)
   From Loc    (field02, input)
   To Loc      (field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cID = @cInField01
      SET @cFromLoc = @cInField02
      SET @cToLoc = @cInField03

      -- Validate blank
      IF ISNULL(@cID, '') = ''
      BEGIN
         SET @nErrNo = 56151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Is Req
         GOTO Step_ID_Fail
      END

      -- Check from id format (james01)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0
      BEGIN
         SET @nErrNo = 56159
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_ID_Fail
      END

      -- Validate blank
      IF ISNULL(@cFromLoc, '') = ''
      BEGIN
         SET @nErrNo = 56152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --From Loc Req
         GOTO Step_FromLoc_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                      WHERE LOC = @cFromLoc
                      AND   Facility = @cFacility
                      AND   LocationCategory = 'ASRSINST')
      BEGIN
         SET @nErrNo = 56153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Loc Cat
         GOTO Step_FromLoc_Fail
      END

      SELECT @cFromFloor = [Floor]
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @cFromLoc
      AND   Facility = @cFacility
      AND   LocationCategory = 'ASRSINST'

      IF ISNULL( @cFromFloor, '') = ''
      BEGIN
         SET @nErrNo = 56154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup From Floor
         GOTO Step_FromLoc_Fail
      END

      -- Validate blank
      IF ISNULL(@cToLoc, '') = ''
      BEGIN
         SET @nErrNo = 56155
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --To Loc Req
         GOTO Step_ToLoc_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                      WHERE LOC = @cToLoc
                      AND   Facility = @cFacility
                      AND   LocationCategory = 'ASRSOUTST')
      BEGIN
         SET @nErrNo = 56156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Loc Cat
         GOTO Step_ToLoc_Fail
      END

      SELECT @cToFloor = [Floor]
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @cToLoc
      AND   Facility = @cFacility
      AND   LocationCategory = 'ASRSOUTST'

      IF ISNULL( @cToFloor, '') = ''
      BEGIN
         SET @nErrNo = 56157
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup To Floor
         GOTO Step_ToLoc_Fail
      END

      IF @cFromFloor = @cToFloor
      BEGIN
         SET @nErrNo = 56158
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same Floor
         SET @cFromLoc = ''
         SET @cToLoc = ''
         SET @cOutField01 = @cID
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      --Send message to WCS to swap the existing task for OLD pallet to NEW pallet
      --Start Call WCS message.  
      SET @nErrNo = 0

      EXEC isp_TCP_WCS_MsgProcess  
           @c_MessageName    = 'MOVE'
         , @c_MessageType    = 'SEND'
         , @c_OrigMessageID  = ''
         , @c_PalletID       = @cID
         , @c_FromLoc        = @cFromLOC
         , @c_ToLoc          = @cToLoc        
         , @c_Priority       = '5'
         , @b_debug          = 0
         , @b_Success        = @bSuccess    OUTPUT
         , @n_Err            = @nErrNo      OUTPUT
         , @c_ErrMsg         = @cErrMsg     OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SEND WCS FAIL
         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- ID
      SET @cOutField02 = '' -- From Loc
      SET @cOutField03 = '' -- To Loc
      
      EXEC rdt.rdtSetFocusField @nMobile, 1

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- ID
      SET @cOutField02 = '' -- From Loc
      SET @cOutField03 = '' -- To Loc
   END

   GOTO Quit

   Step_ID_Fail:
   BEGIN
      SET @cID = ''

      SET @cOutField01 = ''
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = @cToLoc
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO Quit
   END

   Step_FromLoc_Fail:
   BEGIN
      SET @cFromLoc = ''

      SET @cOutField01 = @cID
      SET @cOutField02 = ''
      SET @cOutField03 = @cToLoc
      EXEC rdt.rdtSetFocusField @nMobile, 2
      GOTO Quit
   END

   Step_ToLoc_Fail:
   BEGIN
      SET @cToLoc = ''

      SET @cOutField01 = @cID
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 3
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

      StorerKey    = V_StorerKey,
      Facility     = @cFacility,
      -- UserName     = @cUserName,
      Printer      = @cPrinter,

      V_ID         = @cID, 

      V_String1    = @cFromLoc,
      V_String2    = @cToLoc,

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