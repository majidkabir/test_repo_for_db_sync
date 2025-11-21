SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_808MatrixSP02                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 26-06-2015 1.0  Ung      SOS332714 Created                           */
/* 16-08-2018 1.1  James    WMS1933-Add col & row (james01)             */
/* 24-04-2019 1.3  Ung      Change to PTL.Schema                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_808MatrixSP02] (
     @nMobile    INT
    ,@nFunc      INT
    ,@cLangCode  NVARCHAR( 3)
    ,@nStep      INT 
    ,@nInputKey  INT
    ,@cFacility  NVARCHAR( 5)
    ,@cStorerKey NVARCHAR( 15)
    ,@cLight     NVARCHAR( 1)
    ,@cCartID    NVARCHAR( 10)
    ,@cPickZone  NVARCHAR( 10)
    ,@cDPLKey    NVARCHAR( 10)
    ,@cLOC       NVARCHAR( 10)
    ,@cSKU       NVARCHAR( 20)
    ,@nErrNo     INT            OUTPUT
    ,@cErrMsg    NVARCHAR(20)   OUTPUT
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
    ,@nNextPage  INT            OUTPUT
    ,@cCol       NVARCHAR( 5) = ''
    ,@cRow       NVARCHAR( 5) = '' 
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT
   DECLARE @nPTLTKey INT
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @nCounter    INT
   DECLARE @cQTY        NVARCHAR(20)
   DECLARE @nQTY        INT
   DECLARE @cLightMode  NVARCHAR(4)
   DECLARE @nCellLen    INT
   DECLARE @nWriteRow   INT
   DECLARE @cDeviceID   NVARCHAR(20)
   DECLARE @cToteID     NVARCHAR(20)

   DECLARE @tPos TABLE
   (
      Seq      INT IDENTITY(1,1) NOT NULL,
      PTLKey   NVARCHAR(10),
      ToteID   NVARCHAR(20),
      Position NVARCHAR(5),
      QTY      NVARCHAR(5)
   )

   -- Change page
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @nNextPage = @nNextPage + 1
      IF @nNextPage > 3
         SET @nNextPage = 0
   END
   
   IF @nInputKey = 0 -- ESC
      SET @nNextPage = @nNextPage - 1

   -- Exit condition
   IF @nNextPage = 0
      GOTO Quit

   -- Get login info
   SELECT @cDeviceID = DeviceID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
   
   -- Loop each PTL tran
   DECLARE @curPTLTran CURSOR
   SET @curPTLTran = CURSOR FOR
      SELECT PTLKey, DevicePosition, ExpectedQTY
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE DeviceProfileLogKey = @cDPLKey
         AND Status = '0'
         AND SKU = @cSKU
         AND LOC = @cLOC
      ORDER BY DevicePosition
   OPEN @curPTLTran
   FETCH NEXT FROM @curPTLTran INTO @nPTLTKey, @cPosition, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get ToteID
      SELECT @cToteID = ToteID FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND Position = @cPosition
      
      -- Populate light position
      IF NOT EXISTS( SELECT 1 FROM @tPos WHERE Position = @cPosition)
         INSERT INTO @tPos (PTLKey, ToteID, Position, QTY)
         VALUES (@nPTLTKey, @cToteID, @cPosition, @nQTY)
      ELSE
         UPDATE @tPos SET
            QTY = QTY + @nQTY
         WHERE Position = @cPosition

      FETCH NEXT FROM @curPTLTran INTO @nPTLTKey, @cPosition, @nQTY
   END
   
   -- Calc page total
   DECLARE @nP1Total INT
   DECLARE @nP2Total INT
   DECLARE @nP3Total INT
   SELECT @nP1Total = ISNULL( SUM( CAST( QTY AS INT)), 0) FROM @tPOS WHERE Seq BETWEEN  1 AND 16
   SELECT @nP2Total = ISNULL( SUM( CAST( QTY AS INT)), 0) FROM @tPOS WHERE Seq BETWEEN 17 AND 32
   SELECT @nP3Total = ISNULL( SUM( CAST( QTY AS INT)), 0) FROM @tPOS WHERE Seq BETWEEN 33 AND 48

   -- Remove page
   IF @nNextPage = 1 DELETE @tPOS WHERE Seq NOT BETWEEN  1 AND 16
   IF @nNextPage = 2 DELETE @tPOS WHERE Seq NOT BETWEEN 17 AND 32
   IF @nNextPage = 3 DELETE @tPOS WHERE Seq NOT BETWEEN 33 AND 48

   -- Exit condition
   IF NOT EXISTS( SELECT 1 FROM @tPOS)
   BEGIN
      SET @nNextPage = 0
      GOTO Quit
   END

   SET @nCounter = 1
   SET @nCellLen = 4
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

   -- Loop light position
   DECLARE @curLightPos CURSOR
   SET @curLightPos = CURSOR FOR
      SELECT PTLKey, ToteID, Position, QTY
      FROM @tPos
      ORDER BY Seq
   OPEN @curLightPos
   FETCH NEXT FROM @curLightPos INTO @nPTLTKey, @cToteID, @cPosition, @nQty
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cQTY = ''
      SET @cToteID = LEFT( @cToteID + SPACE(6), 6)

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
            SET @cQTY = LEFT( CAST( @nQty AS NVARCHAR( 4)) + SPACE( 4), 4)
      END

      -- Calc which row to write
      SET @nWriteRow = @nCounter % 8      -- One column 8 records
      IF @nWriteRow = 0
         SET @nWriteRow = 8               -- The last record in a column
      SET @nWriteRow = @nWriteRow +  1    -- Add title row

      -- Write to screen
      IF @nWriteRow =  1 SET @cResult01 = @cResult01 + @cToteID + @cQTY ELSE  
      IF @nWriteRow =  2 SET @cResult02 = @cResult02 + @cToteID + @cQTY ELSE 
      IF @nWriteRow =  3 SET @cResult03 = @cResult03 + @cToteID + @cQTY ELSE 
      IF @nWriteRow =  4 SET @cResult04 = @cResult04 + @cToteID + @cQTY ELSE 
      IF @nWriteRow =  5 SET @cResult05 = @cResult05 + @cToteID + @cQTY ELSE 
      IF @nWriteRow =  6 SET @cResult06 = @cResult06 + @cToteID + @cQTY ELSE 
      IF @nWriteRow =  7 SET @cResult07 = @cResult07 + @cToteID + @cQTY ELSE 
      IF @nWriteRow =  8 SET @cResult08 = @cResult08 + @cToteID + @cQTY ELSE 
      IF @nWriteRow =  9 SET @cResult09 = @cResult09 + @cToteID + @cQTY ELSE 
      IF @nWriteRow = 10 SET @cResult10 = @cResult10 + @cToteID + @cQTY

      -- Light up location
      IF @cLight = '1' AND @nQTY <> 0
      BEGIN
         EXEC [dbo].[isp_DPC_LightUpLoc]
            @c_StorerKey = @cStorerKey
           ,@n_PTLKey    = @nPTLTKey
           ,@c_DeviceID  = @cCartID
           ,@c_DevicePos = @cPosition
           ,@n_LModMode  = @cLightMode
           ,@n_Qty       = @cQTY
           ,@b_Success   = @bSuccess    OUTPUT
           ,@n_Err       = @nErrNo      OUTPUT
           ,@c_ErrMsg    = @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END

      SET @nCounter = @nCounter + 1
      FETCH NEXT FROM @curLightPos INTO @nPTLTKey, @cToteID, @cPosition, @nQty
   END

   -- Header
   SET @cResult01 = 'TOTE  QTY TOTE  QTY'
   
   -- Footer 
   SET @cResult10 = ''
   IF @nP1Total > 0 SET @cResult10 = @cResult10 + 'P1:' + CASE WHEN @nP1Total > 9999 THEN '*' ELSE CAST( @nP1Total AS NVARCHAR(4)) END + ' '
   IF @nP2Total > 0 SET @cResult10 = @cResult10 + 'P2:' + CASE WHEN @nP2Total > 9999 THEN '*' ELSE CAST( @nP2Total AS NVARCHAR(4)) END + ' '
   IF @nP3Total > 0 SET @cResult10 = @cResult10 + 'P3:' + CASE WHEN @nP3Total > 9999 THEN '*' ELSE CAST( @nP3Total AS NVARCHAR(4)) END

Quit:

END

GO