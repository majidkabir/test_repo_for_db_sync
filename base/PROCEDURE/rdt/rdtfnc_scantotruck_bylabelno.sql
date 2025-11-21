SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_ScanToTruck_ByLabelNo                        */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Scan LabelNo/DropID to truck by MBOL/Load/Order             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2012-12-06 1.0  James    SOS262234 Created                           */
/* 2013-03-25 1.1  ChewKP   SOS#272994 Nike Enhacement (ChewKP01)       */
/* 2013-22-05 1.2  ChewKP   SOS#272994 Allow ScanToTruck when MBOL      */
/*                          Status = '9' (ChewKP02)                     */
/* 2013-05-14 1.3  Ung      SOS278061.                                  */
/*                          Add OrderKey, LoadKey                       */
/*                          Remove ToggleID                             */
/*                          Add CheckPackDetailDropID                   */
/*                          Add CheckPickDetailDropID                   */
/*                          Add BypassMBOLShippedCheck                  */
/*                          Add ExtendedUpdateSP                        */
/*                          Change outstanding prompt to compulsory     */
/*                          Change rdtScanToTruck.Status = 9 (prev is 0)*/
/*                          Clean up source                             */
/*                          Add BypassPackConfirmCheck                  */
/* 2013-12-24 1.4  Ung      SOS299726 Add ExtendedValidateSP            */
/* 2014-02-05 1.5  Ung      SOS300731                                   */
/*                          Add CapturePackInfoSP                       */
/*                          Add Weight, Cube, CartonType screen         */
/* 2014-04-15 1.6  ChewKP   ANF Project Enhancement Add StorerConfig    */
/*                          ByPassLoadPlanCheck (ChewKP01)              */
/* 2014-05-11 1.7  ChewKP   Add (NOLOCK) (ChewKP02)                     */
/* 2014-05-21 1.8  Shong    Add AutoScanOutPS to scan out pickslip      */
/*                          (Shong01)                                   */
/* 2014-06-11 1.9  ChewKP   If PickSlipNo in PickDetail have status = 0 */
/*                          do not allow auto pack confirm (ChewKP03)   */
/* 2014-04-18 2.0  Ung      SOS308184                                   */
/*                          Add CaptureRefInfo                          */
/*                          Add Door, RefNo screen                      */
/*                          Change double scan checking by doc          */
/* 2014-08-06 2.1  Ung      SOS317603                                   */
/*                          ByPassLoadPlanCheck to ByPassCheckIDinMBOL  */
/*                          ExtendedValidateSP add InputKey param       */
/* 2014-09-22 2.2  Ung      SOS321146 Add weight range checking         */
/* 2014-10-01 2.3  Ung      SOS321796 ExtendedValidateSP reorg param    */
/* 2014-09-30 2.4  ChewKP   Get Pickslip by Descending order (ChewKP04) */
/* 2015-12-01 2.5  Ung      SOS358041 ExtendedUpdateSP reorg param      */
/* 2015-12-07 2.6  James    Move getstat after extendedupdate (james01) */
/* 2016-08-10 2.7  James    Trim weight leading space (james02)         */
/* 2016-09-30 2.8  Ung      Performance tuning                          */
/* 2018-04-16 2.9  Ung      WMS-4476 Add GetStatSP                      */
/* 2018-09-24 3.0  James    WMS7751-Remove OD.loadkey (james03)         */
/* 2020-11-19 3.1  Chermaine WMS-15680 Add OTMITF config (cc01)         */
/* 2020-11-24 3.2  James    WMS-15718 - Add Refno lookup (james04)      */
/* 2023-08-07 3.3  Ung      WMS-23190 Add ExtendedInfoSP                */
/* 2023-10-26 3.4  James    WMS-23887 Add standard DecodeSP (james05)   */
/* 2023-11-14 3.5  YeeKung  WMS-24119 Add ExtendedInfoSP  in step 2     */
/* 2024-02-28 3.6  Ung      WMS-24945 RefNoLookupColumn add param       */
/* 2024-03-05 3.7  Ung      WMS-24782 Add ManifestReport                */
/************************************************************************/
CREATE   PROC [RDT].[rdtfnc_ScanToTruck_ByLabelNo] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_Success        INT,
   @nTranCount       INT,
   @nTotalCarton     INT,
   @nScanCarton      INT,
   @cSQL             NVARCHAR(MAX),
   @cSQLParam        NVARCHAR(MAX),
   @tManifestReport  VARIABLETABLE

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey    NVARCHAR(15),
   @cFacility     NVARCHAR(5),
   @cUserName     NVARCHAR(18),
   @cPaperPrinter NVARCHAR(10),
   @cLabelPrinter NVARCHAR(10),

   @cLoadKey      NVARCHAR(10),
   @cOrderKey     NVARCHAR(10),
   @cLabelNo      NVARCHAR(20),

   @cMBOLKey      NVARCHAR( 10),
   @cType         NVARCHAR( 1),
   @cCheckPackDetailDropID  NVARCHAR(1),
   @cCheckPickDetailDropID  NVARCHAR(1),
   @cExtendedUpdateSP       NVARCHAR(20),
   @cExtendedValidateSP     NVARCHAR(20),
   @cBypassMBOLShippedCheck NVARCHAR(1),
   @cBypassPackConfirmCheck NVARCHAR(1),
   @cCapturePackInfoSP      NVARCHAR(20),
   @cPackInfo               NVARCHAR(3),
   @cWeight                 NVARCHAR(10),
   @cCube                   NVARCHAR(10),
   @cCartonType             NVARCHAR(10),
   @cPickSlipNo             NVARCHAR(10),
   @nCartonNo               INT,
   @cByPassCheckIDinMBOL    NVARCHAR(1),
   @cAutoScanOutPS          NVARCHAR(1), -- (Shong01)
   @nQtyPacked              INT,
   @nQtyPicked              INT,
   @cCaptureRefInfo         NVARCHAR(1),
   @cDoor                   NVARCHAR(10),
   @cOTMITF                 NVARCHAR(1), -- (cc01)
   @cExtendedInfo           NVARCHAR(20),
   @cExtendedInfoSP         NVARCHAR(20),
   @cRefNo                  NVARCHAR(40),
   @cRefNum                 NVARCHAR(20),
   @nRowCount               INT,
   @n_Err                   INT,
   @cDecodeSP               NVARCHAR( 20),
   @cManifestReport         NVARCHAR( 20),
   @cBarcode                NVARCHAR( MAX),
   @cID                     NVARCHAR( 18),
   @cUPC                    NVARCHAR( 30),

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,
   @cPaperPrinter = Printer_Paper,
   @cLabelPrinter = Printer,

   @cLoadKey    = V_LoadKey,
   @cOrderKey   = V_OrderKey,
   @cLabelNo    = V_CaseID,
   @cPickSlipNo = V_PickSlipNo,
   @nCartonNo   = V_Cartonno,

   @cMBOLKey    = V_String1,
   @cType       = V_String2,
   @cCheckPackDetailDropID  = V_String3,
   @cCheckPickDetailDropID  = V_String4,
   @cExtendedUpdateSP       = V_String5,
   @cExtendedValidateSP     = V_String6,
   @cBypassMBOLShippedCheck = V_String7,
   @cBypassPackConfirmCheck = V_String8,
   @cCapturePackInfoSP      = V_String9,
   @cPackInfo               = V_String10,
   @cWeight                 = V_String11,
   @cCube                   = V_String12,
   @cCartonType             = V_String13,
   @cRefNum                 = V_String14,
   @cByPassCheckIDinMBOL    = V_String15,
   @cAutoScanOutPS          = V_String16,
   @cCaptureRefInfo         = V_String17,
   @cDoor                   = V_String18,
   @cRefNo                  = V_String19,
   @cOTMITF                 = V_String20, --(cc01)
   @cExtendedInfo           = V_String22,
   @cExtendedInfoSP         = V_String23,
   @cDecodeSP               = V_String24,
   @cManifestReport         = V_String25,

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

-- Redirect to respective screen
IF @nFunc = 922
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 922
   IF @nStep = 1 GOTO Step_1   -- Scn = 3430. MBOLKey, LoadKey, OrderKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 3431. LabelNo/DropID
   IF @nStep = 3 GOTO Step_3   -- Scn = 3432. Weight, Cube, CartonType
   IF @nStep = 4 GOTO Step_4   -- Scn = 3433. Door, RefNo
   IF @nStep = 5 GOTO Step_5   -- Scn = 3434. Print manifest?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3430
   SET @nStep = 1

   -- Get storer configure
   SET @cCheckPackDetailDropID = rdt.RDTGetConfig( @nFunc, 'CheckPackDetailDropID', @cStorerKey)
   SET @cCheckPickDetailDropID = rdt.RDTGetConfig( @nFunc, 'CheckPickDetailDropID', @cStorerKey)
   SET @cBypassMBOLShippedCheck = rdt.RDTGetConfig( @nFunc, 'BypassMBOLShippedCheck', @cStorerKey)
   SET @cBypassPackConfirmCheck = rdt.RDTGetConfig( @nFunc, 'BypassPackConfirmCheck', @cStorerKey)
   SET @cCaptureRefInfo = rdt.RDTGetConfig( @nFunc, 'CaptureRefInfo', @cStorerKey)

   SET @cAutoScanOutPS = rdt.RDTGetConfig( @nFunc, 'AutoScanOutPS', @cStorerKey)
   IF @cAutoScanOutPS = '0'
      SET @cAutoScanOutPS = ''
   SET @cByPassCheckIDinMBOL = rdt.RDTGetConfig( @nFunc, 'ByPassCheckIDinMBOL', @cStorerKey)
   IF @cByPassCheckIDinMBOL = '0'
      SET @cByPassCheckIDinMBOL = ''
   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)
   IF @cCapturePackInfoSP = '0'
      SET @cCapturePackInfoSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cManifestReport = rdt.RDTGetConfig( @nFunc, 'ManifestReport', @cStorerKey)
   IF @cManifestReport = '0'
      SET @cManifestReport = ''

    -- Storer config 'OTMITF'   --(cc01)
   EXECUTE dbo.nspGetRight
      NULL, -- Facility
      @cStorerKey,
      '',--sku
      'OTMITF',
      @b_success  OUTPUT,
      @cOTMITF    OUTPUT,
      @nErrNo     OUTPUT,
      @cErrMsg    OUTPUT

   -- Initialize
   SET @cDoor = ''
   SET @cRefNo = ''

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey

   -- Prep next screen var
   SET @cOutField01 = '' -- MBOLKey
   SET @cOutField02 = '' -- LoadKey
   SET @cOutField03 = '' -- OrderKey
   SET @cOutField04 = '' -- RefNo
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 3431
   MBOLKEY   (Field01, input)
   LOADKEY   (Field02, input)
   ORDERKEY  (Field03, input)
   REFNO     (Field04, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMBOLKey = @cInField01
      SET @cLoadKey = @cInField02
      SET @cOrderKey = @cInField03
      SET @cRefNum = @cInField04

      -- Check blank
      IF @cMBOLKey = '' AND @cLoadKey = '' AND @cOrderKey = '' AND @cRefNum = ''
      BEGIN
         SET @nErrNo = 79301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Key either one
         GOTO Step_1_Fail
      END

      -- Get no field keyed-in
      DECLARE @i INT
      SELECT @i = 0, @cType = ''
      IF @cMBOLKey  <> '' SELECT @i = @i + 1, @cType = 'M'
      IF @cLoadKey  <> '' SELECT @i = @i + 1, @cType = 'L'
      IF @cOrderKey <> '' SELECT @i = @i + 1, @cType = 'O'
      IF @cRefNum <> '' SELECT @i = @i + 1, @cType = 'R'

      IF @i = 0
      BEGIN
         SET @nErrNo = 79302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF @i > 1
      BEGIN
         SET @nErrNo = 79303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL/LOAD/ORD
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      DECLARE @cChkMBOLStatus NVARCHAR(10)
      SET @cChkMBOLStatus = ''

      -- MBOL
      IF @cType = 'M'
      BEGIN
         -- Check MBOL valid
         IF NOT EXISTS( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey)
         BEGIN
            SET @nErrNo = 79304
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad MBOLKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- MBOLKey
            GOTO Step_1_Fail
         END
      END

      -- Load
      IF @cType = 'L'
      BEGIN
         -- Check LoadKey valid
         IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 79306
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- LoadKey
            GOTO Step_1_Fail
         END
      END

      -- Order
      IF @cType = 'O'
      BEGIN
         -- Check OrderKey valid
         IF NOT EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
         BEGIN
            SET @nErrNo = 79308
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- OrderKey
            GOTO Step_1_Fail
         END

         -- Get Load info
         SET @cLoadKey = ''
         SELECT TOP 1 @cLoadKey = LoadKey FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         -- Check populated to Load
         IF @cLoadKey = ''
         BEGIN
            SET @nErrNo = 79309
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNotYetLP
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- OrderKey
            GOTO Step_1_Fail
         END

         -- Get MBOL info
         SET @cMBOLKey = ''
         SELECT TOP 1 @cMBOLKey = MBOLKey FROM dbo.MBOLDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

         -- Check populated to MBOL
         IF @cMBOLKey = ''
         BEGIN
            SET @nErrNo = 79310
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Not MBOL
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- OrderKey
            GOTO Step_1_Fail
         END

         -- Check order cancel
         IF EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND SOStatus = 'CANC')
         BEGIN
            SET @nErrNo = 79311
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- OrderKey
            GOTO Step_1_Fail
         END
      END

      -- Refno
      IF @cType = 'R'
      BEGIN
         -- Get storer config
         DECLARE @cColumnName NVARCHAR(20)
         SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)

         -- Get lookup field data type
         DECLARE @cDataType NVARCHAR(128)
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'MBOL' AND COLUMN_NAME = @cColumnName

         IF @cDataType <> ''
         BEGIN
            IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)

            -- Check data type
            IF @n_Err = 0
            BEGIN
               SET @nErrNo = 79337
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- RefNo
               GOTO Quit
            END

            SET @cSQL =
               ' SELECT @cMbolKey = MbolKey ' +
               ' FROM dbo.MBOL WITH (NOLOCK) ' +
               ' WHERE Facility = @cFacility ' +
                  CASE WHEN @cDataType IN ('int', 'float')
                       THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNum '
                       ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNum '
                  END +
               ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '
            SET @cSQLParam =
               ' @nMobile      INT, ' +
               ' @cFacility    NVARCHAR(5),  ' +
               ' @cColumnName  NVARCHAR(20), ' +
               ' @cRefNum      NVARCHAR(30), ' +
               ' @cMbolKey     NVARCHAR(10) OUTPUT, ' +
               ' @nRowCount    INT          OUTPUT, ' +
               ' @nErrNo       INT          OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile,
               @cFacility,
               @cColumnName,
               @cRefNum,
               @cMbolKey    OUTPUT,
               @nRowCount   OUTPUT,
               @nErrNo      OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            -- Check RefNo in ASN
            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 79338
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInMBOL
               EXEC rdt.rdtSetFocusField @nMobile, 4
               GOTO Quit
            END

            -- Check RefNo in ASN
            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 79339
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiMBOL
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- Ref no
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Lookup field is SP
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cColumnName AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cColumnName) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNum, ' +
                  ' @cMBOLKey OUTPUT, @cLoadKey OUTPUT, @cOrderKey OUTPUT, @cType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile      INT,           ' +
                  '@nFunc        INT,           ' +
                  '@cLangCode    NVARCHAR( 3),  ' +
                  '@nStep        INT,           ' +
                  '@nInputKey    INT,           ' +
                  '@cFacility    NVARCHAR( 5),  ' +
                  '@cStorerKey   NVARCHAR( 15), ' +
                  '@cRefNum      NVARCHAR( 30), ' +
                  '@cMbolKey     NVARCHAR( 10) OUTPUT, ' +
                  '@cLoadKey     NVARCHAR( 10) OUTPUT, ' +
                  '@cOrderKey    NVARCHAR( 10) OUTPUT, ' +
                  '@cType        NVARCHAR( 1)  OUTPUT, ' +
                  '@nErrNo       INT           OUTPUT, ' +
                  '@cErrMsg      NVARCHAR( 20) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNum,
                  @cMBOLKey OUTPUT, @cLoadKey OUTPUT, @cOrderKey OUTPUT, @cType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END

      -- Get MBOL info
      SELECT @cChkMBOLStatus = [Status] FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey

      -- Check MBOL shipped
      IF @cChkMBOLStatus = '9' AND @cBypassMBOLShippedCheck <> '1'
      BEGIN
         SET @nErrNo = 79305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- MBOLKey
         GOTO Step_1_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, ' +
               ' @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile     INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode   NVARCHAR( 3),  ' +
               '@nStep       INT,           ' +
               '@nInputKey   INT,           ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cType       NVARCHAR( 1),  ' +
               '@cMBOLKey    NVARCHAR( 10), ' +
               '@cLoadKey    NVARCHAR( 10), ' +
               '@cOrderKey   NVARCHAR( 10), ' +
               '@cLabelNo    NVARCHAR( 20), ' +
               '@cPackInfo   NVARCHAR( 3),  ' +
               '@cWeight     NVARCHAR( 10), ' +
               '@cCube       NVARCHAR( 10), ' +
               '@cCartonType NVARCHAR( 10), ' +
               '@cDoor       NVARCHAR( 10), ' +
               '@cRefNo      NVARCHAR( 40), ' +
               '@nErrNo      INT           OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo,
               @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Capture ref info
      IF @cCaptureRefInfo = '1'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = '' -- Door
         SET @cOutField02 = '' -- RefNo

         -- Go to Ref screen
         SET @nScn  = @nScn + 3
         SET @nStep = @nStep + 3
      END
      ELSE
      BEGIN
         -- Get statistic
         EXEC rdt.rdt_ScanToTruck_ByLabelNo_GetStat @nMobile, @nFunc, @cLangCode, @cStorerKey
            ,@cType
            ,@cMBOLKey
            ,@cLoadKey
            ,@cOrderKey
            ,@cDoor
            ,@cRefNo
            ,@cCheckPackDetailDropID
            ,@cCheckPickDetailDropID
            ,@nTotalCarton OUTPUT
            ,@nScanCarton  OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT

         -- Prep next screen var
         SET @cOutField01 = CASE WHEN @cType IN ('M', 'R') THEN @cMBOLKey  ELSE '' END
         SET @cOutField02 = CASE WHEN @cType = 'L' THEN @cLoadKey  ELSE '' END
         SET @cOutField03 = CASE WHEN @cType = 'O' THEN @cOrderKey ELSE '' END
         SET @cOutField04 = '' -- ID
         SET @cOutField05 = '' -- Last ID
         SET @cOutField06 = CAST( @nScanCarton AS NVARCHAR( 10))
         SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR( 10))
         SET @cOutField08 = CASE WHEN @cType = 'R' THEN @cRefNum ELSE '' END

         -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, ' +
            ' @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, ' +
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nAfterStep      INT,           ' +
            '@nInputKey       INT,           ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cType           NVARCHAR( 1),  ' +
            '@cMBOLKey        NVARCHAR( 10), ' +
            '@cLoadKey        NVARCHAR( 10), ' +
            '@cOrderKey       NVARCHAR( 10), ' +
            '@cLabelNo        NVARCHAR( 20), ' +
            '@cPackInfo       NVARCHAR( 3),  ' +
            '@cWeight         NVARCHAR( 10), ' +
            '@cCube           NVARCHAR( 10), ' +
            '@cCartonType     NVARCHAR( 10), ' +
            '@cDoor           NVARCHAR( 10), ' +
            '@cRefNo          NVARCHAR( 40), ' +
            '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo,
            @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo,
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nStep IN (2)
            SET @cOutField15 = @cExtendedInfo
      END
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cMBOLKey = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen 3431
   MBOLKey         (Field01)
   LoadKey         (Field02)
   OrderKey        (Field03)
   RefNo           (Field08)
   LabelNo/DropID  (Field04, input)
   Last scanned    (Field05)
   Total carton    (Field06)
   Scan carton     (Field07)
   ExtendInfo      (Field15)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLabelNo = @cInField04
      SET @cBarcode = @cInField04

      -- Check label
      IF @cLabelNo = ''
      BEGIN
         SET @nErrNo = 79312
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Label No
         GOTO Step_2_Fail
      END

      -- Decode
      -- Standard decode
      IF @cDecodeSP = '1'
      BEGIN
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
            @cID     = @cLabelNo    OUTPUT,
            @nErrNo  = @nErrNo      OUTPUT,
            @cErrMsg = @cErrMsg     OUTPUT,
            @cType   = 'ID'

         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END
      ELSE
      BEGIN
         IF @cDecodeSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SELECT @cID = '',  @cLabelNo = ''

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cMBOLKey, @cLoadKey, @cOrderKey, @cBarcode OUTPUT, @cFieldName, ' +
                  ' @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  ' @nMobile      INT,             ' +
                  ' @nFunc        INT,             ' +
                  ' @cLangCode    NVARCHAR( 3),    ' +
                  ' @nStep        INT,             ' +
                  ' @nInputKey    INT,             ' +
                  ' @cStorerKey   NVARCHAR( 15),   ' +
                  ' @cMBOLKey     NVARCHAR( 10),   ' +
                  ' @cLoadKey     NVARCHAR( 10),   ' +
                  ' @cOrderKey    NVARCHAR( 10),   ' +
                  ' @cBarcode     NVARCHAR( MAX) OUTPUT, ' +
                  ' @cFieldName   NVARCHAR( 10),   ' +
                  ' @cLabelNo     NVARCHAR( 20)  OUTPUT, ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cMBOLKey, @cLoadKey, @cOrderKey, @cBarcode OUTPUT, 'ID',
                  @cLabelNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_2_Fail
            END
         END
      END

      -- Check double scan
      DECLARE @cDoubleScan NVARCHAR(1)
      SET @cDoubleScan = ''
      IF @cType IN ('M', 'R')
         IF EXISTS( SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK) WHERE URNNo = @cLabelNo AND MBOLKey = @cMBOLKey)
            SET @cDoubleScan = 'Y'
      IF @cType = 'L'
         IF EXISTS( SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK) WHERE URNNo = @cLabelNo AND LoadKey = @cLoadKey)
            SET @cDoubleScan = 'Y'
      IF @cType = 'O'
         IF EXISTS( SELECT 1 FROM RDT.RDTScanToTruck WITH (NOLOCK) WHERE URNNo = @cLabelNo AND OrderKey = @cOrderKey)
            SET @cDoubleScan = 'Y'

      IF @cDoubleScan = 'Y'
      BEGIN
         SET @nErrNo = 79313
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Label Scanned
         GOTO Step_2_Fail
      END

      DECLARE @cPickDetailOrderKey NVARCHAR(10)
      DECLARE @cPackHeaderOrderKey NVARCHAR(10)
      DECLARE @cPackHeaderLoadKey  NVARCHAR(10)
      DECLARE @cStatus   NVARCHAR(10)

      SET @cPickDetailOrderKey = ''
      SET @cPackHeaderOrderKey = ''
      SET @cPackHeaderLoadKey = ''
      SET @cPickSlipNo = ''
      SET @nCartonNo = 0
      SET @cStatus = ''

      -- PickDetail
      IF @cCheckPickDetailDropID = '1'
      BEGIN
         -- Get PickDetail info
         SELECT
            @cStatus = Status,
            @cPickDetailOrderKey = OrderKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DropID = @cLabelNo

         -- Check ID valid
         IF @cStatus = ''
         BEGIN
            SET @nErrNo = 79314
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD LBNo/DrpID
            GOTO Step_2_Fail
         END

         -- Check pick confirm
         IF @cStatus < '5'
         BEGIN
            SET @nErrNo = 79315
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotPickConfirm
            GOTO Step_2_Fail
         END
      END
      ELSE
      BEGIN
         -- Get PackHeaderInfo
         IF @cCheckPackDetailDropID = '1'
            SELECT
               @cPickSlipNo = PH.PickSlipNo,
               @cPackHeaderOrderKey = PH.OrderKey,
               @cPackHeaderLoadKey = PH.LoadKey,
               @nCartonNo = PD.CartonNo
            FROM dbo.PackHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.DropID = @cLabelNo
            ORDER BY PH.PickslipNo Desc -- (ChewKP04)
         ELSE
            SELECT
               @cPickSlipNo = PH.PickSlipNo,
               @cPackHeaderOrderKey = PH.OrderKey,
               @cPackHeaderLoadKey = PH.LoadKey,
               @nCartonNo = PD.CartonNo
            FROM dbo.PackHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.LabelNo = @cLabelNo
            ORDER BY PH.PickslipNo Desc -- (ChewKP04)

         -- Check ID valid
         IF @cPickSlipNo = ''
         BEGIN
            SET @nErrNo = 79316
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD LBNo/DrpID
            GOTO Step_2_Fail
         END

         -- Check pack confirm
         IF @cBypassPackConfirmCheck <> '1'
         BEGIN
            -- (Shong01)
            IF @cAutoScanOutPS = '1'
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status < '5')
               BEGIN

                  -- If Exist PickDetail.Status = 0 do not allow auto PackConfirm (ChewKP03)
                  IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                                  WHERE StorerKey = @cStorerKey
                                  AND PickSlipNo = @cPickSlipNo
                                  AND Status <> '5' )
                  BEGIN

                     SET @nQtyPacked = 0

                     SELECT @nQtyPacked = SUM(Qty)
                     FROM   PackDetail pd WITH (NOLOCK)
                     WHERE  pd.PickSlipNo = @cPickSlipNo

                     SET @nQtyPicked = 0
                     SELECT @nQtyPicked = SUM(Qty)
                     FROM   PICKDETAIL p WITH (NOLOCK)
                     WHERE  p.PickSlipNo = @cPickSlipNo
                     AND    p.[Status] = '5'


                     IF @nQtyPacked = @nQtyPicked
                     BEGIN
                        UPDATE PackHeader WITH (ROWLOCK)
                           SET [Status] ='9'
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   STATUS <> '9'
                     END

                  END
               END
            END

            IF EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status < '5') -- (ChewKP02)
            BEGIN
               SET @nErrNo = 79317
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotPackConfirm
               GOTO Step_2_Fail
            END
         END
      END

      -- Check order cancel
      IF @cPickDetailOrderKey <> '' OR
         @cPackHeaderOrderKey <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey IN (@cPickDetailOrderKey, @cPackHeaderOrderKey) AND SOStatus = 'CANC')
         BEGIN
            SET @nErrNo = 79329
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
            GOTO Step_2_Fail
         END
      END

      -- MBOL
      IF @cType IN ('M', 'R') AND @cByPassCheckIDinMBOL <> '1'
      BEGIN
         -- PickDetail
         IF @cCheckPickDetailDropID = '1'
         BEGIN
            -- Check ID in MBOL
            IF NOT EXISTS( SELECT 1
               FROM dbo.MBOLDetail MD WITH (NOLOCK)
               WHERE MD.MbolKey = @cMBOLKey
                  AND EXISTS( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) WHERE PD.OrderKey = MD.OrderKey AND PD.DropID = @cLabelNo))
            BEGIN
               SET @nErrNo = 79318
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInMBOL
               GOTO Step_2_Fail
            END
         END
         ELSE
         BEGIN
            -- PackDetail
            IF @cPackHeaderOrderKey <> ''
            BEGIN
               IF NOT EXISTS( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MbolKey = @cMBOLKey AND OrderKey = @cPackHeaderOrderKey)
               BEGIN
                 SET @nErrNo = 79319
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInMBOL
                  GOTO Step_2_Fail
               END
            END
            ELSE IF @cPackHeaderLoadKey <> ''
            BEGIN
               IF NOT EXISTS( SELECT 1
                  FROM dbo.MBOLDetail MD WITH (NOLOCK)
                  WHERE MD.MbolKey = @cMBOLKey
                     AND EXISTS( SELECT 1
                        FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                        WHERE LPD.LoadKey = @cPackHeaderLoadKey
                           AND MD.OrderKey = LPD.OrderKey))
               BEGIN
                  SET @nErrNo = 79320
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInMBOL
                  GOTO Step_2_Fail
               END
            END
         END
      END

      -- Load
      IF @cType = 'L'
      BEGIN
         -- PickDetail
         IF @cCheckPickDetailDropID = '1'
         BEGIN
            -- Check ID in Load
            IF NOT EXISTS( SELECT 1
               FROM dbo.ORDERS O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.LoadKey = @cLoadKey
                  AND PD.DropID = @cLabelNo)
            BEGIN
               SET @nErrNo = 79321
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInLoad
               GOTO Step_2_Fail
            END
         END
         ELSE
         BEGIN
            -- PackDetail
            IF @cPackHeaderOrderKey <> ''
            BEGIN
               IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND OrderKey = @cPackHeaderOrderKey)
               BEGIN
                  SET @nErrNo = 79322
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInLoad
                  GOTO Step_2_Fail
               END
            END
            ELSE IF @cPackHeaderLoadKey <> ''
            BEGIN
               IF @cPackHeaderLoadKey <> @cLoadKey
               BEGIN
                  SET @nErrNo = 79323
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInLoad
                  GOTO Step_2_Fail
               END
            END
         END

         -- Check MBOL created (except conso packing, where ID could belong to multiple orders, populate to different mbol)
         IF @cPickDetailOrderKey <> '' OR
            @cPackHeaderOrderKey <> ''
         BEGIN
            -- Get MBOL info
            SET @cMBOLKey = ''
            SELECT @cMBOLKey = MBOLKey FROM MBOLDetail WITH (NOLOCK) WHERE OrderKey IN (@cPickDetailOrderKey, @cPackHeaderOrderKey)

            -- Check populated to MBOL
            IF @cMBOLKey = ''
            BEGIN
               SET @nErrNo = 79307
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Load Not MBOL
               GOTO Step_2_Fail
            END
         END
      END

      -- Order
      IF @cType = 'O'
      BEGIN
         -- PickDetail
         IF @cCheckPickDetailDropID = '1'
         BEGIN
            -- Check ID in Order
            IF NOT EXISTS( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND DropID = @cLabelNo)
            BEGIN
               SET @nErrNo = 79324
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInOrder
               GOTO Step_2_Fail
            END
         END
         ELSE
         BEGIN
            -- PackDetail
            IF @cPackHeaderOrderKey <> ''
            BEGIN
               IF @cPackHeaderOrderKey <> @cOrderKey
               BEGIN
                  SET @nErrNo = 79325
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInOrder
                  GOTO Step_2_Fail
               END
            END
            ELSE IF @cPackHeaderLoadKey <> ''
            BEGIN
               IF NOT EXISTS( SELECT 1
                  FROM dbo.LoadPlanDetail WITH (NOLOCK)
                  WHERE LoadKey = @cPackHeaderLoadKey
                     AND OrderKey = @cOrderKey)
               BEGIN
                  SET @nErrNo = 79326
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotInOrder
                  GOTO Step_2_Fail
               END
            END
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, ' +
               ' @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile     INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode   NVARCHAR( 3),  ' +
               '@nStep       INT,           ' +
               '@nInputKey   INT,           ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cType       NVARCHAR( 1),  ' +
               '@cMBOLKey    NVARCHAR( 10), ' +
               '@cLoadKey    NVARCHAR( 10), ' +
               '@cOrderKey   NVARCHAR( 10), ' +
               '@cLabelNo    NVARCHAR( 20), ' +
               '@cPackInfo   NVARCHAR( 3),  ' +
               '@cWeight     NVARCHAR( 10), ' +
               '@cCube       NVARCHAR( 10), ' +
               '@cCartonType NVARCHAR( 10), ' +
               '@cDoor       NVARCHAR( 10), ' +
               '@cRefNo      NVARCHAR( 40), ' +
               '@nErrNo      INT           OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo,
               @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Insert rdtScanToTruck
      INSERT INTO rdt.rdtScanToTruck
         (MBOLKey, LoadKey, OrderKey, URNNo, Status, Door, RefNo, AddWho, AddDate, EditWho, EditDate)
      VALUES
         (@cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, '9', @cDoor, @cRefNo, @cUserName, GETDATE(), @cUserName, GETDATE())
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 79327
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS Truck Fail
         GOTO Step_2_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, ' +
               ' @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile     INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode   NVARCHAR( 3),  ' +
               '@nStep       INT,           ' +
               '@nInputKey   INT,           ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cType       NVARCHAR( 1),  ' +
               '@cMBOLKey    NVARCHAR( 10), ' +
               '@cLoadKey    NVARCHAR( 10), ' +
               '@cOrderKey   NVARCHAR( 10), ' +
               '@cLabelNo    NVARCHAR( 20), ' +
               '@cPackInfo   NVARCHAR( 3),  ' +
               '@cWeight     NVARCHAR( 10), ' +
               '@cCube       NVARCHAR( 10), ' +
               '@cCartonType NVARCHAR( 10), ' +
               '@cDoor       NVARCHAR( 10), ' +
               '@cRefNo      NVARCHAR( 40), ' +
               '@nErrNo      INT           OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo,
               @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Move to here because the ExtendedUpdate might have changed mboldetail (james01)
      -- Need recalc the stat again
      -- Get statistic
      EXEC rdt.rdt_ScanToTruck_ByLabelNo_GetStat @nMobile, @nFunc, @cLangCode, @cStorerKey
         ,@cType
         ,@cMBOLKey
         ,@cLoadKey
         ,@cOrderKey
         ,@cDoor
         ,@cRefNo
         ,@cCheckPackDetailDropID
         ,@cCheckPickDetailDropID
         ,@nTotalCarton OUTPUT
         ,@nScanCarton  OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT

      -- Capture weight cube carton type
      IF @cCapturePackInfoSP <> '' AND @cPickSlipNo <> ''
      BEGIN
         SET @cPackInfo = @cCapturePackInfoSP
         SET @cWeight = ''
         SET @cCube = ''
         SET @cCartonType = ''

         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT, ' +
               ' @cPackInfo   OUTPUT, ' +
               ' @cWeight     OUTPUT, ' +
               ' @cCube       OUTPUT, ' +
               ' @cCartonType OUTPUT'

            SET @cSQLParam =
               '@nMobile     INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode   NVARCHAR( 3),  ' +
               '@nStep       INT,           ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cType       NVARCHAR( 1),  ' +
               '@cMBOLKey    NVARCHAR( 10), ' +
               '@cLoadKey    NVARCHAR( 10), ' +
               '@cOrderKey   NVARCHAR( 10), ' +
               '@cLabelNo    NVARCHAR( 20), ' +
               '@nErrNo      INT           OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT, ' +
               '@cPackInfo   NVARCHAR( 3)  OUTPUT, ' +
               '@cWeight     NVARCHAR( 10) OUTPUT, ' +
               '@cCube       NVARCHAR( 10) OUTPUT, ' +
               '@cCartonType NVARCHAR( 10) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cPackInfo   OUTPUT,
               @cWeight     OUTPUT,
               @cCube       OUTPUT,
               @cCartonType OUTPUT

            -- IF @nErrNo <> 0
            --   GOTO Quit
         END

         -- Check if need to capture
         IF CHARINDEX( 'W', @cPackInfo) <> 0 OR
            CHARINDEX( 'C', @cPackInfo) <> 0 OR
            CHARINDEX( 'T', @cPackInfo) <> 0
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cLabelNo
            SET @cOutField02 = @cWeight
            SET @cOutField03 = @cCube
            SET @cOutField04 = @cCartonType

            -- Disable field
            SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END
            SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END

            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Weight

            -- Go to capture PackInfo screen
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END
      END

      --(cc01)
      IF @cOTMITF  = '1'
      BEGIN
         IF (@nTotalCarton = @nScanCarton) --last Carton
         BEGIN
            EXEC ispGenOTMLog 'OTMEDLD', @cMBOLKey, '', @cStorerKey, ''
            , @b_success OUTPUT
            , @nErrNo OUTPUT
            , @cErrMsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 79340
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenTLogFail
               GOTO Step_2_Fail
            END
         END
         IF (@nScanCarton = '1')--1st Carton
         BEGIN
            EXEC ispGenOTMLog 'OTMSTLD', @cMBOLKey, '', @cStorerKey, ''
            , @b_success OUTPUT
            , @nErrNo OUTPUT
            , @cErrMsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 79337
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenTLogFail
               GOTO Step_2_Fail
            END
         END
      END

      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, ' +  
               ' @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, ' + 
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
            SET @cSQLParam =  
               '@nMobile         INT,           ' +  
               '@nFunc           INT,           ' +  
               '@cLangCode       NVARCHAR( 3),  ' +  
               '@nStep           INT,           ' +  
               '@nAfterStep      INT,           ' +  
               '@nInputKey       INT,           ' +  
               '@cFacility       NVARCHAR( 5),  ' +  
               '@cStorerKey      NVARCHAR( 15), ' +  
               '@cType           NVARCHAR( 1),  ' +  
               '@cMBOLKey        NVARCHAR( 10), ' +  
               '@cLoadKey        NVARCHAR( 10), ' +  
               '@cOrderKey       NVARCHAR( 10), ' +  
               '@cLabelNo        NVARCHAR( 20), ' +  
               '@cPackInfo       NVARCHAR( 3),  ' +  
               '@cWeight         NVARCHAR( 10), ' +  
               '@cCube           NVARCHAR( 10), ' +  
               '@cCartonType     NVARCHAR( 10), ' +  
               '@cDoor           NVARCHAR( 10), ' +  
               '@cRefNo          NVARCHAR( 40), ' +  
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +  
               '@nErrNo          INT           OUTPUT, ' +  
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo,  
               @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  

            SET @cOutField15 = @cExtendedInfo
         END  
      END  
        
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '4', -- Move
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @cDropID     = @cLabelNo,
         @cLoadKey    = @cLoadKey,
         @cOrderKey   = @cOrderKey,
         @cRefNo1     = @cMBOLKey

      -- Prepare current screen var
      SET @cOutField01 = CASE WHEN @cType IN ('M', 'R') THEN @cMBOLKey  ELSE '' END
      SET @cOutField02 = CASE WHEN @cType = 'L' THEN @cLoadKey  ELSE '' END
      SET @cOutField03 = CASE WHEN @cType = 'O' THEN @cOrderKey ELSE '' END
      SET @cOutField04 = ''
      SET @cOutField05 = @cLabelNo -- Last
      SET @cOutField06 = CAST( @nScanCarton AS NVARCHAR( 10))
      SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR( 10))
      SET @cOutField08 = CASE WHEN @cType = 'R' THEN @cRefNum  ELSE '' END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get statistic
      EXEC rdt.rdt_ScanToTruck_ByLabelNo_GetStat @nMobile, @nFunc, @cLangCode, @cStorerKey
         ,@cType
         ,@cMBOLKey
         ,@cLoadKey
         ,@cOrderKey
         ,@cDoor
         ,@cRefNo
         ,@cCheckPackDetailDropID
         ,@cCheckPickDetailDropID
         ,@nTotalCarton OUTPUT
         ,@nScanCarton  OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT

      -- Print manifest
      IF @nTotalCarton = @nScanCarton AND @cManifestReport <> ''
      BEGIN
         -- Go to print manifest screen
         SET @cOutField01 = '' -- Option

         SET @nScn  = @nScn + 3
         SET @nStep = @nStep + 3

         GOTO Quit
      END

      IF @nTotalCarton <> @nScanCarton
      BEGIN
         SET @nErrNo = 79328
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotAllScanned
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
         SET @nErrNo = 0
         SET @cErrMsg = ''
      END

      -- Prepare prev screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      IF @cType = 'M' EXEC rdt.rdtSetFocusField @nMobile, 1
      IF @cType = 'L' EXEC rdt.rdtSetFocusField @nMobile, 2
      IF @cType = 'O' EXEC rdt.rdtSetFocusField @nMobile, 3
      IF @cType = 'R' EXEC rdt.rdtSetFocusField @nMobile, 4

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLabelNo = ''
      SET @cOutField04 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 3432
   LabelNo/DropID (Field01)
   Weight         (Field02, input)
   Cube           (Field03, input)
   Carton         (Field04, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWeight     = LTRIM( ISNULL( @cInField02, '')) -- (james02)
      SET @cCube       = @cInField03
      SET @cCartonType = @cInField04

      -- Retain key-in value
      SET @cOutField02 = CASE WHEN @cFieldAttr02 = 'O' THEN '' ELSE @cInField02 END
      SET @cOutField03 = CASE WHEN @cFieldAttr03 = 'O' THEN '' ELSE @cInField03 END
      SET @cOutField04 = CASE WHEN @cFieldAttr04 = 'O' THEN '' ELSE @cInField04 END

      -- Check weight
      IF CHARINDEX( 'W', @cPackInfo) <> 0
      BEGIN
         IF rdt.rdtIsValidQty( @cWeight, 21) = 0 OR LEN( @cWeight) > 6 OR CAST( @cWeight AS FLOAT) NOT BETWEEN 0 AND 99999
         BEGIN
            SET @nErrNo = 79330
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Weight
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Weight
            GOTO Step_3_Fail
         END
      END

      -- Check cube
      IF CHARINDEX( 'C', @cPackInfo) <> 0 AND rdt.rdtIsValidQty( @cCube, 21) = 0
      BEGIN
         SET @nErrNo = 79331
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Cube
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Cube
         GOTO Step_3_Fail
      END

      -- Check carton type
      IF CHARINDEX( 'T', @cPackInfo) <> 0
      BEGIN
          IF NOT EXISTS( SELECT 1
             FROM Cartonization WITH (NOLOCK)
                INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
             WHERE Storer.StorerKey = @cStorerKey
                AND Cartonization.CartonType = @cCartonType)
         BEGIN
            SET @nErrNo = 79332
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Carton type
            GOTO Step_3_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, ' +
               ' @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile     INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode   NVARCHAR( 3),  ' +
               '@nStep       INT,           ' +
               '@nInputKey   INT,           ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cType       NVARCHAR( 1),  ' +
               '@cMBOLKey    NVARCHAR( 10), ' +
               '@cLoadKey    NVARCHAR( 10), ' +
               '@cOrderKey   NVARCHAR( 10), ' +
               '@cLabelNo    NVARCHAR( 20), ' +
               '@cPackInfo   NVARCHAR( 3),  ' +
               '@cWeight     NVARCHAR( 10), ' +
               '@cCube       NVARCHAR( 10), ' +
               '@cCartonType NVARCHAR( 10), ' +
               '@cDoor       NVARCHAR( 10), ' +
               '@cRefNo      NVARCHAR( 40), ' +
               '@nErrNo      INT           OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo,
               @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- PackInfo
      IF EXISTS( SELECT 1 FROM PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
      BEGIN
         -- Update PackInfo
         UPDATE PackInfo SET
            Weight     = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN Weight     ELSE @cWeight     END,
            Cube       = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN Cube       ELSE @cCube       END,
            CartonType = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN CartonType ELSE @cCartonType END
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79333
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         -- Insert PackInfo
         INSERT INTO PackInfo (PickSlipNo, CartonNo, Weight, Cube, CartonType)
         VALUES (@cPickSlipNo, @nCartonNo, @cWeight, @cCube, @cCartonType)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79334
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
            GOTO Step_3_Fail
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, ' +
               ' @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile     INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode   NVARCHAR( 3),  ' +
               '@nStep       INT,           ' +
               '@nInputKey   INT,           ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cType       NVARCHAR( 1),  ' +
               '@cMBOLKey    NVARCHAR( 10), ' +
               '@cLoadKey    NVARCHAR( 10), ' +
               '@cOrderKey   NVARCHAR( 10), ' +
               '@cLabelNo    NVARCHAR( 20), ' +
               '@cPackInfo   NVARCHAR( 3),  ' +
               '@cWeight     NVARCHAR( 10), ' +
               '@cCube       NVARCHAR( 10), ' +
               '@cCartonType NVARCHAR( 10), ' +
               '@cDoor       NVARCHAR( 10), ' +
               '@cRefNo      NVARCHAR( 40), ' +
               '@nErrNo      INT           OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo,
               @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '4', -- Move
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @cDropID     = @cLabelNo,
         @cLoadKey    = @cLoadKey,
         @cOrderKey   = @cOrderKey,
         @cRefNo1     = @cMBOLKey

      -- Get statistic
      EXEC rdt.rdt_ScanToTruck_ByLabelNo_GetStat @nMobile, @nFunc, @cLangCode, @cStorerKey
         ,@cType
         ,@cMBOLKey
         ,@cLoadKey
         ,@cOrderKey
         ,@cDoor
         ,@cRefNo
         ,@cCheckPackDetailDropID
         ,@cCheckPickDetailDropID
         ,@nTotalCarton OUTPUT
         ,@nScanCarton  OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT

      -- Prepare current screen var
      SET @cOutField01 = CASE WHEN @cType IN ('M', 'R') THEN @cMBOLKey  ELSE '' END
      SET @cOutField02 = CASE WHEN @cType = 'L' THEN @cLoadKey  ELSE '' END
      SET @cOutField03 = CASE WHEN @cType = 'O' THEN @cOrderKey ELSE '' END
      SET @cOutField04 = ''
      SET @cOutField05 = @cLabelNo -- Last
      SET @cOutField06 = CAST( @nScanCarton AS NVARCHAR( 10))
      SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR( 10))
      SET @cOutField01 = CASE WHEN @cType = 'R' THEN @cRefNum  ELSE '' END

      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
      GOTO Quit
   END

   Step_3_Fail:
END
GOTO Quit


/********************************************************************************
Step 4. Screen 3433
   Door  (Field01)
   RefNo (Field02)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDoor = @cInField01
      SET @cRefNo = @cInField02
/*
      -- Check Door format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DOOR', @cDoor) = 0
      BEGIN
         SET @nErrNo = 79335
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check RefNo format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'REFNO', @cRefNo) = 0
      BEGIN
         SET @nErrNo = 79336
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END
*/
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, ' +
               ' @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile     INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode  NVARCHAR( 3),  ' +
               '@nStep       INT,           ' +
               '@nInputKey   INT,           ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cType       NVARCHAR( 1),  ' +
               '@cMBOLKey    NVARCHAR( 10), ' +
               '@cLoadKey    NVARCHAR( 10), ' +
               '@cOrderKey   NVARCHAR( 10), ' +
               '@cLabelNo    NVARCHAR( 20), ' +
               '@cPackInfo   NVARCHAR( 3),  ' +
               '@cWeight     NVARCHAR( 10), ' +
               '@cCube       NVARCHAR( 10), ' +
               '@cCartonType NVARCHAR( 10), ' +
               '@cDoor       NVARCHAR( 10), ' +
               '@cRefNo      NVARCHAR( 40), ' +
               '@nErrNo      INT           OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo,
               @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Get statistic
      EXEC rdt.rdt_ScanToTruck_ByLabelNo_GetStat @nMobile, @nFunc, @cLangCode, @cStorerKey
         ,@cType
         ,@cMBOLKey
         ,@cLoadKey
         ,@cOrderKey
         ,@cDoor
         ,@cRefNo
         ,@cCheckPackDetailDropID
         ,@cCheckPickDetailDropID
         ,@nTotalCarton OUTPUT
         ,@nScanCarton  OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT

      -- Prep next screen var
      SET @cOutField01 = CASE WHEN @cType IN ('M', 'R') THEN @cMBOLKey  ELSE '' END
      SET @cOutField02 = CASE WHEN @cType = 'L' THEN @cLoadKey  ELSE '' END
      SET @cOutField03 = CASE WHEN @cType = 'O' THEN @cOrderKey ELSE '' END
      SET @cOutField04 = '' -- ID
      SET @cOutField05 = '' -- Last ID
      SET @cOutField06 = CAST( @nScanCarton AS NVARCHAR( 10))
      SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR( 10))
      SET @cOutField08 = CASE WHEN @cType = 'R' THEN @cRefNum  ELSE '' END

      -- Go to LabelNo screen
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      IF @cType = 'M' EXEC rdt.rdtSetFocusField @nMobile, 1
      IF @cType = 'L' EXEC rdt.rdtSetFocusField @nMobile, 2
      IF @cType = 'O' EXEC rdt.rdtSetFocusField @nMobile, 3
      IF @cType = 'R' EXEC rdt.rdtSetFocusField @nMobile, 4

      -- Go to prev screen
      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
   END
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 3434. Message
   Print MANIFEST?
   1 = YES
   9 = NO
   OPTION   (field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 2)

      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 59433
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 59434
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
         IF @cManifestReport <> ''
         BEGIN
            -- Common params
            INSERT INTO @tManifestReport (Variable, Value) VALUES
               ( '@cStorerKey',  @cStorerKey),
               ( '@cFacility',   @cFacility),
               ( '@cMBOLKey',    @cMBOLKey),
               ( '@cLoadKey',    @cLoadKey),
               ( '@cOrderKey',   @cOrderKey)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cManifestReport, -- Report type
               @tManifestReport, -- Report params
               'rdtfnc_ScanToTruck_ByLabelNo',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo, ' +
                  ' @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile     INT,           ' +
                  '@nFunc       INT,           ' +
                  '@cLangCode   NVARCHAR( 3),  ' +
                  '@nStep       INT,           ' +
                  '@nInputKey   INT,           ' +
                  '@cStorerKey  NVARCHAR( 15), ' +
                  '@cType       NVARCHAR( 1),  ' +
                  '@cMBOLKey    NVARCHAR( 10), ' +
                  '@cLoadKey    NVARCHAR( 10), ' +
                  '@cOrderKey   NVARCHAR( 10), ' +
                  '@cLabelNo    NVARCHAR( 20), ' +
                  '@cPackInfo   NVARCHAR( 3),  ' +
                  '@cWeight     NVARCHAR( 10), ' +
                  '@cCube       NVARCHAR( 10), ' +
                  '@cCartonType NVARCHAR( 10), ' +
                  '@cDoor       NVARCHAR( 10), ' +
                  '@cRefNo      NVARCHAR( 40), ' +
                  '@nErrNo      INT           OUTPUT, ' +
                  '@cErrMsg     NVARCHAR( 20) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cLabelNo,
                  @cPackInfo, @cWeight, @cCube, @cCartonType, @cDoor, @cRefNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END

      -- Prepare prev screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      IF @cType = 'M' EXEC rdt.rdtSetFocusField @nMobile, 1
      IF @cType = 'L' EXEC rdt.rdtSetFocusField @nMobile, 2
      IF @cType = 'O' EXEC rdt.rdtSetFocusField @nMobile, 3
      IF @cType = 'R' EXEC rdt.rdtSetFocusField @nMobile, 4

      -- Go to prev screen
      SET @nScn  = @nScn - 4
      SET @nStep = @nStep - 4
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare current screen var
      SET @cOutField01 = CASE WHEN @cType IN ('M', 'R') THEN @cMBOLKey  ELSE '' END
      SET @cOutField02 = CASE WHEN @cType = 'L' THEN @cLoadKey  ELSE '' END
      SET @cOutField03 = CASE WHEN @cType = 'O' THEN @cOrderKey ELSE '' END
      SET @cOutField04 = ''
      SET @cOutField05 = @cLabelNo -- Last
      SET @cOutField06 = CAST( @nScanCarton AS NVARCHAR( 10))
      SET @cOutField07 = CAST( @nTotalCarton AS NVARCHAR( 10))
      SET @cOutField08 = CASE WHEN @cType = 'R' THEN @cRefNum  ELSE '' END

      -- Go to prev screen
      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,

      V_CaseID   = @cLabelNo,
      V_LoadKey  = @cLoadKey,
      V_OrderKey = @cOrderKey,
      V_PickSlipNo = @cPickSlipNo,
      V_Cartonno = @nCartonNo,

      V_String1  = @cMBOLKey,
      V_String2  = @cType,
      V_String3  = @cCheckPackDetailDropID,
      V_String4  = @cCheckPickDetailDropID,
      V_String5  = @cExtendedUpdateSP,
      V_String6  = @cExtendedValidateSP,
      V_String7  = @cBypassMBOLShippedCheck,
      V_String8  = @cBypassPackConfirmCheck,
      V_String9  = @cCapturePackInfoSP,
      V_String10 = @cPackInfo,
      V_String11 = @cWeight,
      V_String12 = @cCube,
      V_String13 = @cCartonType,
      V_String14 = @cRefNum,
      V_String15 = @cByPassCheckIDinMBOL,
      V_String16 = @cAutoScanOutPS,
      V_String17 = @cCaptureRefInfo,
      V_String18 = @cDoor,
      V_String19 = @cRefNo,
      V_String20 = @cOTMITF,   --(cc01)
      V_String22 = @cExtendedInfo,
      V_String23 = @cExtendedInfoSP,
      V_String24 = @cDecodeSP,
      V_String25 = @cManifestReport,

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