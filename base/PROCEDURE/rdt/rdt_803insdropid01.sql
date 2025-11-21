SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_803InsDropID01                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Confirm by order                                            */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 23-01-2018 1.0  Ung         WMS-3788 Created                         */
/* 27-04-2018 1.1  Ung         WMS-3788 Stamp DropID.LoadKey, PickSlipNo*/
/* 24-09-2018 1.2  Ung         INC0401559 Fix DropID not inserted       */
/************************************************************************/

CREATE PROC [RDT].[rdt_803InsDropID01] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cLight       NVARCHAR( 1)
   ,@cStation     NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cSKU         NVARCHAR( 20)
   ,@cIPAddress   NVARCHAR( 40) 
   ,@cPosition    NVARCHAR( 10)
   ,@cCartonID    NVARCHAR( 20)
   ,@cOrderKey    NVARCHAR( 10)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
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
   SAVE TRAN rdt_803InsDropID01 -- For rollback or commit only our own transaction

   -- Get pick info
   DECLARE @cPickSlipNo NVARCHAR( 10)
   SET @cPickSlipNo = ''
   SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

   -- Get LoadKey
   DECLARE @cLoadKey NVARCHAR( 10)
   SET @cLoadKey = ''
   SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

   -- Get DropID status
   DECLARE @cDropIDStatus NVARCHAR( 10)
   SELECT @cDropIDStatus = Status FROM DropID WITH (NOLOCK) WHERE DropID = @cCartonID

   -- Finish pick
   IF @@ROWCOUNT = 0
   BEGIN      
      INSERT INTO dbo.DropID (DropID, DropIDType, Status, LoadKey, PickSlipNo)
      VALUES (@cCartonID, 'MULTIS', '5', @cLoadKey, @cPickSlipNo)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 118901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS DID Fail
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      IF @cDropIDStatus = '9'
      BEGIN
         UPDATE dbo.DropID SET
            Status = '5', 
            LoadKey = @cLoadKey, 
            PickSlipNo = @cPickSlipNo, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE DropID = @cCartonID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 118902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DID Fail
            GOTO RollBackTran
         END
      END
   END
         
   COMMIT TRAN rdt_803InsDropID01
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_803InsDropID01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO