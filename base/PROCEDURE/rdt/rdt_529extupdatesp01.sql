SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_529ExtUpdateSP01                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Split PackDetail for ANF Project  SOS#302191                */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2014-02-11  1.0  ChewKP   Created                                    */    
/* 2014-11-27  1.1  ChewKP   SOS#324966 - Fixes (ChewKP01)              */    
/* 2014-12-15       Leong    SOS#327275 - Add TraceInfo (Temp Only)     */  
/* 2017-06-06  1.2  ChewKP   WMS-2116 Add @nStep checking (ChewKP02)    */   
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_529ExtUpdateSP01] (    
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
   DECLARE @nTraceFlag      INT -- SOS# 327275    
          ,@nStep           INT
    
   SET @nErrNo = 0    
   SET @cErrMsg = ''    
   SET @cPackSKU = ''    
   SET @nTraceFlag = 0    
    
   -- Calc QTY for event log    
   SET @nEventLogQTY = 0    
   IF @cSKU = ''    
      SELECT @nEventLogQTY = SUM( QTY)    
      FROM dbo.PackDetail PD WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
         AND DropID    = @cFromDropID    
         AND StorerKey = @cStorerKey    
   ELSE    
      SET @nEventLogQTY = @nQTY_Move    
    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_529ExtUpdateSP01    
   
   SELECT @nStep = Step
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   -- (ChewKP02) 
   IF @nStep IN ( 2, 3 ) 
   BEGIN  
      SET @nToCartonNo = 0    
      SELECT TOP 1    
         @nToCartonNo = ISNULL(CartonNo,0),    
         @cToLabelNo = LabelNo ,    
         @cToLabelLineNo = LabelLine    
      FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
        AND DropID = @cToDropID    
      ORDER BY CartonNo DESC    
       
      SELECT TOP 1    
         @cFromLabelNo = LabelNo    
      FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE PickSlipNo = @cPickSlipNo    
        AND DropID = @cFromDropID    
      ORDER BY CartonNo DESC    
       
      IF ISNULL(@cToLabelNo,'') = '' -- (ChewKP01)    
      BEGIN    
         SET @nErrNo = 84951    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToLabelReq'    
         GOTO RollBackTran    
      END    
       
      IF ISNULL(@cFromLabelNo,'' )  = '' -- (ChewKP01)    
      BEGIN    
         SET @nErrNo = 84952    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FromLabelReq'    
         GOTO RollBackTran    
      END    
       
      IF ISNULL(RTRIM(@cStorerKey),'') = 'ANF' AND @nTraceFlag = 1    
      BEGIN    
         INSERT dbo.TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5    
                              , Col1, Col2, Col3, Col4, Col5, TotalTime)    
         VALUES ('rdt_529ExtUpdateSP01', GETDATE(), @cPickSlipNo, @cToDropID, @cFromDropID, @nToCartonNo, @cToLabelNo    
        , @cToLabelLineNo, @cFromLabelNo,'','','-1-', @nMobile)    
      END    
       
      -- If Carton to Carton Move, which is SKU = BLANK    
      -- Just update the UCC Label Number. The rest of the information remain    
      IF ISNULL(RTRIM(@cSKU),'') = ''    
      BEGIN    
       
         DECLARE Cur_OffSet_PackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT DISTINCT PD.SKU    
            FROM dbo.PackDetail PD WITH (NOLOCK)    
            WHERE PD.PickSlipNo = @cPickSlipNo    
            AND PD.DropID    = @cFromDropID    
            AND PD.StorerKey = @cStorerKey    
            ORDER BY PD.SKU    
       
         OPEN Cur_OffSet_PackDetail    
         FETCH NEXT FROM Cur_OffSet_PackDetail INTO @cPackSKU    
       
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
       
            IF ISNULL(RTRIM(@cStorerKey),'') = 'ANF' AND @nTraceFlag = 1    
            BEGIN    
               INSERT dbo.TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5    
                                    , Col1, Col2, Col3, Col4, Col5, TotalTime)    
               SELECT 'rdt_529ExtUpdateSP01', GETDATE(), PickSlipNo, DropID, 'To', SKU, ''    
                      ,'', '','','','-2-', @nMobile    
               FROM PackDetail WITH (NOLOCK)    
               WHERE PickSlipNo = @cPickSlipNo    
               AND DropID    = @cToDropID    
               AND StorerKey = @cStorerKey    
               AND SKU       = @cPackSKU    
            END    
       
               IF EXISTS ( SELECT 1 FROM dbo.PACKDETAIL PD WITH (NOLOCK)    
                           WHERE PD.PickSlipNo = @cPickSlipNo    
                           AND PD.DropID    = @cToDropID    
                           AND PD.StorerKey = @cStorerKey    
                           AND PD.SKU       = @cPackSKU )    
               BEGIN    
                  
                  SELECT @nQty = SUM(Qty) 
                  FROM dbo.PackDetail PD    
                  WHERE PD.PickSlipNo = @cPickSlipNo    
                  AND PD.DropID    = @cFromDropID    
                  AND PD.StorerKey = @cStorerKey  
                  AND PD.SKU       = @cPackSKU
                  
                  UPDATE PD    
                  SET Qty = Qty + @nQty
                  FROM dbo.PackDetail PD    
                  WHERE PD.PickSlipNo = @cPickSlipNo    
                  AND PD.DropID    = @cToDropID    
                  AND PD.StorerKey = @cStorerKey
                  AND PD.SKU       = @cPackSKU 
                    
                  IF @@ERROR <> 0   
                  BEGIN  
                     SET @nErrNo = 84961    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail    
                     GOTO RollBackTran  
                  END    
                  
                  DELETE FROM dbo.PackDetail WITH (ROWLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo    
                  AND DropID    = @cFromDropID    
                  AND StorerKey = @cStorerKey  
                  AND SKU       = @cPackSKU
                  
                  IF @@ERROR <> 0   
                  BEGIN  
                     SET @nErrNo = 84962    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail    
                     GOTO RollBackTran  
                  END    
     
               END    
               ELSE    
               BEGIN    
                  IF ISNULL(RTRIM(@cStorerKey),'') = 'ANF' AND @nTraceFlag = 1    
                  BEGIN    
                     INSERT dbo.TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5    
                                          , Col1, Col2, Col3, Col4, Col5, TotalTime)    
                     SELECT 'rdt_529ExtUpdateSP01', GETDATE(), PickSlipNo, DropID, 'From', SKU, ''    
                            , '', '','','','-3-', @nMobile    
                     FROM PackDetail WITH (NOLOCK)    
                     WHERE PickSlipNo = @cPickSlipNo    
                     AND DropID    = @cFromDropID    
                     AND StorerKey = @cStorerKey    
                     AND SKU       = @cPackSKU    
                  END    
       
                  --SET @nToCartonNo = 0    
                  SET @cToLabelLineNo  = @cToLabelLineNo + 1    
       
                  UPDATE PD    
                  SET LabelNo = @cToLabelNo,    
                      DropID  = @cToDropID,    
                      CartonNo = @nToCartonNo,    
                      LabelLine = RIGHT('00000' + CAST(@cToLabelLineNo AS VARCHAR(5)), 5),    
                      ArchiveCop = NULL    
                  FROM dbo.PackDetail PD    
                  WHERE PD.PickSlipNo = @cPickSlipNo    
                  AND PD.DropID    = @cFromDropID    
                  AND PD.StorerKey = @cStorerKey    
                  AND PD.SKU       = @cPackSKU    
     
                  IF @@ERROR <> 0   
                  BEGIN  
                     SET @nErrNo = 84952    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FromLabelReq'    
                     GOTO RollBackTran  
                  END    
       
               END    
            FETCH NEXT FROM Cur_OffSet_PackDetail INTO @cPackSKU    
         END    
         CLOSE Cur_OffSet_PackDetail    
         DEALLOCATE Cur_OffSet_PackDetail    
       
         -- Update PickDetail DropID    
         UPDATE PICKDETAIL WITH (ROWLOCK)    
         SET CaseID = @cToLabelNo,    
             DropID = @cToDropID,    
             TrafficCop = NULL    
         WHERE PickSlipNo = @cPickSlipNo    
           AND CaseID     = @cFromLabelNo    
           AND StorerKey  = @cStorerKey    
           AND Status     = '5'    
       
      END    
      ELSE    
      BEGIN    
         SELECT TOP 1    
               @nFromCartonNo = CartonNo,    
               @cFromLabelNo  = LabelNo,    
               @cFromLabelLine= LabelLine,    
               @cFromSKU      = SKU,    
               @nFromQTY      = QTY    
         FROM dbo.PackDetail PD WITH (NOLOCK)    
         WHERE PD.PickSlipNo = @cPickSlipNo    
            AND PD.DropID = @cFromDropID    
            AND PD.StorerKey = @cStorerKey    
            AND PD.SKU = @cSKU    
       
         IF @nQTY_Move > @nFromQTY    
            SET @nQTY = @nFromQTY    
         ELSE    
            SET @nQTY = @nQTY_Move    
       
       
       
         IF @nToCartonNo = 0    
         BEGIN    
   --         -- Give From Drop ID Carton# to To Drop ID    
       
       
            SET @nToCartonNo = 0    
            SET @cToLabelLineNo  = '00000'    
       
            -- Insert to PackDetail line    
       
            INSERT INTO dbo.PackDetail    
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY,    
                AddWho, AddDate, EditWho, EditDate, DropID)    
            VALUES    
               (@cPickSlipNo, @nToCartonNo, @cToLabelNo, @cToLabelLineNo, @cStorerKey, @cFromSKU, @nQTY,    
                'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToDropID)    
       
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 84953    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'    
               GOTO RollBackTran    
            END    
       
       
       
         END    
         ELSE    
         BEGIN    
       
            IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                        WHERE PickslipNo = @cPickSlipNo    
                        AND LabelNo = @cToLabelNo    
                        AND SKU = @cFromSKU )    
            BEGIN    
       
               -- Update TO PackDetail line    
               UPDATE dbo.PackDetail SET    
                  QTY = QTY + @nQTY,    
                  EditWho = 'rdt.' + sUser_sName(),    
                  EditDate = GETDATE()    
               WHERE PickSlipNo = @cPickSlipNo    
                  AND CartonNo = @nToCartonNo    
                  AND LabelNo = @cToLabelNo    
                  AND LabelLine = @cToLabelLineNo    
                  AND SKU       = @cFromSKU    
       
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 84954    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail    
                  GOTO RollBackTran    
               END    
            END    
            ELSE    
            BEGIN    
               --SET @nToCartonNo = 0    
               SELECT TOP 1    
                    @cToLabelLineNo = ISNULL(LabelLine,0)    
               FROM dbo.PackDetail WITH (NOLOCK)    
               WHERE PickSlipNo = @cPickSlipNo    
                 AND DropID = @cToDropID    
               ORDER BY CartonNo DESC    
       
               SET @cToLabelLineNo  = @cToLabelLineNo + 1    
       
               -- Insert to PackDetail line    
       
               INSERT INTO dbo.PackDetail    
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY,    
                   AddWho, AddDate, EditWho, EditDate, DropID)    
               VALUES    
                  (@cPickSlipNo, @nToCartonNo, @cToLabelNo, RIGHT('00000' + CAST(@cToLabelLineNo AS VARCHAR(5)), 5), @cStorerKey, @cFromSKU, @nQTY,    
                   'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToDropID)    
       
               IF @@ERROR <> 0    
           BEGIN    
                  SET @nErrNo = 84959    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'    
                  GOTO RollBackTran    
               END    
            END    
       
       
       
         END    
       
         IF @nQTY_Move > @nFromQTY    
            SET @nQTY = @nFromQTY    
         ELSE    
            SET @nQTY = @nQTY_Move    
       
       
       
       
       
         -- Update PackDetail - From DropID    
         UPDATE PackDetail SET    
            QTY = QTY - @nQTY    
         WHERE PickSlipNo = @cPickSlipNo    
            AND CartonNo = @nFromCartonNo    
            AND LabelNo = @cFromLabelNo    
            AND LabelLine = @cFromLabelLine    
       
       
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 84955    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail    
            GOTO RollBackTran    
         END    
       
         IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                     WHERE PickSlipNo = @cPickSlipNo    
                     AND CartonNo = @nFromCartonNo    
                     AND LabelNo = @cFromLabelNo    
                     AND LabelLine = @cFromLabelLine    
                     AND Qty <= 0  )    
         BEGIN    
            -- Delete PackDetail line when Pack Quantity =< 0    
            DELETE FROM dbo.PackDetail    
            WHERE PickSlipNo = @cPickSlipNo    
            AND CartonNo = @nFromCartonNo    
            AND LabelNo = @cFromLabelNo    
            AND LabelLine = @cFromLabelLine    
            AND Qty <= 0    
       
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 84956    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail    
               GOTO RollBackTran    
            END    
         END    
       
         -- Update pickdetail DropID    
         DECLARE @nRemainQty     INT,    
                 @nPickDetailQty INT,    
                 @cPickDetailKey NVARCHAR(10),    
                 @cPickLot       NVARCHAR(10),    
                 @cPickLOC       NVARCHAR(10),    
                 @cPickID        NVARCHAR(18),    
                 @cOrderKey      NVARCHAR(10),    
                 @cOrderLineNumber NVARCHAR(5)    
       
         SET  @nRemainQty = @nQTY_Move    
       
         DECLARE Cur_OffSet_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT PickDetailKey, Qty, LOT, LOC, ID, OrderKey, OrderLineNumber    
            FROM   PICKDETAIL WITH (NOLOCK)    
            WHERE PickSlipNo = @cPickSlipNo    
              AND CaseID     = @cFromLabelNo    
              AND StorerKey  = @cStorerKey    
              AND SKU        = @cSKU    
              AND Status     = '5'    
            ORDER BY CASE WHEN  Qty = @nRemainQty THEN 1    
                          WHEN  Qty > @nRemainQty THEN 2    
                          ELSE  9    
                     END,    
                     Qty    
       
         OPEN Cur_OffSet_PickDetail    
         FETCH NEXT FROM Cur_OffSet_PickDetail INTO @cPickDetailKey, @nPickDetailQty,    
                         @cPickLOT, @cPickLOC, @cPickID, @cOrderKey, @cOrderLineNumber    
       
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            IF @nRemainQty >= @nPickDetailQty    
            BEGIN    
       
               UPDATE PICKDETAIL WITH (ROWLOCK)    
                  SET CaseID = @cToLabelNo,    
                      DropID = @cToDropID,    
                      TrafficCop = NULL    
               WHERE PickDetailKey = @cPickDetailKey    
       
               SET @nRemainQty = @nRemainQty - @nPickDetailQty    
            END    
            ELSE IF @nRemainQty < @nPickDetailQty    
            BEGIN    
               -- Split pickdetail    
               EXEC rdt.rdt_529ExtUpdateSP02    
                     @cFromDropID       = @cFromDropID,    
                     @cToDropID         = @cToDropID,    
                     @cFromLabelNo      = @cFromLabelNo,    
                     @cToLabelNo        = @cToLabelNo,    
                     @nQTY_Move         = @nRemainQty,    
                     @cStorerKey        = @cStorerKey,    
                     @cOldPickDetailKey = @cPickDetailKey,    
                     @cLangCode         = @cLangCode,    
                     @nErrNo            = @nErrNo  OUTPUT,    
                     @cErrMsg           = @cErrMsg OUTPUT    
       
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 84957    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SplitPKDtlErr    
                  --GOTO RollBackTran    
               END    
       
               SET @nRemainQty = 0    
               BREAK    
            END -- IF @nRemainQty < @nPickDetailQty    
       
            IF @nRemainQty = 0    
               BREAK    
       
            FETCH NEXT FROM Cur_OffSet_PickDetail INTO @cPickDetailKey, @nPickDetailQty,    
                            @cPickLOT, @cPickLOC, @cPickID, @cOrderKey, @cOrderLineNumber    
       
         END    
         CLOSE Cur_OffSet_PickDetail    
         DEALLOCATE Cur_OffSet_PickDetail    
       
      END -- UPDATE    
       
      -- Check if fully offset (when by SKU)    
      IF @cSKU <> '' AND @nRemainQty <> 0    
      BEGIN    
         SET @nErrNo = 84958    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OffsetError    
         GOTO RollBackTran    
      END    
   END
    
   COMMIT TRAN rdt_529ExtUpdateSP01 -- Only commit change made in rdt_529ExtUpdateSP01    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_529ExtUpdateSP01 -- Only rollback change made in rdt_529ExtUpdateSP01    
Quit:    
   -- Commit until the level we started    
   WHILE @@TRANCOUNT > @nTranCount    
      COMMIT TRAN    
Fail:    
END

GO