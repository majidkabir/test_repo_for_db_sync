SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_PTLStation_GetTask_SEPWaveCriteria              */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Get task and QTY                                            */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 2020-07-13  1.0  James      WMS-13639 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_PTLStation_GetTask_SEPWaveCriteria] (  
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
  
   DECLARE @cIPAddress  NVARCHAR( 40)  
   DECLARE @cPosition   NVARCHAR( 10)  
   DECLARE @cWaveKey    NVARCHAR( 10)  
   DECLARE @cLoadKey    NVARCHAR( 30)  
   DECLARE @cUDF01      NVARCHAR( 30)  
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cDispatchPiecePickMethod   NVARCHAR( 10)
     
   -- Get position  
   SELECT   
      @cIPAddress = IPAddress,   
      @cPosition = Position,   
      @cWaveKey = WaveKey,   
      @cLoadKey = LoadKey,   
      @cUDF01 = UserDefine01,
      @cOrderKey = OrderKey   
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)   
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
      AND CartonID = @cCartonID  

   SELECT @cDispatchPiecePickMethod = DispatchPiecePickMethod
   FROM dbo.Wave WITH (NOLOCK)
   WHERE WaveKey = @cWaveKey

   -- For tote  
   IF @cType = 'CURRENTCARTON'  
   BEGIN  
      -- Get current task QTY  
      SELECT @nCartonQTY = ISNULL( SUM( ExpectedQTY), 0)  
      FROM PTL.PTLTran WITH (NOLOCK)  
      WHERE IPAddress = @cIPAddress   
         AND DevicePosition = @cPosition  
         AND DropID = @cScanID  
         AND SKU = @cSKU  
         AND Status <> '9'  
   END  
     
   -- For tote  
   IF @cType = 'NEXTCARTON'  
   BEGIN  
      IF @cDispatchPiecePickMethod = 'SEPB2BPTS'
      BEGIN
      -- Get next task exist  
      IF NOT EXISTS( SELECT 1   
         FROM dbo.WaveDetail WD WITH (NOLOCK)   
         JOIN dbo.Orders O WITH (NOLOCK) ON ( WD.OrderKey = O.OrderKey)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)  
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.SKU = SKU.Sku AND PD.Storerkey = SKU.StorerKey)
         WHERE WD.WaveKey = @cWaveKey  
         AND   O.LoadKey = @cLoadKey
         AND   SKU.BUSR4 = @cUDF01  
         AND   PD.StorerKey = @cStorerKey  
         AND   PD.DropID = @cScanID  
         AND   PD.Status < '4'  
         AND   PD.QTY > 0  
         AND   PD.UOM <> '2' -- Full carton  
         AND   O.Status <> 'CANC'   
         AND   O.SOStatus <> 'CANC')  
              
         SET @nErrNo = -1 -- No task  
      END
      ELSE
      BEGIN
      -- Get next task exist  
      IF NOT EXISTS( SELECT 1   
         FROM dbo.WaveDetail WD WITH (NOLOCK)   
         JOIN dbo.Orders O WITH (NOLOCK) ON ( WD.OrderKey = O.OrderKey)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)  
         WHERE WD.WaveKey = @cWaveKey  
         AND   O.OrderKey = @cOrderKey  
         AND   PD.StorerKey = @cStorerKey  
         AND   PD.DropID = @cScanID  
         AND   PD.Status < '4'  
         AND   PD.QTY > 0  
         AND   PD.UOM <> '2' -- Full carton  
         AND   O.Status <> 'CANC'   
         AND   O.SOStatus <> 'CANC')  
              
         SET @nErrNo = -1 -- No task  
      END
   END  
     
Quit:  
  
END  

GO