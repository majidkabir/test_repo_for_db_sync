SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_TM_TotePicking                                    */
/* Copyright      : LF Logistics                                             */
/*                                                                           */
/* Purpose: RDT Task Manager - Tote Picking                                  */
/*          Called By rdtfnc_TaskManager                                     */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2014-05-29 1.0  Shong                                                     */
/* 2014-07-08 1.1  ChewKP   Fixes DropID not update when lock > 2 task       */
/*                          (ChewKP01)                                       */
/* 2014-07-23 1.2  Leong    SOS#316564 - Get PickMethod from TaskDetail.     */
/* 2014-08-01 1.3  ChewKP   SOS#313947 DTC Enhancement (ChewKP02)            */
/* 2014-09-26 1.4  ChewKP   Only Swap task with Status = 0 (ChewKP03)        */
/* 2014-10-03 1.5  ChewKP   Update DropID.Status = '5' once confirm pick     */
/*                          Update ListKey = DropID (ChewKP04)               */
/* 2014-10-27 1.6  Leong    SOS#323841 - Clear ListKey when close tote.      */
/* 2015-01-15 1.7  ChewKP   SOS#330270 - Add ExtendedValidation (ChewKP05)   */
/* 2015-12-29 1.8  ChewKP   SOS#358813 - Add WCS Config check to generate    */
/*                          WCSRouting records                               */
/*                          Add ExtendedInfo Config                          */ 
/*                          Add ConfirmSP Config (ChewKP06)                  */
/* 2016-09-30 1.9  Ung      Performance tuning                               */   
/* 2018-08-27 2.0  ChewKP   WMS-6052 - Standardize EventLog (ChewKP07)       */
/* 2018-11-15 2.1  Gan      Performance tuning                               */
/* 2021-03-08 2.2  James    WMS-15657 Add ExtendedWCSSP (james01)            */
/* 2021-07-29 2.3  James    Add ExtendedWCSSP to step 7 (james02)            */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_TM_TotePicking](
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

   @cAreaKey            NVARCHAR(10),
   @cStrategykey        NVARCHAR(10),
   @cTTMStrategykey     NVARCHAR(10),
   @cTTMTasktype        NVARCHAR(10),
   @cFromLoc            NVARCHAR(10),
   @cSuggFromLoc        NVARCHAR(10),
   @cToLoc              NVARCHAR(10),
   @cSuggToLoc          NVARCHAR(10),
   @cTaskdetailkey      NVARCHAR(10),
   @cID                 NVARCHAR(18),
   @cSuggID             NVARCHAR(18),
   @cUOM                NVARCHAR(5),   -- Display NVARCHAR(5)
   @cReasonCode         NVARCHAR(10),
   @cSKU                NVARCHAR(20),
   @cTaskStorer         NVARCHAR(15),
   @cFromFacility       NVARCHAR(5),
   @c_outstring         NVARCHAR(255),
   @cUserPosition       NVARCHAR(10),
   @cQTY                NVARCHAR(5),
   @cPackkey            NVARCHAR(10),
   @cNextTaskDetailKey  NVARCHAR(10),

   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),
   @cListKey            NVARCHAR(10),

   @nQTY                INT,
   @nToFunc             INT,
   @nSuggQTY            INT,
   @nPrevStep           INT,
   @nFromStep           INT,
   @nFromScn            INT,
   @nToScn              INT,

   @cLoc                NVARCHAR( 10),

   @cPUOM               NVARCHAR( 1), -- Prefer UOM
   @cPrepackByBOM       NVARCHAR( 1),

   @cCaseID             NVARCHAR(10),
   @cInToteID           NVARCHAR(18),
   @cInSKU              NVARCHAR(20),
   @cLot                NVARCHAR(10),
   @cWaveKey            NVARCHAR(10),

   @cPickMethod  NVARCHAR(10),
   @cToteNo             NVARCHAR(18),
   @cDescr1             NVARCHAR(20),
   @cDescr2             NVARCHAR(20),
   @nScanQty            INT,
   @cSHTOption          NVARCHAR(1),
   @cLoadkey            NVARCHAR(10),
   @cContinueProcess    NVARCHAR(10),
   @cTaskDetailKeyPK    NVARCHAR(10),
   @nRemainQty          INT,
   @cQCLOC              NVARCHAR(10),
   @cCurrPutawayzone    NVARCHAR(10),
   @c_RTaskDetailkey    NVARCHAR(10),
   @cFinalPutawayzone   NVARCHAR(10),
   @cPPAZone            NVARCHAR(10),
   @nTranCount          INT,
   @cOrderkey           NVARCHAR(10),
   @nTotalToteQTY       INT,
   @cActionFlag         NVARCHAR(1),
   @cNewToteNo          NVARCHAR(18),
   @cShortPickFlag      NVARCHAR(1),
   @cRemoveUserTask     NVARCHAR(1),
   @cCurrArea           NVARCHAR(10),
   @cPA_AreaKey         NVARCHAR(10),
   @cTMAutoShortPick    NVARCHAR(1),
   @cAlertMessage       NVARCHAR( 255),
   @nStep_ConfirmTote   INT,
   @nScn_ConfirmTote    INT,
   @cModuleName         NVARCHAR( 45),
   @cOption             NVARCHAR( 1),
   @bSuccess            INT,
   @cDefaultToteLength  NVARCHAR( 1),
   @cLocAisle           NVARCHAR( 10),
   @cPrevToteID         NVARCHAR( 18),
   @cPickSlipNo         NVARCHAR( 10),
   @cTaskStatus         NVARCHAR(10),
   @cCloseTote          NVARCHAR(1), -- (ChewKP02)
   @cExtendedValidateSP NVARCHAR(30),   -- (ChewKP05)
   @cSQL                NVARCHAR(1000), -- (ChewKP05)
   @cSQLParam           NVARCHAR(1000), -- (ChewKP05)
   @cWCS                NVARCHAR(1),    -- (ChewKP06)
   @cConfirmSP          NVARCHAR(30),   -- (ChewKP06)
   @cExtendedInfoSP     NVARCHAR(30),   -- (CheWKP06) 
   @cOutInfo01          NVARCHAR(20),   -- (ChewKP06)
   @cOutInfo02          NVARCHAR(20),   -- (ChewKP06)
   @cNTaskDetailkey     NVARCHAR(10),   -- (ChewKP06)
   @nSKUCnt             INT,            -- (ChewKP06)
   @cExtendedWCSSP      NVARCHAR( 20),  -- (james01)

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

   @cSKU             = V_SKU,
   @cFromLoc         = V_LOC,
   @cID              = V_ID,
   @cPUOM            = V_UOM,
  -- @nQTY             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,
   @cLot             = V_Lot,
   @cCaseID          = V_CaseID,
   @cPickSlipNo      = V_PickSlipNo,
   
   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,
   
   @nQTY             = V_Integer1,
   @nSuggQTY         = V_Integer2,
   @nPrevStep        = V_Integer3,
   @nScanQty         = V_Integer4,
   @nTotalToteQTY    = V_Integer5,

   @cToteNo          = V_String1,
   @cPickMethod      = V_String2,
   @cToLoc           = V_String3,
   @cReasonCode      = V_String4,
   @cTaskdetailkey   = V_String5,

   @cSuggFromloc     = V_String6,
   @cSuggToloc       = V_String7,
   @cSuggID          = V_String8,
   @cExtendedWCSSP   = V_String9,
  -- @nSuggQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,

   @cUserPosition    = V_String10,
  -- @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,
   @cNextTaskDetailKey = V_String12,
   @cPackkey         = V_String13,
  -- @nFromStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,
  -- @nFromScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,
   @cTaskStorer      = V_String16,
   @cDescr1          = V_String17,
   @cDescr2          = V_String18,
  -- @nScanQty         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19, 5), 0) = 1 THEN LEFT( V_String19, 5) ELSE 0 END,

   @cLoadkey           = V_String20,
   @cTaskDetailKeyPK   = V_String21,
   @cCurrPutawayzone   = V_String22,
   @cFinalPutawayzone  = V_String23,
   @cPPAZone           = V_String24,
   @cUOM               = V_String25,
   @cOrderkey          = V_String26,
   @cPrevToteID        = V_String27,
   @cPrepackByBOM      = V_String28,
  -- @nTotalToteQTY      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String29, 5), 0) = 1 THEN LEFT( V_String29, 5) ELSE 0 END,

   @cNewToteNo         = V_String30,
   @cShortPickFlag     = V_String31,
   @cAreakey           = V_String32,
   @cTTMStrategykey    = V_String33,
   @cTTMTasktype       = V_String34,
   @cRefKey01          = V_String35,
   @cRefKey02          = V_String36,
   @cRefKey03          = V_String37,
   @cRefKey04          = V_String38,
   @cRefKey05          = V_String39,
   @cWaveKey           = V_String40,

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

   @cFieldAttr01 =  FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

DECLARE @nStepShortPickCloseTote INT,
        @nStepEmptyTote          INT,
        @nStepFromLoc            INT,
        @nStepReasonCode         INT,
        @nStepDiffTote           INT,
        @nStepWithToteNo         INT,
        @nScnShortPickCloseTote  INT,
        @nScnFromLoc           INT,
        @nScnToteNo            INT,
        @nScnEmptyTote         INT,
        @nScnDiffTote          INT,
        @nScnSKU               INT,
        @nScnWithToteNo        INT


-- Redirect to respective screen
IF @nFunc = 1809
BEGIN
   SET @nStepShortPickCloseTote = 4
   SET @nStepFromLoc            = 2
   SET @nStepWithToteNo         = 7
   SET @nStepReasonCode         = 9
   SET @nStepEmptyTote          = 11
   SET @nStepDiffTote           = 12
   SET @nStep_ConfirmTote       = 13
   SET @nScnToteNo              = 3880
   SET @nScnEmptyTote           = 2107
   SET @nScnShortPickCloseTote  = 3883
   SET @nScnFromLoc             = 3881
   SET @nScnDiffTote            = 3889
   SET @nScnSKU                 = 3882
   SET @nScnWithToteNo          = 3886
   SET @nScn_ConfirmTote        = 3890

   IF @nStep = 1  GOTO Step_1   -- Menu. Func = 1760, Scn = 3880 -- TOTE ID ID (NEW TOTE)
   IF @nStep = 2  GOTO Step_2   -- Scn = 3881   FromLOC
   IF @nStep = 3  GOTO Step_3   -- Scn = 3882   SKU
   IF @nStep = 4  GOTO Step_4   -- Scn = 3883   Short Pick / Close Tote
   IF @nStep = 5  GOTO Step_5   -- Scn = 3884   TOTE CLOSED MSG
   IF @nStep = 6  GOTO Step_6   -- Scn = 3885   MSG (Need to Pick from Other Zone)
   IF @nStep = 7  GOTO Step_7   -- Menu. Func = 1760, Scn =3886 -- TOTE ID ID (TOTE FROM OTHER ZONE)
   IF @nStep = 8  GOTO Step_8   -- Scn = 3887   No More Task For This Tote MSG
   IF @nStep = 9  GOTO Step_9   -- Scn = 2109   REASON Screen
   IF @nStep = 10 GOTO Step_10  -- Scn = 3888   Msg (Enter / Exit)
   IF @nStep = 11 GOTO Step_11  -- Scn = 2107   Take empty tote
   IF @nStep = 12 GOTO Step_12  -- Scn = 3889   Different Tote?
   IF @nStep = 13 GOTO Step_13  -- Scn = 3890   Tote same as SKU?
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 1. Called from Task Manager Main Screen (func = 1760)
    Screen = 2430 (NEW TOTE)
    PICKTYPE: (Field04)
    TOTE NO (Field05, input)
********************************************************************************/
Step_1:
BEGIN
   -- Set all variable for 1st record - records are from rdtfnc_TaskManager
   IF @nPrevStep = 0
   BEGIN
      SET @cTaskdetailkey  = @cOutField06
      SET @cAreaKey        = @cOutField07
      SET @cTTMStrategykey = @cOutField08
      --SET @cPickMethod     = @cOutField04 -- SOS#316564

      SET @cNextTaskDetailKey = ''
      SET @cShortPickFlag = 'N'
      SET @nScanQty = 0

      SELECT TOP 1
             @cTaskStorer = RTRIM(TD.Storerkey),
             @cSKU        = RTRIM(TD.SKU),
             @cSuggID     = RTRIM(TD.FromID),
             @cSuggToLoc  = RTRIM(TD.ToLOC),
             @cLot        = RTRIM(TD.Lot),
             @cSuggFromLoc  = RTRIM(TD.FromLoc),
             @nSuggQTY    = TD.Qty,
             @cLoadkey    = RTRIM(LPD.Loadkey),
             @cOrderkey   = RTRIM(PD.Orderkey),
             @cWaveKey    = ISNULL(TD.WaveKey,''),
             @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
           , @cPickMethod = ISNULL(RTRIM(TD.PickMethod),'') -- SOS#316564
           , @cListKey    = ISNULL(RTRIM(ListKey),'') -- (ChewKP04)
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
      JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
      WHERE TD.TaskDetailKey = @cTaskdetailkey

      SELECT @cCurrPutawayzone = Putawayzone
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @cSuggFromLoc
      AND Facility = @cFacility

      SELECT @cFinalPutawayzone = Putawayzone
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @cSuggToLoc
      AND Facility = @cFacility
   END

   INSERT INTO TraceInfo ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5 )
   VALUES ( 'TotePK', GETDATE(), '*Step1*', @cAreaKey, @cTTMStrategykey, @nMobile, @cTaskDetailKey, @nSuggQTY, @cLoadkey, @cSKU, @cSuggFromLoc, @cUserName )

   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @nScanQty = 0
      SET @cShortPickFlag = 'N'
      SET @nTotalToteQTY = 0
      SET @cNextTaskDetailKey = ''

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

      SET @cInToteID = ISNULL(RTRIM(@cInField05),'')

--      IF ISNULL(@cPrevToteID, '') = ''
--      BEGIN
--         SET @cPrevToteID = @cInToteID
--         SET @cOutField05 = @cInToteID
--         GOTO Quit
--      END
--      ELSE
      BEGIN
         IF @cPrevToteID <> @cInToteID AND ISNULL(@cPrevToteID, '') <> ''
         BEGIN
            SET @nErrNo = 90092
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTE NOT SAME
            SET @cPrevToteID = ''
            GOTO Step_1_Fail
         END
      END

      SET @cPrevToteID = ''
      IF @cInToteID = ''
      BEGIN
         SET @nErrNo = 90016
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTENO Req
         GOTO Step_1_Fail
      END

      IF rdt.rdtIsValidQTY( @cInToteID, 1) = 0
      BEGIN
         SET @nErrNo = 90056
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo
         GOTO Step_1_Fail
      END

      -- Check if it is a PA tote/case
      IF EXISTS (SELECT 1 FROM dbo.TASKDETAIL WITH (NOLOCK)
                 WHERE StorerKey = @cTaskStorer
                 AND TaskType = 'PA'
                 AND Status IN ('0', 'W')
                 AND CaseID = @cInToteID)
      BEGIN
         SET @nErrNo = 90085
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo
         GOTO Step_1_Fail
      END

      -- Check the length of tote no; 0 = No Check
      SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)
      IF ISNULL(@cDefaultToteLength, '') = ''
      BEGIN
         SET @cDefaultToteLength = '8'  -- make it default to 8 digit if not setup
      END

      IF @cDefaultToteLength <> '0'
      BEGIN
         IF LEN(RTRIM(@cInToteID)) <> @cDefaultToteLength
         BEGIN
            SET @nErrNo = 90090
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTENO LEN
            GOTO Step_1_Fail
         END
      END

      IF EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)
                 WHERE Listname = 'XValidTote'
                    AND Code = SUBSTRING(RTRIM(@cInToteID), 1, 1))
      BEGIN
         SET @nErrNo = 90091
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTE NO
         GOTO Step_1_Fail
      END

      SET @cToteNo = @cInToteID
      -- Make sure user not to scan the SKU Code as Tote#
      IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cInToteID)
      BEGIN
         SET @cOutField01 = @cInToteID
         SET @cOutField02 = @cInToteID
         SET @cOutField03 = ''
         SET @cOutField09 = @cTTMTasktype

         -- Save current screen no
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep

         SET @nScn  = @nScn_ConfirmTote
         SET @nStep = @nStep_ConfirmTote

         GOTO QUIT
      END

      Continue_Step_ToTote:
      IF ISNULL(@cInToteID, '') = ''
         SET @cInToteID = @cToteNo

      
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'  
      BEGIN
         SET @cExtendedValidateSP = ''
      END

      SET @cExtendedWCSSP = rdt.RDTGetConfig( @nFunc, 'ExtendedWCSSP', @cStorerKey)
      IF @cExtendedWCSSP = '0'  
         SET @cExtendedWCSSP = ''
     
      
      
      IF @cExtendedValidateSP = '' 
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cInToteID And Status < '9' )
         BEGIN
            -- Check if every orders inside tote is canc. If exists 1 orders is open/in progress/picked then not allow
            IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                       JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
                       JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                       WHERE TD.DropID = @cInToteID
                       AND O.STATUS NOT IN ('9', 'CANC')
                       AND O.StorerKey = @cTaskStorer)
            BEGIN
               SET @nErrNo = 90076
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Used
               GOTO Step_1_Fail
            END
            ELSE
            BEGIN
               -- If every orders in tote is shipped/canc then update them to '9' and release it
               BEGIN TRAN
   
               UPDATE dbo.DropID WITH (ROWLOCK) SET
                  Status = '9'
               WHERE DropID = @cInToteID
                  AND Status < '9'
   
               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 90084
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateToteFail
                  GOTO Step_1_Fail
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
            END
         END
      END
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            
                    
              SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
                 ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @nFromStep, @cReasonCode, @cTaskDetailKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
              SET @cSQLParam =
                 '@nMobile        INT, ' +
                 '@nFunc          INT, ' +
                 '@cLangCode      NVARCHAR( 3),  ' +
                 '@nStep          INT, ' +
                 '@cStorerKey     NVARCHAR( 15), ' +
                 '@nFromStep      INT,           ' +
                 '@cReasonCode    NVARCHAR( 10), ' +
                 '@cTaskDetailKey NVARCHAR( 20), ' +
                 '@cDropID        NVARCHAR( 20), ' +
                 '@nErrNo         INT           OUTPUT, ' + 
                 '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
              
              EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @nFromStep, @cReasonCode, @cTaskDetailKey, @cToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
              

              IF @nErrNo <> 0 
              BEGIN
                GOTO  Step_1_Fail
              END
 
         END
      END

      IF EXISTS ( SELECT 1 FROM dbo.TASKDETAIL WITH (NOLOCK) WHERE DropID = @cInToteID And Status NOT IN ('9','X','3') )
      BEGIN
         SET @nErrNo = 90076
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Used
         GOTO Step_1_Fail
      END

      IF EXISTS ( SELECT 1 From dbo.DropID WITH (NOLOCK) Where DropID = @cInToteID And Status = '9' )
      BEGIN
         BEGIN TRAN

         DELETE FROM dbo.DROPIDDETAIL
         WHERE DropID = @cInToteID

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 90093
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDIDDetFail
            GOTO Step_1_Fail
         END

         DELETE FROM dbo.DROPID
         WHERE DropID = @cInToteID
         AND   Status = '9'

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 90094
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDropIDFail
            GOTO Step_1_Fail
         END

         COMMIT TRAN
      END

      SET @cToteNo = @cInToteID
      SELECT @cTaskStorer = RTRIM(TD.Storerkey),
             @cSKU        = RTRIM(TD.SKU),
             @cSuggID     = RTRIM(TD.FromID),
             @cSuggToLoc  = RTRIM(TD.ToLOC),
             @cLot        = RTRIM(TD.Lot),
             @cSuggFromLoc  = RTRIM(TD.FromLoc),
             @nSuggQTY    = TD.Qty,
             @cLoadkey    = RTRIM(LPD.Loadkey),
             @cOrderkey   = RTRIM(PD.Orderkey),
             @cWaveKey    = ISNULL(TD.WaveKey,''),
             @cPickSlipNo = ISNULL(PD.PickSlipNo,''),
             @cPickMethod = ISNULL(RTRIM(TD.PickMethod),''), -- SOS#316564
             @cListKey    = ISNULL(RTRIM(ListKey),'') -- (ChewKP04)
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
      JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
      WHERE TD.TaskDetailKey = @cTaskdetailkey

      SELECT @cCurrPutawayzone = Putawayzone
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @cSuggFromLoc
      AND Facility = @cFacility

      SELECT @cFinalPutawayzone = Putawayzone
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @cSuggToLoc

      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @cToteNo )
      BEGIN
         INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )
         VALUES (@cToteNo , '' , @cPickMethod, '0' , @cLoadkey, @cPickSlipNo)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 90053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'
            GOTO Step_1_Fail
         END
      END


--      IF CAST(@cToteNo AS INT) > 0
--      BEGIN
--         SET @cActionFlag = 'N'
--
--         EXEC [dbo].[ispWCSRO01]
--           @c_StorerKey     = @cTaskStorer
--         , @c_Facility      = @cFacility
--         , @c_ToteNo        = @cToteNo
--         , @c_TaskType      = 'SPK'
--         , @c_ActionFlag    = @cActionFlag -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
--         , @c_TaskDetailKey = '' -- @cTaskdetailkey
--         , @c_Username      = @cUserName
--         , @c_RefNo01       = @cLoadKey
--         , @c_RefNo02       = ''
--         , @c_RefNo03       = ''
--         , @c_RefNo04  = ''
--         , @c_RefNo05       = ''
--         , @b_debug         = '0'
--         , @c_LangCode      = 'ENG'
--         , @n_Func          = 0
--         , @b_Success       = @b_success OUTPUT
--         , @n_ErrNo         = @nErrNo    OUTPUT
--         , @c_ErrMsg        = @cErrMSG   OUTPUT
--
--
--         IF @nErrNo <> 0
--         BEGIN
--            SET @nErrNo = @nErrNo
--            SET @cErrMsg = @cErrMsg  --'UpdWCSRouteFail'
--            GOTO Step_1_Fail
--         END
--      END

      -- Update ToteID to DropID field
      IF @cPickMethod = 'SINGLES'
      BEGIN
         BEGIN TRAN BT_002

         Update dbo.TaskDetail WITH (ROWLOCK)
               SET DropID = @cToteNo,
                   Trafficcop = NULL
         WHERE TaskDetailkey = @cTaskDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 90040
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
            ROLLBACK TRAN BT_002
            GOTO Step_1_Fail
         END

         COMMIT TRAN BT_002
      END

      IF @cPickMethod IN ('DOUBLES','MULTIS','PP','STOTE')
      BEGIN
         BEGIN TRAN BT_003

         DECLARE CUR_TOTE_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TaskDetailkey
         FROM dbo.TaskDetail TD WITH (NOLOCK)
         WHERE TD.WaveKey = @cWavekey
           AND TD.PickMethod = @cPickMethod
           AND TD.Status = '3'
           AND TD.UserKey = @cUserName
           --AND TD.DropID = ''  -- (ChewKP01)
           AND TD.TaskType IN ('SPK', 'PK' ) -- (ChewKP02)

         OPEN CUR_TOTE_TASK
         FETCH NEXT FROM CUR_TOTE_TASK INTO @c_RTaskDetailkey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            Update dbo.TaskDetail WITH (ROWLOCK)
            SET DropID = @cToteNo,
                ListKey = @cToteNo,
                Trafficcop = NULL
            WHERE TaskDetailkey = @c_RTaskDetailkey



            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90041
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN BT_003
               GOTO Step_1_Fail
            END

            FETCH NEXT FROM CUR_TOTE_TASK INTO @c_RTaskDetailkey
         END
         CLOSE CUR_TOTE_TASK
         DEALLOCATE CUR_TOTE_TASK

         -- (ChewKP06) 
         SET @cWCS = ''  
  
         SELECT @cWCS = SVALUE   
         FROM dbo.StorerConfig (NOLOCK)  
         WHERE ConfigKey = 'WCS'  
         AND StorerKey = @cStorerKey   
  
         IF @cWCS = '1'   
         BEGIN   
            -- Update WCSRoutingDetail Status = '1' Indicate Visited --
            SELECT @cPPAZone = RTRIM(SHORT)
            FROM dbo.CodeLKup WITH (NOLOCK)
            WHERE Listname = 'WCSStation'
            And Code = @cCurrPutawayzone
   
            IF ISNULL(RTRIM(@cPPAZone), '') = ''
            BEGIN
               SET @nErrNo = 90077
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WcsStatnNotSet'
               ROLLBACK TRAN BT_003
               GOTO Step_1_Fail
            END
   
            UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
            SET Status = '1'  ,
                EditWho = @cUserName,
                EditDate = GetDate()
            WHERE ToteNo = @cToteNo
              AND Zone = @cPPAZone
   
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90049
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'
               ROLLBACK TRAN BT_003
               GOTO Step_1_Fail
            END
         END
         
         COMMIT TRAN BT_003
      END

      -- When Get the first Task Update EditDate
      BEGIN TRAN
      UPDATE dbo.TaskDetail With (ROWLOCK)
      SET StartTime = GETDATE(),
          EditDate = GETDATE(),
          EditWho = @cUserName,
          DropID = @cToteNo,
          Trafficcop = NULL
      WHERE TaskDetailkey = @cTaskdetailkey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 90062
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
         ROLLBACK TRAN
         GOTO Step_1_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '1', -- Sign in function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @cDropID     = @cToteNo,
         @nStep       = @nStep


      -- prepare next screen
      SET @cUserPosition = '1'

      SET @nPrevStep = 1

      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cToteNo
      SET @cOutField03 = @cSuggFromLoc
      SET @cOutField04 = ''
      SET @cOutField05 = @cTTMTasktype

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cUserPosition = ''
      BEGIN
         SET @cUserPosition = '1'
      END

      --SET @cOutField09 = @cOutField01
      SET @cOutField01 = ''

      SET @nFromScn  = @nScn
      SET @nFromStep = @nStep
      
      -- Go to Reason Code Screen
      SET @nScn  = 2109
      SET @nStep = @nStep + 8 -- Step 9
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cInToteID = ''

      SET @cOutField04 = @cPickMethod -- Suggested FromLOC
      SET @cOutField05 = ''
      SET @cOutField09 = @cTTMTasktype
  END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2431
   PICKTYPE (Field01)
   TOTENO   (Field02)
   FROMLOC (Field03)
   FROMLOC  (Input, Field04)
********************************************************************************/
Step_2:
BEGIN
   -- ENTER
   IF @nInputKey = 1
   BEGIN
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

      -- Screen mapping
      SET @cFromLoc = ISNULL(@cInField04,'')

      IF @cFromLoc = ''
      BEGIN
         SET @nErrNo = 90017
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLoc Req
         GOTO Step_2_Fail
      END

      IF ISNULL(@cFromLoc,'') <> ISNULL(@cSuggFromLoc ,'')
      BEGIN
         SET @nErrNo = 90018
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid FromLoc
         GOTO Step_2_Fail
      END

      -- Piece Picking Therefore UOM will be Lowest Unit --
      SELECT @cDescr1 = SUBSTRING(SKU.DESCR, 1, 20),
             @cDescr2 = SUBSTRING(SKU.DESCR,21, 20),
             @cUOM    = P.PackUOM3 -- Each
      FROM dbo.SKU SKU WITH (NOLOCK)
      INNER JOIN dbo.PACK P WITH (NOLOCK) ON ( P.Packkey = SKU.Packkey )
      WHERE  SKU.SKU = @cSKU
      AND    SKU.Storerkey = @cTaskStorer


      EXEC RDT.rdt_STD_EventLog
         @cActionType = '3', 
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @cDropID     = @cToteNo,
         @cPickMethod = @cPickMethod,
         @cLocation   = @cSuggFromLoc,
         @nStep       = @nStep
         
      -- prepare next screen
      SET @nScanQty = 0
      SET @cShortPickFlag = 'N'

      SET @cOutField01 = @cToteNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cDescr1
      SET @cOutField04 = @cDescr2
      SET @cOutField05 = ''
      SET @cOutField06 = @cUOM
      SET @cOutField07 = @nScanQty
      SET @cOutField08 = @nSuggQTY
      SET @cOutField09 = @cFromLoc
      SET @cOutField10 = @cTTMTasktype

      SET @cUserPosition = '1'

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END


   IF @nInputKey = 0 -- ESC
   BEGIN
      --
      IF @cUserPosition = ''
      BEGIN
         SET @cUserPosition = '1'
      END

      IF @cPickMethod IN ('DOUBLES','MULTIS','PIECE','PP','STOTE')
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = @cTTMTasktype
         SET @nFromScn  = @nScn
         SET @nFromStep = @nStep
         SET @cShortPickFlag = 'N'
         SET @nScanQty = 0 -- (ChewKP01)
         SET @cFromLoc = '' -- (ChewKP05) 
         SET @nScn = @nScnShortPickCloseTote
         SET @nStep = @nStepShortPickCloseTote
         GOTO QUIT

      END

      -- After Scanning of ToteNo , always prompt Screen 7 when ESC --
      SET @cOutField04 = @cPickMethod
      SET @cOutField03 = @cToteNo
      SET @cOutField05 = ''
      SET @cOutField09 = @cTTMTasktype
      
      SET @cFromLoc = '' -- (ChewKP05)

      -- go to previous screen
      SET @nScn = @nScn + 5
      SET @nStep = @nStep + 5
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      --SET @cID = ''

      -- Reset this screen var
      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cToteNo
      SET @cOutField03 = @cSuggFromLoc
      SET @cOutField04 = ''
      SET @cOutField05 = @cTTMTasktype
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2432
   TOTE NO (Field01)
   SKU     (Field02)
   DESCR1  (Field03)
   DESCR2  (Field04)
   SKU     (Field05, input)
   UOM     (Field06)
   QTY     (Field07)/(Field08)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
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

      SET @cInSKU = ISNULL(@cInField05,'')

      IF @cInSKU = ''
      BEGIN
         SET @nErrNo = 90019
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Req
         GOTO Step_3_Fail
      END
      
      -- (ChewKP06) 
      
      -- Get SKU barcode count    
      --DECLARE @nSKUCnt INT    
      EXEC rdt.rdt_GETSKUCNT    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cInSKU    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
      
      -- Check SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 90098    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU    
         GOTO Step_3_Fail    
      END    
      
      -- Check multi SKU barcode    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 90099    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod    
         GOTO Step_3_Fail    
      END    
      
      -- Get SKU code    
      EXEC rdt.rdt_GETSKU    
          @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cInSKU        OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
      
      
      IF @cInSKU <> @cSKU
      BEGIN
           SET @nErrNo = 90020
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU/UPC
           GOTO Step_3_Fail
      END


      IF NOT EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) WHERE SKU = @cSKU AND Storerkey = @cTaskStorer)
      BEGIN
         SET @nErrNo = 90021
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not Exists
         GOTO Step_3_Fail
      END

      -- Scanned Qty (V_String19)
      SET @nScanQty = @nScanQty + 1

      -- Total Scanned Qty (V_String29)
      SET @nTotalToteQTY = @nTotalToteQTY + @nScanQty
      SET @cUserPosition = '1'


      IF @nScanQty = @nSuggQTY
      BEGIN
         -- //*** Call Sub-SP rdt_TM_TotePick_ConfirmTask to
         -- //*** Create PickingInfo, PickHeader
         -- //*** Batch Confirm Picking in PickDetail
         SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)  
         IF @cConfirmSP = '0'  
            SET @cConfirmSP = ''  
         
         IF @cConfirmSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')  
            BEGIN  
                 
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +  
                  '   @nMobile  , @nFunc    , @cStorerKey, @cUserName, @cFacility  , @cTaskDetailKey , @cLoadKey, @cSKU '+
                  ' , @cAltSKU  , @cLOC     , @cToLOC    , @cID      , @cToteNo    , @nPickQty       , @cStatus '+        
                  ' , @cLangCode, @nTotalQty, @nErrNo    , @cErrMsg  , @cPickMethod, @cNTaskDetailkey  '
               SET @cSQLParam =  
                  '   @nMobile          INT                    '+      
                  ' , @nFunc            INT                    '+
                  ' , @cStorerKey       NVARCHAR(15)           '+
                  ' , @cUserName        NVARCHAR(15)           '+
                  ' , @cFacility        NVARCHAR(5)            '+
                  ' , @cTaskDetailKey   NVARCHAR(10)           '+
                  ' , @cLoadKey         NVARCHAR(10)           '+
                  ' , @cSKU             NVARCHAR(20)           '+
                  ' , @cAltSKU          NVARCHAR(20)           '+
                  ' , @cLOC             NVARCHAR(10)           '+
                  ' , @cToLOC           NVARCHAR(10)           '+
                  ' , @cID              NVARCHAR(18)           '+
                  ' , @cToteNo          NVARCHAR(18)           '+
                  ' , @nPickQty         INT                    '+
                  ' , @cStatus          NVARCHAR(1)            '+
                  ' , @cLangCode        NVARCHAR(3)            '+
                  ' , @nTotalQty        INT                    '+
                  ' , @nErrNo           INT          OUTPUT    '+
                  ' , @cErrMsg          NVARCHAR(20) OUTPUT    '+
                  ' , @cPickMethod      NVARCHAR(10)           '+
                  ' , @cNTaskDetailkey  NVARCHAR(10)           '
        
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile,     @nFunc, @cTaskStorer,  @cUserName,  @cFacility,      @cTaskDetailKey,
                  @cLoadKey,    @cSKU,  '',            @cFromLoc,   '',              '',               @cToteNo,
                  @nScanQty,    '5',    @cLangCode,    @nSuggQTY,   @nErrNo OUTPUT,  @cErrMsg OUTPUT,  @cPickMethod, ''          
        
            END  
         END            
         ELSE
         BEGIN
               
            EXECUTE RDT.rdt_TM_TotePick_ConfirmTask
               @nMobile,
               @nFunc,
               @cTaskStorer,
               @cUserName,
               @cFacility,
               @cTaskDetailKey,
               @cLoadKey,
               @cSKU,
               '',
               @cFromLoc,
               '', --@cToLoc,
               '',
               @cToteNo,
               @nScanQty,
               '5',
               @cLangCode,
               @nSuggQTY,
               @nErrNo OUTPUT,
               @cErrMsg OUTPUT,
               @cPickMethod
            
         END
         IF @nErrNo <> 0
         BEGIN
            SET @nScanQty = @nScanQty - 1
            SET @nTotalToteQTY = @nTotalToteQTY - 1

            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_3_Fail
         END

         IF ISNULL( @cPickMethod, '') = ''
            SELECT @cPickMethod = ISNULL(RTRIM(TD.PickMethod),'') 
            FROM dbo.TaskDetail TD WITH (NOLOCK)
            WHERE TD.TaskDetailKey = @cTaskdetailkey
      
         -- INSERT INTO DropID and DropID Detail Table (Start) --
         BEGIN TRAN BT_004

         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @cToteNo )
         BEGIN
            INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )
            VALUES (@cToteNo , '' , @cPickMethod, '0' , @cLoadkey, @cPickSlipNo)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90053
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'
               ROLLBACK TRAN BT_004
               GOTO Step_3_Fail
            END
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DROPID = @cToteNo AND ChildID = @cSKU)
         BEGIN
            INSERT INTO DROPIDDETAIL ( DropID, ChildID)
            VALUES (@cToteNo, @cSKU )

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90054
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'
               ROLLBACK TRAN BT_004
               GOTO Step_3_Fail
            END
         END

         COMMIT TRAN BT_004
         -- INSERT INTO DropID and DropID Detail Table (End) --
         -- Retrieve Next Task (If Doubles / Multis Should Retrieve Same Task Within same zone ) -- SINGLES -- MULTIS - DOUBLES -- PIECE

         --    /**************************************/
         --    /* E-COMM SINGLES  (START)            */
         --    /* Update WCSRouting                  */
         --    /* Call TMTM01 for Next Task          */
         --    /**************************************/
         IF @cPickMethod IN ('SINGLES')
         BEGIN
            -- Update TaskDetail STatus = '9'
            BEGIN TRAN
            Update dbo.TaskDetail WITH (ROWLOCK)
            SET Status = '9' ,
                EndTime = GETDATE(),  --CURRENT_TIMESTAMP ,   -- (Vicky02)
                EditDate = GETDATE(),
                EditWho = @cUserName,
                TrafficCop = NULL
            WHERE TaskDetailkey = @cTaskDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90031
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN
               GOTO Step_3_Fail
            END
            BEGIN
               COMMIT TRAN
            END

            -- Reset Scan Qty to 0
            SET @nScanQty = 0
            SET @cShortPickFlag = 'N'

            SELECT TOP 1 @cCurrArea = AD.AREAKEY, @cLocAisle = l.LocAisle
            FROM dbo.TaskDetail td WITH (NOLOCK)
            JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc
            JOIN dbo.AREADETAIL AD (NOLOCK) ON l.PUTAWAYZONE = AD.PUTAWAYZONE
            WHERE td.TaskDetailKey = @cTaskdetailkey
               -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first
               AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END

            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                        INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                        WHERE TD.Wavekey = @cWavekey
                           AND TD.PickMethod = @cPickMethod
                           AND TD.Status = '0'
                           AND TD.TaskDetailkey <> @cTaskDetailkey
                           AND AD.AREAKEY = @cCurrArea
                           AND LOC.Facility = @cFacility
                           AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)
                           AND TD.UserKey = '')
            BEGIN
               -- Get Next TaskKey
               -- Get the task within the same aisle first
               SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Wavekey = @cWavekey
               AND TD.PickMethod = @cPickMethod
               AND TD.Status = '0'
               AND TD.TaskDetailkey <> @cTaskDetailkey
               AND LOC.Putawayzone = @cCurrPutawayzone
               AND LOC.Facility = @cFacility
               AND TD.UserKey = ''
               AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)
               AND LOC.LocAisle = @cLocAisle
               ORDER BY LOC.LogicalLocation ASC, TD.FromLOC

               -- IF same aisle no more task, get the task from same putawayzone but within same area
               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  WHERE TD.Wavekey = @cWavekey
                  AND TD.PickMethod = @cPickMethod
                  AND TD.Status = '0'
                  AND TD.TaskDetailkey <> @cTaskDetailkey
                  AND LOC.Putawayzone = @cCurrPutawayzone
                  AND LOC.Facility = @cFacility
                  AND TD.UserKey = ''
                  AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)
                  ORDER BY LOC.LogicalLocation ASC, TD.FromLOC
               END

               -- IF current putawayzone no more task, get the task from different putawayzone but within same area
               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                  WHERE TD.Wavekey = @cWavekey
                  AND TD.PickMethod = @cPickMethod
                  AND TD.Status = '0'
                  AND TD.TaskDetailkey <> @cTaskDetailkey
                  AND AD.AREAKEY = @cCurrArea
                  AND LOC.Facility = @cFacility
                  AND TD.UserKey = ''
                  AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)
                  ORDER BY LOC.LogicalLocation ASC, TD.FromLOC
               END

               SET @cTaskDetailkey = @cNextTaskDetailKey
               SET @cNextTaskDetailKey = ''

               --- GET Variable --
               SELECT TOP 1
                      @cTaskStorer = RTRIM(TD.Storerkey),
                      @cSKU        = RTRIM(TD.SKU),
                      @cSuggID     = RTRIM(TD.FromID),
                      @cSuggToLoc  = RTRIM(TD.ToLOC),
                      @cLot        = RTRIM(TD.Lot),
                      @cSuggFromLoc  = RTRIM(TD.FromLoc),
                      @nSuggQTY    = TD.Qty,
                      @cLoadkey    = RTRIM(LPD.Loadkey),
                      @cPickMethod = RTRIM(TD.PickMethod),
                      @cWaveKey    = ISNULL(TD.WaveKey,''),
                      @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
               JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
               WHERE TD.TaskDetailKey = @cTaskdetailkey

               SELECT @cCurrPutawayzone = Putawayzone
               FROM LOC WITH (NOLOCK)
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility

               BEGIN TRAN

               Update dbo.TaskDetail WITH (ROWLOCK)
                  SET DropID = @cToteNo,
                      StartTime = GETDATE(),
                      EditDate = GETDATE(),
                      EditWho = @cUserName,
                      Trafficcop = NULL,
                      UserKey = @cUserName,
                      STATUS = '3',
                      ReasonKey = ''
               WHERE TaskDetailkey = @cTaskDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90040
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  ROLLBACK TRAN
                  GOTO Step_3_Fail
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
               
         
               
               EXEC RDT.rdt_STD_EventLog
                     @cActionType = '3', 
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cStorerKey,
                     @cDropID     = @cToteNo,
                     @cPickMethod = @cPickMethod,
                     @cLocation   = @cFromLoc,
                     @cSKU        = @cSKU,
                     @cUOM        = @cUOM,
                     @nExpectedQty = @nSuggQty,
                     @cTaskType   = @cTTMTasktype,
                     @nStep       = @nStep

               -- PrePare Var for Next Screen
               -- Reset Scan Qty to 0
               SET @nScanQty = 0
               SET @cShortPickFlag = 'N'
               SET @cUserPosition = '1'

               SET @nPrevStep = 2

               SET @cOutField01 = @cPickMethod
               SET @cOutField02 = @cToteNo
               SET @cOutField03 = @cSuggFromLoc
               SET @cOutField04 = ''
               SET @cOutField05 = @cTTMTasktype

               -- There is still Task in Same Zone GOTO Screen 2
               SET @nScn = @nScn - 1
               SET @nStep = @nStep - 1
               GOTO QUIT
            END -- If Task Available in Same Zone
            ELSE
            BEGIN
               -- (Vickyxx) - visited should be updated upon close tote for SINGLES
               -- Update WCSRoutingDetail Status = '1' Indicate Visited --
               UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
               SET Status = '1'   ,
               EditWho = @cUserName , EditDate = GetDate()
               WHERE ToteNo = @cToteNo
               AND Zone = @cFinalPutawayzone

              IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90049
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'
                  ROLLBACK TRAN BT_002
                  GOTO Step_3_Fail
               END

               -- Close Tote, Set DropID status to 5
               UPDATE DropID
               SET [Status] = '5'
               WHERE Dropid   = @cToteNo
               AND   [Status] ='0'
               AND   Loadkey  = CASE WHEN ISNULL(RTRIM(@cLoadkey), '') <> '' THEN @cLoadkey ELSE DropID.LoadKey END

               -- (Vickyxx) - Update should be done only upon close Tote
               -- Update WCSRoutingDetail Status = '1' Indicate Visited --
               BEGIN TRAN
               UPDATE dbo.WCSRouting WITH (ROWLOCK)
               SET Status = '5'
               WHERE ToteNo = @cToteNo
               AND Final_Zone = @cFinalPutawayzone
               AND Status < '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90028
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'
                  ROLLBACK TRAN
                  GOTO Step_3_Fail
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
               
               EXEC RDT.rdt_STD_EventLog
                     @cActionType = '3', 
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cStorerKey,
                     @cDropID     = @cToteNo,
                     @cPickMethod = @cPickMethod,
                     @cLocation   = @cFromLoc,
                     @cSKU        = @cSKU,
                     @cUOM        = @cUOM,
                     @nExpectedQty = @nSuggQty,
                     @cTaskType   = @cTTMTasktype,
                     @nStep       = @nStep

               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedWCSSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedWCSSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cType, @cStorerKey, @cReasonCode, @cTaskDetailKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile        INT, ' +
                     '@nFunc          INT, ' +
                     '@cLangCode      NVARCHAR( 3),  ' +
                     '@nStep          INT, ' +
                     '@nInputKey      INT, ' +
                     '@cType          NVARCHAR( 10), ' +
                     '@cStorerKey     NVARCHAR( 15), ' +
                     '@cReasonCode    NVARCHAR( 10), ' +
                     '@cTaskDetailKey NVARCHAR( 20), ' +
                     '@cDropID        NVARCHAR( 20), ' +
                     '@nErrNo         INT           OUTPUT, ' + 
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
              
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, 'C', @cStorerKey, @cReasonCode, @cTaskDetailKey, @cToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
              
                  IF @nErrNo <> 0 
                     GOTO Step_3_Fail
                END
         
               -- Go to Tote Close Screen
               SET @nScn = @nScn + 5
               SET @nStep = @nStep + 5
               SET @cOutField01 = CASE WHEN ISNULL(@cToteNo, '') = '' THEN 'Tote is Closed'
                                       ELSE RTRIM(@cToteNo) + ' is Closed' END
               SET @cOutField02 = @cTTMTasktype
               GOTO QUIT
            END
            -- (Vickyxx)
         END -- ECOMM_SINGLES
         --    /**************************************/
         --    /* E-COMM SINGLES / PIECE  (END)      */
         --    /* Update WCSRouting                  */
         --    /* Call TMTM01 for Next Task          */
         --    /**************************************/

         --    /***************************************/
         --    /* E-COMM DOUBLES , MULTIS (START)    */
         --    /* Update WCSRouting                  */
         --    /* Call TMTM01 for Next Task          */
         --    /**************************************/
         IF @cPickMethod IN ('DOUBLES','MULTIS','PIECE','PP','STOTE')
         BEGIN
            -- Update TaskDetail STatus = '9'
            BEGIN TRAN
            Update dbo.TaskDetail WITH (ROWLOCK)
            SET Status = '9' ,
                EndTime = GETDATE(), --CURRENT_TIMESTAMP ,  -- (Vicky02)
                EditDate = GETDATE(),
                EditWho = @cUserName,
                TrafficCop = NULL
            WHERE TaskDetailkey = @cTaskDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90036
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN
               GOTO Step_3_Fail
            END
            BEGIN
               COMMIT TRAN
            END

            -- Get the task within the same area; there is probably more than 1 zone per area
            SELECT TOP 1
                   @cCurrArea = AD.AREAKEY,
                   @cLocAisle = LOC.LocAisle
            FROM dbo.TaskDetail td WITH (NOLOCK)
            JOIN dbo.LOC LOC (NOLOCK) ON td.FromLoc = LOC.Loc
            JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
            WHERE td.TaskDetailKey = @cTaskdetailkey
             AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END

            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                        INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                        WHERE TD.Wavekey = @cWavekey
                        AND TD.PickMethod = @cPickMethod
                        AND TD.Status = '3'
                        AND TD.TaskDetailkey <> @cTaskDetailkey
                        AND AD.AreaKey   = @cCurrArea
                        AND LOC.Facility = @cFacility
                        AND TD.UserKey   = @cUserName)
            BEGIN
               -- Get Next TaskKey
               -- Get the task within the same aisle first
               SELECT TOP 1
                      @cNextTaskDetailKey = TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Wavekey = @cWavekey
               AND TD.PickMethod = @cPickMethod
               AND TD.Status = '3'
               AND TD.TaskDetailkey <> @cTaskDetailkey
               AND LOC.Putawayzone = @cCurrPutawayzone
               AND LOC.Facility = @cFacility
               AND TD.UserKey = @cUserName
               AND LOC.LocAisle = @cLocAisle
               ORDER BY LOC.LogicalLocation ASC, TD.FromLOC

               -- IF same aisle no more task, get the task from same putawayzone but within same area
               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  WHERE TD.Wavekey = @cWavekey
                  AND TD.PickMethod = @cPickMethod
                  AND TD.Status = '3'
                  AND TD.TaskDetailkey <> @cTaskDetailkey
                  AND LOC.Putawayzone = @cCurrPutawayzone
                  AND LOC.Facility = @cFacility
                  AND TD.UserKey = @cUserName
                  ORDER BY LOC.LogicalLocation ASC, TD.FromLOC -- (SHONG07)
               END

               -- IF current putawayzone no more task, get the task from different putawayzone but within same area
               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  INNER JOIN AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                  WHERE TD.Wavekey = @cWavekey
                  AND TD.PickMethod = @cPickMethod
                  AND TD.Status = '3'
                  AND TD.TaskDetailkey <> @cTaskDetailkey
                  AND AD.AreaKey = @cCurrArea
                  AND LOC.Facility = @cFacility
                  AND TD.UserKey = @cUserName
                  ORDER BY LOC.LogicalLocation ASC, TD.FromLOC -- (SHONG07)
               END

               SET @cTaskDetailkey = @cNextTaskDetailKey
               SET @cNextTaskDetailKey = ''

               BEGIN TRAN

               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  Starttime = GETDATE(),
                  Editdate = GETDATE(),
                  EditWho = @cUserName,
                  TrafficCOP = NULL
               WHERE TaskDetailKey = @cTaskdetailkey
               AND STATUS <> '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 70195
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  ROLLBACK TRAN
                  GOTO Step_3_Fail
               END

               COMMIT TRAN
               
               EXEC RDT.rdt_STD_EventLog
                     @cActionType = '3', 
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cStorerKey,
                     @cDropID     = @cToteNo,
                     @cPickMethod = @cPickMethod,
                     @cLocation   = @cFromLoc,
                     @cSKU        = @cSKU,
                     @cUOM        = @cUOM,
                     @nExpectedQty = @nSuggQty,
                     @cTaskType   = @cTTMTasktype,
                     @nStep       = @nStep

               --- GET Variable --
               SELECT TOP 1
                      @cTaskStorer = RTRIM(TD.Storerkey),
                      @cSKU        = RTRIM(TD.SKU),
                      @cSuggID     = RTRIM(TD.FromID),
                      @cSuggToLoc  = RTRIM(TD.ToLOC),
                      @cLot        = RTRIM(TD.Lot),
                      @cSuggFromLoc  = RTRIM(TD.FromLoc),
                      @nSuggQTY    = TD.Qty,
                      @cLoadkey    = RTRIM(LPD.Loadkey),
                      @cPickMethod = RTRIM(TD.PickMethod),
                      @cOrderkey   = RTRIM(PD.Orderkey),
                      @cWaveKey    = ISNULL(TD.WaveKey,''),
                      @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
               JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
               WHERE TD.TaskDetailKey = @cTaskdetailkey

               SELECT @cCurrPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility

               -- PrePare Var for Next Screen
               -- Reset Scan Qty to 0
               SET @nScanQty = 0
               SET @cUserPosition = '1'
               SET @nPrevStep = 1
               SET @cOutField01 = @cPickMethod
               SET @cOutField02 = @cToteNo
               SET @cOutField03 = @cSuggFromLoc
               SET @cOutField04 = ''
               SET @cOutField05 = @cTTMTasktype

               -- There is still Task in Same Zone GOTO Screen 2
               SET @nScn = @nScn - 1
               SET @nStep = @nStep - 1
               GOTO QUIT

            END
            ELSE
            BEGIN
               -- No More Task in Same Zone
               -- Update LOCKED Task to Status = '0' and Userkey = '' For PickUp by Next Zone
               BEGIN TRAN
               DECLARE CursorReleaseTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailkey  FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               INNER JOIN AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
               WHERE TD.WaveKey = @cWaveKey
                     AND TD.PickMethod = @cPickMethod
                     AND TD.Status = '3'
                     AND TD.TaskDetailkey <> @cTaskDetailkey
                     AND TD.UserKey = @cUserName
                     AND AD.AreaKey <> @cCurrArea

               OPEN CursorReleaseTask
               FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  Update dbo.TaskDetail WITH (ROWLOCK)
                  SET Status = '0', UserKey = '' ,Trafficcop = NULL -- (Vicky01)
                  WHERE TaskDetailkey = @c_RTaskDetailkey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 90039
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                     ROLLBACK TRAN
                     GOTO Step_3_Fail
                  END

                  FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey
               END
               CLOSE CursorReleaseTask
               DEALLOCATE CursorReleaseTask

               COMMIT TRAN

               -- Reset Scan Qty to 0
               SET @nScanQty = 0

               IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                           WHERE WaveKey = @cWaveKey
                           AND PickMethod = @cPickMethod
                           AND DropID = @cToteNo
                           AND Status = '0'
                           AND TaskDetailkey <> @cTaskDetailkey
                           )
               BEGIN
                  -- Go to Fullfill by Other Picker MSG Screen

                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedWCSSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedWCSSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cType, @cStorerKey, @cReasonCode, @cTaskDetailKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                     SET @cSQLParam =
                        '@nMobile        INT, ' +
                        '@nFunc          INT, ' +
                        '@cLangCode      NVARCHAR( 3),  ' +
                        '@nStep          INT, ' +
                        '@nInputKey      INT, ' +
                        '@cType          NVARCHAR( 10), ' +
                        '@cStorerKey     NVARCHAR( 15), ' +
                        '@cReasonCode    NVARCHAR( 10), ' +
                        '@cTaskDetailKey NVARCHAR( 20), ' +
                        '@cDropID        NVARCHAR( 20), ' +
                        '@nErrNo         INT           OUTPUT, ' + 
                        '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
              
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, 'C', @cStorerKey, @cReasonCode, @cTaskDetailKey, @cToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
              
                     IF @nErrNo <> 0 
                        GOTO Step_3_Fail
                  END
               
                  -- (ChewKP06) 
                  SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)  
                  IF @cExtendedInfoSP = '0'  
                     SET @cExtendedInfoSP = ''  
                     
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
                  BEGIN  
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey,  @cOutInfo01 OUTPUT, @cOutInfo02 OUTPUT,' +  
                        ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'  
                     SET @cSQLParam =  
                        ' @nMobile      INT,           ' +  
                        ' @nFunc        INT,           ' +  
                        ' @cLangCode    NVARCHAR( 3),  ' +  
                        ' @nStep        INT,           ' +  
                        ' @nInputKey    INT,           ' +  
                        ' @cStorerKey   NVARCHAR( 15), ' +  
                        ' @cTaskDetailKey  NVARCHAR( 10), ' +  
                        ' @cOutInfo01    NVARCHAR( 60)   OUTPUT, ' +   
                        ' @cOutInfo02    NVARCHAR( 60)   OUTPUT, ' +   
                        ' @nErrNo        INT             OUTPUT, ' +  
                        ' @cErrMsg       NVARCHAR( 20)   OUTPUT'  
              
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cOutInfo01 OUTPUT, @cOutInfo02 OUTPUT,
                        @nErrNo      OUTPUT, @cErrMsg     OUTPUT  
              
                     IF @nErrNo <> 0  
                        GOTO Step_3_Fail  
                       
                     SET @cOutfield02 = @cOutInfo01  
                     SET @cOutfield03 = @cOutInfo02 
                       
                       
                  END  
                  ELSE  
                  BEGIN  
                     SET @cOutField02 = '' --Optional Field  
                     SET @cOutField03 = '' --Optional Field  
                  END     
                  
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType = '3', 
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cStorerKey,
                     @cDropID     = @cToteNo,
                     @cPickMethod = @cPickMethod,
                     @cLocation   = @cFromLoc,
                     @cSKU        = @cSKU,
                     @cUOM        = @cUOM,
                     @nExpectedQty = @nSuggQty,
                     @cTaskType   = @cTTMTasktype,
                     @nStep       = @nStep
                  
                  SET @cOutField01 = @cTTMTasktype
                  SET @nScn = @nScn + 3
                  SET @nStep = @nStep + 3
                  GOTO QUIT
               END
               ELSE
               BEGIN
                  BEGIN TRAN

                  -- Close Tote, Set DropID status to 5
                  UPDATE DropID
                  SET [Status] = '5'
                  WHERE Dropid   = @cToteNo
                  AND   [Status] ='0'
                  AND   Loadkey  = CASE WHEN ISNULL(RTRIM(@cLoadkey), '') <> '' THEN @cLoadkey ELSE DropID.LoadKey END

                  -- Update WCSRouting Status = '5'
                  UPDATE dbo.WCSRouting WITH (ROWLOCK)
                  SET Status = '5'
                  WHERE ToteNo = @cToteNo
                 AND Final_Zone = @cFinalPutawayzone

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 90050
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'
                     ROLLBACK TRAN
                     GOTO Step_3_Fail
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                  END

               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedWCSSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedWCSSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cType, @cStorerKey, @cReasonCode, @cTaskDetailKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile        INT, ' +
                     '@nFunc          INT, ' +
                     '@cLangCode      NVARCHAR( 3),  ' +
                     '@nStep          INT, ' +
                     '@nInputKey      INT, ' +
                     '@cType          NVARCHAR( 10), ' +
                     '@cStorerKey     NVARCHAR( 15), ' +
                     '@cReasonCode    NVARCHAR( 10), ' +
                     '@cTaskDetailKey NVARCHAR( 20), ' +
                     '@cDropID        NVARCHAR( 20), ' +
                     '@nErrNo         INT           OUTPUT, ' + 
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
              
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, 'C', @cStorerKey, @cReasonCode, @cTaskDetailKey, @cToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
              
                  IF @nErrNo <> 0 
                     GOTO Step_3_Fail
               END
               
                  EXEC RDT.rdt_STD_EventLog
                     @cActionType = '3', 
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cStorerKey,
                     @cDropID     = @cToteNo,
                     @cPickMethod = @cPickMethod,
                     @cLocation   = @cFromLoc,
                     @cSKU        = @cSKU,
                     @cUOM        = @cUOM,
                     @nExpectedQty = @nSuggQty,
                     @cTaskType   = @cTTMTasktype,
                     @nStep       = @nStep

                  -- Go to Tote Close Screen  -- 3887
                  SET @nScn = @nScn + 5
                  SET @nStep = @nStep + 5
                  SET @cOutField01 = CASE WHEN ISNULL(@cToteNo, '') = '' THEN 'Tote is Closed'
                                          ELSE RTRIM(@cToteNo) + ' is Closed' END
                  SET @cOutField02 = @cTTMTasktype
                  GOTO QUIT
               END
            END
         END
      END
      ELSE IF @nScanQty < @nSuggQty  -- If @nScanQty < @nSuggQty Continue Loop Current Screen
      BEGIN
         EXEC RDT.rdt_STD_EventLog
                     @cActionType = '3', 
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cStorerKey,
                     @cDropID     = @cToteNo,
                     @cPickMethod = @cPickMethod,
                     @cLocation   = @cFromLoc,
                     @cSKU        = @cSKU,
                     @cUOM        = @cUOM,
                     @nExpectedQty = @nSuggQty,
                     @cTaskType   = @cTTMTasktype,
                     @nStep       = @nStep
                     
         SET @cOutField01 = @cToteNo
         SET @cOutField02 = @cSKU
         SET @cOutField03 = @cDescr1
         SET @cOutField04 = @cDescr2
         SET @cOutField05 = ''
         SET @cOutField06 = @cUOM
         SET @cOutField07 = @nScanQty
         SET @cOutField08 = @nSuggQTY
         SET @cOutField09 = @cFromLoc

         -- Go to next screen
         SET @nScn = @nScn
         SET @nStep = @nStep
         GOTO QUIT
      END
      ELSE IF @nScanQty > @nSuggQty
      BEGIN
         SET @nErrNo = 90079
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OverPickXAllow'
         SET @nScanQty = 0
         GOTO Step_3_Fail
      END -- IF @nScanQty > @nSuggQty


   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''


    IF @cUserPosition = ''
      BEGIN
         SET @cUserPosition = '1'
      END

      SET @nFromScn  = @nScn
      SET @nFromStep = @nStep

      SET @cOutField02 = @cTTMTasktype

      -- go to short pick screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cToteNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cDescr1
      SET @cOutField04 = @cDescr2
      SET @cOutField05 = ''
      SET @cOutField06 = @cUOM
      SET @cOutField07 = @nScanQty
      SET @cOutField08 = @nSuggQTY
      SET @cOutField09 = @cFromLoc
      SET @cOutField10 = @cTTMTasktype
   END
END
GOTO Quit


/********************************************************************************
Step 4. screen = 2433 Short Pick / Close Tote
     OPTION (Input, Field01)
     1= Short Pick
     9= Close Tote
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --OR @nInputKey = 0 -- ENTER / ESC
   BEGIN
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

      --screen mapping
      SET @cSHTOption = ISNULL(@cInField01,'')

      IF ISNULL(RTRIM(@cSHTOption), '') = '' -- (Vicky02)
      BEGIN
         SET @nErrNo = 90022
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'
         GOTO Step_4_Fail
      END

      --IF @cSHTOption NOT IN ('1', '9')
      IF ISNULL(RTRIM(@cSHTOption), '') <> '1' AND ISNULL(RTRIM(@cSHTOption), '') <> '9' -- (Vicky02)
      BEGIN
         SET @nErrNo = 90023
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_4_Fail
      END

      IF @cSHTOption = '1'
      BEGIN
         EXEC RDT.rdt_STD_EventLog
                     @cActionType = '3', 
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cStorerKey,
                     @cDropID     = @cToteNo,
                     @cPickMethod = @cPickMethod,
                     @cLocation   = @cFromLoc,
                     @cSKU        = @cSKU,
                     @cUOM        = @cUOM,
                     @nExpectedQty = @nSuggQty,
                     @cTaskType   = @cTTMTasktype,
                     @cOption     = @cSHTOption,
                     @nStep       = @nStep
         
         SET @cOutField01    = ''
         SET @cUserPosition  = '1'
         SET @cShortPickFlag = 'Y'
         SET @nScn           = 2109
         SET @nStep          = @nStep + 5
      END

      -- Close Tote
      IF @cSHTOption = '9'
      BEGIN
         SET @cShortPickFlag = 'N'
         -- If Nothing Scan in Single Pick. Just Release the Task
         IF @cPickMethod IN ( 'SINGLES')  AND @nScanQty = 0
         BEGIN
            -- Release Previous Task
            Update dbo.TaskDetail WITH (ROWLOCK)
               SET DropID = '',
                   EndTime = GETDATE(),
                   EditDate = GETDATE(),
                   EditWho  = @cUserName,
                   UserKey = '',
                   [STATUS]  = '0',
                   Trafficcop = NULL
            WHERE TaskDetailkey = @cTaskDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90032
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'
               ROLLBACK TRAN BT_001
               GOTO Step_4_Fail
            END

            -- Initialise TaskDetailKey, so that that will continue with new task
            SET @cTaskDetailKeyPK = ''
            GOTO WCS_Routing_Process
         END -- IF @cPickMethod = 'SINGLES' AND @nScanQty = 0

         -- Update WCSRouting - Tote FULL
         -- ToteNo to DropID
         -- If there is still outstatnding PickTask to be done. For the Same TaskDetailkey , Goto Screen 7 -- (SINGLES)
         -- Retrieve Next Task (If Doubles / Multis Should Retrieve Same Task Within same zone )
         -- Split Task If There is remaining Task, and the next task shall be the split Task.
         -- Split Task If There is Remaining QTY after Close Tote (Start)  --
         SET @cTaskDetailKeyPK = ''
         SET @cCloseTote = ''

         IF ( (@nFromScn = @nScnFromLoc OR @nFromScn = @nScnSKU) AND @nScanQTY=0 )
         BEGIN
            SET @cCloseTote = '1'  -- (ChewKP02)
            GOTO WCS_Routing_Process
         END

         INSERT INTO TraceInfo (TraceName , TimeIN, Step1 , Step2 , Step3 , Step4 ,Step5 , Col1, Col2, col3, Col4 , col5  )
         VALUES ( 'TotePK', GETDATE() , @nFromScn , @nScnFromLoc , @nFromScn ,@nScnSKU , @cTaskDetailKey , @nScanQTY, @cLoadKEy, @cSKU, @cFromLoc, @cTotENo )

         IF @nSuggQTY <> @nScanQTY
         BEGIN
            SET @nRemainQty =  @nSuggQTY -  @nScanQTY


               EXECUTE dbo.nspg_getkey
               'TaskDetailKey'
               , 10
               , @cTaskDetailKeyPK OUTPUT
               , @b_success OUTPUT
               , @nErrNo OUTPUT
               , @cErrMsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SET @nErrNo = @nErrNo
                  SET @cErrMsg = @cErrMsg
                  GOTO Quit
               END

               BEGIN TRAN

               INSERT INTO dbo.TaskDetail
                 (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
                 ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
                 ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
                 ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty)
                  SELECT @cTaskDetailKeyPK,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,@nRemainQty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
                 ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
                 ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
                 ,Message01,'PREVFULL',Message03,@cTaskDetailKey,LoadKey,AreaKey, DropID, @nRemainQty
                  FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE Taskdetailkey = @cTaskDetailKey
                  AND Storerkey = @cTaskStorer

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90035
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTaskFailed'
                  ROLLBACK TRAN
                  GOTO Step_4_Fail
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END

         END
         -- Split Task If There is Remaining QTY after Close Tote (End)  --

         SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)  
         IF @cConfirmSP = '0'  
            SET @cConfirmSP = ''  
         
         IF @cConfirmSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')  
            BEGIN  
                 
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +  
                  '   @nMobile  , @nFunc    , @cStorerKey, @cUserName, @cFacility  , @cTaskDetailKey , @cLoadKey, @cSKU '+
                  ' , @cAltSKU  , @cLOC     , @cToLOC    , @cID      , @cToteNo    , @nPickQty       , @cStatus '+        
                  ' , @cLangCode, @nTotalQty, @nErrNo    , @cErrMsg  , @cPickMethod, @cNTaskDetailkey  '
               SET @cSQLParam =  
                  '   @nMobile          INT                    '+      
                  ' , @nFunc            INT                    '+
                  ' , @cStorerKey       NVARCHAR(15)           '+
                  ' , @cUserName        NVARCHAR(15)           '+
                  ' , @cFacility        NVARCHAR(5)            '+
                  ' , @cTaskDetailKey   NVARCHAR(10)           '+
                  ' , @cLoadKey         NVARCHAR(10)           '+
                  ' , @cSKU             NVARCHAR(20)           '+
                  ' , @cAltSKU          NVARCHAR(20)           '+
                  ' , @cLOC             NVARCHAR(10)           '+
                  ' , @cToLOC           NVARCHAR(10)           '+
                  ' , @cID              NVARCHAR(18)           '+
                  ' , @cToteNo          NVARCHAR(18)           '+
                  ' , @nPickQty         INT                    '+
                  ' , @cStatus          NVARCHAR(1)            '+
                  ' , @cLangCode        NVARCHAR(3)            '+
                  ' , @nTotalQty        INT                    '+
                  ' , @nErrNo           INT          OUTPUT    '+
                  ' , @cErrMsg          NVARCHAR(20) OUTPUT    '+
                  ' , @cPickMethod      NVARCHAR(10)           '+
                  ' , @cNTaskDetailkey  NVARCHAR(10)           '
        
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile,     @nFunc, @cTaskStorer,  @cUserName,  @cFacility,      @cTaskDetailKey,
                  @cLoadKey,    @cSKU,  '',            @cFromLoc,   '',              '',               @cToteNo,
                  @nScanQty,    '5',    @cLangCode,    @nSuggQTY,   @nErrNo OUTPUT,  @cErrMsg OUTPUT,  @cPickMethod, @cTaskDetailKeyPK         
        
            END  
         END            
         ELSE
         BEGIN
            
            EXECUTE RDT.rdt_TM_TotePick_ConfirmTask
               @nMobile,
               @nFunc,
               @cTaskStorer,
               @cUserName,
               @cFacility,
               @cTaskDetailKey,
               @cLoadKey,
               @cSKU,
               '',
               @cFromLoc,
               '', --@cToLoc,
               '',
               @cToteNo,
               @nScanQTY,
               '5',
               @cLangCode,
               @nSuggQTY,
               @nErrNo OUTPUT,
               @cErrMsg OUTPUT,
               @cPickMethod ,
               @cTaskDetailKeyPK
               
         END

         BEGIN TRAN BT_001
         -- INSERT INTO DropID and DropID Detail Table (Start) --
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @cToteNo )
         BEGIN
            INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )
            VALUES (@cToteNo , '' , @cPickMethod, '5' , @cLoadkey, @cPickSlipNo)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90042
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'
               ROLLBACK TRAN BT_001
               GOTO Step_4_Fail
            END
         END
         ELSE
         BEGIN
            UPDATE DROPID WITH (ROWLOCK)
               SET [Status]='5'
             WHERE DROPID  = @cToteNo
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DROPID = @cToteNo AND ChildID = @cSKU)
         BEGIN
            INSERT INTO DROPIDDETAIL ( DropID, ChildID)
            VALUES (@cToteNo, @cSKU )

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90043
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'
               ROLLBACK TRAN BT_001
               GOTO Step_4_Fail
            END
         END

         --INSERT INTO DropID and DropID Detail Table (End) --

         -- Confirm Task
         UPDATE dbo.TaskDetail WITH (ROWLOCK)
             SET Status = '9' ,
             Qty = @nScanQty,
             EndTime = GETDATE(),
             EditDate = GETDATE(),
             EditWho = @cUserName,
             TrafficCop = NULL
         WHERE TaskDetailKey = @cTaskDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nScanQTY = 0
            SET @nErrNo = 90032
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'
            ROLLBACK TRAN BT_001
            GOTO Step_4_Fail
         END
         -- Cannot place this statement before @@ERROR Check..
         -- Reset Scan QTY
         SET @nScanQTY = 0

         DECLARE curDropID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT TaskDetailkey
           FROM dbo.TaskDetail TD WITH (NOLOCK)
           INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
           WHERE TD.Wavekey = @cWavekey
           AND TD.PickMethod = @cPickMethod
           AND TD.Status < '9'
           AND TD.UserKey = @cUserName
           AND (TD.DropID = @cToteNo OR TD.ListKey = @cToteNo)-- SOS# 323841

         OPEN curDropID
         FETCH NEXT FROM curDropID INTO @c_RTaskDetailkey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET Message02 = 'PREVFULL',
                   Trafficcop = NULL,
                   DropID = ''  -- Tote Close, should set the dropid to blank (shong02)
                 , ListKey = '' -- SOS# 323841
            WHERE TaskDetailkey = @c_RTaskDetailkey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90048
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN BT_001
               GOTO Step_4_Fail
            END

            FETCH NEXT FROM curDropID INTO @c_RTaskDetailkey
         END
         CLOSE curDropID
         DEALLOCATE curDropID

         COMMIT TRAN BT_001

         WCS_Routing_Process:
         IF @cCloseTote = '1' AND @cTTMTasktype = 'PK'
         BEGIN
--         IF CAST(@cToteNo AS INT) > 0
--         BEGIN
--            EXEC [dbo].[ispWCSRO01]
--              @c_StorerKey     = @cTaskStorer
--            , @c_Facility      = @cFacility
--            , @c_ToteNo        = @cToteNo
--            , @c_TaskType      = 'SPK'
--            , @c_ActionFlag    = 'F' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
--            , @c_TaskDetailKey = ''-- @cTaskdetailkey
--            , @c_Username      = @cUserName
--            , @c_RefNo01       = @cLoadKey
--            , @c_RefNo02       = ''
--            , @c_RefNo03       = ''
--            , @c_RefNo04       = ''
--            , @c_RefNo05       = ''
--            , @b_debug         = '0'
--            , @c_LangCode      = 'ENG'
--            , @n_Func          = 0
--            , @b_Success       = @b_success OUTPUT
--            , @n_ErrNo         = @nErrNo    OUTPUT
--            , @c_ErrMsg        = @cErrMSG   OUTPUT
--
--          IF @nErrNo <> 0
--          BEGIN
--             SET @nErrNo = @nErrNo
--             SET @cErrMsg = @cErrMsg
--             GOTO Step_4_Fail
--          END
--         END

           DECLARE curDropID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              SELECT TaskDetailkey
              FROM dbo.TaskDetail TD WITH (NOLOCK)
              INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
              WHERE TD.Wavekey = @cWavekey
              AND TD.PickMethod = @cPickMethod
              AND TD.Status < '9'
              AND TD.UserKey = @cUserName
              AND (TD.DropID = @cToteNo OR TD.ListKey = @cToteNo)-- SOS# 323841

            OPEN curDropID
            FETCH NEXT FROM curDropID INTO @c_RTaskDetailkey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE dbo.TaskDetail WITH (ROWLOCK)
                  SET Message02 = 'PREVFULL',
                      Trafficcop = NULL,
                      DropID = ''  -- Tote Close, should set the dropid to blank (shong02)
                    , ListKey = '' -- SOS# 323841
               WHERE TaskDetailkey = @c_RTaskDetailkey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90098
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  ROLLBACK TRAN BT_001
                  GOTO Step_4_Fail
               END

               FETCH NEXT FROM curDropID INTO @c_RTaskDetailkey
            END
            CLOSE curDropID
            DEALLOCATE curDropID

          INSERT INTO TraceInfo (TraceName , TimeIN, Step1 , Step2 , Step3 , Step4 ,Step5 , Col1, Col2, col3, Col4 , col5  )
          VALUES ( 'TotePK', GETDATE() , @cTTMTasktype , @cLoadKey , @cPickMethod ,@cOrderKey , @cAreaKey , @nScanQTY, @cLoadKEy, @cSKU, @cFromLoc, @cTotENo )

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedWCSSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedWCSSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cType, @cStorerKey, @cReasonCode, @cTaskDetailKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@nInputKey      INT, ' +
               '@cType          NVARCHAR( 10), ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cReasonCode    NVARCHAR( 10), ' +
               '@cTaskDetailKey NVARCHAR( 20), ' +
               '@cDropID        NVARCHAR( 20), ' +
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
              
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, 'C', @cStorerKey, @cReasonCode, @cTaskDetailKey, @cToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
              
            IF @nErrNo <> 0 
               GOTO Step_4_Fail
         END
         ELSE
         BEGIN
            EXEC [dbo].[ispWCSRO01]
                 @c_StorerKey     = @cTaskStorer
               , @c_Facility      = @cFacility
               , @c_ToteNo        = @cToteNo
               , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
               , @c_ActionFlag    = 'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
               , @c_TaskDetailKey = ''
               , @c_Username      = @cUserName
               , @c_RefNo01       = @cLoadKey
               , @c_RefNo02       = @cPickMethod -- (ChewKP02)
               , @c_RefNo03       = @cOrderKey -- (ChewKP02)
               , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
               , @c_RefNo05       = ''
               , @b_debug         = '0'
               , @c_LangCode      = 'ENG'
               , @n_Func          = 0
               , @b_Success       = @b_success OUTPUT
               , @n_ErrNo         = @nErrNo    OUTPUT
               , @c_ErrMsg        = @cErrMSG   OUTPUT

            IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                        INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
                        WHERE O.LoadKey = @cLoadKey
                        AND PD.Status <> '5'
                        AND PD.StorerKey = @cTaskStorer
                        AND PD.DropID = @cToteNo )
            BEGIN
                  EXEC [dbo].[ispWCSRO01]
                     @c_StorerKey     = @cTaskStorer
                  , @c_Facility      = @cFacility
                  , @c_ToteNo        = @cToteNo
                  , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
                  , @c_ActionFlag    = 'S' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
                  , @c_TaskDetailKey = '' -- @cTaskdetailkey
                  , @c_Username      = @cUserName
                  , @c_RefNo01       = @cLoadKey
                  , @c_RefNo02       = @cPickMethod -- (ChewKP02)
                  , @c_RefNo03       = @cOrderKey -- (ChewKP02)
                  , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
                  , @c_RefNo05       = @cCloseTote -- (ChewKP02)
                  , @b_debug         = '0'
                  , @c_LangCode      = 'ENG'
                  , @n_Func          = 0
                  , @b_Success       = @b_success OUTPUT
               , @n_ErrNo         = @nErrNo    OUTPUT
                  , @c_ErrMsg        = @cErrMSG   OUTPUT
            END

            EXEC [dbo].[ispWCSRO01]
                     @c_StorerKey     = @cTaskStorer
                  , @c_Facility      = @cFacility
                  , @c_ToteNo        = @cToteNo
                  , @c_TaskType      = @cTTMTasktype -- 'SPK' -- (ChewKP02)
                  , @c_ActionFlag    = 'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
                  , @c_TaskDetailKey = '' -- @cTaskdetailkey
                  , @c_Username      = @cUserName
                  , @c_RefNo01       = @cLoadKey
                  , @c_RefNo02       = @cPickMethod -- (ChewKP02)
                  , @c_RefNo03       = @cOrderKey -- (ChewKP02)
                  , @c_RefNo04       = @cAreaKey  -- (ChewKP02)
                  , @c_RefNo05       = @cCloseTote -- (ChewKP02)
                  , @b_debug         = '0'
                  , @c_LangCode      = 'ENG'
                  , @n_Func          = 0
                  , @b_Success       = @b_success OUTPUT
                  , @n_ErrNo         = @nErrNo    OUTPUT
                  , @c_ErrMsg        = @cErrMSG   OUTPUT
            END
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedWCSSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedWCSSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cType, @cStorerKey, @cReasonCode, @cTaskDetailKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT, ' +
                  '@nInputKey      INT, ' +
                  '@cType          NVARCHAR( 10), ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cReasonCode    NVARCHAR( 10), ' +
                  '@cTaskDetailKey NVARCHAR( 20), ' +
                  '@cDropID        NVARCHAR( 20), ' +
                  '@nErrNo         INT           OUTPUT, ' + 
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
              
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, 'C', @cStorerKey, @cReasonCode, @cTaskDetailKey, @cToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
              
               IF @nErrNo <> 0 
                  GOTO Step_4_Fail
            END
         END
         
         BEGIN TRAN

         -- Close Tote, Set DropID status to 5
         UPDATE DropID
         SET [Status] = '5'
         WHERE Dropid   = @cToteNo
         AND   [Status] ='0'
         AND   Loadkey  = CASE WHEN ISNULL(RTRIM(@cLoadkey), '') <> '' THEN @cLoadkey ELSE DropID.LoadKey END

         UPDATE dbo.WCSRouting WITH (ROWLOCK)
         SET Status = '5'
         WHERE ToteNo = @cToteNo
         AND Final_Zone = @cFinalPutawayzone

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 90052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'
            ROLLBACK TRAN
            GOTO Step_4_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END

         IF @cPickMethod = 'SINGLES'
         BEGIN
            -- Release Previous Task
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                        WHERE UserKey = @cUserName
                        AND   STATUS = '3' )
            BEGIN
             Update dbo.TaskDetail WITH (ROWLOCK)
                SET DropID = '',
                    EndTime = GETDATE(),
                    EditDate = GETDATE(),
                    EditWho  = @cUserName,
                    UserKey = '',
                    [STATUS]  = '0',
                    Trafficcop = NULL
             WHERE UserKey = @cUserName
             AND   STATUS = '3'
             IF @@ERROR <> 0
             BEGIN
                SET @nErrNo = 90032
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'
                ROLLBACK TRAN BT_001
                GOTO Step_4_Fail
             END
          END
         END

         EXEC RDT.rdt_STD_EventLog
                     @cActionType = '3', 
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cStorerKey,
                     @cDropID     = @cToteNo,
                     @cPickMethod = @cPickMethod,
                     @cLocation   = @cFromLoc,
                     @cSKU        = @cSKU,
                     @cUOM        = @cUOM,
                     @nExpectedQty = @nSuggQty,
                     @cTaskType   = @cTTMTasktype,
                     @cOption     = @cSHTOption,
                     @nStep       = @nStep
                     
         SET @cUserPosition = '1'

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         SET @cOutField02 = @cTTMTasktype
       END -- Option =9

   END -- IF @nInputKey = 1

   IF @nInputKey = 0    --ESC
   BEGIN
      IF @nFromStep = @nStepFromLoc
      BEGIN
         SET @cOutField02 = @cLoc
         SET @cOutField01 = @cPickMethod
         SET @cOutField02 = @cToteNo
         SET @cOutField03 = @cSuggFromLoc
         SET @cOutField04 = ''
         SET @cOutField05 = @cTTMTasktype

         SET @nScn  = @nScnFromLoc
         SET @nStep = @nStepFromLoc

         GOTO QUIT
      END

      SET @cOutField01 = @cToteNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cDescr1
      SET @cOutField04 = @cDescr2
      SET @cOutField05 = ''
      SET @cOutField06 = @cUOM
      SET @cOutField07 = @nScanQty
      SET @cOutField08 = @nSuggQTY
      SET @cOutField09 = @cFromLoc
      SET @cOutField10 = @cTTMTasktype

      IF @cUserPosition = ''
      BEGIN
         SET @cUserPosition = '1'
      END

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
       SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 2434 Close Tote
     Success Message    ENTER = Next Task
     ESC  = Exit TM
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --OR @nInputKey = 0 -- ENTER / ESC
   BEGIN
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
      SET @cUserPosition = '1'

      EXEC RDT.rdt_STD_EventLog               
           @cActionType = '9', -- Sign Out function
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerKey,
           @cDropID     = @cToteNo,
           @cPickMethod = @cPickMethod,
           @cLocation   = @cFromLoc,
           @cSKU        = @cSKU,
           @cUOM        = @cUOM,
           @nExpectedQty = @nSuggQty,
           @cTaskType   = @cTTMTasktype,
           @cOption     = @cSHTOption,
           @nStep       = @nStep


      IF @cTaskDetailKeyPK <> '' AND
         @cPickMethod NOT IN ('SINGLES') -- Continue Pick the Remaining Qty
      BEGIN
         SELECT @cRefKey03 = DropID ,
                @cRefkey04 = PickMethod
         From dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailkey = @cTaskDetailKeyPK

         SET @cTaskdetailkey = @cTaskDetailKeyPK
         SET @cOutField01 = @cRefKey01
         SET @cOutField02 = @cRefKey02
         SET @cOutField03 = @cRefKey03
         SET @cOutField04 = @cRefKey04
         SET @cOutField05 = @cRefKey05
         SET @cOutField06 = @cTaskdetailkey
         SET @cOutField07 = @cAreaKey
         SET @cOutField08 = @cTTMStrategykey
         SET @cOutField09 = @cTTMTasktype

         SET @nPrevStep = '0'

         SET @cOutField05 = ''

         SET @nFunc = @nFunc

         SET @nScn  = @nScnEmptyTote
         SET @nStep = @nStepEmptyTote

         SET @cTaskDetailKeyPK = ''

       
         GOTO QUIT
      END

      -- Continue Pick the Remaining Qty after close tote
      IF @cPickMethod IN ('MULTIS','DOUBLES','PIECE','PP','STOTE')
      BEGIN
           
         SET @cTaskDetailkey=''

         SELECT TOP 1
                @cTaskdetailkey = TD.TaskDetailKey,
                @cRefKey03 = TD.DropID,
                @cRefkey04 = TD.PickMethod
         FROM dbo.TaskDetail TD WITH (NOLOCK)
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = TD.FromLoc
         WHERE TD.UserKey = @cUserName
            AND TD.Status = '3'
            AND TD.DropID = CASE WHEN Message02 = 'PREVFULL' THEN DropID ELSE @cToteNo END
            AND TD.AreaKey = @cAreaKey -- (ChewKP02)
         ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc   

         IF @@ROWCOUNT = 0
            SELECT TOP 1
                   @cTaskdetailkey = TD.TaskDetailKey,
                   @cRefKey03 = TD.DropID,
                   @cRefkey04 = TD.PickMethod
            FROM dbo.TaskDetail TD WITH (NOLOCK)
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = TD.FromLoc
            WHERE TD.UserKey = @cUserName
               AND TD.Status = '3'
               AND TD.DropID = CASE WHEN Message02 = 'PREVFULL' THEN DropID ELSE @cToteNo END
            ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc   
         
         SET @cOutField01 = @cRefKey01
         SET @cOutField02 = @cRefKey02
         SET @cOutField03 = @cRefKey03
         SET @cOutField04 = @cRefKey04
         SET @cOutField05 = @cRefKey05
         SET @cOutField06 = @cTaskdetailkey
         SET @cOutField07 = @cAreaKey
         SET @cOutField08 = @cTTMStrategykey
         SET @cOutField09 = @cTTMTasktype

         SET @cToteNo = ''

         SET @nPrevStep = '0'

         SET @cOutField05 = ''

         SET @nFunc = @nFunc

         SET @nScn  = @nScnEmptyTote
         SET @nStep = @nStepEmptyTote

         SET @cTaskDetailKeyPK = ''
         GOTO QUIT
      END

      IF @cPickMethod IN ('SINGLES')
      BEGIN
         -- GETNEXTTASK:
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
             ,  @c_areakey05    = ''
             ,  @c_lastloc       = @cSuggToLoc
             ,  @c_lasttasktype  = 'SPK'
             ,  @c_outstring     = @c_outstring    OUTPUT
             ,  @b_Success       = @b_Success      OUTPUT
             ,  @n_err           = @nErrNo         OUTPUT
             ,  @c_errmsg        = @cErrMsg        OUTPUT
             ,  @c_taskdetailkey = @cNextTaskDetailKey OUTPUT
             ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
             ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
             ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
             ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
             ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
             ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func


             IF ISNULL(RTRIM(@cNextTaskDetailKey), '') = '' --@nErrNo = 67804 -- Nothing to do!
             BEGIN
                 -- EventLog - Sign Out Function
                 EXEC RDT.rdt_STD_EventLog
                     @cActionType = '9', -- Sign Out function
                     @cUserID     = @cUserName,
                     @nMobileNo   = @nMobile,
                     @nFunctionID = @nFunc,
                     @cFacility   = @cFacility,
                     @cStorerKey  = @cTaskStorer,
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
                 SET @cOutField09 = ''

                 -- EventLog - Sign Out Function
                 EXEC RDT.rdt_STD_EventLog
                   @cActionType = '9', -- Sign Out function
                   @cUserID     = @cUserName,
                   @nMobileNo   = @nMobile,
                   @nFunctionID = @nFunc,
                   @cFacility   = @cFacility,
                   @cStorerKey  = @cTaskStorer,
                   @nStep       = @nStep

                 GOTO QUIT
             END

             IF ISNULL(@cErrMsg, '') <> ''
             BEGIN
               SET @cErrMsg = @cErrMsg
               GOTO Step_5_Fail
             END

            IF ISNULL(@cNextTaskDetailKey, '') <> ''
            BEGIN
               SET @cToteNo = ''
               SELECT @cRefKey03 = CASE WHEN TaskType = 'PA' THEN CaseID ELSE DropID END,
                      @cRefkey04 = PickMethod,
                      @cToteNo  = DropID,
                      @cPickMethod = PickMethod,
                      @cNewToteNo   = DropID,
                      @cTTMTasktype = TaskType
               From dbo.TaskDetail WITH (NOLOCK)
               WHERE TaskDetailkey = @cNextTaskDetailKey

               SET @cTaskdetailkey = @cNextTaskDetailKey

               IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                           WHERE TaskDetailKey = @cTaskdetailkey
                           AND STATUS <> '9' )
               BEGIN
               BEGIN TRAN

                UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                   Starttime = GETDATE(),
                   Editdate = GETDATE(),
                   EditWho = @cUserName,
                   TrafficCOP = NULL
                WHERE TaskDetailKey = @cTaskdetailkey
                AND STATUS <> '9'

                IF @@ERROR <> 0
                BEGIN
                   SET @nErrNo = 70201
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                   ROLLBACK TRAN
                   GOTO Step_5_Fail
                END

                COMMIT TRAN
             END

               SET @cOutField01 = @cRefKey01
               SET @cOutField02 = @cRefKey02
               SET @cOutField03 = @cRefKey03
               SET @cOutField04 = @cRefKey04
               SET @cOutField05 = @cRefKey05
               SET @cOutField06 = @cTaskdetailkey
               SET @cOutField07 = @cAreaKey
               SET @cOutField08 = @cTTMStrategykey
               SET @cOutField09 = @cTTMTasktype

               IF @cTTMTasktype <> 'PK'
               BEGIN
                  SET @nToFunc = 0
                  SET @nToScn = 0
                  SET @nPrevStep = 0

                  SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
                  FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
                  WHERE TaskType = RTRIM(@cTTMTasktype)

                  IF @nFunc = 0
                  BEGIN
                     SET @nErrNo = 70238
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
                     GOTO Step_5_Fail
                  END

                  SELECT TOP 1 @nToScn = Scn
                  FROM RDT.RDTScn WITH (NOLOCK)
                  WHERE Func = @nToFunc
                  ORDER BY Scn

                  IF @nToScn = 0
                  BEGIN
                     SET @nErrNo = 70239
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
                     GOTO Step_5_Fail
                  END

                  SET @nScn = @nToScn
                  SET @nFunc = @nToFunc
                  SET @nStep = 1

                  -- EventLog - Sign Out Function
                  EXEC RDT.rdt_STD_EventLog
                    @cActionType = '9', -- Sign Out function
                    @cUserID     = @cUserName,
                    @nMobileNo   = @nMobile,
                    @nFunctionID = @nFunc,
                    @cFacility   = @cFacility,
                    @cStorerKey  = @cTaskStorer,
                    @nStep       = @nStep

                  GOTO QUIT
               END

               IF (@cPickMethod = 'SINGLES')
               BEGIN
                  SET @nPrevStep = '0'

                  SET @cOutField05 = ''
                  IF ISNULL(@cToteNo,'') <> ''
                  BEGIN
                     UPDATE DBO.TASKDETAIL WITH (ROWLOCK)
                        SET DropID = '', TrafficCop = NULL
                     WHERE TaskDetailkey = @cNextTaskDetailKey

                     SET @cToteNo = ''
                     SET @cNewToteNo = ''

                END
                  SET @nPrevStep = 0
                  SET @nScn = 2107 -- Empty Tote
                  SET @nStep = 11

               END -- (@cPickMethod = 'SINGLES' OR @cPickMethod = 'PIECE')
          ELSE
          BEGIN
                  SET @cNewToteNo = ISNULL(@cNewToteNo,'')
                  IF ISNULL(RTRIM(@cNewToteNo),'') <> ''
                  BEGIN
                     SET @cToteNo  = @cNewToteNo
                     SET @cOutField05 = ''
                     SET @cOutField04 = @cPickMethod
                     SET @cOutField03 = @cToteNo
                   SET @cOutField09 = @cTTMTasktype
                     SET @nScn  = @nScnWithToteNo
                     SET @nStep = @nStepWithToteNo
          END
                  ELSE
                  BEGIN
                     SET @cOutField01 = @cPickMethod
                     SET @cOutField02 = @cToteNo
                     SET @cOutField03 = @cSuggFromLoc
                     SET @cOutField04 = ''
                     SET @cToteNo = ''
                     SET @cNewToteNo = ''

                     -- Got to empty Tote No screen
                     SET @nPrevStep = 0
                     SET @nScn  = @nScnEmptyTote
                     SET @nStep = @nStepEmptyTote
          END
          END
            END -- IF ISNULL(@cNextTaskDetailKey, '') <> ''
           -- EventLog - Sign Out Function
           EXEC RDT.rdt_STD_EventLog
             @cActionType = '9', -- Sign Out function
             @cUserID     = @cUserName,
             @nMobileNo   = @nMobile,
             @nFunctionID = @nFunc,
             @cFacility   = @cFacility,
             @cStorerKey  = @cTaskStorer,
             @nStep       = @nStep
         GOTO QUIT
      END
      ELSE
      BEGIN
         IF @cPickMethod = 'DOUBLES' OR @cPickMethod = 'MULTIS' OR @cPickMethod = 'PIECE' --
         BEGIN
            -- Get the task within the same area; there is probably more than 1 zone per area
            SELECT TOP 1 @cCurrArea = AD.AREAKEY, @cLocAisle = l.LocAisle
            FROM dbo.TaskDetail td WITH (NOLOCK)
            JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc
            JOIN dbo.AREADETAIL AD (NOLOCK) ON l.PUTAWAYZONE = AD.PUTAWAYZONE
            WHERE td.TaskDetailKey = @cTaskdetailkey
               -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first
               AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END

            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                   INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                        INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                        WHERE TD.Wavekey = @cWavekey
                        AND TD.PickMethod = @cPickMethod
                        AND TD.Status = '3'
                        AND TD.TaskDetailkey <> @cTaskDetailkey
                        AND AD.AreaKey = @cCurrArea
                        AND LOC.Facility = @cFacility
                        AND TD.UserKey = @cUserName
                        AND TD.Message02 = 'PREVFULL'
                        AND ISNULL(RTRIM(TD.DropID), '') <> '')
            BEGIN
               -- Get Next TaskKey
               -- Get the task within the same aisle first
               SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Wavekey = @cWavekey
               AND TD.PickMethod = @cPickMethod
               AND TD.Status = '3'
               AND TD.TaskDetailkey <> @cTaskDetailkey
               AND LOC.Putawayzone = @cCurrPutawayzone
               AND LOC.Facility = @cFacility
               AND TD.UserKey = @cUserName
               AND TD.Message02 = 'PREVFULL'
               AND ISNULL(RTRIM(TD.DropID), '') <> ''
               AND LOC.LocAisle = @cLocAisle
               ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
               
               -- IF same aisle no more task, get the task from same putawayzone but within same area
               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  WHERE TD.Wavekey = @cWavekey
                  AND TD.PickMethod = @cPickMethod
                  AND TD.Status = '3'
                  AND TD.TaskDetailkey <> @cTaskDetailkey
                  AND LOC.Putawayzone = @cCurrPutawayzone
                  AND LOC.Facility = @cFacility
                  AND TD.UserKey = @cUserName
                  AND TD.Message02 = 'PREVFULL'
                  AND ISNULL(RTRIM(TD.DropID), '') <> ''
                  ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
               END

               -- IF current putawayzone no more task, get the task from different putawayzone but within same area
               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                  WHERE TD.Wavekey = @cWavekey
                  AND TD.PickMethod = @cPickMethod
                  AND TD.Status = '3'
                  AND TD.TaskDetailkey <> @cTaskDetailkey
                  AND AD.AreaKey = @cCurrArea
                  AND LOC.Facility = @cFacility
                  AND TD.UserKey = @cUserName
                  AND TD.Message02 = 'PREVFULL'
                  AND ISNULL(RTRIM(TD.DropID), '') <> ''
                  ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
               END

               SET @cTaskDetailkey = @cNextTaskDetailKey
               SET @cNextTaskDetailKey = ''

               IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                           WHERE TaskDetailKey = @cTaskdetailkey
                           AND STATUS <> '9' )
               BEGIN
                  BEGIN TRAN
                  UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                     Starttime = GETDATE(),
                     Editdate = GETDATE(),
                     EditWho = @cUserName,
                     TrafficCOP = NULL
                  WHERE TaskDetailKey = @cTaskdetailkey
                  AND STATUS <> '9'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 70202
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                     ROLLBACK TRAN
                     GOTO Step_5_Fail
                  END
                  COMMIT TRAN
               END

               --- GET Variable --
               SET @cNewToteNo = ''
               SELECT TOP 1
                      @cTaskStorer = RTRIM(TD.Storerkey),
                      @cSKU        = RTRIM(TD.SKU),
                      @cSuggID     = RTRIM(TD.FromID),
                      @cSuggToLoc  = RTRIM(TD.ToLOC),
                      @cLot        = RTRIM(TD.Lot),
                      @cSuggFromLoc  = RTRIM(TD.FromLoc),
                      @nSuggQTY    = TD.Qty,
                      @cLoadkey    = RTRIM(LPD.Loadkey),
                      @cPickMethod = RTRIM(TD.PickMethod),
                      @cOrderkey   = RTRIM(PD.Orderkey),
                      @cNewToteNo  = RTRIM(TD.DropID),
                      @cWaveKey    = ISNULL(TD.WaveKey,''),
                      @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
               JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
               WHERE TD.TaskDetailKey = @cTaskdetailkey

               SELECT @cCurrPutawayzone = Putawayzone
               FROM LOC WITH (NOLOCK)
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility

               -- PrePare Var for Next Screen
               -- Reset Scan Qty to 0
               SET @nScanQty = 0
               SET @cUserPosition = '1'
               SET @nPrevStep = 1
               -- Got to empty Tote No screen
               SET @nFunc = @nFunc

               IF ISNULL(RTRIM(@cToteNo),'') <> ISNULL(RTRIM(@cNewToteNo),'')
               BEGIN
                  SET @cToteNo  = @cNewToteNo
                  SET @cOutField05 = ''
                  SET @cOutField04 = @cPickMethod
                  SET @cOutField03 = @cToteNo
                  SET @cOutField09 = @cTTMTasktype
                  SET @nScn  = @nScnWithToteNo
                  SET @nStep = @nStepWithToteNo
               END
               ELSE
               BEGIN
                  SET @cOutField01 = @cPickMethod
                  SET @cOutField02 = @cToteNo
                  SET @cOutField03 = @cSuggFromLoc
                  SET @cOutField04 = ''
                  SET @cOutField05 = @cTTMTasktype

                  SET @nScn = @nScnFromLoc
                  SET @nStep = @nStepFromLoc
               END
               GOTO QUIT
            END
            ELSE
            -- GET RELATED TASK WITHIN SAME ZONE SAME TOTE IN THE SAME ZONE

            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                        INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                        WHERE TD.Wavekey = @cWavekey
                        AND TD.PickMethod = @cPickMethod
                        AND TD.Status = '3'
                        AND TD.TaskDetailkey <> @cTaskDetailkey
                        AND AD.AreaKey = @cCurrArea
                        AND LOC.Facility = @cFacility
                        AND TD.UserKey = @cUserName
                        AND TD.DropID = @cToteNo
                        AND ISNULL(RTRIM(TD.DropID), '') <> '')
            BEGIN
               -- Get Next TaskKey
               SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Wavekey = @cWavekey
                     AND TD.PickMethod = @cPickMethod
                     AND TD.Status = '3'
                     AND TD.TaskDetailkey <> @cTaskDetailkey
                     AND LOC.Putawayzone = @cCurrPutawayzone
                     AND LOC.Facility = @cFacility
                     AND TD.UserKey = @cUserName
                     AND TD.DropID = @cToteNo
                     AND ISNULL(RTRIM(TD.DropID), '') <> ''
               ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
               
               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                  WHERE TD.Wavekey = @cWavekey
                        AND TD.PickMethod = @cPickMethod
                        AND TD.Status = '3'
                        AND TD.TaskDetailkey <> @cTaskDetailkey
                        AND AD.AreaKey = @cCurrArea
                        AND LOC.Facility = @cFacility
                        AND TD.UserKey = @cUserName
                        AND TD.DropID = @cToteNo
                        AND ISNULL(RTRIM(TD.DropID), '') <> ''
                  ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
               END

               SET @cTaskDetailkey = @cNextTaskDetailKey
               SET @cNextTaskDetailKey = ''

            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                        WHERE TaskDetailKey = @cTaskdetailkey
                        AND STATUS <> '9' )
            BEGIN
                BEGIN TRAN

                UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                   Starttime = GETDATE(),
                   Editdate = GETDATE(),
                   EditWho = @cUserName,
                   TrafficCOP = NULL
                WHERE TaskDetailKey = @cTaskdetailkey
                AND STATUS <> '9'

                IF @@ERROR <> 0
                BEGIN
                   SET @nErrNo = 70203
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                   ROLLBACK TRAN
                   GOTO Step_5_Fail
              END

               COMMIT TRAN
            END
               --- GET Variable --
               SELECT TOP 1
                      @cTaskStorer = RTRIM(TD.Storerkey),
                      @cSKU        = RTRIM(TD.SKU),
                      @cSuggID     = RTRIM(TD.FromID),
                      @cSuggToLoc  = RTRIM(TD.ToLOC),
                      @cLot        = RTRIM(TD.Lot),
                      @cSuggFromLoc  = RTRIM(TD.FromLoc),
                      @nSuggQTY    = TD.Qty,
                      @cLoadkey    = RTRIM(LPD.Loadkey),
                      @cPickMethod = RTRIM(TD.PickMethod),
                      @cOrderkey   = RTRIM(PD.Orderkey),
                      @cWaveKey    = ISNULL(TD.WaveKey,''),
                      @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
               JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
               WHERE TD.TaskDetailKey = @cTaskdetailkey


               SELECT @cCurrPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility


               -- PrePare Var for Next Screen
               -- Reset Scan Qty to 0

               SET @nScanQty = 0

               SET @cUserPosition = '1'

               SET @nPrevStep = 1

               SET @cOutField01 = @cPickMethod
               SET @cOutField02 = @cToteNo
               SET @cOutField03 = @cSuggFromLoc
               SET @cOutField04 = ''
               SET @cOutField05 = @cTTMTasktype

               -- There is still Task in Same Zone GOTO Screen 2
               SET @nScn = @nScnFromLoc
               SET @nStep = @nStepFromLoc
               GOTO QUIT

            END  -- if Task Found for Same Tote#
            ELSE -- GET RELATED TASK WITHIN SAME ZONE TO CONTINUE PICKING TO SAME TOTE
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                                 INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                                 INNER JOIN AREADETAIL AD WITH (NOLOCK) ON AD.PUTAWAYZONE = LOC.PUTAWAYZONE
                        WHERE TD.Wavekey = @cWavekey
                        AND TD.PickMethod = @cPickMethod
                        AND TD.Status = '3'
                        AND TD.TaskDetailkey <> @cTaskDetailkey
                        AND AD.AreaKey = @cCurrArea
                        AND LOC.Facility = @cFacility
                        AND TD.UserKey = @cUserName
                        AND TD.DropID = '' )

            BEGIN
               -- Get Next TaskKey
               SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Wavekey = @cWavekey
               AND TD.PickMethod = @cPickMethod
               AND TD.Status = '3'
               AND TD.TaskDetailkey <> @cTaskDetailkey
               AND LOC.Putawayzone = @cCurrPutawayzone
               AND LOC.Facility = @cFacility
               AND TD.UserKey = @cUserName
               AND TD.DropID = ''
               ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc

               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  INNER JOIN AREADETAIL AD WITH (NOLOCK) ON AD.PUTAWAYZONE = LOC.PUTAWAYZONE
                  WHERE TD.Wavekey = @cWavekey
                  AND TD.PickMethod = @cPickMethod
                  AND TD.Status = '3'
                  AND TD.TaskDetailkey <> @cTaskDetailkey
                  AND AD.AreaKey = @cCurrArea
                  AND LOC.Facility = @cFacility
                  AND TD.UserKey = @cUserName
                  AND TD.DropID = ''
                  ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
               END

               SET @cTaskDetailkey = @cNextTaskDetailKey
               SET @cNextTaskDetailKey = ''

               IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                        WHERE TaskDetailKey = @cTaskdetailkey
                        AND STATUS <> '9' )
               BEGIN
                  BEGIN TRAN

                  UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                     Starttime = GETDATE(),
                     Editdate = GETDATE(),
                     EditWho = @cUserName,
                     TrafficCOP = NULL
                  WHERE TaskDetailKey = @cTaskdetailkey
                  AND STATUS <> '9'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 70204
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                     ROLLBACK TRAN
                     GOTO Step_5_Fail
                  END

                  COMMIT TRAN
               END

               --- GET Variable --
               SELECT TOP 1
                @cTaskStorer = RTRIM(TD.Storerkey),
                @cSKU        = RTRIM(TD.SKU),
                @cSuggID     = RTRIM(TD.FromID),
                @cSuggToLoc  = RTRIM(TD.ToLOC),
                @cLot        = RTRIM(TD.Lot),
                @cSuggFromLoc  = RTRIM(TD.FromLoc),
                @nSuggQTY    = TD.Qty,
                @cLoadkey    = RTRIM(LPD.Loadkey),
                @cOrderkey   = RTRIM(PD.Orderkey),
                @cWaveKey    = ISNULL(TD.WaveKey,''),
                @cToteNo    = ISNULL(RTRIM(TD.DropId),''),
                @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
               JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
               WHERE TD.TaskDetailKey = @cTaskdetailkey

               SELECT @cCurrPutawayzone = Putawayzone
               FROM LOC WITH (NOLOCK)
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility


               -- PrePare Var for Next Screen
               -- Reset Scan Qty to 0

               SET @nScanQty = 0
               SET @cUserPosition = '1'
               SET @nPrevStep = 1
               SET @cOutField01 = @cPickMethod
               SET @cOutField02 = @cToteNo
              SET @cOutField03 = @cSuggFromLoc
               SET @cOutField04 = ''
               SET @cOutField05 = @cTTMTasktype

               -- Have to update tote# that selected
               UPDATE DBO.TASKDETAIL WITH (ROWLOCK)
                 SET DropID = @cToteNo, TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskdetailkey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90065
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  ROLLBACK TRAN
                  GOTO Step_5_Fail
               END

               -- There is still Task in Same Zone GOTO Screen 2
               --SET @nScn  = @nScnFromLoc
               --SET @nStep = @nStepFromLoc
               SET @nScn = @nScnEmptyTote
               SET @nStep = @nStepEmptyTote

--               -- EventLog - Sign Out Function
--               EXEC RDT.rdt_STD_EventLog
--                 @cActionType = '9', -- Sign Out function
--                 @cUserID     = @cUserName,
--                 @nMobileNo   = @nMobile,
--                 @nFunctionID = @nFunc,
--                 @cFacility   = @cFacility,
--                 @cStorerKey  = @cTaskStorer

               GOTO QUIT

            END
            ELSE
            BEGIN
               -- No More Task in Same Zone
               -- Update LOCKED Task to Status = '0' and Userkey = '' For PickUp by Next Zone

               BEGIN TRAN

               DECLARE CursorReleaseTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Loadkey  = @cLoadkey
               AND TD.PickMethod = @cPickMethod
               AND TD.Status = '3' -- (vicky03x)
               AND TD.TaskDetailkey <> @cTaskDetailkey
               AND TD.UserKey = @cUserName
               AND LOC.Putawayzone = @cCurrPutawayzone

               OPEN CursorReleaseTask
               FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  UPDATE dbo.TaskDetail WITH (ROWLOCK)
                  SET Status = '0', UserKey = '' , TrafficCop = NULL -- (Vicky0)
                  WHERE TaskDetailkey = @c_RTaskDetailkey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 90065
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                     ROLLBACK TRAN
                     GOTO Step_5_Fail
                  END

                  FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey
               END
               CLOSE CursorReleaseTask
               DEALLOCATE CursorReleaseTask

               COMMIT TRAN

               -- Reset Scan Qty to 0
               SET @nScanQty = 0

               IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                           WHERE Loadkey = @cLoadkey
                           AND PickMethod = @cPickMethod
                           AND DropID = @cToteNo
                           AND Status IN ('0','3')
                           AND TaskDetailkey <> @cTaskDetailkey
                           )
            BEGIN
                  -- Go to Order Fulli by Other Zone Screen
                  SET @nScn = @nScn + 1
                  SET @nStep = @nStep + 1
                  SET @cOutField01 = @cTTMTasktype
                  GOTO QUIT
               END
               ELSE
               BEGIN
                  -- Go to Tote Close Screen -- 3887
                  SET @nScn = @nScn + 3
                  SET @nStep = @nStep + 3
                  SET @cOutField01 = CASE WHEN ISNULL(@cToteNo, '') = '' THEN 'Tote is Closed'
                                          ELSE RTRIM(@cToteNo) + ' is Closed' END
                  SET @cOutField02 = @cTTMTasktype
                  GOTO QUIT
               END
            END
         END
      END
   END

   IF @nInputKey = 0    --ESC
   BEGIN
   IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                     WHERE Userkey = @cUserName
                     AND Status = '3'  )
      BEGIN
       BEGIN TRAN
       -- Release ALL Task from Users when EXIT TM --
       UPDATE dbo.TaskDetail WITH (ROWLOCK)
          SET Status = '0' , Userkey = '', DropID = '', Message02 = ''  -- should also update DropID for Close Tote
             ,ListKey = '' -- SOS# 323841
             ,TrafficCop = NULL
             ,EditDate = GETDATE()
             ,EditWho = SUSER_SNAME()
       WHERE Userkey = @cUserName
       AND Status = '3'

       IF @@ERROR <> 0
       BEGIN
             SET @nErrNo = 90060
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
             ROLLBACK TRAN
             GOTO Step_5_Fail
       END
       ELSE
       BEGIN
          COMMIT TRAN
       END
      END


      IF @cUserPosition = ''
      BEGIN
         SET @cUserPosition = '1'
      END

      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
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
     SET @nPrevStep = '0'

     SET @cOutField01 = ''  -- Area
     SET @cOutField02 = ''
     SET @cOutField03 = ''
     SET @cOutField04 = ''
     SET @cOutField05 = ''
     SET @cOutField06 = ''
     SET @cOutField07 = ''
     SET @cOutField08 = ''
     SET @cOutField09 = ''
   END
   GOTO Quit

   Step_5_Fail:
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
Step 6. screen = 3885
     MSG (Picking need to be done from other Zone)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 --OR @nInputKey = 0 -- ENTER / ESC
   BEGIN
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
      
      EXEC RDT.rdt_STD_EventLog               
           @cActionType = '3', 
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerKey,
           @cDropID     = @cToteNo,
           @cPickMethod = @cPickMethod,
           @cLocation   = @cFromLoc,
           @cSKU        = @cSKU,
           @cUOM        = @cUOM,
           @nExpectedQty = @nSuggQty,
           @cTaskType   = @cTTMTasktype,
           @cOption     = @cSHTOption,
           @nStep       = @nStep

      SET @cUserPosition = '1'

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
       ,  @c_lastloc       = @cSuggToLoc
       ,  @c_lasttasktype  = 'SPK' -- (Vicky02)
       ,  @c_outstring     = @c_outstring    OUTPUT
       ,  @b_Success       = @b_Success      OUTPUT
       ,  @n_err           = @nErrNo         OUTPUT
       ,  @c_errmsg        = @cErrMsg        OUTPUT
       ,  @c_taskdetailkey = @cNextTaskDetailKey OUTPUT
       ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
       ,  @c_RefKey01      = @cRefKey01   OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

       IF ISNULL(RTRIM(@cNextTaskDetailKey), '') = '' --@nErrNo = 67804 -- Nothing to do!
       BEGIN
          -- EventLog - Sign Out Function
--          EXEC RDT.rdt_STD_EventLog
--          @cActionType = '9', -- Sign Out function
--          @cUserID     = @cUserName,
--          @nMobileNo   = @nMobile,
--          @nFunctionID = @nFunc,
--          @cFacility   = @cFacility,
--          @cStorerKey  = @cStorerKey

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
          SET @cOutField09 = ''

          -- EventLog - Sign Out Function
--          EXEC RDT.rdt_STD_EventLog
--             @cActionType = '9', -- Sign Out function
--             @cUserID     = @cUserName,
--             @nMobileNo   = @nMobile,
--             @nFunctionID = @nFunc,
--             @cFacility   = @cFacility,
--             @cStorerKey  = @cTaskStorer

          GOTO QUIT
       END

       IF ISNULL(@cErrMsg, '') <> ''
       BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_6_Fail
       END

      IF ISNULL(@cNextTaskDetailKey, '') <> ''
      BEGIN
         SET @cRefKey03 = ''
         SET @cRefkey04 = ''

         SELECT @cRefKey03 = CASE WHEN TaskType = 'PA' THEN CaseID ELSE DropID END,
                @cRefkey04 = PickMethod,
                @cPickMethod = PickMethod,
                @cTTMTasktype = TaskType
         From dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailkey = @cNextTaskDetailKey

         IF @cRefKey03 = ''
         BEGIN
            SELECT @cRefKey03 = ListKey
            From dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailkey = @cNextTaskDetailKey
         END

         SET @cTaskdetailkey = @cNextTaskDetailKey
         SET @cOutField01 = @cRefKey01
         SET @cOutField02 = @cRefKey02
         SET @cOutField03 = @cRefKey03
         SET @cOutField04 = @cRefKey04
         SET @cOutField05 = @cRefKey05
         SET @cOutField06 = @cTaskdetailkey
         SET @cOutField07 = @cAreaKey
         SET @cOutField08 = @cTTMStrategykey
         SET @cOutField09 = @cTTMTasktype
         SET @nPrevStep = '0'

         SET @cOutField05 = ''
      END

      IF @cTTMTasktype <> 'PK'
      BEGIN
         SET @nToFunc = 0
         SET @nToScn = 0
       SET @nPrevStep = 0

         SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
         FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
         WHERE TaskType = RTRIM(@cTTMTasktype)

         IF @nFunc = 0
         BEGIN
            SET @nErrNo = 70238
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
            GOTO Step_6_Fail
         END

         SELECT TOP 1 @nToScn = Scn
         FROM RDT.RDTScn WITH (NOLOCK)
         WHERE Func = @nToFunc
         ORDER BY Scn

         IF @nToScn = 0
         BEGIN
            SET @nErrNo = 70239
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
            GOTO Step_6_Fail
         END

         SET @nScn = @nToScn
         SET @nFunc = @nToFunc
         SET @nStep = 1

         -- EventLog - Sign Out Function
--         EXEC RDT.rdt_STD_EventLog
--           @cActionType = '9', -- Sign Out function
--           @cUserID     = @cUserName,
--           @nMobileNo   = @nMobile,
--           @nFunctionID = @nFunc,
--           @cFacility   = @cFacility,
--           @cStorerKey  = @cTaskStorer

         GOTO QUIT
      END

      IF (@cRefkey04 = 'SINGLES' ) -- Get Next Task
      BEGIN
         SET @nToFunc = 0
         SET @nToScn = 0

         SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
         FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
         WHERE TaskType = RTRIM(@cTTMTasktype)

         IF @nFunc = 0
         BEGIN
            SET @nErrNo = 70222
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
            GOTO Step_6_Fail
         END

         SELECT TOP 1 @nToScn = Scn
         FROM RDT.RDTScn WITH (NOLOCK)
         WHERE Func = @nToFunc
         ORDER BY Scn

         IF @nToScn = 0
         BEGIN
            SET @nErrNo = 70222
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
            GOTO Step_6_Fail
         END

         SET @nPrevStep = 0
         SET @nFunc = @nToFunc
         SET @nScn = @nToScn
         SET @nStep = 1

      END
      ELSE IF (@cRefkey04 IN ('DOUBLES','MULTIS','PIECE','STOTE','PP')) -- Get Next Task
      BEGIN
         -- GOTO Step 7 When DropID <> ''
         IF @cRefkey03 = ''
         BEGIN
            SET @nToFunc = 0
            SET @nToScn = 0


            SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
            FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
            WHERE TaskType = RTRIM(@cTTMTasktype)

            IF @nFunc = 0
            BEGIN
               SET @nErrNo = 90074
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
               GOTO Step_6_Fail
            END

            SELECT TOP 1 @nToScn = Scn
            FROM RDT.RDTScn WITH (NOLOCK)
            WHERE Func = @nToFunc
            ORDER BY Scn

            IF @nToScn = 0
            BEGIN
               SET @nErrNo = 90075
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
               GOTO Step_6_Fail
            END

            SET @nPrevStep = 0
            SET @nFunc = @nToFunc
            SET @nScn = @nScnEmptyTote
            SET @nStep = @nStepEmptyTote

         END
         ELSE
         BEGIN
            SET @nPrevStep = 0

            SET @cPickMethod = @cRefkey04
            SET @cOutField05 = ''
            SET @cOutField04 = @cRefkey04
            SET @cOutField03 = @cRefkey03
            SET @cOutField09 = @cTTMTasktype

            SET @nFunc = 1809 -- (ChewKP02)

            SET @nScn = 3886
            SET @nStep = 7
         END

      END
     -- EventLog - Sign Out Function
--     EXEC RDT.rdt_STD_EventLog
--       @cActionType = '9', -- Sign Out function
--       @cUserID     = @cUserName,
--       @nMobileNo   = @nMobile,
--       @nFunctionID = @nFunc,
--       @cFacility   = @cFacility,
--       @cStorerKey  = @cStorerKey
   END  -- IF @nInputKey = 1

   IF @nInputKey = 0    --ESC
   BEGIN

      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE Userkey = @cUserName
                  AND Status = '3' )
      BEGIN
           -- Release ALL Task from Users when EXIT TM
          BEGIN TRAN
          Update dbo.TaskDetail WITH (ROWLOCK)
             SET Status = '0' , Userkey = '', DropID = '', Message02 = ''  -- should also update DropID
               , ListKey = '' -- SOS# 323841
          WHERE Userkey = @cUserName
          AND Status = '3'

          IF @@ERROR <> 0
          BEGIN
                SET @nErrNo = 90081
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                ROLLBACK TRAN
          GOTO Step_6_Fail
          END
          ELSE
          BEGIN
             COMMIT TRAN
          END
      END

      -- EventLog - Sign Out Function
--      EXEC RDT.rdt_STD_EventLog
--       @cActionType = '9', -- Sign Out function
--       @cUserID     = @cUserName,
--       @nMobileNo   = @nMobile,
--       @nFunctionID = @nFunc,
--       @cFacility   = @cFacility,
--       @cStorerKey  = @cStorerKey

     -- Go back to Task Manager Main Screen
     SET @nFunc = 1756
     SET @nScn = 2100
     SET @nStep = 1

     SET @cAreaKey = ''
     SET @nPrevStep = '0'

     SET @cOutField01 = ''  -- Area
     SET @cOutField02 = ''
     SET @cOutField03 = ''
     SET @cOutField04 = ''
     SET @cOutField05 = ''
     SET @cOutField06 = ''
     SET @cOutField07 = ''
     SET @cOutField08 = ''
     SET @cOutField09 = ''
   END
   GOTO Quit

   Step_6_Fail:
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
Step 7. Called from Task Manager Main Screen (func = 1760)
    Screen = 2436 (NEW TOTE) (TOTE FROM OTHER ZONE)
    PICKTYPE: (Field04)
    TOTE NO (Field03)
    TOTE NO (Field05, input)
********************************************************************************/
Step_7:
BEGIN
   -- Set all variable for 1st record - records are from rdtfnc_TaskManager
   IF @nPrevStep = 0
   BEGIN
      SET @cTaskdetailkey = @cOutField06
      SET @cAreaKey = @cOutField07
      SET @cTTMStrategykey = @cOutField08
      SET @cPickMethod = @cOutField04

      SET @cNextTaskDetailKey = ''
      SET @nScanQty = 0
      SET @cShortPickFlag = 'N'
      
      EXEC RDT.rdt_STD_EventLog               
           @cActionType = '3', 
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerKey,
           @cDropID     = @cToteNo,
           @cPickMethod = @cPickMethod,
           @cLocation   = @cFromLoc,
           @cSKU        = @cSKU,
           @cUOM        = @cUOM,
           @nExpectedQty = @nSuggQty,
           @cTaskType   = @cTTMTasktype,
           @cOption     = @cSHTOption,
           @nStep       = @nStep
   END

  IF @nInputKey = 1 -- ENTER
   BEGIN
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
      SET @cToteNo  = ISNULL(RTRIM(@cOutField03),'') -- ChewKP14
      SET @cInToteID = ISNULL(RTRIM(@cInField05),'')  -- ChewKP14

      SET @cExtendedWCSSP = rdt.RDTGetConfig( @nFunc, 'ExtendedWCSSP', @cStorerKey)
      IF @cExtendedWCSSP = '0'  
         SET @cExtendedWCSSP = ''

      IF @cInToteID = ''
      BEGIN
         SET @nErrNo = 90016
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTENO Req
         GOTO Step_7_Fail
      END

      IF rdt.rdtIsValidQTY( @cInToteID, 1) = 0
      BEGIN
         SET @nErrNo = 90057
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo
         GOTO Step_7_Fail
      END

      -- If User Scan Diff Tote, Ask whether they required to work on new tote or not?
      IF @cInToteID <> @cOutField03
      BEGIN
         -- Check The Task Type for Tote Scanned.
         DECLARE @cSwapTaskType      NVARCHAR(10),
                 @cSwapLoc           NVARCHAR(10),
                 @cSwapTaskDetailKey NVARCHAR(10),
                 @cSwapAreaKey       NVARCHAR(10)

         --SET @cTTMTasktype=''
         SET @cSwapTaskDetailKey=''
         SET @cSwapLoc=''

         -- Look for PK task 1st.
         SELECT TOP 1
                @cSwapTaskType=ISNULL(TaskType,''),
                @cSwapLoc=ISNULL(FromLoc,''),
                @cSwapTaskDetailKey=ISNULL(TaskDetailKey,'')
         FROM   dbo.TASKDETAIL TD WITH (NOLOCK)
         JOIN   dbo.LOC LOC WITH (NOLOCK) ON TD.FROMLOC = LOC.LOC
         JOIN   dbo.AreaDetail AD WITH (NOLOCK) ON LOC.Putawayzone = AD.Putawayzone
         WHERE  TD.StorerKey = @cStorerKey
           AND  TD.TaskType = 'PK'
           AND  TD.Status = '0' --IN ('0', '3')  -- (ChewKP03)
           AND  TD.DropID = @cInToteID
           AND  AD.AreaKey = @cAreaKey

         -- If not a PK Task, check whether is PA task?
         IF ISNULL(RTRIM(@cSwapTaskType),'') = ''
         BEGIN
            SELECT TOP 1
                @cSwapTaskType=ISNULL(TaskType,''),
                @cSwapLoc=ISNULL(ToLoc,''),
                @cSwapTaskDetailKey=ISNULL(TaskDetailKey,'')
            FROM   dbo.TASKDETAIL TD WITH (NOLOCK)
            JOIN   dbo.LOC LOC WITH (NOLOCK) ON TD.FROMLOC = LOC.LOC
            JOIN   dbo.AreaDetail AD WITH (NOLOCK) ON LOC.Putawayzone = AD.Putawayzone
            WHERE TD.StorerKey = @cStorerKey
            AND TD.TaskType = 'PA'
            AND TD.Status = '0' -- IN ('0', 'W')  -- (ChewKP03)
            AND TD.CaseID = @cInToteID
            AND AD.AreaKey = @cAreaKey

            IF ISNULL(RTRIM(@cSwapTaskType),'') <> ''
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.TaskManagerUserDetail WITH (NOLOCK)
                              WHERE UserKey = @cUserName
                              AND AreaKey = @cAreaKey
                              AND PermissionType = 'PA'
                              AND Permission = '1')
               BEGIN
                  SET @nErrNo = 90087
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo
                  GOTO Step_7_Fail
               END
            END
         END

         -- If Records not found. Invalid Tote
      IF ISNULL(RTRIM(@cSwapTaskType),'') = ''
     BEGIN
            SET @nErrNo = 90057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo
            GOTO Step_7_Fail
         END
         -- Check If the Swap Tote have the route to current Zone.
         SET @cSwapAreaKey=''
         SELECT TOP 1 @cSwapAreaKey = ISNULL(AD.AreaKey,'')
         FROM   LOC WITH (NOLOCK)
         JOIN   PutawayZone pz WITH (NOLOCK) ON LOC.PutawayZone=pz.PutawayZone
         JOIN   AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = pz.PutawayZone
         WHERE  LOC.Loc = @cSwapLoc

         SELECT TOP 1 @cCurrArea = AD.AREAKEY
         FROM dbo.TaskDetail td WITH (NOLOCK)
         JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc
         JOIN dbo.PUTAWAYZONE P (NOLOCK) ON L.PUTAWAYZONE = P.PUTAWAYZONE
         JOIN dbo.AREADETAIL AD (NOLOCK) ON P.PUTAWAYZONE = AD.PUTAWAYZONE
         WHERE td.TaskDetailKey = @cTaskdetailkey
            -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first
            AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END


         IF @cCurrArea <> @cSwapAreaKey
         BEGIN
            SET @nErrNo = 90057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo
            GOTO Step_7_Fail
         END


         IF @cSwapTaskType='PK'
         BEGIN

            SET @cTTMTasktype = @cSwapTaskType
            SET @nScn  = @nScnDiffTote
            SET @nStep = @nStepDiffTote
            SET @cOutField01 = @cOutField03 -- Old Tote
            SET @cOutField02 = @cInToteID   -- New Tote
            SET @cOutField03 = @cTTMTasktype
            SET @cNewToteNo  = @cInToteID

            GOTO QUIT
         END
         ELSE IF @cSwapTaskType='PA'
         BEGIN
            SET @cRefKey03 = ''
            SET @cRefkey04 = ''

            -- Release current task

            IF EXISTS ( SELECT 1 FROM DBO.TASKDETAIL  with (NOLOCK)
                        WHERE STATUS='3'
                        AND   UserKey = @cUserName )
            BEGIN
             UPDATE DBO.TASKDETAIL
                SET UserKey = '', STATUS='0'
             WHERE STATUS='3'
             AND   UserKey = @cUserName
             IF @@ERROR <> 0
             BEGIN
                SET @nErrNo = 90069
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                ROLLBACK TRAN
                GOTO Step_7_Fail
             END
          END

            -- Lock the new swapped task
            UPDATE DBO.TASKDETAIL
               SET UserKey = @cUserName, STATUS='3'
            WHERE STATUS = '0' -- (ChewKP03) IN ('3','0','W')
            AND   TaskType='PA'
            AND   Caseid = @cInToteID
            AND   TaskDetailKey=@cSwapTaskDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90069
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN
               GOTO Step_7_Fail
            END

            SELECT @cRefKey03 = CaseID,
                   @cRefkey04 = PickMethod,
                   @cPickMethod = PickMethod,
                   @cToteNo     = DropID,
                   @cTTMTasktype = TaskType
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailkey = @cSwapTaskDetailKey

            SET @cTaskdetailkey = @cSwapTaskDetailKey
            SET @cOutField01 = @cRefKey01
            SET @cOutField02 = @cRefKey02
            SET @cOutField03 = @cRefKey03
            SET @cOutField04 = @cRefKey04
            SET @cOutField05 = @cRefKey05
            SET @cOutField06 = @cTaskdetailkey
            SET @cOutField07 = @cAreaKey
            SET @cOutField08 = @cTTMStrategykey
            SET @nPrevStep = '0'

            SET @cOutField05 = ''

            SET @nToFunc = 0
            SET @nToScn = 0
            SET @nPrevStep = 0

            SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
            FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
            WHERE TaskType = RTRIM(@cTTMTasktype)

            IF @nFunc = 0
            BEGIN
               SET @nErrNo = 70238
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
               GOTO Step_5_Fail
            END

            SELECT TOP 1 @nToScn = Scn
            FROM RDT.RDTScn WITH (NOLOCK)
            WHERE Func = @nToFunc
            ORDER BY Scn

            IF @nToScn = 0
            BEGIN
               SET @nErrNo = 70239
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
               GOTO Step_5_Fail
            END

            SET @nScn = @nToScn
            SET @nFunc = @nToFunc
            SET @nStep = 1

            GOTO QUIT

         END
         ELSE
         BEGIN
            SET @nErrNo = 90057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo
            GOTO Step_7_Fail
         END
      END

      SET @cToteNo = @cInToteID
      SELECT TOP 1
             @cTaskStorer = RTRIM(TD.Storerkey),
             @cSKU        = RTRIM(TD.SKU),
             @cSuggID     = RTRIM(TD.FromID),
             @cSuggToLoc  = RTRIM(TD.ToLOC),
             @cLot        = RTRIM(TD.Lot),
             @cSuggFromLoc  = RTRIM(TD.FromLoc),
             @nSuggQTY    = TD.Qty,
             @cLoadkey    = RTRIM(LPD.Loadkey),
             @cOrderkey   = RTRIM(PD.Orderkey),
             @cWaveKey    = ISNULL(TD.WaveKey,''),
             @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
      JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
      WHERE TD.TaskDetailKey = @cTaskdetailkey

      SELECT @cCurrPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)
      WHERE LOC = @cSuggFromLoc AND Facility = @cFacility

      SELECT @cFinalPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)
      WHERE LOC = @cSuggToLoc AND Facility = @cFacility


      -- Update WCSRoutingDetail Status = '1' Indicate Visited --
      SELECT @cPPAZone = RTRIM(SHORT) FROM dbo.CodeLKup WITH (NOLOCK) -- (Vicky02)
      WHERE Listname = 'WCSStation' And Code = @cCurrPutawayzone



      -- (Vicky02) - Start
--      IF ISNULL(RTRIM(@cPPAZone), '') = ''
--      BEGIN
--         SET @nErrNo = 90078
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WcsStatnNotSet'
--         GOTO Step_7_Fail
--      END
--      -- (Vicky02) - End

      BEGIN TRAN
      UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
      SET Status = '1' ,
      EditWho = @cUserName , EditDate = GetDate()
      WHERE ToteNo = @cToteNo
      AND Zone = @cPPAZone

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 90049
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'
         ROLLBACK TRAN
         GOTO Step_7_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END


      BEGIN TRAN
      Update dbo.TaskDetail WITH (ROWLOCK)
      SET StartTime = GETDATE(),
          EditDate = GETDATE(),
          EditWho = @cUserName,
          TrafficCop=NULL
      WHERE TaskDetailkey = @cTaskdetailkey

      IF @@ERROR <> 0
      BEGIN
            SET @nErrNo = 90063
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
            ROLLBACK TRAN
            GOTO Step_7_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      -- EventLog - Sign In Function
--      EXEC RDT.rdt_STD_EventLog
--         @cActionType = '1', -- Sign in function
--         @cUserID     = @cUserName,
--         @nMobileNo   = @nMobile,
--         @nFunctionID = @nFunc,
--         @cFacility  = @cFacility,
--         @cStorerKey  = @cStorerKey


      -- prepare next screen
      SET @cUserPosition = '1'

      SET @nPrevStep = 1

      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cToteNo
      SET @cOutField03 = @cSuggFromLoc
      SET @cOutField04 = ''
      SET @cOutField05 = @cTTMTasktype

      SET @nFromScn  = @nScn
      SET @nFromStep = @nStep

      -- Go to FromLoc screen
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END


   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''
      SET @cToteNo    = @cOutField03

      -- If Task already stealed by someone, do not go to reason code screen
      -- GOTO get next task screen.
      IF EXISTS(SELECT 1 FROM TaskDetail WITH (NOLOCK)
                WHERE TaskDetailkey = @cTaskdetailkey
                  AND Userkey <> @cUserName
                  AND DropID = @cToteNo
                  AND Status = '3')
      BEGIN
         SET @cToteNo = ''
         SET @nScn = 2438
         SET @nStep = 10
         SET @cOutField01 = @cTTMTasktype
      END
      ELSE
      BEGIN
         -- Go to Reason Code screen
         SET @nFromScn  = @nScn
         SET @nFromStep = @nStep

         -- Go to Reason Code Screen
         SET @nScn  = 2109
         SET @nStep = @nStep + 2 -- Step 9
      END
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      -- Reset this screen var
      SET @cInToteID = ''

      SET @cOutField04 = @cPickMethod -- Suggested FromLOC
      SET @cOutField03 = @cOutField03  -- Suggested ToteNo
      SET @cOutField05 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 8. screen = 3887
   TOTE CLOSED MSG
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
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
      
      
      SET @cUserPosition = '1'

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
         ,  @c_areakey02  = ''
         ,  @c_areakey03     = ''
         ,  @c_areakey04     = ''
         ,  @c_areakey05     = ''
         ,  @c_lastloc       = @cSuggToLoc
         ,  @c_lasttasktype  = 'SPK'
         ,  @c_outstring     = @c_outstring    OUTPUT
         ,  @b_Success       = @b_Success      OUTPUT
         ,  @n_err           = @nErrNo         OUTPUT
         ,  @c_errmsg        = @cErrMsg        OUTPUT
         ,  @c_taskdetailkey = @cNextTaskDetailKey OUTPUT
         ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
         ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

       --@nErrNo = 67804 -- Nothing to do!
       IF ISNULL(RTRIM(@cNextTaskDetailKey), '') = ''
       BEGIN
          -- EventLog - Sign Out Function
--          EXEC RDT.rdt_STD_EventLog
--          @cActionType = '9', -- Sign Out function
--          @cUserID     = @cUserName,
--          @nMobileNo   = @nMobile,
--          @nFunctionID = @nFunc,
--          @cFacility   = @cFacility,
--          @cStorerKey  = @cTaskStorer
          EXEC RDT.rdt_STD_EventLog   
              @cActionType = '3',             
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerKey,
              @cDropID     = @cToteNo,
              @cPickMethod = @cPickMethod,
              @cLocation   = @cFromLoc,
              @cSKU        = @cSKU,
              @cUOM        = @cUOM,
              @nExpectedQty = @nSuggQty,
              @cTaskType   = @cTTMTasktype,
              @cOption     = @cSHTOption,
              @nStep       = @nStep

           -- Go back to Task Manager Main Screen
           SET @nFunc = 1756
           SET @nScn  = 2100
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
           SET @cOutField09 = ''
           GOTO QUIT
       END

       IF ISNULL(@cErrMsg, '') <> ''
       BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_8_Fail
       END

       IF ISNULL(@cNextTaskDetailKey, '') <> ''
       BEGIN
         SET @cRefKey03 = ''
         SET @cRefkey04 = ''

         SELECT @cRefKey03 = CASE WHEN TaskType = 'PA' THEN CaseID ELSE DropID END,
                @cRefkey04 = PickMethod,
                @cPickMethod = PickMethod,
                @cToteNo     = DropID,
                @cTTMTasktype = TaskType
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailkey = @cNextTaskDetailKey

         IF @cRefKey03 = ''
         BEGIN
            SELECT @cRefKey03 = ListKey
            From dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailkey = @cNextTaskDetailKey
         END

         SET @cTaskdetailkey = @cNextTaskDetailKey
         SET @cOutField01 = @cRefKey01
         SET @cOutField02 = @cRefKey02
         SET @cOutField03 = @cRefKey03
         SET @cOutField04 = @cRefKey04
         SET @cOutField05 = @cRefKey05
         SET @cOutField06 = @cTaskdetailkey
         SET @cOutField07 = @cAreaKey
         SET @cOutField08 = @cTTMStrategykey
         SET @cOutField09 = @cTTMTasktype
         SET @nPrevStep = '0'
         SET @cOutField05 = ''
      END

      IF @cTTMTasktype NOT IN ('PK','SPK')
      BEGIN
         SET @nToFunc = 0
         SET @nToScn = 0
         SET @nPrevStep = 0

         SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
         FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
         WHERE TaskType = RTRIM(@cTTMTasktype)

         IF @nFunc = 0
         BEGIN
            SET @nErrNo = 70238
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
            GOTO Step_8_Fail
         END

         SELECT TOP 1 @nToScn = Scn
         FROM RDT.RDTScn WITH (NOLOCK)
         WHERE Func = @nToFunc
         ORDER BY Scn

         IF @nToScn = 0
         BEGIN
            SET @nErrNo = 70239
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
            GOTO Step_8_Fail
         END
         
         EXEC RDT.rdt_STD_EventLog     
              @cActionType = '3',           
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerKey,
              @cDropID     = @cToteNo,
              @cPickMethod = @cPickMethod,
              @cLocation   = @cFromLoc,
              @cSKU        = @cSKU,
              @cUOM        = @cUOM,
              @nExpectedQty = @nSuggQty,
              @cTaskType   = @cTTMTasktype,
              @cOption     = @cSHTOption,
              @nStep       = @nStep

         SET @nScn = @nToScn
         SET @nFunc = @nToFunc
         SET @nStep = 1

         -- EventLog - Sign Out Function
--         EXEC RDT.rdt_STD_EventLog
--           @cActionType = '9', -- Sign Out function
--           @cUserID     = @cUserName,
--           @nMobileNo   = @nMobile,
--           @nFunctionID = @nFunc,
--           @cFacility   = @cFacility,
--           @cStorerKey  = @cTaskStorer

         GOTO QUIT
      END
      IF (@cRefkey04 = 'SINGLES' ) -- Get Next Task
      BEGIN
         SET @nToFunc = 0
         SET @nToScn = 0

         SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
         FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
         WHERE TaskType = RTRIM(@cTTMTasktype)

         IF @nFunc = 0
         BEGIN
            SET @nErrNo = 90046
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
            GOTO Step_8_Fail
         END

         SELECT TOP 1 @nToScn = Scn
         FROM RDT.RDTScn WITH (NOLOCK)
         WHERE Func = @nToFunc
         ORDER BY Scn
         IF @nToScn = 0
         BEGIN
            SET @nErrNo = 90047
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
            GOTO Step_8_Fail
         END
         
         EXEC RDT.rdt_STD_EventLog               
              @cActionType = '3', 
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerKey,
              @cDropID     = @cToteNo,
              @cPickMethod = @cPickMethod,
              @cLocation   = @cFromLoc,
              @cSKU        = @cSKU,
              @cUOM        = @cUOM,
              @nExpectedQty = @nSuggQty,
              @cTaskType   = @cTTMTasktype,
              @cOption     = @cSHTOption,
              @nStep       = @nStep

         SET @nPrevStep = 0
         SET @nFunc = @nToFunc
         SET @nScn = @nToScn
         SET @nStep = 1

      END
      ELSE IF (@cRefkey04 IN ('DOUBLES','MULTIS','PIECE','STOTE','PP')) -- Get Next Task
      BEGIN
         IF @cRefkey03 = ''
         BEGIN
            SET @nToFunc = 0
            SET @nToScn = 0

            SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
            FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
            WHERE TaskType = RTRIM(@cTTMTasktype)

            IF @nFunc = 0
            BEGIN
               SET @nErrNo = 90072
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
               GOTO Step_8_Fail
            END

            SELECT TOP 1 @nToScn = Scn
            FROM RDT.RDTScn WITH (NOLOCK)
            WHERE Func = @nToFunc
            ORDER BY Scn

            IF @nToScn = 0
            BEGIN
               SET @nErrNo = 90073
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
               GOTO Step_8_Fail
            END
            
            EXEC RDT.rdt_STD_EventLog               
              @cActionType = '3', 
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerKey,
              @cDropID     = @cToteNo,
              @cPickMethod = @cPickMethod,
              @cLocation   = @cFromLoc,
              @cSKU        = @cSKU,
              @cUOM        = @cUOM,
              @nExpectedQty = @nSuggQty,
              @cTaskType   = @cTTMTasktype,
              @cOption     = @cSHTOption,
              @nStep       = @nStep

            SET @nPrevStep = 0
            SET @nFunc = @nToFunc
            SET @nScn = @nToScn
            SET @nStep = 1
         END
         ELSE
         BEGIN
            EXEC RDT.rdt_STD_EventLog               
              @cActionType = '3', 
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerKey,
              @cDropID     = @cToteNo,
              @cPickMethod = @cPickMethod,
              @cLocation   = @cFromLoc,
              @cSKU        = @cSKU,
              @cUOM        = @cUOM,
              @nExpectedQty = @nSuggQty,
              @cTaskType   = @cTTMTasktype,
              @cOption     = @cSHTOption,
              @nStep       = @nStep
              
            SET @nPrevStep = 0

            SET @cPickMethod = @cRefkey04
            SET @cOutField05 = ''
            SET @cOutField04 = @cRefkey04
            SET @cOutField03 = @cRefkey03
            SET @cOutField09 = @cTTMTasktype

            SET @nFunc = 1809
            SET @nScn = 3886
            SET @nStep = 7
         END
      END
      -- EventLog - Sign Out Function
--      EXEC RDT.rdt_STD_EventLog
--          @cActionType = '9', -- Sign Out function
--          @cUserID     = @cUserName,
--          @nMobileNo   = @nMobile,
--          @nFunctionID = @nFunc,
--          @cFacility   = @cFacility,
--          @cStorerKey  = @cTaskStorer

   END -- IF @nInputKey = 1

   IF @nInputKey = 0    --ESC
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE Userkey = @cUserName
                  AND Status = '3' )
      BEGIN
          -- Release ALL Task from Users when EXIT TM --
          BEGIN TRAN
          Update dbo.TaskDetail WITH (ROWLOCK)
             SET Status = '0' , Userkey = '', DropID = '', Message02 = ''  -- should also update DropID
               , ListKey = '' -- SOS# 323841
          WHERE Userkey = @cUserName
          AND Status = '3'

         IF @@ERROR <> 0
          BEGIN
                SET @nErrNo = 90082
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                ROLLBACK TRAN
                GOTO Step_8_Fail
          END
          ELSE
          BEGIN
             COMMIT TRAN
          END
      END

      -- EventLog - Sign Out Function
--      EXEC RDT.rdt_STD_EventLog
--       @cActionType = '9', -- Sign Out function
--       @cUserID     = @cUserName,
--       @nMobileNo   = @nMobile,
--       @nFunctionID = @nFunc,
--       @cFacility   = @cFacility,
--       @cStorerKey  = @cStorerKey

     --
     IF @cUserPosition = ''
     BEGIN
         SET @cUserPosition = '1'
     END

     -- Go back to Task Manager Main Screen
     SET @nFunc = 1756
     SET @nScn = 2100
     SET @nStep = 1

     SET @cAreaKey = ''
     SET @nPrevStep = '0'

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

   Step_8_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cToteNo
      SET @cOutField03 = @cSuggFromLoc
      SET @cOutField04 = ''
   END
END -- Step 8
GOTO Quit

/********************************************************************************
Step 9. screen = 2109
     REASON CODE  (Field01, input)
     1 = Short Pick
     9 = Close Tote
********************************************************************************/
Step_9:
BEGIN

   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cReasonCode = @cInField01

      IF @cReasonCode = ''
      BEGIN
        SET @nErrNo = 90024
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req
        GOTO Step_9_Fail
      END
      ELSE
      BEGIN
         IF NOT EXISTS( SELECT TOP 1 1
                        FROM CodeLKUP WITH (NOLOCK)
                        WHERE ListName = 'RDTTASKRSN'
                           AND StorerKey = @cStorerKey
                           AND Code = @cTTMTaskType
                           AND @cReasonCode IN (UDF01, UDF02, UDF03, UDF04, UDF05))
         BEGIN
           SET @nErrNo = 69865
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69865^BAD REASON
           GOTO Step_9_Fail
         END
      END

--      IF @cShortPickFlag = 'Y'
--      BEGIN
--         IF EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK)
--                   WHERE c.LISTNAME = 'SPKINVRSN'
--                   AND   C.Code = @cReasonCode)
--         BEGIN
--           SET @nErrNo = 69865
--           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69865^BAD REASON
--           GOTO Step_9_Fail
--         END
--      END
--      ELSE
--      BEGIN
--         IF EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK)
--                   WHERE c.LISTNAME = 'NSPKINVRSN '
--                   AND   C.Code = @cReasonCode)
--         BEGIN
--           SET @nErrNo = 69865
--           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69865^BAD REASON
--           GOTO Step_9_Fail
--         END
--      END

      -- (ChewKP05)
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'  
      BEGIN
         SET @cExtendedValidateSP = ''
      END
      
      IF @cExtendedValidateSP <> ''
      BEGIN
               

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            
              SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
                 ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @nFromStep, @cReasonCode, @cTaskDetailKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
              SET @cSQLParam =
                 '@nMobile        INT, ' +
                 '@nFunc          INT, ' +
                 '@cLangCode      NVARCHAR( 3),  ' +
                 '@nStep          INT, ' +
                 '@cStorerKey     NVARCHAR( 15), ' +
                 '@nFromStep      INT,           ' +
                 '@cReasonCode    NVARCHAR( 10), ' +
                 '@cTaskDetailKey NVARCHAR( 20), ' +
                 '@cDropID        NVARCHAR( 20), ' +
                 '@nErrNo         INT           OUTPUT, ' + 
                 '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
              
              EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @nFromStep, @cReasonCode, @cTaskDetailKey, @cToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                  

                  IF @nErrNo <> 0 
                  BEGIN
                    GOTO  Step_9_Fail
                  END
 
         END
         
                  
      END

      -- Update ReasonCode
      EXEC dbo.nspRFRSN01
              @c_sendDelimiter = NULL
           ,  @c_ptcid         = 'RDT'
           ,  @c_userid        = @cUserName
           ,  @c_taskId        = 'RDT'
           ,  @c_databasename  = NULL
           ,  @c_appflag       = NULL
           ,  @c_recordType    = NULL
           ,  @c_server        = NULL
           ,  @c_ttm           = NULL
           ,  @c_taskdetailkey = @cTaskdetailkey
           ,  @c_fromloc       = @cFromLoc
           ,  @c_fromid        = ''
           ,  @c_toloc         = @cSuggToloc
           ,  @c_toid          = ''
           ,  @n_qty           = @nScanQty--0
           ,  @c_packkey       = ''
           ,  @c_uom           = ''
           ,  @c_reasoncode    = @cReasonCode
           ,  @c_outstring     = @c_outstring    OUTPUT
           ,  @b_Success       = @b_Success      OUTPUT
           ,  @n_err           = @nErrNo         OUTPUT
           ,  @c_errmsg        = @cErrMsg        OUTPUT
           ,  @c_userposition  = @cUserPosition

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_9_Fail
      END

      SET @cContinueProcess = ''
      SET @cTaskStatus      = ''
      SET @cRemoveUserTask  = ''

      SELECT
         @cContinueProcess = ContinueProcessing,
         @cRemoveUserTask = RemoveTaskFromUserQueue,
         @cTaskStatus = TaskStatus
      FROM dbo.TaskManagerReason WITH (NOLOCK)
      WHERE TaskManagerReasonKey = @cReasonCode



--      SET @cContinueProcess = ''
--      SELECT @cContinueProcess = ContinueProcessing
--      FROM dbo.TASKMANAGERREASON WITH (NOLOCK)
--      WHERE TaskManagerReasonKey = @cReasonCode

      -- Update Pick Detail Confirm Task for Short Status = '4' -- Should be common Stored Proc
      -- Update WCSRouting.FinalZone
      -- WCS Short Interface
      -- ToteNo to DropID
      -- Retrieve Next Task (If Doubles / Multis Should Retrieve Same Task Within same zone )


      SET @cTMAutoShortPick = ''
      SET @cTMAutoShortPick = rdt.RDTGetConfig( @nFunc, 'TMAutoShortPick', @cStorerKey)

      IF @cTMAutoShortPick = '1'
      BEGIN
         SET @cShortPickFlag = 'Y'

         IF @nFromStep = '2'
         BEGIN
            SET @cFromLoc = ''
         END
      END

      IF @cContinueProcess = 1 -- SHORT PICK PROCESS
      BEGIN
         IF @nScanQTY <> 0
         BEGIN
            
            SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)  
            IF @cConfirmSP = '0'  
               SET @cConfirmSP = ''  
            
            IF @cConfirmSP <> '' 
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')  
               BEGIN  
                    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +  
                     '   @nMobile  , @nFunc    , @cStorerKey, @cUserName, @cFacility  , @cTaskDetailKey , @cLoadKey, @cSKU '+
                     ' , @cAltSKU  , @cLOC     , @cToLOC    , @cID      , @cToteNo    , @nPickQty       , @cStatus '+        
                     ' , @cLangCode, @nTotalQty, @nErrNo    , @cErrMsg  , @cPickMethod, @cNTaskDetailkey  '
                  SET @cSQLParam =  
                     '   @nMobile          INT                    '+      
                     ' , @nFunc            INT                    '+
                     ' , @cStorerKey       NVARCHAR(15)           '+
                     ' , @cUserName        NVARCHAR(15)           '+
                     ' , @cFacility        NVARCHAR(5)            '+
                     ' , @cTaskDetailKey   NVARCHAR(10)           '+
                     ' , @cLoadKey         NVARCHAR(10)           '+
                     ' , @cSKU             NVARCHAR(20)           '+
                     ' , @cAltSKU          NVARCHAR(20)           '+
                     ' , @cLOC             NVARCHAR(10)           '+
                     ' , @cToLOC           NVARCHAR(10)           '+
                     ' , @cID              NVARCHAR(18)           '+
                     ' , @cToteNo          NVARCHAR(18)           '+
                     ' , @nPickQty         INT                    '+
                     ' , @cStatus          NVARCHAR(1)            '+
                     ' , @cLangCode        NVARCHAR(3)            '+
                     ' , @nTotalQty        INT                    '+
                     ' , @nErrNo           INT          OUTPUT    '+
                     ' , @cErrMsg          NVARCHAR(20) OUTPUT    '+
                     ' , @cPickMethod      NVARCHAR(10)           '+
                     ' , @cNTaskDetailkey  NVARCHAR(10)           '
           
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                     @nMobile,     @nFunc, @cTaskStorer,  @cUserName,  @cFacility,      @cTaskDetailKey,
                     @cLoadKey,    @cSKU,  '',            @cFromLoc,   '',              '',               @cToteNo,
                     @nScanQty,    '4',    @cLangCode,    @nSuggQTY,   @nErrNo OUTPUT,  @cErrMsg OUTPUT,  @cPickMethod, ''          
           
               END  
            END            
            ELSE
            BEGIN
               EXECUTE RDT.rdt_TM_TotePick_ConfirmTask
                  @nMobile=@nMobile,
                  @nFunc=@nFunc,
                  @cStorerKey=@cTaskStorer,
                  @cUserName=@cUserName,
                  @cFacility=@cFacility,
                  @cTaskDetailKey=@cTaskDetailKey,
                  @cLoadKey=@cLoadKey,
                  @cSKU=@cSKU,
                  @cAltSKU='',
                  @cLOC=@cFromLoc,
                  @cToLOC='',
                  @cID='',
                  @cToteNo=@cToteNo,
                  @nPickQty=@nScanQTY,
                  @cStatus='4',
                  @cLangCode=@cLangCode,
                  @nTotalQty=@nSuggQTY,
                  @nErrNo=@nErrNo OUTPUT,
                  @cErrMsg=@cErrMsg OUTPUT,
                  @cPickMethod=@cPickMethod
            END

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_9_Fail
            END

            -- INSERT INTO DropID and DropID Detail Table (Start) --
            BEGIN TRAN BT_005

            IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @cToteNo )
            BEGIN
               INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )
               VALUES (@cToteNo , '' , @cPickMethod, '5' , @cLoadkey, @cPickSlipNo)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90033
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'
                  ROLLBACK TRAN BT_005
                  GOTO Step_9_Fail
               END
            END
            ELSE
            BEGIN
               UPDATE Dropid
               SET STATUS = '5'
               WHERE Dropid = @cToteNo
               AND   [Status] ='0'
               AND   Loadkey  = CASE WHEN ISNULL(RTRIM(@cLoadkey), '') <> '' THEN @cLoadkey ELSE DropID.LoadKey END
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DROPID = @cToteNo AND ChildID = @cSKU)
            BEGIN
               INSERT INTO DROPIDDETAIL ( DropID, ChildID)
               VALUES (@cToteNo, @cSKU )

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90034
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'
                  ROLLBACK TRAN BT_005
                  GOTO Step_9_Fail
               END
            END
            COMMIT TRAN BT_005

            -- INSERT INTO DropID and DropID Detail Table (End) --
            -- For Short Pick --
            -- 1. Stamp QC Loc to ToLoc for Current Task --
            SELECT @cQCLOC = RTRIM(Short)
            FROM CODELKUP WITH (NOLOCK) -- (Vicky02)
            WHERE Listname = 'WCSROUTE' AND Code = 'QC'

            IF ISNULL(RTRIM(@cQCLOC), '') = ''
            BEGIN
               SET @nErrNo = 90067
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QCNotInWCSROUTE'
               GOTO Step_9_Fail
            END
            
            -- Set the task final destination to QC location
            SET @cTMAutoShortPick = ''
            SET @cTMAutoShortPick = rdt.RDTGetConfig( @nFunc, 'TMAutoShortPick', @cStorerKey)

            IF @cTMAutoShortPick <> '1'
            BEGIN
               BEGIN TRAN

               UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET ToLoc = @cQCLOC,
                   LogicalToLoc = @cQCLOC,
                   TrafficCop = NULL
               WHERE TaskDetailkey = @cTaskDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90038
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  ROLLBACK TRAN
                  GOTO Step_9_Fail
               END

               COMMIT TRAN
            END

            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedWCSSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedWCSSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cType, @cStorerKey, @cReasonCode, @cTaskDetailKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT, ' +
                  '@nInputKey      INT, ' +
                  '@cType          NVARCHAR( 10), ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cReasonCode    NVARCHAR( 10), ' +
                  '@cTaskDetailKey NVARCHAR( 20), ' +
                  '@cDropID        NVARCHAR( 20), ' +
                  '@nErrNo         INT           OUTPUT, ' + 
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
              
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, 'S', @cStorerKey, @cReasonCode, @cTaskDetailKey, @cToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
              
               IF @nErrNo <> 0 
                  GOTO Step_3_Fail
               END
         
--            IF CAST(@cToteNo AS INT) > 0
--            BEGIN
--               IF @cTMAutoShortPick = '1'
--               BEGIN
--                  IF @cPickMethod <> 'PIECE'
--                  BEGIN
--                     EXEC [dbo].[ispWCSRO01]
--                       @c_StorerKey     = @cTaskStorer
--                     , @c_Facility      = @cFacility
--                     , @c_ToteNo        = @cToteNo
--                     , @c_TaskType      = 'SPK'
--                     , @c_ActionFlag    = 'S' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
--                     , @c_TaskDetailKey = '' -- @cTaskdetailkey
--                     , @c_Username      = @cUserName
--                     , @c_RefNo01       = @cLoadKey
--                     , @c_RefNo02       = ''
--                     , @c_RefNo03       = ''
--                     , @c_RefNo04       = ''
--                     , @c_RefNo05       = ''
--                     , @b_debug         = '0'
--                     , @c_LangCode      = 'ENG'
--                     , @n_Func          = 0
--                     , @b_Success       = @b_success OUTPUT
--                     , @n_ErrNo         = @nErrNo    OUTPUT
--                     , @c_ErrMsg        = @cErrMSG   OUTPUT
--
--                      IF @nErrNo <> 0
--                      BEGIN
--                         SET @nErrNo = @nErrNo
--                         SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'
--                         GOTO Step_9_Fail
--                      END      --                  END
--               END --   @cTMAutoShortPick = '1'
--               ELSE
--               BEGIN
--                  EXEC [dbo].[ispWCSRO01]
--                    @c_StorerKey     = @cTaskStorer
--                  , @c_Facility      = @cFacility
--                  , @c_ToteNo        = @cToteNo
--                  , @c_TaskType      = 'SPK'
--                  , @c_ActionFlag    = 'S' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
--                  , @c_TaskDetailKey = '' -- @cTaskdetailkey
--                  , @c_Username      = @cUserName
--                  , @c_RefNo01       = @cLoadKey
--                  , @c_RefNo02       = ''
--                  , @c_RefNo03       = ''
--                  , @c_RefNo04       = ''
--                  , @c_RefNo05       = ''
--                  , @b_debug         = '0'
--                  , @c_LangCode      = 'ENG'
--                  , @n_Func          = 0
--                  , @b_Success       = @b_success OUTPUT
--                  , @n_ErrNo         = @nErrNo    OUTPUT
--                  , @c_ErrMsg        = @cErrMSG   OUTPUT
--
--                   IF @nErrNo <> 0
--                   BEGIN
--                   SET @nErrNo = @nErrNo
--                      SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'
--                      GOTO Step_9_Fail
--                   END
--               END
--            END
            ---*** INSERT INTO WCSRouting (End) ***---
         END
         ELSE IF @nScanQTY = 0 AND @cShortPickFlag = 'Y'
         BEGIN
            
            SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)  
            IF @cConfirmSP = '0'  
               SET @cConfirmSP = ''  
            
            IF @cConfirmSP <> '' 
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')  
               BEGIN  
                    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +  
                     '   @nMobile  , @nFunc    , @cStorerKey, @cUserName, @cFacility  , @cTaskDetailKey , @cLoadKey, @cSKU '+
                     ' , @cAltSKU  , @cLOC     , @cToLOC    , @cID      , @cToteNo    , @nPickQty       , @cStatus '+        
                     ' , @cLangCode, @nTotalQty, @nErrNo    , @cErrMsg  , @cPickMethod, @cNTaskDetailkey  '
                  SET @cSQLParam =  
                     '   @nMobile          INT                    '+      
                     ' , @nFunc            INT                    '+
                     ' , @cStorerKey       NVARCHAR(15)           '+
                     ' , @cUserName        NVARCHAR(15)           '+
                     ' , @cFacility        NVARCHAR(5)            '+
                     ' , @cTaskDetailKey   NVARCHAR(10)           '+
                     ' , @cLoadKey         NVARCHAR(10)           '+
                     ' , @cSKU             NVARCHAR(20)           '+
                     ' , @cAltSKU          NVARCHAR(20)           '+
                     ' , @cLOC             NVARCHAR(10)           '+
                     ' , @cToLOC           NVARCHAR(10)           '+
                     ' , @cID              NVARCHAR(18)           '+
                     ' , @cToteNo          NVARCHAR(18)           '+
                     ' , @nPickQty         INT                    '+
                     ' , @cStatus          NVARCHAR(1)            '+
                     ' , @cLangCode        NVARCHAR(3)            '+
                     ' , @nTotalQty        INT                    '+
                     ' , @nErrNo           INT          OUTPUT    '+
                     ' , @cErrMsg          NVARCHAR(20) OUTPUT    '+
                     ' , @cPickMethod      NVARCHAR(10)           '+
                     ' , @cNTaskDetailkey  NVARCHAR(10)           '
           
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                     @nMobile,     @nFunc, @cTaskStorer,  @cUserName,  @cFacility,      @cTaskDetailKey,
                     @cLoadKey,    @cSKU,  '',            @cFromLoc,   '',              '',               @cToteNo,
                     @nScanQty,    '4',    @cLangCode,    @nSuggQTY,   @nErrNo OUTPUT,  @cErrMsg OUTPUT,  @cPickMethod, ''          
           
               END  
            END            
            ELSE
            BEGIN
               
               EXECUTE RDT.rdt_TM_TotePick_ConfirmTask
                  @nMobile,
                  @nFunc,
                  @cTaskStorer,
                  @cUserName,
                  @cFacility,
                  @cTaskDetailKey,
                  @cLoadKey,
                  @cSKU,
                  '',
                  @cFromLoc,
                  '', --@cToLoc,
                  '',
                  @cToteNo,
                  @nScanQTY,
                  '4',
                  @cLangCode,
                  @nSuggQTY,
                  @nErrNo OUTPUT,
                  @cErrMsg OUTPUT,
                  @cPickMethod
            END
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_9_Fail
            END

            -- For Short Pick --
            -- 1. Stamp QC Loc to ToLoc for Current Task --

            SELECT @cQCLOC = RTRIM(Short)
            FROM CODELKUP (NOLOCK)
            WHERE Listname = 'WCSROUTE' AND Code = 'QC'

            IF ISNULL(RTRIM(@cQCLOC), '') = ''
            BEGIN
               SET @nErrNo = 90068
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QCNotInWCSROUTE'
               GOTO Step_9_Fail
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @cToteNo )
            BEGIN
               INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )
               VALUES (@cToteNo , '' , @cPickMethod, '5' , @cLoadkey, @cPickSlipNo)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90097
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'
                  GOTO Step_9_Fail
               END
            END
            ELSE
            BEGIN
               UPDATE Dropid
               SET STATUS = '5'
               WHERE Dropid = @cToteNo
               AND   [Status] ='0'
               AND   Loadkey  = CASE WHEN ISNULL(RTRIM(@cLoadkey), '') <> '' THEN @cLoadkey ELSE DropID.LoadKey END
            END


            SET @cTMAutoShortPick = ''
            SET @cTMAutoShortPick = rdt.RDTGetConfig( @nFunc, 'TMAutoShortPick', @cStorerKey)

            IF @cTMAutoShortPick <> '1'
            BEGIN
            BEGIN TRAN

               UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET ToLoc = @cQCLOC, LogicalToLoc = @cQCLOC , TrafficCop = NULL
               WHERE TaskDetailkey = @cTaskDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90069
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  ROLLBACK TRAN
                  GOTO Step_9_Fail           END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
            END

            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedWCSSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedWCSSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cType, @cStorerKey, @cReasonCode, @cTaskDetailKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT, ' +
                  '@nInputKey      INT, ' +
                  '@cType          NVARCHAR( 10), ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cReasonCode    NVARCHAR( 10), ' +
                  '@cTaskDetailKey NVARCHAR( 20), ' +
                  '@cDropID        NVARCHAR( 20), ' +
                  '@nErrNo         INT           OUTPUT, ' + 
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'
                 
              
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, 'S', @cStorerKey, @cReasonCode, @cTaskDetailKey, @cToteNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
              
               IF @nErrNo <> 0 
                  GOTO Step_3_Fail
               END
         
            ---*** INSERT INTO WCSRouting (Starting) ***---
            -- Added by Shong - Delete action already send to WCS route Singles pick
            -- Need to add New tote instead of Update action back to WCS (Shong01)
--            IF CAST(@cToteNo AS INT) > 0
--            BEGIN
--               SET @cActionFlag = 'S'
--
--               IF @cTMAutoShortPick = '1'
--               BEGIN
--                IF @cPickMethod <> 'PIECE'
--                BEGIN
--                  EXEC [dbo].[ispWCSRO01]
--                    @c_StorerKey     = @cTaskStorer
--                  , @c_Facility      = @cFacility
--                  , @c_ToteNo        = @cToteNo
--                  , @c_TaskType = 'SPK'
--                  , @c_ActionFlag    = @cActionFlag -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
--                  , @c_TaskDetailKey = '' -- @cTaskdetailkey
--                  , @c_Username      = @cUserName
--                  , @c_RefNo01       = @cLoadKey
--  , @c_RefNo02       = ''
--                  , @c_RefNo03       = ''
--                  , @c_RefNo04       = ''
--                  , @c_RefNo05       = ''
--                  , @b_debug         = '0'
--                  , @c_LangCode      = 'ENG'
--                  , @n_Func          = 0
--                  , @b_Success       = @b_success OUTPUT
--                  , @n_ErrNo         = @nErrNo    OUTPUT
--                  , @c_ErrMsg        = @cErrMSG   OUTPUT
--
--                   IF @nErrNo <> 0
--                   BEGIN
--                      SET @nErrNo = @nErrNo
--                      SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'
--                      GOTO Step_9_Fail
--                   END
--                END
--              END -- @cTMAutoShortPick = '1'
--              ELSE
--              BEGIN
--                  EXEC [dbo].[ispWCSRO01]
--                    @c_StorerKey     = @cTaskStorer
--                  , @c_Facility      = @cFacility
--                  , @c_ToteNo        = @cToteNo
--                  , @c_TaskType      = 'SPK'
--                  , @c_ActionFlag    = @cActionFlag -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual
--                  , @c_TaskDetailKey = '' -- @cTaskdetailkey
--                  , @c_Username      = @cUserName
--                  , @c_RefNo01       = @cLoadKey
--                  , @c_RefNo02       = ''
--                  , @c_RefNo03       = ''
--                  , @c_RefNo04       = ''
--                  , @c_RefNo05       = ''
--                  , @b_debug         = '0'
--                  , @c_LangCode      = 'ENG'
--                  , @n_Func          = 0
--                  , @b_Success       = @b_success OUTPUT
--                  , @n_ErrNo         = @nErrNo    OUTPUT
--                  , @c_ErrMsg        = @cErrMSG   OUTPUT
--
--                   IF @nErrNo <> 0
--                   BEGIN
--                      SET @nErrNo = @nErrNo
--                      SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'
--                 GOTO Step_9_Fail
--                   END
--              END
--           END
            ---*** INSERT INTO WCSRouting (End) ***---

            /* Relase task if from Step is Step_7. ToteNo Screen  */
            IF @nFromStep = @nStepWithToteNo AND @nFromScn = @nScnWithToteNo
               AND ISNULL(RTRIM(@cToteNo),'') <> ''
            BEGIN
               INSERT INTO TaskManagerSkipTasks
               (
                  USERID,   TaskDetailKey, TaskType, Caseid, Lot,
                  FromLoc,  ToLoc,         FromId,   ToId,   adddate
               )

               SELECT @cUserName, td.TaskDetailKey, td.TaskType, td.Caseid, td.Lot,
                      td.FromLoc, td.ToLoc, td.FromID, td.ToID, GETDATE()
               FROM   TaskDetail td WITH (NOLOCK)
               WHERE  td.DropID = @cToteNo
               AND    td.UserKey = @cUserName
               AND    td.[Status]='3'

               IF EXISTS ( SELECT  1 FROM dbo.TASKDETAIL with (NOLOCK)
                           WHERE DropID = @cToteNo
                           AND   UserKey = @cUserName
                           AND   [Status]='3' )
               BEGIN
                  UPDATE dbo.TASKDETAIL
                      SET UserKey = '', STATUS = '0' , Reasonkey = ''
                        , DropId = ''
                        , ListKey = '' -- SOS# 323841
                  WHERE DropID = @cToteNo
                  AND   UserKey = @cUserName
                  AND   [Status]='3'
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 90069
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                     ROLLBACK TRAN
                     GOTO Step_9_Fail
                  END
               END
            END
         END -- Scanned Qty = 0                   -- (Vicky02) - End
      END

      IF @nScanQTY <> 0
      BEGIN
         BEGIN TRAN
         UPDATE dbo.TaskDetail WITH (ROWLOCK)
         SET Status = @cTaskStatus, -- '9',
             EndTime = GETDATE(),
             EditDate = GETDATE(),
             EditWho = @cUserName,
             TrafficCop = NULL
         WHERE TaskDetailkey = @cTaskdetailkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 90055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
            ROLLBACK TRAN
            GOTO Step_9_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END
      END
      ELSE
      BEGIN -- If ScanQty = 0


         IF @cRemoveUserTask = '0'
         BEGIN
            BEGIN TRAN
            UPDATE dbo.TaskDetail WITH (ROWLOCK)
            SET Status = @cTaskStatus, -- '9',
                --DropId = '',
                UserKey = '', -- (ChewKP02)
                --ReasonKey = '', -- (ChewKP02)
                EndTime = GETDATE(),
                EditDate = GETDATE(),
                EditWho = @cUserName,
                TrafficCop = NULL
            WHERE TaskDetailkey = @cTaskdetailkey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 90055
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN
               GOTO Step_9_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
         END
         ELSE
         BEGIN
               UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET Status = @cTaskStatus, -- '9',
                   --DropId = '',
                   UserKey = '', -- (ChewKP02)
                   ReasonKey = '', -- (ChewKP02)
                   EndTime = GETDATE(),
                   EditDate = GETDATE(),
                   EditWho = @cUserName,
                   TrafficCop = NULL
               WHERE TaskDetailkey = @cTaskdetailkey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 90096
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  ROLLBACK TRAN
                  GOTO Step_9_Fail
               END

               SELECT @b_success = 0
               EXECUTE nspAddSkipTasks
               ''
               , @cUserName
               , @cTaskdetailkey
               , 'PK'
               , ''
               , @cLot
               , @cSuggFromLoc
               , @cSuggID
               , @cSuggToLoc
               , @cSuggID
               , @b_Success OUTPUT
               , @nErrNo    OUTPUT
               , @cErrMsg   OUTPUT

          END
         -- (Vicky02) - Start

         IF ISNULL(@cTaskStorer,'') = ''
         BEGIN
            SELECT TOP 1
                   @cTaskStorer = RTRIM(TD.Storerkey),
                   @cSKU        = RTRIM(TD.SKU),
                   @cSuggID     = RTRIM(TD.FromID),
                   @cSuggToLoc  = RTRIM(TD.ToLOC),
                   @cLot        = RTRIM(TD.Lot),
                   @cSuggFromLoc  = RTRIM(TD.FromLoc),
                   @nSuggQTY    = TD.Qty,
                   @cLoadkey    = RTRIM(LPD.Loadkey),
                   @cOrderkey   = RTRIM(PD.Orderkey),
                   @cWaveKey    = ISNULL(TD.WaveKey,''),
                   @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
            FROM dbo.TaskDetail TD WITH (NOLOCK)
            JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
            JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
            WHERE TD.TaskDetailKey = @cTaskdetailkey

            SELECT @cCurrPutawayzone = Putawayzone
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @cSuggFromLoc
            AND Facility = @cFacility
            SELECT @cFinalPutawayzone = Putawayzone
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @cSuggToLoc
            AND Facility = @cFacility
         END
      END -- If ScanQty = 0
      
      EXEC RDT.rdt_STD_EventLog               
              @cActionType = '3', 
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerKey,
              @cDropID     = @cToteNo,
              @cPickMethod = @cPickMethod,
              @cLocation   = @cFromLoc,
              @cSKU        = @cSKU,
              @cUOM        = @cUOM,
              @nExpectedQty = @nSuggQty,
              @cTaskType   = @cTTMTasktype,
              @cOption     = @cSHTOption,
              @cReasonKey  = @cReasonCode,
              @nStep       = @nStep

      SET @nFromStep = @nStep
      SET @nFromScn  = @nScn

      SET @nScn = 2438
      SET @nStep = 10
      SET @cOutField01 = @cTTMTasktype
      SET @cShortPickFlag = 'N'
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cShortPickFlag = 'Y'
      BEGIN
         SET @nScn = @nScnShortPickCloseTote
         SET @nStep = @nStepShortPickCloseTote
      END
      ELSE
      BEGIN
         SET @nScn = @nFromScn
         SET @nStep = @nFromStep
      END

   END
   GOTO Quit

   Step_9_Fail:
   BEGIN
      SET @cReasonCode = ''

      -- Reset this screen var
      SET @cOutField01 = ''

   END
END -- Step 9
GOTO Quit

/********************************************************************************
Step 10. screen = 2438
     MSG ( EXIT / ENTER )
********************************************************************************/
Step_10:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF (@cPickMethod = 'SINGLES' ) -- OR @cPickMethod = 'PIECE') -- Get Next Task
      BEGIN
         -- GETNEXTTASK_R:
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
          ,  @c_lastloc       = @cSuggToLoc
          ,  @c_lasttasktype  = 'SPK'
          ,  @c_outstring     = @c_outstring    OUTPUT
          ,  @b_Success       = @b_Success      OUTPUT
          ,  @n_err           = @nErrNo         OUTPUT
          ,  @c_errmsg        = @cErrMsg        OUTPUT
          ,  @c_taskdetailkey = @cNextTaskDetailKey OUTPUT
          ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
          ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
          ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
          ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
          ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
          ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

          IF ISNULL(RTRIM(@cNextTaskDetailKey), '') = '' --@nErrNo = 67804 -- Nothing to do!
          BEGIN
              EXEC RDT.rdt_STD_EventLog               
                 @cActionType = '3', 
                 @cUserID     = @cUserName,
                 @nMobileNo   = @nMobile,
                 @nFunctionID = @nFunc,
                 @cFacility   = @cFacility,
                 @cStorerKey  = @cStorerKey,
                 @cDropID     = @cToteNo,
                 @cPickMethod = @cPickMethod,
                 @cLocation   = @cFromLoc,
                 @cSKU        = @cSKU,
                 @cUOM        = @cUOM,
                 @nExpectedQty = @nSuggQty,
                 @cTaskType   = @cTTMTasktype,
                 @cOption     = @cSHTOption,
                 @cReasonKey  = @cReasonCode,
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
              SET @cOutField09 = ''

              -- EventLog - Sign Out Function
              EXEC RDT.rdt_STD_EventLog
                @cActionType = '9', -- Sign Out function
                @cUserID     = @cUserName,
                @nMobileNo   = @nMobile,
                @nFunctionID = @nFunc,
                @cFacility   = @cFacility,
                @cStorerKey  = @cTaskStorer,
                @nStep       = @nStep

            GOTO QUIT
         END

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            SET @cErrMsg = @cErrMsg
            GOTO QUIT
         END

         IF ISNULL(@cNextTaskDetailKey, '') <> ''
         BEGIN
            SELECT TOP 1
                   @cTaskStorer = RTRIM(TD.Storerkey),
                   @cSKU        = RTRIM(TD.SKU),
                   @cSuggID     = RTRIM(TD.FromID),
                   @cSuggToLoc  = RTRIM(TD.ToLOC),
                   @cLot        = RTRIM(TD.Lot),
                   @cSuggFromLoc  = RTRIM(TD.FromLoc),
                   @nSuggQTY    = TD.Qty,
                   @cLoadkey    = RTRIM(LPD.Loadkey),
                   @cOrderkey   = RTRIM(PD.Orderkey),
                   @cRefKey03   = CASE WHEN TD.TaskType = 'PA' THEN TD.CaseID ELSE TD.DropID END,
                   @cRefkey04    = TD.PickMethod,
                   @cPickMethod = TD.PickMethod,
                   @cNewToteNo   = TD.DropID,
                   @cTTMTasktype = TD.TaskType,
                   @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
            FROM dbo.TaskDetail TD WITH (NOLOCK)
            JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
            JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
            WHERE TD.TaskDetailKey = @cNextTaskDetailKey

            SELECT @cCurrPutawayzone = Putawayzone
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @cSuggFromLoc
            AND Facility = @cFacility

            SELECT @cFinalPutawayzone = Putawayzone
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @cSuggToLoc
            AND Facility = @cFacility

            SET @cTaskdetailkey = @cNextTaskDetailKey

            SET @cOutField01 = @cRefKey01
            SET @cOutField02 = @cRefKey02
            SET @cOutField03 = @cRefKey03
            SET @cOutField04 = @cRefKey04
            SET @cOutField05 = @cRefKey05
            SET @cOutField06 = @cTaskdetailkey
            SET @cOutField07 = @cAreaKey
            SET @cOutField08 = @cTTMStrategykey
            SET @cOutField09 = @cTTMTasktype

            BEGIN TRAN

            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
               Starttime = GETDATE(),
               Editdate = GETDATE(),
               EditWho = @cUserName,
               TrafficCOP = NULL
            WHERE TaskDetailKey = @cTaskdetailkey
            AND STATUS <> '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 70196
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN
               GOTO Step_10_Fail
            END

            COMMIT TRAN

            IF @cTTMTasktype <> 'SPK'
            BEGIN
               EXEC RDT.rdt_STD_EventLog               
                 @cActionType = '3', 
                 @cUserID     = @cUserName,
                 @nMobileNo   = @nMobile,
                 @nFunctionID = @nFunc,
                 @cFacility   = @cFacility,
                 @cStorerKey  = @cStorerKey,
                 @cDropID     = @cToteNo,
                 @cPickMethod = @cPickMethod,
                 @cLocation   = @cFromLoc,
                 @cSKU        = @cSKU,
                 @cUOM        = @cUOM,
                 @nExpectedQty = @nSuggQty,
                 @cTaskType   = @cTTMTasktype,
                 @cOption     = @cSHTOption,
                 @cReasonKey  = @cReasonCode,
                 @nStep       = @nStep
              
               SET @nToFunc = 0
               SET @nToScn = 0
               SET @nPrevStep = 0

               SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
               FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
               WHERE TaskType = RTRIM(@cTTMTasktype)

               IF @nFunc = 0
               BEGIN
                  SET @nErrNo = 70238
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
                  GOTO Step_10_Fail
               END

               SELECT TOP 1 @nToScn = Scn
               FROM RDT.RDTScn WITH (NOLOCK)
               WHERE Func = @nToFunc
               ORDER BY Scn

               IF @nToScn = 0
               BEGIN
                  SET @nErrNo = 70239
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
                  GOTO Step_10_Fail
               END

               SET @nScn = @nToScn
               SET @nFunc = @nToFunc
               SET @nStep = 1

--               -- EventLog - Sign Out Function
--               EXEC RDT.rdt_STD_EventLog
--                 @cActionType = '9', -- Sign Out function
--                 @cUserID     = @cUserName,
--                 @nMobileNo   = @nMobile,
--                 @nFunctionID = @nFunc,
--                 @cFacility   = @cFacility,
--                 @cStorerKey  = @cTaskStorer

               GOTO QUIT
            END


            IF (@cPickMethod = 'SINGLES' )
            BEGIN
               SET @nPrevStep = '0'

               SET @cOutField05 = ''
               IF @nFromStep = @nStepReasonCode
               BEGIN
                  -- When Short Pick for SINGLE, it should continue with same tote# if SINGLE Pick Task still available

                  SET @nStep = @nStepFromLoc
                  SET @nScn  = @nScnFromLoc

                  SET @cOutField01 = @cPickMethod
                  SET @cOutField02 = @cToteNo
                  SET @cOutField03 = @cSuggFromLoc
                  SET @cOutField04 = ''
                  SET @cOutField05 = @cTTMTasktype

                  UPDATE dbo.TASKDETAIL WITH (ROWLOCK)
                     SET Dropid = @cToteNo, TrafficCop=NULL
                  WHERE TaskDetailKey = @cTaskdetailkey

               END
               ELSE
               BEGIN
                  SET @cToteNo = ''
                  SET @cNewToteNo = ''

                  -- Got to empty Tote No screen
                  SET @nPrevStep = 0
                  SET @nScn  = @nScnEmptyTote
                  SET @nStep = @nStepEmptyTote

                  -- EventLog - Sign Out Function
                  EXEC RDT.rdt_STD_EventLog
                    @cActionType = '9', -- Sign Out function
                    @cUserID     = @cUserName,
                    @nMobileNo   = @nMobile,
                    @nFunctionID = @nFunc,
                    @cFacility   = @cFacility,
                    @cStorerKey  = @cTaskStorer,
                    @nStep       = @nStep
               END

            END -- (@cPickMethod = 'SINGLES' OR @cPickMethod = 'PIECE')
            ELSE
            BEGIN
               SET @cNewToteNo = ISNULL(@cNewToteNo,'')
               IF ISNULL(RTRIM(@cNewToteNo),'') <> ''
               BEGIN
                  SET @cToteNo  = @cNewToteNo
                  SET @cOutField05 = ''
                  SET @cOutField04 = @cPickMethod
                  SET @cOutField03 = @cToteNo
                  SET @cOutField09 = @cTTMTasktype
                  SET @nScn  = @nScnWithToteNo
                  SET @nStep = @nStepWithToteNo

                  -- EventLog - Sign Out Function
--                  EXEC RDT.rdt_STD_EventLog
--                    @cActionType = '9', -- Sign Out function
--                    @cUserID     = @cUserName,
--                    @nMobileNo   = @nMobile,
--                    @nFunctionID = @nFunc,
--                    @cFacility   = @cFacility,
--                    @cStorerKey  = @cTaskStorer
               END
               ELSE
               BEGIN
                  SET @cOutField01 = @cPickMethod
                  SET @cOutField02 = @cToteNo
                  SET @cOutField03 = @cSuggFromLoc
                  SET @cOutField04 = ''
                  SET @cToteNo = ''
                  SET @cNewToteNo = ''

                  -- Got to empty Tote No screen
                  SET @nPrevStep = 0
                  SET @nScn  = @nScnEmptyTote
                  SET @nStep = @nStepEmptyTote

                  -- EventLog - Sign Out Function
--                  EXEC RDT.rdt_STD_EventLog
--                    @cActionType = '9', -- Sign Out function
--                    @cUserID     = @cUserName,
--                    @nMobileNo   = @nMobile,
--                    @nFunctionID = @nFunc,
--                    @cFacility   = @cFacility,
--                    @cStorerKey  = @cTaskStorer
               END

            END
         END
      END
      ELSE IF @cPickMethod IN ('DOUBLES','MULTIS','PIECE','STOTE','PP')
      BEGIN
         SET @cToteNo = ISNULL(@cToteNo,'')

         -- Get the task within the same area; there is probably more than 1 zone per area
         SELECT TOP 1 @cCurrArea = AD.AREAKEY, @cLocAisle = l.LocAisle
         FROM dbo.TaskDetail td WITH (NOLOCK)
         JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc
         JOIN dbo.AREADETAIL AD (NOLOCK) ON l.PUTAWAYZONE = AD.PUTAWAYZONE
         WHERE td.TaskDetailKey = @cTaskdetailkey
         AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END

         -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first
         IF ISNULL(RTRIM(@cCurrPutawayzone),'') = ''
         BEGIN
            SELECT @cCurrPutawayzone = Putawayzone
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @cFromLoc
              AND Facility = @cFacility
         END

         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                      INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                      INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                      WHERE TD.Wavekey = @cWavekey
                      AND TD.PickMethod = @cPickMethod
                      AND TD.Status = '3'
                      AND TD.TaskDetailkey <> @cTaskDetailkey
                      AND AD.AreaKey = @cCurrArea
                      AND LOC.Facility = @cFacility
                      AND TD.UserKey = @cUserName
                      AND TD.Message02 = 'PREVFULL'
                      AND ISNULL(RTRIM(TD.DropID), '') <> '')
          BEGIN
            -- Get Next TaskKey
            -- Get the task within the same aisle first
            SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
            FROM dbo.TaskDetail TD WITH (NOLOCK)
            INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
            WHERE TD.Wavekey = @cWavekey
            AND TD.PickMethod = @cPickMethod
            AND TD.Status = '3'
            AND TD.TaskDetailkey <> @cTaskDetailkey
            AND LOC.Putawayzone = @cCurrPutawayzone
            AND LOC.Facility = @cFacility
            AND TD.UserKey = @cUserName
            AND TD.Message02 = 'PREVFULL'
            AND ISNULL(RTRIM(TD.DropID), '') <> ''
            AND LOC.LocAisle = @cLocAisle
            ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
            --ORDER BY Loc.LogicalLocation, Loc.Loc

            -- IF same aisle no more task, get the task from same putawayzone but within same area
            IF ISNULL(@cNextTaskDetailKey, '') = ''
            BEGIN
               SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Wavekey = @cWavekey
               AND TD.PickMethod = @cPickMethod
               AND TD.Status = '3'
               AND TD.TaskDetailkey <> @cTaskDetailkey
               AND LOC.Putawayzone = @cCurrPutawayzone
               AND LOC.Facility = @cFacility
               AND TD.UserKey = @cUserName
               AND TD.Message02 = 'PREVFULL'
               AND ISNULL(RTRIM(TD.DropID), '') <> ''
               ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
            END

            -- IF current putawayzone no more task, get the task from different putawayzone but within same area
            IF ISNULL(@cNextTaskDetailKey, '') = ''
            BEGIN
               SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
               WHERE TD.Wavekey = @cWavekey
               AND TD.PickMethod = @cPickMethod
               AND TD.Status = '3'
               AND TD.TaskDetailkey <> @cTaskDetailkey
               AND AD.AreaKey = @cCurrArea
               AND LOC.Facility = @cFacility
               AND TD.UserKey = @cUserName
               AND TD.Message02 = 'PREVFULL'
               AND ISNULL(RTRIM(TD.DropID), '') <> ''
               ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
            END

            SET @cTaskDetailkey = @cNextTaskDetailKey
            SET @cNextTaskDetailKey = ''

            --- GET Variable --
            SET @cNewToteNo = ''

            BEGIN TRAN

            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
               Starttime = GETDATE(),
               Editdate = GETDATE(),
               EditWho = @cUserName,
               TrafficCOP = NULL
            WHERE TaskDetailKey = @cTaskdetailkey
            AND STATUS <> '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 70198
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN
               GOTO Step_10_Fail
            END
              COMMIT TRAN

              SELECT TOP 1
                   @cTaskStorer = RTRIM(TD.Storerkey),
                   @cSKU        = RTRIM(TD.SKU),
                   @cSuggID     = RTRIM(TD.FromID),
                   @cSuggToLoc  = RTRIM(TD.ToLOC),
                   @cLot        = RTRIM(TD.Lot),
                   @cSuggFromLoc  = RTRIM(TD.FromLoc),
                   @nSuggQTY    = TD.Qty,
                   @cLoadkey    = RTRIM(LPD.Loadkey),
                   @cPickMethod = RTRIM(TD.PickMethod),
                   @cOrderkey   = RTRIM(PD.Orderkey),
                   @cWaveKey    = ISNULL(TD.WaveKey,''),
                   @cNewToteNo  = RTRIM(TD.DropID),
                   @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
            FROM dbo.TaskDetail TD WITH (NOLOCK)
            JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
            JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
            WHERE TD.TaskDetailKey = @cTaskdetailkey

            SELECT @cCurrPutawayzone = Putawayzone
            FROM LOC WITH (NOLOCK)
            WHERE LOC = @cSuggFromLoc AND Facility = @cFacility

            -- PrePare Var for Next Screen
            -- Reset Scan Qty to 0

            SET @nScanQty = 0
            SET @cShortPickFlag = 'N'

            SET @cUserPosition = '1'

            SET @nPrevStep = 1

            -- Got to empty Tote No screen
            SET @nFunc = @nFunc

            IF ISNULL(RTRIM(@cToteNo),'') <> ISNULL(RTRIM(@cNewToteNo),'')
            BEGIN
               SET @cToteNo  = @cNewToteNo
               SET @cOutField05 = ''
               SET @cOutField04 = @cPickMethod
               SET @cOutField03 = @cToteNo
               SET @cOutField09 = @cTTMTasktype
               SET @nScn  = @nScnWithToteNo
               SET @nStep = @nStepWithToteNo

               -- EventLog - Sign Out Function
                  EXEC RDT.rdt_STD_EventLog
                    @cActionType = '9', -- Sign Out function
                    @cUserID     = @cUserName,
                    @nMobileNo   = @nMobile,
                    @nFunctionID = @nFunc,
                    @cFacility   = @cFacility,
                    @cStorerKey  = @cTaskStorer,
                    @nStep       = @nStep
            END
            ELSE
            BEGIN
               SET @cOutField01 = @cPickMethod
               SET @cOutField02 = @cToteNo
               SET @cOutField03 = @cSuggFromLoc
               SET @cOutField04 = ''
               SET @cOutField05 = @cTTMTasktype

               SET @nScn = @nScnFromLoc
               SET @nStep = @nStepFromLoc
            END
            GOTO QUIT
          END
          ELSE -- GET RELATED TASK WITHIN SAME ZONE SAME TOTE IN THE SAME ZONE

           IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                        INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                        WHERE TD.Wavekey = @cWavekey
                        AND TD.PickMethod = @cPickMethod
                        AND TD.Status = '3'
                        AND TD.TaskDetailkey <> @cTaskDetailkey
                        AND AD.AreaKey = @cCurrArea
                        AND LOC.Facility = @cFacility
                        AND TD.UserKey = @cUserName
                        AND TD.DropID = @cToteNo)
                        --AND TD.Orderkey = @cOrderkey)
            BEGIN
               -- Get Next TaskKey
               SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Wavekey = @cWavekey
                     AND TD.PickMethod = @cPickMethod
                     AND TD.Status = '3'
                     AND TD.TaskDetailkey <> @cTaskDetailkey
                     AND LOC.Putawayzone = @cCurrPutawayzone
                     AND LOC.Facility = @cFacility
                     AND TD.UserKey = @cUserName
                     AND TD.DropID = @cToteNo
               ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc   

               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                  WHERE TD.Wavekey = @cWavekey
                        AND TD.PickMethod = @cPickMethod
                        AND TD.Status = '3'
                        AND TD.TaskDetailkey <> @cTaskDetailkey
                        AND AD.AreaKey = @cCurrArea
                        AND LOC.Facility = @cFacility
                        AND TD.UserKey = @cUserName
                        AND TD.DropID = @cToteNo
                  ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc   
               END

               SET @cTaskDetailkey = @cNextTaskDetailKey
               SET @cNextTaskDetailKey = ''

               BEGIN TRAN

               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  Starttime = GETDATE(),
                  Editdate = GETDATE(),
                  EditWho = @cUserName,
                  TrafficCOP = NULL
               WHERE TaskDetailKey = @cTaskdetailkey
               AND STATUS <> '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 70199
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  ROLLBACK TRAN
                  GOTO Step_10_Fail
               END

               COMMIT TRAN

               --- GET Variable --
              SELECT TOP 1
                   @cTaskStorer = RTRIM(TD.Storerkey),
                   @cSKU        = RTRIM(TD.SKU),
                   @cSuggID     = RTRIM(TD.FromID),
                   @cSuggToLoc  = RTRIM(TD.ToLOC),
                   @cLot        = RTRIM(TD.Lot),
                   @cSuggFromLoc  = RTRIM(TD.FromLoc),
                   @nSuggQTY    = TD.Qty,
                   @cLoadkey    = RTRIM(LPD.Loadkey),
                   @cPickMethod = RTRIM(TD.PickMethod),
                   @cOrderkey   = RTRIM(PD.Orderkey),
                   @cWaveKey    = ISNULL(TD.WaveKey,''),
                   @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
              FROM dbo.TaskDetail TD WITH (NOLOCK)
              JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
              JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
              WHERE TD.TaskDetailKey = @cTaskdetailkey


               SELECT @cCurrPutawayzone = Putawayzone
               FROM LOC WITH (NOLOCK)
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility

               -- PrePare Var for Next Screen
               -- Reset Scan Qty to 0

               SET @nScanQty = 0
               SET @cShortPickFlag = 'N'
               SET @cUserPosition = '1'

               SET @nPrevStep = 1

               SET @cOutField01 = @cPickMethod
               SET @cOutField02 = @cToteNo
               SET @cOutField03 = @cSuggFromLoc
               SET @cOutField04 = ''
               SET @cOutField05 = @cTTMTasktype


               IF ISNULL(RTRIM(@cToteNo),'') = ''
               BEGIN
                  SET @nScn = @nScnEmptyTote
                  SET @nStep = @nStepEmptyTote

                  -- EventLog - Sign Out Function
--                  EXEC RDT.rdt_STD_EventLog
--                    @cActionType = '9', -- Sign Out function
--                    @cUserID     = @cUserName,
--                    @nMobileNo   = @nMobile,
--                    @nFunctionID = @nFunc,
--                    @cFacility   = @cFacility,
--                    @cStorerKey  = @cTaskStorer

               END
               ELSE
               BEGIN
                  -- There is still Task in Same Zone GOTO Screen 2
                  SET @nScn = @nScnFromLoc
                  SET @nStep = @nStepFromLoc
               END
               GOTO QUIT

            END
            ELSE
            -- GET RELATED TASK WITHIN SAME ZONE
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                        INNER JOIN dbo.AreaDetail AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE
                        WHERE TD.Wavekey = @cWavekey
                        AND TD.PickMethod = @cPickMethod
                        AND TD.Status = '3'
                        AND TD.TaskDetailkey <> @cTaskDetailkey
                        AND AD.AreaKey = @cCurrArea
                        AND LOC.Facility = @cFacility
                        AND TD.UserKey = @cUserName)
            BEGIN
            -- Get Next TaskKey
               SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
               FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Wavekey = @cWavekey
               AND TD.PickMethod = @cPickMethod
                     AND TD.Status = '3'
                     AND TD.TaskDetailkey <> @cTaskDetailkey
                     AND LOC.Putawayzone = @cCurrPutawayzone
                     AND LOC.Facility = @cFacility
                     AND TD.UserKey = @cUserName
               ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc

               IF ISNULL(@cNextTaskDetailKey, '') = ''
               BEGIN
                  SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
                  INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON AD.PUTAWAYZONE = LOC.PUTAWAYZONE
                  WHERE TD.Wavekey = @cWavekey
                        AND TD.PickMethod = @cPickMethod
                        AND TD.Status = '3'
                        AND TD.TaskDetailkey <> @cTaskDetailkey
                        AND AD.AreaKey = @cCurrArea
                        AND LOC.Facility = @cFacility
                        AND TD.UserKey = @cUserName
                  ORDER BY Loc.LocAisle, Loc.LogicalLocation, Loc.Loc
               END

               SET @cTaskDetailkey = @cNextTaskDetailKey
               SET @cNextTaskDetailKey = ''

               BEGIN TRAN

               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  Starttime = GETDATE(),
                  Editdate = GETDATE(),
                  EditWho = @cUserName,
                  TrafficCOP = NULL
               WHERE TaskDetailKey = @cTaskdetailkey
               AND STATUS <> '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 70200
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  ROLLBACK TRAN
                  GOTO Step_10_Fail
               END

               COMMIT TRAN

               --- GET Variable --
              SELECT TOP 1
                   @cTaskStorer = RTRIM(TD.Storerkey),
                   @cSKU        = RTRIM(TD.SKU),
                   @cSuggID     = RTRIM(TD.FromID),
                   @cSuggToLoc  = RTRIM(TD.ToLOC),
                   @cLot        = RTRIM(TD.Lot),
                   @cSuggFromLoc  = RTRIM(TD.FromLoc),
                   @nSuggQTY    = TD.Qty,
                   @cLoadkey    = RTRIM(LPD.Loadkey),
                   @cPickMethod = RTRIM(TD.PickMethod),
                   @cOrderkey   = RTRIM(PD.Orderkey),
                   @cWaveKey    = ISNULL(TD.WaveKey,''),
                   @cToteNo     = RTRIM(TD.DropID),
                   @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
              FROM dbo.TaskDetail TD WITH (NOLOCK)
              JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
              JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
              WHERE TD.TaskDetailKey = @cTaskdetailkey

               SELECT @cCurrPutawayzone = Putawayzone
               FROM LOC WITH (NOLOCK)
               WHERE LOC = @cSuggFromLoc
                 AND Facility = @cFacility


               -- PrePare Var for Next Screen
               -- Reset Scan Qty to 0

               SET @nScanQty = 0
               SET @cShortPickFlag = 'N'
               SET @cUserPosition = '1'

               SET @nPrevStep = 1


               IF ISNULL(RTRIM(@cToteNo),'') = ''
               BEGIN
                  SET @nScn = @nScnEmptyTote
                  SET @nStep = @nStepEmptyTote

                  -- EventLog - Sign Out Function
--                  EXEC RDT.rdt_STD_EventLog
--                    @cActionType = '9', -- Sign Out function
--                    @cUserID     = @cUserName,
--                    @nMobileNo   = @nMobile,
--                    @nFunctionID = @nFunc,
--                    @cFacility   = @cFacility,
--                    @cStorerKey  = @cTaskStorer

               END
               ELSE
               BEGIN
                  -- There is still Task in Same Zone GOTO Screen 2
                  SET @cOutField01 = @cPickMethod
                  SET @cOutField02 = @cToteNo
                  SET @cOutField03 = @cSuggFromLoc
                  SET @cOutField04 = ''
                  SET @cOutField05 = @cTTMTasktype

                  SET @nScn = @nScnFromLoc
                  SET @nStep = @nStepFromLoc
               END

               -- There is still Task in Same Zone GOTO Screen 2
               GOTO QUIT

            END  -- GET RELATED TASK WITHIN SAME ZONE
            ELSE
            BEGIN
               -- No More Task in Same Zone
               -- Update LOCKED Task to Status = '0' and Userkey = '' For PickUp by Next Zone
               BEGIN TRAN
               DECLARE CursorReleaseTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailkey  FROM dbo.TaskDetail TD WITH (NOLOCK)
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
               WHERE TD.Wavekey = @cWavekey
               AND TD.PickMethod = @cPickMethod
               AND TD.Status = '3'
               AND TD.TaskDetailkey <> @cTaskDetailkey
               AND TD.UserKey = @cUserName
               AND LOC.Putawayzone <> @cCurrPutawayzone

               OPEN CursorReleaseTask
               FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  Update dbo.TaskDetail WITH (ROWLOCK)
                  SET Status = '0', UserKey = '' , TrafficCop = NULL -- (Vicky01)
                  WHERE TaskDetailkey = @c_RTaskDetailkey

                  IF @@ERROR <> 0
                  BEGIN
                        SET @nErrNo = 90066
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                        ROLLBACK TRAN
                        GOTO QUIT
                  END

                  FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey
               END                     CLOSE CursorReleaseTask
               DEALLOCATE CursorReleaseTask

               COMMIT TRAN

               -- Reset Scan Qty to 0
               SET @nScanQty = 0
               SET @cShortPickFlag = 'N'
               IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                           WHERE Loadkey = @cLoadkey
                           --AND Orderkey = @cOrderkey
                           --AND Userkey = @cUserName
                           AND PickMethod = @cPickMethod
                           AND DropID = @cToteNo
                           AND Status IN ('0','3')
                           AND TaskDetailkey <> @cTaskDetailkey
                           )
               BEGIN
                  -- Go to Order Fulli by Other Zone Screen

                  IF EXISTS (SELECT 1 FROM dbo.TaskManagerSkipTasks WITH (NOLOCK)
                             WHERE TaskDetailkey = @cTaskDetailkey  )
                  BEGIN
                     -- Go to Tote Close Screen  3887
                     SET @nScn = 3887
                     SET @nStep = 8
                     SET @cOutField01 = ''
                     SET @cOutField02 = @cTTMTasktype
                     GOTO QUIT

                  END
                  ELSE
                  BEGIN

                     SET @nScn = 3885
                     SET @nStep = 6
                     SET @cOutField01 = @cTTMTasktype
                  GOTO QUIT
                  END
            END
               ELSE
               BEGIN
                  -- Go to Tote Close Screen
                  SET @nScn = 3887
                  SET @nStep = 8
                  SET @cOutField01 = ''
                  SET @cOutField02 = @cTTMTasktype
                  GOTO QUIT
               END
               --GOTO GETNEXTTASK_R -- ONLY WHEN THERE IS NO MORE PICKS FOR DOUBLES / MULTIS
            END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                     WHERE Userkey = @cUserName
                     AND Status = '3' )
      BEGIN
       -- Release ALL Task from Users when EXIT TM --
       BEGIN TRAN

       -- Release ALL Task from Users when EXIT TM --
       IF @cPickMethod IN ('PIECE','SINGLES')
       BEGIN
          -- should also update DropID for Close Tote
          UPDATE dbo.TaskDetail WITH (ROWLOCK)
             SET Status = '0' , Userkey = '', DropID = '', Message02 = ''
                ,TrafficCop = NULL
                ,EditDate = GETDATE()
                ,EditWho = SUSER_SNAME()
          WHERE Userkey = @cUserName
          AND Status = '3'
       END
       ELSE
       BEGIN
         IF @cPickMethod IN ('DOUBLES','MULTIS','PP','STOTE')
         BEGIN
            UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET Status = '0' , Userkey = '', DropID = '', Message02 = ''
                  ,ListKey = '' -- SOS# 323841
                  ,TrafficCop = NULL
                  ,EditDate = GETDATE()
                  ,EditWho = SUSER_SNAME()
            WHERE Userkey = @cUserName
            AND Status = '3'
         END
         ELSE
         BEGIN
            UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET Status = '0',
                   Userkey = '',
                   TrafficCop = NULL,
                   EditDate = GETDATE(),
                   EditWho = SUSER_SNAME()
            WHERE Userkey = @cUserName
            AND Status = '3'
         END
       END

       IF @@ERROR <> 0
       BEGIN
             SET @nErrNo = 90080
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
             ROLLBACK TRAN
             GOTO Step_10_Fail
       END
       ELSE
       BEGIN
          COMMIT TRAN
       END
  END

    -- Reset Scan Qty to 0
      SET @nScanQty = 0


   -- Go back to Task Manager Main Screen
      SET @nFunc = 1756
      SET @nScn = 2100
      SET @nStep = 1

     --SET @cErrMsg = 'No More Task'
      SET @cAreaKey = ''

      SET @cOutField01 = ''  -- Area
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''

      SET @nPrevStep = 0

      GOTO QUIT
   END
   GOTO Quit

END  -- Step 10
GOTO Quit

Step_10_Fail:
GOTO Quit

/********************************************************************************
Step 11. screen = 2107 Take Empty Tote
  MSG (Field01, input)
********************************************************************************/
Step_11:
BEGIN
   IF @nInputKey IN (0, 1) -- Either ESC or ENTER
   BEGIN
      EXEC RDT.rdt_STD_EventLog               
              @cActionType = '3', 
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerKey,
              @cDropID     = @cToteNo,
              @cPickMethod = @cPickMethod,
              @cLocation   = @cFromLoc,
              @cSKU        = @cSKU,
              @cUOM        = @cUOM,
              @nExpectedQty = @nSuggQty,
              @cTaskType   = @cTTMTasktype,
              @cOption     = @cSHTOption,
              @cReasonKey  = @cReasonCode,
              @nStep       = @nStep
              
      SET @nToFunc = 0
      SET @nToScn = 0
      SET @nPrevStep = @nStep

      SET @cOutField04 = @cPickMethod
      SET @nScn = 3880 -- Tote No Screen -- (ChewKP01)
      SET @nStep = 1
      SET @cOutField09 = @cTTMTasktype
   END
END -- Step 11
GOTO Quit

/********************************************************************************
Step 12. screen = 2439 Different Tote?
   Option: (Field01, input)
   ENTER = Confirm
   ESC   = Cancel
********************************************************************************/
Step_12:
BEGIN
   IF @nInputKey = 1
   BEGIN
      -- Check if this tote is lock by someone?
      SELECT @cCurrPutawayzone = LOC.PutawayZone
      FROM   TaskDetail td WITH (NOLOCK)
      JOIN   LOC WITH (NOLOCK) ON LOC.LOC = TD.FromLoc
      WHERE  td.TaskDetailKey = @cTaskDetailkey

      SELECT TOP 1 @cCurrArea = AD.AREAKEY
      FROM dbo.TaskDetail td WITH (NOLOCK)
      JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc
      JOIN dbo.PUTAWAYZONE P (NOLOCK) ON L.PUTAWAYZONE = P.PUTAWAYZONE
      JOIN dbo.AREADETAIL AD (NOLOCK) ON P.PUTAWAYZONE = AD.PUTAWAYZONE
      WHERE td.TaskDetailKey = @cTaskdetailkey
         -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first
         AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END

      -- Get Next TaskKey
      SET @cNextTaskDetailKey = ''

      SELECT TOP 1 @cNextTaskDetailKey = TaskDetailkey
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc
      INNER JOIN dbo.PUTAWAYZONE P (NOLOCK) ON LOC.PUTAWAYZONE = P.PUTAWAYZONE
      INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON P.PUTAWAYZONE = AD.PUTAWAYZONE
      WHERE TD.Status IN ('0','3')
        AND TD.TaskDetailkey <> @cTaskDetailkey
        AND AD.AreaKey = @cCurrArea
        AND LOC.Facility = @cFacility
        AND TD.DropID = @cNewToteNo

      IF ISNULL(RTRIM(@cNextTaskDetailKey),'') = ''
      BEGIN
         SET @nErrNo = 90057
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo
         GOTO Step_12_Fail
      END

      IF EXISTS ( SELECT 1 FROM DBO.TASKDETAIL WITH (NOLOCK)
                  WHERE DropID = @cNewToteNo
                  AND Status IN ('0','3')
                  AND   DropID <> ''   )
      BEGIN
       -- Lock All task for This Tote#
       UPDATE dbo.TASKDETAIL
          SET [Status] = '3',
              UserKey = @cUserName,
              StartTime = GETDATE(),
              TrafficCop=NULL,
              ReasonKey = ''
       WHERE DropID = @cNewToteNo
       AND Status IN ('0','3')
       AND   DropID <> ''
       IF @@ERROR <> 0
       BEGIN
          SET @nErrNo = 90040
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
          ROLLBACK TRAN
          GOTO Step_12_Fail
       END
    END

      -- Release Current Locked Task
      IF EXISTS(SELECT 1 FROM dbo.TaskDetail td WITH (NOLOCK)
                WHERE td.UserKey = @cUserName
                AND   td.Status  = '3'
                AND   td.DropID  <> @cNewToteNo)
      BEGIN
         UPDATE dbo.TASKDETAIL
            SET [Status] = '0', UserKey = ''
         WHERE UserKey = @cUserName
         AND   Status  = '3'
         AND   DropID <> @cNewToteNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 90040
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
            ROLLBACK TRAN
            GOTO Step_12_Fail
         END
      END

      EXEC RDT.rdt_STD_EventLog               
              @cActionType = '3', 
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerKey,
              @cDropID     = @cToteNo,
              @cPickMethod = @cPickMethod,
              @cLocation   = @cFromLoc,
              @cSKU        = @cSKU,
              @cUOM        = @cUOM,
              @nExpectedQty = @nSuggQty,
              @cTaskType   = @cTTMTasktype,
              @cOption     = @cSHTOption,
              @cReasonKey  = @cReasonCode,
              @nStep       = @nStep
              
      SET @cTaskDetailkey = @cNextTaskDetailKey
      SET @cNextTaskDetailKey = ''

      --- GET Variable --
      SELECT TOP 1
          @cTaskStorer = RTRIM(TD.Storerkey),
          @cSKU        = RTRIM(TD.SKU),
          @cSuggID     = RTRIM(TD.FromID),
          @cSuggToLoc  = RTRIM(TD.ToLOC),
          @cLot        = RTRIM(TD.Lot),
          @cSuggFromLoc  = RTRIM(TD.FromLoc),
          @nSuggQTY    = TD.Qty,
          @cLoadkey    = RTRIM(LPD.Loadkey),
          @cPickMethod = RTRIM(TD.PickMethod),
          @cOrderkey   = RTRIM(PD.Orderkey),
          @cWaveKey    = ISNULL(TD.WaveKey,''),
          @cPickSlipNo = ISNULL(PD.PickSlipNo,'')
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN PICKDETAIL PD WITH (NOLOCK) ON td.TaskDetailKey = PD.TaskDetailKey
      JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
      WHERE TD.TaskDetailKey = @cTaskdetailkey

      SELECT @cCurrPutawayzone = Putawayzone
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @cSuggFromLoc AND Facility = @cFacility

      SET @nScanQty = 0
      SET @cUserPosition = '1'

      SET @cToteNo = @cNewToteNo
      SET @nPrevStep = @nStep
      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cToteNo
      SET @cOutField03 = @cSuggFromLoc
      SET @cOutField04 = ''
      SET @cOutField05 = @cTTMTasktype

      -- There is still Task in Same Zone GOTO Screen 2
      SET @nScn = @nScnFromLoc
      SET @nStep = @nStepFromLoc

      SET @nToFunc = 0
      SET @nToScn = 0

      -- EventLog - Sign In Function
--      EXEC RDT.rdt_STD_EventLog
--         @cActionType = '1', -- Sign in function
--         @cUserID     = @cUserName,
--         @nMobileNo   = @nMobile,
--         @nFunctionID = @nFunc,
--         @cFacility   = @cFacility,
--         @cStorerKey  = @cStorerKey

   END

   IF @nInputKey =0 -- Either ESC or ENTER
   BEGIN
      SET @nToFunc = 0
      SET @nToScn = 0
      SET @nPrevStep = @nStep

      SET @cOutField04 = @cPickMethod
      SET @cOutField03 = @cToteNo
      SET @cOutField09 = @cTTMTasktype
      SET @nScn = 2436
      SET @nStep = 7
   END

   Step_12_Fail:
   GOTO QUIT
END -- Step 12
GOTO Quit

/********************************************************************************
Step 13. screen = 2790
   TOTE NO  (Field01)
   SKU      (Field02)
   OPTION   (Field03, input)
********************************************************************************/
Step_13:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField03

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 90087
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_ConfirmTote_Fail
      END

      -- Validate blank
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 90088
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_ConfirmTote_Fail
      END
      
      EXEC RDT.rdt_STD_EventLog               
              @cActionType = '3', 
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerKey,
              @cDropID     = @cToteNo,
              @cPickMethod = @cPickMethod,
              @cLocation   = @cFromLoc,
              @cSKU        = @cSKU,
              @cUOM        = @cUOM,
              @nExpectedQty = @nSuggQty,
              @cTaskType   = @cTTMTasktype,
              @cOption     = @cSHTOption,
              @cReasonKey  = @cReasonCode,
              @nStep       = @nStep

      IF @cOption = '1'
      BEGIN
         SET @nScn = @nFromScn
         SET @nStep = @nFromStep

         SELECT @cModuleName = Message_Text FROM RDT.RDTMSG WITH (NOLOCK) WHERE Message_ID = @nFunc
         SET @cAlertMessage = 'Confirm Tote ' + LTRIM(RTRIM(@cToteNo)) + ' Same As SKU by ' + LTRIM(RTRIM(@cUserName)) + '.'

         -- Insert LOG Alert
         SELECT @bSuccess = 1
         EXECUTE dbo.nspLogAlert
          @c_ModuleName   = @cModuleName,
          @c_AlertMessage = @cAlertMessage,
          @n_Severity     = 0,
          @b_success      = @bSuccess OUTPUT,
          @n_err          = @nErrNo OUTPUT,
          @c_errmsg       = @cErrmsg OUTPUT

         IF NOT @bSuccess = 1
         BEGIN
            GOTO Step_ConfirmTote_Fail
         END

         GOTO Continue_Step_ToTote
      END
      ELSE
      BEGIN
         --prepare next screen variable
         SET @cOutField04 = @cPickMethod
         SET @cOutField05 = ''
         SET @cOutField09 = @cTTMTasktype

         SET @nScn  = @nFromScn
         SET @nStep = @nFromStep
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare next screen variable
      SET @cOutField04 = @cPickMethod
      SET @cOutField05 = ''
      SET @cOutField09 = @cTTMTasktype

      SET @nScn  = @nFromScn
      SET @nStep = @nFromStep
   END
   GOTO Quit

   Step_ConfirmTote_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField03 = ''
   END
END -- Step 13
GOTO Quit

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

       V_SKU         = @cSKU,
       V_LOC         = @cFromloc,
       V_ID          = @cID,
       V_UOM         = @cPUOM,
       --V_QTY         = @nQTY,
       V_Lot         = @cLot,
       V_CaseID      = @cCaseID,
       V_PickSlipNo  = @cPickSlipNo,
       
       V_FromStep    = @nFromStep,
       V_FromScn     = @nFromScn,
      
       V_Integer1    = @nQTY,
       V_Integer2    = @nSuggQTY,
       V_Integer3    = @nPrevStep,
       V_Integer4    = @nScanQty,
       V_Integer5    = @nTotalToteQTY,

       V_String1     = @cToteNo,
       V_String2     = @cPickMethod,
       V_String3     = @cToloc,
       V_String4     = @cReasonCode,
       V_String5     = @cTaskdetailkey,

       V_String6     = @cSuggFromloc,
       V_String7     = @cSuggToloc,
       V_String8     = @cSuggID,
       V_String9     = @cExtendedWCSSP,
       --V_String9     = @nSuggQTY,
       V_String10    = @cUserPosition,
       --V_String11    = @nPrevStep,
       V_String12    = @cNextTaskDetailKey,
       V_String13    = @cPackkey,
       --V_String14    = @nFromStep,
       --V_String15    = @nFromScn,
       V_String16    = @cTaskStorer,
       V_String17    = @cDescr1,
       V_String18    = @cDescr2,
       --V_String19    = @nScanQty,
       V_String20    = @cLoadkey,
       V_String21    = @cTaskDetailKeyPK,
       V_String22    = @cCurrPutawayzone,
       V_String23    = @cFinalPutawayzone,
       V_String24    = @cPPAZone,
       V_String25    = @cUOM,
       V_String26    = @cOrderkey,
       V_STRING27    = @cPrevToteID,
       V_String28    = @cPrepackByBOM,
       --V_String29    = @nTotalToteQTY,
       V_String30    = @cNewToteNo,
       V_String31    = @cShortPickFlag,

       V_String32    =  @cAreakey,
       V_String33    =  @cTTMStrategykey,
       V_String34    =  @cTTMTasktype,
       V_String35    =  @cRefKey01,
       V_String36    =  @cRefKey02,
       V_String37    =  @cRefKey03,
       V_String38    =  @cRefKey04,
       V_String39    =  @cRefKey05,
       V_String40    =  @cWaveKey,

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