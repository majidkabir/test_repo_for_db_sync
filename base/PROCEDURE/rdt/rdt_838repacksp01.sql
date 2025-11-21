SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838RepackSP01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 03-10-2019 1.0  Ung         WMS-10729 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838RepackSP01] (
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

   DECLARE @cLabelLine NVARCHAR(5)
   DECLARE @cFirstLine NVARCHAR(5)
   DECLARE @cSKU       NVARCHAR(20)
   DECLARE @cDropID    NVARCHAR(20)

   SELECT TOP 1 
      @cFirstLine = LabelLine, 
      @cDropID = DropID
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      AND LabelNo = @cLabelNo
   ORDER BY LabelLine

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_838RepackSP01 -- For rollback or commit only our own transaction
   
   IF @cType = 'UCC'
   BEGIN
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
   END
   
   COMMIT TRAN rdt_838RepackSP01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_838RepackSP01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO