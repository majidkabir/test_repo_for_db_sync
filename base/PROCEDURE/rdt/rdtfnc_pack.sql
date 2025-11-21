SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************************/
/* Store procedure: rdtfnc_Pack                                                                 */
/* Copyright      : LFLogistics                                                                 */
/*                                                                                              */
/* Date         Rev  Author     Purposes                                                        */
/* 2016-05-05   1.0  Ung        SOS368666 Created                                               */
/* 2016-09-30   1.1  Ung        Performance tuning                                              */
/* 2016-10-05   1.2  Ung        SQL2014                                                         */
/* 2016-10-31   1.3  Ung        WMS-458 Add pack UCC                                            */
/* 2017-05-19   1.4  Ung        WMS-1919 Add serial no, FromDropID,                             */
/*                              new printing method                                             */
/* 2017-06-06   1.5  Ung        WMS-2126 PackDetail.RefNo,RefNo2,UPC,DropID                     */
/* 2017-08-16   1.6  Ung        WMS-1919 Show pack confirm error                                */
/* 2017-09-05   1.7  Ung        WMS-2795 Add ExtendedInfo                                       */
/* 2017-09-05   1.8  Ung        IN00456144 Fix decode UserDefine not reset                      */
/* 2018-04-12   1.9  James      WMS4231 - Add ExtendedInfoSP at screen 3 after                  */
/*                              validate SKU (james01)                                          */
/*                              Fix wgt & cube wrong position issue (james02)                   */
/* 2018-04-27   2.0  WinSern    INC0210466 Swap position for weight and cube                    */
/* 2018-04-02   2.1  Ung        WMS-3845                                                        */
/*                              Change ExtendedInfoSP for SKU QTY to SKU only                   */
/*                              Add ExtendedValidateSP at screen 1                              */
/*                              Add CustomCartonNo                                              */
/*                              Add PrePackIndicator                                            */
/* 2018-09-18   2.2 James       WMS-6320 Change SerialNoCapture config                          */
/*                              Allow svalue 3 only (james02)                                   */
/* 2018-09-28   2.3 Gan         Performance                                                     */
/* 2018-10-17   2.4 James       WMS-6654 Add ExtendedUpdateSP@ step7 (james03)                  */
/* 2019-03-13   2.5 Ung         WMS-8134 Add bulk serial no                                     */
/*                              Add data capture                                                */
/* 2019-05-14   2.6 Ung         WMS-9050 Add multi SKU barcode                                  */
/*                              Add DefaultWeight                                               */
/* 2019-08-01   2.7 James       WMS-10030 - Fix DecodeSP output wrong                           */
/*                              variable (james04)                                              */
/*                              Add ext validate/update sp @ step 4                             */
/* 2019-09-03   2.8 LZG         INC0841202 - Allow multiple disabled                            */
/*                              options (ZG01)                                                  */
/* 2019-09-25   2.9 James       WMS-10434 Add param to rdt_serialno(james15)                    */
/* 2019-09-30   3.0 Ung         WMS-10729 Add DefaultPrintLabelOption                           */
/*                              Add ExtendedUpdateSP at print label screen                      */
/*                              Migrate DataCapture to DataCaptureSP                            */
/* 2019-10-01   3.1 James       WMS-10570 Display qty based on UOM (james16)                    */
/* 2019-11-04   3.2 James       WMS-10890 Add ExtInfo @ screen 1 (james17)                      */
/*                              Add show pickslipno if config turn on                           */
/* 2020-01-15   3.3 James       WMS-11706 Fix decode qty (james18)                              */
/* 2019-10-03   3.4 Ung         WMS-10717 Add DefaultPrintPackListOption                        */
/* 2020-02-18   3.5 James       WMS-12052 Add DisableQTYFieldSP (james19)                       */
/* 2020-08-04   3.6 Chermaine   WMS-14497 Set DefaultQty @scn3 (cc01)                           */
/* 2020-07-29   3.7 Chermaine   WMS-14153 Add packinfo.qty at scn4 (cc02)                       */
/* 2020-12-08   3.8 Chermaine   WMS-15727 Add DisableQTYFieldSP at scn3 (cc03)                  */
/* 2021-01-06   3.9 James       WMS-15989 Add Length, Weight, Height (james20)                  */
/* 2021-03-09   4.0 Chermaine   WMS-12426 Add rdtIsValidFormat in scn4 (cc04)                   */
/* 2021-03-24   4.1 James       WMS-16439 Enhance DefaultOption (james21)                       */
/* 2021-05-09   4.2 YeeKung     WMS-16963 Default cartontype(yeekung01)                         */
/* 2021-06-09   4.3 LZG         INC1527070 - Extended variable length (ZG02)                    */
/* 2021-06-22   4.4 LZG         JSM-5211 - Corrected @cFieldAttr (ZG03)                         */
/* 2021-08-30   4.5 YeeKung     WMS-17656 add flow thourgh screen (yeekung02)                   */
/* 2021-10-21   4.6 James       WMS-18152 Add ExtendedValidateSP to                             */
/*                              print packing list step (james22)                               */
/* 2021-12-15   4.7 SYCHUA      JSM-39973 - Bug Fix: Swap position correctly                    */
/*                              for cube and weight (SY01)                                      */
/* 2021-12-13   4.8 Chermaine   WMS-18503 Able to go serialNo scn                               */
/*                              after capturePackInfo scn (cc05)                                */
/* 2021-11-13   4.9 YeeKung     WMS-18323 Add data capture label (yeekung03)                    */
/* 2022-02-18   5.0 Ung         WMS-18900 Support 1 carton 1 PackDetail                         */
/* 2023-03-09   5.1 Ung         WMS-21938 Add FlowThruScreen for print label (SValue=5)         */
/*                              Rename FlowThruScr    (SValue=1) to FlowThruScreen (SValue=2)   */
/*                              Rename FlowThruCtnScn (SValue=1) to FlowThruScreen (SValue=4)   */
/* 2023-03-20   5.2 Ung         WMS-21946 Add FlowThruScreen for serial no (SValue=9)           */
/*                              Decode serial no                                                */
/* 2023-03-23   5.3 Ung         WMS-22076 Expand Option field to detact scan barcode            */
/*                              Add ExtendedValidateSP at screen 2 (statistic)                  */
/* 2023-06-14   5.4 YeeKung     WMS-22751 Add Popup Message (yeekung01)                         */
/* 2023-06-28   5.5 Ung         WMS-22741 Remove rdt_Decode error                               */
/* 2023-07-04   5.6 Ung         WMS-22913 Add ExtendedUpdateSP at step 2 ESC                    */
/* 2023-11-24   5.7 Ung         WMS-24060 Add PackByFromDropID                                  */
/* 2023-08-25   5.8 YeeKung     WMS-23946 Clear Extendedinfo SP  (yeekung02)                    */
/* 2024-05-27   5.9 NLT013      FCR-388 Merge code to V2 branch, original owner is Wojciech     */
/* 2024-06-14   6.0 JHU151      FCR-352 ZA_DEFY - Fn838 -Default Pick Quantity                  */
/* 2024-06-24   6.1 JHU151      Fixed Rest @cEnter Flag issue                                   */
/* 2024-07-08   6.2 Jackc       FCR-392 Add ext scn entry and codes                             */
/* 2024-07-08   6.3 JHU151      FCR-330 SSCC code generator                                     */
/* 2024-08-22   6.4 JCH507      FCR-392 Add errno handling to step3>ESC>ExtUpd                  */
/* 2024-10-25   6.5 PXL009     FCR-759 ID and UCC Length Issue                                 */
/* 2024-10-24   6.6 TLE109      FCR-990. Packing Serial Number Validation                       */
/* 2024-11-08   6.7 CYU027      UWP-26811 UCC Multi Storerkey                                   */
/* 2024-10-12   6.8 YYS027      FCR-861 Add support CstLabelSP for Pack List Printing(Step 6)   */ 
/*                              similiar with ship-label printing(Step 5)                       */
/* 2024-11-30   6.9 Dennis      FCR-778 Add Extended Update SP to Step 2                        */
/* 2023-08-25   7.0 Moo         JSM-171339 Add defaultqty config (moo01)                        */
/* 2023-08-25   7.1 YeeKung     WMS-23946 Clear Extendedinfo SP  (yeekung02)                    */
/* 2023-12-26   7.2 Ung         WMS-24292 Add SkipChkPPKQTY                                     */
/* 2024-01-08   7.3 Ung         WMS-24527 Add Carton Type barcode                               */
/* 2024-03-15   7.4 Ung         WMS-24885 Add DefaultCursor                                     */
/* 2025-01-24   7.5 JCH507      FCR-2435 Merge V7.0 to 7.4 from v0 to v2                        */
/************************************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Pack] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @bSuccess       INT,
   @nRowCount      INT, --v7.5
   @cOption        NVARCHAR( 2),
   @cCurrLOC       NVARCHAR( 10),
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX),
   @cUCCNo         NVARCHAR( 20),
   @cType          NVARCHAR( 10),
   @cPrintPackList NVARCHAR( 1),
   @cCustomID      NVARCHAR( 20),
   @nTotalUCC      INT,
   @cSerialNo      NVARCHAR( 30) = '',
   @cIsValSerialNo NVARCHAR( 1) = '0',  --TLE109
   @nSerialQTY     INT,
   @nMoreSNO       INT,
   @nBulkSNO       INT,
   @nBulkSNOQTY    INT,
   @tVar                VariableTable, 
   @tVarDisableQTYField VARIABLETABLE,
   @cBarcode               NVARCHAR( 60),
   @cBarcode2              NVARCHAR( 60),
   @cFromDropIDDecode      NVARCHAR( 20),
   @cToDropIDDecode        NVARCHAR( 20),
   @cUPC                   NVARCHAR( 30),
   @cQTY                   NVARCHAR( 5),
   @nDecodeQTY             INT,
   @cPackDtlDropID_Decode  NVARCHAR(20),
   @cSKUDataCapture        NVARCHAR(1),
   @cDataCapture           NVARCHAR(1)

DECLARE @cCstLabelSP NVARCHAR(30)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,
   @cFlowThruScreen  NVARCHAR( 1), 

   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cUserName        NVARCHAR( 18),
   @cPaperPrinter    NVARCHAR( 10),
   @cLabelPrinter    NVARCHAR( 10),

   @cPickSlipNo      NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cSKUDescr        NVARCHAR( 60),
   @nFromScn         INT,
   @nFromStep        INT,

   @cPackDtlRefNo    NVARCHAR( 20),
   @cPackDtlRefNo2   NVARCHAR( 20),
   @cLabelNo         NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cLabelLine       NVARCHAR( 5),
   @cPackDtlDropID   NVARCHAR( 20),
   @cUCCCounter      NVARCHAR( 5),
                     
   @nCartonNo        INT,
   @nCartonSKU       INT,
   @nCartonQTY       INT,
   @nTotalCarton     INT,
   @nTotalPick       INT,
   @nTotalPack       INT,
   @nTotalShort      INT,
   @nPackedQTY       INT,
   @nAction          INT, --(JHU151)   
   @nEnter           INT, --(cc01)  
   

   @cDefaultPrintLabelOption     NVARCHAR( 1),
   @cDefaultPrintPackListOption  NVARCHAR( 1),
   @cDefaultWeight      NVARCHAR( 1),
   @cFromDropID         NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20),
   @cDisableQTYField    NVARCHAR( 1),
   @cCapturePackInfoSP  NVARCHAR( 20),
   @cPackInfo           NVARCHAR( 10),
   @cAllowWeightZero    NVARCHAR( 1),
   @cAllowCubeZero      NVARCHAR( 1),
   @cAutoScanIn         NVARCHAR( 1),
   @cDefaultOption      NVARCHAR( 1),
   @cDisableOption      NVARCHAR( 10),    -- ZG01
   @cSerialNoCapture    NVARCHAR( 1),
   @cPackList           NVARCHAR( 10),
   @cShipLabel          NVARCHAR( 10),
   @cCartonManifest     NVARCHAR( 10),
   @cCustomCartonNo     NVARCHAR( 1),
   @cCustomNo           NVARCHAR( 5),
   @cDataCaptureSP      NVARCHAR( 20),
   @cPackDtlUPC         NVARCHAR( 30),
   @cPrePackIndicator   NVARCHAR( 30),
   @cPackQtyIndicator   NVARCHAR( 3),
   @cPackData1          NVARCHAR( 30),
   @cPackData2          NVARCHAR( 30),
   @cPackData3          NVARCHAR( 30),
   @cPackLabel1         NVARCHAR( 20),
   @cPackLabel2         NVARCHAR( 20),
   @cPackLabel3         NVARCHAR( 20),
   @cPackAttr1          NVARCHAR( 1),
   @cPackAttr2          NVARCHAR( 1),
   @cPackAttr3          NVARCHAR( 1),
   @cMultiSKUBarcode    NVARCHAR( 1),
   @cPQTY               NVARCHAR( 5),
   @cMQTY               NVARCHAR( 5),
   @cPUOM               NVARCHAR( 1),
   @cPUOM_Desc          NCHAR( 5),
   @cMUOM_Desc          NCHAR( 5),
   @nPUOM_Div           INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @cShowPickSlipNo     NVARCHAR( 1),
   @cDisableQTYFieldSP  NVARCHAR(20),
   @cDefaultQTY         NVARCHAR( 1), --(cc01)
   @cLength             NVARCHAR( 10), -- (james20)
   @cWidth              NVARCHAR( 10), -- (james20)
   @cHeight             NVARCHAR( 10), -- (james20)
   @cAllowLengthZero    NVARCHAR( 1),  -- (james20)
   @cAllowWidthZero     NVARCHAR( 1),  -- (james20)
   @cAllowHeightZero    NVARCHAR( 1),  -- (james20)
   @cDefaultcartontype  NVARCHAR( 20),  --(yeekung01)
   @cExtendedScreenSP   NVARCHAR( 20), --(JHU151)
   @cJumpType           NVARCHAR( 10), --(JHU151) Forward/Back
   @tExtScnData			VariableTable, --(JHU151)
   @cPackByFromDropID   NVARCHAR( 1),
   @cDefaultCursor      NVARCHAR( 2), --(v7.5)

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),   @cFieldAttr01 NVARCHAR( 1), @cLottable01  NVARCHAR( 18),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),   @cFieldAttr02 NVARCHAR( 1), @cLottable02  NVARCHAR( 18),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),   @cFieldAttr03 NVARCHAR( 1), @cLottable03  NVARCHAR( 18),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),   @cFieldAttr04 NVARCHAR( 1), @dLottable04  DATETIME,
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),   @cFieldAttr05 NVARCHAR( 1), @dLottable05  DATETIME,
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),   @cFieldAttr06 NVARCHAR( 1), @cLottable06  NVARCHAR( 30),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),   @cFieldAttr07 NVARCHAR( 1), @cLottable07  NVARCHAR( 30),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),   @cFieldAttr08 NVARCHAR( 1), @cLottable08  NVARCHAR( 30),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),   @cFieldAttr09 NVARCHAR( 1), @cLottable09  NVARCHAR( 30),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),   @cFieldAttr10 NVARCHAR( 1), @cLottable10  NVARCHAR( 30),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),   @cFieldAttr11 NVARCHAR( 1), @cLottable11  NVARCHAR( 30),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),   @cFieldAttr12 NVARCHAR( 1), @cLottable12  NVARCHAR( 30),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),   @cFieldAttr13 NVARCHAR( 1), @dLottable13  DATETIME,
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),   @cFieldAttr14 NVARCHAR( 1), @dLottable14  DATETIME,
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),   @cFieldAttr15 NVARCHAR( 1), @dLottable15  DATETIME,

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

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cUserName        = UserName,
   @cPaperPrinter    = Printer_Paper,
   @cLabelPrinter    = Printer,

   @cPickSlipNo      = V_PickSlipNo,
   @cSKU             = V_SKU,
   @nQTY             = V_QTY,
   @cSKUDescr        = V_SKUDescr,
   -- @cCustomID        = V_CaseID,
   @nFromScn         = V_FromScn,
   @nFromStep        = V_FromStep,
   @cPUOM            = V_UOM,

   @cPackDtlRefNo       = V_String1,
   @cPackDtlRefNo2      = V_String2,
   @cLabelNo            = V_String3,
   @cCartonType         = V_String4,
   @cCube               = V_String5,
   @cWeight             = V_String6,
   @cRefNo              = V_String7,
   @cLabelLine          = V_String8,
   @cPackDtlDropID      = V_String9,
   @cUCCCounter         = V_String10,
   @cMUOM_Desc          = V_String11,
   @cPUOM_Desc          = V_String12,
   @cDisableQTYFieldSP  = V_String13,
   @cFlowThruScreen     = V_String14,

   @nCartonNo           = V_CartonNo,
   @nCartonSKU          = V_Integer1,
   @nCartonQTY          = V_Integer2,
   @nTotalCarton        = V_Integer3,
   @nTotalPick          = V_Integer4,
   @nTotalPack          = V_Integer5,
   @nTotalShort         = V_Integer6,
   @nPackedQTY          = V_Integer7,
   @nPUOM_Div           = V_Integer8,
   @nPQTY               = V_Integer9,
   @nMQTY               = V_Integer10,
   @nEnter              = V_Integer11,  --(cc01)  

   @cShowPickSlipNo     = V_String15,
   @cDefaultPrintLabelOption    = V_String16,
   @cDefaultPrintPackListOption = V_String17,
   @cDefaultWeight      = V_String18,
   @cUCCNo              = V_String19,
   @cFromDropID         = V_String20,
   @cExtendedValidateSP = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedInfoSP     = V_String23,
   @cExtendedInfo       = V_String24,
   @cDecodeSP           = V_String25,
   @cDisableQTYField    = V_String26,
   @cCapturePackInfoSP  = V_String27,
   @cPackInfo           = V_String28,
   @cAllowWeightZero    = V_String29,
   @cAllowCubeZero      = V_String30,
   @cAutoScanIn         = V_String31,
   @cDefaultOption      = V_String32,
   @cDisableOption      = V_String33,
   @cSerialNoCapture    = V_String34,
   @cPackList           = V_String35,
   @cShipLabel          = V_String36,
   @cCartonManifest     = V_String37,
   @cCustomCartonNo     = V_String38,
   @cCustomNo           = V_String39,
   @cDataCaptureSP      = V_String40,
   @cPackDtlUPC         = V_String41,
   @cPrePackIndicator   = V_String42,
   @cPackQtyIndicator   = V_String43,
   @cPackData1          = V_String44,
   @cPackData2          = V_String45,
   @cPackData3          = V_String46,
   @cMultiSKUBarcode    = V_String47,
   @cDefaultQTY         = V_String48, --(cc01)
   @cDefaultcartontype  = V_String49,
   @cPackByFromDropID   = V_String50,
   @cDefaultCursor      = V_String51, --(v7.5)

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

IF @nFunc = 838 -- Pack
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 838
   IF @nStep = 1  GOTO Step_1  -- Scn = 4650. PickSlipNo, FromDropID, ToDropID
   IF @nStep = 2  GOTO Step_2  -- Scn = 4651. Statistic
   IF @nStep = 3  GOTO Step_3  -- Scn = 4652. SKU QTY
   IF @nStep = 4  GOTO Step_4  -- Scn = 4653. Carton type, weight, cube, refno
   IF @nStep = 5  GOTO Step_5  -- Scn = 4654. Print label?
   IF @nStep = 6  GOTO Step_6  -- Scn = 4655. Print packing list?
   IF @nStep = 7  GOTO Step_7  -- Scn = 4656. Confrim repack?
   IF @nStep = 8  GOTO Step_8  -- Scn = 4657. UCC
   IF @nStep = 9  GOTO Step_9  -- Scn = 4830. Serial no
   IF @nStep = 10 GOTO Step_10 -- Scn = 4659. Data 1..3
   IF @nStep = 11 GOTO Step_11 -- Scn = 3570. Multi SKU Barocde
   IF @nStep = 99 GOTO Step_99 -- Extend SCN
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_0. Func = 838
********************************************************************************/
Step_0:
BEGIN
   -- Get default UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName
   
   -- Get storer configure
   SET @cAllowCubeZero = rdt.rdtGetConfig( @nFunc, 'AllowCubeZero', @cStorerKey)
   SET @cAllowWeightZero = rdt.rdtGetConfig( @nFunc, 'AllowWeightZero', @cStorerKey)
   SET @cAutoScanIn = rdt.rdtGetConfig( @nFunc, 'AutoScanIn', @cStorerKey)
   SET @cCustomCartonNo = rdt.rdtGetConfig( @nFunc, 'CustomCartonNo', @cStorerKey)
   SET @cDefaultWeight = rdt.RDTGetConfig( @nFunc, 'DefaultWeight', @cStorerKey)
   SET @cDisableOption = rdt.rdtGetConfig( @nFunc, 'DisableOption', @cStorerKey)
   SET @cDisableQTYField = rdt.rdtGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)
   SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorerKey)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
   SET @cPackByFromDropID = rdt.rdtGetConfig( @nFunc, 'PackByFromDropID', @cStorerKey)
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)
   SET @cShowPickSlipNo = rdt.RDTGetConfig( @nFunc, 'ShowPickSlipNo', @cStorerKey)

   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)
   IF @cCapturePackInfoSP = '0'
      SET @cCapturePackInfoSP = ''
   SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)
   IF @cCartonManifest = '0'
      SET @cCartonManifest = ''
   SET @cDataCaptureSP = rdt.RDTGetConfig( @nFunc, 'DataCaptureSP', @cStorerKey)
   IF @cDataCaptureSP = '0'
      SET @cDataCaptureSP = ''
   SET @cDefaultCursor = rdt.RDTGetConfig( @nFunc, 'DefaultCursor', @cStorerKey) --(v7.5)
   IF @cDefaultCursor = '0'
      SET @cDefaultCursor = ''
   SET @cDecodeSP = rdt.rdtGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDefaultcartontype=rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)  --(cc01)
   IF @cDefaultcartontype = '0'
      SET @cDefaultcartontype = ''
   SET @cDefaultOption = rdt.rdtGetConfig( @nFunc, 'DefaultOption', @cStorerKey)
   IF @cDefaultOption = '0'
      SET @cDefaultOption = ''
   SET @cDefaultPrintLabelOption = rdt.rdtGetConfig( @nFunc, 'DefaultPrintLabelOption', @cStorerKey)
   IF @cDefaultPrintLabelOption = '0'
      SET @cDefaultPrintLabelOption = ''
   SET @cDefaultPrintPackListOption = rdt.rdtGetConfig( @nFunc, 'DefaultPrintPackListOption', @cStorerKey)
   IF @cDefaultPrintPackListOption = '0'
      SET @cDefaultPrintPackListOption = ''
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)  --(cc01)
   IF @cDefaultQTY = '0'
      SET @cDefaultQTY = ''
   SET @cDisableQTYFieldSP = rdt.RDTGetConfig( @nFunc, 'DisableQTYFieldSP', @cStorerKey)
   IF @cDisableQTYFieldSP = '0'
      SET @cDisableQTYFieldSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)
   IF @cPackList = '0'
      SET @cPackList = ''
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Prepare next screen var
   SET @cOutField01 = '' -- PickSlipNo
   SET @cOutField02 = '' -- FromDropID
   SET @cOutField03 = '' -- ToDropID

   IF @cPackByFromDropID = '1'
      EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
   ELSE
      EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo

   -- Go to PickSlipNo screen
   SET @nScn = 4650
   SET @nStep = 1

   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END

   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         SET @nAction = 0

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
         @nScn OUTPUT,  @nStep OUTPUT,
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
            GOTO  Quit
         END

         GOTO Quit
      END
   END -- ExtendedScreenSP <> ''
END
GOTO Quit


/************************************************************************************
Scn = 4650. PickSlipNo screen
   PSNO        (field01, input)
   FROMDROPID  (field02, input)
   TODROPID    (field03, input)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01
      SET @cFromDropID = @cInField02
      SET @cPackDtlDropID = @cInField03
      SET @cBarcode = @cInField02
      SET @cBarcode2 = @cInField03
      SET @cFromDropIDDecode = ''
      SET @cToDropIDDecode = ''

      -- Check blank
      IF @cPickSlipNo = '' AND @cFromDropID = ''
      BEGIN
         SET @nErrNo = 100232
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PS/DropID
         GOTO Quit
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Customize decode
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode, @cBarcode2, ' +
               ' @cSKU OUTPUT, @nQTY OUTPUT, @cPackDtlRefNo OUTPUT, @cPackDtlRefNo2 OUTPUT, @cPackDtlUPC OUTPUT, @cPackDtlDropID OUTPUT, @cSerialNo OUTPUT, ' +
               ' @cFromDropIDDecode OUTPUT, @cToDropIDDecode OUTPUT, @cUCCNo OUTPUT, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile           INT,           ' +
               ' @nFunc             INT,           ' +
               ' @cLangCode         NVARCHAR( 3),  ' +
               ' @nStep             INT,           ' +
               ' @nInputKey         INT,           ' +
               ' @cFacility         NVARCHAR( 5),  ' +
               ' @cStorerKey        NVARCHAR( 15), ' +
               ' @cPickSlipNo       NVARCHAR( 10), ' +
               ' @cFromDropID       NVARCHAR( 20), ' +
               ' @cBarcode          NVARCHAR( 60), ' +
               ' @cBarcode2         NVARCHAR( 60), ' +
               ' @cSKU              NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY              INT            OUTPUT, ' +
               ' @cPackDtlRefNo     NVARCHAR( 20)  OUTPUT, ' +
               ' @cPackDtlRefNo2    NVARCHAR( 20)  OUTPUT, ' +
               ' @cPackDtlUPC       NVARCHAR( 30)  OUTPUT, ' +
               ' @cPackDtlDropID    NVARCHAR( 20)  OUTPUT, ' +
               ' @cSerialNo         NVARCHAR( 30)  OUTPUT, ' +
               ' @cFromDropIDDecode NVARCHAR( 30)  OUTPUT, ' +
               ' @cToDropIDDecode   NVARCHAR( 30)  OUTPUT, ' +
               ' @cUCCNo            NVARCHAR( 30)  OUTPUT, ' +
               ' @nErrNo            INT            OUTPUT, ' +
               ' @cErrMsg           NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode, @cBarcode2,
               @cUPC OUTPUT, @nQTY OUTPUT, @cPackDtlRefNo OUTPUT, @cPackDtlRefNo2 OUTPUT, @cPackDtlUPC OUTPUT, @cPackDtlDropID_Decode OUTPUT, @cSerialNo OUTPUT,
               @cFromDropIDDecode OUTPUT, @cToDropIDDecode OUTPUT, @cUCCNo OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END

         IF @cFromDropIDDecode <> ''
            SET @cFromDropID = @cFromDropIDDecode

         IF @cToDropIDDecode <> ''
            SET @cPackDtlDropID = @cToDropIDDecode

      END

      IF @cFromDropID <> ''
      BEGIN
         -- Check FromDropID format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'FROMDROPID', @cFromDropID) = 0
         BEGIN
            SET @nErrNo = 100233
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
            SET @cOutField02 = ''
            GOTO Quit
         END

         -- Get DropID info
         DECLARE @cOrderKey NVARCHAR( 10)
         SET @cOrderKey = ''
         SELECT TOP 1
            @cOrderKey = OrderKey
         FROM PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DropID = @cFromDropID
            AND Status <= '5'

         -- Check DropID valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 100234
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
            SET @cOutField02 = ''
            GOTO Quit
         END

         -- Auto retrieve PickSlipNo
         IF @cPickSlipNo = ''
         BEGIN
            -- Get discrete pick slip
            SELECT @cPickSlipNo = PickHeaderKey
            FROM PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            -- Get conso pick slip
            IF @cPickSlipNo = ''
            BEGIN
               DECLARE @cLoadKey NVARCHAR( 10)
               SET @cLoadKey = ''
               SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

               IF @cLoadKey <> ''
                  SELECT @cPickSlipNo = PickHeaderKey
                  FROM PickHeader WITH (NOLOCK)
                  WHERE ExternOrderKey = @cLoadKey
                     AND OrderKey = ''
            END

            -- Check PickHeader
            IF @cPickSlipNo = ''
            BEGIN
               SET @nErrNo = 100235
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickHdr
               EXEC rdt.rdtSetFocusField @nMobile, 2  -- ToDropID
               SET @cOutField02 = ''
               GOTO Quit
            END

            SET @cOutField01 = @cPickSlipNo
            SET @cOutField02 = @cFromDropID
         END
      END

      -- Check blank
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 100201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PSNO required
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
         GOTO Quit
      END

      -- Check blank
      IF @cFromDropID = '' AND @cPackByFromDropID = '1'
      BEGIN
         SET @nErrNo = 100247
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedFromDropID
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
         GOTO Quit
      END

      -- Check PickSlipNo
      EXEC rdt.rdt_Pack_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PICKSLIPNO'
         ,@cPickSlipNo
         ,'' --@cFromDropID
         ,'' --@cPackDtlDropID
         ,'' --@cSKU
         ,0  --@nQTY
         ,0  --@nCartonNo
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
         SET @cOutField01 = ''
         GOTO Quit
      END
      SET @cOutField01 = @cPickSlipNo

      -- Check ToDropID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TODROPID', @cPackDtlDropID) = 0
      BEGIN
         SET @nErrNo = 100202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 3  -- ToDropID
         SET @cOutField03 = ''
         GOTO Quit
      END
      SET @cOutField03 = @cPackDtlDropID

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Get PickingInfo info
      DECLARE @dScanInDate DATETIME
      SELECT @dScanInDate = ScanInDate FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

      -- Check scan-in
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
                  SET @nErrNo = 100227
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
                  SET @nErrNo = 100237
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                  GOTO Quit
               END
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 100228
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Scan-In
            GOTO Quit
         END
      END

      SET @nCartonNo    = 0
      SET @cLabelNo     = ''
      SET @cCustomNo    = ''
      SET @cCustomID    = ''
      SET @nCartonSKU   = 0
      SET @nCartonQTY   = 0
      SET @nTotalCarton = 0
      SET @nTotalPick   = 0
      SET @nTotalPack   = 0
      SET @nTotalShort  = 0

      -- Get task
      EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXT'
         ,@cPickSlipNo
         ,@cFromDropID
         ,@cPackDtlDropID
         ,@nCartonNo    OUTPUT
         ,@cLabelNo     OUTPUT
         ,@cCustomNo    OUTPUT
         ,@cCustomID    OUTPUT
         ,@nCartonSKU   OUTPUT
         ,@nCartonQTY   OUTPUT
         ,@nTotalCarton OUTPUT
         ,@nTotalPick   OUTPUT
         ,@nTotalPack   OUTPUT
         ,@nTotalShort  OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- (james17)
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cFromDropID',     @cFromDropID),
               ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
               ('@cLabelNo',        @cLabelNo),
               ('@cSKU',            @cSKU),
               ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
               ('@cUCCNo',          @cUCCNo),
               ('@cCartonType',     @cCartonType),
               ('@cCube',           @cCube),
               ('@cWeight',         @cWeight),
               ('@cRefNo',          @cRefNo),
               ('@cSerialNo',       @cSerialNo),
               ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
               ('@cOption',         @cOption),
               ('@cPackDtlRefNo',   @cPackDtlRefNo),
               ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
               ('@cPackDtlUPC',     @cPackDtlUPC),
               ('@cPackDtlDropID',  @cPackDtlDropID),
               ('@cPackData1',      @cPackData1),
               ('@cPackData2',      @cPackData2),
               ('@cPackData3',      @cPackData3)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

               SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  -- ZG02
      SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  -- ZG02
      SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8))  -- ZG02
      SET @cOutField05 = RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
      SET @cOutField06 = @cCustomID
      SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
      SET @cOutField09 = @cDefaultOption

      IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '2') -- Statistic screen 
      BEGIN
         SET @cInField09 = '1' -- Option
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Step_2
      END

      -- Go to statistic screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
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
   
   --(JHU151)      
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         SET @nAction = 0 --Jump
         SET @cJumpType = 'Forward' --Jump
         
         GOTO Step_99
      END
   END
   
END
GOTO Quit


/********************************************************************************
Scn = 4651. Statistic screen
   OPTION    (field09, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField09

      -- Loop blank
      IF @cOption = ''
      BEGIN
         -- Get task
         EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXT'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@nCartonNo    OUTPUT
            ,@cLabelNo     OUTPUT
            ,@cCustomNo    OUTPUT
            ,@cCustomID    OUTPUT
            ,@nCartonSKU   OUTPUT
            ,@nCartonQTY   OUTPUT
            ,@nTotalCarton OUTPUT
            ,@nTotalPick   OUTPUT
            ,@nTotalPack   OUTPUT
            ,@nTotalShort  OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare next screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  -- ZG02
         SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  -- ZG02
         SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8))  -- ZG02
         SET @cOutField05 = RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
         SET @cOutField06 = @cCustomID
         SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = '' -- Option

         GOTO Quit
      END

      -- Validate option
      IF @cOption NOT IN ('1', '2', '3', '4')
      BEGIN
         SET @nErrNo = 100205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField08 = '' -- Option
         GOTO Quit
      END

      -- Check disable option
      IF @cDisableOption <> ''
      BEGIN
         IF CHARINDEX( @cOption, @cDisableOption) > 0
         BEGIN
            SET @nErrNo = 100205
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DisabledOption
            SET @cOutField08 = '' -- Option
            GOTO Quit
         END
      END

      -- Check Pack confirmed
      IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')
      BEGIN
         SET @nErrNo = 100203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack confirmed
         GOTO Quit
      END

      -- Check valid carton
      IF @nCartonNo = 0 AND @cOption IN ('2', '3')
      BEGIN
         SET @nErrNo = 100224
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No carton
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,    ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

         END
      END

      -- Disable QTY field
      IF @cDisableQTYFieldSP <> ''
      BEGIN
         IF @cDisableQTYFieldSP = '1'
         BEGIN
            SET @cDisableQTYField = @cDisableQTYFieldSP
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
               '@nMobile            INT,           ' +
               '@nFunc              INT,           ' +
               '@cLangCode          NVARCHAR( 3),  ' +
               '@nStep              INT,           ' +
               '@nInputKey          INT,           ' +
               '@cFacility          NVARCHAR( 5),  ' +
               '@cStorerKey         NVARCHAR( 15), ' +
               '@cPickSlipNo        NVARCHAR( 10), ' +
               '@cFromDropID        NVARCHAR( 20), ' +
               '@nCartonNo          INT,           ' +
               '@cLabelNo           NVARCHAR( 20), ' +
               '@cSKU               NVARCHAR( 20), ' +
               '@nQTY               INT,           ' +
               '@cUCCNo             NVARCHAR( 20), ' +
               '@cCartonType        NVARCHAR( 10), ' +
               '@cCube              NVARCHAR( 10), ' +
               '@cWeight            NVARCHAR( 10), ' +
               '@cRefNo             NVARCHAR( 20), ' +
               '@cSerialNo          NVARCHAR( 30), ' +
               '@nSerialQTY         INT,           ' +
               '@cOption            NVARCHAR( 1),  ' +
               '@cPackDtlRefNo      NVARCHAR( 20), ' +
               '@cPackDtlRefNo2     NVARCHAR( 20), ' +
               '@cPackDtlUPC        NVARCHAR( 30), ' +
               '@cPackDtlDropID     NVARCHAR( 20), ' +
               '@cPackData1         NVARCHAR( 30), ' +
               '@cPackData2         NVARCHAR( 30), ' +
               '@cPackData3         NVARCHAR( 30), ' +
               '@tVarDisableQTYField VariableTable READONLY, ' +
               '@cDisableQTYField   NVARCHAR( 1)   OUTPUT, ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                  @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                  @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                  @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END

      SET @cUCCNo = ''

      -- New carton
      IF @cOption = '1'
      BEGIN
         SET @nCartonNo = 0
         SET @cLabelNo = ''
         SET @cSKU = ''
         SET @nPackedQTY = 0
         SET @nCartonSKU = 0
         SET @nCartonQTY = 0

         -- Prepare next screen var
         SET @cOutField01 = 'NEW'
         SET @cOutField02 = '0/0'
         SET @cOutField03 = ''  -- SKU
         SET @cOutField04 = ''  -- SKU
         SET @cOutField05 = ''  -- Desc 1
         SET @cOutField06 = ''  -- Desc 2
         SET @cOutField07 = '0' -- Packed
         SET @cOutField08 = @cDefaultQTY  -- QTY --(cc01)
         SET @cOutField09 = '0' -- CartonQTY
         SET @cOutField11 = '' -- UOM
         SET @cOutField12 = '' -- PUOM
         SET @cOutField13 = '' -- MUOM
         SET @cOutField14 = '' -- PQTY
         SET @cOutField15 = '' -- ExtendedInfo

         -- Enable field
         SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END
         SET @cFieldAttr14 = 'O'
         SET @nEnter = 0 --(cc01)  

         EXEC rdt.rdtSetFocusField @nMobile, 6  -- SKU

         -- Go to SKU QTY screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      -- Edit carton
      ELSE IF @cOption = '2'
      BEGIN
         -- Check UCC
         IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo AND UCCNo <> '')
         BEGIN
            SET @nErrNo = 100229
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot EditUCC
            GOTO Quit
         END

         -- Get carton info
         SELECT TOP 1
            @cSKU = SKU,
            @cLabelLine = LabelLine
         FROM PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
         ORDER BY LabelLine

         -- Get SKU info
         SELECT
            @cSKUDescr = Descr,
            @cPrePackIndicator = ISNULL( PrePackIndicator, ''),
            @cPackQtyIndicator = LEFT( ISNULL( PackQtyIndicator, '0'), 3),
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
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         -- Get PackDetail info
         SELECT @nPackedQTY = PD.QTY
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @cFieldAttr14 = 'O' -- @nPQTY
         END

         -- Prepare next screen var
         SET @cOutField01 = RTRIM( @cCustomNo)
         SET @cOutField02 = CAST( CAST( @cLabelLine AS INT) AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = @cSKU
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
         SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
         SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
         SET @cOutField08 = '' -- QTY
         SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
         SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
         SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
         SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
         SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
         SET @cOutField14 = '' -- PQTY
         SET @cOutField15 = '' -- ExtendedInfo

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @cFieldAttr14 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @cFieldAttr14 = '' -- @nPQTY
         END

         SET @nEnter = 0 --(JHU151)  

         -- Enable field
         SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

         EXEC rdt.rdtSetFocusField @nMobile, 3  -- SKU

         -- Go to SKU QTY screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

      END

      -- Repack carton
      ELSE IF @cOption = '3'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = RTRIM( @cCustomNo)
         SET @cOutField02 = '' -- Option

         SET @nEnter = 0 --(JHU151)  

         -- Go to repack screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END

      -- UCC
      ELSE IF @cOption = '4'
      BEGIN
         -- Get total UCC
         SELECT @nTotalUCC = COUNT(1) FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND UCCNo <> ''

         SET @cUCCCounter = ''

         -- Prepare next screen var
         SET @cOutField01 = '' -- UCC
         SET @cOutField02 = '' -- Scan
         SET @cOutField03 = CAST( @nTotalUCC AS NVARCHAR( 5))

         -- Go to UCC screen
         SET @nScn = @nScn + 6
         SET @nStep = @nStep + 6
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cFromDropID',     @cFromDropID),
               ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
               ('@cLabelNo',        @cLabelNo),
               ('@cSKU',            @cSKU),
               ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
               ('@cUCCNo',          @cUCCNo),
               ('@cCartonType',     @cCartonType),
               ('@cCube',           @cCube),
               ('@cWeight',         @cWeight),
               ('@cRefNo',          @cRefNo),
               ('@cSerialNo',       @cSerialNo),
               ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
               ('@cOption',         @cOption),
               ('@cPackDtlRefNo',   @cPackDtlRefNo),
               ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
               ('@cPackDtlUPC',     @cPackDtlUPC),
               ('@cPackDtlDropID',  @cPackDtlDropID),
               ('@cPackData1',      @cPackData1),
               ('@cPackData2',      @cPackData2),
               ('@cPackData3',      @cPackData3)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
             @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 3
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Pack confirm
      IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '9')
      BEGIN
         -- Pack confirm
         SET @cPrintPackList = ''
         EXEC rdt.rdt_Pack_PackConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@cPrintPackList OUTPUT
            ,@nErrNo         OUTPUT
            ,@cErrMsg        OUTPUT
         -- IF @nErrNo <> 0
         --    GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

         END
      END

      IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9') OR @cPrintPackList = 'Y'
      BEGIN
         -- Print packing list
         IF @cPackList <> ''
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cDefaultPrintPackListOption --Option

            -- Go to print packing list screen
            SET @nScn = @nScn + 4
            SET @nStep = @nStep + 4

            GOTO Quit
         END
      END

      -- Prepare prev screen var
      SET @cOutField01 = CASE WHEN @cShowPickSlipNo = '1' THEN @cPickSlipNo ELSE '' END -- PickSlipNo (james17)
      SET @cOutField02 = '' -- FromDropID
      SET @cOutField03 = '' -- ToDropID

      --(v7.5) start
      IF @cFromDropID <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
      ELSE
      BEGIN
         IF @cPackDtlDropID <> ''
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- ToDropID
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
      END
      --(v7.5) end

      -- Go to PickSlipNo screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END -- Inputkey = 0


   -- Ext Scn SP
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         SET @nAction = 0

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
         @nScn OUTPUT,  @nStep OUTPUT,
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
            GOTO  Quit
         END

         GOTO Quit
      END
   END -- ExtendedScreenSP <> ''
END -- step 2

GOTO Quit


/********************************************************************************
Scn = 4652. SKU QTY screen
   CARTON NO   (field01)
   SKUCount    (field02)
   CartonSKU   (field02)
   SKU/UPC     (field03, input)
   SKU         (field04)
   DESCR1      (field05)
   DESCR2      (field06)
   PACKED      (field07)
   QTY         (field08, input)
   CARTON QTY  (field09)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cSkipChkPPKQTY NVARCHAR(1) = '0' --(v7.5)

      SET @nQTY = 0
      SET @nDecodeQTY = 0
      SET @cQTY = ''

      -- Screen mapping
      SET @cBarcode = @cInField03 -- SKU
      SET @cBarcode2 = ''
      SET @cUPC = LEFT( @cInField03, 30) -- SKU
      SET @cMQTY = CASE WHEN @cFieldAttr08 = 'O' THEN '' ELSE @cInField08 END
      SET @cPQTY = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE @cInField14 END

      -- Retain value
      SET @cOutField08 = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END -- PQTY
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END -- MQTY

      -- Loop SKU
      IF @cBarcode = '' AND @cMQTY = '' AND @cPQTY = ''
      BEGIN
         IF @nCartonQTY > 0
         BEGIN
            -- Get carton info
            SELECT TOP 1
               @cSKU = SKU,
               @cLabelLine = LabelLine
            FROM PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine > @cLabelLine
            ORDER BY LabelLine

            IF @@ROWCOUNT = 0
               SELECT TOP 1
                  @cSKU = SKU,
                  @cLabelLine = LabelLine
               FROM PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cLabelNo
               ORDER BY LabelLine

            -- Get SKU info
            SELECT
               @cSKUDescr = Descr,
               @cPrePackIndicator = ISNULL( PrePackIndicator, ''),
               @cPackQtyIndicator = LEFT( ISNULL( PackQtyIndicator, '0'), 3),
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
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU

            -- Disable QTY field (cc03)
            IF @cDisableQTYFieldSP <> ''
            BEGIN
               IF @cDisableQTYFieldSP = '1'
               BEGIN
                  SET @cDisableQTYField = @cDisableQTYFieldSP
               END
               ELSE
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                     ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                     ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                     ' @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                     SET @cSQLParam =
                     '@nMobile            INT,           ' +
                     '@nFunc              INT,           ' +
                     '@cLangCode          NVARCHAR( 3),  ' +
                     '@nStep              INT,           ' +
                     '@nInputKey          INT,           ' +
                     '@cFacility          NVARCHAR( 5),  ' +
                     '@cStorerKey         NVARCHAR( 15), ' +
                     '@cPickSlipNo        NVARCHAR( 10), ' +
                     '@cFromDropID        NVARCHAR( 20), ' +
                     '@nCartonNo          INT,           ' +
                     '@cLabelNo           NVARCHAR( 20), ' +
                     '@cSKU               NVARCHAR( 20), ' +
                     '@nQTY               INT,           ' +
                     '@cUCCNo             NVARCHAR( 20), ' +
                     '@cCartonType        NVARCHAR( 10), ' +
                     '@cCube              NVARCHAR( 10), ' +
                     '@cWeight            NVARCHAR( 10), ' +
                     '@cRefNo             NVARCHAR( 20), ' +
                     '@cSerialNo          NVARCHAR( 30), ' +
                     '@nSerialQTY         INT,           ' +
                     '@cOption            NVARCHAR( 1),  ' +
                     '@cPackDtlRefNo      NVARCHAR( 20), ' +
                     '@cPackDtlRefNo2     NVARCHAR( 20), ' +
                     '@cPackDtlUPC        NVARCHAR( 30), ' +
                     '@cPackDtlDropID     NVARCHAR( 20), ' +
                     '@cPackData1         NVARCHAR( 30), ' +
                     '@cPackData2         NVARCHAR( 30), ' +
                     '@cPackData3         NVARCHAR( 30), ' +
                     '@tVarDisableQTYField VariableTable READONLY, ' +
                     '@cDisableQTYField   NVARCHAR( 1)   OUTPUT, ' +
                     '@nErrNo             INT            OUTPUT, ' +
                     '@cErrMsg            NVARCHAR( 20)  OUTPUT'

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                        @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                        @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                        @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                     IF @nErrNo <> 0
                        GOTO Quit
                  END
               END
            END

            -- Get PackDetail info
            SELECT @nPackedQTY = PD.QTY
            FROM dbo.PackDetail PD WITH (NOLOCK)
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine = @cLabelLine

            -- Prepare next screen var
            SET @cOutField01 = RTRIM( @cCustomNo)
            SET @cOutField02 = CAST( CAST( @cLabelLine AS INT) AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
            SET @cOutField03 = '' -- SKU
            SET @cOutField04 = @cSKU
            SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
            SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
            SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
            SET @cOutField08 = @cDefaultQTY -- QTY --(cc01)
            SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
            SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
            SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
            SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
            SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
            SET @cOutField14 = '' -- PQTY

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @cFieldAttr14 = 'O' -- @nPQTY
            END
            ELSE
            BEGIN
               SET @cFieldAttr14 = '' -- @nPQTY
            END

            -- Extended info
            IF @cExtendedInfoSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
               BEGIN
                  INSERT INTO @tVar (Variable, Value) VALUES
                     ('@cPickSlipNo',     @cPickSlipNo),
                     ('@cFromDropID',     @cFromDropID),
                     ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
                     ('@cLabelNo',        @cLabelNo),
                     ('@cSKU',            @cSKU),
                     ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
                     ('@cUCCNo',          @cUCCNo),
                     ('@cCartonType',     @cCartonType),
                     ('@cCube',           @cCube),
                     ('@cWeight',         @cWeight),
                     ('@cRefNo',          @cRefNo),
                     ('@cSerialNo',       @cSerialNo),
                     ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
                     ('@cOption',         @cOption),
                     ('@cPackDtlRefNo',   @cPackDtlRefNo),
                     ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
                     ('@cPackDtlUPC',     @cPackDtlUPC),
                     ('@cPackDtlDropID',  @cPackDtlDropID),
                     ('@cPackData1',      @cPackData1),
                     ('@cPackData2',      @cPackData2),
                     ('@cPackData3',      @cPackData3)

                  SET @cExtendedInfo = ''
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
                     ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     ' @nMobile        INT,           ' +
                     ' @nFunc          INT,           ' +
                     ' @cLangCode      NVARCHAR( 3),  ' +
                     ' @nStep          INT,           ' +
                     ' @nAfterStep     INT,           ' +
                     ' @nInputKey      INT,           ' +
                     ' @cFacility      NVARCHAR( 5),  ' +
                     ' @cStorerKey     NVARCHAR( 15), ' +
                     ' @tVar           VariableTable READONLY, ' +
                     ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
                     ' @nErrNo         INT           OUTPUT,   ' +
                     ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
                     @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit

                  IF @nStep = 3
                     SET @cOutField15 = @cExtendedInfo
               END
            END

            GOTO Quit
         END
      END

      -- Check SKU blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 100206
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
         GOTO Step_3_Fail
      END

      -- Validate SKU
      IF @cBarcode <> ''
      BEGIN
         -- Decode
         IF @cDecodeSP <> ''
         BEGIN
            SET @cPackDtlRefNo  = ''
            SET @cPackDtlRefNo2 = ''
            SET @cPackDtlUPC    = ''
            SET @cPackDtlDropID_Decode = ''

            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cUPC          = @cUPC           OUTPUT,
                  @nQTY          = @nDecodeQTY     OUTPUT,
                  @cUserDefine01 = @cPackDtlRefNo  OUTPUT,
                  @cUserDefine02 = @cPackDtlRefNo2 OUTPUT,
                  @cUserDefine03 = @cPackDtlUPC    OUTPUT,
                  @cUserDefine04 = @cPackDtlDropID_Decode OUTPUT,
                  @cSerialNo     = @cSerialNo      OUTPUT,
                  @nErrNo        = 0, --@nErrNo     OUTPUT,
                  @cErrMsg       = '' --@cErrMsg    OUTPUT
            END

            -- Customize decode
            ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode, @cBarcode2, ' +
                  ' @cSKU OUTPUT, @nQTY OUTPUT, @cPackDtlRefNo OUTPUT, @cPackDtlRefNo2 OUTPUT, @cPackDtlUPC OUTPUT, @cPackDtlDropID OUTPUT, @cSerialNo OUTPUT, ' +
                  ' @cFromDropIDDecode OUTPUT, @cToDropIDDecode OUTPUT, @cUCCNo OUTPUT, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile           INT,           ' +
                  ' @nFunc             INT,           ' +
                  ' @cLangCode         NVARCHAR( 3),  ' +
                  ' @nStep             INT,           ' +
                  ' @nInputKey         INT,           ' +
                  ' @cFacility         NVARCHAR( 5),  ' +
                  ' @cStorerKey        NVARCHAR( 15), ' +
                  ' @cPickSlipNo       NVARCHAR( 10), ' +
                  ' @cFromDropID       NVARCHAR( 20), ' +
                  ' @cBarcode          NVARCHAR( 60), ' +
                  ' @cBarcode2         NVARCHAR( 60), ' +
                  ' @cSKU              NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY              INT            OUTPUT, ' +
                  ' @cPackDtlRefNo     NVARCHAR( 20)  OUTPUT, ' +
                  ' @cPackDtlRefNo2    NVARCHAR( 20)  OUTPUT, ' +
                  ' @cPackDtlUPC       NVARCHAR( 30)  OUTPUT, ' +
                  ' @cPackDtlDropID    NVARCHAR( 20)  OUTPUT, ' +
                  ' @cSerialNo         NVARCHAR( 30)  OUTPUT, ' +
                  ' @cFromDropIDDecode NVARCHAR( 30)  OUTPUT, ' +
                  ' @cToDropIDDecode   NVARCHAR( 30)  OUTPUT, ' +
                  ' @cUCCNo            NVARCHAR( 30)  OUTPUT, ' +
                  ' @nErrNo            INT            OUTPUT, ' +
                  ' @cErrMsg           NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode, @cBarcode2,
                  @cUPC OUTPUT, @nQTY OUTPUT, @cPackDtlRefNo OUTPUT, @cPackDtlRefNo2 OUTPUT, @cPackDtlUPC OUTPUT, @cPackDtlDropID_Decode OUTPUT, @cSerialNo OUTPUT, 
                  @cFromDropIDDecode OUTPUT, @cToDropIDDecode OUTPUT, @cUCCNo OUTPUT,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_3_Fail

               IF ISNULL( @nQTY, 0) > 0
                  SET @nDecodeQTY = @nQTY
            END

            IF @cPackDtlDropID_Decode <> ''
               SET @cPackDtlDropID = @cPackDtlDropID_Decode
         END

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

         -- Check SKU valid
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 100207
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_3_Fail
         END


         -- Check barcode return multi SKU
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
                  @cUPC     OUTPUT,
                  @nErrNo   OUTPUT,
                  @cErrMsg  OUTPUT,
                  'PICKSLIPNO',    -- DocType
                  @cPickSlipNo

               IF @nErrNo = 0 -- Populate multi SKU screen
               BEGIN
                  -- Go to Multi SKU screen
                  SET @nFromScn = @nScn
                  SET @nScn = 3570
                  SET @nStep = @nStep + 8
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
               SET @nErrNo = 100208
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
               GOTO Step_3_Fail
            END
         END

         IF @nSKUCnt = 1
            EXEC rdt.rdt_GetSKU
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cUPC      OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT

         SET @cSKU = @cUPC

         -- Check SKU in PickSlipNo
         EXEC rdt.rdt_Pack_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@cSKU
            ,0 --@nQTY
            ,0 --@nCartonNo
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Step_3_Fail

         -- Get SKU info
         SELECT
            @cSKUDescr = Descr,
            @cSKUDataCapture = DataCapture,
            @cPrePackIndicator = ISNULL( PrePackIndicator, ''),
            @cPackQtyIndicator = LEFT( ISNULL( PackQtyIndicator, '0'), 3),
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
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         -- Get PackDetail info
         SET @nPackedQTY = 0
         SELECT @nPackedQTY = QTY
         FROM PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.CartonNo = @nCartonNo -- Could be 0, no record
            AND PD.SKU = @cSKU

         -- Disable QTY field (cc03)
         IF @cDisableQTYFieldSP <> ''
         BEGIN
            IF @cDisableQTYFieldSP = '1'
            BEGIN
               SET @cDisableQTYField = @cDisableQTYFieldSP
            END
            ELSE
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                  ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                  ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                  ' @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                  '@nMobile            INT,           ' +
                  '@nFunc              INT,           ' +
                  '@cLangCode          NVARCHAR( 3),  ' +
                  '@nStep              INT,           ' +
                  '@nInputKey          INT,           ' +
                  '@cFacility          NVARCHAR( 5),  ' +
                  '@cStorerKey         NVARCHAR( 15), ' +
                  '@cPickSlipNo        NVARCHAR( 10), ' +
                  '@cFromDropID        NVARCHAR( 20), ' +
                  '@nCartonNo          INT,           ' +
                  '@cLabelNo           NVARCHAR( 20), ' +
                  '@cSKU               NVARCHAR( 20), ' +
                  '@nQTY               INT,           ' +
                  '@cUCCNo             NVARCHAR( 20), ' +
                  '@cCartonType        NVARCHAR( 10), ' +
                  '@cCube              NVARCHAR( 10), ' +
                  '@cWeight            NVARCHAR( 10), ' +
                  '@cRefNo             NVARCHAR( 20), ' +
                  '@cSerialNo          NVARCHAR( 30), ' +
                  '@nSerialQTY         INT,           ' +
                  '@cOption            NVARCHAR( 1),  ' +
                  '@cPackDtlRefNo      NVARCHAR( 20), ' +
                  '@cPackDtlRefNo2     NVARCHAR( 20), ' +
                  '@cPackDtlUPC        NVARCHAR( 30), ' +
                  '@cPackDtlDropID     NVARCHAR( 20), ' +
                  '@cPackData1         NVARCHAR( 30), ' +
                  '@cPackData2         NVARCHAR( 30), ' +
                  '@cPackData3         NVARCHAR( 30), ' +
                  '@tVarDisableQTYField VariableTable READONLY, ' +
                  '@cDisableQTYField   NVARCHAR( 1)   OUTPUT, ' +
                  '@nErrNo             INT            OUTPUT, ' +
                  '@cErrMsg            NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                     @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                     @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                     @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
         END
         --(V7.5) start
         IF @cPrePackIndicator = '2'
         BEGIN
            DECLARE @cSkipChkPPKQTYSP NVARCHAR( 20) = 0
            SET @cSkipChkPPKQTYSP = rdt.RDTGetConfig( @nFunc, 'SkipChkPPKQTYSP', @cStorerKey)
            IF @cSkipChkPPKQTYSP = '0'
               SET @cSkipChkPPKQTYSP = ''

            IF @cSkipChkPPKQTYSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSkipChkPPKQTYSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cSkipChkPPKQTYSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                  ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                  ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                  ' @tVarDisableQTYField, @cSkipChkPPKQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                  '@nMobile            INT,           ' +
                  '@nFunc              INT,           ' +
                  '@cLangCode          NVARCHAR( 3),  ' +
                  '@nStep              INT,           ' +
                  '@nInputKey          INT,           ' +
                  '@cFacility          NVARCHAR( 5),  ' +
                  '@cStorerKey         NVARCHAR( 15), ' +
                  '@cPickSlipNo        NVARCHAR( 10), ' +
                  '@cFromDropID        NVARCHAR( 20), ' +
                  '@nCartonNo          INT,           ' +
                  '@cLabelNo           NVARCHAR( 20), ' +
                  '@cSKU               NVARCHAR( 20), ' +
                  '@nQTY               INT,           ' +
                  '@cUCCNo             NVARCHAR( 20), ' +
                  '@cCartonType        NVARCHAR( 10), ' +
                  '@cCube              NVARCHAR( 10), ' +
                  '@cWeight            NVARCHAR( 10), ' +
                  '@cRefNo             NVARCHAR( 20), ' +
                  '@cSerialNo          NVARCHAR( 30), ' +
                  '@nSerialQTY         INT,           ' +
                  '@cOption            NVARCHAR( 1),  ' +
                  '@cPackDtlRefNo      NVARCHAR( 20), ' +
                  '@cPackDtlRefNo2     NVARCHAR( 20), ' +
                  '@cPackDtlUPC        NVARCHAR( 30), ' +
                  '@cPackDtlDropID     NVARCHAR( 20), ' +
                  '@cPackData1         NVARCHAR( 30), ' +
                  '@cPackData2         NVARCHAR( 30), ' +
                  '@cPackData3         NVARCHAR( 30), ' +
                  '@tVarDisableQTYField VariableTable READONLY, ' +
                  '@cSkipChkPPKQTY     NVARCHAR( 1)   OUTPUT, ' +
                  '@nErrNo             INT            OUTPUT, ' +
                  '@cErrMsg            NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                     @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                     @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                     @tVarDisableQTYField, @cSkipChkPPKQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
         END
         --(V7.5) end

         -- (james01)
         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               INSERT INTO @tVar (Variable, Value) VALUES
                  ('@cPickSlipNo',     @cPickSlipNo),
                  ('@cFromDropID',     @cFromDropID),
                  ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
                  ('@cLabelNo',        @cLabelNo),
                  ('@cSKU',            @cSKU),
                  ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
                  ('@cUCCNo',          @cUCCNo),
                  ('@cCartonType',     @cCartonType),
                  ('@cCube',           @cCube),
                  ('@cWeight',         @cWeight),
                  ('@cRefNo',          @cRefNo),
                  ('@cSerialNo',       @cSerialNo),
                  ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
                  ('@cOption',         @cOption),
                  ('@cPackDtlRefNo',   @cPackDtlRefNo),
                  ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
                  ('@cPackDtlUPC',     @cPackDtlUPC),
                  ('@cPackDtlDropID',  @cPackDtlDropID),
                  ('@cPackData1',      @cPackData1),
                  ('@cPackData2',      @cPackData2),
                  ('@cPackData3',      @cPackData3)

               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
                  ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nAfterStep     INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cFacility      NVARCHAR( 5),  ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @tVar           VariableTable READONLY, ' +
                  ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
                  ' @nErrNo         INT           OUTPUT,   ' +
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
                  @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit

               IF @nStep = 3
                  SET @cOutField15 = @cExtendedInfo
            END
         END

         SET @cOutField03 = CASE WHEN @cDisableQTYField = '1' THEN '' ELSE @cSKU END
         SET @cOutField04 = @cSKU
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
         SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
         SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
         SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
         SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
         SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
         SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
         SET @cOutField14 = '' -- PQTY

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @cFieldAttr14 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @cFieldAttr14 = '' -- @nPQTY
         END

         EXEC rdt.rdtSetFocusField @nMobile, 8
      END

      
      --JHU151
      Step_3_ExtScn:
      BEGIN
         SET @nAction = 3 --Prepare output fields
         SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
         IF @cExtendedScreenSP = '0'
         BEGIN
            SET @cExtendedScreenSP = ''
         END
         IF @cExtendedScreenSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
               AND @nEnter = 0
            BEGIN
               DELETE FROM @tExtScnData
               INSERT INTO @tExtScnData (Variable, Value) VALUES 	
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cSKU',            @cUPC)

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
               @nScn OUTPUT,  @nStep OUTPUT,
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
                  GOTO  Step_3_Fail
               END 
               
               IF @cExtendedScreenSP = 'rdt_838ExtScn01' AND @cUDF30 = 'Y'
               BEGIN
                  SET @nEnter = 1  
                  EXEC rdt.rdtSetFocusField @nMobile, 8
                  GOTO Quit
               END
            END
         END       
      END

      --(cc01)  
      IF @cDefaultQTY >0 AND @nEnter = 0  
      BEGIN
         SET @nEnter = 1  
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO Quit
      END

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 1) = 0 --Check zero
      BEGIN
         SET @nErrNo = 100209
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- QTY
         GOTO Step_3_QTY_Fail
      END

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 1) = 0 --Check zero
      BEGIN
         SET @nErrNo = 100238
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- QTY
         GOTO Step_3_QTY_Fail
      END

      -- Get QTY
      IF @nDecodeQTY > 0
      BEGIN
         SET @cQTY = CAST( @nDecodeQTY AS NVARCHAR(8))  -- ZG02
         SET @nQTY = @nDecodeQTY
      END
      ELSE
         IF @cSKU <> '' AND @cDisableQTYField = '1' 
         BEGIN
            IF @cPrePackIndicator = '2' AND @cSkipChkPPKQTY = '0'--(v7.5)
            BEGIN
               SET @cQTY = @cPackQtyIndicator
               SET @nQTY = CAST( @cPackQtyIndicator AS INT)
            END
            ELSE
            BEGIN
               SET @cQTY = '1'
               SET @nQTY = 1
            END
         END
         ELSE
         BEGIN
            -- Calc total QTY in master UOM
            SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
            SET @nQTY = @nQTY + CAST( @cMQTY AS INT)

            IF @cPrePackIndicator = '2' AND @cSkipChkPPKQTY = '0'--(v7.5)
            BEGIN
               SET @nQTY = @nQTY * CAST( @cPackQtyIndicator AS INT)
               SET @cQTY = CAST( @nQTY AS NVARCHAR(8))  -- ZG02
            END
         END

      -- Retain QTY
      SET @cOutField08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE @cMQTY END --(cc03)
      SET @cOutField14 = CASE WHEN @cPUOM_Desc <> '' THEN @cPQTY ELSE '' END

      -- Check over pack
      EXEC rdt.rdt_Pack_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'QTY'
         ,@cPickSlipNo
         ,@cFromDropID
         ,@cPackDtlDropID
         ,@cSKU
         ,@nQTY
         ,@nCartonNo
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- QTY
         GOTO Step_3_QTY_Fail
      END

      -- Check blank QTY
      IF @cQTY = '' AND @nQTY = 0
      BEGIN
         SET @nErrNo = 100204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need QTY
         IF @cDisableQTYField = '1'
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
         ELSE
         BEGIN--(v7.5) start
            IF @cDefaultCursor <> ''
               EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 8 -- QTY
         END
         --(v7.5) end
         GOTO Step_3_QTY_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,    ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_QTY_Fail
         END
      END

      -- Custom data capture setup
      SET @cDataCapture = ''
      IF @cDataCaptureSP = ''
      BEGIN
         SET @cPackData1 = ''
         SET @cPackData2 = ''
         SET @cPackData3 = ''
      END
      ELSE
      BEGIN
         -- Get default data capture labels
         SET @cPackLabel1 = ''
         SET @cPackLabel2 = ''
         SET @cPackLabel3 = ''
         SELECT
            @cPackLabel1 = UDF01,
            @cPackLabel2 = UDF02,
            @cPackLabel3 = UDF03
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTDATALBL'
            AND Storerkey = @cStorerKey
            AND Code2 = @nFunc

         SET @cPackAttr1 = CASE WHEN @cPackLabel1 = '' THEN'O' ELSE '' END
         SET @cPackAttr2 = CASE WHEN @cPackLabel2 = '' THEN'O' ELSE '' END
         SET @cPackAttr3 = CASE WHEN @cPackLabel3 = '' THEN'O' ELSE '' END

         -- Custom SP to get data capture setup
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDataCaptureSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDataCaptureSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, ' +
               ' @cPackData1   OUTPUT, @cPackData2  OUTPUT, @cPackData3  OUTPUT, ' +
               ' @cPackLabel1  OUTPUT, @cPackLabel2 OUTPUT, @cPackLabel3 OUTPUT, ' +
               ' @cPackAttr1   OUTPUT, @cPackAttr2  OUTPUT, @cPackAttr3  OUTPUT, ' +
               ' @cDataCapture OUTPUT, @nErrNo      OUTPUT, @cErrMsg     OUTPUT  ' 
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30)  OUTPUT, ' +
               '@cPackData2      NVARCHAR( 30)  OUTPUT, ' +
               '@cPackData3      NVARCHAR( 30)  OUTPUT, ' +
               '@cPackLabel1     NVARCHAR( 20)  OUTPUT, ' +
               '@cPackLabel2     NVARCHAR( 20)  OUTPUT, ' +
               '@cPackLabel3     NVARCHAR( 20)  OUTPUT, ' +
               '@cPackAttr1      NVARCHAR( 1)   OUTPUT, ' +
               '@cPackAttr2      NVARCHAR( 1)   OUTPUT, ' +
               '@cPackAttr3      NVARCHAR( 1)   OUTPUT, ' +
               '@cDataCapture    NVARCHAR( 1)   OUTPUT, ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID,
               @cPackData1   OUTPUT, @cPackData2  OUTPUT, @cPackData3  OUTPUT,
               @cPackLabel1  OUTPUT, @cPackLabel2 OUTPUT, @cPackLabel3 OUTPUT,
               @cPackAttr1   OUTPUT, @cPackAttr2  OUTPUT, @cPackAttr3  OUTPUT,
               @cDataCapture OUTPUT, @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
         ELSE
         BEGIN
            -- Setup is non SP
            SET @cDataCapture = @cDataCaptureSP
            SET @cPackData1 = ''
            SET @cPackData2 = ''
            SET @cPackData3 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- PackData1
         END

         -- Capture data
         IF @cDataCapture = '1'
         BEGIN
            -- SKU need data capture
            IF @cSKUDataCapture IN ('1', '3') -- 1=Inbound and outbound, 3=outbound only
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cPackLabel1
               SET @cOutField02 = @cPackData1
               SET @cOutField03 = @cPackLabel2
               SET @cOutField04 = @cPackData2
               SET @cOutField05 = @cPackLabel3
               SET @cOutField06 = @cPackData3

               --(yeekung01)
               SET @cFieldAttr02 = @cPackAttr1
               SET @cFieldAttr04 = @cPackAttr2
               SET @cFieldAttr06 = @cPackAttr3

               -- Go to capture data screen
               SET @nFromScn = @nScn
               SET @nFromStep = @nStep

               SET @nScn = @nScn + 7
               SET @nStep = @nStep + 7

               GOTO Quit
            END
         END
      END

      -- Serial No
      IF @cSerialNoCapture IN ('1', '3')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDescr, @nQTY, 'CHECK', 'PICKSLIP', @cPickSlipNo,
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
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '3'

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            -- Go to Serial No screen
            SET @nScn = 4831
            SET @nStep = @nStep + 6

            -- Flow thru
            IF @cSerialNo <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '9') -- Serial no screen
               BEGIN
                  -- rdt_SerialNo will read from rdtMboRec directly
                  UPDATE rdt.rdtMobRec SET 
                     V_Max = @cSerialNo, 
                     EditDate = GETDATE()
                  WHERE Mobile = @nMobile
                  
                  SET @nInputKey='1'
                  GOTO Step_9
               END
            END

            GOTO Quit
         END
      END

      -- Confirm
      EXEC RDT.rdt_Pack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickSlipNo    = @cPickSlipNo
         ,@cFromDropID    = @cFromDropID
         ,@cSKU           = @cSKU
         ,@nQTY           = @nQTY
         ,@cUCCNo         = '' -- @cUCCNo
         ,@cSerialNo      = '' -- @cSerialNo
         ,@nSerialQTY     = 0  -- @nSerialQTY
         ,@cPackDtlRefNo  = @cPackDtlRefNo
         ,@cPackDtlRefNo2 = @cPackDtlRefNo2
         ,@cPackDtlUPC    = @cPackDtlUPC
         ,@cPackDtlDropID = @cPackDtlDropID
         ,@nCartonNo      = @nCartonNo    OUTPUT
         ,@cLabelNo       = @cLabelNo     OUTPUT
         ,@nErrNo         = @nErrNo       OUTPUT
         ,@cErrMsg        = @cErrMsg      OUTPUT
         ,@nBulkSNO       = 0
         ,@nBulkSNOQTY    = 0
         ,@cPackData1     = @cPackData1
         ,@cPackData2     = @cPackData2
         ,@cPackData3     = @cPackData3
      IF @nErrNo <> 0
         GOTO Quit

      -- Calc carton info
      SELECT
         @nCartonSKU = COUNT( 1), --DISTINCT PD.SKU
         @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo

      -- Get carton info
      DECLARE @cPD_DropID NVARCHAR(20)
      DECLARE @cPD_RefNo  NVARCHAR(20)
      DECLARE @cPD_RefNo2 NVARCHAR(30)
      SELECT
         @cLabelLine = PD.LabelLine,
         @nPackedQTY = PD.QTY,
         @cPD_DropID = PD.DropID,
         @cPD_RefNo = PD.RefNo,
         @cPD_RefNo2 = PD.RefNo2
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND SKU = @cSKU

      -- Get custom carton no
      SELECT
         @cCustomNo =
            CASE @cCustomCartonNo
               WHEN '1' THEN LEFT( @cPD_DropID, 5)
               WHEN '2' THEN LEFT( @cPD_RefNo, 5)
               WHEN '3' THEN LEFT( @cPD_RefNo2, 5)
               ELSE CAST( @nCartonNo AS NVARCHAR(5))
            END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cFromDropID',     @cFromDropID),
               ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
               ('@cLabelNo',        @cLabelNo),
               ('@cSKU',            @cSKU),
               ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
               ('@cUCCNo',          @cUCCNo),
               ('@cCartonType',     @cCartonType),
               ('@cCube',           @cCube),
               ('@cWeight',         @cWeight),
               ('@cRefNo',          @cRefNo),
               ('@cSerialNo',       @cSerialNo),
               ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
               ('@cOption',         @cOption),
               ('@cPackDtlRefNo',   @cPackDtlRefNo),
               ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
               ('@cPackDtlUPC',     @cPackDtlUPC),
               ('@cPackDtlDropID',  @cPackDtlDropID),
               ('@cPackData1',      @cPackData1),
               ('@cPackData2',      @cPackData2),
               ('@cPackData3',      @cPackData3)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 3
               SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = RTRIM( @cCustomNo)
      SET @cOutField02 = CAST( CAST( @cLabelLine AS INT) AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
      SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
      SET @cOutField08 = CASE WHEN @cDisableQTYField = '1' THEN @cQTY ELSE @cDefaultQTY END --(cc01)
      SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
      SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
      SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
      SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField14 = '' -- PQTY
      --SET @cOutField15 = '' -- ExtendedInfo
      SET @nEnter = 0      --(cc01)  

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @cFieldAttr14 = 'O' -- @nPQTY
      END
      ELSE
      BEGIN
         SET @cFieldAttr14 = '' -- @nPQTY
      END

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 -- V6.4 By JCH507
            BEGIN
               GOTO  Quit
            END
         END
      END

      -- Repack without add SKU QTY
      IF @nCartonNo > 0 AND @nCartonQTY = 0
      BEGIN
         -- Handling transaction
         DECLARE @nTranCount INT
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_Pack -- For rollback or commit only our own transaction

         -- PackInfo
         IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
         BEGIN
            DELETE PackInfo WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_Pack
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               SET @nErrNo = 100225
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PKInfoFail
               GOTO Quit
            END
         END

         -- PackDetail (delete the booking record, 1 line with blank SKU)
         IF EXISTS( SELECT 1 FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
         BEGIN
            DELETE PackDetail WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_Pack
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               SET @nErrNo = 100226
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PAKDtlFail
               GOTO Quit
            END
         END

         COMMIT TRAN rdtfnc_Pack
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
      END

      -- Packed
      IF @nCartonQTY > 0
      BEGIN
         -- Custom PackInfo field setup
         SET @cPackInfo = ''
         IF @cCapturePackInfoSP <> ''
         BEGIN
            -- Custom SP to get PackInfo setup
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @nCartonNo, @cLabelNo, ' +
                  ' @nErrNo      OUTPUT, ' +
                  ' @cErrMsg     OUTPUT, ' +
                  ' @cPackInfo   OUTPUT, ' +
                  ' @cWeight     OUTPUT, ' +
                  ' @cCube       OUTPUT, ' +
                  ' @cRefNo      OUTPUT, ' +
                  ' @cCartonType OUTPUT'
               SET @cSQLParam =
                  '@nMobile     INT,           ' +
                  '@nFunc       INT,           ' +
                  '@cLangCode   NVARCHAR( 3),  ' +
                  '@nStep       INT,           ' +
                  '@nInputKey   INT,           ' +
                  '@cFacility   NVARCHAR( 5),  ' +
                  '@cStorerKey  NVARCHAR( 15), ' +
                  '@cPickSlipNo NVARCHAR( 10), ' +
                  '@cFromDropID NVARCHAR( 20), ' +
                  '@nCartonNo   INT,           ' +
                  '@cLabelNo    NVARCHAR( 20), ' +
                  '@nErrNo      INT           OUTPUT, ' +
                  '@cErrMsg     NVARCHAR( 20) OUTPUT, ' +
                  '@cPackInfo   NVARCHAR( 3)  OUTPUT, ' +
                  '@cWeight     NVARCHAR( 10) OUTPUT, ' +
                  '@cCube       NVARCHAR( 10) OUTPUT, ' +
                  '@cRefNo      NVARCHAR( 20) OUTPUT, ' +
                  '@cCartonType NVARCHAR( 10) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @nCartonNo, @cLabelNo,
                  @nErrNo      OUTPUT,
                  @cErrMsg     OUTPUT,
                  @cPackInfo   OUTPUT,
                  @cWeight     OUTPUT,
                  @cCube       OUTPUT,
                  @cRefNo      OUTPUT,
                  @cCartonType OUTPUT
            END
            ELSE
               -- Setup is non SP
               SET @cPackInfo = @cCapturePackInfoSP
         END

         -- Capture pack info
         IF @cPackInfo <> ''
         BEGIN
            -- Get PackInfo
            SET @cCartonType = ''
            SET @cWeight = ''
            SET @cCube = ''
            SET @cRefNo = ''
            SET @cLength = ''
            SET @cWidth = ''
            SET @cHeight = ''

            SELECT
               @cCartonType = ISNULL( CartonType, ''),
               @cWeight = rdt.rdtFormatFloat( Weight),
               @cCube = rdt.rdtFormatFloat( [Cube]),
               @cRefNo = RefNo,
               @cLength = rdt.rdtFormatFloat( [Length]),
               @cWidth = rdt.rdtFormatFloat( [Width]),
               @cHeight = rdt.rdtFormatFloat( [Height])
            FROM dbo.PackInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo  = @nCartonNo

            -- Prepare LOC screen var
            SET @cOutField01 = CASE WHEN ISNULL(@cCartonType ,'') ='' AND ISNULL(@cDefaultcartontype,'')<>''  THEN @cDefaultcartontype ELSE @cCartonType end
            SET @cOutField02 = @cWeight           --WinSern
            SET @cOutField03 = @cCube             --WinSern
            SET @cOutField04 = @cRefNo
            SET @cOutField05 = @cLength
            SET @cOutField06 = @cWidth
            SET @cOutField07 = @cHeight

            -- Enable disable field
            SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr05 = CASE WHEN CHARINDEX( 'L', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr06 = CASE WHEN CHARINDEX( 'D', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'H', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr08 = '' -- QTY

            -- Position cursor
            IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
            IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
            IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
            IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
            IF @cFieldAttr05 = '' AND @cOutField05 = '0' EXEC rdt.rdtSetFocusField @nMobile, 5 ELSE
            IF @cFieldAttr06 = '' AND @cOutField06 = '0' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
            IF @cFieldAttr07 = '' AND @cOutField07 = '0' EXEC rdt.rdtSetFocusField @nMobile, 7 

            --Reset 
            SET @nEnter = 0 --(JHU151)  

            -- Go to next screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '4') -- PackInfo screen
            BEGIN
               SET @cInField01 = CASE WHEN ISNULL(@cCartonType ,'') ='' AND ISNULL(@cDefaultcartontype,'')<>''  THEN @cDefaultcartontype ELSE @cCartonType end
               SET @nInputKey='1'
               GOTO Step_4
            END

            GOTO Quit
         END

         -- Print label
         IF @cShipLabel <> '' OR @cCartonManifest <> ''
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cDefaultPrintLabelOption --Option

            -- Enable field
            SET @cFieldAttr08 = '' -- QTY
            
            --Reset 
            SET @nEnter = 0 --(JHU151) 

            -- Go to next screen
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            -- Flow thru
            IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '5') -- Print label screen
            BEGIN
               SET @cInField01 = @cDefaultPrintLabelOption --Option
               SET @nInputKey = 1 -- ENTER
               GOTO Step_5
            END
            ELSE
               GOTO Quit
         END
      END

      IF @nCartonNo = 0 OR @nCartonQTY = 0
         SET @cType = 'NEXT'
      ELSE
         SET @cType = 'CURRENT'

      -- Get task
      EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType
         ,@cPickSlipNo
         ,@cFromDropID
         ,@cPackDtlDropID
         ,@nCartonNo    OUTPUT
         ,@cLabelNo     OUTPUT
         ,@cCustomNo    OUTPUT
         ,@cCustomID    OUTPUT
         ,@nCartonSKU   OUTPUT
         ,@nCartonQTY   OUTPUT
         ,@nTotalCarton OUTPUT
         ,@nTotalPick   OUTPUT
         ,@nTotalPack   OUTPUT
         ,@nTotalShort  OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  -- ZG02
      SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  -- ZG02
      SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8))  -- ZG02
      SET @cOutField05 = RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
      SET @cOutField06 = @cCustomID
      SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
      SET @cOutField09 = @cDefaultOption -- Option

      -- Enable field
      SET @cFieldAttr08 = '' -- QTY

      SET @cOutField15 = ''

      --Reset 
      SET @nEnter = 0 --(JHU151) 

      -- Go to statistic screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

   END
   
   --(JHU151)      
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         SET @nAction = 0 --Jump
         SET @cJumpType = 'Back' --Jump
         GOTO Step_99
      END
   END
   
   GOTO Quit
   
   Step_3_Fail:
   BEGIN
      IF rdt.RDTGetConfig( @nFunc, 'ShowErrMsgInNewScn', @cStorerkey) = '1'
      BEGIN
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
      END

      SET @cOutField03 = '' -- SKU
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      SET @cOutField08=@cDefaultQTY --(moo01)
      SET @cInField08=''
   END
   GOTO Quit

   Step_3_QTY_Fail:
   BEGIN
      IF rdt.RDTGetConfig( @nFunc, 'ShowErrMsgInNewScn', @cStorerkey) = '1'
      BEGIN
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
      END

      SET @cOutField08 = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE '' END -- PQTY
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE '' END -- MQTY
   END
   GOTO Quit

END
GOTO Quit


/********************************************************************************
Scn = 4653. Capture pack info
   Carton Type (field01, input)
   Cube        (field02, input)
   Weight      (field03, input)
   RefNo       (field04, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cChkCartonType NVARCHAR( 10)
      DECLARE @cChkCartonTypeBarcode NVARCHAR( 30) --(v7.5)

      -- (james02)
      -- Screen mapping
      SET @cChkCartonTypeBarcode = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END --(v7.5)
      SET @cChkCartonType  = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cWeight         = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cCube           = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cRefNo          = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cLength         = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END
      SET @cWidth          = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END
      SET @cHeight         = CASE WHEN @cFieldAttr07 = '' THEN @cInField07 ELSE @cOutField07 END

      -- Carton type
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check blank
         IF @cChkCartonType = ''
         BEGIN
            SET @nErrNo = 100210
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit 
         END

         -- Get default cube
         DECLARE @nDefaultCube FLOAT
         SELECT @nDefaultCube = [Cube]
         FROM Cartonization WITH (NOLOCK)
            INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
         WHERE Storer.StorerKey = @cStorerKey
            AND Cartonization.CartonType = @cChkCartonType

         --(v7.5) start
         SET @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SELECT
               @cChkCartonType = CartonType,
               @nDefaultCube = [Cube]
            FROM Cartonization WITH (NOLOCK)
               INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
            WHERE Storer.StorerKey = @cStorerKey
               AND Cartonization.Barcode = @cChkCartonTypeBarcode

            SET @nRowCount = @@ROWCOUNT
         END
         --(v7.5) end

         -- Check if valid
         IF @nRowCount = 0 --(v7.5)
         BEGIN
            SET @nErrNo = 100211
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CTN TYPE
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Different carton type scanned
         IF @cChkCartonType <> @cCartonType
         BEGIN
            SET @cCartonType = @cChkCartonType
            SET @cCube = rdt.rdtFormatFloat( @nDefaultCube)
            SET @cWeight = ''

            SET @cOutField01 = @cCartonType
            SET @cOutField02 = @cWeight         --WinSern
            SET @cOutField03 = @cCube           --WinSern
         END
      END

      -- Weight
      IF @cFieldAttr02 = ''
      BEGIN
         -- Check blank
         IF @cWeight = ''
         BEGIN
            SET @nErrNo = 100214
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check format    --(cc04)
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Weight', @cWeight) = 0
         BEGIN
            SET @nErrNo = 100246
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check weight valid
         IF @cAllowWeightZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 100215
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField02 = @cWeight
      END

      -- Default weight
      ELSE IF @cDefaultWeight IN ('2', '3')
      BEGIN
         -- Weight (SKU only)
         DECLARE @nWeight FLOAT
         SELECT @nWeight = ISNULL( SUM( SKU.STDGrossWGT * PD.QTY), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.CartonNo = @nCartonNo

         -- Weight (SKU + carton)
         IF @cDefaultWeight = '3'
         BEGIN
            -- Get carton type info
            DECLARE @nCartonWeight FLOAT
            SELECT @nCartonWeight = CartonWeight
            FROM Cartonization C WITH (NOLOCK)
               JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
            WHERE S.StorerKey = @cStorerKey
               AND C.CartonType = @cCartonType

            SET @nWeight = @nWeight + @nCartonWeight
         END
         SET @cWeight = rdt.rdtFormatFloat( @nWeight)
      END

      -- Cube
      IF @cFieldAttr03 = ''
      BEGIN
         -- Check blank
         IF @cCube = ''
         BEGIN
            SET @nErrNo = 100212
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cube
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         -- Check cube valid
         IF @cAllowCubeZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 100213
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube
            EXEC rdt.rdtSetFocusField @nMobile, 3
            SET @cOutField03 = ''
        GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField03 = @cCube
      END

      -- RefNo    --(cc01)
      IF @cFieldAttr04 = ''
      BEGIN
         -- Check blank
         IF @cRefNo = ''
         BEGIN
            SET @nErrNo = 100239
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need RefNo
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Quit
         END
      END

      -- Length
      --IF @cFieldAttr04 = ''
      IF @cFieldAttr05 = ''   -- ZG03
      BEGIN
         -- Check blank
         IF @cLength = ''
         BEGIN
            SET @nErrNo = 100240
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Length
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Quit
         END

         -- Check cube valid
         IF @cAllowLengthZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cLength, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cLength, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 100241
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Length
            EXEC rdt.rdtSetFocusField @nMobile, 4
            SET @cOutField04 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField04 = @cLength
      END

      -- Width
      --IF @cFieldAttr05 = ''
      IF @cFieldAttr06 = ''   -- ZG03
      BEGIN
         -- Check blank
         IF @cWidth = ''
         BEGIN
            SET @nErrNo = 100242
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Width
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Quit
         END

         -- Check cube valid
         IF @cAllowWidthZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 100243
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Width
            EXEC rdt.rdtSetFocusField @nMobile, 5
            SET @cOutField05 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField05 = @cWidth
      END

      -- Height
      --IF @cFieldAttr06 = ''
      IF @cFieldAttr07 = ''   -- ZG03
      BEGIN
         -- Check blank
         IF @cHeight = ''
         BEGIN
            SET @nErrNo = 100244
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Height
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Quit
         END

         -- Check cube valid
         IF @cAllowHeightZero = '1'
            SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 20)
         ELSE
            SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 100245
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Height
            EXEC rdt.rdtSetFocusField @nMobile, 6
            SET @cOutField06 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField06 = @cHeight
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      DECLARE @fCube FLOAT
      DECLARE @fWeight FLOAT
      DECLARE @fCartonQty FLOAT --(cc02)
      SET @fCube = CAST( @cCube AS FLOAT)
      SET @fWeight = CAST( @cWeight AS FLOAT)

      SELECT @fCartonQty = SUM(qty) FROM packDetail WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo AND cartonNo = @nCartonNo AND storerKey = @cStorerKey --(cc02)

      -- PackInfo
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType, RefNo, Length, Width, Height)
         VALUES (@cPickSlipNo, @nCartonNo, @fCartonQty, @fWeight, @fCube, @cCartonType, @cRefNo, @cLength, @cWidth, @cHeight)  --(cc02)/(james20)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100216
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo SET
            CartonType = @cCartonType,
            Weight = @fWeight,
            [Cube] = @fCube,
            RefNo = @cRefNo,
            Length = @cLength,   -- (james20)
            Width = @cWidth,     -- (james20)
            Height = @cHeight    -- (james20)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100217
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
            GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Print label
      IF @cShipLabel <> '' OR @cCartonManifest <> ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cDefaultPrintLabelOption --Option

         -- Enable field
         SET @cFieldAttr01 = '' -- CartonType
         SET @cFieldAttr02 = '' -- Weight
         SET @cFieldAttr03 = '' -- Cube
         SET @cFieldAttr04 = '' -- RefNo

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         IF @cUCCNo = ''
         BEGIN
            -- Get statistics
            EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
               ,@cPickSlipNo
               ,@cFromDropID
               ,@cPackDtlDropID
               ,@nCartonNo    OUTPUT
               ,@cLabelNo     OUTPUT
               ,@cCustomNo    OUTPUT
               ,@cCustomID    OUTPUT
               ,@nCartonSKU   OUTPUT
               ,@nCartonQTY   OUTPUT
               ,@nTotalCarton OUTPUT
               ,@nTotalPick   OUTPUT
               ,@nTotalPack   OUTPUT
               ,@nTotalShort  OUTPUT
               ,@nErrNo       OUTPUT
               ,@cErrMsg      OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Prepare current screen var
            SET @cOutField01 = @cPickSlipNo
            SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  -- ZG02
            SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  -- ZG02
            SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8))  -- ZG02
            SET @cOutField05 = RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
            SET @cOutField06 = @cCustomID
            SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
            SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
            SET @cOutField09 = @cDefaultOption -- Option

            -- Enable field
            SET @cFieldAttr01 = '' -- CartonType
            SET @cFieldAttr02 = '' -- Weight
            SET @cFieldAttr03 = '' -- Cube
            SET @cFieldAttr04 = '' -- RefNo

            IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '2') -- Statistic screen
            BEGIN
               SET @nInputKey = '0' -- ESC
               SET @nScn = @nScn - 2
               SET @nStep = @nStep - 2
               GOTO Step_2
            END

            -- Go to statistic screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2            
         END
         ELSE
         BEGIN
            -- Get total UCC
            SELECT @nTotalUCC = COUNT(1) FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND UCCNo <> ''

            -- Prepare current screen var
            SET @cOutField01 = '' -- UCCNo
            SET @cOutField02 = @cUCCCounter
            SET @cOutField03 = CAST( @nTotalUCC AS NVARCHAR(5))

            -- Go to UCC screen
            SET @nScn = @nScn + 4
            SET @nStep = @nStep + 4
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr01 = '' -- CartonType
      SET @cFieldAttr02 = '' -- Weight
      SET @cFieldAttr03 = '' -- Cube
      SET @cFieldAttr04 = '' -- RefNo

      IF @cUCCNo = ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = RTRIM( @cCustomNo)
         SET @cOutField02 = CAST( CAST( @cLabelLine AS INT) AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = @cSKU
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
         SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
         SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
         SET @cOutField08 = '' -- QTY
         SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
         SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
         SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
         SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
         SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
         SET @cOutField14 = '' -- PQTY
         SET @cOutField15 = '' -- ExtendedInfo

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @cFieldAttr14 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @cFieldAttr14 = '' -- @nPQTY
         END

         SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         -- Go to SKU QTY screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         -- Get total UCC
         SELECT @nTotalUCC = COUNT(1) FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND UCCNo <> ''

         -- Prepare current screen var
         SET @cOutField01 = '' -- UCCNo
         SET @cOutField02 = @cUCCCounter
         SET @cOutField03 = CAST( @nTotalUCC AS NVARCHAR(5))

         -- Go to UCC screen
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4
      END
   END

   
   --(JHU151)
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         SET @nAction = 0 --Jump
         SET @cJumpType = 'Back' --Jump
         GOTO Step_99
      END
   END

   Step_4_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cFromDropID',     @cFromDropID),
               ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
               ('@cLabelNo',        @cLabelNo),
               ('@cSKU',            @cSKU),
               ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
               ('@cUCCNo',          @cUCCNo),
               ('@cCartonType',     @cCartonType),
               ('@cCube',           @cCube),
               ('@cWeight',         @cWeight),
               ('@cRefNo',          @cRefNo),
               ('@cSerialNo',       @cSerialNo),
               ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
               ('@cOption',         @cOption),
               ('@cPackDtlRefNo',   @cPackDtlRefNo),
               ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
               ('@cPackDtlUPC',     @cPackDtlUPC),
               ('@cPackDtlDropID',  @cPackDtlDropID),
               ('@cPackData1',      @cPackData1),
               ('@cPackData2',      @cPackData2),
               ('@cPackData3',      @cPackData3)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 3
               SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Flow thru
      IF @nStep = 5 -- Print label screen
      BEGIN
         IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '5') -- Print label screen
         BEGIN
            SET @cInField01 = @cDefaultPrintLabelOption --Option
            SET @nInputKey = 1 -- ENTER
            GOTO Step_5
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Scn = 4654. Message. Print label?
   Option (field01, inputf)
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
         SET @nErrNo = 100218
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 100219
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         -- Ship label
         IF @cShipLabel <> ''
         BEGIN
            IF @cShipLabel = 'CstLabelSP'
            BEGIN
               SET @cCstLabelSP = rdt.RDTGetConfig( @nFunc, 'CstLabelSP', @cStorerKey)
               IF @cCstLabelSP = '0'
                  SET @cCstLabelSP = ''
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCstLabelSP AND type = 'P')  --Customize Print Label
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cCstLabelSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                     ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                     ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile         INT,           ' +
                     '@nFunc           INT,           ' +
                     '@cLangCode       NVARCHAR( 3),  ' +
                     '@nStep           INT,           ' +
                     '@nInputKey       INT,           ' +
                     '@cFacility       NVARCHAR( 5),  ' +
                     '@cStorerKey      NVARCHAR( 15), ' +
                     '@cPickSlipNo     NVARCHAR( 10), ' +
                     '@cFromDropID     NVARCHAR( 20), ' +
                     '@nCartonNo       INT,           ' +
                     '@cLabelNo        NVARCHAR( 20), ' +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@nQTY            INT,           ' +
                     '@cUCCNo          NVARCHAR( 20), ' +
                     '@cCartonType     NVARCHAR( 10), ' +
                     '@cCube           NVARCHAR( 10), ' +
                     '@cWeight         NVARCHAR( 10), ' +
                     '@cRefNo          NVARCHAR( 20), ' +
                     '@cSerialNo       NVARCHAR( 30), ' +
                     '@nSerialQTY      INT,           ' +
                     '@cOption         NVARCHAR( 1),  ' +
                     '@cPackDtlRefNo   NVARCHAR( 20), ' +
                     '@cPackDtlRefNo2  NVARCHAR( 20), ' +
                     '@cPackDtlUPC     NVARCHAR( 30), ' +
                     '@cPackDtlDropID  NVARCHAR( 20), ' +
                     '@cPackData1      NVARCHAR( 30), ' +
                     '@cPackData2      NVARCHAR( 30), ' +
                     '@cPackData3      NVARCHAR( 30), ' +
                     '@nErrNo          INT            OUTPUT, ' +
                     '@cErrMsg         NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                     @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                     @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
            ELSE BEGIN  --Standard Print
               -- Common params
               DECLARE @tShipLabel AS VariableTable
               INSERT INTO @tShipLabel (Variable, Value) VALUES
                  ( '@cStorerKey',     @cStorerKey),
                  ( '@cPickSlipNo',    @cPickSlipNo),
                  ( '@cFromDropID',    @cFromDropID),
                  ( '@cPackDtlDropID', @cPackDtlDropID),
                  ( '@cLabelNo',       @cLabelNo),
                  ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                  @cShipLabel, -- Report type
                  @tShipLabel, -- Report params
                  'rdtfnc_Pack',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
         END

         -- Carton manifest
         IF @cCartonManifest <> ''
         BEGIN
            -- Common params
            DECLARE @tCartonManifest AS VariableTable
            INSERT INTO @tCartonManifest (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPickSlipNo',    @cPickSlipNo),
               ( '@cFromDropID',    @cFromDropID),
               ( '@cPackDtlDropID', @cPackDtlDropID),
               ( '@cLabelNo',       @cLabelNo),
               ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cCartonManifest, -- Report type
               @tCartonManifest, -- Report params
               'rdtfnc_Pack',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cUCCNo = ''
      BEGIN
         -- Get statistics
         EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@nCartonNo    OUTPUT
            ,@cLabelNo     OUTPUT
            ,@cCustomNo    OUTPUT
            ,@cCustomID    OUTPUT
            ,@nCartonSKU   OUTPUT
            ,@nCartonQTY   OUTPUT
            ,@nTotalCarton OUTPUT
            ,@nTotalPick   OUTPUT
            ,@nTotalPack   OUTPUT
            ,@nTotalShort  OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare current screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  -- ZG02
         SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  -- ZG02
         SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8))  -- ZG02
         SET @cOutField05 = RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
         SET @cOutField06 = @cCustomID
         SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = @cDefaultOption -- Option
         SET @cOutField15 = ''

         -- Go to statistic screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3

      END
      ELSE
      BEGIN
         -- Get total UCC
         SELECT @nTotalUCC = COUNT(1) FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND UCCNo <> ''

         -- Prepare current screen var
         SET @cOutField01 = '' -- UCCNo
         SET @cOutField02 = @cUCCCounter
         SET @cOutField03 = CAST( @nTotalUCC AS NVARCHAR(5))

         -- Go to UCC screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Capture pack info
      IF @cPackInfo <> ''
      BEGIN
         -- Prepare LOC screen var
         SET @cOutField01 = CASE WHEN ISNULL(@cCartonType ,'') ='' AND ISNULL(@cDefaultcartontype,'')<>''  THEN @cDefaultcartontype ELSE @cCartonType end
         --SET @cOutField02 = @cCube          --SY01
         --SET @cOutField03 = @cWeight        --SY01
         SET @cOutField02 = @cWeight          --SY01
         SET @cOutField03 = @cCube            --SY01  
         SET @cOutField04 = @cRefNo

         -- Enable disable field
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr08 = '' -- QTY

         -- Position cursor
         IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
         IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
         IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
         IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4

         -- Go to pack info screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         IF @cUCCNo = ''
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = RTRIM( @cCustomNo)
            SET @cOutField02 = CAST( CAST( @cLabelLine AS INT) AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
            SET @cOutField03 = '' -- SKU
            SET @cOutField04 = @cSKU
            SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
            SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
            SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
            SET @cOutField08 = '' -- QTY
            SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
            SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
            SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
            SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
            SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
            SET @cOutField14 = '' -- PQTY
            SET @cOutField15 = '' -- ExtendedInfo

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @cFieldAttr14 = 'O' -- @nPQTY
            END
            ELSE
            BEGIN
               SET @cFieldAttr14 = '' -- @nPQTY
            END

            -- Enable field
            SET @cFieldAttr01 = '' -- CartonType
            SET @cFieldAttr02 = '' -- Weight
            SET @cFieldAttr03 = '' -- Cube
            SET @cFieldAttr04 = '' -- RefNo
            SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

            -- Go to SKU QTY screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END
         ELSE
         BEGIN
            -- Get total UCC
            SELECT @nTotalUCC = COUNT(1) FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND UCCNo <> ''

            -- Prepare current screen var
            SET @cOutField01 = '' -- UCCNo
            SET @cOutField02 = @cUCCCounter
            SET @cOutField03 = CAST( @nTotalUCC AS NVARCHAR(5))

            -- Go to UCC screen
            SET @nScn = @nScn + 3
            SET @nStep = @nStep + 3
         END
      END
   END

   --(JHU151)
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         SET @nAction = 0 --Jump
         SET @cJumpType = 'Back' --Jump
         GOTO Step_99
      END
   END
END
GOTO Quit


/********************************************************************************
Scn = 4654. Message. Print packing list?
   Option (field01, input)
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
         SET @nErrNo = 100220
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 100221
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         IF @cPackList = 'CstLabelSP'
         BEGIN
            SET @cCstLabelSP = rdt.RDTGetConfig( @nFunc, 'CstLabelSP', @cStorerKey)
            IF @cCstLabelSP = '0'
               SET @cCstLabelSP = ''
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCstLabelSP AND type = 'P')  --Customize Print Label
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cCstLabelSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                  ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                  ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cPickSlipNo     NVARCHAR( 10), ' +
                  '@cFromDropID     NVARCHAR( 20), ' +
                  '@nCartonNo       INT,           ' +
                  '@cLabelNo        NVARCHAR( 20), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQTY            INT,           ' +
                  '@cUCCNo          NVARCHAR( 20), ' +
                  '@cCartonType     NVARCHAR( 10), ' +
                  '@cCube           NVARCHAR( 10), ' +
                  '@cWeight         NVARCHAR( 10), ' +
                  '@cRefNo          NVARCHAR( 20), ' +
                  '@cSerialNo       NVARCHAR( 30), ' +
                  '@nSerialQTY      INT,           ' +
                  '@cOption         NVARCHAR( 1),  ' +
                  '@cPackDtlRefNo   NVARCHAR( 20), ' +
                  '@cPackDtlRefNo2  NVARCHAR( 20), ' +
                  '@cPackDtlUPC     NVARCHAR( 30), ' +
                  '@cPackDtlDropID  NVARCHAR( 20), ' +
                  '@cPackData1      NVARCHAR( 30), ' +
                  '@cPackData2      NVARCHAR( 30), ' +
                  '@cPackData3      NVARCHAR( 30), ' +
                  '@nErrNo          INT            OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                  @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                  @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
         ELSE
         BEGIN                --STANDARD PRINT
            -- Get report param
            DECLARE @tPackList AS VariableTable
            INSERT INTO @tPackList (Variable, Value) VALUES
               ( '@cPickSlipNo',    @cPickSlipNo),
               ( '@cFromDropID',    @cFromDropID),
               ( '@cPackDtlDropID', @cPackDtlDropID)

            -- Print packing list
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cPackList, -- Report type
               @tPackList, -- Report params
               'rdtfnc_Pack',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

         END
      END

      -- Prepare current screen var
      SET @cOutField01 = CASE WHEN @cShowPickSlipNo = '1' THEN @cPickSlipNo ELSE '' END --PickSlipNo (james17)
      SET @cOutField02 = '' -- FromDropID
      SET @cOutField03 = '' --ToDropID

      IF @cFromDropID <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
      ELSE
      BEGIN
         IF @cPackDtlDropID <> ''
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- ToDropID
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
      END

      -- Go to PickSlipNo screen
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get statistics
      EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
         ,@cPickSlipNo
         ,@cFromDropID
         ,@cPackDtlDropID
         ,@nCartonNo    OUTPUT
         ,@cLabelNo     OUTPUT
         ,@cCustomNo    OUTPUT
         ,@cCustomID    OUTPUT
         ,@nCartonSKU   OUTPUT
         ,@nCartonQTY   OUTPUT
         ,@nTotalCarton OUTPUT
         ,@nTotalPick   OUTPUT
         ,@nTotalPack   OUTPUT
         ,@nTotalShort  OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare current screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  -- ZG02
      SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  -- ZG02
      SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8))  -- ZG02
      SET @cOutField05 = RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
      SET @cOutField06 = @cCustomID
      SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
      SET @cOutField09 = @cDefaultOption -- Option

      -- Go to statistic screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
      
   END

   --(JHU151)
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         SET @nAction = 0 --Jump
         SET @cJumpType = 'Back' --Jump for rdt_838ExtScn01
         GOTO Step_99
      END
   END
END
GOTO Quit


/********************************************************************************
Scn = 4656. Confirm repack?
   Option (field02, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField02

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 100222
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 100223
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         -- Get UCC info
         IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo AND UCCNo <> '')
            SET @cType = 'UCC'
         ELSE
            SET @cType = 'SKU'

         EXEC rdt.rdt_Pack_Repack @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType
            ,@cPickSlipNo
            ,@nCartonNo
            ,@cLabelNo
            ,@nErrNo
            ,@cErrMsg
         IF @nErrNo <> 0
            GOTO Quit

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                  ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                  ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cPickSlipNo     NVARCHAR( 10), ' +
                  '@cFromDropID     NVARCHAR( 20), ' +
                  '@nCartonNo       INT,           ' +
                  '@cLabelNo        NVARCHAR( 20), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQTY            INT,           ' +
                  '@cUCCNo          NVARCHAR( 20), ' +
                  '@cCartonType     NVARCHAR( 10), ' +
                  '@cCube           NVARCHAR( 10), ' +
                  '@cWeight         NVARCHAR( 10), ' +
                  '@cRefNo          NVARCHAR( 20), ' +
                  '@cSerialNo       NVARCHAR( 30), ' +
                  '@nSerialQTY      INT,           ' +
                  '@cOption         NVARCHAR( 1),  ' +
                  '@cPackDtlRefNo   NVARCHAR( 20), ' +
                  '@cPackDtlRefNo2  NVARCHAR( 20), ' +
                  '@cPackDtlUPC     NVARCHAR( 30), ' +
                  '@cPackDtlDropID  NVARCHAR( 20), ' +
                  '@cPackData1      NVARCHAR( 30), ' +
                  '@cPackData2      NVARCHAR( 30), ' +
                  '@cPackData3      NVARCHAR( 30), ' +
                  '@nErrNo          INT            OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                  @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                  @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

            END
         END

         IF @cType = 'SKU'
         BEGIN
            -- SET @nCartonNo = 0  -- Retain original CartonNo
            -- SET @cLabelNo = ''
            SET @cSKU = ''
            SET @nPackedQTY = 0
            SET @nCartonSKU = 0
            SET @nCartonQTY = 0

            -- Prepare next screen var
            SET @cOutField01 = RTRIM( @cCustomNo)
            SET @cOutField02 = '0/0'
            SET @cOutField03 = ''  -- SKU
            SET @cOutField04 = ''  -- SKU
            SET @cOutField05 = ''  -- Desc 1
            SET @cOutField06 = ''  -- Desc 2
            SET @cOutField07 = '0' -- Packed
            SET @cOutField08 = ''  -- QTY
            SET @cOutField09 = '0' -- CartonQTY
            SET @cOutField15 = ''  -- ExtendedInfo

            -- Enable field
            SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

            EXEC rdt.rdtSetFocusField @nMobile, 3  -- SKU

            -- Go to SKU QTY screen
            SET @nScn = @nScn - 4
            SET @nStep = @nStep - 4

            GOTO Step_7_Quit
         END
      END
   END

   -- Get statistics
   EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
      ,@cPickSlipNo
      ,@cFromDropID
      ,@cPackDtlDropID
      ,@nCartonNo    OUTPUT
      ,@cLabelNo     OUTPUT
      ,@cCustomNo    OUTPUT
      ,@cCustomID    OUTPUT
      ,@nCartonSKU   OUTPUT
      ,@nCartonQTY   OUTPUT
      ,@nTotalCarton OUTPUT
      ,@nTotalPick   OUTPUT
      ,@nTotalPack   OUTPUT
      ,@nTotalShort  OUTPUT
      ,@nErrNo       OUTPUT
      ,@cErrMsg      OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

   -- Prepare current screen var
   SET @cOutField01 = @cPickSlipNo
   SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  -- ZG02
   SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  -- ZG02
   SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8))  -- ZG02
   SET @cOutField05 = RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
   SET @cOutField06 = @cCustomID
   SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
   SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
   SET @cOutField09 = @cDefaultOption -- Option

   -- Go to statistic screen
   SET @nScn = @nScn - 5
   SET @nStep = @nStep - 5

   --(JHU151)
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         SET @nAction = 0 --Jump
         SET @cJumpType = 'Back' --Jump
         GOTO Step_99
      END
   END


Step_7_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         INSERT INTO @tVar (Variable, Value) VALUES
            ('@cPickSlipNo',     @cPickSlipNo),
            ('@cFromDropID',     @cFromDropID),
            ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
            ('@cLabelNo',        @cLabelNo),
            ('@cSKU',            @cSKU),
            ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
            ('@cUCCNo',          @cUCCNo),
            ('@cCartonType',     @cCartonType),
            ('@cCube',           @cCube),
            ('@cWeight',         @cWeight),
            ('@cRefNo',          @cRefNo),
            ('@cSerialNo',       @cSerialNo),
            ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
            ('@cOption',         @cOption),
            ('@cPackDtlRefNo',   @cPackDtlRefNo),
            ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
            ('@cPackDtlUPC',     @cPackDtlUPC),
            ('@cPackDtlDropID',  @cPackDtlDropID),
            ('@cPackData1',      @cPackData1),
            ('@cPackData2',      @cPackData2),
            ('@cPackData3',      @cPackData3)

         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @tVar           VariableTable READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
            ' @nErrNo         INT           OUTPUT,   ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 7, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         IF @nStep = 3
            SET @cOutField15 = @cExtendedInfo
      END
   END
END
GOTO Quit


/********************************************************************************
Scn = 4657. UCC
   UCC   (field01, input)
   SKU   (field02)
   Desc1 (field03)
   Desc2 (field04)
   QTY   (field05)
   CNT   (field06)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCCNo = @cInField01
      SET @cBarcode = @cInField01
      SET @cBarcode2 = ''

      -- Validate blank
      IF @cUCCNo = ''
      BEGIN
         SET @nErrNo = 100220
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCNo required
         GOTO Quit
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUCCNo  = @cUCCNo      OUTPUT,
               @nErrNo  = @nErrNo      OUTPUT,
               @cErrMsg = @cErrMsg     OUTPUT,
               @cType   = 'UCCNo'

               IF @nErrNo <> 0
                  GOTO Quit
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode, @cBarcode2, ' +
               ' @cSKU OUTPUT, @nQTY OUTPUT, @cPackDtlRefNo OUTPUT, @cPackDtlRefNo2 OUTPUT, @cPackDtlUPC OUTPUT, @cPackDtlDropID OUTPUT, @cSerialNo OUTPUT, ' +
               ' @cFromDropIDDecode OUTPUT, @cToDropIDDecode OUTPUT, @cUCCNo OUTPUT, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile           INT,           ' +
               ' @nFunc             INT,           ' +
               ' @cLangCode         NVARCHAR( 3),  ' +
               ' @nStep             INT,           ' +
               ' @nInputKey         INT,           ' +
               ' @cFacility         NVARCHAR( 5),  ' +
               ' @cStorerKey        NVARCHAR( 15), ' +
               ' @cPickSlipNo       NVARCHAR( 10), ' +
               ' @cFromDropID       NVARCHAR( 20), ' +
               ' @cBarcode          NVARCHAR( 60), ' +
               ' @cBarcode2         NVARCHAR( 60), ' +
               ' @cSKU              NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY              INT            OUTPUT, ' +
               ' @cPackDtlRefNo     NVARCHAR( 20)  OUTPUT, ' +
               ' @cPackDtlRefNo2    NVARCHAR( 20)  OUTPUT, ' +
               ' @cPackDtlUPC       NVARCHAR( 30)  OUTPUT, ' +
               ' @cPackDtlDropID    NVARCHAR( 20)  OUTPUT, ' +
               ' @cSerialNo         NVARCHAR( 30)  OUTPUT, ' +
               ' @cFromDropIDDecode NVARCHAR( 30)  OUTPUT, ' +
               ' @cToDropIDDecode   NVARCHAR( 30)  OUTPUT, ' +
               ' @cUCCNo            NVARCHAR( 30)  OUTPUT, ' +
               ' @nErrNo            INT            OUTPUT, ' +
               ' @cErrMsg           NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode, @cBarcode2,
               @cUPC OUTPUT, @nQTY OUTPUT, @cPackDtlRefNo OUTPUT, @cPackDtlRefNo2 OUTPUT, @cPackDtlUPC OUTPUT, @cPackDtlDropID_Decode OUTPUT, @cSerialNo OUTPUT,
               @cFromDropIDDecode OUTPUT, @cToDropIDDecode OUTPUT, @cUCCNo OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- UCC scanned
      IF EXISTS(
         SELECT 1 FROM PackInfo I (NOLOCK)
            JOIN PACKDETAIL D (NOLOCK) ON I.PickSlipNo = D.PickSlipNo AND I.CartonNo = D.CartonNo
         WHERE I.UCCNo = @cUCCNo AND D.storerkey = @cStorerKey)
      BEGIN
         SET @nErrNo = 100230
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC scanned
         GOTO Quit
      END

      -- Get UCC info
      SELECT
         @cSKU = SKU,
         @nQTY = QTY
      FROM UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCCNo
      SET @nRowCount = @@ROWCOUNT

      -- Validate UCC
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 100220
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCCNo
         GOTO Quit
      END

      -- Check SKU
      IF @nRowCount = 1
      BEGIN
         -- Check SKU in PickSlipNo
         EXEC rdt.rdt_Pack_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@cSKU
            ,0 --@nQTY
            ,0 --@nCartonNo
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Check over pack
         EXEC rdt.rdt_Pack_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'QTY'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@cSKU
            ,@nQTY
            ,0 --@nCartonNo
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Check SKU for multi SKU UCC
      IF @nRowCount > 1
      BEGIN
         DECLARE @curUCC CURSOR
         SET @curUCC = CURSOR SCROLL FOR -- Need scroll cursor for 2nd loop in below
            SELECT SKU, QTY
            FROM UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND UCCNo = @cUCCNo
            ORDER BY UCC_RowRef
         OPEN @curUCC
         FETCH NEXT FROM @curUCC INTO @cSKU, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Check SKU in PickSlipNo
            EXEC rdt.rdt_Pack_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
               ,@cPickSlipNo
               ,@cFromDropID
               ,@cPackDtlDropID
               ,@cSKU
               ,0 --@nQTY
               ,0 --@nCartonNo
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Check over pack
            EXEC rdt.rdt_Pack_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'QTY'
               ,@cPickSlipNo
               ,@cFromDropID
               ,@cPackDtlDropID
               ,@cSKU
               ,@nQTY
               ,0 --@nCartonNo
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            FETCH NEXT FROM @curUCC INTO @cSKU, @nQTY
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_Pack -- For rollback or commit only our own transaction

      -- Confirm SKU
      IF @nRowCount = 1
      BEGIN
         -- Confirm
         SET @nCartonNo = 0
         EXEC RDT.rdt_Pack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cPickSlipNo    = @cPickSlipNo
            ,@cFromDropID    = @cFromDropID
            ,@cSKU           = @cSKU
            ,@nQTY           = @nQTY
            ,@cUCCNo         = @cUCCNo
            ,@cSerialNo      = '' -- @cSerialNo
            ,@nSerialQTY     = 0  -- @nSerialQTY
            ,@cPackDtlRefNo  = @cPackDtlRefNo
            ,@cPackDtlRefNo2 = @cPackDtlRefNo2
            ,@cPackDtlUPC    = @cPackDtlUPC
            ,@cPackDtlDropID = @cPackDtlDropID
            ,@nCartonNo      = @nCartonNo    OUTPUT
            ,@cLabelNo       = @cLabelNo     OUTPUT
            ,@nErrNo         = @nErrNo       OUTPUT
            ,@cErrMsg        = @cErrMsg      OUTPUT
            ,@nBulkSNO       = 0
            ,@nBulkSNOQTY    = 0
            ,@cPackData1     = ''
            ,@cPackData2     = ''
            ,@cPackData3     = ''
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_Pack
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END
      END

      -- Confirm SKU for multi SKU UCC
      IF @nRowCount > 1
      BEGIN
         SET @nCartonNo = 0

         FETCH FIRST FROM @curUCC INTO @cSKU, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Confirm
            EXEC RDT.rdt_Pack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cPickSlipNo    = @cPickSlipNo
               ,@cFromDropID    = @cFromDropID
               ,@cSKU           = @cSKU
               ,@nQTY           = @nQTY
               ,@cUCCNo         = @cUCCNo
               ,@cSerialNo      = '' -- @cSerialNo
               ,@nSerialQTY     = 0  -- @nSerialQTY
               ,@cPackDtlRefNo  = @cPackDtlRefNo
               ,@cPackDtlRefNo2 = @cPackDtlRefNo2
               ,@cPackDtlUPC    = @cPackDtlUPC
               ,@cPackDtlDropID = @cPackDtlDropID
               ,@nCartonNo      = @nCartonNo    OUTPUT
               ,@cLabelNo       = @cLabelNo     OUTPUT
               ,@nErrNo         = @nErrNo       OUTPUT
               ,@cErrMsg        = @cErrMsg      OUTPUT
               ,@nBulkSNO       = 0
               ,@nBulkSNOQTY    = 0
               ,@cPackData1     = ''
               ,@cPackData2     = ''
               ,@cPackData3     = ''
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_Pack
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END

            FETCH NEXT FROM @curUCC INTO @cSKU, @nQTY
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_Pack
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN rdtfnc_Pack
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Counter
      SET @cUCCCounter = CAST( @cUCCCounter AS INT) + 1

      -- Custom PackInfo field setup
      SET @cPackInfo = ''
      IF @cCapturePackInfoSP <> ''
      BEGIN
         -- Custom SP to get PackInfo setup
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @nCartonNo, @cLabelNo, ' +
               ' @nErrNo      OUTPUT, ' +
               ' @cErrMsg     OUTPUT, ' +
               ' @cPackInfo   OUTPUT, ' +
               ' @cWeight     OUTPUT, ' +
               ' @cCube       OUTPUT, ' +
               ' @cRefNo      OUTPUT, ' +
               ' @cCartonType OUTPUT'
            SET @cSQLParam =
               '@nMobile     INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode   NVARCHAR( 3),  ' +
               '@nStep       INT,           ' +
               '@nInputKey   INT,           ' +
               '@cFacility   NVARCHAR( 5),  ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cPickSlipNo NVARCHAR( 10), ' +
               '@cFromDropID NVARCHAR( 20), ' +
               '@nCartonNo   INT,           ' +
               '@cLabelNo    NVARCHAR( 20), ' +
               '@nErrNo      INT           OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT, ' +
               '@cPackInfo   NVARCHAR( 3)  OUTPUT, ' +
               '@cWeight     NVARCHAR( 10) OUTPUT, ' +
               '@cCube       NVARCHAR( 10) OUTPUT, ' +
               '@cRefNo      NVARCHAR( 20) OUTPUT, ' +
               '@cCartonType NVARCHAR( 10) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @nCartonNo, @cLabelNo,
               @nErrNo      OUTPUT,
               @cErrMsg     OUTPUT,
               @cPackInfo   OUTPUT,
               @cWeight     OUTPUT,
               @cCube       OUTPUT,
               @cRefNo      OUTPUT,
               @cCartonType OUTPUT
         END
         ELSE
            -- Setup is non SP
            SET @cPackInfo = @cCapturePackInfoSP
      END

      -- Capture pack info
      IF @cPackInfo <> ''
      BEGIN
         -- Get PackInfo
         SET @cCartonType = ''
         SET @cWeight = ''
         SET @cCube = ''
         SET @cRefNo = ''
         SELECT
            @cCartonType = ISNULL( CartonType, ''),
            @cWeight = rdt.rdtFormatFloat( Weight),
            @cCube = rdt.rdtFormatFloat( [Cube]),
            @cRefNo = RefNo
         FROM dbo.PackInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo  = @nCartonNo

         -- Prepare LOC screen var
         SET @cOutField01 = CASE WHEN ISNULL(@cCartonType ,'') ='' AND ISNULL(@cDefaultcartontype,'')<>''  THEN @cDefaultcartontype ELSE @cCartonType end
         --SET @cOutField02 = @cCube          --SY01
         --SET @cOutField03 = @cWeight        --SY01
         SET @cOutField02 = @cWeight          --SY01
         SET @cOutField03 = @cCube            --SY01
         SET @cOutField04 = @cRefNo
         SET @cOutField05 = 0       -- ZG03
         SET @cOutField06 = 0       -- ZG03
         SET @cOutField07 = 0       -- ZG03

         -- Enable disable field
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr05 = CASE WHEN CHARINDEX( 'L', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr06 = CASE WHEN CHARINDEX( 'D', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'H', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr08 = '' -- QTY

         -- Position cursor
         IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
         IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
         IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
         IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4
         IF @cFieldAttr05 = '' AND @cOutField05 = '0'  EXEC rdt.rdtSetFocusField @nMobile, 5 ELSE
         IF @cFieldAttr06 = '' AND @cOutField06 = '0'  EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
         IF @cFieldAttr07 = '' AND @cOutField07 = '0'  EXEC rdt.rdtSetFocusField @nMobile, 7 --ELSE

         -- Go to pack info screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4

         GOTO Quit
      END

      -- Print label
      IF EXISTS( SELECT 1
         FROM rdt.rdtReport WITH (NOLOCK)
         WHERE ReportType = 'SHIPCLABEL'
            AND StorerKey = @cStorerKey
            AND (Function_ID = @nFunc OR Function_ID = 0))
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cDefaultPrintLabelOption --Option

         -- Enable field
         SET @cFieldAttr08 = '' -- QTY

         -- Go to next screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3

         -- Flow thru
         IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '5') -- Print label screen
         BEGIN
            SET @cInField01 = @cDefaultPrintLabelOption --Option
            SET @nInputKey = 1 -- ENTER
            GOTO Step_5
         END
         ELSE
            GOTO Quit
      END

      -- Get total UCC
      SELECT @nTotalUCC = COUNT(1) FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND UCCNo <> ''

      -- Prepare current screen var
      SET @cOutField01 = '' -- UCCNo
      SET @cOutField02 = @cUCCCounter
      SET @cOutField03 = CAST( @nTotalUCC AS NVARCHAR(5))
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get task
      EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXT'
         ,@cPickSlipNo
         ,@cFromDropID
         ,@cPackDtlDropID
         ,@nCartonNo    OUTPUT
         ,@cLabelNo     OUTPUT
         ,@cCustomNo    OUTPUT
         ,@cCustomID    OUTPUT
         ,@nCartonSKU   OUTPUT
         ,@nCartonQTY   OUTPUT
         ,@nTotalCarton OUTPUT
         ,@nTotalPick   OUTPUT
         ,@nTotalPack   OUTPUT
         ,@nTotalShort  OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  -- ZG02
      SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  -- ZG02
      SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8))  -- ZG02
      SET @cOutField05 = RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
      SET @cOutField06 = @cCustomID
      SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
      SET @cOutField09 = @cDefaultOption -- Option

      -- Go to statistic screen
      SET @nScn = @nScn - 6
      SET @nStep = @nStep - 6
            
   END

   --(JHU151)
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         SET @nAction = 0 --Jump
         SET @cJumpType = 'Back' --Jump
         GOTO Step_99
      END
   END
END
GOTO Quit


/********************************************************************************
Step 9. Screen = 4830. Serial No
   SKU            (Field01)
   SKUDesc1       (Field02)
   SKUDesc2       (Field03)
   SerialNo       (Field04, input)
   Scan           (Field05)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF @cExtendedValidateSP <> '' AND @cIsValSerialNo = '0'
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_9_Quit
         END
      END
      -- Update SKU setting
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDescr, @nQTY, 'UPDATE', 'PICKSLIP', @cPickSlipNo,
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
         @nBulkSNO   OUTPUT,  @nBulkSNOQTY OUTPUT,  @cSerialCaptureType = '3'

      IF @nErrNo <> 0
         GOTO Quit

      DECLARE @nPackSerialQTY INT
      IF @nBulkSNO > 0
         SET @nPackSerialQTY = @nBulkSNOQTY
      ELSE IF @cSerialNo <> ''
         SET @nPackSerialQTY = @nSerialQTY
      ELSE
         SET @nPackSerialQTY = @nQTY

      -- Confirm
      EXEC RDT.rdt_Pack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickSlipNo    = @cPickSlipNo
         ,@cFromDropID    = @cFromDropID
         ,@cSKU           = @cSKU
         ,@nQTY           = @nPackSerialQTY
         ,@cUCCNo         = '' -- @cUCCNo
         ,@cSerialNo      = @cSerialNo
         ,@nSerialQTY     = @nSerialQTY
         ,@cPackDtlRefNo  = @cPackDtlRefNo
         ,@cPackDtlRefNo2 = @cPackDtlRefNo2
         ,@cPackDtlUPC    = @cPackDtlUPC
         ,@cPackDtlDropID = @cPackDtlDropID
         ,@nCartonNo      = @nCartonNo    OUTPUT
         ,@cLabelNo       = @cLabelNo     OUTPUT
         ,@nErrNo         = @nErrNo       OUTPUT
         ,@cErrMsg        = @cErrMsg      OUTPUT
         ,@nBulkSNO       = @nBulkSNO
         ,@nBulkSNOQTY    = @nBulkSNOQTY
         ,@cPackData1     = @cPackData1      --(cc05)   
         ,@cPackData2     = @cPackData2      --(cc05)   
         ,@cPackData3     = @cPackData3      --(cc05)  
      IF @nErrNo <> 0
         GOTO Quit

      IF @nMoreSNO = 1
         GOTO Quit

      -- Calc carton info
      SELECT
         @nCartonSKU = COUNT( 1), --DISTINCT PD.SKU
         @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo

      -- Get carton info
      SELECT
         @cLabelLine = PD.LabelLine,
         @nPackedQTY = PD.QTY
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND SKU = @cSKU

      -- Get custom carton no
      SELECT
         @cCustomNo =
            CASE @cCustomCartonNo
               WHEN '1' THEN LEFT( @cPD_DropID, 5)
               WHEN '2' THEN LEFT( @cPD_RefNo, 5)
               WHEN '3' THEN LEFT( @cPD_RefNo2, 5)
               ELSE CAST( @nCartonNo AS NVARCHAR(5))
            END

      -- Prepare next screen var
      SET @cOutField01 = RTRIM( @cCustomNo)
      SET @cOutField02 = CAST( CAST( @cLabelLine AS INT) AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
      SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
      SET @cOutField08 = CASE WHEN @cDisableQTYField = '1' THEN @cQTY ELSE @cDefaultQTY END --(moo01)
      SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
      SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
      SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
      SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField14 = '' -- PQTY

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @cFieldAttr14 = 'O' -- @nPQTY
      END
      ELSE
      BEGIN
         SET @cFieldAttr14 = '' -- @nPQTY
      END

      SET @cOutField15 = '' -- ExtendedInfo

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      SET @nenter = 0 --(JHU151)

      -- Go to SKU QTY screen
      SET @nScn = 4652
      SET @nStep = @nStep - 6
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Calc carton info
      SELECT
         @nCartonSKU = COUNT( 1), --DISTINCT PD.SKU
         @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo

      -- Get carton info
      SELECT
         @cLabelLine = PD.LabelLine,
         @nPackedQTY = PD.QTY
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND SKU = @cSKU

      -- Prepare next screen var
      SET @cOutField01 = RTRIM( @cCustomNo)
      SET @cOutField02 = CAST( CAST( @cLabelLine AS INT) AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)        
      SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))  -- ZG02														 
      SET @cOutField08 = CASE WHEN @cDisableQTYField = '1' THEN @cQTY ELSE @cDefaultQTY END --(moo01)
      SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
      SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
      SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
      SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField14 = '' -- PQTY
      SET @cOutField15 = '' -- ExtendedInfo

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @cFieldAttr14 = 'O' -- @nPQTY
      END
      ELSE
      BEGIN
         SET @cFieldAttr14 = '' -- @nPQTY
      END

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to SKU QTY screen
      SET @nScn = 4652
      SET @nStep = @nStep - 6
   END

   Step_9_Quit:
   BEGIN

      SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
      IF @cExtendedScreenSP = '0'
      BEGIN
         SET @cExtendedScreenSP = ''
      END
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            SET @nAction = 0
            GOTO Step_99
         END
      END


      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cFromDropID',     @cFromDropID),
               ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
               ('@cLabelNo',        @cLabelNo),
               ('@cSKU',            @cSKU),
               ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
               ('@cUCCNo',          @cUCCNo),
               ('@cCartonType',     @cCartonType),
               ('@cCube',           @cCube),
               ('@cWeight',         @cWeight),
               ('@cRefNo',          @cRefNo),
               ('@cSerialNo',       @cSerialNo),
               ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
               ('@cOption',         @cOption),
               ('@cPackDtlRefNo',   @cPackDtlRefNo),
               ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
               ('@cPackDtlUPC',     @cPackDtlUPC),
               ('@cPackDtlDropID',  @cPackDtlDropID),
               ('@cPackData1',      @cPackData1),
               ('@cPackData2',      @cPackData2),
               ('@cPackData3',      @cPackData3)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 9, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 3
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Step 10. (screen = 4659) Capture pack data
   Pack data 1: (field01)
   Pack data 2: (field02)
   Pack data 3: (field03)
********************************************************************************/
Step_10:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPackData1 = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cPackData2 = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cPackData3 = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END

      -- Retain value
      SET @cOutField02 = CASE WHEN @cFieldAttr02 = 'O' THEN @cOutField02 ELSE @cInField02 END
      SET @cOutField04 = CASE WHEN @cFieldAttr04 = 'O' THEN @cOutField04 ELSE @cInField04 END
      SET @cOutField06 = CASE WHEN @cFieldAttr06 = 'O' THEN @cOutField06 ELSE @cInField06 END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Serial No  --(cc05)
      IF @cSerialNoCapture IN ('1', '3')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY  
      BEGIN  
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDescr, @nQTY, 'CHECK', 'PICKSLIP', @cPickSlipNo,   
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
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '3'  
           
         IF @nErrNo <> 0  
            GOTO Quit  
  
         IF @nMoreSNO = 1  
         BEGIN  
            -- Go to Serial No screen  
            SET @nScn = 4831  
            SET @nStep = @nStep - 1  
  
            GOTO Quit  
         END  
      END  
  
      -- Confirm
      EXEC RDT.rdt_Pack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickSlipNo    = @cPickSlipNo
         ,@cFromDropID    = @cFromDropID
         ,@cSKU           = @cSKU
         ,@nQTY           = @nQTY
         ,@cUCCNo         = '' -- @cUCCNo
         ,@cSerialNo      = '' -- @cSerialNo
         ,@nSerialQTY     = 0  -- @nSerialQTY
         ,@cPackDtlRefNo  = @cPackDtlRefNo
         ,@cPackDtlRefNo2 = @cPackDtlRefNo2
         ,@cPackDtlUPC    = @cPackDtlUPC
         ,@cPackDtlDropID = @cPackDtlDropID
         ,@nCartonNo      = @nCartonNo    OUTPUT
         ,@cLabelNo       = @cLabelNo     OUTPUT
         ,@nErrNo         = @nErrNo       OUTPUT
         ,@cErrMsg        = @cErrMsg      OUTPUT
         ,@nBulkSNO       = 0
         ,@nBulkSNOQTY    = 0
         ,@cPackData1     = @cPackData1
         ,@cPackData2     = @cPackData2
         ,@cPackData3     = @cPackData3
      IF @nErrNo <> 0
         GOTO Quit

      -- Calc carton info
      SELECT
         @nCartonSKU = COUNT( 1), --DISTINCT PD.SKU
         @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo

      -- Get carton info
      SELECT
         @cLabelLine = PD.LabelLine,
         @nPackedQTY = PD.QTY
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND SKU = @cSKU
   END

   -- Get custom carton no
   SELECT
      @cCustomNo =
         CASE @cCustomCartonNo
            WHEN '1' THEN LEFT( @cPD_DropID, 5)
            WHEN '2' THEN LEFT( @cPD_RefNo, 5)
            WHEN '3' THEN LEFT( @cPD_RefNo2, 5)
            ELSE CAST( @nCartonNo AS NVARCHAR(5))
         END

   SET @cFieldAttr02 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr06 = ''

   -- Prepare next screen var
   SET @cOutField01 = RTRIM( @cCustomNo)
   SET @cOutField02 = CAST( CAST( @cLabelLine AS INT) AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
   SET @cOutField03 = '' -- SKU
   SET @cOutField04 = @cSKU
   SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
   SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
   SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
   SET @cOutField08 = CASE WHEN @cDisableQTYField = '1' THEN @cQTY ELSE '' END
   SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
   SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
   SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
   SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
   SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
   SET @cOutField14 = '' -- PQTY
   SET @cOutField15 = '' -- ExtendedInfo

   -- Convert to prefer UOM QTY
   IF @cPUOM = '6' OR -- When preferred UOM = master unit
      @nPUOM_Div = 0  -- UOM not setup
   BEGIN
      SET @cPUOM_Desc = ''
      SET @nPQTY = 0
      SET @cFieldAttr14 = 'O' -- @nPQTY
   END
   ELSE
   BEGIN
      SET @cFieldAttr14 = '' -- @nPQTY
   END

   SET @nenter = 0 --(JHU151)

   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

   -- Go to SKU QTY screen
   SET @nScn = @nFromScn
   SET @nStep = @nFromStep

   Step_10_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cFromDropID',     @cFromDropID),
               ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
               ('@cLabelNo',        @cLabelNo),
               ('@cSKU',            @cSKU),
               ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
               ('@cUCCNo',          @cUCCNo),
               ('@cCartonType',     @cCartonType),
               ('@cCube',           @cCube),
               ('@cWeight',         @cWeight),
               ('@cRefNo',          @cRefNo),
               ('@cSerialNo',       @cSerialNo),
               ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
               ('@cOption',         @cOption),
               ('@cPackDtlRefNo',   @cPackDtlRefNo),
               ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
               ('@cPackDtlUPC',     @cPackDtlUPC),
               ('@cPackDtlDropID',  @cPackDtlDropID),
               ('@cPackData1',      @cPackData1),
               ('@cPackData2',      @cPackData2),
               ('@cPackData3',      @cPackData3)


            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 10, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 3
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Step 11. Screen = 3570. Multi SKU
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
Step_11:
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
      SELECT
         @cSKUDescr = Descr,
         @cSKUDataCapture = DataCapture,
         @cPrePackIndicator = ISNULL( PrePackIndicator, ''),
         @cPackQtyIndicator = LEFT( ISNULL( PackQtyIndicator, '0'), 3)
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
   END

   -- Prepare next screen var
   SET @cOutField01 = RTRIM( @cCustomNo)
   SET @cOutField02 = CAST( CAST( @cLabelLine AS INT) AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
   SET @cOutField03 = '' -- SKU
   SET @cOutField04 = @cSKU
   SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
   SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
   SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
   SET @cOutField08 = '' -- QTY
   SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
   SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
   SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
   SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
   SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
   SET @cOutField14 = '' -- PQTY
   SET @cOutField15 = '' -- ExtendedInfo

   -- Convert to prefer UOM QTY
   IF @cPUOM = '6' OR -- When preferred UOM = master unit
      @nPUOM_Div = 0  -- UOM not setup
   BEGIN
      SET @cPUOM_Desc = ''
      SET @nPQTY = 0
      SET @cFieldAttr14 = 'O' -- @nPQTY
   END
   ELSE
   BEGIN
      SET @cFieldAttr14 = '' -- @nPQTY
   END

   SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

   -- Go to SKU QTY screen
   SET @nScn = @nFromScn
   SET @nStep = @nStep - 8

END
GOTO Quit


Step_99:
BEGIN
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END

   IF @cExtendedScreenSP = 'rdt_838ExtScn05'
   BEGIN
      SET @cOption = @cInField09
      IF @nScn = 6521 AND (@nInputKey = '0' OR @cOption <> '5')
      BEGIN
         SET @nScn = 4651
         SET @nStep = 2
         GOTO STEP_2
      END
   END

   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         DELETE FROM @tExtScnData
         INSERT INTO @tExtScnData (Variable, Value) VALUES 	
         ('@cPickSlipNo',     @cPickSlipNo),
         ('@cSKU',            @cUPC),
         ('@cJumpType',       @cJumpType)

         DECLARE  @nPreSCn       INT,
                  @nPreInputKey  INT

         SET @nPreSCn = @nScn
         SET @nPreInputKey = @nInputKey
         
         EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtendedScreenSP, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, @cLottable01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, @cLottable02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, @cLottable03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, @dLottable04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, @dLottable05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, @cLottable06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, @cLottable07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, @cLottable08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, @cLottable09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, @cLottable10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, @dLottable15 OUTPUT,
            @nAction, 
            @nScn OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cUDF01 OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
            @cUDF04 OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
            @cUDF07 OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
            @cUDF10 OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
            @cUDF13 OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
            @cUDF16 OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
            @cUDF19 OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
            @cUDF22 OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
            @cUDF25 OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
            @cUDF28 OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @nErrNo <> 0
            GOTO Step_99_Fail

         IF @cExtendedScreenSP = 'rdt_838ExtScn01'
         BEGIN
            IF @nScn = 4652
            BEGIN						
               SET @nCartonNo = 0
               SET @cLabelNo = ''
               SET @cSKU = ''
               SET @nPackedQTY = 0
               SET @nCartonSKU = 0
               SET @nCartonQTY = 0
               SET @nenter = 0

            END
            ELSE IF @nScn = 4650
            BEGIN
               EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
            END
            ELSE IF @nScn = 4831
            BEGIN
               SET @cOutField01 = ''
               SET @cOutField02= @cSKU
               SET @cOutField03 = @cSKUDescr
               IF @cUDF01 = '1'
               BEGIN
                  SET @cIsValSerialNo = '1'  -- set validated to jump the serial no check
                  SET @nInputKey='1'
                  GOTO Step_9
               END
            END
         END --rdt_838ExtScn01
         IF @cExtendedScreenSP = 'rdt_838ExtScn02'
         BEGIN
            IF @nPreScn = '6385' AND @nPreInputKey = 0 -- Back to Menu
            BEGIN
               SET @nFunc = @nScn
            END
            ELSE IF @nPreSCN = '6385' AND @nPreInputKey = 1 -- Go to step2
            BEGIN
               --update values to mobrec
               SET @cPickslipNo     =  @cUDF01
               SET @cFromDropID     =  @cUDF02     
               SET @cPackDtlDropID  =  @cUDF03
               SET @nCartonNo       =  CAST(@cUDF04 AS INT)  
               SET @cLabelNo        =  @cUDF05   
               SET @cCustomNo       =  @cUDF06   
               SET @cCustomID       =  @cUDF07
               SET @nCartonSKU      =  CAST(@cUDF08 AS INT) 
               SET @nCartonQTY      =  CAST(@cUDF09 AS INT)  
               SET @nTotalCarton    =  CAST(@cUDF10 AS INT)
               SET @nTotalPick      =  CAST(@cUDF11 AS INT)  
               SET @nTotalPack      =  CAST(@cUDF12 AS INT)  
               SET @nTotalShort     =  CAST(@cUDF13 AS INT)

            END -- 6385 inputkey=1

         END -- rdt_838ExtScn02

         GOTO Quit
      END
   END -- Ext scn sp <> ''

   Step_99_Fail:
      GOTO Quit
END -- End step99
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
      Printer_Paper  = @cPaperPrinter,
      Printer        = @cLabelPrinter,

      V_PickSlipNo   = @cPickSlipNo,
      V_SKU          = @cSKU,
      V_QTY          = @nQTY,
      -- V_CaseID       = @cCustomID,
      V_SKUDescr     = @cSKUDescr,
      V_FromScn      = @nFromScn,
      V_FromStep     = @nFromStep,
      V_UOM          = @cPUOM,

      V_String1      = @cPackDtlRefNo,
      V_String2      = @cPackDtlRefNo2,
      V_String3      = @cLabelNo,
      V_String4      = @cCartonType,
      V_String5      = @cCube,
      V_String6      = @cWeight,
      V_String7      = @cRefNo,
      V_String8      = @cLabelLine,
      V_String9      = @cPackDtlDropID,
      V_String10     = @cUCCCounter,
      V_String11     = @cMUOM_Desc,
      V_String12     = @cPUOM_Desc,
      V_String13     = @cDisableQTYFieldSP,
      V_String14     = @cFlowThruScreen, 

      V_CartonNo     = @nCartonNo,
      V_Integer1     = @nCartonSKU,
      V_Integer2     = @nCartonQTY,
      V_Integer3     = @nTotalCarton,
      V_Integer4     = @nTotalPick,
      V_Integer5     = @nTotalPack,
      V_Integer6     = @nTotalShort,
      V_Integer7     = @nPackedQTY,
      V_Integer8     = @nPUOM_Div,
      V_Integer9     = @nPQTY,
      V_Integer10    = @nMQTY,
      V_Integer11    = @nEnter,     --(cc01)  

      V_String15     = @cShowPickSlipNo,
      V_String16     = @cDefaultPrintLabelOption,
      V_String17     = @cDefaultPrintPackListOption,
      V_String18     = @cDefaultWeight,
      V_String19     = @cUCCNo,
      V_String20     = @cFromDropID,
      V_String21     = @cExtendedValidateSP,
      V_String22     = @cExtendedUpdateSP,
      V_String23     = @cExtendedInfoSP,
      V_String24     = @cExtendedInfo,
      V_String25     = @cDecodeSP,
      V_String26     = @cDisableQTYField,
      V_String27     = @cCapturePackInfoSP,
      V_String28     = @cPackInfo,
      V_String29     = @cAllowWeightZero,
      V_String30     = @cAllowCubeZero,
      V_String31     = @cAutoScanIn,
      V_String32     = @cDefaultOption,
      V_String33     = @cDisableOption,
      V_String34     = @cSerialNoCapture,
      V_String35     = @cPackList,
      V_String36     = @cShipLabel,
      V_String37     = @cCartonManifest,
      V_String38     = @cCustomCartonNo,
      V_String39     = @cCustomNo,
      V_String40     = @cDataCaptureSP,
      V_String41     = @cPackDtlUPC,
      V_String42     = @cPrePackIndicator,
      V_String43     = @cPackQtyIndicator,
      V_String44     = @cPackData1,
      V_String45     = @cPackData2,
      V_String46     = @cPackData3,
      V_String47     = @cMultiSKUBarcode,
      V_String48     = @cDefaultQTY, --(cc01)
      V_String49     = @cDefaultcartontype,
      V_String50     = @cPackByFromDropID,
      V_String51     = @cDefaultCursor, --(v7.5)

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