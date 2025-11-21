SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_525ExtUpdSP01                                   */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_MoveByDropID_Drop                          */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2014-12-18  1.0  ChewKP   SOS#32678 Created                          */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_525ExtUpdSP01] (    
   @nMobile     INT,    
   @nFunc       INT,    
   @cLangCode   NVARCHAR( 3),    
   @cUserName   NVARCHAR( 15),    
   @cFacility   NVARCHAR( 5),    
   @cStorerKey  NVARCHAR( 15),    
   @nStep       INT,  
   @cFromDropID NVARCHAR(20),  
   @cToDropID   NVARCHAR(20),  
   @nErrNo      INT              OUTPUT,    
   @cErrMsg     NVARCHAR( 20)    OUTPUT  -- screen limitation, 20 char max    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE @cToPickSlipNo NVARCHAR(10)  
          ,@cPackSKU      NVARCHAR(20)  
          ,@nQty          NVARCHAR(20)  
          ,@cOrderKey     NVARCHAR(10)  
          ,@cToLabelLineNo  NVARCHAR(5)   
          ,@nToCartonNo     INT  
          ,@nTranCount      INT  
  
   SET @nErrNo                = 0    
   SET @cErrMsg               = ''   
   SET @cToPickSlipNo         = ''  
   SET @cPackSKU              = ''  
   SET @nQty                  = 0  
   SET @cOrderKey             = ''  
   SET @cToLabelLineNo        = ''  
   SET @nToCartonNo           = 0  
     
     
   SET @nTranCount = @@TRANCOUNT  
     
   BEGIN TRAN  
   SAVE TRAN rdt_525ExtUpdSP01  
     
   SELECT TOP 1  
         @cToPickSlipNo = PD.PickslipNo  
         ,@cOrderKey    = PH.OrderKey  
   FROM dbo.PackDetail PD WITH (NOLOCK)  
   INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo  
   WHERE PD.StorerKey = @cStorerKey  
      AND PD.DropID = @cToDropID  
   ORDER BY PD.PickSlipNo Desc  
     
     
  
     
   DECLARE Cur_OffSet_PackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT PD.SKU  
   FROM dbo.PackDetail PD WITH (NOLOCK)   
   WHERE PD.PickSlipNo = @cToPickSlipNo    
   AND PD.DropID    = @cFromDropID    
   AND PD.StorerKey = @cStorerKey    
   ORDER BY PD.SKU  
    
   OPEN Cur_OffSet_PackDetail    
   FETCH NEXT FROM Cur_OffSet_PackDetail INTO @cPackSKU  
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
           
         SET @nToCartonNo = 0    
         SELECT TOP 1    
            @nToCartonNo    = ISNULL(CartonNo,0),    
            @cToLabelLineNo = LabelLine  
         FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo  = @cToPickSlipNo    
           AND DropID      = @cToDropID    
           AND SKU         = @cPackSKU  
         ORDER BY CartonNo DESC    
     
         IF EXISTS ( SELECT 1 FROM dbo.PACKDETAIL PD WITH (NOLOCK)  
                     WHERE PD.PickSlipNo = @cToPickSlipNo    
                     AND PD.DropID    = @cToDropID    
                     AND PD.StorerKey = @cStorerKey    
                     AND PD.SKU       = @cPackSKU )   
         BEGIN   
              
               SELECT @nQty = SUM(Qty)   
               FROM dbo.PackDetail PD      
               WHERE PD.PickSlipNo = @cToPickSlipNo      
               AND PD.DropID    = @cFromDropID      
               AND PD.StorerKey = @cStorerKey    
               AND PD.SKU       = @cPackSKU  
                 
               UPDATE PD      
               SET Qty = Qty + @nQty  
               FROM dbo.PackDetail PD      
               WHERE PD.PickSlipNo = @cToPickSlipNo      
               AND PD.DropID    = @cToDropID      
               AND PD.StorerKey = @cStorerKey  
               AND PD.SKU       = @cPackSKU   
                   
               IF @@ERROR <> 0     
               BEGIN    
                  SET @nErrNo = 92501      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail      
                  GOTO RollBackTran    
               END      
                 
               DELETE FROM dbo.PackDetail WITH (ROWLOCK)   
               WHERE PickSlipNo = @cToPickSlipNo      
               AND DropID    = @cFromDropID      
               AND StorerKey = @cStorerKey    
               AND SKU       = @cPackSKU  
                 
               IF @@ERROR <> 0     
               BEGIN    
                  SET @nErrNo = 92502      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail      
                  GOTO RollBackTran    
               END    
                 
                 
              
              
         END  
         ELSE  
         BEGIN  
            --SET @nToCartonNo = 0  
            SELECT TOP 1    
               @nToCartonNo    = ISNULL(CartonNo,0),    
               @cToLabelLineNo = LabelLine  
            FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE PickSlipNo  = @cToPickSlipNo    
              AND DropID      = @cToDropID    
            ORDER BY CartonNo DESC    
           
            SET @cToLabelLineNo  = @cToLabelLineNo + 1  
              
            UPDATE PD    
            SET LabelNo = @cToDropID,    
                DropID  = @cToDropID,    
                CartonNo = @nToCartonNo,  
                LabelLine = RIGHT('00000' + CAST(@cToLabelLineNo AS VARCHAR(5)), 5),  
                ArchiveCop = NULL    
            FROM dbo.PackDetail PD    
            WHERE PD.PickSlipNo = @cToPickSlipNo    
            AND PD.DropID    = @cFromDropID    
            AND PD.StorerKey = @cStorerKey   
            AND PD.SKU       = @cPackSKU  
              
            IF @@ERROR <> 0     
            BEGIN    
               SET @nErrNo = 92503     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail      
               GOTO RollBackTran    
            END    
              
              
              
         END  
           
         UPDATE dbo.PickDetail WITH (ROWLOCK)   
         SET CaseID = @cToDropID  
            ,Trafficcop = NULL  
         WHERE StorerKey   = @cStorerKey  
         AND OrderKey      = @cOrderKey  
         AND CaseID        = @cFromDropID  
         AND SKU           = @cPackSKU  
           
           
         IF @@ERROR <> 0     
         BEGIN    
            SET @nErrNo = 92504      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDetFail      
            GOTO RollBackTran    
         END   
           
      FETCH NEXT FROM Cur_OffSet_PackDetail INTO @cPackSKU  
        
        
        
   END  
   CLOSE Cur_OffSet_PackDetail    
   DEALLOCATE Cur_OffSet_PackDetail    
     
     
     
     
  
   GOTO QUIT   
     
RollBackTran:  
   ROLLBACK TRAN rdt_525ExtUpdSP01 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_525ExtUpdSP01  
    
  
END    

GO