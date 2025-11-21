SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Store procedure: rdt_PTLCart_GetTask_PickSeq_XYZ                     */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: rdt_PTLCart_GetTask_PickSeq add XY coord                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */     
/* 15-Apr-2020 1.0  YeeKung     WMS-12353 get the first task (yeekung01)*/   
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_PTLCart_GetTask_PickSeq_XYZ] (    
    @nMobile      INT    
   ,@nFunc        INT    
   ,@cLangCode    NVARCHAR(3)    
   ,@nStep        INT    
   ,@nInputKey    INT    
   ,@cFacility    NVARCHAR(5)    
   ,@cStorerKey   NVARCHAR(15)    
   ,@cType        NVARCHAR(20)  
   ,@cLight       NVARCHAR(1)   
   ,@cCartID      NVARCHAR(10)    
   ,@cPickZone    NVARCHAR(10)    
   ,@cMethod      NVARCHAR(10)    
   ,@cPickSeq     NVARCHAR(10)    
   ,@cToteID      NVARCHAR(20)    
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
   DECLARE @nRowCount   INT    
   DECLARE @nQTY        INT    
   DECLARE @cLogicalLOC NVARCHAR(18)
   DECLARE @cCurrentPickZone NVARCHAR(20)
   DECLARE @nCurrentX INT  
   DECLARE @nCurrentY INT  
   DECLARE @nCurrentDistance INT  =0 
   DECLARE @cNextPickZone NVARCHAR(20)  
    
   -- For LOC    
   IF @cType = 'LOC'     
   BEGIN    
      -- Use light and for LOC    
      IF @cLight = '1'     
         -- Off all lights    
         EXEC dbo.isp_DPC_TerminateAllLight    
             @cStorerKey    
            ,@cCartID    
            ,@bSuccess    OUTPUT    
            ,@nErrNo      OUTPUT    
            ,@cErrMsg     OUTPUT    
    

      -- Get current pickzone,x,y to calculate the shortest distance  
      SELECT TOP 1    
        @cCurrentPickZone= LOC.PickZone,
        @nCurrentX = LOC.Xcoord,
        @nCurrentY=LOC.Ycoord
      FROM PTL.PTLTran PTL WITH (NOLOCK)    
         JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)    
      WHERE PTL.DeviceProfileLogKey = @cDPLKey    
         AND PTL.Status = '0'    
         AND PTL.LOC = @cLOC
         AND PTL.SKU = @cSKU 
        

      -- Get task in same LOC, next SKU    
      SELECT TOP 1    
         @cLOC = PTL.LOC,    
         @cSKU = PTL.SKU,     
         @nQTY = PTL.ExpectedQTY    
      FROM PTL.PTLTran PTL WITH (NOLOCK)    
         JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)    
      WHERE PTL.DeviceProfileLogKey = @cDPLKey    
         AND PTL.Status = '0'    
         AND PTL.LOC = @cLOC    
         AND PTL.SKU > @cSKU    
      ORDER BY PTL.SKU  
       
      -- Get task for next LOC    
      IF @@ROWCOUNT = 0    
      BEGIN    
         DECLARE @cMultiPickerBatch NVARCHAR( 1)    
         SET @cMultiPickerBatch = rdt.RDTGetConfig( @nFunc, 'MultiPickerBatch', @cStorerKey)          
    
         -- Get logical LOC    
         SET @cLogicalLOC = ''    
         SELECT @cLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC    
    
         IF @cPickSeq = '1'    
         BEGIN    
            IF @cLOC = ''    
            BEGIN    
               SET @cLogicalLOC = REPLICATE( 'Z', 18)    
               SET @cLOC = REPLICATE( 'Z', 10)    
            END    
         END    
    
         SET @cSQL = 'SELECT TOP 1 ' +    
            '    @cLOC = PTL.LOC,  ' +     
            '    @cSKU = PTL.SKU,  ' +     
            '    @nQTY = PTL.ExpectedQTY,' + 
            '    @cNextPickZone =  LOC.PickZone'+
            ' FROM PTL.PTLTran PTL WITH (NOLOCK) ' +     
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC) ' +     
            ' WHERE PTL.DeviceProfileLogKey = @cDPLKey ' +     
            '    AND PTL.Status = ''0'' '    
                
         IF @cMultiPickerBatch = '1' AND @cPickZone <> ''    
            SET @cSQL = @cSQL + ' AND LOC.PickZone = @cPickZone '    
                
         IF @cPickSeq = '1'    
            SET @cSQL = @cSQL +     
               ' AND LOC.LogicalLocation + LOC.LOC < @cLogicalLOC + @cLOC ' +     
               ' ORDER BY LOC.PickZone DESC,LOC.LogicalLocation DESC, LOC.LOC DESC, PTL.SKU '    
    
         ELSE    
            SET @cSQL = @cSQL +     
               ' AND LOC.LogicalLocation + LOC.LOC > @cLogicalLOC + @cLOC ' +     
               ' ORDER BY LOC.LogicalLocation, LOC.LOC, PTL.SKU '    
                
         SET @cSQL = @cSQL + ' SELECT @nRowCount = @@ROWCOUNT '     
                
         SET @cSQLParam =    
            ' @cDPLKey     NVARCHAR( 10), ' +    
            ' @cLogicalLOC NVARCHAR( 10), ' +    
            ' @cPickZone   NVARCHAR( 10), ' +    
            ' @cLOC        NVARCHAR( 10) OUTPUT, ' +    
            ' @cSKU        NVARCHAR( 20) OUTPUT, ' +    
            ' @nQTY        INT           OUTPUT, ' +     
            ' @nRowCount   INT           OUTPUT,  ' +
            ' @cNextPickZone NVARCHAR( 20) OUTPUT '  
          
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            @cDPLKey,     
            @cLogicalLOC,     
            @cPickZone,     
            @cLOC       OUTPUT,     
            @cSKU       OUTPUT,     
            @nQTY       OUTPUT,     
            @nRowCount  OUTPUT,
            @cNextPickZone OUTPUT
            
         
         -- Get current pickzone,x,y to calculate the shortest distance  
         IF  @nRowCount<>0 AND @cPickZone = '' AND (@cNextPickZone<>@cCurrentPickZone)
         BEGIN

            DECLARE @cPickLoc NVARCHAR(20),
                    @nNextXCoor INT,
                    @nNextYCoor INT,
                    @nNextDistance INT =0

            DECLARE nDistance CURSOR FOR
            SELECT   LOC.Xcoord,
                     LOC.Ycoord,
                     LOC.LOC
            FROM PTL.PTLTran PTL WITH (NOLOCK)    
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)    
            WHERE PTL.DeviceProfileLogKey = @cDPLKey    
               AND PTL.Status = '0'  
               AND LOC.pickzone=@cNextPickZone

            OPEN nDistance  
            FETCH NEXT FROM nDistance   
            INTO @nNextXCoor, @nNextYCoor,@cPickLoc  
  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  

               SET @nNextDistance=(abs(@nNextXCoor- @nCurrentX) + abs(@nNextYCoor - @nCurrentY))

               IF @nCurrentDistance=0
               BEGIN
                  SET @nCurrentDistance=@nNextDistance
                  SET @cLOC=@cPickLoc
               END
               ELSE IF @nCurrentDistance >@nNextDistance
               BEGIN
                  SET @nCurrentDistance=@nNextDistance
                  SET @cLOC=@cPickLoc
               END

               FETCH NEXT FROM nDistance   
               INTO @nNextXCoor, @nNextYCoor,@cPickLoc  
            END

            CLOSE nDistance;
            DEALLOCATE nDistance;  
            
            SELECT TOP 1     
               @cLOC = PTL.LOC,      
               @cSKU = PTL.SKU,      
               @nQTY = PTL.ExpectedQTY
            FROM PTL.PTLTran PTL WITH (NOLOCK)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)    
            WHERE PTL.DeviceProfileLogKey = @cDPLKey     
                  AND PTL.Status = '0'  
                  AND PTL.LOC=@cLOC
                
           SELECT @nRowCount = @@ROWCOUNT      
     
         END
    
         IF @nRowCount = 0  --yeekung01  
         BEGIN    
            SET @cSQL = 'SELECT TOP 1 ' +    
            '    @cLOC = PTL.LOC,  ' +     
            '    @cSKU = PTL.SKU,  ' +     
            '    @nQTY = PTL.ExpectedQTY ' +     
            ' FROM PTL.PTLTran PTL WITH (NOLOCK) ' +     
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC) ' +     
            ' WHERE PTL.DeviceProfileLogKey = @cDPLKey ' +     
            '    AND PTL.Status = ''0'' '    
                
         IF @cMultiPickerBatch = '1' AND @cPickZone <> ''   
            SET @cSQL = @cSQL + ' AND LOC.PickZone = @cPickZone '    
                  
         IF @cPickSeq = '1'    
            SET @cSQL = @cSQL +     
             ' ORDER BY LOC.PickZone DESC,LOC.LogicalLocation DESC, LOC.LOC DESC, PTL.SKU '    
    
         ELSE    
            SET @cSQL = @cSQL +     
               ' ORDER BY LOC.PickZone,LOC.LogicalLocation, LOC.LOC, PTL.SKU '    
    
         SET @cSQL = @cSQL + ' SELECT @nRowCount = @@ROWCOUNT '     
                
         SET @cSQLParam =                ' @cDPLKey     NVARCHAR( 10), ' +    
            ' @cLogicalLOC NVARCHAR( 10), ' +    
            ' @cPickZone   NVARCHAR( 10), ' +    
            ' @cLOC        NVARCHAR( 10) OUTPUT, ' +    
            ' @cSKU        NVARCHAR( 20) OUTPUT, ' +    
            ' @nQTY        INT           OUTPUT, ' +     
            ' @nRowCount   INT           OUTPUT  '     
          
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            @cDPLKey,     
            @cLogicalLOC,     
            @cPickZone,     
            @cLOC       OUTPUT,     
            @cSKU       OUTPUT,     
            @nQTY       OUTPUT,     
            @nRowCount  OUTPUT    
  
            IF @nRowCount = 0    
            BEGIN    
  
               SET @nErrNo = 152851    
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoTask!'    
               GOTO Quit    
            END  
         END    
      END    
       
      -- Get SKU description    
      DECLARE @cDispStyleColorSize  NVARCHAR( 20)    
      SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)    
          
      IF @cDispStyleColorSize = '0'    
         SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU    
          
      ELSE IF @cDispStyleColorSize = '1'    
         SELECT @cSKUDescr =     
            CAST( Style AS NCHAR(20)) +     
            CAST( Color AS NCHAR(10)) +     
            CAST( Size  AS NCHAR(10))     
         FROM SKU WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey     
            AND SKU = @cSKU    
             
      ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDispStyleColorSize AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cDispStyleColorSize) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +    
            ' @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT '    
         SET @cSQLParam =    
            ' @nMobile    INT,           ' +    
            ' @nFunc      INT,           ' +    
            ' @cLangCode  NVARCHAR( 3),  ' +    
            ' @nStep      INT,           ' +    
            ' @nInputKey  INT,           ' +    
            ' @cFacility  NVARCHAR( 5),  ' +    
            ' @cStorerKey NVARCHAR( 15), ' +    
            ' @cDPLKey    NVARCHAR(10),  ' +    
            ' @cCartID    NVARCHAR(10),  ' +    
            ' @cPickZone  NVARCHAR(10),  ' +    
            ' @cMethod    NVARCHAR(10),  ' +    
            ' @cLOC       NVARCHAR(10),  ' +    
            ' @cSKU       NVARCHAR(20),  ' +    
            ' @cToteID    NVARCHAR(20),  ' +    
            ' @nErrNo     INT          OUTPUT, ' +    
            ' @cErrMsg    NVARCHAR(20) OUTPUT, ' +    
            ' @cSKUDescr  NVARCHAR(60) OUTPUT  '    
          
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,     
            @cDPLKey, @cCartID, @cPickZone, @cMethod, @cLOC, @cSKU, @cToteID, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSKUDescr OUTPUT    
      END    
             
      -- Get total order, QTY    
      SELECT    
         @nTotalPOS = COUNT( DISTINCT DevicePosition),    
         @nTotalQTY = SUM( ExpectedQTY)    
      FROM PTL.PTLTran WITH (NOLOCK)    
    WHERE DeviceProfileLogKey = @cDPLKey    
      AND SKU = @cSKU    
      AND LOC = @cLOC    
      AND Status = '0'    
         
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