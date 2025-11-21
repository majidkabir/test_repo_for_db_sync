SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
/*****************************************************************************/    
/* Store procedure: rdtfnc_SimpleCC                                          */    
/* Copyright      : IDS                                                      */    
/*                                                                           */    
/* Purpose: Simple Cycle Count for Posting                                   */    
/*                                                                           */    
/* Modifications log:                                                        */    
/*                                                                           */    
/* Date       Rev  Author   Purposes                                         */    
/* 2011-03-22 1.0  ChewKP   Created                                          */    
/* 2011-05-06 1.1  ChewKP   Re-work on whole structure                       */    
/* 2013-02-07 1.2  ChewKP   SOS#269922 Bug Fix (ChewKP01)                    */    
/* 2013-07-10 1.3  ChewKP   SOS#283253 Assisted Count (ChewKP02)             */    
/* 2014-06-18 1.4  James    SOS#311863 Disable Qty field if RDT config       */    
/*                          is turn on (james01)                             */    
/* 2015-01-16 1.5  James    Bug fix (james02)                                */    
/* 2015-01-21 1.6  Ung      Fix CCLock not del when ESC back to 1st screen   */    
/* 2015-05-05 1.7  ChewKP   SOS#339947 Add StorerConfig ToLOCLookup          */    
/*                          Update Loc.LastCylceCount (ChewKP03)             */    
/* 2016-03-21 1.8  SPChin   SOS365022 - Update Loc.LastCylceCount When ESC   */    
/* 2016-04-21 1.9  James    SOS368587 - Add ExtendedValidateSP (james03)     */    
/* 2016-06-28 2.0  James    SOS370878 - Add CCSheetNo (james04)              */    
/*                          Add customised fetch task                        */    
/*                          Add ExtendedUpdateSP                             */    
/* 2016-09-01 2.1  James    SOS375760 - Add extendedinfo @ screen 2 (james05)*/    
/* 2016-09-15 2.2  James    SOS375903 - Add DecodeSP (james06)               */    
/* 2016-10-26 2.3  James    Perf tuning (james07)                            */    
/* 2017-04-19 2.4  Ung      Fix recompile                                    */    
/* 2018-05-14 2.5  James    IN00101780 - Auto show next loc when finish count*/    
/*                          1 loc (by config) (james08)                      */    
/* 2018-07-17 2.6  James    Make scan sku,qty compatible with auto ENTER     */    
/*                          handheld (james09)                               */    
/* 2018-08-13 2.7  James    WMS5972 - Add decode with type (james10)         */    
/* 2018-07-17 2.8  Ung      WMS-5664 Add ConfirmSkipLOC and many bugs fix    */    
/* 2018-06-26 2.9  James    WMS5140-Add ExtendedValidateSP @ step 4 (james10)*/    
/* 2018-08-17 3.0  Ung      WMS-5995 Add ExtendedInfo @ screen 4 ESC         */    
/*                          Reorganize ExtendedInfo param                    */    
/*                          Convert hardcode screen and message              */    
/* 2018-09-12 3.1  Ung      WMS-6163 Add confirm LOC counted screen          */    
/*                          Add ConfirmLOCCounted                            */    
/*                          Add CaptureIDSP                                  */    
/*                          Add DisableQTYFieldSP                            */    
/* 2018-09-19 3.2  Ung      WMS-6268 Fix CCSheetNo filter                    */    
/* 2018-10-29 3.3  Gan      Performance tuning                               */    
/* 2019-01-08 3.4  James    WMS7110-Add config to retain CCREF (james10)     */    
/* 2019-03-04 3.5  CheeMun  INC0606210 - Set CaptureID = ''                  */        
/* 2019-08-05 3.6  James    WMS9996-Add ExtendedInfoSP @ step ID (james11)   */        
/*                          Add Reset count by ID screen                     */    
/*                         Loc counted screen, option 2 allow continue count*/    
/*        without reset loc                                                  */    
/* 2019-08-21 3.7  James    WMS-10272 Add IsValidFormat to SKU & Qty         */    
/*                          Add ExtendedValidateSP @ step 8                  */    
/*                          Add check SKUStatus (james12)                    */    
/* 2019-11-22 3.8  James    WMS-11122 Add ExtendedUpdateSP @ step 4 (james13)*/    
/* 2020-02-08 3.9  YeeKung  WMS-16273 Add UOM qty  (yeekung01)                */  
/* 2021-09-03 4.0  CikFun   JSM- Change @cOutField08 as blank; @cOutField09  */  
/*         						as defaultqty         										*/  
/* 2021-11-21 4.1  YeeKung  WMS-18333 Add Multiskubarcode (yeekung02)        */ 
/* 2023-08-16 4.2  James    WMS-23420 Enhance ConfirmLOC logic (james14)     */
/* 2023-08-15 4.3  James    WMS-23277 For DecodeSP no output error (james15) */
/*****************************************************************************/    
    
CREATE   PROC [RDT].[rdtfnc_SimpleCC](    
   @nMobile    INT,    
   @nErrNo     INT  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max    
) AS    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variable    
DECLARE    
   @nVariance           INT,    
   @b_success           INT,    
   @tVar                VariableTable    
    
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
   @cDescription        NVARCHAR(10),    
   @cChkFacility        NVARCHAR(5),    
   @nRowCount           INT,    
   @cChkStorerKey       NVARCHAR(15),    
   @cLOC                NVARCHAR(10),    
   @cSKU                NVARCHAR(20),    
   @cCCKey              NVARCHAR(10),    
   @cInSKU              NVARCHAR(40),    
   @cDecodeLabelNo      NVARCHAR(20),    
   @nQty                INT,    
   @cLottable01         NVARCHAR( 18),    
   @cLottable02         NVARCHAR( 18),    
   @cLottable03         NVARCHAR( 18),    
   @dLottable04         DATETIME,    
   @dLottable05         DATETIME,    
   @nTotalQty           INT,    
   @cCCTempSKUCode      NVARCHAR( 20),    
   @cCCTempSKUCodeSP    NVARCHAR(250),    
   @cCountNo            NVARCHAR(1),    
   @nTotalQty2          INT,    
   @nTotalQty3          INT,    
   @cAddLoc             NVARCHAR(1),    
   @cCCDetailKey        NVARCHAR(10),    
   @n_err               INT,    
   @cCCSheetNo          NVARCHAR(10),    
   @c_errmsg            NVARCHAR(250),    
   @nTotalSKUCount      INT,    
   @nTotalSKUCounted    INT,    
   @nTotalQtyCounted    INT,    
   @nTotalQtyCountNo1   INT,    
   @nTotalQtyCountNo2   INT,    
   @nTotalQtyCountNo3   INT, 
   @nSKUCnt             INT,    --(yeekung02) 
   @cResetLoc           NVARCHAR(1),    
   @cDefaultQTY         NVARCHAR(10),    
   @nInQty              INT,    
   @cSKUDesc            NVARCHAR(60),    
   @cOption             NVARCHAR(1),    
   @bLocCounted         NVARCHAR(1),    
   @cCCUpdateSP         NVARCHAR(20),    
   @nTotalSKUQty        INT,    
   @cSuggestSKU         NVARCHAR(20), -- (ChewKP02)    
   @nFromScn            INT,          -- (CheWKP02)    
   @nFromStep           INT,          -- (CheWKP02)    
   @cSuggestLOC         NVARCHAR(10), -- (ChewKP02)    
   @cSuggestLogiLOC     NVARCHAR(18), -- (ChewKP02)    
   @cLocAisle           NVARCHAR(10), -- (ChewKP02)    
   @nLocLevel           INT,          -- (ChewKP02)    
   @cHideScanInformation NVARCHAR(1), -- (ChewKP02)    
   @cDisableQTYField    NVARCHAR( 1), -- (james01)    
   @cNotAllowSkipSuggestLOC      NVARCHAR( 1),  -- (james02)    
   @cSuggestedLOC       NVARCHAR( 10),    
   @cToLOCLookupSP      NVARCHAR(20), --(ChewKP03)    
   @cSQL                NVARCHAR( MAX), --(ChewKP03)/(james06)    
   @cSQLParam           NVARCHAR( MAX), --(ChewKP03)/(james06)    
   @cExtendedValidateSP NVARCHAR(20),   --(james03)    
   @cExtendedInfoSP     NVARCHAR(20),   --(james03)    
   @cExtendedInfo       NVARCHAR(20),   --(james03)    
   @cConfirmSkipLOC     NVARCHAR(1),    
   @cMultiSKUBarcode    NVARCHAR( 3),  --(yeekung02)
    
   @cExtendedFetchTaskSP   NVARCHAR(20),   --(james04)    
   @cCurrSuggestSKU        NVARCHAR(20),   --(james04)    
   @cCurrSuggestLOC        NVARCHAR(10),   --(james04)    
   @cCurrSuggestLogiLOC    NVARCHAR(10),    
   @cSimpleCCSheetNoReq    NVARCHAR(1),    --(james04)    
   @cExtendedUpdateSP      NVARCHAR(20),   --(james04)    
   @cConfirmLOCCounted     NVARCHAR(1),    
   @cCaptureIDSP           NVARCHAR(20),    
   @cCaptureID             NVARCHAR(1),    
   @cDisableQTYFieldSP     NVARCHAR(20),    
   @cMax                   NVARCHAR(MAX),    
    
    
   -- (james06)    
   @cID                 NVARCHAR( 18),    
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
    
   -- (james08)    
   @cAutoShowNextLoc2Count NVARCHAR( 1),    
   @cSKUValidated          NVARCHAR( 2),    
    
   -- (james10)    
   @cRetainCCKey           NVARCHAR( 1),    
    
   -- (james11)    
   @bIDCounted             INT,    
   @cResetID               NVARCHAR(1),    
   @cSKUStatus             NVARCHAR(10) , -- (james12)       
    
   --(yeekung01)    
   @cPUOM                  NVARCHAR(5),    
   @cMUOM                  NVARCHAR(5),    
   @cPUOM_Desc             NCHAR( 5),        
   @cMUOM_Desc             NCHAR( 5),        
   @nPUOM_Div              INT,       
   @nPQTY                  INT,    
   @nMQTY                  INT,    
   @nDecodeQty             INT,
   
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
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)    
    
-- Getting Mobile information    
SELECT    
   @nFunc            = Func,    
   @nScn             = Scn,    
   @nStep            = Step,    
   @nInputKey        = InputKey,    
   @cLangCode        = Lang_code,    
   @nMenu  = Menu,    
    
   @cFacility        = Facility,    
   @cStorerKey       = StorerKey,    
   @cPrinter         = Printer,    
   @cPrinter_Paper   = Printer_Paper,    
   @cUserName        = UserName,    
    
   @nTotalSKUCounted = V_Integer1,    
   @nTotalSKUCount   = V_Integer2,    
   @nTotalQtyCounted = V_Integer3,    
   @nTotalQty        = V_Integer4,    
   @nPQTY            = V_Integer5,    
   @nMQTY            = V_Integer6,    
   @nPUOM_Div        = V_Integer7,       
       
   @nFromScn       = V_FromScn,    
   @nFromStep        = V_FromStep,    
    
   @cSKU             = V_SKU,    
   @cLoc             = V_Loc,    
   @cID              = V_ID,    
   @cPUOM            = V_UOM, -- (yeekung01)    
   @cCCKey           = V_String1,    
   @cCountNo         = V_String2,    
   @cSKUStatus       = V_String3,     
   @cDefaultQTY      = V_String7,    
   @cSuggestSKU      = V_String8,    
   @cSuggestLogiLOC      = V_String11,    
   @cSuggestLOC          = V_String12,    
   @cHideScanInformation = V_String13,    
   @cDisableQTYField     = V_String14, -- (james01)    
    
   @cNotAllowSkipSuggestLOC   = V_String15, -- (james02)    
   @cToLOCLookupSP            = V_String16, -- (ChewKP03)    
   @cCCSheetNo                = V_String17, -- (james04)    
   @cAutoShowNextLoc2Count    = V_String18, -- (james08)    
   @cSKUValidated             = V_String19, -- (james09)    
   @cExtendedUpdateSP         = V_String20, -- (james09)    
   @cExtendedValidateSP       = V_String21, -- (james09)    
   @cConfirmSkipLOC           = V_String22,    
   @cExtendedInfoSP           = V_String23,    
   @cConfirmLOCCounted        = V_String24,    
   @cCaptureIDSP              = V_String25,    
   @cCaptureID                = V_String26,    
   @cDisableQTYFieldSP        = V_String27,       
   @cRetainCCKey              = V_String28, -- (james10)      
    
   --(yeekung01)    
   @cMUOM                     = V_String29, -- (yeekung01)    
   @cMUOM_Desc                = V_String30,        
   @cPUOM_Desc                = V_String31,    
   @cMultiSKUBarcode          = V_String32,  --(yeekung02)
    
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
   @cMax        = V_Max,    
    
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
IF @nFunc IN (  731 , 732 )    
BEGIN    
   IF @nStep = 0  GOTO Step_0   -- Menu. Func = 577    
   IF @nStep = 1  GOTO Step_1   -- Scn = 2770 CCKey    
   IF @nStep = 2  GOTO Step_2   -- Scn = 2771 LOC    
   IF @nStep = 3  GOTO Step_3   -- Scn = 2772 Statistic    
   IF @nStep = 4  GOTO Step_4   -- Scn = 2773 SKU, QTY    
   IF @nStep = 5  GOTO Step_5   -- Scn = 2774 Add LOC?    
   IF @nStep = 6  GOTO Step_6   -- Scn = 2775 Reset LOC?    
   IF @nStep = 7  GOTO Step_7   -- Scn = 2776 Skip LOC?    
   IF @nStep = 8  GOTO Step_8   -- Scn = 2777 LOC counted?    
   IF @nStep = 9 GOTO Step_9   -- Scn = 2778 ID?    
   IF @nStep = 10 GOTO Step_10  -- Scn = 2779 Reset ID? 
   IF @nStep = 11 GOTO Step_11  -- Scn = 3570 multi sku    
END    
    
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. Called from menu (func = 1664)    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Get storer configure    
   SET @cAutoShowNextLoc2Count = rdt.RDTGetConfig( @nFunc, 'AutoShowNextLoc2Count', @cStorerkey)    
   SET @cConfirmSkipLOC = rdt.RDTGetConfig( @nFunc, 'ConfirmSkipLOC', @cStorerkey)    
   SET @cConfirmLOCCounted = rdt.RDTGetConfig( @nFunc, 'ConfirmLOCCounted', @cStorerkey)    
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerkey)    
   SET @cHideScanInformation = rdt.RDTGetConfig( @nFunc, 'HideScanInformation', @cStorerkey)    
   SET @cNotAllowSkipSuggestLOC = rdt.RDTGetConfig( @nFunc, 'NOTALLOWSKIPSUGGESTLOC', @cStorerkey)    
   SET @cToLOCLookupSP = rdt.RDTGetConfig( @nFunc, 'ToLOCLookup', @cStorerkey)    
    
   SET @cCaptureIDSP = rdt.RDTGetConfig( @nFunc, 'CaptureIDSP', @cStorerkey)    
   IF @cCaptureIDSP = '0'    
      SET @cCaptureIDSP = ''    
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)    
   IF @cDefaultQTY = '0'    
      SET @cDefaultQTY = ''    
   SET @cDisableQTYFieldSP = rdt.RDTGetConfig( @nFunc, 'DisableQTYFieldSP', @cStorerKey)                          
   IF @cDisableQTYFieldSP = '0'                          
      SET @cDisableQTYFieldSP = ''     
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
   IF @cExtendedInfoSP = '0'    
      SET @cExtendedInfoSP = ''    
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'    
      SET @cExtendedUpdateSP = ''    
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
   IF @cExtendedValidateSP = '0'    
      SET @cExtendedValidateSP = ''    

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)    --(yeekung02)
    
   IF @cDisableQTYField = '1'    
      IF @cDefaultQTY = ''    
         SET @cDefaultQTY = '1'    
    
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName      
    
   SET @cRetainCCKey = rdt.RDTGetConfig( @nFunc, 'RetainCCRef', @cStorerKey)    
    
   -- (james03)      
   SET @cSKUStatus  = ''      
   SET @cSKUStatus = rdt.RDTGetConfig( @nFunc, 'SKUStatus', @cStorerkey)        
   IF @cSKUStatus = '0'      
    SET @cSKUStatus = ''      
    
   -- (ChewKP02)    
   IF @nFunc = 732    
   BEGIN    
      -- Clear the incomplete task for the same login    
      DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND AddWho = @cUserName    
      --AND Status = '0'    
    
      -- (ChewKP02)    
      SET @cSuggestLOC = ''    
      SET @cSuggestSKU = ''    
   END    
    
   -- If not assisted count, not allow skip loc (no suggested loc for 731)    
   IF @nFunc = 731    
      SET @cNotAllowSkipSuggestLOC = '1'    
    
   -- Set the entry point    
   SET @nScn  = 2770    
   SET @nStep = 1    
    
   -- initialise all variable    
   SET @nFromScn = 0    
   SET @nFromStep = 0    
    
   -- Enable all fields    
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
    
   SET @cCCKey = ''    
   SET @cCCSheetNo = ''    
    
   -- Prep next screen var    
   SET @cOutField01 = ''    
   SET @cOutField02 = ''    
   EXEC rdt.rdtSetFocusField @nMobile, 1    
END    
GOTO Quit    
    
/********************************************************************************    
Step 1. screen = 2770    
   CCREF:   (Field01, input)    
   CCSHEET: (Field02, input, Optional)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cCCKey = ISNULL(RTRIM(@cInField01),'')    
      SET @cCCSheetNo = ISNULL(@cInField02,'') -- CCSheet no    
    
      IF @cCCKey = ''    
      BEGIN    
         SET @nErrNo = 72741    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CCREF req    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_1_Fail    
      END    
    
      SELECT DISTINCT @cChkStorerKey = StorerKey    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE CCKey = @cCCKey    
    
      SET @nRowCount = @@ROWCOUNT    
    
      IF @nRowCount < 1    
      BEGIN    
         SET @nErrNo = 72742    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CCREF    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_1_Fail    
      END    
    
      -- Validate with StockTakeSheetParameters    
      IF NOT EXISTS (SELECT TOP 1 StockTakeKey    
                     FROM dbo.StockTakeSheetParameters WITH (NOLOCK)    
                     WHERE StockTakeKey = @cCCKey    
                     AND   StorerKey = @cStorerkey    
                     AND   Facility = @cFacility)    
      BEGIN    
         SET @nErrNo = 72749    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Setup CCREF'    
         GOTO Step_1_Fail    
      END    
    
      SET @cCountNo = ''    
      SELECT @cCountNo = FinalizeStage + 1    
      FROM dbo.StockTakeSheetParameters WITH (NOLOCK)    
      WHERE StockTakeKey = @cCCKey    
    
      IF @cCountNo > 3    
     BEGIN    
         SET @nErrNo = 72777    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvCoutNo'    
         GOTO Step_1_Fail    
      END    
    
      IF ISNULL(RTRIM(@cCountNo),'') = '1'    
      BEGIN    
         IF NOT EXISTS (    
            SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
            WHERE CCKey = @cCCKey    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND   FinalizeFlag = 'N')    
         BEGIN    
             SET @nErrNo = 72776    
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CC Finalized'    
             GOTO Step_1_Fail    
         END    
      END    
      ELSE IF ISNULL(RTRIM(@cCountNo),'') = '2'    
      BEGIN    
         IF NOT EXISTS (    
            SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
            WHERE CCKey = @cCCKey    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND   FinalizeFlag_Cnt2 = 'N')    
         BEGIN    
             SET @nErrNo = 72778    
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Count Finalized'    
             EXEC rdt.rdtSetFocusField @nMobile, 3    
             GOTO Step_1_Fail    
         END    
      END    
      ELSE IF ISNULL(RTRIM(@cCountNo),'') = '3'    
      BEGIN    
         IF NOT EXISTS (    
            SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
            WHERE CCKey = @cCCKey    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND   FinalizeFlag_Cnt3 = 'N')    
         BEGIN    
             SET @nErrNo = 72779    
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Count Finalized'    
             EXEC rdt.rdtSetFocusField @nMobile, 3    
             GOTO Step_1_Fail    
         END    
      END    
    
      -- (james04)    
      SET @cSimpleCCSheetNoReq = rdt.RDTGetConfig( @nFunc, 'SIMPLECCSHEETNOREQ', @cStorerkey)    
      IF @cSimpleCCSheetNoReq IN ('', '0')    
         SET @cSimpleCCSheetNoReq = '0'    
    
      IF @cSimpleCCSheetNoReq = '1' AND ISNULL( @cCCSheetNo, '') = ''    
      BEGIN    
         SET @cOutField01 = @cCCKey    
         EXEC rdt.rdtSetFocusField @nMobile, 2    
         GOTO Quit    
      END    
    
      IF ISNULL( @cCCSheetNo, '') <> ''    
      BEGIN    
         IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK) WHERE CCKey = @cCCKey AND CCSheetNo = @cCCSheetNo )    
         BEGIN    
      SET @nErrNo = 72789    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv CCShet#'    
            SET @cOutField01 = @cCCKey    
            EXEC rdt.rdtSetFocusField @nMobile, 2    
            GOTO Quit    
         END    
      END    
    
      -- (james03)    
      IF @cExtendedUpdateSP <> '' AND    
         EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQty, @cOption,' +    
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
         SET @cSQLParam =    
            '@nMobile      INT,           ' +    
            '@nFunc        INT,           ' +    
            '@nStep        INT,           ' +    
            '@nInputKey    INT,           ' +    
            '@cLangCode    NVARCHAR( 3),  ' +    
            '@cStorerkey   NVARCHAR( 15), ' +    
            '@cCCKey       NVARCHAR( 10), ' +    
            '@cCCSheetNo   NVARCHAR( 10), ' +    
            '@cCountNo     NVARCHAR( 1),  ' +    
            '@cLOC         NVARCHAR( 10), ' +    
            '@cSKU         NVARCHAR( 20), ' +    
            '@nQty         INT,           ' +    
            '@cOption      NVARCHAR( 1),  ' +    
            '@nErrNo       INT           OUTPUT, ' +    
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQty, @cOption,    
              @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
    
      SET @cOutField01 = @cCCKey    
      SET @cOutField02 = ''    
      SET @cOutField03 = @cCountNo    
      SET @cOutField06 = @cCCSheetNo    
    
      SET @cSuggestSKU = ''    
      SET @cSuggestLOC = ''    
      SET @cSuggestLogiLOC = ''    
    
      -- (ChewKP02)    
      IF @nFunc = 732    
      BEGIN    
         SET @cExtendedFetchTaskSP = ''    
         SET @cExtendedFetchTaskSP = rdt.RDTGetConfig( @nFunc, 'ExtendedFetchTaskSP', @cStorerKey)    
         IF @cExtendedFetchTaskSP NOT IN ('0', '')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedFetchTaskSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, @cCurrSuggestSKU,' +    
               ' @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile                   INT,           ' +    
               '@nFunc                     INT,   ' +    
               '@cLangCode                 NVARCHAR( 3),  ' +    
               '@nStep                     INT,           ' +    
               '@nInputKey                 INT,           ' +    
               '@cCCKey                    NVARCHAR( 10), ' +    
               '@cCCSheetNo                NVARCHAR( 10), ' +    
               '@cStorerkey                NVARCHAR( 15), ' +    
               '@cFacility                 NVARCHAR( 5),  ' +    
               '@cCurrSuggestLOC           NVARCHAR( 10), ' +    
               '@cCurrSuggestSKU           NVARCHAR( 20), ' +    
               '@cCountNo                  NVARCHAR( 1), ' +    
               '@cUserName                 NVARCHAR( 18),        ' +    
               '@cSuggestLogiLOC           NVARCHAR( 10) OUTPUT, ' +    
               '@cSuggestLOC               NVARCHAR( 10) OUTPUT, ' +    
               '@cSuggestSKU               NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo                    INT           OUTPUT, ' +    
               '@cErrMsg                   NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, '', '',    
                 @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
               GOTO Step_1_Fail    
            END    
         END    
         ELSE    
         BEGIN    
            EXECUTE rdt.rdt_SimpleCC_GetNextLOC    
               @cCCKey,    
               @cCCSheetNo,     
               @cStorerKey,    
               @cFacility,    
               '',   -- current CCLogicalLOC is blank    
               '',   -- current SKU is blank    
               @cSuggestLogiLOC OUTPUT,    
               @cSuggestLOC     OUTPUT,    
               @cSuggestSKU     OUTPUT,    
               @cCountNo,    
               @cUserName    
         END    
    
         IF @cSuggestLoc <> ''    
         BEGIN    
            SET @cOutField04 = @cSuggestLOC    
         END    
         ELSE    
         BEGIN    
            SET @nErrNo = 72781    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoMoreCCTask'    
            GOTO Step_1_Fail    
         END    
    
         DELETE FROM rdt.rdtCCLock    
         WHERE CCKey = @cCCKey    
         AND Loc <> @cSuggestLOC    
         AND AddWho = @cUserName    
    
         -- Insert into RDTCCLock    
         INSERT INTO RDT.RDTCCLock    
            (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,    
            Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,    
            StorerKey,  Sku,        Lot,         Loc, Id,    
            Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,    
            SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)    
         SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey, CCD.CCSheetNo,  @cCountNo,    
            '',        '',        '',         '',        '',       Loc.LocAisle, Loc.LocLevel,    
            @cStorerKey,  CCD.SKU,        CCD.LOT,         CCD.LOC,        CCD.ID,    
            CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,  CCD.Lottable04, CCD.Lottable05,    
            CCD.SystemQty,    
            CASE WHEN @cCountNo = '1' THEN CCD.Qty    
                 WHEN @cCountNo = '2' THEN CCD.Qty_Cnt2    
                 WHEN @cCountNo = '3' THEN CCD.Qty_Cnt3    
            END,    
            '3',             '',             @cUserName,     GETDATE()    
         FROM dbo.CCDETAIL CCD WITH (NOLOCK)    
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = CCD.Loc    
         WHERE CCD.CCKey = @cCCKey    
         AND ( CCD.StorerKey = '' OR CCD.StorerKey = @cStorerKey)    
         AND  (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))    
         AND   CCD.Loc = @cSuggestLOC    
         AND   1 = CASE    
                 WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
                 WHEN @cCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
                 WHEN @cCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
                 ELSE 1    
                 END    
    
         IF @@ROWCOUNT = 0 -- No data in CCDetail    
         BEGIN    
            SET @nErrNo = 72780    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'    
            GOTO Step_1_Fail    
         END    
      END    
      ELSE    
      BEGIN    
         SET @cOutField04 = ''    
      END    
    
      SET @cOutField05 = ''    
      SET @cOutField06 = @cCCSheetNo    
    
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
    
      -- insert to Eventlog    
      EXEC RDT.rdt_STD_EventLog    
           @cActionType   = '1', -- Sign In    
           @cUserID       = @cUserName,    
           @nMobileNo     = @nMobile,    
           @nFunctionID   = @nFunc,    
           @cFacility     = @cFacility,    
           @cStorerKey    = @cStorerkey,    
           @cCCKey        = @cCCKey,    
           --@cRefNo1       = @cCCKey,    
           @cRefNo2       = '',    
           @cRefNo3       = '',    
           @cRefNo4       = '',    
           @nStep         = @nStep    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- (ChewKP02)    
      IF @nFunc = 732    
      BEGIN    
         -- Clear the incomplete task for the same login    
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)    
         WHERE StorerKey = @cStorerKey    
         AND AddWho = @cUserName    
         --AND Status = '0'    
      END    
    
      -- insert to Eventlog    
      EXEC RDT.rdt_STD_EventLog    
           @cActionType   = '9', -- Sign Out    
           @cUserID       = @cUserName,    
           @nMobileNo     = @nMobile,    
           @nFunctionID   = @nFunc,    
           @cFacility     = @cFacility,    
           @cStorerKey    = @cStorerkey,    
           @cCCKey        = @cCCKey,    
           --@cRefNo1       = @cCCKey,    
           @cRefNo2       = '',    
           @cRefNo3       = '',    
           @cRefNo4       = '',    
           @nStep         = @nStep    
    
      -- Back to menu    
      SET @nFunc = @nMenu    
      SET @nScn  = @nMenu    
      SET @nStep = 0    
    
      SET @cOutField01 = ''    
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cCCKey = ''    
      SET @cCCSheetNo = ''    
    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
    END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 2. screen = 2771    
   CCREF   (Field01)    
   CountNo (Field03)    
   Loc     (Field02, input)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cSuggestedLOC = RTRIM( SUBSTRING( @cOutField04, 6, 10)) -- SUGGESTEDLOC    
      SET @cLOC = ISNULL(@cInField02,'') -- LOC    
    
      -- Validate compulsary field    
      IF ISNULL( @cLOC, '') = ''    
      BEGIN    
         -- If config turn on and not allow skip    
         IF @cNotAllowSkipSuggestLOC = '1'    
         BEGIN    
            SET @nErrNo = 72744    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC Req'    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_2_Fail    
         END    
         ELSE    
         BEGIN    
            -- Skip LOC    
            IF @cConfirmSkipLOC = '1'    
            BEGIN    
               -- Check if counted    
               IF NOT EXISTS( SELECT TOP 1 1    
                  FROM dbo.CCDetail CCD (NOLOCK)    
                     INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)    
                  WHERE CCD.CCKey = @cCCKey    
                  AND CCD.StorerKey = @cStorerKey    
                  AND LOC.Facility  = @cFacility    
                  AND LOC.LOC = @cSuggestLOC    
                  AND ( (@cCountNo = '1' AND Counted_Cnt1 = 1) OR    
                        (@cCountNo = '2' AND Counted_Cnt2 = 1) OR    
                        (@cCountNo = '3' AND Counted_Cnt3 = 1)))    
               BEGIN    
                  -- Prepare next screen var    
                  SET @cOutField01 = '' -- Option    
    
                  -- Go to confirm skip LOC screen    
                  SET @nScn = @nScn + 5    
                  SET @nStep = @nStep + 5    
    
                  GOTO Quit    
               END    
            END    
    
            SET @cCurrSuggestLogiLOC = @cSuggestLogiLOC    
            SET @cCurrSuggestLOC = @cSuggestLOC    
            SET @cCurrSuggestSKU = @cSuggestSKU    
            SET @cSuggestSKU = ''    
            SET @cSuggestLOC = ''    
    
            IF ISNULL( @cSuggestLogiLOC, '') = ''    
               SELECT @cSuggestLogiLOC = CCLogicalLoc    
               FROM dbo.LOC WITH (NOLOCK)    
               WHERE LOC = @cSuggestedLOC    
               AND   Facility = @cFacility    
    
            SET @cExtendedFetchTaskSP = ''    
            SET @cExtendedFetchTaskSP = rdt.RDTGetConfig( @nFunc, 'ExtendedFetchTaskSP', @cStorerKey)    
            IF @cExtendedFetchTaskSP NOT IN ('0', '')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedFetchTaskSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, @cCurrSuggestSKU,' +    
                  ' @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
               SET @cSQLParam =    
                  '@nMobile                   INT,           ' +    
                  '@nFunc                     INT,           ' +    
                  '@cLangCode                 NVARCHAR( 3),  ' +    
                  '@nStep                     INT,           ' +    
                  '@nInputKey                 INT,           ' +    
                  '@cCCKey                    NVARCHAR( 10), ' +    
                  '@cCCSheetNo                NVARCHAR( 10), ' +    
                  '@cStorerkey                NVARCHAR( 15), ' +    
                  '@cFacility                 NVARCHAR( 5),  ' +    
                  '@cCurrSuggestLOC           NVARCHAR( 10), ' +    
                  '@cCurrSuggestSKU           NVARCHAR( 20), ' +    
                  '@cCountNo                  NVARCHAR( 1),  ' +    
                  '@cUserName                 NVARCHAR( 18),        ' +    
                  '@cSuggestLogiLOC           NVARCHAR( 10) OUTPUT, ' +    
                  '@cSuggestLOC               NVARCHAR( 10) OUTPUT, ' +    
                  '@cSuggestSKU               NVARCHAR( 20) OUTPUT, ' +    
                  '@nErrNo                    INT           OUTPUT, ' +    
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT  '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, 'ZZZZZZZZZZZZZZZZZZZZ',    
                    @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
                  GOTO Step_2_Fail    
               END    
            END    
            ELSE    
            BEGIN    
               EXECUTE rdt.rdt_SimpleCC_GetNextLOC    
                  @cCCKey,    
                  @cCCSheetNo,     
                  @cStorerKey,    
                  @cFacility,    
                  @cSuggestLogiLOC,          -- current CCLogicalLOC    
                  'ZZZZZZZZZZZZZZZZZZZZ',    -- current SKU    
                  @cSuggestLogiLOC OUTPUT,    
                  @cSuggestLOC     OUTPUT,    
                  @cSuggestSKU     OUTPUT,    
                  @cCountNo,    
                  @cUserName    
            END    
    
            IF @cSuggestLoc <> ''    
            BEGIN    
               SET @cOutField04 = @cSuggestLOC    
            END    
            ELSE    
            BEGIN    
               -- Restore back prev variable    
               SET @cSuggestLogiLOC = @cCurrSuggestLogiLOC    
               SET @cSuggestLOC = @cCurrSuggestLOC    
               SET @cSuggestSKU = @cCurrSuggestSKU    
               SET @nErrNo = 72785    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoMoreCCTask'    
               GOTO Step_2_Fail    
            END    
    
            DELETE FROM rdt.rdtCCLock    
            WHERE CCKey = @cCCKey    
            AND Loc <> @cSuggestLOC    
            AND AddWho = @cUserName    
    
            -- Insert into RDTCCLock    
            INSERT INTO RDT.RDTCCLock    
               (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,    
               Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,    
               StorerKey,  Sku,        Lot,         Loc, Id,    
               Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,    
               SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)    
            SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey, CCD.CCSheetNo,  @cCountNo,    
               '',        '',        '',         '',        '',       Loc.LocAisle, Loc.LocLevel,    
               @cStorerKey,  CCD.SKU,        CCD.LOT,         CCD.LOC,        CCD.ID,    
               CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,  CCD.Lottable04, CCD.Lottable05,    
               CCD.SystemQty,    
               CASE WHEN @cCountNo = '1' THEN CCD.Qty    
                    WHEN @cCountNo = '2' THEN CCD.Qty_Cnt2    
                    WHEN @cCountNo = '3' THEN CCD.Qty_Cnt3    
               END,    
               '3',             '',             @cUserName,     GETDATE()    
            FROM dbo.CCDETAIL CCD WITH (NOLOCK)    
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = CCD.Loc    
            WHERE CCD.CCKey = @cCCKey    
            AND ( CCD.StorerKey = '' OR CCD.StorerKey = @cStorerKey)    
            AND   CCD.Loc = @cSuggestLOC    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))    
            AND   1 =   CASE    
                        WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
                        WHEN @cCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
                        WHEN @cCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
                        ELSE 1 END    
    
            IF @@ROWCOUNT = 0 -- No data in CCDetail    
            BEGIN    
               SET @nErrNo = 72786    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'    
               GOTO Step_2_Fail    
            END    
    
            SET @cOutField01 = @cCCKey    
            SET @cOutField02 = ''    
            SET @cOutField03 = @cCountNo    
            SET @cOutField05 = ''    
            SET @cOutField06 = @cCCSheetNo    
    
            GOTO Quit    
         END    
      END    
    
      -- ToLOC lookup (ChewKP03)    
      IF @cToLOCLookupSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cToLOCLookupSP AND type = 'P')    
         BEGIN    
    
    
            SET @cSQL = 'EXEC RDT.' + RTRIM( @cToLOCLookupSP) + ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLOC OUTPUT'    
    
            SET @cSQLParam =    
               '@nMobile     INT,           ' +    
               '@nFunc       INT,           ' +    
               '@cLangCode   NVARCHAR( 3),  ' +    
               '@cUserName   NVARCHAR( 15), ' +    
               '@cFacility   NVARCHAR( 5),  ' +    
               '@cStorerKey  NVARCHAR( 15), ' +    
               '@cLOC        NVARCHAR( 10) OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile    
                ,@nFunc    
                ,@cLangCode    
                ,@cUserName    
                ,@cFacility    
                ,@cStorerKey    
                ,@cLOC OUTPUT    
         END    
      END    
    
    
      -- Get the location    
      DECLARE @cChkLOC NVARCHAR( 10)    
      SELECT    
         @cChkLOC = LOC,    
         @cChkFacility = Facility    
      FROM dbo.LOC WITH (NOLOCK)    
      WHERE LOC = @cLOC    
    
      -- Validate location    
      IF @cChkLOC IS NULL OR @cChkLOC = ''    
      BEGIN    
         SET @nErrNo = 72745    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv LOC'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail    
      END    
    
      -- Validate location not in facility    
      IF @cChkFacility <> @cFacility    
      BEGIN    
         SET @nErrNo = 72746    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Facility'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail    
      END    
    
      -- Skip Checking on Loc with CCDetial, Actual Loc might have Inventory but system no.    
      IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK) WHERE CCKey = @cCCKey AND Loc = @cLoc )    
      BEGIN    
         SET @cAddLoc = ''    
         SET @cAddLoc = rdt.RDTGetConfig( @nFunc, 'SimpleCCAddLOC', @cStorerkey)    
    
         IF ISNULL(RTRIM(@cAddLoc),'') = '' OR ISNULL(RTRIM(@cAddLoc),'') = '0'    
         BEGIN    
            SET @nErrNo = 72750    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv LOC'    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_2_Fail    
         END    
         ELSE IF ISNULL(RTRIM(@cAddLoc),'') = '1'    
         BEGIN    
            BEGIN TRAN    
    
            EXECUTE dbo.nspg_GetKey    
               'CCDetailKey',    
               10,    
               @cCCDetailKey  OUTPUT,    
               @b_success     OUTPUT,    
               @n_err         OUTPUT,    
               @c_errmsg      OUTPUT    
    
            IF @n_err<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 72752    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --GetDetKey Fail    
               GOTO Step_2_Fail    
            END    
    
            IF ISNULL( @cCCSheetNo, '') = ''    
            BEGIN    
               EXECUTE dbo.nspg_GetKey    
                  'CCSheetNo',    
                  10,    
                  @cCCSheetNo    OUTPUT,    
                  @b_success     OUTPUT,    
                  @n_err         OUTPUT,    
                  @c_errmsg      OUTPUT    
    
               IF @n_err<>0    
               BEGIN    
                   ROLLBACK TRAN    
                   SET @nErrNo = 72753    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --GetDetKey Fail    
                   GOTO Step_2_Fail    
               END    
            END    
    
            INSERT INTO CCDetail (CCKey, CCDetailKey, CCSheetNo, Storerkey, Loc, SystemQty, Qty, Qty_Cnt2, Qty_Cnt3)    
            VALUES (@cCCKey, @cCCDetailKey, @cCCSheetNo, @cStorerkey, @cLoc, 0, 0, 0, 0)    
    
            IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 72754    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- InsCCDet Fail    
               GOTO Step_2_Fail    
            END    
    
            SET @cLocAisle = ''    
            SET @nLocLevel = ''    
            SELECT @cLocAisle = LocAisle    
                 , @nLocLevel = LocLevel    
            FROM dbo.Loc WITH (NOLOCK)    
            WHERE Loc = @cLoc    
            AND Facility = @cFacility    
    
            INSERT INTO RDT.RDTCCLock ( Mobile, CCKey, CCDetailKey, SheetNo, CountNo,  Aisle, Level, StorerKey, Loc, Status)    
            VALUES (@nMobile, @cCCKey, @cCCDetailKey, @cCCSheetNo, @cCountNo, @cLocAisle, @nLocLevel, @cStorerKey, @cLoc, '3')    
    
            COMMIT TRAN    
         END    
         ELSE IF ISNULL(RTRIM(@cAddLoc),'') = '2'    
         BEGIN    
            --GOTO Add Loc Screen    
            SET @cOutField01 = ''    
    
            SET @nScn = @nScn + 3    
            SET @nStep = @nStep + 3    
            GOTO QUIT    
         END    
      END    
    
      -- Validate Loc    
      -- (ChewKP02)    
      IF @nFunc = 732    
      BEGIN    
         IF ISNULL(RTRIM(@cLoc),'')  <> ISNULL(RTRIM(@cSuggestLOC),'')    
         BEGIN    
            IF rdt.RDTGetConfig( @nFunc, 'CCSkipMatchSuggestLOC', @cStorerkey) <> '1'    
            BEGIN    
               SET @nErrNo = 72784    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LocNotMatch'    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_2_Fail    
           END    
         END    
      END    
    
      SET @nTotalSKUCount = 0    
      SET @nTotalQty = 0    
      SET @nTotalSKUCounted = 0    
      SET @nTotalQtyCounted = 0    
      SET @nTotalQtyCountNo1 = 0    
      SET @nTotalQtyCountNo2 = 0    
      SET @nTotalQtyCountNo3 = 0    
    
      Select    
         @nTotalQty = SUM(SystemQty),    
         @nTotalSKUCount = Count(Distinct SKU)    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE CCKey = @cCCKey    
      AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
      AND   Loc = @cLoc    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
      Select    
         @nTotalSKUCounted = COUNT( DISTINCT SKU),      
         @nTotalQtyCounted = CASE WHEN @cCountNo = 1 THEN ISNULL( SUM(Qty), 0)    
                                  WHEN @cCountNo = 2 THEN ISNULL( SUM(Qty_Cnt2), 0)    
                                  WHEN @cCountNo = 3 THEN ISNULL( SUM(Qty_Cnt3), 0)    
                             END    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE CCKey = @cCCKey    
      AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
      AND   Loc = @cLoc    
      AND ((@cCountNo = 1 AND Counted_Cnt1 = '1') OR    
           (@cCountNo = 2 AND Counted_Cnt2 = '1') OR    
           (@cCountNo = 3 AND Counted_Cnt3 = '1'))    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
      Select    
         @nTotalSKUCounted = COUNT( DISTINCT SKU)    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE CCKey = @cCCKey    
      AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
      AND   Loc = @cLoc    
      AND ((@cCountNo = 1 AND Counted_Cnt1 = '1' AND Qty > 0) OR    
           (@cCountNo = 2 AND Counted_Cnt2 = '1' AND Qty_Cnt2 > 0) OR    
           (@cCountNo = 3 AND Counted_Cnt3 = '1' AND Qty_Cnt3 > 0))    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
      SET @cOutField01 = @cCCKey    
      SET @cOutField02 = @cLoc    
      SET @cOutField03 = @cCountNo    
    
      IF @cHideScanInformation = '1'    
      BEGIN    
         SET @cOutField04 = ''    
         SET @cOutField05 = ''    
      END    
      ELSE    
      BEGIN    
         SET @cOutField04 = CAST(@nTotalSKUCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalSKUCount AS NVARCHAR(5))    
         SET @cOutField05 = CAST(@nTotalQtyCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalQty AS NVARCHAR(6))    
      END    
    
      SET @cOutField06 = @cCCSheetNo    
      SET @cOutField07 = '' -- ExtendedInfo    
    
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''   
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,            ' +    
               ' @nFunc          INT,            ' +    
               ' @cLangCode      NVARCHAR( 3),   ' +    
               ' @nStep          INT,            ' +    
               ' @nAfterStep     INT,            ' +    
               ' @nInputKey      INT,            ' +    
               ' @cFacility      NVARCHAR( 5),   ' +    
               ' @cStorerKey     NVARCHAR( 15),  ' +    
               ' @cCCKey         NVARCHAR( 10),  ' +    
               ' @cCCSheetNo     NVARCHAR( 10),  ' +    
               ' @cCountNo       NVARCHAR( 1),   ' +    
               ' @cLOC           NVARCHAR( 10),  ' +    
               ' @cSKU           NVARCHAR( 20),  ' +    
               ' @nQTY           INT,            ' +    
               ' @cOption        NVARCHAR( 1),   ' +    
               ' @tVar           VariableTable READONLY, ' +    
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorerKey,    
               @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
    
            IF @nStep = 3    
               SET @cOutField07 = @cExtendedInfo    
         END    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      IF @nFunc = 732    
      BEGIN    
         -- Clear the incomplete task for the same login    
         DELETE FROM RDT.RDTCCLock WITH (ROWLOCK)    
         WHERE StorerKey = @cStorerKey    
         AND AddWho = @cUserName    
         --AND Status = '0'    
      END    
    
      SET @cOutField01 = CASE WHEN @cRetainCCKey = '1' THEN @cCCKey ELSE '' END -- @cCCKey -- (ChewKP02)/(james10)    
      SET @cOutField02 = '' -- @cCCSheetNo    
    
      EXEC rdt.rdtSetFocusField @nMobile, 1    
    
SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_2_Fail:    
   BEGIN    
      SET @cLOC = ''    
      SET @cOutField02 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 3. screen = 2772    
   CCREF    (Field01)    
   Count No (Field03)    
   Loc      (Field02, input)    
   Scanned SKU / Total SKU (Field04)    
   Scanned Qty / Total Qty (Field05)    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @bLocCounted = ''    
    
      IF @nFunc = 731    
      BEGIN    
         IF @cCountNo = '1'    
         BEGIN    
            IF EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                WHERE Counted_Cnt1 <> '0'    
                AND   CCKey = @cCCKey    
                AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                AND   Loc = @cLoc    
                AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo)))    
            BEGIN    
               SET @bLocCounted = '1'    
            END    
         END    
         ELSE IF @cCountNo = '2'    
         BEGIN    
            IF EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                WHERE Counted_Cnt2 <> '0'    
                AND   CCKey = @cCCKey    
                AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                AND   Loc = @cLoc    
                AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo)))    
            BEGIN    
               SET @bLocCounted = '1'    
            END    
         END    
         ELSE IF @cCountNo = '3'    
         BEGIN    
            IF EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                WHERE Counted_Cnt3 <> '0'    
                AND   CCKey = @cCCKey    
                AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                AND   Loc = @cLoc    
                AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo)))    
            BEGIN    
               SET @bLocCounted = '1'    
            END    
         END    
      END    
      ELSE IF @nFunc = 732    
      BEGIN    
         IF @nFromStep <> 4    
         BEGIN    
            IF @cCountNo = '1'    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                   WHERE Counted_Cnt1 = '0'    
                   AND   CCKey = @cCCKey    
                   AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                   AND   Loc = @cLoc    
                   AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo)))    
               BEGIN    
                  SET @bLocCounted = '1'    
               END    
            END    
            ELSE IF @cCountNo = '2'    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                   WHERE Counted_Cnt2 = '0'    
                   AND   CCKey = @cCCKey    
                   AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                   AND   Loc = @cLoc    
                   AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo)))    
               BEGIN    
                  SET @bLocCounted = '1'    
               END    
            END    
            ELSE IF @cCountNo = '3'    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                   WHERE Counted_Cnt3 = '0'    
                   AND   CCKey = @cCCKey    
                   AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                   AND   Loc = @cLoc    
                   AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo)))    
               BEGIN    
                  SET @bLocCounted = '1'    
               END    
            END    
         END    
      END    
    
      IF @bLocCounted = '1'    
      BEGIN    
         SET @cResetLoc = ''    
         SET @cResetLoc = rdt.RDTGetConfig( @nFunc, 'SimpleCCResetLOC', @cStorerkey)    
    
         IF ISNULL(RTRIM(@cResetLoc),'') = '' OR ISNULL(RTRIM(@cResetLoc),'') = '0'    
 BEGIN    
             SET @nErrNo = 72755    
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- Loc Counted    
             GOTO QUIT    
         END    
         ELSE    
         BEGIN    
            IF ISNULL(RTRIM(@cCountNo),'') = '1'    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                          WHERE CCKey = @cCCKey    
                          AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                          AND   FinalizeFlag = 'N'    
                          AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo)))    
               BEGIN    
                   SET @nErrNo = 72770    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Count Finalized'    
                   EXEC rdt.rdtSetFocusField @nMobile, 3    
                   GOTO Step_3_Fail    
               END    
            END    
            ELSE IF ISNULL(RTRIM(@cCountNo),'') = '2'    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                          WHERE CCKey = @cCCKey    
                          AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
             AND   FinalizeFlag_Cnt2 = 'N'    
                          AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo)))    
               BEGIN    
                   SET @nErrNo = 72771    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Count Finalized'    
                   EXEC rdt.rdtSetFocusField @nMobile, 3    
                   GOTO Step_3_Fail    
               END    
            END    
            ELSE IF ISNULL(RTRIM(@cCountNo),'') = '3'    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                    WHERE CCKey = @cCCKey    
                          AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                          AND   FinalizeFlag_Cnt3 = 'N'    
                          AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo)))    
               BEGIN    
                   SET @nErrNo = 72772    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Count Finalized'    
                   EXEC rdt.rdtSetFocusField @nMobile, 3    
                   GOTO Step_3_Fail    
               END    
            END    
    
          --GOTO RESET Loc Screen    
          SET @cOutField01 = ''    
    
          SET @nScn = @nScn + 3    
          SET @nStep = @nStep + 3    
    
          GOTO QUIT    
         END    
      END    
    
      IF @nFunc = 732    
      BEGIN    
         IF @nFromStep = 4    
         BEGIN    
            SET @cExtendedFetchTaskSP = ''    
            SET @cExtendedFetchTaskSP = rdt.RDTGetConfig( @nFunc, 'ExtendedFetchTaskSP', @cStorerKey)    
            IF @cExtendedFetchTaskSP NOT IN ('0', '')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedFetchTaskSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, @cCurrSuggestSKU,' +    
                  ' @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
               SET @cSQLParam =    
                  '@nMobile                   INT,           ' +    
                  '@nFunc                     INT,           ' +    
                  '@cLangCode                 NVARCHAR( 3),  ' +    
                  '@nStep                     INT,           ' +    
                  '@nInputKey                 INT,           ' +    
                  '@cCCKey                    NVARCHAR( 10), ' +    
                  '@cCCSheetNo                NVARCHAR( 10), ' +    
                  '@cStorerkey                NVARCHAR( 15), ' +    
                  '@cFacility                 NVARCHAR( 5),  ' +    
                  '@cCurrSuggestLOC           NVARCHAR( 10), ' +    
                  '@cCurrSuggestSKU           NVARCHAR( 20), ' +    
 '@cCountNo                  NVARCHAR( 1),  ' +    
                  '@cUserName                 NVARCHAR( 18),        ' +    
                  '@cSuggestLogiLOC           NVARCHAR( 10) OUTPUT, ' +    
                  '@cSuggestLOC               NVARCHAR( 10) OUTPUT, ' +    
                  '@cSuggestSKU               NVARCHAR( 20) OUTPUT, ' +    
                  '@nErrNo                    INT           OUTPUT, ' +    
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT  '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, 'ZZZZZZZZZZZZZZZZZZZZ',    
                    @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
                  GOTO Step_3_Fail    
               END    
            END    
    ELSE    
            BEGIN    
               -- Get Next SKU / Next Loc    
               EXECUTE rdt.rdt_SimpleCC_GetNextLOC    
               @cCCKey,    
               @cCCSheetNo,     
               @cStorerKey,    
               @cFacility,    
               @cSuggestLogiLOC,    
               'ZZZZZZZZZZZZZZZZZZZZ',    
               @cSuggestLogiLOC OUTPUT,    
               @cSuggestLOC     OUTPUT,    
               @cSuggestSKU     OUTPUT,    
       @cCountNo,    
               @cUserName    
            END    
    
            IF @cSuggestLoc <> ''    
            BEGIN    
               SET @cOutField04 = @cSuggestLOC    
            END    
            ELSE    
            BEGIN    
               -- Update RDT.RDTCCLock.Status = '9' When No More Task    
               UPDATE rdt.rdtCCLock WITH (ROWLOCK)    
               SET Status = '9'    
               WHERE CCKey = @cCCKey    
               AND StorerKey = @cStorerKey    
               AND Loc = @cLoc    
               AND (( ISNULL( @cCCSheetNo, '') = '') OR ( SheetNo = @cCCSheetNo))    
    
               SET @cSuggestSKU = ''    
               SET @cSuggestLogiLOC = ''    
               SET @cSuggestLOC = ''    
    
               SET @nFromScn = 0    
               SET @nFromStep = 0    
    
               -- Display No Task Error Message    
               SET @nErrNo = 72782    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoMoreCCTask'    
    
               -- Back To  Screen 1 when No Task    
               SET @cOutField01 = CASE WHEN @cRetainCCKey = '1' THEN @cCCKey ELSE '' END    
               SET @cOutField02 = ''    
    
               SET @nStep = @nStep - 2    
               SET @nScn  = @nScn -2    
    
               GOTO QUIT    
            END    
    
            -- If SuggestLoc <> Current Loc , GOTO Loc Screen    
            IF @cSuggestLoc <> @cLoc    
            BEGIN    
               -- Update RDT.RDTCCLock.Status = '9' When User Switch Loc    
               UPDATE rdt.rdtCCLock WITH (ROWLOCK)    
               SET Status = '9'    
               WHERE CCKey = @cCCKey    
               AND StorerKey = @cStorerKey    
               AND Loc = @cLoc    
               AND (( ISNULL( @cCCSheetNo, '') = '') OR ( SheetNo = @cCCSheetNo))    
    
               DELETE FROM rdt.rdtCCLock    
               WHERE CCKey = @cCCKey    
               AND Loc <> @cSuggestLoc    
               AND AddWho = @cUserName    
    
               INSERT INTO RDT.RDTCCLock    
                  (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,    
                  Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,    
                  StorerKey,  Sku,        Lot,         Loc, Id,    
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,    
                  SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)    
               SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey, CCD.CCSheetNo,  @cCountNo,    
                  '',        '',        '',         '',       '',       Loc.LocAisle, Loc.LocLevel,    
                  @cStorerKey,  CCD.SKU,        CCD.LOT,         CCD.LOC,        CCD.ID,    
                  CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,  CCD.Lottable04, CCD.Lottable05,    
                  CCD.SystemQty,    
                  CASE WHEN @cCountNo = '1' THEN CCD.Qty    
                       WHEN @cCountNo = '2' THEN CCD.Qty_Cnt2    
                       WHEN @cCountNo = '3' THEN CCD.Qty_Cnt3    
                  END,    
                  '3',             '',             @cUserName,     GETDATE()    
               FROM dbo.CCDETAIL CCD WITH (NOLOCK)    
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = CCD.Loc    
               WHERE CCD.CCKey = @cCCKey    
               AND ( CCD.StorerKey = '' OR CCD.StorerKey = @cStorerKey)    
               AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))    
               AND   CCD.Loc = @cSuggestLoc    
               AND   1 =   CASE    
                              WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
                              WHEN @cCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
                              WHEN @cCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
                           ELSE 1 END    
    
               IF @@ROWCOUNT = 0 -- No data in CCDetail    
               BEGIN    
                  SET @nErrNo = 72780    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'    
                  GOTO Step_1_Fail    
               END    
    
               SET @cOutField01 = @cCCKey    
               SET @cOutField02 = ''    
               SET @cOutField03 = @cCountNo    
    
               SET @cOutField04 = @cSuggestLOC    
               SET @cOutField06 = @cCCSheetNo    
    
               SET @nFromScn = 0    
               SET @nFromStep = 0    
    
               SET @nScn  = @nScn - 1    
               SET @nStep = @nStep - 1    
    
               GOTO QUIT    
            END    
    
            SET @cOutField11 = @cSuggestSKU    
         END    
         ELSE    
         BEGIN    
            -- (jamesxxx)    
            IF rdt.RDTGetConfig( @nFunc, 'SimpleCCNoSuggSKU', @cStorerkey) = 1    
               SET @cOutField11 = ''    
            ELSE    
               SET @cOutField11 = @cSuggestSKU    
         END    
      END    
      ELSE    
      BEGIN    
         SET @cOutField11 = ''    
      END    
    
      SET @cCaptureID = ''     --INC0606210      
    
      -- Capture ID    
      IF @cCaptureIDSP <> ''    
      BEGIN    
         IF @cCaptureIDSP = '1'    
            SET @cCaptureID = '1'    
             
         -- Customize capture ID    
         ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCaptureIDSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCaptureIDSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
               ' @cCaptureID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,            ' +    
               ' @nFunc          INT,            ' +    
               ' @cLangCode      NVARCHAR( 3),   ' +    
               ' @nStep          INT,            ' +    
               ' @nInputKey      INT,            ' +    
               ' @cFacility      NVARCHAR( 5),   ' +    
               ' @cStorerKey     NVARCHAR( 15),  ' +    
               ' @cCCKey         NVARCHAR( 10),  ' +    
               ' @cCCSheetNo     NVARCHAR( 10),  ' +    
               ' @cCountNo       NVARCHAR( 1),   ' +    
               ' @cLOC           NVARCHAR( 10),  ' +    
               ' @cSKU           NVARCHAR( 20),  ' +    
               ' @nQTY           INT,            ' +    
               ' @cOption        NVARCHAR( 1),   ' +    
               ' @tVar           VariableTable READONLY, ' +    
               ' @cCaptureID     NVARCHAR( 1)  OUTPUT,   ' +    
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
               @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
               @cCaptureID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END    
      END    
    
      IF @cCaptureID = '1'    
      BEGIN    
         SET @cOutField01 = '' -- ID    
             
         SET @nScn  = @nScn + 6    
         SET @nStep = @nStep + 6    
             
         GOTO Quit    
      END    
    
      -- Disable QTY field    
      IF @cDisableQTYFieldSP <> ''    
      BEGIN    
         IF @cDisableQTYFieldSP = '1'    
            SET @cDisableQTYField = @cDisableQTYFieldSP    
         ELSE    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                  ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar, ' +    
                  ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  ' @nMobile           INT,            ' +    
                  ' @nFunc             INT,            ' +    
                  ' @cLangCode         NVARCHAR( 3),   ' +    
                  ' @nStep             INT,            ' +    
                  ' @nInputKey         INT,            ' +    
                  ' @cFacility         NVARCHAR( 5),   ' +    
                  ' @cStorerKey        NVARCHAR( 15),  ' +    
                  ' @cCCKey            NVARCHAR( 10),  ' +    
                  ' @cCCSheetNo        NVARCHAR( 10),  ' +    
                  ' @cCountNo          NVARCHAR( 1),   ' +    
                  ' @cLOC              NVARCHAR( 10),  ' +    
                  ' @cID               NVARCHAR( 18),  ' +    
                  ' @tVar              VariableTable READONLY, ' +    
                  ' @cDisableQTYField  NVARCHAR( 1)  OUTPUT,   ' +    
                  ' @nErrNo            INT           OUTPUT,   ' +    
                  ' @cErrMsg           NVARCHAR( 20) OUTPUT    '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                  @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar,    
                  @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
            END    
         END    
    
         SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)    
         IF @cDefaultQTY = '0'    
            SET @cDefaultQTY = ''    
    
         IF @cDisableQTYField = '1'    
            IF @cDefaultQTY = ''    
               SET @cDefaultQTY = '1'    
      END    
    
      -- Enable / disable QTY field    (james01)    
      SET @cFieldAttr08 = 'o'    
      SET @cFieldAttr09= CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY    
    
      SET @cSKUValidated = '0'     
    
      -- Prepare Next Screen Var    
      SET @cOutField01 = @cCCKey    
      SET @cOutField02 = @cLoc    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
      SET @cOutField06 = @cCountNo    
      SET @cOutField07 = ''    
      SET @cOutField08 = ''    
      SET @cOutField09 = @cDefaultQTY    
      SET @cOutField10 =''    
      SET @cOutField11 =''    
      SET @cOutField12 = @cCCSheetNo    
      SET @cOutField13 = ''     
      SET @cOutField14 =''    
      SET @cOutField15 ='' -- ExtendedInfo    
    
      -- Set Focus on Field01    
      EXEC rdt.rdtSetFocusField @nMobile, 3    
    
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
    
      -- (ChewKP02)    
      SET @nFromScn = 0    
      SET @nFromStep = 0    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
          SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,            ' +    
               ' @nFunc          INT,            ' +    
               ' @cLangCode      NVARCHAR( 3),   ' +    
               ' @nStep          INT,            ' +    
               ' @nAfterStep     INT,            ' +    
               ' @nInputKey      INT,            ' +    
               ' @cFacility      NVARCHAR( 5),   ' +    
               ' @cStorerKey     NVARCHAR( 15),  ' +    
               ' @cCCKey         NVARCHAR( 10),  ' +    
               ' @cCCSheetNo     NVARCHAR( 10),  ' +    
               ' @cCountNo       NVARCHAR( 1),   ' +    
               ' @cLOC           NVARCHAR( 10),  ' +    
               ' @cSKU           NVARCHAR( 20),  ' +    
               ' @nQTY           INT,            ' +    
               ' @cOption        NVARCHAR( 1),   ' +    
               ' @tVar           VariableTable READONLY, ' +    
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey,    
               @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
    
            IF @nStep = 3    
               SET @cOutField07 = @cExtendedInfo    
         END    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @cOutField01 = @cCCKey    
      SET @cOutField03 = @cCountNo    
      SET @cOutField02 = '' --@cLoc -- (ChewKP02)    
    
      -- (ChewKP02)    
      IF @nFunc = 732    
      BEGIN    
         SET @cOutField04 = @cSuggestLoc    
      END    
      ELSE    
      BEGIN    
         SET @cOutField04 = ''    
      END    
    
      IF EXISTS( SELECT TOP 1 1    
         FROM dbo.CCDetail CCD (NOLOCK)    
            INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)    
         WHERE CCD.CCKey   = @cCCKey    
         AND CCD.StorerKey = @cStorerKey    
         AND LOC.Facility  = @cFacility    
         AND LOC.LOC = @cSuggestLOC    
         AND ( (@cCountNo = '1' AND Counted_Cnt1 = 1) OR    
               (@cCountNo = '2' AND Counted_Cnt2 = 1) OR    
               (@cCountNo = '3' AND Counted_Cnt3 = 1)))    
    
         SET @cOutField05 = '[C]'    
      ELSE    
         SET @cOutField05 = ''    
      SET @cOutField06 = @cCCSheetNo    
    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_3_Fail:    
   BEGIN    
      SET @cOutField01 = @cCCKey    
      SET @cOutField02 = @cLoc    
      SET @cOutField03 = @cCountNo    
    
      IF @cHideScanInformation  = '1'    
      BEGIN    
         SET @cOutField04 = ''    
         SET @cOutField05 = ''    
      END    
      ELSE    
      BEGIN    
         SET @cOutField04 = 'SKU:' +  CAST(@nTotalSKUCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalSKUCount AS NVARCHAR(5))    
         SET @cOutField05 = 'QTY:' +  CAST(@nTotalQtyCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalQty AS NVARCHAR(5))    
      END    
    
      SET @cOutField06 = @cCCSheetNo    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 4. screen = 2773    
   CCKEy    (Field01)    
   CCSHEET  (Field11)    
   CountNo  (Field06)    
   LOC      (Field02)    
   Sugg SKU (Field10)    
   SKU      (Field03, input)    
   SKU      (Field04)    
   SKU DESC (Field05)    
   SKU DESC (Field07)    
   QTY      (Field08, input)    
   TTL QTY  (Field09)    
   EXTINFO  (Field12)    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      --screen mapping    
      SET @cInSKU = ISNULL(RTRIM(@cInField03),'')    
          
      SET @nPQTY = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END        
      SET @nMQTY = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END        
    
      --Piece scanning    -- (james01)    
      --If DisableQTYField turn on then check DefaultQty    
      --If not setup then default as 1 else use qty from DefaultQty    
      IF @cDisableQTYField = '1'    
         SET @nMQTY = CASE WHEN ISNULL(@cDefaultQTY, '') = '' OR @cDefaultQTY = '0' THEN '1' ELSE @cDefaultQTY END    
    
      IF ISNULL(RTRIM(@cInSKU), '') = '' --AND @cSKUValidated = '0' -- False    
      BEGIN    
         SET @nErrNo = 72747    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Req'    
         EXEC rdt.rdtSetFocusField @nMobile, 3    
         GOTO Step_4_Fail    
      END    
    
      -- Check SKU format    
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SKU', @cInSKU) = 0 AND     
         @cInSKU <> '99'    
      BEGIN    
         SET @nErrNo = 129017    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
         GOTO Step_4_Fail    
      END    
    
      IF @cInSKU = '99' -- Fully short    
      BEGIN    
         SET @cSKUValidated = '99'    
         SET @nInQty = ''    
         SET @cOutField08 = '0'    
      END    
      ELSE    
      BEGIN    
         SET @cDecodeLabelNo = ''    
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)    
    
         SET @cSKU = ''    
    
         IF LEN(ISNULL(RTRim(@cInSKU),'')) > 20 AND ISNULL(@cDecodeLabelNo,'') <> ''    
         BEGIN    
            IF ISNULL(@cDecodeLabelNo,'') <> '0'    
            BEGIN    
               EXEC dbo.ispLabelNo_Decoding_Wrapper    
                @c_SPName     = @cDecodeLabelNo    
               ,@c_LabelNo    = @cInSKU    
               ,@c_Storerkey  = @cStorerkey    
               ,@c_ReceiptKey = ''    
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
                  SET @cErrMsg = @cErrMsg    
                  GOTO Step_4_Fail    
               END    
    
               SET @cSKU = @c_oFieled01    
               SET @nQty = @c_oFieled05    
            END    
            ELSE    
            BEGIN    
               SET @cSKU = ISNULL(@cInSKU,'')    
            END    
         END    
         ELSE    
         BEGIN    
            SET @cSKU = ISNULL(@cInSKU,'')    
         END    
    
         -- (james03)    
         SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)    
         IF @cDecodeSP = '0'    
            SET @cDecodeSP = ''    
    
         IF @cDecodeSP <> ''    
         BEGIN    
            SET @cBarcode = @cInSKU    
            SET @cUPC = SUBSTRING( @cInSKU, 1, 30)    
            SET @nQty = CASE WHEN ISNULL(@cDefaultQTY, '') = '' OR @cDefaultQTY = '0' THEN '1' ELSE @cDefaultQTY END            
            SET @nErrNo = 0 
    
            -- Standard decode    
            IF @cDecodeSP = '1'    
               EXEC rdt.rdt_Decode
                  @nMobile       = @nMobile,      
                  @nFunc         = @nFunc,        
                  @cLangCode     = @cLangCode,    
                  @nStep         = @nStep,        
                  @nInputKey     = @nInputKey,    
                  @cStorerKey    = @cStorerKey,   
                  @cFacility     = @cFacility,    
                  @cBarcode      = @cBarcode,     
                  @cID           = @cID           OUTPUT,          
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
                  @cUserDefine01 = @cUserDefine01 OUTPUT,
                  @cUserDefine02 = @cUserDefine02 OUTPUT,
                  @cUserDefine03 = @cUserDefine03 OUTPUT,
                  @cUserDefine04 = @cUserDefine04 OUTPUT,
                  @cUserDefine05 = @cUserDefine05 OUTPUT,
                  @cType = 'UPC'        
    
            -- Customize decode    
            ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCCKey, @cCCSheetNo, @cCountNo, @cBarcode, ' +    
                  ' @cLOC           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, ' +    
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
                  ' @cCCKey         NVARCHAR( 10), ' +    
                  ' @cCCSheetNo     NVARCHAR( 10), ' +    
                  ' @cCountNo       NVARCHAR( 1),  ' +    
                  ' @cBarcode       NVARCHAR( 60), ' +    
                  ' @cLOC           NVARCHAR( 10)  OUTPUT, ' +    
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
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCCKey, @cCCSheetNo, @cCountNo, @cBarcode,    
                  @cLOC          OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,    
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,    
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,    
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,    
                  @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,    
                  @nErrNo        OUTPUT, @cErrMsg        OUTPUT    
            END    
    
            IF @nErrNo <> 0    
               GOTO Step_4_Fail    
            ELSE    
            BEGIN    
               SET @cSKU = @cUPC    
    
               IF ISNULL( @nQty, 0) <> 0    
                  SET @nInQty = @nQty    
            END    
         END   -- End for DecodeSP   
         
         EXEC [RDT].[rdt_GETSKUCNT]  
          @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cSKU  
         ,@nSKUCnt     = @nSKUCnt       OUTPUT  
         ,@bSuccess    = @b_Success     OUTPUT  
         ,@nErr        = @n_Err         OUTPUT  
         ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
         -- Check barcode return multi SKU  
         IF @nSKUCnt > 1  
         BEGIN  
            -- (james03)  
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
                  '',    -- DocType  
                  ''  
  
               IF @nErrNo = 0 -- Populate multi SKU screen  
               BEGIN  
                  -- Go to Multi SKU screen  
                  SET @nFromScn = @nScn  
                  SET @nScn = 3570  
                  SET @nStep = @nStep + 7 
                  GOTO Quit  
               END  
               IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen  
               BEGIN  
                  SET @nErrNo = 0  
           SET @cSKU = @cSKU  
               END  
            END  
            ELSE  
            BEGIN  
               SET @nErrNo = 59425  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod  
               GOTO Step_4_Fail  
            END  
  
         END   
    
         EXEC [RDT].[rdt_GETSKU]    
                  @cStorerKey  = @cStorerkey,    
                  @cSKU        = @cSKU          OUTPUT,    
                  @bSuccess    = @b_Success     OUTPUT,    
                  @nErr        = @nErrNo        OUTPUT,    
                  @cErrMsg     = @cErrMsg       OUTPUT,    
                  @cSKUStatus  = @cSKUStatus    
    
         IF @nErrNo <> 0    
         BEGIN    
            SET @nErrNo = 72748    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
            EXEC rdt.rdtSetFocusField @nMobile, 3    
            GOTO Step_4_Fail    
         END    
             
         -- (ChewKP02)    
         IF @nFunc = 732    
         BEGIN    
            IF @cSKU <> @cSuggestSKU AND ISNULL( @cOutField11, '') <> ''    
            BEGIN    
               SET @nErrNo = 72783    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotMatch    
               EXEC rdt.rdtSetFocusField @nMobile, 3    
               GOTO Step_4_Fail    
            END    
         END    
      END    
    
      -- Mark SKU as validated    
      SET @cSKUValidated = '1'    
    
      -- If qty decoded is blank/null then take qty from screen    
      --SET @nInQty = CASE WHEN ISNULL( @nQty, 0) = 0 THEN @nInQty ELSE @nQty END    
      IF @cDecodeSP = ''
      BEGIN
         SET @nInQty = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nPQTY, @cPUOM, 6) -- Convert to QTY in master UOM       
         SET @nInQty = @nInQTY + @nMQTY        
      END
    
      -- Check full short with QTY    
      IF @cSKUValidated = '99' AND ( (@nInQty <> '0' AND @nInQty <> ''))    
      BEGIN    
         SET @nErrNo = 72767    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FullShortNoQTY    
         GOTO Step_4_Fail    
      END    
    
      SELECT        
         @cSKUDesc = IsNULL( DescR, ''),        
         @cMUOM_Desc = Pack.PackUOM3,        
         @cPUOM_Desc =        
            CASE @cPUOM        
               WHEN '2' THEN Pack.PackUOM1 -- Case        
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack        
               WHEN '6' THEN Pack.PackUOM3 -- Masterk unit        
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
    
      SET @cOutField03 = @cSKU    
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1    
      SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2    
    
      IF ISNULL( @nInQty, '') = ''    
      BEGIN    
         IF @cPUOM = '6' OR -- When preferred UOM = master unit        
            @nPUOM_Div = 0  -- UOM not setup        
         BEGIN        
            EXEC rdt.rdtSetFocusField @nMobile, 9    
            SET @cOutField14 = rdt.rdtRightAlign( @cMUOM_Desc, 5)     
    SET @cPUOM_Desc = ''      
            SET @nPQTY = 0        
            SET @nMQTY = @cDefaultQTY        
            SET @cFieldAttr08 = 'O' -- @nPQTY       
            SET @cOutField09 = CASE WHEN @nMQTY NOT IN ('', '0') THEN @nMQTY ELSE '' END    
         END    
         ELSE    
         BEGIN    
            SET @cOutField13 = rdt.rdtRightAlign( @cPUOM_Desc, 5)        
            SET @cOutField14 = rdt.rdtRightAlign( @cMUOM_Desc, 5)      
            EXEC rdt.rdtSetFocusField @nMobile, 8    
    
            SET @cFieldAttr08 = '' -- @nPQTY       
    
            SET @nPQTY = CASE WHEN @cDefaultQTY NOT IN ('', '0') THEN @cDefaultQTY / @nPUOM_Div  ELSE '' END    
            SET @nMQTY = CASE WHEN @cDefaultQTY NOT IN ('', '0') THEN @cDefaultQTY % @nPUOM_Div  ELSE '' END    
    
            SET @cOutField08 = CASE WHEN @nPQTY NOT IN ('', '0') THEN @nPQTY ELSE '' END    
            SET @cOutField09 = CASE WHEN @nPQTY NOT IN ('', '0') THEN @nMQTY ELSE '' END    
    
         END    
         GOTO Quit    
      END    
    
      -- Check SKU format    
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'QTY', @nInQty) = 0 AND    
         @cSKUValidated <> '99'    
      BEGIN    
         SET @nErrNo = 129018    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
         EXEC rdt.rdtSetFocusField @nMobile, 8    
         SET @cOutField08 = CASE WHEN @cDefaultQTY NOT IN ('', '0') THEN @cDefaultQTY ELSE '' END    
         GOTO Quit    
      END    
    
      IF ( @nInQty <> '' AND @cSKUValidated <> '99') -- Not fully short, prompt error    
      BEGIN    
         IF rdt.rdtIsValidQTY( @nInQty, 0) = 0    
         BEGIN    
            SET @nErrNo = 72757    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'    
            EXEC rdt.rdtSetFocusField @nMobile, 8    
            SET @cOutField08 = CASE WHEN @cDefaultQTY NOT IN ('', '0') THEN @cDefaultQTY ELSE '' END    
            GOTO Quit    
         END    
      END    
    
      SET @nQty = CAST (@nInQty AS INT)    
    
    
      IF @cExtendedValidateSP <> '' AND    
         EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQty, @cOption,' +    
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
         SET @cSQLParam =    
            '@nMobile      INT,           ' +    
            '@nFunc        INT,           ' +    
            '@nStep        INT,           ' +    
            '@nInputKey    INT,           ' +    
            '@cLangCode    NVARCHAR( 3),  ' +    
            '@cStorerkey   NVARCHAR( 15), ' +    
            '@cCCKey       NVARCHAR( 10), ' +    
            '@cCCSheetNo   NVARCHAR( 10), ' +    
            '@cCountNo     NVARCHAR( 1),  ' +    
            '@cLOC         NVARCHAR( 10), ' +    
            '@cSKU         NVARCHAR( 20), ' +    
            '@nQty         INT,           ' +    
            '@cOption      NVARCHAR( 1),  ' +    
            '@nErrNo       INT           OUTPUT, ' +    
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nInQty, @cOption,    
              @nErrNo OUTPUT, @cErrMsg OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
    
      -- Confirm CC By Looping the Location    
      SET @cCCUpdateSP = ''    
      SET @cCCUpdateSP = rdt.RDTGetConfig( @nFunc, 'SimpleCCUpdateLogic', @cStorerkey)    
    
      IF ISNULL(@cCCUpdateSP,'') NOT IN ('0', '') -- (james02)    
      BEGIN   
         EXEC dbo.ispCycleCount_Wrapper    
          @c_SPName     = @cCCUpdateSP    
         ,@c_SKU        = @cSKU    
         ,@c_Storerkey  = @cStorerkey    
         ,@c_Loc        = @cLoc    
         ,@c_ID         = @cID    
         ,@c_CCKey      = @cCCKey    
         ,@c_CountNo    = @cCountNo    
         ,@c_Ref01      = @cCCSheetNo    
         ,@c_Ref02      = ''    
         ,@c_Ref03      = ''    
         ,@c_Ref04      = ''    
         ,@c_Ref05      = ''    
         ,@n_Qty        = @nQty    
         ,@c_Lottable01Value  = ''    
         ,@c_Lottable02Value  = ''    
         ,@c_Lottable03Value  = ''    
         ,@dt_Lottable04Value = ''    
         ,@dt_Lottable05Value = ''    
         ,@c_LangCode   = @cLangCode    
         ,@c_oFieled01  = @c_oFieled01 OUTPUT    
         ,@c_oFieled02  = @c_oFieled02 OUTPUT    
         ,@c_oFieled03  = @c_oFieled03 OUTPUT    
         ,@c_oFieled04  = @c_oFieled04 OUTPUT    
         ,@c_oFieled05  = @c_oFieled05 OUTPUT    
         ,@c_oFieled06  = @c_oFieled06 OUTPUT    
         ,@c_oFieled07  = @c_oFieled07 OUTPUT    
         ,@c_oFieled08  = @c_oFieled08 OUTPUT    
         ,@c_oFieled09  = @c_oFieled09 OUTPUT    
         ,@c_oFieled10  = @c_oFieled10 OUTPUT    
         ,@b_Success    = @b_Success   OUTPUT    
         ,@n_ErrNo      = @nErrNo      OUTPUT    
         ,@c_ErrMsg     = @cErrMsg     OUTPUT    
    
         IF ISNULL(@cErrMsg, '') <> ''    
         BEGIN    
            SET @cErrMsg = @cErrMsg    
            GOTO Step_4_Fail    
         END    
    
      END    
      ELSE    
      BEGIN    
         SET @nErrNo = 72766    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdSP Req'    
         EXEC rdt.rdtSetFocusField @nMobile, 8    
         GOTO Step_4_Fail    
      END    
    
      -- insert to Eventlog    
      EXEC RDT.rdt_STD_EventLog    
           @cActionType   = '3', -- Sign Out    
           @cUserID       = @cUserName,    
           @nMobileNo     = @nMobile,    
           @nFunctionID   = @nFunc,    
           @cFacility     = @cFacility,    
           @cStorerKey    = @cStorerkey,    
           @cCCKey        = @cCCKey,    
           --@cRefNo1       = @cCCKey,    
           @cLocation     = @cLoc,    
           @cSKU          = @cSKU,    
           @cRefNo4       = '',    
           @nQty          = @nQty,    
           @nStep         = @nStep    
    
      SET @nTotalSKUQty = 0    
      SET @nTotalQty2 = 0    
      SET @nTotalQty3 = 0    
    
      SELECT @nTotalSKUQty = Sum(Qty),    
             @nTotalQty2 = Sum(Qty_Cnt2),    
             @nTotalQty3 = Sum(Qty_Cnt3)    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE ( StorerKey = '' OR StorerKey = @cStorerKey)    
      AND   CCKey = @cCCKey    
      AND   Loc = @cLoc    
      AND   SKU = @cSKU    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
      AND (( @cCaptureID IN('','0') AND ID = ID) OR ( @cCaptureID = '1' AND ID = @cID)) 
    
      -- Enable / disable QTY field    (james01)    
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY    
    
      SET @cOutField02 = @cLoc    
      SET @cOutField03 = ''    
      SET @cOutField04 = @cSKU    
    
      SET @cSKUDesc = ''    
    
      SELECT @cSKUDesc = DESCR    
      FROM dbo.SKU WITH (NOLOCK)    
      WHERE SKU = @cSKU    
      AND Storerkey = @cStorerkey    
    
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1    
      SET @cOutField06 = @cCountNo    
      SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2    
    
 IF @cPUOM = '6' OR -- When preferred UOM = master unit        
         @nPUOM_Div = 0  -- UOM not setup        
      BEGIN        
         SET @cPUOM_Desc = ''      
         SET @cOutField14 = rdt.rdtRightAlign( @cMUOM_Desc, 5)      
         SET @nPQTY = 0        
         SET @nMQTY = @cDefaultQTY        
         SET @cFieldAttr08 = 'O' -- @nPQTY       
         SET @cOutField09 = CASE WHEN @nMQTY NOT IN ('', '0') THEN @nMQTY ELSE '' END   
         EXEC rdt.rdtSetFocusField @nMobile, 9   
      END    
      ELSE    
      BEGIN    
         SET @cOutField13 = rdt.rdtRightAlign( @cPUOM_Desc, 5)        
         SET @cOutField14 = rdt.rdtRightAlign( @cMUOM_Desc, 5)     
         EXEC rdt.rdtSetFocusField @nMobile, 8    
    
         SET @nPQTY = CASE WHEN @cDefaultQTY NOT IN ('', '0') THEN @cDefaultQTY / @nPUOM_Div  ELSE '' END    
         SET @nMQTY = CASE WHEN @cDefaultQTY NOT IN ('', '0') THEN @cDefaultQTY % @nPUOM_Div  ELSE '' END    
    
         SET @cOutField08 = CASE WHEN @nPQTY NOT IN ('', '0') THEN @nPQTY ELSE '' END    
         SET @cOutField09 = CASE WHEN @nPQTY NOT IN ('', '0') THEN @nMQTY ELSE '' END    
    
      END    
          
      IF @cCountNo = '1' SET @cOutField10 = CAST( @nTotalSKUQty AS NVARCHAR(5)) ELSE    
      IF @cCountNo = '2' SET @cOutField10 = CAST( @nTotalQty2   AS NVARCHAR(5)) ELSE    
      IF @cCountNo = '3' SET @cOutField10 = CAST( @nTotalQty3   AS NVARCHAR(5))    
    
      SET @cOutField12 = @cCCSheetNo    
      SET @cOutField15 = '' -- ExtendedInfo    
    
      EXEC rdt.rdtSetFocusField @nMobile, 3    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            INSERT INTO @tVar (Variable, Value) VALUES     
            ('@cID',       @cID)    
    
            SET @cExtendedInfo = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,            ' +    
               ' @nFunc          INT,            ' +    
               ' @cLangCode      NVARCHAR( 3),   ' +    
               ' @nStep          INT,            ' +    
               ' @nAfterStep     INT,            ' +    
               ' @nInputKey      INT,            ' +    
               ' @cFacility      NVARCHAR( 5),   ' +    
               ' @cStorerKey     NVARCHAR( 15),  ' +    
               ' @cCCKey         NVARCHAR( 10),  ' +    
               ' @cCCSheetNo     NVARCHAR( 10),  ' +    
               ' @cCountNo       NVARCHAR( 1),   ' +    
               ' @cLOC           NVARCHAR( 10),  ' +    
               ' @cSKU           NVARCHAR( 20),  ' +    
               ' @nQTY           INT,            ' +    
               ' @cOption        NVARCHAR( 1),   ' +    
               ' @tVar           VariableTable READONLY, ' +    
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey,    
               @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
    
            IF @nStep = 4    
               SET @cOutField15 = @cExtendedInfo    
         END    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- (james13)    
      IF @cExtendedUpdateSP <> '' AND    
         EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQty, @cOption,' +    
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
         SET @cSQLParam =    
            '@nMobile      INT,           ' +    
            '@nFunc        INT,           ' +    
            '@nStep        INT,           ' +    
            '@nInputKey    INT,           ' +    
            '@cLangCode    NVARCHAR( 3),  ' +    
            '@cStorerkey   NVARCHAR( 15), ' +    
            '@cCCKey       NVARCHAR( 10), ' +    
            '@cCCSheetNo   NVARCHAR( 10), ' +    
            '@cCountNo     NVARCHAR( 1),  ' +    
            '@cLOC       NVARCHAR( 10), ' +    
            '@cSKU         NVARCHAR( 20), ' +    
            '@nQty         INT,           ' +    
            '@cOption      NVARCHAR( 1),  ' +    
            '@nErrNo       INT           OUTPUT, ' +    
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQty, @cOption,    
              @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
    
      IF @cCaptureID = '1'    
      BEGIN    
         SET @cOutField01 = '' -- Option    
             
         -- Go to ID screen    
         SET @nScn = @nScn + 5    
         SET @nStep = @nStep + 5             
             
         GOTO Quit    
      END    
          
      IF @cConfirmLOCCounted > '0'    
      BEGIN    
         SET @nVariance = 0    
             
         -- Check variance    
         IF @cCountNo = '1'    
            SELECT TOP 1    
               @nVariance = 1    
            FROM dbo.CCDEtail WITH (NOLOCK)    
            WHERE CCKey = @cCCKey    
               AND   LOC = @cLoc    
               AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            GROUP BY StorerKey, SKU    
            HAVING SUM( SystemQTY) <> SUM( QTY)    
    
         ELSE IF @cCountNo = '2'    
            SELECT TOP 1    
               @nVariance = 1    
            FROM dbo.CCDEtail WITH (NOLOCK)    
            WHERE CCKey = @cCCKey    
               AND   LOC = @cLoc    
               AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            GROUP BY StorerKey, SKU    
            HAVING SUM( SystemQTY) <> SUM( QTY_Cnt2)    
    
         ELSE IF @cCountNo = '3'    
            SELECT TOP 1    
               @nVariance = 1    
            FROM dbo.CCDEtail WITH (NOLOCK)    
            WHERE CCKey = @cCCKey    
               AND   LOC = @cLoc    
               AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            GROUP BY StorerKey, SKU    
            HAVING SUM( SystemQTY) <> SUM( QTY_Cnt3)    
    
             
         -- Variance found    
         -- Or config turn on with svalue = 2 (always go to confirm loc screen)
         IF @nVariance = 1 OR @cConfirmLOCCounted = '2'   
         BEGIN    
            SET @cOutField01 = '' -- Option    
                
            -- Go to confirm LOC counted screen    
            SET @nScn = @nScn + 4    
            SET @nStep = @nStep + 4             
                
            GOTO Quit    
         END    
      END    
          
      -- When ESC, whatever CCDetail line not counted in this LOC is treated as Counted    
      -- Set qty = 0 to prevent CCSheet is populated with quantity    
      UPDATE dbo.CCDEtail WITH (ROWLOCK) SET    
        Qty      = CASE WHEN @cCountNo = '1' THEN 0 ELSE Qty  END    
      , Qty_Cnt2 = CASE WHEN @cCountNo = '2' THEN 0 ELSE Qty_Cnt2 END    
      , Qty_Cnt3 = CASE WHEN @cCountNo = '3' THEN 0 ELSE Qty_Cnt3 END    
      , Status  = '2'  
      , Counted_Cnt1 = CASE WHEN @cCountNo = '1' THEN '1' ELSE Counted_Cnt1 END    
      , Counted_Cnt2 = CASE WHEN @cCountNo = '2' THEN '1' ELSE Counted_Cnt2 END    
      , Counted_Cnt3 = CASE WHEN @cCountNo = '3' THEN '1' ELSE Counted_Cnt3 END    
      , EditWho_Cnt1 = CASE WHEN @cCountNo = '1' THEN @cUserName ELSE EditWho_Cnt1 END    
      , EditWho_Cnt2 = CASE WHEN @cCountNo = '2' THEN @cUserName ELSE EditWho_Cnt2 END    
      , EditWho_Cnt3 = CASE WHEN @cCountNo = '3' THEN @cUserName ELSE EditWho_Cnt3 END    
      , EditDate_Cnt1 = CASE WHEN @cCountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END    
      , EditDate_Cnt2 = CASE WHEN @cCountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END    
      , EditDate_Cnt3 = CASE WHEN @cCountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END    
      WHERE CCKey = @cCCKey    
      AND   LOC = @cLoc    
      AND   1 = CASE    
                WHEN @cCountNo = '1' AND Counted_Cnt1 = 0 THEN 1    
                WHEN @cCountNo = '2' AND Counted_Cnt2 = 0 THEN 1    
                WHEN @cCountNo = '3' AND Counted_Cnt3 = 0 THEN 1    
                ELSE 0 END    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 72787    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- UpdCCDetailFail    
         GOTO Step_4_Fail    
      END    
    
      --SOS365022 Start    
      UPDATE dbo.Loc WITH (ROWLOCK)    
     SET LastCycleCount = GetDate()    
        ,TrafficCop = NULL    
    WHERE Loc = @cLoc    
    
    IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 72788    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- UpdLocFail    
         GOTO Step_4_Fail    
      END    
      --SOS365022 End    
    
      IF @cExtendedValidateSP <> '' AND    
         EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQty, @cOption,' +    
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
         SET @cSQLParam =    
            '@nMobile      INT,           ' +    
            '@nFunc        INT,           ' +    
            '@nStep        INT,           ' +    
            '@nInputKey    INT,           ' +    
            '@cLangCode    NVARCHAR( 3),  ' +    
            '@cStorerkey   NVARCHAR( 15), ' +    
            '@cCCKey       NVARCHAR( 10), ' +    
            '@cCCSheetNo   NVARCHAR( 10), ' +    
            '@cCountNo     NVARCHAR( 1),  ' +    
            '@cLOC         NVARCHAR( 10), ' +    
            '@cSKU         NVARCHAR( 20), ' +    
            '@nQty         INT,           ' +    
            '@cOption      NVARCHAR( 1),  ' +    
            '@nErrNo       INT           OUTPUT, ' +    
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQty, @cOption,    
              @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
    
      SET @cCurrSuggestLogiLOC = @cSuggestLogiLOC    
      SET @cCurrSuggestLOC = @cSuggestLOC    
      SET @cCurrSuggestSKU = @cSuggestSKU    
      SET @cSuggestSKU = ''    
      SET @cSuggestLOC = ''    
    
      IF ISNULL( @cSuggestLogiLOC, '') = ''    
         SELECT @cSuggestLogiLOC = CCLogicalLoc    
         FROM dbo.LOC WITH (NOLOCK)    
         WHERE LOC = @cSuggestedLOC    
         AND   Facility = @cFacility    
    
      SET @cExtendedFetchTaskSP = ''    
      SET @cExtendedFetchTaskSP = rdt.RDTGetConfig( @nFunc, 'ExtendedFetchTaskSP', @cStorerKey)    
      IF @cExtendedFetchTaskSP NOT IN ('0', '')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedFetchTaskSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, @cCurrSuggestSKU,' +    
            ' @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
         SET @cSQLParam =    
            '@nMobile                   INT,           ' +    
            '@nFunc                     INT,           ' +    
            '@cLangCode                 NVARCHAR( 3),  ' +    
            '@nStep                     INT,           ' +    
            '@nInputKey                 INT,           ' +    
            '@cCCKey                    NVARCHAR( 10), ' +    
            '@cCCSheetNo                NVARCHAR( 10), ' +    
            '@cStorerkey                NVARCHAR( 15), ' +    
            '@cFacility                 NVARCHAR( 5),  ' +    
            '@cCurrSuggestLOC           NVARCHAR( 10), ' +    
            '@cCurrSuggestSKU           NVARCHAR( 20), ' +    
            '@cCountNo                  NVARCHAR( 1),  ' +    
            '@cUserName                 NVARCHAR( 18),        ' +    
            '@cSuggestLogiLOC           NVARCHAR( 10) OUTPUT, ' +    
            '@cSuggestLOC               NVARCHAR( 10) OUTPUT, ' +    
            '@cSuggestSKU               NVARCHAR( 20) OUTPUT, ' +    
            '@nErrNo                    INT           OUTPUT, ' +    
            '@cErrMsg                   NVARCHAR( 20) OUTPUT  '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, 'ZZZZZZZZZZZZZZZZZZZZ',    
              @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
            GOTO Step_2_Fail    
         END    
      END    
      ELSE    
      BEGIN    
         EXECUTE rdt.rdt_SimpleCC_GetNextLOC    
            @cCCKey,    
            @cCCSheetNo,     
            @cStorerKey,    
            @cFacility,    
            @cSuggestLogiLOC,          -- current CCLogicalLOC    
            'ZZZZZZZZZZZZZZZZZZZZ',    -- current SKU    
            @cSuggestLogiLOC OUTPUT,    
            @cSuggestLOC     OUTPUT,    
            @cSuggestSKU     OUTPUT,    
            @cCountNo,    
            @cUserName    
      END    
    
      IF @cSuggestLoc <> ''    
      BEGIN    
         IF @cAutoShowNextLoc2Count = '1' -- (james08)    
         BEGIN    
            DELETE FROM rdt.rdtCCLock    
            WHERE CCKey = @cCCKey    
            AND Loc <> @cSuggestLOC    
            AND AddWho = @cUserName    
    
            -- Insert into RDTCCLock    
            INSERT INTO RDT.RDTCCLock    
               (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,    
               Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,    
               StorerKey,  Sku,        Lot,         Loc, Id,    
               Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,    
               SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)    
            SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey, CCD.CCSheetNo,  @cCountNo,    
               '',        '',        '',         '',        '',       Loc.LocAisle, Loc.LocLevel,    
               @cStorerKey,  CCD.SKU,        CCD.LOT,         CCD.LOC,        CCD.ID,    
               CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,  CCD.Lottable04, CCD.Lottable05,    
               CCD.SystemQty,    
               CASE WHEN @cCountNo = '1' THEN CCD.Qty    
                    WHEN @cCountNo = '2' THEN CCD.Qty_Cnt2    
                    WHEN @cCountNo = '3' THEN CCD.Qty_Cnt3    
               END,    
               '3',             '',             @cUserName,     GETDATE()    
            FROM dbo.CCDETAIL CCD WITH (NOLOCK)    
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = CCD.Loc    
 WHERE CCD.CCKey = @cCCKey    
            AND ( CCD.StorerKey = '' OR CCD.StorerKey = @cStorerKey)    
            AND   CCD.Loc = @cSuggestLOC    
            AND  (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))    
            AND   1 =   CASE    
                        WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
                        WHEN @cCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
                        WHEN @cCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
                        ELSE 1 END    
    
            IF @@ROWCOUNT = 0 -- No data in CCDetail    
            BEGIN    
               SET @nErrNo = 72790    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'    
               GOTO Quit    
            END    
    
            SET @cOutField01 = @cCCKey    
            SET @cOutField02 = ''    
            SET @cOutField03 = @cCountNo    
            SET @cOutField04 = @cSuggestLOC    
            SET @cOutField05 = ''    
            SET @cOutField06 = @cCCSheetNo    
         END    
         ELSE    
         BEGIN    
            SET @cSuggestLogiLOC = @cCurrSuggestLogiLOC    
            SET @cSuggestLOC = @cCurrSuggestLOC    
            SET @cSuggestSKU = @cCurrSuggestSKU    
    
            SET @cOutField01 = @cCCKey    
            SET @cOutField02 = ''    
            SET @cOutField03 = @cCountNo    
            SET @cOutField04 = @cLoc    
            SET @cOutField05 = '[C]'    
            SET @cOutField06 = @cCCSheetNo    
         END    
    
         SET @nScn = @nScn - 2    
         SET @nStep = @nStep - 2    
      END    
      ELSE    
      BEGIN    
         -- Prep next screen var    
         SET @cOutField01 = CASE WHEN @cRetainCCKey = '1' THEN @cCCKey ELSE '' END      
         SET @cOutField02 = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
    
         DELETE FROM rdt.rdtCCLock    
         WHERE CCKey = @cCCKey    
         AND Loc <> @cSuggestLOC    
         AND AddWho = @cUserName    
    
         SET @cCCKey = ''    
         SET @cCCSheetNo = ''    
         SET @nScn = @nScn - 3    
         SET @nStep = @nStep - 3    
      END    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,            ' +    
               ' @nFunc          INT,            ' +    
               ' @cLangCode      NVARCHAR( 3),   ' +    
               ' @nStep          INT,            ' +    
               ' @nAfterStep     INT,            ' +    
               ' @nInputKey      INT,            ' +    
               ' @cFacility      NVARCHAR( 5),   ' +    
               ' @cStorerKey     NVARCHAR( 15),  ' +    
               ' @cCCKey         NVARCHAR( 10),  ' +    
               ' @cCCSheetNo     NVARCHAR( 10),  ' +    
               ' @cCountNo       NVARCHAR( 1),   ' +  
               ' @cLOC           NVARCHAR( 10),  ' +    
               ' @cSKU           NVARCHAR( 20),  ' +    
               ' @nQTY           INT,            ' +    
               ' @cOption        NVARCHAR( 1),   ' +    
               ' @tVar           VariableTable READONLY, ' +    
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey,    
               @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
   END    
   GOTO QUIT    
    
   Step_4_Fail:    
   BEGIN    
      SET @cSKU = ''    
      SET @cOutField03 = ''    
   --SET @cOutField08 = CASE WHEN @cDefaultQTY NOT IN ('', '0') THEN @cDefaultQTY ELSE '' END --(CIKFUN01)  
   	SET @cOutField08 = ''                   --(CIKFUN01)  
      SET @cOutField09 = CASE WHEN @cDefaultQTY NOT IN ('', '0') THEN @cDefaultQTY ELSE '' END  --(CIKFUN01)  
     
      -- Enable / disable QTY field    (james01)    
      SET @cFieldAttr08 =  'O'   
      SET @cFieldAttr09 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY    
   END    
    
END    
GOTO Quit    
    
/********************************************************************************    
Step 5. screen = 2774    
   Loc found add loc    
   Option (Field01, input)    
********************************************************************************/    
Step_5:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      --screen mapping    
      SET @cOption = ISNULL(RTRIM(@cInField01),'')    
    
      IF ISNULL(RTRIM(@cOption),'') = ''    
      BEGIN    
         SET @nErrNo = 72758    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_5_Fail    
      END    
    
      IF ISNULL(RTRIM(@cOption), '') <> '1' AND ISNULL(RTRIM(@cOption), '') <> '2'    
      BEGIN    
          SET @nErrNo = 72759    
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'    
          EXEC rdt.rdtSetFocusField @nMobile, 1    
          GOTO Step_5_Fail    
      END    
    
      IF ISNULL(RTRIM(@cOption), '') = '1'    
      BEGIN    
         BEGIN TRAN    
    
         EXECUTE dbo.nspg_GetKey    
         'CCDetailKey',    
         10,    
         @cCCDetailKey OUTPUT,    
         @b_success OUTPUT,    
         @n_err OUTPUT,    
         @c_errmsg OUTPUT    
    
         IF @n_err<>0    
         BEGIN    
             ROLLBACK TRAN    
             SET @nErrNo = 72760    
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --GetDetKey Fail    
             GOTO Step_5_Fail    
         END    
    
         IF ISNULL( @cCCSheetNo, '') = ''    
         BEGIN    
            EXECUTE dbo.nspg_GetKey    
               'CCSheetNo',    
               10,    
               @cCCSheetNo OUTPUT,    
               @b_success OUTPUT,    
               @n_err OUTPUT,    
               @c_errmsg OUTPUT    
    
            IF @n_err<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 72761    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --GetDetKey Fail    
               GOTO Step_5_Fail    
            END    
         END    
    
         INSERT INTO CCDetail (CCKey, CCDetailKey, CCSheetNo, Storerkey, Loc, SystemQty, Qty, Qty_Cnt2, Qty_Cnt3)    
         VALUES (@cCCKey, @cCCDetailKey, @cCCSheetNo, @cStorerkey, @cLoc, 0, 0, 0, 0)    
    
         IF @@ERROR<>0    
         BEGIN    
            ROLLBACK TRAN    
            SET @nErrNo = 72762    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- InsCCDet Fail    
            GOTO Step_5_Fail    
         END    
    
         SET @cLocAisle = ''    
         SET @nLocLevel = ''    
         SELECT @cLocAisle = LocAisle    
              , @nLocLevel = LocLevel    
         FROM dbo.Loc WITH (NOLOCK)    
         WHERE Loc = @cLoc    
         AND Facility = @cFacility    
    
         INSERT INTO RDT.RDTCCLock ( Mobile, CCKey, CCDetailKey, SheetNo, CountNo,  Aisle, Level, StorerKey, Loc, Status)    
         VALUES (@nMobile, @cCCKey, @cCCDetailKey, @cCCSheetNo, @cCountNo, @cLocAisle, @nLocLevel, @cStorerKey, @cLoc, '3')    
    
         COMMIT TRAN    
    
         SET @nTotalSKUCount = 0    
         SET @nTotalQty = 0    
         SET @nTotalSKUCounted = 0    
         SET @nTotalQtyCounted = 0    
         SET @nTotalQtyCountNo1 = 0    
         SET @nTotalQtyCountNo2 = 0    
         SET @nTotalQtyCountNo3 = 0    
    
         Select    
            @nTotalQty = SUM(SystemQty),    
            @nTotalSKUCount = Count(Distinct SKU)    
         FROM dbo.CCDetail WITH (NOLOCK)    
         WHERE CCKey = @cCCKey    
         AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
         AND   Loc = @cLoc    
         AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
         Select    
            @nTotalSKUCounted = COUNT( DISTINCT SKU),      
            @nTotalQtyCounted = CASE WHEN @cCountNo = 1 THEN ISNULL( SUM(Qty), 0)    
                                     WHEN @cCountNo = 2 THEN ISNULL( SUM(Qty_Cnt2), 0)    
                                     WHEN @cCountNo = 3 THEN ISNULL( SUM(Qty_Cnt3), 0)    
                                END    
         FROM dbo.CCDetail WITH (NOLOCK)    
         WHERE CCKey = @cCCKey    
         AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
         AND   Loc = @cLoc    
         AND ((@cCountNo = 1 AND Counted_Cnt1 = '1') OR    
              (@cCountNo = 2 AND Counted_Cnt2 = '1') OR    
              (@cCountNo = 3 AND Counted_Cnt3 = '1'))    
         AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
         Select    
            @nTotalSKUCounted = COUNT( DISTINCT SKU)    
         FROM dbo.CCDetail WITH (NOLOCK)    
         WHERE CCKey = @cCCKey    
         AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
         AND   Loc = @cLoc    
         AND ((@cCountNo = 1 AND Counted_Cnt1 = '1' AND Qty > 0) OR    
              (@cCountNo = 2 AND Counted_Cnt2 = '1' AND Qty_Cnt2 > 0) OR    
              (@cCountNo = 3 AND Counted_Cnt3 = '1' AND Qty_Cnt3 > 0))    
         AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
         SET @cOutField01 = @cCCKey    
         SET @cOutField02 = @cLoc    
         SET @cOutField03 = @cCountNo    
    
         IF @cHideScanInformation = '1'    
         BEGIN    
            SET @cOutField04 = ''    
            SET @cOutField05 = ''    
         END    
         ELSE    
         BEGIN    
            SET @cOutField04 = 'SKU:' +  CAST(@nTotalSKUCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalSKUCount AS NVARCHAR(5))    
            SET @cOutField05 = 'QTY:' +  CAST(@nTotalQtyCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalQty AS NVARCHAR(5))    
         END    
    
         SET @cOutField06 = @cCCSheetNo    
    
         -- Goto SKU , Qty Screen    
         SET @nScn = @nScn - 2    
         SET @nStep = @nStep - 2    
      END    
    
      IF ISNULL(RTRIM(@cOption), '') = '2'    
      BEGIN    
         SET @cOutField01 = @cCCKey    
         SET @cOutField02 = ''    
         SET @cOutField03 = @cCountNo    
    
         -- (ChewKP02)    
    IF @nFunc = 732    
         BEGIN    
            SET @cOutField04 = @cSuggestLoc    
         END    
         ELSE    
         BEGIN    
            SET @cOutField04 = ''    
         END    
    
         SET @cOutField06 = @cCCSheetNo    
    
         -- Goto Loc Screen    
         SET @nScn = @nScn - 3    
         SET @nStep = @nStep - 3    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @cOutField01 = @cCCKey    
      SET @cOutField02 = ''    
      SET @cOutField03 = @cCountNo    
      SET @cOutField06 = @cCCSheetNo    
    
      -- Goto Loc Screen    
      SET @nScn = @nScn - 3    
      SET @nStep = @nStep - 3    
   END    
   GOTO QUIT    
    
   Step_5_Fail:    
   BEGIN    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 6. screen = 2775    
   Loc counted recount?    
   Option (Field01, input)    
********************************************************************************/    
Step_6:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      --screen mapping    
      SET @cOption = ISNULL(RTRIM(@cInField01),'')    
    
      IF ISNULL(RTRIM(@cOption),'') = ''    
      BEGIN    
         SET @nErrNo = 72763    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_6_Fail    
      END    
    
      IF ISNULL(RTRIM(@cOption), '') <> '1' AND ISNULL(RTRIM(@cOption), '') <> '2'    
      BEGIN    
         SET @nErrNo = 72764    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_6_Fail    
      END    
    
      IF ISNULL(RTRIM(@cOption), '') = '1'    
      BEGIN    
         BEGIN TRAN    
    
         IF ISNULL(RTRIM(@cCountNo),'') = '1'    
         BEGIN    
            UPDATE dbo.CCDetail WITH (ROWLOCK)    
            SET Qty = 0    
            , EditWho = @cUserName    
            , EditDate = GetDate()    
            , Status = CASE WHEN Status = '2' THEN '0' ELSE [Status] END    
            , Counted_Cnt1 = '0'    
            WHERE CCKey = @cCCKey    
            AND   Loc = @cLoc    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
            IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 72765    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- UpdCCDet Fail    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_6_Fail    
            END    
         END    
         ELSE IF ISNULL(RTRIM(@cCountNo),'') = '2'    
         BEGIN    
            UPDATE dbo.CCDetail WITH (ROWLOCK)    
            SET Qty_Cnt2 = 0    
            , EditWho = @cUserName    
            , EditDate = GetDate()    
            , Status = CASE WHEN Status = '2' THEN '0' ELSE [Status] END    
            , Counted_Cnt2 = '0'    
            WHERE CCKey = @cCCKey    
            AND   Loc = @cLoc    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
        IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 72765    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- UpdCCDet Fail    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_6_Fail    
            END    
         END    
         ELSE IF ISNULL(RTRIM(@cCountNo),'') = '3'    
         BEGIN    
            UPDATE dbo.CCDetail WITH (ROWLOCK)    
            SET Qty_Cnt3 = 0    
            , EditWho = @cUserName    
            , EditDate = GetDate()    
            , Status = CASE WHEN Status = '2' THEN '0' ELSE [Status] END    
            , Counted_Cnt3 = '0'    
            WHERE CCKey = @cCCKey    
            AND   Loc = @cLoc    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
            IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 72765    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- UpdCCDet Fail    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_6_Fail    
            END    
         END    
    
         COMMIT TRAN    
    
         SET @cCaptureID = ''     --INC0606210      
    
         -- Capture ID    
         IF @cCaptureIDSP <> ''    
         BEGIN    
            IF @cCaptureIDSP = '1'    
               SET @cCaptureID = '1'    
             
            -- Customize capture ID    
            ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCaptureIDSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cCaptureIDSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                  ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
                  ' @cCaptureID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  ' @nMobile        INT,            ' +    
                  ' @nFunc          INT,            ' +    
                  ' @cLangCode      NVARCHAR( 3),   ' +    
                  ' @nStep          INT,            ' +    
                  ' @nInputKey      INT,            ' +    
                  ' @cFacility      NVARCHAR( 5),   ' +    
                  ' @cStorerKey     NVARCHAR( 15),  ' +    
                  ' @cCCKey         NVARCHAR( 10),  ' +    
                  ' @cCCSheetNo     NVARCHAR( 10),  ' +    
                  ' @cCountNo       NVARCHAR( 1),   ' +    
                  ' @cLOC           NVARCHAR( 10),  ' +    
                  ' @cSKU           NVARCHAR( 20),  ' +    
                  ' @nQTY           INT,            ' +    
                  ' @cOption        NVARCHAR( 1),   ' +    
                  ' @tVar           VariableTable READONLY, ' +    
                  ' @cCaptureID     NVARCHAR( 1)  OUTPUT,   ' +    
                  ' @nErrNo         INT           OUTPUT,   ' +    
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                  @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
                  @cCaptureID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
            END    
         END    
    
         IF @cCaptureID = '1'    
         BEGIN    
            SET @cOutField01 = '' -- ID    
             
            SET @nScn  = @nScn + 3    
            SET @nStep = @nStep + 3    
             
            GOTO Quit    
         END    
    
         SET @cSKUValidated = '0'    
    
         -- Disable QTY field    
         IF @cDisableQTYFieldSP <> ''    
         BEGIN    
            IF @cDisableQTYFieldSP = '1'    
               SET @cDisableQTYField = @cDisableQTYFieldSP    
            ELSE    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')    
               BEGIN    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +    
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                     ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar, ' +    
                     ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                  SET @cSQLParam =    
                     ' @nMobile           INT,            ' +    
                     ' @nFunc             INT,            ' +    
                     ' @cLangCode         NVARCHAR( 3),   ' +    
                     ' @nStep             INT,            ' +    
                     ' @nInputKey         INT,            ' +    
                     ' @cFacility         NVARCHAR( 5),   ' +    
                     ' @cStorerKey        NVARCHAR( 15),  ' +    
                     ' @cCCKey            NVARCHAR( 10),  ' +    
                     ' @cCCSheetNo        NVARCHAR( 10),  ' +    
                     ' @cCountNo          NVARCHAR( 1),   ' +    
                     ' @cLOC              NVARCHAR( 10),  ' +    
                     ' @cID               NVARCHAR( 18),  ' +    
                     ' @tVar              VariableTable READONLY, ' +    
                     ' @cDisableQTYField  NVARCHAR( 1)  OUTPUT,   ' +    
                     ' @nErrNo            INT           OUTPUT,   ' +    
                     ' @cErrMsg           NVARCHAR( 20) OUTPUT    '    
    
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                     @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar,    
                     @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
               END    
            END    
    
            SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)    
            IF @cDefaultQTY = '0'    
               SET @cDefaultQTY = ''    
    
            IF @cDisableQTYField = '1'    
               IF @cDefaultQTY = ''    
                  SET @cDefaultQTY = '1'    
         END    
    
         -- Enable / disable QTY field    (james01)         
         SET @cFieldAttr08 = 'O'       
         SET @cFieldAttr09 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY          
          
         SET @cOutField01 = @cCCKey          
         SET @cOutField02 = @cLoc          
         SET @cOutField03 = ''          
         SET @cOutField04 = ''          
         SET @cOutField05 = ''          
         SET @cOutField06 = @cCountNo          
         SET @cOutField07 = ''          
         SET @cOutField08 = ''          
         SET @cOutField09 = @cDefaultQTY         
         SET @cOutField10 = ''            
         SET @cOutField11 = ''          
         SET @cOutField12 = @cCCSheetNo -- @cExtendedInfo        
    
    
         -- Goto SKU , Qty Screen    
         SET @nScn = @nScn - 2    
         SET @nStep = @nStep - 2    
      END    
    
      IF ISNULL(RTRIM(@cOption), '') = '2'    
      BEGIN    
         -- WMS9996, Choose 2 (No), continue to scan sku without reset count    
         -- Press ESC to go back prev screen    
        SET @cCaptureID = ''     --INC0606210      
    
         -- Capture ID    
         IF @cCaptureIDSP <> ''    
         BEGIN    
            IF @cCaptureIDSP = '1'    
               SET @cCaptureID = '1'    
             
            -- Customize capture ID    
            ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCaptureIDSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cCaptureIDSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                  ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
                  ' @cCaptureID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  ' @nMobile        INT,            ' +    
                  ' @nFunc          INT,            ' +    
                  ' @cLangCode      NVARCHAR( 3),   ' +    
                  ' @nStep          INT,            ' +    
                  ' @nInputKey      INT,            ' +    
                  ' @cFacility      NVARCHAR( 5),   ' +    
                  ' @cStorerKey     NVARCHAR( 15),  ' +    
                  ' @cCCKey         NVARCHAR( 10),  ' +    
                  ' @cCCSheetNo     NVARCHAR( 10),  ' +    
                  ' @cCountNo       NVARCHAR( 1),   ' +    
                  ' @cLOC           NVARCHAR( 10),  ' +    
                  ' @cSKU           NVARCHAR( 20),  ' +    
                  ' @nQTY           INT,            ' +    
                  ' @cOption        NVARCHAR( 1),   ' +    
                  ' @tVar           VariableTable READONLY, ' +    
                  ' @cCaptureID     NVARCHAR( 1)  OUTPUT,   ' +    
                  ' @nErrNo         INT           OUTPUT,   ' +    
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                  @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
                  @cCaptureID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
            END    
         END    
    
         IF @cCaptureID = '1'    
         BEGIN    
            SET @cOutField01 = '' -- ID    
             
            SET @nScn  = @nScn + 3    
            SET @nStep = @nStep + 3    
             
            GOTO Quit    
         END    
    
         SET @cSKUValidated = '0'    
    
         -- Disable QTY field    
         IF @cDisableQTYFieldSP <> ''    
         BEGIN    
            IF @cDisableQTYFieldSP = '1'    
               SET @cDisableQTYField = @cDisableQTYFieldSP    
            ELSE    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')    
               BEGIN    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +    
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                     ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar, ' +    
                     ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                  SET @cSQLParam =    
                     ' @nMobile           INT,            ' +    
                     ' @nFunc             INT,            ' +    
                     ' @cLangCode         NVARCHAR( 3),   ' +    
                     ' @nStep             INT,            ' +    
                     ' @nInputKey         INT,            ' +    
                     ' @cFacility         NVARCHAR( 5),   ' +    
                     ' @cStorerKey        NVARCHAR( 15),  ' +    
                     ' @cCCKey            NVARCHAR( 10),  ' +    
                     ' @cCCSheetNo        NVARCHAR( 10),  ' +    
                     ' @cCountNo          NVARCHAR( 1),   ' +    
                     ' @cLOC              NVARCHAR( 10),  ' +    
                     ' @cID               NVARCHAR( 18),  ' +    
                     ' @tVar              VariableTable READONLY, ' +    
                     ' @cDisableQTYField  NVARCHAR( 1)  OUTPUT,   ' +    
                     ' @nErrNo            INT           OUTPUT,   ' +    
                     ' @cErrMsg           NVARCHAR( 20) OUTPUT    '    
    
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                     @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar,    
                     @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
               END    
            END    
    
            SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)    
            IF @cDefaultQTY = '0'    
               SET @cDefaultQTY = ''    
    
            IF @cDisableQTYField = '1'    
               IF @cDefaultQTY = ''    
                  SET @cDefaultQTY = '1'    
         END    
    
          
         -- Enable / disable QTY field    (james01)        
         SET @cFieldAttr08 = 'O'        
         SET @cFieldAttr09 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY          
          
         SET @cOutField01 = @cCCKey          
         SET @cOutField02 = @cLoc          
         SET @cOutField03 = ''          
         SET @cOutField04 = ''          
         SET @cOutField05 = ''          
         SET @cOutField06 = @cCountNo          
         SET @cOutField07 = ''          
         SET @cOutField08 = ''          
         SET @cOutField09 = @cDefaultQTY         
         SET @cOutField10 = ''            
         SET @cOutField11 = ''          
         SET @cOutField12 = @cCCSheetNo         
    
    
         -- Goto SKU , Qty Screen    
         SET @nScn = @nScn - 2    
         SET @nStep = @nStep - 2    
      END    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,            ' +    
               ' @nFunc          INT,            ' +    
               ' @cLangCode      NVARCHAR( 3),   ' +    
               ' @nStep          INT,            ' +    
               ' @nAfterStep     INT,            ' +    
               ' @nInputKey      INT,            ' +    
               ' @cFacility      NVARCHAR( 5),   ' +    
               ' @cStorerKey     NVARCHAR( 15),  ' +    
               ' @cCCKey         NVARCHAR( 10),  ' +    
               ' @cCCSheetNo     NVARCHAR( 10),  ' +    
               ' @cCountNo       NVARCHAR( 1),   ' +    
               ' @cLOC           NVARCHAR( 10),  ' +    
               ' @cSKU           NVARCHAR( 20),  ' +    
               ' @nQTY           INT,            ' +    
               ' @cOption        NVARCHAR( 1),   ' +    
               ' @tVar           VariableTable READONLY, ' +    
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cFacility, @cStorerKey,    
               @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
    
            IF @nStep = 3    
               SET @cOutField07 = @cExtendedInfo    
            IF @nStep = 4    
               SET @cOutField15 = @cExtendedInfo    
         END    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @cOutField01 = @cCCKey    
      SET @cOutField02 = @cLoc    
      SET @cOutField03 = '' -- (ChewKP01)    
      SET @cOutField06 = @cCountNo -- (ChewKP01)    
    
      IF @cHideScanInformation = '1'  
      BEGIN    
         SET @cOutField04 = ''    
         SET @cOutField05 = ''    
      END    
      ELSE    
      BEGIN    
         SET @cOutField04 = 'SKU:' +  CAST(@nTotalSKUCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalSKUCount AS NVARCHAR(5))    
         SET @cOutField05 = 'QTY:' +  CAST(@nTotalQtyCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalQty AS NVARCHAR(5))    
      END    
    
      SET @cOutField06 = @cCCSheetNo    
    
      -- Goto Loc Screen    
      SET @nScn = @nScn - 3      -- (ChewKP02)    
      SET @nStep = @nStep - 3    -- (CheWKP02)    
   END    
   GOTO QUIT    
    
   Step_6_Fail:    
   BEGIN    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 7. screen = 2776    
   SKIP LOC?    
   Option (Field01, input)    
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
         SET @nErrNo = 72763    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'    
         GOTO Quit    
      END    
    
-- Check option valid    
      IF @cOption <> '1' AND @cOption <> '2'    
      BEGIN    
         SET @nErrNo = 72764    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'    
         GOTO Quit    
      END    
    
      IF @cOption = '1' -- YES    
      BEGIN    
         SET @cCurrSuggestLogiLOC = @cSuggestLogiLOC    
         SET @cCurrSuggestLOC = @cSuggestLOC    
         SET @cCurrSuggestSKU = @cSuggestSKU    
         SET @cSuggestSKU = ''    
         SET @cSuggestLOC = ''    
    
         SET @cExtendedFetchTaskSP = ''    
         SET @cExtendedFetchTaskSP = rdt.RDTGetConfig( @nFunc, 'ExtendedFetchTaskSP', @cStorerKey)    
         IF @cExtendedFetchTaskSP NOT IN ('0', '')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedFetchTaskSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, @cCurrSuggestSKU,' +    
               ' @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile                   INT,           ' +    
               '@nFunc                     INT,           ' +    
               '@cLangCode                 NVARCHAR( 3),  ' +    
               '@nStep                     INT,           ' +    
               '@nInputKey                 INT,           ' +    
               '@cCCKey                    NVARCHAR( 10), ' +    
               '@cCCSheetNo                NVARCHAR( 10), ' +    
               '@cStorerkey                NVARCHAR( 15), ' +    
               '@cFacility                 NVARCHAR( 5),  ' +    
               '@cCurrSuggestLOC           NVARCHAR( 10), ' +    
               '@cCurrSuggestSKU           NVARCHAR( 20), ' +    
               '@cCountNo                  NVARCHAR( 1),  ' +    
               '@cUserName                 NVARCHAR( 18),        ' +    
               '@cSuggestLogiLOC           NVARCHAR( 10) OUTPUT, ' +    
               '@cSuggestLOC               NVARCHAR( 10) OUTPUT, ' +    
               '@cSuggestSKU               NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo                    INT           OUTPUT, ' +    
               '@cErrMsg                   NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, 'ZZZZZZZZZZZZZZZZZZZZ',    
                 @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
               GOTO Step_2_Fail    
            END    
         END    
         ELSE    
         BEGIN    
            EXECUTE rdt.rdt_SimpleCC_GetNextLOC    
               @cCCKey,    
               @cCCSheetNo,     
               @cStorerKey,    
               @cFacility,    
               @cSuggestLogiLOC,          -- current CCLogicalLOC    
               'ZZZZZZZZZZZZZZZZZZZZ',    -- current SKU    
               @cSuggestLogiLOC OUTPUT,    
               @cSuggestLOC     OUTPUT,    
               @cSuggestSKU     OUTPUT,    
               @cCountNo,    
               @cUserName    
         END    
    
         IF @cSuggestLoc <> ''    
         BEGIN    
            SET @cOutField04 = @cSuggestLOC    
         END    
         ELSE    
         BEGIN    
            SET @nErrNo = 72785    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoMoreCCTask'    
    
            -- Prep next screen var    
            SET @cOutField01 = CASE WHEN @cRetainCCKey = '1' THEN @cCCKey ELSE '' END      
            SET @cOutField02 = ''    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
    
            DELETE FROM rdt.rdtCCLock    
            WHERE CCKey = @cCCKey    
            AND Loc <> @cSuggestLOC    
            AND AddWho = @cUserName    
    
            SET @cCCKey = ''    
            SET @cCCSheetNo = ''    
    
            SET @nScn = @nScn - 6    
            SET @nStep = @nStep - 6    
    
            GOTO Step_7_Quit    
         END    
    
         DELETE FROM rdt.rdtCCLock    
         WHERE CCKey = @cCCKey    
         AND Loc <> @cSuggestLOC    
         AND AddWho = @cUserName    
    
         -- Insert into RDTCCLock    
         INSERT INTO RDT.RDTCCLock    
            (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,    
            Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,    
            StorerKey,  Sku,        Lot,         Loc, Id,    
            Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,    
            SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)    
         SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey, CCD.CCSheetNo,  @cCountNo,    
            '',        '',        '',         '',        '',  Loc.LocAisle, Loc.LocLevel,    
            @cStorerKey,  CCD.SKU,        CCD.LOT,         CCD.LOC,        CCD.ID,    
            CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,  CCD.Lottable04, CCD.Lottable05,    
            CCD.SystemQty,    
            CASE WHEN @cCountNo = '1' THEN CCD.Qty    
                 WHEN @cCountNo = '2' THEN CCD.Qty_Cnt2    
                 WHEN @cCountNo = '3' THEN CCD.Qty_Cnt3    
            END,    
            '3',             '',             @cUserName,     GETDATE()    
         FROM dbo.CCDETAIL CCD WITH (NOLOCK)    
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = CCD.Loc    
         WHERE CCD.CCKey = @cCCKey    
         AND ( CCD.StorerKey = '' OR CCD.StorerKey = @cStorerKey)    
         AND   CCD.Loc = @cSuggestLOC    
         AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))    
         AND   1 =   CASE    
                     WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
                     WHEN @cCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
                     WHEN @cCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
                     ELSE 1 END    
    
         IF @@ROWCOUNT = 0 -- No data in CCDetail    
         BEGIN    
            SET @nErrNo = 72786   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'    
            GOTO Quit    
         END    
      END    
   END    
    
   SET @cOutField01 = @cCCKey    
   SET @cOutField02 = '' -- LOC    
   SET @cOutField03 = @cCountNo    
    
   IF EXISTS( SELECT TOP 1 1    
      FROM dbo.CCDetail CCD (NOLOCK)    
         INNER JOIN dbo.LOC LOC (NOLOCK) ON (CCD.LOC = LOC.LOC)    
      WHERE CCD.CCKey   = @cCCKey    
      AND CCD.StorerKey = @cStorerKey    
      AND LOC.Facility  = @cFacility    
      AND LOC.LOC = @cSuggestLOC    
      AND ( (@cCountNo = '1' AND Counted_Cnt1 = 1) OR    
            (@cCountNo = '2' AND Counted_Cnt2 = 1) OR    
            (@cCountNo = '3' AND Counted_Cnt3 = 1)))    
    
      SET @cOutField05 = '[C]'    
   ELSE    
      SET @cOutField05 = ''    
    
   SET @cOutField06 = @cCCSheetNo    
    
   -- Goto LOC Screen    
   SET @nScn = @nScn - 5    
   SET @nStep = @nStep - 5    
    
Step_7_Quit:    
   -- Extended info    
   IF @cExtendedInfoSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
      BEGIN    
         SET @cExtendedInfo = ''    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
            ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
         SET @cSQLParam =    
            ' @nMobile        INT,            ' +    
            ' @nFunc          INT,            ' +    
            ' @cLangCode      NVARCHAR( 3),   ' +    
            ' @nStep          INT,            ' +    
            ' @nAfterStep     INT,            ' +    
            ' @nInputKey      INT,            ' +    
            ' @cFacility      NVARCHAR( 5),   ' +    
            ' @cStorerKey     NVARCHAR( 15),  ' +    
            ' @cCCKey         NVARCHAR( 10),  ' +    
          ' @cCCSheetNo     NVARCHAR( 10),  ' +    
            ' @cCountNo       NVARCHAR( 1),   ' +    
            ' @cLOC           NVARCHAR( 10),  ' +    
            ' @cSKU           NVARCHAR( 20),  ' +    
            ' @nQTY           INT,            ' +    
            ' @cOption        NVARCHAR( 1),   ' +    
            ' @tVar           VariableTable READONLY, ' +    
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
            ' @nErrNo         INT           OUTPUT,   ' +    
            ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, 7, @nStep, @nInputKey, @cFacility, @cStorerKey,    
            @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 8. screen = 2777    
   LOC COUNTED?    
   1 = YES    
   2 = NO    
   3 = RESET    
   Option (Field01, input)    
********************************************************************************/    
Step_8:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOption = @cInField01    
    
      -- Check blank    
      IF @cOption = ''    
      BEGIN    
         SET @nErrNo = 129001    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'    
         GOTO Quit    
      END    
    
      -- Check option valid    
      IF @cOption NOT IN ('1', '2', '3')    
      BEGIN    
         SET @nErrNo = 129002    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'    
         GOTO Quit    
      END    
    
      IF @cExtendedValidateSP <> '' AND    
         EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQty, @cOption,' +    
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
         SET @cSQLParam =    
            '@nMobile      INT,           ' +    
            '@nFunc        INT,           ' +    
            '@nStep        INT,           ' +    
            '@nInputKey    INT,           ' +    
            '@cLangCode    NVARCHAR( 3),  ' +    
            '@cStorerkey   NVARCHAR( 15), ' +    
            '@cCCKey       NVARCHAR( 10), ' +    
            '@cCCSheetNo   NVARCHAR( 10), ' +    
            '@cCountNo     NVARCHAR( 1),  ' +    
            '@cLOC         NVARCHAR( 10), ' +    
            '@cSKU         NVARCHAR( 20), ' +    
            '@nQty         INT,           ' +    
            '@cOption      NVARCHAR( 1),  ' +    
            '@nErrNo       INT           OUTPUT, ' +    
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nInQty, @cOption,    
              @nErrNo OUTPUT, @cErrMsg OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
    
      IF @cOption = '1' -- YES    
      BEGIN    
         -- When ESC, whatever CCDetail line not counted in this LOC is treated as Counted    
         -- Set qty = 0 to prevent CCSheet is populated with quantity    
         UPDATE dbo.CCDEtail WITH (ROWLOCK) SET    
           Qty      = CASE WHEN @cCountNo = '1' THEN 0 ELSE Qty  END    
         , Qty_Cnt2 = CASE WHEN @cCountNo = '2' THEN 0 ELSE Qty_Cnt2 END    
         , Qty_Cnt3 = CASE WHEN @cCountNo = '3' THEN 0 ELSE Qty_Cnt3 END    
         , Status  = '2'    
         , Counted_Cnt1 = CASE WHEN @cCountNo = '1' THEN '1' ELSE Counted_Cnt1 END    
         , Counted_Cnt2 = CASE WHEN @cCountNo = '2' THEN '1' ELSE Counted_Cnt2 END    
         , Counted_Cnt3 = CASE WHEN @cCountNo = '3' THEN '1' ELSE Counted_Cnt3 END    
         , EditWho_Cnt1 = CASE WHEN @cCountNo = '1' THEN @cUserName ELSE EditWho_Cnt1 END    
         , EditWho_Cnt2 = CASE WHEN @cCountNo = '2' THEN @cUserName ELSE EditWho_Cnt2 END    
         , EditWho_Cnt3 = CASE WHEN @cCountNo = '3' THEN @cUserName ELSE EditWho_Cnt3 END    
         , EditDate_Cnt1 = CASE WHEN @cCountNo = '1' THEN GETDATE() ELSE EditDate_Cnt1 END    
         , EditDate_Cnt2 = CASE WHEN @cCountNo = '2' THEN GETDATE() ELSE EditDate_Cnt2 END    
         , EditDate_Cnt3 = CASE WHEN @cCountNo = '3' THEN GETDATE() ELSE EditDate_Cnt3 END    
         WHERE CCKey = @cCCKey    
         AND   LOC = @cLoc    
         AND   1 = CASE    
                   WHEN @cCountNo = '1' AND Counted_Cnt1 = 0 THEN 1    
                   WHEN @cCountNo = '2' AND Counted_Cnt2 = 0 THEN 1    
                   WHEN @cCountNo = '3' AND Counted_Cnt3 = 0 THEN 1    
                   ELSE 0 END    
         AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 129003    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- UpdCCDetailFail    
            GOTO Step_4_Fail    
         END    
    
         --SOS365022 Start    
         UPDATE dbo.Loc WITH (ROWLOCK)    
        SET LastCycleCount = GetDate()    
           ,TrafficCop = NULL    
       WHERE Loc = @cLoc    
    
       IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 129004    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- UpdLocFail    
            GOTO Step_4_Fail    
         END    
         --SOS365022 End    
    
         SET @cCurrSuggestLogiLOC = @cSuggestLogiLOC    
         SET @cCurrSuggestLOC = @cSuggestLOC    
         SET @cCurrSuggestSKU = @cSuggestSKU    
         SET @cSuggestSKU = ''    
         SET @cSuggestLOC = ''    
    
         SET @cExtendedFetchTaskSP = ''    
         SET @cExtendedFetchTaskSP = rdt.RDTGetConfig( @nFunc, 'ExtendedFetchTaskSP', @cStorerKey)    
         IF @cExtendedFetchTaskSP NOT IN ('0', '')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedFetchTaskSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, @cCurrSuggestSKU,' +    
               ' @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
    
            SET @cSQLParam =    
               '@nMobile                   INT,           ' +    
               '@nFunc                     INT,           ' +    
               '@cLangCode                 NVARCHAR( 3),  ' +    
               '@nStep                     INT,           ' +    
               '@nInputKey                 INT,           ' +    
               '@cCCKey                    NVARCHAR( 10), ' +    
               '@cCCSheetNo                NVARCHAR( 10), ' +    
               '@cStorerkey                NVARCHAR( 15), ' +    
               '@cFacility                 NVARCHAR( 5),  ' +    
               '@cCurrSuggestLOC           NVARCHAR( 10), ' +    
               '@cCurrSuggestSKU           NVARCHAR( 20), ' +    
               '@cCountNo                  NVARCHAR( 1),  ' +    
               '@cUserName                 NVARCHAR( 18),        ' +    
               '@cSuggestLogiLOC           NVARCHAR( 10) OUTPUT, ' +    
               '@cSuggestLOC               NVARCHAR( 10) OUTPUT, ' +    
               '@cSuggestSKU               NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo                    INT           OUTPUT, ' +    
               '@cErrMsg                   NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCCKey, @cCCSheetNo, @cStorerKey, @cFacility, @cCurrSuggestLOC, 'ZZZZZZZZZZZZZZZZZZZZ',    
                 @cCountNo, @cUserName, @cSuggestLogiLOC OUTPUT, @cSuggestLOC OUTPUT, @cSuggestSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
               GOTO Quit    
            END    
         END    
         ELSE    
         BEGIN    
            EXECUTE rdt.rdt_SimpleCC_GetNextLOC    
               @cCCKey,    
               @cCCSheetNo,     
               @cStorerKey,    
               @cFacility,    
               @cSuggestLogiLOC,          -- current CCLogicalLOC    
               'ZZZZZZZZZZZZZZZZZZZZ',   -- current SKU    
               @cSuggestLogiLOC OUTPUT,    
               @cSuggestLOC     OUTPUT,    
               @cSuggestSKU     OUTPUT,    
               @cCountNo,    
               @cUserName    
         END    
    
         IF @cSuggestLoc <> ''    
         BEGIN    
            IF @cAutoShowNextLoc2Count = '1' -- (james08)    
            BEGIN    
               DELETE FROM rdt.rdtCCLock    
               WHERE CCKey = @cCCKey    
               AND Loc <> @cSuggestLOC    
               AND AddWho = @cUserName    
    
               -- Insert into RDTCCLock    
               INSERT INTO RDT.RDTCCLock    
                  (Mobile,    CCKey,      CCDetailKey, SheetNo,    CountNo,    
                  Zone1,      Zone2,      Zone3,       Zone4,      Zone5,      Aisle,    Level,    
                  StorerKey,  Sku,        Lot,         Loc, Id,    
                  Lottable01, Lottable02, Lottable03,  Lottable04, Lottable05,    
                  SystemQty,  CountedQty, Status,      RefNo,      AddWho,     AddDate)    
               SELECT @nMobile,   CCD.CCKey,      CCD.CCDetailKey, CCD.CCSheetNo,  @cCountNo,    
                  '',        '',        '',         '',        '',       Loc.LocAisle, Loc.LocLevel,    
                  @cStorerKey,  CCD.SKU,        CCD.LOT,         CCD.LOC,        CCD.ID,    
                  CCD.Lottable01, CCD.Lottable02, CCD.Lottable03,  CCD.Lottable04, CCD.Lottable05,    
                  CCD.SystemQty,    
                  CASE WHEN @cCountNo = '1' THEN CCD.Qty    
                       WHEN @cCountNo = '2' THEN CCD.Qty_Cnt2    
                       WHEN @cCountNo = '3' THEN CCD.Qty_Cnt3    
                  END,    
                  '3',             '',             @cUserName,     GETDATE()    
               FROM dbo.CCDETAIL CCD WITH (NOLOCK)    
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = CCD.Loc    
               WHERE CCD.CCKey = @cCCKey    
               AND ( CCD.StorerKey = '' OR CCD.StorerKey = @cStorerKey)    
               AND   CCD.Loc = @cSuggestLOC    
               AND  (( ISNULL( @cCCSheetNo, '') = '') OR ( CCD.CCSheetNo = @cCCSheetNo))    
               AND   1 =   CASE    
                           WHEN @cCountNo = 1 AND Counted_Cnt1 = 1 THEN 0    
                           WHEN @cCountNo = 2 AND Counted_Cnt2 = 1 THEN 0    
                           WHEN @cCountNo = 3 AND Counted_Cnt3 = 1 THEN 0    
                           ELSE 1 END    
    
               IF @@ROWCOUNT = 0 -- No data in CCDetail    
               BEGIN    
                  SET @nErrNo = 129005    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Blank Record'    
                  GOTO Quit    
               END    
    
               SET @cOutField01 = @cCCKey    
               SET @cOutField02 = ''    
               SET @cOutField03 = @cCountNo    
               SET @cOutField04 = @cSuggestLOC    
               SET @cOutField05 = ''    
               SET @cOutField06 = @cCCSheetNo    
            END    
            ELSE    
            BEGIN    
               SET @cSuggestLogiLOC = @cCurrSuggestLogiLOC    
               SET @cSuggestLOC = @cCurrSuggestLOC    
               SET @cSuggestSKU = @cCurrSuggestSKU    
    
               SET @cOutField01 = @cCCKey    
               SET @cOutField02 = ''    
               SET @cOutField03 = @cCountNo    
               SET @cOutField04 = @cLoc    
               SET @cOutField05 = '[C]'    
               SET @cOutField06 = @cCCSheetNo    
            END    
    
            SET @nScn = @nScn - 6    
            SET @nStep = @nStep - 6    
                
            GOTO Step_8_Quit    
         END    
         ELSE    
         BEGIN    
            -- Prep next screen var    
            SET @cOutField01 = CASE WHEN @cRetainCCKey = '1' THEN @cCCKey ELSE '' END      
            SET @cOutField02 = ''    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
    
            DELETE FROM rdt.rdtCCLock    
            WHERE CCKey = @cCCKey    
            AND Loc <> @cSuggestLOC    
            AND AddWho = @cUserName    
    
            SET @cCCKey = ''    
            SET @cCCSheetNo = ''    
    
            SET @nScn = @nScn - 7    
            SET @nStep = @nStep - 7    
                
            GOTO Step_8_Quit    
         END    
      END    
          
      IF @cOption = '3' -- RESET    
      BEGIN    
         BEGIN TRAN    
    
         IF ISNULL(RTRIM(@cCountNo),'') = '1'    
         BEGIN    
            UPDATE dbo.CCDetail WITH (ROWLOCK)    
            SET Qty = 0  
            , EditWho = @cUserName    
            , EditDate = GetDate()    
            , Status = CASE WHEN Status = '2' THEN '0' ELSE [Status] END    
            , Counted_Cnt1 = '0'    
            WHERE CCKey = @cCCKey    
            AND   Loc = @cLoc    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
            IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 129006    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- UpdCCDet Fail    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_6_Fail    
            END    
         END    
         ELSE IF ISNULL(RTRIM(@cCountNo),'') = '2'    
         BEGIN    
            UPDATE dbo.CCDetail WITH (ROWLOCK)    
            SET Qty_Cnt2 = 0    
            , EditWho = @cUserName    
            , EditDate = GetDate()    
            , Status = CASE WHEN Status = '2' THEN '0' ELSE [Status] END    
            , Counted_Cnt2 = '0'    
            WHERE CCKey = @cCCKey    
            AND   Loc = @cLoc    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
            IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 129007    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- UpdCCDet Fail    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_6_Fail    
            END    
         END    
         ELSE IF ISNULL(RTRIM(@cCountNo),'') = '3'    
         BEGIN    
            UPDATE dbo.CCDetail WITH (ROWLOCK)    
            SET Qty_Cnt3 = 0    
            , EditWho = @cUserName    
            , EditDate = GetDate()    
            , Status = CASE WHEN Status = '2' THEN '0' ELSE [Status] END    
            , Counted_Cnt3 = '0'    
            WHERE CCKey = @cCCKey    
            AND   Loc = @cLoc    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
            IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 129008    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- UpdCCDet Fail    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_6_Fail    
            END    
         END    
    
         COMMIT TRAN    
    
         SET @cSKUValidated = '0'    
    
         IF @cCaptureID = '1'    
         BEGIN    
            SET @cOutField01 = '' -- ID    
                
            -- Go to ID Screen    
            SET @nScn = @nScn + 1    
            SET @nStep = @nStep + 1    
         END    
         ELSE    
         BEGIN    
            -- Disable QTY field    
            IF @cDisableQTYFieldSP <> ''    
            BEGIN    
               IF @cDisableQTYFieldSP = '1'    
                  SET @cDisableQTYField = @cDisableQTYFieldSP    
               ELSE    
               BEGIN    
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')    
                  BEGIN    
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +    
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                        ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar, ' +    
                        ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                     SET @cSQLParam =    
                        ' @nMobile           INT,            ' +    
                        ' @nFunc             INT,            ' +    
                        ' @cLangCode         NVARCHAR( 3),   ' +    
                        ' @nStep             INT,            ' +    
                        ' @nInputKey         INT,            ' +    
                        ' @cFacility         NVARCHAR( 5),   ' +    
                        ' @cStorerKey        NVARCHAR( 15),  ' +    
                        ' @cCCKey            NVARCHAR( 10),  ' +    
                        ' @cCCSheetNo        NVARCHAR( 10),  ' +    
                        ' @cCountNo          NVARCHAR( 1),   ' +    
                        ' @cLOC              NVARCHAR( 10),  ' +    
                        ' @cID               NVARCHAR( 18),  ' +    
                        ' @tVar              VariableTable READONLY, ' +    
                        ' @cDisableQTYField  NVARCHAR( 1)  OUTPUT,   ' +    
                        ' @nErrNo            INT           OUTPUT,   ' +    
                        ' @cErrMsg           NVARCHAR( 20) OUTPUT    '    
    
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                        @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar,    
                        @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
                  END    
               END    
                   
               SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)    
               IF @cDefaultQTY = '0'    
                  SET @cDefaultQTY = ''    
    
               IF @cDisableQTYField = '1'    
                  IF @cDefaultQTY = ''    
                     SET @cDefaultQTY = '1'    
            END    
    
            -- Enable / disable QTY field    (james01)      
            SET @cFieldAttr08 ='O'          
            SET @cFieldAttr09 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY          
          
            SET @cOutField01 = @cCCKey          
            SET @cOutField02 = @cLoc          
            SET @cOutField03 = ''          
            SET @cOutField04 = ''          
            SET @cOutField05 = ''          
            SET @cOutField06 = @cCountNo          
            SET @cOutField07 = ''          
            SET @cOutField08 = ''          
            SET @cOutField09 = @cDefaultQTY          
            SET @cOutField10 =''          
            SET @cOutField11 =''          
            SET @cOutField12 = @cCCSheetNo          
            SET @cOutField13 = ''           
            SET @cOutField14 =''          
            SET @cOutField15 ='' -- ExtendedInfo     
    
            -- Goto SKU , Qty Screen    
            SET @nScn = @nScn - 4    
            SET @nStep = @nStep - 4    
         END    
             
         GOTO Step_8_Quit    
      END    
   END    
    
   IF @cCaptureID = '1'    
   BEGIN    
      SET @cOutField01 = '' -- ID    
          
      -- Go to ID Screen    
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
   END    
   ELSE    
   BEGIN    
      SET @nTotalSKUQty = 0    
      SET @nTotalQty2 = 0    
      SET @nTotalQty3 = 0    
    
      SELECT @nTotalSKUQty = Sum(Qty),    
             @nTotalQty2 = Sum(Qty_Cnt2),    
             @nTotalQty3 = Sum(Qty_Cnt3)    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE ( StorerKey = '' OR StorerKey = @cStorerKey)    
      AND   CCKey = @cCCKey    
      AND   Loc = @cLoc    
      AND   SKU = @cSKU    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
      AND (( @cCaptureID = '' AND ID = ID) OR ( @cCaptureID = '1' AND ID = @cID))    
          
      -- Disable QTY field    
      IF @cDisableQTYFieldSP <> ''    
      BEGIN    
         IF @cDisableQTYFieldSP = '1'    
            SET @cDisableQTYField = @cDisableQTYFieldSP    
         ELSE    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                  ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar, ' +    
                  ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  ' @nMobile           INT,            ' +    
                  ' @nFunc             INT,            ' +    
                  ' @cLangCode         NVARCHAR( 3),   ' +    
                  ' @nStep             INT,            ' +    
                  ' @nInputKey         INT,            ' +    
                  ' @cFacility         NVARCHAR( 5),   ' +    
                  ' @cStorerKey        NVARCHAR( 15),  ' +    
                  ' @cCCKey            NVARCHAR( 10),  ' +    
                  ' @cCCSheetNo        NVARCHAR( 10),  ' +    
                  ' @cCountNo          NVARCHAR( 1),   ' +    
                  ' @cLOC              NVARCHAR( 10),  ' +    
                  ' @cID               NVARCHAR( 18),  ' +    
                  ' @tVar              VariableTable READONLY, ' +    
                  ' @cDisableQTYField  NVARCHAR( 1)  OUTPUT,   ' +    
                  ' @nErrNo            INT           OUTPUT,   ' +    
                  ' @cErrMsg           NVARCHAR( 20) OUTPUT    '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                  @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar,    
                  @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
            END    
         END    
    
         SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)    
         IF @cDefaultQTY = '0'    
            SET @cDefaultQTY = ''    
    
         IF @cDisableQTYField = '1'    
            IF @cDefaultQTY = ''    
               SET @cDefaultQTY = '1'    
      END    
          
      SET @cOutField01 = @cCCKey    
      SET @cOutField02 = @cLoc    
      SET @cOutField03 = ''    
      SET @cOutField04 = @cSKU    
    
      SET @cSKUDesc = ''    
    
      SELECT @cSKUDesc = DESCR    
      FROM dbo.SKU WITH (NOLOCK)    
      WHERE SKU = @cSKU    
      AND Storerkey = @cStorerkey    
    
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1    
      SET @cOutField06 = @cCountNo    
      SET @cOutField07 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2    
      SET @cOutField08 = ''          
      SET @cOutField09 = @cDefaultQTY         
      
      IF @cCountNo = '1' SET @cOutField10 = CAST( @nTotalSKUQty AS NVARCHAR(5)) ELSE          
      IF @cCountNo = '2' SET @cOutField10 = CAST( @nTotalQty2   AS NVARCHAR(5)) ELSE          
      IF @cCountNo = '3' SET @cOutField10 = CAST( @nTotalQty3   AS NVARCHAR(5))          
          
      SET @cOutField11 = ''          
      SET @cOutField12 = @cCCSheetNo     
    
      -- Enable / disable QTY field    (james01)        
      SET @cFieldAttr08 = 'O'        
      SET @cFieldAttr09 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY     
    
      EXEC rdt.rdtSetFocusField @nMobile, 3    
    
      -- Goto SKU Screen    
      SET @nScn = @nScn - 4    
      SET @nStep = @nStep - 4    
   END    
       
Step_8_Quit:    
   -- Extended info    
   IF @cExtendedInfoSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
      BEGIN    
         SET @cExtendedInfo = ''    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
          ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
            ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
         SET @cSQLParam =    
            ' @nMobile        INT,            ' +    
       ' @nFunc          INT,            ' +    
            ' @cLangCode      NVARCHAR( 3),   ' +    
            ' @nStep          INT,            ' +    
            ' @nAfterStep     INT,            ' +    
            ' @nInputKey      INT,            ' +    
            ' @cFacility      NVARCHAR( 5),   ' +    
            ' @cStorerKey     NVARCHAR( 15),  ' +    
            ' @cCCKey         NVARCHAR( 10),  ' +    
            ' @cCCSheetNo     NVARCHAR( 10),  ' +    
            ' @cCountNo       NVARCHAR( 1),   ' +    
            ' @cLOC           NVARCHAR( 10),  ' +    
            ' @cSKU           NVARCHAR( 20),  ' +    
            ' @nQTY           INT,            ' +    
            ' @cOption        NVARCHAR( 1),   ' +    
            ' @tVar           VariableTable READONLY, ' +    
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
            ' @nErrNo         INT           OUTPUT,   ' +    
            ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, 8, @nStep, @nInputKey, @cFacility, @cStorerKey,    
            @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 9. screen = 2778    
   ID (Field01, input)    
********************************************************************************/    
Step_9:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cID = @cInField01    
    
      -- Check format    
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0    
      BEGIN    
         SET @nErrNo = 129009    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
         GOTO Quit    
      END    
    
      -- Screen mapping    
      SET @bIDCounted = 0    
    
      IF ISNULL( @cID, '') <> ''    
      BEGIN    
         IF @nFunc = 731    
         BEGIN    
            IF EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                WHERE Counted_Cnt1 <> '0'    
                AND   CCKey = @cCCKey    
                AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                AND   Loc = @cLoc    
                AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
                AND (( ISNULL( @cID, '') = '') OR ( ID = @cID))    
                AND (( @cCountNo = '1' AND Counted_Cnt1 <> '0') OR     
                    (  @cCountNo = '2' AND Counted_Cnt2 <> '0') OR    
                    (  @cCountNo = '3' AND Counted_Cnt3 <> '0')))    
            BEGIN    
               IF @nFunc = 731    
                  SET @bIDCounted = 1    
               IF @nFunc = 732 AND @nFromStep <> 4    
                  SET @bIDCounted = 1    
            END    
         END    
      END    
    
      IF @bIDCounted = 1    
      BEGIN    
         SET @cResetID = ''    
         SET @cResetID = rdt.RDTGetConfig( @nFunc, 'SimpleCCResetID', @cStorerkey)    
    
         IF ISNULL(RTRIM(@cResetID),'') = '' OR ISNULL(RTRIM(@cResetID),'') = '0'    
         BEGIN    
             SET @nErrNo = 129010    
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- ID Counted    
             GOTO Quit    
      END    
         ELSE    
         BEGIN    
            IF NOT EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)    
                        WHERE CCKey = @cCCKey    
                        AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
                        AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
                        AND   FinalizeFlag = 'N'    
                        AND (( @cCountNo = '1' AND FinalizeFlag = 'N') OR     
                             ( @cCountNo = '2' AND FinalizeFlag_Cnt2 = 'N') OR    
                             ( @cCountNo = '3' AND FinalizeFlag_Cnt3 = 'N')))    
            BEGIN    
                  SET @nErrNo = 129011    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Count Finalized'    
                  GOTO Quit    
            END    
    
    
            --GOTO RESET ID Screen    
            SET @cOutField01 = ''    
    
            SET @nScn = @nScn + 1    
            SET @nStep = @nStep + 1    
    
            GOTO Quit    
         END    
      END    
    
      -- Disable QTY field    
      IF @cDisableQTYFieldSP <> ''    
      BEGIN    
    IF @cDisableQTYFieldSP = '1'    
            SET @cDisableQTYField = @cDisableQTYFieldSP    
         ELSE    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                  ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar, ' +    
                  ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  ' @nMobile           INT,            ' +    
                  ' @nFunc             INT,            ' +    
                  ' @cLangCode         NVARCHAR( 3),   ' +    
                  ' @nStep             INT,            ' +    
                  ' @nInputKey         INT,            ' +    
                  ' @cFacility         NVARCHAR( 5),   ' +    
                  ' @cStorerKey        NVARCHAR( 15),  ' +    
                  ' @cCCKey            NVARCHAR( 10),  ' +    
                  ' @cCCSheetNo        NVARCHAR( 10),  ' +    
                  ' @cCountNo          NVARCHAR( 1),   ' +    
                  ' @cLOC              NVARCHAR( 10),  ' +    
                  ' @cID               NVARCHAR( 18),  ' +    
                  ' @tVar              VariableTable READONLY, ' +    
                  ' @cDisableQTYField  NVARCHAR( 1)  OUTPUT,   ' +    
                  ' @nErrNo            INT           OUTPUT,   ' +    
                  ' @cErrMsg           NVARCHAR( 20) OUTPUT    '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                  @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar,    
                  @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
            END    
         END    
    
         SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)    
         IF @cDefaultQTY = '0'    
            SET @cDefaultQTY = ''    
    
         IF @cDisableQTYField = '1'    
            IF @cDefaultQTY = ''    
               SET @cDefaultQTY = '1'    
      END    
    
      -- Enable / disable QTY field    (james01)    
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY    
    
      SET @cSKUValidated = '0'    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
           INSERT INTO @tVar (Variable, Value) VALUES     
            ('@cID',       @cID)    
    
            SET @cExtendedInfo = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,            ' +    
               ' @nFunc          INT,            ' +    
               ' @cLangCode      NVARCHAR( 3),   ' +    
               ' @nStep          INT,            ' +    
               ' @nAfterStep     INT,            ' +    
               ' @nInputKey      INT,            ' +    
               ' @cFacility      NVARCHAR( 5),   ' +    
               ' @cStorerKey     NVARCHAR( 15),  ' +    
               ' @cCCKey         NVARCHAR( 10),  ' +    
               ' @cCCSheetNo     NVARCHAR( 10),  ' +    
               ' @cCountNo       NVARCHAR( 1),   ' +    
               ' @cLOC           NVARCHAR( 10),  ' +    
               ' @cSKU           NVARCHAR( 20),  ' +    
               ' @nQTY           INT,            ' +    
               ' @cOption        NVARCHAR( 1),   ' +    
               ' @tVar           VariableTable READONLY, ' +    
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,    
               @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
    
            SET @cOutField15 = @cExtendedInfo    
         END    
      END    
    
      -- Prepare Next Screen Var          
      SET @cOutField01 = @cCCKey          
      SET @cOutField02 = @cLoc          
      SET @cOutField03 = ''          
      SET @cOutField04 = ''          
      SET @cOutField05 = ''          
      SET @cOutField06 = @cCountNo          
      SET @cOutField07 = ''          
      SET @cOutField08 = ''          
      SET @cOutField09 = @cDefaultQTY         
      SET @cOutField10 = ''         
      SET @cOutField11 = ''          
      SET @cOutField12 = @cCCSheetNo       
    
      SET @nScn = @nScn - 5    
      SET @nStep = @nStep - 5    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      IF @cConfirmLOCCounted > '0'    
      BEGIN    
         SET @nVariance = 0    
             
         -- Check variance    
         IF @cCountNo = '1'    
            SELECT TOP 1    
               @nVariance = 1    
            FROM dbo.CCDEtail WITH (NOLOCK)    
            WHERE CCKey = @cCCKey    
               AND   LOC = @cLoc    
               AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            GROUP BY StorerKey, SKU    
            HAVING SUM( SystemQTY) <> SUM( QTY)    
    
         ELSE IF @cCountNo = '2'    
            SELECT TOP 1    
               @nVariance = 1    
            FROM dbo.CCDEtail WITH (NOLOCK)    
            WHERE CCKey = @cCCKey    
               AND   LOC = @cLoc    
               AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            GROUP BY StorerKey, SKU    
            HAVING SUM( SystemQTY) <> SUM( QTY_Cnt2)    
    
         ELSE IF @cCountNo = '3'    
            SELECT TOP 1    
               @nVariance = 1    
            FROM dbo.CCDEtail WITH (NOLOCK)    
            WHERE CCKey = @cCCKey    
               AND   LOC = @cLoc    
               AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            GROUP BY StorerKey, SKU    
            HAVING SUM( SystemQTY) <> SUM( QTY_Cnt3)    
    
         -- Variance found    
         -- Or config turn on with svalue = 2 (always go to confirm loc screen)
         IF @nVariance = 1 OR @cConfirmLOCCounted = '2'   
         BEGIN    
            SET @cOutField01 = '' -- Option    
                
            -- Go to confirm LOC counted screen    
            SET @nScn = @nScn - 1    
            SET @nStep = @nStep - 1             
                
            GOTO Quit    
         END    
      END          
          
      SET @nTotalSKUCount = 0    
      SET @nTotalQty = 0    
      SET @nTotalSKUCounted = 0    
      SET @nTotalQtyCounted = 0    
    
      Select    
         @nTotalQty = SUM(SystemQty),    
         @nTotalSKUCount = Count(Distinct SKU)    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE CCKey = @cCCKey    
      AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
AND   Loc = @cLoc    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
      Select    
         @nTotalSKUCounted = COUNT( DISTINCT SKU),      
         @nTotalQtyCounted = CASE WHEN @cCountNo = 1 THEN ISNULL( SUM(Qty), 0)    
                                  WHEN @cCountNo = 2 THEN ISNULL( SUM(Qty_Cnt2), 0)    
                                  WHEN @cCountNo = 3 THEN ISNULL( SUM(Qty_Cnt3), 0)    
                             END    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE CCKey = @cCCKey    
      AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
      AND   Loc = @cLoc    
      AND ((@cCountNo = 1 AND Counted_Cnt1 = '1') OR    
           (@cCountNo = 2 AND Counted_Cnt2 = '1') OR    
           (@cCountNo = 3 AND Counted_Cnt3 = '1'))    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
      Select    
         @nTotalSKUCounted = COUNT( DISTINCT SKU)    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE CCKey = @cCCKey    
      AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
      AND   Loc = @cLoc    
      AND ((@cCountNo = 1 AND Counted_Cnt1 = '1' AND Qty > 0) OR    
            (@cCountNo = 2 AND Counted_Cnt2 = '1' AND Qty_Cnt2 > 0) OR    
            (@cCountNo = 3 AND Counted_Cnt3 = '1' AND Qty_Cnt3 > 0))    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
    
      SET @cOutField01 = @cCCKey    
      SET @cOutField02 = @cLoc    
      SET @cOutField03 = @cCountNo    
    
      IF @cHideScanInformation = '1'    
      BEGIN    
         SET @cOutField04 = ''    
         SET @cOutField05 = ''    
      END    
      ELSE    
      BEGIN    
         SET @cOutField04 = CAST(@nTotalSKUCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalSKUCount AS NVARCHAR(5))    
         SET @cOutField05 = CAST(@nTotalQtyCounted AS NVARCHAR(5)) + '/' + CAST (@nTotalQty AS NVARCHAR(5))    
      END    
    
      SET @cOutField06 = @cCCSheetNo    
      SET @cOutField07 = '' -- ExtendedInfo    
    
      -- Goto statistic Screen    
      SET @nScn = @nScn - 6    
      SET @nStep = @nStep - 6    
   END    
    
Step_9_Quit:    
   -- Extended info    
   IF @cExtendedInfoSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
      BEGIN    
         SET @cExtendedInfo = ''    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
            ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
         SET @cSQLParam =    
            ' @nMobile        INT,            ' +    
            ' @nFunc          INT,            ' +    
            ' @cLangCode      NVARCHAR( 3),   ' +    
            ' @nStep          INT,            ' +    
            ' @nAfterStep     INT,            ' +    
            ' @nInputKey      INT,            ' +    
            ' @cFacility      NVARCHAR( 5),   ' +    
            ' @cStorerKey     NVARCHAR( 15),  ' +    
            ' @cCCKey         NVARCHAR( 10),  ' +    
            ' @cCCSheetNo     NVARCHAR( 10),  ' +    
            ' @cCountNo       NVARCHAR( 1),   ' +    
            ' @cLOC           NVARCHAR( 10),  ' +    
            ' @cSKU           NVARCHAR( 20),  ' +    
            ' @nQTY           INT,            ' +    
            ' @cOption        NVARCHAR( 1),   ' +    
            ' @tVar           VariableTable READONLY, ' +    
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
            ' @nErrNo         INT           OUTPUT,   ' +    
            ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, 9, @nStep, @nInputKey, @cFacility, @cStorerKey,    
            @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 10. screen = 2779    
   ID counted recount?    
   Option (Field01, input)    
********************************************************************************/    
Step_10:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      --screen mapping    
      SET @cOption = ISNULL(RTRIM(@cInField01),'')    
    
      IF ISNULL(RTRIM(@cOption),'') = ''    
      BEGIN    
         SET @nErrNo = 129012    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_10_Fail    
      END    
    
      IF ISNULL(RTRIM(@cOption), '') <> '1' AND ISNULL(RTRIM(@cOption), '') <> '2'    
      BEGIN    
         SET @nErrNo = 129013    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_10_Fail    
      END    
    
      IF ISNULL(RTRIM(@cOption), '') = '1'    
      BEGIN    
         BEGIN TRAN    
    
         IF ISNULL(RTRIM(@cCountNo),'') = '1'    
         BEGIN    
            UPDATE dbo.CCDetail WITH (ROWLOCK)    
            SET Qty = 0    
            , EditWho = @cUserName    
            , EditDate = GetDate()    
            , Status = CASE WHEN Status = '2' THEN '0' ELSE [Status] END    
            , Counted_Cnt1 = '0'    
            WHERE CCKey = @cCCKey    
            AND   Loc = @cLoc    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            AND   ID = @cID    
    
            IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 129014    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- UpdCCDet Fail    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_10_Fail    
            END    
         END    
         ELSE IF ISNULL(RTRIM(@cCountNo),'') = '2'    
         BEGIN    
            UPDATE dbo.CCDetail WITH (ROWLOCK)    
            SET Qty_Cnt2 = 0    
            , EditWho = @cUserName    
            , EditDate = GetDate()    
            , Status = CASE WHEN Status = '2' THEN '0' ELSE [Status] END    
            , Counted_Cnt2 = '0'    
            WHERE CCKey = @cCCKey    
            AND   Loc = @cLoc    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)   
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            AND   ID = @cID    
    
            IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 129015    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- UpdCCDet Fail    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_10_Fail    
            END    
         END    
         ELSE IF ISNULL(RTRIM(@cCountNo),'') = '3'    
         BEGIN    
            UPDATE dbo.CCDetail WITH (ROWLOCK)    
            SET Qty_Cnt3 = 0    
            , EditWho = @cUserName    
            , EditDate = GetDate()    
            , Status = CASE WHEN Status = '2' THEN '0' ELSE [Status] END    
            , Counted_Cnt3 = '0'    
            WHERE CCKey = @cCCKey    
            AND   Loc = @cLoc    
            AND ( StorerKey = '' OR StorerKey = @cStorerKey)    
            AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
            AND   ID = @cID    
    
            IF @@ERROR<>0    
            BEGIN    
               ROLLBACK TRAN    
               SET @nErrNo = 129016    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') -- UpdCCDet Fail    
               EXEC rdt.rdtSetFocusField @nMobile, 1    
               GOTO Step_10_Fail    
            END    
         END    
    
         COMMIT TRAN    
    
         SET @cSKUValidated = '0'    
    
         -- Disable QTY field    
         IF @cDisableQTYFieldSP <> ''    
         BEGIN    
            IF @cDisableQTYFieldSP = '1'    
               SET @cDisableQTYField = @cDisableQTYFieldSP    
            ELSE    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')    
               BEGIN    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +    
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                     ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar, ' +    
                     ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                  SET @cSQLParam =    
                     ' @nMobile           INT,            ' +    
                     ' @nFunc             INT,            ' +    
                     ' @cLangCode         NVARCHAR( 3),   ' +    
                     ' @nStep             INT,            ' +    
                     ' @nInputKey         INT,            ' +    
                     ' @cFacility         NVARCHAR( 5),   ' +    
                     ' @cStorerKey        NVARCHAR( 15),  ' +    
                     ' @cCCKey            NVARCHAR( 10),  ' +    
                  ' @cCCSheetNo        NVARCHAR( 10),  ' +    
                     ' @cCountNo          NVARCHAR( 1),   ' +    
                     ' @cLOC              NVARCHAR( 10),  ' +    
                     ' @cID               NVARCHAR( 18),  ' +    
                     ' @tVar              VariableTable READONLY, ' +    
                     ' @cDisableQTYField  NVARCHAR( 1)  OUTPUT,   ' +    
                     ' @nErrNo            INT           OUTPUT,   ' +    
                     ' @cErrMsg           NVARCHAR( 20) OUTPUT    '    
    
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                     @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar,    
                     @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
               END    
            END    
    
            SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)    
            IF @cDefaultQTY = '0'    
               SET @cDefaultQTY = ''    
    
            IF @cDisableQTYField = '1'    
               IF @cDefaultQTY = ''    
                  SET @cDefaultQTY = '1'    
         END    
    
         -- Extended info    
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               INSERT INTO @tVar (Variable, Value) VALUES     
               ('@cID',       @cID)    
    
               SET @cExtendedInfo = ''    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                  ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar, ' +    
                  ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  ' @nMobile        INT,            ' +    
                  ' @nFunc          INT,            ' +    
                  ' @cLangCode      NVARCHAR( 3),   ' +    
                  ' @nStep          INT,            ' +    
                  ' @nAfterStep     INT,            ' +    
                  ' @nInputKey      INT,            ' +    
                  ' @cFacility      NVARCHAR( 5),   ' +    
                  ' @cStorerKey     NVARCHAR( 15),  ' +    
                  ' @cCCKey         NVARCHAR( 10),  ' +    
                  ' @cCCSheetNo     NVARCHAR( 10),  ' +    
   ' @cCountNo       NVARCHAR( 1),   ' +    
                  ' @cLOC           NVARCHAR( 10),  ' +    
                  ' @cSKU           NVARCHAR( 20),  ' +    
                  ' @nQTY           INT,            ' +    
                  ' @cOption        NVARCHAR( 1),   ' +    
                  ' @tVar           VariableTable READONLY, ' +    
                  ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +    
                  ' @nErrNo         INT           OUTPUT,   ' +    
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                  @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cSKU, @nQTY, @cOption, @tVar,    
                  @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
                  GOTO Quit    
    
               SET @cOutField15 = @cExtendedInfo    
            END    
         END    
         
         -- Enable / disable QTY field    (james01)        
         SET @cFieldAttr08 = 'O'        
         SET @cFieldAttr09 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY       
          
         -- Prepare Next Screen Var          
         SET @cOutField01 = @cCCKey          
         SET @cOutField02 = @cLoc          
         SET @cOutField03 = ''          
         SET @cOutField04 = ''          
         SET @cOutField05 = ''          
         SET @cOutField06 = @cCountNo          
         SET @cOutField07 = ''          
         SET @cOutField08 = ''          
         SET @cOutField09 = @cDefaultQTY          
         SET @cOutField10 =''          
         SET @cOutField11 =''          
         SET @cOutField12 = @cCCSheetNo          
         SET @cOutField13 = ''           
         SET @cOutField14 =''          
         SET @cOutField15 ='' -- ExtendedInfo       
    
    
         -- Goto SKU , Qty Screen    
         SET @nScn = @nScn - 6    
         SET @nStep = @nStep - 6    
      END    
    
      IF ISNULL(RTRIM(@cOption), '') = '2'    
      BEGIN    
         SET @cOutField01 = '' -- ID    
    
         -- Goto ID Screen    
         SET @nScn = @nScn - 1    
         SET @nStep = @nStep - 1    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @cOutField01 = '' -- ID    
    
      -- Goto ID Screen    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO QUIT    
    
   Step_10_Fail:    
   BEGIN    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    

/********************************************************************************  
Step 13. Screen = 3570. Multi SKU  
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
  
      SELECT  
         @cSKUDesc = IsNULL( DescR, ''),  
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
      JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
      WHERE SKU.StorerKey = @cStorerKey  
      AND   SKU.SKU = @cSKU  
  
      -- Convert to prefer UOM QTY  
      IF @cPUOM = '6' OR -- When preferred UOM = master unit  
         @nPUOM_Div = 0  -- UOM not setup  
      BEGIN  
         SET @cPUOM_Desc = ''  
         SET @nPQTY = 0  
         SET @nMQTY = @nQTY  
         SET @cFieldAttr08 = 'O' -- @nPQTY  
      END  
      ELSE  
      BEGIN  
         SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM  
         SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit  
         SET @cFieldAttr08 = '' -- @nPQTY  
      END  
    
      SELECT @nTotalSKUQty = Sum(Qty),    
         @nTotalQty2 = Sum(Qty_Cnt2),    
         @nTotalQty3 = Sum(Qty_Cnt3)    
      FROM dbo.CCDetail WITH (NOLOCK)    
      WHERE ( StorerKey = '' OR StorerKey = @cStorerKey)    
      AND   CCKey = @cCCKey    
      AND   Loc = @cLoc    
      AND   SKU = @cSKU    
      AND (( ISNULL( @cCCSheetNo, '') = '') OR ( CCSheetNo = @cCCSheetNo))    
      AND (( @cCaptureID = '' AND ID = ID) OR ( @cCaptureID = '1' AND ID = @cID)) 

      SET @cOutField08 = CASE WHEN @cDefaultQTY NOT IN ('', '0') THEN @cDefaultQTY ELSE '' END    
    
      -- Enable / disable QTY field    (james01)    
      SET @cFieldAttr08 =  'O'   
      SET @cFieldAttr09 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY 
  
  
      -- Disable QTY field  
      IF @cDisableQTYFieldSP <> ''  
      BEGIN  
         IF @cDisableQTYFieldSP = '1'  
         SET @cDisableQTYField = @cDisableQTYFieldSP  
         ELSE  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
                  ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar, ' +  
                  ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
               SET @cSQLParam =  
                  ' @nMobile           INT,            ' +  
                  ' @nFunc             INT,            ' +  
                  ' @cLangCode         NVARCHAR( 3),   ' +  
                  ' @nStep             INT,            ' +  
                  ' @nInputKey         INT,            ' +  
                  ' @cFacility         NVARCHAR( 5),   ' +  
                  ' @cStorerKey        NVARCHAR( 15),  ' +  
                  ' @cCCKey            NVARCHAR( 10),  ' +  
                  ' @cCCSheetNo        NVARCHAR( 10),  ' +  
                  ' @cCountNo          NVARCHAR( 1),   ' +  
                  ' @cLOC              NVARCHAR( 10),  ' +  
                  ' @cID               NVARCHAR( 18),  ' +  
                  ' @tVar              VariableTable READONLY, ' +  
                  ' @cDisableQTYField  NVARCHAR( 1)  OUTPUT,   ' +  
                  ' @nErrNo            INT           OUTPUT,   ' +  
                  ' @cErrMsg           NVARCHAR( 20) OUTPUT    '  
  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
                  @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar,  
                  @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
            END  
         END  
  
         SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)  
         IF @cDefaultQTY = '0'  
            SET @cDefaultQTY = ''  
  
         IF @cDisableQTYField = '1'  
            IF @cDefaultQTY = ''  
               SET @cDefaultQTY = '1'  
      END  
  
      -- Enable / disable QTY field    (james01)  
      SET @cFieldAttr13 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY  
 
      -- Prepare Next Screen Var  
      SET @cOutField01 = @cCCKey  
      SET @cOutField02 = @cLoc  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = @cSKU
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = SUBSTRING(@cSKUDesc,21,40)
      SET @cOutField09 = @cDefaultQTY    

      IF @cCountNo = '1' SET @cOutField10 = CAST( @nTotalSKUQty AS NVARCHAR(5)) ELSE    
      IF @cCountNo = '2' SET @cOutField10 = CAST( @nTotalQty2   AS NVARCHAR(5)) ELSE    
      IF @cCountNo = '3' SET @cOutField10 = CAST( @nTotalQty3   AS NVARCHAR(5))   
        
      SET @cOutField11 = ''  
      SET @cOutField12 = '' -- ExtendedInfo  
  
      -- Set Focus on Field01  
      EXEC rdt.rdtSetFocusField @nMobile, 3  
  
      -- Go to SKU QTY screen  
      SET @nScn = @nFromScn  
      SET @nStep = @nStep - 7
   END

   IF @nInputKey=0
   BEGIN
       -- Disable QTY field    
      IF @cDisableQTYFieldSP <> ''  
      BEGIN    
         IF @cDisableQTYFieldSP = '1'    
            SET @cDisableQTYField = @cDisableQTYFieldSP    
         ELSE    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
                  ' @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar, ' +    
                  ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  ' @nMobile           INT,            ' +    
                  ' @nFunc             INT,            ' +    
                  ' @cLangCode         NVARCHAR( 3),   ' +    
                  ' @nStep             INT,            ' +    
                  ' @nInputKey         INT,            ' +    
                  ' @cFacility         NVARCHAR( 5),   ' +    
                  ' @cStorerKey        NVARCHAR( 15),  ' +    
                  ' @cCCKey            NVARCHAR( 10),  ' +    
                  ' @cCCSheetNo        NVARCHAR( 10),  ' +    
                  ' @cCountNo          NVARCHAR( 1),   ' +    
                  ' @cLOC              NVARCHAR( 10),  ' +    
                  ' @cID               NVARCHAR( 18),  ' +    
                  ' @tVar              VariableTable READONLY, ' +    
                  ' @cDisableQTYField  NVARCHAR( 1)  OUTPUT,   ' +    
                  ' @nErrNo            INT           OUTPUT,   ' +    
                  ' @cErrMsg           NVARCHAR( 20) OUTPUT    '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,    
                  @cCCKey, @cCCSheetNo, @cCountNo, @cLOC, @cID, @tVar,    
                  @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
            END    
         END    
    
         SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'SimpleCCDefaultQTY', @cStorerkey)    
         IF @cDefaultQTY = '0'    
            SET @cDefaultQTY = ''    
    
         IF @cDisableQTYField = '1'    
            IF @cDefaultQTY = ''    
               SET @cDefaultQTY = '1'    
      END    
    
      -- Enable / disable QTY field    (james01)    
      SET @cFieldAttr08 = 'o'    
      SET @cFieldAttr09= CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END --QTY    
    
      SET @cSKUValidated = '0'     
    
      -- Prepare Next Screen Var    
      SET @cOutField01 = @cCCKey    
      SET @cOutField02 = @cLoc    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
      SET @cOutField06 = @cCountNo    
      SET @cOutField07 = ''    
      SET @cOutField08 = ''    
      SET @cOutField09 = @cDefaultQTY    
      SET @cOutField10 =''    
      SET @cOutField11 =''    
      SET @cOutField12 = @cCCSheetNo    
      SET @cOutField13 = ''     
      SET @cOutField14 =''    
      SET @cOutField15 ='' -- ExtendedInfo    
    
      -- Set Focus on Field01    
      EXEC rdt.rdtSetFocusField @nMobile, 3    
    
      -- Go to SKU QTY screen  
      SET @nScn = @nFromScn  
      SET @nStep = @nStep - 7
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
      Facility  = @cFacility,    
      Printer       = @cPrinter,    
      Printer_Paper = @cPrinter_Paper,    
    
      V_SKU         = @cSKU,    
      V_Loc         = @cLoc,    
      V_ID          = @cID,    
    
      V_Integer1  = @nTotalSKUCounted,    
      V_Integer2  = @nTotalSKUCount,    
      V_Integer3  = @nTotalQtyCounted,    
      V_Integer4  = @nTotalQty,    
      V_Integer5  = @nPQTY,         
      V_Integer6  = @nMQTY,         
      V_Integer7  = @nPUOM_Div,     
          
      V_FromScn   = @nFromScn,    
      V_FromStep  = @nFromStep,    
    
      V_String1     = @cCCKey,    
      V_String2     = @cCountNo,    
      V_String3     = @cSKUStatus,     
      V_String7     = @cDefaultQTY ,    
      V_String8     = @cSuggestSKU ,    
      V_String11    = @cSuggestLogiLOC,    
      V_String12    = @cSuggestLOC,    
      V_String13    = @cHideScanInformation,    
      V_String14    = @cDisableQTYField, -- (james01)    
    
      V_String15    = @cNotAllowSkipSuggestLOC, -- (james02)    
      V_String16    = @cToLOCLookupSP,          -- (ChewKP03)    
      V_String17    = @cCCSheetNo, -- (james04)    
      V_String18    = @cAutoShowNextLoc2Count,    
      V_String19    = @cSKUValidated, -- (james09)    
      V_String20    = @cExtendedUpdateSP, -- (james09)    
      V_String21    = @cExtendedValidateSP, -- (james09)    
      V_String22    = @cConfirmSkipLOC,    
      V_String23    = @cExtendedInfoSP,    
      V_String24    = @cConfirmLOCCounted,    
      V_String25    = @cCaptureIDSP,    
      V_String26    = @cCaptureID,    
      V_String27    = @cDisableQTYFieldSP,       
      V_String28    = @cRetainCCKey, -- (james10)    
      V_String29    = @cMUOM ,        
      V_String30    = @cMUOM_Desc,    
      V_String31    = @cPUOM_Desc,    
      V_String32    = @cMultiSKUBarcode,

      V_Lottable01  = @cLottable01,    
      V_Lottable02  = @cLottable02,    
      V_Lottable03  = @cLottable03,    
      V_Lottable04  = @dLottable04,    
      V_Lottable05  = @dLottable05,    
      V_Lottable06  = @cLottable06,    
      V_Lottable07  = @cLottable07,    
      V_Lottable08  = @cLottable08,    
      V_Lottable09  = @cLottable09,    
      V_Lottable10  = @cLottable10,    
      V_Lottable11  = @cLottable11,    
      V_Lottable12  = @cLottable12,    
      V_Lottable13  = @dLottable13,    
      V_Lottable14  = @dLottable14,    
      V_Lottable15  = @dLottable15,    
      V_Max         = @cMax,    
    
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