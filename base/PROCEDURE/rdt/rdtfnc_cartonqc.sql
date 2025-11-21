SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_CartonQC                                           */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Check carton is single SKU and QTY is correct                     */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2019-05-21   1.0  Ung        WMS-9158 Created                              */
/******************************************************************************/
CREATE PROC [RDT].[rdtfnc_CartonQC] (
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @bSuccess            INT,
   @cUPC                NVARCHAR( 30)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),

   @cSKU                NVARCHAR( 20),
   @cSKUDescr           NVARCHAR( 60),
   @cSize               NVARCHAR( 10),
   @nActQTY             INT,

   @nExpQTY             INT,

   @cBarcode            NVARCHAR( 30),

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,

   @cSKU       = V_SKU,
   @cSKUDescr  = V_SKUDescr,
   @nActQTY    = V_QTY,

   @nExpQTY    = V_Integer1,

   @cSize      = V_String1,
   @cBarcode   = V_String40,

   @cInField01 = I_Field01,  @cOutField01 = O_Field01,  @cFieldAttr01  =FieldAttr01,
   @cInField02 = I_Field02,  @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,  @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,  @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,  @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,  @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,  @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,  @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,  @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,  @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,  @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,  @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,  @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,  @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,  @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 879  -- Carton QC
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 879
   IF @nStep = 1  GOTO Step_1  -- Scn = 5460. QTY
   IF @nStep = 2  GOTO Step_2  -- Scn = 5461. SKU
   IF @nStep = 3  GOTO Step_3  -- Scn = 5462. Message
   IF @nStep = 4  GOTO Step_4  -- Scn = 5463. Confirm abort?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 879
********************************************************************************/
Step_0:
BEGIN
   -- Event log
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '1', -- Sign-In
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey

   -- Prepare next screen var
   SET @cOutField01 = ''

   -- Go to QTY screen
   SET @nScn = 5460
   SET @nStep = 1
END
GOTO Quit


/***********************************************************************************
Scn = 5460. QTY screen
   QTY (field01)
***********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cQTY NVARCHAR(5)

      -- Screen mapping
      SET @cQTY = @cInField01

      -- Check blank
      IF @cQTY = ''
      BEGIN
         SET @nErrNo = 138751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY
         GOTO Quit
      END

      -- Check QTY valid
      IF rdt.rdtIsValidQTY( @cQTY, 1) = 0
      BEGIN
         SET @nErrNo = 138752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END

      SET @nExpQTY = CAST( @cQTY AS INT)

      -- Prep next screen var
      SET @cOutField01 = '' -- SKU
      SET @cOutField02 = '' -- Desc1
      SET @cOutField03 = '' -- Desc2
      SET @cOutField04 = '' -- Size
      SET @cOutField05 = '' -- SKU
      SET @cOutField06 = CAST( @nExpQTY AS NVARCHAR(5)) -- EXP QTY
      SET @cOutField07 = '' -- ACT QTY

      SET @cSKU = ''
      SET @cBarcode = ''
      SET @nActQTY = 0

      -- Go to next screen
      SET @nStep = @nStep + 1
      SET @nScn = @nScn + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '9', -- Sign Out Function
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
   END
END
GOTO Quit


/***********************************************************************************
Scn = 5461. SKU screen
   SKU      (field01)
   Desc1    (field02)
   Desc2    (field03)
   Size     (field04)
   SKU      (field05, input)
   EXP QTY  (field06)
   ACT QTY  (field07)
***********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUPC = @cInField05

      -- Blank (indicate end capture)
      IF @cUPC = ''
      BEGIN
         -- QTY match
         IF @nExpQTY = @nActQTY
         BEGIN
            -- Prepare prev screen var
            SET @cOutField01 = ''

            -- Go to QTY correct screen
            SET @nStep = @nStep + 1
            SET @nScn = @nScn + 1

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 138753
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- New carton, 1st piece
         IF @cSKU = ''
         BEGIN
            -- Get SKU/UPC
            DECLARE @nSKUCnt INT
            SET @nSKUCnt = 0

            EXEC RDT.rdt_GETSKUCNT
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cUPC
               ,@nSKUCnt     = @nSKUCnt       OUTPUT
               ,@bSuccess    = @bSuccess      OUTPUT
               ,@nErr        = @nErrNo        OUTPUT
               ,@cErrMsg     = @cErrMsg       OUTPUT

            -- Check SKU valid
            IF @nSKUCnt = 1
            BEGIN
               SET @cBarcode = @cUPC

               -- Get SKU
               EXEC [RDT].[rdt_GETSKU]
                   @cStorerKey  = @cStorerKey
                  ,@cSKU        = @cUPC          OUTPUT
                  ,@bSuccess    = @bSuccess      OUTPUT
                  ,@nErr        = @nErrNo        OUTPUT
                  ,@cErrMsg     = @cErrMsg       OUTPUT

               SET @cSKU = @cUPC

               -- Get SKU info
               SELECT
                  @cSKUDescr = ISNULL( Descr, ''),
                  @cSize = ISNULL( Size, '')
               FROM dbo.SKU SKU WITH (NOLOCK)
               WHERE SKU.StorerKey = @cStorerKey
                  AND SKU.SKU = @cSKU
            END

            -- Check multiple SKU barcode
            ELSE IF @nSKUCnt > 1
            BEGIN
               SET @nErrNo = 138754
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
               SET @cOutField05 = '' -- SKU
               GOTO Quit
            END
            ELSE
            BEGIN
               SET @cSKU = @cUPC
               SET @cBarcode = @cUPC
               SET @cSKUDescr = ''
               SET @cSize = ''
            END

            SET @cOutField01 = @cSKU
            SET @cOutField02 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
            SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
            SET @cOutField04 = @cSize
         END

         -- Existing SKU
         ELSE IF @cBarcode <> @cUPC
         BEGIN
            SET @nErrNo = 138755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different SKU
            SET @cOutField05 = '' -- SKU
            GOTO Quit
         END

         SET @nActQTY = @nActQTY + 1
      END

      -- Prep next screen var
      SET @cOutField05 = '' -- SKU
      SET @cOutField06 = CAST( @nExpQTY AS NVARCHAR(5)) -- EXP QTY
      SET @cOutField07 = CAST( @nActQTY AS NVARCHAR(5)) -- ACT QTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = ''

      -- Go to QTY screen
      SET @nStep = @nStep + 2
      SET @nScn = @nScn + 2
   END
END
GOTO Quit


/***********************************************************************************
Scn = 5462. Message screen
   QTY CORRECT
***********************************************************************************/
Step_3:
BEGIN
   -- Event Log
   EXEC RDT.rdt_STD_EventLog
      @cActionType  = '3',
      @nMobileNo    = @nMobile,
      @nFunctionID  = @nFunc,
      @cFacility    = @cFacility,
      @cStorerKey   = @cStorerkey,
      @cSKU         = @cSKU, 
      @nExpectedQTY = @nExpQTY,
      @nQTY         = @nActQTY

   -- Prepare prev screen var
   SET @cOutField01 = ''

   -- Go to QTY screen
   SET @nStep = @nStep - 2
   SET @nScn = @nScn - 2
END
GOTO Quit


/***********************************************************************************
Scn = 5463. Confirm screen
   CONFIRM ABORT?
   1=YES
   2=NO
   OPTION (field01, input)
***********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption  NVARCHAR(1)

      -- Screen mapping
      SET @cOption = @cInField01 -- Option

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 138756
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need option
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 138757
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         SET @cOutField01 = '' -- Option
         GOTO Quit
      END

      IF @cOption IN ('1', '2') -- YES
      BEGIN
         -- Event Log
         EXEC RDT.rdt_STD_EventLog
            @cActionType  = '3',
            @nMobileNo    = @nMobile,
            @nFunctionID  = @nFunc,
            @cFacility    = @cFacility,
            @cStorerKey   = @cStorerkey,
            @cSKU         = @cSKU, 
            @nExpectedQTY = @nExpQTY,
            @nQTY         = @nActQTY, 
            @cOption      = @cOption

         -- Prepare next screen var
         SET @cOutField01 = ''

         -- Go to QTY screen
         SET @nStep = @nStep - 3
         SET @nScn = @nScn - 3
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
         SET @cOutField04 = @cSize
         SET @cOutField05 = '' -- SKU
         SET @cOutField06 = CAST( @nExpQTY AS NVARCHAR(5)) -- EXP QTY
         SET @cOutField07 = CAST( @nActQTY AS NVARCHAR(5)) -- ACT QTY

         -- Go to SKU screen
         SET @nStep = @nStep - 2
         SET @nScn = @nScn - 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
      SET @cOutField04 = @cSize
      SET @cOutField05 = '' -- SKU
      SET @cOutField06 = CAST( @nExpQTY AS NVARCHAR(5)) -- EXP QTY
      SET @cOutField07 = CAST( @nActQTY AS NVARCHAR(5)) -- ACT QTY

      -- Go to SKU screen
      SET @nStep = @nStep - 2
      SET @nScn = @nScn - 2
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
      V_QTY      = @nActQTY,

      V_Integer1 = @nExpQTY,

      V_String1  = @cSize,
      V_String40 = @cBarcode,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  FieldAttr01 = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  FieldAttr02 = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  FieldAttr03 = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  FieldAttr04 = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  FieldAttr05 = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  FieldAttr06 = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  FieldAttr07 = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  FieldAttr08 = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  FieldAttr09 = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  FieldAttr10 = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  FieldAttr11 = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  FieldAttr12 = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  FieldAttr13 = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  FieldAttr14 = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  FieldAttr15 = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO