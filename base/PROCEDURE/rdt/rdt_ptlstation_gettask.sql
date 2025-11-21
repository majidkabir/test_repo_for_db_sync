SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_GetTask                              */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-02-2016  1.0  Ung         SOS361967 Created                       */
/* 2018-11-21  1.1  James       WMS6952-Allow cartonid = ALL to         */  
/*                              unassign whole ptl station (james01)    */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_GetTask] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR(3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR(5)
   ,@cStorerKey   NVARCHAR(15)
   ,@cType        NVARCHAR(20)  -- CURRENTCARTON/NEXTCARTON
   ,@cLight       NVARCHAR(1)   -- 0 = no light, 1 = use light
   ,@cStation1    NVARCHAR(10)  
   ,@cStation2    NVARCHAR(10)  
   ,@cStation3    NVARCHAR(10)  
   ,@cStation4    NVARCHAR(10)  
   ,@cStation5    NVARCHAR(10)  
   ,@cMethod      NVARCHAR(10)
   ,@cScanID      NVARCHAR(20)
   ,@cSKU         NVARCHAR(20)
   ,@cCartonID    NVARCHAR(20)
   ,@nErrNo       INT          OUTPUT
   ,@cErrMsg      NVARCHAR(20) OUTPUT
   ,@nCartonQTY   INT = 0      OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   
   -- Get method info
   DECLARE @cGetTaskSP SYSNAME
   SET @cGetTaskSP = ''
   SELECT @cGetTaskSP = ISNULL( UDF04, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PTLMethod'
      AND Code = @cMethod
      AND StorerKey = @cStorerKey

   /***********************************************************************************************
                                              Custom get task
   ***********************************************************************************************/
   IF @cGetTaskSP <> ''
   BEGIN
      -- Check get task SP valid
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetTaskSP AND type = 'P')
      BEGIN
         SET @nErrNo = 96901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad GetTask SP
         GOTO Quit
      END
   
      -- Get task SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetTaskSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @cCartonID, ' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @nCartonQTY OUTPUT '
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
         ' @cSKU       NVARCHAR(20), ' +
         ' @cCartonID  NVARCHAR(20), ' +
         ' @nErrNo     INT          OUTPUT, ' +
         ' @cErrMsg    NVARCHAR(20) OUTPUT, ' +
         ' @nCartonQTY INT          OUTPUT  '
   
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cType, @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @cCartonID, 
         @nErrNo OUTPUT, @cErrMsg OUTPUT, @nCartonQTY OUTPUT 
   
      GOTO Quit
   END

   /***********************************************************************************************
                                              Standard get task
   ***********************************************************************************************/
   DECLARE @cIPAddress NVARCHAR(40)
   DECLARE @cPosition  NVARCHAR(10)
   DECLARE @nGroupKey  INT

   -- Get position
   SELECT 
      @cIPAddress = IPAddress, 
      @cPosition = Position, 
      @nGroupKey = RowRef
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
      IF @cCartonID <> 'ALL'
      BEGIN
         IF NOT EXISTS( SELECT 1 
            FROM PTL.PTLTran WITH (NOLOCK)
            WHERE IPAddress = @cIPAddress 
               AND DevicePosition = @cPosition
               AND GroupKey = @nGroupKey
               AND Status <> '9')
            SET @nErrNo = -1 -- No task
      END
      ELSE
      BEGIN
      IF NOT EXISTS( SELECT 1 
         FROM PTL.PTLTran P WITH (NOLOCK)
         WHERE Status <> '9'
         AND   EXISTS ( SELECT 1 FROM
                        rdt.rdtPTLStationLog S WITH (NOLOCK)
                        WHERE P.IPAddress = S.IPAddress
                        AND   P.DevicePosition = S.Position
                        AND   P.GroupKey = S.RowRef))
         SET @nErrNo = -1 -- No task

      END
   END

Quit:

END

GO