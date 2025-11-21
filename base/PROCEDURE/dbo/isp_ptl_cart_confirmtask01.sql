SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_PTL_Cart_ConfirmTask01                          */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 24-11-2014 1.0  Ung      SOS316714 Created                           */
/************************************************************************/

CREATE PROC [dbo].[isp_PTL_Cart_ConfirmTask01] (
   @c_MessageNum          NVARCHAR(10),
   @c_IPAddress           NVARCHAR(40),
   @c_LightLoc            NVARCHAR(20),
   @c_Condition           NVARCHAR(20),
   @c_QtyReturn           NVARCHAR(5), 
   @c_StorerKey           NVARCHAR(15),
   @c_DeviceProfileLogKey NVARCHAR(10),
   @n_Err                 INT           OUTPUT, 
   @c_ErrMsg              NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nPOS     INT
   DECLARE @nQTY     INT
   DECLARE @nCase    INT
   DECLARE @nPiece   INT
   DECLARE @nCaseCnt INT
   DECLARE @nPTLKey  INT
   DECLARE @cSKU     NVARCHAR(20)

   SET @nCaseCnt = 0
   SET @nCase = 0
   SET @c_QtyReturn = RTRIM( LTRIM( @c_QtyReturn))

   -- Decode QTY in CS-PCS format
   SET @nPOS = CHARINDEX( '-', @c_QtyReturn)
   IF @nPOS > 0
   BEGIN
      SET @nCase = LEFT( @c_QtyReturn, @nPOS-1)
      SET @nPiece = SUBSTRING( @c_QtyReturn, @nPOS+1, LEN( @c_QtyReturn))
   END
   ELSE
      SET @nPiece = @c_QtyReturn
   
   -- Get PTLTran info
   SELECT TOP 1 
      @nPTLKey = PTLKey, 
      @cSKU = SKU
   FROM PTLTran WITH (NOLOCK)
   WHERE DeviceProfileLogKey = @c_DeviceProfileLogKey
      AND DevicePosition = @c_LightLoc
      AND Status = '1'
   
   -- Get SKU info
   IF @nCase > 0
      SELECT @nCaseCnt = CAST( CaseCnt AS INT)
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @c_StorerKey
         AND SKU = @cSKU
   
   -- Calc QTY
   SET @nQTY = @nCaseCnt * @nCase + @nPiece
   
   -- Update PTLTran
   UPDATE PTLTran WITH (ROWLOCK) SET 
      QTY = @nQTY,
      Status = '9',
      MessageNum = @c_MessageNum,
      EditDate = GETDATE()
   WHERE PTLKey = @nPTLKey
   
END

GO