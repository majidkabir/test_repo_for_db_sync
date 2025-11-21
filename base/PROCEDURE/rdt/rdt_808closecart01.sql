SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_808CloseCart01                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close working batch                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 15-Aug-2017 1.0  Ung         WMS-2671 Created                        */
/* 12-Apr-2019 1.1  Ung         Change to PTL schema                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_808CloseCart01] (
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

   SET @cMultiPickerBatch = rdt.RDTGetConfig( @nFunc, 'MultiPickerBatch', @cStorerKey)
   
   IF @cMultiPickerBatch = '1'
   BEGIN
      -- Check any task outstanding
      IF EXISTS( SELECT TOP 1 1
         FROM PTL.PTLTran PTL WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
         WHERE PTL.DeviceProfileLogKey = @cDPLKey
            AND PTL.Status = '0')
      BEGIN
         GOTO Quit      
      END
   END

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdtfnc_PTL_Cart -- For rollback or commit only our own transaction

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
         SET @nErrNo = 113801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL DPL Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curDPL INTO @nRowRef
   END

   -- PTLTran
   DECLARE @curPTL CURSOR
   SET @curPTL = CURSOR FOR
      SELECT PTLKey
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE DeviceProfileLogKey = @cDPLKey
         AND Status <> '9'
   OPEN @curPTL
   FETCH NEXT FROM @curPTL INTO @nPTLKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update DeviceProfileLog
      UPDATE PTL.PTLTran SET
         Status = '9',
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE(), 
         TrafficCop = NULL
      WHERE PTLKey = @nPTLKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 113802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PTL Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPTL INTO @nPTLKey
   END

   COMMIT TRAN rdtfnc_PTL_Cart_CloseCart
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_808CloseCart01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO