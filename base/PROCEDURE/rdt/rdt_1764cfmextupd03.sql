SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  

/************************************************************************/
/* Store procedure: rdt_1764CfmExtUpd03                                 */
/* Purpose: 1. Stamp TaskDetail.CaseID as UCCNo                         */
/*          2. Stamp PickDetail.DropID as UCCNo                         */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-08-20   ChewKP    1.0   WMS-5178 Created                        */
/* 2019-06-26   Ung       1.1   Remove TraceInfo                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764CfmExtUpd03]
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

   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cPickMethod    NVARCHAR(10)
   DECLARE @cUCCNo         NVARCHAR(20)
          ,@nUCCQty        INT
          ,@cStorerKey     NVARCHAR(15) 
   
   -- Get orginal task info
   SELECT 
       @cPickMethod = PickMethod
      ,@cStorerKey  = StorerKey 
   FROM TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskdetailKey

   -- FP, does not close pallet or short
   IF @cPickMethod = 'FP'
      RETURN

   -- Get UCC
   SELECT @cUCCNo = UCCNo FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
   
   
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1764CfmExtUpd03



   -- Loop PickDetail for original task
   IF ISNULL(@cUCCNo, '' ) <> '' 
   BEGIN
      SELECT @nUCCQty = Qty 
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCCNo 
   
      -- Update task
      UPDATE TaskDetail WITH (ROWLOCK)  SET
         Qty = @nUCCQty,
         CaseID = ISNULL(@cUCCNo,''), 
         EditWho  = SUSER_SNAME(), 
         EditDate = GETDATE(),
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 115451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
         GOTO RollBackTran
      END
      
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.TaskDetailKey = @cTaskDetailKey
            AND PD.QTY > 0
            AND PD.Status = '0'

      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = ISNULL(@cUCCNo,''), 
            Status = '3',
            EditWho  = SUSER_SNAME(), 
            EditDate = GETDATE(),
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 115452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
         
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END
   END
   COMMIT TRAN rdt_1764CfmExtUpd03 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764CfmExtUpd03 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO