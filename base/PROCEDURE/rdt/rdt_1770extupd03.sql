SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ExtUpd03                                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Stamp additional info on UCC                                */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2023-10-05   Ung       1.0   WMS-23486 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1770ExtUpd03]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nQTY            INT
   ,@cToLOC          NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      IF @nStep = 4 -- ToLOC, DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_1770ExtUpd03 -- For rollback or commit only our own transaction

            DECLARE @cStorerKey        NVARCHAR( 15)
            DECLARE @cOrderKey         NVARCHAR( 10)
            DECLARE @cExternOrderKey   NVARCHAR( 50)
            
            -- Loop PickDetail
            DECLARE @curPD CURSOR
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT O.StorerKey, O.OrderKey, O.ExternOrderKey, PD.DropID
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE PD.TaskDetailKey = @cTaskDetailKey
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cStorerKey, @cOrderKey, @cExternOrderKey, @cDropID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- UCC
               UPDATE dbo.UCC SET
                  OrderKey = @cOrderKey, 
                  UserDefined04 = @cExternOrderKey, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE StorerKey = @cStorerKey
                  AND UCCNo = @cDropID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 207051
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd UCC Fail
                  GOTO RollBackTran
               END
                  
               FETCH NEXT FROM @curPD INTO @cStorerKey, @cOrderKey, @cExternOrderKey, @cDropID
            END
            
            COMMIT TRAN rdt_1770ExtUpd03
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1770ExtUpd03 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO