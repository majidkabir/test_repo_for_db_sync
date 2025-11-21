SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdtfnc_PostPickAudit_Lottable                             */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2018-03-28   1.0  Ung        WMS-4238 Migrate from FN904                   */
/* 2018-08-15   1.1  James      WMS-5944 Use UOM from custom sp (james01)     */
/* 2018-10-16   1.2  TungGH     Performance                                   */
/* 2019-07-08   1.3  James      WMS9387-Add MultiSKUBarcode screen (james02)  */
/* 2019-11-28   1.4  Chermaine  WMS-11218 show total and                      */
/*                              counted quantity per sku (cc01)               */
/* 2023-06-09   1.5  YeeKung    WMS-22746 Add eventlog (yeekung01)            */
/* 2023-08-30   1.6  Ung        WMS-23087 Fix ExtVal for lottable runtime err */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PostPickAudit_Lottable] (
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
   @b_success      INT,
   @cErrMsg1       NVARCHAR( 20),
   @nTranCount     INT,
   @nRowRef        INT,
   @nMorePage      INT,
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX),
   @tVar           VariableTable

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
   @cLoadKey       NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cDropID        NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @cDescr         NVARCHAR( 60),
   @cPUOM          NVARCHAR( 1),
   @nQTY           INT,

   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,

   @cRefNo         NVARCHAR( 10),
   @cSourceKey     NVARCHAR( 15),
   @cType          NVARCHAR( 10),

   @cPUOM_Desc     NVARCHAR( 5),
   @cMUOM_Desc     NVARCHAR( 5),
   @nPUOM_Div      INT,
   @cQTY_PPA       NVARCHAR( 10),
   @cQTY_CHK       NVARCHAR( 10),
   @cCHK_SKU       NVARCHAR( 10),
   @cCHK_QTY       NVARCHAR( 10),
   @cPPA_SKU       NVARCHAR( 10),
   @cPPA_QTY       NVARCHAR( 10),

   @cExtendedValidateSP              NVARCHAR( 20),
   @cExtendedUpdateSP                NVARCHAR( 20),
   @cExtendedInfoSP                  NVARCHAR( 20),
   @cExtendedInfo                    NVARCHAR( 20),
   @cDecodeSP                        NVARCHAR( 20),
   @cDefaultCursor                   NVARCHAR( 1),
   @cDefaultQTY                      NVARCHAR( 1),
   @cPPACartonIDByPickDetailCaseID   NVARCHAR( 1),
   @cSkipChkPSlipMustScanOut         NVARCHAR( 1),
   @cAllowSKUNotInPickList           NVARCHAR( 1),
   @cAllowLottableNotInPickList      NVARCHAR( 1),
   @cAllowExcessQTY                  NVARCHAR( 1),

   @cLottableCode  NVARCHAR( 30),
   @cExtendedUOMSP NVARCHAR( 20),
   @nExtPUOM_Div   INT,
   @cMultiSKUBarcode    NVARCHAR(1),
   @nFromScn       INT,
   @nFromStep      INT,

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

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
   @cLoadKey         = V_Loadkey,
   @cOrderKey        = V_OrderKey,
   @cDropID          = V_CaseID,
   @cSKU             = V_SKU,
   @cDescr           = V_SKUDescr,
   @cPUOM            = V_UOM,
   @nQTY             = V_QTY,
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

   @cRefNo           = V_String1,
   @cSourceKey       = V_String2,
   @cType            = V_String3,
   @cMultiSKUBarcode = V_String4,

   @nExtPUOM_Div     = V_Integer1,
   @nFromScn         = V_FromScn,
   @nFromStep        = V_FromStep,

   @cPUOM_Desc       = V_String11,
   @cMUOM_Desc       = V_String12,
   @cQTY_PPA         = V_String14,
   @cQTY_CHK         = V_String15,
   @cCHK_SKU         = V_String16,
   @cCHK_QTY         = V_String17,
   @cPPA_SKU         = V_String18,
   @cPPA_QTY         = V_String19,

   @nPUOM_Div        = V_PUOM_Div,

   @cExtendedValidateSP = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedInfoSP     = V_String23,
   @cExtendedInfo       = V_String24,
   @cDecodeSP           = V_String25,
   @cDefaultCursor      = V_String26,
   @cDefaultQTY         = V_String27,
   @cPPACartonIDByPickDetailCaseID = V_String28,
   @cSkipChkPSlipMustScanOut       = V_String29,
   @cAllowSKUNotInPickList         = V_String30,
   @cAllowLottableNotInPickList    = V_String31,
   @cAllowExcessQTY                = V_String32,
   @cExtendedUOMSP      = V_String33,

   @cLottableCode       = V_String41,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,   @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,   @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,   @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,   @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,   @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,   @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,   @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,   @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,   @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,   @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,   @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,   @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,   @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,   @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,   @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_Criteria      INT,  @nScn_Criteria       INT,
   @nStep_SKU           INT,  @nScn_SKU            INT,
   @nStep_Lottable      INT,  @nScn_Lottable       INT,
   @nStep_QTY           INT,  @nScn_QTY            INT,
   @nStep_Statistic     INT,  @nScn_Statistic      INT,
   @nStep_MultiSKUBar   INT,  @nScn_MultiSKUBar    INT

SELECT
   @nStep_Criteria      = 1,  @nScn_Criteria       = 5130,
   @nStep_SKU           = 2,  @nScn_SKU            = 5131,
   @nStep_Lottable      = 3,  @nScn_Lottable       = 3990,
   @nStep_QTY           = 4,  @nScn_QTY            = 5132,
   @nStep_Statistic     = 5,  @nScn_Statistic      = 5133,
   @nStep_MultiSKUBar   = 6,  @nScn_MultiSKUBar    = 3570

IF @nFunc = 903
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 903
   IF @nStep = 1  GOTO Step_Criteria    -- Scn = 2610. Criteria
   IF @nStep = 2  GOTO Step_SKU         -- Scn = 2611. SKU
   IF @nStep = 3  GOTO Step_Lottables   -- Scn = 3990. Lottables
   IF @nStep = 4  GOTO Step_QTY         -- Scn = 2613. QTY
   IF @nStep = 5  GOTO Step_Statistic   -- Scn = 2615. Statistic
   IF @nStep = 6 GOTO  Step_MultiSKUBar -- Scn = 3570. Multi SKU Barcode
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 903
********************************************************************************/
Step_Start:
BEGIN
   -- Get preferred UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   -- Storer configure
   SET @cAllowExcessQTY = rdt.rdtGetConfig( @nFunc, 'AllowExcessQTY', @cStorerKey)
   SET @cAllowLottableNotInPickList = rdt.rdtGetConfig( @nFunc, 'AllowLottableNotInPickList', @cStorerKey)
   SET @cAllowSKUNotInPickList = rdt.rdtGetConfig( @nFunc, 'AllowSKUNotInPickList', @cStorerKey)
   SET @cDefaultCursor = rdt.RDTGetConfig( @nFunc, 'DefaultCursor', @cStorerKey)
   SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey)
   SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorerKey)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
   IF @cDefaultQTY = '0'
      SET @cDefaultQTY = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cExtendedUOMSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUOMSP', @cStorerKey)
   IF @cExtendedUOMSP = '0'
      SET @cExtendedUOMSP = ''

   -- (james02)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Init var
   SET @cQTY_PPA = ''
   SET @cQTY_CHK = ''
   SET @cCHK_SKU = ''
   SET @cCHK_QTY = ''
   SET @cPPA_SKU = ''
   SET @cPPA_QTY = ''

   -- Prepare PickSlipNo screen var
   SET @cOutField01 = '' -- RefNo
   SET @cOutField02 = '' -- PickSlipNo
   SET @cOutField03 = '' -- LoadKey
   SET @cOutField04 = '' -- OrderKey
   SET @cOutField05 = '' -- DropID

   -- Default cursor
   IF @cDefaultCursor IN ('1', '2', '3', '4', '5')
      EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor

   -- Go to PickSlipNo screen
   SET @nScn = @nScn_Criteria
   SET @nStep = @nStep_Criteria
END
GOTO Quit


/************************************************************************************
Scn = 2610. Criteria screen
   REFNO     (field01, input)
   PSNO      (field02, input)
   LOADKEY   (field03, input)
   ORDERKEY  (field04, input)
   CARTONID  (field05, input)
************************************************************************************/
Step_Criteria:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cRefNo = @cInField01
      SET @cPickSlipNo = @cInField02
      SET @cLoadKey = @cInField03
      SET @cOrderkey = @cInField04
      SET @cDropID = @cInField05

      -- Check all blank
      IF @cRefNo = '' AND @cPickSlipNo = '' AND @cLoadKey = '' AND @cOrderkey = '' AND @cDropID = ''
      BEGIN
         SET @nErrNo = 121951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Value Required
         GOTO Criteria_Fail
      END

      -- Check more then 1 criteria
      DECLARE @i INT
      SET @i = 0
      IF @cRefNo      <> '' SET @i = @i + 1
      IF @cPickSlipNo <> '' SET @i = @i + 1
      IF @cLoadKey    <> '' SET @i = @i + 1
      IF @cOrderKey   <> '' SET @i = @i + 1
      IF @cDropID     <> '' SET @i = @i + 1
      IF @i > 1
      BEGIN
         SET @nErrNo = 121952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Key-in either 1
         GOTO Criteria_Fail
      END

      -- Ref No
      IF @cRefNo <> ''
      BEGIN
         -- Validate load plan status
         IF NOT EXISTS( SELECT 1
            FROM dbo.LoadPlan WITH (NOLOCK)
            WHERE UserDefine10 = @cRefNo
               AND Status <= '9') -- 9=Closed
         BEGIN
            SET @nErrNo = 121953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Ref#
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Criteria_Fail
         END

         -- Validate all pickslip already scan in
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.UserDefine10 = @cRefNo
               AND [PI].ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 121954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not Scan-in
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Criteria_Fail
         END

         -- Validate all pickslip already scan out
         IF @cSkipChkPSlipMustScanOut <> '1'
         BEGIN
            IF EXISTS( SELECT 1
               FROM dbo.LoadPlan LP WITH (NOLOCK)
                  INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
                  LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
               WHERE LP.UserDefine10 = @cRefNo
                  AND [PI].ScanOutDate IS NULL)
            BEGIN
               SET @nErrNo = 121955
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not Scan-out
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Criteria_Fail
            END
         END

         SET @cSourceKey = @cRefNo
      END

      -- Pick Slip No
      IF @cPickSlipNo <> ''
      BEGIN
         -- Get pickheader info
         DECLARE @cChkPickSlipNo NVARCHAR(10)
         SELECT
            @cChkPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         -- Validate pickslip no
         IF @cChkPickSlipNo = '' OR @cChkPickSlipNo IS NULL
         BEGIN
            SET @nErrNo = 121956
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid PS#
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Criteria_Fail
         END

         -- Get picking info
         DECLARE @dScanInDate DATETIME
         DECLARE @dScanOutDate DATETIME
         SELECT TOP 1
            @dScanInDate = ScanInDate,
            @dScanOutDate = ScanOutDate
         FROM dbo.PickingInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         -- Validate pickslip not scan in
         IF @dScanInDate IS NULL
         BEGIN
            SET @nErrNo = 121957
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not scan-in
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Criteria_Fail
         END

         -- Validate pickslip not scan out
         IF @cSkipChkPSlipMustScanOut <> '1'
         BEGIN
            IF @dScanOutDate IS NULL
            BEGIN
               SET @nErrNo = 121958
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not scan-out
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Criteria_Fail
            END
         END

         SET @cSourceKey = @cPickSlipNo
      END

      -- LoadKey
      IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL
      BEGIN
         -- Validate load plan status
         IF NOT EXISTS( SELECT 1
            FROM dbo.LoadPlan WITH (NOLOCK)
            WHERE LoadKey = @cLoadKey
               AND Status <= '9') -- 9=Closed
         BEGIN
            SET @nErrNo = 121959
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Criteria_Fail
         END

         -- Validate all pickslip already scan in
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.LoadKey = @cLoadKey
               AND [PI].ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 121960
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not Scan-in
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Criteria_Fail
         END

         -- Validate all pickslip already scan out
         IF EXISTS( SELECT 1
            FROM dbo.LoadPlan LP WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE LP.LoadKey = @cLoadKey
               AND [PI].ScanOutDate IS NULL)
         BEGIN
            SET @nErrNo = 121961
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not Scan-out
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Criteria_Fail
         END

         SET @cSourceKey = @cLoadKey
      END

      -- OrderKey
      IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
      BEGIN
         -- Validate order status
         IF NOT EXISTS( SELECT 1
            FROM dbo.Orders WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
               AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 121962
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv OrderKey
            GOTO Criteria_Fail
         END

         -- Validate pickslip already scan in
         IF EXISTS( SELECT 1
            FROM dbo.PickHeader PH WITH (NOLOCK)
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE PH.OrderKey = @cOrderKey
               AND [PI].ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 121963
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not Scan-in
            GOTO Criteria_Fail
         END

         -- (james05)
         IF @cSkipChkPSlipMustScanOut <> '1'
         BEGIN
            -- Validate pickslip already scan out
            IF EXISTS( SELECT 1
               FROM dbo.PickHeader PH WITH (NOLOCK)
                  LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
               WHERE PH.OrderKey = @cOrderKey
                  AND [PI].ScanOutDate IS NULL)
            BEGIN
               SET @nErrNo = 121964
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not Scan-out
               GOTO Criteria_Fail
            END
         END
      END

      -- DropID
      IF @cDropID <> ''
      BEGIN
         -- Validate drop ID status
         IF @cPPACartonIDByPickDetailCaseID = '1'
         BEGIN
            IF NOT EXISTS( SELECT 1
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE CaseID = @cDropID
                  AND StorerKey = @cStorerKey
                  AND ShipFlag <> 'Y')
            BEGIN
               SET @nErrNo = 121965
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv CaseID
               GOTO Criteria_Fail
            END
         END
         ELSE
         BEGIN
            IF NOT EXISTS( SELECT 1
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE DropID = @cDropID
                  AND StorerKey = @cStorerKey
                  AND ShipFlag <> 'Y')
            BEGIN
               SET @nErrNo = 121966
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Inv DropID
               GOTO Criteria_Fail
            END
         END

         SET @cSourceKey = @cDropID
      END

      -- Prepare SKU screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderkey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = ''

      -- Go to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Criteria_Fail:
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
      DECLARE @cBarcode NVARCHAR( 60)
      DECLARE @cUPC     NVARCHAR( 30)

      -- Screen mapping
      SET @cBarcode = @cInField06
      SET @cUPC = LEFT( @cInField06, 30)

      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 121967
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
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
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
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
               @nErrNo        = @nErrNo        OUTPUT,
               @cErrMsg       = @cErrMsg       OUTPUT
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
               ' @cRefno         OUTPUT, @cPickSlipNo    OUTPUT, @cLoadKey       OUTPUT, @cOrderKey      OUTPUT, @cDropID        OUTPUT, ' +
               ' @cUPC           OUTPUT, @nQTY           OUTPUT, ' +
               ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
               ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
               ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cBarcode       NVARCHAR( 60), ' +
               ' @cRefno         NVARCHAR( 10)  OUTPUT, ' +
               ' @cPickSlipNo    NVARCHAR( 10)  OUTPUT, ' +
               ' @cLoadKey       NVARCHAR( 10)  OUTPUT, ' +
               ' @cOrderKey      NVARCHAR( 10)  OUTPUT, ' +
               ' @cDropID        NVARCHAR( 20)  OUTPUT, ' +
               ' @cUPC           NVARCHAR( 20)  OUTPUT, ' +
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
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode,
               @cRefno        OUTPUT, @cPickSlipNo    OUTPUT, @cLoadKey       OUTPUT, @cOrderKey      OUTPUT, @cDropID        OUTPUT,
               @cUPC          OUTPUT, @nQTY           OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT
         END
      END

      DECLARE @nSKUCnt INT
      EXEC [RDT].[rdt_GETSKUCNT]
         @cStorerKey  = @cStorerKey
        ,@cSKU        = @cUPC
        ,@nSKUCnt     = @nSKUCnt       OUTPUT
        ,@bSuccess    = @b_Success     OUTPUT
        ,@nErr        = @nErrNo        OUTPUT
        ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU valid
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 121968
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO SKU_Fail
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
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
               'POPULATE',
               @cMultiSKUBarcode,
               @cStorerKey,
               @cUPC         OUTPUT,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT,
               '',    -- DocType
               ''

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nFromScn = @nScn
               SET @nFromStep = @nStep
               SET @nScn = 3570
               SET @nStep = @nStep_MultiSKUBar
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 121969
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarcod
            GOTO SKU_Fail
         END
      END

      -- Get SKU
      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cUPC          OUTPUT,
         @bSuccess    = @b_success     OUTPUT,
         @nErr        = @nErrNo        OUTPUT,
         @cErrMsg     = @cErrMsg       OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 121970
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO SKU_Fail
      END
      SET @cSKU = @cUPC

      -- Get SKU info
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
            END, 1) AS INT),
         @cLottableCode = LottableCode
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      SET @nExtPUOM_Div = 0
      
      -- Extended UOM (james01)
      IF @cExtendedUOMSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUOMSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUOMSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, ' +
               ' @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @nRowRef, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cPUOM, @nExtPUOM_Div OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile         INT,           ' +
               ' @nFunc           INT,           ' +
               ' @cLangCode       NVARCHAR( 3),  ' +
               ' @nStep           INT,           ' +
               ' @nInputKey       INT,           ' +
               ' @cFacility       NVARCHAR( 5),  ' +
               ' @cStorerKey      NVARCHAR( 15), ' +
               ' @cType           NVARCHAR( 10), ' +
               ' @cRefNo          NVARCHAR( 10), ' +
               ' @cPickSlipNo     NVARCHAR( 10), ' +
               ' @cLoadKey        NVARCHAR( 10), ' +
               ' @cOrderKey       NVARCHAR( 10), ' +
               ' @cDropID         NVARCHAR( 20), ' +
               ' @cSKU            NVARCHAR( 20), ' +
               ' @nQTY            INT,           ' +
               ' @nRowRef         INT,           ' +
               ' @cLottable01     NVARCHAR( 18), ' +
               ' @cLottable02     NVARCHAR( 18), ' +
               ' @cLottable03     NVARCHAR( 18), ' +
               ' @dLottable04     DATETIME,      ' +
               ' @dLottable05     DATETIME,      ' +
               ' @cLottable06     NVARCHAR( 30), ' +
               ' @cLottable07     NVARCHAR( 30), ' +
               ' @cLottable08     NVARCHAR( 30), ' +
               ' @cLottable09     NVARCHAR( 30), ' +
               ' @cLottable10     NVARCHAR( 30), ' +
               ' @cLottable11     NVARCHAR( 30), ' +
               ' @cLottable12     NVARCHAR( 30), ' +
               ' @dLottable13     DATETIME,      ' +
               ' @dLottable14     DATETIME,      ' +
               ' @dLottable15     DATETIME,      ' +
               ' @cPUOM           NVARCHAR( 1),  ' +
               ' @nExtPUOM_Div    INT          OUTPUT, ' +
               ' @nErrNo          INT          OUTPUT, ' +
               ' @cErrMsg         NVARCHAR(20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,
               @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @nRowRef,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cPUOM, @nExtPUOM_Div OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO SKU_Fail
         END
      END

      SELECT @cType = 'SKU', @nQTY = 0, @nRowRef = 0, @cQTY_PPA = '0', @cQTY_CHK = '0',
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',   @dLottable04 = NULL, @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',   @cLottable09 = '',   @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL, @dLottable14 = NULL, @dLottable15 = NULL

      -- Check SKU not in pick list
      IF @cAllowSKUNotInPickList <> '1'
      BEGIN
         -- Get PPA
         EXECUTE rdt.rdt_PostPickAudit_Lottable_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHECK', @cType,
            @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cDescr, @nQTY, @cLottableCode,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nRowRef    OUTPUT,
            @cQTY_PPA   OUTPUT,
            @cQTY_CHK   OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO SKU_Fail

         IF @nRowRef = 0 AND @cQTY_PPA = '0'
         BEGIN
            SET @nErrNo = 121971
            SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU NOT IN LIST
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '121971', @cErrMsg1

            GOTO SKU_Fail
         END
      END

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
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
         SET @nScn = @nScn_Lottable
         SET @nStep = @nStep_Lottable
         GOTO Quit
      END

      -- Insert PPA
      EXECUTE rdt.rdt_PostPickAudit_Lottable_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'INSERT', @cType,
         @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cDescr, @nQTY, @cLottableCode,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @nRowRef    OUTPUT,
         @cQTY_PPA   OUTPUT,
         @cQTY_CHK   OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO SKU_Fail

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @cFieldAttr11 = 'O'
      END

       -- Prepare QTY screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cDescr, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cDescr, 21, 20) -- SKU desc 2
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''

      IF ISNULL( @nExtPUOM_Div, 0) > 0
         SET @cOutField08 = '1:' + CAST( @nExtPUOM_Div AS NVARCHAR( 6))
      ELSE
         SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))

      SET @cOutField09 = @cPUOM_Desc
      SET @cOutField10 = @cMUOM_Desc
      SET @cOutField11 = '' -- PQTY
      SET @cOutField12 = '' -- MQTY

      -- Default QTY
      IF @cDefaultQTY <> ''
      BEGIN
         IF @cFieldAttr11 = 'O'
            SET @cOutField12 = @cDefaultQTY -- MQTY
         ELSE
            SET @cOutField11 = @cDefaultQTY -- PQTY
      END

      IF @cOutField11 <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- PQTY

      -- Goto QTY screen
      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      DECLARE @cSKUStat NVARCHAR( 20)
      DECLARE @cQTYStat NVARCHAR( 20)

      SET @cCHK_SKU = '0'
      SET @cCHK_QTY = '0'
      SET @cPPA_SKU = '0'
      SET @cPPA_QTY = '0'

      -- Get statistic
      EXECUTE rdt.rdt_PostPickAudit_Lottable_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID,
         @nCSKU = @cCHK_SKU OUTPUT,
         @nCQTY = @cCHK_QTY OUTPUT,
         @nPSKU = @cPPA_SKU OUTPUT,
         @nPQTY = @cPPA_QTY OUTPUT

      -- Format statistic
      SET @cSKUStat = @cCHK_SKU + '/' + @cPPA_SKU
      SET @cQTYStat = @cCHK_QTY + '/' + @cPPA_QTY

      -- Get status
      DECLARE @cPickStatus NVARCHAR(20)
      IF @cPPA_SKU = @cCHK_SKU AND
         @cPPA_QTY = @cCHK_QTY
      BEGIN
         SET @nErrNo = 121972
         SET @cPickStatus = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- COMPLETED
      END
      ELSE
      BEGIN
         SET @nErrNo = 121973
         SET @cPickStatus = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NOT COMPLETE
      END

      -- Prepare statistic screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderkey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKUStat
      SET @cOutField07 = @cQTYStat
      SET @cOutField08 = @cPickStatus

      -- Go to prev screen
      SET @nScn = @nScn_Statistic
      SET @nStep = @nStep_Statistic
   END
   GOTO Quit

   SKU_Fail:
      SET @cOutField06 = '' -- SKU

END
GOTO Quit


/********************************************************************************
Scn = 3490. Dynamic lottables
   Label      (field01)
   Lottable   (field02, input)
   Label      (field03)
   Lottable   (field04, input)
   Label      (field05)
   Lottable   (field06, input)
   Label      (field07)
   Lottable   (field08, input)
   Label      (field09)
   Lottable   (field10, input)
********************************************************************************/
Step_Lottables:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cOutField15Backup NVARCHAR( 60) = @cOutField15
      
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'CHECK', 5, 1,
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

      SET @cType = 'LOTTABLE'

      -- Check lottable not in pick list
      IF @cAllowLottableNotInPickList <> '1' --Not allow
      BEGIN
         -- Get PPA
         SET @nRowRef = 0
         SET @cQTY_PPA = '0'
         EXECUTE rdt.rdt_PostPickAudit_Lottable_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHECK', @cType,
            @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cDescr, @nQTY, @cLottableCode,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nRowRef    OUTPUT,
            @cQTY_PPA   OUTPUT,
            @cQTY_CHK   OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         IF @nRowRef = 0 AND @cQTY_PPA = '0'
         BEGIN
            SET @nErrNo = 121974
            SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOTTABLE NOT IN LIST
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '121974', @cErrMsg1

            GOTO Step_Lottables_Fail
         END
      END

      -- Insert PPA
      EXECUTE rdt.rdt_PostPickAudit_Lottable_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'INSERT', @cType,
         @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cDescr, @nQTY, @cLottableCode,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @nRowRef    OUTPUT,
         @cQTY_PPA   OUTPUT,
         @cQTY_CHK   OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Step_Lottables_Fail

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 4,
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
         SET @cFieldAttr11 = 'O'
      END

      --Extended info: show total and counted quantity (cc01)
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            --SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 10), ' +
               '@cPickSlipNo  NVARCHAR( 10), ' +
               '@cLoadKey     NVARCHAR( 10), ' +
               '@cOrderKey    NVARCHAR( 10), ' +
               '@cDropID      NVARCHAR( 20), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cExtendedInfo OUTPUT
         END
      END

      -- Prepare QTY screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cDescr, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cDescr, 21, 20) -- SKU desc 2
      -- SET @cOutField04 = @cLottable01
      -- SET @cOutField05 = @cLottable02
      -- SET @cOutField06 = @cLottable03
      -- SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)
      IF ISNULL( @nExtPUOM_Div, 0) > 0
         SET @cOutField08 = '1:' + CAST( @nExtPUOM_Div AS NVARCHAR( 6))
      ELSE
         SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))

      SET @cOutField09 = @cPUOM_Desc
      SET @cOutField10 = @cMUOM_Desc
      SET @cOutField11 = '' -- PQTY
      SET @cOutField12 = '' -- MQTY
      SET @cOutField13 = CASE WHEN @cExtendedInfo = '' THEN '' ELSE @cExtendedInfo END

      IF @cDefaultQTY <> ''
      BEGIN
         IF @cFieldAttr11 = 'O'
            SET @cOutField12 = @cDefaultQTY
         ELSE
            SET @cOutField11 = @cDefaultQTY
      END

      IF @cOutField11 <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 11
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 12

      -- Goto QTY screen
      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
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
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderkey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = ''

      -- Go back to prev screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
   GOTO Quit
   
Step_Lottables_Fail:
   -- After captured lottable, screen exit and the hidden field (O_Field15) is clear. 
   -- If any error occur, need to simulate as if still staying in lottable screen, by restoring this hidden field
   SET @cOutField15 = @cOutField15Backup
END
GOTO Quit


/********************************************************************************
Scn = 2613. QTY screen
  SKU       (Field01)
  DESCR1    (Field02)
  DESCR2    (Field03)
  LOTTABLES:
  Lottable  (Field04)
  Lottable  (Field05)
  Lottable  (Field06)
  Lottable  (Field07)
  DIV       (Field08)
  PUOM DESC (Field09)
  MUOM DESC (Field10)
  PQTY      (Field11, input)
  MQTY      (Field12, input)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cMQTY NVARCHAR(5), @nMQTY INT
      DECLARE @cPQTY NVARCHAR(5), @nPQTY INT

      -- Screen mapping
      SET @cPQTY = CASE WHEN @cFieldAttr11 = 'O' THEN @cOutField11 ELSE @cInField11 END
      SET @cMQTY = @cInField12

      -- Validate QTY blank
      IF @cPQTY = '' AND @cMQTY = ''
      BEGIN
         SET @nErrNo = 121975
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY required
         GOTO Quit
      END

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 121976
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- PQTY
         GOTO Quit
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 121977
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- MQTY
         GOTO Quit
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Calc total QTY in master UOM
      IF ISNULL( @nExtPUOM_Div, 0) > 0
         SET @nQTY = @nExtPUOM_Div * @cPQTY
      ELSE
         SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM

      SET @nQTY = @nQTY + @nMQTY

      -- Multiply QTY if have prepack indicator
      -- IF (@cPrePackIndicator = '2') AND (RDT.rdtIsValidQTY( @cPackQTYIndicator , 1) = 1)
      --    SET @nQTY = @nQTY * CAST( @cPackQTYIndicator AS INT)

      -- Validate QTY
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 121978
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         GOTO Quit
      END

      -- Check excess QTY
      IF @cAllowExcessQTY <> '1'
      BEGIN
         -- Get PPA
         SET @nRowRef = 0
         SET @cQTY_PPA = '0'
         SET @cQTY_CHK = '0'
         EXECUTE rdt.rdt_PostPickAudit_Lottable_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHECK', @cType,
            @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cDescr, @nQTY, @cLottableCode,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nRowRef    OUTPUT,
            @cQTY_PPA   OUTPUT,
            @cQTY_CHK   OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Exclude new SKU / lottable, which is always excess
         IF CAST( @cQTY_PPA AS INT) > 0
         BEGIN
            -- QTY excess
            IF (@nQTY + CAST( @cQTY_CHK AS INT)) > CAST( @cQTY_PPA AS INT)
            BEGIN
               SET @nErrNo = 121979
               SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- QTY EXCESS
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '121979', @cErrMsg1

               GOTO Quit
            END
         END
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PostPickAudit_Lottable -- For rollback or commit only our own transaction

      -- Update PPA
      EXECUTE rdt.rdt_PostPickAudit_Lottable_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'UPDATE', @cType,
         @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cDescr, @nQTY, @cLottableCode,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @nRowRef    OUTPUT,
         @cQTY_PPA   OUTPUT,
         @cQTY_CHK   OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_PostPickAudit_Lottable
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, ' +
               ' @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cLottableCode, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nRowRef, @cQTY_PPA, @cQTY_CHK, @cCHK_SKU, @cCHK_QTY, @cPPA_SKU, @cPPA_QTY, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile         INT,           ' +
               ' @nFunc           INT,           ' +
               ' @cLangCode       NVARCHAR( 3),  ' +
               ' @nStep           INT,           ' +
               ' @nInputKey       INT,           ' +
               ' @cFacility       NVARCHAR( 5),  ' +
               ' @cStorerKey      NVARCHAR( 15), ' +
               ' @cType           NVARCHAR( 10), ' +
               ' @cRefNo          NVARCHAR( 10), ' +
               ' @cPickSlipNo     NVARCHAR( 10), ' +
               ' @cLoadKey        NVARCHAR( 10), ' +
               ' @cOrderKey       NVARCHAR( 10), ' +
               ' @cDropID         NVARCHAR( 20), ' +
               ' @cSKU            NVARCHAR( 20), ' +
               ' @nQTY            INT,           ' +
               ' @cLottableCode   NVARCHAR( 30), ' +
               ' @cLottable01     NVARCHAR( 18), ' +
               ' @cLottable02     NVARCHAR( 18), ' +
               ' @cLottable03     NVARCHAR( 18), ' +
               ' @dLottable04     DATETIME,      ' +
               ' @dLottable05     DATETIME,      ' +
               ' @cLottable06     NVARCHAR( 30), ' +
               ' @cLottable07     NVARCHAR( 30), ' +
               ' @cLottable08     NVARCHAR( 30), ' +
               ' @cLottable09     NVARCHAR( 30), ' +
               ' @cLottable10     NVARCHAR( 30), ' +
               ' @cLottable11     NVARCHAR( 30), ' +
               ' @cLottable12     NVARCHAR( 30), ' +
               ' @dLottable13     DATETIME,      ' +
               ' @dLottable14     DATETIME,      ' +
               ' @dLottable15     DATETIME,      ' +
               ' @nRowRef         INT,           ' +
               ' @cQTY_PPA        NVARCHAR( 10), ' +
               ' @cQTY_CHK        NVARCHAR( 10), ' +
               ' @cCHK_SKU        NVARCHAR( 10), ' +
               ' @cCHK_QTY        NVARCHAR( 10), ' +
               ' @cPPA_SKU        NVARCHAR( 10), ' +
               ' @cPPA_QTY        NVARCHAR( 10), ' +
               ' @nErrNo          INT          OUTPUT, ' +
               ' @cErrMsg         NVARCHAR(20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,
               @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cLottableCode,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nRowRef, @cQTY_PPA, @cQTY_CHK, @cCHK_SKU, @cCHK_QTY, @cPPA_SKU, @cPPA_QTY,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_PostPickAudit_Lottable
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN rdtfnc_PostPickAudit_Lottable
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

      -- EventLog (yeekung01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '4', -- pack
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep,
         @cRefNo1     = @cRefNo,
         @cPickSlipNo = @cPickSlipNo,
         @cLoadKey    = @cLoadKey,
         @cOrderKey   = @cOrderKey,
         @cCartonID   = @cDropID, 
         @cSKU        = @cSKU,
         @nQty        = @nQTY,
         @cLottable01 = @cLottable01 ,
         @cLottable02 = @cLottable02 ,
         @cLottable03 = @cLottable03 ,
         @dLottable04 = @dLottable04 ,
         @dLottable05 = @dLottable05 ,
         @cLottable06 = @cLottable06 ,
         @cLottable07 = @cLottable07 ,
         @cLottable08 = @cLottable08 ,
         @cLottable09 = @cLottable09 ,
         @cLottable10 = @cLottable10 ,
         @cLottable11 = @cLottable11 ,
         @cLottable12 = @cLottable12 ,
         @dLottable13 = @dLottable13 ,
         @dLottable14 = @dLottable14 ,
         @dLottable15 = @dLottable15

      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderkey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = ''

      SET @cFieldAttr11 = '' -- PQTY

      -- Go to prev screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
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

      SET @cFieldAttr11 = '' -- PQTY

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nScn = 3990
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         -- Go to SKU screen
         SET @cOutField01 = @cRefNo
         SET @cOutField02 = @cPickSlipNo
         SET @cOutField03 = @cLoadKey
         SET @cOutField04 = @cOrderkey
         SET @cOutField05 = @cDropID
         SET @cOutField06 = ''

         -- Go to prev screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
   END
END
GOTO Quit


/********************************************************************************
Scn = 2615. Statistic
********************************************************************************/
Step_Statistic:
BEGIN
   -- Extended update
   IF @cExtendedUpdateSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, ' +
            ' @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cLottableCode, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nRowRef, @cQTY_PPA, @cQTY_CHK, @cCHK_SKU, @cCHK_QTY, @cPPA_SKU, @cPPA_QTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile         INT,           ' +
            ' @nFunc           INT,           ' +
            ' @cLangCode       NVARCHAR( 3),  ' +
            ' @nStep           INT,           ' +
            ' @nInputKey       INT,           ' +
            ' @cFacility       NVARCHAR( 5),  ' +
            ' @cStorerKey      NVARCHAR( 15), ' +
            ' @cType           NVARCHAR( 10), ' +
            ' @cRefNo          NVARCHAR( 10), ' +
            ' @cPickSlipNo     NVARCHAR( 10), ' +
            ' @cLoadKey        NVARCHAR( 10), ' +
            ' @cOrderKey       NVARCHAR( 10), ' +
            ' @cDropID         NVARCHAR( 20), ' +
            ' @cSKU            NVARCHAR( 20), ' +
            ' @nQTY            INT,           ' +
            ' @cLottableCode   NVARCHAR( 30), ' +
            ' @cLottable01     NVARCHAR( 18), ' +
            ' @cLottable02     NVARCHAR( 18), ' +
            ' @cLottable03     NVARCHAR( 18), ' +
            ' @dLottable04     DATETIME,      ' +
            ' @dLottable05     DATETIME,      ' +
            ' @cLottable06     NVARCHAR( 30), ' +
            ' @cLottable07     NVARCHAR( 30), ' +
            ' @cLottable08     NVARCHAR( 30), ' +
            ' @cLottable09     NVARCHAR( 30), ' +
            ' @cLottable10     NVARCHAR( 30), ' +
            ' @cLottable11     NVARCHAR( 30), ' +
            ' @cLottable12     NVARCHAR( 30), ' +
            ' @dLottable13     DATETIME,      ' +
            ' @dLottable14     DATETIME,      ' +
            ' @dLottable15     DATETIME,      ' +
            ' @nRowRef         INT,           ' +
            ' @cQTY_PPA        NVARCHAR( 10), ' +
            ' @cQTY_CHK        NVARCHAR( 10), ' +
            ' @cCHK_SKU        NVARCHAR( 10), ' +
            ' @cCHK_QTY        NVARCHAR( 10), ' +
            ' @cPPA_SKU        NVARCHAR( 10), ' +
            ' @cPPA_QTY        NVARCHAR( 10), ' +
            ' @nErrNo          INT          OUTPUT, ' +
            ' @cErrMsg         NVARCHAR(20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,
            @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cLottableCode,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nRowRef, @cQTY_PPA, @cQTY_CHK, @cCHK_SKU, @cCHK_QTY, @cPPA_SKU, @cPPA_QTY,
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   -- Prepare next screen var
   SET @cOutField01 = '' -- RefNo
   SET @cOutField02 = '' -- PickSlipNo
   SET @cOutField03 = '' -- LoadKey
   SET @cOutField04 = '' -- OrderKey
   SET @cOutField05 = '' -- DropID

   IF @cRefNo      <> '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE -- RefNo
   IF @cPickSlipNo <> '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE -- PickSlipNo
   IF @cLoadKey    <> '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE -- LoadKey
   IF @cOrderKey   <> '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE -- OrderKey
   IF @cDropID     <> '' EXEC rdt.rdtSetFocusField @nMobile, 5      -- DropID

   -- Go to criteria screen
   SET @nScn = @nScn_Criteria
   SET @nStep = @nStep_Criteria
END
GOTO Quit

/********************************************************************************
Step 6. Screen = 3570. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_MultiSKUBar:
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
         @cSKU     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END
   END

   -- Prepare SKU screen var
   SET @cOutField01 = @cRefNo
   SET @cOutField02 = @cPickSlipNo
   SET @cOutField03 = @cLoadKey
   SET @cOutField04 = @cOrderkey
   SET @cOutField05 = @cDropID
   SET @cOutField06 = @cSKU

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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,

      V_PickSlipNo   = @cPickSlipNo,
      V_Loadkey      = @cLoadKey,
      V_OrderKey     = @cOrderkey,
      V_CaseID       = @cDropID,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cDescr,
      V_UOM          = @cPUOM,
      V_QTY          = @nQTY,
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

      V_String1  = @cRefNo,
      V_String2  = @cSourceKey,
      V_String3  = @cType,
      V_String4  = @cMultiSKUBarcode,

      V_Integer1 = @nExtPUOM_Div,
      V_FromScn  = @nFromScn,
      V_FromStep = @nFromStep,


      V_String11 = @cPUOM_Desc,
      V_String12 = @cMUOM_Desc,
      V_String14 = @cQTY_PPA,
      V_String15 = @cQTY_CHK,
      V_String16 = @cCHK_SKU,
      V_String17 = @cCHK_QTY,
      V_String18 = @cPPA_SKU,
      V_String19 = @cPPA_QTY,

      V_PUOM_Div = @nPUOM_Div,

      V_String21 = @cExtendedValidateSP,
      V_String22 = @cExtendedUpdateSP,
      V_String23 = @cExtendedInfoSP,
      V_String24 = @cExtendedInfo,
      V_String25 = @cDecodeSP,
      V_String26 = @cDefaultCursor,
      V_String27 = @cDefaultQTY,
      V_String28 = @cPPACartonIDByPickDetailCaseID,
      V_String29 = @cSkipChkPSlipMustScanOut,
      V_String30 = @cAllowSKUNotInPickList,
      V_String31 = @cAllowLottableNotInPickList,
      V_String32 = @cAllowExcessQTY,
      V_String33 = @cExtendedUOMSP,

      V_String41 = @cLottableCode,

      I_Field01 = '',  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = '',  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = '',  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = '',  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = '',  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = '',  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = '',  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = '',  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = '',  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = '',  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = '',  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = '',  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = '',  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = '',  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = '',  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO