SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdtfnc_CC_Tote_Despatch                                  */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#205169 - RDT C&C Tote Despatch                               */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2011-02-16 1.0  James    Created                                          */  
/* 2011-04-18 1.1  James    Delete tote after dispatch (james01)             */  
/* 2016-09-30 1.2  Ung      Performance tuning                               */
/*****************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_CC_Tote_Despatch](  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
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
   @cDefaultToteLength  NVARCHAR( 1),

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

   -- TraceInfo (Vicky02) - Start
   DECLARE    @d_starttime    datetime,
              @d_endtime      datetime,
              @d_step1        datetime,
              @d_step2        datetime,
              @d_step3        datetime,
              @d_step4        datetime,
              @d_step5        datetime,
              @c_col1         NVARCHAR(20),
              @c_col2         NVARCHAR(20),
              @c_col3         NVARCHAR(20),
              @c_col4         NVARCHAR(20),
              @c_col5         NVARCHAR(20),
              @c_TraceName    NVARCHAR(80)

   SET @d_starttime = getdate()

   SET @c_col1 = @cToteNo
   SET @c_TraceName = 'rdtfnc_CC_Tote_Despatch'

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
   @cToteNo          = V_String1,  
   @cDefaultToteLength = V_String2,  

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
IF @nFunc = 1783  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1783  
   IF @nStep = 1 GOTO Step_1   -- Scn = 2670  Tote No  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 1643)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn  = 2670  
   SET @nStep = 1  

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
      @cStorerKey  = @cStorerkey  
  
   -- initialise all variable  
   SET @cToteNo          = ''
  
   -- Init screen     
   SET @cOutField01 = ''   
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
      SET @cToteNo = @cInField01  
  
      -- Validate blank  
      IF ISNULL(RTRIM(@cToteNo), '') = ''  
      BEGIN  
         SET @nErrNo = 72241  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote No req  
         GOTO Step_1_Fail    
      END  

      IF LEN(RTRIM(@cToteNo)) <> @cDefaultToteLength
      BEGIN            
         SET @nErrNo = 72242                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTENO LEN                
         GOTO Step_1_Fail                
      END            

      -- Validate label printed  
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
         WHERE LabelPrinted <> 'Y'
         AND DropID = @cToteNo)  
      BEGIN  
         SET @nErrNo = 72243  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LBL Not Print  
         GOTO Step_1_Fail    
      END  

      -- Validate manifest printed  
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
         WHERE ManifestPrinted <> 'Y'
         AND DropID = @cToteNo)  
      BEGIN  
         SET @nErrNo = 72244  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mfes Not Print  
         GOTO Step_1_Fail    
      END  

      IF EXISTS (SELECT 1 FROM dbo.DropIDDetail DD WITH (NOLOCK) 
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = Ph.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         WHERE DD.DropID = @cToteNo
         AND O.StorerKey = @cStorerKey
         AND O.IncoTerm <> 'CC')
      BEGIN  
         SET @nErrNo = 72245
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote not C&C  
         GOTO Step_1_Fail    
      END  

      IF EXISTS (SELECT 1 FROM dbo.DropIDDetail DD WITH (NOLOCK) 
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = Ph.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         WHERE DD.DropID = @cToteNo
         AND O.StorerKey = @cStorerKey
         AND O.Status <> '9')
      BEGIN  
         SET @nErrNo = 72246
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORD Not Shipped  
         GOTO Step_1_Fail    
      END  

      SET @d_step1 = GETDATE() 
      IF NOT EXISTS (SELECT 1 
         FROM dbo.DropIDDetail DD WITH (NOLOCK) 
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = Ph.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         JOIN dbo.POD POD WITH (NOLOCK) ON O.OrderKey = POD.OrderKey
         WHERE DD.DropID = @cToteNo
            AND O.StorerKey = @cStorerKey
            AND O.IncoTerm = 'CC'
            AND O.Status = '9' )
      BEGIN  
         SET @nErrNo = 72247
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --POD Not Exists
         GOTO Step_1_Fail    
      END  
      SET @d_step1 = GETDATE() - @d_step1

      SET @d_step2 = GETDATE()
      IF NOT EXISTS (SELECT 1 
         FROM dbo.PackDetail PD WITH (NOLOCK) 
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = Ph.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         JOIN dbo.POD POD WITH (NOLOCK) ON O.OrderKey = POD.OrderKey AND O.MBOLKEY = POD.MBOLKEY
         WHERE PD.DropID = @cToteNo
            AND O.StorerKey = @cStorerKey
            AND O.IncoTerm = 'CC'
            AND O.Status = '9' 
            AND POD.FinalizeFlag = 'N'
            AND PD.StorerKey = @cStorerKey)
      BEGIN  
         -- If cannot find using the packdetail then look up in dropid too
         IF NOT EXISTS (SELECT 1 
         FROM dbo.DropIDDetail DD WITH (NOLOCK) 
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = Ph.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         JOIN dbo.POD POD WITH (NOLOCK) ON O.OrderKey = POD.OrderKey AND O.MBOLKEY = POD.MBOLKEY
         WHERE DD.DropID = @cToteNo
            AND O.StorerKey = @cStorerKey
            AND O.IncoTerm = 'CC'
            AND O.Status = '9' 
            AND POD.FinalizeFlag = 'N'
            AND PD.StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 72248
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --POD finalized
            GOTO Step_1_Fail    
         END
      END  
      SET @d_step2 = GETDATE() - @d_step2

      SET @d_step3 = GETDATE() 
      IF EXISTS (SELECT 1 
         FROM dbo.DropIDDetail DD WITH (NOLOCK) 
         JOIN dbo.PackDetail PD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = Ph.PickSlipNo
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
         JOIN dbo.POD POD WITH (NOLOCK) ON O.OrderKey = POD.OrderKey
         WHERE DD.DropID = @cToteNo
            AND O.StorerKey = @cStorerKey
            AND O.IncoTerm = 'CC'
            AND O.Status = '9'
            AND POD.Status IN ('0', '4') )
      BEGIN  
         SET @nErrNo = 72249
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv POD Status
         GOTO Step_1_Fail    
      END  
      SET @d_step3 = GETDATE() - @d_step3



      BEGIN TRAN

      SET @d_step4 = GETDATE() 
      DECLARE CUR_UPDPOD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT DISTINCT O.OrderKey 
      FROM dbo.DropIDDetail DD WITH (NOLOCK) 
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON DD.ChildID = PD.LabelNo
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = Ph.PickSlipNo
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
      WHERE DD.DropID = @cToteNo
         AND O.StorerKey = @cStorerKey
         AND O.IncoTerm = 'CC'
         AND O.Status = '9'

      OPEN CUR_UPDPOD
      FETCH NEXT FROM CUR_UPDPOD INTO @cOrderKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @d_step4 = GETDATE() - @d_step4

         SET @d_step5 = GETDATE()
         UPDATE POD WITH (ROWLOCK) SET 
            FinalizeFlag = 'Y' 
         WHERE OrderKey = @cOrderKey 
            AND FinalizeFlag <> 'Y'

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72250
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Conf POD Fail  
            CLOSE CUR_UPDPOD
            DEALLOCATE CUR_UPDPOD
            GOTO Step_1_Fail    
         END
         SET @d_step5 = GETDATE() - @d_step5
         SET @c_col2 = @cOrderKey

            -- Trace Info 
            SET @d_endtime = GETDATE()
            INSERT INTO TraceInfo VALUES
                  (RTRIM(@c_TraceName), @d_starttime, @d_endtime
                  ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
                  ,CONVERT(CHAR(12),@d_step1,114)
                  ,CONVERT(CHAR(12),@d_step2,114)
                  ,CONVERT(CHAR(12),@d_step3,114)
                  ,CONVERT(CHAR(12),@d_step4,114)
                  ,CONVERT(CHAR(12),@d_step5,114)
                      ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)
         FETCH NEXT FROM CUR_UPDPOD INTO @cOrderKey
      END
      CLOSE CUR_UPDPOD
      DEALLOCATE CUR_UPDPOD

      -- (james01)
      DELETE FROM dbo.DROPIDDETAIL
      WHERE DropID = @cToteNo 

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 72251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDIDDetFail
         GOTO Step_1_Fail
      END

      DELETE FROM dbo.DROPID
      WHERE DropID = @cToteNo
      AND   Status = '9'

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 72252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDropIDFail
         GOTO Step_1_Fail 
      END

      COMMIT TRAN

      -- insert to Eventlog                
      EXEC RDT.rdt_STD_EventLog                
         @cActionType   = '16',                
         @cUserID       = @cUserName,                
         @nMobileNo     = @nMobile,                
         @nFunctionID   = @nFunc,                
         @cFacility     = @cFacility,                
         @cStorerKey    = @cStorerkey,                
         @cRefNo1       = @cToteNo              

      --prepare next screen variable  
      SET @cOutField01 = ''  
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
       @cStorerKey  = @cStorerkey  
  
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
      SET @cToteNo = ''  
   END  
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
      V_String1      = @cToteNo,  
      V_String2      = @cDefaultToteLength,  

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