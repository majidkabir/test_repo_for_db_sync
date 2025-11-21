SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_BOMInquiry                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: BOM Inquiry (SOS183270)                                     */
/*                                                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 02-Aug-2010 1.0  James    Created                                    */
/* 09-Aug-2010 1.1  ChewKP   CR (ChewKP01)                              */
/* 30-Sep-2016 1.2  Ung      Performance tuning                         */
/* 30-Oct-2018 1.3  TungGH   Performance                                */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_BOMInquiry] (
   @nMobile    INT,
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF

-- Misc variables
DECLARE
   @b_success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250)
                      
-- RDT.RDTMobRec variables
DECLARE              
   @nFunc             INT,
   @nScn              INT,
   @nStep             INT,
   @cLangCode         NVARCHAR( 3),
   @nInputKey         INT,
   @nMenu             INT,
                     
   @cStorerKey        NVARCHAR( 15),
   @cUserName         NVARCHAR( 18),
   @cFacility         NVARCHAR( 5),
   @cSKU              NVARCHAR( 20),
   @cBOM              NVARCHAR( 20),

   @nCounter          INT,
   @nSequence         INT,
   @nComponentSKU_CNT INT,
   @nComponentQty     INT,
   @nCaseCnt          INT,
   @nQTY              INT,
   @cStyle            NVARCHAR( 20),           
   @cColor            NVARCHAR( 10),   
   @cSize             NVARCHAR( 5), 
   @cMeasurement      NVARCHAR( 5), 
   @cComponentSKU     NVARCHAR( 20),
   @nInnerPackQty     INT, -- (ChewKP01)
   @cUPC              NVARCHAR(30), -- (ChewKP01)

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

   -- (Vicky02) - Start
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)
   -- (Vicky02) - End

-- Getting Mobile information
SELECT
   @nFunc             = Func,
   @nScn              = Scn,
   @nStep             = Step,
   @nInputKey         = InputKey,
   @nMenu             = Menu,
   @cLangCode         = Lang_code,

   @cStorerKey        = StorerKey,
   @cFacility         = Facility,
   @cUserName         = UserName,
   @cSKU              = V_SKU,
   
   @nQTY              = V_QTY,
   
   @nSequence         = V_Integer1,
   @nComponentSKU_CNT = V_Integer2,
   @nCounter          = V_Integer3,

   @cBOM              = V_String1,

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_BOM                      INT,  @nScn_BOM                      INT,
   @nStep_BOMDetails               INT,  @nScn_BOMDetails               INT, 
   @nStep_ComponentSKU             INT,  @nScn_ComponentSKU             INT

SELECT
   @nStep_BOM                    = 1,  @nScn_BOM                = 2500,
   @nStep_BOMDetails             = 2,  @nScn_BOMDetails         = 2501, 
   @nStep_ComponentSKU           = 3,  @nScn_ComponentSKU       = 2502

IF @nFunc = 559 -- RDT BOM Cycle Count
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start              -- Menu. Func = 559
   IF @nStep = 1  GOTO Step_BOM                -- Scn = 2500. BOM
   IF @nStep = 2  GOTO Step_BOMDetails         -- Scn = 2501. BOM Details
   IF @nStep = 3  GOTO Step_ComponentSKU       -- Scn = 2502. ComponentSKU Details
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 559. Screen 0.
********************************************************************************/
Step_Start:
BEGIN

   SET @cOutField01   = ''

   SET @cBOM = ''

   SET @nScn = @nScn_BOM   -- 2500
   SET @nStep = @nStep_BOM -- 1
END
GOTO Quit

/************************************************************************************
Step_CCRef. Scn = 2500. Screen 1.
   BOM (field01)   - Input field
************************************************************************************/
Step_BOM:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUPC = @cInField01

      -- Validate BOM
      IF @cUPC = '' OR @cUPC IS NULL
      BEGIN
         SET @nErrNo = 70641
         SET @cErrMsg = rdt.rdtgetmessage( 70641, @cLangCode, 'DSP') -- 'BOM required'
         GOTO BOM_Fail
      END
      
      -- (ChewKP01)
      SELECT @cStorerkey = Storerkey, @cBOM = SKU FROM dbo.UPC WITH (NOLOCK)
      WHERE UPC = @cUPC
      
      IF ISNULL(@cBOM,'') = ''
      BEGIN
         SET @cBOM = @cUPC
      END
            
      -- Check if BOM has > 1 Component SKU
      SELECT @nComponentSKU_CNT = ISNULL(COUNT(1), 0) 
      FROM dbo.BillOfMaterial WITH (NOLOCK)
      WHERE SKU = @cBOM
         AND StorerKey = @cStorerKey

      IF @nComponentSKU_CNT <= 0
      BEGIN
         SET @nErrNo = 70642
         SET @cErrMsg = rdt.rdtgetmessage( 70642, @cLangCode, 'DSP') -- 'Invalid BOM'
         GOTO BOM_Fail
      END

      -- If BOM got only 1 Component SKU
      IF @nComponentSKU_CNT = 1
      BEGIN
         SELECT @cSKU = SKU.SKU,
                @cStyle = SKU.Style,
                @cColor = SKU.Color,
                @cSize = SKU.Size,
                @cMeasurement = SKU.Measurement,
                @nComponentQty = BOM.Qty 
         FROM dbo.SKU SKU WITH (NOLOCK) 
         JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (SKU.StorerKey = BOM.StorerKey AND SKU.SKU = BOM.ComponentSKU)
         WHERE BOM.SKU = @cBOM
            AND BOM.StorerKey = @cStorerKey

         -- Prepare next screen var
         SET @cOutField01 = '1/1'
         SET @cOutField02 = @cBOM
         SET @cOutField03 = @cStyle
         SET @cOutField04 = @cColor
         SET @cOutField05 = @cSize + '/' + @cMeasurement
         SET @cOutField06 = @cSKU
         SET @cOutField07 = @nComponentQty

         SET @nScn = @nScn_ComponentSKU   -- 2502
         SET @nStep = @nStep_ComponentSKU -- 3

         GOTO Quit
      END

      IF @nComponentSKU_CNT > 1
      BEGIN
         SELECT @cStyle = SKU.Style,
                @cColor = SKU.Color 
         FROM dbo.SKU SKU WITH (NOLOCK) 
         JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (SKU.StorerKey = BOM.StorerKey AND SKU.SKU = BOM.SKU)
         WHERE BOM.SKU = @cBOM
            AND BOM.StorerKey = @cStorerKey

         SELECT @nCaseCnt = Pack.CaseCnt, 
                @nQty = Pack.Qty 
         FROM dbo.Pack Pack WITH (NOLOCK) 
         JOIN dbo.UPC UPC WITH (NOLOCK) ON (Pack.PackKey = UPC.PackKey)
         JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (UPC.StorerKey = BOM.StorerKey AND UPC.SKU = BOM.SKU)
         WHERE BOM.SKU = @cBOM
            AND BOM.StorerKey = @cStorerKey
            AND UPC.UOM = 'CS'
            
        -- (ChewKP01)
         SELECT @nInnerPackQty = Pack.InnerPack
         FROM dbo.Pack Pack WITH (NOLOCK) 
         JOIN dbo.UPC UPC WITH (NOLOCK) ON (Pack.PackKey = UPC.PackKey)
         JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (UPC.StorerKey = BOM.StorerKey AND UPC.SKU = BOM.SKU)
         WHERE BOM.SKU = @cBOM
            AND BOM.StorerKey = @cStorerKey
            AND UPC.UOM = 'IP'    

         -- Prepare next screen var
         SET @cOutField01 = @cBOM
         SET @cOutField02 = @cStyle
         SET @cOutField03 = @cColor
         SET @cOutField04 = @nComponentSKU_CNT
         SET @cOutField05 = CAST(@nCaseCnt AS NVARCHAR(5)) + CAST(@nInnerPackQty AS NVARCHAR(5)) -- (ChewKP01)

         SET @nScn = @nScn_BOMDetails   -- 2501
         SET @nStep = @nStep_BOMDetails -- 2

         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- BOM

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
   END
   GOTO Quit

   BOM_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- CCREF
   END
END
GOTO Quit

/************************************************************************************
Step_BOMDetails. Scn = 2501. Screen 2.
   BOM            (field01)
   STYLE          (field02)   
   COLOUR         (field03)   
   # Of Component (field04)   
   CS IN          (field05)   
************************************************************************************/
Step_BOMDetails:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN

      SELECT TOP 1 
             @cSKU = SKU.SKU,
             @cStyle = SKU.Style,
             @cColor = SKU.Color,
             @cSize = SKU.Size,
             @cMeasurement = SKU.Measurement,
             @nSequence = BOM.Sequence,
             @nComponentQty = BOM.Qty 
      FROM dbo.SKU SKU WITH (NOLOCK) 
      JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (SKU.StorerKey = BOM.StorerKey AND SKU.SKU = BOM.ComponentSKU)
      WHERE BOM.SKU = @cBOM
         AND BOM.StorerKey = @cStorerKey
      ORDER BY Sequence

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 70643
         SET @cErrMsg = rdt.rdtgetmessage( 70643, @cLangCode, 'DSP') -- 'No More REC'
         GOTO Quit
      END

      SET @nCounter = 1

      -- Prepare next screen var
      SET @cOutField01 = RTRIM(CAST(@nCounter AS NVARCHAR(2))) + '/' + CAST(@nComponentSKU_CNT AS NVARCHAR(2))
      SET @cOutField02 = @cBOM
      SET @cOutField03 = @cStyle
      SET @cOutField04 = @cColor
      SET @cOutField05 = @cSize + '/' + @cMeasurement
      SET @cOutField06 = @cSKU
      SET @cOutField07 = @nComponentQty

      SET @nScn = @nScn_ComponentSKU   -- 2502
      SET @nStep = @nStep_ComponentSKU -- 3

      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset screen var
      SET @cOutField01 = '' -- BOM
      SET @cBOM = ''

      -- Back to previous screen
      SET @nScn = @nScn_BOM
      SET @nStep = @nStep_BOM
   END
END
GOTO Quit

/************************************************************************************
Step_ComponentSKU. Scn = 2502. Screen 3.
   BOM           (field01)
   STYLE         (field02)
   COLOUR        (field03)
   SIZE/MEAS     (field04)
   SKU           (field05)
   QTY           (field06)
************************************************************************************/
Step_ComponentSKU:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SELECT TOP 1 @cSKU = SKU.SKU, -- (ChewKP01)
             @cStyle = SKU.Style,
             @cColor = SKU.Color,
             @cSize = SKU.Size,
             @cMeasurement = SKU.Measurement,
             @nSequence = BOM.Sequence,
             @nComponentQty = BOM.Qty 
      FROM dbo.SKU SKU WITH (NOLOCK) 
      JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (SKU.StorerKey = BOM.StorerKey AND SKU.SKU = BOM.ComponentSKU)
      WHERE BOM.SKU = @cBOM
         AND BOM.StorerKey = @cStorerKey
         AND Sequence > @nSequence
      ORDER By Sequence

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 70644
         SET @cErrMsg = rdt.rdtgetmessage( 70644, @cLangCode, 'DSP') -- 'No More REC'
         GOTO Quit
      END

      SET @nCounter = @nCounter + 1

      -- Prepare next screen var
      SET @cOutField01 = CAST(@nCounter AS NVARCHAR(2)) + '/' + CAST(@nComponentSKU_CNT AS NVARCHAR(2))
      SET @cOutField02 = @cBOM
      SET @cOutField03 = @cStyle
      SET @cOutField04 = @cColor
      SET @cOutField05 = @cSize + '/' + @cMeasurement
      SET @cOutField06 = @cSKU
      SET @cOutField07 = @nComponentQty

      SET @nScn = @nScn_ComponentSKU   -- 2502
      SET @nStep = @nStep_ComponentSKU -- 3

      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Reset screen var
      SET @cOutField01 = '' -- BOM
      SET @cBOM = ''

      -- Back to previous screen
      SET @nScn = @nScn_BOM
      SET @nStep = @nStep_BOM
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate       = GETDATE(), 
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      V_SKU          = @cSKU,

      V_String1      = @cBOM,
      
      V_Integer1     = @nSequence,
      V_Integer2     = @nComponentSKU_CNT,
      V_Integer3     = @nCounter,

      I_Field01 = '',  O_Field01 = @cOutField01,
      I_Field02 = '',  O_Field02 = @cOutField02,
      I_Field03 = '',  O_Field03 = @cOutField03,
      I_Field04 = '',  O_Field04 = @cOutField04,
      I_Field05 = '',  O_Field05 = @cOutField05,
      I_Field06 = '',  O_Field06 = @cOutField06,
      I_Field07 = '',  O_Field07 = @cOutField07,
      I_Field08 = '',  O_Field08 = @cOutField08,
      I_Field09 = '',  O_Field09 = @cOutField09,
      I_Field10 = '',  O_Field10 = @cOutField10,
      I_Field11 = '',  O_Field11 = @cOutField11,
      I_Field12 = '',  O_Field12 = @cOutField12,
      I_Field13 = '',  O_Field13 = @cOutField13,
      I_Field14 = '',  O_Field14 = @cOutField14,
      I_Field15 = '',  O_Field15 = @cOutField15,

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