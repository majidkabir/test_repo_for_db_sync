SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_881ConfirmSP01                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 22-07-2018  1.0  Ung        WMS-5919 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_881ConfirmSP01] (
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @nStep      INT,
   @nInputKey  INT,
   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cCartonID  NVARCHAR( 20),
   @cTotalSKU  NVARCHAR( 5), 
   @cQTYAlloc  NVARCHAR( 5),
   @cQTYShort  NVARCHAR( 5),
   @cQTYPick   NVARCHAR( 5),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cPickDetailKey NVARCHAR( 10)
DECLARE @cCaseID        NVARCHAR( 20)
DECLARE @cSKU           NVARCHAR( 20)
DECLARE @nQTY           INT
DECLARE @cPickSlipNo    NVARCHAR( 10)
DECLARE @nCartonNo      INT
DECLARE @cLabelNo       NVARCHAR( 20)
DECLARE @cLabelLine     NVARCHAR( 5)
DECLARE @nPackQTY       INT

DECLARE @nTranCount     INT
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN
SAVE TRAN rdt_881ConfirmSP01

/*--------------------------------------------------------------------------------------------------

                                          PickDetail line

--------------------------------------------------------------------------------------------------*/
DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, CaseID, SKU, QTY
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE DropID = @cCartonID
         AND StorerKey = @cStorerKey
         AND ShipFlag <> 'Y'
      
OPEN @curPD
FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cCaseID, @cSKU, @nQTY
WHILE @@FETCH_STATUS = 0
BEGIN
   -- Short pick
   UPDATE PickDetail SET
      Status = '4', 
      EditDate = GETDATE(), 
      EditWho = SUSER_SNAME(), 
      TrafficCop = NULL
   WHERE PickDetailKey = @cPickDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 127751
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
      GOTO RollBackTran
   END

   -- Get PackDetail info
   SET @cLabelLine = ''
   SELECT 
      @cPickSlipNo = PickSlipNo, 
      @nCartonNo = CartonNo, 
      @cLabelNo = LabelNo, 
      @cLabelLine = LabelLine, 
      @nPackQTY = QTY
   FROM PackDetail WITH (NOLOCK) 
   WHERE LabelNo = @cCaseID
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
   
   -- Unpack
   IF @cLabelLine <> ''
   BEGIN
      IF @nPackQTY = @nQTY
      BEGIN
         DELETE PackDetail 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 127752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DELPackDtlFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE PackDetail SET
            QTY = QTY - @nQTY, 
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 127753
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPackDtlFail
            GOTO RollBackTran
         END
      END
   END

   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cCaseID, @cSKU, @nQTY
END

COMMIT TRAN rdt_881ConfirmSP01 -- Only commit change made in rdt_881ConfirmSP01
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_881ConfirmSP01 -- Only rollback change made in rdt_881ConfirmSP01
Quit:   
   WHILE @@TRANCOUNT > @nTranCount  -- Commit until the level we started
      COMMIT TRAN

GO