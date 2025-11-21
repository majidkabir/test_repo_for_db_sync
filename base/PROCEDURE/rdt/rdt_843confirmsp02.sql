SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_843ConfirmSP02                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 22-06-2022 1.0  Ung         WMS-19989 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_843ConfirmSP02] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@nCartonNo       INT           OUTPUT
   ,@cLabelNo        NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_843ConfirmSP02 -- For rollback or commit only our own transaction

   EXEC rdt.rdt_PackByDropID_Confirm
       @nMobile     = @nMobile    
      ,@nFunc       = @nFunc      
      ,@cLangCode   = @cLangCode  
      ,@nStep       = @nStep      
      ,@nInputKey   = @nInputKey  
      ,@cFacility   = @cFacility  
      ,@cStorerKey  = @cStorerKey 
      ,@cPickSlipNo = @cPickSlipNo
      ,@cDropID     = @cDropID    
      ,@nCartonNo   = @nCartonNo   OUTPUT
      ,@cLabelNo    = @cLabelNo    OUTPUT
      ,@nErrNo      = @nErrNo      OUTPUT
      ,@cErrMsg     = @cErrMsg     OUTPUT
      ,@nUseStandard = 1
   IF @nErrNo <> 0
      GOTO RollBackTran

   -- Trigger carton to RFID tunnel interface 
   DECLARE @bSuccess INT
   EXEC dbo.ispGenTransmitLog2
        'WSPCKRFIDLOG' -- TableName
      , @cPickSlipNo -- Key1
      , @cLabelNo    -- Key2
      , @cStorerKey  -- Key3
      , ''           -- Batch
      , @bSuccess  OUTPUT
      , @nErrNo    OUTPUT
      , @cErrMsg   OUTPUT
   IF @bSuccess <> 1
   BEGIN
      SET @nErrNo = 187601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG2 Fail
      GOTO RollBackTran
   END

   COMMIT TRAN rdt_843ConfirmSP02
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_843ConfirmSP02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO