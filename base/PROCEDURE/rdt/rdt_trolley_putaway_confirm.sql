SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_Trolley_Putaway_Confirm                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2013-01-09 1.0  Ung        SOS259764. Created                              */
/* 2014-01-29 1.1  Ung        SOS300988 Add EventLog                          */
/* 2014-10-15 1.2  Ung        SOS323013 Lock orders to prevent deadlock       */
/*                            Fix err return from rdt_move not rollback       */
/* 2015-08-09 1.3  Ung        SOS347869 Add LOC                               */
/* 2016-05-04 1.4  Ung        SOS360342 Add UCC MoveQTYAlloc without task     */
/* 2017-03-27 1.5  James      WMS1399 - Include ucc.status = 3 (james01)      */
/* 2019-11-05 1.6  Chermaine  WMS11031 -Change eventLog @cRef1 to @cUCC (cc01)*/
/******************************************************************************/

CREATE PROC [RDT].[rdt_Trolley_Putaway_Confirm] (
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3), 
   @cFacility  NVARCHAR( 5), 
   @cStorerKey NVARCHAR( 15), 
   @cUserName  NVARCHAR( 18), 
   @cTrolleyNo NVARCHAR( 10), 
   @cUCC       NVARCHAR( 20), 
   @cLOC       NVARCHAR( 10), 
   @nErrNo     INT       OUTPUT, 
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @nTranCount     INT

   SET @nTranCount = @@TRANCOUNT

   -- Get UCC info
   SELECT TOP 1 
      @cFromLOC = LOC, 
      @cFromID = ID
   FROM dbo.UCC WITH (NOLOCK)
   WHERE UCCNo = @cUCC 
      AND StorerKey = @cStorerKey
      AND Status IN ('1', '3')   -- (james01)
   
   -- Get final LOC
   SELECT 
      @cToLOC = LOC, 
      @cToID = ID, 
      @cTaskDetailKey = TaskDetailKey
   FROM rdt.rdtTrolleyLog WITH (NOLOCK) 
   WHERE TrolleyNo = @cTrolleyNo 
      AND UCCNo = @cUCC
      AND Status = '1'

   -- Final LOC
   IF @cLOC <> ''
      SET @cToLOC = @cLOC

   -- To prevent missing TaskDetailKey (just in case) that will lock all orders
   IF @cTaskDetailKey = '' OR @cTaskDetailKey IS NULL
   BEGIN
      SET @nErrNo = 79153
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC no TaskKey
      GOTO Quit
   END

   BEGIN TRAN
   SAVE TRAN rdt_Trolley_Putaway_Confirm
   
   -- Lock orders to prevent deadlock
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OrderKey
      FROM PickDetail WITH (NOLOCK) 
      WHERE TaskDetailKey = @cTaskDetailKey
      ORDER BY OrderKey
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cOrderKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Dummy update to lock order
      UPDATE Orders SET
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME(), 
         TrafficCop = NULL
      WHERE OrderKey = @cOrderKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 79151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LockOrderFail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPD INTO @cOrderKey
   END
   
   -- Move by UCC
   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode,
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT,
      @cSourceType = 'rdt_Trolley_Putaway_Confirm',
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility,
      @cFromLOC    = @cFromLOC,
      @cToLOC      = @cToLOC,
      @cFromID     = @cFromID,
      @cToID       = @cToID,
      @cUCC        = @cUCC, 
      @nFunc       = @nFunc, 
      @cDropID     = @cUCC
   IF @nErrNo <> 0
      GOTO RollBackTran

   -- Remove Log
   DELETE rdt.rdtTrolleyLog
   WHERE TrolleyNo = @cTrolleyNo 
      AND UCCNo = @cUCC
      AND Status = '1'
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 79152
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DEL Log Fail
      GOTO RollBackTran
   END
      
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '4', -- Move
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cToLocation   = @cToLOC, 
      @cUCC          = @cUCC, --(cc01)
      @cRefNo2       = @cTrolleyNo, 
      @cTaskDetailKey = @cTaskDetailKey

   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_Trolley_Putaway_Confirm
Quit:         
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO