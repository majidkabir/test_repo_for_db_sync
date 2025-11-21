SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdtfnc_TM_PiecePicking                                   */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: RDT Task Manager - Putaway                                       */  
/*          Called By rdtfnc_TaskManager                                     */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2010-06-17 1.0  ChewKP   SOS#175740 Created                               */  
/* 2010-07-22 1.1  ChewKP   Set UserPosition (ChewKP01)                      */  
/* 2010-07-22 1.2  ChewKP   Change of ESC Screen Flow and WCSRouting Deletion*/  
/*                          (ChewKP02)                                       */  
/* 2010-07-22 1.3  ChewKP   Revised validation of Msg prompting (ChewKP03)   */  
/* 2010-07-23 1.4  ChewKP   Fixed 0 Qty able to Close Tote issues (ChewKP04) */  
/* 2010-07-23 1.5  ChewKP   Random Fixes WCSRouting , Next Task Msg Prompting*/  
/*                          StartTime , EndTime (ChewKP05)                   */  
/* 2010-07-24 1.6  Vicky    - Should update Status = 0 when release task     */  
/*                          - Add validation                                 */  
/*                          (Vicky01)                                        */  
/* 2010-07-27 1.7  ChewKP   Addition Screen (ChewKP06)                       */  
/* 2010-07-27 1.8  ChewKP   PIECE Pick fixes and Task Release Fixes,         */  
/*                          Addtional Validation on Tote Scanning (ChewKP07) */  
/* 2010-07-27 1.9  Vicky    Refine the codes (Vicky02)                       */  
/* 2010-07-28 2.0  ChewKP   Fixes on Screen issues (ChewKP08)                */  
/* 2010-07-29 2.1  Vicky    Bug Fixes (Vicky03)                              */  
/* 2010-07-29 2.2  ChewKP   DropID Deletion when Status = '9' , EventLog for */  
/*                          Confirm Task (ChewKP09)                          */  
/* 2010-08-02 2.3  ChewKP   Random fixes (ChewKP10)                          */  
/* 2010-08-04 2.4  ChewKP   Fix OverPick Issues (ChewKP11)                   */  
/* 2010-08-06 2.5  ChewKP   Fix Exit TM Task still Lock Issues (ChewKP12)    */  
/* 2010-08-14 2.6  Shong    Fix Issues (Shong01)                             */  
/* 2010-08-17 2.7  Shong    Allow user to overwrite tote# suggested by system*/  
/* 2010-08-18 2.8  Vicky    Should prompt error if ToteNo = "0" (Vicky04)    */  
/* 2010-08-20 2.9  Shong    Do not delete routing if short pick (Shong03)    */  
/* 2010-08-27 3.0  Shong    Skip All Task for same tote# if Esc from Tote#   */  
/*                          Screen                                           */  
/* 2010-09-01 3.1  Shong    Check Tote In Use From TaskDetail (Shong04)      */  
/* 2010-09-02 3.2  James    Update StartTime when task just started (james01)*/  
/* 2010-09-03 3.2  Shong    Add ShortPickFlag                                */  
/* 2010-09-03 3.3  ChewKP   Fixes and Enhancement (ChewKP13)                 */  
/* 2010-09-06 3.4  ChewKP   Prevent Trailing space for Tote (ChewKP14)       */  
/* 2010-09-06 3.5  ChewKP   Fix Bug Prevent Re-Used of same Tote when prompt */  
/*                          for new Tote (ChewKP15)                          */  
/* 2010-09-06 3.6  ChewKP   PickMethod =PIECE Task Shall be Retrieve         */  
/*                          differently (ChewKP16)                           */  
/* 2010-09-09 3.7  ChewKP   Update EditDate and Editwho when Update          */  
/*                          WCSrouting (ChewKP17)                            */  
/* 2010-09-13 3.8  Shong    Changin for Stealing Task (Shong05)              */  
/* 2010-09-17 3.9  ChewKP   Implement Logic for Swap Task (ChewKP18)         */  
/* 2010-09-17 4.0  ChewKP   Check TaskManagerSkipTasks displaying screen msg */  
/*                          Especially apply to NT ReasonCode (ChewKP19)     */  
/* 2010-09-20 4.1  ChewKP   Add FromLoc screen for Step 3 (ChewKP20)         */  
/* 2010-09-21 4.2  ChewKP   Change Task Retrieving for PIECE Pick (ChewKP21) */  
/* 2010-09-22 4.3  James    If the orders in tote already CANC/Shipped then  */  
/*                          tote can be released (james02)                   */  
/* 2010-10-10 4.4  James    Get task in same area but diff PA Zone (james03) */  
/* 2010-10-11 4.5  Shong    Allow User to Scan PA CaseID to swap task        */  
/* 2010-10-12 4.6  Shong    Get Next Task Sorting by Logical Loc (SHONG07)   */  
/* 2010-10-16 4.7  TLTING   Status = '9' update traficcop NULL tlting01      */  
/* 2010-10-22 4.8  ChewKP   Fix Issues when Enter Short Pick Scn > ReasonCode*/  
/*                          cannot back to Picking (ChewKP22)                */  
/* 2010-11-10 4.9  James    Set ReasonKey = '' when update TaskDetail Status */  
/*                          to '3' (james04)                                 */  
/* 2010-11-24 5.0  ChewKP   Auto Short Pick, prevent WCSRouting update to QC */  
/*                          when PickMethod = 'PIECE' Control By StoreConfig */  
/*                          "TMAutoShortPick"  SOS#197067(ChewKP23)          */  
/* 2011-02-25 5.1  Leong    SOS# 206805 - Remove extra rdt_STD_EventLog      */  
/* 2011-03-11 5.2  James    Make tasktype display as variable (james05)      */  
/* 2011-04-19 5.3  James    SOS212191 - Extra validation on tote (james06)   */  
/* 2011-05-12 5.4  ChewKP   Begin Tran and Commit Tran issues (ChewKP24)     */  
/* 2011-07-25 5.5  TLTING   Perfromance Tune (tlting01)                      */  
/* 2011-08-03 5.6  James    SOS222682 -  Extra validation on tote (james07)  */  
/* 2012-02-10 5.7  Chee     SOS# 232177 - Add Event Log (Chee01)             */  
/* 2012-04-18 5.8  Leong    SOS# 241911 - Reduce @nScanQty when error occur. */  
/* 2012-07-02 5.9  Leong    SOS# 248996 - Reset DropId in Reason Code screen.*/  
/* 2012-07-18 6.0  James    SOS249832 - Handle Zone in multi area (james10)  */  
/* 2014-06-18 6.1  James    SOS313463 - Cater for additional pickmethod and  */
/*                          1 tote only allow store 1 pickmethod (james11)   */
/*                          Stamp pickslip no inside dropid table            */
/* 2014-09-21 6.2  James    Prevent user scan tote from bulk (james12)       */
/* 2014-10-23 6.3  James    SOS324003 - Clear pending route (james13)        */
/* 2014-12-08 6.4  Leong    SOS# 328018 - Get WCSKey                         */
/* 2014-12-09 6.5  James    SOS326846 - Allow config "TMAutoShortPick" to use*/
/*                          for all tasktype (james15)                       */
/* 2015-04-07 6.6  James    SOS337425-Prompt confirm loc empty scn (james16) */
/* 2016-08-29 6.7  James    SOS375151-Enable bulk picking by config (james17)*/
/* 2016-10-05 6.8  James    Perf tuning                                      */
/* 2017-03-28 6.9  James    WMS1349-Support PPK task type (james18)          */
/* 2018-11-15 7.0  Gan      Performance tuning                               */
/*****************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_TM_PiecePicking](  
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
   @nToScn     INT,  
  
   @nOn_HandQty         INT,  
   @nTTL_Alloc_Qty      INT,  
   @nTaskDetail_Qty     INT,  
   @cLoc                NVARCHAR( 10),  
   @cDescr              NVARCHAR( 60),  
  
   @cPUOM               NVARCHAR( 1), -- Prefer UOM  
   @cSuggestPQTY        NVARCHAR( 5),  
   @cSuggestMQTY        NVARCHAR( 5),  
   @cActPQTY            NVARCHAR( 5),  
   @cActMQTY            NVARCHAR( 5),  
   @cPrepackByBOM       NVARCHAR( 1),  
  
   @nSum_PalletQty      INT,  
   @nActQTY             INT, -- Actual QTY  
   @nSuggestPQTY        INT, -- Suggested master QTY  
   @nSuggestMQTY        INT, -- Suggested prefered QTY  
   @nSuggestQTY         INT, -- Suggetsed QTY  
   @cCaseID             NVARCHAR(10),  
   @cInToteID           NVARCHAR(18),  
   @cInSKU              NVARCHAR(20),  
   @cLot                NVARCHAR(10),  
   @cComponentSKU       NVARCHAR(20),  
   @n_CaseCnt           INT,  
   @n_TotalPalletQTY    INT,  
   @n_TotalBOMQTY       INT,  
   @c_BOMSKU            NVARCHAR(20),  
   @c_VirtualLoc        NVARCHAR(10),  
   @c_PickMethod        NVARCHAR(10),  
   @c_ToteNo            NVARCHAR(18),  
   @cDescr1             NVARCHAR(20),  
   @cDescr2             NVARCHAR(20),  
   @nScanQty            INT,  
   @cSHTOption          NVARCHAR(1),  
   @cLoadkey            NVARCHAR(10),  
   @cContinueProcess    NVARCHAR(10),  
   @c_TaskDetailKeyPK   NVARCHAR(10),  
   @nRemainQty          INT,  
   @c_QCLOC             NVARCHAR(10),  
   @c_CurrPutawayzone   NVARCHAR(10),  
   @c_RTaskDetailkey    NVARCHAR(10),  
   @c_FinalPutawayzone  NVARCHAR(10),  
   @c_PPAZone           NVARCHAR(10),  
   @nTranCount          INT,  
   @cOrderkey           NVARCHAR(10),  
   @nTotalToteQTY       INT, -- (vicky03)  
   @cActionFlag         NVARCHAR(1), -- (shong01)  
   @cNewToteNo          NVARCHAR(18), -- (shong03)  
   @cShortPickFlag      NVARCHAR(1), -- (shong04)  
   @cRemoveTaskFromUserQueue  NVARCHAR(1),  -- (ChewKP13)  
   @c_CurrAREA          NVARCHAR(10),  
   @cPA_AreaKey         NVARCHAR(10),  
   @c_TMAutoShortPick   NVARCHAR(1), -- (ChewKP23)  
   @cAlertMessage       NVARCHAR( 255),       -- (james06)  
   @nStep_ConfirmTote   INT,              -- (james06)  
   @nScn_ConfirmTote    INT,              -- (james06)  
   @cModuleName         NVARCHAR( 45),     -- (james06)  
   @cOption             NVARCHAR( 1),         -- (james06)  
   @bSuccess            INT,              -- (james06)  
   @cDefaultToteLength  NVARCHAR( 1),         -- (james06)  
   @cPickSlipNo         NVARCHAR( 10),    -- (james11)   
   @cInit_Final_Zone    NVARCHAR( 10),    -- (james13)   
   @cFinalWCSZone       NVARCHAR( 10),    -- (james13)   
   @cWCSKey             NVARCHAR( 10),    -- (james13)   
   @cAltLOC             NVARCHAR( 10),    -- (james14)   
   @cSuggAltLoc         NVARCHAR( 10),    -- (james14)   
   @nMQty_TTL           INT,              -- (james14)   
   @cExtendedUpdateSP   NVARCHAR( 20),    -- (james16)   
   @cSQL                NVARCHAR(1000),   -- (james16)   
   @cSQLParam           NVARCHAR(1000),   -- (james16)   

   -- (james17)
   @cInQTY              NVARCHAR( 5),
   @cTaskType2EnableBulkPicking  NVARCHAR( 20),

   -- (james18)
   @c_CurrTaskType      NVARCHAR( 10),

  
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
   
   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,
   
   @nQTY             = V_Integer1,
   @nSuggQTY         = V_Integer2,
   @nPrevStep        = V_Integer3,
   @nScanQty         = V_Integer4,
   @nTotalToteQTY    = V_Integer5,
  
   @c_ToteNo         = V_String1,  
   @c_PickMethod     = V_String2,  
   @cToLoc           = V_String3,  
   @cReasonCode      = V_String4,  
   @cTaskdetailkey   = V_String5,  
  
   @cSuggFromloc     = V_String6,  
   @cSuggToloc       = V_String7,  
   @cSuggID          = V_String8,  
  -- @nSuggQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,  
   @cUserPosition    = V_String10,  
  
  -- @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,  
   @cNextTaskdetailkeyS = V_String12,  
   @cPackkey         = V_String13,  
  -- @nFromStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,  
  -- @nFromScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,  
   @cTaskStorer      = V_String16,  
   @cDescr1          = V_String17,  
   @cDescr2          = V_String18,  
  -- @nScanQty         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19, 5), 0) = 1 THEN LEFT( V_String19, 5) ELSE 0 END,  
   @cLoadkey         = V_String20,  
   @c_TaskDetailKeyPK  = V_String21,  
   @c_CurrPutawayzone  = V_String22,  
   @c_FinalPutawayzone = V_String23,  
   @c_PPAZone          = V_String24,  
   @cUOM               = V_String25,  
   @cOrderkey          = V_String26,  
   @cPUOM            = V_String27,  
   @cPrepackByBOM    = V_String28,  
  -- @nTotalToteQTY    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String29, 5), 0) = 1 THEN LEFT( V_String29, 5) ELSE 0 END, -- (vicky03)  
   @cNewToteNo       = V_String30,  
   @cShortPickFlag   = V_String31,  
  
   @cAreakey         = V_String32,  
   @cTTMStrategykey  = V_String33,  
   @cTTMTasktype     = V_String34,  
   @cRefKey01        = V_String37,  
   @cRefKey02        = V_String38,  
   @cRefKey03        = V_String37,  
   @cRefKey04        = V_String38,  
   @cRefKey05        = V_String39,  
  
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
  
   @cFieldAttr01 = FieldAttr01,    @cFieldAttr02   = FieldAttr02,  
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,  
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
   @cFieldAttr15 =  FieldAttr15  
FROM   RDT.RDTMOBREC (NOLOCK)  
WHERE  Mobile = @nMobile  
  
-- (Shong01)  
DECLARE @nStepShortPickCloseTote INT,  
        @nStepEmptyTote          INT,  
        @nStepFromLoc            INT,  
        @nStepReasonCode         INT,  
        @nStepDiffTote           INT,  
        @nStepWithToteNo         INT,  
        @nStep_AltLOC            INT,  
        @nStep_LOCEmpty          INT,      
        @nScnShortPickCloseTote  INT,  
        @nScnFromLoc             INT,  
        @nScnToteNo              INT,  
        @nScnEmptyTote           INT,  
        @nScnDiffTote            INT,  
        @nScnSKU                 INT,  
        @nScnWithToteNo          INT, 
        @nScn_AltLOC             INT, 
        @nScn_LOCEmpty           INT  

  
  
-- Redirect to respective screen  
IF @nFunc = 1760  
BEGIN  
   SET @nStepShortPickCloseTote = 4  
   SET @nStepFromLoc            = 2  
   SET @nStepWithToteNo         = 7  
   SET @nStepReasonCode         = 9  
   SET @nStepEmptyTote          = 11  
   SET @nStepDiffTote           = 12  
   SET @nStep_ConfirmTote       = 13         -- (james06)  
   SET @nStep_AltLOC            = 14         -- (james14)  
   SET @nStep_LOCEmpty          = 15         -- (james16)  
   SET @nScnToteNo              = 2430  
   SET @nScnEmptyTote           = 2107  
   SET @nScnShortPickCloseTote  = 2433  
   SET @nScnFromLoc             = 2431  
   SET @nScnDiffTote            = 2439  
   SET @nScnSKU                 = 2432  
   SET @nScnWithToteNo          = 2436  
   SET @nScn_ConfirmTote        = 2790       -- (james06)  
   SET @nScn_AltLOC             = 2791       -- (james14)  
   SET @nScn_LOCEmpty           = 2792       -- (james16)  
   
  
   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1760, Scn = 2430 -- TOTE ID ID (NEW TOTE)  
   IF @nStep = 2 GOTO Step_2   -- Scn = 2431   FromLOC  
   IF @nStep = 3 GOTO Step_3   -- Scn = 2432   SKU  
   IF @nStep = 4 GOTO Step_4   -- Scn = 2433   Short Pick / Close Tote  
   IF @nStep = 5 GOTO Step_5   -- Scn = 2434   TOTE CLOSED MSG  
   IF @nStep = 6 GOTO Step_6   -- Scn = 2435   MSG (Need to Pick from Other Zone)  
   IF @nStep = 7 GOTO Step_7   -- Menu. Func = 1760, Scn = 2436 -- TOTE ID ID (TOTE FROM OTHER ZONE)  
   IF @nStep = 8 GOTO Step_8   -- Scn = 2437   No More Task For This Tote MSG  
   IF @nStep = 9 GOTO Step_9   -- Scn = 2109   REASON Screen  
   IF @nStep = 10 GOTO Step_10 -- Scn = 2438   Msg (Enter / Exit) (ChewKP06)  
   IF @nStep = 11 GOTO Step_11 -- Scn = 2107   Take empty tote -- (Shong01)  
   IF @nStep = 12 GOTO Step_12 -- Scn = 2439   Different Tote? -- (Shong03)  
   IF @nStep = 13 GOTO Step_13 -- Scn = 2790   Tote same as SKU? -- (james06)  
   IF @nStep = 14 GOTO Step_14 -- Scn = 2791   ALT LOC   -- (james14)  
   IF @nStep = 15 GOTO Step_15 -- Scn = 2792   LOC EMPTY -- (james16)     
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
      SET @cTaskdetailkey = @cOutField06  
      SET @cAreaKey = @cOutField07  
      SET @cTTMStrategykey = @cOutField08  
      SET @c_PickMethod = @cOutField04  
  
      SET @cNextTaskdetailkeyS = ''  
      SET @cShortPickFlag = 'N'  
      SET @nScanQty = 0  
  
      -- (Shong01)  
      SELECT @cTaskStorer = RTRIM(Storerkey),  
             @cSKU        = RTRIM(SKU),  
             @cSuggID     = RTRIM(FromID),  
             @cSuggToLoc  = RTRIM(ToLOC),  
             @cLot        = RTRIM(Lot),  
             @cSuggFromLoc  = RTRIM(FromLoc),  
             @nSuggQTY    = Qty,  
             @cLoadkey    = RTRIM(Loadkey),  
             @cOrderkey   = RTRIM(Orderkey) -- (ChewKP03)  
      FROM dbo.TaskDetail WITH (NOLOCK)  
      WHERE TaskDetailKey = @cTaskdetailkey  
  
      SELECT @c_CurrPutawayzone = Putawayzone  
      FROM LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggFromLoc  
      AND Facility = @cFacility  
  
      SELECT @c_FinalPutawayzone = Putawayzone  
      FROM LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggToLoc  
      AND Facility = @cFacility  
  
   END  
  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      SET @nScanQty = 0  
      SET @cShortPickFlag = 'N'  
      SET @nTotalToteQTY = 0 -- (vicky03)  
      SET @cNextTaskdetailkeyS = ''  
  
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
  
      IF @cInToteID = ''  
      BEGIN  
         SET @nErrNo = 70016  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTENO Req  
         GOTO Step_1_Fail  
      END  
  
      IF rdt.rdtIsValidQTY( @cInToteID, 1) = 0 --(Vicky04)  
      BEGIN  
         SET @nErrNo = 70056  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo  
         GOTO Step_1_Fail  
      END  
  
      -- (james03)  
      -- Check if it is a PA tote/case  
      IF EXISTS (SELECT 1 FROM dbo.TASKDETAIL WITH (NOLOCK)  
                 WHERE StorerKey = @cTaskStorer  
                 AND TaskType = 'PA'  
                 AND Status IN ('0', '3', 'W')  -- (james12)
               AND CaseID = @cInToteID)  
      BEGIN  
         SET @nErrNo = 70085  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo  
         GOTO Step_1_Fail  
      END  

      -- Check if tote is still in use by DPK/PTS
      IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cTaskStorer
                  AND   CASEID = @cInToteID
                  AND   [Status] IN ('0', '3', '4'))
      BEGIN  
         SET @nErrNo = 70085  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo  
         GOTO Step_1_Fail  
      END  

      -- Check the length of tote no (james06); 0 = No Check  
      SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)  
      IF ISNULL(@cDefaultToteLength, '') = ''  
      BEGIN  
         SET @cDefaultToteLength = '8'  -- make it default to 8 digit if not setup  
      END  
  
      IF @cDefaultToteLength <> '0'  
      BEGIN  
         IF LEN(RTRIM(@cInToteID)) <> @cDefaultToteLength  
         BEGIN  
            SET @nErrNo = 70090  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTENO LEN  
            GOTO Step_1_Fail  
         END  
      END  
  
      -- (james07)  
      IF EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)  
                 WHERE Listname = 'XValidTote'  
                    AND Code = SUBSTRING(RTRIM(@cInToteID), 1, 1))  
      BEGIN  
         SET @nErrNo = 70091  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTE NO  
         GOTO Step_1_Fail  
      END  

      SET @c_ToteNo = @cInToteID  
      -- Make sure user not to scan the SKU Code as Tote# (james06)  
      IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cInToteID)  
      BEGIN  
         SET @cOutField01 = @cInToteID  
         SET @cOutField02 = @cInToteID  
         SET @cOutField03 = ''  
         SET @cOutField09 = @cTTMTasktype  
  
         -- Save current screen no  
         SET @nFromScn = @nScn  
         SET @nFromStep = @nStep  
  
         SET @nScn = @nScn_ConfirmTote  
         SET @nStep = @nStep_ConfirmTote  
  
         GOTO QUIT  
      END  
  
      -- (james06)  
      Continue_Step_ToTote:  
      IF ISNULL(@cInToteID, '') = ''  
         SET @cInToteID = @c_ToteNo  
  
      -- (ChewKP07)  
      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cInToteID And Status < '9' )  
      BEGIN  
         -- Check if every orders inside tote is canc. If exists 1 orders is open/in progress/picked then not allow (james02)  
         IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)  
                    JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey  
                    JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
                    WHERE TD.DropID = @cInToteID  
                    AND O.STATUS NOT IN ('9', 'CANC')  
                    AND O.StorerKey = @cTaskStorer)  
         BEGIN  
            SET @nErrNo = 70076  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Used  
            GOTO Step_1_Fail  
         END  
         ELSE  
         BEGIN  
            -- If every orders in tote is shipped/canc then update them to '9' and release it (james02)  
            BEGIN TRAN  
  
            UPDATE dbo.DropID WITH (ROWLOCK) SET  
               Status = '9'  
            WHERE DropID = @cInToteID  
               AND Status < '9'  
  
            IF @@ERROR <> 0  
            BEGIN  
               ROLLBACK TRAN  
               SET @nErrNo = 70084  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateToteFail  
               GOTO Step_1_Fail  
            END  
            ELSE  
            BEGIN  
               COMMIT TRAN  
            END  

            -- (james13)   
            -- Cancel all route be
            SET @cInit_Final_Zone = ''    
            SET @cFinalWCSZone = ''    

            SELECT TOP 1 
               @cFinalWCSZone = Final_Zone,    
               @cInit_Final_Zone = Initial_Final_Zone    
            FROM dbo.WCSRouting WITH (NOLOCK)    
            WHERE ToteNo = @cInToteID    
            AND ActionFlag = 'I'    
            ORDER BY WCSKey Desc    

            SET @cWCSKey = ''
            EXECUTE nspg_GetKey         
               'WCSKey',         
               10,         
               @cWCSKey   OUTPUT,         
               @bsuccess  OUTPUT,         
               @nErrNo    OUTPUT,         
               @cErrMsg   OUTPUT          

            IF @nErrNo<>0        
            BEGIN        
               SET @nErrNo = 70092
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetWCSKey Fail
               GOTO Step_1_Fail  
            END          

            IF ISNULL(RTRIM(@cWCSKey),'') = '' -- SOS# 328018
            BEGIN
               EXECUTE nspg_GetKey
                  'WCSKey',
                  10,
                  @cWCSKey   OUTPUT,
                  @bsuccess  OUTPUT,
                  @nErrNo    OUTPUT,
                  @cErrMsg   OUTPUT

               IF @nErrNo<>0
               BEGIN
                  SET @nErrNo = 70092
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetWCSKey Fail
                  GOTO Step_1_Fail
               END
            END

            INSERT INTO WCSRouting        
            (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)        
            VALUES        
            ( @cWCSKey, @cInToteID, ISNULL(@cInit_Final_Zone,''), ISNULL(@cFinalWCSZone,''), 'D', @cStorerKey, @cFacility, '', 'PIECEPICK') 
                  
            SELECT @nErrNo = @@ERROR          

            IF @nErrNo<>0        
            BEGIN        
               SET @nErrNo = 70093
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtRouteFail
               GOTO Step_1_Fail  
            END         
                  
            -- Update WCSRouting.Status = '5' When Delete          
            UPDATE WCSRouting WITH (ROWLOCK)        
            SET    STATUS = '5'        
            WHERE  ToteNo = @cInToteID          

            SELECT @nErrNo = @@ERROR          
            IF @nErrNo<>0        
            BEGIN        
               SET @nErrNo = 70094
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdRouteFail
               GOTO Step_1_Fail     
            END         

            EXEC dbo.isp_WMS2WCSRouting  
                 @cWCSKey,  
                 @cStorerKey,  
                 @bSuccess OUTPUT,  
                 @nErrNo  OUTPUT,   
                 @cErrMsg OUTPUT  
           
            IF @nErrNo <> 0   
            BEGIN  
               SET @nErrNo = 70095
               SET @cErrMsg = rdt.rdtgetmessage( 71125, @cLangCode, 'DSP') --CrtWCSRECFail
               GOTO Step_1_Fail  
            END
      
         END  
      END  
  
      -- (Shong04)  
      IF EXISTS ( SELECT 1 FROM dbo.TASKDETAIL WITH (NOLOCK) WHERE DropID = @cInToteID And Status NOT IN ('9','X','3') )  -- (ChewKP15)  
      BEGIN  
         SET @nErrNo = 70076  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Used  
         GOTO Step_1_Fail  
      END  
  
      --(ChewKP09) - start  
      IF EXISTS ( SELECT 1 From dbo.DropID WITH (NOLOCK) Where DropID = @cInToteID And Status = '9' )  
      BEGIN  
         BEGIN TRAN  
         DELETE FROM dbo.DROPIDDETAIL  
         WHERE DropID = @cInToteID  
  
         IF @@ERROR <> 0  
         BEGIN  
            ROLLBACK TRAN  
           SET @nErrNo = 70079  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDIDDetFail  
            GOTO Step_1_Fail  
         END  
  
         DELETE FROM dbo.DROPID  
         WHERE DropID = @cInToteID  
         AND   Status = '9'  
  
         IF @@ERROR <> 0  
         BEGIN  
            ROLLBACK TRAN  
            SET @nErrNo = 70080  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDropIDFail  
            GOTO Step_1_Fail  
         END  
         --ELSE --(ChewKP24)  
         --BEGIN --(ChewKP24)  
            COMMIT TRAN  
         --END --(ChewKP24)  
      END  
      --(ChewKP09) - end  

      SET @c_ToteNo = @cInToteID  
      SELECT @cTaskStorer = RTRIM(Storerkey),  
             @cSKU        = RTRIM(SKU),  
             @cSuggID     = RTRIM(FromID),  
             @cSuggToLoc  = RTRIM(ToLOC),  
             @cLot        = RTRIM(Lot),  
             @cSuggFromLoc  = RTRIM(FromLoc),  
             @nSuggQTY    = Qty,  
             @cLoadkey    = RTRIM(Loadkey),  
             @cOrderkey   = RTRIM(Orderkey) -- (ChewKP03)  
      FROM dbo.TaskDetail WITH (NOLOCK)  
      WHERE TaskDetailKey = @cTaskdetailkey  
  
      SELECT @c_CurrPutawayzone = Putawayzone  
      FROM LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggFromLoc  
      AND Facility = @cFacility  
  
      SELECT @c_FinalPutawayzone = Putawayzone  
      FROM LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggToLoc  
      AND Facility = @cFacility  
  
      -- Stamp pickslip inside dropid table (james11)
      SELECT @cPickSlipNo = PickHeaderKey 
      FROM dbo.PickHeader WITH (NOLOCK) 
      WHERE ExternOrderKey = @cLoadkey
      AND   OrderKey = CASE WHEN ISNULL( OrderKey, '') = '' THEN OrderKey ELSE @cOrderkey END

      IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @c_ToteNo )  
      BEGIN  
         INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )  
         VALUES (@c_ToteNo , '' , @c_PickMethod, '0' , @cLoadkey, @cPickSlipNo)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70053  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
            GOTO Step_1_Fail  
         END  
      END  
  
      --IF @c_PickMethod <> 'PIECE' -- (Shong01)  
      IF CAST(@c_ToteNo AS INT) > 0 -- (Vicky04)  
      BEGIN  
         EXEC [dbo].[nspInsertWCSRouting]  
             @cTaskStorer  
            ,@cFacility  
            ,@c_ToteNo  
            ,'PK'  
            ,'N'  
            ,@cTaskdetailkey  
            ,@cUserName  
            ,0  
            ,@b_Success       OUTPUT  
            ,@nErrNo          OUTPUT  
            ,@cErrMsg         OUTPUT  
  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = @nErrNo  
            SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'  
            GOTO Step_1_Fail  
         END  
      END  
  
      -- Update ToteID to DropID field  
      IF @c_PickMethod LIKE 'SINGLES%'  -- (james11)
      BEGIN  
         BEGIN TRAN BT_002  
  
         Update dbo.TaskDetail WITH (ROWLOCK)  
         SET DropID = @c_ToteNo, Trafficcop = NULL -- (Vicky02)  
         WHERE TaskDetailkey = @cTaskDetailKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70040  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
            ROLLBACK TRAN BT_002  
            GOTO Step_1_Fail  
         END  
  
         COMMIT TRAN BT_002  
      END  
  
      IF @c_PickMethod LIKE 'DOUBLES%' OR    -- (james11)
         @c_PickMethod LIKE 'MULTIS%' OR 
         @c_PickMethod LIKE 'PIECE%'  
      BEGIN  
         BEGIN TRAN BT_003  
         DECLARE curTote CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  
         SELECT TaskDetailkey  
         FROM dbo.TaskDetail TD WITH (NOLOCK)  
         INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
         WHERE TD.Loadkey = @cLoadkey  
         AND TD.PickMethod = @c_PickMethod  
         AND TD.Status = '3'  
         AND TD.UserKey = @cUserName  
         AND TD.DropID = ''  
  
         OPEN curTote  
         FETCH NEXT FROM curTote INTO @c_RTaskDetailkey  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            Update dbo.TaskDetail WITH (ROWLOCK)  
            SET DropID = @c_ToteNo,  
                Trafficcop = NULL -- (Vicky02)  
            WHERE TaskDetailkey = @c_RTaskDetailkey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70041  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
               ROLLBACK TRAN BT_003  
               GOTO Step_1_Fail  
            END  
  
            FETCH NEXT FROM curTote INTO @c_RTaskDetailkey  
         END  
         CLOSE curTote  
         DEALLOCATE curTote  
  
         -- Update WCSRoutingDetail Status = '1' Indicate Visited --  
         SELECT @c_PPAZone = RTRIM(SHORT)  
         FROM dbo.CodeLKup WITH (NOLOCK) -- (Vicky02)  
         WHERE Listname = 'WCSStation' And Code = @c_CurrPutawayzone  
  
         -- (Vicky02) - Start  
         IF ISNULL(RTRIM(@c_PPAZone), '') = ''  
         BEGIN  
            SET @nErrNo = 70077  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WcsStatnNotSet'  
            ROLLBACK TRAN BT_003  -- (ChewKPXX)  
            GOTO Step_1_Fail  
         END  
         -- (Vicky02) - End  
  
         UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)  
         SET Status = '1'  ,  
         EditWho = @cUserName , EditDate = GetDate()  --(ChewKP17)  
         WHERE ToteNo = @c_ToteNo  
         AND Zone = @c_PPAZone  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70049  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
            ROLLBACK TRAN BT_003  
            GOTO Step_1_Fail  
         END  
  
         COMMIT TRAN BT_003  
      END  
  
      -- (ChewKP05) When Get the first Task Update EditDate  
      BEGIN TRAN  
      UPDATE dbo.TaskDetail With (ROWLOCK)  
--      SET EndTime = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
      SET StartTime = GETDATE(), -- (james01)  
          EditDate = GETDATE(),--CURRENT_TIMESTAMP , -- (Vicky02)  
          EditWho = @cUserName,  
          DropID = @c_ToteNo, -- (ChewKP10)  
          Trafficcop = NULL -- (Vicky02)  
      WHERE TaskDetailkey = @cTaskdetailkey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 70062  
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
         @nStep       = @nStep
  
  
      -- prepare next screen  
      SET @cUserPosition = '1'  
  
      SET @nPrevStep = 1  
  
      SET @cOutField01 = @c_PickMethod  
      SET @cOutField02 = @c_ToteNo  
      SET @cOutField03 = @cSuggFromLoc  
      SET @cOutField04 = ''  
      SET @cOutField05 = @cTTMTasktype -- (james05)  
  
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- (ChewKP01)  
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
  
      SET @cOutField04 = @c_PickMethod -- Suggested FromLOC  
      SET @cOutField05 = ''  
      SET @cOutField09 = @cTTMTasktype -- (james05)  
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
      SET @cFromLoc = ISNULL(@cInField04,'')  
  
      IF @cFromLoc = ''  
      BEGIN  
         SET @nErrNo = 70017  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLoc Req  
         GOTO Step_2_Fail  
      END  
  
      IF ISNULL(@cFromLoc,'') <> ISNULL(@cSuggFromLoc ,'')  
      BEGIN  
         SET @nErrNo = 70018  
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
      AND    SKU.Storerkey = @cTaskStorer -- (Vicky02)  
  
      -- prepare next screen  
      SET @nScanQty = 0  
      SET @cShortPickFlag = 'N'  

      SET @cOutField01 = @c_ToteNo  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = @cDescr1  
      SET @cOutField04 = @cDescr2  
      SET @cOutField05 = ''  
      SET @cOutField06 = @cUOM  
      SET @cOutField07 = @nScanQty  
      SET @cOutField08 = @nSuggQTY  
      SET @cOutField09 = @cFromLoc -- (ChewKP20)  
      SET @cOutField10 = @cTTMTasktype  -- (james05)  

      -- (james17)
      SET @cTaskType2EnableBulkPicking = rdt.RDTGetConfig( @nFunc, 'TaskType2EnableBulkPicking', @cTaskStorer)

      IF @cTaskType2EnableBulkPicking = 'ALL' OR 
         @cTaskType2EnableBulkPicking = @cTTMTasktype
      BEGIN
         SET @cOutField11 = 'ENTER QTY:'
         SET @cOutField12 = ''
         SET @cFieldAttr12 = '' -- Enable the qty field
      END
      ELSE
      BEGIN
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         SET @cFieldAttr12 = 'O' -- disable the qty field
      END

      SET @cUserPosition = '1' -- (ChewKP01)  
  
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- (ChewKP01)  
      IF @cUserPosition = ''  
      BEGIN  
         SET @cUserPosition = '1'  
      END  
  
      -- (Shong01)  
  
      -- AND @nScanQty = 0  
      IF (@c_PickMethod LIKE 'DOUBLES%' OR    -- (james11)
          @c_PickMethod LIKE 'MULTIS%' OR 
          @c_PickMethod LIKE 'PIECE%')  
      BEGIN  
         SET @cOutField01 = ''  
         SET @cOutField02 = @cTTMTasktype -- (james05)  
         SET @nFromScn  = @nScn  
         SET @nFromStep = @nStep  
         SET @cShortPickFlag = 'N'  
  
         SET @nScn = @nScnShortPickCloseTote  
         SET @nStep = @nStepShortPickCloseTote  
         GOTO QUIT  
  
      END  
  
      -- After Scanning of ToteNo , always prompt Screen 7 when ESC -- (ChewKP02)  
      SET @cOutField04 = @c_PickMethod  
      SET @cOutField03 = @c_ToteNo  
      SET @cOutField05 = ''  
      SET @cOutField09 = @cTTMTasktype -- (james05)  
  
      -- go to previous screen  
      SET @nScn = @nScn + 5  
      SET @nStep = @nStep + 5  
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      --SET @cID = ''  
  
      -- Reset this screen var  
      SET @cOutField01 = @c_PickMethod  
      SET @cOutField02 = @c_ToteNo  
      SET @cOutField03 = @cSuggFromLoc  
      SET @cOutField04 = ''  
      SET @cOutField05 = @cTTMTasktype -- (james05)  
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
      -- (james17)
      SET @cInQTY = ''
      SET @cInQTY = CASE WHEN @cFieldAttr12 <> 'O' THEN ISNULL(@cInField12,'') ELSE '' END

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
         SET @nErrNo = 70019  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Req  
         GOTO Step_3_Fail  
      END  
  
      IF @cInSKU <> @cSKU  
      BEGIN  
         SET @nErrNo = 70020  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU/UPC  
         GOTO Step_3_Fail  
      END  
  
  
      IF NOT EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) WHERE SKU = @cSKU AND Storerkey = @cTaskStorer)  
      BEGIN  
         SET @nErrNo = 70021  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not Exists  
         GOTO Step_3_Fail  
      END  

      -- Validate QTY (james17)
      IF @cInQTY = '' SET @cInQTY = '0' -- Blank taken as zero

      -- not check for 0 qty as it might be blank from screen
      IF RDT.rdtIsValidQTY( @cInQTY, 0) = 0  
      BEGIN
         SET @nErrNo = 70101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         GOTO Step_3_Fail  
      END

      -- Scanned Qty (V_String19)  
      SET @nScanQty = @nScanQty + CASE WHEN @cInQTY = '0' THEN 1 ELSE CAST( @cInQTY AS INT) END
  
      -- Total Scanned Qty (V_String29)  
      SET @nTotalToteQTY = @nTotalToteQTY + @nScanQty  
      --SET @nScanQty = 1  
  
      -- (ChewKP01)  
      SET @cUserPosition = '1'  
  
      IF @nScanQty = @nSuggQTY  
      BEGIN  
         -- //*** Call Sub-SP rdt_TM_PiecePick_ConfirmTask to  
         -- //*** Create PickingInfo, PickHeader  
         -- //*** Batch Confirm Picking in PickDetail  
         EXECUTE RDT.rdt_TM_PiecePick_ConfirmTask  
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
            @c_ToteNo,  
            @nScanQty, -- (Shong01)  
            '5',  
            @cLangCode,  
            @nSuggQTY,  
            @nErrNo OUTPUT,  
            @cErrMsg OUTPUT,  
            @c_PickMethod  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nScanQty = @nScanQty - 1           -- SOS# 241911  
            SET @nTotalToteQTY = @nTotalToteQTY - 1 -- SOS# 241911  
  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
            GOTO Step_3_Fail  
         END  

         -- Stamp pickslip inside dropid table (james11)
         SELECT @cPickSlipNo = PickHeaderKey 
         FROM dbo.PickHeader WITH (NOLOCK) 
         WHERE ExternOrderKey = @cLoadkey
         AND   OrderKey = CASE WHEN ISNULL( OrderKey, '') = '' THEN OrderKey ELSE @cOrderkey END
      
         -- Insert into DropID and DropID Detail Table (Start) --  
         BEGIN TRAN BT_004  
  
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @c_ToteNo )  
         BEGIN  
            INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )  
            VALUES (@c_ToteNo , '' , @c_PickMethod, '0' , @cLoadkey, @cPickSlipNo)  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70053  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
               ROLLBACK TRAN BT_004  
               GOTO Step_3_Fail  
            END  
         END  
  
         IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DROPID = @c_ToteNo AND ChildID = @cSKU)  
         BEGIN  
            INSERT INTO DROPIDDETAIL ( DropID, ChildID)  
            VALUES (@c_ToteNo, @cSKU )  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70054  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
               ROLLBACK TRAN BT_004  
               GOTO Step_3_Fail  
            END  
         END  
  
         COMMIT TRAN BT_004  
         -- Insert into DropID and DropID Detail Table (End) --  
         
         -- (james16)
         IF rdt.RDTGetConfig( @nFunc, 'PPickPromptLOCEmpty', @cStorerKey) = '1' 
         BEGIN
            -- Check if it is empty loc
            IF EXISTS ( SELECT TOP 1 LOC.LOC
                        FROM LOC WITH (NOLOCK) 
                        LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                        LEFT JOIN SKUxLOC SL WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey AND LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC)
                        WHERE LOC.Facility = @cFacility
                        AND   LOC.LOC = @cFromLoc
                        GROUP BY LOC.LOC
                        HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0
                        AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0)
            BEGIN

               SET @cOutField01 = @cFromLoc
               SET @cOutField02 = ''
               SET @cOutField09 = @c_PickMethod

               -- Remember current screen & step
               SET @nFromStep = @nStep 
               SET @nFromScn = @nScn 

               SET @nScn = @nScn_LOCEmpty 
               SET @nStep = @nStep_LOCEmpty 
               GOTO QUIT  
            END
         END

         -- Retrieve Next Task (If Doubles / Multis Should Retrieve Same Task Within same zone ) -- SINGLES -- MULTIS - DOUBLES -- PIECE  
  
         --    /**************************************/  
         --    /* E-COMM SINGLES  (START)            */  
         --    /* Update WCSRouting                  */  
         --    /* Call TMTM01 for Next Task          */  
         --    /**************************************/  
         IF @c_PickMethod LIKE 'SINGLES%'  -- (james11)
         BEGIN  
            -- Update TaskDetail STatus = '9'  
            BEGIN TRAN  
            Update dbo.TaskDetail WITH (ROWLOCK)  
            SET Status = '9' ,  
                EndTime = GETDATE(),  --CURRENT_TIMESTAMP ,   -- (Vicky02)  
                EditDate = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
                EditWho = @cUserName,  -- (ChewKP05)  
                TrafficCop = NULL            -- tlting01  
            WHERE TaskDetailkey = @cTaskDetailKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70031  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
               ROLLBACK TRAN  
               GOTO Step_3_Fail  
            END  
            BEGIN  
               COMMIT TRAN  
            END  
  
            -- (ChewKP09) -- SOS# 206805  
            --EXEC RDT.rdt_STD_EventLog  
            --     @cActionType   = '3',  
            --     @cUserID       = @cUserName,  
            --     @nMobileNo     = @nMobile,  
            --     @nFunctionID   = @nFunc,  
            --     @cFacility     = @cFacility,  
            --     @cStorerKey    = @cStorerkey,  
            --     @cLocation     = @cFromLoc,  
            --     @nQTY          = @nScanQty,  
            --     @cRefNo1       = @cTaskdetailkey,  
            --     @cRefNo2       = @c_ToteNo  
  
            -- Reset Scan Qty to 0  
            SET @nScanQty = 0  
            SET @cShortPickFlag = 'N'  
  
            -- (vickyxx) - Should get other available task in within the same Zone  
            -- GET RELATED TASK WITHIN SAME ZONE  
--            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
--            INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
--            WHERE TD.Loadkey = @cLoadkey  
--                        AND TD.PickMethod = @c_PickMethod  
--                        AND TD.Status = '0'  
--                        AND TD.TaskDetailkey <> @cTaskDetailkey  
--                        AND LOC.Putawayzone = @c_CurrPutawayzone  
--                        AND LOC.Facility = @cFacility  
--                        AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
--                        AND TD.UserKey = '')  
            -- (james03) Get the task within the same area; there is probably more than 1 zone per area  
            SELECT TOP 1 @c_CurrAREA = AD.AREAKEY, @c_CurrTaskType = td.TaskType  
            FROM dbo.TaskDetail td WITH (NOLOCK)  
            JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc  
            JOIN dbo.AREADETAIL AD (NOLOCK) ON l.PUTAWAYZONE = AD.PUTAWAYZONE  
            WHERE td.TaskDetailKey = @cTaskdetailkey  
               -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first (james10)  
               AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  
                 
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                        INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                        WHERE TD.Loadkey = @cLoadkey  
                           AND TD.PickMethod = @c_PickMethod  
                           AND TD.Status = '0'  
                           AND TD.TaskDetailkey <> @cTaskDetailkey  
                           AND AD.AREAKEY = @c_CurrAREA  
                           AND LOC.Facility = @cFacility  
                           AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
                           AND TD.UserKey = ''
                           AND TD.TaskType = @c_CurrTaskType)  
            BEGIN  
               -- Get Next TaskKey  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               AND TD.Status = '0'  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND LOC.Putawayzone = @c_CurrPutawayzone  
               AND LOC.Facility = @cFacility  
               AND TD.UserKey = ''  
               AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
               AND TD.TaskType = @c_CurrTaskType
               ORDER BY LOC.LogicalLocation ASC, TD.FromLOC  
  
               -- IF current putawayzone no more task, get the task from different putawayzone but within same area  
               IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
               BEGIN  
                  SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                  INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                  WHERE TD.Loadkey = @cLoadkey  
                  AND TD.PickMethod = @c_PickMethod  
                  AND TD.Status = '0'  
                  AND TD.TaskDetailkey <> @cTaskDetailkey  
                  AND AD.AREAKEY = @c_CurrAREA  
                  AND LOC.Facility = @cFacility  
                  AND TD.UserKey = ''  
                  AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
                  AND TD.TaskType = @c_CurrTaskType
                  ORDER BY LOC.LogicalLocation ASC, TD.FromLOC  
               END  
  
               SET @cTaskDetailkey = @cNextTaskdetailkeyS  
               SET @cNextTaskdetailkeyS = ''  
  
               --- GET Variable --  
               SELECT @cTaskStorer = RTRIM(Storerkey),  
                      @cSKU        = RTRIM(SKU),  
                      @cSuggID     = RTRIM(FromID),  
                      @cSuggToLoc  = RTRIM(ToLOC),  
                      @cLot        = RTRIM(Lot),  
                      @cSuggFromLoc = RTRIM(FromLoc),  
                      @nSuggQTY    = Qty,  
                      @cLoadkey    = RTRIM(Loadkey),  
                      @c_PickMethod = RTRIM(PickMethod)  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cTaskdetailkey  
  
               SELECT @c_CurrPutawayzone = Putawayzone  
               FROM LOC WITH (NOLOCK)  
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
  
               BEGIN TRAN  
  
               Update dbo.TaskDetail WITH (ROWLOCK)  
                  SET DropID = @c_ToteNo,  
--                      EndTime = GETDATE(),  
                      StartTime = GETDATE(), -- (james01)  
                      EditDate = GETDATE(),  
                      EditWho = @cUserName,  
                      Trafficcop = NULL,  
                      UserKey = @cUserName,  
                      STATUS = '3',  
                      ReasonKey = '' -- (james04)  
               WHERE TaskDetailkey = @cTaskDetailKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70040  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                  ROLLBACK TRAN  
                  GOTO Step_3_Fail -- (ChewKP10)  
               END  
               ELSE  
               BEGIN  
                  COMMIT TRAN  
               END  
  
               -- PrePare Var for Next Screen  
               -- Reset Scan Qty to 0  
               SET @nScanQty = 0  
               SET @cShortPickFlag = 'N'  
               SET @cUserPosition = '1'  
  
               SET @nPrevStep = 2  
  
               SET @cOutField01 = @c_PickMethod  
               SET @cOutField02 = @c_ToteNo  
               SET @cOutField03 = @cSuggFromLoc  
               SET @cOutField04 = ''  
               SET @cOutField05 = @cTTMTasktype -- (james05)  
  
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
               EditWho = @cUserName , EditDate = GetDate() --  (ChewKP17)  
               WHERE ToteNo = @c_ToteNo  
               AND Zone = @c_FinalPutawayzone  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70049  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
                  ROLLBACK TRAN BT_002  
                  GOTO Step_3_Fail -- (ChewKP10)  
               END  
  
               -- (Vickyxx) - Update should be done only upon close Tote  
               -- Update WCSRoutingDetail Status = '1' Indicate Visited --  
               BEGIN TRAN  
               UPDATE dbo.WCSRouting WITH (ROWLOCK)  
               SET Status = '5'  
               WHERE ToteNo = @c_ToteNo  
               AND Final_Zone = @c_FinalPutawayzone  
               AND Status < '9'  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70028  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
                  ROLLBACK TRAN  
                  GOTO Step_3_Fail  
               END  
               ELSE  
               BEGIN  
                  COMMIT TRAN  
               END  
  
               -- Go to Tote Close Screen  
               SET @nScn = @nScn + 5  
               SET @nStep = @nStep + 5  
               SET @cOutField01 = CASE WHEN ISNULL(@c_ToteNo, '') = '' THEN 'Tote is Closed'  
                                       ELSE RTRIM(@c_ToteNo) + ' is Closed' END  -- (jamesxx)  
               SET @cOutField02 = @cTTMTasktype -- (james05)  
               GOTO QUIT  
            END  
            -- (Vickyxx)  
         END -- ECOMM_SINGLES  
         --    /**************************************/  
         --    /* E-COMM SINGLES / PIECE  (END)      */  
         --    /* Update WCSRouting              */  
         --    /* Call TMTM01 for Next Task          */  
         --    /**************************************/  
  
         --    /***************************************/  
         --    /* E-COMM DOUBLES , MULTIS (START)    */  
         --    /* Update WCSRouting                  */  
         --    /* Call TMTM01 for Next Task          */  
         --    /**************************************/  
         IF @c_PickMethod LIKE 'DOUBLES%' OR -- (james11)
            @c_PickMethod LIKE 'MULTIS%' OR 
            @c_PickMethod LIKE 'PIECE%'  
         BEGIN  
            -- Update TaskDetail STatus = '9'  
            BEGIN TRAN  
            Update dbo.TaskDetail WITH (ROWLOCK)  
            SET Status = '9' ,  
                EndTime = GETDATE(), --CURRENT_TIMESTAMP ,  -- (Vicky02)  
                EditDate = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
                EditWho = @cUserName, -- (ChewKP05)  
                TrafficCop = NULL   -- tlting01  
            WHERE TaskDetailkey = @cTaskDetailKey  
  
            IF @@ERROR <> 0  
            BEGIN  
                SET @nErrNo = 70036  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                  ROLLBACK TRAN  
                  GOTO Step_3_Fail  
            END  
            BEGIN  
               COMMIT TRAN  
            END  
  
            -- GET RELATED TASK WITHIN SAME ZONE  
--            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
--                        INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
--                        WHERE TD.Loadkey = @cLoadkey  
--                        AND TD.PickMethod = @c_PickMethod  
--                        AND TD.Status = '3' -- (vicky03)  
--                        AND TD.TaskDetailkey <> @cTaskDetailkey  
--                        AND LOC.Putawayzone = @c_CurrPutawayzone  
--                        AND LOC.Facility = @cFacility  
--                        AND TD.UserKey = @cUserName)  
  
            -- (james03) Get the task within the same area; there is probably more than 1 zone per area  
            SELECT TOP 1 @c_CurrAREA = AD.AREAKEY, @c_CurrTaskType = td.TaskType
            FROM dbo.TaskDetail td WITH (NOLOCK)  
            JOIN dbo.LOC LOC (NOLOCK) ON td.FromLoc = LOC.Loc  
            JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
            WHERE td.TaskDetailKey = @cTaskdetailkey  
               -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first (james10)  
               AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  
                 
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                        INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                        WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        AND TD.Status = '3' -- (vicky03)  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrAREA  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName
                        AND TD.TaskType = @c_CurrTaskType)  
            BEGIN  
               -- Get Next TaskKey  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               AND TD.Status = '3' -- (vicky03)  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND LOC.Putawayzone = @c_CurrPutawayzone  
               AND LOC.Facility = @cFacility  
               AND TD.UserKey = @cUserName  
               AND TD.TaskType = @c_CurrTaskType
               ORDER BY LOC.LogicalLocation ASC, TD.FromLOC -- (SHONG07)  
               --AND TD.Orderkey = @cOrderkey -- (ChewKP03)  
  
               IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
               BEGIN  
                  SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                  INNER JOIN AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                  WHERE TD.Loadkey = @cLoadkey  
                  AND TD.PickMethod = @c_PickMethod  
                  AND TD.Status = '3' -- (vicky03)  
                  AND TD.TaskDetailkey <> @cTaskDetailkey  
                  AND AD.AreaKey = @c_CurrAREA  
                  AND LOC.Facility = @cFacility  
                  AND TD.UserKey = @cUserName  
                  AND TD.TaskType = @c_CurrTaskType
                  ORDER BY LOC.LogicalLocation ASC, TD.FromLOC -- (SHONG07)  
               END  
  
               SET @cTaskDetailkey = @cNextTaskdetailkeyS  
               SET @cNextTaskdetailkeyS = ''  
  
               BEGIN TRAN  
  
               -- (james01)  
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
                  Starttime = GETDATE(),  
                  Editdate = GETDATE(),  
                  EditWho = @cUserName,  
                  TrafficCOP = NULL -- (jamesxx) performance tuning  
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
  
               --- GET Variable --  
               SELECT @cTaskStorer = RTRIM(Storerkey),  
                      @cSKU        = RTRIM(SKU),  
                      @cSuggID     = RTRIM(FromID),  
                      @cSuggToLoc  = RTRIM(ToLOC),  
                      @cLot        = RTRIM(Lot),  
                      @cSuggFromLoc = RTRIM(FromLoc),  
                      @nSuggQTY    = Qty,  
                      @cLoadkey    = RTRIM(Loadkey),  
                      @c_PickMethod = RTRIM(PickMethod),  
                      @cOrderkey   = RTRIM(Orderkey) -- (ChewKP03)  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cTaskdetailkey  
  
               SELECT @c_CurrPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)  
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
  
  
               -- PrePare Var for Next Screen  
               -- Reset Scan Qty to 0  
  
               SET @nScanQty = 0  
  
               SET @cUserPosition = '1'  
  
               SET @nPrevStep = 1  
  
               SET @cOutField01 = @c_PickMethod  
               SET @cOutField02 = @c_ToteNo  
               SET @cOutField03 = @cSuggFromLoc  
               SET @cOutField04 = ''  
               SET @cOutField05 = @cTTMTasktype -- (james05)  
  
               -- (ChewKP09) -- SOS# 206805  
               -- EXEC RDT.rdt_STD_EventLog  
               --   @cActionType   = '3',  
               --   @cUserID       = @cUserName,  
               --   @nMobileNo     = @nMobile,  
               --   @nFunctionID   = @nFunc,  
               --   @cFacility     = @cFacility,  
               --   @cStorerKey    = @cStorerkey,  
               --   @cLocation     = @cFromLoc,  
               --   @nQTY          = @nScanQty,  
               --   @cRefNo1       = @cTaskdetailkey,  
               --   @cRefNo2       = @c_ToteNo  
  
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
               WHERE TD.Loadkey = @cLoadkey  
                     AND TD.PickMethod = @c_PickMethod  
                     AND TD.Status = '3' -- (vicky03)  
                     AND TD.TaskDetailkey <> @cTaskDetailkey  
                     AND TD.UserKey = @cUserName  
--                     AND LOC.Putawayzone <> @c_CurrPutawayzone -- (vicky03)  
                     AND AD.AreaKey <> @c_CurrAREA  
                     --AND TD.Orderkey = @cOrderkey -- (ChewKP03)  
                     --AND LOC.Putawayzone = @c_CurrPutawayzone  
                     --AND LOC.Facility = @cFacility  
  
               OPEN CursorReleaseTask  
               FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey  
               WHILE @@FETCH_STATUS <> -1  
               BEGIN  
  
                  Update dbo.TaskDetail WITH (ROWLOCK)  
                  SET Status = '0', UserKey = '' ,Trafficcop = NULL -- (Vicky01)  
                  WHERE TaskDetailkey = @c_RTaskDetailkey  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                        SET @nErrNo = 70039  
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
                           WHERE Loadkey = @cLoadkey  
                           --AND Orderkey = @cOrderkey -- (ChewKP03)  
                           --AND Userkey = @cUserName -- (ChewKP05)  
                           AND PickMethod = @c_PickMethod -- (ChewKP05)  
                           AND DropID = @c_ToteNo   -- (ChewKP05)  
                           --AND Status IN ('0','3')  -- (ChewKP05)  
                           AND Status = '0'  -- (vicky03)  
                           AND TaskDetailkey <> @cTaskDetailkey  
                           )  
               BEGIN  
                  -- (ChewKP09) -- SOS# 206805  
                  -- EXEC RDT.rdt_STD_EventLog  
                  --   @cActionType   = '3',  
                  --   @cUserID       = @cUserName,  
                  --   @nMobileNo     = @nMobile,  
                  --   @nFunctionID   = @nFunc,  
                  --   @cFacility     = @cFacility,  
                  --   @cStorerKey    = @cStorerkey,  
                  --   @cLocation     = @cFromLoc,  
                  --   @nQTY          = @nScanQty,  
                  --   @cRefNo1       = @cTaskdetailkey,  
                  --   @cRefNo2       = @c_ToteNo  
  
                  -- Go to Fullfill by Other Picker MSG Screen  
                  SET @cOutField01 = @cTTMTasktype -- (james05)  
                  SET @nScn = @nScn + 3  
                  SET @nStep = @nStep + 3  
                  GOTO QUIT  
               END  
               ELSE  
               BEGIN  
                  -- Update WCSRouting Status = '5'  
                  BEGIN TRAN  
                  UPDATE dbo.WCSRouting WITH (ROWLOCK)  
                  SET Status = '5'  
                  WHERE ToteNo = @c_ToteNo  
                  AND Final_Zone = @c_FinalPutawayzone  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                        SET @nErrNo = 70050  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
                        ROLLBACK TRAN  
                        GOTO Step_3_Fail  
                  END  
                  ELSE  
                  BEGIN  
                     COMMIT TRAN  
                  END  
  
                  -- (ChewKP09) -- SOS# 206805  
                  -- EXEC RDT.rdt_STD_EventLog  
                  --    @cActionType   = '3',  
                  --    @cUserID       = @cUserName,  
                  --    @nMobileNo     = @nMobile,  
                  --    @nFunctionID   = @nFunc,  
                  --    @cFacility     = @cFacility,  
                  --    @cStorerKey    = @cStorerkey,  
                  --    @cLocation     = @cFromLoc,  
                  --    @nQTY          = @nScanQty,  
                  --    @cRefNo1       = @cTaskdetailkey,  
                  --    @cRefNo2       = @c_ToteNo  
  
                  -- Go to Tote Close Screen  -- 2437  
                  SET @nScn = @nScn + 5  
                  SET @nStep = @nStep + 5  
                  SET @cOutField01 = CASE WHEN ISNULL(@c_ToteNo, '') = '' THEN 'Tote is Closed'  
                                          ELSE RTRIM(@c_ToteNo) + ' is Closed' END  -- (jamesxx)  
                  SET @cOutField02 = @cTTMTasktype -- (james05)  
                  GOTO QUIT  
               END  
            END  
         END  
      END  
      ELSE IF @nScanQty < @nSuggQty  -- If @nScanQty < @nSuggQty Continue Loop Current Screen (ChewKP11)  
      BEGIN  
         SET @cOutField01 = @c_ToteNo  
         SET @cOutField02 = @cSKU  
         SET @cOutField03 = @cDescr1  
         SET @cOutField04 = @cDescr2  
         SET @cOutField05 = ''  
         SET @cOutField06 = @cUOM  
         SET @cOutField07 = @nScanQty  
         SET @cOutField08 = @nSuggQTY  
         SET @cOutField09 = @cFromLoc  -- (ChewKP20)  
         SET @cOutField10 = @cTTMTasktype -- (james05)  
        
         -- (james17)
         SET @cTaskType2EnableBulkPicking = rdt.RDTGetConfig( @nFunc, 'TaskType2EnableBulkPicking', @cTaskStorer)

         IF @cTaskType2EnableBulkPicking = 'ALL' OR 
            @cTaskType2EnableBulkPicking = @cTTMTasktype
         BEGIN
            SET @cOutField11 = 'ENTER QTY:'
            SET @cOutField12 = ''
            SET @cFieldAttr12 = '' -- Enable the qty field
         END
         ELSE
         BEGIN
            SET @cOutField11 = ''
            SET @cOutField12 = ''
            SET @cFieldAttr12 = 'O' -- disable the qty field
         END
      
         -- Go to next screen  
         SET @nScn = @nScn  
         SET @nStep = @nStep                   

         GOTO QUIT  
      END  
      ELSE IF @nScanQty > @nSuggQty -- (ChewKP11) Start  
      BEGIN  
         SET @nErrNo = 70079  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OverPickXAllow'  
         SET @nScanQty = 0  
         GOTO Step_3_Fail  
      END -- IF @nScanQty > @nSuggQty -- (ChewKP11) End  
  
  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = ''  
  
      -- (ChewKP01)  
      IF @cUserPosition = ''  
      BEGIN  
         SET @cUserPosition = '1'  
      END  
  
      SET @nFromScn  = @nScn  
      SET @nFromStep = @nStep  
  
      SET @cOutField02 = @cTTMTasktype -- (james05)  
  
      -- go to short pick screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
   GOTO Quit  
  
   Step_3_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cOutField01 = @c_ToteNo  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = @cDescr1  
      SET @cOutField04 = @cDescr2  
      SET @cOutField05 = ''  
      SET @cOutField06 = @cUOM  
      SET @cOutField07 = @nScanQty  
      SET @cOutField08 = @nSuggQTY  
      SET @cOutField09 = @cFromLoc  -- (ChewKP20)  
      SET @cOutField10 = @cTTMTasktype -- (james05)  

      -- (james17)
      SET @cTaskType2EnableBulkPicking = rdt.RDTGetConfig( @nFunc, 'TaskType2EnableBulkPicking', @cTaskStorer)

      IF @cTaskType2EnableBulkPicking = 'ALL' OR 
         @cTaskType2EnableBulkPicking = @cTTMTasktype
      BEGIN
         SET @cOutField11 = 'ENTER QTY:'
         SET @cOutField12 = ''
         SET @cFieldAttr12 = '' -- Enable the qty field
      END
      ELSE
      BEGIN
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         SET @cFieldAttr12 = 'O' -- disable the qty field
      END
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
         SET @nErrNo = 70022  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'  
         GOTO Step_4_Fail  
      END  
  
      --IF @cSHTOption NOT IN ('1', '9')  
      IF ISNULL(RTRIM(@cSHTOption), '') <> '1' AND ISNULL(RTRIM(@cSHTOption), '') <> '9' -- (Vicky02)  
         AND ISNULL(RTRIM(@cSHTOption), '') <> '5' -- (james14)
      BEGIN  
         SET @nErrNo = 70023  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'  
         GOTO Step_4_Fail  
      END  
  
      IF @cSHTOption = '1'  
      BEGIN  
         SET @cOutField01 = ''  
         --(ChewKP01)  
         SET @cUserPosition = '1'  
         SET @cShortPickFlag = 'Y'  
         --SET @cFromLOC = ''  
         --SET @nFromStep = @nStep  
         -- Go to Reason Code Screen  
         SET @nScn  = 2109  
         SET @nStep = @nStep + 5  
      END  

      -- (james14)
      IF @cSHTOption = '5'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                         WHERE StorerKey = @cTaskStorer
                         AND   ListName = 'TWLIGHTLOC'
                         AND   CODE = @cAreaKey
                         AND   Short = '1')
         BEGIN  
            SET @nErrNo = 70098  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ALT LOC NOT ON'  
            GOTO Step_4_Fail  
         END  
      
         EXEC RDT.rdt_PicePick4AltPickLoc 
            @nMobile, 
            @nFunc, 
            @cLangCode, 
            @cTaskStorer, 
            @cAreaKey, 
            @cTaskDetailKey, 
            @cAltLOC       OUTPUT, 
            @nMQty_TTL     OUTPUT, 
            @nErrNo        OUTPUT, 
            @cErrMsg       OUTPUT, 
            0  -- debug mode

         IF @nErrNo = 0
         BEGIN
            SET @cOutField01 = @c_ToteNo
            SET @cOutField02 = @cFromLoc
            SET @cOutField03 = @cAltLOC
            SET @cOutField04 = @nMQty_TTL
            SET @cOutField05 = ''
            SET @cOutField09 = @cTTMTasktype

            SET @nScn  = 2791  
            SET @nStep = @nStep + 10  
         END
         ELSE
            GOTO Step_4_Fail  
      END

      -- Close Tote  
      IF @cSHTOption = '9'  
      BEGIN  
         SET @cShortPickFlag = 'N'  
         -- If Nothing Scan in Single Pick. Just Release the Task  
         IF @c_PickMethod LIKE 'SINGLES%' AND -- (james11)
            @nScanQty = 0  
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
               SET @nErrNo = 70032  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'  
               ROLLBACK TRAN BT_001  
               GOTO Step_4_Fail  
            END  
  
            -- Initialise TaskDetailKey, so that that will continue with new task  
            SET @c_TaskDetailKeyPK = ''  
            GOTO WCS_Routing_Process  
         END -- IF @c_PickMethod = 'SINGLES' AND @nScanQty = 0  
  
         -- Update WCSRouting - Tote FULL  
         -- ToteNo to DropID  
         -- If there is still outstatnding PickTask to be done. For the Same TaskDetailkey , Goto Screen 7 -- (SINGLES)  
         -- Retrieve Next Task (If Doubles / Multis Should Retrieve Same Task Within same zone )  
         -- Split Task If There is remaining Task, and the next task shall be the split Task.  
  
         -- Split Task If There is Remaining QTY after Close Tote (Start)  --  
         SET @c_TaskDetailKeyPK = ''  
  
         IF (( @nFromScn = @nScnFromLoc OR @nFromScn = @nScnSKU) AND @nScanQTY=0)  
            GOTO WCS_Routing_Process  
  
         IF @nSuggQTY <> @nScanQTY  
         BEGIN  
  
            SET @nRemainQty =  @nSuggQTY -  @nScanQTY  
  
            EXECUTE dbo.nspg_getkey  
            'TaskDetailKey'  
            , 10  
            , @c_TaskDetailKeyPK OUTPUT  
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
               SELECT  @c_TaskDetailKeyPK,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,@nRemainQty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc  
              ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide  
              ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey  
              ,Message01,Message02,'PREVFULL',@cTaskDetailKey,LoadKey,AreaKey, DropID, @nRemainQty -- (Vicky02) '' -- (ChewKP04)  
               FROM dbo.TaskDetail WITH (NOLOCK) -- (Vicky02)  
               WHERE Taskdetailkey = @cTaskDetailKey  
               AND Storerkey = @cTaskStorer  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70035  
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
  
         EXECUTE RDT.rdt_TM_PiecePick_ConfirmTask  
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
            @c_ToteNo,  
            @nScanQTY,  
            '5',  
            @cLangCode,  
            @nSuggQTY,  
            @nErrNo OUTPUT,  
            @cErrMsg OUTPUT,  
            @c_PickMethod ,  
            @c_TaskDetailKeyPK  
  
         -- Stamp pickslip inside dropid table (james11)
         SELECT @cPickSlipNo = PickHeaderKey 
         FROM dbo.PickHeader WITH (NOLOCK) 
         WHERE ExternOrderKey = @cLoadkey
         AND   OrderKey = CASE WHEN ISNULL( OrderKey, '') = '' THEN OrderKey ELSE @cOrderkey END
      
         BEGIN TRAN BT_001  
         -- Insert into DropID and DropID Detail Table (Start) --  
  
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @c_ToteNo )  
         BEGIN  
            INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )  
            VALUES (@c_ToteNo , '' , @c_PickMethod, '0' , @cLoadkey, @cPickSlipNo)  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70042  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
               ROLLBACK TRAN BT_001  
               GOTO Step_4_Fail  
            END  
         END  
  
         IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DROPID = @c_ToteNo AND ChildID = @cSKU)  
         BEGIN  
            INSERT INTO DROPIDDETAIL ( DropID, ChildID)  
            VALUES (@c_ToteNo, @cSKU )  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70043  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
               ROLLBACK TRAN BT_001  
               GOTO Step_4_Fail  
            END  
         END  
  
         --Insert into DropID and DropID Detail Table (End) --  
  
         -- Confirm Task  
         UPDATE dbo.TaskDetail WITH (ROWLOCK)  
             SET Status = '9' ,  
             Qty = @nScanQty,  
             EndTime = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
             EditDate = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
             EditWho = @cUserName, -- (ChewKP05)  
             TrafficCop = NULL      -- tlting01  
         WHERE TaskDetailKey = @cTaskDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nScanQTY = 0  
            SET @nErrNo = 70032  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'  
            ROLLBACK TRAN BT_001  
            GOTO Step_4_Fail  
         END  
  
         -- (ChewKP09) -- SOS# 206805  
         -- EXEC RDT.rdt_STD_EventLog  
         --         @cActionType   = '3',  
         --         @cUserID       = @cUserName,  
         --         @nMobileNo     = @nMobile,  
         --         @nFunctionID   = @nFunc,  
         --         @cFacility     = @cFacility,  
         --         @cStorerKey    = @cStorerkey,  
         --         @cLocation     = @cFromLoc,  
         --         @nQTY          = @nScanQty,  
         --         @cRefNo1       = @cTaskdetailkey,  
         --         @cRefNo2       = @c_ToteNo  
  
         -- (Shong01) Cannot place this statement before @@ERROR Check..  
    -- Reset Scan QTY  
         SET @nScanQTY = 0  
  
         -- (vicky03) - Start  
         DECLARE curDropID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TaskDetailkey  
         FROM dbo.TaskDetail TD WITH (NOLOCK)  
         INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
         WHERE TD.Loadkey = @cLoadkey  
         AND TD.PickMethod = @c_PickMethod  
         AND TD.Status < '9'  
         AND TD.UserKey = @cUserName  
         AND TD.DropID = @c_ToteNo  
  
         OPEN curDropID  
         FETCH NEXT FROM curDropID INTO @c_RTaskDetailkey  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            UPDATE dbo.TaskDetail WITH (ROWLOCK)  
               SET Message03 = 'PREVFULL',  
                   Trafficcop = NULL,  
                   DropID = '' -- Tote Close, should set the dropid to blank (shong02)  
            WHERE TaskDetailkey = @c_RTaskDetailkey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70048  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
               ROLLBACK TRAN BT_001  
               GOTO Step_4_Fail  
            END  
  
            FETCH NEXT FROM curDropID INTO @c_RTaskDetailkey  
         END  
         CLOSE curDropID  
         DEALLOCATE curDropID  
         -- (vicky03) - End  
  
         COMMIT TRAN BT_001  
  
         WCS_Routing_Process:  
         ---*** Insert into WCSRouting (Starting) ***---  
         IF CAST(@c_ToteNo AS INT) > 0 -- (Vicky04)  
         BEGIN  
            EXEC [dbo].[nspInsertWCSRouting]  
              @cStorerKey  
             ,@cFacility  
             ,@c_ToteNo  
             ,'PK'  
             ,'F'  
             ,@cTaskdetailkey  
             ,@cUserName  
             , 0  
             ,@b_Success          OUTPUT  
             ,@nErrNo             OUTPUT  
             ,@cErrMsg            OUTPUT  
  
            IF @nErrNo <> 0  
            BEGIN  
               SET @nErrNo = @nErrNo  
               SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'  
               GOTO Step_4_Fail  
            END  
         END  
         ---*** Insert into WCSRouting (End) ***---  
  
         BEGIN TRAN  
         UPDATE dbo.WCSRouting WITH (ROWLOCK)  
         SET Status = '5'  
         WHERE ToteNo = @c_ToteNo  
         AND Final_Zone = @c_FinalPutawayzone  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70052  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
            ROLLBACK TRAN  
            GOTO Step_4_Fail  
         END  
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END  
  
         IF @c_PickMethod LIKE 'SINGLES%' --OR @c_PickMethod = 'PIECE'  (james11)
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
                SET @nErrNo = 70032  
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'  
                ROLLBACK TRAN BT_001  
                GOTO Step_4_Fail  
             END  
          END  
         END  
         -- Added By Shong on 20-Aug-2010  
         -- Release tote# when close tote  
         IF @c_PickMethod LIKE 'MULTIS%' OR  -- (james11)
            @c_PickMethod LIKE 'DOUBLES' OR 
            @c_PickMethod LIKE 'PIECE%'    --(ChewKP21)  
         BEGIN  
            -- Release Tote#  
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                           WHERE UserKey = @cUserName  
                           AND   STATUS = '3'  
                           AND   DropId = @c_ToteNo )  
            BEGIN  
               Update dbo.TaskDetail WITH (ROWLOCK)  
                  SET DropID = '',  
                  EndTime = GETDATE(),  
                  EditDate = GETDATE(),  
                  EditWho  = @cUserName,  
                  Trafficcop = NULL  
               WHERE UserKey = @cUserName  
               AND   STATUS = '3'  
               AND   DropId = @c_ToteNo  
               
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70032  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'  
                  ROLLBACK TRAN BT_001  
                  GOTO Step_4_Fail  
               END  
            END  
  
            SET @c_ToteNo=''  
            SET @cTaskDetailkey=''  
         END  
  
         --(ChewKP01)  
         SET @cUserPosition = '1'  
  
         -- Go to next screen  
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
         SET @cOutField02 = @cTTMTasktype -- (james05)  
       END -- Option =9  
  
    END -- IF @nInputKey = 1  
  
   IF @nInputKey = 0    --ESC  
   BEGIN  
      -- (Shong01)  
      --IF @c_PickMethod = 'SINGLES' AND @nFromStep = @nStepFromLoc  
      IF @nFromStep = @nStepFromLoc  
      BEGIN  
         SET @cOutField02 = @cLoc  
         SET @cOutField01 = @c_PickMethod  
         SET @cOutField02 = @c_ToteNo  
         SET @cOutField03 = @cSuggFromLoc  
         SET @cOutField04 = ''  
         SET @cOutField05 = @cTTMTasktype -- (james05)  
  
         SET @nScn  = @nScnFromLoc  
         SET @nStep = @nStepFromLoc  
  
         GOTO QUIT  
      END  
  
      SET @cOutField01 = @c_ToteNo  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = @cDescr1  
      SET @cOutField04 = @cDescr2  
      SET @cOutField05 = ''  
      SET @cOutField06 = @cUOM  
      SET @cOutField07 = @nScanQty  
      SET @cOutField08 = @nSuggQTY  
      SET @cOutField09 = @cFromLoc -- (ChewKP20)  
      SET @cOutField10 = @cTTMTasktype -- (james05)  

      -- (james17)
      SET @cTaskType2EnableBulkPicking = rdt.RDTGetConfig( @nFunc, 'TaskType2EnableBulkPicking', @cTaskStorer)

      IF @cTaskType2EnableBulkPicking = 'ALL' OR 
         @cTaskType2EnableBulkPicking = @cTTMTasktype
      BEGIN
         SET @cOutField11 = 'ENTER QTY:'
         SET @cOutField12 = ''
         SET @cFieldAttr12 = '' -- Enable the qty field
      END
      ELSE
      BEGIN
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         SET @cFieldAttr12 = 'O' -- disable the qty field
      END
  
      -- (ChewKP01)  
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
     Success Message    
     ENTER = Next Task  
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
  
      --DECLARE @cNextTaskdetailkeyS NVARCHAR(10)  
  
      -- (ChewKP01)  
      SET @cUserPosition = '1'  

      IF @c_TaskDetailKeyPK <> '' AND  
        --@c_PickMethod NOT IN ('SINGLES','PIECE') -- Continue Pick the Remaining Qty  (ChewKP21)  
         @c_PickMethod NOT LIKE 'SINGLES%' -- Continue Pick the Remaining Qty  (ChewKP21)  (james11)
      BEGIN  
         SELECT @cRefKey03 = DropID ,  
                @cRefkey04 = PickMethod  
         From dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskDetailkey = @c_TaskDetailKeyPK  
  
         SET @cTaskdetailkey = @c_TaskDetailKeyPK  
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
  
         --SET @nScn = 2430  
         --SET @nStep = 1  
         SET @nScn  = @nScnEmptyTote  
         SET @nStep = @nStepEmptyTote  
  
         SET @c_TaskDetailKeyPK = ''  
  
         -- EventLog - Sign Out Function (Chee01)  
         EXEC RDT.rdt_STD_EventLog  
           @cActionType = '9', -- Sign Out function  
           @cUserID     = @cUserName,  
           @nMobileNo   = @nMobile,  
           @nFunctionID = @nFunc,  
           @cFacility   = @cFacility,  
           @cStorerKey  = @cTaskStorer ,
           @nStep       = @nStep 
  
         GOTO QUIT  
      END  
  
      IF @c_PickMethod LIKE 'SINGLES%' --OR @c_PickMethod = 'PIECE' (ChewKP21)  (james11)
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
          ,  @c_lasttasktype  = 'TPK'  
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
             ,  @c_areakey05     = ''  
             ,  @c_lastloc       = ''  
             ,  @c_lasttasktype  = 'TPK'  
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
     
               -- EventLog - Sign Out Function (Chee01)  
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
         END  
  
          IF ISNULL(@cErrMsg, '') <> ''  
          BEGIN  
            SET @cErrMsg = @cErrMsg  
            GOTO Step_5_Fail  
          END  
  
         IF ISNULL(@cNextTaskdetailkeyS, '') <> ''  
         BEGIN  
            SET @c_ToteNo = '' -- (ChewKP04)  
            SELECT @cRefKey03 = CASE WHEN TaskType = 'PA' THEN CaseID ELSE DropID END,  
                   @cRefkey04 = PickMethod,  
                   @c_ToteNo  = DropID,  
                   @c_PickMethod = PickMethod,  
                   @cNewToteNo   = DropID, -- (Shong04)  
                   @cTTMTasktype = TaskType  
            From dbo.TaskDetail WITH (NOLOCK)  
            WHERE TaskDetailkey = @cNextTaskdetailkeyS  

            SET @cTaskdetailkey = @cNextTaskdetailkeyS  

            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                        WHERE TaskDetailKey = @cTaskdetailkey  
                        AND STATUS <> '9' )  
            BEGIN  
               BEGIN TRAN  
                  
               -- (james01)  
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
                  Starttime = GETDATE(),  
                  Editdate = GETDATE(),  
                  EditWho = @cUserName,  
                  TrafficCOP = NULL -- (jamesxx) performance tuning  
               WHERE TaskDetailKey = @cTaskdetailkey  
               AND STATUS <> '9'  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70201  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                  ROLLBACK TRAN  
                GOTO Step_10_Fail  
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
            SET @cOutField09 = @cTTMTasktype -- (james05)  

            IF @cTTMTasktype NOT IN ('PK', 'PPK')
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

               -- EventLog - Sign Out Function (Chee01)  
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
            -- (Shong04)  
            IF (@c_PickMethod LIKE 'SINGLES%') --OR @c_PickMethod = 'PIECE')  (ChewKP21)  (james11)
            BEGIN  
               SET @nPrevStep = '0'  

               SET @cOutField05 = ''  
               IF ISNULL(@c_ToteNo,'') <> ''  
               BEGIN  
                  UPDATE DBO.TASKDETAIL WITH (ROWLOCK)  
                     SET DropID = '', TrafficCop = NULL  
                  WHERE TaskDetailkey = @cNextTaskdetailkeyS  

                  SET @c_ToteNo = ''  
                  SET @cNewToteNo = ''  

               END  
               SET @nPrevStep = 0  
               SET @nScn = 2107 -- Empty Tote  
               SET @nStep = 11  

            END -- (@c_PickMethod = 'SINGLES' OR @c_PickMethod = 'PIECE')  
            ELSE  
            BEGIN  
               SET @cNewToteNo = ISNULL(@cNewToteNo,'')  
               IF ISNULL(RTRIM(@cNewToteNo),'') <> ''  
               BEGIN  
                  SET @c_ToteNo  = @cNewToteNo  
                  SET @cOutField05 = ''  
                  SET @cOutField04 = @c_PickMethod  
                  SET @cOutField03 = @c_ToteNo  
                  SET @cOutField09 = @cTTMTasktype -- (james05)  
                  SET @nScn  = @nScnWithToteNo  
                  SET @nStep = @nStepWithToteNo  
               END  
               ELSE  
               BEGIN  
                  SET @cOutField01 = @c_PickMethod  
                  SET @cOutField02 = @c_ToteNo  
                  SET @cOutField03 = @cSuggFromLoc  
                  SET @cOutField04 = ''  
                  SET @c_ToteNo = '' -- (ChewKP04)  
                  SET @cNewToteNo = ''  

                  -- Got to empty Tote No screen  
                  SET @nPrevStep = 0  
                  SET @nScn  = @nScnEmptyTote  
                  SET @nStep = @nStepEmptyTote  
               END  
            END  
         END -- IF ISNULL(@cNextTaskdetailkeyS, '') <> ''  
            
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
         IF @c_PickMethod LIKE 'DOUBLES%' OR    -- (james11)
            @c_PickMethod LIKE 'MULTIS%' OR 
            @c_PickMethod LIKE 'PIECE%' -- (ChewKP21)  
         BEGIN  
            -- (james03) Get the task within the same area; there is probably more than 1 zone per area  
            SELECT TOP 1 @c_CurrAREA = AD.AREAKEY, @c_CurrTaskType = td.TaskType
            FROM dbo.TaskDetail td WITH (NOLOCK)  
            JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc  
            JOIN dbo.AREADETAIL AD (NOLOCK) ON l.PUTAWAYZONE = AD.PUTAWAYZONE  
            WHERE td.TaskDetailKey = @cTaskdetailkey  
               -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first (james10)  
               AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  
                 
            -- (Vicky02) - GET RELATED TASK WITHIN SAME ZONE TO BE FULLFILLED TO NEW TOTE  
--            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
--                        INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
--                        WHERE TD.Loadkey = @cLoadkey  
--                        AND TD.PickMethod = @c_PickMethod  
--          AND TD.Status = '3'  
--                        AND TD.TaskDetailkey <> @cTaskDetailkey  
--                        AND LOC.Putawayzone = @c_CurrPutawayzone  
--                        AND LOC.Facility = @cFacility  
--                        AND TD.UserKey = @cUserName  
--                        AND TD.Message03 = 'PREVFULL'  
--                        AND ISNULL(RTRIM(TD.DropID), '') <> '')  
  
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                        INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                        WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        AND TD.Status = '3'  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrAREA  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName  
                        AND TD.Message03 = 'PREVFULL'  
                        AND ISNULL(RTRIM(TD.DropID), '') <> ''
                        AND TD.TaskType = @c_CurrTaskType)  
            BEGIN  
               -- Get Next TaskKey  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               AND TD.Status = '3'  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND LOC.Putawayzone = @c_CurrPutawayzone  
               AND LOC.Facility = @cFacility  
               AND TD.UserKey = @cUserName  
               AND TD.Message03 = 'PREVFULL'  
               AND ISNULL(RTRIM(TD.DropID), '') <> ''  
               AND TD.TaskType = @c_CurrTaskType
  
               IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
               BEGIN  
                  SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                  INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                  WHERE TD.Loadkey = @cLoadkey  
                  AND TD.PickMethod = @c_PickMethod  
                  AND TD.Status = '3'  
                  AND TD.TaskDetailkey <> @cTaskDetailkey  
                  AND AD.AreaKey = @c_CurrAREA  
                  AND LOC.Facility = @cFacility  
                  AND TD.UserKey = @cUserName  
                  AND TD.Message03 = 'PREVFULL'  
                  AND ISNULL(RTRIM(TD.DropID), '') <> ''  
                  AND TD.TaskType = @c_CurrTaskType
               END  
  
               SET @cTaskDetailkey = @cNextTaskdetailkeyS  
               SET @cNextTaskdetailkeyS = ''  
  
               IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                           WHERE TaskDetailKey = @cTaskdetailkey  
                           AND STATUS <> '9' )  
               BEGIN  
                  BEGIN TRAN  
                  -- (james01)  
                  UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
                     Starttime = GETDATE(),  
                     Editdate = GETDATE(),  
                     EditWho = @cUserName,  
                     TrafficCOP = NULL -- (jamesxx) performance tuning  
                  WHERE TaskDetailKey = @cTaskdetailkey  
                  AND STATUS <> '9'  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 70202  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                     ROLLBACK TRAN  
                     GOTO Step_10_Fail  
                  END  
  
                  COMMIT TRAN  
               END  
  
               --- GET Variable --  
               SET @cNewToteNo = ''  
               SELECT @cTaskStorer = RTRIM(Storerkey),  
                      @cSKU      = RTRIM(SKU),  
                      @cSuggID     = RTRIM(FromID),  
                      @cSuggToLoc  = RTRIM(ToLOC),  
                      @cLot   = RTRIM(Lot),  
                      @cSuggFromLoc   = RTRIM(FromLoc),  
                      @nSuggQTY    = Qty,  
                      @cLoadkey    = RTRIM(Loadkey),  
                      @c_PickMethod = RTRIM(PickMethod),  
                      @cOrderkey   = RTRIM(Orderkey),  
                      @cNewToteNo  = RTRIM(DropID)  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cTaskdetailkey  
  
               SELECT @c_CurrPutawayzone = Putawayzone  
               FROM LOC WITH (NOLOCK)  
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
    
               -- PrePare Var for Next Screen  
               -- Reset Scan Qty to 0  
  
               SET @nScanQty = 0  
  
               SET @cUserPosition = '1'  
  
               SET @nPrevStep = 1  
  
               -- Got to empty Tote No screen  
               SET @nFunc = @nFunc  
  
               IF ISNULL(RTRIM(@c_ToteNo),'') <> ISNULL(RTRIM(@cNewToteNo),'')  
               BEGIN  
                  SET @c_ToteNo  = @cNewToteNo  
                  SET @cOutField05 = ''  
                  SET @cOutField04 = @c_PickMethod  
                  SET @cOutField03 = @c_ToteNo  
                  SET @cOutField09 = @cTTMTasktype -- (james05)  
                  SET @nScn  = @nScnWithToteNo  
                  SET @nStep = @nStepWithToteNo  
               END  
               ELSE  
               BEGIN  
                  SET @cOutField01 = @c_PickMethod  
                  SET @cOutField02 = @c_ToteNo  
                  SET @cOutField03 = @cSuggFromLoc  
                  SET @cOutField04 = ''  
                  SET @cOutField05 = @cTTMTasktype -- (james05)  
  
                  SET @nScn = @nScnFromLoc  
                  SET @nStep = @nStepFromLoc  
               END  
               GOTO QUIT  
            END  
            ELSE  
            -- GET RELATED TASK WITHIN SAME ZONE SAME TOTE IN THE SAME ZONE  
--            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
--                        INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
--                        WHERE TD.Loadkey = @cLoadkey  
--                        AND TD.PickMethod = @c_PickMethod  
--                        --AND TD.Status IN ('0', '3' )  
--                        AND TD.Status = '3' -- (vicky03)  
--                        AND TD.TaskDetailkey <> @cTaskDetailkey  
--                        AND LOC.Putawayzone = @c_CurrPutawayzone  
--                        AND LOC.Facility = @cFacility  
--                   AND TD.UserKey = @cUserName  
--                        AND TD.DropID = @c_ToteNo  
--                        AND ISNULL(RTRIM(TD.DropID), '') <> '')  
--                        --AND TD.Orderkey = @cOrderkey) -- (ChewKP03)  
  
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                        INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                        WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        --AND TD.Status IN ('0', '3' )  
                        AND TD.Status = '3' -- (vicky03)  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrAREA  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName  
                        AND TD.DropID = @c_ToteNo  
                        AND ISNULL(RTRIM(TD.DropID), '') <> '')  
                        --AND TD.Orderkey = @cOrderkey) -- (ChewKP03)  
            BEGIN  
               -- Get Next TaskKey  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey = @cLoadkey  
                     AND TD.PickMethod = @c_PickMethod  
                     AND TD.Status = '3' -- (vicky03)  
                     AND TD.TaskDetailkey <> @cTaskDetailkey  
                     AND LOC.Putawayzone = @c_CurrPutawayzone  
                     AND LOC.Facility = @cFacility  
                     AND TD.UserKey = @cUserName  
                     AND TD.DropID = @c_ToteNo  
                     AND ISNULL(RTRIM(TD.DropID), '') <> ''  

               IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
               BEGIN  
                  SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                  INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                  WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        AND TD.Status = '3' -- (vicky03)  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrArea  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName  
                        AND TD.DropID = @c_ToteNo  
                        AND ISNULL(RTRIM(TD.DropID), '') <> ''  
               END  

               SET @cTaskDetailkey = @cNextTaskdetailkeyS  
               SET @cNextTaskdetailkeyS = ''  

               IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                           WHERE TaskDetailKey = @cTaskdetailkey AND STATUS <> '9' )  
               BEGIN  
                  BEGIN TRAN  
                  
                  -- (james01)  
                  UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
                     Starttime = GETDATE(),  
                     Editdate = GETDATE(),  
                     EditWho = @cUserName,  
                     TrafficCOP = NULL -- (jamesxx) performance tuning  
                  WHERE TaskDetailKey = @cTaskdetailkey  
                  AND STATUS <> '9'  

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 70203  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                     ROLLBACK TRAN  
                     GOTO Step_10_Fail  
                  END  

                  COMMIT TRAN  
               END  
               
               --- GET Variable --  
               SELECT @cTaskStorer = RTRIM(Storerkey),  
                      @cSKU        = RTRIM(SKU),  
                      @cSuggID     = RTRIM(FromID),  
                      @cSuggToLoc  = RTRIM(ToLOC),  
                      @cLot        = RTRIM(Lot),  
                      @cSuggFromLoc   = RTRIM(FromLoc),  
                      @nSuggQTY    = Qty,  
                      @cLoadkey    = RTRIM(Loadkey),  
                      @c_PickMethod = RTRIM(PickMethod),  
                      @cOrderkey   = RTRIM(Orderkey) -- (ChewKP03)  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cTaskdetailkey  
  
               SELECT @c_CurrPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)  
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  


               -- PrePare Var for Next Screen  
               -- Reset Scan Qty to 0  
  
               SET @nScanQty = 0  
  
               SET @cUserPosition = '1'  
  
               SET @nPrevStep = 1  
  
               SET @cOutField01 = @c_PickMethod  
               SET @cOutField02 = @c_ToteNo  
               SET @cOutField03 = @cSuggFromLoc  
               SET @cOutField04 = ''  
               SET @cOutField05 = @cTTMTasktype -- (james05)  
  
               -- There is still Task in Same Zone GOTO Screen 2  
               SET @nScn = @nScnFromLoc  
               SET @nStep = @nStepFromLoc  

               GOTO QUIT  

            END  -- if Task Found for Same Tote#  
            ELSE -- GET RELATED TASK WITHIN SAME ZONE TO CONTINUE PICKING TO SAME TOTE  
--            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
--                                 INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
--                        WHERE TD.Loadkey = @cLoadkey  
--                        AND TD.PickMethod = @c_PickMethod  
--                        AND TD.Status = '3' -- (vicky03)  
--                        AND TD.TaskDetailkey <> @cTaskDetailkey  
--                        AND LOC.Putawayzone = @c_CurrPutawayzone  
--                        AND LOC.Facility = @cFacility  
--                        AND TD.UserKey = @cUserName  
--                        AND TD.DropID = '' )  
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                                 INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                                 INNER JOIN AREADETAIL AD WITH (NOLOCK) ON AD.PUTAWAYZONE = LOC.PUTAWAYZONE  
                        WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        AND TD.Status = '3' -- (vicky03)  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrArea  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName  
                        AND TD.DropID = '' )  
  
            BEGIN  
               -- Get Next TaskKey  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               AND TD.Status = '3' -- (vicky03)  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND LOC.Putawayzone = @c_CurrPutawayzone  
               AND LOC.Facility = @cFacility  
               AND TD.UserKey = @cUserName  
               AND TD.DropID = ''  
  
               IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
               BEGIN  
                  SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                  INNER JOIN AREADETAIL AD WITH (NOLOCK) ON AD.PUTAWAYZONE = LOC.PUTAWAYZONE  
                  WHERE TD.Loadkey = @cLoadkey  
                  AND TD.PickMethod = @c_PickMethod  
                  AND TD.Status = '3' -- (vicky03)  
                  AND TD.TaskDetailkey <> @cTaskDetailkey  
                  AND AD.AreaKey = @c_CurrArea  
                  AND LOC.Facility = @cFacility  
                  AND TD.UserKey = @cUserName  
                  AND TD.DropID = ''  
               END  
  
               SET @cTaskDetailkey = @cNextTaskdetailkeyS  
               SET @cNextTaskdetailkeyS = ''  
  
               IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                           WHERE TaskDetailKey = @cTaskdetailkey  
                           AND STATUS <> '9' )  
               BEGIN  
                  BEGIN TRAN  
               
                  -- (james01)  
                  UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
                     Starttime = GETDATE(),  
                     Editdate = GETDATE(),  
                     EditWho = @cUserName,  
                     TrafficCOP = NULL -- (jamesxx) performance tuning  
                  WHERE TaskDetailKey = @cTaskdetailkey  
                  AND STATUS <> '9'  

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 70204  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                     ROLLBACK TRAN  
                     GOTO Step_10_Fail  
                  END  

                  COMMIT TRAN  
               END  
  
               --- GET Variable --  
               SELECT @cTaskStorer = RTRIM(Storerkey),  
                      @cSKU        = RTRIM(SKU),  
                      @cSuggID     = RTRIM(FromID),  
                      @cSuggToLoc  = RTRIM(ToLOC),  
                      @cLot        = RTRIM(Lot),  
                      @cSuggFromLoc   = RTRIM(FromLoc),  
                      @nSuggQTY    = Qty,  
                      @cLoadkey    = RTRIM(Loadkey),  
                      @c_PickMethod = RTRIM(PickMethod),  
                      @cOrderkey   = RTRIM(Orderkey), -- (ChewKP03)  
                      @c_ToteNo    = ISNULL(RTRIM(DropId),'') -- (Shong03)  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cTaskdetailkey  
  
               SELECT @c_CurrPutawayzone = Putawayzone  
               FROM LOC WITH (NOLOCK)  
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
  
               -- PrePare Var for Next Screen  
               -- Reset Scan Qty to 0  
  
               SET @nScanQty = 0  
  
               SET @cUserPosition = '1'  
  
               SET @nPrevStep = 1  
  
               SET @cOutField01 = @c_PickMethod  
               SET @cOutField02 = @c_ToteNo  
               SET @cOutField03 = @cSuggFromLoc  
               SET @cOutField04 = ''  
               SET @cOutField05 = @cTTMTasktype -- (james05)  
  
               -- Have to update tote# that selected  
               UPDATE DBO.TASKDETAIL WITH (ROWLOCK)  
                 SET DropID = @c_ToteNo, TrafficCop = NULL  
               WHERE TaskDetailKey = @cTaskdetailkey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70065  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                  ROLLBACK TRAN  
                  GOTO Step_5_Fail  
               END  
  
               -- There is still Task in Same Zone GOTO Screen 2  
               --SET @nScn  = @nScnFromLoc  
               --SET @nStep = @nStepFromLoc  
               SET @nScn = @nScnEmptyTote  
               SET @nStep = @nStepEmptyTote  
  
               -- EventLog - Sign Out Function (Chee01)  
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
               -- No More Task in Same Zone  
               -- Update LOCKED Task to Status = '0' and Userkey = '' For PickUp by Next Zone  
  
               BEGIN TRAN  
  
               DECLARE CursorReleaseTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey  = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               AND TD.Status = '3' -- (vicky03x)  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND TD.UserKey = @cUserName  
               AND LOC.Putawayzone = @c_CurrPutawayzone -- (vicky03)  
  
               OPEN CursorReleaseTask  
               FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey  
               WHILE @@FETCH_STATUS <> -1  
               BEGIN  
                  UPDATE dbo.TaskDetail WITH (ROWLOCK)  
                  SET Status = '0', UserKey = '' , TrafficCop = NULL -- (Vicky0)  
                  WHERE TaskDetailkey = @c_RTaskDetailkey  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 70065  
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
                           --AND Orderkey = @cOrderkey -- (ChewKP03)  
                           --AND Userkey = @cUserName -- (ChewKP05)  
                           AND PickMethod = @c_PickMethod -- (ChewKP05)  
                           AND DropID = @c_ToteNo   -- (ChewKP05)  
                           AND Status IN ('0','3')  -- (ChewKP05)  
                           AND TaskDetailkey <> @cTaskDetailkey  
                           )  
               BEGIN  
                  -- Go to Order Fulli by Other Zone Screen  
                  SET @nScn = @nScn + 1  
                  SET @nStep = @nStep + 1  
                  SET @cOutField01 = @cTTMTasktype -- (james05)  
                  GOTO QUIT  
               END  
               ELSE  
               BEGIN  
                  -- Go to Tote Close Screen -- 2437  
                  SET @nScn = @nScn + 3  
                  SET @nStep = @nStep + 3  
                  SET @cOutField01 = CASE WHEN ISNULL(@c_ToteNo, '') = '' THEN 'Tote is Closed'  
                                          ELSE RTRIM(@c_ToteNo) + ' is Closed' END  -- (jamesxx)  
                  SET @cOutField02 = @cTTMTasktype -- (james05)  
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
         Update dbo.TaskDetail WITH (ROWLOCK)  
            SET Status = '0' , Userkey = '', DropID = '', Message03 = '' -- (vicky03) -- should also update DropID for Close Tote  
            ,TrafficCop = NULL  
            ,EditDate = GETDATE()  
            ,EditWho = SUSER_SNAME()  
         WHERE Userkey = @cUserName  
         AND Status = '3'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70060  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
            ROLLBACK TRAN  
            GOTO Step_5_Fail  
         END  
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      -- (ChewKP01)  
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
Step 6. screen = 2435  
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
  
      --DECLARE @cNextTaskdetailkeyS NVARCHAR(10)  
  
      -- (ChewKP01)  
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
       ,  @c_areakey01  = @cAreaKey  
       ,  @c_areakey02     = ''  
       ,  @c_areakey03     = ''  
       ,  @c_areakey04     = ''  
       ,  @c_areakey05     = ''  
       ,  @c_lastloc       = @cSuggToLoc  
       ,  @c_lasttasktype  = 'TPK' -- (Vicky02)  
       ,  @c_outstring     = @c_outstring    OUTPUT  
       ,  @b_Success       = @b_Success      OUTPUT  
       ,  @n_err           = @nErrNo         OUTPUT  
       ,  @c_errmsg        = @cErrMsg        OUTPUT  
       ,  @c_taskdetailkey = @cNextTaskdetailkeyS OUTPUT  
       ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT  
       ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey03      = @cRefKey03    OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func  
  
      IF ISNULL(RTRIM(@cNextTaskdetailkeyS), '') = '' --@nErrNo = 67804 -- Nothing to do!  
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
          ,  @c_areakey05     = ''  
          ,  @c_lastloc       = ''  
          ,  @c_lasttasktype  = 'TPK'  
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
     
            -- EventLog - Sign Out Function (Chee01)  
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
      END

      IF ISNULL(@cErrMsg, '') <> ''  
      BEGIN  
         SET @cErrMsg = @cErrMsg  
         GOTO Step_6_Fail  
      END  
  
      IF ISNULL(@cNextTaskdetailkeyS, '') <> ''  
      BEGIN  
         SET @cRefKey03 = ''  
         SET @cRefkey04 = ''  
  
         SELECT @cRefKey03 = CASE WHEN TaskType = 'PA' THEN CaseID ELSE DropID END,  
                @cRefkey04 = PickMethod,  
                @c_PickMethod = PickMethod,  
                @cTTMTasktype = TaskType  
         From dbo.TaskDetail WITH (NOLOCK)  
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
         SET @cOutField09 = @cTTMTasktype -- (james05)  
         SET @nPrevStep = '0'  
  
         SET @cOutField05 = ''  
      END  
  
      IF @cTTMTasktype NOT IN ('PK', 'PPK')
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
  
         -- EventLog - Sign Out Function (Chee01)  
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
  
  
      -- (ChewKP07) Start  
      IF (@cRefkey04 LIKE 'SINGLES%' ) -- Get Next Task  (james11)
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
  
         -- (ChewKP08)  
         SET @nPrevStep = 0  
         SET @nFunc = @nToFunc  
         SET @nScn = @nToScn  
         SET @nStep = 1  
      END  
      ELSE IF (@cRefkey04 LIKE 'DOUBLES%' OR    -- (james11)
               @cRefkey04 LIKE 'MULTIS%' OR 
               @cRefkey04 LIKE 'PIECE%') -- Get Next Task  
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
               SET @nErrNo = 70074  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr  
               GOTO Step_6_Fail  
            END  
  
            SELECT TOP 1 @nToScn = Scn  
            FROM RDT.RDTScn WITH (NOLOCK)  
            WHERE Func = @nToFunc  
            ORDER BY Scn  
  
            IF @nToScn = 0  
            BEGIN  
               SET @nErrNo = 70075  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr  
               GOTO Step_6_Fail  
            END  
  
            SET @nPrevStep = 0  
            SET @nFunc = @nToFunc  
            --SET @nScn = @nToScn  
            --SET @nStep = 1  
            SET @nScn = @nScnEmptyTote  
            SET @nStep = @nStepEmptyTote  
  
         END  
         ELSE  
         BEGIN  
            SET @nPrevStep = 0  
  
            SET @c_PickMethod = @cRefkey04  
            SET @cOutField05 = ''  
            SET @cOutField04 = @cRefkey04  
            SET @cOutField03 = @cRefkey03  
            SET @cOutField09 = @cTTMTasktype  
  
            SET @nFunc = 1760  
  
            SET @nScn = 2436  
            SET @nStep = 7  
         END  
  
      END  
      -- (ChewKP07) End  
  
  
--       SET @cOutField01 = @cRefKey01  
--       SET @cOutField02 = @cRefKey02  
--       SET @cOutField03 = @cRefKey03  
--       SET @cOutField04 = @cRefKey04  
--       SET @cOutField05 = @cRefKey05  
--   SET @cOutField06 = @cNextTaskdetailkeyS  
--       SET @cOutField07 = @cAreaKey  
--       SET @cOutField08 = @cTTMStrategykey  
  
     -- EventLog - Sign Out Function  
     EXEC RDT.rdt_STD_EventLog  
       @cActionType = '9', -- Sign Out function  
       @cUserID     = @cUserName,  
       @nMobileNo   = @nMobile,  
       @nFunctionID = @nFunc,  
       @cFacility   = @cFacility,  
       @cStorerKey  = @cStorerKey,
       @nStep       = @nStep
   END  
  
   IF @nInputKey = 0    --ESC  
   BEGIN  
      -- tlting01  
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                  WHERE Userkey = @cUserName  
                  AND Status = '3' )  
      BEGIN  
         -- Release ALL Task from Users when EXIT TM -- (ChewKP12)  
         BEGIN TRAN  
         
         Update dbo.TaskDetail WITH (ROWLOCK)  
            SET Status = '0' , Userkey = '', DropID = '', Message03 = '' -- (vicky03) -- should also update DropID  
         WHERE Userkey = @cUserName  
         AND Status = '3'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70081  
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
     SET @cOutField09 = '' -- (james05)  
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
      SET @c_PickMethod = @cOutField04  
  
      SET @cNextTaskdetailkeyS = ''  
      SET @nScanQty = 0  
      SET @cShortPickFlag = 'N'  
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
      SET @c_ToteNo  = ISNULL(RTRIM(@cOutField03),'') -- ChewKP14  
      SET @cInToteID = ISNULL(RTRIM(@cInField05),'')  -- ChewKP14  
  
      IF @cInToteID = ''  
      BEGIN  
         SET @nErrNo = 70016  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTENO Req  
         GOTO Step_7_Fail  
      END  
  
      IF rdt.rdtIsValidQTY( @cInToteID, 1) = 0 -- (Vicky04)  
      BEGIN  
         SET @nErrNo = 70057  
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
  
         SET @cTTMTasktype=''  
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
           AND  TD.TaskType IN ('PK', 'PPK')
           AND  TD.Status IN ('0', '3')  
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
            AND TD.Status IN ('0', 'W')  
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
                  SET @nErrNo = 70087  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo  
                  GOTO Step_7_Fail  
               END  
            END  
         END  
  
         -- If Records not found. Invalid Tote  
         IF ISNULL(RTRIM(@cSwapTaskType),'') = ''  
         BEGIN  
            SET @nErrNo = 70057  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo  
            GOTO Step_7_Fail  
         END  
  
--         -- (ChewKP18) Start  
--         IF EXISTS (SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
--                    JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.TaskDetailkey = TD.TaskDetailkey  
--                    JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey  
--                    WHERE TD.DropID = @cInToteID  
--                    AND TD.Status in ('0','3')  
--                    AND O.Status NOT IN ('9', 'CANC')  
--                    AND TD.Storerkey = @cStorerkey)  
--         BEGIN  
  
         -- Check If the Swap Tote have the route to current Zone.  
         SET @cSwapAreaKey=''  
         SELECT TOP 1 @cSwapAreaKey = ISNULL(AD.AreaKey,'')  
         FROM   LOC WITH (NOLOCK)  
         JOIN   PutawayZone pz WITH (NOLOCK) ON LOC.PutawayZone=pz.PutawayZone  
         JOIN   AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = pz.PutawayZone  
         WHERE  LOC.Loc = @cSwapLoc  
  
         SELECT TOP 1 @c_CurrAREA = AD.AREAKEY, @c_CurrTaskType = td.TaskType
         FROM dbo.TaskDetail td WITH (NOLOCK)  
         JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc  
         JOIN dbo.PUTAWAYZONE P (NOLOCK) ON L.PUTAWAYZONE = P.PUTAWAYZONE  
         JOIN dbo.AREADETAIL AD (NOLOCK) ON P.PUTAWAYZONE = AD.PUTAWAYZONE  
         WHERE td.TaskDetailKey = @cTaskdetailkey  
            -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first (james10)  
            AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  
  
         IF @c_CurrAREA <> @cSwapAreaKey  
         BEGIN  
            SET @nErrNo = 70057  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo  
            GOTO Step_7_Fail  
         END  
  
  
         IF @cSwapTaskType IN ('PK', 'PPK')  
         BEGIN  
            SET @nScn  = @nScnDiffTote  
            SET @nStep = @nStepDiffTote  
            SET @cOutField01 = @cOutField03 -- Old Tote  
            SET @cOutField02 = @cInToteID   -- New Tote  
            SET @cOutField03 = @cTTMTasktype -- (james05)  
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
                        AND UserKey = @cUserName )  
            BEGIN  
               UPDATE DBO.TASKDETAIL  
                  SET UserKey = '', STATUS='0'  
               WHERE STATUS='3'  
               AND   UserKey = @cUserName  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70069  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                  ROLLBACK TRAN  
                  GOTO Step_7_Fail  
               END  
            END  

            -- Lock the new swapped task  
            UPDATE DBO.TASKDETAIL  
               SET UserKey = @cUserName, STATUS='3'  
            WHERE STATUS IN ('3','0','W')  
            AND   TaskType='PA'  
            AND   Caseid = @cInToteID  
            AND   TaskDetailKey=@cSwapTaskDetailKey  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70069  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
               ROLLBACK TRAN  
               GOTO Step_7_Fail  
            END  
     
            SELECT @cRefKey03 = CaseID,  
                   @cRefkey04 = PickMethod,  
                   @c_PickMethod = PickMethod,  
                   @c_ToteNo     = DropID,  
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
            SET @nErrNo = 70057  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToteNo  
            GOTO Step_7_Fail  
         END  
  
         -- (ChewKP18) End  
         --SET @nErrNo = 70058  
         --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteNotMatch  
         --GOTO Step_7_Fail  
      END  

      SET @c_ToteNo = @cInToteID  
      --SET @cErrMSG = @cCaseID  
      --GOTO QUIT  
  
      SELECT @cTaskStorer = RTRIM(Storerkey),  
             @cSKU        = RTRIM(SKU),  
             @cSuggID     = RTRIM(FromID),  
             @cSuggToLoc  = RTRIM(ToLOC),  
             @cLot        = RTRIM(Lot),  
             @cSuggFromLoc  = RTRIM(FromLoc),  
             @nSuggQTY    = Qty,  
             @cLoadkey    = RTRIM(Loadkey),  
             @cOrderkey   = RTRIM(Orderkey) -- (ChewKP03)  
      FROM dbo.TaskDetail WITH (NOLOCK)  
      WHERE TaskDetailKey = @cTaskdetailkey  
  
      SELECT @c_CurrPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
  
      SELECT @c_FinalPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggToLoc AND Facility = @cFacility  
  
  
      -- Update WCSRoutingDetail Status = '1' Indicate Visited --  
      SELECT @c_PPAZone = RTRIM(SHORT) FROM dbo.CodeLKup WITH (NOLOCK) -- (Vicky02)  
      WHERE Listname = 'WCSStation' And Code = @c_CurrPutawayzone  
  
      -- (Vicky02) - Start  
      IF ISNULL(RTRIM(@c_PPAZone), '') = ''  
      BEGIN  
         SET @nErrNo = 70078  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WcsStatnNotSet'  
         GOTO Step_7_Fail  
      END  
      -- (Vicky02) - End  
  
      BEGIN TRAN  
      UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)  
      SET Status = '1' ,  
      EditWho = @cUserName , EditDate = GetDate()   --  (ChewKP17)  
      WHERE ToteNo = @c_ToteNo  
      AND Zone = @c_PPAZone  
  
      IF @@ERROR <> 0  
      BEGIN  
            SET @nErrNo = 70049  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
            ROLLBACK TRAN  
            GOTO Step_7_Fail  
      END  
      ELSE  
      BEGIN  
         COMMIT TRAN  
      END  
  
      -- (ChewKP05)  
      BEGIN TRAN  
      Update dbo.TaskDetail WITH (ROWLOCK)  
--      SET EndTime = GETDATE(),--CURRENT_TIMESTAMP , -- (Vicky02)  
      SET StartTime = GETDATE(), -- (james01)  
          EditDate = GETDATE(),--CURRENT_TIMESTAMP , -- (Vicky02)  
          EditWho = @cUserName,  
          TrafficCop=NULL -- (Shong05)  
      WHERE TaskDetailkey = @cTaskdetailkey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 70063  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
         ROLLBACK TRAN  
         GOTO Step_7_Fail  
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
         @nStep       = @nStep

      -- prepare next screen  
      SET @cUserPosition = '1'  
  
      SET @nPrevStep = 1  
  
      SET @cOutField01 = @c_PickMethod  
      SET @cOutField02 = @c_ToteNo  
      SET @cOutField03 = @cSuggFromLoc  
      SET @cOutField04 = ''  
      SET @cOutField05 = @cTTMTasktype -- (james05)  
  
      SET @nFromScn  = @nScn  
      SET @nFromStep = @nStep  
  
      -- Go to FromLoc screen  
      SET @nScn = @nScn - 5  
      SET @nStep = @nStep - 5  
   END  
  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = ''  
      SET @c_ToteNo    = @cOutField03  
  
      -- SET @cOutField09 = @cOutField01  
      -- (Shong05) Start  
      -- If Task already stealed by someone, do not go to reason code screen  
      -- GOTO get next task screen.  
      IF EXISTS(SELECT 1 FROM TaskDetail WITH (NOLOCK)  
                WHERE TaskDetailkey = @cTaskdetailkey  
                  AND Userkey <> @cUserName  
                  AND DropID = @c_ToteNo  
                  AND Status = '3')  
      BEGIN  
         SET @c_ToteNo = ''  
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
      -- (Shong05) End  
   END  
   GOTO Quit  
  
   Step_7_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cInToteID = ''  
  
      SET @cOutField04 = @c_PickMethod -- Suggested FromLOC  
      SET @cOutField03 = @cOutField03  -- Suggested ToteNo  
      SET @cOutField05 = ''  
  END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 8. screen = 2437  
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
  
      -- (ChewKP01)  
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
       ,  @c_lasttasktype  = 'TPK'  
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
          ,  @c_areakey05     = ''  
          ,  @c_lastloc       = ''  
          ,  @c_lasttasktype  = 'TPK'  
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
            SET @cOutField09 = '' -- (james05)  
            GOTO QUIT  
         END  
      END

      IF ISNULL(@cErrMsg, '') <> ''  
      BEGIN  
         SET @cErrMsg = @cErrMsg  
         GOTO Step_8_Fail  
      END  
  
      IF ISNULL(@cNextTaskdetailkeyS, '') <> ''  
      BEGIN  

         SET @cRefKey03 = ''  
         SET @cRefkey04 = ''  

         SELECT @cRefKey03 = CASE WHEN TaskType = 'PA' THEN CaseID ELSE DropID END,  
            @cRefkey04 = PickMethod,  
            @c_PickMethod = PickMethod,  
            @c_ToteNo     = DropID,  
            @cTTMTasktype = TaskType  
         FROM dbo.TaskDetail WITH (NOLOCK)  
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
         SET @cOutField09 = @cTTMTasktype  
  
         SET @nPrevStep = '0'  

         SET @cOutField05 = ''  
      END  
  
      IF @cTTMTasktype NOT IN ('PK', 'PPK')
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

         SET @nScn = @nToScn  
         SET @nFunc = @nToFunc  
         SET @nStep = 1  

         -- EventLog - Sign Out Function (Chee01)  
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
      
      -- (ChewKP07) Start  
      IF (@cRefkey04 LIKE 'SINGLES%' ) -- Get Next Task  (james11)
      BEGIN  
         SET @nToFunc = 0  
         SET @nToScn = 0  

         SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)  
         FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)  
         WHERE TaskType = RTRIM(@cTTMTasktype)  

         IF @nFunc = 0  
         BEGIN  
            SET @nErrNo = 70046  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr  
            GOTO Step_8_Fail  
         END  
  
         SELECT TOP 1 @nToScn = Scn  
         FROM RDT.RDTScn WITH (NOLOCK)  
         WHERE Func = @nToFunc  
         ORDER BY Scn  

         IF @nToScn = 0  
         BEGIN  
            SET @nErrNo = 70047  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr  
            GOTO Step_8_Fail  
         END  

         -- (ChewKP08)  
         SET @nPrevStep = 0  
         SET @nFunc = @nToFunc  
         SET @nScn = @nToScn  
         SET @nStep = 1  
      END  
      ELSE IF (@cRefkey04 LIKE 'DOUBLES%' OR @cRefkey04 LIKE 'MULTIS%' OR @cRefkey04 LIKE 'PIECE%') -- Get Next Task  (james11)
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
               SET @nErrNo = 70072  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr  
               GOTO Step_8_Fail  
            END  

            SELECT TOP 1 @nToScn = Scn  
            FROM RDT.RDTScn WITH (NOLOCK)  
            WHERE Func = @nToFunc  
            ORDER BY Scn  
  
            IF @nToScn = 0  
            BEGIN  
               SET @nErrNo = 70073  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr  
               GOTO Step_8_Fail  
            END  

            SET @nPrevStep = 0  
            SET @nFunc = @nToFunc  
--            SET @nScn = @nToScn  
--            SET @nStep = 1  
            SET @nScn = @nScnEmptyTote  
            SET @nStep = @nStepEmptyTote  
         END  
         ELSE  
         BEGIN  
            SET @nPrevStep = 0  

            SET @c_PickMethod = @cRefkey04  
            SET @cOutField05 = ''  
            SET @cOutField04 = @cRefkey04  
            SET @cOutField03 = @cRefkey03  
            SET @cOutField09 = @cTTMTasktype -- (james05)  

            SET @nFunc = 1760  
            SET @nScn = 2436  
            SET @nStep = 7  
         END  
      END  
      -- (ChewKP07) End  

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
  
   IF @nInputKey = 0    --ESC  
   BEGIN  
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                  WHERE Userkey = @cUserName  
                  AND Status = '3' )  
      BEGIN  
         -- Release ALL Task from Users when EXIT TM -- (ChewKP12)  
         BEGIN TRAN  
         Update dbo.TaskDetail WITH (ROWLOCK)  
            SET Status = '0' , Userkey = '', DropID = '', Message03 = '' -- (vicky03) -- should also update DropID  
         WHERE Userkey = @cUserName  
         AND Status = '3'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70082  
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
      EXEC RDT.rdt_STD_EventLog  
         @cActionType = '9', -- Sign Out function  
         @cUserID     = @cUserName,  
         @nMobileNo   = @nMobile,  
         @nFunctionID = @nFunc,  
         @cFacility   = @cFacility,  
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep
  
      -- (ChewKP01)  
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
      SET @cOutField01 = @c_PickMethod  
      SET @cOutField02 = @c_ToteNo  
      SET @cOutField03 = @cSuggFromLoc  
      SET @cOutField04 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 9. screen = 2109  
     REASON CODE  (Field01, input)  
********************************************************************************/  
Step_9:  
BEGIN  
  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      -- Screen mapping  

      SET @cReasonCode = @cInField01  
  
      IF @cReasonCode = ''  
      BEGIN  
         SET @nErrNo = 70024  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req  
         GOTO Step_9_Fail  
      END  
  
      IF @cShortPickFlag = 'Y'  
      BEGIN  
         IF EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK)  
                   WHERE C.LISTNAME = 'SPKINVRSN'  
                   AND   C.Code = @cReasonCode)  
         BEGIN  
            SET @nErrNo = 69865  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69865^BAD REASON  
            GOTO Step_9_Fail  
         END  
      END  
      ELSE  
      BEGIN  
         IF EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK)  
                   WHERE C.LISTNAME = 'NSPKINVRSN '  
                   AND   C.Code = @cReasonCode)  
         BEGIN  
            SET @nErrNo = 69865  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69865^BAD REASON  
            GOTO Step_9_Fail  
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
  
      IF @nScanQTY <> 0  
      BEGIN  
         BEGIN TRAN  
         UPDATE dbo.TaskDetail WITH (ROWLOCK)  
         SET Status = '9',  
             EndTime = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
             EditDate = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
             EditWho = @cUserName, -- (ChewKP05)  
             TrafficCop = NULL         -- tlting01  
         WHERE TaskDetailkey = @cTaskdetailkey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70055  
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
         -- (Vicky02) - Start  
  
      SELECT @cRemoveTaskFromUserQueue = RemoveTaskFromUserQueue  
      FROM dbo.TASKMANAGERREASON WITH (NOLOCK)  
      WHERE TaskManagerReasonKey = @cReasonCode  
  
      IF @cRemoveTaskFromUserQueue = '0' -- (ChewKP13)  
      BEGIN  
         BEGIN TRAN  
         UPDATE dbo.TaskDetail WITH (ROWLOCK)  
         SET Status = '9',  
             EndTime = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
             EditDate = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
             EditWho = @cUserName, -- (ChewKP05)  
             TrafficCop = NULL       -- tlting01  
         WHERE TaskDetailkey = @cTaskdetailkey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70055  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
            ROLLBACK TRAN  
            GOTO Step_9_Fail  
         END  
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END  
       END  
         -- (Vicky02) - Start  
         -- (Shong01)  
      IF ISNULL(@cTaskStorer,'') = ''  
         BEGIN  
            SELECT @cTaskStorer = RTRIM(Storerkey),  
                   @cSKU        = RTRIM(SKU),  
                   @cSuggID     = RTRIM(FromID),  
                   @cSuggToLoc  = RTRIM(ToLOC),  
                   @cLot        = RTRIM(Lot),  
                   @cSuggFromLoc  = RTRIM(FromLoc),  
                   @nSuggQTY    = Qty,  
                   @cLoadkey    = RTRIM(Loadkey),  
                   @cOrderkey   = RTRIM(Orderkey) -- (ChewKP03)  
            FROM dbo.TaskDetail WITH (NOLOCK)  
            WHERE TaskDetailKey = @cTaskdetailkey  
  
            SELECT @c_CurrPutawayzone = Putawayzone  
            FROM LOC WITH (NOLOCK)  
            WHERE LOC = @cSuggFromLoc  
            AND Facility = @cFacility  
  
            SELECT @c_FinalPutawayzone = Putawayzone  
            FROM LOC WITH (NOLOCK)  
            WHERE LOC = @cSuggToLoc  
            AND Facility = @cFacility  
         END  
      END -- If ScanQty = 0  
  
      SET @cContinueProcess = ''  
      SELECT @cContinueProcess = ContinueProcessing  
      FROM dbo.TASKMANAGERREASON WITH (NOLOCK)  
      WHERE TaskManagerReasonKey = @cReasonCode  
  
      -- Update Pick Detail Confirm Task for Short Status = '4' -- Should be common Stored Proc  
      -- Update WCSRouting.FinalZone  
      -- WCS Short Interface  
      -- ToteNo to DropID  
      -- Retrieve Next Task (If Doubles / Multis Should Retrieve Same Task Within same zone )  
  
      -- (ChewKP23)  
      SET @c_TMAutoShortPick = ''  
      SET @c_TMAutoShortPick = rdt.RDTGetConfig( @nFunc, 'TMAutoShortPick', @cStorerKey)  

      -- TMAutoShortPick (0 = off, 1 = on for Store piece pick only, 2 = on for Ecom pick only; 3 = on for both type) (james15)
      IF @c_TMAutoShortPick IN ('1', '2', '3') -- (james15)
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
            EXECUTE RDT.rdt_TM_PiecePick_ConfirmTask  
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
               @c_ToteNo,  
               @nScanQTY,  
               '4',  
               @cLangCode,  
               @nSuggQTY,  
               @nErrNo OUTPUT,  
               @cErrMsg OUTPUT,  
               @c_PickMethod  
  
  
            IF @nErrNo <> 0  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
               GOTO Step_9_Fail  
            END  

            -- Stamp pickslip inside dropid table (james11)
            SELECT @cPickSlipNo = PickHeaderKey 
            FROM dbo.PickHeader WITH (NOLOCK) 
            WHERE ExternOrderKey = @cLoadkey
            AND   OrderKey = CASE WHEN ISNULL( OrderKey, '') = '' THEN OrderKey ELSE @cOrderkey END

            -- Insert into DropID and DropID Detail Table (Start) --  
            BEGIN TRAN BT_005  
  
            IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DROPID  = @c_ToteNo )  
            BEGIN  
               INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo )  
               VALUES (@c_ToteNo , '' , @c_PickMethod, '0' , @cLoadkey, @cPickSlipNo)  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70033  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
                  ROLLBACK TRAN BT_005  
                  GOTO Step_9_Fail  
               END  
            END  
  
            IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DROPID = @c_ToteNo AND ChildID = @cSKU)  
            BEGIN  
               INSERT INTO DROPIDDETAIL ( DropID, ChildID)  
               VALUES (@c_ToteNo, @cSKU )  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70034  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'  
                  ROLLBACK TRAN BT_005  
                  GOTO Step_9_Fail  
               END  
            END  
            COMMIT TRAN BT_005  
  
            -- Insert into DropID and DropID Detail Table (End) --  
            -- For Short Pick --  
            -- 1. Stamp QC Loc to ToLoc for Current Task --  
            SELECT @c_QCLOC = RTRIM(Short)  
            FROM CODELKUP WITH (NOLOCK) -- (Vicky02)  
            WHERE Listname = 'WCSROUTE' AND Code = 'QC'  
  
            -- (Vicky01) - Start  
            IF ISNULL(RTRIM(@c_QCLOC), '') = ''  
            BEGIN  
               SET @nErrNo = 70067  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QCNotInWCSROUTE'  
               GOTO Step_9_Fail  
            END  
            -- (Vicky01) - End  
  
            -- Set the task final destination to QC location  
  
            -- (ChewKP23)  
            SET @c_TMAutoShortPick = ''  
            SET @c_TMAutoShortPick = rdt.RDTGetConfig( @nFunc, 'TMAutoShortPick', @cStorerKey)  
  
            -- TMAutoShortPick (0 = off, 1 = on for Store piece pick only, 2 = on for Ecom pick only; 3 = on for both type) (james15)
            IF @c_TMAutoShortPick IN ('', '0')  -- (james15)  
            BEGIN  
  
               BEGIN TRAN  
  
               UPDATE dbo.TaskDetail WITH (ROWLOCK)  
               SET ToLoc = @c_QCLOC,  
                   LogicalToLoc = @c_QCLOC,  
                   TrafficCop = NULL  
               WHERE TaskDetailkey = @cTaskDetailKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70038  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                  ROLLBACK TRAN  
                  GOTO Step_9_Fail  
               END  
  
               COMMIT TRAN  
            END  
  
            ---*** Insert into WCSRouting (Starting) ***---  
            IF CAST(@c_ToteNo AS INT) > 0 -- (Vicky04)  
            BEGIN  
               -- TMAutoShortPick (0 = off, 1 = on for Store piece pick only, 2 = on for Ecom pick only; 3 = on for both type) (james15)
               IF @c_TMAutoShortPick NOT IN ('', '0') 
               BEGIN  
                  -- 1 all ecom pick goes to qc. store piece pick not goto qc
                  IF @c_TMAutoShortPick = '1' AND @c_PickMethod NOT LIKE 'PIECE%'
                  BEGIN
                     EXEC [dbo].[nspInsertWCSRouting]  
                      @cTaskStorer  
                     ,@cFacility  
                     ,@c_ToteNo  
                     ,'PK'  
                     ,'S' -- (Shong01) Change from S to N  
                     ,@cTaskdetailkey  
                     ,@cUserName  
                     ,0  
                     ,@b_Success          OUTPUT  
                     ,@nErrNo             OUTPUT  
                     ,@cErrMsg            OUTPUT  

                     IF @nErrNo <> 0  
                     BEGIN  
                        SET @nErrNo = @nErrNo  
                        SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'  
                        GOTO Step_9_Fail  
                     END  
                  END
                  -- 2 store piece pick goes to qc. all ecom pick not goto qc
                  ELSE IF @c_TMAutoShortPick = '2' AND @c_PickMethod LIKE 'PIECE%'
                  BEGIN
                     EXEC [dbo].[nspInsertWCSRouting]  
                      @cTaskStorer  
                     ,@cFacility  
                     ,@c_ToteNo  
                     ,'PK'  
                     ,'S' -- (Shong01) Change from S to N  
                     ,@cTaskdetailkey  
                     ,@cUserName  
                     ,0  
                     ,@b_Success          OUTPUT  
                     ,@nErrNo             OUTPUT  
                     ,@cErrMsg            OUTPUT  

                     IF @nErrNo <> 0  
                     BEGIN  
                        SET @nErrNo = @nErrNo  
                        SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'  
                        GOTO Step_9_Fail  
                     END  
                  END
               END -- NOT IN ('', '0')   
               ELSE  
               BEGIN  
                  EXEC [dbo].[nspInsertWCSRouting]  
                   @cTaskStorer  
                  ,@cFacility  
                  ,@c_ToteNo  
                  ,'PK'  
                  ,'S' -- (Shong01) Change from S to N  
                  ,@cTaskdetailkey  
                  ,@cUserName  
                  ,0  
                  ,@b_Success          OUTPUT  
                  ,@nErrNo             OUTPUT  
                  ,@cErrMsg            OUTPUT  

                  IF @nErrNo <> 0  
                  BEGIN  
                     SET @nErrNo = @nErrNo  
                     SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'  
                     GOTO Step_9_Fail  
                  END  
               END  
            END  
            ---*** Insert into WCSRouting (End) ***---  
         END  
         ELSE IF @nScanQTY = 0 AND @cShortPickFlag = 'Y'  -- (Vicky02) - Start  
         BEGIN  

            EXECUTE RDT.rdt_TM_PiecePick_ConfirmTask  
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
               @c_ToteNo,  
               @nScanQTY,  
               '4',  
               @cLangCode,  
               @nSuggQTY,  
               @nErrNo OUTPUT,  
               @cErrMsg OUTPUT,  
               @c_PickMethod  
  
            IF @nErrNo <> 0  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
               GOTO Step_9_Fail  
            END  
  
            -- For Short Pick --  
            -- 1. Stamp QC Loc to ToLoc for Current Task --  
  
            SELECT @c_QCLOC = RTRIM(Short)  
            FROM CODELKUP (NOLOCK) -- (Vicky02)  
            WHERE Listname = 'WCSROUTE' AND Code = 'QC'  
  
            -- (Vicky01) - Start  
            IF ISNULL(RTRIM(@c_QCLOC), '') = ''  
            BEGIN  
               SET @nErrNo = 70068  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QCNotInWCSROUTE'  
               GOTO Step_9_Fail  
            END  
            -- (Vicky01) - End  
  
            -- (ChewKP23)  
            SET @c_TMAutoShortPick = ''  
            SET @c_TMAutoShortPick = rdt.RDTGetConfig( @nFunc, 'TMAutoShortPick', @cStorerKey)  
  
            IF @c_TMAutoShortPick in ('', '0')  -- (james15)
            BEGIN  
               BEGIN TRAN  
  
               UPDATE dbo.TaskDetail WITH (ROWLOCK)  
               SET ToLoc = @c_QCLOC, LogicalToLoc = @c_QCLOC , TrafficCop = NULL  
               WHERE TaskDetailkey = @cTaskDetailKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70069  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                  ROLLBACK TRAN  
                  GOTO Step_9_Fail  
                  END  
               ELSE  
               BEGIN  
                  COMMIT TRAN  
               END  
            END  
            ---*** Insert into WCSRouting (Starting) ***---  
            -- Added by Shong - Delete action already send to WCS route Singles pick  
            -- Need to add New tote instead of Update action back to WCS (Shong01)  
            IF CAST(@c_ToteNo AS INT) > 0 -- (Vicky04)  
            BEGIN  
               SET @cActionFlag = 'S'  

               -- TMAutoShortPick (0 = off, 1 = on for Store piece pick only, 2 = on for Ecom pick only; 3 = on for both type) (james15)
               IF @c_TMAutoShortPick NOT IN ('', '0') 
               BEGIN  
                  -- 1 all ecom pick goes to qc. store piece pick not goto qc
                  IF @c_TMAutoShortPick = '1' AND @c_PickMethod NOT LIKE 'PIECE%'
                  BEGIN
                     EXEC [dbo].[nspInsertWCSRouting]  
                      @cTaskStorer  
                     ,@cFacility  
                     ,@c_ToteNo  
                     ,'PK'  
                     ,'S' -- (Shong01) Change from S to N  
                     ,@cTaskdetailkey  
                     ,@cUserName  
                     ,0  
                     ,@b_Success          OUTPUT  
                     ,@nErrNo             OUTPUT  
                     ,@cErrMsg            OUTPUT  

                     IF @nErrNo <> 0  
                     BEGIN  
                        SET @nErrNo = @nErrNo  
                        SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'  
                        GOTO Step_9_Fail  
                     END  

                  END
                  -- 2 store piece pick goes to qc. all ecom pick not goto qc
                  ELSE IF @c_TMAutoShortPick = '2' AND @c_PickMethod LIKE 'PIECE%'
                  BEGIN
                     EXEC [dbo].[nspInsertWCSRouting]  
                      @cTaskStorer  
                     ,@cFacility  
                     ,@c_ToteNo  
                     ,'PK'  
                     ,'S' -- (Shong01) Change from S to N  
                     ,@cTaskdetailkey  
                     ,@cUserName  
                     ,0  
                     ,@b_Success          OUTPUT  
                     ,@nErrNo             OUTPUT  
                     ,@cErrMsg            OUTPUT  

                     IF @nErrNo <> 0  
                     BEGIN  
                        SET @nErrNo = @nErrNo  
                        SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'  
                        GOTO Step_9_Fail  
                     END  
                  END
               END -- @c_TMAutoShortPick = '1'  
               ELSE  
               BEGIN  
                  EXEC [dbo].[nspInsertWCSRouting]  
                      @cTaskStorer  
                     ,@cFacility  
                     ,@c_ToteNo  
                     ,'PK'  
                     ,@cActionFlag -- (Shong01)  
                     ,@cTaskdetailkey  
                     ,@cUserName  
                     ,0  
                     ,@b_Success          OUTPUT  
                     ,@nErrNo             OUTPUT  
                     ,@cErrMsg            OUTPUT  
  
                   IF @nErrNo <> 0  
                   BEGIN  
                      SET @nErrNo = @nErrNo  
                      SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'  
                      GOTO Step_9_Fail  
                   END  
               END  
            END  
            ---*** Insert into WCSRouting (End) ***---  
   
            /* Relase task if from Step is Step_7. ToteNo Screen  
             *  
             */  
            IF @nFromStep = @nStepWithToteNo AND @nFromScn = @nScnWithToteNo  
               AND ISNULL(RTRIM(@c_ToteNo),'') <> ''  
            BEGIN  
               INSERT INTO TaskManagerSkipTasks  
               (  
                  USERID,   TaskDetailKey, TaskType, Caseid, Lot,  
                  FromLoc,  ToLoc,         FromId,   ToId,   adddate  
               )  
               SELECT @cUserName, td.TaskDetailKey, td.TaskType, td.Caseid, td.Lot,  
                      td.FromLoc, td.ToLoc, td.FromID, td.ToID, GETDATE()  
               FROM   TaskDetail td WITH (NOLOCK)  
               WHERE  td.DropID = @c_ToteNo  
               AND    td.UserKey = @cUserName  
               AND    td.[Status]='3'  
  
               IF EXISTS ( SELECT  1 FROM dbo.TASKDETAIL with (NOLOCK)  
                           WHERE DropID = @c_ToteNo  
                           AND   UserKey = @cUserName  
                           AND   [Status]='3' )  
               BEGIN  
                  UPDATE dbo.TASKDETAIL  
                     SET UserKey = ''
                        ,STATUS = '0' 
                        ,Reasonkey = ''  
                        ,DropId = '' -- SOS# 248996  
                  WHERE DropID = @c_ToteNo  
                  AND   UserKey = @cUserName  
                  AND   [Status]='3' 

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 70069  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                     ROLLBACK TRAN  
                     GOTO Step_9_Fail  
                  END  
               END  
            END  
         END -- Scanned Qty = 0                   -- (Vicky02) - End  
      END  
  
      SET @nFromStep = @nStep  
      SET @nFromScn  = @nScn  
  
      SET @nScn = 2438  
      SET @nStep = 10  
      SET @cOutField01 = @cTTMTasktype -- (james05)  
      SET @cShortPickFlag = 'N'  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  

      IF @cShortPickFlag = 'Y' -- (ChewKP22)  
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
END  
GOTO Quit  
  
/********************************************************************************  
Step 10. screen = 2438 (ChewKP04)  
     MSG ( EXIT / ENTER )  
********************************************************************************/  
Step_10:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      IF (@c_PickMethod LIKE 'SINGLES%' ) -- OR @c_PickMethod = 'PIECE') -- Get Next Task  (ChewKP21)  (james11)
      BEGIN  
         -- (james03) Get the task within the same area; there is probably more than 1 zone per area  
         SELECT TOP 1 @c_CurrAREA = AD.AREAKEY, @c_CurrTaskType = td.TaskType
         FROM dbo.TaskDetail td WITH (NOLOCK)  
         JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc  
         JOIN dbo.AREADETAIL AD (NOLOCK) ON l.PUTAWAYZONE = AD.PUTAWAYZONE  
         WHERE td.TaskDetailKey = @cTaskdetailkey  
            -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first (james10)  
            AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  
                 
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                     INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                     INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                     WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        AND TD.Status = '0'  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AREAKEY = @c_CurrAREA  
                        AND LOC.Facility = @cFacility  
                        AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
                        AND TD.UserKey = ''
                        AND TD.TaskType = @c_CurrTaskType)  
         BEGIN  
            -- Get Next TaskKey  
            SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
            FROM dbo.TaskDetail TD WITH (NOLOCK)  
            INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
            WHERE TD.Loadkey = @cLoadkey  
            AND TD.PickMethod = @c_PickMethod  
            AND TD.Status = '0'  
            AND TD.TaskDetailkey <> @cTaskDetailkey  
            AND LOC.Putawayzone = @c_CurrPutawayzone  
            AND LOC.Facility = @cFacility  
            AND TD.UserKey = ''  
            AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
            AND TD.TaskType = @c_CurrTaskType
            ORDER BY LOC.LogicalLocation ASC, TD.FromLOC  
  
            -- IF current putawayzone no more task, get the task from different putawayzone but within same area  
            IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
            BEGIN  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
               WHERE TD.Loadkey = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               AND TD.Status = '0'  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND AD.AREAKEY = @c_CurrAREA  
               AND LOC.Facility = @cFacility  
               AND TD.UserKey = ''  
               AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
               AND TD.TaskType = @c_CurrTaskType
               ORDER BY LOC.LogicalLocation ASC, TD.FromLOC  
            END  
  
            SET @cTaskDetailkey = @cNextTaskdetailkeyS  
            SET @cNextTaskdetailkeyS = ''  
  
            --- GET Variable --  
            SELECT @cTaskStorer = RTRIM(Storerkey),  
                   @cSKU        = RTRIM(SKU),  
                   @cSuggID     = RTRIM(FromID),  
                   @cSuggToLoc  = RTRIM(ToLOC),  
                   @cLot        = RTRIM(Lot),  
                   @cSuggFromLoc = RTRIM(FromLoc),  
                   @nSuggQTY    = Qty,  
                   @cLoadkey    = RTRIM(Loadkey),  
                   @c_PickMethod = RTRIM(PickMethod)  
            FROM dbo.TaskDetail WITH (NOLOCK)  
            WHERE TaskDetailKey = @cTaskdetailkey  

            SELECT @c_CurrPutawayzone = Putawayzone  
            FROM LOC WITH (NOLOCK)  
            WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  

            BEGIN TRAN  
  
            Update dbo.TaskDetail WITH (ROWLOCK)  
               SET DropID = @c_ToteNo,  
                   StartTime = GETDATE(), -- (james01)  
                   EditDate = GETDATE(),  
                   EditWho = @cUserName,  
                   Trafficcop = NULL,  
                   UserKey = @cUserName,  
                   STATUS = '3',  
                   ReasonKey = '' -- (james04)  
            WHERE TaskDetailkey = @cTaskDetailKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70040  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
               ROLLBACK TRAN  
               GOTO Step_10_Fail -- (ChewKP10)  
            END  
            ELSE  
            BEGIN  
               COMMIT TRAN  
            END  
  
            -- PrePare Var for Next Screen  
            -- Reset Scan Qty to 0  
            SET @nScanQty = 0  
            SET @cShortPickFlag = 'N'  
            SET @cUserPosition = '1'  

            SET @nPrevStep = 2  

            SET @cOutField01 = @c_PickMethod  
            SET @cOutField02 = @c_ToteNo  
            SET @cOutField03 = @cSuggFromLoc  
            SET @cOutField04 = ''  
            SET @cOutField05 = @cTTMTasktype -- (james05)  

            -- There is still Task in Same Zone GOTO Screen 2  
            SET @nScn = @nScn - 7  
            SET @nStep = @nStep - 8  
            GOTO QUIT  
         END -- If Task Available in Same Zone  
         ELSE  
         BEGIN  
            BEGIN TRAN
            -- (Vickyxx) - visited should be updated upon close tote for SINGLES  
            -- Update WCSRoutingDetail Status = '1' Indicate Visited --  
            UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)  
            SET Status = '1'   ,  
            EditWho = @cUserName , EditDate = GetDate() --  (ChewKP17)  
            WHERE ToteNo = @c_ToteNo  
            AND Zone = @c_FinalPutawayzone  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70049  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
               ROLLBACK TRAN   
               GOTO Step_10_Fail -- (ChewKP10)  
            END  

            -- (Vickyxx) - Update should be done only upon close Tote  
            -- Update WCSRoutingDetail Status = '1' Indicate Visited --  
            UPDATE dbo.WCSRouting WITH (ROWLOCK)  
            SET Status = '5'  
            WHERE ToteNo = @c_ToteNo  
            AND Final_Zone = @c_FinalPutawayzone  
            AND Status < '9'  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70028  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
               ROLLBACK TRAN  
               GOTO Step_10_Fail  
            END  
            ELSE  
            BEGIN  
               COMMIT TRAN  
            END  

           -- EventLog - Sign Out Function (Chee01)  
           EXEC RDT.rdt_STD_EventLog  
             @cActionType = '9', -- Sign Out function  
             @cUserID     = @cUserName,  
             @nMobileNo   = @nMobile,  
             @nFunctionID = @nFunc,  
             @cFacility   = @cFacility,  
             @cStorerKey  = @cTaskStorer,
             @nStep       = @nStep  
                
            -- Go to Tote Close Screen  
            SET @nScn = @nScn - 1   
            SET @nStep = @nStep - 2  
            SET @cOutField01 = CASE WHEN ISNULL(@c_ToteNo, '') = '' THEN 'Tote is Closed'  
                                    ELSE RTRIM(@c_ToteNo) + ' is Closed' END  -- (jamesxx)  
            SET @cOutField02 = @cTTMTasktype -- (james05)  
            GOTO QUIT  
         END  
            -- (Vickyxx)  
      END -- ECOMM_SINGLES  
      --ELSE IF (@c_PickMethod = 'DOUBLES' OR @c_PickMethod = 'MULTIS') -- Get Next Task  -- (ChewKP21)  
      ELSE IF (@c_PickMethod LIKE 'DOUBLES%' OR @c_PickMethod LIKE 'MULTIS%' OR @c_PickMethod LIKE 'PIECE%') -- Get Next Task  -- (ChewKP21)  
      BEGIN  
         SET @c_ToteNo = ISNULL(@c_ToteNo,'')  
  
         -- (james03) Get the task within the same area; there is probably more than 1 zone per area  
         SELECT TOP 1  @c_CurrAREA = AD.AREAKEY  
         FROM dbo.TaskDetail td WITH (NOLOCK)  
         JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc  
         JOIN dbo.AREADETAIL AD (NOLOCK) ON l.PUTAWAYZONE = AD.PUTAWAYZONE  
         WHERE td.TaskDetailKey = @cTaskdetailkey  
            -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first (james10)  
            AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  
                 
         IF ISNULL(RTRIM(@c_CurrPutawayzone),'') = ''  
         BEGIN  
            SELECT @c_CurrPutawayzone = Putawayzone              FROM LOC WITH (NOLOCK)  
            WHERE LOC = @cFromLoc  
              AND Facility = @cFacility  
         END  
  
         -- (Vicky02) - GET RELATED TASK WITHIN SAME ZONE TO BE FULLFILLED TO NEW TOTE  
--         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
--                      INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
--                      WHERE TD.Loadkey = @cLoadkey  
--                      AND TD.PickMethod = @c_PickMethod  
--                      AND TD.Status = '3'  
--                  AND TD.TaskDetailkey <> @cTaskDetailkey  
--                      AND LOC.Putawayzone = @c_CurrPutawayzone  
--                      AND LOC.Facility = @cFacility  
--                      AND TD.UserKey = @cUserName  
--                      AND TD.Message03 = 'PREVFULL'  
--                      AND ISNULL(RTRIM(TD.DropID), '') <> '')  
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                      INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                      INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE                                    
                      WHERE TD.Loadkey = @cLoadkey  
                      AND TD.PickMethod = @c_PickMethod  
                      AND TD.Status = '3'  
                      AND TD.TaskDetailkey <> @cTaskDetailkey  
                      AND AD.AreaKey = @c_CurrAREA  
                      AND LOC.Facility = @cFacility  
                      AND TD.UserKey = @cUserName  
                      AND TD.Message03 = 'PREVFULL'  
                      AND ISNULL(RTRIM(TD.DropID), '') <> '')  
          BEGIN  
            -- Get Next TaskKey  
            SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
            FROM dbo.TaskDetail TD WITH (NOLOCK)  
            INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
            WHERE TD.Loadkey = @cLoadkey  
            AND TD.PickMethod = @c_PickMethod  
            AND TD.Status = '3'  
            AND TD.TaskDetailkey <> @cTaskDetailkey  
            AND LOC.Putawayzone = @c_CurrPutawayzone  
            AND LOC.Facility = @cFacility  
            AND TD.UserKey = @cUserName  
            AND TD.Message03 = 'PREVFULL'  
            AND ISNULL(RTRIM(TD.DropID), '') <> ''  
  
            IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
            BEGIN  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
               WHERE TD.Loadkey = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               AND TD.Status = '3'  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND AD.AreaKey = @c_CurrAREA  
               AND LOC.Facility = @cFacility  
               AND TD.UserKey = @cUserName  
               AND TD.Message03 = 'PREVFULL'  
               AND ISNULL(RTRIM(TD.DropID), '') <> ''  
            END  
  
            SET @cTaskDetailkey = @cNextTaskdetailkeyS  
            SET @cNextTaskdetailkeyS = ''  
  
            --- GET Variable --  
            SET @cNewToteNo = ''  
  
            BEGIN TRAN  
            -- (james01)  
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
               Starttime = GETDATE(),  
               Editdate = GETDATE(),  
               EditWho = @cUserName,  
               TrafficCOP = NULL -- (jamesxx) performance tuning  
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
  
            SELECT @cTaskStorer = RTRIM(Storerkey),  
                   @cSKU        = RTRIM(SKU),  
                   @cSuggID     = RTRIM(FromID),  
                   @cSuggToLoc  = RTRIM(ToLOC),  
                   @cLot        = RTRIM(Lot),  
                   @cSuggFromLoc   = RTRIM(FromLoc),  
                   @nSuggQTY    = Qty,  
                   @cLoadkey    = RTRIM(Loadkey),  
                   @c_PickMethod = RTRIM(PickMethod),  
                   @cOrderkey   = RTRIM(Orderkey),  
                   @cNewToteNo  = RTRIM(DropID)  
            FROM dbo.TaskDetail TD WITH (NOLOCK)  
            WHERE TaskDetailKey = @cTaskdetailkey  
  
            SELECT @c_CurrPutawayzone = Putawayzone  
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
            --SET @nScn = 2430  
            --SET @nStep = 1  
  
            IF ISNULL(RTRIM(@c_ToteNo),'') <> ISNULL(RTRIM(@cNewToteNo),'')  
            BEGIN  
               SET @c_ToteNo  = @cNewToteNo  
               SET @cOutField05 = ''  
               SET @cOutField04 = @c_PickMethod  
               SET @cOutField03 = @c_ToteNo  
               SET @cOutField09 = @cTTMTasktype -- (james05)  
               SET @nScn  = @nScnWithToteNo  
               SET @nStep = @nStepWithToteNo  
  
                  -- EventLog - Sign Out Function (Chee01)  
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
               SET @cOutField01 = @c_PickMethod  
               SET @cOutField02 = @c_ToteNo  
               SET @cOutField03 = @cSuggFromLoc  
               SET @cOutField04 = ''  
               SET @cOutField05 = @cTTMTasktype -- (james05)  
  
               SET @nScn = @nScnFromLoc  
               SET @nStep = @nStepFromLoc  
            END  
            GOTO QUIT  
          END  
          ELSE -- GET RELATED TASK WITHIN SAME ZONE SAME TOTE IN THE SAME ZONE  
--           IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
--                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
--                        WHERE TD.Loadkey = @cLoadkey  
--                        AND TD.PickMethod = @c_PickMethod  
--                        AND TD.Status = '3' -- (vicky03)  
--                        AND TD.TaskDetailkey <> @cTaskDetailkey  
--                        AND LOC.Putawayzone = @c_CurrPutawayzone  
--                        AND LOC.Facility = @cFacility  
--                        AND TD.UserKey = @cUserName  
--                        AND TD.DropID = @c_ToteNo)  
--                        --AND TD.Orderkey = @cOrderkey) -- (ChewKP03)  
  
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                        INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                        WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        AND TD.Status = '3' -- (vicky03)  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrAREA  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName  
                        AND TD.DropID = @c_ToteNo)  
    --AND TD.Orderkey = @cOrderkey) -- (ChewKP03)  
               BEGIN  
               -- Get Next TaskKey  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey = @cLoadkey  
                     AND TD.PickMethod = @c_PickMethod  
                     AND TD.Status = '3' -- (vicky03)  
                     AND TD.TaskDetailkey <> @cTaskDetailkey  
                     AND LOC.Putawayzone = @c_CurrPutawayzone  
                     AND LOC.Facility = @cFacility  
                     AND TD.UserKey = @cUserName  
                     AND TD.DropID = @c_ToteNo  
  
               IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
               BEGIN  
                  SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                  INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                  WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        AND TD.Status = '3' -- (vicky03)  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrAREA  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName  
                     AND TD.DropID = @c_ToteNo  
               END  
  
               SET @cTaskDetailkey = @cNextTaskdetailkeyS  
               SET @cNextTaskdetailkeyS = ''  
  
               BEGIN TRAN  
              -- (james01)  
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
                  Starttime = GETDATE(),  
                  Editdate = GETDATE(),  
                  EditWho = @cUserName,  
                  TrafficCOP = NULL -- (jamesxx) performance tuning  
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
               SELECT @cTaskStorer = RTRIM(Storerkey),  
                      @cSKU        = RTRIM(SKU),  
                      @cSuggID     = RTRIM(FromID),  
                      @cSuggToLoc  = RTRIM(ToLOC),  
                      @cLot        = RTRIM(Lot),  
                      @cSuggFromLoc   = RTRIM(FromLoc),  
                      @nSuggQTY    = Qty,  
                      @cLoadkey    = RTRIM(Loadkey),  
                      @c_PickMethod = RTRIM(PickMethod),  
                      @cOrderkey   = RTRIM(Orderkey) -- (ChewKP03)  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cTaskdetailkey  
  
               SELECT @c_CurrPutawayzone = Putawayzone  
               FROM LOC WITH (NOLOCK)  
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
  
               -- PrePare Var for Next Screen  
               -- Reset Scan Qty to 0  
  
               SET @nScanQty = 0  
               SET @cShortPickFlag = 'N'  
               SET @cUserPosition = '1'  
  
               SET @nPrevStep = 1  
  
               SET @cOutField01 = @c_PickMethod  
               SET @cOutField02 = @c_ToteNo  
               SET @cOutField03 = @cSuggFromLoc  
               SET @cOutField04 = ''  
               SET @cOutField05 = @cTTMTasktype -- (james05)  
  
  
               IF ISNULL(RTRIM(@c_ToteNo),'') = ''  
               BEGIN  
                  SET @nScn = @nScnEmptyTote  
                  SET @nStep = @nStepEmptyTote  
  
                  -- EventLog - Sign Out Function (Chee01)  
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
                  -- There is still Task in Same Zone GOTO Screen 2  
                  SET @nScn = @nScnFromLoc  
                  SET @nStep = @nStepFromLoc  
               END  
               GOTO QUIT  
  
            END  
            ELSE  
            -- GET RELATED TASK WITHIN SAME ZONE  
--            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
--                        INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
--                        WHERE TD.Loadkey = @cLoadkey  
--                        AND TD.PickMethod = @c_PickMethod  
--                        --AND TD.Status IN ('0', '3' )  
--                        AND TD.Status = '3' -- (vicky03)  
--                        AND TD.TaskDetailkey <> @cTaskDetailkey  
--                        AND LOC.Putawayzone = @c_CurrPutawayzone  
--                        AND LOC.Facility = @cFacility  
--                        AND TD.UserKey = @cUserName)  
--                        --AND TD.Orderkey = @cOrderkey) -- (ChewKP03)  
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                 INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                        INNER JOIN dbo.AreaDetail AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                        WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        --AND TD.Status IN ('0', '3' )  
                        AND TD.Status = '3' -- (vicky03)  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrArea  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName)  
                        --AND TD.Orderkey = @cOrderkey) -- (ChewKP03)  
            BEGIN  
            -- Get Next TaskKey  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey = @cLoadkey  
                     AND TD.PickMethod = @c_PickMethod  
--                   AND TD.Status IN ('0', '3' )  
                     AND TD.Status = '3' -- (vicky03)  
                     AND TD.TaskDetailkey <> @cTaskDetailkey  
                     AND LOC.Putawayzone = @c_CurrPutawayzone  
                     AND LOC.Facility = @cFacility  
                     AND TD.UserKey = @cUserName  
                     --AND TD.Orderkey = @cOrderkey -- (ChewKP03)  
  
               IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
               BEGIN  
                  SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                  INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON AD.PUTAWAYZONE = LOC.PUTAWAYZONE  
                  WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        AND TD.Status = '3' -- (vicky03)  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrAREA  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName  
               END  
  
               SET @cTaskDetailkey = @cNextTaskdetailkeyS  
               SET @cNextTaskdetailkeyS = ''  
  
               BEGIN TRAN  
               -- (james01)  
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
                  Starttime = GETDATE(),  
                  Editdate = GETDATE(),  
                  EditWho = @cUserName,  
                  TrafficCOP = NULL -- (jamesxx) performance tuning  
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
               SELECT @cTaskStorer = RTRIM(Storerkey),  
                      @cSKU        = RTRIM(SKU),  
                      @cSuggID     = RTRIM(FromID),  
                      @cSuggToLoc  = RTRIM(ToLOC),  
                      @cLot        = RTRIM(Lot),  
                      @cSuggFromLoc   = RTRIM(FromLoc),  
                      @nSuggQTY    = Qty,  
                      @cLoadkey    = RTRIM(Loadkey),  
                      @c_PickMethod = RTRIM(PickMethod),  
                      @cOrderkey   = RTRIM(Orderkey), -- (ChewKP03)  
                      @c_ToteNo    = RTRIM(DropID)  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cTaskdetailkey  
  
               SELECT @c_CurrPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)  
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
  
  
               -- PrePare Var for Next Screen  
               -- Reset Scan Qty to 0  
  
               SET @nScanQty = 0  
               SET @cShortPickFlag = 'N'  
               SET @cUserPosition = '1'  
  
               SET @nPrevStep = 1  
  
  
               IF ISNULL(RTRIM(@c_ToteNo),'') = ''  
               BEGIN  
                  SET @nScn = @nScnEmptyTote  
                  SET @nStep = @nStepEmptyTote  
  
                  -- EventLog - Sign Out Function (Chee01)  
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
                  -- There is still Task in Same Zone GOTO Screen 2  
                  SET @cOutField01 = @c_PickMethod  
                  SET @cOutField02 = @c_ToteNo  
                  SET @cOutField03 = @cSuggFromLoc  
                  SET @cOutField04 = ''  
                  SET @cOutField05 = @cTTMTasktype  -- (james05)  
  
                  SET @nScn = @nScnFromLoc  
                  SET @nStep = @nStepFromLoc  
               END  
  
  
               -- There is still Task in Same Zone GOTO Screen 2  
               --SET @nScn = @nScnFromLoc  
               --SET @nStep = @nStepFromLoc  
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
               WHERE TD.Loadkey = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               --AND TD.Status IN ('0', '3' )  
               AND TD.Status = '3' -- (vicky03)  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND TD.UserKey = @cUserName  
               AND LOC.Putawayzone <> @c_CurrPutawayzone -- (vicky03)  
               --AND TD.Orderkey = @cOrderkey -- (ChewKP03)  
               --AND LOC.Putawayzone = @c_CurrPutawayzone  
               --AND LOC.Facility = @cFacility  
  
               OPEN CursorReleaseTask  
               FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey  
               WHILE @@FETCH_STATUS <> -1  
               BEGIN  
                  Update dbo.TaskDetail WITH (ROWLOCK)  
                  SET Status = '0', UserKey = '' , TrafficCop = NULL -- (Vicky01)  
                  WHERE TaskDetailkey = @c_RTaskDetailkey  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                        SET @nErrNo = 70066  
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
                           --AND Orderkey = @cOrderkey -- (ChewKP03)  
                           --AND Userkey = @cUserName -- (ChewKP05)  
                           AND PickMethod = @c_PickMethod -- (ChewKP05)  
                           AND DropID = @c_ToteNo   -- (ChewKP05)  
                           AND Status IN ('0','3')  -- (ChewKP05)  
                           AND TaskDetailkey <> @cTaskDetailkey  
        )  
               BEGIN  
                  -- Go to Order Fulli by Other Zone Screen  
  
                  -- (ChewKP19)  
                  IF EXISTS (SELECT 1 FROM dbo.TaskManagerSkipTasks WITH (NOLOCK)  
                             WHERE TaskDetailkey = @cTaskDetailkey  )  
                  BEGIN  
                     -- Go to Tote Close Screen  2437  
                     SET @nScn = 2437  
                     SET @nStep = 8  
                     SET @cOutField01 = '' -- (jamesxx)  
                     SET @cOutField02 = @cTTMTasktype  -- (james05)  
                     GOTO QUIT  
  
                  END  
                  ELSE  
                  BEGIN  
  
                     SET @nScn = 2435  
                     SET @nStep = 6  
                     SET @cOutField01 = @cTTMTasktype  -- (james05)  
                     GOTO QUIT  
                  END  
               END  
               ELSE  
               BEGIN  
                  -- Go to Tote Close Screen  
                  SET @nScn = 2437  
                  SET @nStep = 8  
                  SET @cOutField01 = '' -- (jamesxx)  
                  SET @cOutField02 = @cTTMTasktype  -- (james05)  
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
       -- Release ALL Task from Users when EXIT TM -- (ChewKP12)  
       BEGIN TRAN  
       -- (Shong03)  
       -- Release ALL Task from Users when EXIT TM --  
       -- IF @c_PickMethod IN ('PIECE','SINGLES')     -- (james11)
       IF @c_PickMethod LIKE 'PIECE%' OR @c_PickMethod LIKE 'SINGLES%' 
       BEGIN  
          Update dbo.TaskDetail WITH (ROWLOCK)  
             SET Status = '0' , Userkey = '', DropID = '', Message03 = '' -- (vicky03) -- should also update DropID for Close Tote  
                ,TrafficCop = NULL  
                ,EditDate = GETDATE()  
                ,EditWho = SUSER_SNAME()  
          WHERE Userkey = @cUserName  
          AND Status = '3'  
       END  
       ELSE  
       BEGIN  
          Update dbo.TaskDetail WITH (ROWLOCK)  
             SET Status = '0',  
                 Userkey = '',  
                 TrafficCop = NULL,  
                 EditDate = GETDATE(),  
                 EditWho = SUSER_SNAME()  
          WHERE Userkey = @cUserName  
          AND Status = '3'  
       END  
  
       IF @@ERROR <> 0  
       BEGIN  
             SET @nErrNo = 70080  
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
      SET @cOutField09 = '' -- (james05)  
  
      SET @nPrevStep = 0  
  
      GOTO QUIT  
   END  
   GOTO Quit  
  
END  
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
      SET @nToFunc = 0  
     SET @nToScn = 0  
      SET @nPrevStep = @nStep  
  
      SET @cOutField04 = @c_PickMethod  
      SET @nScn = 2430 -- Tote No Screen  
      SET @nStep = 1  
      SET @cOutField09 = @cTTMTasktype  
   END  
END  
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
-- (Shong05)  
--      IF EXISTS(SELECT 1 FROM TaskDetail td WITH (NOLOCK)  
--                WHERE DropID = @cNewToteNo  
--                AND td.UserKey <> @cUserName  
--                AND STATUS ='3'  
--                AND td.TaskType='PK')  
--      BEGIN  
--         SET @nErrNo = 70076  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --70076^Tote In Used  
--         GOTO Step_12_Fail  
--      END  
  
      SELECT @c_CurrPutawayzone = LOC.PutawayZone  
      FROM   TaskDetail td WITH (NOLOCK)  
      JOIN   LOC WITH (NOLOCK) ON LOC.LOC = TD.FromLoc  
      WHERE  td.TaskDetailKey = @cTaskDetailkey  
  
      SELECT TOP 1 @c_CurrAREA = AD.AREAKEY, @c_CurrTaskType = td.TaskType
      FROM dbo.TaskDetail td WITH (NOLOCK)  
      JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc  
      JOIN dbo.PUTAWAYZONE P (NOLOCK) ON L.PUTAWAYZONE = P.PUTAWAYZONE  
      JOIN dbo.AREADETAIL AD (NOLOCK) ON P.PUTAWAYZONE = AD.PUTAWAYZONE  
      WHERE td.TaskDetailKey = @cTaskdetailkey  
         -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first (james10)  
         AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  
                 
      -- Get Next TaskKey  
      SET @cNextTaskdetailkeyS = ''  
  
      SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
      FROM dbo.TaskDetail TD WITH (NOLOCK)  
      INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
      INNER JOIN dbo.PUTAWAYZONE P (NOLOCK) ON LOC.PUTAWAYZONE = P.PUTAWAYZONE  
      INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON P.PUTAWAYZONE = AD.PUTAWAYZONE  
      WHERE TD.Status IN ('0','3') -- (Shong05)  
        AND TD.TaskDetailkey <> @cTaskDetailkey  
--        AND LOC.Putawayzone = @c_CurrPutawayzone  
        AND AD.AreaKey = @c_CurrAREA  
        AND LOC.Facility = @cFacility  
        -- AND TD.UserKey = '' -- (Shong05)  
        AND TD.DropID = @cNewToteNo  
        AND TD.TaskType = @c_CurrTaskType

      IF ISNULL(RTRIM(@cNextTaskdetailkeyS),'') = ''  
      BEGIN  
         SET @nErrNo = 70057  
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
              StartTime = GETDATE(), -- (Shong05)  
              TrafficCop=NULL,  
              ReasonKey = '' -- (james04)  
       WHERE DropID = @cNewToteNo  
       AND Status IN ('0','3')  
       -- AND   UserKey = '' (Shong05)  
       AND   DropID <> ''  
       IF @@ERROR <> 0  
       BEGIN  
          SET @nErrNo = 70040  
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
            SET @nErrNo = 70040  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
            ROLLBACK TRAN  
            GOTO Step_12_Fail  
         END  
      END  
  
      SET @cTaskDetailkey = @cNextTaskdetailkeyS  
      SET @cNextTaskdetailkeyS = ''  
  
      --- GET Variable --  
      SELECT @cTaskStorer = RTRIM(Storerkey),  
             @cSKU        = RTRIM(SKU),  
             @cSuggID     = RTRIM(FromID),  
             @cSuggToLoc  = RTRIM(ToLOC),  
             @cLot        = RTRIM(Lot),  
             @cSuggFromLoc   = RTRIM(FromLoc),  
             @nSuggQTY    = Qty,  
             @cLoadkey    = RTRIM(Loadkey),  
             @c_PickMethod = RTRIM(PickMethod),  
             @cOrderkey   = RTRIM(Orderkey) -- (ChewKP03)  
      FROM dbo.TaskDetail WITH (NOLOCK)  
      WHERE TaskDetailKey = @cTaskdetailkey  
  
      SELECT @c_CurrPutawayzone = Putawayzone  
      FROM LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
  
      SET @nScanQty = 0  
      SET @cUserPosition = '1'  
  
      SET @c_ToteNo = @cNewToteNo  
      SET @nPrevStep = @nStep  
      SET @cOutField01 = @c_PickMethod  
      SET @cOutField02 = @c_ToteNo  
      SET @cOutField03 = @cSuggFromLoc  
      SET @cOutField04 = ''  
      SET @cOutField05 = @cTTMTasktype  -- (james05)  
  
      -- There is still Task in Same Zone GOTO Screen 2  
      SET @nScn = @nScnFromLoc  
      SET @nStep = @nStepFromLoc  
  
      SET @nToFunc = 0  
      SET @nToScn = 0  
  
      -- EventLog - Sign In Function (Chee01)  
      EXEC RDT.rdt_STD_EventLog  
         @cActionType = '1', -- Sign in function  
         @cUserID     = @cUserName,  
         @nMobileNo   = @nMobile,  
         @nFunctionID = @nFunc,  
         @cFacility   = @cFacility,  
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep  
   END  
  
   IF @nInputKey =0 -- Either ESC or ENTER  
   BEGIN  
      SET @nToFunc = 0  
      SET @nToScn = 0  
      SET @nPrevStep = @nStep  
  
      SET @cOutField04 = @c_PickMethod  
      SET @cOutField03 = @c_ToteNo  
      SET @cOutField09 = @cTTMTasktype  
      SET @nScn = 2436  
      SET @nStep = 7  
   END  
  
   Step_12_Fail:  
   GOTO QUIT  
END  
GOTO Quit  
  
/********************************************************************************  
Step 13. screen = 2790                -- (james06)  
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
         SET @nErrNo = 70087  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req  
         GOTO Step_ConfirmTote_Fail  
      END  
  
      -- Validate blank  
      IF @cOption NOT IN ('1', '9')  
      BEGIN  
         SET @nErrNo = 70088  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         GOTO Step_ConfirmTote_Fail  
      END  
  
      IF @cOption = '1'  
      BEGIN  
         SET @nScn = @nFromScn  
         SET @nStep = @nFromStep  
  
         SELECT @cModuleName = Message_Text FROM RDT.RDTMSG WITH (NOLOCK) WHERE Message_ID = @nFunc  
         SET @cAlertMessage = 'Confirm Tote ' + LTRIM(RTRIM(@c_ToteNo)) + ' Same As SKU by ' + LTRIM(RTRIM(@cUserName)) + '.'  
  
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
         SET @cOutField04 = @c_PickMethod  
         SET @cOutField05 = ''  
         SET @cOutField09 = @cTTMTasktype  
  
         SET @nScn  = @nFromScn  
         SET @nStep = @nFromStep  
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      --prepare next screen variable  
      SET @cOutField04 = @c_PickMethod  
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
END  
GOTO Quit  

/********************************************************************************  
Step 14. screen = 2791 ALT LOC  
     TOTE      (Field01, display)
     CUR LOC   (Field02, display)
     ALT LOC   (Field03, display)
     QTY       (Field04, display)
     SKU       (Field05, display)
     SKU       (Field06, input)
********************************************************************************/  
Step_14:  
BEGIN  
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
      SET @cSuggAltLoc = ISNULL(@cOutField03,'')  
      SET @cAltLoc = ISNULL(@cInField05,'')  
  
      IF @cAltLoc = ''  
      BEGIN  
         SET @nErrNo = 70096  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Alt Loc Req  
         GOTO Step_14_Fail  
      END  
  
      IF ISNULL(@cAltLoc,'') <> ISNULL(@cSuggAltLoc ,'')  
      BEGIN  
         SET @nErrNo = 70097  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Alt Loc  
         GOTO Step_14_Fail  
      END  

      -- Piece Picking Therefore UOM will be Lowest Unit --  
      SELECT @cDescr1 = SUBSTRING(SKU.DESCR, 1, 20),  
             @cDescr2 = SUBSTRING(SKU.DESCR,21, 20),  
             @cUOM    = P.PackUOM3 -- Each  
      FROM dbo.SKU SKU WITH (NOLOCK)  
      INNER JOIN dbo.PACK P WITH (NOLOCK) ON ( P.Packkey = SKU.Packkey )  
      WHERE  SKU.SKU = @cSKU  
      AND    SKU.Storerkey = @cTaskStorer 
  
      -- prepare next screen  
      SET @nScanQty = 0  
      SET @cShortPickFlag = 'N'  
      SET @cFromLoc = @cAltLoc

      SET @cOutField01 = @c_ToteNo  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = @cDescr1  
      SET @cOutField04 = @cDescr2  
      SET @cOutField05 = ''  
      SET @cOutField06 = @cUOM  
      SET @cOutField07 = @nScanQty  
      SET @cOutField08 = @nSuggQTY  
      SET @cOutField09 = @cAltLoc 
      SET @cOutField10 = @cTTMTasktype  

      -- (james17)
      SET @cTaskType2EnableBulkPicking = rdt.RDTGetConfig( @nFunc, 'TaskType2EnableBulkPicking', @cTaskStorer)

      IF @cTaskType2EnableBulkPicking = 'ALL' OR 
         @cTaskType2EnableBulkPicking = @cTTMTasktype
      BEGIN
         SET @cOutField11 = 'ENTER QTY:'
         SET @cOutField12 = ''
         SET @cFieldAttr12 = '' -- Enable the qty field
      END
      ELSE
      BEGIN
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         SET @cFieldAttr12 = 'O' -- disable the qty field
      END

      SET @cUserPosition = '1' -- (ChewKP01)  
  
 
      -- Go to next screen  
      SET @nScn = 2432  
      SET @nStep = @nStep - 11  
   END
   GOTO Quit

   Step_14_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cOutField05 = ''
   END  
END
GOTO Quit

/********************************************************************************  
Step 15. screen = 2792 LOC EMPTY
     OPTION      (Field01, display)

********************************************************************************/  
Step_15:  
BEGIN  
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

      --screen mapping  
      SET @cOption = @cInField02  
  
      IF ISNULL(@cOption, '') = '' 
      BEGIN  
         SET @nErrNo = 70099  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'  
         GOTO Step_15_Fail01  
      END  
  
      --IF @cSHTOption NOT IN ('1', '9')  
      IF @cOption NOT IN ('1', '9')
      BEGIN  
         SET @nErrNo = 70100  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'  
         GOTO Step_15_Fail01  
      END  
  
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cTaskStorer)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cTaskDetailKey, @cAreaKey, @cFromLOC, @cSKU, @nPickQty, @cToteNo, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' + 
            '@cLangCode       NVARCHAR( 3),  ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cTaskDetailKey  NVARCHAR( 10), ' +
            '@cAreaKey        NVARCHAR( 10), ' +
            '@cFromLOC        NVARCHAR( 10), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nPickQty        INT, ' +
            '@cToteNo         NVARCHAR( 18), ' +
            '@nAfterStep      INT,           ' + 
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cTaskStorer, @cTaskDetailKey, @cAreaKey, @cFromLOC, @cSKU, @cOption, @c_ToteNo, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_15_Fail01

         -- Retrieve Next Task (If Doubles / Multis Should Retrieve Same Task Within same zone ) -- SINGLES -- MULTIS - DOUBLES -- PIECE  
  
         --    /**************************************/  
         --    /* E-COMM SINGLES  (START)            */  
         --    /* Update WCSRouting                  */  
         --    /* Call TMTM01 for Next Task          */  
         --    /**************************************/  
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN

         SAVE TRAN Step_15_UPD
         
         IF @c_PickMethod LIKE 'SINGLES%'  -- (james11)
         BEGIN  
            -- Update TaskDetail STatus = '9'  
            Update dbo.TaskDetail WITH (ROWLOCK)  
            SET Status = '9' ,  
                EndTime = GETDATE(),  
                EditDate = GETDATE(), 
                EditWho = sUser_sName(),  
                TrafficCop = NULL 
            WHERE TaskDetailkey = @cTaskDetailKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70031  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
               ROLLBACK TRAN Step_15_UPD
               GOTO Step_15_Fail02 
            END  
  
            -- Reset Scan Qty to 0  
            SET @nScanQty = 0  
            SET @cShortPickFlag = 'N'  
  
            -- (james03) Get the task within the same area; there is probably more than 1 zone per area  
            SELECT TOP 1 @c_CurrAREA = AD.AREAKEY, @c_CurrTaskType = td.TaskType
            FROM dbo.TaskDetail td WITH (NOLOCK)  
            JOIN dbo.LOC l (NOLOCK) ON td.FromLoc = l.Loc  
            JOIN dbo.AREADETAIL AD (NOLOCK) ON l.PUTAWAYZONE = AD.PUTAWAYZONE  
            WHERE td.TaskDetailKey = @cTaskdetailkey  
               -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first (james10)  
               AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  
                 
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                        INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                        WHERE TD.Loadkey = @cLoadkey  
                           AND TD.PickMethod = @c_PickMethod  
                           AND TD.Status = '0'  
                           AND TD.TaskDetailkey <> @cTaskDetailkey  
                           AND AD.AREAKEY = @c_CurrAREA  
                           AND LOC.Facility = @cFacility  
                           AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
                           AND TD.UserKey = ''
                           AND TD.TaskType = @c_CurrTaskType)  
            BEGIN  
               -- Get Next TaskKey  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               AND TD.Status = '0'  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND LOC.Putawayzone = @c_CurrPutawayzone  
               AND LOC.Facility = @cFacility  
               AND TD.UserKey = ''  
               AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
               AND TD.TaskType = @c_CurrTaskType
               ORDER BY LOC.LogicalLocation ASC, TD.FromLOC  
  
               -- IF current putawayzone no more task, get the task from different putawayzone but within same area  
               IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
               BEGIN  
                  SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                  INNER JOIN dbo.AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                  WHERE TD.Loadkey = @cLoadkey  
                  AND TD.PickMethod = @c_PickMethod  
                  AND TD.Status = '0'  
                  AND TD.TaskDetailkey <> @cTaskDetailkey  
                  AND AD.AREAKEY = @c_CurrAREA  
                  AND LOC.Facility = @cFacility  
                  AND TD.UserKey = ''  
                  AND TD.DropID = '' -- Should filter by DropID, Otherwise will overwritten by this task with diff DropID (Shong01)  
                  AND TD.TaskType = @c_CurrTaskType
                  ORDER BY LOC.LogicalLocation ASC, TD.FromLOC  
               END  
  
               SET @cTaskDetailkey = @cNextTaskdetailkeyS  
               SET @cNextTaskdetailkeyS = ''  
  
               --- GET Variable --  
               SELECT @cTaskStorer = RTRIM(Storerkey),  
                      @cSKU        = RTRIM(SKU),  
                      @cSuggID     = RTRIM(FromID),  
                      @cSuggToLoc  = RTRIM(ToLOC),  
                      @cLot        = RTRIM(Lot),  
                      @cSuggFromLoc = RTRIM(FromLoc),  
                      @nSuggQTY    = Qty,  
                      @cLoadkey    = RTRIM(Loadkey),  
                      @c_PickMethod = RTRIM(PickMethod)  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cTaskdetailkey  
  
               SELECT @c_CurrPutawayzone = Putawayzone  
               FROM LOC WITH (NOLOCK)  
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
  
               Update dbo.TaskDetail WITH (ROWLOCK)  
                  SET DropID = @c_ToteNo,  
                      StartTime = GETDATE(), 
                      EditDate = GETDATE(),  
                      EditWho = sUser_sName(),  
                      Trafficcop = NULL,  
                      UserKey = sUser_sName(),  
                      STATUS = '3',  
                      ReasonKey = '' 
               WHERE TaskDetailkey = @cTaskDetailKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70040  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                  ROLLBACK TRAN Step_15_UPD
                  GOTO Step_15_Fail02 
               END  

               -- PrePare Var for Next Screen  
               -- Reset Scan Qty to 0  
               SET @nScanQty = 0  
               SET @cShortPickFlag = 'N'  
               SET @cUserPosition = '1'  
  
               SET @nPrevStep = 2  
  
               SET @cOutField01 = @c_PickMethod  
               SET @cOutField02 = @c_ToteNo  
               SET @cOutField03 = @cSuggFromLoc  
               SET @cOutField04 = ''  
               SET @cOutField05 = @cTTMTasktype -- (james05)  

               -- There is still Task in Same Zone GOTO Screen 2  
               SET @nScn = @nFromScn - 1  
               SET @nStep = @nFromStep - 1  

               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                  COMMIT TRAN Step_15_UPD  
               GOTO QUIT  
            END -- If Task Available in Same Zone  
            ELSE  
            BEGIN  
               -- (Vickyxx) - visited should be updated upon close tote for SINGLES  
               -- Update WCSRoutingDetail Status = '1' Indicate Visited --  
               UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)  
               SET Status = '1'   ,  
               EditWho = @cUserName , EditDate = GetDate() --  (ChewKP17)  
               WHERE ToteNo = @c_ToteNo  
               AND Zone = @c_FinalPutawayzone  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70049  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
                  ROLLBACK TRAN Step_15_UPD
                  GOTO Step_15_Fail02 
               END  
  
               -- (Vickyxx) - Update should be done only upon close Tote  
               -- Update WCSRoutingDetail Status = '1' Indicate Visited --  
               UPDATE dbo.WCSRouting WITH (ROWLOCK)  
               SET Status = '5'  
               WHERE ToteNo = @c_ToteNo  
               AND Final_Zone = @c_FinalPutawayzone  
               AND Status < '9'  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70028  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
                  ROLLBACK TRAN Step_15_UPD
                  GOTO Step_15_Fail02 
               END  
  
               -- Go to Tote Close Screen  
               SET @nScn = @nFromScn + 5  
               SET @nStep = @nFromStep + 5  
               SET @cOutField01 = CASE WHEN ISNULL(@c_ToteNo, '') = '' THEN 'Tote is Closed'  
                                       ELSE RTRIM(@c_ToteNo) + ' is Closed' END  -- (jamesxx)  
               SET @cOutField02 = @cTTMTasktype -- (james05)  

               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                  COMMIT TRAN Step_15_UPD  

               GOTO QUIT  
            END  
            -- (Vickyxx)  
         END -- ECOMM_SINGLES  
         --    /**************************************/  
         --    /* E-COMM SINGLES / PIECE  (END)      */  
         --    /* Update WCSRouting              */  
         --    /* Call TMTM01 for Next Task          */  
         --    /**************************************/  
  
         --    /***************************************/  
         --    /* E-COMM DOUBLES , MULTIS (START)    */  
         --    /* Update WCSRouting                  */  
         --    /* Call TMTM01 for Next Task          */  
         --    /**************************************/  
         IF @c_PickMethod LIKE 'DOUBLES%' OR -- (james11)
            @c_PickMethod LIKE 'MULTIS%' OR 
            @c_PickMethod LIKE 'PIECE%'  
         BEGIN  
            -- Update TaskDetail STatus = '9'  
            Update dbo.TaskDetail WITH (ROWLOCK)  
            SET Status = '9' ,  
                EndTime = GETDATE(), --CURRENT_TIMESTAMP ,  -- (Vicky02)  
                EditDate = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
                EditWho = @cUserName, -- (ChewKP05)  
                TrafficCop = NULL   -- tlting01  
            WHERE TaskDetailkey = @cTaskDetailKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 70036  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
               ROLLBACK TRAN Step_15_UPD
               GOTO Step_15_Fail02 
            END  
  
            -- (james03) Get the task within the same area; there is probably more than 1 zone per area  
            SELECT TOP 1 @c_CurrAREA = AD.AREAKEY, @c_CurrTaskType = td.TaskType
            FROM dbo.TaskDetail td WITH (NOLOCK)  
            JOIN dbo.LOC LOC (NOLOCK) ON td.FromLoc = LOC.Loc  
            JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
            WHERE td.TaskDetailKey = @cTaskdetailkey  
               -- 1 zone might exists in multiple area. Consider the area that user entered from area screen first (james10)  
               AND AD.AreaKey = CASE WHEN ISNULL(@cAreaKey, '') <> '' THEN @cAreaKey ELSE AD.AreaKey END  
                 
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)  
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                        INNER JOIN dbo.AREADETAIL AD (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                        WHERE TD.Loadkey = @cLoadkey  
                        AND TD.PickMethod = @c_PickMethod  
                        AND TD.Status = '3' -- (vicky03)  
                        AND TD.TaskDetailkey <> @cTaskDetailkey  
                        AND AD.AreaKey = @c_CurrAREA  
                        AND LOC.Facility = @cFacility  
                        AND TD.UserKey = @cUserName
                        AND TD.TaskType = @c_CurrTaskType)  
            BEGIN  
               -- Get Next TaskKey  
               SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
               FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               WHERE TD.Loadkey = @cLoadkey  
               AND TD.PickMethod = @c_PickMethod  
               AND TD.Status = '3' -- (vicky03)  
               AND TD.TaskDetailkey <> @cTaskDetailkey  
               AND LOC.Putawayzone = @c_CurrPutawayzone  
               AND LOC.Facility = @cFacility  
               AND TD.UserKey = @cUserName  
               AND TD.TaskType = @c_CurrTaskType
               ORDER BY LOC.LogicalLocation ASC, TD.FromLOC -- (SHONG07)  
               --AND TD.Orderkey = @cOrderkey -- (ChewKP03)  
  
               IF ISNULL(@cNextTaskdetailkeyS, '') = ''  
               BEGIN  
                  SELECT TOP 1 @cNextTaskdetailkeyS = TaskDetailkey  
                  FROM dbo.TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
                  INNER JOIN AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
                  WHERE TD.Loadkey = @cLoadkey  
                  AND TD.PickMethod = @c_PickMethod  
                  AND TD.Status = '3' -- (vicky03)  
                  AND TD.TaskDetailkey <> @cTaskDetailkey  
                  AND AD.AreaKey = @c_CurrAREA  
                  AND LOC.Facility = @cFacility  
                  AND TD.UserKey = @cUserName  
                  AND TD.TaskType = @c_CurrTaskType
                  ORDER BY LOC.LogicalLocation ASC, TD.FromLOC -- (SHONG07)  
               END  
  
               SET @cTaskDetailkey = @cNextTaskdetailkeyS  
               SET @cNextTaskdetailkeyS = ''  
  
               -- (james01)  
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
                  Starttime = GETDATE(),  
                  Editdate = GETDATE(),  
                  EditWho = @cUserName,  
                  TrafficCOP = NULL -- (jamesxx) performance tuning  
               WHERE TaskDetailKey = @cTaskdetailkey  
               AND STATUS <> '9'  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 70195  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                  ROLLBACK TRAN Step_15_UPD
                  GOTO Step_15_Fail02 
               END  
  
               --- GET Variable --  
               SELECT @cTaskStorer = RTRIM(Storerkey),  
                      @cSKU        = RTRIM(SKU),  
                      @cSuggID     = RTRIM(FromID),  
                      @cSuggToLoc  = RTRIM(ToLOC),  
                      @cLot        = RTRIM(Lot),  
                      @cSuggFromLoc = RTRIM(FromLoc),  
                      @nSuggQTY    = Qty,  
                      @cLoadkey    = RTRIM(Loadkey),  
                      @c_PickMethod = RTRIM(PickMethod),  
                      @cOrderkey   = RTRIM(Orderkey) -- (ChewKP03)  
               FROM dbo.TaskDetail WITH (NOLOCK)  
               WHERE TaskDetailKey = @cTaskdetailkey  
  
               SELECT @c_CurrPutawayzone = Putawayzone FROM LOC WITH (NOLOCK)  
               WHERE LOC = @cSuggFromLoc AND Facility = @cFacility  
  
               -- PrePare Var for Next Screen  
               -- Reset Scan Qty to 0  
               SET @nScanQty = 0  

               SET @cUserPosition = '1'  

               SET @nPrevStep = 1  

               SET @cOutField01 = @c_PickMethod  
               SET @cOutField02 = @c_ToteNo  
               SET @cOutField03 = @cSuggFromLoc  
               SET @cOutField04 = ''  
               SET @cOutField05 = @cTTMTasktype -- (james05)  
  
               -- There is still Task in Same Zone GOTO Screen 2  
               SET @nScn = @nFromScn - 1  
               SET @nStep = @nFromStep - 1  

               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                  COMMIT TRAN Step_15_UPD  

               GOTO QUIT  
            END  
            ELSE  
            BEGIN  
               -- No More Task in Same Zone  
               -- Update LOCKED Task to Status = '0' and Userkey = '' For PickUp by Next Zone  
               DECLARE CursorReleaseTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT TaskDetailkey  FROM dbo.TaskDetail TD WITH (NOLOCK)  
               INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.Loc = TD.FromLoc  
               INNER JOIN AREADETAIL AD WITH (NOLOCK) ON LOC.PUTAWAYZONE = AD.PUTAWAYZONE  
               WHERE TD.Loadkey = @cLoadkey  
                     AND TD.PickMethod = @c_PickMethod  
                     AND TD.Status = '3' -- (vicky03)  
                     AND TD.TaskDetailkey <> @cTaskDetailkey  
                     AND TD.UserKey = @cUserName  
                     AND AD.AreaKey <> @c_CurrAREA  
  
               OPEN CursorReleaseTask  
               FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey  
               WHILE @@FETCH_STATUS <> -1  
               BEGIN  

                  Update dbo.TaskDetail WITH (ROWLOCK)  
                  SET Status = '0', UserKey = '' ,Trafficcop = NULL -- (Vicky01)  
                  WHERE TaskDetailkey = @c_RTaskDetailkey  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 70039  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
                     ROLLBACK TRAN Step_15_UPD
                     CLOSE CursorReleaseTask  
                     DEALLOCATE CursorReleaseTask  
                     GOTO Step_15_Fail02 
                  END  
  
                  FETCH NEXT FROM CursorReleaseTask INTO @c_RTaskDetailkey  
               END  
               CLOSE CursorReleaseTask  
               DEALLOCATE CursorReleaseTask  
  
               -- Reset Scan Qty to 0  
               SET @nScanQty = 0  

               IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                           WHERE Loadkey = @cLoadkey  
                           AND PickMethod = @c_PickMethod -- (ChewKP05)  
                           AND DropID = @c_ToteNo   -- (ChewKP05)  
                           AND Status = '0'  -- (vicky03)  
                           AND TaskDetailkey <> @cTaskDetailkey  
                           )  
               BEGIN  
                  -- Go to Fullfill by Other Picker MSG Screen  
                  SET @cOutField01 = @cTTMTasktype -- (james05)  
                  SET @nScn = @nFromScn + 3  
                  SET @nStep = @nFromStep + 3  

                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                     COMMIT TRAN Step_15_UPD  

                  GOTO QUIT  
               END  
               ELSE  
               BEGIN  
                  -- Update WCSRouting Status = '5'  
                  UPDATE dbo.WCSRouting WITH (ROWLOCK)  
                  SET Status = '5'  
                  WHERE ToteNo = @c_ToteNo  
                  AND Final_Zone = @c_FinalPutawayzone  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 70050  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSFailed'  
                     ROLLBACK TRAN Step_15_UPD
                     GOTO Step_15_Fail02 
                  END  
  
                  -- Go to Tote Close Screen  -- 2437  
                  SET @nScn = @nFromScn + 5  
                  SET @nStep = @nFromStep + 5  
                  SET @cOutField01 = CASE WHEN ISNULL(@c_ToteNo, '') = '' THEN 'Tote is Closed'  
                                          ELSE RTRIM(@c_ToteNo) + ' is Closed' END  -- (jamesxx)  
                  SET @cOutField02 = @cTTMTasktype -- (james05) 

                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                     COMMIT TRAN Step_15_UPD  

                  GOTO QUIT  
               END  
            END  
         END  
      END  
   END

   Step_15_Fail01:  
   BEGIN  
      -- Reset this screen var  
      SET @cOutField02 = ''
   END  
   GOTO Quit

   Step_15_Fail02:
   BEGIN
      -- Reset this screen var  
      SET @cOutField01 = @c_ToteNo  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = @cDescr1  
      SET @cOutField04 = @cDescr2  
      SET @cOutField05 = ''  
      SET @cOutField06 = @cUOM  
      SET @cOutField07 = @nScanQty  
      SET @cOutField08 = @nSuggQTY  
      SET @cOutField09 = @cFromLoc  -- (ChewKP20)  
      SET @cOutField10 = @cTTMTasktype -- (james05)  
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
  
       V_SKU         = @cSKU,  
       V_LOC         = @cFromloc,  
       V_ID          = @cID,  
       V_UOM         = @cPUOM,  
       --V_QTY         = @nQTY,  
       V_Lot         = @cLot,  
       V_CaseID      = @cCaseID,  
       
       V_FromStep    = @nFromStep,
       V_FromScn     = @nFromScn,
      
       V_Integer1    = @nQTY,
       V_Integer2    = @nSuggQTY,
       V_Integer3    = @nPrevStep,
       V_Integer4    = @nScanQty,
       V_Integer5    = @nTotalToteQTY,
  
       V_String1     = @c_ToteNO,  
       V_String2     = @c_PickMethod,  
       V_String3     = @cToloc,  
       V_String4     = @cReasonCode,  
       V_String5     = @cTaskdetailkey,  
  
       V_String6     = @cSuggFromloc,  
       V_String7     = @cSuggToloc,  
       V_String8     = @cSuggID,  
       --V_String9     = @nSuggQTY,  
       V_String10    = @cUserPosition,  
       --V_String11    = @nPrevStep,  
       V_String12    = @cNextTaskdetailkeyS,  
       V_String13    = @cPackkey,  
       --V_String14    = @nFromStep,  
       --V_String15    = @nFromScn,  
       V_String16    = @cTaskStorer,  
       V_String17    = @cDescr1,  
       V_String18    = @cDescr2,  
       --V_String19    = @nScanQty,  
       V_String20    = @cLoadkey,  
       V_String21    = @c_TaskDetailKeyPK,  
       V_String22    = @c_CurrPutawayzone,  
       V_String23    = @c_FinalPutawayzone,  
       V_String24    = @c_PPAZone,  
       V_String25    = @cUOM,  
       V_String26    = @cOrderkey,  
       --V_String18    = @cMUOM_Desc,  
       --V_String19    = @cPUOM_Desc,  
       --V_String20    = @nPUOM_Div,  
       --V_String21    = @nMQTY,  
       --V_String22    = @nPQTY,  
       --V_String23    = @nActMQTY,  
       --V_String24    = @nActPQTY,  
       --V_String25    = @nSUMBOM_Qty,  
       --V_STRING26 = @cAltSKU,  
       V_STRING27    = @cPUOM,  
       V_String28    = @cPrepackByBOM,  
       --V_String29    = @nTotalToteQTY,   -- (vicky03)  
       V_String30    = @cNewToteNo,      -- (shong03)  
       V_String31    =  @cShortPickFlag, -- (SHONG06)  
  
       V_String32    =  @cAreakey,  
       V_String33    =  @cTTMStrategykey,  
       V_String34    =  @cTTMTasktype,  
       V_String35    =  @cRefKey01,  
       V_String36    =  @cRefKey02,  
       V_String37    =  @cRefKey03,  
       V_String38    =  @cRefKey04,  
       V_String39    =  @cRefKey05,  
  
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