SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/******************************************************************************/   
/* Copyright: LF                                                              */   
/* Purpose: IDSTW                                                             */   
/*                                                                            */   
/* Modifications log:                                                         */   
/*                                                                            */   
/* Date       Rev  Author     Purposes                                        */   
/* 2015-10-09 1.0  ChewKP     SOS#353680 Created                              */
/* 2015-11-11 1.1  AlanTan    OTMIDTrack                                      */  
/* 2016-09-30 1.2  Ung        Performance tuning                              */   
/* 2017-04-28 1.3  ChewKP     WMS-1685 - Re-Work 										*/
/* 2018-10-17 1.4  Gan        Performance tuning                              */
/* 2019-06-19 1.5  James      WMS9423-Add extendedupdatesp to step 3 (james01)*/
/******************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_TPEX_OrderToPallet] (  
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
   @cOrderKey     NVARCHAR( 10),    
   @cPalletStorerKey NVARCHAR(20),    
   @cStorerType      NVARCHAR(30),    
   @nIsWMS           INT,    
   @cShipTo          NVARCHAR(60),    
   @cPalletKey       NVARCHAR(20),    
   @cPalletHeight    NVARCHAR(5),    
   @nPalletCount     INT,    
   @cConsigneeKey    NVARCHAR(15),    
   @cPalletType      NVARCHAR(10),
   
   @cPalletMUType    NVARCHAR(10),
   @cExternOrderKey  NVARCHAR(20),
       
   @cPalletWeight    NVARCHAR(5),    
   @nLength          FLOAT,    
   @nWidth           FLOAT,    
   @cDropLoc         NVARCHAR(10), 
   @cOrderFac        NVARCHAR(10),
   @cInputOrderKey   NVARCHAR(20),
   @cCartonCount     NVARCHAR(5),
   @cCheckWMSOrder   NVARCHAR(1),
   @nOrderKeyLength  INT,
   @nPalletIDLength  INT,
   @cValidateFacility NVARCHAR(5),
   @cExtendedUpdateSP NVARCHAR( 20),
   @tExtUpdate        VariableTable, 
   @cSQL              NVARCHAR(MAX), 
   @cSQLParam         NVARCHAR(MAX), 
   @nTranCount        INT,
 
   
    
        
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
   @cPalletStorerKey = V_String1,
   @cExternOrderKey  = V_String2,   
   @cCheckWMSOrder   = V_String3,   
   @cExtendedUpdateSP= V_String4,
  -- @nOrderKeyLength  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END, 
  -- @nPalletIDLength  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END, 
   @cValidateFacility = V_String6,   
   @cCartonCount      = V_String7, --CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7, 5), 0) = 1 THEN LEFT( V_String7, 5) ELSE 0 END, 
   
   @nOrderKeyLength = V_Integer1,
   @nPalletIDLength = V_Integer2,
  
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
  
  
  
IF @nFunc = 1182  -- Order To Pallet  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0 GOTO Step_0   -- Order To Pallet  
   IF @nStep = 1 GOTO Step_1   -- Scn = 4310. StorerKey   
   IF @nStep = 2 GOTO Step_2   -- Scn = 4311. OrderKey  
   IF @nStep = 3 GOTO Step_3   -- Scn = 4312. Pallet ID
    
END  
  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. func = 1182. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Get prefer UOM  
 SET @cPUOM = ''  
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
   FROM RDT.rdtMobRec M WITH (NOLOCK)  
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)  
   WHERE M.Mobile = @nMobile  

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''
  
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
   SET @cOutField01 = @cStorerKey    
     
   SET @cOrderKey = ''  
   
  
   -- Set the entry point  
 SET @nScn = 4310  
 SET @nStep = 1  
   
 EXEC rdt.rdtSetFocusField @nMobile, 1  
   
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Scn = 4310.   
   StorerKey (Input , Field01)  
   
     
********************************************************************************/  
Step_1:  
BEGIN  
 IF @nInputKey = 1 --ENTER  
 BEGIN  
	  SET @cPalletStorerKey = ISNULL(RTRIM(@cInField01),'')  
	  
	  
	  -- Validate blank  
	  IF ISNULL(RTRIM(@cPalletStorerKey), '') = ''  
	  BEGIN  
	     SET @nErrNo = 94451  
	     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StorerKey req  
	     EXEC rdt.rdtSetFocusField @nMobile, 1  
	     GOTO Step_1_Fail  
	  END  
	    
	  IF NOT EXISTS ( SELECT 1 FROM dbo.Storer WITH (NOLOCK)  
	                  WHERE StorerKey = @cPalletStorerKey
	                  AND Type = '1'  )   
	  BEGIN  
	     SET @nErrNo = 94452  
	     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidStorerKey  
	     EXEC rdt.rdtSetFocusField @nMobile, 1  
	     GOTO Step_1_Fail  
	  END  
	                      
	  -- Prepare Next Screen Variable  
	  SET @cOutField01 = @cPalletStorerKey
	  
	    
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
Step 2. Scn = 4311.   
   StorerKey 		(Field01)  
   OrderNo 			(Input, Field02)  
   Carton Count (Input, Field03) 
   
     
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN    
   	SET @cInputOrderKey   = ISNULL(RTRIM(@cInField02),'')  
   	SET @cCartonCount     = ISNULL(RTRIM(@cInField03),'')  
    	
    	SELECT @cCheckWMSOrder = ISNULL(Short ,'') 
    				,@nOrderKeyLength = ISNULL(UDF01,0)
    				,@nPalletIDLength = ISNULL(UDF02,0)
    				,@cValidateFacility = ISNULL(UDF03,'')
      FROM dbo.CodeLkup WITH (NOLOCK) 
      WHERE ListName = 'OTMRDT'
      AND StorerKey = @cPalletStorerKey
      
      IF @cInputOrderKey = ''  
      BEGIN  
         SET @nErrNo = 94453  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderKey req  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         SET @cInputOrderKey = ''
         GOTO Step_2_Fail  
      END  
      
      IF @cCheckWMSOrder = '1' 
      BEGIN
      	IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                    		WHERE ExternOrderKey = @cInputOrderKey
                    		AND StorerKey = @cPalletStorerKey )
        BEGIN
           SET @nErrNo = 94454  
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OrderKey  
           EXEC rdt.rdtSetFocusField @nMobile, 2  
           SET @cInputOrderKey = ''
           GOTO Step_2_Fail 
        END 
    	END
    	
    	IF @nOrderKeyLength > 1 
    	BEGIN
    		SET @cOrderKey = LEFT(@cInputOrderKey, @nOrderKeyLength) 
    	END
    	ELSE
    	BEGIN
    		SET @cOrderKey = @cInputOrderKey
    	END
      
      IF @cCartonCount <> '' 
      BEGIN
         IF ISNUMERIC ( @cCartonCount ) = 0 
         BEGIN
            SET @nErrNo = 94455    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'    
            EXEC rdt.rdtSetFocusField @nMobile, 3   
            SET @cCartonCount = 0
            GOTO Step_2_Fail  
         END

       	IF RDT.rdtIsValidQTY( @cCartonCount, 1) = 0     
         BEGIN    
            SET @nErrNo = 94455    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'    
            EXEC rdt.rdtSetFocusField @nMobile, 3   
            SET @cCartonCount = 0
            GOTO Step_2_Fail    
         END  
      END  
      ELSE 
         EXEC rdt.rdtSetFocusField @nMobile, 3
    	
    	
      IF @cInputOrderKey <> '' AND @cCartonCount <> 0 
      BEGIN
         SET @cOutField01 = @cOrderKey
         SET @cOutField02 = @cCartonCount
         SET @cOutField03 = ''
         SET @cOutField04 = '' 
         
         SET @nScn  = @nScn + 1   
         SET @nStep = @nStep + 1   
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cPalletStorerKey  
         SET @cOutField02 = @cInputOrderKey
         SET @cOutField03 = @cCartonCount  

         
      END
    
 END  -- Inputkey = 1  
  
  
 IF @nInputKey = 0   
 BEGIN  
        
      SET @cOutField01 = @cStorerKey
        
      SET @nScn = @nScn - 1   
      SET @nStep = @nStep - 1   
        
        
 END  
 GOTO Quit  
  
 STEP_2_FAIL:  
 BEGIN  
    SET @cOutField01 = @cPalletStorerKey  
    SET @cOutField02 = @cInputOrderKey
    SET @cOutField03 = @cCartonCount  
   
 
    --EXEC rdt.rdtSetFocusField @nMobile, 1  
 END 
     
  
END   
GOTO QUIT  


/********************************************************************************  
Step 3. Scn = 4312.   
   
   OrderNo 			(Field01)  
   Carton Count (Field02) 
   Pallet ID    (Input, Field03) 
   DropLoc      (Input, Field04) 
   
     
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN    
   	SET @cPalletKey   = ISNULL(RTRIM(@cInField03),'')  
   	--SET @cDropLoc     = ISNULL(RTRIM(@cInField04),'')  
 
      	
      IF @cPalletKey = ''  
      BEGIN  
         SET @nErrNo = 94456  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletKeyReq
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         SET @cPalletKey = ''
         GOTO Step_3_Fail  
      END  
      
      IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
      					  WHERE PalletKey = @cPalletKey 
      					  AND MUStatus > 0 ) 
      BEGIN
      	 SET @nErrNo = 94460
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletKeyExist
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         SET @cPalletKey = ''
         GOTO Step_3_Fail  
    	END
      


      IF LEN(@cPalletKey) <> @nPalletIDLength 
    	BEGIN
    		 SET @nErrNo = 94457  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPalletKey
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         SET @cPalletKey = ''
         GOTO Step_3_Fail  
    	END
      
--    	IF @cDropLoc = '' 
--    	BEGIN
--    		 SET @nErrNo = 94458  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropLocReq
--         EXEC rdt.rdtSetFocusField @nMobile, 4
--         SET @cDropLoc = ''
--         GOTO Step_3_Fail  
--    	END
   
      
--      IF NOT EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK) 
--      								WHERE Loc = @cDropLoc
--      								AND   Facility = @cValidateFacility ) 
--    	BEGIN
--    		SET @nErrNo = 94459
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidDropLoc
--         EXEC rdt.rdtSetFocusField @nMobile, 4
--         SET @cDropLoc = ''
--         GOTO Step_3_Fail  
--    	END
    	
    	SET  @cPalletMUType = SUBSTRING ( @cPalletKey, 5, 1 ) 
    	
 
    	
    	IF NOT EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK) 
    									WHERE ListName = 'PLTSIZE'
    									AND Code = @cPalletMUType ) 
    	BEGIN
    		SET @nErrNo = 94461
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MUTypeNotSetup
         EXEC rdt.rdtSetFocusField @nMobile, 4
         --SET @cDropLoc = ''
         GOTO Step_3_Fail  
    	END
    	
    	SELECT --@cPalletHeight = 
    				--,@cPalletWeight = 
    				 @nLength			= Long
    				,@nWidth				= Short
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE ListName = 'PLTSIZE'
      --AND StorerKey = @cPalletStorerKey 
      AND Code = @cPalletMUType

      IF ISNULL(@nLength,0 )  = 0 AND ISNULL(@nWidth,0 )  = 0 
      BEGIN
         SET @nErrNo = 94463
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletTypeNoSetup
         EXEC rdt.rdtSetFocusField @nMobile, 4
         --SET @cDropLoc = ''
         GOTO Step_3_Fail  
      END
    	

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdtfnc_TPEX_OrderToPallet_Step3

    	-- Insert Into OTMIDTrack --
      INSERT INTO dbo.OTMIDTrack (PalletKey, Principal, MUStatus, OrderID, ShipmentID, Length, Width, Height, GrossWeight, GrossVolume, 
                                 MUType, DropLoc, ExternOrderKey, ConsigneeKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05 )
                               
      VALUES ( @cPalletKey, @cPalletStorerKey, '0', '', '', @nLength, @nWidth, 0 , 0, 0, 
               @cPalletMUType, '', @cOrderKey, '', @cCartonCount, '', '', '', '' )
      
      IF @@ERROR <> 0   
      BEGIN  
         SET @nErrNo = 94462  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPalletFail'    
         EXEC rdt.rdtSetFocusField @nMobile, 8  
         GOTO Step3_RollBackTran    
      END

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
            INSERT INTO @tExtUpdate (Variable, Value) VALUES 
            ('@cPalletStorerKey',   @cPalletStorerKey),
            ('@cOrderKey',          @cOrderKey),
            ('@cCartonCount',       @cCartonCount),
            ('@cPalletKey',         @cPalletKey)

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdate, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @tExtUpdate     VariableTable READONLY, ' + 
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdate, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
            GOTO Step3_RollBackTran
      END

      GOTO Step3_CommitTran

      Step3_RollBackTran:
         ROLLBACK TRAN rdtfnc_TPEX_OrderToPallet_Step3

      Step3_CommitTran:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN rdtfnc_TPEX_OrderToPallet_Step3

      SET @cOutField01 = @cPalletStorerKey
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = '' 
      
      
      SET @nScn = @nScn - 2   
      SET @nStep = @nStep - 2   
      
    
 END  -- Inputkey = 1  
  
  
 IF @nInputKey = 0   
 BEGIN  
        
      SET @cOutField01 = @cPalletStorerKey  
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      
        
      SET @nScn = @nScn - 1   
      SET @nStep = @nStep - 1   
      
      EXEC rdt.rdtSetFocusField @nMobile, 2    
        
 END  
 GOTO Quit  
  
 STEP_3_FAIL:  
 BEGIN  
    SET @cOutField01 = @cOrderKey  
    SET @cOutField02 = @cCartonCount
    SET @cOutField03 = @cPalletKey  
    --SET @cOutField04 = @cDropLoc  
   
    --EXEC rdt.rdtSetFocusField @nMobile, 1  
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
      InputKey  = @nInputKey,  
    
  
      V_UOM      = @cPUOM,  
      V_OrderKey = @cOrderKey,  
      V_String1  = @cPalletStorerKey, 
      V_String2  = @cExternOrderKey, 
      V_String3  = @cCheckWMSOrder,   
      V_String4  = @cExtendedUpdateSP,
      --V_String4  = @nOrderKeyLength,    
      --V_String5  = @nPalletIDLength, 
      V_String6  = @cValidateFacility,   
      V_String7  = @cCartonCount,
      
      V_Integer1 = @nOrderKeyLength,
      V_Integer2 = @nPalletIDLength,
   
        
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