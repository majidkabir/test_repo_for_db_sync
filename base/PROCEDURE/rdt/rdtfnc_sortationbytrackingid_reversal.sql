SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_SortationByTrackingID_Reversal                  */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Reverse Tracking ID Capture                                    */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2020-03-12   1.0  James    WMS-12380 Created                            */
/* 2023-06-06   1.1  James    Addhoc fix. Change V_MAX to V_Max (james01)  */
/***************************************************************************/

CREATE   PROC [RDT].[rdtfnc_SortationByTrackingID_Reversal](
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
   @cSQLParam      NVARCHAR(MAX)

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
   @nFromStep      INT,
   
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
   @nDecodeQTY          INT,
   @nCaseCnt            INT,
   @nPallet             INT,
   @nQTY                INT,
   @cStatus             NVARCHAR( 10),
   @cType               NVARCHAR( 20),
   @nSKUValidated       INT,
   
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

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cLabelPrinter    = Printer,
   @cPaperPrinter    = Printer_Paper, 
   @nFromScn         = V_FromScn,
   @cSKUDescr        = V_SKUDescr,
   
   @cMax             = V_Max,

   @nSKUValidated       = V_Integer1,
      
   @cExtendedUpdateSP   = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedInfoSP     = V_String3,
   @cParentTrackID      = V_String4,
   @cChildTrackID       = V_String5,
   @cMatchSKUTrackID    = V_String6,
   @cMultiSKUBarcode    = V_String7,
   @cType               = V_String8,

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
   @nStep_ParentTracking   INT,  @nScn_ParentTracking    INT,
   @nStep_ChildTracking    INT,  @nScn_ChildTracking     INT,
   @nStep_ConfirmReversal  INT,  @nScn_ConfirmReversal   INT

SELECT
   @nStep_ParentTracking   = 1,  @nScn_ParentTracking    = 5700,
   @nStep_ChildTracking    = 2,  @nScn_ChildTracking     = 5701,
   @nStep_ConfirmReversal  = 3,  @nScn_ConfirmReversal   = 5702

IF @nFunc = 642
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 641
   IF @nStep = 1  GOTO Step_ParentTracking   -- Scn = 5700. Scan Carton ID, Pallet ID
   IF @nStep = 2  GOTO Step_ChildTracking    -- Scn = 5701. Scan To Pallet ID
   IF @nStep = 3  GOTO Step_ConfirmReversal  -- Scn = 5702. Confirm Reversal

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 642
********************************************************************************/
Step_Start:
BEGIN
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

   -- Prepare next screen var
   SET @cOutField01 = '' 

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
   SET @nScn = @nScn_ParentTracking
   SET @nStep = @nStep_ParentTracking
END
GOTO Quit

/************************************************************************************
Scn = 5700. Scan Pallet Serial
   Pallet Serial  (field01, input)
************************************************************************************/
Step_ParentTracking:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cParentTrackID = @cInField01
      SET @cOption = @cInField02

      -- Check blank
      IF ISNULL( @cParentTrackID, '') = '' 
      BEGIN
         SET @nErrNo = 149501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value req
         GOTO Step_ParentTracking_Fail
      END

      -- Check barcode format      
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PTRKID', @cParentTrackID) = 0      
      BEGIN
         SET @nErrNo = 149502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_ParentTracking_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.TrackingID WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   ParentTrackingID = @cParentTrackID)
      BEGIN
         SET @nErrNo = 149503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Not Exists
         GOTO Step_ParentTracking_Fail
      END
      
      SELECT TOP 1 @cStatus = [Status]
      FROM dbo.TrackingID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ParentTrackingID = @cParentTrackID
      ORDER BY 1 DESC   -- Get the max status

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 149503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Not Exists
         GOTO Step_ParentTracking_Fail
      END

      IF @cStatus = '1'
      BEGIN
         SET @nErrNo = 149513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Closed
         GOTO Step_ParentTracking_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
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
               @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Step_ParentTracking_Fail
         END
      END

      IF @cOption <> ''
      BEGIN
         SET @cOutField01 = @cParentTrackID
         SET @cOutField02 = ''
         SET @cOutField03 = ''      -- Option

         SET @cType = 'REVERSALPALLET'

         -- Go to next screen
         SET @nScn = @nScn_ConfirmReversal
         SET @nStep = @nStep_ConfirmReversal
         
         GOTO Quit
      END
      
      SET @cMax = ''
      SET @nSKUValidated = 0
      
      -- Prepare next screen var
      SET @cOutField01 = @cParentTrackID
      SET @cOutField02 = ''   -- SKU
      SET @cOutField03 = ''   -- Child Tracking ID

      EXEC RDT.rdtSetFocusField @nMobile , 2

      -- Go to next screen
      SET @nScn = @nScn_ChildTracking
      SET @nStep = @nStep_ChildTracking 
   END

   IF @nInputKey = 0 -- Esc or No
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

      -- Reset all variables
      SET @cOutField01 = '' 

      -- Enable field
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
   END
   GOTO Quit

   Step_ParentTracking_Fail:
   BEGIN
      SET @cOutField01 = ''
   END
   GOTO Quit
END
GOTO Quit

/***********************************************************************************
Scn = 5701. Parent Tracking ID SKU/Tracking ID screen
   Parent Tracking ID   (field01)
   SKU                  (field02, input)
   Child Tracking       (field03, input)
***********************************************************************************/
Step_ChildTracking:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen var
      SET @cBarcode = @cInField02 -- SKU
      SET @cUPC = LEFT( @cInField02, 30) -- SKU 
      SET @cChildTrackID = SUBSTRING( @cMax, 1, 1000)
      SET @nDecodeQTY = 0

      -- Check SKU blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 149504
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
            SET @nErrNo = 149505
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
                  SET @nStep = @nStep + 8
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
               SET @nErrNo = 149506
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
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
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
                  ' @cParentTrackID NVARCHAR( 20), ' +
                  ' @cChildTrackID  NVARCHAR( 1000),' +
                  ' @cSKU           NVARCHAR( 10), ' +
                  ' @nQty           INT,           ' +
                  ' @cOption        NVARCHAR( 1), ' +
                  ' @tExtInfo       VariableTable READONLY, ' + 
                  ' @cExtendedInfo  NVARCHAR( 20) OUTPUT   '  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtInfo, 
                  @cExtendedInfo OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
               
               IF @cExtendedInfo <> ''                        
                  SET @cOutField15 = @cExtendedInfo               
            END
         END

         -- Prepare next screen var
         SET @cOutField01 = @cParentTrackID
         SET @cOutField02 = @cSKU            -- SKU
         SET @cOutField03 = @cChildTrackID   -- Child Tracking ID

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
         SET @nErrNo = 149507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Child ID
         SET @cOutField02 = @cBarcode
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, V_Max
         GOTO Quit
      END

      -- Check barcode format      
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CTRKID', @cChildTrackID) = 0      
      BEGIN
         SET @nErrNo = 149508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Format
         SET @cMax = ''
         SET @cOutField02 = @cBarcode
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, V_Max
         GOTO Quit
      END      

      IF NOT EXISTS ( SELECT 1 FROM dbo.TrackingID WITH (NOLOCK)
                      WHERE StorerKey = StorerKey
                      AND   ParentTrackingID = @cParentTrackID
                      AND   TrackingID = @cChildTrackID)
      BEGIN
         SET @nErrNo = 149509
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID Not Exists
         SET @cMax = ''
         SET @cOutField02 = @cBarcode
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, V_Max
         GOTO Quit
      END     

      IF NOT EXISTS ( SELECT 1
                      FROM dbo.TrackingID WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   ParentTrackingID = @cParentTrackID
                      AND   TrackingID = @cChildTrackID
                      AND   SKU = @cSKU)
      BEGIN
         SET @nErrNo = 149512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU Not Exists
         SET @cOutField02 = ''
         SET @cOutField03 = @cMax
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END 
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
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
               @cParentTrackID, @cChildTrackID, @cSKU, @nQty, @cOption, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cParentTrackID
      SET @cOutField02 = @cChildTrackID
      SET @cOutField03 = ''      -- Option

      SET @cType = 'REVERSALCHILD'

      -- Go to next screen
      SET @nScn = @nScn_ConfirmReversal
      SET @nStep = @nStep_ConfirmReversal
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = ''

      -- Go to next screen
      SET @nScn = @nScn_ParentTracking
      SET @nStep = @nStep_ParentTracking
      
      EXEC RDT.rdtSetFocusField @nMobile , 1
   END
   GOTO Quit

   Step_ChildTrack_Fail:

END
GOTO Quit

/********************************************************************************
Scn = 5592. Confirm Reversal?
   Option (field01, input)
********************************************************************************/
Step_ConfirmReversal:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField03

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 149510
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Step_ConfirmReversal_Fail
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 149511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_ConfirmReversal_Fail
      END

      IF @cOption = '1'
      BEGIN
         EXEC [RDT].[rdt_SortationByTrackingID] 
            @nMobile          = @nMobile,
            @nFunc            = @nFunc,
            @cLangCode        = @cLangCode,
            @nStep            = @nStep,
            @nInputKey        = @nInputKey,
            @cFacility        = @cFacility,
            @cStorerKey       = @cStorerKey,
            @cParentTrackID   = @cParentTrackID,
            @cChildTrackID    = @cChildTrackID,
            @cSKU             = @cSKU,
            @nQTY             = @nQTY,
            @cType            = @cType,
            @nErrNo           = @nErrNo OUTPUT,
            @cErrMsg          = @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
      
      IF @cType = 'REVERSALCHILD'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cParentTrackID
         SET @cOutField02 = ''   -- SKU
         SET @cOutField03 = ''   -- Child Tracking ID

         SET @cMax = ''
         SET @nSKUValidated = 0
               
         EXEC RDT.rdtSetFocusField @nMobile , 2

         -- Go to next screen
         SET @nScn = @nScn_ChildTracking
         SET @nStep = @nStep_ChildTracking 
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' 
         SET @cOutField02 = ''

         -- Go to next screen
         SET @nScn = @nScn_ParentTracking
         SET @nStep = @nStep_ParentTracking
      
         EXEC RDT.rdtSetFocusField @nMobile , 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cType = 'REVERSALCHILD'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cParentTrackID
         SET @cOutField02 = ''   -- SKU
         SET @cOutField03 = ''   -- Child Tracking ID

         SET @cMax = ''
         SET @nSKUValidated = 0
               
         EXEC RDT.rdtSetFocusField @nMobile , 2

         -- Go to next screen
         SET @nScn = @nScn_ChildTracking
         SET @nStep = @nStep_ChildTracking 
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' 
         SET @cOutField02 = ''

         -- Go to next screen
         SET @nScn = @nScn_ParentTracking
         SET @nStep = @nStep_ParentTracking
      
         EXEC RDT.rdtSetFocusField @nMobile , 1
      END
   END
   GOTO Quit

   Step_ConfirmReversal_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOption = ''
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
      
      V_FromScn  = @nFromScn,
      V_SKUDescr = @cSKUDescr,
      
      V_Max      = @cMax,
      
      V_Integer1 = @nSKUValidated,
      
      V_String1  = @cExtendedUpdateSP,
      V_String2  = @cExtendedValidateSP,
      V_String3  = @cExtendedInfoSP,
      V_String4  = @cParentTrackID,
      V_String5  = @cChildTrackID,
      V_String6  = @cMatchSKUTrackID,
      V_String7  = @cMultiSKUBarcode,
      V_String8  = @cType,

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