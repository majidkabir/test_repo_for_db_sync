SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_WithdrawStock                                  */  
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
CREATE PROC [dbo].[isp_WithdrawStock_NuclearTest]  
   @c_StorerKey NVARCHAR(15)  
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
            @n_RowId          int,  
            @d_today          DATETIME,  
            @c_packkey        NVARCHAR(10),  
            @c_packuom3       NVARCHAR(10),  
            @c_temploc        NVARCHAR(10),  
            @c_tempsku        NVARCHAR(20),  
            @c_LOT            NVARCHAR(10)  
         ,  @c_SourceKey      NVARCHAR(20)   --(Wan01)  
         ,  @c_SourceType     NVARCHAR(30)   --(Wan01)  
  
   SELECT @d_today = GetDate()  
  
   DECLARE inv_cur CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT  RowId, Sku, Lot, Loc, Id, Qty  
         , Lottable01, Lottable02, Lottable03, Lottable04, Lottable05  
         , Lottable06, Lottable07, Lottable08, Lottable09, Lottable10  
         , Lottable11, Lottable12, Lottable13, Lottable14, Lottable15  
         , SourceKey, SourceType  
   FROM WithdrawStock WITH (NOLOCK)  
   WHERE StorerKey = @c_StorerKey  
   ORDER BY RowId  
  
   OPEN inv_cur  
   FETCH NEXT FROM inv_cur INTO @n_RowId, @c_sku, @c_lot, @c_loc, @c_id, @n_qty,  
         @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,  
         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,  
         @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,  
         @c_SourceKey, @c_SourceType  
  
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
      IF @c_id IS NULL SELECT @c_id = ''  
      IF @c_Lottable01 IS NULL SELECT @c_Lottable01 = ''  
      IF @c_Lottable02 IS NULL SELECT @c_Lottable02 = ''  
      IF @c_Lottable03 IS NULL SELECT @c_Lottable03 = ''  
      IF @c_LOT IS NULL SELECT @c_Lot = ''  
  
      SELECT @c_packkey = '', @c_packuom3 = ''  
  
      SELECT @c_packkey = SKU.packkey,  
            @c_packuom3 = PACK.packuom3  
      FROM  SKU with (NOLOCK), PACK with (NOLOCK)  
      WHERE SKU.Packkey = PACK.Packkey  
      AND SKU.StorerKey = @c_StorerKey   --SOS308539  
      AND SKU.SKU = @c_sku               --SOS308539  
  
      SELECT @c_lot '@c_lot', @c_loc '@c_loc', @c_sku '@c_sku', @n_qty '@n_qty'

      IF @c_packkey <> '' AND @c_packuom3 <> '' AND @c_loc <> '' AND @c_sku <> ''  
      BEGIN  
         --SELECT @c_lot "LOT", @c_sku "SKU", @c_id "ID", @c_loc "LOC", @n_qty  
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
  
           DELETE WithdrawStock WHERE RowId = @n_RowId  
           COMMIT TRAN  
         END  
      ELSE  
      BEGIN  
         SELECT 'FAILED - ', @c_sku '@c_sku', @c_lot '@c_lot', @c_loc '@c_loc', @c_id '@c_id', @n_qty '@n_qty'  
      END  
  
      FETCH NEXT FROM inv_cur INTO @n_RowId, @c_sku, @c_lot, @c_loc, @c_id, @n_qty,  
         @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,  
         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,  
         @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,  
         @c_SourceKey, @c_SourceType  
      END  
      CLOSE inv_cur  
      DEALLOCATE inv_cur  
   END  

GO