SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/
/* Store procedure: rdtfnc_TM_Picking                                          */
/* Copyright      : IDS                                                        */
/*                                                                             */
/* Purpose: RDT Task Manager - Picking                                         */
/*          Called By rdtfnc_TaskManager                                       */
/*                                                                             */
/* Modifications log:                                                          */
/*                                                                             */
/* Date        Rev   Author   Purposes                                         */
/* 25-01-2009  1.0   James    Created                                          */
/* 25-02-2010  1.1   James    Misc Bug fix (james01)                           */
/* 26-02-2010  1.2   Vicky    Add @cAreakey to confirm task Sub-SP (Vicky01)   */
/* 02-03-2010  1.3   James    Add in EventLog (james02)                        */
/* 02-03-2010  1.4   James    Add in Lookup for AreaKey (james03)              */
/* 02-03-2010  1.5   Vicky    Fix @cSKU is not being selected (Vicky02)        */
/* 11-03-2010  1.6   Vicky    PrepackByBOM Config should get from WMS and Fix  */
/*                            Prepack UOM & CaseCnt calcualation (Vicky03)     */
/* 11-03-2010  1.7   Vicky    Fix missing field value when the next task is    */
/*                            suggested (Vicky04)                              */
/* 16-03-2010  1.8   James    Add in UOM conversion for prepack (james04)      */
/* 19-03-2010  1.9   Vicky    Fixes on unrelated Orderkey being inserted to    */
/*                            PickHeader for the Loadkey (Vicky06)             */
/* 23-03-2010  2.0   Vicky    Fix taskdetailkey not being pass into mobrec     */
/*                            (Vicky07)                                        */
/* 24-03-2010  2.1   Vicky    Modify: (Vicky08)                                */
/*                            1. Comment REJECT part, PK only allows SHORT     */
/*                            2. For QtyPicked = 0, do not prompt DropID       */
/*                               screen                                        */
/* 25-03-2010  2.2   Vicky    Add trace for concurrency issue (Vicky09)        */
/* 16-06-2010  2.3   Leong    SOS# 176725 - Change TaskDetailKey Variable      */
/* 21-07-2010  2.4   James    SOS182663 - Bug fix (james05)                    */
/* 09-08-2010  2.5   ChewKP   Random Fixes (ChewKP01)                          */
/* 24-08-2010  2.6   Leong    SOS# 187017 - Use TM_PickLog to log data         */
/* 07-07-2011  2.7   James    SOS219045 - Cater for Non BOM (james06)          */
/* 05-01-2012  2.8   ChewKP   SKIPJACK Project Changes - Synchronize V_STRINGXX*/
/*                            (ChewKP02)                                       */
/* 06-04-2015  2.9   ChewKP   SOS#333693 - After Input Reason Code Goto Step 6 */
/*                            (ChewKP03)                                       */
/* 30-09-2016  3.0   Ung      Performance tuning                               */   
/* 16-11-2018  3.1   TungGH   Performance                                      */
/*******************************************************************************/

CREATE PROC [RDT].[rdtfnc_TM_Picking](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
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
   @cDropID             NVARCHAR(18),
   @cSuggID             NVARCHAR(18),
   @cUOM                NVARCHAR(5),   -- Display NVARCHAR(5)
   @cReasonCode         NVARCHAR(10),
   @cSKU                NVARCHAR(20),
   @cDescr              NVARCHAR(60),
   @cAltSKU             NVARCHAR(20),
   @cComponentSKU       NVARCHAR(20),
   @cTaskStorer         NVARCHAR(15),
   @cFromFacility       NVARCHAR(5),
   @c_outstring         NVARCHAR(255),
   @cUserPosition       NVARCHAR(10),
   @cPrevTaskdetailkey  NVARCHAR(10),
   @cQTY                NVARCHAR( 5),
   @cPackkey            NVARCHAR(10),
   @cPickType           NVARCHAR(10),
   @cLoadKey            NVARCHAR(10),
   @cOrderKey           NVARCHAR(10),
   @cSuggestPQTY        NVARCHAR( 5),
   @cSuggestMQTY        NVARCHAR( 5),
   @cActPQTY            NVARCHAR( 5),
   @cActMQTY            NVARCHAR( 5),
   @cPltBuiltDone       NVARCHAR( 1),
   @cSuggestToLoc       NVARCHAR( 10),
   @cPickMethod         NVARCHAR( 10),
   @cPickslipno         NVARCHAR( 10),
   @cContinueProcess    NVARCHAR( 10),
   @n_err               INT,
   @c_errmsg            NVARCHAR(20),
   @cNextTaskdetailkey  NVARCHAR(10),
   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),

   @nQTY                INT,
   @nSum_PalletQty      INT,
   @nToFunc             INT,
   @nSuggQTY            INT,
   @nPrevStep           INT,
   @nFromStep           INT,
   @nFromScn            INT,
   @nToScn              INT,
   @nTD_Qty             INT,
   @nPUOM_Div           INT, -- UOM divider
   @nPQTY               INT, -- Preferred UOM QTY
   @nMQTY               INT, -- Master unit QTY
   @nActQTY             INT, -- Actual QTY
   @nActMQTY            INT, -- Actual keyed in master QTY
   @nActPQTY            INT, -- Actual keyed in prefered QTY
   @nSuggestPQTY        INT, -- Suggested master QTY
   @nSuggestMQTY        INT, -- Suggested prefered QTY
   @nSuggestQTY         INT, -- Suggetsed QTY
   @nSUMBOM_Qty         INT,
   @nOn_HandQty         INT,
   @nTTL_Alloc_Qty      INT,
   @nTaskDetail_Qty     INT,
   @cPUOM               NVARCHAR( 1), -- Prefer UOM
   @cPUOM_Desc          NVARCHAR( 5),
   @cMUOM_Desc          NVARCHAR( 5),
   @cLoc                NVARCHAR( 10),
   @cPrepackByBOM       NVARCHAR( 1),   -- (james04)

   @nTrace              INT, -- (Vicky09)



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
   @cTaskStorer       = StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cSKU             = V_SKU,
   @cDescr           = V_SKUDescr,
   @cFromLoc         = V_LOC,
   @cID              = V_ID,
   @cPUOM            = V_UOM,
   @cLoadKey         = V_LoadKey,
   @cOrderKey        = V_OrderKey,
   
   @nActQty          = V_QTY,

-- (ChewKP02)
--   @cAreaKey         = V_String1,
--   @cTTMStrategykey  = V_String2,

   @cToLoc           = V_String3,
--   @cTTMTasktype     = V_String4,


   @cTaskdetailkey   = V_String5,

   @cSuggFromloc     = V_String6,
   @cSuggToLoc       = V_String7,
   @cSuggID          = V_String8,
   @cUserPosition    = V_String10,
   @cPrevTaskdetailkey = V_String12,
   @cPackkey         = V_String13,
   @cTaskStorer      = V_String16,
   @cMUOM_Desc       = V_String17,
   @cPUOM_Desc       = V_String18,
   @cPickMethod      = V_String25,
   @cDropID          = V_String26,
   @cAltSKU          = V_String27,
   @cRefKey01        = V_String28,
   @cPrepackByBOM    = V_String30,  -- (james04)
   
   @nSuggQTY         = V_Integer1,
   @nPrevStep        = V_Integer2,
   @nActMQTY         = V_Integer3,
   @nActPQTY         = V_Integer4,
   @nSUMBOM_Qty      = V_Integer5,
   @nSuggestQTY      = V_Integer6,
   @nTrace           = V_Integer7,  -- (Vicky09)
   
   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,
   @nPUOM_Div        = V_PUOM_Div,
   @nMQTY            = V_MQTY,
   @nPQTY            = V_PQTY,
      
   @cAreaKey         = V_String32,  --(ChewKP02)
   @cTTMStrategykey  = V_String33,  --(ChewKP02)
   @cTTMTasktype     = V_String34,  --(ChewKP02)
   @cRefKey01        = V_String35,  --(ChewKP02)
   @cRefKey02        = V_String36,  --(ChewKP02)
   @cRefKey03        = V_String37,  --(ChewKP02)
   @cRefKey04        = V_String38,  --(ChewKP02)   
   @cRefKey05        = V_String39,  --(ChewKP02)

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
IF @nFunc = 1758
BEGIN
   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1758, Scn = 2230 -- FromLOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 2231   ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 2232   Qty
   IF @nStep = 4 GOTO Step_4   -- Scn = 2233   DROP ID
   IF @nStep = 5 GOTO Step_5   -- Scn = 2234   TO LOC
   IF @nStep = 6 GOTO Step_6   -- Scn = 2235   MSG
   IF @nStep = 7 GOTO Step_7   -- Scn = 2109   Reason Code screen
   IF @nStep = 8 GOTO Step_8   -- Scn = 2108   Take Empty Pallet Wood screen
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 1. Called from Task Manager Main Screen (func = 1758)
    Screen = 2230
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
      SET @cPickType = @cOutField09 -- either FP (Full Pallet)/PP (Partial Pallet)
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

      SET @cUserPosition = '1'
      SET @nPrevStep = 1

      SET @nTrace = 1 -- (Vicky09)


      SET @cSuggFromLoc = @cOutField01

      -- (ChewKP01) Should not Re-assigned the values
--      -- (Vicky04) - Start
--      SET @cTaskdetailkey = @cOutField06
--      SET @cAreaKey = @cOutField07
--      SET @cTTMStrategykey = @cOutField08
--      SET @cPickType = @cOutField09
--      -- (Vicky04) - End

      SET @cFromLoc = @cInField02

      -- (Vicky09)
      IF @nTrace = 1
      BEGIN
         Declare @cTStatus NVARCHAR(10), @cTUser NVARCHAR(15)

         SELECT @cTStatus = Status,
                @cTUser = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailkey

         INSERT INTO RDT.RDTTMLOG (UserName, TaskUserName, MobileNo, AreaKey, TaskType, PrevTaskdetailkey, Taskdetailkey, PrevStatus, CurrStatus, Func, Scn, Step)
         VALUES (@cUsername, @cTUser, @nMobile, @cAreaKey, 'PK_Scn1', '', @cTaskdetailkey, '', @cTStatus, @nFunc, @nScn, @nStep)
      END

      IF @cFromloc = ''
      BEGIN
         SET @nErrNo = 68766
         SET @cErrMsg = rdt.rdtgetmessage( 68766, @cLangCode, 'DSP') --FromLoc Req
         GOTO Step_1_Fail
      END

      IF @cFromLoc <> @cSuggFromLoc
      BEGIN
         SET @nErrNo = 68767
         SET @cErrMsg = rdt.rdtgetmessage( 68767, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_1_Fail
      END

--      IF @nPrevStep > 0     -- (james01)
--      BEGIN
--         SET @cSuggFromLoc = @cOutField01
--         SET @cTaskdetailkey = @cOutField06
--         SET @cAreaKey = @cOutField07
--         SET @cTTMStrategykey = @cOutField08
--      END

      SELECT @cTaskStorer = Storerkey,
             @cSuggID = FromID,
             @cSuggToLoc = ToLoc,
             @cPickMethod = PickMethod,
             @cLoadKey = LoadKey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskdetailkey

      -- retrieve AreaKey (james03)
      SELECT @cAreaKey = AD.AreaKey FROM dbo.LOC L WITH (NOLOCK)
      JOIN dbo.AreaDetail AD WITH (NOLOCK) ON (L.Putawayzone = AD.Putawayzone)
      WHERE L.LOC = @cSuggFromLoc
         AND L.Facility = @cFacility

      -- (james02) EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '1', -- Sign in function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      -- Get prefer UOM
      SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
      FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
      WHERE M.Mobile = @nMobile

      -- prepare next screen
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cSuggID
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''


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

      SET @cFromLOC = ''

      SET @nFromScn  = @nScn
      SET @nFromStep = @nStep

      -- Go to Reason Code Screen
      SET @nScn  = 2109
      SET @nStep = @nStep + 6 -- Step 7
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
Step 2. screen = 2231
   FROM LOC (Field01)
   ID       (Field02)
   ID       (Field03, input)
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
      SET @cID = @cInField03

      IF @cSuggID <> '' AND @cID = ''
      BEGIN
         SET @nErrNo = 68768
         SET @cErrMsg = rdt.rdtgetmessage( 68768, @cLangCode, 'DSP') --ID Req
         GOTO Step_2_Fail
      END

      -- Enter ID <> Suggested ID, go taskdetail to retrieve the ID to work on
      IF @cSuggID <> @cID
      BEGIN
         SET @nErrNo = 68769
         SET @cErrMsg = rdt.rdtgetmessage( 68769, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_2_Fail
      END

      -- Check LoadKey got something to pick for the given LOC & ID
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cTaskStorer
            AND PD.LOC = @cFromLoc
            AND PD.ID = @cID
            AND PD.Status = '0'
            AND O.LoadKey = @cLoadKey)
      BEGIN
         SET @nErrNo = 68770
         SET @cErrMsg = rdt.rdtgetmessage( 68770, @cLangCode, 'DSP') --PKTaskNotExists
         GOTO Step_2_Fail
      END

      SELECT @cSKU = '', @cAltSKU = '', @cOrderKey = ''

      SELECT TOP 1 @cAltSKU = LA.Lottable03
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      WHERE PD.StorerKey = @cTaskStorer
         AND PD.LOC = @cFromLoc
         AND PD.ID = @cID
         AND PD.Status = '0'
         AND O.LoadKey = @cLoadKey

      -- If prepackbybom is turned on then this is picking by non bom -- (james06)
      SELECT @cPrepackByBOM = ISNULL(RTRIM(sValue), '0')
      FROM dbo.StorerConfig WITH (NOLOCK)
      WHERE Configkey = 'PrePackByBOM'
      AND   Storerkey = @cTaskStorer

      IF @cPrepackByBOM <> '1'
      BEGIN
         SET @cPrepackByBOM = '0'

         -- make sure it is treat as non bom picking  (james06)
         SET @cAltSKU = ''
      END

      -- If not found parent sku then this is not prepack bom
      IF ISNULL(@cAltSKU, '') = ''
      BEGIN
         SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0),
                @cSKU = PD.SKU -- (Vicky02)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cTaskStorer
            AND PD.LOC = @cFromLoc
            AND PD.ID = @cID
            AND PD.Status = '0'
            AND O.LoadKey = @cLoadKey
         GROUP BY PD.SKU -- (Vicky02)
      END
      ELSE
      BEGIN
         -- If AltSKU is not blank from LotAttribute then check for the validity of the parent sku
         IF EXISTS (SELECT 1 FROM dbo.BillOfMaterial WITH (NOLOCK) WHERE StorerKey = @cTaskStorer AND SKU = @cAltSKU)
         BEGIN
            -- If AltSKU is a valid parent sku
            SELECT @nSum_PalletQty = ISNULL(SUM(PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.ComponentSKU)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            WHERE PD.StorerKey = @cTaskStorer
               AND PD.LOC = @cFromLoc
               AND PD.ID = @cID
               AND PD.Status = '0'
               AND BOM.SKU = @cAltSKU
               AND O.LoadKey = @cLoadKey
         END
         ELSE
         BEGIN
            -- If AltSKU is not a valid parent sku then treat this as non prepack bom
            SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0),
                   @cSKU = PD.SKU -- (Vicky02)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            WHERE PD.StorerKey = @cTaskStorer
               AND PD.LOC = @cFromLoc
               AND PD.ID = @cID
--                  AND PD.SKU = @cSKU
               AND PD.Status = '0'
               AND O.LoadKey = @cLoadKey
            GROUP BY PD.SKU -- (Vicky02)

            SET @cAltSKU = ''
         END
       END
--      END
--      ELSE
--         SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0)
--         FROM dbo.PickDetail PD WITH (NOLOCK)
--         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
--         WHERE PD.StorerKey = @cTaskStorer
--            AND PD.LOC = @cFromLoc
--            AND PD.ID = @cID
--            AND PD.AltSKU = @cAltSKU
--            AND PD.Status = '0'
--            AND O.LoadKey = @cLoadKey

      -- (Vicky03) - Start
--      DECLARE @cPrepackByBOM NVARCHAR(1) -- (james04)

--      SELECT @cPrepackByBOM = ISNULL(RTRIM(sValue), '0')
--      FROM dbo.StorerConfig WITH (NOLOCK)
--      WHERE Configkey = 'PrePackByBOM'
--      AND   Storerkey = @cTaskStorer
--
--      IF @cPrepackByBOM = ''
--      BEGIN
--         SET @cPrepackByBOM = '0'

         -- make sure it is treat as non bom picking  (james06)
--         SET @cAltSKU = ''
--      END
      -- (Vicky03) - Start


      -- IF WMS Config 'PrePackByBOM' turned on then show Parent SKU & Descr
      -- ELSE show current taskdetail SKU & Descr
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1' -- (Vicky03)
      --rdt.RDTGetConfig( @nFunc, 'PrePackByBOM', @cTaskStorer) = '1'
      BEGIN
         SET @cSKU = @cAltSKU
         SET @cPUOM = '2' --Case

         SET @nSUMBOM_Qty = 0
         SELECT @nSUMBOM_Qty = ISNULL(SUM(Qty), 0) FROM dbo.BillOfMaterial WITH (NOLOCK) WHERE SKU = @cSKU
         AND StorerKey = @cTaskStorer -- (james05)
     END

      SELECT @cDescr = '', @cMUOM_Desc = '', @cPUOM_Desc = '', @nPUOM_Div = 0

      -- (Vicky03) - Start
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1' -- (Vicky05)
      BEGIN
         SELECT
            @cDescr = SKU.Descr,
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
            AND UPC.SKU = @cSKU
            AND UPC.UOM = 'CS'
      END
      -- (Vicky03) - End
      ELSE
      BEGIN
      -- Get Pack info
         SELECT
            @cDescr = SKU.Descr,
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
         SET @nMQTY = @nSum_PalletQty
      END
      ELSE
      BEGIN
         IF ISNULL(@cAltSKU, '') = ''
         BEGIN
            SET @nPQTY = @nSum_PalletQty / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nSum_PalletQty % @nPUOM_Div  -- Calc the remaining in master unit
         END
         ELSE
         BEGIN
            SET @nPQTY = @nSum_PalletQty / (@nSUMBOM_Qty * @nPUOM_Div)  -- Calc QTY in preferred UOM
            SET @nMQTY = @nSum_PalletQty % (@nSUMBOM_Qty * @nPUOM_Div)  -- Calc the remaining in master unit
         END
      END

      SELECT @cPickSlipno = ''
      DECLARE CUR_PD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT PD.ORDERKEY FROM dbo.PICKDETAIL PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey) -- (Vicky06)
      WHERE PD.StorerKey = @cTaskStorer
         AND PD.LOC = @cFromLoc
         AND PD.ID = @cID
         AND PD.Status = '0'
       AND O.Loadkey = @cLoadkey -- (Vicky06)
      OPEN CUR_PD
      FETCH NEXT FROM CUR_PD INTO @cOrderKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @cPickSlipno = PickheaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey-- AND Zone = 'D'

         -- Create Pickheader
         IF ISNULL(@cPickSlipno, '') = ''
         BEGIN

            BEGIN TRAN
            EXECUTE dbo.nspg_GetKey
               'PICKSLIP',
               9,
               @cPickslipno OUTPUT,
               @b_success OUTPUT,
               @n_err OUTPUT,
               @c_errmsg OUTPUT

            IF @n_err <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 68771
               SET @cErrMsg = rdt.rdtgetmessage( 68771, @cLangCode, 'DSP') --GetDetKey Fail
               GOTO Step_2_Fail
            END

            SELECT @cPickslipno = 'P' + @cPickslipno

            INSERT INTO dbo.PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)
            VALUES (@cPickslipno, @cLoadKey, @cOrderKey, '0', 'D', '')

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 68772
               SET @cErrMsg = rdt.rdtgetmessage( 68772, @cLangCode, 'DSP') --InstPKHdr Fail
               GOTO Step_2_Fail
            END
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            INSERT INTO dbo.PickingInfo
            (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
            VALUES
            (@cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName)

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 68773
               SET @cErrMsg = rdt.rdtgetmessage( 68773, @cLangCode, 'DSP') --Scan In Fail
               GOTO Step_2_Fail
            END
         END

         -- (Vicky06) - Start
         UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
         SET PickSlipNo = @cPickSlipNo, TrafficCop = NULL
         WHERE OrderKey = @cOrderKey

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 68794
            SET @cErrMsg = rdt.rdtgetmessage( 68794, @cLangCode, 'DSP') -- UpdPickDetailFail
            GOTO Step_2_Fail
         END
         -- (Vicky06) - End

         FETCH NEXT FROM CUR_PD INTO @cOrderKey
      END
      CLOSE CUR_PD
      DEALLOCATE CUR_PD

      -- prepare next screen
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSKU   -- ParentSKU
      SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cDescr, 21, 20)
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
         SET @cOutField09 = '' -- @nActPQTY
         IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'   -- (james04)
         BEGIN
            SET @cOutField11 = '1:' + CAST( @nSUMBOM_Qty AS NVARCHAR( 6))
         END
         ELSE
         BEGIN
            SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         END
      END
    --SET @cOutField06 = @cMUOM_Desc -- SOS# 176725
      SET @cOutField12 = @cMUOM_Desc -- SOS# 176725
      IF @nPQTY <= 0    -- (james01)
      BEGIN
         SET @cOutField07 = ''
         SET @cOutField09 = ''
         SET @cInField09 = ''
         SET @cFieldAttr09 = 'O'
      END

      IF @nMQTY > 0
      BEGIN
         SET @cOutField08 = CAST( @nMQTY as NVARCHAR( 5))
         SET @cInField10 = ''
         SET @cFieldAttr10 = ''
      END
      ELSE
      BEGIN
         SET @cOutField08 = ''
    SET @cInField10 = ''
         SET @cFieldAttr10 = 'O'
      END

      IF @nPQTY > 0     -- (james01)
         EXEC rdt.rdtSetFocusField @nMobile, 09
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 10

      SET @cOutField10 = '' -- ActMQTY


      SET @nPrevStep = 2

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

      SET @cUserPosition = '1'

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
Step 3. screen = 2232
   ID          (Field01)
   SKU         (Field02)
   DESCR       (Field03)
   DESCR       (Field04)
   UOM         (Field09, 10)
   SUGGEST QTY (Field11, 12)
   ACTUAL QTY  (Field13, 14)
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

      -- Validate ActPQTY
      IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 68774
         SET @cErrMsg = rdt.rdtgetmessage( 68774, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 09 -- PQTY
         GOTO Step_3_Fail
      END

      -- Validate ActMQTY
      IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 68775
         SET @cErrMsg = rdt.rdtgetmessage( 68775, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY
         GOTO Step_3_Fail
      END

      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)
      SET @nActQTY = 0
      -- (james04)
--      IF ISNULL(@cAltSKU, '') = ''
--         SET @nActQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
--      ELSE
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'
      BEGIN
         SET @nActQTY = ISNULL(rdt.rdtConvUOMQty4Prepack( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
      END
      ELSE
      BEGIN
         SET @nActQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
      END

      SET @nActQTY = @nActQTY + @nActMQTY

     -- Validate QTY
      IF @nActQTY = 0
      BEGIN
         -- Go to Reason Code screen
         SET @cUserPosition = '1' -- (Vicky07)

         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''


         SET @nFromScn  = @nScn
         SET @nFromStep = @nStep

         -- Go to Reason Code Screen
         SET @nScn  = 2109
         SET @nStep = @nStep + 4 -- Step 6

         GOTO QUIT
      END

      -- Calc total QTY in master UOM
      SET @nSuggestQTY = 0
      SET @nSuggestPQTY = 0
      SET @nSuggestMQTY = 0
      SET @nSuggestPQTY = CAST( @cSuggestPQTY AS INT)
      SET @nSuggestMQTY = CAST( @cSuggestMQTY AS INT)

      -- (james04)
--      IF ISNULL(@cAltSKU, '') = ''
--         SET @nSuggestQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, @nSuggestPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
--      ELSE
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'
         SET @nSuggestQTY = ISNULL(rdt.rdtConvUOMQty4Prepack( @cTaskStorer, @cSKU, @nSuggestPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
      ELSE
         SET @nSuggestQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, @nSuggestPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM

      SET @nSuggestQTY = @nSuggestQTY + @nSuggestMQTY

      IF @nActQTY > @nSuggestQTY
      BEGIN
         SET @nErrNo = 68777
         SET @cErrMsg = rdt.rdtgetmessage( 68777, @cLangCode, 'DSP') --'QTY > Suggest'
         IF @cPUOM_Desc = ''
            EXEC rdt.rdtSetFocusField @nMobile, 10
         GOTO Step_3_Fail
      END

      -- Go to Reason Code, only execute PA after reason keyed in
      IF @nActQTY < @nSuggestQTY
      BEGIN
         -- Go to Reason Code screen
         SET @cUserPosition = '1' -- (Vicky07)

         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''

         SET @nFromScn  = @nScn
         SET @nFromStep = @nStep

         -- Go to Reason Code Screen
         SET @nScn  = 2109
         SET @nStep = @nStep + 4 -- Step 6

         GOTO QUIT
      END

      -- prepare next screen
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cID
      SET @cOutField03 = ''

--      For Phase 2
--      IF @cPickMethod = 'PP'
--      BEGIN
--         SET @cOutField04 = ''
--         SET @cOutField05 = ''
--         SET @cOutField06 = ''
--      END
--      ELSE
--      BEGIN
--         SET @cOutField04 = ''
--         SET @cOutField05 = ''
--         SET @cOutField06 = ''
--         SET @cFieldAttr04 = 'O'
--         SET @cFieldAttr05 = 'O'
--         SET @cFieldAttr06 = 'O'
--      END

      SET @nPrevStep = 3

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- prepare next screen
      SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cID
      SET @cOutField03 = ''

      IF @nPrevStep = 0
      BEGIN
         SET @nPrevStep = @nStep
         SET @cToLOC = ''
      END

      SET @cUserPosition = '2'

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
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

      SET @cOutField09 = '' -- ActPQTY
      SET @cOutField10 = '' -- ActMQTY
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 2233
   FROM LOC        (Field01)
   ID              (Field02)
   DROP ID      (Field03, input)
   PLT BUILT DONE  (Field04, input)
********************************************************************************/
Step_4:
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
      SET @cDropID = @cInField03

      IF ISNULL(@cDropID, '') = ''
      BEGIN
         SET @nErrNo = 68778
         SET @cErrMsg = rdt.rdtgetmessage( 68778, @cLangCode, 'DSP') --Drop ID Req
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 03
         GOTO Quit
      END

      -- Drop ID must be unique across pickdetail
      IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cTaskStorer
            AND DropID = @cDropID
            AND LOC <> @cFromLoc -- not equal current from loc
            AND ID <> @cID)   -- not equal current id
      BEGIN
         SET @nErrNo = 68779
         SET @cErrMsg = rdt.rdtgetmessage( 68779, @cLangCode, 'DSP') --DropID Exists
         SET @cDropID = ''
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 03
         GOTO Quit
      END

      -- Drop ID must be unique across DropID table
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
         WHERE DropID = @cDropID)
      BEGIN
         SET @nErrNo = 68780
         SET @cErrMsg = rdt.rdtgetmessage( 68780, @cLangCode, 'DSP') --DropID Exists
         SET @cDropID = ''
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 03
         GOTO Quit
      END

/*    For Phase 2
      -- If partial pallet pick, need to check the uniqueness of DROP ID. Same Drop ID
      -- cannot appear more than one time.
      IF @cPickMethod = 'PP'
      BEGIN
         SET @cPltBuiltDone = @cInField06

         -- Drop ID must be unique across pickdetail
         IF EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
            WHERE StorerKey = @cTaskStorer
               AND DropID = @cDropID
               AND LOC <> @cFromLoc -- not equal current from loc
               AND ID <> @cID)   -- not equal current id
         BEGIN
            SET @nErrNo = 68779
            SET @cErrMsg = rdt.rdtgetmessage( 68779, @cLangCode, 'DSP') --DropID Exists
            SET @cDropID = ''
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 03
            GOTO Quit
         END

         -- Drop ID must be unique across DropID table
         IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
            WHERE DropID = @cDropID)
         BEGIN
            SET @nErrNo = 68780
            SET @cErrMsg = rdt.rdtgetmessage( 68780, @cLangCode, 'DSP') --DropID Exists
            SET @cDropID = ''
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 03
            GOTO Quit
         END

         IF ISNULL(@cPltBuiltDone, '') = ''
         BEGIN
            SET @nErrNo = 68781
            SET @cErrMsg = rdt.rdtgetmessage( 68781, @cLangCode, 'DSP') -- Option req
            SET @cOutField04 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 04
            GOTO Quit
         END

         IF ISNULL(@cPltBuiltDone, '') NOT IN ('1', '2')
         BEGIN
            SET @nErrNo = 68782
            SET @cErrMsg = rdt.rdtgetmessage( 68782, @cLangCode, 'DSP') -- Invalid Option
            SET @cOutField04 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 04
            GOTO Quit
         END

         IF ISNULL(@cPltBuiltDone, '') = '2'
  BEGIN
            EXECUTE RDT.rdt_TM_Picking_ConfirmTask
               @nMobile,
               @nFunc,
               @cTaskStorer,
               @cUserName,
               @cFacility,
               @cTaskDetailKey,
               @cLoadKey,
               @cSKU,
               @cAltSKU,
               @cFromLoc,
               @cToLoc,
               @cID,
               @cDropID,
               @nActQty,
               '5',
               @cLangCode,
               @nErrNo OUTPUT,
               @cErrMsg OUTPUT,
               @cAreakey -- (Vicky01)

            IF @nErrNo <> 0
               GOTO Quit

            -- Search for next task and redirect screen
            SET @cErrMsg = ''
            SET @cNextTaskdetailkey = ''
            SET @cTTMTasktype = ''
            SET @cRefKey01 = ''
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
            ,  @c_lastloc       = @cToLoc
            ,  @c_lasttasktype  = ''
            ,  @c_outstring     = @c_outstring    OUTPUT
            ,  @b_Success       = @b_Success      OUTPUT
            ,  @n_err           = @nErrNo         OUTPUT
            ,  @c_errmsg        = @cErrMsg        OUTPUT
            ,  @c_taskdetailkey = @cNextTaskdetailkey OUTPUT
            ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
            ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
            ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
            ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
            ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
            ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

            IF ISNULL(@cNextTaskdetailkey, '') <> ''
               SET @cTaskdetailkey = @cNextTaskdetailkey

            IF ISNULL(RTRIM(@cNextTaskdetailkey), '') <> ''--@nErrNo = 67804 -- Nothing to do!
            BEGIN
               IF @cTTMTasktype = 'PK'
               BEGIN
                  -- This screen will only be prompt if the QTY to be picked is not full Pallet
                  IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                     WHERE TaskDetailKey = @cTaskdetailkey
                        AND PickMethod <> 'FP')  --FP = full pallet; PP = partial pallet
                  BEGIN
                     SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskdetailkey

                     -- Get on hand qty
                     SELECT @nOn_HandQty = ISNULL(SUM(QTY - QtyAllocated - QtyPicked), 0)
                     FROM dbo.LotxLocxID WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND LOC = @cRefKey01

                     -- Get total allocated qty
                     SELECT @nTTL_Alloc_Qty = ISNULL(SUM(QTY), 0)
                     FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND LOC = @cRefKey01
                        AND Status = '0'

                     IF @nOn_HandQty > @nTTL_Alloc_Qty
                     BEGIN
          SET @nScn = 2108
                       SET @nStep = 8
                    GOTO Quit
                     END
                  END
               END
               ELSE
               BEGIN
                  SET @cOutField01 = @cRefKey01
                  SET @nScn = @nScn - 3
                  SET @nStep = @nStep - 3

                  SET @cOutField01 = @cRefKey01
                  SET @cOutField02 = @cRefKey02
                  SET @cOutField03 = @cRefKey03
                  SET @cOutField04 = @cRefKey04
                  SET @cOutField05 = @cRefKey05
                  SET @cOutField06 = @cTaskdetailkey
                  SET @cOutField07 = @cAreaKey
                  SET @cOutField08 = @cTTMStrategykey
                  SET @nInputKey = 3 -- NOT to auto ENTER when it goes to first screen of next task
               END
               GOTO Quit
            END
            ELSE
            BEGIN
                -- EventLog - Sign In Function  (james02)
                EXEC RDT.rdt_STD_EventLog
                   @cActionType = '9', -- Sign out function
                   @cUserID     = @cUserName,
                   @nMobileNo   = @nMobile,
                   @nFunctionID = @nFunc,
                   @cFacility   = @cFacility,
                   @cStorerKey  = @cStorerKey,
                   @nStep       = @nStep
            END
         END
      END
*/
     -- prepare next screen
     SET @cOutField01 = @cFromloc
     SET @cOutField02 = @cID
     SET @cOutField03 = @cDropID
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField04 = '' -- @cPUOM_Desc
         SET @cOutField06 = '' -- @nPQTY
         SET @cOutField10 = '1:1' -- @nPUOM_Div
         SET @cFieldAttr06 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField04 = @cPUOM_Desc
         SET @cOutField06 = CAST( @nActPQTY AS NVARCHAR( 5))
         SET @cOutField09 = '' -- @nActPQTY
         SET @cOutField10 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END
      SET @cOutField05 = @cMUOM_Desc
      IF @nActMQTY > 0
         SET @cOutField07 = CAST( @nActMQTY as NVARCHAR( 5))
      ELSE
         SET @cOutField07 = ''

      IF @nActPQTY <= 0    -- (james01)
         SET @cOutField06 = ''

      SET @cOutField08 = @cSuggToloc
      SET @cOutField09 = ''

      SET @nPrevStep = 4

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- prepare next screen
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSKU   -- ParentSKU
      SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cDescr, 21, 20)
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
         SET @cOutField09 = '' -- @nActPQTY
         IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'   -- (james04)
            SET @cOutField11 = '1:' + CAST( @nSUMBOM_Qty AS NVARCHAR( 6))
         ELSE
            SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END
    --SET @cOutField06 = @cMUOM_Desc -- SOS# 176725
      SET @cOutField12 = @cMUOM_Desc -- SOS# 176725
      SET @cOutField08 = CAST( @nMQTY as NVARCHAR( 5))
      SET @cOutField10 = '' -- ActMQTY
      IF @nPQTY <= 0    -- (james01)
      BEGIN
         SET @cOutField07 = ''
         SET @cOutField09 = ''
         SET @cInField09 = ''
         SET @cFieldAttr09 = 'O'
      END

      IF @nMQTY > 0
      BEGIN
         SET @cInField10 = ''
         SET @cFieldAttr10 = ''
      END
      ELSE
      BEGIN
         SET @cOutField08 = ''   -- (james01)
         SET @cInField10 = ''
         SET @cFieldAttr10 = 'O'
      END

      IF @nPQTY > 0     -- (james01)
  EXEC rdt.rdtSetFocusField @nMobile, 09
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 10

      IF @nPrevStep = 0
      BEGIN
         SET @nPrevStep = @nStep
      END

      SET @cUserPosition = '2'

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 5. screen = 2234
   FROM LOC        (Field01)
   ID              (Field02)
   DROP ID         (Field03)
   UOM             (Field04)
   ACTUAL QTY      (Field05)
   TO LOC          (Field06, input)
********************************************************************************/
Step_5:
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

      SET @cSuggestToLoc = ISNULL(@cOutField08, '')
      SET @cToLoc = ISNULL(@cInField09, '')

      IF @cToLoc = ''
      BEGIN
         SET @nErrNo = 68783
         SET @cErrMsg = rdt.rdtgetmessage( 68783, @cLangCode, 'DSP') --TO LOC req
         GOTO Step_5_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLoc AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 68784
         SET @cErrMsg = rdt.rdtgetmessage( 68784, @cLangCode, 'DSP') --BAD Location
         GOTO Step_5_Fail
      END

      IF @cSuggestToLoc <> @cToLoc
      BEGIN
         SET @nErrNo = 68785
         SET @cErrMsg = rdt.rdtgetmessage( 68785, @cLangCode, 'DSP') --Invalid TO LOC
         GOTO Step_5_Fail
      END

      INSERT INTO dbo.TM_PickLog
            ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
            , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
            , DropID, PickQty, PDQty, Status, Areakey
            , Col1, Col2, Col3, Col4, Col5
            , Col6, Col7, Col8, Col9, Col10 )
      VALUES( @nMobile, @nFunc, @cTaskStorer, @cUserName, @cFacility, @cTaskDetailKey
            , '', @cLoadKey, @cSKU, @cAltSKU, @cFromLoc, @cToLoc, @cID
            , @cDropID, @nActQty, '', '', @cAreakey
            , @nSuggestQTY, '', '', '', ''
            , '', '', '', '', 'CFMTASK-MAIN' )

      IF @nActQty < @nSuggestQTY
         EXECUTE RDT.rdt_TM_Picking_ConfirmTask
            @nMobile,
            @nFunc,
            @cTaskStorer,
            @cUserName,
            @cFacility,
            @cTaskDetailKey,
            @cLoadKey,
            @cSKU,
            @cAltSKU,
            @cFromLoc,
            @cToLoc,
            @cID,
            @cDropID,
            @nActQty,
            '4',
            @cLangCode,
            @nErrNo OUTPUT,
            @cErrMsg OUTPUT,
            @cAreakey -- (Vicky01)
      ELSE
         EXECUTE RDT.rdt_TM_Picking_ConfirmTask
            @nMobile,
            @nFunc,
            @cTaskStorer,
            @cUserName,
            @cFacility,
            @cTaskDetailKey,
            @cLoadKey,
            @cSKU,
            @cAltSKU,
            @cFromLoc,
            @cToLoc,
            @cID,
            @cDropID,
            @nActQty,
            '5',
            @cLangCode,
            @nErrNo OUTPUT,
            @cErrMsg OUTPUT,
            @cAreakey -- (Vicky01)

      IF @nErrNo <> 0
         GOTO Step_5_Fail

      SET @nPrevStep = 5

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0
   BEGIN
      -- prepare previous screen
    SET @cOutField01 = @cFromLoc
      SET @cOutField02 = @cID
      SET @cOutField03 = ''

--      For Phase 2
--      IF @cPickMethod = 'PP'
--      BEGIN
--         SET @cOutField04 = 'PLT BUILD DONE'
--         SET @cOutField05 = '1 = YES 2 = NO'
--         SET @cOutField06 = ''
--      END
--      ELSE
--      BEGIN
--         SET @cOutField04 = ''
--         SET @cOutField05 = ''
--         SET @cOutField06 = ''
--         SET @cFieldAttr04 = 'O'
--         SET @cFieldAttr05 = 'O'
--         SET @cFieldAttr06 = 'O'
--      END

      IF @nPrevStep = 0
      BEGIN
         SET @nPrevStep = @nStep
      END

      SET @cUserPosition = '2'

      -- Go to next screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField09 = ''      -- (james01)
   END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 2235
   Picking successfull Message
********************************************************************************/
Step_6:
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

      -- Search for next task and redirect screen
      SELECT @cErrMsg = '', @cNextTaskdetailkey = '', @cTTMTasktype = ''

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
      ,  @c_outstring     = @c_outstring  OUTPUT
      ,  @b_Success       = @b_Success      OUTPUT
      ,  @n_err           = @nErrNo         OUTPUT
      ,  @c_errmsg        = @cErrMsg        OUTPUT
      ,  @c_taskdetailkey = @cNextTaskdetailkey OUTPUT
      ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
      ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

      IF ISNULL(RTRIM(@cNextTaskdetailkey), '') = ''--@nErrNo = 67804 -- Nothing to do!
      BEGIN
          -- EventLog - Sign In Function  (james01)
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

         SET @nPrevStep = 0   -- (james04)

         GOTO QUIT
      END

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_6_Fail
      END

      -- (Vicky09)
      IF @nTrace = 1
      BEGIN

         SELECT @cTStatus = Status,
                @cTUser = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailkey

         INSERT INTO RDT.RDTTMLOG (UserName, TaskUserName, MobileNo, AreaKey, TaskType, PrevTaskdetailkey, Taskdetailkey, PrevStatus, CurrStatus, Func, Scn, Step)
         VALUES (@cUsername, @cTUser, @nMobile, @cAreaKey, 'PK_Succ', @cTaskdetailkey, @cNextTaskdetailkey, '', @cTStatus, @nFunc, @nScn, @nStep)
      END


      IF ISNULL(@cNextTaskdetailkey, '') <> ''
      BEGIN
         SET @cTaskdetailkey = @cNextTaskdetailkey
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
               GOTO Step_6_Fail
            END

            IF @nTaskDetail_Qty = 0
            BEGIN
               SET @nErrNo = 68795
               SET @cErrMsg = rdt.rdtgetmessage( 68795, @cLangCode, 'DSP') --tdqty=0
               GOTO Step_6_Fail
            END


            IF @nOn_HandQty > @nTaskDetail_Qty
            BEGIN
               SET @nScn = 2108
               SET @nStep = 8

               GOTO Quit
            END
         END
      END

      SET @nToFunc = 0
      SET @nToScn = 0

      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = RTRIM(@cTTMTasktype)

      IF @nFunc = 0
      BEGIN
         SET @nErrNo = 68786
         SET @cErrMsg = rdt.rdtgetmessage( 68786, @cLangCode, 'DSP') --NextTaskFncErr
         GOTO Step_6_Fail
      END

      SELECT TOP 1 @nToScn = Scn
      FROM RDT.RDTScn WITH (NOLOCK)
      WHERE Func = @nToFunc
      ORDER BY Scn

      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 68787
         SET @cErrMsg = rdt.rdtgetmessage( 68787, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Step_6_Fail
      END

      SET @cOutField01 = @cRefKey01
      SET @cOutField02 = @cRefKey02
      SET @cOutField03 = @cRefKey03
      SET @cOutField04 = @cRefKey04
      SET @cOutField05 = @cRefKey05
      SET @cOutField06 = @cTaskdetailkey
      SET @cOutField07 = @cAreaKey
      SET @cOutField08 = @cTTMStrategykey

      -- EventLog - Sign In Function   (james02)
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

      SET @nPrevStep = 0
   END

   IF @nInputKey = 0    --ESC
   BEGIN
      -- EventLog - Sign Out Function (james02)
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
     SET @nPrevStep = 0    -- (james01)

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

   Step_6_Fail:
END
/********************************************************************************
Step 7. screen = 2109
     REASON CODE  (Field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReasonCode = @cInField01

      IF @cReasonCode = ''
      BEGIN
        SET @nErrNo = 68788
        SET @cErrMsg = rdt.rdtgetmessage( 68788, @cLangCode, 'DSP') --Reason Req
        GOTO Step_7_Fail
      END

      SELECT @cFromLoc = FROMLOC, @cID = FROMID, @cSuggToloc = TOLOC, @nTD_Qty = Qty
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskdetailkey

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
           ,  @n_qty           = @nActQty--0 -- (Vicky08)
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
        GOTO Step_7_Fail
      END

      SET @cContinueProcess = ''
      SELECT @cContinueProcess = ContinueProcessing FROM dbo.TASKMANAGERREASON WITH (NOLOCK)
      WHERE TaskManagerReasonKey = @cReasonCode


      INSERT INTO dbo.TM_PickLog
            ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
            , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
            , DropID, PickQty, PDQty, Status, Areakey
            , Col1, Col2, Col3, Col4, Col5
            , Col6, Col7, Col8, Col9, Col10 )
      VALUES( @nMobile, @nFunc, @cTaskStorer, @cUserName, @cFacility, @cTaskDetailKey
            , '', @cLoadKey, @cSKU, @cAltSKU, @cFromLoc, @cToLoc, @cID
            , @cDropID, @nActQty, '', '', @cAreakey
            , @nSuggestQTY, @cContinueProcess, @cReasonCode, '', ''
            , '', '', '', 'Reason', 'CFMTASK-MAIN' )

      IF ISNULL(@cContinueProcess, '') = '1' AND @nActQty > 0 -- (Vicky08)
      BEGIN
         SET @cOutField01 = @cFromloc
         SET @cOutField02 = @cID
         SET @cOutField03 = ''
         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField04 = '' -- @cPUOM_Desc
            SET @cOutField06 = '' -- @nPQTY
            SET @cOutField10 = '1:1' -- @nPUOM_Div
            SET @cFieldAttr06 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField04 = @cPUOM_Desc
            SET @cOutField06 = CAST( @nActPQTY AS NVARCHAR( 5))
            SET @cOutField09 = '' -- @nActPQTY
            SET @cOutField10 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         END
         SET @cOutField05 = @cMUOM_Desc
         IF @nActMQTY > 0
            SET @cOutField07 = CAST( @nActMQTY as NVARCHAR( 5))
         ELSE
            SET @cOutField07 = ''
         SET @cOutField08 = @cSuggToloc
         SET @cOutField09 = ''

         SET @nScn = 2233
         SET @nStep = 4
         GOTO Quit
      END
      ELSE IF ISNULL(@cContinueProcess, '') = '1' AND @nActQty = 0 -- (Vicky08)
--      IF ISNULL(@cReasonCode, '') <> 'REJECT'
      BEGIN

         INSERT INTO dbo.TM_PickLog
               ( Mobile, Func, StorerKey, UserName, Facility, TaskDetailKey
               , PickDetailKey, LoadKey, SKU, AltSKU, LOC, ToLOC, ID
               , DropID, PickQty, PDQty, Status, Areakey
               , Col1, Col2, Col3, Col4, Col5
               , Col6, Col7, Col8, Col9, Col10 )
         VALUES( @nMobile, @nFunc, @cTaskStorer, @cUserName, @cFacility, @cTaskDetailKey
               , '', @cLoadKey, @cSKU, @cAltSKU, @cFromLoc, @cToLoc, @cID
               , @cDropID, @nActQty, '', '4', @cAreakey
               , @nSuggestQTY, @cContinueProcess, @cReasonCode, '', ''
               , '', '', '', 'Reason', 'CFMTASK-MAIN' )

         SET @cErrMsg = ''
         EXECUTE RDT.rdt_TM_Picking_ConfirmTask
            @nMobile,
            @nFunc,
            @cTaskStorer,
            @cUserName,
            @cFacility,
            @cTaskDetailKey,
            @cLoadKey,
            @cSKU,
            @cAltSKU,
            @cFromLoc,
            @cToLoc,
            @cID,
            @cDropID,
            @nActQty,
            '4',
            @cLangCode,
            @nErrNo OUTPUT,
            @cErrMsg OUTPUT,
            @cAreakey -- (Vicky01)

         IF @nErrNo <> 0
         BEGIN
            GOTO Step_7_Fail
         END

         -- (Vicky08) - Start
         SET @nScn = 2235
         SET @nStep = 6
         GOTO Quit
         -- (Vicky08) - End
      END
-- Comment By (Vicky08) - Start
--      ELSE
--      BEGIN
--         BEGIN TRAN
--
--         -- Confirm PK task
--         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
--            Status = 'R',
--            EditDate = GETDATE(),
--            EditWho = @cUserName
--         WHERE TaskDetailKey = @cTaskDetailKey
--
--         IF @@ERROR <> 0
--         BEGIN
--         SET @nErrNo = 68791
--         SET @cErrMsg = rdt.rdtgetmessage( 68791, @cLangCode, 'DSP') --ConfTask Fail
--         ROLLBACK TRAN
--         GOTO Step_7_Fail
--         END
--
--         -- Confirm PK task
--         UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
--            Status = 'R',
--            EditDate = GETDATE(),
--            EditWho = @cUserName
--         WHERE RefTaskKey = @cTaskDetailKey
--            AND TaskType = 'NMV'
--
--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 68792
--            SET @cErrMsg = rdt.rdtgetmessage( 68792, @cLangCode, 'DSP') --ConfTask Fail
--            ROLLBACK TRAN
--            GOTO Step_7_Fail
--         END
--
----         UPDATE LLI WITH (ROWLOCK) SET
----            LLI.PendingMoveIN = CASE WHEN LLI.PendingMoveIN - (LLI.PendingMoveIN - TD.Qty) < 0 THEN 0
----                              ELSE LLI.PendingMoveIN - TD.Qty END
----         FROM dbo.LotxLocxID LLI
----         JOIN dbo.TaskDetail TD ON (LLI.LOC = TD.ToLOC AND LLI.ID = TD.ToID)
----         WHERE TD.StorerKey = @cTaskStorer
----            AND TD.RefTaskKey = @cTaskDetailKey
----            AND TD.Status = 'R'
--
--         UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET
--            PendingMoveIN = PendingMoveIN - @nTD_Qty
--         WHERE StorerKey = @cTaskStorer
--            AND LOC = @cSuggToloc
--            AND ID = @cID
--
--         IF @@ERROR <> 0
--         BEGIN
--            SET @nErrNo = 68793
--            SET @cErrMsg = rdt.rdtgetmessage( 68793, @cLangCode, 'DSP') --ConfTask Fail
--            ROLLBACK TRAN
--            GOTO Step_7_Fail
--         END
--
--         COMMIT TRAN
--      END
-- Comment By (Vicky08) - End
      
      -- (ChewKP03) 
      /*
      -- Search for next task and redirect screen
      SELECT @cErrMsg = '', @cNextTaskdetailkey = '', @cTTMTasktype = ''

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
      ,  @c_taskdetailkey = @cNextTaskdetailkey OUTPUT
      ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
      ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
      ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

      IF ISNULL(RTRIM(@cNextTaskdetailkey), '') = ''--@nErrNo = 67804 -- Nothing to do!
      BEGIN
          -- EventLog - Sign In Function  (james01)
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

         SET @nPrevStep = 0 -- (ChewKP01)

         GOTO QUIT
      END

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_7_Fail
      END

      -- (Vicky09)
      IF @nTrace = 1
      BEGIN

         SELECT @cTStatus = Status,
                @cTUser = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailkey

         INSERT INTO RDT.RDTTMLOG (UserName, TaskUserName, MobileNo, AreaKey, TaskType, PrevTaskdetailkey, Taskdetailkey, PrevStatus, CurrStatus, Func, Scn, Step)
         VALUES (@cUsername, @cTUser, @nMobile, @cAreaKey, 'PK_Reason', @cTaskdetailkey, @cNextTaskdetailkey, '', @cTStatus, @nFunc, @nScn, @nStep)
      END

      IF ISNULL(@cNextTaskdetailkey, '') <> ''
         SET @cTaskdetailkey = @cNextTaskdetailkey

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
               SET @nErrNo = 68796
               SET @cErrMsg = rdt.rdtgetmessage( 68796, @cLangCode, 'DSP') --onhandqty=0
               GOTO Step_7_Fail
            END

            IF @nTaskDetail_Qty = 0
            BEGIN
               SET @nErrNo = 68797
               SET @cErrMsg = rdt.rdtgetmessage( 68797, @cLangCode, 'DSP') --tdqty=0
               GOTO Step_7_Fail
            END

            IF @nOn_HandQty > @nTaskDetail_Qty
            BEGIN
               SET @nScn = 2108
               SET @nStep = 8
               GOTO Quit
            END
         END
      END

      SET @nToFunc = 0
      SET @nToScn = 0

      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = RTRIM(@cTTMTasktype)

      IF @nFunc = 0
      BEGIN
         SET @nErrNo = 68789
         SET @cErrMsg = rdt.rdtgetmessage( 68789, @cLangCode, 'DSP') --NextTaskFncErr
         GOTO Step_7_Fail
      END


      SELECT TOP 1 @nToScn = Scn
      FROM RDT.RDTScn WITH (NOLOCK)
      WHERE Func = @nToFunc
      ORDER BY Scn

      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 68790
         SET @cErrMsg = rdt.rdtgetmessage( 68790, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Step_7_Fail
      END

      SET @cOutField01 = @cRefKey01
      SET @cOutField02 = @cRefKey02
      SET @cOutField03 = @cRefKey03
      SET @cOutField04 = @cRefKey04
      SET @cOutField05 = @cRefKey05
      SET @cOutField06 = @cTaskdetailkey
      SET @cOutField07 = @cAreaKey
      SET @cOutField08 = @cTTMStrategykey
      */
      
      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep


      
      SET @nScn = 2235
      SET @nStep = 6 

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

     IF @nFromStep = 1 -- ESC from Screen 1
     BEGIN
       SET @cOutField01 = @cOutField09

       -- go to previous screen
       SET @nScn = @nFromScn
       SET @nStep = @nFromStep
     END
     ELSE IF @nFromStep = 3 -- ESC from Screen 3 - QTY
     BEGIN
      -- prepare next screen
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSKU   -- ParentSKU
      SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cDescr, 21, 20)
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
         SET @cOutField09 = '' -- @nActPQTY
         SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END
    --SET @cOutField06 = @cMUOM_Desc -- SOS# 176725
      SET @cOutField12 = @cMUOM_Desc -- SOS# 176725
      SET @cOutField08 = CAST( @nMQTY as NVARCHAR( 5))
      SET @cOutField10 = '' -- ActMQTY
      IF @nPQTY <= 0    -- (james01)
      BEGIN
         SET @cOutField07 = ''
         SET @cOutField09 = ''
         SET @cFieldAttr09 = 'O'
      END

      IF @nMQTY > 0
      BEGIN
         SET @cInField10 = ''
         SET @cFieldAttr10 = ''
      END
      ELSE
      BEGIN
         SET @cOutField08 = ''   -- (james01)
         SET @cInField10 = ''
         SET @cFieldAttr10 = 'O'
      END

      IF @nPQTY > 0     -- (james01)
         EXEC rdt.rdtSetFocusField @nMobile, 09
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 10

       SET @nPrevStep = 2

       -- go to previous screen
       SET @nScn = @nFromScn
       SET @nStep = @nFromStep
     END
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cReasonCode = ''

      -- Reset this screen var
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 8. screen = 2100
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

  IF @nToScn = 0
      BEGIN
         SET @nErrNo = 67576
         SET @cErrMsg = rdt.rdtgetmessage( 67576, @cLangCode, 'DSP') --No Screen
         GOTO Quit
      END

     SET @nPrevStep = 0  -- (james01)

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

      StorerKey     = @cTaskStorer,
      Facility      = @cFacility,
      Printer       = @cPrinter,
      -- UserName      = @cUserName,

      V_SKU         = @cSKU,
      V_SKUDescr    = @cDescr,
      V_LOC         = @cFromloc,
      V_ID          = @cID,
      V_UOM         = @cPUOM,
      V_LoadKey     = @cLoadKey,
      V_OrderKey    = @cOrderKey,
      
      V_QTY         = @nActQty,

--(ChewKP02)
--      V_String1     = @cAreaKey,
--      V_String2     = @cTTMStrategykey,
      V_String3     = @cToloc,
--      V_String4     = @cTTMTasktype,

      V_String5     = @cTaskdetailkey,

      V_String6     = @cSuggFromloc,
      V_String7     = @cSuggToloc,
      V_String8     = @cSuggID,
      V_String10    = @cUserPosition,
      V_String12    = @cPrevTaskdetailkey,
      V_String13    = @cPackkey,
      V_String16    = @cTaskStorer,
      V_String17    = @cMUOM_Desc,
      V_String18    = @cPUOM_Desc,
      V_String25    = @cPickMethod,
      V_String26    = @cDropID,
      V_String27    = @cAltSKU,
      V_String28    = @cRefKey01,
      V_String30    = @cPrepackByBOM,  -- (james04)
      
      V_Integer1    = @nSuggQTY,
      V_Integer2    = @nPrevStep,
      V_Integer3    = @nActMQTY,
      V_Integer4    = @nActPQTY,
      V_Integer5    = @nSUMBOM_Qty,
      V_Integer6    = @nSuggestQTY,
      V_Integer7    = @nTrace, -- (Vicky09)
      
      V_String32     = @cAreaKey,         --(ChewKP02)
      V_String33     = @cTTMStrategykey,  --(ChewKP02)
      V_String34     = @cTTMTasktype,     --(ChewKP02)
      V_String35     = @cRefKey01,        --(ChewKP02)
      V_String36     = @cRefKey02,        --(ChewKP02)
      V_String37     = @cRefKey03,        --(ChewKP02)
      V_String38     = @cRefKey04,        --(ChewKP02)
      V_String39     = @cRefKey05,        --(ChewKP02)

      
      V_FromStep    = @nFromStep,
      V_FromScn     = @nFromScn,
      V_PUOM_Div    = @nPUOM_Div,
      V_MQTY        = @nMQTY,
      V_PQTY        = @nPQTY,
      
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