SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_801MatrixSP01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Show inner QTY                                              */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 10-07-2019 1.0  Ung      WMS-9372 Created                            */
/* 21-01-2020 1.1  Chermaine WMS-11810 Add Total Qty (cc01)             */
/************************************************************************/

CREATE PROC [RDT].[rdt_801MatrixSP01] (
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
   DECLARE @nPTLKey     BIGINT
   DECLARE @cStation    NVARCHAR(10)
   DECLARE @cIPAddress  NVARCHAR(40)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @nCounter    INT
   DECLARE @cQTY        NVARCHAR(20)
   DECLARE @nQTY        INT
   DECLARE @nTQTY       INT   --(cc01)
   DECLARE @nInnerPack  INT
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
      QTY       NVARCHAR(5), 
      InnerPack INT, 
      PRIMARY KEY CLUSTERED (IPAddress, Position)
   )

   -- Page control
   SET @nNextPage = 0 -- Standard matrix is 1 page only

   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)
   SET @cNoAltRow = rdt.RDTGetConfig( @nFunc, 'MatrixNoAltRow', @cStorerKey)
   SET @cCol = rdt.RDTGetConfig( @nFunc, 'MatrixColumn', @cStorerKey)
   SET @cDelimeter = '|'
   SET @nTQTY = 0 --(cc01)
   
   -- Get login info
   SELECT @cDeviceID = DeviceID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile   
   
   -- Check column setup
   IF @cCol = '0'
   BEGIN
      SET @nErrNo = 140251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMatrixCol
      GOTO Quit
   END

   -- Check column range
   IF @cCol NOT BETWEEN '1' AND '9'
   BEGIN
      SET @nErrNo = 140252
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
   INSERT INTO @tPos (Station, IPAddress, Position, QTY, InnerPack)
   SELECT -- TOP (@nMaxRecOnPage)
      DeviceID, IPAddress, DevicePosition, 0, 0
   FROM dbo.DeviceProfile WITH (NOLOCK)
   WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND DeviceType = 'STATION'
      AND DeviceID <> ''
   ORDER BY LogicalPOS, IPAddress, DevicePosition

   -- Loop each PTL tran
   DECLARE @curPTLTran CURSOR
   SET @curPTLTran = CURSOR FOR
      SELECT T.PTLKey, T.IPAddress, T.DevicePosition, ExpectedQTY, Pack.InnerPack
      FROM PTL.PTLTran T WITH (NOLOCK)
         JOIN SKU WITH (NOLOCK) ON (T.StorerKey = SKU.StorerKey AND T.SKU = SKU.SKU)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         JOIN @tPos P ON (T.IPAddress = P.IPAddress AND T.DevicePosition = P.Position)
         AND Status <> '9' -- Due to light on, set PTLTran.Status = 1
   OPEN @curPTLTran
   FETCH NEXT FROM @curPTLTran INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY, @nInnerPack
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update light position QTY
      UPDATE @tPos SET
         PTLKey = @nPTLKey,
         QTY = QTY + @nQTY, 
         InnerPack = @nInnerPack
      WHERE IPAddress = @cIPAddress
         AND Position = @cPosition

      FETCH NEXT FROM @curPTLTran INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY, @nInnerPack
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
      SELECT PTLKey, Station, IPAddress, Position, QTY, InnerPack
      FROM @tPos
      ORDER BY Seq
   OPEN @curLightPos
   FETCH NEXT FROM @curLightPos INTO @nPTLKey, @cStation, @cIPAddress, @cPosition, @nQTY, @nInnerPack
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cQTY = ''
      
      -- Convert QTY to inner
      IF @nInnerPack > 0
         SET @nQTY = @nQTY / @nInnerPack

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

      --Total Qty --(cc01)
      SET @nTQTY = @nTQTY + @nQty
      
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
      IF @nWriteRow =  9 SET @cResult09 = @cResult09 + @cQTY --ELSE 
      --IF @nWriteRow = 10 SET @cResult10 = @cResult10 + @cQTY

      -- Light up location
      IF @cLight = '1' AND @nQTY <> 0
      BEGIN
         -- Check QTY
         IF @nQTY > 9999
            SET @cQTY = '*'
         ELSE
            SET @cQTY = CAST( @nQTY AS NVARCHAR(4))
         
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
      FETCH NEXT FROM @curLightPos INTO @nPTLKey, @cStation, @cIPAddress, @cPosition, @nQTY, @nInnerPack
   END
   SET @cResult10 = 'Total: ' + CAST( @nTQty AS NVARCHAR( 5))  --(cc01)
Quit:

END

GO