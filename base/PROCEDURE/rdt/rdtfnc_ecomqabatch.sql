SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_EcomQABatch                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-03-28 1.0  Ung      WMS-19222 created                                 */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_EcomQABatch] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @nRowCount     INT,
   @nSKUCnt       INT,
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX),
   @cDocType      NVARCHAR( 30), 
   @cDocNo        NVARCHAR( 20), 
   @cBarcode      NVARCHAR( 60),
   @cPrePackIndicator NVARCHAR( 30),
   @bSuccess      INT, 
   @n_err         INT, 
   @c_errmsg      NVARCHAR( 20),
   @tExtInfo      VariableTable

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

   @cSKU        NVARCHAR( 30),
   @cSKUDescr   NVARCHAR( 60),
   @nQTY        INT, 

   @cBatchNo            NVARCHAR( 10),
   @cStation            NVARCHAR( 10),


   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cMultiSKUBarcode    NVARCHAR( 1), 
   @cDecodeSP           NVARCHAR( 20),

   @nPackQtyIndicator   INT,
   @nTotalSKU           INT, 
   @nTotalQTY           INT, 

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

   @cSKU        = V_SKU,
   @cSKUDescr   = V_SKUDescr,
   @nQTY        = V_QTY, 

   @cBatchNo            = V_String1,
   @cStation            = V_String2,

   @cExtendedInfoSP     = V_String20,
   @cExtendedInfo       = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedValidateSP = V_String23,
   @cMultiSKUBarcode    = V_String24,
   @cDecodeSP           = V_String25,

   @nPackQtyIndicator   = V_Integer1,
   @nTotalSKU           = V_Integer2, 
   @nTotalQTY           = V_Integer3, 

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
   @nStep_BatchNo       INT,  @nScn_BatchNo        INT,
   @nStep_SKU           INT,  @nScn_SKU            INT,
   @nStep_Confirm       INT,  @nScn_Confirm        INT, 
   @nStep_MultiSKU      INT,  @nScn_MultiSKU       INT
   
SELECT
   @nStep_BatchNo       = 1,  @nScn_BatchNo        = 6040,
   @nStep_SKU           = 2,  @nScn_SKU            = 6041,
   @nStep_Confirm       = 3,  @nScn_Confirm        = 6042, 
   @nStep_MultiSKU      = 4,  @nScn_MultiSKU       = 3570
    
IF @nFunc = 650 -- ECOM QA Batch
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start       -- Func = 650
   IF @nStep = 1 GOTO Step_BatchNo     -- 6000 BatchNo, Station
   IF @nStep = 2 GOTO Step_SKU         -- 6004 SKU
   IF @nStep = 3 GOTO Step_Confirm     -- 6005 Confirm QA?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 650. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Storer configure
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   -- Prep next screen var
   SET @cOutField01 = '' -- BatchNo
   SET @cOutField02 = '' -- Station

   EXEC rdt.rdtSetFocusField @nMobile, 1 -- BatchNo

   -- Set the entry point
   SET @nScn = @nScn_BatchNo
   SET @nStep = @nStep_BatchNo

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 6040. BatchNo, Station
   BATCHNO     (field01, input)
   Station  (field02, input)
********************************************************************************/
Step_BatchNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cBatchNo = @cInField01
      SET @cStation = @cInField02

      -- Check batch blank
      IF @cBatchNo = ''
      BEGIN
         SET @nErrNo = 184801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchNo
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- BatchNo
         GOTO Quit
      END

      -- Check BatchNo
      IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.PackTask WITH (NOLOCK) WHERE TaskBatchNo = @cBatchNo)
      BEGIN
         SET @nErrNo = 184802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidBatchNo
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- BatchNo
         SET @cOutField01 = ''
         GOTO Quit
      END
      SET @cOutField01 = @cBatchNo

      -- Check station blank
      IF @cStation = ''
      BEGIN
         SET @nErrNo = 184803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Station
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Station
         GOTO Quit
      END
      SET @cOutField02 = @cStation

      -- Populate to log
      IF NOT EXISTS( SELECT TOP 1 1 FROM rdt.rdtECOMQABatchLog WITH (NOLOCK) WHERE BatchNo = @cBatchNo)
      BEGIN
         INSERT INTO rdt.rdtECOMQABatchLog (Mobile, BatchNo, Station, OrderKey, StorerKey, SKU, QTYExpected)
         SELECT @nMobile, @cBatchNo, @cStation, PD.OrderKey, PD.StorerKey, PD.SKU, SUM( PD.QTY)
         FROM dbo.PackTask PT WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PT.OrderKey = PD.OrderKey)
         WHERE PT.TaskBatchNo = @cBatchNo
            AND PD.QTY > 0
            AND PD.Status <> '4'
         GROUP BY PD.OrderKey, PD.StorerKey, PD.SKU
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 184804
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch no task
            GOTO Quit
         END
      END
      
      SET @cOutField01 = @cBatchNo
      SET @cOutField02 = '' --@cSKU
      SET @cOutField04 = '' --@cSKU
      SET @cOutField05 = '' --rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField06 = '' --rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField07 = '' --CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
      SET @cOutField08 = '' --CAST( @nTotalSKU AS NVARCHAR(5))
      SET @cOutField09 = '' --CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField15 = '' --ExtInfo

      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. scn = 6041. SKU screen
   BATCHNO  (field01)
   SKU/UPC  (field02, input)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cUPC NVARCHAR( 30)
      
      -- Screen mapping
      SET @cBarcode = @cInField02
      SET @cUPC = LEFT( @cInField02, 30)

      -- Check blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 184805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUPC    = @cSKU    OUTPUT,
               @nQTY    = @nQTY    OUTPUT
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cBatchNo    OUTPUT, @cStation    OUTPUT, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT  '
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cBatchNo     NVARCHAR( 10)  OUTPUT, ' +
               ' @cStation     NVARCHAR( 10)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,
               @cBatchNo    OUTPUT, @cStation   OUTPUT,
               @cSKU        OUTPUT, @nQTY       OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg    OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Get SKU count
      EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 184806
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            -- Limit search scope 
            SET @cDocType = 'PickSlipNo'
            SET @cDocNo = @cBatchNo
               
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
               @cSKU         OUTPUT,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT,
               @cDocType, 
               @cDocNo
            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nScn = @nScn_MultiSKU
               SET @nStep = @nStep_MultiSKU
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 184807
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
            GOTO Quit
         END
      END

      -- Get SKU
      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC          OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT
      
      SET @cSKU = @cUPC

      -- Get SKU info
      SELECT
         @cSKUDescr = SKU.DescR,
         @cPrePackIndicator = PrePackIndicator,
         @nPackQtyIndicator = ISNULL( PackQtyIndicator, 0)
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack (nolock) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      SET @nQTY = 1

      -- Calc prepack QTY
      IF @cPrePackIndicator = '2'
         IF @nPackQtyIndicator > 1
            SET @nQTY = @nQTY * @nPackQtyIndicator

      -- Get PackTask info
      DECLARE @nQTYExpected INT
      DECLARE @nQTYScanned INT
      SELECT 
         @nQTYExpected = SUM( QTYExpected), 
         @nQTYScanned = SUM( QTY)
      FROM rdt.rdtECOMQABatchLog WITH (NOLOCK) 
      WHERE BatchNo = @cBatchNo 
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Check SKU in batch
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 184808
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotInBatch
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Check over scan
      IF (@nQTYScanned + @nQTY) > @nQTYExpected
      BEGIN
         SET @nErrNo = 184809
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over scan
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBatchNo, @cStation, @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cBatchNo        NVARCHAR( 10), ' +
               '@cStation        NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBatchNo, @cStation, @cSKU, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Confirm
      EXEC rdt.rdt_ECOMQABatch_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'UPDATE', 
         @cBatchNo, 
         @cStation, 
         @cSKU, 
         @nQTY, 
         @nTotalSKU OUTPUT, 
         @nTotalQTY OUTPUT, 
         @nErrNo    OUTPUT, 
         @cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtECOMQABatchLog WITH (NOLOCK) WHERE BatchNo = @cBatchNo AND QTYExpected > QTY)
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cBatchNo
         SET @cOutField02 = '' -- @cSKU
         SET @cOutField04 = @cSKU
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
         SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
         SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
         SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
         SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
         SET @cOutField15 = '' -- ExtInfo
      END
      ELSE
      BEGIN
         -- Prompt batch completes
         SET @nErrNo = 184810
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BATCHNO COMPLETED
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cErrMsg

         -- Close
         EXEC rdt.rdt_ECOMQABatch_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'CLOSE', 
            @cBatchNo, 
            @cStation, 
            @cSKU, 
            @nQTY, 
            @nTotalSKU OUTPUT, 
            @nTotalQTY OUTPUT, 
            @nErrNo    OUTPUT, 
            @cErrMsg   OUTPUT
         
         SET @cOutField01 = '' --@cBatchNo
         SET @cOutField02 = @cStation
         
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- BatchNo
         
         SET @nStep = @nStep_BatchNo
         SET @nScn = @nScn_BatchNo
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtECOMQABatchLog WITH (NOLOCK) WHERE BatchNo = @cBatchNo)
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option
         SET @cOutField02 = CAST( @nTotalSKU AS NVARCHAR(5))
         SET @cOutField03 = CAST( @nTotalQTY AS NVARCHAR(5))

         -- Go to next screen
         SET @nScn = @nScn_Confirm
         SET @nStep = @nStep_Confirm
      END
      ELSE
      BEGIN
         SET @cOutField01 = '' --@cBatchNo
         SET @cOutField02 = @cStation
         
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- BatchNo
         
         SET @nStep = @nStep_BatchNo
         SET @nScn = @nScn_BatchNo
      END 
   END

Step_SKU_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN      
         INSERT INTO @tExtInfo (Variable, Value) VALUES
            ('@cStation',     @cStation),
            ('@cStation',     @cStation),
            ('@cSKU',         @cSKU),
            ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10)))

         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nAfterStep      INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR(  5), ' +
            '@tExtInfo        VariableTable READONLY, ' +
            '@cExtendedInfo   NVARCHAR( 20)  OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT

         IF @nStep = @nStep_SKU
            SET @cOutField15 = @cExtendedInfo
      END
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 6043. Confirm move?
   CONFIRM QA?
   1 = YES (PARTIAL)
   9 = NO  (RESET)
   OPTION   (field01, input)
********************************************************************************/
Step_Confirm:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR(1)

      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 184811
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need option
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 184812
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Confirm
      IF @cOption = '1' -- YES (PARTIAL)
      BEGIN
         EXEC rdt.rdt_ECOMQABatch_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'CLOSE', 
            @cBatchNo, 
            @cStation, 
            @cSKU, 
            @nQTY, 
            @nTotalSKU OUTPUT, 
            @nTotalQTY OUTPUT, 
            @nErrNo    OUTPUT, 
            @cErrMsg   OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
      
      IF @cOption = '9' -- NO (RESET)
      BEGIN
         EXEC rdt.rdt_ECOMQABatch_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'RESET', 
            @cBatchNo, 
            @cStation, 
            @cSKU, 
            @nQTY, 
            @nTotalSKU OUTPUT, 
            @nTotalQTY OUTPUT, 
            @nErrNo    OUTPUT, 
            @cErrMsg   OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
      
      -- Prepare next screen var
      SET @cOutField01 = '' -- @cBatchNo
      SET @cOutField02 = @cStation

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- BatchNo

      SET @nScn = @nScn_BatchNo
      SET @nStep = @nStep_BatchNo
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cBatchNo
      SET @cOutField02 = '' -- @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
      SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField15 = '' --@cExtendedInfo

      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

Step_Confirm_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN      
         INSERT INTO @tExtInfo (Variable, Value) VALUES
            ('@cStation',     @cStation),
            ('@cStation',     @cStation),
            ('@cSKU',         @cSKU),
            ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10)))

         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nAfterStep      INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR(  5), ' +
            '@tExtInfo        VariableTable READONLY, ' +
            '@cExtendedInfo   NVARCHAR( 20)  OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_Confirm, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT

         IF @nStep = @nStep_SKU
            SET @cOutField15 = @cExtendedInfo
      END
   END
END
GOTO Quit


/********************************************************************************
Step 7. Screen = 3570. Multi SKU
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
      -- Limit search scope 
      SET @cDocType = 'PickSlipNo'
      SET @cDocNo = @cBatchNo

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
         'CHECK',
         @cMultiSKUBarcode,
         @cStorerKey,
         @cSKU     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT,  
         @cDocType,  
         @cDocNo      

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Get SKU info
      SELECT
         @cSKUDescr = SKU.DescR,
         @cPrePackIndicator = PrePackIndicator,
         @nPackQtyIndicator = ISNULL( PackQtyIndicator, 0)
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack (nolock) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Prep next screen var
      SET @cOutField01 = @cBatchNo
      SET @cOutField02 = @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
      SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField15 = '' --@cExtendedInfo
      
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cBatchNo
      SET @cOutField02 = '' -- @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)  -- SKU desc 2
      SET @cOutField07 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END
      SET @cOutField08 = CAST( @nTotalSKU AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotalQTY AS NVARCHAR(5))
      SET @cOutField15 = '' --@cExtendedInfo
      
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

Step_MultiSKU_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN      
         INSERT INTO @tExtInfo (Variable, Value) VALUES
            ('@cStation',     @cStation),
            ('@cStation',     @cStation),
            ('@cSKU',         @cSKU),
            ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10)))

         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nAfterStep      INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR(  5), ' +
            '@tExtInfo        VariableTable READONLY, ' +
            '@cExtendedInfo   NVARCHAR( 20)  OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_MultiSKU, @nStep, @nInputKey, @cStorerKey, @cFacility, @tExtInfo, @cExtendedInfo OUTPUT

         IF @nStep = @nStep_SKU
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
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,

      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      V_QTY      = @nQTY, 

      V_String1  = @cBatchNo,
      V_String2  = @cStation,

      V_String20 = @cExtendedInfoSP,
      V_String21 = @cExtendedInfo,
      V_String22 = @cExtendedUpdateSP,
      V_String23 = @cExtendedValidateSP,
      V_String24 = @cMultiSKUBarcode,
      V_String25 = @cDecodeSP,

      V_Integer1 = @nPackQtyIndicator,
      V_Integer2 = @nTotalSKU, 
      V_Integer3 = @nTotalQTY, 

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