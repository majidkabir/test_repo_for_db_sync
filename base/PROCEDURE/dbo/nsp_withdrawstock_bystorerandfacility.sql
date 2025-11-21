SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_WithdrawStock_ByStorerAndFacility              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 30-May-2014  TKLIM   1.1   Added Lottables 06-15                     */
/* 30-Jun-2016  TLTING  1.2   Perfromance Tune                          */
/* 08-Feb-2018  SWT01   1.3   Adding Paramater Variable to Calling SP   */
/************************************************************************/
CREATE PROC [dbo].[nsp_WithdrawStock_ByStorerAndFacility]
    @c_StorerKey NVARCHAR(15), 
    @c_Facility NVARCHAR( 5)
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

    SELECT @d_today = GetDate()

    SELECT LOTXLOCXID.sku, LOTXLOCXID.id, 
         LOTAttribute.Lottable01, LOTAttribute.Lottable02, LOTAttribute.Lottable03, LOTAttribute.Lottable04, LOTAttribute.Lottable05,
         LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
         LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,
         LOTXLOCXID.loc, LOTXLOCXID.qty, LOTAttribute.lot
    INTO #tempstock
    FROM LOTxLOCxID with (NOLOCK)
       INNER JOIN LOTAttribute with (NOLOCK)ON (LOTXLOCXID.LOT = LotAttribute.LOT)
       INNER JOIN LOC with (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
       INNER JOIN SKU with (NOLOCK) ON (LOTxLOCxID.SKU = SKU.SKU)
    WHERE Qty > 0
       AND SKU.Storerkey = @c_StorerKey
       AND LOTxLOCxID.Storerkey = @c_StorerKey 
       AND LOC.Facility = @c_Facility

    DECLARE inv_cur CURSOR FAST_FORWARD READ_ONLY FOR
    SELECT sku, id, 
         Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
         Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
         Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
         loc, qty, lot
    FROM #tempstock
    ORDER BY ID
  --  WHERE id IS NULL
    OPEN inv_cur
    FETCH NEXT FROM inv_cur INTO @c_sku, @c_id, 
         @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
         @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
         @c_loc, @n_qty, @c_lot
    WHILE (@@FETCH_STATUS <> -1)
    BEGIN
       --IF @c_id IS NULL SELECT @c_id = ''
       --IF @c_Lottable01 IS NULL SELECT @c_Lottable01 = ''
       --IF @c_Lottable02 IS NULL SELECT @c_Lottable02 = ''
       --IF @c_Lottable03 IS NULL SELECT @c_Lottable03 = ''

       SELECT @c_id = ISNULL(@c_id,'')
       SELECT @c_Lottable01 = ISNULL(@c_Lottable01,'')
       SELECT @c_Lottable02 = ISNULL(@c_Lottable02,'')
       SELECT @c_Lottable03 = ISNULL(@c_Lottable03,'')
       SELECT @c_Lottable06 = ISNULL(@c_Lottable06,'')
       SELECT @c_Lottable07 = ISNULL(@c_Lottable07,'')
       SELECT @c_Lottable08 = ISNULL(@c_Lottable08,'')
       SELECT @c_Lottable09 = ISNULL(@c_Lottable09,'')
       SELECT @c_Lottable10 = ISNULL(@c_Lottable10,'')
       SELECT @c_Lottable11 = ISNULL(@c_Lottable11,'')
       SELECT @c_Lottable12 = ISNULL(@c_Lottable12,'')

       IF @c_LOT IS NULL SELECT @c_Lot = ''
       SELECT  @c_packkey = '', @c_packuom3 = ''

       SELECT  @c_packkey = SKU.packkey,
               @c_packuom3 = packuom3
       FROM  SKU with (NOLOCK), PACK with (NOLOCK)
       WHERE SKU.Packkey = PACK.Packkey 
       AND SKU.StorerKey = @c_StorerKey   --SOS308539
       AND SKU.SKU = @c_sku               --SOS308539       

       SELECT  @c_tempsku = '', 
               @c_temploc = ''

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
         -- SWT01
         EXECUTE nspItrnAddWithdrawal
             @n_ItrnSysId    =NULL,
             @c_StorerKey    =@c_StorerKey,
             @c_Sku          =@c_Sku,
             @c_Lot          =@c_Lot,
             @c_ToLoc        =@c_loc,
             @c_ToID         =@c_id,
             @c_Status       ='OK',
             @c_lottable01   =@c_Lottable01,
             @c_lottable02   =@c_Lottable02,
             @c_lottable03   =@c_Lottable03,
             @d_lottable04   =@d_Lottable04,   
             @d_lottable05   =@d_Lottable05,
             @c_lottable06   =@c_Lottable06,
             @c_lottable07   =@c_Lottable07,
             @c_lottable08   =@c_Lottable08,
             @c_lottable09   =@c_Lottable09,
             @c_lottable10   =@c_Lottable10,
             @c_lottable11   =@c_Lottable11,
             @c_lottable12   =@c_Lottable12,
             @d_lottable13   =@d_Lottable13,
             @d_lottable14   =@d_Lottable14,
             @d_lottable15   =@d_Lottable15,
             @n_casecnt      =0,
             @n_innerpack    =0,
             @n_qty          =@n_qty,
             @n_pallet       =0,
             @f_cube         =0,
             @f_grosswgt     =0,
             @f_netwgt       =0,
             @f_otherunit1   =0,
             @f_otherunit2   =0,
             @c_SourceKey    ='INTIALDP',
             @c_SourceType   ='INTIALDP',
             @c_PackKey      =@c_packkey,
             @c_UOM          =@c_packuom3,
             @b_UOMCalc      =0,   
             @d_EffectiveDate=@d_today,
             @c_itrnkey      ="",  
             @b_Success      =0,
             @n_err          =0,
             @c_errmsg       =''
         COMMIT TRAN
      END
      ELSE
         SELECT 'FAILED - ', @c_sku, @c_id, @c_loc, @n_qty
       
      FETCH NEXT FROM inv_cur INTO @c_sku, @c_id, 
            @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
            @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
            @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
            @c_loc, @n_qty, @c_lot
    END
    CLOSE inv_cur   
    DEALLOCATE inv_cur
 END



GO