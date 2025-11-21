SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_CloseCart                               */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close working batch                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-Feb-2015 1.0  Ung         SOS332714 Created                       */
/* 14-Aug-2017 1.1  Ung         WMS-2671 Add MultiPickerBatch           */
/* 12-Apr-2019 1.2  Ung         Change to PTL.Schema                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_CloseCart] (
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

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   DECLARE @nRowRef INT
   DECLARE @nPTLKey INT

   DECLARE @cCloseCartSP NVARCHAR( 20)
   SET @cCloseCartSP = rdt.RDTGetConfig( @nFunc, 'CloseCartSP', @cStorerKey)
   IF @cCloseCartSP = '0'
      SET @cCloseCartSP = ''

   /***********************************************************************************************
                                            Custom close cart
   ***********************************************************************************************/
   IF @cCloseCartSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCloseCartSP AND type = 'P')
      BEGIN
         -- Confirm SP
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cCloseCartSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cCartID, @cPickZone, @cDPLKey, @nErrNo OUTPUT, @cErrMsg OUTPUT ' 
         SET @cSQLParam =
            ' @nMobile    INT,           ' +
            ' @nFunc      INT,           ' +
            ' @cLangCode  NVARCHAR( 3),  ' +
            ' @nStep      INT,           ' +
            ' @nInputKey  INT,           ' +
            ' @cFacility  NVARCHAR( 5),  ' +
            ' @cStorerKey NVARCHAR( 15), ' +
            ' @cCartID    NVARCHAR( 10), ' +
            ' @cPickZone  NVARCHAR( 10), ' +
            ' @cDPLKey    NVARCHAR( 10), ' +
            ' @nErrNo     INT            OUTPUT, ' +
            ' @cErrMsg    NVARCHAR( 20)  OUTPUT  '
      
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCartID, @cPickZone, @cDPLKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
         GOTO Quit
      END
   END

   /***********************************************************************************************
                                            Standard close cart
   ***********************************************************************************************/
   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
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
         SET @nErrNo = 53251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL DPL Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curDPL INTO @nRowRef
   END

   -- PTL.PTLTran
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
         SET @nErrNo = 53252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PTL Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPTL INTO @nPTLKey
   END

   COMMIT TRAN rdtfnc_PTL_Cart_CloseCart
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_CloseCart -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO