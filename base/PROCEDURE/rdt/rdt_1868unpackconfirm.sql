SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1868UnpackConfirm                               */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date         Rev   Author      Purposes                              */
/* 2024-11-05   1.0   TLE109      FCR-917 Serial Unpack and Unpick      */
/************************************************************************/


CREATE   PROC rdt.rdt_1868UnpackConfirm (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cSerialNo        NVARCHAR( 100),
   @cPickSlipNo      NVARCHAR( 20),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
   @cUnPackConfirmSP NVARCHAR( 20),
   @nTranCount       INT,
   @cSQL             NVARCHAR( MAX),
   @cSQLParam        NVARCHAR( MAX)

   SET @nTranCount = @@TRANCOUNT

   SET @cUnPackConfirmSP = rdt.RDTGetConfig( @nFunc, 'UnPackConfirmSP', @cStorerKey)
   IF @cUnPackConfirmSP = '0'
   BEGIN
      SET @cUnPackConfirmSP = ''
   END 
-------------------------------------------Customer---------------------------------------------

   IF @cUnPackConfirmSP <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cUnPackConfirmSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cUnPackConfirmSP) +
      ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
      ' @cSerialNo, @cPickSlipNo,' +
      ' @nErrNo OUTPUT, @cErrMsg OUTPUT ' 

      SET @cSQLParam = 
      ' @nMobile        INT,           ' +
      ' @nFunc          INT,           ' +
      ' @cLangCode      NVARCHAR( 3),  ' +
      ' @nStep          INT,           ' +
      ' @nInputKey      INT,           ' +
      ' @cFacility      NVARCHAR( 5),  ' +
      ' @cStorerKey     NVARCHAR( 15), ' +
      ' @cSerialNo      NVARCHAR( 100),' +
      ' @cPickSlipNo    NVARCHAR( 20), ' + 
      ' @nErrNo         INT,           ' +
      ' @cErrMsg        NVARCHAR( 20)  ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cSerialNo, @cPickslipNo,
         @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      END
      GOTO Quit 
   END



-------------------------------------------Standard---------------------------------------------

   DECLARE
   @nCartonNo      INT,
   @cLabelNo       NVARCHAR( 20),
   @cLabelLine     NVARCHAR( 10),
   @cPickDetailKey NVARCHAR( 20),
   @cSKU           NVARCHAR( 40),
   @nPackHeaderCompleted    INT


   -- transaction
   BEGIN TRAN
   SAVE TRAN tran_SerialUnpack

   SET @cLabelNo = ''
   SET @cLabelLine = ''
   SET @cPickDetailKey = ''
   SET @cSKU = ''
   SELECT  
      @nCartonNo      = CartonNo, 
      @cLabelNo       = LabelNo, 
      @cLabelLine     = LabelLine, 
      @cPickDetailKey = PickDetailKey, 
      @cSKU           = SKU
   FROM dbo.PackSerialNo WITH(NOLOCK)
   WHERE  SerialNo =@cSerialNo
      AND PickSlipNo =@cPickSlipNo
      AND StorerKey=@cStorerKey
   IF @cSKU = ''
   BEGIN
      SET @nErrNo = 228265 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --28265^SKU Not Exists
      GOTO RollBackTran
   END

   IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey AND Status = '9')
   BEGIN
      UPDATE dbo.PackHeader WITH(ROWLOCK)
      SET
         Status = '0',
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey AND Status = '9'
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
      SET @nPackHeaderCompleted = 1
   END


   DELETE FROM dbo.PackSerialNo
   WHERE PickSlipNo = @cPickSlipNo AND SerialNo = @cSerialNo AND StorerKey = @cStorerKey
   SET @nErrNo = @@ERROR
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO RollBackTran
   END

   UPDATE dbo.PackDetail WITH(ROWLOCK)
   SET 
      Qty       = Qty-1,
      EditWho   = SUSER_SNAME(),
      EditDate  = GETDATE()
   WHERE PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey
      AND CartonNo = @nCartonNo    AND Qty > 0 AND SKU = @cSKU
      AND LabelNo = @cLabelNo      AND LabelLine = @cLabelLine
   SET @nErrNo = @@ERROR
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO RollBackTran
   END

   DELETE FROM dbo.PackDetail
   WHERE PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey 
      AND CartonNo = @nCartonNo    AND Qty=0   AND SKU = @cSKU
      AND LabelNo = @cLabelNo      AND LabelLine = @cLabelLine
   SET @nErrNo = @@ERROR
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO RollBackTran
   END

   IF NOT EXISTS( SELECT 1 FROM dbo.PackDetail WHERE PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey)
   BEGIN
      DELETE FROM dbo.PackHeader
      WHERE PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      IF @nPackHeaderCompleted = 1
      BEGIN
         UPDATE dbo.PackHeader WITH(ROWLOCK)
         SET
            Status = '9',
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey AND Status = '0'
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO RollBackTran
         END
      END
   END

   UPDATE dbo.SerialNo WITH(ROWLOCK)
   SET 
      Status  = 1,
      EditWho = SUSER_SNAME(),
      EditDate = GETDATE()
   WHERE SerialNo = @cSerialNo AND Storerkey=@cStorerkey
   SET @nErrNo = @@ERROR
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
      EXEC rdt.rdtSetFocusField @nMobile, 1
      GOTO RollBackTran
   END
   COMMIT TRAN tran_SerialUnpack
   GOTO Quit
  

RollBackTran:
   ROLLBACK TRAN tran_SerialUnpack
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO