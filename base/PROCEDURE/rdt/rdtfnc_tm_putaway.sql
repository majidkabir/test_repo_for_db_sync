SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Store procedure: rdtfnc_TM_Putaway                                          */
/* Copyright      : IDS                                                        */
/*                                                                             */
/* Purpose: RDT Task Manager - Putaway                                         */
/*          Called By rdtfnc_TaskManager                                       */
/*                                                                             */
/* Modifications log:                                                          */
/*                                                                             */
/* Date        Rev   Author   Purposes                                         */
/* 29-09-2009  1.0   Vicky    Created                                          */
/* 21-01-2010  1.1   James    At Putaway successful screen, if user press ENTER*/
/*                            then get next task. Press ESC goto TM main screen*/
/*                            AREA screen (james01)                            */
/* 18-02-2010  1.2   Vicky    If NextTaskType = PK, check whether need to take */
/*                            Pallet wood (Vicky01)                            */
/* 23-02-2010  1.3   James    Bug fix (james02)                                */
/* 02-03-2010  1.3   James    Add in EventLog (james03)                        */
/* 05-03-2010  1.4   Vicky    Add In Previous Scn info so when user press ESC  */
/*                            in Screen 5 will back to Screen 1 (Vicky02)      */
/* 09-03-2010  1.5   Vicky    Short PA will prompt error instead of Reason Code*/
/*                            for Phase 1 only (Vicky03)                       */
/* 09-03-2010  1.6   James    Include prepack calculation (james04)            */
/* 10-03-2010  1.7   Vicky    Fix incorrect calculation of Prepack (Vicky04)   */
/* 10-03-2010  1.8   James    Bug fix (james05)                                */        
/* 11-03-2010  1.9   Vicky    Fixes: (Vicky05)                                 */        
/*                            1. Comment redundant code                        */
/*                            2. PrepackByBOM Config should get from WMS DB    */
/*                            3. Release PK task in Q when PA sucessfully      */
/* 11-03-2010  2.0   Vicky    Fix missing field value when the next task is    */
/*                            suggested (Vicky06)                              */
/* 11-03-2010  2.1            Bug fix (james06)                                */
/* 12-03-2010  2.2   James    Check for valid Qty entered (james07)            */
/* 16-03-2010  2.3   James    Add in UOM conversion for prepack (james08)      */
/* 23-03-2010  2.4   Vicky    Fix taskdetailkey not being pass into mobrec     */
/*                            (Vicky07)                                        */
/* 25-03-2010  2.5   Vicky    Add trace for concurrency issue (Vicky09)        */
/* 27-04-2010  2.6   Vicky    Bug fix for field passing from PA to PK (Vicky10)*/
/* 09-07-2010  2.7   Leong    SOS# 178764 - Do not mix variable for UOM and    */
/*                                          TaskDetailKey                      */
/* 16-07-2010  2.7   Leong    Include StdEventLog if Trace is turn on (Leong01)*/
/* 17-07-2010  2.8   ChewKP   Random Fixes (ChewKP01)                          */
/* 21-07-2010  2.8   James    SOS# 182663 - Bug fix (james09)                  */
/* 27-07-2010  2.9   Leong    SOS# 182295 - Use ArchiveCop for trace when      */
/*                                          insert data to LOTxLOCxID          */
/* 05-01-2012  3.0   ChewKP   SKIPJACK Project Changes - Synchronize V_STRINGXX*/
/*                            (ChewKP02)                                       */
/* 21-05-2012  3.1   ChewKP   SOS# 244430 - Enable Swap Task (ChewKP03)        */
/* 04-02-2013  3.2   ChewKP   SOS# 269259 - Fix Swap Task issues (ChewKP04)    */
/* 06-02-2015  3.3   Ung      SOS332294 Add ToLOC check digit                  */
/* 16-02-2015  3.4   Ung      SOS333580 Add DefaultQTY                         */
/* 06-04-2015  2.9   ChewKP   SOS#333693 - After Input Reason Code Goto Step 5 */
/*                            (ChewKP03)                                       */
/* 30-09-2016  3.0   Ung      Performance tuning                               */   
/* 16-11-2018  3.1   Gan      Performance tuning                               */
/* 16-11-2020  3.2   James    WMS-15573 Add extra param to nspTMTM01 (james10) */
/* 08-04-2024  3.3   Dennis   UWP-16908 Check Digit                            */
/*******************************************************************************/

CREATE  PROC [RDT].[rdtfnc_TM_Putaway](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
) AS

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
   @cPrevTaskdetailkey  NVARCHAR(10),
   @cQTY                NVARCHAR(5),
   @cPackkey            NVARCHAR(10),

   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),
   @cExtendedScreenSP   NVARCHAR( 20),
   @nAction             INT,
   @nAfterScn           INT,
   @nAfterStep          INT,
   @cLocNeedCheck       NVARCHAR( 20),

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

   -- (james04)
   @cAltSKU             NVARCHAR( 20),
   @cPUOM               NVARCHAR( 1), -- Prefer UOM
   @cPUOM_Desc          NVARCHAR( 5),
   @cMUOM_Desc          NVARCHAR( 5),
   @cSuggestPQTY        NVARCHAR( 5),
   @cSuggestMQTY        NVARCHAR( 5),
   @cActPQTY            NVARCHAR( 5),
   @cActMQTY            NVARCHAR( 5),
   @cPrepackByBOM       NVARCHAR(1),    -- (james08)

   @nSum_PalletQty      INT,
   @nSUMBOM_Qty         INT,
   @nPUOM_Div           INT, -- UOM divider
   @nPQTY               INT, -- Preferred UOM QTY
   @nMQTY               INT, -- Master unit QTY
   @nActQTY             INT, -- Actual QTY
   @nActMQTY            INT, -- Actual keyed in master QTY
   @nActPQTY            INT, -- Actual keyed in prefered QTY
   @nSuggestPQTY        INT, -- Suggested master QTY
   @nSuggestMQTY        INT, -- Suggested prefered QTY
   @nSuggestQTY         INT, -- Suggetsed QTY

   -- (Vicky05) - Start
   @cAisle              NVARCHAR(10),
   @cNextTaskDetailKeyR NVARCHAR(10),
   @cNextFromLOC        NVARCHAR(10),
   @cNextToID           NVARCHAR(10),
   @cNextLoadKey        NVARCHAR(10),
   @cNextStorerkey      NVARCHAR(15),
   @cRPDLot             NVARCHAR(10),
   @cRPDID              NVARCHAR(18),
   @cRPDSKU             NVARCHAR(20),
   @nRPDQTY             INT,
   @nTranCount          INT,
   -- (Vicky05) - End
   @nTrace              INT, -- (Vicky09)
   @cRefNo1             NVARCHAR(20),    -- SOS# 178764 (To keep TaskDetailkey Only)
   @cTraceReason        NVARCHAR(20), -- SOS# 178764
   @cTMPASwapTask       NVARCHAR(1), -- (ChewKP03)

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

   @cFacility   = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cSKU             = V_SKU,
   @cFromLoc         = V_LOC,
   @cID              = V_ID,
   @cPUOM            = V_UOM,
  -- @nQTY             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,
   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,
   @nPUOM_Div        = V_PUOM_Div,
   @nMQTY            = V_MQTY,
   @nPQTY            = V_PQTY,  
  
   @nQTY             = V_Integer1,
   @nSuggQTY         = V_Integer2,
   @nPrevStep        = V_Integer3,
   @nActMQTY         = V_Integer4,
   @nActPQTY         = V_Integer5,
   @nSUMBOM_Qty      = V_Integer6,
   @nTrace           = V_Integer7,
   
-- (ChewKP02)
--   @cAreaKey         = V_String1,
--   @cTTMStrategykey  = V_String2,
   @cToLoc           = V_String3,
   @cReasonCode      = V_String4,

   @cTaskdetailkey   = V_String5,

   @cSuggFromloc     = V_String6,
   @cSuggToloc       = V_String7,
   @cSuggID          = V_String8,
  -- @nSuggQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,
   @cUserPosition    = V_String10,
  -- @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,
   @cPrevTaskdetailkey = V_String12,
   @cPackkey         = V_String13,
  -- @nFromStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,
  -- @nFromScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,
   @cTaskStorer      = V_String16,
   @cTTMTasktype     = V_String17,
   -- (james04)
   @cMUOM_Desc       = V_String18,
   @cPUOM_Desc       = V_String19,
  -- @nPUOM_Div        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String20, 5), 0) = 1 THEN LEFT( V_String20, 5) ELSE 0 END,
  -- @nMQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String21, 5), 0) = 1 THEN LEFT( V_String21, 5) ELSE 0 END,
  -- @nPQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String22, 5), 0) = 1 THEN LEFT( V_String22, 5) ELSE 0 END,
  -- @nActMQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String23, 5), 0) = 1 THEN LEFT( V_String23, 5) ELSE 0 END,
  -- @nActPQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String24, 5), 0) = 1 THEN LEFT( V_String24, 5) ELSE 0 END,
  -- @nSUMBOM_Qty      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String25, 5), 0) = 1 THEN LEFT( V_String25, 5) ELSE 0 END,
   @cAltSKU          = V_String26,
   @cPUOM            = V_String27,
   @cPrepackByBOM    = V_String28,  -- (james08)

  -- @nTrace           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String29, 5), 0) = 1 THEN LEFT( V_String29, 5) ELSE 0 END,  -- (Vicky09)
   --@cRefKey01        = V_String30, -- (Vicky10)  --(ChewKP02)

   @cAreaKey         = V_String32,  --(ChewKP02)
   @cTTMStrategykey  = V_String33,  --(ChewKP02)
   @cTTMTasktype     = V_String34,  --(ChewKP02)
   @cRefKey01        = V_String35,  --(ChewKP02)
   @cRefKey02        = V_String36,  --(ChewKP02)
   @cRefKey03        = V_String37,  --(ChewKP02)
   @cRefKey04        = V_String38,  --(ChewKP02)
   @cRefKey05        = V_String39,  --(ChewKP02)

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
   @cFieldAttr09 =  FieldAttr09,   @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,   @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1757
BEGIN
   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1757, Scn = 2110 -- FromLOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 2111   ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 2112   ToLOC
   IF @nStep = 4 GOTO Step_4   -- Scn = 2113   QTY
   IF @nStep = 5 GOTO Step_5   -- Scn = 2114   Sucess Msg
   IF @nStep = 6 GOTO Step_6   -- Scn = 2109   Reason Code
   IF @nStep = 8 GOTO Step_8   -- Scn = 2108   Take Empty Pallet Wood screen
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 1. Called from Task Manager Main Screen (func = 1756)
    Screen = 2110
    FROM LOC (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   -- Set all variable for 1st record - records are from rdtfnc_TaskManager
   IF @nPrevStep = 0
   BEGIN
      SET @cSuggFromLoc = @cOutField01
      SET @cTaskdetailkey = @cOutField06
      SET @cAreaKey = @cOutField07
      SET @cTTMStrategykey = @cOutField08
   END

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

      SET @cUserPosition = '1'
      SET @nPrevStep = 1

      SET @nTrace = 1 -- (Vicky09)

      SET @cSuggFromLoc = @cOutField01

      -- (ChewKP01) (start) -- Should not Re-assigned the values
--      -- (Vicky06) - Start
--      SET @cTaskdetailkey = @cOutField06
--      SET @cAreaKey = @cOutField07
--      SET @cTTMStrategykey = @cOutField08
      -- (Vicky06) - End
      -- (ChewKP01) (end) -- Should not Re-assigned the values

      -- (Vicky09)
      IF @nTrace = 1
  BEGIN
         Declare @cTStatus NVARCHAR(10), @cTUser NVARCHAR(15)

         SELECT @cTStatus = Status,
                @cTUser = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailkey

         INSERT INTO RDT.RDTTMLOG (UserName, TaskUserName, MobileNo, AreaKey, TaskType, PrevTaskdetailkey, Taskdetailkey, PrevStatus, CurrStatus, Func, Scn, Step)
         VALUES (@cUsername, @cTUser, @nMobile, @cAreaKey, 'PA_Scn1', '', @cTaskdetailkey, '', @cTStatus, @nFunc, @nScn, @nStep)
      END

      SET @cFromLoc = @cInField02
      SET @cLocNeedCheck = @cInField02

      IF @cFromloc = ''
      BEGIN
         SET @nErrNo = 67666
         SET @cErrMsg = rdt.rdtgetmessage( 67666, @cLangCode, 'DSP') --FromLoc Req
         GOTO Step_1_Fail
      END

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1757ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1757ExtScnEntry] 
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
               GOTO Step_1_Fail
            
            SET @cFromLoc = @cLocNeedCheck
         END
      END

      IF @cFromLoc <> @cSuggFromLoc
      BEGIN
         SET @nErrNo = 67667
         SET @cErrMsg = rdt.rdtgetmessage( 67667, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_1_Fail
      END

      -- (ChewKP01) (start) -- Should not Re-assigned the values
--      SET @cSuggFromLoc = @cOutField01
--      SET @cTaskdetailkey = @cOutField06
--      SET @cAreaKey = @cOutField07
--      SET @cTTMStrategykey = @cOutField08
      -- (ChewKP01) (end) -- Should not Re-assigned the values

      SELECT @cTaskStorer = RTRIM(Storerkey),
             @cSKU = RTRIM(SKU),
             @cSuggID = RTRIM(FromID),
             @cSuggToLoc = RTRIM(ToLOC)
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskdetailkey

      EXEC RDT.rdt_STD_EventLog --Leong01
         @cActionType     = '1', -- Sign in function
         @cUserID         = @cUserName,
         @nMobileNo       = @nMobile,
         @nFunctionID     = @nFunc,
         @cFacility       = @cFacility,
         @cStorerKey      = @cTaskStorer,
         @cLocation       = @cSuggFromLoc,
         @cToLocation    = @cSuggToLoc,
         @cPutawayZone    = '',
         @cPickZone       = '',
         @cID             = @cSuggID,
         @cToID           = @cID,
         @cSKU            = @cSKU,
         @cComponentSKU   = '',
         @cUOM            = @cUOM,
         @nQTY            = @nActQTY,
         @cLot            = 'PA_Scn1',
         @cToLot          = '',
         @cTaskdetailkey  = @cTaskdetailkey,
         --@cRefNo1         = @cTaskdetailkey,
         @cAreaKey        = @cAreaKey,
         --@cRefNo2         = @cAreaKey,
         @cTTMStrategykey = @cTTMStrategykey,
         --@cRefNo3         = @cTTMStrategykey,
         --@cRefNo4         = '',
         --@cRefNo5         = '',
         @nStep           = @nStep

      -- EventLog - Sign In Function (james03)
      -- EXEC RDT.rdt_STD_EventLog
      --    @cActionType = '1', -- Sign in function
      --    @cUserID     = @cUserName,
      --    @nMobileNo   = @nMobile,
      --    @nFunctionID = @nFunc,
      --    @cFacility   = @cFacility,
      --    @cStorerKey  = @cStorerKey

      -- Get prefer UOM
      SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
      FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
      WHERE M.Mobile = @nMobile

      SELECT @cUOM = '', @cPackkey = ''
      SELECT @cUOM = PACK.PACKUOM3,
             @cPackkey = RTRIM(PACK.Packkey)
      FROM dbo.PACK PACK WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.Storerkey = @cTaskStorer
      AND   SKU.SKU = @cSKU

      SELECT @nSuggQTY = SUM(QTY)
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE Storerkey = @cTaskStorer
      AND   SKU = @cSKU
      AND   LOC = @cFromLoc
      AND   ID = @cSuggID

      -- prepare next screen
      SET @cOutField01 = @cFromLoc            SET @cOutField02 = @cSuggID
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      SET @nFromScn  = @nScn
      SET @nFromStep = @nStep

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to Reason Code screen
      IF @nStep = 1 AND @nPrevStep < 2
      BEGIN
        SET @nPrevStep = 1
      END

      IF @nPrevStep < 4
      BEGIN
         SET @cUserPosition = '1'
      END
      ELSE
      BEGIN
         SET @cUserPosition = '2'
      END

      SET @cOutField09 = @cOutField01
      SET @cOutField01 = ''

      SET @nFromScn  = @nScn -- (Vicky02)
      SET @nFromStep = @nStep -- (Vicky02)

    SET @cFromLOC = ''

      IF @nTrace = 1 --Leong01
      BEGIN
         EXEC RDT.rdt_STD_EventLog --Leong01
            @cActionType     = '1',
            @cUserID         = @cUserName,
            @nMobileNo       = @nMobile,
            @nFunctionID     = @nFunc,
            @cFacility       = @cFacility,
            @cStorerKey      = @cTaskStorer,
            @cLocation       = @cFromLoc,
            @cToLocation     = @cSuggToLoc,
            @cPutawayZone    = '',
            @cPickZone       = '',
            @cID             = @cSuggID,
            @cToID           = @cID,
            @cSKU            = @cSKU,
            @cComponentSKU   = '',
            @cUOM            = @cUOM,
            @nQTY            = @nActQTY,
            @cLot            = 'PA_Scn1',
            @cToLot          = '',
            @cTaskdetailkey  = @cTaskdetailkey,
            --@cRefNo1         = @cTaskdetailkey,
            @cRefNo2         = 'GotoScn6',
            --@cRefNo3         = '',
            --@cRefNo4         = '',
            --@cRefNo5         = ''
            @nStep           = @nStep
      END

      -- Go to Reason Code Screen
      SET @nScn  = 2109
      SET @nStep = @nStep + 5 -- Step 6
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cFromLoc = ''

      SET @cOutField01 = @cSuggFromLoc -- Suggested FromLOC
      SET @cOutField02 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2111
   FROM LOC (Field01)
   ID       (Field02)
   ID       (Field03, input)
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
      SET @cID = @cInField03

      IF @nTrace = 1 --Leong01
      BEGIN
         EXEC RDT.rdt_STD_EventLog --Leong01
            @cActionType     = '7', -- Trace
            @cUserID         = @cUserName,
            @nMobileNo       = @nMobile,
            @nFunctionID     = @nFunc,
            @cFacility       = @cFacility,
            @cStorerKey      = @cTaskStorer,
            @cLocation       = @cFromLoc,
            @cToLocation     = @cSuggToLoc,
            @cPutawayZone    = '',
            @cPickZone  = '',
            @cID             = @cSuggID,
            @cToID           = @cID,
            @cSKU            = @cSKU,
            @cComponentSKU   = '',
            @cUOM            = @cUOM,
            @nQTY            = @nActQTY,
            @cLot            = 'PA_Scn2',
            @cToLot          = '',
            @cTaskdetailkey  = @cTaskdetailkey,
            --@cRefNo1         = @cTaskdetailkey,
            --@cRefNo2         = '',
            --@cRefNo3         = '',
            --@cRefNo4         = '',
            --@cRefNo5         = '',
            @nStep           = @nStep
      END

      IF @cSuggID <> '' AND @cID = ''
      BEGIN
         SET @nErrNo = 67668
         SET @cErrMsg = rdt.rdtgetmessage( 67668, @cLangCode, 'DSP') --ID Req
         GOTO Step_2_Fail
      END


      -- Enter ID <> Suggested ID, go taskdetail to retrieve the ID to work on
      IF @cSuggID <> @cID
      BEGIN
          -- (ChewKP03)
          SET @cTMPASwapTask = rdt.RDTGetConfig( 1757, 'TMPASwapTask', @cTaskStorer)

          IF @cTMPASwapTask = '1'
          BEGIN

              SET @cPrevTaskdetailkey = @cTaskDetailKey
              SET @cTaskDetailKey = ''
              SELECT @cTaskDetailKey = TaskDetailKey
              FROM dbo.TaskDetail WITH (NOLOCK)
              WHERE TaskType = 'PA'
              AND Storerkey = @cTaskStorer
              AND FromLOC = @cFromLoc
              AND FromID = @cID
              AND Status = '0'


              IF ISNULL(RTRIM(@cTaskDetailKey), '') <> ''
              BEGIN
                 UPDATE dbo.TaskDetail WITH (ROWLOCK)
                  SET Status = '3',
                      UserKey = @cUserName,
                      Reasonkey = '',
                      StartTime = GETDATE(),
                      Trafficcop = NULL,
                      EditDate  = GETDATE()
                 WHERE TaskDetailKey = @cTaskDetailKey
                 AND STATUS = '0'

                 -- Reset the suggested Taskdetail back to 0
                 UPDATE dbo.TaskDetail WITH (ROWLOCK)
                  SET Status = '0',
                      UserKey = '',
                      Reasonkey = '',
                      Trafficcop = NULL,
                      EditDate  = GETDATE()
                 WHERE TaskDetailKey = @cPrevTaskdetailkey
                 AND STATUS = '3'

                 SELECT @cSKU = RTRIM(SKU),
                        @cSuggID = RTRIM(FromID),
                        @cSuggToLoc = RTRIM(ToLOC),
                        @cTaskStorer = RTRIM(Storerkey)
                 FROM dbo.TaskDetail WITH (NOLOCK)
                 WHERE TaskDetailKey = @cTaskdetailkey


                 SELECT @cUOM = PACK.PACKUOM3
                 FROM dbo.PACK PACK WITH (NOLOCK)
                 JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
                 WHERE SKU.Storerkey = @cTaskStorer
                 AND   SKU.SKU = @cSKU

                 SELECT @nSuggQTY = SUM(QTY)
                 FROM dbo.LOTxLOCxID WITH (NOLOCK)
                 WHERE Storerkey = @cTaskStorer
                 AND   SKU = @cSKU
                 AND   LOC = @cFromLoc
                 AND   ID = @cID
              END
              ELSE
              BEGIN
                SET @cTaskdetailkey = @cPrevTaskdetailkey --(ChewKP04)
                SET @nErrNo = 67669
                SET @cErrMsg = rdt.rdtgetmessage( 67669, @cLangCode, 'DSP') --Invalid ID
                GOTO Step_2_Fail
              END
          END
          ELSE
          BEGIN
             --SET @cTaskdetailkey = @cPrevTaskdetailkey
             SET @nErrNo = 67691
             SET @cErrMsg = rdt.rdtgetmessage( 67691, @cLangCode, 'DSP') --Invalid ID
             GOTO Step_2_Fail
          END
      END

      -- Prepare Suggested ToLOC (Calculate PA during scan Pallet ID)
      IF @cSuggToLoc = ''
      BEGIN
        IF EXISTS (SELECT 1 FROM dbo.Storer WITH (NOLOCK)
                   WHERE Storerkey = @cTaskStorer
                   AND   CalculatePutawayLocation <> '2')
        BEGIN
             SET @nErrNo = 67670
             SET @cErrMsg = rdt.rdtgetmessage( 67670, @cLangCode, 'DSP') --No ToLOC
             GOTO Step_2_Fail
        END
        ELSE
        BEGIN
--           -- call SP to suggest ToLOC
--           EXEC dbo.nspRFTPA01
--                  @c_sendDelimiter = null
--               ,  @c_ptcid         = 'RDT'
--               ,  @c_userid        = @cUserName
--               ,  @c_taskId        = 'RDT'
--               ,  @c_databasename  = NULL
--               ,  @c_appflag       = NULL
--               ,  @c_recordType    = NULL
--               ,  @c_server        = NULL
--               ,  @c_ttm           = NULL
--               ,  @c_taskdetailkey = @cTaskdetailkey
--               ,  @c_fromloc       = @cFromLoc
--               ,  @c_fromid        = @cID
--               ,  @c_reasoncode    = ''
--               ,  @c_outstring     = @c_outstring    OUTPUT
--               ,  @b_Success       = @b_Success      OUTPUT
--               ,  @n_err           = @nErrNo         OUTPUT
--               ,  @c_errmsg        = @cErrMsg        OUTPUT
--               ,  @c_toloc         = @cSuggToLoc     OUTPUT


            SELECT @cSuggToLoc = ToLOC FROM dbo.TaskDetail (NOLOCK) WHERE TASKDETAILKEY = @cTaskdetailkey
--            SELECT @cSuggToLoc = ToLOC
--            FROM dbo.TaskDetail TaskDetail WITH (NOLOCK)
--            JOIN dbo.Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
--       JOIN dbo.AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
--            JOIN dbo.TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
--            WHERE TaskDetail.Status = '3'
--            AND TaskDetail.TaskType = 'PA'
--            AND TaskDetail.UserKey <> ''
--            AND TaskDetail.FromLoc <> @cFromLoc
--            AND TaskDetail.FromID <> @cID
--            AND TaskManagerUserDetail.UserKey = @cUserName
--            AND TaskManagerUserDetail.PermissionType = 'PA'
--            AND TaskManagerUserDetail.Permission = '1'
--  AND AreaDetail.AreaKey = @cAreaKey

            IF @cSuggToLoc = ''
            BEGIN
              SET @nErrNo = 67671
              SET @cErrMsg = rdt.rdtgetmessage( 67671, @cLangCode, 'DSP') --ToLOC Not Gen
              GOTO Step_2_Fail
            END          END
      END

      -- prepare next screen
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSuggToLoc
      SET @cOutField04 = ''

      SET @nPrevStep = 0

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cSuggFromLoc
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      IF @nPrevStep = 0
      BEGIN
       SET @nPrevStep = @nStep
       SET @cID = ''
      END

      IF @nTrace = 1 --Leong01
      BEGIN
         EXEC RDT.rdt_STD_EventLog --Leong01
            @cActionType     = '7',
            @cUserID         = @cUserName,
            @nMobileNo       = @nMobile,
            @nFunctionID     = @nFunc,
            @cFacility       = @cFacility,
            @cStorerKey      = @cTaskStorer,
            @cLocation       = @cSuggFromLoc,
            @cToLocation     = @cSuggToLoc,
            @cPutawayZone    = '',
            @cPickZone       = '',
            @cID             = @cSuggID,
            @cToID           = @cID,
            @cSKU            = @cSKU,
            @cComponentSKU   = '',
            @cUOM            = @cUOM,
            @nQTY            = @nActQTY,
            @cLot            = 'PA_Scn2',
            @cToLot          = '',
            @cTaskdetailkey  = @cTaskdetailkey,
            --@cRefNo1         = @cTaskdetailkey,
            @cRefNo2         = 'GotoScn1',
            --@cRefNo3         = '',
            --@cRefNo4         = '',
            --@cRefNo5         = '',
            @nStep           = @nStep
      END

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cID = ''

      -- Reset this screen var
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cSuggID
      SET @cOutField03 = ''  -- ID
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2112
   FROM LOC        (Field01)
   ID              (Field02)
   SUGGESTED TOLOC (Field03)
   TO LOC          (Field04, input)
********************************************************************************/
Step_3:
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
      SET @cToLoc = @cInField04
      SET @cLocNeedCheck = @cInField04
      
      IF @nTrace = 1 --Leong01
      BEGIN
         EXEC RDT.rdt_STD_EventLog --Leong01
            @cActionType     = '7', -- Trace
            @cUserID         = @cUserName,
            @nMobileNo       = @nMobile,
            @nFunctionID     = @nFunc,
            @cFacility       = @cFacility,
            @cStorerKey      = @cTaskStorer,
            @cLocation       = @cFromLoc,
            @cToLocation     = @cSuggToLoc,
            @cPutawayZone    = '',
            @cPickZone       = '',
            @cID             = @cSuggID,
            @cToID           = @cID,
            @cSKU            = @cSKU,
            @cComponentSKU   = '',
            @cUOM            = @cUOM,
            @nQTY            = @nActQTY,
            @cLot            = 'PA_Scn3',
            @cToLot          = '',
            @cTaskdetailkey  = @cTaskdetailkey,
            --@cRefNo1         = @cTaskdetailkey,
            --@cRefNo2         = '',
            --@cRefNo3         = '',
            --@cRefNo4         = '',
            --@cRefNo5         = '',
            @nStep           = @nStep
      END

      IF @cToLoc = ''
      BEGIN
         SET @nErrNo = 67672
         SET @cErrMsg = rdt.rdtgetmessage( 67672, @cLangCode, 'DSP') --ToLOC Req
         GOTO Step_3_Fail
      END

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1757ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1757ExtScnEntry] 
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
               GOTO Step_3_Fail
            
            SET @cToLoc = @cLocNeedCheck
         END
      END

      -- Check digit
      IF rdt.rdtGetConfig( @nFunc, 'ToLOCCheckDigit', @cStorerKey) = '1'
      BEGIN
         IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cSuggToLoc AND LocCheckDigit = @cToLoc)
            SET @cToLoc = @cSuggToLoc
      END

      IF @cToLoc <> @cSuggToLoc
      BEGIN
--        SELECT @cFromFacility = Facility
--        FROM dbo.LOC WITH (NOLOCK)
--        WHERE LOC = @cFromLoc
--
--        IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
--                       WHERE LOC = @cToLoc AND Facility = @cFromFacility)
--        BEGIN
           SET @nErrNo = 67673
           SET @cErrMsg = rdt.rdtgetmessage( 67673, @cLangCode, 'DSP') --Bad Location
           GOTO Step_3_Fail
--        END
      END

      SELECT @nSuggQTY = ISNULL(SUM(QTY - QtyAllocated - QtyPicked), 0) FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cTaskStorer
         AND LOC = @cFromLoc
         AND ID = @cID
         
         

      -- (james04)   start
      SELECT @cSKU = '', @cAltSKU = ''
-- Comment By (Vicky04) - Start
--      SELECT @cSKU = SKU FROM dbo.LOTxLOCxID WITH (NOLOCK)
--      WHERE StorerKey = @cTaskStorer
--         AND LOC = @cFromLoc
--         AND ID = @cID

--      SELECT TOP 1 @cAltSKU = SKU FROM dbo.BillOfmaterial WITH (NOLOCK)
--      WHERE StorerKey = @cTaskStorer
--         AND ComponentSKU = @cSKU
-- Comment By (Vicky04) - End

     -- (Vicky04) - Start
      SELECT TOP 1 @cAltSKU = ISNULL(RTRIM(LA.Lottable03), '')
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT AND LA.Storerkey = LLI.Storerkey AND LA.SKU = LLI.SKU)
      WHERE LLI.StorerKey = @cTaskStorer
         AND LOC = @cFromLoc
         AND ID = @cID

-- Comment by (Vicky05) - Start
--     IF @cAltSKU = ''
--     BEGIN
--      SELECT @cSKU = SKU
--      FROM dbo.LOTxLOCxID WITH (NOLOCK)
--      WHERE StorerKey = @cTaskStorer
--         AND LOC = @cFromLoc
--         AND ID = @cID
--     END
-- Comment by (Vicky05) - End
     -- (Vicky04) - End

      -- Check for validity of Parent SKU, if not valid then consider as non-prepack   (james05)
   IF NOT EXISTS (SELECT 1 FROM dbo.BILLOFMATERIAL WITH (NOLOCK)
         WHERE StorerKey = @cTaskStorer
            AND SKU = @cAltSKU)
      BEGIN
         SET @cAltSKU = ''

         SELECT @cSKU = SKU
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cTaskStorer
            AND LOC = @cFromLoc
            AND ID = @cID
      END

      -- (Vicky05) - Start
--      DECLARE @cPrepackByBOM Char(1)

      SELECT @cPrepackByBOM = ISNULL(RTRIM(sValue), '0')
      FROM dbo.StorerConfig WITH (NOLOCK)
      WHERE Configkey = 'PrePackByBOM'
      AND  Storerkey = @cTaskStorer

      IF @cPrepackByBOM = ''
      BEGIN
         SET @cPrepackByBOM = '0'
      END
      -- (Vicky05) - Start

      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1' -- (Vicky05)
      --AND rdt.RDTGetConfig( @nFunc, 'PrePackByBOM', @cTaskStorer) = '1'
      BEGIN
         SET @cSKU = @cAltSKU
         SET @cPUOM = '2' --Case

         SET @nSUMBOM_Qty = 0
         SELECT @nSUMBOM_Qty = ISNULL(SUM(Qty), 0) FROM dbo.BillOfMaterial WITH (NOLOCK) WHERE SKU = @cSKU
         AND StorerKey = @cTaskStorer -- (james09)

         -- (Vicky04) - Start
         IF @nSUMBOM_Qty = 0
         BEGIN
           SET @nErrNo = 67683
           SET @cErrMsg = rdt.rdtgetmessage( 67683, @cLangCode, 'DSP') --BOMNotSetup
           GOTO Step_3_Fail
         END
         -- (Vicky04) - End
     END

      SELECT @cMUOM_Desc = '', @cPUOM_Desc = '', @nPUOM_Div = 0
      -- Get Pack info
      -- For Prepack    -- (james04)
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1' -- (Vicky05)
      BEGIN
         SELECT
            @cMUOM_Desc = Pack.PackUOM3,
            @cPUOM_Desc =
               CASE @cPUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END,
               @nPUOM_Div = CAST( IsNULL(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
  INNER JOIN dbo.UPC UPC WITH (NOLOCK) ON (UPC.SKU = SKU.SKU AND UPC.StorerKey = SKU.StorerKey)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (UPC.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cTaskStorer
            AND UPC.SKU = @cAltSKU
            AND UPC.UOM = 'CS'
      -- For non prepack   -- (james04)
      END
      ELSE
      BEGIN
         SELECT
            @cMUOM_Desc = Pack.PackUOM3,
            @cPUOM_Desc =
               CASE @cPUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END,
               @nPUOM_Div = CAST( IsNULL(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cTaskStorer
            AND SKU.SKU = @cSKU
     END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nSuggQTY
      END
      ELSE
      BEGIN
         IF ISNULL(@cAltSKU, '') = ''
         BEGIN
            SET @nPQTY = @nSuggQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nSuggQTY % @nPUOM_Div  -- Calc the remaining in master unit
         END
         ELSE
         BEGIN
           IF @nPUOM_Div > 0  -- (Vicky04)
           BEGIN
            SET @nPQTY = @nSuggQTY / (@nSUMBOM_Qty * @nPUOM_Div)  -- Calc QTY in preferred UOM
            SET @nMQTY = @nSuggQTY % (@nSUMBOM_Qty * @nPUOM_Div)  -- Calc the remaining in master unit
           END
           ELSE
           BEGIN -- (Vicky04)
            SET @nPQTY = 0  -- Calc QTY in preferred UOM
            SET @nMQTY = @nSuggQTY  -- Calc the remaining in master unit
           END
         END
      END
      -- (james04) end

--      -- prepare next screen
--      SET @cOutField01 = @cFromloc
--      SET @cOutField02 = @cID
--      SET @cOutField03 = @cToLoc
--      SET @cOutField04 = @cUOM
--      SET @cOutField05 = CAST(@nSuggQTY AS NVARCHAR)
--      SET @cOutField06 = CAST(@nSuggQTY AS NVARCHAR)

      DECLARE @cDefaultQTY NVARCHAR(1)
      SET @cDefaultQTY = rdt.rdtGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)

      -- (james04)
      -- prepare next screen
      SET @cOutField01 = @cFromloc
      SET @cOutField02 = @cID   -- ParentSKU
      SET @cOutField03 = @cToLoc
      SET @cOutField04 = ''
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField05 = '' -- @cPUOM_Desc
         SET @cOutField07 = '' -- @nPQTY
         SET @cOutField09 = '' -- @nActPQTY
         SET @cOutField11 = '1:1' -- @nPUOM_Div
         SET @cFieldAttr09 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField09 = CASE WHEN @cDefaultQTY = '1' THEN CAST( @nPQTY AS NVARCHAR(5)) ELSE '' END
         IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'   -- (james08)
            SET @cOutField11 = '1:' + CAST( @nSUMBOM_Qty AS NVARCHAR( 6))
         ELSE
        SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END
      SET @cOutField06 = @cMUOM_Desc  -- SOS# 178764
      --SET @cOutField12 = @cMUOM_Desc    -- SOS# 178764
      IF @nPQTY <= 0
      BEGIN
         SET @cOutField07 = ''
         SET @cOutField09 = ''
         SET @cInField09 = ''
         SET @cFieldAttr09 = 'O'
      END

      IF @nMQTY > 0
      BEGIN
         SET @cOutField08 = CASE WHEN @cDefaultQTY = '1' THEN CAST( @nMQTY as NVARCHAR( 5)) ELSE '' END
         SET @cInField10 = ''
         SET @cFieldAttr10 = ''
      END
      ELSE
      BEGIN
         SET @cOutField08 = ''
         SET @cInField10 = ''
         SET @cFieldAttr10 = 'O'
      END

      IF @nPQTY > 0
         EXEC rdt.rdtSetFocusField @nMobile, 09
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 10

      SET @cOutField10 = '' -- ActMQTY


      SET @nPrevStep = 0

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cFromloc
      SET @cOutField02 = @cSuggID
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      IF @nPrevStep = 0
      BEGIN
       SET @nPrevStep = @nStep
       SET @cToLOC = ''
      END

      IF @nTrace = 1 --Leong01
      BEGIN
         EXEC RDT.rdt_STD_EventLog --Leong01
            @cActionType     = '7',
            @cUserID         = @cUserName,
            @nMobileNo       = @nMobile,
            @nFunctionID     = @nFunc,
            @cFacility       = @cFacility,
            @cStorerKey      = @cTaskStorer,
            @cLocation       = @cFromLoc,
            @cToLocation     = @cSuggToLoc,
            @cPutawayZone    = '',
            @cPickZone       = '',
            @cID             = @cSuggID,
            @cToID           = @cID,
            @cSKU            = @cSKU,
            @cComponentSKU   = '',
            @cUOM            = @cUOM,
            @nQTY            = @nActQTY,
            @cLot            = 'PA_Scn3',
            @cToLot          = '',
            @cTaskdetailkey  = @cTaskdetailkey,
            --@cRefNo1         = @cTaskdetailkey,
            @cRefNo2         = 'GotoScn2',
            --@cRefNo3         = '',
            --@cRefNo4         = '',
            --@cRefNo5         = '',
            @nStep           = @nStep
      END

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cToLoc = ''

      -- Reset this screen var
      SET @cOutField01 = @cFromloc
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSuggToLoc
      SET @cOutField04 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 2113
   FROM LOC        (Field01)
   ID              (Field02)
   TOLOC           (Field03)
   UOM             (Field04)
   QTY             (Field05)
   QTY             (Field06, input)
********************************************************************************/
Step_4:
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

--      -- Screen mapping
--      SET @cQTY = @cInField06
--
--      IF ISNULL(RTRIM(@cQTY), '') = ''
--      BEGIN
--         SET @cQTY = '0'
--      END
--
--      SET @nQTY = CAST(@cQTY as INT)

      -- (james04)
      -- Screen mapping
      -- If Prefered unit is available
      IF ISNULL(@cPUOM_Desc, '') <> ''
      BEGIN
         SET @cActPQTY = IsNULL( @cInField09, '')
         SET @cSuggestPQTY = IsNULL( @cOutField07, '')
      END

      SET @cActMQTY = IsNULL( @cInField10, '')
      SET @cSuggestMQTY = IsNULL( @cOutField08, '')

      IF ISNULL(@cActPQTY, '') = '' SET @cActPQTY = '0' -- Blank taken as zero
      IF ISNULL(@cActMQTY, '') = '' SET @cActMQTY = '0' -- Blank taken as zero
      IF ISNULL(@cSuggestPQTY, '') = '' SET @cSuggestPQTY = '0' -- Blank taken as zero
      IF ISNULL(@cSuggestPQTY, '') = '' SET @cSuggestPQTY = '0' -- Blank taken as zero

      -- (james07) start
      IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 67688
         SET @cErrMsg = rdt.rdtgetmessage( 67688, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 09 -- PQTY
         GOTO Step_4_Fail
      END

      -- Validate ActMQTY
      IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 67689
         SET @cErrMsg = rdt.rdtgetmessage( 67689, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY
         GOTO Step_4_Fail
      END
      -- (james07) end

      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)
      SET @nActQTY = 0

      -- (james08)
--      IF ISNULL(@cAltSKU, '') = ''
--         SET @nActQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
--      ELSE
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'
         SET @nActQTY = ISNULL(rdt.rdtConvUOMQty4Prepack( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
      ELSE
         SET @nActQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM

      SET @nActQTY = @nActQTY + @nActMQTY

--      IF @nQTY = 0    -- (james04)
      IF @nActQTY = 0
      BEGIN
         SET @nErrNo = 67674
         SET @cErrMsg = rdt.rdtgetmessage( 67674, @cLangCode, 'DSP') --QTY Req
         GOTO Step_4_Fail
      END

--      IF RDT.rdtIsValidQTY( @cQTY, 0) = 0
      IF RDT.rdtIsValidQTY( @nActQTY, 0) = 0
      BEGIN
         SET @nErrNo = 67675
         SET @cErrMsg = rdt.rdtgetmessage( 67675, @cLangCode, 'DSP') -- Invalid QTY
         IF @cPUOM_Desc <> ''  -- (james07)
            EXEC rdt.rdtSetFocusField @nMobile, 09
         GOTO Step_4_Fail
      END

--      IF @nQTY > @nSuggQTY
      IF @nActQTY > @nSuggQTY
      BEGIN
         SET @nErrNo = 67676
         SET @cErrMsg = rdt.rdtgetmessage( 67676, @cLangCode, 'DSP') -- QTY>Suggest
         IF @cPUOM_Desc <> ''  -- (james07)
            EXEC rdt.rdtSetFocusField @nMobile, 09
         GOTO Step_4_Fail
      END

      -- (Vicky03) - Start
      IF @nActQTY < @nSuggQTY
      BEGIN
         SET @nErrNo = 67682
         SET @cErrMsg = rdt.rdtgetmessage( 67682, @cLangCode, 'DSP') -- QTY<Suggest
         GOTO Step_4_Fail
      END
      -- (Vicky03) - End

-- Comment By (Vicky03) - Start
--      -- Go to Reason Code, only execute PA after reason keyed in
--  IF @nQTY < @nSuggQTY
--      BEGIN
--         -- Go to Reason Code screen
--         SET @cUserPosition = '2'
--
--         -- james02
--         SET @nFromScn  = @nScn
--         SET @nFromStep = @nStep
--
--         -- Go to Reason Code Screen
--         SET @nScn  = 2109
--         SET @nStep = @nStep + 2 -- Step 6
--
--         SET @cOutField01 = ''
--         SET @cOutField02 = ''
--         SET @cOutField03 = ''
--         SET @cOutField04 = ''
--         SET @cOutField05 = ''
--
--         GOTO QUIT
--     END
--     ELSE
--     BEGIN
-- Comment By (Vicky03) - End

         EXEC RDT.rdt_STD_EventLog -- SOS# 178764
            @cActionType     = '4',  -- Move
            @cUserID         = @cUserName,
            @nMobileNo       = @nMobile,
            @nFunctionID     = @nFunc,
            @cFacility       = @cFacility,
            @cStorerKey      = @cStorerKey,
            @cLocation       = @cFromLoc,
            @cToLocation     = @cToLOC,
            @cPutawayZone    = '',
            @cPickZone       = '',
            @cID             = @cSuggID,
            @cToID           = @cID,
            @cSKU            = 'CFMPA',
            @cComponentSKU   = '',
            @cUOM            = @cUOM,
            @nQTY            = @nActQTY,
            @cLot            = 'PA_Scn4',
            @cToLot          = '',
            @cTaskdetailkey  = @cTaskdetailkey,
            --@cRefNo1         = @cTaskdetailkey,
            --@cRefNo2         = '',
            --@cRefNo3         = '',
            --@cRefNo4         = '',
            --@cRefNo5         = '',
            @nStep           = @nStep

        -- Confirm Putaway
        EXEC dbo.nspRFTPA03
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
           ,  @c_fromid        = @cSuggID
           ,  @c_toloc         = @cToLOC
           ,  @c_toid          = @cID
--           ,  @n_qty           = @nQTY
           ,  @n_qty           = @nActQTY
           ,  @c_packkey       = @cPackkey
           ,  @c_uom  = @cUOM
           ,  @c_reasoncode    = ''
           ,  @c_outstring     = @c_outstring    OUTPUT
           ,  @b_Success       = @b_Success      OUTPUT
           ,  @n_err           = @nErrNo         OUTPUT
           ,  @c_errmsg        = @cErrMsg        OUTPUT
           ,  @c_userposition  = ''

        IF ISNULL(@cErrMsg, '') <> ''
        BEGIN
          SET @cErrMsg = @cErrMsg
          GOTO Step_4_Fail
        END

      UPDATE dbo.TaskManagerUser WITH (ROWLOCK) SET
         LastLoc = @cToLOC
      WHERE UserKey = @cUserName

      -- Release PK & NMV task in Status = Q (Vicky05) - Start
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN TM_PA_ReleaseQ

      SELECT @cAisle = ISNULL(RTRIM(LocAisle), '')
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cSuggFromloc

     -- If no more in same Loadplan, get the Taskkey from Other Loadplan
       SELECT TOP 1 @cNextTaskDetailKeyR = TD.TaskDetailKey,
                    @cNextFromLOC = TD.FromLOC,
                    @cNextToID = TD.ToID,
                    @cNextLoadKey = TD.Loadkey,
                    @cNextStorerkey = TD.Storerkey
       FROM dbo.TaskDetail TD WITH (NOLOCK)
       JOIN dbo.LOC LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC)
       WHERE TD.TaskType = 'PK'
       AND   TD.Status = 'Q'
       AND   LOC.LocAisle = @cAisle
       ORDER BY TD.Priority, TD.TaskDetailKey

      -- Reserve current P&D for another Task
       DECLARE CUR_RQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT PD.LOT, PD.ID, PD.SKU, SUM(PD.QTY)
           FROM dbo.PickDetail PD WITH (NOLOCK)
           JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey AND PD.OrderLinenumber = OD.OrderLinenumber)
           JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.Orderkey = OD.Orderkey)
           WHERE PD.ID = @cNextToID
           AND   PD.LOC = @cNextFromLOC
           AND   PD.Storerkey = @cNextStorerkey
           AND   LPD.Loadkey = @cNextLoadKey
           AND   PD.Status not in ('4', '5', '9')
           GROUP BY PD.LOT, PD.ID, PD.SKU

       OPEN CUR_RQTY
       FETCH NEXT FROM CUR_RQTY INTO @cRPDLot, @cRPDID, @cRPDSKU, @nRPDQTY
       WHILE (@@FETCH_STATUS <> -1)
       BEGIN

         IF @nTrace = 1 -- SOS# 182295
         BEGIN
            INSERT dbo.TraceInfo (TraceName, TimeIn, Step1, Step2, Col1, Col2, Col3, Col4, Col5)
            VALUES('rdtfnc_TM_Putaway', GETDATE(), @cNextTaskdetailkeyR, @nRPDQTY, @cNextStorerkey, @cRPDSKU, @cRPDLot, @cSuggFromLoc, @cRPDID)
         END

         -- If P&D already have information
         IF NOT EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK)
                        WHERE Lot = @cRPDLot AND LOC = @cSuggFromloc
                        AND ID = @cRPDID AND SKU = @cRPDSKU AND StorerKey = @cNextStorerkey)
         BEGIN
             INSERT dbo.LOTxLOCxID (STORERKEY, SKU, LOT, LOC, ID, PendingMoveIn, ArchiveCop) -- SOS# 182295
             VALUES (@cNextStorerkey, @cRPDSKU, @cRPDLot, @cSuggFromLoc, @cRPDID, @nRPDQTY, 'P')   -- SOS# 182295

              IF @@Error <> 0
              BEGIN
                 SET @nErrNo = 67684
                 SET @cErrMsg = rdt.rdtgetmessage( 67684, @cLangCode, 'DSP') -- ErrInsPendingMoveIn
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
                   , ArchiveCop = 'p' -- SOS# 182295
            WHERE Lot = @cRPDLot
            AND   LOC = @cSuggFromLoc
            AND   ID = @cRPDID
            AND   SKU = @cRPDSKU
            AND   StorerKey = @cNextStorerkey

            IF @@Error <> 0
            BEGIN
               SET @nErrNo = 67685
               SET @cErrMsg = rdt.rdtgetmessage( 67685, @cLangCode, 'DSP') -- ErrUpdPenMvIn
               CLOSE CUR_RQTY
               DEALLOCATE CUR_RQTY
               GOTO RollBackTran
            END
         END

       FETCH NEXT FROM CUR_RQTY INTO @cRPDLot, @cRPDID, @cRPDSKU, @nRPDQTY
       END -- END WHILE (@@FETCH_STATUS <> -1)
       CLOSE CUR_RQTY
       DEALLOCATE CUR_RQTY

       UPDATE dbo.TaskDetail WITH (ROWLOCK)
         SET Status = '0',
             ToLoc = @cSuggFromLoc,
             LogicalToLoc = @cSuggFromLoc,
             EditDate = GETDATE(),
             EditWho  = @cUsername,
             Trafficcop = NULL, Message02 = 'PKQto0' -- SOS# 182295

       WHERE TaskDetailKey = @cNextTaskdetailkeyR
       AND   TaskType = 'PK'
       AND   Status = 'Q'

       IF @@Error <> 0
       BEGIN
         SET @nErrNo = 67686
         SET @cErrMsg = rdt.rdtgetmessage( 67686, @cLangCode, 'DSP') -- ErrUpdTaskDetail
         GOTO RollBackTran
       END

       UPDATE dbo.TaskDetail WITH (ROWLOCK)
         SET FromLOC = @cSuggFromLoc,
             LogicalFromLoc = @cSuggFromLoc,
             EditDate = GETDATE(),
             EditWho  = @cUsername,
             Trafficcop = NULL
       WHERE RefTaskKey = @cNextTaskdetailkeyR
       AND   TaskType = 'NMV'
       AND   Status = 'W'

       IF @@Error <> 0
       BEGIN
         SET @nErrNo = 67687
         SET @cErrMsg = rdt.rdtgetmessage( 67687, @cLangCode, 'DSP') -- ErrUpdTaskDetail
         GOTO RollBackTran
       END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN TM_PA_ReleaseQ
      -- Release PK & NMV task in Status = Q (Vicky05) - End

      -- EventLog - QTY (james03)
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cLocation     = @cSuggFromLoc,
         @cToLocation   = @cToLOC,
         @cID           = @cSuggID,
         @cToID         = @cID,
         @cPutawayZone  = 'NEXT',
         @cSKU          = '',
         @cUOM          = @cUOM,
--       @nQTY          = @nQTY
         @nQTY          = @nActQTY,
         @cLot          = 'PA_Scn4',
         @cToLot        = '',
         @cTaskdetailkey = @cTaskdetailkey,
         --@cRefNo1       = @cTaskdetailkey,
         @cRefNo3       = @cNextTaskdetailkeyR,
         @nStep         = @nStep

        -- prepare next screen
        SET @cOutField01 = ''
        SET @cOutField02 = ''
        SET @cOutField03 = ''
        SET @cOutField04 = ''
        SET @cOutField05 = ''
        SET @cOutField06 = ''
        SET @cOutField07 = ''
        SET @cOutField08 = ''

        SET @cSuggFromLoc = ''
        SET @cTaskdetailkey = ''
        SET @cTTMStrategykey = ''

        SET @nPrevStep = 0

        -- Go to next screen
        SET @nScn = @nScn + 1
        SET @nStep = @nStep + 1
     -- END -- Comment By (Vicky03)
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cFromloc
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSuggToLoc
      SET @cOutField04 = ''
      SET @cOutField05 = ''
    --SET @cOutField06 = ''

      SET @nQTY = 0
      SET @cQTY = '0'

      IF @nPrevStep = 0
      BEGIN
       SET @nPrevStep = @nStep
      END

      IF @nTrace = 1 --Leong01
      BEGIN
         EXEC RDT.rdt_STD_EventLog --Leong01
            @cActionType     = '7',
            @cUserID         = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID     = @nFunc,
            @cFacility       = @cFacility,
            @cStorerKey      = @cTaskStorer,
            @cLocation       = @cFromLoc,
            @cToLocation     = @cSuggToLoc,
            @cPutawayZone    = '',
            @cPickZone       = '',
            @cID             = @cSuggID,
            @cToID           = @cID,
            @cSKU            = @cSKU,
            @cComponentSKU   = '',
            @cUOM            = @cUOM,
            @nQTY            = @nActQTY,
            @cLot            = 'PA_Scn4',
            @cToLot          = '',
            @cTaskdetailkey  = @cTaskdetailkey,
            --@cRefNo1         = @cTaskdetailkey,
            @cRefNo2         = 'GotoScn3',
            --@cRefNo3         = '',
            --@cRefNo4         = '',
            --@cRefNo5         = '',
            @nStep           = @nStep
      END

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cFieldAttr09 = ''

      IF @cPUOM_Desc = ''
         SET @cFieldAttr09 = 'O'

      IF @cOutField08 = ''    -- If master uom qty got no value then disable the display
         SET @cFieldAttr10 = 'O' -- disable the display (james01)

      IF @nPQTY <= 0    -- (james01)
      BEGIN
         SET @cOutField07 = ''
         SET @cOutField09 = ''
         SET @cInField09 = ''
         SET @cFieldAttr09 = 'O'
      END

      -- (james04)
--      SET @cQTY = ''
--      SET @nQTY = 0

--      -- Reset this screen var
--      SET @cOutField01 = @cFromloc
--      SET @cOutField02 = @cID
--      SET @cOutField03 = @cToLoc
--      SET @cOutField04 = @cUOM
--      SET @cOutField05 = CAST(@nSuggQTY AS NVARCHAR)
--      SET @cOutField06 = CAST(@nSuggQTY AS NVARCHAR)
   END
   GOTO Quit   -- (james06)

   RollBackTran:
      ROLLBACK TRAN TM_PA_ReleaseQ

END
GOTO Quit

/********************************************************************************
Step 5. screen = 2114
     Success Message
********************************************************************************/
Step_5:
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

      DECLARE @cNextTaskdetailkeyS NVARCHAR(10)

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
       ,  @c_RefKey03      = @cRefKey03     OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func
       ,  @n_Mobile        = @nMobile
       ,  @n_Func          = @nFunc
       ,  @c_StorerKey     = @cStorerKey

      IF @nTrace = 1 --Leong01
      BEGIN
         EXEC RDT.rdt_STD_EventLog
          @cActionType     = '7',
            @cUserID         = @cUserName,
          @nMobileNo       = @nMobile,
        @nFunctionID     = @nFunc,
          @cFacility       = @cFacility,
          @cStorerKey      = @cTaskStorer,
          @cLocation       = @cFromLoc,
          @cToLocation     = @cSuggToLoc,
          @cPutawayZone    = '',
          @cPickZone       = '',
          @cID             = @cSuggID,
          @cToID           = @cID,
          @cSKU            = @cSKU,
          @cComponentSKU   = '',
          @cUOM            = @cUOM,
          @nQTY            = @nActQTY,
          @cLot            = 'PA_Scn5',
          @cToLot          = '',
          @cTaskdetailkey  = @cTaskdetailkey,
          --@cRefNo1         = @cTaskdetailkey,
          @cRefNo2         = @cNextTaskdetailkeyS,
          @cAreaKey        = @cAreaKey,
          --@cRefNo3         = @cAreaKey,
          @cTaskType       = @cTTMTasktype,
          --@cRefNo4         = @cTTMTasktype,
          --@cRefNo5         = '',
          @nStep           = @nStep
      END

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

           GOTO QUIT
       END

       IF ISNULL(@cErrMsg, '') <> ''
       BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_5_Fail
       END

      -- (Vicky09)
      IF @nTrace = 1
      BEGIN
         SELECT @cTStatus = Status,
                @cTUser = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailkey

         INSERT INTO RDT.RDTTMLOG (UserName, TaskUserName, MobileNo, AreaKey, TaskType, PrevTaskdetailkey, Taskdetailkey, PrevStatus, CurrStatus, Func, Scn, Step)
         VALUES (@cUsername, @cTUser, @nMobile, @cAreaKey, 'PA_Succ', @cTaskdetailkey, @cNextTaskdetailkeyS, '', @cTStatus, @nFunc, @nScn, @nStep)
      END


      IF ISNULL(@cNextTaskdetailkeyS, '') <> ''
      BEGIN
         SET @cTaskdetailkey = @cNextTaskdetailkeyS
         SET @nPrevStep = 0  -- Shall set to 0 as retrieval of New Task (ChewKP01)
      END

      IF @cTTMTasktype = 'PK'
      BEGIN
         -- This screen will only be prompt if the QTY to be picked is not full Pallet
         IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskdetailkey
               AND PickMethod <> 'FP')  --FP = full pallet; PP = partial pallet
         BEGIN
            SET @nTaskDetail_Qty = 0
            SET @nOn_HandQty = 0
            SELECT @cTaskStorer = StorerKey,
               @cID = FromID,
               @cLoc = FromLOC,
               @nTaskDetail_Qty = ISNULL(Qty, 0)
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskdetailkey

            -- Get on hand qty
            SELECT @nOn_HandQty = ISNULL(SUM(QTY - QtyPicked), 0)
            FROM dbo.LotxLocxID WITH (NOLOCK)
            WHERE StorerKey = @cTaskStorer
               AND LOC = @cLoc
               AND ID = @cID

            IF @nOn_HandQty = 0
            BEGIN
               SET @nErrNo = 68794
               SET @cErrMsg = rdt.rdtgetmessage( 68794, @cLangCode, 'DSP') --onhandqty=0
               --GOTO Step_6_Fail
               GOTO Step_5_Fail  --(ChewKP01)
            END

            IF @nTaskDetail_Qty = 0
            BEGIN
               SET @nErrNo = 68795
               SET @cErrMsg = rdt.rdtgetmessage( 68795, @cLangCode, 'DSP') --tdqty=0
               --GOTO Step_6_Fail
               GOTO Step_5_Fail  --(ChewKP01)
            END

            IF @nOn_HandQty > @nTaskDetail_Qty
            BEGIN
               SET @nScn = 2108
               SET @nStep = 8
               GOTO Quit
            END
         END
      END

--       SELECT @nToFunc = CAST(ISNULL(RTRIM(SHORT), '0') AS INT)
--       FROM dbo.CODELKUP WITH (NOLOCK)
--       WHERE Listname = 'TASKTYPE'
--       AND   Code = RTRIM(@cTTMTasktype)

      SET @nToFunc = 0
      SET @nToScn = 0

       SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
       FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
       WHERE TaskType = RTRIM(@cTTMTasktype)

       IF @nFunc = 0
       BEGIN
         SET @nErrNo = 67677
         SET @cErrMsg = rdt.rdtgetmessage( 67677, @cLangCode, 'DSP') -- NextTaskFncErr
         GOTO Step_5_Fail
       END

       SELECT TOP 1 @nToScn = Scn
       FROM RDT.RDTScn WITH (NOLOCK)
       WHERE Func = @nToFunc
       ORDER BY Scn

       IF @nToScn = 0
       BEGIN
         SET @nErrNo = 67678
         SET @cErrMsg = rdt.rdtgetmessage( 67678, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Step_5_Fail
       END

       SET @cOutField01 = @cRefKey01
       SET @cOutField02 = @cRefKey02
       SET @cOutField03 = @cRefKey03
       SET @cOutField04 = @cRefKey04
       SET @cOutField05 = @cRefKey05
       SET @cOutField06 = @cNextTaskdetailkeyS
       SET @cOutField07 = @cAreaKey
       SET @cOutField08 = @cTTMStrategykey

      -- (Vicky06) EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType     = '9', -- Sign Out function
         @cUserID         = @cUserName,
         @nMobileNo       = @nMobile,
         @nFunctionID     = @nFunc,
         @cFacility       = @cFacility,
         @cStorerKey      = @cStorerKey,
         @cLocation       = @cFromLoc,
         @cToLocation     = @cSuggToLoc,
         @cPutawayZone    = 'NEXT',
         @cPickZone       = '',
         @cID             = '',
         @cToID           = @cTTMStrategykey,
         @cSKU            = @cAreaKey,
         @cComponentSKU   = @cRefKey01,
         @cUOM            = @cUOM,
         @nQTY            = @nActQTY,
         @cLot            = 'PA_Scn5',
         @cToLot          = @cNextTaskdetailkeyS,
         @cTaskdetailkey  = @cTaskdetailkey,
         --@cRefNo1         = @cTaskdetailkey,
         @cRefNo2         = @cRefKey02,
         @cRefNo3         = @cRefKey03,
         @cRefNo4         = @cRefKey04,
         @cRefNo5         = @cRefKey05,
         @nStep           = @nStep

       SET @nFunc = @nToFunc
       SET @nScn = @nToScn
       SET @nStep = 1
   END

   IF @nInputKey = 0    --ESC (james01)
   BEGIN
      -- EventLog - Sign Out Function (james03)
      -- EXEC RDT.rdt_STD_EventLog
      --  @cActionType = '9', -- Sign Out function
      --  @cUserID     = @cUserName,
--  @nMobileNo   = @nMobile,
      --  @nFunctionID = @nFunc,
      --  @cFacility   = @cFacility,
      --  @cStorerKey  = @cStorerKey

     -- Go back to Task Manager Main Screen
     SET @nFunc = 1756
     SET @nScn = 2100
     SET @nStep = 1

     SET @cAreaKey = ''

      EXEC RDT.rdt_STD_EventLog --Leong01
         @cActionType     = '9',
         @cUserID         = @cUserName,
         @nMobileNo       = @nMobile,
         @nFunctionID     = @nFunc,
         @cFacility       = @cFacility,
         @cStorerKey      = @cStorerKey,
         @cLocation       = '',
         @cToLocation     = '',
         @cPutawayZone    = '',
         @cPickZone       = '',
         @cID             = '',
         @cToID           = '',
         @cSKU            = '',
         @cComponentSKU   = '',
         @cUOM            = '',
         @nQTY            = '',
         @cLot            = 'PA_Scn5',
         @cToLot          = '',
         @cTaskdetailkey  = @cTaskdetailkey,
         --@cRefNo1         = @cTaskdetailkey,
         @cRefNo2         = 'GotoTM',
         @nScn            = @nScn,
         --@cRefNo3         = @nScn,
         @nStep           = @nStep,
         --@cRefNo4         = @nStep,
         @cRefNo5         = @cNextTaskdetailkeyS,
         @nStep           = @nStep

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
Step 6. screen = 2109
     REASON CODE  (Field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReasonCode = @cInField01

      IF @cReasonCode = ''
      BEGIN
        SET @nErrNo = 67679
        SET @cErrMsg = rdt.rdtgetmessage( 67679, @cLangCode, 'DSP') --Reason Req
        GOTO Step_6_Fail
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
           ,  @c_fromloc       = @cLoc
           ,  @c_fromid        = @cID
           ,  @c_toloc         = ''
           ,  @c_toid          = ''
           ,  @n_qty           = 0
           ,  @c_PackKey       = ''
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
        GOTO Step_6_Fail
      END

      SET @cTraceReason = 'CFMPA: ' + CAST(@cReasonCode AS NVARCHAR(10))
      EXEC RDT.rdt_STD_EventLog -- SOS# 178764
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cLocation     = @cFromLoc,
         @cToLocation   = @cToLOC,
         @cID           = @cSuggID,
         @cToID         = @cID,
         @cSKU          = @cTraceReason,
         @cUOM          = @cUOM,
         @nQTY          = @nActQTY,
         @cLot          = 'PA_Scn6',
         @cTaskdetailkey = @cTaskdetailkey,
         --@cRefNo1       = @cTaskdetailkey,
         @nStep         = @nStep


-- (ChewKP05)
      -- Confirm Putaway
--      EXEC dbo.nspRFTPA03
--              @c_sendDelimiter = NULL
--           ,  @c_ptcid         = 'RDT'
--           ,  @c_userid        = @cUserName
--           ,  @c_taskId        = 'RDT'
--           ,  @c_databasename  = NULL
--           ,  @c_appflag       = NULL
--           ,  @c_recordType    = NULL
--           ,  @c_server       = NULL
--           ,  @c_ttm           = NULL
--           ,  @c_taskdetailkey = @cTaskdetailkey
--           ,  @c_fromloc       = @cSuggFromLoc
--           ,  @c_fromid        = @cSuggID
--           ,  @c_toloc         = @cToLOC
--           ,  @c_toid          = @cID
--           ,  @n_qty           = @nQTY
--           ,  @c_packkey       = @cPackkey
--           ,  @c_uom           = @cUOM
--           ,  @c_reasoncode    = @cReasonCode
--           ,  @c_outstring     = @c_outstring    OUTPUT
--           ,  @b_Success       = @b_Success      OUTPUT
--           ,  @n_err           = @nErrNo         OUTPUT
--           ,  @c_errmsg        = @cErrMsg        OUTPUT
--           ,  @c_userposition  = @cUserPosition
--
--      IF ISNULL(@cErrMsg, '') <> ''
--      BEGIN
--        SET @cErrMsg = @cErrMsg
--        GOTO Step_6_Fail
--      END

      UPDATE dbo.TaskManagerUser WITH (ROWLOCK) SET
         LastLoc = @cToLOC
      WHERE UserKey = @cUserName

      -- EventLog - QTY (james03)
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cLocation     = @cSuggFromLoc,
         @cToLocation   = @cToLOC,
         @cID           = @cID,
         @cToID         = @cID,
         @cSKU          = '',
         @cUOM          = @cUOM,
         @nQTY        = @nQTY,
         @cLot          = 'PA_Scn6',
         @cTaskdetailkey = @cTaskdetailkey,
         --@cRefNo1       = @cTaskdetailkey,
         @nStep         = @nStep

      -- Search for next task and redirect screen

-- (ChewKP05)
--      DECLARE @cNextTaskdetailkey NVARCHAR(10)
--      SET @cErrMsg = ''
--
--       EXEC dbo.nspTMTM01
--          @c_sendDelimiter = null
--       ,  @c_ptcid         = 'RDT'
--       ,  @c_userid        = @cUserName
--       ,  @c_taskId        = 'RDT'
--       ,  @c_databasename  = NULL
--       ,  @c_appflag       = NULL
--       ,  @c_recordType    = NULL
--       ,  @c_server        = NULL
--       ,  @c_ttm           = NULL
--       ,  @c_areakey01     = @cAreaKey
--       ,  @c_areakey02     = ''
--       ,  @c_areakey03     = ''
--       ,  @c_areakey04     = ''
--       ,  @c_areakey05     = ''
--       ,  @c_lastloc       = @cSuggToLoc
--       ,  @c_lasttasktype  = 'TPA'
--       ,  @c_outstring     = @c_outstring    OUTPUT
--       ,  @b_Success       = @b_Success      OUTPUT
--       ,  @n_err           = @nErrNo         OUTPUT
--       ,  @c_errmsg        = @cErrMsg        OUTPUT
--       ,  @c_taskdetailkey = @cNextTaskdetailkey OUTPUT
--       ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
--       ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
--       ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
--       ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
--       ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
--       ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func
--
--      IF @nTrace = 1 --Leong01
--      BEGIN
--         EXEC RDT.rdt_STD_EventLog
--          @cActionType     = '7',
--            @cUserID         = @cUserName,
--          @nMobileNo       = @nMobile,
--          @nFunctionID     = @nFunc,
--          @cFacility       = @cFacility,
--          @cStorerKey    = @cTaskStorer,
--          @cLocation       = @cFromLoc,
--          @cToLocation     = @cSuggToLoc,
--          @cPutawayZone    = 'NEXT',
--          @cPickZone       = '',
--          @cID             = '',
--          @cToID           = '',
--          @cSKU            = '',
--          @cComponentSKU   = '',
--          @cUOM            = '',
--          @nQTY            = '',
--          @cLot            = 'PA_Scn6',
--          @cToLot          = '',
--          @cRefNo1         = @cTaskdetailkey,
--          @cRefNo2         = @cNextTaskdetailkey,
--          @cRefNo3         = @cAreaKey,
--          @cRefNo4         = @cTTMTasktype,
--          @cRefNo5         = ''
--      END
--
--       IF ISNULL(RTRIM(@cNextTaskdetailkey), '') = ''--@nErrNo = 67804 -- Nothing to do!
--       BEGIN
--           -- EventLog - Sign Out Function (james03)
--    EXEC RDT.rdt_STD_EventLog
--             @cActionType = '9', -- Sign Out function
--             @cUserID     = @cUserName,
--             @nMobileNo   = @nMobile,
--             @nFunctionID = @nFunc,
--             @cFacility   = @cFacility,
--             @cStorerKey  = @cStorerKey,
--             @cLot        = 'PA_Scn6',
--             @cRefNo1     = @cTaskdetailkey,
--             @cRefNo2     = 'NoTask'
--
--           -- Go back to Task Manager Main Screen
--           SET @nFunc = 1756
--           SET @nScn = 2100
--           SET @nStep = 1
--
--           SET @cErrMsg = 'No More Task'
--           SET @cAreaKey = ''
--
--           SET @cOutField01 = ''  -- Area
--           SET @cOutField02 = ''
--           SET @cOutField03 = ''
--           SET @cOutField04 = ''
--           SET @cOutField05 = ''
--           SET @cOutField06 = ''
--           SET @cOutField07 = ''
--           SET @cOutField08 = ''
--
--           GOTO QUIT
--       END
--
--       IF ISNULL(@cErrMsg, '') <> ''
--       BEGIN
--         SET @cErrMsg = @cErrMsg
--         GOTO Step_6_Fail
--       END
--
--      -- (Vicky09)
--      IF @nTrace = 1
--      BEGIN
--         SELECT @cTStatus = Status,
--                @cTUser = UserKey
--         FROM dbo.TaskDetail WITH (NOLOCK)
--         WHERE TaskDetailKey = @cTaskdetailkey
--
--         INSERT INTO RDT.RDTTMLOG (UserName, TaskUserName, MobileNo, AreaKey, TaskType, PrevTaskdetailkey, Taskdetailkey, PrevStatus, CurrStatus, Func, Scn, Step)
--         VALUES (@cUsername, @cTUser, @nMobile, @cAreaKey, 'PA_Reason', @cTaskdetailkey, @cNextTaskdetailkey, '', @cTStatus, @nFunc, @nScn, @nStep)
--      END
--
--
--      IF ISNULL(@cNextTaskdetailkey, '') <> ''
--      BEGIN
--         SET @cTaskdetailkey = @cNextTaskdetailkey
--      END
--
--      -- (Vicky01) - Start
--      IF @cTTMTasktype = 'PK'
--      BEGIN
--         -- This screen will only be prompt if the QTY to be picked is not full Pallet
--         IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
--            WHERE TaskDetailKey = @cTaskdetailkey
--               AND PickMethod <> 'FP')  --FP = full pallet; PP = partial pallet
--         BEGIN
--            SET @nTaskDetail_Qty = 0
--            SET @nOn_HandQty = 0
--            SELECT @cTaskStorer = StorerKey,
--               @cID = FromID,
--               @cLoc = FromLOC,
--               @nTaskDetail_Qty = ISNULL(Qty, 0)
--            FROM dbo.TaskDetail WITH (NOLOCK)
--            WHERE TaskDetailKey = @cTaskdetailkey
--
--            -- Get on hand qty
--            SELECT @nOn_HandQty = ISNULL(SUM(QTY - QtyPicked), 0)
--            FROM dbo.LotxLocxID WITH (NOLOCK)
--            WHERE StorerKey = @cTaskStorer
--               AND LOC = @cLoc
--               AND ID = @cID
--
--            IF @nOn_HandQty = 0
--            BEGIN
--               SET @nErrNo = 68794
--               SET @cErrMsg = rdt.rdtgetmessage( 68794, @cLangCode, 'DSP') --onhandqty=0
--               GOTO Step_6_Fail
--            END
--
--            IF @nTaskDetail_Qty = 0
--            BEGIN
--               SET @nErrNo = 68795
--               SET @cErrMsg = rdt.rdtgetmessage( 68795, @cLangCode, 'DSP') --tdqty=0
--               GOTO Step_6_Fail
--            END
--
--
--            IF @nOn_HandQty > @nTaskDetail_Qty
--            BEGIN
--               SET @nScn = 2108
--               SET @nStep = 8
--               GOTO Quit
--            END
--         END
--      END
--      -- (Vicky01) - End
--
----       SELECT @nToFunc = CAST(ISNULL(RTRIM(SHORT), '0') AS INT)
----       FROM dbo.CODELKUP WITH (NOLOCK)
----       WHERE Listname = 'TASKTYPE'
----       AND   Code = RTRIM(@cTTMTasktype)
--      SET @nToFunc = 0
--      SET @nToScn = 0
--
--      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
--      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
--      WHERE TaskType = RTRIM(@cTTMTasktype)
--
--      IF @nFunc = 0
--      BEGIN
--      SET @nErrNo = 67680
--      SET @cErrMsg = rdt.rdtgetmessage( 67680, @cLangCode, 'DSP') --NextTaskFncErr
--      GOTO Step_6_Fail
--      END
--
--       SELECT TOP 1 @nToScn = Scn
--       FROM RDT.RDTScn WITH (NOLOCK)
--       WHERE Func = @nToFunc
--       ORDER BY Scn
--
--       IF @nToScn = 0
--       BEGIN
--         SET @nErrNo = 67681
--         SET @cErrMsg = rdt.rdtgetmessage( 67681, @cLangCode, 'DSP') --NextTaskScnErr
--         GOTO Step_6_Fail
--       END


       SET @cOutField01 = ''
       SET @cOutField02 = ''
       SET @cOutField03 = ''
   

     -- EventLog - Sign Out Function (james02)
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerKey,
       @cLot        = 'PA_Scn6',
       @cTaskdetailkey = @cTaskdetailkey,
       --@cRefNo1     = @cTaskdetailkey,
       @cRefNo2     = @nToFunc,
       @cRefNo3     = @nToScn,
       @cRefNo4     = '1',
       --@cRefNo5     = '',
       @nStep       = @nStep

    
      SET @nScn = 2114
      SET @nStep = 5 

      SET @nPrevStep = 0
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      -- (Vicky07) - Start
      SET @cOutField01 = @cSuggFromLoc
      SET @cOutField06 = @cTaskdetailkey
      SET @cOutField07 = @cAreaKey
      SET @cOutField08 = @cTTMStrategykey
      -- (Vicky07) - End

     --IF @nFromStep = 1 -- ESC from Screen 1  -- (ChewKP01)
     --BEGIN
       SET @cOutField01 = @cOutField09

       -- go to previous screen
       SET @nScn = @nFromScn
       SET @nStep = @nFromStep
     --END

       -- (ChewKP01)
       IF @nTrace = 1 --Leong01
         BEGIN
            EXEC RDT.rdt_STD_EventLog --Leong01
               @cActionType     = '7',
               @cUserID         = @cUserName,
               @nMobileNo       = @nMobile,
               @nFunctionID     = @nFunc,
               @cFacility       = @cFacility,
               @cStorerKey      = @cTaskStorer,
               @cLocation       = @cFromloc,
               @cToLocation     = @cToLoc,
               @cPutawayZone    = '',
               @cPickZone       = '',
               @cID             = @cSuggID,
               @cToID           = @cID,
               @cLot            = 'PA_Scn6',
               @cToLot          = '',
               @cTaskdetailkey  = @cTaskdetailkey,
               --@cRefNo1         = @cTaskdetailkey,
               @cRefNo2         = 'GotoScn4',
               @cRefNo3         = @nFromStep,
               --@cRefNo4         = '',
               --@cRefNo5         = '',
               @nStep           = @nStep
         END


     -- (ChewKP01) Start -- User Must PA all QTY , therefore only can be ESC from Screen 1
--     ELSE IF @nFromStep = 4 -- ESC from Screen 4 - QTY
--     BEGIN
--       SET @cOutField01 = @cFromloc
--       SET @cOutField02 = @cID
--       SET @cOutField03 = @cToLoc
--       SET @cOutField04 = @cUOM
--       SET @cOutField05 = CAST(@nSuggQTY AS NVARCHAR)
--     --SET @cOutField06 = CAST(@nSuggQTY AS NVARCHAR)
--
--         IF @nTrace = 1 --Leong01
--         BEGIN
--            EXEC RDT.rdt_STD_EventLog --Leong01
--               @cActionType     = '7',
--               @cUserID         = @cUserName,
--               @nMobileNo       = @nMobile,
--               @nFunctionID     = @nFunc,
--               @cFacility       = @cFacility,
--               @cStorerKey      = @cTaskStorer,
--               @cLocation       = @cFromloc,
--               @cToLocation     = @cToLoc,
--               @cPutawayZone    = '',
--               @cPickZone       = '',
--               @cID             = @cSuggID,
--               @cToID           = @cID,
--               @cLot            = 'PA_Scn6',
--               @cToLot          = '',
--               @cRefNo1         = @cTaskdetailkey,
--               @cRefNo2         = 'GotoScn4',
--               @cRefNo3         = @nFromStep,
--               @cRefNo4         = '',
--               @cRefNo5         = ''
--         END
--
--       SET @nPrevStep = 0
--
--       -- go to previous screen
--       SET @nScn = @nFromScn
--       SET @nStep = @nFromStep
--     END
-- (ChewKP01) End -- User Must PA all QTY , therefore only can be ESC from Screen 1
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cReasonCode = ''

      -- Reset this screen var
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 8. screen = 2100 (Vicky01)
   MSG (Field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey IN (0, 1) -- Either ESC or ENTER
   BEGIN
      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = RTRIM(@cTTMTasktype)

      IF @nFunc = 0
      BEGIN
         SET @nErrNo = 67575
         SET @cErrMsg = rdt.rdtgetmessage( 67575, @cLangCode, 'DSP') --No TaskCode
         GOTO Quit
      END

      SELECT TOP 1 @nToScn = Scn
      FROM RDT.RDTScn WITH (NOLOCK)
      WHERE Func = @nToFunc
      ORDER BY Scn

      IF @nToScn = 0              BEGIN
         SET @nErrNo = 67576
         SET @cErrMsg = rdt.rdtgetmessage( 67576, @cLangCode, 'DSP') --No Screen
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

     -- EventLog - Sign Out Function (james03)
     EXEC RDT.rdt_STD_EventLog
       @cActionType   = '9', -- Sign Out function
       @cUserID       = @cUserName,
       @nMobileNo     = @nMobile,
       @nFunctionID   = @nFunc,
       @cFacility     = @cFacility,
       @cStorerKey    = @cStorerKey,
       @cSKU          = @cTTMStrategykey,
       @cComponentSKU = @cAreaKey,
       @cToID         = @cRefKey01,
       @cLot          = 'PA_Scn8',
       @cTaskdetailkey = @cTaskdetailkey,
       --@cRefNo1       = @cTaskdetailkey,
       @cRefNo2       = @cRefKey02,
       @cRefNo3       = @cRefKey03,
       @cRefNo4       = @cRefKey04,
       @cRefNo5       = @cRefKey05,
       @nStep         = @nStep

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
       V_LOC  = @cFromloc,
       V_ID          = @cID,
       V_UOM         = @cPUOM,
       --V_QTY         = @nQTY,
       
       V_FromStep    = @nFromStep,
       V_FromScn     = @nFromScn,
       V_PUOM_Div    = @nPUOM_Div,
       V_MQTY        = @nMQTY,
       V_PQTY        = @nPQTY,
      
       V_Integer1    = @nQTY,
       V_Integer2    = @nSuggQTY,
       V_Integer3    = @nPrevStep,
       V_Integer4    = @nActMQTY,
       V_Integer5    = @nActPQTY,
       V_Integer6    = @nSUMBOM_Qty,
       V_Integer7    = @nTrace,

-- (ChewKP02)
--       V_String1     = @cAreaKey,
--       V_String2     = @cTTMStrategykey,
       V_String3     = @cToloc,
       V_String4     = @cReasonCode,

       V_String5     = @cTaskdetailkey,

       V_String6     = @cSuggFromloc,
       V_String7     = @cSuggToloc,
       V_String8     = @cSuggID,
       --V_String9     = @nSuggQTY,
       V_String10    = @cUserPosition,
       --V_String11    = @nPrevStep,
       V_String12    = @cPrevTaskdetailkey,
       V_String13    = @cPackkey,
       --V_String14    = @nFromStep,
       --V_String15    = @nFromScn,
       V_String16    = @cTaskStorer,
       V_String17    = @cTTMTasktype,
       -- (james04)
       V_String18    = @cMUOM_Desc,
       V_String19    = @cPUOM_Desc,
       --V_String20    = @nPUOM_Div,
       --V_String21    = @nMQTY,
       --V_String22    = @nPQTY,
       --V_String23    = @nActMQTY,
       --V_String24    = @nActPQTY,
       --V_String25    = @nSUMBOM_Qty,
       V_STRING26    = @cAltSKU,
       V_STRING27    = @cPUOM,
       V_String28    = @cPrepackByBOM, -- (james08)
       --V_String29    = @nTrace, -- (Vicky09)
       V_String30    = @cRefKey01, -- (Vicky10)


      V_String32     = @cAreaKey,         --(ChewKP02)
      V_String33     = @cTTMStrategykey,  --(ChewKP02)
      V_String34     = @cTTMTasktype,     --(ChewKP02)
      V_String35     = @cRefKey01,        --(ChewKP02)
      V_String36     = @cRefKey02,        --(ChewKP02)
      V_String37     = @cRefKey03,        --(ChewKP02)
      V_String38     = @cRefKey04,        --(ChewKP02)
      V_String39     = @cRefKey05,        --(ChewKP02)

       -- (james04)
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