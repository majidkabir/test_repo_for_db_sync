SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: IDSTW TPEX Order Inquiry                                          */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2015-10-16 1.0  AlanTan    SOS#354257 Created                              */
/* 2015-11-11 1.1  AlanTan    OTMIDTrack                                      */
/* 2016-09-30 1.2  Ung        Performance tuning                              */
/* 2017-05-11 1.3  ChewKP     WMS-1904 - Reworks                              */ 
/* 2018-10-18 1.4  TungGH     Performance                                     */  
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_TPEX_OrderInquiry] (
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
   @cTruckID      NVARCHAR( 20),
   @cShipmentNo   NVARCHAR( 60),
   @cPalletID     NVARCHAR( 20),
   @cOption       NVARCHAR(  1),
   @nPalletCount  INT,

   @cPalletKey    NVARCHAR( 20),
   @cPalletLOC    NVARCHAR( 10),
   @cPalletTruck  NVARCHAR( 20),
   @cPalletStorer NVARCHAR( 30),
   @cPalletOrder  NVARCHAR( 10),
   @cPalletShip   NVARCHAR( 60),

   @nPalletMUID   INT,
   @cPalletLinePre NVARCHAR( 5),
   @cPalletMUStatus NVARCHAR( 10),
   @cPalletMUStatusCN NVARCHAR( 5),

   @cPalletKeyCount NVARCHAR( 4),
   @cPalletIndex  NVARCHAR( 4),
   @cInputPalletOrder NVARCHAR(20), 
   @nOrderKeyLength   INT,
   @cQty              NVARCHAR(10),
   @nCurrRecord       INT,
   @nTotalRecord      INT,
      
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
   
   @cPUOM            = V_UOM,
   @cPalletKey       = V_String1,  
   @cPalletOrder     = V_String3,
   @cPalletIndex     = V_String4,
   @cPalletLinePre   = V_string5,
   
   @nPalletMUID      = V_Integer1,
   @nCurrRecord      = V_Integer2,      
   @nTotalRecord     = V_Integer3,      

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

IF @nFunc = 1184  --Assign DropLoc
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Assign DropLoc
   IF @nStep = 1 GOTO Step_1   -- Scn = 4330. PalletID ,
	IF @nStep = 2 GOTO Step_2   -- Scn = 4331. Pallet Information

END


RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1184. Menu
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
	SET @nScn = 4330
	SET @nStep = 1
	
	EXEC rdt.rdtSetFocusField @nMobile, 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4330. 
   OrderNum (Input , Field01)

********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cInputPalletOrder = ISNULL(RTRIM(@cInField01),'')
		
      -- Validate blank
      IF @cInputPalletOrder = ''
      BEGIN
         SET @nErrNo = 94702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNum req
         GOTO Step_1_Fail
      END

      SELECT
    			@nOrderKeyLength = ISNULL(UDF01,0)
      FROM dbo.CodeLkup WITH (NOLOCK) 
      WHERE ListName = 'OTMRDT'
      AND StorerKey = @cStorerKey
      
      IF @nOrderKeyLength > 1 
    	BEGIN
    		SET @cPalletOrder = LEFT(@cInputPalletOrder, @nOrderKeyLength) 
    	END
    	ELSE
    	BEGIN
    		SET @cPalletOrder = @cInputPalletOrder
    	END

      --Validate OrderID
      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                     WHERE ExternOrderKey = @cPalletOrder )
      BEGIN
         SET @nErrNo = 94701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNotExist
         GOTO Step_1_Fail
      END
         
            
      --Load dbo.OTMIDTrack
      SELECT TOP 1
      @cPalletStorer = Principal,
      @cPalletKey    = PalletKey,
      @cPalletLOC    = DropLoc,
      @cPalletTruck  = TruckID,
      @cPalletMUStatus = MUStatus,
      @nPalletMUID   = MUID,
      @cQty          = UserDefine01
      FROM dbo.OTMIDTrack WITH (NOLOCK)
      WHERE ExternOrderKey = @cPalletOrder
      ORDER BY MUID
      
      SELECT @nTotalRecord = Count(PalletKey) 
      FROM dbo.OTMIDTrack WITH (NOLOCK)
      WHERE ExternOrderKey = @cPalletOrder
      

      SELECT @cPalletMUStatusCN = RTRIM( LTRIM( Description))
      FROM Codelkup WITH (NOLOCK)
      WHERE LISTNAME = 'OTMStatus'
      AND Code = @cPalletMUStatus

      -- Prepare Next Screen Variable
      --SET @cPalletIndex = CAST(1 AS NVARCHAR( 4))
		
      SET @cOutField01 = @cPalletOrder
      SET @cOutField02 = @cPalletKey 
      SET @cOutField03 = @cPalletMUStatus -- @cPalletMUStatusCN
      SET @cOutField04 = @cQty 
		SET @cOutField05 = @cPalletTruck
      SET @cOutField06 = @cPalletLOC
      
      SET @nCurrRecord = 1 
      SET @cOutField07 = RIGHT('   '+CAST(@nCurrRecord AS VARCHAR(3)),3) 
      SET @cOutField08 = RIGHT('   '+CAST(@nTotalRecord AS VARCHAR(3)),3) 
      
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
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      
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
Step 2. Scn = 4331. 
   Storer    (field01)
   OrderNum  (field02)
   ShipTo    (field03)

   DropID    (field04)
   DropLOC   (field05)
   TruckID   (field06)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 
   BEGIN

       -- EventLog - Sign In Function
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

       --Load dbo.OTMIDTrack
       SELECT TOP 1
         @cPalletStorer = Principal,
         @cPalletKey    = PalletKey,
         @cPalletLOC    = DropLoc,
         @cPalletTruck  = TruckID,
         @cPalletMUStatus = MUStatus,
         @nPalletMUID   = MUID,
         @cQty          = UserDefine01
       FROM dbo.OTMIDTrack WITH (NOLOCK)
       WHERE ExternOrderKey = @cPalletOrder
       AND MUID > @nPalletMUID       --Find the next one result
       --AND UserDefine02 <> '1'
       ORDER BY MUID
       
       IF @@ROWCOUNT = 0   --If no more result
       BEGIN
          SET @nErrNo = 94703
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Last record message display
          GOTO Step_2_Fail
       END

       SELECT @cPalletMUStatusCN = RTRIM( LTRIM( Description))
       FROM Codelkup WITH (NOLOCK)
       WHERE LISTNAME = 'OTMStatus'
       AND Code = @cPalletMUStatus



       -- Prepare Next Screen Variable
       --SET @cPalletIndex = CAST((CAST(@cPalletIndex AS INT) + 1) AS NVARCHAR( 4))
       
		 SET @cOutField01 = @cPalletOrder
       SET @cOutField02 = @cPalletKey 
       SET @cOutField03 = @cPalletMUStatus --@cPalletMUStatusCN
       SET @cOutField04 = @cQty 
		 SET @cOutField05 = @cPalletTruck
       SET @cOutField06 = @cPalletLOC
       
       SET @nCurrRecord = @nCurrRecord + 1
       
       SET @cOutField07 = RIGHT('   '+CAST(@nCurrRecord AS VARCHAR(3)),3) 
       SET @cOutField08 = RIGHT('   '+CAST(@nTotalRecord AS VARCHAR(3)),3) 
       --SET @cOutField07 = @cPalletIndex + '/' + @cPalletKeyCount
       --SET @cOutField08 = @cPalletMUStatusCN
      
      
	END  -- Inputkey = 1
   
   IF @nInputKey = 0 
   BEGIN
     
     SET @cOutfield01 = ''
     SET @cOutField02 = ''
     SET @cOutField03 = ''
     SET @cOutField04 = ''
     SET @cOutField05 = ''
     SET @cOutField06 = ''
     SET @cOutField07 = ''
     SET @cOutField08 = ''
     
     SET @nScn = @nScn - 1 
     SET @nStep = @nStep - 1 
      
      
   END
	GOTO Quit

   STEP_2_FAIL: --fail function
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 2
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

      V_UOM      = @cPUOM,
      
      V_String1  = @cPalletKey,
      V_String3  = @cPalletOrder,
      V_String4  = @cPalletIndex,
      V_String5  = @cPalletLinePre,
      
      V_Integer1 = @nPalletMUID,
      V_Integer2 = @nCurrRecord,
      V_Integer3 = @nTotalRecord,
      
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