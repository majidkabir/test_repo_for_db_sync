SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838RepackSP02                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2024-08-22 1.0  JCH507      FCR-392 Granite Handle pickdetail        */
/************************************************************************/

CREATE PROC rdt.rdt_838RepackSP02 (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 10)
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@nCartonNo    INT
   ,@cLabelNo     NVARCHAR( 20) 
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelLine           NVARCHAR(5)
   DECLARE @cFirstLine           NVARCHAR(5)
   DECLARE @cSKU                 NVARCHAR(20)
   DECLARE @cDropID              NVARCHAR(20)
   DECLARE @bDebugFlag           BINARY = 0

   SELECT TOP 1 
      @cFirstLine = LabelLine, 
      @cDropID = DropID
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      AND LabelNo = @cLabelNo
   ORDER BY LabelLine

   IF @bDebugFlag = 1
      SELECT @cFirstLine AS FirstLine, @cDropID AS DropID, @cType AS Type

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_838RepackSP02 -- For rollback or commit only our own transaction
   
   IF @cType = 'UCC'
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Run UCC logic'
         
      DELETE dbo.PackDetail
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND LabelLine = @cFirstLine
      SET @nErrNo = @@ERROR 
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 144651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Run SKU logic'

      -- Loop PackDetail
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LabelLine, SKU
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo   
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cLabelLine, @cSKU
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Blank the 1st line (to retain the CartonNo)
         IF @bDebugFlag = 1
            SELECT @cLabelLine AS LabelLine, @cFirstLine AS FisrtLine, @cSKU AS SKU

         IF @cLabelLine = @cFirstLine
         BEGIN
            UPDATE PackDetail SET
               SKU = '', 
               QTY = 0, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine = @cLabelLine 
            SET @nErrNo = @@ERROR 
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 144652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
               GOTO RollBackTran
            END
            
            -- Serial no (PackDetail update trigger does not handle PackSerialNo)
            IF EXISTS( SELECT TOP 1 1 
               FROM PackSerialNo WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cLabelNo
                  AND LabelLine = @cLabelLine)
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Handle PackSerialNo'

               DECLARE @nPackSerialNoKey BIGINT
               DECLARE @curSNO CURSOR
               SET @curSNO = CURSOR FOR
                  SELECT PackSerialNoKey 
                  FROM PackSerialNo WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cLabelNo
                     AND LabelLine = @cLabelLine
               OPEN @curSNO
               FETCH NEXT FROM @curSNO INTO @nPackSerialNoKey 
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  DELETE PackSerialNo WHERE PackSerialNoKey = @nPackSerialNoKey
                  SET @nErrNo = @@ERROR 
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END
                  FETCH NEXT FROM @curSNO INTO @nPackSerialNoKey 
               END
            END

            -- Pack data (PackDetail update trigger does not handle PackDetailInfo)
            IF EXISTS( SELECT TOP 1 1 
               FROM PackDetailInfo WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cLabelNo
                  AND LabelLine = @cLabelLine)
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Handle PackDetailInfo'
               DECLARE @nPackDetailInfoKey BIGINT
               DECLARE @curInfo CURSOR
               SET @curInfo = CURSOR FOR
                  SELECT PackDetailInfoKey 
                  FROM PackDetailInfo WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                     AND LabelNo = @cLabelNo
                     AND LabelLine = @cLabelLine
               OPEN @curInfo
               FETCH NEXT FROM @curInfo INTO @nPackDetailInfoKey 
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  DELETE PackDetailInfo WHERE PackDetailInfoKey = @nPackDetailInfoKey
                  SET @nErrNo = @@ERROR 
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END
                  FETCH NEXT FROM @curInfo INTO @nPackDetailInfoKey 
               END
            END

         END
         ELSE
         BEGIN
            IF @bDebugFlag = 1
            BEGIN
               SELECT 'Delete pack detail'
               SELECT @cPickSlipNo AS PickSlipNO, @nCartonNo AS CartonNo, @cLabelNo AS LabelNo,
                     @cLabelLine AS LabelLine
            END

            DELETE dbo.PackDetail
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine = @cLabelLine
            SET @nErrNo = @@ERROR 
            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 144653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail
               GOTO RollBackTran
            END
         END
         
         FETCH NEXT FROM @curPD INTO @cLabelLine, @cSKU
      END

      -- Loop PickDetail
      DECLARE @cPickDetailKey NVARCHAR( 10)
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND CaseID = @cLabelNo   
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.PickDetail SET 
            CaseID = '', 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE PickDetailKey = @cPickDetailKey 
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 144654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END

      --Update packinfo qty  to 0
      UPDATE PackInfo WITH (ROWLOCK) SET Qty = 0, TrafficCop = NULL
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo

   END -- SKU end
   
   COMMIT TRAN rdt_838RepackSP02
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_838RepackSP02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO