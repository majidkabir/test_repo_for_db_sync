SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdtfnc_Pick_SKULottable                                   */
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
/* 2010-10-13   1.0  ChewKP     Created                                       */
/* 2013-09-10   1.1  James      Bug fix (james01)                             */
/* 2016-09-30   1.2  Ung        Performance tuning                            */
/* 2017-01-25   1.3  Ung        WMS-1000 Temporary modify for urgent release  */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_Pick_SKULottable] (
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
   @cOption        NVARCHAR( 1), 
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
   @cID            NVARCHAR( 10), 
   @cDropID        NVARCHAR( 20), 
   @cSKU           NVARCHAR( 20),
   @cSKUDescr      NVARCHAR( 60),
   @cUOM           NVARCHAR( 10),   -- Display NVARCHAR(3)
   --@cQTY           NVARCHAR( 5), 
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
   @nCountPickedSKU     INT,
   @nSumQTY             INT,
   @nSumPickedQTY       INT,
   @cPickStatus         NVARCHAR(20),
   @cSuggestPQTY        NVARCHAR( 5),
   @cSuggestMQTY        NVARCHAR( 5),
   @nSuggestPQTY        INT, -- Suggested master QTY
   @nSuggestMQTY        INT, -- Suggested prefered QTY
   
   @cDecodeSP           NVARCHAR( 20),

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
   @cID              = V_ID, 
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cPUOM            = V_UOM,
   @nActQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,
   @cUCC             = V_UCC,
   @cLottable01       = V_Lottable01,
   @cLottable02       = V_Lottable02,
   @cLottable03       = V_Lottable03,
   @dLottable04       = V_Lottable04,
   @cLotLabel01      = V_LottableLabel01, 
   @cLotLabel02      = V_LottableLabel02, 
   @cLotLabel03      = V_LottableLabel03, 
   @cLotLabel04      = V_LottableLabel04, 
   @cLotLabel05      = V_LottableLabel05,


   @cOrderKey        = V_String1,
   @cDropID          = V_String2,
   @nSuggestQTY      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   @nActMQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
   @nActPQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,
   @cLoadkey         = V_String6,
   @cLottable01_Code   = V_String7, 
   @cLottable02_Code   = V_String8, 
   @cLottable03_Code   = V_String9, 
   @cLottable04_Code   = V_String10, 
   @cLottable05_Code   = V_String11, 
   @cHasLottable       = V_String12, 

   @cMUOM_Desc       = V_String13,
   @cPUOM_Desc       = V_String14,
   @nPUOM_Div        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,
   @nMQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16, 5), 0) = 1 THEN LEFT( V_String16, 5) ELSE 0 END,
   @nPQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17, 5), 0) = 1 THEN LEFT( V_String17, 5) ELSE 0 END,

   @cDecodeSP        = V_String21,

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
   @nStep_PickSlipNo INT,  @nScn_PickSlipNo INT,  
   @nStep_LOC        INT,  @nScn_LOC        INT,  
   @nStep_SKU        INT,  @nScn_SKU        INT,  
   @nStep_Lottables  INT,  @nScn_Lottables  INT,  
   @nStep_QTY        INT,  @nScn_QTY        INT,  
   @nStep_ShortPick  INT,  @nScn_ShortPick  INT,  
   @nStep_OrderSummary  INT,  @nScn_OrderSummary  INT


SELECT
   @nStep_PickSlipNo = 1,  @nScn_PickSlipNo = 2590,  
   @nStep_LOC        = 2,  @nScn_LOC        = 2591,  
   @nStep_SKU        = 3,  @nScn_SKU        = 2592,  
   @nStep_Lottables  = 4,  @nScn_Lottables  = 2593,  
   @nStep_QTY        = 5,  @nScn_QTY        = 2594, 
   @nStep_ShortPick  = 6,  @nScn_ShortPick  = 2595,  
   @nStep_OrderSummary = 7,@nScn_OrderSummary = 2596 


IF @nFunc = 866 
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 866
   IF @nStep = 1  GOTO Step_PickSlipNo  -- Scn = 2590. PickSlipNo
   IF @nStep = 2  GOTO Step_LOC         -- Scn = 2591. LOC, DropID
   IF @nStep = 3  GOTO Step_SKU         -- Scn = 2592. SKU
   IF @nStep = 4  GOTO Step_Lottables   -- Scn = 2593. Lottables
   IF @nStep = 5  GOTO Step_QTY         -- Scn = 2594. QTY
   IF @nStep = 6  GOTO Step_ShortPick   -- Scn = 2595. Message. 'Confrim Short Pick?'
   IF @nStep = 7  GOTO Step_OrderSummary-- Scn = 2596. Message. 'Order Summary'

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 866
********************************************************************************/
Step_Start:
BEGIN
-- Commented (Vicky02) - Start
--    -- Create the session data
--    IF EXISTS (SELECT 1 FROM RDTSessionData WITH (NOLOCK) WHERE Mobile = @nMobile)
--       UPDATE RDTSessionData WITH (ROWLOCK) SET XML = '' WHERE Mobile = @nMobile
--    ELSE
--       INSERT INTO RDTSessionData (Mobile) VALUES (@nMobile)
-- Commented (Vicky02) - End
   
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

   SET @cPrintPalletManifest = ''
   SET @cPrintPalletManifest = rdt.RDTGetConfig( 0, 'PrintPalletManifest', @cStorer)  
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''   

    -- (Vicky06) EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorer

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
   -- End

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
Scn = 2590. PickSlipNo screen
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
         SET @nErrNo = 71466
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PSNO required
         GOTO PickSlipNo_Fail
      END

      SET @cPrePackByBOM = ''
      SELECT @cPrePackByBOM = ISNULL(RTRIM(sValue),'')
      FROM DBO.StorerConfig WITH (NOLOCK)
      WHERE ConfigKey = 'PrePackByBOM'
         AND Storerkey = @cStorer

      -- Get pickheader info
      SET @cOrderkey = ''
      SET @cLoadkey = ''
      
      SELECT TOP 1
         @cOrderKey = OrderKey,
         @cLoadkey = ExternOrderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Validate pickslipno
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 71467
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid PSNO
         GOTO PickSlipNo_Fail
      END

      -- Validate PickSlip type
      IF @cOrderKey IS NULL OR @cOrderKey = ''
      BEGIN
         SET @nErrNo = 71468
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PSTypeNotSupport
         GOTO PickSlipNo_Fail
      END

      -- Get storerkey
      SELECT @cChkStorerKey = StorerKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Validate storerkey
      IF @cChkStorerKey IS NULL OR @cChkStorerKey = '' OR @cChkStorerKey <> @cStorer
      BEGIN
         SET @nErrNo = 71469
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff storer
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
         SET @nErrNo = 71470
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS not scan in
         GOTO PickSlipNo_Fail
      END

      -- Validate pickslip already scan out
      IF @dScanOutDate IS NOT NULL
      BEGIN
         SET @nErrNo = 71471
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS scanned out
         GOTO PickSlipNo_Fail
      END

      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' -- LOC
      SET @cOutField03 = '' -- DropID
      
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC

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
      SET @cOutField01 = '' -- PSNO
   END
END
GOTO Quit


/***********************************************************************************
Scn = 2591. LOC screen
   PSNO   (field01)
   LOC    (field02, input)
   DropID (field03, input)
***********************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField02 -- LOC
      SET @cDropID = @cInField03 -- Option

      -- Validate blank
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @nErrNo = 71472
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC req'
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
         SET @nErrNo = 71473
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO LOC_Fail
      END
      
      -- Validate facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 71474
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO LOC_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                     WHERE PD.Loc = @cLOC AND PD.Orderkey = @cOrderkey AND PD.Storerkey = @cStorer)
      BEGIN
            SET @nErrNo = 71477
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
            GOTO LOC_Fail
      END  
      
      -- Goto SKU screen

         -- Prepare SKU screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cDropID
         SET @cOutField03 = ''
         

         -- Goto SKU screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU


   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN

      SET @nCountSKU = 0
      SET @nCountPickedSKU = 0
      SET @nSumQTY = 0
      SET @nSumPickedQTY = 0
      SET @cPickStatus = ''
      
      
      -- Get Total SKU
--      SELECT @nCountSKU = COUNT (DISTINCT PD.SKU), @nSumQTY = SUM(PD.QTY) FROM dbo.PickDetail PD WITH (NOLOCK)
--      INNER JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
--      INNER JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON ( PH.PickHeaderkey = @cPickSlipNo AND PH.ExternOrderkey = O.Loadkey) 
--      WHERE PD.Storerkey = @cStorer

      SELECT @nCountSKU = COUNT (DISTINCT PD.SKU) , @nSumQTY = SUM(PD.QTY) FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.Storerkey =  @cStorer
      AND PD.PickSlipNo =  @cPickSlipNo
      

      -- Get Picked SKU
--      SELECT @nCountPickedSKU = COUNT (DISTINCT PD.SKU), @nSumPickedQTY = SUM(PD.QTY) FROM dbo.PickDetail PD WITH (NOLOCK)
--      INNER JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
--      INNER JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON ( PH.PickHeaderkey = @cPickSlipNo AND PH.ExternOrderkey = O.Loadkey) 
--      WHERE PD.Storerkey = @cStorer
--      AND PD.Status IN ('4','5')
--      GROUP BY PD.QTY
      SELECT @nCountPickedSKU = COUNT (DISTINCT PD.SKU) , @nSumPickedQTY = SUM(PD.QTY) FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.Storerkey =  @cStorer
      AND PD.PickSlipNo =  @cPickSlipNo
      AND PD.Status = '5'
      

      IF (@nCountSKU = @nCountPickedSKU) AND (@nSumPickedQTY = @nSumQTY)
      BEGIN
         SET @cPickStatus = 'COMPLETED'
      END
      ELSE
      BEGIN
         SET @cPickStatus = 'NOT COMPLETED'
      END
      
      -- Prepare prev screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @nCountPickedSKU
      SET @cOutField03 = @nCountSKU
      SET @cOutField04 = CASE WHEN rdt.rdtIsValidQTY( LEFT( @nSumPickedQTY, 5), 0) = 1 THEN LEFT( @nSumPickedQTY, 5) ELSE 0 END 
      SET @cOutField05 = CASE WHEN rdt.rdtIsValidQTY( LEFT( @nSumQTY, 5), 0) = 1 THEN LEFT( @nSumQTY, 5) ELSE 0 END 
      SET @cOutField06 = @cPickStatus
      

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

   LOC_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField02 = '' -- LOC
      SET @cOutField03 = @cDropID -- DropID      
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
      GOTO Quit
   END

   DropID_Fail:
   BEGIN
      SET @cDropID = ''
      SET @cOutField02 = @cLOC
      SET @cOutField03 = '' -- DropID
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- DropID
      GOTO Quit
   END
END
GOTO Quit


/********************************************************************************
Scn = 2592. SKU screen
   LOC       (field01)
   ID        (field02)
   SKU/UPC   (field03, input)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cUPC NVARCHAR(30)
      DECLARE @cBarcode NVARCHAR(60)

      -- Screen mapping
      SET @cUPC = LEFT( @cInField03, 30) -- SKU
      SET @cBarcode = @cInField03

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
      SET @cSKU = @cInField03 -- SKU

      
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
            SET @nErrNo = 71475
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Req'
            GOTO SKU_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode, 
               @cUPC        = @cUPC        OUTPUT, 
               -- @nQTY        = @nQTY        OUTPUT, 
               -- @cLottable01 = @cLottable01 OUTPUT, 
               @cLottable02 = @cLottable02 OUTPUT 
               -- @cLottable03 = @cLottable03 OUTPUT, 
               -- @dLottable04 = @dLottable04 OUTPUT --, @dLottable05 OUTPUT,
               -- @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               -- @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT
         END
/*         
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode, @cFieldName, ' +
               ' @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cReceiptKey  NVARCHAR( 10), ' +
               ' @cPOKey       NVARCHAR( 10), ' +
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFieldName   NVARCHAR( 10), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04  DATETIME       OUTPUT, ' +
               ' @dLottable05  DATETIME       OUTPUT, ' +
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13  DATETIME       OUTPUT, ' +
               ' @dLottable14  DATETIME       OUTPUT, ' +
               ' @dLottable15  DATETIME       OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode, 'SKU',
               @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail
               
            IF @cSKU <> ''
               SET @cUPC = @cSKU
         END
*/
      END

      
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
      
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                     WHERE PD.SKU = @cSKU AND PD.Orderkey = @cOrderkey AND PD.Storerkey = @cStorer )
      BEGIN
            SET @nErrNo = 71476
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
            GOTO SKU_Fail
      END     


/*
      IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                 WHERE PD.SKU = @cSKU 
                 AND PD.Orderkey = @cOrderkey 
                 AND PD.Storerkey = @cStorer 
                 AND PD.Status >= 4 )
      BEGIN
            SET @nErrNo = 71488
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Picked'
            GOTO SKU_Fail
      END
*/
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                      WHERE PD.SKU = @cSKU 
                      AND PD.Orderkey = @cOrderkey 
                      AND PD.Storerkey = @cStorer 
                      AND PD.LOC = @cLoc )
      BEGIN
            SET @nErrNo = 71493
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad Location'
            GOTO SKU_Fail
      END

      SET @nSum_PalletQty = 0

      SELECT @nSum_PalletQty = ISNULL(SUM(QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      JOIN dbo.PickHeader PH WITH (NOLOCK) ON ( PH.PickHeaderkey = @cPickSlipNo AND PH.ExternOrderkey = O.Loadkey)
      WHERE PD.StorerKey = @cStorer
         AND PD.LOC = @cLoc
         AND PD.SKU = @cSKU
         AND PD.Status = '0'
      GROUP BY PD.SKU 

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
            END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorer
         AND SKU.SKU = @cSKU




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

    

      -- Get SKU description, IVAS, lot label
      SET @cLottable01 = ''
      SET @cLotLabel02 = ''
      SET @cLotLabel03 = ''
      SET @cLotLabel04 = ''
      SET @cLotLabel05 = ''
      
      SET @cLottable01_Code = ''
      SET @cLottable02_Code = ''
      SET @cLottable03_Code = ''
      SET @cLottable04_Code = ''
      SET @cLottable05_Code = ''
      
      

      SELECT
            @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM DBO.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> '' 
                                                                                             AND C.StorerKey = CASE WHEN C.StorerKey <> '' THEN S.StorerKey ELSE C.StorerKey END), ''), 
            @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM DBO.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> '' 
                                                                                             AND C.StorerKey = CASE WHEN C.StorerKey <> '' THEN S.StorerKey ELSE C.StorerKey END), ''), 
            @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM DBO.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> '' 
                                                                                             AND C.StorerKey = CASE WHEN C.StorerKey <> '' THEN S.StorerKey ELSE C.StorerKey END), ''), 
            @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM DBO.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> '' 
                                                                                             AND C.StorerKey = CASE WHEN C.StorerKey <> '' THEN S.StorerKey ELSE C.StorerKey END), ''),
            @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM DBO.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> '' 
                                                                                             AND C.StorerKey = CASE WHEN C.StorerKey <> '' THEN S.StorerKey ELSE C.StorerKey END), ''), 
            @cLottable05_Code = IsNULL( S.Lottable05Label, ''),
            @cLottable01_Code = IsNULL(S.Lottable01Label, ''),  
            @cLottable02_Code = IsNULL(S.Lottable02Label, ''),  
            @cLottable03_Code = IsNULL(S.Lottable03Label, ''),  
            @cLottable04_Code = IsNULL(S.Lottable04Label, '')   
      FROM DBO.SKU S WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND SKU = @cSKU
      
      -- Turn on lottable flag (use later)
      SET @cHasLottable = '0'
      IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR
         (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR
         (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR
         (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) OR
         (@cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL)
       BEGIN
         SET @cHasLottable = '1'
       END

      
                      
/********************************************************************************************************************/
/* SOS#81879 - Start                                                                                                */ 
/* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
/* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
/* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
/* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
/*    Codelkup.Short = 'PRE' and Codelkup.Long = <SP Name>                                */
/********************************************************************************************************************/

      IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR 
         (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')
      BEGIN
 
			--initiate @nCounter = 1
			SET @nCountLot = 1

         --retrieve value for pre lottable01 - 05
         WHILE @nCountLot <=5 --break the loop when @nCount >5
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

             --get short, store procedure and lottablelable value for each lottable
             SET @cShort = ''
             SET @cStoredProd = ''
             SELECT @cShort = ISNULL(RTRIM(C.Short),''), 
                    @cStoredProd = IsNULL(RTRIM(C.Long), '')
             FROM DBO.CodeLkUp C WITH (NOLOCK) 
             JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
             WHERE C.ListName = @cListName
             AND   C.Code = @cLottableLabel
         
             IF @cShort = 'PRE' AND @cStoredProd <> ''
             BEGIN


               IF @cListName = 'Lottable01'
                  SET @cLottable01 = ''
               ELSE IF @cListName = 'Lottable02'
                  SET @cLottable02 = ''
               ELSE IF @cListName = 'Lottable03'
                  SET @cLottable03 = ''
               ELSE IF @cListName = 'Lottable04'
                  SET @dLottable04 = ''
               ELSE IF @cListName = 'Lottable05'
                  SET @dLottable05 = ''


               --SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')
               SET @cSourcekey = ''

               EXEC DBO.ispLottableRule_Wrapper
                  @c_SPName            = @cStoredProd,
                  @c_ListName          = @cListName,
                  @c_Storerkey         = @cStorer,
                  @c_Sku               = @cSKU,
                  @c_LottableLabel     = @cLottableLabel,
                  @c_Lottable01Value   = '',
                  @c_Lottable02Value   = '',
                  @c_Lottable03Value   = '',
                  @dt_Lottable04Value  = '',
                  @dt_Lottable05Value  = '',
                  @c_Lottable01        = @cLottable01 OUTPUT,
                  @c_Lottable02        = @cLottable02 OUTPUT,
                  @c_Lottable03        = @cLottable03 OUTPUT,
                  @dt_Lottable04       = @dLottable04 OUTPUT,
                  @dt_Lottable05       = @dLottable05 OUTPUT,
                  @b_Success           = @b_Success   OUTPUT,
                  @n_Err               = @nErrNo      OUTPUT,
                  @c_Errmsg            = @cErrMsg     OUTPUT,
--                @c_Sourcekey         = @cReceiptKey,  --SOS133226  (james02)
                  @c_Sourcekey         = @cSourcekey,
                  @c_Sourcetype        = 'RDTPICK'

					 --IF @b_success <> 1
                IF ISNULL(@cErrMsg, '') <> ''  
					 BEGIN
  			          SET @cErrMsg = @cErrMsg
						 GOTO SKU_Fail
						 BREAK   
					 END  

					 SET @cLottable01 = IsNULL( @cLottable01, '')
					 SET @cLottable02 = IsNULL( @cLottable02, '')
					 SET @cLottable03 = IsNULL( @cLottable03, '')
					 SET @dLottable04 = IsNULL( @dLottable04, 0)
					 SET @dLottable05 = IsNULL( @dLottable05, 0)
              
                IF @dLottable04 > 0
                BEGIN
                   SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)
                END
 
                IF @dLottable05 > 0
                BEGIN
                   SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)
                END

--
--					 SET @cOutField02 = @cLottable01
--					 SET @cOutField04 = @cLottable02
--					 SET @cOutField06 = @cLottable03
--					 SET @cOutField08 = CASE WHEN @dLottable04 <> 0 THEN rdt.rdtFormatDate( @dLottable04) END
--					 SET @cOutField10 = CASE WHEN @dLottable05 <> 0 THEN rdt.rdtFormatDate( @dLottable05) END
			   END

            -- increase counter by 1
            SET @nCountLot = @nCountLot + 1
       END -- nCount
      END -- Lottable <> ''
/********************************************************************************************************************/
/* SOS#81879 - End                                                                                                  */ 
/* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
/********************************************************************************************************************/

      

      IF @cHasLottable = '1'
      BEGIN

         -- Init lot label
         SELECT 
            @cOutField01 = 'Lottable01:', 
            @cOutField03 = 'Lottable02:', 
            @cOutField05 = 'Lottable03:', 
            @cOutField07 = 'Lottable04:', 
            @cOutField09 = 'Lottable05:'

         -- Disable lot label and lottable field
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O' 
            SET @cOutField02 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            -- Populate lot label and lottable
            SELECT
               @cOutField01 = @cLotLabel01, 
               @cOutField02 = ISNULL(@cLottable01, '') 
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O' 
            SET @cOutField04 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            SELECT
               @cOutField03 = @cLotLabel02, 
               @cOutField04 = ISNULL(@cLottable02, '')  
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
               SET @cFieldAttr06 = 'O' 
               SET @cOutField06 = ''

            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
         SELECT
               @cOutField05 = @cLotLabel03, 
               @cOutField06 = ISNULL(@cLottable03, '')  
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O' 
            SET @cOutField08 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            SELECT
               @cOutField07 = @cLotLabel04, 
               @cOutField08 = @cLottable04 
         END

         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL         BEGIN 
            SET @cFieldAttr10 = 'O' 
            SET @cOutField10 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            -- Lottable05 is usually RCP_DATE
--            IF @cLottable05_Code = 'RCP_DATE' AND (@cLottable05 = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900') -- Edit by james on 20/03/2009
            IF @cLottable05_Code = 'RCP_DATE' AND (ISNULL(@cLottable05, '') = '') 
            BEGIN
               SET @cLottable05 = RDT.RDTFormatDate( GETDATE())
            END
            
              SELECT @cOutField09 = @cLotLabel05, 
              @cOutField10 = @cLottable05
            
         END   
         
         -- Goto Lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables
      END

    

      -- Go to next screen
      IF @cHasLottable = '0'
      BEGIN
         
          -- Prepare QTY screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
         
         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
--         SET @cOutField07 = @cLottable04 + ' ' + rdt.rdtFormatDate( @dLottable04)
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)   -- (james01)
         
         

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

         SET @cOutField12 = ''            -- (james01)
         
         -- Goto QTY screen
         SET @nScn = @nScn_Qty
         SET @nStep = @nStep_Qty

         
      END

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' -- LOC
      SET @cOutField03 = '' -- DropID
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC

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
Scn = 2593. Lottable
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
Step_Lottables:
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
		  SELECT @cShort = C.Short, 
				   @cStoredProd = IsNULL( C.Long, '')
		  FROM DBO.CodeLkUp C WITH (NOLOCK) 
		  WHERE C.Listname = @cListName
		  AND   C.Code = @cLottableLabel

        
       
 
		  IF @cShort = 'POST' AND @cStoredProd <> ''
		  BEGIN
           IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date           
   			  SET @dLottable04 = CAST( @cLottable04 AS DATETIME)

           IF rdt.rdtIsValidDate(@cLottable05) = 1 --valid date
			     SET @dLottable05 = CAST( @cLottable05 AS DATETIME)

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
					  SET @dLottable04 = IsNULL(CAST(@cOutField08 AS DATETIME), 0)
                 SET @cLottable04 = IsNULL(@cOutField08, '')

--					 SET @cErrMsg = IsNULL(CAST(@dLottable04 AS DATETIME), 0) 
--					 GOTO Lottables_Fail
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
            SET @nErrNo = 71478
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable01 required'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Lottables_Fail
         END
         
         -- Validate Lottable against PickDetail.Lot
         IF NOT EXISTS ( SELECT 1
                        FROM dbo.PickDetail PD WITH (NOLOCK)    
                        INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot AND LA.Storerkey = PD.Storerkey
                        WHERE  PD.LOC = @cLOC    
                        AND    PD.SKU = @cSKU  
                        AND    PD.Orderkey = @cOrderkey   
                        AND    LA.Lottable01 = @cLottable01 )
         BEGIN
            SET @nErrNo = 71489
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Lottable01'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Lottables_Fail
         END
     
      END

      -- Validate lottable02
      IF @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL
      BEGIN
         IF @cLottable02 = '' OR @cLottable02 IS NULL
         BEGIN
            SET @nErrNo = 71479
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable02 required'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Step_Lottables_Fail
         END
         /*
         -- Validate Lottable against PickDetail.Lot
         IF NOT EXISTS ( SELECT 1
                        FROM dbo.PickDetail PD WITH (NOLOCK)    
                        INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot AND LA.Storerkey = PD.Storerkey
                        WHERE  PD.LOC = @cLOC    
                        AND    PD.SKU = @cSKU  
                        AND    PD.Orderkey = @cOrderkey   
                        AND    LA.Lottable02 = @cLottable02 )
         BEGIN
            SET @nErrNo = 71490
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Lottable02'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Step_Lottables_Fail
         END
         */
      END

      -- Validate lottable03
      IF @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL
      BEGIN
         IF @cLottable03 = '' OR @cLottable03 IS NULL
         BEGIN
            SET @nErrNo = 71480
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable03 required'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Step_Lottables_Fail
         END  

         -- Validate Lottable against PickDetail.Lot
         IF NOT EXISTS ( SELECT 1
                        FROM dbo.PickDetail PD WITH (NOLOCK)    
                        INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot AND LA.Storerkey = PD.Storerkey
                        WHERE  PD.LOC = @cLOC    
                        AND    PD.SKU = @cSKU  
                        AND    PD.Orderkey = @cOrderkey   
                        AND    LA.Lottable03 = @cLottable03 )
         BEGIN
            SET @nErrNo = 71491
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Lottable03'
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Step_Lottables_Fail
         END
  		END

      -- Validate lottable04
      IF @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL
      BEGIN
         -- Validate empty
       IF @cLottable04 = '' OR @cLottable04 IS NULL
         BEGIN
            SET @nErrNo = 71481
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable04 required'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Step_Lottables_Fail
         END
         -- Validate date
         IF RDT.rdtIsValidDate( @cLottable04) = 0
         BEGIN
            SET @nErrNo = 71482
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Step_Lottables_Fail
         END
         
         SET @dLottable04 = CAST( @cLottable04 AS DATETIME)

         -- Validate Lottable against PickDetail.Lot
         IF NOT EXISTS ( SELECT 1
                        FROM dbo.PickDetail PD WITH (NOLOCK)    
                        INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.Lot = PD.Lot AND LA.Storerkey = PD.Storerkey
                        WHERE  PD.LOC = @cLOC    
                        AND    PD.SKU = @cSKU  
                        AND    PD.Orderkey = @cOrderkey   
                        AND    LA.Lottable04 = rdt.rdtFormatDate(@cLottable04) )
         BEGIN
            SET @nErrNo = 71492
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Lottable04'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Step_Lottables_Fail
         END


      END

       
        
      
--      -- Validate lottable05
--      IF @cLotlabel05 <> '' AND @cLotlabel05 IS NOT NULL
--      BEGIN
--         -- Validate empty
--         IF @cLottable05 = '' OR @cLottable05 IS NULL
--         BEGIN
--            SET @nErrNo = 71483
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Lottable05 required'
--            EXEC rdt.rdtSetFocusField @nMobile, 10
--            GOTO Step_Lottables_Fail
--         END  
--         -- Validate date
--         IF RDT.rdtIsValidDate( @cLottable05) = 0
--         BEGIN
--            SET @nErrNo = 71484
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid date'
--            EXEC rdt.rdtSetFocusField @nMobile, 10
--            GOTO Step_Lottables_Fail
--         END
--      END
--SET @cErrMsg = @cLottable01
--goto Step_Lottables_Fail
      --GOTO Receiving
      
      -- Prepare Next Screen Var --
      
          -- Prepare QTY screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
         
         
         SET @cOutField04 = @cLottable01
         SET @cOutField05 = @cLottable02
         SET @cOutField06 = @cLottable03
--         SET @cOutField07 = ISNULL(RTRIM(@cLottable04_Code),'') + ' ' +  rdt.rdtFormatDate(@dLottable04)
         SET @cOutField07 = rdt.rdtFormatDate(@dLottable04)    -- (james01)
         
         
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
            
         SET @cOutField12 = ''   -- (james01)
      
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
      SET @cOutField01 = @cLoc
      SET @cOutField02 = @cDropID
      SET @cOutField03 = ''
--      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
--      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      --SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS
      --SET @cOutField05 = @cUOM
      --SET @cOutField06 = @cQTY
      --SET @cOutField07 = @cReasonCode


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
Scn = 2594. QTY screen
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
         SET @nErrNo = 71485
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 09 -- PQTY
         GOTO Qty_Fail
      END
      
       -- Validate ActMQTY
      IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 71486
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



      IF @nActQTY > @nSuggestQTY
      BEGIN
         SET @nErrNo = 71487
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY > Suggest'
         IF @cPUOM_Desc = ''
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 10
         END
         GOTO Qty_Fail
      END
      
      
      -- Go to Short Pick
      IF @nActQTY < @nSuggestQTY AND @cLotlabel02 <> 'SERIALNO'
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
      
      -- Confirm Pick --
      SET @cErrMsg = ''
      EXEC rdt.rdtfnc_Pick_SKULottable_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, 
         @cPickSlipNo, 
         @cLOC, 
         @cDropID, 
         @cSKU, 
         @cLottable01, 
         @cLottable02, 
         @cLottable03, 
         @dLottable04, 
         @nActQTY, 
         '5',     --Pick
         @nErrNo  OUTPUT, 
         @cErrMsg OUTPUT
      
      IF @nErrNo <> 0              
      BEGIN              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')               
         GOTO Qty_Fail               
      END       


      SET @cOutField01 = @cLoc
      SET @cOutField02 = @cDropID
      SET @cOutField03 = '' 

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

   IF @nInputKey = 0 -- ESC
   BEGIN
      
      -- Go to SKU screen
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cDropID
      SET @cOutField03 = '' -- @cSKU
      /*
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField06 = @cLottable02
      SET @cOutField07 = @cLottable03
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)
      SET @cOutField09 = '' -- SKU/UPC
      */
      
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
            SET @cOutField11 = '' -- @nPQTY
            --SET @cOutField11 = CAST( @nPQTY AS NVARCHAR( 5))
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

   END

END
GOTO Quit


/********************************************************************************
Scn = 2955. Message. 'Confirm Short Pick?'
   Option (field01)
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
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 62672
         SET @cErrMsg = rdt.rdtgetmessage( 62672, @cLangCode, 'DSP') -- Option required
         GOTO ShortPick_Option_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 62673
         SET @cErrMsg = rdt.rdtgetmessage( 62673, @cLangCode, 'DSP') -- Invalid Option
         GOTO ShortPick_Option_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Confirm Pick --    
         EXEC rdt.rdtfnc_Pick_SKULottable_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, 
            @cPickSlipNo, 
            @cLOC, 
            @cDropID, 
            @cSKU, 
            @cLottable01, 
            @cLottable02, 
            @cLottable03, 
            @dLottable04, 
            @nActQTY, 
            '4',     --Short
            @nErrNo  OUTPUT, 
            @cErrMsg OUTPUT   

         IF @nErrNo <> 0              
         BEGIN              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')               
            GOTO ShortPick_Option_Fail               
         END       

           SET @cOutField01 = @cLoc
           SET @cOutField02 = @cDropID
           SET @cOutField03 = '' 
           

           -- Go to prev screen
           SET @nScn = @nScn_SKU
           SET @nStep = @nStep_SKU
           
           
          -- EventLog - Sign In Function 
--          EXEC RDT.rdt_STD_EventLog
--          @cActionType = '9', -- In Progress
--          @cUserID     = @cUserName,
--          @nMobileNo   = @nMobile,
--          @nFunctionID = @nFunc,
--          @cFacility   = @cFacility,
--          @cStorerKey  = @cStorer

       END

       IF @cOption = '2'
       BEGIN
           SET @cOutField01 = @cLoc
           SET @cOutField02 = @cDropID
           SET @cOutField03 = '' 
           

           -- Go to prev screen
           SET @nScn = @nScn_SKU
           SET @nStep = @nStep_SKU
       END
      
   END

   -- ESC or No

  

   -- Back to UCC screen
   IF @nInputKey =  0  -- ESC
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
            SET @cOutField11 = CAST( @nPQTY AS NVARCHAR( 5))
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
Scn = 2956. Message. 'Order Summary'
   
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
           
           SET @cOutField01 = ''
         
           -- Go to prev screen
           SET @nScn = @nScn_PickSlipNo
           SET @nStep = @nStep_PickSlipNo

      
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
      -- UserName       = @cUserName,

      V_PickSlipNo   = @cPickSlipNo,
      V_LOC          = @cLOC,
      V_ID           = @cID, 
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
      

      V_String1      = @cOrderkey,
      V_String2      = @cDropID, 
      V_String3      = @nSuggestQTY,
      V_String4      = @nActMQTY,        
      V_String5      = @nActPQTY,        
      V_String6      = @cLoadkey,

      V_String7      = @cLottable01_Code,
      V_String8     = @cLottable02_Code,   
      V_String9     = @cLottable03_Code,   
      V_String10     = @cLottable04_Code,   
      V_String11     = @cLottable05_Code,   
     
      V_String12 =  @cHasLottable,     

      V_String13 =  @cMUOM_Desc,       
      V_String14 =  @cPUOM_Desc,       
      V_String15 =  @nPUOM_Div,        
      V_String16 =  @nMQTY,            
      V_String17 =  @nPQTY,    
      
      V_String21 = @cDecodeSP,        

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