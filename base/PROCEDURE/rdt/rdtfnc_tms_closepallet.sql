SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: LF                                                              */ 
/* Purpose: LF                                                                */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2017-05-12 1.0  ChewKP     WMS-1881 Created                                */
/* 2018-10-17 1.1  Gan        Performance tuning                              */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_TMS_ClosePallet] (
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
   @fHeight       FLOAT,
   @fWeight       FLOAT,
   @cDropLoc      NVARCHAR( 10),
   @cValidateFacility NVARCHAR(5),
   @fPalletHeight FLOAT,
   @fPalletWeight FLOAT,
   @nMUID         FLOAT, 
   @fLength       FLOAT, 
   @fWidth        FLOAT,
   @cDataWindow   NVARCHAR( 50),

         
   @cTargetDB     NVARCHAR( 20),    
   @cLabelPrinter NVARCHAR( 10),    
   @cPaperPrinter NVARCHAR( 10),    
   @cLabelType    NVARCHAR( 20),    
   @cPLTWGTDFT    NVARCHAR( 10),
      
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
   
   @cPUOM      = V_UOM,
   @cPLTWGTDFT = V_String1, 
   
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

IF @nFunc = 1188  --TMS Close Pallet
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Assign DropLoc
   IF @nStep = 1 GOTO Step_1   -- Scn = 4840. PalletID
	

END


RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1188. Menu
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
   
   
        
   SET @cPLTWGTDFT = ''  
   SET @cPLTWGTDFT = rdt.RDTGetConfig( @nFunc, 'PLTWGTDFT', @cStorerKey)  
   
   IF @cPLTWGTDFT = ''    
   BEGIN  
      SET @cPLTWGTDFT = '0'  
      SET @cOutField03 = ''
   END    
   ELSE
   BEGIN
      SET @cOutField03 = @cPLTWGTDFT
   END
   
   -- Init screen
   SET @cOutField01 = '' 
   
   
   -- Set the entry point
	SET @nScn = 4840
	SET @nStep = 1
	
	EXEC rdt.rdtSetFocusField @nMobile, 1
	
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4840. 
   Pallet ID  (Input , Field01)
   Weight     (Input , Field02)
   Heigh      (Input , Field03)
   DropLoc    (Input , Field04)

********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

            
		SET @cPalletKey    = ISNULL(RTRIM(@cInField01),'')
      SET @fHeight       = ISNULL(RTRIM(@cInField02),0)
      SET @fWeight       = ISNULL(RTRIM(@cInField03),0)
      SET @cDropLoc      = ISNULL(RTRIM(@cInField04),'')
      
      --SET @fHeight = '2'
      --SET @fWeight       = '1.1'
      --SET @cDropLoc      = 'sfdsdgfsgd'
      --SET @cERRMSG = @cInField02
      --GOTO QUIT 

      -- Check blank    
      IF @cPalletKey = ''    
      BEGIN    
         SET @nErrNo = 109052    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PalletIDReq  
         SET @cPalletKey = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1   
         GOTO STEP_1_FAIL    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)  
                      WHERE PalletKey = @cPalletKey ) 
                      --AND Principal = @cStorerKey ) 
      BEGIN
         SET @nErrNo = 109053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PalletNotExist  
         SET @cPalletKey = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1   
         GOTO STEP_1_FAIL  
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)  
                  WHERE PalletKey = @cPalletKey
                  --AND Principal = @cStorerKey
                  AND MUStatus <> 0  ) 
      BEGIN
         SET @nErrNo = 109054
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvPLTStatus
         SET @cPalletKey = '' 
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Param1   
         GOTO STEP_1_FAIL  
      END
      
      SELECT 
             --@cValidateFacility = ISNULL(UDF03,'')  
    			 @fPalletHeight = ISNULL(UDF04,0)
    			,@fPalletWeight = ISNULL(UDF05,0)
      FROM dbo.CodeLkup WITH (NOLOCK) 
      WHERE ListName = 'OTMRDT'
      AND StorerKey = @cStorerKey
      
      
      
      IF @fHeight = 0 
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 2   
         GOTO STEP_1_FAIL    
      END

      
      
      IF RDT.rdtIsValidQTY( @fHeight, 21) = 0     
      BEGIN    
         SET @nErrNo = 109055    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidQTY'   
         SET @fHeight = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 2   
         GOTO STEP_1_FAIL    
      END    
      
      IF @fHeight > @fPalletHeight 
      BEGIN    
         SET @nErrNo = 109056   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'HeightOverLimit' 
         SET @fHeight = ''     
         EXEC rdt.rdtSetFocusField @nMobile, 2   
         GOTO STEP_1_FAIL    
      END 
            
      IF @fWeight = 0 
      BEGIN
         SET @fWeight = 0
         EXEC rdt.rdtSetFocusField @nMobile, 3   
         GOTO STEP_1_FAIL    
      END
            
      IF RDT.rdtIsValidQTY( @fWeight, 21) = 0     
      BEGIN    
         SET @nErrNo = 109057    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidQTY'   
         SET @fWeight = @cPLTWGTDFT 
         EXEC rdt.rdtSetFocusField @nMobile, 3   
         GOTO STEP_1_FAIL    
      END    
      
      IF @fWeight > @fPalletWeight 
      BEGIN    
         SET @nErrNo = 109058   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WeightOverLimit'    
         SET @fWeight = @cPLTWGTDFT 
         EXEC rdt.rdtSetFocusField @nMobile, 3   
         GOTO STEP_1_FAIL    
      END 
      
      IF @cDropLoc = ''
      BEGIN    
         SET @nErrNo = 109059  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LocReq'    
         EXEC rdt.rdtSetFocusField @nMobile, 4   
         GOTO STEP_1_FAIL    
      END 
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK) 
                      WHERE Facility = @cFacility 
                      AND Loc = @cDropLoc ) 
      BEGIN    
         SET @nErrNo = 109060
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidLoc'    
         SET @cDropLoc = ''
         EXEC rdt.rdtSetFocusField @nMobile, 4   
         GOTO STEP_1_FAIL    
      END 
      
      DECLARE C_OTMCLOSEPALLET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      
      SELECT MUID, Length, Width 
      FROM dbo.OTMIDTrack WITH (NOLOCK) 
      --INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
      WHERE PalletKey = @cPalletKey
      --AND Principal = @cStorerKey 
      AND MUStatus = 0 
      ORDER BY MUID 
      
      OPEN C_OTMCLOSEPALLET
      FETCH NEXT FROM C_OTMCLOSEPALLET INTO @nMUID, @fLength, @fWidth 
      WHILE @@FETCH_STATUS = 0
      BEGIN
         
         UPDATE dbo.OTMIDTrack WITH (ROWLOCK) 
         SET MUStatus = '2' 
             , GrossVolume = @fHeight * @fWidth * @fLength
             , Height = @fHeight
             , GrossWeight = @fWeight
             , DropLoc = @cDropLoc 
             , EditDate = GetDate() 
             , EditWho = @cUserName
         WHERE MUID = @nMUID 
         
         IF @@ERROR <> 0 
         BEGIN    
            SET @nErrNo = 109061
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOTMFail'    
            EXEC rdt.rdtSetFocusField @nMobile, 4   
            GOTO STEP_1_FAIL    
         END 
         
         FETCH NEXT FROM C_OTMCLOSEPALLET INTO @nMUID, @fLength, @fWidth    
      END   
      CLOSE C_OTMCLOSEPALLET        
      DEALLOCATE C_OTMCLOSEPALLET 
      
      -- Print Carton Label --
      SET @cDataWindow = ''
      SET @cTargetDB   = ''
      
      IF EXISTS ( SELECT 1
                  FROM rdt.rdtReport WITH (NOLOCK)     
                  WHERE StorerKey = @cStorerKey    
                  AND   ReportType = 'OTMPLTLBL1'    ) 
      BEGIN 
         

         SELECT @cDataWindow = DataWindow,     
                @cTargetDB = TargetDB     
         FROM rdt.rdtReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
         AND   ReportType = 'OTMPLTLBL1'   
             
         EXEC RDT.rdt_BuiltPrintJob      
             @nMobile,      
             @cStorerKey,      
             'OTMPLTLBL1',    -- ReportType      
             'OTMPLTLBL1',    -- PrintJobName      
             @cDataWindow,      
             @cPrinter,      
             @cTargetDB,      
             @cLangCode,      
             @nErrNo  OUTPUT,      
             @cErrMsg OUTPUT,    
             @cPalletKey--,   
             --@cPickSlipNo, 
             --@nFromCartonNo,
             --@nToCartonNo 
                
      END

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      
      IF @cPLTWGTDFT <> '' 
      BEGIN
         SET @cOutField03 = @cPLTWGTDFT
      END
      ELSE
      BEGIN
         SET @cOutField03 = ''
      END
      
      SET @cOutField04 = ''

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
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @fHeight
      SET @cOutField03 = @fWeight
      SET @cOutField04 = @cDropLoc
      
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
      V_String1  = @cPLTWGTDFT, 
      
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