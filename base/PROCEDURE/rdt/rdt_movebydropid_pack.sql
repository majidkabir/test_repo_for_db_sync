SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_MoveByDropID_Pack                               */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Split PackDetail                                            */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2011-11-09  1.0  Ung      Created                                    */  
/* 2011-12-30  1.1  Shong    Change the logic for getting next Carton   */  
/* 2011-12-31  1.2  Shong    Update Pickdetail DropID to swap carton    */  
/* 2011-02-01  1.3  Ung      Bug Fix                                    */  
/* 2012-02-06  1.4  Shong    Fix Extra line created issues              */  
/* 2012-02-08  1.5  Ung      Add PackInfo section                       */  
/* 2012-02-24  1.6  Shong01  Recalculate Pack Header Total Cartons      */  
/* 2012-03-06  1.7  Ung      Add event log                              */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_MoveByDropID_Pack] (  
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
   DECLARE @cToLabelLine    NVARCHAR( 5)  
  
   SET @nErrNo = 0  
   SET @cErrMsg = ''  
  
   DECLARE  
       @n_debug INT  
      ,@d_date       DATETIME  
      ,@d_starttime  DATETIME  
      ,@d_endtime    DATETIME  
      ,@d_total      DATETIME, @n_total  INT  
      ,@d_step1      DATETIME, @n_step1  INT  
      ,@d_step2      DATETIME, @n_step2  INT  
      ,@d_step3      DATETIME, @n_step3  INT  
      ,@d_step4      DATETIME, @n_step4  INT  
      ,@d_step5      DATETIME, @n_step5  INT  
      ,@d_step6      DATETIME, @n_step6  INT  
      ,@d_step7      DATETIME, @n_step7  INT  
      ,@d_step8      DATETIME, @n_step8  INT  
      ,@d_step9      DATETIME, @n_step9  INT  
      ,@d_step10     DATETIME, @n_step10 INT  
      ,@c_TraceName  NVARCHAR(80)  
  
   SET @d_starttime = GETDATE()  
   SET @c_TraceName = 'rdt_MoveByDropID_Pack'  
   SELECT @d_total     = 0, @n_total  = 0  
   SELECT @d_step1     = 0, @n_step1  = 0  
   SELECT @d_step2     = 0, @n_step2  = 0  
   SELECT @d_step3     = 0, @n_step3  = 0  
   SELECT @d_step4     = 0, @n_step4  = 0  
   SELECT @d_step5     = 0, @n_step5  = 0  
   SELECT @d_step6     = 0, @n_step6  = 0  
   SELECT @d_step7     = 0, @n_step7  = 0  
   SELECT @d_step8     = 0, @n_step8  = 0  
   SELECT @d_step9     = 0, @n_step9  = 0  
   SELECT @d_step10    = 0, @n_step10 = 0  
  
   SET @n_debug = 0  
  
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
   SAVE TRAN rdt_MoveByDropID_Pack  
  
   SET @nToCartonNo = 0  
   SELECT TOP 1  
      @nToCartonNo = ISNULL(CartonNo,0),  
      @cToLabelNo = LabelNo  
   FROM dbo.PackDetail WITH (NOLOCK)  
   WHERE PickSlipNo = @cPickSlipNo  
     AND DropID = @cToDropID  
   ORDER BY CartonNo DESC  
  
   IF @nToCartonNo = 0  
   BEGIN  
      SET @d_date = GETDATE()  
      EXECUTE rdt.rdt_GenUCCLabelNo  
         @cStorerKey,  
         @nMobile,  
         @cToLabelNo  OUTPUT,  
         @cLangCode,  
         @nErrNo      OUTPUT,  
         @cErrMsg     OUTPUT  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 74656  
         SET @cErrMsg = rdt.rdtgetmessage( 74656, @cLangCode, 'DSP') --GenUCCLabelNo  
         GOTO RollBackTran  
      END  
      SELECT @d_step1 = @d_step1 + (GETDATE() - @d_date), @n_step1 = @n_step1 + 1  
   END  
  
   -- If Carton to Carton Move, which is SKU = BLANK  
   -- Just update the UCC Label Number. The rest of the information remain  
   IF ISNULL(RTRIM(@cSKU),'') = ''  
   BEGIN  
      SET @d_date = GETDATE()  
      UPDATE PD  
         SET LabelNo = @cToLabelNo,  
             DropID  = @cToDropID,  
             ArchiveCop = NULL  
      FROM dbo.PackDetail PD  
      WHERE PD.PickSlipNo = @cPickSlipNo  
         AND PD.DropID    = @cFromDropID  
         AND PD.StorerKey = @cStorerKey  
      SELECT @d_step2 = @d_step2 + (GETDATE() - @d_date), @n_step2 = @n_step2 + 1  
  
      -- Update PickDetail DropID  
      SET @d_date = GETDATE()  
      UPDATE PICKDETAIL WITH (ROWLOCK)  
      SET DropID = @cToDropID,  
          TrafficCop = NULL  
      WHERE PickSlipNo = @cPickSlipNo  
        AND DropID     = @cFromDropID  
        AND StorerKey = @cStorerKey  
      SELECT @d_step3 = @d_step3 + (GETDATE() - @d_date), @n_step3 = @n_step3 + 1  
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
  
      IF @nToCartonNo = 0  
      BEGIN  
         -- Give From Drop ID Carton# to To Drop ID  
         SET @nToCartonNo = @nFromCartonNo  
  
         -- If From Carton no = To Carton No, Need to assign new carton# for From Carton.  
         SELECT @nFromCartonNo = IsNULL(MAX(CartonNo), 0) + 1  
         FROM   dbo.PackDetail WITH (NOLOCK)  
         WHERE  PickSlipNo = @cPickSlipNo  
  
         -- Change the From DropID Carton to new Carton#  
         SET @d_date = GETDATE()  
         UPDATE PD  
         SET CartonNo = @nFromCartonNo,  
             ArchiveCop = NULL  
         FROM dbo.PackDetail PD  
         WHERE PD.PickSlipNo = @cPickSlipNo  
            AND PD.DropID    = @cFromDropID  
            AND PD.StorerKey = @cStorerKey  
         SELECT @d_step4 = @d_step4 + (GETDATE() - @d_date), @n_step4 = @n_step4 + 1  
      END  
  
      IF @nQTY_Move > @nFromQTY  
         SET @nQTY = @nFromQTY  
      ELSE  
         SET @nQTY = @nQTY_Move  
  
      --SET @nQTY_Move = @nQTY_Move - @nQTY  
  
      SET @cToLabelLine = ''  
      SELECT  
         @cToLabelLine = LabelLine  
      FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE PickSlipNo = @cPickSlipNo  
         AND DropID = @cToDropID  
         AND StorerKey = @cStorerKey  
         AND SKU = @cFromSKU  
  
      SET @nRowCount = @@ROWCOUNT  
  
      IF @nRowCount = 0  
      BEGIN  
         SELECT @cToLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
         FROM dbo.PackDetail (NOLOCK)  
         WHERE Pickslipno = @cPickSlipNo  
             AND CartonNo = @nToCartonNo  
  
         -- Insert to PackDetail line  
         SET @d_date = GETDATE()  
         INSERT INTO dbo.PackDetail  
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY,  
             AddWho, AddDate, EditWho, EditDate, DropID)  
         VALUES  
            (@cPickSlipNo, @nToCartonNo, @cToLabelNo, @cToLabelLine, @cStorerKey, @cFromSKU, @nQTY,  
             'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToDropID)  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 74651  
            SET @cErrMsg = rdt.rdtgetmessage( 74651, @cLangCode, 'DSP') --'InsPackDtlFail'  
            GOTO RollBackTran  
         END  
         SELECT @d_step5 = @d_step5 + (GETDATE() - @d_date), @n_step5 = @n_step5 + 1  
      END  
      ELSE  
      BEGIN  
         -- Update TO PackDetail line  
         SET @d_date = GETDATE()  
         UPDATE dbo.PackDetail SET  
            QTY = QTY + @nQTY,  
            EditWho = 'rdt.' + sUser_sName(),  
            EditDate = GETDATE()  
         WHERE PickSlipNo = @cPickSlipNo  
            AND CartonNo = @nToCartonNo  
            AND LabelNo = @cToLabelNo  
            AND LabelLine = @cToLabelLine  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 74652  
            SET @cErrMsg = rdt.rdtgetmessage( 74652, @cLangCode, 'DSP') --UpdPackDtlFail  
            GOTO RollBackTran  
         END  
         SELECT @d_step6 = @d_step6 + (GETDATE() - @d_date), @n_step6 = @n_step6 + 1  
      END  
      --- End Update To Drop ID  
  
  
      -- Update PackDetail - From DropID  
      SET @d_date = GETDATE()  
      UPDATE PackDetail SET  
         QTY = QTY - @nQTY  
      WHERE PickSlipNo = @cPickSlipNo  
         AND CartonNo = @nFromCartonNo  
         AND LabelNo = @cFromLabelNo  
         AND LabelLine = @cFromLabelLine  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 74654  
         SET @cErrMsg = rdt.rdtgetmessage( 74654, @cLangCode, 'DSP') --UpdPackDtlFail  
         GOTO RollBackTran  
      END  
      SELECT @d_step7 = @d_step7 + (GETDATE() - @d_date), @n_step7 = @n_step7 + 1  
  
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
           AND DropID     = @cFromDropID  
           AND StorerKey  = @cStorerKey  
           AND SKU        = @cSKU  
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
            SET @d_date = GETDATE()  
  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET DropID = @cToDropID, TrafficCop = NULL  
            WHERE PickDetailKey = @cPickDetailKey  
  
            SELECT @d_step8 = @d_step8 + (GETDATE() - @d_date), @n_step8 = @n_step8 + 1  
  
            SET @nRemainQty = @nRemainQty - @nPickDetailQty  
         END  
         ELSE IF @nRemainQty < @nPickDetailQty  
         BEGIN  
            -- Split pickdetail  
            SET @d_date = GETDATE()  
            EXEC rdt.rdt_MoveByDropID_SplitPickDetail  
                  @cFromDropID       = @cFromDropID,  
                  @cToDropID         = @cToDropID,  
                  @nQTY_Move         = @nRemainQty,  
                  @cStorerKey        = @cStorerKey,  
                  @cOldPickDetailKey = @cPickDetailKey,  
                  @cLangCode         = @cLangCode,  
                  @nErrNo            = @nErrNo  OUTPUT,  
                  @cErrMsg           = @cErrMsg OUTPUT  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 74653  
               SET @cErrMsg = rdt.rdtgetmessage( 74653, @cLangCode, 'DSP') --SplitPKDtlErr  
               --GOTO RollBackTran  
            END  
  
            SELECT @d_step10 = @d_step10 + (GETDATE() - @d_date), @n_step10 = @n_step10 + 1  
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
      SET @nErrNo = 74655  
      SET @cErrMsg = rdt.rdtgetmessage( 74655, @cLangCode, 'DSP') --OffsetError  
      GOTO RollBackTran  
   END  
  
/*--------------------------------------------------------------------------------------------------  
  
                                             PackInfo  
  
--------------------------------------------------------------------------------------------------*/  
   DECLARE @nCartonWeight FLOAT  
   DECLARE @nCartonCube   FLOAT  
  
   SELECT @nFromCartonNo = CartonNo  
   FROM dbo.PackDetail WITH (NOLOCK)  
   WHERE PickSlipNo = @cPickSlipNo AND DropID = @cFromDropID  
  
   SELECT @nToCartonNo   = CartonNo  
   FROM dbo.PackDetail WITH (NOLOCK)  
   WHERE PickSlipNo = @cPickSlipNo AND DropID = @cToDropID  
  
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
  
      IF NOT EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nFromCartonNo)  
      BEGIN  
         INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube)  
         VALUES ( @cPickSlipNo, @nFromCartonNo, @nCartonWeight, @nCartonCube)  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 74656  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail  
            GOTO RollBackTran  
         END  
      END  
      ELSE  
      BEGIN  
         -- Update PackInfo  
         UPDATE dbo.PackInfo SET  
            Weight = @nCartonWeight,  
            Cube = @nCartonCube  
         WHERE PickSlipNo = @cPickSlipNo  
            AND CartonNo = @nFromCartonNo  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 74657  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKInfoFail  
            GOTO RollBackTran  
         END  
      END  
   END  
   ELSE  
   BEGIN  
      DELETE dbo.PackInfo WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nFromCartonNo  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 74658  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPKInfoFail  
         GOTO RollBackTran  
      END  
   END  
  
   -- To carton  
   IF EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nToCartonNo)  
   BEGIN  
      -- Recalc to carton's weight, cube  
      SELECT  
         @nCartonWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0),  
         @nCartonCube   = ISNULL( SUM( PD.QTY * SKU.STDCube), 0)  
      FROM dbo.PackDetail PD WITH (NOLOCK)  
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
      WHERE PD.PickSlipNo = @cPickSlipNo  
         AND PD.CartonNo = @nToCartonNo  
  
      IF NOT EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nToCartonNo)  
      BEGIN  
         INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube)  
         VALUES ( @cPickSlipNo, @nToCartonNo, @nCartonWeight, @nCartonCube)  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 74659  
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
            SET @nErrNo = 74660  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKInfoFail  
            GOTO RollBackTran  
         END  
      END  
   END  
   ELSE  
   BEGIN  
      DELETE dbo.PackInfo WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nToCartonNo  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 74661  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPKInfoFail  
         GOTO RollBackTran  
      END  
   END  
  
   -- Shong01  
   -- Updating PackHeader Total Cartons  
   DECLARE @nTotalCartons INT  
   SET @nTotalCartons = 0  
   SELECT @nTotalCartons = ISNULL(COUNT(DISTINCT LabelNo), 0)  
   FROM  PACKDETAIL WITH (NOLOCK)  
   WHERE PickSlipNo = @cPickSlipNo  
     AND Qty > 0  
  
   UPDATE PACKHEADER WITH (ROWLOCK)  
      SET TTLCNTS=@nTotalCartons, ArchiveCop=NULL  
   WHERE PickSlipNo = @cPickSlipNo  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 74662  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKHdrFail  
      GOTO RollBackTran  
   END  
  
   DECLARE @cUOM NVARCHAR( 10)  
   SET @cUOM = ''  
   IF @cSKU <> ''  
   BEGIN
      SELECT @cUOM = Pack.PackUOM3  
      FROM dbo.Pack WITH (NOLOCK)  
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
      WHERE SKU.StorerKey = @cStorerKey  
         AND SKU.SKU = @cSKU     	
   END
  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType   = '4', -- Move  
      @cUserID       = @cUserName,  
      @nMobileNo     = @nMobile,  
      @nFunctionID   = @nFunc,  
      @cFacility     = @cFacility,  
      @cStorerKey    = @cStorerKey,  
      @cID           = @cFromDropID,  
      @cToID         = @cToDropID,  
      @cSKU          = @cSKU,  
      @cUOM          = @cUOM,  
      @nQTY          = @nEventLogQTY  
  
   IF @n_debug = 1  
   BEGIN  
      SET @d_endtime = GETDATE()  
      SET @d_total = @d_endtime - @d_starttime  
      SET @n_total = @n_step1 + @n_step2 + @n_step3 + @n_step4 + @n_step5 + @n_step6 + @n_step7 + @n_step8 + @n_step9 + @n_step10  
  
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)  
      VALUES ( @c_TraceName ,@d_starttime, @d_endtime,  
         RIGHT( CONVERT( NVARCHAR( 12), @d_total, 114), 8) + '-' + CAST( @n_total AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step1, 114), 8) + '-' + CAST( @n_step1 AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step2, 114), 8) + '-' + CAST( @n_step2 AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step3, 114), 8) + '-' + CAST( @n_step3 AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step4, 114), 8) + '-' + CAST( @n_step4 AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step5, 114), 8) + '-' + CAST( @n_step5 AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step6, 114), 8) + '-' + CAST( @n_step6 AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step7, 114), 8) + '-' + CAST( @n_step7 AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step8, 114), 8) + '-' + CAST( @n_step8 AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step9, 114), 8) + '-' + CAST( @n_step9 AS NVARCHAR( 3)),  
         RIGHT( CONVERT( NVARCHAR( 12), @d_step10,114), 8) + '-' + CAST( @n_step10 AS NVARCHAR( 3)))  
   END  
  
   COMMIT TRAN rdt_MoveByDropID_Pack -- Only commit change made in rdt_MoveByDropID_Pack  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_MoveByDropID_Pack -- Only rollback change made in rdt_MoveByDropID_Pack  
Quit:  
   -- Commit until the level we started  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
Fail:  
END  

GO