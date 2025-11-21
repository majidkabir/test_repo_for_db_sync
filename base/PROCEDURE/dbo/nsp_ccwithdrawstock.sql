SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Stored Procedure: nsp_CCWithdrawStock                                    */
/* Creation Date:                                                           */
/* Copyright: IDS                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose: Post Cycle Count (multiple count) in StockTake module           */
/*                                                                          */
/* Called By: PB object nep_n_cst_stocktake_parm_new                        */
/*                                                                          */
/* PVCS Version: 1.2                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author    Ver. Purposes                                     */
/* 06-Nov-2002  Leo Ng         Program rewrite for IDS version 5            */
/* 26-Dec-2002  Shong          Using Withdrawal Sourcekey and SourceType... */
/* 03-Feb-2009  NJOW           SOS126943 Filer by stocktakekey              */
/* 04-Nov-2011  YTWan     1.2  SOS#229737- Fix to update all pending status */
/*                             to '9' while no deposit stock. (Wan01)       */
/* 02-Jun-2014  TKLIM     1.1  Added Lottables 06-15                        */
/* 20-Sep-2016  TLTING    1.2  Change SetROWCOUNT 1 to Top 1                */
/* 08-Feb-2018  SWT01     1.3  Adding Paramater Variable to Calling SP      */
/****************************************************************************/

CREATE PROCEDURE [dbo].[nsp_CCWithdrawStock] (
	 @b_success int OUTPUT, 
	 @c_StockTakeKey NVARCHAR(10) = '')
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
            @d_Lottable15            DATETIME,
            @c_loc            NVARCHAR(10),
            @n_qty            int,
            @d_today          DATETIME,
            @c_packkey        NVARCHAR(10),
            @c_packuom3       NVARCHAR(10),
            @c_temploc        NVARCHAR(10),
            @c_tempsku        NVARCHAR(20),
            @c_Storerkey      NVARCHAR(15),
            @n_RowId          int,
            @n_continue       int,
            @c_LOT            NVARCHAR(10),
            @c_errmsg         NVARCHAR(255),
            @c_sourcekey      char (20),
            @c_sourcetype     char (30),
            @c_cckey          char (10),
            @c_status         NVARCHAR(10),
            @c_curstatus      NVARCHAR(10),
            @n_rcnt           int

    
   SELECT @d_today = GetDate(), @b_success = 1
   DELETE WITHDRAWSTOCK WHERE lot = '' OR qty = 0

   SELECT storerkey, sku, LOT, id, 
          Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
          Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
          Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
          loc, qty, RowID, sourcekey, sourcetype
   INTO #WithdrawStock
   FROM WithdrawStock with (NOLOCK)
   WHERE (sourcetype = "CC Withdrawal (" +  @c_stocktakekey + ")" OR @c_stocktakekey='')

   DECLARE inv_cur CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT storerkey, sku, LOT, id, 
          Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
          Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
          Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
          loc, qty, RowID, sourcekey, sourcetype
   FROM #WithdrawStock
   ORDER BY ID
   OPEN inv_cur

   FETCH NEXT FROM inv_cur INTO @c_Storerkey, @c_sku, @c_LOT, @c_id, 
         @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
         @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
         @c_loc, @n_qty, @n_RowID, @c_sourcekey, @c_sourcetype
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      --  select @c_Storerkey "storerkey", @c_sku "sku", @c_LOT "lot", @c_id "id", @c_loc "location", @n_qty "qty", @n_RowID
      --IF @c_id IS NULL SELECT @c_id = ''
      --IF @c_Lottable01 IS NULL SELECT @c_Lottable01 = ''
      --IF @c_Lottable02 IS NULL SELECT @c_Lottable02 = ''
      --IF @c_Lottable03 IS NULL SELECT @c_Lottable03 = ''


      SELECT @c_id = ISNULL(@c_id, '')
      SELECT @c_Lottable01 = ISNULL(@c_Lottable01, '')
      SELECT @c_Lottable02 = ISNULL(@c_Lottable02, '')
      SELECT @c_Lottable03 = ISNULL(@c_Lottable03, '')
      SELECT @c_Lottable06 = ISNULL(@c_Lottable06, '')
      SELECT @c_Lottable07 = ISNULL(@c_Lottable07, '')
      SELECT @c_Lottable08 = ISNULL(@c_Lottable08, '')
      SELECT @c_Lottable09 = ISNULL(@c_Lottable09, '')
      SELECT @c_Lottable10 = ISNULL(@c_Lottable10, '')
      SELECT @c_Lottable11 = ISNULL(@c_Lottable11, '')
      SELECT @c_Lottable12 = ISNULL(@c_Lottable12, '')

      SELECT @c_packkey = '', @c_packuom3 = ''
      SELECT @c_packkey = SKU.packkey,
             @c_packuom3 = packuom3
      FROM  SKU (NOLOCK), PACK (NOLOCK)
      WHERE SKU.Packkey = PACK.Packkey
      AND   SKU.STORERKEY = @C_STORERKEY
      and   SKU.SKU       = @c_SKU

      -- select  @c_packkey "SKU.packkey",  @c_packuom3 "packuom3"
      SELECT @c_tempsku = '', @c_temploc = ''
      SELECT @n_continue = 1

      IF @n_Continue = 1
      BEGIN
         SELECT TOP 1 @c_tempsku = SKU
         FROM  SKU (NOLOCK)
         WHERE SKU = @c_sku
         AND   SKU.STORERKEY = @C_STORERKEY

         IF @@ROWCOUNT = 0
         BEGIN
            SELECT @n_continue = 3
         END
      END

      IF @n_Continue = 1
      BEGIN

         SELECT TOP 1 @c_temploc = LOC
         FROM  LOC (NOLOCK)
         WHERE Loc = @c_loc

         IF @@ROWCOUNT = 0
         BEGIN
            SELECT @b_success = 0
            SELECT @n_continue = 3
         END

      END

      IF @n_Continue = 1
      BEGIN
         -- Added by June 06.Nov.01
         -- To Resolve incorrect status in ntrItrnAddwithdraw which results in stock not onhold after stocktake
         SELECT @c_status = 'OK'
         SELECT TOP 1 @c_curstatus=Status
         FROM ID (NOLOCK) WHERE ID = @c_ID
         SELECT @n_rcnt=@@ROWCOUNT
           IF @n_rcnt=1
         BEGIN
            SELECT @c_status = @c_curstatus
         END /* End - By June 06.Nov.01 */

      END

      IF @c_packkey <> '' AND @c_packuom3 <> '' AND @c_loc <> '' AND @c_sku <> ''
      BEGIN
         IF @n_Continue = 1
         BEGIN
            IF NOT EXISTS ( SELECT Qty FROM LOTxLOCxID (NOLOCK)
            WHERE LOT = @c_LOT
            AND   LOC = @c_LOC
            AND   ID  = @c_ID
            AND   Qty - (QtyPicked + QtyAllocated) < @n_Qty )
            BEGIN
               BEGIN TRAN
               SELECT @b_success = 1
             -- (SWT01)
            EXECUTE nspItrnAddWithdrawal
              @n_ItrnSysId    = NULL,
              @c_StorerKey    = @c_StorerKey,
              @c_Sku          = @c_Sku,
              @c_Lot          = @c_Lot,
              @c_ToLoc        = @c_loc,
              @c_ToID         = @c_id,
              @c_Status       = @c_status,
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
              @c_SourceKey    = @c_sourcekey,
              @c_SourceType   = @c_sourcetype,
              @c_PackKey      = @c_packkey,
              @c_UOM          = @c_packuom3,
              @b_UOMCalc      = 0,
              @d_EffectiveDate= @d_today,
              @c_itrnkey      = "",
              @b_Success      = @b_success OUTPUT,
              @n_err          = 0,
              @c_errmsg       = @c_errmsg OUTPUT
               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
                  ROLLBACK TRAN
                  SELECT @b_success = 0
                  BREAK
               END
               ELSE
               BEGIN
                  DELETE WithdrawStock WHERE RowID = @n_RowID
                  COMMIT TRAN
               END
            END -- if overallocated
            ELSE
            BEGIN
               SELECT @b_success = 0
            END
         END -- continue = 1
      END -- loc <> ''
      FETCH NEXT FROM inv_cur INTO @c_Storerkey, @c_sku, @c_LOT, @c_id, 
            @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
            @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
            @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
            @c_loc, @n_qty, @n_RowID, @c_sourcekey, @c_sourcetype
   END
   CLOSE inv_cur
   DEALLOCATE inv_cur

   /*--Wan01 (START)--*/
   IF @n_Continue = 1
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM TempStock WITH (NOLOCK)
                      WHERE SourceType = "CC Deposit (" + @c_StockTakeKey + ")" )
      BEGIN
         BEGIN TRAN
            UPDATE CCDETAIL
            SET   Status = '9'
            WHERE CCKey = @c_StockTakeKey
            AND Status < '9'

            IF @@Error <> 0
            BEGIN
               ROLLBACK TRAN
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
      END
   END
   /*-- Wan01 (END)--*/
END

GO