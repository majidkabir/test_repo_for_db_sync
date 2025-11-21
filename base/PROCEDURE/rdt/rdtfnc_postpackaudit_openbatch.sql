SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_OpenBatch                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Open Batch                                              */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 26-Feb-2007 1.0  jwong    Created                                    */
/* 26-May-2009 1.1  Vicky    SOS#137533 - Allow to open multiple batch  */
/*                           at anytime                                 */ 
/*                           - Do not allow to re-use batch when it's   */
/*                             exists in rdtCSAudit_Batch table         */
/*                            (Vicky01)                                 */
/* 15-Jul-2010 1.2  KHLim    Replace USER_NAME to sUSER_sName           */ 
/* 30-Sep-2016 1.3  Ung      Performance tuning                         */
/* 09-Nov-2018 1.4  Gan      Performance tuning                         */
/************************************************************************/

CREATE  PROC [RDT].[rdtfnc_PostPackAudit_OpenBatch] (
	@nMobile    int,
	@nErrNo     int  OUTPUT,
	@cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Define a variable
DECLARE @nFunc     int,
      @nScn        int,
      @nStep       int,
      @cLangCode   NVARCHAR( 3),
      @nMenu       int,
      @nInputKey   NVARCHAR( 3), 
      @cInField01  NVARCHAR( 60),
      @cOutField01 NVARCHAR( 60),
      @cStorerKey  NVARCHAR( 15),
      @cBatch      NVARCHAR( 15)

-- Getting Mobile information
SELECT @nFunc     = Func,
      @nScn       = Scn,
      @nStep      = Step,
      @nInputKey  = InputKey,
      @cLangCode  = Lang_code,
      @nMenu      = Menu,
      @cStorerKey = StorerKey,
      @cInField01 = I_Field01,
      @cOutField01 = O_Field01
FROM   RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

DECLARE 
   @nStep_OpenBatch  INT,  @nScn_OpenBatch    INT  

SELECT
   @nStep_OpenBatch  = 1,  @nScn_OpenBatch = 1101

IF @nFunc = 889 
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start   		-- Menu. Func = 889
   IF @nStep = 1 GOTO Step_OpenBatch 	-- Scn = 1101   Enter Batch
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Func = 889. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Set the entry point
   SET @nScn = @nScn_OpenBatch
   SET @nStep = @nStep_OpenBatch

   -- Initialize var
   SET @cBatch = ''

   -- Init screen
   SET @cOutField01 = '' 
END
GOTO Quit


/********************************************************************************
Step 0. screen (scn = 1101)
   OPEN BATCH

   BATCH:
   (@cInField01)
********************************************************************************/
Step_OpenBatch:

BEGIN

   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      SET @cBatch = @cInField01

      IF (@cBatch = '' OR @cBatch IS NULL) 
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 62941, @cLangCode, 'DSP') --Batch needed
         GOTO Step_1_Fail      
      END

      IF EXISTS (SELECT 1 FROM rdt.rdtCSAudit_Batch (NOLOCK) 
         WHERE Batch = @cBatch)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 62943, @cLangCode, 'DSP') --DuplicatedBatch
         GOTO Step_1_Fail      
      END

      IF EXISTS (SELECT 1 FROM rdt.rdtCSAudit_Batch (NOLOCK) 
         WHERE StorerKey = @cStorerKey AND Batch = @cBatch AND CloseWho = '') -- (Vicky01)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 62942, @cLangCode, 'DSP') --BatchNotClosed
         GOTO Step_1_Fail      
      END

      BEGIN TRAN

      INSERT INTO rdt.rdtCSAudit_Batch (Batch, StorerKey, OpenDate, OpenWho, CloseWho, CloseDate)
      VALUES (@cBatch, @cStorerKey, GETDATE(), sUser_sName(), '', NULL)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 62944
         SET @cErrMsg = rdt.rdtgetmessage( 62944, @cLangCode, 'DSP') --Fail To UPD
         ROLLBACK TRAN 
         GOTO Step_1_Fail
      END
      COMMIT TRAN

      SET @nScn = @nScn_OpenBatch
      SET @nStep = @nStep_OpenBatch
      SET @cOutField01 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO Quit
   END
   
   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      -- de-initialise all variable   
      SET @cOutField01 = ''
      GOTO Quit
   END
   
   Step_1_Fail:
   BEGIN
      SET @cBatch = ''
   END   
END
GOTO Quit

Quit:
BEGIN

   UPDATE RDTMOBREC WITH (ROWLOCK) SET 
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg, 
      Func = @nFunc,
      Step = @nStep,            
      Scn = @nScn,
      O_Field01 = @cOutField01, 
      I_Field01 = ''
   WHERE Mobile = @nMobile

END


GO