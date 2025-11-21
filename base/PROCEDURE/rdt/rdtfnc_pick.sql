SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_Pick                                               */
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
/* 2006-11-09   1.0  Ung        Created                                       */
/* 2008-24-03   1.1  James      93811 - Add in new pick menu (Pick by         */
/*                              Drop ID)                                      */
/* 2008-11-03   1.2  Vicky      Remove XML part of code that is used to       */
/*                              make field invisible and replace with         */
/*                              new code (Vicky02)                            */
/* 2009-07-07   1.3  Vicky      Add in EventLog (Vicky06)                     */
/* 2011-07-29   1.4  ChewKP     RDT EventLog Standardization (ChewKP01)       */
/* 2012-07-19   1.5  Ung        SOS250649 Fix ID field disabled,length        */
/* 2013-01-22   1.6  James      SOS267939 - Support pick by                   */
/*                              conso picklist (james01)                      */
/* 2013-02-25   1.7  James      SOS270234 -                                   */
/*                              Auto scan out pickslip if fully picked.       */
/*                              Short pick not auto unallocate PD line        */
/*                              Send Alert if short pick (james02)            */
/* 2013-10-03   1.8  James      Enable 6 digits when pass in V_StringXX       */
/*                              (james03)                                     */
/* 2013-05-21   1.9  James      SOS276108 - Show suggest loc (james04)        */
/* 2013-10-07   2.0  James      SOS291606 - Retrieve UOM qty from             */
/*                              CodelkUp based on barcode scan (james05)      */
/* 2014-04-24   2.1  James      SOS308816 - Allow skip short pick screen      */
/*                              by rdt storer config (james06)                */
/*                              Add parameter in rdt_Pick_GetTaskInLOC        */
/* 2014-05-19   2.2  James      SOS311720 - Add customized fetch task         */
/*                              stored proc (james07)                         */
/* 2014-06-10   2.3  Ung        SOS307606 Add Check DropID format             */
/*                              Add ExtendedValidateSP                        */
/*                              Add SwapIDSP                                  */
/*                              Fix PSNO not support discrete type            */
/* 2015-01-30   2.4  James      SOS330787 - Add Lottable01 into confirm       */
/*                              task sp (james08)                             */
/* 2015-05-05   2.5  James      SOS335929 - Add decode label sp into          */
/*                              step STEP_LOC (james09)                       */
/* 2015-07-09   2.6  James      Fix for short pick not getting correct        */
/*                              screen flow (james10)                         */
/* 2015-09-25   2.7  James      Add DecodeDropIDSP (james11)                  */
/* 2016-04-12   2.8  James      SOS367362 Add DropID Validation(james12)      */
/* 2016-05-17   2.9  Ung        SOS370219 Change DecodeLabelNo to DecodeSP    */
/* 2016-06-28   3.0  Ung        SOS372692 Remove DecodeSP error               */
/* 2016-08-24   3.1  James      Remove duplicate dropid checking              */
/* 2016-09-30   3.2  Ung        Performance tuning                            */
/* 2017-10-11   3.3  James      WMS3174-Extend DropID length to pass in decode*/
/*                              stored proc (james13)                         */
/* 2017-11-16   3.4  MT         INC0035335 - RDT PICK EROR (MT01)             */
/* 2017-12-27   3.5  James      WMS3621 - Use config hide lot02 value(james14)*/
/*                   James      Add ID output to swap id sp                   */
/* 2020-03-17   3.6  James      WMS-12504 Add auto scan in pickslip (james15) */
/* 2022-03-09   3.7  yeekung    WMS-18588 Add Extendedvalidate (yeekung01)    */
/* 2022-05-19   3.8  Ung        WMS-22486 Add pick pallet with UCC            */
/* 2022-10-21   3.9  PXL009     UWP-25970 Fix Implicit type conversion error  */
/* 2024-10-22   4.0  PXL009     FCR-759 ID and UCC Length Issue               */
/* 2025-02-26   4.1.0  NLT013   FCR-2519 Be able to config Lottable           */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Pick] (
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
   @cZone                  NVARCHAR( 18),  -- (james01)
   @cPickConfirm_SP        NVARCHAR(20),   -- (james02)
   @cGetSuggestedLoc_SP    NVARCHAR(20),   -- (james04)
   @nLOC_Count             INT,            -- (james04)
   @nORD_Count             INT,            -- (james04)
   @nSKU_Count             INT,            -- (james04)
   @nCurActPQty            INT,            -- (james05)
   @nCurActMQty            INT,            -- (james05)
   @cDefaultLOC            NVARCHAR( 10),  -- (james06)
   @cTempOrderKey          NVARCHAR( 10),  -- (james06)
   @cPickGetTaskInLOC_SP   NVARCHAR( 20),  -- (james07)
   @cSQL                   NVARCHAR( MAX),
   @cSQLParam              NVARCHAR( MAX),
   @cBarcode               NVARCHAR( 60),
   @cUPC                   NVARCHAR( 30),


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
   @cSuggestedLOC          NVARCHAR(10),  -- (james04)
   @cPickShowSuggestedLOC  NVARCHAR(1),   -- (james04)
   @nActPQty               INT,           -- (james05)
   @nActMQty               INT,           -- (james05)
   @cExtendedValidateSP    NVARCHAR(20),
   @cExtendedInfoSP        NVARCHAR(20),
   @cExtendedInfo          NVARCHAR(20),
   @cSwapIDSP              NVARCHAR(20),
   @cDecodeDropIDSP        NVARCHAR(20),
   @nQty                   INT,
   @cDecodeSP              NVARCHAR( 20),
   @cLottableValidSP       NVARCHAR( 20),

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
   @cDefaultToPickQty      NVARCHAR( 20),
   @cAutoScanIn            NVARCHAR( 1),  -- (james15)
   @cMatchUCCLottable      NVARCHAR( 20),  
   @tValidationData        VariableTable,

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

   @nPQTY                  = V_Integer1,
   @nPUCC                  = V_Integer2,
   @nTaskQTY               = V_Integer3,
   @nTaskUCC               = V_Integer4,
   @nCaseCnt               = V_Integer5,
   @nPrefUOM_Div           = V_Integer6,
   @nPrefQTY               = V_Integer7,
   @nMstQTY                = V_Integer8,
   @nActPQty               = V_Integer9,
   @nActMQty               = V_Integer10,

   @cAutoScanIn           = V_String1,
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
   @nStep_PickSlipNo INT,  @nScn_PickSlipNo INT,
   @nStep_LOC        INT,  @nScn_LOC        INT,
   @nStep_SKU        INT,  @nScn_SKU        INT,
   @nStep_QTY        INT,  @nScn_QTY        INT,
   @nStep_UCC        INT,  @nScn_UCC        INT,
   @nStep_ID         INT,  @nScn_ID         INT,
   @nStep_SkipTask   INT,  @nScn_SkipTask   INT,
   @nStep_ShortPick  INT,  @nScn_ShortPick  INT,
   @nStep_NoMoreTask INT,  @nScn_NoMoreTask INT,
   @nStep_AbortTask  INT,  @nScn_AbortTask  INT,
   @nStep_ConfirmLoc INT,  @nScn_ConfirmLoc INT,
   @nStep_Summary    INT,  @nScn_Summary    INT

SELECT
   @nStep_PickSlipNo = 1,  @nScn_PickSlipNo = 831,
   @nStep_LOC        = 2,  @nScn_LOC        = 832,
   @nStep_SKU        = 3,  @nScn_SKU        = 833,
   @nStep_QTY        = 4,  @nScn_QTY        = 834,
   @nStep_UCC        = 5,  @nScn_UCC        = 835,
   @nStep_ID         = 6,  @nScn_ID         = 836,
   @nStep_SkipTask   = 7,  @nScn_SkipTask   = 837,
   @nStep_ShortPick  = 8,  @nScn_ShortPick  = 838,
   @nStep_NoMoreTask = 9,  @nScn_NoMoreTask = 839,
   @nStep_AbortTask  = 10, @nScn_AbortTask  = 840,
   @nStep_ConfirmLoc = 11, @nScn_ConfirmLoc = 842,
   @nStep_Summary    = 12, @nScn_Summary    = 843

IF @nFunc = 860 OR @nFunc = 861 OR @nFunc = 862 OR @nFunc = 863 -- Pick. SKU/UPC, UCC, Pallet, DropID
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 860 / 861
   IF @nStep = 1  GOTO Step_PickSlipNo  -- Scn = 831. PickSlipNo
   IF @nStep = 2  GOTO Step_LOC         -- Scn = 832. LOC, DropID
   IF @nStep = 3  GOTO Step_SKU         -- Scn = 833. SKU
   IF @nStep = 4  GOTO Step_QTY         -- Scn = 834. QTY
   IF @nStep = 5  GOTO Step_UCC         -- Scn = 835. UCC
   IF @nStep = 6  GOTO Step_ID          -- Scn = 836. ID
   IF @nStep = 7  GOTO Step_SkipTask    -- Scn = 837. Message. 'Skip Current Task?'
   IF @nStep = 8  GOTO Step_ShortPick   -- Scn = 838. Message. 'Confrim Short Pick?'
   IF @nStep = 9  GOTO Step_NoMoreTask  -- Scn = 839. Message. 'No more task in LOC'
   IF @nStep = 10 GOTO Step_AbortTask   -- Scn = 840. Message. 'Abort Task?'
   IF @nStep = 11 GOTO Step_ConfirmLoc  -- Scn = 842. Message. 'LOC not match?'
   IF @nStep = 12 GOTO Step_Summary     -- Scn = 842. Message. 'Summary'
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 860 / 861 / 862
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
   WHERE StorerKey = @cStorer
      AND ConfigKey = 'UCC'

   -- Get RDT storer configure
   SET @cPrintPalletManifest = ''
   SET @cPrintPalletManifest = rdt.RDTGetConfig( 0, 'PrintPalletManifest', @cStorer)
   SET @cPickShowSuggestedLOC = ''
   SET @cPickShowSuggestedLOC = rdt.RDTGetConfig( @nFunc, 'PickShowSuggestedLOC', @cStorer)
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorer)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cSwapIDSP = rdt.rdtGetConfig( @nFunc, 'SwapIDSP', @cStorer)
   IF @cSwapIDSP = '0'
      SET @cSwapIDSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   SET @cPickDontShowLot02 = rdt.RDTGetConfig( @nFunc, 'PickDontShowLot02', @cStorer)

   SET @cDefaultToPickQty = rdt.RDTGetConfig( @nFunc, 'DefaultToPickQty', @cStorer)

   SET @cAutoScanIn = rdt.rdtGetConfig( @nFunc, 'AutoScanIn', @cStorer) -- (james15)

   -- Set pick type
   SET @cPickType =
      CASE @nFunc
         WHEN 860 THEN 'S' -- SKU/UPC
         WHEN 861 THEN 'U' -- UCC
         WHEN 862 THEN 'P' -- Pallet
         WHEN 863 THEN 'D' -- Pick By Drop ID
      END

   -- Check if pick UCC but UCC config off
   IF @cPickType = 'U' AND @cUCCStorerConfig <> '1'
   BEGIN
      SET @nErrNo = 62601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC Config Off
      GOTO Step_Start_Fail
   END

   -- Check if pick pallet in ucc warehouse
   /*
   IF @cPickType = 'P' AND @cUCCStorerConfig = '1'
   BEGIN
      SET @nErrNo = 62602
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- CantPickUCC PL
      GOTO Step_Start_Fail
   END
   */

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
Scn = 831. PickSlipNo screen
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
         SET @nErrNo = 62611
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
         @cZone = Zone                 -- (james01)
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Validate pickslipno
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62612
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
            SET @nErrNo = 62613
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
            SET @nErrNo = 62614
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
               SET @nErrNo = 62615
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped
               GOTO PickSlipNo_Fail
            END

            -- Check storer
            IF @cChkStorerKey IS NULL OR @cChkStorerKey = '' OR @cChkStorerKey <> @cStorer
            BEGIN
               SET @nErrNo = 62616
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
               SET @nErrNo = 62617
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
               SET @nErrNo = 62618
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
         -- (james15)
         -- Auto scan-in
         IF @cAutoScanIn = '1'
         BEGIN
            IF NOT EXISTS( SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)
               VALUES (@cPickSlipNo, GETDATE(), @cUserName)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 63915
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
                  SET @nErrNo = 63916
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                  GOTO PickSlipNo_Fail
               END
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 62619
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS not scan in
            GOTO PickSlipNo_Fail
         END
      END

      -- Validate pickslip already scan out
      IF @dScanOutDate IS NOT NULL
      BEGIN
         SET @nErrNo = 62620
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS scanned out
         GOTO PickSlipNo_Fail
      END

      SET @cSuggestedLOC = ''
      SET @cLoc = ''
      -- (james04)
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
   END
   GOTO Quit

   PickSlipNo_Fail:
   BEGIN
      SET @cOutField01 = '' -- PSNO
   END
END
GOTO Quit


/***********************************************************************************
Scn = 832. LOC screen
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

      -- SET @cSuggestedLOC = @cOutField05 -- suggested loc  (james04)

      -- Validate blank
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @nErrNo = 62621
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
         SET @nErrNo = 62622
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO LOC_Fail
      END

      -- Validate facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 62623
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO LOC_Fail
      END
      SET @cOutField03 = @cLOC

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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cPickSlipNo,
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

            -- (james13)
            SET @cDropID = SUBSTRING( @cDropIDBarcode, 1, 20) -- Dropid only accept 20 chars
         END
      END

      -- Check from id format (james02)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'DROPID', @cDropID) = 0
      BEGIN
         SET @nErrNo = 63914
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO DropID_Fail
      END

      -- Validate DropID SOS93811
      IF @cPickType = 'D'
      BEGIN
         IF ISNULL(@cDropID, '') = ''
         BEGIN
            SET @nErrNo = 63901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropID needed'
            GOTO DropID_Fail
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader PH WITH (NOLOCK)
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            WHERE PD.StorerKey = @cStorer
               AND PH.PickHeaderKey = @cPickSlipNo
               AND PD.DropID = @cDropID)
         BEGIN
            SET @nErrNo = 63902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid DropID'
            GOTO DropID_Fail
         END
      END

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
         IF @cPickShowSuggestedLOC = '1'
         BEGIN
            SET @nErrNo = 63911
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid DropID'
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
      END
      ELSE
      BEGIN
         -- Added lottable01 (james06)
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
         SET @nErrNo = 62624
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- No task in LOC
         GOTO LOC_Fail
      END

      -- Goto SKU screen
      IF @cPickType = 'S' OR @cPickType = 'D'
      BEGIN
         SET @nActPQty = 0 -- (james05)
         SET @nActMQty = 0 -- (james05)

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
      END

      -- Goto UCC screen
      IF @cPickType = 'U'
      BEGIN
         -- Reset UCC counter
         SET @nPUCC = 0
         SET @nPQTY = 0
         SET @nTaskUCC = CASE WHEN @nCaseCnt = 0 THEN 0 ELSE @nTaskQTY / @nCaseCnt END

         -- Prepare UCC screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
         SET @cOutField06 = @cLottable2
         SET @cOutField07 = @cLottable3
         SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)
         SET @cOutField09 = CAST( @nPUCC AS NVARCHAR( 5)) + '/' + CAST( @nTaskUCC AS NVARCHAR( 5))
         SET @cOutField10 = '' -- UCC
         SET @cOutField11 = @cLottable1

         -- Goto UCC screen
         SET @nScn = @nScn_UCC
         SET @nStep = @nStep_UCC
      END

      -- Goto ID screen
      IF @cPickType = 'P'
      BEGIN
         -- Prepare SKU screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
         SET @cOutField06 = CASE WHEN @cPickDontShowLot02 = '1' THEN '' ELSE @cLottable2 END
         SET @cOutField07 = @cLottable3
         SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)
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
         SET @cOutField15 = @cLottable1

         -- Goto SKU screen
         SET @nScn = @nScn_ID
         SET @nStep = @nStep_ID
      END

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
Scn = 833. SKU screen
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

      -- Skip task
      IF @cBarcode = '' OR @cBarcode IS NULL
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

      DECLARE @cChkLottable01 NVARCHAR(18)
      DECLARE @cChkLottable02 NVARCHAR(18)
      DECLARE @cChkLottable03 NVARCHAR(18)
      DECLARE @dChkLottable04 DATETIME

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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cPickSlipNo, @cBarcode, ' +
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
               '@cBarcode        NVARCHAR( 60), '  +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cPickSlipNo, @cBarcode,
               @cDropID          OUTPUT, @cLOC        OUTPUT, @cID         OUTPUT, @cSKU        OUTPUT, @nQty        OUTPUT,
               @cLottable1       OUTPUT, @cLottable2  OUTPUT, @cLottable3  OUTPUT, @dLottable4  OUTPUT, @dLottable05 OUTPUT,
               @cLottable06      OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11      OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo           OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO SKU_Fail

            IF @cSKU <> ''
               SET @cUPC = @cSKU
         END
      END

      -- Validate SKU
      -- Assumption: no SKU with same barcode.
      DECLARE @cChkSKU NVARCHAR( 30)
      DECLARE @nSKUCnt INT
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
         SET @nErrNo = 62630
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO SKU_Fail
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 62632
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MultiSKUBarcod'
         GOTO SKU_Fail
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
         SET @nErrNo = 62631
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Wrong SKU'
         GOTO SKU_Fail
      END

      -- Validate L01
      IF @cLottable1 <> '' AND @cChkLottable01 <> '' AND @cLottable1 <> @cChkLottable01
      BEGIN
         SET @nErrNo = 62633
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different L01'
         GOTO SKU_Fail
      END

      -- Validate L02
      IF @cLottable2 <> '' AND @cChkLottable02 <> '' AND @cLottable2 <> @cChkLottable02
      BEGIN
         SET @nErrNo = 62634
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different L02'
         GOTO SKU_Fail
      END

      -- Validate L03
      IF @cLottable3 <> '' AND @cChkLottable03 <> '' AND @cLottable3 <> @cChkLottable03
      BEGIN
         SET @nErrNo = 62635
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different L03'
         GOTO SKU_Fail
      END

      -- Validate L04
      IF (@dLottable4 <> 0 AND @dLottable4 IS NOT NULL) AND
         (@dChkLottable04 <> 0 AND @dChkLottable04 IS NOT NULL) AND
         @dLottable4 <> @dChkLottable04
      BEGIN
         SET @nErrNo = 62636
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Different L04'
         GOTO SKU_Fail
      END

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
               GOTO ID_Fail
         END
      END

      -- Prepare QTY screen var
      SET @cOutField01 = @cLottable1
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
      SET @cOutField14 = CASE WHEN ISNULL( @c_oFieled01, '') <> '' THEN @c_oFieled01 ELSE '' END -- @nPrefQTY
      --SET @cOutField15 = CASE WHEN ISNULL( @c_oFieled02, '') <> '' THEN @c_oFieled02 ELSE '' END -- @nMstQTY
      SET @cOutField15 = CASE WHEN ISNULL( @c_oFieled02, '') <> '' THEN @c_oFieled02 ELSE CASE WHEN @cDefaultToPickQty = '1' THEN '1' ELSE '' END END -- @nMstQTY

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
Scn = 834. QTY screen
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
      DECLARE @cPrefQTY NVARCHAR( 5)
      DECLARE @cMstQTY  NVARCHAR( 5)

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
         SET @nErrNo = 62640
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- PrefQTY
         GOTO QTY_Fail
      END

      -- Validate MstQTY
      IF @cMstQTY  = '' SET @cMstQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMstQTY, 0) = 0
      BEGIN
         SET @nErrNo = 62641
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
         SET @nErrNo = 62642
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over pick'
         GOTO QTY_Fail
      END

      -- Remember current value
      SET @nCurActPQty = @nActPQty
      SET @nCurActMQty = @nActMQty

      -- Assign new value
      SET @nActPQty = @cInField14
      SET @nActMQty = @cInField15

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
            SET @cDefaultLOC = ''
            -- If config turn on then skip short pick and continue confirm pick (james06)
            IF rdt.RDTGetConfig( @nFunc, 'DISABLESHORTPICK', @cStorer) = '1'
            BEGIN
               SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'PickConfirm_SP', @cStorer)
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
                  /* comment by james10. use get task to check for next available pick task
                  SET @cTempOrderKey = ''
                  SELECT @cTempOrderKey = OrderKey
                  FROM dbo.PickHeader WITH (NOLOCK)
                  WHERE PickHeaderKey = @cPickSlipNo

                  -- Check if this LOC still have something to pick. Default LOC if yes(james06)
                  IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                              WHERE StorerKey = @cStorer
                              AND   OrderKey = @cTempOrderKey
                              AND   LOC = @cLOC
                              AND   [Status] = '0'
                              HAVING ISNULL( SUM( QTY), 0) > 0)
                     SET @cDefaultLOC = @cLOC*/
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
                     @cPickType,  --SOS93811
                     @nMobile -- (ChewKP01)
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

               -- (james10)
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
      ELSE
      -- Full picked
      -- IF @nPQTY = @nTaskQTY                                                  --MT01
      BEGIN
         SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'PickConfirm_SP', @cStorer)
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
               @cPickType,  --SOS93811
               @nMobile -- (ChewKP01)
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

         -- Get next task in current LOC
         -- Added lottable01 (james06)
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

      -- Go to prev screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
   GOTO Quit

   QTY_Fail:
   BEGIN
      -- (Vicky02) - Start
      SET @cFieldAttr14 = ''
      -- (Vicky02) - End

      -- Prepare QTY screen var
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
   END

END
GOTO Quit


/***********************************************************************************
Scn = 835. UCC screen
   LOC       (field01)
   ID        (field02)
   SKU       (field03)
   DESCR     (field04, 05)
   LOTTABLE2 (field06)
   LOTTABLE3 (field07)
   LOTTABLE4 (field08)
   Counter   (field09)
   UCC       (field10, input)
************************************************************************************/
Step_UCC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField10
      SET @cBarcode = @cInField10

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

      -- Confirm skip task or short pick (UCC = Blank then press ENTER)
      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Remember parent screen
         SET @cParentScn = 'UCC'

         -- Picking not start
         IF @nPUCC = 0
         BEGIN
            -- Go to screen Message 'Skip Current Task?'
            SET @nScn = @nScn_SkipTask
            SET @nStep = @nStep_SkipTask
         END

         -- Picking started
         IF @nPUCC > 0
         BEGIN
            -- Go to screen 'Confirm Short Pick?'
            SET @nScn = @nScn_ShortPick
            SET @nStep = @nStep_ShortPick
         END
         GOTO Quit
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,
               @cUCCNo  = @cUCC        OUTPUT,
               @nErrNo  = @nErrNo      OUTPUT,
               @cErrMsg = @cErrMsg     OUTPUT,
               @cType   = 'UCCNo'

               IF @nErrNo <> 0
                  GOTO UCC_Fail
         END
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cPickSlipNo, @cBarcode, ' +
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
               '@cBarcode        NVARCHAR( 60), '  +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cPickSlipNo, @cBarcode,
               @cUCC             OUTPUT, @cLOC        OUTPUT, @cID         OUTPUT, @cSKU        OUTPUT, @nQty        OUTPUT,
               @cLottable1       OUTPUT, @cLottable2  OUTPUT, @cLottable3  OUTPUT, @dLottable4  OUTPUT, @dLottable05 OUTPUT,
               @cLottable06      OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11      OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo           OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO UCC_Fail
         END
      END

      -- Validate UCC
      EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT,
         @cUCC,
         @cStorer,
         '1',  -- Status. 1=Received
         @cChkSKU = @cSKU,
         @nChkQTY = 1, -- Turn on check Case count
         @cChkLOC = @cLOC

      IF @nErrNo <> 0
         GOTO UCC_Fail

      DECLARE @cUCCLOT       NVARCHAR( 10)
      DECLARE @cUCCID        NVARCHAR( 18)
      DECLARE @cUCCLottable1 NVARCHAR( 18)
      DECLARE @cUCCLottable2 NVARCHAR( 18)
      DECLARE @cUCCLottable3 NVARCHAR( 18)
      DECLARE @dUCCLottable4 DATETIME

      -- Get UCC lottable
      SELECT
         @cUCCLOT = UCC.LOT,
         @cUCCID = UCC.[ID],
         @cUCCLottable1 = LA.Lottable01,
         @cUCCLottable2 = LA.Lottable02,
         @cUCCLottable3 = LA.Lottable03,
         @dUCCLottable4 = LA.Lottable04
      FROM dbo.UCC UCC WITH (NOLOCK)
         INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (UCC.Lot = LA.LOT)
      WHERE UCC.UCCNo = @cUCC
         AND UCC.StorerKey = @cStorer
         AND UCC.Status = '1' -- Received

	  SET @cMatchUCCLottable = rdt.rdtGetConfig( @nFunc, 'MATCHUCCLOTTABLE', @cStorer)

      DECLARE @tLottableList TABLE
      (
         LottableNo    NVARCHAR(5)
      )

      INSERT INTO @tLottableList ( LottableNo) 
      SELECT VALUE FROM STRING_SPLIT(@cMatchUCCLottable, ',')

	   --NICK
   DECLARE @NICKMSG NVARCHAR(200)
   SET @NICKMSG = CONCAT_WS(',', 'rdtfnc_Pick-0', @cMatchUCCLottable )
   INSERT INTO DocInfo (Tablename, Storerkey, key1, key2, key3, lineSeq, Data)
	VALUES ('NICKLOG', '', '', '', '', 0, @NICKMSG)

      -- Validate UCC lottables
      IF EXISTS(SELECT 1 FROM @tLottableList WHERE LottableNo IN ('01', '02', '03', '04'))
      BEGIN
         SET @cLottableValidSP = rdt.RDTGetConfig( @nFunc, 'LottableValidSP', @cStorer)
		 SET @NICKMSG = CONCAT_WS(',', 'rdtfnc_Pick-1', @cLottableValidSP )
   INSERT INTO DocInfo (Tablename, Storerkey, key1, key2, key3, lineSeq, Data)
	VALUES ('NICKLOG', '', '', '', '', 0, @NICKMSG)

         EXEC rdt.rdt_861LottableValidWrapper 
               @nMobile          = @nMobile
               ,@nFunc           = @nFunc
               ,@cSPName         = @cLottableValidSP
               ,@cLangCode       = @cLangCode
               ,@cStorerKey      = @cStorer
               ,@cFacility       = @cFacility
               ,@nStep           = @nStep
               ,@nInputKey       = @nInputKey
               ,@cUCCLottable1   = @cUCCLottable1
               ,@cUCCLottable2   = @cUCCLottable2
               ,@cUCCLottable3   = @cUCCLottable3
               ,@dUCCLottable4   = @dUCCLottable4
               ,@cLottable01     = @cLottable1
               ,@cLottable02     = @cLottable2
               ,@cLottable03     = @cLottable3
               ,@dLottable04     = @dLottable4
               ,@tValidationData = @tValidationData
               ,@nErrNo          = @nErrNo      OUTPUT
               ,@cErrMsg         = @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO UCC_Fail
      END
      ELSE BEGIN
         IF @cUCCLottable1 <> @cLottable1 OR
            @cUCCLottable2 <> @cLottable2 OR
            @cUCCLottable3 <> @cLottable3 OR
            @dUCCLottable4 <> @dLottable4
         BEGIN
            SET @nErrNo = 62650
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCC LotbleDiff'
            GOTO UCC_Fail
         END
      END

      -- Validate TaskQTY not in full case count
      -- (when PickDetail.QTY edited from show pick tab)
      IF (@nPQTY + @nCaseCnt) > @nTaskQTY
      BEGIN
         SET @nErrNo = 62651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over pick'
         GOTO UCC_Fail
      END

      -- Validate double scan (prevent UCC from scaning twice)
      IF EXISTS( SELECT 1
         FROM RDT.RDTTempUCC
         WHERE StorerKey = @cStorer
            AND UCCNo = @cUCC)
      BEGIN
         SET @nErrNo = 62652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Double scan'
         GOTO UCC_Fail
      END

      -- Store UCC in RDTTempUCC
      INSERT INTO RDT.RDTTempUCC (TaskType, PickSlipNo, StorerKey, SKU, UCCNo, LOT, LOC, [ID], Lottable01, Lottable02, Lottable03, Lottable04, UCCLottable01, UCCLottable02, UCCLottable03, UCCLottable04)
      VALUES ('PICK', @cPickSlipNo, @cStorer, @cSKU, @cUCC, @cUCCLOT, @cLOC, @cUCCID, @cUCCLottable1, @cUCCLottable2, @cUCCLottable3, @dUCCLottable4, @cLottable1, @cLottable2, @cLottable3, @dLottable4)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 62653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd UCC fail'
         GOTO UCC_Fail
      END

      -- Update counter
      SET @nPQTY = @nPQTY + @nCaseCnt
      SET @nPUCC = @nPUCC + 1

      -- Confirm task if fully picked
      IF @nPQTY = @nTaskQTY
      BEGIN
         SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'PickConfirm_SP', @cStorer)
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
               'Y',  -- Y = UCC, N = SKU/UPC
               @cPickType,  --SOS93811
               @nMobile -- (ChewKP01)
         END

         IF @nErrNo <> 0
            GOTO Quit

         -- Delete RDTTempUCC
         DELETE RDT.RDTTempUCC WITH (ROWLOCK)
         WHERE TaskType = 'PICK'
            AND PickSlipNo = @cPickSlipNo
            AND StorerKey = @cStorer
            AND SKU = @cSKU
            AND LOC = @cLOC
            AND ID = @cID
            AND Lottable01 = @cLottable1
            AND Lottable02 = @cLottable2
            AND Lottable03 = @cLottable3
            AND Lottable04 = @dLottable4

         -- Get next task in current LOC
         -- Added lottable01 (james06)
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

                  SET @cOutField01 = 'PS NO:' + @cPickSlipNo
                  SET @cOutField03 = 'LOC NOT PICKED:'
                  SET @cOutField04 = @nLOC_Count
                  SET @cOutField05 = 'ORD NOT PICKED:'
                  SET @cOutField06 = @nORD_Count
                  SET @cOutField07 = 'SKU NOT PICKED:'
                  SET @cOutField08 = @nSKU_Count

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
               SET @cOutField01 = @cLOC
               -- Go to screen 'No more task in LOC'
               SET @nScn = @nScn_NoMoreTask
               SET @nStep = @nStep_NoMoreTask
            END

            GOTO Quit
         END
         ELSE
         BEGIN
            -- Reset next task var
            SET @nPQTY = 0
            SET @nPUCC = 0
            SET @nTaskUCC = CASE WHEN @nCaseCnt = 0 THEN 0 ELSE @nTaskQTY / @nCaseCnt END
         END
      END

      -- Refresh UCC screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField06 = @cLottable2
      SET @cOutField07 = @cLottable3
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)
      SET @cOutField09 = CAST( @nPUCC  AS NVARCHAR( 5)) + '/' + CAST( @nTaskUCC AS NVARCHAR( 5))
      SET @cOutField10 = '' -- UCC
      SET @cOutField11 = @cLottable1
   END

   IF @nInputKey = 0 -- ESC
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

      -- Picking not start
      IF @nPUCC = 0
      BEGIN
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

      -- Picking started
      IF @nPUCC > 0
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Remember parent screen
         SET @cParentScn = 'UCC'

         -- Go to screen 'Abort task?'
         SET @nScn = @nScn_AbortTask
         SET @nStep = @nStep_AbortTask
      END
   END
   GOTO Quit

   UCC_Fail:
   BEGIN
      SET @cOutField10 = ''  -- UCC
   END
END
GOTO Quit


/********************************************************************************
Scn = 836. ID screen
   LOC       (field01)
   ID        (field02)
   SKU       (field03)
   DESCR     (field04, 05)
   LOTTABLE2 (field06)
   LOTTABLE3 (field07)
   LOTTABLE4 (field08)
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
      DECLARE @cInID NVARCHAR( 18)

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

      -- Screen mapping
      SET @cInID = @cInField14 -- ID

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
               GOTO ID_Fail
         END
      END

      -- Validate ID
      IF @cID <> @cInID
      BEGIN
         -- Swap LOT and/or ID
         IF @cSwapIDSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSwapIDSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapIDSP) + ' @nMobile, @nFunc, @cLangCode, @cStorer, @cFacility ' +
                  ',@cPickSlipNo    ' +
                  ',@cLOC           ' +
                  ',@cDropID        ' +
                  ',@cID     OUTPUT ' +
                  ',@cSKU           ' +
                  ',@cUOM           ' +
                  ',@cLottable01    ' +
                  ',@cLottable02    ' +
                  ',@cLottable03    ' +
                  ',@dLottable04    ' +
                  ',@nTaskQTY       ' +
                  ',@cActID         ' +
                  ',@nErrNo  OUTPUT ' +
                  ',@cErrMsg OUTPUT '
               SET @cSQLParam = ' @nMobile INT, @nFunc INT, @cLangCode NVARCHAR(3), @cStorer NVARCHAR(15), @cFacility NVARCHAR(5) ' +
                  ',@cPickSlipNo     NVARCHAR( 10)  ' +
                  ',@cLOC            NVARCHAR( 10)  ' +
                  ',@cDropID         NVARCHAR( 20)  ' +
                  ',@cID             NVARCHAR( 18) OUTPUT  ' +
                  ',@cSKU            NVARCHAR( 20)  ' +
                  ',@cUOM            NVARCHAR( 10)  ' +
                  ',@cLottable01     NVARCHAR( 18)  ' +
                  ',@cLottable02     NVARCHAR( 18)  ' +
                  ',@cLottable03     NVARCHAR( 18)  ' +
                  ',@dLottable04     DATETIME       ' +
                  ',@nTaskQTY        INT            ' +
                  ',@cActID          NVARCHAR( 18)  ' +
                  ',@nErrNo          INT OUTPUT     ' +
                  ',@cErrMsg         NVARCHAR( 20) OUTPUT'
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @cStorer, @cFacility
                  ,@cPickSlipNo
                  ,@cLOC
                  ,@cDropID
                  ,@cID    OUTPUT
                  ,@cSKU
                  ,@cUOM
                  ,@cLottable1
                  ,@cLottable2
                  ,@cLottable3
                  ,@dLottable4
                  ,@nTaskQTY
                  ,@cInID
                  ,@nErrNo  OUTPUT
                  ,@cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO ID_Fail
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 62660
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Wrong ID'
            GOTO ID_Fail
         END
      END

      -- Confirm task
      SET @nPQTY = @nTaskQTY

      SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'PickConfirm_SP', @cStorer)
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
            'N',  -- Y = UCC, N = SKU/UPC
            @cPickType,  --SOS93811
            @nMobile -- (ChewKP01)
      END

      IF @nErrNo <> 0
         GOTO Quit

      -- Get next task in current LOC
      -- Added lottable01 (james06)
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
         SET @cOutField06 = CASE WHEN @cPickDontShowLot02 = '1' THEN '' ELSE @cLottable2 END
         SET @cOutField07 = @cLottable3
         SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)
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
         SET @cOutField15 = @cLottable1
      END

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
               ',@cExtendedInfo  OUTPUT ' +
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
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @nFunc, @cLangCode, @nStep_ID, @nStep, @nInputKey, @cFacility, @cStorer
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

   ID_Fail:
   BEGIN
      SET @cOutField14 = '' -- ID
   END
END
GOTO Quit


/***********************************************************************************
Step 7. Scn = 837. Message 'Skip Current Task?'
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
         -- Get next task in current LOC
         -- Added lottable01 (james06)
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

   -- Back to UCC screen
   IF @cParentScn = 'UCC'
   BEGIN
      -- Prepare UCC screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField06 = @cLottable2
      SET @cOutField07 = @cLottable3
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)
      SET @cOutField09 = CAST( @nPUCC AS NVARCHAR( 5)) + '/' + CAST( @nTaskUCC AS NVARCHAR( 5))
      SET @cOutField10 = '' -- UCC
      SET @cOutField11 = @cLottable1

      -- Go to UCC screen
      SET @nScn = @nScn_UCC
      SET @nStep = @nStep_UCC
   END

   -- Back to ID screen
   IF @cParentScn = 'ID'
   BEGIN
      -- Refresh ID screen var
      -- SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField06 = @cLottable2
      SET @cOutField07 = @cLottable3
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)
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
      SET @cOutField15 = @cLottable1

      -- Go to ID screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END
   GOTO Quit

   SkipTask_Option_Fail:
   BEGIN
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Scn = 838. Message. 'Confirm Short Pick?'
   Option (field01)
********************************************************************************/
Step_ShortPick:
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
         SET @nErrNo = 62672
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required
         GOTO ShortPick_Option_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 62673
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
         GOTO ShortPick_Option_Fail
      END

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
               GOTO ShortPick_Option_Fail
         END
      END


      IF @cOption = '1'  -- Yes
      BEGIN
         DECLARE @cUCCTask NVARCHAR( 1)
         SET @cUCCTask = CASE WHEN @cParentScn = 'UCC' THEN 'Y' ELSE 'N' END

         -- Confirm Task
         SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'PickConfirm_SP', @cStorer)
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
               @cPickType,  --SOS93811
               @nMobile -- (ChewKP01)
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
         -- Added lottable01 (james06)
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

   -- Back to UCC screen
   IF @cParentScn = 'UCC'
   BEGIN
      -- Prep UCC screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField06 = @cLottable2
      SET @cOutField07 = @cLottable3
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)
      SET @cOutField09 = CAST( @nPUCC AS NVARCHAR( 5)) + '/' + CAST( @nTaskUCC AS NVARCHAR( 5))
      SET @cOutField10 = '' -- UCC
      SET @cOutField11 = @cLottable1

      -- Go to UCC screen
      SET @nScn = @nScn_UCC
      SET @nStep = @nStep_UCC
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
Scn = 839. Message. 'No more task in LOC ....'
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
Scn = 840. Message. 'Abort Task?'
   Option (field01)
********************************************************************************/
Step_AbortTask:
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
         SET @nErrNo = 62675
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required
         GOTO AbortTask_Option_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 62676
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
         GOTO AbortTask_Option_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
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
               SET @nErrNo = 62677
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Del UCC fail'
               GOTO AbortTask_Option_Fail
            END
         END

         -- Prepare LOC screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = @cSuggestedLOC
         SET @cOutField03 = '' -- LOC
         SET @cOutField04 = '' -- DropID
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC

         -- Back to LOC screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC

         GOTO Quit
      END
   END

   -- ESC or No

   -- Back to UCC screen
   IF @cParentScn = 'UCC'
   BEGIN
      -- Prep UCC screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField06 = @cLottable2
      SET @cOutField07 = @cLottable3
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable4)
      SET @cOutField09 = CAST( @nPUCC AS NVARCHAR( 5)) + '/' + CAST( @nTaskUCC AS NVARCHAR( 5))
      SET @cOutField10 = '' -- UCC
      SET @cOutField11 = @cLottable1

      -- Go to UCC screen
      SET @nScn = @nScn_UCC
      SET @nStep = @nStep_UCC
   END
   GOTO Quit

   AbortTask_Option_Fail:
   BEGIN
      SET @cOption = ''
   END
END
GOTO Quit

/********************************************************************************
Scn = 842. Message. 'LOC NOT MATCH'
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
         SET @nErrNo = 63912
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required
         GOTO Step_ConfirmLOC_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 63913
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
Scn = 843. Message.
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
      V_UOM          = @cUOM,
      V_QTY          = @cQTY,
      V_UCC          = @cUCC,
      V_Lottable01   = @cLottable1,
      V_Lottable02   = @cLottable2,
      V_Lottable03   = @cLottable3,
      V_Lottable04   = @dLottable4,

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


      V_String1      = @cAutoScanIn,
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