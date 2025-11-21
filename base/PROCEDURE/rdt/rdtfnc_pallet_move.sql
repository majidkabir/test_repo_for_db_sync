SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Pallet_Move                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Putaway to pack and hold                                    */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev   Author   Purposes                                   */
/* 2012-12-07 1.0   James    SOS257520 - Created                        */
/* 2016-09-30 1.1   Ung      Performance tuning                         */
/* 2018-10-11 1.2   TungGH   Performance                                */
/* 2024-07-16 1.3   CYU027   FCR-575                                    */
/* 2024-11-28 1.4   CYU027   FCR-1391 Levis                             */
/* 2025-01-10 1.5.0 Dennis   UWP-28966 BugFix                           */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_Pallet_Move] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Other var use in this stor proc
DECLARE
   @b_Success        INT,
   @c_errmsg         NVARCHAR( 250),
   @cChkFacility     NVARCHAR(5)

-- Variable for RDT.RDTMobRec
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,

   @cStorer          NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cPrinter         NVARCHAR( 10),
   @cUserName        NVARCHAR( 18),

   @cID              NVARCHAR( 20),
   @cToLOC           NVARCHAR( 10),
   @cDropLoc         NVARCHAR( 10),
   @cLOC             NVARCHAR( 10),
   @cSuggestLoc      NVARCHAR( 10),
   @cStatus          NVARCHAR( 10),
   @cDropID_Status   NVARCHAR( 10),
   @cSQL             NVARCHAR( MAX),
   @cSQLParam        NVARCHAR( MAX),
   
   @cLocationCategory      NVARCHAR( 10),
   @cSuggestLocSP          NVARCHAR(20),
   @cExtendedValidateSP    NVARCHAR( 20),

   @nTranCount       INT,
   
   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),

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
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorer    = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cLOC       = V_LOC,
   @cID        = V_ID,

   @cToLOC              = V_String1,
   @cSuggestLoc         = V_String2,
   @cSuggestLocSP       = V_String3,
   @cExtendedValidateSP = V_String4,

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1721
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 1791. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn  = 2990. ID, LOC
   IF @nStep = 2 GOTO Step_2   -- Scn  = 2991. Suggested LOC, final LOC
   IF @nStep = 3 GOTO Step_3   -- Scn  = 2992. Message
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1791. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorer,
      @nStep       = @nStep

   SET @cSuggestLocSP = rdt.RDTGetConfig( @nFunc, 'SuggestLocSP', @cStorer)
   IF @cSuggestLocSP = '0'
      SET @cSuggestLocSP = ''

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   -- Enable all fields
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

   -- Set the entry point
   SET @nScn = 3360
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3360
   ID  (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField01

      SET @nErrNo = 0
      EXEC [RDT].[rdtfnc_Pallet_Move_check_ID]
           @nMobile       = @nMobile,
           @nFunc         = @nFunc,
           @cLangCode     = @cLangCode,
           @nStep         = @nStep,
           @nInputKey     = @nInputKey,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorer,
           @cID           = @cID,
           @nErrNo        = @nErrNo      OUTPUT,
           @cErrMsg       = @cErrMsg     OUTPUT

      IF @nErrNo <> 0
         GOTO Step_1_Fail
      
      SET @cSuggestLoc = ''
      IF @cSuggestLocSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestLocSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestLocSP) +
                        ' @nMobile, @nFunc, @cLangCode, @cStorer, @nStep, @cID, @cSuggestLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
                    '@nMobile         INT,           ' +
                    '@nFunc           INT,           ' +
                    '@cLangCode       NVARCHAR( 3),  ' +
                    '@cStorer         NVARCHAR( 15), ' +
                    '@nStep           INT,           ' +
                    '@cID             NVARCHAR( 20), ' +
                    '@cSuggestLoc     NVARCHAR( 15) OUTPUT, ' +
                    '@nErrNo          INT           OUTPUT, ' +
                    '@cErrMsg         NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode,@cStorer, @nStep, @cID, @cSuggestLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

         -- Prepare next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = ''
      SET @cOutField03 = @cSuggestLoc

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorer,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cID = ''
      SET @cOutField01 = '' -- ID
   END

END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3361
   ID             (field01)
   Final LOC      (field02, input)
   Sugeest LOC    (field03)
********************************************************************************/
Step_2:
BEGIN
IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField02

      -- Check blank final LOC
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 78404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Final LOC
         GOTO Step_2_Fail
      END

      -- Check invalid from loc
      SELECT 
         @cChkFacility = Facility,  
         @cLocationCategory = LocationCategory 
      FROM LOC WITH (NOLOCK) 
      WHERE LOC = @cToLOC
      
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 78405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid LOC
         GOTO Step_2_Fail
      END

      -- Check from loc different facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 78406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff facility
         GOTO Step_2_Fail
      END

      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @cFacility, @cStorer, @cID, @cToLOC, @cSuggestLoc, ' +
                        ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
                    '@nMobile      INT,           ' +
                    '@nFunc        INT,           ' +
                    '@cLangCode    NVARCHAR( 3),  ' +
                    '@nStep        INT,           ' +
                    '@cFacility    NVARCHAR( 5),  ' +
                    '@cStorer      NVARCHAR( 15), ' +
                    '@cID          NVARCHAR( 18), ' +
                    '@cToLOC       NVARCHAR( 10), ' +
                    '@cSuggestLoc  NVARCHAR( 10), ' +
                    '@nErrNo             INT            OUTPUT, ' +
                    '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @cFacility, @cStorer, @cID, @cToLOC, @cSuggestLoc,
                 @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END

      SET @nErrNo = 0
      EXEC [RDT].[rdtfnc_Pallet_Move_update_ID]
           @nMobile           = @nMobile,
           @nFunc             = @nFunc,
           @cLangCode         = @cLangCode,
           @nStep             = @nStep,
           @nInputKey         = @nInputKey,
           @cFacility         = @cFacility,
           @cStorerKey        = @cStorer,
           @cID               = @cID,
           @cToLOC            = @cToLOC,
           @cLocationCategory = @cLocationCategory,
           @nErrNo            = @nErrNo      OUTPUT,
           @cErrMsg           = @cErrMsg     OUTPUT

      IF @nErrNo <> 0
         GOTO Step_2_Fail

      EXEC RDT.rdt_STD_EventLog  
        @cActionType   = '4', -- Move  
        @cUserID       = @cUserName,  
        @nMobileNo     = @nMobile,  
        @nFunctionID   = @nFunc,  
        @cFacility     = @cFacility,  
        @cStorerKey    = @cStorer,  
        @cID           = @cID,  
        @cToID         = @cID,
        @cLocation     = @cLOC,    
        @cToLocation   = @cToLOC,
        @nStep         = @nStep   
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen variable
      SET @cID = ''
      SET @cOutField01 = '' -- ID

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField02 = '' -- Final LOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 2992. Message screen
   Successful putaway
********************************************************************************/
Step_3:
BEGIN
   -- Prepare next screen variable
   SET @cID = ''
   SET @cOutField01 = '' -- ID

   -- Go back to ID screen
   SET @nScn  = @nScn  - 2
   SET @nStep = @nStep - 2
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
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      Facility  = @cFacility,
      StorerKey = @cStorer,
      -- UserName  = @cUserName,

      V_LOC      = @cLOC,

      V_ID       = @cID,
      
      V_String1  = @cToLOC,
      V_String2  = @cSuggestLoc,
      V_String3  = @cSuggestLocSP,
      V_String4  = @cExtendedValidateSP,


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