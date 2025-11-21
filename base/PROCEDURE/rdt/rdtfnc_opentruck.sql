SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: IDSUK Open Truck SOS#262667                                       */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2012-11-28 1.0  ChewKP     Created                                         */
/* 2016-09-30 1.1  Ung        Performance tuning                              */
/* 2018-11-07 1.2  Gan        Performance tuning                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_OpenTruck] (
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
   @cTruckID      NVARCHAR( 20),
   @cOption       NVARCHAR( 1),
   @cPalletKey    NVARCHAR( 20),
   @cSealNo       NVARCHAR( 20),
   
	
	
      
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
   
	@cTruckID    = V_String1,
   @cSealNo     = V_String2,
   

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



IF @nFunc = 1717  -- Open Truck
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Open Truck
   IF @nStep = 1 GOTO Step_1   -- Scn = 3320. Truck ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 3321. Truck ID
	IF @nStep = 3 GOTO Step_3   -- Scn = 3322. Confirm Open Truck
	IF @nStep = 4 GOTO Step_4   -- Scn = 3323. Message
	
	
   
END

--IF @nStep = 3
--BEGIN
--	SET @cErrMsg = 'STEP 3'
--	GOTO QUIT
--END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1717. Menu
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
	SET @nScn = 3320
	SET @nStep = 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3320. 
   TruckID (Input , Field01)
   
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cTruckID = ISNULL(RTRIM(@cInField01),'')
		
      -- Validate blank
      IF ISNULL(RTRIM(@cTruckID), '') = ''
      BEGIN
         SET @nErrNo = 78201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrucKID req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      IF EXISTS (SELECT 1 FROM dbo.Container WITH (NOLOCK) WHERE Vessel =  @cTruckID And Status = '0')
      BEGIN
         SET @nErrNo = 78208
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TruckAlreadyOpen
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

--      IF EXISTS (SELECT 1 FROM dbo.Container WITH (NOLOCK) WHERE Vessel =  @cTruckID And Status = '9')
--      BEGIN
--         SET @nErrNo = 78202
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Truck Shipped
--         EXEC rdt.rdtSetFocusField @nMobile, 1
--         GOTO Step_1_Fail
--      END
      
      
  
		
		 -- Prepare Next Screen Variable
		 SET @cOutField01 = @cTruckID
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
      SET @cOutField01 = ''
      
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 3321. 
   TruckID (Field01)
   SealNo (Input , Field02)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cSealNo = ISNULL(RTRIM(@cInField02),'')
		
      -- Validate blank
      IF ISNULL(RTRIM(@cSealNo), '') = ''
      BEGIN
         SET @nErrNo = 78209
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SealNo Req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail
      END
      
      --IF EXISTS (SELECT 1 FROM dbo.Container WITH (NOLOCK) WHERE Vessel =  @cTruckID And Status = '0' AND @cSealNo IN (Seal01, Seal02) )
      IF NOT EXISTS (SELECT 1 FROM dbo.Container WITH (NOLOCK) WHERE Vessel =  @cTruckID And Status = '9' AND ISNULL(RTRIM(@cSealNo), '') IN (Seal01, Seal02) )  
      BEGIN
         SET @nErrNo = 78210
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SealNo
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_2_Fail
      END

--      IF EXISTS (SELECT 1 FROM dbo.Container WITH (NOLOCK) WHERE Vessel =  @cTruckID And Status = '9')
--      BEGIN
--         SET @nErrNo = 78202
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Truck Shipped
--         EXEC rdt.rdtSetFocusField @nMobile, 1
--         GOTO Step_1_Fail
--      END
      
      
  
		
		 -- Prepare Next Screen Variable
		 SET @cOutField01 = @cTruckID
		 SET @cOutField02 = @cSealNo
		 SET @cOutField03 = ''
		 
		 -- GOTO Next Screen
		 SET @nScn = @nScn + 1
	    SET @nStep = @nStep + 1
	    
	    
		
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
       -- Prepare Previous Screen Variable
		 SET @cOutField01 = @cTruckID
		 SET @cOutField02 = ''
		    
       -- GOTO Previous Screen
		 SET @nScn = @nScn - 1
	    SET @nStep = @nStep - 1
      
      
      
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = ''
   END
   

END 
GOTO QUIT


/********************************************************************************
Step 3. Scn = 3322. 
   TruckID   (field01)
   SealNo    (Field02)
   Options   (field03, input)
   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   
	   	
		SET @cOption = ISNULL(RTRIM(@cInField03),'')
		
		IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 78203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'
         GOTO Step_3_Fail
      END

      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 78204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_3_Fail
      END
      
      IF @cOption = '1'
		BEGIN
         
         -- Get Top 1 ContainerKey for the Current Vessel
		   
		   -- Update Container, 
		   BEGIN TRAN 
		      
		   DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
		   
         SELECT CD.PalletKey
         FROM dbo.Container C (NOLOCK)  
         INNER JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey
         WHERE C.Vessel = @cTruckID
         Order By C.ContainerKey Desc
  
         OPEN CUR_PD  
         
         FETCH NEXT FROM CUR_PD INTO @cPalletKey
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            
            UPDATE Pallet
            SET Status = '3', TrafficCop = NULL        
            WHERE PalletKey = @cPalletKey
            
            
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 78205
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletFail'
               ROLLBACK TRAN
               GOTO Step_3_Fail
            END  
            
            
            UPDATE PalletDetail
            SET Status = '3', TrafficCop = NULL     
            WHERE PalletKey = @cPalletKey
            
            
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 78206
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletDetFail'
               ROLLBACK TRAN
               GOTO Step_3_Fail
            END  
            
            FETCH NEXT FROM CUR_PD INTO @cPalletKey
            
         END
         CLOSE CUR_PD  
         DEALLOCATE CUR_PD  
         
         UPDATE dbo.Container
         SET Status = '0', TrafficCop = NULL   
         WHERE Vessel = @cTruckID
         
         
         IF @@ERROR <> 0    
         BEGIN    
               SET @nErrNo = 78207
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdContainerFail'
               ROLLBACK TRAN
               GOTO Step_3_Fail
         END
         
         COMMIT TRAN
         
         EXEC RDT.rdt_STD_EventLog
           @cActionType = '3', 
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cTruckID    = @cTruckID,
           --@cRefNo1     = @cTruckID,
           @nStep       = @nStep
           
        
         -- Prepare Next Screen Variable
   		SET @cOutField01 = @cTruckID
   		SET @cOutField02 = @cSealNo
   		
   		 
   		-- GOTO Prev Screen
   		SET @nScn = @nScn + 1
   	   SET @nStep = @nStep + 1
		   
	   END 
	   ELSE
		IF @cOption = '9'
		BEGIN
   		-- Prepare Next Screen Variable
   		SET @cOutField01 = '' --@cTruckID
   		--SET @cOutField02 = ''
   		
   		 
   		-- GOTO Prev Screen
   		SET @nScn = @nScn - 2
   	   SET @nStep = @nStep - 2
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
   END
	GOTO Quit

   STEP_3_FAIL:
   BEGIN
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = @cSealNo
      SET @cOutField03 = ''
      
   END
   

END 
GOTO QUIT


/********************************************************************************
Step 4. Scn = 3323. 
   
   TruckID    (Field01)
   
   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0  --ENTER
   BEGIN
		
      -- Prepare Next Screen Variable

      SET @cOutField01 = ''

      -- GOTO Next Screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
      
	END  -- Inputkey = 1
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
  
      V_String1 = @cTruckID      ,
	   V_String2 = @cSealNo       ,
      
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