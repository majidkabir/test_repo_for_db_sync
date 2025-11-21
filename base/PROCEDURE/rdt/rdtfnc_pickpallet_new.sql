SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_PickPallet_NEW                                     */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-06-14   1.0  Chermaine  WMS-17140 Created (dup rdtfnc_Pick)           */
/* 2023-05-25   1.1  Ung        WMS-22370 Clean up source                     */
/* 2023-09-27   1.2  Ung        WMS-23706 Add DecodeSP = 1                    */
/* 2024-02-09   1.3  YeeKung    UWP-14600 Fix the variable problem (yeekung01)*/
/* 2024-04-11   1.4  Ung        WMS-25227 Add SuggestToLOCSP, OverrideToLOC   */
/* 2024-05-21   1.5  Dennis     FCR-336 Check Digit                           */
/* 2024-05-28   1.6  Ung        UWP-19459 Fix suggested ID sequence           */
/* 2024-08-26   1.7  LJQ006     FCR-735 Add new screen of short pick option   */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PickPallet_NEW] (
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
   @cOption        NVARCHAR( 1),
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX),
   @cBarcode       NVARCHAR( 60),
   @nMorePage      INT

-- RDT.RDTMobRec variables
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @nMenu         INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),

   @cPickSlipNo   NVARCHAR( 10),
   @cOrderKey     NVARCHAR( 10),
   @cLoadKey      NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @cSKUDescr     NVARCHAR( 60),
   @cPUOM         NVARCHAR( 1),
   @nPUOM_Div     INT,
   @nTaskQTY      INT,
   @nPTaskQTY     INT,
   @nMTaskQTY     INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,

   @cSuggLOC      NVARCHAR( 10),  
   @cSuggID       NVARCHAR( 18),  
   @cLottableCode NVARCHAR( 20),
   @cPUOM_Desc    NVARCHAR( 5),
   @cMUOM_Desc    NVARCHAR( 5),
   @cToLOC        NVARCHAR( 10),
   @cZone         NVARCHAR( 18),
   @cSuggToLOC    NVARCHAR( 10), 
   @cCheckDigitLOC NVARCHAR( 20),

   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cAutoScanIn         NVARCHAR( 1),
   @cSuggestLOC         NVARCHAR( 1),   
   @cDecodeSP           NVARCHAR( 20),
   @cSwapIDSP           NVARCHAR( 20),
   @cDefaultToLOC       NVARCHAR( 10),
   @cMoveQTYAlloc       NVARCHAR( 1), 
   @cMoveQTYPick        NVARCHAR( 1), 
   @cVerifyPickZone     NVARCHAR( 1),
   @cSuggestToLOCSP     NVARCHAR( 20),
   @cOverrideToLOC      NVARCHAR( 20),
   @cLOCCheckDigitSP    NVARCHAR( 20),
   @cShortOption        NVARCHAR( 1),

   @cExtScnSP           NVARCHAR( 20),
   @nAction             INT,
   @nAfterScn           INT,
   @nAfterStep          INT,
   @tExtScnData			VariableTable,
   
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

   @cPickSlipNo      = V_PickSlipNo,
   @cLoadKey         = V_LoadKey,
   @cOrderKey        = V_OrderKey,
   @cPickZone        = V_Zone,
   @cLOC             = V_LOC,
   @cID              = V_ID,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cPUOM            = V_UOM,
   @nPUOM_Div        = V_PUOM_Div, 
   @nTaskQTY         = V_TaskQTY,
   @nPTaskQTY        = V_PTaskQTY,
   @nMTaskQTY        = V_MTaskQTY,
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

   @cSuggLOC         = V_String1,
   @cSuggID          = V_String2,
   @cLottableCode    = V_String3,
   @cPUOM_Desc       = V_String4,
   @cMUOM_Desc       = V_String5,
   @cToLOC           = V_String6,
   @cZone            = V_String7,
   @cSuggToLOC       = V_String8,
   
   @cExtendedInfo       = V_String21,
   @cExtendedInfoSP     = V_String22,
   @cExtendedValidateSP = V_String23,
   @cExtendedUpdateSP   = V_String24,
   @cAutoScanIn         = V_String25,
   @cSuggestLOC         = V_String26,
   @cDecodeSP           = V_String27,
   @cSwapIDSP           = V_String28,
   @cDefaultToLOC       = V_String29,
   @cMoveQTYAlloc       = V_String30,
   @cMoveQTYPick        = V_String31,
   @cVerifyPickZone     = V_string32,
   @cSuggestToLOCSP     = V_string33,
   @cOverrideToLOC      = V_string34,
   @cLOCCheckDigitSP    = V_string35,

   @cExtScnSP           = V_string37,
   
   @cBarcode            = V_String41,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01  = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02  = FieldAttr02,
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15  = FieldAttr15

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_PickSlipNo       INT,  @nScn_PickSlipNo     INT,
   @nStep_LOC              INT,  @nScn_LOC            INT,
   @nStep_ID               INT,  @nScn_ID             INT,
   @nStep_SkipTask         INT,  @nScn_SkipTask       INT,
   @nStep_ToLOC            INT,  @nScn_ToLOC          INT,
   @nStep_ExtScn           INT,  @nScn_ExtScn         INT

SELECT
   @nStep_PickSlipNo       = 1,  @nScn_PickSlipNo     = 6260,
   @nStep_LOC              = 2,  @nScn_LOC            = 6261,
   @nStep_ID               = 3,  @nScn_ID             = 6262,
   @nStep_SkipTask         = 4,  @nScn_SkipTask       = 6263,
   @nStep_ToLOC            = 5,  @nScn_ToLOC          = 6264,
   @nStep_ExtScn           = 99, @nScn_ExtScn         = 6419

IF @nFunc = 1864 
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 1864 
   IF @nStep = 1  GOTO Step_PickSlipNo       -- Scn = 5910 PickSlipNo
   IF @nStep = 2  GOTO Step_LOC              -- Scn = 5911 PickZone, LOC
   IF @nStep = 3  GOTO Step_ID               -- Scn = 5912 ID
   IF @nStep = 4  GOTO Step_SkipTask         -- Scn = 5913 Skip Current Task?
   IF @nStep = 5  GOTO Step_ToLOC            -- Scn = 5914 TO LOC
   IF @nStep = 99  GOTO Step_ExtScn           -- Scn = 6419 ExtScn
END
RETURN -- Do nothing if incorrect step


/******************************************************************************
Step_Start. Func = 1864 
******************************************************************************/
Step_Start:
BEGIN
   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Storer configure
   SET @cAutoScanIn = rdt.rdtGetConfig( @nFunc, 'AutoScanIn', @cStorerKey)
   SET @cLOCCheckDigitSP = rdt.rdtGetConfig(@nFunc, 'LOCCheckDigitSP', @cStorerKey)
   SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cOverrideToLOC = rdt.RDTGetConfig( @nFunc, 'OverrideToLOC', @cStorerKey)
   SET @cSuggestLOC = rdt.RDTGetConfig( @nFunc, 'SuggestLOC', @cStorerKey)
   SET @cVerifyPickZone = rdt.RDTGetConfig( @nFunc, 'verifypickzone', @cStorerKey)
      
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
   IF @cDefaultToLOC = '0'
      SET @cDefaultToLOC = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cSuggestToLOCSP = rdt.rdtGetConfig( @nFunc, 'SuggestToLOCSP', @cStorerKey)
   IF @cSuggestToLOCSP = '0'
      SET @cSuggestToLOCSP = ''
   SET @cSwapIDSP = rdt.rdtGetConfig( @nFunc, 'SwapIDSP', @cStorerKey)
   IF @cSwapIDSP = '0'
      SET @cSwapIDSP = ''
   SET @cExtScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtScnSP = '0'
   BEGIN
      SET @cExtScnSP = ''
   END

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
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


/******************************************************************************
Scn = 5910. PickSlipNo screen
   PSNO    (field01, input)
******************************************************************************/
Step_PickSlipNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01

      -- Check blank
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 201651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNO required
         GOTO Quit
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

      -- Validate pickslipno
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 201652
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
            SET @nErrNo = 201653
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
            SET @nErrNo = 201654
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
            SET @nErrNo = 201655
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderShipped
            GOTO PickSlipNo_Fail
         END

         -- Check storer
         IF @cChkStorerKey <> @cStorerKey
         BEGIN
            SET @nErrNo = 201656
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
            SET @nErrNo = 201657
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
            SET @nErrNo = 201658
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
               VALUES (@cPickSlipNo, GETDATE(), SUSER_SNAME())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 201659
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
                  SET @nErrNo = 201660
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                  GOTO PickSlipNo_Fail
               END
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 201661
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS not scan in
            GOTO PickSlipNo_Fail
         END
      END

      -- Validate pickslip already scan out
      IF @dScanOutDate IS NOT NULL
      BEGIN
         SET @nErrNo = 201662
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS scanned out
         GOTO PickSlipNo_Fail
      END

      -- Get next LOC
      SET @cLoc = ''
      SET @cSuggLOC = ''
      SET @cPickZone = ''
      IF @cSuggestLOC = '1'
      BEGIN
         EXEC rdt.rdt_PickPallet_SuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cPickSlipNo,
            @cPickZone, 
            @cLOC,
            @cSuggLOC OUTPUT,
            @nErrNo   OUTPUT,
            @cErrMsg  OUTPUT
         IF @nErrNo <> 0 AND
            @nErrNo <> -1
            GOTO PickSlipNo_Fail
      END

      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = @cSuggLOC
      SET @cOutField04 = '' -- LOC
      
      IF @cVerifyPickZone = '1'
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
      
      -- Go to LOC screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out
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

   PickSlipNo_Fail:
   BEGIN
      SET @cOutField01 = '' -- PSNO
   END
END
GOTO Quit


/******************************************************************************
Scn 2 = 5911. LOC screen
   PSNO     (field01)
   PICKZONE (field02, input)
   Sugg LOC (field03)
   LOC      (field04, input)
******************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickZone = @cInField02 -- PickZone
      SET @cLOC = @cInField04 -- LOC
      SET @cCheckDigitLOC = @cInField04 -- LOC

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
               SET @nErrNo = 201663
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
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
               SET @nErrNo = 201664
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
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
               SET @nErrNo = 201665
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
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
               SET @nErrNo = 201666
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Zone NotInPSNO
               GOTO PickZone_Fail
            END
         END
      END
      SET @cOutField02 = @cPickZone

      -- Check blank
      IF @cLOC = ''
      BEGIN
         IF @cSuggestLOC = '1'
         BEGIN
            EXEC rdt.rdt_PickPallet_SuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPickSlipNo,
               @cPickZone, 
               @cSuggLOC,
               @cSuggLOC OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT
            IF @nErrNo <> 0 AND
               @nErrNo <> -1
               GOTO Quit

            EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
            -- Remain in current screen
            SET @cOutField03 = @cSuggLOC
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 201667
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC needed
            GOTO LOC_Fail
         END
      END

      -- Check LOC check digit
      IF @cLOCCheckDigitSP = '1'
      BEGIN
         EXEC rdt.rdt_LOCLookUp_CheckDigit @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cCheckDigitLOC    OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO LOC_Fail
            
         SET @cLOC = @cCheckDigitLOC
      END
      
      -- Get LOC info
      DECLARE @cChkFacility NVARCHAR( 5)
      DECLARE @cChkPickZone NVARCHAR( 10)
      SELECT 
         @cChkFacility = Facility, 
         @cChkPickZone = PickZone
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      -- Check LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 201668
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO LOC_Fail
      END

      -- Check facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 201669
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO LOC_Fail
      END
      
      -- Check PickZone
      IF @cPickZone <> '' AND @cChkPickZone <> @cPickZone
      BEGIN
         SET @nErrNo = 201670
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff PickZone
         GOTO LOC_Fail
      END
      
      -- Check if not allow override LOC
      IF @cSuggLOC <> '' AND @cSuggestLOC = '1'
      BEGIN
         IF @cLOC <> @cSuggLOC
         BEGIN
            SET @nErrNo = 201671
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
            GOTO LOC_Fail
         END
      END

      -- Get 1st task in current LOC
      SELECT @cID = '', @cSuggID = '', @cSKU = '', @nTaskQTY = 0, 
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,    
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',    
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL   

      -- Get task
      EXEC rdt.rdt_PickPallet_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPUOM, 4, @cPickSlipNo, @cPickZone, @cLOC, @cID, 
         @cSuggID      OUTPUT, @cSKU         OUTPUT, @nTaskQTY     OUTPUT,
         @cLottable01  OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT,
         @cLottable06  OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT,
         @cLottable11  OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT,
         @cLottableCode OUTPUT,
         @cSKUDescr    OUTPUT,
         @cMUOM_Desc   OUTPUT,
         @cPUOM_Desc   OUTPUT,
         @nPUOM_Div    OUTPUT,
         @nErrNo       OUTPUT,
         @cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO LOC_Fail

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
         SET @nPTaskQTY = 0
         SET @nMTaskQTY = @nTaskQTY
      END
      ELSE
      BEGIN
         SET @nPTaskQTY = @nTaskQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMTaskQTY = @nTaskQTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cSuggID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))
      SET @cOutField10 = @cPUOM_Desc
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CASE WHEN @nPTaskQTY = 0 THEN '' ELSE CAST( @nPTaskQTY AS NVARCHAR( 5)) END
      SET @cOutField13 = CAST( @nMTaskQTY AS NVARCHAR( 5))
      SET @cOutField14 = '' -- ID
      SET @cOutField15 = '' -- ExtendedInfo

      -- Goto ID screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Scan out        
      SET @nErrNo = 0        
      EXEC rdt.rdt_PickPallet_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey        
         ,@cPickSlipNo        
         ,@nErrNo       OUTPUT        
         ,@cErrMsg      OUTPUT        
      IF @nErrNo <> 0        
         GOTO Quit   
      
      -- Prepare prev screen var
      SET @cOutField01 = '' -- PSNO

      -- Go to prev screen
      SET @nScn = @nScn_PickSlipNo
      SET @nStep = @nStep_PickSlipNo
   END

   -- Extended Info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) + 
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' + 
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' + 
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' + 
            ' @nTaskQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
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
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, 
            @nFunc, @cLangCode, @nStep_LOC, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cID, @cSKU, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            @nTaskQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         IF @cExtendedInfo <> ''
            IF @nStep = @nStep_ID
               SET @cOutField15 = @cExtendedInfo
      END
   END
   GOTO Quit

   PickZone_Fail:
   BEGIN
      SET @cPickZone = ''
      SET @cOutField02 = '' -- PickZone
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZOne
      GOTO Quit
   END

   LOC_Fail:
   BEGIN
      SET @cOutField04 = '' -- LOC
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- PickZOne
   END
END
GOTO Quit


/******************************************************************************
Scn 3 = 5912. ID screen
   ID        (field01)
   SKU       (field02)
   DESCR     (field03, 04)
   LOTTABLE  (field05)
   LOTTABLE  (field06)
   LOTTABLE  (field07)
   LOTTABLE  (field08)
   UOM RATIO (field09)
   PUOM DESC (field10)
   MUOM DESC (field11)
   PQTY      (field12)
   MQTY      (field13)
   ID        (field14, input)
******************************************************************************/
Step_ID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField14 -- ID
      SET @cBarcode = @cInField14 
      
      -- Skip task
      IF @cID = ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option
         -- Go to skip task screen
         SET @nScn = @nScn_SkipTask
         SET @nStep = @nStep_SkipTask
         GOTO Step_ExtScn
      END 
 
      DECLARE @cUPC      NVARCHAR( 30),
         @cChkLottable01 NVARCHAR( 18), @cChkLottable02 NVARCHAR( 18), @cChkLottable03 NVARCHAR( 18), @dChkLottable04 DATETIME,      @dChkLottable05 DATETIME,
         @cChkLottable06 NVARCHAR( 30), @cChkLottable07 NVARCHAR( 30), @cChkLottable08 NVARCHAR( 30), @cChkLottable09 NVARCHAR( 30), @cChkLottable10 NVARCHAR( 30),
         @cChkLottable11 NVARCHAR( 30), @cChkLottable12 NVARCHAR( 30), @dChkLottable13 DATETIME,      @dChkLottable14 DATETIME,      @dChkLottable15 DATETIME

      SELECT @cUPC       = '', 
         @cChkLottable01 = '', @cChkLottable02 = '', @cChkLottable03 = '',    @dChkLottable04 = NULL,  @dChkLottable05 = NULL,
         @cChkLottable06 = '', @cChkLottable07 = '', @cChkLottable08 = '',    @cChkLottable09 = '',    @cChkLottable10 = '',
         @cChkLottable11 = '', @cChkLottable12 = '', @dChkLottable13 = NULL,  @dChkLottable14 = NULL,  @dChkLottable15 = NULL

      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID         = @cID            OUTPUT,
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
               @dLottable15 = @dChkLottable15 OUTPUT, 
               @cType = 'ID'
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cBarcode, @cPickSlipNo, ' +
                  ' @cLOC        OUTPUT, @cID         OUTPUT, @cUPC        OUTPUT, @nTaskQTY    OUTPUT, ' +
                  ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,' +
                  ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,' +
                  ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,' +
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT, '            +
                  '@nFunc           INT, '            +
                  '@cLangCode       NVARCHAR( 3), '   +
                  '@nStep           INT, '            +
                  '@nInputKey       INT, '            +
                  '@cFacility       NVARCHAR( 5),  '  +
                  '@cStorerKey      NVARCHAR( 15), '  +
                  '@cBarcode        NVARCHAR( 60), '  +
                  '@cPickSlipNo     NVARCHAR( 10), '  +
                  '@cLOC            NVARCHAR( 10)  OUTPUT, ' +
                  '@cID             NVARCHAR( 18)  OUTPUT, ' +
                  '@cUPC            NVARCHAR( 30)  OUTPUT, ' +
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
                  '@nErrNo          INT            OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, @cPickSlipNo,
                  @cLOC           OUTPUT, @cID            OUTPUT, @cUPC           OUTPUT, @nTaskQTY       OUTPUT, 
                  @cChkLottable01 OUTPUT, @cChkLottable02 OUTPUT, @cChkLottable03 OUTPUT, @dChkLottable04 OUTPUT, @dChkLottable05 OUTPUT,
                  @cChkLottable06 OUTPUT, @cChkLottable07 OUTPUT, @cChkLottable08 OUTPUT, @cChkLottable09 OUTPUT, @cChkLottable10 OUTPUT,
                  @cChkLottable11 OUTPUT, @cChkLottable12 OUTPUT, @dChkLottable13 OUTPUT, @dChkLottable14 OUTPUT, @dChkLottable15 OUTPUT,
                  @nErrNo         OUTPUT, @cErrMsg        OUTPUT

               IF @nErrNo <> 0
                  GOTO ID_Fail
            END
         END
      END
         
      -- Swap LOT and/or ID
      IF @cSuggID <> @cID
      BEGIN
         IF @cSwapIDSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSwapIDSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapIDSP) + 
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cPickSlipNo, @cPickZone, @cLOC, @cSuggID OUTPUT, @cID OUTPUT, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +        
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +        
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam = 
                  ' @nMobile     INT, ' + 
                  ' @nFunc       INT, ' + 
                  ' @cLangCode   NVARCHAR( 18), ' +
                  ' @nStep       INT, ' +
                  ' @nInputKey   INT, ' +
                  ' @cFacility   NVARCHAR( 5),  ' +
                  ' @cStorerKey  NVARCHAR( 15), ' +
                  ' @cPickSlipNo NVARCHAR( 10), ' +
                  ' @cPickZone   NVARCHAR( 10), ' + 
                  ' @cLOC        NVARCHAR( 10), ' +
                  ' @cSuggID     NVARCHAR( 18) OUTPUT, ' +
                  ' @cID         NVARCHAR( 18) OUTPUT, ' +
                  ' @cSKU        NVARCHAR( 20), ' +
                  ' @nQTY        INT,           ' + 
                  ' @cLottable01 NVARCHAR( 18), ' +        
                  ' @cLottable02 NVARCHAR( 18), ' +        
                  ' @cLottable03 NVARCHAR( 18), ' +        
                  ' @dLottable04 DATETIME,      ' +        
                  ' @dLottable05 DATETIME,      ' +        
                  ' @cLottable06 NVARCHAR( 30), ' +        
                  ' @cLottable07 NVARCHAR( 30), ' +        
                  ' @cLottable08 NVARCHAR( 30), ' +        
                  ' @cLottable09 NVARCHAR( 30), ' +        
                  ' @cLottable10 NVARCHAR( 30), ' +       
                  ' @cLottable11 NVARCHAR( 30), ' +        
                  ' @cLottable12 NVARCHAR( 30), ' +       
                  ' @dLottable13 DATETIME,      ' +        
                  ' @dLottable14 DATETIME,      ' +        
                  ' @dLottable15 DATETIME,      ' +
                  ' @nErrNo      INT           OUTPUT, ' +
                  ' @cErrMsg     NVARCHAR( 20) OUTPUT  '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cPickSlipNo, @cPickZone, @cLOC, @cSuggID OUTPUT, @cID OUTPUT, @cSKU, @nTaskQTY, 
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,     
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,     
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT 
               IF @nErrNo <> 0
                  GOTO ID_Fail
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 201672
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ID
            GOTO ID_Fail
         END
      END

      -- Check decoded SKU
      IF @cUPC <> ''
      BEGIN
         DECLARE @bSuccess INT
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
            SET @nErrNo = 201679
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO ID_Fail
         END

         -- Check barcode return multiple SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 201680
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO ID_Fail
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
            SET @nErrNo = 201681
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SKU
            GOTO ID_Fail
         END
      END

      -- Check lottables
      IF @cLottable01 <> '' AND @cChkLottable01 <> '' AND @cLottable01 <> @cChkLottable01 SET @nErrNo = 201682 ELSE
      IF @cLottable02 <> '' AND @cChkLottable02 <> '' AND @cLottable02 <> @cChkLottable02 SET @nErrNo = 201683 ELSE
      IF @cLottable03 <> '' AND @cChkLottable03 <> '' AND @cLottable03 <> @cChkLottable03 SET @nErrNo = 201684 ELSE
      IF (@dLottable04 <> 0 AND @dLottable04 IS NOT NULL) AND (@dChkLottable04 <> 0 AND @dChkLottable04 IS NOT NULL) AND @dLottable04 <> @dChkLottable04 SET @nErrNo = 201685 ELSE
      IF (@dLottable05 <> 0 AND @dLottable05 IS NOT NULL) AND (@dChkLottable05 <> 0 AND @dChkLottable05 IS NOT NULL) AND @dLottable05 <> @dChkLottable05 SET @nErrNo = 201686 ELSE
      IF @cLottable06 <> '' AND @cChkLottable06 <> '' AND @cLottable06 <> @cChkLottable06 SET @nErrNo = 201687 ELSE
      IF @cLottable07 <> '' AND @cChkLottable07 <> '' AND @cLottable07 <> @cChkLottable07 SET @nErrNo = 201688 ELSE
      IF @cLottable08 <> '' AND @cChkLottable08 <> '' AND @cLottable08 <> @cChkLottable08 SET @nErrNo = 201689 ELSE
      IF @cLottable09 <> '' AND @cChkLottable09 <> '' AND @cLottable09 <> @cChkLottable09 SET @nErrNo = 201690 ELSE
      IF @cLottable10 <> '' AND @cChkLottable10 <> '' AND @cLottable10 <> @cChkLottable10 SET @nErrNo = 201691 ELSE
      IF @cLottable11 <> '' AND @cChkLottable11 <> '' AND @cLottable11 <> @cChkLottable11 SET @nErrNo = 201692 ELSE
      IF @cLottable12 <> '' AND @cChkLottable12 <> '' AND @cLottable12 <> @cChkLottable12 SET @nErrNo = 201693 ELSE
      IF (@dLottable13 <> 0 AND @dLottable13 IS NOT NULL) AND (@dChkLottable13 <> 0 AND @dChkLottable13 IS NOT NULL) AND @dLottable13 <> @dChkLottable13 SET @nErrNo = 201694 ELSE
      IF (@dLottable14 <> 0 AND @dLottable14 IS NOT NULL) AND (@dChkLottable14 <> 0 AND @dChkLottable14 IS NOT NULL) AND @dLottable14 <> @dChkLottable14 SET @nErrNo = 201695 ELSE
      IF (@dLottable15 <> 0 AND @dLottable15 IS NOT NULL) AND (@dChkLottable15 <> 0 AND @dChkLottable15 IS NOT NULL) AND @dLottable15 <> @dChkLottable15 SET @nErrNo = 201696
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different L0X
         GOTO ID_Fail
      END

      -- Suggest TO LOC
      SET @cSuggToLOC = ''
      IF @cSuggestToLOCSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSuggestToLOCSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestToLOCSP) + 
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPickSlipNo, @cPickZone, @cLOC, @cID, @cSKU, @nTaskQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' + 
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' + 
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' + 
               ' @cSuggToLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam = 
               ' @nMobile       INT,           ' + 
               ' @nFunc         INT,           ' + 
               ' @cLangCode     NVARCHAR( 3),  ' + 
               ' @nStep         INT,           ' + 
               ' @nInputKey     INT,           ' + 
               ' @cFacility     NVARCHAR( 5),  ' + 
               ' @cStorerKey    NVARCHAR( 15), ' + 
               ' @cPickSlipNo   NVARCHAR( 10), ' + 
               ' @cPickZone     NVARCHAR( 10), ' + 
               ' @cLOC          NVARCHAR( 10), ' + 
               ' @cID           NVARCHAR( 18), ' + 
               ' @cSKU          NVARCHAR( 20), ' + 
               ' @nTaskQTY      INT,           ' + 
               ' @cLottable01   NVARCHAR( 18), ' + 
               ' @cLottable02   NVARCHAR( 18), ' + 
               ' @cLottable03   NVARCHAR( 18), ' + 
               ' @dLottable04   DATETIME,      ' + 
               ' @dLottable05   DATETIME,      ' + 
               ' @cLottable06   NVARCHAR( 30), ' + 
               ' @cLottable07   NVARCHAR( 30), ' + 
               ' @cLottable08   NVARCHAR( 30), ' + 
               ' @cLottable09   NVARCHAR( 30), ' + 
               ' @cLottable10   NVARCHAR( 30), ' + 
               ' @cLottable11   NVARCHAR( 30), ' + 
               ' @cLottable12   NVARCHAR( 30), ' + 
               ' @dLottable13   DATETIME,      ' + 
               ' @dLottable14   DATETIME,      ' + 
               ' @dLottable15   DATETIME,      ' + 
               ' @cSuggToLOC    NVARCHAR( 10) OUTPUT, ' + 
               ' @nErrNo        INT           OUTPUT, ' + 
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  ' 
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cPickSlipNo, @cPickZone, @cLOC, @cID, @cSKU, @nTaskQTY, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
               @cSuggToLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            IF @nErrNo <> 0
               GOTO Quit
         END
         ELSE
            SET @cSuggToLOC = @cSuggestToLOCSP
      END

      -- To LOC
      IF @cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1'
      BEGIN
         -- Go to TO LOC screen
         SET @nScn = @nScn_ToLOC
         SET @nStep = @nStep_ToLOC

         SET @cOutField01 = @cSuggToLOC 
         SET @cOutField02 = @cDefaultToLOC -- TO LOC
         GOTO Quit
      END

      -- Confirm
      EXECUTE rdt.rdt_PickPallet_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cPickSlipNo, @cPickZone, @cLOC, @cID, @cSKU, @nTaskQTY, @cToLOC, @cLottableCode, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
         @nErrNo OUTPUT, @cErrMsg OUTPUT 
      IF @nErrNo <> 0
         GOTO Quit

      -- Go to next screen
      EXEC rdt.rdt_PickPallet_GoToNextScreen @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, 
         @cPUOM, @cPickSlipNo, @cPickZone, @cLOC, @cID, 
         @cSuggLOC   OUTPUT,  @cSuggID     OUTPUT,  @cSKU         OUTPUT,    
         @nTaskQTY   OUTPUT,  @nPTaskQTY   OUTPUT,  @nMTaskQTY    OUTPUT,  @cLottableCode OUTPUT,
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
         @nStep      OUTPUT,  @nScn        OUTPUT,  @nErrNo       OUTPUT,  @cErrMsg       OUTPUT
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare LOC screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = @cSuggLOC
      SET @cOutField04 = '' -- LOC

      -- Go to prev screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit
   
   -- Extended Info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) + 
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' + 
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' + 
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' + 
            ' @nTaskQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
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
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, 
            @nFunc, @cLangCode, @nStep_ID, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cID, @cSKU, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            @nTaskQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         IF @cExtendedInfo <> ''
            IF @nStep = @nStep_ID
               SET @cOutField15 = @cExtendedInfo
      END
   END
   GOTO Quit

   ID_Fail:
   BEGIN
      SET @cOutField14 = '' -- ID
   END
END
GOTO Quit


/******************************************************************************
Scn = 5913. Skip Current Task?
******************************************************************************/
Step_SkipTask:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 201673
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need option
         GOTO SkipTask_Option_Fail
      END

      -- Validate option
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 201674
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO SkipTask_Option_Fail
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         -- Go to next screen
         EXEC rdt.rdt_PickPallet_GoToNextScreen @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, 
            @cPUOM, @cPickSlipNo, @cPickZone, @cLOC, @cID, 
            @cSuggLOC   OUTPUT,  @cSuggID     OUTPUT,  @cSKU         OUTPUT,    
            @nTaskQTY   OUTPUT,  @nPTaskQTY   OUTPUT,  @nMTaskQTY    OUTPUT,  @cLottableCode OUTPUT,
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
            @nStep      OUTPUT,  @nScn        OUTPUT,  @nErrNo       OUTPUT,  @cErrMsg       OUTPUT
         
         GOTO SkipTask_Option_Quit
      END
   END
   
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
   
   -- Prepare next screen var
   SET @cOutField01 = @cSuggID
   SET @cOutField02 = @cSKU
   SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 1, 20)  -- SKU desc 1
   SET @cOutField04 = rdt.rdtFormatString( @cSKUDescr, 21, 20) -- SKU desc 2
   SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))
   SET @cOutField10 = @cPUOM_Desc
   SET @cOutField11 = @cMUOM_Desc
   SET @cOutField12 = CASE WHEN @nPTaskQTY = 0 THEN '' ELSE CAST( @nPTaskQTY AS NVARCHAR( 5)) END
   SET @cOutField13 = CAST( @nMTaskQTY AS NVARCHAR( 5))
   SET @cOutField14 = '' -- ID
   SET @cOutField15 = '' -- ExtendedInfo

   -- Go to ID screen
   SET @nScn = @nScn_ID
   SET @nStep = @nStep_ID
   
   SkipTask_Option_Quit:

   -- Extended Info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) + 
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' + 
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' + 
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' + 
            ' @nTaskQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
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
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, 
            @nFunc, @cLangCode, @nStep_SkipTask, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cID, @cSKU, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            @nTaskQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         IF @cExtendedInfo <> ''
            IF @nStep = @nStep_ID
               SET @cOutField15 = @cExtendedInfo
      END
   END
   GOTO Quit

   SkipTask_Option_Fail:
   BEGIN
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/******************************************************************************
Scn = 5914. TO LOC screen
   TO LOC   (field01, input)
******************************************************************************/
Step_TOLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField02 -- TO LOC
      SET @cCheckDigitLOC = @cInField02

      -- Check blank
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 201675
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToLOC
         GOTO Quit
      END

      -- Check LOC check digit
      IF @cLOCCheckDigitSP = '1'
      BEGIN
         EXEC rdt.rdt_LOCLookUp_CheckDigit @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cCheckDigitLOC    OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
            
         SET @cToLOC = @cCheckDigitLOC
      END

      -- Suggested to LOC
      IF @cSuggToLOC <> '' AND @cSuggToLOC <> @cToLOC
      BEGIN
         -- Override To LOC
         IF @cOverrideToLOC <> '1'
         BEGIN
            SET @nErrNo = 201697
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
            GOTO Quit
         END
      END

      -- Get LOC info
      SET @cChkFacility = ''
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLOC

      -- Check LOC valid
      IF @cChkFacility = ''
      BEGIN
         SET @nErrNo = 201676
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 201677
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check same FromLOC, ToLOC
      IF @cLOC = @cToLOC
      BEGIN
         SET @nErrNo = 201678
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameFrom/ToLOC
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Confirm task
      EXECUTE rdt.rdt_PickPallet_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cPickSlipNo, @cPickZone, @cLOC, @cID, @cSKU, @nTaskQTY, @cToLOC, @cLottableCode, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
         @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Go to next screen
      EXEC rdt.rdt_PickPallet_GoToNextScreen @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, 
         @cPUOM, @cPickSlipNo, @cPickZone, @cLOC, @cID, 
         @cSuggLOC   OUTPUT,  @cSuggID     OUTPUT,  @cSKU         OUTPUT,    
         @nTaskQTY   OUTPUT,  @nPTaskQTY   OUTPUT,  @nMTaskQTY    OUTPUT,  @cLottableCode OUTPUT,
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
         @nStep      OUTPUT,  @nScn        OUTPUT,  @nErrNo       OUTPUT,  @cErrMsg       OUTPUT
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

      -- Prepare next screen var
      SET @cOutField01 = @cSuggID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))
      SET @cOutField10 = @cPUOM_Desc
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CASE WHEN @nPTaskQTY = 0 THEN '' ELSE CAST( @nPTaskQTY AS NVARCHAR( 5)) END
      SET @cOutField13 = CAST( @nMTaskQTY AS NVARCHAR( 5))
      SET @cOutField14 = '' -- ID
      SET @cOutField15 = '' -- ExtendedInfo

      -- Goto SKU screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END

   -- Extended Info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) + 
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' + 
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' + 
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' + 
            ' @nTaskQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
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
            '@cToLOC        NVARCHAR( 10), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, 
            @nFunc, @cLangCode, @nStep_TOLOC, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPickSlipNo, @cPickZone, @cSuggLOC, @cLOC, @cID, @cSKU, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, 
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
            @nTaskQTY, @cToLOC, @cOption, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         IF @cExtendedInfo <> ''
            IF @nStep = @nStep_ID
               SET @cOutField15 = @cExtendedInfo
      END
   END
   GOTO Quit
END

-- FCR-735 Ext Screen
Step_ExtScn:
BEGIN
   IF @cExtScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
      BEGIN
         DELETE FROM @tExtScnData

         INSERT INTO @tExtScnData (Variable, Value) VALUES
            ('@cPickSlipNo'  , @cPickSlipNo  ),               
            ('@cLOC'         , @cLOC         ),        
            ('@nTaskQTY'     , CAST(@nTaskQTY  AS NVARCHAR(20))),
            ('@nPTaskQTY'    , CAST(@nPTaskQTY AS NVARCHAR(20))),
            ('@nMTaskQTY'    , CAST(@nMTaskQTY AS NVARCHAR(20))),
            ('@cLottableCode', @cLottableCode),
            ('@cSKUDescr'    , @cSKUDescr    ),
            ('@cMUOM_Desc'   , @cMUOM_Desc   ),
            ('@cPUOM_Desc'   , @cPUOM_Desc   ),
            ('@nPUOM_Div'    , CAST(@nPUOM_Div AS NVARCHAR(20))),
            ('@cPickZone'    , @cPickZone    ),
            ('@cPUOM'        , @cPUOM        ),
            ('@cSuggLOC'     , @cSuggLOC     ),
            ('@cSuggID'      , @cSuggID      ),
            ('@cSKU'         , @cSKU         )

         SET @nAction = 0

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
         BEGIN
            GOTO Step_99_Fail
         END
      END
   END
   GOTO Quit
   Step_99_Fail:
   BEGIN
      GOTO Quit
   END
END


/******************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
******************************************************************************/
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

      V_LoadKey      = @cLoadKey,
      V_OrderKey     = @cOrderKey,
      V_PickSlipNo   = @cPickSlipNo,
      V_Zone         = @cPickZone,
      V_LOC          = @cLOC,
      V_ID           = @cID,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cPUOM,
      V_PUOM_Div     = @nPUOM_Div, 
      V_TaskQTY      = @nTaskQTY,
      V_MTaskQTY     = @nMTaskQTY,
      V_PTaskQTY     = @nPTaskQTY,
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

      V_String1      = @cSuggLOC,
      V_String2      = @cSuggID,
      V_String3      = @cLottableCode,
      V_String4      = @cPUOM_Desc,
      V_String5      = @cMUOM_Desc,
      V_String6      = @cToLOC,
      V_String7      = @cZone,
      V_String8      = @cSuggToLOC,

      V_String21     = @cExtendedInfo,
      V_String22     = @cExtendedInfoSP,
      V_String23     = @cExtendedValidateSP,
      V_String24     = @cExtendedUpdateSP,
      V_String25     = @cAutoScanIn,
      V_String26     = @cSuggestLOC,
      V_String27     = @cDecodeSP,
      V_String28     = @cSwapIDSP,
      V_String29     = @cDefaultToLOC,
      V_String30     = @cMoveQTYAlloc,
      V_String31     = @cMoveQTYPick,
      V_String32     = @cVerifyPickZone,
      V_string33     = @cSuggestToLOCSP,
      V_string34     = @cOverrideToLOC,
      V_string35     = @cLOCCheckDigitSP,

      V_string37     = @cExtScnSP,
   
      V_String41     = @cBarcode,

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO