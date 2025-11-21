SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_PTLPiece_Matrix                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 25-04-2016 1.0  Ung      SOS368861 Created                           */
/* 09-05-2023 1.1  Ung      WMS-21609 Add UDF03 as MatrixSP             */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Matrix] (
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

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   /***********************************************************************************************

                                             Customize Matrix

   ***********************************************************************************************/
   -- Get method info
   DECLARE @cStationMatrixSP SYSNAME
   SET @cStationMatrixSP = ''
   SELECT @cStationMatrixSP = ISNULL( UDF03, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PTLPiece'
      AND Code = @cMethod
      AND StorerKey = @cStorerKey

   -- Get storer configure
   IF @cStationMatrixSP = ''
   BEGIN
      SET @cStationMatrixSP = rdt.RDTGetConfig( @nFunc, 'StationMatrixSP', @cStorerKey)
      IF @cStationMatrixSP = '0'
         SET @cStationMatrixSP = ''
   END
   
   -- Custom cart matrix
   IF @cStationMatrixSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cStationMatrixSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cStationMatrixSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cLight, @cStation, @cMethod, @cSKU, @cIPAddress, @cPosition, @cDisplay, @nErrNo OUTPUT, @cErrMsg OUTPUT, ' +
            ' @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT, ' +
            ' @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT  '
         SET @cSQLParam =
            ' @nMobile    INT,           ' +
            ' @nFunc      INT,           ' +
            ' @cLangCode  NVARCHAR( 3),  ' +
            ' @nStep      INT,           ' +
            ' @nInputKey  INT,           ' +
            ' @cFacility  NVARCHAR( 5),  ' +
            ' @cStorerKey NVARCHAR( 15), ' +
            ' @cLight     NVARCHAR( 1),  ' +
            ' @cStation   NVARCHAR( 10), ' +
            ' @cMethod    NVARCHAR( 1),  ' +
            ' @cSKU       NVARCHAR( 20), ' +
            ' @cIPAddress NVARCHAR( 40), ' +
            ' @cPosition  NVARCHAR( 10), ' +
            ' @cDisplay   NVARCHAR( 5),  ' +
            ' @nErrNo     INT            OUTPUT, ' +
            ' @cErrMsg    NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult01  NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult02  NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult03  NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult04  NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult05  NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult06  NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult07  NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult08  NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult09  NVARCHAR( 20)  OUTPUT, ' +
            ' @cResult10  NVARCHAR( 20)  OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cLight, @cStation, @cMethod, @cSKU, @cIPAddress, @cPosition, @cDisplay, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,
            @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT

         GOTO Quit
      END
   END


   /***********************************************************************************************

                                             Stardard Matrix

   ***********************************************************************************************/

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