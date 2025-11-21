SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Data capture 5, for cycle count               				   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2007-10-16 1.0  FKLIM      Created                                   */
/* 2010-11-26 1.1  Ung        Expand CartonNo from 10 to 20 chars       */
/* 2014-03-20 1.2  TLTING     Bug fix                                   */
/* 2015-06-25 1.3  Ung        Performance tuning                        */
/* 2016-09-30 1.4  Ung        Performance tuning                        */
/* 2018-10-18 1.5  TungGH     Performance                               */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DataCapture5] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON 
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF 
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT, 
   @nSKUCnt     INT

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
   @cCartonNo  NVARCHAR( 20), 
   @cSKU       NVARCHAR( 20),
   @cScan      VARCHAR (5),

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

   @cLOC       = V_String1,
   @cCartonNo  = V_String2,
   @cSKU       = V_String3,
   
   @cScan      = V_Integer1,

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

FROM RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 885  -- Data capture #3
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Data capture 5
   IF @nStep = 1 GOTO Step_1   -- Scn = 1950. LOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 1951. Carton No
   IF @nStep = 3 GOTO Step_3   -- Scn = 1952. SKU, counter
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 885. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1950
   SET @nStep = 1

   -- Initiate var
   SET @cLOC = ''
   SET @cCartonNo = ''
   SET @cSKU = ''
   SET @cScan = '0'

   -- Init screen
   SET @cOutField01 = '' -- LOC
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1950. LOC
   LOC      (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
	   SET @cLOC = @cInField01

      -- Validate blank
      IF @cLOC = '' OR @cLoc IS NULL
      BEGIN
         SET @nErrNo = 66301
         SET @cErrMsg = rdt.rdtgetmessage( 66301, @cLangCode, 'DSP') --LOC needed
         GOTO Step_1_Fail
      END

      -- Get LOC info
      DECLARE @cChkFacility NVARCHAR( 5)
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      -- Validate LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 66302
         SET @cErrMsg = rdt.rdtgetmessage( 66302, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_1_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 66303
         SET @cErrMsg = rdt.rdtgetmessage( 66303, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_1_Fail
      END

      --Get scanned LOC QTY
      SET @cScan = '0'
      SELECT @cScan = SUM( V_QTY)
      FROM rdt.rdtDataCapture WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND Facility = @cFacility
         AND V_LOC = @cLOC

      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField03 = ''--SKU
      SET @cOutField04 = @cScan
      EXEC rdt.rdtSetFocusField @nMobile, 3 --SKU
      
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
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField01 = '' -- LOC
   END

END
GOTO Quit


/********************************************************************************
Step 2. Scn = 1951. Carton No
   LOC       (field01)
   CARTON NO (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
	   SET @cCartonNo = @cInField02

      -- Validate blank
      IF @cCartonNo = '' OR @cCartonNo IS NULL
      BEGIN
         SET @nErrNo = 66304
         SET @cErrMsg = rdt.rdtgetmessage( 66304, @cLangCode, 'DSP') --CartonNo needed
         GOTO Step_2_Fail
      END

      --Get scanned LOC QTY
      SET @cScan = '0'
      SELECT @cScan = SUM( V_QTY)
      FROM rdt.rdtDataCapture WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND Facility = @cFacility
         AND V_LOC = @cLOC
         AND V_String2 = @cCartonNo

      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cCartonNo
      SET @cOutField03 = ''--SKU
      SET @cOutField04 = @cScan
      EXEC rdt.rdtSetFocusField @nMobile, 3 --SKU
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cLOC = ''
      SET @cOutField01 = '' -- LOC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cCartonNo = ''
      SET @cOutField02 = '' -- CartonNo
   END

END
GOTO Quit


/********************************************************************************
Step 3. Scn = 1952. SKU, counter
   LOC        (field01)
   CARTON NO  (field01)
   SKU        (field02, input)
   SCAN       (field04)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --screen mapping
      SET @cSKU = @cInField03

      -- Check SKU
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 66305
         SET @cErrMsg = rdt.rdtgetmessage( 66305, @cLangCode,'DSP') --Need SKU
         EXEC rdt.rdtSetFocusField @nMobile, 03
         GOTO Step_3_Fail
      END

      -- Get SKU/UPC
      SELECT 
         @nSKUCnt = COUNT( DISTINCT A.SKU), 
         @cSKU = MIN( A.SKU) -- Just to bypass SQL aggregrate checking
      FROM 
      (
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
      ) A

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 66306
         SET @cErrMsg = rdt.rdtgetmessage( 66306, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_3_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 66307
         SET @cErrMsg = rdt.rdtgetmessage( 66307 , @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_3_Fail
      END

      -- Update data capture
      DECLARE @nRowRef INT
      SET @nRowRef = 0
      SELECT @nRowRef = RowRef
         FROM rdt.rdtDataCapture WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND V_LOC = @cLOC
            AND V_String2 = @cCartonNo
            AND V_SKU = @cSKU
            
      IF @nRowRef > 0
      BEGIN
         -- Update
         UPDATE rdt.rdtDataCapture SET
            V_QTY = V_QTY + 1
         WHERE RowRef = @nRowRef
            -- StorerKey = @cStorerKey
            -- AND Facility = @cFacility
            -- AND V_LOC = @cLOC
            -- AND V_String2 = @cCartonNo
            -- AND V_SKU = @cSKU
      END
      ELSE
      BEGIN
         -- Insert
         INSERT INTO rdt.rdtDataCapture (StorerKey, Facility, V_LOC, V_String2, V_SKU, V_QTY)
         VALUES (@cStorerKey, @cFacility, @cLOC, @cCartonNo, @cSKU, 1)
      END

      -- Increase counter
      SET @cScan = @cScan + 1
      
      -- Prepare next screen var
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
      
      -- Retain in current screen
      SET @cSKU = ''
      SET @cOutField03 = @cSKU
      SET @cOutField04 = @cScan
      EXEC rdt.rdtSetFocusField @nMobile, 03 --SKU
      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cCartonNo = ''
      SET @cOutField02 = '' -- CartonNo

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField03 = '' --SKU
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

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 
      Printer   = @cPrinter,    

      V_String1 = @cLOC,
      V_String2 = @cCartonNo, 
      V_String3 = @cSKU,
      V_String4 = @cScan, 

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