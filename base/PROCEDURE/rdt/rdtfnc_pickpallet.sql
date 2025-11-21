SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PickPallet                                         */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Picking: dynamic lottable                                         */
/*          1. SKU/UPC                                                        */
/*          2. UCC                                                            */
/*          3. Pallet                                                         */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-06-14   1.0  Chermaine  WMS-17140 Created (dup rdtfnc_Pick)           */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PickPallet] (
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
   @nLOC_Count             INT,            
   @nORD_Count             INT,            
   @nSKU_Count             INT,            
   @nCurActPQty            INT,            
   @nCurActMQty            INT,            
   @cDefaultLOC            NVARCHAR( 10),  
   @cTempOrderKey          NVARCHAR( 10),  
   @cPickGetTaskInLOC_SP   NVARCHAR( 20),  
   @cSQL                   NVARCHAR( MAX),
   @cSQLParam              NVARCHAR( MAX),
   @cBarcode               NVARCHAR( 60),
   @cUPC                   NVARCHAR( 30),
   @cFunctionKey           NVARCHAR( 3),  
   @cInID                  NVARCHAR( 20),
   @nFunctionKey           INT,     
   @nMorePage              INT, 

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

   @cStorerKey     NVARCHAR( 15),
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
   @cLottableCode  NVARCHAR( 20),

   @nPQTY                  INT,           -- Picked QTY
   @nPUCC                  INT,           -- Picked UCC
   @nTaskQTY               INT,           -- QTY of the task
   @nTaskUCC               INT,           -- No of UCC in the task
   @nCaseCnt               INT,
   @nFromScn               INT, 
   @nFromStep              INT, 
   @cUOMDesc               NVARCHAR( 3),
   @cPPK                   NVARCHAR( 5),
   @cParentScn             NVARCHAR( 3),
   @cDropID                NVARCHAR( 60),
   @cPrefUOM               NVARCHAR( 1),  -- Pref UOM
   @cPrefUOM_Desc          NVARCHAR( 5),  -- Pref UOM desc
   @cMstUOM_Desc           NVARCHAR( 5),  -- Master UOM desc
   @nPrefUOM_Div           INT,           -- Pref UOM divider
   @nPrefQTY               INT,           -- QTY in pref UOM
   @nMstQTY                INT,           -- Remaining QTY in master unit
   @cPickType              NVARCHAR( 1),  -- S=SKU/UPC, U=UCC, P=Pallet
   @cPrintPalletManifest   NVARCHAR( 1),  -- store configkey 'PrintPalletManifest' value
   @cExternOrderKey        NVARCHAR( 20), -- packheader.externorderkey = loadplan.loadkey??
   @cSuggestedLOC          NVARCHAR(10),  
   @cPickShowSuggestedLOC  NVARCHAR(1),   
   @nActPQty               INT,          
   @nActMQty               INT,           
   @cExtendedValidateSP    NVARCHAR(20),
   @cExtendedInfoSP        NVARCHAR(20),
   @cExtendedInfo          NVARCHAR(20),
   @cSwapIDSP              NVARCHAR(20),
   @cDecodeDropIDSP        NVARCHAR(20),
   @nQty                   INT,
   @cDecodeSP              NVARCHAR( 20),

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
   @cDropIDBarcode         NVARCHAR( 60),
   @cPickDontShowLot02     NVARCHAR( 20),
   @cDefaultToPickQty      INT,
   @cAutoScanIn            NVARCHAR( 1),
   @cPalletOp              Nvarchar( 1),
   @cPalletType            Nvarchar( 5),

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

   @cStorerKey       = StorerKey,
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
   @cLottable01      = V_Lottable01,    
   @cLottable02      = V_Lottable02,    
   @cLottable03      = V_Lottable03,    
   @dLottable04      = V_Lottable04,    
   @dLottable05      = V_Lottable05,    
   @cLottable06      = V_Lottable06,    
   @cLottable07      = V_Lottable07,    
   @cLottable08      = V_Lottable08,    
   @cLottable09      = V_Lottable09,    
   @cLottable10      = V_Lottable10,    
   @cLottable11      = V_Lottable11,    
   @cLottable12      = V_Lottable12,    
   @dLottable13      = V_Lottable13,    
   @dLottable14      = V_Lottable14,    
   @dLottable15      = V_Lottable15,
   @nFromScn         = V_FromScn,
   @nFromStep        = V_FromStep,

   @nPQTY            = V_Integer1,
   @nPUCC            = V_Integer2,
   @nTaskQTY         = V_Integer3,
   @nTaskUCC         = V_Integer4,
   @nCaseCnt         = V_Integer5,
   @nPrefUOM_Div     = V_Integer6,
   @nPrefQTY         = V_Integer7,
   @nMstQTY          = V_Integer8,
   @nActPQty         = V_Integer9,
   @nActMQty         = V_Integer10,
   @nFunctionKey     = V_Integer11,

   @cAutoScanIn           = V_String1,
   @cLottableCode         = V_String2,
   @cFunctionKey          = V_String3,
   @cPalletOp             = V_String4,
   @cPalletType           = V_String5,
   @cUOMDesc              = V_String6,
   @cPPK                  = V_String7,
   @cParentScn            = V_String8,
   @cDropID               = V_String9,
   @cPrefUOM              = V_String10, -- Pref UOM
   @cPrefUOM_Desc         = V_String11, -- Pref UOM desc
   @cMstUOM_Desc          = V_String12, -- Master UOM desc
   @cPickType             = V_String16,
   @cPrintPalletManifest  = V_String17,
   @cExternOrderKey       = V_String18,
   @cSuggestedLOC         = V_String19,
   @cPickShowSuggestedLOC = V_String20,
   @cExtendedValidateSP   = V_String23,
   @cExtendedInfoSP       = V_String24,
   @cExtendedInfo         = V_String25,
   @cSwapIDSP             = V_String26,
   @cDecodeSP             = V_String27,
   @cPickDontShowLot02    = V_String28,
   @cDefaultToPickQty     = V_String29,  
   @cBarcode              = V_String41,

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
   @nStep_PickSlipNo       INT,  @nScn_PickSlipNo     INT,
   @nStep_LOC              INT,  @nScn_LOC            INT,
   @nStep_SKU              INT,  @nScn_SKU            INT,
   @nStep_QTY              INT,  @nScn_QTY            INT,
   @nStep_UCC              INT,  @nScn_UCC            INT,
   @nStep_ID               INT,  @nScn_ID             INT,
   @nStep_SkipTask         INT,  @nScn_SkipTask       INT,
   @nStep_ShortPick        INT,  @nScn_ShortPick      INT,
   @nStep_NoMoreTask       INT,  @nScn_NoMoreTask     INT,
   @nStep_PalletType       INT,  @nScn_PalletType     INT,
   @nStep_ConfirmLoc       INT,  @nScn_ConfirmLoc     INT,
   @nStep_Summary          INT,  @nScn_Summary        INT,
   @nStep_VerifyLottable   INT,  @nScn_VerifyLottable INT 

SELECT
   @nStep_PickSlipNo       = 1,  @nScn_PickSlipNo     = 5910,--831,
   @nStep_LOC              = 2,  @nScn_LOC            = 5911,--832,
   @nStep_ID               = 3,  @nScn_ID             = 5912,--836,
   @nStep_SkipTask         = 4,  @nScn_SkipTask       = 5913,--837,
   @nStep_NoMoreTask       = 5,  @nScn_NoMoreTask     = 5914,--839,
   @nStep_PalletType       = 6,  @nScn_PalletType     = 5915,--840,
   @nStep_ConfirmLoc       = 7,  @nScn_ConfirmLoc     = 5916,--842,
   @nStep_Summary          = 8,  @nScn_Summary        = 5917,--843
   @nStep_VerifyLottable   = 9,  @nScn_VerifyLottable = 3990  

IF @nFunc = 1854 
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 1854 
   IF @nStep = 1  GOTO Step_PickSlipNo       -- Scn = 5910 (831). PickSlipNo
   IF @nStep = 2  GOTO Step_LOC              -- Scn = 5911 (832). LOC, DropID
   IF @nStep = 3  GOTO Step_ID               -- Scn = 5912 (836). ID
   IF @nStep = 4  GOTO Step_SkipTask         -- Scn = 5913 (837). Message. 'Skip Current Task?'
   IF @nStep = 5  GOTO Step_NoMoreTask       -- Scn = 5914 (839). Message. 'No more task in LOC'
   IF @nStep = 6  GOTO Step_PalletType       -- Scn = 5915 (840). Message. Full/partial Pallet Option
   IF @nStep = 7  GOTO Step_ConfirmLoc       -- Scn = 5916 (842). Message. 'LOC not match?'
   IF @nStep = 8  GOTO Step_Summary          -- Scn = 5917 (843). Message. 'Summary'
   --IF @nStep = 9  GOTO Step_VerifyLottable   -- Scn = 3990. Verify lottable      
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1854 
********************************************************************************/
Step_Start:
BEGIN
   -- Get prefer UOM
   SELECT @cPrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Get StorerConfig 'UCC'
   DECLARE @cUCCStorerConfig NVARCHAR( 1)
   SELECT @cUCCStorerConfig = SValue
   FROM dbo.StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ConfigKey = 'UCC'

   -- Get RDT storer configure
   SET @cPrintPalletManifest = ''
   SET @cPrintPalletManifest = rdt.RDTGetConfig( 0, 'PrintPalletManifest', @cStorerKey)
   SET @cPickShowSuggestedLOC = ''
   SET @cPickShowSuggestedLOC = rdt.RDTGetConfig( @nFunc, 'PickShowSuggestedLOC', @cStorerKey)
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cSwapIDSP = rdt.rdtGetConfig( @nFunc, 'SwapIDSP', @cStorerKey)
   IF @cSwapIDSP = '0'
      SET @cSwapIDSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   --SET @cPickDontShowLot02 = rdt.RDTGetConfig( @nFunc, 'PickDontShowLot02', @cStorerKey)   

   SET @cDefaultToPickQty = rdt.RDTGetConfig( @nFunc, 'DefaultToPickQty', @cStorerKey)   

   SET @cAutoScanIn = rdt.rdtGetConfig( @nFunc, 'AutoScanIn', @cStorerKey)

   Set @cPalletOp = rdt.rdtGetConfig( @nFunc, 'PalletOp', @cStorerKey)
   
   SET @cFunctionKey = rdt.RDTGetConfig( @nFunc, 'FunctionKey', @cStorerKey)
   IF @cFunctionKey IN ( '11', '12', '13', '14')
      SELECT @nFunctionKey = RDT.rdtGetFuncKey(@cFunctionKey)
   ELSE
      SET @nFunctionKey = -1  -- Set to some other value than 1 = ENTER; 0 = ESC
      
   -- Set pick type
   SET @cPickType = 'P'
      --CASE @nFunc
      --   WHEN 1854 THEN 'S' -- SKU/UPC --860
      --   WHEN 1855 THEN 'U' -- UCC --861
      --   WHEN 1856 THEN 'P' -- Pallet --862
      --   WHEN 1857 THEN 'D' -- Pick By Drop ID --863
      --END

   -- Check if pick pallet in ucc warehouse
   IF @cUCCStorerConfig = '1'
   BEGIN
      SET @nErrNo = 169151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- CantPickUCC PL
      GOTO Step_Start_Fail
   END

    -- EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerKey

   -- Prepare PickSlipNo screen var
   SET @cOutField01 = '' -- PickSlipNo

   -- Start
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
   -- (Vicky02) - End

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
Scn 1 = 5910 (831). PickSlipNo screen
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
         SET @nErrNo = 169152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PSNO required
         GOTO PickSlipNo_Fail
      END

      DECLARE @cChkStorerKey  NVARCHAR( 15)
      DECLARE @cOrderKey      NVARCHAR( 10)
      DECLARE @nCnt           INT
      DECLARE @dScanInDate    DATETIME
      DECLARE @dScanOutDate   DATETIME

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
         SET @nErrNo = 169153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid PSNO
         GOTO PickSlipNo_Fail
      END

      If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' -- OR ISNULL(@cZone, '') = '7'
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
            SET @nErrNo = 169154
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped
            GOTO PickSlipNo_Fail
         END

         -- Check diff storer
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.PickHeader PickHeader WITH (NOLOCK)
               JOIN dbo.RefKeyLookup RefKeyLookup WITH (NOLOCK) ON (PickHeader.PickHeaderKey = RefKeyLookup.PickSlipNo)
               JOIN dbo.Orders Orders WITH (NOLOCK) ON (RefKeyLookup.Orderkey = ORDERS.Orderkey)
            WHERE PickHeader.PickHeaderKey = @cPickSlipNo
              AND Orders.StorerKey <> @cStorerKey
              AND PickHeader.Zone IN ('XD', 'LB', 'LP'))
         BEGIN
            SET @nErrNo = 169155
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO PickSlipNo_Fail
         END
      END
      ELSE
      BEGIN
         IF ISNULL(@cOrderKey, '') <> ''
         BEGIN
            -- Get Order info
            DECLARE @cChkStatus NVARCHAR( 10)
            SELECT
               @cChkStorerKey = StorerKey,
               @cChkStatus = Status
            FROM dbo.Orders WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            -- Check order shipped
            IF @cChkStatus = '9'
            BEGIN
               SET @nErrNo = 169156
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped
               GOTO PickSlipNo_Fail
            END

            -- Check storer
            IF @cChkStorerKey IS NULL OR @cChkStorerKey = '' OR @cChkStorerKey <> @cStorerKey
            BEGIN
               SET @nErrNo = 169157
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
               SET @nErrNo = 169158
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped
               GOTO PickSlipNo_Fail
            END

            -- Check diff storer
            IF EXISTS( SELECT TOP 1 1
               FROM dbo.PickHeader PH (NOLOCK)
                  INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
                  INNER JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
               WHERE PH.PickHeaderKey = @cPickSlipNo
                  AND O.StorerKey <> @cStorerKey)
            BEGIN
               SET @nErrNo = 169159
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
                  SET @nErrNo = 169160
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                  GOTO PickSlipNo_Fail
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
                  SET @nErrNo = 169161
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                  GOTO PickSlipNo_Fail
               END
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 169162
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS not scan in
            GOTO PickSlipNo_Fail
         END
      END

      -- Validate pickslip already scan out
      IF @dScanOutDate IS NOT NULL
      BEGIN
         SET @nErrNo = 169163
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
         SET @cGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'PickGetSuggestedLoc_SP', @cStorerKey)
         IF ISNULL(@cGetSuggestedLoc_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.RDT_GetSuggestedLoc_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cGetSuggestedLoc_SP
               ,@c_Storerkey     = @cStorerKey
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
      
      --IF @cPalletOp = '1'
      --BEGIN
      --   -- Prepare LOC screen var
      --   SET @cOutField01 = '' --option

      --   -- Go to Pallet Type Option screen
      --   SET @nScn = @nScn_PalletType
      --   SET @nStep = @nStep_PalletType
      --   GOTO Quit
      --END

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

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option

      -- (Vicky02) - Start
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
   END
   GOTO Quit

   PickSlipNo_Fail:
   BEGIN
      SET @cOutField01 = '' -- PSNO
   END
END
GOTO Quit


/***********************************************************************************
Scn 2 = 5911 (832). LOC screen
   PSNO   (field01)
   LOC    (field02, input)
   DropID (field03, input)
***********************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField03 -- LOC
      SET @cDropID = LEFT( @cInField04, 20) -- DropID
      SET @cDropIDBarcode = @cInField04 -- DropID

      -- SET @cSuggestedLOC = @cOutField05 -- suggested loc  

      -- Validate blank
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @nErrNo = 169164
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC needed'
         GOTO LOC_Fail
      END

      -- Get LOC info
      DECLARE @cChkFacility NVARCHAR( 5)
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 169165
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO LOC_Fail
      END

      -- Validate facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 169166
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO LOC_Fail
      END
      SET @cOutField03 = @cLOC

      -- Decode label
      --SET @cDecodeDropIDSP = rdt.RDTGetConfig( @nFunc, 'DecodeDropIDSP', @cStorerKey)
      --IF @cDecodeDropIDSP = '0'
      --   SET @cDecodeDropIDSP = ''

      -- Extended update
      --IF @cDecodeDropIDSP <> ''
      IF @cDecodeSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cBarcode, @cPickSlipNo, ' +
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
               '@cBarcode        NVARCHAR( 60), '  +
               '@cPickSlipNo     NVARCHAR( 10), '  +
               '@cDropID         NVARCHAR(60)   OUTPUT, ' +
               '@cLOC            NVARCHAR(10)   OUTPUT, ' +
               '@cID             NVARCHAR(18)   OUTPUT, ' +
               '@cSKU            NVARCHAR(20)   OUTPUT, ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cPickSlipNo,
               @cDropIDBarcode   OUTPUT, @cLOC        OUTPUT, @cID         OUTPUT, @cSKU        OUTPUT, @nQty        OUTPUT,
               @cLottable01      OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06      OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11      OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo           OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               SET @cDropID = ''
               GOTO LOC_Fail
            END

            SET @cDropID = SUBSTRING( @cDropIDBarcode, 1, 20) -- Dropid only accept 20 chars
         END
      END

      -- Check from id format 
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0
      BEGIN
         SET @nErrNo = 169167
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO DropID_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) + ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey ' +
               ',@cPickSlipNo    ' +
               ',@cSuggestedLOC  ' +
               ',@cLOC           ' +
               ',@cID            ' +
               ',@cDropID        ' +
               ',@cSKU           ' +
               ',@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05 ' +    
               ',@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10 ' +    
               ',@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15 ' +   
               ',@nTaskQTY       ' +
               ',@nPQTY          ' +
               ',@cUCC           ' +
               ',@cOption        ' +
               ',@nErrNo  OUTPUT ' +
               ',@cErrMsg OUTPUT '
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @nStep INT, @nInputKey INT, @cFacility NVARCHAR(5), @cStorerKey NVARCHAR(15)' +
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
               ',@dLottable05     DATETIME      ' +    
               ',@cLottable06     NVARCHAR( 30)  ' +    
               ',@cLottable07     NVARCHAR( 30)  ' +    
               ',@cLottable08     NVARCHAR( 30)  ' +    
               ',@cLottable09     NVARCHAR( 30)  ' +    
               ',@cLottable10     NVARCHAR( 30)  ' +    
               ',@cLottable11     NVARCHAR( 30)  ' +    
               ',@cLottable12     NVARCHAR( 30)  ' +    
               ',@dLottable13     DATETIME       ' +    
               ',@dLottable14     DATETIME       ' +    
               ',@dLottable15     DATETIME       ' +  
               ',@nTaskQTY        INT            ' +
               ',@nPQTY           INT            ' +
               ',@cUCC            NVARCHAR( 20)  ' +
               ',@cOption         NVARCHAR( 1)   ' +
               ',@nErrNo          INT OUTPUT     ' +
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cPickSlipNo
               ,@cSuggestedLOC
               ,@cLOC
               ,@cID
               ,@cDropID
               ,@cSKU
               ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05   
               ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10    
               ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15 
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
    
      -- If show suggested loc config turn on and loc not match suggested loc 
      IF @cPickShowSuggestedLOC <> '0' AND (@cLOC <> @cSuggestedLOC)
      BEGIN
         -- If cannot overwrite suggested loc, prompt error
         IF @cPickShowSuggestedLOC = '1'
         BEGIN
            SET @nErrNo = 169168
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Loc'
            GOTO LOC_Fail
         END

         -- If can overwrite but need confirm loc then goto confirm loc screen
         IF @cPickShowSuggestedLOC = '2'
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = ''

            SET @nScn = @nScn_ConfirmLoc
            SET @nStep = @nStep_ConfirmLoc

            GOTO Quit
         END
      END
      
      IF @cPalletOp = '1'
      BEGIN
         -- Prepare LOC screen var
         SET @cOutField01 = '' --option

         -- Go to Pallet Type Option screen
         SET @nScn = @nScn_PalletType
         SET @nStep = @nStep_PalletType
         GOTO Quit
      END

      Continue_GetTask:
      -- Get 1st task in current LOC
      SELECT  @cID = '', @cSKU = '', @cUOM = '', 
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,    
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',    
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL   

      -- Get next task
      EXECUTE rdt.rdt_PickPallet_GetTaskInLOC @cStorerKey, @cPickSlipNo, @cLOC, @cPrefUOM, @cPickType, @cDropID,
         @cID             OUTPUT,
         @cSKU            OUTPUT,
         @cUOM            OUTPUT,
         @cLottable01     OUTPUT,
         @cLottable02     OUTPUT,
         @cLottable03     OUTPUT,
         @dLottable04     OUTPUT,
         @dLottable05     OUTPUT,
         @cLottable06     OUTPUT,
         @cLottable07     OUTPUT,
         @cLottable08     OUTPUT,
         @cLottable09     OUTPUT,
         @cLottable10     OUTPUT,
         @cLottable11     OUTPUT,
         @cLottable12     OUTPUT,
         @dLottable13     OUTPUT,
         @dLottable14     OUTPUT,
         @dLottable15     OUTPUT,
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
         SET @nErrNo = 169169
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- No task in LOC
         GOTO LOC_Fail
      END
      
      SELECT 
         @cLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
      
      -- Dynamic lottable    
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 6,     
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,    
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,    
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,    
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,    
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,    
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,    
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,    
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,    
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,    
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,    
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,    
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,    
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,    
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,    
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,    
         @nMorePage   OUTPUT,    
         @nErrNo      OUTPUT,    
         @cErrMsg     OUTPUT,    
         '',      -- SourceKey    
         @nFunc   -- SourceType    
         
      -- Goto ID screen
      -- Prepare SKU screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      --SET @cOutField06 = CASE WHEN @cPickDontShowLot02 = '1' THEN '' ELSE @cLottable02 END
      --SET @cOutField07 = @cLottable3
      --SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)
      IF @cPrefUOM_Desc = ''
      BEGIN
         SET @cOutField10 = '' -- @cPrefUOM_Desc
         SET @cOutField11 = '' -- @nPrefQTY
      END
      ELSE
      BEGIN
         SET @cOutField10 = @cPrefUOM_Desc
         SET @cOutField11 = CAST( @nPrefQTY AS NVARCHAR( 5))
      END
      SET @cOutField12 = @cMstUOM_Desc
      SET @cOutField13 = @nMstQTY
      SET @cOutField14 = '' -- @nInID
      --SET @cOutField15 = @cLottable1

      -- Goto SKU screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
      
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) + ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey ' +
               ',@cPickSlipNo    ' +
               ',@cSuggestedLOC  ' +
               ',@cLOC           ' +
               ',@cID            ' +
               ',@cDropID        ' +
               ',@cSKU           ' +
               ',@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05 ' +    
               ',@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10 ' +    
               ',@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15 ' +   
               ',@nTaskQTY       ' +
               ',@nPQTY          ' +
               ',@cUCC           ' +
               ',@cOption        ' +
               ',@cExtendedInfo  OUTPUT' +
               ',@nErrNo         OUTPUT ' +
               ',@cErrMsg        OUTPUT '
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @nStep INT, @nAfterStep INT, @nInputKey INT, @cFacility NVARCHAR(5), @cStorerKey NVARCHAR(15)' +
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
               ',@dLottable05     DATETIME      ' +    
               ',@cLottable06     NVARCHAR( 30) ' +    
               ',@cLottable07     NVARCHAR( 30) ' +    
               ',@cLottable08     NVARCHAR( 30) ' +    
               ',@cLottable09     NVARCHAR( 30) ' +    
               ',@cLottable10     NVARCHAR( 30) ' +    
               ',@cLottable11     NVARCHAR( 30) ' +    
               ',@cLottable12     NVARCHAR( 30) ' +    
               ',@dLottable13     DATETIME      ' +    
               ',@dLottable14     DATETIME      ' +    
               ',@dLottable15     DATETIME     ' +  
               ',@nTaskQTY        INT           ' +
               ',@nPQTY           INT           ' +
               ',@cUCC            NVARCHAR( 20) ' +
               ',@cOption         NVARCHAR( 1)  ' +
               ',@cExtendedInfo   NVARCHAR( 20) OUTPUT' +
               ',@nErrNo          INT           OUTPUT' +
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep_LOC, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cPickSlipNo
               ,@cSuggestedLOC
               ,@cLOC
               ,@cID
               ,@cDropID
               ,@cSKU
               ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05   
               ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10    
               ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15 
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
      SET @nScn = @nScn_PickSlipNo
      SET @nStep = @nStep_PickSlipNo
   END
   GOTO Quit

   LOC_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField03 = '' -- LOC
      SET @cOutField04 = @cDropIDBarcode -- DropID
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
      GOTO Quit
   END

   DropID_Fail:
   BEGIN
      SET @cDropID = ''
      SET @cOutField03 = @cLOC
      SET @cOutField04 = '' -- DropID
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Scn 3 = 5912 (836). ID screen
   LOC       (field01)
   ID        (field02)
   SKU       (field03)
   DESCR     (field04, 05)
   LOTTABLE  (field06)
   LOTTABLE  (field07)
   LOTTABLE  (field08)
   LOTTABLE  (field09)
   PrefUOM   (field10)
   PrefQTY   (field11)
   MstUOM    (field12)
   MstQTY    (field13)
   InID      (field14, input)
********************************************************************************/
Step_ID:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      
      -- (Vicky02) - Start
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
      SET @cInID = @cInField14 -- ID
      SET @cBarcode = @cInField14 
      
      
      -- Skip task
      IF @cInID = '' OR @cInID IS NULL
      BEGIN
         -- Remember parent screen
         SET @cParentScn = 'ID'

         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Go to 'Skip Current Task?' screen
         SET @nScn = @nScn_SkipTask
         SET @nStep = @nStep_SkipTask

         GOTO Quit
      END 
      IF @cDecodeSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cBarcode, @cPickSlipNo, ' +
               ' @cDropID     OUTPUT, @cLOC        OUTPUT, @cID         OUTPUT, @cSKU        OUTPUT, @nTaskQTY    OUTPUT, ' +
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
               '@cBarcode        NVARCHAR( 60), '  +
               '@cPickSlipNo     NVARCHAR( 10), '  +
               '@cDropID         NVARCHAR(60)   OUTPUT, ' +
               '@cLOC            NVARCHAR(10)   OUTPUT, ' +
               '@cID             NVARCHAR(18)   OUTPUT, ' +
               '@cSKU            NVARCHAR(20)   OUTPUT, ' +
               '@nTaskQTY        INT            OUTPUT, ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cPickSlipNo,
               @cDropIDBarcode   OUTPUT, @cLOC        OUTPUT, @cID         OUTPUT, @cSKU        OUTPUT, @nTaskQTY    OUTPUT,
               @cLottable01      OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06      OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11      OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo           OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO ID_Fail
            END
         END
      END
            
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) + ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey ' +
               ',@cPickSlipNo    ' +
               ',@cSuggestedLOC  ' +
               ',@cLOC           ' +
               ',@cID            ' +
               ',@cDropID        ' +
               ',@cSKU           ' +
               ',@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05 ' +        
               ',@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10 ' +        
               ',@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15 ' +   
               ',@nTaskQTY       ' +
               ',@nPQTY          ' +
               ',@cUCC           ' +
               ',@cOption        ' +
               ',@nErrNo  OUTPUT ' +
               ',@cErrMsg OUTPUT '
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @nStep INT, @nInputKey INT, @cFacility NVARCHAR(5), @cStorerKey NVARCHAR(15)' +
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
               ',@dLottable05     DATETIME       ' +        
               ',@cLottable06     NVARCHAR( 30)  ' +        
               ',@cLottable07     NVARCHAR( 30)  ' +        
               ',@cLottable08     NVARCHAR( 30)  ' +        
               ',@cLottable09     NVARCHAR( 30)  ' +        
               ',@cLottable10     NVARCHAR( 30)  ' +        
               ',@cLottable11     NVARCHAR( 30)  ' +        
               ',@cLottable12     NVARCHAR( 30)  ' +        
               ',@dLottable13     DATETIME       ' +        
               ',@dLottable14     DATETIME       ' +        
               ',@dLottable15     DATETIME       ' +
               ',@nTaskQTY        INT            ' +
               ',@nPQTY           INT            ' +
               ',@cUCC            NVARCHAR( 20)  ' +
               ',@cOption         NVARCHAR( 1)   ' +
               ',@nErrNo          INT OUTPUT     ' +
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cPickSlipNo
               ,@cSuggestedLOC
               ,@cLOC
               ,@cID
               ,@cDropID
               ,@cSKU
               ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05  
               ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10    
               ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15   
               ,@nTaskQTY
               ,@nPQTY
               ,@cUCC
               ,@cOption
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO ID_Fail
         END
      END
         
      -- Validate ID
      --IF @cID <> @cInID
      --BEGIN
      -- Swap LOT and/or ID
      IF @cSwapIDSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSwapIDSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapIDSP) + ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility ' +
               ',@cPickSlipNo    ' +
               ',@cLOC           ' +
               ',@cDropID        ' +
               ',@cID     OUTPUT ' +
               ',@cInID          ' +
               ',@cSKU           ' +
               ',@cUOM           ' +
               ',@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05 ' +        
               ',@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10 ' +        
               ',@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15 ' +  
               ',@nTaskQTY       ' +
               ',@cActID         ' +
               ',@nErrNo  OUTPUT ' +
               ',@cErrMsg OUTPUT '
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @cStorerKey NVARCHAR(15), @cFacility NVARCHAR(5) ' +
               ',@cPickSlipNo     NVARCHAR( 10)  ' +
               ',@cLOC            NVARCHAR( 10)  ' +
               ',@cDropID         NVARCHAR( 20)  ' +
               ',@cID             NVARCHAR( 18) OUTPUT  ' +
               ',@cInID           NVARCHAR( 18)  ' +
               ',@cSKU            NVARCHAR( 20)  ' +
               ',@cUOM            NVARCHAR( 10)  ' +
               ',@cLottable01     NVARCHAR( 18)  ' +        
               ',@cLottable02     NVARCHAR( 18)  ' +        
               ',@cLottable03     NVARCHAR( 18)  ' +        
               ',@dLottable04     DATETIME       ' +        
               ',@dLottable05     DATETIME       ' +        
               ',@cLottable06     NVARCHAR( 30)  ' +        
               ',@cLottable07     NVARCHAR( 30)  ' +        
               ',@cLottable08     NVARCHAR( 30)  ' +        
               ',@cLottable09     NVARCHAR( 30)  ' +        
               ',@cLottable10     NVARCHAR( 30)  ' +       
               ',@cLottable11     NVARCHAR( 30)  ' +        
               ',@cLottable12     NVARCHAR( 30)  ' +       
               ',@dLottable13     DATETIME       ' +        
               ',@dLottable14     DATETIME       ' +        
               ',@dLottable15     DATETIME       ' +
               ',@nTaskQTY        INT            ' +
               ',@cActID          NVARCHAR( 18)  ' +
               ',@nErrNo          INT OUTPUT     ' +
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility
               ,@cPickSlipNo
               ,@cLOC
               ,@cDropID
               ,@cID    OUTPUT
               ,@cInID
               ,@cSKU
               ,@cUOM
               ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05  
               ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10    
               ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15  
               ,@nTaskQTY
               ,@cID
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO ID_Fail
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 169170
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Wrong ID'
         GOTO ID_Fail
      END
      --END
      
      -- Confirm task
      SET @nPQTY = @nTaskQTY
      
      --GOTO ID_Fail
      EXECUTE rdt.rdt_PickPallet_ConfirmTask @nErrNo OUTPUT, @cErrMsg OUTPUT, @cLangCode, @cPickSlipNo, @cDropID, @cLOC, @cID, @cStorerKey, @cSKU, @cUOM,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,     
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,     
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            @nTaskQTY,
            @nPQTY,
            'N',  -- Y = UCC, N = SKU/UPC
            @cPickType,  
            @nMobile 

      IF @nErrNo <> 0
         GOTO Quit

      -- Get next task in current LOC
      EXECUTE rdt.rdt_PickPallet_GetTaskInLOC @cStorerKey, @cPickSlipNo, @cLOC, @cPrefUOM, @cPickType, @cDropID,
         @cID             OUTPUT,
         @cSKU            OUTPUT,
         @cUOM            OUTPUT,
         @cLottable01     OUTPUT,
         @cLottable02     OUTPUT,
         @cLottable03     OUTPUT,
         @dLottable04     OUTPUT,
         @dLottable05     OUTPUT,
         @cLottable06     OUTPUT,
         @cLottable07     OUTPUT,
         @cLottable08     OUTPUT,
         @cLottable09     OUTPUT,
         @cLottable10     OUTPUT,
         @cLottable11     OUTPUT,
         @cLottable12     OUTPUT,
         @dLottable13     OUTPUT,
         @dLottable14     OUTPUT,
         @dLottable15     OUTPUT,
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
   
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 6,     
            @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,    
            @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,    
            @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,    
            @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,    
            @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,    
            @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,    
            @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,    
            @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,    
            @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,    
            @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,    
            @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,    
            @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,    
            @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,    
            @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,    
            @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,    
            @nMorePage   OUTPUT,    
            @nErrNo      OUTPUT,    
            @cErrMsg     OUTPUT,    
            '',      -- SourceKey    
            @nFunc   -- SourceType    

      IF @nTask = 0
      BEGIN
         -- Check if the display suggested loc turned on
         IF @cPickShowSuggestedLOC <> '0'
         BEGIN
            -- If turned on then check whether there is another loc to pick
            -- Get suggested loc
            SET @nErrNo = 0
            SET @cGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'PickGetSuggestedLoc_SP', @cStorerKey)
            IF ISNULL(@cGetSuggestedLoc_SP, '') NOT IN ('', '0')
            BEGIN
               EXEC RDT.RDT_GetSuggestedLoc_Wrapper
                   @n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_LangCode      = @cLangCode
                  ,@c_SPName        = @cGetSuggestedLoc_SP
                  ,@c_Storerkey     = @cStorerKey
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
               SET @cErrMsg = ''

               -- Get pickheader info
               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cExternOrderKey = ExternOrderKey,
                  @cZone = Zone
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo

               SELECT @nLOC_Count = 0

               IF ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP'
               BEGIN
                  SELECT
                     @nLOC_Count = COUNT(DISTINCT PD.LOC),
                     @nORD_Count = COUNT(DISTINCT PD.OrderKey),
                     @nSKU_Count = COUNT(DISTINCT PD.SKU)
                  FROM dbo.PickDetail PD (NOLOCK)
                  JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
                  WHERE RPL.PickslipNo = @cPickSlipNo
                  AND   PD.Status = '0'
               END
               ELSE
               BEGIN
                  IF ISNULL(@cOrderKey, '') <> ''
                  BEGIN
                     SELECT
                        @nLOC_Count = COUNT(DISTINCT PD.LOC),
                        @nORD_Count = COUNT(DISTINCT PD.OrderKey),
                        @nSKU_Count = COUNT(DISTINCT PD.SKU)
                     FROM dbo.PickHeader PH WITH (NOLOCK)
                     JOIN dbo.PickDetail PD (NOLOCK) ON PH.OrderKey = PD.OrderKey
                     WHERE PH.PickHeaderKey = @cPickSlipNo
                     AND   PD.Status = '0'
                  END
                  ELSE
                  BEGIN
                     SELECT
                        @nLOC_Count = COUNT(DISTINCT PD.LOC),
                        @nORD_Count = COUNT(DISTINCT PD.OrderKey),
                        @nSKU_Count = COUNT(DISTINCT PD.SKU)
                     FROM dbo.PickHeader PH WITH (NOLOCK)
                     JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
                     JOIN dbo.PickDetail PD (NOLOCK) ON LPD.OrderKey = PD.OrderKey
                     WHERE PH.PickHeaderKey = @cPickSlipNo
                     AND   PD.Status = '0'
                  END
               END

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
               SET @cOutField11 = ''
               SET @cOutField12 = ''
               SET @cOutField13 = ''
               SET @cOutField14 = ''

               SET @cOutField01 = 'PS NO:' + @cPickSlipNo
               SET @cOutField03 = 'LOC NOT PICK: ' + CAST (@nLOC_Count AS NVARCHAR(5))
               SET @cOutField04 = 'ORD NOT PICK: ' + CAST (@nORD_Count AS NVARCHAR(5))
               SET @cOutField05 = 'SKU NOT PICK: ' + CAST (@nSKU_Count AS NVARCHAR(5))
               SET @cOutField10 = 'PRESS ENTER/ESC'
               SET @cOutField11 = 'TO CONTINUE'

               -- Go to picking summary screen
               SET @nScn = @nScn_Summary
               SET @nStep = @nStep_Summary
            END
            ELSE
            BEGIN
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
         END
         ELSE
         BEGIN
            SET @cOutField01 = @cLOC
            -- Go to screen 'No more task in LOC'
            SET @nScn = @nScn_NoMoreTask
            SET @nStep = @nStep_NoMoreTask
         END
      END
      ELSE
      BEGIN
         -- Refresh ID screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
         --SET @cOutField06 = CASE WHEN @cPickDontShowLot02 = '1' THEN '' ELSE @cLottable02 END
         --SET @cOutField07 = @cLottable03
         --SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
         IF @cPrefUOM_Desc = ''
         BEGIN
            SET @cOutField10 = '' -- @cPrefUOM_Desc
            SET @cOutField11 = '' -- @nPrefQTY
         END
         ELSE
         BEGIN
            SET @cOutField10 = @cPrefUOM_Desc
            SET @cOutField11 = CAST( @nPrefQTY AS NVARCHAR( 5))
         END
         SET @cOutField12 = @cMstUOM_Desc
         SET @cOutField13 = @nMstQTY
         SET @cOutField14 = '' -- @cInID
         SET @cOutField15 = @cLottable01
      END

      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) + ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey ' +
               ',@cPickSlipNo    ' +
               ',@cSuggestedLOC  ' +
               ',@cLOC           ' +
               ',@cID            ' +
               ',@cDropID        ' +
               ',@cSKU           ' +
               ',@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05 ' +    
               ',@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10 ' +    
               ',@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15 ' +   
               ',@nTaskQTY       ' +
               ',@nPQTY          ' +
               ',@cUCC           ' +
               ',@cOption        ' +
               ',@cExtendedInfo  OUTPUT ' +
               ',@nErrNo         OUTPUT ' +
               ',@cErrMsg        OUTPUT '
            SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @nStep INT, @nAfterStep INT, @nInputKey INT, @cFacility NVARCHAR(5), @cStorerKey NVARCHAR(15)' +
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
               ',@dLottable05     DATETIME      ' +    
               ',@cLottable06     NVARCHAR( 30) ' +    
               ',@cLottable07     NVARCHAR( 30) ' +    
               ',@cLottable08     NVARCHAR( 30) ' +    
               ',@cLottable09     NVARCHAR( 30) ' +    
               ',@cLottable10     NVARCHAR( 30) ' +    
               ',@cLottable11     NVARCHAR( 30) ' +    
               ',@cLottable12     NVARCHAR( 30) ' +    
               ',@dLottable13     DATETIME      ' +    
               ',@dLottable14     DATETIME      ' +    
               ',@dLottable15     DATETIME      ' +  
               ',@nTaskQTY        INT           ' +
               ',@nPQTY           INT           ' +
               ',@cUCC            NVARCHAR( 20) ' +
               ',@cOption         NVARCHAR( 1)  ' +
               ',@cExtendedInfo   NVARCHAR( 20) OUTPUT' +
               ',@nErrNo          INT           OUTPUT' +
               ',@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep_ID, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cPickSlipNo
               ,@cSuggestedLOC
               ,@cLOC
               ,@cID
               ,@cDropID
               ,@cSKU
               ,@cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05   
               ,@cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10    
               ,@cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15    
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
      --END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSuggestedLOC
      SET @cOutField03 = '' -- LOC
      SET @cOutField04 = '' -- DropID
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC

      -- Go to prev screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit
   
   IF @nFunctionKey <> -1
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 10, 1, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      IF @nErrNo <> 0  
         GOTO Quit  
      ELSE
      BEGIN  
         -- Go to dynamic lottable screen  
         SET @nFromScn = @nScn  
         SET @nFromStep = @nStep
         SET @nScn = @nScn + 6  
         SET @nStep = @nStep + 8  
         
         GOTO Quit
      END    
   END

   ID_Fail:
   BEGIN
      SET @cOutField14 = '' -- ID
   END
END
GOTO Quit

/***********************************************************************************
Step 4. Scn = 5913 (837). Message 'Skip Current Task?'
************************************************************************************/
Step_SkipTask:
BEGIN
   -- (Vicky02) - Start
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
   -- (Vicky02) - End

   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 169171
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required
         GOTO SkipTask_Option_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 169172
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
         GOTO SkipTask_Option_Fail
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         -- Get next task in current LOC
         EXECUTE rdt.rdt_PickPallet_GetTaskInLOC @cStorerKey, @cPickSlipNo, @cLOC, @cPrefUOM, @cPickType, @cDropID,
            @cID             OUTPUT,
            @cSKU            OUTPUT,
            @cUOM            OUTPUT,
            @cLottable01     OUTPUT,
            @cLottable02     OUTPUT,
            @cLottable03     OUTPUT,
            @dLottable04     OUTPUT,
            @dLottable05     OUTPUT,
            @cLottable06     OUTPUT,
            @cLottable07     OUTPUT,
            @cLottable08     OUTPUT,
            @cLottable09     OUTPUT,
            @cLottable10     OUTPUT,
            @cLottable11     OUTPUT,
            @cLottable12     OUTPUT,
            @dLottable13     OUTPUT,
            @dLottable14     OUTPUT,
            @dLottable15     OUTPUT,
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
               SET @cGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'PickGetSuggestedLoc_SP', @cStorerKey)
               IF ISNULL(@cGetSuggestedLoc_SP, '') NOT IN ('', '0')
               BEGIN
                  EXEC RDT.RDT_GetSuggestedLoc_Wrapper
                      @n_Mobile        = @nMobile
                     ,@n_Func          = @nFunc
                     ,@c_LangCode      = @cLangCode
                     ,@c_SPName        = @cGetSuggestedLoc_SP
                     ,@c_Storerkey     = @cStorerKey
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
                  SET @cErrMsg = ''

                  -- Get pickheader info
                  SELECT TOP 1
                     @cOrderKey = OrderKey,
                     @cExternOrderKey = ExternOrderKey,
                     @cZone = Zone
                  FROM dbo.PickHeader WITH (NOLOCK)
                  WHERE PickHeaderKey = @cPickSlipNo

                  SELECT @nLOC_Count = 0

                  IF ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP'
                  BEGIN
                     SELECT
                        @nLOC_Count = COUNT(DISTINCT PD.LOC),
                        @nORD_Count = COUNT(DISTINCT PD.OrderKey),
                        @nSKU_Count = COUNT(DISTINCT PD.SKU)
                     FROM dbo.PickDetail PD (NOLOCK)
                     JOIN dbo.RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
                     WHERE RPL.PickslipNo = @cPickSlipNo
                     AND   PD.Status = '0'
                  END
                  ELSE
                  BEGIN
                     IF ISNULL(@cOrderKey, '') <> ''
                     BEGIN
                        SELECT
                           @nLOC_Count = COUNT(DISTINCT PD.LOC),
                           @nORD_Count = COUNT(DISTINCT PD.OrderKey),
                           @nSKU_Count = COUNT(DISTINCT PD.SKU)
                        FROM dbo.PickHeader PH WITH (NOLOCK)
                        JOIN dbo.PickDetail PD (NOLOCK) ON PH.OrderKey = PD.OrderKey
                        WHERE PH.PickHeaderKey = @cPickSlipNo
                        AND   PD.Status = '0'
                     END
                     ELSE
                     BEGIN
                        SELECT
                           @nLOC_Count = COUNT(DISTINCT PD.LOC),
                           @nORD_Count = COUNT(DISTINCT PD.OrderKey),
                           @nSKU_Count = COUNT(DISTINCT PD.SKU)
                        FROM dbo.PickHeader PH WITH (NOLOCK)
                        JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
                        JOIN dbo.PickDetail PD (NOLOCK) ON LPD.OrderKey = PD.OrderKey
                        WHERE PH.PickHeaderKey = @cPickSlipNo
                        AND   PD.Status = '0'
                     END
                  END

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
                  SET @cOutField11 = ''
                  SET @cOutField12 = ''
                  SET @cOutField13 = ''
                  SET @cOutField14 = ''

                  SET @cOutField01 = 'PS NO:' + @cPickSlipNo
                  SET @cOutField03 = 'LOC NOT PICK: ' + CAST (@nLOC_Count AS NVARCHAR(5))
                  SET @cOutField04 = 'ORD NOT PICK: ' + CAST (@nORD_Count AS NVARCHAR(5))
                  SET @cOutField05 = 'SKU NOT PICK: ' + CAST (@nSKU_Count AS NVARCHAR(5))
                  SET @cOutField10 = 'PRESS ENTER/ESC'
                  SET @cOutField11 = 'TO CONTINUE'

                  -- Go to picking summary screen
                  SET @nScn = @nScn_Summary
                  SET @nStep = @nStep_Summary

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
   
   -- ESC or No --Back to ID screen
   -- Dynamic lottable    
   EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 7,     
      @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,    
      @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,    
      @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,    
      @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,    
      @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,    
      @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,    
      @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,    
      @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,    
      @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,    
      @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,    
      @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,    
      @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,    
      @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,    
      @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,    
      @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,    
      @nMorePage   OUTPUT,    
      @nErrNo      OUTPUT,    
      @cErrMsg     OUTPUT,    
      '',      -- SourceKey    
      @nFunc   -- SourceType    

   
   -- Refresh ID screen var
   -- SET @cOutField01 = @cLOC
   SET @cOutField02 = @cID
   SET @cOutField03 = @cSKU
   SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
   SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
   SET @cOutField06 = @cLottable02
   SET @cOutField07 = @cLottable03
   SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
   IF @cPrefUOM_Desc = ''
   BEGIN
      SET @cOutField10 = '' -- @cPrefUOM_Desc
      SET @cOutField11 = '' -- @nPrefQTY
   END
   ELSE
   BEGIN
      SET @cOutField10 = @cPrefUOM_Desc
      SET @cOutField11 = CAST( @nPrefQTY AS NVARCHAR( 5))
   END
   SET @cOutField12 = @cMstUOM_Desc
   SET @cOutField13 = @nMstQTY
   SET @cOutField14 = '' -- @cInID
   SET @cOutField15 = @cLottable01

   -- Go to ID screen
   SET @nScn = @nScn_ID
   SET @nStep = @nStep_ID
   
   GOTO Quit

   SkipTask_Option_Fail:
   BEGIN
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

/********************************************************************************
Scn 5 = 5914 (839). Message. 'No more task in LOC ....'
********************************************************************************/
Step_NoMoreTask:
BEGIN
   -- Prepare LOC screen var
   SET @cOutField01 = @cPickSlipNo
   SET @cOutField02 = @cSuggestedLOC
   SET @cOutField03 = '' -- LOC
   SET @cOutField04 = '' -- DropID
   EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC

   -- (Vicky02) - Start
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
   -- (Vicky02) - End

   EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC

   -- Back to LOC screen
   SET @nScn = @nScn_LOC
   SET @nStep = @nStep_LOC
END
GOTO Quit


/********************************************************************************
Scn 6 = 5915 (840). Full Pallet/ Partial Pallet Option
   Option (field01)
********************************************************************************/
Step_PalletType:
BEGIN 
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 62675
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required
         GOTO PalletType_Option_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '3')
      BEGIN
         SET @nErrNo = 62676
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
         GOTO PalletType_Option_Fail
      END

      IF @cOption = '1' -- 'Full Pallet'
      BEGIN
         Set @cPalletType = 'FP'
         GOTO Continue_GetTask
      END
      Else IF @cOption = '3' -- 'Partial Pallet'
      BEGIN
         Set @cPalletType = 'PP'
         GOTO Continue_GetTask
      END

      --SET @cSuggestedLOC = ''
      --SET @cLoc = ''
      ---- If show suggested loc config turned on then goto show suggested loc screen
      ---- svalue can be 1 show sugg loc but cannot overwrite, 2 = show sugg loc but can overwrite
      --IF @cPickShowSuggestedLOC <> '0' -- If not setup, return 0
      --BEGIN
      --   -- Get suggested loc
      --   SET @nErrNo = 0
      --   SET @cGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'PickGetSuggestedLoc_SP', @cStorerKey)
      --   IF ISNULL(@cGetSuggestedLoc_SP, '') NOT IN ('', '0')
      --   BEGIN
      --      EXEC RDT.RDT_GetSuggestedLoc_Wrapper
      --          @n_Mobile        = @nMobile
      --         ,@n_Func          = @nFunc
      --         ,@c_LangCode      = @cLangCode
      --         ,@c_SPName        = @cGetSuggestedLoc_SP
      --         ,@c_Storerkey     = @cStorerKey
      --         ,@c_OrderKey      = ''
      --         ,@c_PickSlipNo    = @cPickSlipNo
      --         ,@c_SKU           = ''
      --         ,@c_FromLoc       = @cLOC
      --         ,@c_FromID        = ''
      --         ,@c_oFieled01     = @c_oFieled01    OUTPUT
      --         ,@c_oFieled02     = @c_oFieled02    OUTPUT
      --         ,@c_oFieled03     = @c_oFieled03    OUTPUT
      --         ,@c_oFieled04     = @c_oFieled04    OUTPUT
      --         ,@c_oFieled05     = @c_oFieled05    OUTPUT
      --         ,@c_oFieled06     = @c_oFieled06    OUTPUT
      --         ,@c_oFieled07     = @c_oFieled07    OUTPUT
      --         ,@c_oFieled08     = @c_oFieled08    OUTPUT
      --         ,@c_oFieled09     = @c_oFieled09    OUTPUT
      --         ,@c_oFieled10     = @c_oFieled10    OUTPUT
      --         ,@c_oFieled11     = @c_oFieled11    OUTPUT
      --         ,@c_oFieled12     = @c_oFieled12    OUTPUT
      --         ,@c_oFieled13     = @c_oFieled13    OUTPUT
      --         ,@c_oFieled14     = @c_oFieled14    OUTPUT
      --         ,@c_oFieled15     = @c_oFieled15    OUTPUT
      --         ,@b_Success       = @b_Success      OUTPUT
      --         ,@n_ErrNo         = @nErrNo         OUTPUT
      --         ,@c_ErrMsg        = @cErrMsg        OUTPUT

      --      IF ISNULL(@cErrMsg, '') <> ''
      --         GOTO PickSlipNo_Fail

      --      SET @cSuggestedLOC = @c_oFieled01
      --   END
      --END

      ---- Prepare LOC screen var
      --SET @cOutField01 = @cPickSlipNo
      --SET @cOutField02 = @cSuggestedLOC
      --SET @cOutField03 = '' -- LOC
      --SET @cOutField04 = '' -- DropID
      --EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC

      ---- Go to LOC screen
      --SET @nScn = @nScn_LOC
      --SET @nStep = @nStep_LOC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cPickSlipNo = ''
      SET @cOutField01 = '' -- PSNO

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
      SET @nScn = @nScn_PickSlipNo
      SET @nStep = @nStep_PickSlipNo
   END

   

   PalletType_Option_Fail:
   BEGIN
      SET @cOption = ''
   END
END
GOTO Quit

/********************************************************************************
Scn 7 = 5916 (842). Message. 'LOC NOT MATCH'
   Option (field01)
********************************************************************************/
Step_ConfirmLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 169179
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required
         GOTO Step_ConfirmLOC_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 169180
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
         GOTO Step_ConfirmLOC_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
      	IF @cPalletOp = '1'
         BEGIN
            -- Prepare LOC screen var
            SET @cOutField01 = '' --option

            -- Go to Pallet Type Option screen
            SET @nScn = @nScn_PalletType
            SET @nStep = @nStep_PalletType
            GOTO Quit
         END
      
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
Scn 8 = 5917 (843). Message.
   Picking Summary(field01)
********************************************************************************/
Step_Summary:
BEGIN
   IF @nInputKey IN (1, 0) -- ENTER/ESC
   BEGIN
      -- Prepare PickSlipNo screen var
      SET @cOutField01 = '' -- PickSlipNo

      -- Go to PickSlipNo screen
      SET @nScn = @nScn_PickSlipNo
      SET @nStep = @nStep_PickSlipNo
   END
END
GOTO Quit

--/********************************************************************************    
--Scn = 3990. Dynamic lottables    
--   Label01    (field01)    
--   Lottable01 (field02, input)    
--   Label02    (field03)    
--   Lottable02 (field04, input)    
--   Label03    (field05)    
--   Lottable03 (field06, input)    
--   Label04    (field07)    
--   Lottable04 (field08, input)    
--   Label05    (field09)    
--   Lottable05 (field10, input)    
--********************************************************************************/    
--Step_VerifyLottable:    
--BEGIN    
--   IF @nInputKey = 1 -- Yes or Send    
--   BEGIN    
--      -- Dynamic lottable    
--      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'VERIFY', 'CHECK', 5, 1,     
--         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,    
--         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,    
--         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,    
--         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,    
--         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,    
--         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,    
--         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,    
--         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,    
--         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,    
--         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,    
--         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,    
--         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,    
--         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,    
--         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,    
--         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,    
--         @nMorePage   OUTPUT,    
--         @nErrNo      OUTPUT,    
--         @cErrMsg     OUTPUT,    
--         '',      -- SourceKey    
--         @nFunc   -- SourceType    
    
--      IF @nErrNo <> 0    
--         GOTO Quit    
    
--      IF @nMorePage = 1 -- Yes    
--         GOTO Quit    
    
--      -- Enable field    
--      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5    
--      SET @cFieldAttr04 = ''    
--      SET @cFieldAttr06 = ''    
--      SET @cFieldAttr08 = ''    
--      SET @cFieldAttr10 = ''    
    
--      -- Dynamic lottable    
--      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,     
--         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,    
--         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,    
--         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,    
--         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,    
--         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,    
--         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,    
--         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,    
--         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,    
--         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,    
--         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,    
--         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,    
--         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,    
--         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,    
--         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,    
--         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,    
--         @nMorePage   OUTPUT,    
--         @nErrNo      OUTPUT,    
--         @cErrMsg     OUTPUT,    
--         '',      -- SourceKey    
--         @nFunc   -- SourceType    
    
--      -- Convert to prefer UOM QTY    
--      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
--         @nPUOM_Div = 0  -- UOM not setup    
--      BEGIN    
--         SET @cPUOM_Desc = ''    
--         SET @nPQTY = 0    
--         SET @nMQTY = @nTaskQTY    
--         SET @cFieldAttr14 = 'O' -- @nPQTY    
--      END    
--      ELSE    
--      BEGIN    
--         SET @nPQTY = @nTaskQTY / @nPUOM_Div -- Calc QTY in preferred UOM    
--         SET @nMQTY = @nTaskQTY % @nPUOM_Div -- Calc the remaining in master unit    
--         SET @cFieldAttr14 = '' -- @nPQTY    
--      END             
    
--      -- Prepare QTY screen var    
--      SET @cOutField01 = @cPPK    
--      SET @cOutField02 = @cSKU    
--      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1    
--      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2    
--      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))    
--      SET @cOutField10 = @cPUOM_Desc    
--      SET @cOutField11 = @cMUOM_Desc    
--      SET @cOutField12 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END    
--      SET @cOutField13 = CAST( @nMQTY AS NVARCHAR( 5))    
--      SET @cOutField14 = '' -- @nPQTY    
--      SET @cOutField15 = '' -- @nMQTY    
    
--      -- Goto QTY screen    
--      SET @nScn = @nScn_QTY    
--      SET @nStep = @nStep_QTY    
--   END    
    
--   IF @nInputKey = 0 -- Esc or No    
--   BEGIN    
--      -- Dynamic lottable    
--      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'VERIFY', 'POPULATE', 5, 1,     
--         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,    
--         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,    
--         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,    
--         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,    
--         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,    
--         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,    
--         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,    
--         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,    
--         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,    
--         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,    
--         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,    
--         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,    
--         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,    
--         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,    
--         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,    
--         @nMorePage   OUTPUT,    
--         @nErrNo      OUTPUT,    
--         @cErrMsg     OUTPUT,    
--         '',      -- SourceKey    
--         @nFunc   -- SourceType    
    
--      IF @nMorePage = 1 -- Yes    
--         GOTO Quit    
    
--      -- Enable field    
--      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5    
--      SET @cFieldAttr04 = ''    
--      SET @cFieldAttr06 = ''    
--      SET @cFieldAttr08 = ''    
--      SET @cFieldAttr10 = ''    
    
--      -- Dynamic lottable    
--      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 7,     
--         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,    
--         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,    
--         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,    
--         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,    
--         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,    
--         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,    
--         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,    
--         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,    
--         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,    
--         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,    
--         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,    
--         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,    
--         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,    
--         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,    
--         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,    
--         @nMorePage   OUTPUT,    
--         @nErrNo      OUTPUT,    
--         @cErrMsg     OUTPUT,    
--         '',      -- SourceKey    
--         @nFunc   -- SourceType    
    
--      -- Prepare SKU screen var    
--      SET @cOutField01 = @cLOC    
--      SET @cOutField02 = @cDropID    
--      SET @cOutField03 = @cSKU     
--      SET @cOutField04 = '' --@cSKU    
--      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1    
--      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 40)  -- SKU desc 2    
--      SET @cOutField20 = '' -- ExtendedInfo    
    
--      -- Goto SKU screen    
--      SET @nScn = @nScn_SKU    
--      SET @nStep = @nStep_SKU    
--   END    
    
--   -- Extended info    
--   IF @cExtendedInfoSP <> ''    
--   BEGIN    
--      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
--      BEGIN    
--         SET @cExtendedInfo = ''    
--         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
--            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +    
--            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +    
--            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +    
--            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +    
--            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
--         SET @cSQLParam =     
--            '@nMobile       INT,           ' +    
--            '@nFunc         INT,           ' +    
--            '@cLangCode     NVARCHAR( 3),  ' +    
--            '@nStep         INT,           ' +    
--            '@nAfterStep    INT,           ' +    
--            '@nInputKey     INT,           ' +    
--            '@cFacility     NVARCHAR( 5),  ' +     
--            '@cStorerKey    NVARCHAR( 15), ' +    
--            '@cPickSlipNo   NVARCHAR( 10), ' +  
--            '@cPickZone     NVARCHAR( 10), ' +    
--            '@cSuggLOC NVARCHAR( 10), ' +    
--            '@cLOC          NVARCHAR( 10), ' +    
--            '@cDropID       NVARCHAR( 20), ' +    
--            '@cSKU          NVARCHAR( 20), ' +    
--            '@cLottable01   NVARCHAR( 18), ' +    
--            '@cLottable02   NVARCHAR( 18), ' +    
--            '@cLottable03   NVARCHAR( 18), ' +    
--            '@dLottable04   DATETIME,      ' +    
--            '@dLottable05   DATETIME,      ' +    
--            '@cLottable06   NVARCHAR( 30), ' +    
--            '@cLottable07   NVARCHAR( 30), ' +    
--            '@cLottable08   NVARCHAR( 30), ' +    
--            '@cLottable09   NVARCHAR( 30), ' +    
--            '@cLottable10   NVARCHAR( 30), ' +    
--            '@cLottable11   NVARCHAR( 30), ' +    
--            '@cLottable12   NVARCHAR( 30), ' +    
--            '@dLottable13   DATETIME,      ' +    
--            '@dLottable14   DATETIME,      ' +    
--            '@dLottable15   DATETIME,      ' +    
--            '@nTaskQTY      INT,           ' +    
--            '@nQTY          INT,           ' +    
--            '@cToLOC        NVARCHAR( 10), ' +    
--            '@cOption       NVARCHAR( 1),  ' +    
--            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +    
--            '@nErrNo        INT           OUTPUT, ' +    
--            '@cErrMsg       NVARCHAR( 20) OUTPUT  '    
--         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
--            @nMobile, @nFunc, @cLangCode, Step_VerifyLottable, @nStep, @nInputKey, @cFacility, @cStorerKey,@cPickZone, @cPickSlipNo, @cSuggLOC, @cLOC, @cDropID, @cSKU,     
--            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
--            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,    
--            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,    
--            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
--         IF @nErrNo <> 0    
--            GOTO Quit    
    
--         SET @cOutField20 = @cExtendedInfo    
--      END    
--   END    
--   GOTO Quit    
    
--   Step_5_Fail:    
    
--END    
--GOTO Quit    
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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,

      V_PickSlipNo   = @cPickSlipNo,
      V_LOC          = @cLOC,
      V_ID           = @cID,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cUOM,
      V_QTY          = @cQTY,
      V_UCC          = @cUCC,
      V_Lottable01   = @cLottable01,    
      V_Lottable02   = @cLottable02,    
      V_Lottable03   = @cLottable03,    
      V_Lottable04   = @dLottable04,    
      V_Lottable05   = @dLottable05,    
      V_Lottable06   = @cLottable06,    
      V_Lottable07   = @cLottable07,    
      V_Lottable08   = @cLottable08,    
      V_Lottable09   = @cLottable09,    
      V_Lottable10   = @cLottable10,    
      V_Lottable11   = @cLottable11,    
      V_Lottable12   = @cLottable12,    
      V_Lottable13   = @dLottable13,    
      V_Lottable14   = @dLottable14,    
      V_Lottable15   = @dLottable15, 
      V_FromScn      = @nFromScn,
      V_FromStep     = @nFromStep,

      V_Integer1     = @nPQTY,
      V_Integer2     = @nPUCC,
      V_Integer3     = @nTaskQTY,
      V_Integer4     = @nTaskUCC,
      V_Integer5     = @nCaseCnt,
      V_Integer6     = @nPrefUOM_Div,
      V_Integer7     = @nPrefQTY,
      V_Integer8     = @nMstQTY,
      V_Integer9     = @nActPQty,
      V_Integer10    = @nActMQty,
      V_Integer11    = @nFunctionKey,

      V_String1      = @cAutoScanIn,
      V_String2      = @cLottableCode,
      V_String3      = @cFunctionKey,
      V_String4      = @cPalletOp,
      V_String5      = @cPalletType,
      V_String6      = @cUOMDesc,
      V_String7      = @cPPK,
      V_String8      = @cParentScn,
      V_String9      = @cDropID,
      V_String10     = @cPrefUOM,      -- Pref UOM
      V_String11     = @cPrefUOM_Desc, -- Pref UOM desc
      V_String12     = @cMstUOM_Desc,  -- Master UOM desc
      V_String16     = @cPickType,     -- S=SKU/UPC, U=UCC, P=Pallet
      V_String17     = @cPrintPalletManifest,
      V_String18     = @cExternOrderKey,
      V_String19     = @cSuggestedLOC,
      V_String20     = @cPickShowSuggestedLOC,
      V_String23     = @cExtendedValidateSP,
      V_String24     = @cExtendedInfoSP,
      V_String25     = @cExtendedInfo,
      V_String26     = @cSwapIDSP,
      V_String27     = @cDecodeSP,
      V_String28     = @cPickDontShowLot02,
      V_String29     = @cDefaultToPickQty,  
      V_String41     = @cBarcode,

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