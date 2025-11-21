SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/     
/* Copyright: LF                                                              */     
/* Purpose: IDSCN                                                             */     
/*                                                                            */     
/* Modifications log:                                                         */     
/*                                                                            */     
/* Date       Rev  Author     Purposes                                        */     
/* 2016-04-25 1.0  ChewKP     SOS#356239 Created                              */  
/* 2018-11-15 1.1  Gan        Peformance tuning                               */  
/* 2019-10-01 1.2  YeeKung    WMS-10018 RDT handover 1185 enhancement         */      
/*                            (yeekung01)                                     */    
/* 2020-06-12 1.3  ChaoBing   WMS-13614  Add extendedupdatesp                 */      
/******************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_TMS_ScanOrder] (    
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
   @cSQL       NVARCHAR( MAX),      
   @cSQLParam  NVARCHAR( MAX),       
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
   @cKeyType      NVARCHAR(1),  
   @cCarrierCode  NVARCHAR(10),  
   @nCartonCount  INT,   
   @nOrderCount   INT,  
   @cCartonNo     NVARCHAR(20),  
   @cOption       NVARCHAR(1),  
   @cOrderNo      NVARCHAR(20),  
   @nInOrder      INT,  
   @nInLoadPlan   INT,  
   @nInMBOL       INT,  
   @cTableName    NVARCHAR(10),  
   @cUDF01        NVARCHAR(10),      
   @cUDF02        NVARCHAR(10),      
   @cUDF03        NVARCHAR(10),      
   @cUDF04        NVARCHAR(10),      
   @cUDF05        NVARCHAR(10),      
   @cExtendedUpdateSP  NVARCHAR( 20),     
  
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
     
   @nOrderCount  = V_Integer1,  
   @nCartonCount = V_Integer2,  
     
   --@cOrderKey   = V_OrderKey,  -  
   @cCarrierCode = V_String1,    
  -- @nOrderCount  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END,  
  -- @nCartonCount = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,  
   @cKeyType     = V_String4,   
   @cCartonNo    = V_String5,  
   @cOrderNo     = V_String6,  
   @cTableName   = V_String7,  
  @cUDF01       = V_String8,      
   @cUDF02       = V_String9,      
   @cUDF03       = V_String10,      
   @cUDF04       = V_String11,      
   @cUDF05       = V_String12,    
   @cExtendedUpdateSP  = V_String13,   
  
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
    
    
    
IF @nFunc = 1185  -- Order To Pallet    
BEGIN    
   -- Redirect to respective screen    
   IF @nStep = 0 GOTO Step_0   -- TMS Scan Order  
   IF @nStep = 1 GOTO Step_1   -- Scn = 4570. Carrier Code  
   IF @nStep = 2 GOTO Step_2   -- Scn = 4571. OrderNo, Option  
   IF @nStep = 3 GOTO Step_3   -- Scn = 4572. CartonNo   
   IF @nStep = 4 GOTO Step_4   -- Scn = 4573. Reject / Accept Carton   
    
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
    
   -- Initiate var    
 -- EventLog - Sign In Function    
   EXEC RDT.rdt_STD_EventLog    
     @cActionType = '1', -- Sign in function    
     @cUserID     = @cUserName,    
     @nMobileNo   = @nMobile,    
     @nFunctionID = @nFunc,    
     @cFacility   = @cFacility,    
     @cStorerKey  = @cStorerkey,  
     @nStep      = @nStep  
  
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)      
   IF @cExtendedUpdateSP = '0'      
      SET @cExtendedUpdateSP = ''      
       
   -- Init screen    
   SET @cOutField01 = ''     
     
   SET @cKeyType = ''    
   SET @cOrderKey = ''    
   SET @nOrderCount = 0   
   SET @nCartonCount = 0  
     
   -- Set the entry point    
   SET @nScn = 4570    
   SET @nStep = 1    
     
   EXEC rdt.rdtSetFocusField @nMobile, 1    
     
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Scn = 4570.     
   Carrier Code (Input , Field01)    
   
       
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
      SET @cCarrierCode = ISNULL(RTRIM(@cInField01),'')    
      
      SET @cOutField01 = ''     
      SET @cOutField02 = ''     
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
      SET @cOutField01 = ''    
    
          
      EXEC rdt.rdtSetFocusField @nMobile, 1    
   END    
       
    
END     
GOTO QUIT    
    
    
/********************************************************************************    
Step 2. Scn = 4570.     
   OrderNo (Input, Field01)  
   OrderCount (Field02)   
   Option (Input, Field02)  
       
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
      SET @cOrderNo  = ISNULL(RTRIM(@cInField01),'')    
      SET @cOption   = ISNULL(RTRIM(@cInField03),'')    
        
      -- Validate blank    
      IF ISNULL(RTRIM(@cOrderNo), '') = ''    
      BEGIN    
         SET @nErrNo = 99401    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNoReq    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail    
      END    
        
      IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)  
                     WHERE OrderKey = @cOrderNo )   
      BEGIN  
         SET @nInOrder = 1  
         SET @cKeyType = 'O'  
         --SET @cTableName = 'SOCARGOOTM'   
           
         SELECT Top 1 @cStorerKey = O.StorerKey   
         FROM dbo.Orders O WITH (NOLOCK)   
         WHERE O.OrderKey = @cOrderNo   
           
         SELECT   @cUDF01=UDF01,      
            @cUDF02=UDF02,      
            @cUDF03=UDF03,      
            @cUDF04=UDF04,      
            @cUDF05=UDF05      
         FROM dbo.codelkup WITH (NOLOCK)      
         WHERE Listname='RDT2OTM'      
            AND code='1185-SO'      
            AND storerkey=@cStorerKey    
           
      END  
      ELSE   
      BEGIN  
         SET @nInOrder = 0   
      END  
        
      IF EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK)  
                     WHERE LoadKey = @cOrderNo )   
      BEGIN  
         SET @nInLoadPlan = 1  
         SET @cKeyType = 'L'  
         --SET @cTableName = 'LPCARGOOTM'  
           
         SELECT Top 1 @cStorerKey = O.StorerKey   
         FROM dbo.LoadPlanDetail LP WITH (NOLOCK)   
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = LP.OrderKey   
         WHERE LP.LoadKey = @cOrderNo  
           
         SELECT   @cUDF01=UDF01,      
                  @cUDF02=UDF02,      
                  @cUDF03=UDF03,      
                  @cUDF04=UDF04,      
                  @cUDF05=UDF05      
         FROM dbo.codelkup WITH (NOLOCK)      
         WHERE Listname='RDT2OTM'      
            AND code='1185-LP'      
            AND storerkey=@cStorerKey   
           
      END  
      ELSE   
      BEGIN  
         SET @nInLoadPlan = 0   
      END  
        
      IF EXISTS (SELECT 1 FROM dbo.MBOL WITH (NOLOCK)  
                     WHERE MBOLKey = @cOrderNo )   
      BEGIN  
         SET @nInMBOL = 1  
         SET @cKeyType = 'M'  
         --SET @cTableName = 'MBCARGOOTM'  
           
         SELECT Top 1 @cStorerKey = O.StorerKey   
         FROM dbo.MBOLDetail MD WITH (NOLOCK)   
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey   
         WHERE MD.MBOLKey = @cOrderNo   
           
       SELECT   @cUDF01=UDF01,      
                  @cUDF02=UDF02,      
                  @cUDF03=UDF03,      
                  @cUDF04=UDF04,      
                  @cUDF05=UDF05      
         FROM dbo.codelkup WITH (NOLOCK)      
         WHERE Listname='RDT2OTM'      
            AND code='1185-MB'      
            AND storerkey=@cStorerKey  
      END  
      ELSE   
      BEGIN  
         SET @nInMBOL = 0   
      END  
        
      IF @nInOrder = 0 AND @nInLoadPlan = 0 AND @nInMBOL = 0   
      BEGIN  
         SET @nErrNo = 99402    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvOrderNo  
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_2_Fail    
      END  
  
      IF @cOption = ''  
      BEGIN  
    
         IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTRACK WITH (NOLOCK)   
                         WHERE TrackingNo = @cOrderNo )   
         BEGIN  
          
            IF @cExtendedUpdateSP <> ''  
            BEGIN   
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')      
               BEGIN  
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @cOrderNo, @cKeyType, @cCarrierCode, @cCartonNo ' +       
                     ' , @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, @cStorerKey, @cFacility ' +       
                     ' , @cUserName   ' +       
                     ' , @nErrNo      OUTPUT ' +       
                     ' , @cErrMsg     OUTPUT ' +    
                     ' , @nCount      OUTPUT '      
  
                  SET @cSQLParam =      
                     '@nMobile         INT,           ' +      
                     '@nFunc           INT,           ' +      
                     '@cLangCode       NVARCHAR( 3),  ' +      
                     '@nStep           INT,           ' +      
                     '@cOrderNo        NVARCHAR( 20), ' +      
                     '@cKeyType        NVARCHAR( 5),  ' +      
                     '@cCarrierCode    NVARCHAR(10),  ' +      
                     '@cCartonNo       NVARCHAR(20),  ' +      
                     '@cUDF01          NVARCHAR(10),  ' +      
                     '@cUDF02          NVARCHAR(10),  ' +      
                     '@cUDF03          NVARCHAR(10),  ' +      
                     '@cUDF04          NVARCHAR(10),  ' +      
                     '@cUDF05          NVARCHAR(10),  ' +      
                     '@cStorerKey      NVARCHAR( 15), ' +      
                     '@cFacility       NVARCHAR( 5),  ' +       
                     '@cUserName       NVARCHAR( 10), ' +  
                     '@nErrNo          INT            OUTPUT, ' +      
                     '@cErrMsg         NVARCHAR( 20)  OUTPUT, ' +   
                     '@nCount          INT            OUTPUT'    
                            
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                                 @nMobile, @nFunc, @cLangCode, @nStep, @cOrderNo, @cKeyType, @cCarrierCode, @cCartonNo  
                                 , @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, @cStorerKey, @cFacility  
                                 , @cUserName  
                                 , @nErrNo      OUTPUT  
                                 , @cErrMsg     OUTPUT  
                                 , @nCount      OUTPUT     
  
                  IF @nErrNo <> 0  
                  BEGIN   
                   --SET @nErrNo = 99404                
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed  --hcb add  
                   EXEC rdt.rdtSetFocusField @nMobile, 1    
                   GOTO Step_2_Fail    
                  END  
                SET @nOrderCount = @nOrderCount + @nCount  
                        
               END     
            END   --@cExtendedUpdateSP <> ''  
            ELSE  
            BEGIN   
               IF (ISNULL(@cUDF01,'')<>'')       
               BEGIN      
      
                  SET @cTableName=@cUDF01                     
  
                INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )   
                VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate()  )   
            
                IF @@ERROR <> 0   
                BEGIN  
                   SET @nErrNo = 99404    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed    
                   EXEC rdt.rdtSetFocusField @nMobile, 1    
                   GOTO Step_2_Fail    
                END  
              
                EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''   
                , @b_success OUTPUT   
                , @nErrNo OUTPUT   
                , @cErrMsg OUTPUT       
            
            
                SET @nOrderCount = @nOrderCount + 1  
             END  
            
             IF (ISNULL(@cUDF02,'')<>'')       
               BEGIN      
                    
                  SET @cTableName=@cUDF02     
      
                  INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )       
                  VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate())       
               
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 99410        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                     EXEC rdt.rdtSetFocusField @nMobile, 1        
                     GOTO Step_2_Fail        
                  END      
                  
                  EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
                  , @b_success OUTPUT       
                  , @nErrNo OUTPUT       
                  , @cErrMsg OUTPUT           
               
               
           SET @nOrderCount = @nOrderCount + 1      
               END      
               
               IF (ISNULL(@cUDF03,'')<>'')       
               BEGIN      
      
                  SET @cTableName  = @cUDF03    
      
                  INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )       
                  VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate())       
               
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 99411        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                     EXEC rdt.rdtSetFocusField @nMobile, 1        
                     GOTO Step_2_Fail        
                  END      
                  
                  EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
                  , @b_success OUTPUT       
                  , @nErrNo OUTPUT       
                  , @cErrMsg OUTPUT           
               
               
                  SET @nOrderCount = @nOrderCount + 1      
        END      
      
               IF (ISNULL(@cUDF04,'')<>'')       
               BEGIN      
      
                  SET @cTableName = @cUDF04    
      
                  INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )       
                  VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate())       
               
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 99412        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                     EXEC rdt.rdtSetFocusField @nMobile, 1        
                     GOTO Step_2_Fail        
                  END      
                  
                  EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
                  , @b_success OUTPUT       
                  , @nErrNo OUTPUT       
                  , @cErrMsg OUTPUT           
               
               
                  SET @nOrderCount = @nOrderCount + 1      
               END      
      
               IF (ISNULL(@cUDF05,'')<>'')       
               BEGIN      
      
                  SET @cTableName  =@cUDF05    
      
                  INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, MUStatus, AddWho, AddDate, EditWho, EditDate )       
                  VALUES ( @cOrderNo, @cCarrierCode,  '1' ,@cUserName, GetDATE(), @cUserName , GetDate())       
               
                  IF @@ERROR <> 0       
                  BEGIN      
                     SET @nErrNo = 99413        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                     EXEC rdt.rdtSetFocusField @nMobile, 1        
                     GOTO Step_2_Fail        
                  END      
                  
                  EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
                  , @b_success OUTPUT       
                  , @nErrNo OUTPUT       
                  , @cErrMsg OUTPUT           
               
               
                  SET @nOrderCount = @nOrderCount + 1      
               END      
            END    --@cExtendedUpdateSP <> ''  
  
         END   
         ELSE  
         BEGIN  
            SET @nErrNo = 99408    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackingNoExist    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_2_Fail    
  
         END  
  
         SET @cOutField01 = ''    
         SET @cOutField02 = @nOrderCount   
         --SET @cOutField02 = '10'   
          
         GOTO QUIT   
           
      END  
      ELSE  
      BEGIN  
           
         SET @cOutField01 = @cOrderNo  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
           
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
           
         GOTO QUIT   
           
      END  
          
        
         
      
   END  -- Inputkey = 1    
    
    
   IF @nInputKey = 0     
   BEGIN    
          
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
          
      SET @nScn = @nScn - 1     
      SET @nStep = @nStep - 1     
          
          
   END    
   GOTO Quit    
    
   STEP_2_FAIL:    
   BEGIN    
      SET @cOutField01 = ''  
      SET @cOutField02 = @nOrderCount   
      SET @cOutField03 = ''    
        
    
      EXEC rdt.rdtSetFocusField @nMobile, 1    
   END    
       
    
END     
GOTO QUIT    
    
/********************************************************************************    
Step 3. Scn = 4572.     
   OrderNo    (Field01)    
   CartonNo   (Field02, Input)    
   Carton Count (Field03)   
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1     
   BEGIN    
        
      SET @cCartonNo = ISNULL(RTRIM(@cInField02),'')    
        
    
    
      IF @cCartonNo = ''    
      BEGIN    
         SET @nErrNo = 99403    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonNoReq    
         GOTO Step_3_Fail    
      END    
        
      IF @cKeyType = 'M'  
      BEGIN  
         SELECT Top 1 @cStorerKey = O.StorerKey   
         FROM dbo.MBOLDetail MD WITH (NOLOCK)   
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey   
         WHERE MD.MBOLKey = @cOrderNo   
      END  
      ELSE IF @cKeyType = 'L'  
      BEGIN  
         SELECT Top 1 @cStorerKey = O.StorerKey   
         FROM dbo.LoadPlanDetail LP WITH (NOLOCK)   
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = LP.OrderKey   
         WHERE LP.LoadKey = @cOrderNo   
      END  
      ELSE IF @cKeyType = 'O'  
      BEGIN  
         SELECT Top 1 @cStorerKey = O.StorerKey   
         FROM dbo.Orders O WITH (NOLOCK)   
         WHERE O.OrderKey = @cOrderNo   
      END  
        
      IF EXISTS ( SELECT 1 FROM PackHeader WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey )   
      BEGIN  
           
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)   
                         WHERE StorerKey = @cStorerKey   
                         AND LabelNo = @cCartonNo )   
         BEGIN  
            SET @cOutField01 = @cOrderNo   
            SET @cOutField02 = @cCartonNo     
            SET @cOutField03 = ''  
              
            SET @nScn = @nScn + 1     
            SET @nStep = @nStep + 1               
              
            GOTO QUIT   
              
         END           
           
           
      END  
  
    IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)       
              WHERE CaseID = @cCartonNo )       
      BEGIN   
           
         IF @cExtendedUpdateSP <> ''  
         BEGIN   
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')      
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cOrderNo, @cKeyType, @cCarrierCode, @cCartonNo ' +       
                  ' , @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, @cStorerKey, @cFacility ' +       
                  ' , @cUserName   ' +       
                  ' , @nErrNo      OUTPUT ' +       
                  ' , @cErrMsg     OUTPUT ' +    
                  ' , @nCount      OUTPUT '      
  
               SET @cSQLParam =      
                  '@nMobile         INT,           ' +      
                  '@nFunc           INT,           ' +      
                  '@cLangCode       NVARCHAR( 3),  ' +      
                  '@nStep           INT,           ' +      
                  '@cOrderNo        NVARCHAR( 20), ' +      
                  '@cKeyType        NVARCHAR( 5),  ' +      
                  '@cCarrierCode    NVARCHAR(10),  ' +      
                  '@cCartonNo       NVARCHAR(20),  ' +      
                  '@cUDF01          NVARCHAR(10),  ' +      
                  '@cUDF02          NVARCHAR(10),  ' +      
                  '@cUDF03          NVARCHAR(10),  ' +      
                  '@cUDF04          NVARCHAR(10),  ' +      
                  '@cUDF05          NVARCHAR(10),  ' +      
                  '@cStorerKey      NVARCHAR( 15), ' +      
                  '@cFacility       NVARCHAR( 5),  ' +       
                  '@cUserName       NVARCHAR( 10), ' +  
                  '@nErrNo          INT            OUTPUT, ' +      
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT, ' +   
                  '@nCount          INT            OUTPUT'    
                            
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                           @nMobile, @nFunc, @cLangCode, @nStep, @cOrderNo, @cKeyType, @cCarrierCode, @cCartonNo  
                           , @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, @cStorerKey, @cFacility  
                           , @cUserName  
                           , @nErrNo      OUTPUT  
                           , @cErrMsg     OUTPUT  
   , @nCount OUTPUT     
  
               IF @nErrNo <> 0  
               BEGIN   
                --SET @nErrNo = 99404                
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed  --hcb add  
                EXEC rdt.rdtSetFocusField @nMobile, 2    
                GOTO Step_3_Fail    
               END  
             SET @nCartonCount = @nCartonCount + @nCount  
            END     
         END   --@cExtendedUpdateSP <> ''  
         ELSE  
         BEGIN   
  
            IF (ISNULL(@cUDF01,'')<>'')       
            BEGIN            
               
               SET @cTableName=@cUDF01         
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
            
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 99405        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 2        
                  GOTO Step_3_Fail        
               END      
               
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
                        , @b_success OUTPUT       
                        , @nErrNo OUTPUT       
                        , @cErrMsg OUTPUT            
      
               SET @nCartonCount = @nCartonCount + 1      
            END      
               
            IF (ISNULL(@cUDF02,'')<>'')       
            BEGIN            
               
               SET @cTableName=@cUDF02         
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
    
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 99414        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 2        
                  GOTO Step_3_Fail        
               END      
               
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
                        , @b_success OUTPUT       
                        , @nErrNo OUTPUT       
                        , @cErrMsg OUTPUT            
      
               SET @nCartonCount = @nCartonCount + 1      
            END        
      
            IF (ISNULL(@cUDF03,'')<>'')       
            BEGIN            
               
               SET @cTableName=@cUDF03         
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
            
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 99415        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 2        
                  GOTO Step_3_Fail        
               END      
               
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
                        , @b_success OUTPUT       
                        , @nErrNo OUTPUT       
                        , @cErrMsg OUTPUT            
      
               SET @nCartonCount = @nCartonCount + 1      
            END        
            IF (ISNULL(@cUDF04,'')<>'')       
            BEGIN            
               
               SET @cTableName=@cUDF04         
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
            
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 99416        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 2        
                  GOTO Step_3_Fail        
               END      
               
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
                        , @b_success OUTPUT       
                        , @nErrNo OUTPUT       
                        , @cErrMsg OUTPUT            
      
               SET @nCartonCount = @nCartonCount + 1      
            END      
            IF (ISNULL(@cUDF05,'')<>'')       
            BEGIN            
               
               SET @cTableName=@cUDF05         
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
            
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 99417        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 2        
                  GOTO Step_3_Fail        
               END      
               
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
                        , @b_success OUTPUT       
                        , @nErrNo OUTPUT       
                        , @cErrMsg OUTPUT            
      
               SET @nCartonCount = @nCartonCount + 1      
            END          
         END   --@cExtendedUpdateSP <> ''  
      END   
      ELSE  
      BEGIN  
            SET @nErrNo = 99409    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonNoExist    
            EXEC rdt.rdtSetFocusField @nMobile, 2    
            GOTO Step_3_Fail    
      END  
    
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cOrderKey   
      SET @cOutField02 = ''    
        
      SET @cOutField03 = @nCartonCount  
          
  
          
          
   END  -- Inputkey = 1    
       
   IF @nInputKey = 0     
   BEGIN    
         
     SET @cOutfield01 = ''   
     SET @cOutfield02 = @nOrderCount    
     SET @cOutfield03 = ''  
    
         
     SET @nScn = @nScn - 1     
     SET @nStep = @nStep - 1     
          
          
          
   END    
   GOTO Quit    
    
   STEP_3_FAIL:    
   BEGIN    
      SET @cOutField02 = ''    
      EXEC rdt.rdtSetFocusField @nMobile, 2    
   END    
     
END     
GOTO QUIT    
    
    
/********************************************************************************    
Step 4. Scn = 4573.     
   OrderNo    (Field01)    
   CartonNo   (Field02)    
   Option     (Field03, input)   
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1     
   BEGIN    
        
      SET @cOption = ISNULL(RTRIM(@cInField03),'')    
        
      IF @cOption = ''    
      BEGIN    
         SET @nErrNo = 99406    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionReq    
         GOTO Step_4_Fail    
      END    
        
      IF ISNULL(@cOption,'' )  = '1'  
      BEGIN  
         IF @cExtendedUpdateSP <> ''  
         BEGIN   
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')      
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cOrderNo, @cKeyType, @cCarrierCode, @cCartonNo ' +       
                  ' , @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, @cStorerKey, @cFacility ' +       
                  ' , @cUserName   ' +       
                  ' , @nErrNo      OUTPUT ' +       
                  ' , @cErrMsg     OUTPUT ' +    
                  ' , @nCount      OUTPUT '      
  
               SET @cSQLParam =      
                  '@nMobile         INT,           ' +      
                  '@nFunc           INT,           ' +      
                  '@cLangCode       NVARCHAR( 3),  ' +      
                  '@nStep           INT,           ' +      
                  '@cOrderNo        NVARCHAR( 20), ' +      
                  '@cKeyType        NVARCHAR( 5),  ' +      
                  '@cCarrierCode    NVARCHAR(10),  ' +      
                  '@cCartonNo       NVARCHAR(20),  ' +      
                  '@cUDF01          NVARCHAR(10),  ' +      
                  '@cUDF02          NVARCHAR(10),  ' +      
                  '@cUDF03          NVARCHAR(10),  ' +      
                  '@cUDF04          NVARCHAR(10),  ' +      
                  '@cUDF05          NVARCHAR(10),  ' +      
                  '@cStorerKey      NVARCHAR( 15), ' +      
                  '@cFacility       NVARCHAR( 5),  ' +       
                  '@cUserName       NVARCHAR( 10), ' +  
                  '@nErrNo          INT            OUTPUT, ' +      
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT, ' +   
                  '@nCount          INT            OUTPUT'    
                            
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                              @nMobile, @nFunc, @cLangCode, @nStep, @cOrderNo, @cKeyType, @cCarrierCode, @cCartonNo  
                              , @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, @cStorerKey, @cFacility  
                              , @cUserName  
                              , @nErrNo      OUTPUT  
                              , @cErrMsg     OUTPUT  
                              , @nCount OUTPUT     
  
               IF @nErrNo <> 0  
               BEGIN   
                --SET @nErrNo = 99404                
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed  --hcb add  
                EXEC rdt.rdtSetFocusField @nMobile, 1    
                GOTO Step_3_Fail    
               END  
             SET @nOrderCount = @nOrderCount + @nCount  
            END     
         END   --@cExtendedUpdateSP <> ''  
         ELSE  
         BEGIN   
  
          IF(ISNULL(@cUDF01,'')<>'')       
            BEGIN      
                  
               SET @cTableName=@cUDF01      
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
               
               IF @@ERROR <> 0       
               BEGIN      
              SET @nErrNo = 99407        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 1        
                  GOTO Step_3_Fail        
               END      
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
               , @b_success OUTPUT       
               , @nErrNo OUTPUT       
               , @cErrMsg OUTPUT           
               
               SET @nCartonCount = @nCartonCount + 1      
           END       
      
            IF(ISNULL(@cUDF02,'')<>'')       
            BEGIN      
                  
               SET @cTableName=@cUDF02      
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
               
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 99418        
    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 1        
                  GOTO Step_3_Fail        
               END      
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
               , @b_success OUTPUT       
               , @nErrNo OUTPUT       
               , @cErrMsg OUTPUT           
               
               SET @nCartonCount = @nCartonCount + 1      
            END       
      
            IF(ISNULL(@cUDF03,'')<>'')       
            BEGIN      
                  
               SET @cTableName=@cUDF03      
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
               
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 99419        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 1        
                  GOTO Step_3_Fail        
               END      
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
               , @b_success OUTPUT       
               , @nErrNo OUTPUT       
             , @cErrMsg OUTPUT           
               
               SET @nCartonCount = @nCartonCount + 1      
            END       
      
            IF(ISNULL(@cUDF04,'')<>'')       
            BEGIN      
                  
               SET @cTableName=@cUDF04      
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
               
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 99420        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 1        
                  GOTO Step_3_Fail        
               END      
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
               , @b_success OUTPUT       
               , @nErrNo OUTPUT       
               , @cErrMsg OUTPUT           
               
               SET @nCartonCount = @nCartonCount + 1      
            END       
      
            IF(ISNULL(@cUDF05,'')<>'')       
            BEGIN      
                  
               SET @cTableName=@cUDF05      
      
               INSERT INTO OTMIDTRACK ( TrackingNo, DropLoc, CaseID, MUStatus, AddWho, AddDate, EditWho, EditDate )       
               VALUES ( @cOrderNo, @cCarrierCode, @cCartonNo, '1', @cUserName, GetDATE(), @cUserName , GetDate()  )       
               
               IF @@ERROR <> 0       
               BEGIN      
                  SET @nErrNo = 99421        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTMSFailed        
                  EXEC rdt.rdtSetFocusField @nMobile, 1        
                  GOTO Step_3_Fail        
               END      
               
               EXEC ispGenOTMLog @cTableName, @cOrderNo, '', @cStorerKey, ''       
               , @b_success OUTPUT       
               , @nErrNo OUTPUT       
               , @cErrMsg OUTPUT           
               
               SET @nCartonCount = @nCartonCount + 1      
      
            END  
         END   
  
           
      END  
       
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cOrderKey   
      SET @cOutField02 = ''    
        
        
      SET @cOutField03 = @nCartonCount  
        
        
      SET @nScn = @nScn - 1     
      SET @nStep = @nStep - 1     
        
   END  -- Inputkey = 1    
       
   IF @nInputKey = 0     
   BEGIN    
         
     SET @cOutfield01 = @cOrderNo  
     SET @cOutfield02 = ''  
     SET @cOutfield03 = @nCartonCount  
    
         
     SET @nScn = @nScn - 1     
     SET @nStep = @nStep - 1     
          
          
          
   END    
   GOTO Quit    
    
   STEP_4_FAIL:    
   BEGIN    
      SET @cOutField03 = ''    
      EXEC rdt.rdtSetFocusField @nMobile, 3    
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
      UserName  = @cUserName,    
      InputKey  = @nInputKey,    
        
    
      V_UOM      = @cPUOM,    
      --V_OrderKey = @cOrderKey,    
        
      V_Integer1 = @nOrderCount,  
      V_Integer2 = @nCartonCount,  
      
      V_String1  = @cCarrierCode,  
      --V_String2  = @nOrderCount,   
      --V_String3  = @nCartonCount,  
      V_String4  = @cKeyType,  
      V_String5  = @cCartonNo,  
      V_String6  = @cOrderNo,  
      V_String7  = @cTableName,  
      V_String8  = @cUDF01,      
      V_String9  = @cUDF02,      
      V_String10 = @cUDF03,      
      V_String11 = @cUDF04,      
      V_String12 = @cUDF05,      
      V_String13 = @cExtendedUpdateSP,   
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