SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/
/* Copyright: Maersk                                                            */
/* Purpose: SkipJack CycleCount SOS#227151                                      */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev    Author     Purposes                                        */
/* 2011-11-18 1.0    ChewKP     Created                                         */
/* 2012-10-30 1.1    James      SOS257258 - Bug fix (james01)                   */
/* 2013-04-04 1.2    Leong      SOS# 274011 - Add TraceInfo.                    */
/* 2013-05-13 1.3    SPChin     SOS278025 - Reset value for @cInField06 &       */
/*                                          @cInField07                         */
/* 2011-09-09 1.4    James      SOS315521-Get correct codelkup for lottable     */
/*                              Skip Lottable (james01)                         */
/* 2014-11-06 1.5    Audrey     SOS325165 - Bug fixed                    (ang01)*/
/* 2015-06-04 1.6    Leong      SOS# 342953 - Change variables.                 */
/* 2015-09-17 1.7    James      SOS350672 - Add defaultqty & disable EA field   */
/*                              (james02)                                       */
/* 2016-09-05 1.8    James      SOS375903 Add DecodeSP (james03)                */
/* 2016-10-26 1.9    James      Perf tuning (james03)                           */
/* 2018-05-14 2.0    James      WMS4614-Extend sql variable length (james04)    */
/* 2019-04-03 2.1    James      WMS7262-Add MultiSKUBarcode, ExtendedCfmSP,     */
/*                              ExtendedInfoSP, remove rdtIsValidQTY when       */
/*                              rdtMobRec loading (james05)                     */
/* 2019-10-16 2.2    YeeKung    INC0892773 BugFix (yeekung01)                   */
/* 2020-01-06 2.3    James      WMS-11550 Add ExtendedInfoSP @ scn 4 (james06)  */
/* 2021-04-26 2.4    James      WMS-16634 Add CheckSKUExistsInLoc (james07)     */
/*                              Skip step_1, misc bug fix                       */
/* 2021-05-07 2.5    James      WMS-16965 Add default opt in scn 3 (james08)    */
/* 2021-06-02 2.6    James      WMS-16634 Add update loc.lastcyclecount(james09)*/
/* 2022-07-22 2.7    James      WMS-19597 Add ExtendedDisplayQtySP (james10)    */
/* 2022-02-11 2.8    James      WMS-18635 Add check max qty input (james11)     */
/* 2023-08-01 2.9    James      WMS-23133 Add ExtendedUpdateSP at step3(james12)*/
/* 2023-08-03 3.0    James      WMS-23166 Rearrange ExtendedInfoSP (james13)    */
/* 2023-11-20 3.1    James      WMS-23429 Bug fix on Option not enabled(james15)*/
/* 2023-11-29 3.2    James      WMS-24279 Set focus on sku when come back from  */
/*                              sku not exists screen (james16)                 */
/* 2023-11-11 3.3    James      WMS-23133. Add new param ExtUpdateSP (james14)  */
/* 2024-01-16 3.4    James      WMS-23249 Add variance count (james15)          */
/*                              Allow adj posting even not CCSUP tasktype       */
/* 2024-04-19 3.5    James      WMS-25276 Skip scn 3 based on Loc setup(james16)*/
/* 2024-05-28 3.6    Dennis     FCR-235 Lottable Capture                        */
/* 2023-10-12 3.7    James      WMS-23113 Add Serial No (james17)               */
/*                              Add lottable06 ~ 15 parameters whenever required*/
/* 2024-05-28 3.8    JACKC      FCR-395 Merge WMS-23113 to V2                   */
/* 2024-11-12 3.9    Dennis     UWP-26828 Fix Conversion bug from str to dtime  */
/* 2024-11-21 4.0.0  NLT03      UWP-27346 Additional textbox displays           */
/* 2024-11-21 4.1.0  PXL003     UWP-27584 Fix SKU/UPC decode                    */
/********************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TM_CycleCount_SKU] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,
   @bSuccess   INT,

   @cPrinter   NVARCHAR( 20),
   @cUserName  NVARCHAR( 18),


   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),
   @cTaskDetailKey      NVARCHAR(10),
   @cLoc                NVARCHAR(10),
   @cID                 NVARCHAR(18),
   @cSKU                NVARCHAR(20),
   @cSuggFromLoc        NVARCHAR(10),
   @cSuggID             NVARCHAR(18),
   @cSuggSKU            NVARCHAR(20),
   @cUCC                NVARCHAR(20),
   @cCommodity          NVARCHAR(20),
   @c_outstring         NVARCHAR(255),
   @cContinueProcess    NVARCHAR(10),
   @cReasonStatus       NVARCHAR(10),
   @cAreakey            NVARCHAR(10),
   @cUserPosition       NVARCHAR(10),
   @nFromScn            INT,
   @nFromStep           INT,
   @cTMCCSingleScan     NVARCHAR(1),
   @nToFunc          INT,
   @nToScn              INT,
   @cTTMStrategykey     NVARCHAR(10),
   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),
   @cTTMTasktype        NVARCHAR(10),
   @cReasonCode         NVARCHAR(10),
   @cNextTaskdetailkey  NVARCHAR(10),
   @nPrevStep           INT,
   @cCCKey              NVARCHAR(10),
   @c_CCDetailKey       NVARCHAR(10),
   @b_Success           INT,
   @n_Err               INT,
   @c_ErrMsg            NVARCHAR(20),
   @cSKUDescr           NVARCHAR(60),
   @cLotLabel01         NVARCHAR( 20),
   @cLotLabel02         NVARCHAR( 20),
   @cLotLabel03         NVARCHAR( 20),
   @cLotLabel04         NVARCHAR( 20),
   @cLotLabel05         NVARCHAR( 20),
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @cLottable04         NVARCHAR( 16),
   @cLottable05         NVARCHAR( 16),
   @nUCCQty             INT,
   @nQty                INT,
   @cOptions            NVARCHAR( 1),
   @cInSKU              NVARCHAR(20),
   @nSKUCnt             INT,
   @cLottable01_Code    NVARCHAR( 30),
   @cLottable02_Code    NVARCHAR( 30),
   @cLottable03_Code    NVARCHAR( 30),
   @cLottable04_Code    NVARCHAR( 30),
   @cLottable05_Code    NVARCHAR( 30),
   @nCountLot           INT,
   @cListName           NVARCHAR( 20),
   @cLottableLabel      NVARCHAR( 20),
   @cShort              NVARCHAR( 10),
   @cStoredProd         NVARCHAR( 250),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,

   @cHasLottable        NVARCHAR( 1),
   @cSourcekey          NVARCHAR(15),
   @cTempLottable01     NVARCHAR( 18),
   @cTempLottable02     NVARCHAR( 18),
   @cTempLottable03     NVARCHAR( 18),
   @dTempLottable04     DATETIME,
   @dTempLottable05     DATETIME,
   @cPUOM               NVARCHAR(1),
   @cPUOM_Desc          NVARCHAR(5),
   @cActPQTY            NVARCHAR( 5),
   @cActMQTY            NVARCHAR( 5),
   @nRowID              INT,
   @nQtyAval            INT,
   @nPQty               INT,
   @nMQty               INT,
   @cMUOM_Desc          NVARCHAR(5),
   @nPUOM_Div           INT,
   @nActQTY             INT, -- Actual QTY
   @nActMQTY            INT, -- Actual keyed in master QTY
   @nActPQTY            INT, -- Actual keyed in prefered QTY
   @nPrevScreen         INT,
   @c_modulename        NVARCHAR( 30),
   @c_Activity          NVARCHAR( 10),
   @cCCType             NVARCHAR( 10),
   @cCCOption           NVARCHAR(  1),
   @cPickMethod         NVARCHAR( 10),
   @cSKUDescr1          NVARCHAR( 20),
   @cSKUDescr2          NVARCHAR( 20),
   @cCCDetailKey        NVARCHAR( 10),
   @cCounted            NVARCHAR(1),
   @cNewSKUorLottable   NVARCHAR(1),
   @cCCGroupExLottable05  NVARCHAR(1),
   @nLottableCount      INT,
   @nLottableCountTotal INT,
   @nQTYAvail           INT,
   @nSystemQty          INT,
   @cAlertMessage       NVARCHAR( 255),
   @cLOT                NVARCHAR( 10),
   @cLottableCode       NVARCHAR( 30),
   @nMorePage           INT,
   @cEnableAllLottables    NVARCHAR( 1),

   -- (james02)
   @cSkipLottable           NVARCHAR( 1),
   @cSkipLottable01         NVARCHAR( 1),
   @cSkipLottable02         NVARCHAR( 1),
   @cSkipLottable03         NVARCHAR( 1),
   @cSkipLottable04         NVARCHAR( 1),
   @cStorerConfig_UCC       NVARCHAR( 1),
   @cDefaultQty             NVARCHAR( 5),
   @cActSKU                 NVARCHAR( 20),
   @cExtendedInfoSP         NVARCHAR( 20),
   @cExtendedInfo           NVARCHAR( 20),
   @cSQL                    NVARCHAR( Max),
   @cSQLParam               NVARCHAR( Max),
   @nDefaultQty             INT,

   -- (james03)
   @nSKUQTY             INT,
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
   @cExtCfmSP           NVARCHAR( 20),
   @cMultiSKUBarcode    NVARCHAR( 1),
   @cCheckSKUExistsInLoc   NVARCHAR( 1),
   @cTMCCSKUSkipScreen1    NVARCHAR( 1),
   @cDefaultOption         NVARCHAR( 1),
   @cSkipAlertScreen       NVARCHAR( 1),
   @cMaxQtyValue           NVARCHAR( 5),
   @nMaxQtyValue           INT = 0,
   @cExtendedUpdateSP      NVARCHAR( 20),
   @cExtendedDisplayQtySP  NVARCHAR( 20),
   @tExtendedDisplayQty    VARIABLETABLE,
   @cFlowThruScreen        NVARCHAR( 10),
   @cTMCCVarianceCountSP   NVARCHAR( 20),
   @nReCountLoc            INT,
   @cExtendedValidateSP    NVARCHAR( 20),
   @cTMCCAllowPostAdj      NVARCHAR( 1),
   @nCountNo               INT,    
   @cSerialNoCapture       NVARCHAR(1),
   @cDocType               NVARCHAR( 1),
   @cSerialNo              NVARCHAR( 30),
   @nSerialQTY             INT,
   @nMoreSNO               INT,
   @nBulkSNO               INT,
   @nBulkSNOQTY            INT,
   @cDiffQTYScanSNO        NVARCHAR( 1),
   
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

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,
   @cPUOM            = V_UOM,
   @cTaskDetailKey   = V_TaskDetailKey,
   @cSuggFromLoc     = V_Loc,
   @cID              = V_ID,
   @cSKU             = V_SKU,

   @cLottable01       = V_Lottable01,
   @cLottable02       = V_Lottable02,
   @cLottable03       = V_Lottable03,
   @dLottable04       = V_Lottable04,
   @dLottable05       = V_Lottable05,
   @cLottable06       = V_Lottable06,
   @cLottable07       = V_Lottable07,
   @cLottable08       = V_Lottable08,
   @cLottable09       = V_Lottable09,
   @cLottable10       = V_Lottable10,
   @cLottable11       = V_Lottable11,
   @cLottable12       = V_Lottable12,
   @dLottable13       = V_Lottable13,
   @dLottable14       = V_Lottable14,
   @dLottable15       = V_Lottable15,

   @cLotLabel01      = V_LottableLabel01,
   @cLotLabel02      = V_LottableLabel02,
   @cLotLabel03      = V_LottableLabel03,
   @cLotLabel04      = V_LottableLabel04,
   @cLotLabel05      = V_LottableLabel05,

   @cBarcode         = V_Barcode,

   @nFromStep       = V_FromStep,  
   @nFromScn        = V_FromScn,  
   @nActQTY         = V_Qty,  
   @nUCCQty         = V_Integer1,  
   @nDefaultQty     = V_Integer2,  
   @nLottableCount  = V_Integer3,  
   @nRowID          = V_Integer4,  
   @nLottableCountTotal = V_Integer5,  
   @nMaxQtyValue    = V_Integer6,  
   @nReCountLoc     = V_Integer7,
   @nPrevScreen     = V_Integer8,
   @nPrevStep       = V_Integer9,

   @cCCKey           = V_String1,
   @cSuggID          = V_String2,
   @cCommodity       = V_String3,
   @cUCC             = V_String4,
   @cDefaultOption   = V_String5,
   @cTMCCSKUSkipScreen1 = V_String6,
   @cMultiSKUBarcode = V_String7,
   @cDefaultQty      = V_String8,
   @cSkipLottable    = V_String9,
   @cLoc             = V_String10,
   @cCheckSKUExistsInLoc = V_String11,
   @cSkipAlertScreen = V_String12,
   @cSuggSKU         = V_String13,
   @cPickMethod      = V_String14,
   @cSKUDescr1       = V_String15,
   @cSKUDescr2       = V_String16,
   @cCCDetailKey     = V_String17,
   @cExtendedInfoSP  = V_String18,
   @cDecodeSP        = V_String19,

   -- Module SP Variable V_String 20 - 26 --
   @cCCOption           = V_String20,
   @cNewSKUorLottable   = V_String21,
   @cHasLottable        = V_String22,
   @cCCGroupExLottable05= V_String23,
   @cExtendedInfo       = V_String24,
   @cExtCfmSP           = V_String26,
   @cExtendedUpdateSP   = V_String27,
   @cTMCCVarianceCountSP= V_String28,
   
   -- Start of Common Variable use by UCC, SKU, SingleScan CC
   @cExtendedDisplayQtySP  = V_String29,
   @cDiffQTYScanSNO        = V_String30,

   @cAreakey               = V_String32,
   @cTTMStrategykey        = V_String33,
   @cTTMTasktype           = V_String34,
   @cRefKey01              = V_String35,
   @cRefKey02              = V_String36,
   @cRefKey03              = V_String37,
   @cRefKey04              = V_String38,
   @cRefKey05              = V_String39,
   @cTMCCAllowPostAdj      = V_String40,
   @cSerialNoCapture       = V_String41,
   @cLottableCode          = V_String42,  

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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM RDT.RDTMOBREC with (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1768  -- TM CC - SKU
BEGIN
   -- Redirect to respective screen
   DECLARE @nScnEditScn       INT
          ,@nStepEditScn      INT

   SET @nScnEditScn = 2940
   SET @nStepEditScn = 1

   SET @cSkipLottable = rdt.RDTGetConfig( @nFunc, 'SkipLottable', @cStorerKey)

   -- (james03)
   SET @cExtCfmSP = rdt.RDTGetConfig( @nFunc, 'ExtendedCfmSP', @cStorerKey)
   IF @cExtCfmSP = '0'
      SET @cExtCfmSP = ''

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   -- Get stored proc name for extended info (james40)
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- (james03)
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   -- (james07)
   SET @cCheckSKUExistsInLoc = rdt.RDTGetConfig( @nFunc, 'CheckSKUExistsInLoc', @cStorerKey)

   SET @cTMCCSKUSkipScreen1 = rdt.RDTGetConfig( @nFunc, 'TMCCSKUSkipScreen1', @cStorerKey)

   SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)

   -- (james08)
   SET @cDefaultOption = rdt.RDTGetConfig( @nFunc, 'DefaultOption', @cStorerkey)
   IF @cDefaultOption = '0'
      SET @cDefaultOption = ''

   SET @cSkipAlertScreen = rdt.RDTGetConfig( @nFunc, 'SkipAlertScreen', @cStorerkey)

   -- (james10)
   SET @cExtendedDisplayQtySP = rdt.RDTGetConfig( @nFunc, 'ExtendedDisplayQtySP', @cStorerKey)
   IF @cExtendedDisplayQtySP = '0'
      SET @cExtendedDisplayQtySP = ''

   -- (james11)
   SET @cMaxQtyValue = rdt.RDTGetConfig( @nFunc, 'MaxQtyValue', @cStorerkey)
   IF RDT.rdtIsValidQTY( @cMaxQtyValue, 0) = 1
      SET @nMaxQtyValue = CAST( @cMaxQtyValue AS INT)

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   SET @cTMCCVarianceCountSP = rdt.RDTGetConfig( @nFunc, 'TMCCVarianceCountSP', @cStorerKey)
   IF @cTMCCVarianceCountSP = '0'
      SET @cTMCCVarianceCountSP = ''

   SET @cTMCCAllowPostAdj = rdt.RDTGetConfig( @nFunc, 'TMCCAllowPostAdj', @cStorerKey)
   IF @cTMCCAllowPostAdj = '0'
      SET @cTMCCAllowPostAdj = ''
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)

   SET @cDiffQTYScanSNO = rdt.RDTGetConfig( @nFunc, 'DiffQTYScanSNO', @cStorerKey)

   SET @cCCGroupExLottable05 = rdt.RDTGetConfig( @nFunc, 'CCGroupExLottable05', @cStorerkey)

   --IF @nStep = 0 GOTO Step_0   -- TM CC- SKU
   IF @nStep = 1 GOTO Step_1   -- Scn = 2940. SKU
   IF @nStep = 2 GOTO Step_2   -- Scn = 2941. Qty -- Lottables
   IF @nStep = 3 GOTO Step_3   -- Scn = 2942. Options
   IF @nStep = 4 GOTO Step_4   -- Scn = 2943. Alert
   IF @nStep = 5 GOTO Step_5   -- Scn = 3570. Multi SKU Barocde
   IF @nStep = 6 GOTO Step_6   -- Scn = 2944. SKU Not Exists
   IF @nStep = 7 GOTO Step_7   -- Scn = 3490. Lottable    
   IF @nStep = 8 GOTO Step_8   -- Scn = 4831. Serial no

END


/********************************************************************************
Step 1. Scn = 2940.
   Loc (Field01)
   ID  (Field02)
   SKU (Field06, ) Optional PickMethod = 'SKU'
   SKU (Field03, input)


********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Initialize all Local Variables
      SET @nActQTY = 0
      SET @nFromScn = 0
      SET @nFromStep = 0
      SET @cCCOption = ''
      SET @cNewSKUorLottable = ''
      SET @cHasLottable = ''
      SET @nLottableCount = ''
      SET @nLottableCountTotal = ''
      SET @cSKUDescr1 = ''
      SET @cSKUDescr2 = ''

      SET @cLottable01 = ''  
      SET @cLottable02 = ''  
      SET @cLottable03 = ''  
      SET @dLottable04 = ''  
      SET @dLottable05 = ''  
      SET @cLottable06 = ''  
      SET @cLottable07 = ''  
      SET @cLottable08 = ''  
      SET @cLottable09 = ''  
      SET @cLottable10 = ''  
      SET @cLottable11 = ''  
      SET @cLottable12 = ''  
      SET @dLottable13 = ''  
      SET @dLottable14 = ''  
      SET @dLottable15 = ''  

      SET @cLotLabel01 = ''
      SET @cLotLabel02 = ''
      SET @cLotLabel03 = ''
      SET @cLotLabel04 = ''
      SET @cLotLabel05 = ''

      SET @cExtendedInfo = @cOutField15

      SELECT @cPUOM = V_UOM
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      SET @cCommodity = ISNULL(RTRIM(@cInField03),'')

      IF @cPickMethod = 'LOC' AND rdt.RDTGetConfig( @nFunc, 'TMCCBYSKUVERIFYSKUSTORERKEY', @cStorerkey) = '1'
      BEGIN
         SET @cStorerKey = ''
      END

      IF @cStorerKey = ''
      BEGIN
         SET @cStorerKey = ISNULL(RTRIM(@cInField05),'')
      END

      IF @cCommodity = ''
      BEGIN

         SET @nPrevStep = 0
         SET @nPrevScreen  = 0

         SET @nPrevStep = @nStep
         SET @nPrevScreen = @nScn

         SET @cOutField01 = ''

         -- GOTO Next Screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO QUIT
      END

      IF @cDecodeSP <> ''
      BEGIN
         SET @cBarcode = ISNULL(RTRIM(@cInField03),'')
         SET @cUPC = @cBarcode
         SET @nQTY = @nActQTY

         -- Standard decode
         IF @cDecodeSP = '1'
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cTaskDetailKey, @cLOC, @cID, ' +
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
               ' @cBarcode       NVARCHAR( 60), ' +
               ' @cTaskDetailKey NVARCHAR( 10), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
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
               ' @cUserDefine01  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine02  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine03  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine04  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine05  NVARCHAR( 60)  OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cTaskDetailKey, @cLOC, @cID,
               @cUPC          OUTPUT, @nQTY           OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

         END

         SET @cCommodity = @cUPC
         SET @nActQTY = @nQTY

         -- The sku/qty screen doesn't has suggested qty
         -- If decode return qty then default it
         IF @nQty > 0
            SET @cDefaultQty = @nQty

      END   -- End for DecodeSP

      SET @cCheckSKUExistsInLoc = rdt.RDTGetConfig( @nFunc, 'CheckSKUExistsInLoc', @cStorerKey)  

      SELECT @bsuccess = 1

      SET @nSKUCnt = 0

    -- Get SKU barcode count

      EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cCommodity
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT
         ,@cSKUStatus  = 'ACTIVE'

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 74502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO Step_1_Fail
      END

      -- Validate barcode return multiple SKU
      IF @cStorerKey = ''
      BEGIN

         IF @nSKUCnt > 1
         BEGIN
            SET @cOutField03 = '' --@cCommodity
            SET @cOutField04 = 'StorerKey:'
            SET @cOutField05 = ''

            SET @cFieldAttr04 = ''
            SET @cFieldAttr05 = ''

            GOTO QUIT
         END
      END
      ELSE
      BEGIN
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
                  @cCommodity     OUTPUT,
                  @nErrNo   OUTPUT,
                  @cErrMsg  OUTPUT,
                  '',    -- DocType
                  ''

               IF @nErrNo = 0 -- Populate multi SKU screen
               BEGIN
                  SET @cOutField13 = ''
                  -- Go to Multi SKU screen
                  SET @nFromScn = @nScn
                  SET @nScn = 3570
                  SET @nStep = @nStep + 4
                  GOTO Quit
               END
               IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               BEGIN
                  SET @nErrNo = 0
                  SET @cSKU = @cUPC
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 74533
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
               GOTO Step_1_Fail
            END
         END
      END

      -- Validate SKU/UPC
      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cCommodity    OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT
         ,@cSKUStatus  = 'ACTIVE'

      IF @bSuccess = 0
      BEGIN
         SET @nErrNo = 74514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_1_Fail
      END

      IF @cPickMethod = 'SKU'
      BEGIN
         IF @cSuggSKU <> @cCommodity
         BEGIN
            SET @nErrNo = 74517
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid SKU'
            GOTO Step_1_Fail
         END
      END

      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCkey = @cCCKey
                  AND CCSheetNo = @cTaskDetailKey
                  AND RefNo <> '' )
      BEGIN
         SET @nErrNo = 74528
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'MixCountTypeNotAllowed'
         GOTO Step_1_Fail
      END

      IF ISNULL(@cStorerKey,'') = ''
      BEGIN
         SET @nErrNo = 74525
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'InvalidStorer'
         GOTO Step_1_Fail
      END

      SET @cSKU = @cCommodity

      IF @cCheckSKUExistsInLoc = '1'  
      BEGIN  
         IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)  
                         WHERE CCKey = @cCCKey  
                       AND   Loc = @cLoc  
                       AND   (( @cID = '') OR ( ID = @cID))  
                       AND   SKU = @cSKU  
                       AND   Status  < '9'  
                       AND   CCSheetNo = @cTaskDetailKey) AND @nFromStep <> 6    
         BEGIN  
            SET @cOutField01 = ''  
            SET @nFromScn = @nScn
            SET @nFromStep = @nStep
            SET @nScn = @nScn + 4  
            SET @nStep = @nStep + 5  
            
            GOTO Quit  
         END  
      END  

      SET @cSKUDescr = ''
      SET @cMUOM_Desc = ''
      SET @cPUOM_Desc = ''

      SET @nQtyAval = 0
      SET @nQty = 0
      SET @nPUOM_Div = 0
      SET @nMQTY = 0
      SET @nPQTY = 0

      SET @cFieldAttr06 = ''  
      SET @cFieldAttr07 = ''  
      SET @cFieldAttr12 = ''  

      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL

      SELECT
           @cSKUDescr = SKU.DESCR
         , @cMUOM_Desc  = Pack.PackUOM3
         , @cPUOM_Desc  =
         CASE @cPUOM
            WHEN '2' THEN Pack.PackUOM1 -- Case
            WHEN '3' THEN Pack.PackUOM2 -- Inner pack
            WHEN '6' THEN Pack.PackUOM3 -- Master unit
            WHEN '1' THEN Pack.PackUOM4 -- Pallet
            WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
            WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
         END
         ,  @nPUOM_Div  = CAST( IsNULL(
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
      WHERE SKU.SKU = @cSKU
        AND SKU.StorerKey = @cStorerKey

      SET @cCCDetailKey = ''

      IF @cCCGroupExLottable05 = '1'
      BEGIN
         SELECT TOP 1
                  @cLottable01 = CC.Lottable01
                , @cLottable02 = CC.Lottable02
                , @cLottable03 = CC.Lottable03
                , @dLottable04 = CC.Lottable04  --yeekung01
                , @nQtyAval    =  SUM(CC.SystemQty)
                , @cCCDetailKey = MIN(CC.CCDetailKey)
                , @nQty        = SUM(CC.Qty)
         FROM dbo.CCDetail CC WITH (NOLOCK)
         WHERE CC.SKU = @cSKU
         AND CC.CCKey = @cCCKey
         AND CC.Loc   = @cLoc
         AND CC.ID    = @cID
         AND Status < '9'
         AND CC.CCSheetNo = @cTaskDetailKey
         GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04
         ORDER BY MIN(CC.CCDetailKey)

         SET @nLottableCountTotal = 0
         SELECT @nLottableCountTotal =  COUNT(1)
         FROM dbo.CCDetail CC WITH (NOLOCK)
         WHERE CC.SKU = @cSKU
         AND CC.CCKey = @cCCKey
         AND CC.Loc   = @cLoc
         AND CC.ID    = @cID
         AND Status < '9'
         AND CC.CCSheetNo = @cTaskDetailKey
         GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04
      END
      ELSE
      BEGIN
         SELECT TOP 1
                  @cLottable01 = CC.Lottable01
                , @cLottable02 = CC.Lottable02
                , @cLottable03 = CC.Lottable03
                , @dLottable04 = CC.Lottable04  --yeekung01
                , @dLottable05 = CC.Lottable05  --yeekung01
                , @nQtyAval    =  CC.SystemQty
                , @cCCDetailKey = CC.CCDetailKey
                , @nQty        = CC.Qty
         FROM dbo.CCDetail CC WITH (NOLOCK)
         WHERE CC.SKU = @cSKU
         AND CC.CCKey = @cCCKey
         AND CC.Loc   = @cLoc
         AND CC.ID    = @cID
         AND Status < '9'
         AND CC.CCSheetNo = @cTaskDetailKey
         ORDER BY CCDetailKey

         SET @nLottableCountTotal = 0
         SELECT @nLottableCountTotal = COUNT(1)
         FROM dbo.CCDetail CC WITH (NOLOCK)
         WHERE CC.SKU = @cSKU
         AND CC.CCKey = @cCCKey
         AND CC.Loc   = @cLoc
         AND CC.ID    = @cID
         AND Status < '9'
       AND CC.CCSheetNo = @cTaskDetailKey
      END

      SET @cCounted = ''

      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCKey = @cCCKey
                  AND SKU = @cSKU
                  AND Loc = @cLoc
                  AND ID  = @cID
                  AND Status < '9'
                  AND Qty > 0
                  AND CCSheetNo = @cTaskDetailKey
                  AND CCdetailKey = @cCCDetailKey)
      BEGIN
         SET @nQtyAval = @nQty
         SET @cCounted = '1'
      END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nQtyAval
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQtyAval / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMQTY = @nQtyAval % @nPUOM_Div  -- Calc the remaining in master unit
      END

      -- Prepare Next Screen Variable
      SET @cSKUDescr1 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cSKUDescr2 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 1

      SET @cOutField01 = @cSKU
      SET @cOutField02 = @cSKUDescr1
      SET @cOutField03 = @cSKUDescr2

      SET @nLottableCount = 0
      SET @cOutField13 = CASE WHEN @cSkipLottable = '1' THEN ''
                              ELSE RTRIM(CAST(@nLottableCount AS NVARCHAR(4))) +  '/' +
                                   RTRIM(CAST(@nLottableCountTotal AS NVARCHAR(4)))
                              END

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField04 = ''
         SET @cOutField06 = ''
         SET @cFieldAttr06 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField04 = @cPUOM_Desc
         IF @cCounted = '1'
         BEGIN
            SET @cOutField06 = CAST( @nPQTY AS NVARCHAR( 5))
         END
         ELSE
         BEGIN
            SET @cOutField06 = ''
         END
      END

      IF @nPQTY <= 0
      BEGIN
         --SET @cOutField04 = ''
         SET @cOutField06 = ''
         SET @cOutField06 = ''
         SET @cFieldAttr06 = 'O'
      END

      SET @cOutField05 = @cMUOM_Desc

      IF @cCounted = '1'
      BEGIN
         SET @cOutField07 = CAST( @nMQTY AS NVARCHAR( 5))
      END
      ELSE
      BEGIN
         SET @cOutField07 = ''
      END

      IF @nPQTY > 0
         EXEC rdt.rdtSetFocusField @nMobile, 06
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 07

      SET @cFieldAttr08 = 'O'
      SET @cFieldAttr09 = 'O'
      SET @cFieldAttr10 = 'O'
      SET @cFieldAttr11 = 'O'

      IF @cSkipLottable = '1'
      BEGIN
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cLottable01
         SET @cOutField09 = @cLottable02
         SET @cOutField10 = @cLottable03
         SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)
      END

      --SET @nDefaultQty = 0

      -- if default qty turned on then overwrite the actual MQty (james02)
      --SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)
      IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1
         SET @nDefaultQty = CAST( @cDefaultQty AS INT)
      ELSE
         SET @nDefaultQty = 0

      IF @nDefaultQty > 0
      BEGIN
         SET @cFieldAttr12 = ''
         SET @cOutField12 = ''
         SET @cFieldAttr06 = 'O'
         SET @cFieldAttr07 = 'O'

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
            SET @cOutField07 = @nDefaultQty
         ELSE
         BEGIN
            IF @nDefaultQty > @nPUOM_Div
            BEGIN
               SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM
               SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit
            END
            ELSE
               SET @cOutField07 = @nDefaultQty
         END
      END
      ELSE
      BEGIN
         SET @cFieldAttr12 = 'O'
         SET @cOutField12 = ''
      END

      -- Extended info
      IF @cExtendedDisplayQtySP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedDisplayQtySP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedDisplayQtySP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
               ' @cBarcode, @cPUOM, @nPUOM_Div, @cPUOM_Desc OUTPUT, @cMUOM_Desc OUTPUT, ' +
               ' @cFieldAttr06 OUTPUT, @cFieldAttr07 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, @cOutField06 OUTPUT, @cOutField07 OUTPUT, ' +
               ' @tExtendedDisplayQty '

            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTaskDetailKey  NVARCHAR( 10), ' +
               '@cCCKey          NVARCHAR( 10), ' +
               '@cCCDetailKey    NVARCHAR( 10), ' +
               '@cLoc            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nActQTY         INT, ' +
               '@cBarcode        NVARCHAR( 60), ' +
               '@cPUOM           NVARCHAR( 1), ' +
               '@nPUOM_Div       NVARCHAR( 5), ' +
               '@cPUOM_Desc      NVARCHAR( 5)   OUTPUT, ' +
               '@cMUOM_Desc      NVARCHAR( 5)   OUTPUT, ' +
               '@cFieldAttr06    NVARCHAR( 1)   OUTPUT, ' +
               '@cFieldAttr07    NVARCHAR( 1)   OUTPUT, ' +
               '@cOutField04     NVARCHAR( 60)  OUTPUT, ' +
               '@cOutField05     NVARCHAR( 60)  OUTPUT, ' +
               '@cOutField06     NVARCHAR( 60)  OUTPUT, ' +
               '@cOutField07     NVARCHAR( 60)  OUTPUT, ' +
               '@tExtendedDisplayQty   VARIABLETABLE READONLY'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
               @cBarcode, @cPUOM, @nPUOM_Div, @cPUOM_Desc OUTPUT, @cMUOM_Desc OUTPUT,
               @cFieldAttr06 OUTPUT, @cFieldAttr07 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, @cOutField06 OUTPUT, @cOutField07 OUTPUT,
               @tExtendedDisplayQty
         END
      END
      ELSE
      BEGIN
      -- if default qty turned on then overwrite the actual MQty (james02)
      --SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)
      IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1
            SET @nDefaultQty = CAST( @cDefaultQty AS INT)
         ELSE
            SET @nDefaultQty = 0

         IF @nDefaultQty > 0
         BEGIN
            SET @cFieldAttr12 = ''
            SET @cOutField12 = ''
            SET @cFieldAttr06 = 'O'
            SET @cFieldAttr07 = 'O'

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
               SET @cOutField07 = @nDefaultQty
            ELSE
            BEGIN
               IF @nDefaultQty > @nPUOM_Div
               BEGIN
                  SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM
                  SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit
               END
               ELSE
                  SET @cOutField07 = @nDefaultQty
            END
         END
         ELSE
         BEGIN
            SET @cFieldAttr12 = 'O'
            SET @cOutField12 = ''
         END

         IF @nPQTY > 0
            EXEC rdt.rdtSetFocusField @nMobile, 06
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 07
      END

      SET @cNewSKUorLottable = ''

      IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                    WHERE CCKey = @cCCKey
                    AND Loc     = @cLoc
                    AND ID      = @cID
                    AND SKU     = @cSKU
                    AND Status  < '9'
                    AND CCSheetNo = @cTaskDetailKey  )
      BEGIN
            SET @cEnableAllLottables = rdt.RDTGetConfig( @nFunc, 'EnableAllLottables', @cStorerKey)
            IF ISNULL(@cEnableAllLottables,'') = '1'
            BEGIN
               SET @cSkipLottable = '1'
               SELECT
                  @cLottableCode = LottableCode
               FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
               SET @cLottable01 = ''
               SET @cLottable02 = ''
               SET @cLottable03 = ''
               SET @dLottable04 = NULL
               SET @dLottable05 = NULL
               SET @cLottable06 = ''
               SET @cLottable07 = ''
               SET @cLottable08 = ''
               SET @cLottable09 = ''
               SET @cLottable10 = ''
               SET @cLottable11 = ''
               SET @cLottable12 = ''
               SET @dLottable13 = NULL
               SET @dLottable14 = NULL
               SET @dLottable15 = NULL

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
                  --V3.8 by jackc
                  --@cCCKey,
                  @cTaskDetailKey, --V3.8 by jackc END,
                  @nFunc

               IF @nErrNo <> 0
                  GOTO Step_1_Fail

               IF @nMorePage = 1 -- Yes
               BEGIN
                  -- Go to dynamic lottable screen
                  SET @nFromScn = @nScn
                  SET @nScn = 3990
                  SET @nStep = 7
               END
               GOTO QUIT 
            END
            -- SET to 1 for New Found SKU or Lottables
            SET @cNewSKUorLottable = '1'

            SET @cFieldAttr08 = ''
            SET @cFieldAttr09 = ''
            SET @cFieldAttr10 = ''
            SET @cFieldAttr11 = ''
            SET @cFieldAttr12 = ''
            SET @cFieldAttr13 = ''
            SET @cFieldAttr14 = ''
            SET @cFieldAttr15 = ''

            -- (james02)
            SELECT
               @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description]
                                       FROM dbo.CodeLKUP C WITH (NOLOCK)
                                       WHERE C.Code = S.Lottable01Label
                                       AND C.ListName = 'LOTTABLE01' AND C.Code <> ''
                                       AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                       ORDER By C.StorerKey DESC), ''),
               @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description]
                                       FROM dbo.CodeLKUP C WITH (NOLOCK)
                                       WHERE C.Code = S.Lottable02Label
                                       AND C.ListName = 'LOTTABLE02' AND C.Code <> ''
                                       AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                       ORDER By C.StorerKey DESC), ''),
               @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description]
                                       FROM dbo.CodeLKUP C WITH (NOLOCK)
                                       WHERE C.Code = S.Lottable03Label
                                       AND C.ListName = 'LOTTABLE03' AND C.Code <> ''
                                       AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                       ORDER By C.StorerKey DESC), ''),
               @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description]
                                       FROM dbo.CodeLKUP C WITH (NOLOCK)
                                       WHERE C.Code = S.Lottable04Label
                                       AND C.ListName = 'LOTTABLE04' AND C.Code <> ''
                                       AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                       ORDER By C.StorerKey DESC), ''),
               @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description]
                                       FROM dbo.CodeLKUP C WITH (NOLOCK)
                                       WHERE C.Code = S.Lottable05Label
                                       AND C.ListName = 'LOTTABLE05' AND C.Code <> ''
                                       AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                       ORDER By C.StorerKey DESC), ''),
               @cLottable05_Code = IsNULL( S.Lottable05Label, ''),
               @cLottable01_Code = IsNULL(S.Lottable01Label, ''),
               @cLottable02_Code = IsNULL(S.Lottable02Label, ''),
               @cLottable03_Code = IsNULL(S.Lottable03Label, ''),
               @cLottable04_Code = IsNULL(S.Lottable04Label, '')
            FROM dbo.SKU S WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
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
            /*  - Start                                                                                                         */
            /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
            /* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
            /* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
            /* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
            /*    Codelkup.Short = 'PRE' and Codelkup.Long = <SP Name>                                                          */
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
                  FROM dbo.CodeLkUp C WITH (NOLOCK)
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

                     EXEC dbo.ispLottableRule_Wrapper
                        @c_SPName            = @cStoredProd,
                        @c_ListName          = @cListName,
                        @c_Storerkey         = @cStorerKey,
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
                        @b_Success           = @bSuccess    OUTPUT,
                        @n_Err               = @nErrNo      OUTPUT,
                        @c_Errmsg            = @cErrMsg     OUTPUT,
                        @c_Sourcekey         = @cSourcekey,
                        @c_Sourcetype        = 'RDTRECEIPT'

                     --IF @b_success <> 1
                     IF ISNULL(@cErrMsg, '') <> ''
                     BEGIN
                        SET @cErrMsg = @cErrMsg
                        GOTO Step_1_Fail
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
                  END

                  -- increase counter by 1
                  SET @nCountLot = @nCountLot + 1
               END -- nCount
            END -- Lottable <> ''

            /********************************************************************************************************************/
            /* - End                                                                                                            */
            /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
            /********************************************************************************************************************/

            IF @cSkipLottable = '1'
            BEGIN
               SET @cSkipLottable01 = '1'
               SET @cSkipLottable02 = '1'
               SET @cSkipLottable03 = '1'
               SET @cSkipLottable04 = '1'
               SET @cHasLottable = '0'
            END
            ELSE
            BEGIN
               SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)
               SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)
               SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)
               SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)
            END

            IF @cSkipLottable01 = '1' SELECT @cFieldAttr08 = 'O', @cInField08 = '', @cLottable01 = ''
            IF @cSkipLottable02 = '1' SELECT @cFieldAttr09 = 'O', @cInField09 = '', @cLottable02 = ''
            IF @cSkipLottable03 = '1' SELECT @cFieldAttr10 = 'O', @cInField10 = '', @cLottable03 = ''
            IF @cSkipLottable04 = '1' SELECT @cFieldAttr11 = 'O', @cInField11 = '', @dLottable04 = 0

            IF @cHasLottable = '1'
            BEGIN

               -- Disable lot label and lottable field
               IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
               BEGIN
                  SET @cFieldAttr08 = 'O'
                  SET @cOutField08 = ''
               END
               ELSE
               BEGIN
                  -- Populate lot label and lottable
                  SELECT @cOutField08 = ISNULL(@cLottable01, '')
               END

               IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
               BEGIN
                  SET @cFieldAttr09 = 'O'
                  SET @cOutField09 = ''
               END
               ELSE
               BEGIN
                  SELECT @cOutField09 = ISNULL(@cLottable02, '')
               END

               IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
               BEGIN
                  SET @cFieldAttr10 = 'O'
                  SET @cOutField10 = ''
               END
               ELSE
               BEGIN
                  SELECT @cOutField10 = ISNULL(@cLottable03, '')
               END

               IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
               BEGIN
                  SET @cFieldAttr11 = 'O'
                  SET @cOutField11 = ''
               END
               ELSE
               BEGIN
                  SELECT @cOutField11 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))

                  -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan (james07)
                  IF ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable04) = '1900/01/01'
                     SET @cOutField08 = ''
               END
            END

            IF @cHasLottable = '0'
            BEGIN
               -- Not Lottable
               SET @cLottable01 = ''
               SET @cLottable02 = ''
               SET @cLottable03 = ''
               SET @cLottable04 = ''
            END
      END
      SET @cEnableAllLottables = rdt.RDTGetConfig( @nFunc, 'EnableAllLottables', @cStorerKey)
      IF ISNULL(@cEnableAllLottables,'') = '1'
         BEGIN
            SET @cSkipLottable = '1'
            SELECT 
            @cLottable01 = lot.Lottable01,
            @cLottable02 = lot.Lottable02,
            @cLottable03 = lot.Lottable03,
            @dLottable04 = lot.Lottable04,
            @dLottable05 = lot.Lottable05,
            @cLottable06 = lot.Lottable06,
            @cLottable07 = lot.Lottable07,
            @cLottable08 = lot.Lottable08,
            @cLottable09 = lot.Lottable09,
            @cLottable10 = lot.Lottable10,
            @cLottable11 = lot.Lottable11,
            @cLottable12 = lot.Lottable12,
            @dLottable13 = lot.Lottable13,
            @dLottable14 = lot.Lottable14,
            @dLottable15 = lot.Lottable15,
            @cLottableCode = s.LottableCode
            FROM dbo.CCDetail cc WITH (NOLOCK)
            INNER JOIN LOTATTRIBUTE lot WITH (NOLOCK) 
            ON lot.StorerKey = @cStorerKey AND lot.Sku=cc.SKU AND lot.Lot = cc.Lot
            INNER JOIN dbo.SKU s WITH (NOLOCK)
            ON s.StorerKey = @cStorerKey AND s.SKU = @cSKU
            WHERE CCKey = @cCCKey
                    AND cc.Loc     = @cLoc
                    AND cc.ID      = @cID
                    AND cc.SKU     = @cSKU
                    AND cc.Status  < '9'
                    AND cc.CCSheetNo = @cTaskDetailKey
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
               --V3.8 by jackc
               --@cCCKey,
               @cTaskDetailKey, --V3.8 by jackc END
               @nFunc

            IF @nErrNo <> 0
            BEGIN
               GOTO STEP_1_FAIL
            END

            IF @nMorePage = 1 -- Yes
            BEGIN
               -- Go to dynamic lottable screen
               SET @nFromScn = @nScn
               SET @nScn = 3990
               SET @nStep = 7
            END
            GOTO QUIT 
         END
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cExtendedInfo OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTaskDetailKey  NVARCHAR( 10), ' +
               '@cCCKey          NVARCHAR( 10), ' +
               '@cCCDetailKey    NVARCHAR( 10), ' +
               '@cLoc            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nActQTY         INT, ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME, ' +
               '@dLottable05     DATETIME, ' +
               '@cLottable06     NVARCHAR( 30), ' +
               '@cLottable07     NVARCHAR( 30), ' +
               '@cLottable08     NVARCHAR( 30), ' +
               '@cLottable09     NVARCHAR( 30), ' +
               '@cLottable10     NVARCHAR( 30), ' +
               '@cLottable11     NVARCHAR( 30), ' +
               '@cLottable12     NVARCHAR( 30), ' +
               '@dLottable13     DATETIME, ' +
               '@dLottable14     DATETIME, ' +
               '@dLottable15     DATETIME, ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cExtendedInfo OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Prepare Next Screen Variable
      SET @cInField05 = ''
      SET @cInField06 = '' --SOS278025
      SET @cInField07 = '' --SOS278025

      SET @cOutField14 = @cLoc

      IF @cFieldAttr12 = ''
         SET @cOutField12 = @cSKU

      -- GOTO Next Screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

  IF @nPrevStep = 6
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 03
         SET @cOutField12 = ''
      END
      ELSE
      BEGIN
         IF @nPQTY > 0
            EXEC rdt.rdtSetFocusField @nMobile, 06
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 07
      END

   END  -- Inputkey = 1


   IF @nInputKey = 0
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


       IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                   WHERE CCKey = @cCCKey
                        AND Loc = @cLoc
                        AND Status <> '0'
                        AND ID = @cID
                        AND CCSheetNo = @cTaskDetailKey )
       BEGIN

         SET @cOutField01 = ''

         -- GOTO Next Screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

           GOTO QUIT
       END
       ELSE
       BEGIN
         SET @cCCOption           = ''
         SET @cNewSKUorLottable   = ''
         SET @cHasLottable        = ''

         -- EventLog - Sign In Function
         EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign in function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

         -- If turn on UCC config then goto option screen to let user choose
         -- whether they want count by UCC or SKU. Else by default is SKU
         SET @cStorerConfig_UCC = '0' -- Default Off
         SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
         FROM dbo.StorerConfig (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ConfigKey = 'UCC'

         IF @cStorerConfig_UCC <> '1'
         BEGIN
            SET @cOutField10 = @cLoc
            SET @cOutField11 = ''
            SET @cOutField02 = ''

            --go to main menu
            SET @nFunc = 1766
            SET @nScn  = 2870
            SET @nStep = 1

            GOTO QUIT
         END
         ELSE
         BEGIN
            SET @cOutField01 = @cLoc
            SET @cOutField02 = @cID
            SET @cOutField03 = ''

            --go to main menu
            SET @nFunc = 1766

            --Get RDT config for function id 1766 here to determine whether need show Option screen
            SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorerKey)

            IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '3') -- Statistic screen
            BEGIN
               -- If loc.loseid = 1 then no need scan pallet id. Skip the screen (james02)
               IF EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cLoc AND LoseId = '1')
               BEGIN
                  -- prepare next screen variable
                  SET @cOutField10 = @cLoc
                  SET @cOutField11 = CASE WHEN @cTTMTasktype = 'CCSUP' THEN '(S)' ELSE '' END
                  SET @cOutField01 = ''

                  -- Go to Loc Screen
                  SET @nScn = 2870
               SET @nStep = 1

                  GOTO Quit
               END
               ELSE
               BEGIN
                  SET @cOutField01 = @cLoc
                  SET @cOutField02 = ''


                  -- Go to ID Screen
                  SET @nScn = 2871
                  SET @nStep = 2

                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               SET @nScn  = 2872
               SET @nStep = 3

               GOTO Quit
            END
         END
      END
   END
 GOTO Quit

   STEP_1_FAIL:
   BEGIN
      SET @cOutField03 = ''
      SET @cOutField15 = @cExtendedInfo
   END

--    END
END
GOTO QUIT

/********************************************************************************
Step 2. Scn = 2941.

      SKU (field01)
      DESCR (field02)
      DESCR (field03)
      UOM   (field04 , field05)
      QTY   (input field06 , input field07)
      Lottable01 (field08)
      Lottable02 (field09)
      Lottable03 (field10)
      Lottable04 (field11)
      Lottable05 (field12)

********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- (james03)
      --SET @cExtCfmSP = rdt.RDTGetConfig( @nFunc, 'ExtendedCfmSP', @cStorerKey)
      --IF @cExtCfmSP = '0'
      --   SET @cExtCfmSP = ''

      --SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

      ---- Get stored proc name for extended info (james40)
      --SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      --IF @cExtendedInfoSP = '0'
      --   SET @cExtendedInfoSP = ''

      ---- (james03)
      --SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
      --IF @cDecodeSP = '0'
      --   SET @cDecodeSP = ''

      ---- (james07)
      --SET @cCheckSKUExistsInLoc = rdt.RDTGetConfig( @nFunc, 'CheckSKUExistsInLoc', @cStorerKey)

      --SET @cTMCCSKUSkipScreen1 = rdt.RDTGetConfig( @nFunc, 'TMCCSKUSkipScreen1', @cStorerKey)

      --SET @nDefaultQty = 0

      -- if default qty turned on then overwrite the actual MQty (james02)
  --SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)
      IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1
         SET @nDefaultQty = CAST( @cDefaultQty AS INT)
      ELSE
         SET @nDefaultQty = 0

      SET @cActPQTY = ISNULL(RTRIM(@cInField06),'')
      SET @cActMQTY = ISNULL(RTRIM(@cInField07),'')
      SET @cActSKU = ''

      -- If turn on piece scanning (james02)
      IF @nDefaultQty > 0
      BEGIN
         SET @cActSKU = ISNULL(RTRIM(@cInField12),'')
         SET @cActPQTY = CASE WHEN @cFieldAttr06 = 'O' THEN ISNULL(RTRIM(@cOutField06),'') ELSE @cInField06 END
         SET @cActMQTY = CASE WHEN @cFieldAttr07 = 'O' THEN ISNULL(RTRIM(@cOutField07),'') ELSE @cInField07 END
      END
      ELSE
         SET @cActSKU = ISNULL(RTRIM(@cOutField01),'')

      IF @cFieldAttr12 = ''
         SET @cActSKU = ISNULL(RTRIM(@cInField12),'')

      IF @cDecodeSP <> ''
      BEGIN
         SET @cBarcode = @cInField12
         SET @cUPC = @cActSKU
         SET @nQTY = @nActQTY

         -- Standard decode
         IF @cDecodeSP = '1'
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cTaskDetailKey, @cLOC, @cID, ' +
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
               ' @cBarcode       NVARCHAR( 60), ' +
               ' @cTaskDetailKey NVARCHAR( 10), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
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
               ' @cUserDefine01  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine02  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine03  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine04  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine05  NVARCHAR( 60)  OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cTaskDetailKey, @cLOC, @cID,
               @cUPC          OUTPUT, @nQTY           OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08 OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

         END

         SET @cActSKU = @cUPC
         SET @nActQTY = @nQTY
      END   -- End for DecodeSP

      IF ISNULL( @cActSKU, '') = ''
      BEGIN
         SET @nErrNo = 74532
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
--         SET @cOutField12 = ''
--         EXEC rdt.rdtSetFocusField @nMobile, 12
         GOTO Quit
      END

      SELECT @bSuccess = 1
      SET @nSKUCnt = 0

      -- Get SKU barcode count
      EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cActSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 74502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         SET @cOutField12 = ''
--         EXEC rdt.rdtSetFocusField @nMobile, 12
         GOTO Quit
      END

      -- Validate SKU/UPC
      EXEC dbo.nspg_GETSKU
          @c_StorerKey  = @cStorerKey
         ,@c_sku        = @cActSKU    OUTPUT
         ,@b_success    = @bSuccess  OUTPUT
         ,@n_err        = @nErrNo     OUTPUT
         ,@c_errmsg     = @cErrMsg    OUTPUT

    IF @bSuccess = 0
    BEGIN
         SET @nErrNo = 74514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid SKU'
         SET @cOutField12 = ''
--         EXEC rdt.rdtSetFocusField @nMobile, 12
         GOTO Quit
      END

      IF @cPickMethod = 'SKU'
      BEGIN
         -- If turn on defaultqty feature (piece scanning) then need check sku scan
         IF ( @cActSKU <> @cCommodity) AND @nDefaultQty > 0
         BEGIN
            SET @nErrNo = 74517
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid SKU'
            SET @cOutField12 = ''
--            EXEC rdt.rdtSetFocusField @nMobile, 12
            GOTO Quit
         END
      END
      SET @cOutField01 = @cActSKU
      SET @cOutField12 = @cActSKU
      SET @cSKU = @cActSKU

      -- Validate ActPQTY
      IF ISNULL(@cPUOM_Desc,'') <> ''
      BEGIN
      IF @cActPQTY = ''
      BEGIN
         SET @nErrNo = 74518
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY Req'

         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
            EXEC rdt.rdtSetFocusField @nMobile, 07 -- MQTY
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 06 -- PQTY

         GOTO Step_2_Fail
      END

      IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 74504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'

         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
            EXEC rdt.rdtSetFocusField @nMobile, 07 -- MQTY
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 06 -- PQTY

         GOTO Step_2_Fail
       END
      END

      IF @cActMQTY = '' AND @cActPQTY = ''
      BEGIN
         SET @nErrNo = 74519
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY Req'

         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
            EXEC rdt.rdtSetFocusField @nMobile, 07 -- MQTY
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 06 -- PQTY

            GOTO Step_2_Fail
      END

      -- Validate ActMQTY
      IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0 AND @cActPQTY = ''
      BEGIN
         SET @nErrNo = 74505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'

         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
            EXEC rdt.rdtSetFocusField @nMobile, 07 -- MQTY
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 06 -- PQTY

         GOTO Step_2_Fail
      END

      SELECT
         @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description]
                                 FROM dbo.CodeLKUP C WITH (NOLOCK)
                                 WHERE C.Code = S.Lottable01Label
                                 AND C.ListName = 'LOTTABLE01'
                                 AND C.Code <> ''
                                 AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                 ORDER By C.StorerKey DESC), ''),
         @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description]
                                 FROM dbo.CodeLKUP C WITH (NOLOCK)
                                 WHERE C.Code = S.Lottable02Label
                                 AND C.ListName = 'LOTTABLE02'
                                 AND C.Code <> ''
                                 AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                 ORDER By C.StorerKey DESC), ''),
         @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description]
                                 FROM dbo.CodeLKUP C WITH (NOLOCK)
                                 WHERE C.Code = S.Lottable03Label
                                 AND C.ListName = 'LOTTABLE03'
                                 AND C.Code <> ''
                                 AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                 ORDER By C.StorerKey DESC), ''),
         @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description]
                                 FROM dbo.CodeLKUP C WITH (NOLOCK)
                                 WHERE C.Code = S.Lottable04Label
                                 AND C.ListName = 'LOTTABLE04'
                                 AND C.Code <> ''
                                 AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                 ORDER By C.StorerKey DESC), ''),
         @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description]
                                 FROM dbo.CodeLKUP C WITH (NOLOCK)
                                 WHERE C.Code = S.Lottable05Label
                                 AND C.ListName = 'LOTTABLE05'
                                 AND C.Code <> ''
                                 AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                 ORDER By C.StorerKey DESC), ''),
         @cLottable05_Code = IsNULL( S.Lottable05Label, ''),
         @cLottable01_Code = IsNULL(S.Lottable01Label, ''),
         @cLottable02_Code = IsNULL(S.Lottable02Label, ''),
         @cLottable03_Code = IsNULL(S.Lottable03Label, ''),
         @cLottable04_Code = IsNULL(S.Lottable04Label, '')
      FROM dbo.SKU S WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      IF @cNewSKUorLottable = '1'
      BEGIN
         SELECT
            @cLottable01 = CASE WHEN @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL THEN @cInField08 ELSE '' END,
            @cLottable02 = CASE WHEN @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL THEN @cInField09 ELSE '' END,
            @cLottable03 = CASE WHEN @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL THEN @cInField10 ELSE '' END,
            @cLottable04 = CASE WHEN @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL THEN @cInField11 ELSE '' END

         SET @cFieldAttr08 = ''
         SET @cFieldAttr09 = ''
         SET @cFieldAttr10 = ''
         SET @cFieldAttr11 = ''
         SET @cFieldAttr12 = ''
         SET @cFieldAttr13 = ''
         SET @cFieldAttr14 = ''
         SET @cFieldAttr15 = ''

         /********************************************************************************************************************/
         /*  - Start                                                                                                         */
         /* Generic Lottables Computation (POST): To compute Lottables after input of Lottable value                         */
         /* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
         /* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
         /* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
         /*    Codelkup.Short = 'POST' and Codelkup.Long = <SP Name>                                            */
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

            SET @cShort = ''
            SET @cStoredProd = ''

            SELECT @cShort = C.Short,
                   @cStoredProd = IsNULL( C.Long, '')
            FROM dbo.CodeLkUp C WITH (NOLOCK)
            WHERE C.Listname = @cListName
            AND   C.Code = @cLottableLabel

            IF @cShort = 'POST' AND @cStoredProd <> ''
            BEGIN
               IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date
                     SET @dLottable04 = CAST( @cLottable04 AS DATETIME)

               IF rdt.rdtIsValidDate(@cLottable05) = 1 --valid date
                  SET @dLottable05 = CAST( @cLottable05 AS DATETIME)

               SET @cSourcekey = @cCCKey

                EXEC dbo.ispLottableRule_Wrapper
                   @c_SPName            = @cStoredProd,
                   @c_ListName          = @cListName,
                   @c_Storerkey         = @cStorerKey,
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
                   @b_Success           = @bSuccess   OUTPUT,
                   @n_Err               = @nErrNo      OUTPUT,
                   @c_Errmsg            = @cErrMsg     OUTPUT,
                   @c_Sourcekey         = @cSourcekey,
                   @c_Sourcetype        = 'RDTTMCC'


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

                  GOTO Step_2_Fail
                END

                SET @cTempLottable01 = IsNULL( @cTempLottable01, '')
                SET @cTempLottable02 = IsNULL( @cTempLottable02, '')
                SET @cTempLottable03 = IsNULL( @cTempLottable03, '')
                SET @dTempLottable04 = @dTempLottable04--NLT013
                SET @dTempLottable05 = @dTempLottable05--NLT013


                SET @cOutField02 = CASE WHEN @cTempLottable01 <> '' THEN @cTempLottable01 ELSE @cLottable01 END
                SET @cOutField04 = CASE WHEN @cTempLottable02 <> '' THEN @cTempLottable02 ELSE @cLottable02 END
                SET @cOutField06 = CASE WHEN @cTempLottable03 <> '' THEN @cTempLottable03 ELSE @cLottable03 END
                SET @cOutField08 = CASE WHEN @dTempLottable04 IS NOT NULL AND TRY_CAST(@dTempLottable04 AS DATETIME) IS NOT NULL THEN rdt.rdtFormatDate( @dTempLottable04) ELSE @cLottable04 END --ang01

                SET @cLottable01 = IsNULL(@cOutField02, '')
                SET @cLottable02 = IsNULL(@cOutField04, '')
                SET @cLottable03 = IsNULL(@cOutField06, '')
                SET @cLottable04 = IsNULL(@cOutField08, '')
            END -- Short

            --increase counter by 1
            SET @nCountLot = @nCountLot + 1

         END -- end of while


         IF @cSkipLottable = '1'
         BEGIN
            SET @cSkipLottable01 = '1'
            SET @cSkipLottable02 = '1'
            SET @cSkipLottable03 = '1'
            SET @cSkipLottable04 = '1'
         END
         ELSE
         BEGIN
            SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)
            SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)
            SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)
            SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)
         END

         -- Skip lottable
         IF @cSkipLottable01 = '1' SET @cLottable01 = ''
         IF @cSkipLottable02 = '1' SET @cLottable02 = ''
         IF @cSkipLottable03 = '1' SET @cLottable03 = ''
         IF @cSkipLottable04 = '1' SET @dLottable04 = 0

         -- Validate lottable01
         IF @cSkipLottable01 <> '1' AND ( ISNULL( @cLotlabel01, '') <> '' AND ISNULL( @cLottable01, '') = '')
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 74520, @cLangCode, 'DSP') --'Lottable01 required'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Step_2_Fail
         END

        -- Validate lottable02
        IF @cSkipLottable02 <> '1' AND (ISNULL( @cLotlabel02, '') <> '' AND ISNULL( @cLottable02, '') = '')
        BEGIN
           SET @cErrMsg = rdt.rdtgetmessage( 74521, @cLangCode, 'DSP') --'Lottable02 required'
           EXEC rdt.rdtSetFocusField @nMobile, 9
           GOTO Step_2_Fail
        END

         -- Validate lottable03
         IF @cSkipLottable03 <> '1' AND (ISNULL( @cLotlabel03, '') <> '' AND ISNULL( @cLottable03, '') = '')
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 74522, @cLangCode, 'DSP') --'Lottable03 required'
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Step_2_Fail
         END

         -- Validate lottable04
         IF @cSkipLottable04 <> '1' AND (ISNULL( @cLotlabel04, '') <> '' AND ISNULL( @cLottable04, '') = '')
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 74523, @cLangCode, 'DSP') --'Lottable04 required'
            EXEC rdt.rdtSetFocusField @nMobile, 11
            GOTO Step_2_Fail
         END

         -- Validate date
         IF @cSkipLottable04 <> '1' AND (ISNULL( @cLotlabel04, '') <> '' AND RDT.rdtIsValidDate( @cLottable04) = 0)
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 74559, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 11
            GOTO Step_2_Fail
         END
      END

      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)
      SET @nActQTY = 0

      SET @nActQTY = ISNULL(rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nActPQTY, @cPUOM, 6), 0) -- Convert to QTY in master UOM

      SET @nActQTY = @nActQTY + @nActMQTY

      IF @nMaxQtyValue > 0 AND (@nActQTY > @nMaxQtyValue)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 74536, @cLangCode, 'DSP') --'Exceed Max Qty'
         EXEC rdt.rdtSetFocusField @nMobile, 11
         GOTO Step_2_Fail
      END

      IF @cCheckSKUExistsInLoc = '1'  
      BEGIN  
         IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)  
                         WHERE CCKey = @cCCKey  
                       AND   Loc = @cLoc  
                       AND   (( @cID = '') OR ( ID = @cID))  
                       AND   SKU = @cSKU  
                       AND   Status  < '9'  
                       AND   CCSheetNo = @cTaskDetailKey) AND @nFromStep <> 6    
         BEGIN  
            SET @cOutField01 = ''  
            SET @nFromScn = @nScn
            SET @nFromStep = @nStep
            SET @nScn = @nScn + 4  
            SET @nStep = @nStep + 5  
            
            GOTO Quit  
         END  
      END  

      DECLARE @nSysQty     INT = 0
      DECLARE @nSNQty      INT = 0
      DECLARE @nNeedScanSN INT = 1

      IF @cDiffQTYScanSNO = '1'
      BEGIN
            
         SELECT @nSysQty = ISNULL( SUM( SystemQty), 0)
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCKey
         AND   CCSheetNo = @cTaskDetailKey
         AND   StorerKey = @cStorerKey
         AND   Loc = @cLoc
         AND   ID = CASE WHEN ISNULL( @cID, '') = '' THEN ID ELSE @cID END
         AND   SKU = @cSKU

         SELECT @nSNQty = ISNULL( SUM( Qty), 0)
         FROM dbo.SERIALNO WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ID = CASE WHEN ISNULL( @cID, '') = '' THEN ID ELSE @cID END
         AND   SKU = @cSKU
         AND   [Status] = '1' -- Received

         IF (@nSysQty = @nActQTY) AND (@nSysQty = @nSNQty)
            SET @nNeedScanSN = 0
      END

      IF @cSerialNoCapture IN ('1', '2') AND @nNeedScanSN = 1 -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cSKU, @cSKUDescr, @nActQTY, 'CHECK', 'TMCCSKU', @cTaskDetailKey,
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
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            -- Go to Serial No screen
            SET @nFromScn = @nScn
            SET @nPrevScreen = @nScn
            SET @nScn = 4831
            SET @nStep = @nStep + 6
            SET @cInField04=''
            GOTO Quit
         END
      END
      
      -- Extended info
      IF @cExtCfmSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtCfmSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.[' + RTRIM( @cExtCfmSP) +']'+
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, ' +
               ' @cCCKey, @cCCDetailKey, @cPickMethod, @cLoc, @cID, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTaskDetailKey  NVARCHAR( 10), ' +
               '@cCCKey          NVARCHAR( 10), ' +
               '@cCCDetailKey    NVARCHAR( 10), ' +
               '@cPickMethod     NVARCHAR( 10), ' +
               '@cLoc            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT, ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME, ' +
               '@dLottable05     DATETIME, ' +
               '@cLottable06     NVARCHAR( 30), ' +
               '@cLottable07     NVARCHAR( 30), ' +
               '@cLottable08     NVARCHAR( 30), ' +
               '@cLottable09     NVARCHAR( 30), ' +
               '@cLottable10     NVARCHAR( 30), ' +
               '@cLottable11     NVARCHAR( 30), ' +
               '@cLottable12     NVARCHAR( 30), ' +
               '@dLottable13     DATETIME, ' +
               '@dLottable14     DATETIME, ' +
               '@dLottable15     DATETIME, ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey,
               @cCCKey, @cCCDetailKey, @cPickMethod, @cLoc, @cID, @cSKU, @nActQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END
      ELSE
      BEGIN
         -- Update CCDetail --
         EXEC [RDT].[rdt_TM_CycleCount_SKU_ConfirmTask]
             @nMobile           = @nMobile
            ,@nFunc             = @nFunc
            ,@cFacility         = @cFacility
            ,@cCCKey            = @cCCKey
            ,@cStorerKey        = @cStorerKey
            ,@cSKU              = @cSKU
            ,@cLOC              = @cLOC
            ,@cID               = @cID
            ,@nQty              = @nActQTY
            ,@nPackValue        = ''
            ,@cUserName         = @cUserName
            ,@cLottable01       = @cLottable01
            ,@cLottable02       = @cLottable02
            ,@cLottable03       = @cLottable03
            ,@dLottable04       = @dLottable04
            ,@dLottable05       = @dLottable05
            ,@cLottable06       = @cLottable06  
            ,@cLottable07       = @cLottable07  
            ,@cLottable08       = @cLottable08  
            ,@cLottable09       = @cLottable09  
            ,@cLottable10       = @cLottable10  
            ,@cLottable11       = @cLottable11  
            ,@cLottable12       = @cLottable12  
            ,@dLottable13       = @dLottable13  
            ,@dLottable14       = @dLottable14  
            ,@dLottable15       = @dLottable15  
            ,@cUCC              = ''
            ,@cTaskDetailKey    = @cTaskDetailKey
            ,@cPickMethod       = @cPickMethod
            ,@cLangCode         = @cLangCode
            ,@nErrNo            = @nErrNo      OUTPUT
            ,@cErrMsg           = @cErrMsg     OUTPUT -- screen limitation, 20 char max
      END

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Step_2_Fail
      END

      SET @nReCountLoc = 0

      -- Variance count  
      IF @cTMCCVarianceCountSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cTMCCVarianceCountSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cTMCCVarianceCountSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, ' + 
               ' @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, @cOptions, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @nReCountLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
    
            SET @cSQLParam =  
               '@nMobile         INT, ' +  
               '@nFunc           INT, ' +  
               '@cLangCode       NVARCHAR( 3), ' +  
               '@nStep           INT, ' +  
               '@nInputKey       INT, ' +  
               '@cStorerKey      NVARCHAR( 15), ' +  
               '@cTaskDetailKey  NVARCHAR( 10), ' +  
               '@cCCKey          NVARCHAR( 10), ' +  
               '@cCCDetailKey    NVARCHAR( 10), ' +  
               '@cLoc            NVARCHAR( 10), ' +  
               '@cID             NVARCHAR( 18), ' +  
               '@cSKU            NVARCHAR( 20), ' +  
               '@nActQTY         INT, ' +  
               '@cOptions        NVARCHAR( 1), ' +
               '@cLottable01     NVARCHAR( 18), ' +  
               '@cLottable02     NVARCHAR( 18), ' +  
               '@cLottable03     NVARCHAR( 18), ' +  
               '@dLottable04     DATETIME, ' +  
               '@dLottable05     DATETIME, ' +  
               '@cLottable06     NVARCHAR( 30), ' +  
               '@cLottable07     NVARCHAR( 30), ' +  
               '@cLottable08     NVARCHAR( 30), ' +  
               '@cLottable09     NVARCHAR( 30), ' +  
               '@cLottable10     NVARCHAR( 30), ' +  
               '@cLottable11     NVARCHAR( 30), ' +  
               '@cLottable12     NVARCHAR( 30), ' +  
               '@dLottable13     DATETIME, ' +  
               '@dLottable14     DATETIME, ' +  
               '@dLottable15     DATETIME, ' +  
               '@nReCountLoc     INT           OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, 
               @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,  @cOptions, 
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @nReCountLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit  
            
            IF @nReCountLoc <> 0
            BEGIN
               SET @cInField01 = @nReCountLoc
               
               GOTO Step_3
            END
         END  
      END  

      SET @cEnableAllLottables = rdt.RDTGetConfig( @nFunc, 'EnableAllLottables', @cStorerKey)
      IF ISNULL(@cEnableAllLottables,'') = '1'
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

            SET @cCCDetailKey = ''
            SET @cNewSKUorLottable = ''

            SET @nPrevStep = 0
            SET @nPrevScreen  = 0

            SET @nPrevStep = @nStep
            SET @nPrevScreen = @nScn

            SET @cOutField01 = ''

            -- GOTO Next Screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO QUIT
      END
      
      IF @nDefaultQty = 0
      BEGIN
         SET @nQtyAval = 0
         SET @nQty = 0
         SET @nRowCount = 0
         SET @nLottableCount = @nLottableCount + 1

         --- Get Next Lottable
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = NULL
         SET @dLottable05 = NULL


         IF @cCCGroupExLottable05 = '1'
         BEGIN
            SELECT TOP 1
                     @cLottable01 = CC.Lottable01
                   , @cLottable02 = CC.Lottable02
                   , @cLottable03 = CC.Lottable03
                   , @dLottable04 = rdt.rdtFormatDate( CC.Lottable04)
                   , @nQtyAval    =  SUM(CC.SystemQty)
                   , @cCCDetailKey = MIN(CC.CCDetailKey)
                   , @nQty        = SUM(CC.Qty)
            FROM dbo.CCDetail CC WITH (NOLOCK)
            WHERE CC.SKU = @cSKU
            AND CC.CCKey = @cCCKey
            AND CC.Loc   = @cLoc
            AND CC.ID    = @cID
            AND Status < '9'
            AND CC.CCSheetNo = @cTaskDetailKey
            GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04
            HAVING MIN(CC.CCDetailKey) > @cCCDetailKey

        END
        ELSE
        BEGIN
           SELECT TOP 1
                     @cLottable01 = CC.Lottable01
                   , @cLottable02 = CC.Lottable02
                   , @cLottable03 = CC.Lottable03
                   , @dLottable04 = rdt.rdtFormatDate( CC.Lottable04)  
                   , @dLottable05 = rdt.rdtFormatDate( CC.Lottable05)  
                   , @nQtyAval    =  CC.SystemQty
                   , @cCCDetailKey = CC.CCDetailKey
                   , @nQty        = CC.Qty
            FROM dbo.CCDetail CC WITH (NOLOCK)
            WHERE CC.SKU = @cSKU
            AND CC.CCKey = @cCCKey
            AND CC.Loc   = @cLoc
            AND CC.ID    = @cID
            --AND Status < '9' if 9 will have record keep looping for newly added record
            AND Status = '0'
            AND CC.CCSheetNo = @cTaskDetailKey
            AND CC.CCDetailKey > @cCCDetailKey
            ORDER BY CCDetailKey
         END

         SET @nRowCount = @@ROWCOUNT

         IF @cSkipLottable = '1'
         BEGIN
            --SET @nRowCount = 1

            SET @cLottable01 = ''
            SET @cLottable02 = ''
            SET @cLottable03 = ''
            SET @dLottable04 = 0
         END

         IF @nRowCount = 0 OR @cNewSKUorLottable = '1'
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

            SET @cCCDetailKey = ''
            SET @cNewSKUorLottable = ''

            SET @nPrevStep = 0
            SET @nPrevScreen  = 0

            SET @nPrevStep = @nStep
            SET @nPrevScreen = @nScn

            SET @cOutField01 = ''

            -- GOTO Next Screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO QUIT
         END
         ELSE IF @nRowCount > 0
         BEGIN

            SET @cCounted = ''
            IF @cSkipLottable = '1'
               SET @cOutField13 = '1/1'
            ELSE
               SET @cOutField13 = CASE WHEN @cSkipLottable = '1' THEN ''
                                       ELSE RTRIM(CAST(@nLottableCount AS NVARCHAR(4))) +  '/' +
                                            RTRIM(CAST(@nLottableCountTotal AS NVARCHAR(4)))
                                       END

            SELECT
                    -- @cStorerKey = CC.StorerKey
                     @cSKUDescr = SKU.DESCR
                   , @cMUOM_Desc  = Pack.PackUOM3
                   , @cPUOM_Desc  =
                      CASE @cPUOM
                         WHEN '2' THEN Pack.PackUOM1 -- Case
                         WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                         WHEN '6' THEN Pack.PackUOM3 -- Master unit
                         WHEN '1' THEN Pack.PackUOM4 -- Pallet
                         WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                         WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                      END
                   ,  @nPUOM_Div  = CAST( IsNULL(
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
            WHERE SKU.SKU = @cSKU
              AND SKU.StorerKey = @cStorerKey

            IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                        WHERE CCKey = @cCCKey
                        AND SKU = @cSKU
                        AND Loc = @cLoc
                        AND ID  = @cID
                        AND Status < '9'
                        AND Qty > 0
                        AND CCSheetNo = @cTaskDetailKey
                        AND CCdetailKey = @cCCDetailKey)
            BEGIN
               SET @nQtyAval = @nQty
               SET @cCounted = '1'
            END

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @nMQTY = @nQtyAval
            END
            ELSE
            BEGIN
                  SET @nPQTY = @nQtyAval / @nPUOM_Div  -- Calc QTY in preferred UOM
                  SET @nMQTY = @nQtyAval % @nPUOM_Div  -- Calc the remaining in master unit
            END

            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField04 = ''
               SET @cOutField06 = ''
               SET @cFieldAttr06 = 'O'
            END
            ELSE
            BEGIN
               SET @cOutField04 = @cPUOM_Desc
               IF @cCounted = '1'
               BEGIN
                  SET @cOutField06 = CAST( @nPQTY AS NVARCHAR( 5))
               END
               ELSE
               BEGIN
                  SET @cOutField06 = ''
               END
            END

            IF @nPQTY <= 0
            BEGIN
               SET @cOutField04 = ''
               SET @cOutField06 = ''
               SET @cOutField06 = ''
               SET @cFieldAttr06 = 'O'
            END


            SET @cOutField05 = @cMUOM_Desc

            IF @cCounted = '1'
            BEGIN
               SET @cOutField07 = CAST( @nMQTY AS NVARCHAR( 5))
            END
            ELSE
            BEGIN
               SET @cOutField07 = ''
            END

            SET @cFieldAttr07 = ''

            IF @nPQTY > 0
               EXEC rdt.rdtSetFocusField @nMobile, 06
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 07

            SET @cNewSKUorLottable = ''

            SET @cFieldAttr08 = 'O'
            SET @cFieldAttr09 = 'O'
            SET @cFieldAttr10 = 'O'
            SET @cFieldAttr11 = 'O'

            SET @cOutField08 = @cLottable01
            SET @cOutField09 = @cLottable02
            SET @cOutField10 = @cLottable03
            SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)
         END
      END
      ELSE
      BEGIN
         SELECT
                  -- @cStorerKey = CC.StorerKey
                  @cSKUDescr = SKU.DESCR
                  , @cMUOM_Desc  = Pack.PackUOM3
                  , @cPUOM_Desc  =
                     CASE @cPUOM
                        WHEN '2' THEN Pack.PackUOM1 -- Case
                        WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                        WHEN '6' THEN Pack.PackUOM3 -- Master unit
                        WHEN '1' THEN Pack.PackUOM4 -- Pallet
                        WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                        WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                     END
                  ,  @nPUOM_Div  = CAST( IsNULL(
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
         WHERE SKU.SKU = @cSKU
            AND SKU.StorerKey = @cStorerKey

         SET @cFieldAttr08 = 'O'
         SET @cFieldAttr09 = 'O'
         SET @cFieldAttr10 = 'O'
         SET @cFieldAttr11 = 'O'

         SET @cFieldAttr06 = ''
         SET @cFieldAttr07 = ''
         SET @cFieldAttr12 = ''

         --SET @nDefaultQty = 0

         -- if default qty turned on then overwrite the actual MQty (james02)
         --SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)
         IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1
            SET @nDefaultQty = CAST( @cDefaultQty AS INT)
         ELSE
            SET @nDefaultQty = 0

      IF @nDefaultQty > 0
         BEGIN
            SET @cFieldAttr12 = ''
            SET @cOutField12 = ''
            SET @cFieldAttr06 = 'O'
            SET @cFieldAttr07 = 'O'

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
               SET @cOutField07 = @nDefaultQty
            ELSE
            BEGIN
               IF @nDefaultQty > @nPUOM_Div
               BEGIN
                  SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM
                  SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit
               END
               ELSE
                  SET @cOutField07 = @nDefaultQty
            END
         END
         ELSE
         BEGIN
            SET @cFieldAttr12 = 'O'
            SET @cOutField12 = ''
         END

         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutfield12 = ''
      END
   END  -- Inputkey = 1

   IF @nInputKey = 0
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


      -- (james08)
      SET @cOutField01 = CASE WHEN @cDefaultOption <> '' THEN @cDefaultOption ELSE '' END

      -- GOTO Next Screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @cExtendedInfo OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT, ' +
            '@nFunc           INT, ' +
            '@cLangCode       NVARCHAR( 3), ' +
            '@nStep           INT, ' +
            '@nInputKey       INT, ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cTaskDetailKey  NVARCHAR( 10), ' +
            '@cCCKey          NVARCHAR( 10), ' +
            '@cCCDetailKey    NVARCHAR( 10), ' +
            '@cLoc            NVARCHAR( 10), ' +
            '@cID             NVARCHAR( 18), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nActQTY         INT, ' +
            '@cLottable01     NVARCHAR( 18), ' +
            '@cLottable02     NVARCHAR( 18), ' +
            '@cLottable03     NVARCHAR( 18), ' +
            '@dLottable04     DATETIME, ' +
            '@dLottable05     DATETIME, ' +
            '@cLottable06     NVARCHAR( 30), ' +
            '@cLottable07     NVARCHAR( 30), ' +
            '@cLottable08     NVARCHAR( 30), ' +
            '@cLottable09     NVARCHAR( 30), ' +
            '@cLottable10     NVARCHAR( 30), ' +
            '@cLottable11     NVARCHAR( 30), ' +
            '@cLottable12     NVARCHAR( 30), ' +
            '@dLottable13     DATETIME, ' +
            '@dLottable14     DATETIME, ' +
            '@dLottable15     DATETIME, ' +
            '@cExtendedInfo   NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 2, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cExtendedInfo OUTPUT

         SET @cOutField15 = @cExtendedInfo
      END
   END

   GOTO Quit

   STEP_2_FAIL:
   BEGIN
      IF @nDefaultQty = 0
      BEGIN
         SET @cOutField06 = ''
         SET @cOutField07 = ''
      END

      SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)
      SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)
      SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)
      SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)

      -- Skip lottable
      IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = '', @cLottable01 = ''
      IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = '', @cLottable02 = ''
      IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = '', @cLottable03 = ''
      IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = '', @dLottable04 = 0

      -- Init next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Disable lottable
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O'
            SET @cOutField08 = ''
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr09 = 'O'
            SET @cOutField09 = ''
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
            SET @cFieldAttr10 = 'O'
            SET @cOutField10 = ''
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
        SET @cFieldAttr11 = 'O'
            SET @cOutField11 = ''
         END
      END
   END

--    END
END
GOTO QUIT

/********************************************************************************
Step 3. Scn = 2942.
   Options (Input , Field01)

********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cOptions = ISNULL(RTRIM(@cInField01),'')

      IF ISNULL(@cOptions, '') = ''
      BEGIN
         SET @nErrNo = 74506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'
         GOTO Step_3_Fail
      END

      IF @cOptions NOT IN ('1', '2','3','4','5')
      BEGIN
         SET @nErrNo = 74507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_3_Fail
      END

      SET @cCCOption = @cOptions
      SET @cNewSKUorLottable = ''

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

      IF @cOptions = '1'
      BEGIN

         SET @cCCOption           = ''
         SET @cNewSKUorLottable   = ''
         SET @cHasLottable        = ''

         -- Prepare Next Screen Variable
         SET @cOutField01 = @cLoc
         SET @cOutField02 = ''

         -- GOTO Main Module ID Screen
         SET @nFunc = 1766
         SET @nScn = 2871
         SET @nStep = 2
      END
      ELSE IF @cOptions = '2'
      BEGIN
         -- Get QTY available
         SET @nQTYAvail = 0
         SELECT @nQTYAvail = ISNULL(SUM(QTY - QTYAllocated - QTYPicked), 0)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         WHERE LOC = @cLoc

         SELECT @cLOT = C.LOT, @cLOC = C.LOC, @cID = C.ID, @nSystemQty =
                CASE WHEN C.Status = '4' THEN 0
                     WHEN C.Status = '2' THEN (C.SystemQTY - C.QTY)
                     WHEN C.SystemQTY = 0 THEN
              /*
                  1. blank count sheet, systemqty = 0
                  2. count sheet
                   if include empty loc, systemqty = 0 (for all locations)
                   if not include empty loc, systemqty = lotxlocxid
                  3. ucc count sheet
                   regardless include empty loc, systemqty = ucc.qty / lotxlocxid
                  4. RDT TM CC, systemqty = ucc.qty / lotxlocxid
               */
                     (SELECT ISNULL( SUM( QTY-QTYAllocated-QTYPicked), 0) FROM dbo.LotxLocxID WITH (NOLOCK) WHERE LOT = C.LOT AND LOC = C.LOC AND ID = C.ID)
              ELSE ISNULL(SUM(C.SystemQTY), 0) END
         FROM dbo.CCDetail C WITH (NOLOCK)
         INNER JOIN LOC L WITH (NOLOCK) ON (C.LOC = L.LOC)
         WHERE C.CCKey  = @cCCKey
           AND C.Loc    = @cLoc
           AND C.Status < '9'
        GROUP BY C.STATUS, C.SYSTEMQTY, C.LOT, C.LOC, C.ID, C.QTY

         -- Check if adjust out more then available
         IF @nSystemQty > @nQTYAvail
         BEGIN
            SET @cAlertMessage =
               'Adjust out qty (' + CAST( @nSystemQty AS NVARCHAR( 10)) + ') more then available QTY (' + CAST( @nQTYAvail AS NVARCHAR( 10)) + ')'
            EXEC nspLogAlert
                 @c_modulename       = 'TMCC'
               , @c_AlertMessage     = @cAlertMessage
               , @n_Severity         = '5'
               , @b_success          = @bSuccess
               , @n_err              = @n_Err
               , @c_errmsg           = @c_ErrMsg
               , @c_Activity         = 'CC'
               , @c_Storerkey        = @cStorerkey
               , @c_SKU              = @cSKU
               , @c_UOM              = ''
               , @c_UOMQty           = ''
               , @c_Qty              = @nSystemQty
               , @c_Lot              = @cLot
               , @c_Loc              = @cLoc
               , @c_ID               = @cID
               , @c_TaskDetailKey    = @cTaskDetailKey
               , @c_UCCNo            = ''

            UPDATE dbo.TaskDetail
            SET Status = '9'
                ,TrafficCop = NULL
                ,EditDate = GetDate()
            WHERE TaskDetailKey = @cTaskDetailKey

            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 74530
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDetFailed'
               GOTO Step_3_Fail
            END

            -- GOTO Alert Screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            --GOTO Quit
         END
         ELSE
         BEGIN
            -- Update CCDetail Remaining Loc , ID to Status = '5'  
            UPDATE dbo.CCDetail WITH (ROWLOCK)  
               SET FinalizeFlag = 'Y'  
                 , FinalizeFlag_Cnt2 = CASE WHEN Counted_Cnt2 > 0 THEN 'Y' END  
                 , FinalizeFlag_Cnt3 = CASE WHEN Counted_Cnt3 > 0 THEN 'Y' END  
            WHERE CCKey  = @cCCKey  
              AND Loc    = @cLoc  
              AND Status < '9'  
  
            IF @@ERROR <> ''  
            BEGIN  
               SET @nErrNo = 74511  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDCCDetFail'  
               GOTO Step_3_Fail  
            END  
            
            -- Update CCDetail Remaining Loc , ID to Status = '5'
            UPDATE dbo.CCDetail WITH (ROWLOCK)
               SET FinalizeFlag = 'Y'
            WHERE CCKey  = @cCCKey
              AND Loc    = @cLoc
              AND Status < '9'

            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 74511
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDCCDetFail'
               GOTO Step_3_Fail
            END

            IF  @cTTMTasktype = 'CCSUP' OR @cTMCCAllowPostAdj = '1' 
            BEGIN  
               SET @nCountNo = 1    
               SELECT TOP 1 @nCountNo =     
               CASE WHEN Counted_Cnt3 > 0 THEN 3    
                     WHEN Counted_Cnt2 > 0 THEN 2     
                     ELSE 1 END    
               FROM dbo.CCDetail WITH (NOLOCK)    
               WHERE CCKey   = @cCCKey        
               AND CCSheetNo = @cTaskDetailKey    
               ORDER BY CCDetailKey DESC    
               
               EXEC ispGenCCAdjustmentPost_MultiCnt  
                       @c_StockTakeKey = @cCCKey  
                     , @c_CountNo      = @nCountNo  
                     , @b_success      = @bSuccess OUTPUT  
                     , @c_TaskDetailKey = @cTaskDetailKey  

               IF @bSuccess = 0  
               BEGIN  
                  SET @nErrNo = 74524  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CCPostingFail'  
                  GOTO Step_3_Fail  
               END  
            END  

            UPDATE dbo.TaskDetail WITH (ROWLOCK)
            SET Status = '9'
                ,TrafficCop = NULL
                ,EditDate = GetDate()
            WHERE TaskDetailKey = @cTaskDetailKey

            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 74512
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskDetFailed'
               GOTO Step_3_Fail
            END

            UPDATE AL WITH (ROWLOCK) SET
               AL.STATUS = '9'
            FROM dbo.TaskDetail TD
            JOIN dbo.Alert AL ON TD.Message03 = AL.AlertKey
            WHERE TD.TaskDetailKey = @cTaskDetailKey
            AND   TD.TaskType = 'CCSUP'
            AND   TD.Status = '9'

            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 74529
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD ALERT FAIL'
               GOTO Step_3_Fail
            END

            IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                           WHERE CCKey = @cCCKey
                           AND Loc = @cLoc
                           AND CCSheetNo = @cTaskDetailKey
                           GROUP BY Loc
                           HAVING SUM( SystemQty) <> SUM( Qty))
            BEGIN
               IF @cTTMTasktype <> 'CCSUP'
               BEGIN
                  -- Go to ALERT Message Screen
                  SET @cCCType = 'SKU'
                  SET @c_ModuleName = 'TMCC'
                  SET @c_Activity  = 'CC'

                  EXEC [RDT].[rdt_TM_CycleCount_Alert]
                      @nMobile         = @nMobile
                     ,@cCCKey          = @cCCKey
                     ,@cStorerKey      = @cStorerKey
                     ,@cLOC            = @cLOC
                     ,@cID             = @cID
                     ,@cSKU            = @cSKU
                     ,@cUserName       = @cUserName
                     ,@cModuleName     = @c_ModuleName
                     ,@cActivity       = @c_Activity
                     ,@cCCType         = @cCCType
                     ,@cTaskDetailKey  = @cTaskDetailKey
                     ,@cLangCode       = @cLangCode
                     ,@nErrNo          = @nErrNo
                     ,@cErrMsg         = @cErrMsg

                  -- GOTO Next Screen
                  SET @nScn = @nScn + 1
                  SET @nStep = @nStep + 1

                  --(james08)
                  IF @cSkipAlertScreen = '1'
                     GOTO Step_4
               END
               ELSE
               BEGIN
                  -- GOTO Main Module Get Next Task Screen Screen
                  SET @cCCOption           = ''
                  SET @cNewSKUorLottable   = ''
                  SET @cHasLottable        = ''

                  SET @nFunc = 1766
                  SET @nScn = 2875
                  SET @nStep = 6
               END
            END
            ELSE
            BEGIN
               -- GOTO Main Module Get Next Task Screen Screen
               SET @cCCOption           = ''
               SET @cNewSKUorLottable   = ''
               SET @cHasLottable        = ''

               SET @nFunc = 1766
               SET @nScn = 2875
               SET @nStep = 6
            END

            -- (james09)
            UPDATE dbo.Loc WITH (ROWLOCK) SET
               LastCycleCount = GETDATE(),
               EditWho = @cUserName,
               EditDate = GETDATE()
            WHERE Loc = @cLoc
            AND   Facility = @cFacility

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74535
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- Upd LastCC Err
               GOTO Step_3_Fail
            END
         END
      END
      ELSE IF @cOptions = '3'
      BEGIN
         IF @nReCountLoc = 0
         BEGIN
            -- Update CCDetail Remaining Loc , ID to Status = '5'  
            DELETE FROM dbo.CCDetail  
            WHERE CCKey  = @cCCKey  
              AND Loc    = @cLoc  
              AND CCSheetNo = @cTaskDetailKey  
  
            IF @@ERROR <> ''  
            BEGIN  
               SET @nErrNo = 74513  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDCCDetFail'  
               GOTO Step_3_Fail  
            END  
         END

         -- Loc recount, delete all serial no  
         DELETE FROM dbo.CCSerialNoLog  
         WHERE CCKey  = @cCCKey  
         AND   Loc    = @cLoc  
         AND   CCSheetNo = @cTaskDetailKey  
         AND   [Status] = '0'

         IF @@ERROR <> ''  
         BEGIN  
            SET @nErrNo = 74536  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Del SN# Err'  
            GOTO Step_3_Fail  
         END  
         
         -- Prepare Next Screen Variable
         SET @cCCOption           = ''
         SET @cNewSKUorLottable   = ''
         SET @cHasLottable        = ''

         SET @cOutField10 = @cSuggFromLoc
         SET @cOutField02 = ''
         SET @cOutField11 = ''

         -- GOTO Next Screen
         SET @nFunc = 1766
         SET @nScn = 2870
         SET @nStep = 1
      END
      ELSE IF @cOptions = '4'
      BEGIN
         IF @cTMCCSKUSkipScreen1 = '1'
         BEGIN
            SET @cFieldAttr06 = ''
            SET @cFieldAttr07 = ''
            SET @cFieldAttr12 = ''

            IF @nDefaultQty > 0
            BEGIN
               SET @cFieldAttr12 = ''
               SET @cOutField12 = ''
               SET @cFieldAttr06 = 'O'
               SET @cFieldAttr07 = 'O'

               -- Convert to prefer UOM QTY
               IF @cPUOM = '6' OR -- When preferred UOM = master unit
                  @nPUOM_Div = 0  -- UOM not setup
                  SET @cOutField07 = @nDefaultQty
               ELSE
               BEGIN
                  IF @nDefaultQty > @nPUOM_Div
                  BEGIN
                     SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM
                     SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit
                  END
                  ELSE
                     SET @cOutField07 = @nDefaultQty
               END
            END
            ELSE
            BEGIN
               SET @cFieldAttr12 = 'O'
               SET @cOutField12 = ''
            END

            -- Extended info
            IF @cExtendedInfoSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
               BEGIN
                  SET @cExtendedInfo = ''

                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
                     ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                     ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                     ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                     ' @cExtendedInfo OUTPUT '

                  SET @cSQLParam =
                     '@nMobile         INT, ' +
                     '@nFunc           INT, ' +
                     '@cLangCode       NVARCHAR( 3), ' +
                     '@nStep           INT, ' +
                     '@nInputKey       INT, ' +
                     '@cStorerKey      NVARCHAR( 15), ' +
                     '@cTaskDetailKey  NVARCHAR( 10), ' +
                     '@cCCKey          NVARCHAR( 10), ' +
                     '@cCCDetailKey    NVARCHAR( 10), ' +
                     '@cLoc            NVARCHAR( 10), ' +
                     '@cID             NVARCHAR( 18), ' +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@nActQTY         INT, ' +
                     '@cLottable01     NVARCHAR( 18), ' +
                     '@cLottable02     NVARCHAR( 18), ' +
                     '@cLottable03     NVARCHAR( 18), ' +
                     '@dLottable04     DATETIME, ' +
                     '@dLottable05     DATETIME, ' +
                     '@cLottable06     NVARCHAR( 30), ' +
                     '@cLottable07     NVARCHAR( 30), ' +
                     '@cLottable08     NVARCHAR( 30), ' +
                     '@cLottable09     NVARCHAR( 30), ' +
                     '@cLottable10     NVARCHAR( 30), ' +
                     '@cLottable11     NVARCHAR( 30), ' +
                     '@cLottable12     NVARCHAR( 30), ' +
                     '@dLottable13     DATETIME, ' +
                     '@dLottable14     DATETIME, ' +
                     '@dLottable15     DATETIME, ' +
                     '@cExtendedInfo   NVARCHAR( 20) OUTPUT '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
                     @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                     @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                     @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                     @cExtendedInfo OUTPUT

                  SET @cOutField15 = @cExtendedInfo
               END
            END
            SET @cFieldAttr08 = 'O'
            SET @cFieldAttr09 = 'O'
            SET @cFieldAttr10 = 'O'
            SET @cFieldAttr11 = 'O'
            SET @cOutField14 = @cLoc
        -- Prepare Next Screen Variable
        SET @cInField05 = ''
            SET @cInField06 = '' --SOS278025
            SET @cInField07 = '' --SOS278025

        -- GOTO Next Screen
        SET @nScn = @nScn - 1
          SET @nStep = @nStep - 1

            IF @cFieldAttr12 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 12
            ELSE
            BEGIN
               IF @nPQTY > 0
                  EXEC rdt.rdtSetFocusField @nMobile, 06
               ELSE
                  EXEC rdt.rdtSetFocusField @nMobile, 07
            END
         END
         ELSE
         BEGIN
            SET @cOutField01 = @cLoc
            SET @cOutField02 = @cID
            SET @cOutField03 = ''

            SET @cOutField04 = ''
            SET @cOutField05 = ''

         SET @cFieldAttr04 = 'O'
            SET @cFieldAttr05 = 'O'

            IF @cPickMethod = 'SKU'
            BEGIN
               SET @cSuggSKU = ''
               SELECT @cSuggSKU = SKU FROM dbo.CCDetail WITH (NOLOCK)
               WHERE CCKey = @cCCKey
               --AND STatus  = '0'
               AND Loc     = @cLoc
               AND ID      = @cID
               AND Status < '9'
               AND CCSheetNo = @cTaskDetailKey

               SET @cOutField06 = @cSuggSKU
            END

            -- Extended info
            IF @cExtendedInfoSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
               BEGIN
                  SET @cExtendedInfo = ''

                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
                     ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                     ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                     ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                     ' @cExtendedInfo OUTPUT '

                  SET @cSQLParam =
                     '@nMobile         INT, ' +
                     '@nFunc           INT, ' +
                     '@cLangCode       NVARCHAR( 3), ' +
                     '@nStep           INT, ' +
                     '@nInputKey       INT, ' +
                     '@cStorerKey      NVARCHAR( 15), ' +
                     '@cTaskDetailKey  NVARCHAR( 10), ' +
                     '@cCCKey          NVARCHAR( 10), ' +
                     '@cCCDetailKey    NVARCHAR( 10), ' +
                     '@cLoc            NVARCHAR( 10), ' +
                     '@cID             NVARCHAR( 18), ' +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@nActQTY         INT, ' +
                     '@cLottable01     NVARCHAR( 18), ' +
                     '@cLottable02     NVARCHAR( 18), ' +
                     '@cLottable03     NVARCHAR( 18), ' +
                     '@dLottable04     DATETIME, ' +
                     '@dLottable05     DATETIME, ' +
                     '@cLottable06     NVARCHAR( 30), ' +
                     '@cLottable07     NVARCHAR( 30), ' +
                     '@cLottable08     NVARCHAR( 30), ' +
                     '@cLottable09     NVARCHAR( 30), ' +
                     '@cLottable10     NVARCHAR( 30), ' +
                     '@cLottable11     NVARCHAR( 30), ' +
                     '@cLottable12     NVARCHAR( 30), ' +
                     '@dLottable13     DATETIME, ' +
                     '@dLottable14     DATETIME, ' +
                     '@dLottable15     DATETIME, ' +
                     '@cExtendedInfo   NVARCHAR( 20) OUTPUT '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
                     @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                     @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                     @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                     @cExtendedInfo OUTPUT

                  SET @cOutField15 = @cExtendedInfo
               END
            END

            SET @cCCOption           = ''
            SET @cNewSKUorLottable   = ''
            SET @cHasLottable        = ''

            --go to previous screen
            SET @nScn  = @nScn - 2
            SET @nStep = @nStep - 2
         END
      END
      ELSE IF @cOptions = '5'
      BEGIN

         -- SET to 1 for New Found SKU or Lottables
         SET @cNewSKUorLottable = '1'
         SET @cOutField01 = @cSKU

         SET @cOutField02 = @cSKUDescr1
         SET @cOutField03 = @cSKUDescr2

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


         SET @cSKUDescr = ''
         SET @cMUOM_Desc = ''
         SET @cPUOM_Desc = ''

         SET @nQtyAval = 0
         SET @nQty = 0
         SET @nPUOM_Div = 0
         SET @nMQTY = 0
         SET @nPQTY = 0

         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = NULL
         SET @dLottable05 = NULL
         SET @cEnableAllLottables = rdt.RDTGetConfig( @nFunc, 'EnableAllLottables', @cStorerKey)
         IF ISNULL(@cEnableAllLottables,'') = '1'
         BEGIN
            SET @cNewSKUorLottable = ''
            SET @cSkipLottable = '1'
            SET @cLottable01 = ''
            SET @cLottable02 = ''
            SET @cLottable03 = ''
            SET @dLottable04 = NULL
            SET @dLottable05 = NULL
            SET @cLottable06 = ''
            SET @cLottable07 = ''
            SET @cLottable08 = ''
            SET @cLottable09 = ''
            SET @cLottable10 = ''
            SET @cLottable11 = ''
            SET @cLottable12 = ''
            SET @dLottable13 = NULL
            SET @dLottable14 = NULL
            SET @dLottable15 = NULL
            SELECT
                  @cLottableCode = LottableCode
               FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
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
               --V3.8 by jackc
               --@cCCKey,
               @cTaskDetailKey, --V3.8 by jackc END
               @nFunc

            IF @nErrNo <> 0
               GOTO Quit

            IF @nMorePage = 1 -- Yes
            BEGIN
               -- Go to dynamic lottable screen
               SET @nFromScn = @nScn
               SET @nScn = 3990
               SET @nStep = 7
            END
            ELSE
            BEGIN
               SET @nPrevStep = 0    
               SET @nPrevScreen  = 0    
         
               SET @nPrevStep = @nStep    
               SET @nPrevScreen = @nScn    
         
               SET @cOutField01 = ''    
               -- GOTO Option Screen   
               SET @nScn = 2942    
               SET @nStep = 3    
            END
            GOTO QUIT 
         END
        -- GET LOTTABLE LABEL & VALUES
         SELECT
            @cSKUDescr = SKU.DESCR
          , @cMUOM_Desc  = Pack.PackUOM3
          , @cPUOM_Desc  =
         CASE @cPUOM
            WHEN '2' THEN Pack.PackUOM1 -- Case
            WHEN '3' THEN Pack.PackUOM2 -- Inner pack
            WHEN '6' THEN Pack.PackUOM3 -- Master unit
            WHEN '1' THEN Pack.PackUOM4 -- Pallet
            WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
            WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
         END
          , @nPUOM_Div  = CAST( IsNULL(
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
         WHERE SKU.SKU = @cSKU
            AND SKU.StorerKey = @cStorerKey

         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nQtyAval
         END
         ELSE
         BEGIN
            SET @nPQTY = @nQtyAval / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nQtyAval % @nPUOM_Div  -- Calc the remaining in master unit
         END

         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField04 = ''
            SET @cOutField06 = ''
            SET @cFieldAttr06 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField04 = @cPUOM_Desc
            SET @cOutField06 = '' -- CAST( @nPQTY AS NVARCHAR( 5))
         END

         IF @nPQTY <= 0
         BEGIN
            SET @cOutField04 = ''
            SET @cOutField06 = ''
            SET @cOutField06 = ''
            SET @cFieldAttr06 = 'O'
         END

         SET @cOutField05 = @cMUOM_Desc
         SET @cOutField07 = '' --CAST( @nMQTY as NVARCHAR( 5))
         SET @cFieldAttr07 = ''

         IF @nPQTY > 0
            EXEC rdt.rdtSetFocusField @nMobile, 06
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 07

         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = NULL
         SET @dLottable05 = NULL

         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''

         SELECT
            @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description]
                                    FROM dbo.CodeLKUP C WITH (NOLOCK)
                                    WHERE C.Code = S.Lottable01Label
                                    AND C.ListName = 'LOTTABLE01'
                                    AND C.Code <> ''
                                    AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                    ORDER By C.StorerKey DESC), ''),
            @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description]
                                    FROM dbo.CodeLKUP C WITH (NOLOCK)
                                    WHERE C.Code = S.Lottable02Label
                                    AND C.ListName = 'LOTTABLE02'
                                    AND C.Code <> ''
                                    AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                    ORDER By C.StorerKey DESC), ''),
            @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description]
                                    FROM dbo.CodeLKUP C WITH (NOLOCK)
                                    WHERE C.Code = S.Lottable03Label
                                    AND C.ListName = 'LOTTABLE03'
                                    AND C.Code <> ''
                                    AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                    ORDER By C.StorerKey DESC), ''),
            @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description]
                                    FROM dbo.CodeLKUP C WITH (NOLOCK)
                                    WHERE C.Code = S.Lottable04Label
                                    AND C.ListName = 'LOTTABLE04'
                                    AND C.Code <> ''
                                    AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                    ORDER By C.StorerKey DESC), ''),
            @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description]
                                    FROM dbo.CodeLKUP C WITH (NOLOCK)
                                    WHERE C.Code = S.Lottable05Label
                                    AND C.ListName = 'LOTTABLE05'
                                    AND C.Code <> ''
                                    AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                    ORDER By C.StorerKey DESC), ''),
            @cLottable05_Code = IsNULL( S.Lottable05Label, ''),
            @cLottable01_Code = IsNULL(S.Lottable01Label, ''),
            @cLottable02_Code = IsNULL(S.Lottable02Label, ''),
            @cLottable03_Code = IsNULL(S.Lottable03Label, ''),
            @cLottable04_Code = IsNULL(S.Lottable04Label, '')
         FROM dbo.SKU S WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
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
         /*  - Start                                                                                                         */
         /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
         /* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
         /* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label> */
         /* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
         /*    Codelkup.Short = 'PRE' and Codelkup.Long = <SP Name>                                                          */
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
            FROM dbo.CodeLkUp C WITH (NOLOCK)
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

               EXEC dbo.ispLottableRule_Wrapper
                  @c_SPName            = @cStoredProd,
                  @c_ListName          = @cListName,
                  @c_Storerkey         = @cStorerKey,
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
                  @b_Success           = @bSuccess   OUTPUT,
                  @n_Err               = @nErrNo      OUTPUT,
                  @c_Errmsg   = @cErrMsg     OUTPUT,
                  @c_Sourcekey         = @cSourcekey,
                  @c_Sourcetype        = 'RDTRECEIPT'

              IF ISNULL(@cErrMsg, '') <> ''
               BEGIN
                  SET @cErrMsg = @cErrMsg
                  GOTO Step_1_Fail
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
            END

            -- increase counter by 1
            SET @nCountLot = @nCountLot + 1
         END -- nCount
      END -- Lottable <> ''

      /********************************************************************************************************************/
      /* - End                                                                                                            */
      /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
      /********************************************************************************************************************/

      SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)
      SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)
      SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)
      SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)

      -- Skip lottable
      IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = '', @cLottable01 = ''
      IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = '', @cLottable02 = ''
      IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = '', @cLottable03 = ''
      IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = '', @dLottable04 = 0

      IF @cHasLottable = '1'
      BEGIN
         -- Disable lot label and lottable field
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O'
            SET @cOutField08 = ''
         END
         ELSE
         BEGIN
            -- Populate lot label and lottable
            SELECT
               @cOutField08 = ISNULL(@cLottable01, '')
            END

            IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
            BEGIN
               SET @cFieldAttr09 = 'O'
               SET @cOutField09 = ''
            END
            ELSE
            BEGIN
               SELECT
                  @cOutField09 = ISNULL(@cLottable02, '')
            END

            IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
            BEGIN

               SET @cFieldAttr10 = 'O'
               SET @cOutField10 = ''
            END
            ELSE
            BEGIN
               SELECT
               @cOutField10 = ISNULL(@cLottable03, '')
            END

            IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
            BEGIN
               SET @cFieldAttr11 = 'O'
               SET @cOutField11 = ''
            END
            ELSE
            BEGIN
               SELECT
                  @cOutField11 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))

               -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan (james07)
               IF ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable04) = '1900/01/01'
                  SET @cOutField08 = ''
            END
         END


         IF @cHasLottable = '0'
         BEGIN

            -- Not Lottable
            SET @cLottable01 = ''
            SET @cLottable02 = ''
            SET @cLottable03 = ''
            SET @cLottable04 = ''
         END

         SET @nPrevStep = @nStep
         SET @nPrevScreen = @nScn

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, ' +
               ' @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, @cOptions, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '


            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3), ' +
               '@nStep           INT, ' +
               '@nAfterStep      INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTaskDetailKey  NVARCHAR( 10), ' +
               '@cCCKey          NVARCHAR( 10), ' +
               '@cCCDetailKey    NVARCHAR( 10), ' +
               '@cLoc            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nActQTY         INT, ' +
               '@cOptions        NVARCHAR( 1), ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME, ' +
               '@dLottable05     DATETIME, ' +
               '@cLottable06     NVARCHAR( 30), ' +
               '@cLottable07     NVARCHAR( 30), ' +
               '@cLottable08     NVARCHAR( 30), ' +
               '@cLottable09     NVARCHAR( 30), ' +
               '@cLottable10     NVARCHAR( 30), ' +
               '@cLottable11     NVARCHAR( 30), ' +
               '@cLottable12     NVARCHAR( 30), ' +
               '@dLottable13     DATETIME, ' +
               '@dLottable14     DATETIME, ' +
               '@dLottable15     DATETIME, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey,
               @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,  @cOptions,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
 END  -- Inputkey = 1
 GOTO Quit

   STEP_3_FAIL:
   BEGIN
      SET @cOutField01 = ''
   END
END
GOTO QUIT

/********************************************************************************
Step 4.
    Screen = 2943
    Message
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER  / ESC
   BEGIN

      /****************************
       prepare next screen variable
      ****************************/

      --@cCCOption
      -- 1 = END ID
      -- 2 = END LOC
      SET @cCCOption           = ''
      SET @cNewSKUorLottable   = ''
      SET @cHasLottable        = ''

      -- GOTO Main Module Get Next Task Screen Screen
      SET @nFunc = 1766
      SET @nScn = 2875
      SET @nStep = 6
   END
   GOTO QUIT

END
GOTO Quit

/********************************************************************************
Step 5. Screen = 3570. Multi SKU
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
Step_5:
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
         @cCommodity     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
   END

      -- Prepare Next Screen Var
      SET @cOutField01 = @cLoc
      SET @cOutField02 = @cID
      SET @cOutField03 = @cCommodity

      SET @cOutField04 = ''
      SET @cOutField05 = ''

      SET @cFieldAttr04 = 'O'
      SET @cFieldAttr05 = 'O'


      IF @cPickMethod = 'SKU'
      BEGIN
         SET @cOutField06 =  @cCommodity
      END
      ELSE
      BEGIN
         SET @cOutField06 = ''
      END

      SET @cOutField07 = @cPickMethod


      -- Go to SKU screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 4
   END

END
GOTO Quit

/********************************************************************************  
Step 6. Scn = 2944.  
   Options (Input , Field01)  
  
********************************************************************************/  
Step_6:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
  
      SET @cOption = ISNULL(RTRIM(@cInField01),'')  
  
      IF ISNULL(@cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 74533  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'  
         GOTO Step_6_Fail  
      END  
  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 74534  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'  
         GOTO Step_6_Fail  
      END  
  
      IF @cOption = '1'  
      BEGIN  
         SET @cSKUDescr = ''  
         SET @cMUOM_Desc = ''  
         SET @cPUOM_Desc = ''  
  
         SET @nQtyAval = 0  
         SET @nQty = 0  
         SET @nPUOM_Div = 0  
         SET @nMQTY = 0  
         SET @nPQTY = 0  
  
         SET @cLottable01 = ''  
         SET @cLottable02 = ''  
         SET @cLottable03 = ''  
         SET @dLottable04 = NULL  
         SET @dLottable05 = NULL  
  
         SELECT  
              @cSKUDescr = SKU.DESCR  
            , @cMUOM_Desc  = Pack.PackUOM3  
            , @cPUOM_Desc  =  
            CASE @cPUOM  
               WHEN '2' THEN Pack.PackUOM1 -- Case  
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack  
               WHEN '6' THEN Pack.PackUOM3 -- Master unit  
               WHEN '1' THEN Pack.PackUOM4 -- Pallet  
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1  
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2  
            END  
            ,  @nPUOM_Div  = CAST( IsNULL(  
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
         WHERE SKU.SKU = @cSKU  
           AND SKU.StorerKey = @cStorerKey  
  
         SET @cCCDetailKey = ''  
  
         IF @cCCGroupExLottable05 = '1'  
         BEGIN  
            SELECT TOP 1  
                     @cLottable01 = CC.Lottable01  
                   , @cLottable02 = CC.Lottable02  
                   , @cLottable03 = CC.Lottable03  
                   , @dLottable04 = CC.Lottable04  --yeekung01       
                   , @nQtyAval    =  SUM(CC.SystemQty)  
                   , @cCCDetailKey = MIN(CC.CCDetailKey)  
                   , @nQty        = SUM(CC.Qty)  
            FROM dbo.CCDetail CC WITH (NOLOCK)  
            WHERE CC.SKU = @cSKU  
            AND CC.CCKey = @cCCKey  
            AND CC.Loc   = @cLoc  
            AND CC.ID    = @cID  
            AND Status < '9'  
            AND CC.CCSheetNo = @cTaskDetailKey  
            GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04  
            ORDER BY MIN(CC.CCDetailKey)  
  
            SET @nLottableCountTotal = 0  
            SELECT @nLottableCountTotal =  COUNT(1)  
            FROM dbo.CCDetail CC WITH (NOLOCK)  
            WHERE CC.SKU = @cSKU  
            AND CC.CCKey = @cCCKey  
            AND CC.Loc   = @cLoc  
            AND CC.ID    = @cID  
            AND Status < '9'  
            AND CC.CCSheetNo = @cTaskDetailKey  
            GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04  
         END  
         ELSE  
         BEGIN  
            SELECT TOP 1  
                     @cLottable01 = CC.Lottable01  
                   , @cLottable02 = CC.Lottable02  
                   , @cLottable03 = CC.Lottable03  
            , @dLottable04 = CC.Lottable04  --yeekung01      
                   , @dLottable05 = CC.Lottable05  --yeekung01      
                   , @nQtyAval    =  CC.SystemQty  
                   , @cCCDetailKey = CC.CCDetailKey  
                   , @nQty        = CC.Qty  
            FROM dbo.CCDetail CC WITH (NOLOCK)  
            WHERE CC.SKU = @cSKU  
            AND CC.CCKey = @cCCKey  
            AND CC.Loc   = @cLoc  
            AND CC.ID    = @cID  
            AND Status < '9'  
            AND CC.CCSheetNo = @cTaskDetailKey  
            ORDER BY CCDetailKey  
  
            SET @nLottableCountTotal = 0  
            SELECT @nLottableCountTotal = COUNT(1)  
            FROM dbo.CCDetail CC WITH (NOLOCK)  
            WHERE CC.SKU = @cSKU  
            AND CC.CCKey = @cCCKey  
            AND CC.Loc   = @cLoc  
            AND CC.ID    = @cID  
            AND Status < '9'  
            AND CC.CCSheetNo = @cTaskDetailKey  
         END  
  
         SET @cCounted = ''  
  
         IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)  
                     WHERE CCKey = @cCCKey  
                     AND SKU = @cSKU  
                     AND Loc = @cLoc  
                     AND ID  = @cID  
                     AND Status < '9'  
                     AND Qty > 0  
                     AND CCSheetNo = @cTaskDetailKey  
                     AND CCdetailKey = @cCCDetailKey)  
         BEGIN  
            SET @nQtyAval = @nQty  
            SET @cCounted = '1'  
         END  
  
         -- Convert to prefer UOM QTY  
         IF @cPUOM = '6' OR -- When preferred UOM = master unit  
            @nPUOM_Div = 0  -- UOM not setup  
         BEGIN  
            SET @cPUOM_Desc = ''  
            SET @nPQTY = 0  
            SET @nMQTY = @nQtyAval  
         END  
         ELSE  
         BEGIN  
            SET @nPQTY = @nQtyAval / @nPUOM_Div  -- Calc QTY in preferred UOM  
            SET @nMQTY = @nQtyAval % @nPUOM_Div  -- Calc the remaining in master unit  
         END  
  
         -- Prepare Next Screen Variable  
         SET @cSKUDescr1 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
         SET @cSKUDescr2 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 1  
  
         SET @cOutField01 = @cSKU  
         SET @cOutField02 = @cSKUDescr1  
         SET @cOutField03 = @cSKUDescr2  
  
         SET @nLottableCount = 0  
         SET @cOutField13 = CASE WHEN @cSkipLottable = '1' THEN ''   
                                 ELSE RTRIM(CAST(@nLottableCount AS NVARCHAR(4))) +  '/' +   
                                      RTRIM(CAST(@nLottableCountTotal AS NVARCHAR(4)))   
                                 END  
  
         IF @cPUOM_Desc = ''  
         BEGIN  
            SET @cOutField04 = ''  
            SET @cOutField06 = ''  
            SET @cFieldAttr06 = 'O'  
         END  
         ELSE  
         BEGIN  
            SET @cOutField04 = @cPUOM_Desc  
            IF @cCounted = '1'  
            BEGIN  
               SET @cOutField06 = CAST( @nPQTY AS NVARCHAR( 5))  
            END  
            ELSE  
            BEGIN  
               SET @cOutField06 = ''  
            END  
         END  
  
         IF @nPQTY <= 0  
         BEGIN  
            --SET @cOutField04 = ''  
            SET @cOutField06 = ''  
            SET @cOutField06 = ''  
            SET @cFieldAttr06 = 'O'  
         END  
  
         SET @cOutField05 = @cMUOM_Desc  
  
         IF @cCounted = '1'  
         BEGIN  
            SET @cOutField07 = CAST( @nMQTY AS NVARCHAR( 5))  
         END  
         ELSE  
         BEGIN  
            SET @cOutField07 = ''  
         END  
  
         SET @cFieldAttr07 = ''  
  
         IF @nPQTY > 0  
            EXEC rdt.rdtSetFocusField @nMobile, 06  
         ELSE  
            EXEC rdt.rdtSetFocusField @nMobile, 07  
  
         SET @cFieldAttr08 = 'O'  
         SET @cFieldAttr09 = 'O'  
         SET @cFieldAttr10 = 'O'  
         SET @cFieldAttr11 = 'O'  
  
         IF @cSkipLottable = '1'    
         BEGIN    
            SET @cOutField08 = ''    
            SET @cOutField09 = ''    
            SET @cOutField10 = ''    
            SET @cOutField11 = ''    
         END    
         ELSE          
         BEGIN    
            SET @cOutField08 = @cLottable01    
            SET @cOutField09 = @cLottable02    
            SET @cOutField10 = @cLottable03    
            SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)    
         END    
  
         SET @cFieldAttr06 = ''  
         SET @cFieldAttr07 = ''  
         SET @cFieldAttr12 = ''  
  
         --SET @nDefaultQty = 0  
  
         -- if default qty turned on then overwrite the actual MQty (james02)  
     --SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)  
         IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1  
            SET @nDefaultQty = CAST( @cDefaultQty AS INT)  
         ELSE  
            SET @nDefaultQty = 0  
  
         IF @nDefaultQty > 0  
         BEGIN  
            SET @cFieldAttr12 = ''  
            SET @cOutField12 = ''  
            SET @cFieldAttr06 = 'O'  
            SET @cFieldAttr07 = 'O'  
  
            -- Convert to prefer UOM QTY  
            IF @cPUOM = '6' OR -- When preferred UOM = master unit  
               @nPUOM_Div = 0  -- UOM not setup  
               SET @cOutField07 = @nDefaultQty  
            ELSE  
            BEGIN  
               IF @nDefaultQty > @nPUOM_Div  
               BEGIN  
                  SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM  
                  SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit  
               END  
               ELSE  
                  SET @cOutField07 = @nDefaultQty  
            END  
         END  
         ELSE  
         BEGIN  
            SET @cFieldAttr12 = 'O'  
            SET @cOutField12 = ''  
         END  

         -- Extended info
         IF @cExtendedDisplayQtySP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedDisplayQtySP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedDisplayQtySP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
                  ' @cBarcode, @cPUOM, @nPUOM_Div, @cPUOM_Desc OUTPUT, @cMUOM_Desc OUTPUT, ' +
                  ' @cFieldAttr06 OUTPUT, @cFieldAttr07 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, @cOutField06 OUTPUT, @cOutField07 OUTPUT, ' +
                  ' @tExtendedDisplayQty '

               SET @cSQLParam =
                  '@nMobile         INT, ' +
                  '@nFunc           INT, ' +
                  '@cLangCode       NVARCHAR( 3), ' +
                  '@nStep           INT, ' +
                  '@nInputKey       INT, ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cTaskDetailKey  NVARCHAR( 10), ' +
                  '@cCCKey          NVARCHAR( 10), ' +
                  '@cCCDetailKey    NVARCHAR( 10), ' +
                  '@cLoc            NVARCHAR( 10), ' +
                  '@cID             NVARCHAR( 18), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nActQTY         INT, ' +
                  '@cBarcode        NVARCHAR( 60), ' +
                  '@cPUOM           NVARCHAR( 1), ' +
                  '@nPUOM_Div       NVARCHAR( 5), ' +
                  '@cPUOM_Desc      NVARCHAR( 5)   OUTPUT, ' +
                  '@cMUOM_Desc      NVARCHAR( 5)   OUTPUT, ' +
                  '@cFieldAttr06    NVARCHAR( 1)   OUTPUT, ' +
                  '@cFieldAttr07    NVARCHAR( 1)   OUTPUT, ' +
                  '@cOutField04     NVARCHAR( 60)  OUTPUT, ' +
                  '@cOutField05     NVARCHAR( 60)  OUTPUT, ' +
                  '@cOutField06     NVARCHAR( 60)  OUTPUT, ' +
                  '@cOutField07     NVARCHAR( 60)  OUTPUT, ' + 
                  '@tExtendedDisplayQty   VARIABLETABLE READONLY' 
               
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
                  @cBarcode, @cPUOM, @nPUOM_Div, @cPUOM_Desc OUTPUT, @cMUOM_Desc OUTPUT,
                  @cFieldAttr06 OUTPUT, @cFieldAttr07 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, @cOutField06 OUTPUT, @cOutField07 OUTPUT,
                  @tExtendedDisplayQty
            END
         END
         ELSE
         BEGIN
            -- if default qty turned on then overwrite the actual MQty (james02)
            --SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)
            IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1
               SET @nDefaultQty = CAST( @cDefaultQty AS INT)
            ELSE
               SET @nDefaultQty = 0

            IF @nDefaultQty > 0
            BEGIN
               SET @cFieldAttr12 = ''
               SET @cOutField12 = ''
               SET @cFieldAttr06 = 'O'
               SET @cFieldAttr07 = 'O'

               -- Convert to prefer UOM QTY
               IF @cPUOM = '6' OR -- When preferred UOM = master unit
                  @nPUOM_Div = 0  -- UOM not setup
                  SET @cOutField07 = @nDefaultQty
               ELSE
               BEGIN
                  IF @nDefaultQty > @nPUOM_Div
                  BEGIN
                     SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM
                     SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit
                  END
                  ELSE
                     SET @cOutField07 = @nDefaultQty
               END
            END
            ELSE
            BEGIN
               SET @cFieldAttr12 = 'O'
               SET @cOutField12 = ''
            END

            IF @nPQTY > 0       
               EXEC rdt.rdtSetFocusField @nMobile, 06  
            ELSE  
               EXEC rdt.rdtSetFocusField @nMobile, 07  
         END
      
         SET @cNewSKUorLottable = ''  
  
         IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)  
                       WHERE CCKey = @cCCKey  
                       AND Loc     = @cLoc  
                       AND ID      = @cID  
                       AND SKU     = @cSKU  
                       AND Status  < '9'  
                       AND CCSheetNo = @cTaskDetailKey  )  
         BEGIN  
               -- SET to 1 for New Found SKU or Lottables  
               SET @cNewSKUorLottable = '1'  
  
               SET @cFieldAttr08 = ''  
               SET @cFieldAttr09 = ''  
               SET @cFieldAttr10 = ''  
               SET @cFieldAttr11 = ''  
               SET @cFieldAttr12 = ''  
               SET @cFieldAttr13 = ''  
               SET @cFieldAttr14 = ''  
               SET @cFieldAttr15 = ''  
  
               -- (james02)  
               SELECT  
                  @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description] 
                                          FROM dbo.CodeLKUP C WITH (NOLOCK) 
                                          WHERE C.Code = S.Lottable01Label 
                                          AND C.ListName = 'LOTTABLE01' AND C.Code <> '' 
                                          AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') 
                                          ORDER By C.StorerKey DESC), ''),  
                  @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description] 
                                          FROM dbo.CodeLKUP C WITH (NOLOCK) 
                                          WHERE C.Code = S.Lottable02Label 
                                          AND C.ListName = 'LOTTABLE02' AND C.Code <> '' 
                                          AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') 
                                          ORDER By C.StorerKey DESC), ''),  
                  @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description] 
                                          FROM dbo.CodeLKUP C WITH (NOLOCK) 
                                          WHERE C.Code = S.Lottable03Label 
                                          AND C.ListName = 'LOTTABLE03' AND C.Code <> '' 
                                          AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') 
                                          ORDER By C.StorerKey DESC), ''),  
                  @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description] 
                                          FROM dbo.CodeLKUP C WITH (NOLOCK) 
                                          WHERE C.Code = S.Lottable04Label 
                                          AND C.ListName = 'LOTTABLE04' AND C.Code <> '' 
                                          AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') 
                                          ORDER By C.StorerKey DESC), ''),  
                  @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description] 
                                          FROM dbo.CodeLKUP C WITH (NOLOCK) 
                                          WHERE C.Code = S.Lottable05Label 
                                          AND C.ListName = 'LOTTABLE05' AND C.Code <> '' 
                                          AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') 
                                          ORDER By C.StorerKey DESC), ''),  
                  @cLottable05_Code = IsNULL( S.Lottable05Label, ''),  
                  @cLottable01_Code = IsNULL(S.Lottable01Label, ''),  
                  @cLottable02_Code = IsNULL(S.Lottable02Label, ''),  
                  @cLottable03_Code = IsNULL(S.Lottable03Label, ''),  
                  @cLottable04_Code = IsNULL(S.Lottable04Label, '')  
               FROM dbo.SKU S WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
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
               /*  - Start                                                                                                         */  
               /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */  
               /* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */  
               /* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */  
               /* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */  
               /*    Codelkup.Short = 'PRE' and Codelkup.Long = <SP Name>                                                          */  
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
                     FROM dbo.CodeLkUp C WITH (NOLOCK)  
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
  
                        EXEC dbo.ispLottableRule_Wrapper  
                           @c_SPName            = @cStoredProd,  
                           @c_ListName          = @cListName,  
                           @c_Storerkey         = @cStorerKey,  
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
                           @b_Success           = @bSuccess   OUTPUT,  
                           @n_Err               = @nErrNo      OUTPUT,  
                           @c_Errmsg            = @cErrMsg     OUTPUT,  
                           @c_Sourcekey         = @cSourcekey,  
                           @c_Sourcetype        = 'RDTRECEIPT'  
  
                        --IF @b_success <> 1  
                        IF ISNULL(@cErrMsg, '') <> ''  
                        BEGIN  
                           SET @cErrMsg = @cErrMsg  
                           GOTO Step_1_Fail  
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
                     END  
  
                     -- increase counter by 1  
                     SET @nCountLot = @nCountLot + 1  
                  END -- nCount  
               END -- Lottable <> ''  
  
               /********************************************************************************************************************/  
               /* - End                                                                                                            */  
               /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */  
               /********************************************************************************************************************/  
  
               IF @cSkipLottable = '1'    
               BEGIN    
                  SET @cSkipLottable01 = '1'    
                  SET @cSkipLottable02 = '1'    
                  SET @cSkipLottable03 = '1'    
                  SET @cSkipLottable04 = '1'    
                  SET @cHasLottable = '0'    
               END    
               ELSE    
               BEGIN    
                  SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)    
                  SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)    
                  SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)    
                  SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)    
               END    
  
               IF @cSkipLottable01 = '1' SELECT @cFieldAttr08 = 'O', @cInField08 = '', @cLottable01 = ''  
               IF @cSkipLottable02 = '1' SELECT @cFieldAttr09 = 'O', @cInField09 = '', @cLottable02 = ''  
               IF @cSkipLottable03 = '1' SELECT @cFieldAttr10 = 'O', @cInField10 = '', @cLottable03 = ''  
               IF @cSkipLottable04 = '1' SELECT @cFieldAttr11 = 'O', @cInField11 = '', @dLottable04 = 0  
  
               IF @cHasLottable = '1'  
               BEGIN  
  
                  -- Disable lot label and lottable field  
                  IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL  
                  BEGIN  
                     SET @cFieldAttr08 = 'O'  
                     SET @cOutField08 = ''  
                  END  
                  ELSE  
                  BEGIN  
                     -- Populate lot label and lottable  
                     SELECT @cOutField08 = ISNULL(@cLottable01, '')  
                  END  
  
                  IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL  
                  BEGIN  
                     SET @cFieldAttr09 = 'O'  
                     SET @cOutField09 = ''  
                  END  
                  ELSE  
                  BEGIN  
                     SELECT @cOutField09 = ISNULL(@cLottable02, '')  
                  END  
  
                  IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL  
                  BEGIN  
                     SET @cFieldAttr10 = 'O'  
                     SET @cOutField10 = ''  
                  END  
                  ELSE  
                  BEGIN  
                     SELECT @cOutField10 = ISNULL(@cLottable03, '')  
                  END  
  
                  IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL  
                  BEGIN  
                     SET @cFieldAttr11 = 'O'  
                     SET @cOutField11 = ''  
                  END  
                  ELSE  
                  BEGIN  
                     SELECT @cOutField11 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))  
  
                     -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan (james07)  
                     IF ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable04) = '1900/01/01'  
                        SET @cOutField08 = ''  
                  END  
               END  
  
               IF @cHasLottable = '0'  
               BEGIN  
                  -- Not Lottable  
                  SET @cLottable01 = ''  
                  SET @cLottable02 = ''  
                  SET @cLottable03 = ''  
                  SET @cLottable04 = ''  
               END  
         END  
  
         -- Extended info  
         IF @cExtendedInfoSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
            BEGIN  
               SET @cExtendedInfo = ''  
  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +  
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
                  ' @cExtendedInfo OUTPUT '  
  
               SET @cSQLParam =  
                  '@nMobile         INT, ' +  
                  '@nFunc           INT, ' +  
                  '@cLangCode       NVARCHAR( 3), ' +  
                  '@nStep           INT, ' +  
                  '@nInputKey       INT, ' +  
                  '@cStorerKey      NVARCHAR( 15), ' +  
                  '@cTaskDetailKey  NVARCHAR( 10), ' +  
                  '@cCCKey          NVARCHAR( 10), ' +  
                  '@cCCDetailKey    NVARCHAR( 10), ' +  
                  '@cLoc            NVARCHAR( 10), ' +  
                  '@cID             NVARCHAR( 18), ' +  
                  '@cSKU            NVARCHAR( 20), ' +  
                  '@nActQTY         INT, ' +  
                  '@cLottable01     NVARCHAR( 18), ' +  
                  '@cLottable02     NVARCHAR( 18), ' +  
                  '@cLottable03     NVARCHAR( 18), ' +  
                  '@dLottable04     DATETIME, ' +  
                  '@dLottable05     DATETIME, ' +  
                  '@cLottable06     NVARCHAR( 30), ' +  
                  '@cLottable07     NVARCHAR( 30), ' +  
                  '@cLottable08     NVARCHAR( 30), ' +  
                  '@cLottable09     NVARCHAR( 30), ' +  
                  '@cLottable10     NVARCHAR( 30), ' +  
                  '@cLottable11     NVARCHAR( 30), ' +  
                  '@cLottable12     NVARCHAR( 30), ' +  
                  '@dLottable13     DATETIME, ' +  
                  '@dLottable14     DATETIME, ' +  
                  '@dLottable15     DATETIME, ' +  
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT '  
  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,  
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
                  @cExtendedInfo OUTPUT  
  
               SET @cOutField15 = @cExtendedInfo  
            END  
         END  
  
         -- Prepare Next Screen Variable  
         SET @cInField05 = ''  
         SET @cInField06 = '' --SOS278025  
         SET @cInField07 = '' --SOS278025  
  
         SET @cOutField14 = @cLoc  
        
         IF @cFieldAttr12 = ''  
            SET @cOutField12 = @cSKU   
  
         IF @nPQTY > 0         
            EXEC rdt.rdtSetFocusField @nMobile, 06    
         ELSE    
            EXEC rdt.rdtSetFocusField @nMobile, 07    
         
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep
         
         -- GOTO Next Screen
         SET @nScn = @nScn - 3  
         SET @nStep = @nStep - 4  
         GOTO Quit  
      END  
      ELSE  
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
  
  
         SET @cOutField01 = ''  
  
         -- GOTO Next Screen  
         SET @nScn = @nScn - 2  
         SET @nStep = @nStep - 3  
  
         GOTO QUIT  
      END  
    END  -- Inputkey = 1  
    GOTO Quit  
  
   STEP_6_FAIL:  
   BEGIN  
      SET @cOutField01 = ''  
   END  
END  
GOTO QUIT  

/********************************************************************************
Step 7. Scn = 3490. Dynamic lottables
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
Step_7:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      
      DECLARE @cOutField15Backup NVARCHAR( 60) = @cOutField15
      SELECT
         @cLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
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
         --V3.8 by jackc
         --@cCCKey,
         @cTaskDetailKey, --V3.8 by jackc END
         @nFunc
      
      IF @nErrNo <> 0
         GOTO Quit
      
      IF @nMorePage = 1 -- Yes
         GOTO Quit

      SET @cSKUDescr = ''    
      SET @cMUOM_Desc = ''    
      SET @cPUOM_Desc = ''
    
      SET @nQtyAval = 0
      SET @nQty = 0
      SET @nPUOM_Div = 0
      SET @nMQTY = 0
      SET @nPQTY = 0
    
      SELECT    
           @cSKUDescr = SKU.DESCR    
         , @cMUOM_Desc  = Pack.PackUOM3    
         , @cPUOM_Desc  =    
         CASE @cPUOM    
            WHEN '2' THEN Pack.PackUOM1 -- Case    
            WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
            WHEN '6' THEN Pack.PackUOM3 -- Master unit    
            WHEN '1' THEN Pack.PackUOM4 -- Pallet    
            WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
            WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
         END    
         ,  @nPUOM_Div  = CAST( IsNULL(    
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
      WHERE SKU.SKU = @cSKU    
        AND SKU.StorerKey = @cStorerKey    

      SET @cCounted = ''    
    
      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                  WHERE CCKey = @cCCKey    
                  AND SKU = @cSKU    
                  AND Loc = @cLoc    
                  AND ID  = @cID    
                  AND Status < '9'    
                  AND Qty > 0    
                  AND CCSheetNo = @cTaskDetailKey    
                  AND CCdetailKey = @cCCDetailKey)    
      BEGIN    
         SET @nQtyAval = @nQty    
         SET @cCounted = '1'    
      END    
    
      -- Convert to prefer UOM QTY    
      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
         @nPUOM_Div = 0  -- UOM not setup    
      BEGIN    
         SET @cPUOM_Desc = ''    
         SET @nPQTY = 0    
         SET @nMQTY = @nQtyAval    
      END    
      ELSE    
      BEGIN    
         SET @nPQTY = @nQtyAval / @nPUOM_Div  -- Calc QTY in preferred UOM    
         SET @nMQTY = @nQtyAval % @nPUOM_Div  -- Calc the remaining in master unit    
      END    
    
      -- Prepare Next Screen Variable    
      SET @cSKUDescr1 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1    
      SET @cSKUDescr2 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 1    
    
      SET @cOutField01 = @cSKU    
      SET @cOutField02 = @cSKUDescr1    
      SET @cOutField03 = @cSKUDescr2    
    
      SET @nLottableCount = 0    
      SET @cOutField13 = CASE WHEN @cSkipLottable = '1' THEN ''     
                              ELSE RTRIM(CAST(@nLottableCount AS NVARCHAR(4))) +  '/' +     
                                   RTRIM(CAST(@nLottableCountTotal AS NVARCHAR(4)))     
                              END    
    
      IF @cPUOM_Desc = ''    
      BEGIN    
         SET @cOutField04 = ''    
         SET @cOutField06 = ''    
         SET @cFieldAttr06 = 'O'    
      END    
      ELSE    
      BEGIN    
         SET @cOutField04 = @cPUOM_Desc    
         IF @cCounted = '1'    
         BEGIN    
            SET @cOutField06 = CAST( @nPQTY AS NVARCHAR( 5))    
         END    
         ELSE    
         BEGIN    
            SET @cOutField06 = ''    
         END    
      END    
  
      SET @cFieldAttr06 = ''    
      SET @cFieldAttr07 = ''    
      SET @cFieldAttr12 = ''    
  
      IF @nPQTY <= 0    
      BEGIN    
         --SET @cOutField04 = ''    
         SET @cOutField06 = ''    
         SET @cOutField06 = ''    
         SET @cFieldAttr06 = 'O'    
      END    
    
      SET @cOutField05 = @cMUOM_Desc    
    
      IF @cCounted = '1'    
      BEGIN    
         SET @cOutField07 = CAST( @nMQTY AS NVARCHAR( 5))    
      END    
      ELSE    
      BEGIN    
         SET @cOutField07 = ''    
      END    
    
      SET @cFieldAttr07 = ''    
    
      IF @nPQTY > 0    
         EXEC rdt.rdtSetFocusField @nMobile, 06    
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 07    
    
      SET @cFieldAttr08 = 'O'    
      SET @cFieldAttr09 = 'O'    
      SET @cFieldAttr10 = 'O'    
      SET @cFieldAttr11 = 'O'    
    
      IF @cSkipLottable = '1'      
      BEGIN      
         SET @cOutField08 = ''      
         SET @cOutField09 = ''      
         SET @cOutField10 = ''      
         SET @cOutField11 = ''      
      END      
      ELSE            
      BEGIN      
         SET @cOutField08 = @cLottable01      
         SET @cOutField09 = @cLottable02      
         SET @cOutField10 = @cLottable03      
         SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)      
      END

      IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1    
         SET @nDefaultQty = CAST( @cDefaultQty AS INT)    
      ELSE    
         SET @nDefaultQty = 0    
    
      IF @nDefaultQty > 0    
      BEGIN    
         SET @cFieldAttr12 = ''    
         SET @cOutField12 = ''    
         SET @cFieldAttr06 = 'O'    
         SET @cFieldAttr07 = 'O'    
    
         -- Convert to prefer UOM QTY    
         IF @cPUOM = '6' OR -- When preferred UOM = master unit    
            @nPUOM_Div = 0  -- UOM not setup    
            SET @cOutField07 = @nDefaultQty    
         ELSE    
         BEGIN    
            IF @nDefaultQty > @nPUOM_Div    
            BEGIN    
               SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM    
               SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit    
            END    
            ELSE    
               SET @cOutField07 = @nDefaultQty    
         END    
      END    
      ELSE   
      BEGIN    
         SET @cFieldAttr12 = 'O'    
         SET @cOutField12 = ''    
      END    
  
      -- Extended info  
      IF @cExtendedDisplayQtySP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedDisplayQtySP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedDisplayQtySP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +  
               ' @cBarcode, @cPUOM, @nPUOM_Div, @cPUOM_Desc OUTPUT, @cMUOM_Desc OUTPUT, ' +  
               ' @cFieldAttr06 OUTPUT, @cFieldAttr07 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, @cOutField06 OUTPUT, @cOutField07 OUTPUT, ' +  
               ' @tExtendedDisplayQty '  
  
            SET @cSQLParam =  
               '@nMobile         INT, ' +  
               '@nFunc           INT, ' +  
               '@cLangCode       NVARCHAR( 3), ' +  
               '@nStep           INT, ' +  
               '@nInputKey       INT, ' +  
               '@cStorerKey      NVARCHAR( 15), ' +  
               '@cTaskDetailKey  NVARCHAR( 10), ' +  
               '@cCCKey          NVARCHAR( 10), ' +  
               '@cCCDetailKey    NVARCHAR( 10), ' +  
               '@cLoc            NVARCHAR( 10), ' +  
               '@cID             NVARCHAR( 18), ' +  
               '@cSKU            NVARCHAR( 20), ' +  
               '@nActQTY         INT, ' +  
               '@cBarcode        NVARCHAR( 60), ' +  
               '@cPUOM           NVARCHAR( 1), ' +  
               '@nPUOM_Div       NVARCHAR( 5), ' +  
               '@cPUOM_Desc      NVARCHAR( 5)   OUTPUT, ' +  
               '@cMUOM_Desc      NVARCHAR( 5)   OUTPUT, ' +  
               '@cFieldAttr06    NVARCHAR( 1)   OUTPUT, ' +  
               '@cFieldAttr07    NVARCHAR( 1)   OUTPUT, ' +  
               '@cOutField04     NVARCHAR( 60)  OUTPUT, ' +  
               '@cOutField05     NVARCHAR( 60)  OUTPUT, ' +  
               '@cOutField06     NVARCHAR( 60)  OUTPUT, ' +  
               '@cOutField07     NVARCHAR( 60)  OUTPUT, ' +   
               '@tExtendedDisplayQty   VARIABLETABLE READONLY'   
                 
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,  
               @cBarcode, @cPUOM, @nPUOM_Div, @cPUOM_Desc OUTPUT, @cMUOM_Desc OUTPUT,  
               @cFieldAttr06 OUTPUT, @cFieldAttr07 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, @cOutField06 OUTPUT, @cOutField07 OUTPUT,  
               @tExtendedDisplayQty  
         END  
      END  
      ELSE  
      BEGIN
         IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1  
            SET @nDefaultQty = CAST( @cDefaultQty AS INT)  
         ELSE  
            SET @nDefaultQty = 0  
  
         IF @nDefaultQty > 0  
         BEGIN  
            SET @cFieldAttr12 = ''  
            SET @cOutField12 = ''  
            SET @cFieldAttr06 = 'O'  
            SET @cFieldAttr07 = 'O'  
  
            -- Convert to prefer UOM QTY  
            IF @cPUOM = '6' OR -- When preferred UOM = master unit  
               @nPUOM_Div = 0  -- UOM not setup  
               SET @cOutField07 = @nDefaultQty  
            ELSE  
            BEGIN  
               IF @nDefaultQty > @nPUOM_Div  
               BEGIN  
                  SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM  
                  SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit  
               END  
               ELSE  
                  SET @cOutField07 = @nDefaultQty  
            END  
         END  
         ELSE  
         BEGIN  
            SET @cFieldAttr12 = 'O'  
            SET @cOutField12 = ''  
         END  
  
         IF @nPQTY > 0         
            EXEC rdt.rdtSetFocusField @nMobile, 06    
         ELSE    
            EXEC rdt.rdtSetFocusField @nMobile, 07    
      END

      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +    
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +    
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +    
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +    
               ' @cExtendedInfo OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile         INT, ' +    
               '@nFunc           INT, ' +    
               '@cLangCode       NVARCHAR( 3), ' +    
               '@nStep           INT, ' +    
               '@nInputKey       INT, ' +    
               '@cStorerKey      NVARCHAR( 15), ' +    
               '@cTaskDetailKey  NVARCHAR( 10), ' +    
               '@cCCKey          NVARCHAR( 10), ' +    
               '@cCCDetailKey    NVARCHAR( 10), ' +    
               '@cLoc            NVARCHAR( 10), ' +    
               '@cID             NVARCHAR( 18), ' +    
               '@cSKU            NVARCHAR( 20), ' +    
               '@nActQTY         INT, ' +    
               '@cLottable01     NVARCHAR( 18), ' +    
               '@cLottable02     NVARCHAR( 18), ' +    
               '@cLottable03     NVARCHAR( 18), ' +    
               '@dLottable04     DATETIME, ' +    
               '@dLottable05     DATETIME, ' +    
               '@cLottable06     NVARCHAR( 30), ' +    
               '@cLottable07     NVARCHAR( 30), ' +    
               '@cLottable08     NVARCHAR( 30), ' +    
               '@cLottable09     NVARCHAR( 30), ' +    
               '@cLottable10     NVARCHAR( 30), ' +    
               '@cLottable11     NVARCHAR( 30), ' +    
               '@cLottable12     NVARCHAR( 30), ' +    
               '@dLottable13     DATETIME, ' +    
               '@dLottable14     DATETIME, ' +    
               '@dLottable15     DATETIME, ' +    
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,    
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,    
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,    
               @cExtendedInfo OUTPUT    
    
            SET @cOutField15 = @cExtendedInfo    
         END    
      END    
    
      -- Prepare Next Screen Variable    
      SET @cInField05 = ''    
      SET @cInField06 = '' --SOS278025    
      SET @cInField07 = '' --SOS278025    
    
      SET @cOutField14 = @cLoc    
          
      IF @cFieldAttr12 = ''    
         SET @cOutField12 = @cSKU    
    
      -- GOTO Next Screen    
      SET @nScn = 2941    
      SET @nStep = 2    

      IF @nPrevStep = 6
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 03
         SET @cOutField12 = ''
      END         
      ELSE
      BEGIN
         IF @nPQTY > 0           
            EXEC rdt.rdtSetFocusField @nMobile, 06      
         ELSE      
            EXEC rdt.rdtSetFocusField @nMobile, 07      
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SELECT
         @cLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
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
         --V3.8 by jackc
         --@cCCKey,
         @cTaskDetailKey, --V3.8 by jackc END
         @nFunc

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      SET @cOutField01 = @cLoc    
      SET @cOutField02 = @cID    
      SET @cOutField03 = ''    
    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
    
      SET @cFieldAttr04 = 'O'    
      SET @cFieldAttr05 = 'O'    
    
      IF @cPickMethod = 'SKU'    
      BEGIN    
         SET @cSuggSKU = ''    
         SELECT @cSuggSKU = SKU FROM dbo.CCDetail WITH (NOLOCK)    
         WHERE CCKey = @cCCKey    
         --AND STatus  = '0'    
         AND Loc     = @cLoc    
         AND ID      = @cID    
         AND Status < '9'    
         AND CCSheetNo = @cTaskDetailKey    
    
         SET @cOutField06 = @cSuggSKU    
      END    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +    
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +    
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +    
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +    
               ' @cExtendedInfo OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile         INT, ' +    
               '@nFunc           INT, ' +    
               '@cLangCode       NVARCHAR( 3), ' +    
               '@nStep           INT, ' +    
               '@nInputKey       INT, ' +    
               '@cStorerKey      NVARCHAR( 15), ' +    
               '@cTaskDetailKey  NVARCHAR( 10), ' +    
               '@cCCKey          NVARCHAR( 10), ' +    
               '@cCCDetailKey    NVARCHAR( 10), ' +    
               '@cLoc      NVARCHAR( 10), ' +    
               '@cID       NVARCHAR( 18), ' +    
               '@cSKU      NVARCHAR( 20), ' +    
               '@nActQTY         INT, ' +    
               '@cLottable01     NVARCHAR( 18), ' +    
               '@cLottable02     NVARCHAR( 18), ' +    
               '@cLottable03     NVARCHAR( 18), ' +    
               '@dLottable04     DATETIME, ' +    
               '@dLottable05     DATETIME, ' +    
               '@cLottable06     NVARCHAR( 30), ' +    
               '@cLottable07     NVARCHAR( 30), ' +    
               '@cLottable08     NVARCHAR( 30), ' +    
               '@cLottable09     NVARCHAR( 30), ' +    
               '@cLottable10     NVARCHAR( 30), ' +    
               '@cLottable11     NVARCHAR( 30), ' +    
               '@cLottable12     NVARCHAR( 30), ' +    
               '@dLottable13     DATETIME, ' +    
               '@dLottable14     DATETIME, ' +    
               '@dLottable15     DATETIME, ' +    
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,    
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,    
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,    
               @cExtendedInfo OUTPUT    
    
            SET @cOutField15 = @cExtendedInfo    
         END    
      END    
    
      SET @cCCOption           = ''    
      SET @cNewSKUorLottable   = ''    
      SET @cHasLottable        = ''    
    
      --go to previous screen    
      SET @nScn  = 2940    
      SET @nStep = 1
   END
   GOTO Quit

   Step_5_Fail:
   -- After captured lottable, screen exit and the hidden field (O_Field15) is clear. 
   -- If any error occur, need to simulate as if still staying in lottable screen, by restoring this hidden field
   SET @cOutField15 = @cOutField15Backup
END
GOTO Quit

/********************************************************************************
Step 8. Screen = 4831. Serial No
   SKU            (Field01)
   SKUDesc1       (Field02)
   SKUDesc2       (Field03)
   SerialNo       (Field04, input)
   Scan           (Field05)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Update SKU setting
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cSKU, @cSKUDescr, @nActQTY, 'UPDATE', 'TMCCSKU', @cTaskDetailKey,
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
         @nBulkSNO   OUTPUT,  @nBulkSNOQTY OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Extended info  
      IF @cExtCfmSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtCfmSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtCfmSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, ' +  
               ' @cCCKey, @cCCDetailKey, @cPickMethod, @cLoc, @cID, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               '@nMobile         INT, ' +  
               '@nFunc           INT, ' +  
               '@cLangCode       NVARCHAR( 3), ' +  
               '@nStep           INT, ' +  
               '@nInputKey       INT, ' +  
               '@cStorerKey      NVARCHAR( 15), ' +  
               '@cTaskDetailKey  NVARCHAR( 10), ' +  
               '@cCCKey          NVARCHAR( 10), ' +  
               '@cCCDetailKey    NVARCHAR( 10), ' +  
               '@cPickMethod     NVARCHAR( 10), ' +  
               '@cLoc            NVARCHAR( 10), ' +  
               '@cID             NVARCHAR( 18), ' +  
               '@cSKU            NVARCHAR( 20), ' +  
               '@nQTY            INT, ' +  
               '@cLottable01     NVARCHAR( 18), ' +  
               '@cLottable02     NVARCHAR( 18), ' +  
               '@cLottable03     NVARCHAR( 18), ' +  
               '@dLottable04     DATETIME, ' +  
               '@dLottable05     DATETIME, ' +  
               '@cLottable06     NVARCHAR( 30), ' +  
               '@cLottable07     NVARCHAR( 30), ' +  
               '@cLottable08     NVARCHAR( 30), ' +  
               '@cLottable09     NVARCHAR( 30), ' +  
               '@cLottable10     NVARCHAR( 30), ' +  
               '@cLottable11     NVARCHAR( 30), ' +  
               '@cLottable12     NVARCHAR( 30), ' +  
               '@dLottable13     DATETIME, ' +  
               '@dLottable14     DATETIME, ' +  
               '@dLottable15     DATETIME, ' +  
               '@nErrNo          INT            OUTPUT, ' +  
               '@cErrMsg         NVARCHAR( 20)  OUTPUT '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey,  
               @cCCKey, @cCCDetailKey, @cPickMethod, @cLoc, @cID, @cSKU, @nActQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable07, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
         END  
      END  
      ELSE  
      BEGIN  
         -- Update CCDetail --  
         EXEC [RDT].[rdt_TM_CycleCount_SKU_ConfirmTask]  
             @nMobile           = @nMobile  
            ,@nFunc             = @nFunc  
            ,@cFacility         = @cFacility  
            ,@cCCKey            = @cCCKey  
            ,@cStorerKey        = @cStorerKey  
            ,@cSKU              = @cSKU  
            ,@cLOC              = @cLOC  
            ,@cID               = @cID  
            ,@nQty              = @nSerialQTY  
            ,@nPackValue        = ''  
            ,@cUserName         = @cUserName  
            ,@cLottable01       = @cLottable01  
            ,@cLottable02       = @cLottable02  
            ,@cLottable03       = @cLottable03  
            ,@dLottable04       = @dLottable04  
            ,@dLottable05       = @dLottable05  
            ,@cLottable06       = @cLottable06  
            ,@cLottable07       = @cLottable07  
            ,@cLottable08       = @cLottable08  
            ,@cLottable09       = @cLottable09  
            ,@cLottable10       = @cLottable10  
            ,@cLottable11       = @cLottable11  
            ,@cLottable12       = @cLottable12  
            ,@dLottable13       = @dLottable13  
            ,@dLottable14       = @dLottable14  
            ,@dLottable15       = @dLottable15  
            ,@cUCC              = ''  
            ,@cTaskDetailKey    = @cTaskDetailKey  
            ,@cPickMethod       = @cPickMethod  
            ,@cLangCode         = @cLangCode  
            ,@nErrNo            = @nErrNo      OUTPUT  
            ,@cErrMsg           = @cErrMsg     OUTPUT -- screen limitation, 20 char max  
      END  
  
      IF @nErrNo <> 0  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
         GOTO Step_8_Fail  
      END  

      EXEC [RDT].[rdt_TM_CycleCount_SerialNo] 
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cCCKey        = @cCCKey,
         @cCCDetailKey  = @cCCDetailKey,
         @cCCSheetNo    = @cTaskDetailKey,
         @cLot          = @cLot,
         @cLoc          = @cLoc,
         @cID           = @cID,
         @cSKU          = @cSKU,
         @cSerialNo     = @cSerialNo,
         @nSerialQTY    = @nSerialQTY,
         @nErrNo        = @nErrNo   OUTPUT,
         @cErrMsg       = @cErrMsg  OUTPUT

      IF @nErrNo <> 0  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
         GOTO Step_8_Fail  
      END  
      
      IF @nMoreSNO = 1
         GOTO Quit

      IF @nDefaultQty = 0  
      BEGIN  
         SET @nQtyAval = 0  
         SET @nQty = 0  
         SET @nRowCount = 0  
         SET @nLottableCount = @nLottableCount + 1  
  
         --- Get Next Lottable  
         SET @cLottable01 = ''  
         SET @cLottable02 = ''  
         SET @cLottable03 = ''  
         SET @dLottable04 = NULL  
         SET @dLottable05 = NULL  
  
  
         IF @cCCGroupExLottable05 = '1'  
         BEGIN  
            SELECT TOP 1  
                     @cLottable01 = CC.Lottable01  
                   , @cLottable02 = CC.Lottable02  
                   , @cLottable03 = CC.Lottable03  
                   --V3.8 , @dLottable04 = rdt.rdtFormatDate( CC.Lottable04) 
                   , @dLottable04 = CC.Lottable04 -- V3.8 Fix data type convertion issue
                   , @nQtyAval    =  SUM(CC.SystemQty)  
                   , @cCCDetailKey = MIN(CC.CCDetailKey)  
                   , @nQty        = SUM(CC.Qty)  
            FROM dbo.CCDetail CC WITH (NOLOCK)  
            WHERE CC.SKU = @cSKU  
            AND CC.CCKey = @cCCKey  
            AND CC.Loc   = @cLoc  
            AND CC.ID    = @cID  
            AND Status < '9'  
            AND CC.CCSheetNo = @cTaskDetailKey  
            GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04  
            HAVING MIN(CC.CCDetailKey) > @cCCDetailKey  
  
        END  
        ELSE  
        BEGIN  
           SELECT TOP 1  
                     @cLottable01 = CC.Lottable01  
                   , @cLottable02 = CC.Lottable02  
                   , @cLottable03 = CC.Lottable03  
                   --V3.8 , @dLottable04 = rdt.rdtFormatDate( CC.Lottable04)  
                   --, @dLottable05 = rdt.rdtFormatDate( CC.Lottable05)
                   , @dLottable04 =  CC.Lottable04 
                   , @dLottable05 =  CC.Lottable05 -- V3.8 Fix data type convertion issue 
                   , @nQtyAval    =  CC.SystemQty  
                   , @cCCDetailKey = CC.CCDetailKey  
                   , @nQty        = CC.Qty  
            FROM dbo.CCDetail CC WITH (NOLOCK)  
            WHERE CC.SKU = @cSKU  
            AND CC.CCKey = @cCCKey  
            AND CC.Loc   = @cLoc  
            AND CC.ID    = @cID  
            --AND Status < '9' if 9 will have record keep looping for newly added record  
            AND Status = '0'  
            AND CC.CCSheetNo = @cTaskDetailKey  
            AND CC.CCDetailKey > @cCCDetailKey  
            ORDER BY CCDetailKey  
         END  

         --SET @nRowCount = @@ROWCOUNT  
         SET @nRowCount = 0

         IF @cSkipLottable = '1'    
         BEGIN    
            --SET @nRowCount = 1    
       
            SET @cLottable01 = ''    
            SET @cLottable02 = ''    
            SET @cLottable03 = ''    
            SET @dLottable04 = 0    
         END    
  
         IF @nRowCount = 0 OR @cNewSKUorLottable = '1'  
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
  
            SET @cCCDetailKey = ''  
            SET @cNewSKUorLottable = ''  
  
            SET @nPrevStep = 0  
            SET @nPrevScreen  = 0  
  
            SET @nPrevStep = @nStep  
            SET @nPrevScreen = @nScn  
  
            SET @cOutField01 = ''  
  
            -- GOTO Next Screen  
            SET @nScn = @nFromScn + 1
            SET @nStep = @nStep - 5
  
            GOTO QUIT  
         END  
         ELSE IF @nRowCount > 0  
         BEGIN  
  
            SET @cCounted = ''  
            IF @cSkipLottable = '1'    
               SET @cOutField13 = '1/1'    
            ELSE    
               SET @cOutField13 = CASE WHEN @cSkipLottable = '1' THEN ''   
                                       ELSE RTRIM(CAST(@nLottableCount AS NVARCHAR(4))) +  '/' +   
                                            RTRIM(CAST(@nLottableCountTotal AS NVARCHAR(4)))   
                                       END  
  
            SELECT  
                    -- @cStorerKey = CC.StorerKey  
                     @cSKUDescr = SKU.DESCR  
                   , @cMUOM_Desc  = Pack.PackUOM3  
                   , @cPUOM_Desc  =  
                      CASE @cPUOM  
                         WHEN '2' THEN Pack.PackUOM1 -- Case  
                         WHEN '3' THEN Pack.PackUOM2 -- Inner pack  
                         WHEN '6' THEN Pack.PackUOM3 -- Master unit  
                         WHEN '1' THEN Pack.PackUOM4 -- Pallet  
                         WHEN '4' THEN Pack.PackUOM8 -- Other unit 1  
                         WHEN '5' THEN Pack.PackUOM9 -- Other unit 2  
                      END  
                   ,  @nPUOM_Div  = CAST( IsNULL(  
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
            WHERE SKU.SKU = @cSKU  
              AND SKU.StorerKey = @cStorerKey  
  
            IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)  
                        WHERE CCKey = @cCCKey  
                        AND SKU = @cSKU  
                        AND Loc = @cLoc  
                        AND ID  = @cID  
                        AND Status < '9'  
                        AND Qty > 0  
                        AND CCSheetNo = @cTaskDetailKey  
                        AND CCdetailKey = @cCCDetailKey)  
            BEGIN  
               SET @nQtyAval = @nQty  
               SET @cCounted = '1'  
            END  
  
            -- Convert to prefer UOM QTY  
            IF @cPUOM = '6' OR -- When preferred UOM = master unit  
               @nPUOM_Div = 0  -- UOM not setup  
            BEGIN  
               SET @cPUOM_Desc = ''  
               SET @nPQTY = 0  
               SET @nMQTY = @nQtyAval  
            END  
            ELSE  
            BEGIN  
                  SET @nPQTY = @nQtyAval / @nPUOM_Div  -- Calc QTY in preferred UOM  
                  SET @nMQTY = @nQtyAval % @nPUOM_Div  -- Calc the remaining in master unit  
            END  
  
            IF @cPUOM_Desc = ''  
            BEGIN  
               SET @cOutField04 = ''  
               SET @cOutField06 = ''  
               SET @cFieldAttr06 = 'O'  
            END  
            ELSE  
            BEGIN  
               SET @cOutField04 = @cPUOM_Desc  
               IF @cCounted = '1'  
               BEGIN  
                  SET @cOutField06 = CAST( @nPQTY AS NVARCHAR( 5))  
               END  
               ELSE  
               BEGIN  
                  SET @cOutField06 = ''  
               END  
            END  
  
            IF @nPQTY <= 0  
            BEGIN  
               SET @cOutField04 = ''  
               SET @cOutField06 = ''  
               SET @cOutField06 = ''  
               SET @cFieldAttr06 = 'O'  
            END  
  
  
            SET @cOutField05 = @cMUOM_Desc  
  
            IF @cCounted = '1'  
            BEGIN  
               SET @cOutField07 = CAST( @nMQTY AS NVARCHAR( 5))  
            END  
            ELSE  
            BEGIN  
               SET @cOutField07 = ''  
            END  
  
            SET @cFieldAttr07 = ''  
  
            IF @nPQTY > 0  
               EXEC rdt.rdtSetFocusField @nMobile, 06  
            ELSE  
               EXEC rdt.rdtSetFocusField @nMobile, 07  
  
            SET @cNewSKUorLottable = ''  
  
            SET @cFieldAttr08 = 'O'  
            SET @cFieldAttr09 = 'O'  
            SET @cFieldAttr10 = 'O'  
            SET @cFieldAttr11 = 'O'  
  
            SET @cOutField08 = @cLottable01  
            SET @cOutField09 = @cLottable02  
            SET @cOutField10 = @cLottable03  
            SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)  
         END  
      END  
      ELSE  
      BEGIN  
         SELECT  
                  -- @cStorerKey = CC.StorerKey  
                  @cSKUDescr = SKU.DESCR  
                  , @cMUOM_Desc  = Pack.PackUOM3  
                  , @cPUOM_Desc  =  
                     CASE @cPUOM  
                        WHEN '2' THEN Pack.PackUOM1 -- Case  
                        WHEN '3' THEN Pack.PackUOM2 -- Inner pack  
                        WHEN '6' THEN Pack.PackUOM3 -- Master unit  
                        WHEN '1' THEN Pack.PackUOM4 -- Pallet  
                        WHEN '4' THEN Pack.PackUOM8 -- Other unit 1  
                        WHEN '5' THEN Pack.PackUOM9 -- Other unit 2  
                     END  
                  ,  @nPUOM_Div  = CAST( IsNULL(  
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
         WHERE SKU.SKU = @cSKU  
            AND SKU.StorerKey = @cStorerKey  
  
         SET @cFieldAttr08 = 'O'  
         SET @cFieldAttr09 = 'O'  
         SET @cFieldAttr10 = 'O'  
         SET @cFieldAttr11 = 'O'  
  
         SET @cFieldAttr06 = ''  
         SET @cFieldAttr07 = ''  
         SET @cFieldAttr12 = ''  
  
         --SET @nDefaultQty = 0  
  
         -- if default qty turned on then overwrite the actual MQty (james02)  
         --SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)  
         IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1  
            SET @nDefaultQty = CAST( @cDefaultQty AS INT)  
         ELSE  
            SET @nDefaultQty = 0  
  
         IF @nDefaultQty > 0  
         BEGIN  
            SET @cFieldAttr12 = ''  
            SET @cOutField12 = ''  
            SET @cFieldAttr06 = 'O'  
            SET @cFieldAttr07 = 'O'  
  
            -- Convert to prefer UOM QTY  
            IF @cPUOM = '6' OR -- When preferred UOM = master unit  
               @nPUOM_Div = 0  -- UOM not setup  
               SET @cOutField07 = @nDefaultQty  
            ELSE  
            BEGIN  
               IF @nDefaultQty > @nPUOM_Div  
               BEGIN  
                  SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM  
                  SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit  
               END  
               ELSE  
                  SET @cOutField07 = @nDefaultQty  
            END  
         END  
         ELSE  
         BEGIN  
            SET @cFieldAttr12 = 'O'  
            SET @cOutField12 = ''  
         END  

         SET @cOutField01 = @cSKU  
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)  
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)  
         SET @cOutfield12 = ''  
      END  

      -- Go to SKU QTY screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 6
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cSKUDescr = ''
      SET @cMUOM_Desc = ''
      SET @cPUOM_Desc = ''

      SET @nQtyAval = 0
      SET @nQty = 0
      SET @nPUOM_Div = 0
      SET @nMQTY = 0
      SET @nPQTY = 0

      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = NULL
      SET @dLottable05 = NULL

      SELECT
           @cSKUDescr = SKU.DESCR
         , @cMUOM_Desc  = Pack.PackUOM3
         , @cPUOM_Desc  =
         CASE @cPUOM
            WHEN '2' THEN Pack.PackUOM1 -- Case
            WHEN '3' THEN Pack.PackUOM2 -- Inner pack
            WHEN '6' THEN Pack.PackUOM3 -- Master unit
            WHEN '1' THEN Pack.PackUOM4 -- Pallet
            WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
            WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
         END
         ,  @nPUOM_Div  = CAST( IsNULL(
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
      WHERE SKU.SKU = @cSKU
        AND SKU.StorerKey = @cStorerKey

      IF @cCCGroupExLottable05 = '1'
      BEGIN
         SELECT TOP 1
                  @cLottable01 = CC.Lottable01
                , @cLottable02 = CC.Lottable02
                , @cLottable03 = CC.Lottable03
                , @dLottable04 = CC.Lottable04  --yeekung01
                , @nQtyAval    =  SUM(CC.SystemQty)
                , @cCCDetailKey = MIN(CC.CCDetailKey)
                , @nQty        = SUM(CC.Qty)
         FROM dbo.CCDetail CC WITH (NOLOCK)
         WHERE CC.SKU = @cSKU
         AND CC.CCKey = @cCCKey
         AND CC.Loc   = @cLoc
         AND CC.ID    = @cID
         AND Status < '9'
         AND CC.CCSheetNo = @cTaskDetailKey
         GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04
         ORDER BY MIN(CC.CCDetailKey)

         SET @nLottableCountTotal = 0
         SELECT @nLottableCountTotal =  COUNT(1)
         FROM dbo.CCDetail CC WITH (NOLOCK)
         WHERE CC.SKU = @cSKU
         AND CC.CCKey = @cCCKey
         AND CC.Loc   = @cLoc
         AND CC.ID    = @cID
         AND Status < '9'
         AND CC.CCSheetNo = @cTaskDetailKey
         GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04
      END
      ELSE
      BEGIN
         SELECT TOP 1
                  @cLottable01 = CC.Lottable01
                , @cLottable02 = CC.Lottable02
                , @cLottable03 = CC.Lottable03
                , @dLottable04 = CC.Lottable04  --yeekung01
                , @dLottable05 = CC.Lottable05  --yeekung01
                , @nQtyAval    =  CC.SystemQty
                , @cCCDetailKey = CC.CCDetailKey
                , @nQty        = CC.Qty
         FROM dbo.CCDetail CC WITH (NOLOCK)
         WHERE CC.SKU = @cSKU
         AND CC.CCKey = @cCCKey
         AND CC.Loc   = @cLoc
         AND CC.ID    = @cID
         AND Status < '9'
         AND CC.CCSheetNo = @cTaskDetailKey
         ORDER BY CCDetailKey

         SET @nLottableCountTotal = 0
         SELECT @nLottableCountTotal = COUNT(1)
         FROM dbo.CCDetail CC WITH (NOLOCK)
         WHERE CC.SKU = @cSKU
         AND CC.CCKey = @cCCKey
         AND CC.Loc   = @cLoc
         AND CC.ID    = @cID
         AND Status < '9'
       AND CC.CCSheetNo = @cTaskDetailKey
      END

      SET @cCounted = ''

      IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCKey = @cCCKey
                  AND SKU = @cSKU
                  AND Loc = @cLoc
                  AND ID  = @cID
                  AND Status < '9'
                  AND Qty > 0
                  AND CCSheetNo = @cTaskDetailKey
                  AND CCdetailKey = @cCCDetailKey)
      BEGIN
         SET @nQtyAval = @nQty
         SET @cCounted = '1'
      END

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nQtyAval
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQtyAval / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMQTY = @nQtyAval % @nPUOM_Div  -- Calc the remaining in master unit
      END

      -- Prepare Next Screen Variable  
      SET @cSKUDescr1 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1  
      SET @cSKUDescr2 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 1  
  
      SET @cOutField01 = @cSKU  
      SET @cOutField02 = @cSKUDescr1  
      SET @cOutField03 = @cSKUDescr2  
  
      SET @nLottableCount = 0  
      SET @cOutField13 = CASE WHEN @cSkipLottable = '1' THEN ''   
                              ELSE RTRIM(CAST(@nLottableCount AS NVARCHAR(4))) +  '/' +   
                                   RTRIM(CAST(@nLottableCountTotal AS NVARCHAR(4)))   
                              END  
  
      IF @cPUOM_Desc = ''  
      BEGIN  
         SET @cOutField04 = ''  
         SET @cOutField06 = ''  
         SET @cFieldAttr06 = 'O'  
      END  
      ELSE  
      BEGIN  
         SET @cOutField04 = @cPUOM_Desc
         IF @cCounted = '1'  
         BEGIN  
            SET @cOutField06 = CAST( @nPQTY AS NVARCHAR( 5))  
         END  
         ELSE  
         BEGIN  
            SET @cOutField06 = ''  
         END  
      END  
  
      IF @nPQTY <= 0  
      BEGIN  
         SET @cOutField06 = ''  
         SET @cFieldAttr06 = 'O'  
      END  
  
      SET @cOutField05 = @cMUOM_Desc  
  
      IF @cCounted = '1'  
      BEGIN  
         SET @cOutField07 = CAST( @nMQTY AS NVARCHAR( 5))  
      END  
      ELSE  
      BEGIN  
         SET @cOutField07 = ''  
      END  
  
      SET @cFieldAttr07 = ''  
  
      IF @nPQTY > 0  
         EXEC rdt.rdtSetFocusField @nMobile, 06  
      ELSE  
         EXEC rdt.rdtSetFocusField @nMobile, 07  
  
      SET @cFieldAttr08 = 'O'  
      SET @cFieldAttr09 = 'O'  
      SET @cFieldAttr10 = 'O'  
      SET @cFieldAttr11 = 'O'  
  
      IF @cSkipLottable = '1'    
      BEGIN    
         SET @cOutField08 = ''    
         SET @cOutField09 = ''    
         SET @cOutField10 = ''    
         SET @cOutField11 = ''    
      END    
      ELSE          
      BEGIN    
         SET @cOutField08 = @cLottable01    
         SET @cOutField09 = @cLottable02    
         SET @cOutField10 = @cLottable03    
         SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)    
      END    
  
      SET @cFieldAttr07 = ''  
      SET @cFieldAttr12 = ''  
  
      --SET @nDefaultQty = 0  
  
      -- if default qty turned on then overwrite the actual MQty (james02)  
  --SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)  
      IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1  
         SET @nDefaultQty = CAST( @cDefaultQty AS INT)  
      ELSE  
         SET @nDefaultQty = 0  
  
      IF @nDefaultQty > 0  
      BEGIN  
         SET @cFieldAttr12 = ''  
         SET @cOutField12 = ''  
         SET @cFieldAttr06 = 'O'  
         SET @cFieldAttr07 = 'O'  
  
         -- Convert to prefer UOM QTY  
         IF @cPUOM = '6' OR -- When preferred UOM = master unit  
            @nPUOM_Div = 0  -- UOM not setup  
            SET @cOutField07 = @nDefaultQty  
         ELSE  
         BEGIN  
            IF @nDefaultQty > @nPUOM_Div  
            BEGIN  
               SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM  
               SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit  
            END  
            ELSE  
               SET @cOutField07 = @nDefaultQty  
         END  
      END  
      ELSE  
      BEGIN  

         SET @cFieldAttr12 = 'O'  
         SET @cOutField12 = ''  
      END  
      
      -- Go to SKU QTY screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 6      
   END
   GOTO Quit

   STEP_8_FAIL:  
   BEGIN  
      SET @cOutField01 = ''  
   END     
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:

BEGIN
 UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      Printer   = @cPrinter,
      InputKey  = @nInputKey,

      V_TaskDetailKey  = @cTaskDetailKey,
      V_Loc            = @cSuggFromLoc,
      V_ID             = @cID,
      V_SKU            = @cSKU,

      V_Lottable01     = @cLottable01,
      V_Lottable02     = @cLottable02,
      V_Lottable03     = @cLottable03,
      V_Lottable04     = @dLottable04,
      V_Lottable05     = @dLottable05,
      V_Lottable06     = @cLottable06,
      V_Lottable07     = @cLottable07,
      V_Lottable08     = @cLottable08,
      V_Lottable09     = @cLottable09,
      V_Lottable10     = @cLottable10,
      V_Lottable11     = @cLottable11,
      V_Lottable12     = @cLottable12,
      V_Lottable13     = @dLottable13,
      V_Lottable14     = @dLottable14,
      V_Lottable15     = @dLottable15,

      V_LottableLabel01 = @cLotLabel01,
      V_LottableLabel02 = @cLotLabel02,
      V_LottableLabel03 = @cLotLabel03,
      V_LottableLabel04 = @cLotLabel04,
      V_LottableLabel05 = @cLotLabel05,

      V_Barcode    = @cBarcode,
  
      V_FromStep  = @nFromStep,  
      V_FromScn   = @nFromScn,  
      V_Qty       = @nActQTY,
      V_Integer1  = @nUCCQty,
      V_Integer2  = @nDefaultQty,
      V_Integer3  = @nLottableCount,
      V_Integer4  = @nRowID,
      V_Integer5  = @nLottableCountTotal,
      V_Integer6  = @nMaxQtyValue,
      V_Integer7  = @nReCountLoc,
      V_Integer8  = @nPrevScreen,
      V_Integer9  = @nPrevStep,

      V_String1        = @cCCKey,
      V_String2        = @cSuggID,
      V_String3        = @cCommodity,
      V_String4        = @cUCC,
      V_String5        = @cDefaultOption,
      V_String6        = @cTMCCSKUSkipScreen1,
      V_String7        = @cMultiSKUBarcode,
      V_String8        = @cDefaultQty,
      V_String9        = @cSkipLottable,
      V_String10       = @cLoc,
      V_String11       = @cCheckSKUExistsInLoc,
      V_String12       = @cSkipAlertScreen,
      V_String13       = @cSuggSKU,
      V_String14       = @cPickMethod,
      V_String15       = @cSKUDescr1,
      V_String16       = @cSKUDescr2,
      V_String17       = @cCCDetailKey,
      V_String18       = @cExtendedInfoSP,
      V_String19       = @cDecodeSP,
      V_String20       = @cCCOption,
      V_String21       = @cNewSKUorLottable,
      V_String22       = @cHasLottable,
      V_String23       = @cCCGroupExLottable05,
      V_String24       = @cExtendedInfo,
      V_String26       = @cExtCfmSP,
      V_String27       = @cExtendedUpdateSP,
      V_String28       = @cTMCCVarianceCountSP,
      V_String29       = @cExtendedDisplayQtySP,
      V_String30       = @cDiffQTYScanSNO, 

      V_String32       = @cAreakey,  
      V_String33       = @cTTMStrategykey,  
      V_String34       = @cTTMTasktype,  
      V_String35       = @cRefKey01,  
      V_String36       = @cRefKey02,  
      V_String37       = @cRefKey03,  
      V_String38       = @cRefKey04,  
      V_String39       = @cRefKey05,  
      V_String40       = @cTMCCAllowPostAdj,
      V_String41       = @cSerialNoCapture,
      V_String42       = @cLottableCode,  

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,

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