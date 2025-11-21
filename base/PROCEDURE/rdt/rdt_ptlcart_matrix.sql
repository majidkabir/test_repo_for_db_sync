SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLCart_Matrix                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 07-04-2015 1.0  Ung      SOS336903 Created                           */
/* 07-04-2018 1.1  James    WMS1933-Add User defined Row X Col (james01)*/
/* 09-01-2018 1.2  Ung      WMS-3549 Add lottables                      */
/* 25-02-2019 1.3  Ung      WMS-8024 Fix lottables                      */
/* 26-10-2021 1.4  LZG      JSM-27261 - Extended column length (ZG01)   */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Matrix] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cLight          NVARCHAR( 1)
   ,@cCartID         NVARCHAR( 10)
   ,@cPickZone       NVARCHAR( 10)
   ,@cDPLKey         NVARCHAR( 10)
   ,@cLOC            NVARCHAR( 10)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottableCode   NVARCHAR( 30)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@dLottable05     DATETIME
   ,@cLottable06     NVARCHAR( 30)
   ,@cLottable07     NVARCHAR( 30)
   ,@cLottable08     NVARCHAR( 30)
   ,@cLottable09     NVARCHAR( 30)
   ,@cLottable10     NVARCHAR( 30)
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME
   ,@dLottable14     DATETIME
   ,@dLottable15     DATETIME
   ,@nErrNo          INT            OUTPUT
   ,@cErrMsg         NVARCHAR(20)   OUTPUT
   ,@cResult01       NVARCHAR( 20)  OUTPUT
   ,@cResult02       NVARCHAR( 20)  OUTPUT
   ,@cResult03       NVARCHAR( 20)  OUTPUT
   ,@cResult04       NVARCHAR( 20)  OUTPUT
   ,@cResult05       NVARCHAR( 20)  OUTPUT
   ,@cResult06       NVARCHAR( 20)  OUTPUT
   ,@cResult07       NVARCHAR( 20)  OUTPUT
   ,@cResult08       NVARCHAR( 20)  OUTPUT
   ,@cResult09       NVARCHAR( 20)  OUTPUT
   ,@cResult10       NVARCHAR( 20)  OUTPUT
   ,@nNextPage       INT = NULL     OUTPUT  -- NULL = refresh current page
   ,@cCol            NVARCHAR( 5) = ''
   ,@cRow            NVARCHAR( 5) = ''
   ,@cMethod         NVARCHAR( 1) = ''
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @nTotalPos   INT
   DECLARE @cDevicePosition      NVARCHAR( 10)
   DECLARE @cLastDevicePosition  NVARCHAR( 10)
   DECLARE @cLottables   NVARCHAR( 1)
   DECLARE @c_ForceColor NVARCHAR(20)

   /***********************************************************************************************

                                             Customize Matrix

   ***********************************************************************************************/
   -- Get method info
   DECLARE @cCartMatrixSP SYSNAME
   SET @cCartMatrixSP = ''
   SELECT @cCartMatrixSP = ISNULL( UDF04, '')
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'CartMethod'
      AND Code = @cMethod
      AND StorerKey = @cStorerKey

   -- Get storer configure
   IF @cCartMatrixSP = ''
   BEGIN
      SET @cCartMatrixSP = rdt.RDTGetConfig( @nFunc, 'CartMatrixSP', @cStorerKey)
      IF @cCartMatrixSP = '0'
         SET @cCartMatrixSP = ''
   END

   -- Custom cart matrix
   IF @cCartMatrixSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCartMatrixSP AND type = 'P')
      BEGIN
         -- Detect lottables
         IF EXISTS( SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID( 'rdt.' + @cCartMatrixSP) AND name = '@cLottableCode')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCartMatrixSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLight, @cCartID, @cPickZone, @cDPLKey, @cLOC, @cSKU, @cLottableCode, ' +
               ' @cLottable01,  @cLottable02,  @cLottable03,  @dLottable04,  @dLottable05, ' +
               ' @cLottable06,  @cLottable07,  @cLottable08,  @cLottable09,  @cLottable10, ' +
               ' @cLottable11,  @cLottable12,  @dLottable13,  @dLottable14,  @dLottable15, ' +
               ' @nErrNo    OUTPUT, @cErrMsg   OUTPUT, ' +
               ' @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT, ' +
               ' @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT, ' +
               ' @nNextPage OUTPUT, @cCol, @cRow '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cLight         NVARCHAR( 1),  ' +
               ' @cCartID        NVARCHAR( 10), ' +
               ' @cPickZone      NVARCHAR( 10), ' +
               ' @cDPLKey        NVARCHAR( 10), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @cLottableCode  NVARCHAR( 30), ' +
               ' @cLottable01    NVARCHAR( 18), ' +
               ' @cLottable02    NVARCHAR( 18), ' +
               ' @cLottable03    NVARCHAR( 18), ' +
               ' @dLottable04    DATETIME,      ' +
               ' @dLottable05    DATETIME,      ' +
               ' @cLottable06    NVARCHAR( 30), ' +
               ' @cLottable07    NVARCHAR( 30), ' +
               ' @cLottable08    NVARCHAR( 30), ' +
               ' @cLottable09    NVARCHAR( 30), ' +
               ' @cLottable10    NVARCHAR( 30), ' +
               ' @cLottable11    NVARCHAR( 30), ' +
               ' @cLottable12    NVARCHAR( 30), ' +
               ' @dLottable13    DATETIME,      ' +
               ' @dLottable14    DATETIME,      ' +
               ' @dLottable15    DATETIME,      ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult01      NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult02      NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult03      NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult04      NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult05      NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult06      NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult07      NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult08      NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult09      NVARCHAR( 20)  OUTPUT, ' +
               ' @cResult10      NVARCHAR( 20)  OUTPUT, ' +
               ' @nNextPage      INT = NULL     OUTPUT, ' +
               ' @cCol           NVARCHAR( 5),  ' +
               ' @cRow           NVARCHAR( 5)   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLight, @cCartID, @cPickZone, @cDPLKey, @cLOC, @cSKU, @cLottableCode,
               @cLottable01,  @cLottable02,  @cLottable03,  @dLottable04,  @dLottable05,
               @cLottable06,  @cLottable07,  @cLottable08,  @cLottable09,  @cLottable10,
               @cLottable11,  @cLottable12,  @dLottable13,  @dLottable14,  @dLottable15,
               @nErrNo    OUTPUT, @cErrMsg   OUTPUT,
               @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,
               @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT,
               @nNextPage OUTPUT, @cCol, @cRow
         END
         ELSE
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCartMatrixSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLight, @cCartID, @cPickZone, @cDPLKey, @cLOC, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT, ' +
               ' @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT, ' +
               ' @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT, ' +
               ' @nNextPage OUTPUT, @cCol, @cRow'
            SET @cSQLParam =
               ' @nMobile    INT,           ' +
               ' @nFunc      INT,           ' +
               ' @cLangCode  NVARCHAR( 3),  ' +
               ' @nStep      INT,           ' +
               ' @nInputKey  INT,           ' +
               ' @cFacility  NVARCHAR( 5),  ' +
               ' @cStorerKey NVARCHAR( 15), ' +
               ' @cLight     NVARCHAR( 1),  ' +
               ' @cCartID    NVARCHAR( 10), ' +
               ' @cPickZone  NVARCHAR( 10), ' +
               ' @cDPLKey    NVARCHAR( 10), ' +
               ' @cLOC       NVARCHAR( 10), ' +
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
               ' @nNextPage  INT = NULL     OUTPUT, ' +
               ' @cCol       NVARCHAR( 5),  ' +
               ' @cRow       NVARCHAR( 5)   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLight, @cCartID, @cPickZone, @cDPLKey, @cLOC, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cResult01 OUTPUT, @cResult02 OUTPUT, @cResult03 OUTPUT, @cResult04 OUTPUT, @cResult05 OUTPUT,
               @cResult06 OUTPUT, @cResult07 OUTPUT, @cResult08 OUTPUT, @cResult09 OUTPUT, @cResult10 OUTPUT,
               @nNextPage OUTPUT, @cCol, @cRow

         END

         GOTO Quit
      END
   END


   /***********************************************************************************************

                                             Stardard Matrix

   ***********************************************************************************************/
   DECLARE @bSuccess    INT
   DECLARE @nPTLTranKey INT
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @nCounter    INT
   DECLARE @cQTY        NVARCHAR(20)
   DECLARE @nQTY        INT
   DECLARE @cLightMode  NVARCHAR(4)
   DECLARE @cDelimeter  NVARCHAR(1)
   DECLARE @nCellLen    INT
   DECLARE @cNoAltRow   NVARCHAR(1)
   DECLARE @cDeviceID   NVARCHAR(20)

   DECLARE @tPos TABLE
   (
      Seq      INT IDENTITY(1,1) NOT NULL,
      PTLKey   NVARCHAR(10),
      --Position NVARCHAR(5),   -- ZG01
      Position NVARCHAR(10),    -- ZG01
      QTY      NVARCHAR(5)
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

   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)
   SET @cNoAltRow = rdt.RDTGetConfig( @nFunc, 'MatrixNoAltRow', @cStorerKey)

   -- If user defined custom col value, forget storerconfig
   IF ISNULL( @cCol, '') = ''
   SET @cCol = rdt.RDTGetConfig( @nFunc, 'MatrixColumn', @cStorerKey)

   SET @cDelimeter = '|'

   -- Get login info
   SELECT @cDeviceID = DeviceID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Check column setup
   IF @cCol = '0'
   BEGIN
      SET @nErrNo = 53351
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SetupMatrixCol
      GOTO Quit
   END

   -- Check column range
   IF @cCol NOT BETWEEN '1' AND '9'
   BEGIN
      SET @nErrNo = 53352
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Col
      GOTO Quit
   END

   SET @nTotalPOS = 0
   SET @cDevicePosition = ''
   SET @cLastDevicePosition = ''

   SET @nTotalPOS = CAST( @cCol AS INT) * CAST( @cRow AS INT)
   IF ISNULL( @nTotalPOS, 0) > 0
   BEGIN
      SET @nCounter = 1
      WHILE @nCounter <= @nTotalPOS
      BEGIN
         -- Populate light position
         SELECT TOP 1 @cDevicePosition = DevicePosition
         FROM dbo.DeviceProfile WITH (NOLOCK)
         WHERE DeviceID = @cCartID
         AND   DevicePosition > @cLastDevicePosition
         GROUP BY DevicePosition
         ORDER BY DevicePosition

         INSERT INTO @tPos (PTLKey, Position, QTY) VALUES
         ('', @cDevicePosition, 0)

         SET @cLastDevicePosition = @cDevicePosition

         SET @nCounter = @nCounter + 1
      END
   END
   ELSE
   BEGIN
      -- Populate light position
      INSERT INTO @tPos (PTLKey, Position, QTY)
      SELECT DISTINCT '', DevicePosition, 0
      FROM dbo.DeviceProfile WITH (NOLOCK)
      WHERE DeviceID = @cCartID
      ORDER BY DevicePosition
   END

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
   FETCH NEXT FROM @curPTLTran INTO @nPTLTranKey, @cPosition, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update light position QTY
      UPDATE @tPos SET
         PTLKey = @nPTLTranKey,
         QTY = QTY + @nQTY
      WHERE Position = @cPosition

      FETCH NEXT FROM @curPTLTran INTO @nPTLTranKey, @cPosition, @nQTY
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
      SELECT PTLKey, Position, QTY
      FROM @tPos
      ORDER BY Seq
   OPEN @curLightPos
   FETCH NEXT FROM @curLightPos INTO @nPTLTranKey, @cPosition, @nQty
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
         IF EXISTS( SELECT 1 FROM PTL.PTLTran WITH (NOLOCK) WHERE PTLKey = @nPTLTranKey AND Status = '0') -- 0=Not light-up, 1=light-up
         BEGIN
--
--            EXEC [dbo].[isp_DPC_LightUpLoc]
--               @c_StorerKey = @cStorerKey
--              ,@n_PTLKey    = @nPTLTranKey
--              ,@c_DeviceID  = @cCartID
--              ,@c_DevicePos = @cPosition
--              ,@n_LModMode  = @cLightMode
--              ,@n_Qty       = @cQTY
--              ,@b_Success   = @bSuccess    OUTPUT
--              ,@n_Err       = @nErrNo      OUTPUT
--              ,@c_ErrMsg    = @cErrMsg     OUTPUT
--            IF @nErrNo <> 0
--               GOTO Quit

              EXEC [ptl].[isp_PTL_LightUpLoc]
               @n_Func      = @nFunc
              ,@n_PTLKey    = @nPTLTranKey
              ,@c_DisplayValue = @nQTY
              ,@b_Success   = @bSuccess    OUTPUT
              ,@n_Err       = @nErrNo      OUTPUT
              ,@c_ErrMsg    = @cErrMsg     OUTPUT
              ,@c_ForceColor = @c_ForceColor

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @nCounter = @nCounter + 1
      FETCH NEXT FROM @curLightPos INTO @nPTLTranKey, @cPosition, @nQty
   END

Quit:

END

GO