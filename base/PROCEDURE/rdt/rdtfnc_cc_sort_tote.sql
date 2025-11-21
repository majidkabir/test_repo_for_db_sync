SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdtfnc_CC_Sort_Tote                                      */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#202456 - RDT C&C Sort To Tote                                */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2011-02-16 1.0  James    Created                                          */  
/* 2011-04-15 1.1  James    Close Tote when manifest prints (james01)        */  
/* 2011-04-18 1.2  James    Delete tote for non C&C type only (james02)      */  
/* 2011-10-05 1.3  James    SOS215850 - Not to default PTS action (james03)  */  
/* 2014-09-03 1.4  James    SOS320178 - Add extended update sp (james04)     */  
/* 2014-09-23 1.5  James    Extend DefaultToteLength variable (james05)      */
/* 2016-09-30 1.6  Ung      Performance tuning                               */
/* 2018-10-31 1.7  TungGH   Performance                                      */
/*****************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_CC_Sort_Tote](  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max  
) AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
-- Misc variable  
DECLARE  
   @b_success           INT  
          
-- Define a variable  
DECLARE    
   @nFunc               INT,  
   @nScn                INT,  
   @nStep               INT,  
   @cLangCode           NVARCHAR( 3),  
   @nMenu               INT,  
   @nInputKey           NVARCHAR( 3),  
   @cPrinter            NVARCHAR( 10),  
   @cUserName           NVARCHAR( 18),  
   @cPrinter_Paper      NVARCHAR( 10), 
  
   @cStorerKey          NVARCHAR( 15),  
   @cFacility           NVARCHAR( 5),  
  
   @cConsigneekey       NVARCHAR( 15),  
   @cOrderKey           NVARCHAR( 10),  
   @cLoadKey            NVARCHAR( 10),  
   @cPickSlipNo         NVARCHAR( 10),  
   @cToteNo             NVARCHAR( 28),
   @cDefaultPTSAction   NVARCHAR( 1),  
   @cDefaultToteLength  NVARCHAR( 2),  -- (james05)
   @cLabelNo            NVARCHAR( 20),
   @cOption             NVARCHAR( 1),
   @cPrefix             NVARCHAR( 2),
   @cSurfix             NVARCHAR( 2),
   @cReportType         NVARCHAR( 10),                
   @cPrintJobName       NVARCHAR( 50),                
   @cDataWindow         NVARCHAR( 50),                
   @cTargetDB           NVARCHAR( 20), 
   @cTaskDetailKey      NVARCHAR( 10), 

   @cExtendedUpdateSP   NVARCHAR( 20),    -- (james04)
   @cSQL                NVARCHAR(1000),   -- (james04)
   @cSQLParam           NVARCHAR(1000),   -- (james04)

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
              
-- Getting Mobile information  
SELECT   
   @nFunc            = Func,  
   @nScn             = Scn,  
   @nStep            = Step,  
   @nInputKey        = InputKey,  
   @cLangCode        = Lang_code,  
   @nMenu            = Menu,  
  
   @cFacility        = Facility,  
   @cStorerKey       = StorerKey,  
   @cPrinter         = Printer,   
   @cUserName        = UserName,  
   @cPrinter_Paper   = Printer_Paper, 
  
   @cConsigneekey    = V_ConsigneeKey,  
   @cOrderKey        = V_OrderKey,  
   @cLoadKey         = V_LoadKey,  
   @cPickSlipNo      = V_PickSlipNo,  
   @cLabelNo         = V_String1,  
   @cToteNo          = V_String2,  
   @cDefaultPTSAction   = V_String3, 
   @cDefaultToteLength  = V_String4, 

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
  
FROM   RDT.RDTMOBREC (NOLOCK)  
WHERE  Mobile = @nMobile  
  
  
-- Redirect to respective screen  
IF @nFunc = 1782  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1782  
   IF @nStep = 1 GOTO Step_1   -- Scn = 2660  Label No  
   IF @nStep = 2 GOTO Step_2   -- Scn = 2661  Label No/Store/Tote No/Option  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 1643)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn  = 2660  
   SET @nStep = 1  

   SET @cDefaultPTSAction  = rdt.RDTGetConfig( @nFunc, 'DefaultPTSAction', @cStorerKey)  
   IF ISNULL(@cDefaultPTSAction, '') NOT IN ('1', '9')  
   BEGIN  
      SET @cDefaultPTSAction = ''  
   END  

   -- Get the default length of tote no  
   SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)  
   IF ISNULL(@cDefaultToteLength, '') = ''
   BEGIN  
      SET @cDefaultToteLength = '8'  -- make it default to 8 digit if not setup
   END  

   -- EventLog - Sign In Function  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType = '1', -- Sign in function  
      @cUserID     = @cUserName,  
      @nMobileNo   = @nMobile,  
      @nFunctionID = @nFunc,  
      @cFacility   = @cFacility,  
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep  
  
   -- initialise all variable  
   SET @cLabelNo         = ''  
   SET @cConsigneeKey    = ''
   SET @cToteNo          = ''
   SET @cOption          = ''  
  
   -- Init screen     
   SET @cOutField01 = ''   
   SET @cOutField02 = ''   
END  
GOTO Quit  
  
/********************************************************************************  
Step 1. screen = 2660  
   Label No (Field01, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cLabelNo = @cInField01  
  
      -- Validate blank  
      IF ISNULL(RTRIM(@cLabelNo), '') = ''  
      BEGIN  
         SET @nErrNo = 72191  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Label No req  
         GOTO Step_1_Fail    
      END  

      -- C&C despatch label will have 'CC' as prefix and surfix in the barcode
      SET @cPrefix = SUBSTRING(@cLabelNo, 1, 2)
      SET @cSurfix = SUBSTRING(@cLabelNo, LEN(@cLabelNo) - 2, 2)

      -- If Prefix and Surfix does not contain 'CC' then this is not a C&C orders
      IF @cPrefix <> 'CC' AND @cSurfix <> 'CC'
      BEGIN  
         SET @nErrNo = 72192  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Label No  
         GOTO Step_1_Fail    
      END  

      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE LabelNo =  @cLabelNo)
      BEGIN  
         SET @nErrNo = 72193  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Label No  
         GOTO Step_1_Fail    
      END  

      SELECT TOP 1 
         @cOrderKey = PH.OrderKey, 
         @cPickSlipNo = PH.PickSlipNo, 
         @cLoadKey = O.LoadKey 
      FROM dbo.PackDetail PD WITH (NOLOCK) 
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickslipNo = PH.PickSlipNo
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
      WHERE PH.StorerKey = @cStorerKey
         AND PD.LabelNo = @cLabelNo

      -- Check if it is a C&C orders
      IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND IncoTerm = 'CC')
      BEGIN  
         SET @nErrNo = 72194  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not C&C ORD 
         GOTO Step_1_Fail    
      END  

--      IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
--         WHERE StorerKey = @cStorerKey
--         AND OrderKey = @cOrderKey
--         AND IncoTerm = 'CC'
--         AND Status = '9')
--      BEGIN  
--         SET @nErrNo = 72195  
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDERS Shipped  
--         GOTO Step_1_Fail    
--      END  

      IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND IncoTerm = 'CC'
         AND Status = 'CANC')
      BEGIN  
         SET @nErrNo = 72196  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDERS CANC  
         GOTO Step_1_Fail    
      END  

      IF EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE ChildID = @cLabelNo)
      BEGIN       
         SET @nErrNo = 72197  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Label Scanned  
         GOTO Step_1_Fail 
      END               

      SELECT TOP 1 @cConsigneeKey = ConsigneeKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey

      --prepare next screen variable  
      SET @cOutField01 = @cLabelNo  
      SET @cOutField02 = @cConsigneeKey  
      SET @cOutField03 = ''  
      SET @cOutField04 = @cDefaultPTSAction  
      EXEC rdt.rdtSetFocusField @nMobile, 3  
  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- EventLog - Sign Out Function  
      EXEC RDT.rdt_STD_EventLog  
       @cActionType = '9', -- Sign Out function  
       @cUserID     = @cUserName,  
       @nMobileNo   = @nMobile,  
       @nFunctionID = @nFunc,  
       @cFacility   = @cFacility,  
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep 
  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
  
      SET @cOutField01 = ''   
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      SET @cOutField01 = ''   
      SET @cLabelNo = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 2. screen = 2661  
   Label No  (Field01)  
   Store     (Field02)  
   TOTE      (Field03, input)  
   Option    (Field04, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cToteNo = @cInField03  
      SET @cOption = @cInField04  
  
      -- Validate blank  
      IF ISNULL(@cToteNo, '') = '' AND ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 72224  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTE/OPT req  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         GOTO Quit    
      END

      IF ISNULL(@cToteNo, '') = '' AND ISNULL(@cOption, '') <> ''
      BEGIN  
         IF EXISTS (SELECT 1 FROM RDT.RDTXML_Root WITH (NOLOCK) 
                    WHERE Mobile = @nMobile
                    AND Focus = 'Field03')
         BEGIN
            SET @nErrNo = 72198  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote No req 
            SET @cOutField04 =  @cOption
         END

         EXEC rdt.rdtSetFocusField @nMobile, 3  
         GOTO Quit    
      END  

      SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)  
      IF ISNULL(@cDefaultToteLength, '') = ''
      BEGIN  
         SET @cDefaultToteLength = '8'  -- make it default to 8 digit if not setup
      END  
   
      -- Check the length of tote no (james20)
      IF LEN(RTRIM(@cToteNo)) <> @cDefaultToteLength
      BEGIN            
         SET @nErrNo = 72199  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTENO LEN  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         SET @cOutField03 = ''
         SET @cOutField04 =  CASE WHEN ISNULL(@cOption, '') = '' THEN '' ELSE @cOption END
         GOTO Quit       
      END      

      IF ISNULL(@cOption, '') = '' AND ISNULL(@cToteNo, '') <> ''         
      BEGIN       
         IF EXISTS (SELECT 1 FROM RDT.RDTXML_Root WITH (NOLOCK) 
                    WHERE Mobile = @nMobile
                    AND Focus = 'Field04')
         BEGIN
            SET @nErrNo = 72202      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req                
         END

         SET @cOutField03 = @cToteNo
         EXEC rdt.rdtSetFocusField @nMobile, 4                
         GOTO Quit    
      END                 
                
      IF ISNULL(@cOption, '') <> '1' AND ISNULL(@cOption, '') <> '9'                
      BEGIN                
         SET @nErrNo = 72203                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option                
         EXEC rdt.rdtSetFocusField @nMobile, 4                
         SET @cOutField03 = CASE WHEN ISNULL(@cToteNo, '') = '' THEN '' ELSE @cToteNo END
         SET @cOutField04 = ''
         GOTO Quit    
      END                 

      -- (james02)
      IF EXISTS ( SELECT 1 From dbo.DropID WITH (NOLOCK) Where DropID = @cToteNo And Status = '9' AND DropIDType <> 'C&C')
      BEGIN
         BEGIN TRAN
         DELETE FROM dbo.DROPIDDETAIL
         WHERE DropID = @cToteNo

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72222
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDIDDetFail
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            SET @cOutField03 = ''
            GOTO Quit       
         END

         DELETE FROM dbo.DROPID
         WHERE DropID = @cToteNo
         AND   Status = '9'

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72223
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDropIDFail
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            SET @cOutField03 = ''
            GOTO Quit       
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END
      END

      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToteNo AND ManifestPrinted = 'Y')          
      BEGIN                
         SET @nErrNo = 72200                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Closed                
         EXEC rdt.rdtSetFocusField @nMobile, 3             
         SET @cOutField03 = ''
         GOTO Quit    
      END                

      IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK)               
                 WHERE DropID = @cToteNo    
                 AND Status < '9'  
                 AND DropLOC <> @cConsigneeKey)              
      BEGIN              
         SET @nErrNo = 72201                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote4OtherStore                
         EXEC rdt.rdtSetFocusField @nMobile, 3                
         SET @cOutField03 = ''
         GOTO Quit    
      END              

      Step_Insert_DropID:
      BEGIN TRAN

      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
         WHERE Dropid = @cToteNo
         AND Status = '0')
      BEGIN
         INSERT INTO dbo.DropID     
         (Dropid, Droploc, LabelPrinted, [Status], ManifestPrinted, Loadkey, PickSlipNo, DropIDType)  
         VALUES(@cToteNo, @cConsigneeKey, 'N', '0', 'N', ISNULL(@cLoadKey,''), @cPickSlipNo, 'C&C')    
      
         IF @@ERROR <> 0
         BEGIN                   
            ROLLBACK TRAN 
            SET @nErrNo = 72204                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIdFail                
            EXEC rdt.rdtSetFocusField @nMobile, 4                
            GOTO Quit          
         END     
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) 
         WHERE DropID = @cToteNo
         AND ChildId = @cLabelNo)
      BEGIN
         INSERT INTO dbo.DropIDDetail     
         (Dropid, ChildId)  
         VALUES(@cToteNo, @cLabelNo)    

         IF @@ERROR <> 0
         BEGIN                   
            ROLLBACK TRAN 
            SET @nErrNo = 72205                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIdDFail                
            EXEC rdt.rdtSetFocusField @nMobile, 4                
            GOTO Quit          
         END     
      END

      -- Update dropid
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT DISTINCT TD.TASKDETAILKEY 
      FROM dbo.PACKDETAIL PAD WITH (NOLOCK)
      JOIN dbo.PACKHEADER PAH WITH (NOLOCK) ON PAD.PICKSLIPNO = PAH.PICKSLIPNO
      JOIN dbo.PICKDETAIL PID WITH (NOLOCK) ON PAH.ORDERKEY = PID.ORDERKEY
      JOIN dbo.TASKDETAIL TD WITH (NOLOCK) ON PID.TASKDETAILKEY = TD.TASKDETAILKEY
      JOIN dbo.ORDERS O WITH (NOLOCK) ON PID.ORDERKEY = O.ORDERKEY
      WHERE PID.STORERKEY = @cStorerKey
         AND PAD.LABELNO = @cLabelNo
         AND TASKTYPE = 'PK'
         AND TD.Status = '9'     
         AND O.INCOTERM = 'CC'
         AND O.LoadKey = @cLoadKey

      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @cTaskDetailKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE TASKDETAIL WITH (ROWLOCK) SET 
            Message02 = Dropid, 
            DropID = @cToteNo,
            TrafficCop = NULL 
         WHERE TaskDetailKey = @cTaskDetailKey
            AND StorerKey = @cStorerKey
            AND Status = '9'

         IF @@ERROR <> 0
         BEGIN                   
            ROLLBACK TRAN 
            SET @nErrNo = 72219                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDropIdFailed                
            EXEC rdt.rdtSetFocusField @nMobile, 4                
            GOTO Quit          
         END     

         FETCH NEXT FROM CUR_UPD INTO @cTaskDetailKey
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
 
      -- Update pickdetail
      UPDATE PID WITH (ROWLOCK) SET 
         PID.DropID = @cToteNo, 
         PID.TrafficCop = NULL 
      FROM dbo.PICKDETAIL PID 
      JOIN dbo.PACKHEADER PAH ON PID.OrderKey = PAH.OrderKey
      JOIN dbo.PackDetail PAD ON PAH.PickSlipNo = PAD.PickSlipNo
      JOIN dbo.ORDERS O ON PID.ORDERKEY = O.ORDERKEY
      WHERE O.StorerKey = @cStorerKey
         AND PAD.LabelNo = @cLabelNo
         AND O.LoadKey = @cLoadKey
         AND O.IncoTerm = 'CC'

      IF @@ERROR <> 0
      BEGIN                   
         ROLLBACK TRAN 
         SET @nErrNo = 72220                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDropIdFailed                
         EXEC rdt.rdtSetFocusField @nMobile, 4                
         GOTO Quit          
      END     

      -- Update packdetail
      UPDATE PD WITH (ROWLOCK) SET 
         DropID = @cToteNo, 
         ArchiveCop = NULL 
      FROM dbo.PACKDETAIL PD 
      JOIN dbo.PACKHEADER PH ON PD.PICKSLIPNO = PH.PICKSLIPNO
      JOIN dbo.ORDERS O ON PH.ORDERKEY = O.ORDERKEY
      WHERE O.StorerKey = @cStorerKey
         AND PD.LabelNo = @cLabelNo
         AND O.LoadKey = @cLoadKey
         AND O.IncoTerm = 'CC'

      IF @@ERROR <> 0
      BEGIN                   
         ROLLBACK TRAN 
         SET @nErrNo = 72221                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDropIdFailed                
         EXEC rdt.rdtSetFocusField @nMobile, 4                
         GOTO Quit          
      END     

     -- insert to Eventlog                
      EXEC RDT.rdt_STD_EventLog                
         @cActionType   = '19',                
         @cUserID       = @cUserName,                
         @nMobileNo     = @nMobile,                
         @nFunctionID   = @nFunc,                
         @cFacility     = @cFacility,                
         @cStorerKey    = @cStorerkey,                
         @cDropID       = @cToteNo,
         @cLabelNo      = @cLabelNo,
         @cConsigneeKey = @cConsigneekey,
         @nStep         = @nStep

      -- Start Printing
      IF ISNULL(@cPrinter, '') = ''                
      BEGIN                   
         ROLLBACK TRAN 
         SET @nErrNo = 72206                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLoginPrinter                
         EXEC rdt.rdtSetFocusField @nMobile, 4                
         GOTO Quit          
      END              

      IF ISNULL(@cOption, '') = '1'
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToteNo              
                       AND LabelPrinted = 'Y')              
         BEGIN         
            SET @cReportType = 'CCSTLABEL'                
            SET @cPrintJobName = 'PRINT_CCSORTLABEL'                
                      
            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),                
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')                 
            FROM RDT.RDTReport WITH (NOLOCK)                 
            WHERE StorerKey = @cStorerKey                
            AND   ReportType = @cReportType                
                            
            IF ISNULL(@cDataWindow, '') = ''                
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 72207                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup                
               EXEC rdt.rdtSetFocusField @nMobile, 4                
               GOTO Quit              
            END                
                         
            IF ISNULL(@cTargetDB, '') = ''                
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 72208                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set                
               EXEC rdt.rdtSetFocusField @nMobile, 4                
               GOTO Quit              
            END                
                         
            SET @nErrNo = 0                
            EXEC RDT.rdt_BuiltPrintJob                 
               @nMobile,                
               @cStorerKey,                
               @cReportType,                
               @cPrintJobName,                
               @cDataWindow,                
               @cPrinter,                
               @cTargetDB,                
               @cLangCode,                
               @nErrNo  OUTPUT,                 
               @cErrMsg OUTPUT,                
               @cStorerKey,                
               @cToteNo                
                      
            IF @nErrNo <> 0                
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 72209                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'                
               EXEC rdt.rdtSetFocusField @nMobile, 4                
               GOTO Quit              
            END                
            ELSE              
            BEGIN              
               UPDATE DROPID WITH (ROWLOCK)              
               SET LabelPrinted = 'Y'              
               WHERE Dropid = @cToteNo    
                       
               IF @@ERROR <> 0               
               BEGIN              
                  ROLLBACK TRAN              
                  SET @nErrNo = 72210              
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFailed'              
                  EXEC rdt.rdtSetFocusField @nMobile, 4                
                  GOTO Quit              
               END                                                
            END                
         END  -- Print Tote Label     

         IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToteNo              
                       AND ManifestPrinted = 'Y')              
         BEGIN                                 
            SET @cReportType = 'CCSTMFEST'                
            SET @cPrintJobName = 'PRINT_CCSORTMANFEST'                
                         
            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),                
                  @cTargetDB = ISNULL(RTRIM(TargetDB), '')                 
            FROM RDT.RDTReport WITH (NOLOCK)              
            WHERE StorerKey = @cStorerKey                
            AND   ReportType = @cReportType                
                         
            IF ISNULL(@cDataWindow, '') = ''                
            BEGIN            
               ROLLBACK TRAN                
               SET @nErrNo = 72211               
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup                
               EXEC rdt.rdtSetFocusField @nMobile, 4                
               GOTO Quit          
            END                
                         
            IF ISNULL(@cTargetDB, '') = ''                
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 72212              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set                
               EXEC rdt.rdtSetFocusField @nMobile, 4                
               GOTO Quit          
            END                
                      
            SET @nErrNo = 0                
            EXEC RDT.rdt_BuiltPrintJob                 
               @nMobile,                
               @cStorerKey,                
               @cReportType,                
               @cPrintJobName,                
               @cDataWindow,                
               @cPrinter_Paper, 
               @cTargetDB,                
               @cLangCode,                
               @nErrNo  OUTPUT,                
               @cErrMsg OUTPUT,                
               @cStorerKey,                
               @cToteNo                
        
            IF @nErrNo <> 0                
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 72213                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'                
               EXEC rdt.rdtSetFocusField @nMobile, 4                
               GOTO Quit          
            END                
            ELSE              
            BEGIN              
               UPDATE DROPID WITH (ROWLOCK)              
               SET ManifestPrinted = 'Y', Status = '9'   -- (james01)              
               WHERE Dropid = @cToteNo     
         
               IF @@ERROR <> 0               
               BEGIN              
                  ROLLBACK TRAN              
                  SET @nErrNo = 72214              
                  SET @cErrMsg = rdt.rdtgetmessage( 70136, @cLangCode, 'DSP') --'UpdDropIdFailed'              
                  EXEC rdt.rdtSetFocusField @nMobile, 4                
                  GOTO Quit          
               END                                                    
            END              
         END -- Print Tote Manifest                           
      END
      ELSE
      IF ISNULL(@cOption, '') = '9'
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToteNo              
                       AND LabelPrinted = 'Y')              
         BEGIN              
            SET @cReportType = 'CCSTLABEL'                
            SET @cPrintJobName = 'PRINT_CCSORTLABEL'                
                      
            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),                
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')                 
            FROM RDT.RDTReport WITH (NOLOCK)                 
            WHERE StorerKey = @cStorerKey                
            AND   ReportType = @cReportType                
                         
            IF ISNULL(@cDataWindow, '') = ''                
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 72215                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup                
               EXEC rdt.rdtSetFocusField @nMobile, 4                
               GOTO Quit              
            END                
                         
            IF ISNULL(@cTargetDB, '') = ''                
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 72216                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set                
               EXEC rdt.rdtSetFocusField @nMobile, 4                
               GOTO Quit              
            END                
                         
            SET @nErrNo = 0                
            EXEC RDT.rdt_BuiltPrintJob                 
               @nMobile,                
               @cStorerKey,                
               @cReportType,                
               @cPrintJobName,                
               @cDataWindow,                
               @cPrinter,                
               @cTargetDB,                
               @cLangCode,                
               @nErrNo  OUTPUT,                 
               @cErrMsg OUTPUT,                
               @cStorerKey,                
               @cToteNo                
                         
            IF @nErrNo <> 0                
            BEGIN                
               ROLLBACK TRAN                
               SET @nErrNo = 72217                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'                
               EXEC rdt.rdtSetFocusField @nMobile, 4                
               GOTO Quit              
            END                
            ELSE              
            BEGIN              
               UPDATE DROPID WITH (ROWLOCK)              
               SET LabelPrinted = 'Y'              
               WHERE Dropid = @cToteNo        
                   
               IF @@ERROR <> 0               
               BEGIN              
                  ROLLBACK TRAN              
                  SET @nErrNo = 72218              
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFailed'              
                  EXEC rdt.rdtSetFocusField @nMobile, 4                
                  GOTO Quit              
               END                                                
            END                
         END  -- Print Tote Label       
      END

      SET @cExtendedUpdateSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
      IF @cExtendedUpdateSP NOT IN ('0', '')
      BEGIN
         SET @nErrNo = 0
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cLabelNo, @cToteNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParam =    
            '@nMobile                   INT, '           +
            '@nFunc                     INT, '           +
            '@cLangCode                 NVARCHAR( 3), '  +
            '@nStep                     INT, '           +
            '@nInputKey                 INT, '           + 
            '@cStorerkey                NVARCHAR( 15), ' +
            '@cLabelNo                  NVARCHAR( 20), ' +
            '@cToteNo                   NVARCHAR( 18), ' +
            '@cOption                   NVARCHAR( 1),  ' +
            '@nErrNo                    INT           OUTPUT,  ' +
            '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cLabelNo, @cToteNo, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT     
              
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN              
            EXEC rdt.rdtSetFocusField @nMobile, 4                
            GOTO Quit              
         END
      END
   
      COMMIT TRAN

      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''
  
      -- Go back to prev screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''
  
      -- Go back to prev screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
END  
GOTO Quit  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET  
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg,   
      Func          = @nFunc,  
      Step          = @nStep,              
      Scn           = @nScn,  

      StorerKey     = @cStorerKey,  
      Facility      = @cFacility,   
      Printer       = @cPrinter,      
      -- UserName      = @cUserName,  
  
      V_ConsigneeKey = @cConsigneekey,  
      V_OrderKey     = @cOrderKey,  
      V_LoadKey      = @cLoadKey,  
      V_PickSlipNo   = @cPickSlipNo,  
      V_String1      = @cLabelNo,   
      V_String2      = @cToteNo,  
      V_String3      = @cDefaultPTSAction, 
      V_String4      = @cDefaultToteLength,

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