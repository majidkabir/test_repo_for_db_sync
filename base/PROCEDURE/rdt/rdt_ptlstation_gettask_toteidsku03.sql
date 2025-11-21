SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_GetTask_ToteIDSKU03                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Get next SKU to Pick                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 20-02-2018 1.0 ChewKP      WMS-3962 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_GetTask_ToteIDSKU03] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT 
   ,@nInputKey  INT 
   ,@cFacility  NVARCHAR(5)
   ,@cStorerKey NVARCHAR(15)
   ,@cType      NVARCHAR(20)
   ,@cLight     NVARCHAR(1)
   ,@cStation1  NVARCHAR(10)  
   ,@cStation2  NVARCHAR(10)  
   ,@cStation3  NVARCHAR(10)  
   ,@cStation4  NVARCHAR(10)  
   ,@cStation5  NVARCHAR(10)  
   ,@cMethod    NVARCHAR(10)
   ,@cScanID    NVARCHAR(20)
   ,@cSKU       NVARCHAR(20)
   ,@cCartonID  NVARCHAR(20)
   ,@nErrNo     INT          OUTPUT
   ,@cErrMsg    NVARCHAR(20) OUTPUT
   ,@nCartonQTY INT = 0      OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cIPAddress  NVARCHAR(40)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @nGroupKey   INT
          ,@cOrderKey   NVARCHAR(10) 
          ,@cWaveKey    NVARCHAR(10) 
   
   SET @nErrNo = 0 
   
   -- Get position
   SELECT 
      @cIPAddress = IPAddress, 
      @cPosition = Position, 
      @nGroupKey = RowRef,
      @cOrderKey = OrderKey,
      @cWaveKey  = WaveKey
   FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND CartonID = @cCartonID
   
   -- For tote
   IF @cType = 'CURRENTCARTON'
   BEGIN
      -- Get current task QTY
      SELECT @nCartonQTY = ISNULL( SUM( ExpectedQTY), 0)
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE IPAddress = @cIPAddress 
         AND DevicePosition = @cPosition
         AND GroupKey = @nGroupKey
         AND DropID = @cScanID
         AND SKU = @cSKU
         AND Status <> '9'
   END
   
   -- For tote
   IF @cType = 'NEXTCARTON'
   BEGIN
      -- Get next task exist
      IF NOT EXISTS( SELECT 1 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND OrderKey = @cOrderKey 
         AND CaseID = '' 
         AND Status <= '5' ) 
       BEGIN
         SET @nErrNo = -1 -- No task
       END
   END
   
   IF @cType = 'CURRENTTASK'
   BEGIN
      
      SELECT TOP 1 @cWaveKey = O.UserDefine09 
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
      WHERE PD.StorerKey = @cStorerKey
      AND PD.DropID = @cScanID

      
      -- Get next task exist
      IF EXISTS( SELECT 1 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         --AND OrderKey = @cOrderKey 
         AND CaseID = '' 
         AND DropID = @cScanID
         AND Status <= '5'
         AND WaveKey = @cWaveKey ) 
       BEGIN
         SET @nErrNo = -1 
       END

      
   END
   
   
Quit:

END

GO