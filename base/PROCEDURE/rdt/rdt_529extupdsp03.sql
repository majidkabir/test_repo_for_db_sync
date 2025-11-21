SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_529ExtUpdSP03                                   */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2015-01-18  1.0  ChewKP   Created SOS#359841                         */ 
/* 2017-06-06  1.1  ChewKP   WMS-2116 Allow Conso Packed item(ChewKP01) */   
/* 2020-07-16  1.1  Chermaine WMS-14164 Auto Cal Weight when combine(cc01)*/  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_529ExtUpdSP03] (    
   @nMobile     INT,    
   @nFunc       INT,    
   @cLangCode  NVARCHAR( 3),    
   @cUserName   NVARCHAR( 15),    
   @cFacility   NVARCHAR( 5),    
   @cStorerKey  NVARCHAR( 15),    
   @cPickSlipNo NVARCHAR( 10),    
   @cFromDropID NVARCHAR( 20),    
   @cToDropID   NVARCHAR( 20),    
   @cSKU        NVARCHAR( 20),    
   @nQTY_Move   INT,    
   @nErrNo      INT          OUTPUT,    
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @nQTY            INT    
   DECLARE @nTranCount      INT    
   DECLARE @nRowCount       INT    
   DECLARE @nEventLogQTY    INT    
    
   DECLARE @nFromCartonNo   INT    
   DECLARE @cFromLabelNo    NVARCHAR( 20)    
   DECLARE @cFromLabelLine  NVARCHAR( 5)    
   DECLARE @cFromSKU        NVARCHAR( 20)    
   DECLARE @nFromQTY        INT    
    
   DECLARE @nToCartonNo     INT    
   DECLARE @cToLabelNo      NVARCHAR( 20)    
   DECLARE @cToLabelLineNo  NVARCHAR( 5)    
   DECLARE @cPackSKU        NVARCHAR( 20)    
   DECLARE @nTraceFlag      INT 
          ,@cPickDetailKey  NVARCHAR(10) 
          ,@cDataWindow     NVARCHAR( 50)  
          ,@nStep           INT
          ,@cFromOrderKey   NVARCHAR(10) 
          ,@cToOrderKey     NVARCHAR(10)
          ,@cFromCaseID     NVARCHAR(20)
          ,@cToCaseID       NVARCHAR(20) 
          ,@cToPickSlipNo   NVARCHAR(10)
          ,@cFromPickSlipNo NVARCHAR(10)
          ,@cPDSKU          NVARCHAR(20)
          ,@cLabelNo        NVARCHAR(20)
          ,@cLabelLine      NVARCHAR(5) 
          ,@nCartonNo       INT
          ,@cLabelPrinter   NVARCHAR(10) 
          ,@cMaxLabelLine   NVARCHAR(5) 


   DECLARE @cTargetDB     NVARCHAR( 20)    
    
   SET @nErrNo = 0    
   SET @cErrMsg = ''    
   SET @cPackSKU = ''    
   SET @nTraceFlag = 0    
   
   SELECT @nStep = Step
         ,@cLabelPrinter = Printer
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   

   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_529ExtUpdSP03    
      
   IF @nStep IN ( 2 ,3 ) 
   BEGIN 
    
      -- Calc QTY for event log    
      SET @nEventLogQTY = 0    
      IF @cSKU = ''    
         SELECT @nEventLogQTY = SUM( QTY)    
         FROM dbo.PickDetail PD WITH (NOLOCK)    
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey 
         WHERE PD.DropID    = @cFromDropID    
            AND PD.StorerKey = @cStorerKey    
            AND PD.Status    = '5'
      ELSE    
         SET @nEventLogQTY = @nQTY_Move    
       
      
       
      
      
      -- If Carton to Carton Move, which is SKU = BLANK    
      -- Just update the UCC Label Number. The rest of the information remain  
      SELECT
           @cFromOrderKey = OrderKey 
          ,@cFromCaseID   = CaseID
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.DropID = @cFromDropID
         AND Status = '5'
      
      SELECT
          @cToOrderKey = OrderKey 
         ,@cToCaseID  = CaseID
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.DropID = @cToDropID     
         AND Status = '5'
      
   --   SELECT @cFromPickSlipNo = PickSlipNo 
   --   FROM dbo.PackHeader WITH (NOLOCK) 
   --   WHERE StorerKey = @cStorerKey
   --   AND OrderKey = @cFromOrderKey
   
      
        
      IF ISNULL(RTRIM(@cSKU),'') = ''  AND @nStep = 2   
      BEGIN    
         
         

         DECLARE Cur_Update_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PD.PickDetailKey    
         FROM   dbo.PICKDETAIL PD WITH (NOLOCK)    
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey 
         WHERE PD.DropID     = @cFromDropID    
           AND PD.StorerKey  = @cStorerKey    
           AND PD.Status     = '5'    
         ORDER BY PD.PickDetailKey 
       
         OPEN Cur_Update_PickDetail    
         FETCH NEXT FROM Cur_Update_PickDetail INTO @cPickDetailKey 
       
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            
            UPDATE dbo.PICKDETAIL WITH (ROWLOCK)    
               SET DropID = @cToDropID,    
                   CaseID = CASE WHEN ISNULL(CaseID, '' )  = '' THEN CaseID ELSE @cToDropID END,
                   TrafficCop = NULL    
            WHERE PickDetailKey = @cPickDetailKey    
       
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 95752    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail    
               GOTO RollBackTran  
            END
            
            FETCH NEXT FROM Cur_Update_PickDetail INTO @cPickDetailKey    
         END    
         CLOSE Cur_Update_PickDetail    
         DEALLOCATE Cur_Update_PickDetail    
         
         
         IF ISNULL(@cFromCaseID,'' )  <> '' 
         BEGIN
         	--get fromDropID weight --(cc01)
            DECLARE @nFrCartonWeight FLOAT
            DECLARE @nToCartonWeight FLOAT
         
            SELECT @nFromCartonNo = CartonNo    
            FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE PickSlipNo = @cPickSlipNo AND DropID = @cFromDropID  
         
    
            IF EXISTS (SELECT 1 FROM packInfo WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo AND cartonNo = @nFromCartonNo)
            BEGIN
         	   SELECT @nFrCartonWeight = WEIGHT FROM packInfo WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo AND cartonNo = @nFromCartonNo
            END
            ELSE
            BEGIN
         	   SELECT    
                  @nFrCartonWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0) 
               FROM dbo.PackDetail PD WITH (NOLOCK)    
                  INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
               WHERE PD.PickSlipNo = @cPickSlipNo    
                  AND PD.CartonNo = @nFromCartonNo
            END
            

            --SELECT @cToPickSlipNo = ISNULL(PickSlipNo ,'' ) 
            --FROM dbo.PackHeader WITH (NOLOCK) 
            --WHERE StorerKey = @cStorerKey
            --AND OrderKey = @cToOrderKey
            

            

            SET @nFromCartonNo = 0 

            DECLARE Cur_Update_PackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT PD.PickSlipNo, PD.LabelNo, PD.LabelLine, PD.CartonNo, PD.SKU, PD.Qty  
            FROM   dbo.PackDetail PD WITH (NOLOCK)    
            WHERE PD.DropID     = @cFromDropID    
              AND PD.StorerKey  = @cStorerKey    
            ORDER BY PD.PickSlipNo, PD.CartonNo, PD.LabelNo
          
            OPEN Cur_Update_PackDetail    
            FETCH NEXT FROM Cur_Update_PackDetail INTO @cFromPickSlipNo, @cLabelNo, @cLabelLine, @nCartonNo, @cPDSKU, @nQty 
          
            WHILE @@FETCH_STATUS <> -1    
            BEGIN    
               
               
               

               IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                               WHERE StorerKey = @cStorerKey 
                               AND PickSlipNo = @cFromPickSlipNo
                               AND SKU = @cPDSKU 
                               AND LabelNo = @cToDropID ) 
               BEGIN
                  

                  SELECT Top 1 @nToCartonNo = CartonNo
                              ,@cMaxLabelLine = LabelLine
                  FROM dbo.PackDetail WITH (NOLOCK) 
                  WHERE PickSlipNo = @cFromPickSlipNo
                  AND DropID = @cToDropID
                  Order by LabelLine DESC

                  --SELECT @cMaxLabelLine '@cMaxLabelLine'

                  

                  UPDATE dbo.PackDetail  WITH (ROWLOCK)    
                     SET LabelNo = @cToDropID
                        ,LabelLine = RIGHT('00000' + CAST(@cMaxLabelLine + 1  AS VARCHAR(5)), 5)
                        ,CartonNo = @nToCartonNo 
                        ,DropID   = @cToDropID 
                  WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cFromPickSlipNo 
                  AND SKU = @cPDSKU
                  AND LabelNo = @cFromDropID  
             
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 95753    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail    
                     GOTO RollBackTran  
                  END

                  

               END
               ELSE
               BEGIN
                  
                  UPDATE dbo.PackDetail WITH (ROWLOCK) 
                  SET Qty = Qty + @nQty 
                  WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cFromPickSlipNo 
                  AND SKU = @cPDSKU
                  AND LabelNo = @cToDropID 
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 95754    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail    
                     GOTO RollBackTran  
                  END
                  
                  DELETE FROM dbo.PackDetail WITH (ROWLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cFromPickSlipNo 
                  AND SKU = @cPDSKU
                  AND LabelNo = @cFromDropID 
                  AND LabelLine = @cLabelLine
                  AND Qty = @nQty 
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 95755    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail    
                     GOTO RollBackTran  
                  END
                  

                  --SELECT @cStorerKey '@cStorerKey' , @cFromPickSlipNo '@cFromPickSlipNo' , @nCartonNo '@nCartonNo' , @cFromDropID '@cFromDropID' , @nFromCartonNo '@nFromCartonNo' 

                  
                  
               END
               
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                             WHERE StorerKey = @cStorerKey
                             AND PickSlipNo = @cFromPickSlipNo 
                             AND CartonNo = @nCartonNo 
                             AND LabelNo = @cFromDropID)
               BEGIN
                  

                  DELETE FROM dbo.PackInfo WITH (ROWLOCK) 
                  WHERE PickSlipNo = @cFromPickSlipNo 
                  AND CartonNo = @nCartonNo 
                  
                  IF @@ERROR <> 0 
                  BEGIN
                     SET @nErrNo = 95755    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail    
                     GOTO RollBackTran  
                  END
                  
               END
               
               
               FETCH NEXT FROM Cur_Update_PackDetail INTO @cFromPickSlipNo, @cLabelNo, @cLabelLine, @nCartonNo, @cPDSKU, @nQty 
            END    
            CLOSE Cur_Update_PackDetail    
            DEALLOCATE Cur_Update_PackDetail   
            
            -- get toDropID weight then add fromDropID weight + toDropID weight -0.5   --(cc01)
            SELECT @nToCartonNo = CartonNo    
            FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE PickSlipNo = @cPickSlipNo AND DropID = @cToDropID  
   
            IF EXISTS (SELECT 1 FROM packInfo WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo AND cartonNo = @nToCartonNo)
            BEGIN
         	   SELECT @nToCartonWeight = WEIGHT FROM packInfo WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo AND cartonNo = @nToCartonNo
         	
         	   UPDATE packInfo WITH (ROWLOCK) SET
         	   WEIGHT = @nFrCartonWeight + @nToCartonWeight - 0.5
         	   WHERE pickslipNo = @cPickSlipNo
         	   AND cartonNo = @nToCartonNo
         	   IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 95756    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKInfoFail   
                  GOTO RollBackTran    
               END   
            END
            ELSE
            BEGIN
         	   SELECT    
                  @nToCartonWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0) 
               FROM dbo.PackDetail PD WITH (NOLOCK)    
                  INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
               WHERE PD.PickSlipNo = @cPickSlipNo    
                  AND PD.CartonNo = @nToCartonNo
               
               INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight)    
               VALUES ( @cPickSlipNo, @nToCartonNo, (@nFrCartonWeight + @nToCartonWeight - 0.5))    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 95757    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail     
                  GOTO RollBackTran    
               END   
            END
            
            
         END
         
         
         UPDATE dbo.DropID
         SET Status = '0' , PickSlipNo = '' , LoadKey = '' 
            ,Editdate = Getdate()
            ,EditWho = @cUserName
         WHERE DropID = @cFromDropID  
         
         --(cc01)
         EXEC RDT.rdt_STD_EventLog    
         @cActionType   = '4', -- Move    
         @cUserID       = @cUserName,    
         @nMobileNo     = @nMobile,    
         @nFunctionID   = @nFunc,    
         @cFacility     = @cFacility,    
         @cStorerKey    = @cStorerKey,    
         @cID           = @cFromDropID,    
         @cToID         = @cToDropID,
         @cRemark       = 'Combine'
         
         

       
      END    
      ELSE IF ISNULL(@cFromCaseID,'')  = ''  AND @nStep = 3 
      BEGIN    
             
         DECLARE Cur_Update_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PD.PickDetailKey    
         FROM   dbo.PICKDETAIL PD WITH (NOLOCK)    
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey 
         WHERE PD.DropID     = @cFromDropID    
           AND PD.StorerKey  = @cStorerKey    
           AND PD.SKU        = @cSKU    
           AND PD.Status     = '5'    
         ORDER BY PD.PickDetailKey 
                
         OPEN Cur_Update_PickDetail    
         FETCH NEXT FROM Cur_Update_PickDetail INTO @cPickDetailKey
       
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            
       
            UPDATE dbo.PICKDETAIL WITH (ROWLOCK)    
               SET DropID = @cToDropID,    
                   TrafficCop = NULL    
            WHERE PickDetailKey = @cPickDetailKey    
       
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 95751    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail    
               GOTO RollBackTran  
            END
            
       
            FETCH NEXT FROM Cur_Update_PickDetail INTO @cPickDetailKey
       
         END    
         CLOSE Cur_Update_PickDetail    
         DEALLOCATE Cur_Update_PickDetail    
       
      END -- UPDATE    
      
   
   END
   
   IF @nStep = 4
   BEGIN
      
      SELECT
          @cToOrderKey = OrderKey 
         ,@cToCaseID  = CaseID
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.StorerKey = @cStorerKey
         AND PD.DropID = @cToDropID     
         AND Status = '5'
      
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND OrderKey = @cToOrderKey 
      
      SELECT Top 1 @nCartonNo = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickslipNo = @cPickSlipNo
      AND StorerKey = @cStorerKey 
      AND DropID = @cToDropID
      
         
      SELECT @cDataWindow = DataWindow,     
             @cTargetDB = TargetDB     
      FROM rdt.rdtReport WITH (NOLOCK)     
      WHERE StorerKey = @cStorerKey    
      AND   ReportType = 'CARTONLBL'    
      
            
      EXEC RDT.rdt_BuiltPrintJob      
                   @nMobile,      
                   @cStorerKey,      
                   'CARTONLBL',      -- ReportType      
                   'CartonLabel',    -- PrintJobName      
                   @cDataWindow,      
                   @cLabelPrinter,      
                   @cTargetDB,      
                   @cLangCode,      
                   @nErrNo  OUTPUT,      
                   @cErrMsg OUTPUT,    
                   @cStorerKey,   
                   @cPickSlipNo, 
                   @nCartonNo,
                   @nCartonNo 
   END
    
    
   COMMIT TRAN rdt_529ExtUpdSP03 -- Only commit change made in rdt_529ExtUpdSP03    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_529ExtUpdSP03 -- Only rollback change made in rdt_529ExtUpdSP03    
Quit:    
   -- Commit until the level we started    
   WHILE @@TRANCOUNT > @nTranCount    
      COMMIT TRAN    
Fail:    
END

GO