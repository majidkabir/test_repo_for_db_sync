SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspAL_HK01                                         */
/* Creation Date: 25-Jan-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16124 - [HK]_Nestle_Allocation Strategy_Exceed_New      */
/*          SkipPreallocation = '1'                                     */
/*                                                                      */
/*                                                                      */
/* Called By: Orders/Load/Wave                                          */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 04/03/2021   Michael 1.1   (ML01)                                    */
/*                            1. Fine tune Sorting sequence             */
/*                     2. Add StorerConfig NotAlcLooseQtyWhenFullCtnOrd */
/************************************************************************/
CREATE PROC [dbo].[nspAL_HK01]
   @c_DocumentNo NVARCHAR(10),
   @c_Facility   NVARCHAR(5),
   @c_StorerKey  NVARCHAR(15),
   @c_SKU        NVARCHAR(20),
   @c_Lottable01 NVARCHAR(18),
   @c_Lottable02 NVARCHAR(18),
   @c_Lottable03 NVARCHAR(18),
   @d_Lottable04 DATETIME,
   @d_Lottable05 DATETIME,
   @c_Lottable06 NVARCHAR(30),
   @c_Lottable07 NVARCHAR(30),
   @c_Lottable08 NVARCHAR(30),
   @c_Lottable09 NVARCHAR(30),
   @c_Lottable10 NVARCHAR(30),
   @c_Lottable11 NVARCHAR(30),
   @c_Lottable12 NVARCHAR(30),
   @d_Lottable13 DATETIME,
   @d_Lottable14 DATETIME,
   @d_Lottable15 DATETIME,
   @c_UOM        NVARCHAR(10),
   @c_HostWHCode NVARCHAR(10),
   @n_UOMBase    INT,
   @n_QtyLeftToFulfill INT,
   @c_OtherParms NVARCHAR(200)=''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @c_SQL                NVARCHAR(MAX),
           @c_SQLParm            NVARCHAR(MAX),
           @c_key1               NVARCHAR(10),
           @c_key2               NVARCHAR(5),
           @c_key3               NCHAR(1),
           @c_Orderkey           NVARCHAR(10),
           @n_QtyAvailable       INT,
           @c_LOT                NVARCHAR(10),
           @c_LOC                NVARCHAR(10),
           @c_ID                 NVARCHAR(18),
           @c_OtherValue         NVARCHAR(20),
           @n_QtyToTake          INT,
           @n_StorerMinShelfLife INT,
           @c_PrevLOT            NVARCHAR(10),
           @n_LotQtyAvailable    INT,
           @c_ExtraCond          NVARCHAR(4000)

   SET @n_QtyAvailable = 0
   SET @c_OtherValue = '1'
   SET @n_QtyToTake = 0
   SET @c_ExtraCond = ''

   IF @n_UOMBase = 0
      SET @n_UOMBase = 1

   EXEC isp_Init_Allocate_Candidates

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))

   IF LEN(@c_OtherParms) > 0
   BEGIN
      -- this pickcode can call from wave by discrete / load conso / wave conso
      SET @c_OrderKey = LEFT(@c_OtherParms,10)  --if call by discrete
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave

      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='' --call by load conso
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK)
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE O.Loadkey = @c_key1
         AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END

      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' --call by wave conso
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK)
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE O.Userdefine09 = @c_key1
         AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END
   END

   --IF @c_UOM NOT IN ('2','3','6')
   --   GOTO EXIT_SP

   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
   FROM Sku (nolock)
   JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
   WHERE Sku.Sku = @c_sku
   AND Sku.Storerkey = @c_storerkey

   IF @n_StorerMinShelfLife IS NULL
      SELECT @n_StorerMinShelfLife = 0

   -- ML01 Start
   DECLARE @n_Pallet             INT = 0
         , @n_CaseCnt            INT = 0
         , @n_InnerPack          INT = 0
         , @n_ConvFactor         INT = 0
         , @c_PalletUOM          NVARCHAR(10) = ''
         , @c_CaseUOM            NVARCHAR(10) = ''
         , @c_InnerUOM           NVARCHAR(10) = ''
         , @c_OrderUOM           NVARCHAR(10) = ''
         , @c_SpecifyLot         NVARCHAR(1)  = ''
         , @c_LOTTABLE04LABEL    NVARCHAR(20) = ''

   SELECT @n_Pallet          = ISNULL(PACK.Pallet   , 0)
        , @n_CaseCnt         = ISNULL(PACK.CaseCnt  , 0)
        , @n_InnerPack       = ISNULL(PACK.InnerPack, 0)
        , @c_PalletUOM       = ISNULL(PACK.PACKUOM4, '')
        , @c_CaseUOM         = ISNULL(PACK.PACKUOM1, '')
        , @c_InnerUOM        = ISNULL(PACK.PACKUOM2, '')
        , @c_LOTTABLE04LABEL = ISNULL(SKU.LOTTABLE04LABEL, '')
   FROM dbo.SKU  SKU (NOLOCK)
   JOIN dbo.PACK PACK(NOLOCK) ON SKU.Packkey = PACK.Packkey
   WHERE SKU.Storerkey=@c_storerkey AND SKU.Sku=@c_sku

   IF @c_Orderkey<>'' AND @c_key2<>''
   BEGIN
      SELECT @c_OrderUOM = UOM
        FROM dbo.ORDERDETAIL (NOLOCK)
       WHERE Orderkey = @c_Orderkey AND OrderLineNumber = @c_key2 AND SKU = @c_SKU
   END

   SET @n_ConvFactor = CASE @c_OrderUOM
                            WHEN @c_InnerUOM    THEN @n_InnerPack
                            WHEN @c_CaseUOM     THEN @n_CaseCnt
                            WHEN @c_PalletUOM   THEN @n_Pallet
                            ELSE 0
                       END
   IF @n_ConvFactor = 0
   BEGIN
      SET @n_ConvFactor = CASE WHEN @n_InnerPack>0 THEN @n_InnerPack
                               WHEN @n_CaseCnt  >0 THEN @n_CaseCnt
                               WHEN @n_Pallet   >0 THEN @n_Pallet
                               ELSE 0
                          END
   END

   SET @c_SpecifyLot = CASE WHEN (ISNULL(@c_Lottable01,'')<>'' OR ISNULL(@c_Lottable02,'')<>'' OR ISNULL(@c_Lottable03,'')<>'' OR
                                  ISNULL(@d_Lottable04,'')<>'' OR ISNULL(@d_Lottable05,'')<>'' OR ISNULL(@c_Lottable06,'')<>'' OR
                                  ISNULL(@c_Lottable07,'')<>'' OR ISNULL(@c_Lottable08,'')<>'' OR ISNULL(@c_Lottable09,'')<>'' OR
                                  ISNULL(@c_Lottable10,'')<>'' OR ISNULL(@c_Lottable11,'')<>'' OR ISNULL(@c_Lottable12,'')<>'' OR
                                  ISNULL(@d_Lottable13,'')<>'' OR ISNULL(@d_Lottable14,'')<>'' OR ISNULL(@d_Lottable15,'')<>'')
                            THEN 'Y' ELSE 'N'
                       END

   SET @c_SQL = N'
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT, LOC, ID, QTYAVAILABLE
      FROM (
        SELECT *
             , PalletQty = CASE WHEN @n_Pallet   >0 THEN FLOOR(QTYAVAILABLE / @n_Pallet) ELSE 0 END
             , CaseQty   = CASE WHEN @n_CaseCnt  >0 THEN FLOOR(CASE WHEN @n_Pallet>0  THEN QTYAVAILABLE % @n_Pallet ELSE QTYAVAILABLE END / @n_CaseCnt) ELSE 0 END
             , InnerQty  = CASE WHEN @n_InnerPack>0
                           THEN FLOOR(CASE WHEN @n_CaseCnt>0
                                      THEN CASE WHEN @n_Pallet>0 THEN QTYAVAILABLE % @n_Pallet ELSE QTYAVAILABLE END % @n_CaseCnt
                                      ELSE CASE WHEN @n_Pallet>0 THEN QTYAVAILABLE % @n_Pallet ELSE QTYAVAILABLE END
                                      END / @n_InnerPack)
                           ELSE 0 END
             , EachQty   = CASE WHEN @n_InnerPack>0
                           THEN CASE WHEN @n_CaseCnt>0
                                THEN CASE WHEN @n_Pallet>0 THEN QTYAVAILABLE % @n_Pallet ELSE QTYAVAILABLE END % @n_CaseCnt
                                ELSE CASE WHEN @n_Pallet>0 THEN QTYAVAILABLE % @n_Pallet ELSE QTYAVAILABLE END
                                END % @n_InnerPack
                           ELSE CASE WHEN @n_CaseCnt>0
                                THEN CASE WHEN @n_Pallet>0 THEN QTYAVAILABLE % @n_Pallet ELSE QTYAVAILABLE END % @n_CaseCnt
                                ELSE CASE WHEN @n_Pallet>0 THEN QTYAVAILABLE % @n_Pallet ELSE QTYAVAILABLE END
                                END
                           END
        FROM (
          SELECT LOTxLOCxID.LOT,
                 LOTxLOCxID.LOC,
                 LOTxLOCxID.ID,
                 QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN),
                 LA.Lottable04,
                 LOC.LogicalLocation
          FROM LOTxLOCxID (NOLOCK)
          JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
          JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
          JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
          JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
          JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
          WHERE LOC.LocationFlag <> ''DAMAGE''
          AND LOC.LocationFlag = ''NONE''
          AND LOC.Status <> ''HOLD'''

   IF ISNULL(@c_SpecifyLot,'')<>'Y'
   BEGIN
      SET @c_SQL = @c_SQL + N'
             AND LOT.Status <> ''HOLD''
             AND LOT.Status = ''OK'''
   END

   SET @c_SQL = @c_SQL + N'
          AND ID.Status <> ''HOLD''
          AND ID.Status = ''OK''
          AND LOC.Facility = @c_Facility
          AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) >= @n_UOMBase
          AND LOTxLOCxID.STORERKEY = @c_StorerKey
          AND LOTxLOCxID.SKU = @c_SKU
          AND LOC.Locationflag NOT IN (''HOLD'',''DAMAGE'') '
   SET @c_SQL = @c_SQL + @c_ExtraCond
   SET @c_SQL = @c_SQL +
          CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END +
          CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END +
          CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END +
          CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
          CASE WHEN @n_StorerMinShelfLife <> 0 THEN ' AND DateAdd(Day, ' + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ', LA.Lottable04) > GetDate() ' ELSE ' ' END +
          CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
          CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END +
          CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END +
          CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END +
          CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END +
          CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END +
          CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END +
          CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END +
          CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
          CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
          CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END
   SET @c_SQL = @c_SQL + N'
        ) X
      ) Y
      WHERE 1=1'

   IF @c_UOM='6' AND
      EXISTS(SELECT TOP 1 1 FROM dbo.STORERCONFIG (NOLOCK)
             WHERE Storerkey=@c_StorerKey AND Configkey='NotAlcLooseQtyWhenFullCtnOrd' AND SValue='1')
   BEGIN
      IF @n_QtyLeftToFulfill % @n_ConvFactor = 0
         SET @c_SQL = @c_SQL + N' AND QTYAVAILABLE >= @n_QtyLeftToFulfill'
   END

   SET @c_SQL = @c_SQL + N'
      ORDER BY ' + CASE WHEN @c_LOTTABLE04LABEL<>'' THEN 'Lottable04,' ELSE '' END + '
        CASE WHEN @n_UOMBase >= @n_Pallet                                                              THEN 0
             WHEN PalletQty = 0 AND CaseQty = 0 AND InnerQty = 0                                       THEN 110 /*Less than Inner*/
             WHEN PalletQty = 0 AND CaseQty = 0 AND InnerQty>= 1 AND @n_QtyLeftToFulfill<=EachQty      THEN 120 /*More than Inner but the EachQty more than required*/
             WHEN PalletQty = 0 AND CaseQty = 0 AND InnerQty>= 1 AND @n_QtyLeftToFulfill<=
                  InnerQty*@n_InnerPack+EachQty                                                        THEN 130 /*More than Inner but the InnerQty more than required*/
             WHEN PalletQty = 0 AND CaseQty = 0 AND InnerQty>= 1 AND EachQty > 0                       THEN 140 /*More than Inner but have loose Inner*/
             WHEN PalletQty = 0 AND CaseQty = 0 AND InnerQty>= 1                                       THEN 150 /*Full Inner*/
             WHEN PalletQty = 0 AND CaseQty = 0                                                        THEN 210 /*Less than Case*/
             WHEN PalletQty = 0 AND CaseQty>= 1 AND @n_QtyLeftToFulfill<=InnerQty*@n_InnerPack+EachQty THEN 220 /*More than Case but InnerQty more than required*/
             WHEN PalletQty = 0 AND CaseQty>= 1 AND @n_QtyLeftToFulfill<=
                  QTYAVAILABLE - PalletQty*@n_Pallet                                                   THEN 230 /*More than Case but CaseQty more than required*/
             WHEN PalletQty = 0 AND CaseQty>= 1 AND InnerQty*@n_InnerPack+EachQty > 0                  THEN 240 /*More than Case but has loose Case*/
             WHEN PalletQty = 0 AND CaseQty>= 1                                                        THEN 250 /*Full Case*/
             WHEN PalletQty = 0                                                                        THEN 310 /*Less than Pallet*/
             WHEN PalletQty>= 1 AND @n_QtyLeftToFulfill<=QTYAVAILABLE-PalletQty*@n_Pallet              THEN 320 /*More than Pallet but the rest more than required*/
             WHEN PalletQty>= 1 AND QTYAVAILABLE - PalletQty*@n_Pallet > 0                             THEN 330 /*More than Pallet but has loose Pallet*/
             WHEN PalletQty>= 1                                                                        THEN 340 /*Full Pallet*/
             ELSE 999
        END
      , LogicalLocation
      , Loc'

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME, ' +
                      '@n_Pallet INT, @n_CaseCnt INT, @n_InnerPack INT'

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15,
                      @n_Pallet, @n_CaseCnt, @n_InnerPack
   -- ML01 End

   --PRINT @c_SQL
   SET @c_SQL = ''
   SET @c_PrevLOT = ''
   SET @n_LotQtyAvailable = 0

   OPEN CURSOR_AVAILABLE
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable

   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
      BEGIN
         INSERT INTO #TMP_LOT (Lot, QtyAvailable)
         SELECT Lot, Qty - QtyAllocated - QtyPicked
         FROM LOT (NOLOCK)
         WHERE LOT = @c_LOT
      END
      SET @n_LotQtyAvailable = 0

      SELECT @n_LotQtyAvailable = QtyAvailable
      FROM #TMP_LOT
      WHERE Lot = @c_Lot

      IF @n_LotQtyAvailable < @n_QtyAvailable
      BEGIN
         IF @c_UOM = '1'
            SET @n_QtyAvailable = 0
         ELSE
            SET @n_QtyAvailable = @n_LotQtyAvailable
      END

      IF @n_QtyLeftToFulfill >= @n_QtyAvailable
      BEGIN
         SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
      END
      ELSE
      BEGIN
         SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
      END

      IF @n_QtyToTake > 0
      BEGIN
         UPDATE #TMP_LOT
         SET QtyAvailable = QtyAvailable - @n_QtyToTake
         WHERE Lot = @c_Lot

         /*IF ISNULL(@c_SQL,'') = ''
         BEGIN
            SET @c_SQL = N'
                  DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                  '
         END
         ELSE
         BEGIN
            SET @c_SQL = @c_SQL + N'
                  UNION ALL
                  SELECT ''' + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                  '
         END*/

         SET @c_Lot       = RTRIM(@c_Lot)
         SET @c_Loc       = RTRIM(@c_Loc)
         SET @c_ID        = RTRIM(@c_ID)

         EXEC isp_Insert_Allocate_Candidates
            @c_Lot = @c_Lot
         ,  @c_Loc = @c_Loc
         ,  @c_ID  = @c_ID
         ,  @n_QtyAvailable = @n_QtyToTake
         ,  @c_OtherValue = @c_OtherValue

         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake
      END

      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable
   END -- END WHILE FOR CURSOR_AVAILABLE

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)
   BEGIN
      CLOSE CURSOR_AVAILABLE
      DEALLOCATE CURSOR_AVAILABLE
   END

   /*IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL
   END*/

   EXEC isp_Cursor_Allocate_Candidates
         @n_SkipPreAllocationFlag = 1    --Return Lot column

END -- Procedure

GO