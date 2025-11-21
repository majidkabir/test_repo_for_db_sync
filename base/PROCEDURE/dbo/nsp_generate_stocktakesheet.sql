SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_Generate_StockTakeSheet                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 02-Jun-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROC [dbo].[nsp_Generate_StockTakeSheet] (
   @c_facility_start    NVARCHAR(5),
   @c_facility_end      NVARCHAR(5),
   @c_zone_start        NVARCHAR(10),
   @c_zone_end          NVARCHAR(10),
   @c_aisle_start       NVARCHAR(2),
   @c_aisle_end         NVARCHAR(2),
   @n_level_start       int,
   @n_level_end         int,
   @c_withqty           NVARCHAR(1)
)  
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- delete previous ccdetail with the same facility, aisle, level and zone
   DELETE CCDETAIL
   FROM CCDETAIL INNER JOIN LOC
   ON CCDETAIL.loc = LOC.loc
   WHERE LOC.facility BETWEEN @c_facility_start AND @c_facility_end
   AND   LOC.locaisle BETWEEN @c_aisle_start AND @c_aisle_end
   AND   LOC.loclevel BETWEEN @n_level_start AND @n_level_end
   AND   LOC.putawayzone BETWEEN @c_zone_start AND @c_zone_end

   -- select records from lotxlocxid with qty > 0
   SELECT LOTxLOCxID.lot,
         LOTxLOCxID.loc,
         LOTxLOCxID.id,
         storerkey = UPPER(LOTxLOCxID.storerkey),
         sku = UPPER(LOTxLOCxID.sku),
         LOTATTRIBUTE.Lottable01,
         LOTATTRIBUTE.Lottable02,
         LOTATTRIBUTE.Lottable03,
         LOTATTRIBUTE.Lottable04,
         LOTATTRIBUTE.Lottable05,
         LOTATTRIBUTE.Lottable06,
         LOTATTRIBUTE.Lottable07,
         LOTATTRIBUTE.Lottable08,
         LOTATTRIBUTE.Lottable09,
         LOTATTRIBUTE.Lottable10,
         LOTATTRIBUTE.Lottable11,
         LOTATTRIBUTE.Lottable12,
         LOTATTRIBUTE.Lottable13,
         LOTATTRIBUTE.Lottable14,
         LOTATTRIBUTE.Lottable15,
         LOTxLOCxID.qty,
         LOC.putawayzone,
         LOC.loclevel,
         aisle = LOC.locaisle,
         LOC.facility
   INTO #TEMP
   from lotxlocxid (nolock) join lotattribute (nolock)
   on lotxlocxid.lot = lotattribute.lot
   join loc (nolock)
   on lotxlocxid.loc = loc.loc
   where LOC.facility BETWEEN @c_facility_start AND @c_facility_end
   AND   LOC.locaisle BETWEEN @c_aisle_start AND @c_aisle_end
   AND   LOC.loclevel BETWEEN @n_level_start AND @n_level_end
   AND   LOC.putawayzone BETWEEN @c_zone_start AND @c_zone_end
   AND   LOTxLOCxID.qty > 0

   -- insert loc not existing in lotxlocxid
   INSERT #TEMP
   SELECT lot = space(10),
         loc.loc,
         id = space(20),
         storerkey = space(18),
         sku = space(20),
         Lottable01 = space(18),
         Lottable02 = space(18),
         Lottable03 = space(18),
         Lottable04 = NULL,
         Lottable05 = NULL,
         Lottable06 = space(30),
         Lottable07 = space(30),
         Lottable08 = space(30),
         Lottable09 = space(30),
         Lottable10 = space(30),
         Lottable11 = space(30),
         Lottable12 = space(30),
         Lottable13 = space(30),
         Lottable14 = NULL,
         Lottable15 = NULL,
         qty = 0,
         loc.putawayzone,
         loc.loclevel,
         aisle = loc.locaisle,
         loc.facility
   FROM LOC (nolock) left join #temp
   on loc.loc = #temp.loc
   WHERE LOC.facility BETWEEN @c_facility_start AND @c_facility_end
   AND   LOC.locaisle BETWEEN @c_aisle_start AND @c_aisle_end
   AND    LOC.loclevel BETWEEN @n_level_start AND @n_level_end
   AND   LOC.putawayzone BETWEEN @c_zone_start AND @c_zone_end
   AND #temp.loc is null

   -- insert into CCDETAIL
   DECLARE @c_lot             NVARCHAR(10),
            @c_loc            NVARCHAR(10),
            @c_id             NVARCHAR(18),
            @c_storerkey      NVARCHAR(18),
            @c_sku            NVARCHAR(20),
            @c_Lottable01     NVARCHAR(18),
            @c_Lottable02     NVARCHAR(18),
            @c_Lottable03     NVARCHAR(18),
            @d_Lottable04     DATETIME,
            @d_Lottable05     DATETIME,
            @c_Lottable06     NVARCHAR(30),
            @c_Lottable07     NVARCHAR(30),
            @c_Lottable08     NVARCHAR(30),
            @c_Lottable09     NVARCHAR(30),
            @c_Lottable10     NVARCHAR(30),
            @c_Lottable11     NVARCHAR(30),
            @c_Lottable12     NVARCHAR(30),
            @d_Lottable13     DATETIME,
            @d_Lottable14     DATETIME,
            @d_Lottable15     DATETIME,
            @n_qty            int,
            @c_facility       NVARCHAR(5),
            @c_aisle          NVARCHAR(2),
            @n_loclevel       int,
            @c_prev_facility  NVARCHAR(5),
            @c_prev_aisle     NVARCHAR(2),
            @n_prev_loclevel  int,
            @c_ccdetailkey    NVARCHAR(10),
            @c_ccsheetno      NVARCHAR(10),
            @b_success        int,
            @n_err            int,
            @c_errmsg         NVARCHAR(250)

            SELECT @c_prev_facility = "", @c_prev_aisle = "", @n_prev_loclevel = 0

   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT lot, loc, id, storerkey, sku, 
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
         qty, facility, aisle, loclevel
   FROM #TEMP ORDER BY aisle, loclevel,facility

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_storerkey, @c_sku, 
         @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
         @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
         @n_qty, @c_facility, @c_aisle, @n_loclevel
   WHILE (@@fetch_status <> -1)
   BEGIN
      IF @c_withqty = 'N' SELECT @n_qty = 0

      IF @c_facility <> @c_prev_facility OR @c_aisle <> @c_prev_aisle OR @n_loclevel <> @n_prev_loclevel
      BEGIN
         EXECUTE nspg_getkey
                  "CCSheetNo"
                  , 10
                  , @c_CCSheetNo OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
         SELECT @c_prev_facility = @c_facility, @c_prev_aisle = @c_aisle, @n_prev_loclevel = @n_loclevel
      END
      EXECUTE nspg_getkey
               "CCDetailKey"
               , 10
               , @c_CCDetailKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
      IF @c_lot <> ""
      BEGIN
         INSERT CCDETAIL (cckey, ccdetailkey, storerkey, sku, lot, loc, id, qty, ccsheetno, 
                  Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
                  )
         VALUES (@c_CCDetailKey, @c_CCDetailKey, @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty, @c_CCSheetNo,
                  @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                  @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                  )
      END
   ELSE
      BEGIN
         INSERT CCDETAIL (cckey, ccdetailkey, storerkey, sku, lot, loc, id, qty, ccsheetno, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
               )
         VALUES ('XXXXXXXXXX', @c_CCDetailKey, @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @n_qty, @c_CCSheetNo,
               @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
               @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
               @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
         )
      END
      FETCH NEXT FROM cur_1 INTO @c_lot, @c_loc, @c_id, @c_storerkey, @c_sku, 
               @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
               @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
               @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
               @n_qty, @c_facility, @c_aisle, @n_loclevel
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   DROP TABLE #TEMP
END

GO