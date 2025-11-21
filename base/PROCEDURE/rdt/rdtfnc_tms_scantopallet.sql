SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: LF                                                              */ 
/* Purpose: IDSTW TMS Scan To Pallet                                          */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2017-05-03 1.0  ChewKP     WMS-1693 Created                                */
/* 2017-07-26 1.1  ChewKP     WMS-1693 V 4.0 Changes (ChewKP01)               */
/* 2018-10-17 1.2  Gan        Performance tuning                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_TMS_ScanToPallet] (
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
   @cPaperPrinter NVARCHAR(20),
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
   @nShipmentLength INT,
   @nPalletLength INT,
   @cExtendedValidateSP NVARCHAR(30),   
   @cExtendedUpdateSP   NVARCHAR(30),   
   @cCountType          NVARCHAR(30),    
   @cSQL                NVARCHAR(1000), 
   @cSQLParam           NVARCHAR(1000), 
   @cDataWindow			NVARCHAR( 50),  
   @cTargetDB    			NVARCHAR( 20),   
   @cToWHS              NVARCHAR( 20),
   @cPreFix             NVARCHAR( 10),
   @cOMTPLTCounter      NVARCHAR(  8),
   @cPrintLoadingList   NVARCHAR(  1),
   @nMUID               INT,
   @nCounter            INT,
   @nI                  INT,

  
      
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
   @cPaperPrinter = Printer_Paper,
   
   @cPUOM       = V_UOM,
   @cTruckID    = V_String1,
   @cShipmentNo = V_String2,
  -- @nPalletCount= CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,  
   @cExtendedValidateSP = V_String4, 
   @cExtendedUpdateSP   = V_String5, 
   @cCountType          = V_String6, 
   @cPrintLoadingList   = V_String7,
   @cToWHS              = V_String8,
   
   @nPalletCount = V_Integer1,

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



IF @nFunc = 1187  --Assign DropLoc
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Assign DropLoc
   IF @nStep = 1 GOTO Step_1   -- Scn = 4820. TruckID 
	IF @nStep = 2 GOTO Step_2   -- Scn = 4821. PalletID
	IF @nStep = 3 GOTO Step_3   -- Scn = 4822. Information

END


RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1187. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
	SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile
   
   
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
   BEGIN
      SET @cExtendedValidateSP = ''
   END
   
   
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
   BEGIN
      SET @cExtendedUpdateSP = ''
   END
   
   SET @cPrintLoadingList = rdt.RDTGetConfig( @nFunc, 'PrintLoadingList', @cStorerKey)
   IF @cPrintLoadingList = '0'  
   BEGIN
      SET @cExtendedUpdateSP = ''
   END
   
   SET @cCountType = rdt.RDTGetConfig( @nFunc, 'CountType', @cStorerKey)
   IF @cCountType = '0'  
   BEGIN
      SET @cCountType = ''
   END
   
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
	SET @nScn = 4820
	SET @nStep = 1
	
	EXEC rdt.rdtSetFocusField @nMobile, 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4820. 
   TruckID (Input , Field01)
   To WHS  (Input , Field03) 
   Shipment No (Input, Field02) 

********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @cTruckID    = ISNULL(RTRIM(@cInField01),'')
	   SET @cShipmentNo = ISNULL(RTRIM(@cInField02),'')
	   SET @cToWHS      = ISNULL(RTRIM(@cInField03),'')
	   
	    
     IF @cExtendedValidateSP <> ''
     BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cOption, @cPalletID, @cTruckID, @cShipmentNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@cOption        NVARCHAR( 1),  ' +
               '@cPalletID      NVARCHAR( 20), ' +
               '@cTruckID       NVARCHAR( 20), ' +
               '@cShipmentNo    NVARCHAR( 60), ' +
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
               
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cOption, @cPalletID, @cTruckID, @cShipmentNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
            IF @nErrNo <> 0 
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_1_Fail 
            END
         END
     END
     ELSE
		 BEGIN
         -- Validate blank
         IF @cTruckID = ''
         BEGIN
            SET @nErrNo = 108601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TruckID req
            SET @cTruckID = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      
--         IF @cShipmentNo = ''
--         BEGIN 
--            SET @nErrNo = 108602
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipmentNo req
--            GOTO Step_1_Fail
--         END
         
         IF @cToWHS = ''
         BEGIN 
            SET @nErrNo = 108603
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToWHS Req
            SET @cToWHS = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_1_Fail
         END
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) 
         								 WHERE ListName = 'PLTDECODE'
         								 AND Code = @cToWHS ) 
         BEGIN
         	SET @nErrNo = 108604
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToWHS
            SET @cToWHS = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_1_Fail
       	 END
         
         SELECT @cPreFix = UDF01 
         FROM dbo.Codelkup WITH (NOLOCK) 
         WHERE ListName = 'PLTDECODE'    
         AND Code = @cToWHS
         
         IF @cShipmentNo = '' 
         BEGIN
	         EXECUTE dbo.nspg_GetKey
	                'OTMPLT',
	                8 ,
	                @cOMTPLTCounter    OUTPUT,
	                @b_success         OUTPUT,
	                @nErrNo            OUTPUT,
	                @cErrMsg           OUTPUT

	         IF @b_success<>1
	         BEGIN
	            SET @nErrNo = 108605
	            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKeyFail
	            EXEC rdt.rdtSetFocusField @nMobile, 2
	            GOTO Step_1_Fail
	         END
	         
	         SET @cShipmentNo = @cToWHS + @cOMTPLTCounter
       	 END
         
     END     

     IF @cPrintLoadingList = '1'
     BEGIN
        IF @cPrinter = '' 
        BEGIN    
            SET @nErrNo = 108613
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrinterReq
            --SET @cToWHS = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_1_Fail
        END
     END

     IF @cCountType <> ''
     BEGIN
        SELECT @nPalletCount = Count(DISTINCT CaseID)
        FROM dbo.OTMIDTrack WITH (NOLOCK)
        WHERE TruckID = @cTruckID
        AND ShipmentID = @cShipmentNo
        AND MUStatus > '0'
     END
     ELSE
     BEGIN
        SELECT @nPalletCount = Count(DISTINCT PalletKey)
        FROM dbo.OTMIDTrack WITH (NOLOCK)
        WHERE TruckID = @cTruckID
        AND ShipmentID = @cShipmentNo
        AND UserDefine02 = ''
        AND MUStatus <> '8'
     END
      
      -- Prepare Next Screen Variable
		 SET @cOutField01 = ''
		 SET @cOutField02 = @nPalletCount
       SET @cOutField03 = ''
	 
		 -- GOTO Next Screen
		 SET @nScn = @nScn + 1
	    SET @nStep = @nStep + 1

       EXEC rdt.rdtSetFocusField @nMobile, 1
	    
		
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
      SET @cOutField01 = @cTruckID
      SET @cOutField02 = @cShipmentNo
      SET @cOutField03 = @cToWHS
      
  END
   

END 
GOTO QUIT

/********************************************************************************
Step 2. Scn = 4821. 
   PalletID  (field01, input)
   Scan Count(field02)
   Option    (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 
   BEGIN
	   
	    SET @cPalletID = ISNULL(RTRIM(@cInField01),'')
	    SET @cOption   = ISNULL(RTRIM(@cInField03),'')
	   
      
	    
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cOption, @cPalletID, @cTruckID, @cShipmentNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@cOption        NVARCHAR( 1),  ' +
               '@cPalletID      NVARCHAR( 20), ' +
               '@cTruckID       NVARCHAR( 20), ' +
               '@cShipmentNo    NVARCHAR( 60), ' +
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
               
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cOption, @cPalletID, @cTruckID, @cShipmentNo, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
            IF @nErrNo <> 0 
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_2_Fail 
            END
         END
      END
      ELSE
      BEGIN
      	 
      	 IF @cPalletID = ''  AND @cOption = '' 
      	 BEGIN
      	      SET @nErrNo = 108607
	            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --EitherInputReq
	            GOTO Step_2_Fail	
      	 END
      	 
          IF @cPalletID <> '' 
          BEGIN
      	 
      	    IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
      	 								    WHERE PalletKey = @cPalletID  ) 
      	    BEGIN
      	 			   SET @nErrNo = 108606
	               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletIDNotExist
	               GOTO Step_2_Fail
      	    END
      	 
      	    IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
      	 						    WHERE PalletKey = @cPalletID
      	 						    --AND TruckID = @cTruckID 
      	 						    AND MUStatus = 0 ) 
				    BEGIN
      	 			   SET @nErrNo = 108608
	               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletNotClosed
	               GOTO Step_2_Fail
      	    END
      	 
      	    IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
      	 						    WHERE PalletKey = @cPalletID
      	 						    AND TruckID = @cTruckID 
      	 						    AND MUStatus IN ( '3', '5' )  ) 
				    BEGIN
      	 			   SET @nErrNo = 108609
	               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletIDScanned
	               GOTO Step_2_Fail
      	    END	      	 	
      	 END

      	 IF @cOption <> '' 
      	 BEGIN
	      	IF @cOption <> '1'
	         BEGIN
	               SET @nErrNo = 108611
	               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
	               GOTO Step_2_Fail
	         END					 
      	 END
--         IF @cOption <> '1'
--         BEGIN
--            IF @cPalletID = ''
--            BEGIN
--               SET @nErrNo = 94353
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletID Req
--               GOTO Step_2_Fail
--            END
--
--            IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK) 
--                           WHERE PalletKey = @cPalletID )
--            BEGIN
--              SET @nErrNo = 94359
--              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletIDNotExist
--              GOTO Step_2_Fail
--            END
--
--            IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
--                        WHERE PalletKey = @cPalletID
--                        AND TruckID = @cTruckID
--                        AND UserDefine02 = ''
--                        AND MUStatus IN ('5', '8') )
--            BEGIN
--              SET @nErrNo = 94358
--              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltIDScanned
--              GOTO Step_2_Fail
--            END
--
--            IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
--                        WHERE PalletKey = @cPalletID
--                        AND TruckID <> @cTruckID
--                        AND MUStatus = '8'
--                        AND UserDefine02 = '' )
--            BEGIN
--              SET @nErrNo = 94361
--              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltIDScanned
--              GOTO Step_2_Fail
--            END
--         END
      END
      
       
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @cOption, @cPalletID, @cTruckID, @cShipmentNo, @cUserName, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
                '@nMobile        INT, ' +
                '@nFunc          INT, ' +
                '@cLangCode      NVARCHAR( 3), ' +
                '@nStep          INT, ' +
                '@cOption        NVARCHAR( 1),  ' +
                '@cPalletID      NVARCHAR( 20), ' +
                '@cTruckID       NVARCHAR( 20), ' +
                '@cShipmentNo    NVARCHAR( 60), ' +
                '@cUserName      NVARCHAR( 15), ' +
                '@nErrNo         INT           OUTPUT, ' + 
                '@cErrMsg        NVARCHAR( 20) OUTPUT'
         
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @cOption, @cPalletID, @cTruckID, @cShipmentNo, @cUserName, @nErrNo OUTPUT, @cErrMsg OUTPUT 
         
            IF @nErrNo <> 0 
                GOTO Step_2_Fail
                
            ELSE IF @cOption = 1
            BEGIN
               SELECT @nPalletCount = Count(DISTINCT CaseID)
               FROM dbo.OTMIDTrack WITH (NOLOCK)
               WHERE TruckID = @cTruckID
               AND ShipmentID = @cShipmentNo
               AND MUStatus = '9'

               SET @cOutField01 = @cTruckID
               SET @cOutField02 = @nPalletCount
            
               SET @nScn = @nScn + 1 
               SET @nStep = @nStep + 1 
            
               GOTO QUIT 
            END
         END
      END
      ELSE
      BEGIN
         IF @cOption <> '1'
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                        WHERE PalletKey = @cPalletID
                        AND MUStatus <= '7' ) 
            BEGIN            
               UPDATE dbo.OTMIDTrack WITH (ROWLOCK)
               SET  TruckID = @cTruckID
                  , ShipmentID = @cShipmentNo
                  , LocationName = @cToWHS
                  , MUStatus = '5' 
                  , EditWho  = @cUserName
                  , EditDate = GetDATE() 
               WHERE PalletKey = @cPalletID
               AND MUStatus <> '8'
               
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 108610
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletFail
                  GOTO Step_2_Fail
               END
            END
         END
         
         
         IF @cOption = '1'
         BEGIN
            -- Update Pallet to Status = '8' with shipment ID
            DECLARE C_Pallet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT MUID
            FROM dbo.OTMIDTrack WITH (NOLOCK) 
            WHERE TruckID = @cTruckID
            AND   ShipmentID = @cShipmentNo
            AND   MUStatus = '5'
            ORDER BY MUID      
             
            OPEN C_Pallet      
            FETCH NEXT FROM C_Pallet INTO  @nMUID 
            WHILE (@@FETCH_STATUS <> -1)      
            BEGIN      
               UPDATE dbo.OTMIDTrack WITH (ROWLOCK)
               SET MUStatus = '8' 
                  ,EditDate = GetDate()
                  ,Editwho = @cUSerName
               WHERE MUID = @nMUID
            
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 108612
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletFail
                  GOTO Step_2_Fail
               END
            
               FETCH NEXT FROM C_Pallet INTO  @nMUID
            
            END
            CLOSE C_Pallet      
            DEALLOCATE C_Pallet
            
            -- Update Pallet to Status = '8' without Shipment ID -- (ChewKP01) 
            DECLARE C_PalletID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT MUID
            FROM dbo.OTMIDTrack WITH (NOLOCK) 
            WHERE TruckID = @cTruckID
            AND   ShipmentID = ''
            AND   MUStatus = '5'
            ORDER BY MUID      
             
            OPEN C_PalletID      
            FETCH NEXT FROM C_PalletID INTO  @nMUID 
            WHILE (@@FETCH_STATUS <> -1)      
            BEGIN      
               UPDATE dbo.OTMIDTrack WITH (ROWLOCK)
               SET MUStatus = '8' 
                  ,ShipmentID = @cShipmentNo
                  ,EditDate = GetDate()
                  ,Editwho = @cUSerName
               WHERE MUID = @nMUID
            
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 108614
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPalletFail
                  GOTO Step_2_Fail
               END
            
               FETCH NEXT FROM C_PalletID INTO  @nMUID
            
            END
            CLOSE C_PalletID      
            DEALLOCATE C_PalletID
            
            -- Print Label
            
            IF @cPrintLoadingList > '0'
            BEGIN
                     SET @nI = 0 

	            	   SELECT @cDataWindow = DataWindow,     
	          					@cTargetDB = TargetDB     
					      FROM rdt.rdtReport WITH (NOLOCK)     
					      WHERE StorerKey = @cStorerKey    
					      AND   ReportType = 'TMSLIST'   
					      
					      SET @nCounter = @cPrintLoadingList

					      WHILE @nI < @nCounter
					      BEGIN 
                        

   					      EXEC RDT.rdt_BuiltPrintJob      
   					                   @nMobile,      
   					                   @cStorerKey,      
   					                   'TMSLIST',    -- ReportType      
   					                   'TMSLIST',    -- PrintJobName      
   					                   @cDataWindow,      
   					                   @cPaperPrinter,      
   					                   @cTargetDB,      
   					                   @cLangCode,      
   					                   @nErrNo  OUTPUT,      
   					                   @cErrMsg OUTPUT, 
   					                   @cShipmentNo,   
   					                   @cTruckID,
   					                   @cFacility
					            
					        SET @nI = @nI + 1   
					      END             
          	END
            
            
            SELECT @nPalletCount = Count(DISTINCT PalletKey)
            FROM dbo.OTMIDTrack WITH (NOLOCK)
            WHERE TruckID = @cTruckID
            AND ShipmentID = @cShipmentNo
            --AND UserDefine02 = ''
            AND MUStatus = '8'

            SET @cOutField01 = @cTruckID
            SET @cOutField02 = @nPalletCount
         
            SET @nScn = @nScn + 1 
            SET @nStep = @nStep + 1 
         
            GOTO QUIT 
            
         END
             
      END
      
      --IF @cCountType <> ''
      --BEGIN
      --   SELECT @nPalletCount = Count(DISTINCT CaseID)  --Count by CaseID
      --   FROM dbo.OTMIDTrack WITH (NOLOCK)
      --   WHERE TruckID = @cTruckID
      --   AND ShipmentID = @cShipmentNo
      --   AND MUStatus > '0'
      --END
      --ELSE
      --BEGIN
         SELECT @nPalletCount = Count(DISTINCT PalletKey)
         FROM dbo.OTMIDTrack WITH (NOLOCK)
         WHERE TruckID = @cTruckID
         AND ShipmentID = @cShipmentNo
         --AND UserDefine02 = ''
         AND MUStatus <> '8'
      --END 
       
      SET @cOutField01 = ''
      SET @cOutField02 = @nPalletCount
      SET @cOutField03 = ''
      
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
       --@cRefNo2     = @cPalletID,
       @nStep       = @nStep
      
      
	 END  -- Inputkey = 1
   
   IF @nInputKey = 0 
   BEGIN
     
     SET @cOutfield01 = ''
     SET @cOutField02 = ''
     
     SET @nScn = @nScn - 1 
     SET @nStep = @nStep - 1 
       
     EXEC rdt.rdtSetFocusField @nMobile, 1 
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
      --IF @cCountType <> ''
      --BEGIN
      --   SELECT @nPalletCount = Count(DISTINCT CaseID)
      --   FROM dbo.OTMIDTrack WITH (NOLOCK)
      --   WHERE TruckID = @cTruckID
      --   AND ShipmentID = @cShipmentNo
      --   AND MUStatus > '0'
      --END
       
      --ELSE
      --BEGIN
         SELECT @nPalletCount = Count(DISTINCT PalletKey)
         FROM dbo.OTMIDTrack WITH (NOLOCK)
         WHERE TruckID = @cTruckID
         AND ShipmentID = @cShipmentNo
         --AND UserDefine02 = ''
         AND MUStatus <> '8'
      --END

      SET @cOutField02 = @nPalletCount
      EXEC rdt.rdtSetFocusField @nMobile, 2
   END

END 
GOTO QUIT


/********************************************************************************
Step 3. Scn = 4823. 
   TruckID (Input , Field01)
   Shipment No (Input, Field02) 

********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
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
        
        SET @cTruckID = ''
	     SET @cShipmentNo = ''
	     
        SET @cOutfield01 = ''
        SET @cOutfield02 = ''
     
        SET @nScn = @nScn - 2 
        SET @nStep = @nStep - 2 
	    
		
	END  -- Inputkey = 1
  

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
      Printer_Paper = @cPaperPrinter,
      UserName  = @cUserName,
		InputKey  =	@nInputKey,		

      V_UOM      = @cPUOM,
      
      V_String1 = @cTruckID,
      V_String2 = @cShipmentNo,
      --V_String3 = @nPalletCount,
      V_String4 = @cExtendedValidateSP,
      V_String5 = @cExtendedUpdateSP,
      V_String6 = @cCountType,
      V_String7 = @cPrintLoadingList, 
      V_String8 = @cToWHS,
      
      V_Integer1 = @nPalletCount,
    
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