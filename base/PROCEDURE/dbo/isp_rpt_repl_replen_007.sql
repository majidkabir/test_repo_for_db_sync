SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_REPL_REPLEN_007                               */
/* Creation Date: 09-Dec-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS- 18554 - Migrate WMS report to Logi Report.                */
/*         : modify from isp_ReplenishmentRpt_PC26                         */
/*                                                                         */
/* Called By: RPT_REPL_REPLEN_007                                          */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 04-Jan-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE PROC [dbo].[isp_RPT_REPL_REPLEN_007]
               @c_Zone01           NVARCHAR(10)
,              @c_Zone02           NVARCHAR(10)
,              @c_Zone03           NVARCHAR(10)
,              @c_Zone04           NVARCHAR(10)
,              @c_Zone05           NVARCHAR(10)
,              @c_Zone06           NVARCHAR(10)
,              @c_Zone07           NVARCHAR(10)
,              @c_Zone08           NVARCHAR(10)
,              @c_Zone09           NVARCHAR(10)
,              @c_Zone10           NVARCHAR(10)
,              @c_Zone11           NVARCHAR(10)
,              @c_Zone12           NVARCHAR(10)
,              @c_StorerKey        NVARCHAR(15)
,              @c_ReplGrp          NVARCHAR(30) = 'ALL'
,              @c_Functype NCHAR(1) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug INT
          ,@n_continue int
          ,@b_success   INT
          ,@n_err       INT
          ,@c_errmsg    NVARCHAR(255)

   DECLARE @c_CurrSKU NVARCHAR(20)
          ,@c_CurrStorer NVARCHAR(15)
          ,@c_CurrLoc NVARCHAR(10)
          ,@c_SQL NVARCHAR(MAX)
          ,@c_ReplenishmentGroup NVARCHAR(10)
          ,@c_FromLoc NVARCHAR(10)
          ,@c_Fromlot NVARCHAR(10)
          ,@c_Fromid NVARCHAR(18)
          ,@n_FromQty INT
          ,@c_Packkey NVARCHAR(10)
          ,@c_UOM NVARCHAR(10)
          ,@c_HostWHCode NVARCHAR(10)
          ,@n_QtyLocationMinimum INT
          ,@n_QtyLocationLimit INT
          ,@c_ReplenishmentKey NVARCHAR(10)
          ,@c_facility NVARCHAR(5)
          ,@c_PrevLoc NVARCHAR(10)
          ,@c_PrevID NVARCHAR(18)
          ,@n_LocQty INT


   DECLARE @c_NoMixLottable01 NCHAR(1),
           @c_NoMixLottable02 NCHAR(1),
           @c_NoMixLottable03 NCHAR(1),
           @c_NoMixLottable04 NCHAR(1),
           @c_NoMixLottable05 NCHAR(1),
           @c_NoMixLottable06 NCHAR(1),
           @c_NoMixLottable07 NCHAR(1),
           @c_NoMixLottable08 NCHAR(1),
           @c_NoMixLottable09 NCHAR(1),
           @c_NoMixLottable10 NCHAR(1),
           @c_NoMixLottable11 NCHAR(1),
           @c_NoMixLottable12 NCHAR(1),
           @c_NoMixLottable13 NCHAR(1),
           @c_NoMixLottable14 NCHAR(1),
           @c_NoMixLottable15 NCHAR(1),
           @c_CurrLottable01 NVARCHAR(18),
           @c_CurrLottable02 NVARCHAR(18),
           @c_CurrLottable03 NVARCHAR(18),
           @dt_CurrLottable04 DATETIME,
           @dt_CurrLottable05 DATETIME,
           @c_CurrLottable06 NVARCHAR(30),
           @c_CurrLottable07 NVARCHAR(30),
           @c_CurrLottable08 NVARCHAR(30),
           @c_CurrLottable09 NVARCHAR(30),
           @c_CurrLottable10 NVARCHAR(30),
           @c_CurrLottable11 NVARCHAR(30),
           @c_CurrLottable12 NVARCHAR(30),
           @dt_CurrLottable13 DATETIME,
           @dt_CurrLottable14 DATETIME,
           @dt_CurrLottable15 DATETIME,
           @c_LotSort NVARCHAR(2000),
           @c_LotFilter NVARCHAR(2000),
           @c_LotGroup NVARCHAR(2000),
           @c_LotSortLottable NVARCHAR(2000),
           @n_BalQty INT,
           @n_ReplenQty INT,
           @n_OverAllocateQty INT,
           @c_Lottable01 NVARCHAR(18),
           @c_Lottable02 NVARCHAR(18),
           @c_Lottable03 NVARCHAR(18),
           @c_Lottable04 NVARCHAR(10),
           @c_Lottable05 NVARCHAR(10),
           @c_Lottable06 NVARCHAR(30),
           @c_Lottable07 NVARCHAR(30),
           @c_Lottable08 NVARCHAR(30),
           @c_Lottable09 NVARCHAR(30),
           @c_Lottable10 NVARCHAR(30),
           @c_Lottable11 NVARCHAR(30),
           @c_Lottable12 NVARCHAR(30),
           @c_Lottable13 NVARCHAR(10),
           @c_Lottable14 NVARCHAR(10),
           @c_Lottable15 NVARCHAR(10)

   SELECT @n_continue=1, @n_err = 0, @b_success = 1, @c_errmsg = '', @b_debug = 0, @c_ReplenishmentGroup = ''

   IF @c_Zone12 = '1'
   BEGIN
      SELECT @b_debug = CAST( @c_Zone12 AS int)
      SELECT @c_Zone12 = ''
   END


   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END


   IF @c_FuncType IN ( 'P' )
   BEGIN
      GOTO QUIT_SP
   END

   CREATE TABLE #LOTTABLEGROUP (RowID INT IDENTITY(1,1),
                                Storerkey NVARCHAR(15) NULL,
                                Sku NVARCHAR(20) NULL,
                                Lottable01 NVARCHAR(18) NULL,
                                Lottable02 NVARCHAR(18) NULL,
                                Lottable03 NVARCHAR(18) NULL,
                                Lottable04 NVARCHAR(10) NULL,
                                Lottable05 NVARCHAR(10) NULL,
                                Lottable06 NVARCHAR(30) NULL,
                                Lottable07 NVARCHAR(30) NULL,
                                Lottable08 NVARCHAR(30) NULL,
                                Lottable09 NVARCHAR(30) NULL,
                                Lottable10 NVARCHAR(30) NULL,
                                Lottable11 NVARCHAR(30) NULL,
                                Lottable12 NVARCHAR(30) NULL,
                                Lottable13 NVARCHAR(10) NULL,
                                Lottable14 NVARCHAR(10) NULL,
                                Lottable15 NVARCHAR(10) NULL,
                                QtyAvailable INT NULL)

   CREATE TABLE #OVERLOT (LOT NVARCHAR(10) NULL)

   CREATE TABLE #LOTXLOCXID (Lot NVARCHAR(10) NULL,
                             Loc NVARCHAR(10) NULL,
                             Id  NVARCHAR(18) NULL,
                             QtyAvailable INT NULL)

   CREATE TABLE #LOCxLOTTABLE (Loc NVARCHAR(10) NULL,
                               Lottable01 NVARCHAR(18) NULL,
                               Lottable02 NVARCHAR(18) NULL,
                               Lottable03 NVARCHAR(18) NULL,
                               Lottable04 DATETIME NULL,
                               Lottable05 DATETIME NULL,
                               Lottable06 NVARCHAR(30) NULL,
                               Lottable07 NVARCHAR(30) NULL,
                               Lottable08 NVARCHAR(30) NULL,
                               Lottable09 NVARCHAR(30) NULL,
                               Lottable10 NVARCHAR(30) NULL,
                               Lottable11 NVARCHAR(30) NULL,
                               Lottable12 NVARCHAR(30) NULL,
                               Lottable13 DATETIME NULL,
                               Lottable14 DATETIME NULL,
                               Lottable15 DATETIME NULL,
                               QtyAvailable INT NULL,
                               Seq INT NULL)

   DECLARE CUR_SKUXLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKUxLOC.Storerkey, SKUxLOC.Sku, SKUxLOC.Loc, LOC.Facility,
             (SKUxLOC.Qty - SKUxLOC.QtyPicked) AS BalQty,
             CASE WHEN ISNULL(EXT.QtyExpected,0) = 0 AND(SKUxLOC.Qty - SKUxLOC.QtyAllocated) + ISNULL(EXT.PendingMoveIn,0) < SKUxLOC.QtyLocationMinimum THEN --No overallocate and below min, just replen to loc max
                     CASE WHEN PACK.Casecnt = 0 THEN SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked) - ISNULL(EXT.PendingMoveIn,0)
                                                ELSE (CEILING((SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked) - ISNULL(EXT.PendingMoveIn,0)) / CAST(PACK.Casecnt AS INT)) * CAST(PACK.Casecnt AS INT)) END
                  WHEN ISNULL(EXT.QtyExpected,0) > 0 AND SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked) - ISNULL(EXT.PendingMoveIn,0) < ISNULL(EXT.QtyExpected,0) THEN --Overallocte qty more than loc max, just replen overalocate qty
                     CASE WHEN PACK.Casecnt = 0 THEN ISNULL(EXT.QtyExpected,0)
                                                ELSE (CEILING((ISNULL(EXT.QtyExpected,0) / CAST(PACK.Casecnt AS INT))) * CAST(PACK.Casecnt AS INT)) END
                  WHEN ISNULL(EXT.QtyExpected,0) > 0 AND SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked) - ISNULL(EXT.PendingMoveIn,0) >= ISNULL(EXT.QtyExpected,0) THEN --Overallocte qty less than loc max, just replen max qty
                     CASE WHEN PACK.Casecnt = 0 THEN SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked) - ISNULL(EXT.PendingMoveIn,0)
                                                ELSE (CEILING((SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked) - ISNULL(EXT.PendingMoveIn,0)) / CAST(PACK.Casecnt AS INT)) * CAST(PACK.Casecnt AS INT)) END
                  ELSE
                     CASE WHEN PACK.Casecnt = 0 THEN PACK.Qty
                                                ELSE (CEILING(((SKUxLOC.QtyLocationLimit - (SKUxLOC.Qty - SKUxLOC.QtyPicked) - ISNULL(EXT.PendingMoveIn,0) + SKUXLOC.QtyExpected ) / CAST(PACK.Casecnt AS INT))) * CAST(PACK.Casecnt AS INT)) END
             END AS ReplenQty,
             SKUxLOC.QtyLocationMinimum,
             SKUxLOC.QtyLocationLimit,
             PACK.Packkey,
             PACK.PackUOM3,
             LOC.HostWHCode,
             LOC.NoMixLottable01,
             LOC.NoMixLottable02,
             LOC.NoMixLottable03,
             LOC.NoMixLottable04,
             LOC.NoMixLottable05,
             LOC.NoMixLottable06,
             LOC.NoMixLottable07,
             LOC.NoMixLottable08,
             LOC.NoMixLottable09,
             LOC.NoMixLottable10,
             LOC.NoMixLottable11,
             LOC.NoMixLottable12,
             LOC.NoMixLottable13,
             LOC.NoMixLottable14,
             LOC.NoMixLottable15,
             ISNULL(EXT.QtyExpected,0)
             --SKUXLoc.QtyExpected
      From SKUxLOC (NOLOCK)
      JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
      JOIN SKU (NOLOCK) ON SKU.StorerKey = SKUxLOC.StorerKey
                               AND  SKU.SKU = SKUxLOC.SKU
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      OUTER APPLY dbo.fnc_skuxloc_extended(SKUxLOC.StorerKey, SKUxLOC.Sku, SKUxLOC.Loc) AS EXT
      WHERE SKUxLOC.LocationType IN('PICK','CASE')
      AND  (LOC.Facility = @c_Zone01 OR ISNULL(@c_Zone01,'') = '')
      AND  (LOC.PutawayZone in (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)
            OR @c_Zone02 = 'ALL')
      AND (SKUxLOC.StorerKey = @c_Storerkey OR @c_StorerKey IN('ALL',''))
      AND ((SKUxLOC.Qty - SKUxLOC.QtyAllocated) + ISNULL(EXT.PendingMoveIn,0) < SKUxLOC.QtyLocationMinimum
           OR ISNULL(EXT.QtyExpected,0) > 0)
      ORDER BY SKUxLOC.Storerkey, SKUxLOC.Sku, SKUxLOC.Loc

      OPEN CUR_SKUXLOC

      FETCH NEXT FROM CUR_SKUXLOC INTO @c_CurrStorer, @c_CurrSKU, @c_CurrLoc, @c_Facility, @n_BalQty, @n_ReplenQty, @n_QtyLocationMinimum, @n_QtyLocationLimit, @C_Packkey, @c_UOM, @c_HostWHCode,
                                       @c_NoMixLottable01, @c_NoMixLottable02, @c_NoMixLottable03, @c_NoMixLottable04, @c_NoMixLottable05, @c_NoMixLottable06, @c_NoMixLottable07,
                                       @c_NoMixLottable08, @c_NoMixLottable09, @c_NoMixLottable10, @c_NoMixLottable11, @c_NoMixLottable12, @c_NoMixLottable13, @c_NoMixLottable14, @c_NoMixLottable15,
                                       @n_OverAllocateQty

      IF @@FETCH_STATUS <> -1
      BEGIN
         EXECUTE nspg_GetKey
            'REPLENGROUP',
            9,
            @c_ReplenishmentGroup OUTPUT,
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT

         IF @b_success = 1
            SELECT @c_ReplenishmentGroup = 'T' + @c_ReplenishmentGroup
      END

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN
          IF @b_debug = 1
          BEGIN
             PRINT ''
             PRINT '-----------Start---------'
            PRINT '@c_CurrStorer=' + @c_currStorer + ' @c_CurrSku=' + @c_CurrSku + ' @c_CurrLoc=' + @c_CurrLoc + ' @n_BalQty=' + CAST(@n_BalQty AS NVARCHAR) +  ' @n_ReplenQty=' + CAST(@n_ReplenQty AS NVARCHAR) + ' @c_zone01=' + @c_zone01
            PRINT '@n_QtyLocationMinimum=' + CAST(@n_QtyLocationMinimum AS NVARCHAR) + ' @n_QtyLocationLimit=' + CAST(@n_QtyLocationLimit AS NVARCHAR) + ' @n_OverAllocateQty=' + CAST(@n_OverAllocateQty AS NVARCHAR)
            PRINT '@c_NoMixLottable1-15=' + @c_NoMixLottable01+@c_NoMixLottable02+@c_NoMixLottable03+@c_NoMixLottable04+@c_NoMixLottable05+@c_NoMixLottable06+@c_NoMixLottable07+
                  @c_NoMixLottable08+@c_NoMixLottable09+@c_NoMixLottable10+@c_NoMixLottable11+@c_NoMixLottable12+@c_NoMixLottable13+@c_NoMixLottable14+@c_NoMixLottable15
          END

          SELECT @c_LotSort = '', @c_LotGroup = '', @c_LotFilter = '', @c_LotSortLottable = ''

          SELECT TOP 1 @c_LotSort = ISNULL(CL.Long,'')
          FROM CODELKUP CL (NOLOCK)
          WHERE CL.Storerkey = @c_CurrStorer
          AND CL.Listname = 'REPLNCFG'
          AND CL.Code = 'LOTSORT'

          IF ISNULL(@c_LotSort,'') <> ''
             SET @C_LotSort = ',' + LTRIM(RTRIM(@c_LotSort))

          SELECT TOP 1 @c_LotFilter = ISNULL(CL.Long,'')
          FROM CODELKUP CL (NOLOCK)
          WHERE CL.Storerkey = @c_CurrStorer
          AND CL.Listname = 'REPLNCFG'
          AND CL.Code = 'LOTFILTER'

          IF ISNULL(@c_LotFilter,'') <> ''
             SET @c_LotFilter = ' AND ' + LTRIM(RTRIM(@c_LotFilter))

          SELECT TOP 1 @c_LotGroup = ISNULL(CL.Long,'')
          FROM CODELKUP CL (NOLOCK)
          WHERE CL.Storerkey = @c_CurrStorer
          AND CL.Listname = 'REPLNCFG'
          AND CL.Code = 'LOTGROUP'

         SELECT @c_LotSortLottable = @c_LotSortLottable +
            CASE WHEN Colvalue IN( 'lottable04','lottable05','lottable13','lottable14','lottable15') THEN 'CONVERT(NVARCHAR,' + ColValue + ',112)'  ELSE ColValue END + ','
         FROM dbo.fnc_DelimSplit(',',@c_LotSort)
         WHERE (ColValue = 'lottable01' AND (CHARINDEX('Lottable01',@c_LotGroup,1) > 0 OR @c_NoMixLottable01 = '1'))
            OR (ColValue = 'lottable02' AND (CHARINDEX('Lottable02',@c_LotGroup,1) > 0 OR @c_NoMixLottable02 = '1'))
            OR (ColValue = 'lottable03' AND (CHARINDEX('Lottable03',@c_LotGroup,1) > 0 OR @c_NoMixLottable03 = '1'))
            OR (ColValue = 'lottable04' AND (CHARINDEX('Lottable04',@c_LotGroup,1) > 0 OR @c_NoMixLottable04 = '1'))
            OR (ColValue = 'lottable05' AND (CHARINDEX('Lottable05',@c_LotGroup,1) > 0 OR @c_NoMixLottable05 = '1'))
            OR (ColValue = 'lottable06' AND (CHARINDEX('Lottable06',@c_LotGroup,1) > 0 OR @c_NoMixLottable06 = '1'))
            OR (ColValue = 'lottable07' AND (CHARINDEX('Lottable07',@c_LotGroup,1) > 0 OR @c_NoMixLottable07 = '1'))
            OR (ColValue = 'lottable08' AND (CHARINDEX('Lottable08',@c_LotGroup,1) > 0 OR @c_NoMixLottable08 = '1'))
            OR (ColValue = 'lottable09' AND (CHARINDEX('Lottable09',@c_LotGroup,1) > 0 OR @c_NoMixLottable09 = '1'))
            OR (ColValue = 'lottable10' AND (CHARINDEX('Lottable10',@c_LotGroup,1) > 0 OR @c_NoMixLottable10 = '1'))
            OR (ColValue = 'lottable11' AND (CHARINDEX('Lottable11',@c_LotGroup,1) > 0 OR @c_NoMixLottable11 = '1'))
            OR (ColValue = 'lottable12' AND (CHARINDEX('Lottable12',@c_LotGroup,1) > 0 OR @c_NoMixLottable12 = '1'))
            OR (ColValue = 'lottable13' AND (CHARINDEX('Lottable13',@c_LotGroup,1) > 0 OR @c_NoMixLottable13 = '1'))
            OR (ColValue = 'lottable14' AND (CHARINDEX('Lottable14',@c_LotGroup,1) > 0 OR @c_NoMixLottable14 = '1'))
            OR (ColValue = 'lottable15' AND (CHARINDEX('Lottable15',@c_LotGroup,1) > 0 OR @c_NoMixLottable15 = '1'))
         ORDER BY Seqno

         IF LEN(@c_LotSortLottable) > 0
            SELECT @c_LotSortLottable = ',' + LEFT(@c_LotSortLottable, LEN(@c_LotSortLottable)-1)

          IF @b_debug = 1
            PRINT '@c_LotSort=' + @c_LotSort + ' @c_LotFilter=' + @c_LotFilter + ' @c_LotGroup=' + @c_LotGroup + ' @c_LotSortLottable=' + @c_LotSortLottable

         TRUNCATE TABLE #LOTTABLEGROUP
         TRUNCATE TABLE #OVERLOT

          IF @n_BalQty > 0 OR @n_OverAllocateQty > 0
          BEGIN
             SELECT TOP 1 @c_CurrLottable01 = LA.Lottable01,
                          @c_CurrLottable02 = LA.Lottable02,
                          @c_CurrLottable03 = LA.Lottable03,
                          @dt_CurrLottable04 = LA.Lottable04,
                          @dt_CurrLottable05 = LA.Lottable05,
                          @c_CurrLottable06 = LA.Lottable06,
                          @c_CurrLottable07 = LA.Lottable07,
                          @c_CurrLottable08 = LA.Lottable08,
                          @c_CurrLottable09 = LA.Lottable09,
                          @c_CurrLottable10 = LA.Lottable10,
                          @c_CurrLottable11 = LA.Lottable11,
                          @c_CurrLottable12 = LA.Lottable12,
                          @dt_CurrLottable13 = LA.Lottable13,
                          @dt_CurrLottable14 = LA.Lottable14,
                          @dt_CurrLottable15 = LA.Lottable15
             FROM LOTXLOCXID LLI (NOLOCK)
             JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
             WHERE LLI.Storerkey = @c_CurrStorer
             AND LLI.Sku = @c_CurrSku
             AND LLI.Loc = @c_Currloc
             AND (LLI.Qty - LLI.QtyPicked > 0 OR LLI.QtyExpected > 0 )
             ORDER BY LLI.Qtyexpected DESC, LLI.Qty DESC

              IF @b_debug = 1
                 PRINT '@c_Currlottable1-15=' + @c_CurrLottable01+','+@c_CurrLottable02+','+@c_CurrLottable03+','+CONVERT(NVARCHAR,@dt_CurrLottable04,112)+','+CONVERT(NVARCHAR,@dt_CurrLottable05,112)+','+@c_CurrLottable06+','+@c_CurrLottable07+','+
                     @c_CurrLottable08+','+@c_CurrLottable09+','+@c_CurrLottable10+','+@c_CurrLottable11+','+@c_CurrLottable12+','+CONVERT(NVARCHAR,@dt_CurrLottable13,112)+','+CONVERT(NVARCHAR,@dt_CurrLottable14,112)+','+ CONVERT(NVARCHAR,@dt_CurrLottable15,12)


             IF @n_OverAllocateQty > 0
             BEGIN
                INSERT INTO #OVERLOT (LOT)
                SELECT DISTINCT Lot
                FROM LOTXLOCXID LLI (NOLOCK)
                WHERE LLI.Storerkey = @c_CurrStorer
                AND LLI.Sku = @c_CurrSku
                AND LLI.Loc = @c_Currloc
                AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked < 0
             END
          END

         SET @c_SQL = N'
            INSERT INTO #LOTTABLEGROUP (Storerkey, Sku, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08,
                                        Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, QtyAvailable)
            SELECT LLI.Storerkey, LLI.Sku, ' +
            CASE WHEN @c_NoMixLottable01 = '1' OR CHARINDEX('Lottable01',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable01' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable02 = '1' OR CHARINDEX('Lottable02',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable02' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable03 = '1' OR CHARINDEX('Lottable03',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable03' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable04 = '1' OR CHARINDEX('Lottable04',@c_LotGroup,1) > 0 THEN 'CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable04,112)' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable05 = '1' OR CHARINDEX('Lottable05',@c_LotGroup,1) > 0 THEN 'CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable05,112)' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable06 = '1' OR CHARINDEX('Lottable06',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable06' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable07 = '1' OR CHARINDEX('Lottable07',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable07' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable08 = '1' OR CHARINDEX('Lottable08',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable08' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable09 = '1' OR CHARINDEX('Lottable09',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable09' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable10 = '1' OR CHARINDEX('Lottable10',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable10' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable11 = '1' OR CHARINDEX('Lottable11',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable11' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable12 = '1' OR CHARINDEX('Lottable12',@c_LotGroup,1) > 0 THEN 'LOTATTRIBUTE.Lottable12' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable13 = '1' OR CHARINDEX('Lottable13',@c_LotGroup,1) > 0 THEN 'CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable13,112)' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable14 = '1' OR CHARINDEX('Lottable14',@c_LotGroup,1) > 0 THEN 'CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable14,112)' ELSE '''''' END + ',' +
            CASE WHEN @c_NoMixLottable15 = '1' OR CHARINDEX('Lottable15',@c_LotGroup,1) > 0 THEN 'CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable15,112)' ELSE '''''' END + ',' +
            'SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen)
            FROM LOTxLOCxID LLI(NOLOCK)
            JOIN SKUXLOC (NOLOCK) ON LLI.Storerkey = SKUXLOC.Storerkey and LLI.Sku = SKUXLOC.Sku AND LLI.Loc = SKUXLOC.Loc
            JOIN LOC (NOLOCK) ON LLI.LOC = LOC.LOC
            JOIN LOTATTRIBUTE (NOLOCK) ON LLI.LOT = LOTATTRIBUTE.LOT
            JOIN LOT (NOLOCK) ON LLI.LOT = LOT.Lot
            LEFT JOIN #OVERLOT ON LLI.Lot = #OVERLOT.Lot
            LEFT OUTER JOIN ID (NOLOCK) ON LLI.ID  = ID.ID
            WHERE LLI.StorerKey = @c_CurrStorer
            AND LLI.SKU = @c_CurrSKU
            AND LOC.LocationFlag <> ''DAMAGE''
            AND LOC.LocationFlag <> ''HOLD''
            AND LOC.Status <> ''HOLD''
            AND LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen > 0
            AND LLI.QtyExpected = 0
            AND LLI.LOC <> @c_CurrLoc
            AND SKUXLOC.LocationType NOT IN(''PICK'',''CASE'')
            AND LOC.LocationType NOT IN(''PICK'')
            AND LOC.Facility = @c_Zone01
            AND LOT.Status     = ''OK''
            AND LOC.HostWHCode = @c_HostWHCode
            AND ISNULL(ID.Status ,'''') <> ''HOLD'' ' +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable01 = '1' THEN ' AND LOTATTRIBUTE.Lottable01 = @c_currLottable01 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable02 = '1' THEN ' AND LOTATTRIBUTE.Lottable02 = @c_currLottable02 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable03 = '1' THEN ' AND LOTATTRIBUTE.Lottable03 = @c_currLottable03 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable04 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable04,112) = CONVERT(NVARCHAR,@dt_currLottable04,112) ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable05 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable05,112) = CONVERT(NVARCHAR,@dt_currLottable05,112) ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable06 = '1' THEN ' AND LOTATTRIBUTE.Lottable06 = @c_currLottable06 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable07 = '1' THEN ' AND LOTATTRIBUTE.Lottable07 = @c_currLottable07 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable08 = '1' THEN ' AND LOTATTRIBUTE.Lottable08 = @c_currLottable08 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable09 = '1' THEN ' AND LOTATTRIBUTE.Lottable09 = @c_currLottable09 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable10 = '1' THEN ' AND LOTATTRIBUTE.Lottable10 = @c_currLottable10 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable11 = '1' THEN ' AND LOTATTRIBUTE.Lottable11 = @c_currLottable11 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable12 = '1' THEN ' AND LOTATTRIBUTE.Lottable12 = @c_currLottable12 ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable13 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable13,112) = CONVERT(NVARCHAR,@dt_currLottable13,112) ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable14 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable14,112) = CONVERT(NVARCHAR,@dt_currLottable14,112) ' ELSE '' END +
            CASE WHEN @n_BalQty + @n_OverAllocateQty > 0 AND @c_NoMixLottable15 = '1' THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable15,112) = CONVERT(NVARCHAR,@dt_currLottable15,112) ' ELSE '' END + ' ' +
            @c_LotFilter + CHAR(13) +
          ' GROUP BY LLI.Storerkey, LLI.Sku' +
            CASE WHEN @c_NoMixLottable01 = '1' OR CHARINDEX('Lottable01',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable01' ELSE '' END +
            CASE WHEN @c_NoMixLottable02 = '1' OR CHARINDEX('Lottable02',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable02' ELSE '' END +
            CASE WHEN @c_NoMixLottable03 = '1' OR CHARINDEX('Lottable03',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable03' ELSE '' END +
            CASE WHEN @c_NoMixLottable04 = '1' OR CHARINDEX('Lottable04',@c_LotGroup,1) > 0 THEN ',CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable04,112)' ELSE '' END +
            CASE WHEN @c_NoMixLottable05 = '1' OR CHARINDEX('Lottable05',@c_LotGroup,1) > 0 THEN ',CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable05,112)' ELSE '' END +
            CASE WHEN @c_NoMixLottable06 = '1' OR CHARINDEX('Lottable06',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable06' ELSE '' END +
            CASE WHEN @c_NoMixLottable07 = '1' OR CHARINDEX('Lottable07',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable07' ELSE '' END +
            CASE WHEN @c_NoMixLottable08 = '1' OR CHARINDEX('Lottable08',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable08' ELSE '' END +
            CASE WHEN @c_NoMixLottable09 = '1' OR CHARINDEX('Lottable09',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable09' ELSE '' END +
            CASE WHEN @c_NoMixLottable10 = '1' OR CHARINDEX('Lottable10',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable10' ELSE '' END +
            CASE WHEN @c_NoMixLottable11 = '1' OR CHARINDEX('Lottable11',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable11' ELSE '' END +
            CASE WHEN @c_NoMixLottable12 = '1' OR CHARINDEX('Lottable12',@c_LotGroup,1) > 0 THEN ',LOTATTRIBUTE.Lottable12' ELSE '' END +
            CASE WHEN @c_NoMixLottable13 = '1' OR CHARINDEX('Lottable13',@c_LotGroup,1) > 0 THEN ',CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable13,112)' ELSE '' END  +
            CASE WHEN @c_NoMixLottable14 = '1' OR CHARINDEX('Lottable14',@c_LotGroup,1) > 0 THEN ',CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable14,112)' ELSE '' END  +
            CASE WHEN @c_NoMixLottable15 = '1' OR CHARINDEX('Lottable15',@c_LotGroup,1) > 0 THEN ',CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable15,112)' ELSE '' END  + CHAR(13) +
            ' HAVING SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen) >= @n_QtyLocationMinimum ' + CHAR(13) +
            ' ORDER BY LLI.Storerkey, LLI.Sku, CASE WHEN MAX(ISNULL(#OVERLOT.Lot,'''')) <> '''' THEN 1 ELSE 2 END' + @c_LotSortLottable

            IF @b_debug = 1
               PRINT @c_SQL

            EXEC sp_executesql @c_SQL,
             N'@c_CurrStorer NVARCHAR(15), @c_CurrSku NVARCHAR(20), @c_CurrLoc NVARCHAR(10), @c_Zone01 NVARCHAR(10),
               @c_CurrLottable01 NVARCHAR(18), @c_CurrLottable02 NVARCHAR(18), @c_CurrLottable03 NVARCHAR(18), @dt_CurrLottable04 DATETIME, @dt_CurrLottable05 DATETIME,
               @c_CurrLottable06 NVARCHAR(30), @c_CurrLottable07 NVARCHAR(30), @c_CurrLottable08 NVARCHAR(30), @c_CurrLottable09 NVARCHAR(30), @c_CurrLottable10 NVARCHAR(30),
               @c_CurrLottable11 NVARCHAR(30), @c_CurrLottable12 NVARCHAR(30), @dt_CurrLottable13 DATETIME, @dt_CurrLottable14 DATETIME, @dt_CurrLottable15 DATETIME,
               @n_QtyLocationMinimum INT, @c_HostWHCode NVARCHAR(10)',
             @c_CurrStorer,
             @c_CurrSku,
             @c_CurrLoc,
             @c_Zone01,
             @c_CurrLottable01,
             @c_CurrLottable02,
             @c_CurrLottable03,
             @dt_CurrLottable04,
             @dt_CurrLottable05,
             @c_CurrLottable06,
             @c_CurrLottable07,
             @c_CurrLottable08,
             @c_CurrLottable09,
             @c_CurrLottable10,
             @c_CurrLottable11,
             @c_CurrLottable12,
             @dt_CurrLottable13,
             @dt_CurrLottable14,
             @dt_CurrLottable15,
             @n_QtyLocationMinimum,
             @c_HostWHCode

         DECLARE CUR_LOTTABLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TOP 1 Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09,
                   Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
            FROM #LOTTABLEGROUP
            ORDER BY RowId

         OPEN CUR_LOTTABLE

         FETCH NEXT FROM CUR_LOTTABLE INTO @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable04, @c_Lottable05, @c_Lottable06, @c_Lottable07,
                                           @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @c_Lottable13, @c_Lottable14, @c_Lottable15

         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
         BEGIN
              IF @b_debug = 1
                 PRINT '@c_lottable1-15=' + @c_Lottable01+','+@c_Lottable02+','+@c_Lottable03+','+@c_Lottable04+','+@c_Lottable05+','+@c_Lottable06+','+@c_Lottable07+','+
                     @c_Lottable08+','+@c_Lottable09+','+@c_Lottable10+','+@c_Lottable11+','+@c_Lottable12+','+@c_Lottable13+','+@c_Lottable14+','+ @c_Lottable15

            TRUNCATE TABLE #LOTXLOCXID
            TRUNCATE TABLE #LOCxLOTTABLE

            SET @c_SQL =
            N'INSERT INTO #LOTXLOCXID (Lot, Loc, ID, QtyAvailable)
            SELECT LLI.Lot, Loc.Loc, LLI.ID,
            (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen) AS QtyAvailable
            FROM LOTxLOCxID LLI(NOLOCK)
            JOIN SKUXLOC (NOLOCK) ON LLI.Storerkey = SKUXLOC.Storerkey and LLI.Sku = SKUXLOC.Sku AND LLI.Loc = SKUXLOC.Loc
            JOIN LOC (NOLOCK) ON LLI.LOC = LOC.LOC
            JOIN LOTATTRIBUTE (NOLOCK) ON LLI.LOT = LOTATTRIBUTE.LOT
            JOIN LOT (NOLOCK) ON LLI.LOT = LOT.Lot
            LEFT OUTER JOIN ID (NOLOCK) ON LLI.ID  = ID.ID
            WHERE LLI.StorerKey = @c_CurrStorer
            AND LLI.SKU = @c_CurrSKU
            AND LOC.LocationFlag <> ''DAMAGE''
            AND LOC.LocationFlag <> ''HOLD''
            AND LOC.Status <> ''HOLD''
            AND LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen > 0
            AND LLI.QtyExpected = 0
            AND LLI.LOC <> @c_CurrLoc
            AND SKUXLOC.LocationType NOT IN(''PICK'',''CASE'')
            AND LOC.Locationtype NOT IN(''PICK'')
            AND LOC.Facility = @c_Zone01
            AND LOT.Status     = ''OK''
            AND LOC.HostWHCode = @c_HostWHCode
            AND ISNULL(ID.Status ,'''') <> ''HOLD'' ' + @c_LotFilter + CHAR(13) +
            CASE WHEN @c_NoMixLottable01 = '1' OR CHARINDEX('Lottable01',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable02 = '1' OR CHARINDEX('Lottable02',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable03 = '1' OR CHARINDEX('Lottable03',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable04 = '1' OR CHARINDEX('Lottable04',@c_LotGroup,1) > 0 THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable04,112) = @c_Lottable04 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable05 = '1' OR CHARINDEX('Lottable05',@c_LotGroup,1) > 0 THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable05,112) = @c_lottable05 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable06 = '1' OR CHARINDEX('Lottable06',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable07 = '1' OR CHARINDEX('Lottable07',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable08 = '1' OR CHARINDEX('Lottable08',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable09 = '1' OR CHARINDEX('Lottable09',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable10 = '1' OR CHARINDEX('Lottable10',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable11 = '1' OR CHARINDEX('Lottable11',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable12 = '1' OR CHARINDEX('Lottable12',@c_LotGroup,1) > 0 THEN ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable13 = '1' OR CHARINDEX('Lottable13',@c_LotGroup,1) > 0 THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable13,112) = @c_Lottable13 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable14 = '1' OR CHARINDEX('Lottable14',@c_LotGroup,1) > 0 THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable14,112) = @c_Lottable14 ' ELSE '' END +
            CASE WHEN @c_NoMixLottable15 = '1' OR CHARINDEX('Lottable15',@c_LotGroup,1) > 0 THEN ' AND CONVERT(NVARCHAR,LOTATTRIBUTE.Lottable15,112) = @c_Lottable15 ' ELSE '' END

            EXEC sp_executesql @c_SQL,
             N'@c_CurrStorer NVARCHAR(15), @c_CurrSku NVARCHAR(20), @c_CurrLoc NVARCHAR(10), @c_Zone01 NVARCHAR(10),
               @c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @c_Lottable04 NVARCHAR(10), @c_Lottable05 NVARCHAR(10),
               @c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30),
               @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @c_Lottable13 NVARCHAR(10), @C_Lottable14 NVARCHAR(10), @c_Lottable15 NVARCHAR(10), @c_HostWHCode NVARCHAR(10)',
             @c_CurrStorer,
             @c_CurrSku,
             @c_CurrLoc,
             @c_Zone01,
             @c_Lottable01,
             @c_Lottable02,
             @c_Lottable03,
             @c_Lottable04,
             @c_Lottable05,
             @c_Lottable06,
             @c_Lottable07,
             @c_Lottable08,
             @c_Lottable09,
             @c_Lottable10,
             @c_Lottable11,
             @c_Lottable12,
             @c_Lottable13,
             @c_Lottable14,
             @c_Lottable15,
             @c_HostWHCode

            INSERT INTO #LOCxLOTTABLE (Loc, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07,
                                       Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, QtyAvailable, Seq)
            SELECT LLI.Loc, MIN(ISNULL(LA.Lottable01,'')), MIN(ISNULL(LA.Lottable02,'')), MIN(ISNULL(LA.Lottable03,'')), MIN(ISNULL(LA.Lottable04,'')), MIN(ISNULL(LA.Lottable05,'')), MIN(ISNULL(LA.Lottable06,'')), MIN(ISNULL(LA.Lottable07,'')),
                   MIN(ISNULL(LA.Lottable08,'')), MIN(ISNULL(LA.Lottable09,'')), MIN(ISNULL(LA.Lottable10,'')), MIN(ISNULL(LA.Lottable11,'')), MIN(ISNULL(LA.Lottable12,'')), MIN(ISNULL(LA.Lottable13,'')), MIN(ISNULL(LA.Lottable14,'')), MIN(ISNULL(LA.Lottable15,'')),
                   SUM(LLI.QtyAvailable), MIN(CASE WHEN #OVERLOT.Lot IS NOT NULL THEN 0 ELSE 1 END)
            FROM #LOTXLOCXID LLI
            JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
            LEFT JOIN #OVERLOT ON LLI.Lot = #OVERLOT.Lot
            GROUP BY LLI.Loc

            SET @c_SQL =
            N'DECLARE CUR_LLI CURSOR FAST_FORWARD READ_ONLY FOR
                 SELECT LLI.Lot, Loc.Loc, LLI.ID, LLI.QtyAvailable, LL.QtyAvailable AS LocQty
                 FROM #LOTXLOCXID LLI
                 JOIN #LOCXLOTTABLE LL ON LLI.Loc = LL.Loc
                 JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
                 LEFT JOIN #OVERLOT ON LLI.Lot = #OVERLOT.Lot ' +
                 CASE WHEN @n_OverAllocateQty = 0 THEN
                   ' WHERE LLI.QtyAvailable <= @n_ReplenQty '
                 ELSE ' ' END +
                 --WHERE LL.QtyAvailable <= @n_ReplenQty'
               ' ORDER BY LL.Seq, CASE WHEN #OVERLOT.Lot IS NOT NULL THEN 1 ELSE 2 END ' + @c_LotSort + ', LL.QtyAvailable, LOC.LogicalLocation, LOC.Loc, LLI.Lot '

           EXEC sp_executesql @c_SQL,
             N'@n_ReplenQty INT',
             @n_ReplenQty

            OPEN CUR_LLI

            FETCH NEXT FROM CUR_LLI INTO @c_FromLot, @c_FromLoc, @c_FromID, @n_FromQty, @n_LocQty

            SET @c_PrevLoc = ''
            SET @c_PrevID = ''
            WHILE @@FETCH_STATUS <> -1  AND @n_ReplenQty > 0  AND @n_continue IN(1,2)
            BEGIN
                IF @b_debug = 1
                   PRINT '@c_FromLot=' + @c_FromLot + ' @c_FromLoc=' + @c_FromLoc + ' @c_FromID=' + @c_FromID + ' @n_FromQty=' + CAST(@n_FromQty AS NVARCHAR)+ ' @n_ReplenQty=' + CAST(@n_ReplenQty AS NVARCHAR)

                --IF @c_PrevLoc <> @c_FromLoc AND @n_LocQty > @n_ReplenQty
                IF (@c_PrevLoc <> @c_FromLoc OR @c_PrevId <> @c_FromID) AND @n_FromQty > @n_ReplenQty AND @n_OverAllocateQty = 0
                BEGIN
                   SET @n_ReplenQty = 0
                   BREAK
                END

                IF @n_FromQty > @n_ReplenQty
                   SET @n_FromQty = @n_ReplenQty

                --IF @n_FromQty <= @n_ReplenQty
                --BEGIN
                   EXECUTE nspg_GetKey
                     'REPLENISHKEY',
                     10,
                     @c_ReplenishmentKey OUTPUT,
                     @b_success OUTPUT,
                     @n_err OUTPUT,
                     @c_errmsg OUTPUT

                  IF @b_success = 1
                  BEGIN
                     INSERT REPLENISHMENT (replenishmentgroup,
                        ReplenishmentKey,
                        StorerKey,
                        Sku,
                        FromLoc,
                        ToLoc,
                        Lot,
                        Id,
                        Qty,
                        UOM,
                        PackKey,
                        Confirmed,
                        RefNo,
                        QtyReplen)
                        VALUES (@c_ReplenishmentGroup,
                        @c_ReplenishmentKey,
                        @c_CurrStorer,
                        @c_CurrSKU,
                        @c_FromLoc,
                        @c_CurrLoc,
                        @c_FromLot,
                        @c_FromId,
                        @n_FromQty,
                        @c_UOM,
                        @c_PackKey,
                        'N',
                        'PC26',
                        @n_FromQty)
                  END
                  SET @n_ReplenQty = @n_ReplenQty - @n_FromQty
                  SET @c_PrevLoc = @c_FromLoc
                  SET @c_PrevID = @c_FromID
               --END
               --ELSE
               --   SET @n_ReplenQty = 0

               FETCH NEXT FROM CUR_LLI INTO @c_FromLot, @c_FromLoc, @c_FromID, @n_FromQty, @n_LocQty
           END
            CLOSE CUR_LLI
            DEALLOCATE CUR_LLI

            FETCH NEXT FROM CUR_LOTTABLE INTO @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable04, @c_Lottable05, @c_Lottable06, @c_Lottable07,
                                              @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @c_Lottable13, @c_Lottable14, @c_Lottable15
         END
         CLOSE CUR_LOTTABLE
         DEALLOCATE CUR_LOTTABLE


         FETCH NEXT FROM CUR_SKUXLOC INTO @c_CurrStorer, @c_CurrSKU, @c_CurrLoc, @c_Facility, @n_BalQty, @n_ReplenQty, @n_QtyLocationMinimum, @n_QtyLocationLimit, @C_Packkey, @c_UOM, @c_HostWHCode,
                                          @c_NoMixLottable01, @c_NoMixLottable02, @c_NoMixLottable03, @c_NoMixLottable04, @c_NoMixLottable05, @c_NoMixLottable06, @c_NoMixLottable07,
                                          @c_NoMixLottable08, @c_NoMixLottable09, @c_NoMixLottable10, @c_NoMixLottable11, @c_NoMixLottable12, @c_NoMixLottable13, @c_NoMixLottable14, @c_NoMixLottable15,
                                          @n_OverAllocateQty
      END
      CLOSE CUR_SKUXLOC
      DEALLOCATE CUR_SKUXLOC

   QUIT_SP:

      IF @c_FuncType IN ( 'G' )
      BEGIN
         RETURN
      END

      SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
      SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey
      ,LA.Lottable04, LA.Lottable02, LA.Lottable03
      From  REPLENISHMENT R (NOLOCK)
      JOIN  SKU (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
--      JOIN  LOC (NOLOCK) ON (LOC.Loc = R.FromLoc)
      JOIN  LOC (NOLOCK) ON (LOC.Loc = R.ToLoc)
      JOIN  PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON (R.Lot = LA.Lot)
      WHERE (LOC.PutawayZone in (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)
         OR @c_Zone02 = 'ALL')
      AND (LOC.Facility = @c_Zone01 OR ISNULL(@c_Zone01,'') = '')
      AND Confirmed = 'N'
      AND (R.StorerKey = @c_Storerkey OR @c_StorerKey IN('ALL',''))
      AND  (LOC.PickZone = @c_ReplGrp OR @c_ReplGrp = 'ALL')
      ORDER BY LOC.PutawayZone, R.Priority
END

GO