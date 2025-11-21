SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspUploadINVBAL                                    */
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
/* Date         Author    ver   Purposes                                */
/* 21-Mar-2014  TLTING    1.1   SQL20112 Bug                            */
/* 30-May-2014  TKLIM     1.2   Added Lottables 06-15                   */
/* 08-Feb-2018  SWT01     1.3   Adding Paramater Variable to Calling SP */
/************************************************************************/
CREATE PROC [dbo].[nspUploadINVBAL]
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   Declare @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err                int       -- Error number returned by stored procedure or this trigger
         , @n_err2               int       -- For Additional Error Detection
         , @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         , @n_continue           int

   Declare @ReceiptPrimaryKey    NVARCHAR(15)
         , @n_ItrnSysId          int
         , @c_StorerKey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_Lot                NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_ToID               NVARCHAR(18)
         , @c_Status             NVARCHAR(10)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @d_Lottable04         DATETIME
         , @d_Lottable05         DATETIME
         , @c_Lottable06         NVARCHAR(30)
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable09         NVARCHAR(30)
         , @c_Lottable10         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_Lottable12         NVARCHAR(30)
         , @d_Lottable13         DATETIME
         , @d_Lottable14         DATETIME
         , @d_Lottable15         DATETIME
         , @n_casecnt            int
         , @n_innerpack          int
         , @n_Qty                int
         , @n_pallet             int
         , @f_cube               float
         , @f_grosswgt           float
         , @f_netwgt             float
         , @f_otherunit1         float
         , @f_otherunit2         float
         , @c_packkey            NVARCHAR(10)
         , @c_uom                NVARCHAR(10)
         , @c_SourceKey          NVARCHAR(15)
         , @c_SourceType         NVARCHAR(30)
         , @d_EffectiveDate      DATETIME
         , @N_RUNNING            INT

   SELECT @n_continue=1, @b_success=1, @n_err = 1,@c_errmsg="", @d_EffectiveDate = getdate()

   Declare CURSOR_BALANCE SCROLL CURSOR FOR
   SELECT UPLOADINVBAL.StorerKey, UPLOADINVBAL.SKU, UPLOADINVBAL.Location, 
         UPLOADINVBAL.Lottable01, UPLOADINVBAL.Lottable02, UPLOADINVBAL.Lottable03, UPLOADINVBAL.Lottable04, UPLOADINVBAL.Lottable05, 
         UPLOADINVBAL.Lottable06, UPLOADINVBAL.Lottable07, UPLOADINVBAL.Lottable08, UPLOADINVBAL.Lottable09, UPLOADINVBAL.Lottable10,
         UPLOADINVBAL.Lottable11, UPLOADINVBAL.Lottable12, UPLOADINVBAL.Lottable13, UPLOADINVBAL.Lottable14, UPLOADINVBAL.Lottable15,
         UPLOADINVBAL.QTY, UPLOADINVBAL.STATUS, UPLOADINVBAL.RUNNING
   FROM    UPLOADINVBAL (NOLOCK)
   LEFT JOIN LOC (nolock) ON (UPLOADINVBAL.Location = LOC.loc)
   WHERE     uploadstatus = 'NO'
   ORDER BY UPLOADINVBAL.StorerKey, UPLOADINVBAL.SKU, LOC.locationtype desc, UPLOADINVBAL.Lottable04,
   UPLOADINVBAL.Lottable05, UPLOADINVBAL.Location

   OPEN CURSOR_BALANCE
   IF @@CURSOR_ROWS = 0
   BEGIN
      SELECT @n_continue = 3 ,@b_success = 0,  @n_err = 62243
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": SELECT RECORD NOT FOUND! "
      Print @c_errmsg
      CLOSE CURSOR_BALANCE
      DEALLOCATE CURSOR_BALANCE
   END
   IF( @n_continue = 1 OR @n_continue = 2 )
   BEGIN
      IF( @@FETCH_STATUS = -1)
      BEGIN
         FETCH FIRST FROM CURSOR_BALANCE INTO    -- Reset Cursor Position
               @c_StorerKey, @c_SKU, @c_ToLoc, 
               @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
               @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
               @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
               @n_QTY, @c_status, @N_RUNNING
      END
   ELSE
      BEGIN
         FETCH NEXT FROM CURSOR_BALANCE INTO    -- Reset Cursor Position
               @c_StorerKey, @c_SKU, @c_ToLoc, 
               @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
               @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
               @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
               @n_QTY, @c_status, @N_RUNNING
      END

      /* Reset Reason Code for New Running */
      UPDATE UploadINVBAL SET Reason = '' WHERE UploadStatus = 'NO'
      WHILE( @@FETCH_STATUS = 0)
      BEGIN
         SELECT @n_continue=1, @b_success=1, @n_err = 1, @c_errmsg = ""

         IF ISNULL(@c_Lottable01,'') = ''
         BEGIN
            SELECT @c_Lottable01 = ' '
         END
         IF ISNULL(@c_Lottable02,'') = ''
         BEGIN
            SELECT @c_Lottable02 = ' '
         END
         IF ISNULL(@c_Lottable03,'') = ''
         BEGIN
            SELECT @c_Lottable03 = ' '
         END
         IF @d_Lottable04 is null
         BEGIN
            SELECT @d_Lottable04 = 0
         END
         IF @d_Lottable05 is null
         BEGIN
            SELECT @d_Lottable05 = getdate()
         END

         IF ISNULL(@c_Lottable06,'') = ''
         BEGIN
            SELECT @c_Lottable06 = ' '
         END
         IF ISNULL(@c_Lottable07,'') = ''
         BEGIN
            SELECT @c_Lottable07 = ' '
         END
         IF ISNULL(@c_Lottable08,'') = ''
         BEGIN
            SELECT @c_Lottable08 = ' '
         END
         IF ISNULL(@c_Lottable09,'') = ''
         BEGIN
            SELECT @c_Lottable09 = ' '
         END
         IF ISNULL(@c_Lottable10,'') = ''
         BEGIN
            SELECT @c_Lottable10 = ' '
         END
         IF ISNULL(@c_Lottable11,'') = ''
         BEGIN
            SELECT @c_Lottable11 = ' '
         END
         IF ISNULL(@c_Lottable12,'') = ''
         BEGIN
            SELECT @c_Lottable12 = ' '
         END
         IF @d_Lottable13 is null
         BEGIN
            SELECT @d_Lottable13 = 0
         END
         IF @d_Lottable14 is null
         BEGIN
            SELECT @d_Lottable14 = 0
         END
         IF @d_Lottable15 is null
         BEGIN
            SELECT @d_Lottable15 = 0
         END

         IF( @c_status = '1' OR @c_status = 'P' )
         BEGIN
            SELECT @c_status = 'OK'
         END
         ELSE IF( @c_status = '2' )
         BEGIN
            SELECT @c_status = 'DAMAGE'
         END
         ELSE IF( @c_status = 'Q' )
         BEGIN
            SELECT @c_status = 'QC'
         END
         ELSE IF( @c_status = 'E' )
         BEGIN
            SELECT @c_status = 'EXPIRED'
         END

         IF NOT EXISTS (SELECT loc FROM LOC WHERE LOC = @c_ToLoc)
         BEGIN
            UPDATE UPLOADINVBAL SET REASON = dbo.fnc_RTrim(REASON)+'1. Location Not Found'
            WHERE  RUNNING = @N_RUNNING
            SELECT @n_continue = 3
         END
         SELECT @c_packkey = SKU.PackKey
            , @c_uom       = PACK.PackUOM3
            , @f_cube      = @N_QTY * SKU.STDCUBE
            , @f_grosswgt  = @N_QTY * SKU.STDGROSSWGT
            , @f_netwgt    = @N_QTY * SKU.STDNETWGT
         FROM SKU (nolock), PACK (nolock)
         WHERE    SKU.PackKey = PACK.Packkey
         AND   SKU.STORERKEY = @c_StorerKey
         AND    SKU.SKU = @c_sku
         IF( @@ROWCOUNT = 0)
         BEGIN
            IF( NOT EXISTS (SELECT * FROM SKU (NOLOCK),  PACK (NOLOCK)
            WHERE SKU.PackKey = PACK.Packkey
            AND   SKU.STORERKEY = @c_StorerKey
            AND   SKU.SKU = @c_sku ) )
            BEGIN
               IF EXISTS (SELECT * FROM SKU WHERE SKU.STORERKEY = @c_StorerKey
               AND SKU.SKU = @c_sku )
               BEGIN
                  UPDATE UPLOADINVBAL SET REASON = dbo.fnc_RTrim(REASON)+' 2. PACKKEY NOT EXISTS'
                  WHERE RUNNING = @N_RUNNING
                  SELECT @n_continue = 3
               END
               ELSE
               BEGIN
                  UPDATE UPLOADINVBAL SET REASON = dbo.fnc_RTrim(REASON)+' 3. STORER or SKU NOT EXISTS'
                  WHERE RUNNING = @N_RUNNING
                  SELECT @n_continue = 3
               END
            END
         END
      ELSE /* Found Storer and SKU and Packkey and Location Gen Pallet ID and System LOT */
         BEGIN

            SELECT  @b_success=1, @n_err = 1,@c_errmsg=""
            EXECUTE  nspg_getkey
                     "ID"
                     ,  10
                     ,  @c_ToID    OUTPUT
                     ,  @b_success OUTPUT
                     ,  @n_err     OUTPUT
                     ,  @c_errmsg  OUTPUT

            SELECT  @b_success=1, @n_err = 1,@c_errmsg=""
            EXECUTE  nsp_lotgen
                    @c_storerkey
                  , @c_sku
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
                  , @c_lot       OUTPUT
                  , @b_Success   OUTPUT
                  , @n_err       OUTPUT
                  , @c_errmsg    OUTPUT
                  , 0
         END
         IF( @n_continue = 1 OR @n_continue = 2 )
         BEGIN
            BEGIN TRAN
               -- (SWT01)
               EXECUTE nspItrnAddDeposit
                   @n_ItrnSysId    =    0 
                   ,@c_StorerKey    =  @c_StorerKey
                   ,@c_Sku          =  @c_Sku
                   ,@c_Lot          =  @c_Lot
                   ,@c_ToLoc        =  @c_ToLoc
                   ,@c_ToID         =  @c_ToID
                   ,@c_Status       =  @c_Status
                   ,@c_lottable01   =  @c_Lottable01
                   ,@c_lottable02   =  @c_Lottable02
                   ,@c_lottable03   =  @c_Lottable03
                   ,@d_lottable04   =  @d_Lottable04
                   ,@d_lottable05   =  @d_Lottable05
                   ,@c_lottable06   =  @c_Lottable06
                   ,@c_lottable07   =  @c_Lottable07
                   ,@c_lottable08   =  @c_Lottable08
                   ,@c_lottable09   =  @c_Lottable09
                   ,@c_lottable10   =  @c_Lottable10
                   ,@c_lottable11   =  @c_Lottable11
                   ,@c_lottable12   =  @c_Lottable12
                   ,@d_lottable13   =  @d_Lottable13
                   ,@d_lottable14   =  @d_Lottable14
                   ,@d_lottable15   =  @d_Lottable15
                   ,@n_casecnt      =  0
                   ,@n_innerpack    =  0
                   ,@n_qty          =  @n_Qty
                   ,@n_pallet       =  0
                   ,@f_cube         =  @f_cube
                   ,@f_grosswgt     =  @f_grosswgt
                   ,@f_netwgt       =  @f_netwgt
                   ,@f_otherunit1   =  0
                   ,@f_otherunit2   =  0
                   ,@c_SourceKey    =  'BEGINBALANCE'
                   ,@c_SourceType   =  'UploadBalance061101'
                   ,@c_PackKey      =  @c_packkey
                   ,@c_UOM          =  @c_uom
                   ,@b_UOMCalc      =  0
                   ,@d_EffectiveDate=  @d_EffectiveDate
                   ,@c_itrnkey      =  ''
                   ,@b_Success      =  @b_Success    OUTPUT
                   ,@n_err          =  @n_err        OUTPUT
                   ,@c_errmsg       =  @c_errmsg     OUTPUT

               update uploadinvbal set uploadstatus = 'YES'
               where   RUNNING  =  @N_RUNNING
               IF( @b_success <> 1)
               BEGIN
                  ROLLBACK TRAN
               END
            ELSE
               BEGIN
                  COMMIT TRAN
               END
            END -- CONINUE CHECK
            FETCH NEXT FROM CURSOR_BALANCE INTO
                  @c_StorerKey, @c_SKU, @c_ToLoc, 
                  @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                  @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,
                  @n_QTY, @c_status, @N_RUNNING
         END -- WHILE LOOP
         CLOSE CURSOR_BALANCE
         DEALLOCATE CURSOR_BALANCE
      END
   END

GO