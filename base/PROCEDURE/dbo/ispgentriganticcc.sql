SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[ispGenTriganticCC] 
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @CCKey  NVARCHAR(10)

CREATE TABLE #Deposit (
   Facility  NVARCHAR(5),
   StorerKey NVARCHAR(15),
   SKU       NVARCHAR(20),
   Qty       int,
   AddDate   datetime  
   ) 

CREATE TABLE #Withdraw (
   Facility NVARCHAR(5),
   StorerKey NVARCHAR(15),
   SKU       NVARCHAR(20),
   Qty       int,
   AddDate   datetime 
) 

TRUNCATE TABLE TriganticCC

SELECT @ccKey = SPACE(10)
WHILE (1=1)
BEGIN
   SELECT @ccKey = MIN(Key1)
   FROM TRIGANTICLOG (NOLOCK)
   WHERE KEY1 > @ccKey
   AND   TABLENAME = 'CCOUNT'
   AND   TransmitFlag = '1'

   IF dbo.fnc_RTrim(@ccKey) IS NULL OR dbo.fnc_RTrim(@ccKey) = ''
      BREAK

   TRUNCATE TABLE #Deposit
   TRUNCATE TABLE #Withdraw

   INSERT INTO #Deposit
   SELECT L.Facility, I.StorerKey, I.SKU, SUM(Qty) as Qty , MAX(I.AddDate)
   FROM ITRN I (NOLOCK) 
   JOIN LOC L (NOLOCK) ON (I.ToLoc = L.LOC)
   WHERE (SourceType = 'CC Deposit (' + @ccKey + ')' AND
          TranType = 'DP')
   GROUP By L.Facility, I.StorerKey, I.SKU

   CREATE INDEX tmp_deposit_ind
      ON #Deposit (Facility, StorerKey, SKU)

   INSERT INTO #Withdraw
   SELECT L.Facility, I.StorerKey, I.SKU, SUM(Qty) as Qty, Max(I.AddDate) 
   FROM ITRN I (NOLOCK) 
   JOIN LOC L (NOLOCK) ON (I.ToLoc = L.LOC)
   WHERE (SourceType = 'CC Withdrawal (' + @ccKey + ')' AND
          TranType = 'WD')
   GROUP BY L.Facility, I.StorerKey, I.SKU

   CREATE INDEX tmp_withdraw_ind
      ON #Withdraw (Facility, StorerKey, SKU)

   INSERT INTO TriganticCC (CCKey, Facility, StorerKey, SKU, AdjCode, AdjCodeDesc, AdjType) 
   SELECT DISTINCT @ccKey, Facility, StorerKey, SKU, 'CC', 'CycleCount', 'CC'
   FROM #Deposit
   UNION
   SELECT DISTINCT @ccKey, Facility, StorerKey, SKU, 'CC', 'CycleCount', 'CC'
   FROM #Withdraw

   UPDATE TriganticCC
   SET    Qty_After = Qty, TriganticCC.AddDate = #Deposit.AddDate
   FROM   TriganticCC, #Deposit
   WHERE  TriganticCC.Facility = #Deposit.Facility
   AND    TriganticCC.StorerKey = #Deposit.StorerKey
   AND    TriganticCC.SKU = #Deposit.SKU
   AND    CCKey = @ccKey 

   UPDATE TriganticCC
   SET    Qty_Before = ABS(Qty), TriganticCC.AddDate = #Withdraw.AddDate
   FROM   TriganticCC, #Withdraw
   WHERE  TriganticCC.Facility = #Withdraw.Facility
   AND    TriganticCC.StorerKey = #Withdraw.StorerKey
   AND    TriganticCC.SKU = #Withdraw.SKU

   DROP INDEX #Deposit.tmp_deposit_ind
   DROP INDEX #Withdraw.tmp_withdraw_ind

END -- WHILE

-- Addded by SHONG on 14-JAN-2004
-- To include Cycle Count Adjustment
DECLARE @cStorerKey  NVARCHAR(15),
        @cSKU        NVARCHAR(20),
        @cFacility   NVARCHAR(10),
        @nQtyAdj     int,
        @cAdjType    NVARCHAR(10),
        @cReasonDesc NVARCHAR(20),
        @nQty        int,
        @cAdjReason  NVARCHAR(10),
        @nQtyBefore  int,
        @dAdjustmentDate datetime   

DECLARE ADJ_CUR CURSOR FAST_FORWARD READ_ONLY FOR  
SELECT LOC.Facility, AJD.StorerKey, AJD.SKU, SUM(AJD.Qty) as Qty_After
FROM TRIGANTICLOG (NOLOCK) 
JOIN ADJUSTMENTDETAIL AJD (NOLOCK) ON (TRIGANTICLOG.Key1 = AJD.AdjustmentKey AND TRIGANTICLOG.Key2 = AJD.AdjustmentLineNumber)
JOIN ADJUSTMENT AJ (NOLOCK) ON (AJ.AdjustmentKey = AJD.AdjustmentKey) 
JOIN LOC (NOLOCK) ON (LOC.LOC = AJD.LOC) 
WHERE TableName = 'CCAdj' AND TransmitFlag = '1'
GROUP BY LOC.Facility, AJD.StorerKey, AJD.SKU 
ORDER BY LOC.Facility, AJD.StorerKey, AJD.SKU


OPEN ADJ_CUR

FETCH NEXT FROM ADJ_CUR INTO @cFacility, @cStorerKey, @cSKU, @nQtyAdj
WHILE @@FETCH_STATUS <> -1
BEGIN
   SET ROWCOUNT 1

   -- Get The Adj Type and reason code for sku with the larger adjusted qty.
   SELECT @cAdjType = AJ.AdjustmentType , 
          @cAdjReason = AJD.ReasonCode,
          @nQty = ABS(AJD.Qty),
          @dAdjustmentDate = AJD.AddDate 
   FROM TRIGANTICLOG (NOLOCK)
   JOIN ADJUSTMENTDETAIL AJD (NOLOCK) ON (TRIGANTICLOG.Key1 = AJD.AdjustmentKey AND TRIGANTICLOG.Key2 = AJD.AdjustmentLineNumber)
   JOIN ADJUSTMENT AJ (NOLOCK) ON (AJ.AdjustmentKey = AJD.AdjustmentKey) 
   ORDER BY ABS(AJD.Qty)  
   
   SELECT @cReasonDesc = Description
   FROM   Codelkup (NOLOCK)
   WHERE  ListName = 'AdjReason'
   AND    Code = @cAdjReason 

   SELECT @nQty = SUM(Qty) 
   FROM   SKUxLOC (NOLOCK)
   JOIN   LOC (NOLOCK) ON (LOC.LOC = SKUxLOC.LOC)
   WHERE  StorerKey = @cStorerKey
   AND    SKU = @cSKU
   AND    LOC.Facility = @cFacility    

   IF @nQtyAdj > 0 
      SELECT @nQtyBefore = @nQty - @nQtyAdj
   ELSE
      SELECT @nQtyBefore = @nQty + ABS(@nQtyAdj)

   INSERT INTO TriganticCC (CCKey, Facility, StorerKey, SKU, Qty_Before, Qty_After, AdjCode, AdjCodeDesc, AdjType, AddDate) 
   VALUES ('ADJXXX', @cFacility, @cStorerkey, @cSKU, @nQtyBefore, @nQty, @cAdjReason, @cReasonDesc, @cAdjType, @dAdjustmentDate)

   FETCH NEXT FROM ADJ_CUR INTO @cFacility, @cStorerKey, @cSKU, @nQtyAdj
END -- While
DEALLOCATE ADJ_CUR 
-- end procedure

GO