SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*******************************************************************************/
/* Store procedure: rdtfnc_TM_NonInventory_Move                                */
/* Copyright      : IDS                                                        */
/*                                                                             */
/* Purpose: RDT Task Manager - Non Inventory Move (SOS#159576)                 */
/*          Called By rdtfnc_TaskManager                                       */
/*                                                                             */
/* Modifications log:                                                          */
/*                                                                             */
/* Date        Rev   Author   Purposes                                         */
/* 20-01-2010  1.0   Vicky    Created                                          */
/* 26-02-2010  1.1   Vicky    Fix: LastLoc supposed to be P&D (Vicky01)        */
/* 01-03-2010  1.2   Vicky    Add in Loadkey to Std EventLog (Vicky02)         */
/* 02-03-2010  1.3   ChewKP   Add In Previous Scn info so when user press ESC  */
/*                            in Screen 5 will back to Screen 1 (ChewKP01)     */
/* 05-03-2010  1.4   James    Rollback all trans when error occured (james01)  */
/* 05-03-2010  1.5   Vicky    LoadplanLaneDetail should check by Loadkey only  */
/*                            (Vicky03)                                        */
/* 11-03-2010  1.6   Vicky    Release Q task should consider PD.Status = 9     */
/*                            (Vicky04)                                        */
/* 11-03-2010  1.7   Vicky    Fix missing field value when the next task is    */
/*                            suggested (Vicky05)                              */
/* 11-03-2010  1.8   James    Bug fix (james02)                                */
/* 11-03-2010  1.9   Vicky    When ESC from Reason Code, Sugg LOC not showing  */
/*                            (Vicky06)                                        */
/* 17-03-2010  2.0   ChewKP   Remove Condition when cannot find Q Task in same */
/*                            Loadplan (ChewKP02)                              */
/* 25-03-2010  2.1   Vicky    Do not prompt Reason Code because all Pallet has */
/*                            to be moved (Vicky07)                            */
/* 25-03-2010  2.2   Vicky    Add trace for concurrency issue (Vicky09)        */
/* 16-06-2010  2.3   Leong    SOS# 176725 - Update EndTime when status 9 And   */
/*                                          StartTime when status 0            */
/* 27-07-2010  2.4   Leong    SOS# 182295 - Use ArchiveCop for trace when      */
/*                                          insert data to LOTxLOCxID          */
/* 02-11-2010  2.5   ChewKP   SOS# 195380 - Fixes for release status = 'Q' PK  */
/*                                          task (ChewKP03)                    */
/* 12-09-2011  2.6   TLTING   Turn OFF TraceInfo                               */
/* 19-12-2011  2.7   ChewKP   SOS# 229422 - Get Lane Info by MBOLKEy (ChewKP04)*/
/* 05-01-2012  3.0   ChewKP   SKIPJACK Project Changes - Synchronize V_STRINGXX*/
/*                            (ChewKP05)                                       */
/* 16-02-2012  3.1   ChewKP   Add FinalLOC check same ShipTo + PO (ChewKP06)   */
/* 27-02-2012  3.2   ChewKP   ADd StorerConfig for checking same ShipTo + PO   */
/*                            (ChewKP07)                                       */
/* 06-03-2012  3.3   ChewKP   Additional Screen Flow (ChewKP08)                */
/* 06-04-2012  3.4   ChewKP   Extend DropID = 20 (ChewKP09)                    */
/* 07-05-2012  3.5   Ung      SOS243691 Chg DropID.Status from 3 to 5 (ung01)  */
/* 07-06-2012  3.6   Ung      SOS246383 Add generate label file (ung02)        */
/* 01-06-2012  3.7   ChewKP   SOS#246238 Fixed NMV Update PK.Status = 'Q'      */
/*                            issues (ChewKP10)                                */
/* 30-05-2013  3.8   Ung      SOS279795 Add ExtendedUpdateSP                   */
/* 30-09-2016  3.9   Ung      Performance tuning                               */  
/* 09-10-2018  4.0   Gan      Performance tuning                               */
/*******************************************************************************/

CREATE PROC [RDT].[rdtfnc_TM_NonInventory_Move](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @b_success           INT, 
   @cSQL                NVARCHAR(1000),
   @cSQLParam           NVARCHAR(1000)

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

   @cAreaKey            NVARCHAR(10),
   @cStrategykey        NVARCHAR(10),
   @cTTMStrategykey     NVARCHAR(10),
   @cTTMTasktype        NVARCHAR(10),
   @cFromLoc            NVARCHAR(10),
   @cSuggFromLoc        NVARCHAR(10),
   @cToLoc              NVARCHAR(10),
   @cSuggToLoc          NVARCHAR(10),
   @cTaskdetailkey      NVARCHAR(10),
   @cID                 NVARCHAR(20),  -- (ChewKP09)
   @cSuggID             NVARCHAR(18),
   @cUOM                NVARCHAR(5),   -- Display NVARCHAR(5)
   @cReasonCode         NVARCHAR(10),
   @cSKU                NVARCHAR(20),
   @cTaskStorer         NVARCHAR(15),
   @cFromFacility       NVARCHAR(5),
   @c_outstring         NVARCHAR(255),
   @cUserPosition       NVARCHAR(10),
   @cPrevTaskdetailkey  NVARCHAR(10),
   @cQTY                NVARCHAR(5),
   @cPackkey            NVARCHAR(10),
   @cLoadkey            NVARCHAR(10),
   @cExternOrderkey     NVARCHAR(20),
   @cOrderkey           NVARCHAR(10),
   @cConsigneekey       NVARCHAR(15),
   @cParentSKU          NVARCHAR(20),
   @cPrePackByBOM       NVARCHAR(1),
   @cPackUOM1           NVARCHAR(5),
   @cPackUOM3           NVARCHAR(5),
   @cAisle              NVARCHAR(10),
   @cLocCategory        NVARCHAR(10),
   @cNextTaskdetailkey  NVARCHAR(10),
   @cNextFromLOC        NVARCHAR(10),
   @cNextToID           NVARCHAR(18),
   @cNextLoadkey        NVARCHAR(10),
   @cNextStorerkey      NVARCHAR(15),
   @cBOMIndicator       NVARCHAR(1),

   @cSuggQTY_Ctn        NVARCHAR(5),
   @cSuggQTY_Pcs        NVARCHAR(5),
   @cActQTY_Ctn         NVARCHAR(5),
   @cActQTY_Pcs         NVARCHAR(5),

   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),

   @nQTY                INT,
   @nToFunc             INT,
   @nSuggQTY_Ctn        INT,
   @nSuggQTY_Pcs        INT,
   @nPrevStep           INT,
   @nFromStep           INT,
   @nFromScn            INT,
   @nToScn              INT,

   @nPackCaseCnt        INT,
   @nSumBOMQTY          INT,
   @nSumPDQTY           INT,
   @nTotalCartons       INT,
   @nTotalRemaining     INT,
   @nActQTY_Ctn         INT,
   @nActQTY_Pcs         INT,

   @cPDLot              NVARCHAR(10),
   @cPDID               NVARCHAR(18),
   @cPDSKU              NVARCHAR(20),
   @cPDQTY              INT,

   @cRPDLot             NVARCHAR(10),
   @cRPDID              NVARCHAR(18),
   @cRPDSKU             NVARCHAR(20),
   @nRPDQTY             INT,
   @nTranCount          INT,     -- (james01)

   @nTrace              INT, -- (Vicky09)
   @nPnDCheck           INT, -- (ChewKP03)
   @cGetLaneByMBOL      NVARCHAR(1),  -- (ChewKP04)
   @cMBOLKey            NVARCHAR(10), -- (ChewKP04)

-- (ChewKP06)
   @cOtherLoadKey       NVARCHAR( 10),
   @cOtherExternOrderKey NVARCHAR( 30),
   @cOtherConsigneeKey  NVARCHAR( 15),
   @c_mixpoinlane       NVARCHAR(1),
   @cDisplayDropIDSCN   NVARCHAR(1),    -- (ChewKP08)
   @cInID               NVARCHAR(18),   -- (ChewKP08)
   @cOverRideID         NVARCHAR(1),    -- (ChewKP08)
   @cNewTaskdetailkey   NVARCHAR(10),   -- (ChewKP08)
   @cFromLocCategory    NVARCHAR(10),   -- (ChewKP10)
   @cNextTaskFacility   NVARCHAR(5),    -- (ChewKP10)
   @cExtendedUpdateSP   NVARCHAR(20), 
   @cNextTaskDetailKeys NVARCHAR(10), 


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

   @cFromLoc         = V_LOC,
   @cID              = V_ID,
   @cUOM             = V_UOM,
  -- @nQTY             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,
   @cLoadkey         = V_Loadkey,

-- (ChewKP05)
--   @cAreaKey         = V_String1,
--   @cTTMStrategykey  = V_String2,
   @cToLoc           = V_String3,
   @cReasonCode      = V_String4,
   @cTaskdetailkey   = V_String5,
   
   @nQTY             = V_Integer1,
   @nSuggQTY_Ctn     = V_Integer2,
   @nPrevStep        = V_Integer3,
   @nSuggQTY_Pcs     = V_Integer4,
   @nSumPDQTY        = V_Integer5,
   @nActQTY_Ctn      = V_Integer6,
   @nActQTY_Pcs      = V_Integer7,
   @nTrace           = V_Integer8,
   
   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,

   @cSuggFromloc     = V_String6,
   @cSuggToloc       = V_String7,
   @cSuggID          = V_String8,
  -- @nSuggQTY_Ctn     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,
   @cUserPosition    = V_String10,
  -- @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,
   @cPrevTaskdetailkey = V_String12,
   @cPackkey         = V_String13,
  -- @nFromStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,
  -- @nFromScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,
   @cTaskStorer      = V_String16,

   @cPrepackByBOM    = V_String17,
   --@nSuggQTY_Pcs     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String18, 5), 0) = 1 THEN LEFT( V_String18, 5) ELSE 0 END,
   --@nSumPDQTY        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19, 5), 0) = 1 THEN LEFT( V_String19, 5) ELSE 0 END,

  -- @nActQTY_Ctn      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String20, 5), 0) = 1 THEN LEFT( V_String20, 5) ELSE 0 END,
  -- @nActQTY_Pcs      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String21, 5), 0) = 1 THEN LEFT( V_String21, 5) ELSE 0 END,

   @cPackUOM1        = V_String22,
   @cPackUOM3        = V_String23,

  -- @nTrace           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String24, 5), 0) = 1 THEN LEFT( V_String24, 5) ELSE 0 END,  -- (Vicky09)

   @cAreaKey         = V_String32,  --(ChewKP05)
   @cTTMStrategykey = V_String33,  --(ChewKP05)
   @cTTMTasktype     = V_String34,  --(ChewKP05)
   @cRefKey01        = V_String35,  --(ChewKP05)
   @cRefKey02        = V_String36,  --(ChewKP05)
   @cRefKey03        = V_String37,  --(ChewKP05)
   @cRefKey04        = V_String38,  --(ChewKP05)
   @cRefKey05        = V_String39,  --(ChewKP05)

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

FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1759
BEGIN
   -- (ChewKP08)
   DECLARE @nStepDropID INT,
        @nStepFromLoc   INT,
        @nScnDropID     INT,
        @nScnFromLoc    INT,
        @nStepToLoc     INT,
        @nScnToLoc      INT

   SET @nStepDropID  = 5  
   SET @nScnDropID   = 2214  
     
   SET @nStepFromLoc = 1  
   SET @nScnFromLoc  = 2210  
     
   SET @nStepToLoc = 2  
   SET @nScnToLoc  = 2211

   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1759, Scn = 2210 -- FromLOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 2211   ToLOC
   IF @nStep = 4 GOTO Step_4   -- Scn = 2213   Sucess Msg
   IF @nStep = 5 GOTO Step_5   -- Scn = 2214   DropID -- (ChewKP08)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 1. Called from Task Manager Main Screen (func = 1756)
    Screen = 2210
    PALLET ID     (Field01)
    LOTTABLE
    1: XXXXX      (Field02)
    2: XXXXX      (Field03)
    3: XXXXX      (Field04)
    4: YYYY/MM/DD (Field05)
    FROM LOC
    XXXXXXXXXX    (Field06)
    (Field07, input)
********************************************************************************/
Step_1:
BEGIN
   -- Set all variable for 1st record - records are from rdtfnc_TaskManager
   IF @nPrevStep = 0
   BEGIN
      SET @cID             = @cOutField01
      SET @cSuggFromLoc    = @cOutField02
      SET @cTaskdetailkey  = @cOutField06
      SET @cAreaKey        = @cOutField07
      SET @cTTMStrategykey = @cOutField08
   END

   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cUserPosition = '1'
      SET @nPrevStep = 1

      SET @nTrace = 0 -- (Vicky09)

      SET @cID             = @cOutField01
      SET @cSuggFromLoc    = @cOutField02
      SET @cTaskdetailkey  = @cOutField06
      SET @cAreaKey        = @cOutField07
      SET @cTTMStrategykey = @cOutField08

       -- (Vicky09)
      IF @nTrace = 1
      BEGIN
         Declare @cTStatus NVARCHAR(10), @cTUser NVARCHAR(15)

         SELECT @cTStatus = Status,
                @cTUser = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailkey

         INSERT INTO RDT.RDTTMLOG (UserName, TaskUserName, MobileNo, AreaKey, TaskType, PrevTaskdetailkey, Taskdetailkey, PrevStatus, CurrStatus, Func, Scn, Step)
         VALUES (@cUsername, @cTUser, @nMobile, @cAreaKey, 'NMV_Scn1', '', @cTaskdetailkey, '', @cTStatus, @nFunc, @nScn, @nStep)
      END

      SET @cFromLoc = @cInField03

      IF @cFromloc = ''
      BEGIN
         SET @nErrNo = 68616
         SET @cErrMsg = rdt.rdtgetmessage( 68616, @cLangCode, 'DSP') --FromLoc Req
         GOTO Step_1_Fail
      END

      IF @cFromLoc <> @cSuggFromLoc
      BEGIN
         SET @nErrNo = 68617
         SET @cErrMsg = rdt.rdtgetmessage( 68617, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_1_Fail
      END

      SET @cID             = @cOutField01
      SET @cSuggFromLoc    = @cOutField02
      SET @cTaskdetailkey  = @cOutField06
      SET @cAreaKey        = @cOutField07
      SET @cTTMStrategykey = @cOutField08

      SELECT @cTaskStorer = ISNULL(RTRIM(Storerkey), ''),
             @cSKU = ISNULL(RTRIM(SKU), ''),
             @cSuggID = ISNULL(RTRIM(ToID), ''),
             @cSuggToLoc = ISNULL(RTRIM(ToLOC), ''),
             @cLoadkey = ISNULL(RTRIM(Loadkey), '')
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskdetailkey

      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '1', -- Sign in function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cTaskStorer,
         @nStep       = @nStep

      IF @cSuggToLoc = ''
      BEGIN
         SET @nErrNo = 68618
         SET @cErrMsg = rdt.rdtgetmessage( 68618, @cLangCode, 'DSP') --BlankSuggToLOC
         GOTO Step_1_Fail
      END

      SELECT @cPrepackByBOM = ISNULL(RTRIM(sValue), '0')
      FROM dbo.STORERCONFIG WITH (NOLOCK)
      WHERE Storerkey = @cTaskStorer

      -- Extended update
      SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cToLOC, @cNextTaskDetailKeys, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile             INT,          ' +
               '@nFunc               INT,          ' +
               '@cLangCode           NVARCHAR( 3), ' +
               '@nStep               INT,          ' +
               '@cTaskdetailKey      NVARCHAR(10), ' +
               '@cToLOC              NVARCHAR(10), ' +
               '@cNextTaskDetailKeys NVARCHAR(10), ' +
               '@nErrNo              INT          OUTPUT, ' +
               '@cErrMsg             NVARCHAR(20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cToLOC, @cNextTaskDetailKeys, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- prepare next screen
      SET @cOutField01 = @cSuggID
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = @cSuggToLoc
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      SET @nFromScn  = @nScn
      SET @nFromStep = @nStep

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Display Confirm ID Screen When StorerConfig is Setup -- (ChewKP08)
      SET @cDisplayDropIDSCN = ''
      SET @cDisplayDropIDSCN = rdt.RDTGetConfig( @nFunc, 'DisplayDropIDSCN', @cStorerKey)

      IF @cDisplayDropIDSCN = '1'
      BEGIN
         -- prepare next screen
         SET @cOutField01 = @cFromLoc
         SET @cOutField02 = @cSuggID
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''

         SET @nFromScn  = @nScn
         SET @nFromStep = @nStep

         -- Go to dropID screen
         SET @nScn = @nScnDropID
         SET @nStep = @nStepDropID
      END
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cFromLoc = ''

      SET @cOutField01 = @cID
      SET @cOutField02 = @cSuggFromLoc
      SET @cOutField03 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2211
   PALLET ID (Field01)
   FROM LOC  (Field02)
   SUG TOLOC (Field03)
   TO LOC    (Field04, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLoc = @cInField04

      IF @cToLoc = ''
      BEGIN
         SET @nErrNo = 68619
         SET @cErrMsg = rdt.rdtgetmessage( 68619, @cLangCode, 'DSP') --ToLOC Req
         GOTO Step_2_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLoc AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 68620
         SET @cErrMsg = rdt.rdtgetmessage( 68620, @cLangCode, 'DSP') --Bad Location
         GOTO Step_2_Fail
      END

      -- Get Lane By MBOL -- (ChewKP04)
      SET @cGetLaneByMBOL = ''
      SET @cGetLaneByMBOL = rdt.RDTGetConfig( @nFunc, 'LaneAssignmentByMBOL', @cStorerKey)

      -- Enter To Loc <> Suggested To Loc, check whether location is in the LoadPlanLaneDetail
      IF @cSuggToLoc <> @cToLoc
      BEGIN
         IF @cGetLaneByMBOL <> '1'
         BEGIN
            -- Get the Loadkey (DropID.Loadkey)
            SELECT @cLoadkey = ISNULL(RTRIM(Loadkey), '')
            FROM dbo.DropID WITH (NOLOCK)
            WHERE DropID = @cID

            IF @cLoadkey = ''
            BEGIN
               SET @nErrNo = 68621
               SET @cErrMsg = rdt.rdtgetmessage( 68621, @cLangCode, 'DSP') --LdNotInTsk
               GOTO Step_2_Fail
            END

            SELECT @cLocCategory = ISNULL(RTRIM(LocationCategory), '')
            FROM dbo.LOC WITH (NOLOCK)
            WHERE LOC = @cSuggToLoc

            SELECT TOP 1 @cOrderkey = ISNULL(RTRIM(PD.Orderkey), '' )
            FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey AND PD.Storerkey = OD.Storerkey AND
                                                            PD.SKU = OD.SKU AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo.ORDERS ORD WITH (NOLOCK) ON (ORD.Orderkey = OD.Orderkey)
            JOIN dbo.LoadplanDetail LPD WITH (NOLOCK) ON (LPD.Orderkey = ORD.OrderKey)
            WHERE PD.DropID = @cID
           -- AND   PD.LOC = @cSuggFromLoc
            AND   LPD.Loadkey = @cLoadkey

            SELECT @cExternOrderkey = ISNULL(RTRIM(ExternOrderkey), ''),
                   @cConsigneeKey = ISNULL(RTRIM(Consigneekey), '')
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE Orderkey = @cOrderkey

            IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
                           WHERE Loadkey = @cLoadkey
                           AND   LocationCategory = @cLocCategory
                           AND   LOC = @cToLoc )
            BEGIN
               SET @nErrNo = 68622
               SET @cErrMsg = rdt.rdtgetmessage( 68622, @cLangCode, 'DSP') --LocNotAsgn
               GOTO Step_2_Fail
            END

         END  -- IF @cGetLaneByMBOL <> '1'
         ELSE IF @cGetLaneByMBOL = '1'
         BEGIN
            -- Get the Loadkey (DropID.Loadkey)
            SELECT @cLoadkey = ISNULL(RTRIM(Loadkey), '')
            FROM dbo.DropID WITH (NOLOCK)
            WHERE DropID = @cID

            IF @cLoadkey = ''
            BEGIN
               SET @nErrNo = 68639
               SET @cErrMsg = rdt.rdtgetmessage( 68639, @cLangCode, 'DSP') --LdNotInTsk
               GOTO Step_2_Fail
            END

            -- Get other ID on this lane
            DECLARE @cOtherID NVARCHAR( 18)
            SET @cOtherID = ''
            SELECT TOP 1 @cOtherID = DropID
            FROM dbo.DropID WITH (NOLOCK)
            WHERE DropLOC = @cToLoc
               AND DropID <> @cID
               AND Status < 9 --5=Putaway

            -- (ChewKP07)
            EXECUTE nspGetRight @cFacility,  -- facility
               '',      -- Storerkey
               NULL,      -- Sku
               'MIXPOINLANE', -- Configkey
               @b_success       OUTPUT,
               @c_mixpoinlane   OUTPUT,
               @nErrNo           OUTPUT,
               @cErrMsg        OUTPUT

            IF @c_mixpoinlane <> '1'
            BEGIN
                  -- (ChewKP06)
                  -- Check other ID is same ExternOrderKey and ConsigneeKey
                  IF @cOtherID <> ''
                  BEGIN
                     -- Get LoadKey of other ID
                     SELECT TOP 1 @cOtherLoadKey = PH.LoadKey
                     FROM dbo.DropIDDetail DD WITH (NOLOCK)
                        INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (DD.ChildID = PD.LabelNo)
                        INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                     WHERE DD.DropID = @cOtherID

                     -- Get ID ExternOrderKey and ConsigneeKey
                     SELECT TOP 1
                        @cExternOrderKey = O.ExternOrderKey,
                        @cConsigneeKey = O.ConsigneeKey
                     FROM dbo.Orders O WITH (NOLOCK)
                        JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                     WHERE LPD.LoadKey = @cLoadKey

                     -- Get other ID ExternOrderKey and ConsigneeKey
                     SELECT TOP 1
                        @cOtherExternOrderKey = O.ExternOrderKey,
                        @cOtherConsigneeKey = O.ConsigneeKey
                     FROM dbo.Orders O WITH (NOLOCK)
                        JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                     WHERE LPD.LoadKey = @cOtherLoadKey

                     IF @cOtherExternOrderKey <> @cExternOrderKey OR
                        @cOtherConsigneeKey <> @cConsigneeKey
                     BEGIN
                        SET @nErrNo = 68642
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ShipTo+PO
                        GOTO Step_2_Fail
                     END
                  END
            END
         END
      END

      -- Confirm Non Inventory Move
      -- Update TaskDetail
      SET @nTranCount = @@TRANCOUNT    -- (james01)
      BEGIN TRAN
      SAVE TRAN TM_NMV_ConfirmTask     -- (james01)

      UPDATE dbo.TaskDetail WITH (ROWLOCK)
         SET Status = '9',
             UserKey  = @cUsername,
             EditDate = GETDATE(),
             EditWho  = @cUsername,
             Trafficcop = NULL,
             Message01 = 'NMVCFM',   -- SOS# 176725
             EndTime   = GETDATE()   -- SOS# 176725
      WHERE TaskDetailKey = @cTaskdetailkey
      AND   TaskType = 'NMV'

      IF @@Error <> 0
      BEGIN
         SET @nErrNo = 68628
         SET @cErrMsg = rdt.rdtgetmessage( 68628, @cLangCode, 'DSP') -- ErrUpdTaskDetail
         GOTO RollBackTran
      END

      -- (ChewKP04)
      IF @cGetLaneByMBOL = '1'
      BEGIN
         UPDATE dbo.DropID WITH (ROWLOCK)
            SET DropLOC = @cToLOC,
                Status = '5',  -- (ung01)
                EditDate = GETDATE(),
                EditWho  = @cUsername,
                Trafficcop = NULL
         WHERE DropID = @cID
         AND   Status = '3'  --3=Putaway (ung01)
         AND   DropIDType = 'PALLET'

         IF @@Error <> 0
         BEGIN
            SET @nErrNo = 68641
            SET @cErrMsg = rdt.rdtgetmessage( 68641, @cLangCode, 'DSP') -- ErrUpdDropID
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.DropID WITH (ROWLOCK)
            SET DropLOC = @cToLOC,
                Status = '3',
                EditDate = GETDATE(),
                EditWho  = @cUsername,
                Trafficcop = NULL
         WHERE DropID = @cID
         AND   Status = '0'
         AND   DropIDType = 'C'

         IF @@Error <> 0
         BEGIN
            SET @nErrNo = 68629
            SET @cErrMsg = rdt.rdtgetmessage( 68629, @cLangCode, 'DSP') -- ErrUpdDropID
            GOTO RollBackTran
         END
     END

      -- Print label (ung03)
      IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND LocationCategory = 'STAGING')
      BEGIN
         DECLARE @cPrintLabelSP NVARCHAR( 20)
         SET @cPrintLabelSP = rdt.RDTGetConfig( @nFunc, 'PrintLabel', @cStorerKey)
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = @cPrintLabelSP AND type = 'P')
         BEGIN
            DECLARE @cSQLStatement NVARCHAR(1000)
            DECLARE @cSQLParms     NVARCHAR(1000)

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
               ,@cID
             ,@nErrNo   OUTPUT
             ,@cErrMsg  OUTPUT
         END
      END

      -- Get the PK task in Queue
      SELECT @cAisle = ISNULL(RTRIM(LocAisle), '')
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cSuggFromLoc

      -- Get the Taskkey from same Loadplan
      SET @cNextTaskFacility = '' -- (ChewKP10)

      SELECT TOP 1 @cNextTaskDetailKey = TD.TaskDetailKey,
                   @cNextFromLOC = TD.FromLOC,
                   @cNextToID = TD.ToID,
                   @cNextLoadKey = TD.Loadkey,
                   @cNextStorerkey = TD.Storerkey,
                   @cNextTaskFacility = Loc.Facility -- (ChewKP10)
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
      WHERE TD.TaskDetailKey > @cTaskDetailKey
      AND   TD.TaskType = 'PK'
      AND   TD.Status = 'Q'
      AND   LOC.LocAisle = @cAisle
      AND   TD.Loadkey = @cLoadkey
      ORDER BY TD.Priority, TD.TaskDetailKey

      -- If no more in same Loadplan, get the Taskkey from Other Loadplan
      IF ISNULL(RTRIM(@cNextTaskDetailKey), '') = ''
      BEGIN
          SELECT TOP 1 @cNextTaskDetailKey = TD.TaskDetailKey,
                       @cNextFromLOC = TD.FromLOC,
                       @cNextToID = TD.ToID,
                       @cNextLoadKey = TD.Loadkey,
                       @cNextStorerkey = TD.Storerkey
          FROM dbo.TaskDetail TD WITH (NOLOCK)
          JOIN dbo.LOC LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
          WHERE
          --TD.TaskDetailKey > @cTaskDetailKey AND -- (ChewKP02)
          TD.TaskType = 'PK'
          AND   TD.Status = 'Q'
          AND   LOC.LocAisle = @cAisle
          ORDER BY TD.Priority, TD.TaskDetailKey
      END

       -- Deduct from  current P&D PendingMoveIn
       DECLARE CUR_PQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT LOT, ID, SKU, SUM(QTY)
           FROM dbo.PickDetail WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))
           WHERE DropID = @cID
           --AND   LOC = @cSuggFromLoc
           AND   Storerkey = @cTaskStorer
           AND   Status = '5'
           GROUP BY LOT, ID, SKU

       OPEN CUR_PQTY
       FETCH NEXT FROM CUR_PQTY INTO @cPDLot, @cPDID, @cPDSKU, @cPDQTY
       WHILE (@@FETCH_STATUS <> -1)
       BEGIN
         IF EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)
                    WHERE Lot = @cPDLot AND LOC = @cSuggFromLoc
                    AND ID = @cPDID AND SKU = @cPDSKU AND StorerKey = @cTaskStorer)
         BEGIN
             UPDATE dbo.LotxLocxID WITH (ROWLOCK)
                SET PendingMoveIn = PendingMoveIn - @cPDQTY,
                    Trafficcop = NULL
             WHERE Lot = @cPDLot
             AND   LOC = @cSuggFromLoc
             AND   ID = @cPDID
             AND   SKU = @cPDSKU
             AND   StorerKey = @cTaskStorer

              IF @@Error <> 0
              BEGIN
                 SET @nErrNo = 68630
                 SET @cErrMsg = rdt.rdtgetmessage( 68630, @cLangCode, 'DSP') -- ErrPendingMoveIn
                 CLOSE CUR_PQTY        -- (james01)
                 DEALLOCATE CUR_PQTY   -- (james01)
                 GOTO RollBackTran
              END
         END
         FETCH NEXT FROM CUR_PQTY INTO @cPDLot, @cPDID, @cPDSKU, @cPDQTY
       END -- END WHILE (@@FETCH_STATUS <> -1)
       CLOSE CUR_PQTY
       DEALLOCATE CUR_PQTY


       -- Reserve current P&D for another Task
       -- Only Release Q Task IF there No Existing Task Occupying the P&D Loc
       -- (CheWKP03)
       SET @nPnDCheck = 0

       IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE TaskType = 'PK'
                  AND ToLoc = @cSuggFromLoc
                  AND Status IN ('0','3')
                  AND TaskDetailkey <> @cTaskdetailkey )
       BEGIN
            SET @nPnDCheck = 1
       END

       IF EXISTS (SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN dbo.TaskDetail TD2 WITH (NOLOCK) ON TD.ReftaskKey = TD2.TaskDetailKey
                  WHERE TD.TaskType = 'NMV'
                  AND TD.FromLoc = @cSuggFromLoc
                  AND TD.Status IN ('0','3','W')
                  AND TD2.Status NOT IN ('Q','9')
                  AND TD.TaskDetailkey <> @cTaskdetailkey )
       BEGIN
            SET @nPnDCheck = 1
       END

       IF @nPnDCheck = 0
       BEGIN
              DECLARE CUR_RQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              SELECT PD.LOT, PD.ID, PD.SKU, SUM(PD.QTY)
              FROM dbo.PickDetail PD WITH (NOLOCK)
              JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey AND PD.OrderLinenumber = OD.OrderLinenumber)
              JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.Orderkey = OD.Orderkey)
              WHERE PD.ID = @cNextToID
              AND   PD.LOC = @cNextFromLOC
              AND   PD.Storerkey = @cNextStorerkey
              AND   LPD.Loadkey = @cNextLoadKey
              AND   PD.Status not in ('4', '5', '9') -- (Vicky04)
              GROUP BY PD.LOT, PD.ID, PD.SKU

          OPEN CUR_RQTY
          FETCH NEXT FROM CUR_RQTY INTO @cRPDLot, @cRPDID, @cRPDSKU, @nRPDQTY
          WHILE (@@FETCH_STATUS <> -1)
          BEGIN

            IF @nTrace = 1 -- SOS# 182295
            BEGIN
               INSERT dbo.TraceInfo (TraceName, TimeIn, Step1, Step2, Col1, Col2
                                         , Col3, Col4, Col5)
               VALUES('rdtfnc_TM_NonInventory_Move', GETDATE(), @cNextTaskDetailKey, @nRPDQTY, @cNextStorerkey, @cRPDSKU
                    , @cRPDLot, @cSuggFromLoc, @cRPDID)
            END

            -- If P&D already have information
            IF NOT EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)
                           WHERE Lot = @cRPDLot AND LOC = @cSuggFromLoc
                           AND ID = @cRPDID AND SKU = @cRPDSKU AND StorerKey = @cNextStorerkey)

            BEGIN
              INSERT dbo.LOTxLOCxID (STORERKEY, SKU, LOT, LOC, ID, PendingMoveIn, ArchiveCop) -- SOS# 182295
              VALUES (@cNextStorerkey, @cRPDSKU, @cRPDLot, @cSuggFromLoc, @cRPDID, @nRPDQTY, 'M')   -- SOS# 182295

              IF @@Error <> 0
              BEGIN
                 SET @nErrNo = 68631
                 SET @cErrMsg = rdt.rdtgetmessage( 68631, @cLangCode, 'DSP') -- ErrInsPendingMoveIn
                 CLOSE CUR_RQTY
                 DEALLOCATE CUR_RQTY
                 GOTO RollBackTran
              END
            END
            ELSE
            BEGIN
               UPDATE dbo.LotxLocxID WITH (ROWLOCK)
                  SET PendingMoveIn = PendingMoveIn + @nRPDQTY,
                  Trafficcop = NULL
                , ArchiveCop = 'm' -- SOS# 182295
               WHERE Lot = @cRPDLot
               AND   LOC = @cSuggFromLoc
               AND   ID = @cRPDID
               AND   SKU = @cRPDSKU
               AND   StorerKey = @cNextStorerkey

               -- (james01)
               IF @@Error <> 0
               BEGIN
                  SET @nErrNo = 68637
                  SET @cErrMsg = rdt.rdtgetmessage( 68637, @cLangCode, 'DSP') -- ErrUpdPenMvIn
                  CLOSE CUR_RQTY
                  DEALLOCATE CUR_RQTY
                  GOTO RollBackTran
               END
            END

          FETCH NEXT FROM CUR_RQTY INTO @cRPDLot, @cRPDID, @cRPDSKU, @nRPDQTY
          END -- END WHILE (@@FETCH_STATUS <> -1)
          CLOSE CUR_RQTY
          DEALLOCATE CUR_RQTY

          -- (ChewKP10)
          SET @cFromLocCategory = ''
          SELECT @cFromLocCategory = ISNULL(LocationCategory,'')
          FROM dbo.Loc WITH (NOLOCK)
          WHERE Loc = @cSuggFromLoc
          AND Facility = @cFacility

          IF @cFromLocCategory IN ('PnD_Ctr' ,'PnD_Out') AND @cNextTaskFacility = @cFacility -- (ChewKP10)
          BEGIN
             UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET Status = '0',
                   ToLoc = @cSuggFromLoc,
                   LogicalToLoc = @cSuggFromLoc,
                   EditDate = GETDATE(),
                   EditWho  = @cUsername,
                   Trafficcop = NULL,
                   StartTime  = GETDATE()   -- SOS# 176725
                 , Message02 = 'MVPKQto0'   -- SOS# 182295
             WHERE TaskDetailKey = @cNextTaskdetailkey
             AND   TaskType = 'PK'
             AND   Status = 'Q'

             -- (james01)
             IF @@Error <> 0
             BEGIN
               SET @nErrNo = 68632
               SET @cErrMsg = rdt.rdtgetmessage( 68632, @cLangCode, 'DSP') -- ErrUpdTaskDetail
               GOTO RollBackTran
             END

             UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET FromLOC = @cSuggFromLoc,
                   LogicalFromLoc = @cSuggFromLoc,
                   EditDate = GETDATE(),
                   EditWho  = @cUsername,
                   Trafficcop = NULL
             WHERE RefTaskKey = @cNextTaskdetailkey
             AND   TaskType = 'NMV'
             AND   Status = 'W'

             -- (james01)
             IF @@Error <> 0
             BEGIN
               SET @nErrNo = 68635
               SET @cErrMsg = rdt.rdtgetmessage( 68635, @cLangCode, 'DSP') -- ErrUpdTaskDetail
               GOTO RollBackTran
             END
          END
      END -- END IF EXISTS -- (CheWKP03)

      -- Update TaskManagerUser table (ToLOC)
      UPDATE dbo.TaskManagerUser WITH (ROWLOCK)
         SET LastLoc = @cFromLoc,
             LastDropID = @cID,
             EditDate = GETDATE(),
             EditWho  = @cUsername,
             Trafficcop = NULL
      WHERE UserKey = @cUsername

      IF @@Error <> 0
      BEGIN
         SET @nErrNo = 68638     -- (james01)
         SET @cErrMsg = rdt.rdtgetmessage( 68638, @cLangCode, 'DSP') -- ErrUpdTskMgUsr
         GOTO RollBackTran
      END

      -- Extended update
      SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cToLOC, @cNextTaskDetailKeys, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile             INT,          ' +
               '@nFunc               INT,          ' +
               '@cLangCode           NVARCHAR( 3), ' +
               '@nStep               INT,          ' +
               '@cTaskdetailKey      NVARCHAR(10), ' +
               '@cToLOC              NVARCHAR(10), ' +
               '@cNextTaskDetailKeys NVARCHAR(10), ' +
               '@nErrNo              INT          OUTPUT, ' +
               '@cErrMsg             NVARCHAR(20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cToLOC, @cNextTaskDetailKeys, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO RollBackTran
         END
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN TM_NMV_ConfirmTask

       -- EventLog - QTY
       EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cTaskStorer,
         @cLocation     = @cSuggFromLoc,
         @cToLocation   = @cToLOC,
         @cToID         = @cID, -- DropID
         @cSKU          = '',
         @cLoadkey      = @cLoadkey,
         @nStep         = @nStep
         --@cRefNo1       = @cLoadkey --(Vicky02)

       -- prepare next screen
       SET @cOutField01 = ''
       SET @cOutField02 = ''
       SET @cOutField03 = ''
       SET @cOutField04 = ''
       SET @cOutField05 = ''
       SET @cOutField06 = ''
       SET @cOutField07 = ''
       SET @cOutField08 = ''
       SET @cOutField09 = ''
       SET @cOutField10 = ''

       SET @nPrevStep = 0

       -- Go to next screen
       SET @nScn = @nScn + 2
       SET @nStep = @nStep + 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSuggFromLoc
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

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

      IF @nPrevStep = 0
      BEGIN
       SET @nPrevStep = @nStep
       SET @cToLOC = ''
      END

      -- go to previous screen
     SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToLOC = ''

   -- Reset this screen var
      SET @cOutField01 = @cSuggID
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = @cSuggToLoc
      SET @cOutField04 = ''
      SET @cOutField05 = ''
   END
   GOTO Quit   -- (james02)

   RollBackTran:
      ROLLBACK TRAN TM_NMV_ConfirmTask

END
GOTO Quit


/********************************************************************************
Step 4. screen = 2213
     Success Message
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1
   BEGIN

      SET @cID = ''
      SET @cSuggFromLoc = ''
      SET @cTaskdetailkey = ''
      SET @cTTMStrategykey = ''
      SET @cNextTaskDetailKeys = ''

      -- Search for next task and redirect screen
      EXEC dbo.nspTMTM01
         @c_sendDelimiter = null
      ,  @c_ptcid         = 'RDT'
      ,  @c_userid        = @cUserName
      ,  @c_taskId        = 'RDT'
      ,  @c_databasename  = NULL
      ,  @c_appflag       = NULL
      ,  @c_recordType    = NULL
      ,  @c_server        = NULL
      ,  @c_ttm           = NULL
      ,  @c_areakey01     = @cAreaKey
      ,  @c_areakey02     = ''
      ,  @c_areakey03     = ''
      ,  @c_areakey04     = ''
      ,  @c_areakey05     = ''
      ,  @c_lastloc       = @cFromLoc--@cSuggToLoc (Vicky01)
      ,  @c_lasttasktype  = 'NMV'
      ,  @c_outstring     = @c_outstring    OUTPUT
      ,  @b_Success       = @b_Success      OUTPUT
      ,  @n_err           = @nErrNo         OUTPUT
      ,  @c_errmsg        = @cErrMsg        OUTPUT
      ,  @c_taskdetailkey = @cNextTaskDetailKeys OUTPUT
      ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
      ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

      IF ISNULL(RTRIM(@cNextTaskDetailKeys), '') = '' --@nErrNo = 67804 -- Nothing to do!
      BEGIN
         -- EventLog - Sign In Function
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign out function
            @cUserID     = @cUserName,
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerKey,
            @nStep       = @nStep

          -- Go back to Task Manager Main Screen
          SET @nFunc = 1756
          SET @nScn = 2100
          SET @nStep = 1

          SET @cErrMsg = 'No More Task'
          SET @cAreaKey = ''

          SET @cOutField01 = ''  -- Area
          SET @cOutField02 = ''
          SET @cOutField03 = ''
          SET @cOutField04 = ''
          SET @cOutField05 = ''
          SET @cOutField06 = ''
          SET @cOutField07 = ''
          SET @cOutField08 = ''

          GOTO QUIT
      END

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
        SET @cErrMsg = @cErrMsg
        GOTO Step_4_Fail
      END

      -- Extended update
      SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cToLOC, @cNextTaskDetailKeys, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile             INT,          ' +
               '@nFunc               INT,          ' +
               '@cLangCode           NVARCHAR( 3), ' +
               '@nStep               INT,          ' +
               '@cTaskdetailKey      NVARCHAR(10), ' +
               '@cToLOC              NVARCHAR(10), ' +
               '@cNextTaskDetailKeys NVARCHAR(10), ' +
               '@nErrNo              INT          OUTPUT, ' +
               '@cErrMsg             NVARCHAR(20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cToLOC, @cNextTaskDetailKeys, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_4_Fail
         END
      END

      SET @nToFunc = 0
      SET @nToScn = 0

      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = RTRIM(@cTTMTasktype)

      IF @nFunc = 0
      BEGIN
        SET @nErrNo = 67677
        SET @cErrMsg = rdt.rdtgetmessage( 67677, @cLangCode, 'DSP') -- NextTaskFncErr
        GOTO Step_4_Fail
      END

      SELECT TOP 1 @nToScn = Scn
      FROM RDT.RDTScn WITH (NOLOCK)
      WHERE Func = @nToFunc
      ORDER BY Scn

      IF @nToScn = 0
      BEGIN
        SET @nErrNo = 67678
        SET @cErrMsg = rdt.rdtgetmessage( 67678, @cLangCode, 'DSP') --NextTaskScnErr
        GOTO Step_4_Fail
      END

      SET @cOutField01 = @cRefKey01
      SET @cOutField02 = @cRefKey02
      SET @cOutField03 = @cRefKey03
      SET @cOutField04 = @cRefKey04
      SET @cOutField05 = @cRefKey05
      SET @cOutField06 = @cNextTaskDetailKeys
      SET @cOutField07 = @cAreaKey
      SET @cOutField08 = @cTTMStrategykey

       -- (Vicky09)
      IF @nTrace = 1
      BEGIN
         SELECT @cTStatus = Status,
                @cTUser = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cNextTaskDetailKeys

         INSERT INTO RDT.RDTTMLOG (UserName, TaskUserName, MobileNo, AreaKey, TaskType, PrevTaskdetailkey, Taskdetailkey, PrevStatus, CurrStatus, Func, Scn, Step)
         VALUES (@cUsername, @cTUser, @nMobile, @cAreaKey, 'NMV_Succ', @cTaskdetailkey, @cNextTaskDetailKeys, '', @cTStatus, @nFunc, @nScn, @nStep)
      END

      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      SET @nFunc = @nToFunc
      SET @nScn = @nToScn
      SET @nStep = 1
   END

   IF @nInputKey = 0    --ESC
   BEGIN
      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

     -- Go back to Task Manager Main Screen
     SET @nFunc = 1756
     SET @nScn = 2100
     SET @nStep = 1

     SET @cAreaKey = ''

     SET @cOutField01 = ''  -- Area
     SET @cOutField02 = ''
     SET @cOutField03 = ''
     SET @cOutField04 = ''
     SET @cOutField05 = ''
     SET @cOutField06 = ''
     SET @cOutField07 = ''
     SET @cOutField08 = ''
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
       SET @cRefKey01 = ''
       SET @cRefKey02 = ''
       SET @cRefKey03 = ''
       SET @cRefKey04 = ''
       SET @cRefKey05 = ''
       SET @cTaskdetailkey = ''
   END
END
GOTO Quit

/********************************************************************************
-- (ChewKP08)
Step 5. screen = 2214
     FromLoc(Field01)
     SuggID (Field02)
     DropID (Field03, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cInID = ISNULL(@cInField03  ,'')

      IF @cInID = ''
      BEGIN
         SET @nErrNo = 68643
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID Req
         GOTO Step_5_Fail
      END

      IF @cInID <> @cSuggID
      BEGIN
         SET @cOverRideID = ''
         SET @cOverRideID = rdt.RDTGetConfig( @nFunc, 'RDTOverRideID', @cStorerKey)

         IF @cOverRideID <> '1'
         BEGIN
            SET @nErrNo = 68644
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
            GOTO Step_5_Fail
         END
         ELSE
         BEGIN
            -- Check If ID is Exist in the Task List
            IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                           WHERE FromID      = @cInID
                           AND StorerKey = @cStorerKey
                           AND FromLoc   = @cFromLoc
                           AND TaskType  = 'NMV'
                           AND Status    = '0'
                           AND TaskDetailKey <> @cTaskDetailKey)
            BEGIN
               SET @nErrNo = 68645
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
               GOTO Step_5_Fail
            END

            -- ID is Swap -- Update Previous TaskDetail.Status , User to Blank and Update the Relevant Info to the Current Task
            UPDATE dbo.TaskDetail WITH (ROWLOCK)
            SET Status = '0'
               ,UserKey = ''
            WHERE TaskDetailKey = @cTaskDetailKey

            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 68646
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail
               GOTO Step_5_Fail
            END

            SET @cNewTaskdetailkey = ''

            SELECT TOP 1 @cNewTaskdetailkey  = TaskDetailKey
                         ,@cSuggToLoc = ToLoc
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE FromID        = @cInID
              AND StorerKey = @cStorerKey
              AND FromLoc   = @cFromLoc
              AND TaskType  = 'NMV'
              AND TaskDetailKey <> @cTaskDetailKey
              AND Status = '0'
            Order by Priority, TaskDetailKey

            IF @cNewTaskDetailKey <> ''
            BEGIN
               SET @cTaskDetailKey = @cNewTaskDetailKey
               SET @cSuggID = @cInID

               Update dbo.TaskDetail WITH (ROWLOCK)
               SET Status ='3'
                  ,UserKey = @cUserName
               WHERE TaskDetailKey = @cTaskDetailKey
            END
         END
      END

      -- Extended update
      SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cToLOC, @cNextTaskDetailKeys, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile             INT,          ' +
               '@nFunc               INT,          ' +
               '@cLangCode           NVARCHAR( 3), ' +
               '@nStep               INT,          ' +
               '@cTaskdetailKey      NVARCHAR(10), ' +
               '@cToLOC              NVARCHAR(10), ' +
               '@cNextTaskDetailKeys NVARCHAR(10), ' +
               '@nErrNo              INT          OUTPUT, ' +
               '@cErrMsg             NVARCHAR(20) OUTPUT'
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cToLOC, @cNextTaskDetailKeys, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Goto To Loc Screen
      SET @cOutField01 = @cSuggID
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = @cSuggToLoc
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      SET @nFromScn  = @nScn
      SET @nFromStep = @nStep

      -- Go to next screen
      SET @nScn = @nScnToLoc
      SET @nStep = @nStepToLoc
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
       --go to previous screen
       SET @cOutField01 = @cSuggID
       SET @cOutField02 = @cFromLoc
       SET @cOutfield03 = ''

       SET @nScn = @nScnFromLoc
       SET @nStep = @nStepFromLoc
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = ''
   END
END


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg,
       Func          = @nFunc,
       Step          = @nStep,
       Scn           = @nScn,

       StorerKey     = @cStorerKey,
       Facility      = @cFacility,
       Printer       = @cPrinter,
       -- UserName      = @cUserName,

       V_LOC         = @cFromloc,
       V_ID          = @cID,
       V_UOM         = @cUOM,
       --V_QTY         = @nQTY,
       V_Loadkey     = @cLoadkey,
       
       V_Integer1    = @nQTY,
       V_Integer2    = @nSuggQTY_Ctn,
       V_Integer3    = @nPrevStep,
       V_Integer4    = @nSuggQTY_Pcs,
       V_Integer5    = @nSumPDQTY,
       V_Integer6    = @nActQTY_Ctn,
       V_Integer7    = @nActQTY_Pcs,
       V_Integer8    = @nTrace,
   
       V_FromStep    = @nFromStep,
       V_FromScn     = @nFromScn,

-- (ChewKP05)
--       V_String1     = @cAreaKey,
--       V_String2     = @cTTMStrategykey,

       V_String3     = @cToloc,
       V_String4     = @cReasonCode,
       V_String5     = @cTaskdetailkey,

       V_String6     = @cSuggFromloc,
       V_String7     = @cSuggToloc,
       V_String8     = @cSuggID,
       --V_String9     = @nSuggQTY_Ctn,
       V_String10    = @cUserPosition,
       --V_String11    = @nPrevStep,
       V_String12    = @cPrevTaskdetailkey,
       V_String13    = @cPackkey,
      -- V_String14    = @nFromStep,
       --V_String15    = @nFromScn,
       V_String16    = @cTaskStorer,

       V_String17    = @cPrepackByBOM,
       --V_String18    = @nSuggQTY_Pcs,
       --V_String19    = @nSumPDQTY,

       --V_String20    = @nActQTY_Ctn,
       --V_String21    = @nActQTY_Pcs,

       V_String22    = @cPackUOM1,
       V_String23    = @cPackUOM3,

       --V_String24    = @nTrace, -- (Vicky09)

       V_String32    = @cAreaKey,         --(ChewKP05)
       V_String33    = @cTTMStrategykey,  --(ChewKP05)
       V_String34    = @cTTMTasktype,     --(ChewKP05)
       V_String35    = @cRefKey01,        --(ChewKP05)
       V_String36    = @cRefKey02,        --(ChewKP05)
       V_String37    = @cRefKey03,        --(ChewKP05)
       V_String38    = @cRefKey04,        --(ChewKP05)
       V_String39    = @cRefKey05,        --(ChewKP05)

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