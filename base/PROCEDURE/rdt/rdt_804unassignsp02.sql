SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_804UnassignSP02                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Close station                                               */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-02-2022  1.1  Ung         WMS-18928 Add calc PackInfo.CartonType  */
/************************************************************************/

CREATE PROC [RDT].[rdt_804UnassignSP02] (
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
   DECLARE @cOrderKey  NVARCHAR(10)

   SELECT 
      @cIPAddress = IPAddress, 
      @cPosition = Position, 
      @cOrderKey = OrderKey
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)
   WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND CartonID = @cCartonID

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_804UnassignSP02 -- For rollback or commit only our own transaction

   -- rdtPTLStationLog
   DECLARE @curDPL CURSOR
   SET @curDPL = CURSOR FOR
      SELECT RowRef
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND IPAddress = @cIPAddress
         AND Position = @cPosition
   OPEN @curDPL
   FETCH NEXT FROM @curDPL INTO @nRowRef
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update rdtPTLStationLog
      DELETE rdt.rdtPTLStationLog WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 182751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL LOG Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curDPL INTO @nRowRef
   END

   -- PTLTran
   DECLARE @curPTL CURSOR
   SET @curPTL = CURSOR FOR
      SELECT PTLKey
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE DeviceID IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND IPAddress = @cIPAddress
         AND DevicePosition = @cPosition
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
         SET @nErrNo = 182752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL PTL Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPTL INTO @nPTLKey
   END

   -- Get carton info
   DECLARE @cPickSlipNo NVARCHAR( 10)
   DECLARE @nCartonNo INT
   SELECT TOP 1 
      @cPickSlipNo = @cPickSlipNo, 
      @nCartonNo = CartonNo
   FROM dbo.PackHeader PH WITH (NOLOCK)
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   WHERE PH.OrderKey = @cOrderKey
      AND RefNo = @cCartonID

   -- Get storer info
   DECLARE @cCartonGroup NVARCHAR( 10)
   SELECT @cCartonGroup FROM dbo.Storer WITH (NOLOCK) WHERE StorerKey = @cStorerKey
   
   -- Calc carton cube
   DECLARE @nCube FLOAT
   SELECT @nCube = ISNULL( SUM( SKU.STDCube * PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
   WHERE PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo

   -- Get best fit carton type
   DECLARE @cCartonType NVARCHAR( 10) = ''
   SELECT TOP 1 
      @cCartonType = CartonType
   FROM dbo.Cartonization WITH (NOLOCK)
   WHERE CartonizationGroup = @cCartonGroup
      AND Cube > @nCube
   ORDER BY Cube
   
   -- Get best fit carton type
   IF @cCartonType <> ''
   BEGIN
      UPDATE dbo.PackInfo SET 
         CartonType = @cCartonType, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME()
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 182753
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --UPD PInf Fail
         GOTO RollBackTran
      END 
   END    

   COMMIT TRAN rdt_804UnassignSP02
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_804UnassignSP02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO