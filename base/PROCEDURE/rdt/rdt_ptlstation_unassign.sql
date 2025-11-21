SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_Unassign                             */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close station                                               */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-Mar-2016 1.0  Ung         SOS361967 Created                       */
/* 21-Nov-2018 1.1  James       WMS6952. Add ext. unassign SP (james01) */
/* 19-Apr-2021 1.2  James       WMS-15658. Add reverse on table         */
/*                              rdtPTLStationLogQueue (james02)         */  
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Unassign] (
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
   DECLARE @cSQL       NVARCHAR(MAX)
   DECLARE @cSQLParam  NVARCHAR(MAX)
   DECLARE @cExtendedUnassignSP  NVARCHAR( 20)
   DECLARE @cPTLStationLogQueue  NVARCHAR( 1)
   
   -- Get storer configure
   SET @cExtendedUnassignSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUnassignSP', @cStorerKey)
   IF @cExtendedUnassignSP = '0'
      SET @cExtendedUnassignSP = ''

   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Custom logic
   IF @cExtendedUnassignSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUnassignSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUnassignSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cCartonID, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile        INT,           ' + 
            ' @nFunc          INT,           ' + 
            ' @cLangCode      NVARCHAR( 3),  ' + 
            ' @nStep          INT,           ' + 
            ' @nInputKey      INT,           ' + 
            ' @cFacility      NVARCHAR( 5),  ' + 
            ' @cStorerKey     NVARCHAR( 15), ' +   
            ' @cStation1      NVARCHAR( 10), ' +   
            ' @cStation2      NVARCHAR( 10), ' +   
            ' @cStation3      NVARCHAR( 10), ' +   
            ' @cStation4      NVARCHAR( 10), ' +   
            ' @cStation5      NVARCHAR( 10), ' +   
            ' @cMethod        NVARCHAR( 10), ' +   
            ' @cCartonID      NVARCHAR( 20), ' +   
            ' @nErrNo         INT           OUTPUT, ' + 
            ' @cErrMsg        NVARCHAR(250) OUTPUT  '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cCartonID, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT 

         GOTO Quit
      END
   END

   SET @cPTLStationLogQueue = rdt.RDTGetConfig( @nFunc, 'PTLStationLogQueue', @cStorerKey)
   
   IF @cCartonID <> ''
      SELECT 
         @cIPAddress = IPAddress, 
         @cPosition = Position
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND CartonID = @cCartonID

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLStation_Unassign -- For rollback or commit only our own transaction

   -- rdtPTLStationLog
   DECLARE @curDPL CURSOR
   IF @cCartonID <> ''
      SET @curDPL = CURSOR FOR
         SELECT RowRef
         FROM rdt.rdtPTLStationLog WITH (NOLOCK)
         WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND IPAddress = @cIPAddress
            AND Position = @cPosition
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
         SET @nErrNo = 97251
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
         FROM PTL.PTLTran WITH (NOLOCK)
         WHERE DeviceID IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND IPAddress = @cIPAddress
            AND DevicePosition = @cPosition
            AND Status <> '9'
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
         SET @nErrNo = 97252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PTL Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPTL INTO @nPTLKey
   END

   -- (james02)
   -- rdtPTLStationLog
   DECLARE @curPTLQueue CURSOR
   IF @cCartonID <> ''
      SET @curPTLQueue = CURSOR FOR
         SELECT RowRef
         FROM rdt.rdtPTLStationLogQueue WITH (NOLOCK)
         WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
            AND IPAddress = @cIPAddress
            AND Position = @cPosition
   ELSE
      SET @curPTLQueue = CURSOR FOR
         SELECT RowRef
         FROM rdt.rdtPTLStationLogQueue WITH (NOLOCK)
         WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)

   OPEN @curPTLQueue
   FETCH NEXT FROM @curPTLQueue INTO @nRowRef
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update rdtPTLStationLog
      UPDATE rdt.rdtPTLStationLogQueue SET 
         DataPopulated = '0',
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE()  
      WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 97253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD QLOG Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPTLQueue INTO @nRowRef
   END
   
   COMMIT TRAN rdt_PTLStation_Unassign
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Unassign -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO