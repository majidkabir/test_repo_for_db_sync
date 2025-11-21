SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_533ExtMoveSP03                                  */  
/* Copyright      : MAERSK                                              */  
/*                                                                      */  
/* Purpose: Move by PackDetail.DropID                                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date       Rev  Author   Purposes                                    */  
/* 2023-09-05 1.0  James    WMS-23509 - Created                         */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_533ExtMoveSP03] (  
   @nMobile      INT,  
   @nFunc        INT,   
   @cLangCode    NVARCHAR( 3),   
   @cUserName    NVARCHAR( 18),   
   @cFacility    NVARCHAR( 5),   
   @cStorerKey   NVARCHAR( 15),  
   @cPickSlipNo  NVARCHAR( 10),  
   @cFromLabelNo NVARCHAR( 20),  
   @cToLabelNo   NVARCHAR( 20),  
   @cCartonType  NVARCHAR( 10),   
   @cSKU         NVARCHAR( 20),  
   @nQTY_Move    INT,  
   @nErrNo       INT          OUTPUT,  
   @cErrMsg      NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @nQTY           INT    
   DECLARE @nQty_Bal       INT    
   DECLARE @nTranCount     INT    
    
   DECLARE @nFromCartonNo  INT    
   DECLARE @cFromLabelLine NVARCHAR( 5)    
   DECLARE @cFromSKU       NVARCHAR( 20)    
   DECLARE @nFromQTY       INT    
    
   DECLARE @nToCartonNo    INT    
   DECLARE @cToLabelLine   NVARCHAR( 5)    
   DECLARE @cToDropID      NVARCHAR( 20)    
   DECLARE @cToRefNo       NVARCHAR( 20)    
   DECLARE @cToRefNo2      NVARCHAR( 30)    
   DECLARE @cToUPC         NVARCHAR( 30)    
   DECLARE @cActFromLabelNo   NVARCHAR( 20)    
   DECLARE @cActToLabelNo     NVARCHAR( 20)  
    
   DECLARE @cMoveByLabelNoUseDropID NVARCHAR( 1)    
   DECLARE @cPickDetailKey NVARCHAR( 18)    
   DECLARE @cToID          NVARCHAR( 18)    
   DECLARE @cFromID        NVARCHAR( 18)    
   DECLARE @cToLoc         NVARCHAR( 10)    
   DECLARE @cFromLoc       NVARCHAR( 10)    
   DECLARE @cPickDtlSKU    NVARCHAR( 20)  
   DECLARE @cLabelNo       NVARCHAR( 20)  
   DECLARE @nCartonNo      INT  
   DECLARE @nNewCartonNo   INT  
   DECLARE @curUpdPickDetail  CURSOR    
   DECLARE @curPackDtl        CURSOR  
   DECLARE @bSuccess          INT
   
   SET @nErrNo = 0    
   SET @cErrMsg = ''    
   SET @cToID = ''    
  
   SET @cMoveByLabelNoUseDropID = rdt.RDTGetConfig( @nFunc, 'MoveByLabelNoUseDropID', @cStorerKey)    
       
   SET @nQTY_Bal = @nQTY_Move    
    
   SET @nFromCartonNo = 0    
   SELECT @nFromCartonNo = PD.CartonNo     
   FROM dbo.PackDetail PD WITH (NOLOCK)     
   WHERE PD.PickSlipNo = @cPickSlipNo     
   AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo))    
    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_533ExtMoveSP03    
    
   -- Loop from PackDetail lines    
   DECLARE @curPD CURSOR    
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT PD.LabelNo, PD.LabelLine, PD.SKU, PD.QTY    
      FROM dbo.PackDetail PD WITH (NOLOCK)    
      WHERE PD.PickSlipNo = @cPickSlipNo    
         AND (( @cMoveByLabelNoUseDropID = '1' AND PD.DropID = @cFromLabelNo) OR ( PD.LabelNo = @cFromLabelNo))    
         AND PD.StorerKey = @cStorerKey    
         AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END    
   OPEN @curPD    
   FETCH NEXT FROM @curPD INTO @cActFromLabelNo, @cFromLabelLine, @cFromSKU, @nFromQTY    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      -- Calc QTY to move    
      IF @cSKU = '' -- Merge carton    
         SET @nQTY = @nFromQTY     
      ELSE    
      BEGIN    
         -- Merge by SKU    
         IF @nQTY_Bal > @nFromQTY    
            SET @nQTY = @nFromQTY    
         ELSE    
            SET @nQTY = @nQTY_Bal    
    
         SET @nQTY_Bal = @nQTY_Bal - @nQTY    
      END    
    
      -- Find TO PackDetail line    
      SET @nToCartonNo = 0    
      SET @cToLabelLine = ''    
      SET @cActToLabelNo = ''    
      SET @cToDropID = ''    
      SET @cToRefNo = ''    
      SET @cToRefNo2 = ''    
      SET @cToUPC = ''    
    
      SELECT    
         @cActToLabelNo = LabelNo,    
         @nToCartonNo = CartonNo,     
         @cToLabelLine = LabelLine,     
         @cToDropID = DropID,     
         @cToRefNo = RefNo,     
         @cToRefNo2 = RefNo2,     
         @cToUPC = UPC    
      FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
         AND (( @cMoveByLabelNoUseDropID = '1' AND DropID = @cToLabelNo) OR ( LabelNo = @cToLabelNo))    
         AND StorerKey = @cStorerKey    
         AND SKU = @cFromSKU    
             
      -- TO PackDetail line    
      -- Add new SKU to existing carton    
      IF @cActToLabelNo = ''    
      BEGIN    
         SELECT    
            @cActToLabelNo = LabelNo,    
            @nToCartonNo = CartonNo,     
            @cToLabelLine = LabelLine,     
            @cToDropID = DropID,     
            @cToRefNo = RefNo,     
            @cToRefNo2 = RefNo2,     
            @cToUPC = UPC    
         FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
            AND (( @cMoveByLabelNoUseDropID = '1' AND DropID = @cToLabelNo) OR ( LabelNo = @cToLabelNo))    
            AND StorerKey = @cStorerKey    
         
         -- No to packdetail line found, create new line
         IF @cActToLabelNo = ''
         BEGIN
         	SET @nToCartonNo = 0
            SET @cToLabelLine = '00000'
            
            -- Get new LabelNo    
            EXECUTE isp_GenUCCLabelNo    
               @cStorerKey = @cStorerKey,    
               @cLabelNo   = @cActToLabelNo OUTPUT,    
               @b_success  = @bSuccess      OUTPUT,    
               @n_err      = @nErrNo        OUTPUT,    
               @c_errmsg   = @cErrMsg       OUTPUT    
        
            IF @cMoveByLabelNoUseDropID = '1'
               SET @cToDropID = @cToLabelNo
            ELSE
            	SET @cToDropID = @cActToLabelNo

            SELECT    
               @cToRefNo = RefNo,     
               @cToRefNo2 = RefNo2,     
               @cToUPC = UPC    
            FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE PickSlipNo = @cPickSlipNo    
               AND (( @cMoveByLabelNoUseDropID = '1' AND DropID = @cFromLabelNo) OR ( LabelNo = @cFromLabelNo))    
               AND StorerKey = @cStorerKey   
         END
         ELSE
            -- Get max LabelLine    
            SELECT @cToLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)    
            FROM dbo.PackDetail (NOLOCK)    
            WHERE Pickslipno = @cPickSlipNo    
               AND CartonNo = @nToCartonNo    
  
         -- Insert PackDetail    
         INSERT INTO dbo.PackDetail    
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID, RefNo, RefNo2, UPC)    
         VALUES    
            (@cPickSlipNo, @nToCartonNo, @cActToLabelNo, @cToLabelLine, @cStorerKey, @cFromSKU, @nQTY,     
            LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE(),     
            LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE(),    
            @cToDropID, @cToRefNo, @cToRefNo2, @cToUPC)    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 206001    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'    
            GOTO RollBackTran    
         END    
      END    
      ELSE    
      BEGIN    
         -- Top up to existing carton and SKU    
         UPDATE dbo.PackDetail SET    
            QTY = QTY + @nQTY,    
            EditWho = LEFT( 'rdt.' + SUSER_SNAME(), 18),    
            EditDate = GETDATE(),     
            ArchiveCop = NULL    
         WHERE PickSlipNo = @cPickSlipNo    
            AND CartonNo = @nToCartonNo    
            AND LabelNo = @cActToLabelNo    
            AND LabelLine = @cToLabelLine    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 206002    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail    
            GOTO RollBackTran    
         END    
      END    
    
      -- FROM PackDetail line    
      IF @nFromQTY = @nQTY    
      BEGIN    
         -- Delete PackDetail    
         DELETE PackDetail    
         WHERE PickSlipNo = @cPickSlipNo    
            AND CartonNo = @nFromCartonNo    
            AND (( @cMoveByLabelNoUseDropID = '1' AND DropID = @cFromLabelNo) OR ( LabelNo = @cFromLabelNo))    
            AND LabelLine = @cFromLabelLine    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 206003    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail    
            GOTO RollBackTran    
         END    
      END    
      ELSE    
      BEGIN    
         -- Update PackDetail    
       UPDATE PackDetail SET    
            QTY = QTY - @nQTY,     
            EditWho = LEFT( 'rdt.' + SUSER_SNAME(), 18),     
            EditDate = GETDATE(),     
            ArchiveCop = NULL    
         WHERE PickSlipNo = @cPickSlipNo    
            AND CartonNo = @nFromCartonNo    
            AND (( @cMoveByLabelNoUseDropID = '1' AND DropID = @cFromLabelNo) OR ( LabelNo = @cFromLabelNo))    
            AND LabelLine = @cFromLabelLine    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 206004    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail    
            GOTO RollBackTran    
         END    
      END    
    
      FETCH NEXT FROM @curPD INTO @cActFromLabelNo, @cFromLabelLine, @cFromSKU, @nFromQTY    
   END    
   CLOSE @curPD    
   DEALLOCATE @curPD    
    
   -- Check if fully offset (when by SKU)    
   IF @cSKU <> '' AND @nQty_Bal <> 0    
   BEGIN    
      SET @nErrNo = 206005    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OffsetError    
      GOTO RollBackTran    
   END    
    
    
/*--------------------------------------------------------------------------------------------------    
    
                                             PackInfo    
    
--------------------------------------------------------------------------------------------------*/    
   DECLARE @nCartonWeight FLOAT    
   DECLARE @nCartonCube   FLOAT    
    
   SET @nToCartonNo = 0    
   SELECT @nToCartonNo   = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cActToLabelNo    
    
   -- From carton    
   IF EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nFromCartonNo)    
   BEGIN    
      -- Recalc from carton's weight, cube    
      SELECT    
         @nCartonWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0),    
         @nCartonCube   = ISNULL( SUM( PD.QTY * SKU.STDCube), 0)    
      FROM dbo.PackDetail PD WITH (NOLOCK)    
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
      WHERE PD.PickSlipNo = @cPickSlipNo    
         AND PD.CartonNo = @nFromCartonNo    
    
      -- Update PackInfo    
      UPDATE dbo.PackInfo SET    
         Weight = @nCartonWeight,    
         Cube = @nCartonCube    
      WHERE PickSlipNo = @cPickSlipNo    
         AND CartonNo = @nFromCartonNo    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 206006    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKInfoFail    
         GOTO RollBackTran    
      END    
   END    
   ELSE    
   BEGIN    
      DELETE dbo.PackInfo WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nFromCartonNo    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 206007    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPKInfoFail    
         GOTO RollBackTran    
      END    
   END    
    
   -- Calc To carton's weight, cube    
   SELECT    
      @nCartonWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0),    
      @nCartonCube   = ISNULL( SUM( PD.QTY * SKU.STDCube), 0)    
   FROM dbo.PackDetail PD WITH (NOLOCK)    
      INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)    
   WHERE PD.PickSlipNo = @cPickSlipNo    
      AND PD.CartonNo = @nToCartonNo    
    
   -- To carton    
   IF NOT EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nToCartonNo)    
   BEGIN    
      INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube, CartonType)    
      VALUES ( @cPickSlipNo, @nToCartonNo, @nCartonWeight, @nCartonCube, @cCartonType)    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 206008    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail    
         GOTO RollBackTran    
      END    
   END    
   ELSE    
   BEGIN    
      UPDATE dbo.PackInfo SET    
         Weight = @nCartonWeight,    
         Cube = @nCartonCube    
      WHERE PickSlipNo = @cPickSlipNo    
         AND CartonNo = @nToCartonNo    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 206009    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKInfoFail    
         GOTO RollBackTran    
      END    
   END    
     
   -- Update pickdetail.caseid = packdetail.labelno here  
   SET @curUpdPickDetail = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
   SELECT PICKD.PickDetailKey      
         ,PICKD.ID      
         ,PICKD.SKU      
         ,PICKD.QTy      
         ,PICKD.Loc      
   FROM dbo.Pickdetail PICKD WITH (NOLOCK)       
   WHERE PICKD.StorerKey = @cStorerKey      
   AND PICKD.Status <= '5'      
   AND PICKD.CaseID = @cActFromLabelNo  
   AND PICKD.PickSlipNo = @cPickSlipNo  
   ORDER BY PICKD.PickDetailKey      
   OPEN @curUpdPickDetail              
   FETCH NEXT FROM @curUpdPickDetail INTO  @cPickDetailKey, @cFromID, @cPickDtlSKU, @nQty, @cFromLoc      
   WHILE (@@FETCH_STATUS <> -1)              
   BEGIN              
      SELECT @cToID = PICKD.ID ,      
             @cToLoc = PICKD.Loc  
      FROM dbo.PickDetail PICKD WITH (NOLOCK)       
      WHERE PICKD.StorerKey = @cStorerKey      
      AND PICKD.Status <= '5'      
      AND PICKD.CaseID = @cActToLabelNo  
      AND PICKD.PickSlipNo = @cPickSlipNo  
          
      IF @cToID <> @cFromID       
      BEGIN      
         -- ID not same , need to move PickDetail ID as well.      
         EXECUTE rdt.rdt_Move          
            @nMobile     = @nMobile,          
            @cLangCode   = @cLangCode,          
            @nErrNo      = @nErrNo  OUTPUT,          
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max          
            @cSourceType = 'rdt_533ExtMoveSP03',          
            @cStorerKey  = @cStorerKey,          
            @cFacility   = @cFacility,          
            @cFromLOC    = @cFromLOC,          
            @cToLOC      = @cToLOC,          
            @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID          
            @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID          
            @cSKU        = @cSKU,          
            @nQTY        = @nQTY,         
            @nFunc       = @nFunc      
               
         IF @nErrNo <> 0       
            GOTO RollBackTran        
      END      
  
      UPDATE dbo.PickDetail SET       
            CaseID = @cActToLabelNo      
            ,EditWho = @cUserName      
            ,EditDate = GetDate()      
            ,Trafficcop = NULL      
      WHERE PickDetailKey = @cPickDetailKey       
      
      IF @@ERROR <> 0        
      BEGIN        
         SET @nErrNo = 206010        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'        
         GOTO RollBackTran        
      END        
  
      FETCH NEXT FROM @curUpdPickDetail INTO  @cPickDetailKey, @cFromID, @cPickDtlSKU, @nQty, @cFromLoc      
   END      
  
   --Rearrange carton no  
   SET @nNewCartonNo = 1  
   SET @curPackDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
   SELECT DISTINCT CartonNo, LabelNo  
   FROM dbo.PackDetail WITH (NOLOCK)  
   WHERE PickSlipNo = @cPickSlipNo  
   ORDER BY CartonNo  
   OPEN @curPackDtl  
   FETCH NEXT FROM @curPackDtl INTO @nCartonNo, @cLabelNo  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      UPDATE dbo.PackDetail WITH (ROWLOCK) SET  
         CartonNo = @nNewCartonNo  
      WHERE PickSlipNo = @cPickSlipNo  
      AND   CartonNo = @nCartonNo  
      AND   LabelNo = @cLabelNo  
        
      IF @@ERROR <> 0  
      BEGIN        
         SET @nErrNo = 206011        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'        
         GOTO RollBackTran        
      END   
        
      SET @nNewCartonNo = @nNewCartonNo + 1  
  
      FETCH NEXT FROM @curPackDtl INTO @nCartonNo, @cLabelNo  
   END  
     
   COMMIT TRAN rdt_533ExtMoveSP03 -- Only commit change made in rdt_533ExtMoveSP03    
   GOTO Quit    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_533ExtMoveSP03 -- Only rollback change made in rdt_533ExtMoveSP03    
   Quit:    
      -- Commit until the level we started    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
Fail:    
END    

GO