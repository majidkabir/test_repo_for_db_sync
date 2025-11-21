SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_760ExtUpdSP05_DelPack                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2018-04-11  1.0  Ung      WMS-5913 Created                           */
/************************************************************************/
CREATE PROC [RDT].[rdt_760ExtUpdSP05_DelPack] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @nStep          INT,
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cLabelNo       NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @nQTY           INT, 
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cPickSlipNo NVARCHAR(10)
   DECLARE @nCartonNo   INT
   DECLARE @cLabelLine  NVARCHAR(5)
   DECLARE @nPackQTY    INT
   
   SET @nTranCount = @@TRANCOUNT
   
   -- Get PackDetail info
   SET @cLabelLine = ''
   SELECT 
      @cPickSlipNo = PickSlipNo, 
      @nCartonNo = CartonNo, 
      @cLabelLine = LabelLine, 
      @nPackQTY = QTY
   FROM PackDetail WITH (NOLOCK) 
   WHERE LabelNo = @cLabelNo
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU

   IF @cLabelLine <> ''
   BEGIN
      BEGIN TRAN
      SAVE TRAN rdt_760ExtUpdSP05_DelPack
   
      IF @nPackQTY = @nQTY
      BEGIN
         DELETE PackDetail 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND LabelLine = @cLabelLine
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 126851
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
            SET @nErrNo = 126852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPackDtlFail
            GOTO RollBackTran
         END
      END
      
      COMMIT TRAN rdt_760ExtUpdSP05_DelPack
      GOTO Quit
   END
   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_760ExtUpdSP05_DelPack -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_760ExtUpdSP05_DelPack
END

GO