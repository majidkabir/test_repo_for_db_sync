SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm_Order02                           */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Confirm by order                                               */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 30-08-2016 1.0  Ung        SOS368861 Created                            */
/* 12-04-2017 1.1  Ung        WMS-1603 Auto light up after assign tote     */
/* 07-10-2019 1.2  chermaine  WMS-10753 Add Event Log (cc01)               */
/* 12-09-2023 1.3  Ung        WMS-23635 Add LOC                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Confirm_Order02] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cLight       NVARCHAR( 1)
   ,@cStation     NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cSKU         NVARCHAR( 20)
   ,@cIPAddress   NVARCHAR( 40) OUTPUT
   ,@cPosition    NVARCHAR( 10) OUTPUT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cResult01    NVARCHAR( 20) OUTPUT
   ,@cResult02    NVARCHAR( 20) OUTPUT
   ,@cResult03    NVARCHAR( 20) OUTPUT
   ,@cResult04    NVARCHAR( 20) OUTPUT
   ,@cResult05    NVARCHAR( 20) OUTPUT
   ,@cResult06    NVARCHAR( 20) OUTPUT
   ,@cResult07    NVARCHAR( 20) OUTPUT
   ,@cResult08    NVARCHAR( 20) OUTPUT
   ,@cResult09    NVARCHAR( 20) OUTPUT
   ,@cResult10    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess          INT
   DECLARE @nTranCount        INT
   DECLARE @nQTY_PD           INT

   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cCartonID         NVARCHAR( 20)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cOrderLineNumber  NVARCHAR( 5)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cLoadkey          NVARCHAR( 10)
   DECLARE @cLightMode        NVARCHAR( 4)
   DECLARE @cDisplay          NVARCHAR( 5)
   DECLARE @cLOC              NVARCHAR( 10)
   
   SET @nTranCount = @@TRANCOUNT
   SET @cDisplay = '' 

   -- Check light not yet press
   IF EXISTS( SELECT 1 FROM PTL.LightStatus WITH (NOLOCK) WHERE DeviceID = @cStation AND DisplayValue <> '')
   BEGIN
      SET @nErrNo = 103555
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Light NotPress
      GOTO Quit
   END

   -- Get assign info
   SET @cWaveKey = ''
   SELECT @cWaveKey = WaveKey FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation 
   IF @cWaveKey = ''
      SELECT @cWaveKey = V_WaveKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Find PickDetail to offset
   SET @cOrderKey = ''
   SELECT TOP 1 
      @cOrderKey = O.OrderKey, 
      @cPickDetailKey = PD.PickDetailKey, 
      @nQTY_PD = QTY
   FROM WaveDetail WD WITH (NOLOCK)
      JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.WaveKey = @cWaveKey AND L.Station = @cStation)
   WHERE WD.WaveKey = @cWaveKey
      AND PD.SKU = @cSKU
      AND PD.Status <= '5'
      AND PD.CaseID = ''
      AND PD.QTY > 0
      AND PD.Status <> '4'
      AND O.Status <> 'CANC' 
      AND O.SOStatus <> 'CANC'
   ORDER BY L.RowRef DESC -- Match order with position first

   -- Check blank
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 103551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No order
      GOTO Quit
   END

   -- Get assign info
   SET @cCartonID = ''
   SET @cIPAddress = ''
   SET @cPosition = ''
   SELECT 
      @cCartonID = CartonID, 
      @cIPAddress = IPAddress, 
      @cPosition = Position
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
   WHERE Station = @cStation 
      AND OrderKey = @cOrderKey

   -- Assign order
   IF @cPosition = ''
   BEGIN
      -- Get position not yet assign
      SELECT TOP 1
         @cIPAddress = DP.IPAddress, 
         @cPosition = DP.DevicePosition, 
         @cLOC = DP.LOC
      FROM dbo.DeviceProfile DP WITH (NOLOCK)
      WHERE DP.DeviceType = 'STATION'
         AND DP.DeviceID = @cStation
         AND NOT EXISTS( SELECT 1
            FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)
            WHERE Log.Station = @cStation
               AND Log.Position = DP.DevicePosition)
      ORDER BY DP.LogicalPos, DP.DevicePosition
      
      -- Check position available
      IF @cPosition = ''
      BEGIN
         SET @nErrNo = 103552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPos4NewOrder
         GOTO Quit
      END
      
      -- Save assign
      INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, WaveKey, OrderKey, CartonID, LOC)
      VALUES (@cStation, @cIPAddress, @cPosition, @cWaveKey, @cOrderKey, '', @cLOC)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 103553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS Log fail
         GOTO Quit
      END
   END
   
   -- Update current SKU
   UPDATE rdt.rdtPTLPieceLog SET
      SKU = @cSKU
   WHERE IPAddress = @cIPAddress
      AND Position = @cPosition
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 103556
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLog Fail
      GOTO Quit
   END

   -- EventLog - (cc01)  
   EXEC RDT.rdt_STD_EventLog  
     @cActionType = '3', 
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey,
     @cOrderKey   = @cOrderKey,
     @cSKU        = @cSKU, 
     @nQTY        = @nQTY_PD,
     @cCaseID     = @cCartonID
   
   -- Assign carton ID 
   IF @cCartonID = ''
   BEGIN
      IF @cLight = '1'
      BEGIN
         -- Get light setting
         SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)
   
         -- Off all lights
         EXEC PTL.isp_PTL_TerminateModule
             @cStorerKey
            ,@nFunc
            ,@cStation
            ,'STATION'
            ,@bSuccess    OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
           ,@n_PTLKey         = 0
           ,@c_DisplayValue   = 'TOTE' 
           ,@b_Success        = @bSuccess    OUTPUT    
           ,@n_Err            = @nErrNo      OUTPUT  
           ,@c_ErrMsg         = @cErrMsg     OUTPUT
           ,@c_DeviceID       = @cStation
           ,@c_DevicePos      = @cPosition
           ,@c_DeviceIP       = @cIPAddress  
           ,@c_LModMode       = @cLightMode
         IF @nErrNo <> 0
            GOTO Quit
      END
      
      SET @nErrNo = 103554
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Assign Carton
      SET @nErrNo = 0
      GOTO Quit
   END

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction   

   -- Draw matrix (and light up)
   EXEC rdt.rdt_PTLPiece_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cLight
      ,@cStation
      ,@cMethod
      ,@cSKU
      ,@cIPAddress 
      ,@cPosition
      ,@cDisplay
      ,@nErrNo     OUTPUT
      ,@cErrMsg    OUTPUT
      ,@cResult01  OUTPUT
      ,@cResult02  OUTPUT
      ,@cResult03  OUTPUT
      ,@cResult04  OUTPUT
      ,@cResult05  OUTPUT
      ,@cResult06  OUTPUT
      ,@cResult07  OUTPUT
      ,@cResult08  OUTPUT
      ,@cResult09  OUTPUT
      ,@cResult10  OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran
   
   COMMIT TRAN rdt_PTLPiece_Confirm
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO