SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_808CloseCart02                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close working batch                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 20-07-2018 1.0  Ung         WMS-5487 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_808CloseCart02] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR(5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cCartID    NVARCHAR( 10)
   ,@cPickZone  NVARCHAR( 10)
   ,@cDPLKey    NVARCHAR( 10)
   ,@nErrNo     INT           OUTPUT
   ,@cErrMsg    NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowRef     INT
   DECLARE @nPTLKey     INT
   DECLARE @nTranCount  INT
   DECLARE @cMultiPickerBatch NVARCHAR( 1)

   SET @nTranCount = @@TRANCOUNT

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdtfnc_PTL_Cart -- For rollback or commit only our own transaction

   -- rdtPTLCartLog_Doc
   DECLARE @curLog CURSOR
   SET @curLog = CURSOR FOR
      SELECT RowRef
      FROM rdt.rdtPTLCartLog_Doc WITH (NOLOCK)
      WHERE CartID = @cCartID

   OPEN @curLog
   FETCH NEXT FROM @curLog INTO @nRowRef
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update rdtPTLCartLog
      DELETE rdt.rdtPTLCartLog_Doc WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 126751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL LOG Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curLog INTO @nRowRef
   END

   -- DeviceProfileLog
   DECLARE @curDPL CURSOR
   SET @curDPL = CURSOR FOR
      SELECT RowRef
      FROM rdt.rdtPTLCartLog WITH (NOLOCK)
      WHERE CartID = @cCartID
         AND DeviceProfileLogKey = @cDPLKey

   OPEN @curDPL
   FETCH NEXT FROM @curDPL INTO @nRowRef
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update rdtPTLCartLog
      DELETE rdt.rdtPTLCartLog WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 126752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL DPL Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curDPL INTO @nRowRef
   END

   -- PTLTran
   DECLARE @curPTL CURSOR
   SET @curPTL = CURSOR FOR
      SELECT PTLKey
      FROM PTLTran WITH (NOLOCK)
      WHERE DeviceProfileLogKey = @cDPLKey
         AND Status <> '9'
   OPEN @curPTL
   FETCH NEXT FROM @curPTL INTO @nPTLKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update DeviceProfileLog
      UPDATE PTLTran SET
         Status = '9',
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE(), 
         TrafficCop = NULL
      WHERE PTLKey = @nPTLKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 126753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PTL Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPTL INTO @nPTLKey
   END

   COMMIT TRAN rdtfnc_PTL_Cart_CloseCart
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_808CloseCart02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO