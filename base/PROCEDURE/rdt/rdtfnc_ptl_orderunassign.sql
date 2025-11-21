SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: IDSUK Put To Light Order Unassignment SOS#269034                  */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2013-02-21 1.0  ChewKP     Created                                         */
/* 2013-06-11 1.1  ChewKP     SOS#280749 PTL Enhancement (ChewKP01)           */
/* 2014-07-10 1.2  James      SOS315448-Unassign filter by pickzone (james01) */
/*                            Add extended info                               */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PTL_OrderUnassign] (
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
   
   @cCartID       NVARCHAR(10),
   @cOrderKey     NVARCHAR(10),
   @cLightLoc     NVARCHAR(10),
   @cToteID       NVARCHAR(20),
	@cPickSlipNo   NVARCHAR(10),
	@cLightLocKey  NVARCHAR(10),
	@cEmptyLoc     NVARCHAR(5), 
	@nCartLocCounter INT,
	@nCountLoc       INT,
	@nCountLocLog    INT,
	@cExternOrderKey NVARCHAR(30),
	
	@cPTLPKZoneReq    NVARCHAR( 1),     -- (james01)
	@cPickZone        NVARCHAR( 10),    -- (james01)
   @cExtendedInfo    NVARCHAR( 20),    -- (james01)
   @cExtendedInfoSP  NVARCHAR( 20),    -- (james01)
   @cSQL             NVARCHAR( MAX),   -- (james01)
   @cSQLParam        NVARCHAR( MAX),   -- (james01)
      
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
   
	@cCartID     = V_String1,
	

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



IF @nFunc = 812  -- PTL Order Unassignment
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTL Order Unassignment
   IF @nStep = 1 GOTO Step_1   -- Scn = 3470. Cart ID
	IF @nStep = 2 GOTO Step_2   -- Scn = 3471. OrderKey, LightLoc, ExterOrderKey
	IF @nStep = 3 GOTO Step_3   -- Scn = 3472. Message
	
	
	
   
END

--IF @nStep = 3
--BEGIN
--	SET @cErrMsg = 'STEP 3'
--	GOTO QUIT
--END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 812. Menu
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
     @cStorerKey  = @cStorerkey
     
   
   -- Init screen
   SET @cOutField01 = '' 
   
   SET @cOrderKey = ''
   SET @cExternOrderKey = ''
   SET @cLightLoc = ''
	

   -- Set the entry point
	SET @nScn = 3470
	SET @nStep = 1
	
	EXEC rdt.rdtSetFocusField @nMobile, 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3470. 
   CartID (Input , Field01)
   
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cCartID = ISNULL(RTRIM(@cInField01),'')
		
      -- Validate blank
      IF ISNULL(RTRIM(@cCartID), '') = ''
      BEGIN
         SET @nErrNo = 79651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartID req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      
      IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID AND Status = '1' )
      BEGIN
         SET @nErrNo = 79652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CartID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile D WITH (NOLOCK)
                      INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey 
                      WHERE D.DeviceID = @cCartID
                      AND DL.Status = '1'
                      AND D.Status = '1' ) 
      BEGIN
         SET @nErrNo = 79659
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoOrderToUnAssign
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END                      

      -- Get stored proc name for extended info (james01)
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''
            
      -- Extended info (james01)
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nStep, @nInputKey, @cStorerKey, @cCartID, @cToteID, @cExtendedInfo OUTPUT '
            
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cCartID         NVARCHAR( 10), ' +
               '@cToteID         NVARCHAR( 20), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nStep, @nInputKey, @cStorerKey, @cCartID, @cToteID, @cExtendedInfo OUTPUT
         END
      END
      
		 -- Prepare Next Screen Variable
		 SET @cOutField01 = @cCartID
		 SET @cOutField02 = ''
		 SET @cOutField03 = ''
		 SET @cOutField04 = ''
		 SET @cOutField05 = @cExtendedInfo

		 -- GOTO Next Screen
		 SET @nScn = @nScn + 1
	    SET @nStep = @nStep + 1
	    
	    EXEC rdt.rdtSetFocusField @nMobile, 2
	    
		
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
        @cStorerKey  = @cStorerkey
        
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
Step 2. Scn = 3471. 
   CartID   (field01)
   OrderKey        (field02, input)
   Cart Position   (field03, input)
   ExternOrderKey  (field04, input)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   
	   	
		SET @cOrderKey = ISNULL(RTRIM(@cInField02),'')
		SET @cLightLoc = ISNULL(RTRIM(@cInField03),'')
		SET @cExternOrderKey = ISNULL(RTRIM(@cInField04),'')
		
		IF ISNULL(@cOrderKey, '') = '' AND ISNULL(@cLightLoc, '') = '' AND ISNULL(@cExternOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 79653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoFieldScanned'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END
      
      
      IF ISNULL(@cOrderKey, '') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey
                  AND Status >= '1'
                  AND Status < '5')
         BEGIN
               SET @nErrNo = 79654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Order Status
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_2_Fail
         END
         
         
         SET @cPickSlipNo = ''
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader PH WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.WaveKey = O.UserDefine09 AND PH.OrderKey = O.OrderKey
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    
         WHERE OD.StorerKey = @cStorerKey    
         AND O.OrderKey = @cOrderKey
         AND PH.Status = '0'
               
         IF ISNULL(@cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 79655
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKSLIPNotPrinted
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_2_Fail
         END
         ELSE  -- pickslip printed, check if scanned out
         BEGIN
            -- Check if pickslip scanned out
            IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                       WHERE PickSlipNo = @cPickSlipNo
                        AND ScanOutDate IS NOT NULL)
            BEGIN
               SET @nErrNo = 79656
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Scanned Out
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_2_Fail
            END
         END
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfile DP WITH (NOLOCK)
                         INNER JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DP.DeviceProfileKey = DPL.DeviceProfileKey 
                         WHERE DP.DeviceID = @cCartID
                         AND DPL.OrderKey = @cOrderKey ) 
         BEGIN
               SET @nErrNo = 79660
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOrderOnCart
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_2_Fail
         END                         
         
         
         SELECT @cExternOrderKey = ExternOrderKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
      END            

      IF @cLightLoc <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID AND DevicePosition = @cLightLoc AND Status = '1') 
         BEGIN
            SET @nErrNo = 79657
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Position'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END
         
         IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfileLog DPL WITH (NOLOCK) 
                        INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DeviceProfileKey = DPL.DeviceProfileKey 
                        WHERE DP.DeviceID = @cCartID 
                        AND DP.DevicePosition = @cLightLoc 
                        AND DPL.Status = '1') 
         BEGIN
            SET @nErrNo = 79661
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PositionNotAssign'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END
         
         -- (ChewKP01)
         SELECT TOP 1 @cOrderKey = O.OrderKey
              , @cExternOrderKey = O.ExternOrderKey
         FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey 
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = DL.OrderKey
         WHERE D.DeviceID = @cCartID
         AND   D.DevicePosition = @cLightLoc
         AND   D.Status = '1'
         ORDER BY DL.DeviceProfileLogKey DESC
         
      END
      
      
      IF @cExternOrderKey <> ''
      BEGIN      
         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog LD WITH (NOLOCK) 
                         INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey
                         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = LD.OrderKey
                         WHERE LL.DeviceID = @cCartID
                         AND   LD.Status = '1'
                         AND   O.ExternOrderKey = @cExternOrderKey) 
         BEGIN
            SET @nErrNo = 79658
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NotExistInCart'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Step_2_Fail
         END      
         
         SELECT @cOrderKey = OrderKey 
         FROM dbo.Orders WITH (NOLOCK)
         WHERE ExternOrderKey = @cExternOrderKey
      END

      -- (james01)
      SET @cPTLPKZoneReq = ''
      SET @cPTLPKZoneReq = rdt.rdtGetConfig( @nFunc, 'PTLPicKZoneReq', @cStorerKey)  

      IF ISNULL( @cPTLPKZoneReq, '') <> ''
      BEGIN
         SET @cPickZone = ''
         SELECT TOP 1 @cPickZone = DL.UserDefine10 
         FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
         WHERE D.DeviceID = @cCartID
         AND   DL.Status = '1'
         AND   D.DevicePosition = CASE WHEN @cLightLoc = '' THEN DevicePosition ELSE @cLightLoc END
         AND   DL.OrderKey = CASE WHEN @cOrderKey = '' THEN OrderKey ELSE @cOrderKey END
         ORDER BY DL.UserDefine10 DESC -- with pickzone come first


         -- If RDT config is turn on and pickzone is blank then prompt error
         IF @cPickZone = ''
         BEGIN
            SET @nErrNo = 79662
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NotExistInCart'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Step_2_Fail
         END      
      END

        -- Delete from LightLocLog Table
      SET @cLightLocKey = ''
      
      SELECT @cLightLocKey = DL.DeviceProfileKey
           , @cLightLoc    = D.DevicePosition
      FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
      WHERE D.DeviceID = @cCartID
      AND D.DevicePosition = CASE WHEN @cLightLoc = '' THEN DevicePosition ELSE @cLightLoc END
      AND DL.OrderKey = CASE WHEN @cOrderKey = '' THEN OrderKey ELSE @cOrderKey END
      AND DL.UserDefine10 = CASE WHEN ISNULL( @cPTLPKZoneReq, '') <> '' THEN @cPickZone ELSE DL.UserDefine10 END  -- (james01)
      
      
      DELETE FROM dbo.DeviceProfileLog  
      WHERE DeviceProfileKey = @cLightLocKey
      AND Status = '1'
      
      IF @@ERROR <> 0 OR @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 79562
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLightLocFail'
         GOTO Step_2_Fail
      END
      
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '3', 
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cRefNo1     = @cCartID,
        @cRefNo2     = @cLightLoc,
        @cOrderKey   = @cOrderKey,
        @cRefNo3     = @cExternOrderKey
        
      
		
   	-- Prepare Next Screen Variable
      SET @cOutField01 = @cCartID
      SET @cOutField02 = @cLightLoc
      SET @cOutField03 = @cOrderKey
      SET @cOutField04 = @cExternOrderKey
      
      -- GOTO Previous Screen
   	SET @nScn = @nScn + 1
   	SET @nStep = @nStep + 1
      
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
       
      -- Prepare Previous Screen Variable
   	SET @cOutField01 = ''
   	   
      -- GOTO Previous Screen
   	SET @nScn = @nScn - 1
   	SET @nStep = @nStep - 1
      
      EXEC rdt.rdtSetFocusField @nMobile, 1
       
	    
	    
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField01 = @cCartID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
   END
   

END 
GOTO QUIT


/********************************************************************************
Step 3. Scn = 3473. 
   
   CartID         (Field01)
   CartPosition   (Field02)
   OrderKey       (Field03)
   ExternOrderKey (Field04)
   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1
   BEGIN
      
      -- Prepare Next Screen Variable
      SET @cOutField01 = ''

      -- GOTO Next Screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
      
      EXEC rdt.rdtSetFocusField @nMobile, 1
      
	END  -- Inputkey = 1
   
   IF @nInputKey = 0 
   BEGIN
       -- Prepare Previous Screen Variable
		 SET @cOutField01 = @cCartID
		 SET @cOutField02 = ''
		 SET @cOutField03 = ''
		 SET @cOutField04 = ''
		    
       -- GOTO Previous Screen
		 SET @nScn = @nScn - 1
	    SET @nStep = @nStep - 1
	    
	    EXEC rdt.rdtSetFocusField @nMobile, 2
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
      ErrMsg = @cErrMsg, 
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 
      Printer   = @cPrinter, 
      UserName  = @cUserName,
		InputKey  =	@nInputKey,
		

      V_UOM = @cPUOM,
  
      V_String1 = @cCartID,
      
      
      
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