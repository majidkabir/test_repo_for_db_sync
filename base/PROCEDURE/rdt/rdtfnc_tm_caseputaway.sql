SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdtfnc_TM_CasePutaway                                    */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: RDT Task Manager - Putaway                                       */
/*          Called By rdtfnc_TaskManager                                     */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-06-17 1.0  ChewKP   SOS#178103 Created                               */
/* 2010-07-20 1.1  ChewKP   Random fixes (ChewKP01)                          */
/* 2010-07-20 1.2  Vicky    Set User Position                                */
/* 2010-07-23 1.3  ChewKP   Add in EventLog (ChewKP02)                       */
/* 2010-07-23 1.4  ChewKP   Add in EndTime , Edtidate , StartTime (ChewKP03) */
/* 2010-07-25 1.5  Shong    Cater Putaway Qty Less then a Carton (Shong01)   */
/* 2010-07-27 1.6  ChewKP   Addition Screen (ChewKP04)                       */
/* 2010-07-27 1.7  Vicky    Refine Code (Vicky01)                            */
/* 2010-07-28 1.8  ChewKP   Fixes on Screen issues (ChewKP05)                */
/* 2010-07-29 1.9  ChewKP   Add EventLog when ReasonCode (ChewKP06)          */
/* 2010-08-19 2.0  Shong    Allow user to overwrite To-loc with reason code  */
/* 2010-08-26 2.1  James    Prompt take empty tote after putaway (james01)   */
/* 2010-09-01 2.2  James    Display retail SKU after open case (james02)     */
/* 2010-09-05 2.3  ChewKP   Insert WCSRouting Delete Record After Putaway    */
/*                          (ChewKP07)                                       */
/* 2010-09-18 2.4  ChewKP   Bug Fixes (ChewKP08)                             */
/* 2010-10-06 2.5  Shong    Filter TaskType = 'PA' (Shong02)                 */
/* 2010-10-18 2.6  TLTING   Set ANSI Standard                                */
/* 2010-11-10 2.7  James    Set ReasonKey = '' when update TaskDetail status */
/*                          to '3' (james03)                                 */
/* 2011-09-02      Leong    SOS# 224844 - Add TraceInfo                      */
/* 2011-05-12 2.8  ChewKP   Begin Tran and Commit Tran issues (ChewKP09)     */
/* 2013-07-19 2.9  SPChin   SOS281579 - Display Qty for Non BOM SKU          */
/* 2014-03-21 3.0  ChewKP   Changes for ANF Project (ChewKP10)               */
/*                          Limit Task reason code                           */
/*                          Change TaskDetail.Status=9 to rdt_Move           */
/* 2014-08-08 3.1  Ung      SOS317842 Fix empty loc to consider PendingMoveIn*/
/* 2014-09-17 3.2  Chee     Bug Fix - Update TaskDetail.Toloc only after     */
/*                          unlocking pendingMoveIn in Confirm (Chee01)      */
/* 2014-12-19 3.3  SPChin   SOS328569 - Set UserKey = '' and ReasonKey = ''  */
/*                                      if Taskdetail status is '0'          */
/* 2015-03-19 3.4  James    SOS336649 - Consider SPK task when exit (james04)*/
/* 2016-09-30 3.5  Ung      Performance tuning                               */   
/* 2018-08-27 3.6  ChewKP   WMS-6052 - Standardize EventLog (ChewKP11)       */
/* 2018-11-15 3.7  TungGH   Performance                                      */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_TM_CasePutaway](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON       -- SQL2005 Standard
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

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
   @cToLoc              NVARCHAR(10),
   @cSuggToLoc          NVARCHAR(10),
   @cTaskdetailkey      NVARCHAR(10),
   @cID                 NVARCHAR(18),
   @cUOM                NVARCHAR(5),   -- Display NVARCHAR(5)
   @cReasonCode         NVARCHAR(10),
   @cSKU                NVARCHAR(20),
   @cTaskStorer         NVARCHAR(15),
   @cFromFacility       NVARCHAR(5),
   @c_outstring         NVARCHAR(255),
   @cUserPosition       NVARCHAR(10),
   --@cPrevTaskdetailkey NVARCHAR(10),
   @cQTY                NVARCHAR(5),
   @cPackkey            NVARCHAR(10),
   @cNextTaskdetailkeyS NVARCHAR(10),

   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),

   @nQTY                INT,
   @nToFunc             INT,
   @nSuggQTY            INT,
   @nPrevStep           INT,
   @nFromStep           INT,
   @nFromScn            INT,
   @nToScn              INT,

   @nOn_HandQty         INT,
   @nTTL_Alloc_Qty      INT,
   @nTaskDetail_Qty     INT,
   @cLoc                NVARCHAR( 10),
   @cDescr              NVARCHAR( 60),

   --@cAltSKU             NVARCHAR( 20),
   @cPUOM               NVARCHAR( 1), -- Prefer UOM
   --@cPUOM_Desc          NVARCHAR( 5),
   --@cMUOM_Desc          NVARCHAR( 5),
   @cSuggestPQTY        NVARCHAR( 5),
   @cSuggestMQTY        NVARCHAR( 5),
   @cActPQTY            NVARCHAR( 5),
   @cActMQTY            NVARCHAR( 5),
   @cPrepackByBOM       NVARCHAR(1),

   @nSum_PalletQty      INT,
   @nActQTY             INT, -- Actual QTY
   @nSuggestPQTY        INT, -- Suggested master QTY
   @nSuggestMQTY        INT, -- Suggested prefered QTY
   @nSuggestQTY         INT, -- Suggetsed QTY
   @cCaseID             NVARCHAR(20),
   @cInCaseID           NVARCHAR(20), -- (ChewKP10)
   @cInSKU              NVARCHAR(20), -- (ChewKP10)
   @cLot                NVARCHAR(10),
   @cComponentSKU       NVARCHAR(20),
   @n_CaseCnt           INT,
   @n_TotalPalletQTY    INT,
   @n_TotalBOMQTY       INT,
   @c_BOMSKU            NVARCHAR(20),
   @c_VirtualLoc        NVARCHAR(10),
   @cDescr1             NVARCHAR( 20),
   @cDescr2             NVARCHAR( 20),
   @c_NewTaskDetailkey  NVARCHAR(10),
   @c_ComponentPackkey  NVARCHAR(10),
   @c_ComponentPackUOM3 NVARCHAR(5),
   @cContinueProcess    NVARCHAR(10),
   @cTaskStatus         NVARCHAR(10),
   @c_FinalPutawayzone  NVARCHAR(10),
   @c_PPAZone           NVARCHAR(10),
   @cCurrPutawayZone    NVARCHAR(10),
   @c_PromptToteMsg     NVARCHAR(1),    --(james01)
   @c_RetailSKU         NVARCHAR(20),   --(james02)
   @cExtendedUpdateSP   NVARCHAR(20),

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
   @nStep = Step,
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
   @cLot             = V_Lot,
   @cCaseID          = V_CaseID,
   
   @nQTY             = V_QTY,

   @cToLoc           = V_String3,
   @cReasonCode      = V_String4,
   @cTaskdetailkey   = V_String5,

   @cSuggToloc       = V_String7,
   @cUserPosition    = V_String10,
   
   @nSuggQTY         = V_Integer1,
   @nPrevStep        = V_Integer2,
   
   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,
      
   @cNextTaskdetailkeyS = V_String12,
   @cPackkey         = V_String13,
   @cTaskStorer      = V_String16,
   @cDescr1          = V_String17,
   @cDescr2          = V_String18,
   @c_FinalPutawayzone = V_String19,
   @c_RetailSKU      = V_String20,
   @cExtendedUpdateSP = V_String21,

   @cPUOM            = V_String27,
   @cPrepackByBOM    = V_String28,

   @cAreakey         = V_String32,
   @cTTMStrategykey  = V_String33,
   @cTTMTasktype     = V_String34,
   @cRefKey01        = V_String35,     -- (james01)
   @cRefKey02        = V_String36,     -- (james01)
   @cRefKey03        = V_String37,
   @cRefKey04        = V_String38,
   @cRefKey05        = V_String39,

   -- (james04)
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

DECLARE @nScn_ReasonCode  INT
       ,@nScn_ToLoc       INT
       ,@nStep_ReasonCode INT
       ,@nStep_ToLoc      INT

SET @nScn_ReasonCode = 2109
SET @nScn_ToLoc      = 2452
SET @nStep_ReasonCode = 5
SET @nStep_ToLoc      = 3

-- Redirect to respective screen
IF @nFunc = 1762
BEGIN
   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1762, Scn = 2450 -- CASEID
   IF @nStep = 2 GOTO Step_2   -- Scn = 2451   SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 2452   ToLoc
   IF @nStep = 4 GOTO Step_4   -- Scn = 2453   Msg
   IF @nStep = 5 GOTO Step_5   -- Scn = 2109   REASON Screen
   IF @nStep = 6 GOTO Step_6   -- Scn = 2454   Msg (Enter / Exit)
   IF @nStep = 7 GOTO Step_7   -- Scn = 2107   Take empty tote -- (james01)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 1. Called from Task Manager Main Screen (func = 1762)
    Screen = 2450
    CASEID (Field03)
    CASEID (Field04, input)
********************************************************************************/
Step_1:
BEGIN
   -- Set all variable for 1st record - records are from rdtfnc_TaskManager
   IF @nPrevStep = 0
   BEGIN
      SET @cTaskdetailkey = @cOutField06
      SET @cAreaKey = @cOutField07
      SET @cTTMStrategykey = @cOutField08

      SET @cCaseID = @cOutField03

      IF ISNULL(RTRIM(@cCaseID),'') = ''
      BEGIN
         SELECT @cCaseID =CASEID
         FROM   TaskDetail WITH (NOLOCK)
         WHERE  TaskDetailKey = @cTaskdetailkey
         AND    TaskType = 'PA' -- (Shong02)
         AND    Status = '0' -- SOS# 224844
      END

      -- Get storer config
      SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
   END

   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cUserPosition = '1'    -- (james01)
      SET @cFieldAttr01 = '' -- (james04)
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

      SET @cInCaseID = ISNULL(@cInField04,'')

      SET @nPrevStep = 1 -- (ChewKP01)

      IF @cInCaseID = ''
      BEGIN
         SET @nErrNo = 70216
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CASEID req
         GOTO Step_1_Fail
      END

     IF @cCaseID <> @cInCaseID
     BEGIN
       IF EXISTS (
              SELECT 1
              FROM   dbo.TaskDetail (NOLOCK)
              WHERE  CASEID = @cInCaseID
              AND    STATUS = '0'
              AND    TaskDetailKEy <> @cTaskdetailkey
              AND    Storerkey = @cStorerKey
              AND    TaskType = 'PA' -- (Shong02)
          )
       BEGIN
           -- IF Found Matching CaseID Putaway this Case ID and Release previous Taskkey to status = '0'
           BEGIN TRAN
           UPDATE dbo.TASKDETAIL WITH (ROWLOCK)
           SET    STATUS = '0'
                 ,Userkey = ''
                 --,EndTime = GETDATE() --CURRENT_TIMESTAMP -- (Vicky01) -- (ChewKP08)
                 ,StartTime = GETDATE() --CURRENT_TIMESTAMP -- (Vicky01) -- (ChewKP08)
                 ,EditDate = GETDATE()--CURRENT_TIMESTAMP -- (Vicky01)
                 ,EditWho = @cUserName -- (ChewKP03)
                 ,TrafficCop = NULL
           WHERE  Taskdetailkey = @cTaskdetailkey
           IF @@ERROR<>0
           BEGIN
               SET @nErrNo = 70228
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN
               GOTO Step_1_Fail
           END

           SET @c_NewTaskDetailkey = ''
           SELECT @c_NewTaskDetailkey = TaskDetailkey
           FROM   dbo.TaskDetail (NOLOCK)
           WHERE  CaseID = @cInCaseID
           AND    STATUS = '0'
           AND    Storerkey = @cStorerKey
           AND    TaskType = 'PA' -- (Shong02)

           UPDATE dbo.TASKDETAIL WITH (ROWLOCK)
           SET  STATUS = '3'
                 ,Userkey = @cUserName
                 --,EndTime = GETDATE() --CURRENT_TIMESTAMP -- (Vicky01) -- (ChewKP08)
                 ,StartTime = GETDATE() --CURRENT_TIMESTAMP -- (Vicky01) -- (ChewKP08)
                 ,EditDate = GETDATE() --CURRENT_TIMESTAMP -- (Vicky01)
                 ,EditWho = @cUserName -- (ChewKP03)
                 ,ReasonKey = '' -- (james03)
                 ,TrafficCop = NULL
           WHERE  Taskdetailkey = @c_NewTaskDetailkey
           AND    Status = '0'

           IF @@ERROR<>0 OR @@ROWCOUNT <> 1
           BEGIN
               SET @nErrNo = 70229
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdTaskFailed'
               ROLLBACK TRAN
               GOTO Step_1_Fail
           END

   --SOS# 230248 (ang01)
         /*
         INSERT INTO TraceInfo( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5
                              , Col1, Col2, Col3, Col4, Col5 )
         VALUES ( 'rdtfnc_TM_CasePutaway_1', GetDate(), '*3*', @cTaskdetailkey, @cCaseID, @cOutField03, @cInCaseID
                , '' ,'', '', @cUserName, @nMobile)
         */

           SET @cTaskdetailkey = @c_NewTaskDetailkey
           SET @cCaseID = @cInCaseID

           COMMIT TRAN
       END
       ELSE
       BEGIN
          IF EXISTS (SELECT 1 FROM dbo.TaskDetail (NOLOCK)
                    WHERE  CASEID = @cInCaseID
                    AND    STATUS = '9'
                    AND    Storerkey = @cStorerKey
                    AND    TaskDetailKEy <> @cTaskdetailkey
                    AND    TaskType = 'PA')
          BEGIN
             SET @nErrNo = 70246
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --70246^Task Closed
             GOTO Step_1_Fail
          END

          IF EXISTS (SELECT 1 FROM dbo.TaskDetail (NOLOCK)
                    WHERE  CASEID = @cInCaseID
                    AND    TaskDetailKEy <> @cTaskdetailkey
                    AND    STATUS = 'W'
                    AND    Storerkey = @cStorerKey
                    AND    TaskType='PA')
          BEGIN
             SET @nErrNo = 70247
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --70247^PTS Not Done
             GOTO Step_1_Fail
          END

         -- Check if other user taken this task
         DECLARE @cOtherUserName NVARCHAR(18)
         SET @cOtherUserName = ''
         SELECT TOP 1
            @cOtherUserName = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE CaseID = @cInCaseID
            AND TaskDetailKEy <> @cTaskdetailkey
            AND Status = '3'
            AND Storerkey = @cStorerKey
            AND TaskType='PA'
            AND UserKey <> @cUserName
         IF @cOtherUserName <> ''
         BEGIN
            SET @nErrNo = 70250
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LCK:
            SET @cErrMsg = RTRIM( @cErrMsg) + RTRIM( @cOtherUserName)
            GOTO Step_1_Fail
         END
         ELSE
         BEGIN
            SET @nErrNo = 70217
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --CASEID not match
            GOTO Step_1_Fail
         END
       END
     END -- @cCaseID<>@cInCaseID

      SELECT @cTaskStorer = RTRIM(Storerkey)
            ,@cSKU = RTRIM(SKU)
            ,@cID = RTRIM(FromID)
            ,@cSuggToLoc = RTRIM(ToLOC)
            ,@cLot = RTRIM(Lot)
            ,@cFromLoc = RTRIM(FromLoc)
            ,@nSuggQTY = Qty
            ,@c_BOMSKU = RTRIM(Sourcekey)
      FROM   dbo.TaskDetail WITH (NOLOCK)
      WHERE  TaskDetailKey = @cTaskdetailkey

      SELECT @c_FinalPutawayzone = Putawayzone
      FROM   LOC(NOLOCK)
      WHERE  LOC = @cSuggToLoc
      AND    Facility = @cFacility

      -- (ChewKP01)
      -- Update WCSRoutingDetail Status = '1' Indicate Visited --

      SELECT @c_PPAZone = RTRIM(SHORT)
      FROM   dbo.CodeLKup (NOLOCK)
      WHERE  Listname = 'WCSStation'
      AND    Code = @c_FinalPutawayzone

      -- (Vicky01) - Start
      IF ISNULL(RTRIM(@c_PPAZone), '') = ''
      BEGIN
          SET @nErrNo = 70240
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- WcsStnNotSet
          GOTO Step_1_Fail
      END
      -- (Vicky01) - End

   --   BEGIN TRAN

      UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
      SET    STATUS = '9'
      WHERE  ToteNo = @cCaseID
      AND    Zone = @c_PPAZone

      IF @@ERROR<>0
      BEGIN
          SET @nErrNo = 70235
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdWCSFailed'
          GOTO Step_1_Fail
      END

      UPDATE dbo.WCSRouting WITH (ROWLOCK)
      SET Status = '9'
      WHERE  ToteNo = @cCaseID
      AND    Final_Zone = @c_PPAZone

      IF @@ERROR<>0
      BEGIN
          SET @nErrNo = 70248
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdWCSRODetFail'
          GOTO Step_1_Fail
      END

      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
          StartTime = GETDATE()
         ,EditDate = GETDATE()
         ,EditWho = @cUserName
         ,TrafficCop = NULL
      WHERE  TaskDetailkey = @cTaskdetailkey
      IF @@ERROR<>0
      BEGIN
          SET @nErrNo = 70237
          SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdTaskFailed'
          GOTO Step_1_Fail
      END

         -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
           @cActionType='1' -- Sign in function
          ,@cUserID=@cUserName
          ,@nMobileNo=@nMobile
          ,@nFunctionID=@nFunc
          ,@cFacility=@cFacility
          ,@cStorerKey=@cStorerKey
          ,@nStep=@nStep


      --SET @cPrePackByBOM = rdt.RDTGetConfig( @nFunc, 'PrePackByBOM', @cTaskStorer)
      SELECT @cPrePackByBOM = SVALUE
      FROM   dbo.StorerConfig (NOLOCK)
      WHERE  Storerkey = @cStorerKey
      AND    Configkey = 'PrePackByBOM'

      IF @cPrePackByBOM='1'
      BEGIN
          SET @cSKU = @c_BOMSKU

          SELECT @cDescr = DESCR
          FROM   dbo.SKU (NOLOCK)
          WHERE SKU = @c_BOMSKU
          AND    Storerkey = @cTaskStorer
      END
      ELSE
      BEGIN
          SELECT @cDescr = DESCR
          FROM   dbo.SKU (NOLOCK)
          WHERE  SKU = @cSKU
          AND    Storerkey = @cTaskStorer
      END

      -- prepare next screen
      SET @cUserPosition = '1'

      SET @cDescr1 = SUBSTRING(@cDescr ,1 ,20)
      SET @cDescr2 = SUBSTRING(@cDescr ,21 ,20)

      SET @cOutField01 = @cCaseID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cDescr1
      SET @cOutField04 = @cDescr2
      SET @cOutField05 = ''

      SET @nFromScn  = @nScn
      SET @nFromStep = @nStep

      -- Go to next screen
      SET @nScn = @nScn+1
      SET @nStep = @nStep+1
   END

   IF @nInputKey=0 -- ESC
   BEGIN
      -- Go to Reason Code screen
      IF @cUserPosition=''
      BEGIN
         SET @cUserPosition = '1'
      END

      --SET @cOutField09 = @cOutField01
      SET @cOutField01 = ''

      -- Go to Reason Code Screen
      SET @nScn = 2109
      SET @nStep = @nStep+4 -- Step 5
   END

   GOTO Quit

Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cInCaseID = ''

      SET @cOutField01 = @cCaseID -- Suggested FromLOC
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2451
   CASE ID (Field01)
   SKU     (Field02)
   DESCR   (Field03)
   DESCR   (Field04)
   SKU  (Field05, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cFieldAttr01 = '' -- (james04)
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
      SET @cInSKU = ISNULL(@cInField05,'')

      IF @cInSKU = ''
      BEGIN
         SET @nErrNo = 70218
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Req
         GOTO Step_2_Fail
      END



      IF ISNULL(@cInSKU,'') <> ISNULL(@cSKU ,'')
      BEGIN
         SET @nErrNo = 70219
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_2_Fail
      END



      IF @cPrePackByBOM <> '1'
      BEGIN
         SET @nQty = @nSuggQTY
      END
      ELSE
      BEGIN
         SELECT @cComponentSKU = SKU
         FROM dbo.TaskDetail (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailkey

         SELECT @cPackkey = Packkey
         FROM dbo.SKU (NOLOCK)
         WHERE SKU = @cSKU
         AND Storerkey = @cTaskStorer

         SELECT @n_CaseCnt = CaseCnt,
                @cUOM = PackUOM1
         FROM dbo.PACK (NOLOCK)
         WHERE PACKKEY = @cPackkey

         --SELECT @n_TotalBOMQTY = SUM(QTY)           --SOS281579
         SELECT @n_TotalBOMQTY = ISNULL(SUM(QTY), 0)  --SOS281579
         FROM dbo.BILLOFMATERIAL (NOLOCK) -- (ChewKP01)
         WHERE SKU = @cSKU
         AND STORERKEY = @cTaskStorer

         --IF @nSuggQTY < (@n_CaseCnt * @n_TotalBOMQTY)-- (Shong01) Start                                            --SOS281579
         IF (@nSuggQTY < (@n_CaseCnt * @n_TotalBOMQTY)) OR @n_CaseCnt = 0 OR @n_TotalBOMQTY = 0 -- (Shong01) Start   --SOS281579
         BEGIN
            SELECT @cUOM = PACK.PackUOM3
                  ,@cDescr1 = SUBSTRING(SKU.DESCR, 1,  20)
                  ,@cDescr2 = SUBSTRING(SKU.DESCR, 21, 20)
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.Pack PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
            WHERE SKU.StorerKey = @cTaskStorer
             AND  SKU.SKU = @cComponentSKU

            SET @nQty = @nSuggQTY
         END
         ELSE
         BEGIN
            SET @nQTY = @nSuggQTY / (@n_TotalBOMQTY * @n_CaseCnt) -- (Vicky05)
         END
         --  (Shong01)
      END

      SET @cUserPosition = '1'

      -- (james02)
      SELECT @c_RetailSKU = SKU.RetailSKU
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (TD.StorerKey = SKU.StorerKey AND TD.SKU = SKU.SKU)
      WHERE TD.TaskDetailKey = @cTaskdetailkey

      -- prepare next screen
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = CASE WHEN ISNULL(@c_RetailSKU, '') = '' THEN @cSKU ELSE @c_RetailSKU END
      SET @cOutField03 = @cDescr1
      SET @cOutField04 = @cDescr2
      SET @cOutField05 = @cUOM
      SET @cOutField06 = @nQty
      SET @cOutField07 = @cSuggToLoc
      SET @cOutField08 = ''

      --SET @nPrevStep = 0
      
      -- (ChewKP11) 
      EXEC RDT.rdt_STD_EventLog
           @cActionType   = '3',
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerkey,
           @cLocation     = @cFromLoc,
           @cToLocation   = @cToLOC,
           @cCaseID       = @cCaseID,
           @cSKU          = @cSKU,
           @nQty          = @nQty, 
           @cTaskDetailKey = @cTaskdetailkey,
           @nStep         = @nStep

      

      SET @cUserPosition = '1'
      SET @nFromStep = @nStep
      SET @nFromScn  = @nScn

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField03 = @cCaseID
      SET @cOutField04 = ''

      IF @cUserPosition = ''
      BEGIN
         SET @cUserPosition = '1'
      END

      SET @nFromStep = @nStep
      SET @nFromScn  = @nScn

      -- Go to Reason Code Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO QUIT

   Step_2_Fail:
   BEGIN
      --SET @cID = ''

      -- Reset this screen var
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cDescr1
      SET @cOutField04 = @cDescr2
      SET @cOutField05 = @cUOM
      SET @cOutField06 = @nQty
      SET @cOutField07 = @cSuggToLoc
      SET @cOutField08 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2452
   CASE ID (Field01)
   SKU     (Field02)
   DESCR   (Field03)
   DESCR   (Field04)
   UOM     (Field05)
   QTY     (Field06)
   TOLOC   (Field07)
   TOLOC   (Field08, input)
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

      -- Screen mapping
      SET @cToLoc = @cInField08

      IF @cToLoc = ''
      BEGIN
         SET @nErrNo = 70220
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC Req
         GOTO Step_3_Fail
      END

      IF @cToLoc <> @cSuggToLoc
      BEGIN
         -- Do Not allow to put-away to Pick location that already assigned to another SKU
         IF EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)
                   WHERE StorerKey = @cStorerKey
                   AND   sku <> @cSKU
                   AND   LOC = @cToLoc
                   AND   LocationType IN ('PICK', 'CASE'))
         BEGIN
            SET @nErrNo = 70242
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --70242^LocInUse
            GOTO Step_3_Fail
         END
         -- Only allow empty location
         IF EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                   WHERE LOC = @cToLoc
                   AND (Qty > 0 OR PendingMoveIn > 0))
         BEGIN
            SET @nErrNo = 70243
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LocNotEmpty
            GOTO Step_3_Fail
         END

         SELECT @cCurrPutawayZone = PutawayZone
         FROM   LOC WITH (NOLOCK)
         WHERE  LOC = @cSuggToLoc

         IF NOT EXISTS(SELECT 1 FROM LOC WITH (NOLOCK)
                       WHERE LOC = @cToLoc
        AND   PutawayZone = @cCurrPutawayZone  )
         BEGIN
            SET @nErrNo = 70221
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Location
            GOTO Step_3_Fail
         END

         SET @nScn  = @nScn_ReasonCode
         SET @nStep = @nStep_ReasonCode
         SET @nFromStep = @nStep
         SET @nFromScn  = @nScn
         SET @cInField01 = ''
         SET @cOutField01=''

         GOTO QUIT
        --SET @nErrNo = 70221
        --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Location
        --GOTO Step_3_Fail
      END

      CONTINUE_CASE_PUTAWAY:

      EXEC rdt.rdt_TM_CasePutaway_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
         ,@cTaskDetailKey
         ,@cToLoc
         ,@nErrNo         OUTPUT
         ,@cErrMsg        OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      SELECT @c_ComponentPackkey = PACK.Packkey ,
             @c_ComponentPackUOM3 = PackUOM3
      FROM dbo.TaskDetail TD (NOLOCK)
      INNER JOIN dbo.SKU SKU (NOLOCK) ON ( SKU.SKU = TD.SKU AND SKU.Storerkey = TD.Storerkey )
      INNER JOIN dbo.PACK PACK (NOLOCK) ON ( PACK.PACKKEY = SKU.PACKKEY )
      WHERE TD.TaskDetailKey = @cTaskdetailkey

      --BEGIN TRAN
      UPDATE dbo.TaskManagerUser WITH (ROWLOCK)
      SET LastLoc = @cToLOC
      WHERE UserKey = @cUserName

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 70230
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
         --ROLLBACK TRAN
         GOTO Step_3_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      SET @cUserPosition = '1'--'2'    -- (james01)

      -- EventLog - Sign In Function -- (ChewKP02)
--      EXEC RDT.rdt_STD_EventLog
--         @cActionType = '9', -- Sign out function
--         @cUserID     = @cUserName,
--         @nMobileNo   = @nMobile,
--         @nFunctionID = @nFunc,
--         @cFacility   = @cFacility,
--         @cStorerKey  = @cStorerKey,
--         @nStep       = @nStep
      
      -- (ChewKP11) 
      EXEC RDT.rdt_STD_EventLog
           @cActionType   = '3',
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID    = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerkey,
           @cCaseID       = @cCaseID,
           @cLocation     = @cFromLoc,
           @cToLocation   = @cToLOC,
           @cTaskDetailKey = @cTaskdetailkey,
           @cSKU          = @cSKU,
           @nQty          = @nQty, 
           @nStep         = @nStep
   

      SET @nFromStep = @nStep
      SET @nFromScn  = @nScn

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cDescr1
      SET @cOutField04 = @cDescr2
      SET @cOutField05 = ''

      SET @cUserPosition = '1'--'2' -- (james01)

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cToLoc = ''

      -- Reset this screen var
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = CASE WHEN ISNULL(@c_RetailSKU, '') = '' THEN @cSKU ELSE @c_RetailSKU END
      SET @cOutField03 = @cDescr1
      SET @cOutField04 = @cDescr2
      SET @cOutField05 = @cUOM
      SET @cOutField06 = @nQty
      SET @cOutField07 = @cSuggToLoc
      SET @cOutField08 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 4. screen = 2453
     Success Message
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --OR @nInputKey = 0 -- ENTER / ESC  (james01)
   BEGIN
      SET @cFieldAttr01 = '' -- (james04)
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

      --DECLARE @cNextTaskdetailkeyS NVARCHAR(10)

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
       ,  @c_lastloc     = @cSuggToLoc
       ,  @c_lasttasktype  = 'TPA'
       ,  @c_outstring     = @c_outstring    OUTPUT
       ,  @b_Success       = @b_Success      OUTPUT
       ,  @n_err           = @nErrNo         OUTPUT
       ,  @c_errmsg        = @cErrMsg        OUTPUT
       ,  @c_taskdetailkey = @cNextTaskdetailkeyS OUTPUT
       ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
       ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey02      = @cRefKey02     OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

       IF ISNULL(RTRIM(@cNextTaskdetailkeyS), '') = '' --@nErrNo = 67804 -- Nothing to do!
       BEGIN
 -- EventLog - Sign Out Function (james03)
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

           GOTO Step_4_Fail -- (ChewKP01)
       END

       IF ISNULL(@cErrMsg, '') <> ''
       BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_4_Fail
       END


      IF ISNULL(@cNextTaskdetailkeyS, '') <> ''
      BEGIN
         SET @cTaskdetailkey = @cNextTaskdetailkeyS
         SET @cOutField01 = @cRefKey01
         SET @cOutField02 = @cRefKey02
         SET @cOutField03 = @cRefKey03
         SET @cOutField04 = @cRefKey04
         SET @cOutField05 = @cRefKey05
         SET @cOutField06 = @cTaskdetailkey
         SET @cOutField07 = @cAreaKey
         SET @cOutField08 = @cTTMStrategykey
         SET @nPrevStep = '0'
         SET @nInputKey = 3 -- NOT to auto ENTER when it goes to first screen of next task

         -- For tasktype = 'PA' only (james01)
         IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskdetailkey
               AND TaskType = 'PA'
               AND Status = '3'
               AND UserKey = @cUsername)
         BEGIN
            SELECT @cOutField03 = CaseID
            FROM dbo.TaskDetail (NOLOCK)
            WHERE TaskDetailkey = @cTaskdetailkey

            SET @cCaseID = @cOutField03  -- (ChewKP01)
            SET @cOutField04 = ''

            SELECT @cTaskStorer = RTRIM(Storerkey)
                  ,@cSKU = RTRIM(SKU)
                  ,@cID = RTRIM(FromID)
                  ,@cSuggToLoc = RTRIM(ToLOC)
                  ,@cLot = RTRIM(Lot)
                  ,@cFromLoc = RTRIM(FromLoc)
                  ,@nSuggQTY = Qty
                  ,@c_BOMSKU = RTRIM(Sourcekey)
            FROM   dbo.TaskDetail WITH (NOLOCK)
            WHERE  TaskDetailKey = @cTaskdetailkey
         END
      END

      -- (james01)
      SELECT @cRefKey03 = CASE CaseID
         WHEN '' THEN DropID
         ELSE CaseID
         END,
         @cRefkey04 = PickMethod,
         @cRefKey05 = CASE TaskType
         WHEN 'DPK' THEN 'Dynamic Picking  DPK'
         WHEN 'DRP' THEN 'Dynamic Replen   DRP'
         ELSE '' END
      From dbo.TaskDetail (NOLOCK)
      WHERE TaskDetailkey = @cTaskdetailkey
      -- (james01)

      SET @nToFunc = 0
      SET @nToScn = 0
      SET @nPrevStep = 0

      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = RTRIM(@cTTMTasktype)

      IF @nFunc = 0
      BEGIN
         SET @nErrNo = 70222
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
         GOTO Step_4_Fail
      END

      SELECT TOP 1 @nToScn = Scn
      FROM RDT.RDTScn WITH (NOLOCK)
      WHERE Func = @nToFunc
      ORDER BY Scn

      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 70223
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Step_4_Fail
      END

      -- (james01)
      SET @c_PromptToteMsg  = rdt.RDTGetConfig( 0, 'PromptToteMsg', @cStorerKey)

      IF @c_PromptToteMsg = '1'
      BEGIN
         IF @cTTMTasktype IN ('PK', 'SPK') -- Diana Piece Picking  (james04)
         BEGIN
            IF @cRefKey03 = ''
            BEGIN
               --SET @nFunc = @nToFunc
               SET @nScn = 2107
               SET @nStep = 7
            END
            ELSE
            BEGIN
               -- I need to display the dropid & tasktype if this is come from
               -- other zone (james01)
               SET @cOutField03 = @cRefKey03    -- DropID
               SET @cOutField04 = @cRefKey04    -- TaskType
               SET @cOutField05 = ''            -- DropID (Input)

               SET @nFunc = @nToFunc
               SET @nScn = 2436
             SET @nStep = 7
            END
         END
         ELSE
         BEGIN
            SET @nFunc = @nToFunc
            SET @nScn = @nToScn
            SET @nStep = 1
         END
      END
      ELSE
      BEGIN
         SET @nFunc = @nToFunc
         SET @nScn = @nToScn
         SET @nStep = 1
      END
      -- (james01)

      -- (Vicky06) EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      SET @nFromStep = 0
      SET @nFromScn  = 0
--     (james01)
--       SET @nFunc = @nToFunc
--       SET @nScn = @nToScn
--
--       SET @nStep = 1
   END

   IF @nInputKey = 0    --ESC (james01)
   BEGIN
      -- EventLog - Sign Out Function (james03)
      EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerKey,
       @nStep       = @nStep

     SET @nFromStep = 0
     SET @nFromScn  = 0


     -- Go back to Task Manager Main Screen
     SET @nFunc = 1756
     SET @nScn = 2100
     SET @nStep = 1

     SET @cAreaKey = ''
     SET @nPrevStep = '0'
     SET @cCaseID = '' -- (ChewKP01)

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
Step 5. screen = 2109
     REASON CODE  (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReasonCode = @cInField01

      IF @cReasonCode = ''
      BEGIN
        SET @nErrNo = 70224
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req
        GOTO Step_5_Fail
      END

      IF NOT EXISTS( SELECT TOP 1 1
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTTASKRSN'
            AND StorerKey = @cStorerKey
            AND Code = @cTTMTaskType
            AND @cReasonCode IN (UDF01, UDF02, UDF03, UDF04, UDF05))
      BEGIN
        SET @nErrNo = 70249
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Reason
        GOTO Step_5_Fail
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
           ,  @c_fromid        = @cID
           ,  @c_toloc         = @cSuggToloc
           ,  @c_toid          = @cID
           ,  @n_qty           = @nQTY--0 -- (Vicky08)
           ,  @c_packkey       = ''
           ,  @c_uom           = ''
           ,  @c_reasoncode    = @cReasonCode
           ,  @c_outstring     = @c_outstring    OUTPUT
           ,  @b_Success      = @b_Success      OUTPUT
           ,  @n_err           = @nErrNo         OUTPUT
           ,  @c_errmsg        = @cErrMsg        OUTPUT
           ,  @c_userposition  = @cUserPosition

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
        SET @cErrMsg = @cErrMsg
        GOTO Step_5_Fail
      END

      SET @cContinueProcess = ''
      SET @cTaskStatus = ''
      SELECT
         @cContinueProcess = ContinueProcessing,
         @cTaskStatus = TaskStatus
      FROM dbo.TASKMANAGERREASON WITH (NOLOCK)
      WHERE TaskManagerReasonKey = @cReasonCode

      IF ISNULL(@cContinueProcess, '') = '1' AND @nFromStep = @nStep_ReasonCode
         AND @nFromScn = @nScn_ReasonCode
      BEGIN
         -- Update in rdt_TM_CasePutaway_Confirm (Chee01)
--         UPDATE TASKDETAIL WITH (ROWLOCK)
--         SET ToLoc = @cToLoc, TrafficCop = NULL
--         WHERE TaskDetailKey = @cTaskdetailkey

         SET @nStep = @nStep_ToLoc
         SET @nScn  = @nScn_ToLoc
         GOTO CONTINUE_CASE_PUTAWAY
      END

      -- Update task status
      IF @cTaskStatus <> ''
      BEGIN
         UPDATE TaskDetail SET
            Status = @cTaskStatus,
            EndTime = GETDATE(),
            EditDate = GETDATE(),
            EditWho  = @cUserName,
            Trafficcop = NULL
         WHERE TaskDetailKey = @cTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 70251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskFailed
            GOTO Step_5_Fail
         END

         -- Cancel task
         IF @cTaskStatus = 'X'
         BEGIN
            -- Unlock suggested location
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,@cFromLOC
               ,@cID
               ,@cSuggToLoc
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU        = @cSKU
               ,@nPutawayQTY = @nSuggQTY
               ,@cFromLOT    = @cLOT
               ,@cUCCNo      = @cCaseID
            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END
         
         --SOS328569 Start
         IF @cTaskStatus = '0'
         BEGIN
         	UPDATE TASKDETAIL WITH (ROWLOCK)
         	SET USERKEY = '',
         		 REASONKEY = '',
         		 EndTime = GETDATE(),
            	 EditDate = GETDATE(),
                EditWho  = @cUserName,
                Trafficcop = NULL
            WHERE TaskDetailKey = @cTaskDetailKey
            IF @@ERROR <> 0
         	BEGIN
            	SET @nErrNo = 70252
            	SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskFailed
            	GOTO Step_5_Fail
         	END
      	END
         --SOS328569 End
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END
      END

      --(ChewKP06) -- (ChewKP11) 
      EXEC RDT.rdt_STD_EventLog
           @cActionType   = '3',
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerkey,
           @cLocation     = @cFromLoc,
           @cID           = @cID,
           @cTaskDetailKey = @cTaskdetailkey,
           @cToLocation   = @cToLOC,
           @cCaseID       = @cCaseID,
           @cReasonKey    = @cReasonCode,
           @cSKU          = @cSKU,
           @nQty          = @nQty, 
           @nStep         = @nStep

     SET @nFromStep = @nScn
     SET @nFromScn  = @nStep

     SET @nScn = 2454
     SET @nStep = 6

  END

   IF @nInputKey = 0 -- ESC
   BEGIN
       -- go to previous screen
       SET @cOutField03 =  @cCaseID  -- (ChewKP01)
       SET @cOutField04 =  ''  -- (ChewKP01)

       SET @nFromStep = @nScn
       SET @nFromScn  = @nStep

       SET @nScn = 2450
       SET @nStep = 1

     --END
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cReasonCode = ''

      -- Reset this screen var
      SET @cOutField01 = ''

   END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 2434
     MSG ( EXIT / ENTER )
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
    --GETNEXTTASK_R:
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
     ,  @c_lasttasktype  = 'TPA'
     ,  @c_outstring     = @c_outstring    OUTPUT
     ,  @b_Success       = @b_Success      OUTPUT
     ,  @n_err           = @nErrNo         OUTPUT
     ,  @c_errmsg        = @cErrMsg        OUTPUT
     ,  @c_taskdetailkey = @cNextTaskdetailkeyS OUTPUT
     ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
     ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
     ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
     ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
     ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
     ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

     IF ISNULL(RTRIM(@cNextTaskdetailkeyS), '') = '' --@nErrNo = 67804 -- Nothing to do!
     BEGIN
        SET @nFromScn = 0
        SET @nFromStep = 0

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

        SET @nPrevStep = 0

        GOTO QUIT

     END

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO QUIT
      END


      IF ISNULL(@cNextTaskdetailkeyS, '') <> ''
      BEGIN

         SELECT @cRefKey03 = CaseID , @cRefkey04 = PickMethod
         From  dbo.TaskDetail (NOLOCK)
         WHERE TaskDetailkey = @cNextTaskdetailkeyS

         SET @cTaskdetailkey = @cNextTaskdetailkeyS
         SET @cOutField01 = @cRefKey01
         SET @cOutField02 = @cRefKey02
         SET @cOutField03 = @cRefKey03
         SET @cOutField04 = @cRefKey04
         SET @cOutField05 = @cRefKey05
         SET @cOutField06 = @cTaskdetailkey
         SET @cOutField07 = @cAreaKey
         SET @cOutField08 = @cTTMStrategykey
         SET @nPrevStep = '0'

         -- For tasktype = 'PA' only (james01)
         IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailkey
            AND TaskType = 'PA'
            AND Status = '3'
            AND UserKey = @cUsername)
         BEGIN
            SELECT @cOutField03 = CaseID
            FROM dbo.TaskDetail (NOLOCK)
            WHERE TaskDetailkey = @cTaskdetailkey

            SET @cCaseID = @cOutField03  -- (ChewKP01)
            SET @cOutField04 = ''

            SELECT @cTaskStorer = RTRIM(Storerkey)
                  ,@cSKU = RTRIM(SKU)
                  ,@cID = RTRIM(FromID)
                  ,@cSuggToLoc = RTRIM(ToLOC)
                  ,@cLot = RTRIM(Lot)
                  ,@cFromLoc = RTRIM(FromLoc)
                  ,@nSuggQTY = Qty
                  ,@c_BOMSKU = RTRIM(Sourcekey)
            FROM   dbo.TaskDetail WITH (NOLOCK)
            WHERE  TaskDetailKey = @cTaskdetailkey
         END
      END

      -- (james01)
      SELECT @cRefKey03 = CASE CaseID
            WHEN '' THEN DropID
            ELSE CaseID
            END,
            @cRefkey04 = PickMethod,
            @cRefKey05 = CASE TaskType
            WHEN 'DPK' THEN 'Dynamic Picking  DPK'
            WHEN 'DRP' THEN 'Dynamic Replen   DRP'
            ELSE '' END
      From dbo.TaskDetail (NOLOCK)
      WHERE TaskDetailkey = @cTaskdetailkey
      -- (james01)

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
         GOTO QUIT
      END

      SELECT TOP 1 @nToScn = Scn
      FROM RDT.RDTScn WITH (NOLOCK)
      WHERE Func = @nToFunc
      ORDER BY Scn

      IF @nToScn = 0
      BEGIN
     SET @nErrNo = 70239
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO QUIT
      END

      -- (james01)
      SET @c_PromptToteMsg  = rdt.RDTGetConfig( 0, 'PromptToteMsg', @cStorerKey)

      IF @c_PromptToteMsg = '1'
      BEGIN
         IF @cTTMTasktype = 'PK' -- Diana Piece Picking
         BEGIN
            IF @cRefKey03 = ''
            BEGIN
               --SET @nFunc = @nToFunc
               SET @nScn = 2107
               SET @nStep = 7
            END
            ELSE
            BEGIN
               -- I need to display the dropid & tasktype if this is come from
               -- other zone (james01)
               SET @cOutField03 = @cRefKey03    -- DropID
               SET @cOutField04 = @cRefKey04    -- TaskType
               SET @cOutField05 = ''            -- DropID (Input)

               SET @nFunc = @nToFunc
               SET @nScn = 2436
               SET @nStep = 7
            END
         END
         ELSE
         BEGIN
            SET @nFunc = @nToFunc
            SET @nScn = @nToScn
            SET @nStep = 1
         END
      END
      ELSE
      BEGIN
         SET @nFunc = @nToFunc
         SET @nScn = @nToScn
         SET @nStep = 1
      END
      -- (james01)

      -- (ChewKP05)
      SET @nFromScn = 0
      SET @nFromStep = 0

      SET @nPrevStep = 0
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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

        SET @nPrevStep = 0

        GOTO QUIT
   END
   GOTO Quit


END
GOTO Quit

/********************************************************************************
Step 7. screen = 2107
   MSG (Field01, input)
********************************************************************************/
Step_7:  -- ChewKP01
BEGIN
   IF @nInputKey IN (0, 1) -- Either ESC or ENTER
   BEGIN
      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = RTRIM(@cTTMTasktype)

      IF @nFunc = 0
      BEGIN
         SET @nErrNo = 70244
         SET @cErrMsg = rdt.rdtgetmessage( 70244, @cLangCode, 'DSP') --No TaskCode
         GOTO Quit
      END

      SELECT TOP 1 @nToScn = Scn
      FROM RDT.RDTScn WITH (NOLOCK)
      WHERE Func = @nToFunc
      ORDER BY Scn

      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 70245
         SET @cErrMsg = rdt.rdtgetmessage( 70245, @cLangCode, 'DSP') --No Screen
         GOTO Quit
      END

     -- prepare next func variable (This one for those Type that has From LOC as first value in 1st screen)
     SET @cOutField01 = @cRefKey01
     SET @cOutField02 = @cRefKey02
     SET @cOutField03 = @cRefKey03
     SET @cOutField04 = @cRefKey04
     SET @cOutField05 = @cRefKey05
     SET @cOutField06 = @cTaskdetailkey
     SET @cOutField07 = @cAreaKey
     SET @cOutField08 = @cTTMStrategykey
     SET @nInputKey = 3 -- NOT to auto ENTER when it goes to first screen of next task
     SET @nFunc = @nToFunc
     SET @nScn = @nToScn
     SET @nStep = 1
   END
END
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
       V_Lot         = @cLot,
       V_CaseID      = @cCaseID,
       
       V_QTY         = @nQTY,

       V_String3     = @cToloc,
       V_String4     = @cReasonCode,
       V_String5     = @cTaskdetailkey,

       V_String7     = @cSuggToloc,
       V_String10    = @cUserPosition,
       V_String12    = @cNextTaskdetailkeyS,
       --V_String12    = @cPrevTaskdetailkey,
       V_String13    = @cPackkey,
       V_String16    = @cTaskStorer,
       V_String17    = @cDescr1,
       V_String18    = @cDescr2,
       V_String19    = @c_FinalPutawayzone,
       V_String20    = @c_RetailSKU,
       V_String21    = @cExtendedUpdateSP,

       V_Integer1    = @nSuggQTY,
       V_Integer2    = @nPrevStep,
       
       V_FromStep    = @nFromStep,
       V_FromScn     = @nFromScn,
       
       V_STRING27    = @cPUOM,
       V_String28    = @cPrepackByBOM,

       V_String32  = @cAreakey,
       V_String33  = @cTTMStrategykey,
       V_String34  = @cTTMTasktype,
       V_String35  = @cRefKey01,
       V_String36  = @cRefKey02,
       V_String37  = @cRefKey03,
       V_String38  = @cRefKey04,
       V_String39  = @cRefKey05,

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