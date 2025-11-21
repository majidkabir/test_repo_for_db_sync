SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[ispHoldBackTheLot] @cTransferKey NVARCHAR(10)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @cSourceKey  NVARCHAR(20),
        @cLine       NVARCHAR(5),
        @cFromLot    NVARCHAR(10),
        @cToLot      NVARCHAR(10),
        @cStatus     NVARCHAR(10)

SELECT @cLine = SPACE(5)

WHILE 1=1
BEGIN
   SET ROWCOUNT 1

   select @cSourceKey = TransferKey + TransferLineNumber,
          @cLine    = TransferLineNumber,
          @cFromLot = FromLOT
   FROM   TRANSFERDETAIL (NOLOCK)
   WHERE  TransferKey = @cTransferKey
   AND    TransferLineNumber > @cLine
   ORDER BY TransferKey, TransferLineNumber

   IF @@ROWCOUNT = 0
      BREAK

   SET ROWCOUNT 0

   IF EXISTS( SELECT 1 FROM INVENTORYHOLD (NOLOCK) WHERE LOT = @cFromLOT and HOLD = '1')
   BEGIN
      SELECT @cStatus = STATUS
      FROM   INVENTORYHOLD (NOLOCK) 
      WHERE LOT = @cFromLOT 
      and HOLD = '1'

      SELECT @cToLot = LOT
      FROM   ITRN (NOLOCK)
      WHERE  SourceKey = @cSourceKey
      AND    SOURCETYPE = 'ntrTransferDetailUpdate'
      AND    TranType = 'DP'

      IF dbo.fnc_RTrim(@cToLOT) IS NOT NULL
      BEGIN
         EXEC nspInventoryHold @cToLot,NULL,NULL,@cStatus,'1', 0, 0, ''

         Print 'Old LOT on Hold ' + @cFromLot + ', New LOT on HOLD ' + @cToLOT 
      END
   END -- if exists in inventory hold
END -- while
SET ROWCOUNT 0




GO