SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdtfnc_PostPickAudit_SKULottable                          */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Picking:                                                          */
/*          1. SKU/UPC                                                        */
/*          2. UCC                                                            */
/*          3. Pallet                                                         */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2010-10-19   1.0  ChewKP     Created                                       */
/* 2015-01-08   1.1  James      Get correct codelkup for lottable             */
/*                              Bug fix (james01)                             */
/* 2015-05-05   1.2  James      SOS337674 - Set default cursor by using       */
/*                              config (james02)                              */
/* 2015-05-25   1.3  James      Set default ppa qty                           */
/* 2015-09-25   1.4  SPChin     SOS353781 - PRE POST Codelkup Filter by       */
/*                                          Storerkey                         */
/* 2016-08-09   1.5  James      SOS374911 Add DecodeSP (james03)              */
/*                              Add ExtendedUpdateSP                          */
/*                              Add dynamic lottable                          */
/* 2016-09-30   1.6  Ung        Performance tuning                            */
/* 2017-01-24   1.7  Ung        Fix recompile due to date format different    */
/*                              IN00402909 Fix UPC is blank                   */
/* 2020-01-07   1.8  Chermaine  WMS-11486 Add Eventlog (cc01)                 */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PostPickAudit_SKULottable] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 250),
   @i              INT,
   @nTask          INT,
   @cParentScn     NVARCHAR( 3),
   @cReasonCode    NVARCHAR( 2),
   @cReasonDesc    NVARCHAR(25),
   @cXML           NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

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
   @cDropID        NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @cSKUDescr      NVARCHAR( 60),
   @cUOM           NVARCHAR( 10),   -- Display NVARCHAR(3)
   @cQTY           NVARCHAR( 5),
   @cUCC           NVARCHAR( 20),


   @nPQTY          INT,  -- Picked QTY
   @nPUCC          INT,  -- Picked UCC
   @nTaskQTY       INT,  -- QTY of the task
   @nTaskUCC       INT,  -- No of UCC in the task

   @cUOMDesc       NVARCHAR( 3),
   @cPrefUOM       NVARCHAR( 1), -- Pref UOM
   @nPrefUOM_Div   INT,      -- Pref UOM divider
   @cPrefUOM_Desc  NVARCHAR( 5), -- Pref UOM desc
   @cMstUOM_Desc   NVARCHAR( 5), -- Master UOM desc
   @nPrefQTY       INT,      -- QTY in pref UOM
   @nMstQTY        INT,      -- Remaining QTY in master unit

   @cPPK           NVARCHAR( 5),
   @nCaseCnt       INT,
   @cPickType      NVARCHAR( 1), -- S=SKU/UPC, U=UCC, P=Pallet
   @cPrintPalletManifest NVARCHAR( 1),  -- store configkey 'PrintPalletManifest' value
   @cLoadkey       NVARCHAR( 10),   -- packheader.externorderkey = loadplan.loadkey??
   @cPrinter       NVARCHAR( 10),
   @cDataWindow    NVARCHAR( 50),
   @cTargetDB      NVARCHAR( 10),
   @cChkStorerKey  NVARCHAR( 15),
   @cOrderKey      NVARCHAR( 10),
   @nCnt           INT,
   @dScanInDate    DATETIME,
   @dScanOutDate   DATETIME,
   @cLottable01_Code    NVARCHAR( 20),
   @cLottable02_Code    NVARCHAR( 20),
   @cLottable03_Code    NVARCHAR( 20),
   @cLottable04_Code    NVARCHAR( 20),
   @cLottable05_Code    NVARCHAR( 20),
   @nCountLot           INT,
   @cLottableLabel      NVARCHAR( 20),
   @cLotLabel01         NVARCHAR( 20),
   @cLotLabel02         NVARCHAR( 20),
   @cLotLabel03         NVARCHAR( 20),
   @cLotLabel04         NVARCHAR( 20),
   @cLotLabel05         NVARCHAR( 20),
   @cListName           NVARCHAR( 20),
   @cShort              NVARCHAR( 10),
   @cStoredProd         NVARCHAR( 250),
   @cHasLottable        NVARCHAR( 1),
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @cLottable04         NVARCHAR( 16),
   @cLottable05         NVARCHAR( 16),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cSourcekey          NVARCHAR(15),
   @cPrePackByBOM       NVARCHAR(1),
   @cTempLottable01     NVARCHAR( 18),
   @cTempLottable02     NVARCHAR( 18),
	@cTempLottable03     NVARCHAR( 18),
	@cTempLottable04     NVARCHAR( 16),
	@cTempLottable05     NVARCHAR( 16),
   @dTempLottable04     DATETIME,
	@dTempLottable05     DATETIME,
   @cSKUDesc            NVARCHAR( 60),
   @cPUOM               NVARCHAR( 1), -- Prefer UOM
   @cPUOM_Desc          NVARCHAR( 5),
   @cMUOM_Desc          NVARCHAR( 5),
   @nPUOM_Div           INT, -- UOM divider
   @nMQTY               INT, -- Master unit QTY
   @nSum_PalletQty      INT,
   @nSuggestQTY         INT, -- Suggetsed QTY
   @nActQTY             INT, -- Actual QTY
   @nActMQTY            INT, -- Actual keyed in master QTY
   @nActPQTY            INT, -- Actual keyed in prefered QTY
   @cActPQTY            NVARCHAR( 5),
   @cActMQTY            NVARCHAR( 5),
   @nCountSKU           INT,
   @nCountChkSKU     INT,
   @nSumQTY             INT,
   @nSumChkQTY       INT,
   @cPickStatus         NVARCHAR(20),
   @cPPAType            NVARCHAR(1),
   @cRefNo              NVARCHAR(10),
   @cChkPickSlipNo      NVARCHAR(10),
   @cOrd_LoadKey        NVARCHAR(10),
   @cDropID_LoadKey     NVARCHAR(10),
   @nCQTY               INT,
   @c_NewLineChar       NVARCHAR(2),
   @c_AlertMessage      NVARCHAR( 255),
   @nCheckQty           INT,
   @cSuggestPQTY        NVARCHAR( 5),
   @cSuggestMQTY        NVARCHAR( 5),
   @nSuggestPQTY        INT, -- Suggested master QTY
   @nSuggestMQTY        INT, -- Suggested prefered QTY

   @cPPASKULottableDefCursor  NVARCHAR( 1),

   -- (james03)
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cUPC                NVARCHAR( 30),
   @cLottable06         NVARCHAR( 30), 
   @cLottable07         NVARCHAR( 30), 
   @cLottable08         NVARCHAR( 30), 
   @cLottable09         NVARCHAR( 30), 
   @cLottable10         NVARCHAR( 30), 
   @cLottable11         NVARCHAR( 30), 
   @cLottable12         NVARCHAR( 30), 
   @dLottable13         DATETIME,      
   @dLottable14         DATETIME,      
   @dLottable15         DATETIME,    
   @cUserDefine01       NVARCHAR( 60),  
   @cUserDefine02       NVARCHAR( 60),  
   @cUserDefine03       NVARCHAR( 60),  
   @cUserDefine04       NVARCHAR( 60),  
   @cUserDefine05       NVARCHAR( 60),  
   @cSKUCode            NVARCHAR( 20),  
   @cSQL                NVARCHAR( MAX), 
   @cSQLParam           NVARCHAR( MAX), 
   @cPieceScanQty       NVARCHAR( 5),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cLottableCode       NVARCHAR( 30),
   @nQty                INT,
   @nSKUCnt             INT,
   @nMorePage           INT,
   @nFromScn            INT,
   @nFromStep           INT,

   @cHasLottable01      NVARCHAR( 18), 
   @cHasLottable02      NVARCHAR( 18), 
   @cHasLottable03      NVARCHAR( 18), 
   @dHasLottable04      DATETIME, 
   @dHasLottable05      DATETIME, 
   @cHasLottable06      NVARCHAR( 30), 
   @cHasLottable07      NVARCHAR( 30), 
   @cHasLottable08      NVARCHAR( 30), 
   @cHasLottable09      NVARCHAR( 30), 
   @cHasLottable10      NVARCHAR( 30), 
   @cHasLottable11      NVARCHAR( 30), 
   @cHasLottable12      NVARCHAR( 30), 
   @dHasLottable13      DATETIME,      
   @dHasLottable14      DATETIME,      
   @dHasLottable15      DATETIME,    

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
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorer          = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,

   @cPickSlipNo      = V_PickSlipNo,
   @cLOC             = V_LOC,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cPUOM            = V_UOM,
   @nActQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,
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
   @cLotLabel01      = V_LottableLabel01,
   @cLotLabel02      = V_LottableLabel02,
   @cLotLabel03      = V_LottableLabel03,
   @cLotLabel04      = V_LottableLabel04,
   @cLotLabel05      = V_LottableLabel05,
   @cLoadkey         = V_Loadkey,

   @cOrderKey        = V_String1,
   @cDropID          = V_String2,
   @nSuggestQTY      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   @nActMQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
   @nActPQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,
   @cPieceScanQty    = V_String6,
   @cLottable01_Code = V_String7,
   @cLottable02_Code = V_String8,
   @cLottable03_Code = V_String9,
   @cLottable04_Code = V_String10,
   @cLottable05_Code = V_String11,
   @cHasLottable     = V_String12,

   @cMUOM_Desc       = V_String13,
   @cPUOM_Desc       = V_String14,
   @nPUOM_Div        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,
   @nMQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16, 5), 0) = 1 THEN LEFT( V_String16, 5) ELSE 0 END,
   @nPQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17, 5), 0) = 1 THEN LEFT( V_String17, 5) ELSE 0 END,
   @cPPAType         = V_String18,
   @cRefNo           = V_String19,
   @cLottableCode    = V_String20,
   @cSourceKey       = V_String21,
   @nFromScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String22, 5), 0) = 1 THEN LEFT( V_String22, 5) ELSE 0 END,
   @nFromStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String23, 5), 0) = 1 THEN LEFT( V_String23, 5) ELSE 0 END,
   @cDecodeSP        = V_String24,

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

   -- Start
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
   -- End

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_Criteria      INT,  @nScn_Criteria       INT,
   @nStep_SKU           INT,  @nScn_SKU            INT,
   @nStep_Lottables     INT,  @nScn_Lottables      INT,
   @nStep_QTY           INT,  @nScn_QTY            INT,
   @nStep_ShortPick     INT,  @nScn_ShortPick      INT,
   @nStep_OrderSummary  INT,  @nScn_OrderSummary   INT

SELECT
   @nStep_Criteria      = 1,  @nScn_Criteria       = 2610,
   @nStep_SKU           = 2,  @nScn_SKU            = 2611,
--   @nStep_Lottables     = 3,  @nScn_Lottables      = 2612,
   @nStep_QTY           = 4,  @nScn_QTY            = 2613,
   @nStep_ShortPick     = 5,  @nScn_ShortPick      = 2614,
   @nStep_OrderSummary  = 6,  @nScn_OrderSummary   = 2615,
   @nStep_Lottables     = 7,  @nScn_Lottables      = 3990

IF @nFunc = 904
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 904
   IF @nStep = 1  GOTO Step_Criteria    -- Scn = 2610. Criteria
   IF @nStep = 2  GOTO Step_SKU         -- Scn = 2611. SKU
--   IF @nStep = 3  GOTO Step_Lottables   -- Scn = 2612. Lottables
   IF @nStep = 4  GOTO Step_QTY         -- Scn = 2613. QTY
   IF @nStep = 5  GOTO Step_ShortPick   -- Scn = 2614. Message. 'ReasonCode'
   IF @nStep = 6  GOTO Step_OrderSummary-- Scn = 2615. Message. 'PPA Summary'
   IF @nStep = 7  GOTO Step_Lottables   -- Scn = 3990. Lottables

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 904
********************************************************************************/
Step_Start:
BEGIN
   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
   INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Get StorerConfig 'UCC'
   DECLARE @cUCCStorerConfig NVARCHAR( 1)
   SELECT @cUCCStorerConfig = SValue
   FROM dbo.StorerConfig WITH (NOLOCK)
   WHERE StorerKey = @cStorer
      AND ConfigKey = 'UCC'

   SET @cPPASKULottableDefCursor = rdt.RDTGetConfig( @nFunc, 'PPASKULottableDefCursor', @cStorer)
   SET @cPrintPalletManifest = rdt.RDTGetConfig( 0, 'PrintPalletManifest', @cStorer)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   IF @cPPASKULottableDefCursor = '1'
      EXEC rdt.rdtSetFocusField @nMobile, 1

   IF @cPPASKULottableDefCursor = '2'
      EXEC rdt.rdtSetFocusField @nMobile, 2

   IF @cPPASKULottableDefCursor = '3'
      EXEC rdt.rdtSetFocusField @nMobile, 3

   IF @cPPASKULottableDefCursor = '4'
      EXEC rdt.rdtSetFocusField @nMobile, 4

   IF @cPPASKULottableDefCursor = '5'
      EXEC rdt.rdtSetFocusField @nMobile, 5

   SET @cPieceScanQty = rdt.RDTGetConfig( @nFunc, 'PPAPieceScan', @cStorer) 
   IF @cPieceScanQty = ''
      SET @cPieceScanQty = '0'

    -- (Vicky06) EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorer

   -- Prepare PickSlipNo screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''


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
   -- End

   -- Go to PickSlipNo screen
   SET @nScn = @nScn_Criteria
   SET @nStep = @nStep_Criteria
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
Scn = 2610. Criteria screen
   REFNO   (field01,input)
   PSNO    (field02,input)
   LOADKEY (field03,input)
   ORDERKEY(field04,input)
   CARTONID(field05,input)
************************************************************************************/
Step_Criteria:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cRefNo = ''
      SET @cPickSlipNo = ''
      SET @cLoadkey = ''
      SET @cOrderkey = ''
      SET @cDropID = '' -- (james01)

      -- Screen mapping
      SET @cRefNo = ISNULL(RTRIM(@cInField01),'')
      SET @cPickSlipNo = ISNULL(RTRIM(@cInField02),'')
      SET @cLoadkey = ISNULL(RTRIM(@cInField03),'')
      SET @cOrderkey = ISNULL(RTRIM(@cInField04),'')
      SET @cDropID = ISNULL(RTRIM(@cInField05),'')



      IF @cRefNo = '' AND @cPickSlipNo = '' AND @cLoadkey = '' AND @cOrderkey = '' AND @cDropID = ''
      BEGIN
         SET @nErrNo = 71591
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Value Required
         GOTO PickSlipNo_Fail
      END

      IF (@cRefNo <> '' ) AND (
            (@cPickSlipNo <> '' ) OR
            (@cLoadKey <> '' )) OR
            -- for RefNo checking
            (@cPickSlipNo <> '' ) AND (
            (@cRefNo <> '' ) OR
            (@cLoadKey <> '' )) OR
            -- for LoadKey checking
            (@cLoadKey <> '' ) AND (
            (@cRefNo <> '' ) OR
            (@cPickSlipNo <> '' ))
      BEGIN
            SET @nErrNo = 71592
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Key-in either 1
            GOTO PickSlipNo_Fail
      END

      SET @cPPAType = ''
      SET @cSourceKey = ''

    -- Ref No
      IF @cRefNo <> ''
      BEGIN
         -- Validate load plan status
         IF NOT EXISTS( SELECT 1
            FROM dbo.LoadPlan WITH (NOLOCK)
            WHERE UserDefine10 = @cRefNo ) -- 9=Closed
         BEGIN
            SET @nErrNo = 71593
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Ref#
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO PickSlipNo_Fail
         END

         -- Validate all pickslip already scan in
         IF EXISTS( SELECT 1
               FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
               WHERE LP.UserDefine10 = @cRefNo
               AND [PI].ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 71594
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not Scan-in
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO PickSlipNo_Fail
         END

         -- Validate all pickslip already scan out
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.UserDefine10 = @cRefNo
               AND [PI].ScanOutDate IS NULL)
         BEGIN
            SET @nErrNo = 71595
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not Scan-out
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO PickSlipNo_Fail
         END

         SET @cLoadkey = ''
         SELECT @cLoadkey = Loadkey FROM dbo.LOADPLAN WITH (NOLOCK)
         WHERE UserDefine10 = @cRefNo

         SET @cPPAType = '5'  -- By RefNo
         SET @cSourceKey = @cRefNo
      END


      -- Pick Slip No
      IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
      BEGIN
         SET @cOrderKey = ''
         -- Get pickheader info
         SELECT TOP 1
            @cChkPickSlipNo = PickHeaderKey--,
            --@cOrderKey = OrderKey--,
            --@cZone = Zone
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         -- Validate pickslip no
         IF @cChkPickSlipNo = '' OR @cChkPickSlipNo IS NULL
         BEGIN
            SET @nErrNo = 71596
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid PS#
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO PickSlipNo_Fail
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
            SET @nErrNo = 71597
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not scan-in
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO PickSlipNo_Fail
         END

         -- Validate pickslip not scan out
         IF @dScanOutDate IS NULL
         BEGIN
            SET @nErrNo = 71598
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not scan-out
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO PickSlipNo_Fail
         END

         SET @cPPAType = '2'  -- By PickSlip
         SET @cSourceKey = @cPickSlipNo
      END



      -- LoadKey
      IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL
      BEGIN
         -- Validate load plan status
         IF NOT EXISTS( SELECT 1
            FROM dbo.LoadPlan WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey ) -- 9=Closed
         BEGIN
            SET @nErrNo = 71599
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO PickSlipNo_Fail
         END

         -- Validate all pickslip already scan in
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.LoadKey = @cLoadKey
               AND [PI].ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 71600
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not Scan-in
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO PickSlipNo_Fail
         END

         -- Validate all pickslip already scan out
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.LoadKey = @cLoadKey
               AND [PI].ScanOutDate IS NULL)
         BEGIN
            SET @nErrNo = 71601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not Scan-out
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO PickSlipNo_Fail
         END

         SET @cPPAType = '1'  -- By Loadkey
         SET @cSourceKey = @cLoadKey
      END


      -- OrderKey
      IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
      BEGIN
         -- Validate load plan status
         IF NOT EXISTS( SELECT 1
            FROM dbo.Orders WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
               AND StorerKey = @cStorer) -- 9=Closed
         BEGIN
            SET @nErrNo = 71602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv OrderKey
            GOTO PickSlipNo_Fail
         END

         SELECT @cOrd_LoadKey = LoadKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND StorerKey = @cStorer

         -- Validate all pickslip already scan in
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.LoadKey = @cOrd_LoadKey
               AND [PI].ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 71603
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not Scan-in
            GOTO PickSlipNo_Fail
         END

         -- Validate all pickslip already scan out
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.LoadKey = @cOrd_LoadKey
               AND [PI].ScanOutDate IS NULL)
         BEGIN
            SET @nErrNo = 71604
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not Scan-out
            GOTO PickSlipNo_Fail
         END

         SET @cPPAType = '3'  -- By Orderkey
         SET @cSourceKey = @cOrderKey
      END


      -- DropID
      IF @cDropID <> '' AND @cDropID IS NOT NULL
      BEGIN
         -- Validate load plan status
         IF NOT EXISTS( SELECT 1
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE DropID = @cDropID
               AND StorerKey = @cStorer) -- 9=Closed
         BEGIN
            SET @nErrNo = 71605
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv DropID
            GOTO PickSlipNo_Fail
         END

         SELECT TOP 1 @cDropID_LoadKey = LoadKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         WHERE PD.DropID = @cDropID
            AND PD.StorerKey = @cStorer

         -- Validate all pickslip already scan in
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.LoadKey = @cDropID_LoadKey
               AND [PI].ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 71606
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not Scan-in
            GOTO PickSlipNo_Fail
         END

         -- Validate all pickslip already scan out
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.LoadKey = @cDropID_LoadKey
               AND [PI].ScanOutDate IS NULL)
         BEGIN
            SET @nErrNo = 71607
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not Scan-out
            GOTO PickSlipNo_Fail
         END

         SET @cPPAType = '4'  -- By DropID
         SET @cSourceKey = @cDropID
      END

      SET @cPrePackByBOM = ''
      SELECT @cPrePackByBOM = ISNULL(RTRIM(sValue),'')
      FROM DBO.StorerConfig WITH (NOLOCK)
      WHERE ConfigKey = 'PrePackByBOM'
      AND Storerkey = @cStorer

      -- Get storerkey
      SET @cChkStorerKey = ''

      IF @cPPAType = '1'  -- Loadkey
      BEGIN
         SELECT @cChkStorerKey = StorerKey
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = LPD.Orderkey
         WHERE LPD.Loadkey = @cLoadkey
      END
      ELSE IF @cPPAType = '2' -- PickSlipNo
      BEGIN
         SELECT @cChkStorerKey = Pd.StorerKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON  PH.PickHeaderkey = PD.PickSlipNo
         WHERE PD.PickSlipNo = @cPickSlipNo
      END
      ELSE IF @cPPAType = '3' -- Orderkey
      BEGIN
         SELECT @cChkStorerKey = Pd.StorerKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.Orderkey = @cOrderkey
      END
      ELSE IF @cPPAType = '4' -- DropID
      BEGIN
         SELECT @cChkStorerKey = Pd.StorerKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.DropID = @cDropID
      END
      ELSE IF @cPPAType = '5' -- RefNo
      BEGIN
         SELECT @cChkStorerKey = O.StorerKey
         FROM dbo.LoadPlan LP WITH (NOLOCK)
         INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.Loadkey = LP.Loadkey)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.Orderkey = LPD.Orderkey )
         WHERE LP.UserDefine10 = @cRefNo
      END



      -- Validate storerkey
      IF @cChkStorerKey IS NULL OR @cChkStorerKey = '' OR @cChkStorerKey <> @cStorer
      BEGIN
         SET @nErrNo = 71608
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff storer
         GOTO PickSlipNo_Fail
      END





      -- Prepare SKU screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadkey
      SET @cOutField04 = @cOrderkey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU

      -- Go to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
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
       @cStorerKey  = @cStorer

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option

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
      -- End
   END
   GOTO Quit

   PickSlipNo_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
   END
END
GOTO Quit


/********************************************************************************
Scn = 2611. SKU screen
   REFNO     (field01)
   PSNO      (field02)
   LOADKEY   (field03)
   ORDERKEY  (field04)
   CARTONID  (field05)
   SKU/UPC   (field06, input)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN


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
      -- End

      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = 0 -- 1900-01-01

      -- Screen mapping
      SET @cBarcode = @cInField06
      SET @cUPC = LEFT( @cInField06, 30)

      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 71609
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Req'
         GOTO SKU_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         SELECT @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',   @dLottable04 = NULL, @dLottable05 = NULL
         SELECT @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',   @cLottable09 = '',   @cLottable10 = ''
         SELECT @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL, @dLottable14 = NULL, @dLottable15 = NULL

         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode, 
               @cUPC          = @cUPC          OUTPUT, 
               @nQTY          = @nQTY          OUTPUT, 
               @cLottable01   = @cLottable01   OUTPUT, 
               @cLottable02   = @cLottable02   OUTPUT, 
               @cLottable03   = @cLottable03   OUTPUT, 
               @dLottable04   = @dLottable04   OUTPUT, 
               @dLottable05   = @dLottable05   OUTPUT,
               @cLottable06   = @cLottable06   OUTPUT, 
               @cLottable07   = @cLottable07   OUTPUT, 
               @cLottable08   = @cLottable08   OUTPUT, 
               @cLottable09   = @cLottable09   OUTPUT, 
               @cLottable10   = @cLottable10   OUTPUT,
               @cLottable11   = @cLottable11   OUTPUT, 
               @cLottable12   = @cLottable12   OUTPUT, 
               @dLottable13   = @dLottable13   OUTPUT, 
               @dLottable14   = @dLottable14   OUTPUT, 
               @dLottable15   = @dLottable15   OUTPUT,
               @cUserDefine01 = @cUserDefine01 OUTPUT, 
               @cUserDefine02 = @cUserDefine02 OUTPUT, 
               @cUserDefine03 = @cUserDefine03 OUTPUT, 
               @cUserDefine04 = @cUserDefine04 OUTPUT, 
               @cUserDefine05 = @cUserDefine05 OUTPUT,
               @nErrNo        = @nErrNo        OUTPUT, 
               @cErrMsg       = @cErrMsg       OUTPUT
         END
         
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, ' +
               ' @cRefno         OUTPUT, @cPickSlipNo    OUTPUT, @cLoadKey       OUTPUT, @cOrderKey      OUTPUT, @cDropID        OUTPUT, ' +
               ' @cUPC           OUTPUT, @nQTY           OUTPUT, ' + 
               ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
               ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
               ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
               ' @cUserDefine01  OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, ' + 
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cBarcode       NVARCHAR( 60), ' +
               ' @cRefno         NVARCHAR( 10)  OUTPUT, ' +
               ' @cPickSlipNo    NVARCHAR( 10)  OUTPUT, ' +
               ' @cLoadKey       NVARCHAR( 10)  OUTPUT, ' +
               ' @cOrderKey      NVARCHAR( 10)  OUTPUT, ' +
               ' @cDropID        NVARCHAR( 20)  OUTPUT, ' +
               ' @cUPC           NVARCHAR( 30)  OUTPUT, ' + 
               ' @nQTY           INT            OUTPUT, ' + 
               ' @cLottable01    NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02    NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03    NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04    DATETIME       OUTPUT, ' +
               ' @dLottable05    DATETIME       OUTPUT, ' +
               ' @cLottable06    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12    NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13    DATETIME       OUTPUT, ' +
               ' @dLottable14    DATETIME       OUTPUT, ' +
               ' @dLottable15    DATETIME       OUTPUT, ' +
               ' @cUserDefine01  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine02  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine03  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine04  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine05  NVARCHAR( 60)  OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode, 
               @cRefno        OUTPUT, @cPickSlipNo    OUTPUT, @cLoadKey       OUTPUT, @cOrderKey      OUTPUT, @cDropID        OUTPUT,
               @cUPC          OUTPUT, @nQTY           OUTPUT, 
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,               
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT
         END
      END

      SET @nErrNo = 0
      EXEC [RDT].[rdt_GETSKUCNT]
         @cStorerKey  = @cStorer
        ,@cSKU        = @cUPC
        ,@nSKUCnt     = @nSKUCnt       OUTPUT
        ,@bSuccess    = @b_Success     OUTPUT
        ,@nErr        = @nErrNo        OUTPUT
        ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 71628
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO SKU_Fail  
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 71629
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarcodeSKU
         GOTO SKU_Fail  
      END

      SET @nErrNo = 0
      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorer,
         @cSKU        = @cUPC          OUTPUT,
         @bSuccess    = @b_success     OUTPUT,
         @nErr        = @nErrNo        OUTPUT,
         @cErrMsg     = @cErrMsg       OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO SKU_Fail
      END

      SET @cSKU = @cUPC

      SET @nSum_PalletQty = 0

      IF @cPPAType = '1' -- Loadkey
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = LPD.Orderkey
                         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.Orderkey = O.Orderkey AND PD.Storerkey = O.Storerkey )
                         WHERE LPD.Loadkey = @cLoadkey
                         AND PD.SKU = @cSKU )
         BEGIN
               SET @nErrNo = 71610
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
               GOTO SKU_Fail
         END

      END
      ELSE IF @cPPAType = '2' -- PickSlipNo
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                        WHERE SKU = @cSKU
                        AND Storerkey = @cStorer
                        AND PickSlipNo = @cPickSlipNo)
         BEGIN
               SET @nErrNo = 71611
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
               GOTO SKU_Fail
         END
      END
      ELSE IF @cPPAType = '3' -- Orderkey
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                        WHERE SKU = @cSKU
                        AND Storerkey = @cStorer
                        AND Orderkey = @cOrderkey)
         BEGIN
               SET @nErrNo = 71612
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
               GOTO SKU_Fail
         END

      END
      ELSE IF @cPPAType = '4' -- DropID
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                        WHERE SKU = @cSKU
                        AND Storerkey = @cStorer
                        AND DropID = @cDropID)
         BEGIN
               SET @nErrNo = 71613
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
               GOTO SKU_Fail
         END

      END
      ELSE IF @cPPAType = '5' -- RefNo
      BEGIN
         IF NOT EXISTS (SELECT 1  FROM dbo.OrderDetail AS OD WITH (NOLOCK)
                           INNER JOIN dbo.PickDetail AS PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
                           INNER JOIN dbo.LoadPlan AS LP WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
                        WHERE LP.UserDefine10 = @cRefNo
                           AND OD.StorerKey = @cStorer
                           AND OD.SKU = @cSKU)
         BEGIN
               SET @nErrNo = 71614
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
               GOTO SKU_Fail
         END

      END


      SELECT @cSKUDescr = '', @cMUOM_Desc = '', @cPUOM_Desc = '', @nPUOM_Div = 0

      SELECT
            @cSKUDescr = SKU.Descr,
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
            END, 1) AS INT),
            @cLottableCode = LottableCode
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorer
         AND SKU.SKU = @cSKU

      -- Get Total Pick QTY for SKU and Insert into rdtPPA
      IF @cPPAType = '1'
      BEGIN
         SELECT @nSum_PalletQty = ISNULL(SUM(PD.QTY), 0) FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = LPD.Orderkey
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.Orderkey = O.Orderkey AND PD.Storerkey = O.Storerkey )
         WHERE LPD.Loadkey = @cLoadkey
         AND PD.SKU = @cSKU
         AND O.Storerkey = @cStorer


         -- Get check QTY from PPA
         SELECT @nCQTY = SUM( CQTY)
         FROM rdt.rdtPPA WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
            AND StorerKey = @cStorer
            AND SKU = @cSKU
         /*
         -- Insert into RDTPPA, if not exists
         IF @nCQTY IS NULL
         BEGIN
            SET @nCQTY = 0
            INSERT INTO rdt.rdtPPA WITH (ROWLOCK) (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID)
            VALUES ('', '', @cLoadKey, '', @cStorer, @cSKU, @cSKUDescr, @nSum_PalletQty, 0, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, '', '')
         END
         */
      END

      IF @cPPAType = '2'
      BEGIN
           SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
           WHERE SKU = @cSKU
           AND Storerkey = @cStorer
           AND PickSlipNo = @cPickSlipNo

           -- Get check QTY of the SKU
           SELECT @nCQTY = SUM( CQTY)
           FROM rdt.rdtPPA WITH (NOLOCK)
           WHERE SKU = @cSKU
             AND StorerKey = @cStorer
             AND PickSlipNo = @cPickSlipNo
           /*
           -- Insert into RDTPPA, if not exists
           IF @nCQTY IS NULL
           BEGIN
             SET @nCQTY = 0
             INSERT INTO rdt.rdtPPA WITH (ROWLOCK) (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID)
             VALUES ('', @cPickSlipNo, '', '', @cStorer, @cSKU, @cSKUDescr, @nSum_PalletQty, 0, '0', @cUserName, GETDATE(), 0, @nPUOM_Div, '', '')
           END
           */
      END

      IF @cPPAType = '3'
      BEGIN
         SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
         WHERE SKU = @cSKU
         AND Storerkey = @cStorer
         AND Orderkey = @cOrderkey

           -- Get check QTY from PPA
         SELECT @nCQTY = SUM( CQTY)
         FROM rdt.rdtPPA WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND StorerKey = @cStorer
            AND SKU = @cSKU
            /*
         -- Insert into RDTPPA, if not exists
         IF @nCQTY IS NULL
         BEGIN
            SET @nCQTY = 0
            INSERT INTO rdt.rdtPPA WITH (ROWLOCK) (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID)
            VALUES ('', '', '', '', @cStorer, @cSKU, @cSKUDescr, @nSum_PalletQty, 0, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, @cOrderKey, '')
         END
         */
      END

      IF @cPPAType = '4'
      BEGIN
          SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
          WHERE SKU = @cSKU
          AND Storerkey = @cStorer
          AND DropID = @cDropID

          -- Get check QTY from PPA
         SELECT @nCQTY = SUM( CQTY)
         FROM rdt.rdtPPA WITH (NOLOCK)
         WHERE DropID = @cDropID
            AND StorerKey = @cStorer
            AND SKU = @cSKU
         /*
         -- Insert into RDTPPA, if not exists
         IF @nCQTY IS NULL
         BEGIN
            SET @nCQTY = 0
            INSERT INTO rdt.rdtPPA WITH (ROWLOCK) (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID)
            VALUES ('', '', '', '', @cStorer, @cSKU, @cSKUDescr, @nSum_PalletQty, 0, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, '', @cDropID)
         END
         */
      END

      IF @cPPAType = '5'
      BEGIN
         SELECT @nSum_PalletQty = SUM( PD.QTY)
         FROM dbo.OrderDetail AS OD WITH (NOLOCK)
            INNER JOIN dbo.PickDetail AS PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            INNER JOIN dbo.LoadPlan AS LP WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
         WHERE LP.UserDefine10 = @cRefNo
            AND OD.StorerKey = @cStorer
            AND OD.SKU = @cSKU

          -- Get check QTY from PPA
         SELECT @nCQTY = SUM( CQTY)
         FROM rdt.rdtPPA WITH (NOLOCK)
         WHERE RefKey = @cRefNo
            AND StorerKey = @cStorer
            AND SKU = @cSKU
         /*
         -- Insert into RDTPPA, if not exists
         IF @nCQTY IS NULL
         BEGIN
            SET @nCQTY = 0
            INSERT INTO rdt.rdtPPA WITH (ROWLOCK) (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID)
            VALUES (@cRefNo, '', '', '', @cStorer, @cSKU, @cSKUDescr, @nSum_PalletQty, 0, '0',  @cUserName, GETDATE(), 0, @nPUOM_Div, '', '')
         END
         */
      END

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorer, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1, 
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
         @cSourceKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables
      END
      ELSE
      BEGIN       -- Go to Qty screen
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nSum_PalletQty

            SET @cFieldAttr11 = 'O'
         END
         ELSE
         BEGIN
            SET @nPQTY = @nSum_PalletQty / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nSum_PalletQty % @nPUOM_Div  -- Calc the remaining in master unit
         END

          -- Prepare QTY screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2

         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

         SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         SET @cOutField09 = @cPUOM_Desc
         SET @cOutField10 = @cMUOM_Desc

         -- (james02)
         IF rdt.RDTGetConfig( @nFunc, 'PPADefaultQTY', @cStorer) <> '1'
         BEGIN
            SET @cOutField11 = ''
            SET @cOutField12 = ''
         END
         ELSE
         BEGIN
            -- (james03)
            IF CAST( @cPieceScanQty AS INT) > 0
            BEGIN
               IF @cFieldAttr11 = 'O'
                  SET @cOutField12 = @cPieceScanQty
               ELSE
               BEGIN
                  SET @cOutField11 = @cPieceScanQty
                  SET @cOutField12 = ''
               END
            END
            ELSE
            BEGIN
               SET @cOutField11 = @nPQTY
               SET @cOutField12 = @nMQTY
            END
         END

         IF @nPQTY > 0
            EXEC rdt.rdtSetFocusField @nMobile, 11
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 12

         -- Goto QTY screen
         SET @nScn = @nScn_Qty
         SET @nStep = @nStep_Qty
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nCountSKU = 0
      SET @nCountChkSKU = 0
      SET @nSumQTY = 0
      SET @nSumChkQTY = 0
      SET @cPickStatus = ''

      IF @cPPAType = '1'
      BEGIN
            SELECT @nCountSKU = Count(Distinct PD.SKU), @nSumQty = ISNULL(SUM(PD.QTY), 0) FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = LPD.Orderkey
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.Orderkey = O.Orderkey AND PD.Storerkey = O.Storerkey )
            WHERE LPD.Loadkey = @cLoadkey
            AND O.Storerkey = @cStorer

            SELECT @nCountChkSKU = COUNT (DISTINCT PPA.SKU) ,  @nSumChkQTY = SUM(PPA.CQTY)
            FROM rdt.rdtPPA PPA WITH (NOLOCK)
            WHERE PPA.PickSlipNo = @cPickSlipNo
            AND Storerkey = @cStorer

      END

      IF @cPPAType = '2'
      BEGIN
           SELECT @nCountSKU = Count(Distinct SKU), @nSumQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
           WHERE Storerkey = @cStorer
           AND PickSlipNo = @cPickSlipNo

           SELECT @nCountChkSKU = COUNT (DISTINCT PPA.SKU) ,  @nSumChkQTY = SUM(PPA.CQTY)
            FROM rdt.rdtPPA PPA WITH (NOLOCK)
            WHERE PPA.PickSlipNo = @cPickSlipNo
            AND Storerkey = @cStorer

      END

      IF @cPPAType = '3'
      BEGIN
           SELECT @nCountSKU = Count(Distinct SKU), @nSumQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
           WHERE Storerkey = @cStorer
           AND Orderkey = @cOrderkey

            SELECT @nCountChkSKU = COUNT (DISTINCT PPA.SKU) ,  @nSumChkQTY = SUM(PPA.CQTY)
            FROM rdt.rdtPPA PPA WITH (NOLOCK)
            WHERE PPA.PickSlipNo = @cPickSlipNo
            AND Storerkey = @cStorer
      END

      IF @cPPAType = '4'
      BEGIN

           SELECT @nCountSKU = Count(Distinct SKU), @nSumQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
           WHERE Storerkey = @cStorer
           AND DropID = @cDropID

            SELECT @nCountChkSKU = COUNT (DISTINCT PPA.SKU) ,  @nSumChkQTY = SUM(PPA.CQTY)
            FROM rdt.rdtPPA PPA WITH (NOLOCK)
            WHERE PPA.DropID = @cDropID
            AND Storerkey = @cStorer
      END

      IF @cPPAType = '5'
      BEGIN
           SELECT @nCountSKU = Count(Distinct PD.SKU), @nSumQty = ISNULL(SUM(PD.QTY), 0)
           FROM dbo.OrderDetail AS OD WITH (NOLOCK)
            INNER JOIN dbo.PickDetail AS PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            INNER JOIN dbo.LoadPlan AS LP WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
           WHERE LP.UserDefine10 = @cRefNo
            AND OD.StorerKey = @cStorer
            AND OD.SKU = @cSKU

            SELECT @nCountChkSKU = COUNT (DISTINCT PPA.SKU) ,  @nSumChkQTY = SUM(PPA.CQTY)
            FROM rdt.rdtPPA PPA WITH (NOLOCK)
            WHERE PPA.PickSlipNo = @cPickSlipNo
            AND Storerkey = @cStorer
      END


      IF (@nCountSKU = @nCountChkSKU) AND (@nSumQty = @nSumChkQTY)
      BEGIN
         SET @cPickStatus = 'COMPLETED'
      END
      ELSE
      BEGIN
         SET @cPickStatus = 'NOT COMPLETED'
      END

      -- Prepare Order Summary screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadkey
      SET @cOutField04 = @cOrderkey
      SET @cOutField05 = @cDropID

      SET @cOutField06 = @nCountChkSKU
      SET @cOutField07 = @nCountSKU
      SET @cOutField08 = @nSumChkQTY
      SET @cOutField09 = @nSumQTY
      SET @cOutField10 = @cPickStatus

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
       -- End

      -- Go to prev screen
      SET @nScn = @nScn_OrderSummary
      SET @nStep = @nStep_OrderSummary
   END
   GOTO Quit

   SKU_Fail:
   BEGIN


      SET @cOutField06 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Scn = 2612. Lottable
   LottableLabel01   (field01, display)
   Lottable01        (field02)
   LottableLabel02   (field03, display)
   Lottable02        (field04)
   LottableLabel03   (field05, display)
   Lottable03        (field06)
   LottableLabel04   (field07, display)
   Lottable04        (field08)
   LottableLabel05   (field09, display)
   Lottable05        (field10)
********************************************************************************/
Step_Lottables1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SELECT
         @cLottable01 = CASE WHEN @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL THEN @cInField02 ELSE '' END,
         @cLottable02 = CASE WHEN @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL THEN @cInField04 ELSE '' END,
         @cLottable03 = CASE WHEN @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL THEN @cInField06 ELSE '' END,
         @cLottable04 = CASE WHEN @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL THEN @cInField08 ELSE '' END,
         @cLottable05 = CASE WHEN @cLotlabel05 <> '' AND @cLotlabel05 IS NOT NULL THEN @cInField10 ELSE '' END


      --  - Start
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
      --  - End

/********************************************************************************************************************/
/* SOS#81879 - Start                                                                                                */
/* Generic Lottables Computation (POST): To compute Lottables after input of Lottable value                         */
/* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
/* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
/* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
/*    Codelkup.Short = 'POST' and Codelkup.Long = <SP Name>                                                         */
/********************************************************************************************************************/


		--initiate @nCounter = 1
		SET @nCountLot = 1

		WHILE @nCountLot < = 5
		BEGIN
		  IF @nCountLot = 1
	     BEGIN
	          SET @cListName = 'Lottable01'
	          SET @cLottableLabel = @cLottable01_Code
	     END
	     ELSE
		  IF @nCountLot = 2
	     BEGIN
	          SET @cListName = 'Lottable02'
	          SET @cLottableLabel = @cLottable02_Code
	     END
	     ELSE
		  IF @nCountLot = 3
	     BEGIN
	          SET @cListName = 'Lottable03'
	          SET @cLottableLabel = @cLottable03_Code
	     END
	     ELSE
		  IF @nCountLot = 4
	     BEGIN
	          SET @cListName = 'Lottable04'
	            SET @cLottableLabel = @cLottable04_Code
	     END
	     ELSE
		  IF @nCountLot = 5
	     BEGIN
	          SET @cListName = 'Lottable05'
	          SET @cLottableLabel = @cLottable05_Code
	     END

        DECLARE @cTempSKU NVARCHAR(15)

        SET @cShort = ''
        SET @cStoredProd = ''
        SET @cTempSKU = ''
		  SELECT TOP 1 @cShort = C.Short,
				   @cStoredProd = IsNULL( C.Long, '')
		  FROM DBO.CodeLkUp C WITH (NOLOCK)
		  WHERE C.Listname = @cListName
		  AND   C.Code = @cLottableLabel
        AND (C.StorerKey = @cStorer OR C.Storerkey = '') 	--SOS353781
        ORDER BY C.StorerKey DESC									--SOS353781

		  IF @cShort = 'POST' AND @cStoredProd <> ''
		  BEGIN
           IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date
   			  SET @dLottable04 = rdt.rdtConvertToDate( @cLottable04)

           IF rdt.rdtIsValidDate(@cLottable05) = 1 --valid date
			     SET @dLottable05 = rdt.rdtConvertToDate( @cLottable05)

	        IF  @cPrePackByBOM = '1'
	        BEGIN
	         SELECT @cTempSKU = ''
	        END
           ELSE
           BEGIN
             SELECT @cTempSKU = @cSku
           END


           SET @cSourcekey = ''

		     EXEC DBO.ispLottableRule_Wrapper
					  @c_SPName            = @cStoredProd,
					  @c_ListName          = @cListName,
					  @c_Storerkey         = @cStorer,
					  @c_Sku               = @cSku,
					  @c_LottableLabel     = @cLottableLabel,
					  @c_Lottable01Value   = @cLottable01,
					  @c_Lottable02Value   = @cLottable02,
					  @c_Lottable03Value   = @cLottable03,
					  @dt_Lottable04Value  = @dLottable04,
					  @dt_Lottable05Value  = @dLottable05,
					  @c_Lottable01        = @cTempLottable01 OUTPUT,
					  @c_Lottable02        = @cTempLottable02 OUTPUT,
					  @c_Lottable03        = @cTempLottable03 OUTPUT,
					  @dt_Lottable04       = @dTempLottable04 OUTPUT,
					  @dt_Lottable05       = @dTempLottable05 OUTPUT,
					  @b_Success           = @b_Success   OUTPUT,
					  @n_Err               = @nErrNo      OUTPUT,
					  @c_Errmsg            = @cErrMsg     OUTPUT,
--				     @c_Sourcekey         = @cReceiptKey,
				     @c_Sourcekey         = @cSourcekey,
				     @c_Sourcetype        = 'RDTPICK'

                 --IF @b_success <> 1
                 IF ISNULL(@cErrMsg, '') <> ''
                 BEGIN
  				        SET @cErrMsg = @cErrMsg

                    IF @cListName = 'Lottable01'
                       EXEC rdt.rdtSetFocusField @nMobile, 2
                    ELSE IF @cListName = 'Lottable02'
                       EXEC rdt.rdtSetFocusField @nMobile, 4
                    ELSE IF @cListName = 'Lottable03'
                       EXEC rdt.rdtSetFocusField @nMobile, 6
                    ELSE IF @cListName = 'Lottable04'
                       EXEC rdt.rdtSetFocusField @nMobile, 8


                    GOTO Step_Lottables_Fail
                 END


					  SET @cTempLottable01 = IsNULL( @cTempLottable01, '')
					  SET @cTempLottable02 = IsNULL( @cTempLottable02, '')
					  SET @cTempLottable03 = IsNULL( @cTempLottable03, '')
					  SET @dTempLottable04 = IsNULL( @dTempLottable04, 0)
					  SET @dTempLottable05 = IsNULL( @dTempLottable05, 0)


					  SET @cOutField02 = CASE WHEN @cTempLottable01 <> '' THEN @cTempLottable01 ELSE @cLottable01 END
					  SET @cOutField04 = CASE WHEN @cTempLottable02 <> '' THEN @cTempLottable02 ELSE @cLottable02 END
					  SET @cOutField06 = CASE WHEN @cTempLottable03 <> '' THEN @cTempLottable03 ELSE @cLottable03 END
					  SET @cOutField08 = CASE WHEN @dTempLottable04 <> 0  THEN rdt.rdtFormatDate( @dTempLottable04) ELSE @cLottable04 END

                 SET @cLottable01 = IsNULL(@cOutField02, '')
                 SET @cLottable02 = IsNULL(@cOutField04, '')
					  SET @cLottable03 = IsNULL(@cOutField06, '')
                 SET @cLottable04 = IsNULL(@cOutField08, '')

        END -- Short

			--increase counter by 1
			SET @nCountLot = @nCountLot + 1

      END -- end of while


      -- Validate lottable01
      IF @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL
      BEGIN
         --SET @cLottable01 = @cOutField02--@cInField02
         IF @cLottable01 = '' OR @cLottable01 IS NULL
         BEGIN
            SET @nErrNo = 71615
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable01 required'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Lottables_Fail
         END

       -- Validation agaist PickDetail Lot
       SET @nErrNo = 0

       EXEC [RDT].[rdtfnc_PostPickAudit_SKULottable_Validate]
        @nMobile
       ,@nFunc
       ,@cStorer
       ,@cUserName
       ,@cFacility
       ,@cRefNo
       ,@cPickslipNo
       ,@cLoadkey
       ,@cOrderkey
       ,@cDropID
       ,'1'
       ,@cLottable01
       ,@cSKU
       ,@cPPAType -- 1 = Loadkey , 2 = PSNO , 3 = OrderKey , 4 = DropID
       ,@cLangCode
       ,@nErrNo  OUTPUT
       ,@cErrMsg OUTPUT -- screen limitation, 20 char max


       IF @nErrNo <> 0
       BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_Lottables_Fail
       END

      END

      -- Validate lottable02
      IF @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL
      BEGIN
         IF @cLottable02 = '' OR @cLottable02 IS NULL
         BEGIN
            SET @nErrNo = 71616
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable02 required'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Step_Lottables_Fail
         END

         -- Validation agaist PickDetail Lot
       SET @nErrNo = 0

       EXEC [RDT].[rdtfnc_PostPickAudit_SKULottable_Validate]
        @nMobile
       ,@nFunc
       ,@cStorer
       ,@cUserName
       ,@cFacility
       ,@cRefNo
       ,@cPickslipNo
       ,@cLoadkey
       ,@cOrderkey
       ,@cDropID
       ,'2'
       ,@cLottable02
       ,@cSKU
       ,@cPPAType -- 1 = Loadkey , 2 = PSNO , 3 = OrderKey , 4 = DropID
       ,@cLangCode
       ,@nErrNo  OUTPUT
       ,@cErrMsg OUTPUT -- screen limitation, 20 char max


       IF @nErrNo <> 0
       BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_Lottables_Fail
       END
      END

      -- Validate lottable03
      IF @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL
      BEGIN
         IF @cLottable03 = '' OR @cLottable03 IS NULL
         BEGIN
            SET @nErrNo = 71617
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable03 required'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Step_Lottables_Fail
         END

         -- Validation agaist PickDetail Lot
       SET @nErrNo = 0

       EXEC [RDT].[rdtfnc_PostPickAudit_SKULottable_Validate]
        @nMobile
       ,@nFunc
       ,@cStorer
       ,@cUserName
       ,@cFacility
       ,@cRefNo
       ,@cPickslipNo
       ,@cLoadkey
       ,@cOrderkey
       ,@cDropID
       ,'3'
       ,@cLottable03
       ,@cSKU
       ,@cPPAType -- 1 = Loadkey , 2 = PSNO , 3 = OrderKey , 4 = DropID
       ,@cLangCode
       ,@nErrNo  OUTPUT
       ,@cErrMsg OUTPUT -- screen limitation, 20 char max


       IF @nErrNo <> 0
       BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_Lottables_Fail
       END
  		END

      -- Validate lottable04
      IF @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL
      BEGIN
         -- Validate empty
       IF @cLottable04 = '' OR @cLottable04 IS NULL
         BEGIN
            SET @nErrNo = 71618
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable04 required'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Step_Lottables_Fail
         END
         -- Validate date
         IF RDT.rdtIsValidDate( @cLottable04) = 0
         BEGIN
            SET @nErrNo = 71619
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Step_Lottables_Fail
         END

         -- Validation agaist PickDetail Lot
       SET @nErrNo = 0

       EXEC [RDT].[rdtfnc_PostPickAudit_SKULottable_Validate]
        @nMobile
       ,@nFunc
       ,@cStorer
       ,@cUserName
       ,@cFacility
       ,@cRefNo
       ,@cPickslipNo
       ,@cLoadkey
       ,@cOrderkey
       ,@cDropID
       ,'4'
       ,@cLottable04
       ,@cSKU
       ,@cPPAType -- 1 = Loadkey , 2 = PSNO , 3 = OrderKey , 4 = DropID
       ,@cLangCode
       ,@nErrNo  OUTPUT
       ,@cErrMsg OUTPUT -- screen limitation, 20 char max


      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Step_Lottables_Fail
      END

       SET @dLottable04 = rdt.rdtConvertToDate( @cLottable04)

      END

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorer)
      IF @cExtendedUpdateSP NOT IN ('0', '')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, ' +
            ' @cRefNo, @cPickSlipNo, @cLoadkey, @cOrderkey, @cDropID, @cPPAType, ' +  
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' + 
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' + 
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' + 
            ' @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,  ' +
            '@nFunc           INT,  ' +   
            '@nStep           INT,  ' +
            '@nInputKey       INT,  ' +
            '@cLangCode    	NVARCHAR( 3),   ' +
            '@cStorerKey   	NVARCHAR( 15),  ' +
            '@cRefNo       	NVARCHAR( 10),  ' +
            '@cPickSlipNo  	NVARCHAR( 10),  ' +
            '@cLoadkey     	NVARCHAR( 10),  ' +
            '@cOrderkey    	NVARCHAR( 10),  ' +
            '@cDropID      	NVARCHAR( 20),  ' +
            '@cPPAType     	NVARCHAR( 1),   ' +
            '@cLottable01  	NVARCHAR( 18),  ' +
            '@cLottable02  	NVARCHAR( 18),  ' +
            '@cLottable03  	NVARCHAR( 18),  ' +
            '@dLottable04  	DATETIME,       ' +
            '@dLottable05  	DATETIME,       ' +
            '@cLottable06  	NVARCHAR( 30),  ' +
            '@cLottable07  	NVARCHAR( 30),  ' +
            '@cLottable08  	NVARCHAR( 30),  ' +
            '@cLottable09  	NVARCHAR( 30),  ' +
            '@cLottable10  	NVARCHAR( 30),  ' +
            '@cLottable11  	NVARCHAR( 30),  ' +
            '@cLottable12  	NVARCHAR( 30),  ' +
            '@dLottable13  	DATETIME,  ' +
            '@dLottable14  	DATETIME,  ' +
            '@dLottable15  	DATETIME,  ' +
            '@cSKU         	NVARCHAR( 20),  ' + 
            '@nQTY         	INT,  ' +
            '@nErrNo          INT           OUTPUT,  ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, 
            @cRefNo, @cPickSlipNo, @cLoadkey, @cOrderkey, @cDropID, @cPPAType, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EXT UPD FAIL'
            GOTO Quit
         END
      END

      IF @cPPAType = '1'
         SELECT @nSum_PalletQty = ISNULL(SUM(PD.QTY), 0) FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = LPD.Orderkey
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.Orderkey = O.Orderkey AND PD.Storerkey = O.Storerkey )
         WHERE LPD.Loadkey = @cLoadkey
         AND PD.SKU = @cSKU
         AND O.Storerkey = @cStorer

      IF @cPPAType = '2'
         SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
         WHERE SKU = @cSKU
         AND Storerkey = @cStorer
         AND PickSlipNo = @cPickSlipNo

      IF @cPPAType = '3'
         SELECT @nSum_PalletQty = ISNULL(SUM(PQTY), 0) 
         FROM rdt.rdtPPA WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND   StorerKey = @cStorer
         AND   SKU = @cSKU

      IF @cPPAType = '4'
          SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)
          WHERE SKU = @cSKU
          AND Storerkey = @cStorer
          AND DropID = @cDropID

      IF @cPPAType = '5'
         SELECT @nSum_PalletQty = SUM( PD.QTY)
         FROM dbo.OrderDetail AS OD WITH (NOLOCK)
            INNER JOIN dbo.PickDetail AS PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            INNER JOIN dbo.LoadPlan AS LP WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
         WHERE LP.UserDefine10 = @cRefNo
            AND OD.StorerKey = @cStorer
            AND OD.SKU = @cSKU

      -- Prepare Next Screen Var --
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
         --IF ISNULL(@cAltSKU, '') = ''
         --BEGIN
            SET @nPQTY = @nSum_PalletQty / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nSum_PalletQty % @nPUOM_Div  -- Calc the remaining in master unit
         --END
--         ELSE
--         BEGIN
--            SET @nPQTY = @nSum_PalletQty / (@nSUMBOM_Qty * @nPUOM_Div)  -- Calc QTY in preferred UOM
--            SET @nMQTY = @nSum_PalletQty % (@nSUMBOM_Qty * @nPUOM_Div)  -- Calc the remaining in master unit
--         END
      END

          -- Prepare QTY screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2



         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)


         IF @cPUOM_Desc = ''
         BEGIN

            SET @cOutField08 = '1:1' -- @nPUOM_Div
            SET @cOutField09 = '' -- @cPUOM_Desc
            SET @cOutField11 = '' -- @nPQTY

            SET @cFieldAttr11 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
            SET @cOutField09 = @cPUOM_Desc
            SET @cOutField11 = '' -- @nPQTY
            --SET @cOutField11 = CAST( @nPQTY AS NVARCHAR( 5))
         END

         SET @cOutField10 = @cMUOM_Desc -- SOS# 176725

         IF @nPQTY <= 0
         BEGIN
            --SET @cOutField07 = ''
            SET @cOutField11 = ''
            SET @cInField11 = ''
            SET @cFieldAttr11 = 'O'
         END



         IF @nMQTY > 0
         BEGIN
            --SET @cOutField08 = CAST( @nMQTY as NVARCHAR( 5))
            SET @cInField12 = ''
            SET @cFieldAttr12 = ''
         END
         ELSE
         BEGIN
            --SET @cOutField08 = ''
            SET @cInField12 = ''
            SET @cFieldAttr12 = 'O'
         END

         IF @nPQTY > 0
            EXEC rdt.rdtSetFocusField @nMobile, 11
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 12

         -- (james02)
         IF rdt.RDTGetConfig( @nFunc, 'PPADefaultQTY', @cStorer) <> '1'
         BEGIN
            SET @cOutField11 = ''
            SET @cOutField12 = ''
         END
         ELSE
         BEGIN
            -- (james03)
            IF ISNULL( @cPieceScanQty, 0) > 0
            BEGIN
               IF @cFieldAttr11 = 'O'
                  SET @cOutField12 = @cPieceScanQty
               ELSE
               BEGIN
                  SET @cOutField11 = @cPieceScanQty
                  SET @cOutField12 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 11
               END
            END
            ELSE
            BEGIN
               SET @cOutField11 = @nPQTY
               SET @cOutField12 = @nMQTY
            END
         END

      -- Go to prev screen
      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty

   END
/********************************************************************************************************************/
/* SOS#81879 - End                                                                                                  */
/* Generic Lottables Computation (POST): To compute Lottables after input of Lottable value                         */
/********************************************************************************************************************/

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Go back to prev screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU

      -- Load prev screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadkey
      SET @cOutField04 = @cOrderkey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = ''


   	SET @cLottable01 = ''
	   SET @cLottable02 = ''
		SET @cLottable03 = ''
		SET @dLottable04 = 0
		SET @dLottable05 = 0
      SET @cLottable04 = ''

      --  - Start
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
      --  - End
   END
   GOTO Quit

   Step_Lottables_Fail:
   BEGIN
      --  - Start
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''
      --  - End

      -- Init next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Disable lottable
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O' --
            SET @cOutField02 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O' --
            SET @cOutField04 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
              SET @cFieldAttr06 = 'O' --
              SET @cOutField06 = ''

            -- (Vicky07) - End
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O' --
            SET @cOutField08 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
         END

         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
         BEGIN
            SET @cFieldAttr10 = 'O' --
            SET @cOutField10 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Scn = 2613. QTY screen
  SKU
  SKU       (Field01)
  DESCR     (Field02)
  DESCR     (Field03)
  LOTTABLE 1/2/3/4
  Lottable1 (Field04)
  Lottable2 (Field05)
  Lottable3 (Field06)
  Lottable4 (Field07)
  UOM:PrefferedUOM     (Field10):(Field11)
  QTY                  (Field12,Input) (Field13,Input)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN

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
      -- End

      IF ISNULL(@cPUOM_Desc, '') <> ''
      BEGIN
         SET @cActPQTY = IsNULL( @cInField11, '')
         SET @cSuggestPQTY = @nPQTY
      END

      SET @cActMQTY = IsNULL( @cInField12, '')
      SET @cSuggestMQTY = @nMQTY

      IF ISNULL(@cActPQTY, '') = '' SET @cActPQTY = '0' -- Blank taken as zero
      IF ISNULL(@cActMQTY, '') = '' SET @cActMQTY = '0' -- Blank taken as zero


      -- Validate ActPQTY
      IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 71620
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 09 -- PQTY
         GOTO Qty_Fail
      END

       -- Validate ActMQTY
      IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 71621
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY
         GOTO Qty_Fail
      END


       -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)
      SET @nActQTY = 0
      -- (james04)
--      IF ISNULL(@cAltSKU, '') = ''
--         SET @nActQTY = ISNULL(rdt.rdtConvUOMQTY( @cTaskStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
--      ELSE

      SET @nActQTY = ISNULL(rdt.rdtConvUOMQTY( @cStorer, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM

      SET @nActQTY = @nActQTY + @nActMQTY



      -- Validate QTY
      IF @nActQTY = 0
      BEGIN
         -- Go to Short Pick screen

         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''


         -- Go to Short Pick Screen
         SET @nScn  = @nScn_ShortPick
         SET @nStep = @nStep_ShortPick

         GOTO QUIT
      END

      -- Calc total QTY in master UOM
      SET @nSuggestPQTY = 0
      SET @nSuggestMQTY = 0
      SET @nSuggestPQTY = CAST( @cSuggestPQTY AS INT)
      SET @nSuggestMQTY = CAST( @cSuggestMQTY AS INT)

      SET @nSuggestQTY = 0
      SET @nSuggestQTY = ISNULL(rdt.rdtConvUOMQTY( @cStorer, @cSKU, @nSuggestPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM
      SET @nSuggestQTY = @nSuggestQTY + @nSuggestMQTY

      SET @nCheckQty = 0

      IF @cPPAType = '1'
      BEGIN
         SELECT @nCheckQty = CQTY
         FROM rdt.RDTPPA WITH (NOLOCK)
         WHERE Loadkey = @cLoadkey
         AND Storerkey = @cStorer
         AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
         AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
         AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
         AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
         AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
         AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
         AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
         AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
         AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
         AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
         AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
         AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
         AND STATUS < '9'
      END

      IF @cPPAType = '2'
      BEGIN
         SELECT @nCheckQty = CQTY
         FROM rdt.RDTPPA WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND Storerkey = @cStorer
         AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
         AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
         AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
         AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
         AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
         AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
         AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
         AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
         AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
         AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
         AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
         AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
         AND STATUS < '9'
      END

      IF @cPPAType = '3'
      BEGIN
         SELECT @nCheckQty = CQTY
         FROM rdt.RDTPPA WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
         AND Storerkey = @cStorer
         AND SKU = @cSKU
         AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
         AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
         AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
         AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
         AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
         AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
         AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
         AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
         AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
         AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
         AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
         AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
         AND STATUS < '9'
      END

      IF @cPPAType = '4'
      BEGIN
         SELECT @nCheckQty = CQTY
         FROM rdt.RDTPPA WITH (NOLOCK)
         WHERE DropID = @cDropID
         AND Storerkey = @cStorer
         AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
         AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
         AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
         AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
         AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
         AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
         AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
         AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
         AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
         AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
         AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
         AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
         AND STATUS < '9'
      END

      IF @cPPAType = '5'
      BEGIN
         SELECT @nCheckQty = CQTY
         FROM rdt.RDTPPA WITH (NOLOCK)
         WHERE Refkey = @cRefNo
         AND Storerkey = @cStorer
         AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
         AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
         AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
         AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
         AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
         AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
         AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
         AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
         AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
         AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
         AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
         AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
         AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
         AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
         AND STATUS < '9'
      END


      IF @nActQTY > @nSuggestQTY
      BEGIN
         SET @nErrNo = 71622
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY > Suggest'
         IF @cPUOM_Desc = ''
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 10
         END
         GOTO Qty_Fail
      END

      IF @nCheckQty > @nSuggestQTY
      BEGIN
         SET @nErrNo = 71626
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY > Suggest'
         IF @cPUOM_Desc = ''
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 10
         END
         GOTO Qty_Fail
      END

      IF (@nCheckQty + @nActQty) >  @nSuggestQTY
      BEGIN
         SET @nErrNo = 71626
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY > Suggest'
         IF @cPUOM_Desc = ''
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 10
         END
         GOTO Qty_Fail
      END

      -- Go to Short Pick
      -- Only goto Short Pick when Current Check Qty + Checked Qty < PickedQty
      -- If piece scanning turn on then skip this function. User has to key in 0 for short pick
      IF (@nActQTY + @nCheckQty) < @nSuggestQTY AND CAST( @cPieceScanQty AS INT) = 0
      BEGIN
         -- Go to Reason Code screen

         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''

         -- Go to Short Pick Screen
         SET @nScn  = @nScn_ShortPick
         SET @nStep = @nStep_ShortPick

         GOTO QUIT
      END

      -- Confirm Checking --
      SET @cErrMsg = ''
      -- Confirm Checking --
      -- Update check QTY, increment check count
      BEGIN TRAN

      IF @cPPAType = '1'
      BEGIN
            UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
               CQTY = CQTY + @nActQty ,
               NoOfCheck = NoOfCheck + 1
            WHERE Loadkey = @cLoadkey
            AND Storerkey = @cStorer
            AND SKU = @cSKU
            AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
            AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
            AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
            AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
            AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
            AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
            AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
            AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
            AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
            AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
            AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
            AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
            AND   STATUS < '9'
      END

      IF @cPPAType = '2'
      BEGIN
            UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
               CQTY = CQTY + @nActQty ,
               NoOfCheck = NoOfCheck + 1
            WHERE PickSlipNo = @cPickSlipNo
            AND Storerkey = @cStorer
            AND SKU = @cSKU
            AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
            AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
            AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
            AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
            AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
            AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
            AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
            AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
            AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
            AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
            AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
            AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
            AND   STATUS < '9'
      END

      IF @cPPAType = '3'
      BEGIN
            UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
               CQTY = CQTY + @nActQty ,
               NoOfCheck = NoOfCheck + 1
            WHERE Orderkey = @cOrderkey
            AND   Storerkey = @cStorer
            AND   SKU = @cSKU
            AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
            AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
            AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
            AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
            AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
            AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
            AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
            AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
            AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
            AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
            AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
            AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
            AND   STATUS < '9'
      END

      IF @cPPAType = '4'
      BEGIN
            UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
               CQTY = CQTY + @nActQty ,
               NoOfCheck = NoOfCheck + 1
            WHERE DropID = @cDropID
            AND Storerkey = @cStorer
            AND SKU = @cSKU
            AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
            AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
            AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
            AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
            AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
            AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
            AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
            AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
            AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
            AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
            AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
            AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
            AND   STATUS < '9'
      END

      IF @cPPAType = '5'
      BEGIN
            UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
               CQTY = CQTY + @nActQty ,
               NoOfCheck = NoOfCheck + 1
            WHERE Refkey = @cRefNo
            AND Storerkey = @cStorer
            AND SKU = @cSKU
            AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
            AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
            AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
            AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
            AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
            AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
            AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
            AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
            AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
            AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
            AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
            AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
            AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
            AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
            AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END
            AND   STATUS < '9'
      END



      IF @@ERROR <> 0
		BEGIN
		   	SET @nErrNo = 71623
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPPAFailed'
				ROLLBACK TRAN
				GOTO Qty_Fail
		END
		ELSE
		BEGIN
			  COMMIT TRAN
		END

      --event log --(cc01)
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '3', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorer,
        @csku        = @cSKU,
        @nQTY        = @cActPQTY,
        @cPickSlipNo = @cPickSlipNo,
        @cLoadKey    = @cLoadKey,
        @cOrderKey   = @cOrderKey,
        @cDropID     = @cDropID,
        @cRefNo1     = @cRefNo
        
     
      IF rdt.RDTGetConfig( @nFunc, 'PPADropIDSingleSKU', @cStorer) = '1'
      BEGIN
         -- (james02)
         SET @cPPASKULottableDefCursor = ''
         SET @cPPASKULottableDefCursor = rdt.RDTGetConfig( @nFunc, 'PPASKULottableDefCursor', @cStorer)

         IF @cPPASKULottableDefCursor = '1'
            EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @cPPASKULottableDefCursor = '2'
            EXEC rdt.rdtSetFocusField @nMobile, 2

         IF @cPPASKULottableDefCursor = '3'
            EXEC rdt.rdtSetFocusField @nMobile, 3

         IF @cPPASKULottableDefCursor = '4'
            EXEC rdt.rdtSetFocusField @nMobile, 4

         IF @cPPASKULottableDefCursor = '5'
            EXEC rdt.rdtSetFocusField @nMobile, 5

         -- Prepare PickSlipNo screen var
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''


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
         -- End

         -- Go to PickSlipNo screen
         SET @nScn = @nScn_Criteria
         SET @nStep = @nStep_Criteria
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cRefNo
         SET @cOutField02 = @cPickSlipNo
         SET @cOutField03 = @cLoadkey
         SET @cOutField04 = @cOrderkey
         SET @cOutField05 = @cDropID
         SET @cOutField06 = ''

         -- Go to prev screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU

          -- EventLog - Sign In Function
   --       EXEC RDT.rdt_STD_EventLog
   --          @cActionType = '9', -- In Progress
   --          @cUserID     = @cUserName,
   --          @nMobileNo   = @nMobile,
   --          @nFunctionID = @nFunc,
   --          @cFacility   = @cFacility,
   --          @cStorerKey  = @cStorer

      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      -- Go to SKU screen
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadkey
      SET @cOutField04 = @cOrderkey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = ''


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
      -- End

      -- Go to prev screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
   GOTO Quit

   QTY_Fail:
   BEGIN
       -- Start
      SET @cFieldAttr14 = ''
       -- End

      -- Prepare QTY screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2


         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)


         IF @cPUOM_Desc = ''
         BEGIN

            SET @cOutField08 = '1:1' -- @nPUOM_Div
            SET @cOutField09 = '' -- @cPUOM_Desc
            SET @cOutField11 = '' -- @nPQTY

            SET @cFieldAttr11 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
            SET @cOutField09 = @cPUOM_Desc
            --SET @cOutField11 = CAST( @nPQTY AS NVARCHAR( 5))
            SET @cOutField11 = '' -- @nPQTY
         END


         IF @nPQTY <= 0
         BEGIN
            --SET @cOutField07 = ''
            SET @cOutField11 = ''
            SET @cInField11 = ''
            SET @cFieldAttr11 = 'O'
         END



         IF @nMQTY > 0
         BEGIN
            --SET @cOutField08 = CAST( @nMQTY as NVARCHAR( 5))
            SET @cInField12 = ''
            SET @cFieldAttr12 = ''
         END
         ELSE
         BEGIN
            --SET @cOutField08 = ''
            SET @cInField12 = ''
            SET @cFieldAttr12 = 'O'
         END

         IF @nPQTY > 0
            EXEC rdt.rdtSetFocusField @nMobile, 11
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 12

         -- (james02)
         IF rdt.RDTGetConfig( @nFunc, 'PPADefaultQTY', @cStorer) <> '1'
         BEGIN
            SET @cOutField11 = ''
            SET @cOutField12 = ''
         END
         ELSE
         BEGIN
            -- (james03)
            IF ISNULL( @cPieceScanQty, 0) > 0
            BEGIN
               IF @cFieldAttr11 = 'O'
                  SET @cOutField12 = @cPieceScanQty
               ELSE
               BEGIN
                  SET @cOutField11 = @cPieceScanQty
                  SET @cOutField12 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 11
               END
            END
            ELSE
            BEGIN
               SET @cOutField11 = @nPQTY
               SET @cOutField12 = @nMQTY
            END
         END
   END

END
GOTO Quit


/********************************************************************************
Scn = 2614. Message. 'REASON CODE'
   REASON CODE (field01, input)
********************************************************************************/
Step_ShortPick:
BEGIN
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
    -- End

   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReasonCode = ISNULL(RTRIM(@cInField01),'')
      SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)

      -- Validate option
      IF @cReasonCode = ''
      BEGIN
         SET @nErrNo = 71624
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Reason
         GOTO ShortPick_Option_Fail
      END

      SET @cReasonDesc = ''
      IF @cReasonDesc = ''
      BEGIN
         SELECT @cReasonDesc = Description FROM dbo.CodeLKup WITH (NOLOCK)
         WHERE Listname = 'PPAREASON'
         AND Code = @cReasonCode
      END

      IF @cReasonDesc = ''
      BEGIN
            SET @nErrNo = 71625
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Bad ReasonCode
            GOTO ShortPick_Option_Fail
      END


      BEGIN TRAN

      IF @cPPAType = '1'
      BEGIN
         UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
            CQTY = CQTY + @nActQty ,
            NoOfCheck = NoOfCheck + 1
         WHERE Loadkey = @cLoadkey
         AND Storerkey = @cStorer
         AND SKU = @cSKU
      END

      IF @cPPAType = '2'
      BEGIN
         UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
            CQTY = CQTY + @nActQty ,
            NoOfCheck = NoOfCheck + 1
         WHERE PickSlipNo = @cPickSlipNo
         AND Storerkey = @cStorer
         AND SKU = @cSKU
      END

      IF @cPPAType = '3'
      BEGIN
         UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
            CQTY = CQTY + @nActQty ,
            NoOfCheck = NoOfCheck + 1
         WHERE Orderkey = @cOrderkey
         AND Storerkey = @cStorer
         AND SKU = @cSKU
      END

      IF @cPPAType = '4'
      BEGIN
         UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
            CQTY = CQTY + @nActQty ,
            NoOfCheck = NoOfCheck + 1
         WHERE DropID = @cDropID
         AND Storerkey = @cStorer
         AND SKU = @cSKU
      END

      IF @cPPAType = '5'
      BEGIN
         UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
            CQTY = CQTY + @nActQty ,
            NoOfCheck = NoOfCheck + 1
         WHERE Refkey = @cRefNo
         AND Storerkey = @cStorer
         AND SKU = @cSKU
      END

      IF @@ERROR <> 0
		BEGIN
   	   SET @nErrNo = 71623
		   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPPAFailed'
		   ROLLBACK TRAN
		   GOTO Qty_Fail
		END
		ELSE
		BEGIN
			COMMIT TRAN
		END
		
      --event log --(cc01)
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '3', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorer,
        @csku        = @cSKU,
        @nQTY        = @cActPQTY,
        @cPickSlipNo = @cPickSlipNo,
        @cLoadKey    = @cLoadKey,
        @cOrderKey   = @cOrderKey,
        @cDropID     = @cDropID,
        @cRefNo1     = @cRefNo,
        @cReasonKey  = @cReasonCode
        
        
      -- Insert WMS Supervisor Alert --
      SET @c_AlertMessage = ' RDT Post Pick Audit  ' + @c_NewLineChar

      IF @cPPAType = '1'
      BEGIN
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'LOADKEY:'      +  @cLoadkey      + @c_NewLineChar
      END

      IF @cPPAType = '2'
      BEGIN
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'PSNO:'         +  @cPickSlipNo   + @c_NewLineChar
      END

      IF @cPPAType = '3'
      BEGIN
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'ORDERKEY:'     +  @cOrderkey     + @c_NewLineChar
      END


      IF @cPPAType = '4'
      BEGIN
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'CARTONID:'     +  @cDropID       + @c_NewLineChar
      END


      IF @cPPAType = '5'
      BEGIN
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'REFNO:'        +  @cRefNo        + @c_NewLineChar
      END

      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'StorerKey:'    +  @cStorer       + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'SKU:'          +  @cSKU          + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'Lottable01:'   +  @cLottable01   + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'Lottable02:'   +  @cLottable02   + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'Lottable03:'   +  @cLottable03   + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'Lottable04:'   +  @cLottable04   + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'QTY Check:'    +  CAST( @nActQTY AS NVARCHAR( 5))        + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'QTY Pick:'     +  CAST( @nSuggestQTY AS NVARCHAR( 5))    + @c_NewLineChar
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + 'ReasonCode:'  +  @cReasonDesc   + @c_NewLineChar

      SELECT @b_Success = 1
      EXECUTE dbo.nspLogAlert
         @c_ModuleName   = 'RDT PostPickAudit_SKULottable',
         @c_AlertMessage = @c_AlertMessage,
         @n_Severity     = 0,
         @b_success      = @b_Success OUTPUT,
         @n_err          = @nErrNo OUTPUT,
         @c_errmsg       = @cErrMsg OUTPUT

      IF @nErrNO <> 0
      BEGIN
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
       GOTO ShortPick_Option_Fail
      END

      IF rdt.RDTGetConfig( @nFunc, 'PPADropIDSingleSKU', @cStorer) = '1'
      BEGIN
         -- (james02)
         SET @cPPASKULottableDefCursor = ''
         SET @cPPASKULottableDefCursor = rdt.RDTGetConfig( @nFunc, 'PPASKULottableDefCursor', @cStorer)

         IF @cPPASKULottableDefCursor = '1'
            EXEC rdt.rdtSetFocusField @nMobile, 1

         IF @cPPASKULottableDefCursor = '2'
            EXEC rdt.rdtSetFocusField @nMobile, 2

         IF @cPPASKULottableDefCursor = '3'
            EXEC rdt.rdtSetFocusField @nMobile, 3

         IF @cPPASKULottableDefCursor = '4'
            EXEC rdt.rdtSetFocusField @nMobile, 4

         IF @cPPASKULottableDefCursor = '5'
            EXEC rdt.rdtSetFocusField @nMobile, 5

         -- Prepare PickSlipNo screen var
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''

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
         -- End

         -- Go to PickSlipNo screen
         SET @nScn = @nScn_Criteria
         SET @nStep = @nStep_Criteria
      END
      ELSE
      BEGIN
         -- Prepare Variable for Next Scn
         SET @cOutField01 = @cRefNo
         SET @cOutField02 = @cPickSlipNo
         SET @cOutField03 = @cLoadkey
         SET @cOutField04 = @cOrderkey
         SET @cOutField05 = @cDropID
         SET @cOutField06 = ''

         -- Go to prev screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END   -- 'PPADropIDSingleSKU'
   END

   -- ESC or No
   -- Back to UCC screen
   IF @nInputKey =  0  -- ESC
   BEGIN
      -- Prepare QTY screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2

      SET @cOutField04 = @cLottable01
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)

      SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      SET @cOutField09 = @cPUOM_Desc
      SET @cOutField10 = @cMUOM_Desc

      -- (james02)
      IF rdt.RDTGetConfig( @nFunc, 'PPADefaultQTY', @cStorer) <> '1'
      BEGIN
         SET @cOutField11 = ''
         SET @cOutField12 = ''
      END
      ELSE
      BEGIN
         -- (james03)
         IF ISNULL( @cPieceScanQty, 0) > 0
         BEGIN
            IF @cFieldAttr11 = 'O'
               SET @cOutField12 = @cPieceScanQty
            ELSE
            BEGIN
               SET @cOutField11 = @cPieceScanQty
               SET @cOutField12 = ''
            END
         END
         ELSE
         BEGIN
            SET @cOutField11 = @nPQTY
            SET @cOutField12 = @nMQTY
         END
      END

      IF @nPQTY > 0
         EXEC rdt.rdtSetFocusField @nMobile, 11
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 12
         
      -- Go to prev screen
      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty
   END
   GOTO Quit

   ShortPick_Option_Fail:
   BEGIN
      -- Reset this screen var
      SET @cReasonCode = ''
   END
END
GOTO Quit


/********************************************************************************
Scn = 2615. Message. 'Order Summary'

********************************************************************************/
Step_OrderSummary:
BEGIN
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
    -- End

   IF @nInputKey = 1 OR @nInputkey = 0 -- ENTER / ESC
   BEGIN
      -- (james02)
      SET @cPPASKULottableDefCursor = ''
      SET @cPPASKULottableDefCursor = rdt.RDTGetConfig( 904, 'PPASKULottableDefCursor', @cStorer)

      IF @cPPASKULottableDefCursor = '1'
         EXEC rdt.rdtSetFocusField @nMobile, 1

      IF @cPPASKULottableDefCursor = '2'
         EXEC rdt.rdtSetFocusField @nMobile, 2

      IF @cPPASKULottableDefCursor = '3'
         EXEC rdt.rdtSetFocusField @nMobile, 3

      IF @cPPASKULottableDefCursor = '4'
         EXEC rdt.rdtSetFocusField @nMobile, 4

      IF @cPPASKULottableDefCursor = '5'
         EXEC rdt.rdtSetFocusField @nMobile, 5

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      -- Go to prev screen
      SET @nScn = @nScn_Criteria
      SET @nStep = @nStep_Criteria
   END
   GOTO Quit


END
GOTO Quit

/********************************************************************************
Scn = 3490. Dynamic lottables
   Label01    (field01)
   Lottable01 (field02, input)
   Label02    (field03)
   Lottable02 (field04, input)
   Label03    (field05)
   Lottable03 (field06, input)
   Label04    (field07)
   Lottable04 (field08, input)
   Label05    (field09)
   Lottable05 (field10, input)
********************************************************************************/
Step_Lottables:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorer, @cSKU, @cLottableCode, 'CAPTURE', 'CHECK', 5, 1, 
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
         @cSourceKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorer)
      IF @cExtendedUpdateSP NOT IN ('0', '')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, ' +
            ' @cRefNo, @cPickSlipNo, @cLoadkey, @cOrderkey, @cDropID, @cPPAType, ' +  
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' + 
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' + 
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' + 
            ' @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,  ' +
            '@nFunc           INT,  ' +   
            '@nStep           INT,  ' +
            '@nInputKey       INT,  ' +
            '@cLangCode    	NVARCHAR( 3),   ' +
            '@cStorerKey   	NVARCHAR( 15),  ' +
            '@cRefNo       	NVARCHAR( 10),  ' +
            '@cPickSlipNo  	NVARCHAR( 10),  ' +
            '@cLoadkey     	NVARCHAR( 10),  ' +
            '@cOrderkey    	NVARCHAR( 10),  ' +
            '@cDropID      	NVARCHAR( 20),  ' +
            '@cPPAType     	NVARCHAR( 1),   ' +
            '@cLottable01  	NVARCHAR( 18),  ' +
            '@cLottable02  	NVARCHAR( 18),  ' +
            '@cLottable03  	NVARCHAR( 18),  ' +
            '@dLottable04  	DATETIME,       ' +
            '@dLottable05  	DATETIME,       ' +
            '@cLottable06  	NVARCHAR( 30),  ' +
            '@cLottable07  	NVARCHAR( 30),  ' +
            '@cLottable08  	NVARCHAR( 30),  ' +
            '@cLottable09  	NVARCHAR( 30),  ' +
            '@cLottable10  	NVARCHAR( 30),  ' +
            '@cLottable11  	NVARCHAR( 30),  ' +
            '@cLottable12  	NVARCHAR( 30),  ' +
            '@dLottable13  	DATETIME,  ' +
            '@dLottable14  	DATETIME,  ' +
            '@dLottable15  	DATETIME,  ' +
            '@cSKU         	NVARCHAR( 20),  ' + 
            '@nQTY         	INT,  ' +
            '@nErrNo          INT           OUTPUT,  ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, 
            @cRefNo, @cPickSlipNo, @cLoadkey, @cOrderkey, @cDropID, @cPPAType, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EXT UPD FAIL'
            GOTO Quit
         END
      END

      SELECT @nSum_PalletQty = ISNULL( SUM( PQty), 0)
      FROM RDT.RDTPPA WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   SKU = @cSKU
      AND   Status < '9'
      AND   LoadKey = CASE WHEN @cPPAType = '1' THEN @cLoadKey ELSE LoadKey END
      AND   PickSlipNo = CASE WHEN @cPPAType = '2' THEN @cPickSlipNo ELSE PickSlipNo END
      AND   OrderKey = CASE WHEN @cPPAType = '3' THEN @cOrderKey ELSE OrderKey END
      AND   DropID = CASE WHEN @cPPAType = '4' THEN @cDropID ELSE DropID END
      AND   RefKey = CASE WHEN @cPPAType = '5' THEN @cRefNo ELSE RefKey END
      AND   Lottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE Lottable01 END
      AND   Lottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE Lottable02 END
      AND   Lottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE Lottable03 END
      AND   ISNULL( Lottable04, 0) = CASE WHEN ISNULL( @dLottable04, 0) <> 0 THEN @dLottable04 ELSE ISNULL( Lottable04, 0) END
      AND   ISNULL( Lottable05, 0) = CASE WHEN ISNULL( @dLottable05, 0) <> 0 THEN @dLottable05 ELSE ISNULL( Lottable05, 0) END
      AND   Lottable06 = CASE WHEN ISNULL( @cLottable06, '') <> '' THEN @cLottable06 ELSE Lottable06 END
      AND   Lottable07 = CASE WHEN ISNULL( @cLottable07, '') <> '' THEN @cLottable07 ELSE Lottable07 END
      AND   Lottable08 = CASE WHEN ISNULL( @cLottable08, '') <> '' THEN @cLottable08 ELSE Lottable08 END
      AND   Lottable09 = CASE WHEN ISNULL( @cLottable09, '') <> '' THEN @cLottable09 ELSE Lottable09 END
      AND   Lottable10 = CASE WHEN ISNULL( @cLottable10, '') <> '' THEN @cLottable10 ELSE Lottable10 END
      AND   Lottable11 = CASE WHEN ISNULL( @cLottable11, '') <> '' THEN @cLottable11 ELSE Lottable11 END
      AND   Lottable12 = CASE WHEN ISNULL( @cLottable12, '') <> '' THEN @cLottable12 ELSE Lottable12 END
      AND   ISNULL( Lottable13, 0) = CASE WHEN ISNULL( @dLottable13, 0) <> 0 THEN @dLottable13 ELSE ISNULL( Lottable13, 0) END
      AND   ISNULL( Lottable14, 0) = CASE WHEN ISNULL( @dLottable14, 0) <> 0 THEN @dLottable14 ELSE ISNULL( Lottable14, 0) END
      AND   ISNULL( Lottable15, 0) = CASE WHEN ISNULL( @dLottable15, 0) <> 0 THEN @dLottable15 ELSE ISNULL( Lottable15, 0) END

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
         SET @nPQTY = @nSum_PalletQty / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMQTY = @nSum_PalletQty % @nPUOM_Div  -- Calc the remaining in master unit
      END

         -- Prepare QTY screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2

      SET @cOutField04 = @cLottable01
      SET @cOutField05 = @cLottable02
      SET @cOutField06 = @cLottable03
      SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)


      IF @cPUOM_Desc = ''
      BEGIN

         SET @cOutField08 = '1:1' -- @nPUOM_Div
         SET @cOutField09 = '' -- @cPUOM_Desc
         SET @cOutField11 = '' -- @nPQTY

         SET @cFieldAttr11 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         SET @cOutField09 = @cPUOM_Desc
         --SET @cOutField11 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField11 = ''
      END

      SET @cOutField10 = @cMUOM_Desc -- SOS# 176725
      --SET @cOutField12 = @cMUOM_Desc -- SOS# 176725


      IF @nPQTY <= 0
      BEGIN
         --SET @cOutField07 = ''
         SET @cOutField11 = ''
         SET @cInField11 = ''
         SET @cFieldAttr11 = 'O'
      END



      IF @nMQTY > 0
      BEGIN
         --SET @cOutField08 = CAST( @nMQTY as NVARCHAR( 5))
         SET @cInField12 = ''
         SET @cFieldAttr12 = ''
      END
      ELSE
      BEGIN
         --SET @cOutField08 = ''
         SET @cInField12 = ''
         SET @cFieldAttr12 = 'O'
      END

      IF @nPQTY > 0
         EXEC rdt.rdtSetFocusField @nMobile, 11
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 12

      -- (james02)
      IF rdt.RDTGetConfig( @nFunc, 'PPADefaultQTY', @cStorer) <> '1'
      BEGIN
         SET @cOutField11 = ''
         SET @cOutField12 = ''
      END
      ELSE
      BEGIN
         -- (james03)
         IF CAST( @cPieceScanQty AS INT) > 0
         BEGIN
            IF @cFieldAttr11 = 'O'
               SET @cOutField12 = @cPieceScanQty
            ELSE
            BEGIN
               SET @cOutField11 = @cPieceScanQty
               SET @cOutField12 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 11
            END
         END
         ELSE
         BEGIN
            SET @cOutField11 = @nPQTY
            SET @cOutField12 = @nMQTY
         END
      END

      -- Goto QTY screen
      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorer, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1, 
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
         @cSourceKey,
         @nFunc

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = '' --
      SET @cFieldAttr06 = '' --
      SET @cFieldAttr08 = '' --
      SET @cFieldAttr10 = '' --

      -- Load prev screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadkey
      SET @cOutField04 = @cOrderkey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU

      -- Go back to prev screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep
   END
   GOTO Quit
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
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cPUOM,
      V_QTY          = @nActQty,
      V_UCC          = @cUCC,
      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,

      V_LottableLabel01 = @cLotLabel01,
      V_LottableLabel02 = @cLotLabel02,
      V_LottableLabel03 = @cLotLabel03,
      V_LottableLabel04 = @cLotLabel04,
      V_LottableLabel05 = @cLotLabel05,
      V_Loadkey         = @cLoadkey,

      V_String1  = @cOrderkey,
      V_String2  = @cDropID,
      V_String3  = @nSuggestQTY,
      V_String4  = @nActMQTY,
      V_String5  = @nActPQTY,
      V_String6  = @cPieceScanQty,
      V_String7  = @cLottable01_Code,
      V_String8  = @cLottable02_Code,
      V_String9  = @cLottable03_Code,
      V_String10 = @cLottable04_Code,
      V_String11 = @cLottable05_Code,
      V_String12 = @cHasLottable,
      V_String13 = @cMUOM_Desc,
      V_String14 = @cPUOM_Desc,
      V_String15 = @nPUOM_Div,
      V_String16 = @nMQTY,
      V_String17 = @nPQTY,
      V_String18 = @cPPAType,
      V_String19 = @cRefNo,
      V_String20 = @cLottableCode,
      V_String21 = @cSourceKey,
      V_String22 = @nFromScn,
      V_String23 = @nFromStep,
      V_String24 = @cDecodeSP,

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
       -- Start
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15
       -- End
   WHERE Mobile = @nMobile


END

GO