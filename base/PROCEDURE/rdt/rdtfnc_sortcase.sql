SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_SortCase                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Sort full case                                                    */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-01-20 1.0  Ung      WMS-1085 Created                                  */
/* 2018-03-05 1.1  Ung      WMS-4202 Add MultiLoadKey                         */
/* 2018-10-03 1.2  Gan      Performance tuning                                */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_SortCase] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @bSuccess      INT, 
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX), 
   @nRowCount     INT, 
   @cScan         NVARCHAR( 5),
   @cTotal        NVARCHAR( 5),
   @cPOS          NVARCHAR( 20)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cUserName   NVARCHAR( 18),
   @cPrinter    NVARCHAR( 10),

   @cLoadKey    NVARCHAR( 10),
   @cUCCNo      NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @nQTY        INT, 

   @cLastLoadKey  NVARCHAR( 10),
   @cLoadKeyCount NVARCHAR( 5),

   @cSortInf1     NVARCHAR( 20),
   @cSortInf2     NVARCHAR( 20),
   @cSortInf3     NVARCHAR( 20),
   @cSortInf4     NVARCHAR( 20),
   @cSortInf5     NVARCHAR( 20),

   @cExtendedSortSP     NVARCHAR( 20), 
   @cMultiLoadKey       NVARCHAR( 20), 
   @cExtendedUpdateSP   NVARCHAR( 20), 
   @cDecodeSP           NVARCHAR( 20), 

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
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cUserName  = UserName,
   @cPrinter   = Printer,

   @cLoadKey      = V_LoadKey,
   @cUCCNo        = V_UCC,
   @cSKU          = V_SKU, 
   @nQTY          = V_QTY, 
   
   @cLastLoadKey  = V_String1,
   @cLoadKeyCount = V_String2,
   
   @cSortInf1     = V_String11,
   @cSortInf2     = V_String12,
   @cSortInf3     = V_String13,
   @cSortInf4     = V_String14,
   @cSortInf5     = V_String15,

   @cExtendedSortSP   = V_String21,
   @cMultiLoadKey     = V_String22,
   @cExtendedUpdateSP = V_String23,
   @cDecodeSP         = V_String24,

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
IF @nFunc = 579
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 579
   IF @nStep = 1 GOTO Step_1   -- Scn = 4760. LoadKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 4761. UCC
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu
********************************************************************************/
Step_0:
BEGIN
   -- Get StorerConfig
   SET @cMultiLoadKey = rdt.RDTGetConfig( @nFunc, 'MultiLoadKey', @cStorerKey)

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedSortSP = rdt.RDTGetConfig( @nFunc, 'ExtendedSortSP', @cStorerKey)
   IF @cExtendedSortSP = '0'
      SET @cExtendedSortSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'     
      SET @cExtendedUpdateSP = ''  

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   SET @cLastLoadKey = ''
   SET @cLoadKeyCount = '0'

   -- Prep next screen var
   SET @cOutField01 = '' -- LoadKey
   SET @cOutField02 = '' -- Last LoadKey
   SET @cOutField03 = '' -- LoadKey count

   -- Set the entry point
   SET @nScn = 4760
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 4760
   LOADKEY        (field01, input)
   LAST LOADKEY   (field02)
   LOADKEY COUNT  (field03)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLoadKey = @cInField01

      -- Check blank
      IF @cLoadKey = ''
      BEGIN
         IF @cMultiLoadKey = '1' AND CAST( @cLoadKeyCount AS INT) > 0
         BEGIN
            -- ExtendedSortSP
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedSortSP) +
               ' @nMobile, @nFunc, @nScn, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, @cType, @cLoadKey OUTPUT, @cUCCNo, @cSKU, @nQTY, ' +
               ' @cScan OUTPUT, @cTotal OUTPUT, @cPOS OUTPUT, @cSortInf1 OUTPUT, @cSortInf2 OUTPUT, @cSortInf3 OUTPUT, @cSortInf4 OUTPUT, @cSortInf5 OUTPUT, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile     INT, ' + 
               ' @nFunc       INT, ' + 
               ' @nScn        INT, ' + 
               ' @nStep       INT, ' + 
               ' @nInputKey   INT, ' + 
               ' @cLangCode   NVARCHAR( 3) , ' +
               ' @cStorerkey  NVARCHAR( 15), ' +
               ' @cFacility   NVARCHAR( 5) , ' +
               ' @cType       NVARCHAR( 10), ' + 
               ' @cLoadKey    NVARCHAR( 10) OUTPUT, ' +
               ' @cUCCNo      NVARCHAR( 20), ' +
               ' @cSKU        NVARCHAR( 20), ' +
               ' @nQTY        INT, ' +
               ' @cScan       NVARCHAR( 5)  OUTPUT, ' + 
               ' @cTotal      NVARCHAR( 5)  OUTPUT, ' + 
               ' @cPOS        NVARCHAR( 20) OUTPUT, ' + 
               ' @cSortInf1   NVARCHAR( 20) OUTPUT, ' + 
               ' @cSortInf2   NVARCHAR( 20) OUTPUT, ' + 
               ' @cSortInf3   NVARCHAR( 20) OUTPUT, ' + 
               ' @cSortInf4   NVARCHAR( 20) OUTPUT, ' + 
               ' @cSortInf5   NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo      INT           OUTPUT, ' + 
               ' @cErrMsg     NVARCHAR(20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nScn, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, '', @cLoadKey OUTPUT, @cUCCNo, @cSKU, @nQTY, 
               @cScan OUTPUT, @cTotal OUTPUT, @cPOS OUTPUT, @cSortInf1 OUTPUT, @cSortInf2 OUTPUT, @cSortInf3 OUTPUT, @cSortInf4 OUTPUT, @cSortInf5 OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            -- Prep next screen var
            SET @cOutField01 = @cLoadKey
            SET @cOutField02 = @cScan + '/' + @cTotal
            SET @cOutField03 = '' -- UCC
            SET @cOutField04 = '' -- POS
            SET @cOutField05 = '' -- SortInf1
            SET @cOutField06 = '' -- SortInf2
            SET @cOutField07 = '' -- SortInf3
            SET @cOutField08 = '' -- SortInf4
            SET @cOutField09 = '' -- SortInf5

            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
            
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 105651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need LoadKey
            GOTO Quit
         END
      END

      -- Check valid
      IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
      BEGIN
         SET @nErrNo = 105652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidLoadKey
         SET @cOutField01 = '' -- LoadKey
         GOTO Quit
      END

      -- Get load plan info
      DECLARE @cChkFacility NVARCHAR(5)
      DECLARE @cChkStatus   NVARCHAR(10)
      SET @cChkFacility = ''
      SET @cChkStatus = ''
      SELECT
         @cChkFacility = Facility,
         @cChkStatus = Status
      FROM dbo.LoadPlan WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey

      -- Check facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 105653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff Facility
         SET @cOutField01 = '' -- LoadKey
         GOTO Quit
      END

      -- Check load plan status
      IF @cChkStatus = '9' -- 9=Closed
      BEGIN
         SET @nErrNo = 105654
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LoadKey Closed
         SET @cOutField01 = '' -- LoadKey
         GOTO Quit
      END

      -- Check storer
      IF EXISTS ( SELECT 1
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND O.StorerKey <> @cStorerKey)
      BEGIN
         SET @nErrNo = 105655
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff Storer
         SET @cOutField01 = '' -- LoadKey
         GOTO Quit
      END

      IF @cMultiLoadKey = '1'
      BEGIN
         -- Check double scan
         IF EXISTS( SELECT 1 FROM rdt.rdtSortCaseLog WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND Mobile = @nMobile)
         BEGIN
            SET @nErrNo = 105661
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LoadKeyScanned
            GOTO Quit
         END
         
         -- Insert log
         INSERT INTO rdt.rdtSortCaseLog (Mobile, LoadKey) VALUES (@nMobile, @cLoadKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105662
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Fail INS Log
            GOTO Quit
         END
         
         SET @cLastLoadKey = @cLoadKey
         SET @cLoadKeyCount = CAST( CAST( @cLoadKeyCount AS INT) + 1 AS NVARCHAR(5))
         
         SET @cOutField01 = '' -- LoadKey         
         SET @cOutField02 = @cLastLoadKey         
         SET @cOutField03 = @cLoadKeyCount
         GOTO Quit
      END

      -- ExtendedSortSP
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedSortSP AND type = 'P')
      BEGIN
         SET @nErrNo = 105660
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SetupExtSortSP
         SET @cOutField03 = '' -- UCCNo
         GOTO Quit
      END

      -- ExtendedSortSP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedSortSP) +
         ' @nMobile, @nFunc, @nScn, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, @cType, @cLoadKey OUTPUT, @cUCCNo, @cSKU, @nQTY, ' +
         ' @cScan OUTPUT, @cTotal OUTPUT, @cPOS OUTPUT, @cSortInf1 OUTPUT, @cSortInf2 OUTPUT, @cSortInf3 OUTPUT, @cSortInf4 OUTPUT, @cSortInf5 OUTPUT, ' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
      SET @cSQLParam =
         ' @nMobile     INT, ' + 
         ' @nFunc       INT, ' + 
         ' @nScn        INT, ' + 
         ' @nStep       INT, ' + 
         ' @nInputKey   INT, ' + 
         ' @cLangCode   NVARCHAR( 3) , ' +
         ' @cStorerkey  NVARCHAR( 15), ' +
         ' @cFacility   NVARCHAR( 5) , ' +
         ' @cType       NVARCHAR( 10), ' + 
         ' @cLoadKey    NVARCHAR( 10) OUTPUT, ' +
         ' @cUCCNo      NVARCHAR( 20), ' +
         ' @cSKU        NVARCHAR( 20), ' +
         ' @nQTY        INT, ' +
         ' @cScan       NVARCHAR( 5)  OUTPUT, ' + 
         ' @cTotal      NVARCHAR( 5)  OUTPUT, ' + 
         ' @cPOS        NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf1   NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf2   NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf3   NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf4   NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf5   NVARCHAR( 20) OUTPUT, ' + 
         ' @nErrNo      INT           OUTPUT, ' + 
         ' @cErrMsg     NVARCHAR(20)  OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @nScn, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, '', @cLoadKey OUTPUT, @cUCCNo, @cSKU, @nQTY,
         @cScan OUTPUT, @cTotal OUTPUT, @cPOS OUTPUT, @cSortInf1 OUTPUT, @cSortInf2 OUTPUT, @cSortInf3 OUTPUT, @cSortInf4 OUTPUT, @cSortInf5 OUTPUT,
         @nErrNo OUTPUT, @cErrMsg OUTPUT

      -- Prep next screen var
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = @cScan + '/' + @cTotal
      SET @cOutField03 = '' -- UCC
      SET @cOutField04 = '' -- POS
      SET @cOutField05 = '' -- SortInf1
      SET @cOutField06 = '' -- SortInf2
      SET @cOutField07 = '' -- SortInf3
      SET @cOutField08 = '' -- SortInf4
      SET @cOutField09 = '' -- SortInf5

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cMultiLoadkey = '1'
         DELETE rdt.rdtSortCaseLog WHERE Mobile = @nMobile
      
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
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
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 4760
   LOADKEY     (field01)
   SCAN/TOTAL  (field02, field03)
   UCC/CASE    (field03, input)
   POS         (field04)
   SORTINF1    (field05)
   SORTINF2    (field06)
   SORTINF3    (field07)
   SORTINF4    (field08)
   SORTINF5    (field08)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cBarcode NVARCHAR(60)
      DECLARE @cUPC NVARCHAR(30)

      -- Screen mapping
      SET @cBarcode = @cInField03
      SET @cUCCNo = LEFT( @cInField03, 20)
      SET @cUPC = LEFT( @cInField03, 30)

      -- Check blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 105656
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need UCC/CASE
         GOTO Quit
      END

      -- Get UCC info
      DECLARE @cStatus NVARCHAR( 1)
      SELECT 
         @cStatus = Status
      FROM UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCCNo
      SET @nRowCount = @@ROWCOUNT

      -- Check UCC valid
      IF @nRowCount = 0
      BEGIN
         SET @cSKU = ''
         SET @nQTY = 0
         
         -- Decode
         IF @cDecodeSP <> ''
         BEGIN
            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
                  @cUPC = @cUPC OUTPUT, 
                  @nQTY = @nQTY OUTPUT
            END
         
            -- Customize decode
            ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
                  ' @cBarcode, @cUCCNo OUTPUT, @cSKU OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile      INT,             ' +
                  ' @nFunc        INT,             ' +
                  ' @cLangCode    NVARCHAR( 3),    ' +
                  ' @nStep        INT,             ' +
                  ' @nInputKey    INT,             ' +
                  ' @cStorerKey   NVARCHAR( 15),   ' +
                  ' @cFacility    NVARCHAR( 5),    ' +
                  ' @cBarcode     NVARCHAR( 2000), ' +
                  ' @cUCCNo       NVARCHAR( 20)  OUTPUT,  ' +
                  ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY         INT            OUTPUT, ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
                  @cBarcode, @cUCCNo OUTPUT, @cSKU OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
               IF @nErrNo <> 0
                  GOTO Quit

               IF @cSKU <> ''
                  SET @cUPC = @cSKU
            END
         END

         DECLARE @nSKUCnt INT
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
            SET @nErrNo = 105657
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad UCC/CASE
            GOTO Quit
         END

         -- Check multi SKU barcode
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 105663
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Quit
         END
                  
         -- Get SKU
         EXEC rdt.rdt_GetSKU
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC      OUTPUT
            ,@bSuccess    = @bSuccess  OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT
         
         SET @cSKU = @cUPC

         -- Get case count
         IF @nQTY = 0
         BEGIN
            -- Get SKU info
            SELECT @nQTY = CAST( CaseCnt AS INT)
            FROM SKU WITH (NOLOCK) 
               JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU
            
            -- Check case count
            IF @nQTY = 0
            BEGIN
               SET @nErrNo = 105664
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No case count
               GOTO Quit
            END
         END
      END
      ELSE
      BEGIN
         -- Check UCC valid
         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 105658
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKU UCC
            SET @cOutField03 = '' -- UCCNo
            GOTO Quit
         END

         -- Check UCC status
         IF @cStatus >= '5'
         BEGIN
            SET @nErrNo = 105659
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC sorted
            SET @cOutField03 = '' -- UCCNo
            GOTO Quit
         END

         SET @cSKU = ''
         SET @nQTY = 0
      END

      -- ExtendedSortSP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedSortSP) +
         ' @nMobile, @nFunc, @nScn, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, @cType, @cLoadKey OUTPUT, @cUCCNo, @cSKU, @nQTY, ' +
         ' @cScan OUTPUT, @cTotal OUTPUT, @cPOS OUTPUT, @cSortInf1 OUTPUT, @cSortInf2 OUTPUT, @cSortInf3 OUTPUT, @cSortInf4 OUTPUT, @cSortInf5 OUTPUT, ' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
      SET @cSQLParam =
         ' @nMobile     INT, ' + 
         ' @nFunc       INT, ' + 
         ' @nScn        INT, ' + 
         ' @nStep       INT, ' + 
         ' @nInputKey   INT, ' + 
         ' @cLangCode   NVARCHAR( 3) , ' +
         ' @cStorerkey  NVARCHAR( 15), ' +
         ' @cFacility   NVARCHAR( 5) , ' +
         ' @cType       NVARCHAR( 10), ' + 
         ' @cLoadKey    NVARCHAR( 10) OUTPUT, ' +
         ' @cUCCNo      NVARCHAR( 20), ' +
         ' @cSKU        NVARCHAR( 20), ' +
         ' @nQTY        INT, ' +
         ' @cScan       NVARCHAR( 5)  OUTPUT, ' + 
         ' @cTotal      NVARCHAR( 5)  OUTPUT, ' + 
         ' @cPOS        NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf1   NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf2   NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf3   NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf4   NVARCHAR( 20) OUTPUT, ' + 
         ' @cSortInf5   NVARCHAR( 20) OUTPUT, ' + 
         ' @nErrNo      INT           OUTPUT, ' + 
         ' @cErrMsg     NVARCHAR(20)  OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @nScn, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, 'CONFIRM', @cLoadKey OUTPUT, @cUCCNo, @cSKU, @nQTY, 
         @cScan OUTPUT, @cTotal OUTPUT, @cPOS OUTPUT, @cSortInf1 OUTPUT, @cSortInf2 OUTPUT, @cSortInf3 OUTPUT, @cSortInf4 OUTPUT, @cSortInf5 OUTPUT,
         @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit 

      -- Prep current screen var
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = @cScan + '/' + @cTotal
      SET @cOutField03 = '' -- UCC
      SET @cOutField04 = @cPOS
      SET @cOutField05 = @cSortInf1
      SET @cOutField06 = @cSortInf2
      SET @cOutField07 = @cSortInf3
      SET @cOutField08 = @cSortInf4
      SET @cOutField09 = @cSortInf5
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- ExtendedUpdateSP
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @nScn, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, @cType, @cLoadKey, @cUCCNo, ' +
               ' @cScan, @cTotal, @cPOS, @cSortInf1, @cSortInf2, @cSortInf3, @cSortInf4, @cSortInf5, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile     INT, ' + 
               ' @nFunc       INT, ' + 
               ' @nScn        INT, ' + 
               ' @nStep       INT, ' + 
               ' @nInputKey   INT, ' + 
               ' @cLangCode   NVARCHAR( 3) , ' +
               ' @cStorerkey  NVARCHAR( 15), ' +
               ' @cFacility   NVARCHAR( 5) , ' +
               ' @cType       NVARCHAR( 10), ' + 
               ' @cLoadKey    NVARCHAR( 10), ' +
               ' @cUCCNo      NVARCHAR( 20), ' +
               ' @cScan       NVARCHAR( 5),  ' + 
               ' @cTotal      NVARCHAR( 5),  ' + 
               ' @cPOS        NVARCHAR( 20), ' + 
               ' @cSortInf1   NVARCHAR( 20), ' + 
               ' @cSortInf2   NVARCHAR( 20), ' + 
               ' @cSortInf3   NVARCHAR( 20), ' + 
               ' @cSortInf4   NVARCHAR( 20), ' + 
               ' @cSortInf5   NVARCHAR( 20), ' + 
               ' @nErrNo      INT           OUTPUT, ' + 
               ' @cErrMsg     NVARCHAR(20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nScn, @nStep, @nInputKey, @cLangCode, @cStorerKey, @cFacility, '', @cLoadKey, @cUCCNo, 
               @cScan, @cTotal, @cPOS, @cSortInf1, @cSortInf2, @cSortInf3, @cSortInf4, @cSortInf5,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
            
      -- Prepare next screen var
      SET @cOutField01 = '' --LoadKey
      SET @cOutField02 = @cLastLoadKey         
      SET @cOutField03 = @cLoadKeyCount

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
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
      Printer    = @cPrinter,

      V_LoadKey  = @cLoadKey,
      V_UCC      = @cUCCNo, 
      V_SKU      = @cSKU, 
      V_QTY      = @nQTY, 

      V_String1  = @cLastLoadKey,
      V_String2  = @cLoadKeyCount,

      V_String21 = @cExtendedSortSP,
      V_String22 = @cMultiLoadKey,
      V_String23 = @cExtendedUpdateSP,
      V_String24 = @cDecodeSP,

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