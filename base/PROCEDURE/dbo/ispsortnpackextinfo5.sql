SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: ispSortNPackExtInfo5                                */      
/* Copyright      : LFL                                                 */      
/*                                                                      */      
/* Purpose: Return generated labelno to rdt Sort&Pack module for ANF    */      
/*                                                                      */      
/* Called from:                                                         */      
/*                                                                      */      
/* Exceed version: 5.4                                                  */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author   Purposes                                    */      
/* 2014-04-01 1.0  Chee     SOS#307177 Created                          */    
/* 2014-05-21 1.1  Chee     Insert generated labelno into DropID and    */    
/*                          DropIDDetail table to avoid regenerating   8 */    
/*                          another labelno (Chee01)                    */    
/* 2014-05-26 1.2  Chee     Filter DropIDDetail by username if it is    */    
/*                          DCToDC order to avoid getting same label    */    
/*                          concurrently                                */    
/*                          Generate new label if user scan UCC (Chee02)*/    
/* 2014-06-16 1.3  Chee     Add rdt.StorerConfig -                      */    
/*                          GenLabelByUserForDCToStoreOdr (Chee03)      */    
/* 2020-04-22 1.4  YeeKung  WMS- 12853 ADD generate label (yeekung01)   */  
/************************************************************************/      
      
CREATE PROCEDURE [dbo].[ispSortNPackExtInfo5]      
   @cLoadKey         NVARCHAR(10),      
   @cOrderKey        NVARCHAR(10),      
   @cConsigneeKey    NVARCHAR(15),      
   @cLabelNo         NVARCHAR(20) OUTPUT,      
   @cStorerKey       NVARCHAR(15),      
   @cSKU             NVARCHAR(20),      
   @nQTY             INT,       
   @cExtendedInfo    NVARCHAR(20) OUTPUT,      
   @cExtendedInfo2   NVARCHAR(20) OUTPUT,    
   @cLangCode        NVARCHAR(3),    
   @bSuccess         INT          OUTPUT,    
   @nErrNo           INT          OUTPUT,    
   @cErrMsg          NVARCHAR(20) OUTPUT,    
   @nMobile          INT                  -- (Chee02)       
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE     
      @c_PickSlipNo NVARCHAR(10),    
      @n_CartonNo   INT,    
      @b_Success    INT,    
      @n_ErrNo      INT,    
      @c_ErrMsg     NVARCHAR(20),    
      @n_TranCount  INT,          -- (Chee01)    
      @c_UserName   NVARCHAR(18), -- (Chee02)    
      @c_OrderType  NVARCHAR(20), -- (Chee02)    
      @cUCCNo       NVARCHAR(20), -- (Chee02)    
      @nFunc        INT,                             -- (Chee03)    
      @cGenLabelByUserForDCToStoreOdr NVARCHAR(20),  -- (Chee03)    
      @nStep        INT  
  
   SET @n_TranCount = @@TRANCOUNT      
   BEGIN TRAN      
   SAVE TRAN ispSortNPackExtInfo5     
    
   -- Get UserName (Chee02)    
   SELECT @c_UserName = UserName,    
          @nFunc      = Func,      -- (Chee03)    
          @nStep      = Step  
   FROM rdt.RDTMOBREC WITH (NOLOCK)        
   WHERE Mobile = @nMobile   
     
   IF (@nFunc='542') --yeekung01  
   BEGIN  
      IF (@nStep in ('2','6'))  
      BEGIN  
         SELECT TOP 1 @cOrderKey=OD.Orderkey   
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)        --(yeekung01)  
         JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
         JOIN dbo.Orderdetail OD WITH (NOLOCK) ON (O.OrderKey=OD.orderkey)  
         WHERE LPD.LoadKey = @cLoadKey    
         AND    OD.userdefine02=@cExtendedInfo  
  
         IF @@ROWCOUNT=0  
         BEGIN    
            SET @nErrNo = 86956    
            SET @cErrMsg =rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InvalidStoreNo'    
            GOTO RollBackTran    
         END   
  
         SELECT TOP 1     
            @c_PickSlipNo = PD.PickSlipNo    
         FROM dbo.PickDetail PD WITH (NOLOCK)     
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)    
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)    
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)    
         WHERE LPD.LoadKey = @cLoadKey       
           AND PD.StorerKey = @cStorerKey      
           AND PD.Status IN ('3', '5')    
           AND OD.Userdefine02 = @cExtendedInfo    
           AND O.OrderKey = @cOrderKey  
  
         IF @@ROWCOUNT=0  
         BEGIN    
            SET @nErrNo = 86957    
            SET @cErrMsg = @cExtendedInfo--rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InvalidStoreNo'    
            GOTO RollBackTran    
         END   
       
         IF @cLabelNo = ''    
         BEGIN    
            SET @cLabelNo = 'x' -- Pass in random value to avoid error    
            -- Generate ANF UCC Label No        
            EXEC isp_GLBL03                 
            @c_PickSlipNo  = @c_PickSlipNo,               
            @n_CartonNo    = @n_CartonNo,    
            @c_LabelNo     = @cLabelNo    OUTPUT,    
            @cStorerKey    = @cStorerKey,    
            @cDeviceProfileLogKey = '',    
            @cConsigneeKey = @cExtendedInfo,    
            @b_success     = @b_Success   OUTPUT,                
            @n_err         = @n_ErrNo     OUTPUT,                
            @c_errmsg      = @c_ErrMsg    OUTPUT     
  
            SET @cLabelNo=@cLabelNo  
  
            SET @cExtendedInfo=''  
         END    
      END  
   END   
   
   IF (@nFunc='547')  
   BEGIN  
    
      IF ISNULL(@cConsigneeKey, '') = '' OR ISNULL(@cOrderKey, '') = ''    
      BEGIN    
         SET @nErrNo = 86951    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --EmpConsigOrOdr    
         GOTO Quit    
      END    
    
      SELECT TOP 1     
         @c_PickSlipNo = PD.PickSlipNo    
      FROM dbo.PickDetail PD WITH (NOLOCK)     
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)    
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)    
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)    
      WHERE LPD.LoadKey = @cLoadKey       
        AND PD.StorerKey = @cStorerKey    
        AND PD.SKU = @cSKU    
        AND PD.Status IN ('3', '5')    
        AND OD.Userdefine02 = @cConsigneeKey    
        AND O.OrderKey = @cOrderKey    
    
      IF ISNULL(@c_PickSlipNo, '') = ''     
      BEGIN    
         SET @nErrNo = 86952    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --EmpPickSlipNo    
         GOTO Quit    
      END    
    
      -- Get OrderType (Chee02)    
      SELECT @c_OrderType = O.[Type]    
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)    
      JOIN ORDERS O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
      WHERE LPD.LoadKey = @cLoadKey    
        AND O.OrderKey = @cOrderKey     
    
      -- Get GenLabelByUserForDCToStoreOdr rdt.StorerConfig (Chee03)    
      SELECT @cGenLabelByUserForDCToStoreOdr = rdt.RDTGetConfig( @nFunc, 'GenLabelByUserForDCToStoreOdr', @cStorerKey)     
    
      -- Get pass in UCC (Chee02)    
      SET @cUCCNo = LTRIM(RTRIM(ISNULL(@cExtendedInfo, '')))    
      SET @cExtendedInfo = ''    
    
      SET @cLabelNo = ''    
      SELECT @cLabelNo = PD.LabelNo    
      FROM dbo.PackDetail PD WITH (NOLOCK)    
      JOIN dbo.DropID D WITH (NOLOCK) ON (PD.PickSlipNo = D.PickSlipNo AND PD.LabelNo = D.DropID)    
      JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON (D.DropID = DD.DropID)    
      WHERE PD.PickSlipNo = @c_PickSlipNo    
        AND PD.StorerKey = @cStorerKey    
        AND D.DropIDType = '0'     
        AND D.DropLoc = ''    
        AND D.LabelPrinted <> 'Y'    
        AND D.Status <> '9'    
        AND DD.UserDefine01 = @cConsigneeKey    
        AND DD.UserDefine02 = CASE WHEN @c_OrderType = 'DCToDC'     
                                        OR (@c_OrderType = 'N' AND @cGenLabelByUserForDCToStoreOdr = '1') -- (Chee03)    
                                   THEN @c_UserName ELSE DD.UserDefine02 END  -- (Chee02)    
        AND DD.UserDefine03 = @cUCCNo  -- (Chee02)    
    
      -- Get from generated labelno but not pack confirm (Chee01)    
      IF @cLabelNo = ''     
      BEGIN    
         SELECT @cLabelNo = D.DropID    
         FROM dbo.DropID D WITH (NOLOCK)    
         JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON (D.DropID = DD.DropID)    
         WHERE D.PickSlipNo = @c_PickSlipNo    
           AND D.DropIDType = '0'     
           AND D.DropLoc = ''    
           AND D.LabelPrinted <> 'Y'    
           AND D.Status <> '9'    
           AND DD.UserDefine01 = @cConsigneeKey    
           AND DD.UserDefine02 = CASE WHEN @c_OrderType = 'DCToDC'     
                                           OR (@c_OrderType = 'N' AND @cGenLabelByUserForDCToStoreOdr = '1') -- (Chee03)    
                                      THEN @c_UserName ELSE DD.UserDefine02 END  -- (Chee02)    
           AND DD.UserDefine03 = @cUCCNo  -- (Chee02)    
      END    
    
      IF @cLabelNo = ''    
      BEGIN    
         SET @cLabelNo = 'x' -- Pass in random value to avoid error    
         -- Generate ANF UCC Label No        
         EXEC isp_GLBL03                 
            @c_PickSlipNo  = @c_PickSlipNo,               
            @n_CartonNo    = @n_CartonNo,    
            @c_LabelNo     = @cLabelNo    OUTPUT,    
            @cStorerKey    = @cStorerKey,    
            @cDeviceProfileLogKey = '',    
            @cConsigneeKey = @cConsigneeKey,    
            @b_success     = @b_Success   OUTPUT,                
            @n_err         = @n_ErrNo     OUTPUT,                
            @c_errmsg      = @c_ErrMsg    OUTPUT       
    
         IF @n_ErrNo <> 0    
         BEGIN    
            SET @nErrNo = 86953    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelFail    
            GOTO RollBackTran    
         END      
    
         IF NOT EXISTS(SELECT 1 FROM dbo.DropID D WITH (NOLOCK)    
                       JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON (D.DropID = DD.DropID)    
                       WHERE D.PickSlipNo = @c_PickSlipNo    
                         AND D.DropIDType = '0'     
                         AND D.DropLoc = ''    
                         AND D.LabelPrinted <> 'Y'    
                         AND D.Status <> '9'    
                         AND DD.UserDefine01 = @cConsigneeKey    
                         AND DD.UserDefine02 = CASE WHEN @c_OrderType = 'DCToDC'     
                                                         OR (@c_OrderType = 'N' AND @cGenLabelByUserForDCToStoreOdr = '1') -- (Chee03)    
          THEN @c_UserName ELSE DD.UserDefine02 END   -- (Chee02)     
                         AND DD.UserDefine03 = @cUCCNo ) -- (Chee02)     
         BEGIN     
            -- Insert DropID (Chee01)    
            INSERT INTO dbo.DropID     
            (DropID, DropIDType, LabelPrinted, Status, Loadkey, PickSlipNo)    
            VALUES     
            (@cLabelNo, '0', '0', '0', @cLoadKey , @c_PickSlipNo)    
         
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 86954       
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDropIDFail'        
               GOTO RollBackTran        
            END        
    
            -- Insert DropIDDetail (Chee01)    
    
            IF @c_OrderType = 'DCToDC' OR (@c_OrderType = 'N' AND @cGenLabelByUserForDCToStoreOdr = '1') -- (Chee03)    
               INSERT INTO dbo.DropIDDetail (DropID, ChildID , UserDefine01, UserDefine02, UserDefine03) -- (Chee02)    
               VALUES ( @cLabelNo , @cLabelNo, @cConsigneeKey, @c_UserName, @cUCCNo)                    -- (Chee02)    
            ELSE    
               INSERT INTO dbo.DropIDDetail (DropID, ChildID , UserDefine01, UserDefine03) -- (Chee02)    
               VALUES ( @cLabelNo , @cLabelNo, @cConsigneeKey, @cUCCNo)                   -- (Chee02)    
            
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 86955    
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsDrIDDetFail'    
               GOTO RollBackTran    
            END                
         END -- IF NOT EXISTS    
      END -- IF @cLabelNo = ''  
   END    
   GOTO Quit    
    
RollBackTran:      
   ROLLBACK TRAN ispSortNPackExtInfo5      
Quit:      
   WHILE @@TRANCOUNT > @n_TranCount      
      COMMIT TRAN      
END -- End Procedure 

GO