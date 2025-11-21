SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_AdjustStock                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Stock Take Posting by UCC#                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-Nov-11  Shong         Performance Issues                        */
/*                                                                      */
/* 2012-Mar-01  James         Get Pack & UOM (jamesxx)                  */
/* 2013-Mar-25  Leong         SOS# 273455 - Rename @c_cckey to          */
/*                            @c_StocktakeKey which is same as Exceed 6.*/
/* 2014-May-07  TKLIM         Added Lottables 06-15                     */
/* 07-Feb-2018  SWT02         Channel Management                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_AdjustStock]
   @c_StocktakeKey NVARCHAR(10),
   @b_success int OUTPUT
AS
BEGIN -- main
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @n_starttcnt int,
            @c_ccdetailkey NVARCHAR(10),
            @c_prev_storerkey NVARCHAR(18),
            @c_prev_facility NVARCHAR(5),
            @c_storerkey NVARCHAR(18),
            @c_facility NVARCHAR(5),
            @c_adjustmentkey NVARCHAR(10),
            @n_err int,
            @c_errmsg NVARCHAR(250),
            @n_continue int,
            @n_FinalizeStage int,
            @c_status NVARCHAR(10),
            @c_ucc NVARCHAR(20),
            @c_sku NVARCHAR(20),
            @n_systemqty int,
            @c_lot NVARCHAR(10),
            @c_loc NVARCHAR(10),
            @c_id NVARCHAR(18),
            @n_cntqty int,
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
            @d_today DATETIME,
            @c_sourcekey NVARCHAR(20),
            @c_oldsku NVARCHAR(20),
            @n_oldqty int,
            @c_oldlot NVARCHAR(10),
            @c_oldloc NVARCHAR(10),
            @c_oldid NVARCHAR(18),
            @c_oldstorer NVARCHAR(18), -- SOS29992
            @b_debug int

   DECLARE @c_PackKey      NVARCHAR(10),   -- (jamesxx)
           @c_PackUOM3     NVARCHAR(10)    -- (jamesxx)

   SELECT @n_starttcnt = @@TRANCOUNT

   -- hardcoded values:
   declare @c_type NVARCHAR(2),
            @c_reasoncode NVARCHAR(2),
            @c_remarks NVARCHAR(30)

   if left(@c_StocktakeKey,2) = 'ST' -- stock take
   begin
      set @c_type =  'AA'
      set @c_reasoncode = 'AA'
   end
   else -- normal cycle count
   begin
      set @c_type =  'PI'
      set @c_reasoncode = 'PI'
   end

   set @c_remarks = 'Stock Take Posting by UCC'

   select @c_ccdetailkey = ''
   select @c_prev_storerkey = ''
   select @c_prev_facility = ''

   while (1=1)
   begin -- while
      select @c_ccdetailkey = min(ccdetailkey)
      from  ccdetail (nolock)
      where cckey = @c_StocktakeKey
      and   ccdetailkey > @c_ccdetailkey
      and   status < '9'

      if isnull(@c_ccdetailkey, '0') = '0'
         break

      -- SOS29992
      BEGIN TRAN

      select @c_storerkey = storerkey,
             @c_facility = facility
      from  ccdetail c (nolock)
      join  loc l (nolock) on c.loc = l.loc
      where cckey = @c_StocktakeKey
      and   ccdetailkey = @c_ccdetailkey

      if @c_prev_storerkey <> @c_storerkey or
         @c_prev_facility <> @c_facility
      begin -- new adjustment header record
         EXECUTE nspg_getkey
            'Adjustment'
            , 10
            , @c_adjustmentkey OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

         IF NOT @b_success = 1
         BEGIN
            -- Start : SOS29992
            /*
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Obtain transmitlogkey. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            */
            ROLLBACK TRAN
            -- End : SOS29992
            break
         END
         else -- insert new adjustment header record
         begin
            insert adjustment (adjustmentkey, adjustmenttype, storerkey, facility, customerrefno, remarks)
               values (@c_adjustmentkey, @c_type, @c_storerkey, @c_facility, @c_StocktakeKey, @c_remarks)

            select @n_err = @@error
            if @n_err > 0
            BEGIN
               -- SOS29992
               /*
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Header. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               */
               ROLLBACK TRAN
               break
            END
         end
      end -- new adjustment header record

      -- insert adjustment details
      select @n_FinalizeStage = finalizestage
      from   stocktakesheetparameters (nolock)
      where  stocktakekey = @c_StocktakeKey

      -- reverse back to previous select
      select @c_status = status,
             @c_ucc = refno,
             @c_sku = sku,
             @n_systemqty = systemqty,
             @c_lot = lot,
             @c_loc = loc,
             @c_id  = id,
             @n_cntqty = CASE @n_FinalizeStage
                           WHEN 1 THEN qty
                           WHEN 2 THEN qty_cnt2

            WHEN 3 THEN qty_cnt3
                        end
      from  CCDETAIL (NOLOCK)
      where CCKEY = @c_StocktakeKey
      and   CCDETAILKEY = @c_ccdetailkey
      --End of
/*
      -- status = '0' : zero out inventory
      if @c_status = '0'
      begin -- @c_status = '0'
         if exists (select 1 from ucc (nolock) where uccno = @c_ucc)
         begin
            update ucc
            set status = '9'
            where uccno = @c_ucc

            select @n_err = @@error
            if @n_err > 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed on UCC Table. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               break
            END
         end

         if @n_systemqty > 0
         begin
            insert adjustmentdetail (adjustmentkey, adjustmentlinenumber, storerkey, sku, loc, lot, id, reasoncode, uom,
                     packkey, qty)
               select @c_adjustmentkey, right(@c_ccdetailkey, 5), @c_storerkey, @c_sku, @c_loc, @c_lot, @c_id, @c_reasoncode,
                  p.packuom3, s.packkey, @n_systemqty*-1
               from sku s (nolock) join pack p (nolock)
                  on s.packkey = p.packkey
               where s.storerkey = @c_storerkey
                  and s.sku = @c_sku

            select @n_err = @@error
            if @n_err > 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Header. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               break
            END
         end
      end -- @c_status = '0'
*/
      -- status = '2' : inventory is existing
      if @c_status = '2' or @c_status = '0'
      begin -- @c_status = '2'
         if @n_cntqty <> @n_systemqty
         begin -- @n_cntqty <> @n_systemqty
            if exists (select 1 from ucc (nolock) where uccno = @c_ucc)
               update ucc
               set   qty = @n_cntqty
               where uccno = @c_ucc
            else
               insert ucc (uccno, storerkey, sku, lot, loc, id, qty, status, externkey)
                  values (@c_ucc, @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @n_cntqty, '1', '')

            select @n_err = @@error
            if @n_err > 0
            BEGIN
               -- SOS29992
               /*
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert/Update Failed on UCC Table. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               */
               ROLLBACK TRAN
               break
            END

            insert adjustmentdetail
            (adjustmentkey, adjustmentlinenumber, storerkey, sku, loc, lot, id, reasoncode, uom, packkey, qty)
            select @c_adjustmentkey, right(@c_ccdetailkey, 5), @c_storerkey, @c_sku, @c_loc, @c_lot, @c_id, @c_reasoncode,
                   p.packuom3, s.packkey, @n_cntqty-@n_systemqty
            from sku s (nolock)
            join pack p (nolock) on s.packkey = p.packkey
            where s.storerkey = @c_storerkey
            and   s.sku = @c_sku

            select @n_err = @@error
            if @n_err > 0
            BEGIN
               -- SOS29992
               /*
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Detail. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               */
               ROLLBACK TRAN
               break
            END
         end -- @n_cntqty <> @n_systemqty
      end -- @c_status = '2'

      -- status = '1' : new inventory
      if @c_status = '1' or @c_status = '4'
      begin -- @c_status = '1'
         if exists (select 1 from lotxlocxid (nolock)
                     where storerkey = @c_storerkey
                        and sku = @c_sku
                        and lot = @c_lot
                        and loc = @c_loc
                        and id = @c_id)
         begin -- exists lotxlocxid

            insert adjustmentdetail
            (adjustmentkey, adjustmentlinenumber, storerkey, sku, loc, lot, id, reasoncode, uom, packkey, qty)
            select @c_adjustmentkey, right(@c_ccdetailkey, 5), @c_storerkey, @c_sku, @c_loc, @c_lot, @c_id, @c_reasoncode,
                   p.packuom3, s.packkey, @n_cntqty
            from  sku s (nolock)
            join  pack p (nolock) on    s.packkey = p.packkey
            where s.storerkey = @c_storerkey
            and   s.sku = @c_sku

            select @n_err = @@error
            if @n_err > 0
            BEGIN
               -- SOS29992
               /*
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Detail. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               */
               ROLLBACK TRAN
               break
            END
         end -- exists lotxlocxid
         else -- no inventory record
         begin -- create inventory record and adjust
            select @c_Lottable01 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable01, '')
                                    WHEN 2 THEN ISNULL(Lottable01_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable01_cnt3, '')
                                   END,
                  @c_Lottable02 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable02, '')
                                    WHEN 2 THEN ISNULL(Lottable02_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable02_cnt3, '')
                                   END,
                  @c_Lottable03 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable03, '')
                                    WHEN 2 THEN ISNULL(Lottable03_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable03_cnt3, '')
                                   END,
                  @d_Lottable04 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable04
                                    WHEN 2 THEN Lottable04_cnt2
                                    WHEN 3 THEN Lottable04_cnt3
                                   END,
                  @d_Lottable05 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable05
                                    WHEN 2 THEN Lottable05_cnt2
                                    WHEN 3 THEN Lottable05_cnt3
                                   END,
                  @c_Lottable06 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable06, '')
                                    WHEN 2 THEN ISNULL(Lottable06_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable06_cnt3, '')
                                   END,
                  @c_Lottable07 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable07, '')
                                    WHEN 2 THEN ISNULL(Lottable07_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable07_cnt3, '')
                                   END,
                  @c_Lottable08 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable08, '')
                                    WHEN 2 THEN ISNULL(Lottable08_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable08_cnt3, '')
                                   END,
                  @c_Lottable09 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable09, '')
                                    WHEN 2 THEN ISNULL(Lottable09_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable09_cnt3, '')
                                   END,
                  @c_Lottable10 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable10, '')
                                    WHEN 2 THEN ISNULL(Lottable10_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable10_cnt3, '')
                                   END,
                  @c_Lottable11 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable11, '')
                                    WHEN 2 THEN ISNULL(Lottable11_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable11_cnt3, '')
                                   END,
                  @c_Lottable12 = CASE @n_FinalizeStage
                                    WHEN 1 THEN ISNULL(Lottable12, '')
                                    WHEN 2 THEN ISNULL(Lottable12_cnt2, '')
                                    WHEN 3 THEN ISNULL(Lottable12_cnt3, '')
                                   END,
                  @d_Lottable13 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable13
                                    WHEN 2 THEN Lottable13_cnt2
                                    WHEN 3 THEN Lottable13_cnt3
                                   END,
                  @d_Lottable14 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable14
                                    WHEN 2 THEN Lottable14_cnt2
                                    WHEN 3 THEN Lottable14_cnt3
                                   END,
                  @d_Lottable15 = CASE @n_FinalizeStage
                                    WHEN 1 THEN Lottable15
                                    WHEN 2 THEN Lottable15_cnt2
                                    WHEN 3 THEN Lottable15_cnt3
                                   END,
                  @d_today = getdate()
            from  ccdetail (nolock)
            where cckey = @c_StocktakeKey
            and   ccdetailkey = @c_ccdetailkey

            -- (jamesxx)
            SELECT @c_PackKey = PackKey
            FROM dbo.SKU WITH (NOLOCK)
            WHERE SKU = @c_sku
            AND StorerKey = @c_storerkey

            SELECT @c_PackUOM3 = PackUOM3
            FROM dbo.Pack WITH (NOLOCK)
            WHERE PackKey = @c_PackKey

            -- insert a dummy deposit to create inventory record
            select @c_sourcekey = @c_StocktakeKey + @c_ccdetailkey
            EXECUTE nspItrnAddDeposit
                 @n_ItrnSysId    = NULL,
                 @c_StorerKey    = @c_StorerKey,
                 @c_Sku          = @c_SKU,
                 @c_Lot          = '',
                 @c_ToLoc        = @c_LOC,
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
                 @c_Channel      =  '',
                 @n_Channel_ID   =  0,
                 @n_casecnt      =  0, -- dummy qty
                 @n_innerpack    =  0,
                 @n_qty          =  0,
                 @n_pallet       =  0,
                 @f_cube         =  0,
                 @f_grosswgt     =  0,
                 @f_netwgt       =  0,
                 @f_otherunit1   =  0,
                 @f_otherunit2   =  0,
                 @c_SourceKey    =  @c_sourcekey,
                 @c_SourceType   =  'DUMMY',
                 @c_PackKey      =  @c_PackKey,
                 @c_UOM          =  @c_PackUOM3,
                 @b_UOMCalc      =  0,
                 @d_EffectiveDate=  @d_today,
                 @c_itrnkey      =  "",
                 @b_Success      =  @b_Success OUTPUT,
                 @n_err          =  0,
                 @c_errmsg       =  ''
                                    
            select @n_err = @@error 
            if @b_success <> 1
            begin
               if @n_err > 0
               BEGIN
-- SOS29992
                  /*
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Dummy Deposit Failed. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  */
                  ROLLBACK TRAN
                  break
               END
            end

            -- retrieve newly created lot
            select @c_lot = space(10)
            select @c_lot = lot
            from  itrn (nolock)
            where storerkey = @c_storerkey
            and   sku = @c_sku
            and   sourcekey = @c_sourcekey


            insert adjustmentdetail
            (adjustmentkey, adjustmentlinenumber, storerkey, sku, loc, lot, id, reasoncode, uom, packkey, qty)
            select @c_adjustmentkey, right(@c_ccdetailkey, 5), @c_storerkey, @c_sku, @c_loc, @c_lot, @c_id, @c_reasoncode,
                  p.packuom3,       s.packkey,                @n_cntqty
            from sku s (nolock)
            join pack p (nolock) on s.packkey = p.packkey
            where s.storerkey = @c_storerkey
            and s.sku = @c_sku

            select @n_err = @@error
            if @n_err > 0
            BEGIN
               -- SOS29992
               /*
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Detail. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               */
               ROLLBACK TRAN
               break
            END
         end -- create inventory record and adjust

         if exists (select 1 from ucc (nolock) where uccno = @c_ucc)
                    and @c_ucc > ''
         begin
            -- duplicate ucc: negative adjust old ucc
            select @c_oldloc = loc,
                  @c_oldlot = lot,
                  @c_oldid = id,
                  @c_oldsku = sku,
                  @n_oldqty = qty,
                  @c_oldstorer = storerkey -- SOS29992
            from  ucc (nolock)
            where uccno = @c_ucc


            -- Start : SOS29992
            if exists (select 1 from lotxlocxid (nolock) where storerkey = @c_oldstorer and sku = @c_oldsku
                                                         and  lot = @c_oldlot and loc = @c_oldloc and id = @c_oldid
                                                         and  qty > 0)
            begin
            -- End : SOS29992
               insert adjustmentdetail (adjustmentkey, adjustmentlinenumber, storerkey, sku, loc, lot, id, reasoncode, uom,
               packkey, qty)
               select @c_adjustmentkey, 'D'+right(@c_ccdetailkey, 4), @c_storerkey, @c_oldsku, @c_oldloc, @c_oldlot,
               @c_oldid, @c_reasoncode, p.packuom3, s.packkey, @n_oldqty * -1
               from sku s (nolock) join pack p (nolock)
               on s.packkey = p.packkey
               where s.storerkey = @c_storerkey
               and s.sku = @c_oldsku

               select @n_err = @@error
               if @n_err > 0
               BEGIN
                  -- SOS29992
                  /*
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Create Adjustment Detail. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  */
                  ROLLBACK TRAN
                  break
               END
            end -- SOS29992

            delete ucc where uccno = @c_ucc
            select @n_err = @@error
            if @n_err > 0
            BEGIN
               -- SOS29992
               /*
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed to Delete Duplicate UCC. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               */
               ROLLBACK TRAN
               break
            END
         end
         if @c_ucc > ''
            insert ucc (uccno, storerkey, sku, lot, loc, id, qty, status, externkey)
               values (@c_ucc, @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @n_cntqty, '1', '')

         select @n_err = @@error
         if @n_err > 0
         BEGIN
            -- SOS29992
            /*
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert/Update Failed on UCC Table. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            */
            ROLLBACK TRAN
            break
         END
      end -- @c_status = '1'

      -- Start : SOS29992
      -- Requested by Kim to set refno to blank if there's pending records
      -- Added by SHONG on 2005-Nov-10
      if @c_ucc > ''
      begin
         if exists (select 1
                    from  packheader ph (nolock), packdetail pd (nolock)
                    where ph.pickslipno = pd.pickslipno
                    and   pd.refno = @c_ucc
                    and   ph.status < '9')
         begin
            update packdetail
            set    refno = ''
            from   packheader ph (nolock)
            where  ph.pickslipno = packdetail.pickslipno
            and    refno = @c_ucc
            and    ph.status < '9'
            select @n_err = @@error
            if @n_err > 0
            BEGIN
               ROLLBACK TRAN
               break
            END
         end
      end -- if @c_ucc > ''

      if exists (select 1
                 from  replenishment (nolock)
                 where refno = @c_ucc
                 and   confirmed <> 'Y')
      begin
         update replenishment
         set    refno = ''
         where  refno = @c_ucc
         and    confirmed <> 'Y'
         select @n_err = @@error
         if @n_err > 0
         BEGIN
            ROLLBACK TRAN
            break
         END
      end
      -- End : SOS29992

      -- finalize/close ccdetail record
      update ccdetail
      set status = '9'
      where cckey = @c_StocktakeKey
      and ccdetailkey = @c_ccdetailkey

      select @n_err = @@error
      if @n_err > 0
      BEGIN
         -- SOS29992
         /*
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed on CCDETAIL Table. (isp_AdjustStock)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         */
         ROLLBACK TRAN
         break
      END
      ELSE
      BEGIN
         -- SOS29992
         COMMIT TRAN
      END

      select @c_prev_storerkey = @c_storerkey
      select @c_prev_facility = @c_facility
   end -- while

   /*
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_AdjustStock'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   */
END -- main

GO