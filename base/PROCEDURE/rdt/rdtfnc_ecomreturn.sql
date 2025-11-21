SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************************/
/* Store procedure: rdtfnc_EcomReturn                                                              */
/* Copyright      : LFLogistics                                                                    */
/*                                                                                                 */
/* Purpose: Ecomm Trade Return                                                                     */
/*                                                                                                 */
/* Modifications log:                                                                              */
/*                                                                                                 */
/* Date         Rev  Author      Purposes                                                          */
/* 2019-11-14   1.0  James       WMS-10952. Created                                                */
/* 2020-02-27   1.1  YeeKung     INC1056974 Fix @cPreToIDLOC  (yeekung01)                          */
/* 2020-03-18   1.2  YeeKung     WMS-12465 Fix the ecom return default loc                         */
/*                               (yeekung02)                                                       */
/* 2020-07-20   1.3  YeeKung     WMS-14241 Add default cursor(yeekung03)                           */
/* 2020-06-17   1.4  Ung         WMS-13555 clean up source                                         */
/*                               Revise ReceiptConfirm_SP                                          */
/*                               Revise Finalize ASN screen                                        */
/*                               Revise CaptureReceiptInfoSP                                       */
/*                               Remove POKey, StorerGroup                                         */
/*                               Change PreToIDScreenSP to PreToIDLOC                              */
/*                               Change ReturnDefaultToLOC to DefaultToLOC                         */
/*                               Add ArriveDate                                                    */
/*                               Add RefNo multi columns lookup                                    */
/*                               Add RefNoSKULookup                                                */
/*                               Add ExtendedPutawaySP                                             */
/*                               Add AllowOverReceive                                              */
/*                               Add FinalizeASN. Auto option                                      */
/*                               Add AutoReceiveNext                                               */
/* 2020-08-26   1.5  Ung         WMS-14617 Add SKULabel                                            */
/*                               Remove save tran for finalize ASN due to some                     */
/*                               Exceed logic involve cross DB trans                               */
/*                               Default ConditionCode = OK                                        */
/* 2020-09-30   1.6  Ung         WMS-14691 Add DisableToIDField                                    */
/*                               Add serial no                                                     */
/* 2021-01-04   1.7  Ung         WMS-15939 Add DispStyleColorSize                                  */
/* 2021-03-11   1.8  Ung         WMS-16521 Fix RCV QTY not refresh on 1st QTY                      */
/* 2021-03-26   1.9  James       WMS-16614 Add StdEventLog to step1 (james01)                      */
/* 2021-03-26   2.0  James       WMS-16506 Add check ASNStatus (james02)                           */
/* 2021-04-15   2.1  James       WMS-16668 Add RefNo param to finalize                             */
/*                               sub sp (james03)                                                  */
/*                               Add ExtendedInfoSP to step sku                                    */
/* 2021-05-06   2.2  James       WMS-16735 Add capture receiptdetail info                          */
/*                               screen (james04)                                                  */
/* 2021-05-24   2.3  James       Add AfterStep param into ExtInfoSP (james05)                      */
/*                               Remove StdEventLog at step 1                                      */
/* 2021-01-12   2.4  Ung         WMS-15663 Add ConditionCode, SubReasonCode                        */
/* 2021-07-08   2.5  Ung         WMS-17458 Fix ConditionCode, SubReasonCode                        */
/*                               Add ExtendedValidateSP at cond reason screen                      */
/* 2022-08-19   2.6  YeeKung     JSM-88504 Fix ExtInfoSP AfterStep (yeekung01)                     */
/* 2022-10-20   2.7  KokHoe      JSM-103402 Initialize Condition Code (kh01)                       */ 
/* 2022-09-23   2.8  YeeKung     WMS-20820 Extended refno length (yeekung02)                       */
/* 2023-04-13   2.9  Ung         WMS-22302 Allow ExtInfoSP at SKU to lottables                     */
/*                               Fix ExtendedInfoSP AfterStep                                      */
/* 2023-03-24   3.0  Ung         WMS-22017 Add RefNoSKULookup to FinalizeASN screen                */
/* 2023-09-07   3.1  YeeKung     WMS-23459 Remove goto quit on sku screen (yeekung02)              */
/***************************************************************************************************/
CREATE   PROC [RDT].[rdtfnc_EcomReturn](
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @b_success           INT,
   @n_err               INT,
   @c_errmsg            NVARCHAR( 250),
   @cChkFacility        NVARCHAR( 5),
   @cChkLOC             NVARCHAR( 10),
   @nVariance           INT,
   @nMorePage           INT,
   @nTranCount          INT,
   @cBarcode            NVARCHAR( 60),
   @cAuthority          NVARCHAR( 1),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @cSerialNo           NVARCHAR( 30),
   @nSerialQTY          INT,
   @nBulkSNO            INT,
   @nBulkSNOQTY         INT,
   @nMoreSNO            INT,
   @tCaptureVar         VARIABLETABLE,
   @tExtValidVar        VARIABLETABLE,
   @tExtUpdateVar       VARIABLETABLE,
   @tConfirmVar         VARIABLETABLE,
   @tSKULabel           VARIABLETABLE,
   @tExtInfoVar         VARIABLETABLE

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cFacility           NVARCHAR( 5),
   @cPaperPrinter       NVARCHAR( 10),
   @cLabelPrinter       NVARCHAR( 10),

   @cStorerKey          NVARCHAR( 15),
   @cUOM                NVARCHAR( 10),
   @cReceiptKey         NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cSKU                NVARCHAR( 60),
   @cSKUDesc            NVARCHAR( 60),
   @nQTY                INT,
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
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

   @nTotalQTYExp        INT,
   @nTotalQTYRcv        INT,
   @nBalQTY             INT,
   @nFromScn            INT,

   @dArriveDate         DATETIME,

   @cRefNo              NVARCHAR( 60),
   @cLottableCode       NVARCHAR( 30),
   @cSuggID             NVARCHAR( 18),
   @cSuggLOC            NVARCHAR( 10),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cOption             NVARCHAR( 1),
   @cConditionCode      NVARCHAR( 10),
   @cSubreasonCode      NVARCHAR( 10),

   @cCaptureConditionReason NVARCHAR( 10),
   @cDispStyleColorSize    NVARCHAR( 1),
   @cSerialNoCapture       NVARCHAR( 1),
   @cDisableToIDField      NVARCHAR( 1),
   @cDefaultToLOC          NVARCHAR( 20),
   @cDecodeSKUSP           NVARCHAR( 20),
   @cVerifySKU             NVARCHAR( 1),
   @cExtendedPutawaySP     NVARCHAR( 20),
   @cOverrideSuggestID     NVARCHAR( 1),
   @cOverrideSuggestLOC    NVARCHAR( 1),
   @cDefaultIDAsSuggID     NVARCHAR( 1),
   @cDefaultLOCAsSuggLOC   NVARCHAR( 1),
   @cExtendedInfoSP        NVARCHAR( 20),
   @cExtendedInfo          NVARCHAR( 20),
   @cExtendedValidateSP    NVARCHAR( 20),
   @cExtendedUpdateSP      NVARCHAR( 20),
   @cMultiSKUBarcode       NVARCHAR( 1),
   @cCheckSKUInASN         NVARCHAR( 1),
   @cCaptureReceiptInfoSP  NVARCHAR( 20),
   @cRefNoSKULookup        NVARCHAR( 1),
   @cFinalizeASN           NVARCHAR( 1),
   @cPreToIDLOC            NVARCHAR( 1),
   @cAllowOverReceive      NVARCHAR( 1),
   @cAutoReceiveNext       NVARCHAR( 1),
   @cSKULabel              NVARCHAR( 10), 

   @cData1                 NVARCHAR( 60),
   @cData2                 NVARCHAR( 60),
   @cData3                 NVARCHAR( 60),
   @cData4                 NVARCHAR( 60),
   @cData5                 NVARCHAR( 60),
   @cASNStatus             NVARCHAR( 10),

   @cCaptureReceiptDetailInfoSP  NVARCHAR( 20),
   @cDtlData1              NVARCHAR( 60),
   @cDtlData2              NVARCHAR( 60),
   @cDtlData3              NVARCHAR( 60),
   @cDtlData4              NVARCHAR( 60),
   @cDtlData5              NVARCHAR( 60),


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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,

   @cFacility     = Facility,
   @cPaperPrinter = Printer_Paper,
   @cLabelPrinter = Printer,

   @cStorerKey    = V_StorerKey,
   @cUOM          = V_UOM,
   @cReceiptKey   = V_ReceiptKey,
   @cLOC          = V_LOC,
   @cID           = V_ID,
   @cSKU          = V_SKU,
   @cSKUDesc      = V_SKUDescr,
   @nQTY          = V_QTY,
   @cLottable01   = V_Lottable01,
   @cLottable02   = V_Lottable02,
   @cLottable03   = V_Lottable03,
   @dLottable04   = V_Lottable04,
   @dLottable05   = V_Lottable05,
   @cLottable06   = V_Lottable06,
   @cLottable07   = V_Lottable07,
   @cLottable08   = V_Lottable08,
   @cLottable09   = V_Lottable09,
   @cLottable10   = V_Lottable10,
   @cLottable11   = V_Lottable11,
   @cLottable12   = V_Lottable12,
   @dLottable13   = V_Lottable13,
   @dLottable14   = V_Lottable14,
   @dLottable15   = V_Lottable15,

   @nTotalQTYExp  = V_Integer1,
   @nTotalQTYRcv  = V_Integer2,
   @nBalQTY       = V_Integer3,
   @nFromScn      = V_Integer4,

   @dArriveDate   = V_DateTime1,

   @cRefNo                 = V_String1,
   @cLottableCode          = V_String2,
   @cSuggID                = V_String3,
   @cSuggLOC               = V_String4,
   @cReceiptLineNumber     = V_String5,
   @cOption                = V_String7,
   @cCaptureReceiptDetailInfoSP = V_String8,
   @cConditionCode         = V_String9,
   @cSubreasonCode         = V_String10,

   @cCaptureConditionReason = V_String16,
   @cDispStyleColorSize    = V_String17,
   @cSerialNoCapture       = V_String18,
   @cDisableToIDField      = V_String19,
   @cCaptureReceiptInfoSP  = V_String20,
   @cDefaultToLOC          = V_String21,
   @cDecodeSKUSP           = V_String22,
   @cVerifySKU             = V_String23,
   @cExtendedPutawaySP     = V_String24,
   @cOverrideSuggestID     = V_String25,
   @cOverrideSuggestLOC    = V_String26,
   @cDefaultIDAsSuggID     = V_String27,
   @cDefaultLOCAsSuggLOC   = V_String28,
   @cExtendedInfoSP        = V_String29,
   @cExtendedInfo          = V_String30,
   @cExtendedValidateSP    = V_String31,
   @cExtendedUpdateSP      = V_String32,
   @cMultiSKUBarcode       = V_String33,
   @cCheckSKUInASN         = V_String34,
   @cRefNoSKULookup        = V_String35,
   @cFinalizeASN           = V_String36,
   @cPreToIDLOC            = V_String37,
   @cAllowOverReceive      = V_String38,
   @cAutoReceiveNext       = V_String39,
   @cSKULabel              = V_String40,

   @cData1                 = V_String41,
   @cData2                 = V_String42,
   @cData3                 = V_String43,
   @cData4                 = V_String44,
   @cData5                 = V_String45,

   @cDtlData1              = V_String46,
   @cDtlData2              = V_String47,
   @cDtlData3              = V_String48,
   @cDtlData4              = V_String49,
   @cDtlData5              = V_String50,

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_ASNRefNo         INT,  @nScn_ASNRefNo       INT,
   @nStep_CaptureData      INT,  @nScn_CaptureData    INT,
   @nStep_SKU              INT,  @nScn_SKU            INT,
   @nStep_Lottables        INT,  @nScn_Lottables      INT,
   @nStep_IDLOC            INT,  @nScn_IDLOC          INT,
   @nStep_VerifySKU        INT,  @nScn_VerifySKU      INT,
   @nStep_MultiSKU         INT,  @nScn_MultiSKU       INT,
   @nStep_FinalizeASN      INT,  @nScn_FinalizeASN    INT,
   @nStep_PreIDLOC         INT,  @nScn_PreIDLOC       INT,
   @nStep_SerialNo         INT,  @nScn_SerialNo       INT,
   @nStep_CondReason       INT,  @nScn_CondReason     INT,
   @nStep_CaptureDtlData   INT,  @nScn_CaptureDtlData INT

SELECT
   @nStep_ASNRefNo         = 1,  @nScn_ASNRefNo       = 5640,
   @nStep_CaptureData      = 2,  @nScn_CaptureData    = 5641,
   @nStep_SKU              = 3,  @nScn_SKU            = 5642,
   @nStep_Lottables        = 4,  @nScn_Lottables      = 3990,
   @nStep_IDLOC            = 5,  @nScn_IDLOC          = 5644,
   @nStep_VerifySKU        = 6,  @nScn_VerifySKU      = 3951,
   @nStep_MultiSKU         = 7,  @nScn_MultiSKU       = 3570,
   @nStep_FinalizeASN      = 8,  @nScn_FinalizeASN    = 5645,
   @nStep_PreIDLOC         = 9,  @nScn_PreIDLOC       = 5646,
   @nStep_SerialNo         = 10, @nScn_SerialNo       = 4831,
   @nStep_CondReason       = 11, @nScn_CondReason     = 5647,
   @nStep_CaptureDtlData   = 12, @nScn_CaptureDtlData = 5648

IF @nFunc = 638
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start            -- Menu. 607
   IF @nStep = 1  GOTO Step_ASNRefNo         -- Scn = 5640. ASN, RefNo
   IF @nStep = 2  GOTO Step_CaptureData      -- Scn = 5641. Capture data
   IF @nStep = 3  GOTO Step_SKU              -- Scn = 5642. SKU
   IF @nStep = 4  GOTO Step_Lottables        -- Scn = 3990. Lottable
   IF @nStep = 5  GOTO Step_IDLOC            -- Scn = 5644. ID, LOC
   IF @nStep = 6  GOTO Step_VerifySKU        -- Scn = 3951. Verify SKU
   IF @nStep = 7  GOTO Step_MultiSKU         -- Scn = 3570. Multi SKU
   IF @nStep = 8  GOTO Step_FinalizeASN      -- Scn = 5645. Finalize ASN?
   IF @nStep = 9  GOTO Step_PreIDLOC         -- Scn = 5646. Pre ID, LOC, ArriveDate
   IF @nStep = 10 GOTO Step_SerialNo         -- Scn = 4831. Serial no
   IF @nStep = 11 GOTO Step_CondReason  		 -- Scn = 5647. Condition, sub reason
   IF @nStep = 12 GOTO Step_CaptureDtlData   -- Scn = 5648. Capture receiptdetail data
END
RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 638
********************************************************************************/
Step_Start:
BEGIN
   -- Get storer config
   SET @cAllowOverReceive = rdt.RDTGetConfig( @nFunc, 'AllowOverReceive', @cStorerKey)
   SET @cAutoReceiveNext = rdt.RDTGetConfig( @nFunc, 'AutoReceiveNext', @cStorerKey)
   SET @cCheckSKUInASN = rdt.RDTGetConfig( @nFunc, 'CheckSKUInASN', @cStorerKey)
   SET @cDefaultIDAsSuggID = rdt.RDTGetConfig( @nFunc, 'DefaultIDAsSuggID', @cStorerKey)
   SET @cDefaultLOCAsSuggLOC = rdt.RDTGetConfig( @nFunc, 'DefaultLOCAsSuggLOC', @cStorerKey)
   SET @cDisableToIDField = rdt.RDTGetConfig( @nFunc, 'DisableToIDField', @cStorerKey)
   SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)
   SET @cFinalizeASN = rdt.RDTGetConfig( @nFunc, 'FinalizeASN', @cStorerKey)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
   SET @cOverrideSuggestID = rdt.RDTGetConfig( @nFunc, 'OverrideSuggestID', @cStorerKey)
   SET @cOverrideSuggestLOC = rdt.RDTGetConfig( @nFunc, 'OverrideSuggestLOC', @cStorerKey)
   SET @cPreToIDLOC = rdt.RDTGetConfig( @nFunc, 'PreToIDLOC', @cStorerKey)
   SET @cRefNoSKULookup = rdt.RDTGetConfig( @nFunc, 'RefNoSKULookup', @cStorerKey)
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)
   SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorerKey)

   SET @cCaptureReceiptInfoSP = rdt.RDTGetConfig( @nFunc, 'CaptureReceiptInfoSP', @cStorerKey)
   IF @cCaptureReceiptInfoSP = '0'
      SET @cCaptureReceiptInfoSP = ''
   SET @cCaptureConditionReason = rdt.RDTGetConfig( @nFunc, 'CaptureConditionReason', @cStorerKey)
   IF @cCaptureConditionReason = '0'
      SET @cCaptureConditionReason = ''
   SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
   IF @cDefaultToLOC = '0'
      SET @cDefaultToLOC = ''
   SET @cDecodeSKUSP = rdt.RDTGetConfig( @nFunc, 'DecodeSKUSP', @cStorerKey)
   IF @cDecodeSKUSP = '0'
      SET @cDecodeSKUSP = ''
   SET @cExtendedPutawaySP = rdt.RDTGetConfig( @nFunc, 'ExtendedPutawaySP', @cStorerKey)
   IF @cExtendedPutawaySP = '0'
      SET @cExtendedPutawaySP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cSKULabel = rdt.RDTGetConfig( @nFunc, 'SKULabel', @cStorerKey)
   IF @cSKULabel = '0'
      SET @cSKULabel = ''

   SET @cCaptureReceiptDetailInfoSP = rdt.RDTGetConfig( @nFunc, 'CaptureReceiptDetailInfoSP', @cStorerKey)
   IF @cCaptureReceiptDetailInfoSP = '0'
      SET @cCaptureReceiptDetailInfoSP = ''

   -- DefaultToLOC, by facility
   IF @cDefaultToLOC = ''
   BEGIN
      DECLARE @c_authority NVARCHAR(1)
      SELECT @b_success = 0
      EXECUTE nspGetRight
         @cFacility,
         @cStorerKey,
         NULL, -- @cSKU
         'ASNReceiptLocBasedOnFacility',
         @b_success   OUTPUT,
         @c_authority OUTPUT,
         @n_err       OUTPUT,
         @c_errmsg    OUTPUT

      IF @b_success = '1' AND @c_authority = '1'
         SELECT @cDefaultToLOC = UserDefine04
         FROM Facility WITH (NOLOCK)
         WHERE Facility = @cFacility
   END

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   SET @cConditionCode = '' --kh01  
   SET @cReceiptKey = ''
   SET @cRefNo = ''
   SET @cOption = ''
   SET @nQTY = 1
   SET @dArriveDate = NULL

   IF @cPreToIDLOC = '1'
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- To ID
      SET @cOutField02 = @cDefaultToLOC -- To LOC
      SET @cOutField03 = '' -- ArriveDate

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Set the entry point
      SET @nScn = @nScn_PreIDLOC
      SET @nStep = @nStep_PreIDLOC
   END
   ELSE
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- @cRefNo
      SET @cOutField02 = '' -- @cReceiptKey

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Set the entry point
      SET @nScn = @nScn_ASNRefNo
      SET @nStep = @nStep_ASNRefNo
   END
END
GOTO Quit

/************************************************************************************
Step 1. Scn = 5640. RefNo, ASN screen
   REF NO   (field01, input)
   ASN      (field02, input)
************************************************************************************/
Step_ASNRefNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cReceiptStatus NVARCHAR( 10)
      DECLARE @cChkStorerKey NVARCHAR( 15)
      DECLARE @nRowCount INT

      -- Screen mapping
      SET @cRefNo = @cInField01
      SET @cReceiptKey = @cInField02

      -- Check blank
      IF @cReceiptKey = '' AND @cRefNo = ''
      BEGIN
         SET @nErrNo = 145951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN/RefNo
         GOTO Quit
      END

      -- Check both key-in
      IF @cReceiptKey <> '' AND @cRefNo <> ''
      BEGIN
         SET @nErrNo = 145952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN or RefNo
         GOTO Quit
      END

      -- Lookup ref no
      IF @cRefNo <> '' AND @cReceiptKey = ''
      BEGIN
         EXEC rdt.rdt_EcomReturn_RefNoLookup @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cSKU         = '' -- @cSKU
            ,@cRefNo       = @cRefNo      OUTPUT
            ,@cReceiptKey  = @cReceiptKey OUTPUT
            ,@nBalQTY      = @nBalQTY     OUTPUT
            ,@nErrNo       = @nErrNo      OUTPUT
            ,@cErrMsg      = @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         IF @cReceiptKey <> ''
         BEGIN
            SET @cOutField01 = @cRefNo
            SET @cOutField02 = @cReceiptKey
         END
      END

      -- Check ASN
      IF @cReceiptKey <> ''
      BEGIN
         -- Get ASN info
         SELECT
            @cChkFacility = Facility,
            @cChkStorerKey = StorerKey,
            @cReceiptStatus = STATUS,
            @cASNStatus = ASNStatus
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         SET @nRowCount = @@ROWCOUNT

         -- Check ASN exist
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 145953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exist
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Validate ASN in different facility
         IF @cFacility <> @cChkFacility
         BEGIN
            SET @nErrNo = 145954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Validate ASN belong to the storer
         IF @cStorerKey <> @cChkStorerKey
         BEGIN
            SET @nErrNo = 145955
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Validate ASN status
         IF @cReceiptStatus = '9'
         BEGIN
            SET @nErrNo = 145956
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Check ASN cancelled
         IF @cReceiptStatus = 'CANC' OR @cASNStatus = 'CANC'
         BEGIN
            SET @nErrNo = 145957
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN cancelled
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtUpdateVar VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT,   ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Capture ASN Info
      IF @cCaptureReceiptInfoSP <> ''
      BEGIN
         EXEC rdt.rdt_EcomReturn_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'DISPLAY',
            @dArriveDate, @cReceiptKey, @cRefNo, @cID, @cLOC, @cData1, @cData2, @cData3, @cData4, @cData5,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @tCaptureVar,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Go to next screen
         SET @nScn = @nScn_CaptureData
         SET @nStep = @nStep_CaptureData

         GOTO Quit
      END

      -- Get statistic
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cPreToIDLOC = '1'
      BEGIN
        -- Prepare next screen variable
         SET @cOutField01 = '' -- ID
         SET @cOutField02 = @cLOC
         SET @cOutField03 = CASE WHEN @dArriveDate IS NULL THEN '' ELSE rdt.rdtFormatDate( @dArriveDate) END -- ArriveDate

         EXEC rdt.rdtSetFocusField @nMobile, 1

         -- Set the entry point
         SET @nScn = @nScn_PreIDLOC
         SET @nStep = @nStep_PreIDLOC
      END
      ELSE
      BEGIN
         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign-Out
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerKey

         -- Back to menu
         SET @nFunc = @nMenu
         SET @nScn  = @nMenu
         SET @nStep = 0

         SET @cOutField01 = ''
      END
   END

   Step_ASNRefNo_Quit:
   BEGIN
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_ASNRefNo, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/***********************************************************************************
Step 2. Scn = 5641. Capture data screen
   Data1    (field01)
   Input1   (field02, input)
   .
   .
   .
   Data5    (field09)
   Input5   (field10, input)
***********************************************************************************/
Step_CaptureData:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cData1 = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cData2 = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cData3 = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END
      SET @cData4 = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE @cOutField08 END
      SET @cData5 = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE @cOutField10 END

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10

      EXEC rdt.rdt_EcomReturn_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'UPDATE',
         @dArriveDate, @cReceiptKey, @cRefNo, @cID, @cLOC, @cData1, @cData2, @cData3, @cData4, @cData5,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @tCaptureVar,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Get statistic
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Prepare next screen var
      SET @cOutField01 = '' -- @cRefNo
      SET @cOutField02 = '' -- @cReceiptKey

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to prev screen
      SET @nScn = @nScn_ASNRefNo
      SET @nStep = @nStep_ASNRefNo
   END

   Step_CaptureData_Quit:
   BEGIN
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_CaptureData, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/***********************************************************************************
Step 3. Scn = 5642. SKU screen
   ASN      (field01)
   PO       (field02)
   SKU      (field03, input)
   Desc1    (field04)
   Desc2    (field05)
   ASN QTY  (field06)
   RCV QTY  (field07)
***********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03 -- SKU
      SET @cBarcode = @cInField03

      -- Validate blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 145958
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed
         GOTO Step_SKU_Fail
      END

      -- Init var (due to var pass out by DecodeSKUSP, GetReceiveInfoSP is not reset)
      SELECT @nQTY = 1,
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

      -- Decode
      IF @cDecodeSKUSP <> ''
      BEGIN
         IF @cDecodeSKUSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
                  @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
                  @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
                  @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
                  @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSKUSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSKUSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cRefNo, @cLOC, @cBarcode, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
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
               ' @cRefNo       NVARCHAR( 60), ' +
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cRefNo, @cLOC, @cBarcode,
               @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail
         END
      END

      -- Get SKU/UPC
      DECLARE @nSKUCnt INT
      SET @nSKUCnt = 0
      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 145959
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_SKU_Fail
      END

      IF @nSKUCnt = 1
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate barcode return multiple SKU
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
               @cSKU     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT,
               'ASN',    -- DocType
               @cReceiptKey

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
            SET @nErrNo = 145960
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_SKU_Fail
         END
      END

      -- Get SKU info
      SELECT
         @cSKUDesc =
            CASE WHEN @cDispStyleColorSize = '0'
                 THEN ISNULL( DescR, '')
                 ELSE CAST( Style AS NCHAR(20)) +
                      CAST( Color AS NCHAR(10)) +
                      CAST( Size  AS NCHAR(10))
            END,
         @cLottableCode = LottableCode,
         @cUOM = Pack.PackUOM3
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Retain value
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2

      -- Verify SKU
      IF @cVerifySKU = '1'
      BEGIN
         EXEC rdt.rdt_VerifySKU_V7 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, 'CHECK',
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT

         IF @nErrNo <> 0
         BEGIN
            -- Go to verify SKU screen
            SET @nScn = 3951
            SET @nStep = @nStep_VerifySKU

            GOTO Quit
         END
      END

      -- Lookup ASN by RefNo + SKU
      IF @cRefNoSKULookup = '1' AND @cRefNo <> ''
      BEGIN
         SET @cReceiptKey = ''
         SET @nBalQTY = 0
         EXEC rdt.rdt_EcomReturn_RefNoLookup @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cSKU         = @cSKU
            ,@cRefNo       = @cRefNo      OUTPUT
            ,@cReceiptKey  = @cReceiptKey OUTPUT
            ,@nBalQTY      = @nBalQTY     OUTPUT
            ,@nErrNo       = @nErrNo      OUTPUT
            ,@cErrMsg      = @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Check ASN found
         IF @cReceiptKey = ''
         BEGIN
            SET @nErrNo = 145962
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not found
            GOTO Step_SKU_Fail
         END

         SET @cOutField01 = @cReceiptKey
      END

      -- Check SKU in ASN
      IF @cCheckSKUInASN = '1'
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.Receiptdetail WITH (NOLOCK)
            WHERE Receiptkey = @cReceiptKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 145961
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not in ASN
            GOTO Step_SKU_Fail
         END
      END

      -- Check over receive
      IF @cAllowOverReceive = '0'
      BEGIN
         IF EXISTS( SELECT 1
            FROM ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
            HAVING ISNULL( SUM( BeforeReceivedQty), 0) + @nQTY >
                   ISNULL( SUM( QTYExpected), 0))
         BEGIN
            SET @nErrNo = 145963
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over received
            GOTO Step_SKU_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail
         END
      END

      -- Capture ASN Info
      IF @cCaptureReceiptDetailInfoSP <> ''
      BEGIN
         EXEC rdt.rdt_EcomReturn_CaptureDetailInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'DISPLAY',
            @dArriveDate, @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @cDtlData1, @cDtlData2, @cDtlData3, @cDtlData4, @cDtlData5,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @tCaptureVar,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo NOT IN ( 0, -1)
            GOTO Quit
         ELSE
         BEGIN
            IF @nErrNo = 0
            BEGIN
               -- Go to next screen
               SET @nScn = @nScn_CaptureDtlData
               SET @nStep = @nStep_CaptureDtlData

               GOTO Quit
            END
            ELSE
               SET @nErrNo = 0
         END
      END

      -- Get statistic
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Condition, reason
      -- SET @cConditionCode = 'OK' -- Set default at confirm SP
      SET @cSubReasonCode = ''
      IF @cCaptureConditionReason <> ''
      BEGIN
         SET @cOutField01 = '' -- ConditionCode
         SET @cOutField02 = '' -- SubReasonCode
         
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'C', @cCaptureConditionReason) > 0 THEN '' ELSE 'O' END
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'R', @cCaptureConditionReason) > 0 THEN '' ELSE 'O' END
         
         -- Go to condition, reason
         SET @nScn = @nScn_CondReason
         SET @nStep = @nStep_CondReason

         GOTO Quit
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
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         GOTO Step_SKU_Quit
      END

      -- Serial No
      IF @cSerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, @nQTY, 'CHECK', 'ASN', @cReceiptKey,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '2'

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            -- Go to Serial No screen
            SET @nFromScn = @nScn
            SET @nScn = @nScn_SerialNo
            SET @nStep = @nStep_SerialNo

            GOTO Quit
         END
      END

      -- Already key in toid & toloc, receive and stay in sku screen
      IF @cPreToIDLOC = '1'
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN Step_SKU -- For rollback or commit only our own transaction

         -- Receive
         EXEC rdt.rdt_EcomReturn_Confirm
            @nFunc               = @nFunc,
            @nMobile             = @nMobile,
            @cLangCode           = @cLangCode,
            @cStorerKey          = @cStorerKey,
            @cFacility           = @cFacility,
            @dArriveDate         = @dArriveDate,
            @cReceiptKey         = @cReceiptKey,
            @cRefNo              = @cRefNo,
            @cToLoc              = @cLOC,
            @cToID               = @cID,
            @cSKUCode            = @cSKU,
            @cSKUUOM             = @cUOM,
            @nSKUQTY             = @nQTY,
            @cLottable01         = @cLottable01,
            @cLottable02         = @cLottable02,
            @cLottable03         = @cLottable03,
            @dLottable04         = @dLottable04,
            @dLottable05         = @dLottable05,
            @cLottable06         = @cLottable06,
            @cLottable07         = @cLottable07,
            @cLottable08         = @cLottable08,
            @cLottable09         = @cLottable09,
            @cLottable10         = @cLottable10,
            @cLottable11         = @cLottable11,
            @cLottable12         = @cLottable12,
            @dLottable13         = @dLottable13,
            @dLottable14         = @dLottable14,
            @dLottable15         = @dLottable15,
            @cData1              = @cData1,
            @cData2              = @cData2,
            @cData3              = @cData3,
            @cData4              = @cData4,
            @cData5              = @cData5,
            @cConditionCode      = @cConditionCode,
            @cSubreasonCode      = @cSubreasonCode,
            @cSerialNo           = @cSerialNo,
            @nSerialQTY          = @nSerialQTY,
            @tConfirmVar         = @tConfirmVar,
            @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
            @nErrNo              = @nErrNo    OUTPUT,
            @cErrMsg             = @cErrMsg   OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN Step_SKU
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Step_SKU_Fail
         END

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
                  ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cRefNo        NVARCHAR( 60), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@nQTY          INT,           ' +
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
                  '@cData1        NVARCHAR( 60), ' +
                  '@cData2        NVARCHAR( 60), ' +
                  '@cData3        NVARCHAR( 60), ' +
                  '@cData4        NVARCHAR( 60), ' +
                  '@cData5        NVARCHAR( 60), ' +
                  '@cOption       NVARCHAR( 1),  ' +
                  '@dArriveDate   DATETIME,      ' +
                  '@tExtUpdateVar VariableTable READONLY, ' +
                  '@nErrNo        INT           OUTPUT,   ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
                  @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN Step_SKU
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  GOTO Quit
               END
            END
         END

         COMMIT TRAN Step_SKU
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- SKU label
         IF @cSKULabel <> ''
         BEGIN
            -- Common params
            INSERT INTO @tSKULabel (Variable, Value) VALUES
               ( '@cReceiptKey',          @cReceiptKey),
               ( '@cReceiptLineNumber',   @cReceiptLineNumber),
               ( '@cStorerKey',           @cStorerKey),
               ( '@cSKU',                 @cSKU),
               ( '@nQTY',                 CAST( @nQTY AS NVARCHAR(5)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cSKULabel, -- Report type
               @tSKULabel, -- Report params
               'rdtfnc_ECOMReturn',
               @nErrNo, -- OUTPUT, bypass error
               @cErrMsg OUTPUT
         END

         -- Back to RefNo/ASN, if fully receive and not allow over receive
         IF @cAllowOverReceive = '0'
         BEGIN
            -- Calc fully receive
            IF @cRefNoSKULookup = '1' AND @cRefNo <> ''
               SET @nBalQTY = @nBalQTY - 1
            ELSE
            BEGIN
               SET @nBalQTY = 0
               SELECT TOP 1 @nBalQTY = 1
               FROM ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               GROUP BY SKU
               HAVING ISNULL( SUM( QTYExpected), 0) <>
                      ISNULL( SUM( BeforeReceivedQty), 0)
            END

            -- Fully received
            IF @nBalQTY = 0
            BEGIN
               IF @cAutoReceiveNext = '1' OR @cFinalizeASN IN ('1', '2')
               BEGIN
                  IF @cFinalizeASN = '1' -- Always prompt
                  BEGIN
                     SET @cOutField01 = '' -- @cOption

                     -- Go to next screen
                     SET @nScn = @nScn_FinalizeASN
                     SET @nStep = @nStep_FinalizeASN

                     GOTO Quit
                  END

                  IF @cFinalizeASN = '2' -- No prompt, auto finalize
                  BEGIN
                     -- Finalize ASN
                     EXEC rdt.rdt_EcomReturn_Finalize
                        @nFunc         = @nFunc,
                        @nMobile       = @nMobile,
                        @cLangCode     = @cLangCode,
                        @nStep         = @nStep,
                        @nInputKey     = @nInputKey,
                        @cFacility     = @cFacility,
                        @cStorerKey    = @cStorerKey,
                        @cReceiptKey   = @cReceiptKey,
                        @cRefNo        = @cRefNo,
                        @nErrNo        = @nErrNo  OUTPUT,
                        @cErrMsg       = @cErrMsg OUTPUT

                     -- Go to finalilze screen, to retry
                     -- (cannot remain at current screen, due to it is not inside the transaction. ENTER again will double receive)
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

                        SET @cOutField01 = '' -- @cOption

                        -- Go to next screen
                        SET @nScn = @nScn_FinalizeASN
                        SET @nStep = @nStep_FinalizeASN

                        GOTO Quit
                     END
                  END

                  -- Prepare next screen var
                  SET @cOutField01 = '' -- @cRefNo
                  SET @cOutField02 = '' -- @cReceiptKey

                  EXEC rdt.rdtSetFocusField @nMobile, 1

                  -- Go to next screen
                  SET @nScn = @nScn_ASNRefNo
                  SET @nStep = @nStep_ASNRefNo

                  GOTO Quit
               END
            END
         END

         -- Get statistic
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20) -- Desc1
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)-- Desc2
         SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
         SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

         -- Reset data
         SELECT @cSKU = '', @nQTY = 1,
            @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
            @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
            @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         GOTO Quit
      END
      ELSE
      BEGIN
         SET @cSuggID = ''
         SET @cSuggLOC = ''

         -- Check need to putaway
         IF @cExtendedPutawaySP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile      INT,           ' +
                  '@nFunc        INT,           ' +
                  '@cLangCode    NVARCHAR( 3),  ' +
                  '@nStep        INT,           ' +
                  '@nInputKey    INT,           ' +
                  '@cFacility    NVARCHAR( 5),  ' +
                  '@cStorerKey   NVARCHAR( 15), ' +
                  '@cReceiptKey  NVARCHAR( 10), ' +
                  '@cRefNo       NVARCHAR( 60), ' +
                  '@cID          NVARCHAR( 18), ' +
                  '@cLOC         NVARCHAR( 10), ' +
                  '@cSKU         NVARCHAR( 20), ' +
                  '@nQTY         INT,           ' +
                  '@cReceiptLineNumber NVARCHAR( 5), ' +
                  '@cLottable01  NVARCHAR( 18), ' +
                  '@cLottable02  NVARCHAR( 18), ' +
                  '@cLottable03  NVARCHAR( 18), ' +
                  '@dLottable04  DATETIME,      ' +
                  '@dLottable05  DATETIME,      ' +
                  '@cLottable06  NVARCHAR( 30), ' +
                  '@cLottable07  NVARCHAR( 30), ' +
                  '@cLottable08  NVARCHAR( 30), ' +
                  '@cLottable09  NVARCHAR( 30), ' +
                  '@cLottable10  NVARCHAR( 30), ' +
                  '@cLottable11  NVARCHAR( 30), ' +
                  '@cLottable12  NVARCHAR( 30), ' +
                  '@dLottable13  DATETIME,      ' +
                  '@dLottable14  DATETIME,      ' +
                  '@dLottable15  DATETIME,      ' +
                  '@cSuggID      NVARCHAR( 18)  OUTPUT, ' +
                  '@cSuggLOC     NVARCHAR( 10)  OUTPUT, ' +
                  '@nErrNo       INT            OUTPUT, ' +
                  '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            END
         END

         -- Prepare next screen variable
         SET @cOutField01 = @cSuggID
         SET @cOutField02 = CASE WHEN @cDefaultIDAsSuggID = '1' THEN @cSuggID ELSE '' END -- ID
         SET @cOutField03 = @cSuggLOC
         SET @cOutField04 = CASE WHEN @cDefaultLOCAsSuggLOC = '1' THEN @cSuggLOC ELSE @cDefaultToLOC  END -- LOC

         IF @cDisableToIDField = '1'
            SET @cFieldAttr02 = 'O'
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SuggID

         -- Go to ID LOC screen
         SET @nScn = @nScn_IDLOC
         SET @nStep = @nStep_IDLOC
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Check received
      IF EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND BeforeReceivedQTY > 0 AND FinalizeFlag <> 'Y')
      BEGIN
         -- Prompt finalize ASN
         IF @cFinalizeASN = '1'
         BEGIN
            -- Prepare prev screen var
            SET @cOutField01 = CASE WHEN ISNULL( @cOption, '') = '' THEN '' ELSE @cOption END -- Last selected Option
            SET @cOption = ''

            -- Go to finalize ASN screen
            SET @nScn = @nScn_FinalizeASN
            SET @nStep = @nStep_FinalizeASN

            GOTO Quit
         END

         -- Prompt finalize ASN (fully received)
         ELSE IF @cFinalizeASN = '2'
         BEGIN
            -- Get ASN variance
            DECLARE @nQTYExp INT, @nSKUExp INT
            DECLARE @nQTYAct INT, @nSKUAct INT

            -- Expected
            SELECT
               @nSKUExp = COUNT( DISTINCT SKU),
               @nQTYExp = ISNULL( SUM( QTYExpected), 0)
            FROM ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND QTYExpected > 0

            -- Actual
            SELECT
               @nSKUAct = COUNT( DISTINCT SKU),
               @nQTYAct = ISNULL( SUM( BeforeReceivedQTY), 0)
            FROM ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND BeforeReceivedQTY > 0

            DECLARE @cMsg1 NVARCHAR( 20)
            DECLARE @cMsg2 NVARCHAR( 20)
            DECLARE @cMsg3 NVARCHAR( 20)

            SET @cMsg1 = rdt.rdtgetmessage( 145980, @cLangCode, 'DSP') --VARIANCE FOUND !
            SET @cMsg2 = rdt.rdtgetmessage( 145981, @cLangCode, 'DSP') --SKU:
            SET @cMsg3 = rdt.rdtgetmessage( 145982, @cLangCode, 'DSP') --QTY:

            SET @cMsg2 = TRIM( @cMsg2) + ' ' + CAST( @nSKUAct AS NVARCHAR(3)) + '/' + CAST( @nSKUExp AS NVARCHAR(3))
            SET @cMsg3 = TRIM( @cMsg3) + ' ' + CAST( @nQTYAct AS NVARCHAR(3)) + '/' + CAST( @nQTYExp AS NVARCHAR(3))

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               '', @cMsg1, '', @cMsg2, @cMsg3

            SET @nErrNo = 0
            SET @cErrMsg = ''

            -- Prepare prev screen var
            SET @cOutField01 = ''
            SET @cOption = ''

            -- Go to finalize ASN screen
            SET @nScn = @nScn_FinalizeASN
            SET @nStep = @nStep_FinalizeASN

            GOTO Quit
         END
      END

      -- Don't prompt finalize ASN (default)
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- @cRefNo
         SET @cOutField02 = '' -- @cReceiptKey

         EXEC rdt.rdtSetFocusField @nMobile, 1

         -- Go to prev screen
         SET @nScn = @nScn_ASNRefNo
         SET @nStep = @nStep_ASNRefNo

         GOTO Quit
      END
   END

   Step_SKU_Quit:
   BEGIN
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> '' AND @nStep <> @nStep_Lottables -- Lottable screen uses @cOutField15, cannot overwrite
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
   GOTO Quit

   Step_SKU_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 3990. Dynamic lottables
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
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Serial No
      IF @cSerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, @nQTY, 'CHECK', 'ASN', @cReceiptKey,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '2'

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            -- Go to Serial No screen
            SET @nFromScn = @nScn
            SET @nScn = @nScn_SerialNo
            SET @nStep = @nStep_SerialNo

            GOTO Quit
         END
      END

      -- Already key in toid & toloc, receive and stay in sku screen
      IF @cPreToIDLOC = '1'
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN Step_SKU -- For rollback or commit only our own transaction

         -- Receive
         EXEC rdt.rdt_EcomReturn_Confirm
            @nFunc               = @nFunc,
            @nMobile             = @nMobile,
            @cLangCode           = @cLangCode,
            @cStorerKey          = @cStorerKey,
            @cFacility           = @cFacility,
            @dArriveDate         = @dArriveDate,
            @cReceiptKey         = @cReceiptKey,
            @cRefNo              = @cRefNo,
            @cToLoc              = @cLOC,
            @cToID               = @cID,
            @cSKUCode            = @cSKU,
            @cSKUUOM             = @cUOM,
            @nSKUQTY             = @nQTY,
            @cLottable01         = @cLottable01,
            @cLottable02         = @cLottable02,
            @cLottable03         = @cLottable03,
            @dLottable04         = @dLottable04,
            @dLottable05         = @dLottable05,
            @cLottable06         = @cLottable06,
            @cLottable07         = @cLottable07,
            @cLottable08         = @cLottable08,
            @cLottable09         = @cLottable09,
            @cLottable10         = @cLottable10,
            @cLottable11         = @cLottable11,
            @cLottable12         = @cLottable12,
            @dLottable13         = @dLottable13,
            @dLottable14         = @dLottable14,
            @dLottable15         = @dLottable15,
            @cData1              = @cData1,
            @cData2              = @cData2,
            @cData3              = @cData3,
            @cData4              = @cData4,
            @cData5              = @cData5,
            @cConditionCode      = @cConditionCode,
            @cSubreasonCode      = @cSubreasonCode,
            @cSerialNo           = @cSerialNo,
            @nSerialQTY          = @nSerialQTY,
            @tConfirmVar         = @tConfirmVar,
            @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
            @nErrNo              = @nErrNo    OUTPUT,
            @cErrMsg             = @cErrMsg   OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN Step_SKU
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END

         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
                  ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cRefNo        NVARCHAR( 60), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@nQTY          INT,           ' +
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
                  '@cData1        NVARCHAR( 60), ' +
                  '@cData2        NVARCHAR( 60), ' +
                  '@cData3        NVARCHAR( 60), ' +
                  '@cData4        NVARCHAR( 60), ' +
                  '@cData5        NVARCHAR( 60), ' +
                  '@cOption       NVARCHAR( 1),  ' +
                  '@dArriveDate   DATETIME,      ' +
                  '@tExtUpdateVar VariableTable READONLY, ' +
                  '@nErrNo        INT           OUTPUT,   ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
                  @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN Step_SKU
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  GOTO Quit
               END
            END
         END

         COMMIT TRAN Step_SKU
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- SKU label
         IF @cSKULabel <> ''
         BEGIN
            -- Common params
            INSERT INTO @tSKULabel (Variable, Value) VALUES
               ( '@cReceiptKey',          @cReceiptKey),
               ( '@cReceiptLineNumber',   @cReceiptLineNumber),
               ( '@cStorerKey',           @cStorerKey),
               ( '@cSKU',                 @cSKU) ,
               ( '@nQTY',                 CAST( @nQTY AS NVARCHAR(5)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cSKULabel, -- Report type
               @tSKULabel, -- Report params
               'rdtfnc_ECOMReturn',
               @nErrNo, -- OUTPUT, bypass error
               @cErrMsg OUTPUT
         END

         -- Enable field
         SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
         SET @cFieldAttr04 = ''
         SET @cFieldAttr06 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr10 = ''

         -- Back to RefNo/ASN, if fully receive and not allow over receive
         IF @cAllowOverReceive = '0'
         BEGIN
            -- Calc fully receive
            IF @cRefNoSKULookup = '1' AND @cRefNo <> ''
               SET @nBalQTY = @nBalQTY - 1
            ELSE
            BEGIN
               SET @nBalQTY = 0
               SELECT TOP 1 @nBalQTY = 1
               FROM ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               GROUP BY SKU
               HAVING ISNULL( SUM( QTYExpected), 0) <>
                      ISNULL( SUM( BeforeReceivedQty), 0)
            END

            -- Fully received
            IF @nBalQTY = 0
            BEGIN
               IF @cAutoReceiveNext = '1' OR @cFinalizeASN IN ('1', '2')
               BEGIN
                  IF @cFinalizeASN = '1' -- Always prompt
                  BEGIN
                     SET @cOutField01 = '' -- @cOption

                     -- Go to next screen
                     SET @nScn = @nScn_FinalizeASN
                     SET @nStep = @nStep_FinalizeASN

                     GOTO Quit
                  END

                  IF @cFinalizeASN = '2' -- No prompt, auto finalize
                  BEGIN
                     -- Finalize ASN
                     EXEC rdt.rdt_EcomReturn_Finalize
                        @nFunc         = @nFunc,
                        @nMobile       = @nMobile,
                        @cLangCode     = @cLangCode,
                        @nStep         = @nStep,
                        @nInputKey     = @nInputKey,
                        @cFacility     = @cFacility,
                        @cStorerKey    = @cStorerKey,
                        @cReceiptKey   = @cReceiptKey,
                        @cRefNo        = @cRefNo,
                        @nErrNo        = @nErrNo  OUTPUT,
                        @cErrMsg       = @cErrMsg OUTPUT

                     -- Go to finalilze screen, to retry
                     -- (cannot remain at current screen, due to it is not inside the transaction. ENTER again will double receive)
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

                        SET @cOutField01 = '' -- @cOption

                        -- Go to next screen
                        SET @nScn = @nScn_FinalizeASN
                        SET @nStep = @nStep_FinalizeASN

                        GOTO Quit
                     END
                  END

                  -- Prepare next screen var
                  SET @cOutField01 = '' -- @cRefNo
                  SET @cOutField02 = '' -- @cReceiptKey

                  EXEC rdt.rdtSetFocusField @nMobile, 1

                  -- Go to next screen
                  SET @nScn = @nScn_ASNRefNo
                  SET @nStep = @nStep_ASNRefNo

                  GOTO Quit
               END
            END
         END

         -- Get statistic
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20) -- Desc1
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)-- Desc2
         SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
         SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

         -- Reset data
         SELECT @cSKU = '', @nQTY = 1,
            @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
            @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
            @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         -- Go to next screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
      ELSE
      BEGIN
         SET @cSuggID = ''
         SET @cSuggLOC = ''

         -- Check need to putaway
         IF @cExtendedPutawaySP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile      INT,           ' +
                  '@nFunc        INT,           ' +
                  '@cLangCode    NVARCHAR( 3),  ' +
                  '@nStep        INT,           ' +
                  '@nInputKey    INT,           ' +
                  '@cFacility    NVARCHAR( 5),  ' +
                  '@cStorerKey   NVARCHAR( 15), ' +
                  '@cReceiptKey  NVARCHAR( 10), ' +
                  '@cRefNo       NVARCHAR( 60), ' +
                  '@cID          NVARCHAR( 18), ' +
                  '@cLOC         NVARCHAR( 10), ' +
                  '@cSKU         NVARCHAR( 20), ' +
                  '@nQTY         INT,           ' +
                  '@cReceiptLineNumber NVARCHAR( 5), ' +
                  '@cLottable01  NVARCHAR( 18), ' +
                  '@cLottable02  NVARCHAR( 18), ' +
                  '@cLottable03  NVARCHAR( 18), ' +
                  '@dLottable04  DATETIME,      ' +
                  '@dLottable05  DATETIME,      ' +
                  '@cLottable06  NVARCHAR( 30), ' +
                  '@cLottable07  NVARCHAR( 30), ' +
                  '@cLottable08  NVARCHAR( 30), ' +
                  '@cLottable09  NVARCHAR( 30), ' +
                  '@cLottable10  NVARCHAR( 30), ' +
                  '@cLottable11  NVARCHAR( 30), ' +
                  '@cLottable12  NVARCHAR( 30), ' +
                  '@dLottable13  DATETIME,      ' +
                  '@dLottable14  DATETIME,      ' +
                  '@dLottable15  DATETIME,      ' +
                  '@cSuggID      NVARCHAR( 18)  OUTPUT, ' +
                  '@cSuggLOC     NVARCHAR( 10)  OUTPUT, ' +
                  '@nErrNo       INT            OUTPUT, ' +
                  '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END

         -- Enable field
         SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
         SET @cFieldAttr04 = ''
         SET @cFieldAttr06 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr10 = ''

         -- Prepare next screen variable
         SET @cOutField01 = @cSuggID
         SET @cOutField02 = CASE WHEN @cDefaultIDAsSuggID = '1' THEN @cSuggID ELSE '' END -- ID
         SET @cOutField03 = @cSuggLOC
         SET @cOutField04 = CASE WHEN @cDefaultLOCAsSuggLOC = '1' THEN @cSuggLOC ELSE @cDefaultToLOC  END -- LOC

         IF @cDisableToIDField = '1'
            SET @cFieldAttr02 = 'O'
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SuggID

         -- Go to ID LOC screen
         SET @nScn = @nScn_IDLOC
         SET @nStep = @nStep_IDLOC
      END
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
         @cReceiptKey,
         @nFunc

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Condition, reason
      IF @cCaptureConditionReason <> ''
      BEGIN
         SET @cOutField01 = @cConditionCode
         SET @cOutField02 = @cSubReasonCode
         
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'C', @cCaptureConditionReason) > 0 THEN '' ELSE 'O' END
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'R', @cCaptureConditionReason) > 0 THEN '' ELSE 'O' END
         
         -- Go to condition, reason
         SET @nScn = @nScn_CondReason
         SET @nStep = @nStep_CondReason

         GOTO Quit
      END

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = '' --
      SET @cFieldAttr06 = '' --
      SET @cFieldAttr08 = '' --
      SET @cFieldAttr10 = '' --

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  -- SKU desc 2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   Step_Lottables_Quit:
   BEGIN
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_Lottables, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 5644. ID, LOC screen
   SuggID  (field01)
   ID      (field02, input)
   SuggLOC (field03)
   LOC     (field04, input)
********************************************************************************/
Step_IDLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = CASE WHEN @cDisableToIDField = '1' THEN @cOutField02 ELSE @cInField02 END -- ID
      SET @cLOC = @cInField04 -- LOC

      -- Check different ID
      IF @cSuggID <> @cID AND @cSuggID <> ''
      BEGIN
         -- Check allow overwrite
         IF @cOverrideSuggestID <> '1'
         BEGIN
            SET @nErrNo = 145964
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ID
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
            SET @cOutField02 = ''
            GOTO Quit
         END
      END

      -- Check ID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0
      BEGIN
         SET @nErrNo = 145965
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
         SET @cOutField02 = ''
         GOTO Quit
      END

      IF @cID <> ''
      BEGIN
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            NULL, -- @cSKU
            'DisAllowDuplicateIdsOnRFRcpt',
            @b_Success   OUTPUT,
            @cAuthority  OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT

         -- Check ID in used
         IF @cAuthority = '1' AND @cID <> ''
         BEGIN
            IF EXISTS( SELECT [ID]
               FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
               WHERE [ID] = @cID
                  AND QTY > 0
                  AND LOC.Facility = @cFacility)
            BEGIN
               SET @nErrNo = 145966
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
               SET @cOutField02 = ''
               GOTO Quit
            END
         END

         SET @cOutField02 = @cID
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
      END

      -- Validate compulsary field
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 145967
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
         SET @cOutField04 = ''
         GOTO Quit
      END

      -- Check different ID
      IF @cSuggLOC <> @cLOC AND @cSuggLOC <> ''
      BEGIN
         -- Check allow overwrite
         IF @cOverrideSuggestLOC <> '1'
         BEGIN
            SET @nErrNo = 145968
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
            SET @cOutField04 = ''
            GOTO Quit
         END
      END

      -- Get the location
      SET @cChkLOC = ''
      SET @cChkFacility = ''
      SELECT
         @cChkLOC = LOC,
         @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      -- Validate location
      IF @cChkLOC = ''
      BEGIN
         SET @nErrNo = 145969
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
         SET @cOutField04 = ''
         GOTO Quit
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 145970
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
         SET @cOutField04 = ''
         GOTO Quit
      END
      SET @cOutField04 = @cLOC

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step_IDLOC -- For rollback or commit only our own transaction

      -- Receive
      EXEC rdt.rdt_EcomReturn_Confirm
         @nFunc               = @nFunc,
         @nMobile             = @nMobile,
         @cLangCode           = @cLangCode,
         @cStorerKey          = @cStorerKey,
         @cFacility           = @cFacility,
         @dArriveDate         = @dArriveDate,
         @cReceiptKey         = @cReceiptKey,
         @cRefNo              = @cRefNo,
         @cToLoc              = @cLOC,
         @cToID               = @cID,
         @cSKUCode            = @cSKU,
         @cSKUUOM             = @cUOM,
         @nSKUQTY             = @nQTY,
         @cLottable01         = @cLottable01,
         @cLottable02         = @cLottable02,
         @cLottable03         = @cLottable03,
         @dLottable04         = @dLottable04,
         @dLottable05         = @dLottable05,
         @cLottable06         = @cLottable06,
         @cLottable07         = @cLottable07,
         @cLottable08         = @cLottable08,
         @cLottable09         = @cLottable09,
         @cLottable10         = @cLottable10,
         @cLottable11         = @cLottable11,
         @cLottable12         = @cLottable12,
         @dLottable13         = @dLottable13,
         @dLottable14         = @dLottable14,
         @dLottable15         = @dLottable15,
         @cData1              = @cData1,
         @cData2              = @cData2,
         @cData3              = @cData3,
         @cData4              = @cData4,
         @cData5              = @cData5,
         @cConditionCode      = @cConditionCode,
         @cSubreasonCode      = @cSubreasonCode,
         @cSerialNo           = @cSerialNo,
         @nSerialQTY          = @nSerialQTY,
         @tConfirmVar         = @tConfirmVar,
         @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
         @nErrNo              = @nErrNo    OUTPUT,
         @cErrMsg             = @cErrMsg   OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN Step_IDLOC
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtUpdateVar VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT,   ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_IDLOC
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN Step_IDLOC
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- SKU label
      IF @cSKULabel <> ''
      BEGIN
         -- Common params
         INSERT INTO @tSKULabel (Variable, Value) VALUES
            ( '@cReceiptKey',          @cReceiptKey),
            ( '@cReceiptLineNumber',   @cReceiptLineNumber),
            ( '@cStorerKey',           @cStorerKey),
            ( '@cSKU',                 @cSKU),
            ( '@nQTY',                 CAST( @nQTY AS NVARCHAR(5)))

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
            @cSKULabel, -- Report type
            @tSKULabel, -- Report params
            'rdtfnc_ECOMReturn',
            @nErrNo, -- OUTPUT, bypass error
            @cErrMsg OUTPUT
      END

      IF @cDisableToIDField = '1'
         SET @cFieldAttr02 = ''

      -- Back to RefNo/ASN, if fully receive and not allow over receive
      IF @cAllowOverReceive = '0'
      BEGIN
         -- Calc fully receive
         IF @cRefNoSKULookup = '1' AND @cRefNo <> ''
            SET @nBalQTY = @nBalQTY - 1
         ELSE
         BEGIN
            SET @nBalQTY = 0
            SELECT TOP 1 @nBalQTY = 1
            FROM ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            GROUP BY SKU
            HAVING ISNULL( SUM( QTYExpected), 0) <>
                   ISNULL( SUM( BeforeReceivedQty), 0)
         END

         -- Fully received
         IF @nBalQTY = 0
         BEGIN
            IF @cAutoReceiveNext = '1' OR @cFinalizeASN IN ('1', '2')
            BEGIN
               IF @cFinalizeASN = '1' -- Always prompt
               BEGIN
                  SET @cOutField01 = '' -- @cOption

                  -- Go to next screen
                  SET @nScn = @nScn_FinalizeASN
                  SET @nStep = @nStep_FinalizeASN

                  GOTO Quit
               END

               IF @cFinalizeASN = '2' -- No prompt, auto finalize
               BEGIN
                  -- Finalize ASN
                  EXEC rdt.rdt_EcomReturn_Finalize
                     @nFunc         = @nFunc,
                     @nMobile       = @nMobile,
                     @cLangCode     = @cLangCode,
                     @nStep         = @nStep,
                     @nInputKey     = @nInputKey,
                     @cFacility     = @cFacility,
                     @cStorerKey    = @cStorerKey,
                     @cReceiptKey   = @cReceiptKey,
                     @cRefNo        = @cRefNo,
                     @nErrNo        = @nErrNo  OUTPUT,
                     @cErrMsg       = @cErrMsg OUTPUT

                  -- Go to finalilze screen, to retry
                  -- (cannot remain at current screen, due to it is not inside the transaction. ENTER again will double receive)
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

                     SET @cOutField01 = '' -- @cOption

                     -- Go to next screen
                     SET @nScn = @nScn_FinalizeASN
                     SET @nStep = @nStep_FinalizeASN

                     GOTO Quit
                  END
               END

               -- Prepare next screen var
               SET @cOutField01 = '' -- @cRefNo
               SET @cOutField02 = '' -- @cReceiptKey

               EXEC rdt.rdtSetFocusField @nMobile, 1

               -- Go to next screen
               SET @nScn = @nScn_ASNRefNo
               SET @nStep = @nStep_ASNRefNo

               GOTO Quit
            END
         END
      END

      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20) -- Desc1
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)-- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU

      -- Reset data
      SELECT @cSKU = '', @nQTY = 1,
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL
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
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         -- To bypass ExtendedInfo override OutField15 required by dynamic lottable
         GOTO Quit
      END

      -- Condition, reason
      IF @cCaptureConditionReason <> ''
      BEGIN
         SET @cOutField01 = @cConditionCode
         SET @cOutField02 = @cSubReasonCode
         
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'C', @cCaptureConditionReason) > 0 THEN '' ELSE 'O' END
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'R', @cCaptureConditionReason) > 0 THEN '' ELSE 'O' END
         
         -- Go to condition, reason
         SET @nScn = @nScn_CondReason
         SET @nStep = @nStep_CondReason

         GOTO Quit
      END

      BEGIN
         -- Enable field
         SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
         SET @cFieldAttr04 = '' --
         SET @cFieldAttr06 = '' --
         SET @cFieldAttr08 = '' --
         SET @cFieldAttr10 = '' --

         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = '' -- Desc1
         SET @cOutField05 = '' -- Desc2
         SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
         SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         -- Go to next screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
   END


   Step_IDLOC_Quit:
   BEGIN
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_IDLOC, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/********************************************************************************
Step 6. Screen = 3950. Verify SKU
   SKU            (Field01)
   SKUDesc1       (Field02)
   SKUDesc2       (Field03)
   Field label 1  (Field04)
   Field value 1  (Field05, input)
   Field label 2  (Field06)
   Field value 2  (Field07, input)
   Field label 3  (Field08)
   Field value 3  (Field09, input)
   Field label 4  (Field10)
   Field value 4  (Field11, input)
   Field label 5  (Field12)
   Field value 5  (Field13, input)
********************************************************************************/
Step_VerifySKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Update SKU setting
      EXEC rdt.rdt_VerifySKU_V7 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, 'UPDATE',
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Enable field
      SET @cFieldAttr05 = '' -- Dynamic verify SKU 1..5
      SET @cFieldAttr07 = '' --
      SET @cFieldAttr09 = '' --
      SET @cFieldAttr11 = '' --
      SET @cFieldAttr13 = '' --

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr05 = '' -- Dynamic verify SKU 1..5
      SET @cFieldAttr07 = '' --
      SET @cFieldAttr09 = '' --
      SET @cFieldAttr11 = '' --
      SET @cFieldAttr13 = '' --

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   Step_VerifySKU_Quit:
   BEGIN
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_VerifySKU, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/********************************************************************************
Step 7. Screen = 3570. Multi SKU
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
         @cSKU     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Get SKU info
      SELECT @cSKUDesc =
               CASE WHEN @cDispStyleColorSize = '0'
                    THEN ISNULL( DescR, '')
                    ELSE CAST( Style AS NCHAR(20)) +
                         CAST( Color AS NCHAR(10)) +
                         CAST( Size  AS NCHAR(10))
               END
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
   END

   -- Enable field
   SET @cFieldAttr05 = '' -- Dynamic verify SKU 1..5
   SET @cFieldAttr07 = '' --
   SET @cFieldAttr09 = '' --
   SET @cFieldAttr11 = '' --
   SET @cFieldAttr13 = '' --

   -- Prepare next screen var
   SET @cOutField01 = @cReceiptKey
   SET @cOutField02 = @cRefNo
   SET @cOutField03 = @cSKU -- SKU
   SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20) -- Desc1
   SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)-- Desc2
   SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
   SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

   -- Go to next screen
   SET @nScn = @nScn_SKU
   SET @nStep = @nStep_SKU

   -- Extended Info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
            ' @tExtInfoVar, @cExtendedInfo OUTPUT'
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nAfterStep    INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cReceiptKey   NVARCHAR( 10), ' +
            '@cRefNo        NVARCHAR( 60), ' +
            '@cID           NVARCHAR( 18), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@nQTY          INT,           ' +
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
            '@cData1        NVARCHAR( 60), ' +
            '@cData2        NVARCHAR( 60), ' +
            '@cData3        NVARCHAR( 60), ' +
            '@cData4        NVARCHAR( 60), ' +
            '@cData5        NVARCHAR( 60), ' +
            '@cOption       NVARCHAR( 1),  ' +
            '@dArriveDate   DATETIME,      ' +
            '@tExtInfoVar   VariableTable READONLY, ' +
            '@cExtendedInfo NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_MultiSKU, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
            @tExtInfoVar, @cExtendedInfo OUTPUT

         IF @cExtendedInfo <> ''
            SET @cOutField15 = @cExtendedInfo
      END
   END
END
GOTO Quit

/********************************************************************************
Step 8. Screen = 5645. Finalize ASN
   Finalize ASN?
   1 = YES
   9 = NO
   Option      (Field01, input)
********************************************************************************/
Step_FinalizeASN:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 145971
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         GOTO Step_FinalizeASN_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ( '1', '9')
	   BEGIN
         SET @nErrNo = 145972
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_FinalizeASN_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_FinalizeASN_Fail
         END
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      -- Cross DB trans will hit "Cannot promote the transaction to a distributed transaction because there is an active save point in this transaction."
      -- SAVE TRAN Step_FinalizeASN -- For rollback or commit only our own transaction

      IF @cOption = '1' -- Yes
      BEGIN
         -- Finalize ASN
         EXEC rdt.rdt_EcomReturn_Finalize
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cReceiptKey   = @cReceiptKey,
            @cRefNo        = @cRefNo,
            @nErrNo        = @nErrNo  OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN -- Step_FinalizeASN
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Quit
         END
      END
      
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtUpdateVar VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT,   ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN -- Step_FinalizeASN
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN -- Step_FinalizeASN
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Lookup ASN by RefNo + SKU
      IF @cRefNoSKULookup = '1' AND @cRefNo <> ''
      BEGIN
         SET @cReceiptKey = ''
         SET @nBalQTY = 0
         EXEC rdt.rdt_EcomReturn_RefNoLookup @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cSKU         = '' -- @cSKU
            ,@cRefNo       = @cRefNo      OUTPUT
            ,@cReceiptKey  = @cReceiptKey OUTPUT
            ,@nBalQTY      = @nBalQTY     OUTPUT
            ,@nErrNo       = 0  -- @nErrNo      OUTPUT -- ASN could all finalized, returned error
            ,@cErrMsg      = '' -- @cErrMsg     OUTPUT

         IF @nBalQTY > 0
         BEGIN
            -- Get statistic
            SET @nTotalQTYExp = 0
            SET @nTotalQTYRcv = 0

            -- Prepare next screen var
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cRefNo
            SET @cOutField03 = '' -- SKU
            SET @cOutField04 = '' -- Desc1
            SET @cOutField05 = '' -- Desc2
            SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
            SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

            -- Go to next screen
            SET @nScn = @nScn_SKU
            SET @nStep = @nStep_SKU

            GOTO Step_FinalizeASN_Quit
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- @cRefNo
      SET @cOutField02 = '' -- @cReceiptKey

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn_ASNRefNo
      SET @nStep = @nStep_ASNRefNo
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   Step_FinalizeASN_Quit:
   BEGIN
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_FinalizeASN, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
   GOTO Quit

   Step_FinalizeASN_Fail:
   BEGIN
      SET @cOutField01 = '' -- Option
      SET @cOption = ''
   END
END
GOTO Quit

/********************************************************************************
Step 9. Scn = 5646. Pre ID, LOC screen
   ID          (field01, input)
   LOC         (field02, input)
   ARRIVE DATE (field03, input)
********************************************************************************/
Step_PreIDLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cArriveDate NVARCHAR(10)

      -- Screen mapping
      SET @cID = @cInField01 -- ID
      SET @cLOC = @cInField02 -- LOC
      SET @cArriveDate = @cInField03 -- ArriveDate

      -- Check ID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0
      BEGIN
         SET @nErrNo = 145973
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cID <> ''
      BEGIN
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            NULL, -- @cSKU
            'DisAllowDuplicateIdsOnRFRcpt',
            @b_Success   OUTPUT,
            @cAuthority  OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT

         -- Check ID in used
         IF @cAuthority = '1'
         BEGIN
            IF EXISTS( SELECT [ID]
               FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
               WHERE [ID] = @cID
                  AND QTY > 0
                  AND LOC.Facility = @cFacility)
            BEGIN
               SET @nErrNo = 145974
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID
               SET @cOutField01 = ''
               GOTO Quit
            END
         END

         SET @cOutField01 = @cID
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
      END

      -- Validate compulsary field
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 145975
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get the location
      SET @cChkLOC = ''
      SET @cChkFacility = ''
      SELECT
         @cChkLOC = LOC,
         @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      -- Validate location
      IF @cChkLOC = ''
      BEGIN
         SET @nErrNo = 145976
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 145977
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- LOC
         SET @cOutField02 = ''
         GOTO Quit
      END
      SET @cOutField02 = @cLOC

      -- Check valid arrival date
      IF @cArriveDate <> ''
      BEGIN
         -- Check valid date
         IF rdt.rdtIsValidDate( @cArriveDate) = 0
         BEGIN
            SET @nErrNo = 145978
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Date
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- ArriveDate
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check future date
         IF rdt.rdtConvertToDate( @cArriveDate) > CONVERT( DATE, GETDATE())
         BEGIN
            SET @nErrNo = 145979
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Future Date
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- ArriveDate
            SET @cOutField03 = ''
            GOTO Quit
         END

         SET @dArriveDate = rdt.rdtConvertToDate( @cArriveDate)
         SET @cOutField03 = @cArriveDate
      END
      ELSE
         SET @dArriveDate = NULL

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- @cRefNo
      SET @cOutField02 = '' -- @cReceiptKey

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Set the entry point
      SET @nScn = @nScn_ASNRefNo
      SET @nStep = @nStep_ASNRefNo
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''

      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 10. Screen = 4831. Serial No
 SKU            (Field01)
 SKUDesc1       (Field02)
 SKUDesc2       (Field03)
 SerialNo       (Field04, input)
 Scan           (Field05)
********************************************************************************/
Step_SerialNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Update SKU setting
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, @nQTY, 'UPDATE', 'ASN', @cReceiptKey,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
         @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn,
         @nBulkSNO   OUTPUT,  @nBulkSNOQTY OUTPUT,  @cSerialCaptureType = '2'

      IF @nErrNo = -1
      BEGIN
         SET @nInputKey = 0 -- Simulate ESC needed by rdt_Lottable
         SET @nErrNo = 0    -- Reset error
         GOTO Step_SerialNo_Quit
      END

      IF @nErrNo <> 0
         GOTO Quit

      -- Already key in toid & toloc, receive and stay in sku screen
      IF @cPreToIDLOC = '1'
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN Step_SKU -- For rollback or commit only our own transaction

         -- Receive
         EXEC rdt.rdt_EcomReturn_Confirm
            @nFunc               = @nFunc,
            @nMobile             = @nMobile,
            @cLangCode           = @cLangCode,
            @cStorerKey          = @cStorerKey,
            @cFacility           = @cFacility,
            @dArriveDate         = @dArriveDate,
            @cReceiptKey         = @cReceiptKey,
            @cRefNo              = @cRefNo,
            @cToLoc              = @cLOC,
            @cToID               = @cID,
            @cSKUCode            = @cSKU,
            @cSKUUOM             = @cUOM,
            @nSKUQTY             = @nQTY,
            @cLottable01         = @cLottable01,
            @cLottable02         = @cLottable02,
            @cLottable03         = @cLottable03,
            @dLottable04         = @dLottable04,
            @dLottable05         = @dLottable05,
            @cLottable06         = @cLottable06,
            @cLottable07         = @cLottable07,
            @cLottable08         = @cLottable08,
            @cLottable09         = @cLottable09,
            @cLottable10         = @cLottable10,
            @cLottable11         = @cLottable11,
            @cLottable12         = @cLottable12,
            @dLottable13         = @dLottable13,
            @dLottable14         = @dLottable14,
            @dLottable15         = @dLottable15,
            @cData1              = @cData1,
            @cData2              = @cData2,
            @cData3              = @cData3,
            @cData4              = @cData4,
            @cData5              = @cData5,
            @cConditionCode      = @cConditionCode,
            @cSubreasonCode      = @cSubreasonCode,
            @cSerialNo           = @cSerialNo,
            @nSerialQTY          = @nSerialQTY,
            @tConfirmVar         = @tConfirmVar,
            @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
            @nErrNo              = @nErrNo    OUTPUT,
            @cErrMsg             = @cErrMsg   OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN Step_SKU
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END

         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
                  ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cRefNo        NVARCHAR( 60), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@nQTY          INT,           ' +
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
                  '@cData1        NVARCHAR( 60), ' +
                  '@cData2        NVARCHAR( 60), ' +
                  '@cData3        NVARCHAR( 60), ' +
                  '@cData4        NVARCHAR( 60), ' +
                  '@cData5        NVARCHAR( 60), ' +
                  '@cOption       NVARCHAR( 1),  ' +
                  '@dArriveDate   DATETIME,      ' +
                  '@tExtUpdateVar VariableTable READONLY, ' +
                  '@nErrNo        INT           OUTPUT,   ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
                  @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN Step_SKU
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  GOTO Quit
               END
            END
         END

         COMMIT TRAN Step_SKU
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- SKU label
         IF @cSKULabel <> ''
         BEGIN
            -- Common params
            INSERT INTO @tSKULabel (Variable, Value) VALUES
               ( '@cReceiptKey',          @cReceiptKey),
               ( '@cReceiptLineNumber',   @cReceiptLineNumber),
               ( '@cStorerKey',           @cStorerKey),
               ( '@cSKU',                 @cSKU) ,
               ( '@nQTY',                 CAST( @nQTY AS NVARCHAR(5)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cSKULabel, -- Report type
               @tSKULabel, -- Report params
               'rdtfnc_ECOMReturn',
               @nErrNo, -- OUTPUT, bypass error
               @cErrMsg OUTPUT
         END

         -- Back to RefNo/ASN, if fully receive and not allow over receive
         IF @cAllowOverReceive = '0'
         BEGIN
            -- Calc fully receive
            IF @cRefNoSKULookup = '1' AND @cRefNo <> ''
               SET @nBalQTY = @nBalQTY - 1
            ELSE
            BEGIN
               SET @nBalQTY = 0
               SELECT TOP 1 @nBalQTY = 1
               FROM ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               GROUP BY SKU
               HAVING ISNULL( SUM( QTYExpected), 0) <>
                      ISNULL( SUM( BeforeReceivedQty), 0)
            END

            -- Fully received
            IF @nBalQTY = 0
            BEGIN
               IF @cAutoReceiveNext = '1' OR @cFinalizeASN IN ('1', '2')
               BEGIN
                  IF @cFinalizeASN = '1' -- Always prompt
                  BEGIN
                     SET @cOutField01 = '' -- @cOption

                     -- Go to next screen
                     SET @nScn = @nScn_FinalizeASN
                     SET @nStep = @nStep_FinalizeASN

                     GOTO Quit
                  END

                  IF @cFinalizeASN = '2' -- No prompt, auto finalize
                  BEGIN
                     -- Finalize ASN
                     EXEC rdt.rdt_EcomReturn_Finalize
                        @nFunc         = @nFunc,
                        @nMobile       = @nMobile,
                        @cLangCode     = @cLangCode,
                        @nStep         = @nStep,
                        @nInputKey     = @nInputKey,
                        @cFacility     = @cFacility,
                        @cStorerKey    = @cStorerKey,
                        @cReceiptKey   = @cReceiptKey,
                        @cRefNo        = @cRefNo,
                        @nErrNo        = @nErrNo  OUTPUT,
                        @cErrMsg       = @cErrMsg OUTPUT

                     -- Go to finalilze screen, to retry
                     -- (cannot remain at current screen, due to it is not inside the transaction. ENTER again will double receive)
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

                        SET @cOutField01 = '' -- @cOption

                        -- Go to next screen
                        SET @nScn = @nScn_FinalizeASN
                        SET @nStep = @nStep_FinalizeASN

                        GOTO Quit
                     END
                  END

                  -- Prepare next screen var
                  SET @cOutField01 = '' -- @cRefNo
                  SET @cOutField02 = '' -- @cReceiptKey

                  EXEC rdt.rdtSetFocusField @nMobile, 1

                  -- Go to next screen
                  SET @nScn = @nScn_ASNRefNo
                  SET @nStep = @nStep_ASNRefNo

                  GOTO Quit
               END
            END
         END

         -- Get statistic
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20) -- Desc1
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)-- Desc2
         SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
         SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

         -- Reset data
         SELECT @cSKU = '', @nQTY = 1,
            @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
            @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
            @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         -- Go to next screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU

         GOTO Quit
      END
      ELSE
      BEGIN
         SET @cSuggID = ''
         SET @cSuggLOC = ''

         -- Check need to putaway
         IF @cExtendedPutawaySP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile      INT,           ' +
                  '@nFunc        INT,           ' +
                  '@cLangCode    NVARCHAR( 3),  ' +
                  '@nStep        INT,           ' +
                  '@nInputKey    INT,           ' +
                  '@cFacility    NVARCHAR( 5),  ' +
                  '@cStorerKey   NVARCHAR( 15), ' +
                  '@cReceiptKey  NVARCHAR( 10), ' +
                  '@cRefNo       NVARCHAR( 60), ' +
                  '@cID          NVARCHAR( 18), ' +
                  '@cLOC         NVARCHAR( 10), ' +
                  '@cSKU         NVARCHAR( 20), ' +
                  '@nQTY         INT,           ' +
                  '@cReceiptLineNumber NVARCHAR( 5), ' +
                  '@cLottable01  NVARCHAR( 18), ' +
                  '@cLottable02  NVARCHAR( 18), ' +
                  '@cLottable03  NVARCHAR( 18), ' +
                  '@dLottable04  DATETIME,      ' +
                  '@dLottable05  DATETIME,      ' +
                  '@cLottable06  NVARCHAR( 30), ' +
                  '@cLottable07  NVARCHAR( 30), ' +
                  '@cLottable08  NVARCHAR( 30), ' +
                  '@cLottable09  NVARCHAR( 30), ' +
                  '@cLottable10  NVARCHAR( 30), ' +
                  '@cLottable11  NVARCHAR( 30), ' +
                  '@cLottable12  NVARCHAR( 30), ' +
                  '@dLottable13  DATETIME,      ' +
                  '@dLottable14  DATETIME,      ' +
                  '@dLottable15  DATETIME,      ' +
                  '@cSuggID      NVARCHAR( 18)  OUTPUT, ' +
                  '@cSuggLOC     NVARCHAR( 10)  OUTPUT, ' +
                  '@nErrNo       INT            OUTPUT, ' +
                  '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END

         -- Enable field
         SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
         SET @cFieldAttr04 = ''
         SET @cFieldAttr06 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr10 = ''

         -- Prepare next screen variable
         SET @cOutField01 = @cSuggID
         SET @cOutField02 = CASE WHEN @cDefaultIDAsSuggID = '1' THEN @cSuggID ELSE '' END -- ID
         SET @cOutField03 = @cSuggLOC
         SET @cOutField04 = CASE WHEN @cDefaultLOCAsSuggLOC = '1' THEN @cSuggLOC ELSE @cDefaultToLOC  END -- LOC

         IF @cDisableToIDField = '1'
            SET @cFieldAttr02 = 'O'
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SuggID

         -- Go to ID LOC screen
         SET @nScn = @nScn_IDLOC
         SET @nStep = @nStep_IDLOC

         GOTO Quit
      END
   END

   Step_SerialNo_Quit:
   BEGIN
      -- SKU
      IF @nFromScn = @nScn_SKU
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  -- SKU desc 2
         SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
         SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         -- Go to next screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU

         -- Extended Info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
                  ' @tExtInfoVar, @cExtendedInfo OUTPUT'
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nAfterStep    INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cRefNo        NVARCHAR( 60), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@nQTY          INT,           ' +
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
                  '@cData1        NVARCHAR( 60), ' +
                  '@cData2        NVARCHAR( 60), ' +
                  '@cData3        NVARCHAR( 60), ' +
                  '@cData4        NVARCHAR( 60), ' +
                  '@cData5        NVARCHAR( 60), ' +
                  '@cOption       NVARCHAR( 1),  ' +
                  '@dArriveDate   DATETIME,      ' +
                  '@tExtInfoVar   VariableTable READONLY, ' +
                  '@cExtendedInfo NVARCHAR( 20) OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep_SerialNo, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
                  @tExtInfoVar, @cExtendedInfo OUTPUT

               IF @cExtendedInfo <> ''
                  SET @cOutField15 = @cExtendedInfo
            END
         END
      END

      -- Lottable
      ELSE IF @nFromScn = @nScn_Lottables
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
            @cReceiptKey,
            @nFunc

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMorePage = 1 -- Yes
         BEGIN
            -- Go to dynamic lottable screen
            SET @nScn = @nScn_Lottables
            SET @nStep = @nStep_Lottables

            -- To bypass ExtendedInfo override OutField15 required by dynamic lottable
            GOTO Quit
         END
      END
   END
END
GOTO Quit

/***********************************************************************************
Scn = 5647. Subreason screen
    Subreason (field01, input)
************************************************************************************/
Step_CondReason:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cConditionCode = CASE WHEN @cFieldAttr01 = 'O' THEN @cOutField01 ELSE @cInField01 END
      SET @cSubreasonCode = CASE WHEN @cFieldAttr02 = 'O' THEN @cOutField02 ELSE @cInField02 END

      -- Check condition code valid
      IF @cConditionCode NOT IN ('', 'OK')
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE Listname = 'ASNREASON'
               AND Code = @cConditionCode
               AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 145983
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Cond Code
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ConditionCode
            GOTO Quit
         END
      END

      -- Check sub reason code valid
      IF @cSubreasonCode <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE Listname = 'ASNSUBRSN'
               AND Code = @cSubreasonCode
               AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 145984
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Subreason
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SubreasonCode
            GOTO Quit
         END
      END
      
     -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtValidVar (Variable, Value) VALUES
               ('@cConditionCode', @cConditionCode), 
               ('@cSubreasonCode', @cSubreasonCode)
            
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
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
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Enable field
         SET @cFieldAttr01 = '' -- SubReasonCode
         SET @cFieldAttr02 = '' -- ConditionCode

         -- Go to dynamic lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         GOTO Quit
      END

      -- Serial No
      IF @cSerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, @nQTY, 'CHECK', 'ASN', @cReceiptKey,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '2'

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            -- Enable field
            SET @cFieldAttr01 = '' -- SubReasonCode
            SET @cFieldAttr02 = '' -- ConditionCode

            -- Go to Serial No screen
            SET @nFromScn = @nScn
            SET @nScn = @nScn_SerialNo
            SET @nStep = @nStep_SerialNo

            GOTO Quit
         END
      END

      -- Already key in toid & toloc, receive and stay in sku screen
      IF @cPreToIDLOC = '1'
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN Step_CondReason -- For rollback or commit only our own transaction

         -- Receive
         EXEC rdt.rdt_EcomReturn_Confirm
            @nFunc               = @nFunc,
            @nMobile             = @nMobile,
            @cLangCode           = @cLangCode,
            @cStorerKey          = @cStorerKey,
            @cFacility           = @cFacility,
            @dArriveDate         = @dArriveDate,
            @cReceiptKey         = @cReceiptKey,
            @cRefNo              = @cRefNo,
            @cToLoc              = @cLOC,
            @cToID               = @cID,
            @cSKUCode            = @cSKU,
            @cSKUUOM             = @cUOM,
            @nSKUQTY             = @nQTY,
            @cLottable01         = @cLottable01,
            @cLottable02         = @cLottable02,
            @cLottable03         = @cLottable03,
            @dLottable04         = @dLottable04,
            @dLottable05         = @dLottable05,
            @cLottable06         = @cLottable06,
            @cLottable07         = @cLottable07,
            @cLottable08         = @cLottable08,
            @cLottable09         = @cLottable09,
            @cLottable10         = @cLottable10,
            @cLottable11         = @cLottable11,
            @cLottable12         = @cLottable12,
            @dLottable13         = @dLottable13,
            @dLottable14         = @dLottable14,
            @dLottable15         = @dLottable15,
            @cData1              = @cData1,
            @cData2              = @cData2,
            @cData3              = @cData3,
            @cData4              = @cData4,
            @cData5              = @cData5,
            @cConditionCode      = @cConditionCode,
            @cSubreasonCode      = @cSubreasonCode,
            @cSerialNo           = @cSerialNo,
            @nSerialQTY          = @nSerialQTY,
            @tConfirmVar         = @tConfirmVar,
            @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
            @nErrNo              = @nErrNo    OUTPUT,
            @cErrMsg             = @cErrMsg   OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN Step_CondReason
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
                  ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cRefNo        NVARCHAR( 60), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@nQTY          INT,           ' +
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
                  '@cData1        NVARCHAR( 60), ' +
                  '@cData2        NVARCHAR( 60), ' +
                  '@cData3        NVARCHAR( 60), ' +
                  '@cData4        NVARCHAR( 60), ' +
                  '@cData5        NVARCHAR( 60), ' +
                  '@cOption       NVARCHAR( 1),  ' +
                  '@dArriveDate   DATETIME,      ' +
                  '@tExtUpdateVar VariableTable READONLY, ' +
                  '@nErrNo        INT           OUTPUT,   ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
                  @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN Step_SKU
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  GOTO Quit
               END
            END
         END

         COMMIT TRAN Step_SKU
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- Enable field
         SET @cFieldAttr01 = '' -- SubReasonCode
         SET @cFieldAttr02 = '' -- ConditionCode

         -- SKU label
         IF @cSKULabel <> ''
         BEGIN
            -- Common params
            INSERT INTO @tSKULabel (Variable, Value) VALUES
               ( '@cReceiptKey',          @cReceiptKey),
               ( '@cReceiptLineNumber',   @cReceiptLineNumber),
               ( '@cStorerKey',           @cStorerKey),
               ( '@cSKU',                 @cSKU),
               ( '@nQTY',                 CAST( @nQTY AS NVARCHAR(5)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cSKULabel, -- Report type
               @tSKULabel, -- Report params
               'rdtfnc_ECOMReturn',
               @nErrNo, -- OUTPUT, bypass error
               @cErrMsg OUTPUT
         END

         -- Back to RefNo/ASN, if fully receive and not allow over receive
         IF @cAllowOverReceive = '0'
         BEGIN
            -- Calc fully receive
            IF @cRefNoSKULookup = '1' AND @cRefNo <> ''
               SET @nBalQTY = @nBalQTY - 1
            ELSE
            BEGIN
               SET @nBalQTY = 0
               SELECT TOP 1 @nBalQTY = 1
               FROM ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               GROUP BY SKU
               HAVING ISNULL( SUM( QTYExpected), 0) <>
                      ISNULL( SUM( BeforeReceivedQty), 0)
            END

            -- Fully received
            IF @nBalQTY = 0
            BEGIN
               IF @cAutoReceiveNext = '1' OR @cFinalizeASN IN ('1', '2')
               BEGIN
                  IF @cFinalizeASN = '1' -- Always prompt
                  BEGIN
                     SET @cOutField01 = '' -- @cOption

                     -- Go to next screen
                     SET @nScn = @nScn_FinalizeASN
                     SET @nStep = @nStep_FinalizeASN

                     GOTO Quit
                  END

                  IF @cFinalizeASN = '2' -- No prompt, auto finalize
                  BEGIN
                     -- Finalize ASN
                     EXEC rdt.rdt_EcomReturn_Finalize
                        @nFunc         = @nFunc,
                        @nMobile       = @nMobile,
                        @cLangCode     = @cLangCode,
                        @nStep         = @nStep,
                        @nInputKey     = @nInputKey,
                        @cFacility     = @cFacility,
                        @cStorerKey    = @cStorerKey,
                        @cReceiptKey   = @cReceiptKey,
                        @nErrNo        = @nErrNo  OUTPUT,
                        @cErrMsg       = @cErrMsg OUTPUT

                     -- Go to finalilze screen, to retry
                     -- (cannot remain at current screen, due to it is not inside the transaction. ENTER again will double receive)
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

                        SET @cOutField01 = '' -- @cOption

                        -- Go to next screen
                        SET @nScn = @nScn_FinalizeASN
                        SET @nStep = @nStep_FinalizeASN

                        GOTO Quit
                     END
                  END

                  -- Prepare next screen var
                  SET @cOutField01 = '' -- @cRefNo
                  SET @cOutField02 = '' -- @cReceiptKey

                  EXEC rdt.rdtSetFocusField @nMobile, 1

                  -- Go to next screen
                  SET @nScn = @nScn_ASNRefNo
                  SET @nStep = @nStep_ASNRefNo

                  GOTO Quit
               END
            END
         END

         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20) -- Desc1
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)-- Desc2
         SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
         SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

         -- Reset data
         SELECT @cSKU = '', @nQTY = 1,
            @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
            @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
            @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         -- GOTO Quit
      END
      ELSE
      BEGIN
         SET @cSuggID = ''
         SET @cSuggLOC = ''

         -- Check need to putaway
         IF @cExtendedPutawaySP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile      INT,           ' +
                  '@nFunc        INT,           ' +
                  '@cLangCode    NVARCHAR( 3),  ' +
                  '@nStep        INT,           ' +
                  '@nInputKey    INT,           ' +
                  '@cFacility    NVARCHAR( 5),  ' +
                  '@cStorerKey   NVARCHAR( 15), ' +
                  '@cReceiptKey  NVARCHAR( 10), ' +
                  '@cRefNo       NVARCHAR( 60), ' +
                  '@cID          NVARCHAR( 18), ' +
                  '@cLOC         NVARCHAR( 10), ' +
                  '@cSKU         NVARCHAR( 20), ' +
                  '@nQTY         INT,           ' +
                  '@cReceiptLineNumber NVARCHAR( 5), ' +
                  '@cLottable01  NVARCHAR( 18), ' +
                  '@cLottable02  NVARCHAR( 18), ' +
                  '@cLottable03  NVARCHAR( 18), ' +
                  '@dLottable04  DATETIME,      ' +
                  '@dLottable05  DATETIME,      ' +
                  '@cLottable06  NVARCHAR( 30), ' +
                  '@cLottable07  NVARCHAR( 30), ' +
                  '@cLottable08  NVARCHAR( 30), ' +
                  '@cLottable09  NVARCHAR( 30), ' +
                  '@cLottable10  NVARCHAR( 30), ' +
                  '@cLottable11  NVARCHAR( 30), ' +
                  '@cLottable12  NVARCHAR( 30), ' +
                  '@dLottable13  DATETIME,      ' +
                  '@dLottable14  DATETIME,      ' +
                  '@dLottable15  DATETIME,      ' +
                  '@cSuggID      NVARCHAR( 18)  OUTPUT, ' +
                  '@cSuggLOC     NVARCHAR( 10)  OUTPUT, ' +
                  '@nErrNo       INT            OUTPUT, ' +
                  '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            END
         END

         -- Enable field
         SET @cFieldAttr01 = '' -- SubReasonCode
         SET @cFieldAttr02 = '' -- ConditionCode

         -- Prepare next screen variable
         SET @cOutField01 = @cSuggID
         SET @cOutField02 = CASE WHEN @cDefaultIDAsSuggID = '1' THEN @cSuggID ELSE '' END -- ID
         SET @cOutField03 = @cSuggLOC
         SET @cOutField04 = CASE WHEN @cDefaultLOCAsSuggLOC = '1' THEN @cSuggLOC ELSE @cDefaultToLOC  END -- LOC

         IF @cDisableToIDField = '1'
            SET @cFieldAttr02 = 'O'
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SuggID

         -- Go to ID LOC screen
         SET @nScn = @nScn_IDLOC
         SET @nStep = @nStep_IDLOC
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr01 = '' -- SubReasonCode
      SET @cFieldAttr02 = '' -- ConditionCode

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  -- SKU desc 2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   Step_CondReason_Quit:
   BEGIN
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_CondReason, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/***********************************************************************************
Step 12. Scn = 5648. Capture data screen
   Data1    (field01)
   Input1   (field02, input)
   .
   .
   .
   Data5    (field09)
   Input5   (field10, input)
***********************************************************************************/
Step_CaptureDtlData:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDtlData1 = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cDtlData2 = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cDtlData3 = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END
      SET @cDtlData4 = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE @cOutField08 END
      SET @cDtlData5 = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE @cOutField10 END

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10

      EXEC rdt.rdt_EcomReturn_CaptureDetailInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'UPDATE',
         @dArriveDate, @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU,
         @cDtlData1, @cDtlData2, @cDtlData3, @cDtlData4, @cDtlData5,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @tCaptureVar,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
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
               '@cData1        NVARCHAR( 60), ' +
               '@cData2        NVARCHAR( 60), ' +
               '@cData3        NVARCHAR( 60), ' +
               '@cData4        NVARCHAR( 60), ' +
               '@cData5        NVARCHAR( 60), ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_VerifySKU, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Get statistic
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

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
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         GOTO Quit
      END

      -- Serial No
      IF @cSerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, @nQTY, 'CHECK', 'ASN', @cReceiptKey,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '2'

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            -- Go to Serial No screen
            SET @nFromScn = @nScn
            SET @nScn = @nScn_SerialNo
            SET @nStep = @nStep_SerialNo

            GOTO Quit
         END
      END

      -- Already key in toid & toloc, receive and stay in sku screen
      IF @cPreToIDLOC = '1'
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN Step_CaptureDtlData -- For rollback or commit only our own transaction

         -- Receive
         EXEC rdt.rdt_EcomReturn_Confirm
            @nFunc               = @nFunc,
            @nMobile             = @nMobile,
            @cLangCode           = @cLangCode,
            @cStorerKey          = @cStorerKey,
            @cFacility           = @cFacility,
            @dArriveDate         = @dArriveDate,
            @cReceiptKey         = @cReceiptKey,
            @cRefNo              = @cRefNo,
            @cToLoc              = @cLOC,
            @cToID               = @cID,
            @cSKUCode            = @cSKU,
            @cSKUUOM             = @cUOM,
            @nSKUQTY             = @nQTY,
            @cLottable01         = @cLottable01,
            @cLottable02         = @cLottable02,
            @cLottable03         = @cLottable03,
            @dLottable04         = @dLottable04,
            @dLottable05         = @dLottable05,
            @cLottable06         = @cLottable06,
            @cLottable07         = @cLottable07,
            @cLottable08         = @cLottable08,
            @cLottable09         = @cLottable09,
            @cLottable10         = @cLottable10,
            @cLottable11         = @cLottable11,
            @cLottable12         = @cLottable12,
            @dLottable13         = @dLottable13,
            @dLottable14         = @dLottable14,
            @dLottable15         = @dLottable15,
            @cData1              = @cData1,
            @cData2              = @cData2,
            @cData3              = @cData3,
            @cData4              = @cData4,
            @cData5              = @cData5,
            @cConditionCode      = 'OK',
            @cSubreasonCode      = '',
            @cSerialNo           = @cSerialNo,
            @nSerialQTY          = @nSerialQTY,
            @tConfirmVar         = @tConfirmVar,
            @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
            @nErrNo              = @nErrNo    OUTPUT,
            @cErrMsg             = @cErrMsg   OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN Step_CaptureDtlData
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
                  ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cRefNo        NVARCHAR( 60), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@nQTY          INT,           ' +
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
                  '@cData1        NVARCHAR( 60), ' +
                  '@cData2        NVARCHAR( 60), ' +
                  '@cData3        NVARCHAR( 60), ' +
                  '@cData4        NVARCHAR( 60), ' +
                  '@cData5        NVARCHAR( 60), ' +
                  '@cOption       NVARCHAR( 1),  ' +
                  '@dArriveDate   DATETIME,      ' +
                  '@tExtUpdateVar VariableTable READONLY, ' +
                  '@nErrNo        INT           OUTPUT,   ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
                  @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN Step_CaptureDtlData
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  GOTO Quit
               END
            END
         END

         COMMIT TRAN Step_CaptureDtlData
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- SKU label
         IF @cSKULabel <> ''
         BEGIN
            -- Common params
            INSERT INTO @tSKULabel (Variable, Value) VALUES
               ( '@cReceiptKey',          @cReceiptKey),
               ( '@cReceiptLineNumber',   @cReceiptLineNumber),
               ( '@cStorerKey',           @cStorerKey),
               ( '@cSKU',                 @cSKU),
               ( '@nQTY',                 CAST( @nQTY AS NVARCHAR(5)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cSKULabel, -- Report type
               @tSKULabel, -- Report params
               'rdtfnc_ECOMReturn',
               @nErrNo, -- OUTPUT, bypass error
               @cErrMsg OUTPUT
         END

         -- Back to RefNo/ASN, if fully receive and not allow over receive
         IF @cAllowOverReceive = '0'
         BEGIN
            -- Calc fully receive
            IF @cRefNoSKULookup = '1' AND @cRefNo <> ''
               SET @nBalQTY = @nBalQTY - 1
            ELSE
            BEGIN
               SET @nBalQTY = 0
               SELECT TOP 1 @nBalQTY = 1
               FROM ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               GROUP BY SKU
               HAVING ISNULL( SUM( QTYExpected), 0) <>
                      ISNULL( SUM( BeforeReceivedQty), 0)
            END

            -- Fully received
            IF @nBalQTY = 0
            BEGIN
               IF @cAutoReceiveNext = '1' OR @cFinalizeASN IN ('1', '2')
               BEGIN
                  IF @cFinalizeASN = '1' -- Always prompt
                  BEGIN
                     SET @cOutField01 = '' -- @cOption

                     -- Go to next screen
                     SET @nScn = @nScn_FinalizeASN
                     SET @nStep = @nStep_FinalizeASN

                     GOTO Quit
                  END

                  IF @cFinalizeASN = '2' -- No prompt, auto finalize
                  BEGIN
                     -- Finalize ASN
                     EXEC rdt.rdt_EcomReturn_Finalize
                        @nFunc         = @nFunc,
                        @nMobile       = @nMobile,
                        @cLangCode     = @cLangCode,
                        @nStep         = @nStep,
                        @nInputKey     = @nInputKey,
                        @cFacility     = @cFacility,
                        @cStorerKey    = @cStorerKey,
                        @cReceiptKey   = @cReceiptKey,
                        @cRefNo        = @cRefNo,
                        @nErrNo        = @nErrNo  OUTPUT,
                        @cErrMsg       = @cErrMsg OUTPUT

                     -- Go to finalilze screen, to retry
                     -- (cannot remain at current screen, due to it is not inside the transaction. ENTER again will double receive)
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

                        SET @cOutField01 = '' -- @cOption

                        -- Go to next screen
                        SET @nScn = @nScn_FinalizeASN
                        SET @nStep = @nStep_FinalizeASN

                        GOTO Quit
                     END
                  END

                  -- Prepare next screen var
                  SET @cOutField01 = '' -- @cRefNo
                  SET @cOutField02 = '' -- @cReceiptKey

                  EXEC rdt.rdtSetFocusField @nMobile, 1

                  -- Go to next screen
                  SET @nScn = @nScn_ASNRefNo
                  SET @nStep = @nStep_ASNRefNo

                  GOTO Quit
               END
            END
         END

         -- Extended Info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate, ' +
                  ' @tExtInfoVar, @cExtendedInfo OUTPUT'
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nAfterStep    INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cRefNo        NVARCHAR( 60), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@nQTY          INT,           ' +
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
                  '@cData1        NVARCHAR( 60), ' +
                  '@cData2        NVARCHAR( 60), ' +
                  '@cData3        NVARCHAR( 60), ' +
                  '@cData4        NVARCHAR( 60), ' +
                  '@cData5        NVARCHAR( 60), ' +
                  '@cOption       NVARCHAR( 1),  ' +
                  '@dArriveDate   DATETIME,      ' +
                  '@tExtInfoVar   VariableTable READONLY, ' +
                  '@cExtendedInfo NVARCHAR( 20) OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep_VerifySKU, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cData1, @cData2, @cData3, @cData4, @cData5, @cOption, @dArriveDate,
                  @tExtInfoVar, @cExtendedInfo OUTPUT

               IF @cExtendedInfo <> ''
                  SET @cOutField15 = @cExtendedInfo
            END
         END

         -- Get statistic
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cRefNo
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20) -- Desc1
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)-- Desc2
         SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
         SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

         -- Reset data
         SELECT @cSKU = '', @nQTY = 1,
            @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
            @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
            @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
      ELSE
      BEGIN
         SET @cSuggID = ''
         SET @cSuggLOC = ''

         -- Check need to putaway
         IF @cExtendedPutawaySP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile      INT,           ' +
                  '@nFunc        INT,           ' +
                  '@cLangCode    NVARCHAR( 3),  ' +
                  '@nStep        INT,           ' +
                  '@nInputKey    INT,           ' +
                  '@cFacility    NVARCHAR( 5),  ' +
                  '@cStorerKey   NVARCHAR( 15), ' +
                  '@cReceiptKey  NVARCHAR( 10), ' +
                  '@cRefNo       NVARCHAR( 60), ' +
                  '@cID          NVARCHAR( 18), ' +
                  '@cLOC         NVARCHAR( 10), ' +
                  '@cSKU         NVARCHAR( 20), ' +
                  '@nQTY         INT,           ' +
                  '@cReceiptLineNumber NVARCHAR( 5), ' +
                  '@cLottable01  NVARCHAR( 18), ' +
                  '@cLottable02  NVARCHAR( 18), ' +
                  '@cLottable03  NVARCHAR( 18), ' +
                  '@dLottable04  DATETIME,      ' +
                  '@dLottable05  DATETIME,      ' +
                  '@cLottable06  NVARCHAR( 30), ' +
                  '@cLottable07  NVARCHAR( 30), ' +
                  '@cLottable08  NVARCHAR( 30), ' +
                  '@cLottable09  NVARCHAR( 30), ' +
                  '@cLottable10  NVARCHAR( 30), ' +
                  '@cLottable11  NVARCHAR( 30), ' +
                  '@cLottable12  NVARCHAR( 30), ' +
                  '@dLottable13  DATETIME,      ' +
                  '@dLottable14  DATETIME,      ' +
                  '@dLottable15  DATETIME,      ' +
                  '@cSuggID      NVARCHAR( 18)  OUTPUT, ' +
                  '@cSuggLOC     NVARCHAR( 10)  OUTPUT, ' +
                  '@nErrNo       INT            OUTPUT, ' +
                  '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, @cReceiptLineNumber,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            END
         END

         -- Prepare next screen variable
         SET @cOutField01 = @cSuggID
         SET @cOutField02 = CASE WHEN @cDefaultIDAsSuggID = '1' THEN @cSuggID ELSE '' END -- ID
         SET @cOutField03 = @cSuggLOC
         SET @cOutField04 = CASE WHEN @cDefaultLOCAsSuggLOC = '1' THEN @cSuggLOC ELSE @cDefaultToLOC  END -- LOC

         IF @cDisableToIDField = '1'
            SET @cFieldAttr02 = 'O'
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SuggID

         -- Go to ID LOC screen
         SET @nScn = @nScn_IDLOC
         SET @nStep = @nStep_IDLOC
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Get statistic
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20) -- Desc1
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)-- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      -- Reset data
      SELECT @cSKU = '', @nQTY = 1,
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
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

      Facility     = @cFacility,

      V_StorerKey  = @cStorerKey,
      V_UOM        = @cUOM,
      V_ReceiptKey = @cReceiptKey,
      V_LOC        = @cLOC,
      V_ID         = @cID,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKUDesc,
      V_QTY        = @nQTY,
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

      V_Integer1   = @nTotalQTYExp,
      V_Integer2   = @nTotalQTYRcv,
      V_Integer3   = @nBalQTY,
      V_Integer4   = @nFromScn,

      V_DateTime1  = @dArriveDate,

      V_String1    = @cRefNo,
      V_String2    = @cLottableCode,
      V_String3    = @cSuggID,
      V_String4    = @cSuggLOC,
      V_String5    = @cReceiptLineNumber,
      V_String7    = @cOption,
      V_String8    = @cCaptureReceiptDetailInfoSP,
      V_String9    = @cConditionCode,
      V_String10   = @cSubreasonCode,

      V_String16   = @cCaptureConditionReason,
      V_String17   = @cDispStyleColorSize,
      V_String18   = @cSerialNoCapture,
      V_String19   = @cDisableToIDField,
      V_String20   = @cCaptureReceiptInfoSP,
      V_String21   = @cDefaultToLOC,
      V_String22   = @cDecodeSKUSP,
      V_String23   = @cVerifySKU,
      V_String24   = @cExtendedPutawaySP,
      V_String25   = @cOverrideSuggestID,
      V_String26   = @cOverrideSuggestLOC,
      V_String27   = @cDefaultIDAsSuggID,
      V_String28   = @cDefaultLOCAsSuggLOC,
      V_String29   = @cExtendedInfoSP,
      V_String30   = @cExtendedInfo,
      V_String31   = @cExtendedValidateSP,
      V_String32   = @cExtendedUpdateSP,
      V_String33   = @cMultiSKUBarcode,
      V_String34   = @cCheckSKUInASN,
      V_String35   = @cRefNoSKULookup,
      V_String36   = @cFinalizeASN,
      V_String37   = @cPreToIDLOC,
      V_String38   = @cAllowOverReceive,
      V_String39   = @cAutoReceiveNext,
      V_String40   = @cSKULabel,

      V_String41   = @cData1,
      V_String42   = @cData2,
      V_String43   = @cData3,
      V_String44   = @cData4,
      V_String45   = @cData5,

      V_String46   = @cDtlData1,
      V_String47   = @cDtlData2,
      V_String48   = @cDtlData3,
      V_String49   = @cDtlData4,
      V_String50   = @cDtlData5,

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