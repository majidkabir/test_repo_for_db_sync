SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/  
/* Store procedure: rdtfnc_Scan_To_Container                                 */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#152430                                                       */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2009-10-27 1.0  Vicky    Created                                          */  
/* 2010-03-11 1.1  James    SOS163594 - Define the func no to allow different*/  
/*                          screen processing (james01)                      */  
/* 2012-06-12 1.2  James    SOS246728 - Customization for Zara (james02)     */  
/* 2012-08-23 1.3  James    Bug fix (james03)                                */  
/* 2012-08-28 1.4  James    Handle multi SSCC per container (james04)        */  
/* 2016-02-02 1.5  Ung      SOS362689 Add VerifyPallet                       */  
/* 2016-03-18 1.6  James    SOS365910 - Store mbolkey into container.mbolkey */  
/*                          instead of container.otherreference (james05)    */    
/* 2016-05-26 1.7  James    Add Container No and Close Container (james06)   */  
/* 2016-09-30 1.8  Ung      Performance tuning                               */  
/* 2017-06-22 1.9  Ung      WMS-2017 Add CloseContainerStatus                */  
/*                          Add DefaultContainerType                         */  
/* 2017-10-02 2.0  Ung      WMS-3128 Fix PalletKey to 30 chars               */  
/* 2017-11-01 2.1  Ung      WMS-3329 Add ContainerManifest                   */  
/* 2018-04-23 2.2  James    WMS-4673 Add new function id to allow pallet to  */  
/*                          be verify 2nd time (james07)                     */  
/* 2018-06-20 2.3  James    WMS-5460-Allow container no. to be filtered by   */  
/*                          customizable field (james08)                     */  
/* 2017-09-21 2.4  James    WMS2990-Add custom userdefine fields (james09)   */  
/* 2018-07-20 2.5  James    WMS4673-Fix for pallet scanned display for       */  
/*                          2nd time pallet verify  (james10)                */  
/* 2018-09-25 2.6  TungGH   Perfomance tuning. Remove isvalidqty during      */  
/*                          loading rdtmobrec                                */  
/* 2019-06-17 2.7  Shong    Capture Edidate for nCounter                     */  
/* 2018-11-13 2.8  Gan      Performance tuning                               */
/* 2019-10-01 2.9  James    WMS-10651 Add extupdsp @close container (james11)*/
/* 2020-01-17 3.0  Chermaine WMS-11844 Add eventLog (cc01)                   */
/* 2020-01-23 3.1  YeeKung  WMS-11663 Add Verifypalletstatus (yeekung02)     */
/* 2020-10-01 3.2  Chermaine WMS-15384 Add print Delivery List (cc02)        */
/* 2021-03-08 3.3  James    WMS16476-Add CaptureContainerInfoSP (james12)    */
/* 2021-04-16 3.4  James     WMS-16024 Standarized use of TrackingNo(james13)*/
/* 2020-03-09 3.5  YeeKung  WMS-12381 Add RDTFormat step_8   (yeekung03)     */     
/* 2020-04-24 3.6  YeeKung  WMS-13025 Add popup Message (yeekung04)          */ 
/* 2020-07-08 3.7  YeeKung  WMS-13899 Add PalletLbl print (yeekung05)        */   
/* 2022-11-29 3.8  YeeKung  JSM-103586 Fix Count @cTotalCTNCnt by labelno    */
/*                          Instead by CartonNo (yeekung06)                  */
/* 2024-08-15 3.9 NLT013    FCR-673 Add Extended Screen                      */
/*****************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_Scan_To_Container](  
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
   @b_success           INT  
  
-- Define a variable  
DECLARE  
   @nFunc               INT,  
   @nScn                INT,  
   @nStep               INT,  
   @cLangCode           NVARCHAR(3),  
   @nMenu               INT,  
   @nInputKey           NVARCHAR(3),  
   @cLabelPrinter       NVARCHAR(10),  
   @cPaperPrinter       NVARCHAR(10),  
   @cUserName           NVARCHAR(18),  
  
   @cStorerKey          NVARCHAR(15),  
   @cFacility           NVARCHAR(5),  
  
   @cContainerKey       NVARCHAR(10),  
   @cMBOLKey            NVARCHAR(10),  
   @cContainerNo        NVARCHAR(20),  
   @cSSCCNo             NVARCHAR(20),  
   @cScanCnt            NVARCHAR(5),  
   @cScanCTNCnt         NVARCHAR(5),  
   @cTotalCTNCnt        NVARCHAR(5),  
   @cVerifyPallet       NVARCHAR(1),  
   @cPalletKey          NVARCHAR(30), -- (james01)  
   @c_NewKey            NVARCHAR(20), -- (james02)  
   @c_ErrMsg            NVARCHAR(20), -- (james02)  
   @cConsigneeKey       NVARCHAR(15), -- (james02)  
   @cTempBarcode        NVARCHAR(20), -- (james02)  
   @cTrackNo            NVARCHAR(20), -- (james02)  
   @cPickSlipNo         NVARCHAR(10), -- (james02)  
   @cShipperKey         NVARCHAR(15), -- (james02)  
   @cOption             NVARCHAR(1),  -- (james02)  
   @cCheckDigit         NVARCHAR(1),  -- (james02)  
   @cSectionKey         NVARCHAR(10), -- (james02)  
   @cOrderKey           NVARCHAR(10), -- (james02)  
   @cPrevSSCCNo         NVARCHAR(20), -- (james02)  
   @cTrackRegExp        NVARCHAR(255),-- (james02)  
  
   @cReportType         NVARCHAR(10), -- (james02)  
   @cPrintJobName       NVARCHAR(50), -- (james02)  
   @cDataWindow         NVARCHAR(50), -- (james02)  
   @cTargetDB           NVARCHAR(20), -- (james02)  
  
   @cKeyName            NVARCHAR(30), -- (james02)  
  	@cShowPopOutMsg      NVARCHAR( 1), -- (yeekung01)     
  
   @nScanCnt            INT,  
   @nScanCTNCnt         INT,  
   @nTotalCTNCnt        INT,  
   @nTranCount          INT,     -- (james02)  
   @n_ErrNo             INT,     -- (james02)  
  
   @cExtendedUpdateSP   NVARCHAR( 20),       -- (james05)  
   @cExtendedValidateSP NVARCHAR( 20),       -- (james05)  
   @cExtendedScnSP      NVARCHAR( 20),
   @cSQL                NVARCHAR(1000),      -- (james05)  
   @cSQLParam           NVARCHAR(1000),      -- (james05)  
  
   @cMbolNotFromOtherReference   NVARCHAR( 1),  -- (james05)  
   @cCloseContainerStatus        NVARCHAR( 1),  
   @cDefaultContainerType        NVARCHAR( 10),   
   @cContainerManifest           NVARCHAR( 20),   
   @cExtendedInfoSP     NVARCHAR( 20),          -- (james06)  
   @cExtendedInfo1      NVARCHAR( 20),          -- (james06)  
   @c_oFieled01         NVARCHAR( 20),          -- (james06)  
   @cColumnName         NVARCHAR( 20), -- (james08)  
   @cDataType           NVARCHAR(128), -- (james08)  
   @n_Err               INT,  -- (james08)  
   @nRowCount           INT,  -- (james08)  
   @cUDFCriteria        NVARCHAR( 10),          -- (james07)  
   @cAction             NVARCHAR( 10),          -- (james07)  
   @nPrevScn            INT,  
   @nPrevStep           INT,
	@cVerifypalletstatus NVARCHAR( 10),      --(yeekung01)  
	@cDelList            NVARCHAR( 20),       --(cc02)  
	@cPalletKeyPrev      NVARCHAR(30),        --(cc02) 
   @cData1              NVARCHAR(60),        --(james12) 
   @cData2              NVARCHAR(60),        --(james12) 
   @cData3              NVARCHAR(60),        --(james12) 
   @cData4              NVARCHAR(60),        --(james12) 
   @cData5              NVARCHAR(60),        --(james12) 
   @cCaptureContainerInfoSP      NVARCHAR( 20),    --(james12)
   @cContainerNoIsOptional       NVARCHAR( 1),     --(james12) 
   @tCaptureVar         VARIABLETABLE,
   @cPalletLabel        NVARCHAR( 10),      --(yeekung05)  
   @tExtScnData         VariableTable,
   @nExtScnAction       INT,
   
   @cParam1    NVARCHAR( 20),   @cParamLabel1 NVARCHAR( 20),  
   @cParam2    NVARCHAR( 20),   @cParamLabel2 NVARCHAR( 20),  
   @cParam3    NVARCHAR( 20),   @cParamLabel3 NVARCHAR( 20),  
   @cParam4    NVARCHAR( 20),   @cParamLabel4 NVARCHAR( 20),  
   @cParam5    NVARCHAR( 20),   @cParamLabel5 NVARCHAR( 20),  
  
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

   @cLottable01     NVARCHAR( 18),
   @cLottable02     NVARCHAR( 18),
   @cLottable03     NVARCHAR( 18),
   @dLottable04     DATETIME,
   @dLottable05     DATETIME,
   @cLottable06     NVARCHAR( 30),
   @cLottable07     NVARCHAR( 30),
   @cLottable08     NVARCHAR( 30),
   @cLottable09     NVARCHAR( 30),
   @cLottable10     NVARCHAR( 30),
   @cLottable11     NVARCHAR( 30),
   @cLottable12     NVARCHAR( 30),
   @dLottable13     DATETIME,
   @dLottable14     DATETIME,
   @dLottable15     DATETIME,

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
   @cLangCode        = Lang_code,  
   @nMenu            = Menu,  
  
   @cFacility        = Facility,  
   @cStorerKey       = StorerKey,  
   @cLabelPrinter    = Printer,  
   @cPaperPrinter    = Printer_Paper,  
   @cUserName        = UserName,  
  
   @cContainerKey    = V_String1,  
   @cMBOLKey         = V_String2,  
   @cContainerNo     = V_String3,  
   @cSSCCNo          = V_String4,  
   @cScanCnt         = V_String5,  
   @cScanCTNCnt      = V_String6,  
   @cTotalCTNCnt     = V_String7,  
   @cVerifyPallet    = V_String8,  
  
   @cMbolNotFromOtherReference = V_String9,  
   @cCloseContainerStatus      = V_String10,  
   @cDefaultContainerType      = V_String11,  
   @cContainerManifest         = V_String12,  
   @cColumnName                = V_String13,  
   @cParam1          = V_String14,  
   @cParam2          = V_String15,  
   @cParam3          = V_String16,  
   @cParam4          = V_String17,  
   @cParam5          = V_String18,  
   @cParamLabel1     = V_String19,  
   @cParamLabel2     = V_String20,  
   @cParamLabel3     = V_String21,  
   @cParamLabel4     = V_String22,  
   @cParamLabel5     = V_String23,  
   @cUDFCriteria     = V_String24,  
   @cCaptureContainerInfoSP = V_String25,
   @cContainerNoIsOptional  = V_String26,
   @cAction          = V_String27,  
 	@cVerifypalletstatus = V_String28, 
 	@cDelList         = V_String29,  --(cc02)
 	@cShowPopOutMsg   = V_String30,
   @cPalletLabel     = V_String31,
 	@cPalletKeyPrev   = V_String41,  --(cc02)
   @cData1           = V_String42,
   @cData2           = V_String43,
   @cData3           = V_String44,
   @cData4           = V_String45,
   @cData5           = V_String46,
   @nPrevScn         = V_FromScn,
   @nPrevStep        = V_FromStep,

  
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
IF @nFunc IN (1636, 1637, 1649, 1651)  -- (james01)/(james02)/(james07)  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1636  
   IF @nStep = 1 GOTO Step_1   -- Scn = 2190   CONTAINERKEY  
   IF @nStep = 2 GOTO Step_2   -- Scn = 2191   CONTAINERKEY, MBOL #, CONTAINER #, SSCC  
   IF @nStep = 3 GOTO Step_3   -- Scn = 2192   CONTAINERKEY, MBOL #, CONTAINER #, PalletKey  -- (james01)  
   IF @nStep = 4 GOTO Step_4   -- Scn = 2193   TRACKING NO  -- (james02)  
   IF @nStep = 5 GOTO Step_5   -- Scn = 2194   OPTION       -- (james02)  
   IF @nStep = 6 GOTO Step_6   -- Scn = 2195   CLOSE CONTAINER, OPTION  -- (james06)  
   IF @nStep = 7 GOTO Step_7   -- Scn = 2196   PRINT MANIFEST?  
   IF @nStep = 8 GOTO Step_8   -- Scn = 2197   Userdefine fields  -- (james09)  
   IF @nStep = 9 GOTO Step_9   -- Scn = 2198   Userdefine fields  -- (james12)  
   IF @nStep = 99 GOTO Step_99   -- Extended Screen
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 1634)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Storer config  
   SET @cVerifyPallet = rdt.rdtGetConfig( @nFunc, 'VerifyPallet', @cStorerKey)
   
   SET @cShowPopOutMsg = rdt.rdtGetConfig( @nFunc, 'ShowPopOutMsg', @cStorerKey)    
  
   SET @cVerifypalletstatus = rdt.rdtGetConfig( @nFunc, 'Verifypalletstatus', @cStorerKey)      --(yeekung01)
   
   SET @cDelList = rdt.rdtGetConfig( @nFunc, 'DelList', @cStorerKey)      --(cc02)
        
   -- Set the entry point  
   SET @nScn  = 2190  
   SET @nStep = 1  
  
   -- initialise all variable  
   SET @cContainerKey = ''  
   SET @cMBOLKey = ''  
   SET @cContainerNo = ''  
   SET @cSSCCNo = ''  
   SET @cScanCnt = ''  
   SET @cScanCTNCnt = ''  
   SET @cTotalCTNCnt = ''  
  
   SET @cParam1 = ''  
   SET @cParam2 = ''  
   SET @cParam3 = ''  
   SET @cParam4 = ''  
   SET @cParam5 = ''  
  
   SET @cCloseContainerStatus = rdt.RDTGetConfig( @nFunc, 'CloseContainerStatus', @cStorerKey)  
   IF @cCloseContainerStatus = '0'  
      SET @cCloseContainerStatus = ''        
   SET @cContainerManifest = rdt.RDTGetConfig( @nFunc, 'ContainerManifest', @cStorerKey)  
   IF @cContainerManifest = '0'  
      SET @cContainerManifest = ''  
   SET @cPalletLabel = rdt.rdtGetConfig( @nFunc, 'PalletLbl', @cStorerKey)      --(yeekung05)
   IF @cPalletLabel = '0'        
      SET @cPalletLabel = ''                
  
   SET @cDefaultContainerType = rdt.RDTGetConfig( @nFunc, 'DefaultContainerType', @cStorerKey)  
   IF @cDefaultContainerType = '0'  
      SET @cDefaultContainerType = ''        
   SET @cMbolNotFromOtherReference = rdt.RDTGetConfig( @nFunc, 'MbolNotFromOtherReference', @cStorerKey)  
   IF @cMbolNotFromOtherReference = '0'  
      SET @cMbolNotFromOtherReference = ''        
  
   SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'ContainerNoLookupColumn', @cStorerKey)  
   IF @cColumnName = '0'  
      SET @cColumnName = ''        
  
   SET @cUDFCriteria = rdt.RDTGetConfig( @nFunc, 'UDFCriteria', @cStorerkey)  
   IF @cUDFCriteria IN ('0', '')  
      SET @cUDFCriteria = ''  

   -- (james12)
   SET @cCaptureContainerInfoSP = rdt.RDTGetConfig( @nFunc, 'CaptureContainerInfoSP', @cStorerKey)
   IF @cCaptureContainerInfoSP = '0'
      SET @cCaptureContainerInfoSP = ''

   SET @cContainerNoIsOptional = rdt.RDTGetConfig( @nFunc, 'ContainerNoIsOptional', @cStorerKey)
      
    --event log   -(cc01)  
    EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey
  
   -- Prep next screen var  
   SET @cOutField01 = ''  
   SET @cOutField02 = ''  
   SET @cOutField03 = ''  
   SET @cOutField04 = ''  

   SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScnSP = '0'
      SET @cExtendedScnSP = ''

   IF @cExtendedScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
      BEGIN
         SET @nExtScnAction = 0
         GOTO Step_99
      END
   END
END  
GOTO Quit  
  
/********************************************************************************  
Step 1. screen = 2190  
   CONTAINERKEY (Field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cContainerKey = @cInField01  
      SET @cContainerNo = @cInField02  
  
      -- Check format  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ContainerKey', @cContainerKey) = 0  
      BEGIN  
         SET @nErrNo = 95889  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet  
         GOTO Step_1_Fail  
      END  
  
      IF ISNULL(@cContainerKey, '') = ''  
      BEGIN  
         -- Check if containerkey is allow blank. If it is allow then auto generate a new containerkey (james02)  
         IF rdt.RDTGetConfig( @nFunc, 'ContainerKeyAllowBlank', @cStorerKey) <> '1'  
         BEGIN  
            --When ContainerKey is blank  
            IF @cContainerKey = ''  
            BEGIN  
               SET @nErrNo = 95851  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CONTKEY req  
               GOTO Step_1_Fail  
            END  
         END  
         ELSE  
         BEGIN  
            SET @nTranCount = @@TRANCOUNT  
            BEGIN TRAN  
            SAVE TRAN INS_Container  
  
            SET @c_NewKey = ''  
            EXECUTE nspg_getkey  
            'ContainerKey'  
            , 10  
            , @c_NewKey          OUTPUT  
            , @b_Success         OUTPUT  
            , @n_ErrNo           OUTPUT  
            , @c_ErrMsg          OUTPUT  
  
            IF @b_Success <> 1  
            BEGIN  
               ROLLBACK TRAN INS_Container  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
               SET @nErrNo = 95852  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GETKEY FAILED  
               GOTO Step_1_Fail  
            END  
  
            SET @cContainerKey = @c_NewKey  
  
            -- Insert new container  
            INSERT INTO dbo.Container  
            (ContainerKey, Status, ContainerType) VALUES (@cContainerKey, '0', @cDefaultContainerType)  
  
            IF @@ERROR <> 0  
            BEGIN  
               ROLLBACK TRAN INS_Container  
               WHILE @@TRANCOUNT > @nTranCount  
               COMMIT TRAN  
               SET @nErrNo = 95853  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS CONT FAIL  
               GOTO Step_1_Fail  
            END  
  
            WHILE @@TRANCOUNT > @nTranCount  
               COMMIT TRAN  
         END  
      END  
  
      --ContainerKey Not Exists  
      IF NOT EXISTS (SELECT 1 FROM dbo.CONTAINER WITH (NOLOCK) WHERE ContainerKey = @cContainerKey)  
      BEGIN  
         SET @nErrNo = 95854  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CONTKEY  
         GOTO Step_1_Fail  
      END  
  
      IF (@cVerifypalletstatus='')  --(yeekung01)
      BEGIN  
         --ContainerKey Status > 0      
         IF EXISTS (SELECT 1 FROM dbo.CONTAINER WITH (NOLOCK) WHERE ContainerKey = @cContainerKey AND Status > 0)      
         BEGIN      
            SET @nErrNo = 95855      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CONTKEY Done      
            GOTO Step_1_Fail      
         END    
      END   
  
      IF @cColumnName = ''  
      BEGIN  
         -- (james06)  
         -- Container no optional but need validate when key in  
         IF ISNULL( @cContainerNo, '') <> ''
         BEGIN  
            IF @cContainerNoIsOptional = '0'
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM dbo.Container WITH (NOLOCK)        
                               WHERE ContainerKey = @cContainerKey  
                               AND   BookingReference = @cContainerNo)  
               BEGIN  
                  SET @nErrNo = 95884  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv container#  
                  GOTO Step_1_Fail  
               END  
            END
         END  
  
         -- Retrieve Related Info      (james05)  
         SELECT @cMBOLKEY = CASE WHEN @cMbolNotFromOtherReference = '1'   
                            THEN ISNULL(RTRIM(MBOLKey), '')  
                            ELSE ISNULL(RTRIM(OtherReference), '') END,   
                @cContainerNo = ISNULL(RTRIM(BookingReference), '')        
         FROM dbo.CONTAINER WITH (NOLOCK)        
         WHERE ContainerKey = @cContainerKey        
  
         IF @cMBOLKEY = '' AND rdt.RDTGetConfig( @nFunc, 'ContainerKeyAllowBlank', @cStorerKey) <> '1'  
         BEGIN  
            SET @nErrNo = 95856  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No MBOLKEY  
            GOTO Step_1_Fail  
         END  
         
         -- Reinitiate the value here because user might have entered from screen (james12)
         IF ISNULL( @cContainerNo, '') = ''
            SET @cContainerNo = @cInField02
      END  
      ELSE  
      BEGIN -- (james08)  
         -- Get lookup field data type  
         SET @cDataType = ''  
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'CONTAINER' AND COLUMN_NAME = @cColumnName  
  
         IF @cDataType <> ''  
         BEGIN  
            IF @cDataType = 'nvarchar' SET @n_Err = 1  
  
            -- Check data type  
            IF @n_Err <> 1  
            BEGIN  
               SET @nErrNo = 95897  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Column  
               GOTO Step_1_Fail  
            END  
  
            SET @cSQL =  
               ' SELECT ' +  
                  CASE WHEN @cMbolNotFromOtherReference = '1'   
                     THEN ' @cMBOLKey = MBOLKEY, '  
                     ELSE ' @cMBOLKey = OtherReference, '  
                  END +  
               ' @cContainerNo = ISNULL( ' + @cColumnName + ', '''') ' +   
               ' FROM dbo.Container WITH (NOLOCK) ' +  
               ' WHERE ContainerKey = @cContainerKey ' +  
               ' AND ISNULL( ' + @cColumnName + ', '''') = @cContainerNo ' +   
               ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '  
            SET @cSQLParam =  
               ' @nMobile        INT, ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @cColumnName    NVARCHAR( 20), ' +  
               ' @cContainerKey  NVARCHAR( 10), ' +  
               ' @cMBOLKey       NVARCHAR( 10) OUTPUT, ' +  
               ' @cContainerNo   NVARCHAR( 20) OUTPUT, ' +  
               ' @nRowCount      INT           OUTPUT, ' +  
               ' @nErrNo         INT           OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile,  
               @cFacility,  
               @cStorerKey,  
               @cColumnName,  
               @cContainerKey,  
               @cMBOLKey      OUTPUT,  
               @cContainerNo  OUTPUT,  
               @nRowCount     OUTPUT,  
               @nErrNo        OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_1_Fail  
  
            -- Check RefNo in ASN  
            IF @nRowCount = 0  
            BEGIN  
               SET @nErrNo = 95893  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv container#  
               GOTO Step_1_Fail  
            END  
  
            -- Check RefNo in ASN  
            IF ISNULL( @cMBolKey, '') = '' AND   
               rdt.RDTGetConfig( @nFunc, 'ContainerKeyAllowBlank', @cStorerKey) <> '1'  
            BEGIN  
               SET @nErrNo = 95894  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No MbolKey  
               GOTO Step_1_Fail  
            END  
         END  
         ELSE  
         BEGIN  
            -- Lookup field is SP  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cColumnName AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cColumnName) +  
                  ' @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cContainerKey, @cMBOLKey OUTPUT, @cContainerNo OUTPUT, ' +   
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
               SET @cSQLParam =  
                  '@nMobile         INT,           ' +  
                  '@nFunc           INT,           ' +  
                  '@cLangCode       NVARCHAR( 3),  ' +  
                  '@cFacility       NVARCHAR( 5),  ' +  
                  '@cStorerKey      NVARCHAR( 15), ' +  
                  '@cContainerKey   NVARCHAR( 10), ' +  
                  '@cMBOLKey        NVARCHAR( 10) OUTPUT, ' +  
                  '@cContainerNo    NVARCHAR( 20) OUTPUT, ' +  
                  '@nErrNo          INT           OUTPUT, ' +  
                  '@cErrMsg         NVARCHAR( 20) OUTPUT  '  
     
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cContainerKey, @cMBOLKey OUTPUT, @cContainerNo OUTPUT,   
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
     
               IF @nErrNo <> 0  
                  GOTO Step_1_Fail  
            END              
         END  
      END  
  
      -- (james06)  
      SET @nErrNo = 0  
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
      IF @cExtendedValidateSP NOT IN ('0', '')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,  ' +  
            ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
          
         SET @cSQLParam =  
            '@nMobile                   INT,           ' +  
            '@nFunc                     INT,           ' +  
            '@cLangCode                 NVARCHAR( 3),  ' +  
            '@nStep                     INT,           ' +  
            '@nInputKey                 INT,           ' +  
            '@cStorerkey                NVARCHAR( 15), ' +  
            '@cContainerKey             NVARCHAR( 10), ' +  
            '@cContainerNo              NVARCHAR( 20), ' +  
            '@cMBOLKey                  NVARCHAR( 10), ' +  
            '@cSSCCNo                   NVARCHAR( 20), ' +  
            '@cPalletKey                NVARCHAR( 30), ' +  
            '@cTrackNo                  NVARCHAR( 20), ' +  
            '@cOption                   NVARCHAR( 1), '  +  
            '@nErrNo                    INT           OUTPUT,  ' +  
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '  
          
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,   
               @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT  
          
         IF @nErrNo <> 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            GOTO Step_1_Fail          
         END  
      END  
  
      -- (james09)  
      SELECT  
         @cParamLabel1 = UDF01,  
         @cParamLabel2 = UDF02,  
         @cParamLabel3 = UDF03,  
         @cParamLabel4 = UDF04,  
         @cParamLabel5 = UDF05  
      FROM dbo.CodeLKUP WITH (NOLOCK)  
      WHERE ListName = 'SCAN2TRKUD'  
      AND   Code = @cUDFCriteria  
      AND   StorerKey = @cStorerKey  
      AND   Code2 = @nFunc  
      AND   Short IN ('PRE', 'BOTH')  
  
      IF @@ROWCOUNT > 0  
      BEGIN  
         -- Check pallet criteria setup  
         IF @cParamLabel1 = '' AND  
            @cParamLabel2 = '' AND  
            @cParamLabel3 = '' AND  
            @cParamLabel4 = '' AND  
            @cParamLabel5 = ''  
         BEGIN  
            SET @nErrNo = 95895  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup  
            GOTO Quit  
         END  
  
         -- Enable / disable field  
         SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END  
  
         -- Clear optional in field  
         SET @cInField02 = ''  
         SET @cInField04 = ''  
         SET @cInField06 = ''  
         SET @cInField08 = ''  
         SET @cInField10 = ''  
         SET @cInField11 = ''  
  
         -- Prepare next screen var  
         SET @cOutField01 = @cParamLabel1  
         SET @cOutField02 = ''  
         SET @cOutField03 = @cParamLabel2  
         SET @cOutField04 = ''  
         SET @cOutField05 = @cParamLabel3  
         SET @cOutField06 = ''  
         SET @cOutField07 = @cParamLabel4  
         SET @cOutField08 = ''  
         SET @cOutField09 = @cParamLabel5  
         SET @cOutField10 = ''  
         SET @cOutField11 = ''  
  
         SET @cAction = 'PRE'  
  
         SET @nPrevScn = @nScn  
         SET @nPrevStep = @nStep  
  
         SET @nScn = @nScn + 7  
         SET @nStep = @nStep + 7  
  
         GOTO Quit  
      END  

      -- Capture ASN Info
      IF @cCaptureContainerInfoSP <> ''
      BEGIN
         EXEC rdt.rdt_ScanToContainer_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'DISPLAY',  
            @cContainerKey, @cContainerNo, @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cData1, @cData2, @cData3, @cData4, @cData5, 
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
         SET @nScn = @nScn + 8
         SET @nStep = @nStep + 8
         
         GOTO Quit
      END
  
      SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
      FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
      WHERE ContainerKey = @cContainerKey  
  
      IF @nFunc IN (1636, 1649)  
      BEGIN  
         -- (james05)  
         SELECT @cScanCTNCnt = CAST(COUNT(PalletKey) AS CHAR)        
         FROM dbo.CONTAINER CH WITH (NOLOCK)        
         JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (CH.ContainerKey = CD.ContainerKey)        
         WHERE CH.OtherReference = CASE WHEN @cMbolNotFromOtherReference = '1' THEN CH.OtherReference ELSE @cMBOLKEY END  
         AND   CH.MBOLKey = CASE WHEN @cMbolNotFromOtherReference = '1' THEN @cMBOLKEY ELSE CH.MBOLKEY END  
     
         SELECT @cTotalCTNCnt = CAST(COUNT(PD.LabelNo) AS CHAR)  --(yeekung06)
         FROM dbo.MBOLDETAIL MD WITH (NOLOCK)  
         JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)  
         JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
         WHERE MD.MBOLKey = @cMBOLKEY  
  
         --prepare next screen variable  
         SET @cOutField01 = @cContainerKey  
         SET @cOutField02 = @cMBOLKEY  
         SET @cOutField03 = @cContainerNo  
         SET @cOutField04 = ''  
         SET @cOutField05 = @cScanCnt  
         SET @cOutField06 = RTRIM(@cScanCTNCnt) + '/' + RTRIM(@cTotalCTNCnt)  
         SET @cOutField07 = CASE WHEN @nFunc = 1649 THEN 'SCANNED: ' + RTRIM(@cScanCnt) ELSE '' END   -- (james02)  
  
         -- Go to next screen  
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
      END  
      ELSE -- @nFunc = 1637  
      BEGIN  
         IF @cVerifyPallet = '1'  
            SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
            FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
            WHERE ContainerKey = @cContainerKey  
               AND Status = '5'  
  
         SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)  
         IF @cExtendedInfoSP = '0'  
            SET @cExtendedInfoSP = ''  
     
         IF @cExtendedInfoSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,  ' +  
                  ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @cExtendedInfo1 OUTPUT '  
               SET @cSQLParam =  
                  '@nMobile         INT, ' +  
                  '@nFunc           INT, ' +  
                  '@cLangCode       NVARCHAR( 3), ' +  
                  '@nStep           INT, ' +  
                  '@nInputKey       INT, ' +  
                  '@cStorerkey      NVARCHAR( 15), ' +  
                  '@cContainerKey   NVARCHAR( 10), ' +  
                  '@cContainerNo    NVARCHAR( 20), ' +  
                  '@cMBOLKey        NVARCHAR( 10), ' +  
                  '@cSSCCNo         NVARCHAR( 20), ' +  
                  '@cPalletKey      NVARCHAR( 30), ' +  
                  '@cTrackNo        NVARCHAR( 20), ' +  
                  '@cOption         NVARCHAR( 1), ' +  
                  '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '  
     
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,    
                  @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @cExtendedInfo1 OUTPUT   
     
               -- Prepare extended fields  
               IF @cExtendedInfo1 <> '' SET @cOutField06 = @cExtendedInfo1  
            END  
         END  
           
         --prepare next screen variable  
         SET @cOutField01 = @cContainerKey  
         SET @cOutField02 = @cMBOLKEY  
         SET @cOutField03 = @cContainerNo  
         SET @cOutField04 = ''  
         SET @cOutField05 = @cScanCnt  
  
         SET @nPrevScn = @nScn  
         SET @nPrevStep = @nStep  
  
         -- Go to next screen  
         SET @nScn = @nScn + 2  
         SET @nStep = @nStep + 2  
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
   	--eventLog  --(cc01)
   	EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey
         
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
  
      SET @cContainerKey = ''  
      SET @cMBOLKey = ''  
      SET @cContainerNo = ''  
      SET @cSSCCNo = ''  
      SET @cScanCnt = ''  
      SET @cScanCTNCnt = ''  
      SET @cTotalCTNCnt = ''  
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      SET @cContainerKey = ''  
      SET @cContainerNo = ''  
  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
    END  
  
END  
GOTO Quit  
  
/********************************************************************************  
Step 2. (screen = 2191)  
   CONTAINERKEY: (Field01)  
   MBOL #:       (Field02)  
   CONTAINTER #: (Field03)  
   SSCC:         (Field04, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cSSCCNo = @cInField04  
  
      --When SSCC is blank  
      IF @cSSCCNo = ''  
      BEGIN  
         SET @nErrNo = 95857  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC# req  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_2_Fail  
      END  
  
      --SSCC exists in Container  
      IF EXISTS (SELECT 1 FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
                 WHERE ContainerKey = @cContainerKey AND PalletKey = @cSSCCNo)  
      BEGIN  
         SET @nErrNo = 95858  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC# Exists  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_2_Fail  
      END  
  
      IF @nFunc = 1649  
      BEGIN  
         IF EXISTS (SELECT 1 FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
                    WHERE PalletKey = @cSSCCNo)  
         BEGIN  
            SET @nErrNo = 95859  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC# Exists  
           EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Step_2_Fail  
         END  
      END  
  
      -- Check if SSCC checking is req  
      IF rdt.RDTGetConfig( @nFunc, 'NOTCHECKSSCC', @cStorerKey) <> '1'  
      BEGIN  
         --SSCC not exists in MBOL  
         IF NOT EXISTS (SELECT 1 FROM dbo.MBOLDETAIL MD WITH (NOLOCK)  
                        JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)  
                        JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
                        WHERE MD.MBOLKey = @cMBOLKEY  
                        AND   PD.LabelNo = @cSSCCNo)  
         BEGIN  
            SET @nErrNo = 95860  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SSCC#  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Step_2_Fail  
         END  
  
         --SSCC exists in other Container in same MBOL      (james05)  
         IF EXISTS (SELECT 1 FROM dbo.CONTAINER CH WITH (NOLOCK)        
                    JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (CH.ContainerKey = CD.ContainerKey)        
                    WHERE CH.OtherReference = CASE WHEN @cMbolNotFromOtherReference = '1' THEN CH.OtherReference ELSE @cMBOLKEY END  
                    AND   CH.MBOLKey = CASE WHEN @cMbolNotFromOtherReference = '1' THEN @cMBOLKEY ELSE CH.MBOLKEY END  
                    AND   CD.PalletKey = @cSSCCNo)        
         BEGIN  
            SET @nErrNo = 95861  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC# Scanned  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Step_2_Fail  
         END  
  
         IF @cScanCTNCnt = @cTotalCTNCnt  
         BEGIN  
            SET @nErrNo = 95862  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Scan  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Step_2_Fail  
         END  
      END  
  
      -- Insert to ContainerDetail  
      INSERT INTO dbo.CONTAINERDETAIL (ContainerKey, ContainerLineNumber, PalletKey)  
      VALUES (@cContainerKey, '0', @cSSCCNo)  
  
      SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
      FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
      WHERE ContainerKey = @cContainerKey  
  
      -- (james05)  
      SELECT @cScanCTNCnt = CAST(COUNT(PalletKey) AS CHAR)        
      FROM dbo.CONTAINER CH WITH (NOLOCK)        
      JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (CH.ContainerKey = CD.ContainerKey)        
      WHERE CH.OtherReference = CASE WHEN @cMbolNotFromOtherReference = '1' THEN CH.OtherReference ELSE @cMBOLKEY END  
      AND   CH.MBOLKey = CASE WHEN @cMbolNotFromOtherReference = '1' THEN @cMBOLKEY ELSE CH.MBOLKEY END  
  
      SELECT @cTotalCTNCnt = CAST(COUNT(PD.CartonNo) AS CHAR)  
      FROM dbo.MBOLDETAIL MD WITH (NOLOCK)  
      JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)  
      JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
      WHERE MD.MBOLKey = @cMBOLKEY  
      
      --eventlog  --(cc01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '8',
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep,
         @cContainerNo= @cContainerNo,
         @cContainerKey= @cContainerKey,
         @cSSCC       = @cSSCCNo
  
      --prepare next screen variable  
      SET @cOutField01 = @cContainerKey  
      SET @cOutField02 = @cMBOLKEY  
      SET @cOutField03 = @cContainerNo  
      SET @cOutField04 = ''  
      SET @cOutField05 = @cScanCnt  
      SET @cOutField06 = RTRIM(@cScanCTNCnt) + '/' + RTRIM(@cTotalCTNCnt)  
      SET @cOutField07 = CASE WHEN @nFunc = 1649 THEN 'SCANNED: ' + RTRIM(@cScanCnt) ELSE '' END    -- (james02)  
  
  
      SET @cPrevSSCCNo = @cSSCCNo  
      SET @cSSCCNo = ''  
  
      -- Go next screen  
      SET @nScn = @nScn  
      SET @nStep = @nStep  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      IF @nFunc = 1649     -- (james02)  
      BEGIN  
      /*  
         -- Must at least scanned one sscc#  
         IF NOT EXISTS (SELECT 1 FROM dbo.ContainerDetail WITH (NOLOCK)  
                        WHERE ContainerKey = @cContainerKey  
                           AND PalletKey = @cPrevSSCCNo)  
         BEGIN  
            SET @cPrevSSCCNo = ''  
            SET @cOutField01 = ''  
  
            SET @nScn = @nScn - 1  
            SET @nStep = @nStep - 1  
  
            GOTO Quit  
         END  
        */  
         -- Check if Container.BookingReference has value.  
         -- If Container.BookingReference like '9385%', then do not update Container.BookingReference;  
         -- Else, update big box barcode to Container.BookingReference  
         IF NOT EXISTS (SELECT 1 FROM dbo.Container WITH (NOLOCK)  
                    WHERE ContainerkEY = @cContainerKey  
                    AND BookingReference LIKE '9385%')  
         BEGIN  
            SELECT TOP 1  
               @cConsigneeKey = RIGHT( '0000' + CAST(SUBSTRING(ISNULL(RTRIM(O.ConsigneeKey), '0000'), 1, 4) AS NVARCHAR(4)), 4),  
               @cSectionKey   = SUBSTRING(O.SectionKey, 1, 1)  
            FROM dbo.PackDetail PD WITH (NOLOCK)  
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo  
            JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey  
            JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON PD.UPC = CD.PalletKey  
            JOIN dbo.Container C WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey  
            WHERE C.ContainerKey = @cContainerKey  
  
            SET @nTranCount = @@TRANCOUNT  
            BEGIN TRAN  
            SAVE TRAN UPD_BIGBOXLABEL  
  
            IF ISNULL(@cSectionKey, '') = ''  
            BEGIN  
               -- Rollback any carton scanned  
               DELETE FROM dbo.ContainerDetail WITH (ROWLOCK) WHERE ContainerKey = @cContainerKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  ROLLBACK TRAN UPD_BIGBOXLABEL  
                  WHILE @@TRANCOUNT > @nTranCount  
                     COMMIT TRAN  
                  SET @nErrNo = 95863  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL COND FAIL  
                  GOTO Step_2_Fail  
               END  
  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
               SET @nErrNo = 95864  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV SECTIONKEY  
               GOTO Step_2_Fail  
            END  
  
            SET @cKeyName = ''  
            SET @cKeyName = RTRIM(@cConsigneeKey) + '_BIGBOXLABEL'  
            IF NOT EXISTS (SELECT 1 FROM dbo.NCounter WITH (NOLOCK) WHERE KeyName = @cKeyName)  
            BEGIN  
               SET @c_NewKey = '65000'  
               INSERT INTO NCounter (KeyName, KeyCount)  
               VALUES (@cKeyName, @c_NewKey)  
  
               IF @@ERROR <> 0  
               BEGIN  
                  ROLLBACK TRAN UPD_BIGBOXLABEL  
                  WHILE @@TRANCOUNT > @nTranCount  
                     COMMIT TRAN  
                  SET @nErrNo = 95865  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GETKEY FAILED  
                  GOTO Step_2_Fail  
               END  
            END  
            ELSE  
            BEGIN  
               SET @c_NewKey = ''  
               EXECUTE nspg_getkey  
                 @cKeyName  
               , 5  
               , @c_NewKey          OUTPUT  
               , @b_Success         OUTPUT  
               , @n_ErrNo           OUTPUT  
               , @c_ErrMsg  OUTPUT  
  
               IF @b_Success <> 1  
               BEGIN  
                  ROLLBACK TRAN UPD_BIGBOXLABEL  
                  WHILE @@TRANCOUNT > @nTranCount  
                     COMMIT TRAN  
                  SET @nErrNo = 95866  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GETKEY FAILED  
                  GOTO Step_2_Fail  
               END  
  
               -- Big box sequential number, from 65000 to 69999, store level  
               -- (e.g. store1: 65000, 65001, 65002 ...; store2: 65000, 65001, 65002 ... 65222 ... loop it if number =69999)  
               IF ISNULL(@c_NewKey, '') = '70000'  
               BEGIN  
                  SET @c_NewKey = '65000'  
  
                  -- Reset the counter  
                  UPDATE nCounter WITH (ROWLOCK) SET  
                     KeyCount = 65000, Editdate = GETDATE()  
                  WHERE KeyName = @cKeyName  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     ROLLBACK TRAN UPD_BIGBOXLABEL  
                     WHILE @@TRANCOUNT > @nTranCount  
                        COMMIT TRAN  
                     SET @nErrNo = 95867  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GETKEY FAILED  
                     GOTO Step_2_Fail  
                  END  
               END  
            END  
  
            SET @cTempBarcode = '9385'  
            SET @cTempBarcode = RTRIM(@cTempBarcode) + RTRIM(@cConsigneeKey)  
            SET @cTempBarcode = RTRIM(@cTempBarcode) + RTRIM(@cSectionKey)  
            SET @cTempBarcode = RTRIM(@cTempBarcode) + '0'  
            SET @cTempBarcode = RTRIM(@cTempBarcode) + RTRIM(@c_NewKey)  
            SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcode), 0)  
            SET @cTempBarcode = RTRIM(@cTempBarcode) + @cCheckDigit  
  
            UPDATE dbo.Container WITH (ROWLOCK) SET  
               BookingReference = @cTempBarcode  
            WHERE ContainerKey = @cContainerKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               ROLLBACK TRAN UPD_BIGBOXLABEL  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
               SET @nErrNo = 95868  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LBL FAIL  
               GOTO Step_2_Fail  
            END  
  
            WHILE @@TRANCOUNT > @nTranCount  
               COMMIT TRAN  
         END  
  
         -- If config turned on then show tracking no screen  
         IF ISNULL(rdt.RDTGetConfig( @nFunc, 'SHOWTRACKINGNO', @cStorerKey), '') = '1'  
         BEGIN  
            SET @cOutField01 = ''  
  
            SET @nScn = @nScn + 2  
            SET @nStep = @nStep + 2  
  
            GOTO Quit  
         END  
         ELSE  
         BEGIN  
            SET @cOutField01 = ''  
  
            SET @nScn = @nScn + 3  
            SET @nStep = @nStep + 3  
  
            GOTO Quit  
         END  
  
         GOTO Quit  
      END  
  
      -- (james09)  
      SELECT  
         @cParamLabel1 = UDF01,  
         @cParamLabel2 = UDF02,  
         @cParamLabel3 = UDF03,  
         @cParamLabel4 = UDF04,  
         @cParamLabel5 = UDF05,  
         @cAction = Short  
      FROM dbo.CodeLKUP WITH (NOLOCK)  
      WHERE ListName = 'SCAN2TRKUD'  
      AND   Code = @cUDFCriteria  
      AND   StorerKey = @cStorerKey  
      AND   Code2 = @nFunc  
      AND   Short IN ('BOTH', 'POST')  
  
      IF @@ROWCOUNT > 0  
      BEGIN  
         -- Check pallet criteria setup  
         IF @cParamLabel1 = '' AND  
            @cParamLabel2 = '' AND  
            @cParamLabel3 = '' AND  
            @cParamLabel4 = '' AND  
            @cParamLabel5 = ''  
         BEGIN  
            SET @nErrNo = 95896  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup  
            GOTO Quit  
         END  
  
         -- Enable / disable field  
         SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END  
  
         -- Clear optional in field  
         SET @cInField02 = ''  
         SET @cInField04 = ''  
         SET @cInField06 = ''  
         SET @cInField08 = ''  
         SET @cInField10 = ''  
         SET @cInField11 = ''  
  
         -- Prepare next screen var  
         SET @cOutField01 = @cParamLabel1  
         SET @cOutField02 = ''  
         SET @cOutField03 = @cParamLabel2  
         SET @cOutField04 = ''  
         SET @cOutField05 = @cParamLabel3  
         SET @cOutField06 = ''  
         SET @cOutField07 = @cParamLabel4  
         SET @cOutField08 = ''  
         SET @cOutField09 = @cParamLabel5  
         SET @cOutField10 = ''  
         SET @cOutField11 = ''  
  
         SET @cAction = 'POST'  
  
         SET @nPrevScn = @nScn  
         SET @nPrevStep = @nStep  
  
         SET @nScn = @nScn + 6  
         SET @nStep = @nStep + 6  
  
         GOTO Quit  
      END  
  
      --prepare prev screen variable  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
  
      SET @cContainerKey = ''  
      SET @cMBOLKey = ''  
      SET @cContainerNo = ''  
      SET @cSSCCNo = ''  
      SET @cScanCnt = ''  
      SET @cScanCTNCnt = ''  
      SET @cTotalCTNCnt = ''  
  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  

   Step_2_ExtScn:
   BEGIN
      SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
      IF @cExtendedScnSP = '0'
         SET @cExtendedScnSP = ''

      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            SET @nExtScnAction = 0
            GOTO Step_99
         END
      END
   END

   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cSSCCNo = ''  
  
      SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
      FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
      WHERE ContainerKey = @cContainerKey  
  
      -- (james05)  
      SELECT @cScanCTNCnt = CAST(COUNT(PalletKey) AS CHAR)        
      FROM dbo.CONTAINER CH WITH (NOLOCK)        
      JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (CH.ContainerKey = CD.ContainerKey)        
      WHERE CH.OtherReference = CASE WHEN @cMbolNotFromOtherReference = '1' THEN CH.OtherReference ELSE @cMBOLKEY END  
      AND   CH.MBOLKey = CASE WHEN @cMbolNotFromOtherReference = '1' THEN @cMBOLKEY ELSE CH.MBOLKEY END  
  
      SELECT @cTotalCTNCnt = CAST(COUNT(PD.CartonNo) AS CHAR)  
      FROM dbo.MBOLDETAIL MD WITH (NOLOCK)  
      JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)  
      JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
      WHERE MD.MBOLKey = @cMBOLKEY  
  
      -- Reset this screen var  
      SET @cOutField01 = @cContainerKey  
      SET @cOutField02 = @cMBOLKEY  
      SET @cOutField03 = @cContainerNo  
      SET @cOutField04 = ''  
      SET @cOutField05 = @cScanCnt  
      SET @cOutField06 = RTRIM(@cScanCTNCnt) + '/' + RTRIM(@cTotalCTNCnt)  
      SET @cOutField07 = CASE WHEN @nFunc = 1649 THEN 'SCANNED: ' + RTRIM(@cScanCnt) ELSE '' END    -- (james02)  
  END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 3. (screen = 2192) -- (james01)  
   CONTAINERKEY: (Field01)  
   MBOL #:       (Field02)  
   CONTAINTER #: (Field03)  
   PALLETKEY:    (Field04, input)  
   SCANNED:      (Field05)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cPalletKey = @cInField04  
  
      --When SSCC is blank  
      IF @cPalletKey = ''  
      BEGIN  
         SET @nErrNo = 95869  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID req  
         GOTO Step_3_Fail  
      END  
  
      -- Check format  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletKey', @cPalletKey) = 0  
      BEGIN  
         SET @nErrNo = 95888  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet  
         GOTO Step_3_Fail  
      END  
  
      IF @cVerifyPallet = '1'  
      BEGIN  
      	IF (@cShowPopOutMsg='1')  
         BEGIN   
            SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)        
            IF @cExtendedValidateSP NOT IN ('0', '')        
            BEGIN        
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +        
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo, ' +         
                  ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
                
               SET @cSQLParam =        
                  '@nMobile                   INT,           ' +        
                  '@nFunc                     INT,           ' +        
                  '@cLangCode                 NVARCHAR( 3),  ' +        
                  '@nStep                     INT,           ' +        
                  '@nInputKey                 INT,           ' +        
                  '@cStorerkey                NVARCHAR( 15), ' +        
                  '@cContainerKey             NVARCHAR( 10), ' +        
                  '@cContainerNo              NVARCHAR( 20), ' +        
                  '@cMBOLKey                  NVARCHAR( 10), ' +        
                  '@cSSCCNo                   NVARCHAR( 20), ' +        
                  '@cPalletKey                NVARCHAR( 30), ' +        
                  '@cTrackNo                  NVARCHAR( 20), ' +        
                  '@cOption                   NVARCHAR( 1), '  +        
                  '@nErrNo                    INT           OUTPUT,  ' +        
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT   '        
                
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,         
                  @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT        
                
               IF @nErrNo <> 0        
               BEGIN        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')         
                  GOTO Step_3_Fail                
               END        
            END    
         END  
         ELSE  
         BEGIN 
	         -- Pallet not in container  
	         IF NOT EXISTS (SELECT 1 FROM dbo.ContainerDetail WITH (NOLOCK) WHERE ContainerKey = @cContainerKey AND PalletKey = @cPalletKey)  
	         BEGIN  
	            SET @nErrNo = 95870  
	            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PL not in Cont  
	            GOTO Step_3_Fail  
	         END  
	  
	         -- Check if pallet scanned (for 2nd time verify only)  
	         IF EXISTS ( SELECT 1 FROM dbo.ContainerDetail WITH (NOLOCK)   
	                     WHERE ContainerKey = @cContainerKey   
	                     AND   PalletKey = @cPalletKey  
	                     AND   [Status] = '5'  
	                     AND   (( @nFunc = 1651 AND 1 = 1) OR ( 1 = 0)))  
	         BEGIN  
	            SET @nErrNo = 95898  
	            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet scanned   
	            GOTO Step_3_Fail  
	         END  
	  		END  
	  		
         BEGIN TRAN  
     
         -- ContainerDetail  
         UPDATE dbo.CONTAINERDETAIL SET  
            Status = '5',   
            Trafficcop='9',  
            EditWho = SUSER_SNAME(),   
            EditDate = GETDATE()  
         WHERE ContainerKey = @cContainerKey  
            AND PalletKey = @cPalletKey  
            AND Status = '0'  
         IF @@ERROR <> 0  
         BEGIN  
            ROLLBACK TRAN  
            SET @nErrNo = 95871  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsConDtl Fail  
            GOTO Step_3_Fail  
         END  
     
         COMMIT TRAN  
  
         SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
         FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
         WHERE ContainerKey = @cContainerKey  
            AND Status = '5'  
   	END 
   	ELSE
      BEGIN  
  
         --PalletID exists in Container  
         IF EXISTS (SELECT 1 FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
                    --WHERE PalletKey = @cPalletKey)      
                    WHERE ContainerKey = @cContainerKey AND PalletKey = @cPalletKey) 
         BEGIN  
            SET @nErrNo = 95872  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID Exist  
            GOTO Step_3_Fail  
         END  
     
         --PalletID exists in other Container in same MBOL      (james05)  
         IF EXISTS (SELECT 1 FROM dbo.CONTAINER CH WITH (NOLOCK)        
                   JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (CH.ContainerKey = CD.ContainerKey)        
                   WHERE CH.OtherReference = CASE WHEN @cMbolNotFromOtherReference = '1' THEN CH.OtherReference ELSE @cMBOLKEY END  
                   AND   CH.MBOLKey = CASE WHEN @cMbolNotFromOtherReference = '1' THEN @cMBOLKEY ELSE CH.MBOLKEY END  
                   AND   CD.PalletKey = @cPalletKey)        
         BEGIN  
            SET @nErrNo = 95873  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet scanned  
            GOTO Step_3_Fail  
         END  
  
         -- (james05)  
         SET @nErrNo = 0  
         SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
         IF @cExtendedValidateSP NOT IN ('0', '')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo, ' +   
               ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
          
            SET @cSQLParam =  
               '@nMobile                   INT,           ' +  
               '@nFunc                     INT,           ' +  
               '@cLangCode                 NVARCHAR( 3),  ' +  
               '@nStep                     INT,           ' +  
               '@nInputKey                 INT,           ' +  
               '@cStorerkey                NVARCHAR( 15), ' +  
               '@cContainerKey             NVARCHAR( 10), ' +  
               '@cContainerNo              NVARCHAR( 20), ' +  
               '@cMBOLKey    NVARCHAR( 10), ' +  
               '@cSSCCNo                   NVARCHAR( 20), ' +  
               '@cPalletKey                NVARCHAR( 30), ' +  
               '@cTrackNo                  NVARCHAR( 20), ' +  
               '@cOption                   NVARCHAR( 1), '  +  
               '@nErrNo                    INT           OUTPUT,  ' +  
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '  
          
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,   
               @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT  
          
            IF @nErrNo <> 0  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
               GOTO Step_3_Fail          
            END  
         END  
        
         SET @nTranCount = @@TRANCOUNT      
  
         BEGIN TRAN      
         SAVE TRAN Step3_UPD      
     
         -- Insert to ContainerDetail  
         INSERT INTO dbo.CONTAINERDETAIL (ContainerKey, ContainerLineNumber, PalletKey)  
         VALUES (@cContainerKey, '0', @cPalletKey)  
     
         IF @@ERROR <> 0  
         BEGIN  
            ROLLBACK TRAN Step3_UPD  
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN Step3_UPD  
            SET @nErrNo = 95874        
            SET @cErrMsg = rdt.rdtgetmessage( 68429, @cLangCode, 'DSP') --InsConDtl Fail         
            GOTO Step_3_Fail          
         END  
     
         SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)  
         IF @cExtendedUpdateSP NOT IN ('0', '')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, ' +  
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
     
            SET @cSQLParam =  
               '@nMobile                   INT,           ' +  
               '@nFunc                     INT,           ' +  
               '@cLangCode                 NVARCHAR( 3),  ' +  
               '@nStep                     INT,           ' +  
               '@nInputKey                 INT,           ' +  
               '@cStorerkey                NVARCHAR( 15), ' +  
               '@cContainerKey             NVARCHAR( 10), ' +  
               '@cMBOLKey                  NVARCHAR( 10), ' +  
               '@cSSCCNo                   NVARCHAR( 20), ' +  
               '@cPalletKey                NVARCHAR( 30), ' +  
               '@cTrackNo                  NVARCHAR( 20), ' +  
               '@cOption                   NVARCHAR( 1), '  +  
               '@nErrNo                    INT           OUTPUT,  ' +  
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '  
     
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption,  
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
     
            IF @nErrNo <> 0  
            BEGIN  
               ROLLBACK TRAN Step3_UPD  
               WHILE @@TRANCOUNT > @nTranCount    
                  COMMIT TRAN    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EXT UPD FAIL'  
               GOTO Quit  
            END  
         END  
     
         WHILE @@TRANCOUNT > @nTranCount    
            COMMIT TRAN Step3_UPD  
     
         SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
         FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
         WHERE ContainerKey = @cContainerKey  
      END  
  
      SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)  
      IF @cExtendedInfoSP = '0'  
         SET @cExtendedInfoSP = ''  
     
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,  ' +  
               ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @cExtendedInfo1 OUTPUT '  
            SET @cSQLParam =  
               '@nMobile         INT, ' +  
               '@nFunc           INT, ' +  
               '@cLangCode       NVARCHAR( 3), ' +  
               '@nStep           INT, ' +  
               '@nInputKey       INT, ' +  
               '@cStorerkey      NVARCHAR( 15), ' +  
               '@cContainerKey   NVARCHAR( 10), ' +  
               '@cContainerNo    NVARCHAR( 20), ' +  
               '@cMBOLKey        NVARCHAR( 10), ' +  
               '@cSSCCNo         NVARCHAR( 20), ' +  
               '@cPalletKey      NVARCHAR( 30), ' +  
               '@cTrackNo        NVARCHAR( 20), ' +  
               '@cOption         NVARCHAR( 1), ' +  
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '  
     
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,    
               @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @cExtendedInfo1 OUTPUT   
     
            -- Prepare extended fields  
            IF @cExtendedInfo1 <> '' SET @cOutField06 = @cExtendedInfo1  
         END  
      END  
  
      --eventlog  --(cc01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '8',
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep,
         @cContainerNo= @cContainerNo,
         @cContainerKey= @cContainerKey,
         @cDropID     = @cPalletKey
         
      --prepare next screen variable  
      SET @cOutField01 = @cContainerKey  
      SET @cOutField02 = @cMBOLKEY  
      SET @cOutField03 = @cContainerNo  
      SET @cOutField04 = ''  
      SET @cOutField05 = @cScanCnt  
      
      SET @cPalletKeyPrev = @cPalletKey      --(cc02)
  
      SET @cPalletKey = ''  
  
      -- Go next screen  
      SET @nScn = @nScn  
      SET @nStep = @nStep  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- (james09)  
      SELECT  
         @cParamLabel1 = UDF01,  
         @cParamLabel2 = UDF02,  
         @cParamLabel3 = UDF03,  
         @cParamLabel4 = UDF04,  
         @cParamLabel5 = UDF05,  
         @cAction = Short  
      FROM dbo.CodeLKUP WITH (NOLOCK)  
      WHERE ListName = 'SCAN2TRKUD'  
      AND   Code = @cUDFCriteria  
      AND   StorerKey = @cStorerKey  
      AND   Code2 = @nFunc  
      AND   Short IN ('BOTH', 'POST')  
  
      IF @@ROWCOUNT > 0  
      BEGIN  
         -- Check pallet criteria setup  
         IF @cParamLabel1 = '' AND  
            @cParamLabel2 = '' AND  
            @cParamLabel3 = '' AND  
            @cParamLabel4 = '' AND  
            @cParamLabel5 = ''  
         BEGIN  
            SET @nErrNo = 95892  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup  
            GOTO Quit  
         END  
  
         -- Enable / disable field  
         SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END  
         SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END  
  
         -- Clear optional in field  
         SET @cInField02 = ''  
         SET @cInField04 = ''  
         SET @cInField06 = ''  
         SET @cInField08 = ''  
         SET @cInField10 = ''  
         SET @cInField11 = ''  
  
         -- Prepare next screen var  
         SET @cOutField01 = @cParamLabel1  
         SET @cOutField02 = ''  
         SET @cOutField03 = @cParamLabel2  
         SET @cOutField04 = ''  
         SET @cOutField05 = @cParamLabel3  
         SET @cOutField06 = ''  
         SET @cOutField07 = @cParamLabel4  
         SET @cOutField08 = ''  
         SET @cOutField09 = @cParamLabel5  
         SET @cOutField10 = ''  
         SET @cOutField11 = ''  
  
         SET @cAction = 'POST'  
  
         SET @nPrevScn = @nScn  
         SET @nPrevStep = @nStep  
  
         SET @nScn = @nScn + 5  
         SET @nStep = @nStep + 5  
  
         GOTO Quit  
      END  
        
      IF rdt.RDTGetConfig( @nFunc, 'CLOSECONTAINER', @cStorerKey) = '1'  
      BEGIN  
         --prepare prev screen variable  
         SET @cOption = ''  
         SET @cOutField01 = ''  
  
         SET @nScn = @nScn + 3  
         SET @nStep = @nStep + 3  
  
         GOTO Quit  
      END  
  
      -- Print container manifest  
      IF @cContainerManifest not in  ('','0')
      BEGIN  
         -- Prep next screen var  
         SET @cOutField01 = ''  
           
         -- Go to print container manifest screen  
         SET @nScn  = @nScn + 4  
         SET @nStep = @nStep + 4  
           
         GOTO Quit  
      END  
  
      --prepare prev screen variable  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
  
      SET @cContainerKey = ''  
      SET @cMBOLKey = ''  
      SET @cContainerNo = ''  
      SET @cSSCCNo = ''  
      SET @cScanCnt = ''  
      SET @cScanCTNCnt = ''  
      SET @cTotalCTNCnt = ''  
  
      SET @nScn = @nScn - 2  
      SET @nStep = @nStep - 2  
   END  

   Step_3_ExtScn:
   BEGIN
      SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
      IF @cExtendedScnSP = '0'
         SET @cExtendedScnSP = ''

      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            SET @nExtScnAction = 0
            GOTO Step_99
         END
      END
   END

   GOTO Quit  
  
   Step_3_Fail:  
   BEGIN  
      SET @cPalletKey = ''  
      SET @cScanCnt = '0'  
  
      -- (james10)  
      SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
      FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
      WHERE ContainerKey = @cContainerKey  
      AND   ((@cVerifyPallet = '0') OR (@cVerifyPallet = '1' AND [Status] = '5'))  
  
      -- Reset this screen var  
      SET @cOutField01 = @cContainerKey  
      SET @cOutField02 = @cMBOLKEY  
      SET @cOutField03 = @cContainerNo  
      SET @cOutField04 = ''  
      SET @cOutField05 = @cScanCnt  
  END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 4. screen = 2193  
   TRACKING NO (Field01, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cTrackNo = @cInField01      -- (james03)  
  
      IF rdt.RDTGetConfig( @nFunc, 'TRACKNOREQUIRED', @cStorerKey) = 1  
      BEGIN  
         --When SSCC is blank  
         IF ISNULL(@cTrackNo, '') = '' -- (james03)  
         BEGIN  
            SET @nErrNo = 95875  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Track No req  
            GOTO Step_4_Fail  
         END  
      END  
  
      IF ISNULL(@cTrackNo, '') <> ''  
      BEGIN  
         SET @nTranCount = @@TRANCOUNT  
         BEGIN TRAN  
         SAVE TRAN UPD_TRACKNO  
  
         -- Handle multi SSCC per container (james04)  
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT DISTINCT PalletKey FROM dbo.ContainerDetail WITH (NOLOCK)  
         WHERE ContainerKey = @cContainerKey  
         OPEN CUR_LOOP  
         FETCH NEXT FROM CUR_LOOP INTO @cSSCCNo  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            SET @cPickSlipNo = ''  
            SELECT TOP 1 @cPickSlipNo = ISNULL(PD.PickSlipNo, '')  
            FROM dbo.PackDetail PD WITH (NOLOCK)  
            JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON PD.UPC = CD.PalletKey  
            WHERE CD.PalletKey = @cSSCCNo  
               AND PD.StorerKey = @cStorerKey  
  
            SET @cOrderKey = ''  
            SET @cShipperKey = ''  
            SELECT TOP 1  
               @cOrderKey   = ISNULL(O.OrderKey, '')  ,  
               @cShipperKey = ISNULL(O.ShipperKey, '')  
            FROM dbo.ORDERS O WITH (NOLOCK)  
            JOIN dbo.PackHeader PH WITH (NOLOCK)  
               ON (O.StorerKey = PH.StorerKey AND O.OrderKey = PH.OrderKey)  
            WHERE PickSlipNo = @cPickSlipNo  
  
            SET @cTrackRegExp = ''  
            SELECT @cTrackRegExp = Notes1 FROM dbo.Storer WITH (NOLOCK)  
            WHERE Storerkey = @cShipperKey  
  
            IF rdt.rdtIsRegExMatch(ISNULL(RTRIM(@cTrackRegExp),''),ISNULL(RTRIM(@cTrackNo),'')) <> 1  
            BEGIN  
               ROLLBACK TRAN UPD_TRACKNO  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
               CLOSE CUR_LOOP  
               DEALLOCATE CUR_LOOP  
               SET @nErrNo = 95876  
               SET @cErrMsg = rdt.rdtgEtmessage( @nErrNo, @cLangCode, 'DSP') --Inv TrackNo  
               GOTO Step_4_Fail  
            END  
  
            UPDATE dbo.Orders WITH (ROWLOCK) SET  
               --UserDefine04 = @cTrackNo  
               TrackingNo = @cTrackNo     -- (james13)
            WHERE Orderkey = @cOrderKey  
            AND Storerkey = @cStorerKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               ROLLBACK TRAN UPD_TRACKNO  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
               CLOSE CUR_LOOP  
               DEALLOCATE CUR_LOOP  
               SET @nErrNo = 95877  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Ord Failed  
               GOTO Step_4_Fail  
            END  
            FETCH NEXT FROM CUR_LOOP INTO @cSSCCNo  
         END  
         CLOSE CUR_LOOP  
         DEALLOCATE CUR_LOOP  
  
         WHILE @@TRANCOUNT > @nTranCount  
            COMMIT TRAN  
      END  
  
      SET @cOutField01 = ''  
  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ENTER  
   BEGIN  
      SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
      FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
      WHERE ContainerKey = @cContainerKey  
  
      -- (james05)  
      SELECT @cScanCTNCnt = CAST(COUNT(PalletKey) AS CHAR)        
      FROM dbo.CONTAINER CH WITH (NOLOCK)        
      JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (CH.ContainerKey = CD.ContainerKey)        
      WHERE CH.OtherReference = CASE WHEN @cMbolNotFromOtherReference = '1' THEN CH.OtherReference ELSE @cMBOLKEY END  
      AND   CH.MBOLKey = CASE WHEN @cMbolNotFromOtherReference = '1' THEN @cMBOLKEY ELSE CH.MBOLKEY END  
  
      SELECT @cTotalCTNCnt = CAST(COUNT(PD.CartonNo) AS CHAR)  
      FROM dbo.MBOLDETAIL MD WITH (NOLOCK)  
      JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)  
      JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
      WHERE MD.MBOLKey = @cMBOLKEY  
  
      --prepare next screen variable  
      SET @cOutField01 = @cContainerKey  
      SET @cOutField02 = @cMBOLKEY  
      SET @cOutField03 = @cContainerNo  
      SET @cOutField04 = ''  
      SET @cOutField05 = @cScanCnt  
      SET @cOutField06 = RTRIM(@cScanCTNCnt) + '/' + RTRIM(@cTotalCTNCnt)  
      SET @cOutField07 = CASE WHEN @nFunc = 1649 THEN 'SCANNED: ' + RTRIM(@cScanCnt) ELSE '' END   -- (james02)  
  
      -- Go to next screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
  
      GOTO Quit  
   END  
  
   Step_4_Fail:  
   BEGIN  
      SET @cTrackNo = ''  
      SET @cOutField01 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 5. screen = 2194  
   OPTION (Field01, input)  
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      IF ISNULL(@cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 95878  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req  
         GOTO Step_5_Fail  
      END  
  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 95879  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Option  
         GOTO Step_5_Fail  
      END  
  
      IF @cOption = '1'  
      BEGIN  
         -- Print the label  
         IF ISNULL(@cLabelPrinter, '') = ''  
         BEGIN  
            SET @nErrNo = 95880  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter  
            GOTO Step_5_Fail  
         END  
  
         SET @cReportType = 'REPORDLBL'  
         SET @cPrintJobName = 'PRINT_REPACKORDERLABEL'  
  
         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
         FROM RDT.RDTReport WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   ReportType = @cReportType  
  
         IF ISNULL(@cDataWindow, '') = ''  
         BEGIN  
            SET @nErrNo = 95881  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP  
            GOTO Step_5_Fail  
         END  
  
         IF ISNULL(@cTargetDB, '') = ''  
         BEGIN  
            SET @nErrNo = 95882  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET  
            GOTO Step_5_Fail  
         END  
  
         SET @nErrNo = 0  
         EXEC RDT.rdt_BuiltPrintJob  
            @nMobile,  
            @cStorerKey,  
            @cReportType,  
            @cPrintJobName,  
            @cDataWindow,  
            @cLabelPrinter,  
            @cTargetDB,  
            @cLangCode,  
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT,  
            @cStorerKey,  
            @cContainerKey  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 95883  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL  
            GOTO Step_5_Fail  
         END  
  
         SET @cOutField01 = ''  
  
         SET @nScn = @nScn - 4  
         SET @nStep = @nStep - 4  
  
         GOTO Step_5_ExtScn
      END  
      ELSE  
      BEGIN  
         SET @cOutField01 = ''  
  
         SET @nScn = @nScn - 4  
         SET @nStep = @nStep - 4
      END  
   END  

   Step_5_ExtScn:
   BEGIN
      SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
      IF @cExtendedScnSP = '0'
         SET @cExtendedScnSP = ''

      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            SET @nExtScnAction = 0
            GOTO Step_99
         END
      END
   END
   GOTO Quit  
  
   Step_5_Fail:  
   BEGIN  
      SET @cOption = ''  
      SET @cOutField01 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 6. screen = 2195  
   OPTION (Field01, input)  
********************************************************************************/  
Step_6:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      IF ISNULL( @cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 95885  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req  
         GOTO Step_6_Fail  
      END  
  
      -- Check invalid option  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 95886  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option  
         GOTO Step_6_Fail  
      END  
  
      IF @cOption = '1' -- Yes  
      BEGIN  
         -- (james06)  
         SET @nErrNo = 0  
         SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
         IF @cExtendedValidateSP NOT IN ('0', '')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,  ' +  
               ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
          
            SET @cSQLParam =  
               '@nMobile                   INT,           ' +  
               '@nFunc                     INT,           ' +  
               '@cLangCode                 NVARCHAR( 3),  ' +  
               '@nStep                     INT,           ' +  
               '@nInputKey                 INT,           ' +  
               '@cStorerkey                NVARCHAR( 15), ' +  
               '@cContainerKey             NVARCHAR( 10), ' +  
               '@cContainerNo              NVARCHAR( 20), ' +  
               '@cMBOLKey                  NVARCHAR( 10), ' +  
               '@cSSCCNo                   NVARCHAR( 20), ' +  
               '@cPalletKey                NVARCHAR( 30), ' +  
               '@cTrackNo                  NVARCHAR( 20), ' +  
               '@cOption                   NVARCHAR( 1), '  +  
               '@nErrNo                    INT           OUTPUT,  ' +  
               '@cErrMsg                   NVARCHAR( 20) OUTPUT '  
          
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,   
                  @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT  
          
            IF @nErrNo <> 0  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
               GOTO Step_6_Fail          
            END  
         END  
  
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN Step_6_CloseContainer

         UPDATE dbo.Container WITH (ROWLOCK) SET 
            [Status] = CASE WHEN @cCloseContainerStatus = '' THEN '9' ELSE @cCloseContainerStatus END
         WHERE ContainerKey = @cContainerKey
         AND   [Status] = '0'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 95887
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- Close error
            ROLLBACK TRAN Step_6_CloseContainer
            WHILE @@TRANCOUNT > @nTranCount  
               COMMIT TRAN  
            GOTO Step_6_Fail
         END
         
         SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
         IF @cExtendedUpdateSP NOT IN ('0', '')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
   
            SET @cSQLParam =
               '@nMobile                   INT,           ' +
               '@nFunc                     INT,           ' +
               '@cLangCode                 NVARCHAR( 3),  ' +
               '@nStep                     INT,           ' +
               '@nInputKey                 INT,           ' +
               '@cStorerkey                NVARCHAR( 15), ' +
               '@cContainerKey             NVARCHAR( 10), ' +
               '@cMBOLKey                  NVARCHAR( 10), ' +
               '@cSSCCNo                   NVARCHAR( 20), ' +
               '@cPalletKey                NVARCHAR( 30), ' +
               '@cTrackNo                  NVARCHAR( 20), ' +
               '@cOption                   NVARCHAR( 1), '  +
               '@nErrNo                    INT           OUTPUT,  ' +
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_6_CloseContainer
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
               GOTO Step_6_Fail
            END
         END
         
         IF ISNULL(@cPalletLabel,'')<>'' --(yeekung05)
         BEGIN
            DECLARE @tPalletLbl AS VariableTable 

            INSERT INTO @tPalletLbl (Variable, Value) VALUES ( '@cContainerKey',  @cContainerKey)  
            INSERT INTO @tPalletLbl (Variable, Value) VALUES ( '@cStorerkey', @cStorerKey)  

            -- Print Carton label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
               @cPalletLabel, -- Report type  
               @tPalletLbl, -- Report params  
               'rdtfnc_Scan_To_Container',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT 
           
            IF @nErrNo <> 0  
            BEGIN      
               ROLLBACK TRAN Step_6_CloseContainer      
               WHILE @@TRANCOUNT > @nTranCount        
                  COMMIT TRAN        
               GOTO Step_6_Fail      
            END    
         END     
      
         WHILE @@TRANCOUNT > @nTranCount      
            COMMIT TRAN  
         
         --eventlog  --(cc01)
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '8',
            @cUserID     = @cUserName,
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerkey,
            @nStep       = @nStep,
            @cContainerNo  = @cContainerNo,
            @cContainerKey = @cContainerKey,
            @cOption       = @cOption,
            @cOptionDefinition= 'Close Container'
           
         -- Print container manifest  
         IF @cContainerManifest not in  ('','0')
         BEGIN  
            -- Prep next screen var  
            SET @cOutField01 = ''  
              
            -- Go to print container manifest screen  
            SET @nScn  = @nScn + 1  
            SET @nStep = @nStep + 1  
              
            GOTO Quit  
         END  
         
         --Print (cc02)
         IF @cDelList not in  ('','0')
         BEGIN
         	-- Common params  
            DECLARE @tDelList AS VariableTable  
            INSERT INTO @tDelList (Variable, Value) VALUES ( '@cContainerKey', @cContainerKey)  
            INSERT INTO @tDelList (Variable, Value) VALUES ( '@cPalletKey', @cPalletKeyPrev)  
  
            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
               @cDelList, -- Report type  
               @tDelList, -- Report params  
               'rdtfnc_Scan_To_Container',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT  
                            
            IF @nErrNo <> 0  
               GOTO Quit  
                            
         END
      END  
  
      -- Set the entry point  
      SET @nScn  = @nScn - 5  
      SET @nStep = @nStep - 5  
  
      -- initialise all variable  
      SET @cContainerKey = ''  
      SET @cContainerNo = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
      -- Prep next screen var  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
   END  

   Step_6_ExtScn:
   BEGIN
      SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
      IF @cExtendedScnSP = '0'
         SET @cExtendedScnSP = ''

      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            SET @nExtScnAction = 0
            GOTO Step_99
         END
      END
   END
   GOTO Quit  
  
   Step_6_Fail:  
   BEGIN  
      SET @cOption = ''  
      SET @cOutField01 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 7. screen = 2196  
   OPTION (Field01, input)  
********************************************************************************/  
Step_7:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      IF ISNULL( @cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 95890  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req  
         GOTO Step_7_Fail  
      END  
  
      -- Check invalid option  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 95891  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option  
         GOTO Step_7_Fail  
      END  
  
      IF @cOption = '1' -- Yes  
      BEGIN  
         -- Common params  
         DECLARE @tContainerManifest AS VariableTable  
         INSERT INTO @tContainerManifest (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)  
         INSERT INTO @tContainerManifest (Variable, Value) VALUES ( '@cContainerKey', @cContainerKey)  
         INSERT INTO @tContainerManifest (Variable, Value) VALUES ( '@cContainerNo', @cContainerNo)  
  
         -- Print label  
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
            @cContainerManifest, -- Report type  
            @tContainerManifest, -- Report params  
            'rdtfnc_Scan_To_Container',   
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT  
              
       --  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,     
       --      @cContainerManifest, -- Report type    
       --     @tContainerManifest, -- Report params    
       --     'rdtfnc_Scan_To_Container',     
       --     @nErrNo  OUTPUT,    
       --     @cErrMsg OUTPUT  
              
         IF @nErrNo <> 0  
            GOTO Quit  
      END  
  
      -- Set the entry point  
      SET @nScn  = @nScn - 6  
      SET @nStep = @nStep - 6  
  
      -- initialise all variable  
      SET @cContainerKey = ''  
      SET @cContainerNo = ''    
      -- Prep next screen var  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
   END  

   Step_7_ExtScn:
   BEGIN
      SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
      IF @cExtendedScnSP = '0'
         SET @cExtendedScnSP = ''

      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            SET @nExtScnAction = 0
            GOTO Step_99
         END
      END
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
Step 8. Scn = 2197  
   Param1      (field01, input)     
   Param2      (field02, input)     
   Param3      (field03, input)     
   Param4      (field04, input)     
   Param5      (field05, input)     
********************************************************************************/  
Step_8:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cParam1 = @cInField02  
      SET @cParam2 = @cInField04  
      SET @cParam3 = @cInField06  
      SET @cParam4 = @cInField08  
      SET @cParam5 = @cInField10  
      SET @cOption = @cInField11  
  
      -- Retain value  
      SET @cOutField02 = @cInField02  
      SET @cOutField04 = @cInField04  
      SET @cOutField06 = @cInField06  
      SET @cOutField08 = @cInField08  
      SET @cOutField10 = @cInField10  
      
		-- Check format        
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UDF01', @cParam1) = 0    --(yeekung03)    
      BEGIN        
         SET @nErrNo = 95900        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format       
         GOTO Step_8_Fail        
      END      
    
      -- Check format        
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UDF02', @cParam2) = 0    --(yeekung03)    
      BEGIN        
         SET @nErrNo = 149201        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format       
         GOTO Step_8_Fail        
      END     
    
      -- Check format        
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UDF03', @cParam3) = 0    --(yeekung03)    
      BEGIN        
         SET @nErrNo = 149202       
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format       
         GOTO Step_8_Fail        
      END       
    
       -- Check format        
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UDF04', @cParam4) = 0    --(yeekung03)    
      BEGIN        
         SET @nErrNo = 149203        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format       
         GOTO Step_8_Fail        
      END      
    
      -- Check format        
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UDF05', @cParam5) = 0    --(yeekung03)    
      BEGIN        
         SET @nErrNo = 149204        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format       
         GOTO Step_8_Fail        
      END      
      
      SET @nErrNo = 0  
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
      IF @cExtendedValidateSP NOT IN ('0', '')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,  ' +  
            ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
          
         SET @cSQLParam =  
            '@nMobile                   INT,           ' +  
            '@nFunc                     INT,           ' +  
            '@cLangCode                 NVARCHAR( 3),  ' +  
            '@nStep     INT,           ' +  
            '@nInputKey                 INT,           ' +  
            '@cStorerkey                NVARCHAR( 15), ' +  
            '@cContainerKey             NVARCHAR( 10), ' +  
            '@cContainerNo              NVARCHAR( 20), ' +  
            '@cMBOLKey                  NVARCHAR( 10), ' +  
            '@cSSCCNo                   NVARCHAR( 20), ' +  
            '@cPalletKey                NVARCHAR( 18), ' +  
            '@cTrackNo                  NVARCHAR( 20), ' +  
            '@cOption                   NVARCHAR( 1), '  +  
            '@nErrNo                    INT           OUTPUT,  ' +  
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '  
          
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,   
               @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT  
          
         IF @nErrNo <> 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            GOTO Step_8_Fail          
         END  
      END  
  
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)  
      IF @cExtendedUpdateSP NOT IN ('0', '')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, ' +  
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
     
         SET @cSQLParam =  
            '@nMobile                   INT,           ' +  
            '@nFunc                     INT,           ' +  
            '@cLangCode                 NVARCHAR( 3),  ' +  
            '@nStep                     INT,           ' +  
            '@nInputKey                 INT,           ' +  
            '@cStorerkey                NVARCHAR( 15), ' +  
            '@cContainerKey             NVARCHAR( 10), ' +  
            '@cMBOLKey                  NVARCHAR( 10), ' +  
            '@cSSCCNo                   NVARCHAR( 20), ' +  
            '@cPalletKey                NVARCHAR( 18), ' +  
            '@cTrackNo                  NVARCHAR( 20), ' +  
            '@cOption                   NVARCHAR( 1), '  +  
            '@nErrNo                    INT           OUTPUT,  ' +  
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '  
     
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption,  
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
     
         IF @nErrNo <> 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            GOTO Step_8_Fail  
         END  
      END  
  
      -- Enable fields  
      SET @cFieldAttr02 = ''  
      SET @cFieldAttr04 = ''  
      SET @cFieldAttr06 = ''  
      SET @cFieldAttr08 = ''  
      SET @cFieldAttr10 = ''  
  
      -- Decide where to go  
      IF @cAction = 'PRE'  
      BEGIN  
         IF @nFunc IN (1636, 1649)  
         BEGIN  
            SELECT @cScanCTNCnt = CAST(COUNT(PalletKey) AS CHAR)        
            FROM dbo.CONTAINER CH WITH (NOLOCK)        
            JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (CH.ContainerKey = CD.ContainerKey)        
            WHERE CH.OtherReference = CASE WHEN @cMbolNotFromOtherReference = '1' THEN CH.OtherReference ELSE @cMBOLKEY END  
            AND   CH.MBOLKey = CASE WHEN @cMbolNotFromOtherReference = '1' THEN @cMBOLKEY ELSE CH.MBOLKEY END  
     
            SELECT @cTotalCTNCnt = CAST(COUNT(PD.CartonNo) AS CHAR)  
            FROM dbo.MBOLDETAIL MD WITH (NOLOCK)  
            JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)  
            JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
            WHERE MD.MBOLKey = @cMBOLKEY  
  
            --prepare next screen variable  
            SET @cOutField01 = @cContainerKey  
            SET @cOutField02 = @cMBOLKEY  
            SET @cOutField03 = @cContainerNo  
            SET @cOutField04 = ''  
            SET @cOutField05 = @cScanCnt  
            SET @cOutField06 = RTRIM(@cScanCTNCnt) + '/' + RTRIM(@cTotalCTNCnt)  
            SET @cOutField07 = CASE WHEN @nFunc = 1649 THEN 'SCANNED: ' + RTRIM(@cScanCnt) ELSE '' END   -- (james02)  
  
            SET @nScn = @nPrevScn + 1  
            SET @nStep = @nPrevStep + 1  
         END  
         ELSE  
         BEGIN  
            IF @cVerifyPallet = '1'  
               SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
               FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
               WHERE ContainerKey = @cContainerKey  
                  AND Status = '5'  
  
            SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)  
            IF @cExtendedInfoSP = '0'  
               SET @cExtendedInfoSP = ''  
     
            IF @cExtendedInfoSP <> ''  
            BEGIN  
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
               BEGIN  
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,  ' +  
                     ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @cExtendedInfo1 OUTPUT '  
                  SET @cSQLParam =  
                     '@nMobile         INT, ' +  
                     '@nFunc           INT, ' +  
                     '@cLangCode       NVARCHAR( 3), ' +  
                     '@nStep           INT, ' +  
                     '@nInputKey       INT, ' +  
                     '@cStorerkey      NVARCHAR( 15), ' +  
                     '@cContainerKey   NVARCHAR( 10), ' +  
                     '@cContainerNo    NVARCHAR( 20), ' +  
                     '@cMBOLKey        NVARCHAR( 10), ' +  
                     '@cSSCCNo         NVARCHAR( 20), ' +  
                     '@cPalletKey      NVARCHAR( 18), ' +  
                     '@cTrackNo        NVARCHAR( 20), ' +  
                     '@cOption         NVARCHAR( 1), ' +  
                     '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '  
     
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,    
                     @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @cExtendedInfo1 OUTPUT   
     
                  -- Prepare extended fields  
                  IF @cExtendedInfo1 <> '' SET @cOutField06 = @cExtendedInfo1  
               END  
            END  
           
            --prepare next screen variable  
            SET @cOutField01 = @cContainerKey  
            SET @cOutField02 = @cMBOLKEY  
            SET @cOutField03 = @cContainerNo  
            SET @cOutField04 = ''  
            SET @cOutField05 = @cScanCnt  
  
            SET @nScn = @nPrevScn + 2  
            SET @nStep = @nPrevStep + 2  
         END  
      END  
      ELSE IF @cAction = 'POST'  
      BEGIN  
               -- Prep next screen var  
         SET @cOutField01 = ''  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
  
         SET @nScn = 2190  
         SET @nStep = 1  
      END  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Enable fields  
      SET @cFieldAttr02 = ''  
      SET @cFieldAttr04 = ''  
      SET @cFieldAttr06 = ''  
      SET @cFieldAttr08 = ''  
      SET @cFieldAttr10 = ''  
          
      SET @nErrNo = 0 --(yeekung03)    
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)          
      IF @cExtendedValidateSP NOT IN ('0', '')        
      BEGIN        
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +        
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,  ' +        
            ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
                
         SET @cSQLParam =        
            '@nMobile                   INT,           ' +        
            '@nFunc                     INT,           ' +        
            '@cLangCode                 NVARCHAR( 3),  ' +        
            '@nStep     INT,           ' +        
            '@nInputKey                 INT,           ' +        
            '@cStorerkey                NVARCHAR( 15), ' +        
            '@cContainerKey             NVARCHAR( 10), ' +        
            '@cContainerNo              NVARCHAR( 20), ' +        
            '@cMBOLKey                  NVARCHAR( 10), ' +        
            '@cSSCCNo                   NVARCHAR( 20), ' +        
            '@cPalletKey                NVARCHAR( 18), ' +        
            '@cTrackNo                  NVARCHAR( 20), ' +        
            '@cOption                   NVARCHAR( 1), '  +        
            '@nErrNo                    INT           OUTPUT,  ' +        
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   '        
                
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,         
               @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT        
                
         IF @nErrNo <> 0        
         BEGIN        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')         
            GOTO Step_8_Fail                
         END        
      END      
        
      -- Decide where to go  
      IF @cAction = 'PRE'  
      BEGIN  
         -- Prep next screen var  
         SET @cOutField01 = ''  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
  
         SET @nScn = @nPrevScn  
         SET @nStep = @nPrevStep  
      END  
      ELSE IF @cAction = 'POST'  
      BEGIN  
         IF @nFunc IN (1636, 1649)  
         BEGIN  
            SELECT @cScanCTNCnt = CAST(COUNT(PalletKey) AS CHAR)        
            FROM dbo.CONTAINER CH WITH (NOLOCK)        
            JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (CH.ContainerKey = CD.ContainerKey)        
            WHERE CH.OtherReference = CASE WHEN @cMbolNotFromOtherReference = '1' THEN CH.OtherReference ELSE @cMBOLKEY END  
            AND   CH.MBOLKey = CASE WHEN @cMbolNotFromOtherReference = '1' THEN @cMBOLKEY ELSE CH.MBOLKEY END  
     
            SELECT @cTotalCTNCnt = CAST(COUNT(PD.CartonNo) AS CHAR)  
            FROM dbo.MBOLDETAIL MD WITH (NOLOCK)  
            JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)  
            JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
            WHERE MD.MBOLKey = @cMBOLKEY  
  
            --prepare next screen variable  
            SET @cOutField01 = @cContainerKey  
            SET @cOutField02 = @cMBOLKEY  
            SET @cOutField03 = @cContainerNo  
            SET @cOutField04 = ''  
            SET @cOutField05 = @cScanCnt  
            SET @cOutField06 = RTRIM(@cScanCTNCnt) + '/' + RTRIM(@cTotalCTNCnt)  
            SET @cOutField07 = CASE WHEN @nFunc = 1649 THEN 'SCANNED: ' + RTRIM(@cScanCnt) ELSE '' END   -- (james02)  
  
            SET @nScn = @nPrevScn - 1  
            SET @nStep = @nPrevStep - 1  
         END  
         ELSE  
         BEGIN  
            IF rdt.RDTGetConfig( @nFunc, 'CLOSECONTAINER', @cStorerKey) = '1'  
            BEGIN  
               --prepare prev screen variable  
               SET @cOption = ''  
               SET @cOutField01 = ''  
  
               SET @nScn = @nPrevScn + 3  
               SET @nStep = @nPrevStep + 3  
  
               GOTO Step_8_ExtScn  
            END  
  
            --prepare prev screen variable  
            SET @cOutField01 = ''  
            SET @cOutField02 = ''  
            SET @cOutField03 = ''  
            SET @cOutField04 = ''  
  
            SET @cContainerKey = ''  
            SET @cMBOLKey = ''  
            SET @cContainerNo = ''  
            SET @cSSCCNo = ''  
            SET @cScanCnt = ''  
            SET @cScanCTNCnt = ''  
            SET @cTotalCTNCnt = ''  
  
            SET @nScn = @nPrevScn - 2  
            SET @nStep = @nPrevScn - 2  
         END  
      END  
   END  

   Step_8_ExtScn:
   BEGIN
      SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
      IF @cExtendedScnSP = '0'
         SET @cExtendedScnSP = ''

      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            SET @nExtScnAction = 0
            GOTO Step_99
         END
      END
   END
   GOTO Quit  
  
   Step_8_Fail:  
   BEGIN  
      -- Reset this screen var  
       SET @cOutField02 = ''  
       SET @cOutField04 = ''  
       SET @cOutField06 = ''  
       SET @cOutField08 = ''  
       SET @cOutField10 = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 2  
   END  
   GOTO Quit  
END  
GOTO Quit  

/***********************************************************************************
Step 2. Scn = 2198. Capture data screen
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

      EXEC rdt.rdt_ScanToContainer_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'UPDATE', 
         @cContainerKey, @cContainerNo, @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cData1, @cData2, @cData3, @cData4, @cData5, 
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

     SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
      FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
      WHERE ContainerKey = @cContainerKey  
  
      IF @nFunc IN (1636, 1649)  
      BEGIN  
         -- (james05)  
         SELECT @cScanCTNCnt = CAST(COUNT(PalletKey) AS CHAR)        
         FROM dbo.CONTAINER CH WITH (NOLOCK)        
         JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON (CH.ContainerKey = CD.ContainerKey)        
         WHERE CH.OtherReference = CASE WHEN @cMbolNotFromOtherReference = '1' THEN CH.OtherReference ELSE @cMBOLKEY END  
         AND   CH.MBOLKey = CASE WHEN @cMbolNotFromOtherReference = '1' THEN @cMBOLKEY ELSE CH.MBOLKEY END  
     
         SELECT @cTotalCTNCnt = CAST(COUNT(PD.CartonNo) AS CHAR)  
         FROM dbo.MBOLDETAIL MD WITH (NOLOCK)  
         JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)  
         JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
         WHERE MD.MBOLKey = @cMBOLKEY  
  
         --prepare next screen variable  
         SET @cOutField01 = @cContainerKey  
         SET @cOutField02 = @cMBOLKEY  
         SET @cOutField03 = @cContainerNo  
         SET @cOutField04 = ''  
         SET @cOutField05 = @cScanCnt  
         SET @cOutField06 = RTRIM(@cScanCTNCnt) + '/' + RTRIM(@cTotalCTNCnt)  
         SET @cOutField07 = CASE WHEN @nFunc = 1649 THEN 'SCANNED: ' + RTRIM(@cScanCnt) ELSE '' END   -- (james02)  
  
         -- Go to next screen  
         SET @nScn = @nScn - 7  
         SET @nStep = @nStep - 7  
      END  
      ELSE -- @nFunc = 1637  
      BEGIN  
         IF @cVerifyPallet = '1'  
            SELECT @cScanCnt = CAST(COUNT(PalletKey) AS CHAR)  
            FROM dbo.CONTAINERDETAIL WITH (NOLOCK)  
            WHERE ContainerKey = @cContainerKey  
               AND Status = '5'  
  
         SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)  
         IF @cExtendedInfoSP = '0'  
            SET @cExtendedInfoSP = ''  
     
         IF @cExtendedInfoSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,  ' +  
                  ' @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @cExtendedInfo1 OUTPUT '  
               SET @cSQLParam =  
                  '@nMobile         INT, ' +  
                  '@nFunc           INT, ' +  
                  '@cLangCode       NVARCHAR( 3), ' +  
                  '@nStep           INT, ' +  
                  '@nInputKey       INT, ' +  
                  '@cStorerkey      NVARCHAR( 15), ' +  
                  '@cContainerKey   NVARCHAR( 10), ' +  
                  '@cContainerNo    NVARCHAR( 20), ' +  
                  '@cMBOLKey        NVARCHAR( 10), ' +  
                  '@cSSCCNo         NVARCHAR( 20), ' +  
                  '@cPalletKey      NVARCHAR( 30), ' +  
                  '@cTrackNo        NVARCHAR( 20), ' +  
                  '@cOption         NVARCHAR( 1), ' +  
                  '@cExtendedInfo1  NVARCHAR( 20) OUTPUT '  
     
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cContainerKey, @cContainerNo,    
                  @cMBOLKey, @cSSCCNo, @cPalletKey, @cTrackNo, @cOption, @cExtendedInfo1 OUTPUT   
     
               -- Prepare extended fields  
               IF @cExtendedInfo1 <> '' SET @cOutField06 = @cExtendedInfo1  
            END  
         END  
           
         --prepare next screen variable  
         SET @cOutField01 = @cContainerKey  
         SET @cOutField02 = @cMBOLKEY  
         SET @cOutField03 = @cContainerNo  
         SET @cOutField04 = ''  
         SET @cOutField05 = @cScanCnt  
  
         SET @nPrevScn = @nScn  
         SET @nPrevStep = @nStep  
  
         -- Go to next screen  
         SET @nScn = @nScn - 6  
         SET @nStep = @nStep - 6  
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

     --prepare prev screen variable  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
  
      SET @cContainerKey = ''  
      SET @cMBOLKey = ''  
      SET @cContainerNo = ''  
      SET @cSSCCNo = ''  
      SET @cScanCnt = ''  
      SET @cScanCTNCnt = ''  
      SET @cTotalCTNCnt = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 1

      SET @nScn = @nScn - 8  
      SET @nStep = @nStep - 8  
   END

   Step_9_ExtScn:
   BEGIN
      SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
      IF @cExtendedScnSP = '0'
         SET @cExtendedScnSP = ''

      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            SET @nExtScnAction = 0
            GOTO Step_99
         END
      END
   END
   GOTO Quit
END
GOTO Quit

Step_99:
BEGIN
   SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScnSP = '0'
      SET @cExtendedScnSP = ''

   IF @cExtendedScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
      BEGIN
         DELETE FROM @tExtScnData
         
         EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtendedScnSP,  --1637ExtScn01
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
            @nExtScnAction, 
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

         IF @cExtendedScnSP = 'rdt_1637ExtScn01' 
         BEGIN
            IF @cUDF30 = 'UPDATE'
            BEGIN
               SET @cContainerKey = @cUDF01
               SET @cMBOLKEY = @cUDF02
               SET @cContainerNo = @cUDF03
               SET @cScanCnt = @cUDF04
               SET @cScanCTNCnt = @cUDF05

               --Back to main menu
               IF @cUDF06 = 'BACKTOMENU'
               BEGIN
                  -- Back to menu  
                  SET @nFunc = @nMenu  
                  SET @nScn  = @nMenu  
                  SET @nStep = 0  
               END
            END
         END

         GOTO Quit
      END
   END

   Step_99_Fail:
      GOTO Quit
END

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
  
      V_String1     = @cContainerKey,  
      V_String2     = @cMBOLKey,  
      V_String3     = @cContainerNo,  
      V_String4     = @cSSCCNo,  
      V_String5     = @cScanCnt,  
      V_String6     = @cScanCTNCnt,  
      V_String7     = @cTotalCTNCnt,  
      V_String8     = @cVerifyPallet,  
      V_String9     = @cMbolNotFromOtherReference,  
      V_String10    = @cCloseContainerStatus,  
      V_String11    = @cDefaultContainerType,  
      V_String12    = @cContainerManifest,  
      V_String13    = @cColumnName,  
      V_String14    = @cParam1,  
      V_String15    = @cParam2,  
      V_String16    = @cParam3,  
      V_String17    = @cParam4,  
      V_String18    = @cParam5,  
      V_String19    = @cParamLabel1,  
      V_String20    = @cParamLabel2,  
      V_String21    = @cParamLabel3,  
      V_String22    = @cParamLabel4,  
      V_String23    = @cParamLabel5,  
      V_String24    = @cUDFCriteria,  
      V_String25    = @cCaptureContainerInfoSP,
      V_String26    = @cContainerNoIsOptional,
      V_String27    = @cAction,  
		V_String28    = @cVerifypalletstatus, 
		V_String29    = @cDelList,  --(cc02)
		V_String30    = @cShowPopOutMsg, 
      V_String31    = @cPalletLabel, --(yeekung05)      
		V_String41    = @cPalletKeyPrev, --(cc02)--more then nvarchar(20)

      V_String42    = @cData1,
      V_String43    = @cData2,
      V_String44    = @cData3,
      V_String45    = @cData4,
      V_String46    = @cData5,

      V_FromScn     = @nPrevScn,  
      V_FromStep    = @nPrevStep,  
           
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