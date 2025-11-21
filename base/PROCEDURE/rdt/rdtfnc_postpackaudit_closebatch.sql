SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_CloseBatch                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Close Batch                                             */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 26-Feb-2007 1.0  jwong    Created                                    */
/* 22-May-2007 1.1  FKLIM    Insert a record into transmitlog2(sos72938)*/
/* 26-May-2009 1.2  Vicky    SOS#137534 - Add Batch Screen (Vicky01)    */
/* 15-Jul-2010 1.3  KHLim    Replace USER_NAME to sUSER_sName           */ 
/* 30-Sep-2016 1.4  Ung      Performance tuning                         */
/* 09-Nov-2018 1.5  TungGH   Performance                                */
/************************************************************************/

CREATE  PROC [RDT].[rdtfnc_PostPackAudit_CloseBatch] (
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
      @cInField02  NVARCHAR( 60),
      @cOutField01 NVARCHAR( 60),
      @cOutField02 NVARCHAR( 60), -- (Vicky01)
      @cStorerKey  NVARCHAR( 15),
      @cOption     NVARCHAR( 1),
      @cBatch      NVARCHAR( 15),
      @nBatchID    INT -- (Vicky01)

-- Getting Mobile information
SELECT @nFunc     = Func,
      @nScn       = Scn,
      @nStep      = Step,
      @nInputKey  = InputKey,
      @cLangCode  = Lang_code,
      @nMenu      = Menu,
      @cStorerKey = StorerKey,
      @cBatch     = V_String1, 
      @cInField01 = I_Field01,
      @cInField02 = I_Field02,
      @cOutField01 = O_Field01,
      @cOutField02 = O_Field02, -- (Vicky01)
      @nBatchID    = V_Integer1 -- (Vicky01)
FROM   RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

DECLARE 
   @nStep_CloseBatch        INT,  @nScn_CloseBatch        INT,  
   @nStep_CloseBatch_Msg    INT,  @nScn_CloseBatch_Msg    INT,  
   @nStep_CloseBatch_Option INT,  @nScn_CloseBatch_Option INT  -- (Vicky01)

SELECT
--    @nStep_CloseBatch        = 1,  @nScn_CloseBatch       = 1102, 
--    @nStep_CloseBatch_Msg    = 2,  @nScn_CloseBatch_Msg   = 1103

   -- (Vicky01) - Start
   @nStep_CloseBatch        = 1,  @nScn_CloseBatch         = 1102,
   @nStep_CloseBatch_Option = 2,  @nScn_CloseBatch_Option  = 1103, 
   @nStep_CloseBatch_Msg    = 3,  @nScn_CloseBatch_Msg     = 1104
    -- (Vicky01) - End

IF @nFunc = 890 -- Complex template
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start             -- menu func 890
   IF @nStep = 1 GOTO Step_CloseBatch        -- scn = 1102   Enter Batch
   IF @nStep = 2 GOTO Step_CloseBatch_Option -- scn = 1103   Confirm Batch to close
   IF @nStep = 3 GOTO Step_CloseBatch_Msg    -- scn = 1104   Batch closed successfully
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Func = 890. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Set the entry point
   SET @nScn = @nScn_CloseBatch
   SET @nStep = @nStep_CloseBatch

-- (Vicky01) - Start
--    SELECT @cBatch = Batch
--    FROM RDT.RDTCSAudit_Batch (NOLOCK) 
--    WHERE StorerKey = @cStorerKey 
--       AND CloseWho = '' 
--    ORDER BY BatchID
-- (Vicky01) - End

   -- Initialize var
   SET @cBatch = '' -- (Vicky01)
   SET @cOption = ''
   SET @nBatchID = ''

   -- Init screen
   -- SET @cOutField01 = @cBatch 
   SET @cOutField01 = '' -- (Vicky01)
END
GOTO Quit

/********************************************************************************
Added By (Vicky01)
Step 1. screen (scn = 1102)

   BATCH: (@cInField01)

********************************************************************************/
Step_CloseBatch:
BEGIN

   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      SET @cBatch = @cInField01
        
      IF ISNULL(RTRIM(@cBatch), '') = ''
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 62952, @cLangCode, 'DSP') --Batch needed
         GOTO Step_1_Fail      
      END


      IF NOT EXISTS (SELECT 1 FROM rdt.rdtCSAudit_Batch (NOLOCK) 
                     WHERE StorerKey = @cStorerKey AND Batch = @cBatch)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 62953, @cLangCode, 'DSP') --BatchNotFound
         GOTO Step_1_Fail      
      END
 

      IF NOT EXISTS (SELECT 1 FROM rdt.rdtCSAudit_Batch (NOLOCK) 
                     WHERE StorerKey = @cStorerKey AND Batch = @cBatch 
                     AND CloseWho = '')
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 62954, @cLangCode, 'DSP') --BatchAlrdyClosed
         GOTO Step_1_Fail      
      END

      SELECT @nBatchID = BatchID
      FROM rdt.rdtCSAudit_Batch (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND Batch = @cBatch 
      AND CloseWho = ''
       

      -- Prepare next screen variable
      SET @cOutField01 = @cBatch 

      SET @nScn = @nScn_CloseBatch_Option
      SET @nStep = @nStep_CloseBatch_Option

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


/********************************************************************************
Step 2. screen (scn = 1103)
   Close this batch?
   XXXXXXXXXXXXXXX
  
   1 = YES
   2 = NO

   Option: (@cInField02)

********************************************************************************/
Step_CloseBatch_Option:
BEGIN

   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      SET @cOption = @cInField02
        
      IF @cOption = '' 
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 62945, @cLangCode, 'DSP') --Option needed
         GOTO Step_2_Fail      
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 4, @cLangCode, 'DSP') --Invalid Option
         SET @cOption = ''
         GOTO Step_2_Fail      
      END

      IF @cOption = '1'   --confirm to close batch
      BEGIN
-- (Vicky01) - Start
--          IF @cBatch = ''
--          BEGIN
--             SET @cErrMsg = rdt.rdtgetmessage( 62941, @cLangCode, 'DSP') --Batch needed
--             GOTO Step_2_Fail      
--          END

--          IF NOT EXISTS (SELECT 1 FROM rdt.rdtCSAudit_Batch (NOLOCK) 
--             WHERE StorerKey = @cStorerKey AND CloseWho = '')
--          BEGIN
--             SET @cErrMsg = rdt.rdtgetmessage( 62946, @cLangCode, 'DSP') --NoOpenedBatch
--             GOTO Step_2_Fail      
--          END
-- (Vicky01) - End
   
         IF EXISTS (SELECT 1 FROM rdt.rdtCSAudit (NOLOCK) 
                    WHERE StorerKey = @cStorerKey AND Status = '0'
                    AND BatchID = @nBatchID )    -- (Vicky01)
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 62947, @cLangCode, 'DSP') --OpenTaskFound
            GOTO Step_2_Fail      
         END
   
         BEGIN TRAN
         UPDATE rdt.rdtCSAudit_Batch SET 
            CloseWho = sUser_sName(), 
            CloseDate = GETDATE() 
         WHERE Batch = @cBatch 
            AND StorerKey = @cStorerKey

         IF @@ERROR <> 0
         BEGIN         
            SET @cErrMsg = rdt.rdtgetmessage( 62944, @cLangCode, 'DSP') --Fail To UPD
            ROLLBACK TRAN 
            GOTO Step_2_Fail
         END

         --sos72938 insert a record into transmitlog2 upon successfully close batch -start (FKLIM)
			DECLARE @c_WTSITF NVARCHAR( 1)
			DECLARE @n_err INT, @b_success INT
			
         SELECT @b_success = 0
         Execute dbo.nspGetRight 
         	null,	
            @cStorerKey, 	
            null,				
            'WTS-ITF',	
            @b_success		output,
            @c_WTSITF 	   output,
            @n_err			output,
            @cErrMsg		output

	      IF @b_success <> 1
	      BEGIN
	         SET @nErrNo = 62950
	         SET @cErrMsg = rdt.rdtgetmessage( 62950, @cLangCode, 'DSP') --'nspGetRight'
	         GOTO Step_2_Fail
	      END

         IF (@c_WTSITF = '1' AND @b_success = 1 )
         BEGIN
            EXEC dbo.ispGenTransmitLog2 
              'WTS-PPA' 
            , @cBatch
            , '' 
            , @cStorerKey 
            , ''
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @cErrMsg OUTPUT
            
            IF @b_success <> 1
            BEGIN
	         SET @nErrNo =62951
	         SET @cErrMsg = rdt.rdtgetmessage( 62951, @cLangCode, 'DSP') --'GenTransL2Err'
	         GOTO Step_2_Fail
            END				
			END   
	       --sos72938 insert a record into transmitlog2 upon successfully close trip -end (FKLIM)
         
         COMMIT TRAN
         SET @nScn = @nScn_CloseBatch_Msg
         SET @nStep = @nStep_CloseBatch_Msg
         SET @cOption = ''
         SET @cBatch = ''
         SET @nBatchID = ''
         GOTO Quit
      END
      
      IF RTRIM(@cOption) = '2'   --cancel batch close and return to first screen
      BEGIN
--          SET @nFunc = @nMenu
--          SET @nScn  = @nMenu
--          SET @nStep = 0
--    
--          -- de-initialise all variable   
--          SET @cOutField01 = ''   

         -- (Vicky01) - Start
         SET @nScn = @nScn_CloseBatch
         SET @nStep = @nStep_CloseBatch
         SET @cOption = ''
         SET @cBatch = ''
         SET @nBatchID = ''
   
         -- de-initialise all variable   
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         -- (Vicky01) - End

         GOTO Quit
      END
   END
   
   IF @nInputKey = 0 -- Esc OR No
   BEGIN
--       SET @nFunc = @nMenu
--       SET @nScn  = @nMenu
--       SET @nStep = 0
-- 
--       -- de-initialise all variable   
--       SET @cOutField01 = ''

-- (Vicky01) - Start
      SET @nScn = @nScn_CloseBatch
      SET @nStep = @nStep_CloseBatch
      SET @cOption = ''
      SET @cBatch = ''
      SET @nBatchID = ''

      -- de-initialise all variable   
      SET @cOutField01 = ''
      SET @cOutField02 = ''
-- (Vicky01) - End

      GOTO Quit
   END
   
   Step_2_Fail:
   BEGIN
      SET @cOption = ''
   END   
END
GOTO Quit

/********************************************************************************
Step 3. screen (scn = 1104)
Batch closed 
successfully

Press ENTER or ESC 
to continue

********************************************************************************/
Step_CloseBatch_Msg:
BEGIN
--    SET @nFunc = @nMenu
--    SET @nScn  = @nMenu
--    SET @nStep = 0

  -- (Vicky01) - Start
   SET @nScn = @nScn_CloseBatch
   SET @nStep = @nStep_CloseBatch
   SET @cOption = ''
   SET @cBatch = ''
   SET @nBatchID = ''

   -- de-initialise all variable   
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   -- (Vicky01) - End

   GOTO Quit
END  

Quit:
BEGIN

   UPDATE RDTMOBREC WITH (ROWLOCK) SET 
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg   , 
      Func = @nFunc,
      Step = @nStep,            
      Scn = @nScn,
      V_String1 = @cBatch,
      O_Field01 = @cOutField01,
      O_Field02 = @cOutField02, -- (Vicky01)
      I_Field01 = '',    I_Field02 = '',
      V_Integer1 = @nBatchID    -- (Vicky01)
   WHERE Mobile = @nMobile

END







GO