SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_803MatrixSP03                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 28-02-2021 1.0  yeekung  WMS-16220 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_803MatrixSP03] (
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

   -- Get assign info
   DECLARE @cOrderKey NVARCHAR( 10)
   SELECT @cOrderKey = OrderKey
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
   WHERE Station = @cStation
      AND IPAddress = @cIPAddress
      AND Position = @cPosition

   -- Check the position is completed
   IF NOT EXISTS( SELECT TOP 1 1
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
         JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = L.OrderKey)
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE L.Station = @cStation
         AND PD.Status <= '5'
         AND PD.CaseID = ''
         AND PD.QTY > 0
         AND PD.Status <> '4'
         AND O.Status <> 'CANC' 
         AND O.SOStatus <> 'CANC')
   BEGIN
      SET @cResult09 = '*** COMPLETED ***'
   END

   exec [PTL].[isp_PTL_Light_TMS]
   @n_Func          = @nFunc
   ,@n_PTLKey        = 0
   ,@b_Success       = 0
   ,@n_Err           = @nErrNo    
   ,@c_ErrMsg        = @cErrMsg OUTPUT
   ,@c_DeviceID      = @cStation
   ,@c_DevicePos     = @cPosition
   ,@c_DeviceIP      = ''
   ,@c_DeviceStatus  = '0'

   IF @nErrNo<>0
      GOTO QUIt

  exec [PTL].[isp_PTL_Light_TMS]
   @n_Func          = @nFunc
   ,@n_PTLKey        = 0
   ,@b_Success       = 0
   ,@n_Err           = @nErrNo    
   ,@c_ErrMsg        = @cErrMsg OUTPUT
   ,@c_DeviceID      = @cStation
   ,@c_DevicePos     = @cPosition
   ,@c_DeviceIP      = ''
   ,@c_DeviceStatus  = '1'

   IF @nErrNo<>0
      GOTO QUIt
   

Quit:

END

GO