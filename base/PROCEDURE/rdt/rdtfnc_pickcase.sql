SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PickCase                                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author      Purposes                                     */
/* 2018-11-05   1.0  ChewKP      WMS-6666  Created                            */
/* 2022-08-17   1.1  Ung         WMS-20525 Add UCC                            */
/* 2022-12-09   1.2  Ung         WMS-21275 Fix AllowSkipLOC                   */
/* 2023-08-16   1.3  Ung         WMS-23142 Enable suggest SKU, descr          */
/* 2023-12-08   1.4  Ung         WMS-24353 Add ExtendedUpdteSP at screen 1    */
/* 2024-04-29   1.5  CYU027      UWP-18306 Short Pick                         */
/* 2024-05-06   1.6  Dennis      FCR-133   Carton pick  trigger Automation    */
/* 2024-06-11   1.7  Dennis      UWP-16958 Bug Fix                            */
/* 2024-07-09   1.8  NLT013      FCR-454 Add ExtScnSP to Pick UCC             */
/* 2024-07-16   1.9  JHU151      FCR-428 gen cctask and hold inv for short pk */
/* 2024-09-09   2.0  PXL009      FCR-770 Tote closure                         */
/* 2024-09-23   2.1  CYU027      FCR-808 PUMA SKU IMAGE widget                */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PickCase] (
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
   @bSuccess   INT,
   @nTranCount INT,
   @cOption    NVARCHAR( 1),
   @cSQL       NVARCHAR( MAX),
   @cSQLParam  NVARCHAR( MAX)

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

   @cLoadKey       NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @cPickZone      NVARCHAR( 10),
   @cSuggLOC       NVARCHAR( 10),
   @cSuggSKU       NVARCHAR( 20),
   @cSKUDescr      NVARCHAR( 60),
   @nSuggQTY       INT,

   @cZone          NVARCHAR( 18),
   @cSKUValidated  NVARCHAR( 2),
   @nActQTY        INT,
   @cDropID        NVARCHAR( 20),
   @cFromStep      NVARCHAR( 1),
   @cExtendedScreenSP   NVARCHAR( 20),
   @nAction     INT,
   @nAfterScn   INT,
   @nAfterStep  INT,

   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtScnSP           NVARCHAR( 20), --NLT013 New Extended Screen SP
   @cExtendedInfo       NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20),
   @cDefaultQTY         NVARCHAR( 1),
   @cAllowSkipLOC       NVARCHAR( 1),
   @cConfirmLOC         NVARCHAR( 1),
   @nTotalQty           INT,
   @cPickConfirmStatus  NVARCHAR( 1),
   @cAutoScanOut        NVARCHAR( 1),
   @cType               NVARCHAR( 10),
   @cBarcode            NVARCHAR( 60),
   @cUPC                NVARCHAR( 30),
   @cSKU                NVARCHAR( 20),
   @cQTY                NVARCHAR( 5),
   @nQTY                INT,
   @nMorePage           INT,
   @nLottableOnPage     INT,
   @cLottableCode       NVARCHAR( 30), 
   @cSuggID             NVARCHAR( 18),
   @tExtScnData         VariableTable,

   @cLottable01 NVARCHAR( 18),   @cChkLottable01 NVARCHAR( 18),
   @cLottable02 NVARCHAR( 18),   @cChkLottable02 NVARCHAR( 18),
   @cLottable03 NVARCHAR( 18),   @cChkLottable03 NVARCHAR( 18),
   @dLottable04 DATETIME,        @dChkLottable04 DATETIME,
   @dLottable05 DATETIME,        @dChkLottable05 DATETIME,
   @cLottable06 NVARCHAR( 30),   @cChkLottable06 NVARCHAR( 30),
   @cLottable07 NVARCHAR( 30),   @cChkLottable07 NVARCHAR( 30),
   @cLottable08 NVARCHAR( 30),   @cChkLottable08 NVARCHAR( 30),
   @cLottable09 NVARCHAR( 30),   @cChkLottable09 NVARCHAR( 30),
   @cLottable10 NVARCHAR( 30),   @cChkLottable10 NVARCHAR( 30),
   @cLottable11 NVARCHAR( 30),   @cChkLottable11 NVARCHAR( 30),
   @cLottable12 NVARCHAR( 30),   @cChkLottable12 NVARCHAR( 30),
   @dLottable13 DATETIME,        @dChkLottable13 DATETIME,
   @dLottable14 DATETIME,        @dChkLottable14 DATETIME,
   @dLottable15 DATETIME,        @dChkLottable15 DATETIME,
   
   @cInField01 NVARCHAR( 60),    @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),    @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),    @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),    @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),    @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),    @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),    @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),    @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),    @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),    @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),    @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),    @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),    @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),    @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),    @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1),

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

   @cLoadKey         = V_LoadKey,
   @cOrderKey        = V_OrderKey,
   @cPickZone        = V_Zone,
   @cPickSlipNo      = V_PickSlipNo,
   @cSuggLOC         = V_LOC,
   @cSuggSKU         = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @nSuggQTY         = V_QTY,
   @cSuggID          = V_ID,

   @cZone            = V_String1,
   @cSKUValidated    = V_String2,
   @cDropID          = V_String4,
   @cFromStep        = V_String5,

   @cExtendedValidateSP = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedInfoSP     = V_String23,
   @cExtendedInfo       = V_String24,
   @cDecodeSP           = V_String25,
   -- @nTotalQtySP      = V_String26,
   @cDefaultQTY         = V_String27,
   @cAllowSkipLOC       = V_String28,
   @cConfirmLOC         = V_String29,
   --@nTotalQty         = V_String30,
   @cPickConfirmStatus  = V_String31,
   @cAutoScanOut        = V_String32,
   @cExtScnSP           = V_String33,
   
   @nActQTY          = V_Integer1,
   @nTotalQty        = V_Integer2,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 957 -- Pick Case
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 957
   IF @nStep = 1  GOTO Step_1  -- Scn = 5290. PickSlipNo
   IF @nStep = 2  GOTO Step_2  -- Scn = 5291. PickZone, DropID
   IF @nStep = 3  GOTO Step_3  -- Scn = 5292. UCC
   IF @nStep = 4  GOTO Step_4  -- Scn = 5293. No more task in LOC
   IF @nStep = 5  GOTO Step_5  -- Scn = 5294. Confrim Short Pick?
   IF @nStep = 6  GOTO Step_6  -- Scn = 5295. Skip LOC?
   IF @nStep = 7  GOTO Step_7  -- Scn = 5296. Confirm LOC
   IF @nStep = 99  GOTO Step_99  -- Scn = Extended Screen
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_0. Func = 957
********************************************************************************/
Step_0:
BEGIN
   -- Get storer configure
   SET @cAllowSkipLOC = rdt.rdtGetConfig( @nFunc, 'AllowSkipLOC', @cStorerKey)
   SET @cConfirmLOC = rdt.rdtGetConfig( @nFunc, 'ConfirmLOC', @cStorerKey)
   SET @cDefaultQTY = rdt.rdtGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)

   SET @cDecodeSP = rdt.rdtGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SET @cExtScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtScnSP = '0'
      SET @cExtScnSP = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   SET @cLoadKey         = ''
   SET @cOrderKey        = ''
   SET @cPickZone        = ''
   SET @cPickSlipNo      = ''
   SET @cSuggLOC         = ''
   SET @cSuggSKU         = ''
   SET @cSKUDescr        = ''
   SET @nSuggQTY         = ''
   SET @cSuggID          = ''
   SET @nTotalQty        = 0

   -- Prepare next screen var
   SET @cOutField01 = '' -- PickSlipNo

   -- Go to PickSlipNo screen
   SET @nScn = 5290
   SET @nStep = 1
END
GOTO Quit


/************************************************************************************
Scn = 5290. PickSlipNo screen
   PSNO    (field01)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01

      -- Check blank
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 130551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNO required
         GOTO Step_1_Fail
      END

      SET @cOrderKey = ''
      SET @cLoadKey = ''
      SET @cZone = ''

      -- Get PickHeader info
      SELECT TOP 1
         @cOrderKey = OrderKey,
         @cLoadKey = ExternOrderKey,
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         -- Check PickSlipNo valid
         IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.RefKeyLookup RKL WITH (NOLOCK) WHERE RKL.PickSlipNo = @cPickSlipNo)
         BEGIN
            SET @nErrNo = 130552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Step_1_Fail
         END

         -- Check diff storer
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = RKL.Orderkey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 130553
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Step_1_Fail
         END
      END

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         DECLARE @cChkStorerKey NVARCHAR( 15)
         DECLARE @cChkStatus    NVARCHAR( 10)

         -- Get Order info
         SELECT
            @cChkStorerKey = StorerKey,
            @cChkStatus = Status
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         -- Check PickSlipNo valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 130554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Step_1_Fail
         END

         -- Check order shipped
         IF @cChkStatus >= '5'
         BEGIN
            SET @nErrNo = 130555
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked
            GOTO Step_1_Fail
         END

         -- Check storer
         IF @cChkStorerKey <> @cStorerKey
         BEGIN
            SET @nErrNo = 130556
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff storer
            GOTO Step_1_Fail
         END
      END

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
      BEGIN
         -- Check PickSlip valid
         IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) WHERE LPD.LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 130557
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Step_1_Fail
         END
/*
         -- Check order shipped
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
               AND O.Status >= '5')
         BEGIN
            SET @nErrNo = 130558
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked
            GOTO Step_1_Fail
         END
*/
         -- Check diff storer
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
            WHERE LPD.LoadKey = @cLoadKey
               AND O.StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 130559
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Step_1_Fail
         END
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         -- Check PickSlip valid
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
         BEGIN
            SET @nErrNo = 130560
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
            GOTO Step_1_Fail
         END
/*
         -- Check order picked
         IF EXISTS( SELECT 1
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND O.Status >= '5')
         BEGIN
            SET @nErrNo = 130561
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked
            GOTO Step_1_Fail
         END
*/
         -- Check diff storer
         IF EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND StorerKey <> @cStorerKey)
         BEGIN
            SET @nErrNo = 130562
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Step_1_Fail
         END
      END

      DECLARE @dScanInDate DATETIME
      DECLARE @dScanOutDate DATETIME

      -- Get picking info
      SELECT TOP 1
         @dScanInDate = ScanInDate,
         @dScanOutDate = ScanOutDate
      FROM dbo.PickingInfo WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      IF @@ROWCOUNT = 0
      BEGIN
         INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)
         VALUES (@cPickSlipNo, GETDATE(), @cUserName)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 130583
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail scan-in
            GOTO Step_1_Fail
         END
      END
      ELSE
      BEGIN
         -- Scan-in
         IF @dScanInDate IS NULL
         BEGIN
            UPDATE dbo.PickingInfo SET
               ScanInDate = GETDATE(),
               PickerID = @cUserName
            WHERE PickSlipNo = @cPickSlipNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 130563
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail scan-in
               GOTO Step_1_Fail
            END
         END

         -- Check already scan out
         IF @dScanOutDate IS NOT NULL
         BEGIN
            SET @nErrNo = 130564
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS scanned out
            GOTO Step_1_Fail
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile         INT                      ' +
               ',@nFunc           INT                      ' +
               ',@cLangCode       NVARCHAR( 3)             ' +
               ',@nStep           INT                      ' +
               ',@nInputKey       INT                      ' +
               ',@cFacility       NVARCHAR( 5)             ' +
               ',@cStorerKey      NVARCHAR( 15)            ' +
               ',@cPickSlipNo     NVARCHAR( 10)            ' +
               ',@cPickZone       NVARCHAR( 10)            ' +
               ',@cDropID         NVARCHAR( 20)            ' +
               ',@cSuggLOC        NVARCHAR( 10)            ' +
               ',@cSuggID         NVARCHAR( 18)            ' +
               ',@cSuggSKU        NVARCHAR( 20)            ' +
               ',@nSuggQTY        INT                      ' +
               ',@cOption         NVARCHAR( 1)             ' +
               ',@cLottableCode   NVARCHAR( 30)            ' +
               ',@cLottable01     NVARCHAR( 18)            ' +
               ',@cLottable02     NVARCHAR( 18)            ' +
               ',@cLottable03     NVARCHAR( 18)            ' +
               ',@dLottable04     DATETIME                 ' +
               ',@dLottable05     DATETIME                 ' +
               ',@cLottable06     NVARCHAR( 30)            ' +
               ',@cLottable07     NVARCHAR( 30)            ' +
               ',@cLottable08     NVARCHAR( 30)            ' +
               ',@cLottable09     NVARCHAR( 30)            ' +
               ',@cLottable10     NVARCHAR( 30)            ' +
               ',@cLottable11     NVARCHAR( 30)            ' +
               ',@cLottable12     NVARCHAR( 30)            ' +
               ',@dLottable13     DATETIME                 ' +
               ',@dLottable14     DATETIME                 ' +
               ',@dLottable15     DATETIME                 ' +
               ',@nErrNo          INT           OUTPUT     ' +
               ',@cErrMsg         NVARCHAR(250) OUTPUT     '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' --PickZone
      SET @cOutField03 = '' --DropID

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone

      -- Go to PickZone screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
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
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = '' -- PSNO
   END
END
GOTO Quit


/********************************************************************************
Scn = 5291. PickZone screen
   LOC         (field01)
   PickZone    (field02)
   DropID      (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickZone = @cInField02
      SET @cDropID = @cInField03

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
               SET @nErrNo = 130565
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
               GOTO Step_2_Fail
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
               SET @nErrNo = 130566
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
               GOTO Step_2_Fail
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
               SET @nErrNo = 130567
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
               GOTO Step_2_Fail
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
               SET @nErrNo = 130568
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
               GOTO Step_2_Fail
            END
         END
      END
      SET @cOutField02 = @cPickZone

      -- Check DropID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0
      BEGIN
         SET @nErrNo = 130580
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- DropID
         SET @cOutField03 = ''
         GOTO Quit
      END
      SET @cOutField03 = @cDropID

      -- Get task
      SET @cSKUValidated = '0'
      SET @nActQTY = 0
      SET @cSuggLOC = ''
      EXEC rdt.rdt_PickCase_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTLOC'
            ,@cPickSlipNo
            ,@cPickZone
            ,@cSuggLOC         OUTPUT
            ,@cSuggSKU         OUTPUT
            ,@cSKUDescr        OUTPUT
            ,@nSuggQTY         OUTPUT
            ,@cSuggID          OUTPUT
            ,@cBarcode     
            ,@nTotalQty        OUTPUT
            ,@nErrNo           OUTPUT
            ,@cErrMsg          OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      IF @cConfirmLOC = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cSuggLOC
         SET @cOutField02 = '' -- LOC

         -- Go to confirm LOC screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cSuggLOC
         SET @cOutField02 = @cSuggSKU
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
         SET @cOutField05 = '' -- SKU
         SET @cOutField06 = CAST (@nSuggQTY AS NVARCHAR(5))
         SET @cOutField07 = CAST (@nTotalQty  AS NVARCHAR(5)) -- QTY
         SET @cOutField08 = @cSuggID 
         SET @cOutField09 = '' 

         EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU

         -- Disable QTY field
         SET @cFieldAttr07 = CASE WHEN @nTotalQty = '1' THEN 'O' ELSE '' END -- QTY

         -- Go to SKU QTY screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Scan out
      SET @nErrNo = 0
      EXEC rdt.rdt_PickPiece_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickSlipNo
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare prev screen var
      SET @cOutField01 = '' -- PickSlipNo

      -- Go to PickSlipNo screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   --Jump point
   Step_2_Jump:
   IF @cExtScnSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
   BEGIN
      SET @nAction = 0
      GOTO Step_99
   END
   
   GOTO Quit

   Step_2_Fail:
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone
      SET @cOutField02 = '' -- PickZone
   END
END
GOTO Quit


/********************************************************************************
Scn = 5292. UCC screen
   LOC         (field01)
   SKU         (field02)
   DESCR1      (field03)
   DESCR1      (field04)
   UCC         (field05, input)
   PK QTY      (field06)
   ACT QTY     (field07)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cBarcode = @cInField05 -- SKU
      SET @cUPC = LEFT( @cInField05, 30)
      --SET @cQTY = CASE WHEN @cFieldAttr07 = 'O' THEN @cOutField07 ELSE @cInField07 END

      -- Retain value
      --SET @cOutField07 = CASE WHEN @cFieldAttr07 = 'O' THEN @cOutField07 ELSE @cInField07 END -- MQTY

      SET @cSKU = ''
      SET @nQTY = 0

      -- Skip LOC
      IF @cAllowSkipLOC = '1' AND @cBarcode = '' AND @nTotalQTY = ''
      BEGIN
         -- Prepare skip LOC screen var
         SET @cOutField01 = ''

         -- Remember step
         SET @cFromStep = @nStep

         -- Go to skip LOC screen
         SET @nScn = 5295
         SET @nStep = @nStep + 3

         GOTO Quit
      END

      -- Check SKU blank
      IF @cBarcode = '' AND @cSKUValidated = '0' -- False
      BEGIN
         SET @nErrNo = 130569
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU
         GOTO Step_3_Fail
      END

      SELECT
         @cChkLottable01 = '', @cChkLottable02 = '', @cChkLottable03 = '',    @dChkLottable04 = NULL,  @dChkLottable05 = NULL,
         @cChkLottable06 = '', @cChkLottable07 = '', @cChkLottable08 = '',    @cChkLottable09 = '',    @cChkLottable10 = '',
         @cChkLottable11 = '', @cChkLottable12 = '', @dChkLottable13 = NULL,  @dChkLottable14 = NULL,  @dChkLottable15 = NULL

      -- Validate SKU
      IF @cBarcode <> ''
      BEGIN
         IF @cBarcode = '99' -- Fully short
         BEGIN

            EXEC rdt.rdt_PickCase_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTUCC'
               ,@cPickSlipNo
               ,@cPickZone
               ,@cSuggLOC         OUTPUT
               ,@cSuggSKU         OUTPUT
               ,@cSKUDescr        OUTPUT
               ,@nSuggQTY         OUTPUT
               ,@cSuggID          OUTPUT
               ,@cBarcode
               ,@nTotalQty        OUTPUT
               ,@nErrNo           OUTPUT
               ,@cErrMsg          OUTPUT

            SET @cOutField01 = 1
            SET @cOutField02 = CAST ((@nSuggQTY -@nTotalQty) AS NVARCHAR(5))

            SET @nStep = 5
            SET @nScn = 5294


            GOTO QUIT


         END
         ELSE
         BEGIN
            -- Decode
            IF @cDecodeSP <> ''
            BEGIN
               -- Standard decode
               IF @cDecodeSP = '1'
               BEGIN
                  EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                     @cUPC        = @cUPC           OUTPUT,
                     @nQTY        = @nQTY           OUTPUT,
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
                     @dLottable15 = @dChkLottable15 OUTPUT,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT,
                     @cType       = 'UPC'
               END
               
               -- Customize decode
               ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
                     ' @cPickSlipNo, @cPickZone, @cDropID, @cLOC, ' +
                     ' @cUPC        OUTPUT, @nQTY        OUTPUT, ' +
                     ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
                     ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
                     ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
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
                     ' @cPickZone    NVARCHAR( 10), ' +
                     ' @cDropID      NVARCHAR( 20), ' +
                     ' @cLOC         NVARCHAR( 10), ' +
                     ' @cUPC         NVARCHAR( 30)  OUTPUT, ' +
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
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,
                     @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC,
                     @cUPC           OUTPUT, @nQTY           OUTPUT,
                     @cChkLottable01 OUTPUT, @cChkLottable02 OUTPUT, @cChkLottable03 OUTPUT, @dChkLottable04 OUTPUT, @dChkLottable05 OUTPUT,
                     @cChkLottable06 OUTPUT, @cChkLottable07 OUTPUT, @cChkLottable08 OUTPUT, @cChkLottable09 OUTPUT, @cChkLottable10 OUTPUT,
                     @cChkLottable11 OUTPUT, @cChkLottable12 OUTPUT, @dChkLottable13 OUTPUT, @dChkLottable14 OUTPUT, @dChkLottable15 OUTPUT,
                     @nErrNo         OUTPUT, @cErrMsg        OUTPUT
               END

               IF @nErrNo <> 0
                  GOTO Step_3_Fail
            END
            
            SELECT @cUPC = SKU
                  ,@cQTY = Qty 
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND UCCNo = @cBarcode
            --AND SKU = @cSuggSKU 

            -- Get SKU count
            DECLARE @nSKUCnt INT
            SET @nSKUCnt = 0
            EXEC RDT.rdt_GetSKUCNT
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cUPC
               ,@nSKUCnt     = @nSKUCnt   OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT

            -- Check SKU
            IF @nSKUCnt = 0
            BEGIN
               SET @nErrNo = 130570
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
               GOTO Step_3_Fail
            END

            -- Check barcode return multi SKU
            IF @nSKUCnt > 1
            BEGIN
               SET @nErrNo = 130571
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
               GOTO Step_3_Fail
            END

            -- Get SKU
            EXEC rdt.rdt_GetSKU
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cUPC      OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT
            IF @nErrNo <> 0
               GOTO Step_3_Fail

            SET @cSKU = @cUPC

            -- Validate SKU
--            IF @cSKU <> @cSuggSKU
--            BEGIN
--               SET @nErrNo = 130572
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SKU
--               EXEC rdt.rdtSetFocusField @nMobile, 11  -- SKU
--               GOTO Step_3_Fail
--            END

            -- Mark SKU as validated
            SET @cSKUValidated = '1'
         END
      END

      -- Validate QTY
      IF @cQTY <> '' AND RDT.rdtIsValidQTY( @cQTY, 0) = 0
      BEGIN
         SET @nErrNo = 130573
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- QTY
         GOTO Step_3_Fail
      END

      -- Check full short with QTY
      IF @cSKUValidated = '99' AND @cQTY <> '0' AND @cQTY <> ''
      BEGIN
         SET @nErrNo = 130579
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AllShortWithQTY
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- QTY
         GOTO Step_3_Fail
      END

      -- Top up QTY
      IF @cSKUValidated = '99' -- Fully short
         SET @nQTY = 0
      ELSE IF @nQTY > 0
         SET @nQTY = @nActQTY + @nQTY
      ELSE
         IF @cSKU <> '' AND @nTotalQty = '1' AND @cDefaultQTY <> '1'
            SET @nQTY = @nActQTY + 1
         ELSE
            SET @nQTY = CAST( @cQTY AS INT)

      -- Check over pick
--      IF @nQTY > @nSuggQTY
--      BEGIN
--         SET @nErrNo = 130574
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Over pick
--         EXEC rdt.rdtSetFocusField @nMobile, 7 -- PQTY
--         GOTO Step_3_Fail
--      END

      -- Save to ActQTY
      SET @nActQTY = @nQTY
      --SET @cOutField07 = CAST( @nQTY AS NVARCHAR(5))

      -- SKU scanned, remain in current screen
      --IF @cBarcode <> ''
      --BEGIN
      --   SET @cOutField05 = '' -- SKU

      --   IF @nTotalQty = '1'
      --   BEGIN
      --      EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU
      --      IF @nActQTY <> @nSuggQTY
      --         GOTO Quit
      --   END
      --   ELSE
      --   BEGIN
      --      EXEC rdt.rdtSetFocusField @nMobile, 7 -- MQTY
      --      GOTO Quit
      --   END
      --END

      -- QTY short
      --SELECT @nActQTY '@nActQTY' , @nSuggQTY '@nSuggQTY' 

--      IF @nActQTY < @nSuggQTY
--      BEGIN
--         -- Prepare next screen var
--         SET @cOption = ''
--         SET @cOutField01 = '' -- Option
--
--         -- Enable field
--         SET @cFieldAttr07 = '' -- QTY
--
--         SET @nScn = @nScn + 2
--         SET @nStep = @nStep + 2
--      END

      -- QTY fulfill
      --IF @nActQTY = @nSuggQTY
      --BEGIN
      -- Confirm
      EXEC RDT.rdt_PickCase_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CONFIRM'
         ,@cPickSlipNo
         ,@cPickZone
         ,@cDropID
         ,@cSuggLOC
         ,@cSuggID 
         ,@cBarcode
         ,@cSuggSKU
         ,@nActQTY
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- PXL009 call extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile         INT                      ' +
               ',@nFunc           INT                      ' +
               ',@cLangCode       NVARCHAR( 3)             ' +
               ',@nStep           INT                      ' +
               ',@nInputKey       INT                      ' +
               ',@cFacility       NVARCHAR( 5)             ' +
               ',@cStorerKey      NVARCHAR( 15)            ' +
               ',@cPickSlipNo     NVARCHAR( 10)            ' +
               ',@cPickZone       NVARCHAR( 10)            ' +
               ',@cDropID         NVARCHAR( 20)            ' +
               ',@cSuggLOC        NVARCHAR( 10)            ' +
               ',@cSuggID         NVARCHAR( 18)            ' +
               ',@cSuggSKU        NVARCHAR( 20)            ' +
               ',@nSuggQTY        INT                      ' +
               ',@cOption         NVARCHAR( 1)             ' +
               ',@cLottableCode   NVARCHAR( 30)            ' +
               ',@cLottable01     NVARCHAR( 18)            ' +
               ',@cLottable02     NVARCHAR( 18)            ' +
               ',@cLottable03     NVARCHAR( 18)            ' +
               ',@dLottable04     DATETIME                 ' +
               ',@dLottable05     DATETIME                 ' +
               ',@cLottable06     NVARCHAR( 30)            ' +
               ',@cLottable07     NVARCHAR( 30)            ' +
               ',@cLottable08     NVARCHAR( 30)            ' +
               ',@cLottable09     NVARCHAR( 30)            ' +
               ',@cLottable10     NVARCHAR( 30)            ' +
               ',@cLottable11     NVARCHAR( 30)            ' +
               ',@cLottable12     NVARCHAR( 30)            ' +
               ',@dLottable13     DATETIME                 ' +
               ',@dLottable14     DATETIME                 ' +
               ',@dLottable15     DATETIME                 ' +
               ',@nErrNo          INT           OUTPUT     ' +
               ',@cErrMsg         NVARCHAR(250) OUTPUT     '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @nTotalQty = @nTotalQty + 1 
      
      -- Get task in same LOC
      SET @cSKUValidated = '0'
      SET @nActQTY = 0
      SET @cSuggSKU = ''
      EXEC rdt.rdt_PickCase_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTUCC'
           ,@cPickSlipNo
           ,@cPickZone
           ,@cSuggLOC         OUTPUT
           ,@cSuggSKU         OUTPUT
           ,@cSKUDescr        OUTPUT
           ,@nSuggQTY         OUTPUT
           ,@cSuggID          OUTPUT
           ,@cBarcode     
           ,@nTotalQty        OUTPUT
           ,@nErrNo           OUTPUT
           ,@cErrMsg          OUTPUT
      IF @nErrNo = 0
      BEGIN
         -- Prepare SKU QTY screen var
         SET @cOutField01 = @cSuggLOC
         SET @cOutField02 = @cSuggSKU
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
         SET @cOutField05 = '' -- SKU/UPC
         SET @cOutField06 = CAST (@nSuggQTY AS NVARCHAR(5))
         SET @cOutField07 = CAST (@nTotalQty AS NVARCHAR(5)) -- QTY
         SET @cOutField08 = @cSuggID 
         SET @cOutField09 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU
      END
      ELSE
      BEGIN
         SET @nTotalQty = 0
         
         -- Get task in same LOC Diff ID
         SET @cSKUValidated = '0'
         SET @nActQTY = 0
         SET @cSuggSKU = ''
         EXEC rdt.rdt_PickCase_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTID'
              ,@cPickSlipNo
              ,@cPickZone
              ,@cSuggLOC         OUTPUT
              ,@cSuggSKU         OUTPUT
              ,@cSKUDescr        OUTPUT
              ,@nSuggQTY         OUTPUT
              ,@cSuggID          OUTPUT
              ,@cBarcode     
              ,@nTotalQty        OUTPUT
              ,@nErrNo           OUTPUT
              ,@cErrMsg          OUTPUT
              
         IF @nErrNo = 0 
         BEGIN
            -- Prepare SKU QTY screen var
            SET @cOutField01 = @cSuggLOC
            SET @cOutField02 = ''--@cSuggSKU
            SET @cOutField03 = ''--rdt.rdtFormatString( @cSKUDescr, 1, 20)
            SET @cOutField04 = ''--rdt.rdtFormatString( @cSKUDescr, 21, 20)
            SET @cOutField05 = '' -- SKU/UPC
            SET @cOutField06 = CAST( @nSuggQTY AS NVARCHAR(5))
            SET @cOutField07 = CAST( @nTotalQty AS NVARCHAR(5))-- QTY
            SET @cOutField08 = @cSuggID 
            SET @cOutField09 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU
         END
         ELSE
         BEGIN
            /*
            -- Enable field
            SET @cFieldAttr07 = '' -- QTY

            -- Goto no more task in loc screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            */

            -- Get task in next loc
            SET @cSKUValidated = '0'
            SET @nActQTY = 0
            EXEC rdt.rdt_PickCase_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTLOC'
               ,@cPickSlipNo
               ,@cPickZone
               ,@cSuggLOC         OUTPUT
               ,@cSuggSKU         OUTPUT
               ,@cSKUDescr        OUTPUT
               ,@nSuggQTY         OUTPUT
               ,@cSuggID          OUTPUT
               ,@cBarcode     
               ,@nTotalQty        OUTPUT
               ,@nErrNo           OUTPUT
               ,@cErrMsg          OUTPUT
            IF @nErrNo = 0
            BEGIN
               IF @cConfirmLOC = '1'
               BEGIN
                  -- Prepare next screen var
                  SET @cOutField01 = @cSuggLOC
                  SET @cOutField02 = '' -- LOC

                  -- Go to confirm LOC screen
                  SET @nScn = 5296
                  SET @nStep = @nStep + 4
               END
               ELSE
               BEGIN
                  -- Prepare SKU QTY screen var
                  SET @cOutField01 = @cSuggLOC
                  SET @cOutField02 = @cSuggSKU
                  SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
                  SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
                  SET @cOutField05 = '' -- SKU/UPC
                  SET @cOutField06 = CAST (@nSuggQTY AS NVARCHAR(5))
                  SET @cOutField07 = CAST (@nTotalQty AS NVARCHAR(5))-- QTY
                  SET @cOutField08 = @cSuggID 
                  SET @cOutField09 = ''

                  EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU
               END
            END
            ELSE
            BEGIN
               -- Scan out
               SET @nErrNo = 0
               EXEC rdt.rdt_PickPiece_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                  ,@cPickSlipNo
                  ,@nErrNo       OUTPUT
                  ,@cErrMsg      OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit

               -- Prepare next screen var
               SET @cOutField01 = '' -- PickSlipNo

               -- Go to PickSlipNo screen
               SET @nScn = 5290
               SET @nStep = @nStep - 2
            END
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' --PickZone
      SET @cOutField03 = '' --DropID

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone

      -- Enable field
      SET @cFieldAttr07 = '' -- QTY

      -- Go to prev screen
      SET @nScn = 5291
      SET @nStep = @nStep - 1
   END

   IF @cExtScnSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
   BEGIN
      SET @nAction = 0
      GOTO Step_99
   END

   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField05 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Scn = 5293. Message. No more task in LOC
********************************************************************************/
Step_4:
BEGIN
   -- Get task in next loc
   SET @cSKUValidated = '0'
   SET @nTotalQty = 0
   SET @nActQTY = 0
   EXEC rdt.rdt_PickCase_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTLOC'
           ,@cPickSlipNo
           ,@cPickZone
           ,@cSuggLOC         OUTPUT
           ,@cSuggSKU         OUTPUT
           ,@cSKUDescr        OUTPUT
           ,@nSuggQTY         OUTPUT
           ,@cSuggID          OUTPUT
           ,@cBarcode     
           ,@nTotalQty        OUTPUT
           ,@nErrNo           OUTPUT
           ,@cErrMsg          OUTPUT
   IF @nErrNo = 0
   BEGIN
      IF @cConfirmLOC = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cSuggLOC
         SET @cOutField02 = '' -- LOC

         -- Go to confirm LOC screen
         SET @nScn = 5296
         SET @nStep = @nStep + 3
      END
      ELSE
      BEGIN
         -- Prepare SKU QTY screen var
         SET @cOutField01 = @cSuggLOC
         SET @cOutField02 = ''--@cSuggSKU
         SET @cOutField03 = ''--rdt.rdtFormatString( @cSKUDescr, 1, 20)
         SET @cOutField04 = ''--rdt.rdtFormatString( @cSKUDescr, 21, 20)
         SET @cOutField05 = '' -- SKU/UPC
         SET @cOutField06 = CAST ( @nSuggQTY AS NVARCHAR(5))
         SET @cOutField07 = CAST ( @nTotalQty AS NVARCHAR(5))-- QTY
         SET @cOutField08 = @cSuggID 
         SET @cOutField09 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU

         -- Disable QTY field
         --SET @cFieldAttr07 = CASE WHEN @nTotalQty = '1' THEN 'O' ELSE '' END

         -- Go to SKU QTY screen
         SET @nScn = 5292
         SET @nStep = @nStep - 1
      END
   END
   ELSE
   BEGIN
      -- Scan out
      SET @nErrNo = 0
      EXEC rdt.rdt_PickPiece_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickSlipNo
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = '' -- PickSlipNo

      -- Go to PickSlipNo screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END
END

IF @cExtScnSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
BEGIN
   SET @nAction = 0
   GOTO Step_99
END

GOTO Quit


/********************************************************************************
Scn = 5294. Short the Pick by XY Cases?
   Option (field01)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01
      
      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 130575
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required
         GOTO Step_5_Fail
      END

      -- Validate option
--       IF @cOption <> '1' AND @cOption <> '2' AND @cOption <> '3' -- (ChewKP01)
      IF @cOption <> '1' AND @cOption <> '0'
      BEGIN
         SET @nErrNo = 130576
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_5_Fail
      END

      

      IF @cOption = '1'  -- Yes    
      BEGIN
         -- Confirm    
         EXEC RDT.rdt_PickCase_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SHORT'
            ,@cPickSlipNo
            ,@cPickZone
            ,@cDropID
            ,@cSuggLOC
            ,@cSuggID 
            ,@cBarcode
            ,@cSuggSKU
            ,@nActQTY
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile         INT                      ' +
                  ',@nFunc           INT                      ' +
                  ',@cLangCode       NVARCHAR( 3)             ' +
                  ',@nStep           INT                      ' +
                  ',@nInputKey       INT                      ' +
                  ',@cFacility       NVARCHAR( 5)             ' +
                  ',@cStorerKey      NVARCHAR( 15)            ' +
                  ',@cPickSlipNo     NVARCHAR( 10)            ' +
                  ',@cPickZone       NVARCHAR( 10)            ' +
                  ',@cDropID         NVARCHAR( 20)            ' +
                  ',@cSuggLOC        NVARCHAR( 10)            ' +
                  ',@cSuggID         NVARCHAR( 18)            ' +
                  ',@cSuggSKU        NVARCHAR( 20)            ' +
                  ',@nSuggQTY        INT                      ' +
                  ',@cOption         NVARCHAR( 1)             ' +
                  ',@cLottableCode   NVARCHAR( 30)            ' +
                  ',@cLottable01     NVARCHAR( 18)            ' +
                  ',@cLottable02     NVARCHAR( 18)            ' +
                  ',@cLottable03     NVARCHAR( 18)            ' +
                  ',@dLottable04     DATETIME                 ' +
                  ',@dLottable05     DATETIME                 ' +
                  ',@cLottable06     NVARCHAR( 30)            ' +
                  ',@cLottable07     NVARCHAR( 30)            ' +
                  ',@cLottable08     NVARCHAR( 30)            ' +
                  ',@cLottable09     NVARCHAR( 30)            ' +
                  ',@cLottable10     NVARCHAR( 30)            ' +
                  ',@cLottable11     NVARCHAR( 30)            ' +
                  ',@cLottable12     NVARCHAR( 30)            ' +
                  ',@dLottable13     DATETIME                 ' +
                  ',@dLottable14     DATETIME                 ' +
                  ',@dLottable15     DATETIME                 ' +
                  ',@nErrNo          INT           OUTPUT     ' +
                  ',@cErrMsg         NVARCHAR(250) OUTPUT     '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode, 
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_5_Fail
            END
         END
         
         SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '957ExtendedScreenSP', @cStorerKey), '')
         SET @nAction = 1
         IF @cExtendedScreenSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
            BEGIN
               EXECUTE [RDT].[rdt_957ExtScnEntry]
                  @cExtendedScreenSP,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cBarcode,@nAction,
                  @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Step_7_Fail
            END
         END
         SET @nTotalQty = @nTotalQty + 1 

        -- Get task in current LOC
         SET @cSKUValidated = '0'
         SET @nActQTY = 0
         EXEC rdt.rdt_PickCase_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTUCC'
            ,@cPickSlipNo
            ,@cPickZone
            ,@cSuggLOC         OUTPUT
            ,@cSuggSKU         OUTPUT
            ,@cSKUDescr        OUTPUT
            ,@nSuggQTY         OUTPUT
            ,@cSuggID          OUTPUT
            ,@cBarcode     
            ,@nTotalQty        OUTPUT
            ,@nErrNo           OUTPUT
            ,@cErrMsg          OUTPUT
         IF @nErrNo = 0
         BEGIN
            -- Prepare SKU QTY screen var
            SET @cOutField01 = @cSuggLOC
            SET @cOutField02 = @cSuggSKU
            SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
            SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
            SET @cOutField05 = '' -- SKU/UPC
            SET @cOutField06 = CAST (@nSuggQTY AS NVARCHAR(5))
            SET @cOutField07 = CAST (@nTotalQty AS NVARCHAR(5)) -- QTY
            SET @cOutField08 = @cSuggID 
            SET @cOutField09 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU

            -- Disable QTY field
            --SET @cFieldAttr07 = CASE WHEN @nTotalQty = '1' THEN 'O' ELSE '' END

            -- Go to SKU QTY screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END
         ELSE
         BEGIN
            -- Go to no more task in loc screen
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END

         IF @cExtScnSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
         BEGIN
            SET @nAction = 0
            GOTO Step_99
         END

         GOTO Quit
      END

-- CYU027 UWP-18306
--       ELSE IF @cOption = '3' -- (ChewKP01)
--       BEGIN
--          -- Confirm
--          EXEC RDT.rdt_PickCase_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CONFIRM'
--             ,@cPickSlipNo
--             ,@cPickZone
--             ,@cDropID
--             ,@cSuggLOC
--             ,@cSuggID
--             ,@cBarcode
--             ,@cSuggSKU
--             ,@nActQTY
--             ,@nErrNo       OUTPUT
--             ,@cErrMsg      OUTPUT
--          IF @nErrNo <> 0
--             GOTO Quit
--
--          SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '957ExtendedScreenSP', @cStorerKey), '')
--          SET @nAction = 1
--          IF @cExtendedScreenSP <> ''
--          BEGIN
--             IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
--             BEGIN
--                EXECUTE [RDT].[rdt_957ExtScnEntry]
--                   @cExtendedScreenSP,
--                   @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
--                   @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode,
--                   @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
--                   @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
--                   @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
--                   @nAction,
--                   @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
--                   @nErrNo OUTPUT, @cErrMsg OUTPUT
--
--                   IF @nErrNo <> 0
--                      GOTO Step_5_Fail
--             END
--          END
--          -- Get task in current LOC
--          SET @cSKUValidated = '0'
--          SET @nTotalQty = @nTotalQty + 1
--          SET @nActQTY = 0
--
--          -- Goto PickZone Screen
--          SET @cOutField01 = @cPickSlipNo
--          SET @cOutField02 = ''
--          SET @cOutField03 = ''
--
--          SET @nScn = @nScn - 3
--          SET @nStep = @nStep - 3
--
--          EXEC rdt.rdtSetFocusField @nMobile, 3 -- DropID
--          GOTO Quit
--       END
   END

   -- Prepare SKU QTY screen var
   SET @cOutField01 = @cSuggLOC
   SET @cOutField02 = ''--@cSuggSKU
   SET @cOutField03 = ''--rdt.rdtFormatString( @cSKUDescr, 1, 20)
   SET @cOutField04 = ''--rdt.rdtFormatString( @cSKUDescr, 21, 20)
   SET @cOutField05 = '' -- SKU/UPC
   SET @cOutField06 = CAST( @nSuggQTY AS NVARCHAR(5))
   SET @cOutField07 = CAST( @nTotalQty AS NVARCHAR(5))
   SET @cOutField08 = @cSuggID 
   SET @cOutField09 = ''

   -- Disable QTY field
   --SET @cFieldAttr07 = CASE WHEN @nTotalQty = '1' THEN 'O' ELSE '' END -- QTY

   IF @cFieldAttr07 = 'O'
      EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU
   ELSE
      EXEC rdt.rdtSetFocusField @nMobile, 7 -- QTY

   -- Go to SKU QTY screen
   SET @nScn = @nScn - 2
   SET @nStep = @nStep - 2

   IF @cExtScnSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
   BEGIN
      SET @nAction = 0
      GOTO Step_99
   END

   GOTO Quit

   Step_5_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' --Option
   END
END
GOTO Quit


/********************************************************************************
Scn = 5295. Skip LOC?
   Option (field01)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 130577
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required
         GOTO Step_6_Fail
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 130578
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_6_Fail
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         -- Get task in current LOC
         SET @cSKUValidated = '0'
         SET @nActQTY = 0
         SET @nTotalQty = 0
         EXEC rdt.rdt_PickCase_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTLOC'
              ,@cPickSlipNo
              ,@cPickZone
              ,@cSuggLOC         OUTPUT
              ,@cSuggSKU         OUTPUT
              ,@cSKUDescr        OUTPUT
              ,@nSuggQTY         OUTPUT
              ,@cSuggID          OUTPUT
              ,@cBarcode     
              ,@nTotalQty        OUTPUT
              ,@nErrNo           OUTPUT
              ,@cErrMsg          OUTPUT
         IF @nErrNo = 0
         BEGIN
            IF @cConfirmLOC = '1'
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cSuggLOC
               SET @cOutField02 = '' -- LOC

               -- Go to confirm LOC screen
               SET @nScn = 5296
               SET @nStep = @nStep + 1
            END
            ELSE
            BEGIN
               -- Prepare SKU QTY screen var
               SET @cOutField01 = @cSuggLOC
               SET @cOutField02 = @cSuggSKU
               SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
               SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
               SET @cOutField05 = '' -- SKU/UPC
               SET @cOutField06 = CAST (@nSuggQTY AS NVARCHAR(5))
               SET @cOutField07 = CAST (@nTotalQty AS NVARCHAR(5))-- QTY
               SET @cOutField08 = @cSuggID 
               SET @cOutField09 = ''

               EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU

               -- Disable QTY field
               --SET @cFieldAttr07 = CASE WHEN @nTotalQty = '1' THEN 'O' ELSE '' END

               -- Go to SKU QTY screen
               SET @nScn = 5292
               SET @nStep = @nStep - 3
            END
         END
         ELSE
         BEGIN
            -- Go to no more task in loc screen
            SET @nScn = 5293
            SET @nStep = @nStep - 2
         END
         GOTO Quit
      END
   END

   IF @cFromStep = '3'
   BEGIN
      -- Prepare SKU QTY screen var
      SET @cOutField01 = @cSuggLOC
      SET @cOutField02 = @cSuggSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
      SET @cOutField05 = '' -- SKU/UPC
      SET @cOutField06 = CAST (@nSuggQTY AS NVARCHAR(5))
      SET @cOutField07 = CAST (@nTotalQty AS NVARCHAR(5)) -- QTY
      SET @cOutField08 = @cSuggID 
      SET @cOutField09 = ''

      -- Disable QTY field
      --SET @cFieldAttr07 = CASE WHEN @nTotalQty = '1' THEN 'O' ELSE '' END -- QTY

      EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU

      -- Go to SKU QTY screen
      SET @nScn = 5292
      SET @nStep = @nStep - 3
   END

   ELSE IF @cFromStep = '7'
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cSuggLOC
      SET @cOutField02 = '' -- LOC

      -- Go to confirm LOC screen
      SET @nScn = 5296
      SET @nStep = @nStep + 1
   END

   GOTO Quit

   Step_6_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' --Option
   END
END
GOTO Quit


/********************************************************************************
Scn = 5296. Confirm LOC
   Sugg LOC (field01)
   LOC      (filed02, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cActLOC NVARCHAR(10)

      -- Screen mapping
      SET @cActLOC = @cInField02

      -- Validate blank
      IF @cActLOC = ''
      BEGIN
         IF @cAllowSkipLOC = '1'
         BEGIN
            -- Prepare skip LOC screen var
            SET @cOutField01 = ''

            -- Remember step
            SET @cFromStep = @nStep

            -- Go to skip LOC screen
            SET @nScn = 5295
            SET @nStep = @nStep - 1

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 130581
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
            GOTO Step_7_Fail
         END
      END

      -- Validate option
      IF @cActLOC <> @cSuggLOC
      BEGIN
         SET @nErrNo = 130582
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
         GOTO Step_7_Fail
      END

      -- Prepare SKU QTY screen var
      SET @cOutField01 = @cSuggLOC
      SET @cOutField02 = @cSuggSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
      SET @cOutField05 = '' -- SKU/UPC
      SET @cOutField06 = CAST (@nSuggQTY AS NVARCHAR(5))
      SET @cOutField07 = CAST (@nTotalQty AS NVARCHAR(5)) -- QTY
      SET @cOutField08 = @cSuggID 
      SET @cOutField09 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU

      -- Disable QTY field
      --SET @cFieldAttr07 = CASE WHEN @nTotalQty = '1' THEN 'O' ELSE '' END

      -- Go to SKU QTY screen
      SET @nScn = 5292
      SET @nStep = @nStep - 4
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '957ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_957ExtScnEntry]
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPickSlipNo, @cPickZone, @cDropID, @cSuggLOC, @cSuggID, @cSuggSKU, @nSuggQTY, @cOption, @cLottableCode,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cBarcode,@nAction,
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_7_Fail
         END
      END

      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' --PickZone
      SET @cOutField03 = '' --DropID

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone

      -- Go to prev screen
      SET @nScn = 5291
      SET @nStep = @nStep - 5
   END

   IF @cExtScnSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
   BEGIN
      SET @nAction = 0
      GOTO Step_99
   END

   GOTO Quit

   Step_7_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField02 = '' --LOC
   END
END
GOTO Quit

--JHU151
Step_99:
BEGIN
   IF @cExtScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
      BEGIN
         DECLARE @nOriginalScn INT = @nScn

         DELETE FROM @tExtScnData
         INSERT INTO @tExtScnData (Variable, Value) VALUES    
         ('@nMenu',        CONVERT(Nvarchar(20),@nMenu)),
         ('@cUserName',    @cUserName),
         ('@cSuggSKU',     @cSuggSKU),
         ('@cDropID',     @cDropID),
         ('@cPickSlipNo', @cPickSlipNo)
         EXECUTE [RDT].[rdt_ExtScnEntry] 
         @cExtScnSP, 
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

         IF @cExtScnSP = 'rdt_957ExtScn02' AND @nOriginalScn = 6388 AND @nInputKey = 1
         BEGIN
            IF ISNULL(@cUDF01, '') = 'SWAPUCC' AND ISNULL(@cUDF02, '') <> ''
            BEGIN
               SET @cDropID = @cUDF02
            END
         END
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
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,

      V_LoadKey      = @cLoadKey,
      V_OrderKey     = @cOrderKey,
      V_PickSlipNo   = @cPickSlipNo,
      V_Zone         = @cPickZone,
      V_LOC          = @cSuggLOC,
      V_SKU          = @cSuggSKU,
      V_SKUDescr     = @cSKUDescr,
      V_QTY          = @nSuggQTY,
      V_ID           = @cSuggID,


      V_String1      = @cZone,
      V_String2      = @cSKUValidated,
      V_String4      = @cDropID,
      V_String5      = @cFromStep,

      V_String21     = @cExtendedValidateSP,
      V_String22     = @cExtendedUpdateSP,
      V_String23     = @cExtendedInfoSP,
      V_String24     = @cExtendedInfo,
      V_String25     = @cDecodeSP,
      -- V_String26  = @nTotalQtySP,
      V_String27     = @cDefaultQTY,
      V_String28     = @cAllowSkipLOC,
      V_String29     = @cConfirmLOC,
      --V_String30   = @nTotalQty,
      V_String31     = @cPickConfirmStatus,
      V_String32     = @cAutoScanOut,
      V_String33     = @cExtScnSP,
      
      V_Integer1     = @nActQTY,
      V_Integer2     = @nTotalQty,
      

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