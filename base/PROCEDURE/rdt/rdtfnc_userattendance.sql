SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: IDSTW User Time Attendance                                        */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2015-11-16 1.0  ChewKP     SOS#356126 Created                              */
/* 2016-02-05 1.1  ChewKP     SOS#363137 - Remove CurrentDate validation      */
/*                            (ChewKP01)                                      */
/* 2016-02-22 1.2  ChewKP     SOS#362253 - Add Codelkup Validation (ChewKP02) */
/* 2016-09-30 1.3  Ung        Performance tuning                              */
/* 2018-10-17 1.4  Tung GH    Performance                                     */  
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_UserAttendance] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
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
   @cPrinter   NVARCHAR( 20), 
   @cUserName  NVARCHAR( 18),
   
   @nError        INT,
   @b_success     INT,
   @n_err         INT,     
   @c_errmsg      NVARCHAR( 250), 
   @cPUOM         NVARCHAR( 10),    
   @bSuccess      INT,
   @cUserID       NVARCHAR( 18),
   @cLocation     NVARCHAR( 10),
   @dStartDate    DATETIME,
   @dEndDate      DATETIME,
   @cClockLoc     NVARCHAR( 10),
   @cStartDate    NVARCHAR( 20), 
   @cEndDate      NVARCHAR( 20),
   @cStatus       NVARCHAR( 5),
      
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

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)
   
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
   @cUserName  = UserName,
   
   @cPUOM       = V_UOM,
   @cUserID     = V_String1, 
   @cLocation   = V_String2,
   --@cStartDate  = V_String3,
   --@cEndDate    = V_String4,
   
   

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

Declare @n_debug INT

SET @n_debug = 0



IF @nFunc = 704  --Assign DropLoc
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Assign DropLoc
   IF @nStep = 1 GOTO Step_1   -- Scn = 4380. UserID ,
	IF @nStep = 2 GOTO Step_2   -- Scn = 4381. Loc
	--IF @nStep = 3 GOTO Step_3   -- Scn = 4382. Information

END


RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 704. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
	SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Initiate var
	-- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep
     
   
   -- Init screen
   SET @cOutField01 = '' 
   
   
   -- Set the entry point
	SET @nScn = 4380
	SET @nStep = 1
	
	EXEC rdt.rdtSetFocusField @nMobile, 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4380. 
   UserID (Input , Field01)
   

********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cUserID = ISNULL(RTRIM(@cInField01),'')
	   
	   
		
      -- Validate blank
      IF @cUserID = ''
      BEGIN
         SET @nErrNo = 95001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UserIDReq
         GOTO Step_1_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK)
                      WHERE ListName = 'WATUSER'
                      AND Code = @cUserID
                      AND StorerKey = @cStorerKey ) 
      BEGIN
         SET @nErrNo = 95008
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUserID
         GOTO Step_1_Fail
      END      
      

                      
      
      SELECT TOP 1 @cLocation = Location 
            ,@dStartDate = StartDate 
            ,@dEndDate   = EndDate
            ,@cStatus    = Status 
      FROM rdt.rdtWATLog WITH (NOLOCK)
      WHERE Module = 'CLK'
      AND UserName = @cUserID
      --AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103) -- (ChewKP01)
      ORDER By RowRef DESC
      
      IF @@ROWCOUNT = 0 
      BEGIN 
         -- Prepare Next Screen Variable
   		SET @cOutField01 = @cUserID
   		SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
	 
      END
      ELSE
      BEGIN
         -- Prepare Next Screen Variable
   		SET @cOutField01 = @cUserID
   		SET @cOutField02 = @cLocation
         SET @cOutField03 = CONVERT ( NVARCHAR(20) ,  @dStartDate , 120   ) 
         SET @cOutField04 = CASE WHEN @cStatus = '9' THEN CONVERT ( NVARCHAR(20) ,  @dEndDate , 120   ) ELSE '' END
         SET @cOutField05 = ''
   	 
      END

         
 
		-- GOTO Next Screen
		SET @nScn = @nScn + 1
	   SET @nStep = @nStep + 1
	    
	    
		
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
      -- EventLog - Sign In Function
       EXEC RDT.rdt_STD_EventLog
        @cActionType = '9', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep
        
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
      
      
      
   END
	GOTO Quit

   STEP_1_FAIL:
   BEGIN
      SET @cOutField01 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 4381. 
   UserID      (Field01) 
   Location    (Field02) 
   StartDate   (Field03) 
   EndDate     (Field04) 
   Location    (Field05, Input) 
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 
   BEGIN
	   
	   SET @cClockLoc = ISNULL(RTRIM(@cInField05),'')
	   
      
      IF @cClockLoc = ''
      BEGIN
         SET @nErrNo = 95002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocReq
         GOTO Step_2_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK) 
                      WHERE ListName = 'WATLOC'
                      AND StorerKey = @cStorerKey
                      AND Code = @cClockLoc ) 
      BEGIN
         SET @nErrNo = 95007
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoc
         GOTO Step_2_Fail
      END

--      IF EXISTS ( SELECT 1 FROM rdt.rdtWATLOG WITH (NOLOCK)
--                      WHERE Module = 'CLK'
--                      AND UserName = @cUserID
--                      AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103)
--                      AND Location = @cClockLoc
--                      AND Status = '9' ) 
--      BEGIN
--         SET @nErrNo = 95005
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AttendanceExist 
--         GOTO Step_2_Fail   
--      END

      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtWATLOG WITH (NOLOCK)
                      WHERE Module = 'CLK'
                      AND UserName = @cUserID
                      --AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103)-- (ChewKP01)
                      AND Location = @cClockLoc
                      AND Status = '0' ) 
      BEGIN
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtWATLOG WITH (NOLOCK)
                     WHERE Module = 'CLK'
                     AND UserName = @cUserID
                     --AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103)-- (ChewKP01)
                     AND Status = '0'
                     AND Location <>  @cClockLoc ) 
         BEGIN
            
            UPDATE rdt.rdtWATLog WITH (ROWLOCK) 
            SET  EndDate = GetDate()
               , Status  = '9'
            WHERE Module = 'CLK'
            AND UserName = @cUserID
            --AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103) -- (ChewKP01)
            AND Location <> @cClockLoc
            AND Status = '0'
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 95006
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateLogErr
               GOTO Step_2_Fail
            END
            
         END
         
         
         INSERT INTO RDT.rdtWATLog (Module, UserName, Location, StartDate, EndDate)  
         VALUES ('CLK', @cUserID, @cClockLoc, GetDate()  , Getdate())  
         
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 95003
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsertLogErr
            GOTO Step_2_Fail
         END

         SELECT --@cLocation = Location 
                @dStartDate = StartDate 
               --,@dEndDate   = EndDate
         FROM rdt.rdtWATLog WITH (NOLOCK)
         WHERE Module = 'CLK'
         AND UserName = @cUserID
         --AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103)-- (ChewKP01)
         AND Location = @cClockLoc
         AND Status = '0'

         SET @cOutField01 = @cUserID
   		SET @cOutField02 = @cClockLoc
         SET @cOutField03 = CONVERT ( NVARCHAR(20) ,  @dStartDate , 120   ) 
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         
         

      END
      ELSE 
      BEGIN 
         
         UPDATE rdt.rdtWATLog WITH (ROWLOCK) 
            SET  EndDate = GetDate()
               , Status  = '9'
         WHERE Module = 'CLK'
         AND UserName = @cUserID
         --AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103) -- (ChewKP01)
         AND Location = @cClockLoc
         AND Status = '0'
         
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 95004
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateLogErr
            GOTO Step_2_Fail
         END

         SELECT TOP 1 --@cLocation = Location 
                @dStartDate = StartDate 
               ,@dEndDate   = EndDate
         FROM rdt.rdtWATLog WITH (NOLOCK)
         WHERE Module = 'CLK'
         AND UserName = @cUserID
         --AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103)-- (ChewKP01)
         AND Location = @cClockLoc
         AND Status = '9'
         ORDER By RowRef DESC

         SET @cOutField01 = @cUserID
   	   SET @cOutField02 = @cClockLoc
         SET @cOutField03 = CONVERT ( NVARCHAR(20) ,  @dStartDate , 120   ) 
         SET @cOutField04 = CONVERT ( NVARCHAR(20) ,  @dEndDate , 120   ) 
         SET @cOutField05 = ''
      END
                      
     
      
      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
       @cActionType = '3', 
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @cRefNo1     = @cUserID,
       @cRefNo2     = @cClockLoc,
       @nStep       = @nStep
      
      
--      SELECT @cLocation = Location 
--            ,@dStartDate = StartDate 
--            ,@dEndDate   = EndDate
--      FROM rdt.rdtWATLog WITH (NOLOCK)
--      WHERE Module = 'CLK'
--      AND UserName = @cUserID
--      AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103)
--      AND Location = @cClockLoc
--      
--      IF @@ROWCOUNT = 0 
--      BEGIN 
--
--         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtWATLOG WITH (NOLOCK)
--                      WHERE Module = 'CLK'
--                      AND UserName = @cUserID
--                      AND CONVERT(VARCHAR, StartDate , 103) = CONVERT(VARCHAR, GETDATE() , 103)
--                      AND Location = @cClockLoc ) 
--         BEGIN
--            
--            INSERT INTO RDT.rdtWATLog (Module, UserName, Location, StartDate, EndDate)  
--            VALUES ('CLK', @cUserID, @cClockLoc, GetDate()  , Getdate())  
--            
--            IF @@ERROR <> 0 
--            BEGIN
--               SET @nErrNo = 95003
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsertLogErr
--               GOTO Step_2_Fail
--            END
--            
--         END
--         -- Prepare Next Screen Variable
--
--   		SET @cOutField01 = @cUserID
--   		SET @cOutField02 = @cClockLoc
--         SET @cOutField03 = CONVERT ( NVARCHAR(20) ,  @dStartDate , 120   ) 
--         SET @cOutField04 = ''
--         SET @cOutField05 = ''
--	 
--      END
--      ELSE
--      BEGIN
--         -- Prepare Next Screen Variable
--   	   SET @cOutField01 = @cUserID
--   	   SET @cOutField02 = @cLocation
--         SET @cOutField03 = CONVERT ( NVARCHAR(20) ,  @dStartDate , 120   ) 
--         SET @cOutField04 = CONVERT ( NVARCHAR(20) ,  @dEndDate , 120   ) 
--         SET @cOutField05 = ''
--      END
      
      
	END  -- Inputkey = 1
   
   IF @nInputKey = 0 
   BEGIN
     
     SET @cOutfield01 = ''
     
     
     SET @nScn = @nScn - 1 
     SET @nStep = @nStep - 1 
      
      
      
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField05 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 5
   END

END 
GOTO QUIT


/********************************************************************************
Step 3. Scn = 4382. 
   UserID      (Field01) 
   Location    (Field02) 
   StartDate   (Field03) 
   EndDate     (Field04) 

********************************************************************************/
--Step_3:
--BEGIN
--   IF @nInputKey = 1 --ENTER
--   BEGIN
--	     
--	     
--	     
--	     -- EventLog - Sign In Function
--        EXEC RDT.rdt_STD_EventLog
--        @cActionType = '9', -- Sign in function
--        @cUserID     = @cUserName,
--        @nMobileNo   = @nMobile,
--        @nFunctionID = @nFunc,
--        @cFacility   = @cFacility,
--        @cStorerKey  = @cStorerkey,
--        @nStep       = @nStep
--        
--	     
--        SET @cOutfield01 = ''
--        SET @cOutfield02 = ''
--     
--        SET @nScn = @nScn - 2 
--        SET @nStep = @nStep - 2 
--	    
--		
--	END  -- Inputkey = 1
--
--   
--
--END 
--GOTO QUIT




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
		InputKey  =	@nInputKey,

      V_UOM      = @cPUOM,
      V_String1  = @cUserID    , 
      V_String2  = @cLocation  ,
      --V_String3  = @cStartDate ,
      --V_String4  = @cEndDate   ,
     
      
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