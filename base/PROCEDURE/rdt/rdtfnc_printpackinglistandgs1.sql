SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdtfnc_PrintPackingListAndGS1                       */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Purpose: RDT Replenishment                                           */      
/*          SOS93812 - Move By Drop ID                                  */      
/*                                                                      */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author   Purposes                                    */      
/* 2011-11-21 1.0  Ung      Created                                     */      
/* 2012-01-03 1.1  Ung      Standarize print GS1 to use Exceed logic    */      
/* 2012-01-18 1.2  Ung      Add if DropID record exist then only allow  */      
/*                          print GS1 label                             */      
/* 2012-03-02 1.3  Ung      SOS237492:                                  */      
/*                          Reprint child GS1 label                     */      
/*                          Send master GS1 label information to WCS    */      
/*                          SOS238077 Add weight field                  */      
/* 2012-04-07 1.4  James    Bug fix (james01)                           */      
/* 2012-04-18 1.5  Ung      Prompt weight capture for every GS1         */      
/*                          Add packing list not print err msg          */      
/* 2012-04-19 1.6  Ung      Fix master pack GS1 not print (ung01)       */      
/* 2012-04-20 1.7  Shong    Update PackInfo.Weight if record exists     */      
/* 2012-04-23 1.8  Shong    Carton Type Master and Normal need to send  */      
/*                          TCP                                         */      
/* 2012-04-20 1.9  Ung      Support scan GS1 label no (ung02)           */      
/* 2012-04-30 2.0  Ung      SOS243194 Not send WCS GS1 for              */      
/*                          DropID.DropIDType = NON-WCS                 */      
/* 2012-05-02 2.1  Ung      Not sent TCP GS1, if send before            */      
/* 2012-05-09 2.2  Ung      SOS244056 check ID shipped                  */      
/* 2012-06-08 2.3  ChewKP   SOS#239201 UPDATE DropIDDetail.LabelPrinted */      
/*                          = 'Y' (ChewKP01)                            */      
/* 28-05-2012 2.4  Ung      SOS245083 change master and child carton    */      
/*                          on tracking no, print GS1                   */      
/*                          Clean up source                             */    
/* 30-09-2016 2.5  Ung      Performance tuning                          */  
/* 08-11-2018 2.6  Gan      Performance tuning                          */
/************************************************************************/      
      
CREATE PROC [RDT].[rdtfnc_PrintPackingListAndGS1] (      
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
   @b_success   INT,      
   @cDataWindow NVARCHAR( 50),      
   @cTargetDB   NVARCHAR( 20),      
   @cOption     NVARCHAR( 1),      
   @cLabelNo    NVARCHAR( 20),      
   @cGS1TemplatePath NVARCHAR(120),      
   @cEtcTemplateID   NVARCHAR( 60),      
   @cRefNo      NVARCHAR( 20),      
   @cRefNo2     NVARCHAR( 20),      
   @cBatchNo    NVARCHAR( 20),      
   @b_Debug     INT,      
   @cDropIDType NVARCHAR( 10),      
   @cTCPGS1Sent NVARCHAR( 1),      
   @cDropIDExist    NVARCHAR( 1)      
      
-- RDT.RDTMobRec variable      
DECLARE      
   @nFunc       INT,      
   @nScn        INT,      
   @nStep       INT,      
   @cLangCode   NVARCHAR( 3),      
   @nInputKey   INT,      
   @nMenu       INT,      
      
   @cStorerKey      NVARCHAR( 15),      
   @cFacility       NVARCHAR( 5),      
   @cUserName       NVARCHAR( 18),      
   @cLabelPrinter   NVARCHAR( 10),      
   @cPaperPrinter   NVARCHAR( 10),      
      
   @cID             NVARCHAR( 20),      
   @cLastID         NVARCHAR( 20),      
   @cDropID         NVARCHAR( 20),      
   @cPrintGS1Label  NVARCHAR( 1),      
   @cPrintPackList  NVARCHAR( 1),      
   @cPickSlipNo     NVARCHAR( 10),      
   @cType           NVARCHAR( 10),      
   @nCartonNo       INT,      
   @cWeight         NVARCHAR( 10),      
   @cDropIDPrinted  NVARCHAR( 1),       
      
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
   @nFunc       = Func,      
   @nScn        = Scn,      
   @nStep       = Step,      
   @nInputKey   = InputKey,      
   @nMenu       = Menu,      
   @cLangCode   = Lang_code,      
      
   @cStorerKey  = StorerKey,      
   @cFacility   = Facility,      
   @cUserName   = UserName,      
   @cLabelPrinter = Printer,      
   @cPaperPrinter = Printer_Paper,      
   
   @nCartonNo      = V_Cartonno,
      
   @cDropID        = V_String1,      
   @cLastID        = V_String2,      
   @cPrintGS1Label = V_String3,      
   @cPrintPackList = V_String4,      
   @cPickSlipNo    = V_String5,      
   @cID            = V_String6,      
   @cType          = V_String7,      
  -- @nCartonNo      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8, 5), 0) = 1 THEN LEFT( V_String8, 5) ELSE 0 END,      
   @cWeight        = V_String9,      
   @cDropIDPrinted = V_String10,      
      
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
      
FROM RDTMOBREC (NOLOCK)      
WHERE Mobile = @nMobile      
      
-- Redirect to respective screen      
IF @nFunc in (1789, 1790)      
BEGIN      
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1789, 1790      
   IF @nStep = 1 GOTO Step_1   -- Scn = 2980. DropID      
   IF @nStep = 2 GOTO Step_2   -- Scn = 2981. Weight      
   IF @nStep = 3 GOTO Step_3   -- Scn = 2982. Option. Reprint pack list      
   IF @nStep = 4 GOTO Step_4   -- Scn = 2983. Option. Reprint GS1      
END      
RETURN -- Do nothing if incorrect step      
      
      
/********************************************************************************      
Step 0. Called from menu      
********************************************************************************/      
Step_0:      
BEGIN      
   -- Set the entry point      
   SET @nScn = 2980      
   SET @nStep = 1      
      
   -- Init var      
   IF @nFunc = 1789      
   BEGIN      
      SET @cPrintGS1Label = '1'      
      SET @cPrintPackList = '1'      
   END      
   IF @nFunc = 1790 -- Allow reprint      
   BEGIN      
      SET @cPrintGS1Label = ''      
      SET @cPrintPackList = ''      
   END      
      
   -- Logging      
   EXEC RDT.rdt_STD_EventLog      
      @cActionType = '1', -- Sign in function      
      @cUserID     = @cUserName,      
      @nMobileNo   = @nMobile,      
      @nFunctionID = @nFunc,      
      @cFacility   = @cFacility,      
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep      
      
   -- Prep next screen var      
   SET @cDropID = ''      
   SET @cOutField01 = ''  -- DropID      
   SET @cOutField02 = ''  -- Last DropID      
   SET @cOutField03 = @cPrintGS1Label      
   SET @cOutField04 = @cPrintPackList      
      
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
      
   EXEC rdt.rdtSetFocusField @nMobile, 1      
END      
GOTO Quit      
      
      
/********************************************************************************      
Step 1. Screen = 2980      
   DROPID   (Field01, input)      
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping      
      SET @cID = @cInField01      
      SET @cPrintGS1Label = @cInField03      
      SET @cPrintPackList = @cInField04      
      
      -- Retain key-in value      
      SET @cOutField01 = @cID      
      SET @cOutField03 = @cPrintGS1Label      
      SET @cOutField04 = @cPrintPackList      
      
      -- Validate blank      
      IF @cID = ''      
      BEGIN      
         SET @nErrNo = 74951      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID needed      
         EXEC rdt.rdtSetFocusField @nMobile, 1      
         GOTO Step_1_Fail      
      END      
      
      SET @cType = ''      
      SET @cPickSlipNo = ''      
      
      -- Get PickSlip by RefNo (master carton)      
      SELECT TOP 1      
         @cPickSlipNo = PickSlipNo,      
         @nCartonNo = CartonNo,      
         @cDropID = DropID,      
         @cType = 'MASTER'      
      FROM dbo.PackDetail WITH (NOLOCK)      
      WHERE StorerKey = @cStorerKey      
         AND RefNo = @cID      
      
      -- Get PickSlip by RefNo2 (master carton) (ung02)      
      IF @cPickSlipNo = ''      
         SELECT TOP 1      
   @cPickSlipNo = PickSlipNo,      
            @nCartonNo = CartonNo,      
            @cDropID = DropID,      
            @cType = 'MASTER'      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND RefNo2 = @cID      
      
      -- Get PickSlipNo by DropID (child carton)      
      IF @cPickSlipNo = ''      
         SELECT TOP 1      
            @cPickSlipNo = PickSlipNo,      
            @nCartonNo = CartonNo,      
            @cDropID = DropID,      
            @cType = 'CHILD'      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND DropID = @cID      
            AND RefNo <> ''      
      
      -- Get PickSlipNo by label no (child carton) (ung02)      
      IF @cPickSlipNo = ''      
         SELECT TOP 1      
            @cPickSlipNo = PickSlipNo,      
            @nCartonNo = CartonNo,      
            @cDropID = DropID,      
            @cType = 'CHILD'      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND LabelNo = @cID      
            AND RefNo <> ''      
      
      -- Get PickSlip by LabelNo (normal carton)      
      IF @cPickSlipNo = ''      
         SELECT TOP 1      
            @cPickSlipNo = PickSlipNo,      
            @nCartonNo = CartonNo,      
            @cDropID = DropID,      
            @cType = 'NORMAL'      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND @cID IN (DropID, LabelNo)      
      
      -- Check if valid ID      
      IF @cPickSlipNo = ''      
      BEGIN      
         SET @nErrNo = 74952      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID      
         EXEC rdt.rdtSetFocusField @nMobile, 1 --DropID      
         GOTO Step_1_Fail      
      END      
      
      -- Check if label shipped      
      IF EXISTS( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cDropID AND Status = '9')      
      BEGIN      
         SET @nErrNo = 74979      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Shipped      
         EXEC rdt.rdtSetFocusField @nMobile, 1 --DropID      
         GOTO Step_1_Fail      
      END      
      
      -- Validate print GS1 label option      
      IF @cPrintGS1Label NOT IN ('', '1')      
      BEGIN      
         SET @nErrNo = 74953      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option      
         EXEC rdt.rdtSetFocusField @nMobile, 3 --PrintGS1Label      
         GOTO Quit      
      END      
      
      -- Validate print pack list option      
      IF @cPrintPackList NOT IN ('', '1')      
      BEGIN      
         SET @nErrNo = 74954      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option      
         EXEC rdt.rdtSetFocusField @nMobile, 4 --PrintPackList      
         GOTO Quit      
      END      
      
      -- Check if no printing option selected      
      IF @cPrintGS1Label = '' AND @cPrintPackList = ''      
      BEGIN      
         SET @nErrNo = 74955      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrintOptionReq      
         EXEC rdt.rdtSetFocusField @nMobile, 3 --PrintGS1Label      
         GOTO Quit      
      END      
      
      -- Check if reprint and selected both option      
      IF @nFunc = 1790 AND @cPrintGS1Label = '1' AND @cPrintPackList = '1'      
      BEGIN      
         SET @nErrNo = 74972      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrintEitherOne      
         EXEC rdt.rdtSetFocusField @nMobile, 3 --PrintGS1Label      
         GOTO Quit      
      END      
      
      -- Check print GS1 option      
      IF @cPrintGS1Label = '1'      
      BEGIN      
         -- Check label printer blank      
         IF @cLabelPrinter = ''      
         BEGIN      
            SET @nErrNo = 74956      
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq      
            EXEC rdt.rdtSetFocusField @nMobile, 3 --PrintGS1Label      
            GOTO Quit      
         END      
      
         -- Get DropID exist      
         SET @cDropIDExist = ''      
         IF @cType IN ('NORMAL', 'MASTER') AND EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)      
            SET @cDropIDExist = '1'      
         IF @cType = 'CHILD' AND EXISTS( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE ChildID = @cDropID)      
            SET @cDropIDExist = '1'      
      
         -- Check if DropID exist      
         IF @cDropIDExist = ''      
         BEGIN      
            SET @nErrNo = 74975      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedDropIDRec      
            EXEC rdt.rdtSetFocusField @nMobile, 3 --PrintGS1Label      
            GOTO Quit      
         END      
      
         -- Get GS1 label printed      
         SET @cDropIDPrinted = ''      
         IF @cType IN ('NORMAL', 'MASTER') AND EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID AND LabelPrinted = '1')      
            SET @cDropIDPrinted = '1'      
         IF @cType = 'CHILD' AND EXISTS( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE ChildID = @cDropID)      
            SET @cDropIDPrinted = '1'      
      
         -- Check allow reprint      
         IF @cDropIDPrinted = '1' AND @nFunc = 1789 -- Not allow reprint      
         BEGIN      
            SET @nErrNo = 74957      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrinted      
            GOTO Step_2_Fail      
         END      
      END      
      
      -- Check print pack list option      
      IF @cPrintPackList = '1'      
      BEGIN      
         -- Check paper printer blank      
         IF @cPaperPrinter = ''      
         BEGIN      
            SET @nErrNo = 74959      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq      
            EXEC rdt.rdtSetFocusField @nMobile, 4 --PrintGS1Label      
            GOTO Quit      
         END      
      
         -- Get packing list report info      
         SET @cDataWindow = ''      
         SET @cTargetDB = ''      
         SELECT      
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),      
            @cTargetDB = ISNULL(RTRIM(TargetDB), '')      
         FROM RDT.RDTReport WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND ReportType = 'PACKLIST'      
      
         -- Check data window      
         IF ISNULL( @cDataWindow, '') = ''      
         BEGIN      
            SET @nErrNo = 74961      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup      
            GOTO Step_2_Fail      
         END      
      
         -- Check database      
         IF ISNULL( @cTargetDB, '') = ''      
         BEGIN      
            SET @nErrNo = 74962      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set      
            GOTO Step_2_Fail      
         END      
      
         DECLARE @cManifestPrinted     NVARCHAR( 10)      
         DECLARE @cPackStatus          NVARCHAR( 1)      
         DECLARE @nPackingListRequired INT      
      
         -- Get PackHeader info      
         SELECT      
            @cPackStatus = Status,      
            @cManifestPrinted = ManifestPrinted      
         FROM dbo.PackHeader WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
      
         -- Check if packing list printed      
         IF @cManifestPrinted = '1' AND @nFunc = 1789 -- Not allow reprint      
         BEGIN      
            SET @nErrNo = 74960      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackLstPrinted      
            GOTO Step_2_Fail      
         END      
               
         -- Get packing list required      
         SET @nPackingListRequired = 0      
         SELECT @nPackingListRequired = CASE WHEN SUBSTRING( O.B_Fax1, 9, 1) IN ('I', 'P', 'B') THEN 1 ELSE 0 END      
         FROM dbo.PickDetail PD WITH (NOLOCK)      
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)      
         WHERE PD.PickSlipNo = @cPickSlipNo      
      
         -- Check packing list not required      
         IF NOT( @nPackingListRequired = 1 AND -- Packing list required      
                 @cPackStatus >= '5')          -- Pack confirmed      
         BEGIN      
            SET @nErrNo = 74978      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotMeetPrnReq      
            GOTO Step_2_Fail      
         END      
      END      
      
      -- Print GS1, catch weight      
      IF @cPrintGS1Label = '1' AND @cType IN ('MASTER', 'NORMAL')      
      BEGIN      
         -- Go to reprint screen      
         SET @cOutField01 = '' -- Weight      
         SET @nScn  = @nScn + 1      
         SET @nStep = @nStep + 1      
         GOTO Quit      
      END      
      
      -- Reprint print pack list      
      IF @cPrintPackList = '1' AND @cManifestPrinted = '1' AND @nFunc = 1790 -- Allow reprint      
      BEGIN      
         -- Go to weight screen      
         SET @cOutField01 = '' -- Option      
         SET @nScn  = @nScn + 2      
         SET @nStep = @nStep + 2      
         GOTO Quit      
      END      
      
      -- Reprint GS1      
      IF @cPrintGS1Label = '1' AND @cDropIDPrinted = '1' AND @nFunc = 1790 -- Allow reprint      
      BEGIN      
         -- Prep next screen var      
         SET @cOutField01 = '' -- Option      
         SET @nScn  = @nScn + 3      
         SET @nStep = @nStep + 3      
         GOTO Quit      
      END      
      
      -- Print pack list      
      IF @cPrintPackList = '1'      
      BEGIN      
         EXEC rdt.rdt_PrintPackingListAndGS1_PL      
            @nMobile,      
            @cLangCode,      
            @cPaperPrinter,      
            @cStorerKey,      
            @cFacility,      
            @cPickSlipNo,      
            @nErrNo  OUTPUT,      
            @cErrMsg OUTPUT      
         IF @nErrNo <> 0      
            GOTO Quit      
      
         -- Prompt message        
         DECLARE @cErrMsg1 NVARCHAR( 20)        
         DECLARE @cErrMsg2 NVARCHAR( 20)        
         SET @cErrMsg1 = rdt.rdtgetmessage( 74970, @cLangCode, 'DSP') --PackLstPrinted        
         SET @cErrMsg2 = rdt.rdtgetmessage( 74971, @cLangCode, 'DSP') --PackLstPrinted        
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2                    
      END      
      
      -- Print GS1      
      IF @cPrintGS1Label = '1'      
      BEGIN      
         EXEC rdt.rdt_PrintPackingListAndGS1_GS1      
            @nMobile,      
            @cLangCode,      
            @cLabelPrinter,      
            @cStorerKey,      
            @cFacility,      
            @cPickSlipNo,       
            @nCartonNo,       
            @cDropID,      
            @cType,       
            @cWeight,       
            @nErrNo  OUTPUT,      
            @cErrMsg OUTPUT      
         IF @nErrNo <> 0      
            GOTO Quit      
      END      
      
      SET @cLastID = @cID      
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
     -- Logging      
     EXEC RDT.rdt_STD_EventLog      
       @cActionType = '9', -- Sign Out function      
       @cUserID     = @cUserName,      
       @nMobileNo   = @nMobile,      
       @nFunctionID = @nFunc,      
       @cFacility   = @cFacility,      
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep
      
      -- Back to menu      
      SET @nFunc = @nMenu      
      SET @nScn  = @nMenu      
      SET @nStep = 0      
      SET @cOutField01 = '' -- Clean up for menu option      
      
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
   END      
   GOTO Quit      
      
   Step_1_Fail:      
   BEGIN      
      SET @cID = ''      
      SET @cOutField01 = '' -- ID      
      EXEC rdt.rdtSetFocusField @nMobile, 1 --ID      
   END      
END      
GOTO Quit      
      
      
/********************************************************************************      
Step 2. Screen = 2981      
   Weight (Field01, input)      
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping      
      SET @cWeight = @cInField01      
      
      -- Check if weight is valid      
      IF RDT.rdtIsValidQTY( @cWeight, 21) = 0      
      BEGIN      
         SET @nErrNo = 74976      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight      
         GOTO Step_2_Fail      
      END      
      
      -- Go to reprint GS1 screen      
      IF @cDropIDPrinted = '1'      
      BEGIN      
         SET @cOutField01 = '' -- Option      
         SET @nScn  = @nScn + 2      
         SET @nStep = @nStep + 2      
         GOTO Quit      
      END      
      
      -- Print pack list      
      IF @cPrintPackList = '1'      
      BEGIN      
         EXEC rdt.rdt_PrintPackingListAndGS1_PL      
            @nMobile,      
            @cLangCode,      
            @cPaperPrinter,      
            @cStorerKey,      
            @cFacility,      
            @cPickSlipNo,      
            @nErrNo  OUTPUT,      
            @cErrMsg OUTPUT      
         IF @nErrNo <> 0      
            GOTO Quit      
      END      
      
      -- Print GS1      
      IF @cPrintGS1Label = '1'      
      BEGIN      
         EXEC rdt.rdt_PrintPackingListAndGS1_GS1      
            @nMobile,      
            @cLangCode,      
            @cLabelPrinter,      
            @cStorerKey,      
            @cFacility,      
            @cPickSlipNo,       
            @nCartonNo,       
            @cDropID,      
            @cType,       
            @cWeight,       
            @nErrNo  OUTPUT,      
            @cErrMsg OUTPUT      
         IF @nErrNo <> 0      
            GOTO Quit      
      END      
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      -- Back to TO DropID screen      
      SET @cOutField01 = '' -- DropID      
      SET @cOutField02 = @cLastID      
      SET @cOutField03 = @cPrintGS1Label      
      SET @cOutField04 = @cPrintPackList      
      
      SET @nScn  = @nScn - 1      
      SET @nStep = @nStep - 1      
   END      
   GOTO Quit      
      
   Step_2_Fail:      
   BEGIN      
      SET @cWeight = ''      
      SET @cOutField01 = '' -- Weight      
   END      
END      
GOTO Quit      
      
      
/********************************************************************************      
Step 3. Screen = 2981      
   PACKING LIST PRINTED      
   REPRINT?      
   1 = YES      
   2 = NO      
   OPTION (Field01, input)      
********************************************************************************/      
Step_3:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping      
      SET @cOption = @cInField01      
      
      -- Validate blank      
      IF @cOption = ''      
      BEGIN      
         SET @nErrNo = 74964      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed      
         GOTO Step_3_Fail      
      END      
      
      -- Validate option      
      IF @cOption <> '1' AND @cOption <> '2'      
      BEGIN      
         SET @nErrNo = 74965      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option      
         GOTO Step_3_Fail      
      END      
      
      IF @cOption = '1' -- YES      
      BEGIN      
         -- Print pack list      
         EXEC rdt.rdt_PrintPackingListAndGS1_PL      
            @nMobile,      
            @cLangCode,      
            @cPaperPrinter,      
            @cStorerKey,      
            @cFacility,      
            @cPickSlipNo,      
            @nErrNo  OUTPUT,      
            @cErrMsg OUTPUT      
         IF @nErrNo <> 0      
            GOTO Quit      
      
         SET @cLastID = @cID      
      END      
   END      
      
   -- Back to TO DropID screen      
   SET @cOutField01 = '' -- DropID      
   SET @cOutField02 = @cLastID      
   SET @cOutField03 = @cPrintGS1Label      
   SET @cOutField04 = @cPrintPackList      
      
   SET @nScn  = @nScn - 2      
   SET @nStep = @nStep - 2      
   EXEC rdt.rdtSetFocusField @nMobile, 1 --DropID      
      
   GOTO Quit      
      
   Step_3_Fail:      
   BEGIN      
      SET @cOption = ''      
      SET @cOutField01 = '' -- Option      
   END      
END      
GOTO Quit      
      
      
/********************************************************************************      
Step 4. Screen = 2982      
   GS1 LABEL PRINTED      
   REPRINT?      
   1 = YES      
   2 = NO      
   OPTION (Field01, input)      
********************************************************************************/      
Step_4:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping      
      SET @cOption = @cInField01      
      
      -- Validate blank      
      IF @cOption = ''      
      BEGIN      
   SET @nErrNo = 74968      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed      
         GOTO Step_4_Fail      
      END      
      
      -- Validate option      
      IF @cOption <> '1' AND @cOption <> '2'      
      BEGIN      
         SET @nErrNo = 74969      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option      
         GOTO Step_4_Fail      
      END      
      
      
      
      IF @cOption = '1' -- YES      
      BEGIN      
         -- Print GS1, send WCS      
         EXEC rdt.rdt_PrintPackingListAndGS1_GS1      
            @nMobile,      
            @cLangCode,      
            @cLabelPrinter,      
            @cStorerKey,      
            @cFacility,      
            @cPickSlipNo,       
            @nCartonNo,       
            @cDropID,      
            @cType,       
            @cWeight,       
            @nErrNo  OUTPUT,      
            @cErrMsg OUTPUT      
         IF @nErrNo <> 0      
            GOTO Quit      
      
         SET @cLastID = @cID      
      END      
   END      
      
   -- Back to TO DropID screen      
   SET @cOutField01 = '' -- DropID      
   SET @cOutField02 = @cLastID      
   SET @cOutField03 = @cPrintGS1Label      
   SET @cOutField04 = @cPrintPackList      
      
   SET @nScn  = @nScn - 3      
   SET @nStep = @nStep - 3      
   EXEC rdt.rdtSetFocusField @nMobile, 1 --DropID      
      
   GOTO Quit      
      
   Step_4_Fail:      
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
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,      
      Func   = @nFunc,      
      Step   = @nStep,      
      Scn    = @nScn,      
      
      StorerKey  = @cStorerKey,      
      Facility   = @cFacility,      
      -- UserName   = @cUserName,-- (Vicky06)      
      Printer    = @cLabelPrinter ,      
      Printer_Paper = @cPaperPrinter , 
      
      V_Cartonno = @nCartonNo,
      
      V_String1  = @cDropID,      
      V_String2  = @cLastID,      
      V_String3  = @cPrintGS1Label,      
      V_String4  = @cPrintPackList,      
      V_String5  = @cPickSlipNo,   
      V_String6  = @cID,      
      V_String7  = @cType,      
      --V_String8  = CAST( @nCartonNo AS NVARCHAR(5)),      
      V_String9  = @cWeight,      
      V_String10 = @cDropIDPrinted,       
      
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