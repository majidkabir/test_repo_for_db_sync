SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_Pallet_Build                                       */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: SOS#173267 - Standard/Generic Pallet Build module                 */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2010-05-17 1.0  Vicky    Created                                           */
/* 2013-11-18 1.1  ChewKP   SOS#293509 - ANF Enhancement (ChewKP01)           */
/* 2014-11-25 1.2  Ung      SOS325485 Add pallet criteria screen              */
/* 2015-10-26 1.3  Ung      SOS354305                                         */
/*                          Add CheckPackDetailDropID                         */
/*                          Add CheckPickDetailDropID                         */
/* 2016-06-07 1.4  James    SOS370791-Add config skip ins dropid id (james01) */
/* 2016-10-12 1.5  James    Reset screen variable (james02)                   */
/* 2017-03-07 1.6  Ung      WMS-1284 Add DefaultClosePalletOption             */
/* 2018-01-25 1.7  ChewKP   WMS-3809 Add Print Label Screen (ChewKP02)        */
/* 2019-08-08 1.8  YeeKung  WMS-10083 Add Reopen the palletid (yeekung01)     */  
/* 2020-06-10 1.9  James    WMS-13606 Add capture pallet info (james03)       */
/* 2020-07-25 2.0  Ung      WMS-13505 Add AutoGenDropID, DecodeSP             */
/* 2022-04-20 2.1  Ung      WMS-19340 Expand DropID to 20 chars               */
/* 2021-11-16 2.2  YeeKung  WMS-18255 Add Defaultloc (yeekung02)              */
/* 2023-02-19 2.3  YeeKung  WMS-21738 Extended UCCNo length (yeekung03)       */
/* 2023-02-14 2.4  James    WMS-21690 Add cfg no mix orders pallet (james04)  */
/* 2023-05-05 2.5  YeeKung  WMS-22419 Add decodeSP and V_max (yeekung04)      */
/* 2023-11-22 2.6  YeeKung  UWP-11213 Fix Bug   (yeekung05)                   */
/* 2023-12-03 2.7  YeeKung  UWP-11635 Fix Bug   (yeekung06)                   */
/* 2024-12-02 3.0.0 LJQ006  FCR-1406. Created                                 */
/******************************************************************************/

CREATE    PROC [RDT].[rdtfnc_Pallet_Build](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @b_success           INT,
   @cParamLabel1        NVARCHAR( 20),
   @cParamLabel2        NVARCHAR( 20),
   @cParamLabel3        NVARCHAR( 20),
   @cParamLabel4        NVARCHAR( 20),
   @cParamLabel5        NVARCHAR( 20)

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cDropID             NVARCHAR(20),
   @cUCCNo              NVARCHAR(20),
   @cOrderkey           NVARCHAR(10),
   @cDropLOC            NVARCHAR(10),
   @cOption             NVARCHAR(1),

   @nUCCCnt             INT,
   @nLoadkeyCnt         INT,
   @cBarcode            NVARCHAR( 2000), --(yeekung03)
   @cMax                NVARCHAR( MAX), --(yeekung03)

   -- (ChewKP01)
   @cSkipDropLoc        NVARCHAR(1),
   @cSQL                NVARCHAR(MAX), -- (ChewKP01)
   @cSQLParam           NVARCHAR(MAX), -- (ChewKP01)
   @cExtendedValidateSP NVARCHAR(30),   -- (ChewKP01)
   @cExtendedUpdateSP   NVARCHAR(30),   -- (ChewKP01)
   @nTotalUCCCount      INT,            -- (ChewKP01)
   @cPalletCriteria     NVARCHAR( 20),
   @cParam1             NVARCHAR( 20),
   @cParam2             NVARCHAR( 20),
   @cParam3             NVARCHAR( 20),
   @cParam4             NVARCHAR( 20),
   @cParam5             NVARCHAR( 20),
   
   @cCheckPackDetailDropID    NVARCHAR( 1),
   @cCheckPickDetailDropID    NVARCHAR( 1),
   @cPltBuildNotInsDropID     NVARCHAR( 20), -- (james01)
   @cPltBuildSkipValidateUCC  NVARCHAR( 20), -- (james01)
   @cExtendedInfoSP           NVARCHAR( 20), -- (james01)
   @cExtendedInfo1            NVARCHAR( 20), -- (james01)
   @cDefaultClosePalletOption NVARCHAR( 1),
   @cPrintLabel               NVARCHAR( 1),  -- (ChewKP02) 
   @cOpenPallet               NVARCHAR( 1),  -- (yeekung01)   
   @cCapturePalletInfoSP      NVARCHAR( 20), -- (james03)
   @cAutoGenDropID            NVARCHAR( 1),
   @cDecodeSP                 NVARCHAR( 20), 
   @cData1                    NVARCHAR( 60),
   @cData2                    NVARCHAR( 60),
   @cData3                    NVARCHAR( 60),
   @cData4                    NVARCHAR( 60),
   @cData5                    NVARCHAR( 60),
   @tCaptureVar               VARIABLETABLE,
   @nAfterStep                INT,
   @nAfterScn                 INT,
   @cDefaultLoc               NVARCHAR(20),
   @nTranCount                INT,
   @cPalletNoMixOrderKey      NVARCHAR( 1),
   @nOrdCnt                   INT = 0,

   @tExtScnData               VariableTable,
   @cExtScnSP                 NVARCHAR(20),
   @nAction                   INT,

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
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @nTotalUCCCount   = V_Integer1,

   @cMax             = V_Max,
   
   @cOrderkey        = V_Orderkey,
   @cDropID          = V_String1,
   @cUCCNo           = V_String2,
   @cDropLOC         = V_String5,
   @cOption          = V_String6,
   @cSkipDropLoc     = V_string7, -- (ChewKP01)
   @cExtendedValidateSP = V_String8, -- (ChewKP01)
   @cExtendedUpdateSP   = V_String9, -- (ChewKP01)
   @cPalletNoMixOrderKey = V_String10,
   @cPalletCriteria     = V_String11,
   @cParam1             = V_String12,
   @cParam2             = V_String13,
   @cParam3             = V_String14,
   @cParam4             = V_String15,
   @cParam5             = V_String16,
   
   @cCheckPackDetailDropID    = V_String17,
   @cCheckPickDetailDropID    = V_String18,
   @cPltBuildNotInsDropID     = V_String19,
   @cPltBuildSkipValidateUCC  = V_String20,
   @cExtendedInfoSP           = V_String21,
   @cDefaultClosePalletOption = V_String22,
   @cPrintLabel               = V_String23, -- (ChewKP02)
   @cOpenPallet               = V_String24, -- (yeekung01) 
   @cExtendedInfo1            = V_String25, -- (yeekung01)  
   @cCapturePalletInfoSP      = V_String26, -- (james03)  
   @cAutoGenDropID            = V_String27,
   @cDecodeSP                 = V_String28,
   @cDefaultLoc               = V_String29, --(yeekung02)
   @cExtScnSP                 = V_String30,

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
IF @nFunc = 1641
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1641
   IF @nStep = 1 GOTO Step_1   -- Scn = 2320   Drop ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 2321   LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 2322   UCC No
   IF @nStep = 4 GOTO Step_4   -- Scn = 2323   Close Pallet?
   IF @nStep = 5 GOTO Step_5   -- Scn = 2324   Pallet criteria
   IF @nStep = 6 GOTO Step_6   -- Scn = 2325   Print Label ? 
   IF @nStep = 7 GOTO Step_7   -- Scn = 2326   Reopen the Pallet 
   IF @nStep = 8 GOTO Step_8   -- Scn = 2327   Capture Pallet Info
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1641)
********************************************************************************/
Step_0:
BEGIN
   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- Get storer config
   SET @cAutoGenDropID = rdt.RDTGetConfig( @nFunc, 'AutoGenDropID', @cStorerKey)
   SET @cCheckPackDetailDropID = rdt.RDTGetConfig( @nFunc, 'CheckPackDetailDropID', @cStorerKey)
   SET @cCheckPickDetailDropID = rdt.RDTGetConfig( @nFunc, 'CheckPickDetailDropID', @cStorerKey)
   SET @cSkipDropLoc = rdt.RDTGetConfig( @nFunc, 'SkipFromLocScn', @cStorerKey)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDefaultClosePalletOption = rdt.RDTGetConfig( @nFunc, 'DefaultClosePalletOption', @cStorerKey)
   IF @cDefaultClosePalletOption = '0'
      SET @cDefaultClosePalletOption = ''
   SET @cPalletCriteria = rdt.RDTGetConfig( @nFunc, 'PalletCriteria', @cStorerKey)
   IF @cPalletCriteria = '0'
      SET @cPalletCriteria = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtScnSP = '0'
      SET @cExtScnSP = ''

   --(yeekung02)
   SET @cDefaultLoc = rdt.RDTGetConfig( @nFunc, 'DefaultLoc', @cStorerKey)

   -- (james01)
   SET @cPltBuildNotInsDropID = rdt.RDTGetConfig( @nFunc, 'PltBuildNotInsDropID', @cStorerKey)
   IF @cPltBuildNotInsDropID = ''
      SET @cPltBuildNotInsDropID = '0'

   SET @cPltBuildSkipValidateUCC = rdt.RDTGetConfig( @nFunc, 'PltBuildSkipValidateUCC', @cStorerKey)
   IF @cPltBuildSkipValidateUCC = ''
      SET @cPltBuildSkipValidateUCC = '0'

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   --(ChewKP02) 
   SET @cPrintLabel = rdt.RDTGetConfig( @nFunc, 'PrintLabel', @cStorerKey)
   IF @cPrintLabel = '0'
      SET @cPrintLabel = ''
      
   --(yeekung01)   
   SET @cOpenPallet = rdt.RDTGetConfig( @nFunc, 'OpenPallet', @cStorerKey)  
   IF @cOpenPallet = '0'  
      SET @cOpenPallet = ''  

   -- (james03)
   SET @cCapturePalletInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePalletInfoSP', @cStorerKey)
   IF @cCapturePalletInfoSP = '0'
      SET @cCapturePalletInfoSP = ''

   -- (james04)
   SET @cPalletNoMixOrderKey = rdt.RDTGetConfig( @nFunc, 'PalletNoMixOrderKey', @cStorerKey)

   -- initialise all variable
   SET @cDropID = ''
   SET @cUCCNo = ''
   SET @cOrderKey = ''
   SET @cDropLOC = ''
   SET @cOption = ''
   SET @nTotalUCCCount = 0
   SET @cParam1 = ''
   SET @cParam2 = ''
   SET @cParam3 = ''
   SET @cParam4 = ''
   SET @cParam5 = ''

   -- Pallet criteria
   IF @cPalletCriteria <> ''
   BEGIN
      -- Get pallet criteria label
      SELECT
         @cParamLabel1 = UDF01,
         @cParamLabel2 = UDF02,
         @cParamLabel3 = UDF03,
         @cParamLabel4 = UDF04,
         @cParamLabel5 = UDF05
     FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTBuildPL'
         AND Code = @cPalletCriteria
         AND StorerKey = @cStorerKey

      -- Check pallet criteria setup
      IF @cParamLabel1 = '' AND
         @cParamLabel2 = '' AND
         @cParamLabel3 = '' AND
         @cParamLabel4 = '' AND
         @cParamLabel5 = ''
      BEGIN
         SET @nErrNo = 69191
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

      -- Go to pallet criteria screen
      SET @nScn  = 2324
      SET @nStep = 5
   END
   ELSE
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = ''

      -- Go to DropID screen
      SET @nScn  = 2320
      SET @nStep = 1
   END
END
GOTO Quit


/********************************************************************************
Step 1. screen = 2320
   DROP ID (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropID = @cInField01

      --When PalletID is blank
      IF @cDropID = ''
      BEGIN
         -- Auto generate DropID
         IF @cAutoGenDropID = '1'
         BEGIN
            SET @b_Success = 0
            EXECUTE dbo.nspg_GetKey
               'ID',
               10 ,
               @cDropID    OUTPUT,
               @b_Success  OUTPUT,
               @nErrNo     OUTPUT,
               @cErrMsg    OUTPUT
            IF @b_Success <> 1
            BEGIN
               SET @nErrNo = 155601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenDropID Fail
               GOTO Step_1_Fail
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 69192
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DROP ID req
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END

      --DROP ID Exists
      IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cDropID AND Status = '9')
      BEGIN
         SET @nErrNo = 69193
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DROP ID Exists
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Check from id format (james01)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0
      BEGIN
         SET @nErrNo = 69207
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_1_Fail
      END

      IF @cOpenPallet='1'  
      BEGIN  
         IF EXISTS (SELECT 1 FROM PALLET WITH (NOLOCK)   
         WHERE PALLETKEY=@cDropID AND Storerkey=@cStorerKey AND STATUS=9)  
         BEGIN  
            SET @cOutField01=''  
              
            SET @nScn = @nScn + 6  
            SET @nStep = @nStep + 6  
            GOTO Quit  
         END  
      END  
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, @cPrevLoadKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cUCCNo        NVARCHAR( 20), ' +
               '@cPrevLoadKey  NVARCHAR( 10), ' +
               '@cParam1       NVARCHAR(20),  ' +
               '@cParam2       NVARCHAR(20),  ' +
               '@cParam3       NVARCHAR(20),  ' +
               '@cParam4       NVARCHAR(20),  ' +
               '@cParam5       NVARCHAR(20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, '', @cParam1, @cParam2, @cParam3, @cParam4, @cParam5,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_1_Fail
            END
         END
      END

      -- Pallet criteria
      IF @cPalletCriteria <> ''
      BEGIN
         -- Get DropID info
         SELECT
            @cParam1 = LEFT( ISNULL( UDF01, ''), 20),
            @cParam2 = LEFT( ISNULL( UDF02, ''), 20),
            @cParam3 = LEFT( ISNULL( UDF03, ''), 20),
            @cParam4 = LEFT( ISNULL( UDF04, ''), 20),
            @cParam5 = LEFT( ISNULL( UDF05, ''), 20)
         FROM DropID WITH (NOLOCK)
         WHERE DropID = @cDropID
      END

      -- Extended validate
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' +
               ' @cExtendedInfo1 OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cParam1         NVARCHAR(20),  ' +
               '@cParam2         NVARCHAR(20),  ' +
               '@cParam3         NVARCHAR(20),  ' +
               '@cParam4         NVARCHAR(20),  ' +
               '@cParam5         NVARCHAR(20),  ' +
               '@cExtendedInfo1  NVARCHAR(20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5,
               @cExtendedInfo1 OUTPUT
         END
      END

      IF @cSkipDropLoc = '1'
      BEGIN
         SET @cDropLOC = ''
         --prepare next screen variable
         SET @cOutField01 = @cDropID
         SET @cOutField02 = CASE WHEN ISNULL(@cDefaultLoc,'')='' THEN @cDropLOC ELSE @cDefaultLoc END --(yeekung02)
         SET @cOutField03 = ''
         SET @cOutField04 = ''      -- (james02)
         SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo1, '') <> '' THEN @cExtendedInfo1 ELSE '' END     -- (james02)

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
      ELSE
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = @cDropID
         SET @cOutField02 = CASE WHEN ISNULL(@cDefaultLoc,'')='' THEN '' ELSE @cDefaultLoc END --(yeekung02)

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Set the entry point
      IF @cPalletCriteria <> ''
      BEGIN
         -- Get report info
         SELECT
            @cParamLabel1 = UDF01,
            @cParamLabel2 = UDF02,
            @cParamLabel3 = UDF03,
            @cParamLabel4 = UDF04,
            @cParamLabel5 = UDF05
        FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTBuildPL'
            AND Code = @cPalletCriteria
            AND StorerKey = @cStorerKey

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

         -- Prepare next screen var
         SET @cOutField01 = @cParamLabel1
         SET @cOutField02 = @cParam1
         SET @cOutField03 = @cParamLabel2
         SET @cOutField04 = @cParam2
         SET @cOutField05 = @cParamLabel3
         SET @cOutField06 = @cParam3
         SET @cOutField07 = @cParamLabel4
         SET @cOutField08 = @cParam4
         SET @cOutField09 = @cParamLabel5
         SET @cOutField10 = @cParam5

         -- Go to pallet criteria screen
         SET @nScn  = 2324
         SET @nStep = 5
      END
      ELSE
      BEGIN
         -- EventLog - Sign Out Function
         EXEC RDT.rdt_STD_EventLog
          @cActionType = '9', -- Sign Out function
          @cUserID     = @cUserName,
          @nMobileNo   = @nMobile,
          @nFunctionID = @nFunc,
          @cFacility   = @cFacility,
          @cStorerKey  = @cStorerkey

         SET @cOutField01 = ''

         -- Back to menu
         SET @nFunc = @nMenu
         SET @nScn  = @nMenu
         SET @nStep = 0
      END
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cDropID = ''
      SET @cUCCNo = ''
      SET @cOrderkey = ''
      SET @cDropLOC = ''
      SET @cOption = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2321
   DROP ID (Field01)
   LOC     (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropLOC = @cInField02

      --When Pallet LOC is blank
      IF ISNULL(RTRIM(@cDropLOC), '') = ''
      BEGIN
         SET @nErrNo = 69194
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END

      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cDropLOC
      SET @cMax = ''

      IF @cPltBuildNotInsDropID = '0'
      BEGIN
         SET @nTotalUCCCount = 0
         SELECT @nTotalUCCCount = Count (ChildID)
         FROM dbo.DropIDDetail WITH (NOLOCK)
         WHERE DropID = @cDropID

         SET @cOutField04 = @nTotalUCCCount -- (ChewKP01)
      END
      ELSE
         SET @cOutField04 = ''

      SET @cOutField05 = ''               -- (james02)

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cDropID = ''
      SET @cUCCNo = ''
      SET @cOrderkey = ''
      SET @cDropLOC = ''
      SET @cOption = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   Step_2_Jump:
   IF @cExtScnSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
   BEGIN
      SET @nAction = 0
      GOTO Step_99
   END

   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cUCCNo = ''
      SET @cOrderkey = ''
      SET @cDropLOC = ''
      SET @cOption = ''

      SET @cOutField01 = @cDropID
      SET @cOutField02 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 2322)
   DROP ID:    (Field01)
   LOC:        (Field02)
   UCC NO:     (Field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCCNo = @cMax
      SET @cBarcode = @cMax  --(yeekung03)

      --When UCC NO is blank
      IF @cUCCNo = ''
      BEGIN
         SET @nErrNo = 69195
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC# req
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_3_Fail
      END

      IF ISNULL(@cDecodeSP,'') <> ''
      BEGIN
         IF @cDecodeSP = '1'  
         BEGIN  
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,   --(yeekung03)
               @cUCCNo  = @cUCCNo  OUTPUT,   
               @nErrNo  = @nErrNo  OUTPUT,   
               @cErrMsg = @cErrMsg OUTPUT,  
               @cType   = 'UCCNo'  
  
            -- Decode is optional, allow some barcode to pass thru
            SET @nErrNo = 0
         END
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID,@cBarcode, @cPrevLoadKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' +
               ' @cUCCNo OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cBarcode      NVARCHAR( 2000),' +
               '@cPrevLoadKey  NVARCHAR( 10), ' +
               '@cParam1       NVARCHAR(20),  ' +
               '@cParam2       NVARCHAR(20),  ' +
               '@cParam3       NVARCHAR(20),  ' +
               '@cParam4       NVARCHAR(20),  ' +
               '@cParam5       NVARCHAR(20),  ' +
               '@cUCCNo        NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cBarcode, '', @cParam1, @cParam2, @cParam3, @cParam4, @cParam5,
                @cUCCNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      -- PickDetail
      IF @cCheckPickDetailDropID = '1'
      BEGIN
         -- Check UCC valid
         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cUCCNo)
         BEGIN
            SET @nErrNo = 69196
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC#
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         -- PackDetail
         IF @cCheckPackDetailDropID = '1'
         BEGIN
            -- Check UCC valid
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cUCCNo)
            BEGIN
               SET @nErrNo = 69197
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC#
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_3_Fail
            END

            -- Check UCC multi carton no
            IF EXISTS( SELECT 1
               FROM dbo.PackDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cUCCNo
               HAVING COUNT( DISTINCT PD.CartonNo) > 1)
            BEGIN
               SET @nErrNo = 69198
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCMultiCtnNo
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_3_Fail
            END
         END
         ELSE
         BEGIN
            IF @cPltBuildSkipValidateUCC = '0'
            BEGIN
               -- Check UCC valid
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cUCCNo)
               BEGIN
                  SET @nErrNo = 69199
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC#
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  GOTO Step_3_Fail
               END

               -- Check UCC multi carton no
               IF EXISTS( SELECT 1
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                  WHERE PD.StorerKey = @cStorerKey
                     AND PD.LabelNo = @cUCCNo
                  HAVING COUNT( DISTINCT PD.CartonNo) > 1)
               BEGIN
                  SET @nErrNo = 69200
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCMultiCtnNo
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  GOTO Step_3_Fail
               END
            END
         END
      END

      -- Check UCC build on multi pallets
      IF EXISTS (SELECT 1
         FROM DropID D WITH (NOLOCK)
            JOIN dbo.DropIDDetail DID WITH (NOLOCK) ON (D.DropID = DID.DropID)
         WHERE D.DropIDType = 'B'
            AND DID.ChildID = @cUCCNo)
      BEGIN
         SET @nErrNo = 69201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC# Exists
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_3_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, @cPrevLoadKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cUCCNo        NVARCHAR( 20), ' +
               '@cPrevLoadKey  NVARCHAR( 10), ' +
               '@cParam1       NVARCHAR(20),  ' +
               '@cParam2       NVARCHAR(20),  ' +
               '@cParam3       NVARCHAR(20),  ' +
               '@cParam4       NVARCHAR(20),  ' +
               '@cParam5       NVARCHAR(20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, '', @cParam1, @cParam2, @cParam3, @cParam4, @cParam5,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_3_Fail
            END
         END
      END

      IF @cPltBuildNotInsDropID = '0'
      BEGIN
         SET @nTranCount = @@TRANCOUNT    
         BEGIN TRAN  -- Begin our own transaction    
         SAVE TRAN InsDropId -- For rollback or commit only our own transaction    

         -- Create DropID
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cDropID)
         BEGIN
            IF @cPalletCriteria <> ''
               INSERT INTO dbo.DROPID (Dropid, Droploc, DropIDType, Status, UDF01, UDF02, UDF03, UDF04, UDF05)
               VALUES (@cDropID, @cDropLOC, 'B', '0', @cParam1, @cParam2, @cParam3, @cParam4, @cParam5)
            ELSE
               INSERT INTO dbo.DROPID (Dropid, Droploc, DropIDType, Status)
               VALUES (@cDropID, @cDropLOC, 'B', '0')
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins DROPIDFail
               GOTO RollBackTran_InsDropId
            END
         END

         -- Create DropIDDetail
         INSERT INTO dbo.DropIDDetail (Dropid, ChildID) VALUES (@cDropID, @cUCCNo )
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 69203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins DPDtl Fail
            GOTO RollBackTran_InsDropId
         END

         -- (james04)
         IF @cPalletNoMixOrderKey = '1'
         BEGIN
         	SET @nOrdCnt = 0
         	
         	IF @cCheckPickDetailDropID = '1'
         	BEGIN
         		SELECT @nOrdCnt = COUNT( DISTINCT PD.OrderKey)
         		FROM dbo.PickDetail PD WITH (NOLOCK)
         		WHERE Storerkey = @cStorerKey
         		AND   EXISTS ( SELECT 1 
         		               FROM dbo.DropIDDetail DD WITH (NOLOCK)
         		               JOIN dbo.Dropid D WITH (NOLOCK) ON ( DD.Dropid = D.Dropid)
         		               WHERE D.Dropid = @cDropID
         		               AND   D.Droploc = @cDropLOC
         		               AND   D.[Status] = '0'
         		               AND   D.DropIDType = 'B'
         		               AND   PD.DropID = DD.ChildId)
         	END
         	ELSE
         	BEGIN
         		IF @cCheckPackDetailDropID = '1'
         		BEGIN
         		   SELECT @nOrdCnt = COUNT( DISTINCT PH.OrderKey)
         		   FROM dbo.PackDetail PD WITH (NOLOCK)
         		   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         		   WHERE PD.Storerkey = @cStorerKey
         		   AND   EXISTS ( SELECT 1 
         		                  FROM dbo.DropIDDetail DD WITH (NOLOCK)
         		                  JOIN dbo.Dropid D WITH (NOLOCK) ON ( DD.Dropid = D.Dropid)
         		                  WHERE D.Dropid = @cDropID
         		                  AND   D.Droploc = @cDropLOC
         		                  AND   D.[Status] = '0'
         		                  AND   D.DropIDType = 'B'
         		                  AND   PD.DropID = DD.ChildId)
         		END
         		ELSE
         		BEGIN
         		   SELECT @nOrdCnt = COUNT( DISTINCT PH.OrderKey)
         		   FROM dbo.PackDetail PD WITH (NOLOCK)
         		   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         		   WHERE PD.Storerkey = @cStorerKey
         		   AND   EXISTS ( SELECT 1 
         		                  FROM dbo.DropIDDetail DD WITH (NOLOCK)
         		                  JOIN dbo.Dropid D WITH (NOLOCK) ON ( DD.Dropid = D.Dropid)
         		                  WHERE D.Dropid = @cDropID
         		                  AND   D.Droploc = @cDropLOC
         		                  AND   D.[Status] = '0'
         		                  AND   D.DropIDType = 'B'
         		                  AND   PD.LabelNo = DD.ChildId)
         		END
         		
         		IF @nOrdCnt > 1
         		BEGIN
                  SET @nErrNo = 69212
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Plt Mix Orders
                  GOTO RollBackTran_InsDropId
               END
         	END
         END
         
         COMMIT TRAN InsDropId    
    
         GOTO Quit_InsDropId    
    
         RollBackTran_InsDropId:    
            ROLLBACK TRAN -- Only rollback change made here    

         Quit_InsDropId:    
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
               COMMIT TRAN    
      END

      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cDropID, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3), ' +
               '@cUserName      NVARCHAR( 18), ' +
               '@cFacility      NVARCHAR( 5), ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cDropID        NVARCHAR( 20), ' +
               '@cUCCNo         NVARCHAR( 20), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cDropID, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO QUIT
         END
      END

      -- Extended validate
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' +
               ' @cExtendedInfo1 OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cParam1         NVARCHAR(20),  ' +
               '@cParam2         NVARCHAR(20),  ' +
               '@cParam3         NVARCHAR(20),  ' +
               '@cParam4         NVARCHAR(20),  ' +
               '@cParam5         NVARCHAR(20),  ' +
               '@cExtendedInfo1  NVARCHAR(20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5,
               @cExtendedInfo1 OUTPUT
         END
      END
      
      DECLARE @cToID NVARCHAR( 18)
      SET @cToID = LEFT( @cDropID, 18)

      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cToLocation   = @cDropLoc,
         @cToID         = @cToID,
         @cDropID       = @cDropID, 
         @cRefNo2       = @cOrderkey,
         @cRefNo3       = @cUCCNo

      --prepare next screen variable
      SET @cUCCNo = ''
      SET @cOrderkey = ''
      SET @cOption = ''

      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cDropLOC
      SET @cOutField03 = ''
      SET @cMax        = ''  

      IF @cPltBuildNotInsDropID = '0'
      BEGIN
         -- (ChewKP01)
         SET @nTotalUCCCount = 0
         SELECT @nTotalUCCCount = Count (ChildID)
         FROM dbo.DropIDDetail WITH (NOLOCK)
         WHERE DropID = @cDropID

         SET @cOutField04 = @nTotalUCCCount -- (ChewKP01)
      END
      ELSE
         SET @cOutField04 = ''

      SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo1, '') <> '' THEN @cExtendedInfo1 ELSE '' END

      -- Stay at same screen scan next UCC
      SET @nScn = @nScn
      SET @nStep = @nStep
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --Go to Close Pallet
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cMax = ''

      SET @cOption = ''
      SET @cInField01 = @cDefaultClosePalletOption
      SET @cOutField01 = @cDefaultClosePalletOption

      -- Capture ASN Info
      IF @cCapturePalletInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCapturePalletInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePalletInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, ' +
               ' @cDropID, @cDropLOC, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, ' + 
               ' @cData1, @cData2, @cData3, @cData4, @cData5, ' +
               ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
               ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, ' +
               ' @tCaptureVar,        @nAfterScn   OUTPUT, @nAfterStep  OUTPUT, @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cType        NVARCHAR( 10), ' +
               ' @cDropID      NVARCHAR( 20), ' +
               ' @cDropLOC     NVARCHAR( 10), ' +
               ' @cUCCNo       NVARCHAR( 20), ' +               
               ' @cParam1      NVARCHAR( 20), ' +
               ' @cParam2      NVARCHAR( 20), ' +
               ' @cParam3      NVARCHAR( 20), ' +
               ' @cParam4      NVARCHAR( 20), ' +
               ' @cParam5      NVARCHAR( 10), ' +
               ' @cOption      NVARCHAR( 1),  ' +
               ' @cData1       NVARCHAR( 60), ' +
               ' @cData2       NVARCHAR( 60), ' +
               ' @cData3       NVARCHAR( 60), ' +
               ' @cData4       NVARCHAR( 60), ' +
               ' @cData5       NVARCHAR( 60), ' +
               ' @cOutField01  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField02  NVARCHAR( 60)  OUTPUT, ' +
               ' @cOutField03  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField04  NVARCHAR( 60)  OUTPUT, ' +
               ' @cOutField05  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField06  NVARCHAR( 60)  OUTPUT, ' +
               ' @cOutField07  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField08  NVARCHAR( 60)  OUTPUT, ' +
               ' @cOutField09  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField10  NVARCHAR( 60)  OUTPUT, ' +
               ' @tCaptureVar  VariableTable  READONLY, ' +
               ' @nAfterScn    INT            OUTPUT, ' +
               ' @nAfterStep   INT            OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'DISPLAY', 
               @cDropID, @cDropLOC, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, 
               @cData1, @cData2, @cData3, @cData4, @cData5, 
               @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, 
               @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, 
               @tCaptureVar,        @nAfterScn   OUTPUT, @nAfterStep  OUTPUT, @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Refno1

            -- Go to next screen
            SET @nScn = @nScn + 5
            SET @nStep = @nStep + 5
            GOTO Quit
         END
      END
            
      IF @cPrintLabel = '1'
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cUCCNo = ''

      SET @cUCCNo = ''
      SET @cOrderkey = ''
      SET @cOption = ''

      -- Reset this screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cDropLOC
      SET @cOutField03 = ''

      IF @cPltBuildNotInsDropID = '0'
         SET @cOutField04 = @nTotalUCCCount
  END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 2323
   OPTION (Field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER / ESC
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF ISNULL(RTRIM(@cOption), '') = ''
      BEGIN
         SET @nErrNo = 69204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_4_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 69205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_4_Fail
      END

      -- Close Pallet
      IF @cOption = '1'
      BEGIN
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cDropID, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3), ' +
                  '@cUserName      NVARCHAR( 18), ' +
                  '@cFacility      NVARCHAR( 5), ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cDropID        NVARCHAR( 20), ' +
                  '@cUCCNo         NVARCHAR( 20), ' +
                  '@nErrNo         INT           OUTPUT, ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cDropID, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO QUIT
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.DROPID WITH (ROWLOCK) SET
               Status = '9'
            WHERE DropID = @cDropID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 69206
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd DROPIDFail
               GOTO QUIT
            END
         END
      END

      SET @cDropID = ''
      SET @cUCCNo = ''
      SET @cOrderkey = ''
      SET @cDropLOC = ''
      SET @cOption = ''

      -- Prepare next screen var
      SET @cOutField01 = '' -- DropID

      -- Go to DropID screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit


/***********************************************************************************
Scn = 2324. Parameter screen
   Report       (field11)
   Param1 label (field01)
   Param1       (field02, input)
   Param2 label (field03)
   Param2       (field04, input)
   Param3 label (field05)
   Param3       (field06, input)
   Param4 label (field07)
   Param4       (field08, input)
   Param5 label (field09)
   Param5       (field10, input)
***********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cParam1 = @cInField02
      SET @cParam2 = @cInField04
      SET @cParam3 = @cInField06
      SET @cParam4 = @cInField08
      SET @cParam5 = @cInField10

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, @cPrevLoadKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cUCCNo        NVARCHAR( 20), ' +
               '@cPrevLoadKey  NVARCHAR( 10), ' +
               '@cParam1       NVARCHAR(20),  ' +
               '@cParam2       NVARCHAR(20),  ' +
               '@cParam3       NVARCHAR(20),  ' +
               '@cParam4       NVARCHAR(20),  ' +
               '@cParam5       NVARCHAR(20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, '', @cParam1, @cParam2, @cParam3, @cParam4, @cParam5,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

         END
      END

      -- Go to DropID screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
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
   END

   -- Prepare prev screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''

   -- Enable field
   SET @cFieldAttr02 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr10 = ''
END
GOTO Quit


/********************************************************************************
Step 6. screen = 2325
   OPTION (Field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF ISNULL(RTRIM(@cOption), '') = ''
      BEGIN
         SET @nErrNo = 69208
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_6_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 69209
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_6_Fail
      END

      -- Close Pallet
      IF @cOption = '1'
      BEGIN
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cDropID, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3), ' +
                  '@cUserName      NVARCHAR( 18), ' +
                  '@cFacility      NVARCHAR( 5), ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cDropID        NVARCHAR( 20), ' +
                  '@cUCCNo         NVARCHAR( 20), ' +
                  '@nErrNo         INT           OUTPUT, ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cDropID, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO QUIT
            END
         END
         
      END

--      SET @cDropID = ''
--      SET @cUCCNo = ''
--      SET @cOrderkey = ''
--      SET @cDropLOC = ''
--      SET @cOption = ''

      -- Prepare next screen var
      SET @cOutField01 = '' -- Option

      -- Go to Close Pallet screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cDropLOC
      SET @cOutField03 = ''

      IF @cPltBuildNotInsDropID = '0'
      BEGIN
         SET @nTotalUCCCount = 0
         SELECT @nTotalUCCCount = Count (ChildID)
         FROM dbo.DropIDDetail WITH (NOLOCK)
         WHERE DropID = @cDropID

         SET @cOutField04 = @nTotalUCCCount -- (ChewKP01)
      END
      ELSE
         SET @cOutField04 = ''

      SET @cOutField05 = ''               -- (james02)

      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
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
Step 7. screen = 2326  
   OPTION (Field01, input)  
********************************************************************************/  
Step_7:  
BEGIN  
   IF @nInputKey = 1   
   BEGIN  
      -- Screen mapping  
      SET @cOption = @cInField01  
  
      IF ISNULL(RTRIM(@cOption), '') = ''  
      BEGIN  
         SET @nErrNo = 69210  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_7_Fail  
      END  
  
      IF @cOption <> '1' AND @cOption <> '2'  
      BEGIN  
         SET @nErrNo = 69211  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_7_Fail  
      END  
  
      -- Reopen the Pallet  
      IF @cOption = '1'  
      BEGIN  
         IF @cExtendedUpdateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cDropID, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3), ' +
                  '@cUserName      NVARCHAR( 18), ' +
                  '@cFacility      NVARCHAR( 5), ' +
                  '@cStorerKey     NVARCHAR( 15), ' +
                  '@cDropID        NVARCHAR( 20), ' +
                  '@cUCCNo         NVARCHAR( 20), ' +
                  '@nErrNo         INT           OUTPUT, ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cDropID, @cUCCNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO QUIT
            END
         END  
           
      END  
  
      -- Extended validate  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo1 = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, ' +  
               ' @cExtendedInfo1 OUTPUT '  
            SET @cSQLParam =  
               '@nMobile         INT,           ' +  
               '@nFunc           INT,           ' +  
               '@cLangCode       NVARCHAR( 3),  ' +                 '@nStep           INT,           ' +  
               '@nInputKey       INT,           ' +  
               '@cStorerKey      NVARCHAR( 15), ' +  
               '@cDropID         NVARCHAR( 20), ' +  
               '@cUCCNo          NVARCHAR( 20), ' +  
               '@cParam1         NVARCHAR(20),  ' +  
               '@cParam2         NVARCHAR(20),  ' +  
               '@cParam3         NVARCHAR(20),  ' +  
               '@cParam4         NVARCHAR(20),  ' +  
               '@cParam5         NVARCHAR(20),  ' +  
               '@cExtendedInfo1  NVARCHAR(20)  OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cDropID, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5,  
               @cExtendedInfo1 OUTPUT  
         END  
      END  
  
      IF @cSkipDropLoc = '1'  
      BEGIN  
         SET @cDropLOC = ''  
         --prepare next screen variable  
         SET @cOutField01 = @cDropID  
         SET @cOutField02 = @cDropLOC  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''      -- (james02)  
         SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo1, '') <> '' THEN @cExtendedInfo1 ELSE '' END     -- (james02)  
  
         SET @nScn = @nScn - 4  
         SET @nStep = @nStep - 4  
      END  
      ELSE  
      BEGIN  
         --prepare next screen variable  
         SET @cOutField01 = @cDropID  
         SET @cOutField02 = ''  
  
         SET @nScn = @nScn -5  
         SET @nStep = @nStep -5  
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''           
  
      SET @nScn = @nScn - 6  
      SET @nStep = @nStep - 6  
   END  
  
   GOTO Quit  
  
   Step_7_Fail:  
   BEGIN  
      SET @cOption = ''  
      SET @cOutField01 = ''  
   END  
END  
GOTO Quit  

/***********************************************************************************
Step 8. Scn = 5641. Capture Pallet Info screen
   RefNo1   (field01)
   Input1   (field02, input)
   .
   .
   .
   RefNo5   (field09)
   Input5   (field10, input) 
***********************************************************************************/  
Step_8:  
BEGIN  
   IF @nInputKey = 1      -- ENTER
   BEGIN
      -- Screen mapping
      SET @cData1 = @cInField02
      SET @cData2 = @cInField04
      SET @cData3 = @cInField06
      SET @cData4 = @cInField08
      SET @cData5 = @cInField10

      -- Capture ASN Info
      IF @cCapturePalletInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCapturePalletInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePalletInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cType, ' +
               ' @cDropID, @cDropLOC, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, ' + 
               ' @cData1, @cData2, @cData3, @cData4, @cData5, ' +
               ' @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, ' +
               ' @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, ' +
               ' @tCaptureVar,        @nAfterScn   OUTPUT, @nAfterStep  OUTPUT,  @nErrNo     OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cType        NVARCHAR( 10), ' +
               ' @cDropID      NVARCHAR( 20), ' +
               ' @cDropLOC     NVARCHAR( 10), ' +
               ' @cUCCNo       NVARCHAR( 20), ' +               
               ' @cParam1      NVARCHAR( 20), ' +
               ' @cParam2      NVARCHAR( 20), ' +
               ' @cParam3      NVARCHAR( 20), ' +
               ' @cParam4      NVARCHAR( 20), ' +
               ' @cParam5      NVARCHAR( 10), ' +
               ' @cOption      NVARCHAR( 1),  ' +
               ' @cData1       NVARCHAR( 60), ' +
               ' @cData2       NVARCHAR( 60), ' +
               ' @cData3       NVARCHAR( 60), ' +
               ' @cData4       NVARCHAR( 60), ' +
               ' @cData5       NVARCHAR( 60), ' +
               ' @cOutField01  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField02  NVARCHAR( 60)  OUTPUT, ' +
               ' @cOutField03  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField04  NVARCHAR( 60)  OUTPUT, ' +
               ' @cOutField05  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField06  NVARCHAR( 60)  OUTPUT, ' +
               ' @cOutField07  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField08  NVARCHAR( 60)  OUTPUT, ' +
               ' @cOutField09  NVARCHAR( 20)  OUTPUT, ' +
               ' @cOutField10  NVARCHAR( 60)  OUTPUT, ' +
               ' @tCaptureVar  VariableTable  READONLY, ' +
               ' @nAfterScn    INT            OUTPUT, ' +
               ' @nAfterStep   INT            OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'UPDATE', 
               @cDropID, @cDropLOC, @cUCCNo, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, 
               @cData1, @cData2, @cData3, @cData4, @cData5, 
               @cOutField01 OUTPUT, @cOutField02 OUTPUT, @cOutField03 OUTPUT, @cOutField04 OUTPUT, @cOutField05 OUTPUT, 
               @cOutField06 OUTPUT, @cOutField07 OUTPUT, @cOutField08 OUTPUT, @cOutField09 OUTPUT, @cOutField10 OUTPUT, 
               @tCaptureVar,        @nAfterScn   OUTPUT, @nAfterStep  OUTPUT,  @nErrNo     OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nAfterStep = 1
            BEGIN
               -- Prep next screen var
               SET @cOutField01 = ''

               -- Go to DropID screen
               SET @nScn  = @nScn - 7
               SET @nStep = @nStep - 7
               
               GOTO Quit
            END
   
            IF @nAfterStep = 5
            BEGIN
               IF @cPrintLabel = '1'
               BEGIN
                  SET @cOutField01 = ''
                  SET @cOutField02 = ''
                  SET @cOutField03 = ''
                  SET @cOutField04 = ''

                  SET @nScn = @nScn - 2
                  SET @nStep = @nStep - 2
               END
               ELSE
               BEGIN
                  SET @nScn = @nScn - 4
                  SET @nStep = @nStep - 4
               END
               
               GOTO Quit
            END 
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cDropLOC = ''
      --prepare next screen variable
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cDropLOC
      SET @cOutField03 = ''
      SET @cOutField04 = ''      -- (james02)
      SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo1, '') <> '' THEN @cExtendedInfo1 ELSE '' END     -- (james02)

      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END
END
GOTO Quit

Step_99:
BEGIN
   IF @cExtScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
      BEGIN

         DELETE FROM @tExtScnData
         INSERT INTO @tExtScnData (Variable, Value) VALUES    
         ('@cDropLOC',        @cDropLOC)

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
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(),
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility,
      Printer       = @cPrinter,

      V_Integer1    = @nTotalUCCCount,

      V_MAX         = @cMax,
      
      V_Orderkey    = @cOrderkey,
      V_String1     = @cDropID,
      V_String2     = @cUCCNo,
      V_String5     = @cDropLOC,
      V_String6     = @cOption,
      V_String7     = @cSkipDropLoc,
      V_String8     = @cExtendedValidateSP,
      V_String9     = @cExtendedUpdateSP,
      V_String10    = @cPalletNoMixOrderKey,
      V_String11    = @cPalletCriteria,
      V_String12    = @cParam1,
      V_String13    = @cParam2,
      V_String14    = @cParam3,
      V_String15    = @cParam4,
      V_String16    = @cParam5,
      V_String17    = @cCheckPackDetailDropID,
      V_String18    = @cCheckPickDetailDropID,
      V_String19    = @cPltBuildNotInsDropID,
      V_String20    = @cPltBuildSkipValidateUCC,
      V_String21    = @cExtendedInfoSP,
      V_String22    = @cDefaultClosePalletOption,
      V_String23    = @cPrintLabel, -- (ChewKP02)
      V_String24    = @cOpenPallet,  
      V_String25    = @cExtendedInfo1,     
      V_String26    = @cCapturePalletInfoSP,
      V_String27    = @cAutoGenDropID,
      V_String28    = @cDecodeSP,
      V_String29    = @cDefaultLoc, --(yeekung02)
      V_String30    = @cExtScnSP,
      
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