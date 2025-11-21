SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_UCCInquire                                   */
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Purpose: UCC Inquiry                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 16-Feb-2017 1.0  James    WMS1074 - Created                          */
/* 09-Oct-2018 1.1  Gan      Performance tuning                         */
/* 11-Sep-2023 1.2  James    WMS-23534 Add custom reference (james01)   */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_UCCInquire] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @nRowCnt        INT

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cUCC           NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @cSKUDescr      NVARCHAR( 60),
   @cUOM           NVARCHAR( 10),   -- Display NVARCHAR(3)
   @nQTY           NVARCHAR( 5),

   @cPackUOM       NVARCHAR( 10),
   @cPPK           NVARCHAR( 5),

   @cExtendedUCCInfoSP  NVARCHAR(20),
   @cSQL                NVARCHAR(MAX),
   @cSQLParam           NVARCHAR(MAX),
   @cExtInfo01          NVARCHAR(20),
   @cExtInfo02          NVARCHAR(20),
   @cExtInfo03          NVARCHAR(20),
   @cExtInfo04          NVARCHAR(20),
   @cExtInfo05          NVARCHAR(20),
   @cExtInfo06          NVARCHAR(20),
   @cExtInfo07          NVARCHAR(20),
   @cValidate           NVARCHAR( 10),
   @cTableName          NVARCHAR( 20),
   @cColumnName         NVARCHAR( 30),
   @cDataType           NVARCHAR( 128),
   @n_Err               INT,
   @nMultiSKU           INT = 0,
   @nRowCount           INT,
   
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

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
   @cUCC             = V_UCC,

   @cExtendedUCCInfoSP  = V_String1,

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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM rdt.rdtMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 729 -- UCC Inquire
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0   -- Menu. Func = 729
   IF @nStep = 1  GOTO Step_1   -- Scn = 4810. UCC, SKU, DESCR, QTY, extendedinfo...
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 729
********************************************************************************/
Step_0:
BEGIN
   SELECT
      @cOutField01   = '',
      @cOutField02   = '',
      @cOutField03   = '',
      @cOutField04   = '',
      @cOutField05   = '',
      @cOutField06   = '',
      @cOutField07   = '',
      @cOutField08   = '',
      @cOutField09   = '',
      @cOutField10   = '',
      @cOutField11   = '',
      @cOutField12   = '',
      @cOutField13   = '',
      @cOutField14   = '',
      @cOutField15   = '',
      @cUCC = ''

      SET @cExtendedUCCInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUCCInfoSP', @cStorerkey)
      IF @cExtendedUCCInfoSP IN ('0', '')
         SET @cExtendedUCCInfoSP = ''

      SET @nScn = 4810
      SET @nStep = 1

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep
END
GOTO Quit


/************************************************************************************
Step 1. Scn = 4810. UCC screen
   UCC            (field01)
   SKU            (field02)
   SKUDESC1       (field03)
   SKUDESC2       (field04)
   QTY            (field05)
   PPK            (field06)
   EXTENDEDINFO01 (field07)
   ...
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField01

      -- If UCC and SKU are blank
      IF ISNULL(@cUCC, '') = ''
      BEGIN
         SET @nErrNo = 106101
         SET @cErrMsg = rdt.rdtgetmessage( 106101, @cLangCode, 'DSP') --'UCC required'
         GOTO Step_1_Fail
      END

      SELECT @cValidate = Short
            ,@cTableName = Long
            ,@cColumnName = UDF01
      FROM dbo.CodeLkup WITH (NOLOCK)
      WHERE ListName = 'UCCINFO'
      AND Code = '1'
      AND StorerKey = @cStorerKey
      
      IF @cValidate = '1'
      BEGIN

         -- Get lookup field data type
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @cTableName AND COLUMN_NAME = @cColumnName
      
         IF @cDataType <> ''
         BEGIN
            IF @cDataType = 'nvarchar' SET @n_Err = 1                            ELSE
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cUCC)   ELSE 
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger( @cUCC)     ELSE 
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY( @cUCC, 20)
                           
            -- Check data type
            IF @n_Err = 0
            BEGIN
               SET @nErrNo = 106103
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo
               GOTO Quit
            END

            SET @cSQL = 
            ' SELECT TOP 1 @cSKU = SKU ' + 
            ' FROM dbo.' + @cTableName + ' WITH (NOLOCK) ' + 
            ' WHERE StorerKey = @cStorerKey ' + 
               CASE WHEN @cDataType IN ('int', 'float') 
                    THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cUCC ' 
                    ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cUCC ' 
               END + 
            ' ORDER BY 1 ' + 
            ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT ' 
         SET @cSQLParam =
            ' @nMobile      INT, ' + 
            ' @cStorerKey   NVARCHAR(15), ' +
            ' @cTableName   NVARCHAR(20), ' + 
            ' @cColumnName  NVARCHAR(30), ' +  
            ' @cUCC         NVARCHAR(20), ' + 
            ' @cSKU         NVARCHAR(20) OUTPUT, ' + 
            ' @nRowCount    INT          OUTPUT, ' + 
            ' @nErrNo       INT          OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
            @nMobile, 
            @cStorerKey, 
            @cTableName,
            @cColumnName, 
            @cUCC, 
            @cSKU        OUTPUT, 
            @nRowCount   OUTPUT, 
            @nErrNo      OUTPUT
         END
         ELSE
         BEGIN
            SET @nErrNo = 106104
            SET @cErrMsg = rdt.rdtgetmessage( 106104, @cLangCode, 'DSP') --'Invalid Setup'
            GOTO Step_1_Fail
         END
      END
      ELSE
      BEGIN
         SELECT
            @cSKU = SKU,
            @nQTY = Qty
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCC
         AND   StorerKey = @cStorerKey

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 106102
            SET @cErrMsg = rdt.rdtgetmessage( 106102, @cLangCode, 'DSP') --'Invalid UCC'
            GOTO Step_1_Fail
         END
         ELSE  --@@ROWCOUNT > 1
         BEGIN
            SELECT @nQTY = ISNULL( SUM( Qty), 0)
            FROM dbo.UCC WITH (NOLOCK)
            WHERE UCCNo = @cUCC
            AND   StorerKey = @cStorerKey

            SET @nMultiSKU = 1
         END
      END
      
      SELECT
         @cSKUDescr = SKU.Descr,
         @cPPK = CASE WHEN SKU.PrePackIndicator = '2'
                     THEN CAST( SKU.PackQtyIndicator AS NVARCHAR( 5))
                     ELSE '' END
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.PACK PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cSKU

      IF @cExtendedUCCInfoSP <> '' AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUCCInfoSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUCCInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cUCC, ' +
            ' @cExtInfo01 OUTPUT, @cExtInfo02 OUTPUT, @cExtInfo03 OUTPUT, @cExtInfo04 OUTPUT, ' +
            ' @cExtInfo05 OUTPUT, @cExtInfo06 OUTPUT, @cExtInfo07 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cStorerKey   NVARCHAR( 15), ' +
            '@cUCC         NVARCHAR( 20), ' +
            '@cExtInfo01   NVARCHAR( 20)  OUTPUT, ' +
            '@cExtInfo02   NVARCHAR( 20)  OUTPUT, ' +
            '@cExtInfo03   NVARCHAR( 20)  OUTPUT, ' +
            '@cExtInfo04   NVARCHAR( 20)  OUTPUT, ' +
            '@cExtInfo05   NVARCHAR( 20)  OUTPUT, ' +
            '@cExtInfo06   NVARCHAR( 20)  OUTPUT, ' +
            '@cExtInfo07   NVARCHAR( 20)  OUTPUT, ' +
            '@nErrNo       INT            OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cUCC,
            @cExtInfo01 OUTPUT, @cExtInfo02 OUTPUT, @cExtInfo03 OUTPUT, @cExtInfo04 OUTPUT,
            @cExtInfo05 OUTPUT, @cExtInfo06 OUTPUT, @cExtInfo07 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END


      IF @nMultiSKU = 0
      BEGIN
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      END
      ELSE
      BEGIN
         SET @cOutField02 = 'MULTI SKUs'
         SET @cOutField03 = ''
         SET @cOutField04 = ''
      END
      SET @cOutField05 = @nQty
      SET @cOutField06 = @cPPK
      SET @cOutField07 = @cExtInfo01
      SET @cOutField08 = @cExtInfo02
      SET @cOutField09 = @cExtInfo03
      SET @cOutField10 = @cExtInfo04
      SET @cOutField11 = @cExtInfo05
      SET @cOutField12 = @cExtInfo06
      SET @cOutField13 = @cExtInfo07

      SET @nMultiSKU = 0
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cUCC = ''

      -- Reset this screen var
      SET @cOutField01 = ''  -- UCC
      SET @cOutField02 = ''  -- SKU
      SET @cOutField03 = ''  -- SKU descr 1
      SET @cOutField04 = ''  -- SKU descr 2
      SET @cOutField05 = ''  -- QTY
      SET @cOutField06 = ''  -- PackUOM
      SET @cOutField07 = ''  -- PPK
      SET @cOutField08 = ''  -- Lottable1
      SET @cOutField09 = ''  -- Lottable2
      SET @cOutField10 = ''  -- Lottable3
      SET @cOutField11 = ''  -- Lottable4
      SET @cOutField12 = ''  -- Lottable5
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      UserName       = @cUserName,

      V_UCC          = @cUCC,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cUOM,
      V_QTY          = @nQTY,

      V_String1      = @cExtendedUCCInfoSP,

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15
   WHERE Mobile = @nMobile

END

GO