SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdtfnc_Pick_CaptureDropID                                 */  
/* Copyright      : IDS                                                       */  
/*                                                                            */  
/* Purpose: Picking SKU/UPC and capture drop id                               */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date         Rev  Author     Purposes                                      */  
/* 31-10-2017   1.0  James      WMS3294. Created                              */  
/* 25-10-2018   1.1  Gan        Performance tuning                            */  
/* 11-06-2021   1.2  YeeKung    WMS17191 Add auto scan in (yeekung01)         */  
/* 16-08-2021   1.3  yeekung    WMS17675 add extendedvalidate in step_dropid  */  
/*                              (yeekung01)                                   */  
/* 26-10-2021   1.4  Chermaine  WMS-18009 clear @cDropID after st1 (cc01)     */
/* 22-09-2022   1.5  James      WMS-20758 Add FlowThruStepSP (james01)        */
/* 13-10-2022   1.6  YeeKung    WMS-20985 Add customize SP (yeekung01)        */
/* 07-02-2023   1.7  YeeKung    WMS-21707 Fix FlowThru DropID (yeekung02)     */
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_Pick_CaptureDropID] (   
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 VARCHAR max  
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variables  
DECLARE  
   @b_success              INT,  
   @bSuccess               INT,  
   @nTask                  INT,  
   @cOption                NVARCHAR( 1),  
   @cZone                  NVARCHAR( 18),    
   @cPickConfirm_SP        NVARCHAR(20),     
   @cGetSuggestedLoc_SP    NVARCHAR(20),     
   @nCurActPQty            INT,              
   @nCurActMQty            INT,              
   @cPickGetTaskInLOC_SP   NVARCHAR( 20),    
   @cSQL                   NVARCHAR( MAX),  
   @cSQLParam              NVARCHAR( MAX),  
  
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),  
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),  
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),  
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),  
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),  
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),  
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),  
   @c_oFieled15 NVARCHAR(20)  
  
-- RDT.RDTMobRec variables  
DECLARE  
   @nFunc          INT,  
   @nScn           INT,  
   @nStep          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nInputKey      INT,  
   @nMenu          INT,  
  
   @cStorer        NVARCHAR( 15),  
   @cUserName      NVARCHAR( 18),  
   @cFacility      NVARCHAR( 5),  
  
   @cPickSlipNo    NVARCHAR( 10),  
   @cLOC           NVARCHAR( 10),  
   @cID            NVARCHAR( 18),  
   @cSKU           NVARCHAR( 20),  
   @cSKUDescr      NVARCHAR( 60),  
   @cUOM           NVARCHAR( 10),         -- Display NVARCHAR(3)  
   @cQTY           NVARCHAR( 5),  
   @cUCC           NVARCHAR( 20),  
   @cLottable1     NVARCHAR( 18),  
   @cLottable2     NVARCHAR( 18),  
   @cLottable3     NVARCHAR( 18),  
   @dLottable4     DATETIME,  
  
   @nPQTY                  INT,           -- Picked QTY  
   @nPUCC                  INT,           -- Picked UCC  
   @nTaskQTY               INT,           -- QTY of the task  
   @nTaskUCC               INT,           -- No of UCC in the task  
   @nCaseCnt               INT,  
   @cUOMDesc               NVARCHAR( 3),  
   @cPPK                   NVARCHAR( 5),  
   @cParentScn             NVARCHAR( 3),  
   @cDropID  NVARCHAR( 60),  
   @cPrefUOM               NVARCHAR( 1),  -- Pref UOM  
   @cPrefUOM_Desc          NVARCHAR( 5),  -- Pref UOM desc  
   @cMstUOM_Desc           NVARCHAR( 5),  -- Master UOM desc  
   @nPrefUOM_Div           INT,           -- Pref UOM divider  
   @nPrefQTY               INT,           -- QTY in pref UOM  
   @nMstQTY         INT,           -- Remaining QTY in master unit  
   @cPickType              NVARCHAR( 1),  -- S=SKU/UPC, U=UCC, P=Pallet  
   @cExternOrderKey        NVARCHAR( 20), -- packheader.externorderkey = loadplan.loadkey??  
   @cSuggestedLOC          NVARCHAR(10),    
   @cPickShowSuggestedLOC  NVARCHAR(1),     
   @nActPQty               INT,             
   @nActMQty               INT,             
   @cExtendedValidateSP    NVARCHAR(20),  
   @cExtendedInfoSP        NVARCHAR(20),  
   @cExtendedInfo          NVARCHAR(20),  
   @cDecodeDropIDSP        NVARCHAR(20),  
   @cPickConfirmSP         NVARCHAR(20),  
   @nQty                   INT,  
   @cDecodeSP              NVARCHAR( 20),   
   @nDropID_Cnt            INT,  
   @cSKUGroup              NVARCHAR( 10),   
   @cChkStorerKey          NVARCHAR( 15),  
   @cOrderKey              NVARCHAR( 10),  
   @nCnt                   INT,  
   @dScanInDate            DATETIME,  
   @dScanOutDate           DATETIME,  
   @cChkStatus             NVARCHAR( 10),  
   @cChkFacility           NVARCHAR( 5),  
   @cBarcode               NVARCHAR( 60),  
   @cUPC                   NVARCHAR( 30),  
   @cChkSKU                NVARCHAR( 30),  
   @nSKUCnt                INT,  
   @nPickQty               INT,  
   @cPrefQTY               NVARCHAR( 5),  
   @cMstQTY                NVARCHAR( 5),  
  
   @cLottable01            NVARCHAR( 18),  
   @cLottable02            NVARCHAR( 18),  
   @cLottable03            NVARCHAR( 18),  
   @dLottable04            DATETIME,  
   @dLottable05            DATETIME,  
   @cLottable06            NVARCHAR( 30),  
   @cLottable07            NVARCHAR( 30),  
   @cLottable08            NVARCHAR( 30),  
   @cLottable09            NVARCHAR( 30),  
   @cLottable10            NVARCHAR( 30),  
   @cLottable11            NVARCHAR( 30),  
   @cLottable12            NVARCHAR( 30),  
   @dLottable13            DATETIME,  
   @dLottable14            DATETIME,  
   @dLottable15            DATETIME,  
  
   @cChkLottable01         NVARCHAR( 18),  
   @cChkLottable02         NVARCHAR( 18),  
   @cChkLottable03         NVARCHAR( 18),  
   @dChkLottable04         DATETIME,  
   @cDropIDBarcode         NVARCHAR( 60),  
   @cAutoScanIn            NVARCHAR( 1),  -- (yeekung01)  
   @cMultiSKUBarcode       NVARCHAR( 3),     
   @cFlowThruStepSP        NVARCHAR( 20),    
   @nToScn                 INT,
   @nToStep                INT,
   
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
   @cInField16 NVARCHAR( 60),   @cOutField16 NVARCHAR( 60),  
  
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
   @nMenu            = Menu,  
   @cLangCode        = Lang_code,  
  
   @cStorer          = StorerKey,  
   @cFacility        = Facility,  
   @cUserName        = UserName,  
  
   @cPickSlipNo      = V_PickSlipNo,  
   @cLOC             = V_LOC,  
   @cID              = V_ID,  
   @cSKU             = V_SKU,  
   @cSKUDescr        = V_SKUDescr,  
   @cUOM             = V_UOM,  
   @cQTY             = V_QTY,  
   @cUCC             = V_UCC,  
   @cLottable1       = V_Lottable01,  
   @cLottable2       = V_Lottable02,  
   @cLottable3       = V_Lottable03,  
   @dLottable4       = V_Lottable04,  
     
   @nPQTY            = V_PQTY,  
   @nTaskQTY         = V_PTaskQty,  
     
   @nPUCC                 = V_Integer1,  
   @nTaskUCC              = V_Integer2,  
   @nCaseCnt              = V_Integer3,  
   @nPrefUOM_Div          = V_Integer4,  
   @nPrefQTY              = V_Integer5,  
   @nMstQTY               = V_Integer6,  
   @cPickShowSuggestedLOC = V_Integer7,  
   @nActPQty              = V_Integer8,  
   @nActMQty              = V_Integer9,  
   @nDropID_Cnt           = V_Integer10,  
  
  -- @nPQTY                 = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String1, 6), 0) = 1 THEN LEFT( V_String1, 6) ELSE 0 END,  -- (james03)  
  -- @nPUCC                 = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 6), 0) = 1 THEN LEFT( V_String2, 6) ELSE 0 END,  
  -- @nTaskQTY              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 10), 0) = 1 THEN LEFT( V_String3, 10) ELSE 0 END,  
  -- @nTaskUCC              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 6), 0) = 1 THEN LEFT( V_String4, 6) ELSE 0 END,  
  -- @nCaseCnt              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 6), 0) = 1 THEN LEFT( V_String5, 6) ELSE 0 END,  
   @cUOMDesc              = V_String6,  
   @cPPK                  = V_String7,  
   @cParentScn            = V_String8,  
   @cDropID               = V_String9,  
   @cPrefUOM              = V_String10, -- Pref UOM  
   @cPrefUOM_Desc         = V_String11, -- Pref UOM desc  
   @cMstUOM_Desc          = V_String12, -- Master UOM desc  
  -- @nPrefUOM_Div          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 6), 0) = 1 THEN LEFT( V_String13, 6) ELSE 0 END, -- Pref UOM divider  
  -- @nPrefQTY              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 6), 0) = 1 THEN LEFT( V_String14, 6) ELSE 0 END, -- QTY in pref UOM  
  -- @nMstQTY               = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 6), 0) = 1 THEN LEFT( V_String15, 6) ELSE 0 END, -- Remaining QTY in master unit  
   @cPickType             = V_String16,  
   @cExternOrderKey       = V_String18,  
   @cSuggestedLOC         = V_String19,  
  -- @cPickShowSuggestedLOC = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String20, 6), 0) = 1 THEN LEFT( V_String20, 6) ELSE 0 END,  
  -- @nActPQty              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String21, 6), 0) = 1 THEN LEFT( V_String21, 6) ELSE 0 END,  -- (james05)  
  -- @nActMQty              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String22, 6), 0) = 1 THEN LEFT( V_String22, 6) ELSE 0 END,  -- (james05)  
   @cExtendedValidateSP   = V_String23,  
   @cExtendedInfoSP       = V_String24,  
   @cExtendedInfo         = V_String25,  
   @cDecodeSP             = V_String27,  
  -- @nDropID_Cnt           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String28, 5), 0) = 1 THEN LEFT( V_String28, 5) ELSE 0 END,  
   @cPickConfirm_SP       = V_String29,  
   @cAutoScanIn           = V_String30,  
   @cMultiSKUBarcode      = V_String31,  
   @cFlowThruStepSP       = V_String32,
      
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
  
FROM rdt.rdtMobRec WITH (NOLOCK)  
WHERE Mobile = @nMobile  
  
-- Screen constant  
DECLARE  
   @nStep_PickSlipNo INT,  @nScn_PickSlipNo INT,  
   @nStep_LOC        INT,  @nScn_LOC        INT,  
   @nStep_SKU        INT,  @nScn_SKU        INT,  
   @nStep_QTY        INT,  @nScn_QTY        INT,  
   @nStep_DropID     INT,  @nScn_DropID     INT,  
   @nStep_SkipTask   INT,  @nScn_SkipTask   INT,  
   @nStep_ShortPick  INT,  @nScn_ShortPick  INT,  
   @nStep_NoMoreTask INT,  @nScn_NoMoreTask INT,  
   @nStep_ConfirmLoc INT,  @nScn_ConfirmLoc INT,  
   @nStep_MultiSKU   INT,  @nScn_MultiSKU   INT   
  
SELECT  
   @nStep_PickSlipNo = 1,  @nScn_PickSlipNo = 5050,  
   @nStep_LOC        = 2,  @nScn_LOC        = 5051,  
   @nStep_SKU        = 3,  @nScn_SKU        = 5052,  
   @nStep_QTY        = 4,  @nScn_QTY        = 5053,  
   @nStep_DropID     = 5,  @nScn_DropID     = 5054,  
   @nStep_SkipTask   = 6,  @nScn_SkipTask   = 5055,  
   @nStep_ShortPick  = 7,  @nScn_ShortPick  = 5056,  
   @nStep_NoMoreTask = 8,  @nScn_NoMoreTask = 5057,  
   @nStep_ConfirmLoc = 9,  @nScn_ConfirmLoc = 5058,  
   @nStep_MultiSKU   = 10, @nScn_MultiSKU   = 3570   
  
IF @nFunc = 955 -- Pick capture dropid.   
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 955  
   IF @nStep = 1  GOTO Step_PickSlipNo  -- Scn = 5050. PickSlipNo  
   IF @nStep = 2  GOTO Step_LOC         -- Scn = 5051. LOC, DropID  
   IF @nStep = 3  GOTO Step_SKU         -- Scn = 5052. SKU  
   IF @nStep = 4  GOTO Step_QTY         -- Scn = 5053. QTY  
   IF @nStep = 5  GOTO Step_DropID      -- Scn = 5054. ID  
   IF @nStep = 6  GOTO Step_SkipTask    -- Scn = 5055. Message. 'Skip Current Task?'  
   IF @nStep = 7  GOTO Step_ShortPick   -- Scn = 5056. Message. 'Confrim Short Pick?'  
   IF @nStep = 8  GOTO Step_NoMoreTask  -- Scn = 5057. Message. 'No more task in LOC'  
   IF @nStep = 9  GOTO Step_ConfirmLoc  -- Scn = 5058. Message. 'LOC not match?'  
   IF @nStep = 10 GOTO Step_MultiSKU         -- Scn = 3570  Multi SKU screen  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step_Start. Func = 955  
********************************************************************************/  
Step_Start:  
BEGIN  
   -- Get prefer UOM  
   SELECT @cPrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA 
   FROM RDT.rdtMobRec M WITH (NOLOCK)  
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)  
   WHERE M.Mobile = @nMobile  
  
   -- Get RDT storer configure  
   SET @cPickShowSuggestedLOC = ''  
   SET @cPickShowSuggestedLOC = rdt.RDTGetConfig( @nFunc, 'PickShowSuggestedLOC', @cStorer)  
  
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)  
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''  
  
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorer)  
   IF @cExtendedInfoSP = '0'  
      SET @cExtendedInfoSP = ''  
  
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)  
   IF @cDecodeSP = '0'  
      SET @cDecodeSP = ''  
  
   SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'PickConfirm_SP', @cStorer)  
   IF @cPickConfirm_SP = '0'  
      SET @cPickConfirm_SP = ''  
  
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorer)      
  
   SET @cAutoScanIn = rdt.rdtGetConfig( @nFunc, 'AutoScanIn', @cStorer)    

   SET @cFlowThruStepSP = rdt.rdtGetConfig( @nFunc, 'FlowThruStepSP', @cStorer)    
   IF @cFlowThruStepSP = '0'    
      SET @cFlowThruStepSP = ''  
      
   -- Set pick type  
   SET @cPickType = 'S'  
  
    -- (Vicky06) EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorer,  
     @nStep       = @nStep  
  
   -- Prepare PickSlipNo screen var  
   SET @cOutField01 = '' -- PickSlipNo  
  
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
  
   -- Go to PickSlipNo screen  
   SET @nScn = @nScn_PickSlipNo  
   SET @nStep = @nStep_PickSlipNo  
   GOTO Quit  
  
   Step_Start_Fail:  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- Option  
   END  
END  
GOTO Quit  
  
  
/************************************************************************************  
Scn = 5050. PickSlipNo screen  
   PSNO    (field01)  
************************************************************************************/  
Step_PickSlipNo:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cPickSlipNo = @cInField01  
  
      -- Validate blank PickSlipNo  
      IF @cPickSlipNo = '' OR @cPickSlipNo IS NULL  
      BEGIN  
         SET @nErrNo = 116351  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PSNO required  
         GOTO PickSlipNo_Fail  
      END  
  
      -- Get pickheader info  
      SELECT TOP 1  
         @cOrderKey = OrderKey,  
         @cExternOrderKey = ExternOrderKey,  
         @cZone = Zone  
      FROM dbo.PickHeader WITH (NOLOCK)  
      WHERE PickHeaderKey = @cPickSlipNo  
  
      -- Validate pickslipno  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 116352  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid PSNO  
         GOTO PickSlipNo_Fail  
      END  
  
      If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP'   
      BEGIN  
         -- Check order shipped  
         IF EXISTS( SELECT TOP 1 1  
            FROM dbo.PickHeader PickHeader WITH (NOLOCK)  
          JOIN dbo.RefKeyLookup RefKeyLookup WITH (NOLOCK) ON (PickHeader.PickHeaderKey = RefKeyLookup.PickSlipNo)  
               JOIN dbo.Orders Orders WITH (NOLOCK) ON (RefKeyLookup.Orderkey = ORDERS.Orderkey)  
            WHERE PickHeader.PickHeaderKey = @cPickSlipNo  
              AND Orders.Status = '9'  
              AND PickHeader.Zone IN ('XD', 'LB', 'LP'))  
         BEGIN  
            SET @nErrNo = 116353  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped  
            GOTO PickSlipNo_Fail  
         END  
  
         -- Check diff storer  
         IF EXISTS( SELECT TOP 1 1  
            FROM dbo.PickHeader PickHeader WITH (NOLOCK)  
               JOIN dbo.RefKeyLookup RefKeyLookup WITH (NOLOCK) ON (PickHeader.PickHeaderKey = RefKeyLookup.PickSlipNo)  
               JOIN dbo.Orders Orders WITH (NOLOCK) ON (RefKeyLookup.Orderkey = ORDERS.Orderkey)  
            WHERE PickHeader.PickHeaderKey = @cPickSlipNo  
              AND Orders.StorerKey <> @cStorer  
              AND PickHeader.Zone IN ('XD', 'LB', 'LP'))  
         BEGIN  
            SET @nErrNo = 116354  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer  
            GOTO PickSlipNo_Fail  
         END  
      END  
      ELSE  
      BEGIN  
         IF ISNULL(@cOrderKey, '') <> ''  
         BEGIN  
            -- Get Order info  
            SELECT   
               @cChkStorerKey = StorerKey,   
               @cChkStatus = Status  
            FROM dbo.Orders WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
              
            -- Check order shipped  
            IF @cChkStatus = '9'  
            BEGIN  
               SET @nErrNo = 116355  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped  
               GOTO PickSlipNo_Fail  
            END  
              
            -- Check storer  
            IF @cChkStorerKey IS NULL OR @cChkStorerKey = '' OR @cChkStorerKey <> @cStorer  
            BEGIN  
               SET @nErrNo = 116356  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff storer  
               GOTO PickSlipNo_Fail  
            END  
         END  
         ELSE  
         BEGIN  
            -- Check order shipped  
            IF EXISTS( SELECT TOP 1 1   
               FROM dbo.PickHeader PH (NOLOCK)       
                  INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey  
                  INNER JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)      
               WHERE PH.PickHeaderKey = @cPickSlipNo      
                  AND O.Status = '9')  
            BEGIN  
               SET @nErrNo = 116357  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped  
               GOTO PickSlipNo_Fail  
            END  
              
            -- Check diff storer  
            IF EXISTS( SELECT TOP 1 1   
               FROM dbo.PickHeader PH (NOLOCK)       
                  INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey  
                  INNER JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)      
               WHERE PH.PickHeaderKey = @cPickSlipNo      
                  AND O.StorerKey <> @cStorer)  
            BEGIN  
               SET @nErrNo = 116358  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer  
               GOTO PickSlipNo_Fail  
            END  
         END  
      END  
        
      -- Get picking info  
      SELECT TOP 1  
         @dScanInDate = ScanInDate,  
         @dScanOutDate = ScanOutDate  
      FROM dbo.PickingInfo WITH (NOLOCK)  
      WHERE PickSlipNo = @cPickSlipNo  
  
      -- Validate pickslip not scan in  
      IF @dScanInDate IS NULL  
      BEGIN  
        -- Auto scan-in            
         IF @cAutoScanIn = '1'            
         BEGIN            
            IF NOT EXISTS( SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)            
            BEGIN            
               INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)            
               VALUES (@cPickSlipNo, GETDATE(), @cUserName)            
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 116386            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail            
                  GOTO Quit            
               END            
            END            
            ELSE            
            BEGIN            
               UPDATE dbo.PickingInfo SET            
                  ScanInDate = GETDATE(),             
                  PickerID = SUSER_SNAME(),             
                  EditWho = SUSER_SNAME()            
               WHERE PickSlipNo = @cPickSlipNo            
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 116387            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail            
                  GOTO Quit            
               END            
            END            
         END            
         ELSE          
         BEGIN          
            SET @nErrNo = 116359  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS not scan in  
            GOTO PickSlipNo_Fail        
         END   
      END  
  
      -- Validate pickslip already scan out  
      IF @dScanOutDate IS NOT NULL  
      BEGIN  
         SET @nErrNo = 116360  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS scanned out  
         GOTO PickSlipNo_Fail  
      END  
  
      SET @cSuggestedLOC = ''  
      SET @cLoc = ''  
      -- If show suggested loc config turned on then goto show suggested loc screen  
      -- svalue can be 1 show sugg loc but cannot overwrite, 2 = show sugg loc but can overwrite  
      IF @cPickShowSuggestedLOC <> '0' -- If not setup, return 0  
      BEGIN  
         -- Get suggested loc  
         SET @nErrNo = 0  
         SET @cGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'PickGetSuggestedLoc_SP', @cStorer)  
         IF ISNULL(@cGetSuggestedLoc_SP, '') NOT IN ('', '0')  
         BEGIN  
            EXEC RDT.RDT_GetSuggestedLoc_Wrapper  
                @n_Mobile        = @nMobile  
               ,@n_Func          = @nFunc  
               ,@c_LangCode      = @cLangCode  
               ,@c_SPName        = @cGetSuggestedLoc_SP  
               ,@c_Storerkey     = @cStorer  
               ,@c_OrderKey      = ''  
               ,@c_PickSlipNo    = @cPickSlipNo  
               ,@c_SKU           = ''  
               ,@c_FromLoc       = @cLOC  
               ,@c_FromID        = ''  
               ,@c_oFieled01     = @c_oFieled01    OUTPUT  
               ,@c_oFieled02     = @c_oFieled02    OUTPUT  
               ,@c_oFieled03     = @c_oFieled03    OUTPUT  
               ,@c_oFieled04     = @c_oFieled04    OUTPUT  
               ,@c_oFieled05     = @c_oFieled05    OUTPUT  
               ,@c_oFieled06     = @c_oFieled06    OUTPUT  
               ,@c_oFieled07     = @c_oFieled07    OUTPUT  
               ,@c_oFieled08     = @c_oFieled08    OUTPUT  
               ,@c_oFieled09     = @c_oFieled09    OUTPUT  
               ,@c_oFieled10     = @c_oFieled10    OUTPUT  
               ,@c_oFieled11     = @c_oFieled11    OUTPUT  
               ,@c_oFieled12     = @c_oFieled12    OUTPUT  
               ,@c_oFieled13     = @c_oFieled13    OUTPUT  
               ,@c_oFieled14     = @c_oFieled14    OUTPUT  
               ,@c_oFieled15     = @c_oFieled15    OUTPUT  
               ,@b_Success       = @b_Success      OUTPUT  
           ,@n_ErrNo         = @nErrNo         OUTPUT  
               ,@c_ErrMsg        = @cErrMsg        OUTPUT  
  
            IF ISNULL(@cErrMsg, '') <> ''  
               GOTO PickSlipNo_Fail  
  
            SET @cSuggestedLOC = @c_oFieled01  
         END  
      END  
  
      -- Prepare LOC screen var  
      SET @cOutField01 = @cPickSlipNo  
      SET @cOutField02 = @cSuggestedLOC  
      SET @cOutField03 = '' -- LOC  
      SET @cOutField04 = '' -- DropID  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
      
      SET @cDropID = '' --(cc01)
  
      -- Go to LOC screen  
      SET @nScn = @nScn_LOC  
      SET @nStep = @nStep_LOC  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
     -- (Vicky06) EventLog - Sign Out Function  
     EXEC RDT.rdt_STD_EventLog  
       @cActionType = '9', -- Sign Out function  
       @cUserID     = @cUserName,  
       @nMobileNo   = @nMobile,  
       @nFunctionID = @nFunc,  
       @cFacility   = @cFacility,  
       @cStorerKey  = @cStorer,  
       @nStep       = @nStep  
  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- Option  
   END  
   GOTO Quit  
  
   PickSlipNo_Fail:  
   BEGIN  
      SET @cOutField01 = '' -- PSNO  
   END  
END  
GOTO Quit  
  
  
/***********************************************************************************  
Scn = 5051. LOC screen  
   PSNO   (field01)  
   LOC    (field02, input)  
***********************************************************************************/  
Step_LOC:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cLOC = @cInField03 -- LOC  
  
      -- Validate blank  
      IF ISNULL( @cLOC, '') = ''   
      BEGIN  
         SET @nErrNo = 116361  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC needed'  
         GOTO LOC_Fail  
      END  
  
      -- Get LOC info  
      SELECT @cChkFacility = Facility  
      FROM dbo.LOC WITH (NOLOCK)  
      WHERE LOC = @cLOC  
  
      -- Validate LOC  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 116362  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'  
         GOTO LOC_Fail  
      END  
  
      -- Validate facility  
      IF @cChkFacility <> @cFacility  
      BEGIN  
         SET @nErrNo = 116363  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'  
         GOTO LOC_Fail  
      END  
      SET @cOutField03 = @cLOC  
  
      -- Decode label  
      SET @cDecodeDropIDSP = rdt.RDTGetConfig( @nFunc, 'DecodeDropIDSP', @cStorer)  
      IF @cDecodeDropIDSP = '0'  
         SET @cDecodeDropIDSP = ''  
  
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) + ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer ' +  
               ',@cPickSlipNo    ' +  
               ',@cSuggestedLOC  ' +  
               ',@cLOC           ' +  
               ',@cID            ' +  
               ',@cDropID        ' +  
               ',@cSKU           ' +  
               ',@cLottable01    ' +  
               ',@cLottable02    ' +  
               ',@cLottable03    ' +  
               ',@dLottable04    ' +  
               ',@nTaskQTY       ' +  
               ',@nPQTY          ' +  
               ',@cUCC           ' +  
               ',@cOption        ' +  
               ',@nErrNo  OUTPUT ' +  
               ',@cErrMsg OUTPUT '  
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @nStep INT, @nInputKey INT, @cFacility NVARCHAR(5), @cStorer NVARCHAR(15)' +  
               ',@cPickSlipNo     NVARCHAR( 10)  ' +  
               ',@cSuggestedLOC   NVARCHAR( 10)  ' +  
               ',@cLOC            NVARCHAR( 10)  ' +  
               ',@cID             NVARCHAR( 18)  ' +  
               ',@cDropID         NVARCHAR( 20)  ' +  
               ',@cSKU            NVARCHAR( 20)  ' +  
               ',@cLottable01     NVARCHAR( 18)  ' +  
               ',@cLottable02     NVARCHAR( 18)  ' +  
               ',@cLottable03     NVARCHAR( 18)  ' +  
               ',@dLottable04     DATETIME       ' +  
               ',@nTaskQTY        INT            ' +  
               ',@nPQTY           INT            ' +  
               ',@cUCC            NVARCHAR( 20)  ' +  
               ',@cOption         NVARCHAR( 1)   ' +  
               ',@nErrNo          INT OUTPUT     ' +  
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer  
               ,@cPickSlipNo  
               ,@cSuggestedLOC  
               ,@cLOC  
               ,@cID  
               ,@cDropID  
               ,@cSKU  
               ,@cLottable1  
               ,@cLottable2  
               ,@cLottable3  
               ,@dLottable4  
               ,@nTaskQTY  
               ,@nPQTY  
               ,@cUCC  
               ,@cOption  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- If show suggested loc config turn on and loc not match suggested loc (james04)  
      IF @cPickShowSuggestedLOC <> '0' AND (@cLOC <> @cSuggestedLOC)  
      BEGIN  
         -- If cannot overwrite suggested loc, prompt error  
         IF @cPickShowSuggestedLOC = 1  
         BEGIN  
            SET @nErrNo = 116364  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid DropID'  
            GOTO LOC_Fail  
         END    
         -- If can overwrite but need confirm loc then goto confirm loc screen  
         IF @cPickShowSuggestedLOC = 2  
         BEGIN  
            -- Prep next screen var  
            SET @cOutField01 = ''  
  
            SET @nScn = @nScn_ConfirmLoc  
            SET @nStep = @nStep_ConfirmLoc  
  
            GOTO Quit  
         END  
      END  
  
      Continue_GetTask:  
      -- Get 1st task in current LOC  
      SET @cID = ''  
      SET @cSKU = ''  
      SET @cUOM = ''  
      SET @cLottable1 = ''  
      SET @cLottable2 = ''  
      SET @cLottable3 = ''  
      SET @dLottable4 = 0 -- 1900-01-01  
  
      -- Get next task  
      -- (james07)  
      SET @nErrNo = 0  
      SET @cPickGetTaskInLOC_SP = rdt.RDTGetConfig( @nFunc, 'PickGetTaskInLOC_SP', @cStorer)  
      IF ISNULL(@cPickGetTaskInLOC_SP, '') NOT IN ('', '0')  
      BEGIN  
         EXEC RDT.RDT_PickGetTaskInLOC_Wrapper  
             @n_Mobile        = @nMobile  
            ,@n_Func          = @nFunc  
            ,@c_LangCode      = @cLangCode  
            ,@c_SPName        = @cPickGetTaskInLOC_SP  
            ,@c_StorerKey     = @cStorer  
            ,@c_PickSlipNo    = @cPickSlipNo  
            ,@c_LOC           = @cLOC  
            ,@c_PrefUOM       = @cPrefUOM  
            ,@c_PickType      = @cPickType  
            ,@c_DropID        = @cDropID  
            ,@c_ID            = @cID            OUTPUT  
            ,@c_SKU           = @cSKU           OUTPUT  
            ,@c_UOM           = @cUOM           OUTPUT  
            ,@c_Lottable1     = @cLottable1     OUTPUT  
            ,@c_Lottable2     = @cLottable2     OUTPUT  
            ,@c_Lottable3     = @cLottable3     OUTPUT  
            ,@d_Lottable4     = @dLottable4     OUTPUT  
            ,@c_SKUDescr      = @cSKUDescr      OUTPUT  
            ,@c_oFieled01     = @c_oFieled01 OUTPUT  
            ,@c_oFieled02     = @c_oFieled02    OUTPUT  
            ,@c_oFieled03     = @c_oFieled03    OUTPUT  
            ,@c_oFieled04     = @c_oFieled04    OUTPUT  
            ,@c_oFieled05     = @c_oFieled05    OUTPUT  
            ,@c_oFieled06     = @c_oFieled06    OUTPUT  
            ,@c_oFieled07     = @c_oFieled07    OUTPUT  
            ,@c_oFieled08     = @c_oFieled08    OUTPUT  
            ,@c_oFieled09     = @c_oFieled09    OUTPUT  
            ,@c_oFieled10     = @c_oFieled10    OUTPUT  
            ,@c_oFieled11     = @c_oFieled11    OUTPUT  
            ,@c_oFieled12     = @c_oFieled12    OUTPUT  
            ,@c_oFieled13     = @c_oFieled13    OUTPUT  
            ,@c_oFieled14     = @c_oFieled14    OUTPUT  
            ,@c_oFieled15     = @c_oFieled15    OUTPUT  
            ,@b_Success       = @bSuccess       OUTPUT  
            ,@n_ErrNo         = @nErrNo         OUTPUT  
            ,@c_ErrMsg        = @cErrMsg        OUTPUT  
  
            SET @nTaskQTY     = CAST(@c_oFieled01 AS INT)  
            SET @nTask        = CAST(@c_oFieled02 AS INT)  
            SET @cUOMDesc     = @c_oFieled03  
            SET @cPPK         = @c_oFieled04  
            SET @nCaseCnt     = CAST(@c_oFieled05 AS INT)  
            SET @cPrefUOM_Desc= @c_oFieled06  
            SET @nPrefQTY     = CAST(@c_oFieled07 AS INT)  
            SET @cMstUOM_Desc = @c_oFieled08  
            SET @nMstQTY      = CAST(@c_oFieled09 AS INT)  
            SET @nPrefUOM_Div = CAST(@c_oFieled10 AS INT)  
      END  
      ELSE  
      BEGIN  
         EXECUTE rdt.rdt_Pick_GetTaskInLOC @cStorer, @cPickSlipNo, @cLOC, @cPrefUOM, @cPickType, @cDropID,  
            @cID             OUTPUT,  
            @cSKU            OUTPUT,  
            @cUOM            OUTPUT,  
            @cLottable1      OUTPUT,  
            @cLottable2      OUTPUT,  
            @cLottable3      OUTPUT,  
            @dLottable4      OUTPUT,  
            @nTaskQTY        OUTPUT,  
            @nTask           OUTPUT,  
            @cSKUDescr       OUTPUT,  
            @cUOMDesc        OUTPUT,  
            @cPPK            OUTPUT,  
            @nCaseCnt        OUTPUT,  
            @cPrefUOM_Desc   OUTPUT,  
          @nPrefQTY        OUTPUT,  
            @cMstUOM_Desc    OUTPUT,  
            @nMstQTY         OUTPUT  
      END  
  
      IF @nTask = 0  
      BEGIN  
         SET @nErrNo = 116365  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- No task in LOC  
         GOTO LOC_Fail  
      END  
  
      -- Goto SKU screen  
      SET @nActPQty = 0   
      SET @nActMQty = 0   
  
      -- Prepare SKU screen var  
      SET @cOutField01 = @cLOC  
      SET @cOutField02 = @cID  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
      SET @cOutField06 = @cLottable2  
      SET @cOutField07 = @cLottable3  
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
      SET @cOutField09 = '' -- SKU/UPC  
      SET @cOutField10 = @cLottable1  
  
      -- Goto SKU screen  
      SET @nScn = @nScn_SKU  
      SET @nStep = @nStep_SKU  
  
      -- Extended Info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) + ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer ' +  
               ',@cPickSlipNo    ' +  
               ',@cSuggestedLOC  ' +  
               ',@cLOC           ' +  
               ',@cID            ' +  
               ',@cDropID        ' +  
               ',@cSKU           ' +  
      ',@cLottable01    ' +  
               ',@cLottable02    ' +  
               ',@cLottable03    ' +  
               ',@dLottable04    ' +  
               ',@nTaskQTY       ' +  
               ',@nPQTY          ' +  
               ',@cUCC           ' +  
               ',@cOption        ' +  
               ',@cExtendedInfo  OUTPUT' +  
               ',@nErrNo         OUTPUT ' +  
               ',@cErrMsg        OUTPUT '  
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @nStep INT, @nAfterStep INT, @nInputKey INT, @cFacility NVARCHAR(5), @cStorer NVARCHAR(15)' +  
               ',@cPickSlipNo     NVARCHAR( 10) ' +  
               ',@cSuggestedLOC   NVARCHAR( 10) ' +  
               ',@cLOC            NVARCHAR( 10) ' +  
               ',@cID             NVARCHAR( 18) ' +  
               ',@cDropID         NVARCHAR( 20) ' +  
               ',@cSKU            NVARCHAR( 20) ' +  
               ',@cLottable01     NVARCHAR( 18) ' +  
               ',@cLottable02     NVARCHAR( 18) ' +  
               ',@cLottable03     NVARCHAR( 18) ' +  
               ',@dLottable04     DATETIME      ' +  
               ',@nTaskQTY        INT           ' +  
               ',@nPQTY           INT           ' +  
               ',@cUCC            NVARCHAR( 20) ' +  
               ',@cOption         NVARCHAR( 1)  ' +  
               ',@cExtendedInfo   NVARCHAR( 20) OUTPUT' +  
               ',@nErrNo          INT           OUTPUT' +  
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep_LOC, @nStep, @nInputKey, @cFacility, @cStorer  
               ,@cPickSlipNo  
               ,@cSuggestedLOC  
               ,@cLOC  
               ,@cID  
               ,@cDropID  
               ,@cSKU  
               ,@cLottable1  
               ,@cLottable2  
               ,@cLottable3  
               ,@dLottable4  
               ,@nTaskQTY  
               ,@nPQTY  
               ,@cUCC  
               ,@cOption  
               ,@cExtendedInfo OUTPUT  
               ,@nErrNo        OUTPUT  
               ,@cErrMsg       OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
                 
            SET @cOutField01 = @cExtendedInfo  
         END  
      END  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Prepare prev screen var  
      SET @cPickSlipNo = ''  
      SET @cOutField01 = '' -- PSNO  
  
      -- Go to prev screen  
      SET @nScn = @nScn_PickSlipNo  
      SET @nStep = @nStep_PickSlipNo  
   END  
   GOTO Quit  
  
   LOC_Fail:  
   BEGIN  
      SET @cLOC = ''  
      SET @cOutField03 = '' -- LOC  
      SET @cOutField04 = @cDropID -- DropID  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
      GOTO Quit  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 5052. SKU screen  
   LOC       (field01)  
   ID        (field02)  
   SKU       (field03)  
   DESCR     (field04, 05)  
   LOTTABLE2 (field06)  
   LOTTABLE3 (field07)  
   LOTTABLE4 (field08)  
   SKU/UPC   (field09, input)  
********************************************************************************/  
Step_SKU:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cBarcode = @cInField09  
      SET @cUPC = LEFT( @cInField09, 30)  
  
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
  
      -- Skip task  
   IF ISNULL( @cBarcode, '') = ''   
      BEGIN  
         -- Remember parent screen  
         SET @cParentScn = 'SKU'  
  
         -- Prepare next screen var  
         SET @cOutField01 = '' -- Option  
  
         -- Go to 'Skip Current Task?' screen  
         SET @nScn = @nScn_SkipTask  
         SET @nStep = @nStep_SkipTask  
  
         GOTO Quit  
      END  
  
      SET @cChkLottable01 = ''  
      SET @cChkLottable02 = ''  
      SET @cChkLottable03 = ''  
      SET @dChkLottable04 = NULL  
        
      -- Decode  
      IF @cDecodeSP <> ''  
      BEGIN  
         -- Standard decode  
         IF @cDecodeSP = '1'  
         BEGIN  
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,   
               @cUPC        = @cUPC           OUTPUT,   
               @cLottable01 = @cChkLottable01 OUTPUT,   
               @cLottable02 = @cChkLottable02 OUTPUT,   
               @cLottable03 = @cChkLottable03 OUTPUT,   
               @dLottable04 = @dChkLottable04 OUTPUT  
         END  
          -- Customize decode        
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +        
               ' @cPickSlipNo, @cDropID, @cLOC, ' +        
               ' @cUPC        OUTPUT, @nQTY        OUTPUT, ' +        
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT,'+    
               ' @nErrNo   OUTPUT, @cErrMsg     OUTPUT'        
            SET @cSQLParam =        
               ' @nMobile      INT,           ' +        
               ' @nFunc        INT,           ' +        
               ' @cLangCode    NVARCHAR( 3),  ' +                         
               ' @nStep        INT,           ' +        
               ' @nInputKey    INT,           ' +        
               ' @cFacility    NVARCHAR( 5),  ' +        
               ' @cStorerKey   NVARCHAR( 15), ' +        
               ' @cBarcode     NVARCHAR( 60), ' +        
               ' @cPickSlipNo  NVARCHAR( 10), ' +              
               ' @cDropID      NVARCHAR( 20), ' +        
               ' @cLOC         NVARCHAR( 10), ' +        
               ' @cUPC         NVARCHAR( 30)  OUTPUT, ' +        
               ' @nQTY         INT            OUTPUT, ' +        
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +        
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +        
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +        
               ' @dLottable04  DATETIME       OUTPUT, ' +           
               ' @nErrNo       INT            OUTPUT, ' +        
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cBarcode,        
               @cPickSlipNo, @cDropID, @cLOC,        
               @cUPC        OUTPUT, @nQTY        OUTPUT,        
               @cChkLottable01 OUTPUT, @cChkLottable02 OUTPUT, @cChkLottable03 OUTPUT, @dChkLottable04 OUTPUT,    
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT        
         END        

         IF @nErrNo<>0
            GOTO SKU_Fail 
      END  
  
      -- Validate SKU  
      -- Assumption: no SKU with same barcode.  
      SET @nSKUCnt = 0  
        
      EXEC RDT.rdt_GetSKUCNT  
          @cStorerKey  = @cStorer  
         ,@cSKU        = @cUPC  
         ,@nSKUCnt     = @nSKUCnt   OUTPUT  
         ,@bSuccess    = @bSuccess  OUTPUT  
         ,@nErr        = @nErrNo    OUTPUT  
         ,@cErrMsg     = @cErrMsg   OUTPUT  
  
      -- Check SKU valid  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 116366  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'  
         GOTO SKU_Fail  
      END  
  
      -- Validate barcode return multiple SKU      
      IF @nSKUCnt > 1      
      BEGIN      
         IF @cMultiSKUBarcode IN ('1', '2')      
         BEGIN      
  
            SET @cOutField01=''   
            SET @cInField01=''  
                  
            EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,      
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,      
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,      
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,      
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,      
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,      
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,      
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,      
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,      
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,      
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,     
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,      
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,      
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,      
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,      
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,      
               'POPULATE',      
               @cMultiSKUBarcode,      
               @cStorer,      
               @cUPC     OUTPUT,      
               @nErrNo   OUTPUT,      
               @cErrMsg  OUTPUT,      
               'PickSlipNo',    -- DocType      
               @cPickSlipNo,  
               'LOC',  
               @cloc  
      
            IF @nErrNo = 0 -- Populate multi SKU screen      
            BEGIN      
               -- Go to Multi SKU screen      
               SET @nScn = @nScn_MultiSKU      
               SET @nStep = @nStep_MultiSKU      
               GOTO Quit      
            END      
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen      
               SET @nErrNo = 0      
         END      
         ELSE      
         BEGIN      
            SET @nErrNo = 116367      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod      
            GOTO SKU_Fail      
         END      
      END      
                    
      -- Get SKU  
      SET @cChkSKU = @cUPC  
      EXEC rdt.rdt_GetSKU  
          @cStorerKey  = @cStorer  
         ,@cSKU        = @cChkSKU   OUTPUT  
         ,@bSuccess    = @bSuccess  OUTPUT  
         ,@nErr        = @nErrNo    OUTPUT  
         ,@cErrMsg     = @cErrMsg   OUTPUT  
              
      -- Validate SKU  
      IF @cSKU <> @cChkSKU  
      BEGIN  
         SET @nErrNo = 116368  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Wrong SKU'  
         GOTO SKU_Fail  
      END  
  
      -- Validate L01  
      IF @cLottable1 <> '' AND @cChkLottable01 <> '' AND @cLottable1 <> @cChkLottable01   
      BEGIN  
         SET @nErrNo = 116369  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different L01'  
         GOTO SKU_Fail  
      END  
  
      -- Validate L02  
      IF @cLottable2 <> '' AND @cChkLottable02 <> '' AND @cLottable2 <> @cChkLottable02   
      BEGIN  
         SET @nErrNo = 116370  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different L02'  
         GOTO SKU_Fail  
      END  
        
      -- Validate L03  
      IF @cLottable3 <> '' AND @cChkLottable03 <> '' AND @cLottable3 <> @cChkLottable03   
      BEGIN  
         SET @nErrNo = 116371  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different L03'  
         GOTO SKU_Fail  
      END  
        
      -- Validate L04  
      IF (@dLottable4 <> 0 AND @dLottable4 IS NOT NULL) AND   
         (@dChkLottable04 <> 0 AND @dChkLottable04 IS NOT NULL) AND  
         @dLottable4 <> @dChkLottable04   
      BEGIN  
         SET @nErrNo = 116372  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different L04'  
         GOTO SKU_Fail  
      END  
  
      -- Prepare QTY screen var  
      SET @cOutField02 = @cID  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
      SET @cOutField06 = @cLottable2  
      SET @cOutField07 = @cLottable3  
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
      SET @cOutField09 = @cPPK  
  
      IF @cPrefUOM_Desc = ''  
      BEGIN  
         SET @cOutField10 = '' -- @cPrefUOM_Desc  
         SET @cOutField11 = '' -- @nPrefQTY  
  
         SET @cFieldAttr14 = 'O'   
      END  
      ELSE  
      BEGIN  
         SET @cOutField10 = @cPrefUOM_Desc  
         SET @cOutField11 = CAST( @nPrefQTY AS NVARCHAR( 5))  
      END  
      SET @cOutField12 = @cMstUOM_Desc  
      SET @cOutField13 = @nMstQTY  
      SET @cOutField14 = CASE WHEN ISNULL( @c_oFieled01, '') <> '' THEN @c_oFieled01 ELSE '' END -- @nPrefQTY  
      SET @cOutField15 = CASE WHEN ISNULL( @c_oFieled02, '') <> '' THEN @c_oFieled02 ELSE '' END -- @nMstQTY  
      SET @cOutField01 = @cLottable1  
  
      -- Goto QTY screen  
      SET @nScn = @nScn_QTY  
      SET @nStep = @nStep_QTY  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare LOC screen var  
      SET @cOutField01 = @cPickSlipNo  
      SET @cOutField02 = @cSuggestedLOC  
      SET @cOutField03 = '' -- LOC  
      SET @cOutField04 = '' -- DropID  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
  
      -- Go to prev screen  
      SET @nScn = @nScn_LOC  
      SET @nStep = @nStep_LOC  
   END  
   GOTO Quit  
  
   SKU_Fail:  
   BEGIN  
      SET @cOutField08 = '' -- SKU  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 5053. QTY screen  
   LOC       (field01)  
   ID        (field02)  
   SKU       (field03)  
   DESCR     (field04, 05)  
   LOTTABLE2 (field06)  
   LOTTABLE3 (field07)  
   LOTTABLE4 (field08)  
   PPK       (field09)  
   PrefUOM   (field10)  
   PrefQTY   (field11)  
   MstUOM    (field12)  
   MstQTY    (field13)  
   PrefQTY   (field14, input)  
   MstQTY    (field15, input)  
********************************************************************************/  
Step_QTY:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
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
      SET @cPrefQTY = @cInField14  
      SET @cMstQTY  = @cInField15  
  
      -- Retain QTY keyed-in  
      SET @cOutField14 = @cInField14  
      SET @cOutField15 = @cInField15  
  
      -- Validate PrefQTY  
      IF @cPrefQTY = '' SET @cPrefQTY = '0' -- Blank taken as zero  
      IF RDT.rdtIsValidQTY( @cPrefQTY, 0) = 0  
      BEGIN  
         SET @nErrNo = 116373  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'  
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- PrefQTY  
         GOTO QTY_Fail  
      END  
  
      -- Validate MstQTY  
      IF @cMstQTY  = '' SET @cMstQTY  = '0' -- Blank taken as zero  
      IF RDT.rdtIsValidQTY( @cMstQTY, 0) = 0  
      BEGIN  
         SET @nErrNo = 116374  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'  
         EXEC rdt.rdtSetFocusField @nMobile, 15 -- MstQTY  
         GOTO QTY_Fail  
      END  
  
      -- Calc total QTY in master UOM  
      SET @nPQTY = rdt.rdtConvUOMQTY( @cStorer, @cSKU, @cPrefQTY, @cPrefUOM, 6) -- Convert to QTY in master UOM  
      SET @nPQTY = @nPQTY + CAST( @cMstQTY AS INT)  
  
      -- Validate over pick  
      IF @nPQTY > @nTaskQTY  
      BEGIN  
         SET @nErrNo = 116375  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over pick'  
         GOTO QTY_Fail  
      END  
  
      -- Remember current value  
      SET @nCurActPQty = @nActPQty  
      SET @nCurActMQty = @nActMQty  
  
      -- Assign new value  
      SET @nActPQty = @cInField14  
      SET @nActMQty = @cInField15  
  
      -- Short pick  
      IF @nPQTY < @nTaskQTY  
      BEGIN  
         -- If setup codelkup then go back SKU screen to recursively scan sku/upc  
         IF EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'ScanQty' and StorerKey = @cStorer)  
         BEGIN  
  
            IF @nActPQty < @nTaskQTY  
            BEGIN  
               -- Prepare SKU screen var  
               SET @cOutField01 = @cLOC  
               SET @cOutField02 = @cID  
               SET @cOutField03 = @cSKU  
               SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
               SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
               SET @cOutField06 = @cLottable2  
               SET @cOutField07 = @cLottable3  
               SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
               SET @cOutField09 = '' -- SKU/UPC  
               SET @cOutField10 = @cLottable1  
  
               -- Goto SKU screen  
               SET @nScn = @nScn_SKU  
               SET @nStep = @nStep_SKU  
  
               GOTO Quit  
            END  
         END  
         ELSE  
         BEGIN  
            -- If config turn on then skip short pick and continue confirm pick   
            IF rdt.RDTGetConfig( @nFunc, 'DISABLESHORTPICK', @cStorer) = '1'  
            BEGIN  
               IF ISNULL(@cFlowThruStepSP,'') = ''    --yeekung02
               BEGIN    
                  goto HERE 
               END  
               ELSE
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cFlowThruStepSP AND type = 'P')    
                  BEGIN    
            	      SET @nErrNo = 0
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cFlowThruStepSP) +    
                        ' @nMobile, @nFunc, @cLangCode, @nScn, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                        ' @cPickSlipNo, @cLOC, @cID, @cSKU, @cUOM, @nQTY, @cDropID, ' + 
                        ' @cInField01 OUTPUT, @cInField02 OUTPUT, @cInField03 OUTPUT, @cInField04 OUTPUT, @cInField05 OUTPUT, ' + 
                        ' @cInField06 OUTPUT, @cInField07 OUTPUT, @cInField08 OUTPUT, @cInField09 OUTPUT, @cInField10 OUTPUT, ' +
                        ' @cInField11 OUTPUT, @cInField12 OUTPUT, @cInField13 OUTPUT, @cInField14 OUTPUT, @cInField15 OUTPUT, ' +
                        ' @nToScn OUTPUT, @nToStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                     SET @cSQLParam =    
                        ' @nMobile      INT,           ' +    
                        ' @nFunc        INT,           ' +    
                        ' @cLangCode    NVARCHAR( 3),  ' +    
                        ' @nScn         INT,           ' +    
                        ' @nStep        INT,           ' +
                        ' @nInputKey INT,           ' +    
                        ' @cFacility    NVARCHAR( 5) , ' +    
                        ' @cStorerKey   NVARCHAR( 15), ' +    
                        ' @cPickSlipNo  NVARCHAR( 10), ' +    
                        ' @cLOC         NVARCHAR( 10), ' +
                        ' @cID          NVARCHAR( 10), ' +
                        ' @cSKU         NVARCHAR( 20), ' +    
                        ' @cUOM         NVARCHAR( 10), ' +
                        ' @nQTY         INT, ' +
                        ' @cDropID      NVARCHAR( 20), ' +
                        ' @cInField01   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField02   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField03   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField04   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField05   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField06   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField07   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField08   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField09   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField10   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField11   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField12   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField13   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField14   NVARCHAR( 60) OUTPUT,  ' +
                        ' @cInField15   NVARCHAR( 60) OUTPUT,  ' +
                        ' @nToScn       INT           OUTPUT,  ' +    
                        ' @nToStep      INT           OUTPUT,  ' +
                        ' @nErrNo       INT           OUTPUT, ' +    
                        ' @cErrMsg      NVARCHAR(250) OUTPUT  '    
    
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                        @nMobile, @nFunc, @cLangCode, @nScn, @nStep, @nInputKey, @cFacility, @cStorer,    
                        @cPickSlipNo, @cLOC, @cID, @cSKU, @cUOM, @nQTY, @cDropID,  
                        @cInField01 OUTPUT, @cInField02 OUTPUT, @cInField03 OUTPUT, @cInField04 OUTPUT, @cInField05 OUTPUT, 
                        @cInField06 OUTPUT, @cInField07 OUTPUT, @cInField08 OUTPUT, @cInField09 OUTPUT, @cInField10 OUTPUT, 
                        @cInField11 OUTPUT, @cInField12 OUTPUT, @cInField13 OUTPUT, @cInField14 OUTPUT, @cInField15 OUTPUT, 
                        @nToScn OUTPUT, @nToStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     

                     IF @nErrNo > 0     
                        GOTO Quit    

                     SET @nDropID_Cnt = 0  
                     SET @cOutField01 = CAST( @nDropID_Cnt AS NVARCHAR( 3)) + '/' + CAST( @nActPQty AS NVARCHAR( 3))  
                     SET @cOutField02 = ''  
                     SET @cDropID = ''  
  
                     SET @nScn = @nToScn  
                     SET @nStep = @nToStep
               
                     IF @nErrNo <> -1
               	      GOTO Step_DropID
                  END  
 
                  IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')  
                  BEGIN  
                     EXEC RDT.rdt_Pick_ConfirmTask_Wrapper  
                         @n_Mobile        = @nMobile  
                        ,@n_Func          = @nFunc  
                        ,@c_LangCode      = @cLangCode  
                        ,@c_SPName        = @cPickConfirm_SP  
                        ,@c_PickSlipNo    = @cPickSlipNo  
                        ,@c_DropID        = @cDropID  
                        ,@c_LOC           = @cLOC  
                        ,@c_ID            = @cID  
                        ,@c_Storerkey     = @cStorer  
                        ,@c_SKU           = @cSKU  
                        ,@c_UOM           = @cUOM  
                        ,@c_Lottable1     = @cLottable1  
                        ,@c_Lottable2     = @cLottable2  
                        ,@c_Lottable3     = @cLottable3  
                        ,@d_Lottable4     = @dLottable4  
                        ,@n_TaskQTY       = @nTaskQTY  
                        ,@n_PQTY          = @nPQTY  
                        ,@c_UCCTask       = 'N'          -- Y = UCC, N = SKU/UPC  
                        ,@c_PickType      = @cPickType  
                        ,@b_Success       = @bSuccess    OUTPUT  
                        ,@n_ErrNo         = @nErrNo      OUTPUT  
                        ,@c_ErrMsg        = @cErrMsg     OUTPUT  
                  END  
                  ELSE  
                  BEGIN  
                     -- Confirm task  
                     EXECUTE rdt.rdt_Pick_ConfirmTask @nErrNo OUTPUT, @cErrMsg OUTPUT, @cLangCode,  
                        @cPickSlipNo,  
                        @cDropID,  
                        @cLOC,  
                        @cID,  
                        @cStorer,  
                        @cSKU,  
                        @cUOM,  
                        @cLottable1,   
                        @cLottable2,  
                        @cLottable3,  
                        @dLottable4,  
                        @nTaskQTY,  
                        @nPQTY,  
                        'N', -- Y = UCC, N = SKU/UPC  
                        @cPickType,    
                        @nMobile   
                  END  
  
                  IF @nErrNo <> 0  
                  BEGIN  
                     -- Reverse back to prev value  
                     SET @nActPQty = @nCurActPQty  
                     SET @nActMQty = @nCurActMQty  
  
                     GOTO Quit  
                  END  
                  ELSE  
                  BEGIN  
                     -- Re-Initiase value  
                     SET @nActPQty = 0  
                     SET @nActMQty = 0  
                  END  
  
                  -- Check if anymore pick task in same loc  
                  SET @cID = ''  
                  SET @cSKU = ''  
                  SET @cUOM = ''  
                  SET @cLottable1 = ''  
                  SET @cLottable2 = ''  
                  SET @cLottable3 = ''  
                  SET @dLottable4 = 0 -- 1900-01-01  
                  SET @nTaskQTY = 0  
  
                  SET @nErrNo = 0  
                  SET @cPickGetTaskInLOC_SP = rdt.RDTGetConfig( @nFunc, 'PickGetTaskInLOC_SP', @cStorer)  
                  IF ISNULL(@cPickGetTaskInLOC_SP, '') NOT IN ('', '0')  
                  BEGIN  
                     EXEC RDT.RDT_PickGetTaskInLOC_Wrapper  
                         @n_Mobile        = @nMobile  
                        ,@n_Func          = @nFunc  
                        ,@c_LangCode      = @cLangCode  
            ,@c_SPName        = @cPickGetTaskInLOC_SP  
                        ,@c_StorerKey     = @cStorer  
                        ,@c_PickSlipNo    = @cPickSlipNo  
                        ,@c_LOC           = @cLOC  
                        ,@c_PrefUOM       = @cPrefUOM  
                        ,@c_PickType      = @cPickType  
                        ,@c_DropID        = @cDropID  
                        ,@c_ID            = @cID            OUTPUT  
                        ,@c_SKU           = @cSKU           OUTPUT  
                        ,@c_UOM           = @cUOM           OUTPUT  
          ,@c_Lottable1     = @cLottable1     OUTPUT  
                        ,@c_Lottable2     = @cLottable2     OUTPUT  
                        ,@c_Lottable3     = @cLottable3     OUTPUT  
                        ,@d_Lottable4     = @dLottable4     OUTPUT  
                        ,@c_SKUDescr      = @cSKUDescr      OUTPUT  
                        ,@c_oFieled01     = @c_oFieled01    OUTPUT  
                        ,@c_oFieled02     = @c_oFieled02    OUTPUT  
                        ,@c_oFieled03     = @c_oFieled03    OUTPUT  
                        ,@c_oFieled04     = @c_oFieled04    OUTPUT  
                        ,@c_oFieled05     = @c_oFieled05    OUTPUT  
                        ,@c_oFieled06     = @c_oFieled06    OUTPUT  
                        ,@c_oFieled07     = @c_oFieled07    OUTPUT  
                        ,@c_oFieled08     = @c_oFieled08    OUTPUT  
                        ,@c_oFieled09     = @c_oFieled09    OUTPUT  
                        ,@c_oFieled10     = @c_oFieled10    OUTPUT  
                        ,@c_oFieled11     = @c_oFieled11    OUTPUT  
                        ,@c_oFieled12     = @c_oFieled12    OUTPUT  
                        ,@c_oFieled13     = @c_oFieled13    OUTPUT  
                        ,@c_oFieled14     = @c_oFieled14    OUTPUT  
                        ,@c_oFieled15     = @c_oFieled15    OUTPUT  
                        ,@b_Success       = @bSuccess       OUTPUT  
                        ,@n_ErrNo         = @nErrNo         OUTPUT  
                        ,@c_ErrMsg        = @cErrMsg        OUTPUT  
  
                        SET @nTaskQTY     = CAST(@c_oFieled01 AS INT)  
                        SET @nTask        = CAST(@c_oFieled02 AS INT)  
                        SET @cUOMDesc     = @c_oFieled03  
                        SET @cPPK         = @c_oFieled04  
                        SET @nCaseCnt     = CAST(@c_oFieled05 AS INT)  
                        SET @cPrefUOM_Desc= @c_oFieled06  
                        SET @nPrefQTY     = CAST(@c_oFieled07 AS INT)  
                        SET @cMstUOM_Desc = @c_oFieled08  
                        SET @nMstQTY      = CAST(@c_oFieled09 AS INT)  
                        SET @nPrefUOM_Div = CAST(@c_oFieled10 AS INT)  
                  END  
                  ELSE  
                  BEGIN  
                     EXECUTE rdt.rdt_Pick_GetTaskInLOC @cStorer, @cPickSlipNo, @cLOC, @cPrefUOM, @cPickType, @cDropID,  
                        @cID             OUTPUT,  
                        @cSKU            OUTPUT,  
                        @cUOM            OUTPUT,  
                        @cLottable1      OUTPUT,  
                        @cLottable2      OUTPUT,  
                        @cLottable3      OUTPUT,  
                        @dLottable4      OUTPUT,  
                        @nTaskQTY        OUTPUT,  
                        @nTask           OUTPUT,  
                        @cSKUDescr       OUTPUT,  
                        @cUOMDesc        OUTPUT,  
                        @cPPK            OUTPUT,  
                        @nCaseCnt        OUTPUT,  
                        @cPrefUOM_Desc   OUTPUT,  
                        @nPrefQTY        OUTPUT,  
                        @cMstUOM_Desc    OUTPUT,  
                        @nMstQTY         OUTPUT  
                  END  
  
                  IF @nTask = 0  
                  BEGIN  
                     -- Check if the display suggested loc turned on  
                     IF @cPickShowSuggestedLOC <> '0'  
                     BEGIN  
                        -- If turned on then check whether there is another loc to pick  
                        -- Get suggested loc  
                        SET @cSuggestedLOC = ''  
                        SET @cLoc = ''                       
                        SET @nErrNo = 0  
                        SET @cGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'PickGetSuggestedLoc_SP', @cStorer)  
                        IF ISNULL(@cGetSuggestedLoc_SP, '') NOT IN ('', '0')  
                        BEGIN  
                           EXEC RDT.RDT_GetSuggestedLoc_Wrapper  
                           @n_Mobile        = @nMobile  
                              ,@n_Func          = @nFunc  
                              ,@c_LangCode      = @cLangCode  
                              ,@c_SPName        = @cGetSuggestedLoc_SP  
                              ,@c_Storerkey     = @cStorer  
                              ,@c_OrderKey      = ''  
                              ,@c_PickSlipNo    = @cPickSlipNo  
                              ,@c_SKU           = ''  
                              ,@c_FromLoc       = @cLOC  
                              ,@c_FromID        = ''  
                              ,@c_oFieled01     = @c_oFieled01    OUTPUT  
                              ,@c_oFieled02     = @c_oFieled02    OUTPUT  
                              ,@c_oFieled03     = @c_oFieled03    OUTPUT  
                              ,@c_oFieled04     = @c_oFieled04    OUTPUT  
                              ,@c_oFieled05     = @c_oFieled05    OUTPUT  
                              ,@c_oFieled06     = @c_oFieled06    OUTPUT  
                              ,@c_oFieled07     = @c_oFieled07    OUTPUT  
                              ,@c_oFieled08     = @c_oFieled08    OUTPUT  
                              ,@c_oFieled09     = @c_oFieled09    OUTPUT  
                              ,@c_oFieled10     = @c_oFieled10    OUTPUT  
                              ,@c_oFieled11     = @c_oFieled11    OUTPUT  
                              ,@c_oFieled12     = @c_oFieled12    OUTPUT  
                              ,@c_oFieled13     = @c_oFieled13    OUTPUT  
                              ,@c_oFieled14     = @c_oFieled14    OUTPUT  
                              ,@c_oFieled15     = @c_oFieled15    OUTPUT  
                              ,@b_Success       = @b_Success      OUTPUT  
                              ,@n_ErrNo         = @nErrNo         OUTPUT  
                              ,@c_ErrMsg        = @cErrMsg        OUTPUT  
                        END  
  
                        -- Nothing to pick for the pickslip, goto display summary  
                        IF ISNULL(@c_oFieled01, '') = ''  
                        BEGIN  
                           -- No need display error message if nothing to pick anymore  
                           SET @cErrMsg = ''  
                           SET @cOutField01 = '' -- PickSlipNo  
  
                           -- Go to PickSlipNo screen  
                           SET @nScn = @nScn_PickSlipNo  
                           SET @nStep = @nStep_PickSlipNo  
                           GOTO Quit  
                        END  
  
                     END  
                     ELSE  
                     BEGIN  
                        SET @cOutField01 = @cLOC  
                        -- Go to screen 'No more task in LOC'  
                        SET @nScn = @nScn_NoMoreTask  
                        SET @nStep = @nStep_NoMoreTask  
                     END  
  
                     GOTO Quit  
                  END  
                  ELSE  
                  BEGIN  
                     -- Go to SKU screen  
                     SET @cOutField01 = @cLOC  
                     SET @cOutField02 = @cID  
                     SET @cOutField03 = @cSKU  
                     SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
                     SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
                     SET @cOutField06 = @cLottable2  
                     SET @cOutField07 = @cLottable3  
                     SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
                     SET @cOutField09 = '' -- SKU/UPC  
                     SET @cOutField10 = @cLottable1  
  
                     -- Go to SKU screen  
                     SET @nScn = @nScn_SKU  
                     SET @nStep = @nStep_SKU  
                  END  
            END 
            END
            ELSE  
            BEGIN  
               -- Remember parent screen  
               SET @cParentScn = 'QTY'  
  
               -- Go to screen 'Confirm Short Pick?'  
               SET @nScn = @nScn_ShortPick  
          SET @nStep = @nStep_ShortPick  
  
               SET @cOutField01 = '' -- Option  
            END  
         END  
      END  
        
      IF @nPQTY = @nTaskQTY  
      BEGIN  
         IF @cFlowThruStepSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cFlowThruStepSP AND type = 'P')    
            BEGIN    
            	SET @nErrNo = 0
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cFlowThruStepSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nScn, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                  ' @cPickSlipNo, @cLOC, @cID, @cSKU, @cUOM, @nQTY, @cDropID, ' + 
                  ' @cInField01 OUTPUT, @cInField02 OUTPUT, @cInField03 OUTPUT, @cInField04 OUTPUT, @cInField05 OUTPUT, ' + 
                  ' @cInField06 OUTPUT, @cInField07 OUTPUT, @cInField08 OUTPUT, @cInField09 OUTPUT, @cInField10 OUTPUT, ' +
                  ' @cInField11 OUTPUT, @cInField12 OUTPUT, @cInField13 OUTPUT, @cInField14 OUTPUT, @cInField15 OUTPUT, ' +
                  ' @nToScn OUTPUT, @nToStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  ' @nMobile      INT,           ' +    
                  ' @nFunc        INT,           ' +    
                  ' @cLangCode    NVARCHAR( 3),  ' +    
                  ' @nScn         INT,           ' +    
                  ' @nStep        INT,           ' +
                  ' @nInputKey INT,           ' +    
                  ' @cFacility    NVARCHAR( 5) , ' +    
                  ' @cStorerKey   NVARCHAR( 15), ' +    
                  ' @cPickSlipNo  NVARCHAR( 10), ' +    
                  ' @cLOC         NVARCHAR( 10), ' +
                  ' @cID          NVARCHAR( 10), ' +
                  ' @cSKU         NVARCHAR( 20), ' +    
                  ' @cUOM         NVARCHAR( 10), ' +
                  ' @nQTY         INT, ' +
                  ' @cDropID      NVARCHAR( 20), ' +
                  ' @cInField01   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField02   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField03   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField04   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField05   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField06   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField07   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField08   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField09   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField10   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField11   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField12   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField13   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField14   NVARCHAR( 60) OUTPUT,  ' +
                  ' @cInField15   NVARCHAR( 60) OUTPUT,  ' +
                  ' @nToScn       INT           OUTPUT,  ' +    
                  ' @nToStep      INT           OUTPUT,  ' +
                  ' @nErrNo       INT           OUTPUT, ' +    
                  ' @cErrMsg      NVARCHAR(250) OUTPUT  '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nScn, @nStep, @nInputKey, @cFacility, @cStorer,    
                  @cPickSlipNo, @cLOC, @cID, @cSKU, @cUOM, @nQTY, @cDropID,  
                  @cInField01 OUTPUT, @cInField02 OUTPUT, @cInField03 OUTPUT, @cInField04 OUTPUT, @cInField05 OUTPUT, 
                  @cInField06 OUTPUT, @cInField07 OUTPUT, @cInField08 OUTPUT, @cInField09 OUTPUT, @cInField10 OUTPUT, 
                  @cInField11 OUTPUT, @cInField12 OUTPUT, @cInField13 OUTPUT, @cInField14 OUTPUT, @cInField15 OUTPUT, 
                  @nToScn OUTPUT, @nToStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     

               IF @nErrNo > 0     
                  GOTO Quit    

               SET @nDropID_Cnt = 0  
               SET @cOutField01 = CAST( @nDropID_Cnt AS NVARCHAR( 3)) + '/' + CAST( @nActPQty AS NVARCHAR( 3))  
               SET @cOutField02 = ''  
               SET @cDropID = ''  
  
               SET @nScn = @nToScn  
               SET @nStep = @nToStep
               
               IF @nErrNo <> -1
               	GOTO Step_DropID
            END    
         END    
         ELSE
         BEGIN
            HERE:  
            SET @nDropID_Cnt = 0  
            SET @cOutField01 = CAST( @nDropID_Cnt AS NVARCHAR( 3)) + '/' + CAST( @nActPQty AS NVARCHAR( 3))  
            SET @cOutField02 = ''  
            SET @cDropID = ''  
  
            SET @nScn = @nScn_DropID  
            SET @nStep = @nStep_DropID  
  
            GOTO Quit
         END  
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Go to SKU screen  
      SET @cOutField01 = @cLOC  
      SET @cOutField02 = @cID  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
      SET @cOutField06 = @cLottable2  
      SET @cOutField07 = @cLottable3  
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
      SET @cOutField09 = '' -- SKU/UPC  
      SET @cOutField10 = @cLottable1  
  
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
  
      -- Go to prev screen  
      SET @nScn = @nScn_SKU  
      SET @nStep = @nStep_SKU  
   END  
   GOTO Quit  
  
   QTY_Fail:  
   BEGIN  
      SET @cFieldAttr14 = ''  
  
      -- Prepare QTY screen var  
      SET @cOutField02 = @cID  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
      SET @cOutField06 = @cLottable2  
      SET @cOutField07 = @cLottable3  
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
      SET @cOutField09 = @cPPK  
      IF @cPrefUOM_Desc = ''  
      BEGIN  
         SET @cOutField10 = '' -- @cPrefUOM_Desc  
         SET @cOutField11 = '' -- @nPrefQTY  
  
         SET @cFieldAttr14 = 'O'  
      END  
      ELSE  
      BEGIN  
         SET @cOutField10 = @cPrefUOM_Desc  
         SET @cOutField11 = CAST( @nPrefQTY AS NVARCHAR( 5))  
      END  
      SET @cOutField12 = @cMstUOM_Desc  
      SET @cOutField13 = @nMstQTY  
      SET @cOutField14 = '' -- @nPrefQTY  
      SET @cOutField15 = '' -- @nMstQTY  
      SET @cOutField01 = @cLottable1  
   END  
  
END  
GOTO Quit  
  
/***********************************************************************************  
Scn = 5054. Drop ID  
   DROP ID   (field02, input)  
************************************************************************************/  
Step_DropID:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cDropID = @cInField02  
      SET @cDropIDBarcode = @cInField02  
  
      -- Validate blank  
      IF ISNULL( @cDropID, '') = ''  
      BEGIN  
         SET @nErrNo = 116376  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DROPID needed'  
         GOTO DropID_Fail  
      END  
  
      -- Decode label  
      SET @cDecodeDropIDSP = rdt.RDTGetConfig( @nFunc, 'DecodeDropIDSP', @cStorer)  
      IF @cDecodeDropIDSP = '0'  
         SET @cDecodeDropIDSP = ''  
  
      -- Extended update  
      IF @cDecodeDropIDSP <> ''   
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeDropIDSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeDropIDSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cPickSlipNo, ' +   
               ' @cDropID     OUTPUT, @cLOC        OUTPUT, @cID         OUTPUT, @cSKU        OUTPUT, @nQty        OUTPUT, ' +   
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,' +   
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,' +   
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,' +   
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile         INT, '            +  
               '@nFunc           INT, '            +  
               '@cLangCode       NVARCHAR( 3), '   +  
               '@nStep           INT, '            +   
               '@nInputKey       INT, '            +  
               '@cStorerKey      NVARCHAR( 15), '  +  
               '@cPickSlipNo     NVARCHAR( 10), '  +  
               '@cDropID         NVARCHAR(60)   OUTPUT, ' +  
               '@cLOC            NVARCHAR(10)   OUTPUT, ' +  
               '@cID             NVARCHAR(18)   OUTPUT, ' +  
               '@cSKU  NVARCHAR(20)   OUTPUT, ' +  
               '@nQty            INT            OUTPUT, ' +  
               '@cLottable01     NVARCHAR( 18)  OUTPUT, ' +   
               '@cLottable02     NVARCHAR( 18)  OUTPUT, ' +   
               '@cLottable03     NVARCHAR( 18)  OUTPUT, ' +   
               '@dLottable04     DATETIME       OUTPUT, ' +    
               '@dLottable05     DATETIME       OUTPUT, ' +    
               '@cLottable06     NVARCHAR( 30)  OUTPUT, ' +    
               '@cLottable07     NVARCHAR( 30)  OUTPUT, ' +    
               '@cLottable08     NVARCHAR( 30)  OUTPUT, ' +    
               '@cLottable09     NVARCHAR( 30)  OUTPUT, ' +    
               '@cLottable10     NVARCHAR( 30)  OUTPUT, ' +    
               '@cLottable11     NVARCHAR( 30)  OUTPUT, ' +    
               '@cLottable12     NVARCHAR( 30)  OUTPUT, ' +    
               '@dLottable13     DATETIME       OUTPUT, ' +    
               '@dLottable14     DATETIME       OUTPUT, ' +     
               '@dLottable15     DATETIME       OUTPUT, ' +     
               '@nErrNo          INT OUTPUT,    '         +  
               '@cErrMsg         NVARCHAR( 20) OUTPUT'    
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cPickSlipNo,  
               @cDropIDBarcode   OUTPUT, @cLOC        OUTPUT, @cID         OUTPUT, @cSKU        OUTPUT, @nQty        OUTPUT,   
               @cLottable01      OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,  
               @cLottable06      OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,  
               @cLottable11      OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,  
               @nErrNo           OUTPUT, @cErrMsg     OUTPUT  
  
            IF @nErrNo <> 0  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
               GOTO DropID_Fail  
            END  
  
            SET @cDropID = SUBSTRING( @cDropIDBarcode, 1, 20) -- Dropid only accept 20 chars  
         END  
      END  
  
      -- Check from id format (james02)  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'DROPID', @cDropID) = 0  
      BEGIN  
         SET @nErrNo = 116377  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO DropID_Fail  
      END  
  
            -- Extended validate  
      IF @cExtendedValidateSP <> '' --(yeekung01)  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) + ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer ' +  
               ',@cPickSlipNo    ' +  
               ',@cSuggestedLOC  ' +  
               ',@cLOC           ' +  
               ',@cID            ' +  
               ',@cDropID        ' +  
               ',@cSKU           ' +  
               ',@cLottable01    ' +  
               ',@cLottable02    ' +  
               ',@cLottable03    ' +  
               ',@dLottable04    ' +  
               ',@nTaskQTY       ' +  
               ',@nPQTY          ' +  
               ',@cUCC           ' +  
               ',@cOption        ' +  
               ',@nErrNo  OUTPUT ' +  
               ',@cErrMsg OUTPUT '  
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @nStep INT, @nInputKey INT, @cFacility NVARCHAR(5), @cStorer NVARCHAR(15)' +  
               ',@cPickSlipNo     NVARCHAR( 10)  ' +  
               ',@cSuggestedLOC   NVARCHAR( 10)  ' +  
               ',@cLOC            NVARCHAR( 10)  ' +  
               ',@cID             NVARCHAR( 18)  ' +  
               ',@cDropID         NVARCHAR( 20)  ' +  
            ',@cSKU            NVARCHAR( 20)  ' +  
               ',@cLottable01     NVARCHAR( 18)  ' +  
               ',@cLottable02     NVARCHAR( 18)  ' +  
               ',@cLottable03     NVARCHAR( 18)  ' +  
               ',@dLottable04     DATETIME       ' +  
               ',@nTaskQTY        INT            ' +  
               ',@nPQTY           INT            ' +  
               ',@cUCC            NVARCHAR( 20)  ' +  
               ',@cOption         NVARCHAR( 1)   ' +  
               ',@nErrNo          INT OUTPUT     ' +  
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer  
               ,@cPickSlipNo  
               ,@cSuggestedLOC  
               ,@cLOC  
               ,@cID  
               ,@cDropID  
               ,@cSKU  
               ,@cLottable1  
               ,@cLottable2  
               ,@cLottable3  
               ,@dLottable4  
               ,@nTaskQTY  
               ,@nPQTY  
               ,@cUCC  
               ,@cOption  
               ,@nErrNo  OUTPUT  
               ,@cErrMsg OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
      /*  
      IF @cDropID = 'NA'  
      BEGIN  
         --If picked quantity remained is less than full carton quantity  
         IF @nPQty <= @nPrefUOM_Div  
         BEGIN  
            SET @nErrNo = 116378  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Last Ctn  
            GOTO DropID_Fail  
         END  
  
         SET @nPickQty = @nPQTY  
         SET @nPQty = 0  
      END  
      ELSE  
      BEGIN  
         IF @cDropID = 'X'  
         BEGIN  
            SELECT @cSKUGroup = SKUGroup  
            FROM dbo.SKU WITH (NOLOCK)   
            WHERE StorerKey = @cStorer  
            AND   SKU = @cSKU  
  
            IF EXISTS ( SELECT 1 FROM dbo.CODElKUP WITH (NOLOCK)   
                        WHERE StorerKey = @cStorer  
                        AND   ListName = 'DROPIDREQ'  
                        AND   Code = @cSKUGroup  
                        AND   Udf01 = 'Y')  
            BEGIN  
               SET @nErrNo = 116379  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pls Scan Ctn  
               GOTO DropID_Fail  
            END  
            ELSE  
           BEGIN  
               -- Key in X meaning pick all qty at once  
               SET @nPickQty = @nPQTY  
               SET @nPQty = 0  
            END  
         END  
         ELSE  
         BEGIN  
            -- Key in carton barcode, set the qty = carton qty  
            SET @nPickQty = @nPrefUOM_Div  
            SET @nPQty = @nPQty - @nPrefUOM_Div  
         END  
      END  
      */  
      --INSERT INTO TRACEINFO ( TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5) VALUES ('955', GETDATE(), @cDropID, @cPrefUOM, @cPrefQTY, @cMstQTY, @nPickQty)  
        
      IF @cDropID IN ('NA', 'X')  
      BEGIN  
         SET @nPickQty = @nPQTY  
         SET @nPQty = 0  
      END  
      ELSE  
      BEGIN  
         SET @nPickQty = @nPrefUOM_Div  
         SET @nPQty = @nPQty - @nPrefUOM_Div  
      END  
      INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2) VALUES ('955', GETDATE(), @nTaskQTY, @nPickQty)  
      IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')  
      BEGIN  
         EXEC RDT.rdt_Pick_ConfirmTask_Wrapper  
             @n_Mobile        = @nMobile  
            ,@n_Func          = @nFunc  
            ,@c_LangCode      = @cLangCode  
            ,@c_SPName        = @cPickConfirm_SP  
            ,@c_PickSlipNo    = @cPickSlipNo  
            ,@c_DropID        = @cDropID  
            ,@c_LOC           = @cLOC  
            ,@c_ID            = @cID  
            ,@c_Storerkey     = @cStorer  
            ,@c_SKU           = @cSKU  
            ,@c_UOM           = @cUOM  
            ,@c_Lottable1     = @cLottable1  
            ,@c_Lottable2     = @cLottable2  
            ,@c_Lottable3     = @cLottable3  
            ,@d_Lottable4     = @dLottable4  
            ,@n_TaskQTY       = @nTaskQTY  
            ,@n_PQTY          = @nPickQty  
            ,@c_UCCTask       = 'N'          -- Y = UCC, N = SKU/UPC  
            ,@c_PickType      = @cPickType  
            ,@b_Success       = @bSuccess    OUTPUT  
            ,@n_ErrNo         = @nErrNo      OUTPUT  
            ,@c_ErrMsg        = @cErrMsg     OUTPUT  
      END  
      ELSE  
      BEGIN  
         -- Confirm task  
         EXECUTE rdt.rdt_Pick_ConfirmTask @nErrNo OUTPUT, @cErrMsg OUTPUT, @cLangCode,  
            @cPickSlipNo,  
            @cDropID,  
            @cLOC,  
            @cID,  
            @cStorer,  
            @cSKU,  
            @cUOM,  
            @cLottable1,   
            @cLottable2,  
            @cLottable3,  
            @dLottable4,  
            @nTaskQTY,  
            @nPickQty,  
            'N', -- Y = UCC, N = SKU/UPC  
            @cPickType,  --SOS93811  
            @nMobile -- (ChewKP01)  
      END  
  
      IF @nErrNo <> 0  
      BEGIN  
         IF @cDropID IN ('NA', 'X')  
         BEGIN  
            SET @nPQty = @nPickQty  
         END  
         ELSE  
         BEGIN  
            SET @nPQty = @nPQty + @nPrefUOM_Div  
         END  
  
         GOTO DropID_Fail  
      END  
      SET @nTaskQTY = @nTaskQTY - @nPickQty  
  
      IF @nPQty = 0  
      BEGIN  
         -- Get next task in current LOC  
         EXECUTE rdt.rdt_Pick_GetTaskInLOC @cStorer, @cPickSlipNo, @cLOC, @cPrefUOM, @cPickType, @cDropID,  
            @cID             OUTPUT,  
            @cSKU            OUTPUT,  
            @cUOM            OUTPUT,  
            @cLottable1      OUTPUT,  
            @cLottable2      OUTPUT,  
            @cLottable3      OUTPUT,  
            @dLottable4      OUTPUT,  
            @nTaskQTY        OUTPUT,  
            @nTask           OUTPUT,  
            @cSKUDescr       OUTPUT,  
            @cUOMDesc        OUTPUT,  
            @cPPK            OUTPUT,  
            @nCaseCnt        OUTPUT,  
            @cPrefUOM_Desc   OUTPUT,  
            @nPrefQTY        OUTPUT,  
            @cMstUOM_Desc    OUTPUT,  
            @nMstQTY         OUTPUT  
  
         IF @nTask = 0  
         BEGIN  
            -- Check if the display suggested loc turned on  
            IF @cPickShowSuggestedLOC <> '0'  
            BEGIN  
               -- If turned on then check whether there is another loc to pick  
               -- Get suggested loc  
               SET @nErrNo = 0  
               SET @cGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'PickGetSuggestedLoc_SP', @cStorer)  
               IF ISNULL(@cGetSuggestedLoc_SP, '') NOT IN ('', '0')  
               BEGIN  
                  EXEC RDT.RDT_GetSuggestedLoc_Wrapper  
                      @n_Mobile        = @nMobile  
                     ,@n_Func          = @nFunc  
                     ,@c_LangCode      = @cLangCode  
                     ,@c_SPName        = @cGetSuggestedLoc_SP  
                     ,@c_Storerkey     = @cStorer  
                     ,@c_OrderKey      = ''  
                     ,@c_PickSlipNo    = @cPickSlipNo  
                     ,@c_SKU           = ''  
                     ,@c_FromLoc       = @cLOC  
                     ,@c_FromID        = ''  
                     ,@c_oFieled01     = @c_oFieled01    OUTPUT  
                     ,@c_oFieled02     = @c_oFieled02    OUTPUT  
                     ,@c_oFieled03     = @c_oFieled03    OUTPUT  
                     ,@c_oFieled04     = @c_oFieled04    OUTPUT  
                     ,@c_oFieled05     = @c_oFieled05    OUTPUT  
                     ,@c_oFieled06     = @c_oFieled06    OUTPUT  
                 ,@c_oFieled07     = @c_oFieled07    OUTPUT  
                     ,@c_oFieled08     = @c_oFieled08    OUTPUT  
                     ,@c_oFieled09     = @c_oFieled09    OUTPUT  
                     ,@c_oFieled10     = @c_oFieled10    OUTPUT  
                     ,@c_oFieled11     = @c_oFieled11    OUTPUT  
                     ,@c_oFieled12     = @c_oFieled12    OUTPUT  
                     ,@c_oFieled13     = @c_oFieled13    OUTPUT  
                     ,@c_oFieled14     = @c_oFieled14    OUTPUT  
                     ,@c_oFieled15     = @c_oFieled15    OUTPUT  
                     ,@b_Success       = @b_Success      OUTPUT  
                     ,@n_ErrNo         = @nErrNo         OUTPUT  
                     ,@c_ErrMsg        = @cErrMsg        OUTPUT  
               END  
  
               -- Nothing to pick for the pickslip, goto display summary  
               IF ISNULL(@c_oFieled01, '') = ''  
               BEGIN  
                  -- No need display error message if nothing to pick anymore  
                  SET @cErrMsg = ''  
                  SET @cOutField01 = '' -- PickSlipNo  
  
                  -- Go to PickSlipNo screen  
                  SET @nScn = @nScn_PickSlipNo  
                  SET @nStep = @nStep_PickSlipNo  
  
                  GOTO Quit  
               END  
  
               SET @cSuggestedLOC = @c_oFieled01  
               SET @cDropID = ''
               
               -- Prepare LOC screen var  
               SET @cOutField01 = @cPickSlipNo  
               SET @cOutField02 = @cSuggestedLOC  
               SET @cOutField03 = '' -- LOC  
               SET @cOutField04 = '' -- DropID  
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
  
               -- Go to LOC screen  
               SET @nScn = @nScn_LOC  
               SET @nStep = @nStep_LOC  
            END  
            ELSE  
            BEGIN  
               SET @cOutField01 = @cLOC  
               -- Go to screen 'No more task in LOC'  
               SET @nScn = @nScn_NoMoreTask  
               SET @nStep = @nStep_NoMoreTask  
            END  
  
            GOTO Quit  
         END  
         ELSE  
         BEGIN  
            -- Go to SKU screen  
            SET @cOutField01 = @cLOC  
            SET @cOutField02 = @cID  
            SET @cOutField03 = @cSKU  
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
            SET @cOutField06 = @cLottable2  
            SET @cOutField07 = @cLottable3  
            SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
            SET @cOutField09 = '' -- SKU/UPC  
            SET @cOutField10 = @cLottable1  
  
            -- Go to SKU screen  
            SET @nScn = @nScn_SKU  
            SET @nStep = @nStep_SKU  
  
            GOTO Quit  
         END  
      END  
        
      DECLARE @nCntScanned INT, @nCnt2Scanned INT--, @nCaseCnt INT  
      SELECT @nCaseCnt = PACK.CASECNT   
      FROM PACK PACK WITH (NOLOCK)  
      JOIN SKU SKU WITH (NOLOCK) ON PACK.PACKKEY = SKU.PACKKEY  
      WHERE SKU.STORERKEY = @cStorer  
      AND   SKU.SKU = @cSKU  
  
      SELECT @nCntScanned = ISNULL( SUM( PD.QTY), 0)/@nCaseCnt  
      FROM dbo.PickHeader PH (NOLOCK)     
         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
      WHERE PH.PickHeaderKey = @cPickSlipNo    
         AND PD.Status = '5' -- Picked    
         AND PD.LOC = @cLOC    
         AND PD.ID = @cID    
         AND PD.SKU = @cSKU    
         AND PD.UOM = @cUOM    
         AND LA.Lottable01 = @cLottable1  
         AND LA.Lottable02 = @cLottable2  
         AND LA.Lottable03 = @cLottable3  
         AND IsNULL( @dLottable4, 0) = IsNULL( LA.Lottable04, 0)  
  
      SELECT @nCnt2Scanned = ISNULL( SUM( PD.QTY), 0)/@nCaseCnt  
      FROM dbo.PickHeader PH (NOLOCK)     
         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
      WHERE PH.PickHeaderKey = @cPickSlipNo    
         AND PD.Status < '9' -- Not yet shipped    
         AND PD.LOC = @cLOC    
         AND PD.ID = @cID    
         AND PD.SKU = @cSKU    
         AND PD.UOM = @cUOM    
         AND LA.Lottable01 = @cLottable1  
         AND LA.Lottable02 = @cLottable2    
         AND LA.Lottable03 = @cLottable3    
         AND IsNULL( @dLottable4, 0) = IsNULL( LA.Lottable04, 0)  
  
      --SET @cOutField01 = CAST( @nDropID_Cnt AS NVARCHAR( 3)) + '/' + CAST (( @nPrefQty - 1) AS NVARCHAR( 3))  
      SET @cOutField01 = CAST( @nCntScanned AS NVARCHAR( 3)) + '/' + CAST (@nCnt2Scanned AS NVARCHAR( 3))  
      SET @cOutField02 = ''  
  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
         -- Get 1st task in current LOC  
      SET @cID = ''  
      SET @cSKU = ''  
      SET @cUOM = ''  
      SET @cLottable1 = ''  
      SET @cLottable2 = ''  
      SET @cLottable3 = ''  
      SET @dLottable4 = 0 -- 1900-01-01  
  
      -- Get next task  
      SET @nErrNo = 0  
      SET @cPickGetTaskInLOC_SP = rdt.RDTGetConfig( @nFunc, 'PickGetTaskInLOC_SP', @cStorer)  
      IF ISNULL(@cPickGetTaskInLOC_SP, '') NOT IN ('', '0')  
      BEGIN  
         EXEC RDT.RDT_PickGetTaskInLOC_Wrapper  
             @n_Mobile        = @nMobile  
            ,@n_Func          = @nFunc  
            ,@c_LangCode      = @cLangCode  
            ,@c_SPName        = @cPickGetTaskInLOC_SP  
            ,@c_StorerKey     = @cStorer  
            ,@c_PickSlipNo    = @cPickSlipNo  
            ,@c_LOC           = @cLOC  
            ,@c_PrefUOM       = @cPrefUOM  
            ,@c_PickType      = @cPickType  
            ,@c_DropID        = @cDropID  
            ,@c_ID            = @cID            OUTPUT  
            ,@c_SKU           = @cSKU           OUTPUT  
            ,@c_UOM           = @cUOM           OUTPUT  
            ,@c_Lottable1     = @cLottable1     OUTPUT  
            ,@c_Lottable2     = @cLottable2     OUTPUT  
            ,@c_Lottable3     = @cLottable3     OUTPUT  
            ,@d_Lottable4     = @dLottable4     OUTPUT  
            ,@c_SKUDescr      = @cSKUDescr      OUTPUT  
            ,@c_oFieled01     = @c_oFieled01    OUTPUT  
            ,@c_oFieled02     = @c_oFieled02    OUTPUT  
            ,@c_oFieled03     = @c_oFieled03    OUTPUT  
            ,@c_oFieled04     = @c_oFieled04    OUTPUT  
            ,@c_oFieled05     = @c_oFieled05    OUTPUT  
            ,@c_oFieled06     = @c_oFieled06    OUTPUT  
            ,@c_oFieled07     = @c_oFieled07    OUTPUT  
            ,@c_oFieled08     = @c_oFieled08    OUTPUT  
            ,@c_oFieled09     = @c_oFieled09    OUTPUT  
            ,@c_oFieled10     = @c_oFieled10    OUTPUT  
            ,@c_oFieled11     = @c_oFieled11    OUTPUT  
            ,@c_oFieled12     = @c_oFieled12    OUTPUT  
            ,@c_oFieled13     = @c_oFieled13    OUTPUT  
            ,@c_oFieled14     = @c_oFieled14    OUTPUT  
            ,@c_oFieled15     = @c_oFieled15    OUTPUT  
            ,@b_Success       = @bSuccess       OUTPUT  
            ,@n_ErrNo         = @nErrNo         OUTPUT  
            ,@c_ErrMsg        = @cErrMsg        OUTPUT  
  
            SET @nTaskQTY     = CAST(@c_oFieled01 AS INT)  
            SET @nTask        = CAST(@c_oFieled02 AS INT)  
            SET @cUOMDesc     = @c_oFieled03  
            SET @cPPK         = @c_oFieled04  
  SET @nCaseCnt     = CAST(@c_oFieled05 AS INT)  
            SET @cPrefUOM_Desc= @c_oFieled06  
            SET @nPrefQTY     = CAST(@c_oFieled07 AS INT)  
            SET @cMstUOM_Desc = @c_oFieled08  
            SET @nMstQTY      = CAST(@c_oFieled09 AS INT)  
       SET @nPrefUOM_Div = CAST(@c_oFieled10 AS INT)  
      END  
      ELSE  
      BEGIN  
         EXECUTE rdt.rdt_Pick_GetTaskInLOC @cStorer, @cPickSlipNo, @cLOC, @cPrefUOM, @cPickType, @cDropID,  
            @cID             OUTPUT,  
            @cSKU            OUTPUT,  
            @cUOM            OUTPUT,  
            @cLottable1      OUTPUT,  
            @cLottable2      OUTPUT,  
            @cLottable3      OUTPUT,  
            @dLottable4      OUTPUT,  
            @nTaskQTY        OUTPUT,  
            @nTask           OUTPUT,  
            @cSKUDescr       OUTPUT,  
            @cUOMDesc        OUTPUT,  
            @cPPK            OUTPUT,  
            @nCaseCnt        OUTPUT,  
            @cPrefUOM_Desc   OUTPUT,  
            @nPrefQTY        OUTPUT,  
            @cMstUOM_Desc    OUTPUT,  
            @nMstQTY         OUTPUT  
      END  
  
      IF @nTask = 0  
      BEGIN  
         -- No need display error message if nothing to pick anymore  
         SET @cErrMsg = ''  
         SET @cOutField01 = '' -- PickSlipNo  
  
         -- Go to PickSlipNo screen  
         SET @nScn = @nScn_PickSlipNo  
         SET @nStep = @nStep_PickSlipNo  
  
         GOTO Quit  
      END  
  
      -- Goto SKU screen  
      SET @nActPQty = 0   
      SET @nActMQty = 0   
  
      -- Prepare SKU screen var  
      SET @cOutField01 = @cLOC  
      SET @cOutField02 = @cID  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
      SET @cOutField06 = @cLottable2  
      SET @cOutField07 = @cLottable3  
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
      SET @cOutField09 = '' -- SKU/UPC  
      SET @cOutField10 = @cLottable1  
  
      -- Goto SKU screen  
      SET @nScn = @nScn_SKU  
      SET @nStep = @nStep_SKU  
  
      -- Extended Info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) + ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorer ' +  
               ',@cPickSlipNo    ' +  
               ',@cSuggestedLOC  ' +  
               ',@cLOC           ' +  
               ',@cID            ' +  
               ',@cDropID        ' + 
               ',@cSKU           ' +  
               ',@cLottable01    ' +  
               ',@cLottable02    ' +  
               ',@cLottable03    ' +  
               ',@dLottable04    ' +  
               ',@nTaskQTY       ' +  
               ',@nPQTY          ' +  
               ',@cUCC           ' +  
               ',@cOption        ' +  
               ',@cExtendedInfo  OUTPUT' +  
               ',@nErrNo         OUTPUT ' +  
               ',@cErrMsg        OUTPUT '  
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @nStep INT, @nAfterStep INT, @nInputKey INT, @cFacility NVARCHAR(5), @cStorer NVARCHAR(15)' +  
               ',@cPickSlipNo     NVARCHAR( 10) ' +  
               ',@cSuggestedLOC   NVARCHAR( 10) ' +  
               ',@cLOC            NVARCHAR( 10) ' +  
               ',@cID             NVARCHAR( 18) ' +  
               ',@cDropID         NVARCHAR( 20) ' +  
               ',@cSKU            NVARCHAR( 20) ' +  
               ',@cLottable01     NVARCHAR( 18) ' +  
               ',@cLottable02     NVARCHAR( 18) ' +  
               ',@cLottable03     NVARCHAR( 18) ' +  
               ',@dLottable04     DATETIME      ' +  
               ',@nTaskQTY        INT           ' +  
               ',@nPQTY           INT           ' +  
               ',@cUCC            NVARCHAR( 20) ' +  
               ',@cOption         NVARCHAR( 1)  ' +  
   ',@cExtendedInfo   NVARCHAR( 20) OUTPUT' +  
               ',@nErrNo          INT           OUTPUT' +  
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep_LOC, @nStep, @nInputKey, @cFacility, @cStorer  
               ,@cPickSlipNo  
               ,@cSuggestedLOC  
               ,@cLOC  
               ,@cID  
               ,@cDropID  
               ,@cSKU  
               ,@cLottable1  
               ,@cLottable2  
               ,@cLottable3  
               ,@dLottable4  
               ,@nTaskQTY  
               ,@nPQTY  
               ,@cUCC  
               ,@cOption  
               ,@cExtendedInfo OUTPUT  
               ,@nErrNo        OUTPUT  
               ,@cErrMsg       OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  
                 
            SET @cOutField01 = @cExtendedInfo  
         END  
      END  
  
   END  
   GOTO Quit  
  
   DropID_Fail:  
   BEGIN  
      SET @cOutField02 = ''  
      SET @cDropID = ''  
   END  
END  
GOTO Quit  
  
/***********************************************************************************  
Scn = 5055. Message 'Skip Current Task?'  
************************************************************************************/  
Step_SkipTask:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      -- Validate blank  
      IF ISNULL( @cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 62670  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required  
         GOTO SkipTask_Option_Fail  
      END  
  
      -- Validate option  
      IF (@cOption <> '1' AND @cOption <> '2')  
      BEGIN  
         SET @nErrNo = 62671  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option  
         GOTO SkipTask_Option_Fail  
      END  
  
      IF @cOption = '1'  -- Yes  
      BEGIN  
         -- Get next task  
         SET @nErrNo = 0  
         SET @cPickGetTaskInLOC_SP = rdt.RDTGetConfig( @nFunc, 'PickGetTaskInLOC_SP', @cStorer)  
         IF ISNULL(@cPickGetTaskInLOC_SP, '') NOT IN ('', '0')  
         BEGIN  
            EXEC RDT.RDT_PickGetTaskInLOC_Wrapper  
                @n_Mobile        = @nMobile  
               ,@n_Func          = @nFunc  
               ,@c_LangCode      = @cLangCode  
               ,@c_SPName        = @cPickGetTaskInLOC_SP  
               ,@c_StorerKey     = @cStorer  
               ,@c_PickSlipNo    = @cPickSlipNo  
               ,@c_LOC           = @cLOC  
               ,@c_PrefUOM       = @cPrefUOM  
               ,@c_PickType      = @cPickType  
               ,@c_DropID        = @cDropID  
               ,@c_ID            = @cID            OUTPUT  
               ,@c_SKU           = @cSKU           OUTPUT  
               ,@c_UOM           = @cUOM           OUTPUT  
               ,@c_Lottable1     = @cLottable1     OUTPUT  
               ,@c_Lottable2     = @cLottable2     OUTPUT  
               ,@c_Lottable3     = @cLottable3     OUTPUT  
               ,@d_Lottable4     = @dLottable4     OUTPUT  
               ,@c_SKUDescr      = @cSKUDescr      OUTPUT  
               ,@c_oFieled01     = @c_oFieled01    OUTPUT  
               ,@c_oFieled02     = @c_oFieled02    OUTPUT  
               ,@c_oFieled03     = @c_oFieled03    OUTPUT  
               ,@c_oFieled04     = @c_oFieled04    OUTPUT  
               ,@c_oFieled05     = @c_oFieled05    OUTPUT  
               ,@c_oFieled06     = @c_oFieled06    OUTPUT  
               ,@c_oFieled07     = @c_oFieled07    OUTPUT  
               ,@c_oFieled08     = @c_oFieled08    OUTPUT  
               ,@c_oFieled09     = @c_oFieled09    OUTPUT  
               ,@c_oFieled10     = @c_oFieled10    OUTPUT  
               ,@c_oFieled11     = @c_oFieled11    OUTPUT  
               ,@c_oFieled12     = @c_oFieled12    OUTPUT  
               ,@c_oFieled13     = @c_oFieled13   OUTPUT  
               ,@c_oFieled14     = @c_oFieled14    OUTPUT  
               ,@c_oFieled15     = @c_oFieled15    OUTPUT  
               ,@b_Success       = @bSuccess       OUTPUT  
               ,@n_ErrNo         = @nErrNo         OUTPUT  
               ,@c_ErrMsg        = @cErrMsg        OUTPUT  
  
               SET @nTaskQTY     = CAST(@c_oFieled01 AS INT)  
               SET @nTask        = CAST(@c_oFieled02 AS INT)  
               SET @cUOMDesc     = @c_oFieled03  
               SET @cPPK         = @c_oFieled04  
               SET @nCaseCnt     = CAST(@c_oFieled05 AS INT)  
               SET @cPrefUOM_Desc= @c_oFieled06  
               SET @nPrefQTY     = CAST(@c_oFieled07 AS INT)  
               SET @cMstUOM_Desc = @c_oFieled08  
               SET @nMstQTY      = CAST(@c_oFieled09 AS INT)  
               SET @nPrefUOM_Div = CAST(@c_oFieled10 AS INT)  
         END  
         ELSE  
         BEGIN  
            -- Get next task in current LOC  
            EXECUTE rdt.rdt_Pick_GetTaskInLOC @cStorer, @cPickSlipNo, @cLOC, @cPrefUOM, @cPickType, @cDropID,  
               @cID             OUTPUT,  
               @cSKU            OUTPUT,  
               @cUOM            OUTPUT,  
               @cLottable1      OUTPUT,  
               @cLottable2      OUTPUT,  
               @cLottable3      OUTPUT,  
               @dLottable4      OUTPUT,  
               @nTaskQTY        OUTPUT,  
               @nTask           OUTPUT,  
               @cSKUDescr       OUTPUT,  
               @cUOMDesc        OUTPUT,  
               @cPPK            OUTPUT,  
               @nCaseCnt        OUTPUT,  
               @cPrefUOM_Desc   OUTPUT,  
               @nPrefQTY        OUTPUT,  
               @cMstUOM_Desc    OUTPUT,  
               @nMstQTY         OUTPUT  
         END  
  
         IF @nTask = 0  
         BEGIN  
            -- Check if the display suggested loc turned on  
            IF @cPickShowSuggestedLOC <> '0'  
            BEGIN  
               -- If turned on then check whether there is another loc to pick  
               -- Get suggested loc  
               SET @nErrNo = 0  
               SET @cGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'PickGetSuggestedLoc_SP', @cStorer)  
               IF ISNULL(@cGetSuggestedLoc_SP, '') NOT IN ('', '0')  
               BEGIN  
             EXEC RDT.RDT_GetSuggestedLoc_Wrapper  
                      @n_Mobile        = @nMobile  
                     ,@n_Func          = @nFunc  
                     ,@c_LangCode      = @cLangCode  
                     ,@c_SPName        = @cGetSuggestedLoc_SP  
                     ,@c_Storerkey     = @cStorer  
                     ,@c_OrderKey      = ''  
                     ,@c_PickSlipNo    = @cPickSlipNo  
                     ,@c_SKU           = ''  
                     ,@c_FromLoc       = @cLOC  
                     ,@c_FromID        = ''  
                     ,@c_oFieled01     = @c_oFieled01    OUTPUT  
                     ,@c_oFieled02     = @c_oFieled02    OUTPUT  
                     ,@c_oFieled03     = @c_oFieled03    OUTPUT  
                     ,@c_oFieled04     = @c_oFieled04    OUTPUT  
                     ,@c_oFieled05     = @c_oFieled05    OUTPUT  
                     ,@c_oFieled06     = @c_oFieled06    OUTPUT  
                     ,@c_oFieled07     = @c_oFieled07    OUTPUT  
                     ,@c_oFieled08     = @c_oFieled08    OUTPUT  
                     ,@c_oFieled09     = @c_oFieled09    OUTPUT  
                     ,@c_oFieled10     = @c_oFieled10    OUTPUT  
                     ,@c_oFieled11     = @c_oFieled11    OUTPUT  
                     ,@c_oFieled12     = @c_oFieled12    OUTPUT  
                     ,@c_oFieled13     = @c_oFieled13    OUTPUT  
     ,@c_oFieled14     = @c_oFieled14    OUTPUT  
                     ,@c_oFieled15     = @c_oFieled15    OUTPUT  
                     ,@b_Success       = @b_Success      OUTPUT  
                     ,@n_ErrNo         = @nErrNo         OUTPUT  
                     ,@c_ErrMsg     = @cErrMsg        OUTPUT  
               END  
  
               -- Nothing to pick for the pickslip, goto display summary  
               IF ISNULL(@c_oFieled01, '') = ''  
               BEGIN  
                  -- No need display error message if nothing to pick anymore  
                  SET @cErrMsg = ''  
                  SET @cOutField01 = '' -- PickSlipNo  
  
                  -- Go to PickSlipNo screen  
                  SET @nScn = @nScn_PickSlipNo  
                  SET @nStep = @nStep_PickSlipNo  
                  GOTO Quit  
               END  
  
               SET @cSuggestedLOC = @c_oFieled01  
  
               -- Prepare LOC screen var  
               SET @cOutField01 = @cPickSlipNo  
               SET @cOutField02 = @cSuggestedLOC  
               SET @cOutField03 = '' -- LOC  
               SET @cOutField04 = '' -- DropID  
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
  
               -- Go to LOC screen  
               SET @nScn = @nScn_LOC  
               SET @nStep = @nStep_LOC  
            END  
            ELSE  
            BEGIN  
               -- Prepare No more task screen var  
               SET @cOutField01 = @cLOC  
  
               -- Go to LOC screen  
               SET @nScn = @nScn_NoMoreTask  
               SET @nStep = @nStep_NoMoreTask  
               GOTO Quit  
            END  
         END  
         ELSE  
         BEGIN  
            -- Remain in current screen but need to reset QTY counter  
            IF @cParentScn = 'UCC'  
            BEGIN  
               SET @nPUCC = 0  
               SET @nPQTY = 0  
               SET @nTaskUCC = CASE WHEN @nCaseCnt = 0 THEN 0 ELSE @nTaskQTY / @nCaseCnt END  
            END  
         END  
      END  
   END  
  
   -- ESC or No  
  
   -- Back to SKU screen  
   IF @cParentScn = 'SKU'  
   BEGIN  
      -- Prepare SKU screen var  
      SET @cOutField01 = @cLOC  
      SET @cOutField02 = @cID  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
      SET @cOutField06 = @cLottable2  
SET @cOutField07 = @cLottable3  
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
      SET @cOutField09 = '' -- SKU/UPC  
      SET @cOutField10 = @cLottable1  
  
      -- Go to SKU screen  
      SET @nScn = @nScn_SKU  
      SET @nStep = @nStep_SKU  
   END  
  
   GOTO Quit  
  
   SkipTask_Option_Fail:  
   BEGIN  
      SET @cOutField01 = '' -- Option  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 5056. Message. 'Confirm Short Pick?'  
   Option (field01)  
********************************************************************************/  
Step_ShortPick:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      -- Validate blank  
      IF ISNULL( @cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 116382  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required  
         GOTO ShortPick_Option_Fail  
      END  
  
      -- Validate option  
      IF (@cOption <> '1' AND @cOption <> '2')  
      BEGIN  
         SET @nErrNo = 116382  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option  
         GOTO ShortPick_Option_Fail  
      END  
  
      IF @cOption = '1'  -- Yes  
      BEGIN  
         DECLARE @cUCCTask NVARCHAR( 1)  
         SET @cUCCTask = CASE WHEN @cParentScn = 'UCC' THEN 'Y' ELSE 'N' END  
  
         -- Confirm Task  
         IF ISNULL(@cPickConfirm_SP, '') NOT IN ('', '0')  
         BEGIN  
            EXEC RDT.rdt_Pick_ConfirmTask_Wrapper  
                @n_Mobile        = @nMobile  
               ,@n_Func          = @nFunc  
               ,@c_LangCode      = @cLangCode  
               ,@c_SPName        = @cPickConfirm_SP  
               ,@c_PickSlipNo    = @cPickSlipNo  
               ,@c_DropID        = @cDropID  
               ,@c_LOC    = @cLOC  
               ,@c_ID            = @cID  
               ,@c_Storerkey     = @cStorer  
               ,@c_SKU           = @cSKU  
               ,@c_UOM           = @cUOM  
               ,@c_Lottable1     = @cLottable1  
               ,@c_Lottable2     = @cLottable2  
               ,@c_Lottable3     = @cLottable3  
               ,@d_Lottable4     = @dLottable4  
               ,@n_TaskQTY       = @nTaskQTY  
               ,@n_PQTY          = @nPQTY  
               ,@c_UCCTask       = 'N'          -- Y = UCC, N = SKU/UPC  
               ,@c_PickType      = @cPickType  
               ,@b_Success       = @bSuccess    OUTPUT  
               ,@n_ErrNo         = @nErrNo      OUTPUT  
               ,@c_ErrMsg        = @cErrMsg     OUTPUT  
         END  
         ELSE  
         BEGIN  
            EXECUTE rdt.rdt_Pick_ConfirmTask @nErrNo OUTPUT, @cErrMsg OUTPUT, @cLangCode,  
               @cPickSlipNo,  
               @cDropID,  
               @cLOC,  
               @cID,  
               @cStorer,  
               @cSKU,  
               @cUOM,  
               @cLottable1,   
               @cLottable2,  
               @cLottable3,  
               @dLottable4,  
               @nTaskQTY,  
               @nPQTY,  
               @cUCCTask,  -- Y = UCC, N = SKU/UPC  
               @cPickType,  
               @nMobile  
         END  
         IF @nErrNo <> 0  
            GOTO Quit  
  
         IF @cParentScn = 'UCC'  
         BEGIN  
            -- Delete RDTTempUCC  
            DELETE RDT.RDTTempUCC WITH (ROWLOCK)  
            WHERE TaskType = 'PICK'  
               AND PickSlipNo = @cPickSlipNo  
               AND StorerKey = @cStorer  
               AND SKU = @cSKU  
               AND LOC = @cLOC  
               AND Lottable01 = @cLottable1  
               AND Lottable02 = @cLottable2  
               AND Lottable03 = @cLottable3  
               AND Lottable04 = @dLottable4  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 62674  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Del UCC fail'  
               GOTO ShortPick_Option_Fail  
            END  
         END  
  
         -- Get task in current LOC  
         EXECUTE rdt.rdt_Pick_GetTaskInLOC @cStorer, @cPickSlipNo, @cLOC, @cPrefUOM, @cPickType, @cDropID,  
            @cID             OUTPUT,  
            @cSKU            OUTPUT,  
            @cUOM            OUTPUT,  
            @cLottable1      OUTPUT,  
            @cLottable2      OUTPUT,  
            @cLottable3      OUTPUT,  
            @dLottable4      OUTPUT,  
            @nTaskQTY        OUTPUT,  
            @nTask           OUTPUT,  
            @cSKUDescr       OUTPUT,  
            @cUOMDesc        OUTPUT,  
            @cPPK            OUTPUT,  
            @nCaseCnt        OUTPUT,  
            @cPrefUOM_Desc   OUTPUT,  
            @nPrefQTY        OUTPUT,  
            @cMstUOM_Desc    OUTPUT,  
            @nMstQTY         OUTPUT  
  
         IF @nTask = 0  
         BEGIN  
            -- Check if the display suggested loc turned on  
            IF @cPickShowSuggestedLOC <> '0'  
            BEGIN  
               -- If turned on then check whether there is another loc to pick  
               -- Get suggested loc  
               SET @nErrNo = 0  
               SET @cGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'PickGetSuggestedLoc_SP', @cStorer)  
               IF ISNULL(@cGetSuggestedLoc_SP, '') NOT IN ('', '0')  
               BEGIN  
                  EXEC RDT.RDT_GetSuggestedLoc_Wrapper  
                      @n_Mobile        = @nMobile  
                     ,@n_Func          = @nFunc  
                     ,@c_LangCode      = @cLangCode  
                     ,@c_SPName        = @cGetSuggestedLoc_SP  
                     ,@c_Storerkey     = @cStorer  
                     ,@c_OrderKey      = ''  
                     ,@c_PickSlipNo    = @cPickSlipNo  
                     ,@c_SKU           = ''  
                     ,@c_FromLoc       = @cLOC  
                     ,@c_FromID        = ''  
                     ,@c_oFieled01     = @c_oFieled01    OUTPUT  
                     ,@c_oFieled02     = @c_oFieled02    OUTPUT  
                     ,@c_oFieled03     = @c_oFieled03    OUTPUT  
                     ,@c_oFieled04     = @c_oFieled04    OUTPUT  
                     ,@c_oFieled05     = @c_oFieled05    OUTPUT  
                     ,@c_oFieled06     = @c_oFieled06    OUTPUT  
                     ,@c_oFieled07     = @c_oFieled07    OUTPUT  
                     ,@c_oFieled08     = @c_oFieled08    OUTPUT  
                     ,@c_oFieled09     = @c_oFieled09    OUTPUT  
                     ,@c_oFieled10     = @c_oFieled10    OUTPUT  
                     ,@c_oFieled11     = @c_oFieled11    OUTPUT  
                     ,@c_oFieled12     = @c_oFieled12    OUTPUT  
                     ,@c_oFieled13     = @c_oFieled13    OUTPUT  
                     ,@c_oFieled14     = @c_oFieled14    OUTPUT  
                     ,@c_oFieled15     = @c_oFieled15    OUTPUT  
                     ,@b_Success       = @b_Success      OUTPUT  
                     ,@n_ErrNo         = @nErrNo         OUTPUT  
                     ,@c_ErrMsg        = @cErrMsg        OUTPUT  
               END  
  
               -- Nothing to pick for the pickslip, goto display summary  
               IF ISNULL(@c_oFieled01, '') = ''  
               BEGIN  
                  -- No need display error message if nothing to pick anymore  
                  SET @cErrMsg = ''  
                  SET @cOutField01 = '' -- PickSlipNo  
  
                  -- Go to PickSlipNo screen  
                  SET @nScn = @nScn_PickSlipNo  
                  SET @nStep = @nStep_PickSlipNo  
                  GOTO Quit  
               END  
  
      SET @cSuggestedLOC = @c_oFieled01  
  
               -- Prepare LOC screen var  
               SET @cOutField01 = @cPickSlipNo  
               SET @cOutField02 = @cSuggestedLOC  
               SET @cOutField03 = '' -- LOC  
               SET @cOutField04 = '' -- DropID  
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
  
               -- Go to LOC screen  
               SET @nScn = @nScn_LOC  
               SET @nStep = @nStep_LOC  
            END  
            ELSE  
            BEGIN  
               -- Prepare No more task screen var  
               SET @cOutField01 = @cLOC  
  
               -- Go to LOC screen  
               SET @nScn = @nScn_NoMoreTask  
               SET @nStep = @nStep_NoMoreTask  
            END  
  
            GOTO Quit  
         END  
         ELSE  
         BEGIN  
            -- Back to SKU screen  
            IF @cParentScn = 'QTY'  
               SET @cParentScn = 'SKU'  
  
            -- Remain in current screen but need to reset QTY counter  
            IF @cParentScn = 'UCC'  
            BEGIN  
               SET @nPUCC = 0  
               SET @nPQTY = 0  
               SET @nTaskUCC = CASE WHEN @nCaseCnt = 0 THEN 0 ELSE @nTaskQTY / @nCaseCnt END  
            END  
         END  
      END  
   END  
  
   -- ESC or No  
  
   -- Back to SKU screen  
   IF @cParentScn = 'SKU'  
   BEGIN  
      -- Prepare SKU screen var  
SET @cOutField01 = @cLOC  
      SET @cOutField02 = @cID  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
      SET @cOutField06 = @cLottable2  
      SET @cOutField07 = @cLottable3  
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
      SET @cOutField09 = '' -- SKU/UPC  
      SET @cOutField10 = @cLottable1  
  
      -- Go to SKU screen  
      SET @nScn = @nScn_SKU  
      SET @nStep = @nStep_SKU  
   END  
  
   -- Back to QTY screen  
   IF @cParentScn = 'QTY'  
   BEGIN  
      -- Prep QTY screen var  
      --SET @cOutField01 = @cLOC  
      SET @cOutField02 = @cID  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
      SET @cOutField06 = @cLottable2  
      SET @cOutField07 = @cLottable3  
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
      SET @cOutField09 = @cPPK  
      IF @cPrefUOM_Desc = ''  
      BEGIN  
         SET @cOutField10 = '' -- @cPrefUOM_Desc  
         SET @cOutField11 = '' -- @nPrefQTY  
         -- Disable pref QTY field  
         SET @cFieldAttr14 = 'O' -- (Vicky02)  
      END  
      ELSE  
      BEGIN  
         SET @cOutField10 = @cPrefUOM_Desc  
         SET @cOutField11 = CAST( @nPrefQTY AS NVARCHAR( 5))  
      END  
      SET @cOutField12 = @cMstUOM_Desc  
      SET @cOutField13 = @nMstQTY  
      SET @cOutField14 = '' -- @nPrefQTY  
      SET @cOutField15 = '' -- @nMstQTY  
      SET @cOutField01 = @cLottable1  
  
      -- Go to QTY screen  
      SET @nScn = @nScn_QTY  
      SET @nStep = @nStep_QTY  
   END  
  
   GOTO Quit  
  
   ShortPick_Option_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cOption = ''  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 5057. Message. 'No more task in LOC ....'  
********************************************************************************/  
Step_NoMoreTask:  
BEGIN  
   -- Prepare LOC screen var  
   SET @cOutField01 = @cPickSlipNo  
   SET @cOutField02 = @cSuggestedLOC  
   SET @cOutField03 = '' -- LOC  
   SET @cOutField04 = '' -- DropID  
   EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
     
   EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC  
  
  -- Back to LOC screen  
   SET @nScn = @nScn_LOC  
   SET @nStep = @nStep_LOC  
END  
GOTO Quit  
  
/********************************************************************************  
Scn = 5058. Message. 'LOC NOT MATCH'  
   Option (field01)  
********************************************************************************/  
Step_ConfirmLOC:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      -- Validate blank  
      IF ISNULL( @cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 116384  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required  
         GOTO Step_ConfirmLOC_Fail  
      END  
  
      -- Validate option  
      IF (@cOption <> '1' AND @cOption <> '2')  
      BEGIN  
         SET @nErrNo = 116385  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option  
         GOTO Step_ConfirmLOC_Fail  
      END  
  
      IF @cOption = '1' -- Yes  
      BEGIN  
         GOTO Continue_GetTask  
      END  
  
      IF @cOption = '2' -- Yes  
      BEGIN  
         -- Prepare LOC screen var  
         SET @cOutField01 = @cPickSlipNo  
         SET @cOutField02 = @cSuggestedLOC  
         SET @cOutField03 = '' -- LOC  
         SET @cOutField04 = @cDropID  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
           
         -- Go to LOC screen  
      SET @nScn = @nScn_LOC  
         SET @nStep = @nStep_LOC  
      END  
   END  
  
   -- ESC or No  
   IF @nInputKey = 1 -- NO  
   BEGIN  
      -- Prepare LOC screen var  
      SET @cOutField01 = @cPickSlipNo  
      SET @cOutField02 = @cSuggestedLOC  
      SET @cOutField02 = '' -- LOC  
      SET @cOutField04 = @cDropID  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC  
  
      -- Go to LOC screen  
      SET @nScn = @nScn_LOC  
      SET @nStep = @nStep_LOC  
   END  
   GOTO Quit  
  
   Step_ConfirmLOC_Fail:  
   BEGIN  
      SET @cOption = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************      
Step 10. Screen = 3570. Multi SKU      
   SKU         (Field01)      
   SKUDesc1    (Field02)      
   SKUDesc2   (Field03)      
   SKU         (Field04)      
   SKUDesc1    (Field05)      
   SKUDesc2    (Field06)      
   SKU         (Field07)      
   SKUDesc1    (Field08)      
   SKUDesc2    (Field09)      
   Option      (Field10, input)      
********************************************************************************/      
Step_MultiSKU:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,      
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,      
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,      
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,      
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,      
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,      
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,      
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,      
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,      
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,      
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,      
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,      
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,      
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,      
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,      
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,      
         'CHECK',      
         @cMultiSKUBarcode,      
         @cStorer,      
         @cUPC     OUTPUT,      
         @nErrNo   OUTPUT,      
         @cErrMsg  OUTPUT      
      
      IF @nErrNo <> 0      
      BEGIN      
         IF @nErrNo = -1      
            SET @nErrNo = 0      
      GOTO Quit      
      END      
      
      -- Get SKU info      
      SELECT @cSKUDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cUPC      
   END      
      
      -- Prepare SKU screen var  
      SET @cOutField01 = @cLOC  
      SET @cOutField02 = @cID  
      SET @cOutField03 = @cUPC  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2  
      SET @cOutField06 = @cLottable2  
      SET @cOutField07 = @cLottable3  
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)  
      SET @cOutField09 = @cUPC-- SKU/UPC  
      SET @cOutField10 = @cLottable1  
  
   EXEC rdt.rdtSetFocusField @nMobile, 9 -- SKU      
      
   -- Go to next screen      
   SET @nScn = @nScn_SKU      
   SET @nStep = @nStep_SKU      
      
END      
GOTO Quit      
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET  
      EditDate = GETDATE(),   
      ErrMsg = @cErrMsg,  
      Func   = @nFunc,  
      Step   = @nStep,  
      Scn    = @nScn,  
  
      StorerKey      = @cStorer,  
      Facility       = @cFacility,  
  
      V_PickSlipNo   = @cPickSlipNo,  
      V_LOC          = @cLOC,  
      V_ID           = @cID,  
      V_SKU          = @cSKU,  
      V_SKUDescr     = @cSKUDescr,  
      V_UOM          = @cUOM,  
      V_QTY          = @cQTY,  
      V_UCC          = @cUCC,  
      V_Lottable01   = @cLottable1,  
      V_Lottable02   = @cLottable2,  
      V_Lottable03   = @cLottable3,  
      V_Lottable04   = @dLottable4,  
        
      V_PQTY     = @nPQTY,  
      V_PTaskQty = @nTaskQTY,  
        
      V_Integer1  = @nPUCC,  
      V_Integer2  = @nTaskUCC,  
      V_Integer3  = @nCaseCnt,  
      V_Integer4  = @nPrefUOM_Div,  
      V_Integer5  = @nPrefQTY,  
      V_Integer6  = @nMstQTY,  
      V_Integer7  = @cPickShowSuggestedLOC,  
      V_Integer8  = @nActPQty,  
      V_Integer9  = @nActMQty,  
      V_Integer10 = @nDropID_Cnt,  
  
      --V_String1      = @nPQTY,  
      --V_String2      = @nPUCC,  
      --V_String3      = @nTaskQTY,  
      --V_String4      = @nTaskUCC,  
      --V_String5      = @nCaseCnt,  
  
      V_String6      = @cUOMDesc,  
      V_String7      = @cPPK,  
      V_String8      = @cParentScn,  
      V_String9      = @cDropID,  
  
      V_String10     = @cPrefUOM,      -- Pref UOM  
      V_String11     = @cPrefUOM_Desc, -- Pref UOM desc  
      V_String12     = @cMstUOM_Desc,  -- Master UOM desc  
      --V_String13     = @nPrefUOM_Div,  -- Pref UOM divider  
      --V_String14     = @nPrefQTY,   -- QTY in pref UOM  
      --V_String15     = @nMstQTY,       -- Remaining QTY in master unit  
      V_String16     = @cPickType,     -- S=SKU/UPC, U=UCC, P=Pallet  
      V_String18     = @cExternOrderKey,  
      V_String19     = @cSuggestedLOC,  
      --V_String20     = @cPickShowSuggestedLOC,  
      --V_String21     = @nActPQty,      -- (james05)  
      --V_String22     = @nActMQty,      -- (james05)  
      V_String23     = @cExtendedValidateSP,  
      V_String24     = @cExtendedInfoSP,   
      V_String25     = @cExtendedInfo,   
      V_String27     = @cDecodeSP,  
      --V_String28     = @nDropID_Cnt,  
      V_String29     = @cPickConfirm_SP,  
      V_String30     = @cAutoScanIn,  
      V_String31     = @cMultiSKUBarcode,  
      V_String32     = @cFlowThruStepSP,
  
      I_Field01 = '',  O_Field01 = @cOutField01,  
      I_Field02 = '',  O_Field02 = @cOutField02,  
      I_Field03 = '',  O_Field03 = @cOutField03,  
      I_Field04 = '',  O_Field04 = @cOutField04,  
      I_Field05 = '',  O_Field05 = @cOutField05,  
      I_Field06 = '',  O_Field06 = @cOutField06,  
      I_Field07 = '',  O_Field07 = @cOutField07,  
      I_Field08 = '',  O_Field08 = @cOutField08,  
      I_Field09 = '',  O_Field09 = @cOutField09,  
      I_Field10 = '',  O_Field10 = @cOutField10,  
      I_Field11 = '',  O_Field11 = @cOutField11,  
      I_Field12 = '',  O_Field12 = @cOutField12,  
      I_Field13 = '',  O_Field13 = @cOutField13,  
      I_Field14 = '',  O_Field14 = @cOutField14,  
      I_Field15 = '',  O_Field15 = @cOutField15,  
  
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