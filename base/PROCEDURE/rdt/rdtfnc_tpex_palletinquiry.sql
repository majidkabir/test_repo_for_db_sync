SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: IDSTW TPEX Pallet Inquiry                                         */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2015-10-12 1.0  AlanTan    SOS#354256 Created                              */
/* 2015-11-11 1.1  AlanTan    OTMIDTrack                                      */
/* 2016-09-30 1.2  Ung        Performance tuning                              */   
/* 2017-05-15 1.3  ChewKP     WMS-1905 - Rework                               */
/* 2018-10-18 1.4  Gan        Performance tuning                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_TPEX_PalletInquiry] (
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
   @cPalletStorer NVARCHAR( 15),
   @cPalletOrder  NVARCHAR( 10),
   @cPalletShip   NVARCHAR( 60),

   @cPalletMUID   INT,
   @cDestLoc      NVARCHAR( 20),
   @nSumCtn       INT,
   @nTotalRecord  INT,
   @nRecordCount  INT,
   @nOrderCtnCount INT,

 
      
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
   @cPalletLOC       = V_String2,
   @cPalletTruck     = V_String3,
   @cPalletShip      = V_String4,
   @cDestLoc         = V_String5,
  -- @nSumCtn          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,
   @cPalletOrder     = V_String7,
  -- @nTotalRecord     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8, 5), 0) = 1 THEN LEFT( V_String8, 5) ELSE 0 END,
  -- @nRecordCount     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,
      
   @nSumCtn      = V_Integer1,
   @nTotalRecord = V_Integer2,
   @nRecordCount = V_Integer3,
     
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

IF @nFunc = 1181  --Assign DropLoc
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Assign DropLoc
   IF @nStep = 1 GOTO Step_1   -- Scn = 4300. PalletID ,
	IF @nStep = 2 GOTO Step_2   -- Scn = 4301. Pallet Information
	IF @nStep = 3 GOTO Step_3   -- Scn = 4302. Pallet Information

END


RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1181. Menu
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
	SET @nScn = 4300
	SET @nStep = 1
	
	EXEC rdt.rdtSetFocusField @nMobile, 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4300. 
   PalletID (Input , Field01)

********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cPalletKey = ISNULL(RTRIM(@cInField01),'')
		
      -- Validate blank
      IF @cPalletKey = ''
      BEGIN
         SET @nErrNo = 94402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID req
         GOTO Step_1_Fail
      END
      
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                     WHERE PalletKey = @cPalletKey )
      BEGIN
         SET @nErrNo = 94401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDNotExist
         GOTO Step_1_Fail
      END
      
      
      
            
      --Load dbo.OTMIDTrack table
      SELECT 
         @cPalletLOC    = DropLoc,
         @cPalletTruck  = TruckID,
         @cPalletShip   = ShipmentID,
         @nSumCtn       = SUM(CAST ( UserDefine01  AS INT) ) 
      FROM dbo.OTMIDTrack WITH (NOLOCK)
      WHERE PalletKey = @cPalletKey
      GROUP BY DropLoc, TruckID, ShipmentID
      
           
      -- Prepare Next Screen Variable
      SET @cDestLoc    = Substring(@cPalletKey, 3,2) 
      
		SET @cOutField01 = @cPalletKey 
		SET @cOutField02 = @cPalletLOC
      SET @cOutField03 = @cPalletTruck
      SET @cOutField04 = @cPalletShip
      SET @cOutField05 = @cDestLoc
      SET @cOutField06 = @nSumCtn
      
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
Step 2. Scn = 4301. 
   Pallet ID ( Field01 ) 
   Drop Loc  ( Field02 ) 
   Truck ID  ( Field03 ) 
   ShipmentNo( Field04 ) 
   DEST LOC  ( Field05 ) 
   TTL CTN   ( Field06 ) 
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 
   BEGIN
      
       SELECT @nTotalRecord = COUNT ( DISTINCT ExternOrderKey ) 
       FROM dbo.OTMIDTRACK WITH (NOLOCK) 
       WHERE PalletKey = @cPalletKey
       
       SET @nRecordCount = 1 
       
       SELECT TOP 1 
           @cPalletOrder  = ExternOrderKey 
          ,@cPalletStorer = Principal
          ,@nOrderCtnCount = SUM( CAST( UserDefine01 AS INT ) ) 
       FROM dbo.OTMIDTRACK WITH (NOLOCK) 
       WHERE PalletKey = @cPalletKey
       GROUP BY ExternOrderKey, Principal
       ORDER BY ExternOrderKey 
       
       SET @cOutField01 = RIGHT((REPLICATE(' ', 3 - LEN(@nRecordCount)  ) + CAST(@nRecordCount AS VARCHAR(3))), 3)  --@nRecordCount 
       SET @cOutField02 = RIGHT((REPLICATE(' ', 3 - LEN(@nTotalRecord)  ) + CAST(@nTotalRecord AS VARCHAR(3))), 3)  --@nTotalRecord 
       SET @cOutField03 = @cPalletKey 
       SET @cOutField04 = @cPalletStorer
       SET @cOutField05 = @cPalletOrder
       SET @cOutField06 = @nOrderCtnCount
       
       

       -- EventLog - Sign In Function
       EXEC RDT.rdt_STD_EventLog
        @cActionType = '3', 
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cDeviceID   = @cTruckID,
        @cID         = @cPalletID,
        --@cRefNo1     = @cTruckID,
       -- @cRefNo2     = @cPalletID,
        @nStep       = @nStep

       SET @nScn  = @nScn + 1 
       SET @nStep = @nStep + 1 
      
	END  -- Inputkey = 1
   
   IF @nInputKey = 0 
   BEGIN
     
     
	  SET @cOutField01 = @cPalletKey 
	  SET @cOutField02 = @cPalletLOC
     SET @cOutField03 = @cPalletTruck
     SET @cOutField04 = @cPalletShip
     SET @cOutField05 = @cDestLoc
     SET @cOutField06 = @nSumCtn
     
		

     SET @nScn = @nScn - 1 
     SET @nStep = @nStep - 1 
      
      
   END
	GOTO Quit



END 
GOTO QUIT

/********************************************************************************
Step 3. Scn = 4302. 
   Pallet ID ( Field01 ) 
   Drop Loc  ( Field02 ) 
   Truck ID  ( Field03 ) 
   ShipmentNo( Field04 ) 
   DEST LOC  ( Field05 ) 
   TTL CTN   ( Field06 ) 
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 
   BEGIN
      
      SELECT TOP 1 
           @cPalletOrder  = ExternOrderKey 
          ,@cPalletStorer = Principal
          ,@nOrderCtnCount = SUM( CAST( UserDefine01 AS INT ) ) 
       FROM dbo.OTMIDTRACK WITH (NOLOCK) 
       WHERE PalletKey = @cPalletKey
       AND ExternOrderKey > @cPalletOrder
       GROUP BY ExternOrderKey, Principal
       ORDER BY ExternOrderKey 
       
       IF @@ROWCOUNT = 0 
       BEGIN
          SET @nErrNo = 94403
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Last record message display
          GOTO QUIT
       END

       SET @nRecordCount = @nRecordCount +  1
       
       SET @cOutField01 = RIGHT((REPLICATE(' ', 3 - LEN(@nRecordCount)  ) + CAST(@nRecordCount AS VARCHAR(3))), 3)  --@nRecordCount 
       SET @cOutField02 = RIGHT((REPLICATE(' ', 3 - LEN(@nTotalRecord)  ) + CAST(@nTotalRecord AS VARCHAR(3))), 3)  --@nTotalRecord 
       SET @cOutField03 = @cPalletKey 
       SET @cOutField04 = @cPalletStorer
       SET @cOutField05 = @cPalletOrder
       SET @cOutField06 = @nOrderCtnCount
       
    
      
      
	END  -- Inputkey = 1
   
   IF @nInputKey = 0 
   BEGIN
     
     
	  SET @cOutField01 = @cPalletKey 
	  SET @cOutField02 = @cPalletLOC
     SET @cOutField03 = @cPalletTruck
     SET @cOutField04 = @cPalletShip
     SET @cOutField05 = @cDestLoc
     SET @cOutField06 = @nSumCtn
     		

     SET @nScn = @nScn - 1 
     SET @nStep = @nStep - 1 
      
      
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

      V_UOM      = @cPUOM,
      
      V_String1  = @cPalletKey,
      V_String2 = @cPalletLOC       ,
      V_String3 = @cPalletTruck     ,
      V_String4 = @cPalletShip      ,
      V_String5 = @cDestLoc         ,
      --V_String6 = @nSumCtn          ,
      V_String7 = @cPalletOrder     ,
      --V_String8 = @nTotalRecord     ,
      --V_String9 = @nRecordCount     ,
      
      V_Integer1 = @nSumCtn,
      V_Integer2 = @nTotalRecord,
      V_Integer3 = @nRecordCount,
      
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