SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805MatrixSP06                                   */
/* Copyright      : Mearsk                                              */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 16-06-2023 1.0  Ung      WMS-22703 Created                           */
/************************************************************************/

CREATE   PROC [RDT].[rdt_805MatrixSP06] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR( 5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cLight     NVARCHAR( 1)
   ,@cStation1  NVARCHAR( 10)
   ,@cStation2  NVARCHAR( 10)
   ,@cStation3  NVARCHAR( 10)
   ,@cStation4  NVARCHAR( 10)
   ,@cStation5  NVARCHAR( 10)
   ,@cMethod    NVARCHAR( 1)
   ,@cScanID    NVARCHAR( 20)
   ,@cSKU       NVARCHAR( 20)
   ,@nErrNo     INT            OUTPUT
   ,@cErrMsg    NVARCHAR( 20)  OUTPUT
   ,@cResult01  NVARCHAR( 20)  OUTPUT
   ,@cResult02  NVARCHAR( 20)  OUTPUT
   ,@cResult03  NVARCHAR( 20)  OUTPUT
   ,@cResult04  NVARCHAR( 20)  OUTPUT
   ,@cResult05  NVARCHAR( 20)  OUTPUT
   ,@cResult06  NVARCHAR( 20)  OUTPUT
   ,@cResult07  NVARCHAR( 20)  OUTPUT
   ,@cResult08  NVARCHAR( 20)  OUTPUT
   ,@cResult09  NVARCHAR( 20)  OUTPUT
   ,@cResult10  NVARCHAR( 20)  OUTPUT
   ,@nNextPage  INT = NULL     OUTPUT  -- NULL = refresh current page
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT
   DECLARE @cStation    NVARCHAR(10)
   DECLARE @cIPAddress  NVARCHAR(40)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cQTY        NVARCHAR(20)
   DECLARE @nQTY        INT
   DECLARE @cLightMode  NVARCHAR(4)
   DECLARE @cLOC        NVARCHAR(10)

   SET @cResult01 = ''
   SET @cResult02 = ''
   SET @cResult03 = ''
   SET @cResult04 = ''
   SET @cResult05 = ''
   SET @cResult06 = ''
   SET @cResult07 = ''
   SET @cResult08 = ''
   SET @cResult09 = ''
   SET @cResult10 = ''

   -- Page control
   SET @nNextPage = 0

   -- Get the SKU position
   SELECT TOP 1
      @cStation = Station,
      @cIPAddress = IPAddress,
      @cPosition = Position,
      @cLOC = LOC
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND SKU = @cSKU

   -- Get the QTY (of the ID and SKU)
   SELECT @nQTY = ISNULL( SUM( ExpectedQTY), 0)
   FROM PTL.PTLTran T WITH (NOLOCK)
   WHERE DeviceID = @cStation
      AND IPAddress = @cIPAddress
      AND DevicePosition = @cPosition
      AND DropID = @cScanID
      AND SKU = @cSKU
      AND Status <> '9' -- Due to light on, set PTLTran.Status = 1

   -- Check QTY
   IF @nQTY > 99999
      SET @cQTY = '*'
   ELSE
      SET @cQTY = CAST( @nQTY AS NVARCHAR(5))

   -- Light
   IF @cLight = '1' AND @nQTY <> 0
   BEGIN
      -- Get login info
      SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

      EXEC PTL.isp_PTL_LightUpLoc
         @n_Func           = @nFunc
        ,@n_PTLKey         = 0
        ,@c_DisplayValue   = @cQTY
        ,@b_Success        = @bSuccess    OUTPUT
        ,@n_Err            = @nErrNo      OUTPUT
        ,@c_ErrMsg         = @cErrMsg     OUTPUT
        ,@c_DeviceID       = @cStation
        ,@c_DevicePos      = @cPosition
        ,@c_DeviceIP       = @cIPAddress
        ,@c_LModMode       = @cLightMode
      IF @nErrNo <> 0
         GOTO Quit

      -- Confirm
      EXEC rdt.rdt_PTLStation_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'ID'
         ,@cStation1
         ,@cStation2
         ,@cStation3
         ,@cStation4
         ,@cStation5
         ,@cMethod
         ,@cScanID
         ,@cSKU
         ,@cQTY
         ,@nErrNo     OUTPUT
         ,@cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END
   
   -- Output
   SELECT @cResult02 = @cLOC + ' | ' + CAST( @nQTY AS NVARCHAR( 5))

Quit:

END

GO