SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTL_LightUp_CSPC                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Display QTY in CS-PCS, format 9-999                         */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 24-11-2014 1.0  Ung      SOS316714 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTL_LightUp_CSPC] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR( 5)
    ,@cStorerKey       NVARCHAR( 15)
    ,@cCartID          NVARCHAR( 10)
    ,@cSKU             NVARCHAR( 20)
    ,@cLoc             NVARCHAR( 10)
    ,@cLot             NVARCHAR( 10)
    ,@cPDDropID        NVARCHAR( 20)
    ,@cPDLoc           NVARCHAR( 20)
    ,@cPDToLoc         NVARCHAR( 20)
    ,@cLottable01      NVARCHAR( 18)
    ,@cLottable02      NVARCHAR( 18)
    ,@cLottable03      NVARCHAR( 18)
    ,@dLottable04      DATETIME
    ,@dLottable05      DATETIME
    ,@cPDID            NVARCHAR( 20)
    ,@cWaveKey         NVARCHAR( 10)
    ,@cResult01        NVARCHAR( 20)  OUTPUT
    ,@cResult02        NVARCHAR( 20)  OUTPUT
    ,@cResult03        NVARCHAR( 20)  OUTPUT
    ,@cResult04        NVARCHAR( 20)  OUTPUT
    ,@cResult05        NVARCHAR( 20)  OUTPUT
    ,@cResult06        NVARCHAR( 20)  OUTPUT
    ,@cResult07        NVARCHAR( 20)  OUTPUT
    ,@cResult08        NVARCHAR( 20)  OUTPUT
    ,@cResult09        NVARCHAR( 20)  OUTPUT
    ,@cResult10        NVARCHAR( 20)  OUTPUT
    ,@cUserName        NVARCHAR( 18)
    ,@cLangCode        NVARCHAR( 3)
    ,@nErrNo           INT             OUTPUT
    ,@cErrMsg          NVARCHAR(20)    OUTPUT -- screen limitation, 20 char max
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess        INT
   DECLARE @nPTLTranKey     INT
   DECLARE @nExpectedQTY    INT
   DECLARE @cDevicePosition NVARCHAR(10)
   DECLARE @nCounter        INT
   DECLARE @cQTY            NVARCHAR(5)
   DECLARE @nQTY            INT
   DECLARE @nCaseCnt        INT
   DECLARE @nCase           INT
   DECLARE @nPiece          INT
   DECLARE @cCase           NVARCHAR(3)
   DECLARE @cPiece          NVARCHAR(4)
   DECLARE @cLightMode      NVARCHAR(4)
   DECLARE @cDeviceProfileLogKey NVARCHAR(10)

   DECLARE @tPos TABLE
   (
      Seq            INT IDENTITY(1,1) NOT NULL,
      PTLKey         NVARCHAR(10),
      DevicePosition NVARCHAR(5),
      QTY            NVARCHAR(5)
   )

   -- Get storer config
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

   -- Get working batch
   SELECT TOP 1
      @cDeviceProfileLogKey = DeviceProfileLogKey
   FROM dbo.DeviceProfile WITH (NOLOCK)
	WHERE DeviceID = @cCartID
	  AND Status IN ('1', '3')

   -- Get SKU info
   SELECT @nCaseCnt = CAST( CaseCNT AS INT) 
   FROM SKU WITH (NOLOCK)
      JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Populate light position
   INSERT INTO @tPos (PTLKey, DevicePosition, QTY)
   SELECT DISTINCT '', DevicePosition, 0
   FROM dbo.DeviceProfile WITH (NOLOCK)
   WHERE DeviceID = @cCartID
      AND [Status] IN ('1', '3')
   ORDER BY DevicePosition

   -- Loop each PTL tran
   DECLARE curPTLTran CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PTLKey, DevicePosition, ExpectedQTY
      FROM PTLTran WITH (NOLOCK)
      WHERE DeviceProfileLogKey = @cDeviceProfileLogKey
         AND Status = '0'
         AND SKU = @cSKU
         AND LOC = @cLOC
      ORDER BY DevicePosition      
   OPEN curPTLTran
   FETCH NEXT FROM curPTLTran INTO @nPTLTranKey, @cDevicePosition, @nExpectedQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Update light position QTY
      UPDATE @tPos SET
         PTLKey = @nPTLTranKey, 
         QTY = QTY + @nExpectedQTY
      WHERE DevicePosition = @cDevicePosition
   
      FETCH NEXT FROM curPTLTran INTO @nPTLTranKey, @cDevicePosition, @nExpectedQTY
   END
   CLOSE curPTLTran
   DEALLOCATE curPTLTran

   SET @nCounter = 1
   SET @cResult01   = ''
   SET @cResult02   = ''
   SET @cResult03   = ''
   SET @cResult04   = ''
   SET @cResult05   = ''
   SET @cResult06   = ''
   SET @cResult07   = ''
   SET @cResult08   = ''
   SET @cResult09   = ''
   SET @cResult10   = ''

   -- Loop light position
   DECLARE curLightPos CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PTLKey, DevicePosition, QTY
      FROM @tPos
      ORDER BY Seq
   OPEN curLightPos
   FETCH NEXT FROM curLightPos INTO @nPTLTranKey, @cDevicePosition, @nQty
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Calc case and piece
      IF @nCaseCnt <> 0
      BEGIN
         SET @nCase = @nQTY / @nCaseCnt
         SET @nPiece = @nQTY % @nCaseCnt
      END
      ELSE
      BEGIN
         SET @nCase = 0
         SET @nPiece = @nQTY
      END

      SET @cQTY = ''

      -- Format case QTY
      IF @nCase > 0
      BEGIN
         IF @nCase > 9 
            SET @cQTY = '*'
         ELSE
            SET @cQTY = CAST( @nCase AS NVARCHAR( 1))
         SET @cQTY = @cQTY + '-'
      END
      
      -- Format piece QTY
      IF @nPiece >= 0
      BEGIN
         IF @nPiece > 999
            SET @cQTY = @cQTY + '*'
         ELSE 
            SET @cQTY = @cQTY + CAST( @nPiece AS NVARCHAR(3))
      END
      
      -- Right align
      SET @cQTY = RIGHT( SPACE(5) + @cQTY, 5)
      
      -- Light up location
      IF @cResult01 <> 'SKIP' AND @nQTY <> 0
      BEGIN
         EXEC [dbo].[isp_DPC_LightUpLoc]
            @c_StorerKey = @cStorerKey
           ,@n_PTLKey    = @nPTLTranKey
           ,@c_DeviceID  = @cCartID
           ,@c_DevicePos = @cDevicePosition
           ,@n_LModMode  = @cLightMode  
           ,@n_Qty       = @cQTY       
           ,@b_Success   = @bSuccess    OUTPUT
           ,@n_Err       = @nErrNo      OUTPUT
           ,@c_ErrMsg    = @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
      
      IF @nCounter BETWEEN 1 AND 3 SET @cResult01 = @cResult01 + @cQTY + '|'
      IF @nCounter BETWEEN 4 AND 6 SET @cResult02 = @cResult02 + @cQTY + '|'
      IF @nCounter BETWEEN 7 AND 9 SET @cResult03 = @cResult03 + @cQTY + '|'

      SET @nCounter = @nCounter + 1
      FETCH NEXT FROM curLightPos INTO @nPTLTranKey, @cDevicePosition, @nQty
   END
   CLOSE curLightPos
   DEALLOCATE curLightPos

Quit:

END

GO