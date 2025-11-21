SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* S Proc: nsp_ChangePickDetailByStorer                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: To solve the integrity for qty expected between the         */
/*          LOTxLOCxID and SKUxLOC                                      */
/* Input Parameters: Storer Key                                         */
/*                                                                      */
/* OUTPUT Parameters: None                                              */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: For Backend Schedule job                                      */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.11                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 15-Feb-2005  Shong   1.0   Patch the qty expected for lotxlocxid     */
/*                                                                      */
/* 01-Apr-2005  Shong   1.1   Bug Fixed and Performance Tuning          */
/*                                                                      */
/* 21-07-2005   Shong   1.2   Include those records was previously over */
/*                            Allocated and Now LocationType change to  */
/*                            OTHER                                     */
/* 04-04-2007   Shong   1.3   SOS72093 Not Allow to swap HELD Lot and ID*/
/* 24-08-2008   Shong   1.4   Include DropID when duplicate PickDetail  */
/* 13-01-2010   Shong   1.5   SOS158944 - Include StorerConfigKey       */
/*                                        'ForceAllocLottable'          */
/* 23-06-2010   Shong   1.6   Insert into RefKeyLookup for newly added  */
/*                            Pickdetail Record.                        */
/* 11-10-2010   Shong   1.7   Include others Column when insert PD      */
/* 16-10-2010   TLTING  1.8   Get Larger qty for swap lot tlting01      */
/* 29-10-2010   TLTING  1.9   Check QtyPreAllocated to get lot          */
/* 24-07-2015   NJOW01  2.0   342639-ForceAllocLottable configure by    */
/*                            codelkup                                  */
/* 15-03-2017   Leong   2.1   IN00291676 - Enable @n_debug mode.        */
/* 17-04-2017   TLTING  2.2   Performance Tune                          */
/* 11-11-2017   TLTING  2.2   Update editdate                           */
/* 11-11-2017   Leong   2.2   Exclude ShipFlag Y (L01)                  */
/************************************************************************/

CREATE PROC [dbo].[nsp_ChangePickDetailByStorer]
     @c_StorerKey NVARCHAR(15)
   , @n_debug     INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @c_PickDetailKey        NVARCHAR(18),
   @b_Err                  INT,
   @n_Rows                 INT,
   @n_RowCount             INT,
   @c_LOT                  NVARCHAR(10),
   @c_Ctrl                 NVARCHAR(1),
   @c_LOC                  NVARCHAR(10),
   @c_ID                   NVARCHAR(18),
   @c_SKU                  NVARCHAR(20),
   @n_Qty                  INT,
   @c_NewLOT               NVARCHAR(10),
   @c_NewID                NVARCHAR(18),
   @c_Message              NVARCHAR(255),
   @n_LotQty               INT,
   @c_NewPickDetailKey     NVARCHAR(18),
   @b_Success              INT,
   @c_ErrMsg               NVARCHAR(250),
   @c_Status               NVARCHAR(5),
   @c_ShipFlag             NVARCHAR(1),
   @n_LOTQty2              INT,
   @c_Lottable01           NVARCHAR(18), --SOS158944
   @c_Lottable02           NVARCHAR(18),
   @c_Lottable03           NVARCHAR(18),
   @d_Lottable04           DATETIME,
   @c_ForceAllocLottable   NVARCHAR(1),
   @c_SQLSelect            NVARCHAR(4000),
   @c_Lottable06           NVARCHAR(30), --NJOW01
   @c_Lottable07           NVARCHAR(30), --NJOW01
   @c_Lottable08           NVARCHAR(30), --NJOW01
   @c_Lottable09           NVARCHAR(30), --NJOW01
   @c_Lottable10           NVARCHAR(30), --NJOW01
   @c_Lottable11           NVARCHAR(30), --NJOW01
   @c_Lottable12           NVARCHAR(30), --NJOW01
   @c_forcelottablelist    NVARCHAR(500) --NJOW01


   SELECT @n_Rows = 0
   SELECT @c_Ctrl = '0'

   DECLARE @n_Continue INT

   SELECT @n_Continue = 1

   IF @n_Continue=1 or @n_Continue=2
   BEGIN
      DECLARE @c_Authority NVARCHAR(1)

      SELECT @b_Success = 0
      EXECUTE nspGetRight '',
      @c_StorerKey,   -- Storer
      '',             -- Sku
      'OWITF',        -- ConfigKey
      @b_Success          OUTPUT,
      @c_Authority        OUTPUT,
      @b_Err              OUTPUT,
      @c_ErrMsg           OUTPUT

      IF @c_Authority = '1'
         SELECT @n_Continue = 3
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      --IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
      --              JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.SKU = LOTxLOCxID.SKU AND
      --                                        SKUxLOC.StorerKey = LOTxLOCxID.StorerKey)
      --              JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc
      --              WHERE LOTxLOCxID.QtyExpected > 0
      --              AND SKUxLOC.StorerKey = @c_StorerKey
      --              AND ( SKUxLOC.LocationType IN ('PICK', 'CASE') OR
      --                    (LOTxLOCxID.QtyExpected > 0 AND SKUxLOC.QtyExpected = 0 ) OR
      --                    (LOC.LocationType IN ('DYNPICKP', 'DYNPICKR', 'DYNPPICK') )))   --NJOW01
      IF NOT EXISTS ( SELECT  1 FROM SKUxLOC  WITH (NOLOCK)
                    JOIN LOTxLOCxID WITH (NOLOCK) ON ( SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                                          AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC  )
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND SKUxLOC.StorerKey = @c_StorerKey
                    AND SKUxLOC.LocationType IN ('PICK', 'CASE') ) AND
         NOT EXISTS (
                     SELECT  1 FROM SKUxLOC  WITH (NOLOCK)
                    JOIN LOTxLOCxID WITH (NOLOCK) ON ( SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                                          AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC )
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND SKUxLOC.StorerKey = @c_StorerKey
                    AND  SKUxLOC.QtyExpected = 0  ) AND
         NOT EXISTS ( SELECT  1 FROM SKUxLOC WITH (NOLOCK)
                    JOIN LOTxLOCxID  WITH (NOLOCK) ON ( SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                               AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC )
                    JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND SKUxLOC.StorerKey = @c_StorerKey
                    AND LOC.LocationType IN ('DYNPICKP', 'DYNPICKR', 'DYNPPICK') )
      BEGIN
         SELECT @n_Continue = 4
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      --NJOW01 Start
      SELECT TOP 1 @c_ForceLottableList = NOTES
      FROM CODELKUP (NOLOCK)
      WHERE Storerkey = @c_StorerKey
      AND Listname = 'FORCEALLOT'

      IF ISNULL(@c_ForceLottableList,'') = ''
         SET @c_ForceLottableList = 'LOTTABLE01,LOTTABLE02,LOTTABLE03'
      --NJOW01 End

      DECLARE LOT_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.id, LOTxLOCxID.Sku
      FROM LOTxLOCxID WITH (NOLOCK)
      JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.SKU = LOTxLOCxID.SKU AND
                                SKUxLOC.StorerKey = LOTxLOCxID.StorerKey)
      JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc
      WHERE LOTxLOCxID.QtyExpected > 0
      AND SKUxLOC.StorerKey = @c_StorerKey
      AND ( SKUxLOC.LocationType IN ('PICK', 'CASE') OR
            (LOTxLOCxID.QtyExpected > 0 AND SKUxLOC.QtyExpected = 0 ) OR
            (LOC.LocationType IN ('DYNPICKP', 'DYNPICKR', 'DYNPPICK') ))   --NJOW01

      OPEN LOT_CUR

      FETCH NEXT FROM LOT_CUR INTO @c_LOT, @c_LOC, @c_ID, @c_SKU
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         --IF @n_rows = 200
         --BEGIN
         --   BREAK
         --END
         DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.Qty, PD.Shipflag --Added by Vicky 04 Dec 2002
              , OD.Lottable01, OD.Lottable02, OD.Lottable03, OD.Lottable04
              , OD.Lottable06, OD.Lottable07, OD.Lottable08, OD.Lottable09  --NJOW01
              , OD.Lottable10, OD.Lottable11, OD.Lottable12  --NJOW01
         FROM PICKDETAIL PD WITH (NOLOCK)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey --SOS158944
              AND PD.OrderLineNumber = OD.OrderLineNumber
         WHERE PD.SKU       = @c_SKU
           AND PD.StorerKey = @c_StorerKey
           AND PD.LOC       = @c_LOC
           AND PD.LOT       = @c_LOT
           AND PD.ID        = @c_ID
           AND ( (PD.Status BETWEEN '5' AND '8' AND PD.ShipFlag <> 'Y') OR PD.ShipFlag = 'P' ) --L01
           --AND ( PD.Status BETWEEN '5' AND '8' OR PD.ShipFlag = 'P' )

         OPEN PICK_CUR

        FETCH NEXT FROM PICK_CUR IntO @c_PickDetailKey, @n_Qty, @c_shipflag, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                      @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12 --NJOW01

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            IF @n_debug = 1
            BEGIN
               SELECT @c_PickDetailKey '@c_PickDetailKey', @c_StorerKey '@c_StorerKey', @c_SKU '@c_SKU'
                    , @c_LOT '@c_LOT', @c_LOC '@c_LOC', @c_ID '@c_ID', @n_Qty '@n_Qty'
            END

            SELECT @c_NewLOT = ''

            SELECT TOP 1
                   @c_NewLOT = LOTxLOCxID.Lot,
                   @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                   @c_NewID = LOTxLOCxID.ID
            FROM  LOTxLOCxID WITH (NOLOCK)
            JOIN  ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID
            JOIN  LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
            WHERE
            --LOTxLOCxID.Sku = @c_SKU
            --AND   LOTxLOCxID.StorerKey = @c_StorerKey
               LOTxLOCxID.Loc = @c_LOC
            AND   LOTxLOCxID.LOT = @c_LOT
            AND   LOTxLOCxID.ID <> @c_ID
            AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
            AND   ID.Status <> 'HOLD'
            AND   LOT.Status <> 'HOLD'
            ORDER BY LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked DESC

            SELECT @n_RowCount = @@ROWCOUNT

            IF @n_RowCount = 0
            BEGIN
               SET @c_ForceAllocLottable = '0' -- SOS158944

               SELECT @c_ForceAllocLottable = sValue FROM StorerConfig WITH (NOLOCK)
               WHERE  StorerKey = @c_StorerKey
               AND    ConfigKey = 'ForceAllocLottable'

               --SELECT @c_SKU 'sku', @c_LOC 'loc', @c_NewLOT 'new lot', @c_PickDetailKey 'pickdetailkey',
               --@n_LotQty '@n_LotQty',@n_Qty '@n_Qty', @n_LOTQty2 '@n_LOTQty2', @c_LOT 'Old_LOT'

               -- SOS72093 Not Allow to swap HELD Lot and ID
               SET  @n_LotQty=0
               SET  @c_NewLOT = ''

               GET_NEXT_LOT:

               SET @n_RowCount=0

               IF ISNULL(RTRIM(@c_ForceAllocLottable),'0') = '1'
               BEGIN
                  -- SOS72093 Not Allow to swap HELD Lot and ID
                  SELECT @c_SQLSelect =
                  N'SELECT @c_NewLOT = LOTxLOCxID.Lot,
                           @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                           @c_NewID  = LOTxLOCxID.ID
                    FROM  LOTxLOCxID WITH (NOLOCK)
                    JOIN  ID WITH (NOLOCK) ON LOTxLOCxID.ID = ID.ID
                    JOIN  LOT WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
                    JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT
                    WHERE LOT.Sku       = @c_SKU
                    AND   LOT.StorerKey = @c_StorerKey
                    AND   LOTxLOCxID.Loc       = @c_LOC
                    AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
                    AND   ID.Status <> ''HOLD''
                    AND   LOT.Status <> ''HOLD''
                    AND   LOT.LOT > @c_NewLOT ' +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') <> '' AND CHARINDEX('LOTTABLE01', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') <> '' AND CHARINDEX('LOTTABLE02', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') <> '' AND CHARINDEX('LOTTABLE03', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') <> '' AND CHARINDEX('LOTTABLE06', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') <> '' AND CHARINDEX('LOTTABLE07', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') <> '' AND CHARINDEX('LOTTABLE08', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') <> '' AND CHARINDEX('LOTTABLE09', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') <> '' AND CHARINDEX('LOTTABLE10', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') <> '' AND CHARINDEX('LOTTABLE11', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') <> '' AND CHARINDEX('LOTTABLE12', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END --NJOW01
                    -- + CASE WHEN @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = @d_Lottable04 ' END
               END
               ELSE
               BEGIN
                  SELECT @c_SQLSelect =
                  N'SELECT @c_NewLOT = LOTxLOCxID.Lot,
                           @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                           @c_NewID  = LOTxLOCxID.ID
                    FROM  LOTxLOCxID WITH (NOLOCK)
                    JOIN  ID WITH (NOLOCK) ON LOTxLOCxID.ID = ID.ID
                    JOIN  LOT WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
                    JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT
                    WHERE LOT.Sku       = @c_SKU
                    AND   LOT.StorerKey = @c_StorerKey
                    AND   LOTxLOCxID.Loc= @c_LOC
                    AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
                    AND   ID.Status <> ''HOLD''
                    AND   LOT.Status <> ''HOLD''
                    AND   LOT.LOT > @c_NewLOT '
               END

/*
               SELECT TOP 1
                      @c_NewLOT = LOTxLOCxID.Lot,
                      @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                      @c_NewID = LOTxLOCxID.ID
               FROM  LOTxLOCxID (NOLOCK)
               JOIN  ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID
               JOIN  LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
               WHERE LOTxLOCxID.Sku = @c_SKU
               AND   LOTxLOCxID.StorerKey = @c_StorerKey
               AND   LOTxLOCxID.Loc = @c_LOC
               AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
               AND   ID.Status <> 'HOLD'
               AND   LOT.Status <> 'HOLD'
               AND   LOT.LOT > @c_NewLOT
               ORDER BY LOTxLOCxID.Lot
*/

               EXEC sp_executesql @c_SQLSelect, N'@c_StorerKey  NVARCHAR(15)
                                                , @c_LOC        NVARCHAR(10)
                                                , @c_SKU        NVARCHAR(20)
                                                , @c_NewLOT     NVARCHAR(10) OUTPUT
                                                , @n_LotQty     INT      OUTPUT
                                                , @c_NewID      NVARCHAR(18) OUTPUT
                                                , @c_Lottable01 NVARCHAR(18)
                                                , @c_Lottable02 NVARCHAR(18)
                                                , @c_Lottable03 NVARCHAR(18)
                                                , @d_Lottable04 DATETIME
                                                , @c_Lottable06 NVARCHAR(30)
                                                , @c_Lottable07 NVARCHAR(30)
                                                , @c_Lottable08 NVARCHAR(30)
                                                , @c_Lottable09 NVARCHAR(30)
                                                , @c_Lottable10 NVARCHAR(30)
                                                , @c_Lottable11 NVARCHAR(30)
                                                , @c_Lottable12 NVARCHAR(30)' --NJOW01
                                                , @c_StorerKey
                                                , @c_LOC
                                                , @c_SKU
                                                , @c_NewLOT OUTPUT
                                                , @n_LotQty OUTPUT
                                                , @c_NewID  OUTPUT
                                                , @c_Lottable01
                                                , @c_Lottable02
                                                , @c_Lottable03
                                                , @d_Lottable04
                                                , @c_Lottable06  --NJOW01
                                                , @c_Lottable07
                                                , @c_Lottable08
                                                , @c_Lottable09
                                                , @c_Lottable10
                                                , @c_Lottable11
                                                , @c_Lottable12
               SELECT @n_RowCount = @@ROWCOUNT

               --SELECT @c_SKU 'sku', @c_LOC 'loc', @c_NewLOT 'new lot', @c_PickDetailKey 'pickdetailkey',
               --@n_LotQty '@n_LotQty',@n_Qty '@n_Qty', @n_LOTQty2 '@n_LOTQty2', @c_LOT 'Old_LOT' , @n_RowCount '@n_RowCount'

               IF @n_RowCount = 0
               BEGIN
                  CLOSE PICK_CUR
                  DEALLOCATE PICK_CUR
                  GOTO READ_NEXT_RECORD
               END

               SET @n_LOTQty2=0

               SELECT @n_LOTQty2 = LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated  -- tlting01
               FROM LOT  With (NOLOCK)        -- tlting01
               WHERE  LOT = @c_NewLOT
               AND LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated > 0


               IF @n_LOTQty2 < @n_LotQty
                  SET @n_LotQty = @n_LOTQty2

               IF @n_LotQty = 0
                  GOTO GET_NEXT_LOT
            END

            --SET ROWCOUNT 0

            IF ISNULL(RTrim(@c_NewLOT),'') <> '' AND @n_RowCount > 0  AND @n_LotQty > 0
            BEGIN
               IF @n_LotQty >= @n_Qty
               BEGIN
                  BEGIN TRAN

                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET Lot = @c_NewLOT,
                      id  = @c_NewID,
                      editwho = 'wms', EditDate = GETDATE()
                  WHERE PickDetailKey = @c_PickDetailKey

                  SELECT @b_Err = @@ERROR

                  IF @b_Err <> 0
                  BEGIN
                     SELECT @c_SKU 'sku', @c_LOC 'loc', @c_NewLOT 'new lot', @c_PickDetailKey 'pickdetailkey'
                     ROLLBACK TRAN
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                     SELECT @n_rows = @n_rows + 1
                  END
                  -- Added By SHONG on 15-Feb-2005
                  IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_LOC  AND   LOT = @c_LOT
                            AND   ID = @c_ID AND ( Qty > QtyPicked + QtyAllocated) )
                  BEGIN
                     BEGIN TRAN

                     UPDATE LOTxLOCxID WITH (ROWLOCK)
                        SET QtyExpected = 0
                     WHERE LOT = @c_LOT
                     AND   LOC = @c_LOC
                     AND   ID = @c_ID
                     AND ( Qty >= QtyPicked + QtyAllocated )
                     IF @@ERROR <> 0
                     BEGIN
                        ROLLBACK TRAN
                     END
                     ELSE
                     BEGIN
                        COMMIT TRAN
                     END
                  END
               END -- If lot qty > pick qty
               ELSE -- Split PickDetail
               BEGIN
                  SELECT @b_Success = 0

                  EXECUTE   nspg_getkey
                        'PickDetailKey'
                        , 10
                        , @c_NewPickDetailKey OUTPUT
                        , @b_Success OUTPUT
                        , @b_Err OUTPUT
                        , @c_ErrMsg OUTPUT

                  IF @b_Success = 1
                  BEGIN
                     SELECT 'Update Pickdetail', @c_PickDetailKey "Pick Key",  @c_NewLOT  "LOT", @n_LotQty "Qty"

                     BEGIN TRAN

                     UPDATE PICKDETAIL WITH (ROWLOCK)
                        SET Qty = Qty - @n_LotQty,
                           editwho = 'wms', EditDate = GETDATE()
                     WHERE PickDetailKey = @c_PickDetailKey

                     IF @@ERROR = 0
                     BEGIN
                        INSERT PICKDETAIL
                           (PickDetailKey, PickHeaderKey, OrderKey,      OrderLineNumber,
                            Lot,           StorerKey,     Sku,           Qty,
                            Loc,           Id,            UOMQty,        UOM,
                            CaseID,        PackKey,       CartonGroup,   DoReplenish,
                            Replenishzone, docartonize,   Trafficcop,    PickMethod,
                            Status,        PickSlipNo,    AddWho,        EditWho,
                            ShipFlag,      DropID,        TaskDetailKey, AltSKU,
                            ToLoc)
                        SELECT @c_NewPickDetailKey,    PickHeaderKey,    OrderKey,     OrderLineNumber,
                               @c_NewLOT,              StorerKey,        Sku,          @n_LotQty,
                               Loc,                    @c_NewID,         UOMQty,       UOM,
                               CaseID,                 PackKey,          CartonGroup,  DoReplenish,
                               replenishzone,          docartonize,      Trafficcop,   PickMethod,
                               '0',                    PickSlipNo,       'wms',        'wms',
                               @c_ShipFlag,            DropID,           TaskDetailKey, AltSku,
                               ToLoc
                        FROM   PICKDETAIL (NOLOCK)
                        WHERE  PickDetailKey = @c_PickDetailKey

                        IF @@ERROR <> 0
                           ROLLBACK TRAN
                        ELSE
                        BEGIN
                           -- 23-06-2010 (Shong) Insert into RefKeyLookup for newly added Pickdetail Record.
                           IF EXISTS(SELECT 1 FROM RefKeyLookup rkl WITH (NOLOCK) WHERE rkl.PickDetailkey = @c_PickDetailKey)
                           BEGIN
                              INSERT INTO RefKeyLookup
                              (
                                 PickDetailkey,
                                 Pickslipno,
                                 OrderKey,
                                 OrderLineNumber,
                                 Loadkey
                              )
                              SELECT @c_NewPickDetailKey,
                                     rkl.Pickslipno,
                                     rkl.OrderKey,
                                     rkl.OrderLineNumber,
                                     rkl.Loadkey
                                FROM RefKeyLookup rkl
                              WHERE rkl.PickDetailkey = @c_PickDetailKey
                           END
                           SELECT @c_Status = STATUS
                           FROM   PICKDETAIL WITH (NOLOCK)
                           WHERE  PickDetailKey = @c_PickDetailKey

                           UPDATE PICKDETAIL WITH (ROWLOCK)
                           SET STATUS = @c_Status
                           WHERE  PickDetailKey = @c_NewPickDetailKey
                           AND    STATUS <> @c_Status

                           COMMIT TRAN
                           SELECT @n_rows = @n_rows + 1
                        END
                        SELECT 'Insert Pickdetail', @c_NewPickDetailKey "New Key",  @c_NewLOT  "LOT", @n_LotQty "Qty"
                     END
                  END
               END
            END
            SKIP_NEXT:
            FETCH NEXT FROM PICK_CUR IntO @c_PickDetailKey, @n_Qty, @c_shipflag, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12 --NJOW01
         END

         CLOSE PICK_CUR
         DEALLOCATE PICK_CUR

         READ_NEXT_RECORD:
         FETCH NEXT FROM LOT_CUR INTO @c_LOT, @c_LOC, @c_ID, @c_SKU
      END
      CLOSE LOT_CUR
      DEALLOCATE LOT_CUR
   END -- @n_Continue = 1

   QUIT:
END

GO