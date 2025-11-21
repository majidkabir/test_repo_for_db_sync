SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Data Capture #9                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-11-24 1.1  YeeKung		WMS3494. Created                          */
/* 2018-10-04 1.2  TungGH		Performance                               */
/* 2018-11-26 1.3  SPChin     INC0483327 - Extend The Length Of @cUCC   */
/* 2018-12-03 1.4  James      WMS7168-Add SKU & Qty capture(james01)    */
/*                            Add ExtendedValidateSP                    */
/*                            Add DataCaptureIDIsMandatory              */
/* 2019-03-27 1.5  James      INC0639478 Trim Qty field (james02)       */
/* 2019-03-28 1.6  James      Add extra param to var table (james03)    */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DataCapture9] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

-- Misc variable
DECLARE 
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT
-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5), 
   @cPrinter   NVARCHAR( 10),

   @b_success  INT,
   @n_err      INT,     
   @c_errmsg   NVARCHAR( 250), 

   @cLOC       NVARCHAR( 10),
   @cQTY       NVARCHAR (5),   
   @cUCC       NVARCHAR(20), 
   @cSerialNo  NVARCHAR(30),  --INC0483327
   @nScan		INT,
   @cID			NVARCHAR(20), --scan id
   @cSKU       NVARCHAR( 20),
   @nQty       INT,
   @nSKUCnt    INT,
   @bSuccess   INT,
   @cSQL       NVARCHAR(4000),   
   @cSQLParam  NVARCHAR(4000),   
   @cDuplicateUCC    NVARCHAR( 1),
   @cExtendedValidateSP NVARCHAR(20),
   @cIDIsMandatory   NVARCHAR( 1),
   @cSKUIsMandatory  NVARCHAR( 1),
   @cQtyIsMandatory  NVARCHAR( 1),
   @tVar           VariableTable,

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
   @cPrinter   = Printer, 


   @cLOC       = V_LOC,
   @cID        = V_ID, 
   @cSKU       = V_SKU,
   @nQty       = V_Qty,
   

   @cExtendedValidateSP = V_String1,
   @cQty                = V_String2,
   @cSerialNo           = V_String3,
   @cIDIsMandatory      = V_String4,
   @cSKUIsMandatory     = V_String5,
   @cQtyIsMandatory     = V_String6,
   @cDuplicateUCC = V_String8,

   @nScan      = V_Integer1,
   
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

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 625   -- Data capture #9
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Data Capture
   IF @nStep = 1 GOTO Step_1   -- Scn = 5070. LOC,ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 5071. LOC, UCC, SKU/UPC, Qty, counter
END

/********************************************************************************
Step 0. func = 625. Menu
********************************************************************************/

Step_0:
BEGIN
   SET @cDuplicateUCC = ''
   SET @cDuplicateUCC = rdt.RDTGetConfig(@nFunc, 'CheckDuplicateUCC', @cStorerkey)

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cIDIsMandatory = ''
   SET @cIDIsMandatory = rdt.RDTGetConfig(@nFunc, 'DataCaptureIDIsMandatory', @cStorerkey)

   SET @cSKUIsMandatory = ''
   SET @cSKUIsMandatory = rdt.RDTGetConfig(@nFunc, 'DataCaptureSKUIsMandatory', @cStorerkey)

   SET @cQtyIsMandatory = ''
   SET @cQtyIsMandatory = rdt.RDTGetConfig(@nFunc, 'DataCaptureQtyIsMandatory', @cStorerkey)

	--Set the entry point
	SET @nScn  = 5070
	SET @nStep = 1

	-- Initiate var
	SET @cLOC = ''
	SET @cUCC = ''
	SET @cID  = ''
	SET @nScan = 0

	--Initial Screen
	SET @cOutField01 =''--Loc
	SET @cOutField02 =''--counter
	
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 5070. LOC
   LOC      (field01, input)
   ID:		(field02, input)
********************************************************************************/

Step_1:
BEGIN
	IF @nInputKey = 1 --ENTER
	BEGIN
      --Screen Mapping
      SET @cLOC = @cInField01
      SET @cID = @cInField02
   
      --Validate Blank
      IF @cLOC ='' OR @cLOC IS NULL
      BEGIN
			SET @nErrNo = 117151
			SET @cErrMsg = rdt.rdtgetmessage(@nErrNo,@cLangCode,'DSP')
			EXEC rdt.rdtSetFocusField @nMobile, 1
			GOTO Quit
      END

		-- Get LOC info
		DECLARE @cChkFacility NVARCHAR( 5)
		SELECT @cChkFacility = Facility
		FROM dbo.LOC WITH (NOLOCK)
		WHERE LOC = @cLOC
		
		-- Validate LOC
		IF @@ROWCOUNT = 0
		BEGIN
			SET @cLOC = ''
			SET @nErrNo = 117152
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         SET @cOutField01 = ''
			EXEC rdt.rdtSetFocusField @nMobile, 1
			GOTO Quit
		END
		
		--Validate Loc's Facility
		IF @cChkFacility <> @cFacility 
		BEGIN
			SET @cLOC = ''
			SET @nErrNo = 117153
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         SET @cOutField01 = ''
			EXEC rdt.rdtSetFocusField @nMobile, 1
			GOTO Quit
		END

      IF ISNULL( @cID, '') = ''
		   AND EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC AND LoseID = 0)
		BEGIN
         IF @cIDIsMandatory = '1'
         BEGIN
            SET @cOutField01 = @cLOC
			   SET @nErrNo = 117154
			   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ID Needed'
			   EXEC rdt.rdtSetFocusField @nMobile, 2
			   GOTO Quit
         END
		END

		--validate id follow the format or not null
		IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0  
		BEGIN
			SET @cID = ''
			SET @nErrNo = 117155
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ID Req'
         SET @cOutField02 = ''
			EXEC rdt.rdtSetFocusField @nMobile, 2
			GOTO Quit
      END
      
      SET @nScan = '0'
      SET @cUCC = ''
      SET @cSKU = ''
      SET @cQty = ''

      -- Prepare next screen var
      SET @cOutField01 = @cLOC --loc
      SET @cOutField02 = @cID --ID
      SET @cOutField03 = ''--UCC
      SET @cOutField04 = ''--SKU
      SET @cOutField05 = ''--Qty
      SET @cOutField13 = @nScan --scan counter
      EXEC rdt.rdtSetFocusField @nMobile, 3 --UCC
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

	END

	IF @nInputKey = 0 --ESC 
   BEGIN
    --go to main menu
    SET @nFunc = @nMenu
    SET @nScn  = @nMenu
    SET @nStep = 0
    SET @cOutField01 = '' --loc
    SET @cOutField02 = '' --id
   END
   GOTO Quit

END
GOTO Quit

/********************************************************************************
Step 2. Scn = 5071. 
   LOC      (field01)
   ID       (field02)
   UCC      (field03, input)
   SKU/UPC  (field04, input)
   QTY      (field05, input)
   SCAN     (field13)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --screen mapping
      SET @cUCC = @cInField03
      SET @cSKU = @cInField04
      SET @cQty = @cInField05

      -- Check UCC
      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 117156
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Need UCC
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit  
      END
      
      --check ucc is valid format or not and not null
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UCC', @cInField03) = 0  
      BEGIN
         SET @cUCC = ''
         SET @nErrNo = 117157
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Format is required'
         SET @cOutField03 = ''
         SET @cOutField04 = @cInField04
         SET @cOutField05 = @cInField05
         EXEC rdt.rdtSetFocusField @nMobile, 3 
         GOTO Quit
      END
      
      IF @cDuplicateUCC = '1'
      BEGIN
         IF EXISTS (SELECT * FROM rdt.rdtDataCapture WITH (NOLOCK) WHERE serialno=@cUCC)
         BEGIN
            SET @cUCC = ''
            SET @nErrNo = 117158
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Duplicate UCC'
            SET @cOutField03 = ''
            SET @cOutField04 = @cInField04
            SET @cOutField05 = @cInField05
            EXEC rdt.rdtSetFocusField @nMobile, 3 
            GOTO Quit
         END
      END
      
      IF @cSKUIsMandatory = '1'
      BEGIN
         IF ISNULL( @cSKU, '') <> ''
         BEGIN
            -- Get SKU/UPC
            SET @nSKUCnt = 0

            EXEC RDT.rdt_GETSKUCNT
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cSKU
               ,@nSKUCnt     = @nSKUCnt       OUTPUT
               ,@bSuccess    = @bSuccess      OUTPUT
               ,@nErr        = @nErrNo        OUTPUT
               ,@cErrMsg     = @cErrMsg       OUTPUT

            -- Validate SKU/UPC
            IF @nSKUCnt = 0
            BEGIN
               SET @cSKU = ''
               SET @nErrNo = 117159
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- Invalid SKU
               SET @cOutField03 = @cInField03
               SET @cOutField04 = ''
               SET @cOutField05 = @cInField05
               EXEC rdt.rdtSetFocusField @nMobile, 4 
               GOTO Quit
            END

            IF @nSKUCnt = 1
               EXEC [RDT].[rdt_GETSKU]
                   @cStorerKey  = @cStorerKey
                  ,@cSKU        = @cSKU          OUTPUT
                  ,@bSuccess    = @b_Success     OUTPUT
                  ,@nErr        = @nErrNo        OUTPUT
                  ,@cErrMsg     = @cErrMsg       OUTPUT
      
            -- Validate barcode return multiple SKU
            IF @nSKUCnt > 1
            BEGIN
               SET @cSKU = ''
               SET @nErrNo = 117160
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- SameBarcodeSKU
               SET @cOutField03 = @cInField03
               SET @cOutField04 = ''
               SET @cOutField05 = @cInField05
               EXEC rdt.rdtSetFocusField @nMobile, 4 
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @cOutField03 = @cInField03
            SET @cOutField04 = @cInField04
            SET @cOutField05 = @cInField05
            EXEC rdt.rdtSetFocusField @nMobile, 4 
            GOTO Quit
         END
      END

      IF @cQtyIsMandatory = '1'
      BEGIN
         -- (james02) barcode may contain space in front or back 
         -- example ' 6'. RDTFormat will return error
         SET @cQty = RTRIM( LTRIM( @cQty))

         IF RDT.rdtIsValidQTY( @cQty, 1) = 0 AND ISNULL( @cQty, '') <> ''
         BEGIN
            SET @cQty = ''
            SET @nErrNo = 117161
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- Invalid Qty
            SET @cOutField03 = @cInField03
            SET @cOutField04 = @cInField04
            SET @cOutField05 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 5 
            GOTO Quit
         END

         --check ucc is valid format or not and not null
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'QTY', @cQty) = 0  
            AND ISNULL( @cQty, '') <> ''
         BEGIN
            SET @cUCC = ''
            SET @nErrNo = 117162
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Qty'
            SET @cOutField03 = @cInField03
            SET @cOutField04 = @cInField04
            SET @cOutField05 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 5 
            GOTO Quit
         END
      
         SET @nQty = CAST( @cQty AS INT)
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES 
               ('@cLOC',         @cLOC), 
               ('@cID',          @cID), 
               ('@cUCC',         @cUCC), 
               ('@cSKU',         @cSKU), 
               ('@cQty',         @cQty),
               ('@cInField03',   @cInField03),  -- (james03)
               ('@cInField04',   @cInField04),
               ('@cInField05',   @cInField05)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' + 
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tVar           VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cOutField03 = @cInField03
               SET @cOutField04 = @cInField04
               SET @cOutField05 = @cInField05
               GOTO Quit            
            END
         END
      END

      -- Insert UCC
      INSERT INTO rdt.rdtDataCapture (StorerKey, Facility, V_LOC, V_UCC, SerialNo, V_SKU, V_String1, V_QTY) 
      VALUES (@cStorerKey, @cFacility, @cLOC, SUBSTRING( @cUCC, 1, 20), SUBSTRING( @cUCC, 1, 30), @cSKU, @cID, @nQty) 

      -- Increase counter
      SET @nScan = @nScan + 1

      -- Prepare next screen var
      SET @cUCC = ''
      SET @cSKU = ''
      SET @cQty = ''
      SET @cOutField03 =''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField13 = @nScan
      EXEC rdt.rdtSetFocusField @nMobile, 03 --UCC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cLOC = ''
      SET @cID  = ''
      SET @cOutField01 = '' -- LOC
      SET @cOutField02 = '' --id

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
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
      V_LOC     = @cLOC,
      V_ID      = @cID, 
      V_SKU     = @cSKU,
      V_Qty     = @nQty,

      V_String1 = @cExtendedValidateSP,
      V_String2 = @cQty, 
      V_String3 = @cSerialNo, 
      V_String4 = @cIDIsMandatory,
      V_String5 = @cSKUIsMandatory,
      V_String6 = @cQtyIsMandatory,
      V_String8 = @cDuplicateUCC,
      
      V_Integer1 = @nScan,
      
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