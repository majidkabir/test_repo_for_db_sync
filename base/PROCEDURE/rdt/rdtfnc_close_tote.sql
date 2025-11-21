SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
     
/******************************************************************************/       
/* Copyright: LF                                                              */       
/* Purpose:                                                                   */       
/*                                                                            */       
/* Modifications log:                                                         */       
/*                                                                            */       
/* Date       Rev  Author     Purposes                                        */       
/* 2017-07-11 1.0  ChewKP     Created. WMS-2121                               */
/* 2018-10-25 1.1  TungGH     Performance                                     */      
/******************************************************************************/      
      
CREATE PROC [RDT].[rdtfnc_Close_Tote] (      
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
   
   @cCloseToteNo        NVARCHAR(20),
   @cNewToteNo          NVARCHAR(20),
   @cExtendedValidateSP NVARCHAR(30),   
   @cExtendedUpdateSP   NVARCHAR(30),   
   @cPUOM               NVARCHAR( 1), -- Prefer UOM
   @cSQL                NVARCHAR(1000), 
   @cSQLParam           NVARCHAR(1000), 
   @nCursorPosition     INT,
   @cOption             NVARCHAR(1),

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),    
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),    
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),    
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),    
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),    
            
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
   --@cLightMode  = LightMode,  
   --@cSKU       = V_SKU,  
   --@cSKUDescr   = V_SKUDescr,  
   
   --@cLot        = V_Lot,  
   @cPUOM     = V_UOM,     
   
         
   @cCloseToteNo              = V_String1,    
   @cNewToteNo                = V_String2,    
   @cExtendedValidateSP       = V_String3,    
   @cExtendedUpdateSP         = V_String4,    

   
         
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
      
      
IF @nFunc = 1036  -- Serial No SKU Change
BEGIN      
         
   -- Redirect to respective screen      
   IF @nStep = 0 GOTO Step_0   -- Close Tote 
   IF @nStep = 1 GOTO Step_1   -- Scn = 4970. Close Tote , To Tote
   IF @nStep = 2 GOTO Step_2   -- Scn = 4971. Confirm Close Tote
         
END      
      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step 0. func = 1036. Menu      
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
   SET @cOutField02 = ''      
     

      
   -- Set the entry point      
   SET @nScn = 4970      
   SET @nStep = 1      
         
   EXEC rdt.rdtSetFocusField @nMobile, 1      
         
END      
GOTO Quit      
      
      
/********************************************************************************      
Step 1. Scn = 4970.      
   Close Tote No     (field01 , input)      
   To Tote No        (field02 , input)      
     
    
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
            
      SET @cCloseToteNo = ISNULL(RTRIM(@cInField01),'')      
      SET @cNewToteNo = ISNULL(RTRIM(@cInField02),'')      
          
      --When Lane is blank
      IF @cCloseToteNo = ''
      BEGIN
         SET @nErrNo = 112101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CloseToteReq
         SET @cCloseToteNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      
      
       
      IF @cExtendedValidateSP <> ''
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN

            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cCloseToteNo OUTPUT, @cNewToteNo OUTPUT, @nCursorPosition OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cCloseToteNo    NVARCHAR( 20) OUTPUT, ' +
               '@cNewToteNo      NVARCHAR( 20) OUTPUT, ' +
               '@nCursorPosition INT           OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cCloseToteNo OUTPUT, @cNewToteNo OUTPUT, @nCursorPosition OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               EXEC rdt.rdtSetFocusField @nMobile, @nCursorPosition
               GOTO Step_1_Fail
            END

         END
      END
      
      
      -- GOTO Next Screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1     
          
      -- Prepare Next Screen Variable      
      --SET @cOutField01 = @cPTSZone    
      SET @cOutField01 = @cCloseToteNo
      SET @cOutField02 = @cNewToteNo
      SET @cOutField03 = ''
        
    
        
            
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0     
   BEGIN      
              
--    -- EventLog - Sign In Function      
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
      -- Prepare Next Screen Variable      
      SET @cOutField01 = @cCloseToteNo  
      SET @cOutField02 = @cNewToteNo
     
   END      
END       
GOTO QUIT      
      
      
/********************************************************************************      
Step 2. Scn = 4721.       
       
   Close Tote        (field01)      
   New Tote          (field02)    
   Option            (field03, input)    
         
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cOption     = ISNULL(RTRIM(@cInField03),'')      
      
      IF ISNULL(@cOption,'' )  = '' 
      BEGIN
         SET @nErrNo = 112102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionReq
         GOTO Step_2_Fail
      END
      
      IF @cOption NOT IN ( '1', '9' ) 
      BEGIN
         SET @nErrNo = 112103
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         GOTO Step_2_Fail
      END
      
      IF @cExtendedUpdateSP <> ''
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN

            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cCloseToteNo, @cNewToteNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cCloseToteNo    NVARCHAR( 20) , '+
               '@cNewToteNo      NVARCHAR( 20) , '+
               '@cOption         NVARCHAR( 1) , ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cCloseToteNo, @cNewToteNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_2_Fail
            END

         END
      END
      
      
      
           
      -- Prepare Next Screen Variable      
      --SET @cOutField01 = @cPTSZone    
      SET @cOutField01 = ''  
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      
      -- GOTO Next Screen      
      SET @nScn = @nScn - 1      
      SET @nStep = @nStep - 1     
     
      EXEC rdt.rdtSetFocusField @nMobile, 1        
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = ''   
       SET @cOutField02 = ''   
       SET @cOutField03 = ''     
       
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 1      
       SET @nStep = @nStep - 1      
             
       EXEC rdt.rdtSetFocusField @nMobile, 1      
   END      
   GOTO Quit      
         
   Step_2_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
      
      SET @cOutField03 = ''
            
   END      
      
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
      EditDate  = GetDate() ,  
      InputKey  = @nInputKey,   
    
      V_String1 = @cCloseToteNo, 
      V_String2 = @cNewToteNo,
      V_String3 = @cExtendedValidateSP,
      V_String4 = @cExtendedUpdateSP,
      
      

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