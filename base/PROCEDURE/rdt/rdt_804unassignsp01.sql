SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_804UnassignSP01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close station                                               */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 21-Nov-2018 1.0  James       WMS6952 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_804UnassignSP01] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR(5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cStation1  NVARCHAR( 10)
   ,@cStation2  NVARCHAR( 10)
   ,@cStation3  NVARCHAR( 10)
   ,@cStation4  NVARCHAR( 10)
   ,@cStation5  NVARCHAR( 10)
   ,@cMethod    NVARCHAR( 10)
   ,@cCartonID  NVARCHAR( 20) -- Optional
   ,@nErrNo     INT           OUTPUT
   ,@cErrMsg    NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowRef INT
   DECLARE @nPTLKey INT
   DECLARE @cIPAddress NVARCHAR(40)
   DECLARE @cPosition  NVARCHAR(10)

   DECLARE @tStation TABLE ( IPAddress NVARCHAR( 40), Position NVARCHAR( 10))

   IF @cCartonID <> ''
   BEGIN
      INSERT INTO @tStation ( IPAddress, Position)
      SELECT IPAddress, Position
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND   ( ( @cCartonID = 'ALL') OR ( CartonID = @cCartonID))
      AND  StorerKey = @cStorerKey
   END

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_804UnassignSP01 -- For rollback or commit only our own transaction

   -- rdtPTLStationLog
   DECLARE @curDPL CURSOR
   IF @cCartonID <> ''
      SET @curDPL = CURSOR FOR
         SELECT RowRef
         FROM rdt.rdtPTLStationLog R WITH (NOLOCK)
         WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND   EXISTS ( SELECT 1 FROM @tStation S WHERE R.IPAddress = S.IPAddress AND R.Position = S.Position)
   ELSE
      SET @curDPL = CURSOR FOR
         SELECT RowRef
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)

   OPEN @curDPL
   FETCH NEXT FROM @curDPL INTO @nRowRef
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update rdtPTLStationLog
      DELETE rdt.rdtPTLStationLog WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 132001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL LOG Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curDPL INTO @nRowRef
   END

   -- PTLTran
   DECLARE @curPTL CURSOR
   IF @cCartonID <> ''
      SET @curPTL = CURSOR FOR
         SELECT PTLKey
         FROM PTL.PTLTran PTL WITH (NOLOCK)
         WHERE DeviceID IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND   Status <> '9'
         AND   EXISTS ( SELECT 1 FROM @tStation S WHERE PTL.IPAddress = S.IPAddress AND PTL.DevicePosition = S.Position)
   ELSE
      SET @curPTL = CURSOR FOR
         SELECT PTLKey
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceID IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
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
         SET @nErrNo = 132002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PTL Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPTL INTO @nPTLKey
   END

   COMMIT TRAN rdt_804UnassignSP01
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_804UnassignSP01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO