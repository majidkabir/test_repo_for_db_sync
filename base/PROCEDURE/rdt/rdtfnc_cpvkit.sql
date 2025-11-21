SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_CPVKit                                             */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-03-20 1.0  Ung      WMS-4225 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_CPVKit](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
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
   @cSKU                NVARCHAR(60), 
   @cBarcode            NVARCHAR(60), 
   @cExternLotStatus    NVARCHAR(10), 
   @nRowRef             INT, 
   @nExpectedQTY        INT, 
   @nShelfLife          INT, 
   @dToday              DATETIME, 
   @dExpiryDate         DATETIME, 
   @dExternLottable04   DATETIME


-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cPrinter_Paper      NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),
   
   @dLottable04         DATETIME,
   @cLottable07         NVARCHAR( 30),
   @cLottable08         NVARCHAR( 30),
   @nParentQTY                INT, 

   @cKitKey             NVARCHAR(10),
   @cParentSKU          NVARCHAR(20),
   @cChildSKU           NVARCHAR(20),

   @cParentSNO          NVARCHAR(60),
   @cParentDesc         NVARCHAR(60),
   @cChildSNO           NVARCHAR(60),
   @cChildDesc          NVARCHAR(60),
   
   @nParentInner        INT, 
   @nParentScan         INT,
   @nParentTotal        INT,
   @nChildInner         INT, 
   @nChildScan          INT,
   @nChildTotal         INT,

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
   @cPrinter         = Printer,
   @cPrinter_Paper   = Printer_Paper,
   @cUserName        = UserName,
   
   @dLottable04      = V_Lottable04, 
   @cLottable07      = V_Lottable07, 
   @cLottable08      = V_Lottable08, 
   @nParentQTY       = V_QTY, 

   @cKitKey          = V_String1,
   @cParentSKU       = V_String2,
   @cChildSKU        = V_String3,

   @cParentSNO       = V_String41,
   @cParentDesc      = V_String42,
   @cChildSNO        = V_String43,
   @cChildDesc       = V_String44, 

   @nParentInner     = V_Integer1, 
   @nParentScan      = V_Integer2,
   @nParentTotal     = V_Integer3,
   @nChildInner      = V_Integer4, 
   @nChildScan       = V_Integer5,
   @nChildTotal      = V_Integer6,

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
   @nStep_KitKey        INT,  @nScn_KitKey       INT,
   @nStep_Parent        INT,  @nScn_Parent       INT,
   @nStep_Child         INT,  @nScn_Child        INT,
   @nStep_ParentSNO     INT,  @nScn_ParentSNO    INT,
   @nStep_CloseKit      INT,  @nScn_CloseKit     INT, 
   @nStep_Reset         INT,  @nScn_Reset        INT,
   @nStep_MultiSKU      INT,  @nScn_MultiSKU     INT
   
SELECT
   @nStep_KitKey        = 1,  @nScn_KitKey       = 5280,
   @nStep_Parent        = 2,  @nScn_Parent       = 5281,
   @nStep_Child         = 3,  @nScn_Child        = 5282,
   @nStep_ParentSNO     = 4,  @nScn_ParentSNO    = 5283,
   @nStep_CloseKit      = 5,  @nScn_CloseKit     = 5284, 
   @nStep_Reset         = 6,  @nScn_Reset        = 5285, 
   @nStep_MultiSKU      = 7,  @nScn_MultiSKU     = 5286

-- Redirect to respective screen
IF @nFunc = 632
BEGIN
   IF @nStep = 0 GOTO Step_Start       -- Menu. Func = 632
   IF @nStep = 1 GOTO Step_KitKey      -- Scn = 5280 Kit
   IF @nStep = 2 GOTO Step_Parent      -- Scn = 5281 Parent
   IF @nStep = 3 GOTO Step_Child       -- Scn = 5282 Child
   IF @nStep = 4 GOTO Step_ParentSNO   -- Scn = 5283 ParentSNO
   IF @nStep = 5 GOTO Step_CloseKit    -- Scn = 5284 Close Kit?
   IF @nStep = 6 GOTO Step_Reset       -- Scn = 5285 Reset Kit?
   IF @nStep = 7 GOTO Step_MultiSKU    -- Scn = 5286 Multi SKU selection
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 1018)
********************************************************************************/
Step_Start:
BEGIN
   -- Prep next screen var
   SET @cOutField01 = '' -- KitKey

   -- Set the entry point
   SET @nScn = @nScn_KitKey
   SET @nStep = @nStep_KitKey
END
GOTO Quit


/********************************************************************************
Step KitKey. screen = 5280
   KitKey     (field01, input)
   OPTION     (Field02, input)    
********************************************************************************/
Step_KitKey:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cKitKey = @cInField01
      SET @cOption = @cInField02   
      
      -- Check blank
      IF @cKitKey = ''
      BEGIN
         SET @nErrNo = 127151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need KITKEY
         GOTO Quit
      END

      -- Get Kit info
      DECLARE @cToStorerKey NVARCHAR(15)
      SELECT 
         @cChkStorerKey = StorerKey, 
         @cToStorerKey = ToStorerKey, 
         @cChkFacility = Facility, 
         @cChkStatus = Status
      FROM KIT WITH (NOLOCK)
      WHERE KitKey = @cKitKey
      
      -- Check Kit valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 127152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid KIT
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- KIT
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check diff storer
      IF @cChkStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 127153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check diff facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 127154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check status
      IF @cChkStatus = '9'
      BEGIN
         SET @nErrNo = 127155
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --KIT closed
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      -- Check inter storer kit
      IF @cStorerKey <> @cToStorerKey
      BEGIN
         SET @nErrNo = 127156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff To Storer
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check multi parent SKU in kit
      IF ( SELECT COUNT( DISTINCT SKU)
         FROM KitDetail WITH (NOLOCK)
         WHERE KitKey = @cKitKey
            AND Type = 'T') > 1
      BEGIN
         SET @nErrNo = 127157
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiParentKit
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check status
      IF EXISTS( SELECT TOP 1 1 FROM KIT WITH (NOLOCK) WHERE KitKey = @cKitKey AND USRDEF3 = 'PENDALLOC')
      BEGIN
         SET @nErrNo = 127501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --KIT PENDALLOC
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Get parent SKU
      SET @cParentSKU = ''
      SELECT TOP 1 
         @cParentSKU = SKU
      FROM dbo.KitDetail WITH (NOLOCK)
      WHERE KitKey = @cKitKey
         AND Type = 'T'
      ORDER BY KitLineNumber

      IF @cParentSKU = ''
      BEGIN
         SET @nErrNo = 129307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No parent SKU
         SET @cOutField01 = ''
         GOTO Quit
      END
            
      -- Check parent SKU completed
      IF NOT EXISTS( SELECT 1 
         FROM KitDetail WITH (NOLOCK) 
         WHERE KitKey = @cKitKey
            AND StorerKey = @cStorerKey
            AND SKU = @cParentSKU
            AND Type = 'T'
            AND Status = '0')
      BEGIN
         SET @nErrNo = 127162
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU completed
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Get parent SKU info
      SELECT
         @cParentDesc = Descr, 
         @nShelfLife = ShelfLife, 
         @nParentInner = CAST( Pack.InnerPack AS INT)
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cParentSKU

      -- Reset
      IF @cOption = '1'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = ''

         SET @nScn = @nScn_Reset
         SET @nStep = @nStep_Reset
      END
      ELSE
      BEGIN
         -- Prepare next screen screen
         SET @cOutField01 = @cKitKey
         SET @cOutField02 = @cParentSKU
         SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)
         SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)
         SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)
         SET @cOutField06 = '' -- QTY
      
         -- Go to track no screen
         SET @nScn = @nScn_Parent
         SET @nStep = @nStep_Parent
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @cUserID     = @cUserName,
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
Step_Parent. screen = 5281
   KitKey      (field01)
   Parent SKU  (field02)
   Desc 1      (field03)
   Desc 2      (field04)
   Desc 3      (field05)
   QTY         (field06, input)
********************************************************************************/
Step_Parent:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cQTY NVARCHAR( 5)
      
      -- Screen mapping
      SET @cQTY = @cInField06

      -- Check QTY blank
      IF @cQTY = ''
      BEGIN
         SET @nErrNo = 127163
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY
         GOTO Quit
      END

      -- Check QTY validate 
      IF rdt.rdtIsValidQty( @cQTY, 1) = 0
      BEGIN
         SET @nErrNo = 127164
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY
         GOTO Quit
      END
      SET @nParentQTY = @cQTY

      -- Check parent SKU QTY
      IF (SELECT ISNULL( SUM( (KD.ExpectedQTY - KD.QTY) / CASE WHEN Pack.InnerPack > 0 THEN Pack.InnerPack ELSE 1 END), 0) 
         FROM KitDetail KD WITH (NOLOCK) 
            JOIN SKU WITH (NOLOCK) ON (KD.StorerKey = SKU.StorerKey AND KD.SKU = SKU.SKU)
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE KD.KitKey = @cKitKey
            AND KD.StorerKey = @cStorerKey
            AND KD.SKU = @cParentSKU
            AND KD.Type = 'T'
            AND KD.Status = '0') < @nParentQTY
      BEGIN
         SET @nErrNo = 127165
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY over kit
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY
         GOTO Quit
      END

      -- Populate parent SKU
      EXEC rdt.rdt_CPVKit_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PARENT',
         @cKitKey      = @cKitKey,
         @cParentSKU   = @cParentSKU, 
         @nParentInner = @nParentInner, 
         @nQTY         = @nParentQTY,
         @nErrNo       = @nErrNo  OUTPUT, 
         @cErrMsg      = @cErrMsg OUTPUT
      IF @nErrNO <> 0
         GOTO Quit

      -- Get stat
      SET @nChildTotal = 0
      EXEC rdt.rdt_CPVKit_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'BOTH',
         @cKitKey, @cParentSKU, @nParentInner, @cChildSKU, @nChildInner,
         @nParentScan  OUTPUT, 
         @nParentTotal OUTPUT, 
         @nChildScan   OUTPUT, 
         @nChildTotal  OUTPUT, 
         @nErrNo       OUTPUT, 
         @cErrMsg      OUTPUT

      SET @cChildSKU = ''
      SET @cChildDesc = ''

      -- Prepare next screen var
      SET @cOutField01 = @cKitKey
      SET @cOutField02 = @cChildSKU
      SET @cOutField03 = SUBSTRING( @cChildDesc, 1, 20)
      SET @cOutField04 = SUBSTRING( @cChildDesc, 21, 20)
      SET @cOutField05 = SUBSTRING( @cChildDesc, 41, 20)
      SET @cOutField06 = '' -- ChildSNO
      SET @cOutField07 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))
      
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- ChildLOT

      -- Go to track no screen
      SET @nScn = @nScn_Child
      SET @nStep = @nStep_Child
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      DECLARE @cCloseKit NVARCHAR( 1)

      SET @cCloseKit = 'Y'
      
      -- Get Kit info
      DECLARE @cStatus NVARCHAR( 10)
      DECLARE @cUDF3 NVARCHAR( 18)
      SELECT 
         @cStatus = Status, 
         @cUDF3 = USRDEF3
      FROM Kit WITH (NOLOCK) 
      WHERE KitKey = @cKitKey 
      
      -- Check kit is closed or submitted to backend alloc
      IF @cStatus = '9' OR
         @cUDF3 = 'PENDALLOC'
         SET @cCloseKit = 'N'
      
      -- Check all KitDetail is fulfill
      IF @cCloseKit = 'Y'
      BEGIN
         -- Open QTY
         IF EXISTS( SELECT 1 
            FROM KitDetail WITH (NOLOCK)
            WHERE KitKey = @cKitKey 
               AND Status = '0'
               AND QTY > 0
               AND ExpectedQTY > QTY)
            SET @cCloseKit = 'N'
      END

      IF @cCloseKit = 'Y'
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = '' -- Option

         -- Go to close kit screen
         SET @nScn = @nScn_CloseKit
         SET @nStep = @nStep_CloseKit
      END
      ELSE
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = '' -- KitKey

         -- Go to kit key screen
         SET @nScn = @nScn_KitKey
         SET @nStep = @nStep_KitKey
      END
   END
END
GOTO Quit


/********************************************************************************
Step Child. screen = 5282
   KitKey      (Field01)
   Child SKU   (field02)
   Desc 1      (field03)
   Desc 2      (field04)
   Desc 3      (field05)
   Child LOT   (field06, input)
   Scan        (field07)
********************************************************************************/
Step_Child:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cChildSNO = @cInField06
      
      -- Finish scan
      IF @nChildScan = @nChildTotal
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- ParentSNO

         -- Go to pallet serialno screen
         SET @nScn = @nScn_ParentSNO
         SET @nStep = @nStep_ParentSNO
      
         GOTO Quit
      END

      -- Check blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 129315
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ChildLOT
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- In future MasterLOT could > 30 chars, need to use 2 lottables field
      SET @cLottable07 = ''
      SET @cLottable08 = ''

      -- Decode to abstract master LOT
      EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cChildSNO,
         @cLottable07 = @cLottable07 OUTPUT,
         @cLottable08 = @cLottable08 OUTPUT,
         @nErrNo  = @nErrNo  OUTPUT,
         @cErrMsg = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Check barcode format
      IF @cLottable07 = '' AND @cLottable08 = ''
      BEGIN
         SET @nErrNo = 129316
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         SET @cOutField06 = ''
         GOTO Quit
      END

      DECLARE @cMasterLOT NVARCHAR(60)
      SELECT @cMasterLOT = @cLottable07 + @cLottable08

      -- Get master LOT info
      SELECT 
         @cSKU = SKU, 
         @cExternLotStatus = ExternLotStatus, 
         @dExternLottable04 = ExternLottable04
      FROM ExternLotAttribute WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ExternLOT = @cMasterLOT

      SET @nRowCount = @@ROWCOUNT

      -- Check SKU in Kit
      IF @nRowCount = 1
      BEGIN
         IF NOT EXISTS( SELECT TOP 1 1
            FROM KitDetail WITH (NOLOCK)
            WHERE KitKey = @cKitKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND Type = 'F')
         BEGIN
            SET @nErrNo = 125026
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in Kit
            SET @cOutField06 = ''
            GOTO Quit
         END
         
         SET @cChildSKU = @cSKU
      END

      -- Check master LOT valid
      ELSE IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 127503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid MLOT
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Check multi SKU extern LOT
      ELSE -- IF @nRowCount > 1
      BEGIN
         SET @cSKU = ''
         EXEC rdt.rdt_CPVMultiSKUExtLOT @nMobile, @nFunc, @cLangCode,
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
            @cMasterLOT, 
            @cStorerKey,
            @cSKU       OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT

         IF @nErrNo = 0 -- Populate multi SKU screen
         BEGIN
            -- Go to Multi SKU screen
            SET @nScn = @nScn_MultiSKU
            SET @nStep = @nStep_MultiSKU
            GOTO Quit
         END
      END

      -- Check master LOT status
      IF @cExternLotStatus <> 'ACTIVE'
      BEGIN
         SET @nErrNo = 127504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive MLOT
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Get SKU info
      SELECT 
         @cChildDesc = SKU.Descr, 
         @nShelfLife = SKU.ShelfLife, 
         @nChildInner = Pack.InnerPack
      FROM SKU WITH (NOLOCK) 
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey 
         AND SKU.SKU = @cChildSKU

      -- Calc expiry date
      SET @dToday = CONVERT( DATE, GETDATE())
      SET @dExpiryDate = @dExternLottable04
      IF @nShelfLife > 0
         SET @dExpiryDate = DATEADD( dd, -@nShelfLife, @dExternLottable04)

      -- Check expired stock
      IF @dExpiryDate < @dToday
      BEGIN
         SET @nErrNo = 125015
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock expired
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Add child serial no
      EXEC rdt.rdt_CPVKit_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHILD',
         @cKitKey     = @cKitKey,
         @cChildSKU   = @cChildSKU, 
         @nChildInner = @nChildInner, 
         @cChildSNO   = @cChildSNO,
         @cLottable07 = @cLottable07,
         @cLottable08 = @cLottable08,
         @nErrNo      = @nErrNo  OUTPUT, 
         @cErrMsg     = @cErrMsg OUTPUT
      IF @nErrNO <> 0
         GOTO Quit

      -- Get stat
      EXEC rdt.rdt_CPVKit_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHILD',
         @cKitKey, @cParentSKU, @nParentInner, @cChildSKU, @nChildInner,
         @nParentScan  OUTPUT, 
         @nParentTotal OUTPUT, 
         @nChildScan   OUTPUT, 
         @nChildTotal  OUTPUT, 
         @nErrNo       OUTPUT, 
         @cErrMsg      OUTPUT

      IF @nChildScan = @nChildTotal
      BEGIN
         IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cParentSKU AND SerialNoCapture IN ('1', '3'))
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- ParentSNO

            -- Go to pallet serialno screen
            SET @nScn = @nScn_ParentSNO
            SET @nStep = @nStep_ParentSNO
         END
         ELSE
         BEGIN
            -- Add parent serial no (BLANK)
            EXEC rdt.rdt_CPVKit_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PARENTSNO',
               @cKitKey      = @cKitKey,
               @cParentSKU   = @cParentSKU, 
               @nParentInner = @nParentInner, 
               @cParentSNO   = @cParentSNO, 
               @cLottable07  = @cLottable07,
               @cLottable08  = @cLottable08,
               @nErrNo       = @nErrNo  OUTPUT, 
               @cErrMsg    = @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Get stat
            EXEC rdt.rdt_CPVKit_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PARENT',
               @cKitKey, @cParentSKU, @nParentInner, @cChildSKU, @nChildInner,
               @nParentScan  OUTPUT, 
               @nParentTotal OUTPUT, 
               @nChildScan   OUTPUT, 
               @nChildTotal  OUTPUT, 
               @nErrNo       OUTPUT, 
               @cErrMsg      OUTPUT

            IF @nParentScan = @nParentTotal
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cKitKey
               SET @cOutField02 = @cParentSKU
               SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)
               SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)
               SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)
               SET @cOutField06 = '' -- QTY

               -- Go to statistic screen
               SET @nScn = @nScn_Parent
               SET @nStep = @nStep_Parent
            END
            ELSE
            BEGIN
               -- Get stat
               EXEC rdt.rdt_CPVKit_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHILD',
                  @cKitKey, @cParentSKU, @nParentInner, @cChildSKU, @nChildInner,
                  @nParentScan  OUTPUT, 
                  @nParentTotal OUTPUT, 
                  @nChildScan   OUTPUT, 
                  @nChildTotal  OUTPUT, 
                  @nErrNo       OUTPUT, 
                  @cErrMsg      OUTPUT

               -- Prepare next screen var
               SET @cOutField01 = @cKitKey
               SET @cOutField02 = @cChildSKU
               SET @cOutField03 = SUBSTRING( @cChildDesc, 1, 20)
               SET @cOutField04 = SUBSTRING( @cChildDesc, 21, 20)
               SET @cOutField05 = SUBSTRING( @cChildDesc, 41, 20)
               SET @cOutField06 = '' -- ChildSNO
               SET @cOutField07 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

               -- Go to statistic screen
               SET @nScn = @nScn_Child
               SET @nStep = @nStep_Child
            END
         END
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cKitKey
         SET @cOutField02 = @cChildSKU
         SET @cOutField03 = SUBSTRING( @cChildDesc, 1, 20)
         SET @cOutField04 = SUBSTRING( @cChildDesc, 21, 20)
         SET @cOutField05 = SUBSTRING( @cChildDesc, 41, 20)
         SET @cOutField06 = '' -- ChildSNO
         SET @cOutField07 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ChildSKU

         -- Remain in current screen
         -- SET @nScn = @nScn_Parent
         -- SET @nStep = @nStep_Parent
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Delete log
      IF EXISTS( SELECT 1 FROM rdt.rdtCPVKitLog WITH (NOLOCK) WHERE Mobile = @nMobile)
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdtfnc_CPVKit
         
         -- Loop log
         DECLARE @curLog CURSOR
         SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RowRef 
            FROM rdt.rdtCPVKitLog WITH (NOLOCK) 
            WHERE Mobile = @nMobile
         OPEN @curLog 
         FETCH NEXT FROM @curLog INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtCPVKitLog 
            WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_CPVKit
               WHILE @@TRANCOUNT > @nTranCount
                  COMMIT TRAN
               SET @nErrNo = 127174
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
               GOTO Quit               
            END
            FETCH NEXT FROM @curLog INTO @nRowRef
         END
         
         COMMIT TRAN rdtfnc_CPVKit
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
      END
      
      -- Prepare next screen var
      SET @cOutField01 = @cKitKey
      SET @cOutField02 = @cParentSKU
      SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)
      SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)
      SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)
      SET @cOutField06 = '' -- QTY

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- ParentSKU

      -- Go to pallet ID screen
      SET @nScn = @nScn_Parent
      SET @nStep = @nStep_Parent
   END
END
GOTO Quit


/********************************************************************************
Step ParentSNO. screen = 5283
   Parent SNO  (field01, input)
********************************************************************************/
Step_ParentSNO:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cParentSNO = @cInField01

      -- Check blank
      IF @cParentSNO = ''
      BEGIN
         SET @nErrNo = 127175
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need parentSNO
         GOTO Quit
      END

      -- In future MasterLOT could > 30 chars, need to use 2 lottables field
      SET @cLottable07 = ''
      SET @cLottable08 = ''

      -- Decode to abstract master LOT
      EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cParentSNO, 
         @cLottable07 = @cLottable07 OUTPUT, 
         @cLottable08 = @cLottable08 OUTPUT, 
         @nErrNo  = @nErrNo  OUTPUT, 
         @cErrMsg = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
      
      -- Check parent master LOT in adjustment
      IF NOT EXISTS( SELECT 1 
         FROM KitDetail WITH (NOLOCK)
         WHERE KitKey = @cKitKey
            AND StorerKey = @cStorerKey
            AND SKU = @cParentSKU
            AND Type = 'T'
            AND Lottable07 = @cLottable07
            AND Lottable08 = @cLottable08)
      BEGIN
         SET @nErrNo = 127185
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MLOT NotIn ADJ
         SET @cOutField06 = ''
         GOTO Quit
      END

      SET @cMasterLOT = @cLottable07 + @cLottable08

      -- Get master LOT info
      SELECT TOP 1
         @cExternLotStatus = ExternLotStatus,
         @dExternLottable04 = ExternLottable04
      FROM ExternLotAttribute WITH (NOLOCK)
      WHERE ExternLOT = @cMasterLOT
         AND StorerKey = @cStorerKey
         AND SKU = @cParentSKU 

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 127503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid MLOT
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Check master LOT status
      IF @cExternLotStatus <> 'ACTIVE'
      BEGIN
         SET @nErrNo = 125014
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive LOT
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Add parent serial no
      EXEC rdt.rdt_CPVKit_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PARENTSNO',
         @cKitKey      = @cKitKey,
         @cParentSKU   = @cParentSKU, 
         @nParentInner = @nParentInner,  
         @cParentSNO   = @cParentSNO,
         @cLottable07  = @cLottable07,
         @cLottable08  = @cLottable08,
         @nQTY         = @nParentQTY, 
         @nErrNo       = @nErrNo  OUTPUT, 
         @cErrMsg      = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Get stat
      EXEC rdt.rdt_CPVKit_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PARENT',
         @cKitKey, @cParentSKU, @nParentInner, @cChildSKU, @nChildInner,
         @nParentScan  OUTPUT, 
         @nParentTotal OUTPUT, 
         @nChildScan   OUTPUT, 
         @nChildTotal  OUTPUT, 
         @nErrNo       OUTPUT, 
         @cErrMsg      OUTPUT

      IF @nParentScan = @nParentTotal
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cKitKey
         SET @cOutField02 = @cParentSKU
         SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)
         SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)
         SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)
         SET @cOutField06 = '' -- QTY

         -- Go to statistic screen
         SET @nScn = @nScn_Parent
         SET @nStep = @nStep_Parent
      END
      ELSE
      BEGIN
         -- Get stat
         EXEC rdt.rdt_CPVKit_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHILD',
            @cKitKey, @cParentSKU, @nParentInner, @cChildSKU, @nChildInner,
            @nParentScan  OUTPUT, 
            @nParentTotal OUTPUT, 
            @nChildScan   OUTPUT, 
            @nChildTotal  OUTPUT, 
            @nErrNo       OUTPUT, 
            @cErrMsg      OUTPUT

         -- Prepare next screen var
         SET @cOutField01 = @cKitKey
         SET @cOutField02 = @cChildSKU
         SET @cOutField03 = SUBSTRING( @cChildDesc, 1, 20)
         SET @cOutField04 = SUBSTRING( @cChildDesc, 21, 20)
         SET @cOutField05 = SUBSTRING( @cChildDesc, 41, 20)
         SET @cOutField06 = '' -- ChildSNO
         SET @cOutField07 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ChildSKU

         -- Go to statistic screen
         SET @nScn = @nScn_Child
         SET @nStep = @nStep_Child
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cKitKey
      SET @cOutField02 = @cChildSKU
      SET @cOutField03 = SUBSTRING( @cChildDesc, 1, 20)
      SET @cOutField04 = SUBSTRING( @cChildDesc, 21, 20)
      SET @cOutField05 = SUBSTRING( @cChildDesc, 41, 20)
      SET @cOutField06 = '' -- ChildSNO
      SET @cOutField07 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

      -- Go to child screen
      SET @nScn = @nScn_Child
      SET @nStep = @nStep_Child
   END
END
GOTO Quit


/********************************************************************************
Step Close kit. screen = 5284. Close kit?
   Option (Field11, input)
********************************************************************************/
Step_CloseKit:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check valid option
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 127178
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_CPVKit -- For rollback or commit only our own transaction
   
         -- Close kit
         UPDATE Kit SET
            USRDEF3 = 'PENDALLOC', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE KitKey = @cKitKey
         SET @nErrNo = @@ERROR  
         IF @nErrNo <> 0
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_CPVKit
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END
   
         COMMIT TRAN rdtfnc_CPVKit
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

         -- Prepare next screen screen
         SET @cOutField01 = '' -- KitKey
         SET @cOutField02 = '' -- Option
         
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- KitKey

         -- Go to kit screen
         SET @nScn = @nScn_KitKey
         SET @nStep = @nStep_KitKey

         GOTO Quit
      END
      
      IF @cOption = '9' -- No
      BEGIN
         -- Prepare next screen screen
         SET @cOutField01 = '' -- KitKey
         SET @cOutField02 = '' -- Option

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- KitKey

         -- Go to track no screen
         SET @nScn = @nScn_KitKey
         SET @nStep = @nStep_KitKey
      END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen screen
      SET @cOutField01 = @cKitKey
      SET @cOutField02 = @cParentSKU
      SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)
      SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)
      SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)
      SET @cOutField06 = '' -- QTY

      -- Go to track no screen
      SET @nScn = @nScn_Parent
      SET @nStep = @nStep_Parent
   END
END
GOTO Quit


/********************************************************************************
Step 5. Screen = 5285. Reset kit?
   OPTION (Field01, input)
********************************************************************************/
Step_Reset:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 127183
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OPTION
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check blank
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 127184
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OPTION
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cOption = '1'
      BEGIN
         -- Reset
         EXEC rdt.rdt_CPVKit_Reset @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
            @cKitKey, 
            @nErrNo     OUTPUT, 
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- KitKey
      SET @cOutField02 = '' -- Option
      
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- KitKey
      
      -- Go to Order screen
      SET @nScn  = @nScn_KitKey
      SET @nStep = @nStep_KitKey
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cKitKey
      SET @cOutField02 = '' -- Option

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- KitKey

      -- Go back order screen
      SET @nScn  = @nScn_KitKey
      SET @nStep = @nStep_KitKey
   END
END
GOTO Quit


/********************************************************************************
Step 7. Screen = 5286. Multi SKU
   Option      (Field13, input)
   SKU         (Field02)
   SKUDesc1    (Field03)
   SKUDesc2    (Field04)
   SKUDesc3    (Field05)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   SKUDesc3    (Field10)
********************************************************************************/
Step_MultiSKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cMasterLOT = @cLottable07 + @cLottable08
      
      EXEC rdt.rdt_CPVMultiSKUExtLOT @nMobile, @nFunc, @cLangCode,
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
         @cMasterLOT, 
         @cStorerKey OUTPUT,
         @cChildSKU  OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Check SKU in kit
      IF NOT EXISTS( SELECT TOP 1 1
         FROM KitDetail WITH (NOLOCK)
         WHERE KitKey = @cKitKey
            AND Type = 'F'
            AND StorerKey = @cStorerKey
            AND SKU = @cChildSKU)
      BEGIN
         SET @nErrNo = 125027
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn Kit
         GOTO Quit
      END

      -- Get master LOT info
      SELECT TOP 1
         @cExternLotStatus = ExternLotStatus,
         @dExternLottable04 = ExternLottable04
      FROM ExternLotAttribute WITH (NOLOCK)
      WHERE ExternLOT = @cMasterLOT
         AND StorerKey = @cStorerKey
         AND SKU = @cChildSKU 

      -- Check master LOT status
      IF @cExternLotStatus <> 'ACTIVE'
      BEGIN
         SET @nErrNo = 125014
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive LOT
         SET @cOutField06 = ''
         GOTO Quit
      END
      
      -- Get SKU info
      SELECT 
         @cChildDesc = SKU.Descr, 
         @nShelfLife = SKU.ShelfLife, 
         @nChildInner = Pack.InnerPack
      FROM SKU WITH (NOLOCK) 
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey 
         AND SKU.SKU = @cChildSKU
      
      -- Calc expiry date
      SET @dToday = CONVERT( DATE, GETDATE())
      SET @dExpiryDate = @dExternLottable04
      IF @nShelfLife > 0
         SET @dExpiryDate = DATEADD( dd, -@nShelfLife, @dExternLottable04)

      -- Check expired stock
      IF @dExpiryDate < @dToday
      BEGIN
         SET @nErrNo = 125015
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock expired
         SET @cOutField06 = ''
         GOTO Quit
      END

      -- Add child serial no
      EXEC rdt.rdt_CPVKit_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHILD',
         @cKitKey     = @cKitKey,
         @cChildSKU   = @cChildSKU,     
         @nChildInner = @nChildInner, 
         @cChildSNO   = @cChildSNO,
         @cLottable07 = @cLottable07,
         @cLottable08 = @cLottable08,
         @nErrNo      = @nErrNo  OUTPUT, 
         @cErrMsg     = @cErrMsg OUTPUT
      IF @nErrNO <> 0
         GOTO Quit

      -- Get stat
      EXEC rdt.rdt_CPVKit_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHILD',
         @cKitKey, @cParentSKU, @nParentInner, @cChildSKU, @nChildInner,
         @nParentScan  OUTPUT, 
         @nParentTotal OUTPUT, 
         @nChildScan   OUTPUT, 
         @nChildTotal  OUTPUT, 
         @nErrNo       OUTPUT, 
         @cErrMsg      OUTPUT

      IF @nChildScan = @nChildTotal
      BEGIN
         IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cParentSKU AND SerialNoCapture IN ('1', '3'))
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = '' -- ParentSNO

            -- Go to pallet serialno screen
            SET @nScn = @nScn_ParentSNO
            SET @nStep = @nStep_ParentSNO
         END
         ELSE
         BEGIN
            -- Add parent serial no (BLANK)
            EXEC rdt.rdt_CPVKit_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PARENTSNO',
               @cKitKey      = @cKitKey,
               @cParentSKU   = @cParentSKU, 
               @nParentInner = @nParentInner, 
               @cParentSNO   = @cParentSNO, 
               @cLottable07  = @cLottable07,
               @cLottable08  = @cLottable08,
               @nErrNo       = @nErrNo  OUTPUT, 
               @cErrMsg      = @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            -- Get stat
            EXEC rdt.rdt_CPVKit_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PARENT',
               @cKitKey, @cParentSKU, @nParentInner, @cChildSKU, @nChildInner,
               @nParentScan  OUTPUT, 
               @nParentTotal OUTPUT, 
               @nChildScan   OUTPUT, 
               @nChildTotal  OUTPUT, 
               @nErrNo       OUTPUT, 
               @cErrMsg      OUTPUT

            IF @nParentScan = @nParentTotal
            BEGIN
               -- Prepare next screen var
               SET @cOutField01 = @cKitKey
               SET @cOutField02 = @cParentSKU
               SET @cOutField03 = SUBSTRING( @cParentDesc, 1, 20)
               SET @cOutField04 = SUBSTRING( @cParentDesc, 21, 20)
               SET @cOutField05 = SUBSTRING( @cParentDesc, 41, 20)
               SET @cOutField06 = '' -- QTY

               -- Go to statistic screen
               SET @nScn = @nScn_Parent
               SET @nStep = @nStep_Parent
            END
            ELSE
            BEGIN
               -- Get stat
               EXEC rdt.rdt_CPVKit_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CHILD',
                  @cKitKey, @cParentSKU, @nParentInner, @cChildSKU, @nChildInner,
                  @nParentScan  OUTPUT, 
                  @nParentTotal OUTPUT, 
                  @nChildScan   OUTPUT, 
                  @nChildTotal  OUTPUT, 
                  @nErrNo       OUTPUT, 
                  @cErrMsg      OUTPUT

               -- Prepare next screen var
               SET @cOutField01 = @cKitKey
               SET @cOutField02 = @cChildSKU
               SET @cOutField03 = SUBSTRING( @cChildDesc, 1, 20)
               SET @cOutField04 = SUBSTRING( @cChildDesc, 21, 20)
               SET @cOutField05 = SUBSTRING( @cChildDesc, 41, 20)
               SET @cOutField06 = '' -- ChildSNO
               SET @cOutField07 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

               -- Go to statistic screen
               SET @nScn = @nScn_Child
               SET @nStep = @nStep_Child
            END
         END
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cKitKey
         SET @cOutField02 = @cChildSKU
         SET @cOutField03 = SUBSTRING( @cChildDesc, 1, 20)
         SET @cOutField04 = SUBSTRING( @cChildDesc, 21, 20)
         SET @cOutField05 = SUBSTRING( @cChildDesc, 41, 20)
         SET @cOutField06 = '' -- ChildSNO
         SET @cOutField07 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

         -- Go to child LOT screen
         SET @nScn = @nScn_Child
         SET @nStep = @nStep_Child
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cKitKey
      SET @cOutField02 = @cChildSKU
      SET @cOutField03 = SUBSTRING( @cChildDesc, 1, 20)
      SET @cOutField04 = SUBSTRING( @cChildDesc, 21, 20)
      SET @cOutField05 = SUBSTRING( @cChildDesc, 41, 20)
      SET @cOutField06 = '' -- ChildSNO
      SET @cOutField07 = CAST( @nChildScan AS NVARCHAR(5))+ '/' + CAST( @nChildTotal AS NVARCHAR(5))

      -- Go to child LOT screen
      SET @nScn = @nScn_Child
      SET @nStep = @nStep_Child
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

      V_Lottable04 = @dLottable04,  
      V_Lottable07 = @cLottable07,  
      V_Lottable08 = @cLottable08,  
      V_QTY        = @nParentQTY, 

      V_String1  = @cKitKey,
      V_String2  = @cParentSKU,
      V_String3  = @cChildSKU,

      V_String41 = @cParentSNO,
      V_String42 = @cParentDesc,
      V_String43 = @cChildSNO, 
      V_String44 = @cChildDesc, 

      V_Integer1 = @nParentInner, 
      V_Integer2 = @nParentScan,
      V_Integer3 = @nParentTotal,
      V_Integer4 = @nChildInner, 
      V_Integer5 = @nChildScan,
      V_Integer6 = @nChildTotal,

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