SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_WithdrawStock                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 04-DEC-2013  YTWan   1.1   SOS296757: #Auto Withdrawal of Virtual    */
/*                            Inventories.(Wan01)                       */ 
/* 11-APR-2014  SPChin  1.2   SOS308539 - Bug Fixed                     */
/* 02-Jun-2014  TKLIM   1.3   Added Lottables 06-15                     */
/* 30-Jun-2016  TLTING  1.5   Perfromance Tune                          */
/* 08-Feb-2018  SWT01   1.6   Adding Paramater Variable to Calling SP   */
/************************************************************************/
CREATE PROC [dbo].[nsp_WithdrawStock]
      @c_StorerKey         NVARCHAR(10)
   ,  @c_LocationCategory  NVARCHAR(10) = '' --(Wan01)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE  @c_sku            NVARCHAR(20),
            @c_id             NVARCHAR(18),
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
            @c_loc            NVARCHAR(10),
            @n_qty            int,
            @d_today          DATETIME,
            @c_packkey        NVARCHAR(10),
            @c_packuom3       NVARCHAR(10),
            @c_temploc        NVARCHAR(10),
            @c_tempsku        NVARCHAR(20),
            @c_LOT            NVARCHAR(10)
         ,  @c_SourceKey      NVARCHAR(20)   --(Wan01) 
         ,  @c_SourceType     NVARCHAR(30)   --(Wan01)

   SELECT @d_today = GetDate()

   SET @c_SourceKey  = 'INTIALDP'         --(Wan01)
   SET @c_SourceType = 'INTIALDP'         --(Wan01)

   --(Wan01)  - START
   IF @c_LocationCategory <> ''
   BEGIN
      SET @c_SourceKey = @c_LocationCategory
      SET @c_SourceType= 'nsp_WithdrawStock'
   END

   /*
   SELECT LOTXLOCXID.sku, LOTXLOCXID.id, LOTAttribute.Lottable01, LOTAttribute.Lottable02, LOTAttribute.Lottable03, LOTAttribute.Lottable04, LOTAttribute.Lottable05,
   LOTXLOCXID.loc, LOTXLOCXID.qty, LOTAttribute.lot
   INTO #tempstock
   FROM LOTxLOCxID, LOTAttribute, SKU
   WHERE LOTXLOCXID.LOT = LotAttribute.LOT
   AND Qty > 0
   AND LOTxLOCxID.SKU = SKU.SKU
   AND SKU.Storerkey = @c_StorerKey
   AND LOTxLOCxID.Storerkey = @c_StorerKey
   AND LOTXLOCXID.Storerkey = LotAttribute.Storerkey
   */
   SELECT LOTXLOCXID.Sku
         ,ID  = ISNULL(RTRIM(LOTXLOCXID.Id),'')
         ,Lottable01 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'')
         ,Lottable02 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
         ,Lottable03 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable03),'')
         ,LOTATTRIBUTE.Lottable04
         ,LOTATTRIBUTE.Lottable05
         ,Lottable06 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable06),'')
         ,Lottable07 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable07),'')
         ,Lottable08 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable08),'')
         ,Lottable09 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable09),'')
         ,Lottable10 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable10),'')
         ,Lottable11 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable11),'')
         ,Lottable12 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable12),'')
         ,LOTATTRIBUTE.Lottable13
         ,LOTATTRIBUTE.Lottable14
         ,LOTATTRIBUTE.Lottable15
         ,Loc = ISNULL(RTRIM(LOTXLOCXID.Loc),'')
         ,LOTXLOCXID.qty
         ,Lot = ISNULL(RTRIM(LOTXLOCXID.Lot),'')
   INTO #tempstock
   FROM SKU          WITH (NOLOCK)  
   JOIN LOTATTRIBUTE WITH (NOLOCK) ON (SKU.Storerkey = LOTATTRIBUTE.Storerkey)
           AND(SKU.Sku = LOTATTRIBUTE.Sku) 
   JOIN LOTxLOCxID   WITH (NOLOCK) ON (LOTATTRIBUTE.LOT = LOTxLOCxID.LOT)
   JOIN LOC          WITH (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC)
   WHERE SKU.Storerkey = @c_StorerKey
   AND LOTxLOCxID.Qty > 0
   AND LOC.LocationCategory = CASE WHEN @c_LocationCategory = '' THEN LOC.LocationCategory ELSE @c_LocationCategory END
   --(Wan01) -- END

   DECLARE inv_cur CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT sku, id, loc, qty, lot,
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15

   FROM #tempstock
   ORDER BY ID
   --  WHERE id IS NULL
   OPEN inv_cur
   FETCH NEXT FROM inv_cur INTO @c_sku, @c_id, @c_loc, @n_qty, @c_lot,
         @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
         @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF @c_id IS NULL SELECT @c_id = ''
      IF @c_Lottable01 IS NULL SELECT @c_Lottable01 = ''
      IF @c_Lottable02 IS NULL SELECT @c_Lottable02 = ''
      IF @c_Lottable03 IS NULL SELECT @c_Lottable03 = ''
      IF @c_LOT IS NULL SELECT @c_Lot = ''

      SELECT @c_packkey = '', @c_packuom3 = ''

      SELECT @c_packkey = SKU.packkey,
            @c_packuom3 = packuom3
      FROM  SKU with (NOLOCK), PACK with (NOLOCK)
      WHERE SKU.Packkey = PACK.Packkey
      AND SKU.StorerKey = @c_StorerKey   --SOS308539
      AND SKU.SKU = @c_sku               --SOS308539
      SELECT @c_tempsku = '', @c_temploc = ''

      SELECT @c_tempsku = SKU
      FROM SKU (NOLOCK)
      WHERE SKU = @c_sku
      AND   StorerKey = @c_StorerKey

      SELECT @c_temploc = LOC
      FROM LOC (NOLOCK)
      WHERE Loc = @c_loc

      IF @c_packkey <> '' AND @c_packuom3 <> '' AND @c_loc <> '' AND @c_sku <> ''
      BEGIN
         SELECT @c_lot "LOT", @c_sku "SKU", @c_id "ID", @c_loc "LOC", @n_qty
         BEGIN TRAN
         -- (SWT01)
         EXECUTE nspItrnAddWithdrawal
           @n_ItrnSysId    = NULL,
           @c_StorerKey    = @c_StorerKey,
           @c_Sku          = @c_Sku,
           @c_Lot          = @c_Lot,
           @c_ToLoc        = @c_loc,
           @c_ToID         = @c_id,
           @c_Status       = 'OK',
           @c_lottable01   = @c_Lottable01,
           @c_lottable02   = @c_Lottable02,
           @c_lottable03   = @c_Lottable03,
           @d_lottable04   = @d_Lottable04,
           @d_lottable05   = @d_Lottable05,
           @c_lottable06   = @c_Lottable06,
           @c_lottable07   = @c_Lottable07,
           @c_lottable08   = @c_Lottable08,
           @c_lottable09   = @c_Lottable09,
           @c_lottable10   = @c_Lottable10,
           @c_lottable11   = @c_Lottable11,
           @c_lottable12   = @c_Lottable12,
           @d_lottable13   = @d_Lottable13,
           @d_lottable14   = @d_Lottable14,
           @d_lottable15   = @d_Lottable15,
           @n_casecnt      = 0,
           @n_innerpack    = 0,
           @n_qty          = @n_qty,
           @n_pallet       = 0,
           @f_cube         = 0,
           @f_grosswgt     = 0,
           @f_netwgt       = 0,
           @f_otherunit1   = 0,
           @f_otherunit2   = 0,
           @c_SourceKey    = @c_Sourcekey,     -- (Wan01)
           @c_SourceType   = @c_SourceType,    -- (Wan01)
           @c_PackKey      = @c_packkey,
           @c_UOM          = @c_packuom3,
           @b_UOMCalc      = 0,
           @d_EffectiveDate= @d_today,
           @c_itrnkey      = "",
           @b_Success      = 0,
           @n_err          = 0,
           @c_errmsg       = ''
           
            COMMIT TRAN
         END
      ELSE
         SELECT 'FAILED - ', @c_sku, @c_id, @c_loc, @n_qty

      FETCH NEXT FROM inv_cur INTO @c_sku, @c_id, @c_loc, @n_qty, @c_lot,
            @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
            @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
            @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      END
      CLOSE inv_cur
      DEALLOCATE inv_cur
   END

GO