SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: LF                                                              */ 
/* Purpose:                                                                   */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2015-11-16 1.0  ChewKP     SOS#354259 Created                              */
/* 2016-09-30 1.1  Ung        Performance tuning                              */
/* 2018-11-07 1.2  TungGH     Performance                                     */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_OTMPalletConsolidation] (
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

   @cStorerKey NVARCHAR( 30),
   @cFacility  NVARCHAR( 5), 
   @cPrinter   NVARCHAR( 20), 
   @cUserName  NVARCHAR( 18),
   
   @nError        INT,
   @b_success     INT,
   @n_err         INT,     
   @c_errmsg      NVARCHAR( 250), 
   @cPUOM         NVARCHAR( 10),    
   @cTruckID      NVARCHAR( 20),
   @cOption       NVARCHAR( 1),
   @cPalletKey    NVARCHAR( 20),
	@cConsoOption  NVARCHAR( 10),
	@cPalletID     NVARCHAR( 20),
	@cToPalletID   NVARCHAR( 20),
	@cToteNo       NVARCHAR( 10),
	@cNewPalletLineNumber NVARCHAR( 5),
	@cPalletLineNumber    NVARCHAR( 5),
   @cFromLoc      NVARCHAR( 10),
   @cToLoc        NVARCHAR( 10), 

   
   
      
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
 --@cOrderKey   = V_OrderKey,
   
	@cPalletID    = V_String1,
	@cToPalletID  = V_String2,
   @cConsoOption = V_String3,

   

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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,
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



IF @nFunc = 1722  -- OTM Pallet Consolidation
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Pallet Consolidation
   IF @nStep = 1 GOTO Step_1   -- Scn = 4390. From PalletID
	IF @nStep = 2 GOTO Step_2   -- Scn = 4391. To Pallet ID
	IF @nStep = 3 GOTO Step_3   -- Scn = 4392. Tote No
	
	
   
END

--IF @nStep = 3
--BEGIN
--	SET @cErrMsg = 'STEP 3'
--	GOTO QUIT
--END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1722. Menu
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
   SET @cOutField02 = '' 
	

   -- Set the entry point
	SET @nScn = 4390
	SET @nStep = 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3350. 
   Pallet ID (Input , Field01)
   Option    (Input , Field02)
   
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cPalletID = ISNULL(RTRIM(@cInField01),'')
	   SET @cOption   = ISNULL(RTRIM(@cInField02),'')
		
      -- Validate blank
      IF ISNULL(RTRIM(@cPalletID), '') = ''
      BEGIN
         SET @nErrNo = 95051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID Req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey = @cPalletID) 
      BEGIN
         SET @cPalletID = ''
         SET @nErrNo = 95066
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPalletID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END      
      
      

      IF EXISTS (SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey = @cPalletID AND MUStatus = '5')
      BEGIN
         SET @cPalletID = ''
         SET @nErrNo = 95052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletScanToTruck
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey = @cPalletID AND MUStatus IN ('2', '7') )
      BEGIN
         SET @cPalletID = ''
         SET @nErrNo = 95073
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletClosedTruck
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
                 
      IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey = @cPalletID AND MUStatus = '9' ) 
      BEGIN
         SET @cPalletID = ''
         SET @nErrNo = 95053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletShipped
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 95054
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END
      
      IF @cOption NOT IN ( '1','9')
      BEGIN
         SET @nErrNo = 95055
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END
      
      SET @cConsoOption = ''
      IF @cOption = '1'
      BEGIN
         SET @cConsoOption = 'WHOLE'
      END
      ELSE IF @cOption = '9'
      BEGIN
         SET @cConsoOption = 'PARTIAL'
      END
		
		-- Prepare Next Screen Variable
		SET @cOutField01 = @cPalletID
		SET @cOutField02 = ''
		 
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
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''
      --EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 4391. 
   PalletID   (field01)
   ToPalletID (field02, input)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   
	   	
		SET @cToPalletID = ISNULL(RTRIM(@cInField02),'')
		
		IF ISNULL(@cToPalletID, '') = ''
      BEGIN
         SET @nErrNo = 95056
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToPallet Req'
         GOTO Step_2_Fail
      END
      
--      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey = @cToPalletID) 
--      BEGIN
--         SET @nErrNo = 95067
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPalletID
--         GOTO Step_2_Fail
--      END      

      IF @cPalletID = @cToPalletID
         BEGIN
            SET @nErrNo = 95075
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameID
            GOTO Step_2_Fail
         END

      IF EXISTS (SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey =  @cToPalletID)
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey =  @cToPalletID AND MUStatus = '5')
         BEGIN
            SET @nErrNo = 95057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletScanToTruck
            GOTO Step_2_Fail
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey = @cToPalletID AND MUStatus IN ('2', '7') )
         BEGIN
            SET @cPalletID = ''
            SET @nErrNo = 95074
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletClosedTruck
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
                    
         IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey = @cToPalletID AND MUStatus = '9'  )
         BEGIN
            SET @nErrNo = 95058
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletShipped
            GOTO Step_2_Fail
         END
      END
          
      SELECT @cFromLoc = DropLoc
      FROM dbo.OTMIDTrack WITH (NOLOCK)
      WHERE PalletKey = @cPalletID
      
            
      SELECT @cToLoc = DropLoc
      FROM dbo.OTMIDTrack WITH (NOLOCK)
      WHERE PalletKey = @cToPalletID
      
      IF ISNULL(@cToLoc, '') <> '' 
      BEGIN
         IF @cFromLoc <> @cToLoc
         BEGIN
            SET @nErrNo = 95070
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffDropLoc'
            GOTO QUIT
         END
      END
     
      
      IF @cConsoOption = 'WHOLE'
		BEGIN
         
 
            --BEGIN TRAN
            
            DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      	   
      	   SELECT MUID
            FROM dbo.OTMIDTrack WITH (NOLOCK)  
            WHERE PalletKey = @cPalletID
            AND   MUStatus IN ('2', '7')
            Order By MUID
        
            OPEN CUR_PD  
            
            FETCH NEXT FROM CUR_PD INTO @cPalletLineNumber
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               
--               SET @cNewPalletLineNumber = ''
--      	      SELECT @cNewPalletLineNumber =
--               RIGHT( '00000' + CAST( CAST( IsNULL( MAX( MUID), 0) AS INT) + 1 AS VARCHAR( 5)), 5)  --Still need to revise
--               FROM dbo.OTMIDTrack WITH (NOLOCK)
--               WHERE PalletKey = @cToPalletID
               
      	      Update dbo.OTMIDTrack
      	      SET PalletKey = @cToPalletID
      	         --,MUID      = @cNewPalletLineNumber 
      	      WHERE PalletKey = @cPalletID 
      	          AND MUID    = @cPalletLineNumber
      	      
      	      IF @@ERROR <> 0 
      	      BEGIN
      	         --ROLLBACK TRAN
                  SET @nErrNo = 95059
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletDetFail
                  GOTO Step_2_Fail
      	      END
      	      
      	      
      	      FETCH NEXT FROM CUR_PD INTO @cPalletLineNumber
      	      
   	      END
   	      CLOSE CUR_PD  
            DEALLOCATE CUR_PD  
            
           
            
--            DELETE FROM dbo.OTMIDTrack
--            WHERE PalletKey = @cPalletID
--            
--            IF @@ERROR <> 0 
--            BEGIN
--               ROLLBACK TRAN
--               SET @nErrNo = 95060
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletFail
--               GOTO Step_2_Fail
--            END
               
            
            --COMMIT TRAN
	

		      		
   		SET @cOutField01 = ''
   		SET @cOutField02 = ''
   		SET @cOutField03 = ''
   		
   		-- GOTO Next Screen
   		SET @nScn = @nScn - 1
   	   SET @nStep = @nStep - 1
		   
	   END 
	   ELSE
		IF @cConsoOption = 'PARTIAL'
		BEGIN
   		
   		
   		SET @cOutField01 = @cPalletID
   		SET @cOutField02 = @cToPalletID
   		SET @cOutField03 = ''
   		
   		-- GOTO Next Screen
   		SET @nScn = @nScn + 1
   	   SET @nStep = @nStep + 1
   		
   		
	   END
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
        -- Prepare Previous Screen Variable
		 SET @cOutField01 = ''
		 SET @cOutField02 = ''
		    
       -- GOTO Previous Screen
		 SET @nScn = @nScn - 1
	    SET @nStep = @nStep - 1
       EXEC rdt.rdtSetFocusField @nMobile, 1
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''
   END
   

END 
GOTO QUIT


/********************************************************************************
Step 3. Scn = 4392. 
   
   PalletID    (Field01)
   ToPalletID  (Field02)
   ToteNo      (Field03 , Input)
   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 
   BEGIN
		SET @cToteNo = ISNULL(RTRIM(@cInField03),'')
		
		IF @cToteNo = ''
		BEGIN
		      SET @nErrNo = 95061
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNo Req
            GOTO Step_3_Fail
	   END
	   
	   
	   IF NOT EXISTS (SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                     WHERE PalletKey = @cPalletID
                     AND OrderID = @cToteNo ) 
      BEGIN
            SET @nErrNo = 95072
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOrderNo'
            GOTO QUIT
      END


   	--BEGIN TRAN
   	      
   	DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         
      SELECT MUID
      FROM dbo.OTMIDTrack WITH (NOLOCK)  
      WHERE PalletKey = @cPalletID
      AND OrderID = @cToteNo
      AND MUStatus IN ('2', '7')
      Order By MUID
      
      OPEN CUR_PD  
      
      FETCH NEXT FROM CUR_PD INTO @cPalletLineNumber
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         
         
         Update dbo.OTMIDTrack
         SET PalletKey = @cToPalletID
            --,MUID      = @cNewPalletLineNumber 
         WHERE PalletKey = @cPalletID 
             AND OrderID = @cToteNo
             AND MUID         = @cPalletLineNumber
         
         IF @@ERROR <> 0 
         BEGIN
            --ROLLBACK TRAN
            SET @nErrNo = 95064
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletDetFail
            GOTO Step_3_Fail
         END
         
         
         FETCH NEXT FROM CUR_PD INTO @cPalletLineNumber
         
   	END
   	CLOSE CUR_PD  
      DEALLOCATE CUR_PD  
   	
   	
--   	IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) WHERE PalletKey = @cPalletID ) 
--   	BEGIN
--   	   DELETE FROM dbo.OTMIDTrack
--         WHERE PalletKey = @cPalletID
--         
--         IF @@ERROR <> 0 
--         BEGIN
--            ROLLBACK TRAN
--            SET @nErrNo = 95065
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletFail
--            GOTO Step_3_Fail
--         END
--   	END
   	      
--   	   COMMIT TRAN
--	   END
	 
      -- Prepare Next Screen Variable
      --SET @cOutField01 = ''

      
      
	END  -- Inputkey = 1
	
	IF @nInputKey = 0 
   BEGIN
        -- Prepare Previous Screen Variable
		 SET @cOutField01 = @cPalletID
		 SET @cOutField02 = ''
		    
       -- GOTO Previous Screen
		 SET @nScn = @nScn - 1
	    SET @nStep = @nStep - 1
   END
	GOTO Quit

   STEP_3_FAIL:
   BEGIN
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cToPalletID
      SET @cOutField03 = ''
      
   END
   GOTO Quit

END 
GOTO QUIT



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
		

      V_UOM = @cPUOM,
  
      V_String1 = @cPalletID     ,
	   V_String2 = @cToPalletID   ,
	   V_String3 = @cConsoOption  , 

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