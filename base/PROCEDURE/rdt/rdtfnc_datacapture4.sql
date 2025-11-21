SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Data Capture #4                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2007-10-16 1.0  FKLIM      Created                                   */
/* 2014-03-20 1.2  TLTING     Bug fix                                   */
/* 2016-01-05 1.3  ChewKP     SOS#359415 - Add Remarks Field (ChewKP01) */
/* 2016-09-30 1.4  Ung        Performance tuning                        */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DataCapture4] (
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
	@cQTY       CHAR (5),   
   @cUCC       NVARCHAR( 20),
	@cScan      VARCHAR (5),
	@cReference NVARCHAR(20), -- (ChewKP01) 
	@cExecStatements  NVARCHAR(4000),   -- (ChewKP01) 
   @cExecArguments   NVARCHAR(4000),   -- (ChewKP01) 
   @cCounter         NVARCHAR(100),

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
   @cUCC       = V_String3,
   @cScan      = CASE WHEN rdt.rdtIsValidQTY( V_String4,  0) = 1 THEN V_String4 ELSE 0 END,
   @cReference = V_String5, -- (ChewKP01) 
   @cCounter   = V_String6, -- (ChewKP01) 

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 884  -- Data capture #3
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- UCC Replenishment From (Dynamic Pick)
   IF @nStep = 1 GOTO Step_1   -- Scn = 1770. LOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 1771. QTY, UCC, counter
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 884. Menu
********************************************************************************/
Step_0:
BEGIN
   
   -- (ChewKP01) 
   SELECT @cCounter = Short
   FROM dbo.Codelkup WITH (NOLOCK)
   WHERE ListName = 'RDT884'
   AND Code = 'Counter'
   
   IF ISNULL(@cCounter, '' ) = '' 
   BEGIN
      SET @cCounter = ''
   END
   

   
   -- Set the entry point
   SET @nScn = 1770
   SET @nStep = 1

   -- Initiate var
   SET @cLOC = ''
   SET @cUCC = ''
   SET @cScan = '0'

   -- Init screen
   SET @cOutField01 = '' -- LOC
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1770. LOC
   LOC      (field01, input)
   REFERENCE(field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
	   SET @cLOC = @cInField01
	   SET @cReference = ISNULL(@cInField02,'') 

      -- Validate blank
      IF @cLOC = '' OR @cLoc IS NULL
      BEGIN
         SET @cLOC = ''
         SET @nErrNo = 65651
         SET @cErrMsg = rdt.rdtgetmessage( 65651, @cLangCode, 'DSP') --LOC needed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail
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
         SET @nErrNo = 65652
         SET @cErrMsg = rdt.rdtgetmessage( 65652, @cLangCode, 'DSP') --'Invalid LOC'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Validate LOC's facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @cLOC = ''
         SET @nErrNo = 65653
         SET @cErrMsg = rdt.rdtgetmessage( 65653, @cLangCode, 'DSP') --'Diff facility'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      -- (ChewKP01) 
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'REFERENCE', @cReference) = 1  
      BEGIN
         SET @nErrNo = 65657
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReferenceReq'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END
      
      SET @cScan = '0'
      
      IF @cCounter = '' 
      BEGIN
         --Get scanned UCC
         --SET @cScan = '0'
         SELECT @cScan = COUNT( 1)
         FROM rdt.rdtDataCapture (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND V_LOC = @cLOC
            AND V_UCC <> ''
      END
      ELSE
      BEGIN
         SET @cExecStatements  = N'SELECT @cScan = COUNT( 1) ' + char(13) +   
                                  ' FROM rdt.rdtDataCapture (NOLOCK) ' + Char(13) +   
                                  ' WHERE StorerKey = @cStorerKey ' + char(13) +   
                                  ' AND Facility = @cFacility ' + Char(13) +   
                                  ' AND V_UCC <> '''' ' + Char(13) +   
                                  ' AND ' + RTRIM(@cCounter) + ' = ''' + @cReference + ''' ' + Char(13)  
  
         SET @cExecArguments = N'@cFacility      char(5), ' +   
                                '@cStorerKey    char(15), ' +   
                                '@cScan     INT OUTPUT  '   
  
         EXEC sp_ExecuteSql @cExecStatements, @cExecArguments   
                               ,@cFacility    
                               ,@cStorerKey   
                               ,@cScan OUTPUT  
      END
      
      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField03 = ''--UCC
      SET @cOutField04 = @cScan
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
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = @cLoc -- LOC
      SET @cOutField02 = ''
      
   END

END
GOTO Quit


/********************************************************************************
Step 2. Scn = 1771. UCC, counter
   LOC  (field01)
   UCC  (field02, input)
   SCAN (field04)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --screen mapping
      SET @cUCC = @cInField03

      -- Check UCC
      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 65655
         SET @cErrMsg = rdt.rdtgetmessage( 65655, @cLangCode,'DSP') --Need UCC
         EXEC rdt.rdtSetFocusField @nMobile, 03
         GOTO Step_2_Fail  
      END

      IF LEN( @cUCC) < 20
      BEGIN
         SET @nErrNo = 65656
         SET @cErrMsg = rdt.rdtgetmessage( 65656, @cLangCode,'DSP') --UCC length <20
         EXEC rdt.rdtSetFocusField @nMobile, 03
         GOTO Step_2_Fail  
      END

      -- Save the data
      IF EXISTS( SELECT 1
         FROM rdt.rdtDataCapture (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND V_LOC = @cLOC
            AND V_UCC = @cUCC)
      BEGIN
         SET @nErrNo = 65654
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UCC scanned
         EXEC rdt.rdtSetFocusField @nMobile, 03
         GOTO Step_2_Fail  
      END
      ELSE
      BEGIN
         -- Insert UCC
         INSERT INTO rdt.rdtDataCapture (StorerKey, Facility, V_LOC, V_UCC, V_QTY, V_String1) -- (ChewKP01) 
         VALUES (@cStorerKey, @cFacility, @cLOC, @cUCC, @cQTY, @cReference) -- (ChewKP01) 

         -- Increase counter
         SET @cScan = @cScan + 1
      END
      
      -- Retain in current screen
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
      
      -- Prepare next screen var
      SET @cUCC = ''
      SET @cOutField03 = @cUCC
      SET @cOutField04 = @cScan
      EXEC rdt.rdtSetFocusField @nMobile, 03 --UCC
      
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
      SET @cUCC = ''
      SET @cOutField03 = '' --UCC
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
      V_String2 = @cQTY, 
      V_String3 = @cUCC,
      V_String4 = @cScan, 
      V_String5 = @cReference, -- (ChewKP01) 
      V_String6 = @cCounter, -- (ChewKP01) 

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