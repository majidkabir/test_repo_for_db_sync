SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspItrnAddAdjustment                               */
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
/* 11-May-2006  MaryVong      Add in RDT compatible error messages      */
/* 07-Sep-2006  MaryVong      Add in RDT compatible error messages      */
/* 07-May-2014  TKLIM         Added Lottables 06-15                     */
/* 22-MAR-2017  JayLim        SQL2012 compatibility modification (Jay01)*/
/* 27-APR-2017  JyhBin        Initialize lottable01 to lottable03 value */
/* 27-Jul-2017  TLTING        SET Option                                */
/* 07-Feb-2016  SWT02         Channel Management                        */
/************************************************************************/

CREATE PROC [dbo].[nspItrnAddAdjustment]
     @n_ItrnSysId    int
   , @c_StorerKey    NVARCHAR(15)
   , @c_Sku          NVARCHAR(20)
   , @c_Lot          NVARCHAR(10)
   , @c_ToLoc        NVARCHAR(10)
   , @c_ToID         NVARCHAR(18)
   , @c_Status       NVARCHAR(10)
   , @c_lottable01   NVARCHAR(18)   = '' --JyhBin
   , @c_lottable02   NVARCHAR(18)   = '' --JyhBin
   , @c_lottable03   NVARCHAR(18)   = '' --JyhBin
   , @d_lottable04   DATETIME
   , @d_lottable05   DATETIME
   , @c_Lottable06   NVARCHAR(30)   = ''
   , @c_Lottable07   NVARCHAR(30)   = ''
   , @c_Lottable08   NVARCHAR(30)   = ''
   , @c_Lottable09   NVARCHAR(30)   = ''
   , @c_Lottable10   NVARCHAR(30)   = ''
   , @c_Lottable11   NVARCHAR(30)   = ''
   , @c_Lottable12   NVARCHAR(30)   = ''
   , @d_Lottable13   DATETIME       = NULL
   , @d_Lottable14   DATETIME       = NULL
   , @d_Lottable15   DATETIME       = NULL
   , @n_casecnt      int
   , @n_innerpack    int
   , @n_qty          int
   , @n_pallet       int
   , @f_cube         float
   , @f_grosswgt     float
   , @f_netwgt       float
   , @f_otherunit1   float
   , @f_otherunit2   float
   , @c_SourceKey    NVARCHAR(20)
   , @c_SourceType   NVARCHAR(30)
   , @c_PackKey      NVARCHAR(10)
   , @c_UOM          NVARCHAR(10)
   , @b_UOMCalc      int
   , @d_EffectiveDate datetime
   , @c_itrnkey      NVARCHAR(10)   OUTPUT
   , @b_Success      int        OUTPUT
   , @n_err          int        OUTPUT
   , @c_errmsg       NVARCHAR(250)  OUTPUT
   , @c_Channel      NVARCHAR(20)   = '' -- SWT02
   , @n_Channel_ID   BIGINT         = 0 OUTPUT -- SWT02   
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int              -- For Additional Error Detection
   
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   /* #INCLUDE <SPIAA1.SQL> */
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@d_EffectiveDate)) IS NULL
   BEGIN
      SELECT @d_EffectiveDate = GETDATE()
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @b_success = 1
      EXECUTE   nspg_getkey
      "ItrnKey"
      , 10
      , @c_ItrnKey OUTPUT
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61951
         SELECT @c_errmsg = 'nspItrnAddAdjustment: ' + dbo.fnc_RTrim(@c_errmsg)
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @n_UOMQty int
      SELECT @n_UOMQty = 0
      IF @b_UOMCalc = 1
      BEGIN
         SELECT @n_UOMQty = @n_Qty
         SELECT @b_success = 1
         EXECUTE nspUOMConv
         @n_fromqty = @n_qty,
         @c_fromuom = @c_uom,
         @c_touom   = NULL,
         @c_packkey = @c_packkey,
         @n_toqty   = @n_qty OUTPUT,
         @b_success = @b_success OUTPUT,
         @n_err     = @n_err OUTPUT,
         @c_errmsg  = @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61952
            SELECT @c_errmsg = 'nspItrnAddAdjustment: ' + dbo.fnc_RTrim(@c_errmsg)
         END
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      BEGIN TRANSACTION
         IF @n_ItrnSysId IS NULL
         BEGIN
            SELECT @n_ItrnSysId = RAND() * 2147483647
         END
         INSERT itrn(
              ItrnKey
            , ItrnSysId
            , TranType
            , StorerKey
            , Sku
            , Lot
            , FromLoc
            , FromID
            , ToLoc
            , ToID
            , Status
            , lottable01
            , lottable02
            , lottable03
            , lottable04
            , lottable05
            , lottable06
            , lottable07
            , lottable08
            , lottable09
            , lottable10
            , lottable11
            , lottable12
            , lottable13
            , lottable14
            , lottable15 
            , casecnt
            , innerpack
            , Qty
            , pallet
            , [cube]
            , grosswgt
            , netwgt
            , otherunit1
            , otherunit2
            , SourceKey
            , SourceType
            , PackKey
            , UOM
            , UOMCalc
            , UOMQty
            , EffectiveDate
            , Channel  -- SWT02 
            , Channel_ID -- SWT02              
         )
         VALUES  (
              @c_ItrnKey
            , @n_ItrnSysId
            , "AJ"
            , @c_StorerKey
            , @c_Sku
            , @c_Lot
            , ""
            , ""
            , @c_ToLoc
            , @c_ToID
            , dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Status))
            , @c_lottable01
            , @c_lottable02
            , @c_lottable03
            , @d_lottable04
            , @d_lottable05
            , @c_lottable06
            , @c_lottable07
            , @c_lottable08
            , @c_lottable09
            , @c_lottable10
            , @c_lottable11
            , @c_lottable12
            , @d_lottable13
            , @d_lottable14
            , @d_lottable15 
            , @n_casecnt
            , @n_innerpack
            , @n_Qty
            , @n_pallet
            , @f_cube
            , @f_grosswgt
            , @f_netwgt
            , @f_otherunit1
            , @f_otherunit2
            , @c_SourceKey
            , @c_SourceType
            , @c_PackKey
            , @c_UOM
            , @b_UOMCalc
            , @n_UOMQty
            , @d_EffectiveDate
            ,@c_Channel -- SWT02
            ,@n_Channel_ID -- SWT02               
         )
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
      END
      ELSE 
      BEGIN
         SELECT @n_Channel_ID= i.Channel_ID 
         FROM ITRN AS i WITH(NOLOCK)
         WHERE i.ItrnKey = @c_ItrnKey
      END      
   END -- @n_continue =1 or @n_continue = 2
      
   /* #INCLUDE <SPIAA2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide
   
         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN
   
         -- Raise error with severity = 10, instead of the default severity 16. 
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR 
   
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspItrnAddAdjustment'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         SELECT @b_success = 1
         COMMIT TRAN
      END
      RETURN
   END
END

GO