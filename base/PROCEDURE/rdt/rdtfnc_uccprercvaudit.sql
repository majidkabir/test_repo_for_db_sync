SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_UCCPreRCVAudit                                     */
/* Copyright      : LF Logistics                                              */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 02-06-2014 1.0  Ung        SOS313943 Created                               */
/* 26-10-2015 1.1  Ung        SOS355410 Misc enhancement                      */
/* 30-09-2016 1.2  Ung        Performance tuning                              */  
/* 05-10-2018 1.3  TungGH     Performance                                     */
/* 17-09-2021 1.4  Chermaine  WMS-17896 Add Userdefine config AND             */
/*                            Add checkSKUinUCC config (cc01)                 */
/******************************************************************************/
CREATE PROC [RDT].[rdtfnc_UCCPreRCVAudit] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @bSuccess         INT,
   @nCSKU            INT,
   @nPSKU            INT,
   @nCQTY            INT,
   @nPQTY            INT, 
   @nRowCount        INT, 
   @cOption          NVARCHAR(1)
   
-- rdt.rdtMobRec variable
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @nMenu            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,

   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cUserName        NVARCHAR( 18),
   @cPrinter         NVARCHAR( 10),

   @cSKU             NVARCHAR( 20),
   @cDesc            NVARCHAR( 60),
   @cUCC             NVARCHAR( 20), 
   @cReceiptKey      NVARCHAR( 10),

   @cUCCType         NVARCHAR( 10),
   @cSuggUCC         NVARCHAR( 20),
   @cStyle           NVARCHAR( 20),
   @cColor           NVARCHAR( 10),
   @cSize            NVARCHAR( 10),
   @cExternKey       NVARCHAR( 20), 
   @cUCCTypeCol      NVARCHAR( 20), --(cc01)
   @cUCCVarMarker    NVARCHAR( 20), --(cc01)
   @cSQL             NVARCHAR(MAX), --(cc01)
   @cSQLParam        NVARCHAR(MAX), --(cc01)
   @cCheckSKUInUcc   NVARCHAR( 1),  --(cc01)

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),    
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),    
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),    
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),    
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),    
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),    
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),    
   @cFieldAttr15 NVARCHAR( 1)    

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,
   @nInputKey        = InputKey,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cSKU             = V_SKU,
   @cDesc            = V_SKUDescr,
   @cUCC             = V_UCC, 
   @cReceiptKey      = V_ReceiptKey, 

   @cUCCType         = V_String1,
   @cSuggUCC         = V_String2,
   @cStyle           = V_String3,
   @cColor           = V_String4,
   @cSize            = V_String5,
   @cExternKey       = V_String6,
   @cUCCTypeCol      = V_String7, --(cc01)
   @cUCCVarMarker    = V_String8, --(cc01)
   @cCheckSKUInUcc   = V_String9, --(cc01)

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

   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,    
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,    
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,    
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,    
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,    
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,    
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,    
   @cFieldAttr15 =  FieldAttr15    

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc in (845)
BEGIN
   IF @nStep = 0 GOTO Step_0  -- Menu. Func = 845
   IF @nStep = 1 GOTO Step_1  -- Scn = 4370. UCC, close/reset UCC
   IF @nStep = 2 GOTO Step_2  -- Scn = 4371. Statistic
   IF @nStep = 3 GOTO Step_3  -- Scn = 4372. SKU
   IF @nStep = 4 GOTO Step_4  -- Scn = 4373. SuggUCC, UCC
   IF @nStep = 5 GOTO Step_5  -- Scn = 4374. Option. 1=Close, 2=Reset
   IF @nStep = 6 GOTO Step_6  -- Scn = 4375. Variance found, confirm?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 845
********************************************************************************/
Step_0:
BEGIN
	--get config
   SET @cUCCTypeCol = rdt.rdtGetConfig( @nFunc, 'UCCTypeCol', @cStorerKey) --(cc01)
   IF @cUCCTypeCol = '0'
      SET @cUCCTypeCol = 'UserDefined07'
   
   SET @cUCCVarMarker = rdt.rdtGetConfig( @nFunc, 'UCCVarMarker', @cStorerKey) --(cc01)
   IF @cUCCVarMarker = '0'
      SET @cUCCVarMarker = 'UserDefined08'
      
   SET @cCheckSKUInUcc = rdt.rdtGetConfig( @nFunc, 'CheckSKUInUcc', @cStorerKey) --(cc01)

   -- Go to next screen
   SET @nScn = 4370
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4370
   UCC             (field01, input)
   CLOSE/RESET UCC (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cUCC1 NVARCHAR(20)
      DECLARE @cUCC2 NVARCHAR(20)
      
      -- Screen mapping
      SET @cUCC1 = @cInField01 -- UCC
      SET @cUCC2 = @cInField02 -- Close/Reset UCC

      -- Check blank
      IF @cUCC1 = '' AND @cUCC2 = ''
      BEGIN
         SET @nErrNo = 88751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need UCC
         GOTO Step_1_Fail
      END
      
      -- Check key-in both
      IF @cUCC1 <> '' AND @cUCC2 <> ''
      BEGIN
         SET @nErrNo = 88752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Key either one
         GOTO Step_1_Fail
      END
      
      -- Get UCC info
      DECLARE @cUCCStatus NVARCHAR(1)
      SET @cUCCStatus = ''
      
      --SELECT TOP 1 
      --   @cUCCStatus = Status, 
      --   @cExternKey = ExternKey, 
      --   @cUCCType = LEFT( UserDefined07, 10) -- RDM or CIQ
      --FROM UCC WITH (NOLOCK) 
      --WHERE StorerKey = @cStorerKey 
      --   AND UCCNo = CASE WHEN @cUCC1 <> '' THEN @cUCC1 ELSE @cUCC2 END
      --ORDER BY UserDefined07 DESC

      --SET @nRowCount = @@ROWCOUNT
      --(cc01)
      SET @cSQL = 'SELECT TOP 1 ' +    
                              '@cUCCStatus = Status, ' +
                              '@cExternKey = ExternKey, ' +
                              '@cUCCType = LEFT(' + @cUCCTypeCol + ', 10) '+
                              'FROM UCC WITH (NOLOCK) ' +    
                              'WHERE StorerKey = @cStorerKey ' +    
                              'AND UCCNo = CASE WHEN @cUCC1 <> '''' THEN @cUCC1 ELSE @cUCC2 END ' +    
                              'ORDER BY ' + @cUCCTypeCol + ' DESC ' +
                              'SET @nRowCount = @@ROWCOUNT '     
                              
      SET @cSQLParam = N'@cUCCStatus   NVARCHAR( 10) OUTPUT, ' +    
                        '@cExternKey   NVARCHAR( 20) OUTPUT, ' +    
                        '@cUCCType     NVARCHAR( 10) OUTPUT, ' +    
                        '@cStorerKey   NVARCHAR( 10), ' +
                        '@cUCC1        NVARCHAR( 20), ' +
                        '@cUCC2        NVARCHAR( 20), ' +
                        '@nRowCount    INT   OUTPUT   '
                        
      EXEC sp_ExecuteSql @cSQL    
                        , @cSQLParam    
                        , @cUCCStatus  OUTPUT    
                        , @cExternKey  OUTPUT   
                        , @cUCCType    OUTPUT    
                        , @cStorerKey 
                        , @cUCC1
                        , @cUCC2 
                        , @nRowCount   OUTPUT  

      -- Check UCC
      IF @cUCC1 <> ''
      BEGIN
         -- Check UCC valid
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 88753
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid UCC
            GOTO Step_1_Fail
         END
   
         -- Check UCC status
         IF @cUCCStatus <> '0'
         BEGIN
            SET @nErrNo = 88754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC received
            GOTO Step_1_Fail
         END

         -- Check UCC type
         IF @cUCCType NOT IN ('RDM', 'CIQ')
         BEGIN
            SET @nErrNo = 88768
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC no RDM/CIQ
            GOTO Step_1_Fail
         END
   
         -- UCC checked
         IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK) WHERE OrgUCCNo = @cUCC1 AND StorerKey = @cStorerKey AND Status = '9')
         BEGIN
            SET @nErrNo = 88769
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC checked
            GOTO Step_1_Fail
         END
   
         -- Get receipt info
         SET @cReceiptKey = ''
         SELECT @cReceiptKey = ReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ExternReceiptKey = @cExternKey
   
         -- Check ASN
         IF @cReceiptKey = ''
         BEGIN
            SET @nErrNo = 88755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC NO ASN
            GOTO Step_1_Fail
         END

         SET @cUCC = @cUCC1

         -- Get statistic
         SELECT @nCSKU = 0, @nCQTY = 0, @nPSKU = 0, @nPQTY = 0
         EXECUTE rdt.rdt_UCCPreRCVAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cUCC, 
            @nCSKU = @nCSKU OUTPUT,
            @nCQTY = @nCQTY OUTPUT,
            @nPSKU = @nPSKU OUTPUT,
            @nPQTY = @nPQTY OUTPUT
   
         -- Prepare next screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = @cUCCType
         SET @cOutField03 = CAST( @nCSKU AS NVARCHAR( 10)) + '/' + CAST( @nPSKU AS NVARCHAR( 10))
         SET @cOutField04 = CAST( @nCQty AS NVARCHAR( 10)) + '/' + CAST( @nPQty AS NVARCHAR( 10))
   
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      -- Check close / reset UCC
      IF @cUCC2 <> ''
      BEGIN
         -- Check UCC valid
         IF NOT EXISTS( SELECT TOP 1 1 FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrgUCCNo = @cUCC2 AND Status = '0')
         BEGIN
            SET @nErrNo = 88756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC not exists
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- UCC2
            SET @cOutField02 = ''
            GOTO Quit
         END
         
         SET @cUCC = @cUCC2

         -- Prepare next screen var
         SET @cOutField01 = '' -- Option
   
         -- Go to close reset option screen
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4         
         
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- UCC1
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC1
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 4371. Statistic screen
   UCC      (field01)
   TYPE     (field02)
   CHK SKU  (field03)
   CHK QTY  (field04)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- SKU
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKU Desc1
      SET @cOutField04 = '' -- SKU Desc2
      SET @cOutField05 = '' -- Style
      SET @cOutField06 = '' -- Color Size
      SET @cOutField07 = '' -- QTYStat
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- UCC1
      SET @cOutField02 = '' -- UCC2

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC1
         
      -- Go to UCC screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 4372. SKU screen
   SKU/UPC    (field01, input)
   SKU        (field02)
   SKUDesc1   (field03)
   SKUDesc2   (field04)
   Style      (field05)
   Color Size (field06)
   QTYStat    (field07)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField01 -- SKU
      
      -- Check SKU blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 88757
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKU required
         GOTO Step_3_Fail
      END

      -- Check SKU valid
      EXEC dbo.nspg_GETSKU @cStorerKey, @cSKU OUTPUT, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @bSuccess = 0
      BEGIN
         SET @nErrNo = 88758
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid SKU
         GOTO Step_3_Fail
      END

      -- Check SKU in ASN
      IF NOT EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND SKU = @cSKU)
      BEGIN
         SET @nErrNo = 88759
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKU Not in ASN
         GOTO Step_3_Fail
      END
      
      --(cc01)
      IF @cCheckSKUInUcc = '1'
      BEGIN
      	IF NOT EXISTS( SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 88772
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKU Not in ASN
            GOTO Step_3_Fail
         END
      END

      -- Get SKU info
      SELECT 
         @cDesc = Descr, 
         @cStyle = Style, 
         @cColor = Color, 
         @cSize = Size
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Get suggest UCC
      IF @cUCCType = 'RDM'
      BEGIN
         -- Confirm
         EXEC rdt.rdt_UCCPreRCVAudit_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
            ,@cUCCType
            ,@cExternKey
            ,@cUCC
            ,@cUCC -- ActUCC
            ,@cSKU
            ,1 -- @nQTY
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Get statistic
         SET @nCQTY = 0
         EXECUTE rdt.rdt_UCCPreRCVAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cUCC, 
            @nCQTY = @nCQTY OUTPUT

         -- Prepare next screen var
         SET @cOutField01 = '' --SKU
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cDesc, 1, 20)
         SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
         SET @cOutField05 = @cStyle
         SET @cOutField06 = @cColor + @cSize
         SET @cOutField07 = CAST( @nCQTY AS NVARCHAR(5))
         
         -- Remain at current screen
         -- SET @nScn = @nScn + 1
         -- SET @nStep = @nStep + 1
      END
      
      IF @cUCCType = 'CIQ'
      BEGIN
         -- Get new UCC
         SET @cSuggUCC = ''
         SELECT TOP 1
            @cSuggUCC = NewUCCNo
         FROM rdtUCCPreRCVAuditLog WITH (NOLOCK) 
         WHERE OrgUCCNo = @cUCC
            AND StorerKey = @cStorerKey 
            AND SKU = @cSKU
            AND Status = '0' -- Open
         ORDER BY RowRef DESC

         -- Get statistic
         SET @nCQTY = 0
         EXECUTE rdt.rdt_UCCPreRCVAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cUCC, 
            @nCQTY = @nCQTY OUTPUT

         -- Prepare next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cDesc, 1, 20)
         SET @cOutField03 = SUBSTRING( @cDesc, 21, 20)
         SET @cOutField04 = @cStyle
         SET @cOutField05 = @cColor + @cSize
         SET @cOutField06 = CAST( @nCQTY AS NVARCHAR(5))
         SET @cOutField07 = @cSuggUCC
         SET @cOutField08 = '' -- New UCC
         
         -- Go to new UCC screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get statistic
      SELECT @nCSKU = 0, @nCQTY = 0, @nPSKU = 0, @nPQTY = 0
      EXECUTE rdt.rdt_UCCPreRCVAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cUCC, 
         @nCSKU = @nCSKU OUTPUT,
         @nCQTY = @nCQTY OUTPUT,
         @nPSKU = @nPSKU OUTPUT,
         @nPQTY = @nPQTY OUTPUT

      -- Prepare next screen var
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cUCCType
      SET @cOutField03 = CAST( @nCSKU AS NVARCHAR( 10)) + '/' + CAST( @nPSKU AS NVARCHAR( 10))
      SET @cOutField04 = CAST( @nCQty AS NVARCHAR( 10)) + '/' + CAST( @nPQty AS NVARCHAR( 10))

      -- Go to statistic screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit                         
                                     
   Step_3_Fail:                      
      SET @cOutField01 = '' -- SKU

END
GOTO Quit

      
/********************************************************************************
Step 4. Scn = 4373. New UCC screen
   SKU        (field01)
   SKUDesc1   (field02)
   SKUDesc2   (field03)
   Style      (field04)
   Color Size (field05)
   QTYStat    (field06)
   Sugg UCC   (field07)
   UCC        (field08, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cActUCC NVARCHAR(20)
      
      -- Screen mapping
      SET @cActUCC = @cInField08 -- UCC
      
      -- Check UCC blank
      IF @cActUCC = ''
      BEGIN
         SET @nErrNo = 88760
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need UCC
         GOTO Step_4_Fail
      END      

      -- Check new UCC format
      IF LEFT( @cActUCC, 2) <> 'VF' OR LEN( @cActUCC) <> 10
      BEGIN
         SET @nErrNo = 88761
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         GOTO Step_4_Fail
      END

      -- Check if scanned original UCC
      IF EXISTS( SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cActUCC AND SourceType <> 'UCCPreRCVAudit')
      BEGIN
         SET @nErrNo = 88765
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need new UCC 
         GOTO Step_4_Fail
      END
      
      -- Get SKU CIQ/non-CIQ in original UCC
      DECLARE @cSKUType NVARCHAR(10)
      SET @cSKUType = ''
      SELECT @cSKUType = UserDefined07
      FROM UCC WITH (NOLOCK)
      WHERE UCCNo = @cUCC
         AND StorerKey = @cStorerKey 
         AND SKU = @cSKU
      
      -- Get SKU CIQ/non-CIQ in new UCC
      DECLARE @cChkSKUType NVARCHAR(10)
      SET @cChkSKUType = ''
      SELECT TOP 1 
         @cChkSKUType = UserDefined07
      FROM rdt.rdtUCCPreRCVAuditLog L WITH (NOLOCK)
         JOIN UCC WITH (NOLOCK) ON (L.OrgUCCNo = UCC.UCCNo AND UCC.StorerKey = L.StorerKey AND UCC.SKU = L.SKU)
      WHERE L.NewUCCNo = @cActUCC
         AND L.StorerKey = @cStorerKey 
      
      -- Check mix CIQ and normal
      IF @@ROWCOUNT <> 0 AND @cChkSKUType <> @cSKUType 
      BEGIN
         SET @nErrNo = 88770
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix CIQ/NotCIQ
         GOTO Step_4_Fail
      END         

      -- Get Act UCC info
      DECLARE @cChkExternKey NVARCHAR(20)
      SET @cChkExternKey = ''
      SELECT @cChkExternKey = ExternKey
      FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND NewUCCNo = @cActUCC
      
      -- Check ExternKey different
      IF @cChkExternKey <> '' AND @cChkExternKey <> @cExternKey
      BEGIN
         SET @nErrNo = 88762
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCC diff PO
         GOTO Step_4_Fail
      END
   
      -- Confirm
      EXEC rdt.rdt_UCCPreRCVAudit_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
         ,@cUCCType
         ,@cExternKey
         ,@cUCC
         ,@cActUCC
         ,@cSKU
         ,1 -- @nQTY
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Get statistic
      SET @nCQTY = 0
      EXECUTE rdt.rdt_UCCPreRCVAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cUCC, 
         @nCQTY = @nCQTY OUTPUT
         
      -- Go back SKU screen
      SET @cOutField01 = '' --SKU
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDesc, 1, 20)
      SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
      SET @cOutField05 = @cStyle
      SET @cOutField06 = @cColor + @cSize
      SET @cOutField07 = CAST( @nCQTY AS NVARCHAR(5))

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go back SKU screen
      SET @cOutField01 = '' --SKU
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKU Desc1
      SET @cOutField04 = '' -- SKU Desc2
      SET @cOutField05 = '' -- Style
      SET @cOutField06 = '' -- Color Size
      SET @cOutField07 = '' -- QTYStat
      
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
   
   Step_4_Fail:
      SET @cOutField08 = '' -- ActUCC
END
GOTO Quit


/********************************************************************************
Step 5. Screen = 4374 Close / reset UCC?
   CLOSE OR RESET UCC?
   1 = CLOSE
   2 = RESET
   OPTION: (field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 88763
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
	   BEGIN
	      SET @nErrNo = 88764
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
         GOTO Quit
      END

      -- Close UCC
      IF @cOption = '1'
      BEGIN
         -- Get statistic
         DECLARE @nVariance INT
         SELECT @nVariance = 0
         EXECUTE rdt.rdt_UCCPreRCVAudit_GetStat @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerKey, @cUCC, 
            @nVariance = @nVariance OUTPUT

         -- Check if variance
         IF @nVariance = 1
         BEGIN
            -- Prepare next screen
            SET @cOutField01 = '' -- Option
               
            -- Go to variance screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            
            GOTO Quit
         END

         -- Close UCC
         EXEC rdt.rdt_UCCPreRCVAudit_Close @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, 
            @cUCC, 
            @cUCCType, 
            0, -- Variance
            @nErrNo OUTPUT, 
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
      
      -- Reset UCC
      IF @cOption = '2'
      BEGIN
         -- Reset UCC
         EXEC rdt.rdt_UCCPreRCVAudit_Reset @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cUCC, @nErrNo OUTPUT, @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   -- Go back UCC screen
   SET @cOutField01 = '' --UCC1
   SET @cOutField02 = '' --UCC2

   -- Go to UCC screen
   SET @nScn = @nScn - 4
   SET @nStep = @nStep - 4

   GOTO Quit
   
   Step_5_Fail:
   BEGIN
      SET @cOutField01 = '' --option
   END
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 4375 Variance found, close UCC?
   VARIANCE FOUND
   CLOSE UCC?
   1 = YES
   2 = NO
   OPTION: (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01
      
      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 88766
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option required
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
	   BEGIN
	      SET @nErrNo = 88767
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
         GOTO Quit
      END

      -- Close UCC
      IF @cOption = '1'
      BEGIN
      	--(cc01)
      	DECLARE @nExists  INT 
      	SET @nExists = 0
         -- Check supervisor had confirm the variance (UserDefined08 = Y)
         SET @cSQL = 'SELECT @nExists = 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCC AND ' + @cUCCVarMarker + ' <> ''Y'' '
                              
         SET @cSQLParam = N'@nExists INT OUTPUT,'+
                           '@cStorerKey NVARCHAR(15), ' +    
                           '@cUCC NVARCHAR(30) ' 
                        
         EXEC sp_ExecuteSql @cSQL    
                           , @cSQLParam    
                           , @nExists  OUTPUT    
                           , @cStorerKey   
                           , @cUCC
                  
         --IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCC AND UserDefined08 <> 'Y')
         IF @nExists = 1
   	   BEGIN
   	      SET @nErrNo = 88771
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DiffNotConfirm
            GOTO Quit
         END
         
         -- Close UCC
         EXEC rdt.rdt_UCCPreRCVAudit_Close @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, 
            @cUCC, 
            @cUCCType, 
            1, -- Variance
            @nErrNo OUTPUT, 
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
            
         -- Go back UCC screen
         SET @cOutField01 = '' -- UCC1
         SET @cOutField02 = '' -- UCC2
      
         -- Go to UCC screen
         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5
         
         GOTO Quit
      END
   END      

   -- Go back close reset screen
   SET @cOutField01 = '' -- Option

   -- Go to close/reset screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1
      
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

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      Printer   = @cPrinter,
      -- UserName  = @cUserName,

      V_SKU        = @cSKU,
      V_SKUDescr   = @cDesc,
      V_UCC        = @cUCC, 
      V_ReceiptKey = @cReceiptKey, 

      V_String1 = @cUCCType,
      V_String2 = @cSuggUCC,
      V_String3 = @cStyle,
      V_String4 = @cColor,
      V_String5 = @cSize,
      V_String6 = @cExternKey,
      V_String7 = @cUCCTypeCol,
      V_String8 = @cUCCVarMarker,
      V_String9 = @cCheckSKUInUcc,
      
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