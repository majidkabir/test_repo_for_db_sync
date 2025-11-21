SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*****************************************************************************/
/* Store procedure: rdtfnc_TM_OrderPicking                                   */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: RDT Task Manager - Order Picking                                 */
/*          Called By rdtfnc_TaskManager                                     */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-05-19 1.0  ChewKP   Created                                          */
/* 2012-01-10 1.1  Ung      Fix runtime error upon loading                   */
/*                          Fix close pallet rollback without begin tran     */
/*                          Fix PrinterID, DropID screen various errors      */
/* 2016-09-30 1.2  Ung      Performance tuning                               */  
/* 2018-11-16 1.3  Gan      Performance tuning                               */ 
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_TM_OrderPicking](
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

   @cTaskStorer          NVARCHAR(15),
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
   --@cTaskStorer         NVARCHAR(15),
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
   @cPrepackByBOM       NVARCHAR( 1),   

   @nTrace              INT, 
	@cPrinterID			 NVARCHAR( 20), 

	-- Carton Label Printing Variable (Start)--
	@cBuyerPO            NVARCHAR( 20),
   @cTemplateID         NVARCHAR( 20),
   @cGenTemplateID      NVARCHAR( 20), 
	@cDischargePlace	 NVARCHAR( 20),
	@cGSILBLITF          NVARCHAR( 1),   
	@cFilePath           NVARCHAR( 30),
	@cFilePath1          NVARCHAR( 20),
	@cFilePath2          NVARCHAR( 20),
	@cGS1TemplatePath    NVARCHAR( 120),
	@cGS1TemplatePath1   NVARCHAR( 20), 
	@cGS1TemplatePath2   NVARCHAR( 20), 
   @cGS1TemplatePath3   NVARCHAR( 20), 
   @cGS1TemplatePath4   NVARCHAR( 20), 
   @cGS1TemplatePath5   NVARCHAR( 20), 
   @cGS1TemplatePath6   NVARCHAR( 20), 
	@cGS1TemplatePath_Gen   NVARCHAR( 120), 
   @cGS1TemplatePath_Final NVARCHAR( 120), 
	@c_LoosePick         NVARCHAR( 1),
	@cPackCheck			 NVARCHAR(  1),
	@nUPCCaseCnt         INT,
	@c_ALTSKU			 NVARCHAR( 20),
	@nPDQTY              INT,
	@nTotalBOMQty        INT,
	@nLotCtns            INT,
	@nTotalCtnsALL			INT,
	@nTotalCtns          INT,
	@cTemplateOption	 NVARCHAR(1),
	@cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
	-- Carton Label Printing Variable (End)--

	@cPalleteOption	 NVARCHAR(1),
	@cNMVTask			 NVARCHAR(1),
	@c_taskdetailkey2	 NVARCHAR(10),
	@c_taskdetailkeyNMV NVARCHAR(10),
	@nRemainPQTY         INT,
	@nRemainMQTY         INT,
	@cShortPickOption	 NVARCHAR(1),
	@cWCSFilePath1		 NVARCHAR(50),
	@nCaseCnt            INT,
	@cLot					 NVARCHAR(10),
	@cLLISKU				 NVARCHAR(20),
	@cINToLoc			 NVARCHAR(10),
   @cNMV_Areakey		 NVARCHAR(10),
	@cNMV_PAZone		 NVARCHAR(10),
	@cNMVToLoc			 NVARCHAR(20),
	@cLogicalLoc		 NVARCHAR(18),
	@cSHTPICKOption	 NVARCHAR(1),
	@nActualPendingMoveIn INT,
	@nTotalQTY				INT,
	@nRemainQTY				INT,
	@c_LocationCategory NVARCHAR(10),
	   
   @nPackDetailQTY      INT,
   @nPickDetailQTY      INT,
   
   

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
  -- @nActQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,
   @cLoadKey         = V_LoadKey,
   @cOrderKey        = V_OrderKey,
   
   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,
   @nPUOM_Div        = V_PUOM_Div,
   @nMQTY            = V_MQTY,
   @nPQTY            = V_PQTY, 
   
   @nActQty          = V_Integer1,
   @nSuggQTY         = V_Integer2,
   @nPrevStep        = V_Integer3,
   @nActMQTY         = V_Integer4,
   @nActPQTY         = V_Integer5,
   @nSUMBOM_Qty      = V_Integer6,
   @nSuggestQTY      = V_Integer7,
   @nTrace           = V_Integer8,
   @nTotalCtnsALL    = V_Integer9,
   @nRemainQTY       = V_Integer10,

   @cAreaKey         = V_String1,
   @cTTMStrategykey  = V_String2,
   @cToLoc           = V_String3,
   @cTTMTasktype     = V_String4,
   @cTaskdetailkey   = V_String5,

   @cSuggFromloc     = V_String6,
   @cSuggToLoc       = V_String7,
   @cSuggID          = V_String8,
  -- @nSuggQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,
   @cUserPosition    = V_String10,
  -- @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,
   @cPrevTaskdetailkey = V_String12,
   @cPackkey         = V_String13,
  -- @nFromStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,
  -- @nFromScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,
   @cTaskStorer      = V_String16,
   @cMUOM_Desc       = V_String17,
   @cPUOM_Desc       = V_String18,
  -- @nPUOM_Div        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19, 5), 0) = 1 THEN LEFT( V_String19, 5) ELSE 0 END,
  -- @nMQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String20, 5), 0) = 1 THEN LEFT( V_String20, 5) ELSE 0 END,
  -- @nPQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String21, 5), 0) = 1 THEN LEFT( V_String21, 5) ELSE 0 END,
  -- @nActMQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String22, 5), 0) = 1 THEN LEFT( V_String22, 5) ELSE 0 END,
  -- @nActPQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String23, 5), 0) = 1 THEN LEFT( V_String23, 5) ELSE 0 END,
  -- @nSUMBOM_Qty      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String24, 5), 0) = 1 THEN LEFT( V_String24, 5) ELSE 0 END, 
   @cPickMethod      = V_String25,
   @cDropID          = V_String26,
   @cAltSKU          = V_String27,
   @cRefKey01        = V_String28,
  -- @nSuggestQTY      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String29, 5), 0) = 1 THEN LEFT( V_String29, 5) ELSE 0 END, 
   @cPrepackByBOM    = V_String30,  
  -- @nTrace           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String31, 5), 0) = 1 THEN LEFT( V_String31, 5) ELSE 0 END,  
	@cPrinterID			= V_String32,
	@cTemplateID		= V_String33, 
  -- @nTotalCtnsALL    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String34, 5), 0) = 1 THEN LEFT( V_String34, 5) ELSE 0 END,
	@c_LoosePick      = V_String35,
	@c_taskdetailkeyNMV = V_String36,
  -- @nRemainQTY			= CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String37, 5), 0) = 1 THEN LEFT( V_String37, 5) ELSE 0 END,
	@cSHTPICKOption   = V_String38,
	@cPickslipNo		= V_String39,
	 
	

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
IF @nFunc = 1775
BEGIN
   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1775, Scn = 2350 -- Take Empty Pallet
	IF @nStep = 2 GOTO Step_2   -- Scn = 2351   PRINTER ID, DROPID
	IF @nStep = 3 GOTO Step_3   -- Scn = 2352   FROMLOC
	IF @nStep = 4 GOTO Step_4   -- Scn = 2353   ID
   IF @nStep = 5 GOTO Step_5   -- Scn = 2354   Qty
	IF @nStep = 6 GOTO Step_6   -- Scn = 2355   Template Option
   IF @nStep = 7 GOTO Step_7   -- Scn = 2356   Carton Printed
   IF @nStep = 8 GOTO Step_8   -- Scn = 2357   PALLET Option
	IF @nStep = 9 GOTO Step_9   -- Scn = 2358   TO Loc
	IF @nStep = 10 GOTO Step_10   -- Scn = 2359   MSG
	IF @nStep = 11 GOTO Step_11   -- Scn = 2360   Short Pick
   IF @nStep = 12 GOTO Step_12   -- Scn = 2109   Reason Code screen

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 1. Called from Task Manager Main Screen (func = 1775)
    Screen = 2350
    Take Empty Pallet
********************************************************************************/
Step_1:
BEGIN
   -- Set all variable for 1st record - records are from rdtfnc_TaskManager
	

   BEGIN
      SET @cSuggFromLoc = @cOutField01
      SET @cTaskdetailkey = @cOutField06
      SET @cAreaKey = @cOutField07
      SET @cTTMStrategykey = @cOutField08
      SET @cPickType = @cOutField09 -- either FP (Full Pallet)/PP (Partial Pallet)
      SET @cPrinterID = ''
   END

   IF @nInputKey = 1 -- ENTER
   BEGIN
		SET @cOutField01 = @cPrinterID 
		
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN

		SET @cOutField01 = ''

      ---- Go to Reason Code Screen
      SET @nScn  = 2109
		SET @nStep = @nStep + 11
		
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
Step 2. 
    Screen = 2351
    PRINTER ID  (Field01, input)
	 DROPID		 (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
		SET @cPrinterID = ISNULL(RTRIM(@cInField01), '')  
		SET @cDropID = ISNULL(RTRIM(@cInField02), '')
      
      -- Retain the value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      
		-- Check Printer ID blank
      IF @cPrinterID = ''
      BEGIN
         SET @nErrNo = 69291
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Printer ID req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail
      END

		-- Check DropID blank
      IF @cDropID = ''
      BEGIN
         SET @nErrNo = 69292
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --DROPID require
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail 
      END

		IF EXISTS ( SELECT 1 FROM dbo.TASKDETAIL (NOLOCK) WHERE FROMID = @cDropID )
		BEGIN
			SET @nErrNo = 69293
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --DropIDSameAsPLTID
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField02 = ''
         GOTO Step_2_Fail 
		END
		
      SET @nPickDetailQTY = 0 
      SET @nPackDetailQTY = 0 
		
      SELECT @nPickDetailQTY = SUM(QTY)
	   FROM dbo.PICKDETAIL WITH (NOLOCK, INDEX (IDX_PICKDETAIL_DropID))
	   WHERE DropID = @cDropID

      SELECT @nPackDetailQTY = SUM(QTY)
	   FROM dbo.PACKDETAIL WITH (NOLOCK)
	   WHERE RefNo = @cDropID

      IF @nPickDetailQTY + @nPackDetailQTY > @nPickDetailQTY
      BEGIN
	      SET @nErrNo = 69576
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Over Pack
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail 
      END
		
		SELECT @cSuggFromLoc = FROMLOC
		FROM dbo.TASKDETAIL (NOLOCK)
		WHERE TASKDETAILKEY = @cTaskdetailkey
		
		SET @cOutField01 = @cDropID
		SET @cOutField02 = @cSuggFromLoc

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to Reason Code Screen
		SET @cOutField01 = ''
		
		SET @nFromStep = @nStep
		SET @nFromScn = @nScn

      SET @nScn  = 2109
		SET @nStep = @nStep + 10
   END
   GOTO Quit
   
   Step_2_Fail:

END
GOTO Quit

/********************************************************************************
Step 3. 
    Screen = 2352
	 DROPID (Field01, output)
    FROM LOC (Field02, output)
	 FROM LOC (Field03, input)
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

      SET @cUserPosition = '1'
      SET @nPrevStep = 1

      SET @nTrace = 1 

      SET @cSuggFromLoc = @cOutField02

      SET @cFromLoc = ISNULL(RTRIM(@cInField03),'')
      
      IF @cFromloc = ''
      BEGIN
         SET @nErrNo = 69294
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLoc Req
         GOTO Step_3_Fail    
      END

      IF @cFromLoc <> @cSuggFromLoc
      BEGIN
         SET @nErrNo = 69295
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_3_Fail    
      END


      SELECT @cTaskStorer = Storerkey, 
             @cSuggID = FromID,
             @cSuggToLoc = ToLoc, 
             @cPickMethod = PickMethod, 
             @cLoadKey = LoadKey 
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskdetailkey


      -- retrieve AreaKey (james03)
--      SELECT @cAreaKey = AD.AreaKey FROM dbo.LOC L WITH (NOLOCK) 
--      JOIN dbo.AreaDetail AD WITH (NOLOCK) ON (L.Putawayzone = AD.Putawayzone)
--      WHERE L.LOC = @cSuggFromLoc
--         AND L.Facility = @cFacility

      -- (james02) EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '1', -- Sign in function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerkey  = @cTaskStorer,
         @nStep       = @nStep

      -- Get prefer UOM
      SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
      FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
      WHERE M.Mobile = @nMobile

      -- prepare next screen
		SET @cOutField01 = @cDropID
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = @cSuggID
      SET @cOutField04 = ''
      SET @cOutField05 = ''
		


      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cPrinterID
      SET @cOutField02 = @cDropID
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

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cDropID 
      SET @cOutField02 = @cSuggFromLoc
		SET @cOutField03 = ''  -- (ChewKP01)
      
      

  END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 2353
    DROPID    (Field01, output)
    FROM LOC  (Field02, output)
	 PALLET ID (Field03, output)
	 PALLET ID (Field04, input)
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
      SET @cID = @cInField04

      IF @cSuggID <> '' AND @cID = ''
      BEGIN
         SET @nErrNo = 69296
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Req
         GOTO Step_4_Fail    
      END

      -- Enter ID <> Suggested ID, go taskdetail to retrieve the ID to work on
      IF @cSuggID <> @cID
      BEGIN
         SET @nErrNo = 69297
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_4_Fail   
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
         SET @nErrNo = 69298
         SET @cErrMsg = rdt.rdtgetmessage( 69298, @cLangCode, 'DSP') --PKTaskNotExists
         GOTO Step_4_Fail   
      END


      SELECT @cSKU = '', @cAltSKU = '', @cOrderKey = ''
--      -- Start look for the first task to pick
--      SELECT TOP 1 @cSKU = SKU, @cAltSKU = ALTSKU, @cOrderKey = PD.OrderKey 
--      FROM dbo.PickDetail PD WITH (NOLOCK) 
--      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
--      WHERE PD.StorerKey = @cTaskStorer
--         AND PD.LOC = @cFromLoc
--         AND PD.ID = @cID
--         AND PD.Status = '0'
--         AND O.LoadKey = @cLoadKey
--      ORDER BY PickDetailKey

      -- IF AltSKU = '' means not BOMSKU
--      IF ISNULL(@cAltSKU, '') = ''
--      BEGIN
         SELECT TOP 1 @cAltSKU = LA.Lottable03 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cTaskStorer
            AND PD.LOC = @cFromLoc
            AND PD.ID = @cID
            AND PD.Status = '0'
            AND O.LoadKey = @cLoadKey

         -- If not found parent sku then this is not prepack bom
         IF ISNULL(@cAltSKU, '') = ''
         BEGIN
            SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0),
                   @cSKU = PD.SKU 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            WHERE PD.StorerKey = @cTaskStorer
               AND PD.LOC = @cFromLoc
               AND PD.ID = @cID
               AND PD.Status = '0'
               AND O.LoadKey = @cLoadKey
            GROUP BY PD.SKU 
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
                      @cSKU = PD.SKU 
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
               WHERE PD.StorerKey = @cTaskStorer
                  AND PD.LOC = @cFromLoc
                  AND PD.ID = @cID
--                  AND PD.SKU = @cSKU
                  AND PD.Status = '0'
                  AND O.LoadKey = @cLoadKey
               GROUP BY PD.SKU 

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

       -- Start
--      DECLARE @cPrepackByBOM NVARCHAR(1) 
      
      SELECT @cPrepackByBOM = ISNULL(RTRIM(sValue), '0')
      FROM dbo.StorerConfig WITH (NOLOCK)
      WHERE Configkey = 'PrePackByBOM'
      AND   Storerkey = @cTaskStorer

      IF @cPrepackByBOM = ''
		BEGIN
         SET @cPrepackByBOM = '0'
      END

		

      -- IF WMS Config 'PrePackByBOM' turned on then show Parent SKU & Descr
      -- ELSE show current taskdetail SKU & Descr
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'  
      --rdt.RDTGetConfig( @nFunc, 'PrePackByBOM', @cTaskStorer) = '1'
      BEGIN
         SET @cSKU = @cAltSKU
         SET @cPUOM = '2' --Case

         SET @nSUMBOM_Qty = 0
         SELECT @nSUMBOM_Qty = ISNULL(SUM(Qty), 0) FROM dbo.BillOfMaterial WITH (NOLOCK) WHERE SKU = @cSKU AND Storerkey = @cTaskStorer
      END

      SELECT @cDescr = '', @cMUOM_Desc = '', @cPUOM_Desc = '', @nPUOM_Div = 0



      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1' 
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
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey) 
      WHERE PD.StorerKey = @cTaskStorer
         AND PD.LOC = @cFromLoc
         AND PD.ID = @cID
         AND PD.Status = '0'
         AND O.Loadkey = @cLoadkey 
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
               SET @nErrNo = 69299
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetDetKey Fail
               GOTO Step_4_Fail   
            END

            SELECT @cPickslipno = 'P' + @cPickslipno

            INSERT INTO dbo.PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)
            VALUES (@cPickslipno, @cLoadKey, @cOrderKey, '0', 'D', '')

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 69300
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InstPKHdr Fail
               GOTO Step_4_Fail   
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
               SET @nErrNo = 69301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan In Fail
               GOTO Step_4_Fail   
            END
         END


         UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
			      SET PickSlipNo = @cPickSlipNo, TrafficCop = NULL 
			WHERE OrderKey = @cOrderKey 

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 69301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail
            GOTO Step_4_Fail   
         END


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
         IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'   
            SET @cOutField11 = '1:' + CAST( @nSUMBOM_Qty AS NVARCHAR( 6))
         ELSE
            SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END
      SET @cOutField06 = @cMUOM_Desc
      IF @nPQTY <= 0    
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

      IF @nPQTY > 0     
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
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cSuggFromLoc
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

   Step_4_Fail:
   BEGIN
      SET @cID = ''
  
      -- Reset this screen var
		SET @cOutField01 = @cDropID  -- DROPID
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = @cSuggID
      
   END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 2354
   ID          (Field01)
   SKU         (Field02)
   DESCR       (Field03)
   DESCR       (Field04)
   UOM         (Field05, 06)
   SUGGEST QTY (Field07, 08)
   ACTUAL QTY  (Field09, 10)
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
		   SET @nErrNo = 69303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 09 -- PQTY
			GOTO Step_5_Fail
      END


	
	   -- Validate ActMQTY
      IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0 
      BEGIN
         SET @nErrNo = 69304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY
         GOTO Step_5_Fail
      END

		

      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)
      SET @nActQTY = 0
      
--      IF ISNULL(@cAltSKU, '') = ''
--         SET @nActQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
--      ELSE
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'
		BEGIN
         SET @nActQTY = ISNULL(rdt.rdtConvUOMQty4Prepack( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
			SET @nTotalQTY = ISNULL(rdt.rdtConvUOMQty4Prepack( @cTaskStorer, @cSKU, CAST(@cSuggestPQTY AS INT), @cPUOM, 6), 0) -- Convert to QTY in master UOM
		END
      ELSE
		BEGIN
         SET @nActQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
			SET @nTotalQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, CAST(@cSuggestPQTY AS INT), @cPUOM, 6), 0) -- Convert to QTY in master UOM
		END

      SET @nActQTY = @nActQTY + @nActMQTY

      
      SET @nRemainQTY = (@nTotalQTY + CAST(@cSuggestMQTY AS INT) ) -  @nActQTY
      
   
      -- Validate QTY
      IF @nActQTY = 0  
      BEGIN
      
         SET @cOutField01 = @cOutField11  
         SET @cOutField02 = @cOutField05
         SET @cOutField03 = @cOutField06
         SET @cOutField04 = CAST(@cSuggestPQTY AS INT) - @cActPQTY
         SET @cOutField05 = CAST(@cSuggestMQTY AS INT) - @cActMQTY
			SET @cOutField06 = ''
         
			--SET @cErrMSG = @cSuggestMQTY
			--GOTO QUIT

         -- Go to Short Pick Screen
         SET @nScn  = 2360
         SET @nStep = @nStep + 6 -- Step 11

         GOTO QUIT
      END

      -- Calc total QTY in master UOM
      SET @nSuggestQTY = 0
      SET @nSuggestPQTY = 0
      SET @nSuggestMQTY = 0
      SET @nSuggestPQTY = CAST( @cSuggestPQTY AS INT)
      SET @nSuggestMQTY = CAST( @cSuggestMQTY AS INT)

      
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
         SET @nErrNo = 69305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY > Suggest'
         IF @cPUOM_Desc = ''
            EXEC rdt.rdtSetFocusField @nMobile, 10
         GOTO Step_5_Fail
      END
      


      -- Go to Short Pick
     IF @nActQTY < @nSuggestQTY
     BEGIN

			

         SET @cOutField01 = @cOutField11  
			--SET @cErrMSG = @cOutField11
			--GOTO QUIT

         SET @cOutField02 = @cOutField05
         SET @cOutField03 = @cOutField06
			SET @cOutField04 = CAST(@cSuggestPQTY AS INT) - @cActPQTY
         SET @cOutField05 = CAST(@cSuggestMQTY AS INT) - @cActMQTY
			SET @cOutField06 = ''

         SET @nFromScn  = @nScn
         SET @nFromStep = @nStep

         -- Go to Short Pick Screen
         SET @nScn  = 2360
         SET @nStep = @nStep + 6 -- Step 11
			
         GOTO QUIT
     END
     ELSE IF @nActQTY = @nSuggestQTY
     BEGIN
			 --SET @cErrMSG = @cAltSKU
			 --GOTO QUIT

          EXECUTE RDT.rdt_TM_OrderPicking_ConfirmTask 
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
            '', --@cToLoc,
            @cID,
            @cDropID,
            @nActQty,  
            '5',
            @cLangCode,
				'',
            @nErrNo OUTPUT,
            @cErrMsg OUTPUT,
            @cAreakey 


				-- Update TaskManagerUser with current LoadKey, Loc
				BEGIN TRAN
				UPDATE dbo.TaskManagerUser WITH (ROWLOCK) SET 
					LastLoadKey = @cLoadKey,
					LastDropID = @cID,
					LastLoc = @cFromLOC, -- VNA
					EditDate = GETDATE(), 
					EditWho = @cUserName,
					TrafficCop = NULL
				WHERE UserKey = @cUserName

				IF @@ERROR <> 0
				BEGIN
					SET @nErrNo = 69339
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTMUser Fail'
					ROLLBACK TRAN 
					GOTO QUIT
				END
				ELSE
				BEGIN
					 COMMIT TRAN 
				END	

			
				BEGIN TRAN
				UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
				            ToID = @cDropID, 
				--            Qty = @nTotalPickQty, 
				--            Status = '0', 
				            Trafficcop = NULL, 
				            EditDate = GETDATE(), 
				            EditWho = @cUserName
				            --AreaKey = ISNULL(RTRIM(@cAreakey), '')  
				            --Areakey = ISNULL(RTRIM(@cNMV_Areakey), '') 
				WHERE TaskDetailKey = @cTaskDetailKey
				      AND TaskType = 'OPK'
				--            AND Status = 'W' 
				--
	         IF @@ERROR <> 0
	         BEGIN
	            SET @nErrNo = 69340
	            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OPKTask fail'
					ROLLBACK TRAN 
					GOTO QUIT
	         END
				ELSE
				BEGIN
					 COMMIT TRAN 
				END	

		END		

      -- prepare next screen
--      SET @cOutField01 = @cFromLoc
--      SET @cOutField02 = @cID
--      SET @cOutField03 = ''

--      For Phase 2
--    IF @cPickMethod = 'PP'
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

      --*** Template Validation (Start) ***--
		SET @cTemplateID = ''

		SELECT TOP 1 
		   @cBuyerPO = O.BuyerPO, 
		   @cTemplateID = O.DischargePlace, 
			@cOrderKey = O.OrderKey 
      FROM dbo.ORDERS O WITH (NOLOCK) 
      JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (O.OrderKey = PH.Orderkey)
      WHERE PH.PickHeaderKey = @cPickslipNo
		 AND   PH.ExternOrderKey = @cLoadkey
		 ORDER BY O.Priority, O.BuyerPO
          

--          IF ISNULL(@cTemplateID , '') = '' 
--          BEGIN
--              SET @cTemplateID = ISNULL(RTRIM(@cDischargePlace), '')
--          END

  		    IF ISNULL(@cTemplateID, '') = '' 
		    BEGIN
					-- Prepare next screen var
					SET @cOutField01 = ''
					SET @cGenTemplateID = ''  
		         
					-- Go to next screen
					SET @nScn = @nScn + 1
					SET @nStep = @nStep + 1  

               GOTO QUIT
          END
 		--*** Template Validation (End) ***--

		-- *** Carton Label Printing (Start) *** --
		
		IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
			WHERE Storerkey = @cTaskStorer
				AND Configkey = 'GSILBLITF'
				AND SValue = '1')
			SET @cGSILBLITF = '1'
		ELSE
			SET @cGSILBLITF = '0'


		SET @cOutField03 	 = ''
		SET @cOutField04 	 = ''	

		-- GS1 Label validation start
		 IF @cGSILBLITF = '1'
		 BEGIN
			SET @cFilePath = ''

			SELECT @cFilePath = ISNULL(RTRIM(UserDefine20 ), '')
         FROM dbo.Facility WITH (NOLOCK) 
			WHERE Facility = @cFacility

			-- use 2 variables to store because facility.userdefine20 is NVARCHAR(30) while rdt v_string variable is NVARCHAR(20)
			SET @cFilePath1 = SUBSTRING(@cFilePath, 1, 20)
			SET @cFilePath2 = SUBSTRING(@cFilePath, 21, 20)

			IF ISNULL(@cFilePath1, '') = ''
			BEGIN
				SET @nErrNo = 69307
				SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69237 No FilePath
				EXEC rdt.rdtSetFocusField @nMobile, 2
				GOTO Step_5_Fail
			END

			SET @cGS1TemplatePath = ''

			SELECT @cGS1TemplatePath = NSQLDescrip
			FROM RDT.NSQLCONFIG WITH (NOLOCK)
			WHERE ConfigKey = 'GS1TemplatePath'

			IF ISNULL(@cGS1TemplatePath, '') = ''
			BEGIN
			  	SET @nErrNo = 69308

				SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69236 No Template
				EXEC rdt.rdtSetFocusField @nMobile, 2
				GOTO Step_5_Fail
			END
		END

      Insert into traceinfo (tracename , step1 , step2 , step3 ,step4 ,step5, col1 ) --, col2, col3,col4,col5)
      values ('label_process' , @cPrepackByBOM, @cTaskStorer, @cOrderKey , @cDropID, @cTaskdetailkey, 2354 ) 
 
		EXEC [RDT].[rdt_TM_OrderPicking_Label_Process] 
		@nMobile						=	@nMobile
		,@cFacility            	=	@cFacility            
		,@cTaskStorer          	=	@cTaskStorer          
		,@cDropID              	=	@cDropID              
		,@cOrderKey           	=	@cOrderKey           
		,@cPickSlipNo         	=	@cPickSlipNo         
		,@cFilePath1           	=	@cFilePath1           
		,@cFilePath2          	=	@cFilePath2          
		,@cLangCode           	=	@cLangCode           
		,@cTaskdetailkey       	=	@cTaskdetailkey       
		,@cPrepackByBOM			=	@cPrepackByBOM
		,@cUserName            	=	@cUserName            
		,@cTemplateID         	=	@cTemplateID         
		,@cPrinterID				=	@cPrinterID
		,@nErrNo              	=	@nErrNo						OUTPUT
		,@cErrMsg             	=	@cErrMsg						OUTPUT
		,@cGS1TemplatePath_Final	=	@cGS1TemplatePath_Final OUTPUT
		,@nTotalCtnsALL				=	@nTotalCtnsALL				OUTPUT
		,@c_LoosePick					=  @c_LoosePick			OUTPUT
	  
--	  IF @nErrNo <> 0
--	  BEGIN
--	      SET @nErrNo = @nErrNo
--		   SET @cErrMSG = @cErrMsg
--			EXEC rdt.rdtSetFocusField @nMobile, 2
--	      GOTO Step_5_Fail
--	  END
	  -- PrePare Next Screen Variable --
		  SET @cOutField01 	 = @cDropID
		  SET @cOutField02 	 = @nTotalCtnsALL

		  IF  @c_LoosePick = '1'
		  BEGIN
				 SET @cOutField03 = 'Loose pieces'
				 SET @cOutField04 = 'found'
		  END

--      SET @nPrevStep = 3

      -- Go to next screen
      SET @nScn = @nScn + 2
      SET @nStep = @nStep + 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- prepare next screen
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cFromLoc
      SET @cOutField03 = @cID
		SET @cOutField04 = ''

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

	

   Step_5_Fail:
   BEGIN
      SET @cFieldAttr09 = ''

      IF @cPUOM_Desc = ''
         SET @cFieldAttr09 = 'O'

      IF @cOutField08 = ''    -- If master uom qty got no value then disable the display
         SET @cFieldAttr10 = 'O' -- disable the display 

      IF @nPQTY <= 0    
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
Step 6. Scn = 2355. 
   OPTION     (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 --ENTER
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
      SET @cTemplateOption = @cInField01

      IF @cTemplateOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 69310
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_6_Fail
      END
 
      -- If option = 1, template id will be defaulted to 'Generic.btw'
      IF @cTemplateOption = '1'
      BEGIN
      SET @cTemplateID = 'Generic.btw'
        --SET @cGenTemplateID = 'Generic.btw' 
		
		-- *** Carton Label Printing (Start) *** --
		
		IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
			WHERE Storerkey = @cTaskStorer
				AND Configkey = 'GSILBLITF'
				AND SValue = '1')
			SET @cGSILBLITF = '1'
		ELSE
			SET @cGSILBLITF = '0'


		SET @cOutField03 	 = ''
		SET @cOutField04 	 = ''	

		-- GS1 Label validation start
		 IF @cGSILBLITF = '1'
		 BEGIN
			SET @cFilePath = ''

			SELECT @cFilePath = ISNULL(RTRIM(UserDefine20 ), '')
         FROM dbo.Facility WITH (NOLOCK) 
			WHERE Facility = @cFacility

			-- use 2 variables to store because facility.userdefine20 is NVARCHAR(30) while rdt v_string variable is NVARCHAR(20)
			SET @cFilePath1 = SUBSTRING(@cFilePath, 1, 20)
			SET @cFilePath2 = SUBSTRING(@cFilePath, 21, 20)

			IF ISNULL(@cFilePath1, '') = ''
			BEGIN
				SET @nErrNo = 69307
				SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69237 No FilePath
				EXEC rdt.rdtSetFocusField @nMobile, 2
				GOTO Step_5_Fail
			END

			SET @cGS1TemplatePath = ''

			SELECT @cGS1TemplatePath = NSQLDescrip
			FROM RDT.NSQLCONFIG WITH (NOLOCK)
			WHERE ConfigKey = 'GS1TemplatePath'

			IF ISNULL(@cGS1TemplatePath, '') = ''
			BEGIN
			  	SET @nErrNo = 69308

				SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69236 No Template
				EXEC rdt.rdtSetFocusField @nMobile, 2
				GOTO Step_5_Fail
			END
		END

      SELECT TOP 1 
		 --  @cBuyerPO = O.BuyerPO, 
		 --  @cTemplateID = O.DischargePlace, 
			@cOrderKey = O.OrderKey 
      FROM dbo.ORDERS O WITH (NOLOCK) 
      JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (O.OrderKey = PH.Orderkey)
      WHERE PH.PickHeaderKey = @cPickslipNo
		 AND   PH.ExternOrderKey = @cLoadkey
		 ORDER BY O.Priority, O.BuyerPO
		 
      Insert into traceinfo (tracename , step1 , step2 , step3 ,step4 ,step5 ,col1 ) -- , col2, col3,col4,col5)
      values ('label_process' , @cPrepackByBOM, @cTaskStorer, @cOrderKey , @cDropID, @cTaskdetailkey, 2355) 
		 
		EXEC [RDT].[rdt_TM_OrderPicking_Label_Process] 
		@nMobile						=	@nMobile
		,@cFacility            	=	@cFacility            
		,@cTaskStorer          	=	@cTaskStorer          
		,@cDropID              	=	@cDropID              
		,@cOrderKey           	=	@cOrderKey           
		,@cPickSlipNo         	=	@cPickSlipNo         
		,@cFilePath1           	=	@cFilePath1           
		,@cFilePath2          	=	@cFilePath2          
		,@cLangCode           	=	@cLangCode           
		,@cTaskdetailkey       	=	@cTaskdetailkey       
		,@cPrepackByBOM			=	@cPrepackByBOM
		,@cUserName            	=	@cUserName            
		,@cTemplateID         	=	@cTemplateID         
		,@cPrinterID				=	@cPrinterID
		,@nErrNo              	=	@nErrNo						OUTPUT
		,@cErrMsg             	=	@cErrMsg						OUTPUT
		,@cGS1TemplatePath_Final	=	@cGS1TemplatePath_Final OUTPUT
		,@nTotalCtnsALL				=	@nTotalCtnsALL				OUTPUT
		,@c_LoosePick					=  @c_LoosePick			OUTPUT
					
		  -- PrePare Next Screen Variable --
		  SET @cOutField01 	 = @cDropID
		  SET @cOutField02 	 = @nTotalCtnsALL
		
		  IF  @c_LoosePick = '1'
		  BEGIN
				 SET @cOutField03 = 'Loose pieces'
				 SET @cOutField04 = 'found'
		  END

	
        -- Go to Next screen
        SET @nScn = @nScn + 1
        SET @nStep = @nStep + 1  

      END


      -- If option = 2, prompt error and go back to screen 1
      IF @cTemplateOption = '2'
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '69311 Template ID'
         SET @cErrMsg2 = 'not setup'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         
         EXEC rdt.rdtSetFocusField @nMobile, 2

		  -- Prepare prev screen Variable	
		  SET @cOutField01 = ''
		  SET @cOutField02 = ''

         -- Go to prev screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4                
        -- GOTO Quit
      END
   END
   
--   IF @nInputKey = 0 -- ESC
--   BEGIN
--      -- Prepare prev screen var
--		-- Prepare prev screen Variable	
--		SET @cOutField01 = @cSuggID
--
--      EXEC rdt.rdtSetFocusField @nMobile, 4
--
--      -- Go to prev screen
--      SET @nScn = @nScn - 1
--      SET @nStep = @nStep - 1
--   END
--   GOTO QUIT
--
   Step_6_Fail:
   BEGIN
      SET @cTemplateOption = ''
  
      -- Reset this screen var
      --SET @cOutField01 = ''
   
   END
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 2356. 
   ORDER PICKING				OPK
   DROP ID           (field01)
	CARTON PRINTED NO (field02)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 OR @nInPutKey = 0 --ENTER / ESC
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


			EXEC rdt.rdtSetFocusField @nMobile, 1 

			SET @nScn = @nScn + 1
			SET @nStep = @nStep + 1

			SET @cOutField01 = ''
     
   END

   GOTO Quit

END
GOTO Quit

/********************************************************************************
Step 8. Scn = 2357. (Close Pallete)
   ORDER PICKING				OPK
   OPTION     (field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 --ENTER 
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
			SET @cPalleteOption = ISNULL(RTRIM(@cInField01),'')

			IF @cPalleteOption NOT IN ('1', '2')
			BEGIN
				SET @nErrNo = 69311
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
				GOTO Step_8_Fail
			END

			IF @cSHTPICKOption = '2' And @cPalleteOption <> '1'
			BEGIN
				SET @nErrNo = 69571
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pallet Must Close'
				SET @cOutField01 = ''
				GOTO Step_8_Fail

			END
			

			IF @cPalleteOption = '1'
			BEGIN

--				BEGIN TRAN
--				 -- Confirm PK task
--				UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
--					Status = '9',
--					EditDate = GETDATE(), 
--					EditWho = @cUserName
--				WHERE TaskDetailKey = @cTaskDetailKey
--
--				IF @@ERROR <> 0
--				BEGIN
--					SET @nErrNo = 69312
--					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDtl Fail'
--					ROLLBACK TRAN 
--					GOTO QUIT
--				END
--  			   ELSE
--				BEGIN
--					COMMIT TRAN 
--				END	

				DECLARE @nTranCount INT
				SET @nTranCount = @@TRANCOUNT				
				BEGIN TRAN
				SAVE TRAN ClosePallet
				
				-- Update DropID Status (Start) --
				UPDATE dbo.DROPID WITH (ROWLOCK)
				SET LABELPRINTED = 'Y' , STATUS = '5'
				WHERE DROPID = @cDropID
				AND Loadkey = @cLoadkey
				IF @@ERROR <> 0
				BEGIN
               SET @nErrNo = 69327
               SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD ID FAILED'
               GOTO RollbackTran
				END

				-- Retrieve ToLoc For NMV Task Creation --
				SET @cToLoc = ''
				EXEC [dbo].[isp_TM_OPK_LOC] 
				@nMobile,
				@cFromLoc,            
				@cTaskDetailKey,
				@cLoadKey,             
				@cID,						 
				@cToLOC   OUTPUT, 
				@cNMVTask OUTPUT          
				IF ISNULL(RTRIM(@cToLOC),'') = ''
				BEGIN
					SET @nErrNo = 69316
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToLOC NA'
					GOTO RollbackTran
				END
				
				-- Get Total QTY to Update for PendingMoveIN - No PendingMovein QTY if LocationCategory = HVCP
				SELECT @c_LocationCategory = LocationCategory  from dbo.Loc (NOLOCK)
				WHERE Loc = @cToLOC

				IF @c_LocationCategory <> 'HVCP'
				BEGIN
					SELECT @nActualPendingMoveIn = SUM (QTY) FROM dbo.TaskDetail (NOLOCK)
					WHERE ToID = @cDropID 
				END
				ELSE
				BEGIN
					SET @nActualPendingMoveIn = 0
				END	

				IF ISNULL(RTRIM(@cToLOC),'') <> '' AND ISNULL(RTRIM(@cNMVTask),'') = '0'
				BEGIN
					-- Get Key 
               SELECT @b_success = 1      

                     -- (SHONG01)
                     EXECUTE dbo.nspg_getkey       
                     'TaskDetailKey'      
                     , 10      
                     , @c_taskdetailkeyNMV OUTPUT      
                     , @b_success OUTPUT      
                     , @n_err OUTPUT      
                     , @c_errmsg OUTPUT      

                     IF NOT @b_success = 1      
                     BEGIN      
                        SET @nErrNo = 69317
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
                        GOTO RollbackTran
                     END   

					SELECT @cNMV_PAZone = ISNULL(RTRIM(LOC.PutawayZone), '') 
					FROM dbo.LOC LOC WITH (NOLOCK) 
					WHERE LOC = @cToLOC

					SELECT TOP 1 @cNMV_Areakey = ISNULL(RTRIM(AreaKey), '')
					FROM dbo.AreaDetail WITH (NOLOCK) 
					WHERE PutawayZone = @cNMV_PAZone


					SELECT TOP 1 @cNMVToLoc = Loc From dbo.LoadPlanLaneDetail (NOLOCK)
					WHERE Loadkey = @cLoadkey
					AND LocationCategory = 'HVCP'
					ORDER BY Loc
			
					-- Generate NMV Task with Status W --
					EXEC [rdt].[rdt_TMTask] 
						 @c_taskdetailkeyNMV
						, 'NMV'  
						,''
						,@cTaskStorer   
						, ''
						, ''
						,@cToLoc
						,@cDropID
						,@cNMVToLoc
						,@cDropID
						,''
						,0
						,@nActualPendingMoveIn
						,@cLoadkey
						,'RDT'
						,'W'
						,'A'
						,''
						,@b_Success OUTPUT      
						,@c_errmsg OUTPUT      
						,@cNMV_Areakey
	                  
					If @b_success = 0
					BEGIN
   					SET @nErrNo = 69318
   					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
   					GOTO RollbackTran
					END
						 
               UPDATE dbo.TaskDetail WITH (ROWLOCK)
               SET RefTaskKey =  @cTaskDetailKey, TrafficCop = NULL
               WHERE TaskDetailkey = @c_taskdetailkeyNMV
               IF @@ERROR <> 0
               BEGIN
               	  SET @nErrNo = 69575
               	  SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'
               	  GOTO RollbackTran
               END
				END

				SELECT @cLogicalLoc = LogicalLocation, @c_LocationCategory = LocationCategory  from dbo.Loc (NOLOCK)
				WHERE Loc = @cToLoc

				IF ISNULL(@cLogicalLoc,'')  = ''
					SET @cLogicalLoc = @cToLoc

				-- Update OPK ToLoc , ToID
				UPDATE dbo.TaskDetail WITH (ROWLOCK)
					SET ToLoc = @cToLoc
					,ToID =  @cDropID
					,LogicalToLoc = @cLogicalLoc
					,TrafficCop = NULL
				WHERE Taskdetailkey = @cTaskDetailKey
					AND Loadkey = @cLoadkey
					AND Storerkey = @cTaskStorer
					AND TaskType = 'OPK'
				IF @@ERROR <> 0
				BEGIN
					SET @nErrNo = 69343
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'
					GOTO RollbackTran
				END
				
				-- Update ToLoc , LogicalLoc for all same @cToID = @cDropID
				UPDATE dbo.TaskDetail WITH (ROWLOCK)
					SET ToLoc = @cToLoc
					,LogicalToLoc = @cLogicalLoc
					,TrafficCop = NULL
				WHERE ToID = @cDropID
				AND TaskType = 'OPK'
				IF @@ERROR <> 0
				BEGIN
					SET @nErrNo = 69567
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Task Fail'
					GOTO RollbackTran
				END

				SELECT @cLLISKU = SKU FROM dbo.PickDetail (NOLOCK)
				WHERE ID = @cSuggID
						AND Storerkey =  @cTaskStorer
						AND Orderkey = @cOrderkey

				SELECT @cLot = Lot FROM dbo.LotxLocxID (NOLOCK)
				WHERE SKU = @cLLISKU
				AND Loc = @cFromLoc
				AND ID = @cSuggID
				AND Storerkey = @cTaskStorer 

				IF EXISTS ( SELECT 1 FROM dbo.LotXLocXID (NOLOCK)
								WHERE SKU = @cLLISKU
								AND Loc = @cToLoc
								AND ID = @cSuggID
								AND Storerkey = @cTaskStorer )
				BEGIN
					UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET 
						PendingMoveIN = PendingMoveIN + @nActualPendingMoveIn
					WHERE StorerKey = @cTaskStorer
						AND SKU = @cLLISKU
		--          AND LOT = @cLOT
						AND LOC = @cToLOC
						AND ID = @cSuggID
					IF @@ERROR <> 0
					BEGIN
						SET @nErrNo = 69326
						SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPenMVInFail'
						GOTO RollbackTran
					END
						
				END
				ELSE
				BEGIN
					INSERT INTO dbo.LotXLocXID (
						Lot
						,Loc
						,Id
						,StorerKey
						,Sku
						,Qty
						,QtyAllocated
						,QtyPicked
						,QtyExpected
						,QtyPickInProcess
						,PendingMoveIN )
					VALUES (
						@cLot
					  ,@cToLOC
					  ,@cSuggID
					  ,@cTaskStorer
					  ,@cLLISKU
					  ,0
					  ,0
					  ,0
					  ,0		 	
					  ,0	
					  ,@nActualPendingMoveIn	
					)
   				IF @@ERROR <> 0
   				BEGIN
   					SET @nErrNo = 69328
   					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPenMVInFail'
   					GOTO RollbackTran
   				END
				END

				-- Update DropID.DropLoc --
				UPDATE dbo.DROPID WITH (ROWLOCK)
				SET DropLoc = @cToLoc
				WHERE DropID = @cDropID
				IF @@ERROR <> 0
				BEGIN
					SET @nErrNo = 69331
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropLoc Fail'
					GOTO RollbackTran
				END

				/***************************************************************/
			   -- GEN GS1 to WCS (START) --
				SET  @cWCSFilePath1 = ''
				SELECT @cWCSFilePath1 = UserDefine18 FROM dbo.FACILITY WITH (NOLOCK)
				WHERE FACILITY = @cFacility 

				EXEC rdt.rdt_Print_GS1_Carton_Label_GS1Info2WCS
					  @nMobile,
					  @cFacility,
					  @cTaskStorer,
					  @cDropID,
					  '',
					  @cLoadKey,
					  @cWCSFilePath1,
					  @cPrepackByBOM,
					  @cUserName,   
					  --@cTemplateID,
					  @cPrinterID,
					  @cLangCode,
					  @nCaseCnt, 
					  @nErrNo        OUTPUT, 
					  @cOutField01   OUTPUT,  
					  '1' -- Set Loc Filter to 1 to Remove LocationCategory Filter 
            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO RollbackTran
            END

            -- Commit until the level we started
            WHILE @@TRANCOUNT > @nTranCount  
               COMMIT TRAN
            
				-- Prepare Next Scn Variable --
				SET @cSHTPICKOption = ''
				SET @cOutField01 = @cDropID
				SET @cOutField02 = @cFromLoc
				SET @cOutField03 = @cSuggID
				SET @cOutField04 = @cToLOC
				SET @cOutField05 = ''
				EXEC rdt.rdtSetFocusField @nMobile, 1 				
	        
				SET @nScn = @nScn + 1
				SET @nStep = @nStep + 1
				
				GOTO Quit

         RollBackTran:
            ROLLBACK TRAN ClosePallet
            WHILE @@TRANCOUNT > @nTranCount  -- Commit until the level we started
               COMMIT TRAN
			END

			IF @cPalleteOption = '2'
			BEGIN
				IF EXISTS (SELECT 1 FROM dbo.TASKDETAIL (NOLOCK) WHERE TaskDetailKey <> @cTaskDetailKey AND Status <> '9' AND TaskType = 'OPK' AND Loadkey = @cLoadkey)
				BEGIN
					-- Confirm OPK task
					UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
						Status = '9',
						EditDate = GETDATE(), 
						EditWho = @cUserName
					WHERE TaskDetailKey = @cTaskDetailKey
					IF @@ERROR <> 0
					BEGIN
						SET @nErrNo = 69313
						SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDtl Fail'
						GOTO Quit
					END	
				END
				ELSE
				BEGIN
					SET @nErrNo = 69574
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PLT Must Close'
					GOTO Step_8_Fail  
				END
	
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
				,  @c_lasttasktype  = 'OPK'
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
					-- When No Task Prompt Error , Must Close Pallete --
					SET @nErrNo = 69566
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No More Task'
					GOTO Step_8_Fail  
				END     

				IF ISNULL(@cErrMsg, '') <> ''  
				BEGIN
					SET @cErrMsg = @cErrMsg
					GOTO Step_8_Fail
				END     

				IF ISNULL(@cNextTaskdetailkey, '') <> ''
					SET @cTaskdetailkey = @cNextTaskdetailkey
		    
				--SET @nToFunc = 1775
				SET @nToScn = 2352
		
				SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
				FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
				WHERE TaskType = RTRIM(@cTTMTasktype)

				IF @nToFunc = 0
				BEGIN
					SET @nErrNo = 69336
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskFncErr
					GOTO Step_8_Fail  
				END

				-- Prepare Next Scn Variable 
				-- GET FromLoc from Next Task to Display --
				SET @cOutField01 = @cDropID
				SET @cOutField03 = ''

				SELECT @cOutField02 = FromLoc FROM dbo.TaskDetail (NOLOCK)
				WHERE TaskDetailkey= @cTaskdetailkey

				SET @nFunc = @nToFunc
				SET @nScn = @nToScn
				SET @nStep = 3

				SET @nPrevStep = 0
		   END
         
         GOTO Quit
   END

   Step_8_Fail:
END
GOTO Quit


/********************************************************************************
Step 9. Scn = 2356. 
   ORDER PICKING				OPK
   DROPID    (Field01, output)
   FROM LOC  (Field02, output)
	PALLET ID (Field03, output)
	TOLOC     (Field04, input)
	TOLOC     (Field05, input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 --OR @nInPutKey = 0 --ENTER / ESC
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


			SET @cINToLoc = ISNULL(RTRIM(@cInField05),'')
			
			

			IF @cINToLoc = ''
			BEGIN
				EXEC rdt.rdtSetFocusField @nMobile, 5 	
				SET @nErrNo = 69329
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'To Loc Req'
				GOTO QUIT
			END

			IF @cINToLoc <> @cToLoc
			BEGIN
			
				EXEC rdt.rdtSetFocusField @nMobile, 5 	
				SET @nErrNo = 69330
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid ToLoc'
				GOTO QUIT
			END

			

			-- Release NMV Task --
         --DECLARE @cNMV_Areakey NVARCHAR(10), @cNMV_PAZone NVARCHAR(10)

         SELECT @cNMV_PAZone = ISNULL(RTRIM(LOC.PutawayZone), '')
         FROM dbo.TaskDetail TD WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.Loc = TD.FromLOC)
         WHERE TD.TaskDetailkey = @c_taskdetailkeyNMV
            AND TD.TaskType = 'NMV'
            AND TD.Status = 'W' 

         SELECT TOP 1 @cNMV_Areakey = ISNULL(RTRIM(AreaKey), '')
         FROM dbo.AreaDetail WITH (NOLOCK) 
         WHERE PutawayZone = @cNMV_PAZone


			BEGIN TRAN
			UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
            Status = '0', 
            Trafficcop = NULL, 
            EditDate = GETDATE(), 
            EditWho = @cUserName,
            Areakey = ISNULL(RTRIM(@cNMV_Areakey), '') 
         WHERE TaskDetailkey = @c_taskdetailkeyNMV
            AND TaskType = 'NMV'
            AND Status = 'W' 

		
			IF @@ERROR <> 0
			BEGIN
				SET @nErrNo = 69332
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd NMV fail'
				ROLLBACK TRAN 
				GOTO QUIT
			END
		   ELSE
			BEGIN
				 COMMIT TRAN 
			END	

			IF EXISTS (SELECT 1 FROM dbo.TASKDETAIL (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND Status <> '9' )
			BEGIN
				BEGIN TRAN
				UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
					Status = '9', 
					Trafficcop = NULL, 
					EditDate = GETDATE(), 
					EditWho = @cUserName,
					Areakey = ISNULL(RTRIM(@cNMV_Areakey), '') 
				WHERE TaskDetailkey = @cTaskDetailKey
					AND TaskType = 'OPK'
					AND Status = '3' 

			
				IF @@ERROR <> 0
				BEGIN
					SET @nErrNo = 69337
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OPK fail'
					ROLLBACK TRAN 
					GOTO QUIT
				END
				ELSE
				BEGIN
					 COMMIT TRAN 
				END	
			END
			
			-- Update TaskManagerUser with current LoadKey, Loc
			BEGIN TRAN
			UPDATE dbo.TaskManagerUser WITH (ROWLOCK) SET 
				LastLoadKey = @cLoadKey,
				LastDropID = @cDropID,
				LastLoc = @cToLOC, -- VNA
				EditDate = GETDATE(), 
				EditWho = @cUserName,
				TrafficCop = NULL
			WHERE UserKey = @cUserName

			IF @@ERROR <> 0
			BEGIN
				SET @nErrNo = 69338
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTMUser Fail'
				ROLLBACK TRAN 
				GOTO QUIT
			END
			ELSE
			BEGIN
				 COMMIT TRAN 
			END	

			SET @nScn = @nScn + 1
			SET @nStep = @nStep + 1
     
   END
   GOTO Quit

--	IF @nInputKey = 0 
--   BEGIN	
--		SET @nScn = @nScn - 1
--		SET @nStep = @nStep - 1
--	END



END
GOTO Quit



/********************************************************************************
Step 10. screen = 2359
   Picking successfull Message
********************************************************************************/
Step_10:
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
      ,  @c_lasttasktype  = 'OPK'
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
          -- EventLog - Sign In Function  
          EXEC RDT.rdt_STD_EventLog
             @cActionType = '9', -- Sign out function
             @cUserID     = @cUserName,
             @nMobileNo   = @nMobile,
             @nFunctionID = @nFunc,
             @cFacility   = @cFacility,
             @cStorerkey  = @cTaskStorer,
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

         SET @nPrevStep = 0   

         GOTO QUIT
    END     

      IF ISNULL(@cErrMsg, '') <> ''  
      BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_10_Fail
      END     

      IF ISNULL(@cNextTaskdetailkey, '') <> ''
         SET @cTaskdetailkey = @cNextTaskdetailkey

      SET @nToFunc = 0
      SET @nToScn = 0

      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = RTRIM(@cTTMTasktype)

      IF @nFunc = 0
      BEGIN
         SET @nErrNo = 69319
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskFncErr
       GOTO Step_10_Fail  
      END

      SELECT TOP 1 @nToScn = Scn 
      FROM RDT.RDTScn WITH (NOLOCK)
      WHERE Func = @nToFunc
      ORDER BY Scn

      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 69320
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Step_10_Fail  
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
         @cStorerkey  = @cTaskStorer,
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
      @cStorerkey  = @cTaskStorer,
      @nStep       = @nStep

     -- Go back to Task Manager Main Screen
     SET @nFunc = 1756
     SET @nScn = 2100
     SET @nStep = 1

     SET @cAreaKey = ''
     SET @nPrevStep = 0    

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

   Step_10_Fail:
END
GOTO QUIT


/********************************************************************************
Step 11. screen = 2360 -- Short Pick
   OPTION (Field06, input)
********************************************************************************/
Step_11:
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

		SET @cSHTPICKOption = ''

		SET @cShortPickOption = ISNULL(RTRIM(@cInField06),'')

		SET @cSHTPICKOption = @cShortPickOption

		IF @cShortPickOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 69321
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'

         GOTO Step_11_Fail
      END


		IF @cShortPickOption = '1'
		BEGIN
  	     
      
		  SET @nFromStep = @nStep

		  IF @nActQty > 0 
		  BEGIN
			-- Create TaskDetail for Remaining QTY (Start) --
			
--         EXECUTE dbo.nspg_getkey       
--         'TaskDetailKey'      
--         , 10      
--         , @c_taskdetailkey2 OUTPUT      
--         , @b_success OUTPUT      
--         , @n_err OUTPUT      
--         , @c_errmsg OUTPUT      
--
--         IF NOT @b_success = 1      
--         BEGIN      
--            SET @nErrNo = 69568
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
--            GOTO Quit
--         END   
--
--
--			EXEC [rdt].[rdt_TMTask] 
--                   @c_taskdetailkey2
--                  , 'OPK'  
--                  ,''
--                  ,@cTaskStorer   
--                  , ''
--                  , ''
--                  ,@cFromLOC
--                  ,@cID
--                  ,''
--                  ,''
--                  ,''
--                  ,0
--                  ,@nRemainQTY
--                  ,@cLoadkey
--                  ,'RDT'
--                  ,'0'
--                  ,'A'
--                  ,''
--						,@cAreakey
--						,@b_Success OUTPUT      
--                  ,@c_errmsg OUTPUT      
--                  
--                If @b_success = 0
--                BEGIN
--                  SET @nErrNo = 69335
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
--                  GOTO Quit
--                END
			
				EXECUTE RDT.rdt_TM_OrderPicking_ConfirmTask 
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
            '',
            @cID,
            @cDropID,
            @nActQty,  
            '4',
            @cLangCode,
				@c_taskdetailkey2,
            @nErrNo OUTPUT,
            @cErrMsg OUTPUT,
            @cAreakey 
				

			-- Create TaskDetail for Remaining QTY (End) --
			
			BEGIN TRAN
			UPDATE dbo.TASKDETAIL WITH (ROWLOCK)
				SET QTY = @nActQty , ToID = @cDropID,  TrafficCop = NULL
			WHERE TASKDETAILKEY = @cTaskDetailKey

			IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69334
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PKTask fail'
            ROLLBACK TRAN
				GOTO QUIT
         END			
			ELSE
			BEGIN
				COMMIT TRAN
			END
			
		  END


		  SET @cOutField01 = ''         
		  SET @nScn = 2109
        SET @nStep = @nStep + 1
        
       

		END



		IF @cShortPickOption = '2'
		BEGIN


			

			EXECUTE dbo.nspg_getkey       
         'TaskDetailKey'      
         , 10      
         , @c_taskdetailkey2 OUTPUT      
         , @b_success OUTPUT      
         , @n_err OUTPUT      
         , @c_errmsg OUTPUT      

         IF NOT @b_success = 1      
         BEGIN      
            SET @nErrNo = 69569
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
            GOTO Quit
         END   

			-- Create TaskDetail for Remaining QTY (Start) --
			EXEC [rdt].[rdt_TMTask] 
                   @c_taskdetailkey2
                  , 'OPK'  
                  ,''
                  ,@cTaskStorer   
                  , ''
                  , ''
                  ,@cFromLOC
                  ,@cID
                  ,''
                  ,''
                  ,''
                  ,0
                  ,@nRemainQTY
                  ,@cLoadkey
                  ,'RDT'
                  ,'0'
                  ,'A'
                  ,''
						,@b_Success OUTPUT      
                  ,@c_errmsg OUTPUT      
                  ,@cAreakey
                  
                If @b_success = 0
                BEGIN
                  SET @nErrNo = 69322
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
                  GOTO Quit
                END
			
			-- Create TaskDetail for Remaining QTY (End) --

			EXECUTE RDT.rdt_TM_OrderPicking_ConfirmTask 
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
            '',
            @cID,
            @cDropID,
            @nActQty,  
            '5',
            @cLangCode,
				@c_taskdetailkey2,
            @nErrNo OUTPUT,
            @cErrMsg OUTPUT,
            @cAreakey,
				@cShortPickOption

			
			BEGIN TRAN
			UPDATE dbo.TASKDETAIL WITH (ROWLOCK)
				SET QTY = @nActQty 
				, ToID = @cDropID
			WHERE TASKDETAILKEY = @cTaskDetailKey

			IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69323
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PKTask fail'
            ROLLBACK TRAN
				GOTO QUIT
         END			
			ELSE
			BEGIN
				COMMIT TRAN
			END
			

			
			-- Update TaskManagerUser with current LoadKey, Loc
				BEGIN TRAN
				UPDATE dbo.TaskManagerUser WITH (ROWLOCK) SET 
					LastLoadKey = @cLoadKey,
					LastDropID = @cID,
					LastLoc = @cFromLOC, -- VNA
					EditDate = GETDATE(), 
					EditWho = @cUserName,
					TrafficCop = NULL
				WHERE UserKey = @cUserName

				IF @@ERROR <> 0
				BEGIN
					SET @nErrNo = 69570
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTMUser Fail'
					ROLLBACK TRAN 
					GOTO QUIT
				END
				ELSE
				BEGIN
					 COMMIT TRAN 
				END	


			 --*** Template Validation (Start) ***--
				SET @cTemplateID = ''

				SELECT TOP 1 
					@cBuyerPO = O.BuyerPO, 
					@cTemplateID = O.DischargePlace, 
					@cOrderKey = O.OrderKey 
				FROM dbo.ORDERS O WITH (NOLOCK) 
				JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (O.OrderKey = PH.Orderkey)
				WHERE PH.PickHeaderKey = @cPickslipNo
				 AND   PH.ExternOrderKey = @cLoadkey
				 ORDER BY O.Priority, O.BuyerPO

					 --SET @cTemplateID = ''

--					 IF ISNULL(@cTemplateID , '') = '' 
--					 BEGIN
--						  SET @cTemplateID = ISNULL(RTRIM(@cDischargePlace), '')
--					 END

  					 IF ISNULL(@cTemplateID, '') = '' 
					 BEGIN
							-- Prepare next screen var
							SET @cOutField01 = ''
							SET @cGenTemplateID = ''  
				         
							-- Go to next screen
							SET @nScn = @nScn - 5
							SET @nStep = @nStep - 5  

							GOTO QUIT
					 END
 				--*** Template Validation (End) ***--

	    -- *** Carton Label Printing (Start) *** --
		
		IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
			WHERE Storerkey = @cTaskStorer
				AND Configkey = 'GSILBLITF'
				AND SValue = '1')
			SET @cGSILBLITF = '1'
		ELSE
			SET @cGSILBLITF = '0'


		SET @cOutField03 	 = ''
		SET @cOutField04 	 = ''	

		-- GS1 Label validation start
		 IF @cGSILBLITF = '1'
		 BEGIN
			SET @cFilePath = ''

			SELECT @cFilePath = ISNULL(RTRIM(UserDefine20 ), '')
         FROM dbo.Facility WITH (NOLOCK) 
			WHERE Facility = @cFacility

			-- use 2 variables to store because facility.userdefine20 is NVARCHAR(30) while rdt v_string variable is NVARCHAR(20)
			SET @cFilePath1 = SUBSTRING(@cFilePath, 1, 20)
			SET @cFilePath2 = SUBSTRING(@cFilePath, 21, 20)

			IF ISNULL(@cFilePath1, '') = ''
			BEGIN
				SET @nErrNo = 69307
				SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69237 No FilePath
				EXEC rdt.rdtSetFocusField @nMobile, 2
				GOTO Step_5_Fail
			END

			SET @cGS1TemplatePath = ''

			SELECT @cGS1TemplatePath = NSQLDescrip
			FROM RDT.NSQLCONFIG WITH (NOLOCK)
			WHERE ConfigKey = 'GS1TemplatePath'

			IF ISNULL(@cGS1TemplatePath, '') = ''
			BEGIN
			  	SET @nErrNo = 69308

				SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69236 No Template
				EXEC rdt.rdtSetFocusField @nMobile, 2
				GOTO Step_5_Fail
			END
		END
		
		

		Insert into traceinfo (tracename , step1 , step2 , step3 ,step4 ,step5, col1 ) -- , col2, col3,col4,col5)
      values ('label_process' , @cPrepackByBOM, @cTaskStorer, @cOrderKey , @cDropID, @cTaskdetailkey, 2360) 
      
		EXEC [RDT].[rdt_TM_OrderPicking_Label_Process] 
		@nMobile						=	@nMobile
		,@cFacility            	=	@cFacility            
		,@cTaskStorer          	=	@cTaskStorer          
		,@cDropID              	=	@cDropID              
		,@cOrderKey           	=	@cOrderKey           
		,@cPickSlipNo         	=	@cPickSlipNo         
		,@cFilePath1           	=	@cFilePath1           
		,@cFilePath2          	=	@cFilePath2          
		,@cLangCode           	=	@cLangCode           
		,@cTaskdetailkey       	=	@cTaskdetailkey       
		,@cPrepackByBOM			=	@cPrepackByBOM
		,@cUserName            	=	@cUserName            
		,@cTemplateID         	=	@cTemplateID         
		,@cPrinterID				=	@cPrinterID
		,@nErrNo              	=	@nErrNo						OUTPUT
		,@cErrMsg             	=	@cErrMsg						OUTPUT
		,@cGS1TemplatePath_Final	=	@cGS1TemplatePath_Final OUTPUT
		,@nTotalCtnsALL				=	@nTotalCtnsALL				OUTPUT
		,@c_LoosePick					=  @c_LoosePick			OUTPUT
		  
		  -- PrePare Next Screen Variable --
		  SET @cOutField01 	 = @cDropID
		  SET @cOutField02 	 = @nTotalCtnsALL
		  
		  IF  @c_LoosePick = '1'
		  BEGIN
				 SET @cOutField03 = 'Loose pieces'
				 SET @cOutField04 = 'found'
		  END

		  SET @nScn = @nScn - 4
        SET @nStep = @nStep - 4

		END
     

      

      --SET @nPrevStep = 0
   END

	IF @nInputKey = 0 --ESC
	BEGIN
		     

         -- If not found parent sku then this is not prepack bom
         IF ISNULL(@cAltSKU, '') = ''
         BEGIN
            SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0),
                   @cSKU = PD.SKU 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            WHERE PD.StorerKey = @cTaskStorer
               AND PD.LOC = @cFromLoc
               AND PD.ID = @cID
               AND PD.Status = '0'
               AND O.LoadKey = @cLoadKey
            GROUP BY PD.SKU 
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
                      @cSKU = PD.SKU 
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
               WHERE PD.StorerKey = @cTaskStorer
                  AND PD.LOC = @cFromLoc
                  AND PD.ID = @cID
--                  AND PD.SKU = @cSKU
                  AND PD.Status = '0'
                  AND O.LoadKey = @cLoadKey
               GROUP BY PD.SKU 

               SET @cAltSKU = ''
            END
         END

      

      -- IF WMS Config 'PrePackByBOM' turned on then show Parent SKU & Descr
      -- ELSE show current taskdetail SKU & Descr
      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'  
      --rdt.RDTGetConfig( @nFunc, 'PrePackByBOM', @cTaskStorer) = '1'
      BEGIN
         SET @cSKU = @cAltSKU
         SET @cPUOM = '2' --Case

         SET @nSUMBOM_Qty = 0
         SELECT @nSUMBOM_Qty = ISNULL(SUM(Qty), 0) FROM dbo.BillOfMaterial WITH (NOLOCK) WHERE SKU = @cSKU And Storerkey = @cTaskStorer
      END

      SELECT @cDescr = '', @cMUOM_Desc = '', @cPUOM_Desc = '', @nPUOM_Div = 0



      IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1' 
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
         IF ISNULL(@cAltSKU, '') <> '' AND @cPrepackByBOM = '1'   
            SET @cOutField11 = '1:' + CAST( @nSUMBOM_Qty AS NVARCHAR( 6))
         ELSE
            SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END
      SET @cOutField06 = @cMUOM_Desc
      IF @nPQTY <= 0    
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

      IF @nPQTY > 0     
         EXEC rdt.rdtSetFocusField @nMobile, 09
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 10

      SET @cOutField10 = '' -- ActMQTY

		-- go to previous screen
      SET @nScn = @nScn - 6
      SET @nStep = @nStep - 6	

	END
   GOTO Quit

   Step_11_Fail:
END
GOTO QUIT


/********************************************************************************
Step 12. screen = 2109
     REASON CODE  (Field01, input)
********************************************************************************/
Step_12:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReasonCode = @cInField01

      IF @cReasonCode = ''
      BEGIN
        SET @nErrNo = 69325
        SET @cErrMsg = rdt.rdtgetmessage( 69325, @cLangCode, 'DSP') --Reason Req
        GOTO Step_12_Fail  
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
           ,  @n_qty           = @nActQty--0 
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
        GOTO Step_12_Fail
      END 

      SET @cContinueProcess = ''
      SELECT @cContinueProcess = ContinueProcessing FROM dbo.TASKMANAGERREASON WITH (NOLOCK)
      WHERE TaskManagerReasonKey = @cReasonCode

      IF ISNULL(@cContinueProcess, '') = '1' AND @nActQty > 0 
      BEGIN

			 --*** Template Validation (Start) ***--
			SET @cTemplateID = ''
			
			Insert into traceinfo (tracename , step1 , step2 , step3 ,step4 ,step5, col1 , col2)--, col3,col4,col5)
         values ('label_process' , @cPrepackByBOM, @cTaskStorer, @cOrderKey , @cDropID, @cTaskdetailkey, 2109 , 'b4') 

         -- 
			SELECT TOP 1 
				@cBuyerPO = O.BuyerPO, 
				@cTemplateID = O.DischargePlace, 
				@cOrderKey = O.OrderKey 
			FROM dbo.ORDERS O WITH (NOLOCK) 
			JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (O.OrderKey = PH.Orderkey)
			WHERE PH.PickHeaderKey = @cPickslipNo
			 AND   PH.ExternOrderKey = @cLoadkey
			 ORDER BY O.Priority, O.BuyerPO

          

				 --SET @cTemplateID = ''

--				 IF ISNULL(@cTemplateID , '') = '' 
--				 BEGIN
--					  SET @cTemplateID = ISNULL(RTRIM(@cDischargePlace), '')
--				 END

  				 IF ISNULL(@cTemplateID, '') = '' 
				 BEGIN
						-- Prepare next screen var
						SET @cOutField01 = ''
						SET @cGenTemplateID = ''  
			         
						-- Go to next screen
						SET @nScn =  2355 
						SET @nStep = 6

						GOTO QUIT
				 END
 			--*** Template Validation (End) ***--

		-- *** Carton Label Printing (Start) *** --
		
		IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
			WHERE Storerkey = @cTaskStorer
				AND Configkey = 'GSILBLITF'
				AND SValue = '1')
			SET @cGSILBLITF = '1'
		ELSE
			SET @cGSILBLITF = '0'


		SET @cOutField03 	 = ''
		SET @cOutField04 	 = ''	

		-- GS1 Label validation start
		 IF @cGSILBLITF = '1'
		 BEGIN
			SET @cFilePath = ''

			SELECT @cFilePath = ISNULL(RTRIM(UserDefine20 ), '')
         FROM dbo.Facility WITH (NOLOCK) 
			WHERE Facility = @cFacility

			-- use 2 variables to store because facility.userdefine20 is NVARCHAR(30) while rdt v_string variable is NVARCHAR(20)
			SET @cFilePath1 = SUBSTRING(@cFilePath, 1, 20)
			SET @cFilePath2 = SUBSTRING(@cFilePath, 21, 20)

			IF ISNULL(@cFilePath1, '') = ''
			BEGIN
				SET @nErrNo = 69307
				SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69237 No FilePath
				EXEC rdt.rdtSetFocusField @nMobile, 2
				GOTO Step_5_Fail
			END

			SET @cGS1TemplatePath = ''

			SELECT @cGS1TemplatePath = NSQLDescrip
			FROM RDT.NSQLCONFIG WITH (NOLOCK)
			WHERE ConfigKey = 'GS1TemplatePath'

			IF ISNULL(@cGS1TemplatePath, '') = ''
			BEGIN
			  	SET @nErrNo = 69308

				SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --69236 No Template
				EXEC rdt.rdtSetFocusField @nMobile, 2
				GOTO Step_5_Fail
			END
		END

		
      Insert into traceinfo (tracename , step1 , step2 , step3 ,step4 ,step5, col1 ) -- , col2, col3,col4,col5)
      values ('label_process' , @cPrepackByBOM, @cTaskStorer, @cOrderKey , @cDropID, @cTaskdetailkey, 2109) 

		EXEC [RDT].[rdt_TM_OrderPicking_Label_Process] 
		@nMobile						=	@nMobile
		,@cFacility            	=	@cFacility            
		,@cTaskStorer          	=	@cTaskStorer          
		,@cDropID              	=	@cDropID  
		,@cOrderKey           	=	@cOrderKey           
		,@cPickSlipNo         	=	@cPickSlipNo         
		,@cFilePath1           	=	@cFilePath1           
		,@cFilePath2          	=	@cFilePath2          
		,@cLangCode           	=	@cLangCode           
		,@cTaskdetailkey       	=	@cTaskdetailkey       
		,@cPrepackByBOM			=	@cPrepackByBOM
		,@cUserName            	=	@cUserName            
		,@cTemplateID         	=	@cTemplateID         
		,@cPrinterID				=	@cPrinterID
		,@nErrNo              	=	@nErrNo						OUTPUT
		,@cErrMsg             	=	@cErrMsg						OUTPUT
		,@cGS1TemplatePath_Final	=	@cGS1TemplatePath_Final OUTPUT
		,@nTotalCtnsALL				=	@nTotalCtnsALL				OUTPUT
		,@c_LoosePick					=  @c_LoosePick			OUTPUT
	  
	  -- PrePare Next Screen Variable --
		  SET @cOutField01 	 = @cDropID
		  SET @cOutField02 	 = @nTotalCtnsALL

		  IF  @c_LoosePick = '1'
		  BEGIN
				 SET @cOutField03 = 'Loose pieces'
				 SET @cOutField04 = 'found'
		  END


         SET @nScn = 2356
         SET @nStep = 7
         GOTO Quit

      END
      ELSE IF ISNULL(@cContinueProcess, '') = '1' AND @nActQty = 0 
      BEGIN
         
         SET @cErrMsg = ''
         EXECUTE RDT.rdt_TM_OrderPicking_ConfirmTask 
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
            '',
            @cID,
            @cDropID,
            @nActQty,  
            '4', 
            @cLangCode,
				@c_taskdetailkey2,
            @nErrNo OUTPUT,
            @cErrMsg OUTPUT,
            @cAreakey 

         IF @nErrNo <> 0
         BEGIN
            GOTO Step_12_Fail
         END

			-- Update TaskManagerUser with current LoadKey, Loc
			BEGIN TRAN
			UPDATE dbo.TaskManagerUser WITH (ROWLOCK) SET 
				LastLoadKey = @cLoadKey,
				LastDropID = @cID,
				LastLoc = @cFromLOC, -- VNA
				EditDate = GETDATE(), 
				EditWho = @cUserName,
				TrafficCop = NULL
			WHERE UserKey = @cUserName

			IF @@ERROR <> 0
			BEGIN
				SET @nErrNo = 69572
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTMUser Fail'
				ROLLBACK TRAN 
				GOTO QUIT
			END
			ELSE
			BEGIN
				 COMMIT TRAN 
			END	

			-- Update TaskDetail Status = '9'
			IF EXISTS (SELECT 1 FROM dbo.TASKDETAIL (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND Status <> '9' )
			BEGIN
				BEGIN TRAN
				 -- Confirm OPK task
				UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
					Status = '9',
					ToID = @cDropID,
					EditDate = GETDATE(), 
					EditWho = @cUserName
				WHERE TaskDetailKey = @cTaskDetailKey
				

				IF @@ERROR <> 0
				BEGIN
					SET @nErrNo = 69573
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDtl Fail'
					ROLLBACK TRAN 
					GOTO QUIT
				END
  			   ELSE
				BEGIN
					 COMMIT TRAN 
				END	
			END

			


         SET @nScn = 2352
         SET @nStep = 3 -- (ChewKP01)
         
         
         --GOTO Quit


      END


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
      ,  @c_lasttasktype  = 'OPK'
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
          -- EventLog - Sign In Function  
          EXEC RDT.rdt_STD_EventLog
             @cActionType = '9', -- Sign out function
             @cUserID     = @cUserName,
             @nMobileNo   = @nMobile,
             @nFunctionID = @nFunc,
             @cFacility   = @cFacility,
             @cStorerkey  = @cTaskStorer,
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
         GOTO Step_12_Fail
      END     

		-- Prepare Screen Variable --
		IF @nScn = 2352
		BEGIN
			SELECT @cSuggFromLoc = FROMLOC
			FROM dbo.TASKDETAIL (NOLOCK)
			WHERE TASKDETAILKEY = @cNextTaskdetailkey
		
			SET @cOutField01 = @cDropID
			SET @cOutField02 = @cSuggFromLoc
			SET @cOutField03 = ''
		
		END

      

      IF ISNULL(@cNextTaskdetailkey, '') <> ''
         SET @cTaskdetailkey = @cNextTaskdetailkey


      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerkey  = @cTaskStorer,
         @nStep       = @nStep


   END
	

   IF @nInputKey = 0 -- ESC
   BEGIN
		
      -- (Vicky07) - Start
     --SET @cOutField01 = @cSuggFromLoc
     --SET @cOutField06 = @cTaskdetailkey
     --SET @cOutField07 = @cAreaKey
     --SET @cOutField08 = @cTTMStrategykey
      -- (Vicky07) - End
	  
	  --SET @cErrMSG = 	@nFromStep
	  --GOTO QUIT

     IF @nFromStep <> 11
	  BEGIN
		 SET @cOutField03 = '' -- (ChewKP01)
	  
	  -- go to previous screen
       SET @nScn = @nFromScn
       SET @nStep = @nFromStep
		 
		 
	  END
--     IF @nFromStep = 1 -- ESC from Screen 1
--     BEGIN
--       SET @cOutField01 = @cOutField09
--
--       -- go to previous screen
--       SET @nScn = @nFromScn
--       SET @nStep = @nFromStep
--     END
--     ELSE IF @nFromStep = 3 -- ESC from Screen 3 - QTY
--     BEGIN
--      -- prepare next screen
--      SET @cOutField01 = @cID
--      SET @cOutField02 = @cSKU   -- ParentSKU
--      SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
--      SET @cOutField04 = SUBSTRING(@cDescr, 21, 20)
--      IF @cPUOM_Desc = ''
--      BEGIN
--         SET @cOutField05 = '' -- @cPUOM_Desc
--         SET @cOutField07 = '' -- @nPQTY
--         SET @cOutField09 = '' -- @nActPQTY
--         SET @cOutField11 = '1:1' -- @nPUOM_Div
--         SET @cFieldAttr09 = 'O' 
--      END
--      ELSE
--      BEGIN
--         SET @cOutField05 = @cPUOM_Desc
--         SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
--         SET @cOutField09 = '' -- @nActPQTY
--         SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
--      END
--      SET @cOutField06 = @cMUOM_Desc
--      SET @cOutField08 = CAST( @nMQTY as NVARCHAR( 5))
--      SET @cOutField10 = '' -- ActMQTY
--      IF @nPQTY <= 0    
--      BEGIN
--         SET @cOutField07 = ''
--         SET @cOutField09 = ''
--         SET @cFieldAttr09 = 'O' 
--      END
--
--      IF @nMQTY > 0
--      BEGIN
--         SET @cInField10 = ''
--         SET @cFieldAttr10 = '' 
--      END
--      ELSE
--      BEGIN
--         SET @cOutField08 = ''   
--         SET @cInField10 = ''
--         SET @cFieldAttr10 = 'O' 
--      END
--
--      IF @nPQTY > 0     
--         EXEC rdt.rdtSetFocusField @nMobile, 09
--      ELSE
--         EXEC rdt.rdtSetFocusField @nMobile, 10
--
--       SET @nPrevStep = 2
--
--       -- go to previous screen
--       SET @nScn = @nFromScn
--       SET @nStep = @nFromStep
--     END     
   END
   GOTO Quit

   Step_12_Fail:
   BEGIN
      SET @cReasonCode = ''
      -- Reset this screen var
      SET @cOutField01 = ''

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
      --V_QTY         = @nActQty,
      V_LoadKey     = @cLoadKey,
      V_OrderKey    = @cOrderKey,
      
      V_FromStep    = @nFromStep,
      V_FromScn     = @nFromScn,
      V_PUOM_Div    = @nPUOM_Div,
      V_MQTY        = @nMQTY,
      V_PQTY        = @nPQTY,
      
      V_Integer1    = @nActQty,
      V_Integer2    = @nSuggQTY,
      V_Integer3    = @nPrevStep,
      V_Integer4    = @nActMQTY,
      V_Integer5    = @nActPQTY,
      V_Integer6    = @nSUMBOM_Qty,
      V_Integer7    = @nSuggestQTY,
      V_Integer8    = @nTrace,
      V_Integer9    = @nTotalCtnsALL,
      V_Integer10   = @nRemainQTY,

      V_String1     = @cAreaKey,
      V_String2     = @cTTMStrategykey,
      V_String3     = @cToloc,
      V_String4     = @cTTMTasktype,
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
      V_String17    = @cMUOM_Desc,
      V_String18    = @cPUOM_Desc,
      --V_String19    = @nPUOM_Div,
      --V_String20    = @nMQTY,
      --V_String21    = @nPQTY,
      --V_String22    = @nActMQTY,
      --V_String23    = @nActPQTY,
      --V_String24    = @nSUMBOM_Qty, 
      V_String25    = @cPickMethod,
      V_String26    = @cDropID,
      V_String27    = @cAltSKU,
      V_String28    = @cRefKey01,
      --V_String29    = @nSuggestQTY,
      V_String30    = @cPrepackByBOM,  
      --V_String31    = @nTrace, 
		V_String32	  = @cPrinterID,
		V_String33	  = @cTemplateID, 
		--V_String34    = @nTotalCtnsALL,
		V_String36    = @c_taskdetailkeyNMV,
		--V_String37    = @nRemainQTY,
		V_String38    = @cSHTPICKOption,
		V_String39    = @cPickslipNo,

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