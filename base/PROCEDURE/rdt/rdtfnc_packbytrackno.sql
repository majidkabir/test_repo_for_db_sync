SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*****************************************************************************/    
/* Store procedure: rdtfnc_PackByTrackNo                                     */    
/* Copyright      : MAERSK                                                   */    
/*                                                                           */    
/* Purpose: SOS#247093 - Order Tracking No Capture                           */    
/*                                                                           */    
/* Modifications log:                                                        */    
/*                                                                           */    
/* Date       Rev  Author   Purposes                                         */    
/* 2012-06-15 1.0  James    Created                                          */    
/* 2012-08-17 1.1  James    Add option to force go back prev scn (james01)   */    
/* 2012-08-29 1.2  James    Print Carton Label only when change carton no    */    
/*                          but print multiple copies of A5 ticket (james02) */    
/* 2012-09-18 1.3  James    1. Get cartontype from cartonization table       */    
/*                          2. Limit weight that can key in (james03)        */    
/* 2012-09-20 1.4  James    Perfomance tuning & removing nvarchar (james04)  */    
/* 2013-07-01 1.5  James    SOS282353 - Allow MultiSKUBarcode (james05)      */    
/* 2013-11-06 1.6  James    SOS292634 - Enable print in Bartender (james06)  */    
/* 2014-02-28 1.7  James    SOS300492 - H&M modification (james07)           */    
/*                          1. Do not display "Label/Report" printed text    */    
/*                          if nothing printed                               */    
/*                          2. Skip update Orders.UserDefine04 if value      */    
/*                          already exists and same value                    */    
/*                          3. Add RDT config NOCHECKIFORDERSPICKED to skip  */    
/*                          checking orders picked                           */    
/*                          4. Skip Track No checking for H&M orders type    */    
/*                          5. Prompt alert message if RDT config FRAGILECHK */    
/*                          is turned on                                     */    
/*                          6. Allow swap lot if RDT PackSwapLot_SP turn on  */    
/*                          7. Add config ExtendedUpdateSP in screen 3       */    
/*                          8. Add config HideWeightInput to skip capture wgt*/    
/* 2014-04-30 1.8  James    SOS309850 - Skip track no screen if RDT config   */    
/*                          turn on (james08)                                */    
/*                          Add new print type                               */    
/*                          Do not display "Label/Report" printed text if    */    
/*                          nothing printed                                  */    
/* 2014-09-17 1.9  Ung      SOS320585 Add ExtendedInfoSP                     */    
/* 2014-10-23 2.0  James    SOS323253 - Add gift order printing (james09)    */    
/* 2015-05-05 2.1  James    SOS340748 - Add custom errmsg in step 5 (james10)*/    
/* 2015-07-10 2.2  James    SOS347381 - 1.Check CANC orders                  */    
/*                          2. Display errmsg in another screen              */    
/*                          3. Delete pack info when abort (james11)         */    
/* 2015-07-21 2.3  James    SOS347581 - Change the way Order box barcode     */    
/*                          be generated (james12)                           */    
/* 2015-08-04 2.4  James    SOS349301-Enhance PACKSKIPTRACKNO config(james13)*/    
/* 2015-10-06 2.5  James    SOS353558-Add tote id (james14)                  */    
/*                          Add extended validate                            */    
/* 2016-01-18 2.6  James    SOS361387 - Add ExtendedLabelNoSP (james15)      */    
/* 2016-02-29 2.7  James    SOS362968 - Add ExtendedInsPackSP (james16)      */    
/* 2016-03-03 2.8  James    SOS365177 - Add ExtendedValidateSP (james17)     */    
/* 2016-06-27 2.9  James    SOS368195 - Add ExtendedPrintSP (james18)        */    
/* 2016-09-06 2.8  James    Move Track No check to stored proc (james19)     */    
/* 2016-10-05 2.9  James    Perf tuning                                      */    
/* 2016-10-10 3.0  Ung      Performance tuning. ECOM bypass scan-in trigger  */    
/* 2016-10-25 3.1  James    Skip carton screen if config turn off (james20)  */    
/* 2016-11-13 3.2  James    Add labeltype SHIPPLBLSP (james21)               */    
/* 2016-11-21 3.3  James    Trim space for weight (james22)                  */    
/* 2016-12-14 3.4  James    Add ExtendedUpdateSP @ step1 (james23)           */    
/* 2017-02-23 3.5  James    WMS981-Add show error screen @ step 3 (james24)  */    
/* 2017-03-30 3.6  James    WMS1446-Add config for auto packconfirm (james25)*/    
/* 2017-04-12 3.7  James    WMS1563-Add extended msg queue sp (james26)      */    
/* 2017-10-26 3.8  James    Move printing label out from transaction         */    
/*                          block (james27)                                  */    
/* 2018-03-01 3.9  James    WMS3212-Bug fix. Change hardcoded error message  */    
/*                          to follow standard error handling (james28)      */    
/* 2018-03-13 4.0  James    WMS3212-Make input carton type optional (james29)*/    
/* 2018-07-30 4.1  James    Perf tuning. Remove storerkey filter if not      */    
/*                          necessary (james30)                              */    
/* 2018-09-25 4.2  Gan      Perfomance tuning. Remove isvalidqty during      */    
/*                          loading rdtmobrec                                */    
/* 2018-11-16 4.3  James    Bug fix on DropID (james31)                      */    
/* 2019-01-16 4.4  James    WMS7499-Add ExtendedValidateSP @ scn 3 (james32) */    
/* 2019-02-11 4.5  James    WMS7181-Determine CapturePackInfo using stored   */    
/*                          proc (james33)                                   */    
/* 2019-03-01 4.6  James    Bug fix on get next carton no (james34)          */    
/* 2019-07-25 4.7  James    WMS9881-Allow variable report type when print    */    
/*                          ship label using RDT config (james35)            */    
/* 2019-10-30 4.8  James    WMS-10896 Add ExtendedValidateSP @ step1(james36)*/    
/* 2020-02-24 4.9  Leong    INC1049672 - Revise BT Cmd parameters.           */    
/* 2020-03-30 5.0  James    WMS-12662 Add ExtendedMsgSP @ step1 (james37)    */    
/* 2020-07-03 5.1  James    WMS-13965 Add Confirm Unpack screen (james38)    */    
/* 2020-07-05 5.2  James    WMS-13913 Add GetOrdersSP (james39)              */    
/*                          CapturePackInfo add additional parameters        */    
/*                          Add rdt_Decode                                   */    
/* 2020-04-24 5.3  James    WMS-12757 Add skip trackno screen when user esc  */      
/*                          back from sku screen (james38)                   */      
/* 2020-09-10 5.4  James    WMS-15010 Add packcfm sp (james39)               */      
/* 2020-12-17 5.5  James    WMS-15906 Add Ref no (james40)                   */    
/* 2020-02-05 5.6  James    WMS-16306 Add Flow thru step 4 (james41)         */    
/* 2020-12-14 5.7  James    WMS-15773 Fix codelkup (sostatus) didn't filter  */      
/*                          storerkey (james40)                              */      
/* 2020-04-01 5.8 LZG       INC1090847 - Cater for PTL.PTLTran (ZG01)        */     
/* 2021-04-20 5.9  James    WMS-16841 Fix param wrong put on                 */    
/*                          ExtendedLabelNoSP (james42)                      */    
/* 2020-10-22 6.0  James    WMS-13913 Screen will iterate 3-4-5 if it is     */      
/*                          tote with multi orders (james43)                 */      
/* 2021-04-08 6.1  James    WMS-16024 Standarized use of TrackingNo (james44)*/    
/* 2021-06-04 6.2  James    WMS-17181 Add config to determine whether use    */    
/*                          Udf04 or TrackingNo as system trackingno(james45)*/    
/* 2021-04-02 6.3  YeeKung  WMS-16717 Add serialno screen(yeekung01)          */   
/* 2020-12-14 6.4 Chermaine WMS-15826 Add eventlog (cc01)                    */     
/* 2021-07-16 6.5  James    WMS-17503 Add default ctn type (james46)         */    
/*                          Add update trackingno into PackInfo              */   
/* 2021-10-01 6.6  YeeKung   WMSS-17797 change printsp (yeekung02)           */   
/* 2021-11-11 6.7  James    WMS-18225 Add CaptureInfoSP (james47)            */  
/*                          Add config to disallow carton no change          */  
/* 2022-03-18 6.8  James    WMS-19123 Add CaptureInfoSP to step3 (james48)   */    
/* 2022-06-15 6.9  James    WMS-19935 Not auto convert weight to kg (james49)*/  
/* 2022-07-19 7.0  James    INC1862140 Add SKUStatus filter (james50)        */  
/* 2021-10-05 7.1  James    WMS-17435 Add ExtUpdSP into step 5 (james46)     */
/* 2022-01-10 7.2  James    WMS-18321 Add config to exclude short (james51)  */    
/* 2022-07-07 7.3  James    Addhoc fix. Changed weight variable from real    */    
/*                          to float (james52)                               */    
/* 2024-02-07 7.4  James    WMS-24696 Prompt Invalid carton type in new      */
/*                          screen (james52)                                 */
/* 2023-03-28 7.5  James    WMS-22039 Enhance ExtInfoSP at step 3 (james53)  */  
/* 2024-06-02 7.6  James    WMS-24295 Add custom carton no sp (james54)      */
/*                          Add ExtValidSP into step 1 (ESC)                 */
/* 2024-09-06 7.7  James    Add Pickslip output during decode (james54)      */
/* 2024-09-03 7.8  James    WMS-26174 Add Tote/DropID format check (james55) */
/* 2024-11-08 7.9  PXL009   FCR-1118 Merged 7.8 from v0 branch               */
/*****************************************************************************/    
    
CREATE   PROC [RDT].[rdtfnc_PackByTrackNo](    
   @nMobile    INT,    
   @nErrNo     INT  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max    
) AS    
    
SET NOCOUNT ON      
SET QUOTED_IDENTIFIER OFF      
SET ANSI_NULLS OFF      
SET CONCAT_NULL_YIELDS_NULL OFF      
        
-- Misc variable    
DECLARE @b_Success      INT    
    
-- Define a variable    
DECLARE    
   @nFunc               INT,    
   @nScn                INT,    
   @nStep               INT,    
   @cLangCode           NVARCHAR(3),    
   @nMenu               INT,    
   @nInputKey           NVARCHAR(3),    
   @cPrinter            NVARCHAR(10),    
   @cPrinter_Paper      NVARCHAR(10),    
   @cUserName           NVARCHAR(18),    
    
   @cStorerKey          NVARCHAR(15),    
   @cFacility           NVARCHAR(5),    
    
   @cOrderKey           NVARCHAR(10),    
   @cTrackNo            NVARCHAR(20),    
   @cSKU                NVARCHAR(20),    
   @cTrackRegExp        NVARCHAR(255),    
   @nAllocatedQty       INT,    
   @nPickedQty          INT,    
   @nPickCheck          INT,    
   @nQty                INT,    
   @cInSKU              NVARCHAR(40),    
   @cDecodeLabelNo      NVARCHAR(20),    
   @cShipperKey         NVARCHAR(15),    
   @cPickDetailKey      NVARCHAR(10),    
   @nPDQty              INT,    
   @nPickDetailCheck    INT,    
   @cPickslipno         NVARCHAR( 10),    
   @cCartonNo           NVARCHAR( 5),    
   @cLoadKey            NVARCHAR( 10),    
   @cLabelNo            NVARCHAR( 20),    
   @cCtnType            NVARCHAR( 10),    
   @cCtnWeight          NVARCHAR( 10),    
   @cRoute              NVARCHAR( 10),    
   @cConsigneeKey       NVARCHAR( 15),    
   @cTempBarcode        NVARCHAR( 20),    
   @cOrderBoxBarcode    NVARCHAR( 20),    
   @cCheckDigit         NVARCHAR( 1),    
   @cActSKU             NVARCHAR( 20),    
   @cCurLabelNo         NVARCHAR( 20),    
   @cCurLabelLine       NVARCHAR( 5),    
   @cReportType         NVARCHAR( 10),    
   @cPrintJobName       NVARCHAR( 50),    
   @cDataWindow         NVARCHAR( 50),    
   @cTargetDB           NVARCHAR( 20),    
   @cPriority           NVARCHAR( 10),    
   @cOption             NVARCHAR( 1),     -- (james01)    
   @cMaxCtnWeight       NVARCHAR( 10),    -- (james03)    
   @nSKUCnt             INT,    
   @nQTY_PD             INT,    
   @nTranCount          INT,    
   @nExpectedQty        INT,    
   @nPackedQty          INT,    
   @nCartonNo           INT,    
   @bSuccess            INT,    
   @nCtnCount           INT,    
   @nCtnNo  INT,    
   @nSUM_PackedSKU      INT,    
   @nSUM_PickedSKU      INT,    
   @bDebug              INT, -- (james06)    
   @fCtnWeight          FLOAT,    
   @cMultiSKUBarcode    NVARCHAR(1),   -- (james05)    
   @nFromScn            INT,           -- (james05)    
   @cSKUDesc            NVARCHAR( 60), -- (james05)    
   @cExtendedUpdateSP   NVARCHAR( 20), -- (james05)    
   @cExtendedInfoSP     NVARCHAR( 20),    
   @cExtendedInfo       NVARCHAR( 20),    
   @cSQL                NVARCHAR(MAX),      -- (james05)    
   @cSQLParam           NVARCHAR(MAX),      -- (james05)    
   @cPackByTrackNotUpdUPC    NVARCHAR(1),    -- (james05)    
   @cHideWeightInput    NVARCHAR( 1),        -- (james07)    
   @cShort              NVARCHAR( 10),       -- (james07)    
    
   @cLottable01         NVARCHAR( 18),       -- (james07)    
   @cLottable02         NVARCHAR( 18),       -- (james07)    
   @cLottable03         NVARCHAR( 18),       -- (james07)    
   @dLottable04         DATETIME,            -- (james07)    
   @dLottable05         DATETIME,            -- (james07)    
   @cOrd_Status         NVARCHAR( 10),       -- (james07)    
   @cPackSwapLot_SP     NVARCHAR( 20),       -- (james07)    
   @cLOC                NVARCHAR( 10),       -- (james07)    
   @cID                 NVARCHAR( 18),       -- (james07)    
   @nPrinted            INT,                 -- (james08)    
   @cNotes2             NVARCHAR( 4000),     -- (james09)    
   @cOrderInfo01        NVARCHAR( 30),       -- (james09)    
   @cShowErrMsgInNewScn NVARCHAR( 1),        -- (james11)    
   @cUPCCode            NVARCHAR( 10),       -- (james12)    
   @cPackSkipTrackNo_SP NVARCHAR( 20),       -- (james13)    
   @cPackSkipTrackNo    NVARCHAR( 1),        -- (james13)    
   @cDropID             NVARCHAR( 20),       -- (james14)    
   @cExtendedValidateSP NVARCHAR( 20),       -- (james14)    
   @cCapturePackInfo    NVARCHAR( 1),        -- (james14)    
   @cCapturePackInfoSP  NVARCHAR( 20),       -- (james33)    
   @cExtendedLabelNoSP  NVARCHAR( 20),       -- (james15)       
   @cExtendedInsPackSP  NVARCHAR( 20),       -- (james16)       
   @cExtendedPrintSP    NVARCHAR( 20),       -- (james18)       
   @nCurStep            INT,                 -- (james18)       
   @nCurScn             INT,                 -- (james18)       
   @cAutoPackConfirm    NVARCHAR( 1),        -- (james25)       
   @cExtendedMsgQSP     NVARCHAR( 20),       -- (james26)       
   @cShowPackCompletedScn NVARCHAR( 1),      -- (james25)       
   @cHideCartonInput    NVARCHAR( 20),       -- (james29)    
   @cCtnTypeEnabled     NVARCHAR( 1),        -- (james29)    
   @nNextCartonNo       INT,                 -- (james34)    
   @cShipLabel          NVARCHAR( 10),       -- (james35)    
   @fCartontnWeight     FLOAT,               -- (james39)    
   @cGetOrders_SP       NVARCHAR(20),        -- (james39)    
   @tGetOrders          VARIABLETABLE,       -- (james39)    
   @cDecodeSP           NVARCHAR( 20),    
   @cBarcode            NVARCHAR( 60),    
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
   @nIsMoveOrders       INT,                 -- (james38)      
   @cRefNo              NVARCHAR( 40),    
   @cFlowThruCtnTypeScn NVARCHAR( 1),        -- (james41)    
   @nMoreToPack         INT,      
   @cUseUdf04AsTrackNo  NVARCHAR(1),   -- (james45)    
   @cSerialNo           NVARCHAR( 30),       -- ( yeekung01)    
   @cSerialNoCapture    NVARCHAR( 1),        -- ( yeekung01)    
   @nSerialQTY          INT,                 -- ( yeekung01)    
   @nMoreSNO       INT,         
   @nBulkSNO       INT,         
   @nBulkSNOQTY    INT,     
   @cDefaultCartonType  NVARCHAR( 10),    
   @cUpdTrackingNo      NVARCHAR( 1),    
   @cCaptureInfoSP      NVARCHAR( 20),  
   @cData1              NVARCHAR( 60),  
   @cData2              NVARCHAR( 60),  
   @cData3              NVARCHAR( 60),  
   @cData4              NVARCHAR( 60),  
   @cData5              NVARCHAR( 60),  
   @tCaptureVar         VARIABLETABLE,  
   @nDisAllowChangeCtnNo   INT,  
   @cDataCapture           NVARCHAR( 1),  
   @cDataCaptureInfo       NVARCHAR( 1),  
   @cSKUDataCapture        NVARCHAR( 1),  
   @nFromStep              INT,  
   @cNotConvertWgt2KG      NVARCHAR( 1),  
   @cSKUStatus             NVARCHAR( 10),  
   @cExcludeShortPick      NVARCHAR( 1),    
   @cPickConfirmStatus     NVARCHAR( 1),    
   @cExcludedDocType       NVARCHAR( 20),
   @cDoctype               NVARCHAR( 1),
   @nDocTypeExists         INT,
   @cSkipCTNInUseCFG       NVARCHAR( 1), --TSY01  
   @cGetCartonNoCFG        NVARCHAR( 1), --TSY01  
   @cNewCtnNoSP            NVARCHAR( 20), --(james54)
   
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
   @cFieldAttr15 NVARCHAR( 1),    
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),    
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),    
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),    
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),    
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),     
    
   @cErrMsg1    NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),    
   @cErrMsg3    NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),    
   @cErrMsg5    NVARCHAR( 20), @cErrMsg6    NVARCHAR( 20),    
   @cErrMsg7    NVARCHAR( 20), @cErrMsg8    NVARCHAR( 20),    
   @cErrMsg9    NVARCHAR( 20), @cErrMsg10   NVARCHAR( 20),    
   @cErrMsg11   NVARCHAR( 20), @cErrMsg12   NVARCHAR( 20),    
   @cErrMsg13   NVARCHAR( 20), @cErrMsg14   NVARCHAR( 20),    
   @cErrMsg15   NVARCHAR( 20)     
    
    
    
-- Getting Mobile information    
SELECT    
   @nFunc            = Func,    
   @nScn             = Scn,    
   @nStep            = Step,    
   @nInputKey        = InputKey,    
   @cLangCode        = Lang_code,    
   @nMenu            = Menu,    
    
   @cFacility        = Facility,    
   @cStorerKey       = StorerKey,    
   @cPrinter         = Printer,    
   @cPrinter_Paper   = Printer_Paper,    
   @cUserName        = UserName,    
   @cLottable02      = V_Lottable02,    
   @cOrderKey        = V_OrderKey,    
   @cSKU             = V_SKU,    
   @cDropID          = V_CaseID,    
       
   @nIsMoveOrders    = V_Integer1,      
   @nDisAllowChangeCtnNo = V_Integer2,  
     
   @nCartonNo        = V_Cartonno,    
   @nFromScn         = V_FromScn,    
   @nFromStep        = V_FromStep,  
    
   @cTrackNo         = V_String1,    
   @cShipperKey      = V_String2,    
   @cShipLabel       = V_String3,    
   @cPickslipno      = V_String4,    
   @cGetOrders_SP    = V_String5,       
   @cDecodeSP        = V_String6,    
   @cMultiSKUBarcode = V_String7,    
   @cActSKU          = V_String8,    
   @cPackByTrackNotUpdUPC = V_String9,    
   @cHideWeightInput = V_String10,    
   @cExtendedInfoSP  = V_String11,    
    
   @cShowErrMsgInNewScn = V_String12,    
   @cCapturePackInfoSP  = V_String13,    
   @cExtendedInsPackSP  = V_String14,    
   @cExtendedPrintSP    = V_String15,    
   @cExtendedUpdateSP   = V_String16,    
   @cExtendedValidateSP = V_String17,    
   @cAutoPackConfirm    = V_String18,    
   @cShowPackCompletedScn = V_String19,    
   @cExtendedMsgQSP       = V_String20,    
   @cHideCartonInput      = V_String21,    
   @cPackSkipTrackNo    = V_String22,      
   @cFlowThruCtnTypeScn = V_String23,    
   @cUseUdf04AsTrackNo  = V_String24,   -- (james45)    
   @cDefaultCartonType  = V_String25,   -- (james46)    
   @cCaptureInfoSP      = V_String26,  
   @cPackSkipTrackNo_SP = V_String27,  
   @cDataCapture        = V_String28,  
   @cNotConvertWgt2KG   = V_String29,  
   @cSKUStatus          = V_String30,   
   @cExcludeShortPick   = V_String31,   -- (james51)    
   @cPickConfirmStatus  = V_String32,   -- (james51)    
   @cExcludedDocType    = V_String33,
   @cNewCtnNoSP         = V_String34,   -- (james54)
      
   @cRefNo              = V_String41,  -- (james40)    
   @cSerialNoCapture    = V_String42,    
   @cPackSwapLot_SP     = V_String43,    
   @cData1              = V_String44,  
   @cData2              = V_String45,  
   @cData3              = V_String46,  
   @cData4              = V_String47,  
   @cData5              = V_String48,  
     
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
    
FROM   RDTMOBREC (NOLOCK)    
WHERE  Mobile = @nMobile    
    
-- Redirect to respective screen    
IF @nFunc = 840    
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 840    
   IF @nStep = 1 GOTO Step_1   -- Scn = 3120 Orderkey    
   IF @nStep = 2 GOTO Step_2   -- Scn = 3121 Track No    
   IF @nStep = 3 GOTO Step_3   -- Scn = 3122 SKU    
   IF @nStep = 4 GOTO Step_4   -- Scn = 3123 Success Message    
   IF @nStep = 5 GOTO Step_5   -- Scn = 3124 Options RESCAN / CONTINUE SCANNING    
   IF @nStep = 6 GOTO Step_6   -- Scn = 3570 Multi SKU selection     -- (james05)    
   IF @nStep = 7 GOTO Step_7   -- Scn = 3126 Unpack   -- (james38)    
   IF @nStep = 8 GOTO Step_8   -- Scn = 4830. Serial no     
   IF @nStep = 9 GOTO Step_9   -- Scn = 3127. Capture data  
END    
    
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. Called from menu (func = 867)    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Set the entry point    
   SET @nScn = 3120    
   SET @nStep = 1    
    
   -- initialise all variable    
   SET @cOrderKey = ''    
   SET @cTrackNo = ''    
   SET @cDropID = ''    
   SET @cRefNo = ''    
    
   -- Prep next screen var    
   SET @cOutField01 = ''    
   SET @cOutField02 = ''    
   SET @cOutField03 = ''    
    
   -- Clear previous stored record    
   DELETE FROM RDT.rdtTrackLog    
   WHERE AddWho = @cUserName    
    
   SET @cMultiSKUBarcode = ''    
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)    
    
   SET @cPackByTrackNotUpdUPC = ''    
   SET @cPackByTrackNotUpdUPC = rdt.RDTGetConfig( @nFunc, 'PackByTrackNotUpdUPC', @cStorerKey)    
    
   SET @cHideWeightInput = ''    
   SET @cHideWeightInput = rdt.RDTGetConfig( @nFunc, 'HideWeightInput', @cStorerkey)    
    
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)    
   IF @cExtendedInfoSP = '0'    
      SET @cExtendedInfoSP = ''    
    
   SET @cShowErrMsgInNewScn = rdt.RDTGetConfig( @nFunc, 'ShowErrMsgInNewScn', @cStorerkey)    
   IF @cShowErrMsgInNewScn = '0'    
      SET @cShowErrMsgInNewScn = ''          
    
   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfo', @cStorerkey)    
   IF @cCapturePackInfoSP = '0'    
      SET @cCapturePackInfoSP = ''          
    
   SET @cExtendedInsPackSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInsPackSP', @cStorerKey)    
   IF @cExtendedInsPackSP = '0'    
      SET @cExtendedInsPackSP = ''          
    
   SET @cExtendedPrintSP = rdt.RDTGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)    
   IF @cExtendedPrintSP = '0'    
      SET @cExtendedPrintSP = ''          
    
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'    
      SET @cExtendedUpdateSP = ''          
    
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
   IF @cExtendedValidateSP = '0'    
      SET @cExtendedValidateSP = ''          
    
   SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)    
    
   SET @cShowPackCompletedScn = rdt.RDTGetConfig( @nFunc, 'ShowPackCompletedScn', @cStorerKey)    
    
   SET @cExtendedMsgQSP = rdt.RDTGetConfig( @nFunc, 'ExtendedMsgQueueSP', @cStorerKey)    
   IF @cExtendedMsgQSP = '0'    
      SET @cExtendedMsgQSP = ''          
    
   SET @cHideCartonInput = ''    
   SET @cHideCartonInput = rdt.RDTGetConfig( @nFunc, 'HideCartonInput', @cStorerkey)    
    
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)    
   IF @cShipLabel = '0'    
      SET @cShipLabel = ''    
    
   -- (james39)    
   SET @cGetOrders_SP = rdt.RDTGetConfig( @nFunc, 'GetOrders_SP', @cStorerkey)        
   IF @cGetOrders_SP = '0'      
    SET @cGetOrders_SP = ''      
    
   -- (james39)    
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)    
   IF @cDecodeSP = '0'    
      SET @cDecodeSP = ''    
    
   -- (james41)    
   SET @cFlowThruCtnTypeScn = rdt.RDTGetConfig( @nFunc, 'FlowThruCtnTypeScn', @cStorerKey)    
    
   --(james45)    
   SET @cUseUdf04AsTrackNo = rdt.RDTGetConfig( @nFunc, 'UseUdf04AsTrackNo', @cStorerKey)    
       
    --(yeekung01)    
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)      
           
   SET @cPackSwapLot_SP = rdt.RDTGetConfig( @nFunc, 'PackSwapLot_SP', @cStorerKey)    
       
   --(james46)    
   SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)    
     
   --(james47)  
   SET @cCaptureInfoSP = rdt.RDTGetConfig( @nFunc, 'CaptureInfoSP', @cStorerKey)  
   IF @cCaptureInfoSP = '0'  
      SET @cCaptureInfoSP = ''  
  
   SET @cPackSkipTrackNo_SP = rdt.RDTGetConfig( @nFunc, 'PACKSKIPTRACKNO', @cStorerkey)  
  
   SET @nDisAllowChangeCtnNo = rdt.RDTGetConfig( @nFunc, 'DisAllowChangeCtnNo', @cStorerkey)  
     
   SET @cDataCapture = rdt.RDTGetConfig( @nFunc, 'DataCapture', @cStorerkey)  
     
   -- (james49)  
   SET @cNotConvertWgt2KG = rdt.RDTGetConfig( @nFunc, 'NotConvertWgt2KG', @cStorerkey)  
  
   -- (james50)    
   SET @cSKUStatus = rdt.RDTGetConfig( @nFunc, 'SKUStatus', @cStorerkey)      
   IF @cSKUStatus = '0'    
      SET @cSKUStatus = ''    
  
   -- (james51)    
   SET @cExcludeShortPick = rdt.RDTGetConfig( @nFunc, 'ExcludeShortPick', @cStorerKey)    
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = ''  

   -- (james53)
   SET @cExcludedDocType = rdt.RDTGetConfig( @nFunc, 'ExcludedDocType', @cStorerkey)    
   IF @cExcludedDocType = '0'  
      SET @cExcludedDocType = ''  

   -- (james54)
   SET @cNewCtnNoSP = rdt.RDTGetConfig( @nFunc, 'NewCartonNoSP', @cStorerKey)  
   IF @cNewCtnNoSP = '0'  
      SET @cNewCtnNoSP = ''  

   EXEC rdt.rdtSetFocusField @nMobile, 1          
END    
GOTO Quit    
    
/********************************************************************************    
Step 1. screen = 3120    
   OrderKey:   (Field01, input)    
   Drop ID:    (Field02, input)    
   Ref No:    (Field03, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOrderKey = ISNULL(RTRIM(@cInField01),'')    
      SET @cDropID = ISNULL(RTRIM(@cInField02),'')          
      SET @cRefNo = ISNULL(RTRIM(@cInField03),'')    
    
      IF ISNULL(@cDropID,'') <> '' OR ISNULL(@cRefNo,'') <> '' --(yeekung01)    
      BEGIN    
         IF ISNULL(@cDropID,'') <> ''
         BEGIN
            -- Check DropID format
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0   -- (james55)
            BEGIN
               SET @nErrNo = 90672
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
               EXEC rdt.rdtSetFocusField @nMobile, 2  -- DropID
               SET @cOutField02 = ''
               GOTO Quit
            END
         END

         -- Custom get orderkey sp. Can do swap lot inside the sp and insert ecommlog      
         IF @cGetOrders_SP <> ''      
            AND EXISTS ( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetOrders_SP AND type = 'P')      
         BEGIN      
            INSERT INTO @tGetOrders (Variable, Value) VALUES ( '@cRefNo',     @cRefNo)    
                  
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cGetOrders_SP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cDropID, @tGetOrders,        
                 @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '      
            SET @cSQLParam =      
               '@nMobile                   INT,           ' +    
               '@nFunc                     INT,           ' +    
               '@cLangCode                 NVARCHAR( 3),  ' +    
               '@nStep                     INT,           ' +    
               '@nInputKey                 INT,           ' +    
               '@cStorerkey                NVARCHAR( 15), ' +    
               '@cDropID                   NVARCHAR( 20), ' +    
               '@tGetOrders                VariableTable READONLY,   ' +    
               '@cOrderKey                 NVARCHAR( 10) OUTPUT,     ' +    
               '@nErrNo                    INT           OUTPUT,     ' +    
               '@cErrMsg                   NVARCHAR( 20) OUTPUT      '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cDropID, @tGetOrders,       
               @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT      
      
            IF @nErrNo <> 0      
            BEGIN      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')       
               GOTO Step_1_Fail      
            END      
         END      
         ELSE    
         BEGIN    
            SELECT TOP 1 @cOrderKey = OrderKey    
            FROM dbo.PTLTran WITH (NOLOCK)     
            WHERE DropID = @cDropID    
            AND   StorerKey = @cStorerkey    
            AND   [Status] = '9'    
            ORDER BY PTLKey DESC    
                
                  
            IF ISNULL(@cOrderKey, '') = ''            -- ZG01        
            BEGIN        
               SELECT TOP 1 @cOrderKey = OrderKey        
               FROM PTL.PTLTran WITH (NOLOCK)        
               WHERE DropID = @cDropID        
               AND   StorerKey = @cStorerkey        
               AND   [Status] = '9'        
               ORDER BY PTLKey Desc        
            END     
         END      
      END    
          
      --Check if it is blank    
      IF @cOrderKey = ''    
      BEGIN    
         IF @cDropID <> ''    
         BEGIN    
            SET @nErrNo = 90664    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid tote id    
            EXEC rdt.rdtSetFocusField @nMobile, 2    
         END    
         ELSE IF @cRefNo <> ''    
         BEGIN    
            SET @nErrNo = 90670    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Refno    
            EXEC rdt.rdtSetFocusField @nMobile, 3    
         END    
         ELSE             
         BEGIN    
            SET @nErrNo = 76451    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderKey req    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
         END    
    
         GOTO Step_1_Fail    
      END    
    
      --Check if Order exits    
      IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)    
                     WHERE Orderkey = @cOrderkey    
                     AND Storerkey = @cStorerkey)    
      BEGIN    
          SET @nErrNo =  76452    
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv OrderKey    
          GOTO Step_1_Fail    
      END    
    
      --Check if Order.SOStatus = 'HOLD'    
      IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)    
                 JOIN dbo.CodeLkup CL WITH (NOLOCK)   --(james41)    
                     ON ( CL.CODE = O.SOSTATUS AND CL.StorerKey = O.StorerKey)      
                     WHERE O.Orderkey = @cOrderkey    
                     AND O.Storerkey = @cStorerkey    
                     AND CL.Listname = 'SOStatus'    
                     AND CL.Code = 'HOLD'    
                     )    
      BEGIN    
         SET @nErrNo =  76453    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Hold!    
         GOTO Step_1_Fail    
      END    
    
      SET @cOrd_Status = ''  
      SET @cDoctype = ''
      SELECT 
         @cOrd_Status = [Status],
         @cDoctype = DocType
      FROM dbo.Orders WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
      AND Storerkey = @cStorerKey  
    
      --Check if Order in Progress    
      IF @cOrd_Status = '0'    
      BEGIN    
         SET @nErrNo =  76454    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORD NOT ALLOC    
         GOTO Step_1_Fail    
      END    
    
      IF @cOrd_Status = '5' AND rdt.RDTGetConfig( @nFunc, 'NOCHECKIFORDERSPICKED', @cStorerKey) <> '1'  -- (james07)    
      BEGIN    
         SET @nErrNo =  76497    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDER PICKED    
         GOTO Step_1_Fail    
      END    
    
      IF @cOrd_Status = '9'    
      BEGIN    
         SET @nErrNo =  76498    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDERS SHIPPED    
         GOTO Step_1_Fail    
      END    
    
      --Check if Order.SOStatus = 'CANC'  (james11)    
      IF @cOrd_Status = 'CANC'    
      BEGIN    
         SET @nErrNo =  90663    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Canc!    
         GOTO Step_1_Fail    
      END    

      -- (james53)
      -- Check for overlap between ExcludedDocType and Doctype
      SELECT @nDocTypeExists = CASE WHEN EXISTS (
                                  SELECT 1
                                  FROM STRING_SPLIT( @cDoctype, ',') AS DocType
                                  WHERE TRIM(value) IN (SELECT TRIM(value) FROM STRING_SPLIT( @cExcludedDocType, ',')))
                                  THEN 1
                                  ELSE 0
                               END
      IF @nDocTypeExists = 1
      BEGIN  
         SET @nErrNo =  90671  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Doctype  
         GOTO Step_1_Fail  
      END  

      -- (james17)    
      IF @cExtendedValidateSP <> '' AND     
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
            ' @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
       
         SET @cSQLParam =    
            '@nMobile                   INT,           ' +    
            '@nFunc                     INT,           ' +    
            '@cLangCode                 NVARCHAR( 3),  ' +    
            '@nStep                     INT,           ' +    
            '@nInputKey                 INT,           ' +    
            '@cStorerkey                NVARCHAR( 15), ' +    
            '@cOrderKey                 NVARCHAR( 10), ' +    
            '@cPickSlipNo               NVARCHAR( 10), ' +    
            '@cTrackNo                  NVARCHAR( 20), ' +    
            '@cSKU                      NVARCHAR( 20), ' +    
            '@nCartonNo                 INT,           ' +    
            '@cCtnType                  NVARCHAR( 10), ' +    
            '@cCtnWeight                NVARCHAR( 10), ' +    
            '@cSerialNo                 NVARCHAR( 30), ' +         
            '@nSerialQTY                INT,           ' +      
            '@nErrNo                    INT           OUTPUT,  ' +    
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
       
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
               @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
         IF @nErrNo <> 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            GOTO Step_1_Fail    
         END    
      END    
             
      -- Generate PickingInfo    
      SET @cPickSlipno = ''    
      SELECT @cPickSlipno = ISNULL(PickheaderKey,'')    
      FROM   dbo.PickHeader WITH (NOLOCK)    
      WHERE  OrderKey = @cOrderKey    
    
      SET @nErrNo = 0      
      SET @nTranCount = @@TRANCOUNT      
      BEGIN TRAN      
      SAVE TRAN Step1_ScanIn      
    
      -- Create Pickheader    
      IF ISNULL(RTRIM(@cPickSlipno) ,'')=''    
      BEGIN    
         EXECUTE dbo.nspg_GetKey    
         'PICKSLIP',    
         9,    
         @cPickslipno   OUTPUT,    
         @bsuccess      OUTPUT,    
         @nErrNo        OUTPUT,    
         @cErrMsg       OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
            SET @nErrNo = 76455    
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --GET PSLIP FAIL    
            GOTO RollBackTran_Step1_ScanIn      
         END    
    
         SELECT @cPickslipno = 'P'+@cPickslipno    
    
         INSERT INTO dbo.PICKHEADER    
            (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone)    
         VALUES    
            (@cPickslipno, '', @cOrderKey, '0', 'D')    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 76456    
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --InstPKHdr Fail    
            GOTO RollBackTran_Step1_ScanIn      
         END    
      END --ISNULL(@cPickSlipno, '') = ''    
    
      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)    
                     WHERE  PickSlipNo = @cPickSlipNo)    
      BEGIN    
         -- Check ECOM order    
         IF EXISTS( SELECT 1 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND DocType = 'E')    
         BEGIN    
            -- Scan-in, bypass trigger    
            INSERT INTO dbo.PickingInfo( PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho, TrafficCop)    
            VALUES (@cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName, 'U')    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 90665    
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Scan In Fail    
               GOTO RollBackTran_Step1_ScanIn      
            END    
         END    
         ELSE    
         BEGIN    
            EXEC dbo.isp_ScanInPickslip    
               @c_PickSlipNo    = @cPickSlipNo,    
               @c_PickerID  = @cUserName,    
               @n_err    = @nErrNo      OUTPUT,    
               @c_errmsg   = @cErrMsg     OUTPUT    
       
            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 76457    
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Scan In Fail    
               GOTO RollBackTran_Step1_ScanIn      
            END    
         END    
      END    
    
      -- (james23)    
      IF @cExtendedUpdateSP <> '' AND     
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,' +    
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
         SET @cSQLParam =    
            '@nMobile                   INT,           ' +    
            '@nFunc                     INT,           ' +    
            '@cLangCode                 NVARCHAR( 3),  ' +    
            '@nStep                     INT,           ' +    
            '@nInputKey                 INT,           ' +    
            '@cStorerkey                NVARCHAR( 15), ' +    
            '@cOrderKey                 NVARCHAR( 10), ' +    
            '@cPickSlipNo               NVARCHAR( 10), ' +    
            '@cTrackNo                  NVARCHAR( 20), ' +    
            '@cSKU                      NVARCHAR( 20), ' +    
            '@nCartonNo                 INT,           ' +    
            '@cSerialNo                 NVARCHAR( 30), ' +         
            '@nSerialQTY                INT,           ' +      
            '@nErrNo                    INT           OUTPUT,  ' +    
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO RollBackTran_Step1_ScanIn      
      END    
    
      COMMIT TRAN Step1_ScanIn      
      GOTO Quit_Step1_ScanIn      
      
      RollBackTran_Step1_ScanIn:      
         ROLLBACK TRAN Step1_ScanIn -- Only rollback change made here      
      Quit_Step1_ScanIn:      
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
         COMMIT TRAN      
    
      IF @nErrNo <> 0      
         GOTO Step_1_Fail      
  
      -- Capture Info  
      IF @cCaptureInfoSP <> ''  
      BEGIN  
       INSERT INTO @tCaptureVar (Variable, Value) VALUES ( '@cDataCapture', @cDataCapture)    
         
         EXEC rdt.rdt_PackByTrackNo_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'DISPLAY',   
            @cOrderKey, @cDropID, @cRefNo, @cPickSlipNo, @cData1, @cData2, @cData3, @cData4, @cData5,   
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
            @cDataCaptureInfo OUTPUT,  
            @tCaptureVar,   
            @nErrNo  OUTPUT,   
            @cErrMsg OUTPUT  
         IF @nErrNo <> 0  
            GOTO Quit  
  
         IF @cDataCaptureInfo IN ('1', '2')
         BEGIN  
            -- Go to next screen  
            SET @nScn = @nScn + 7  
            SET @nStep = @nStep + 8  
           
            -- insert to Eventlog    
            EXEC RDT.rdt_STD_EventLog    
              @cActionType   = '1', -- SignIn    
              @cUserID       = @cUserName,    
              @nMobileNo     = @nMobile,    
              @nFunctionID   = @nFunc,    
              @cFacility     = @cFacility,    
              @cStorerKey    = @cStorerkey,    
              @cRefNo1       = @cOrderkey,    
              @cRefNo2       = ''    
          
            IF @cDataCaptureInfo = '1'
               GOTO Quit  

            IF @cDataCaptureInfo = '2'
               GOTO Step_9  
         END  
      END  
  
      IF LEN( RTRIM( @cPackSkipTrackNo_SP)) > 1    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPackSkipTrackNo_SP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackSkipTrackNo_SP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, ' +    
               ' @cPackSkipTrackNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPackSkipTrackNo NVARCHAR( 1)  OUTPUT,  ' +    
               '@nErrNo           INT           OUTPUT,  ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cStorerkey, @cOrderKey,     
                 @cPackSkipTrackNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END          
         ELSE    
            SET @cPackSkipTrackNo = ''    
      END    
      ELSE    
         SET @cPackSkipTrackNo = @cPackSkipTrackNo_SP    
    
      IF @cPackSkipTrackNo IN ('', '0')    
      BEGIN    
         SET @cOutField01 = @cOrderkey    
         SET @cOutField02 = ''    
       
         SET @nScn = @nScn + 1    
         SET @nStep = @nStep + 1    
      END    
    
      -- (james08)    
      -- If svalue = 0 or blank then need go to next screen and exists check in that screen    
      -- If svalue = 1 then check every orders must have a track no    
      -- If svalue > 0 (1, 2, 3, etc) then no need check orders whether tracking no exists    
      IF @cPackSkipTrackNo = '1'    
      BEGIN    
         SET @cTrackNo = ''    
             
         IF @cUseUdf04AsTrackNo = '1'    
            SELECT @cTrackNo = Userdefine04    
            FROM dbo.Orders WITH (NOLOCK)    
            WHERE StorerKey = @cStorerkey    
            AND   OrderKey = @cOrderkey    
         ELSE    
            SELECT @cTrackNo = TrackingNo    
            FROM dbo.Orders WITH (NOLOCK)    
            WHERE StorerKey = @cStorerkey    
            AND   OrderKey = @cOrderkey    
    
         IF ISNULL( @cTrackNo, '') = ''    
         BEGIN    
            SET @nErrNo = 90652    
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --TRACK NO REQ    
            GOTO Step_1_Fail    
          END    
      END    
    
      IF @cPackSkipTrackNo > '0'    
      BEGIN    
         -- 1 orders 1 tracking no    
         -- discrete pickslip, 1 ordes 1 pickslipno    
         SET @nExpectedQty = 0    
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
         WHERE Orderkey = @cOrderkey    
         AND   Storerkey = @cStorerkey    
         AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
               ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
               ( [Status] = [Status]))    
             
         SET @nPackedQty = 0    
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
    
         -- (james54)  
         IF @cNewCtnNoSP <> '' AND  
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cNewCtnNoSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cNewCtnNoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cDropID, @cRefNo, ' +  
               ' @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               '@nMobile                   INT,           ' +  
               '@nFunc                     INT,           ' +  
               '@cLangCode                 NVARCHAR( 3),  ' +  
               '@nStep                     INT,           ' +  
               '@nInputKey                 INT,           ' +  
               '@cStorerkey                NVARCHAR( 15), ' +  
               '@cOrderKey                 NVARCHAR( 10), ' +  
               '@cPickSlipNo               NVARCHAR( 10), ' +  
               '@cDropID                   NVARCHAR( 20), ' +  
               '@cRefNo                    NVARCHAR( 40), ' +  
               '@nCartonNo                 INT           OUTPUT,  ' +  
               '@nErrNo                    INT           OUTPUT,  ' +  
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cDropID, @cRefNo, 
                  @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_1_Fail  
         END  
         ELSE
         BEGIN
            SET @nCartonNo = 0  
            SELECT @nCartonNo = ISNULL(MAX(CartonNo), 1) FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
         END
    
         -- If packheader not exists meaning is first carton in this pickslip. So default to carton no 1 (james07)    
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)    
         BEGIN    
            SET @nCartonNo = 1    
         END    
    
         SET @cOutField01 = @cOrderkey    
         SET @cOutField02 = @cTrackNo    
         SET @cOutField03 = @nCartonNo    
         SET @cOutField04 = @nExpectedQty    
         SET @cOutField05 = @nPackedQty    
         SET @cOutField06 = ''    
         SET @cOutField07 = ''            -- (james01)    
    
         IF @nDisAllowChangeCtnNo = 1  
            SET @cFieldAttr03 = 'O'  
              
         EXEC rdt.rdtSetFocusField @nMobile, 6    
    
         SET @nScn = @nScn + 2    
         SET @nStep = @nStep + 2    
      END    
    
      -- Extended info    
      SET @cExtendedInfo = ''    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT,  ' +    
               '@nErrNo           INT           OUTPUT,  ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
                
            SET @cOutField15 = @cExtendedInfo    
         END    
      END    
    
      -- (james37)    
      IF @cExtendedMsgQSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedMsgQSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedMsgQSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                 @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END    
      END    
          
      -- insert to Eventlog    
      EXEC RDT.rdt_STD_EventLog    
        @cActionType   = '1', -- SignIn    
        @cUserID       = @cUserName,    
        @nMobileNo     = @nMobile,    
        @nFunctionID   = @nFunc,    
        @cFacility     = @cFacility,    
        @cStorerKey    = @cStorerkey,    
        @cRefNo1       = @cOrderkey,    
        @cRefNo2       = ''    
    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- (james54)  
      IF @cExtendedValidateSP <> '' AND  
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +  
            ' @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
         SET @cSQLParam =  
            '@nMobile                   INT,           ' +  
            '@nFunc                     INT,           ' +  
            '@cLangCode                 NVARCHAR( 3),  ' +  
            '@nStep                     INT,           ' +  
            '@nInputKey                 INT,           ' +  
            '@cStorerkey                NVARCHAR( 15), ' +  
            '@cOrderKey                 NVARCHAR( 10), ' +  
            '@cPickSlipNo               NVARCHAR( 10), ' +  
            '@cTrackNo                  NVARCHAR( 20), ' +  
            '@cSKU                      NVARCHAR( 20), ' +  
            '@nCartonNo                 INT,           ' +  
            '@cCtnType                  NVARCHAR( 10), ' +  
            '@cCtnWeight                NVARCHAR( 10), ' +  
            '@cSerialNo                 NVARCHAR( 30), ' +  
            '@nSerialQTY                INT,           ' +  
            '@nErrNo                    INT           OUTPUT,  ' +  
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '  
  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,  
               @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
            GOTO Step_1_Fail  
         END  
      END  
      
      EXEC RDT.rdt_STD_EventLog    
      @cActionType   = '9', -- SignOut    
      @cUserID       = @cUserName,    
      @nMobileNo     = @nMobile,    
      @nFunctionID   = @nFunc,    
      @cFacility     = @cFacility,    
      @cStorerKey    = @cStorerkey,    
      @cRefNo1       = @cOrderkey,    
      @cRefNo2       = ''    
    
      -- Back to menu    
      SET @nFunc = @nMenu    
      SET @nScn  = @nMenu    
      SET @nStep = 0    
    
      SET @cOutField01 = ''    
      SET @cOrderKey = ''    
        
      IF @nDisAllowChangeCtnNo = 1  
         SET @cFieldAttr03 = ''  
        
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cOrderKey = ''    
      SET @cDropID = ''    
      SET @cRefNo = ''    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 2. screen = 3121    
   Orderkey (Field01)    
   Track No (Field02, Input)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cTrackNo = @cInField02    
    
      -- (james07)    
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)    
                  JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
                  WHERE C.ListName = 'HMORDTYPE'    
                  AND   O.OrderKey = @cOrderkey    
                  AND   O.StorerKey = @cStorerKey)    
      BEGIN    
         SELECT @cShort = C.Short    
         FROM dbo.CODELKUP C WITH (NOLOCK)    
         JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
         WHERE C.ListName = 'HMORDTYPE'    
         AND   O.OrderKey = @cOrderkey    
         AND   O.StorerKey = @cStorerKey    
    
         -- S = Normal order    
         -- M = Move order    
         -- For Move order, no trucking no need to be inputted, in this case, ignore the checking    
         IF @cShort = 'M'    
            GOTO CONTINUE_PROCESS    
    
         -- If orders.userdefine04 = '' then proceed with normal checking    
         -- If orders.userdefine04 <> '' then check if same with track no. If not same then prompt error    
         IF @cShort = 'S'    
         BEGIN    
            IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)    
                        WHERE (( @cUseUdf04AsTrackNo = '1' AND ISNULL( USERDEFINE04, '') <> '') OR ( ISNULL ( TrackingNo, '') <> ''))    
                        AND   OrderKey = @cOrderkey    
                        AND   StorerKey = @cStorerKey)    
            BEGIN    
               IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)    
                           WHERE (( @cUseUdf04AsTrackNo = '1' AND ISNULL( USERDEFINE04, '') <> ISNULL( @cTrackNo, '')) OR     
                                  ( ISNULL ( TrackingNo, '') <> ISNULL( @cTrackNo, '')))    
                           AND   OrderKey = @cOrderkey    
                           AND   StorerKey = @cStorerKey)    
               BEGIN    
                  SET @nErrNo = 76495    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNo req    
           EXEC rdt.rdtSetFocusField @nMobile, 1    
                  GOTO Step_2_Fail    
               END    
               ELSE    
                  GOTO CONTINUE_PROCESS    
            END    
         END    
      END    
    
      IF rdt.RDTGetConfig( @nFunc, 'TRACKNOREQUIRED', @cStorerKey) = 1    
      BEGIN    
         IF ISNULL(@cTrackNo, '') = ''    
         BEGIN    
            SET @nErrNo = 76458    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNo req    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_2_Fail    
         END    
      END    
    
      IF ISNULL(@cTrackNo, '') <> ''    
      BEGIN    
         -- (james19)    
         SET @nErrNo = 0    
         EXEC [rdt].[rdt_PackByTrackNo_ValidateTrackNo]     
            @nMobile       = @nMobile,    
            @nFunc         = @nFunc,     
            @cLangCode     = @cLangCode,     
            @nStep         = @nStep,     
            @nInputKey     = @nInputKey,     
            @cStorerkey    = @cStorerkey,     
            @cOrderKey     = @cOrderKey,     
            @cTrackNo      = @cTrackNo,     
            @nErrNo        = @nErrNo    OUTPUT,     
            @cErrMsg       = @cErrMsg   OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_2_Fail    
         END    
    
               -- (james17)    
      IF @cExtendedValidateSP <> '' AND     
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
            ' @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
       
         SET @cSQLParam =    
            '@nMobile                   INT,           ' +    
            '@nFunc                     INT,           ' +    
            '@cLangCode                 NVARCHAR( 3),  ' +    
            '@nStep                     INT,           ' +    
            '@nInputKey                 INT,           ' +    
            '@cStorerkey                NVARCHAR( 15), ' +    
            '@cOrderKey                 NVARCHAR( 10), ' +    
            '@cPickSlipNo               NVARCHAR( 10), ' +    
            '@cTrackNo                  NVARCHAR( 20), ' +    
            '@cSKU                      NVARCHAR( 20), ' +    
            '@nCartonNo                 INT,           ' +    
            '@cCtnType                  NVARCHAR( 10), ' +    
            '@cCtnWeight                NVARCHAR( 10), ' +    
            '@cSerialNo                 NVARCHAR( 30), ' +         
            '@nSerialQTY                INT,           ' +      
            '@nErrNo                    INT           OUTPUT,  ' +    
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
       
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
               @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
         IF @nErrNo <> 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            GOTO Step_2_Fail    
         END    
      END    
    
         IF @cExtendedUpdateSP <> '' AND     
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,' +    
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile                   INT,           ' +    
               '@nFunc                     INT,           ' +    
               '@cLangCode                 NVARCHAR( 3),  ' +    
               '@nStep                     INT,           ' +    
               '@nInputKey                 INT,           ' +    
               '@cStorerkey                NVARCHAR( 15), ' +    
               '@cOrderKey                 NVARCHAR( 10), ' +    
               '@cPickSlipNo               NVARCHAR( 10), ' +    
               '@cTrackNo                  NVARCHAR( 20), ' +    
               '@cSKU                      NVARCHAR( 20), ' +    
               '@nCartonNo                 INT,           ' +    
               '@cSerialNo                 NVARCHAR( 30), ' +         
               '@nSerialQTY                INT,           ' +      
               '@nErrNo                    INT           OUTPUT,  ' +    
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,    
                  @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EXT UPD FAIL'    
               GOTO Quit    
            END    
         END    
         ELSE    
         BEGIN    
            SET @nTranCount = @@TRANCOUNT    
            BEGIN TRAN    
            SAVE TRAN UPD_TRACKNO    
    
            IF @cUseUdf04AsTrackNo = '1'    
               UPDATE dbo.Orders WITH (ROWLOCK) SET    
                  UserDefine04 = @cTrackNo, TrafficCop = NULL    
               WHERE Orderkey = @cOrderKey    
               AND Storerkey = @cStorerKey    
               AND ISNULL( UserDefine04, '') = ''  -- Upd only when blank track# (james17)    
            ELSE    
               UPDATE dbo.Orders WITH (ROWLOCK) SET     
                  TrackingNo = @cTrackNo, TrafficCop = NULL    
               WHERE Orderkey = @cOrderKey    
               AND Storerkey = @cStorerKey    
               AND ISNULL( TrackingNo, '') = ''  -- Upd only when blank track# (james17)    
    
            IF @@ERROR <> 0    
            BEGIN    
               ROLLBACK TRAN UPD_TRACKNO    
               WHILE @@TRANCOUNT > @nTranCount    
                  COMMIT TRAN    
               SET @nErrNo = 76462    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Ord Failed'    
               GOTO Step_2_Fail    
            END    
    
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN    
         END    
      END      -- TRACKNOREQUIRED = 0    
    
      -- (james07)    
      CONTINUE_PROCESS:    
      -- (james26)    
      IF @cExtendedMsgQSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedMsgQSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedMsgQSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                 @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END    
      END    
                
      --IF rdt.RDTGetConfig( @nFunc, 'FRAGILECHK', @cStorerKey) = 1 AND    
      --   EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)    
      --            WHERE [Stop] = 'Y'    
      --            AND   OrderKey = @cOrderKey    
      --            AND   StorerKey = @cStorerKey)    
      --BEGIN    
      --   SET @nErrNo = 0    
      --   SET @cErrMsg1 = 'THIS ORDERS INCLUDES'    
      --   SET @cErrMsg2 = 'FRAGILE ITEM.'    
      --   SET @cErrMsg3 = 'PLS USE BOX.'    
      --   SET @cErrMsg4 = ''    
      --   SET @cErrMsg5 = ''    
      --   EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3    
      --   IF @nErrNo = 1    
      --   BEGIN    
      --      SET @cErrMsg1 = ''    
      --      SET @cErrMsg2 = ''    
      --      SET @cErrMsg3 = ''    
      --   END    
      --END    
    
      -- 1 orders 1 tracking no    
      -- discrete pickslip, 1 ordes 1 pickslipno    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
      AND   Storerkey = @cStorerkey    
      AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
            ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
            ( [Status] = [Status]))    
    
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
    
      SET @nCartonNo = 0    
      SELECT @nCartonNo = ISNULL(MAX(CartonNo), 1) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
    
      -- If packheader not exists meaning is first carton in this pickslip. So default to carton no 1 (james07)    
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)    
      BEGIN    
         SET @nCartonNo = 1    
      END    
    
      -- Extended info    
      SET @cExtendedInfo = ''    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END    
      END    
    
      SET @cOutField01 = @cOrderkey    
      SET @cOutField02 = @cTrackNo    
      SET @cOutField03 = @nCartonNo    
      SET @cOutField04 = @nExpectedQty    
      SET @cOutField05 = @nPackedQty    
      SET @cOutField06 = ''    
      SET @cOutField07 = ''            -- (james01)    
      SET @cOutField15 = @cExtendedInfo    
    
      EXEC rdt.rdtSetFocusField @nMobile, 6    
    
      IF @nDisAllowChangeCtnNo = 1  
         SET @cFieldAttr03 = 'O'  
           
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- (james13)  
      IF @cExtendedUpdateSP <> '' AND  
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo, @cSerialNo, @nSerialQTY, ' +  
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
         SET @cSQLParam =  
            '@nMobile                   INT,           ' +  
            '@nFunc                     INT,           ' +  
            '@cLangCode                 NVARCHAR( 3),  ' +  
            '@nStep                     INT,           ' +  
            '@nInputKey                 INT,           ' +  
            '@cStorerkey                NVARCHAR( 15), ' +  
            '@cOrderKey                 NVARCHAR( 10), ' +  
            '@cPickSlipNo               NVARCHAR( 10), ' +  
            '@cTrackNo                  NVARCHAR( 20), ' +  
            '@cSKU                      NVARCHAR( 20), ' +  
            '@nCartonNo                 INT,           ' +  
            '@cSerialNo                 NVARCHAR( 30), ' +         
            '@nSerialQTY                INT,           ' +      
            '@nErrNo                    INT           OUTPUT,  ' +  
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '  
  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo, @cSerialNo, @nSerialQTY,   
              @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EXT UPD FAIL'  
            GOTO Quit  
         END  
      END  
             
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
    
      SET @nScn = @nScn - 1      
      SET @nStep = @nStep - 1      
      
      -- (james31)      
      IF @cRefNo <> ''      
         EXEC rdt.rdtSetFocusField @nMobile, 3      
      ELSE IF @cDropID <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 2    
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 1      
    
      SET @cOrderKey = ''      
      SET @cDropID = ''      
      SET @cRefNo = ''    
   END    
   GOTO Quit    
    
   Step_2_Fail:    
   BEGIN    
      SET @cTrackNo = ''    
      SET @cOutField02 = ''    
   END    
END    
GOTO Quit    
        
/********************************************************************************        
Step 3. screen = 3122        
   Orderkey (Field01)        
   Track No (Field02)        
   CTN No   (Field03, Input)        
   QTY EXP  (Field04)        
   QTY PICK (Field05)        
   SKU      (Field06, Input)    
   Option   (Field07, Input)    
   Ext Info (Field15)    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cCartonNo = CASE WHEN @nDisAllowChangeCtnNo = 1 THEN ISNULL(RTRIM(@cOutField03),'') else ISNULL(RTRIM(@cInField03),'') END    
      SET @cInSKU = ISNULL(RTRIM(@cInField06),'')    
      SET @cOption = ISNULL(RTRIM(@cInField07),'')    
      SET @cBarcode = ISNULL(RTRIM(@cInField06),'')    

      -- (james01)    
      IF ISNULL(@cOption, '') <> ''    
      BEGIN    
         IF @cOption <> '1'    
         BEGIN    
            SET @nErrNo = 76490    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv opt    
            SET @cOutField03 = @cCartonNo    
            SET @cOutField07 = ''    
            SET @cOption = ''    
            EXEC rdt.rdtSetFocusField @nMobile, 7    
            GOTO Quit    
         END    
    
         IF @cOption = '1'    
         BEGIN    
            IF rdt.RDTGetConfig( @nFunc, 'PackByTrackNo_AbortDelPack', @cStorerkey) = '1'    
            BEGIN    
               SET @cOutField01 = ''    
                   
               SET @nScn = @nScn + 4    
               SET @nStep = @nStep + 4    
                 
               IF @nDisAllowChangeCtnNo = 1  
                  SET @cFieldAttr03 = ''  
  
               GOTO Quit    
            END    
            ELSE    
               DELETE FROM RDT.rdtTrackLog WITH (ROWLOCK)    
               WHERE AddWho = @cUserName    
  
               IF @nDisAllowChangeCtnNo = 1  
                  SET @cFieldAttr03 = ''  
  
            GOTO GO_BACK_SCN2    
         END    
      END    
    
      IF ISNULL(@cInSKU, '') = ''    
      BEGIN    
         SET @nErrNo = 76463    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU req    
         SET @cOutField03 = @cCartonNo    
         SET @cOutField06 = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 6    
         GOTO Quit    
      END    
    
      SET @cActSKU = ''    
      SET @cDecodeLabelNo = ''    
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)    
      IF @cDecodeLabelNo = '0'    
         SET @cDecodeLabelNo = ''    
    
      IF ISNULL(@cDecodeLabelNo,'') <> ''    
      BEGIN    
         EXEC dbo.ispLabelNo_Decoding_Wrapper    
          @c_SPName     = @cDecodeLabelNo    
         ,@c_LabelNo    = @cInSKU    
         ,@c_Storerkey  = @cStorerkey    
         ,@c_ReceiptKey = @cOrderKey    
         ,@c_POKey      = ''    
         ,@c_LangCode   = @cLangCode    
         ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU    
         ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE    
         ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR    
         ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE    
         ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY    
         ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#    
         ,@c_oFieled07  = @c_oFieled07 OUTPUT    
         ,@c_oFieled08  = @c_oFieled08 OUTPUT    
         ,@c_oFieled09  = @c_oFieled09 OUTPUT    
         ,@c_oFieled10  = @c_oFieled10 OUTPUT    
         ,@b_Success    = @b_Success   OUTPUT    
         ,@n_ErrNo      = @nErrNo      OUTPUT    
         ,@c_ErrMsg     = @cErrMsg     OUTPUT    
    
         IF ISNULL(@cErrMsg, '') <> ''    
         BEGIN    
            IF @cShowErrMsgInNewScn = '1' -- (james24)    
            BEGIN    
               SET @nErrNo = @nErrNo    
               SET @cErrMsg = @cErrMsg    
               SET @cErrMsg1 = @cErrMsg    
               SET @cErrMsg2 = ''    
               SET @cErrMsg3 = ''    
               SET @nErrNo = 0    
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3    
               IF @nErrNo = 1    
               BEGIN    
                  SET @cErrMsg1 = ''    
                  SET @cErrMsg2 = ''    
                  SET @cErrMsg3 = ''    
               END       
               GOTO Step_3_Fail          
            END    
            ELSE    
            BEGIN    
               SET @cErrMsg = @cErrMsg    
               GOTO Step_3_Fail    
            END    
         END    
    
         SET @cActSKU = @c_oFieled01    
         SET @cLottable02 = @c_oFieled02    
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
                  @cUPC          = @cActSKU     OUTPUT,     
                  @cLottable01   = @cLottable01 OUTPUT,      
                  @cLottable02   = @cLottable02 OUTPUT,      
                  @cLottable02   = @cLottable03 OUTPUT,      
                  @dLottable04   = @dLottable04 OUTPUT,      
                  @dLottable05   = @dLottable05 OUTPUT,      
                  @cLottable06   = @cLottable06 OUTPUT,      
                  @cLottable07   = @cLottable07 OUTPUT,      
                  @cLottable08   = @cLottable08 OUTPUT,      
                  @cLottable09   = @cLottable09 OUTPUT,      
                  @cLottable10   = @cLottable10 OUTPUT,      
                  @cLottable11   = @cLottable11 OUTPUT,      
                  @cLottable12   = @cLottable12 OUTPUT,      
                  @dLottable13   = @dLottable13 OUTPUT,      
                  @dLottable14   = @dLottable14 OUTPUT,      
                  @dLottable15   = @dLottable15 OUTPUT,      
                  @cUserDefine01 = @cOrderKey   OUTPUT,  
                  @cUserDefine02 = @cPickSlipNo OUTPUT,  
                  @nErrNo        = @nErrNo      OUTPUT,     
                  @cErrMsg       = @cErrMsg     OUTPUT  
            END      
      
            -- Customize decode      
            ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')      
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cDropID, ' +    
                  ' @cOrderKey     OUTPUT, @cSKU        OUTPUT, @cTrackingNo OUTPUT, ' +  
                  ' @cLottable01   OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +  
                  ' @cLottable06   OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +  
                  ' @cLottable11   OUTPUT, @cLottable02 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +  
                  ' @cSerialNo OUTPUT, @nSerialQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cPickSlipNo OUTPUT'    
               SET @cSQLParam =    
                  ' @nMobile      INT,             ' +    
                  ' @nFunc        INT,             ' +    
                  ' @cLangCode    NVARCHAR( 3),    ' +    
                  ' @nStep        INT,             ' +    
                  ' @nInputKey    INT,             ' +    
                  ' @cStorerKey   NVARCHAR( 15),   ' +    
                  ' @cBarcode     NVARCHAR( 2000), ' +    
                  ' @cDropID      NVARCHAR( 20),' +  
                  ' @cOrderKey    NVARCHAR( 10)  OUTPUT, ' +  
                  ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +    
                  ' @cTrackingNo  NVARCHAR( 20)  OUTPUT, ' +  
                  ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +    
                  ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +  
                  ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +  
                  ' @dLottable04  DATETIME  OUTPUT, ' +  
                  ' @dLottable05  DATETIME  OUTPUT, ' +  
                  ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +    
                  ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +  
                  ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +  
                  ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +    
                  ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +  
                  ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +  
                  ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +  
                  ' @dLottable13  DATETIME  OUTPUT, ' +  
                  ' @dLottable14  DATETIME  OUTPUT, ' +  
                  ' @dLottable15  DATETIME  OUTPUT, ' +   
                  ' @cSerialNo    NVARCHAR( 30)  OUTPUT, ' +   
                  ' @nSerialQTY   INT            OUTPUT, ' +                   
                  ' @nErrNo       INT            OUTPUT, ' +    
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT, ' +   
                  ' @cPickSlipNo  NVARCHAR( 10)  OUTPUT  '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, @cDropID,   
                  @cOrderKey     OUTPUT, @cActSKU     OUTPUT, @cTrackNo    OUTPUT,     
                  @cLottable01   OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,  
                  @cLottable06   OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,  
                  @cLottable11   OUTPUT, @cLottable02 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,  
                  @cSerialNo OUTPUT, @nSerialQTY OUTPUT ,@nErrNo OUTPUT, @cErrMsg OUTPUT, @cPickSlipNo OUTPUT  
  
                SET @nQty = CASE WHEN @nSerialQTY = 0 THEN @nQty ELSE @nSerialQTY END  
            END        
    
            IF @nErrNo <> 0      
               GOTO Step_3_Fail      
         END      
         ELSE    
         BEGIN    
            SET @cActSKU = ISNULL(@cInSKU,'')    
         END    
      END    
          
      SET @nSKUCnt = 0    
      EXEC [RDT].[rdt_GETSKUCNT]    
         @cStorerKey  = @cStorerKey,    
         @cSKU        = @cActSKU,    
         @nSKUCnt     = @nSKUCnt       OUTPUT,    
         @bSuccess    = @bSuccess      OUTPUT,    
         @nErr        = @nErrNo        OUTPUT,    
         @cErrMsg     = @cErrMsg       OUTPUT,  
         @cSKUStatus  = @cSKUStatus    
    
      IF @nSKUCnt = 0    
      BEGIN    
         IF @cShowErrMsgInNewScn = '1' -- (james11)    
         BEGIN    
            SET @nErrNo = 76464    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
            SET @cErrMsg1 = @cErrMsg    
            SET @cErrMsg2 = ''    
            SET @cErrMsg3 = ''    
            SET @nErrNo = 0    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3    
            IF @nErrNo = 1    
            BEGIN    
               SET @cErrMsg1 = ''    
               SET @cErrMsg2 = ''    
               SET @cErrMsg3 = ''    
            END             
         END    
         ELSE    
         BEGIN    
            SET @nErrNo = 76464    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
         END    
         SET @cOutField03 = @cCartonNo    
         SET @cOutField06 = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 6    
         GOTO Quit    
      END    
    
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
               @cActSKU  OUTPUT,    
               @nErrNo   OUTPUT,    
               @cErrMsg  OUTPUT    
    
            IF @nErrNo = 0    
            BEGIN    
               -- Go to Multi SKU screen    
               SET @nFromScn = @nScn    
               SET @nScn = 3570    
               SET @nStep = @nStep + 3    
    
               GOTO Quit    
            END    
         END    
    
         SET @nErrNo = 90667    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUbarcod    
         SET @cErrMsg1 = @cErrMsg    
         SET @nErrNo = 0    
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1    
         IF @nErrNo = 1    
            SET @cErrMsg1 = ''    
    
         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64276 ', 'Multi SKU barcode'    
         GOTO Step_3_Fail    
      END    
      ELSE    
      BEGIN    
         EXEC [RDT].[rdt_GETSKU]    
            @cStorerKey  = @cStorerkey,    
           @cSKU        = @cActSKU       OUTPUT,    
            @bSuccess    = @bSuccess      OUTPUT,    
            @nErr        = @nErrNo        OUTPUT,    
            @cErrMsg     = @cErrMsg       OUTPUT,  
            @cSKUStatus  = @cSKUStatus    
      END    
    
      SET @cSKU = @cActSKU    
    
      SELECT @cSKUDataCapture = DataCapture  
      FROM dbo.SKU WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   Sku = @cSKU  
        
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)    
                     WHERE StorerKey = @cStorerKey    
                     AND   OrderKey = @cOrderKey    
                     AND   SKU = @cSKU)    
      BEGIN    
         IF @cShowErrMsgInNewScn = '1' -- (james11)    
         BEGIN    
            SET @nErrNo = 76494    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NOT IN ORD    
            SET @cErrMsg1 = @cErrMsg    
            SET @cErrMsg2 = ''    
            SET @cErrMsg3 = ''    
            SET @nErrNo = 0    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3    
            IF @nErrNo = 1    
            BEGIN    
               SET @cErrMsg1 = ''    
               SET @cErrMsg2 = ''    
               SET @cErrMsg3 = ''    
            END             
         END    
         ELSE    
         BEGIN          
            SET @nErrNo = 76494    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NOT IN ORD    
         END    
         SET @cOutField06 = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 6    
         GOTO Quit    
      END    
    
      -- Check if SKU over packed    
      SELECT @nSUM_PackedSKU = ISNULL(SUM( QTY), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
         AND SKU = @cSKU    
    
      SELECT @nSUM_PickedSKU = ISNULL(SUM( QTY), 0) FROM dbo.PickDetail WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
         AND OrderKey = @cOrderKey    
         AND SKU = @cSKU    
         AND Status < '9'    
    
      IF @nSUM_PickedSKU < (@nSUM_PackedSKU + 1)   -- +1 because each scan is increase by 1 qty    
      BEGIN    
         IF @cShowErrMsgInNewScn = '1' -- (james11)    
         BEGIN    
            SET @nErrNo = 76481    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU OVERPACKED    
            SET @cErrMsg1 = @cErrMsg    
            SET @cErrMsg2 = ''    
            SET @cErrMsg3 = ''    
            SET @nErrNo = 0    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3    
            IF @nErrNo = 1    
            BEGIN    
               SET @cErrMsg1 = ''    
               SET @cErrMsg2 = ''    
               SET @cErrMsg3 = ''    
            END             
         END    
         ELSE    
         BEGIN                
            SET @nErrNo = 76481    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU OVERPACKED    
         END    
         SET @cOutField06 = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 6    
         GOTO Quit             
      END    
    
      -- Carton No field validation    
      IF ISNULL(@cCartonNo, '') IN ('', '0')    
      BEGIN    
         SET @nErrNo = 76465    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CTN#    
         --SET @cOutField03 = ''    
         SET @cOutField06 = @cInSKU    
         EXEC rdt.rdtSetFocusField @nMobile, 3    
         GOTO Quit    
      END    
    
      IF RDT.rdtIsValidQTY( @cCartonNo, 1) = 0    
      BEGIN    
         SET @nErrNo = 76466    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CTN#    
         --SET @cOutField03 = ''    
         SET @cOutField06 = @cInSKU    
         EXEC rdt.rdtSetFocusField @nMobile, 3    
         GOTO Quit    
      END    
    
      SET @nCartonNo = CAST(@cCartonNo AS INT)    
    
      SET @cSkipCTNInUseCFG = rdt.RDTGetConfig( @nFunc, 'SkipCTNInUseCFG', @cStorerKey) --TSY01  
      -- 1 carton only allow 1 user do packing  
      IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)  
                 WHERE PickSlipNo = @cPickSlipNo  
                 AND StorerKey = @cStorerkey  
                 AND CartonNo = @nCartonNo  
                 AND AddWho <> @cUserName)  
        AND @cSkipCTNInUseCFG <> '1' --TSY01  
      BEGIN  
         SET @nErrNo = 76467  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTN# IN USE  
         SET @cOutField06 = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 6  
         GOTO Quit  
      END  
    
      -- (james32)    
      IF @cExtendedValidateSP <> '' AND     
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
            ' @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
       
         SET @cSQLParam =    
            '@nMobile                   INT,           ' +    
            '@nFunc                     INT,           ' +    
            '@cLangCode                 NVARCHAR( 3),  ' +    
            '@nStep                     INT,           ' +    
            '@nInputKey                 INT,           ' +    
            '@cStorerkey                NVARCHAR( 15), ' +    
            '@cOrderKey                 NVARCHAR( 10), ' +    
            '@cPickSlipNo               NVARCHAR( 10), ' +    
            '@cTrackNo                  NVARCHAR( 20), ' +    
            '@cSKU                      NVARCHAR( 20), ' +    
            '@nCartonNo                 INT,           ' +    
            '@cCtnType                  NVARCHAR( 10), ' +    
            '@cCtnWeight                NVARCHAR( 10), ' +    
            '@cSerialNo                 NVARCHAR( 30), ' +         
            '@nSerialQTY                INT,           ' +      
            '@nErrNo                    INT           OUTPUT,  ' +    
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
       
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
               @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
         IF @nErrNo <> 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            GOTO QUIT    
         END    
      END    
  
      -- Custom data capture setup        
      IF @cCaptureInfoSP = '' OR @cSKUDataCapture NOT IN ( '1', '3')       
      BEGIN        
         SET @cData1 = ''        
         SET @cData2 = ''        
         SET @cData3 = ''        
         SET @cData4 = ''  
         SET @cData5 = ''  
      END        
      ELSE        
      BEGIN  
       INSERT INTO @tCaptureVar (Variable, Value) VALUES ( '@cDataCapture', @cDataCapture)  
         
         EXEC rdt.rdt_PackByTrackNo_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'DISPLAY',   
            @cOrderKey, @cDropID, @cRefNo, @cPickSlipNo, @cData1, @cData2, @cData3, @cData4, @cData5,   
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
            @cDataCaptureInfo OUTPUT,  
            @tCaptureVar,   
            @nErrNo  OUTPUT,   
            @cErrMsg OUTPUT  
         IF @nErrNo <> 0  
            GOTO Quit  
           
         IF @cDataCaptureInfo IN ('1', '2') AND @cSKUDataCapture IN ( '1', '3')  
         BEGIN  
            -- Go to next screen  
            SET @nFromScn = @nScn  
            SET @nFromStep = @nStep  
            SET @nScn = @nScn + 5  
            SET @nStep = @nStep + 6  

            IF @cDataCaptureInfo = '1'
               GOTO Quit  

            IF @cDataCaptureInfo = '2'
               GOTO Step_9  
         END  
      END  
        
      -- Serial No        
      IF @cSerialNoCapture IN ('1', '3')  AND ISNULL(@cSerialNo,'')='' -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY        
      BEGIN        
    
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc,@nqty, 'CHECK', 'PICKSLIP', @cPickSlipNo,         
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
            SET @nFromScn=  @nScn    
            SET @nScn = 4831        
            SET @nStep = @nStep + 5        
        
            GOTO Quit        
         END        
         ELSE  
          SET @cSerialNo = ''  --Initialse serialno variable  
      END        
    
      IF ISNULL(@cPackSwapLot_SP, '') NOT IN ('', '0') AND     
         EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cPackSwapLot_SP AND type = 'P')    
      BEGIN    
         SET @nErrNo = 0    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackSwapLot_SP) +    
            ' @n_Mobile,     @c_Storerkey,  @c_OrderKey,   @c_TrackNo,    @c_PickSlipNo, ' +    
            ' @n_CartonNo,   @c_LOC,        @c_ID,         @c_SKU, ' +    
            ' @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, ' +    
            ' @c_Barcode,    @b_Success   OUTPUT,  @n_ErrNo OUTPUT,  @c_ErrMsg OUTPUT '    
    
         SET @cSQLParam =    
            '@n_Mobile         INT,           ' +    
            '@c_Storerkey      NVARCHAR( 15),  ' +    
            '@c_OrderKey       NVARCHAR( 10), ' +    
            '@c_TrackNo        NVARCHAR( 20), ' +    
            '@c_PickSlipNo     NVARCHAR( 10), ' +    
            '@n_CartonNo       INT, ' +    
            '@c_LOC            NVARCHAR( 10), ' +    
            '@c_ID             NVARCHAR( 18), ' +    
            '@c_SKU            NVARCHAR( 20), ' +    
            '@c_Lottable01     NVARCHAR( 18), ' +    
            '@c_Lottable02     NVARCHAR( 18), ' +    
            '@c_Lottable03     NVARCHAR( 18), ' +    
            '@d_Lottable04     DATETIME,      ' +    
            '@d_Lottable05     DATETIME,      ' +    
            '@c_Barcode        NVARCHAR( 40), ' +    
            '@b_Success        INT           OUTPUT, ' +    
            '@n_ErrNo          INT           OUTPUT, ' +    
            '@c_ErrMsg         NVARCHAR( 20) OUTPUT  '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @cStorerkey, @cOrderKey, @cTrackNo, @cPickSlipNo, @nCartonNo, @cLOC, @cID, @cSKU,    
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
              @cInField06, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
      ELSE    
      BEGIN    
         -- Extended insert pack info stored proc here (james16)    
         IF @cExtendedInsPackSP <> '' AND     
            EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedInsPackSP AND type = 'P')    
         BEGIN    
            SET @nErrNo = 0    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInsPackSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nQty, @nCartonNo,@cSerialNo,@nSerialQTY, @cLabelNo OUTPUT,' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile                   INT,           ' +    
               '@nFunc                     INT,           ' +    
               '@cLangCode                 NVARCHAR( 3),  ' +    
               '@nStep                     INT,           ' +    
               '@nInputKey                 INT,           ' +    
               '@cStorerkey                NVARCHAR( 15), ' +    
               '@cOrderKey                 NVARCHAR( 10), ' +    
               '@cPickSlipNo               NVARCHAR( 10), ' +    
               '@cTrackNo                  NVARCHAR( 20), ' +    
               '@cSKU                      NVARCHAR( 20), ' +    
               '@nQty                      INT,           ' +    
               '@nCartonNo                 INT,           ' +    
               '@cSerialNo                 NVARCHAR( 30), ' +     
               '@nSerialQTY                INT,           ' +    
               '@cLabelNo                  NVARCHAR( 20) OUTPUT,  ' +                         
               '@nErrNo                    INT           OUTPUT,  ' +    
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nQty, @nCartonNo,@cSerialNo,@nSerialQTY, @cLabelNo OUTPUT,    
                  @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    

            SET @cGetCartonNoCFG = rdt.RDTGetConfig( @nFunc, 'GetCartonNoCFG', @cStorerKey) --TSY01  
  
            IF @cGetCartonNoCFG = 1 --TSY01  
               SELECT @nCartonNo = CartonNo      --TSY01  
               FROM dbo.PackDetail WITH (NOLOCK) --TSY01  
               WHERE PickSlipNo = @cPickSlipNo   --TSY01  
               AND Storerkey = @cStorerkey       --TSY01  
               AND LabelNo = @cLabelNo           --TSY01  
         END    
         ELSE    
         BEGIN    
            SET @nTranCount = @@TRANCOUNT    
            BEGIN TRAN    
            SAVE TRAN CONFIRM_TRACKNO    
    
            IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)    
                       WHERE PickSlipNo = @cPickSlipNo    
                       AND Storerkey = @cStorerkey    
                       AND CartonNo = @nCartonNo    
                       AND UserName = @cUserName    
                       AND SKU = @cSKU)   -- can scan many sku into 1 carton    
            BEGIN    
               UPDATE rdt.rdtTrackLog WITH (ROWLOCK) SET    
                  Qty = ISNULL(Qty, 0) + 1,    
                  EditWho = @cUserName,    
                  EditDate = GetDate()    
               WHERE PickSlipNo = @cPickSlipNo    
               AND Storerkey = @cStorerkey    
               AND CartonNo = @nCartonNo    
               AND UserName = @cUserName    
               AND SKU = @cSKU    
    
               IF @@ERROR <> 0    
               BEGIN    
                  ROLLBACK TRAN CONFIRM_TRACKNO    
                  WHILE @@TRANCOUNT > @nTranCount    
                     COMMIT TRAN    
                  SET @nErrNo = 76468    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdLog Failed'    
                  SET @cOutField06 = ''    
                  EXEC rdt.rdtSetFocusField @nMobile, 6    
                  GOTO Quit    
               END    
            END    
            ELSE    
            BEGIN    
               INSERT INTO rdt.rdtTrackLog ( PickSlipNo, Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, CartonNo )    
               VALUES (@cPickSlipNo, @nMobile, @cUserName, @cStorerkey, @cOrderKey, @cTrackNo, @cSKU, 1, @nCartonNo  )    
    
                IF @@ERROR <> 0    
                BEGIN    
                  ROLLBACK TRAN CONFIRM_TRACKNO    
                  WHILE @@TRANCOUNT > @nTranCount    
                     COMMIT TRAN    
                  SET @nErrNo = 76469    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLog Failed'    
                  SET @cOutField06 = ''    
                  EXEC rdt.rdtSetFocusField @nMobile, 6    
                  GOTO Quit    
               END    
            END    
    
            -- Create PackHeader if not yet created    
            IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)    
            BEGIN    
               SELECT @cLoadKey = ISNULL(RTRIM(LoadKey),'')    
                    , @cRoute = ISNULL(RTRIM(Route),'')    
                    , @cConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')    
               FROM dbo.Orders WITH (NOLOCK)    
               WHERE Orderkey = @cOrderkey    
    
               INSERT INTO dbo.PACKHEADER    
               (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])    
               VALUES    
               (@cPickSlipNo, @cStorerkey, @cOrderkey, @cLoadKey, @cRoute, @cConsigneeKey, '', 0, '0')    
    
                IF @@ERROR <> 0    
                BEGIN    
                  ROLLBACK TRAN CONFIRM_TRACKNO    
                  WHILE @@TRANCOUNT > @nTranCount    
                     COMMIT TRAN    
                  SET @nErrNo = 76470    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPKHDR Failed'    
                  SET @cOutField06 = ''    
                  EXEC rdt.rdtSetFocusField @nMobile, 6    
                  GOTO Quit    
               END    
            END    
    
            -- (james07)    
            SELECT TOP 1 @cPickDetailKey = PID.PickDetailKey    
            FROM dbo.PickDetail PID WITH (NOLOCK)    
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PID.LOT = LA.LOT    
            WHERE PID.Orderkey = @cOrderKey    
            AND   PID.Storerkey = @cStorerKey    
            AND   PID.Status < '9'    
            AND   PID.SKU = @cSKU    
            AND   LA.Lottable02 = @cLottable02    
            AND   QtyMoved = 0    
    
            UPDATE PickDetail WITH (ROWLOCK) SET    
               QtyMoved = 1, Trafficcop = NULL    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               ROLLBACK TRAN CONFIRM_TRACKNO    
               WHILE @@TRANCOUNT > @nTranCount    
                  COMMIT TRAN    
               SET @nErrNo = 76496    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKDET Failed'    
               SET @cOutField06 = ''    
               EXEC rdt.rdtSetFocusField @nMobile, 6    
               GOTO Quit    
            END    
    
            -- Update PackDetail.Qty if it is already exists    
            IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                       WHERE PickSlipNo = @cPickSlipNo    
                       AND CartonNo = @nCartonNo    
                       AND SKU = @cSKU)   -- can scan many sku into 1 carton    
            BEGIN    
               UPDATE dbo.PackDetail WITH (ROWLOCK) SET    
                  Qty = Qty + 1,    
                  EditDate = GETDATE(),    
                  EditWho = 'rdt.' + sUser_sName()    
               WHERE PickSlipNo = @cPickSlipNo    
               AND CartonNo = @nCartonNo    
               AND SKU = @cSKU    
    
               IF @@ERROR <> 0    
               BEGIN    
                  ROLLBACK TRAN CONFIRM_TRACKNO    
                  WHILE @@TRANCOUNT > @nTranCount    
                     COMMIT TRAN    
                  SET @nErrNo = 76471    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKDET Failed'    
                  SET @cOutField06 = ''    
                  EXEC rdt.rdtSetFocusField @nMobile, 6    
                  GOTO Quit    
               END    
            END    
            ELSE     -- Insert new PackDetail    
            BEGIN    
               -- Check if same carton exists before. Diff sku can scan into same carton    
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                          WHERE PickSlipNo = @cPickSlipNo    
                          AND CartonNo = @nCartonNo)    
               BEGIN    
                  -- (james15)    
                  SET @cExtendedLabelNoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedLabelNoSP', @cStorerKey)    
                  IF @cExtendedLabelNoSP NOT IN ('0', '') AND     
                     EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedLabelNoSP AND type = 'P')    
                  BEGIN    
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedLabelNoSP) +    
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @cLabelNo OUTPUT, @nCartonNo OUTPUT,' +    
                        ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
                     SET @cSQLParam =    
                        '@nMobile                   INT,           ' +    
                        '@nFunc                     INT,           ' +    
                        '@cLangCode                 NVARCHAR( 3),  ' +    
                        '@nStep                     INT,           ' +    
                        '@nInputKey                 INT,           ' +    
                        '@cStorerkey                NVARCHAR( 15), ' +    
                        '@cOrderKey                 NVARCHAR( 10), ' +    
                        '@cPickSlipNo               NVARCHAR( 10), ' +    
                        '@cTrackNo                  NVARCHAR( 20), ' +    
                        '@cSKU                      NVARCHAR( 20), ' +    
                        '@cLabelNo                  NVARCHAR( 20) OUTPUT,  ' +    
                        '@nCartonNo                 INT           OUTPUT,  ' +    
                        '@nErrNo                    INT           OUTPUT,  ' +    
                        '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                          @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @cLabelNo OUTPUT, @nCartonNo OUTPUT,    
                          @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
                     IF @nErrNo <> 0    
                     BEGIN    
                        ROLLBACK TRAN CONFIRM_TRACKNO    
                        WHILE @@TRANCOUNT > @nTranCount    
                           COMMIT TRAN    
                        SET @cOutField06 = ''    
                        EXEC rdt.rdtSetFocusField @nMobile, 6    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EXT UPD FAIL'    
                        GOTO Quit    
                     END    
                  END    
                  ELSE    
                  BEGIN    
                     -- Get new LabelNo    
                     EXECUTE isp_GenUCCLabelNo    
                              @cStorerKey,    
                              @cLabelNo     OUTPUT,    
                              @bSuccess     OUTPUT,    
                              @nErrNo       OUTPUT,    
                              @cErrMsg      OUTPUT    
    
                     IF @bSuccess <> 1    
                     BEGIN    
                        ROLLBACK TRAN CONFIRM_TRACKNO    
                        WHILE @@TRANCOUNT > @nTranCount    
                           COMMIT TRAN    
                        SET @nErrNo = 76472    
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'    
                        SET @cOutField06 = ''    
                        EXEC rdt.rdtSetFocusField @nMobile, 6    
                        GOTO Quit    
                     END    
                  END    
    
                  -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign    
                  INSERT INTO dbo.PackDetail    
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)    
                  VALUES    
                     (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, 1,    
                     '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')    
               END    
               ELSE    
               BEGIN    
                  SET @cCurLabelNo = ''    
                  SET @cCurLabelLine = ''    
    
                  SELECT TOP 1 @cCurLabelNo = LabelNo FROM dbo.PackDetail WITH (NOLOCK)    
                  WHERE PickSlipNo = @cPickSlipNo    
                  AND CartonNo = @nCartonNo    
    
                  SELECT @cCurLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)    
                  FROM PACKDETAIL WITH (NOLOCK)    
                  WHERE PickSlipNo = @cPickSlipNo    
                  AND CartonNo = @nCartonNo    
    
                  -- need to use the existing labelno    
                  INSERT INTO dbo.PackDetail    
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)    
                  VALUES    
                     (@cPickSlipNo, @nCartonNo, @cCurLabelNo, @cCurLabelLine, @cStorerKey, @cSku, 1,    
                     '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')    
               END    
    
               IF @@ERROR <> 0    
               BEGIN    
                  ROLLBACK TRAN CONFIRM_TRACKNO    
                  WHILE @@TRANCOUNT > @nTranCount    
                     COMMIT TRAN    
                  SET @nErrNo = 76473    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INSPKDET Failed'    
                  SET @cOutField06 = ''    
                  EXEC rdt.rdtSetFocusField @nMobile, 6    
                  GOTO Quit    
               END    
            END    
    
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN    
         END    
      END    
    
      EXEC RDT.rdt_STD_EventLog  
         @cActionType   = '3', -- Picking  
         @cUserID       = @cUserName,  
         @nMobileNo     = @nMobile,  
         @nFunctionID   = @nFunc,  
         @cFacility     = @cFacility,  
         @cStorerKey    = @cStorerkey,  
         @cOrderKey     = @cOrderkey,  --(cc01)  
         @cTrackingNo   = @cTrackNo,   --(cc01)  
         @cSKU          = @cSKU,       --(cc01)  
         @cPickSlipNo   = @cPickSlipNo,--(cc01)  
         @nQTY          = 1            --(cc01)  
    
      -- 1 orders 1 tracking no    
      -- discrete pickslip, 1 ordes 1 pickslipno    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
      AND   Storerkey = @cStorerkey    
      AND   Status < '9'    
      AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
            ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
            ( [Status] = [Status]))    
    
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
    
      -- (james26)    
      IF @cExtendedMsgQSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedMsgQSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedMsgQSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                 @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END    
      END    
          
      IF @nExpectedQty = @nPackedQty    
         GOTO Continue_Step3    
    
      -- Extended info    
      SET @cExtendedInfo = ''    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +         
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +     
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +     
               '@nAfterStep       INT,           ' +     
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' +     
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '     
                   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                 @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,     
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT         
         END    
      END    
    
      SET @cOutField01 = @cOrderkey    
      SET @cOutField02 = @cTrackNo    
      SET @cOutField03 = @nCartonNo    
      SET @cOutField04 = @nExpectedQty    
      SET @cOutField05 = @nPackedQty    
      SET @cOutField06 = ''    
      SET @cOutField15 = @cExtendedInfo    
    
      EXEC rdt.rdtSetFocusField @nMobile, 6    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      Continue_Step3:    
      -- (james07)    
      SET @nErrNo = 0          
      IF @cExtendedUpdateSP <> '' AND     
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,' +    
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
         SET @cSQLParam =    
            '@nMobile                   INT,           ' +    
            '@nFunc                     INT,           ' +    
            '@cLangCode                 NVARCHAR( 3),  ' +    
            '@nStep                     INT,           ' +    
            '@nInputKey                 INT,           ' +    
            '@cStorerkey                NVARCHAR( 15), ' +    
            '@cOrderKey                 NVARCHAR( 10), ' +    
            '@cPickSlipNo               NVARCHAR( 10), ' +    
            '@cTrackNo                  NVARCHAR( 20), ' +    
            '@cSKU                      NVARCHAR( 20), ' +    
            '@nCartonNo                 INT,           ' +    
            '@cSerialNo                 NVARCHAR( 30), ' +         
            '@nSerialQTY                INT,           ' +      
            '@nErrNo                    INT           OUTPUT,  ' +    
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            -- Remove hardcode error no from extendedupdatesp  (james14)    
            GOTO Quit    
      END    
    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
      AND   Storerkey = @cStorerkey    
      AND   Status < '9'    
      AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
            ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
            ( [Status] = [Status]))    
        
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
    
      -- (james33)    
      IF @cCapturePackInfoSP <> ''     
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cCapturePackInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @cCartonType OUTPUT, @fCartonWeight OUTPUT, @cCapturePackInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile                   INT,           ' +    
               '@nFunc                     INT,           ' +    
               '@cLangCode                 NVARCHAR( 3),  ' +    
               '@nStep                     INT,           ' +    
               '@nInputKey                 INT,           ' +    
               '@cStorerkey                NVARCHAR( 15), ' +    
               '@cOrderKey                 NVARCHAR( 10), ' +    
               '@cPickSlipNo               NVARCHAR( 10), ' +    
               '@cTrackNo                  NVARCHAR( 20), ' +    
               '@cSKU                      NVARCHAR( 20), ' +    
               '@nCartonNo                 INT,           ' +    
               '@cCartonType               NVARCHAR( 10) OUTPUT, ' +     
               '@fCartonWeight             FLOAT         OUTPUT, ' +    
               '@cCapturePackInfo          NVARCHAR( 1)  OUTPUT,  ' +    
               '@nErrNo                    INT           OUTPUT,  ' +    
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                  @cCtnType OUTPUT, @fCartontnWeight OUTPUT, @cCapturePackInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               ROLLBACK TRAN rdt_840Step03Cfm    
               WHILE @@TRANCOUNT > @nTranCount    
                  COMMIT TRAN    
               GOTO Quit    
            END    
         END    
         ELSE    
         BEGIN    
            SET @cCapturePackInfo = @cCapturePackInfoSP    
         END    
      END    
      ELSE    
      BEGIN    
         SET @cCapturePackInfo = ''    
      END    
    
      -- Press ESC, system check if user scanned any SKU to the carton,    
      -- if yes, then go to the next screen for carton type and weight capture.    
      -- If not, then go back to screen2, and ESC to go back to screen 1.    
      IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)    
                 WHERE AddWho = @cUserName)    
      BEGIN    
         IF @cCapturePackInfo = ''    
         BEGIN    
            -- (james07)    
            -- If H&M orders and it is Sales type orders then skip weight screen and go back screen 2    
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)    
                        WHERE ListName = 'HMORDTYPE'    
                        AND   StorerKey = @cStorerKey)    
            BEGIN    
               -- If it is H&M orders and orders.stop = 'Y' and no packinfo, set default carton type (james07)    
               IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)    
                            WHERE PickSlipNo = @cPickSlipNo    
                            AND   CartonNo = @nCartonNo) AND    
                   EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)    
                            JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
                            WHERE C.ListName = 'HMORDTYPE'    
                            AND   O.OrderKey = @cOrderkey    
                            AND   O.StorerKey = @cStorerKey    
                            AND   O.Stop = 'Y')    
               BEGIN    
                  SET @cCtnType = ''    
                  SELECT @cCtnType = CartonType    
                  FROM dbo.Cartonization CZ WITH (NOLOCK)    
                  JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup    
                  WHERE StorerKey = @cStorerKey    
                  AND   UseSequence = 0    
               END    
    
               -- Not all SKU and qty has been packed then go back screen 2 for next SKU    
               IF @nExpectedQty > @nPackedQty    
               BEGIN    
                  IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)    
                              JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
                              WHERE C.ListName = 'HMORDTYPE'    
                              AND   O.OrderKey = @cOrderkey    
                              AND   O.StorerKey = @cStorerKey    
                              AND   C.Short = 'S')    
                  BEGIN    
                     -- (james38)      
                     IF @cPackSkipTrackNo IN ('', '0')      
                     BEGIN      
                        SET @cOutField01 = @cOrderkey      
                        SET @cOutField02 = ''      
         
                        SET @nScn = @nScn - 1      
                        SET @nStep = @nStep - 1      
  
                        IF @nDisAllowChangeCtnNo = 1  
                           SET @cFieldAttr03 = ''  
                             
                        GOTO Quit      
                     END      
                     ELSE      
                     BEGIN      
                        IF @cRefNo <> ''      
                           EXEC rdt.rdtSetFocusField @nMobile, 3      
                        ELSE IF @cDropID <> ''    
                           EXEC rdt.rdtSetFocusField @nMobile, 2    
                        ELSE    
                           EXEC rdt.rdtSetFocusField @nMobile, 1      
      
                        SET @cOrderKey = ''      
                        SET @cDropID = ''      
                        SET @cRefNo = ''    
    
                        -- Prep next screen var      
                        SET @cOutField01 = ''      
                        SET @cOutField02 = ''      
                        SET @cOutField03 = ''    
         
                        SET @nScn = @nScn - 2      
                        SET @nStep = @nStep - 2      
      
                        IF @nDisAllowChangeCtnNo = 1  
                           SET @cFieldAttr03 = ''  
  
                        GOTO Quit      
                     END      
                  END    
               END    
            END    
    
            -- all SKU and qty has been packed then go back screen 1 for next order else go screen 2 for next SKU    
            IF @nExpectedQty = @nPackedQty    
            BEGIN    
               IF @cExtendedPrintSP NOT IN ('0', '') AND    
                  EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')    
               BEGIN    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +    
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
                  SET @cSQLParam =    
                     '@nMobile                   INT,           ' +    
                     '@nFunc                     INT,           ' +    
                     '@cLangCode                 NVARCHAR( 3),  ' +    
                     '@nStep                     INT,           ' +    
                     '@nInputKey                 INT,           ' +    
                     '@cStorerkey                NVARCHAR( 15), ' +    
                     '@cOrderKey                 NVARCHAR( 10), ' +    
                     '@cPickSlipNo               NVARCHAR( 10), ' +    
                     '@cTrackNo                  NVARCHAR( 20), ' +    
                     '@cSKU                      NVARCHAR( 20), ' +    
                     '@nCartonNo                 INT,           ' +    
                     '@nErrNo                    INT           OUTPUT,  ' +    
                     '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                        @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
                  IF @nErrNo <> 0    
                     GOTO Quit    
               END    
    
               SET @nTranCount = @@TRANCOUNT    
               BEGIN TRAN  -- Begin our own transaction    
               SAVE TRAN rdt_840Step03Cfm -- For rollback or commit only our own transaction    
    
               IF @cAutoPackConfirm = '1' -- (james25)    
               BEGIN    
                  -- (james39)      
                  SET @nErrNo = 0      
                  EXEC rdt.rdt_PackByTrackNo_PackCfm     
                     @nMobile       = @nMobile,                 
                     @nFunc         = @nFunc,                 
                     @cLangCode     = @cLangCode,        
                     @nStep         = @nStep,                 
                     @nInputKey     = @nInputKey,                 
                     @cStorerkey    = @cStorerkey,     
                     @cPickslipno   = @cPickslipno,      
                     @cSerialNo     = @cSerialNo,     
                     @nSerialQTY    = @nSerialQTY,      
                     @nErrNo        = @nErrNo OUTPUT,        
                     @cErrMsg       = @cErrMsg OUTPUT         
    
                  IF @nErrNo <> 0    
                  BEGIN    
                     ROLLBACK TRAN rdt_840Step03Cfm    
                     WHILE @@TRANCOUNT > @nTranCount    
                        COMMIT TRAN    
                     SET @nErrNo = 90666    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ConfPackFail'    
                     GOTO Quit    
                  END    
                    
                  --(cc01)  
                  EXEC RDT.rdt_STD_EventLog    
                  @cActionType   = '3', -- Picking    
                  @cUserID       = @cUserName,    
                  @nMobileNo     = @nMobile,    
                  @nFunctionID   = @nFunc,    
                  @cFacility     = @cFacility,    
                  @cStorerKey    = @cStorerkey,    
                  @cOrderKey     = @cOrderkey,    
                  @cTrackingNo   = @cTrackNo,     
                  @cSKU          = @cSKU,         
                  @cPickSlipNo   = @cPickSlipNo,  
                  @nQTY          = @nPackedQty,    
                  @cStatus       = '9'  
               END    
    
               WHILE @@TRANCOUNT > @nTranCount    
                  COMMIT TRAN    
    
               SET @cOrderKey = ''    
               SET @cOutField01 = ''    
               SET @cOutField02 = ''    
    
               -- If config turn on then show "Pick & Pack Completed" screnn    
               IF @cShowPackCompletedScn = '1'    
               BEGIN    
                  SET @nScn = @nScn + 2    
                  SET @nStep = @nStep + 2    
               END    
               ELSE    
               BEGIN    
                  -- (james31)      
                  IF @cRefNo <> ''      
                     EXEC rdt.rdtSetFocusField @nMobile, 3      
                  ELSE IF @cDropID <> ''    
                     EXEC rdt.rdtSetFocusField @nMobile, 2    
                  ELSE    
                     EXEC rdt.rdtSetFocusField @nMobile, 1      
    
      
                  SET @cOrderKey = ''      
                  SET @cDropID = ''      
                  SET @cRefNo = ''    
    
                  -- Prep next screen var      
                  SET @cOutField01 = ''      
                  SET @cOutField02 = ''      
                  SET @cOutField03 = ''    
    
                  SET @nScn = @nScn - 2      
                  SET @nStep = @nStep - 2      
               END    
  
               IF @nDisAllowChangeCtnNo = 1  
                  SET @cFieldAttr03 = ''  
  
               GOTO QUIT    
            END    
         END    
    
         IF @cHideWeightInput = '1'    
            SET @cFieldAttr05 = 'O'    
         ELSE    
            SET @cFieldAttr05 = ''    
    
         -- (james29)    
         IF @cHideCartonInput <> ''    
         BEGIN    
            -- If svalue is a stored proc then let it to decide what to do    
            IF @cHideCartonInput <> '1' AND     
               EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cHideCartonInput AND type = 'P')    
            BEGIN    
               SET @cCtnTypeEnabled = ''    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cHideCartonInput) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
                  ' @cCtnType OUTPUT, @cCtnTypeEnabled OUTPUT '    
    
               SET @cSQLParam =    
                  '@nMobile                   INT,           ' +    
                  '@nFunc                     INT,           ' +    
                  '@cLangCode                 NVARCHAR( 3),  ' +    
                  '@nStep                     INT,           ' +    
                  '@nInputKey                 INT,           ' +    
                  '@cStorerkey                NVARCHAR( 15), ' +    
                  '@cOrderKey                 NVARCHAR( 10), ' +    
                  '@cPickSlipNo               NVARCHAR( 10), ' +    
                  '@cTrackNo                  NVARCHAR( 20), ' +    
                  '@cSKU                      NVARCHAR( 20), ' +    
                  '@nCartonNo                 INT,           ' +    
                  '@cCtnType                  NVARCHAR( 10) OUTPUT, ' +    
                  '@cCtnTypeEnabled           NVARCHAR( 1)  OUTPUT  '     
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                     @cCtnType OUTPUT, @cCtnTypeEnabled OUTPUT    
    
               SET @cFieldAttr04 = @cCtnTypeEnabled    
            END    
            ELSE    
            BEGIN    
               IF @cHideCartonInput = '1' SET @cFieldAttr04 = 'O'    
            END    
         END    
         ELSE    
            SET @cFieldAttr04 = ''    
          
         -- (james46)    
         IF ISNULL( @cCtnType, '') = ''     
            SET @cCtnType = @cDefaultCartonType    
    
         SET @cOutField01 = @cOrderkey    
         SET @cOutField02 = @cTrackNo    
         SET @cOutField03 = @nCartonNo    
         SET @cOutField04 = CASE WHEN ISNULL( @cCtnType, '') = '' THEN '' ELSE @cCtnType END    
         SET @cOutField05 = CASE WHEN ISNULL( @fCartontnWeight, 0) <> 0 THEN @fCartontnWeight ELSE '' END    
    
         EXEC rdt.rdtSetFocusField @nMobile, 4    
    
         SET @nScn = @nScn + 1    
         SET @nStep = @nStep + 1    
  
         IF @nDisAllowChangeCtnNo = 1  
            SET @cFieldAttr03 = ''  

         -- Extended info
         SET @cExtendedInfo = ''
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' + 
                  ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  '@nMobile          INT,           ' +
                  '@nFunc            INT,           ' +
                  '@cLangCode        NVARCHAR( 3),  ' +
                  '@nStep            INT,           ' + 
                  '@nAfterStep       INT,           ' + 
                  '@nInputKey        INT,           ' +
                  '@cStorerkey       NVARCHAR( 15), ' +
                  '@cOrderKey        NVARCHAR( 10), ' +
                  '@cPickSlipNo      NVARCHAR( 10), ' +
                  '@cTrackNo         NVARCHAR( 20), ' +
                  '@cSKU             NVARCHAR( 20), ' +
                  '@nCartonNo        INT,           ' +
                  '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' + 
                  '@nErrNo           INT           OUTPUT, ' +
                  '@cErrMsg          NVARCHAR( 20) OUTPUT  ' 
               
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                    @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo, 
                    @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     

               SET @cOutField15 = @cExtendedInfo
            END
         END
         
         IF @cFlowThruCtnTypeScn = '1'    
         BEGIN    
            -- Set default value to input field (if any)    
            SET @cInField04 = CASE WHEN ISNULL( @cCtnType, '') = '' THEN '' ELSE @cCtnType END    
            SET @cInField05 = CASE WHEN ISNULL( @fCartontnWeight, 0) <> 0 THEN @fCartontnWeight ELSE '' END    
            SET @nInputKey = 1    
            GOTO Step_4    
         END    
      END    
      ELSE    
      BEGIN    
         GO_BACK_SCN2:     -- (james01)    
         -- (james08)    
         IF rdt.RDTGetConfig( @nFunc, 'PACKSKIPTRACKNO', @cStorerkey) IN ('', '0')    
         BEGIN    
            SET @cOutField01 = @cOrderkey    
            SET @cOutField02 = ''    
    
            SET @nScn = @nScn - 1    
            SET @nStep = @nStep - 1    
    
            --GOTO QUIT    
         END    
         ELSE    
         BEGIN    
            -- (james31)    
            IF @cRefNo <> ''      
               EXEC rdt.rdtSetFocusField @nMobile, 3      
            ELSE IF @cDropID <> ''    
               EXEC rdt.rdtSetFocusField @nMobile, 2    
            ELSE    
               EXEC rdt.rdtSetFocusField @nMobile, 1      
    
            SET @cOrderKey = ''    
            SET @cTrackNo = ''    
            SET @cDropID = ''    
            SET @cRefNo = ''    
    
            SET @cOutField01 = ''    
            SET @cOutField02 = ''    
            SET @cOutField03 = ''    
    
            SET @nScn = @nScn - 2    
            SET @nStep = @nStep - 2    
         END    
  
         IF @nDisAllowChangeCtnNo = 1  
            SET @cFieldAttr03 = ''  
  
         -- Extended info    
         SET @cExtendedInfo = ''    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = ''    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +         
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +     
                  ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
               SET @cSQLParam =        
                  '@nMobile          INT,           ' +    
                  '@nFunc            INT,           ' +    
                  '@cLangCode        NVARCHAR( 3),  ' +    
                  '@nStep            INT,           ' +     
                  '@nAfterStep       INT,           ' +     
                  '@nInputKey        INT,           ' +    
                  '@cStorerkey       NVARCHAR( 15), ' +    
                  '@cOrderKey        NVARCHAR( 10), ' +    
                  '@cPickSlipNo      NVARCHAR( 10), ' +    
                  '@cTrackNo         NVARCHAR( 20), ' +    
                  '@cSKU             NVARCHAR( 20), ' +    
                  '@nCartonNo        INT,           ' +    
                  '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' +     
                  '@nErrNo           INT           OUTPUT, ' +    
                  '@cErrMsg          NVARCHAR( 20) OUTPUT  '     
                      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                     @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,     
                     @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT         
       
               SET @cOutField15 = @cExtendedInfo    
            END    
         END    
      END
   END    
   GOTO Quit    
    
   Step_3_Fail:    
    
END    
GOTO Quit    
    
/********************************************************************************    
Step 4. screen = 3123    
   Orderkey (Field01)    
   Track No (Field02)    
   CTN No   (Field03, Input)    
   QTY EXP  (Field04)    
   QTY PICK (Field05)    
   SKU      (Field06, Input)    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cCtnType = ISNULL(RTRIM(@cInField04),'')    
      SET @cCtnWeight = LTRIM( ISNULL( @cInField05, '0'))   -- (james22)    
    
      -- If carton type is blank and field is enabled then check blank value    
      IF ISNULL(@cCtnType, '') = '' AND @cFieldAttr04 <> 'O'-- (james29)    
      BEGIN    
         SET @nErrNo = 76474    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CTN TYPE REQ'    
         SET @cOutField04 = ''    
         SET @cOutField05 = @cCtnWeight    
         EXEC rdt.rdtSetFocusField @nMobile, 4    
         GOTO Quit    
      END    
      ELSE    
      BEGIN    
         IF ISNULL(@cCtnType, '') <> ''    
         BEGIN    
            -- (james03)    
            DECLARE @fCube FLOAT    
            SELECT @fCube = Cube    
            FROM Cartonization CZ WITH (NOLOCK)    
               JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup    
            WHERE CZ.CartonType = @cCtnType    
               AND ST.StorerKey = @cStorerkey    
    
            IF @@ROWCOUNT = 0    
            BEGIN    
               SET @nErrNo = 76491    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV CTN TYPE'    

               IF @cShowErrMsgInNewScn = '1' -- (james52)  
               BEGIN  
                  SET @cErrMsg1 = @cErrMsg  
                  SET @nErrNo = 0  
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1  
                  IF @nErrNo = 1  
                     SET @cErrMsg1 = ''  
                  SET @nErrNo = 76491
               END  

               SET @cOutField04 = ''    
               SET @cOutField05 = @cCtnWeight    
               EXEC rdt.rdtSetFocusField @nMobile, 4    
               GOTO Quit    
            END    
         END    
      END    
    
      -- (james07)    
      IF @cHideWeightInput <> '1'    
      BEGIN    
         IF ISNULL(@cCtnWeight, '') = ''    
         BEGIN    
            SET @nErrNo = 76475    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CTN WGT REQ'    
            SET @cOutField04 = @cCtnType    
            SET @cOutField05 = ''    
            EXEC rdt.rdtSetFocusField @nMobile, 5    
            GOTO Quit    
         END    
    
         -- Check weight for decimal, cannot -ve and cannot 0    
         IF rdt.rdtIsValidQTY( @cCtnWeight, 21) <> 1    
         BEGIN    
            SET @nErrNo = 76476    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV CTN WGT'    
            SET @cOutField04 = @cCtnType    
            SET @cOutField05 = ''    
            EXEC rdt.rdtSetFocusField @nMobile, 5    
            GOTO Quit    
         END    
           
         -- (james49)  
         IF @cNotConvertWgt2KG = '0'  
            SET @fCtnWeight = CAST(@cCtnWeight AS FLOAT) * 1000    
         ELSE  
            SET @fCtnWeight = CAST(@cCtnWeight AS FLOAT)  
  
         -- (james03)    
         SET @cMaxCtnWeight = rdt.RDTGetConfig( @nFunc, 'MaxWeight', @cStorerKey)    
    
         IF (@cNotConvertWgt2KG = '0' AND @fCtnWeight > (CAST(@cMaxCtnWeight AS FLOAT) * 1000)) OR  
            (@cNotConvertWgt2KG = '1' AND @fCtnWeight > (CAST(@cMaxCtnWeight AS FLOAT))) -- (james49)  
         BEGIN    
            SET @nErrNo = 76492    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EXCEED MAX WGT'    
            SET @cOutField04 = @cCtnType    
            SET @cOutField05 = ''    
            EXEC rdt.rdtSetFocusField @nMobile, 5    
            GOTO Quit    
         END    
      END    
    
      -- (james17)    
      IF @cExtendedValidateSP <> '' AND     
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
            ' @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
       
         SET @cSQLParam =    
            '@nMobile                   INT,           ' +    
            '@nFunc                     INT,           ' +    
            '@cLangCode                 NVARCHAR( 3),  ' +    
            '@nStep                     INT,           ' +    
            '@nInputKey                 INT,           ' +    
            '@cStorerkey                NVARCHAR( 15), ' +    
            '@cOrderKey                 NVARCHAR( 10), ' +    
            '@cPickSlipNo               NVARCHAR( 10), ' +    
            '@cTrackNo                  NVARCHAR( 20), ' +    
            '@cSKU                      NVARCHAR( 20), ' +    
            '@nCartonNo                 INT,           ' +    
            '@cCtnType                  NVARCHAR( 10), ' +    
            '@cCtnWeight                NVARCHAR( 10), ' +    
            '@cSerialNo                 NVARCHAR( 30), ' +         
            '@nSerialQTY                INT,           ' +      
            '@nErrNo                    INT           OUTPUT,  ' +    
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
       
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
               @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
         IF @nErrNo <> 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')     
            GOTO QUIT    
         END    
      END    
    
      SET @cUpdTrackingNo = ''    
      SELECT @cUpdTrackingNo = Short    
      FROM dbo.CODELKUP WITH (NOLOCK)    
      WHERE LISTNAME = 'PackInfo'    
      AND   Code = 'TrackingNo'    
      AND   Storerkey = @cStorerKey    
      AND   code2 = @nFunc    
          
      -- (james27)    
      SET @nErrNo = 0    
      SET @nTranCount = @@TRANCOUNT    
      BEGIN TRAN    
      SAVE TRAN CONFIRM_PACKINFO    
    
      IF EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)    
                 WHERE PickSlipNo = @cPickSliPno    
                 AND CartonNo = @nCartonNo)    
      BEGIN    
         -- (james07)    
         UPDATE dbo.PackInfo WITH (ROWLOCK) SET    
            Weight = CASE WHEN @cHideWeightInput <> '1' THEN @fCtnWeight ELSE Weight END,    
            Cube = @fCube,    
            CartonType = @cCtnType,    
            TrackingNo = CASE WHEN @cUpdTrackingNo = 'R' THEN @cTrackNo ELSE TrackingNo END,    
            EditDate = GETDATE(),    
            EditWho = 'rdt.' + sUser_sName()    
         WHERE PickSlipNo = @cPickSliPno    
         AND CartonNo = @nCartonNo    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 76477    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKINFO Failed'    
            SET @cOutField04 = @cCtnType    
            SET @cOutField04 = @cCtnWeight    
            EXEC rdt.rdtSetFocusField @nMobile, 4    
            GOTO RollBackTran    
        END    
      END    
      ELSE  -- Insert new PackInfo    
      BEGIN    
         INSERT INTO dbo.PACKINFO    
         (PickSlipNo, CartonNo, CartonType, Cube, WEIGHT, TrackingNo)    
         VALUES    
         (@cPickSlipNo, @nCartonNo, @cCtnType, @fCube,    
         CASE WHEN @cHideWeightInput <> '1' THEN @fCtnWeight ELSE 0 END,    -- (james07)    
         CASE WHEN @cUpdTrackingNo = 'R' THEN @cTrackNo ELSE '' END)    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 76478    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INSPKINFO Failed'    
            SET @cOutField04 = @cCtnType    
            SET @cOutField04 = @cCtnWeight    
            EXEC rdt.rdtSetFocusField @nMobile, 4    
            GOTO RollBackTran    
         END    
      END    
    
      -- 1 orders 1 tracking no    
      -- discrete pickslip, 1 ordes 1 pickslipno    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
      AND   Storerkey = @cStorerkey    
      AND   Status < '9'    
      AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
            ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
            ( [Status] = [Status]))    
          
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
    
      -- all SKU and qty has been packed, Update the carton barcode to the PackDetail.UPC for each carton    
      IF @nExpectedQty = @nPackedQty    
      BEGIN    
         /*    
         Order box barcode: 20 digits, Code 128 barcode codification, divided into 5 blocks:    
         3 digits: Hardcode â€˜021â€™.    
         12 digits: Orders.OrderKey (10digits) + Current CartonNo (2 digits, e.g. 01, 02â€¦)    
         3 digits: Total carton box in the order (e.g. 002)    
         1 digit: Hardcode â€˜1â€™    
         1 digit: Barcodeâ€™s check digit, refer to the below java code.    
         */    
    
         SELECT @nCtnCount = ISNULL(COUNT( DISTINCT CartonNo), 0)    
         FROM dbo.PackDetail WITH ( NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
    
         IF @nCtnCount > 0    
         BEGIN    
            DECLARE CUR_PACKDTL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
            SELECT DISTINCT CartonNo FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE PickSlipNo = @cPickSlipNo    
            ORDER BY CartonNo    
            OPEN CUR_PACKDTL    
            FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo    
            WHILE @@FETCH_STATUS <> -1    
            BEGIN    
               -- (james12)    
               SET @cUPCCode = ''    
               SELECT @cUPCCode = Code FROM dbo.CODELKUP WITH (NOLOCK)     
               WHERE ListName = 'WHUPCCODE'     
               AND   StorerKey = @cStorerKey    
    
               -- Generateorder box barcode    
               SET @cTempBarcode = ''    
               SET @cTempBarcode = CASE WHEN ISNULL( @cUPCCode, '') = '' THEN '021' ELSE RTRIM( @cUPCCode) END    
               SET @cTempBarcode = RTRIM(@cTempBarcode) + RTRIM(@cOrderKey)    
               SET @cTempBarcode = RTRIM(@cTempBarcode) + RIGHT( '00' + CAST( @nCtnNo AS NVARCHAR( 2)), 2)    
               SET @cTempBarcode = RTRIM(@cTempBarcode) + RIGHT( '000' + CAST( @nCtnCount AS NVARCHAR( 3)), 3)    
               SET @cTempBarcode = RTRIM(@cTempBarcode) + '1'    
               SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcode), 0)    
               SET @cOrderBoxBarcode = RTRIM(@cTempBarcode) + @cCheckDigit    
    
               UPDATE dbo.PackDetail WITH (ROWLOCK) SET    
                  UPC = CASE WHEN @cPackByTrackNotUpdUPC = '1' THEN UPC ELSE @cOrderBoxBarcode END,    
                  ArchiveCop = NULL,    
                  EditWho = 'rdt.' + sUser_sName(),    
                  EditDate = GETDATE()    
               WHERE PickSlipNo = @cPickSlipNo    
                  AND CartonNo = @nCtnNo    
    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 76479    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD BOX Failed'    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField04 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  CLOSE CUR_PACKDTL    
                  DEALLOCATE CUR_PACKDTL    
                  GOTO RollBackTran    
               END    
    
               FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo    
            END    
            CLOSE CUR_PACKDTL    
            DEALLOCATE CUR_PACKDTL    
    
            -- Trigger pack confirm    
            -- (james39)      
            SET @nErrNo = 0      
            EXEC rdt.rdt_PackByTrackNo_PackCfm       
               @nMobile       = @nMobile,                 
               @nFunc         = @nFunc,                 
               @cLangCode     = @cLangCode,        
               @nStep         = @nStep,                 
               @nInputKey     = @nInputKey,                 
               @cStorerkey    = @cStorerkey,       
               @cPickslipno   = @cPickslipno,       
               @cSerialNo     = @cSerialNo,     
               @nSerialQTY    = @nSerialQTY,    
               @nErrNo        = @nErrNo OUTPUT,        
               @cErrMsg       = @cErrMsg OUTPUT          
      
            IF @nErrNo <> 0      
            BEGIN    
               SET @nErrNo = 76480    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CFM PACKHDR Failed'    
               SET @cOutField04 = @cCtnType    
               SET @cOutField04 = @cCtnWeight    
               EXEC rdt.rdtSetFocusField @nMobile, 4    
               GOTO RollBackTran    
            END    
              
            --(cc01)  
            EXEC RDT.rdt_STD_EventLog    
            @cActionType   = '3', -- Picking    
            @cUserID       = @cUserName,    
            @nMobileNo     = @nMobile,    
            @nFunctionID   = @nFunc,    
            @cFacility     = @cFacility,    
            @cStorerKey    = @cStorerkey,    
            @cOrderKey     = @cOrderkey,    
            @cTrackingNo   = @cTrackNo,     
            @cSKU          = @cSKU,         
            @cPickSlipNo   = @cPickSlipNo,  
            @nQTY          = @nPackedQty,  
            @cStatus       = '9'    

            -- (james05)    
            IF @cExtendedUpdateSP <> '' AND     
               EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,' +    
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
               SET @cSQLParam =    
                  '@nMobile                   INT,           ' +    
                  '@nFunc                     INT,           ' +    
                  '@cLangCode                 NVARCHAR( 3),  ' +    
                  '@nStep                     INT,           ' +    
                  '@nInputKey                 INT,           ' +    
                  '@cStorerkey                NVARCHAR( 15), ' +    
                  '@cOrderKey                 NVARCHAR( 10), ' +    
                  '@cPickSlipNo               NVARCHAR( 10), ' +    
                  '@cTrackNo                  NVARCHAR( 20), ' +    
                  '@cSKU                      NVARCHAR( 20), ' +    
                  '@nCartonNo                 INT,           ' +    
                  '@cSerialNo                 NVARCHAR( 30), ' +         
                  '@nSerialQTY                INT,           ' +      
                  '@nErrNo                    INT           OUTPUT,  ' +    
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,    
                     @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField04 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO RollBackTran    
               END    
            END    
         END    
    
         GOTO CommitTrans    
    
         RollBackTran:    
            ROLLBACK TRAN CONFIRM_PACKINFO    
    
         CommitTrans:    
         WHILE @@TRANCOUNT > @nTranCount    
            COMMIT TRAN    
    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         -- (james08)    
         SET @nPrinted = 0    
         IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)     
                     WHERE StorerKey = @cStorerKey    
                     AND   OrderKey = @cOrderKey    
                     AND   RDS = '0')  -- non gift type orders    
         BEGIN    
            -- Print only if rdt report is setup (james05)    
            IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)    
                        WHERE StorerKey = @cStorerKey    
                        AND   ReportType = 'RTNTICKET'    
                        AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1    
                                 ELSE 0 END)    
            BEGIN    
               -- Printing process    
               -- Print the A5 return ticket    
               IF ISNULL(@cPrinter_Paper, '') = ''    
               BEGIN    
                  SET @nErrNo = 76482    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
    
               SET @cReportType = 'RTNTICKET'    
               SET @cPrintJobName = 'PRINT_RTNTICKET'    
    
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                        @cTargetDB = ISNULL(RTRIM(TargetDB), '')    
               FROM RDT.RDTReport WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
               AND   ReportType = @cReportType    
    
               IF ISNULL(@cDataWindow, '') = ''    
               BEGIN    
                  SET @nErrNo = 76483    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
    
               IF ISNULL(@cTargetDB, '') = ''    
               BEGIN    
                  SET @nErrNo = 76484    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
    
               SET @nErrNo = 0    
               EXEC RDT.rdt_BuiltPrintJob    
                  @nMobile,    
                  @cStorerKey,    
                  @cReportType,    
                  @cPrintJobName,    
                  @cDataWindow,    
                  @cPrinter_Paper,    
                  @cTargetDB,    
                  @cLangCode,    
                  @nErrNo  OUTPUT,    
                  @cErrMsg OUTPUT,    
                  @cStorerKey,    
                  @cOrderKey    
    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @nErrNo = 76485    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
               ELSE  -- (james08)    
               BEGIN    
                  IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)    
                              WHERE StorerKey = @cStorerKey    
                              AND   ReportType = @cReportType    
                              AND   Function_ID IN (0, @nFunc))    
                     SET @nPrinted = @nPrinted + 1    
               END    
            END   -- end print    
         END    
         ELSE  -- (james09)    
         BEGIN    
            -- Print only if rdt report is setup (james05)    
            IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)    
                        WHERE StorerKey = @cStorerKey    
                        AND   ReportType = 'GIFTTICKET'    
                        AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1    
                                 ELSE 0 END)    
            BEGIN    
               -- Printing process    
               -- Print the A5 return ticket    
               IF ISNULL(@cPrinter_Paper, '') = ''    
               BEGIN    
                  SET @nErrNo = 90653    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
    
               SET @cReportType = 'GIFTTICKET'    
               SET @cPrintJobName = 'PRINT_GIFTTICKET'    
    
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                        @cTargetDB = ISNULL(RTRIM(TargetDB), '')    
               FROM RDT.RDTReport WITH (NOLOCK)    
               WHERE StorerKey = @cStorerKey    
               AND   ReportType = @cReportType    
    
               IF ISNULL(@cDataWindow, '') = ''    
               BEGIN    
                  SET @nErrNo = 90654    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
    
               IF ISNULL(@cTargetDB, '') = ''    
               BEGIN    
                  SET @nErrNo = 90655    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight                      
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
    
               SET @nErrNo = 0    
               EXEC RDT.rdt_BuiltPrintJob    
                  @nMobile,    
                  @cStorerKey,    
                  @cReportType,    
                  @cPrintJobName,    
                  @cDataWindow,    
                  @cPrinter_Paper,    
                  @cTargetDB,    
                  @cLangCode,    
                  @nErrNo  OUTPUT,    
                  @cErrMsg OUTPUT,    
                  @cStorerKey,    
                  @cOrderKey    
    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @nErrNo = 90656    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
               ELSE  -- (james08)    
               BEGIN    
                  IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)    
                              WHERE StorerKey = @cStorerKey    
                              AND   ReportType = @cReportType    
                              AND   Function_ID IN (0, @nFunc))    
                     SET @nPrinted = @nPrinted + 1    
               END    
    
               SELECT @cNotes2 = ORDERS.Notes2, @cOrderInfo01 = ORDERINFO.OrderInfo01    
               FROM dbo.ORDERS WITH (NOLOCK)     
               LEFT OUTER JOIN dbo.ORDERINFO WITH (NOLOCK) ON ( ORDERS.ORDERKEY = ORDERINFO.ORDERKEY)    
               WHERE ORDERS.StorerKey = @cStorerKey     
               AND ORDERS.OrderKey = @cOrderKey     
    
               -- Printing process    
               -- Print the gift sheet label    
               -- If one of the field is not empty then need print gift label    
               IF ISNULL( @cNotes2, '') <> '' OR ISNULL( @cOrderInfo01, '') <> ''    
               BEGIN    
                  IF ISNULL(@cPrinter_Paper, '') = ''    
                  BEGIN    
                     SET @nErrNo = 90657    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter    
                     SET @cOutField04 = @cCtnType    
                     SET @cOutField05 = @cCtnWeight    
                     EXEC rdt.rdtSetFocusField @nMobile, 4    
                     GOTO Quit    
                  END    
    
                  SET @cPrintJobName = 'PRINT_GIFTLABEL'    
    
                  -- Extended info    
                  SET @cExtendedInfo = ''    
                  IF @cExtendedInfoSP <> ''    
                  BEGIN    
                     IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
                     BEGIN    
                        SET @cExtendedInfo = @cPrintJobName  -- subsitute @cExtendedInfo with @cPrintJobName as extra checking parameter passed in    
                        SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
                           ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                        SET @cSQLParam =    
                           '@nMobile          INT,           ' +    
                           '@nFunc            INT,           ' +    
                           '@cLangCode        NVARCHAR( 3),  ' +    
                           '@nStep            INT,           ' +    
                           '@nAfterStep       INT,           ' +    
                           '@nInputKey        INT,           ' +    
                           '@cStorerkey       NVARCHAR( 15), ' +    
                           '@cOrderKey        NVARCHAR( 10), ' +    
                           '@cPickSlipNo      NVARCHAR( 10), ' +    
                           '@cTrackNo         NVARCHAR( 20), ' +    
                           '@cSKU             NVARCHAR( 20), ' +    
                           '@nCartonNo        INT,           ' +    
                           '@cExtendedInfo    NVARCHAR( 20) OUTPUT,  ' +    
                           '@nErrNo           INT           OUTPUT,  ' +    
                           '@cErrMsg          NVARCHAR( 20) OUTPUT   '    
    
                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                              @nMobile, @nFunc, @cLangCode, @nStep, 5, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                              @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
                                  
                        SET @cReportType = CASE WHEN RTRIM( ISNULL( @cExtendedInfo, '')) = RTRIM( ISNULL( @cPrintJobName, '')) THEN 'GIFTLABEL1' ELSE @cExtendedInfo END    
                     END    
                  END    
    
                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                           @cTargetDB = ISNULL(RTRIM(TargetDB), '')    
                  FROM RDT.RDTReport WITH (NOLOCK)    
                  WHERE StorerKey = @cStorerKey    
                  AND   ReportType = @cReportType    
    
                  IF ISNULL(@cDataWindow, '') = ''    
                  BEGIN    
                     SET @nErrNo = 90658    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP    
                     SET @cOutField04 = @cCtnType    
                     SET @cOutField05 = @cCtnWeight    
                     EXEC rdt.rdtSetFocusField @nMobile, 4    
                     GOTO Quit    
                  END    
    
                  IF ISNULL(@cTargetDB, '') = ''    
                  BEGIN    
                     SET @nErrNo = 90659    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET    
                     SET @cOutField04 = @cCtnType    
                     SET @cOutField05 = @cCtnWeight    
                     EXEC rdt.rdtSetFocusField @nMobile, 4    
                     GOTO Quit    
                  END    
    
                  SET @nErrNo = 0    
                  EXEC RDT.rdt_BuiltPrintJob    
                     @nMobile,    
                     @cStorerKey,    
                     @cReportType,    
                     @cPrintJobName,    
                     @cDataWindow,    
                     @cPrinter_Paper,    
                     @cTargetDB,    
                     @cLangCode,    
                     @nErrNo  OUTPUT,    
                     @cErrMsg OUTPUT,    
                     @cStorerKey,    
                     @cOrderKey    
    
                  IF @nErrNo <> 0    
                  BEGIN    
                     SET @nErrNo = 90660    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL    
                     SET @cOutField04 = @cCtnType    
                     SET @cOutField05 = @cCtnWeight    
                     EXEC rdt.rdtSetFocusField @nMobile, 4    
                     GOTO Quit    
                  END    
                  ELSE  -- (james08)    
                  BEGIN    
                     IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)    
                                 WHERE StorerKey = @cStorerKey    
                                 AND   ReportType = @cReportType    
                                 AND   Function_ID IN (0, @nFunc))    
                        SET @nPrinted = @nPrinted + 1    
                  END    
               END    
            END   -- end print    
         END    
    
         -- Print only if rdt report is setup (james05)    
         IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)    
                     WHERE StorerKey = @cStorerKey    
                     AND   ReportType = 'ORDERLABEL'    
           AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1    
                              ELSE 0 END)    
         BEGIN    
            -- If Orders.Priority ='4', then need to print the order box label,    
            -- if Orders.Priority ='1' or '2' or '3', then do not print order box label.    
            -- For A5 report, all orders need to print this report.    
            SET @cPriority = ''    
            SELECT @cPriority = Priority    
            FROM dbo.Orders WITH (NOLOCK)    
            WHERE StorerKey = @cStorerKey    
            AND   OrderKey = @cOrderKey    
    
            IF ISNULL(@cPriority, '') = '4'    
            BEGIN    
               -- Print the label    
               IF ISNULL(@cPrinter, '') = ''    
               BEGIN    
                  SET @nErrNo = 76486    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
    
               -- If label setup in bartender then skip printing using rdtspooler (james06)    
               IF NOT EXISTS ( SELECT 1 FROM dbo.BartenderLabelCfg WITH (NOLOCK)    
                                 WHERE StorerKey = @cStorerKey    
                                 AND   LabelType = 'BOXLABEL')    
               BEGIN    
                  SET @cReportType = 'ORDERLABEL'    
                  SET @cPrintJobName = 'PRINT_ORDERLABEL'    
    
                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                           @cTargetDB = ISNULL(RTRIM(TargetDB), '')    
                  FROM RDT.RDTReport WITH (NOLOCK)    
                  WHERE StorerKey = @cStorerKey    
                  AND   ReportType = @cReportType    
    
                  IF ISNULL(@cDataWindow, '') = ''    
                  BEGIN    
                     SET @nErrNo = 76487    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP    
                     SET @cOutField04 = @cCtnType    
                     SET @cOutField05 = @cCtnWeight    
                     EXEC rdt.rdtSetFocusField @nMobile, 4    
                     GOTO Quit    
                  END    
    
                  IF ISNULL(@cTargetDB, '') = ''    
                  BEGIN    
                     SET @nErrNo = 76488    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET    
                    SET @cOutField04 = @cCtnType    
                     SET @cOutField05 = @cCtnWeight    
                     EXEC rdt.rdtSetFocusField @nMobile, 4    
                     GOTO Quit    
                  END    
    
                  SET @nErrNo = 0    
                  EXEC RDT.rdt_BuiltPrintJob    
                     @nMobile,    
                     @cStorerKey,    
                     @cReportType,    
                     @cPrintJobName,    
                     @cDataWindow,    
                     @cPrinter,    
                     @cTargetDB,    
                     @cLangCode,    
                     @nErrNo  OUTPUT,    
                     @cErrMsg OUTPUT,    
                     @cStorerKey,    
                     @cOrderKey    
    
                  IF @nErrNo <> 0    
                  BEGIN    
                     SET @nErrNo = 76489    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL    
                     SET @cOutField04 = @cCtnType    
                     SET @cOutField05 = @cCtnWeight    
                     EXEC rdt.rdtSetFocusField @nMobile, 4    
                     GOTO Quit    
                  END    
                  ELSE  -- (james08)    
                  BEGIN    
                     IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)    
                                 WHERE StorerKey = @cStorerKey    
                                 AND   ReportType = @cReportType    
                                 AND   Function_ID IN (0, @nFunc))    
                        SET @nPrinted = @nPrinted + 1    
                  END    
               END    
               ELSE    
               BEGIN    
                  -- Call Bartender standard SP    
                  EXECUTE dbo.isp_BT_GenBartenderCommand    
                     @cPrinterID     = @cPrinter,     -- printer id    
                     @c_LabelType    = 'BOXLABEL',    -- label type    
                     @c_userid       = @cUserName,    -- user id    
                     @c_Parm01       = @cStorerKey,   -- parm01    
                     @c_Parm02       = @cOrderKey,    -- parm02    
                     @c_Parm03       = '',            -- parm03    
                     @c_Parm04       = '',            -- parm04    
                     @c_Parm05       = '',            -- parm05    
                     @c_Parm06       = '',            -- parm06    
                     @c_Parm07       = '',            -- parm07    
                     @c_Parm08       = '',            -- parm08    
                     @c_Parm09       = '',            -- parm09    
                     @c_Parm10       = '',            -- parm10    
                     @c_StorerKey    = @cStorerKey,   -- StorerKey    
                     @c_NoCopy       = '1',   -- no of copy    
                     @b_Debug        = @bDebug,    
                     @c_Returnresult = '',            -- return result    
                     @n_err          = @nErrNo        OUTPUT,    
                     @c_errmsg       = @cErrMsg       OUTPUT    
    
                  IF @nErrNo <> 0    
                  BEGIN    
                     SET @nErrNo = 76489    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL    
                     SET @cOutField04 = @cCtnType    
                     SET @cOutField05 = @cCtnWeight    
                     EXEC rdt.rdtSetFocusField @nMobile, 4    
                     GOTO Quit    
                  END    
                  ELSE  -- (james08)    
                     SET @nPrinted = @nPrinted + 1    
               END   -- end print    
            END    
         END    
    
         -- Print only if rdt report is setup (james08)    
         IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)    
                     WHERE StorerKey = @cStorerKey    
                     AND   ReportType = 'SHIPPLABEL'    
                     AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1    
                                                   ELSE 0 END)    
         BEGIN    
            SET @nIsMoveOrders = 0      
            -- If it is a Move type orders then no need print ship label          
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)           
                        JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)          
                        WHERE C.ListName = 'HMORDTYPE'          
                        AND   C.Short = 'M'          
                        AND   O.OrderKey = @cOrderkey          
                        AND   O.StorerKey = @cStorerKey)          
               SET @nIsMoveOrders = 1        
      
            IF @nIsMoveOrders = 0      
            BEGIN      
               SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),    
                        @cShipperKey = ISNULL(RTRIM(ShipperKey), '')    
               FROM dbo.Orders WITH (NOLOCK)    
               WHERE Storerkey = @cStorerkey    
               AND   Orderkey = @cOrderkey    
    
               IF ISNULL( @cShipperKey, '') = ''    
               BEGIN    
                  SET @nErrNo = 76500    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV SHIPPERKEY    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
  
               DECLARE @tShipLabel AS VariableTable  --(yeekung02)  
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)      
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)      
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)         
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLoadKey', @cLoadKey)         
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cShipperKey', @cShipperKey)        
                -- Print label    
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cPrinter, @cPrinter_Paper,     
                  'SHIPPLABEL', -- Report type    
                  @tShipLabel, -- Report params    
                  'rdtfnc_PackByTrackNo',     
                  @nErrNo  OUTPUT,    
                  @cErrMsg OUTPUT     
  
               IF @nErrNo <> 0    
               BEGIN    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
               ELSE  -- (james08)    
               BEGIN    
                  IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)    
                              WHERE StorerKey = @cStorerKey    
                              AND   ReportType = @cReportType    
                              AND   Function_ID IN (0, @nFunc))    
                     SET @nPrinted = @nPrinted + 1    
               END    
            END    
         END    
    
         IF @cShipLabel <> ''    
         BEGIN    
            SET @nErrNo = 0    
            DECLARE @tSHIPPLABEL    VARIABLETABLE    
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)    
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)    
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)    
    
            -- Print label    
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cPrinter, '',     
               @cShipLabel, -- Report type    
               @tSHIPPLABEL, -- Report params    
               'rdtfnc_PackByTrackNo',     
               @nErrNo  OUTPUT,    
               @cErrMsg OUTPUT     
         END    
         ELSE    
         BEGIN    
            -- Print only if rdt report is setup (james21)    
            IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)    
                        WHERE StorerKey = @cStorerKey    
                        AND   ReportType = 'SHIPPLBLSP'    
                        AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1    
                                                      ELSE 0 END)    
            BEGIN    
               SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),    
                        @cShipperKey = ISNULL(RTRIM(ShipperKey), '')    
               FROM dbo.Orders WITH (NOLOCK)    
               WHERE Storerkey = @cStorerkey    
               AND   Orderkey = @cOrderkey    
    
               IF ISNULL( @cShipperKey, '') = ''    
               BEGIN    
                  SET @nErrNo = 90665    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV SHIPPERKEY    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
    
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                        @cTargetDB = ISNULL(RTRIM(TargetDB), '')    
               FROM RDT.RDTReport WITH (NOLOCK)    
               WHERE StorerKey = @cStorerkey    
               AND ReportType = 'SHIPPLBLSP'    
    
               SET @nErrNo = 0    
               EXEC RDT.rdt_BuiltPrintJob    
                  @nMobile,    
                  @cStorerKey,    
                  'SHIPPLBLSP',    
                  'PRINT_SHIPPLBLSP',    
                  @cDataWindow,    
                  @cPrinter,    
                  @cTargetDB,    
                  @cLangCode,    
                  @nErrNo  OUTPUT,    
                  @cErrMsg OUTPUT,    
                  @cLoadKey,    
                  @cOrderKey,    
                  @cShipperKey,    
                  0    
    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @cOutField04 = @cCtnType    
                  SET @cOutField05 = @cCtnWeight    
                  EXEC rdt.rdtSetFocusField @nMobile, 4    
                  GOTO Quit    
               END    
               ELSE  -- (james08)    
               BEGIN    
                  IF EXISTS ( SELECT 1 FROM rdt.rdtReport WITH (NOLOCK)    
                              WHERE StorerKey = @cStorerKey    
                              AND   ReportType = @cReportType    
                              AND   Function_ID IN (0, @nFunc))    
                     SET @nPrinted = @nPrinted + 1    
               END    
            END    
         END    
    
         -- (james08)    
         -- Prepare next screen variable    
         IF @nPrinted > 0    
         BEGIN    
            -- (james10) if config turn on then show the custom errmsg     
            IF rdt.RDTGetConfig( @nFunc, 'PackByTrackNoShowMsgInNewScn', @cStorerKey) = 1    
            BEGIN    
               SET @cOutField01 = SUBSTRING( rdt.rdtgetmessage( 90662, @cLangCode, 'DSP'), 7, 13)    
               SET @cOutField02 = ''    
            END    
            ELSE    
            BEGIN    
               SET @cOutField01 = 'And Label/Report'    
               SET @cOutField02 = 'PRINTED'    
            END    
         END    
         ELSE    
         BEGIN    
            SET @cOutField01 = ''    
            SET @cOutField02 = ''    
         END    
    
         SET @nCurScn = @nScn    
         SET @nCurStep = @nStep    
    
         SET @nScn = @nScn + 1    
         SET @nStep = @nStep + 1    
      END    
      ELSE     -- Not all SKU for this pickslip scanned and packed    
      BEGIN    
          -- (james05)    
         IF @cExtendedUpdateSP <> '' AND     
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile                   INT,           ' +    
               '@nFunc                     INT,           ' +    
               '@cLangCode                 NVARCHAR( 3),  ' +    
               '@nStep                     INT,           ' +    
               '@nInputKey                 INT,           ' +    
               '@cStorerkey                NVARCHAR( 15), ' +    
               '@cOrderKey                 NVARCHAR( 10), ' +    
               '@cPickSlipNo               NVARCHAR( 10), ' +    
               '@cTrackNo                  NVARCHAR( 20), ' +    
               '@cSKU                      NVARCHAR( 20), ' +    
               '@nCartonNo                 INT,           ' +    
               '@cSerialNo                 NVARCHAR( 30), ' +         
               '@nSerialQTY                INT,           ' +      
               '@nErrNo                    INT           OUTPUT,  ' +    
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,    
                  @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @cOutField04 = @cCtnType    
               SET @cOutField04 = @cCtnWeight    
               EXEC rdt.rdtSetFocusField @nMobile, 4    
               ROLLBACK TRAN CONFIRM_PACKINFO    
            END    
         END    
                
         WHILE @@TRANCOUNT > @nTranCount    
            COMMIT TRAN    
    
         SET @nNextCartonNo = 0  -- (james34) need use new variable here to prevent below printing use wrong carton no    
         SELECT @nNextCartonNo = ISNULL(MAX(CartonNo), 1) + 1 FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
    
         SET @cOutField01 = @cOrderkey    
         SET @cOutField02 = @cTrackNo    
         SET @cOutField03 = @nNextCartonNo    
         SET @cOutField04 = @nExpectedQty    
         SET @cOutField05 = @nPackedQty    
         SET @cOutField06 = ''    
    
         EXEC rdt.rdtSetFocusField @nMobile, 6    
    
         SET @nCurScn = @nScn    
         SET @nCurStep = @nStep    
    
         SET @nScn = @nScn - 1    
         SET @nStep = @nStep - 1    
      END    
    
      -- (james18)    
      IF @cExtendedPrintSP NOT IN ('0', '') AND     
         EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
         SET @cSQLParam =    
            '@nMobile                   INT,           ' +    
            '@nFunc                     INT,           ' +    
            '@cLangCode                 NVARCHAR( 3),  ' +    
            '@nStep                     INT,           ' +    
            '@nInputKey                 INT,           ' +    
            '@cStorerkey                NVARCHAR( 15), ' +    
            '@cOrderKey                 NVARCHAR( 10), ' +    
            '@cPickSlipNo               NVARCHAR( 10), ' +    
            '@cTrackNo                  NVARCHAR( 20), ' +    
            '@cSKU                      NVARCHAR( 20), ' +    
            '@nCartonNo                 INT,           ' +    
            '@nErrNo                    INT           OUTPUT,  ' +    
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @nFunc, @cLangCode, @nCurStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
              @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
            SET @cOutField04 = @cCtnType    
            SET @cOutField04 = @cCtnWeight    
            EXEC rdt.rdtSetFocusField @nMobile, 4    
            GOTO Quit    
         END    
      END    
    
      -- Extended info    
      SET @cExtendedInfo = ''    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +         
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +     
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +     
               '@nAfterStep       INT,           ' +     
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' +     
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '     
                   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                 @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,     
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT         
             
            SET @cOutField15 = @cExtendedInfo    
         END    
      END    
      SET @cInField03=''    
   END    
    
   IF @nInputKey = 0 -- ENTER    
   BEGIN    
      -- 1 orders 1 tracking no    
      -- discrete pickslip, 1 ordes 1 pickslipno    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
      AND   Storerkey = @cStorerkey    
      AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
            ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
            ( [Status] = [Status]))    
        
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
      AND CartonNo = @nCartonNo    
    
      SET @cOutField01 = @cOrderkey    
      SET @cOutField02 = @cTrackNo    
      SET @cOutField03 = @nCartonNo    
      SET @cOutField04 = @nExpectedQty    
      SET @cOutField05 = @nPackedQty    
      SET @cOutField06 = ''    
      SET @cOutField15 = ISNULL( @cExtendedInfo, '')    
    
      EXEC rdt.rdtSetFocusField @nMobile, 6    
  
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
    
      -- Extended info    
      SET @cExtendedInfo = ''    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +         
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +     
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +     
               '@nAfterStep       INT,           ' +     
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' +     
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '     
                   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                 @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,     
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT         
    
            SET @cOutField15 = @cExtendedInfo    
         END    
      END    
   END    
    
   -- Reset back the field attribute (james07)    
   SET @cFieldAttr03 = CASE WHEN @cFieldAttr03 = 'O' THEN '' ELSE @cFieldAttr03 END  
   SET @cFieldAttr04 = CASE WHEN @cFieldAttr04 = 'O' THEN '' ELSE @cFieldAttr04 END    
   SET @cFieldAttr05 = CASE WHEN @cFieldAttr05 = 'O' THEN '' ELSE @cFieldAttr05 END    
    
   Step_4_Fail:    
END    
GOTO Quit    
    
/********************************************************************************    
Step 5. screen = 3124    
   Message    
********************************************************************************/    
Step_5:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      SET @nMoreToPack = 0      

      IF @cExtendedUpdateSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile                   INT,           ' +
            '@nFunc                     INT,           ' +
            '@cLangCode                 NVARCHAR( 3),  ' +
            '@nStep                     INT,           ' +
            '@nInputKey                 INT,           ' +
            '@cStorerkey                NVARCHAR( 15), ' +
            '@cOrderKey                 NVARCHAR( 10), ' +
            '@cPickSlipNo               NVARCHAR( 10), ' +
            '@cTrackNo                  NVARCHAR( 20), ' +
            '@cSKU                      NVARCHAR( 20), ' +
            '@nCartonNo                 INT,           ' +
            '@cSerialNo                 NVARCHAR( 30), ' +     
            '@nSerialQTY                INT,           ' +  
            '@nErrNo                    INT           OUTPUT,  ' +
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,@cSerialNo, @nSerialQTY,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
      
      -- (james40)      
      IF @cDropID <> ''      
      BEGIN      
         SET @cOrderKey = ''      
      
         -- Custom get orderkey sp. Can do swap lot inside the sp and insert ecommlog        
         IF @cGetOrders_SP <> ''        
            AND EXISTS ( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetOrders_SP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cGetOrders_SP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cDropID, @tGetOrders,          
                 @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               '@nMobile                   INT,           ' +      
               '@nFunc                     INT,           ' +      
               '@cLangCode                 NVARCHAR( 3),  ' +      
               '@nStep                     INT,           ' +      
               '@nInputKey                 INT,           ' +      
               '@cStorerkey                NVARCHAR( 15), ' +      
               '@cDropID                   NVARCHAR( 20), ' +      
               '@tGetOrders                VariableTable READONLY,   ' +      
               '@cOrderKey                 NVARCHAR( 10) OUTPUT,     ' +      
               '@nErrNo                    INT           OUTPUT,     ' +      
               '@cErrMsg                   NVARCHAR( 20) OUTPUT      '      
      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cDropID, @tGetOrders,         
               @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT        
         END        
         ELSE      
         BEGIN      
            SELECT TOP 1 @cOrderKey = OrderKey      
            FROM dbo.PTLTran WITH (NOLOCK)       
            WHERE DropID = @cDropID      
            AND   StorerKey = @cStorerkey      
            AND   [Status] = '9'      
            ORDER BY PTLKey DESC      
         END      
      
         -- Generate PickingInfo      
         SET @cPickSlipno = ''      
         SELECT @cPickSlipno = ISNULL(PickheaderKey,'')      
         FROM   dbo.PickHeader WITH (NOLOCK)      
         WHERE  OrderKey = @cOrderKey      
            
         -- 1 orders 1 tracking no      
         -- discrete pickslip, 1 ordes 1 pickslipno      
         SET @nExpectedQty = 0      
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)      
         WHERE Orderkey = @cOrderkey      
         AND   Storerkey = @cStorerkey      
         AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
               ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
               ( [Status] = [Status]))    
           
         SET @nPackedQty = 0      
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
               
         IF @nExpectedQty > @nPackedQty      
         BEGIN      
            SET @nMoreToPack = 1      
            SET @cOutField02 = @cDropID      
         END      
      END      
          
      -- (james31)      
      IF @cRefNo <> ''      
         EXEC rdt.rdtSetFocusField @nMobile, 3      
      ELSE IF @cDropID <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 2    
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 1      
    
      SET @cOrderKey = ''      
      SET @cDropID = ''      
      SET @cRefNo = ''    
    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''      
      SET @cOutField03 = ''    
      SET @cInField03  =''    
    
      -- (james31)    
      SET @nScn = @nScn - 4      
      SET @nStep = @nStep - 4      
    
      -- Clear previous stored record    
      DELETE FROM RDT.rdtTrackLog    
      WHERE AddWho = @cUserName    
    
      IF @nMoreToPack = 1      
         GOTO Step_1               
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 6. Screen = 3125. Multi SKU    
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
Step_6:    
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
         @cActSKU  OUTPUT,    
         @nErrNo   OUTPUT,    
         @cErrMsg  OUTPUT    
    
      IF @nErrNo <> 0    
      BEGIN    
         IF @nErrNo = -1    
            SET @nErrNo = 0    
         GOTO Quit    
      END    
    
      SET @cSKU = @cActSKU    
    
      -- Get SKU info    
      SELECT @cSKUDesc = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU    
   END    
    
   -- 1 orders 1 tracking no    
   -- discrete pickslip, 1 ordes 1 pickslipno    
   SET @nExpectedQty = 0    
   SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
   WHERE Orderkey = @cOrderkey    
   AND   Storerkey = @cStorerkey    
   AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
         ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
         ( [Status] = [Status]))    
     
   SET @nPackedQty = 0    
   SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
   WHERE PickSlipNo = @cPickSlipNo    
    
   SET @nCartonNo = 0    
   SELECT @nCartonNo = ISNULL(MAX(CartonNo), 1) FROM dbo.PackDetail WITH (NOLOCK)    
   WHERE PickSlipNo = @cPickSlipNo    
    
   -- Prepare SKU fields    
   SET @cOutField01 = @cOrderkey    
   SET @cOutField02 = @cTrackNo    
   SET @cOutField03 = @nCartonNo    
   SET @cOutField04 = @nExpectedQty    
   SET @cOutField05 = @nPackedQty    
   SET @cOutField06 = @cSKU    
   SET @cOutField07 = ''            -- (james01)    
    
   EXEC rdt.rdtSetFocusField @nMobile, 6    
    
   IF @nDisAllowChangeCtnNo = 1  
      SET @cFieldAttr03 = 'O'  
        
   -- Go to SKU screen    
   SET @nScn = @nFromScn    
   SET @nStep = @nStep - 3    
    
END    
GOTO Quit    
    
/********************************************************************************    
Step 7. screen = 3125. Unpack    
   Option   (Field01, input)    
********************************************************************************/    
Step_7:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOption = @cInField01    
    
      -- Check blank    
      IF @cOption = ''    
      BEGIN    
         SET @nErrNo = 90668    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Required'    
         GOTO Step_7_Fail    
      END    
    
      -- Check valid option    
      IF @cOption NOT IN ( '1', '2')    
      BEGIN    
         SET @nErrNo = 90669    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'    
         GOTO Step_7_Fail    
      END    
    
      IF @cOption = '1'    
      BEGIN    
         -- (james11)    
         EXEC rdt.rdt_PackByTrackNo_DelPack     
            @nMobile       = @nMobile,    
            @nFunc         = @nFunc,     
            @cLangCode     = @cLangCode,     
            @nStep         = @nStep,     
            @nInputKey = @nInputKey,     
            @cStorerkey    = @cStorerkey,     
            @cOrderKey     = @cOrderKey,     
            @cPickSlipNo   = @cPickSlipNo,     
            @cTrackNo      = @cTrackNo,     
            @cSKU          = @cSKU,     
            @nCartonNo     = @nCartonNo,    
            @cOption       = @cOption,     
            @nErrNo        = @nErrNo   OUTPUT,     
            @cErrMsg       = @cErrMsg  OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
    
      -- Option 1 or 2 still goes here to go back screen 1 or 2    
      SET @cPackSkipTrackNo_SP = rdt.RDTGetConfig( @nFunc, 'PACKSKIPTRACKNO', @cStorerkey)    
    
      IF LEN( RTRIM( @cPackSkipTrackNo_SP)) > 1    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPackSkipTrackNo_SP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackSkipTrackNo_SP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, ' +    
               ' @cPackSkipTrackNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPackSkipTrackNo NVARCHAR( 1)  OUTPUT,  ' +    
               '@nErrNo           INT           OUTPUT,  ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cStorerkey, @cOrderKey,     
                 @cPackSkipTrackNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END          
         ELSE    
            SET @cPackSkipTrackNo = ''    
      END    
      ELSE    
         SET @cPackSkipTrackNo = @cPackSkipTrackNo_SP    
    
      IF @cPackSkipTrackNo IN ('', '0')    
      BEGIN    
         SET @cOutField01 = @cOrderkey    
         SET @cOutField02 = ''    
    
         SET @nScn = @nScn - 5    
         SET @nStep = @nStep - 5    
    
         GOTO QUIT    
      END    
    
      -- (james31)    
      IF @cRefNo <> ''      
         EXEC rdt.rdtSetFocusField @nMobile, 3      
      ELSE IF @cDropID <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 2    
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 1      
    
      SET @cOrderKey = ''    
      SET @cDropID = ''    
      SET @cRefNo = ''    
      SET @cTrackNo = ''    
    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
    
      SET @nScn = @nScn - 6    
      SET @nStep = @nStep - 6    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- 1 orders 1 tracking no    
      -- discrete pickslip, 1 ordes 1 pickslipno    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
      AND   Storerkey = @cStorerkey    
      AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
            ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
            ( [Status] = [Status]))    
        
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
    
      SET @nCartonNo = 0    
      SELECT @nCartonNo = ISNULL(MAX(CartonNo), 1) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
    
      -- If packheader not exists meaning is first carton in this pickslip. So default to carton no 1 (james07)    
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)    
      BEGIN    
         SET @nCartonNo = 1    
      END    
    
      -- Extended info    
      SET @cExtendedInfo = ''    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END    
      END    
    
      SET @cOutField01 = @cOrderkey    
      SET @cOutField02 = @cTrackNo    
      SET @cOutField03 = @nCartonNo    
      SET @cOutField04 = @nExpectedQty    
      SET @cOutField05 = @nPackedQty    
      SET @cOutField06 = ''    
      SET @cOutField07 = ''            -- (james01)    
      SET @cOutField15 = @cExtendedInfo    
    
      EXEC rdt.rdtSetFocusField @nMobile, 6    
  
      IF @nDisAllowChangeCtnNo = 1  
         SET @cFieldAttr03 = 'O'  
           
      SET @nScn = @nScn - 4    
      SET @nStep = @nStep - 4    
   END    
   GOTO Quit    
    
   Step_7_Fail:    
   BEGIN    
      SET @cOption = ''    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************        
Step 8. Screen = 4830. Serial No        
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
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, 1, 'UPDATE', 'PICKSLIP', @cPickSlipNo,         
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
        
      IF ISNULL(@cPackSwapLot_SP, '') NOT IN ('', '0') AND     
         EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cPackSwapLot_SP AND type = 'P')    
      BEGIN    
         SET @nErrNo = 0    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackSwapLot_SP) +    
            ' @n_Mobile,     @c_Storerkey,  @c_OrderKey,   @c_TrackNo,    @c_PickSlipNo, ' +    
            ' @n_CartonNo,   @c_LOC,        @c_ID,         @c_SKU, ' +    
            ' @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, ' +    
            ' @c_Barcode,    @b_Success   OUTPUT,  @n_ErrNo OUTPUT,  @c_ErrMsg OUTPUT '    
    
         SET @cSQLParam =    
            '@n_Mobile         INT,           ' +    
            '@c_Storerkey      NVARCHAR( 15),  ' +    
            '@c_OrderKey       NVARCHAR( 10), ' +    
            '@c_TrackNo        NVARCHAR( 20), ' +    
            '@c_PickSlipNo     NVARCHAR( 10), ' +    
            '@n_CartonNo       INT, ' +    
            '@c_LOC            NVARCHAR( 10), ' +    
            '@c_ID             NVARCHAR( 18), ' +    
            '@c_SKU            NVARCHAR( 20), ' +    
            '@c_Lottable01     NVARCHAR( 18), ' +    
            '@c_Lottable02     NVARCHAR( 18), ' +    
            '@c_Lottable03     NVARCHAR( 18), ' +    
            '@d_Lottable04     DATETIME,      ' +    
            '@d_Lottable05     DATETIME,      ' +    
            '@c_Barcode        NVARCHAR( 40), ' +    
            '@b_Success        INT           OUTPUT, ' +    
            '@n_ErrNo          INT           OUTPUT, ' +    
            '@c_ErrMsg         NVARCHAR( 20) OUTPUT  '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @cStorerkey, @cOrderKey, @cTrackNo, @cPickSlipNo, @nCartonNo, @cLOC, @cID, @cSKU,    
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
              @cInField06, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
      ELSE    
      BEGIN    
         -- Extended insert pack info stored proc here (james16)    
         IF @cExtendedInsPackSP <> '' AND     
            EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedInsPackSP AND type = 'P')    
         BEGIN    
            SET @nErrNo = 0    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInsPackSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nQty, @nCartonNo, @cSerialNo,@nSerialQTY,@cLabelNo OUTPUT,' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile                   INT,           ' +    
               '@nFunc                     INT,           ' +    
               '@cLangCode                 NVARCHAR( 3),  ' +    
               '@nStep                     INT,           ' +    
               '@nInputKey                 INT,           ' +    
               '@cStorerkey                NVARCHAR( 15), ' +    
               '@cOrderKey                 NVARCHAR( 10), ' +    
               '@cPickSlipNo               NVARCHAR( 10), ' +    
               '@cTrackNo                  NVARCHAR( 20), ' +    
               '@cSKU                      NVARCHAR( 20), ' +    
               '@nQty                      INT,           ' +    
               '@nCartonNo                 INT,           ' +    
               '@cSerialNo                 NVARCHAR( 30), ' +     
               '@nSerialQTY                INT,           ' +    
               '@cLabelNo                  NVARCHAR( 20) OUTPUT,  ' +                         
               '@nErrNo                    INT           OUTPUT,  ' +    
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nQty, @nCartonNo,@cSerialNo,@nSerialQTY, @cLabelNo OUTPUT    
                  ,@nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    

            SET @cGetCartonNoCFG = rdt.RDTGetConfig( @nFunc, 'GetCartonNoCFG', @cStorerKey) --TSY01  
  
            IF @cGetCartonNoCFG = 1 --TSY01  
               SELECT @nCartonNo = CartonNo      --TSY01  
               FROM dbo.PackDetail WITH (NOLOCK) --TSY01  
               WHERE PickSlipNo = @cPickSlipNo   --TSY01  
               AND Storerkey = @cStorerkey       --TSY01  
               AND LabelNo = @cLabelNo           --TSY01  
         END    
      END    
        
      IF @nMoreSNO = 1        
         GOTO Quit     
             
      -- 1 orders 1 tracking no    
      -- discrete pickslip, 1 ordes 1 pickslipno    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
      AND   Storerkey = @cStorerkey    
      AND   Status < '9'    
      AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
            ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
            ( [Status] = [Status]))    
        
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
    
      -- (james26)    
      IF @cExtendedMsgQSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedMsgQSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedMsgQSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                 @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END    
      END    
          
      IF @nExpectedQty = @nPackedQty    
      BEGIN    
         SET @nScn = @nFromScn    
         SET @nStep = @nStep - 5     
         GOTO CONTINUE_STEP3    
      END    
    
      -- Extended info    
      SET @cExtendedInfo = ''    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +         
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +     
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +     
               '@nAfterStep       INT,           ' +     
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' +     
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '     
                   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                 @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,     
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT         
         END    
      END    
    
      SET @cOutField01 = @cOrderkey    
      SET @cOutField02 = @cTrackNo    
      SET @cOutField03 = @nCartonNo    
      SET @cOutField04 = @nExpectedQty    
      SET @cOutField05 = @nPackedQty    
      SET @cOutField06 = ''    
      SET @cOutField15 = @cExtendedInfo    
    
      SET @cInField03=''    
    
      EXEC rdt.rdtSetFocusField @nMobile, 6      
  
      IF @nDisAllowChangeCtnNo = 1  
         SET @cFieldAttr03 = 'O'  
           
      SET @nScn = @nFromScn    
      SET @nStep = @nStep - 5     
   END        
   IF @nInputKey = 0 -- ENTER       
   BEGIN    
            -- 1 orders 1 tracking no    
      -- discrete pickslip, 1 ordes 1 pickslipno    
      SET @nExpectedQty = 0    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
      AND   Storerkey = @cStorerkey    
      AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
            ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
            ( [Status] = [Status]))    
        
      SET @nPackedQty = 0    
      SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
      AND CartonNo = @nCartonNo    
    
      SET @cOutField01 = @cOrderkey    
      SET @cOutField02 = @cTrackNo    
      SET @cOutField03 = @nCartonNo    
      SET @cOutField04 = @nExpectedQty    
      SET @cOutField05 = @nPackedQty    
      SET @cOutField06 = ''    
      SET @cOutField15 = ISNULL( @cExtendedInfo, '')    
    
      EXEC rdt.rdtSetFocusField @nMobile, 6    
  
      IF @nDisAllowChangeCtnNo = 1  
         SET @cFieldAttr03 = 'O'  
           
      SET @nScn = @nFromScn    
      SET @nStep = @nStep - 5    
    
      -- Extended info    
      SET @cExtendedInfo = ''    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +         
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +     
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +     
               '@nAfterStep       INT,           ' +     
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' +     
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '     
                   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                 @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,     
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT         
    
            SET @cOutField15 = @cExtendedInfo    
         END    
      END    
      GOTO QUIT    
   END     
   GOTO QUIT    
    
   CONFIRMTRACKNOFAIL:    
   BEGIN    
      ROLLBACK TRAN CONFIRM_TRACKNO    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
      GOTO QUIT    
   END    
    
    
END        
GOTO Quit        
  
/***********************************************************************************  
Step 9. Scn = 3127. Capture data screen  
   Data1    (field01)  
   Input1   (field02, input)  
   .  
   .  
   .  
   Data5    (field09)  
   Input5   (field10, input)  
***********************************************************************************/  
Step_9:  
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
  
      IF @cExtendedValidateSP <> '' AND     
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
            ' @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
       
         SET @cSQLParam =    
            '@nMobile                   INT,           ' +    
            '@nFunc                     INT,           ' +    
            '@cLangCode                 NVARCHAR( 3),  ' +    
            '@nStep                     INT,           ' +    
            '@nInputKey                 INT,           ' +    
            '@cStorerkey                NVARCHAR( 15), ' +    
            '@cOrderKey                 NVARCHAR( 10), ' +    
            '@cPickSlipNo               NVARCHAR( 10), ' +    
            '@cTrackNo                  NVARCHAR( 20), ' +    
            '@cSKU                      NVARCHAR( 20), ' +    
            '@nCartonNo                 INT,           ' +    
            '@cCtnType                  NVARCHAR( 10), ' +    
            '@cCtnWeight                NVARCHAR( 10), ' +    
            '@cSerialNo                 NVARCHAR( 30), ' +         
            '@nSerialQTY                INT,           ' +      
            '@nErrNo                    INT           OUTPUT,  ' +    
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
       
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
               @cCtnType, @cCtnWeight,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
        
      EXEC rdt.rdt_PackByTrackNo_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'UPDATE',   
         @cOrderKey, @cDropID, @cRefNo, @cPickSlipNo, @cData1, @cData2, @cData3, @cData4, @cData5,   
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
         @cDataCaptureInfo OUTPUT,  
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
  
      -- Serial No        
      IF @cSerialNoCapture IN ('1', '3')  AND ISNULL(@cSerialNo,'')='' -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY        
      BEGIN        
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc,@nqty, 'CHECK', 'PICKSLIP', @cPickSlipNo,         
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
            SET @nFromScn=  3122  
            SET @nScn = 4831        
            SET @nStep = @nStep - 1        
        
            GOTO Quit        
         END        
      END        
        
      IF @nFromStep = 3  
      BEGIN  
       SET @cSerialNo = ''  
  
         IF ISNULL(@cPackSwapLot_SP, '') NOT IN ('', '0') AND     
            EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cPackSwapLot_SP AND type = 'P')    
         BEGIN    
            SET @nErrNo = 0    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackSwapLot_SP) +    
               ' @n_Mobile,     @c_Storerkey,  @c_OrderKey,   @c_TrackNo,    @c_PickSlipNo, ' +    
               ' @n_CartonNo,   @c_LOC,        @c_ID,         @c_SKU, ' +    
               ' @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, ' +    
               ' @c_Barcode,    @b_Success   OUTPUT,  @n_ErrNo OUTPUT,  @c_ErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               '@n_Mobile         INT,           ' +    
               '@c_Storerkey      NVARCHAR( 15),  ' +    
               '@c_OrderKey       NVARCHAR( 10), ' +    
               '@c_TrackNo        NVARCHAR( 20), ' +    
               '@c_PickSlipNo     NVARCHAR( 10), ' +    
               '@n_CartonNo       INT, ' +    
               '@c_LOC            NVARCHAR( 10), ' +    
               '@c_ID             NVARCHAR( 18), ' +    
               '@c_SKU            NVARCHAR( 20), ' +    
               '@c_Lottable01     NVARCHAR( 18), ' +    
               '@c_Lottable02     NVARCHAR( 18), ' +    
               '@c_Lottable03     NVARCHAR( 18), ' +    
               '@d_Lottable04     DATETIME,      ' +    
               '@d_Lottable05     DATETIME,      ' +    
               '@c_Barcode        NVARCHAR( 40), ' +    
               '@b_Success        INT           OUTPUT, ' +    
               '@n_ErrNo          INT           OUTPUT, ' +    
               '@c_ErrMsg         NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @cStorerkey, @cOrderKey, @cTrackNo, @cPickSlipNo, @nCartonNo, @cLOC, @cID, @cSKU,    
                 @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
                 @cInField06, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
         ELSE    
         BEGIN    
            -- Extended insert pack info stored proc here (james16)    
            IF @cExtendedInsPackSP <> '' AND     
               EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedInsPackSP AND type = 'P')    
            BEGIN    
               SET @nErrNo = 0    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInsPackSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nQty, @nCartonNo, @cSerialNo,@nSerialQTY,@cLabelNo OUTPUT,' +    
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
               SET @cSQLParam =    
                  '@nMobile       INT,           ' +    
                  '@nFunc                     INT,           ' +    
                  '@cLangCode                 NVARCHAR( 3),  ' +    
                  '@nStep                     INT,           ' +    
                  '@nInputKey                 INT,           ' +    
                  '@cStorerkey                NVARCHAR( 15), ' +    
                  '@cOrderKey                 NVARCHAR( 10), ' +    
                  '@cPickSlipNo               NVARCHAR( 10), ' +    
                  '@cTrackNo                  NVARCHAR( 20), ' +    
                  '@cSKU                      NVARCHAR( 20), ' +    
                  '@nQty                      INT,           ' +    
                  '@nCartonNo                 INT,           ' +    
                  '@cSerialNo                 NVARCHAR( 30), ' +     
                  '@nSerialQTY                INT,           ' +    
                  '@cLabelNo                  NVARCHAR( 20) OUTPUT,  ' +                         
                  '@nErrNo                    INT           OUTPUT,  ' +    
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT   '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nQty, @nCartonNo,@cSerialNo,@nSerialQTY, @cLabelNo OUTPUT    
                     ,@nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
                  GOTO Quit    

               SET @cGetCartonNoCFG = rdt.RDTGetConfig( @nFunc, 'GetCartonNoCFG', @cStorerKey) --TSY01  
  
               IF @cGetCartonNoCFG = 1 --TSY01  
                  SELECT @nCartonNo = CartonNo      --TSY01  
                  FROM dbo.PackDetail WITH (NOLOCK) --TSY01  
                  WHERE PickSlipNo = @cPickSlipNo   --TSY01  
                  AND Storerkey = @cStorerkey       --TSY01  
                  AND LabelNo = @cLabelNo           --TSY01  
            END    
         END    
        
         -- 1 orders 1 tracking no    
         -- discrete pickslip, 1 ordes 1 pickslipno    
         SET @nExpectedQty = 0    
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
         WHERE Orderkey = @cOrderkey    
            AND Storerkey = @cStorerkey    
            AND Status < '9'    
    
         SET @nPackedQty = 0    
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
    
         -- (james26)    
         IF @cExtendedMsgQSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedMsgQSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedMsgQSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  '@nMobile          INT,           ' +    
                  '@nFunc            INT,           ' +    
                  '@cLangCode        NVARCHAR( 3),  ' +    
                  '@nStep            INT,           ' +    
                  '@nAfterStep       INT,           ' +    
                  '@nInputKey        INT,           ' +    
                  '@cStorerkey       NVARCHAR( 15), ' +    
                  '@cOrderKey        NVARCHAR( 10), ' +    
                  '@cPickSlipNo      NVARCHAR( 10), ' +    
                  '@cTrackNo         NVARCHAR( 20), ' +    
                  '@cSKU             NVARCHAR( 20), ' +    
                  '@nCartonNo        INT,           ' +    
                  '@nErrNo           INT           OUTPUT, ' +    
                  '@cErrMsg          NVARCHAR( 20) OUTPUT  '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                    @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                    @nErrNo OUTPUT, @cErrMsg OUTPUT    
            END    
         END    
          
         IF @nExpectedQty = @nPackedQty    
         BEGIN    
            SET @nScn = @nFromScn    
            SET @nStep = @nFromStep     
            GOTO CONTINUE_STEP3    
         END    
    
         -- Extended info    
         SET @cExtendedInfo = ''    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cExtendedInfo = ''    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +         
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +     
                  ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
               SET @cSQLParam =        
                  '@nMobile          INT,           ' +    
                  '@nFunc            INT,           ' +    
                  '@cLangCode        NVARCHAR( 3),  ' +    
                  '@nStep            INT,           ' +     
                  '@nAfterStep       INT,           ' +     
                  '@nInputKey        INT,           ' +    
                  '@cStorerkey       NVARCHAR( 15), ' +    
                  '@cOrderKey        NVARCHAR( 10), ' +    
                  '@cPickSlipNo      NVARCHAR( 10), ' +    
                  '@cTrackNo         NVARCHAR( 20), ' +    
                  '@cSKU             NVARCHAR( 20), ' +    
                  '@nCartonNo        INT,           ' +    
                  '@cExtendedInfo    NVARCHAR( 20) OUTPUT, ' +     
                  '@nErrNo           INT           OUTPUT, ' +    
                  '@cErrMsg          NVARCHAR( 20) OUTPUT  '     
                   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,         
                    @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,     
                    @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT         
            END    
         END    
    
         SET @cOutField01 = @cOrderkey    
         SET @cOutField02 = @cTrackNo    
         SET @cOutField03 = @nCartonNo    
         SET @cOutField04 = @nExpectedQty    
         SET @cOutField05 = @nPackedQty    
         SET @cOutField06 = ''    
         SET @cOutField15 = @cExtendedInfo    
    
         SET @cInField03=''    
    
         EXEC rdt.rdtSetFocusField @nMobile, 6      
  
         IF @nDisAllowChangeCtnNo = 1  
            SET @cFieldAttr03 = 'O'  
           
         SET @nScn = @nFromScn    
         SET @nStep = @nFromStep  
           
         GOTO Quit         
      END  
        
      IF LEN( RTRIM( @cPackSkipTrackNo_SP)) > 1    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPackSkipTrackNo_SP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackSkipTrackNo_SP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, ' +    
               ' @cPackSkipTrackNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPackSkipTrackNo NVARCHAR( 1)  OUTPUT,  ' +    
               '@nErrNo           INT           OUTPUT,  ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cStorerkey, @cOrderKey,     
                 @cPackSkipTrackNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END          
         ELSE    
            SET @cPackSkipTrackNo = ''    
      END    
      ELSE    
         SET @cPackSkipTrackNo = @cPackSkipTrackNo_SP    
    
      IF @cPackSkipTrackNo IN ('', '0')    
      BEGIN    
         SET @cOutField01 = @cOrderkey    
         SET @cOutField02 = ''    
       
         SET @nScn = @nScn - 6    
         SET @nStep = @nStep - 7    
      END    
    
      -- (james08)    
      -- If svalue = 0 or blank then need go to next screen and exists check in that screen    
      -- If svalue = 1 then check every orders must have a track no    
      -- If svalue > 0 (1, 2, 3, etc) then no need check orders whether tracking no exists    
      IF @cPackSkipTrackNo = '1'    
      BEGIN    
         SET @cTrackNo = ''    
             
         IF @cUseUdf04AsTrackNo = '1'    
            SELECT @cTrackNo = Userdefine04    
            FROM dbo.Orders WITH (NOLOCK)    
            WHERE StorerKey = @cStorerkey    
            AND   OrderKey = @cOrderkey    
         ELSE    
            SELECT @cTrackNo = TrackingNo    
            FROM dbo.Orders WITH (NOLOCK)    
            WHERE StorerKey = @cStorerkey    
            AND   OrderKey = @cOrderkey    
    
         IF ISNULL( @cTrackNo, '') = ''    
         BEGIN    
            SET @nErrNo = 90652    
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --TRACK NO REQ    
            SET @cOutField01 = @cOrderkey    
            SET @cOutField02 = ''    
       
            SET @nScn = @nScn - 6    
            SET @nStep = @nStep - 7    
            GOTO Quit    
          END    
      END    
    
      IF @cPackSkipTrackNo > '0'    
      BEGIN    
         -- 1 orders 1 tracking no    
         -- discrete pickslip, 1 ordes 1 pickslipno    
         SET @nExpectedQty = 0    
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
         WHERE Orderkey = @cOrderkey    
         AND Storerkey = @cStorerkey    
    
         SET @nPackedQty = 0    
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
    
         SET @nCartonNo = 0    
         SELECT @nCartonNo = ISNULL(MAX(CartonNo), 1) FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
    
         -- If packheader not exists meaning is first carton in this pickslip. So default to carton no 1 (james07)    
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)    
         BEGIN    
            SET @nCartonNo = 1    
         END    
    
         SET @cOutField01 = @cOrderkey    
         SET @cOutField02 = @cTrackNo    
         SET @cOutField03 = @nCartonNo    
         SET @cOutField04 = @nExpectedQty    
         SET @cOutField05 = @nPackedQty    
         SET @cOutField06 = ''    
         SET @cOutField07 = ''            -- (james01)    
    
         EXEC rdt.rdtSetFocusField @nMobile, 6    
    
         IF @nDisAllowChangeCtnNo = 1  
            SET @cFieldAttr03 = 'O'  
  
         SET @nScn = @nScn - 5    
         SET @nStep = @nStep - 6    
      END    
    
      -- Extended info    
      SET @cExtendedInfo = ''    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@cExtendedInfo    NVARCHAR( 20) OUTPUT,  ' +    
               '@nErrNo           INT           OUTPUT,  ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT   '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                 @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
                
            SET @cOutField15 = @cExtendedInfo    
         END    
      END    
    
      -- (james37)    
      IF @cExtendedMsgQSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedMsgQSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedMsgQSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile          INT,           ' +    
               '@nFunc            INT,           ' +    
               '@cLangCode        NVARCHAR( 3),  ' +    
               '@nStep            INT,           ' +    
               '@nAfterStep       INT,           ' +    
               '@nInputKey        INT,           ' +    
               '@cStorerkey       NVARCHAR( 15), ' +    
               '@cOrderKey        NVARCHAR( 10), ' +    
               '@cPickSlipNo      NVARCHAR( 10), ' +    
               '@cTrackNo         NVARCHAR( 20), ' +    
               '@cSKU             NVARCHAR( 20), ' +    
               '@nCartonNo        INT,           ' +    
               '@nErrNo           INT           OUTPUT, ' +    
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo,    
                 @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END    
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
  
      -- Prepare next screen var  
      SET @cOutField01 = '' -- @cRefNo  
      SET @cOutField02 = '' -- @cReceiptKey  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      -- Go to prev screen  
      SET @nScn = @nScn - 7  
      SET @nStep = @nStep - 8  
   END  
  
END  
GOTO Quit  
  
/********************************************************************************    
Quit. Update back to I/O table, ready to be pick up by JBOSS    
********************************************************************************/    
Quit:    
BEGIN    
   UPDATE RDTMOBREC WITH (ROWLOCK) SET    
       EditDate      = GETDATE(),    
       ErrMsg        = @cErrMsg,    
       Func          = @nFunc,    
       Step          = @nStep,    
       Scn           = @nScn,    
    
       StorerKey     = @cStorerKey,    
       Facility      = @cFacility,    
       Printer       = @cPrinter,    
       Printer_Paper = @cPrinter_Paper,    
       -- UserName      = @cUserName,    
       V_Lottable02  = @cLottable02,    
       V_OrderKey    = @cOrderKey,    
       V_SKU         = @cSKU,    
       V_CaseID      = @cDropID,    
    
       V_Cartonno    = @nCartonNo,    
       V_FromScn     = @nFromScn,    
       V_FromStep    = @nFromStep,  
     
       V_Integer1    = @nIsMoveOrders,    
       V_Integer2    = @nDisAllowChangeCtnNo,  
         
       V_String1     = @cTrackNo,    
       V_String2     = @cShipperKey,    
       V_String3     = @cShipLabel,    
       V_String4     = @cPickslipno,    
       V_String5     = @cGetOrders_SP,    
       V_String6     = @cDecodeSP,    
       V_String7     = @cMultiSKUBarcode,    
       V_String8     = @cActSKU,    
       V_String9     = @cPackByTrackNotUpdUPC,    
       V_String10    = @cHideWeightInput,    
       V_String11    = @cExtendedInfoSP,    
       V_String12    = @cShowErrMsgInNewScn,    
       V_String13    = @cCapturePackInfoSP,    
       V_String14    = @cExtendedInsPackSP,    
       V_String15    = @cExtendedPrintSP,    
       V_String16    = @cExtendedUpdateSP,    
       V_String17    = @cExtendedValidateSP,    
       V_String18    = @cAutoPackConfirm,    
       V_String19    = @cShowPackCompletedScn,    
       V_String20    = @cExtendedMsgQSP,    
       V_String21    = @cHideCartonInput,    
       V_String22    = @cPackSkipTrackNo,      
       V_String23    = @cFlowThruCtnTypeScn,    
       V_String24    = @cUseUdf04AsTrackNo,   -- (james45)    
       V_String25    = @cDefaultCartonType,   -- (james46)    
       V_String26    = @cCaptureInfoSP,  
       V_String27    = @cPackSkipTrackNo_SP,  
       V_String28    = @cDataCapture,  
       V_String29    = @cNotConvertWgt2KG,  
       V_String30    = @cSKUStatus,  
       V_String31    = @cExcludeShortPick,   -- (james51)    
       V_String32    = @cPickConfirmStatus,  -- (james51)    
       V_String33    = @cExcludedDocType,
       V_String34    = @cNewCtnNoSP,

       V_String41    = @cRefNo,    
       V_String42    = @cSerialNoCapture,    
       V_String43    = @cPackSwapLot_SP,    
       V_String44    = @cData1,  
       V_String45    = @cData2,  
       V_String46    = @cData3,  
       V_String47    = @cData4,  
       V_String48    = @cData5,  
     
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