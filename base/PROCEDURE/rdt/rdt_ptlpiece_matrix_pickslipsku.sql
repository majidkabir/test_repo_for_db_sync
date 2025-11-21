SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLPiece_Matrix_PickSlipSKU                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 09-05-2023 1.0  Ung      WMS-21609 base on rdt_PTLPiece_Matrix       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Matrix_PickSlipSKU] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR( 5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cLight     NVARCHAR( 1)
   ,@cStation   NVARCHAR( 10)
   ,@cMethod    NVARCHAR( 1)
   ,@cSKU       NVARCHAR( 20)
   ,@cIPAddress NVARCHAR( 40)
   ,@cPosition  NVARCHAR( 10)
   ,@cDisplay   NVARCHAR( 5)
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
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @i        INT
   DECLARE @nStart   INT
   DECLARE @nEnd     INT
   DECLARE @nLen     INT
   DECLARE @cCR      NVARCHAR( 1)
   DECLARE @cLF      NVARCHAR( 1)
   DECLARE @cASCII   NVARCHAR( 4000)
   DECLARE @cResult  NVARCHAR( 20)
   DECLARE @cLogicalName NVARCHAR( 10)

   SET @cCR = CHAR( 13)
   SET @cLF = CHAR( 10)
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

   -- Get logical name
   SET @cLogicalName = @cPosition
   SELECT @cLogicalName = LogicalName
   FROM DeviceProfile WITH (NOLOCK)
   WHERE DeviceType = 'STATION'
      AND DeviceID = @cStation
      AND DeviceID <> ''
      AND IPAddress = @cIPAddress
      AND DevicePosition = @cPosition

   -- Get ASCII art
   SET @cASCII = ''
   SELECT TOP 1
      @cASCII = ISNULL( Notes, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PTLASCII'
      AND Code = @cLogicalName
      AND (StorerKey = @cStorerKey OR StorerKey = '')
   ORDER BY StorerKey DESC

   -- Format ASCII art
   IF @cASCII = ''
   BEGIN
      IF @cLogicalName = ''
         SET @cResult01 = @cPosition
      ELSE
         SET @cResult01 = @cLogicalName
   END
   ELSE
   BEGIN
      SET @nStart = 1
      SET @i = 1
      SET @nEnd = CHARINDEX( @cLF, @cASCII)  -- Find delimeter
      SET @nLen = @nEnd
      WHILE @nLen > 0
      BEGIN
         SET @cResult = SUBSTRING( @cASCII, @nStart, @nLen) -- Abstract field
         SET @cResult = REPLACE( @cResult, @cLF, '')        -- Remove line break
         SET @cResult = REPLACE( @cResult, @cCR, '')        -- Remove line break

         --select @cResult '@cResult', @nStart '@nStart', @nEnd '@nEnd', @nLen '@nLen', @i '@i'
         --print @cResult

         -- Map to output
         IF @i = 1  SET @cResult01 = @cResult ELSE
         IF @i = 2  SET @cResult02 = @cResult ELSE
         IF @i = 3  SET @cResult03 = @cResult ELSE
         IF @i = 4  SET @cResult04 = @cResult ELSE
         IF @i = 5  SET @cResult05 = @cResult ELSE
         IF @i = 6  SET @cResult06 = @cResult ELSE
         IF @i = 7  SET @cResult07 = @cResult ELSE
         IF @i = 8  SET @cResult08 = @cResult ELSE
         IF @i = 9  SET @cResult09 = @cResult ELSE
         IF @i = 10 SET @cResult10 = @cResult

         IF @nEnd = 0                                       -- No more delimeter
            BREAK

         SET @i = @i + 1                                    -- Next field
         SET @nStart = @nEnd + 1                            -- Next field starting position
         SET @nEnd = CHARINDEX( @cLF, @cASCII, @nStart)     -- Find next delimeter
         IF @nEnd > 0
            SET @nLen = @nEnd - @nStart
         ELSE
            SET @nLen = LEN( @cASCII)
      END
   END

   /***********************************************************************************************
                                         Show position completed
   ***********************************************************************************************/
   DECLARE @cPickSlipNo NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cPositionCompleted   NVARCHAR( 1) = ''
   DECLARE @cStationCompleted    NVARCHAR( 1) = ''

   -- Get assign info
   SELECT @cPickSlipNo = PickSlipNo
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
   WHERE Station = @cStation
      AND IPAddress = @cIPAddress
      AND Position = @cPosition

   -- Get PickHeader info
   SELECT
      @cZone = Zone,
      @cOrderKey = ISNULL( OrderKey, ''),
      @cLoadKey = ExternOrderKey
   FROM PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      IF NOT EXISTS( SELECT TOP 1 1
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
         WHERE RKL.PickslipNo = @cPickSlipNo
            AND PD.SKU = @cSKU
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status <= '5'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC')
         SET @cPositionCompleted = 'Y'

      IF NOT EXISTS( SELECT TOP 1 1
         FROM Orders O WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
         WHERE RKL.PickslipNo = @cPickSlipNo
            -- AND PD.SKU = @cSKU
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status <= '5'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC')
         SET @cStationCompleted = 'Y'
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      IF NOT EXISTS( SELECT TOP 1 1
         FROM Orders O WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE O.OrderKey = @cOrderKey
            AND PD.SKU = @cSKU
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status <= '5'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC')
         SET @cPositionCompleted = 'Y'

      IF NOT EXISTS( SELECT TOP 1 1
         FROM Orders O WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE O.OrderKey = @cOrderKey
            -- AND PD.SKU = @cSKU
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status <= '5'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC')
         SET @cStationCompleted = 'Y'
   END

   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      IF NOT EXISTS( SELECT TOP 1 1
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE LPD.Loadkey = @cLoadKey
            AND PD.SKU = @cSKU
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status <= '5'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC')
         SET @cPositionCompleted = 'Y'

      IF NOT EXISTS( SELECT TOP 1 1
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE LPD.Loadkey = @cLoadKey
            -- AND PD.SKU = @cSKU
            AND PD.CaseID = ''
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status <= '5'
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC')
         SET @cStationCompleted = 'Y'
   END

   -- Custom PickSlip
   ELSE
   BEGIN
      IF NOT EXISTS( SELECT TOP 1 1
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC')
         SET @cPositionCompleted = 'Y'

      IF NOT EXISTS( SELECT TOP 1 1
      FROM Orders O WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE PD.PickSlipNo = @cPickSlipNo
         -- AND PD.SKU = @cSKU
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND PD.Status <= '5'
         AND O.Status <> 'CANC'
         AND O.SOStatus <> 'CANC')
         SET @cStationCompleted = 'Y'
   END

   IF @cPositionCompleted = 'Y'
      SET @cResult09 = '*POSITION COMPLETED*'

   IF @cStationCompleted = 'Y'
      SET @cResult09 = '**STATION COMPLETED*'

   /***********************************************************************************************
                                                Using light
   ***********************************************************************************************/
   IF @cLight = '1'
   BEGIN
      DECLARE @bSuccess    INT
      DECLARE @cLightMode  NVARCHAR(4)

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

      IF @cDisplay = ''
         SET @cDisplay = '1'

      EXEC PTL.isp_PTL_LightUpLoc
         @n_Func           = @nFunc
        ,@n_PTLKey         = 0
        ,@c_DisplayValue   = @cDisplay
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

Quit:

END

GO