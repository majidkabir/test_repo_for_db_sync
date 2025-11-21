SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Scan_To_Pallet                               */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2010-03-08 1.0  James      Created                                   */
/* 2012-03-21 1.1  Ung        SOS239386 Add carton type                 */
/* 2015-01-12 1.2  ChewKP     SOS#329818 -- Add Pallet Info Screen      */
/*                            (ChewKP01)                                */
/* 2016-01-11 1.3  Ung        SOS360339 Add ExtendedUpdateSP            */
/*                            Add pallet LOC                            */
/*                            Add check pallet key format               */
/*                            Fix pallet key not save                   */
/* 2016-08-29 1.4  Ung        IN00132118 Fix pallet check               */
/*                            Performance tuning                        */
/* 2018-05-07 1.5  James      WMS4941-Change to use rdt_Print (james01) */
/* 2020-05-12 1.6  Ung        WMS-13218 Add ConfirmSP                   */
/*                            Add CapturePackInfo (after)               */
/* 2021-01-13 1.7  James      WMS-15914 Add config skip print pack list */
/*                            screen (james02)                          */
/* 2021-01-18 1.8  James      WMS-15913 Add Decode Case Id (james03)    */
/*                            Add Close Pallet Add ExtendedInfoSP       */
/* 2022-05-26 1.9  James      WMS-19694 Add CapturePackInfoSP (james04) */
/*                            Add ExtendedValidateSP at step 1          */
/* 2022-10-17 2.0  yeekung    WMS-20927. Fixed paper to paper (yeekung01)  */ 
/* 2023-01-12 2.1  James      WMS-21135 Bug fix on extinfo @st1(james05)*/
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Scan_To_Pallet] (
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
   @nRowCount   INT, 
   @nTranCount  INT, 
   @nTotalCases INT,
   @cSQL        NVARCHAR( MAX),
   @cSQLParam   NVARCHAR( MAX)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nCurScn    INT,  -- Current screen variable
   @nStep      INT,
   @nCurStep   INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cPrinter   NVARCHAR( 10),

   @cPickSlipNo         NVARCHAR( 10), 
   @nCartonNo           INT, 
   @nQty                INT,
   @cSKU                NVARCHAR( 20),
   @cLOC                NVARCHAR( 10),
   @nFromStep           INT,
   @nFromScreen         INT,

   @cCaseID             NVARCHAR( 20),
   @cCartonType         NVARCHAR( 10),
   @cCapturePackInfo    NVARCHAR( 10),
   @cCapturePalletInfo  NVARCHAR( 1),  -- (ChewKP01)
   @cAllowWeightZero    NVARCHAR( 1),
   @cAllowCubeZero      NVARCHAR( 1),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cLength             NVARCHAR( 5),   -- (ChewKP01)
   @cWidth              NVARCHAR( 5),   -- (ChewKP01)
   @cHeight             NVARCHAR( 5),   -- (ChewKP01)
   @cGrossWeight        NVARCHAR( 5),   -- (ChewKP01)
   @cExtendedValidateSP NVARCHAR( 20),
   @cDefaultWeight      NVARCHAR( 1),
   @cSkipPrintPackList  NVARCHAR( 1),
   @cPalletKey          NVARCHAR( 30),
   @cClosePallet        NVARCHAR( 1),
   @cMBOLKey            NVARCHAR( 10),
   @cDecodeSP           NVARCHAR( 20),  
   @cCaseIDBarcode      NVARCHAR( 60),
   @cOrderKey           NVARCHAR( 10),
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cCapturePackInfoSP  NVARCHAR( 20),
   @cWeight             NVARCHAR( 10),
   @cCube               NVARCHAR( 10),
   @cRefNo              NVARCHAR( 20),

   @cInField01 NVARCHAR( 60), @cOutField01 NVARCHAR( 60), @cFieldAttr01 NVARCHAR( 1), 
   @cInField02 NVARCHAR( 60), @cOutField02 NVARCHAR( 60), @cFieldAttr02 NVARCHAR( 1), 
   @cInField03 NVARCHAR( 60), @cOutField03 NVARCHAR( 60), @cFieldAttr03 NVARCHAR( 1), 
   @cInField04 NVARCHAR( 60), @cOutField04 NVARCHAR( 60), @cFieldAttr04 NVARCHAR( 1), 
   @cInField05 NVARCHAR( 60), @cOutField05 NVARCHAR( 60), @cFieldAttr05 NVARCHAR( 1), 
   @cInField06 NVARCHAR( 60), @cOutField06 NVARCHAR( 60), @cFieldAttr06 NVARCHAR( 1), 
   @cInField07 NVARCHAR( 60), @cOutField07 NVARCHAR( 60), @cFieldAttr07 NVARCHAR( 1), 
   @cInField08 NVARCHAR( 60), @cOutField08 NVARCHAR( 60), @cFieldAttr08 NVARCHAR( 1), 
   @cInField09 NVARCHAR( 60), @cOutField09 NVARCHAR( 60), @cFieldAttr09 NVARCHAR( 1), 
   @cInField10 NVARCHAR( 60), @cOutField10 NVARCHAR( 60), @cFieldAttr10 NVARCHAR( 1), 
   @cInField11 NVARCHAR( 60), @cOutField11 NVARCHAR( 60), @cFieldAttr11 NVARCHAR( 1), 
   @cInField12 NVARCHAR( 60), @cOutField12 NVARCHAR( 60), @cFieldAttr12 NVARCHAR( 1), 
   @cInField13 NVARCHAR( 60), @cOutField13 NVARCHAR( 60), @cFieldAttr13 NVARCHAR( 1), 
   @cInField14 NVARCHAR( 60), @cOutField14 NVARCHAR( 60), @cFieldAttr14 NVARCHAR( 1), 
   @cInField15 NVARCHAR( 60), @cOutField15 NVARCHAR( 60), @cFieldAttr15 NVARCHAR( 1)

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
   @cPrinter   = Printer_paper,

   @cPickSlipNo = V_PickSlipNo, 
   @nCartonNo   = V_CartonNo, 
   @nQTY        = V_QTY,
   @cSKU        = V_SKU,
   @cLOC        = V_LOC,
   @nFromStep   = V_FromStep,
   @nFromScreen = V_FromScn,

   @cSkipPrintPackList  = V_String1,
   @cClosePallet        = V_String2,
   @cCaseID             = V_String3,
   @cCartonType         = V_String4,
   @cCapturePackInfo    = V_String5,
   @cCapturePalletInfo  = V_String6,
   @cAllowWeightZero    = V_String7,
   @cAllowCubeZero      = V_String8,
   @cExtendedUpdateSP   = V_String9, -- (ChewKP01)
   @cLength             = V_String10, -- (ChewKP01)
   @cWidth              = V_String11, -- (ChewKP01)
   @cHeight             = V_String12, -- (ChewKP01)
   @cGrossWeight        = V_String13, -- (ChewKP01)
   @cExtendedValidateSP = V_String14,
   @cDefaultWeight      = V_String15,
   @cDecodeSP           = V_String16,
   @cExtendedInfoSP     = V_String17,
   @cCapturePackInfoSP  = V_String18,

   @cPalletKey          = V_String41,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,   @cFieldAttr01 = FieldAttr01, 
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,   @cFieldAttr02 = FieldAttr02, 
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,   @cFieldAttr03 = FieldAttr03, 
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,   @cFieldAttr04 = FieldAttr04, 
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,   @cFieldAttr05 = FieldAttr05, 
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,   @cFieldAttr06 = FieldAttr06, 
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,   @cFieldAttr07 = FieldAttr07, 
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,   @cFieldAttr08 = FieldAttr08, 
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,   @cFieldAttr09 = FieldAttr09, 
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,   @cFieldAttr10 = FieldAttr10, 
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,   @cFieldAttr11 = FieldAttr11, 
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,   @cFieldAttr12 = FieldAttr12, 
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,   @cFieldAttr13 = FieldAttr13, 
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,   @cFieldAttr14 = FieldAttr14, 
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,   @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1638  -- RDT Scan To Pallet
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Scan To Pallet
   IF @nStep = 1 GOTO Step_1   -- Scn = 2250. Pallet#
   IF @nStep = 2 GOTO Step_2   -- Scn = 2251. Pallet#, Carton type
   IF @nStep = 3 GOTO Step_3   -- Scn = 2252. Pallet#, Carton type, Case ID, # of Case
   IF @nStep = 4 GOTO Step_4   -- Scn = 2253. Print Pallet Packing List Report
   IF @nStep = 5 GOTO Step_5   -- Scn = 2254. Pallet Info
   IF @nStep = 6 GOTO Step_6   -- Scn = 2255. Carton type, weight, cube, refno
   IF @nStep = 7 GOTO Step_7   -- Scn = 2256. Close Pallet Option
END
--RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1638. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Storer configure
   SET @cAllowCubeZero = rdt.rdtGetConfig( @nFunc, 'AllowCubeZero', @cStorerKey)
   SET @cAllowWeightZero = rdt.rdtGetConfig( @nFunc, 'AllowWeightZero', @cStorerKey)
   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfo', @cStorerKey)
   SET @cCapturePalletInfo = rdt.RDTGetConfig( @nFunc, 'CapturePalletInfo', @cStorerKey)
   SET @cDefaultWeight = rdt.RDTGetConfig( @nFunc, 'DefaultWeight', @cStorerKey)

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)
   IF @cLOC = '0'
      SET @cLOC = ''

   SET @cSkipPrintPackList = rdt.RDTGetConfig( @nFunc, 'SkipPrintPackList', @cStorerKey)

   SET @cClosePallet = rdt.RDTGetConfig( @nFunc, 'ClosePallet', @cStorerKey)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)  
   IF @cDecodeSP = '0'  
      SET @cDecodeSP = ''  

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- Set the entry point
   SET @nScn = 2250
   SET @nStep = 1

   -- Initiate var
   SET @cPalletKey  = ''
   SET @nFromStep   = 0
   SET @nFromScreen = 0
   SET @cLength      = ''
   SET @cWidth       = ''
   SET @cHeight      = ''
   SET @cGrossWeight = ''

   -- Init screen
   SET @cOutField01 = '' -- PalletKey
   SET @cOutField02 = @cLOC 
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 2250.
   PalletKey   (field01, input)
   LOC         (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
      SET @cPalletKey = @cInField01
      SET @cLOC = @cInField02

      -- Validate blank
      IF ISNULL(@cPalletKey, '') = ''
      BEGIN
         SET @nErrNo = 68866
         SET @cErrMsg = rdt.rdtgetmessage( 68866, @cLangCode,'DSP') --PLT# required
         GOTO Step_1_Fail
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletKey', @cPalletKey) = 0
      BEGIN
         SET @nErrNo = 68889
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_1_Fail
      END

      -- Check if Palletkey exists in Pallet table
      IF NOT EXISTS (SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey)
      BEGIN
         -- Not exists then auto create pallet manifest header
         BEGIN TRAN

         INSERT INTO dbo.Pallet (PalletKey, StorerKey, Status, AddDate, AddWho, EditDate, EditWho) VALUES
         (@cPalletKey, @cStorerKey, '0', GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME())

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 68867
            SET @cErrMsg = rdt.rdtgetmessage( 68867, @cLangCode,'DSP') --Ins PLT Fail
            GOTO Step_1_Fail
         END

         COMMIT TRAN
      END
      ELSE  -- Palletkey exists
      BEGIN
         -- If storerkey not same with RDT login storerkey
         IF NOT EXISTS (SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 68868
            SET @cErrMsg = rdt.rdtgetmessage( 68868, @cLangCode,'DSP') --Invalid Storer
            GOTO Step_1_Fail
         END
      END
      SET @cOutField01 = @cPalletKey

      -- Check blank LOC
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 68887
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LOC required
         GOTO Quit
      END

      -- Check LOC valid
      IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC)
      BEGIN
         SET @nErrNo = 68888
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid LOC
         GOTO Quit
      END
      SET @cOutField02 = @cLOC

      -- ExtendedValidateSP
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
            ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cPalletKey   NVARCHAR( 30), ' +
            '@cCartonType  NVARCHAR( 10), ' +
            '@cCaseID      NVARCHAR( 20), ' +
            '@cLOC         NVARCHAR( 10), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' + 
            '@cLength      NVARCHAR(5),   ' + 
            '@cWidth       NVARCHAR(5),   ' + 
            '@cHeight      NVARCHAR(5),   ' + 
            '@cGrossWeight NVARCHAR(5),   ' + 
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
            @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_3_Fail
      END
      
      IF @cCapturePackInfoSP = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = '' -- CartonType

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE IF @cCapturePalletInfo = '1' -- (ChewKP01)
      BEGIN

         SELECT @cLength = Length
               ,@cWidth  = Width
               ,@cHeight = Height
               ,@cGrossWeight = GrossWgt
         FROM dbo.Pallet WITH (NOLOCK)
         WHERE PalletKey = @cPalletKey


         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = @cLength
         SET @cOutField03 = @cWidth
         SET @cOutField04 = @cHeight
         SET @cOutField05 = @cGrossWeight

         SET @nFromStep   = @nStep
         SET @nFromScreen = @nScn

         -- Go to next screen
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4
      END
      ELSE
      BEGIN
         -- Get total case
         SELECT @nTotalCases = ISNULL(COUNT(1), '') FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND PalletKey = @cPalletKey

         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = ''   -- Case ID
         SET @cOutField03 = ''   -- Case ID
         SET @cOutField04 = @nTotalCases   -- # OF Case ID
         SET @cOutField15 = ''   -- (james05)
         SET @cCaseID = ''

         -- Go to next screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   SET @cOutField01 = ''
   SET @cPalletKey = ''

END
GOTO Quit

/********************************************************************************
Step 2. Scn = 2251.
   PalletKey    (field01)
   CartonType   (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cCartonType = @cInField02

      -- Validate blank
      IF ISNULL(@cCartonType, '') = ''
      BEGIN
         SET @nErrNo = 68879
         SET @cErrMsg = rdt.rdtgetmessage( 68879, @cLangCode,'DSP') --NeedCartonType
         GOTO Step_2_Fail
      END

      -- Validate carton type
	   IF NOT EXISTS( SELECT 1
   	   FROM Cartonization WITH (NOLOCK)
   	      INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
   	   WHERE Storer.StorerKey = @cStorerKey
   	      AND Cartonization.CartonType = @cCartonType)
      BEGIN
         SET @nErrNo = 68880
         SET @cErrMsg = rdt.rdtgetmessage( 68880, @cLangCode,'DSP') --Bad CartonType
         GOTO Step_2_Fail
      END


      IF @cCapturePalletInfo = '1' -- (ChewKP01)
      BEGIN

         SELECT @cLength = Length
               ,@cWidth  = Width
               ,@cHeight = Height
               ,@cGrossWeight = GrossWgt
         FROM dbo.Pallet WITH (NOLOCK)
         WHERE PalletKey = @cPalletKey

         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = @cLength
         SET @cOutField03 = @cWidth
         SET @cOutField04 = @cHeight
         SET @cOutField05 = @cGrossWeight

         SET @nFromStep   = @nStep
         SET @nFromScreen = @nScn

         -- Go to next screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
      END
      ELSE
      BEGIN
         -- Get total case
         SELECT @nTotalCases = ISNULL(COUNT(1), '') FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND PalletKey = @cPalletKey

         -- Prepare next screen var
         SET @cCaseID = ''
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = @cCartonType
         SET @cOutField03 = '' -- Case ID
         SET @cOutField04 = CAST( @nTotalCases AS NVARCHAR( 5))

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      IF @cClosePallet = '1'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = ''   -- Option

         -- Go to Close Pallet screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END
      ELSE
      BEGIN
         -- Prep prev screen var
         SET @cOutField01 = ''   -- PalletKey
         SET @cOutField02 = @cLOC

         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1         
      END
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cCartonType = ''
      SET @cOutField02 = '' -- Carton type
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 2252.
   PalletKey    (field01)
   Carton type  (field02)
   Case ID      (field03, input)
   NoOfCases    (field04)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- screen mapping
      SET @cCaseID = @cInField03
      SET @cCaseIDBarcode = @cInField03
      
      -- Validate blank
      IF ISNULL(@cCaseID, '') = ''
      BEGIN
         SET @nErrNo = 68869
         SET @cErrMsg = rdt.rdtgetmessage( 68869, @cLangCode,'DSP') --Case ID req
         GOTO Step_3_Fail
      END

      -- Decode    
      -- Standard decode    
      IF @cDecodeSP = '1'    
      BEGIN    
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cCaseIDBarcode,     
            @cUCCNo  = @cCaseID OUTPUT,   
            @nErrNo  = @nErrNo  OUTPUT,   
            @cErrMsg = @cErrMsg OUTPUT,  
            @cType   = 'UCCNo'  
    
         IF @nErrNo <> 0    
            GOTO Step_3_Fail    
      END    
      ELSE    
      BEGIN  
         IF @cDecodeSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
                  ' @cPalletKey, @cCartonType, @cMBOLKey, @cTrackNo OUTPUT, @cOrderKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
               SET @cSQLParam =  
                  '@nMobile         INT,           ' +  
                  '@nFunc           INT,           ' +  
                  '@cLangCode       NVARCHAR( 3),  ' +  
                  '@nStep           INT,           ' +  
                  '@nInputKey       INT,           ' +  
                  '@cFacility       NVARCHAR( 5),  ' +  
                  '@cStorerKey      NVARCHAR( 15), ' +  
                  '@cPalletKey      NVARCHAR( 20), ' +   
                  '@cCartonType     NVARCHAR( 10), ' +   
                  '@cMBOLKey        NVARCHAR( 10), ' +   
                  '@cTrackNo        NVARCHAR( 60)  OUTPUT, ' +   
                  '@cOrderKey       NVARCHAR( 10)  OUTPUT, ' +   
                  '@nErrNo          INT            OUTPUT, ' +  
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT  '  
  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,   
                  @cPalletKey, @cCartonType, @cMBOLKey, @cCaseIDBarcode OUTPUT, @cOrderKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT   
  
               IF @nErrNo <> 0  
               BEGIN  
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg  
                  GOTO Quit  
               END  
            
               -- (james03)
               SET @cCaseID = LEFT( @cCaseIDBarcode, 20)
            END  
         END  
      END  
      
      -- Check for duplicate
      IF EXISTS (SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND CaseID = @cCaseID)
      BEGIN
         SET @nErrNo = 68870
         SET @cErrMsg = rdt.rdtgetmessage( 68870, @cLangCode,'DSP') --Case ID exists
         GOTO Step_3_Fail
      END

      -- Check if the scanned case id storerkey same with login storerkey
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cCaseID)
      BEGIN
         SET @nErrNo = 68871
         SET @cErrMsg = rdt.rdtgetmessage( 68871, @cLangCode,'DSP') --Invalid Storer
         GOTO Step_3_Fail
      END

      -- Get PackDetailInfo
      SET @cPickSlipNo = ''
      SET @nCartonNo = 0
      SET @cSKU = ''
      SET @nQty = 0
      SELECT TOP 1
         @cPickSlipNo = PickSlipNo,
         @nCartonNo = CartonNo,
         @cSKU = ISNULL(SKU, ''),
         @nQty = ISNULL(Qty, 0) 
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE LabelNo = @cCaseID
         AND StorerKey = @cStorerKey
      ORDER BY LabelLine

      -- ExtendedValidateSP
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
            ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cPalletKey   NVARCHAR( 30), ' +
            '@cCartonType  NVARCHAR( 10), ' +
            '@cCaseID      NVARCHAR( 20), ' +
            '@cLOC         NVARCHAR( 10), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' + 
            '@cLength      NVARCHAR(5),   ' + 
            '@cWidth       NVARCHAR(5),   ' + 
            '@cHeight      NVARCHAR(5),   ' + 
            '@cGrossWeight NVARCHAR(5),   ' + 
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
            @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_3_Fail
      END

      SET @cCapturePackInfo = ''
      IF @cCapturePackInfoSP <> ''
      BEGIN
         -- Custom SP to get PackInfo setup
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cPalletKey, @cCaseID, @cLOC, @cSKU, @nQTY, ' +
               ' @cCapturePackInfo  OUTPUT, ' +
               ' @cCartonType       OUTPUT, ' +
               ' @cWeight           OUTPUT, ' +
               ' @cCube             OUTPUT, ' +
               ' @cRefNo            OUTPUT, ' +
               ' @nErrNo            OUTPUT, ' +
               ' @cErrMsg           OUTPUT  '
            SET @cSQLParam =
               '@nMobile            INT,           ' +
               '@nFunc              INT,           ' +
               '@cLangCode          NVARCHAR( 3),  ' +
               '@nStep              INT,           ' +
               '@nInputKey          INT,           ' +
               '@cFacility          NVARCHAR( 5),  ' +
               '@cStorerKey         NVARCHAR( 15), ' +
               '@cPalletKey         NVARCHAR( 30), ' +
               '@cCaseID            NVARCHAR( 20), ' +
               '@cLOC               NVARCHAR( 10), ' +
               '@cSKU               NVARCHAR( 20), ' +
               '@nQTY               INT, ' +
               '@cCapturePackInfo   NVARCHAR( 3)  OUTPUT, ' +
               '@cCartonType        NVARCHAR( 10) OUTPUT, ' +
               '@cWeight            NVARCHAR( 10) OUTPUT, ' +
               '@cCube              NVARCHAR( 10) OUTPUT, ' +
               '@cRefNo             NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo             INT           OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20) OUTPUT  ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cPalletKey, @cCaseID, @cLOC, @cSKU, @nQTY,
               @cCapturePackInfo    OUTPUT,
               @cCartonType         OUTPUT,
               @cWeight             OUTPUT,
               @cCube               OUTPUT,
               @cRefNo              OUTPUT,
               @nErrNo              OUTPUT,
               @cErrMsg             OUTPUT
         END
         ELSE
            -- Setup is non SP
            SET @cCapturePackInfo = @cCapturePackInfoSP
      END

      -- Capture pack info (after)
      IF CHARINDEX( '2', @cCapturePackInfo) <> 0 AND -- Capture pack info (after)
        (CHARINDEX( 'T', @cCapturePackInfo) <> 0 OR  -- CartonType
         CHARINDEX( 'C', @cCapturePackInfo) <> 0 OR  -- Cube
         CHARINDEX( 'W', @cCapturePackInfo) <> 0 OR  -- Weight
         CHARINDEX( 'R', @cCapturePackInfo) <> 0)    -- RefNo
      BEGIN
         -- Prepare LOC screen var
         SET @cOutField01 = '' -- @cCartonType
         SET @cOutField02 = '' -- @cWeight
         SET @cOutField03 = '' -- @cCube
         SET @cOutField04 = '' -- @cRefNo
   
         -- Enable disable field
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'W', @cCapturePackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'C', @cCapturePackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cCapturePackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr08 = '' -- QTY
   
         -- Position cursor
         IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
         IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
         IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
         IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4

         -- Go to pack info screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
         
         GOTO Quit
      END
      
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_Scan_To_Pallet -- For rollback or commit only our own transaction

      -- Confirm
      EXEC rdt.rdt_Scan_To_Pallet_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPalletKey       = @cPalletKey      
         ,@cLOC             = @cLOC            
         ,@cCaseID          = @cCaseID         
         ,@cCapturePackInfo = @cCapturePackInfo
         ,@cCartonType      = @cCartonType     
         ,@cWeight          = '' --@cWeight         
         ,@cCube            = '' --@cCube           
         ,@cRefNo           = '' --@cRefNo
         ,@cPickSlipNo      = @cPickSlipNo
         ,@nCartonNo        = @nCartonNo
         ,@cSKU             = @cSKU
         ,@nQTY             = @nQTY
         ,@nErrNo           = @nErrNo  OUTPUT
         ,@cErrMsg          = @cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_Scan_To_Pallet
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         GOTO Step_3_Fail
      END

      -- ExtendedUpdate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nAfterStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
            ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nAfterStep   INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cPalletKey   NVARCHAR( 30), ' +
            '@cCartonType  NVARCHAR( 10), ' +
            '@cCaseID      NVARCHAR( 20), ' +
            '@cLOC         NVARCHAR( 10), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' + 
            '@cLength      NVARCHAR(5),   ' + 
            '@cWidth       NVARCHAR(5),   ' + 
            '@cHeight      NVARCHAR(5),   ' + 
            '@cGrossWeight NVARCHAR(5),   ' + 
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
            @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_Scan_To_Pallet
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Step_3_Fail
         END
      END

      COMMIT TRAN rdtfnc_Scan_To_Pallet
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

      SELECT @nTotalCases = ISNULL(COUNT(1), '') 
      FROM dbo.PalletDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PalletKey = @cPalletKey

      -- ExtendedValidateSP
      IF @cExtendedInfoSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
            ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @cExtendedInfo OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@nStep         INT,           ' +
            '@nInputKey     INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerkey    NVARCHAR( 15), ' +
            '@cPalletKey    NVARCHAR( 30), ' +
            '@cCartonType   NVARCHAR( 10), ' +
            '@cCaseID       NVARCHAR( 20), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cSKU          NVARCHAR( 20), ' +
            '@nQTY          INT,           ' + 
            '@cLength       NVARCHAR(5),   ' + 
            '@cWidth        NVARCHAR(5),   ' + 
            '@cHeight       NVARCHAR(5),   ' + 
            '@cGrossWeight  NVARCHAR(5),   ' + 
            '@cExtendedInfo NVARCHAR( 20)  OUTPUT ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
            @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @cExtendedInfo OUTPUT

         IF @cExtendedInfo <> ''
            SET @cOutField15 = @cExtendedInfo
      END

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cCartonType
      SET @cOutField03 = ''   -- Case ID
      SET @cOutField04 = @nTotalCases   -- # OF Case ID

      -- Remain in same screen
      SET @nScn = @nScn
      SET @nStep = @nStep
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      IF @cSkipPrintPackList= '1'
      BEGIN
         IF @cClosePallet = '1'
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = ''   -- Option

            -- Go to Close Pallet screen
            SET @nScn = @nScn + 4
            SET @nStep = @nStep + 4
         END
         ELSE
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- PalletKey
            SET @cOutField02 = @cLOC

            -- Go to PalletKey screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2            
         END
      END
      ELSE
      BEGIN
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         SET @cOutField01 = ''   -- Option
      END
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cCaseID = ''
      SET @cOutField03 = '' -- CASE ID
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 2253.
   OPTION        (field02, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 68874
         SET @cErrMsg = rdt.rdtgetmessage( 68874, @cLangCode,'DSP') --Invalid Option
         GOTO Step_4_Fail
      END

      -- user wannt to print
      IF @cOption = '1'
      BEGIN
		   IF ISNULL(@cPrinter, '') = ''
		   BEGIN
	         SET @nErrNo = 68875
	         SET @cErrMsg = rdt.rdtgetmessage( 68875, @cLangCode, 'DSP') --NoLoginPrinter
	         GOTO Step_4_Fail
		   END

         DECLARE @cDataWindow NVARCHAR( 50)
         DECLARE @cTargetDB   NVARCHAR( 10)
         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')
	      FROM RDT.RDTReport WITH (NOLOCK)
	      WHERE StorerKey = @cStorerKey
	         AND ReportType = 'PACKLIST'

         IF ISNULL(@cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 68876
            SET @cErrMsg = rdt.rdtgetmessage( 68876, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Step_4_Fail
         END

         IF ISNULL(@cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 68877
            SET @cErrMsg = rdt.rdtgetmessage( 68877, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Step_4_Fail
         END

         DECLARE @tPACKLIST AS VariableTable  
         INSERT INTO @tPACKLIST (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)  
         INSERT INTO @tPACKLIST (Variable, Value) VALUES ( '@cPalletKey',  @cPalletKey)  
  
         -- Print label  
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPrinter,   
            'PACKLIST', -- Report type  
            @tPACKLIST, -- Report params  
            'rdtfnc_Scan_To_Pallet',   
            @nErrNo  OUTPUT,  
            @cErrMsg OUTPUT   
  
         IF @nErrNo <> 0  
         BEGIN  
            ROLLBACK TRAN  
            SET @nErrNo = 68878  
            SET @cErrMsg = rdt.rdtgetmessage( 68878, @cLangCode, 'DSP') --'InsertPRTFail'  
            GOTO Step_4_Fail  
         END  
      END

      -- ExtendedUpdate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nAfterStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
            ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nAfterStep   INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cPalletKey   NVARCHAR( 30), ' +
            '@cCartonType  NVARCHAR( 10), ' +
            '@cCaseID      NVARCHAR( 20), ' +
            '@cLOC         NVARCHAR( 10), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' + 
            '@cLength      NVARCHAR(5),   ' + 
            '@cWidth       NVARCHAR(5),   ' + 
            '@cHeight      NVARCHAR(5),   ' + 
            '@cGrossWeight NVARCHAR(5),   ' + 
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
            @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_4_Fail
      END

      IF @cClosePallet = '1'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = ''   -- Option

         -- Go to Close Pallet screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- PalletKey
         SET @cOutField02 = @cLOC

         -- Go to PalletKey screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3         
      END
   END

   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 2254.
   PalletKey    (field01)
   Lenght       (field02, input)
   Width        (field03, input)
   Height       (field04, input)
   Gross Weight (field05, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cLength      = @cInField02
      SET @cWidth       = @cInField03
      SET @cHeight      = @cInField04
      SET @cGrossWeight = @cInField05

      IF ISNULL(RTRIM(@cLength), '') <> ''
      BEGIN
         IF rdt.rdtIsValidQTY( @cLength, 20) = 0
         BEGIN
            SET @nErrNo = 68882
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidValue
            GOTO Step_5_Fail
         END
      END

      IF ISNULL(RTRIM(@cWidth), '') <> ''
      BEGIN
         IF rdt.rdtIsValidQTY( @cWidth, 20) = 0
         BEGIN
            SET @nErrNo = 68883
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidValue
            GOTO Step_5_Fail
         END
      END

      IF ISNULL(RTRIM(@cHeight), '') <> ''
      BEGIN
         IF rdt.rdtIsValidQTY( @cHeight, 20) = 0
         BEGIN
            SET @nErrNo = 68884
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidValue
            GOTO Step_5_Fail
         END
      END

      IF ISNULL(RTRIM(@cGrossWeight), '') <> ''
      BEGIN
         IF rdt.rdtIsValidQTY( @cGrossWeight, 20) = 0
         BEGIN
            SET @nErrNo = 68885
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidValue
            GOTO Step_5_Fail
         END
      END


      UPDATE dbo.Pallet WITH (ROWLOCK)
      SET  Length      = @cLength
         , Width       = @cWidth
         , Height      = @cHeight
         , GrossWgt = @cGrossWeight
      WHERE PalletKey = @cPalletKey

      IF @@ERROR <> 0
      BEGIN
            SET @nErrNo = 68886
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InsPalletFail
            GOTO Step_5_Fail
      END

      -- Get total case
      SELECT @nTotalCases = ISNULL(COUNT(1), '') FROM dbo.PalletDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PalletKey = @cPalletKey

      -- Prepare next screen var
      SET @cCaseID = ''
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cCartonType
      SET @cOutField03 = '' -- Case ID
      SET @cOutField04 = CAST( @nTotalCases AS NVARCHAR( 5))

      -- Go to next screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

   END

   IF @nInputKey = 0 --ESC
   BEGIN
      IF @cClosePallet = '1'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = ''   -- Option

         -- Go to Close Pallet screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END
      ELSE
      BEGIN
         IF @nFromStep = 1
         BEGIN
            -- Prep prev screen var
            SET @cOutField01 = ''   -- PalletKey

            -- Go to prev screen
            SET @nScn = @nScn - 4
            SET @nStep = @nStep - 4

         END
         ELSE IF @nFromStep = 2
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cPalletKey
            SET @cOutField02 = '' -- CartonType

            -- Go to prev screen
            SET @nScn = @nScn - 3
            SET @nStep = @nStep - 3
         END
      END
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
   END

END
GOTO Quit


/********************************************************************************
Scn = 2255. Capture pack info
   Carton Type (field01, input)
   Weight      (field02, input)
   Cube        (field03, input)
   RefNo       (field04, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cChkCartonType NVARCHAR( 10)

      -- Screen mapping
      SET @cChkCartonType  = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cWeight         = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cCube           = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cRefNo          = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END

      -- Carton type
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check blank
         IF @cChkCartonType = ''
         BEGIN
            SET @nErrNo = 68890
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

         -- Check if valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 155051
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

            SET @cOutField02 = @cWeight         --WinSern
            SET @cOutField03 = @cCube           --WinSern
         END
         SET @cOutField01 = @cCartonType
      END

      -- Weight
      IF @cFieldAttr02 = ''
      BEGIN
         -- Check blank
         IF @cWeight = ''
         BEGIN
            SET @nErrNo = 155052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight
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
            SET @nErrNo = 155053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = ''
            GOTO Quit
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
            SET @nErrNo = 155054
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
            SET @nErrNo = 155055
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube
            EXEC rdt.rdtSetFocusField @nMobile, 3
            SET @cOutField03 = ''
            GOTO Quit
         END
         SET @nErrNo = 0
         SET @cOutField03 = @cCube
      END

      -- RefNo
      IF @cFieldAttr04 = ''
      BEGIN
         -- Check barcode format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'RefNo', @cRefNo) = 0
         BEGIN
            SET @nErrNo = 155056
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Quit
         END
      END

      -- ExtendedValidateSP
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
            ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cPalletKey   NVARCHAR( 30), ' +
            '@cCartonType  NVARCHAR( 10), ' +
            '@cCaseID      NVARCHAR( 20), ' +
            '@cLOC         NVARCHAR( 10), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' + 
            '@cLength      NVARCHAR(5),   ' + 
            '@cWidth       NVARCHAR(5),   ' + 
            '@cHeight      NVARCHAR(5),   ' + 
            '@cGrossWeight NVARCHAR(5),   ' + 
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
            @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_Scan_To_Pallet -- For rollback or commit only our own transaction

      -- Confirm
      EXEC rdt.rdt_Scan_To_Pallet_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPalletKey       = @cPalletKey      
         ,@cLOC             = @cLOC            
         ,@cCaseID          = @cCaseID         
         ,@cCapturePackInfo = @cCapturePackInfo
         ,@cCartonType      = @cCartonType     
         ,@cWeight          = @cWeight         
         ,@cCube            = @cCube           
         ,@cRefNo           = @cRefNo          
         ,@cPickSlipNo      = @cPickSlipNo
         ,@nCartonNo        = @nCartonNo
         ,@cSKU             = @cSKU
         ,@nQTY             = @nQTY
         ,@nErrNo           = @nErrNo  OUTPUT
         ,@cErrMsg          = @cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_Scan_To_Pallet
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         GOTO Quit
      END

      -- ExtendedUpdate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nAfterStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
            ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nAfterStep   INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cPalletKey   NVARCHAR( 30), ' +
            '@cCartonType  NVARCHAR( 10), ' +
            '@cCaseID      NVARCHAR( 20), ' +
            '@cLOC         NVARCHAR( 10), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' + 
            '@cLength      NVARCHAR(5),   ' + 
            '@cWidth       NVARCHAR(5),   ' + 
            '@cHeight      NVARCHAR(5),   ' + 
            '@cGrossWeight NVARCHAR(5),   ' + 
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
            @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_Scan_To_Pallet
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Quit
         END
      END

      -- Enable field
      SET @cFieldAttr01 = '' -- CartonType
      SET @cFieldAttr02 = '' -- Weight
      SET @cFieldAttr03 = '' -- Cube
      SET @cFieldAttr04 = '' -- RefNo

      COMMIT TRAN rdtfnc_Scan_To_Pallet
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

      SELECT @nTotalCases = ISNULL(COUNT(1), '') 
      FROM dbo.PalletDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PalletKey = @cPalletKey

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cCartonType
      SET @cOutField03 = ''   -- Case ID
      SET @cOutField04 = @nTotalCases
      
      -- Go to case ID screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr01 = '' -- CartonType
      SET @cFieldAttr02 = '' -- Weight
      SET @cFieldAttr03 = '' -- Cube
      SET @cFieldAttr04 = '' -- RefNo
         
      SELECT @nTotalCases = ISNULL(COUNT(1), '') 
      FROM dbo.PalletDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PalletKey = @cPalletKey

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cCartonType
      SET @cOutField03 = ''   -- Case ID
      SET @cOutField04 = @nTotalCases
      
      -- Go to case ID screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
  	END
      
  	-- ExtendedValidateSP
   IF @cExtendedInfoSP <> ''
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
         ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
         ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @cExtendedInfo OUTPUT '
      SET @cSQLParam =
         '@nMobile       INT,           ' +
         '@nFunc         INT,           ' +
         '@nStep         INT,           ' +
         '@nInputKey     INT,           ' +
         '@cLangCode     NVARCHAR( 3),  ' +
         '@cFacility     NVARCHAR( 5),  ' +
         '@cStorerkey    NVARCHAR( 15), ' +
         '@cPalletKey    NVARCHAR( 30), ' +
         '@cCartonType   NVARCHAR( 10), ' +
         '@cCaseID       NVARCHAR( 20), ' +
         '@cLOC          NVARCHAR( 10), ' +
         '@cSKU          NVARCHAR( 20), ' +
         '@nQTY          INT,           ' + 
         '@cLength       NVARCHAR(5),   ' + 
         '@cWidth        NVARCHAR(5),   ' + 
         '@cHeight       NVARCHAR(5),   ' + 
         '@cGrossWeight  NVARCHAR(5),   ' + 
         '@cExtendedInfo NVARCHAR( 20)  OUTPUT ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
         @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @cExtendedInfo OUTPUT

      IF @cExtendedInfo <> ''
         SET @cOutField15 = @cExtendedInfo
   END
END
GOTO Quit

/********************************************************************************                    
Step 7.                  
Scn = 2256. Close pallet
    Options  (input, field01)      
********************************************************************************/                    
Step_7:                    
BEGIN                    
   IF @nInputKey = 1 -- ENTER                    
   BEGIN        
      -- Screen mapping                    
      SET @cOption   = @cInField01                    
      
      /****************************                    
       VALIDATION                     
      ****************************/                    
      --When Options is blank                    
      IF @cOption = ''                    
      BEGIN                    
         SET @nErrNo = 155057                   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req         
         GOTO Step_7_Fail                      
      END                     
            
      IF @cOption NOT IN ('1', '2')      
      BEGIN                    
         SET @nErrNo = 155058                    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Option      
         GOTO Step_7_Fail                      
      END

      -- ExtendedValidateSP
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
            ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cPalletKey   NVARCHAR( 30), ' +
            '@cCartonType  NVARCHAR( 10), ' +
            '@cCaseID      NVARCHAR( 20), ' +
            '@cLOC         NVARCHAR( 10), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' + 
            '@cLength      NVARCHAR(5),   ' + 
            '@cWidth       NVARCHAR(5),   ' + 
            '@cHeight      NVARCHAR(5),   ' + 
            '@cGrossWeight NVARCHAR(5),   ' + 
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
            @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_7_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Check pallet closed (temporary workaround, instead of changing ntrPalletHeaderUpdate trigger)  
         IF EXISTS( SELECT 1 FROM Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND Status = '9')  
         BEGIN  
            SET @nErrNo = 155059  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet closed  
            GOTO Step_7_Fail
         END  

         SELECT @cMBOLKey = MbolKey
         FROM dbo.MBOL WITH (NOLOCK)
         WHERE ExternMbolKey = @cPalletKey
         AND [Status] < '9'

         SET @nTranCount = @@TRANCOUNT  
         BEGIN TRAN  -- Begin our own transaction  
         SAVE TRAN ClosePallet -- For rollback or commit only our own transaction  
     
         -- Close pallet  
         UPDATE Pallet SET  
            Status = '9',   
            EditWho = SUSER_SNAME(),  
            EditDate = GETDATE()  
         WHERE PalletKey = @cPalletKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 155060  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PalletFail  
            ROLLBACK TRAN ClosePallet
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Step_7_Fail
         END  
           
         -- Submit for MBOL validation (backend job)  
         UPDATE MBOL SET  
            Status = '5',   
            EditWho = SUSER_SNAME(),  
            EditDate = GETDATE(),   
            TrafficCop = NULL  
         WHERE MBOLKey = @cMBOLKey  
            AND Status = '0'  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 155061  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBOL Fail  
            ROLLBACK TRAN ClosePallet
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Step_7_Fail
         END  

         -- ExtendedUpdate
         IF @cExtendedUpdateSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @nStep, @nAfterStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, '+ 
               ' @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@nStep        INT,           ' +
               '@nAfterStep   INT,           ' +
               '@nInputKey    INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerkey   NVARCHAR( 15), ' +
               '@cPalletKey   NVARCHAR( 30), ' +
               '@cCartonType  NVARCHAR( 10), ' +
               '@cCaseID      NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@nQTY         INT,           ' + 
               '@cLength      NVARCHAR(5),   ' + 
               '@cWidth       NVARCHAR(5),   ' + 
               '@cHeight      NVARCHAR(5),   ' + 
               '@cGrossWeight NVARCHAR(5),   ' + 
               '@nErrNo       INT           OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nStep, @nInputKey, @cLangCode, @cFacility, @cStorerKey, @cPalletKey, @cCartonType, @cCaseID, 
               @cLOC, @cSKU, @nQTY, @cLength, @cWidth, @cHeight, @cGrossWeight, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN ClosePallet
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               GOTO Step_7_Fail
            END
         END
         
         COMMIT TRAN ClosePallet  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
      END

      -- Prep prev screen var
      SET @cOutField01 = ''   -- PalletKey
      SET @cOutField02 = @cLOC

      -- Go to prev screen
      SET @nScn = @nScn - 6
      SET @nStep = @nStep - 6         
   END                     

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep prev screen var
      SET @cOutField01 = ''   -- PalletKey
      SET @cOutField02 = @cLOC

      -- Go to prev screen
      SET @nScn = @nScn - 6
      SET @nStep = @nStep - 6         
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate     = GETDATE(), 
      ErrMsg       = @cErrMsg,
      Func         = @nFunc,
      Step         = @nStep,
      Scn          = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility, 
      Printer_paper  = @cPrinter, --(yeekung01)

      V_PickSlipNo = @cPickSlipNo, 
      V_CartonNo   = @nCartonNo, 
      V_QTY        = @nQTY,
      V_SKU        = @cSKU,
      V_LOC        = @cLOC,
      V_FromStep   = @nFromStep,
      V_FromScn    = @nFromScreen,

      V_String1    = @cSkipPrintPackList,
      V_String2    = @cClosePallet,
      V_String3    = @cCaseID,
      V_String4    = @cCartonType, 
      V_String5    = @cCapturePackInfo, 
      V_String6    = @cCapturePalletInfo,
      V_String7    = @cAllowWeightZero,
      V_String8    = @cAllowCubeZero,
      V_String9    = @cExtendedUpdateSP,
      V_String10   = @cLength             , -- (ChewKP01)
      V_String11   = @cWidth              , -- (ChewKP01)
      V_String12   = @cHeight             , -- (ChewKP01)
      V_String13   = @cGrossWeight        , -- (ChewKP01)
      V_String14   = @cExtendedValidateSP,
      V_String15   = @cDefaultWeight,
      V_String16   = @cDecodeSP,
      V_String17   = @cExtendedInfoSP,
      V_String18   = @cCapturePackInfoSP,

      V_String41   = @cPalletKey,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  FieldAttr01  = @cFieldAttr01, 
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  FieldAttr02  = @cFieldAttr02, 
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  FieldAttr03  = @cFieldAttr03, 
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  FieldAttr04  = @cFieldAttr04, 
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  FieldAttr05  = @cFieldAttr05, 
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  FieldAttr06  = @cFieldAttr06, 
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  FieldAttr07  = @cFieldAttr07, 
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  FieldAttr08  = @cFieldAttr08, 
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  FieldAttr09  = @cFieldAttr09, 
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  FieldAttr10  = @cFieldAttr10, 
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  FieldAttr11  = @cFieldAttr11, 
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  FieldAttr12  = @cFieldAttr12, 
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  FieldAttr13  = @cFieldAttr13, 
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  FieldAttr14  = @cFieldAttr14, 
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO