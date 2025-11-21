SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: IDSUK Put To Light Order Assignment SOS#269031                    */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2013-02-15 1.0  ChewKP     Created                                         */
/* 2014-05-29 1.1  James      Add extended update sp (james01)                */
/* 2014-06-23 1.2  James      SOS314306 - Add extended info sp (james02)      */
/*                            Add pickzone                                    */
/* 2016-09-30 1.3  Ung        Performance tuning                              */  
/* 2018-10-18 1.4  Gan        Performance tuning                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PTL_OrderAssignment] (
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
	@cDeviceProfileLogKey NVARCHAR(10),
	
   @cExtendedUpdateSP   NVARCHAR( 20), -- (james01)  
   @cSQL                NVARCHAR( MAX),-- (james01)  
   @cSQLParam           NVARCHAR( MAX),-- (james01)  
   @cExtendedInfoSP     NVARCHAR( 20), -- (james02)  
   @cPickZone           NVARCHAR( 10), -- (james02)  
   @cPTLPKZoneReq       NVARCHAR( 1),  -- (james02)  
   @cCurrentPickZone    NVARCHAR( 10), -- (james02)  
   
   @cResult01 NVARCHAR( 20), @cResult02 NVARCHAR( 20),
   @cResult03 NVARCHAR( 20), @cResult04 NVARCHAR( 20),
   @cResult05 NVARCHAR( 20), @cResult06 NVARCHAR( 20),
   @cResult07 NVARCHAR( 20), @cResult08 NVARCHAR( 20),
   @cResult09 NVARCHAR( 20), @cResult10 NVARCHAR( 20),
      
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
   @cOrderKey   = V_OrderKey,
   
	@cCartID     = V_String1,
	@cLightLoc   = V_String2,
	@cToteID     = V_String3,

	@cPTLPKZoneReq = V_String4,   -- (james02)
	@cPickZone     = V_String5,   -- (james02)

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

IF @nFunc = 810  -- PTL Order Assignment
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTL Order Assignment
   IF @nStep = 1 GOTO Step_1   -- Scn = 3450. Cart ID
	IF @nStep = 2 GOTO Step_2   -- Scn = 3451. OrderKey, Cart Position, Tote ID
	IF @nStep = 3 GOTO Step_3   -- Scn = 3452. Warning Message
	IF @nStep = 4 GOTO Step_4   -- Scn = 3453. Warning Message
END

--IF @nStep = 3
--BEGIN
--	SET @cErrMsg = 'STEP 3'
--	GOTO QUIT
--END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 810. Menu
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
     
   SET @cPTLPKZoneReq = rdt.rdtGetConfig( @nFunc, 'PTLPicKZoneReq', @cStorerKey)
   IF @cPTLPKZoneReq = '0'
      SET @cPTLPKZoneReq = ''

   -- Init screen
   SET @cOutField01 = ''   -- cart id
   SET @cOutField01 = ''   -- pickzone
   
	SET @cOrderKey  =''  
   SET @cLightLoc  =''  
   SET @cToteID    =''  

   -- Set the entry point
	SET @nScn = 3450
	SET @nStep = 1
	
	EXEC rdt.rdtSetFocusField @nMobile, 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3450. 
   CartID   (Input , Field01)
   PickZone (Input , Field02)
   
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cCartID = ISNULL(RTRIM(@cInField01),'')
	   SET @cPickZone = ISNULL(RTRIM(@cInField02),'')
		
      -- Validate blank
      IF ISNULL(RTRIM(@cCartID), '') = ''
      BEGIN
         SET @nErrNo = 79551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartID req
         SET @cOutField01 = ''
         SET @cOutField02 = @cPickZone
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      IF ISNULL( @cPickZone, '') = ''
      BEGIN
         IF @cPTLPKZoneReq = '1'
         BEGIN
            SET @nErrNo = 79571
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickZone req
            SET @cOutField01 = @cCartID
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                         WHERE Facility = @cFacility
                         AND   PickZone = @cPickZone)
         BEGIN
            SET @nErrNo = 79572
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV PickZone
            SET @cOutField01 = @cCartID
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         SET @cCurrentPickZone = ''         
         SELECT TOP 1 @cCurrentPickZone = ISNULL( LD.UserDefine10, '')
         FROM dbo.DeviceProfileLog LD WITH (NOLOCK)
         INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey
         WHERE LL.DeviceID = @cCartID 
         AND LD.Status IN('0','1','3')

         IF @cCurrentPickZone <> '' 
         BEGIN
            IF @cCurrentPickZone <> @cPickZone
            BEGIN
               SET @nErrNo = 79574
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV PickZone
               SET @cOutField01 = @cCartID
               SET @cOutField02 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Quit
            END
         END
      END
      
      -- Update DeviceProfile Table Cart Status = '0' When all detail in LightLocLog.Status = '9'
      IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog LD WITH (NOLOCK)
                      INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey
                      WHERE LL.DeviceID = @cCartID 
                      AND LD.Status IN('0','1','3'))
      BEGIN        
            UPDATE dbo.DeviceProfile
            SET Status = '0' 
            WHERE DeviceID = @cCartID
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 79563
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdLightLocFail
               SET @cOutField01 = ''
               SET @cOutField02 = @cPickZone
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit
            END
      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID AND Status IN ('0','1') )
      BEGIN
         SET @nErrNo = 79552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CartID
         SET @cOutField01 = ''
         SET @cOutField02 = @cPickZone
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

		 -- Prepare Next Screen Variable
		 SET @cOutField01 = @cCartID
		 SET @cOutField02 = ''
		 SET @cOutField03 = ''
		 SET @cOutField04 = ''
		 SET @cOutField05 = @cPickZone      -- (james02)
		 
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
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep
        
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
      SET @cOutField02 = ''      
   END
	GOTO Quit
END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 3451. 
   CartID   (field01)
   OrderKey        (field02, input)
   Cart Position   (field03, input)
   Tote ID         (field04, input)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
		SET @cOrderKey = ISNULL(RTRIM(@cInField02),'')
		SET @cLightLoc = ISNULL(RTRIM(@cInField03),'')
		SET @cToteID = ISNULL(RTRIM(@cInField04),'')
		
		IF ISNULL(@cOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 79553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OrderKey Req'
         SET @cOrderKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
         GOTO Step_2_Fail
      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND Status >= '1'
               AND Status < '5')
      BEGIN
            SET @nErrNo = 79554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Order Status
            SET @cOrderKey = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
            GOTO Step_2_Fail
      END

      -- If pickzone is req then check this order whether any of the loc is in that zone
      IF @cPTLPKZoneReq = '1'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                         JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
                         WHERE PD.StorerKey = @cStorerKey
                         AND   PD.OrderKey = @cOrderKey
                         AND   PD.Status = '0'
                         AND   LOC.Facility = @cFacility
                         AND   LOC.PickZone = @cPickZone)
         BEGIN
               SET @nErrNo = 79573
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrdNotInPKZone
               SET @cOrderKey = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
               GOTO Step_2_Fail
         END
      END
      
      SET @cPickSlipNo = ''

      -- (james01)
      SET @cExtendedUpdateSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
      IF @cExtendedUpdateSP NOT IN ('0', '')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCartID, @cOrderKey, @cLightLoc, @cToteID, ' + 
            ' @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParam =    
            '@nMobile                   INT,           ' +
            '@nFunc                     INT,           ' +
            '@cLangCode                 NVARCHAR( 3),  ' +
            '@nStep                     INT,           ' + 
            '@nInputKey                 INT,           ' +
            '@cStorerKey                NVARCHAR( 15), ' +
            '@cCartID                   NVARCHAR( 10), ' +
            '@cOrderKey                 NVARCHAR( 10), ' +
            '@cLightLoc                 NVARCHAR( 10), ' +
            '@cToteID                   NVARCHAR( 20), ' +
            '@bSuccess                  INT           OUTPUT,  ' +
            '@nErrNo                    INT           OUTPUT,  ' +
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCartID, @cOrderKey, @cLightLoc, @cToteID,  
              @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT     
              
         IF @bSuccess <> 1
            GOTO Step_2_Fail  
      END
         
      SELECT @cPickSlipNo = PickHeaderKey
      FROM dbo.PickHeader PH WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.WaveKey = O.UserDefine09 AND PH.OrderKey = O.OrderKey
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    
      WHERE OD.StorerKey = @cStorerKey    
      AND O.OrderKey = @cOrderKey
      AND PH.Status = '0'
            
      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         SET @nErrNo = 79555
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKSLIPNotPrinted
         SET @cOrderKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
         GOTO Step_2_Fail
      END
      ELSE  -- pickslip printed, check if scanned out
      BEGIN
         -- Check if pickslip scanned out
         IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                    WHERE PickSlipNo = @cPickSlipNo
                     AND ScanOutDate IS NOT NULL)
         BEGIN
            SET @nErrNo = 79556
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Scanned Out
            SET @cOrderKey = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
            GOTO Step_2_Fail
         END
      END
      
      IF EXISTS (SELECT 1 FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
                 INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
                 WHERE DL.OrderKey = @cOrderKey
                 AND DL.Status IN ( '0','1','3')
                 AND D.DeviceID <> @cCartID 
                 AND DL.UserDefine10 = CASE WHEN @cPTLPKZoneReq = 1 THEN @cPickZone ELSE DL.UserDefine10 END)
      BEGIN                 
         SET @nErrNo = 79564
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OrderAssigned'
         SET @cOrderKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
         GOTO Step_2_Fail
      END
      
      IF EXISTS (SELECT 1 FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
                 INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
                 WHERE DL.OrderKey = @cOrderKey
                 AND DL.Status IN ( '0','1','3')
                 AND D.DeviceID = @cCartID 
                 AND DL.UserDefine10 = CASE WHEN @cPTLPKZoneReq = 1 THEN @cPickZone ELSE DL.UserDefine10 END)
      BEGIN                 
         SET @nErrNo = 79566
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OrderAssigned'
         SET @cOrderKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
         GOTO Step_2_Fail
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey 
                  AND   [Status] < '9'
                  AND   UserDefine10 = CASE WHEN @cPTLPKZoneReq = 1 THEN @cPickZone ELSE UserDefine10 END)   -- (james01)
      BEGIN                 
         SET @nErrNo = 79570
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OrderAssigned'
         SET @cOrderKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey
         GOTO Step_2_Fail
      END                  

      IF @cLightLoc = ''
      BEGIN
         SET @nErrNo = 79557
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Position Req'
         SET @cLightLoc = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LightLoc
         GOTO Step_2_Fail
      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID AND DevicePosition = @cLightLoc AND Status IN('0','1') ) 
      BEGIN
         SET @nErrNo = 79558
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Position'
         SET @cLightLoc = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LightLoc
         GOTO Step_2_Fail
      END
      
--      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog LD WITH (NOLOCK) 
--                  INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey
--                  WHERE LL.DeviceID <> @cCartID
--                  AND   LL.DevicePosition = @cLightLoc
--                  AND   LD.Status IN ('0','1','3') ) 
--      BEGIN
--         SET @nErrNo = 79567
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Position Assigned'
--         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LightLoc
--         SET @cLightLoc = ''
--         GOTO Step_2_Fail
--      END
      
      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog LD WITH (NOLOCK) 
                  INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey
                  WHERE LL.DeviceID = @cCartID
                  AND   LL.DevicePosition = @cLightLoc
                  AND   LD.Status IN ('0','1','3') ) 
      BEGIN
         SET @nErrNo = 79568
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Position Assigned'
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- LightLoc
         SET @cLightLoc = ''
         GOTO Step_2_Fail
      END
      
      IF @cToteID = ''
      BEGIN
         SET @nErrNo = 79560
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteID Req'
         SET @cToteID = ''
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToteID
         GOTO Step_2_Fail
      END      
      
--      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog LD WITH (NOLOCK) 
--                  INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey
--                  WHERE LL.DeviceID <> @cCartID
--                  AND   LD.DropID   = @cToteID
--                  AND   LD.Status IN ('1','0') ) 
--      BEGIN
--         SET @nErrNo = 79561
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Tote Assigned'
--         SET @cToteID = ''
--         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToteID
--         GOTO Step_2_Fail
--      END      
      
      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog LD WITH (NOLOCK) 
                  INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey
                  WHERE LL.DeviceID = @cCartID
                  AND   LD.DropID   = @cToteID
                  AND   LD.Status IN ( '0','1') ) 
      BEGIN
         SET @nErrNo = 79565
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Tote Assigned'
         SET @cToteID = ''
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToteID
         GOTO Step_2_Fail
      END      
      
      -- Insert into LightLoc_Detail Table
      SET @cLightLocKey = ''
      SET @cDeviceProfileLogKey = ''
      
      SELECT @cLightLocKey = DeviceProfileKey
      FROM dbo.DeviceProfile WITH (NOLOCK)
      WHERE DeviceID = @cCartID
      AND DevicePosition = @cLightLoc
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
                      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKEy = DL.DeviceProfileKey
                      WHERE D.DeviceID = @cCartID
                      AND DL.Status = '1' ) 
      BEGIN
         
         EXECUTE nspg_getkey
      	      'DeviceProfileLogKey'
      	      , 10
      	      , @cDeviceProfileLogKey OUTPUT
      	      , @b_success OUTPUT
      	      , @nErrNo OUTPUT
      	      , @cErrMsg OUTPUT
      END
      ELSE
      BEGIN
         
         SELECT Top 1 @cDeviceProfileLogKey = DL.DeviceProfileLogKey
         FROM dbo.DeviceProfileLog DL WITH (NOLOCK)
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKEy = DL.DeviceProfileKey
         WHERE D.DeviceID = @cCartID
         AND DL.Status = '1'
         
      END
      
      INSERT INTO DeviceProfileLog(DeviceProfileKey, OrderKey, DropID, Status, DeviceProfileLogKey, UserDefine10)
      VALUES ( @cLightLocKey, @cOrderKey, @cToteID, '1', @cDeviceProfileLogKey, @cPickZone)
      
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 79562
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLightLocFail'
         GOTO Step_2_Fail
      END
      ELSE
      BEGIN
         
         UPDATE DeviceProfile
            SET Status = '1', DeviceProfileLogKey = @cDeviceProfileLogKey
         WHERE DeviceID = @cCartID
         
         
         SET @cOrderKey = ''
         SET @cLightLoc = ''
         SET @cToteID   = ''
         
         SET @nErrNo = 79569
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SetupDone'
         
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- OrderKey  
         
      END
      
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '3', 
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cDeviceID   = @cCartID,
        @cLocation   = @cLightLoc,
        --@cRefNo1     = @cCartID,
        --@cRefNo2     = @cLightLoc,
        @cOrderKey   = @cOrderKey,
        @cDropID     = @cToteID,
        @nStep       = @nStep
      
		
   	-- Prepare Next Screen Variable
      SET @cOutField01 = @cCartID
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      
	END  -- Inputkey = 1

   IF @nInputKey = 0 
   BEGIN
      SET @nCountLoc = 0
      SET @nCountLocLog = 0

      SELECT @nCountLoc = Count(DevicePosition)
      FROM dbo.DeviceProfile WITH (NOLOCK)
      WHERE DeviceID = @cCartID
      AND Status = '1'

      SELECT @nCountLocLog = Count(LL.DeviceProfileKey)
      FROM dbo.DeviceProfileLog LD WITH (NOLOCK)
      INNER JOIN dbo.DeviceProfile LL WITH (NOLOCK) ON LL.DeviceProfileKey = LD.DeviceProfileKey
      WHERE LL.DeviceID = @cCartID 
      AND LD.Status = '1'
      AND LL.Status = '1'
       
      IF @nCountLocLog >= @nCountLoc 
      BEGIN
         -- Prepare Previous Screen Variable
         SET @cOutField01 = ''

         -- GOTO Previous Screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         EXEC rdt.rdtSetFocusField @nMobile, 1
      END
      ELSE  -- If Not All Light Loc is assign go to next screen
      BEGIN
         SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
         IF @cExtendedInfoSP NOT IN ('0', '')
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cOutfield02 = ''
               SET @cOutfield03 = ''
               SET @cOutfield04 = ''
               SET @cOutfield05 = ''
               SET @cOutfield06 = ''
               SET @cOutfield07 = ''
               SET @cOutfield08 = ''
               SET @cOutfield09 = ''
               SET @cOutfield10 = ''
          
               SET @cResult01   = ''
               SET @cResult02   = ''
               SET @cResult03   = ''
               SET @cResult04   = ''
               SET @cResult05   = ''
               SET @cResult06   = ''
               SET @cResult07   = ''
               SET @cResult08   = ''
               SET @cResult09   = ''
               SET @cResult10   = ''

               SET @nErrNo = 0

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCartID, 
                    @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT, 
                    @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT, 
                    @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
               SET @cSQLParam =    
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cCartID         NVARCHAR( 10), ' +
                  '@cResult01       NVARCHAR( 20)  OUTPUT,  ' +
                  '@cResult02       NVARCHAR( 20)  OUTPUT,  ' +
                  '@cResult03       NVARCHAR( 20)  OUTPUT,  ' +
                  '@cResult04       NVARCHAR( 20)  OUTPUT,  ' +
                  '@cResult05       NVARCHAR( 20)  OUTPUT,  ' +
                  '@cResult06       NVARCHAR( 20)  OUTPUT,  ' +
                  '@cResult07       NVARCHAR( 20)  OUTPUT,  ' +
                  '@cResult08       NVARCHAR( 20)  OUTPUT,  ' +
                  '@cResult09       NVARCHAR( 20)  OUTPUT,  ' +
                  '@cResult10       NVARCHAR( 20)  OUTPUT,  ' +
                  '@nErrNo          INT            OUTPUT,  ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT   ' 
      
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cCartID, 
                  @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT, 
                  @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT  
      
               IF @nErrNo <> 0 
               BEGIN
                  SET @cErrMsg = LEFT (@cErrMsg,1024)
                  GOTO Quit
               END

               SET @cOutfield02 = @cResult01
               SET @cOutfield03 = @cResult02
               SET @cOutfield04 = @cResult03
               SET @cOutfield05 = @cResult04
               SET @cOutfield06 = @cResult05
            END

            SET @cOutfield07 = @cPickZone
            
             -- GOTO Previous Screen
   		    SET @nScn = @nScn + 2
   	       SET @nStep = @nStep + 2
         END
         ELSE
         BEGIN
            DECLARE CursorLightLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   

            SELECT LL.DevicePosition , LD.OrderKey
            FROM dbo.DeviceProfile LL WITH (NOLOCK)
            LEFT JOIN dbo.DeviceProfileLog LD WITH (NOLOCK) ON LD.DeviceProfileKey = LL.DeviceProfileKey AND LD.Status = '1'
            WHERE LL.DeviceID = @cCartID
            AND LL.Status = '1'
            Order By DevicePosition   

            OPEN CursorLightLoc            
   
            FETCH NEXT FROM CursorLightLoc INTO @cLightLoc, @cOrderKey

            WHILE @@FETCH_STATUS <> -1            
            BEGIN   

               IF @nCartLocCounter = 2
               BEGIN
                  IF ISNULL(@cOrderKey,'') = ''
                  BEGIN
                     SET @cOutfield02 = @cLightLoc
                  END
                  ELSE
                  BEGIN
                     SET @cOutfield02 = 'XXXXX'
                  
                  END
               END
               ELSE IF @nCartLocCounter = 3
               BEGIN
                  IF ISNULL(@cOrderKey,'') = ''
                  BEGIN
                        SET @cOutfield03 = @cLightLoc
                  END
                  ELSE
                  BEGIN
                        SET @cOutfield03 = 'XXXXX'
                  END
               END 
               ELSE IF @nCartLocCounter = 4
               BEGIN
                  IF ISNULL(@cOrderKey,'') = ''
                  BEGIN
                        SET @cOutfield04 = @cLightLoc
                  END
                  ELSE
                  BEGIN
                        SET @cOutfield04 = 'XXXXX'
                  END
               END   
               ELSE IF @nCartLocCounter = 5
               BEGIN
                  IF ISNULL(@cOrderKey,'') = ''
                  BEGIN
                        SET @cOutfield05 = @cLightLoc
                  END
                  ELSE
                  BEGIN
                        SET @cOutfield05 = 'XXXXX'
                  END
               END                     
               ELSE IF @nCartLocCounter = 6
               BEGIN
                  IF ISNULL(@cOrderKey,'') = ''
                  BEGIN
                        SET @cOutfield06 = @cLightLoc
                  END
                  ELSE
                  BEGIN
                        SET @cOutfield06 = 'XXXXX'
                  END
               END    
               ELSE IF @nCartLocCounter = 7
               BEGIN
                  IF ISNULL(@cOrderKey,'') = ''
                  BEGIN
                        SET @cOutfield07 = @cLightLoc
                  END
                  ELSE
                  BEGIN
                        SET @cOutfield07 = 'XXXXX'
                  END
               END   
               ELSE IF @nCartLocCounter = 8
               BEGIN
                  IF ISNULL(@cOrderKey,'') = ''
                  BEGIN
                        SET @cOutfield08 = @cLightLoc
                  END
                  ELSE
                  BEGIN
                        SET @cOutfield08 = 'XXXXX'
                  END
               END   
               ELSE IF @nCartLocCounter = 9
               BEGIN
                  IF ISNULL(@cOrderKey,'') = ''
                  BEGIN
                        SET @cOutfield09 = @cLightLoc
                  END
                  ELSE
                  BEGIN
                        SET @cOutfield09 = 'XXXXX'
                  END
               END   
               ELSE IF @nCartLocCounter = 10
               BEGIN
                  IF ISNULL(@cOrderKey,'') = ''
                  BEGIN
                        SET @cOutfield10 = @cLightLoc
                  END
                  ELSE
                  BEGIN
                        SET @cOutfield10 = 'XXXXX'
                  END
               END    
               
               SET @nCartLocCounter = @nCartLocCounter + 1
               
               IF @nCartLocCounter > 10 
                  BREAK
               
            
               FETCH NEXT FROM CursorLightLoc INTO @cLightLoc, @cOrderKey
            
            END
            
             -- GOTO Previous Screen
   		    SET @nScn = @nScn + 1
   	       SET @nStep = @nStep + 1
         END
          

      END
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
      
      SET @cOutField01 = @cCartID
      SET @cOutField02 = @cOrderKey
      SET @cOutField03 = @cLightLoc
      SET @cOutField04 = @cToteID
   END
   

END 
GOTO QUIT


/********************************************************************************
Step 3. Scn = 3452. 
   
   CartID     (Field01)
   CartPosition (Field02, Input)
   
   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1
   BEGIN
      
      -- Prepare Next Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''

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
		 SET @cOutField05 = @cPickZone      -- (james02)

       -- GOTO Previous Screen
		 SET @nScn = @nScn - 1
	    SET @nStep = @nStep - 1
   END
	GOTO Quit

END 
GOTO QUIT

/********************************************************************************
Step 4. Scn = 3453. 
   
   CartID     (Field01)
   CartPosition (Field02, Input)
   
   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1
   BEGIN
      
      -- Prepare Next Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      -- GOTO Screen 1
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
      
      EXEC rdt.rdtSetFocusField @nMobile, 1
      
	END  -- Inputkey = 1
   
   IF @nInputKey = 0 
   BEGIN
       -- Prepare Previous Screen Variable
		 SET @cOutField01 = @cCartID
		 SET @cOutField02 = ''
		 SET @cOutField03 = ''
		 SET @cOutField04 = ''
		 SET @cOutField05 = @cPickZone
		 SET @cOutField06 = ''
		 SET @cOutField07 = ''
		 SET @cOutField08 = ''
		 SET @cOutField09 = ''
		 SET @cOutField10 = ''
		 SET @cOutField11 = ''
		 SET @cOutField12 = ''
		 SET @cOutField13 = ''

       -- GOTO Previous Screen
		 SET @nScn = @nScn - 2
	    SET @nStep = @nStep - 2
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
      V_OrderKey = @cOrderKey,
      
      V_String1 = @cCartID,
      V_String2 = @cLightLoc,
      V_String3 = @cToteID,
      V_String4 = @cPTLPKZoneReq,   -- (james02)
	   V_String5 = @cPickZone,       -- (james02)
      
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