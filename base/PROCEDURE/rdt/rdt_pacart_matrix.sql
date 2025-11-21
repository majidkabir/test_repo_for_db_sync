SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PACart_Matrix                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 08-10-2015 1.0  Ung      SOS350419 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_PACart_Matrix] (
     @nMobile    INT
    ,@nFunc      INT
    ,@cLangCode  NVARCHAR( 3)
    ,@nStep      INT 
    ,@nInputKey  INT
    ,@cFacility  NVARCHAR( 5)
    ,@cStorerKey NVARCHAR( 15)
    ,@cCartID    NVARCHAR( 10)
    ,@cCol       NVARCHAR( 5)
    ,@cRow       NVARCHAR( 5)
    ,@cLOC       NVARCHAR( 10)
    ,@cSKU       NVARCHAR( 20)
    ,@nErrNo     INT            OUTPUT
    ,@cErrMsg    NVARCHAR(20)   OUTPUT
    ,@cResult01  NVARCHAR( 20)  OUTPUT
    ,@cResult02  NVARCHAR( 20)  OUTPUT
    ,@cResult03  NVARCHAR( 20)  OUTPUT
    ,@cResult04  NVARCHAR( 20)  OUTPUT
    ,@cResult05  NVARCHAR( 20)  OUTPUT
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTotalPOS   INT
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @nCounter    INT
   DECLARE @cQTY        NVARCHAR(20)
   DECLARE @nQTY        INT
   DECLARE @cDelimeter  NVARCHAR(1)
   DECLARE @nCellLen    INT

   DECLARE @tPos TABLE
   (
      Seq      INT IDENTITY(1,1) NOT NULL,
      Position NVARCHAR(5),
      QTY      NVARCHAR(5)
   )

   -- Populate light position
   SET @nTotalPOS = CAST( @cCol AS INT) * CAST( @cRow AS INT)
   SET @nCounter = 1
   WHILE @nCounter <= @nTotalPOS
   BEGIN
      SET @cPosition = RIGHT( '00' + CAST( @nCounter AS NVARCHAR( 2)), 2)
      INSERT INTO @tPos( Position, QTY) VALUES ( @cPosition, '')
      SET @nCounter = @nCounter + 1
   END
   
   -- Loop PA tran
   DECLARE @curPATran CURSOR
   SET @curPATran = CURSOR FOR
      SELECT Position, SUM( QTY)
      FROM rdt.rdtPACartLog L WITH (NOLOCK)
         JOIN RFPutaway R WITH (NOLOCK) ON (L.ToteID = R.FromID)
   	WHERE L.CartID = @cCartID
         AND R.StorerKey = @cStorerKey
   	   AND R.SKU = @cSKU
   	   AND R.SuggestedLOC = @cLOC
   	GROUP BY Position
   OPEN @curPATran
   FETCH NEXT FROM @curPATran INTO @cPosition, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update light position QTY
      UPDATE @tPos SET
         QTY = QTY + @nQTY
      WHERE Position = @cPosition

      FETCH NEXT FROM @curPATran INTO @cPosition, @nQTY
   END

   SET @cDelimeter = '|'
   SET @nCounter = 1
   SET @cResult01 = ''
   SET @cResult02 = ''
   SET @cResult03 = ''
   SET @cResult04 = ''
   SET @cResult05 = ''

   -- Calc cell length (without delimeter)
   IF @cCol = '1'  SET @nCellLen = 19
   IF @cCol = '2'  SET @nCellLen = 9
   IF @cCol = '3'  SET @nCellLen = 5
   IF @cCol = '4'  SET @nCellLen = 4
   IF @cCol = '5'  SET @nCellLen = 3
   IF @cCol = '6'  SET @nCellLen = 2
   IF @cCol = '7'  SET @nCellLen = 1
   IF @cCol = '8'  SET @nCellLen = 1
   IF @cCol = '9'  SET @nCellLen = 1
   IF @cCol = '10' SET @nCellLen = 1

   -- Loop light position
   DECLARE @curLightPos CURSOR
   SET @curLightPos = CURSOR FOR
      SELECT Position, QTY
      FROM @tPos
      ORDER BY Seq
   OPEN @curLightPos
   FETCH NEXT FROM @curLightPos INTO @cPosition, @nQTY
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
      SET @nWriteRow = CEILING(@nCounter / CAST( @cCol AS FLOAT))

      -- Write to screen
      IF @nWriteRow =  1 SET @cResult01 = @cResult01 + @cQTY ELSE  
      IF @nWriteRow =  2 SET @cResult02 = @cResult02 + @cQTY ELSE 
      IF @nWriteRow =  3 SET @cResult03 = @cResult03 + @cQTY ELSE 
      IF @nWriteRow =  4 SET @cResult04 = @cResult04 + @cQTY ELSE 
      IF @nWriteRow =  5 SET @cResult05 = @cResult05 + @cQTY

      SET @nCounter = @nCounter + 1
      FETCH NEXT FROM @curLightPos INTO @cPosition, @nQTY
   END

Quit:

END

GO