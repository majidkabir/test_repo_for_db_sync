SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_NIKEOffSiteReplen                            */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2023-04-26 1.0  Ung      WMS-22246 Created                           */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_NIKEOffSiteReplen] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

-- Misc variable

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT, 

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5), 
   
   @cWaveKey   NVARCHAR( 10), 
   @cPickZone  NVARCHAR( 10), 
   @cToArea    NVARCHAR( 10), 
   @cDropID    NVARCHAR( 20), 
   @cUCCNo     NVARCHAR( 20), 
   
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
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,

   @cWaveKey   = V_String1, 
   @cPickZone  = V_String2, 
   @cToArea    = V_String3, 
   @cDropID    = V_String4, 
   @cUCCNo     = V_String5, 

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01  = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02  = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03  = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04  = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05  = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06  = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07  = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08  = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09  = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10  = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11  = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12  = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13  = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14  = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15  = FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 656 -- Offsite replen
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = 656
   IF @nStep = 1 GOTO Step_1   -- Scn = 6250. Wave, pickzone, to area
   IF @nStep = 2 GOTO Step_2   -- Scn = 6251. DropID
   IF @nStep = 3 GOTO Step_3   -- Scn = 6252. UCC
   IF @nStep = 4 GOTO Step_4   -- Scn = 6253. Close pallet?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 656. Menu
********************************************************************************/
Step_0:
BEGIN
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   --Prep next screen var
   SET @cOutField01 = '' -- WaveKey
   SET @cOutField02 = '' -- PickZone
   SET @cOutField03 = '' -- ToArea

   SET @nScn = 6250
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 6250. Wave screen
   WAVEKEY  (field01, input)
   PICKZONE (field02, input)
   TOAREA   (field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWaveKey = @cInField01
      SET @cPickZone = @cInField02
      SET @cToArea = @cInField03

      -- Check Wave task
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND WaveKey = @cWaveKey
            AND TaskType = 'RPF'
            AND Status = '0')
      BEGIN
         SET @nErrNo = 199951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No task found
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END
      SET @cOutField01 = @cWaveKey
      
      -- Check PickZone task
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM dbo.TaskDetail TD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
         WHERE TD.StorerKey = @cStorerKey
            AND TD.WaveKey = @cWaveKey
            AND TD.TaskType = 'RPF'
            AND TD.Status = '0'
            AND LOC.PickZone = @cPickZone)
      BEGIN
         SET @nErrNo = 199952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No task found
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField02 = ''
         GOTO Quit
      END
      SET @cOutField02 = @cPickZone
      
      -- Check to area task
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM dbo.TaskDetail TD WITH (NOLOCK) 
            JOIN dbo.LOC FromLOC WITH (NOLOCK) ON (TD.FromLOC = FromLOC.LOC)
            JOIN dbo.LOC ToLOC WITH (NOLOCK) ON (TD.ToLOC = ToLOC.LOC)
            JOIN dbo.PickZone ToPicKZone WITH (NOLOCK) ON (ToLOC.PickZone = ToPicKZone.PickZone)
         WHERE TD.StorerKey = @cStorerKey
            AND TD.WaveKey = @cWaveKey
            AND TD.TaskType = 'RPF'
            AND TD.Status = '0'
            AND FromLOC.PickZone = @cPickZone
            AND ToPickZone.InLOC = @cToArea)
      BEGIN
         SET @nErrNo = 199953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No task found
         EXEC rdt.rdtSetFocusField @nMobile, 3
         SET @cOutField03 = ''
         GOTO Quit
      END
      SET @cOutField03 = @cToArea
      
      -- Prep next screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = @cToArea
      SET @cOutField04 = '' -- DropID
      
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey
      
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. scn = 6251. DropID screen
   WAVEKEY  (field01)
   PICKZONE (field02)
   TOAREA   (field03)
   DROPID   (field04, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropID = @cInField04

      -- Check blank
      IF @cDropID = ''
      BEGIN
         SET @nErrNo = 199954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
         GOTO Quit
      END
      
      -- Prepare next screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = '' -- UCC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- WaveKey
      SET @cOutField02 = '' -- PickZone
      SET @cOutField03 = '' -- ToArea

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Wavekey

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 6252. UCC screen
   DROPID   (field01)
   UCC      (field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCCNo = @cInField02
      
      -- Check UCC
      IF NOT EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCCNo AND Status IN ('1', '3'))
      BEGIN
         SET @nErrNo = 199955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No UCC found
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check UCC
      IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND CaseID = @cUCCNo AND Status > '0')
      BEGIN
         SET @nErrNo = 199956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC picked
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Confirm
      EXEC rdt.rdt_NIKEOffSiteReplen_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cWavekey, @cPickZone, @cToArea, @cDropID, @cUCCNo, 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      DECLARE @nTotalUCC INT
      SELECT @nTotalUCC = COUNT(1)
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND TaskType = 'RPF'
         AND DropID = @cDropID
         AND Status = '5' -- Picked
      
      -- Prep next screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = @cToArea
      SET @cOutField04 = '' -- Option
      SET @cOutField05 = CAST( @nTotalUCC AS NVARCHAR( 5))

      -- Go to prev screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 6253. Message
   WAVEKEY   (field01)
   PICKZONE  (field02)
   TOAREA    (field03)
   CLOSE PALLET?
   1 = YES
   9 = NO
   OPTION    (field04, input)
   TOTAL UCC (field05)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 2)

      -- Screen mapping
      SET @cOption = @cInField04
      
      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 199957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required
         GOTO Quit
      END

      -- Validate option
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 199958
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField04 = ''
         GOTO Quit
      END

      IF @cOption = '1' -- YES
      BEGIN
         -- Close pallet
         EXEC rdt.rdt_NIKEOffSiteReplen_ClosePallet @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cWavekey, @cPickZone, @cToArea, @cDropID, @cUCCNo, 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Check any tasks
         IF NOT EXISTS( SELECT TOP 1 1 
            FROM dbo.TaskDetail TD WITH (NOLOCK) 
               JOIN dbo.LOC FromLOC WITH (NOLOCK) ON (TD.FromLOC = FromLOC.LOC)
               JOIN dbo.LOC ToLOC WITH (NOLOCK) ON (TD.ToLOC = ToLOC.LOC)
               JOIN dbo.PickZone ToPicKZone WITH (NOLOCK) ON (ToLOC.PickZone = ToPicKZone.PickZone)
            WHERE TD.StorerKey = @cStorerKey
               AND TD.WaveKey = @cWaveKey
               AND TD.TaskType = 'RPF'
               AND TD.Status = '0'
               AND FromLOC.PickZone = @cPickZone
               AND ToPickZone.InLOC = @cToArea)
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- WaveKey
            SET @cOutField02 = '' -- PickZone
            SET @cOutField03 = '' -- ToArea
            
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Wavekey
            
            -- Go to Wave screen
            SET @nScn = @nScn - 3
            SET @nStep = @nStep - 3
         END
         ELSE
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cWaveKey
            SET @cOutField02 = @cPickZone
            SET @cOutField03 = @cToArea
            SET @cOutField04 = '' -- DropID
            
            -- Go to DropID screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END
         GOTO Quit
      END

      IF @cOption = '9' -- NO
      BEGIN
         /*
         If last carton (no more task), and operator chose not close pallet, the pallet can no longer be closed 
         At 1st screen it will be blocked with no task error, when try to go in again. 
         
         operator confirmed there is no concern of non full pallet being built, and loaded for transport
         the offsite is just beside the main warehouse
         
         -- Prepare next screen var
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = @cPickZone
         SET @cOutField03 = @cToArea
         SET @cOutField04 = '' -- DropID
         
         -- Go to DropID screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
         */
         
         -- Prepare next screen var
         SET @cOutField01 = @cDropID
         SET @cOutField02 = '' -- UCCNo

         -- Go to UCC screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = '' -- UCCNo

      -- Go to UCC screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
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

      StorerKey  = @cStorerKey,
      Facility   = @cFacility, 

      V_String1  = @cWaveKey, 
      V_String2  = @cPickZone, 
      V_String3  = @cToArea, 
      V_String4  = @cDropID, 
      V_String5  = @cUCCNo, 

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