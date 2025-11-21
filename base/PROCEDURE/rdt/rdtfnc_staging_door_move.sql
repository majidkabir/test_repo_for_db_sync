SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Staging_Door_Move                                 */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#158579 - Project Titan                                       */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-01-11 1.0  Vicky    Created                                          */
/* 2010-03-01 1.1  Vicky    Add in Loadkey to Std EventLog (Vicky02)         */
/* 2010-03-05 1.2  Vicky    LoadplanLaneDetail should check by Loadkey only  */
/*                          (Vicky03)                                        */
/* 2010-03-06 1.3  Vicky    New Option - Staging to Staging Move (Vicky04)   */
/* 2010-03-11 1.4  Vicky    Checking on HVCP Pallet cannot be moved to Stage */
/*                          (Vicky05)                                        */
/* 2010-03-12 1.5  Vicky    WCS does not send back Loadkey, therefore has to */
/*                          retrieve Loadkey differently & Add RefNo2 to     */
/*                          EventLog (Vicky06)                               */
/* 2010-04-08 1.6  Vicky    Stage to Stage move additional validation        */
/*                          1. Check whether the To Stage is being assigned  */
/*                             by other Loadkey, if yes prompt error         */
/*                          2. Insert To Stage to LoadplanLaneDetail if      */
/*                             LOC available (Vicky07)                       */
/* 2010-05-20 1.7  Vicky    Titan Phase 2 - Door is to be updated to         */
/*                          DROPID.AdditionalLoc (Vicky08)                   */
/* 2010-08-12 1.8  Vicky    Disable checking on Multi Loadplan into 1 Lane   */
/*                          (Vicky09)                                        */
/* 2010-12-24 1.9  ChewKP   SOS#200191 Add CheckDigit Checking for Door Move */
/*                          (ChewKP01)                                       */
/* 2012-03-13 2.0  Ung      SOS238302 Add generate label file                */
/* 2012-06-01 2.1  Ung      SOS246108 Allow stage to stage status=5 (ung01)  */
/* 2012-06-04 2.2  Ung      SOS244733 Add generate label file for option 3   */
/* 2012-07-02 2.3  James    SOS252313 DropID Status enhancement (james01)    */
/* 2012-10-11 2.4  ChewKP   SOS#257898 Stage to Stage Label printing by      */
/*                          StorerConfig (ChewKP02)                          */  
/* 2016-09-30 2.5  Ung      Performance tuning                               */
/* 2018-11-14 2.6  TungGH   Performance                                      */   
/* 2018-11-14 2.7  Dennis   UWP-16907 Check Digit                            */   
/*****************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Staging_Door_Move](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_success           INT
        
-- Define a variable
DECLARE  
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cPalletID           NVARCHAR(18),
   @cStagingLane        NVARCHAR(10),
   @cActStagingLane     NVARCHAR(10),
   @cDoor               NVARCHAR(10), 
   @cLoadkey            NVARCHAR(10),
   @cOrderkey           NVARCHAR(10),
   @cPickSlipNo         NVARCHAR(10),
   @cExternOrderkey     NVARCHAR(20),
   @cConsigneeKey       NVARCHAR(15),
   @cLocCategory        NVARCHAR(10),
   @cOption             NVARCHAR(1),
   @cDoorCheckDigit     NVARCHAR(11), -- (ChewKP01)
   @cCheckDigit         NVARCHAR(1),  -- (ChewKP01)
   @cStageMoveDoorCheckDigit  NVARCHAR(1), -- (ChewKP01)
   @cFromStage          NVARCHAR(10),
   @cToStage            NVARCHAR(10),
   @cDropIDType         NVARCHAR(10),
   @cUCCNo              NVARCHAR(20),
   @cLineNo             NVARCHAR(5),
   @nLineNo             INT,
   @cPrintLabelSP       NVARCHAR( 20), 
   @cSQLStatement       NVARCHAR(1000), 
   @cSQLParms           NVARCHAR(1000), 
   @cExtendedScreenSP   NVARCHAR( 20),
   @nAction             INT,
   @nAfterScn           INT,
   @nAfterStep          INT,
   @cLocNeedCheck       NVARCHAR( 20),

   @cStageMovePalletStatus    NVARCHAR(1),  -- (james01)
   @cMBOLKey                  NVARCHAR(10), -- (james01)
   @cStage2StagePrintLabel    NVARCHAR(1),  -- (ChewKP02)
   
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
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer, 
   @cUserName        = UserName,

   @cLoadkey         = V_Loadkey,
   @cPickSlipNo      = V_PickSlipNo,
   @cOrderkey        = V_Orderkey,
   @cPalletID        = V_String1,
   @cStagingLane     = V_String2,  
   @cDoor            = V_String3,  
   @cOption          = V_String4,
   @cExternOrderkey  = V_String5,
   @cConsigneeKey    = V_String6,
   @cLocCategory     = V_String7,
   @cActStagingLane  = V_String8,
   @cFromStage       = V_String9,
   @cToStage         = V_String10,
      
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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1751
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1751
   IF @nStep = 1 GOTO Step_1   -- Scn = 2200   Pallet ID, option
   IF @nStep = 2 GOTO Step_2   -- Scn = 2201   Option 1. To Staging lane
   IF @nStep = 3 GOTO Step_3   -- Scn = 2202   Option 1. Message
   IF @nStep = 4 GOTO Step_4   -- Scn = 2203   Option 2. To Door
   IF @nStep = 5 GOTO Step_5   -- Scn = 2204   Option 2. Message
   IF @nStep = 6 GOTO Step_6   -- Scn = 2204   Option 3. From staging lane
   IF @nStep = 7 GOTO Step_7   -- Scn = 2204   Option 3. To staging lane
   IF @nStep = 8 GOTO Step_8   -- Scn = 2204   Option 3. Message
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1751)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2200
   SET @nStep = 1

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- initialise all variable
   SET @cPalletID = ''
   SET @cStagingLane = ''
   SET @cDoor = ''
   SET @cOption = '' -- Default

   -- Prep next screen var   
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
   SET @cOutField03 = '' 
   SET @cOutField04 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2200
   Pallet ID (Field01, input)
   Option    (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletID = @cInField01
      SET @cOption   = @cInField02

      --When PalletID is blank
      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 68566
         SET @cErrMsg = rdt.rdtgetmessage( 68566, @cLangCode, 'DSP') --PalletID req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail  
      END 

      --Pallet ID Not Exists
      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cPalletID)
      BEGIN
             SET @nErrNo = 68567
             SET @cErrMsg = rdt.rdtgetmessage( 68567, @cLangCode, 'DSP') --Invalid PalletID
             EXEC rdt.rdtSetFocusField @nMobile, 1
             GOTO Step_1_Fail  
      END

      IF @cOption = ''
      BEGIN
         SET @nErrNo = 68568
         SET @cErrMsg = rdt.rdtgetmessage( 68568, @cLangCode, 'DSP') --Option Req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1P_Fail 
      END

      IF @cOption <> '1' AND @cOption <> '2' AND @cOption <> '3' -- (Vicky04)
      BEGIN
         SET @nErrNo = 68569
         SET @cErrMsg = rdt.rdtgetmessage( 68569, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1P_Fail 
      END

      SELECT @cLocCategory = ISNULL(RTRIM(L.LocationCategory), ''),
             @cLoadkey = ISNULL(RTRIM(DP.Loadkey), ''), -- (Vicky06)
             @cDropIDType = ISNULL(RTRIM(DP.DropIDType), '') -- (Vicky06)
      FROM dbo.DROPID DP WITH (NOLOCK)
      JOIN dbo.LOC L WITH (NOLOCK) ON (DP.DropLOC = L.LOC)
      WHERE L.Facility = @cFacility
      AND   DP.DropID = @cPalletID

       -- (Vicky06) - Start
       IF @cLoadkey = '' AND @cDropIDType = 'C'
       BEGIN
          SET @nErrNo = 68571
          SET @cErrMsg = rdt.rdtgetmessage( 68571, @cLangCode, 'DSP') --No Loadkey
          EXEC rdt.rdtSetFocusField @nMobile, 1
          GOTO Step_1_Fail 
       END
   
       IF @cLoadkey = '' AND @cDropIDType = 'P'
       BEGIN
          SELECT TOP 1 @cUCCNo = ISNULL(RTRIM(ChildID), '')
          FROM dbo.DROPIDDETAIL WITH (NOLOCK) 
          WHERE DropID = @cPalletID

          IF @cUCCNo = ''
          BEGIN
             SET @nErrNo = 68582
             SET @cErrMsg = rdt.rdtgetmessage( 68582, @cLangCode, 'DSP') --No UCC
             EXEC rdt.rdtSetFocusField @nMobile, 1
             GOTO Step_1_Fail 
          END
          ELSE
          BEGIN
             SELECT @cLoadkey = ISNULL(RTRIM(DP.Loadkey), '')
             FROM dbo.DROPID DP WITH (NOLOCK)
             JOIN dbo.DROPIDDETAIL DPD WITH (NOLOCK) ON (DP.DropID = DPD.DropID)
             WHERE DP.DropIDType = 'C'
             AND   DPD.ChildID = @cUCCNo

             IF @cLoadkey = ''
             BEGIN
                SET @nErrNo = 68591
                SET @cErrMsg = rdt.rdtgetmessage( 68591, @cLangCode, 'DSP') --No Loadkey
                EXEC rdt.rdtSetFocusField @nMobile, 1
                GOTO Step_1_Fail 
             END
          END
       END
       -- (Vicky06) - End

      IF @cOption = '1' -- Staging
      BEGIN
           --Check Status = '9' -- Pallet Moved to Staging
          IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cPalletID AND Status = '9')
          BEGIN
             SET @nErrNo = 68583
             SET @cErrMsg = rdt.rdtgetmessage( 68583, @cLangCode, 'DSP') --PLTMvToStage
             EXEC rdt.rdtSetFocusField @nMobile, 1
             GOTO Step_1_Fail  
          END 

           --Check Status = '3' -- Both Processing Area & Broom Area
          IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cPalletID AND Status = '5')
          BEGIN
             SET @nErrNo = 68570
             SET @cErrMsg = rdt.rdtgetmessage( 68570, @cLangCode, 'DSP') --PalletNotClose
             EXEC rdt.rdtSetFocusField @nMobile, 1
             GOTO Step_1_Fail  
          END 

          -- (Vicky05) - Start
          IF @cLocCategory = 'HVCP'
          BEGIN
             SET @nErrNo = 68590
             SET @cErrMsg = rdt.rdtgetmessage( 68590, @cLangCode, 'DSP') --Invalid ID
             EXEC rdt.rdtSetFocusField @nMobile, 1
             GOTO Step_1_Fail 
          END
          -- (Vicky05) - Start

          SELECT TOP 1 @cStagingLane = ISNULL(RTRIM(LOC), '') 
          FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
          WHERE Loadkey = @cLoadkey
-- Comment By (Vicky03)
--          AND   ExternOrderkey = @cExternOrderkey
--          AND   Consigneekey = @cConsigneeKey
          AND   LocationCategory = 'STAGING'--@cLocCategory
          ORDER BY LOC

          IF @cStagingLane = ''
          BEGIN
             -- (james01)
             IF ISNULL(@cLoadkey, '') = ''
             BEGIN
                SELECT @cLoadkey = ISNULL(RTRIM(DP.Loadkey), '')
                FROM dbo.DROPID DP WITH (NOLOCK)
                WHERE DropID = @cPalletID
             END
             
             SELECT TOP 1 @cMBOLKey = O.MBOLKey 
             FROM dbo.Orders O WITH (NOLOCK) 
             JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey 
             JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
             WHERE LPD.LoadKey = @cLoadkey

             SELECT TOP 1 @cStagingLane = ISNULL(RTRIM(LOC), '') 
             FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
             WHERE MBOLKey = @cMBOLKey
             AND   LocationCategory = 'STAGING'--@cLocCategory
             ORDER BY LOC
          
             IF @cStagingLane = ''
             BEGIN
                SET @nErrNo = 68577
                SET @cErrMsg = rdt.rdtgetmessage( 68577, @cLangCode, 'DSP') --NoLaneAssign
                EXEC rdt.rdtSetFocusField @nMobile, 1
                GOTO Step_1_Fail 
            END
          END
           
          --prepare next screen variable
          SET @cOutField01 = @cPalletID
          SET @cOutField02 = @cStagingLane
          SET @cOutField03 = ''
                            
          -- Go to Staging screen
          SET @nScn = @nScn + 1
          SET @nStep = @nStep + 1 
      END

      IF @cOption = '2' -- Door
      BEGIN
           --Check Status = '9' -- Both Processing Area & Broom Area
          IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cPalletID AND Status = '9')
          BEGIN
             SET @nErrNo = 68578
             SET @cErrMsg = rdt.rdtgetmessage( 68578, @cLangCode, 'DSP') --PltNotInStage
             EXEC rdt.rdtSetFocusField @nMobile, 1
             GOTO Step_1_Fail  
          END 

          --prepare next screen variable
          SET @cOutField01 = @cPalletID
          SET @cOutField02 = ''
          SET @cOutField03 = ''
                            
          -- Go to Door screen
          SET @nScn = @nScn + 3
          SET @nStep = @nStep + 3 
      END

      -- (Vicky04) - Start
      IF @cOption = '3' -- Staging to Staging
      BEGIN
           --Check Status <> '9' -- Pallet Moved to Staging
          IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cPalletID AND Status NOT IN ('5', '9')) --(ung01)
          BEGIN
             SET @nErrNo = 68584
             SET @cErrMsg = rdt.rdtgetmessage( 68584, @cLangCode, 'DSP') --PLTNotInStage
             EXEC rdt.rdtSetFocusField @nMobile, 1
             GOTO Step_1_Fail  
          END 

          -- Retrieve Staging Lane
          SELECT @cLoadkey    = ISNULL(RTRIM(Loadkey), '')
          FROM dbo.DROPID WITH (NOLOCK)
          WHERE DropID = @cPalletID


          --prepare next screen variable
          SET @cOutField01 = @cPalletID
          SET @cOutField02 = ''
          SET @cOutField03 = ''
                            
          -- Go to Staging screen
          SET @nScn = @nScn + 5
          SET @nStep = @nStep + 5 
      END
      
      -- (ChewKP01)
      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
       @cActionType = '1', -- Sign In function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep
      -- (Vicky04) - End
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

      SET @cOutField01 = ''
      SET @cOutField02 = '' 
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cPalletID = ''
      SET @cStagingLane = ''
      SET @cDoor = ''
      SET @cLocCategory = ''
      SET @cOrderkey = ''
      SET @cPickSlipNo = ''
      SET @cExternOrderkey = '' 
      SET @cConsigneeKey = ''
      SET @cOption = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cPalletID = ''
      SET @cOption = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
    END

   Step_1P_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''
    END

END
GOTO Quit

/********************************************************************************
Step 2. (screen = 2201) 
   PALLET ID:    (Field01)
   STAGING LANE: (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cActStagingLane = @cInField03
      SET @cLocNeedCheck = @cInField03

      --When Staging is blank
      IF @cActStagingLane = ''
      BEGIN
         SET @nErrNo = 68579
         SET @cErrMsg = rdt.rdtgetmessage( 68579, @cLangCode, 'DSP') --Lane req
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail  
      END 

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1751ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1751ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, 
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, 
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_2_Fail
            
            SET @cActStagingLane = @cLocNeedCheck
         END
      END

      IF @cActStagingLane <> @cStagingLane
      BEGIN
          IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
                         WHERE Loadkey = @cLoadkey
-- Comment By (Vicky03)
--                         AND   ExternOrderkey = @cExternOrderkey
--                         AND   Consigneekey = @cConsigneeKey
                         AND   LocationCategory = 'STAGING'--@cLocCategory
                         AND   LOC = @cActStagingLane)
          BEGIN
             SET @nErrNo = 68580
             SET @cErrMsg = rdt.rdtgetmessage( 68580, @cLangCode, 'DSP') --Invalid Lane
             EXEC rdt.rdtSetFocusField @nMobile, 3
             GOTO Step_2_Fail
          END 
      END

      -- (james01)
      SET @cStageMovePalletStatus = rdt.RDTGetConfig( @nFunc, 'StageMovePalletStatus', @cStorerkey)    
      IF ISNULL(@cStageMovePalletStatus, '') = '' OR ISNULL(@cStageMovePalletStatus, '0') = '0'
         SET @cStageMovePalletStatus = '9'   -- set default to 9
         
      BEGIN TRAN -- (Vicky08)

      -- Update DropID Table
      UPDATE dbo.DROPID WITH (ROWLOCK)
        SET DropLoc = @cActStagingLane,
            --Status = '9',
            Status = @cStageMovePalletStatus,   -- (james01)
            EditDate = GETDATE(),
            EditWho = @cUserName
      WHERE Loadkey = @cLoadkey
      AND   DropID = @cPalletID

      -- (Vicky08) - Start
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 68595
         SET @cErrMsg = rdt.rdtgetmessage( 68595, @cLangCode, 'DSP') --'Upd DropID Fail'
         ROLLBACK TRAN 
         GOTO QUIT
      END
      ELSE
      BEGIN
         COMMIT TRAN 
      END
      -- (Vicky08) - End

      -- Get storer
      SELECT DISTINCT @cStorerkey = Storerkey FROM dbo.DropID DropID WITH (NOLOCK)
      INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) on DD.DropID = DropID.DropID
      INNER JOIN dbo.PackDetail PD WITH (NOLOCK) on PD.LabelNo = DD.ChildID
      WHERE DropID.DropID = @cPalletID
      
      -- Print label
      SET @cPrintLabelSP = rdt.RDTGetConfig( 1751, 'PrintLabel', @cStorerKey)
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = @cPrintLabelSP AND type = 'P')
      BEGIN
   	   SET @cSQLStatement = N'EXEC rdt.' + @cPrintLabelSP + 
            ' @nMobile, @cLangCode, @cUserName, @cPrinter, @cStorerKey, @cFacility, @cDropID, ' +
            ' @nErrNo     OUTPUT,' +
            ' @cErrMsg    OUTPUT '

   	   SET @cSQLParms = 
   	      '@nMobile     INT,       ' +
            '@cLangCode   NVARCHAR(3),   ' +
            '@cUserName   NVARCHAR(18),  ' +
            '@cPrinter    NVARCHAR(10),  ' +
            '@cStorerKey  NVARCHAR(15),  ' +
            '@cFacility   NVARCHAR(5),   ' +  
            '@cDropID     NVARCHAR( 20), ' +        
            '@nErrNo      INT          OUTPUT, ' +
            '@cErrMsg     NVARCHAR(250) OUTPUT  ' 
                        
         EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @nMobile
            ,@cLangCode
            ,@cUserName 
            ,@cPrinter 
            ,@cStorerKey
            ,@cFacility 
            ,@cPalletID
	         ,@nErrNo   OUTPUT
	         ,@cErrMsg  OUTPUT
      END
      
      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cToLocation   = @cActStagingLane,
         @cToID         = @cPalletID,
         @cLoadkey      = @cLoadkey,     -- (Vicky01)
         @cRefNo2       = 'MoveToStage', -- (Vicky08)
         @nStep         = @nStep
              
      --prepare next screen variable
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cActStagingLane
      SET @cOutField03 = ''
      SET @cOutField04 = ''
                  
      -- Go next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = '' -- Option
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cPalletID = ''
      SET @cStagingLane = ''
      SET @cDoor = ''
      SET @cLocCategory = ''
      SET @cOrderkey = ''
      SET @cPickSlipNo = ''
      SET @cExternOrderkey = '' 
      SET @cConsigneeKey = ''


      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cActStagingLane = ''
             
      -- Reset this screen var
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cStagingLane
      SET @cOutField03 = ''
      SET @cOutField04 = ''
  END
END
GOTO Quit



/********************************************************************************
Step 3. (screen = 2202) 
   PALLET ID:    (Field01)
   STAGING LANE: (Field02)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cPalletID = ''
      SET @cStagingLane = ''
      SET @cDoor = ''
      SET @cLocCategory = ''
      SET @cOrderkey = ''
      SET @cPickSlipNo = ''
      SET @cExternOrderkey = '' 
      SET @cConsigneeKey = ''
      SET @cActStagingLane = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1
                  
      -- Go next screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END

   GOTO Quit

END
GOTO Quit

/********************************************************************************
Step 4. (screen = 2203) 
   PALLET ID:    (Field01)
   DOOR:         (Field02, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDoorCheckDigit = @cInField02 -- (ChewKP01)
      SET @cLocNeedCheck = @cInField02
      
      --When Door is blank
      IF @cDoorCheckDigit = '' -- (ChewKP01)
      BEGIN
         SET @nErrNo = 68581
         SET @cErrMsg = rdt.rdtgetmessage( 68581, @cLangCode, 'DSP') --Door req
         EXEC rdt.rdtSetFocusField @nMobile, 2 
         GOTO Step_4_Fail  
      END 

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1751ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1751ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, 
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, 
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_4_Fail
            
            SET @cDoor = @cLocNeedCheck
         END
      END

      -- Start (ChewKP01)   
      
      SELECT DISTINCT @cStorerkey = Storerkey FROM dbo.DropID DropID WITH (NOLOCK)
      INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) on DD.DropID = DropID.DropID
      INNER JOIN dbo.PackDetail PD WITH (NOLOCK) on PD.LabelNo = DD.ChildID
      WHERE DropID.DropID = @cPalletID
      
      IF @@RowCount = 0 
      BEGIN
         SET @nErrNo = 68599
         SET @cErrMsg = rdt.rdtgetmessage( 68599, @cLangCode, 'DSP') --Invalid DropID
         EXEC rdt.rdtSetFocusField @nMobile, 2 
         GOTO Step_4_Fail  
      END 
      
      SET @cStageMoveDoorCheckDigit = rdt.RDTGetConfig( @nFunc, 'StageMoveDoorCheckDigit', @cStorerkey)    
      
      IF @cStageMoveDoorCheckDigit = '1'
      BEGIN
         SET @cCheckDigit = ''
   
         SET @cDoor = LEFT(RTRIM(@cDoorCheckDigit) , LEN(RTRIM(@cDoorCheckDigit)) - 1)
         SET @cCheckDigit =  RIGHT(RTRIM(@cDoorCheckDigit), 1)
   
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)    
                        WHERE LocationCategory = 'DOOR'
                        AND Loc = @cDoor
                        AND LocCheckDigit = @cCheckDigit ) 
         BEGIN
            SET @nErrNo = 68598
            SET @cErrMsg = rdt.rdtgetmessage( 68598, @cLangCode, 'DSP') --Invalid Door
            EXEC rdt.rdtSetFocusField @nMobile, 2 
            GOTO Step_4_Fail
         END
      END   
      -- End (ChewKP01)
      
      -- (Vicky08) - Start
      -- Update DropID Table
      BEGIN TRAN

      UPDATE dbo.DROPID WITH (ROWLOCK)
        SET AdditionalLoc = @cDoor,
            Status = '9',
            EditDate = GETDATE(),
            EditWho = @cUserName
      WHERE Loadkey = @cLoadkey
      AND   DropID = @cPalletID

      -- (Vicky08) - Start
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 68596
         SET @cErrMsg = rdt.rdtgetmessage( 68596, @cLangCode, 'DSP') --'Upd DropID Fail'
         ROLLBACK TRAN 
         GOTO QUIT
      END
      ELSE
      BEGIN
         COMMIT TRAN 
      END
      -- (Vicky08) - End

      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cToLocation   = @cDoor,
         @cToID         = @cPalletID,
         @cLoadkey      = @cLoadkey, -- (Vicky01)
         @cRefNo2       = 'Door',
         @nStep         = @nStep
              
      --prepare next screen variable
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cDoor
      SET @cOutField03 = ''
      SET @cOutField04 = ''
                  
      -- Go next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = '' -- Option
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cPalletID = ''
      SET @cStagingLane = ''
      SET @cDoor = ''
      SET @cLocCategory = ''
      SET @cOrderkey = ''
      SET @cPickSlipNo = ''
      SET @cExternOrderkey = '' 
      SET @cConsigneeKey = ''


      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cDoor = ''
             
      -- Reset this screen var
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
  END
END
GOTO Quit



/********************************************************************************
Step 5. (screen = 2204) 
   PALLET ID:    (Field01)
   Door:         (Field02)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cPalletID = ''
      SET @cStagingLane = ''
      SET @cDoor = ''
      SET @cLocCategory = ''
      SET @cOrderkey = ''
      SET @cPickSlipNo = ''
      SET @cExternOrderkey = '' 
      SET @cConsigneeKey = ''
      SET @cActStagingLane = ''


      EXEC rdt.rdtSetFocusField @nMobile, 1
                  
      -- Go next screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END

   GOTO Quit

END
GOTO Quit

-- (Vicky04) - Start
/********************************************************************************
Step 6. (screen = 2205)
   PALLET ID:    (Field01)
   FROM STAGING LANE: (Field02, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromStage = @cInField02
      SET @cLocNeedCheck = @cInField02

      --When Staging is blank
      IF @cFromStage = ''
      BEGIN
         SET @nErrNo = 68585
         SET @cErrMsg = rdt.rdtgetmessage( 68585, @cLangCode, 'DSP') --Lane req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_6_Fail  
      END 

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1751ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1751ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, 
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, 
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_6_Fail
            
            SET @cFromStage = @cLocNeedCheck
         END
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK)
                     WHERE DropID = @cPalletID 
                     AND   DropLOC = @cFromStage
                     AND   Status IN ('5', '9')) --(ung01)
      BEGIN
         SET @nErrNo = 68586
         SET @cErrMsg = rdt.rdtgetmessage( 68586, @cLangCode, 'DSP') --LaneNotMatchID
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_6_Fail  
      END

              
      --prepare next screen variable
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cFromStage
      SET @cOutField03 = ''
      SET @cOutField04 = ''
                  
      -- Go next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = '' -- Option
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cPalletID = ''
      SET @cStagingLane = ''
      SET @cDoor = ''
      SET @cLocCategory = ''
      SET @cOrderkey = ''
      SET @cPickSlipNo = ''
      SET @cExternOrderkey = '' 
      SET @cConsigneeKey = ''
      SET @cFromStage = ''


      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cFromStage = ''
             
      -- Reset this screen var
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 7. (screen = 2206)
   PALLET ID:    (Field01)
   FROM STAGING LANE: (Field02)
   TO STAGING LANE: (Field03, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToStage = @cInField03
      SET @cLocNeedCheck = @cInField03

      --When Staging is blank
      IF @cToStage = ''
      BEGIN
         SET @nErrNo = 68587
         SET @cErrMsg = rdt.rdtgetmessage( 68587, @cLangCode, 'DSP') --Lane req
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_7_Fail  
      END 

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1751ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1751ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, 
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, 
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_7_Fail
            
            SET @cToStage = @cLocNeedCheck
         END
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                     WHERE Facility = @cFacility 
                     AND   LOC = @cToStage)
      BEGIN
         SET @nErrNo = 68588
         SET @cErrMsg = rdt.rdtgetmessage( 68588, @cLangCode, 'DSP') --Diff Facility
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_7_Fail  
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                     WHERE Facility = @cFacility 
                     AND   LOC = @cToStage
                     AND   LocationCategory = 'STAGING')
      BEGIN
         SET @nErrNo = 68589
         SET @cErrMsg = rdt.rdtgetmessage( 68589, @cLangCode, 'DSP') --NotStagingLoc
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_7_Fail  
      END

      -- (Vicky07) - Start
-- Commended By (Vicky09)
--      IF EXISTS (SELECT 1 FROM dbo.LoadplanLaneDetail WITH (NOLOCK)
--                 WHERE LOC = @cToStage
--                 AND Status < '9'
--                 AND Loadkey <> @cLoadkey)
--      BEGIN
--         SET @nErrNo = 68593
--         SET @cErrMsg = rdt.rdtgetmessage( 68593, @cLangCode, 'DSP') --Lane4OtherLoad
--         EXEC rdt.rdtSetFocusField @nMobile, 3
--         GOTO Step_7_Fail  
--      END
    
      IF EXISTS (SELECT 1 FROM dbo.LoadplanLaneDetail WITH (NOLOCK)
                 WHERE LOC = @cToStage
                 AND Status = '9'
                 AND Loadkey = @cLoadkey)
      BEGIN
         SET @nErrNo = 68594
         SET @cErrMsg = rdt.rdtgetmessage( 68594, @cLangCode, 'DSP') --LoadPlanClosed
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_7_Fail  
      END 

      IF NOT EXISTS (SELECT 1 FROM dbo.LoadplanLaneDetail WITH (NOLOCK)
                     WHERE LOC = @cToStage
                     AND Loadkey = @cLoadkey)
      BEGIN
         SELECT TOP 1 @cExternOrderkey = ExternOrderKey,
                      @cConsigneeKey = ConsigneeKey
         FROM dbo.LoadplanLaneDetail WITH (NOLOCK)
         WHERE Loadkey = @cLoadkey

         SELECT @cLineNo = ISNULL(MAX(LP_LaneNumber), '0')
         FROM dbo.LoadplanLaneDetail WITH (NOLOCK)
         WHERE Loadkey = @cLoadkey

         SELECT @cLineNo = RIGHT(REPLICATE('0',5) + ISNULL(RTRIM(CAST(ISNULL(CAST(MAX(@cLineNo) AS INT),0)+1 AS NVARCHAR(5))),''),5) 

         INSERT INTO dbo.LoadplanLaneDetail (LoadKey, ExternOrderKey, ConsigneeKey, LP_LaneNumber, LocationCategory, LOC, Status)
         VALUES (@cLoadkey, ISNULL(RTRIM(@cExternOrderkey), ''), ISNULL(RTRIM(@cConsigneeKey), ''), @cLineNo, 'STAGING', @cToStage, '0') 
      END 
      -- (Vicky07) - End

      -- Update DropID Table
      BEGIN TRAN -- (Vicky08)

      UPDATE dbo.DROPID WITH (ROWLOCK)
        SET DropLoc = @cToStage,
            EditDate = GETDATE(),
            EditWho = @cUserName
      WHERE DropID = @cPalletID

      -- (Vicky08) - Start
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 68597
         SET @cErrMsg = rdt.rdtgetmessage( 68597, @cLangCode, 'DSP') --'Upd DropID Fail'
         ROLLBACK TRAN 
         GOTO QUIT
      END
      ELSE
      BEGIN
         COMMIT TRAN 
      END
      -- (Vicky08) - End

      -- Get storer
      SELECT DISTINCT @cStorerkey = Storerkey FROM dbo.DropID DropID WITH (NOLOCK)
      INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) on DD.DropID = DropID.DropID
      INNER JOIN dbo.PackDetail PD WITH (NOLOCK) on PD.LabelNo = DD.ChildID
      WHERE DropID.DropID = @cPalletID
      
      SET @cStage2StagePrintLabel = ''
      
      SET @cStage2StagePrintLabel = rdt.RDTGetConfig( 1751, 'Stage2StagePrintLabel', @cStorerKey)
      
      -- (ChewKP02)
      IF ISNULL(RTRIM(@cStage2StagePrintLabel),'') = '1'
      BEGIN
         -- Print label
         SET @cPrintLabelSP = rdt.RDTGetConfig( 1751, 'PrintLabel', @cStorerKey)
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = @cPrintLabelSP AND type = 'P')
         BEGIN
      	   SET @cSQLStatement = N'EXEC rdt.' + @cPrintLabelSP + 
               ' @nMobile, @cLangCode, @cUserName, @cPrinter, @cStorerKey, @cFacility, @cDropID, ' +
               ' @nErrNo     OUTPUT,' +
               ' @cErrMsg    OUTPUT '
   
      	   SET @cSQLParms = 
      	      '@nMobile     INT,       ' +
               '@cLangCode   NVARCHAR(3),   ' +
               '@cUserName   NVARCHAR(18),  ' +
               '@cPrinter    NVARCHAR(10),  ' +
               '@cStorerKey  NVARCHAR(15),  ' +
               '@cFacility   NVARCHAR(5),   ' +  
               '@cDropID     NVARCHAR( 20), ' +        
               '@nErrNo      INT          OUTPUT, ' +
               '@cErrMsg     NVARCHAR(250) OUTPUT  ' 
                           
            EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
                @nMobile
               ,@cLangCode
               ,@cUserName 
               ,@cPrinter 
               ,@cStorerKey
               ,@cFacility 
               ,@cPalletID
   	         ,@nErrNo   OUTPUT
   	         ,@cErrMsg  OUTPUT
         END
      END
      
      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cToLocation   = @cToStage,
         @cToID         = @cPalletID,
         @cLoadKey      = @cLoadkey,
         @cRefNo2       = 'StageToStage', -- (Vicky08)
         @nStep         = @nStep
              
      --prepare next screen variable
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cFromStage
      SET @cOutField03 = @cToStage
      SET @cOutField04 = ''
                  
      -- Go next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cStagingLane = ''
      SET @cDoor = ''
      SET @cLocCategory = ''
      SET @cOrderkey = ''
      SET @cPickSlipNo = ''
      SET @cExternOrderkey = '' 
      SET @cConsigneeKey = ''
      SET @cFromStage = ''


      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cToStage = ''
             
      -- Reset this screen var
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cFromStage
      SET @cOutField03 = ''
      SET @cOutField04 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 8. (screen = 2207) 
   PALLET ID:    (Field01)
   FROM STAGING LANE: (Field02)
   TO STAGING LANE: (Field03)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cPalletID = ''
      SET @cStagingLane = ''
      SET @cDoor = ''
      SET @cLocCategory = ''
      SET @cOrderkey = ''
      SET @cPickSlipNo = ''
      SET @cExternOrderkey = '' 
      SET @cConsigneeKey = ''
      SET @cActStagingLane = ''
      SET @cFromStage = ''
      SET @cToStage = ''


      EXEC rdt.rdtSetFocusField @nMobile, 1
      
      
                  
      -- Go next screen
      SET @nScn = @nScn - 7
      SET @nStep = @nStep - 7
   END

   GOTO Quit

END
GOTO Quit
-- (Vicky04) - End

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg, 
      Func          = @nFunc,
      Step          = @nStep,            
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility, 
      Printer       = @cPrinter,    
      -- UserName      = @cUserName,

      V_Loadkey     = @cLoadkey,
      V_PickSlipNo  = @cPickSlipNo,
      V_Orderkey    = @cOrderkey,
      V_String1     = @cPalletID,
      V_String2     = @cStagingLane,  
      V_String3     = @cDoor,  
      V_String4     = @cOption,
      V_String5     = @cExternOrderkey,
      V_String6     = @cConsigneeKey,
      V_String7     = @cLocCategory,
      V_String8     = @cActStagingLane,
      V_String9     = @cFromStage,
      V_String10    = @cToStage,

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