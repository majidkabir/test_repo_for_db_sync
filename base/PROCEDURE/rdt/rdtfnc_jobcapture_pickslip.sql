SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdtfnc_JobCapture_PickSlip                          */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Purpose: Serial no capture by ext orderkey + sku                     */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 16-10-2019  1.0  Chermaine  WMS-10469 Created                        */  
/* 12-07-2021  1.1  Chermaine  WMS-17454 Change to generic              */
/*                             check pickslipNo (cc01)                  */
/************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_JobCapture_PickSlip] (  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT  
)  
AS  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc var  
DECLARE  
   @nRowRef     INT,  
   @cSQL        NVARCHAR( MAX),   
   @cSQLParam   NVARCHAR( MAX)  
  
-- RDT.RDTMobRec variable  
DECLARE  
   @nFunc       INT,  
   @nScn        INT,  
   @nStep       INT,  
   @cLangCode   NVARCHAR( 3),  
   @cUserName   NVARCHAR( 10),  
   @nInputKey   INT,  
   @nMenu       INT,  

   @cStorerKey  NVARCHAR( 15),  
   @cFacility   NVARCHAR( 5), 
                  
   @cUserID     NVARCHAR( 15),  
   @cPickSlipNo NVARCHAR( 20),          
   @cQTY        NVARCHAR( 5),  
   @cOption     NVARCHAR(1),
   @cOrderKey   NVARCHAR( 10),    
   @cLoadKey    NVARCHAR( 10),    
   @cZone       NVARCHAR( 18),
  
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),  
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),  
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),  
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),  
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),  
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),  
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),  
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),  
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),  
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),  
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),  
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),  
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),  
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),  
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)  
  
-- Load RDT.RDTMobRec  
SELECT  
   @nFunc       = Func,  
   @nScn        = Scn,  
   @nStep       = Step,  
   @nInputKey   = InputKey,  
   @nMenu       = Menu,  
   @cLangCode   = Lang_code,  
   @cUserName   = UserName,  
   
   @cStorerKey  = StorerKey,  
   @cFacility   = Facility,  
                  
   @cUserID     = V_String1,  
   @cPickSlipNo = V_String2,                         
   @cQTY        = V_String3,  
   @cOption     = V_String4,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,  
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,  
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,  
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,  
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,  
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,  
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,  
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,   
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,  
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,  
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,  
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,  
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,  
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,  
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15  
     
FROM rdt.RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
IF @nFunc = 1838 -- Pick Job capture
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0 GOTO Step_0   -- Func = 1838  
   IF @nStep = 1 GOTO Step_1   -- 5620 UserID  
   IF @nStep = 2 GOTO Step_2   -- 5621 PickSlipNo Method (Full/Split)
   IF @nStep = 3 GOTO Step_3   -- 5622 Full Pick Slip  
   IF @nStep = 4 GOTO Step_4   -- 5623 Split Pick Slip  
   IF @nStep = 5 GOTO Step_5   -- 5624 Split Pick Slip Qty
END  
  
RETURN -- Do nothing if incorrect step  
  
  
/********************************************************************************  
Step 0. func = 1838. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   --SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
   --IF @cExtendedValidateSP = '0'  
   --   SET @cExtendedValidateSP = ''  
  
   --SET @cFieldAttr02 = ''
   --SET @cFieldAttr04 = ''
   --SET @cFieldAttr06 = ''
   --SET @cFieldAttr08 = ''
   --SET @cFieldAttr10 = ''

   SET @cUserID = ''

   -- Set the entry point  
   SET @nScn = 5620  
   SET @nStep = 1  
  
   -- Prepare next screen var  
   SET @cOutField01 = '' -- User ID  

   -- EventLog  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType = '1', -- Sign-in  
      @cUserID     = @cUserName,  
      @nMobileNo   = @nMobile,  
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,  
      @cStorerKey  = @cStorerkey  
   
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Screen = 5620  
   User ID  (Field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cUserID = @cInField01  
  
      -- Check blank  
      IF @cUserID = ''  
      BEGIN  
         SET @nErrNo = 145301 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need UserID  
         GOTO Quit  
      END  

      -- Clear variable here, user might not go back to menu screen 
      -- before start using with another user id
      SET @cPickSlipNo = ''
      SET @cQTY = ''
 
      -- Get user info  
      DECLARE @cStatus NVARCHAR(10)  
      SELECT @cStatus = Short  
      FROM CodeLKUP WITH (NOLOCK)  
      WHERE ListName = 'JOBCapUser'  
         AND Code = @cUserID  
  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 145302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UserID  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      -- Check status  
      IF @cStatus = '9'  
      BEGIN  
         SET @nErrNo = 145303 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive user  
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Order  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
 
      -- Prep next screen var  
      SET @cOutField01 = @cUserID  
      SET @cOutField02 = ''  
  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  

   END  
   
   IF @nInputKey = 0 -- ESC  
   BEGIN   
      -- EventLog  
      EXEC RDT.rdt_STD_EventLog  
         @cActionType = '9', -- Sign-out  
         @cUserID     = @cUserName,  
         @nMobileNo   = @nMobile,  
         @nFunctionID = @nFunc,  
         @cFacility   = @cFacility,  
         @cStorerKey  = @cStorerkey  

      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- Clean up for menu option  
   END  
   GOTO Quit  
END
GOTO Quit  
  
  
/********************************************************************************  
Step 2. Screen = 5621  Pick Method
   USER ID  (Field01)  
   OPTION (Field02, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN
      
      -- Screen mapping  
      SET @cOption = @cInField02  
  
      -- Check blank  
      IF @cOption = ''  
      BEGIN  
         SET @nErrNo = 145304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option   
         GOTO Quit  
      END  
      
      -- Check option valid  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 145305  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         GOTO Quit  
      END  
  
      IF @cOption = '1' -- YES  
      BEGIN  
         -- Prepare next screen var
         SET @cOutField01 = @cUserID  
         
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
  
         GOTO Quit  
      END 
      
      IF @cOption = '2'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cUserID  
         
         SET @nScn = @nScn + 2  
         SET @nStep = @nStep + 2

         GOTO Quit  
      END       
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      
      --back to step 1      
      SET @cOutField01 = ''  
           
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit     
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 3. Screen = 5622. Full Pick Slip  
   USER ID        (Field01)   
   PICK SLIP NO   (Field02, input)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cPickSlipNo = @cInField02  
  
      -- Check blank  
      IF @cPickSlipNo = ''  
      BEGIN  
         SET @nErrNo = 145306  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickSlip 
         SET @cOutField03 = ''  
         GOTO Quit  
      END  
      
      SET @cOrderKey = ''
      SET @cLoadKey = ''
      SET @cZone = ''
      
      --(cc01)
       -- Get PickHeader info    
      SELECT TOP 1    
         @cOrderKey = OrderKey,    
         @cLoadKey = ExternOrderKey,    
         @cZone = Zone    
      FROM dbo.PickHeader WITH (NOLOCK)    
      WHERE PickHeaderKey = @cPickSlipNo 
      
      -- Cross dock PickSlip    
      IF @cZone IN ('XD', 'LB', 'LP')    
      BEGIN
      	SELECT 1
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)    
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)    
         WHERE RKL.PickSlipNo = @cPickSlipNo     
            AND PD.QTY > 0    
            AND PD.Status <> '4'
      END          
      ELSE IF @cOrderKey <> ''      -- Discrete PickSlip 
      BEGIN
      	SELECT 1   
         FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE PD.OrderKey = @cOrderKey      
            AND PD.QTY > 0     
            AND PD.Status <> '4'  
      END 
      ELSE IF @cLoadKey <> ''    ---- Conso PickSlip  
      BEGIN
      	SELECT 1   
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)    
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE LPD.LoadKey = @cLoadKey      
            AND PD.QTY > 0     
            AND PD.Status <> '4' 
      END
      ELSE    -- Custom PickSlip  
      BEGIN
      	SELECT 1    
         FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE PD.PickSlipNo = @cPickSlipNo      
            AND PD.QTY > 0    
            AND PD.Status <> '4'  
      END
      
      IF @@ROWCOUNT = 0
      BEGIN  
         SET @nErrNo = 145307  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PickSlip  
         SET @cOutField03 = ''  
         GOTO Quit  
      END  
          
      EXEC RDT.rdt_STD_EventLog  
       @cActionType = '3',   
       @cUserID     = @cUserID,--@cUserName,  
       @nMobileNo   = @nMobile,  
       @nFunctionID = @nFunc, 
       @cFacility   = @cFacility,  
       @cStorerKey  = @cStorerkey,  
       @cPickSlipNo = @cPickSlipNo,
       @cOption     = @cOption,
       @cOptionDefinition  = 'FULL'
       

      -- Prepare next screen var  
      SET @cOutField01 = @cUserID   
      SET @cOutField02 = ''  
   
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      
      -- Prepare next screen var  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''
      --back to step 1  
      SET @nScn  = @nScn - 2  
      SET @nStep = @nStep - 2  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 4. Screen = 5623. SPLIT PICK SLIP  
   USER ID        (Field01)  
   PICK SLIP No   (Field02, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cPickSlipNo = @cInField02  
  
      -- Check blank  
      IF @cPickSlipNo = ''  
      BEGIN  
         SET @nErrNo = 145306  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickSlip 
         SET @cOutField03 = ''  
         GOTO Quit  
      END  
      
      SET @cOrderKey = ''
      SET @cLoadKey = ''
      SET @cZone = ''
  
      --(cc01)
       -- Get PickHeader info    
      SELECT TOP 1    
         @cOrderKey = OrderKey,    
         @cLoadKey = ExternOrderKey,    
         @cZone = Zone    
      FROM dbo.PickHeader WITH (NOLOCK)    
      WHERE PickHeaderKey = @cPickSlipNo 
      
      -- Cross dock PickSlip    
      IF @cZone IN ('XD', 'LB', 'LP')    
      BEGIN
      	SELECT 1
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)    
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)    
         WHERE RKL.PickSlipNo = @cPickSlipNo     
            AND PD.QTY > 0    
            AND PD.Status <> '4'
      END          
      ELSE IF @cOrderKey <> ''      -- Discrete PickSlip 
      BEGIN
      	SELECT 1   
         FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE PD.OrderKey = @cOrderKey      
            AND PD.QTY > 0     
            AND PD.Status <> '4'  
      END 
      ELSE IF @cLoadKey <> ''    ---- Conso PickSlip  
      BEGIN
      	SELECT 1   
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)    
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE LPD.LoadKey = @cLoadKey      
            AND PD.QTY > 0     
            AND PD.Status <> '4' 
      END
      ELSE    -- Custom PickSlip  
      BEGIN
      	SELECT 1    
         FROM dbo.PickDetail PD WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)    
         WHERE PD.PickSlipNo = @cPickSlipNo      
            AND PD.QTY > 0    
            AND PD.Status <> '4'  
      END
      
      IF @@ROWCOUNT = 0 
      BEGIN  
         SET @nErrNo = 145307  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PickSlip  
         SET @cOutField03 = ''  
         GOTO Quit  
      END  

      -- Prepare next screen var  
      SET @cOutField01 = @cPickSlipNo   
      --SET @cOutField02 = @cPickSlipNo
      
      
      SET @nScn  = @nScn + 1  
      SET @nStep = @nStep + 1 
   
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      
      -- Prepare next screen var  
      SET @cOutField01 = ''
      --SET @cOutField01 = ''
  
      -- back to step 1
      SET @nScn  = @nScn - 3 
      SET @nStep = @nStep - 3 
   END  
END  
GOTO Quit 
  
  
/********************************************************************************  
Step 5. Screen = 5624 - SPLIT PICK QTY  
   PICK SLIP No   (Field01)  
   QTY            (Field02, input)  
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cQTY = @cInField02  
  
      -- Check blank  
      IF @cQTY = ''  
      BEGIN  
         SET @nErrNo = 145308  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need QTY  
         GOTO Quit  
      END  
  
      -- Check QTY valid  
      IF rdt.rdtIsValidQty( @cQTY, 1) = 0  
      BEGIN  
         SET @nErrNo = 145309  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY  
         GOTO Quit  
      END  
  
      EXEC RDT.rdt_STD_EventLog  
       @cActionType = '3',   
       @cUserID     = @cUserID,--@cUserName,  
       @nMobileNo   = @nMobile,  
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,  
       @cStorerKey  = @cStorerkey,
       @cPickSlipNo = @cPickSlipNo,
       @nQTY        = @cQTY,
       @cOption     = @cOption,
       @cOptionDefinition  = 'SPLIT'
 
      -- Prepare next screen var  
      SET @cOutField01 = @cUserID -- UserID  
      SET @cOutField02 = '' 
      SET @cOutField03 = ''  
  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare next screen var  
      SET @cOutField01 = @cUserID -- User ID  
      SET @cOutField02 = ''  
      SET @cOutField03 = '' -- End   
        
      -- Go back SKU screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
END  
GOTO Quit 
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET  
      EditDate = GETDATE(),  
      ErrMsg = @cErrMsg,  
      Func   = @nFunc,  
      Step   = @nStep,  
      Scn    = @nScn,  
      
      StorerKey = @cStorerKey,  
      Facility  = @cFacility,  
  
      V_String1 = @cUserID,  
      V_String2 = @cPickSlipNo,                            
      V_String3 = @cQTY, 
      V_String4 = @cOption, 
  
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,  
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,  
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,  
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,  
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,  
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,  
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,  
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,  
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,   
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,   
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,   
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,   
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,   
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,   
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15  
        
   WHERE Mobile = @nMobile  
END  

GO