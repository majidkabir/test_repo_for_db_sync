SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_TrackingIDSortByASN                             */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Sort Tracking ID By ASN                                        */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2020-03-24   1.0  James    WMS-12432 Created                            */
/* 2023-06-06   1.1  James    Addhoc fix. Change V_MAX to V_Max (james01)  */
/***************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TrackingIDSortByASN](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE 
   @cSQL           NVARCHAR(MAX), 
   @cSQLParam      NVARCHAR(MAX),
   @b_Success      INT,        
   @n_Err          INT,        
   @c_ErrMsg       NVARCHAR( 250)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,
   @bSuccess       INT,
   @nFromScn       INT,
   
   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cLabelPrinter  NVARCHAR( 10),
   @cPaperPrinter  NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cSKUDescr      NVARCHAR( 60),
   @cMultiSKUBarcode    NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20), 
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cBarcode            NVARCHAR( Max), 
   @cOption             NVARCHAR( 1), 
   @cPickConfirmStatus  NVARCHAR( 1),
   @cDefaultWeight      NVARCHAR( 1),  
   @tExtValidate        VariableTable, 
   @tExtUpdate          VariableTable, 
   @tExtInfo            VariableTable, 
   @tClosePallet        VariableTable, 
   @tPostPackSortCfm    VariableTable, 
   @cCartonID           NVARCHAR( 20),
   @cPalletID           NVARCHAR( 20),
   @nNoOfCheck          INT,
   @cLoadKey            NVARCHAR( 10),
   @cOrderKey           NVARCHAR( 10),
   @cParentTrackID      NVARCHAR( 20),
   @cChildTrackID       NVARCHAR( 1000),
   @cMax                NVARCHAR( MAX),
   @cUPC                NVARCHAR( 30),
   @cMatchSKUTrackID    NVARCHAR( 1),
   @cPOKeyDefaultValue  NVARCHAR( 10),        
   @cDefaultToLOC       NVARCHAR( 10),        
   @cReceiptKey         NVARCHAR( 10),        
   @cPOKey              NVARCHAR( 10),        
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cChkFacility        NVARCHAR( 5),        
   @cRefNo              NVARCHAR( 20),        
   @cStorerGroup        NVARCHAR( 20),        
   @cChkLOC             NVARCHAR( 10),
   @cLOCLookUP          NVARCHAR( 1),
   @cCheckIDInUse       NVARCHAR( 1),    
   @cCheckPLTID         NVARCHAR( 1),
   @cLoc2Close          NVARCHAR( 2),
   @nDecodeQTY          INT,
   @nCaseCnt            INT,
   @nPallet             INT,
   @nQTY                INT,
   @nASNExpectedQTY     INT,
   @nASNReceivedQTY     INT,
   @nScanned            INT,
   @nTrackingIDCnt      INT,
   @nTrackingIDSKUCnt   INT,
   @nSKUValidated       INT,
   
   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1), 
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerGroup     = StorerGroup,         
   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cLabelPrinter    = Printer,
   @cPaperPrinter    = Printer_Paper, 
   @nFromScn         = V_FromScn,
   @cSKUDescr        = V_SKUDescr,
   @cStorerKey       = V_StorerKey,        
   @cReceiptKey      = V_Receiptkey,        
   @cPOKey           = V_POKey,        
   @cLOC             = V_Loc,        
   @cID              = V_ID,        
   @cSKU             = V_SKU,        
   @nQTY             = V_QTY,        
      
   @cMax                = V_Max,
   
   @nCaseCnt            = V_Integer1,
   @nPallet             = V_Integer2,
   @nSKUValidated       = V_Integer3,
   
   @cExtendedUpdateSP   = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedInfoSP     = V_String3,
   @cParentTrackID      = V_String4,
   @cMatchSKUTrackID    = V_String5,
   @cMultiSKUBarcode    = V_String6,
   @cPOKeyDefaultValue  = V_String7,        
   @cDefaultToLOC       = V_String8,        
   @cRefNo              = V_String9,        
   @cLOCLookUP          = V_String10,      
   @cCheckIDInUse       = V_String11,    
   @cCheckPLTID         = V_String12,
   @cChildTrackID       = V_String13,
   @cParentTrackID      = V_String14,

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

-- Screen constant
DECLARE
   @nStep_ASN           INT,  @nScn_ASN         INT,
   @nStep_ToLoc         INT,  @nScn_ToLoc       INT,
   @nStep_SKU           INT,  @nScn_SKU         INT,
   @nStep_ToID          INT,  @nScn_ToID        INT,
   @nStep_RefNoLookUp   INT,  @nScn_RefNoLookUp INT,
   @nStep_MultiSKU      INT,  @nScn_MultiSKU    INT     

SELECT
   @nStep_ASN           = 1,  @nScn_ASN         = 5720,
   @nStep_ToLoc         = 2,  @nScn_ToLoc       = 5721,
   @nStep_SKU           = 3,  @nScn_SKU         = 5722,
   @nStep_ToID          = 4,  @nScn_ToID        = 5723,
   @nStep_RefNoLookUp   = 5,  @nScn_RefNoLookUp = 5724,
   @nStep_MultiSKU      = 6,  @nScn_MultiSKU    = 3570

IF @nFunc = 644
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start   -- Menu. Func = 644
   IF @nStep = 1  GOTO Step_ASN     -- Scn = 5720. Scan ASN, PO, Ref No
   IF @nStep = 2  GOTO Step_ToLoc   -- Scn = 5721. Scan To Loc
   IF @nStep = 3  GOTO Step_SKU     -- Scn = 5722. Scan SKU, ML
   IF @nStep = 4  GOTO Step_ToID    -- Scn = 5723. Scan To Id, PL
   IF @nStep = 5  GOTO Step_RefNoLookUp   -- Scn = 5724. Ref No Lookup
   IF @nStep = 6  GOTO Step_MultiSKU      -- Scn = 3570. Multi SKU Barocde

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 644
********************************************************************************/
Step_Start:
BEGIN
   -- Get storer config
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( @nFunc, 'ReceivingPOKeyDefaultValue', @cStorerKey)        
   IF @cPOKeyDefaultValue = '0'        
      SET @cPOKeyDefaultValue = ''    

   -- Prepare next screen var        
   SET @cOutField01 = '' -- ASN        
   SET @cOutField02 = @cPOKeyDefaultValue        
   SET @cOutField03 = '' -- ContainerNo    
   SET @cOutField04 = '' -- Option
   
   EXEC rdt.rdtSetFocusField @nMobile, 1

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep

      -- Go to next screen
      SET @nScn = @nScn_ASN
      SET @nStep = @nStep_ASN
END
GOTO Quit

/********************************************************************************        
Step 1. Scn = 5720. ASN, PO, Container No screen        
   ASN          (field01, input)        
   PO           (field02, input)        
   REF NO       (field03, input)   
   OPTION       (field04, input)
********************************************************************************/      
Step_ASN:        
BEGIN        
   IF @nInputKey = 1 -- Yes or Send        
   BEGIN        
      DECLARE @cChkReceiptKey NVARCHAR( 10)        
      DECLARE @cReceiptStatus NVARCHAR( 10)        
      DECLARE @cChkStorerKey NVARCHAR( 15)        
      DECLARE @nRowCount INT        
        
      -- Screen mapping        
      SET @cReceiptKey = @cInField01        
      SET @cPOKey = @cInField02        
      SET @cRefNo = @cInField03        
      SET @cLoc2Close = @cInField04
        
      -- Check ref no        
      IF @cRefNo <> '' AND @cReceiptKey = ''        
      BEGIN        
         -- Get storer config        
         DECLARE @cFieldName NVARCHAR(20)        
         SET @cFieldName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)        
                 
         -- Get lookup field data type        
         DECLARE @cDataType NVARCHAR(128)        
         SET @cDataType = ''        
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cFieldName        
                 
         IF @cDataType <> ''        
         BEGIN        
            IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE        
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE         
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE         
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)        
                                      
            -- Check data type        
            IF @n_Err = 0        
            BEGIN        
               SET @nErrNo = 150001        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo        
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo        
               GOTO Quit        
            END        
                    
            DECLARE @tReceipt TABLE        
            (        
               RowRef     INT IDENTITY( 1, 1),        
               ReceiptKey NVARCHAR( 10) NOT NULL        
            )        
           
            SET @cSQL =         
               ' SELECT ReceiptKey ' +         
               ' FROM dbo.Receipt WITH (NOLOCK) ' +         
               ' WHERE Facility = ' + QUOTENAME( @cFacility, '''') +         
                  ' AND ISNULL( ' + @cFieldName + CASE WHEN @cDataType IN ('int', 'float') THEN ',0)' ELSE ','''')' END + ' = ' + QUOTENAME( @cRefNo, '''') +         
               ' ORDER BY ReceiptKey '         
           
            -- Get ASN by RefNo        
            INSERT INTO @tReceipt (ReceiptKey)        
            EXEC (@cSQL)        
            SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT        
            IF @nErrNo <> 0        
               GOTO Quit        
           
            -- Check RefNo in ASN        
            IF @nRowCount = 0        
            BEGIN        
               SET @nErrNo = 150002        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN        
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- ContainerKey        
               GOTO Quit        
            END        
            SET @cOutField03 = @cRefNo        
           
            -- Only 1 ASN. Auto retrieve the ASN        
            IF @nRowCount = 1        
            BEGIN        
               SELECT @cReceiptKey = ReceiptKey FROM @tReceipt        
               SET @cOutField01 = @cReceiptKey        
            END        
           
            -- Multi ASN found, prompt user to select        
            IF @nRowCount > 1        
            BEGIN        
               DECLARE        
                  @cMsg1 NVARCHAR(20), @cMsg2 NVARCHAR(20), @cMsg3 NVARCHAR(20), @cMsg4 NVARCHAR(20), @cMsg5 NVARCHAR(20),        
                  @cMsg6 NVARCHAR(20), @cMsg7 NVARCHAR(20), @cMsg8 NVARCHAR(20), @cMsg9 NVARCHAR(20), @cMsg  NVARCHAR(20)        
               SELECT        
                  @cMsg1 = '', @cMsg2 = '', @cMsg3 = '', @cMsg4 = '', @cMsg5 = '',        
                  @cMsg6 = '', @cMsg7 = '', @cMsg8 = '', @cMsg9 = '', @cMsg = ''        
           
               SELECT        
                  @cMsg1 = CASE WHEN RowRef = 1 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg1 END,        
                  @cMsg2 = CASE WHEN RowRef = 2 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg2 END,        
                  @cMsg3 = CASE WHEN RowRef = 3 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg3 END,        
                  @cMsg4 = CASE WHEN RowRef = 4 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg4 END,        
                  @cMsg5 = CASE WHEN RowRef = 5 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg5 END,        
                  @cMsg6 = CASE WHEN RowRef = 6 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg6 END,        
                  @cMsg7 = CASE WHEN RowRef = 7 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg7 END,        
                  @cMsg8 = CASE WHEN RowRef = 8 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg8 END,        
                  @cMsg9 = CASE WHEN RowRef = 9 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg9 END        
               FROM @tReceipt        
           
               SET @cOutField01 = @cMsg1        
               SET @cOutField02 = @cMsg2        
               SET @cOutField03 = @cMsg3        
               SET @cOutField04 = @cMsg4        
               SET @cOutField05 = @cMsg5        
               SET @cOutField06 = @cMsg6        
               SET @cOutField07 = @cMsg7        
               SET @cOutField08 = @cMsg8        
               SET @cOutField09 = @cMsg9        
               SET @cOutField10 = '' -- Option        
                       
               -- Go to Lookup        
               SET @nScn = @nScn_RefNoLookUp        
               SET @nStep = @nStep_RefNoLookUp        
           
               GOTO Quit        
            END        
         END        
      END        

      -- Validate at least one field must key-in        
      IF (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND        
         (@cPOKey = '' OR @cPOKey IS NULL OR @cPOKey = 'NOPO') 
      BEGIN        
         SET @nErrNo = 150003        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN or PO        
         GOTO Step_ASN_Fail        
      END        

      -- Both ASN & PO keyed-in        
      IF NOT (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND        
         NOT (@cPOKey = '' OR @cPOKey IS NULL) AND        
         NOT (@cPOKey = 'NOPO')        
      BEGIN        
         -- Get the ASN        
         SELECT        
            @cChkFacility = R.Facility,        
            @cChkStorerKey = R.StorerKey,        
            @cChkReceiptKey = R.ReceiptKey,        
            @cReceiptStatus = R.Status        
         FROM dbo.Receipt R WITH (NOLOCK)        
            INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey        
         WHERE R.ReceiptKey = @cReceiptKey        
            AND RD.POKey = @cPOKey        
         SET @nRowCount = @@ROWCOUNT        
        
         -- No row returned, either ASN or PO not exists        
         IF @nRowCount = 0        
         BEGIN        
            DECLARE @nASNExist INT        
            DECLARE @nPOExist  INT        
            DECLARE @nPOInASN  INT        
        
            SET @nASNExist = 0        
            SET @nPOExist = 0        
            SET @nPOInASN = 0        
        
            -- Check ASN exists        
            IF EXISTS (SELECT 1 FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)        
               SET @nASNExist = 1        
        
            -- Check PO exists        
            IF EXISTS (SELECT 1 FROM dbo.PO WITH (NOLOCK) WHERE POKey = @cPOKey)        
               SET @nPOExist = 1        
        
            -- Check PO in ASN        
            IF EXISTS( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey AND RD.POKey = @cPOKey)        
               SET @nPOInASN = 1        
        
            -- Both ASN & PO also not exists        
            IF @nASNExist = 0 AND @nPOExist = 0        
            BEGIN        
               SET @nErrNo = 150004        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN&PONotExist        
               SET @cOutField01 = '' -- ReceiptKey        
               SET @cOutField02 = '' -- POKey        
               SET @cReceiptKey = ''        
               SET @cPOKey = ''        
               EXEC rdt.rdtSetFocusField @nMobile, 1        
               GOTO Quit        
            END        
        
            -- Only ASN not exists        
            ELSE IF @nASNExist = 0        
            BEGIN        
               SET @nErrNo = 150005        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN Not Exist        
               SET @cOutField01 = '' -- ReceiptKey        
               SET @cOutField02 = @cPOKey -- POKey        
               SET @cReceiptKey = ''        
               EXEC rdt.rdtSetFocusField @nMobile, 1        
               GOTO Quit        
            END        
        
            -- Only PO not exists        
            ELSE IF @nPOExist = 0        
            BEGIN        
               SET @nErrNo = 150006        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO Not Exist        
               SET @cOutField01 = @cReceiptKey        
               SET @cOutField02 = '' -- POKey        
               SET @cPOKey = ''        
               EXEC rdt.rdtSetFocusField @nMobile, 2        
               GOTO Quit        
            END        
        
            -- PO not in ASN        
            ELSE IF @nPOInASN = 0        
            BEGIN        
               SET @nErrNo = 150007        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO Not In ASN        
               SET @cOutField01 = @cReceiptKey        
               SET @cOutField02 = '' -- POKey        
               SET @cPOKey = ''        
               EXEC rdt.rdtSetFocusField @nMobile, 2        
               GOTO Quit        
            END        
         END        
      END        
      ELSE        
         -- Only ASN key-in (POKey = blank or NOPO)        
         IF (@cReceiptKey <> '' AND @cReceiptKey IS NOT NULL)        
         BEGIN        
            -- Validate whether ASN have multiple PO        
            DECLARE @cChkPOKey NVARCHAR( 10)        
            SELECT DISTINCT        
               @cChkPOKey = RD.POKey,        
               @cChkFacility = R.Facility,        
               @cChkStorerKey = R.StorerKey,        
               @cReceiptStatus = R.Status        
            FROM dbo.Receipt R WITH (NOLOCK)        
               INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey        
            WHERE RD.ReceiptKey = @cReceiptKey        
            -- If return multiple row, the last row is taken & assign into var.        
            -- We want blank POKey to be assigned if multiple row returned, hence using the DESC        
            ORDER BY RD.POKey DESC        
            SET @nRowCount = @@ROWCOUNT        
        
            -- No row returned, either ASN or ASN detail not exist        
            IF @nRowCount = 0        
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
                  SET @nErrNo = 150008        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exist        
                  SET @cOutField01 = '' -- ReceiptKey        
                  SET @cReceiptKey = ''        
                  EXEC rdt.rdtSetFocusField @nMobile, 1        
                  GOTO Quit        
               END        
            END        
        
            -- Auto retrieve PO, if only 1 PO in ASN        
            ELSE IF @nRowCount = 1        
            BEGIN        
               IF @cPOKey <> 'NOPO'        
                  SET @cPOKey = @cChkPOKey        
            END        
        
            -- Check multi PO in ASN        
            ELSE IF @nRowCount > 1        
            BEGIN        
               IF @cPOKey <> 'NOPO'        
               BEGIN        
                  SET @cPOKey = ''        
                  SET @nErrNo = 150009        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiPO In ASN        
                  SET @cOutField01 = @cReceiptKey        
                  SET @cOutField02 = ''        
                  SET @cPOKey = ''        
                  EXEC rdt.rdtSetFocusField @nMobile, 2        
                  GOTO Quit        
               END        
            END        
         END        
         ELSE
            -- Only PO key-in (POKey not blank or NOPO)        
            IF @cPOKey <> '' AND @cPOKey IS NOT NULL AND        
               @cPOKey <> 'NOPO'        
            BEGIN        
               -- Validate whether PO have multiple ASN        
               SELECT DISTINCT        
                  @cChkFacility = R.Facility,        
                  @cChkStorerKey = R.StorerKey,        
                  @cReceiptKey = R.ReceiptKey,        
                  @cReceiptStatus = R.Status        
               FROM dbo.Receipt R WITH (NOLOCK)        
                  INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey        
               WHERE RD.POKey = @cPOKey        
               SET @nRowCount = @@ROWCOUNT        
        
               IF @nRowCount = 0        
               BEGIN        
                  SET @nErrNo = 150010        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO not exist        
                  SET @cOutField02 = '' -- POKey        
                  SET @cPOKey = ''        
                  EXEC rdt.rdtSetFocusField @nMobile, 2        
                  GOTO Quit        
               END        
        
               IF @nRowCount > 1        
               BEGIN        
                  SET @nErrNo = 150011        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiASN in PO        
                  SET @cOutField01 = '' -- ReceiptKey        
                  SET @cOutField02 = @cPOKey        
                  SET @cReceiptKey = ''        
                  EXEC rdt.rdtSetFocusField @nMobile, 1        
                  GOTO Quit        
               END        
            END        
        
      -- Validate ASN in different facility        
      IF @cFacility <> @cChkFacility        
      BEGIN        
         SET @nErrNo = 150012        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility        
         SET @cOutField01 = '' -- ReceiptKey        
         SET @cReceiptKey = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Quit        
      END        
        
      -- Check storer group        
      IF @cStorerGroup <> ''        
      BEGIN        
         -- Check storer not in storer group        
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)        
         BEGIN        
            SET @nErrNo = 150013        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp        
            SET @cOutField01 = '' -- ReceiptKey        
            SET @cReceiptKey = ''        
            EXEC rdt.rdtSetFocusField @nMobile, 1        
            GOTO Quit        
         END        
        
         -- Set session storer        
         SET @cStorerKey = @cChkStorerKey        
      END        
        
      -- Validate ASN belong to the storer        
      IF @cStorerKey <> @cChkStorerKey        
      BEGIN        
         SET @nErrNo = 150014        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer        
         SET @cOutField01 = '' -- ReceiptKey        
         SET @cReceiptKey = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Quit        
      END        
        
      -- Validate ASN status        
      IF @cReceiptStatus = '9'        
      BEGIN        
         SET @nErrNo = 150015        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed        
         SET @cOutField01 = '' -- ReceiptKey        
         SET @cReceiptKey = ''        
         EXEC rdt.rdtSetFocusField @nMobile, 1        
         GOTO Quit        
      END        

      IF @cLoc2Close <> '' AND @cReceiptKey <> ''
      BEGIN
         --IF @cOption <> '1'
         --BEGIN        
         --   SET @nErrNo = 150036        
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option        
         --   SET @cOutField01 = @cReceiptKey -- ReceiptKey        
         --   SET @cOption = ''        
         --   EXEC rdt.rdtSetFocusField @nMobile, 4        
         --   GOTO Quit        
         --END 

         SET @nScanned = 0
         SELECT @nScanned = ISNULL( SUM( Qty), 0)
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UserDefine01 = @cLoc2Close
         AND   [Status] = '0'
         AND   Facility = @cFacility
         AND   ReceiptKey = @cReceiptKey
         AND   UserDefine02 = ''

         IF @@ROWCOUNT = 0 OR @nScanned = 0
         BEGIN
            SET @nErrNo = 150036        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Loc        
            SET @cOutField01 = @cReceiptKey -- ReceiptKey        
            SET @cLoc2Close = ''        
            EXEC rdt.rdtSetFocusField @nMobile, 4        
            GOTO Quit        
         END 

         -- Close ASN
         EXEC [RDT].[rdt_TrackingIDSortationByASN] 
            @nMobile          = @nMobile,
            @nFunc            = @nFunc,
            @cLangCode        = @cLangCode,
            @nStep            = @nStep,
            @nInputKey        = @nInputKey,
            @cFacility        = @cFacility,
            @cStorerKey       = @cStorerKey,
            @cReceiptKey      = @cReceiptKey,
            @cPOKey           = @cPOKey,
            @cRefNo           = @cRefNo,
            @cLOC             = @cLOC,
            @cID              = @cID,
            @cParentTrackID   = @cParentTrackID,
            @cChildTrackID    = @cChildTrackID,
            @cSKU             = @cSKU,
            @nQTY             = @nQTY,
            @cType            = 'RELEASELOC',
            @nErrNo           = @nErrNo OUTPUT,
            @cErrMsg          = @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN        
            SET @cOutField01 = @cReceiptKey -- ReceiptKey        
            SET @cLoc2Close = ''        
            EXEC rdt.rdtSetFocusField @nMobile, 4        
            GOTO Quit        
         END 

         SET @cErrMsg1 = 'LOC ' + @cLoc2Close 
         SET @cErrMsg2 = rdt.rdtgetmessage( 150037, @cLangCode, 'DSP') --Release Done
            
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2

         SET @nErrNo = 0
         SET @cErrMsg = ''

         -- Remain in same screen
         SET @cOutField01 = @cReceiptKey -- ASN        
         SET @cOutField02 = @cPOKeyDefaultValue        
         SET @cOutField03 = '' -- ContainerNo    
         SET @cOutField04 = '' -- Option
   
         EXEC rdt.rdtSetFocusField @nMobile, 1
         
         GOTO Quit
      END

      -- Get storer config        
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'  
         SET @cExtendedValidateSP = ''

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'  
         SET @cExtendedUpdateSP = ''

      SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      SET @cMatchSKUTrackID = rdt.rdtGetConfig( @nFunc, 'MatchSKUTrackID', @cStorerKey)
                       
      SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)        
      IF @cDefaultToLOC = '0'        
         SET @cDefaultToLOC = ''        

      -- DefaultToLOC, by facility        
      IF @cDefaultToLOC = ''        
      BEGIN        
         DECLARE @c_authority NVARCHAR(1)        
         SELECT @b_success = 0        
         EXECUTE nspGetRight        
            @cFacility,        
            @cStorerKey,        
            NULL, -- @cSKU        
            'ASNReceiptLocBasedOnFacility',        
            @b_success   OUTPUT,        
            @c_authority OUTPUT,        
            @n_err       OUTPUT,        
            @c_errmsg    OUTPUT        
           
         IF @b_success = '1' AND @c_authority = '1'        
            SELECT @cDefaultToLOC = UserDefine04        
            FROM Facility WITH (NOLOCK)        
            WHERE Facility = @cFacility        
      END        

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, ' +
               ' @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, ' + 
               ' @cExtendedInfo OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cPOKey         NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
               ' @cParentTrackID NVARCHAR( 20), ' +
               ' @cChildTrackID  NVARCHAR( 1000),' +
               ' @cSKU           NVARCHAR( 10), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT   '  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, 
               @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, 
               @cExtendedInfo OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
               
            IF @cExtendedInfo <> ''                        
               SET @cOutField15 = @cExtendedInfo               
         END
      END

      -- Prepare next screen var        
      SET @cOutField01 = @cReceiptKey        
      SET @cOutField02 = @cPOKey        
      SET @cOutField03 = @cDefaultToLOC        

      EXEC rdt.rdtSetFocusField @nMobile, 3  -- To Loc
              
      -- Go to next screen        
      SET @nScn = @nScn_ToLoc
      SET @nStep = @nStep_ToLoc      
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
   END        
   GOTO Quit        
        
   Step_ASN_Fail:        
   BEGIN        
      -- Reset this screen var        
      SET @cOutField01 = '' -- ReceiptKey        
      SET @cOutField02 = '' -- POKey        
      SET @cReceiptKey = ''        
      SET @cPOKey = ''        
   END        
END        
GOTO Quit  

/********************************************************************************        
Step 2. Scn = 5721. Location screen        
   ASN   (field01)        
   PO    (field02)        
   TOLOC (field03, input)        
********************************************************************************/        
Step_ToLoc:        
BEGIN        
   IF @nInputKey = 1 -- Yes or Send        
   BEGIN        
      -- Screen mapping        
      SET @cLOC = @cInField03 -- LOC        
        
      -- Validate compulsary field        
      IF ISNULL( @cLOC, '') = ''         
      BEGIN        
         SET @nErrNo = 150016        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC        
         GOTO Step_ToLoc_Fail        
      END        
      
      --Loc Prefix      
      IF @cLOCLookUP = '1'         
      BEGIN          
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,           
            @cLOC       OUTPUT,           
            @nErrNo     OUTPUT,           
            @cErrMsg    OUTPUT          

         IF @nErrNo <> 0          
         GOTO Step_ToLoc_Fail          
      END      
        
      -- Get the location        
      SET @cChkLOC = ''        
      SET @cChkFacility = ''        
      SELECT        
         @cChkLOC = LOC,        
         @cChkFacility = Facility        
      FROM dbo.LOC WITH (NOLOCK)        
      WHERE LOC = @cLOC        
        
      -- Validate location        
      IF @cChkLOC = ''        
      BEGIN        
         SET @nErrNo = 150017        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC        
         GOTO Step_ToLoc_Fail        
      END        
        
      -- Validate location not in facility        
      IF @cChkFacility <> @cFacility        
      BEGIN        
         SET @nErrNo = 150018        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility        
         GOTO Step_ToLoc_Fail        
      END        

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cOutField15 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, ' +
               ' @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, ' + 
               ' @cExtendedInfo OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cPOKey         NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
               ' @cParentTrackID NVARCHAR( 20), ' +
               ' @cChildTrackID  NVARCHAR( 1000),' +
               ' @cSKU           NVARCHAR( 10), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT   '  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, 
               @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, 
               @cExtendedInfo OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
               
            IF @cExtendedInfo <> ''                        
               SET @cOutField15 = @cExtendedInfo               
         END
      END
      
      -- Prepare next screen var        
      SET @cOutField01 = @cLOC        
      SET @cOutField02 = ''        
      SET @cOutField03 = ''
      
      SET @cMax = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2
      
      SET @nSKUValidated = 0

      -- Go to next screen        
      SET @nScn  = @nScn_SKU
      SET @nStep = @nStep_SKU        
   END        
        
   IF @nInputKey = 0 -- Esc or No        
   BEGIN        
      -- Prepare prev screen var        
      SET @cOutField01 = @cReceiptKey        
      SET @cOutField02 = @cPOKey        
      SET @cOutField03 = @cRefNo        
      SET @cOutField04 = ''
        
      SET @nScn = @nScn_ASN
      SET @nStep = @nStep_ASN
   END        
   GOTO Quit        
        
   Step_ToLoc_Fail:        
   BEGIN        
      -- Reset this screen var        
      SET @cOutField03 = '' -- LOC        
      SET @cLOC = ''        
   END        
END        
GOTO Quit        

/***********************************************************************************
Scn = 5723. To Location, SKU, Child ID screen
   To Loc      (field01)
   SKU         (field02, input)
   Child ID    (field03, input)
***********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen var
      SET @cBarcode = @cInField02 -- SKU
      SET @cUPC = LEFT( @cInField02, 30) -- SKU 
      SET @cChildTrackID = SUBSTRING( @cMax, 1, 1000)
      SET @nDecodeQTY = 0

      IF ISNULL( @cUPC, '') = '' AND ISNULL( @cChildTrackID, '') = ''
      BEGIN
         SET @nErrNo = 150019
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Value
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END
      
      -- Check SKU blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 150020
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
         SET @cOutField02 = ''
         SET @cOutField03 = @cMax
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
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
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
                  @cUPC          = @cUPC           OUTPUT, 
                  @nQTY          = @nDecodeQTY     OUTPUT, 
                  @cUserDefine01 = @cChildTrackID  OUTPUT,
                  @nErrNo        = @nErrNo         OUTPUT, 
                  @cErrMsg       = @cErrMsg        OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
            
            -- Customize decode
            ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cParentTrackID, @cChildTrackID, @cBarcode, ' +
                  ' @cUPC OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cFacility      NVARCHAR( 5),  ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cParentTrackID NVARCHAR( 20), ' +
                  ' @cChildTrackID  NVARCHAR( 1000),' +
                  ' @cBarcode       NVARCHAR( 60),  ' +
                  ' @cUPC           NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY           INT            OUTPUT, ' +
                  ' @nErrNo         INT            OUTPUT, ' +
                  ' @cErrMsg        NVARCHAR( 20)  OUTPUT'
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cParentTrackID, @cChildTrackID, @cBarcode, 
                  @cUPC OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
   
               IF @nErrNo <> 0
               BEGIN
                  SET @cOutField02 = ''
                  SET @cOutField03 = @cMax
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Quit
               END

               IF ISNULL( @nQTY, 0) > 0
                  SET @nDecodeQTY = @nQTY
            END
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
            SET @nErrNo = 150021
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
            SET @cOutField02 = ''
            SET @cOutField03 = @cMax
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
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
                  '',    -- DocType
                  ''

               IF @nErrNo = 0 -- Populate multi SKU screen
               BEGIN
                  -- Go to Multi SKU screen
                  SET @nFromScn = @nScn
                  SET @nScn = 3570
                  SET @nStep = @nStep_MultiSKU
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
               SET @nErrNo = 150022
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiBarcodSKU
               SET @cOutField02 = ''
               SET @cOutField03 = @cMax
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Quit
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

         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                         WHERE ReceiptKey = @cReceiptKey
                         AND   SKU = @cSKU)
         BEGIN
            SET @nErrNo = 150023
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
            SET @cOutField02 = ''
            SET @cOutField03 = @cMax
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
         
         -- Get SKU info
         SELECT @cSKUDescr = SKU.DESCR,
                @nCaseCnt = Pack.CaseCnt,
                @nPallet = Pack.Pallet 
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU
                     
         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cOutField15 = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, ' +
                  ' @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, ' + 
                  ' @cExtendedInfo OUTPUT '
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cFacility      NVARCHAR( 5),  ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cReceiptKey    NVARCHAR( 10), ' +
                  ' @cPOKey         NVARCHAR( 10), ' +
                  ' @cRefNo         NVARCHAR( 20), ' +
                  ' @cLOC           NVARCHAR( 10), ' +
                  ' @cID            NVARCHAR( 18), ' +
                  ' @cParentTrackID NVARCHAR( 20), ' +
                  ' @cChildTrackID  NVARCHAR( 1000),' +
                  ' @cSKU           NVARCHAR( 10), ' +
                  ' @nQty           INT,           ' +
                  ' @cOption        NVARCHAR( 1), ' +
                  ' @tExtInfo       VariableTable READONLY, ' + 
                  ' @cExtendedInfo  NVARCHAR( 20) OUTPUT   '  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, 
                  @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, 
                  @cExtendedInfo OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
               
               IF @cExtendedInfo <> ''                        
                  SET @cOutField15 = @cExtendedInfo               
            END
         END

         SET @cID = ''
         SET @cParentTrackID = ''
      
         SELECT TOP 1 
            @cID = DropID,
            @cParentTrackID = ParentTrackingID
         FROM dbo.TrackingID T1 WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   SKU = @cSKU
         AND   [Status] = '0'
         AND   Facility = @cFacility
         AND   UserDefine02 = ''
         AND   ( SELECT ISNULL( SUM( QTY), 0) 
                 FROM dbo.TrackingID T2 WITH (NOLOCK) 
                 WHERE T1.ReceiptKey = T2.ReceiptKey 
                 AND T1.ParentTrackingID = T2.ParentTrackingID 
                 AND T1.SKU = T2.SKU) < @nPallet
         ORDER BY TrackingIDKey

         SET @nScanned = 0
         SELECT @nScanned = ISNULL( SUM( Qty), 0)
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ParentTrackingID = @cParentTrackID
         AND   [Status] = '0'
         AND   Facility = @cFacility
      
         -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cSKU            -- SKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField05 = @cChildTrackID   -- Child Tracking ID
         SET @cOutField06 = '1:' + CAST( @nCaseCnt AS NVARCHAR( 4))   -- Packinfo

         SET @nTrackingIDCnt = 0
         SELECT @nTrackingIDCnt = COUNT( DISTINCT TrackingID)
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ParentTrackingID = @cParentTrackID
         AND   [Status] = '0'
         AND   Facility = @cFacility
         
         SET @cOutField07 = CAST((@nCaseCnt * @nTrackingIDCnt) AS NVARCHAR( 5)) + '/' + CAST( @nPallet AS NVARCHAR( 5))

         SET @nASNExpectedQTY = 0
         SET @nASNReceivedQTY = 0
         SELECT @nASNExpectedQTY = ISNULL( SUM( QtyExpected), 0), 
                @nASNReceivedQTY = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   SKU = @cSKU
      
         SET @cOutField08 = CAST( @nASNReceivedQTY AS NVARCHAR( 5)) + '/' + CAST( @nASNExpectedQTY AS NVARCHAR( 5))
         
         IF @cChildTrackID = '' AND @nSKUValidated = 0
         BEGIN
            SET @nSKUValidated = 1
            SET @cOutField02 = @cBarcode
            EXEC rdt.rdtSetFocusField @nMobile, V_Max
            GOTO Quit
         END
      END

      -- Check SKU blank
      IF @cChildTrackID = ''
      BEGIN
         SET @nErrNo = 150024
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Child ID
         SET @cOutField02 = @cBarcode
         SET @cOutField05 = ''
         EXEC rdt.rdtSetFocusField @nMobile, V_Max
         GOTO Quit
      END

      -- Check barcode format      
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CTRACKID', @cChildTrackID) = 0  
      BEGIN
         SET @nErrNo = 150025
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Format
         SET @cMax = ''
         SET @cOutField02 = @cBarcode
         SET @cOutField05 = ''
         EXEC rdt.rdtSetFocusField @nMobile, V_Max
         GOTO Quit
      END      

      IF EXISTS ( SELECT 1 FROM dbo.TrackingID WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   TrackingID = @cChildTrackID
                  AND   [Status] = '0'
                  AND   Facility = @cFacility)
      BEGIN
         SET @nErrNo = 150026
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- TrackID Scanned
         SET @cMax = ''
         SET @cOutField02 = @cBarcode
         SET @cOutField05 = ''
         EXEC rdt.rdtSetFocusField @nMobile, V_Max
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, ' + 
               ' @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtValidate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cPOKey         NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
               ' @cParentTrackID NVARCHAR( 20), ' +
               ' @cChildTrackID  NVARCHAR( 1000),' +
               ' @cSKU           NVARCHAR( 10), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, 
               @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cOutField15 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, ' +
               ' @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, ' + 
               ' @cExtendedInfo OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cPOKey         NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
               ' @cParentTrackID NVARCHAR( 20), ' +
               ' @cChildTrackID  NVARCHAR( 1000),' +
               ' @cSKU           NVARCHAR( 10), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT   '  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, 
               @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, 
               @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> '' 
               SET @cOutField15 = @cExtendedInfo
         END
      END

      SET @cMax = ''
      /*
      SELECT @nScanned = COUNT( DISTINCT TrackingID)
      FROM dbo.TrackingID WITH (NOLOCK)
      WHERE ParentTrackingID = @cParentTrackID
      AND   [Status] = '0'

      -- Prepare next screen var
      SET @cOutField01 = @cParentTrackID
      SET @cOutField02 = CASE WHEN @cMatchSKUTrackID = '1' THEN '' ELSE @cSKU END
      SET @cOutField03 = ''
      SET @cOutField04 = @nScanned
      SET @cOutField15 = @cExtendedInfo

      IF @cMatchSKUTrackID = '1'
      BEGIN
         SET @cMax = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
      END
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, V_Max
         */
      
      SET @cID = ''
      SET @cParentTrackID = ''

      SELECT TOP 1 
         @cID = DropID,
         @cParentTrackID = ParentTrackingID
      FROM dbo.TrackingID T1 WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   SKU = @cSKU
      AND   [Status] = '0'
      AND   Facility = @cFacility
      AND   UserDefine02 = ''
      AND   ( SELECT ISNULL( SUM( QTY), 0) 
              FROM dbo.TrackingID T2 WITH (NOLOCK) 
              WHERE T1.ReceiptKey = T2.ReceiptKey 
              AND T1.ParentTrackingID = T2.ParentTrackingID 
              AND T1.SKU = T2.SKU) < @nPallet
      ORDER BY TrackingIDKey

      SET @nScanned = 0
      SELECT @nScanned = ISNULL( SUM( Qty), 0)
      FROM dbo.TrackingID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ParentTrackingID = @cParentTrackID
      AND   [Status] = '0'
      AND   Facility = @cFacility

      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN @nPallet = @nScanned THEN '' ELSE @cID END
      SET @cOutField02 = CASE WHEN @nPallet = @nScanned THEN '' ELSE @cParentTrackID END

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID        

      -- Go to next screen
      SET @nScn = @nScn_ToID
      SET @nStep = @nStep_ToID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey 
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = ''

      SET @cLOC = ''

      -- Go to next screen
      SET @nScn = @nScn_ToLoc
      SET @nStep = @nStep_ToLoc
   END
   GOTO Quit

   Step_SKU_Fail:

END
GOTO Quit

/********************************************************************************
Scn = 5723. Scan To ID, Parent Tracking ID screen
   To ID                (field01, input)
   Parent Tracking ID   (field02, input)
********************************************************************************/
Step_ToID:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      -- Screen mapping    
      SET @cID = LEFT( @cInField01, 18) -- ID    
      SET @cParentTrackID = @cInField02
      
      IF ISNULL( @cID, '') = '' AND ISNULL( @cParentTrackID, '') = ''
      BEGIN        
         SET @nErrNo = 150027        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value        
         SET @cOutField01 = ''
         SET @cOutField02 = @cParentTrackID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit        
      END 

      IF ISNULL( @cID, '') = ''
      BEGIN        
         SET @nErrNo = 150028        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Id        
         SET @cOutField01 = ''
         SET @cOutField02 = @cParentTrackID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit         
      END 
      ELSE
      BEGIN
         -- Check barcode format    
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0    
         BEGIN        
            SET @nErrNo = 150029        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format        
            SET @cOutField01 = ''
            SET @cOutField02 = @cParentTrackID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit         
         END        
        
         -- Validate pallet id received. If config turn on then not allow reuse    
         IF @cCheckIDInUse = '1'    
         BEGIN    
            IF EXISTS( SELECT [ID]    
               FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)    
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)    
               WHERE [ID] = @cID    
               AND   QTY > 0    
               AND   StorerKey = @cStorerKey    
               AND   LOC.Facility = @cFacility)    
            BEGIN    
               SET @nErrNo = 150030    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID    
               SET @cOutField01 = ''
               SET @cOutField02 = @cParentTrackID
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit     
            END    
         END    
              
         -- Check pallet received        
         IF @cCheckPLTID = '1'        
         BEGIN        
            IF EXISTS (SELECT 1 FROM  dbo.ReceiptDetail RD WITH (NOLOCK)        
                       WHERE RD.ReceiptKey = @cReceiptKey        
                       AND RD.StorerKey = @cStorerKey        
                       AND RD.ToID = RTRIM(@cID)        
                       AND RD.BeforeReceivedQty > 0)        
            BEGIN        
               SET @nErrNo = 150031        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID received        
               SET @cOutField01 = ''
               SET @cOutField02 = @cParentTrackID
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit         
            END        
         END        

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, ' + 
                  ' @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, ' + 
                  ' @cExtendedInfo OUTPUT '
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cFacility      NVARCHAR( 5),  ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cReceiptKey    NVARCHAR( 10), ' +
                  ' @cPOKey         NVARCHAR( 10), ' +
                  ' @cRefNo         NVARCHAR( 20), ' +
                  ' @cLOC           NVARCHAR( 10), ' +
                  ' @cID            NVARCHAR( 18), ' +
                  ' @cParentTrackID NVARCHAR( 20), ' +
                  ' @cChildTrackID  NVARCHAR( 1000),' +
                  ' @cSKU           NVARCHAR( 10), ' +
                  ' @nQty           INT,           ' +
                  ' @cOption        NVARCHAR( 1), ' +
                  ' @tExtInfo       VariableTable READONLY, ' + 
                  ' @cExtendedInfo  NVARCHAR( 20) OUTPUT   '  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, 
                  @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, 
                  @cExtendedInfo OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
               
               IF @cExtendedInfo <> ''                        
                  SET @cOutField15 = @cExtendedInfo               
            END
         END

         -- Prepare next screen var
         SET @cOutField01 = @cID
         SET @cOutField02 = @cParentTrackID            -- SKU

         EXEC rdt.rdtSetFocusField @nMobile, 2
      END
      
      IF ISNULL( @cParentTrackID, '') = ''
      BEGIN
         SET @nErrNo = 150032        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Parent ID        
         SET @cOutField01 = @cID
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit     
      END
      ELSE
      BEGIN
         -- Check barcode format      
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PTRACKID', @cParentTrackID) = 0      
         BEGIN
            SET @nErrNo = 150033
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            SET @cOutField01 = @cID
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit  
         END

         IF EXISTS ( SELECT 1 FROM dbo.TrackingID WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   ParentTrackingID = @cParentTrackID
                     AND   [Status] = '1'
                     AND   Facility = @cFacility)
         BEGIN
            SET @nErrNo = 150034
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Closed
            SET @cOutField01 = @cID
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit  
         END

         SET @nScanned = 0
         SELECT @nScanned = ISNULL( SUM( Qty), 0)
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ParentTrackingID = @cParentTrackID
         AND   [Status] = '0'
         AND   Facility = @cFacility
         
         IF @nCaseCnt + @nScanned > @nPallet
         BEGIN
            SET @nErrNo = 150035
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Scanned
            GOTO Quit
         END
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, ' + 
               ' @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtValidate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cPOKey         NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
               ' @cParentTrackID NVARCHAR( 20), ' +
               ' @cChildTrackID  NVARCHAR( 1000),' +
               ' @cSKU           NVARCHAR( 10), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, 
               @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END

      -- Confirm
      EXEC [RDT].[rdt_TrackingIDSortationByASN] 
         @nMobile          = @nMobile,
         @nFunc            = @nFunc,
         @cLangCode        = @cLangCode,
         @nStep            = @nStep,
         @nInputKey        = @nInputKey,
         @cFacility        = @cFacility,
         @cStorerKey       = @cStorerKey,
         @cReceiptKey      = @cReceiptKey,
         @cPOKey           = @cPOKey,
         @cRefNo           = @cRefNo,
         @cLOC             = @cLOC,
         @cID              = @cID,
         @cParentTrackID   = @cParentTrackID,
         @cChildTrackID    = @cChildTrackID,
         @cSKU             = @cSKU,
         @nQTY             = @nQTY,
         @cType            = 'NEW',
         @nErrNo           = @nErrNo OUTPUT,
         @cErrMsg          = @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, ' + 
               ' @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtUpdate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cPOKey         NVARCHAR( 10), ' +
               ' @cRefNo         NVARCHAR( 20), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
               ' @cParentTrackID NVARCHAR( 20), ' +
               ' @cChildTrackID  NVARCHAR( 1000),' +
               ' @cSKU           NVARCHAR( 10), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdate     VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cID, 
               @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtUpdate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END

      SET @cMax = ''
      
      -- Prepare prev screen var        
      SET @cOutField01 = @cLOC        
      SET @cOutField02 = ''        
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)      
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cMax
      SET @cOutField06 = '1:' + CAST( @nCaseCnt AS NVARCHAR( 4))
      
      SET @nTrackingIDCnt = 0
      SELECT @nTrackingIDCnt = COUNT( DISTINCT TrackingID)
      FROM dbo.TrackingID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ParentTrackingID = @cParentTrackID
      AND   [Status] = '0'
      AND   Facility = @cFacility
         
      SET @cOutField07 = CAST((@nCaseCnt * @nTrackingIDCnt) AS NVARCHAR( 5)) + '/' + CAST( @nPallet AS NVARCHAR( 5))

      SET @nASNExpectedQTY = 0
      SET @nASNReceivedQTY = 0
      SELECT @nASNExpectedQTY = ISNULL( SUM( QtyExpected), 0), 
             @nASNReceivedQTY = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   SKU = @cSKU
      
      --SET @cOutField08 = CAST((@nCaseCnt * @nTrackingIDSKUCnt) AS NVARCHAR( 4)) + '/' + CAST( @nASNExpectedQTY AS NVARCHAR( 4))
      SET @cOutField08 = CAST( @nASNReceivedQTY AS NVARCHAR( 5)) + '/' + CAST( @nASNExpectedQTY AS NVARCHAR( 5))
      
      EXEC rdt.rdtSetFocusField @nMobile, 2  
      
      SET @nSKUValidated = 0

      -- Goto SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU    
   END        
        
   IF @nInputKey = 0 -- Esc or No        
   BEGIN        
      -- Prepare prev screen var        
      SET @cOutField01 = @cLOC        
      SET @cOutField02 = ''        
      SET @cOutField03 = ''        
      SET @cOutField04 = ''        
      SET @cOutField05 = ''
      SET @cOutField06 = ''        
      SET @cOutField07 = ''
      SET @cOutField08 = ''        

      EXEC rdt.rdtSetFocusField @nMobile, 2

      SET @nSKUValidated = 0

      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU          
   END        
   GOTO Quit        
        
   Step_ToID_Fail:        
   BEGIN        
      -- Reset this screen var        
      SET @cOutField01 = '' -- To ID        
      SET @cOutField02 = '' -- Parent Tracking ID  
                            
      SET @cID = '' 
      SET @cParentTrackID = ''
   END        
END        
GOTO Quit     

/********************************************************************************        
Step 5. Screen = 5724. Refno Lookup        
   ASN1     (Field01)        
   ASN2     (Field02)        
   ASN3     (Field03)        
   ASN4     (Field04)        
   ASN5     (Field05)        
   ASN6     (Field06)        
   ASN7     (Field07)        
   ASN8     (Field08)        
   ASN9     (Field09)        
   OPTION   (Field10, input)        
********************************************************************************/        
Step_RefNoLookUp:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      -- Screen mapping        
      SET @cOption = @cInField10        
        
      -- Check blank        
      IF @cOption = ''        
      BEGIN        
         SET @nErrNo = 59441        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option        
         GOTO Quit        
      END        
        
      -- Check valid         
      IF @cOption NOT BETWEEN '1' AND '9'        
      BEGIN        
         SET @nErrNo = 59442        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option        
         GOTO Quit        
      END        
        
      -- Check option selectable        
      IF @cOption = '1' AND @cOutField01 = '' OR        
         @cOption = '2' AND @cOutField02 = '' OR        
         @cOption = '3' AND @cOutField03 = '' OR        
         @cOption = '4' AND @cOutField04 = '' OR        
         @cOption = '5' AND @cOutField05 = '' OR        
         @cOption = '6' AND @cOutField06 = '' OR        
         @cOption = '7' AND @cOutField07 = '' OR        
         @cOption = '8' AND @cOutField08 = '' OR        
         @cOption = '9' AND @cOutField09 = ''         
      BEGIN        
         SET @nErrNo = 59443        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not an option        
         GOTO Quit        
      END        
              
      -- Abstract ASN        
      IF @cOption = '1' SET @cReceiptKey = SUBSTRING( @cOutField01, 4, 10) ELSE        
      IF @cOption = '2' SET @cReceiptKey = SUBSTRING( @cOutField02, 4, 10) ELSE        
      IF @cOption = '3' SET @cReceiptKey = SUBSTRING( @cOutField03, 4, 10) ELSE        
      IF @cOption = '4' SET @cReceiptKey = SUBSTRING( @cOutField04, 4, 10) ELSE        
      IF @cOption = '5' SET @cReceiptKey = SUBSTRING( @cOutField05, 4, 10) ELSE        
      IF @cOption = '6' SET @cReceiptKey = SUBSTRING( @cOutField06, 4, 10) ELSE        
      IF @cOption = '7' SET @cReceiptKey = SUBSTRING( @cOutField07, 4, 10) ELSE        
      IF @cOption = '8' SET @cReceiptKey = SUBSTRING( @cOutField08, 4, 10) ELSE        
      IF @cOption = '9' SET @cReceiptKey = SUBSTRING( @cOutField09, 4, 10)        
        
      -- Prepare prev screen var        
      SET @cOutField01 = @cReceiptKey        
      SET @cOutField02 = @cPOKey        
      SET @cOutField03 = @cRefNo        
      SET @cOutField04 = '' -- Option
        
      -- Go back to ASN/PO screen        
      SET @nScn = @nScn_ASN     
      SET @nStep = @nStep_ASN     
   END        
        
   IF @nInputKey = 0 -- ESC        
   BEGIN        
      -- Prepare prev screen var        
      SET @cOutField01 = @cReceiptKey        
      SET @cOutField02 = @cPOKey        
      SET @cOutField03 = @cRefNo        
      SET @cOutField04 = '' -- Option
        
      -- Go back to ASN/PO screen        
      SET @nScn = @nScn_ASN        
      SET @nStep = @nStep_ASN        
   END        
END        
GOTO Quit       

/********************************************************************************    
Step 6. Screen = 3570. Multi SKU    
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
Step_MultiSKU:    
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
         @cInField07 OUTPUT, @cOutField07 OUTPUT,    
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
      SELECT @cSKUDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU    
   END    
    
   -- Init next screen var    
   SET @cOutField01 = @cLOC    
   SET @cMax = @cSKU -- SKU    
   SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20) -- SKUDesc1    
   SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKUDesc2    
   SET @cOutField05 = @cMax

   -- Go to SKU QTY screen    
   SET @nScn = @nFromScn    
   SET @nStep = @nStep_SKU    
    
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
      
      V_FromScn  = @nFromScn,
      V_SKUDescr = @cSKUDescr,
      V_StorerKey  = @cStorerKey,         
      V_ReceiptKey = @cReceiptKey,        
      V_POKey      = @cPOKey,        
      V_Loc        = @cLOC,        
      V_ID         = @cID,        
      V_SKU        = @cSKU,        
            
      V_Max      = @cMax,

      V_Integer1 = @nCaseCnt,
      V_Integer2 = @nPallet,
      V_Integer3 = @nSKUValidated,

      V_String1  = @cExtendedUpdateSP,
      V_String2  = @cExtendedValidateSP,
      V_String3  = @cExtendedInfoSP,
      V_String4  = @cParentTrackID,
      V_String5  = @cMatchSKUTrackID,
      V_String6  = @cMultiSKUBarcode,
      V_String7  = @cPOKeyDefaultValue,
      V_String8  = @cDefaultToLOC,
      V_String9  = @cRefNo,
      V_String10 = @cLOCLookUP,
      V_String11 = @cCheckIDInUse,
      V_String12 = @cCheckPLTID,
      V_String13 = @cChildTrackID,
      V_String14 = @cParentTrackID,
   
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