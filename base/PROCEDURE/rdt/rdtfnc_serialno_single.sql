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
/* 2017-05-23 1.0  ChewKP     Created. WMS-2881                               */  
/* 2018-10-16 1.1  Gan        Performance tuning                              */
/******************************************************************************/      
      
CREATE PROC [RDT].[rdtfnc_SerialNo_Single] (      
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
         
   @nError            INT,      
   @b_success         INT,      
   @n_err             INT,           
   @c_errmsg          NVARCHAR( 250),       
   @cPUOM             NVARCHAR( 10),          
   @cSQL              NVARCHAR(1000), 
   @cSQLParam         NVARCHAR(1000), 
   @cExtendedUpdateSP NVARCHAR(30), 
   @cExtendedValidateSP NVARCHAR(30), 
   @cExtendedInfoSP     NVARCHAR(30), 
   @cMasterSerialNo   NVARCHAR(20),
   @cChildSerialNo    NVARCHAR(20),
   @cSKU              NVARCHAR(20),
   @cWorkOrderNo      NVARCHAR(20), 
   @cSKUDescr         NVARCHAR(60),
   @nCompleteFlag     INT,
   @cOutPutText       NVARCHAR(20), 
   @cWorkOrderNoInput NVARCHAR(10),
   @cSKULabel         NVARCHAR(60),
   @cDecodeLabelNo    NVARCHAR(20), 
   @cOption           NVARCHAR(1),


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
    
   @cSKU       = V_SKU,  
   @cSKUDescr   = V_SKUDescr,  
      
   @cPUOM     = V_UOM,     
            
   @cWorkOrderNo        = V_String1,    
   @cExtendedUpdateSP   = V_String2,
   @cExtendedValidateSP = V_String3,
   @cMasterSerialNo     = V_String4,
   @cExtendedInfoSP     = V_String5,
   @cDecodeLabelNo      = V_String6,

               
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
      
      
IF @nFunc = 1016  -- Serial No Single
BEGIN      
         
   -- Redirect to respective screen      
   IF @nStep = 0 GOTO Step_0   -- Serial No SKU Change  
   IF @nStep = 1 GOTO Step_1   -- Scn = 5010. WorkOrderNo
   IF @nStep = 2 GOTO Step_2   -- Scn = 5011. SKU, Master SerialNo
   IF @nStep = 3 GOTO Step_3   -- Scn = 5012. Child SerialNo
   IF @nStep = 4 GOTO Step_4   -- Scn = 5013. Child SerialNo
   
         
END      
      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step 0. func = 1016. Menu      
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
      
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
 
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
      
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)  
   IF @cDecodeLabelNo = '0'  
      SET @cDecodeLabelNo = ''     
      
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
           
   
   SET @cWorkOrderNo = ''
  
   -- Init screen      
   SET @cOutField01 = ''       
   SET @cOutField02 = ''      
      
   -- Set the entry point      
   SET @nScn = 5010      
   SET @nStep = 1      
         
   EXEC rdt.rdtSetFocusField @nMobile, 1      
         
END      
GOTO Quit      
      
      
/********************************************************************************      
Step 1. Scn = 5010.      
   WorkOrderNo     (field01 , input)      
     
    
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
      SET @cWorkOrderNo = ''
      
      SET @cWorkOrderNoInput = ISNULL(RTRIM(@cInField01),'')      
      
      
      
          
      IF @cWorkOrderNoInput = ''
      BEGIN
         SET @nErrNo = 114401      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WorkOrdeRNoReq    
         GOTO Step_1_Fail  
      END
      
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)  
                      WHERE StorerKey = @cStorerKey  
                      AND Facility = @cFacility  
                      AND WorkOrderKey = @cWorkOrderNoInput )   
      BEGIN  
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)  
                         WHERE StorerKey = @cStorerKey  
                         AND Facility = @cFacility  
                         AND ExternWorkOrderKey = @cWorkOrderNoInput )   
         BEGIN
            SET @nErrNo = 114402      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvdWorkOrder
            GOTO Step_1_Fail      
         END
         ELSE 
         BEGIN
            SELECT @cWorkOrderNo = WorkOrderKey
            FROM dbo.WorkOrder WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND ExternWorkOrderKey = @cWorkOrderNoInput
         END
      END    
      ELSE
      BEGIN
         SET @cWorkOrderNo = @cWorkOrderNoInput
      END
      
      SELECT @cSKU = WKOrdUdef3
      FROM dbo.WorkOrder WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND WorkOrderKey = @cWorkOrderNo
      AND Facility = @cFacility
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND SKU = @cSKU ) 
      BEGIN
         SET @nErrNo = 114403     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSKU
         GOTO Step_1_Fail   
      END
     
      -- Extended Validate
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cWorkOrderNo    NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cMasterSerialNo NVARCHAR( 20), ' +
               '@cChildSerialNo  NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_1_Fail
            END
         END
      END
      
      SELECT @cSKUDescr = Descr
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE Storerkey = @cStorerKey
      AND SKU = @cSKU  
      
      SET @cOutField01 = @cSKU 
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = ''       
      
      -- GOTO Previous Screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1      
            
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0     
   BEGIN      
              
      DELETE FROM rdt.rdtSerialNoLog WITH (ROWLOCK) 
      WHERE AddWho = @cUserName
      AND Status <> '9' 
      
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 114407     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelrdtSerailFail
         GOTO Step_1_Fail   
      END        
      
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
         
      SET @cOutField01 = ''
      SET @cOutField02 = ''
     
   END      
END       
GOTO QUIT      
      
      
/********************************************************************************      
Step 2. Scn = 5010.       
       
   SKU               (field01)      
   SKU Descr         (field02)
   SKU Descr         (field03)
   Master SerialNo   (field04, input)      
         
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cMasterSerialNo  = ISNULL(RTRIM(@cInField04),'')      
      
      IF @cMasterSerialNo = ''
      BEGIN
         SET @nErrNo = 114404     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MasterSerialReq
         GOTO Step_2_Fail   
      END
      
      -- Extended Validate
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cWorkOrderNo    NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cMasterSerialNo NVARCHAR( 20), ' +
               '@cChildSerialNo  NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_2_Fail
            END
         END
      END
      
     

      SET @cOutField01 = @cSKU 
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = ''  
      SET @cOutField05 = ''


      
      -- GOTO Previous Screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1          
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = ''   
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 1      
       SET @nStep = @nStep - 1      
             
       EXEC rdt.rdtSetFocusField @nMobile, 1  
   END      
   GOTO Quit      
         
   Step_2_Fail:      
   BEGIN      
            
      SET @cOutField04 = ''   
            
   END      
      
END       
GOTO QUIT      
      
/********************************************************************************      
Step 3. Scn = 5012.       
       
   SKU               (field01)      
   SKU Descr         (field02)
   SKU Descr         (field03)
   Master SerialNo   (field04, input)      
   SCAN COUNT        (field05, field06) 
   
         
********************************************************************************/      
Step_3:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
          
      SET @cSKULabel   = ISNULL(RTRIM(@cInField04),'')   
      
      --SET @cChildSerialNo = '12345678919' 
      
      IF @cSKULabel = ''
      BEGIN
         SET @nErrNo = 114405   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ChildSerialReq
         GOTO Step_3_Fail  
      END
      
      IF ISNULL(RTRIM(@cDecodeLabelNo),'')  <> ''    
      BEGIN    
      
         SET @cErrMsg = ''    
         SET @nErrNo = 0    
             
         EXEC dbo.ispLabelNo_Decoding_Wrapper    
             @c_SPName     = @cDecodeLabelNo    
            ,@c_LabelNo    = @cSKULabel    
            ,@c_Storerkey  = @cStorerKey    
            ,@c_ReceiptKey = ''    
            ,@c_POKey      = ''    
            ,@c_LangCode   = @cLangCode    
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU    
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE    
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR    
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE    
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY    
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- LOT    
            ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Label Type    
            ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- UCC    
            ,@c_oFieled09  = @c_oFieled09 OUTPUT    
            ,@c_oFieled10  = @c_oFieled10 OUTPUT    
            ,@b_Success    = @b_Success   OUTPUT    
            ,@n_ErrNo      = @nErrNo      OUTPUT    
            ,@c_ErrMsg     = @cErrMsg     OUTPUT    
      
         IF @nErrNo <> 0    
         BEGIN
            SET @nErrNo = 114410   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ChildSerialReq
            GOTO Step_3_Fail    
         END
         
         --SET @cSKU    = ISNULL( @c_oFieled01, '')    
         --SET @nUCCQTY = CAST( ISNULL( @c_oFieled05, '') AS INT)    
         --SET @cUCC    = ISNULL( @c_oFieled08, '')    
         SET @cChildSerialNo  = ISNULL(@c_oFieled02,'' ) 
      
      END    
      ELSE     
      BEGIN    
         SET @cChildSerialNo = @cSKULabel   
      END   

      
      
   
      -- Extended Validate
      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cWorkOrderNo    NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cMasterSerialNo NVARCHAR( 20), ' +
               '@cChildSerialNo  NVARCHAR( 20), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_3_Fail
            END
         END
      END     
               
      --INSERT INTO rdt.rdtSerialNoLog ( StorerKey, Status, FromSerialNo, ToSerialNo, ParentSerialNo, FromSKU, ToSKU, SourceKey, SourceType, BatchKey, Remarks, Func, AddWho  ) 
      --VALUES ( @cStorerKey, '1' , @cChildSerialNo, @cChildSerialNo, @cMasterSerialNo, @cSKU, @cSKU,  @cWorkOrderNo, '', '', '' , @nFunc, @cUserName ) 
      
      --IF @@ERROR <> 0 
      --BEGIN
      --      SET @nErrNo = 114406
      --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsrdtSerailFail
      --      GOTO Step_3_Fail
      --END   

      
      -- Extended Update
      IF @cExtendedUpdateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @nCompleteFlag = 0 

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @cOption, @nCompleteFlag OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cWorkOrderNo    NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cMasterSerialNo NVARCHAR( 20), ' +
               '@cChildSerialNo  NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 10), ' +
               '@nCompleteFlag   INT OUTPUT, ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @cOption, @nCompleteFlag OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_3_Fail
            END
         END
      END
      
      
         
      IF @nCompleteFlag = 1 
      BEGIN
         SET @cOutField01 =  @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 =  '' 
         
         SET @nScn = @nScn - 1      
         SET @nStep = @nStep - 1 
      END
      ELSE
      BEGIN
     
         SET @cOutField04 =  ''
         
         -- Extended Update
         IF @cExtendedInfoSP <> '' 
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @cOutPutText OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     + 
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cWorkOrderNo    NVARCHAR( 10), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@cMasterSerialNo NVARCHAR( 20), ' +
                  '@cChildSerialNo  NVARCHAR( 20), ' +
                  '@cOutPutText     NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo          INT OUTPUT,    ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                   @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @cOutPutText OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                  GOTO Step_3_Fail
               END
               
               SET @cOutField05 = @cOutPutText
                
            END
         END 
         ELSE
         BEGIN
            SET @cOutField05 =  ''
         END
      END 
      
            
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = @cSKU   
       SET @cOutField02 = ''   
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn + 1      
       SET @nStep = @nStep + 1      
             
       EXEC rdt.rdtSetFocusField @nMobile, 1  
   END      
   GOTO Quit      
         
   Step_3_Fail:      
   BEGIN      
      
            
      -- Prepare Next Screen Variable      
      --SET @cOutField01 = @cSKU   
      --SET @cOutField02 = ''   
      SET @cOutField04 = ''
            
   END      
      
END       
GOTO QUIT   

/********************************************************************************      
Step 4. Scn = 5013.       
       
   SKU               (field01)      
   Option            (field04, input)      
      
         
********************************************************************************/      
Step_4:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
          
      SET @cOption   = ISNULL(RTRIM(@cInField02),'')   
      
      --SET @cChildSerialNo = '12345678919' 
      
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 114408   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionReq
         GOTO Step_4_Fail  
      END
     
   
      IF @cOption NOT IN ( '1', '9' ) 
      BEGIN
         SET @nErrNo = 114409
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
         GOTO Step_4_Fail 
      END

      
      -- Extended Update
      IF @cExtendedUpdateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @nCompleteFlag = 0 

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @cOption, @nCompleteFlag OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cWorkOrderNo    NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cMasterSerialNo NVARCHAR( 20), ' +
               '@cChildSerialNo  NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 10), ' +
               '@nCompleteFlag   INT OUTPUT, ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @cOption, @nCompleteFlag OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_4_Fail
            END
         END
      END
      
      
         
      --IF @nCompleteFlag = 1 
      --BEGIN
      SET @cOutField01 =  @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 =  '' 
      
      SET @nScn = @nScn - 2      
      SET @nStep = @nStep - 2 
      --END

      
            
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = @cSKU 
       SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
       SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
       SET @cOutField04 = ''  

       IF @cExtendedInfoSP <> '' 
       BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @cOutPutText OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     + 
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cWorkOrderNo    NVARCHAR( 10), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@cMasterSerialNo NVARCHAR( 20), ' +
                  '@cChildSerialNo  NVARCHAR( 20), ' +
                  '@cOutPutText     NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo          INT OUTPUT,    ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                   @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cWorkOrderNo, @cSKU, @cMasterSerialNo, @cChildSerialNo, @cOutPutText OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
                  GOTO Step_4_Fail
               END
               
               SET @cOutField05 = @cOutPutText
                
            END
         END 
       ELSE
       BEGIN
          SET @cOutField05 =  ''
       END
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 1    
       SET @nStep = @nStep - 1      
             
       EXEC rdt.rdtSetFocusField @nMobile, 1  
   END      
   GOTO Quit      
         
   Step_4_Fail:      
   BEGIN      
      
            
      -- Prepare Next Screen Variable      
      --SET @cOutField01 = @cSKU   
      --SET @cOutField02 = ''   
      SET @cOutField02 = ''
            
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
      
            
      V_SKUDescr = @cSKUDescr,  
     
      V_SKU = @cSKU,   
      
      V_String1 = @cWorkOrderNo        ,    
      V_String2 = @cExtendedUpdateSP   ,
      V_String3 = @cExtendedValidateSP ,
      V_String4 = @cMasterSerialNo     ,
      V_String5 = @cExtendedInfoSP     ,
      V_String6 = @cDecodeLabelNo      , 

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