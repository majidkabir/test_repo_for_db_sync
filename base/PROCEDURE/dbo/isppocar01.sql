SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPOCAR01                                         */
/* Creation Date: 03-Feb-2016                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 358754 - CN Carters SZ - Pre-Allocation process to update   */
/*          UCC.Status to 3 and Stamp UCCNo to PickDetail.DropID to     */
/*          avoid duplicate allocation (All)                            */
/*          Set to storerconfig PostProcessingStrategyKey               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 13/06/2018   NJOW01    1.0   WMS-4038 convert uom 7 to 6 as conso    */
/*                              carton if can pick full ucc             */
/* 02-Jul-2019  Leong     1.1   Revise ErrMsg (L01).                    */
/************************************************************************/

CREATE PROC [dbo].[ispPOCAR01]
    @c_WaveKey                      NVARCHAR(10)
  , @c_UOM                          NVARCHAR(10)
  , @c_LocationTypeOverride         NVARCHAR(10)
  , @c_LocationTypeOverRideStripe   NVARCHAR(10)
  , @b_Success                      INT           OUTPUT
  , @n_Err                          INT           OUTPUT
  , @c_ErrMsg                       NVARCHAR(250) OUTPUT
  , @b_Debug                        INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @n_Continue    INT,
      @n_StartTCnt   INT

   DECLARE
      @c_PickDetailKey    NVARCHAR(18),
      @c_NewPickDetailKey NVARCHAR(18),
      @c_OrderKey         NVARCHAR(10),
      @c_OrderLineNumber  NVARCHAR(5),
      @c_StorerKey        NVARCHAR(15),
      @c_SKU              NVARCHAR(20),
      @c_Loc              NVARCHAR(10),
      @c_Lot              NVARCHAR(10),
      @c_ID               NVARCHAR(18),
      @c_UCCNo            NVARCHAR(20),
      @n_UCCQty           INT,
      @n_PickedQty        INT,
      @n_Sum              INT,
      @n_Qty              INT,
      @n_Total            INT

   DECLARE
      @n_CntCount         INT,
      @n_Count            INT,
      @n_Number           INT,
      @n_Pos              INT,
      @n_Result           INT,
      @c_Result           NVARCHAR(MAX),
      @c_Subset           NVARCHAR(MAX),
      @c_TempStr          NVARCHAR(MAX),
      @c_PrintResult      NVARCHAR(MAX),
      @n_RowCount         INT

   IF OBJECT_ID('tempdb..#NumPool','u') IS NOT NULL
      DROP TABLE #NumPool;

   CREATE TABLE #NumPool (
      ID            INT IDENTITY(1,1),
      UCCQty        INT,
      CntCount      INT DEFAULT 0
   )

   IF OBJECT_ID('tempdb..#CombinationPool','u') IS NOT NULL
      DROP TABLE #CombinationPool;

   -- Store all possible combination numbers
   CREATE TABLE #CombinationPool (
      [Sum]    INT,
      Subset   NVARCHAR(4000)
   )

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''

   DECLARE CURSOR_PICKDETAILS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT
      PD.StorerKey,
      PD.SKU,
      PD.LOT,
      PD.LOC,
      PD.ID,
      PD.UOM,
      SUM(PD.Qty)
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.LOC)
   JOIN WaveDetail WD WITH (NOLOCK) ON PD.OrderKey =WD.OrderKey
   WHERE WD.WaveKey = @c_WaveKey
     AND LOC.LocationCategory = 'BULK'
     AND LOC.LocationType = 'OTHER'
     AND ISNULL(PD.DropID, '') = ''
   GROUP BY PD.StorerKey, PD.SKU, PD.LOT, PD.LOC, PD.ID, PD.UOM

   OPEN CURSOR_PICKDETAILS
   FETCH NEXT FROM CURSOR_PICKDETAILS INTO @c_StorerKey, @c_SKU, @c_Lot, @c_Loc, @c_ID, @c_UOM, @n_Total

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF @b_Debug = 1
        PRINT '-------------------------------------------------' + CHAR(13) +
            'StorerKey: ' + @c_StorerKey + CHAR(13) +
            'SKU: ' + @c_SKU + CHAR(13) +
            'Lot: ' + @c_Lot + CHAR(13) +
            'Loc: ' + @c_Loc + CHAR(13) +
            'ID: ' + @c_ID + CHAR(13) +
            'UOM: ' + @c_UOM + CHAR(13) +
            'Total: ' + CAST(@n_Total AS NVARCHAR) + CHAR(13)

      IF @c_UOM = '7'
      BEGIN
         SELECT @c_UCCNo = '', @n_UCCQty = 0
         SELECT TOP 1
            @c_UCCNo = UCCNo,
            @n_UCCQty = Qty
         FROM UCC WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
           AND SKU = @c_SKU
           AND Lot = @c_Lot
           AND Loc = @c_Loc
           AND ID = @c_Id
           AND Status < '3'
           AND Qty >= @n_Total
           --AND Qty > @n_Total
         ORDER BY Qty

         IF ISNULL(@c_UCCNo, '') = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 13000
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                            ' StorerKey=' + ISNULL(RTRIM(@c_StorerKey),'') + ', Sku=' + ISNULL(RTRIM(@c_SKU),'') + CHAR(13) +
                            ', Lot=' + ISNULL(RTRIM(@c_Lot),'') + ', Loc=' + ISNULL(RTRIM(@c_Loc),'') + ', Id=' + ISNULL(RTRIM(@c_Id),'') +
                            ', UCCQty=' + CAST(ISNULL(@n_Total,0) AS VARCHAR) +
                            ' : Failed to find UCC. (ispPOCAR01)' -- L01
            GOTO Quit
         END

         IF @b_Debug = 1
            PRINT '******' + CHAR(13) +
                  'Update UCCNo: ' + @c_UCCNo + CHAR(13) +
                  'UCCQty: ' + CAST(@n_UCCQty AS NVARCHAR) + CHAR(13)

         UPDATE PD
         SET PD.DropID = @c_UCCNo, PD.UOMQty = @n_UCCQty,
             PD.UOM = CASE WHEN @n_UCCQty = @n_Total THEN '6' ELSE PD.UOM END --NJOW01
         FROM PickDetail PD WITH (NOLOCK)
         JOIN WaveDetail WD WITH (NOLOCK) ON PD.OrderKey = WD.OrderKey
         WHERE WD.WaveKey = @c_WaveKey
           AND PD.StorerKey = @c_StorerKey
           AND PD.SKU = @c_SKU
           AND PD.Lot = @c_Lot
           AND PD.Loc = @c_Loc
           AND PD.ID = @c_Id
           AND PD.UOM = @c_UOM
           AND ISNULL(PD.DropID, '') = ''

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 13001
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                            ': Update PickDetail Failed. (ispPOCAR01)'
            GOTO Quit
         END

         SELECT TOP 1
            @c_PickDetailKey = PickDetailKey,
            @c_OrderKey = OrderKey,
            @c_OrderLineNumber = OrderLineNumber
         FROM PickDetail WITH (NOLOCK)
         WHERE DropID = @c_UccNo

         IF @b_Debug = 1
            PRINT '------------------' + CHAR(13) +
                  'Updating UCC: ' + @c_UCCNo + ' - PickDetailKey: ' + @c_PickDetailKey +
                  ', OrderKey: ' + @c_OrderKey + ', OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                  '------------------' + CHAR(13)

         -- Update UCC.Status to 3
         UPDATE UCC WITH (ROWLOCK)
         SET Status = '3', PickDetailKey = @c_PickDetailKey,
             OrderKey = @c_OrderKey, OrderLineNumber = @c_OrderLineNumber
         WHERE UCCNo = @c_UCCNo
           AND Status = '1'

         SELECT @n_RowCount = @@ROWCOUNT, @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 13002
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                            ': Update UCC Failed. (ispPOCAR01)'
            GOTO Quit
         END

         IF @n_RowCount = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 13003
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                            ': Update UCC Failed. (ispPOCAR01)'
            GOTO Quit
         END

         IF @b_Debug = 1
         BEGIN
            SET @c_PrintResult = ''
            SELECT @c_PrintResult = @c_PrintResult + PickDetailKey + ',' FROM PickDetail WITH (NOLOCK) WHERE DropID = @c_UccNo
            PRINT 'to ' + CHAR(13) +
                  'PickDetailKey: ' + SUBSTRING(@c_PrintResult, 0, LEN(@c_PrintResult)) + CHAR(13) +
                  '******' + CHAR(13)
         END

      END -- IF @c_UOM = '7'
      ELSE
      BEGIN
         -- Assign UCC to pickdetail with conso-carton(UOM6) or full-carton(UOM2)
         IF @n_Total > 0
         BEGIN
            SET @c_Result = ''
            SET @n_Result = 0

            DELETE FROM #NumPool
            INSERT INTO #NumPool (UCCQty, CntCount)
            SELECT Qty, COUNT(1)
            FROM UCC WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
              AND SKU = @c_SKU
              AND Lot = @c_Lot
              AND Loc = @c_Loc
              AND ID = @c_Id
              AND Status < '3'
            GROUP BY Qty

            IF @b_Debug = 1
            BEGIN
               PRINT 'Remaining Total: ' + CAST(@n_Total AS NVARCHAR)

               SET @c_PrintResult = ''
               SELECT @c_PrintResult = @c_PrintResult + 'UCCQty: ' + CAST(UCCQty AS NVARCHAR) +
                      ', CntCount: ' + CAST(CntCount AS NVARCHAR) + CHAR(13) FROM #NumPool WITH (NOLOCK)
               PRINT 'Remaining UCC for StorerKey: ' + @c_StorerKey +
                     ', SKU: ' + @c_SKU + ', LOT: ' + @c_Lot + ', LOC: ' + @c_Loc + ', ID: ' + @c_Id + CHAR(13) +
                     SUBSTRING(@c_PrintResult, 0, LEN(@c_PrintResult)) + CHAR(13)
            END

            SET @n_UCCQty = 0
            SELECT TOP 1 @n_UCCQty = UCCQty
            FROM #NumPool WITH (NOLOCK)
            WHERE @n_Total % UCCQty = 0
              AND @n_Total/UCCQty <= CntCount

            IF ISNULL(@n_UCCQty, 0) <> 0
            BEGIN
               SET @c_Result = CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_Total/@n_UCCQty AS NVARCHAR)
               SET @n_Result = @n_Total/@n_UCCQty * @n_UCCQty
            END -- IF ISNULL(@n_UCCQty,'') <> ''

            IF ISNULL(@c_Result, '') = ''
            BEGIN
               DELETE FROM #CombinationPool
               /***************************************************/
               /***   Get all possible combination of NumPool   ***/
               /***************************************************/
               DECLARE CURSOR_COMBINATION CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT UCCQty, CntCount
               FROM #NumPool WITH (ROWLOCK)

               OPEN CURSOR_COMBINATION
               FETCH NEXT FROM CURSOR_COMBINATION INTO @n_UCCQty, @n_CntCount

               WHILE (@@FETCH_STATUS <> -1)
               BEGIN
                  SET @n_Count = 1

                  WHILE (@n_Count <= @n_CntCount)
                  BEGIN
                     INSERT INTO #CombinationPool
                     VALUES (@n_UCCQty * @n_Count,
                             CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                     DECLARE CURSOR_COMBINATION_INNER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT [Sum], Subset
                     FROM #CombinationPool WITH (NOLOCK)
                     --WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR), Subset) = 0
                     WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR) + ' * ', Subset) = 0 -- (Chee01)

                     OPEN CURSOR_COMBINATION_INNER
                     FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                     WHILE (@@FETCH_STATUS <> -1)
                     BEGIN

                        INSERT INTO #CombinationPool
                        VALUES (@n_Sum + @n_UCCQty * @n_Count,
                                @c_Subset + ' + ' + CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                        FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                     END -- END WHILE FOR CURSOR_COMBINATION_INNER
                     CLOSE CURSOR_COMBINATION_INNER
                     DEALLOCATE CURSOR_COMBINATION_INNER

                     SET @n_Count = @n_Count + 1
                  END

                  FETCH NEXT FROM CURSOR_COMBINATION INTO @n_UCCQty, @n_CntCount
               END -- END WHILE FOR CURSOR_COMBINATION
               CLOSE CURSOR_COMBINATION
               DEALLOCATE CURSOR_COMBINATION

               -- GET Combination with least Remainder, least number combination
               SELECT TOP 1 @c_Result = Subset, @n_Result = [Sum]
               FROM #CombinationPool WITH (NOLOCK)
               WHERE [Sum] <= @n_Total
               ORDER BY [Sum] DESC,
                        LEN(Subset) - LEN(REPLACE(Subset, '+', ''))
            END -- IF ISNULL(@c_Result, '') = ''

            IF @b_Debug = 1
               PRINT 'RESULT FOR ' + CAST(@n_Total AS NVARCHAR) + ': ' + @c_Result + CHAR(13)

            /*************************/
            /***  Process Result   ***/
            /************************/
            IF ISNULL(@c_Result, '') <> ''
            BEGIN
               -- Clear #NumPool
               DELETE FROM #NumPool
               SET @c_TempStr = @c_Result

               -- Convert Result string into #SplitList table
               WHILE CHARINDEX('+', @c_TempStr) > 0
               BEGIN
                  SET @n_Pos = CHARINDEX('+', @c_TempStr)
                  SET @c_Subset = SUBSTRING(@c_TempStr, 1, @n_Pos-2)
                  SET @c_TempStr = SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr)-@n_Pos)

                  SET @n_Pos  = CHARINDEX('*', @c_Subset)
                  SET @n_Number = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-2) AS INT)
                  SET @n_CntCount = CAST(SUBSTRING(@c_Subset, @n_Pos+2, LEN(@c_Subset) - @n_Pos+2) AS INT)
                  WHILE @n_CntCount > 0
                  BEGIN
                     INSERT INTO #NumPool (UCCQty) VALUES (@n_Number)
                     SET @n_CntCount = @n_CntCount - 1
                  END
               END -- WHILE CHARINDEX('+', @c_Result) > 0

               SET @n_Pos  = CHARINDEX('*', @c_TempStr)
               SET @n_Number = CAST(SUBSTRING(@c_TempStr, 1, @n_Pos-2) AS INT)
               SET @n_CntCount = CAST(SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr) - @n_Pos+2) AS INT)
               WHILE @n_CntCount > 0
               BEGIN
                  INSERT INTO #NumPool (UCCQty) VALUES (@n_Number)
                  SET @n_CntCount = @n_CntCount - 1
               END

               IF @b_Debug = 1
               BEGIN
                  SET @c_PrintResult = ''
                  SELECT @c_PrintResult = @c_PrintResult + CAST(ID AS NVARCHAR) + ': ' + CAST(UCCQty AS NVARCHAR) + CHAR(13) FROM #NumPool WITH (NOLOCK)
                  PRINT 'Result UCC: ' + CHAR(13) +
                        SUBSTRING(@c_PrintResult, 0, LEN(@c_PrintResult)) + CHAR(13)
               END

               SET @n_PickedQty = 0
               -- Loop through UCC result
               DECLARE CURSOR_UCC_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT
                  ID, UCCQty
               FROM #NumPool WITH (NOLOCK)
               ORDER BY UCCQty

               OPEN CURSOR_UCC_RESULT
               FETCH NEXT FROM CURSOR_UCC_RESULT INTO @n_Pos, @n_UCCQty

               WHILE (@@FETCH_STATUS <> -1)
               BEGIN
                  SELECT @c_UCCNO = '', @n_Qty = @n_UCCQty
                  SELECT TOP 1
                     @c_UCCNo = UCCNo
                  FROM UCC WITH (NOLOCK)
                  WHERE StorerKey = @c_StorerKey
                    AND SKU = @c_SKU
                    AND Lot = @c_Lot
                    AND Loc = @c_Loc
                    AND ID = @c_ID
                    AND Status < '3'
                    AND Qty = @n_UCCQty

                  IF ISNULL(@c_UCCNo, '') = ''
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 13004
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                     ' StorerKey=' + ISNULL(RTRIM(@c_StorerKey),'') + ', Sku=' + ISNULL(RTRIM(@c_SKU),'') + CHAR(13) +
                                     ', Lot=' + ISNULL(RTRIM(@c_Lot),'') + ', Loc=' + ISNULL(RTRIM(@c_Loc),'') + ', Id=' + ISNULL(RTRIM(@c_Id),'') +
                                     ', UCCQty=' + CAST(ISNULL(@n_UCCQty,0) AS VARCHAR) +
                                     ' : Failed to find UCC. (ispPOCAR01)' -- L01
                     GOTO Quit
                  END

                  IF @b_Debug = 1
                     PRINT '******' + CHAR(13) +
                           'Update UCCNo: ' + @c_UCCNo + CHAR(13) +
                           'UCCQty: ' + CAST(@n_UCCQty AS NVARCHAR) + CHAR(13)

                  WHILE @n_Qty > 0
                  BEGIN
                     IF @n_PickedQty = 0
                     BEGIN
                        SELECT @c_PickDetailKey = ''
                        SELECT TOP 1
                           @c_PickDetailKey = PD.PickDetailKey,
                           @c_OrderKey = PD.OrderKey,
                           @c_OrderLineNumber = PD.OrderLineNumber,
                           @n_PickedQty = PD.Qty
                        FROM PICKDETAIL PD WITH (NOLOCK)
                        JOIN WaveDetail WD WITH (NOLOCK) ON PD.OrderKey = WD.OrderKey
                        WHERE WD.WaveKey = @c_WaveKey
                          AND StorerKey = @c_StorerKey
                          AND SKU = @c_SKU
                          AND Lot = @c_Lot
                          AND Loc = @c_Loc
                          AND ID = @c_Id
                          AND UOM = @c_UOM
                          AND ISNULL(DropID, '') = ''
                        ORDER BY @n_UCCQty % Qty, Qty

                        IF ISNULL(@c_PickDetailKey, '') = ''
                        BEGIN
                           SET @n_Continue = 3
                           SET @n_Err = 13005
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                          ' WaveKey=' + ISNULL(RTRIM(@c_WaveKey),'') + ', StorerKey=' + ISNULL(RTRIM(@c_StorerKey),'') + ', Sku=' + ISNULL(RTRIM(@c_SKU),'') + CHAR(13) +
                                          ', Lot=' + ISNULL(RTRIM(@c_Lot),'') + ', Loc=' + ISNULL(RTRIM(@c_Loc),'') + ', Id=' + ISNULL(RTRIM(@c_Id),'') +
                                          ', UOM=' + ISNULL(RTRIM(@c_UOM),'') +
                                          ' : Failed to get PickDetailKey. (ispPOCAR01)' -- L01
                           GOTO Quit
                        END

                        IF @b_Debug = 1
                           PRINT
                              '######' + CHAR(13) +
                              'PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                              'PickedQty: ' + CAST(@n_PickedQty AS NVARCHAR) + CHAR(13) +
                              'Total: ' + CAST(@n_Total AS NVARCHAR) + CHAR(13) +
                              '######' + CHAR(13)
                     END -- IF @n_PickedQty = 0

                     IF @n_PickedQty <= @n_Qty
                     BEGIN
                        UPDATE PickDetail WITH (ROWLOCK)
                        SET DropID = @c_UCCNo, UOMQty = @n_UCCQty
                        WHERE PickDetailKey = @c_PickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           SET @n_Continue = 3
                           SET @n_Err = 13006
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                           ': Update PickDetail Failed. (ispPOCAR01)'
                           GOTO Quit
                        END

                        SET @n_Qty = @n_Qty - @n_PickedQty
                        SET @n_Total = @n_Total - @n_PickedQty
                        SET @n_PickedQty = 0
                     END
                     ELSE
                     BEGIN
                        -- Split PickDetail Lines
                        EXECUTE dbo.nspg_GetKey
                              'PICKDETAILKEY',
                              10,
                              @c_NewPickDetailKey OUTPUT,
                              @b_Success          OUTPUT,
                              @n_Err              OUTPUT,
                              @c_ErrMsg           OUTPUT

                        IF @b_Success<>1
                        BEGIN
                           SET @b_Success = 0
                           SET @n_Err = 13007
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                           ': Unable to retrieve new PickdetailKey. (ispPOCAR01)'
                           GOTO Quit
                        END

                        -- Create a new PickDetail to hold the balance
                        INSERT INTO dbo.PICKDETAIL
                           (
                             CaseID               ,PickHeaderKey     ,OrderKey
                            ,OrderLineNumber      ,LOT               ,StorerKey
                            ,SKU                  ,AltSKU            ,UOM
                            ,UOMQTY               ,QTYMoved          ,STATUS
                            ,DropID               ,LOC               ,ID
                            ,PackKey              ,UpdateSource      ,CartonGroup
                            ,CartonType           ,ToLoc             ,DoReplenish
                            ,ReplenishZone        ,DoCartonize       ,PickMethod
                            ,WaveKey              ,EffectiveDate     ,ArchiveCop
                            ,ShipFlag             ,PickSlipNo        ,PickDetailKey
                            ,QTY
                            ,TrafficCop
                            ,OptimizeCop
                            ,TaskDetailkey
                           )
                        SELECT
                             CaseID             ,PickHeaderKey     ,OrderKey
                            ,OrderLineNumber      ,Lot               ,StorerKey
                            ,SKU                  ,AltSku            ,UOM
                            ,UOMQTY               ,QTYMoved          ,STATUS
                            ,''                   ,LOC               ,ID
                            ,PackKey              ,UpdateSource      ,CartonGroup
                            ,CartonType           ,ToLoc             ,DoReplenish
                            ,ReplenishZone        ,DoCartonize       ,PickMethod
                            ,WaveKey              ,EffectiveDate     ,ArchiveCop
                            ,ShipFlag             ,PickSlipNo        ,@c_NewPickDetailKey
                            ,@n_PickedQty - @n_Qty
                            , NULL
                            ,'1'
                            ,TaskDetailkey
                        FROM   dbo.PickDetail WITH (NOLOCK)
                        WHERE PickDetailKey = @c_PickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           SET @b_Success = 0
                           SET @n_Err = 13008
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                           ': Insert Pickdetail Failed. (ispPOCAR01)'
                           GOTO Quit
                        END

                        UPDATE PickDetail WITH (ROWLOCK)
                        SET DropID = @c_UCCNo, Qty = @n_Qty, UOMQty = @n_UCCQty, Trafficcop = NULL
                        WHERE PickDetailKey = @c_PickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           SET @b_Success = 0
                           SET @n_Err = 13009
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                           ': Update Pickdetail Failed. (ispPOCAR01)'
                           GOTO Quit
                        END

                        IF @b_Debug = 1
                           PRINT '   Splited PickDetail: ' + CHAR(13) +
                              '   PickDetailKey: ' + @c_PickDetailKey + ' to ' + @c_NewPickDetailKey + CHAR(13) +
                              '   PickedQty: ' + CAST(@n_PickedQty AS NVARCHAR) + ' to ' + CAST(@n_PickedQty - @n_Qty AS NVARCHAR) + CHAR(13)

                        SET @n_PickedQty = @n_PickedQty - @n_Qty
                        SET @n_Total = @n_Total - @n_Qty
                        SET @n_Qty = 0
                     END

                     IF @b_Debug = 1
                     BEGIN
                        SET @c_PrintResult = ''
                        SELECT @c_PrintResult = @c_PrintResult + PickDetailKey + ',' FROM PickDetail WITH (NOLOCK) WHERE DropID = @c_UccNo
                        PRINT 'to ' + CHAR(13) +
                              'PickDetailKey: ' + SUBSTRING(@c_PrintResult, 0, LEN(@c_PrintResult)) + CHAR(13) +
                              '*******' + CHAR(13)
                     END
                  END -- WHILE @n_Qty > 0

                  IF @b_Debug = 1
                     PRINT '------------------' + CHAR(13) +
                           'Updating UCC: ' + @c_UCCNo + ' - PickDetailKey: ' + @c_PickDetailKey +
                           ', OrderKey: ' + @c_OrderKey + ', OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                           '------------------' + CHAR(13)

                  -- Update UCC.Status to 3
                  UPDATE UCC WITH (ROWLOCK)
                  SET Status = '3', PickDetailKey = @c_PickDetailKey,
                      OrderKey = @c_OrderKey, OrderLineNumber = @c_OrderLineNumber
                  WHERE UCCNo = @c_UCCNo
                    AND Status = '1'
                    AND SKU = @c_SKU

                  SELECT @n_RowCount = @@ROWCOUNT, @n_Err = @@ERROR

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 13010
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                     ': Update UCC Failed. (ispPOCAR01)'
                     GOTO Quit
                  END

                  IF @n_RowCount = 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 13011
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                                     ': Update UCC Failed. (ispPOCAR01)'
                     GOTO Quit
                  END

                  -- SET NewPickDetailKey to PickDetailKey if splited PickDetail
                  IF ISNULL(@c_NewPickDetailKey, '') <> ''
                  BEGIN
                     SET @c_PickDetailKey = @c_NewPickDetailKey
                     SET @c_NewPickDetailKey = ''
                  END

                  FETCH NEXT FROM CURSOR_UCC_RESULT INTO @n_Pos, @n_UCCQty
               END
               CLOSE CURSOR_UCC_RESULT
               DEALLOCATE CURSOR_UCC_RESULT
            END -- IF ISNULL(@c_Result, '') <> ''
         END -- IF @n_Total > 0
      END -- IF @c_UOM = '6'

      FETCH NEXT FROM CURSOR_PICKDETAILS INTO @c_StorerKey, @c_SKU, @c_Lot, @c_Loc, @c_ID, @c_UOM, @n_Total
   END
   CLOSE CURSOR_PICKDETAILS
   DEALLOCATE CURSOR_PICKDETAILS

   IF @b_Debug = 1
      PRINT '-------------------------------------------------' + CHAR(13)

QUIT:
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_PICKDETAILS')) >=0
   BEGIN
      CLOSE CURSOR_PICKDETAILS
      DEALLOCATE CURSOR_PICKDETAILS
   END

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_UCC_RESULT')) >=0
   BEGIN
      CLOSE CURSOR_UCC_RESULT
      DEALLOCATE CURSOR_UCC_RESULT
   END

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_COMBINATION')) >=0
   BEGIN
      CLOSE CURSOR_COMBINATION
      DEALLOCATE CURSOR_COMBINATION
   END

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_COMBINATION_INNER')) >=0
   BEGIN
      CLOSE CURSOR_COMBINATION_INNER
      DEALLOCATE CURSOR_COMBINATION_INNER
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOCAR01'
      --RAISERROR @n_Err @c_ErrMsg
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

END -- Procedure

GO