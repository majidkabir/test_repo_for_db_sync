SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtANFRPFCfmExtUpd                                  */
/* Purpose: Confirm extended update                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-02-25   Ung       1.0   SOS256104 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtANFRPFCfmExtUpd]
    @nMobile            INT 
   ,@nFunc              INT 
   ,@cLangCode          NVARCHAR( 3) 
   ,@cTaskdetailKey     NVARCHAR( 10) 
   ,@cNewTaskdetailKey  NVARCHAR( 10) 
   ,@nErrNo             INT           OUTPUT 
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT

   -- Task splitted
   IF @cNewTaskdetailKey <> ''
   BEGIN
      BEGIN TRAN
      SAVE TRAN rdtANFRPFCfmExtUpd
      
      -- Loop PickDetail
      DECLARE @cPickDetailKey NVARCHAR(10)
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
            AND Status = '0'
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update PickDetail with splitted TaskDetailKey
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            TaskDetailKey = @cNewTaskDetailKey, 
            EditWho  = SUSER_SNAME(), 
            EditDate = GETDATE(),
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 85401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
            GOTO RollBackTran
         END
               
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END

      COMMIT TRAN rdtANFRPFCfmExtUpd -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtANFRPFCfmExtUpd -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO