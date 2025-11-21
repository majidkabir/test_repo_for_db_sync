SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805MatrixSP02                                   */
/* Copyright      : Mearsk                                              */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 20-02-2018 1.0  ChewKP   WMS-3962 Created                            */
/* 16-06-2023 1.1  Ung      WMS-22703 Add Method param                  */
/************************************************************************/

CREATE   PROC [RDT].[rdt_805MatrixSP02] (
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
          ,@cUserName   NVARCHAR(18) 
          ,@cLoc        NVARCHAR(10) 
          ,@nSumqty     INT
          ,@cWaveKey    NVARCHAR(10) 
          ,@nMultiOrder INT
          ,@cCartonID   NVARCHAR(20)  
          ,@nCount      INT

   DECLARE @tPos TABLE
   (
      Seq       INT IDENTITY(1,1) NOT NULL,
      PTLKey    BIGINT,
      Station   NVARCHAR(10), 
      IPAddress NVARCHAR(40),
      Position  NVARCHAR(5),
      Loc       NVARCHAR(10), 
      QTY       NVARCHAR(5),
      WaveKey   NVARCHAR(10) 
   )

   -- Page control
   IF @nNextPage IS NOT NULL
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @nNextPage = @nNextPage + 1
         IF @nNextPage > 1
            SET @nNextPage = 0
      END
      
      IF @nInputKey = 0 -- ESC
         SET @nNextPage = @nNextPage - 1
   
      IF @nNextPage = 0
         GOTO Quit
   END

   --SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)


   SET @cNoAltRow = rdt.RDTGetConfig( @nFunc, 'MatrixNoAltRow', @cStorerKey)
   SET @cCol = rdt.RDTGetConfig( @nFunc, 'MatrixColumn', @cStorerKey)
   SET @cDelimeter = '|'

   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)
   
   -- Get login info
   SELECT @cMethod = V_String6 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile   
--
--   SELECT @cLightMode = DefaultLightColor 
--      FROm rdt.rdtUser WITH (NOLOCK) 
--   WHERE UserName = @cUserName
      
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

   -- Populate light position
   INSERT INTO @tPos (Station, IPAddress, Position, Loc, QTY)
   SELECT DeviceID, IPAddress, DevicePosition, Loc, 0
   FROM dbo.DeviceProfile WITH (NOLOCK)
   WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
      AND DeviceType = 'STATION'
      AND DeviceID <> ''
   ORDER BY LogicalPOS, IPAddress, DevicePosition

   

   -- Loop each PTL tran
   DECLARE @curPTLTran CURSOR
   SET @curPTLTran = CURSOR FOR
      SELECT T.PTLKey, T.IPAddress, T.DevicePosition, ExpectedQTY, T.SourceKey 
      FROM PTL.PTLTran T WITH (NOLOCK)
         JOIN @tPos P ON (T.IPAddress = P.IPAddress AND T.DevicePosition = P.Position)
      WHERE DropID = @cScanID
         AND SKU = @cSKU
         AND Status <> '9' -- Due to light on, set PTLTran.Status = 1
   OPEN @curPTLTran
   FETCH NEXT FROM @curPTLTran INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY, @cWaveKey 
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update light position QTY
      UPDATE @tPos SET
         PTLKey = @nPTLKey,
         QTY = QTY + @nQTY,
         WaveKey = @cWaveKey
      WHERE IPAddress = @cIPAddress
         AND Position = @cPosition

      
      FETCH NEXT FROM @curPTLTran INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY, @cWaveKey 
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
   
   SET @nCounter = 2 

--   SELECT @nSumQty = SUM(ExpectedQTY) 
--   FROM PTL.PTLTran T WITH (NOLOCK)
--      JOIN @tPos P ON (T.IPAddress = P.IPAddress AND T.DevicePosition = P.Position)
--   WHERE DropID = @cScanID
--      AND SKU = @cSKU
--      AND Status <> '9' -- Due to light on, set PTLTran.Status = 1

   --SET @cResult01 = 'TOTAL QTY: ' + CAST (  @nSumqty  AS NVARCHAR(5) ) 

   -- Loop light position
   DECLARE @curLightPos CURSOR
   SET @curLightPos = CURSOR FOR
      SELECT PTLKey, Station, IPAddress, Position, Loc, QTY
      FROM @tPos
      WHERE Qty > 0 
      ORDER BY Seq
   OPEN @curLightPos
   FETCH NEXT FROM @curLightPos INTO @nPTLKey, @cStation, @cIPAddress, @cPosition, @cLoc, @nQty
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cQTY = ''
      
      --SELECT @cStorerKey '@cStorerKey' , @cWaveKey '@cWaveKey' , @cScanID '@cScanID' , @cSKU '@cSKU' 
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND WaveKey = @cWaveKey 
                  AND DropID = @cScanID
                  AND SKU = @cSKU 
                  AND UOM = '6' ) 
      BEGIN 
         SET @nCount = 2 -- SET as MultiOrder
      END
      ELSE
      BEGIN
         SELECT @nCount = Count(1)  OVER ()
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
              AND WaveKey = @cWaveKey 
              AND DropID = @cScanID
              AND SKU = @cSKU 
         GROUP BY OrderKey 
      END
      --PRINT @nCount
      
      --SET @nCount = @@ROWCount 
      

      IF @nCount > 1 
      BEGIN
         SET @nMultiOrder = 1 
      END
      ELSE  
      BEGIN
         SET @nMultiOrder = 0 
      END
      
     
      

      IF @nMultiOrder = 1 
      BEGIN
         SELECT @cResult02 = @cLoc + ' | ' + CAST( @nQty AS NVARCHAR( 5))
      END
      ELSE IF @nMultiOrder = 0 
      BEGIN
         SET @cResult02 = 'FULL CASE CARTON'
         SET @cResult04 = 'PUT TO CONVEYOR'
      END

      --SELECT @cResult02 '@cResult02' , @cResult04 '@cResult04' 

      -- Format QTY
      --IF @nQty > 0
      --BEGIN
      --   IF (@nCellLen = 1 AND @nQty > 9) OR
      --      (@nCellLen = 2 AND @nQty > 99) OR
      --      (@nCellLen = 3 AND @nQty > 999) OR
      --      (@nCellLen = 4 AND @nQty > 9999) OR
      --      (@nCellLen = 5 AND @nQty > 99999)
      --      SET @cQTY = '*'
      --   ELSE
      --      SET @cQTY = CAST( @nQty AS NVARCHAR( 5))
      --END

      -- Right align
      --SET @cQTY = RIGHT( SPACE( @nCellLen) + RTRIM( @cQTY), @nCellLen)
      --SET @cQty = @cLoc + ' | ' + CAST( @nQty AS NVARCHAR( 5))

      -- Add delimeter
      -- IF @nCounter % @cCol <> 0 -- Last column not add delimeter
      --   SET @cQTY = @cQTY + @cDelimeter

      -- Calc which row to write
      --DECLARE @nWriteRow INT
      --SET @nWriteRow = CEILING(@nCounter / CAST( @cCol AS FLOAT))
      
      -- Alternate row
      --IF @cNoAltRow <> '1'
      --   SET @nWriteRow = (@nWriteRow * 2) - 1

      

      -- Write to screen
--      IF @nWriteRow =  1 SET @cResult01 = @cResult01 + @cQTY ELSE  
--      IF @nWriteRow =  2 SET @cResult02 = @cResult02 + @cQTY ELSE 
--      IF @nWriteRow =  3 SET @cResult03 = @cResult03 + @cQTY ELSE 
--      IF @nWriteRow =  4 SET @cResult04 = @cResult04 + @cQTY ELSE 
--      IF @nWriteRow =  5 SET @cResult05 = @cResult05 + @cQTY ELSE 
--      IF @nWriteRow =  6 SET @cResult06 = @cResult06 + @cQTY ELSE 
--      IF @nWriteRow =  7 SET @cResult07 = @cResult07 + @cQTY ELSE 
--      IF @nWriteRow =  8 SET @cResult08 = @cResult08 + @cQTY ELSE 
--      IF @nWriteRow =  9 SET @cResult09 = @cResult09 + @cQTY ELSE 
--      IF @nWriteRow = 10 SET @cResult10 = @cResult10 + @cQTY



      -- Light up location
      --SET @cLight = '1' 
      --PRINT @nQTY 

      --SELECT @cLight '@cLight' , @nQTY '@nQTY' 

      IF @cLight = '1' AND @nQTY <> 0
      BEGIN
         --PRINT 'asdfasfdaf'
/*       
         EXEC [dbo].[isp_DPC_LightUpLoc]
            @c_StorerKey = @cStorerKey
           ,@n_PTLKey    = @nPTLTranKey
           ,@c_DeviceID  = @cStation
           ,@c_DevicePos = @cPosition
           ,@n_LModMode  = @cLightMode
           ,@n_Qty       = @cQTY
           ,@b_Success   = @bSuccess    OUTPUT
           ,@n_Err       = @nErrNo      OUTPUT
           ,@c_ErrMsg    = @cErrMsg     OUTPUT
*/
         -- Check QTY
         IF @nQTY > 99999
            SET @cQTY = '*'
         ELSE
            SET @cQTY = CAST( @nQTY AS NVARCHAR(5))
            
          -- Check If Full Case No Insert of PTL.PTLTran
         IF @nMultiOrder = 1 
         BEGIN    
            
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
         ELSE IF @nMultiOrder = 0 -- No Light up on Full Carton on Single Order, need to Update PickDetail
         BEGIN
            SELECT @cCartonID = CartonID  
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
            WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
               AND LOC = @cLOC  

            -- Confirm
            EXEC rdt.rdt_PTLStation_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSECARTON'
               ,@cStation1
               ,@cStation2
               ,@cStation3
               ,@cStation4
               ,@cStation5
               ,@cMethod
               ,@cScanID
               ,@cSKU
               ,0  -- @cQTY
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT
               ,@cCartonID
               ,@cQTY
               ,'' -- @cNewCartonID
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF @nMultiOrder = 0 -- No Light up on Full Carton on Single Order, need to Update PickDetail
         BEGIN
            SELECT @cCartonID = CartonID  
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
            WHERE Station IN( @cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
               AND LOC = @cLOC  

             -- Confirm
            EXEC rdt.rdt_PTLStation_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CLOSECARTON'
               ,@cStation1
               ,@cStation2
               ,@cStation3
               ,@cStation4
               ,@cStation5
               ,@cMethod
               ,@cScanID
               ,@cSKU
               ,0  -- @cQTY
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT
               ,@cCartonID
               ,@cQTY
               ,'' -- @cNewCartonID
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      SET @nCounter = @nCounter + 1
      FETCH NEXT FROM @curLightPos INTO @nPTLKey, @cStation, @cIPAddress, @cPosition, @cLoc, @nQty
   END

   --SET @cResult02 = ''
   --SET @cResult03 = ''
   --SET @cResult04 = ''
   --SET @cResult05 = ''
   --SET @cResult06 = ''
   --SET @cResult07 = ''
   --SET @cResult08 = ''
   --SET @cResult09 = ''
   --PRINT @cResult01
   --PRINT @cResult02 
   --PRINT @cResult03 
   --PRINT @cResult04 
   --PRINT @cResult05 
   --PRINT @cResult06 
   --PRINT @cResult07 
   --PRINT @cResult08 
   --PRINT @cResult09 

Quit:

END




GO