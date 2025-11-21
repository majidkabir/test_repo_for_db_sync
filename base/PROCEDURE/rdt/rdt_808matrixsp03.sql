SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_808MatrixSP03                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 20-02-2019 1.0  Ung      WMS-8024 Created                            */
/************************************************************************/

CREATE PROC [RDT].[rdt_808MatrixSP03] (
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

   DECLARE @bSuccess    INT
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @nQTY        INT
   DECLARE @cLightMode  NVARCHAR(4)

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

   -- Get position (1 slot = 1 SKU)
   SELECT 
      @cPosition = DevicePosition, 
      @nQTY = ExpectedQTY
   FROM PTL.PTLTran WITH (NOLOCK)
   WHERE DeviceProfileLogKey = @cDPLKey
      AND Status = '0'
      AND SKU = @cSKU
      AND LOC = @cLOC

   IF @@ROWCOUNT > 1
      SELECT @nQTY = ISNULL( SUM( ExpectedQTY), 0)
      FROM PTL.PTLTran WITH (NOLOCK)
      WHERE DeviceProfileLogKey = @cDPLKey
         AND Status = '0'
         AND SKU = @cSKU
         AND LOC = @cLOC

   -- Get logical name
   SET @cLogicalName = @cPosition 
   SELECT @cLogicalName = LogicalName
   FROM DeviceProfile WITH (NOLOCK)
   WHERE DeviceType = 'CART'
      AND DeviceID = @cCartID
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

   -- Show position
   IF @cASCII = ''
   BEGIN
      IF @cLogicalName = ''
         SET @cResult01 = @cPosition
      ELSE
         SET @cResult01 = @cLogicalName
   END
   ELSE
   BEGIN
      -- Format position (in ASCII art)
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
         IF @i = 8  SET @cResult08 = @cResult
      
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

   -- Show QTY
   SET @cResult10 = 'QTY: ' + CAST( @nQTY AS NVARCHAR( 5))

Quit:

END

GO