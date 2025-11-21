SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_PTLCart_GetTask_JW                              */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Get next SKU to Pick                                        */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 24-Aug-2016 1.0  James       SOS370883 Created                       */  
/* 26-Jan-2018 1.1  Ung         Change to PTL.Schema                    */
/* 12-Jun-2019 1.2  Ung         Migrate BondDPC to LFLightLink          */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_PTLCart_GetTask_JW] (  
    @nMobile      INT  
   ,@nFunc        INT  
   ,@cLangCode    NVARCHAR(3)  
   ,@nStep        INT  
   ,@nInputKey    INT  
   ,@cFacility    NVARCHAR(5)  
   ,@cStorerKey   NVARCHAR(15)  
   ,@cType        NVARCHAR(20)  -- LOC/CURRENTTOTE/NEXTTOTE  
   ,@cLight       NVARCHAR(1)   -- 0 = no light, 1 = use light  
   ,@cCartID      NVARCHAR(10)  
   ,@cPickZone    NVARCHAR(10)  
   ,@cMethod      NVARCHAR(10)  
   ,@cPickSeq     NVARCHAR(10)  
   ,@cToteID      NVARCHAR(10)  
   ,@cDPLKey      NVARCHAR(10)  
   ,@nErrNo       INT          OUTPUT  
   ,@cErrMsg      NVARCHAR(20) OUTPUT  
   ,@cLOC         NVARCHAR(10) OUTPUT  
   ,@cSKU         NVARCHAR(20) OUTPUT  
   ,@cSKUDescr    NVARCHAR(60) OUTPUT  
   ,@nTotalPOS    INT          OUTPUT  
   ,@nTotalQTY    INT          OUTPUT  
   ,@nToteQTY     INT          OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSQL        NVARCHAR( MAX)  
   DECLARE @cSQLParam   NVARCHAR( MAX)  
   DECLARE @bSuccess    INT  
   DECLARE @nQTY        INT  
   DECLARE @cLogicalLOC NVARCHAR(18)  
  
   -- For LOC  
   IF @cType = 'LOC'   
   BEGIN  
      -- Use light and for LOC  
      IF @cLight = '1'   
         -- Off all lights
         EXEC PTL.isp_PTL_TerminateModule
             @cStorerKey
            ,@nFunc
            ,@cCartID
            ,''
            ,@bSuccess OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
  
      -- Get task in same LOC, next SKU  
      SELECT TOP 1  
         @cLOC = PTL.LOC
      FROM PTL.PTLTran PTL WITH (NOLOCK)  
         JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)  
      WHERE PTL.DeviceProfileLogKey = @cDPLKey  
         AND PTL.Status = '0'  
         AND PTL.LOC = @cLOC  
      ORDER BY PTL.LOC
     
      -- Get task for next LOC  
      IF @@ROWCOUNT = 0  
      BEGIN  
         -- Get logical LOC  
         SET @cLogicalLOC = ''  
         SELECT @cLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC  
  
         SELECT TOP 1  
            @cLOC = PTL.LOC
         FROM PTL.PTLTran PTL WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)  
         WHERE PTL.DeviceProfileLogKey = @cDPLKey                 
         AND   PTL.Status = '0'  
         AND   LOC.LogicalLocation + LOC.LOC > @cLogicalLOC + @cLOC  
         ORDER BY LOC.LogicalLocation, LOC.LOC
     
         IF @@ROWCOUNT = 0  
         BEGIN  
            SET @nErrNo = 103101  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoTask!'  
            GOTO Quit  
         END  
      END  

      GOTO Quit  
   END  

   -- For SKU  
   IF @cType = 'SKU'   
   BEGIN  
      -- Get task in same LOC, next SKU  
      SELECT TOP 1  
         @cSKU = PTL.SKU
      FROM PTL.PTLTran PTL WITH (NOLOCK)  
         JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)  
      WHERE PTL.DeviceProfileLogKey = @cDPLKey  
         AND PTL.Status = '0'  
         AND PTL.LOC = @cLOC  
         AND PTL.SKU > @cSKU  
      ORDER BY PTL.SKU  
     
      -- Get task for next SKU  
      IF @@ROWCOUNT = 0  
      BEGIN  
         SET @nErrNo = 103102  
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'No more sku!'  
         GOTO Quit  
     END

      SELECT @cSKUDescr = DESCR
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU
      
      GOTO Quit  
   END  
   
   -- Get position  
   DECLARE @cPosition NVARCHAR(10)  
   SELECT @cPosition = Position FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID = @cToteID  
     
   -- For tote  
   IF @cType = 'CURRENTTOTE'  
   BEGIN  
      -- Get current task QTY  
      SELECT @nToteQTY = ISNULL( SUM( PTL.ExpectedQTY), 0)  
      FROM PTL.PTLTran PTL WITH (NOLOCK)  
         JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)  
      WHERE PTL.DeviceProfileLogKey = @cDPLKey  
         AND PTL.Status = '0'  
         AND PTL.LOC = @cLOC  
         AND PTL.SKU = @cSKU  
         AND DevicePosition = @cPosition  
   END  
     
   -- For tote  
   IF @cType = 'NEXTTOTE'  
   BEGIN  
      -- Get logical LOC  
      SET @cLogicalLOC = ''  
      SELECT @cLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC  
        
      -- Check next task exist  
      IF @cPickSeq = '1'  
      BEGIN  
         IF NOT EXISTS( SELECT 1   
            FROM PTL.PTLTran PTL WITH (NOLOCK)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)  
            WHERE PTL.DeviceProfileLogKey = @cDPLKey  
  AND PTL.Status = '0'  
               AND (LOC.LogicalLocation + LOC.LOC < @cLogicalLOC + @cLOC  
                OR (LOC.LOC = @cLOC AND SKU > @cSKU))  
               AND DevicePosition = @cPosition)  
            SET @nErrNo = -1 -- No task  
      END  
      ELSE  
      BEGIN  
         IF NOT EXISTS( SELECT 1   
            FROM PTL.PTLTran PTL WITH (NOLOCK)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)  
            WHERE PTL.DeviceProfileLogKey = @cDPLKey  
               AND PTL.Status = '0'  
               AND (LOC.LogicalLocation + LOC.LOC > @cLogicalLOC + @cLOC  
                OR (LOC.LOC = @cLOC AND SKU > @cSKU))  
               AND DevicePosition = @cPosition)  
            SET @nErrNo = -1 -- No task  
      END  
   END  
     
Quit:  
  
END  

GO