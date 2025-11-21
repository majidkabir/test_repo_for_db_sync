SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_GetTask_LOCSKU                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next SKU to Pick                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 25-May-2015 1.0  Ung         SOS336312 Created                       */
/* 16-May-2016 1.1  Ung         SOS361968 Expand ToteID 20 chars        */
/* 15-Jul-2015 1.2  Ung         Support light                           */  
/* 30-Nov-2018 1.3  Ung         INC0457739 Fix skip task                */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_GetTask_LOCSKU] (
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

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @bSuccess INT
   DECLARE @nQTY INT

   -- For LOC
   IF @cType = 'LOC' 
   BEGIN
      -- Use light and for LOC
      IF @cLight = '1' 
         -- Off all lights
         /*
         EXEC dbo.isp_DPC_TerminateAllLight
             @cStorerKey
            ,@cCartID
            ,@bSuccess    OUTPUT
            ,@nErrNo      OUTPUT
            ,@cErrMsg     OUTPUT
         */
         EXEC PTL.isp_PTL_TerminateModule    
             @cStorerKey    
            ,@nFunc    
            ,@cCartID    
            ,'0'    
            ,@bSuccess    OUTPUT    
            ,@nErrNo      OUTPUT    
            ,@cErrMsg     OUTPUT    

   
      IF @nStep = 3 -- SKU (skip task)
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
         ORDER BY LOC.LOC, PTL.SKU      
      ELSE
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
         ORDER BY LOC.LOC, PTL.SKU
   
      IF @@ROWCOUNT = 0
      BEGIN
         -- Get task for next LOC
         SELECT TOP 1
            @cLOC = PTL.LOC,
            @cSKU = PTL.SKU, 
            @nQTY = PTL.ExpectedQTY
         FROM PTL.PTLTran PTL WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
         WHERE PTL.DeviceProfileLogKey = @cDPLKey
            AND PTL.Status = '0'
            AND PTL.LOC > @cLOC
         ORDER BY LOC.LOC, PTL.SKU
   
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 54751
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoTask!'
            GOTO Quit
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
      -- Get next task exist
      IF NOT EXISTS( SELECT 1 
         FROM PTL.PTLTran PTL WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PTL.LOC)
         WHERE PTL.DeviceProfileLogKey = @cDPLKey
            AND PTL.Status = '0'
            AND (PTL.LOC > @cLOC
             OR (PTL.LOC = @cLOC AND SKU > @cSKU))
            AND DevicePosition = @cPosition)
         SET @nErrNo = -1 -- No task
   END
   
Quit:

END

GO