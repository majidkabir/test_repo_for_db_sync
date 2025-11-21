SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdtfnc_PickSKU                                               */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: Pick SKU/UPC                                                         */
/*                                                                               */
/* Date         Rev  Author     Purposes                                         */
/* 2016-06-20   1.0  Ung        SOS372037 Migrate from 860 Pick SKU/UPC          */
/* 2017-02-09   1.1  Ung        WMS-1000 Add verify lottable                     */
/* 2017-02-21   1.2  Ung        WMS-1715 Add DefaultToLOC, SkipLOC,              */
/*                              balance pick later                               */
/* 2017-10-03   1.3  Ung        WMS-3052 Add VerifyID                            */
/* 2018-09-25   1.4  Ung        WMS-6410 Add ExtendedInfo at LOC screen          */
/*                              Add rdtMobRec Field16..20                        */
/* 2019-10-18   1.5  James      WMS-10860 Add auto scan in (james01)             */
/* 2019-12-23   1.6  James      WMS-11487 Add ExtValid @ qty screen (james02)    */
/* 2020-02-20   1.7  James      WMS-12097 Add MultiSKUBarcode (james03)          */
/* 2020-10-10   1.8  YeeKung    WMS-15415 Add DecodeidSP (yeekung01)             */
/* 2020-08-28   1.9  YeeKung    WMS-14706 Add clearid (yeekung02)                */
/* 2020-12-28   2.0  YeeKung    WMS-15995 Add PickZone (yeekung03 )              */
/* 2020-12-28   2.1  WyeChun    Add in PickZone (WC01)                           */  
/* 2022-04-08   2.2  Ung        WMS-19402 Add AutoScanOut                        */
/* 2021-10-04   2.3  YeeKung    WMS-16543 Fix multisku (yeekung04)               */   
/*                              Add SwapIDSP                                     */
/* 2022-12-30   2.4  Calvin     JSM-119684 Reset Pickzone Variable (CLVN01)      */
/* 2022-11-24   2.5  Ung        WMS-21032 Fix ExtendedInfoSP at LOC screen       */
/*                              Add DefaultQTY                                   */
/* 2023-03-15   2.6  YeeKung    WMS-21872 Fix Bug (yeekung05)                    */
/* 2024-07-04   2.7  JHU151     FCR-537 @cDefaultQTY to NVARCHAR(10)             */
/* 2024-07-08   2.8  JHU151     FCR-330 SSCC code generator                      */
/* 2024-10-17   2.9  PXL009     FCR-759 ID and UCC Length Issue                  */
/*********************************************************************************/

CREATE   PROC rdt.rdtfnc_PickSKU (
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @bSuccess     INT,
   @cOption      NVARCHAR( 1),
   @cSQL         NVARCHAR( MAX),
   @cSQLParam    NVARCHAR( MAX),
   @nMorePage    INT

-- RDT.RDTMobRec variables
DECLARE
   @nFunc        INT,
   @nScn         INT,
   @nStep        INT,
   @cLangCode    NVARCHAR( 3),
   @nInputKey    INT,
   @nMenu        INT,

   @cStorerKey   NVARCHAR( 15),
   @cUserName    NVARCHAR( 18),
   @cFacility    NVARCHAR( 5),

   @cPickSlipNo  NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cDropID      NVARCHAR( 20),
   @cSKU         NVARCHAR( 20),
   @cSKUDescr    NVARCHAR( 60),
   @cPUOM        NVARCHAR( 10),
   @nTaskQTY     INT,
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,

   @cSuggLOC      NVARCHAR( 10),
   @cSuggID       NVARCHAR( 18),
   @cLottableCode NVARCHAR( 20),
   @cPPK          NVARCHAR( 5),
   @cToLOC        NVARCHAR( 10),
   @cType         NVARCHAR( 10),

   @cPUOM_Desc   NVARCHAR( 5),
   @cMUOM_Desc   NVARCHAR( 5),
   @nPUOM_Div    INT,
   @nPQTY        INT,
   @nMQTY        INT,
   @nQTY         INT,
   @nAction      INT,

   @cOrderKey      NVARCHAR( 10)  ,
   @cLoadKey       NVARCHAR( 10)  ,
   @cZone          NVARCHAR( 18)  ,

   @cDefaultQTY         NVARCHAR( 10),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cSuggestLOC         NVARCHAR( 20),
   @cOverrideLOC        NVARCHAR( 1),
   @cDecodeSP           NVARCHAR( 20),
   @cMoveQTYAlloc       NVARCHAR( 1),
   @cMoveQTYPick        NVARCHAR( 1),
   @cSkipLOC            NVARCHAR( 1),
   @cDefaultToLOC       NVARCHAR( 10),
   @cVerifyID           NVARCHAR( 1),
   @cAutoScanIn         NVARCHAR( 1),  -- (james01)
   @cMultiSKUBarcode    NVARCHAR( 3),
   @cDoctype            NVARCHAR(5),   --yeekung01
   @cClearid            NVARCHAR( 1),  --(yeekung02)
   @cPickZone           NVARCHAR(10),  --(yeekung03)
   @cVerifyPickZone     NVARCHAR(1),   --(yeekung03)
   @cSwapidSP           NVARCHAR(20), 
   @cExtendedScreenSP   NVARCHAR(20),
   @tExtScnData			VariableTable, --(JHU151)

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1),
   @cInField16 NVARCHAR( 60),   @cOutField16 NVARCHAR( 60),    @cFieldAttr16 NVARCHAR( 1),
   @cInField17 NVARCHAR( 60),   @cOutField17 NVARCHAR( 60),    @cFieldAttr17 NVARCHAR( 1),
   @cInField18 NVARCHAR( 60),   @cOutField18 NVARCHAR( 60),    @cFieldAttr18 NVARCHAR( 1),
   @cInField19 NVARCHAR( 60),   @cOutField19 NVARCHAR( 60),    @cFieldAttr19 NVARCHAR( 1),
   @cInField20 NVARCHAR( 60),   @cOutField20 NVARCHAR( 60),    @cFieldAttr20 NVARCHAR( 1),

   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( 250)

DECLARE 
   @cBarcode       NVARCHAR(60),
   @cUPC           NVARCHAR(30),
   @cChkLottable01 NVARCHAR( 18), @cChkLottable02 NVARCHAR( 18), @cChkLottable03 NVARCHAR( 18), @dChkLottable04 DATETIME,      @dChkLottable05 DATETIME,
   @cChkLottable06 NVARCHAR( 30), @cChkLottable07 NVARCHAR( 30), @cChkLottable08 NVARCHAR( 30), @cChkLottable09 NVARCHAR( 30), @cChkLottable10 NVARCHAR( 30),
   @cChkLottable11 NVARCHAR( 30), @cChkLottable12 NVARCHAR( 30), @dChkLottable13 DATETIME,      @dChkLottable14 DATETIME,      @dChkLottable15 DATETIME,
   @cUserDefine01  NVARCHAR( 30) -- FCR759

-- Getting Mobile information
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,

   @nPUOM_Div     = V_Integer1,
   @nPQTY         = V_Integer2,
   @nMQTY         = V_Integer3,
   @nQTY          = V_Integer4,

   @cPickSlipNo = V_PickSlipNo,
   @cLOC        = V_LOC,
   @cID         = V_ID,
   @cDropID     = V_CaseID,
   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @cPUOM       = V_UOM,
   @nTaskQTY    = V_QTY,
   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @dLottable05 = V_Lottable05,
   @cLottable06 = V_Lottable06,
   @cLottable07 = V_Lottable07,
   @cLottable08 = V_Lottable08,
   @cLottable09 = V_Lottable09,
   @cLottable10 = V_Lottable10,
   @cLottable11 = V_Lottable11,
   @cLottable12 = V_Lottable12,
   @dLottable13 = V_Lottable13,
   @dLottable14 = V_Lottable14,
   @dLottable15 = V_Lottable15,

   @cSuggLOC         = V_String1,
   @cMultiSKUBarcode = V_String2,
   @cLottableCode    = V_String3,
   @cPPK             = V_String4,
   @cToLOC           = V_String5,
   @cType            = V_String6,
   @cSuggID          = V_String7,

   @cMUOM_Desc       = V_String10,
   @cPUOM_Desc       = V_String11,

   @cDefaultQTY         = V_String20,
   @cExtendedValidateSP = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedInfoSP     = V_String23,
   @cExtendedInfo       = V_String24,
   @cSuggestLOC         = V_String25,
   @cOverrideLOC        = V_String26,
   @cDecodeSP           = V_String27,
   @cMoveQTYAlloc       = V_String28,
   @cMoveQTYPick        = V_String29,
   @cSkipLOC            = V_String30,
   @cDefaultToLOC       = V_String31,
   @cVerifyID           = V_String32,
   @cAutoScanIn         = V_String33,
   @cClearid            = V_String34,
   @cPickZone           = V_string35,
   @cVerifyPickZone     = V_string36,
   @cOrderKey           = V_string37,
   @cLoadKey            = V_string38,
   @cZone               = V_string39,
   @cSwapidSP           = V_String40,
   @cExtendedScreenSP   = V_String41,
   @cUserDefine01       = V_String42,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01  = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02, @cFieldAttr02  = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03  = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04  = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05  = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06  = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07  = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08  = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09  = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10  = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11  = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12  = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13  = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14  = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15  = FieldAttr15,
   @cInField16 = I_Field16,   @cOutField16 = O_Field16,  @cFieldAttr16  = FieldAttr16,
   @cInField17 = I_Field17,   @cOutField17 = O_Field17,  @cFieldAttr17  = FieldAttr17,
   @cInField18 = I_Field18,   @cOutField18 = O_Field18,  @cFieldAttr18  = FieldAttr18,
   @cInField19 = I_Field19,   @cOutField19 = O_Field19,  @cFieldAttr19  = FieldAttr19,
   @cInField20 = I_Field20,   @cOutField20 = O_Field20,  @cFieldAttr20  = FieldAttr20

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_PickSlipNo       INT,  @nScn_PickSlipNo       INT,
   @nStep_LOC              INT,  @nScn_LOC              INT,
   @nStep_SKU              INT,  @nScn_SKU              INT,
   @nStep_QTY              INT,  @nScn_QTY              INT,
   @nStep_TOLOC            INT,  @nScn_TOLOC            INT,
   @nStep_SkipTask         INT,  @nScn_SkipTask         INT,
   @nStep_ShortPick        INT,  @nScn_ShortPick        INT,
   @nStep_VerifyLottable   INT,  @nScn_VerifyLottable   INT,
   @nStep_VerifyID         INT,  @nScn_VerifyID         INT,
   @nStep_MultiSKU         INT,  @nScn_MultiSKU         INT

SELECT
   @nStep_PickSlipNo       = 1,  @nScn_PickSlipNo     = 4690,
   @nStep_LOC              = 2,  @nScn_LOC            = 4691,
   @nStep_SKU              = 3,  @nScn_SKU            = 4692,
   @nStep_QTY              = 4,  @nScn_QTY            = 4693,
   @nStep_TOLOC            = 5,  @nScn_TOLOC          = 4694,
   @nStep_SkipTask         = 6,  @nScn_SkipTask       = 4695,
   @nStep_ShortPick        = 7,  @nScn_ShortPick      = 4696,
   @nStep_VerifyLottable   = 8,  @nScn_VerifyLottable = 3990,
   @nStep_VerifyID         = 9,  @nScn_VerifyID       = 4697,
   @nStep_MultiSKU         = 10, @nScn_MultiSKU       = 3570

IF @nFunc = 830
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 830
   IF @nStep = 1  GOTO Step_PickSlipNo       -- Scn = 4690. PickSlipNo
   IF @nStep = 2  GOTO Step_LOC              -- Scn = 4691. LOC, DropID
   IF @nStep = 3  GOTO Step_SKU              -- Scn = 4692. SKU
   IF @nStep = 4  GOTO Step_QTY              -- Scn = 4693. QTY
   IF @nStep = 5  GOTO Step_ToLOC            -- Scn = 4694. TO LOC
   IF @nStep = 6  GOTO Step_SkipTask         -- Scn = 4695. Skip Current Task?
   IF @nStep = 7  GOTO Step_ShortPick        -- Scn = 4696. Confrim Short Pick?
   IF @nStep = 8  GOTO Step_VerifyLottable   -- Scn = 3990. Verify lottable
   IF @nStep = 9  GOTO Step_VerifyID         -- Scn = 4697. Verify ID
   IF @nStep = 10 GOTO Step_MultiSKU         -- Scn = 3570  Multi SKU screen
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 830
********************************************************************************/
Step_Start:
BEGIN
   -- Get default UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   -- Get RDT storer configure
   SET @cAutoScanIn = rdt.rdtGetConfig( @nFunc, 'AutoScanIn', @cStorerKey)
   SET @cClearID = rdt.RDTGetConfig( @nFunc, 'clearID', @cStorerKey)
   SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
   SET @cOverrideLOC = rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorerKey)
   SET @cSkipLOC = rdt.RDTGetConfig( @nFunc, 'SkipLOC', @cStorerKey)
   SET @cSuggestLOC = rdt.RDTGetConfig( @nFunc, 'SuggestLOC', @cStorerKey)
   SET @cSwapidSP = rdt.RDTGetConfig( @nFunc, 'SwapIDSP', @cStorerKey) 
   SET @cVerifyID = rdt.RDTGetConfig( @nFunc, 'VerifyID', @cStorerKey)
   SET @cVerifyPickZone = rdt.RDTGetConfig( @nFunc, 'verifypickzone', @cStorerKey)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDefaultQTY = rdt.rdtGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
   IF @cDefaultQTY = '0'
      SET @cDefaultQTY = ''
   SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
   IF @cDefaultToLOC = '0'
      SET @cDefaultToLOC = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
      SET @cExtendedScreenSP = ''

   -- Sign-In
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   -- Prepare next screen var
   SET @cOutField01 = '' -- PickSlipNo

   -- Go to PickSlipNo screen
   SET @nScn = @nScn_PickSlipNo
   SET @nStep = @nStep_PickSlipNo
END
GOTO Quit


/************************************************************************************
Scn = 4690. PickSlipNo screen
 PSNO    (field01)
************************************************************************************/
Step_PickSlipNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01

      -- Check blank
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 101951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNO required
         GOTO PickSlipNo_Fail
      END

      DECLARE @cChkStorerKey  NVARCHAR( 15)
      DECLARE @dScanInDate    DATETIME
      DECLARE @dScanOutDate   DATETIME

      -- Get PickHeader info
      SELECT TOP 1
         @cOrderKey = OrderKey,
         @cLoadKey = ExternOrderKey,
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Check pickslipno valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 101952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
         GOTO PickSlipNo_Fail
      END

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         -- Check order shipped
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = RKL.Orderkey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
              AND O.Status = '9')
         BEGIN
            SET @nErrNo = 101953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped
            GOTO PickSlipNo_Fail
         END

         -- Check diff storer
         IF EXISTS( SELECT TOP 1 1
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = RKL.Orderkey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
              AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 101954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO PickSlipNo_Fail
         END
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
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
            SET @nErrNo = 101955
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped
            GOTO PickSlipNo_Fail
         END

         -- Check storer
         IF @cChkStorerKey <> @cStorerKey
         BEGIN
            SET @nErrNo = 101956
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO PickSlipNo_Fail
         END
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         -- Check order shipped
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
               AND O.Status = '9')
         BEGIN
            SET @nErrNo = 101957
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped
            GOTO PickSlipNo_Fail
         END

         -- Check diff storer
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 101958
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO PickSlipNo_Fail
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
                  SET @nErrNo = 101998
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
                  SET @nErrNo = 101999
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                  GOTO Quit
               END
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 101959
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS not scan in
            GOTO PickSlipNo_Fail
         END
      END

      -- Validate pickslip already scan out
      IF @dScanOutDate IS NOT NULL
      BEGIN
         SET @nErrNo = 101960
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS scanned out
         GOTO PickSlipNo_Fail
      END

      -- Get next LOC
      SET @cLoc = ''
      SET @cSuggLOC = ''
      SET @cPickZone = ''	--(CLVN01)
      IF @cSuggestLOC = '1'
      BEGIN
         EXEC rdt.rdt_PickSKU_SuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cPickSlipNo,
            @cPickZone,
            @cLOC,
            @cSuggLOC OUTPUT,
            @nErrNo   OUTPUT,
            @cErrMsg  OUTPUT
         IF @nErrNo <> 0 AND
            @nErrNo <> -1
            GOTO Quit
      END

      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSuggLOC
      SET @cOutField03 = '' -- LOC
      SET @cOutField04 = '' -- DropID
      SET @cOutField05 = '' -- PickZone
      SET @cOutField20 = '' -- ExtendedInfo

      IF @cVerifyPickZone='1'
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- LOC
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC

      -- Go to LOC screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Sign-Out
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
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
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cSuggLOC NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cDropID       NVARCHAR( 20), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cLottable01   NVARCHAR( 18), ' +
            '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nTaskQTY      INT,           ' +
            '@nQTY          INT,           ' +
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_PickSlipNo, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField20 = @cExtendedInfo
      END
   END

   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      GOTO Step_99
   END

   GOTO Quit

   PickSlipNo_Fail:
   BEGIN
      SET @cOutField01 = '' -- PSNO
   END
END
GOTO Quit


/***********************************************************************************
Scn = 4691. LOC screen
   PSNO     (field01)
   Sugg LOC (field02)
   LOC      (field03, input)
   DropID   (field04, input)
***********************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField03 -- LOC
      SET @cDropID = @cInField04 -- DropID
      SET @cBarcode = @cInField04 -- Barcode for DropID
      SET @cPickZone = @cInField05 -- PickZone
      SET @cUserDefine01 = ''
      -- Check PickZone
      IF @cPickZone <> ''
      BEGIN
         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
         BEGIN
            -- Check zone in PickSlip
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE RKL.PickSlipNo = @cPickSlipNo
               AND LOC.PickZone = @cPickZone)
            BEGIN
               SET @nErrNo = 147251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone
               SET @cOutField05 = '' -- PickZone
               GOTO PickZone_Fail
            END
         END

         -- Discrete PickSlip
         ELSE IF @cOrderKey <> ''
         BEGIN
            -- Check zone in PickSlip
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE O.OrderKey = @cOrderKey
                  AND LOC.PickZone = @cPickZone)
            BEGIN
               SET @nErrNo = 147252
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone
               SET @cOutField05 = '' -- PickZone
               GOTO PickZone_Fail
            END
         END

         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
         BEGIN
            -- Check zone in PickSlip
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE LPD.LoadKey = @cLoadKey
                  AND LOC.PickZone = @cPickZone)
            BEGIN
               SET @nErrNo = 147253
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone
               SET @cOutField05 = '' -- PickZone
               GOTO PickZone_Fail
            END
         END

         -- Custom PickSlip
         ELSE
         BEGIN
            -- Check zone in PickSlip
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND LOC.PickZone = @cPickZone)
            BEGIN
               SET @nErrNo = 147254
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone
               SET @cOutField05 = '' -- PickZone
               GOTO PickZone_Fail
            END
         END
      END
      SET @cOutField05 = @cPickZone

      -- Validate blank
      IF @cLOC = ''
      BEGIN
         IF @cSuggestLOC = '1' AND @cSkipLOC = '1'
         BEGIN
            EXEC rdt.rdt_PickSKU_SuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPickSlipNo,
               @cPickZone, 
               @cSuggLOC,
               @cSuggLOC OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT
            IF @nErrNo <> 0 AND
               @nErrNo <> -1
               GOTO Quit

            -- Remain in current screen
            SET @cOutField02 = @cSuggLOC
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 101961
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC needed
            GOTO LOC_Fail
         END
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID     = @cDropID  OUTPUT,
               @nErrNo  = @nErrNo   OUTPUT,
               @cErrMsg = @cErrMsg  OUTPUT,
               @cType   = 'ID'
            IF @nErrNo <> 0
               GOTO DropID_Fail
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,@cLoc,@cDropid,@cpickslipno,@cBarcode,@cFieldName, ' +
                  ' @cUPC         OUTPUT,@cSKu         OUTPUT,  @nQTY OUTPUT,' +
                  ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
                  ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
                  ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
                  ' @cUserDefine01 OUTPUT, ' +
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  ' @nMobile      INT,             ' +
                  ' @nFunc        INT,             ' +
                  ' @cLangCode    NVARCHAR( 3),    ' +
                  ' @nStep        INT,             ' +
                  ' @nInputKey    INT,             ' +
                  ' @cStorerKey   NVARCHAR( 15),   ' +
                  ' @cFacility    NVARCHAR( 20),   ' +
                  ' @cLOC         NVARCHAR( 10),   ' +
                  ' @cDropid      NVARCHAR( 20),   ' +
                  ' @cpickslipno  NVARCHAR( 20),   ' +
                  ' @cBarcode     NVARCHAR( 60),   ' +
                  ' @cFieldName   NVARCHAR( 10),   ' +
                  ' @cUPC         NVARCHAR( 20)  OUTPUT, ' +
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
                  ' @cUserDefine01 NVARCHAR( 30) OUTPUT, ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey,@cFacility,@cLoc,@cDropid,@cpickslipno, @cBarcode, 'DROPID',
                  @cDropid        OUTPUT, @cSKU           OUTPUT, @cDefaultQTY       OUTPUT,
                  @cChkLottable01 OUTPUT, @cChkLottable02 OUTPUT, @cChkLottable03 OUTPUT, @dChkLottable04 OUTPUT, @dChkLottable05 OUTPUT,
                  @cChkLottable06 OUTPUT, @cChkLottable07 OUTPUT, @cChkLottable08 OUTPUT, @cChkLottable09 OUTPUT, @cChkLottable10 OUTPUT,
                  @cChkLottable11 OUTPUT, @cChkLottable12 OUTPUT, @dChkLottable13 OUTPUT, @dChkLottable14 OUTPUT, @dChkLottable15 OUTPUT,
                  @cUserDefine01  OUTPUT,
                  @nErrNo         OUTPUT, @cErrMsg        OUTPUT

               IF @nErrNo <> 0
                  GOTO DropID_Fail
            END
         END
      END

      -- Get LOC info
      DECLARE @cChkFacility NVARCHAR( 5)
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 101962
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO LOC_Fail
      END

      -- Validate facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 101963
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO LOC_Fail
      END

      -- Check if not allow override LOC
      IF @cSuggLOC <> '' AND @cSuggestLOC = '1'
      BEGIN
         IF @cLOC <> @cSuggLOC AND @cOverrideLOC <> '1'
         BEGIN
            SET @nErrNo = 101965
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
            GOTO LOC_Fail
         END
      END
      SET @cOutField03 = @cLOC

      -- Check DropID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0
      BEGIN
         SET @nErrNo = 101964
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO DropID_Fail
      END
      SET @cOutField04 = @cDropID

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +  --WC01       
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cPickSlipNo   NVARCHAR( 10), ' +
               '@cPickZone     NVARCHAR( 10), ' + --WC01  
               '@cSuggLOC NVARCHAR( 10), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@nTaskQTY      INT,           ' +
               '@nQTY          INT,           ' +
               '@cToLOC        NVARCHAR( 10), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,         
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nTaskQTY, @nPQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cVerifyID = '1'
      BEGIN
         SET @cID = ''
         SET @cSuggID = ''
         EXEC rdt.rdt_PickSKU_SuggestID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cPickSlipNo,
            @cPickZone,
            @cLOC,
            @cSuggID  OUTPUT,
            @nErrNo   OUTPUT,
            @cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare ID screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cSuggID
         SET @cOutField03 = ''

         -- Goto ID screen
         SET @nScn = @nScn_VerifyID
         SET @nStep = @nStep_VerifyID

         GOTO Quit
      END

      SELECT @cSKU = '', @nTaskQTY = 0,
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

      -- Get task
      EXEC rdt.rdt_PickSKU_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPUOM, 4, @cPickSlipNo,@cPickZone,@cLOC, @cID,
         @cSKU         OUTPUT, @nTaskQTY     OUTPUT,
         @cLottable01  OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT,
         @cLottable06  OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT,
         @cLottable11  OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT,
         @cLottableCode OUTPUT,
         @cSKUDescr    OUTPUT,
         @cMUOM_Desc   OUTPUT,
         @cPUOM_Desc   OUTPUT,
         @nPUOM_Div    OUTPUT,
         @nErrNo       OUTPUT,
         @cErrMsg      OUTPUT,
         @cPPK         OUTPUT
      IF @nErrNo <> 0
         GOTO LOC_Fail

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

      -- Prepare SKU screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = '' --@cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField20 = '' -- ExtendedInfo

      -- Goto SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Scan out        
      SET @nErrNo = 0        
      EXEC rdt.rdt_PickSKU_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey        
         ,@cPickSlipNo        
         ,@nErrNo       OUTPUT        
         ,@cErrMsg      OUTPUT        
      IF @nErrNo <> 0        
         GOTO Quit   
      
      -- Prepare prev screen var
      SET @cPickSlipNo = ''
      SET @cOutField01 = '' -- PSNO

      -- Go to prev screen
      SET @nScn = @nScn_PickSlipNo
      SET @nStep = @nStep_PickSlipNo
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cSuggLOC      NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cDropID       NVARCHAR( 20), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cLottable01   NVARCHAR( 18), ' +
            '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nTaskQTY      INT,           ' +
            '@nQTY          INT,           ' +
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_LOC, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField20 = @cExtendedInfo
      END
   END
   GOTO Quit

   PickZone_Fail:
   BEGIN
      SET @cPickZone = ''
      SET @cOutField05 = '' -- PickZone
      EXEC rdt.rdtSetFocusField @nMobile, 5 -- PickZOne
      GOTO Quit
   END

   LOC_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField03 = '' -- LOC
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC
      GOTO Quit
   END

   DropID_Fail:
   BEGIN
      SET @cDropID = ''
      SET @cOutField04 = '' -- DropID
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
      GOTO Quit
   END
END
GOTO Quit


/********************************************************************************
Scn = 4692. SKU screen
   LOC       (field01)
   DROPID    (field02)
   SKU       (field03)
   SKU       (field04, input)
   DESC1     (field05)
   DESC1     (field06)
   LOTTABLE  (field07)
   LOTTABLE  (field08)
   LOTTABLE  (field09)
   LOTTABLE  (field10)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cBarcode = @cInField04
      SET @cUPC = LEFT( @cInField04, 30)

      -- Skip task
      IF @cBarcode = '' OR @cBarcode IS NULL
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Go to 'Skip Current Task?' screen
         SET @nScn = @nScn_SkipTask
         SET @nStep = @nStep_SkipTask

         GOTO Quit
      END

      SELECT
         @cChkLottable01 = '', @cChkLottable02 = '', @cChkLottable03 = '',    @dChkLottable04 = NULL,  @dChkLottable05 = NULL,
         @cChkLottable06 = '', @cChkLottable07 = '', @cChkLottable08 = '',    @cChkLottable09 = '',    @cChkLottable10 = '',
         @cChkLottable11 = '', @cChkLottable12 = '', @dChkLottable13 = NULL,  @dChkLottable14 = NULL,  @dChkLottable15 = NULL

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUPC        = @cUPC           OUTPUT,
               @cLottable01 = @cChkLottable01 OUTPUT,
               @cLottable02 = @cChkLottable02 OUTPUT,
               @cLottable03 = @cChkLottable03 OUTPUT,
               @dLottable04 = @dChkLottable04 OUTPUT,
               @dLottable05 = @dChkLottable05 OUTPUT,
               @cLottable06 = @cChkLottable06 OUTPUT,
               @cLottable07 = @cChkLottable07 OUTPUT,
               @cLottable08 = @cChkLottable08 OUTPUT,
               @cLottable09 = @cChkLottable09 OUTPUT,
               @cLottable10 = @cChkLottable10 OUTPUT,
               @cLottable11 = @cChkLottable11 OUTPUT,
               @cLottable12 = @cChkLottable12 OUTPUT,
               @dLottable13 = @dChkLottable13 OUTPUT,
               @dLottable14 = @dChkLottable14 OUTPUT,
               @dLottable15 = @dChkLottable15 OUTPUT
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,@cLoc,@cDropid,@cpickslipno,@cBarcode,@cFieldName, ' +
                  ' @cUPC         OUTPUT,@cSKu         OUTPUT,  @nQTY OUTPUT,' +
                  ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
                  ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
                  ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
                  ' @cUserDefine01 OUTPUT, ' +
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  ' @nMobile      INT,             ' +
                  ' @nFunc        INT,             ' +
                  ' @cLangCode    NVARCHAR( 3),    ' +
                  ' @nStep        INT,             ' +
                  ' @nInputKey    INT,             ' +
                  ' @cStorerKey   NVARCHAR( 15),   ' +
                  ' @cFacility    NVARCHAR( 20),   ' +
                  ' @cLOC         NVARCHAR( 10),   ' +
                  ' @cDropid      NVARCHAR( 20),   ' +
                  ' @cpickslipno  NVARCHAR( 20),   ' +
                  ' @cBarcode     NVARCHAR( 60),   ' +
                  ' @cFieldName   NVARCHAR( 10),   ' +
                  ' @cUPC         NVARCHAR( 20)  OUTPUT, ' +
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
                  ' @cUserDefine01 NVARCHAR( 30) OUTPUT, ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey,@cFacility,@cLoc,@cDropid,@cpickslipno, @cBarcode, 'SKU', --(yeekung05)
                  @cUPC           OUTPUT, @cSKU           OUTPUT, @cDefaultQTY       OUTPUT,
                  @cChkLottable01 OUTPUT, @cChkLottable02 OUTPUT, @cChkLottable03 OUTPUT, @dChkLottable04 OUTPUT, @dChkLottable05 OUTPUT,
                  @cChkLottable06 OUTPUT, @cChkLottable07 OUTPUT, @cChkLottable08 OUTPUT, @cChkLottable09 OUTPUT, @cChkLottable10 OUTPUT,
                  @cChkLottable11 OUTPUT, @cChkLottable12 OUTPUT, @dChkLottable13 OUTPUT, @dChkLottable14 OUTPUT, @dChkLottable15 OUTPUT,
                  @cUserDefine01  OUTPUT,
                  @nErrNo         OUTPUT, @cErrMsg        OUTPUT

               IF @nErrNo <> 0
                  GOTO SKU_Fail
            END
         END
      END

      DECLARE @nSKUCnt INT
      EXEC RDT.rdt_GetSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Check SKU valid
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 101966
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO SKU_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            SET @cDoctype = CASE WHEN ISNULL(@cLOC,'') <>'' THEN 'LOC' ELSE '' END

            SET @cOutField13 =''
            
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
               @cStorerKey,
               @cUPC     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT,
               'PickSlipNo',    -- DocType
               @cPickSlipNo,
               @cDoctype,
               @cLoc

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
            SET @nErrNo = 101967
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO SKU_Fail
         END
      END

      -- Get SKU
      EXEC rdt.rdt_GetSKU
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC      OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Validate SKU
      IF @cSKU <> @cUPC
      BEGIN
         SET @nErrNo = 101968
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SKU
         GOTO SKU_Fail
      END

      -- Validate lottables
      IF @cLottable01 <> '' AND @cChkLottable01 <> '' AND @cLottable01 <> @cChkLottable01 SET @nErrNo = 101969 ELSE
      IF @cLottable02 <> '' AND @cChkLottable02 <> '' AND @cLottable02 <> @cChkLottable02 SET @nErrNo = 101970 ELSE
      IF @cLottable03 <> '' AND @cChkLottable03 <> '' AND @cLottable03 <> @cChkLottable03 SET @nErrNo = 101971 ELSE
      IF (@dLottable04 <> 0 AND @dLottable04 IS NOT NULL) AND (@dChkLottable04 <> 0 AND @dChkLottable04 IS NOT NULL) AND @dLottable04 <> @dChkLottable04 SET @nErrNo = 101972 ELSE
      IF (@dLottable05 <> 0 AND @dLottable05 IS NOT NULL) AND (@dChkLottable05 <> 0 AND @dChkLottable05 IS NOT NULL) AND @dLottable05 <> @dChkLottable05 SET @nErrNo = 101973 ELSE
      IF @cLottable06 <> '' AND @cChkLottable06 <> '' AND @cLottable06 <> @cChkLottable06 SET @nErrNo = 101974 ELSE
      IF @cLottable07 <> '' AND @cChkLottable07 <> '' AND @cLottable07 <> @cChkLottable07 SET @nErrNo = 101975 ELSE
      IF @cLottable08 <> '' AND @cChkLottable08 <> '' AND @cLottable08 <> @cChkLottable08 SET @nErrNo = 101976 ELSE
      IF @cLottable09 <> '' AND @cChkLottable09 <> '' AND @cLottable09 <> @cChkLottable09 SET @nErrNo = 101977 ELSE
      IF @cLottable10 <> '' AND @cChkLottable10 <> '' AND @cLottable10 <> @cChkLottable10 SET @nErrNo = 101978 ELSE
      IF @cLottable11 <> '' AND @cChkLottable11 <> '' AND @cLottable11 <> @cChkLottable11 SET @nErrNo = 101979 ELSE
      IF @cLottable12 <> '' AND @cChkLottable12 <> '' AND @cLottable12 <> @cChkLottable12 SET @nErrNo = 101980 ELSE
      IF (@dLottable13 <> 0 AND @dLottable13 IS NOT NULL) AND (@dChkLottable13 <> 0 AND @dChkLottable13 IS NOT NULL) AND @dLottable13 <> @dChkLottable13 SET @nErrNo = 101981 ELSE
      IF (@dLottable14 <> 0 AND @dLottable14 IS NOT NULL) AND (@dChkLottable14 <> 0 AND @dChkLottable14 IS NOT NULL) AND @dLottable14 <> @dChkLottable14 SET @nErrNo = 101982 ELSE
      IF (@dLottable15 <> 0 AND @dLottable15 IS NOT NULL) AND (@dChkLottable15 <> 0 AND @dChkLottable15 IS NOT NULL) AND @dLottable15 <> @dChkLottable15 SET @nErrNo = 101983
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different L0X
         GOTO SKU_Fail
      END

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'VERIFY', 'POPULATE', 5, 1,
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

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nScn = @nScn_VerifyLottable
         SET @nStep = @nStep_VerifyLottable
      END
      ELSE
      BEGIN
         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nTaskQTY
            SET @cFieldAttr14 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nTaskQTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY = @nTaskQTY % @nPUOM_Div -- Calc the remaining in master unit
            SET @cFieldAttr14 = '' -- @nPQTY
         END

         -- Prepare QTY screen var
         SET @cOutField01 = @cPPK
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
         SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))
         SET @cOutField10 = @cPUOM_Desc
         SET @cOutField11 = @cMUOM_Desc
         SET @cOutField12 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
         SET @cOutField13 = CAST( @nMQTY AS NVARCHAR( 5))
         SET @cOutField14 = '' -- @nPQTY
         SET @cOutField15 = @cDefaultQTY -- @nMQTY

         -- Goto QTY screen
         SET @nScn = @nScn_QTY
         SET @nStep = @nStep_QTY
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cVerifyID = '1'
      BEGIN
         -- Prepare LOC screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cSuggID
         SET @cOutField03 = '' -- ID

         -- Go to prev screen
         SET @nScn = @nScn_VerifyID
         SET @nStep = @nStep_VerifyID
      END
      ELSE
      BEGIN
         -- Prepare LOC screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = CASE WHEN @cSuggestLOC = '1' THEN @cSuggLOC ELSE '' END
         SET @cOutField03 = '' -- LOC
         SET @cOutField04 = CASE WHEN @cClearID ='1' THEN '' ELSE @cDropID  END
         SET @cOUtField05 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC

         SET @cFieldAttr14 = '' -- @nPQTY

         -- Go to prev screen
         SET @nScn = @nScn_LOC
         SET @nStep = @nStep_LOC
      END
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
    '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cSuggLOC NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cDropID       NVARCHAR( 20), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cLottable01   NVARCHAR( 18), ' +
            '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nTaskQTY      INT,           ' +
            '@nQTY          INT,           ' +
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField20 = @cExtendedInfo
      END
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
    '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cSuggLOC NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cDropID       NVARCHAR( 20), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cLottable01   NVARCHAR( 18), ' +
            '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nTaskQTY      INT,           ' +
            '@nQTY          INT,           ' +
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField20 = @cExtendedInfo
      END
   END

   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      GOTO Step_99
   END
   GOTO Quit

   SKU_Fail:
   BEGIN
      SET @cOutField04 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Scn = 4693. QTY screen
   PPK       (field01)
   SKU       (field02)
   DESC1     (field03)
   DESC1     (field04)
   LOTTABLE  (field05)
   LOTTABLE  (field06)
   LOTTABLE  (field07)
   LOTTABLE  (field08)
   UOMRatio  (field09)
   PUOMDesc  (field10)
   MUOMDesc  (field11)
   PQTY      (field12)
   MQTY      (field13)
   PQTY      (field14, input)
   MQTY      (field15, input)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cPQTY NVARCHAR( 5)
      DECLARE @cMQTY NVARCHAR( 5)

      -- Screen mapping
      SET @cPQTY = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END
      SET @cMQTY = @cInField15

      -- Retain QTY keyed-in
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END -- PQTY
      SET @cOutField15 = @cInField15

      -- Check blank
      IF @cPQTY = '' AND @cMQTY = ''
      BEGIN
         SET @nErrNo = 101994
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY
         GOTO Quit
      END

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 101984
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY
         GOTO Quit
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 101985
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 15 -- MstQTY
         GOTO Quit
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Calc total QTY in master UOM
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- Validate over pick
      IF @nQTY > @nTaskQTY
      BEGIN
         SET @nErrNo = 101986
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pick
         GOTO Quit
      END

      -- (james02)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cPickSlipNo   NVARCHAR( 10), ' +
               '@cPickZone     NVARCHAR( 10), ' +
               '@cSuggLOC NVARCHAR( 10), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@nTaskQTY      INT,           ' +
               '@nQTY          INT,           ' +
               '@cToLOC        NVARCHAR( 10), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nTaskQTY, @nPQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Short pick
      IF @nQTY < @nTaskQTY
      BEGIN
         -- Go to screen 'Confirm Short Pick?'
         SET @nScn = @nScn_ShortPick
         SET @nStep = @nStep_ShortPick

         SET @cOutField01 = '' -- Option
       GOTO Quit
      END

      -- To LOC
      IF @cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1'
      BEGIN
         -- Go to TO LOC screen
         SET @nScn = @nScn_ToLOC
         SET @nStep = @nStep_ToLOC

         SET @cOutField01 = @cDefaultToLOC -- TO LOC
         GOTO Quit
      END

      -- Confirm task
      SET @cType = ''
      SET @cToLOC = ''
      EXEC rdt.rdt_PickSKU_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,
         @cPickSlipNo,@cPickZone, @cLOC, @cDropID, @cID, @cSKU, @nQTY, @cToLOC, @cLottableCode,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- FCR-759
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cUserDefine01, ' +
               ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cPickSlipNo   NVARCHAR( 10), ' +
               '@cPickZone     NVARCHAR( 10), ' +
               '@cSuggLOC NVARCHAR( 10), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@cUserDefine01 NVARCHAR( 30), ' +
               '@nTaskQTY      INT,           ' +
               '@nQTY          INT,           ' +
               '@cToLOC        NVARCHAR( 10), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cUserDefine01,
               @nTaskQTY, @nPQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Go to next screen
      EXEC rdt.rdt_PickSKU_GoToNextScreen @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cPUOM, @cPickSlipNo,@cPickZone, @cLOC, @cID, @cDropID,
         @cSuggLOC   OUTPUT,  @cSuggID     OUTPUT,  @cSKU        OUTPUT,   @nTaskQTY      OUTPUT,  @cLottableCode OUTPUT,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01   OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02   OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03   OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04   OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05   OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06   OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07   OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08   OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09   OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10   OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11   OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12   OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13   OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14   OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15   OUTPUT,
         @cSKUDescr  OUTPUT,  @cMUOM_Desc  OUTPUT,  @cPUOM_Desc   OUTPUT,  @nPUOM_Div     OUTPUT,
         @nStep      OUTPUT,  @nScn        OUTPUT,  @nErrNo       OUTPUT,  @cErrMsg       OUTPUT,
         @cPPK       OUTPUT
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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

      -- Go to SKU screen
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = '' --@cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField20 = '' -- ExtendedInfo

      -- Go to prev screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cSuggLOC NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cDropID       NVARCHAR( 20), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cLottable01   NVARCHAR( 18), ' +
            '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nTaskQTY      INT,           ' +
            '@nQTY          INT,           ' +
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_QTY, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField20 = @cExtendedInfo
      END
   END
END
GOTO Quit


/********************************************************************************
Scn = 4694. TO LOC screen
   TO LOC   (field01, input)
********************************************************************************/
Step_TOLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField01 -- LOC

      -- Validate compulsary field
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 101987
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToLOC
         GOTO Quit
      END

      -- Get the location
      SET @cChkFacility = ''
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate location
      IF @cChkFacility = ''
      BEGIN
         SET @nErrNo = 101988
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 101989
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check same FromLOC, ToLOC
      IF @cLOC = @cToLOC        BEGIN
         SET @nErrNo = 101995
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameFrom/ToLOC
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Confirm task
      EXEC rdt.rdt_PickSKU_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,
         @cPickSlipNo,@cPickZone, @cLOC, @cDropID, @cID, @cSKU, @nQTY, @cToLOC, @cLottableCode,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- FCR-759
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cUserDefine01, ' +
               ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cPickSlipNo   NVARCHAR( 10), ' +
               '@cPickZone     NVARCHAR( 10), ' +
               '@cSuggLOC NVARCHAR( 10), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@cUserDefine01 NVARCHAR( 30), ' +
               '@nTaskQTY      INT,           ' +
               '@nQTY          INT,           ' +
               '@cToLOC        NVARCHAR( 10), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cUserDefine01,
               @nTaskQTY, @nPQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Go to next screen
      EXEC rdt.rdt_PickSKU_GoToNextScreen @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cPUOM, @cPickSlipNo,@cPickZone, @cLOC, @cID, @cDropID,
         @cSuggLOC   OUTPUT,  @cSuggID     OUTPUT,  @cSKU        OUTPUT,   @nTaskQTY      OUTPUT,  @cLottableCode OUTPUT,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01   OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02   OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03   OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04   OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05   OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06   OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07   OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08   OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09   OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10   OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11   OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12   OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13   OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14   OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15   OUTPUT,
         @cSKUDescr  OUTPUT,  @cMUOM_Desc  OUTPUT,  @cPUOM_Desc   OUTPUT,  @nPUOM_Div     OUTPUT,
         @nStep      OUTPUT,  @nScn        OUTPUT,  @nErrNo       OUTPUT,  @cErrMsg       OUTPUT,
         @cPPK       OUTPUT
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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

      -- Prepare QTY screen var
      SET @cOutField01 = @cPPK
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))
      SET @cOutField10 = @cPUOM_Desc
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
      SET @cOutField13 = CAST( @nMQTY AS NVARCHAR( 5))
      SET @cOutField14 = '' -- @nPQTY
      SET @cOutField15 = '' -- @nMQTY

      -- Go to QTY screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Scn = 4695. Skip Current Task?
   OPTION   (field01, input)
********************************************************************************/
Step_SkipTask:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 101990
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required
         GOTO Quit
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 101991
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         -- Go to next screen
         EXEC rdt.rdt_PickSKU_GoToNextScreen @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cPUOM, @cPickSlipNo,@cPickZone, @cLOC, @cID, @cDropID,
            @cSuggLOC   OUTPUT,  @cSuggID     OUTPUT,  @cSKU         OUTPUT,  @nTaskQTY      OUTPUT,  @cLottableCode OUTPUT,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01   OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02   OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03   OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04   OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05   OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06   OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07   OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08   OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09   OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10   OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11   OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12   OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13   OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14   OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15   OUTPUT,
            @cSKUDescr  OUTPUT,  @cMUOM_Desc  OUTPUT,  @cPUOM_Desc   OUTPUT,  @nPUOM_Div     OUTPUT,
            @nStep      OUTPUT,  @nScn        OUTPUT,  @nErrNo       OUTPUT,  @cErrMsg       OUTPUT,
            @cPPK       OUTPUT

         GOTO Quit
      END
   END

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

   -- Prepare SKU screen var
   SET @cOutField01 = @cLOC
   SET @cOutField02 = @cDropID
   SET @cOutField03 = @cSKU
   SET @cOutField04 = '' --@cSKU
   SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1
   SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
   SET @cOutField20 = '' -- ExtendedInfo

   -- Goto SKU screen
   SET @nScn = @nScn_SKU
   SET @nStep = @nStep_SKU

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cSuggLOC NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cDropID       NVARCHAR( 20), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cLottable01   NVARCHAR( 18), ' +
            '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nTaskQTY      INT,           ' +
            '@nQTY          INT,           ' +
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_SkipTask, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField20 = @cExtendedInfo
      END
   END
END
GOTO Quit


/********************************************************************************
Scn = 4695. Confirm Short Pick?
   OPTION   (field01, input)
********************************************************************************/
Step_ShortPick:
BEGIN
   IF @nInputKey = 1 -- ENTER
BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 101992
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required
         GOTO Quit
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 101993
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cOption = '1'
         SET @cType = 'SHORT'
      ELSE
         SET @cType = ''

      -- To LOC
      IF @cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1'
      BEGIN
         -- Go to TO LOC screen
         SET @nScn = @nScn_ToLOC
         SET @nStep = @nStep_ToLOC

         SET @cOutField01 = @cDefaultToLOC -- TO LOC
         GOTO Quit
      END

      -- Confirm task
      SET @cToLOC = ''
      EXEC rdt.rdt_PickSKU_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,
         @cPickSlipNo,@cPickZone, @cLOC, @cDropID, @cID, @cSKU, @nQTY, @cToLOC, @cLottableCode,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- FCR-759
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cUserDefine01, ' +
               ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cPickSlipNo   NVARCHAR( 10), ' +
               '@cPickZone     NVARCHAR( 10), ' +
               '@cSuggLOC NVARCHAR( 10), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@cUserDefine01 NVARCHAR( 30), ' +
               '@nTaskQTY      INT,           ' +
               '@nQTY          INT,           ' +
               '@cToLOC        NVARCHAR( 10), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cUserDefine01,
               @nTaskQTY, @nPQTY, @cToLOC, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Go to next screen
      EXEC rdt.rdt_PickSKU_GoToNextScreen @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cPUOM, @cPickSlipNo,@cPickZone, @cLOC, @cID, @cDropID,
         @cSuggLOC   OUTPUT,  @cSuggID     OUTPUT,  @cSKU        OUTPUT,   @nTaskQTY      OUTPUT,  @cLottableCode OUTPUT,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01   OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02   OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03   OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04   OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05   OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06   OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07   OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08   OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09   OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10   OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11   OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12   OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13   OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14   OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15   OUTPUT,
         @cSKUDescr  OUTPUT,  @cMUOM_Desc  OUTPUT,  @cPUOM_Desc   OUTPUT,  @nPUOM_Div     OUTPUT,
         @nStep      OUTPUT,  @nScn        OUTPUT,  @nErrNo       OUTPUT,  @cErrMsg       OUTPUT,
         @cPPK       OUTPUT

      GOTO Quit
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare QTY screen var
      SET @cOutField01 = @cPPK
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))
      SET @cOutField10 = @cPUOM_Desc
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
      SET @cOutField13 = CAST( @nMQTY AS NVARCHAR( 5))
      SET @cOutField14 = '' -- @nPQTY
      SET @cOutField15 = '' -- @nMQTY

      -- Goto QTY screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END
END
GOTO Quit


/********************************************************************************
Scn = 3990. Dynamic lottables
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
Step_VerifyLottable:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'VERIFY', 'CHECK', 5, 1,
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

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 5,
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

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nTaskQTY
         SET @cFieldAttr14 = 'O' -- @nPQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nTaskQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY = @nTaskQTY % @nPUOM_Div -- Calc the remaining in master unit
         SET @cFieldAttr14 = '' -- @nPQTY
      END

      -- Prepare QTY screen var
      SET @cOutField01 = @cPPK
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))
      SET @cOutField10 = @cPUOM_Desc
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
      SET @cOutField13 = CAST( @nMQTY AS NVARCHAR( 5))
      SET @cOutField14 = '' -- @nPQTY
      SET @cOutField15 = '' -- @nMQTY

      -- Goto QTY screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'VERIFY', 'POPULATE', 5, 1,
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

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

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

      -- Prepare SKU screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = '' --@cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField20 = '' -- ExtendedInfo

      -- Goto SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cSuggLOC NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cDropID       NVARCHAR( 20), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cLottable01   NVARCHAR( 18), ' +
            '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nTaskQTY      INT,           ' +
            '@nQTY          INT,           ' +
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, Step_VerifyLottable, @nStep, @nInputKey, @cFacility, @cStorerKey,@cPickZone, @cPickSlipNo, @cSuggLOC, @cLOC, @cDropID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField20 = @cExtendedInfo
      END
   END
   GOTO Quit

   Step_5_Fail:

END
GOTO Quit


/********************************************************************************
Scn = 4697. Verify ID
   LOC      (field01)
   Sugg ID  (field02)
   ID       (field03, input)
********************************************************************************/
Step_VerifyID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField03
      SET @cBarcode = @cInField03
/*
      -- Validate blank
      IF @cID = ''
      BEGIN
         SET @nErrNo = 101996
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID required
         GOTO ID_Fail
      END
*/

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID     = @cID      OUTPUT,
               @nErrNo  = @nErrNo   OUTPUT,
               @cErrMsg = @cErrMsg  OUTPUT,
               @cType   = 'ID'
            IF @nErrNo <> 0
               GOTO ID_Fail
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,@cLoc,@cDropid,@cpickslipno,@cBarcode,@cFieldName, ' +
                  ' @cUPC         OUTPUT,@cSKu         OUTPUT,  @nQTY OUTPUT,' +
                  ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
                  ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
                  ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
                  ' @cUserDefine01 OUTPUT, ' +
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  ' @nMobile      INT,             ' +
                  ' @nFunc        INT,             ' +
                  ' @cLangCode    NVARCHAR( 3),    ' +
                  ' @nStep        INT,             ' +
                  ' @nInputKey    INT,             ' +
                  ' @cStorerKey   NVARCHAR( 15),   ' +
                  ' @cFacility    NVARCHAR( 20),   ' +
                  ' @cLOC         NVARCHAR( 10),   ' +
                  ' @cDropid      NVARCHAR( 20),   ' +
                  ' @cpickslipno  NVARCHAR( 20),   ' +
                  ' @cBarcode     NVARCHAR( 60),   ' +
                  ' @cFieldName   NVARCHAR( 10),   ' +
                  ' @cUPC         NVARCHAR( 20)  OUTPUT, ' +
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
                  ' @cUserDefine01 NVARCHAR( 30) OUTPUT, ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey,@cFacility,@cLoc,@cDropid,@cpickslipno, @cBarcode, 'ID',
                  @cID            OUTPUT, @cSKU           OUTPUT, @cDefaultQTY       OUTPUT,
                  @cChkLottable01 OUTPUT, @cChkLottable02 OUTPUT, @cChkLottable03 OUTPUT, @dChkLottable04 OUTPUT, @dChkLottable05 OUTPUT,
                  @cChkLottable06 OUTPUT, @cChkLottable07 OUTPUT, @cChkLottable08 OUTPUT, @cChkLottable09 OUTPUT, @cChkLottable10 OUTPUT,
                  @cChkLottable11 OUTPUT, @cChkLottable12 OUTPUT, @dChkLottable13 OUTPUT, @dChkLottable14 OUTPUT, @dChkLottable15 OUTPUT,
                  @cUserDefine01  OUTPUT,
                  @nErrNo         OUTPUT, @cErrMsg        OUTPUT

               IF @nErrNo <> 0
                  GOTO DropID_Fail
            END
         END

      END

      -- Extended info      
      IF @cSwapidSP <> ''      
      BEGIN      
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSwapidSP AND type = 'P')      
         BEGIN          
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapidSP) +       
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +      
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +      
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +      
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +      
               ' @nTaskQTY, @nQTY, @cToLOC, @cOption,@cSuggID,@cID, @nErrNo OUTPUT, @cErrMsg OUTPUT '      
            SET @cSQLParam =       
               '@nMobile       INT,           ' +      
               '@nFunc         INT,           ' +      
               '@cLangCode     NVARCHAR( 3),  ' +      
               '@nStep         INT,           ' +      
               '@nAfterStep    INT,           ' +      
               '@nInputKey     INT,           ' +      
               '@cFacility     NVARCHAR( 5),  ' +       
               '@cStorerKey    NVARCHAR( 15), ' +      
               '@cPickSlipNo   NVARCHAR( 10), ' +      
               '@cSuggLOC NVARCHAR( 10), ' +    
               '@cPickZone     NVARCHAR( 10), ' +      
               '@cLOC          NVARCHAR( 10), ' +      
               '@cDropID       NVARCHAR( 20), ' +      
               '@cSKU       NVARCHAR( 20), ' +      
               '@cLottable01   NVARCHAR( 18), ' +      
               '@cLottable02   NVARCHAR( 18), ' +      
               '@cLottable03   NVARCHAR( 18), ' +      
               '@dLottable04   DATETIME,      ' +      
               '@dLottable05   DATETIME,      ' +      
               '@cLottable06   NVARCHAR( 30), ' +      
               '@cLottable07   NVARCHAR( 30), ' +      
               '@cLottable08   NVARCHAR( 30), ' +      
               '@cLottable09   NVARCHAR( 30), ' +      
               '@cLottable10   NVARCHAR( 30), ' +      
               '@cLottable11   NVARCHAR( 30), ' +      
               '@cLottable12   NVARCHAR( 30), ' +      
               '@dLottable13   DATETIME,      ' +      
               '@dLottable14   DATETIME,      ' +      
               '@dLottable15   DATETIME,      ' +      
               '@nTaskQTY      INT,           ' +      
               '@nQTY          INT,           ' +      
               '@cToLOC        NVARCHAR( 10), ' +      
               '@cOption       NVARCHAR( 1),  ' + 
               '@cSuggID       NVARCHAR( 20),'  +   
               '@cID           NVARCHAR( 20), ' +      
               '@nErrNo        INT           OUTPUT, ' +      
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,       
               @nMobile, @nFunc, @cLangCode, @nStep_VerifyID, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,       
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,      
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,      
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,      
               @nTaskQTY, @nPQTY, @cToLOC, @cOption,@cSuggID, @cID, @nErrNo OUTPUT, @cErrMsg OUTPUT      
            IF @nErrNo <> 0      
               GOTO Quit      
      
            SET @cOutField20 = @cExtendedInfo      
         END      
      END 
      ELSE  
      BEGIN  
         -- Validate ID      
         IF @cID <> @cSuggID      
         BEGIN      
            SET @nErrNo = 101997      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ID      
            GOTO ID_Fail      
         END      
      END

      SELECT @cSKU = '', @nTaskQTY = 0,
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

      -- Get task
      EXEC rdt.rdt_PickSKU_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPUOM, 4, @cPickSlipNo,@cPickZone, @cLOC, @cID,
         @cSKU         OUTPUT, @nTaskQTY     OUTPUT,
         @cLottable01  OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT,
         @cLottable06  OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT,
         @cLottable11  OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT,
         @cLottableCode OUTPUT,
         @cSKUDescr    OUTPUT,
         @cMUOM_Desc   OUTPUT,
         @cPUOM_Desc   OUTPUT,
         @nPUOM_Div    OUTPUT,
         @nErrNo       OUTPUT,
         @cErrMsg      OUTPUT,
         @cPPK         OUTPUT
      IF @nErrNo <> 0
         GOTO ID_Fail

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

      -- Prepare SKU screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cSKU
      SET @cOutField04 = '' --@cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField20 = '' -- ExtendedInfo

      -- Goto SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = CASE WHEN @cSuggestLOC = '1' THEN @cSuggLOC ELSE '' END
      SET @cOutField03 = '' -- LOC
      SET @cOutField04 = CASE WHEN @cClearID ='1' THEN '' ELSE @cDropID  END

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC

      -- Go to prev screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cSuggLOC NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cDropID       NVARCHAR( 20), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cLottable01   NVARCHAR( 18), ' +
          '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nTaskQTY      INT,           ' +
            '@nQTY          INT,           ' +
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_VerifyID, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField20 = @cExtendedInfo
      END
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nTaskQTY, @nQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
    '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cPickSlipNo   NVARCHAR( 10), ' +
            '@cPickZone     NVARCHAR( 10), ' +
            '@cSuggLOC NVARCHAR( 10), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cDropID       NVARCHAR( 20), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@cLottable01   NVARCHAR( 18), ' +
            '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nTaskQTY      INT,           ' +
            '@nQTY          INT,           ' +
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo,@cPickZone, @cSuggLOC, @cLOC, @cDropID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nTaskQTY, @nPQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField20 = @cExtendedInfo
      END
   END

   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      GOTO Step_99
   END
   
   GOTO Quit

   ID_Fail:
   BEGIN
      SET @cOutField03 = '' -- ID
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
         @cStorerKey,
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
      SELECT @cSKUDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cUPC
   END

   -- Prepare SKU screen var
   SET @cOutField01 = @cLOC
   SET @cOutField02 = @cDropID
   SET @cOutField03 = @cSKU
   SET @cOutField04 = @cUPC
   SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1
   SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20) -- SKU desc 2
   SET @cOutField20 = '' -- ExtendedInfo

   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

   -- Go to next screen
   SET @nScn = @nScn_SKU
   SET @nStep = @nStep_SKU

END
GOTO Quit

Step_99:
BEGIN
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN      

         EXECUTE [RDT].[rdt_ExtScnEntry] 
         @cExtendedScreenSP, 
         @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT, 
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT, 
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT, 
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT, 
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT, 
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nAction, 
         @nScn     OUTPUT,  @nStep OUTPUT,
         @nErrNo   OUTPUT, 
         @cErrMsg  OUTPUT,
         @cUDF01   OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
         @cUDF04   OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
         @cUDF07   OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
         @cUDF10   OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
         @cUDF13   OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
         @cUDF16   OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
         @cUDF19   OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
         @cUDF22   OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
         @cUDF25   OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
         @cUDF28   OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @nErrNo <> 0
            GOTO Step_99_Fail
      END
   END

   GOTO Quit

Step_99_Fail:
   BEGIN
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      UserName     = @cUserName,

      V_Integer1 = @nPUOM_Div,
      V_Integer2 = @nPQTY,
      V_Integer3 = @nMQTY,
      V_Integer4 = @nQTY,

      V_PickSlipNo = @cPickSlipNo,
      V_LOC        = @cLOC,
      V_ID         = @cID,
      V_CaseID     = @cDropID,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKUDescr,
      V_UOM        = @cPUOM,
      V_QTY        = @nTaskQTY,
      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_Lottable05 = @dLottable05,
      V_Lottable06 = @cLottable06,
      V_Lottable07 = @cLottable07,
      V_Lottable08 = @cLottable08,
      V_Lottable09 = @cLottable09,
      V_Lottable10 = @cLottable10,
      V_Lottable11 = @cLottable11,
      V_Lottable12 = @cLottable12,
      V_Lottable13 = @dLottable13,
      V_Lottable14 = @dLottable14,
      V_Lottable15 = @dLottable15,

      V_String1    = @cSuggLOC,
      V_String2    = @cMultiSKUBarcode,
      V_String3    = @cLottableCode,
      V_String4    = @cPPK,
      V_String5    = @cToLOC,
      V_String6    = @cType,
      V_String7    = @cSuggID,

      V_String10   = @cMUOM_Desc,
      V_String11   = @cPUOM_Desc,
      V_String12   = @nPUOM_Div ,
      V_String13   = @nPQTY,
      V_String14   = @nMQTY,
      V_String15   = @nQTY,

      V_String20  = @cDefaultQTY,
      V_String21  = @cExtendedValidateSP,
      V_String22  = @cExtendedUpdateSP,
      V_String23  = @cExtendedInfoSP,
      V_String24  = @cExtendedInfo,
      V_String25  = @cSuggestLOC,
      V_String26  = @cOverrideLOC,
      V_String27  = @cDecodeSP,
      V_String28  = @cMoveQTYAlloc,
      V_String29  = @cMoveQTYPick,
      V_String30  = @cSkipLOC,
      V_String31  = @cDefaultToLOC,
      V_String32  = @cVerifyID,
      V_String33  = @cAutoScanIn,
      V_String34  = @cClearID,
      V_String35  = @cPickZone ,
      V_String36  = @cVerifyPickZone,
      V_string37  = @cOrderKey,
      V_string38  = @cLoadKey,
      V_string39  = @cZone,
      V_string40  = @cSwapidSP,   
      V_String41  = @cExtendedScreenSP,
      V_String42  = @cUserDefine01,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15,
      I_Field16 = @cInField16,  O_Field16 = @cOutField16,   FieldAttr16  = @cFieldAttr16,
      I_Field17 = @cInField17,  O_Field17 = @cOutField17,   FieldAttr17  = @cFieldAttr17,
      I_Field18 = @cInField18,  O_Field18 = @cOutField18,   FieldAttr18  = @cFieldAttr18,
      I_Field19 = @cInField19,  O_Field19 = @cOutField19,   FieldAttr19  = @cFieldAttr19,
      I_Field20 = @cInField20,  O_Field20 = @cOutField20,   FieldAttr20  = @cFieldAttr20

   WHERE Mobile = @nMobile
END

GO