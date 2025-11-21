SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

        
/******************************************************************************/        
/* Store procedure: rdtfnc_PTLCartRemove                                      */        
/* Copyright: LF Logistics                                                    */        
/*                                                                            */        
/* Purpose : Customize PTL Cart Remove                                        */        
/*                                                                            */        
/* Date       Rev  Author     Purposes                                        */        
/* 2015-04-05 1.0  YeeKung    WMS-8257 PTL Cart Release                       */        
/******************************************************************************/        
        
        
CREATE PROC [RDT].[rdtfnc_PTLCartRemove] (        
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
   @nCount     			INT,        
   @bSuccess   			INT,        
   @nTranCount 			INT,        
   @cSQL       			NVARCHAR( MAX),        
   @cSQLParam  			NVARCHAR( MAX),        
   @nRowCount  			INT,         
   @cNewToteID 			NVARCHAR( 20),         
   @nToteQTY   			INT,        
        
   @cResult01  			NVARCHAR( 20),        
   @cResult02  			NVARCHAR( 20),        
   @cResult03  			NVARCHAR( 20),        
   @cResult04  			NVARCHAR( 20),        
   @cResult05  			NVARCHAR( 20),        
   @cResult06  			NVARCHAR( 20),        
   @cResult07  			NVARCHAR( 20),        
   @cResult08  			NVARCHAR( 20),        
   @cResult09  			NVARCHAR( 20),        
   @cResult10  			NVARCHAR( 20)        
        
-- RDT.RDTMobRec variable        
DECLARE        
   @nFunc         		INT,        
   @nScn          		INT,        
   @nStep         		INT,        
   @cLangCode     		NVARCHAR( 3),        
   @nInputKey     		INT,        
   @nMenu         		INT,        
        
   @cStorerKey    		NVARCHAR( 15),        
   @cFacility    	 		NVARCHAR( 5),        
   @cPrinter      		NVARCHAR( 20),        
   @cUserName     		NVARCHAR( 18),        
   @cDeviceID     		NVARCHAR( 20),        
        
   @cOrderKey     		NVARCHAR(10),        
   @cLOC          		NVARCHAR(10),        
   @cSKU          		NVARCHAR(20),        
   @cSKUDescr     		NVARCHAR(60),        
   @nQTY 	         	INT,        
        
   @cCartID       		NVARCHAR(10),        
   @cPickZone     		NVARCHAR(10),        
   @cMethod       		NVARCHAR(1),        
   @cDPLKey       		NVARCHAR(10),        
   @cToteID       		NVARCHAR(20),        
   @cBatch        		NVARCHAR(10),        
   @cPosition     		NVARCHAR(10),        
   @nTotalOrder   		INT,        
   @nTotalTote    		INT,        
   @nTotalPOS     		INT,        
   @nTotalQTY     		INT,        
   @nNextPage     		INT,        
   @cOption       		NVARCHAR(1),        
   @cPickSeq      		NVARCHAR(1),        
        
   @cPTLPKZoneReq       NVARCHAR( 20),        
   @cExtendedValidateSP NVARCHAR( 20),        
   @cExtendedUpdateSP   NVARCHAR( 20),        
   @cExtendedInfoSP     NVARCHAR( 20),        
   @cAllowSkipTask      NVARCHAR( 1),        
   @cDecodeLabelNo      NVARCHAR( 20),        
   @cLight              NVARCHAR( 1),        
   @cExtendedInfo       NVARCHAR( 20),        
   @cPassOnCart         NVARCHAR( 1),        
   @cDefaultDeviceID    NVARCHAR( 20),        
   @cDecodeSP           NVARCHAR( 20),         
   @cRow                NVARCHAR( 5),          
   @cCol                NVARCHAR( 5),         
   @cStatus             INT,         
        
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
   @nFunc      			= Func,        
   @nScn       			= Scn,        
   @nStep      			= Step,        
   @nInputKey  			= InputKey,        
   @nMenu      			= Menu,        
   @cLangCode  			= Lang_code,        
        
   @cStorerKey 			= StorerKey,        
   @cFacility  			= Facility,        
   @cPrinter   			= Printer,        
   @cUserName  			= UserName,        
   @cDeviceID  			= DeviceID,        
        
   @cOrderKey   			= V_OrderKey,        
   @cLOC        			= V_LOC,        
   @cSKU        			= V_SKU,        
   @cSKUDescr   			= V_SKUDescr,        
   @nQTY        			= V_Qty,          
   @nTotalOrder 			= V_Integer1,          
   @nTotalTote  			= V_Integer2,          
   @nTotalPOS   			= V_Integer3,          
   @nTotalQTY   			= V_Integer4,          
   @nNextPage   			= V_Integer5,             
        
   @cCartID     			= V_String1,        
   @cPickZone   			= V_String2,        
   @cMethod     			= V_String3,        
   @cDPLKey     			= V_String4,        
   @cToteID     			= V_String5,        
   @cPosition   			= V_String6,        
   @cBatch      			= V_String7,        
   @cOption     			= V_String13,        
   @cPickSeq    			= V_String14,        
   @cRow        			= V_String15,        
   @cCol        			= V_String16,        
        
   @cExtendedValidateSP = V_String20,        
   @cExtendedUpdateSP   = V_String21,        
   @cExtendedInfoSP     = V_String22,        
   @cPTLPKZoneReq       = V_String23,        
   @cAllowSkipTask      = V_String24,        
   @cDecodeLabelNo      = V_String25,        
   @cLight              = V_String26,        
   @cExtendedInfo       = V_String27,        
   @cPassOnCart         = V_String28,        
   @cDecodeSP           = V_String29,        
   @cStatus             = V_String30,        
        
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
   @cFieldAttr05 =  FieldAttr05, @cFieldAttr06   = FieldAttr06,        
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,        
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,        
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,        
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,        
   @cFieldAttr15 =  FieldAttr15        
        
FROM rdt.rdtMobRec (NOLOCK)        
WHERE Mobile = @nMobile        
        
IF @nFunc = 1833  -- PTL Cart        
BEGIN        
   -- Redirect to respective screen        
   IF @nStep = 0 GOTO Step_0   -- PTL Cart        
   IF @nStep = 1 GOTO Step_1   -- Scn = 5360. Input Device ID of PTL Cart        
   IF @nStep = 2 GOTO Step_2   -- Scn = 5361. successful release cart        
END        
RETURN -- Do nothing if incorrect step        
        
/********************************************************************************        
Step 0. func = 1833. Menu        
********************************************************************************/        
Step_0:        
BEGIN        
        
   -- EventLog - Sign In Function              
   EXEC RDT.rdt_STD_EventLog              
     @cActionType = '1', -- Sign in function              
     @cUserID     = @cUserName,              
     @nMobileNo   = @nMobile,              
     @nFunctionID = @nFunc,              
     @cFacility   = @cFacility,              
     @cStorerKey  = @cStorerkey,              
     @nStep       = @nStep           
        
  -- Set the entry point        
   SET @nScn = 5360        
   SET @nStep = 1        
        
END        
GOTO Quit        
        
/********************************************************************************        
Step 1. Scn = 6110        
 ID  (Field01,input)        
********************************************************************************/        
Step_1:        
BEGIN        
   IF @nInputKey = 1 --ENTER        
   BEGIN        
      SET @cDeviceID = @cInField01        
        
      IF (@cDeviceID) = ''         
      BEGIN         
         SET @nErrNo = 136651         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need_Cart'              
         GOTO Step_1_Fail          
      END        
        
      IF NOT EXISTS(SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)         
      WHERE DeviceType = 'CART' AND DeviceID = @cDeviceID)         
      BEGIN         
         SET @nErrNo = 136652         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid CartID'              
         GOTO Step_1_Fail          
      END        
        
      SELECT TOP 1 @cPickZone=LC.PickZone,@cDPLKey=CL.DeviceProfileLogKey FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
      JOIN rdt.rdtPTLCartLog CL WITH (NOLOCK)  
      on PD.orderkey=CL.orderkey    
      JOIN dbo.LOC LC WITH (NOLOCK)         
      ON PD.loc=LC.loc         
      WHERE LC.FACILITY= @cFacility AND  CL.CARTID=@cDeviceID   
        
      IF @@ROWCOUNT = 0     
      BEGIN    
         IF EXISTS(SELECT TOP 1 *   
                     FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
                     JOIN rdt.rdtPTLCartLog CL WITH (NOLOCK)  
                     ON PD.orderkey=CL.orderkey  
                     WHERE CL.STORERKEY=@cStorerKey AND CL.CARTID=@cDeviceID )  
         BEGIN  
            SET @nErrNo = 136653         
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff Facility'              
            GOTO Step_1_Fail     
         END   
         ELSE  
         BEGIN   
             SELECT TOP 1 @cPickZone=PickZone,@cDPLKey=DeviceProfileLogKey   
             FROM rdt.rdtPTLCartLog  WITH (NOLOCK)  
             WHERE STORERKEY=@cStorerKey AND CARTID=@cCartID  
         END     
      END    
        
      BEGIN TRAN       
        
      -- Close cart        
      EXEC rdt.rdt_PTLCart_CloseCart @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey        
         ,@cDeviceID        
         ,@cPickZone        
         ,@cDPLKey        
         ,@nErrNo     OUTPUT        
         ,@cErrMsg    OUTPUT        
      IF @nErrNo <> 0        
         GOTO Quit      
           
      IF EXISTS ( SELECT * FROM  rdt.rdtPTLCartLog  WITH (NOLOCK)  
                  WHERE STORERKEY=@cStorerKey AND CARTID=@cDeviceID )  
      BEGIN  
         ROLLBACK TRAN  
         SET @nErrNo = 136654         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CARTIDREMAIN'              
         GOTO Step_1_Fail  
      END  
  
      COMMIT TRAN  
    
      SET @cOutField03 = 'Success Rmv Cart'        
        
      -- Go to next screen        
      SET @nScn = @nScn + 1        
      SET @nStep = @nStep + 1        
   END        
        
   IF @nInputKey = 0        
   BEGIN        
      -- EventLog        
      EXEC RDT.rdt_STD_EventLog        
         @cActionType = '9', -- Sign-out        
         @cUserID     = @cUserName,        
         @nMobileNo   = @nMobile,        
         @nFunctionID = @nFunc,        
         @cFacility   = @cFacility,        
         @cStorerKey  = @cStorerkey,          
         @nStep       = @nStep          
        
      -- Back to main menu        
      SET @nFunc = @nMenu        
      SET @nScn  = @nMenu        
      SET @nStep = 0        
      SET @cOutField01 = ''        
      SET @cOutField02 = ''        
      SET @cOutField03 = ''        
   END        
        
   Step_1_Fail:        
   BEGIN        
      SET @cDeviceID=''        
      SET @cInField01=''        
   END        
        
END        
GOTO Quit        
        
/********************************************************************************        
Step 2. Scn = 6111         
        
(Field03, display)              
********************************************************************************/        
Step_2:        
BEGIN        
   IF @nInputKey = 1        
   BEGIN        
      -- Go to next screen        
      SET @nScn = @nScn         
      SET @nStep = @nStep         
   END        
        
   IF @nInputKey = 0        
   BEGIN        
      SET @cOutField03=''        
      -- Go to previous screen        
      SET @nScn = @nScn - 1        
      SET @nStep = @nStep - 1        
   END        
        
END        
GOTO Quit        
        
        
        
/********************************************************************************        
Quit. Update back to I/O table, ready to be pick up by JBOSS        
********************************************************************************/        
Quit:        
        
BEGIN        
   UPDATE RDTMOBREC WITH (ROWLOCK) SET        
      EditDate 		= GETDATE(),         
      ErrMsg 			= @cErrMsg,        
      Func   			= @nFunc,        
      Step   			= @nStep,        
      Scn    			= @nScn,        
        
      StorerKey 		= @cStorerKey,        
      Facility  		= @cFacility,        
      Printer   		= @cPrinter,        
      -- UserName  = @cUserName,        
      InputKey  		= @nInputKey,        
        
      V_OrderKey 		= @cOrderKey,        
      V_LOC      		= @cLOC,        
      V_SKU      		= @cSKU,        
      V_SKUDescr 		= @cSKUDescr,        
      V_QTY      		= @nQTY,        
      V_Integer1 		= @nTotalOrder,          
      V_Integer2 		= @nTotalTote,          
      V_Integer3 		= @nTotalPOS,          
      V_Integer4 		= @nTotalQTY,          
      V_Integer5 		= @nNextPage,          
        
      V_String1  		= @cCartID,        
      V_String2  		= @cPickZone,        
      V_String3  		= @cMethod,        
      V_String4  		= @cDPLKey,        
      V_String5  		= @cToteID,        
      V_String6  		= @cPosition,        
      V_String7  		= @cBatch,        
        
      V_String13 		= @cOption,        
      V_String14 		= @cPickSeq,        
      V_String15 		= @cRow,        
      V_String16 		= @cCol,        
              
      V_String20 		= @cExtendedValidateSP,        
      V_String21 		= @cExtendedUpdateSP,        
      V_String22 		= @cExtendedInfoSP,        
      V_String23 		= @cPTLPKZoneReq,        
      V_String24 		= @cAllowSkipTask,        
      V_String25	 	= @cDecodeLabelNo,        
      V_String26 		= @cLight,        
      V_String27 		= @cExtendedInfo,        
      V_String28 		= @cPassOnCart,        
      V_String29 		= @cDecodeSP,        
      V_String30 		= @cStatus,        
        
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