SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/    
/* Store procedure: rdtfnc_TaskManager                                       */    
/* Copyright      : IDS                                                      */    
/*                                                                           */    
/* Purpose: RDT Task Manager                                                 */    
/*          Related Module: RDT TM Putaway                                   */    
/*                                                                           */    
/* Modifications log:                                                        */    
/*                                                                           */    
/* Date       Rev  Author   Purposes                                         */    
/* 2009-09-28 1.0  Vicky    Created                                          */    
/* 2010-01-28 1.1  James    Prompt "Take empty pallet wood" scn when qty to  */    
/*                          take < total qty on pallet (james01)             */    
/* 2010-03-01 1.2  Vicky    Add RESET of variables when ESC from Scn1        */    
/* 2010-05-08 1.3  Vicky    Add RDT Storerconfig to not allow user to enter  */    
/*                          empty Areakey (Vicky01)                          */    
/* 2010-06-24 1.4  ChewKP   Changes for RDT Standard for V_String_32-40      */    
/*                          (ChewKP01)                                       */    
/* 2010-06-30 1.5  ChewKP   Add in RDT.Storerconfig = NotPromptPalletMSG     */    
/*                          for Diana (ChewKP02)                             */    
/* 2010-07-06 1.6  AQSKC    Add in dynamic retrieval of RDT screen title     */    
/*                          for DPK and DRP task which share same func/scn   */    
/*                          (KC01)                                           */    
/* 2010-07-07 1.7  ChewKP   Add in RDT.Storerconfig = 'PromptToteMsg' for    */    
/*                          Diana (ChewKP03)                                 */    
/* 2010-07-21 1.8  ChewKP   Initialize all unused  V_string Values when      */    
/*                          ,  it enter TM Module (ChewKP04)                 */    
/* 2010-07-27 1.9  James    SOS#183278 Fix Message Errors (james02)          */    
/* 2010-07-30 2.0  Shong    Initial value for ToScn and ToFunc (Shong01)     */    
/* 2010-09-17 2.1  KHLim    Assign TaskDetail.StatusMsg to OutField1-10      */    
/*                          (KHLim01)                                        */    
/* 2011-03-11 2.1  James    Add tasktype 'SPK' (james03)                     */    
/* 2011-11-09 2.2  ChewKP   SOS#227151 TM CC (ChewKP05)                      */    
/* 2012-10-30 2.3  James    SOS257258 - Indicate a TM CC supervisor count by */    
/*                          putting '(s)' besides suggested loc (james04)    */    
/* 2013-07-11 2.4  TLTING   Perfromance Tune                                 */    
/* 2013-05-09 2.5  Ung      Add TTMStrategyDetail.Step (ung01)               */    
/* 2013-05-30 2.6  Ung      SOS279795 Add ExtendedUpdateSP                   */    
/* 2014-01-28 2.7  James    SOS296464 - Add device id param (james05)        */    
/* 2014-07-41 2.8  ChewKP   SOS#313947 DTC Enhancement (ChewKP06)            */
/* 2015-11-23 2.9  James    SOS#350672 Cater TMCC no storerkey (james06)     */
/* 2016-09-30 3.0  Ung      Performance tuning                               */   
/* 2017-03-28 3.1  James    WMS1349-Support PPK task type (james07)          */
/* 2018-10-03 3.2  TungGH   Performance                                      */
/* 2019-12-03 3.3  James    WMS-11350 Add default areakey (james08)          */
/*****************************************************************************/    
CREATE PROC [RDT].[rdtfnc_TaskManager](    
   @nMobile    INT,    
   @nErrNo     INT  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max    
) AS    
    
SET NOCOUNT ON        
SET ANSI_NULLS OFF        
SET QUOTED_IDENTIFIER OFF        
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
   @cFromloc            NVARCHAR(10),    
   @cTaskdetailkey      NVARCHAR(10),    
   @cPrevTaskType       NVARCHAR(10),    
   @c_outstring         NVARCHAR(255),    
   @cLoc                NVARCHAR(10),    
   @cID                 NVARCHAR(18),    
   @cStatusMsg          NVARCHAR(255),    
    
   @cRefKey01           NVARCHAR(20),    
   @cRefKey02           NVARCHAR(20),    
   @cRefKey03           NVARCHAR(20),    
   @cRefKey04           NVARCHAR(20),    
   @cRefKey05           NVARCHAR(20),    
    
   @c_BlankAreakey      NVARCHAR(1), -- (Vicky01)    
    
   @nToFunc             INT,    
   @nToScn              INT,    
   @nToStep             INT, -- (ung01)    
    
   @nOn_HandQty         INT,    
   @nTTL_Alloc_Qty      INT,    
   @nTaskDetail_Qty     INT,    
    
   @c_ShowTote          NVARCHAR(1),  --(ChewKP02)    
--   @c_Tote              NVARCHAR(18), --(ChewKP02)    
   @c_DTote             NVARCHAR(18), --(ChewKP02)    
   @cTaskStorer         NVARCHAR(15), --(ChewKP02)    
   @cSKU                NVARCHAR(20), --(ChewKP02)    
   @cSuggID             NVARCHAR(18), --(ChewKP02)    
   @cPrepackByBOM      NVARCHAR(1),  --(ChewKP02)    
   @c_BOMSKU            NVARCHAR(20), --(ChewKP02)    
   @cDescr              NVARCHAR( 60),--(ChewKP02)    
   @cUserPosition       NVARCHAR(10), --(ChewKP02)    
   @cCaseID             NVARCHAR(10), --(ChewKP02)    
   @cSuggToLoc          NVARCHAR(10), --(ChewKP02)    
   @nPrevStep           INT,      --(ChewKP02)    
   @cLot                NVARCHAR(10), --(ChewKP02)    
   @nSuggQTY            INT,      --(ChewKP02)    
   --@nQTY                 INT,      --(ChewKP02)    
   @cDescr1             NVARCHAR( 20),--(ChewKP02)    
   @cDescr2             NVARCHAR( 20),--(ChewKP02)    
   @c_PromptPalletMSG   NVARCHAR(1) , --(ChewKP02)    
   @c_DropID            NVARCHAR(20),    
   @c_PromptToteMsg     NVARCHAR(1),    
   @cDeviceID           NVARCHAR( 20),    -- (james05)    
   @cDefaultAreaKey     NVARCHAR( 10),    -- (james08)    
    
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
   @cLot             = V_Lot,    
   @cTaskDetailKey   = V_TaskDetailKey, -- (ChewKP05)    
   @cTaskdetailkey   = V_String5,    
   @cTaskStorer      = V_String16,    
    
   @cAreaKey         = V_String32,  --(ChewKP01)    
   @cTTMStrategykey  = V_String33,  --(ChewKP01)    
   @cTTMTasktype     = V_String34,  --(ChewKP01)    
   @cRefKey01        = V_String35,  --(ChewKP01)    
   @cRefKey02        = V_String36,  --(ChewKP01)    
   @cRefKey03        = V_String37,  --(ChewKP01)    
   @cRefKey04        = V_String38,  --(ChewKP01)    
   @cRefKey05        = V_String39,  --(ChewKP01)    
    
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
IF @nFunc = 1756    
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1756    
   IF @nStep = 1 GOTO Step_1   -- Scn = 2100   Area    
   IF @nStep = 7 GOTO Step_7   -- Scn = 2107   Take empty tote -- (ChewKP03)    
   IF @nStep = 8 GOTO Step_8   -- Scn = 2108   Take empty pallet wood    
END    
RETURN -- Do nothing if incorrect step    
    
    
/********************************************************************************    
Step 0. Called from menu (func = 1756)    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Set the entry point    
   SET @nScn  = 2100    
   SET @nStep = 1    

   -- initialise all variable    
   SET @cAreaKey = ''
   
   -- Try get default areakey from user setup. if not setup then get from rdt config
   SELECT @cDefaultAreaKey = AreaKey
   FROM rdt.RDTUser WITH (NOLOCK)
   WHERE UserName = @cUserName

   IF ISNULL( @cDefaultAreaKey, '') = ''
   BEGIN
      SET @cDefaultAreaKey = rdt.RDTGetConfig( @nFunc, 'DefaultAreaKey', @cStorerKey)
      IF @cDefaultAreaKey NOT IN ('', '0')
         SET @cAreaKey = @cDefaultAreaKey
   END
   ELSE
      SET @cAreaKey = @cDefaultAreaKey

   -- Prep next screen var    
   SET @cOutField01 = CASE WHEN @cAreaKey <> '' THEN @cAreaKey ELSE '' END   -- Area    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. screen = 2100    
   Area (Field01, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cAreaKey = @cInField01    
    
      -- (Vicky01) - Start    
      SET @c_BlankAreakey = rdt.RDTGetConfig( @nFunc, 'NotAllowBlankAreaKey', @cStorerKey)    
    
      IF @c_BlankAreakey = '1'    
      BEGIN    
         IF ISNULL(RTRIM(@cAreaKey), '') = ''    
         BEGIN    
             SET @nErrNo = 67577    
             SET @cErrMsg = rdt.rdtgetmessage( 67577, @cLangCode, 'DSP') --Areakey Req    
             GOTO Step_1_Fail    
         END    
      END    
      -- (Vicky01) - End    
    
      IF ISNULL(RTRIM(@cAreaKey), '') <> ''    
      BEGIN    
         -- Check if Area exists    
         IF NOT EXISTS ( SELECT 1    
            FROM dbo.AreaDetail WITH (NOLOCK)    
            WHERE AreaKey = @cAreaKey)    
         BEGIN    
            SET @nErrNo = 67566    
            SET @cErrMsg = rdt.rdtgetmessage( 67566, @cLangCode, 'DSP') --Invalid Area    
            GOTO Step_1_Fail    
         END    
    
         -- Check if Area same as RDT User setup    
         IF NOT EXISTS ( SELECT 1    
            FROM dbo.TaskManagerUserDetail WITH (NOLOCK)    
            WHERE AreaKey = @cAreaKey    
            AND   UserKey = @cUsername)    
         BEGIN    
            SET @nErrNo = 67567    
            SET @cErrMsg = rdt.rdtgetmessage( 67567, @cLangCode, 'DSP') --Not User Area    
            GOTO Step_1_Fail    
         END    
    
         -- Check if RDT User has permission on this area    
         IF NOT EXISTS ( SELECT 1    
            FROM dbo.TaskManagerUserDetail WITH (NOLOCK)    
            WHERE AreaKey = @cAreaKey    
            AND   UserKey = @cUsername    
            AND   Permission = '1')    
         BEGIN    
            SET @nErrNo = 67568    
            SET @cErrMsg = rdt.rdtgetmessage( 67568, @cLangCode, 'DSP') --No Permission    
            GOTO Step_1_Fail    
         END    
      END    
    
      SELECT @cStrategykey = ISNULL(RTRIM(Strategykey), '')    
      FROM  dbo.TaskManagerUser WITH (NOLOCK)    
      WHERE UserKey = @cUserName    
    
      IF ISNULL(RTRIM(@cStrategykey), '') = ''    
      BEGIN    
         SET @nErrNo = 67569    
         SET @cErrMsg = rdt.rdtgetmessage( 67569, @cLangCode, 'DSP') --Bad Strategykey    
         GOTO Step_1_Fail    
      END    
    
      IF NOT EXISTS (SELECT 1 FROM dbo.STRATEGY WITH (NOLOCK) WHERE Strategykey = @cStrategykey)    
      BEGIN    
         SET @nErrNo = 67570    
         SET @cErrMsg = rdt.rdtgetmessage( 67570, @cLangCode, 'DSP') --Bad Strategy    
         GOTO Step_1_Fail    
      END    
    
      SELECT @cTTMStrategykey = Ttmstrategykey    
      FROM dbo.STRATEGY WITH (NOLOCK)    
      WHERE Strategykey = @cStrategykey    
    
      IF @cTTMStrategykey = ''    
      BEGIN    
         SET @nErrNo = 67571    
         SET @cErrMsg = rdt.rdtgetmessage( 67571, @cLangCode, 'DSP') --Bad TTMStrategykey    
         GOTO Step_1_Fail    
      END    
    
      IF NOT EXISTS (SELECT 1 FROM dbo.TTMSTRATEGY WITH (NOLOCK) WHERE TTMStrategykey = @cTTMStrategykey) OR    
         NOT EXISTS (SELECT 1 FROM dbo.TTMSTRATEGYDETAIL WITH (NOLOCK) WHERE TTMStrategykey = @cTTMStrategykey)    
      BEGIN    
         SET @nErrNo = 67572    
         SET @cErrMsg = rdt.rdtgetmessage( 67572, @cLangCode, 'DSP') --Bad TTMStrategy    
         GOTO Step_1_Fail    
      END    
    
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
         ,  @c_lasttasktype  = ''    
         ,  @c_outstring     = @c_outstring    OUTPUT    
         ,  @b_Success       = @b_Success      OUTPUT    
         ,  @n_err           = @nErrNo         OUTPUT    
         ,  @c_errmsg        = @cErrMsg        OUTPUT    
         ,  @c_taskdetailkey = @cTaskdetailkey OUTPUT    
         ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT    
         ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func    
         ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func    
         ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func    
         ,  @c_RefKey04      = @cRefKey04  OUTPUT -- this is the field value to parse to 1st Scn in func    
         ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func    
    
      -- No Task will be prompt as Error Msg too.    
      IF ISNULL(@cErrMsg, '') <> ''    
      BEGIN    
         SET @cErrMsg = @cErrMsg    
         GOTO Step_1_Fail    
      END    
    
      SELECT @cTaskStorer = Storerkey FROM dbo.TaskDetail (NOLOCK)    
      WHERE Taskdetailkey = @cTaskdetailkey    

      -- If the taskdetail having blank storerkey, take the storerkey from login
      IF ISNULL( @cTaskStorer, '') <> ''
         SET @cStorerKey = @cTaskStorer
      
      SET @c_PromptPalletMSG  = rdt.RDTGetConfig( 0, 'NotPromptPalletMsg', @cStorerKey)    
      IF @c_PromptPalletMSG = '0'    
      BEGIN    
         -- (james01) start    
         IF @cTTMTasktype = 'PK'    
         BEGIN    
            -- This screen will only be prompt if the QTY to be picked is not full Pallet    
            IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)    
               WHERE TaskDetailKey = @cTaskdetailkey    
                  AND PickMethod <> 'FP'
                  AND PickMethod = 'PP' )  --FP = full pallet; PP = partial pallet   -- (ChewKP06) 
            BEGIN    
               SET @nTaskDetail_Qty = 0    
               SET @nOn_HandQty = 0    
               SELECT @cStorerKey = StorerKey,    
                  @cID = FromID,    
                  @cLoc = FromLOC,    
                  @nTaskDetail_Qty = ISNULL(Qty, 0)    
               FROM dbo.TaskDetail WITH (NOLOCK)    
               WHERE TaskDetailKey = @cTaskdetailkey    
    
               -- Get on hand qty    
               SELECT @nOn_HandQty = ISNULL(SUM(QTY - QtyPicked), 0)    
               FROM dbo.LotxLocxID WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
                  AND LOC = @cLoc    
                  AND ID = @cID    
                  AND QTY > 0    -- tlting01     
    
               IF @nOn_HandQty = 0    
               BEGIN    
                  SET @nErrNo = 67582 -- (james02)    
                  SET @cErrMsg = rdt.rdtgetmessage( 67582, @cLangCode, 'DSP') --onhandqty=0 -- (james02)    
                  GOTO Step_1_Fail    
               END    
    
               IF @nTaskDetail_Qty = 0    
               BEGIN    
                  SET @nErrNo = 67581 -- (james02)    
                  SET @cErrMsg = rdt.rdtgetmessage( 67581, @cLangCode, 'DSP') --tdqty=0 -- (james02)    
                  GOTO Step_1_Fail    
               END    
    
    
               IF @nOn_HandQty > @nTaskDetail_Qty    
               BEGIN    
                 SET @nScn = 2108    
                 SET @nStep = 8    
                 GOTO Quit    
               END    
            END    
         END    
      END    
    
      --(ChewKP02)    
      SELECT   @cRefKey03 = CASE CaseID    
               WHEN '' THEN DropID    
               ELSE CaseID    
               END,    
               @cRefkey04 = PickMethod,    
               @cRefKey05 = CASE TaskType    
               WHEN 'DPK' THEN 'Dynamic Picking  DPK'    
               WHEN 'DRP' THEN 'Dynamic Replen   DRP'    
               ELSE '' END   --(KC01)    
               ,@cFromLoc = FromLoc -- (ChewKP05)    
               ,@cStatusMsg = StatusMsg  -- (KHLim01)    
      From dbo.TaskDetail (NOLOCK)    
      WHERE TaskDetailkey = @cTaskdetailkey    
    
      SET @nToFunc=0 -- (Shong01)    
      SELECT     
         @nToFunc = ISNULL(FUNCTION_ID, 0),     
         @nToStep = Step -- (ung01)    
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)    
      WHERE TaskType = RTRIM(@cTTMTasktype)    
    
      IF @nFunc = 0    
      BEGIN    
         SET @nErrNo = 67573    
         SET @cErrMsg = rdt.rdtgetmessage( 67573, @cLangCode, 'DSP') --No TaskCode    
         GOTO Step_1_Fail    
      END    
    
      IF @cTTMTasktype IN ( 'CC', 'CCSUP', 'CCSV') -- (ChewKP05)    
      BEGIN    
         SET @nToScn=0    
         SELECT TOP 1 @nToScn = ISNULL(Scn,0)    
         FROM RDT.RDTScn WITH (NOLOCK)    
         WHERE Func = 1766    
         ORDER BY Scn    
      END    
      ELSE    
      BEGIN    
         SET @nToScn=0 -- (Shong01)    
         SELECT TOP 1 @nToScn = ISNULL(Scn,0) -- (Shong01)    
         FROM RDT.RDTScn WITH (NOLOCK)    
         WHERE Func = @nToFunc    
         ORDER BY Scn    
      END    
     
  
  
      IF @nToScn = 0    
      BEGIN    
         SET @nErrNo = 67574    
         SET @cErrMsg = rdt.rdtgetmessage( 67574, @cLangCode, 'DSP') --No Screen    
         GOTO Step_1_Fail    
      END    
    
      IF @cTTMTasktype = 'GM' -- (KHLim01)    
      BEGIN    
         declare  @end int,    
                  @i int,    
                  @start int,    
                  @space int,    
                  @length int    
    
         set @start = 0    
         set @end = 0    
         set @space = 0    
         set @length = 0    
    
         set @i = 1    
         while @i <= 10    
         begin    
            while @space < @start + 20    
            begin    
               SET @end = @space    
               SET @space = CHARINDEX(' ', @cStatusMsg, @end+1)    
            end    
            if @end <= @start    
            begin    
               set @end = @start+ 20    
            end    
            IF       @i =  1 SET @cOutField01 = substring(@cStatusMsg,@start,@end-@start)    
            ELSE IF  @i =  2 SET @cOutField02 = substring(@cStatusMsg,@start,@end-@start)    
            ELSE IF  @i =  3 SET @cOutField03 = substring(@cStatusMsg,@start,@end-@start)    
            ELSE IF  @i =  4 SET @cOutField04 = substring(@cStatusMsg,@start,@end-@start)    
            ELSE IF  @i =  5 SET @cOutField05 = substring(@cStatusMsg,@start,@end-@start)    
            ELSE IF  @i =  6 SET @cOutField09 = substring(@cStatusMsg,@start,@end-@start)    
            ELSE IF  @i =  7 SET @cOutField10 = substring(@cStatusMsg,@start,@end-@start)    
            ELSE IF  @i =  8 SET @cOutField11 = substring(@cStatusMsg,@start,@end-@start)    
            ELSE IF  @i =  9 SET @cOutField12 = substring(@cStatusMsg,@start,@end-@start)    
            ELSE IF  @i = 10 SET @cOutField13 = substring(@cStatusMsg,@start,@end-@start)    
            set @start = @end+1    
            set @i = @i + 1    
         end    
      END    
      ELSE    
      BEGIN    
         SET @cOutField01 = @cRefKey01    
         SET @cOutField02 = @cRefKey02    
         SET @cOutField03 = @cRefKey03    
         SET @cOutField04 = @cRefKey04    
         SET @cOutField05 = @cRefKey05    
      END    
    
      SELECT @cDeviceID = DeviceID FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile    
          
      SET @cOutField06 = @cTaskdetailkey    
      SET @cOutField07 = @cAreaKey    
      SET @cOutField08 = @cTTMStrategykey    
      SET @cOutField09 = CASE WHEN @cTTMTasktype IN ('DRP', 'DPK') THEN ''     
                         ELSE CASE WHEN @nToFunc = 1806 THEN @cRefkey04 ELSE @cTTMTasktype END END      -- (james03)    
      SET @cOutField10 = @cFromLoc -- (ChewKP05)    
      SET @cOutField11 = CASE WHEN @cTTMTasktype = 'CCSUP' THEN '(S)' ELSE '' END   -- (james04)    
      SET @cOutField12 = @cDeviceID   -- (james05)    
      SET @nInputKey = 3 -- NOT to auto ENTER when it goes to first screen of next task    
    
      IF @cTTMTasktype = 'NMV'    
      BEGIN    
         -- Get storer configure    
         DECLARE @cExtendedUpdateSP NVARCHAR(20)    
         SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nToFunc, 'ExtendedUpdateSP', @cStorerKey)    
         IF @cExtendedUpdateSP = '0'    
            SET @cExtendedUpdateSP = ''    
             
         -- Extended update    
         IF @cExtendedUpdateSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
            BEGIN    
               DECLARE @cSQL      NVARCHAR(1000)    
               DECLARE @cSQLParam NVARCHAR(1000)    
    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cToLOC, @cNextTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
               SET @cSQLParam =    
                  '@nMobile             INT,     ' +    
                  '@nFunc               INT,        ' +    
                  '@cLangCode           NVARCHAR( 3),   ' +    
                  '@nStep               INT,        ' +    
                  '@cTaskdetailKey      NVARCHAR( 10),  ' +    
                  '@cToLOC              NVARCHAR( 10),  ' +    
                  '@cNextTaskdetailKey  NVARCHAR( 10),  ' +      
                  '@nErrNo              INT OUTPUT, ' +    
                  '@cErrMsg             NVARCHAR( 20) OUTPUT'    
          
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nToFunc, @cLangCode, 0, @cTaskdetailKey, '', '', @nErrNo OUTPUT, @cErrMsg OUTPUT    
          
               IF @nErrNo <> 0    
                  GOTO Quit    
            END    
         END    
      END    
    
      -- (ChewKP03)    
      SET @c_PromptToteMsg  = rdt.RDTGetConfig( 0, 'PromptToteMsg', @cStorerKey)    
      IF @c_PromptToteMsg = '1'    
      BEGIN    
         IF @cTTMTasktype IN ('PK', 'SPK', 'PPK') -- Diana Piece Picking (james03)    
         BEGIN    
            IF @cRefKey03 = ''    
            BEGIN    
               --SET @nFunc = @nToFunc    
               SET @nScn = 2107    
               SET @nStep = 7    
            END    
            ELSE    
            BEGIN    
               
               IF @nToFunc <> 1809 -- (ChewKP06)
               BEGIN
                  
                  
                  SET @nFunc = @nToFunc    
                  SET @nScn = 2436    
                  SET @nStep = 7    
               END
               ELSE
               BEGIN
                  SET @cOutField09 = @cTTMTasktype
                  
                  SET @nFunc = @nToFunc    
                  SET @nScn = 3886    
                  SET @nStep = 7    
               END
            END    
         END    
         ELSE    
         BEGIN    
            SET @nFunc = @nToFunc    
            SET @nScn = @nToScn    
            -- SET @nStep = 1     -- (ung01)    
            SET @nStep = @nToStep -- (ung01)    
         END    
      END    
      ELSE    
      BEGIN    
         SET @nFunc = @nToFunc    
         SET @nScn = @nToScn    
         -- SET @nStep = 1     -- (ung01)    
         SET @nStep = @nToStep -- (ung01)    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Back to menu    
      SET @nFunc = @nMenu    
      SET @nScn  = @nMenu    
      SET @nStep = 0    
    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
      SET @cOutField06 = ''    
      SET @cOutField07 = ''    
      SET @cOutField08 = ''    
    
      SET @cAreaKey  = ''    
      SET @cTaskdetailkey = ''    
      SET @cTTMStrategykey = ''    
      SET @cRefKey01 = ''    
      SET @cRefKey02 = ''    
      SET @cRefKey03 = ''    
      SET @cRefKey04 = ''    
      SET @cRefKey05 = ''    
      SET @cTTMTasktype = ''    
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cAreakey = ''    
    
      -- Reset this screen var    
      SET @cOutField01 = CASE WHEN @cAreaKey <> '' THEN @cAreaKey ELSE '' END  -- AreaKey    
  END    
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
         SET @nErrNo = 67579    
         SET @cErrMsg = rdt.rdtgetmessage( 67575, @cLangCode, 'DSP') --No TaskCode    
         GOTO Quit    
      END    
    
      SELECT TOP 1 @nToScn = Scn    
      FROM RDT.RDTScn WITH (NOLOCK)    
      WHERE Func = @nToFunc    
      ORDER BY Scn    
    
      IF @nToScn = 0    
      BEGIN    
         SET @nErrNo = 67580    
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
     
    
     SET @nFunc = @nToFunc    
     SET @nScn = @nToScn    
     SET @nStep = 1    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 8. screen = 2100    
   MSG (Field01, input)    
********************************************************************************/    
Step_8:  --(james01)    
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
    
      IF @nToScn = 0    
      BEGIN    
         SET @nErrNo = 67576    
         SET @cErrMsg = rdt.rdtgetmessage( 67576, @cLangCode, 'DSP') --No Screen    
         GOTO Quit    
      END    
      
     --(ChewKP08)    
      SELECT   @cRefKey03 = CASE CaseID    
               WHEN '' THEN DropID    
               ELSE CaseID    
               END,    
               @cRefkey04 = PickMethod,    
               @cRefKey05 = CASE TaskType    
               WHEN 'DPK' THEN 'Dynamic Picking  DPK'    
               WHEN 'DRP' THEN 'Dynamic Replen   DRP'    
               ELSE '' END   --(KC01)    
               ,@cFromLoc = FromLoc -- (ChewKP05)    
               ,@cStatusMsg = StatusMsg  -- (KHLim01)    
      From dbo.TaskDetail (NOLOCK)    
      WHERE TaskDetailkey = @cTaskdetailkey
    
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
      InputKey      = @nInputKey,    
    
      StorerKey     = @cStorerKey,    
      Facility      = @cFacility,    
      Printer       = @cPrinter,    
      -- UserName      = @cUserName,    
    
      V_SKU         = @cSKU,    
      V_LOC         = @cFromloc,    
      V_ID          = @cID,    
      V_Lot         = @cLot,    
      V_TaskDetailKey = @cTaskDetailKey, -- (ChewKP05)    

      -- (ChewKP04) Start    
      V_String1 = '',    
      V_String2 = '',    
      V_String3 = '',    
      V_String4 = '',    
    
      V_String6 = '',    
      V_String7 = '',    
      V_String8 = '',    
      V_String9 = '',    
      V_String10 = '',    
      V_String11 = '',    
      V_String12 = '',    
      V_String13 = '',    
      V_String14 = '',    
      V_String15 = '',    
    
      V_String17 = '',    
      V_String18 = '',    
      V_String19 = '',    
      V_String20 = '',    
      V_String21 = '',    
      V_String22 = '',    
      V_String23 = '',    
      V_String24 = '',    
      V_String25 = '',    
      V_String26 = '',    
      V_String27 = '',    
      V_String28 = '',    
      V_String29 = '',    
      V_String30 = '',    
      V_String31 = '',    
    
      V_String40 = '',    
      -- (ChewKP04) End    
    
      V_String5 = @cTaskdetailkey,    
      V_String16 = @cTaskStorer,    
    
      V_String32     = @cAreaKey,         --(ChewKP01)    
      V_String33     = @cTTMStrategykey,  --(ChewKP01)    
      V_String34     = @cTTMTasktype,     --(ChewKP01)    
      V_String35     = @cRefKey01,        --(ChewKP01)    
      V_String36     = @cRefKey02,        --(ChewKP01)    
      V_String37     = @cRefKey03,        --(ChewKP01)    
      V_String38     = @cRefKey04,        --(ChewKP01)    
      V_String39     = @cRefKey05,        --(ChewKP01)    
    
    
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
    
   -- Execute TM module initialization (ung01)    
   IF (@nFunc <> 1756 AND @nStep = 0) AND     
      (@nFunc <> @nMenu) -- ESC from AREA screen to menu    
   BEGIN    
      -- Get the stor proc to execute    
      DECLARE @cStoredProcName NVARCHAR( 1024)    
      SELECT @cStoredProcName = StoredProcName    
      FROM RDT.RDTMsg WITH (NOLOCK)    
      WHERE Message_ID = @nFunc    
    
      -- Execute the stor proc    
      SELECT @cStoredProcName = N'EXEC RDT.' + RTRIM(@cStoredProcName)    
      SELECT @cStoredProcName = RTRIM(@cStoredProcName) + ' @InMobile, @nErrNo OUTPUT,  @cErrMsg OUTPUT'    
      EXEC sp_executesql @cStoredProcName , N'@InMobile int, @nErrNo int OUTPUT,  @cErrMsg NVARCHAR(125) OUTPUT',    
         @nMobile,    
         @nErrNo OUTPUT,    
         @cErrMsg OUTPUT    
   END    
END 

GO