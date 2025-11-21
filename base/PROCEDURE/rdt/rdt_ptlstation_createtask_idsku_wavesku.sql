SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_CreateTask_IDSKU_WaveSKU             */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 12-06-2023 1.0 Ung         WMS-22703 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLStation_CreateTask_IDSKU_WaveSKU] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR(3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR(5)
   ,@cStorerKey   NVARCHAR(15)
   ,@cType        NVARCHAR(20)
   ,@cLight       NVARCHAR(1)   -- 0 = no light, 1 = use light
   ,@cStation1    NVARCHAR(10)
   ,@cStation2    NVARCHAR(10)
   ,@cStation3    NVARCHAR(10)
   ,@cStation4    NVARCHAR(10)
   ,@cStation5    NVARCHAR(10)
   ,@cMethod      NVARCHAR(10)
   ,@cScanID      NVARCHAR(20)      OUTPUT
   ,@cCartonID    NVARCHAR(20)
   ,@nErrNo       INT               OUTPUT
   ,@cErrMsg      NVARCHAR(20)      OUTPUT
   ,@cScanSKU     NVARCHAR(20) = '' OUTPUT
   ,@cSKUDescr    NVARCHAR(60) = '' OUTPUT
   ,@nQTY         INT          = 0  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)

   DECLARE @nRowRef        INT
   DECLARE @cStation       NVARCHAR(10) = ''
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @cWaveKey       NVARCHAR(10) = ''
   DECLARE @cChkWaveKey    NVARCHAR(10) 
   DECLARE @cPTLLOC        NVARCHAR(10) = ''

   SET @nErrNo = 0
   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                              Generate PTLTran
   ***********************************************************************************************/
   -- Get station info (could be 1st task, no WaveKey assigned yet)
   SELECT TOP 1 
      @cWaveKey = WaveKey
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND WaveKey <> ''

   -- Get assigned PTL LOC from TaskDetail
   SELECT TOP 1
      @cChkWaveKey = TD.WaveKey, 
      @cPTLLOC = CASE WHEN TD.FinalLOC <> '' THEN TD.FinalLOC ELSE TD.ToLOC END
   FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)
      JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = TD.FromLOC)
   WHERE TD.TaskType = 'RPF'
      AND TD.WaveKey <> ''
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cScanSKU
      AND PD.ID = @cScanID
      AND PD.CaseID = '' -- Not yet sort
      AND TD.Status = '9'
      AND LOC.Facility = @cFacility

   -- Check task
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 202801
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No task
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
      SET @nErrNo = -1 -- Remain in current screen
      SET @cScanID = ''
      SET @cScanSKU = ''
      GOTO Quit
   END

   -- Get position info
   SELECT
      @cStation = DeviceID,
      @cIPAddress = IPAddress, 
      @cPosition = DevicePosition
   FROM dbo.DeviceProfile WITH (NOLOCK)
   WHERE DeviceType = 'STATION'
      AND StorerKey = @cStorerKey
      AND LOC = @cPTLLOC
      AND LogicalName = 'PTL'

   -- Check position setup
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 202802
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --POS Not Setup
      GOTO Quit
   END

   -- Check pallet for this station
   IF @cStation NOT IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
   BEGIN
      SET @nErrNo = 202803
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Station
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
      SET @nErrNo = -1 -- Remain in current screen
      SET @cScanID = ''
      SET @cScanSKU = ''
      GOTO Quit
   END

   -- Assign wave (1st task)
   IF @cWaveKey = ''
      SET @cWaveKey = @cChkWaveKey

   -- Check wave
   IF @cWaveKey <> @cChkWaveKey
   BEGIN
      SET @nErrNo = 202804
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Wave
      GOTO Quit
   END

   -- Get assign info
   SET @nRowRef = 0
   SELECT @nRowRef = RowRef 
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)
   WHERE Station = @cStation
      AND WaveKey = @cWaveKey
      AND SKU = @cScanSKU
   
   BEGIN TRAN
   SAVE TRAN rdt_PTLStation_CreateTask
   
   -- Save assign
   IF @nRowRef = 0
   BEGIN
      INSERT INTO rdt.rdtPTLStationLog (
         Station, IPAddress, Position, LOC, Method, WaveKey, StorerKey, SKU)
      VALUES (
         @cStation, @cIPAddress, @cPosition, @cPTLLOC, @cMethod, @cWaveKey, @cStorerKey, @cScanSKU)
      
      SELECT @nRowRef = SCOPE_IDENTITY(), @nErrNo = @@ERROR
      
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 202805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
         SET @nErrNo = -1 -- Remain in current screen
         SET @cScanID = ''
         SET @cScanSKU = ''
         GOTO RollBackTran
      END
   END

   -- Check PTLTran generated
   IF NOT EXISTS( SELECT 1
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE DeviceID = @cStation
         AND IPAddress = @cIPAddress 
         AND DevicePosition = @cPosition
         AND GroupKey = @nRowRef
         AND Func = @nFunc
         AND SKU = @cScanSKU
         AND DropID = @cScanID
         AND SourceKey = @cWaveKey)
   BEGIN
      -- Generate PTLTran
      INSERT INTO PTL.PTLTran (
         IPAddress, DevicePosition, DeviceID, PTLType, 
         SourceKey, StorerKey, SKU, ExpectedQTY, QTY, DropID, Func, GroupKey, SourceType)
      SELECT
         @cIPAddress, @cPosition, @cStation, 'STATION', 
         @cWaveKey, @cStorerKey, @cScanSKU, ISNULL( SUM( PD.QTY), 0), 0, @cScanID, @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_IDSKU_WaveSKU'
      FROM Orders O WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      WHERE O.UserDefine09 = @cWaveKey
         AND PD.StorerKey = @cStorerKey
         AND PD.ID = @cScanID
         AND PD.SKU = @cScanSKU
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC'
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 202806
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PTL Fail
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID
         SET @nErrNo = -1 -- Remain in current screen
         SET @cScanID = ''
         SET @cScanSKU = ''
         GOTO RollBackTran
      END
   END
   COMMIT TRAN rdt_PTLStation_CreateTask


   /***********************************************************************************************
                                              Get task info
   ***********************************************************************************************/
   -- Get SKU description
   DECLARE @cDispStyleColorSize  NVARCHAR( 20)
   SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)

   IF @cDispStyleColorSize = '0'
      SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cScanSKU

   ELSE IF @cDispStyleColorSize = '1'
      SELECT @cSKUDescr =
         CAST( Style AS NCHAR(20)) +
         CAST( Color AS NCHAR(10)) +
         CAST( Size  AS NCHAR(10))
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cScanSKU

   ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cCartonID, @cScanSKU, ' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT '
      SET @cSQLParam =
         ' @nMobile    INT,          ' +
         ' @nFunc      INT,          ' +
         ' @cLangCode  NVARCHAR( 3), ' +
         ' @nStep      INT,          ' +
         ' @nInputKey  INT,          ' +
         ' @cFacility  NVARCHAR(5),  ' +
         ' @cStorerKey NVARCHAR(15), ' +
         ' @cType      NVARCHAR(20), ' +
         ' @cLight     NVARCHAR(1),  ' +
         ' @cStation1  NVARCHAR(10), ' +
         ' @cStation2  NVARCHAR(10), ' +
         ' @cStation3  NVARCHAR(10), ' +
         ' @cStation4  NVARCHAR(10), ' +
         ' @cStation5  NVARCHAR(10), ' +
         ' @cMethod    NVARCHAR(10), ' +
         ' @cScanID    NVARCHAR(20), ' +
         ' @cScanSKU   NVARCHAR(20), ' +
         ' @nErrNo     INT          OUTPUT, ' +
         ' @cErrMsg    NVARCHAR(20) OUTPUT, ' +
         ' @cSKUDescr  NVARCHAR(60) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cCartonID, @cScanSKU,
         @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_CreateTask
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO