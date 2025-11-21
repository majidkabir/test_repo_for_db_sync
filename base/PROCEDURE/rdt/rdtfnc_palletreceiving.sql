SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: IDSUK Pallet Receiving SOS#262666                                 */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2012-12-04 1.0  ChewKP     Created                                         */
/* 2016-09-30 1.1  Ung        Performance tuning                              */
/* 2018-06-07 1.2  James      WMS5314 - Add rdt_decode sp (james01)           */
/* 2018-11-07 1.3  TungGH     Performance                                     */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PalletReceiving] (
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
	@cContainerKey NVARCHAR( 10),
	@cPalletID     NVARCHAR( 20),
	@nToteCount    INT,
   @nTotalSystemToteCount INT,
	@cTotalTote    INT,
	@nTotalTote    INT,
	@cToteNo       NVARCHAR(28),
   @cDecodeSP     NVARCHAR( 20),
   @cBarcode      NVARCHAR( 60),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX),

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
   
	@cTruckID      = V_String1,
	@cSealNo       = V_String2,
	@cContainerKey = V_String3, 
	@cPalletID     = V_String4,
   @cDecodeSP     = V_String7,
   
   @nToteCount              = V_Integer1,
   @nTotalSystemToteCount   = V_Integer2, 

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



IF @nFunc = 1719  -- Pallet Receiving
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Pallet Receiving
   IF @nStep = 1 GOTO Step_1   -- Scn = 3340. Truck ID
	IF @nStep = 2 GOTO Step_2   -- Scn = 3341. Seal No
	IF @nStep = 3 GOTO Step_3   -- Scn = 3342. Pallet ID
	IF @nStep = 4 GOTO Step_4   -- Scn = 3343. Total Totes / Boxes
	IF @nStep = 5 GOTO Step_5   -- Scn = 3344. Tote No
	IF @nStep = 6 GOTO Step_6   -- Scn = 3345. Options (Accept Pallet)
	
	
   
END

--IF @nStep = 3
--BEGIN
--	SET @cErrMsg = 'STEP 3'
--	GOTO QUIT
--END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1719. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
	SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerkey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

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
	SET @nScn = 3340
	SET @nStep = 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3340. 
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
         SET @nErrNo = 78301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrucKID req
         GOTO Step_1_Fail
      END
      
      
      IF NOT EXISTS (SELECT 1 FROM dbo.IDS_VEHICLE WITH (NOLOCK) WHERE VehicleNumber = @cTruckID )
      BEGIN
         SET @nErrNo = 78302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid TruckID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Container WITH (NOLOCK)
                      WHERE Vessel = @cTruckID ) 
      BEGIN
         SET @nErrNo = 78304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TruckIDNotExist
         GOTO Step_1_Fail
      END                      
      
      SET @cContainerKey = ''
      
      SELECT @cContainerKey = ContainerKey
      FROM dbo.Container WITH (NOLOCK)
      WHERE Vessel = @cTruckId
      
      IF EXISTS ( SELECT 1 FROM dbo.Container WITH (NOLOCK)
                      WHERE ContainerKey = @cContainerKey
                      AND Status = '9' ) 
      BEGIN
            SET @nErrNo = 78312
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'AllPalletReceived'
            GOTO Step_3_Fail
      END   
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Container WITH (NOLOCK)
                      WHERE ContainerKey = @cContainerKey
                      AND Status = '5')
      BEGIN
            SET @nErrNo = 78314
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TruckNotClosed'
            GOTO Step_3_Fail
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
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 3341. 
   TruckID   (field01)
   SealNo   (field02, input)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   
	   	
		SET @cSealNo = ISNULL(RTRIM(@cInField02),'')
		
		IF ISNULL(@cSealNo, '') = ''
      BEGIN
         SET @nErrNo = 78303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SealNo Req'
         GOTO Step_2_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Container WITH (NOLOCK)
                      WHERE Vessel = @cTruckID
                      AND Seal01 = @cSealNo ) 
      BEGIN
         
         UPDATE dbo.Container 
         SET Seal02 = @cSealNo
         WHERE ContainerKey = @cContainerKey
         AND Vessel = @cTruckID
         
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 78305
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdContainerFail'
            GOTO Step_2_Fail
         END
         
      END                      
      
      
      

      SET @cOutField01 = @cTruckID
      SET @cOutField02 = @cSealNo
      SET @cOutField03 = ''
   		 
      -- GOTO Prev Screen
   	SET @nScn = @nScn + 1
   	SET @nStep = @nStep + 1

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
Step 3. Scn = 3342. 
   
   TruckID    (Field01)
   SealNo     (Field02)
   PalletID   (Field03, Input)
   
   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 
   BEGIN
		
      SET @cPalletID = ISNULL(RTRIM(@cInField03),'')
      SET @cBarcode = ISNULL(RTRIM(@cInField03),'')
      
      IF @cPalletID = ''
      BEGIN
            SET @nErrNo = 78306
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PalletID Req'
            GOTO Step_3_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cID     = @cPalletID   OUTPUT, 
               @cUPC    = @cSKU        OUTPUT, 
               @nQTY    = @nQTY        OUTPUT, 
               @nErrNo  = @nErrNo      OUTPUT, 
               @cErrMsg = @cErrMsg     OUTPUT,
               @cType   = 'ID'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cTruckID  OUTPUT, @cSealNo    OUTPUT, @cPalletID     OUTPUT, ' +
               ' @nTotalTote     OUTPUT, @cToteNo        OUTPUT, @cOption   OUTPUT,  ' +
               ' @nErrNo   OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cTruckID     NVARCHAR( 20)  OUTPUT, ' +
               ' @cSealNo      NVARCHAR( 20)  OUTPUT, ' +
               ' @cPalletID    NVARCHAR( 20)  OUTPUT, ' +
               ' @nTotalTote   INT            OUTPUT, ' +
               ' @cToteNo      NVARCHAR( 28)  OUTPUT, ' +
               ' @cOption      NVARCHAR( 1)   OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, 
               @cTruckID      OUTPUT, @cSealNo     OUTPUT, @cPalletID      OUTPUT, 
               @nTotalTote    OUTPUT, @cToteNo     OUTPUT, @cOption        OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_3_Fail
      END

      IF EXISTS ( SELECT 1 FROM dbo.Container WITH (NOLOCK)
                      WHERE ContainerKey = @cContainerKey
                      AND Status = '9' ) 
      BEGIN
            SET @nErrNo = 78308
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'AllPalletReceived'
            GOTO Step_3_Fail
      END                       
      
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                      WHERE PalletKey = @cPalletID
	                   AND Status = '5')
	   BEGIN
	      SET @nErrNo = 78307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid PalletID'
         GOTO Step_3_Fail
	   END
	   
	   IF NOT EXISTS ( SELECT 1 FROM dbo.ContainerDetail WITH (NOLOCK)
	                   WHERE PalletKey = @cPalletID ) 
      BEGIN
	      SET @nErrNo = 78315
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid PalletID'
         GOTO Step_3_Fail
	   END	                   
	   
--	   BEGIN TRAN
--	   
--	   UPDATE dbo.PalletDetail 
--	   SET Status = '9'
--	   WHERE PalletKey = @cPalletID
--	   AND Status = '5'
--	   
--	   IF @@ERROR <> 0 
--	   BEGIN
--	      SET @nErrNo = 78309
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletFail'
--         GOTO Step_3_Fail
--	   END
--	   
--	   UPDATE dbo.Pallet
--	   SET Status = '9'
--	   WHERE PalletKey = @cPalletID
--	   AND Status = '5'
--	   
--	   IF @@ERROR <> 0 
--	   BEGIN
--	      SET @nErrNo = 78311
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletDetFail'
--         GOTO Step_3_Fail
--	   END
--	   
--	   COMMIT TRAN
--	   
--	   IF NOT EXISTS ( SELECT 1 FROM dbo.ContainerDetail CD WITH (NOLOCK)
--	                   INNER JOIN dbo.Pallet P WITH (NOLOCK) ON P.PalletKey = CD.PalletKey
--	                   WHERE CD.ContainerKey = @cContainerKey
--	                   AND P.Status <> '9' )
--      BEGIN
--         	UPDATE dbo.Container
--      	   SET Status = '9'
--      	   WHERE ContainerKey = @cContainerKey
--      	   AND Status = '5'
--      	   
--      	   IF @@ERROR <> 0 
--      	   BEGIN
--      	      SET @nErrNo = 78310
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdContainerFail'
--               GOTO Step_3_Fail
--      	   END
--      	   
--      	   SET @cOutField01 = ''
--      	   
--      	   SET @nErrNo = 78313
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReceiveCompleted'
--            
--            -- GOTO Next Screen
--		      SET @nScn = @nScn - 2
--	         SET @nStep = @nStep - 2
--      	   GOTO QUIT 
--      END	            
--      
--      EXEC RDT.rdt_STD_EventLog
--        @cActionType = '3', 
--        @cUserID     = @cUserName,
--        @nMobileNo   = @nMobile,
--        @nFunctionID = @nFunc,
--        @cFacility   = @cFacility,
--        @cStorerKey  = @cStorerkey,
--        @cDeviceID   = @cTruckID,
--        @cID         = @cPalletID,
--        @nStep       = @nStep            
      
      -- Prepare Next Screen Variable
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = @cSealNo
      SET @cOutField03 = @cPalletID
      SET @cOutField04 = ''
      
      
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

   STEP_3_FAIL:
   BEGIN
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = @cSealNo
      SET @cOutField03 = ''
   END
   GOTO Quit

END 
GOTO QUIT

/********************************************************************************
Step 4. Scn = 3343. 
   
   TruckID    (Field01)
   SealNo     (Field02)
   PalletID   (Field03)
   Total Totes/Boxes    (Field04, input)
   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 
   BEGIN
		
      SET @cTotalTote = ISNULL(RTRIM(@cInField04),'')
      
      IF @cTotalTote = ''
      BEGIN
            SET @nErrNo = 78316
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty Req'
            GOTO Step_4_Fail
      END
      
      IF rdt.rdtIsValidQTY( @cTotalTote, 0) = 0 
      BEGIN
            SET @nErrNo = 78317
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Qty'
            GOTO Step_4_Fail
      END
      
      SET @nTotalTote = CAST ( @cTotalTote AS NVARCHAR(5))
      
      SELECT @nTotalSystemToteCount = COUNT (DISTINCT PD.UserDefine05) 
      FROM dbo.PALLETDETAIL PD WITH (NOLOCK)
      INNER JOIN dbo.CONTAINER C WITH (NOLOCK) ON C.MBOLKEY = PD.UserDefine03 
      INNER JOIN dbo.CONTAINERDETAIL CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey AND CD.PALLETKEY = PD.PALLETKEY
      WHERE PD.PalletKey = @cPalletID
      AND C.Vessel = @cTruckID
      --AND C.Seal01 = @cSealNo
      
      
      
      IF @nTotalSystemToteCount = @nTotalTote
      BEGIN 
      
   	   BEGIN TRAN
   	   
   	   UPDATE dbo.PalletDetail 
   	   SET Status = '9'
   	   WHERE PalletKey = @cPalletID
   	   AND Status = '5'
   	   
   	   IF @@ERROR <> 0 
   	   BEGIN
   	      SET @nErrNo = 78309
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletFail'
            GOTO Step_4_Fail
   	   END
   	   
   	   UPDATE dbo.Pallet
   	   SET Status = '9'
   	   WHERE PalletKey = @cPalletID
   	   AND Status = '5'
   	   
   	   IF @@ERROR <> 0 
   	   BEGIN
   	      SET @nErrNo = 78311
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletDetFail'
            GOTO Step_4_Fail
   	   END
   	   
   	   COMMIT TRAN
   	   
   	   IF NOT EXISTS ( SELECT 1 FROM dbo.ContainerDetail CD WITH (NOLOCK)
   	                   INNER JOIN dbo.Pallet P WITH (NOLOCK) ON P.PalletKey = CD.PalletKey
   	                   WHERE CD.ContainerKey = @cContainerKey
   	                   AND P.Status <> '9' )
         BEGIN
            	UPDATE dbo.Container
         	   SET Status = '9'
         	   WHERE ContainerKey = @cContainerKey
         	   AND Status = '5'
         	   
         	   IF @@ERROR <> 0 
         	   BEGIN
         	      SET @nErrNo = 78310
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdContainerFail'
                  GOTO Step_4_Fail
         	   END
         	   
         	   SET @cOutField01 = ''
         	   
         	   SET @nErrNo = 78313
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReceiveCompleted'
               
               -- GOTO Next Screen
   		      SET @nScn = @nScn - 3
   	         SET @nStep = @nStep - 3
         	   GOTO QUIT 
         END	            
         
         EXEC RDT.rdt_STD_EventLog
           @cActionType = '3', 
           @cUserID     = @cUserName,
           @nMobileNo   = @nMobile,
           @nFunctionID = @nFunc,
           @cFacility   = @cFacility,
           @cStorerKey  = @cStorerkey,
           @cTruckID    = @cTruckID,
           @cID         = @cPalletID,
           @nStep       = @nStep             
      
--         -- Prepare Next Screen Variable
--         SET @cOutField01 = @cTruckID
--         SET @cOutField02 = @cSealNo
--         SET @cOutField03 = ''
--      
--         -- GOTO Previous Screen
--		   SET @nScn = @nScn - 1
--	      SET @nStep = @nStep - 1
         
         
      END
      ELSE
      BEGIN
         
         
         
          -- Prepare Next Screen Variable
         SET @cOutField01 = @cTruckID
         SET @cOutField02 = @cSealNo
         SET @cOutField03 = @cPalletID
         SET @cOutField04 = ''
         SET @cOutField05 = '0'
         SET @cOutField06 = @nTotalSystemToteCount
         
         -- GOTO Next Screen
		   SET @nScn = @nScn + 1
	      SET @nStep = @nStep + 1
	      
      END
      
      
      
      
	END  -- Inputkey = 1
	
	IF @nInputKey = 0 
   BEGIN
        -- Prepare Previous Screen Variable
		 SET @cOutField01 = @cTruckID
       SET @cOutField02 = @cSealNo
       SET @cOutField03 = ''
		    
       -- GOTO Previous Screen
		 SET @nScn = @nScn - 1
	    SET @nStep = @nStep - 1
	    
   END
	GOTO Quit

   STEP_4_FAIL:
   BEGIN
      SET @cOutField04 = ''
      
   END
   GOTO Quit

END 
GOTO QUIT


/********************************************************************************
Step 5. Scn = 3344. 
   
   TruckID    (Field01)
   SealNo     (Field02)
   PalletID   (Field03)
   ToteNo     (Field04, Input)
   Scanned    (Field05) / (Field06)
   
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 
   BEGIN
		
      SET @cToteNo = ISNULL(RTRIM(@cInField04),'')
      
      IF @cToteNo = ''
      BEGIN
            SET @nErrNo = 78318
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteNo Req'
            GOTO Step_5_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Container C WITH (NOLOCK)
                      INNER JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON CD.ContainerKey = C.ContainerKey 
                      INNER JOIN dbo.Pallet P WITH (NOLOCK) ON P.PalletKey = CD.PalletKey
                      INNER JOIN dbo.PalletDetail PD WITH (NOLOCK) ON PD.PalletKEy = P.PalletKey
                      WHERE C.ContainerKey = @cContainerKey
                      AND C.Status = '5' 
                      AND PD.UserDefine05 = @cToteNo ) 
      BEGIN
            SET @nErrNo = 78319
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Tote'
            GOTO Step_5_Fail
      END                       
       
	   
	   BEGIN TRAN
	   
	   UPDATE dbo.PalletDetail 
	   SET Status = '9'
	   WHERE PalletKey = @cPalletID
	   AND Status = '5'
	   AND UserDefine05 = @cToteNo
	   
	   IF @@ERROR <> 0 
	   BEGIN
	      SET @nErrNo = 78320
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletDetFail'
         ROLLBACK TRAN
         GOTO Step_5_Fail
	   END
	   
	   
	   IF NOT EXISTS ( SELECT 1 FROM PALLETDETAIL PD WITH (NOLOCK)
	                   WHERE PD.Status = '5'
	                   AND PD.PalletKey = @cPalletID ) 
      BEGIN	                   
   	   UPDATE dbo.Pallet
   	   SET Status = '9'
   	   WHERE PalletKey = @cPalletID
   	   AND Status = '5'
   	   
   	   IF @@ERROR <> 0 
   	   BEGIN
   	      SET @nErrNo = 78321
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletFail'
            ROLLBACK TRAN
            GOTO Step_5_Fail
   	   END
	   END
	   
	   
	   
	   IF NOT EXISTS ( SELECT 1 FROM dbo.ContainerDetail CD WITH (NOLOCK)
	                   INNER JOIN dbo.Pallet P WITH (NOLOCK) ON P.PalletKey = CD.PalletKey
	                   WHERE CD.ContainerKey = @cContainerKey
	                   AND P.Status <> '9' )
      BEGIN
         	UPDATE dbo.Container
      	   SET Status = '9'
      	   WHERE ContainerKey = @cContainerKey
      	   AND Status = '5'
      	   
      	   IF @@ERROR <> 0 
      	   BEGIN
      	      SET @nErrNo = 78322
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdContainerFail'
               ROLLBACK TRAN
               GOTO Step_5_Fail
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
        @cID         = @cPalletID,
        @nStep       = @nStep   
      
      
      -- Prepare Next Screen Variable
      SET @nToteCount = 0
      
      SELECT @nToteCount = COUNT(DISTINCT UserDefine05)
      FROM PalletDetail WITH (NOLOCK)
      WHERE PalletKey = @cPalletID
      AND Status = '9'
      
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = @cSealNo
      SET @cOutField03 = @cPalletID
      SET @cOutField04 = ''
      SET @cOutField05 = @nToteCount
      SET @cOutField06 = @nTotalSystemToteCount
      
      
      
      
      
	END  -- Inputkey = 1
	
	IF @nInputKey = 0 
   BEGIN
        
       
       IF @nToteCount <> @nTotalSystemToteCount
       BEGIN
         
          -- Prepare Previous Screen Variable
   		 SET @cOutField01 = @cPalletID
   		 SET @cOutField02 = ''
   		 
          -- GOTO Previous Screen
   		 SET @nScn = @nScn + 1
   	    SET @nStep = @nStep + 1
	    END
	    ELSE
	    BEGIN
	       -- Prepare Previous Screen Variable
   		 SET @cOutField01 = @cTruckID
   		 SET @cOutField02 = ''
   		 
   		 SET @nErrNo = 78323
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReceiveCompleted'
   		    
          -- GOTO Previous Screen
   		 SET @nScn = @nScn - 4
   	    SET @nStep = @nStep - 4
	      
	      
	    END
   END
	GOTO Quit

   STEP_5_FAIL:
   BEGIN
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = @cSealNo
      SET @cOutField03 = @cPalletID
      SET @cOutField04 = ''
   END
   GOTO Quit

END 
GOTO QUIT


/********************************************************************************
Step 6. Scn = 3345. 
   
   PalletID   (Field01)
   Option     (Field02, input)
   
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 
   BEGIN
		
      SET @cOption = ISNULL(RTRIM(@cInField02),'')
      
      IF @cOption = ''
      BEGIN
            SET @nErrNo = 78324
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'
            GOTO Step_6_Fail
      END
      
      IF @cOption NOT IN ( '1','9')
      BEGIN
            SET @nErrNo = 78325
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
            GOTO Step_6_Fail
      END
      
      IF @cOption = '1'
      BEGIN
         
            
--         UPDATE dbo.PalletDetail 
--         SET Status = '9'
--         WHERE PalletKey = @cPalletID
--         AND Status = '5'
--         
--         IF @@ERROR <> 0 
--         BEGIN
--              SET @nErrNo = 78326
--              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletDetFail'
--              ROLLBACK TRAN
--              GOTO Step_3_Fail
--         END
   
         UPDATE dbo.Pallet
         SET Status = '9'
           , TrafficCop = NULL
         WHERE PalletKey = @cPalletID
         AND Status = '5'
         
         IF @@ERROR <> 0 
         BEGIN
              SET @nErrNo = 78327
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPalletDetFail'
              ROLLBACK TRAN
              GOTO Step_3_Fail
         END
      
         
   
--         IF NOT EXISTS ( SELECT 1 FROM dbo.ContainerDetail CD WITH (NOLOCK)
--                      INNER JOIN dbo.Pallet P WITH (NOLOCK) ON P.PalletKey = CD.PalletKey
--                      WHERE CD.ContainerKey = @cContainerKey
--                      AND P.Status <> '9' )
--         BEGIN
           	UPDATE dbo.Container
        	   SET Status = '9'
        	   WHERE ContainerKey = @cContainerKey
        	   AND Status = '5'
        	   
        	   IF @@ERROR <> 0 
        	   BEGIN
        	      SET @nErrNo = 78328
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdContainerFail'
                 GOTO Step_3_Fail
        	   END
        	   
        	   SET @cOutField01 = ''
        	   
        	   SET @nErrNo = 78329
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReceiveCompleted'
              
            -- GOTO Next Screen
            SET @nScn = @nScn - 5
            SET @nStep = @nStep - 5
        	   
--         END	            
     
         EXEC RDT.rdt_STD_EventLog
          @cActionType = '3', 
          @cUserID     = @cUserName,
          @nMobileNo   = @nMobile,
          @nFunctionID = @nFunc,
          @cFacility   = @cFacility,
          @cStorerKey  = @cStorerkey,
          @cTruckID    = @cTruckID,
          @cID         = @cPalletID,
          @nStep       = @nStep           
         
        
         
      END
      ELSE IF @cOption = '9'
      BEGIN
            -- Prepare Next Screen Variable
            SET @cOutField01 = @cTruckID
            SET @cOutField02 = @cSealNo
            SET @cOutField03 = @cPalletID
            SET @cOutField04 = ''
            SET @cOutField05 = @nToteCount
            SET @cOutField06 = @nTotalSystemToteCount
            
            
            -- GOTO Next Screen
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
            
            
      END 

      
      
      
      
      
	END  -- Inputkey = 1
	GOTO QUIT 
	
--	IF @nInputKey = 0 
--   BEGIN
--        -- Prepare Previous Screen Variable
--		 SET @cOutField01 = @cTruckID
--		 SET @cOutField02 = ''
--		    
--       -- GOTO Previous Screen
--		 SET @nScn = @nScn - 1
--	    SET @nStep = @nStep - 1
--   END
--	GOTO Quit

   STEP_6_FAIL:
   BEGIN
      
      SET @cOutField02 = ''
      
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
  
      V_String1 = @cTruckID      ,
      V_String2 = @cSealNo       ,
      V_String3 = @cContainerKey , 
	   V_String4 = @cPalletID     ,
      V_String7 = @cDecodeSP     ,
      
      V_Integer1 = @nToteCount   , 
      V_Integer2 = @nTotalSystemToteCount ,
      
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