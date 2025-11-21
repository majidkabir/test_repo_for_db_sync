SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*********************************************************************************/  
/* Store procedure: rdtfnc_ReturnRegistration                                    */  
/* Copyright      : LFLogistics                                                  */  
/*                                                                               */  
/* Purpose: Register when return come into warehouse                             */  
/*                                                                               */  
/* Date       Rev  Author   Purposes                                             */  
/* 2015-02-29 1.0  Ung      SOS350413 Created                                    */  
/* 2016-01-18 1.1  Ung      SOS360398 Add type                                   */  
/* 2016-09-30 1.2  Ung      Performance tuning                                   */   
/* 2017-04-11 1.3  James    WMS8630-Add custom field for return date (james01)   */   
/* 2020-04-13 1.4  James    WMS-12749 Add custom refno lookup sp (james02)       */  
/* 2021-01-15 1.5  James    WMS-15446 Allow Qty = 0 or blank (james03)           */  
/* 2021-06-02 1.6  Chermain WMS-15858 Change st2 extUpd @step=1 (cc01)           */  
/* 2022-06-17 1.7  James    WMS-19955 Add eventlog (james04)                     */
/*********************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdtfnc_ReturnRegistration] (  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
) AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE  
   @cChkFacility     NVARCHAR( 5),   
   @nRowCount        INT,   
   @cSQL             NVARCHAR( MAX),   
   @cSQLParam        NVARCHAR( MAX),   
   @cExtendedInfo    NVARCHAR( 20)  
  
-- Session variable  
DECLARE  
   @nFunc            INT,  
   @nScn             INT,  
   @nStep            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nInputKey        INT,  
   @nMenu            INT,  
   @cUserName        NVARCHAR( 18),  
   @cPrinter         NVARCHAR( 10),  
   @cStorerGroup     NVARCHAR( 20),  
   @cStorerKey       NVARCHAR( 15),  
   @cFacility        NVARCHAR( 5),  
                       
   @cReceiptKey      NVARCHAR( 10),  
   @cRefNo           NVARCHAR( 20),  
   @cCarrierKey      NVARCHAR( 15),   
   @cCarrierName     NVARCHAR( 30),   
   @cID              NVARCHAR( 18),  
   @nQTY             INT,  
   @cExtendedInfoSP  NVARCHAR( 20),   
   @cExtendedValidateSP  NVARCHAR( 20),   
   @cExtendedUpdateSP    NVARCHAR( 20),   
   @cReturnRegisterField NVARCHAR( 20),   
   @tExtUpdVar           VariableTable,  
   @tExtValidVar         VariableTable,  
   @cFieldName           NVARCHAR(20),  
   @cPOKey               NVARCHAR( 10),  
   @cAllowZeroQty        NVARCHAR( 1),  
   @nCheckZeroQty        INT,  
   @nContainerQTY        INT,
   
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
  
   @cStorerGroup  = StorerGroup,   
   @cFacility     = Facility,  
   @cPrinter      = Printer,  
   @cUserName     = UserName,  
  
   @cStorerKey    = V_StorerKey,  
   @cReceiptKey   = V_ReceiptKey,   
   @cPOKey        = V_POKey,  
   @cID           = V_ID,   
   @cCarrierName  = V_SKUDescr, -- Due to V_String only 20 chars  
  
   @nQTY          = V_Integer1,  
   @nCheckZeroQty = V_Integer2,  
   @nContainerQTY = V_Integer3,  
   
   @cRefNo        = V_String1,  
   @cCarrierKey   = V_String2,  
   @cAllowZeroQty = V_String3,  
   @cExtendedInfoSP        = V_String4,  
   @cExtendedValidateSP    = V_String5,  
   @cExtendedUpdateSP      = V_String6,  
   @cReturnRegisterField   = V_String7,  
  
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
  
   @cFieldAttr01 = FieldAttr01,    @cFieldAttr02 = FieldAttr02,  
   @cFieldAttr03 = FieldAttr03,    @cFieldAttr04 = FieldAttr04,  
   @cFieldAttr05 = FieldAttr05,    @cFieldAttr06 = FieldAttr06,  
   @cFieldAttr07 = FieldAttr07,    @cFieldAttr08 = FieldAttr08,  
   @cFieldAttr09 = FieldAttr09,    @cFieldAttr10 = FieldAttr10,  
   @cFieldAttr11 = FieldAttr11,    @cFieldAttr12 = FieldAttr12,  
   @cFieldAttr13 = FieldAttr13,    @cFieldAttr14 = FieldAttr14,  
   @cFieldAttr15 = FieldAttr15  
  
FROM RDT.RDTMOBREC WITH (NOLOCK)  
WHERE Mobile = @nMobile  
  
-- Redirect to respective screen  
IF @nFunc = 606  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Func = 597. Menu  
   IF @nStep = 1 GOTO Step_1   -- Scn = 4260. ASN, RefNo, QTY  
   IF @nStep = 2 GOTO Step_2   -- Scn = 4261. ID  
END  
RETURN -- Do nothing if incorrect step  
  
  
/********************************************************************************  
Step 0. func = 597. Menu  
   @nStep = 0  
********************************************************************************/  
Step_0:  
BEGIN  
   -- EventLog  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType = '1', -- Sign-in  
      @cUserID     = @cUserName,  
      @nMobileNo   = @nMobile,  
      @nFunctionID = @nFunc,  
      @cFacility   = @cFacility,  
      @cStorerKey  = @cStorerKey  
  
   SET @cAllowZeroQty = rdt.RDTGetConfig( @nFunc, 'AllowZeroQty', @cStorerKey)    
  
   IF @cAllowZeroQty = '1'  
      SET @nCheckZeroQty = 0  
   ELSE  
      SET @nCheckZeroQty = 1  
        
   -- Prepare next screen var  
   SET @cOutField01 = '' -- ASN  
   SET @cOutField02 = '' -- RefNo  
   SET @cOutField03 = '' -- CarrierName  
   SET @cOutField04 = '' -- CarrierName  
   SET @cOutField05 = '' -- CarrierName  
   SET @cOutField06 = '' -- QTY  
   SET @cOutField15 = '' -- ExtendedInfo  
  
   -- Set the entry point  
   SET @nScn = 4260  
   SET @nStep = 1  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Scn = 4030. ASN, PO, Container No screen  
   ASN          (field01, input)  
   REF NO       (field02, input)  
   QTY          (field03, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      DECLARE @cReceiptStatus NVARCHAR( 10)  
      DECLARE @cChkStorerKey NVARCHAR( 15)  
      DECLARE @cQTY NVARCHAR(5)  
  
      -- Screen mapping  
      SET @cReceiptKey = @cInField01  
      SET @cRefNo = @cInField02  
      SET @cQTY = @cInField06  
  
      -- Check both field not key-in  
      IF @cReceiptKey = '' AND @cRefNo = ''  
      BEGIN  
         SET @nErrNo = 55101  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN/RefNo  
         GOTO Quit  
      END  
  
      -- Check both field key-in  
      IF @cReceiptKey <> '' AND @cRefNo <> ''  
      BEGIN  
         SET @nErrNo = 55102  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN or RefNo  
         SET @cOutField01 = ''  
         SET @cOutField02 = ''  
         GOTO Quit  
      END  
  
      -- ASN  
      IF @cReceiptKey <> ''  
      BEGIN  
         SELECT  
             @cChkFacility = R.Facility,  
             @cChkStorerKey = R.StorerKey,  
             @cReceiptStatus = R.Status  
         FROM dbo.Receipt R WITH (NOLOCK)  
         WHERE R.ReceiptKey = @cReceiptKey  
         SET @nRowCount = @@ROWCOUNT  
  
         -- Check ASN exist  
         IF @nRowCount = 0  
         BEGIN  
            SET @nErrNo = 55103  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exist  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            SET @cOutField01 = '' -- ReceiptKey  
            GOTO Quit  
         END  
         SET @cOutField01 = @cReceiptKey  
      END  
  
      -- RefNo  
      IF @cRefNo <> ''  
      BEGIN  
         -- Get storer config  
         SET @cFieldName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)  
           
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cFieldName AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cFieldName) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerGroup, @cStorerKey, ' +   
               ' @cReceiptKey OUTPUT, @cPOKey OUTPUT, @cRefNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               ' @nMobile      INT,           ' +  
               ' @nFunc        INT,           ' +  
               ' @cLangCode    NVARCHAR( 3),  ' +  
               ' @nStep        INT,           ' +  
               ' @nInputKey    INT,           ' +  
               ' @cFacility    NVARCHAR( 5),  ' +   
               ' @cStorerGroup NVARCHAR( 20), ' +   
               ' @cStorerKey   NVARCHAR( 15), ' +  
               ' @cReceiptKey  NVARCHAR( 10)  OUTPUT, ' +  
               ' @cPOKey       NVARCHAR( 10)  OUTPUT, ' +  
               ' @cRefNo       NVARCHAR( 20)  OUTPUT, ' +  
               ' @nErrNo       INT            OUTPUT, ' +  
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerGroup, @cStorerKey,   
               @cReceiptKey OUTPUT, @cPOKey OUTPUT, @cRefNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
                 
            SET @cOutField02 = @cRefNo  
         END  
         ELSE  
         BEGIN  
            -- Get storer config  
            SET @cFieldName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)  
           
            -- Get lookup field data type  
            DECLARE @cDataType NVARCHAR(128)  
            SET @cDataType = ''  
            SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cFieldName  
           
            IF @cDataType = ''  
            BEGIN  
               SET @nErrNo = 55117  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LookupNotSetup  
               EXEC rdt.rdtSetFocusField @nMobile, 2  
               SET @cOutField02 = '' -- RefNo  
               GOTO Quit  
            END  
           
            DECLARE @n_Err INT  
            IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE  
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE   
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE   
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)  
                             
            -- Check data type  
            IF @n_Err = 0  
            BEGIN  
               SET @nErrNo = 55104  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo  
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo  
               GOTO Quit  
            END  
           
            SET @cSQL =   
               ' SELECT @cReceiptKey = ReceiptKey ' +   
               ' FROM dbo.Receipt WITH (NOLOCK) ' +   
               ' WHERE Facility = ' + QUOTENAME( @cFacility, '''') +   
                  ' AND ISNULL( ' + @cFieldName + CASE WHEN @cDataType IN ('int', 'float') THEN ',0)' ELSE ','''')' END + ' = ' + QUOTENAME( @cRefNo, '''') +   
               ' ORDER BY ReceiptKey ' +   
               ' SET @nRowCount = @@ROWCOUNT '  
            SET @cSQLParam =  
               '@cReceiptKey   NVARCHAR( 10) OUTPUT, ' +  
               '@nRowCount     INT           OUTPUT  '  
     
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cReceiptKey OUTPUT, @nRowCount OUTPUT  
  
            -- Check RefNo in ASN  
            IF @nRowCount = 0  
            BEGIN  
               SET @nErrNo = 55105  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN  
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- ContainerKey  
               SET @cOutField02 = '' -- RefNo  
               GOTO Quit  
            END  
  
            -- Multi ASN found, prompt user to select  
            IF @nRowCount > 1  
            BEGIN  
               SET @nErrNo = 55106  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiASN  
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- ContainerKey  
               SET @cOutField02 = '' -- RefNo  
               GOTO Quit  
            END  
         END  
  
         -- Get ASN info  
         SELECT  
             @cChkFacility = R.Facility,  
             @cChkStorerKey = R.StorerKey,  
             @cReceiptStatus = R.Status  
         FROM dbo.Receipt R WITH (NOLOCK)  
         WHERE R.ReceiptKey = @cReceiptKey  
  
         SET @cOutField02 = @cRefNo  
      END  
  
      -- Validate ASN in different facility  
      IF @cFacility <> @cChkFacility  
      BEGIN  
         SET @nErrNo = 55107  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility  
         GOTO Step_1_Fail  
      END  
  
      -- Check storer group  
      IF @cStorerGroup <> ''  
      BEGIN  
         -- Check storer not in storer group  
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)  
         BEGIN  
            SET @nErrNo = 55108  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp  
            GOTO Step_1_Fail  
         END  
  
         -- Set session storer  
         SET @cStorerKey = @cChkStorerKey  
      END  
  
      -- Validate ASN belong to the storer  
      IF @cStorerKey <> @cChkStorerKey  
      BEGIN  
         SET @nErrNo = 55109  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer  
         GOTO Step_1_Fail  
      END  
  
      -- Validate ASN status  
      IF @cReceiptStatus = '9'  
      BEGIN  
         SET @nErrNo = 55110  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed  
         GOTO Step_1_Fail  
      END  
     
      -- Get storer config  
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)  
      IF @cExtendedInfoSP = '0'  
         SET @cExtendedInfoSP = ''  
  
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
      IF @cExtendedValidateSP = '0'  
         SET @cExtendedValidateSP = ''  
  
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)  
      IF @cExtendedUpdateSP = '0'  
         SET @cExtendedUpdateSP = ''  
  
      SET @cReturnRegisterField = rdt.RDTGetConfig( @nFunc, 'ReturnRegisterField', @cStorerKey)  
      IF @cReturnRegisterField = '0'  
         SET @cReturnRegisterField = ''  
  
      -- Get ASN info  
      SELECT   
         @cCarrierKey = ISNULL( CarrierKey, ''),   
         @cCarrierName = ISNULL( CarrierName, ''),   
         @nContainerQTY = ISNULL( ContainerQTY, 0)  
      FROM Receipt WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey   
        
      -- Prepare next screen var  
      SET @cOutField03 = @cCarrierKey  
      SET @cOutField04 = rdt.rdtFormatString( @cCarrierName, 1, 20)  
      SET @cOutField05 = rdt.rdtFormatString( @cCarrierName, 21, 10)  
        
      -- Default QTY  
      IF @cQTY = '' AND rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey) = '1'  
      BEGIN  
         SET @cQTY = @nContainerQTY  
         SET @cOutField06 = @nContainerQTY  
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY  
           
         -- Remain at current screen to let user verify QTY  
         GOTO Step_1_Quit   
      END  
        
      -- (james03)  
      IF @cAllowZeroQty = '1' AND @cQTY = ''  
         SET @cQTY = '0'  
  
      -- Check QTY blank  
      IF @cQTY = ''  
      BEGIN  
         SET @nErrNo = 55111  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY  
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY  
         GOTO Quit  
      END  
  
      -- Check QTY valid  
      IF RDT.rdtIsValidQTY( @cQTY, @nCheckZeroQty) = 0  
      BEGIN  
         SET @nErrNo = 55112  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY  
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY  
         GOTO Quit  
      END  
      SET @nQTY = CAST( @cQTY AS INT)  
  
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            INSERT INTO @tExtValidVar (Variable, Value) VALUES   
               ('@cReceiptKey',           @cReceiptKey),   
               ('@cRefNo',                @cRefNo),   
               ('@nQTY',                  CAST( @nQTY AS NVARCHAR( 10))),   
               ('@cID',                   @cID),   
               ('@cReturnRegisterField',  @cReturnRegisterField)  
  
            SET @nErrNo = 0  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtValidVar, ' +   
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile       INT,           ' +  
               '@nFunc         INT,           ' +  
               '@cLangCode     NVARCHAR( 3),  ' +  
               '@nStep         INT,           ' +  
               '@nAfterStep    INT,           ' +   
               '@nInputKey     INT,           ' +  
               '@cFacility     NVARCHAR( 5),  ' +   
               '@cStorerKey    NVARCHAR( 15), ' +  
               '@tExtValidVar  VariableTable READONLY, ' +   
               '@nErrNo        INT           OUTPUT, '   +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
     
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtValidVar,   
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
     
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- Capture ID  
      IF rdt.RDTGetConfig( @nFunc, 'CaptureID', @cStorerKey) = '1'  
      BEGIN  
         -- Prepare next screen var  
         SET @cOutField01 = '' -- ID  
     
         -- Go to ID screen  
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
           
         GOTO Step_1_Quit  
      END  
  
      IF @cReturnRegisterField = ''  
         -- Update  
         UPDATE Receipt SET  
            ContainerQTY = @nQTY,   
            UserDefine06 = GETDATE()  
         WHERE ReceiptKey = @cReceiptKey  
      ELSE  
      BEGIN  
         -- Extended update  
         IF @cExtendedUpdateSP <> '' AND   
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            INSERT INTO @tExtUpdVar (Variable, Value) VALUES   
               ('@cReceiptKey',           @cReceiptKey),   
               ('@cRefNo',                @cRefNo),   
               ('@nQTY',                  CAST( @nQTY AS NVARCHAR( 10))),   
               ('@cID',                   @cID),   
               ('@cReturnRegisterField',  @cReturnRegisterField)  
  
            SET @nErrNo = 0  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdVar, ' +   
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile       INT,           ' +  
               '@nFunc         INT,           ' +  
               '@cLangCode     NVARCHAR( 3),  ' +  
               '@nStep         INT,           ' +  
               '@nAfterStep    INT,           ' +   
               '@nInputKey     INT,           ' +  
               '@cFacility     NVARCHAR( 5),  ' +   
               '@cStorerKey    NVARCHAR( 15), ' +  
               '@tExtUpdVar    VariableTable READONLY, ' +   
               '@nErrNo        INT           OUTPUT, '  +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
     
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdVar,   
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
     
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
         ELSE  
         BEGIN  
            SET @nErrNo = 55118  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Upd SP  
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY  
            GOTO Quit  
         END  
      END  

      SET @nContainerQTY = @nQTY
      
      SET @nErrNo = @@ERROR  
      IF @nErrNo <> 0  
         GOTO Quit  

      -- EventLog (james04)
      EXEC RDT.rdt_STD_EventLog  
         @cActionType   = '2', -- Return  
         @cUserID       = @cUserName,  
         @nMobileNo     = @nMobile,  
         @nFunctionID   = @nFunc,  
         @cFacility     = @cFacility,  
         @cStorerKey    = @cStorerKey,  
         @cReceiptKey   = @cReceiptKey,  
         @nQty          = @nContainerQTY,
         @nStep         = @nStep  
         
      -- Get case label info  
      DECLARE @cDataWindow NVARCHAR(50)  
      DECLARE @cTargetDB   NVARCHAR(10)  
      SELECT  
         @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
         @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
      FROM RDT.RDTReport WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND ReportType ='CASELABEL'  
  
      -- Print case label  
      IF @@ROWCOUNT = 1   
      BEGIN  
         -- Check data window  
         IF ISNULL(@cDataWindow, '') = ''  
         BEGIN  
            SET @nErrNo = 55113  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
            GOTO Quit  
         END  
  
         -- Check database  
         IF ISNULL(@cTargetDB, '') = ''  
         BEGIN  
            SET @nErrNo = 55114  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
            GOTO Quit  
         END  
  
         -- Print case label  
         IF @cCarrierKey <> ''   
            IF EXISTS( SELECT 1 FROM Storer WITH (NOLOCK) WHERE StorerKey = @cCarrierKey AND Type IN ('2', '3') AND CustomerGroupCode <> 'W')  
               EXEC RDT.rdt_BuiltPrintJob  
                  @nMobile,  
                  @cStorerKey,  
                  'CASELABEL',       -- ReportType  
                  'PRINT_CASELABEL', -- PrintJobName  
                  @cDataWindow,  
                  @cPrinter,  
                  @cTargetDB,  
                  @cLangCode,  
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT,  
                  @cReceiptKey  
      END  
  
      -- Prepare next screen var  
      SET @cOutField01 = '' -- ReceiptKey  
      SET @cOutField02 = '' -- RefNo  
      SET @cOutField03 = '' -- CarrierKey  
      SET @cOutField04 = '' -- CarrierName  
      SET @cOutField05 = '' -- CarrierName  
      SET @cOutField06 = '' -- QTY  
        
      IF @cRefNo <> ''  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo  
      ELSE  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey  
  
      SET @cReceiptKey = ''  
      SET @cRefNo = ''  
  
      -- Remain in current screen  
      -- SET @nScn = @nScn + 1  
      -- SET @nStep = @nStep + 1  
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
         @cStorerKey  = @cStorerKey  
  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
  
      SET @cOutField01 = ''  
      GOTO Quit  
   END     
     
   Step_1_Quit:  
   BEGIN  
      -- Extended info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @nQTY, @cID, ' +   
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile       INT,           ' +  
               '@nFunc         INT,           ' +  
               '@cLangCode     NVARCHAR( 3),  ' +  
               '@nStep         INT,           ' +  
               '@nAfterStep    INT,           ' +   
               '@nInputKey     INT,           ' +  
               '@cFacility     NVARCHAR( 5),  ' +   
               '@cStorerKey    NVARCHAR( 15), ' +  
               '@cReceiptKey   NVARCHAR( 10), ' +  
               '@cRefNo        NVARCHAR( 20), ' +  
               '@nQTY          INT,           ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +   
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
     
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @nQTY, @cID,   
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
     
            SET @cOutField15 = @cExtendedInfo  
         END  
      END  
   END  
   GOTO Quit  
     
   Step_1_Fail:  
   BEGIN  
      IF @cRefNo <> ''  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo  
      ELSE  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey  
  
      SET @cOutField01 = '' -- ReceiptKey  
      SET @cOutField02 = '' -- RefNo  
      SET @cReceiptKey = ''  
      SET @cRefNo = ''  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 2. Scn = 4032. ID screen  
   TO ID  (field01, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cID = @cInField01 -- ID  
  
      -- Check ID blank  
      IF @cID = ''  
      BEGIN  
         SET @nErrNo = 55115  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID  
         GOTO Quit  
      END  
  
      -- Check ID format  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0  
      BEGIN  
         SET @nErrNo = 55116  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         SET @cOutField01 = '' -- ID  
         GOTO Quit  
      END  

      IF @cReturnRegisterField = ''  
         -- Update  
         UPDATE Receipt SET  
            ContainerQTY = @nQTY,   
            UserDefine06 = GETDATE(),   
            UserDefine02 = @cID  
         WHERE ReceiptKey = @cReceiptKey  
      ELSE  
      BEGIN  
         -- Extended update  
         IF @cExtendedUpdateSP <> '' AND   
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            INSERT INTO @tExtUpdVar (Variable, Value) VALUES   
               ('@cReceiptKey',           @cReceiptKey),   
               ('@cRefNo',                @cRefNo),   
               ('@nQTY',                  CAST( @nQTY AS NVARCHAR( 10))),   
               ('@cID',                   @cID),   
               ('@cReturnRegisterField',  @cReturnRegisterField)  
  
            SET @nErrNo = 0  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdVar, ' +   
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile       INT,           ' +  
               '@nFunc         INT,           ' +  
               '@cLangCode     NVARCHAR( 3),  ' +  
               '@nStep         INT,           ' +  
               '@nAfterStep    INT,           ' +   
               '@nInputKey     INT,           ' +  
               '@cFacility     NVARCHAR( 5),  ' +   
               '@cStorerKey    NVARCHAR( 15), ' +  
               '@tExtUpdVar    VariableTable READONLY, ' +   
               '@nErrNo        INT           OUTPUT, '  +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
     
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdVar, --(cc01)   
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
     
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
         ELSE  
         BEGIN  
            SET @nErrNo = 55119  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Upd SP  
            SET @cOutField01 = '' -- ID  
            GOTO Quit  
         END  
      END  
  
      SET @nErrNo = @@ERROR  
      IF @nErrNo <> 0  
         GOTO Quit  

      SET @nContainerQTY = @nQTY
      
      -- EventLog (james04)
      EXEC RDT.rdt_STD_EventLog  
         @cActionType   = '2', -- Return  
         @cUserID       = @cUserName,  
         @nMobileNo     = @nMobile,  
         @nFunctionID   = @nFunc,  
         @cFacility     = @cFacility,  
         @cStorerKey    = @cStorerKey,  
         @cReceiptKey   = @cReceiptKey,  
         @nQty          = @nContainerQTY,
         @nStep         = @nStep  

      -- Init next screen var  
      SET @cOutField01 = '' -- ReceiptKey  
      SET @cOutField02 = '' -- RefNo  
      SET @cOutField03 = '' -- CarrierKey  
      SET @cOutField04 = '' -- CarrierName  
      SET @cOutField05 = '' -- CarrierName  
      SET @cOutField06 = '' -- QTY  
      SET @cOutField15 = ''  
  
      IF @cRefNo <> ''  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo  
      ELSE  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey  
  
      SET @cReceiptKey = ''  
      SET @cRefNo = ''  
        
      -- Go to next screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
     
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare prev screen var  
      SET @cOutField01 = CASE WHEN @cRefNo = '' THEN @cReceiptKey ELSE '' END  
      SET @cOutField02 = @cRefNo  
      SET @cOutField03 = @cCarrierKey  
      SET @cOutField04 = rdt.rdtFormatString( @cCarrierName, 1, 20)  
      SET @cOutField05 = rdt.rdtFormatString( @cCarrierName, 21, 10)  
      SET @cOutField06 = CAST( @nQTY AS NVARCHAR(5))  
      SET @cOutField15 = ''  
  
      IF @cRefNo <> ''  
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo  
      ELSE  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey  
  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
  
   -- Extended info  
   IF @cExtendedInfoSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
      BEGIN  
         SET @cExtendedInfo = ''  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @nQTY, @cID, ' +   
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
         SET @cSQLParam =  
            '@nMobile       INT,           ' +  
            '@nFunc         INT,           ' +  
            '@cLangCode     NVARCHAR( 3),  ' +  
            '@nStep         INT,           ' +  
            '@nAfterStep    INT,           ' +   
            '@nInputKey     INT,           ' +  
            '@cFacility     NVARCHAR( 5),  ' +   
            '@cStorerKey    NVARCHAR( 15), ' +  
            '@cReceiptKey   NVARCHAR( 10), ' +  
            '@cRefNo        NVARCHAR( 20), ' +  
            '@nQTY          INT,           ' +  
            '@cID           NVARCHAR( 18), ' +  
            '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +   
            '@nErrNo        INT           OUTPUT, ' +  
            '@cErrMsg       NVARCHAR( 20) OUTPUT'  
  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @nQTY, @cID,   
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
         SET @cOutField15 = @cExtendedInfo  
      END  
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
  
      Facility     = @cFacility,  
      Printer      = @cPrinter,  
      -- UserName     = @cUserName,  
  
      V_StorerKey  = @cStorerKey,   
      V_ReceiptKey = @cReceiptKey,  
      V_POKey      = @cPOKey,  
      V_ID         = @cID,  
      V_SKUDescr   = @cCarrierName,  
  
      V_Integer1    = @nQTY,  
      V_Integer2    = @nCheckZeroQty,  
      V_Integer3    = @nContainerQTY,  

      V_String1    = @cRefNo,  
      V_String2    = @cCarrierKey,  
      V_String3    = @cAllowZeroQty,  
      V_String4    = @cExtendedInfoSP,  
      V_String5    = @cExtendedValidateSP,  
      V_String6    = @cExtendedUpdateSP,  
      V_String7    = @cReturnRegisterField,  
  
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