SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PackByDropID_Repack                             */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2019-02-27 1.0  Ung         WMS-8034 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_PackByDropID_Repack] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@nCartonNo    INT
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
   DECLARE @cUOM       NVARCHAR(10)
   DECLARE @cLabelNo   NVARCHAR(20)
   DECLARE @cPickDetailKey NVARCHAR(10)

   /***********************************************************************************************
                                                PackDetail
   ***********************************************************************************************/
   SELECT TOP 1 
      @cFirstLine = LabelLine, 
      @cLabelNo = LabelNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
   ORDER BY LabelLine

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PackByDropID_Repack -- For rollback or commit only our own transaction

   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LabelLine, SKU
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo

   -- Loop PackDetail
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
            SET @nErrNo = 100301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
            GOTO RollBackTran
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
            SET @nErrNo = 100302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail
            GOTO RollBackTran
         END
      END
      
      FETCH NEXT FROM @curPD INTO @cLabelLine, @cSKU
   END


   /***********************************************************************************************
                                              PickDetail
   ***********************************************************************************************/
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, UOM
      FROM PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND CaseID = @cLabelNo
         AND Status = '5'
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cUOM
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Confirm PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         Status = CASE WHEN @cUOM = '2' THEN '0' ELSE '3' END,
         CaseID = '', 
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME()
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 102001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cUOM
   END
   
   COMMIT TRAN rdt_PackByDropID_Repack
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PackByDropID_Repack -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO