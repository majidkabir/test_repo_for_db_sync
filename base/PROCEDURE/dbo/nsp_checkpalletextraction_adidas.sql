SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* STORE PROCEDURE: nsp_CheckPalletExtraction_ADIDAS                   */
/* CREATION DATE  : 13-July-2021                                        */
/* WRITTEN BY     : LZG                                                 */
/*                                                                      */
/* PURPOSE: Check for ADIDAS pallet in overflow location                */
/*                                                                      */
/* UPDATES:                                                             */
/*                                                                      */
/* DATE     AUTHOR   VER.  PURPOSES                                     */
/*                                                                      */
/************************************************************************/
CREATE PROCEDURE [dbo].[nsp_CheckPalletExtraction_ADIDAS]
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @cOrderKey       NVARCHAR(10)
         , @cExternOrderKey NVARCHAR(50)
         , @cSKU            NVARCHAR(20)
         , @cPrevSKU        NVARCHAR(20)
         , @cPalletID       NVARCHAR(18)
         , @nOrderQty       INT = 0
         , @nStdSOH         INT = 0
         , @nQtyNeeded      INT = 0
         , @nRemainOrderQty INT = 0
         , @nTotalPLTQty    INT = 0
         , @nAvailPLTQty    INT = 0
         , @bIsFinished     INT = 0
         , @nRowRef         INT = 0
         , @nLLI_RowRef     INT = 0
         , @nExcess_RowRef  INT = 0
         , @nExcessPLTQty   INT = 0
         , @nRemainPLTQty   INT = 0

   IF OBJECT_ID('TEMPDB..#PLTCandidates') IS NOT NULL
       DROP TABLE #PLTCandidates
   CREATE TABLE #PLTCandidates (
        ID             INT IDENTITY(1,1)
      , OrderKey       NVARCHAR(10) NULL
      , ExternOrderKey NVARCHAR(50)
      , PalletID       NVARCHAR(18)
      , SKU            NVARCHAR(20)
      , OrderQty       INT
      , PalletQty      INT
   )

   --SY: TEMP TABLE TO STORE STANDARD LOCATIONS AVAILABLEQTY
   IF OBJECT_ID('TEMPDB..#LLI_STAND') IS NOT NULL
         DROP TABLE #LLI_STAND

   SELECT SKU,SUM(Qty - QtyAllocated - QtyPicked) AS AVAILQTY INTO #LLI_STAND FROM LotxLocxID (NOLOCK)
   WHERE StorerKey = 'ADIDAS'
   AND Qty > 0
   AND (TRIM(Loc) NOT LIKE 'DRO%' AND TRIM(Loc) NOT IN ('4PLSTD','4PLQI'))
   GROUP BY SKU

   -- Check SKUs to be fulfilled
   SELECT IDENTITY(INT, 1, 1) AS RowRef, OrderKey, ExternOrderKey, SKU, SUM(OriginalQty) 'OrderQty' INTO #TempTable FROM OrderDetail (NOLOCK)
   WHERE StorerKey = 'ADIDAS'
   AND Status = '0'
   --AND SKU = 'BB5379-610'
   GROUP BY OrderKey, ExternOrderKey, SKU
   ORDER BY SKU

   DECLARE CUR_ORD CURSOR FAST_FORWARD READ_ONLY FOR SELECT OrderKey, ExternOrderKey, SKU, OrderQty FROM #TempTable ORDER BY RowRef
   OPEN CUR_ORD
   FETCH NEXT FROM CUR_ORD INTO @cOrderKey, @cExternOrderKey, @cSKU, @nOrderQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @nRowRef = 0
      SET @bIsFinished = 0
      SET @nQtyNeeded = 0
      SET @nStdSOH = 0
      SET @cPalletID = ''
      SET @nRemainOrderQty = @nOrderQty

      -- Reset RowRef for new SKU
      IF @cPrevSKU <> @cSKU
         SET @nLLI_RowRef = 0

      IF OBJECT_ID('TEMPDB..#LLI') IS NOT NULL
         DROP TABLE #LLI
      -- Get SOH in overflow locations
      --SELECT IDENTITY(INT, 1, 1) AS LLI_RowRef, * INTO #LLI FROM LotxLocxID (NOLOCK) --SY
      SELECT IDENTITY(INT, 1, 1) AS LLI_RowRef, SKU,ID,SUM(QTY) AS QTY INTO #LLI FROM LotxLocxID (NOLOCK) --SY
      WHERE StorerKey = 'ADIDAS'
      AND Qty > 0
      AND (TRIM(Loc) LIKE 'DRO%' OR TRIM(Loc) IN ('4PLSTD','4PLQI'))
      AND SKU = @cSKU
      GROUP BY SKU,ID
      ORDER BY Qty

      -- Get SOH in standard locations
      /*
      SELECT @nStdSOH = SUM(Qty - QtyAllocated - QtyPicked) FROM LotxLocxID (NOLOCK)
      WHERE StorerKey = 'ADIDAS'
      AND Qty > 0
      AND (TRIM(Loc) NOT LIKE 'DRO%' AND TRIM(Loc) NOT IN ('4PLSTD','4PLQI'))
      AND SKU = @cSKU
      */
      --SY
      SELECT @nStdSOH = AVAILQTY FROM #LLI_STAND (NOLOCK)
      WHERE SKU = @cSKU
      AND AVAILQty > 0

      SET @nQtyNeeded = ISNULL(@nStdSOH - @nOrderQty, -1)

      --SY: REDUCE STANDARD LOCATION QTY
      IF(@nQtyNeeded >= 0)
      BEGIN
           UPDATE #LLI_STAND SET AVAILQTY = AVAILQTY - @nOrderQty
           WHERE SKU = @cSKU
           AND AVAILQty > 0
      END

      PRINT ('@cOrderKey: ' + @cOrderKey + ', @nStdSOH: ' + CAST(@nStdSOH AS NVARCHAR) + ', @nOrderQty: ' + CAST(@nOrderQty AS NVARCHAR) + ', @nQtyNeeded: ' + CAST(@nQtyNeeded AS NVARCHAR))

      -- Pull from overflow locations if insufficient standard SOH
      WHILE @nQtyNeeded < 0 AND @bIsFinished = 0
      BEGIN
         SET @nAvailPLTQty = 0

         /*SELECT TOP 1 @nRowRef '@nRowRef', MAX(PalletQty) - SUM(OrderQty) 'AvailPLTQty' FROM #PLTCandidates
         WHERE SKU = @cSKU
         AND ID > @nRowRef
         GROUP BY PalletID
         HAVING MAX(PalletQty) - SUM(OrderQty) >= @nRemainOrderQty*/

         -- Check pallet candidates if still have enough Qty to spare in pallet level
         SELECT TOP 1 @nRowRef = MAX(ID), @cPalletID = PalletID, @nAvailPLTQty = MAX(PalletQty) - SUM(OrderQty), @nTotalPLTQty = MAX(PalletQty) FROM #PLTCandidates
         WHERE SKU = @cSKU
         AND ID > @nRowRef
         GROUP BY PalletID
         HAVING MAX(PalletQty) - SUM(OrderQty) >= @nRemainOrderQty

         --SELECT '#PLTCandidates', * FROM #PLTCandidates (NOLOCK)
         --SELECT '#LLI', @nLLI_RowRef, * FROM #LLI (NOLOCK)
         PRINT ('@cSKU: ' + CAST(@cSKU AS NVARCHAR) + ', @nAvailPLTQty: ' + CAST(@nAvailPLTQty AS NVARCHAR) + ', @cPalletID: ' + CAST(@cPalletID AS NVARCHAR) + ', @nTotalPLTQty: ' + CAST(@nTotalPLTQty AS NVARCHAR))

         -- If pallet candidates have insufficient balance, then pull from new pallet in overflow locations
         IF ISNULL(@nAvailPLTQty, 0) <= 0
         BEGIN
            -- Check pallet candidates if still have enough Qty to spare
            SET @nExcessPLTQty = 0
            SELECT @nExcessPLTQty = SUM(Qty) - SUM(SumOrder) FROM #LLI L (NOLOCK)
            CROSS APPLY (
               SELECT SUM(OrderQty) 'SumOrder' FROM #PLTCandidates P (NOLOCK)
               WHERE SKU = L.SKU
               AND PalletID = L.ID
            ) PLT
            WHERE SumOrder IS NOT NULL

            -- Check if still have extra balance in SKU level
            IF @nExcessPLTQty > 0
            BEGIN
               PRINT ('Check by SKU level - @nExcessPLTQty: ' + CAST(@nExcessPLTQty AS NVARCHAR) + ', @nRemainOrderQty: ' + CAST(@nRemainOrderQty AS NVARCHAR))

               -- Loop to use up extra balance in pallet candidates
               SET @nExcess_RowRef = 0
               WHILE @nExcessPLTQty > 0 AND @nRemainOrderQty > 0
               BEGIN
                  SELECT TOP 1 @nExcess_RowRef = MAX(ID), @nRemainPLTQty = MAX(PalletQty) - SUM(OrderQty), @nTotalPLTQty = MAX(PalletQty)
                  ,@cPalletID = PalletID
                  FROM #PLTCandidates (NOLOCK)
                  WHERE ID > @nExcess_RowRef
                  AND SKU = @cSKU
                  GROUP BY PalletID

                  IF @nRemainPLTQty > 0
                  BEGIN
                     /*
                     UPDATE #PLTCandidates
                        SET OrderQty = CASE WHEN @nRemainOrderQty >= @nRemainPLTQty -- If remaining order Qty is more than remaining pallet Qty, then use all remaining pallet Qty
                                          THEN OrderQty + @nRemainPLTQty
                                       ELSE @nRemainOrderQty END                    -- Else use remaining order Qty
                     WHERE ID = @nExcess_RowRef
                     */

                     IF @nRemainPLTQty >= @nRemainOrderQty
                         INSERT #PLTCandidates (OrderKey, ExternOrderKey, PalletID, SKU, OrderQty, PalletQty)
                         VALUES (@cOrderKey, @cExternOrderKey, @cPalletID, @cSKU, @nRemainOrderQty, @nTotalPLTQty)
                     ELSE
                         INSERT #PLTCandidates (OrderKey, ExternOrderKey, PalletID, SKU, OrderQty, PalletQty)
                         VALUES (@cOrderKey, @cExternOrderKey, @cPalletID, @cSKU, @nRemainPLTQty, @nTotalPLTQty)

                     SET @nRemainOrderQty = @nRemainOrderQty - @nRemainPLTQty
                     SET @nExcessPLTQty = @nExcessPLTQty - @nRemainPLTQty

                  END
               END
            END

         PRINT ('Check by pallet level - @cPalletID: ' + @cPalletID + ', @nTotalPLTQty: ' + CAST(@nTotalPLTQty AS NVARCHAR) + ', @nRemainOrderQty: ' + CAST(@nRemainOrderQty AS NVARCHAR))

            -- If pallet level in overflow locations can fulfill order Qty
            IF @nRemainOrderQty > 0
            BEGIN
               SELECT TOP 1 @nLLI_RowRef = LLI_RowRef, @cPalletID = ID, @nTotalPLTQty = Qty FROM #LLI (NOLOCK)
               WHERE LLI_RowRef > @nLLI_RowRef
               ORDER BY LLI_RowRef

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @bIsFinished = 1
                  BREAK
               END

               PRINT ('@nTotalPLTQty >= @nRemainOrderQty - @cPalletID: ' + @cPalletID + ', @nTotalPLTQty: ' + CAST(@nTotalPLTQty AS NVARCHAR) + ', @nRemainOrderQty: ' + CAST(@nRemainOrderQty AS NVARCHAR))

               IF @nTotalPLTQty >= @nRemainOrderQty
               BEGIN
                  INSERT #PLTCandidates (OrderKey, ExternOrderKey, PalletID, SKU, OrderQty, PalletQty)
                  VALUES (@cOrderKey, @cExternOrderKey, @cPalletID, @cSKU, @nRemainOrderQty, @nTotalPLTQty)

                  SET @nRemainOrderQty = @nRemainOrderQty - @nTotalPLTQty
               END
               --SY: IF TOTALPLTQTY LESS THAN ORDERQTY, INSERT INTO CANDIDATES AND REDUCE ORDER REMAININGQTY
               ELSE IF @nTotalPLTQty < @nRemainOrderQty
               BEGIN
                  INSERT #PLTCandidates (OrderKey, ExternOrderKey, PalletID, SKU, OrderQty, PalletQty)
                  VALUES (@cOrderKey, @cExternOrderKey, @cPalletID, @cSKU, @nTotalPLTQty, @nTotalPLTQty)

                  SET @nRemainOrderQty = @nRemainOrderQty - @nTotalPLTQty
               END
            END
         END
         -- Else pull from existing pallet candidates
         ELSE
         BEGIN
            PRINT ('Pallet candidates - @cPalletID: ' + @cPalletID + ', @nAvailPLTQty: ' + CAST(@nAvailPLTQty AS NVARCHAR) + ', @nRemainOrderQty: ' + CAST(@nRemainOrderQty AS NVARCHAR))

            INSERT #PLTCandidates (OrderKey, ExternOrderKey, PalletID, SKU, OrderQty, PalletQty)
            VALUES (@cOrderKey, @cExternOrderKey, @cPalletID, @cSKU, @nRemainOrderQty, @nTotalPLTQty)

            SET @nRemainOrderQty = @nRemainOrderQty - @nAvailPLTQty
         END

         IF @nRemainOrderQty <= 0
         BEGIN
            SET @bIsFinished = 1
            BREAK
         END
      END

      SET @cPrevSKU = @cSKU

   FETCH NEXT FROM CUR_ORD INTO @cOrderKey, @cExternOrderKey, @cSKU, @nOrderQty
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD
   DROP TABLE #TempTable

   IF EXISTS (SELECT 1 FROM #PLTCandidates)
   BEGIN
       SELECT
         --COUNT(DISTINCT OrderKey) AS COLUMN_01,
   OrderKey AS COLUMN_01,
         PalletID AS COLUMN_02,
         SKU AS COLUMN_03,
         --SUM(OrderQty) AS COLUMN_04,
   OrderQty AS COLUMN_04,
         PalletQty AS COLUMN_05,
         '' AS COLUMN_06,
         '' AS COLUMN_07,
         '' AS COLUMN_08,
         '' AS COLUMN_09,
         '' AS COLUMN_10 FROM #PLTCandidates
       --GROUP BY PalletID, SKU, PalletQty
       ORDER BY COLUMN_01 DESC, SKU
   END

QUIT:

END

GO