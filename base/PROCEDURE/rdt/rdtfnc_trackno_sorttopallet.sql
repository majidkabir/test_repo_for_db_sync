SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtfnc_TrackNo_SortToPallet                         */  
/* Copyright      : MAERSK                                              */  
/*                                                                      */  
/* Purpose: Sort trackno to pallet                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Rev  Author   Purposes                                  */  
/* 2020-08-0`   1.0  James    WMS-14248. Created                        */  
/* 2021-07-09   1.1  James    WMS17425-Add check pallet format (james01)*/  
/*                            Add check 1 mbol 1 pallet(externmbolkey)  */  
/* 2021-08-12   1.2  James    WMS-17486. Add retrieve orderkey (james02)*/  
/*                            Extend TrackNo to 40 chars                */  
/* 2021-10-21   1.3  James    WMS-18222 Add config to prevent user scan */  
/*                            diff shipperkey onto same pallet (james03)*/  
/* 2021-11-18   1.4  James    WMS-18350 Add ExtendedInfoSP to step      */  
/*                            scan/show pallet key (james04)            */  
/* 2021-11-24   1.5  James    WMS-18315 Add palletkey format check      */  
/*                            to trackno and close pallet scn (james05) */  
/* 2022-01-03   1.6  James    WMS-18616 Fix SKU null error when insert  */  
/*                            palletdetail record (james06)             */  
/* 2022-02-07   1.7  LZG      JSM-49257 - Cleared @cLabelNo value after */  
/*                            error to fix no error shown bug (ZG01)    */  
/* 2022-02-28   1.8  James    WMS-18350 Add ExtendedUpdateSP to step    */  
/*                            scan trackno pallet key (james07)         */  
/* 2022-04-12   1.9  James    WMS-19218 Add new screen to allow scan to */  
/*                            different pallet id screen (james08)      */  
/* 2022-04-28   2.0  James    WMS-18616 Extend the length of barcode    */  
/*                            to 100 chars (james07)                    */  
/* 2022-08-15   2.1  James    WMS-20033 Add check pallet closed(james08)*/  
/* 2022-08-18   2.2  James    WMS-20561 Chk order status before close   */  
/*                            pallet (james09)                          */  
/* 2022-09-15   2.3  James    WMS-20667 Add Lane (james10)              */  
/*                            Add confirm scan new lane screen          */  
/* 2023-03-28   2.4  James    WMS-21868 Exclude certain order type from */    
/*                            split lane check (james11)                */  
/* 2023-08-23   2.5  James    WMS-23471 Add validate lane (james12)     */  
/* 2023-11-01   2.6  WyeChun  JSM-187801 Add validation from Step2 to   */  
/*                            Step5 (WC01)                              */  
/* 2023-11-14   2.7  James    WMS-23712 Extend Lane var length (james13)*/
/* 2024-04-23   2.8  JihHaur  Add storerkey filter (JH01)               */
/* 2024-07-09   2.8  CYU027   FCR-539 Granite Scan to Pallet            */
/* 2024-09-20   2.9  CYU027   Add Validation TrackNo                    */
/* 2024-10-08   3.0  NLT013   FCR-950 Add OrderKey into @tExtScnData    */
/* 2024-11-12   3.1  YYS027   FCR-1122 Merged from 3.0(v2,NLT)          */
/*                                     and 2.8(V0,JH01)                 */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_TrackNo_SortToPallet] (  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(125) OUTPUT  
) AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- RDT.RDTMobRec variable  
DECLARE  
   @nFunc       INT,  
   @nScn        INT,  
   @nStep       INT,  
   @nAfterStep  INT,  
   @cLangCode   NVARCHAR( 3),  
   @nInputKey   INT,  
   @nMenu       INT,  
   @nMorePage   INT,  
   @bSuccess    INT,  
   @nTranCount  INT,  
  
   @cStorerKey  NVARCHAR( 15),  
   @cFacility   NVARCHAR( 5),  
   @cSKU        NVARCHAR( 20),  
   @cUserName           NVARCHAR( 18),  
   @cOrderKey           NVARCHAR( 10),  
   @cSQL                NVARCHAR( MAX),  
   @cSQLParam           NVARCHAR( MAX),  
  
   @cExtendedInfo       NVARCHAR( 20),  
   @cExtendedInfoSP     NVARCHAR( 20),  
   @cExtendedValidateSP NVARCHAR( 20),  
   @cExtendedUpdateSP   NVARCHAR( 20),  
   @tExtValidVar        VariableTable,  
   @tExtUpdateVar       VariableTable,  
   @tExtInfoVar       VariableTable,  
   @tCapturePackInfo    VariableTable,  
  
   @cInTrackNo          NVARCHAR( 40),  
   @cTrackNo            NVARCHAR( 40),  
   @cDecodeSP           NVARCHAR( 20),  
   @cBarcode            NVARCHAR( 100),  
   @cUserDefine01       NVARCHAR( 60),  
   @cPalletKey          NVARCHAR( 20),  
   @cSuggPalletKey      NVARCHAR( 20),  
   @cMBOLKey            NVARCHAR( 10),  
   @cLoadKey            NVARCHAR( 10),  
   @cPalletCloseStatus  NVARCHAR( 10),  
   @cPltDetailCloseStatus  NVARCHAR( 10),
   @cOrderInfo04        NVARCHAR( 30),  
   @cOption             NVARCHAR( 1),  
   @cPalletLineNumber   NVARCHAR( 5),  
   @nQty_Picked         INT,  
   @nQty_Packed         INT,  
   @curDel              CURSOR,  
   @dOrderDate          DATETIME,  
   @dDeliveryDate       DATETIME,  
   @cExternOrderKey     NVARCHAR( 50),  
   @nCtnCnt1            INT,  
   @cLabelNo            NVARCHAR( 20),  
   @cPalletNotAllowMixShipperKey NVARCHAR( 20),  
   @cCur_ShipperKey   NVARCHAR( 15),  
   @cNew_ShipperKey   NVARCHAR( 15),  
   @cCur_OrderKey     NVARCHAR( 10),  
   @cAllowScanToDiffPallet NVARCHAR( 1),  
   @cCapturePackInfo       NVARCHAR( 10),  
   @cPackInfo              NVARCHAR( 10),  
   @cCube                  NVARCHAR( 10),  
   @cWeight                NVARCHAR( 10),  
   @cRefNo                 NVARCHAR( 20),  
   @cLength                NVARCHAR( 10),  
   @cWidth                 NVARCHAR( 10),  
   @cHeight                NVARCHAR( 10),  
   @cAllowWeightZero       NVARCHAR( 1),  
   @cAllowCubeZero         NVARCHAR( 1),  
   @cAllowLengthZero       NVARCHAR( 1),  
   @cAllowWidthZero        NVARCHAR( 1),  
   @cAllowHeightZero       NVARCHAR( 1),  
   @fWeight                FLOAT,  
   @fLength                FLOAT,  
   @fWidth                 FLOAT,  
   @fHeight                FLOAT,  
   @cSortToPalletNotCreateMBOL   NVARCHAR( 1),  
   @cChk_StorerKey         NVARCHAR( 15),  
   @cPlt_StorerKey         NVARCHAR( 15),  
   @cCapturePackInfoSP     NVARCHAR( 20),  
   @cNotAllowReusePalletKey      NVARCHAR( 1),  
   @cPallet_Status         NVARCHAR( 10),  
   @cChkPalletOrdStatus    NVARCHAR( 1),  
   @cScanPalletToLane      NVARCHAR( 1),  
   @cSuggestLoc            NVARCHAR( 1),
   @cOverrideLoc           NVARCHAR( 1),
   @cExtendedScreenSP      NVARCHAR( 20),
   @cLane                  NVARCHAR( 30),  
   @cNewLane               NVARCHAR( 30),  
   @nPalletValidated       INT = 0,  
   @tCreateMBOLVar         VARIABLETABLE,  
   @nIsChildLane           INT = 0,  
   @nIsOriginalLane        INT = 0,  
   @tValidateLane          VARIABLETABLE,  
   @tExtScnData            VariableTable,
   @nAction                INT,
     
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
  
   @cLottable01  NVARCHAR( 18), @cLottable02  NVARCHAR( 18), @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,      @dLottable05  DATETIME,      @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30), @cLottable08  NVARCHAR( 30), @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30), @cLottable11  NVARCHAR( 30), @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,      @dLottable14  DATETIME,      @dLottable15  DATETIME,

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
   @nFunc       = Func,  
   @nScn      = Scn,  
   @nStep       = Step,  
   @nInputKey   = InputKey,  
   @nMenu       = Menu,  
   @cLangCode   = Lang_code,  
  
   @cStorerKey  = StorerKey,  
   @cFacility   = Facility,  
   @cUserName   = UserName,  
   @cOrderKey   = V_OrderKey,  
  
   @nPalletValidated       = V_Integer1,  
  
   @cLabelNo               = V_String1,  
   @cPalletKey             = V_String2,  
   @cMBOLKey               = V_String3,  
   @cPalletCloseStatus     = V_String4,  
   @cSuggPalletKey         = V_String5,  
   @cAllowScanToDiffPallet = V_String6,  
   @cCapturePackInfoSP     = V_String7,  
   @cChkPalletOrdStatus    = V_String8,  
   @cPltDetailCloseStatus    = V_String9,
  
   @cDecodeSP              =  V_String20,  
   @cExtendedInfoSP        =  V_String21,  
   @cExtendedValidateSP    =  V_String22,  
   @cExtendedUpdateSP      =  V_String23,  
   @cPalletNotAllowMixShipperKey = V_String24,  
   @cSortToPalletNotCreateMBOL   = V_String25,  
   @cNotAllowReusePalletKey      = V_String26,  
   @cScanPalletToLane            = V_String27,  
   @cExtendedScreenSP      = V_String28,
   @cSuggestLoc            = V_String29,
   @cOverrideLoc           = V_String30,
  
   @cTrackNo               = V_String41,  
   @cLane                  = V_String42,

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
  
FROM rdt.RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
-- Screen constant  
DECLARE  
   @nStep_TrackNo          INT,  @nScn_TrackNo           INT,  
   @nStep_ScanPalletID     INT,  @nScn_ScanPalletID      INT,  
   @nStep_ShowPalletID     INT,  @nScn_ShowPalletID      INT,  
   @nStep_ClosePallet      INT,  @nScn_ClosePallet       INT,  
   @nStep_ScanDiffPallet   INT,  @nScn_ScanDiffPallet    INT,  
   @nStep_PalletDimension  INT,  @nScn_PalletDimension   INT,  
   @nStep_ConfirmNewLane   INT,  @nScn_ConfirmNewLane    INT  
  
SELECT  
   @nStep_TrackNo          = 1,   @nScn_TrackNo          = 5800,  
   @nStep_ScanPalletID     = 2,   @nScn_ScanPalletID     = 5801,  
   @nStep_ShowPalletID     = 3,   @nScn_ShowPalletID     = 5802,  
   @nStep_ClosePallet      = 4,   @nScn_ClosePallet      = 5803,  
   @nStep_ScanDiffPallet   = 5,   @nScn_ScanDiffPallet   = 5804,  
   @nStep_PalletDimension  = 6,   @nScn_PalletDimension  = 5805,  
   @nStep_ConfirmNewLane   = 7,   @nScn_ConfirmNewLane   = 5806  
  
  
IF @nFunc = 1653 -- TrackNo Sort To Pallet  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0 GOTO Step_0                 -- Func = PRE CARTONIZE PRINT LABEL  
   IF @nStep = 1 GOTO Step_TrackNo           -- Scn = 5800. TRACK NO  
   IF @nStep = 2 GOTO Step_ScanPalletID      -- Scn = 5801. SCAN PALLET ID  
   IF @nStep = 3 GOTO Step_ShowPalletID      -- Scn = 5802. SHOW PALLET ID  
   IF @nStep = 4 GOTO Step_ClosePallet       -- Scn = 5803. CLOSE PALLET ID  
   IF @nStep = 5 GOTO Step_ScanDiffPallet    -- Scn = 5804. SCAN TO DIFF PALLET ID  
   IF @nStep = 6 GOTO Step_PalletDimension   -- Scn = 5805. PALLET DIMENSION  
   IF @nStep = 7 GOTO Step_ConfirmNewLane    -- Scn = 5806. CONFIRM SCAN NEW LANE  
   IF @nStep =99 GOTO Step_ExtScn            -- Scn = 5807. SCAN TO LOC/LANE
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. func = 1654. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)  
   IF @cExtendedInfoSP IN ('0', '')  
      SET @cExtendedInfoSP = ''  
  
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)  
   IF @cExtendedValidateSP IN ('0', '')  
      SET @cExtendedValidateSP = ''  
  
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)  
   IF @cExtendedUpdateSP IN ('0', '')  
      SET @cExtendedUpdateSP = ''  
  
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerkey)  
   IF @cDecodeSP IN ('0', '')  
      SET @cDecodeSP = ''  
  
   SET @cPalletCloseStatus = rdt.RDTGetConfig( @nFunc, 'PalletCloseStatus', @cStorerkey)  
   IF @cPalletCloseStatus = '0'  
      SET @cPalletCloseStatus = '9'  

     SET @cPltDetailCloseStatus = rdt.RDTGetConfig( @nFunc, 'PltDetailCloseStatus', @cStorerkey)
   IF @cPltDetailCloseStatus = '0'
      SET @cPltDetailCloseStatus = '9'

   SET @cPalletNotAllowMixShipperKey = rdt.RDTGetConfig( @nFunc, 'PalletNotAllowMixShipperKey', @cStorerkey)  
  
   SET @cAllowScanToDiffPallet = rdt.RDTGetConfig( @nFunc, 'AllowScanToDiffPallet', @cStorerkey)  
  
   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfo', @cStorerKey)  
   IF @cCapturePackInfoSP = '0'  
      SET @cCapturePackInfoSP = ''  
  
   SET @cSortToPalletNotCreateMBOL = rdt.RDTGetConfig( @nFunc, 'SortToPalletNotCreateMBOL', @cStorerKey)  
  
   SET @cNotAllowReusePalletKey = rdt.RDTGetConfig( @nFunc, 'NotAllowReusePalletKey', @cStorerKey)  
  
   SET @cChkPalletOrdStatus = rdt.RDTGetConfig( @nFunc, 'ChkPalletOrdStatus', @cStorerKey)  
  
   SET @cScanPalletToLane = rdt.RDTGetConfig( @nFunc, 'ScanPalletToLane', @cStorerKey)  
  
   SET @cSuggestLoc = rdt.RDTGetConfig( @nFunc, 'SUGGESTLOC', @cStorerKey)
   SET @cOverrideLoc = rdt.RDTGetConfig( @nFunc, 'OVERRIDELOC', @cStorerKey)
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
      SET @cExtendedScreenSP = ''

   -- Initialize value  
   SET @cTrackNo = ''  
   SET @cOption = ''  
   SET @cLane = ''  
   SET @cMBOLKey = ''  
   SET @cPalletKey = ''  
   SET @cOrderKey = ''
  
   EXEC rdt.rdtSetFocusField @nMobile, 1  
  
   -- Prep next screen var  
   SET @cOutField01 = '' -- Track No  
   SET @cOutField02 = '' -- Option  
  
   SET @nScn = @nScn_TrackNo  
   SET @nStep = @nStep_TrackNo  
  
   -- EventLog  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType = '1', -- Sign-in  
      @cUserID     = @cUserName,  
      @nMobileNo   = @nMobile,  
      @nFunctionID = @nFunc,  
      @cFacility   = @cFacility,  
      @cStorerKey  = @cStorerKey,  
      @nStep       = @nStep  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Scn = 5800  
   TRACK NO    (field01, input)  
********************************************************************************/  
Step_TrackNo:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cInTrackNo = @cInField01  
      SET @cBarcode = @cInField01  
      SET @cOption = @cInField02  
  
      IF @cOption <> ''  
      BEGIN  
         IF @cOption <> '1'  
         BEGIN  
            SET @nErrNo = 156351  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
            GOTO Step_TrackNo_Fail  
         END  
  
         SET @cOutField01 = ''  
         SET @nScn = @nScn_ClosePallet  
         SET @nStep = @nStep_ClosePallet  
      END  
      ELSE  
      BEGIN  
         IF ISNULL( @cInTrackNo, '') = ''  
         BEGIN  
            SET @nErrNo = 156352  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TrackNo  
            GOTO Step_TrackNo_Fail  
         END  
  
         -- Validate SKU  
         IF @cBarcode <> ''  
         BEGIN  
            -- Decode  
            IF @cDecodeSP <> ''  
            BEGIN  
               -- Standard decode  
               IF @cDecodeSP = '1'  
               BEGIN  
                  SET @cUserDefine01 = ''  
                  EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,  
                     @cUserDefine01 = @cUserDefine01  OUTPUT,  
                     @nErrNo        = @nErrNo         OUTPUT,  
                    @cErrMsg       = @cErrMsg        OUTPUT  
                  IF @nErrNo <> 0  
                     GOTO Quit  
  
                  SET @cTrackNo = @cUserDefine01  
               END  
  
               -- Customize decode  
               ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')  
               BEGIN  
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +  
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +  
                     ' @cTrackNo OUTPUT, @cOrderKey OUTPUT, @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
                  SET @cSQLParam =  
                     ' @nMobile        INT,           ' +  
                     ' @nFunc          INT,           ' +  
                     ' @cLangCode      NVARCHAR( 3),  ' +  
                     ' @nStep          INT,           ' +  
                     ' @nInputKey      INT,           ' +  
                     ' @cFacility      NVARCHAR( 5),  ' +  
                     ' @cStorerKey     NVARCHAR( 15), ' +  
                     ' @cBarcode       NVARCHAR( 100),  ' +  
                     ' @cTrackNo       NVARCHAR( 40)  OUTPUT, ' +  
                     ' @cOrderKey      NVARCHAR( 10)  OUTPUT, ' +  
                     ' @cLabelNo       NVARCHAR( 20)  OUTPUT, ' +  
                     ' @nErrNo         INT            OUTPUT, ' +  
                     ' @cErrMsg        NVARCHAR( 20)  OUTPUT'  
  
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,  
                     @cTrackNo OUTPUT, @cOrderKey OUTPUT, @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
                  IF @nErrNo <> 0  
                     GOTO Step_TrackNo_Fail  
               END  
            END  
            ELSE  
            BEGIN  
               SELECT @cLabelNo = LabelNo  
               FROM dbo.CartonTrack WITH (NOLOCK)  
               WHERE KeyName = @cStorerKey  
               AND   Trackingno = @cBarcode  
  
               SELECT TOP 1 @cOrderKey = PH.OrderKey  
               FROM dbo.PackDetail PD WITH (NOLOCK)  
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)  
               WHERE PD.StorerKey = @cStorerKey  
               AND   PD.LabelNo = @cLabelNo  
               ORDER BY 1  
  
               SET @cTrackNo = @cInTrackNo  
            END  
  
            -- Check barcode format  
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TrackingNo', @cBarcode) = 0  
            BEGIN  
               SET @nErrNo = 156374  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
               GOTO Step_TrackNo_Fail  
            END  
         END  
  
         IF ISNULL( @cOrderKey, '') = ''  
         BEGIN  
            SET @nErrNo = 156353  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Orders  
            GOTO Step_TrackNo_Fail  
         END  
  
         IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)  
                     WHERE OrderKey = @cOrderKey  
                     AND   [Status] = '9')  
         BEGIN  
            SET @nErrNo = 189803  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Orders Shipped  
            GOTO Step_TrackNo_Fail  
         END  
  
         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)  
                     WHERE StorerKey = @cStorerKey  
                     AND   UserDefine02 = @cTrackNo)  
         BEGIN  
            SET @nErrNo = 189817  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNo In Use  
            GOTO Step_TrackNo_Fail  
         END  
  
         -- Extended validate  
         IF @cExtendedValidateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
            BEGIN  
               DELETE FROM @tExtValidVar
               INSERT INTO @tExtValidVar (Variable, Value) VALUES ( '@cLabelNo',     @cLabelNo)

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
                  ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar, ' +  
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
               SET @cSQLParam =  
                  ' @nMobile        INT,           ' +  
                  ' @nFunc          INT,           ' +  
                  ' @cLangCode      NVARCHAR( 3),  ' +  
                  ' @nStep          INT,           ' +  
                  ' @nInputKey      INT,           ' +  
                  ' @cFacility      NVARCHAR( 5),  ' +  
                  ' @cStorerKey     NVARCHAR( 15), ' +  
                  ' @cTrackNo       NVARCHAR( 40), ' +  
                  ' @cOrderKey      NVARCHAR( 20),'  +  
                  ' @cPalletKey     NVARCHAR( 20), ' +  
                  ' @cMBOLKey       NVARCHAR( 10), ' +  
                  ' @cLane          NVARCHAR( 30), ' +  
                  ' @tExtValidVar   VariableTable READONLY, ' +  
                  ' @nErrNo         INT           OUTPUT, ' +  
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
                  @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar,  
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
               IF @nErrNo <> 0  
                  GOTO Step_TrackNo_Fail  
            END  
         END  
  
         -- Extended update  
         IF @cExtendedUpdateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
                  ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar, ' +  
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
               SET @cSQLParam =  
                  ' @nMobile        INT,           ' +  
                  ' @nFunc          INT,           ' +  
                  ' @cLangCode      NVARCHAR( 3),  ' +  
                  ' @nStep          INT,           ' +  
                  ' @nInputKey      INT,           ' +  
                  ' @cFacility      NVARCHAR( 5),  ' +  
                  ' @cStorerKey     NVARCHAR( 15), ' +  
                  ' @cTrackNo       NVARCHAR( 40), ' +  
                  ' @cOrderKey      NVARCHAR( 20),'  +  
                  ' @cPalletKey     NVARCHAR( 20), ' +  
                  ' @cMBOLKey       NVARCHAR( 10), ' +  
                  ' @cLane          NVARCHAR( 30), ' +  
                  ' @tExtUpdateVar  VariableTable READONLY, ' +  
                  ' @nErrNo         INT           OUTPUT, ' +  
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
                  @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar,  
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
               IF @nErrNo <> 0  
                  GOTO Step_TrackNo_Fail  
            END  
         END  
  
         SET @cMBOLKey = ''  
         SET @nErrNo = 0  
         EXEC [RDT].[rdt_TrackNo_SortToPallet_GetMbolKey]  
            @nMobile       = @nMobile,  
            @nFunc         = @nFunc,  
            @cLangCode     = @cLangCode,  
            @nStep         = @nStep,  
            @nInputKey     = @nInputKey,  
            @cFacility     = @cFacility,  
            @cStorerKey    = @cStorerKey,  
            @cTrackNo = @cTrackNo,  
            @cOrderKey     = @cOrderKey,  
            @cPalletKey    = @cPalletKey  OUTPUT,  
            @cMBOLKey      = @cMBOLKey    OUTPUT,  
            @cLane         = @cLane       OUTPUT,  
            @nErrNo        = @nErrNo      OUTPUT,  
            @cErrMsg       = @cErrMsg     OUTPUT  
  
         IF @nErrNo <> 0  
            GOTO Quit  
  
         -- Check if pallet closed  
         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND [Status] >= '5')  
            SET @cMBOLKey = ''  
  
         IF ISNULL( @cMBOLKey, '') <> '' OR ( @cSortToPalletNotCreateMBOL = '1' AND @cPalletKey <> '')  
         BEGIN  
            IF @cScanPalletToLane = '1'  
            BEGIN  
               -- Do not allow cartons for an order to scatter across different lane / MBOL  
               IF EXISTS ( SELECT 1  
                           FROM dbo.MBOL M WITH (NOLOCK)  
                           JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON ( MD.MBOLKey = M.MBOLKey)  
                           WHERE M.ExternMBOLKey <> @cLane   -- Scanned lane  
                           AND   MD.OrderKey = @cOrderKey)   -- Decoded from DecodeSP  
               BEGIN  
                  SET @nErrNo = 189804  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrdInOtherLane  
                  GOTO Step_TrackNo_Fail  
               END  
            END  
  
            SET @cOutField01 = @cTrackNo  
            SET @cOutField02 = @cOrderKey  
            SET @cOutField03 = @cPalletKey  
            SET @cOutField04 = ''  
            SET @cOutField05 = CASE WHEN @cScanPalletToLane = '1' THEN @cLane ELSE '' END  
  
            SET @nScn  = @nScn_ShowPalletID  
            SET @nStep = @nStep_ShowPalletID  
         END  
         ELSE  
         BEGIN  
            SET @cPalletKey = ''  
            SET @nPalletValidated = 0  
  
            -- Prep next screen var  
            SET @cOutField01 = @cTrackNo  
            SET @cOutField02 = @cOrderKey  
            SET @cOutField03 = ''   -- PalletKey  
  
            IF @cScanPalletToLane = '1'  
            BEGIN  
               IF @cLane = ''  
                  SELECT @cLane = UserDefine03  
                  FROM dbo.PALLETDETAIL WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey  
                  AND   UserDefine01 = @cOrderKey  
  
               IF ISNULL( @cLane, '') <> ''  
                  SET @cOutField04 = @cLane  
               ELSE  
                  SET @cOutField04 = '' -- Lane  
  
               SET @cFieldAttr04 = ''  
            END  
            ELSE  
               SET @cFieldAttr04 = 'O'  
  
            -- Goto scan pallet screen  
            SET @nScn  = @nScn_ScanPalletID  
            SET @nStep = @nStep_ScanPalletID  
  
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- PalletKey  
         END  
      END  
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
      SET @cOutField01 = ''  
   END  
  
   -- Extended info  
   IF @cExtendedInfoSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
            ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT'  
  
         SET @cSQLParam =  
            ' @nMobile        INT,           ' +  
            ' @nFunc          INT,           ' +  
            ' @cLangCode      NVARCHAR( 3),  ' +  
            ' @nStep          INT,       ' +  
            ' @nAfterStep     INT,           ' +  
            ' @nInputKey      INT,           ' +  
            ' @cFacility    NVARCHAR( 5),  ' +  
            ' @cStorerKey     NVARCHAR( 15), ' +  
            ' @cTrackNo       NVARCHAR( 40), ' +  
            ' @cOrderKey      NVARCHAR( 20),'  +  
            ' @cPalletKey     NVARCHAR( 20), ' +  
            ' @cMBOLKey       NVARCHAR( 10), ' +  
            ' @cLane          NVARCHAR( 30), ' +  
            ' @tExtInfoVar    VariableTable READONLY, ' +  
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep_TrackNo, @nStep, @nInputKey, @cFacility, @cStorerKey,  
            @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT  
  
         IF @cExtendedInfo <> ''  
            SET @cOutField15 = @cExtendedInfo  
      END  
   END  

   --FCR-539 extend screen
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF @nInputKey = 1 AND @cOption = ''--YES
      BEGIN
         SET @nStep = 1
      END

      GOTO Step_ExtScn
   END
     
   GOTO Quit  
  
   Step_TrackNo_Fail:  
   BEGIN  
      SET @cTrackNo = ''  
      SET @cOrderKey = ''  
      SET @cLabelNo = ''   -- ZG01  
      SET @cInTrackNo = ''  
      SET @cOutField01 = ''  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 2. Scn = 5801.  
   TRACK NO       (field01)  
   ORDERKEY       (field02)  
   PALLET ID      (field03, input)  
   LANE           (field04, input)  
********************************************************************************/  
Step_ScanPalletID:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Initialize value  
      SET @cPalletKey = @cInField03  
      SET @cLane = @cInField04  
  
      IF ISNULL( @cPalletKey, '') = ''  
      BEGIN  
         SET @nErrNo = 156354  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Pallet ID  
         GOTO Step_ScanPalletID_Fail  
      END  
  
      -- Check barcode format  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletKey', @cPalletKey) = 0  
      BEGIN  
         SET @nErrNo = 156367  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_ScanPalletID_Fail  
      END  
  
      SET @cPallet_Status= ''  
      SELECT @cPallet_Status = [Status]  
      FROM dbo.Pallet WITH (NOLOCK)  
      WHERE PalletKey = @cPalletKey  
      AND   StorerKey = @cStorerKey  
  
      IF @@ROWCOUNT > 0  
      BEGIN  
         IF @cPallet_Status = @cPalletCloseStatus AND @cNotAllowReusePalletKey = '1'  
         BEGIN  
            SET @nErrNo = 189801  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet In Use  
            GOTO Step_ScanPalletID_Fail  
         END  
      END  
  
      -- Check if user is scanning tracking no onto different storer  
      SET @cChk_StorerKey = ''  
      SELECT TOP 1 @cChk_StorerKey = StorerKey  
      FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey --JH01
      AND LabelNo = @cLabelNo
      ORDER BY 1  

      --JH01
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 156397  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff StorerKey  
         GOTO Step_ShowPalletID_Fail   
      END
      --JH01
  
      IF @cChk_StorerKey <> ''  
      BEGIN  
       SET @cPlt_StorerKey = ''  
         SELECT TOP 1 @cPlt_StorerKey = StorerKey  
         FROM dbo.PALLETDETAIL WITH (NOLOCK)  
         WHERE PalletKey = @cPalletKey  
         ORDER BY 1  
  
         IF @@ROWCOUNT > 0 AND ( @cChk_StorerKey <> @cPlt_StorerKey)  
         BEGIN  
            SET @nErrNo = 156397  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff StorerKey  
            GOTO Step_ScanPalletID_Fail  
         END  
      END  
  
      IF @cPalletNotAllowMixShipperKey = '1'  
      BEGIN  
         -- Get shipperkey from newly scanned orderkey (tracking no)  
         SELECT @cNew_ShipperKey = ShipperKey  
         FROM dbo.ORDERS WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
  
         -- Get orderkey from existing pallet  
         SELECT TOP 1 @cCur_OrderKey = UserDefine01  
         FROM dbo.PALLETDETAIL WITH (NOLOCK)  
         WHERE PalletKey = @cPalletKey  
         AND   StorerKey = @cStorerKey  
         AND   [Status] = '0'  
         ORDER BY 1  
  
         IF @@ROWCOUNT = 1  
         BEGIN  
            -- Get shipperkey from orders on existing pallet  
            SELECT @cCur_ShipperKey = ShipperKey  
            FROM dbo.ORDERS WITH (NOLOCK)  
            WHERE OrderKey = @cCur_OrderKey  
  
            -- Validate if same shipperkey  
            IF @cCur_ShipperKey <> @cNew_ShipperKey  
            BEGIN  
               SET @nErrNo = 156373  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltDiffShipper  
               GOTO Step_ScanPalletID_Fail  
            END  
         END  
      END  
  
      IF @cScanPalletToLane = '1'  
      BEGIN  
         EXEC [RDT].[rdt_TrackNo_SortToPallet_ValidateLane]  
            @nMobile       = @nMobile,  
            @nFunc         = @nFunc,  
            @cLangCode     = @cLangCode,  
            @nStep         = @nStep,  
            @nInputKey     = @nInputKey,  
            @cFacility     = @cFacility,  
            @cStorerKey    = @cStorerKey,  
            @cTrackNo      = @cTrackNo,  
            @cOrderKey     = @cOrderKey,  
            @cPalletKey    = @cPalletKey,  
            @cMBOLKey      = @cMBOLKey,  
            @cLabelNo      = @cLabelNo,  
            @tValidateLane = @tValidateLane,  
            @cLane         = @cLane       OUTPUT,  
            @nErrNo        = @nErrNo      OUTPUT,  
            @cErrMsg       = @cErrMsg     OUTPUT              
              
         IF @nErrNo <> 0  
            GOTO Step_ScanLane_Fail     
                 
         IF ISNULL( @cLane, '') = '' AND @nPalletValidated = 0  
         BEGIN  
            SET @cOutField03 = @cPalletKey  
            SET @nPalletValidated = 1  
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Lane  
            GOTO Quit  
         END  
  
         IF ISNULL( @cLane, '') = '' AND @nPalletValidated = 1  
         BEGIN  
            SET @nErrNo = 189805  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lane  
            GOTO Step_ScanLane_Fail  
         END  
  
         -- Check barcode format  
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Lane', @cBarcode) = 0  
         BEGIN  
            SET @nErrNo = 189810  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
            GOTO Step_ScanLane_Fail  
         END  
  
         -- Check if Lane is closed  
         IF EXISTS ( SELECT 1 FROM dbo.MBOL WITH (NOLOCK)  
                     WHERE ExternMBOLKey = @cLane  
                     AND   [Status] >= '5')  
         BEGIN  
            SET @nErrNo = 189806  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lane Closed  
            GOTO Step_ScanLane_Fail  
         END  
  
         -- Check if pallet is already another to another lane  
         IF EXISTS ( SELECT 1  
                     FROM dbo.PalletDetail PD WITH (NOLOCK)  
                     JOIN dbo.PALLET P WITH (NOLOCK) ON ( PD.PalletKey = P.PalletKey)  
                     WHERE P.StorerKey = @cStorerKey  
                     AND   P.PalletKey = @cPalletKey  -- Scanned pallet ID  
                     AND   P.Status < @cPalletCloseStatus  
                     AND   PD.UserDefine03 <> @cLane) -- Scanned lane  
         BEGIN  
            SET @nErrNo = 189807  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltInOtherLane  
            GOTO Step_ScanLane_Fail  
         END  
  
         -- Do not allow cartons for an order to scatter across different lane / MBOL  
         IF EXISTS ( SELECT 1  
                     FROM dbo.MBOL M WITH (NOLOCK)  
                     JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON ( MD.MBOLKey = M.MBOLKey)  
                     WHERE M.ExternMBOLKey <> @cLane   -- Scanned lane  
                     AND   MD.OrderKey = @cOrderKey)   -- Decoded from DecodeSP  
         BEGIN  
            SET @nErrNo = 189808  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrdInOtherLane  
            GOTO Step_ScanLane_Fail  
         END  
  
         IF EXISTS ( SELECT 1  
                     FROM dbo.PalletDetail PD WITH (NOLOCK)  
                     LEFT JOIN dbo.MBOL M WITH (NOLOCK) ON ( M.ExternMBOLKey = PD.UserDefine03)  
                     WHERE PD.StorerKey = @cStorerKey  
                     AND   PD.UserDefine03 = @cLane  
                     AND   M.MBOLKey IS NULL)  
         BEGIN  
            SET @nErrNo = 189818  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrdInOtherLane  
            GOTO Step_ScanLane_Fail  
         END  
  
         IF EXISTS ( SELECT 1  
                     FROM dbo.MBOL WITH (NOLOCK)  
                     WHERE ExternMBOLKey = @cLane  
                     AND   [STATUS] < '5'  
                     AND   ISNULL(UserDefine05, '') <> '')      -- Lane already split  
                     AND NOT EXISTS (    
                                 SELECT 1 FROM dbo.Codelkup CL WITH (NOLOCK)    
                                 JOIN dbo.Orders O WITH (NOLOCK) ON O.Type = CL.Code2 AND O.StorerKey = CL.StorerKey     
                                 WHERE O.OrderKey = @cOrderKey    
                                 AND CL.ListName = 'LANECONFIG'    
                                 AND CL.Code = 'SPLNEXCLORD'    
                                 AND O.StorerKey = @cStorerKey    
                                 AND CL.Short = '1')    
         BEGIN  
            SET @nIsChildLane = 0  
            SELECT @nIsChildLane = 1  
            FROM dbo.MBOL M WITH (NOLOCK)  
            JOIN dbo.Orders O WITH (NOLOCK) ON ( O.MBOLKey = M.MBOLKey)  
            WHERE O.StorerKey = @cStorerKey  
            AND   M.ExternMBOLKey = @cLane  
            AND   CHARINDEX('|', M.ExternMBOLKey) > 1   -- Duplicated lane  
  
            IF @nIsChildLane = 1  
            BEGIN  
               SET @nErrNo = 189819  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LaneAlrdSplit  
               GOTO Step_ScanLane_Fail  
            END  
  
            SET @nIsOriginalLane = 1  
            SELECT @nIsOriginalLane = 0  
            FROM dbo.MBOL M WITH (NOLOCK)  
            JOIN dbo.Orders O WITH (NOLOCK) ON ( O.MBOLKey = M.MBOLKey)  
            WHERE O.StorerKey = @cStorerKey  
            AND   O.OrderKey = @cOrderKey  
            AND   M.ExternMBOLKey = @cLane  
  
            IF @nIsOriginalLane = 1  
            BEGIN  
               SET @nErrNo = 189820  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LaneAlrdSplit  
               GOTO Step_ScanLane_Fail  
            END  
         END  
      END  
  
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @cTrackNo       NVARCHAR( 40), ' +  
               ' @cOrderKey      NVARCHAR( 20),'  +  
               ' @cPalletKey     NVARCHAR( 20), ' +  
               ' @cMBOLKey       NVARCHAR( 10), ' +  
               ' @cLane          NVARCHAR( 30), ' +  
               ' @tExtValidVar   VariableTable READONLY, ' +  
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- Check whether user scanned a new lane  
      -- (prevent user accidentally scan other barcode and create new mbol)  
      IF @cScanPalletToLane = '1'  
      BEGIN  
         IF NOT EXISTS (  
             SELECT 1 FROM MBOL M WITH (NOLOCK)  
             JOIN PalletDetail PD WITH (NOLOCK) ON ( PD.UserDefine03 = M.ExternMBOLKey)  
             WHERE ExternMBOLKey = @cLane  
             AND   PD.StorerKey = @cStorerKey)  
         BEGIN  
            -- Prep next screen var  
            SET @cOutField01 = @cPalletKey   -- PalletKey  
            SET @cOutField02 = @cLane        -- Lane  
            SET @cOutField03 = ''  
  
            SET @nScn = @nScn_ConfirmNewLane  
            SET @nStep = @nStep_ConfirmNewLane  
  
            GOTO Quit  
         END  
      END  
  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdt_CreateMbol -- For rollback or commit only our own transaction  
  
      SET @nErrNo = 0  
      EXEC [RDT].[rdt_TrackNo_SortToPallet_CreateMbol]  
         @nMobile       = @nMobile,  
         @nFunc         = @nFunc,  
         @cLangCode     = @cLangCode,  
         @nStep         = @nStep,  
         @nInputKey     = @nInputKey,  
         @cFacility     = @cFacility,  
         @cStorerKey    = @cStorerKey,  
         @cTrackNo      = @cTrackNo,  
         @cOrderKey     = @cOrderKey,  
         @cPalletKey    = @cPalletKey,  
         @cMBOLKey      = @cMBOLKey OUTPUT,  
         @cLane         = @cLane,  
         @cLabelNo      = @cLabelNo,  
         @tCreateMBOLVar= @tCreateMBOLVar,  
         @nErrNo        = @nErrNo      OUTPUT,  
         @cErrMsg       = @cErrMsg     OUTPUT  
  
      IF @nErrNo <> 0  
         GOTO RollBackTran_CreateMbol  
  
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @cTrackNo       NVARCHAR( 40), ' +  
               ' @cOrderKey      NVARCHAR( 20),'  +  
               ' @cPalletKey     NVARCHAR( 20), ' +  
               ' @cMBOLKey       NVARCHAR( 10), ' +  
               ' @cLane          NVARCHAR( 30), ' +  
               ' @tExtUpdateVar  VariableTable READONLY, ' +  
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO RollBackTran_CreateMbol  
         END  
      END  
  
      COMMIT TRAN rdt_CreateMbol  
  
      GOTO Quit_CreateMbol  
  
      RollBackTran_CreateMbol:  
         ROLLBACK TRAN rdt_CreateMbol    -- Only rollback change made here  
      Quit_CreateMbol:  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
           COMMIT TRAN  
  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = '' -- Option  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      SET @cFieldAttr04 = ''  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Initialize value  
      SET @cTrackNo = ''  
      SET @cOrderKey = ''  
      SET @nPalletValidated = 0  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = '' -- Option  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      SET @cFieldAttr04 = ''  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   -- Extended info  
   IF @cExtendedInfoSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
            ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT'  
  
         SET @cSQLParam =  
            ' @nMobile        INT,           ' +  
            ' @nFunc          INT,           ' +  
            ' @cLangCode      NVARCHAR( 3),  ' +  
            ' @nStep          INT,           ' +  
            ' @nAfterStep     INT,           ' +  
            ' @nInputKey      INT,           ' +  
            ' @cFacility      NVARCHAR( 5),  ' +  
            ' @cStorerKey     NVARCHAR( 15), ' +  
            ' @cTrackNo       NVARCHAR( 40), ' +  
            ' @cOrderKey      NVARCHAR( 20),'  +  
            ' @cPalletKey     NVARCHAR( 20), ' +  
            ' @cMBOLKey       NVARCHAR( 10), ' +  
            ' @cLane          NVARCHAR( 30), ' +  
            ' @tExtInfoVar    VariableTable READONLY, ' +  
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep_ScanPalletID, @nStep, @nInputKey, @cFacility, @cStorerKey,  
            @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT  
  
         IF @cExtendedInfo <> ''  
            SET @cOutField15 = @cExtendedInfo  
      END  
   END  
  
   GOTO Quit  
  
   Step_ScanPalletID_Fail:  
   BEGIN  
      SET @cPalletKey = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = @cLane  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- PalletKey  
   END  
  
   Step_ScanLane_Fail:  
   BEGIN  
      SET @cLane = ''  
      SET @cOutField03 = @cPalletKey  
      SET @cOutField04 = ''  
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Lane  
   END  
  
END  
GOTO Quit  
  
/********************************************************************************  
Step 3. Scn = 5802.  
   TRACK NO       (field01)  
   ORDERKEY       (field02)  
   PALLET ID      (field03, input)  
********************************************************************************/  
Step_ShowPalletID:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Initialize value  
      SET @cSuggPalletKey = @cOutField03  
      SET @cPalletKey = @cInField04  
  
      IF ISNULL( @cPalletKey, '') = ''  
      BEGIN  
         SET @nErrNo = 156360  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Pallet ID  
         GOTO Step_ShowPalletID_Fail  
      END  
  
      -- Check barcode format  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletKey', @cPalletKey) = 0  
      BEGIN  
         SET @nErrNo = 189813  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_ShowPalletID_Fail  
      END  
  
      IF @cSuggPalletKey <> @cPalletKey  
      BEGIN  
       IF @cAllowScanToDiffPallet = '0'  
       BEGIN  
            SET @nErrNo = 156361  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Not Match  
            GOTO Step_ShowPalletID_Fail  
       END  
       ELSE  
         BEGIN  
          SET @cOption = ''  
  
        SET @cOutField01 = @cSuggPalletKey  
          SET @cOutField02 = @cPalletKey  
          SET @cOutField03 = ''  
  
            SET @nScn = @nScn_ScanDiffPallet  
            SET @nStep = @nStep_ScanDiffPallet  
  
            GOTO Quit  
         END  
      END  
  
      -- Check if user is scanning tracking no onto different storer  
      SET @cChk_StorerKey = ''  
      SELECT TOP 1 @cChk_StorerKey = StorerKey  
      FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  --JH01
      AND LabelNo = @cLabelNo  
      ORDER BY 1  

      --JH01
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 156398  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff StorerKey  
         GOTO Step_ShowPalletID_Fail   
      END
      --JH01
  
      IF NOT EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)  
                      WHERE PalletKey = @cPalletKey  
                      AND   StorerKey = @cChk_StorerKey)  
      BEGIN  
         SET @nErrNo = 156398  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff StorerKey  
         GOTO Step_ShowPalletID_Fail  
      END  
  
      IF @cScanPalletToLane = '1'  
      BEGIN  
         -- Check if pallet is already another to another lane  
         IF EXISTS ( SELECT 1  
                     FROM dbo.PalletDetail PD WITH (NOLOCK)  
                     JOIN dbo.PALLET P WITH (NOLOCK) ON ( PD.PalletKey = P.PalletKey)  
                     WHERE P.StorerKey = @cStorerKey  
                     AND   P.PalletKey = @cPalletKey  -- Scanned pallet ID  
                     AND   P.Status < @cPalletCloseStatus  
                     AND   PD.UserDefine03 <> @cLane) -- Scanned lane  
         BEGIN  
            SET @nErrNo = 189809  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltInOtherLane  
            GOTO Step_ShowPalletID_Fail  
         END  
      END  
  
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @cTrackNo       NVARCHAR( 40), ' +  
               ' @cOrderKey      NVARCHAR( 20),'  +  
               ' @cPalletKey     NVARCHAR( 20), ' +  
               ' @cMBOLKey       NVARCHAR( 10), ' +  
               ' @cLane          NVARCHAR( 30), ' +  
               ' @tExtValidVar   VariableTable READONLY, ' +  
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_TrackNo_Fail  
         END  
      END  
  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdt_CreateMbolDetail -- For rollback or commit only our own transaction  
      SET @nErrNo = 0  
      EXEC [RDT].[rdt_TrackNo_SortToPallet_CreateMbol]  
         @nMobile       = @nMobile,  
         @nFunc         = @nFunc,  
         @cLangCode     = @cLangCode,  
         @nStep         = @nStep,  
         @nInputKey     = @nInputKey,  
         @cFacility     = @cFacility,  
         @cStorerKey   = @cStorerKey,  
         @cTrackNo      = @cTrackNo,  
         @cOrderKey     = @cOrderKey,  
         @cPalletKey    = @cPalletKey,  
         @cMBOLKey      = @cMBOLKey,  
         @cLane         = @cLane,  
         @cLabelNo      = @cLabelNo,  
         @tCreateMBOLVar= @tCreateMBOLVar,  
         @nErrNo        = @nErrNo      OUTPUT,  
         @cErrMsg       = @cErrMsg     OUTPUT  
  
      IF @nErrNo <> 0  
         GOTO RollBackTran_CreateMbolDetail  
  
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @cTrackNo       NVARCHAR( 40), ' +  
               ' @cOrderKey      NVARCHAR( 20),'  +  
               ' @cPalletKey     NVARCHAR( 20), ' +  
               ' @cMBOLKey       NVARCHAR( 10), ' +  
               ' @cLane          NVARCHAR( 30), ' +  
               ' @tExtUpdateVar  VariableTable READONLY, ' +  
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO RollBackTran_CreateMbolDetail  
         END  
      END  
  
      COMMIT TRAN rdt_CreateMbolDetail  
  
      GOTO Quit_CreateMbolDetail  
  
      RollBackTran_CreateMbolDetail:  
         ROLLBACK TRAN rdt_CreateMbolDetail -- Only rollback change made here  
      Quit_CreateMbolDetail:  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
  
      IF @nErrNo <> 0  
         GOTO Step_ShowPalletID_Fail  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = '' -- Option  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Initialize value  
      SET @cTrackNo = ''  
      SET @cOrderKey = ''  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = ''  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   -- Extended info  
   IF @cExtendedInfoSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
            ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT'  
  
         SET @cSQLParam =  
            ' @nMobile        INT,           ' +  
            ' @nFunc          INT,           ' +  
            ' @cLangCode      NVARCHAR( 3),  ' +  
            ' @nStep          INT,           ' +  
            ' @nAfterStep     INT,           ' +  
            ' @nInputKey      INT,           ' +  
            ' @cFacility      NVARCHAR( 5),  ' +  
            ' @cStorerKey     NVARCHAR( 15), ' +  
            ' @cTrackNo       NVARCHAR( 40), ' +  
            ' @cOrderKey      NVARCHAR( 20),'  +  
            ' @cPalletKey     NVARCHAR( 20), ' +  
            ' @cMBOLKey       NVARCHAR( 10), ' +  
            ' @cLane          NVARCHAR( 30), ' +  
            ' @tExtInfoVar    VariableTable READONLY, ' +  
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep_ShowPalletID, @nStep, @nInputKey, @cFacility, @cStorerKey,  
            @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT  
  
         IF @cExtendedInfo <> ''  
            SET @cOutField15 = @cExtendedInfo  
      END  
   END  
  
   GOTO Quit  
  
   Step_ShowPalletID_Fail:  
   BEGIN  
      SET @cPalletKey = ''  
      SET @cOutField04 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 4. Scn = 5803  
   PALLETKEY    (field01, input)  
********************************************************************************/  
Step_ClosePallet:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cPalletKey = @cInField01  
      SET @cBarcode = @cInField01  
  
      IF ISNULL( @cPalletKey, '') = ''  
      BEGIN  
         SET @nErrNo = 156365  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Pallet ID  
         GOTO Step_ClosePallet_Fail  
      END  
  
      -- Check barcode format  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletKey', @cBarcode) = 0  
      BEGIN  
         SET @nErrNo = 156375  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_ClosePallet_Fail  
      END  
  
      -- Make sure pallet to close belong to login storer  
      IF EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)  
                  WHERE PalletKey = @cPalletKey  
                  AND   StorerKey <> @cStorerKey)  
      BEGIN  
         SET @nErrNo = 156399  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storerkey  
         GOTO Step_ClosePallet_Fail  
      END  
  
      IF @cSortToPalletNotCreateMBOL = '0'  
      BEGIN  
         SET @cMBOLKey = ''  
  
         IF @cScanPalletToLane = '1'  
         BEGIN  
            SELECT @cLane = ISNULL(UserDefine03, '')  
            FROM dbo.PalletDetail PD WITH (NOLOCK)  
            JOIN dbo.Pallet P WITH (NOLOCK) ON P.PalletKey = PD.PalletKey  
            WHERE P.StorerKey = @cStorerKey  
            AND P.PalletKey = @cPalletKey  
            AND P.Status < @cPalletCloseStatus  
  
            SELECT @cMBOLKey = MBOLKey  
            FROM dbo.MBOL WITH (NOLOCK)  
            WHERE ExternMbolKey = @cLane  
            AND   [Status] = '0'  
         END  
         ELSE  
         BEGIN  
            SELECT @cMBOLKey = MBOLKey  
            FROM dbo.MBOL WITH (NOLOCK)  
            WHERE ExternMbolKey = @cPalletKey  
            AND   [Status] = '0'  
         END  
  
         IF ISNULL( @cMBOLKey, '') = ''  
         BEGIN  
            SET @nErrNo = 156366  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Pallet ID  
            GOTO Step_ClosePallet_Fail  
         END  
      END  
  
      IF @cChkPalletOrdStatus <> '0'  
      BEGIN  
         IF EXISTS ( SELECT 1  
                     FROM dbo.ORDERS WITH (NOLOCK)  
                     WHERE OrderKey IN ( SELECT DISTINCT UserDefine01  
                                         FROM dbo.PalletDetail WITH (NOLOCK)  
                                         WHERE PalletKey = @cPalletKey  
                                         AND   StorerKey = @cStorerKey  
                                         AND   [Status] < '9')  
                     AND   StorerKey = @cStorerKey  
                     AND   [Status] < @cChkPalletOrdStatus)  
         BEGIN  
            SET @nErrNo = 189802  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Ord Status  
        GOTO Step_ClosePallet_Fail  
         END  
      END  
  
      IF @cCapturePackInfoSP <> ''  
      BEGIN  
     IF EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cCapturePackInfoSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, ' +  
               ' @cWeight OUTPUT, @cLength OUTPUT, @cWidth OUTPUT, @cHeight OUTPUT, @cCapturePackInfo OUTPUT, @tCapturePackInfo, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               '@nMobile            INT,           ' +  
               '@nFunc              INT,           ' +  
               '@cLangCode          NVARCHAR( 3),  ' +  
               '@nStep              INT,           ' +  
               '@nInputKey          INT,           ' +  
               '@cFacility          NVARCHAR( 5),  ' +  
               '@cStorerkey         NVARCHAR( 15), ' +  
               '@cTrackNo           NVARCHAR( 40), ' +  
               '@cOrderKey          NVARCHAR( 10), ' +  
               '@cPalletKey         NVARCHAR( 20), ' +  
               '@cMBOLKey           NVARCHAR( 10), ' +  
               '@cWeight            NVARCHAR( 10) OUTPUT, ' +  
               '@cLength            NVARCHAR( 10) OUTPUT, ' +  
               '@cWidth             NVARCHAR( 10) OUTPUT, ' +  
               '@cHeight            NVARCHAR( 10) OUTPUT, ' +  
               '@cCapturePackInfo   NVARCHAR( 10)  OUTPUT,  ' +  
               '@tCapturePackInfo   VariableTable READONLY, ' +  
               '@nErrNo             INT           OUTPUT,  ' +  
               '@cErrMsg            NVARCHAR( 20) OUTPUT   '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey,  
                  @cWeight OUTPUT, @cLength OUTPUT, @cWidth OUTPUT, @cHeight OUTPUT, @cCapturePackInfo OUTPUT, @tCapturePackInfo,  
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_ClosePallet_Fail  
            ELSE  
             SET @cPackInfo = @cCapturePackInfo  
         END  
         ELSE  
         BEGIN  
            SET @cPackInfo = @cCapturePackInfoSP  
         END  
      END  
      ELSE  
      BEGIN  
         SET @cPackInfo = ''  
      END  
  
      -- Capture pack info  
      IF @cPackInfo <> ''  
      BEGIN  
         -- Prepare LOC screen var  
         SET @cOutField01 = @cPalletKey  
         SET @cOutField02 = @cWeight  
         SET @cOutField03 = @cLength  
         SET @cOutField04 = @cWidth  
         SET @cOutField05 = @cHeight  
  
         -- Enable disable field  
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END  
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'L', @cPackInfo) = 0 THEN 'O' ELSE '' END  
         SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'D', @cPackInfo) = 0 THEN 'O' ELSE '' END  
         SET @cFieldAttr05 = CASE WHEN CHARINDEX( 'H', @cPackInfo) = 0 THEN 'O' ELSE '' END  
  
         -- Position cursor  
         IF @cFieldAttr02 = '' AND @cOutField02 <> '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE  
         IF @cFieldAttr03 = '' AND @cOutField03 <> '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE  
         IF @cFieldAttr04 = '' AND @cOutField04 <> '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE  
         IF @cFieldAttr05 = '' AND @cOutField05 <> '' EXEC rdt.rdtSetFocusField @nMobile, 5  
  
         -- Go to next screen  
         SET @nScn = @nScn_PalletDimension  
         SET @nStep = @nStep_PalletDimension  
      END  
      ELSE  
      BEGIN  
         SET @nTranCount = @@TRANCOUNT  
         BEGIN TRAN  -- Begin our own transaction  
         SAVE TRAN rdt_UpdatePltDim -- For rollback or commit only our own transaction  
         SET @nErrNo = 0  
  
         UPDATE dbo.PalletDetail SET  
            [Status] = @cPltDetailCloseStatus,
            EditDate = GETDATE(),  
            EditWho = SUSER_SNAME()  
       WHERE PalletKey = @cPalletKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 156369  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close PltD Err  
            GOTO RollBackTran_UpdatePltDim  
         END  
  
         UPDATE dbo.Pallet SET  
            [Status] = @cPalletCloseStatus,  
            EditDate = GETDATE(),  
            EditWho = SUSER_SNAME()  
         WHERE PalletKey = @cPalletKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 156370  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Plt Err  
            GOTO RollBackTran_UpdatePltDim  
         END  
  
         -- Extended update  
         IF @cExtendedUpdateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
                  ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar, ' +  
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
               SET @cSQLParam =  
                  ' @nMobile        INT,           ' +  
                  ' @nFunc          INT,           ' +  
                  ' @cLangCode      NVARCHAR( 3),  ' +  
                  ' @nStep          INT,           ' +  
                  ' @nInputKey      INT,           ' +  
                  ' @cFacility      NVARCHAR( 5),  ' +  
                  ' @cStorerKey     NVARCHAR( 15), ' +  
                  ' @cTrackNo       NVARCHAR( 40), ' +  
                  ' @cOrderKey      NVARCHAR( 20),'  +  
                  ' @cPalletKey     NVARCHAR( 20), ' +  
                  ' @cMBOLKey       NVARCHAR( 10), ' +  
                  ' @cLane          NVARCHAR( 30), ' +  
                  ' @tExtUpdateVar  VariableTable READONLY, ' +  
                  ' @nErrNo         INT           OUTPUT, ' +  
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
                  @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar,  
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
               IF @nErrNo <> 0  
                  GOTO RollBackTran_UpdatePltDim  
            END  
         END  
  
         COMMIT TRAN rdt_UpdatePltDim  
  
         GOTO Quit_UpdatePltDim  
  
         RollBackTran_UpdatePltDim:  
            ROLLBACK TRAN rdt_UpdatePltDim -- Only rollback change made here  
         Quit_UpdatePltDim:  
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
               COMMIT TRAN  
  
         IF @nErrNo <> 0  
            GOTO Step_ClosePallet_Fail  
  
         -- Prep next screen var  
         SET @cOutField01 = '' -- Track No  
         SET @cOutField02 = '' -- Option  
  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
  
         SET @nScn = @nScn_TrackNo  
         SET @nStep = @nStep_TrackNo  
      END  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Initialize value  
      SET @cTrackNo = ''  
      SET @cOrderKey = ''  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = '' -- Option  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   -- Extended info  
   IF @cExtendedInfoSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
            ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT'  
  
         SET @cSQLParam =  
            ' @nMobile        INT,           ' +  
            ' @nFunc          INT,           ' +  
            ' @cLangCode      NVARCHAR( 3),  ' +  
            ' @nStep          INT,           ' +  
            ' @nAfterStep     INT,           ' +  
            ' @nInputKey      INT,           ' +  
            ' @cFacility      NVARCHAR( 5),  ' +  
            ' @cStorerKey     NVARCHAR( 15), ' +  
            ' @cTrackNo       NVARCHAR( 40), ' +  
            ' @cOrderKey      NVARCHAR( 20),'  +  
            ' @cPalletKey     NVARCHAR( 20), ' +  
            ' @cMBOLKey       NVARCHAR( 10), ' +  
            ' @cLane          NVARCHAR( 30), ' +  
            ' @tExtInfoVar    VariableTable READONLY, ' +  
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep_ClosePallet, @nStep, @nInputKey, @cFacility, @cStorerKey,  
            @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT  
  
         IF @cExtendedInfo <> ''  
            SET @cOutField15 = @cExtendedInfo  
      END  
   END  
  
   GOTO Quit  
  
   Step_ClosePallet_Fail:  
   BEGIN  
      SET @cPalletKey = ''  
      SET @cOutField01 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 5. Scn = 5804.  
   SUGGESTED PALLET ID  (field01)  
   SCANNED PALLET ID    (field02)  
   OPTION               (field03, input)  
********************************************************************************/  
Step_ScanDiffPallet:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField03  
  
      -- Validate blank  
      IF @cOption = ''  
      BEGIN  
         SET @nErrNo = 156376  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required  
         GOTO Step_ScanDiffPallet_Fail  
      END  
  
      -- Validate option  
      IF @cOption NOT IN ( '1', '2')  
      BEGIN  
         SET @nErrNo = 156377  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         GOTO Step_ScanDiffPallet_Fail  
      END  
  
      SET @cPallet_Status= ''  
      SELECT @cPallet_Status = [Status]  
      FROM dbo.Pallet WITH (NOLOCK)  
      WHERE PalletKey = @cPalletKey  
      AND   StorerKey = @cStorerKey  
  
      IF @@ROWCOUNT > 0  
      BEGIN  
         IF @cPallet_Status = @cPalletCloseStatus AND @cNotAllowReusePalletKey = '1'  
         BEGIN  
            SET @nErrNo = 189814  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet In Use  
            GOTO Step_ScanDiffPallet_Fail  
         END  
      END  
  
      -- Check if user is scanning tracking no onto different storer  
      SET @cChk_StorerKey = ''  
      SELECT TOP 1 @cChk_StorerKey = StorerKey  
      FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE LabelNo = @cLabelNo  
      ORDER BY 1  
  
      IF @cChk_StorerKey <> ''  
      BEGIN  
       SET @cPlt_StorerKey = ''  
         SELECT TOP 1 @cPlt_StorerKey = StorerKey  
         FROM dbo.PALLETDETAIL WITH (NOLOCK)  
         WHERE PalletKey = @cPalletKey  
         ORDER BY 1  
  
         IF @@ROWCOUNT > 0 AND ( @cChk_StorerKey <> @cPlt_StorerKey)  
         BEGIN  
            SET @nErrNo = 189815  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff StorerKey  
            GOTO Step_ScanDiffPallet_Fail  
         END  
      END  
  
      IF @cOption = '2'  
      BEGIN  
         -- Prep next screen var  
         SET @cOutField01 = '' -- Track No  
         SET @cOutField02 = '' -- Option  
  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         SET @nScn = @nScn_TrackNo  
         SET @nStep = @nStep_TrackNo  
         GOTO QUIT  
      END  
  
      IF @cPalletNotAllowMixShipperKey = '1'  
      BEGIN  
         -- Get shipperkey from newly scanned orderkey (tracking no)  
  SELECT @cNew_ShipperKey = ShipperKey  
         FROM dbo.ORDERS WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
  
         -- Get orderkey from existing pallet  
         SELECT TOP 1 @cCur_OrderKey = UserDefine01  
         FROM dbo.PALLETDETAIL WITH (NOLOCK)  
         WHERE PalletKey = @cPalletKey  
         AND   StorerKey = @cStorerKey  
         AND   [Status] = '0'  
         ORDER BY 1  
  
         IF @@ROWCOUNT = 1  
         BEGIN  
            -- Get shipperkey from orders on existing pallet  
            SELECT @cCur_ShipperKey = ShipperKey  
            FROM dbo.ORDERS WITH (NOLOCK)  
            WHERE OrderKey = @cCur_OrderKey  
  
            -- Validate if same shipperkey  
            IF @cCur_ShipperKey <> @cNew_ShipperKey  
            BEGIN  
               SET @nErrNo = 156378  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltDiffShipper  
               GOTO Step_ScanDiffPallet_Fail  
            END  
         END  
      END  
  
      IF @cScanPalletToLane = '1'  
      BEGIN  
         -- Check if pallet is already another to another lane  
         IF EXISTS ( SELECT 1  
                     FROM dbo.PalletDetail PD WITH (NOLOCK)  
                     JOIN dbo.PALLET P WITH (NOLOCK) ON ( PD.PalletKey = P.PalletKey)  
                     WHERE P.StorerKey = @cStorerKey  
                     AND   P.PalletKey = @cPalletKey  -- Scanned pallet ID  
                     AND   P.Status < @cPalletCloseStatus  
                     AND   PD.UserDefine03 <> @cLane) -- Scanned lane  
         BEGIN  
            SET @nErrNo = 189816  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltInOtherLane  
            GOTO Step_ScanDiffPallet_Fail  
         END  
  
         IF EXISTS ( SELECT 1  
                     FROM dbo.MBOL WITH (NOLOCK)  
                     WHERE ExternMBOLKey = @cLane  
                     AND   [STATUS] < '5'  
                     AND   ISNULL(UserDefine05, '') <> '')      -- Lane already split  
                     AND NOT EXISTS (                           --WC01  
                                 SELECT 1 FROM dbo.Codelkup CL WITH (NOLOCK)    
                                 JOIN dbo.Orders O WITH (NOLOCK) ON O.Type = CL.Code2 AND O.StorerKey = CL.StorerKey     
                                 WHERE O.OrderKey = @cOrderKey    
                                 AND CL.ListName = 'LANECONFIG'    
                                 AND CL.Code = 'SPLNEXCLORD'    
                                 AND O.StorerKey = @cStorerKey    
                                 AND CL.Short = '1')     
         BEGIN  
            SET @nIsChildLane = 0  
            SELECT @nIsChildLane = 1  
            FROM dbo.MBOL M WITH (NOLOCK)  
            JOIN dbo.Orders O WITH (NOLOCK) ON ( O.MBOLKey = M.MBOLKey)  
            WHERE O.StorerKey = @cStorerKey  
            AND   M.ExternMBOLKey = @cLane  
            AND   CHARINDEX('|', M.ExternMBOLKey) > 1   -- Duplicated lane  
  
            IF @nIsChildLane = 1  
            BEGIN  
               SET @nErrNo = 189821  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LaneAlrdSplit  
               GOTO Step_ScanDiffPallet_Fail  
            END  
  
            SET @nIsOriginalLane = 0  
            SELECT @nIsOriginalLane = 1  
            FROM dbo.MBOL M WITH (NOLOCK)  
            JOIN dbo.Orders O WITH (NOLOCK) ON ( O.MBOLKey = M.MBOLKey)  
            WHERE O.StorerKey = @cStorerKey  
            AND   O.OrderKey = @cOrderKey  
            AND   M.ExternMBOLKey = @cLane  
  
            IF @nIsOriginalLane = 1  
            BEGIN  
               SET @nErrNo = 189822  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LaneAlrdSplit  
               GOTO Step_ScanDiffPallet_Fail  
            END  
         END  
      END  
  
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey    NVARCHAR( 15), ' +  
               ' @cTrackNo       NVARCHAR( 40), ' +  
               ' @cOrderKey      NVARCHAR( 20),' +  
               ' @cPalletKey     NVARCHAR( 20), ' +  
               ' @cMBOLKey       NVARCHAR( 10), ' +  
               ' @cLane          NVARCHAR( 30), ' +  
               ' @tExtValidVar   VariableTable READONLY, ' +  
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_ScanDiffPallet_Fail  
         END  
      END  
  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdt_CreateMbol -- For rollback or commit only our own transaction  
  
      SET @nErrNo = 0  
      EXEC [RDT].[rdt_TrackNo_SortToPallet_CreateMbol]  
         @nMobile       = @nMobile,  
         @nFunc         = @nFunc,  
         @cLangCode     = @cLangCode,  
         @nStep         = @nStep,  
         @nInputKey     = @nInputKey,  
         @cFacility     = @cFacility,  
         @cStorerKey    = @cStorerKey,  
         @cTrackNo      = @cTrackNo,  
         @cOrderKey     = @cOrderKey,  
         @cPalletKey    = @cPalletKey,  
         @cMBOLKey      = @cMBOLKey,  
         @cLane         = @cLane,  
         @cLabelNo      = @cLabelNo,  
         @tCreateMBOLVar= @tCreateMBOLVar,  
         @nErrNo        = @nErrNo      OUTPUT,  
         @cErrMsg       = @cErrMsg     OUTPUT  
  
      IF @nErrNo <> 0  
         GOTO RollBack_CreateMbol  
  
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @cTrackNo       NVARCHAR( 40), ' +  
               ' @cOrderKey      NVARCHAR( 20),'  +  
               ' @cPalletKey     NVARCHAR( 20), ' +  
               ' @cMBOLKey       NVARCHAR( 10), ' +  
               ' @cLane          NVARCHAR( 30), ' +  
               ' @tExtUpdateVar  VariableTable READONLY, ' +  
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO RollBack_CreateMbol  
         END  
      END  
  
      COMMIT TRAN rdt_CreateMbol  
  
      GOTO Commit_CreateMbol  
  
      RollBack_CreateMbol:  
         ROLLBACK TRAN rdt_CreateMbol    -- Only rollback change made here  
      Commit_CreateMbol:  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = '' -- Option  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Initialize value  
      SET @cTrackNo = ''  
      SET @cOrderKey = ''  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = '' -- Option  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   -- Extended info  
   IF @cExtendedInfoSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
            ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT'  
  
         SET @cSQLParam =  
            ' @nMobile        INT,           ' +  
            ' @nFunc          INT,           ' +  
            ' @cLangCode      NVARCHAR( 3),  ' +  
            ' @nStep          INT,           ' +  
            ' @nAfterStep     INT,           ' +  
            ' @nInputKey      INT,           ' +  
            ' @cFacility      NVARCHAR( 5),  ' +  
            ' @cStorerKey     NVARCHAR( 15), ' +  
            ' @cTrackNo       NVARCHAR( 40), ' +  
            ' @cOrderKey      NVARCHAR( 20),'  +  
            ' @cPalletKey     NVARCHAR( 20), ' +  
            ' @cMBOLKey       NVARCHAR( 10), ' +  
            ' @cLane          NVARCHAR( 30), ' +  
            ' @tExtInfoVar    VariableTable READONLY, ' +  
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep_ScanPalletID, @nStep, @nInputKey, @cFacility, @cStorerKey,  
            @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT  
  
         IF @cExtendedInfo <> ''  
            SET @cOutField15 = @cExtendedInfo  
      END  
   END  
  
   GOTO Quit  
  
   Step_ScanDiffPallet_Fail:  
   BEGIN  
      SET @cOption = ''  
      SET @cOutField03 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Scn = 5805. Capture pack info  
   PalletKey   (field01)  
   Weight      (field02, input)  
   Cube        (field03, input)  
   Length      (field04, input)  
   Weight      (field05, input)  
   Height      (field06, input)  
   RefNo       (field07, input)  
********************************************************************************/  
Step_PalletDimension:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cWeight         = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END  
      SET @cLength         = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END  
      SET @cWidth          = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END  
      SET @cHeight         = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END  
  
      -- Weight  
      IF @cFieldAttr02 = ''  
      BEGIN  
         -- Check blank  
         IF @cWeight = ''  
         BEGIN  
            SET @nErrNo = 156386  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Quit  
         END  
  
         -- Check format    --(cc04)  
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Weight', @cWeight) = 0  
         BEGIN  
            SET @nErrNo = 156387  
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
            SET @nErrNo = 156388  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            SET @cOutField02 = ''  
            GOTO QUIT  
         END  
         SET @nErrNo = 0  
         SET @cOutField02 = @cWeight  
      END  
  
      -- Length  
      IF @cFieldAttr03 = ''  
      BEGIN  
         -- Check blank  
         IF @cLength = ''  
         BEGIN  
            SET @nErrNo = 156389  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Length  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            GOTO Quit  
         END  
  
         -- Check cube valid  
         IF @cAllowLengthZero = '1'  
            SET @nErrNo = rdt.rdtIsValidQty( @cLength, 20)  
         ELSE  
            SET @nErrNo = rdt.rdtIsValidQty( @cLength, 21)  
  
         IF @nErrNo = 0  
         BEGIN  
            SET @nErrNo = 156390              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Length  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            SET @cOutField03 = ''  
            GOTO QUIT  
         END  
         SET @nErrNo = 0  
         SET @cOutField03 = @cLength  
      END  
  
      -- Width  
      IF @cFieldAttr04 = ''  
      BEGIN  
         -- Check blank  
         IF @cWidth = ''  
         BEGIN  
            SET @nErrNo = 156391  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Width  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            GOTO Quit  
         END  
  
         -- Check cube valid  
         IF @cAllowWidthZero = '1'  
            SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 20)  
         ELSE  
            SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 21)  
  
         IF @nErrNo = 0  
         BEGIN  
            SET @nErrNo = 156392  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Width  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            SET @cOutField04 = ''  
            GOTO QUIT  
         END  
         SET @nErrNo = 0  
         SET @cOutField04 = @cWidth  
      END  
  
      -- Height  
      IF @cFieldAttr05 = ''  
      BEGIN  
         -- Check blank  
         IF @cHeight = ''  
         BEGIN  
            SET @nErrNo = 156393  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Height  
            EXEC rdt.rdtSetFocusField @nMobile, 5  
            GOTO Quit  
         END  
  
         -- Check cube valid  
         IF @cAllowHeightZero = '1'  
            SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 20)  
         ELSE  
            SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 21)  
  
         IF @nErrNo = 0  
         BEGIN  
            SET @nErrNo = 156394  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Height  
            EXEC rdt.rdtSetFocusField @nMobile, 5  
            SET @cOutField05 = ''  
            GOTO QUIT  
         END  
         SET @nErrNo = 0  
         SET @cOutField05 = @cHeight  
      END  
  
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
          INSERT INTO @tExtValidVar (Variable, Value) VALUES ( '@cWeight',     @cWeight)  
          INSERT INTO @tExtValidVar (Variable, Value) VALUES ( '@cLength',     @cLength)  
          INSERT INTO @tExtValidVar (Variable, Value) VALUES ( '@cWidth',      @cWidth)  
          INSERT INTO @tExtValidVar (Variable, Value) VALUES ( '@cHeight',     @cHeight)  
  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
             ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @cTrackNo       NVARCHAR( 40), ' +  
               ' @cOrderKey      NVARCHAR( 20),'  +  
               ' @cPalletKey     NVARCHAR( 20), ' +  
               ' @cMBOLKey       NVARCHAR( 10), ' +  
               ' @cLane          NVARCHAR( 30), ' +  
               ' @tExtValidVar   VariableTable READONLY, ' +  
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtValidVar,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_PalletDim_Fail  
         END  
      END  
  
      SET @fWeight = ISNULL( CAST( @cWeight AS FLOAT), 0)  
      SET @fLength = ISNULL( CAST( @cLength AS FLOAT), 0)  
      SET @fWidth = ISNULL( CAST( @cWidth AS FLOAT), 0)  
      SET @fHeight = ISNULL( CAST( @cHeight AS FLOAT), 0)  
  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN UpdDimClosePallet -- For rollback or commit only our own transaction  
      SET @nErrNo = 0  
  
      UPDATE dbo.PalletDetail SET  
         [Status] = @cPltDetailCloseStatus, 
         EditDate = GETDATE(),  
         EditWho = SUSER_SNAME()  
      WHERE PalletKey = @cPalletKey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 156395  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close PltD Err  
         GOTO RollBackTran_UpdDimClosePallet  
      END  
  
      UPDATE dbo.Pallet SET  
         GrossWgt = @fWeight,  
         [Length] = @fLength,  
         Width = @fWidth,  
         Height = @fHeight,  
         [Status] = @cPalletCloseStatus,  
         EditDate = GETDATE(),  
         EditWho = SUSER_SNAME()  
      WHERE PalletKey = @cPalletKey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 156396  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Plt Err  
         GOTO RollBackTran_UpdDimClosePallet  
      END  
  
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
          INSERT INTO @tExtValidVar (Variable, Value) VALUES ( '@cWeight',     @cWeight)  
          INSERT INTO @tExtValidVar (Variable, Value) VALUES ( '@cLength',     @cLength)  
          INSERT INTO @tExtValidVar (Variable, Value) VALUES ( '@cWidth',      @cWidth)  
          INSERT INTO @tExtValidVar (Variable, Value) VALUES ( '@cHeight',     @cHeight)  
  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @cTrackNo       NVARCHAR( 40), ' +  
               ' @cOrderKey      NVARCHAR( 20),'  +  
               ' @cPalletKey     NVARCHAR( 20), ' +  
               ' @cMBOLKey       NVARCHAR( 10), ' +  
               ' @cLane          NVARCHAR( 30), ' +  
               ' @tExtUpdateVar  VariableTable READONLY, ' +  
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO RollBackTran_UpdDimClosePallet  
         END  
      END  
  
      COMMIT TRAN UpdDimClosePallet  
  
      GOTO Quit_UpdDimClosePallet  
  
      RollBackTran_UpdDimClosePallet:  
         ROLLBACK TRAN UpdDimClosePallet -- Only rollback change made here  
      Quit_UpdDimClosePallet:  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
  
      IF @nErrNo <> 0  
         GOTO Step_PalletDim_Fail  
  
      -- Enable field  
      SET @cFieldAttr01 = ''  
      SET @cFieldAttr02 = ''  
      SET @cFieldAttr03 = ''  
      SET @cFieldAttr04 = ''  
      SET @cFieldAttr05 = ''  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = '' -- Option  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
    -- Enable field  
    SET @cFieldAttr01 = ''  
    SET @cFieldAttr02 = ''  
    SET @cFieldAttr03 = ''  
    SET @cFieldAttr04 = ''  
    SET @cFieldAttr05 = ''  
  
      -- Initialize value  
      SET @cTrackNo = ''  
      SET @cOrderKey = ''  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = '' -- Option  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   -- Extended info  
   IF @cExtendedInfoSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
            ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT'  
  
         SET @cSQLParam =  
            ' @nMobile        INT,           ' +  
            ' @nFunc          INT,           ' +  
            ' @cLangCode      NVARCHAR( 3),  ' +  
            ' @nStep          INT,           ' +  
            ' @nAfterStep     INT,           ' +  
            ' @nInputKey      INT,           ' +  
            ' @cFacility      NVARCHAR( 5),  ' +  
            ' @cStorerKey     NVARCHAR( 15), ' +  
            ' @cTrackNo       NVARCHAR( 40), ' +  
            ' @cOrderKey      NVARCHAR( 20),'  +  
            ' @cPalletKey     NVARCHAR( 20), ' +  
            ' @cMBOLKey       NVARCHAR( 10), ' +  
            ' @cLane          NVARCHAR( 30), ' +  
            ' @tExtInfoVar    VariableTable READONLY, ' +  
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep_PalletDimension, @nStep, @nInputKey, @cFacility, @cStorerKey,  
            @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT  
  
         IF @cExtendedInfo <> ''  
            SET @cOutField15 = @cExtendedInfo  
      END  
   END  
  
   GOTO Quit  
  
   Step_PalletDim_Fail:  
   BEGIN  
      SET @cOutField02 = CASE WHEN @cFieldAttr02 = '' THEN '' ELSE @cWeight END  
      SET @cOutField03 = CASE WHEN @cFieldAttr03 = '' THEN '' ELSE @cLength END  
      SET @cOutField04 = CASE WHEN @cFieldAttr04 = '' THEN '' ELSE @cWidth END  
      SET @cOutField05 = CASE WHEN @cFieldAttr05 = '' THEN '' ELSE @cHeight END  
  
      -- Position cursor  
      IF @cFieldAttr02 = '' AND @cOutField02 <> '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE  
      IF @cFieldAttr03 = '' AND @cOutField03 <> '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE  
      IF @cFieldAttr04 = '' AND @cOutField04 <> '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE  
      IF @cFieldAttr05 = '' AND @cOutField05 <> '' EXEC rdt.rdtSetFocusField @nMobile, 5  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Scn = 5806. Confirm Scan New Lane  
   Lane        (field01)  
   New Lane    (field02, input)  
********************************************************************************/  
Step_ConfirmNewLane:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cPalletKey = @cOutField01  
      SET @cLane = @cOutField02  
      SET @cNewLane = @cInField03  
  
      IF @cNewLane = ''  
      BEGIN  
         SET @nErrNo = 189811  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lane  
         GOTO Step_ConfirmNewLane_Fail  
      END  
  
      IF @cNewLane <> @cLane  
      BEGIN  
         SET @nErrNo = 189812  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Lane  
         GOTO Step_ConfirmNewLane_Fail  
      END  
  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdt_NewCreateMbol -- For rollback or commit only our own transaction  
  
      SET @nErrNo = 0  
      EXEC [RDT].[rdt_TrackNo_SortToPallet_CreateMbol]  
         @nMobile       = @nMobile,  
         @nFunc         = @nFunc,  
         @cLangCode     = @cLangCode,  
         @nStep         = @nStep,  
         @nInputKey     = @nInputKey,  
         @cFacility     = @cFacility,  
         @cStorerKey    = @cStorerKey,  
         @cTrackNo      = @cTrackNo,  
         @cOrderKey     = @cOrderKey,  
         @cPalletKey    = @cPalletKey,  
         @cMBOLKey      = @cMBOLKey OUTPUT,  
         @cLane         = @cLane,  
         @cLabelNo      = @cLabelNo,  
         @tCreateMBOLVar= @tCreateMBOLVar,  
         @nErrNo        = @nErrNo      OUTPUT,  
         @cErrMsg       = @cErrMsg     OUTPUT  
  
      IF @nErrNo <> 0  
         GOTO RollBackTran_NewCreateMbol  
  
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
            SET @cSQLParam =  
               ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @cTrackNo       NVARCHAR( 40), ' +  
               ' @cOrderKey      NVARCHAR( 20),'  +  
               ' @cPalletKey     NVARCHAR( 20), ' +  
               ' @cMBOLKey       NVARCHAR( 10), ' +  
               ' @cLane          NVARCHAR( 30), ' +  
               ' @tExtUpdateVar  VariableTable READONLY, ' +  
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtUpdateVar,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO RollBackTran_NewCreateMbol  
         END  
      END  
  
      COMMIT TRAN rdt_NewCreateMbol  
  
      GOTO Quit_NewCreateMbol  
  
      RollBackTran_NewCreateMbol:  
         ROLLBACK TRAN rdt_NewCreateMbol    -- Only rollback change made here  
      Quit_NewCreateMbol:  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      -- Prep next screen var  
      SET @cOutField01 = '' -- Track No  
      SET @cOutField02 = '' -- Option  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      SET @cFieldAttr04 = ''  
  
      SET @nScn = @nScn_TrackNo  
      SET @nStep = @nStep_TrackNo  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      SET @cPalletKey = ''  
      SET @cLane = ''  
      SET @nPalletValidated = 0  
  
      -- Prep next screen var  
      SET @cOutField01 = @cTrackNo  
      SET @cOutField02 = @cOrderKey  
      SET @cOutField03 = ''   -- PalletKey  
  
      IF @cScanPalletToLane = '1'  
      BEGIN  
         SET @cOutField04 = ''   -- Lane  
         SET @cFieldAttr04 = ''  
      END  
      ELSE  
         SET @cFieldAttr04 = 'O'  
  
      -- Goto scan pallet screen  
      SET @nScn  = @nScn_ScanPalletID  
      SET @nStep = @nStep_ScanPalletID  
  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- PalletKey  
   END  
  
   -- Extended info  
   IF @cExtendedInfoSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
            ' @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT'  
  
         SET @cSQLParam =  
            ' @nMobile        INT,           ' +  
            ' @nFunc          INT,           ' +  
            ' @cLangCode      NVARCHAR( 3),  ' +  
            ' @nStep          INT,           ' +  
            ' @nAfterStep     INT,           ' +  
            ' @nInputKey      INT,           ' +  
            ' @cFacility      NVARCHAR( 5),  ' +  
            ' @cStorerKey     NVARCHAR( 15), ' +  
            ' @cTrackNo       NVARCHAR( 40), ' +  
            ' @cOrderKey      NVARCHAR( 20),'  +  
            ' @cPalletKey     NVARCHAR( 20), ' +  
            ' @cMBOLKey       NVARCHAR( 10), ' +  
            ' @cLane          NVARCHAR( 30), ' +  
            ' @tExtInfoVar    VariableTable READONLY, ' +  
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep_ScanPalletID, @nStep, @nInputKey, @cFacility, @cStorerKey,  
            @cTrackNo, @cOrderKey, @cPalletKey, @cMBOLKey, @cLane, @tExtInfoVar, @cExtendedInfo OUTPUT  
  
         IF @cExtendedInfo <> ''  
            SET @cOutField15 = @cExtendedInfo  
      END  
   END  
  
   GOTO Quit  
  
   Step_ConfirmNewLane_Fail:  
   BEGIN  
      SET @cNewLane = ''  
      SET @cOutField01 = @cPalletKey  
      SET @cOutField02 = @cLane  
      SET @cOutField03 = ''  
   END  
END  
GOTO Quit  

/********************************************************************************
Scn = 5807. SCAN TO LOC/LANE
   TRACK NO          (field01)
   ORDERKEY          (field02)
   SCAN PALLET:      (field03)
   SCAN TO PALLET:   (field04, input)
   LOC/LANE:         (field05, input)
********************************************************************************/

Step_ExtScn:
BEGIN
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN

         DELETE FROM @tExtScnData
         INSERT INTO @tExtScnData (Variable, Value) VALUES
             ('@cPalletKey',     @cPalletKey),
             ('@cLane',          @cLane),
             ('@cLabelNo',       @cLabelNo)

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
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET  
      EditDate = GETDATE(),  
      ErrMsg = @cErrMsg,  
      Func   = @nFunc,  
      Step   = @nStep,  
      Scn    = @nScn,  
  
      StorerKey = @cStorerKey,  
      Facility  = @cFacility,  
      UserName  = @cUserName,  
      V_OrderKey= @cOrderKey,  
  
      V_Integer1  = @nPalletValidated,  
  
      V_String1   = @cLabelNo,  
      V_String2   = @cPalletKey,  
      V_String3   = @cMBOLKey,  
      V_String4   = @cPalletCloseStatus,  
      V_String5   = @cSuggPalletKey,  
      V_String6   = @cAllowScanToDiffPallet,  
      V_String7   = @cCapturePackInfoSP,  
      V_String8   = @cChkPalletOrdStatus,  
      V_String9   = @cPltDetailCloseStatus,
  
      V_String20 = @cDecodeSP,  
      V_String21 = @cExtendedInfoSP,  
      V_String22 = @cExtendedValidateSP,  
      V_String23 = @cExtendedUpdateSP,  
      V_String24 = @cPalletNotAllowMixShipperKey,  
      V_String25 = @cSortToPalletNotCreateMBOL,  
      V_String26 = @cNotAllowReusePalletKey,  
      V_String27 = @cScanPalletToLane,  
      V_String28 = @cExtendedScreenSP,
      V_String29 = @cSuggestLoc,
      V_String30 = @cOverrideLoc,

      V_String41 = @cTrackNo,  
      V_String42 = @cLane,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01, FieldAttr01  = @cFieldAttr01,  
      I_Field02 = @cInField02,  O_Field02 = @cOutField02, FieldAttr02  = @cFieldAttr02,  
      I_Field03 = @cInField03,  O_Field03 = @cOutField03, FieldAttr03  = @cFieldAttr03,  
      I_Field04 = @cInField04,  O_Field04 = @cOutField04, FieldAttr04  = @cFieldAttr04,  
      I_Field05 = @cInField05,  O_Field05 = @cOutField05, FieldAttr05  = @cFieldAttr05,  
      I_Field06 = @cInField06,  O_Field06 = @cOutField06, FieldAttr06  = @cFieldAttr06,  
      I_Field07 = @cInField07,  O_Field07 = @cOutField07, FieldAttr07  = @cFieldAttr07,  
      I_Field08 = @cInField08,  O_Field08 = @cOutField08, FieldAttr08  = @cFieldAttr08,  
      I_Field09 = @cInField09,  O_Field09 = @cOutField09, FieldAttr09  = @cFieldAttr09,  
      I_Field10 = @cInField10,  O_Field10 = @cOutField10, FieldAttr10  = @cFieldAttr10,  
      I_Field11 = @cInField11,  O_Field11 = @cOutField11, FieldAttr11  = @cFieldAttr11,  
      I_Field12 = @cInField12,  O_Field12 = @cOutField12, FieldAttr12  = @cFieldAttr12,  
      I_Field13 = @cInField13,  O_Field13 = @cOutField13, FieldAttr13  = @cFieldAttr13,  
      I_Field14 = @cInField14,  O_Field14 = @cOutField14, FieldAttr14  = @cFieldAttr14,  
      I_Field15 = @cInField15,  O_Field15 = @cOutField15, FieldAttr15  = @cFieldAttr15  
   WHERE Mobile = @nMobile  
END  

GO