SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_WithdrawVirtualStock                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  SOS296757: #Auto Withdrawal of Virtual Inventories         */
/*        :  Copy and modify from nsp_WithdrawStock                     */
/* Called By: Job Scheduler                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Purposes                                       */
/* 21-May-2014  TKLIM    Added Lottables 06-15                          */
/* 08-Feb-2018  SWT01    Adding Paramater Variable to Calling SP        */
/************************************************************************/
CREATE PROC [dbo].[isp_WithdrawVirtualStock]
            @c_StorerKey         NVARCHAR(10)
         ,  @c_LocationCategory  NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @c_Sku         NVARCHAR(20) 
         , @c_Lot         NVARCHAR(10)
         , @c_Loc         NVARCHAR(10)  
         , @c_ID          NVARCHAR(18)
         , @n_qty         INT   
         , @c_Lottable01  NVARCHAR(18)  
         , @c_Lottable02  NVARCHAR(18)  
         , @c_Lottable03  NVARCHAR(18)  
         , @d_Lottable04  DATETIME 
         , @d_Lottable05  DATETIME 
         , @c_Lottable06  NVARCHAR(30)
         , @c_Lottable07  NVARCHAR(30)
         , @c_Lottable08  NVARCHAR(30)
         , @c_Lottable09  NVARCHAR(30)
         , @c_Lottable10  NVARCHAR(30)
         , @c_Lottable11  NVARCHAR(30)
         , @c_Lottable12  NVARCHAR(30)
         , @d_Lottable13  DATETIME
         , @d_Lottable14  DATETIME
         , @d_Lottable15  DATETIME

         , @d_today       DATETIME 
         , @c_packkey     NVARCHAR(10) 
         , @c_packuom3    NVARCHAR(10)

         , @c_SourceKey   NVARCHAR(20) 
         , @c_SourceType  NVARCHAR(30) 

   SET @c_Sku        = ''
   SET @c_Lot        = '' 
   SET @c_Loc        = '' 
   SET @c_ID         = '' 
   SET @n_qty        = '' 
   
   SET @c_Lottable01 = ''
   SET @c_Lottable02 = ''
   SET @c_Lottable03 = ''
   SET @c_Lottable06 = ''
   SET @c_Lottable07 = ''
   SET @c_Lottable08 = ''
   SET @c_Lottable09 = ''
   SET @c_Lottable10 = ''
   SET @c_Lottable11 = ''
   SET @c_Lottable12 = ''
   
   SET @c_packkey    = ''
   SET @c_packuom3   = ''

   SET @c_SourceKey  = 'INTIALDP'
   SET @c_SourceType = 'INTIALDP'

   SET @d_today = GetDate()
   
   IF @c_LocationCategory <> ''
   BEGIN
      SET @c_SourceKey = @c_LocationCategory
      SET @c_SourceType= 'isp_WithdrawVirtualStock'
   END

   SELECT LOTXLOCXID.Sku
         ,Lot = ISNULL(RTRIM(LOTXLOCXID.Lot),'')
         ,Loc = ISNULL(RTRIM(LOTXLOCXID.Loc),'')
         ,ID  = ISNULL(RTRIM(LOTXLOCXID.Id),'')
         ,LOTXLOCXID.qty
         ,Lottable01 = ISNULL(RTRIM(LOTATTRIBUTE.lottable01),'')
         ,Lottable02 = ISNULL(RTRIM(LOTATTRIBUTE.lottable02),'')
         ,Lottable03 = ISNULL(RTRIM(LOTATTRIBUTE.lottable03),'')
         ,LOTATTRIBUTE.lottable04
         ,LOTATTRIBUTE.lottable05
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
   INTO #tempstock
   FROM LOTATTRIBUTE WITH (NOLOCK) 
   JOIN LOTxLOCxID   WITH (NOLOCK) ON (LOTATTRIBUTE.LOT = LOTxLOCxID.LOT)
   JOIN LOC          WITH (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC)
   WHERE LOTATTRIBUTE.Storerkey = @c_StorerKey
   AND LOTxLOCxID.Qty > 0
   AND LOC.LocationCategory = CASE WHEN @c_LocationCategory = '' THEN LOC.LocationCategory ELSE @c_LocationCategory END

   DECLARE Cur_Inv CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT Sku
         ,Lot
         ,Loc
         ,ID
         ,Lottable01
         ,Lottable02
         ,Lottable03
         ,Lottable04
         ,Lottable05
         ,Lottable06
         ,Lottable07
         ,Lottable08
         ,Lottable09
         ,Lottable10
         ,Lottable11
         ,Lottable12
         ,Lottable13
         ,Lottable14
         ,Lottable15
         ,Qty
   FROM #tempstock
   ORDER BY ID

   OPEN Cur_Inv
   
   FETCH NEXT FROM Cur_Inv INTO @c_Sku
                              , @c_Lot
                              , @c_Loc
                              , @c_ID
                              , @c_Lottable01
                              , @c_Lottable02
                              , @c_Lottable03
                              , @d_Lottable04
                              , @d_Lottable05
                              , @c_Lottable06
                              , @c_Lottable07
                              , @c_Lottable08
                              , @c_Lottable09
                              , @c_Lottable10
                              , @c_Lottable11
                              , @c_Lottable12
                              , @d_Lottable13
                              , @d_Lottable14
                              , @d_Lottable15
                              , @n_Qty

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

      SET @c_packkey = ''
      SET @c_packuom3 = ''
           
      SELECT @c_packkey = SKU.packkey
            ,@c_packuom3= ISNULL(RTRIM(PACK.packuom3),'')
      FROM SKU  WITH (NOLOCK)
      JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.Storerkey = @c_Storerkey
      AND   SKU.Sku       = @c_Sku
      
      IF @c_packkey <> '' AND @c_packuom3 <> '' AND @c_loc <> '' AND @c_sku <> ''
      BEGIN
         --SELECT @c_lot 'LOT', @c_sku 'SKU', @c_id 'ID', @c_loc 'LOC', @n_qty
         BEGIN TRAN
         -- (SWT01)
         
            EXECUTE nspItrnAddWithdrawal
             @n_ItrnSysId    = NULL 
            ,@c_StorerKey    = @c_StorerKey 
            ,@c_Sku          = @c_Sku 
            ,@c_Lot          = @c_Lot 
            ,@c_ToLoc        = @c_Loc 
            ,@c_ToID         = @c_ID
            ,@c_Status       = 'OK' 
            ,@c_lottable01   = @c_Lottable01
            ,@c_lottable02   = @c_Lottable02
            ,@c_lottable03   = @c_Lottable03
            ,@d_lottable04   = @d_Lottable04
            ,@d_lottable05   = @d_Lottable05 
            ,@c_lottable06   = @c_Lottable06
            ,@c_lottable07   = @c_Lottable07
            ,@c_lottable08   = @c_Lottable08
            ,@c_lottable09   = @c_Lottable09
            ,@c_lottable10   = @c_Lottable10
            ,@c_lottable11   = @c_Lottable11
            ,@c_lottable12   = @c_Lottable12
            ,@d_lottable13   = @d_Lottable13
            ,@d_lottable14   = @d_Lottable14
            ,@d_lottable15   = @d_Lottable15
            ,@n_casecnt      = 0 
            ,@n_innerpack    = 0 
            ,@n_qty          = @n_qty 
            ,@n_pallet       = 0 
            ,@f_cube         = 0 
            ,@f_grosswgt     = 0 
            ,@f_netwgt       = 0 
            ,@f_otherunit1   = 0 
            ,@f_otherunit2   = 0 
            ,@c_SourceKey    = @c_SourceKey 
            ,@c_SourceType   = @c_SourceType 
            ,@c_PackKey      = @c_packkey 
            ,@c_UOM          = @c_packuom3 
            ,@b_UOMCalc      = 0 
            ,@d_EffectiveDate= @d_today 
            ,@c_itrnkey      = '' 
            ,@b_Success      = 0   
            ,@n_err          = 0   
            ,@c_errmsg       = ''
            COMMIT TRAN
   END
      --ELSE
      --   SELECT 'FAILED - ', @c_sku, @c_id, @c_loc, @n_qty

      FETCH NEXT FROM Cur_Inv INTO @c_Sku
                                 , @c_Lot
                                 , @c_Loc
                                 , @c_ID
                                 , @c_Lottable01
                                 , @c_Lottable02
                                 , @c_Lottable03
                                 , @d_Lottable04
                                 , @d_Lottable05
                                 , @c_Lottable06
                                 , @c_Lottable07
                                 , @c_Lottable08
                                 , @c_Lottable09
                                 , @c_Lottable10
                                 , @c_Lottable11
                                 , @c_Lottable12
                                 , @d_Lottable13
                                 , @d_Lottable14
                                 , @d_Lottable15
                                 , @n_Qty                            
   END
   CLOSE Cur_Inv
   DEALLOCATE Cur_Inv
END


GO