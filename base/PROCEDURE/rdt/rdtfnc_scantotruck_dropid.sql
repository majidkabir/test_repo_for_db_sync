SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: C4 Split Shipment when scan to truck SOS#257863                   */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2012-10-02 1.0  ChewKP     Created                                         */
/* 2016-09-30 1.1  Ung        Performance tuning                              */
/* 2018-11-14 1.2  TungGH     Performance                                     */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_ScanToTruck_DropID] (
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
   @cPrinter   NVARCHAR( 20), 
   @cUserName  NVARCHAR( 18),
   
   @nError        INT,
   @b_success     INT,
   @n_err         INT,     
   @c_errmsg      NVARCHAR( 250), 
   @cPUOM         NVARCHAR( 10),    
	@cMBOLKey      NVARCHAR(10),
	@cConsigneeKey NVARCHAR(15),
	@nDropIDCount  INT,
	@cDropID       NVARCHAR(20),
	@cStatus       NVARCHAR(10),
	
      
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
   
	@cMBOLKey      = V_String1,
	@cConsigneeKey = V_String2,     
   @cDropID       = V_String4,
   
   @nDropIDCount  = V_Integer1,
      
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



IF @nFunc = 1716  -- TruckLoading
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Truck Loading
   IF @nStep = 1 GOTO Step_1   -- Scn = 3220. MBOLKey
	IF @nStep = 2 GOTO Step_2   -- Scn = 3221. Consignee
	IF @nStep = 3 GOTO Step_3   -- Scn = 3222. DropID
	IF @nStep = 4 GOTO Step_4   -- Scn = 3223. Confirmation Options
	IF @nStep = 5 GOTO Step_5   -- Scn = 3224. Message
	
   
END

--IF @nStep = 3
--BEGIN
--	SET @cErrMsg = 'STEP 3'
--	GOTO QUIT
--END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1716. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
	SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

	--SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   --SET @nCasePackDefaultQty =  CAST(rdt.RDTGetConfig( @nFunc, 'CasePackDefaultQty', @cStorerKey) AS INT)

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
   
	SET @cMBOLKey = ''
	
	
	

   -- Set the entry point
	SET @nScn = 3220
	SET @nStep = 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3220. 
   MBOLKey (Input , Field01)
   
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cMBOLKey = ISNULL(RTRIM(@cInField01),'')
		
      -- Validate blank
      IF ISNULL(RTRIM(@cMBOLKey), '') = ''
      BEGIN
         SET @nErrNo = 77301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL# req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKEY =  @cMBOLKey)
      BEGIN
         SET @nErrNo = 77302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid MBOL#
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
  
      SELECT 
             @cStatus = Status
      FROM dbo.MBOL WITH (NOLOCK)
      WHERE MbolKey = @cMBOLKey

      IF @cStatus = '9'
      BEGIN
         SET @nErrNo = 77303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
		
		 -- Prepare Next Screen Variable
		 SET @cOutField01 = @cMBOLKey
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
Step 2. Scn = 3221. 
   MBOLKey   (field01)
   Consignee (field02, input)
   
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   
	   	
		SET @cConsigneeKey = ISNULL(RTRIM(@cInField02),'')
		
		
		
      -- Validate blank
      IF ISNULL(RTRIM(@cConsigneeKey), '') = ''
      BEGIN
         SET @nErrNo = 77304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Consginee Req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.Storer WITH (NOLOCK) WHERE StorerKey =  @cConsigneeKey)
      BEGIN
         SET @nErrNo = 77305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Consignee
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END
      
      SET @nDropIDCount = 0
      
--      SELECT @nDropIDCount =  Count(DISTINCT PD.DropID)
--      FROM dbo.MBOL M WITH (NOLOCK)
--      INNER JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
--      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
--      WHERE M.MBOLKEY = @cMBOLKey
--      AND PD.StorerKey = @cStorerKey

      SELECT @nDropIDCount = Count(DISTINCT RefNo) 
      FROM rdt.RDTScanToTruck
      WHERE MBOLKey = @cMBOLKey
      AND Status <> '9'
       
		-- Prepare Next Screen Variable
		SET @cOutField01 = @cMBOLKey
		SET @cOutField02 = @cConsigneeKey
		SET @cOutField03 = @nDropIDCount
		SET @cOutField04 = ''
		 
		-- GOTO Next Screen
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
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = ''
   END
   

END 
GOTO QUIT


/********************************************************************************
Step 3. Scn = 3222. 
   
   MBOLKey    (Field01)
   Consignee  (Field02)
   DropID CNT (Field03)
   DropID     (Field04, Input)
   
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
		SET @cDropID = ISNULL(RTRIM(@cInField04),'')
		
      -- Validate blank
      IF ISNULL(RTRIM(@cDropID), '') = ''
      BEGIN
         SET @nErrNo = 77306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID Req
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Step_3_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND DropID = @cDropID
                      AND Status = '5' )
      BEGIN
         SET @nErrNo = 77307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv DropID
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Step_3_Fail
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
                      WHERE PD.StorerKey = @cStorerKey
                      AND PD.DropID = @cDropID
                      AND PD.Status < '9' 
                      AND O.ConsigneeKey = @cConsigneeKey)
      BEGIN
         SET @nErrNo = 77308
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Consignee
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Step_3_Fail
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
                  INNER JOIN dbo.MBOL M WITH (NOLOCK) ON M.MBOLKey = O.MBOLKey
                  INNER JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON MD.MBOLKey = M.MBOLKey AND MD.OrderKey = O.OrderKey
                  WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID      = @cDropID
                  AND O.ConsigneeKey = @cConsigneeKey
                  AND M.MBOLKey      = @cMBOLKey )
      BEGIN
         SET @nErrNo = 77309
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID Process
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Step_3_Fail
      END
      
      
      SET @nDropIDCount = 0
      
--      SELECT @nDropIDCount =  Count(DISTINCT PD.DropID)
--      FROM dbo.MBOL M WITH (NOLOCK)
--      INNER JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
--      INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
--      WHERE M.MBOLKEY = @cMBOLKey
--      AND PD.StorerKey = @cStorerKey     
      

      
      
      IF NOT EXISTS (SELECT 1 FROM rdt.RDTScanToTruck WITH (NOLOCK)
                     WHERE RefNo = @cDropID )
      BEGIN                     
         INSERT INTO rdt.RdtScanToTruck (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, Adddate, Door)  
         VALUES (@cMBOLKey, '', '', @cDropID, '' , '3', GetDate(), '')  
          
         IF @@ERROR <> 0  
         BEGIN  
               SET @nErrNo = 77312  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins Scan2Truck Fail'  
               GOTO Step_3_Fail  
         END  
      END
      ELSE
      BEGIN
               IF NOT EXISTS ( SELECT 1 FROM rdt.RDTScanToTruck WITH (NOLOCK)
                               WHERE RefNo = @cDropID
                               AND Status = '9' ) 
               BEGIN                               
                  
                  Delete from rdt.rdtScanToTruck
                  Where RefNo = @cDropID
                  AND Status <> '9'
                  
                  IF @@ERROR <> 0  
                  BEGIN  
                        SET @nErrNo = 77315
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Del Scan2Truck Fail'  
                        GOTO Step_3_Fail  
                  END   
                  
                  
                  INSERT INTO rdt.RdtScanToTruck (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, Adddate, Door)  
                  VALUES (@cMBOLKey, '', '', @cDropID, '' , '3', GetDate(), '')  
                   
                  IF @@ERROR <> 0  
                  BEGIN  
                        SET @nErrNo = 77314  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins Scan2Truck Fail'  
                        GOTO Step_3_Fail  
                  END    
               END
               ELSE
               BEGIN
                  SET @nErrNo = 77313  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropID Scanned'  
                  GOTO Step_3_Fail  
               END                  
      END

      SELECT @nDropIDCount = Count(DISTINCT RefNo) 
      FROM rdt.RDTScanToTruck
      WHERE MBOLKey = @cMBOLKey
      AND Status <> '9'
      
      -- Prepare Next Screen Variable
--      SET @cOutField01 = @cMBOLKey
--      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = @nDropIDCount
--      SET @cOutField04 = @cDropID
--      SET @cOutField05 = ''
      
      SET @cOutField04 = ''

      -- GOTO Next Screen
      --SET @nScn = @nScn + 1
      --SET @nStep = @nStep + 1
	END  -- Inputkey = 1


	IF @nInputKey = 0 
   BEGIN
       
       IF @nDropIDCount >= 1
       BEGIN
            -- Prepare Next Screen Variable
            SET @cOutField01 = @cMBOLKey
            SET @cOutField02 = @cConsigneeKey
            SET @cOutField03 = @nDropIDCount
            SET @cOutField04 = @cDropID
            SET @cOutField05 = ''
            
            -- GOTO Next Screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            
            
       END
       ELSE
       BEGIN
          -- Prepare Previous Screen Variable
          SET @cOutField01 = @cMBOLKey
   		 SET @cOutField02 = ''
   		    
          -- GOTO Previous Screen
   		 SET @nScn = @nScn - 1
   	    SET @nStep = @nStep - 1
       END   	    
   END
	GOTO Quit

   STEP_3_FAIL:
   BEGIN
      
      SET @cOutField01 = @cMBOLKey
      SET @cOutField02 = @cConsigneeKey
      --SET @cOutField03 = @nDropIDCount
      SET @cOutField04 = ''
      
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 4. Scn = 3223. 
   MBOLKey    (Field01)
   Consignee  (Field02)
   DropID CNT (Field03)
   DropID     (Field04)
   Option     (Field05, Input)
   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   	
		SET @cOption = ISNULL(RTRIM(@cInField05),'')
		
      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 77310
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'
         GOTO Step_4_Fail
      END

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 77311
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_4_Fail
      END
       
      IF @cOption = '1'
      BEGIN
          
         
         
         -- Execute SP to Split Orders
         EXEC dbo.isp_ScanToTruck_DropID_MBOLCreation
              @cMBOLKey = @cMBOLKey 
            , @cListTo  = ''
            , @cListCc  = ''
            , @nErrNo   = @nErrNo OUTPUT
            , @cErrMsg  = @cERRMSG OUTPUT -- screen limitation, 20 char max
         
         IF @nErrNo <> 0    
         BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_4_Fail  
         END
         
         -- Prepare Next Screen Variable
         SET @cOutField01 = @cMBOLKey
         SET @cOutField02 = @cConsigneeKey
         SET @cOutField03 = @cDropID
         
   		 
   		 -- GOTO Next Screen
   		 SET @nScn = @nScn + 1
   	    SET @nStep = @nStep + 1
      END
      ELSE IF @cOption = '2'
      BEGIN
          
          
          
          -- Prepare Next Screen Variable
   		 SET @cOutField01 = ''
   		 
   		 -- GOTO MBOLKey Screen
   		 SET @nScn = @nScn - 3
   	    SET @nStep = @nStep - 3
      END    
		
	END  -- Inputkey = 1


--	IF @nInputKey = 0 
--   BEGIN
--      
--        -- Prepare Previous Screen Variable
--       SET @cOutField01 = @cMBOLKey
--       SET @cOutField02 = @cConsigneeKey
--       SET @cOutField03 = @nDropIDCount
--       SET @cOutField04 = ''
--       
--		    
--       -- GOTO Previous Screen
--		 SET @nScn = @nScn - 1
--	    SET @nStep = @nStep - 1
--   END
	GOTO Quit

   STEP_4_FAIL:
   BEGIN
         -- Prepare Next Screen Variable
         SET @cOutField01 = @cMBOLKey
         SET @cOutField02 = @cConsigneeKey
         SET @cOutField03 = @nDropIDCount
         SET @cOutField04 = @cDropID
         SET @cOutField05 = ''
   END
   

END 
GOTO QUIT

/********************************************************************************
Step 5. Scn = 3224. 
   MBOLKey    (Field01)
   Consignee  (Field02)
   DropID     (Field03)
   
   
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1  OR @nInputKey = 0  --ENTER / ESC
   BEGIN
	   	
		
       -- Prepare Next Screen Variable
   	 SET @cOutField01 = ''
   	 
   	 -- GOTO MBOLKey Screen
   	 SET @nScn = @nScn - 4
   	 SET @nStep = @nStep - 4
      
		
	END  -- Inputkey = 1

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
  
      V_String1 = @cMBOLKey      ,
	   V_String2 = @cConsigneeKey ,
      V_String4 = @cDropID       ,

      V_Integer1 = @nDropIDCount ,
      
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