SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLStation_Matrix                               */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 07-04-2015 1.0  Ung      SOS336903 Created                           */
/* 11-05-2016 1.1  Ung      SOS361967 Add LogicalPOS                    */
/* 23-08-2018 1.2  Ung      WMS-6027 Remove multi page                  */
/* 04-04-2019 1.3  Ung      INC0645616 Fix not light up, if lights are  */
/*                          more than matrix                            */
/* 19-10-2022 1.4  Ung      WMS-21024 Fix IPAddress not setup           */
/* 16-06-2023 1.5  Ung      WMS-22703 Add MatrixSP as UDF05             */
/*                          Add Method param                            */
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLStation_Matrix] (
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

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   /***********************************************************************************************

                                             Customize Matrix

   ***********************************************************************************************/
   -- Get method info
   DECLARE @cStationtMatrixSP SYSNAME
   SET @cStationtMatrixSP = ''
   SELECT @cStationtMatrixSP = ISNULL( UDF05, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PTLMethod'
      AND Code = @cMethod
      AND StorerKey = @cStorerKey

   -- Get storer configure
   IF @cStationtMatrixSP = ''
   BEGIN
      SET @cStationtMatrixSP = rdt.RDTGetConfig( @nFunc, 'StationMatrixSP', @cStorerKey)
      IF @cStationtMatrixSP = '0'
         SET @cStationtMatrixSP = ''
   END
   
   -- Custom matrix
   IF @cStationtMatrixSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cStationtMatrixSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cStationtMatrixSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT, ' +
            ' @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT, ' +
            ' @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT, ' +
            ' @nNextPage OUTPUT'
         SET @cSQLParam =
            ' @nMobile    INT,           ' +
            ' @nFunc      INT,           ' +
            ' @cLangCode  NVARCHAR( 3),  ' +
            ' @nStep      INT,           ' +
            ' @nInputKey  INT,           ' +
            ' @cFacility  NVARCHAR( 5),  ' +
            ' @cStorerKey NVARCHAR( 15), ' +
            ' @cLight     NVARCHAR( 1),  ' +
            ' @cStation1  NVARCHAR( 10), ' +
            ' @cStation2  NVARCHAR( 10), ' +
            ' @cStation3  NVARCHAR( 10), ' +
            ' @cStation4  NVARCHAR( 10), ' +
            ' @cStation5  NVARCHAR( 10), ' +
            ' @cMethod    NVARCHAR( 1),  ' + 
            ' @cScanID    NVARCHAR( 20), ' +
            ' @cSKU       NVARCHAR( 20), ' +
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
            ' @cResult10  NVARCHAR( 20)  OUTPUT, ' +
            ' @nNextPage  INT = NULL     OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cLight, @cStation1, @cStation2, @cStation3, @cStation4, @cStation5, @cMethod, @cScanID, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,
            @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT,
            @nNextPage OUTPUT

         GOTO Quit
      END
   END


   /***********************************************************************************************

                                             Stardard Matrix

   ***********************************************************************************************/
   DECLARE @bSuccess    INT
   DECLARE @nPTLKey     BIGINT
   DECLARE @cStation    NVARCHAR(10)
   DECLARE @cIPAddress  NVARCHAR(40)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @nCounter    INT
   DECLARE @cQTY        NVARCHAR(20)
   DECLARE @nQTY        INT
   DECLARE @cLightMode  NVARCHAR(4)
   DECLARE @cRow        NVARCHAR(2)
   DECLARE @cCol        NVARCHAR(2)
   DECLARE @cDelimeter  NVARCHAR(1)
   DECLARE @nCellLen    INT
   DECLARE @cNoAltRow   NVARCHAR(1)
   DECLARE @cDeviceID   NVARCHAR(20)
   -- DECLARE @nMaxRecOnPage INT

   DECLARE @tPos TABLE
   (
      Seq       INT IDENTITY(1,1) NOT NULL,
      PTLKey    BIGINT,
      Station   NVARCHAR(10),
      IPAddress NVARCHAR(40),
      Position  NVARCHAR(5),
      QTY       NVARCHAR(5)
   )

   -- Page control
   SET @nNextPage = 0 -- Standard matrix is 1 page only

   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)
   SET @cNoAltRow = rdt.RDTGetConfig( @nFunc, 'MatrixNoAltRow', @cStorerKey)
   SET @cCol = rdt.RDTGetConfig( @nFunc, 'MatrixColumn', @cStorerKey)
   SET @cDelimeter = '|'

   -- Get login info
   SELECT @cDeviceID = DeviceID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Check column setup
   IF @cCol = '0'
   BEGIN
      SET @nErrNo = 96551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMatrixCol
      GOTO Quit
   END

   -- Check column range
   IF @cCol NOT BETWEEN '1' AND '9'
   BEGIN
      SET @nErrNo = 96552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Col
      GOTO Quit
   END

/*
   IF @cNoAltRow = '1'
      SET @nMaxRecOnPage = CAST( @cCol AS INT) * 10
   ELSE
      SET @nMaxRecOnPage = CAST( @cCol AS INT) * 5
*/

   -- Populate light position
   INSERT INTO @tPos (Station, IPAddress, Position, QTY)
   SELECT -- TOP (@nMaxRecOnPage)
      DeviceID, IPAddress, DevicePosition, 0
   FROM dbo.DeviceProfile WITH (NOLOCK)
   WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND DeviceType = 'STATION'
      AND DeviceID <> ''
   ORDER BY LogicalPOS, IPAddress, DevicePosition

   -- Loop each PTL tran
   DECLARE @curPTLTran CURSOR
   SET @curPTLTran = CURSOR FOR
      SELECT T.PTLKey, T.IPAddress, T.DevicePosition, ExpectedQTY
      FROM PTL.PTLTran T WITH (NOLOCK)
         JOIN @tPos P ON (T.IPAddress = P.IPAddress AND T.DevicePosition = P.Position AND T.DeviceID = P.Station)
      WHERE DropID = @cScanID
         AND SKU = @cSKU
         AND Status <> '9' -- Due to light on, set PTLTran.Status = 1
   OPEN @curPTLTran
   FETCH NEXT FROM @curPTLTran INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update light position QTY
      UPDATE @tPos SET
         PTLKey = @nPTLKey,
         QTY = QTY + @nQTY
      WHERE IPAddress = @cIPAddress
         AND Position = @cPosition

      FETCH NEXT FROM @curPTLTran INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY
   END

   SET @nCounter = 1
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

   -- Calc cell length (without delimeter)
   IF @cCol = '1'  SET @nCellLen = 19 ELSE
   IF @cCol = '2'  SET @nCellLen = 9  ELSE
   IF @cCol = '3'  SET @nCellLen = 5  ELSE
   IF @cCol = '4'  SET @nCellLen = 4  ELSE
   IF @cCol = '5'  SET @nCellLen = 3  ELSE
   IF @cCol = '6'  SET @nCellLen = 2  ELSE
   IF @cCol = '7'  SET @nCellLen = 1  ELSE
   IF @cCol = '8'  SET @nCellLen = 1  ELSE
   IF @cCol = '9'  SET @nCellLen = 1  ELSE
   IF @cCol = '10' SET @nCellLen = 1

   -- Loop light position
   DECLARE @curLightPos CURSOR
   SET @curLightPos = CURSOR FOR
      SELECT PTLKey, Station, IPAddress, Position, QTY
      FROM @tPos
      ORDER BY Seq
   OPEN @curLightPos
   FETCH NEXT FROM @curLightPos INTO @nPTLKey, @cStation, @cIPAddress, @cPosition, @nQty
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cQTY = ''

      -- Format QTY
      IF @nQty > 0
      BEGIN
         IF (@nCellLen = 1 AND @nQty > 9) OR
            (@nCellLen = 2 AND @nQty > 99) OR
            (@nCellLen = 3 AND @nQty > 999) OR
            (@nCellLen = 4 AND @nQty > 9999) OR
            (@nCellLen = 5 AND @nQty > 99999)
            SET @cQTY = '*'
         ELSE
            SET @cQTY = CAST( @nQty AS NVARCHAR( 5))
      END

      -- Right align
      SET @cQTY = RIGHT( SPACE( @nCellLen) + RTRIM( @cQTY), @nCellLen)

      -- Add delimeter
      -- IF @nCounter % @cCol <> 0 -- Last column not add delimeter
         SET @cQTY = @cQTY + @cDelimeter

      -- Calc which row to write
      DECLARE @nWriteRow INT
      SET @nWriteRow = CEILING( @nCounter / CAST( @cCol AS FLOAT))

      -- Alternate row
      IF @cNoAltRow <> '1'
         SET @nWriteRow = (@nWriteRow * 2) - 1

      -- Write to screen
      IF @nWriteRow =  1 SET @cResult01 = @cResult01 + @cQTY ELSE
      IF @nWriteRow =  2 SET @cResult02 = @cResult02 + @cQTY ELSE
      IF @nWriteRow =  3 SET @cResult03 = @cResult03 + @cQTY ELSE
      IF @nWriteRow =  4 SET @cResult04 = @cResult04 + @cQTY ELSE
      IF @nWriteRow =  5 SET @cResult05 = @cResult05 + @cQTY ELSE
      IF @nWriteRow =  6 SET @cResult06 = @cResult06 + @cQTY ELSE
      IF @nWriteRow =  7 SET @cResult07 = @cResult07 + @cQTY ELSE
      IF @nWriteRow =  8 SET @cResult08 = @cResult08 + @cQTY ELSE
      IF @nWriteRow =  9 SET @cResult09 = @cResult09 + @cQTY ELSE
      IF @nWriteRow = 10 SET @cResult10 = @cResult10 + @cQTY

      -- Light up location
      IF @cLight = '1' AND @nQTY <> 0
      BEGIN
         -- Check QTY
         IF @nQTY > 99999
            SET @cQTY = '*'
         ELSE
            SET @cQTY = CAST( @nQTY AS NVARCHAR(5))

         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
           ,@n_PTLKey         = @nPTLKey
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
      END

      SET @nCounter = @nCounter + 1
      FETCH NEXT FROM @curLightPos INTO @nPTLKey, @cStation, @cIPAddress, @cPosition, @nQty
   END

Quit:

END

GO