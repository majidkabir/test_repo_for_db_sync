SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: IDSUK rdtfnc_ScanToTruck_Pallet SOS#262664                        */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2012-12-03 1.0  ChewKP     Created                                         */
/* 2015-01-26 1.1  James      SOS331117 Add ExtendedUpdateSP (james01)        */
/* 2016-09-30 1.2  Ung        Performance tuning                              */
/* 2018-11-14 1.3  Gan        Performance tuning                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_ScanToTruck_Pallet] (
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
   @cPalletID     NVARCHAR( 20),
	@cContainerKey NVARCHAR( 10),
	@cSealNo       NVARCHAR( 20),
	@cVessel       NVARCHAR( 20),
	@cOtherReference NVARCHAR( 30),
   @cMBOLKey        NVARCHAR( 10),
   @cRoute          NVARCHAR( 20), 
   @cContainerType  NVARCHAR( 10),
   @bSuccess        INT,
   @nScanned        INT,
   @cExtendedUpdateSP   NVARCHAR( 20),    -- (james01)
   @cSQL                NVARCHAR(1000),   -- (james01)
   @cSQLParam           NVARCHAR(1000),   -- (james01)
   @cErrMsg1            NVARCHAR( 20),    -- (james01)
   @cErrMsg2            NVARCHAR( 20),    -- (james01)
   @cErrMsg3            NVARCHAR( 20),    -- (james01)
   @cErrMsg4            NVARCHAR( 20),    -- (james01)
   @cErrMsg5            NVARCHAR( 20),    -- (james01)

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
 
   @nScanned    = V_Integer1,
   
	@cTruckID    = V_String1,
   @cPalletID   = V_String2,
   @cContainerKey = V_String3, 
  -- @nScanned      = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String4, 5), 0) = 1 THEN LEFT(V_String4, 5) ELSE 0 END, 
   

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



IF @nFunc = 1718  -- Scan To Truck
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Open Truck
   IF @nStep = 1 GOTO Step_1   -- Scn = 3330. Truck ID
	IF @nStep = 2 GOTO Step_2   -- Scn = 3331. Options
	IF @nStep = 3 GOTO Step_3   -- Scn = 3332. Close Truck
	IF @nStep = 4 GOTO Step_4   -- Scn = 3333. Remove Pallet 
	IF @nStep = 5 GOTO Step_5   -- Scn = 3334. Add Pallet
	
	
   
END

--IF @nStep = 3
--BEGIN
--	SET @cErrMsg = 'STEP 3'
--	GOTO QUIT
--END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1718. Menu
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
	SET @nScn = 3330
	SET @nStep = 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3330. 
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
         SET @nErrNo = 78251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrucKID req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
--      IF EXISTS (SELECT 1 FROM dbo.Container WITH (NOLOCK) WHERE Vessel =  @cTruckID And Status >= '5')
--      BEGIN
--         SET @nErrNo = 78253
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TruckIDClosed
--         EXEC rdt.rdtSetFocusField @nMobile, 1
--         GOTO Step_1_Fail
--      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.IDS_VEHICLE WITH (NOLOCK) WHERE VehicleNumber = @cTruckID )
      BEGIN
         SET @nErrNo = 78252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid TruckID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      
      
   	
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
Step 2. Scn = 3331. 
   TruckID   (field01)
   Options   (field02, input)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   
	   	
		SET @cOption = ISNULL(RTRIM(@cInField02),'')
		
		IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 78254
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'
         GOTO Step_2_Fail
      END

      IF @cOption NOT IN ('1', '5', '9')
      BEGIN
         SET @nErrNo = 78255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_2_Fail
      END
      
      IF @cOption = '1'
		BEGIN
         	-- Prepare Next Screen Variable
      		SET @cOutField01 = @cTruckID
      		SET @cOutField02 = ''
      		
      		-- GOTO Next Screen
      		SET @nScn = @nScn + 1
      	   SET @nStep = @nStep + 1	   
	   END
	   ELSE
		IF @cOption = '5'
		BEGIN
		      SET @cPalletID = ''
		      
   		   -- Prepare Next Screen Variable
      		SET @cOutField01 = @cTruckID
      		SET @cOutField02 = ''
      		
      		-- GOTO Next Screen
      		SET @nScn = @nScn + 2
      	   SET @nStep = @nStep + 2	 
	   END 
	   ELSE
		IF @cOption = '9'
		BEGIN
		      SET @cPalletID = ''
		      
   		   -- Prepare Next Screen Variable
      		SET @cOutField01 = @cTruckID
      		SET @cOutField02 = ''
      		
      		SET @nScanned = 0
      		
      		SELECT @nScanned = Count(CD.PalletKey)
            FROM dbo.Container C WITH (NOLOCK)
            INNER JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey
            WHERE C.Vessel = @cTruckID
            AND C.Status = '0'
      		
      		SET @cOutField03 = @nScanned
      		
      		-- GOTO Next Screen
      		SET @nScn = @nScn + 3
      	   SET @nStep = @nStep + 3	 
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

   STEP_2_FAIL:
   BEGIN
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = ''
   END
   

END 
GOTO QUIT


/********************************************************************************
Step 3. Scn = 3332. 
   
   TruckID     (Field01)
   Close Truck (Field02, Input)
   
   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1
   BEGIN
      
      SET @cSealNo = ISNULL(RTRIM(@cInField02),'')
      
      
      
      IF @cSealNo = ''
      BEGIN
         SET @nErrNo = 78256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SealNo Req'
         GOTO Step_3_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Container WHERE Vessel = @cTruckID AND Status = '0' ) 
      BEGIN
         SET @nErrNo = 78275
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TruckNotExist'
         GOTO Step_3_Fail
      END

      -- Update Container , ContainerDetail , Pallet, PalletDetail Status = '5'
      BEGIN TRAN
      
      SELECT Top 1 @cContainerKey = ContainerKey
      FROM dbo.Container WITH (NOLOCK)
      WHERE Vessel = @cTruckID
      AND Status <> '9'

      
      DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
		   
      SELECT CD.PalletKey, C.ContainerType
      FROM dbo.Container C (NOLOCK)  
      INNER JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey
      WHERE C.Vessel = @cTruckID
      AND C.ContainerKey = @cContainerKey
      
      Order By CD.PalletKey
  
      OPEN CUR_PD  
      
      FETCH NEXT FROM CUR_PD INTO @cPalletID, @cContainerType
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         
         
         UPDATE Pallet
         SET Status = CASE WHEN @cContainerType = 'DIRECT' THEN '9' ELSE '5'
                      END      
         WHERE PalletKey = @cPalletID
         
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 78259
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletFail'
            ROLLBACK TRAN
            GOTO Step_3_Fail
         END  
         
         
         UPDATE PalletDetail
         SET Status = CASE WHEN @cContainerType = 'DIRECT' THEN '9' ELSE '5'
                      END      
         WHERE PalletKey = @cPalletID
         
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 78260
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletDetFail'
            ROLLBACK TRAN
            GOTO Step_3_Fail
         END  
         
         FETCH NEXT FROM CUR_PD INTO @cPalletID, @cContainerType
         
      END
      CLOSE CUR_PD  
      DEALLOCATE CUR_PD  
      
      Update dbo.Container   
      SET Status = CASE WHEN @cContainerType = 'DIRECT' THEN '9' ELSE '5'
                   END   
         ,Seal01 = @cSealNo
      WHERE ContainerKey = @cContainerKey
      
      IF @@ERROR <> 0 
      BEGIN 
         ROLLBACK TRAN
         SET @nErrNo = 78257
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdContainerFail'
         GOTO Step_3_Fail
      END

      -- (james01)
      SET @cExtendedUpdateSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
      IF @cExtendedUpdateSP NOT IN ('0', '')
      BEGIN
         SET @nErrNo = 0
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTruckID, @cPalletID, @cSealNo, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParam =    
            '@nMobile                  INT, '           +
            '@nFunc                    INT, '           +
            '@cLangCode                NVARCHAR( 3), '  +
            '@nStep                    INT, '           +
            '@nInputKey                INT, '           + 
            '@cStorerKey               NVARCHAR( 15), ' +
            '@cTruckID                 NVARCHAR( 20), ' +
            '@cPalletID                NVARCHAR( 20), ' +
            '@cSealNo                  NVARCHAR( 20), ' +
            '@nErrNo                   INT           OUTPUT,  ' +
            '@cErrMsg                  NVARCHAR( 20) OUTPUT   ' 
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTruckID, @cPalletID, @cSealNo, 
              @nErrNo OUTPUT, @cErrMsg OUTPUT     
              
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
            GOTO Step_3_Fail
         END
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
        @cID         = @cPalletID,
        --@cRefNo2     = @cPalletID,
        @nStep       = @nStep
		
      -- Prepare Next Screen Variable
      SET @cOutField01 = ''
      
      -- Display Message on Screen
--      SET @nErrNo = 78261
--      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Truck Closed'
      
      SET @nErrNo = 0
      SET @cErrMsg1 = 'Truck Closed'
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
      IF @nErrNo = 1
      BEGIN
         SET @cErrMsg1 = ''
      END
               
      -- GOTO Next Screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
      
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

   STEP_3_FAIL:
   BEGIN
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = ''
   END

END 
GOTO QUIT

/********************************************************************************
Step 4. Scn = 3333. 
   TruckID   (field01)
   PalletID  (field02, input)
   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   
	   	
		SET @cPalletID = ISNULL(RTRIM(@cInField02),'')
		
		IF @cPalletID = ''
		BEGIN
		   SET @nErrNo = 78262
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PalletID Req'
         GOTO Step_4_Fail
	   END
	   
	   SET @cContainerKey = ''
	   SET @cVessel = ''
	   SELECT   @cContainerKey = C.ContainerKey
	          , @cVessel       = C.Vessel
	   FROM dbo.PalletDetail PD WITH (NOLOCK)
	   INNER JOIN dbo.Container C WITH (NOLOCK) ON C.MBOLKey = PD.UserDefine03
	   WHERE PD.PalletKey = @cPalletID
	   
	   
      IF ISNULL(@cVessel,'') <> ''
	   BEGIN
	      IF @cVessel <> @cTruckID
	      BEGIN
   	      SET @nErrNo = 78272
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TruckIDNotMatch'
            GOTO Step_4_Fail
         END
	   END
	   
	   IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletID AND Status = '3')
	   BEGIN
		   SET @nErrNo = 78274
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidPalletID'
         GOTO Step_4_Fail
	   END
	   
	   
	   BEGIN TRAN 
	      
	   DELETE FROM dbo.ContainerDetail
	   WHERE ContainerKEy = @cContainerKey
	   AND PalletKey = @cPalletID
	   
	   IF @@ERROR <> 0 
	   BEGIN
	      ROLLBACK TRAN
	      SET @nErrNo = 78263
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelContDetFail'
         GOTO Step_4_Fail
	   END
		
		UPDATE dbo.Pallet
		SET Status = '3'
		WHERE PalletKey = @cPalletID
		
		IF @@ERROR <> 0 
	   BEGIN
	      ROLLBACK TRAN
	      SET @nErrNo = 78264
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPalletFail'
         GOTO Step_4_Fail
	   END
	   
	   UPDATE dbo.PalletDetail
		SET Status = '3'
		WHERE PalletKey = @cPalletID
		
		IF @@ERROR <> 0 
	   BEGIN
	      ROLLBACK TRAN
	      SET @nErrNo = 78265
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPalletDetFail'
         GOTO Step_4_Fail
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
        @cID         = @cPalletID,
        --@cRefNo2     = @cPalletID
        @nStep       = @nStep

      SET @cOutField02 = ''        
		
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
        -- Prepare Previous Screen Variable
		 SET @cOutField01 = @cTruckID
		 SET @cOutField02 = ''
		    
       -- GOTO Previous Screen
		 SET @nScn = @nScn - 2
	    SET @nStep = @nStep - 2
   END
	GOTO Quit

   STEP_4_FAIL:
   BEGIN
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = ''
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 5. Scn = 3334. 
   TruckID   (field01)
   PalletID  (field02, input)
   
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   
	   	
		SET @cPalletID = ISNULL(RTRIM(@cInField02),'')
		
		IF @cPalletID = ''
		BEGIN
		   SET @nErrNo = 78266
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PalletID Req'
         GOTO Step_5_Fail
	   END
	   
	   IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
	                   WHERE PalletKey= @cPalletID
	                   AND Status = '3')
	   BEGIN
	      SET @nErrNo = 78269
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid PalletID'
         GOTO Step_5_Fail
	   END
	   
	   IF EXISTS ( SELECT 1 FROM dbo.ContainerDetail WITH (NOLOCK)
	               WHERE PalletKey = @cPalletID )
      BEGIN
         SET @nErrNo = 78273
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PalletScannedB4'
         GOTO Step_5_Fail
      END	               
	                
	   
	                
	   
	   IF NOT EXISTS ( SELECT 1 FROM dbo.Container WITH (NOLOCK) 
                      WHERE Vessel = @cTruckID
                      AND Status = '0' ) 
      BEGIN
         EXECUTE nspg_GetKey  
          'ContainerKey',  
          10,  
          @cContainerKey  OUTPUT,  
          @bSuccess    OUTPUT,  
          @nErrNo      OUTPUT,  
          @cErrMsg     OUTPUT  
     
         IF @bSuccess <> 1  
         BEGIN  
            GOTO Step_5_Fail  
         END  
         
         SET @cOtherReference = ''
         SET @cMBOLKey = ''
         SET @cRoute = ''
         SET @cContainerType = ''
         
         SELECT 
                  @cMBOLKey = UserDefine03 
                , @cOtherReference = UserDefine02
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE PalletKey = @cPalletID

         
         SELECT @cRoute = PlaceOfLoadingQualifier 
         FROM dbo.MBOL WITH (NOLOCK)         
         WHERE MBOLKey = @cMBOLKey
         
         
         SELECT @cContainerType = CASE WHEN UDF01 = 'INDIRECT' THEN UDF01
                                  ELSE 'DIRECT'
                                  END
         FROM dbo.Codelkup WITH (NOLOCK)
         WHERE LISTNAME = 'PLACEQUAL'
         AND CODE = @cRoute
         
         
         
         INSERT INTO dbo.CONTAINER 
         (ContainerKey, OtherReference, ContainerType, MBOLKey, Vessel, Status)
         VALUES 
         (@cContainerKey, @cOtherReference, @cContainerType, @cMBOLKey, @cTruckID, '0')
         
         IF @@ERROR <> 0 
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 78267
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsContainerFail
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_5_Fail
         END
      END
      ELSE
      BEGIN
         
         SELECT 
                  @cMBOLKey = UserDefine03 
                , @cOtherReference = UserDefine02
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE PalletKey = @cPalletID
         
         SELECT @cContainerKey = ContainerKey
         FROM dbo.Container WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLKey
         AND Status IN ('0','5')
         
      END
      
      IF ISNULL(@cContainerKey,'') = ''
      BEGIN
         SET @nErrNo = 78276
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidContainerKey
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_5_Fail
      END
      
      
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.ContainerDetail WITH (NOLOCK)
                      WHERE PalletKey = @cPalletID)
      BEGIN                         
         INSERT INTO dbo.ContainerDetail 
         (ContainerKey, ContainerLinenumber, PalletKey)
         VALUES 
         (@cContainerKey, 0, @cPalletID)
   
         IF @@ERROR <> 0 
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 78271
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsContainerDetFail
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_5_Fail
         END         
      END
   
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '3', 
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cTruckID    = @cTruckID,
        --@cRefNo1     = @cTruckID,
        @cID         = @cPalletID,
        --@cRefNo2     = @cPalletID
        @nStep       = @nStep

      SET @nScanned = 0 
      
      SELECT @nScanned = Count(CD.PalletKey)
      FROM dbo.Container C WITH (NOLOCK)
      INNER JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey
      WHERE C.Vessel = @cTruckID
      AND C.ContainerKey = @cContainerKey 
      AND C.Status = '0'
      
      		
      SET @cOutField02 = ''         
      SET @cOutField03 = @nScanned     
		
		
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
        -- Prepare Previous Screen Variable
		 SET @cOutField01 = @cTruckID
		 SET @cOutField02 = ''
		    
       -- GOTO Previous Screen
		 SET @nScn = @nScn - 3
	    SET @nStep = @nStep - 3
   END
	GOTO Quit

   STEP_5_FAIL:
   BEGIN
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = ''
   END
   

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
      
      V_Integer1 = @nScanned,
  
      V_String1 = @cTruckID,
      V_String2 = @cPalletID,
      V_String3 = @cContainerKey, 
	   --V_String4 = @nScanned,
      
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