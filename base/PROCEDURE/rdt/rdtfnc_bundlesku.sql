SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_BundleSKU                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-02-08 1.0  Ung      WMS-18861 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_BundleSKU](
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
   @bSuccess            INT, 
   @nTranCount          INT,  
   @nRowCount           INT, 
   @cOption             NVARCHAR(1), 
   @cChkStorerKey       NVARCHAR(15), 
   @cChkFacility        NVARCHAR(5), 
   @cChkStatus          NVARCHAR(10), 
   @cExternStatus       NVARCHAR(10), 
   @cSKU                NVARCHAR(60), 
   @nRowRef             INT, 
   @cSQL                NVARCHAR(MAX),
   @cSQLParam           NVARCHAR(MAX), 
   @tVCLabel            VariableTable

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),
   @cPaperPrinter       NVARCHAR( 10),
   @cLabelPrinter       NVARCHAR( 10),
   
   @nParentQTY          INT, 

   @cWorkOrderKey       NVARCHAR(10),
   @cParentSKU          NVARCHAR(20),
   @cChildSKU           NVARCHAR(20),
   
   @cDecodeSP           NVARCHAR(20), 
   @cVCLabel            NVARCHAR(10),

   @cParentSNO          NVARCHAR(50),
   @cChildSNO           NVARCHAR(50),
   
   @nParentScan         INT,
   @nParentTotal        INT,
   @nChildScan          INT,
   @nChildTotal         INT,
   @nGroupKey           INT, 

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
   @cPaperPrinter    = Printer_Paper,
   @cLabelPrinter    = Printer,

   @nParentQTY       = V_QTY, 

   @cWorkOrderKey    = V_String1,
   @cParentSKU       = V_String2,
   @cChildSKU        = V_String3,
   
   @cDecodeSP        = V_String21, 
   @cVCLabel         = V_String22, 

   @cParentSNO       = V_String41,
   @cChildSNO        = V_String42,

   @nParentScan      = V_Integer1,
   @nParentTotal     = V_Integer2,
   @nChildScan       = V_Integer3,
   @nChildTotal      = V_Integer4,
   @nGroupKey        = V_Integer5,

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
   @nStep_Start         INT,  
   @nStep_WorkOrder     INT,  @nScn_WorkOrder   INT,
   @nStep_Parent        INT,  @nScn_Parent      INT,
   @nStep_Child         INT,  @nScn_Child       INT,
   @nStep_Child_MAC     INT,  @nScn_Child_MAC   INT
   
SELECT
   @nStep_WorkOrder     = 1,  @nScn_WorkOrder   = 6020,
   @nStep_Parent        = 2,  @nScn_Parent      = 6021,
   @nStep_Child         = 3,  @nScn_Child       = 6022,
   @nStep_Child_MAC     = 4,  @nScn_Child_MAC   = 6023

-- Redirect to respective screen
IF @nFunc = 649
BEGIN
   IF @nStep = 0 GOTO Step_Start          -- Menu. Func = 632
   IF @nStep = 1 GOTO Step_WorkOrderKey   -- Scn = 6020 Work order
   IF @nStep = 2 GOTO Step_Parent         -- Scn = 6021 Parent
   IF @nStep = 3 GOTO Step_Child          -- Scn = 6022 Child
   IF @nStep = 4 GOTO Step_Child_MAC      -- Scn = 6023 Child MAC
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 649)
********************************************************************************/
Step_Start:
BEGIN
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerkey)  
   IF @cDecodeSP = '0'  
      SET @cDecodeSP = ''  
   SET @cVCLabel = rdt.RDTGetConfig( @nFunc, 'VCLabel', @cStorerKey)
   IF @cVCLabel = '0'
      SET @cVCLabel = ''

   -- Prep next screen var
   SET @cOutField01 = '' -- WorkOrderKey

   -- Set the entry point
   SET @nScn = @nScn_WorkOrder
   SET @nStep = @nStep_WorkOrder
END
GOTO Quit


/********************************************************************************
Step WorkOrderKey. screen = 6020
   WorkOrderKey   (field01, input)
   OPTION         (Field02, input)    
********************************************************************************/
Step_WorkOrderKey:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWorkOrderKey = @cInField01
      
      -- Check blank
      IF @cWorkOrderKey = ''
      BEGIN
         SET @nErrNo = 181851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need WOKey
         GOTO Quit
      END

      -- Get Kit info
      SELECT 
         @cChkStorerKey = StorerKey, 
         @cChkFacility = Facility, 
         @cChkStatus = Status, 
         @cExternStatus = ExternStatus
      FROM WorkOrder WITH (NOLOCK)
      WHERE WorkOrderKey = @cWorkOrderKey
      
      -- Check Kit valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 181852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid WO
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- KIT
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check diff storer
      IF @cChkStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 181853
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check diff facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 181854
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check status
      IF @cChkStatus = '9' OR @cExternStatus = '9'
      BEGIN
         SET @nErrNo = 181855
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WO closed
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Get parent SKU
      SET @cParentSKU = ''
      SELECT TOP 1 
         @cParentSKU = SKU, 
         @nParentTotal = QTY
      FROM dbo.WorkOrderDetail WITH (NOLOCK)
      WHERE WorkOrderKey = @cWorkOrderKey
         AND ExternLineNo = '001'

      IF @cParentSKU = ''
      BEGIN
         SET @nErrNo = 181856
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No parent SKU
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check child to parent ratio is full
      IF EXISTS( SELECT 1
         FROM dbo.WorkOrderDetail WITH (NOLOCK)
         WHERE WorkOrderKey = @cWorkOrderKey
            AND ExternLineNo <> '001'
         GROUP BY SKU
         HAVING SUM( QTY) % @nParentTotal <> 0)
      BEGIN
         SET @nErrNo = 181857
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ratio
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Get stat
      SELECT @nParentScan = COUNT( DISTINCT WkOrdUdef4)
      FROM WorkOrderDetail WITH (NOLOCK)
      WHERE WorkOrderKey = @cWorkOrderKey
         AND WkOrdUdef4 <> ''

      -- Get stat
      SELECT @nChildTotal = ISNULL( SUM( QTY), 0)
      FROM WorkOrderDetail WITH (NOLOCK)
      WHERE WorkOrderKey = @cWorkOrderKey
         AND ExternLineNo <> '001'

      SET @nChildTotal = @nChildTotal / @nParentTotal

      -- Prepare next screen screen
      SET @cOutField01 = @cWorkOrderKey
      SET @cOutField02 = @cParentSKU
      SET @cOutField03 = '' -- ParentSerialNo
      SET @cOutField04 = CAST( @nParentScan AS NVARCHAR(5))+ '/' + CAST( @nParentTotal AS NVARCHAR(5))
   
      -- Go to track no screen
      SET @nScn = @nScn_Parent
      SET @nStep = @nStep_Parent
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step_Parent. screen = 6021
   WorkOrderKey   (field01)
   Parent SKU     (field02)
   Parent SNO     (field03, input)
   QTY            (field04)
********************************************************************************/
Step_Parent:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cParentSNO = @cInField03

      -- Check fully scanned
      IF @nParentScan = @nParentTotal
      BEGIN
         SET @cOutField03 = ''
         GOTO Quit
      END
      
      -- Check blank
      IF @cParentSNO = ''
      BEGIN
         SET @nErrNo = 181858
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ParentSNO
         GOTO Quit
      END

      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ParentSNO', @cParentSNO) = 0
      BEGIN
         SET @nErrNo = 181859
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Quit
      END

      -- Check Parent SNO valid
      IF @cDecodeSP <> ''  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
            ' @cWorkOrderNo, @cSKU, @cSerialNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
         SET @cSQLParam =    
            ' @nMobile        INT,           ' +    
            ' @nFunc          INT,           ' +    
            ' @cLangCode      NVARCHAR( 3),  ' +    
            ' @nStep          INT,           ' +    
            ' @nInputKey      INT,           ' +    
            ' @cFacility      NVARCHAR( 5),  ' +    
            ' @cStorerKey     NVARCHAR( 15), ' +    
            ' @cWorkOrderNo   NVARCHAR( 20), ' +      
            ' @cSKU           NVARCHAR( 20), ' +    
            ' @cSerialNo      NVARCHAR(20)   OUTPUT, ' +     
            ' @nErrNo         INT            OUTPUT, ' +    
            ' @cErrMsg        NVARCHAR( 20)  OUTPUT  '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cWorkOrderKey, @cSKU, @cParentSNO OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
         IF @nErrNo <> 0
         BEGIN
            SET @cOutField03 = ''
            GOTO Quit
         END
      END     

      -- Check parent SNO scanned
      IF EXISTS( SELECT 1
         FROM rdt.rdtBundleSKULog WITH (NOLOCK) 
         WHERE WorkOrderKey = @cWorkOrderKey
            AND SerialNo = @cParentSNO
            AND Type = 'P') 
      BEGIN
         SET @nErrNo = 181860
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO scanned
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Check parent SNO exist
      IF EXISTS( SELECT 1
         FROM MasterSerialNo WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND ParentSerialNo = @cParentSNO
            AND UnitType = 'K')
      BEGIN
         SET @nErrNo = 181861
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ParentSNOExist
         SET @cOutField03 = ''
         GOTO Quit
      END

      SET @nChildScan = 0
      SET @nGroupKey = 0

      -- Prepare next screen var
      SET @cOutField01 = @cWorkOrderKey
      SET @cOutField02 = @cParentSKU
      SET @cOutField03 = @cParentSNO
      SET @cOutField04 = '' -- @cChildSKU
      SET @cOutField05 = '' -- @cChildSNO
      SET @cOutField06 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))
      
      -- Go to track no screen
      SET @nScn = @nScn_Child
      SET @nStep = @nStep_Child
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- WorkOrderKey
      SET @cOutField02 = '' -- Option

      -- Go to work order screen
      SET @nScn = @nScn_WorkOrder
      SET @nStep = @nStep_WorkOrder
   END
END
GOTO Quit


/********************************************************************************
Step Child. screen = 6022
   WorkOrderKey   (Field01)
   Parent SKU     (field02)
   Parent SNO     (field03)
   Child SKU      (field04)
   Child SNO      (field05, input)
   QTY            (field06)
********************************************************************************/
Step_Child:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cChildSNO = @cInField05
      
      -- Finish scan
      IF @nChildScan = @nChildTotal
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cWorkOrderKey
         SET @cOutField02 = @cParentSKU
         SET @cOutField03 = '' -- @cParentSNO
         SET @cOutField04 = CAST( @nParentScan AS NVARCHAR(5))+ '/' + CAST( @nParentTotal AS NVARCHAR(5))

         -- Go to pallet serialno screen
         SET @nScn = @nScn_Parent
         SET @nStep = @nStep_Parent
      
         GOTO Quit
      END

      -- Check blank
      IF @cChildSNO = ''
      BEGIN
         SET @nErrNo = 181862
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Child SNO
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check child same as parent
      IF @cChildSNO = @cParentSNO
      BEGIN
         SET @nErrNo = 181863
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Child SNO
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check child SNO scanned
      IF EXISTS( SELECT 1
         FROM rdt.rdtBundleSKULog WITH (NOLOCK) 
         WHERE WorkOrderKey = @cWorkOrderKey
            AND SerialNo = @cChildSNO
            AND Type = 'C')
      BEGIN
         SET @nErrNo = 181864
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO scanned
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Check child SNO scanned
      IF EXISTS( SELECT TOP 1 1
         FROM dbo.WorkOrderDetail WITH (NOLOCK) 
         WHERE WorkOrderKey = @cWorkOrderKey
            AND WkOrdUdef1 = @cChildSNO)
      BEGIN
         SET @nErrNo = 181878
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO scanned
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Get child SKU
      SET @cChildSKU = ''
      SELECT @cChildSKU = SKU 
      FROM MasterSerialNo WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND @cChildSNO IN (SerialNo, ParentSerialNo)
      
      IF @@ROWCOUNT = 0
      BEGIN
         DECLARE @cBarcode NVARCHAR( 30)
         SET @cBarcode = LEFT( @cChildSNO, 30)
         
         -- Get SKU/UPC
         DECLARE @nSKUCnt INT
         SET @nSKUCnt = 0
         EXEC RDT.rdt_GETSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cBarcode
            ,@nSKUCnt     = @nSKUCnt       OUTPUT
            ,@bSuccess    = @bSuccess      OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

         IF @nSKUCnt = 1
         BEGIN
            EXEC [RDT].[rdt_GETSKU]
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cBarcode  OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT
         
            IF @bSuccess = 1
            BEGIN
               SET @cChildSKU = @cBarcode
            
               -- Check SKU had SNO
               IF EXISTS( SELECT 1 
                  FROM SKU WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND SKU = @cChildSKU
                     AND BUSR7 = 'Yes')
               BEGIN
                  SET @nErrNo = 181865
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU had SNO
                  SET @cOutField05 = ''
                  GOTO Quit
               END
               
               SET @cChildSNO = ''
            END
         END
      END

      -- Check child SNO valid
      IF @cChildSKU = ''
      BEGIN
         SET @nErrNo = 181866
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad SNO/SKU
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check child SKU in work order
      IF NOT EXISTS( SELECT 1 
         FROM WorkOrderDetail WITH (NOLOCK)
         WHERE WorkOrderKey = @cWorkOrderKey
            AND StorerKey = @cStorerKey
            AND SKU = @cChildSKU
            AND ExternLineNo <> '001')
      BEGIN
         SET @nErrNo = 181867
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in WO
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check child SKU over scan
      IF @nGroupKey > 0
      BEGIN
         DECLARE @nQTY     INT
         DECLARE @nExpQTY  INT
      
         -- Get expected QTY (all sets)
         SELECT @nExpQTY = ISNULL( SUM( QTY), 0) 
         FROM WorkOrderDetail WITH (NOLOCK)
         WHERE WorkOrderKey = @cWorkOrderKey
            AND StorerKey = @cStorerKey
            AND SKU = @cChildSKU
            AND ExternLineNo <> '001'
         
         -- Calc expected QTY of 1 set
         SELECT @nExpQTY = @nExpQTY / @nParentTotal
         
         -- Get scanned QTY of current set
         SELECT @nQTY = ISNULL( SUM( QTY), 0) 
         FROM rdt.rdtBundleSKULog WITH (NOLOCK)
         WHERE WorkOrderKey = @cWorkOrderKey
            AND GroupKey = @nGroupKey
            AND StorerKey = @cStorerKey
            AND SKU = @cChildSKU
            AND Type = 'C'
            
         -- Check SKU over scan
         IF (@nQTY + 1) > @nExpQTY
         BEGIN
            SET @nErrNo = 181868
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU over scan
            SET @cOutField05 = ''
            GOTO Quit
         END
      END

      -- Get child SKU additional info
      DECLARE @cExtendedField09 NVARCHAR( 30)
      SELECT @cExtendedField09 = ISNULL( ExtendedField09, '')
      FROM dbo.SKUInfo WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cChildSKU
      
      -- Capture additional info
      IF @cExtendedField09 = 'Y'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cWorkOrderKey
         SET @cOutField02 = @cParentSKU
         SET @cOutField03 = @cChildSKU
         SET @cOutField04 = '' -- Ethernet MAC
         SET @cOutField05 = '' -- WIFI MAC

         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Ethernet MAC
         
         SET @cFieldAttr04 = ''  -- Ethernet MAC
         SET @cFieldAttr05 = 'O' -- WIFI MAC
      
         -- Go to child MA screen
         SET @nScn = @nScn_Child_MAC
         SET @nStep = @nStep_Child_MAC

         GOTO Quit
      END

      -- Confirm
      EXEC rdt.rdt_BundleSKU_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cWorkOrderKey = @cWorkOrderKey,
         @cParentSKU    = @cParentSKU, 
         @cParentSNO    = @cParentSNO,         
         @cChildSKU     = @cChildSKU, 
         @cChildSNO     = @cChildSNO,
         @nChildTotal   = @nChildTotal, 
         @nChildScan    = @nChildScan OUTPUT, 
         @nGroupKey     = @nGroupKey  OUTPUT, 
         @nErrNo        = @nErrNo     OUTPUT, 
         @cErrMsg       = @cErrMsg    OUTPUT
      IF @nErrNO <> 0
         GOTO Quit

      -- Bundle completed
      IF @nChildScan = @nChildTotal
      BEGIN
         SET @nParentScan = @nParentScan + 1

         -- VC label
         IF @cVCLabel <> ''
         BEGIN
            -- Common params
            INSERT INTO @tVCLabel (Variable, Value) VALUES
               ( '@cWorkOrderKey',  @cWorkOrderKey),
               ( '@cParentSNO',     @cParentSNO)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cVCLabel, -- Report type
               @tVCLabel, -- Report params
               'rdtfnc_BundleSKU',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            -- IF @nErrNo <> 0
            --    GOTO Quit
         END

         -- Prepare next screen screen
         SET @cOutField01 = @cWorkOrderKey
         SET @cOutField02 = @cParentSKU
         SET @cOutField03 = '' -- ParentSerialNo
         SET @cOutField04 = CAST( @nParentScan AS NVARCHAR(5))+ '/' + CAST( @nParentTotal AS NVARCHAR(5))
      
         -- Go to parent screen
         SET @nScn = @nScn_Parent
         SET @nStep = @nStep_Parent
      END
      ELSE
      BEGIN         
         -- Prepare next screen var
         SET @cOutField01 = @cWorkOrderKey
         SET @cOutField02 = @cParentSKU
         SET @cOutField03 = @cParentSNO
         SET @cOutField04 = @cChildSKU
         SET @cOutField05 = '' -- ChildSNO
         SET @cOutField06 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

         -- Remain in current screen
         -- SET @nScn = @nScn_Child
         -- SET @nStep = @nStep_Child
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Delete log
      IF @nGroupKey > 0
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdtfnc_BundleSKU
         
         -- Loop log
         DECLARE @curLog CURSOR
         SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RowRef 
            FROM rdt.rdtBundleSKULog WITH (NOLOCK) 
            WHERE GroupKey = @nGroupKey
         OPEN @curLog 
         FETCH NEXT FROM @curLog INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtBundleSKULog 
            WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_BundleSKU
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               SET @nErrNo = 181869
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
               GOTO Quit               
            END
            FETCH NEXT FROM @curLog INTO @nRowRef
         END
         
         COMMIT TRAN rdtfnc_BundleSKU
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
      END
      
      -- Prepare next screen screen
      SET @cOutField01 = @cWorkOrderKey
      SET @cOutField02 = @cParentSKU
      SET @cOutField03 = '' -- ParentSerialNo
      SET @cOutField04 = CAST( @nParentScan AS NVARCHAR(5))+ '/' + CAST( @nParentTotal AS NVARCHAR(5))
   
      -- Go to parent screen
      SET @nScn = @nScn_Parent
      SET @nStep = @nStep_Parent
   END
END
GOTO Quit


/********************************************************************************
Step Child. screen = 6023
   WorkOrderKey   (Field01)
   Parent SKU     (field02)
   Child SKU      (field03)
   Ethernet MAC   (field04, input)
   WIFI MAC       (field05, input)
********************************************************************************/
Step_Child_MAC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cUserDefine01 NVARCHAR( 18)
      DECLARE @cUserDefine02 NVARCHAR( 18)
      
      /*
         Operator will scan a 2D barcode contain both MAC, but unfortunately the separator is an ENTER, which RDT cannot support
         So need to apply the following tricks:
         -- Take-in 1st and 2nd MAC, without any checking
         -- Once collected both MAC, check at once. 
            -- If encounter error, ignore both MAC, go back to 1st MAC field
      */
      
      -- Screen mapping
      SET @cUserDefine01 = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cUserDefine02 = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END
      
      -- Ethernet MAC
      IF @cFieldAttr04 = '' 
      BEGIN
         SET @cOutField04 = @cUserDefine01
         IF @cUserDefine01 = ''
            GOTO Quit
            
         SET @cFieldAttr04 = 'O'
         SET @cFieldAttr05 = ''
         GOTO Quit
      END
      
      -- WIFI MAC
      IF @cFieldAttr05 = ''
      BEGIN
         SET @cOutField05 = @cUserDefine02
         IF @cUserDefine02 = ''
            GOTO Quit
      END
         
      -- Check blank
      IF @cUserDefine01 = ''
      BEGIN
         SET @nErrNo = 181870
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need data
         GOTO Step_Child_MAC_Fail
      END

      -- Check format    
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UserDefine01', @cUserDefine01) = 0    
      BEGIN    
         SET @nErrNo = 181871  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_Child_MAC_Fail
      END

      -- Check duplicate (bundle level)
      IF EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtBundleSKULog WITH (NOLOCK)
         WHERE WorkOrderKey = @cWorkOrderKey
            AND UserDefine01 = @cUserDefine01)
      BEGIN    
         SET @nErrNo = 181872
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate SNO
         GOTO Step_Child_MAC_Fail
      END

      -- Check duplicate (workorder level)
      IF EXISTS( SELECT TOP 1 1 
         FROM dbo.WorkOrderDetail WITH (NOLOCK)
         WHERE WorkOrderKey = @cWorkOrderKey
            AND WkOrdUdef2 = @cUserDefine01)
      BEGIN    
         SET @nErrNo = 181873
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate SNO
         GOTO Step_Child_MAC_Fail
      END
         
      -- Check blank
      IF @cUserDefine02 = ''
      BEGIN
         SET @nErrNo = 181874
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need data
         GOTO Step_Child_MAC_Fail
      END

      -- Check format    
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UserDefine02', @cUserDefine02) = 0    
      BEGIN    
         SET @nErrNo = 181875    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_Child_MAC_Fail
      END
      
      -- Check duplicate (bundle level)
      IF EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtBundleSKULog WITH (NOLOCK)
         WHERE WorkOrderKey = @cWorkOrderKey
            AND UserDefine02 = @cUserDefine02)
      BEGIN    
         SET @nErrNo = 181876
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate SNO
         GOTO Step_Child_MAC_Fail
      END
      
      -- Check duplicate (workorder level)
      IF EXISTS( SELECT TOP 1 1 
         FROM dbo.WorkOrderDetail WITH (NOLOCK)
         WHERE WorkOrderKey = @cWorkOrderKey
            AND WkOrdUdef3 = @cUserDefine02)
      BEGIN    
         SET @nErrNo = 181877
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate SNO
         GOTO Step_Child_MAC_Fail
      END
      
      -- Confirm
      EXEC rdt.rdt_BundleSKU_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cWorkOrderKey = @cWorkOrderKey,
         @cParentSKU    = @cParentSKU, 
         @cParentSNO    = @cParentSNO,         
         @cChildSKU     = @cChildSKU, 
         @cChildSNO     = @cChildSNO,
         @cUserDefine01 = @cUserDefine01, 
         @cUserDefine02 = @cUserDefine02, 
         @nChildTotal   = @nChildTotal, 
         @nChildScan    = @nChildScan OUTPUT, 
         @nGroupKey     = @nGroupKey  OUTPUT, 
         @nErrNo        = @nErrNo     OUTPUT, 
         @cErrMsg       = @cErrMsg    OUTPUT
      IF @nErrNO <> 0
         GOTO Step_Child_MAC_Fail
      
      -- Bundle completed
      IF @nChildScan = @nChildTotal
      BEGIN
         SET @nParentScan = @nParentScan + 1

         -- VC label
         IF @cVCLabel <> ''
         BEGIN
            -- Common params
            INSERT INTO @tVCLabel (Variable, Value) VALUES
               ( '@cWorkOrderKey',  @cWorkOrderKey),
               ( '@cParentSNO',     @cParentSNO)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cVCLabel, -- Report type
               @tVCLabel, -- Report params
               'rdtfnc_BundleSKU',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            -- IF @nErrNo <> 0
            --    GOTO Quit
         END

         -- Prepare next screen screen
         SET @cOutField01 = @cWorkOrderKey
         SET @cOutField02 = @cParentSKU
         SET @cOutField03 = '' -- ParentSerialNo
         SET @cOutField04 = CAST( @nParentScan AS NVARCHAR(5))+ '/' + CAST( @nParentTotal AS NVARCHAR(5))

         -- Enable field
         SET @cFieldAttr04 = ''
         SET @cFieldAttr05 = ''
      
         -- Go to parent screen
         SET @nScn = @nScn_Parent
         SET @nStep = @nStep_Parent
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cWorkOrderKey
         SET @cOutField02 = @cParentSKU
         SET @cOutField03 = @cParentSNO
         SET @cOutField04 = @cChildSKU
         SET @cOutField05 = '' -- ChildSNO
         SET @cOutField06 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

         -- Enable field
         SET @cFieldAttr04 = ''
         SET @cFieldAttr05 = ''

         -- Go to child screen
         SET @nScn = @nScn_Child
         SET @nStep = @nStep_Child
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cWorkOrderKey
      SET @cOutField02 = @cParentSKU
      SET @cOutField03 = @cParentSNO
      SET @cOutField04 = @cChildSKU
      SET @cOutField05 = '' -- ChildSNO
      SET @cOutField06 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

      -- Enable field
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''

      -- Go to child screen
      SET @nScn = @nScn_Child
      SET @nStep = @nStep_Child
   END
   GOTO Quit

   Step_Child_MAC_Fail:
   BEGIN
      -- Reset field
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = 'O'

      EXEC rdt.rdtSetFocusField @nMobile, 4 -- UserDefine01       
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate   = GETDATE(),
      ErrMsg     = @cErrMsg,
      Func       = @nFunc,
      Step       = @nStep,
      Scn        = @nScn,

      V_QTY        = @nParentQTY, 

      V_String1  = @cWorkOrderKey,
      V_String2  = @cParentSKU,
      V_String3  = @cChildSKU,

      V_String21 = @cDecodeSP, 
      V_String22 = @cVCLabel, 

      V_String41 = @cParentSNO,
      V_String42 = @cChildSNO, 

      V_Integer1 = @nParentScan,
      V_Integer2 = @nParentTotal,
      V_Integer3 = @nChildScan,
      V_Integer4 = @nChildTotal,
      V_Integer5 = @nGroupKey,

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