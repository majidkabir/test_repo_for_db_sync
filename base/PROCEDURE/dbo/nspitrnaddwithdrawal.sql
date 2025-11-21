SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspItrnAddWithdrawal                               */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 07-Sep-2006  MaryVong      Add in RDT compatible error messages      */
/* 07-Apr-2009  ACM           Take adddate, addwho, editwho, editdate   */
/*                            from mbol if itrn sourcetype =            */
/*                            'ntrPickDetailUpdate'  (SOS 131697)       */
/* 26-Feb-2013  TLTING01      Configkey - By BackendShipDate            */
/* 13-Mar-2013  Leong         SOS# 272653 - Change to float for @n_qty  */
/*                                          and @n_UOMQty.              */
/* 21-Nov-2013  Shong         Performance Tuning (Shong01)              */ 
/* 07-May-2014  TKLIM         Added Lottables 06-15                     */
/* 06-Oct-2016  TLTING        SET OPTION                                */
/* 07-Feb-2016  SWT02         Channel Management                        */
/************************************************************************/

CREATE PROC [dbo].[nspItrnAddWithdrawal]
     @n_ItrnSysId       int
   , @c_StorerKey       NVARCHAR(15)
   , @c_Sku             NVARCHAR(20)
   , @c_Lot             NVARCHAR(10)
   , @c_ToLoc           NVARCHAR(10)
   , @c_ToID            NVARCHAR(18)
   , @c_Status          NVARCHAR(10)
   , @c_Lottable01      NVARCHAR(18)
   , @c_Lottable02      NVARCHAR(18)
   , @c_Lottable03      NVARCHAR(18)
   , @d_Lottable04      DATETIME
   , @d_Lottable05      DATETIME
   , @c_Lottable06      NVARCHAR(30)   = ''
   , @c_Lottable07      NVARCHAR(30)   = ''
   , @c_Lottable08      NVARCHAR(30)   = ''
   , @c_Lottable09      NVARCHAR(30)   = ''
   , @c_Lottable10      NVARCHAR(30)   = ''
   , @c_Lottable11      NVARCHAR(30)   = ''
   , @c_Lottable12      NVARCHAR(30)   = ''
   , @d_Lottable13      DATETIME       = NULL
   , @d_Lottable14      DATETIME       = NULL
   , @d_Lottable15      DATETIME       = NULL
   , @n_casecnt         int
   , @n_innerpack       int
   , @n_qty             float -- SOS# 272653
   , @n_pallet          int
   , @f_cube            float
   , @f_grosswgt        float
   , @f_netwgt          float
   , @f_otherunit1      float
   , @f_otherunit2      float
   , @c_SourceKey       NVARCHAR(20)
   , @c_SourceType      NVARCHAR(30)
   , @c_PackKey         NVARCHAR(10)
   , @c_UOM             NVARCHAR(10)
   , @b_UOMCalc         int
   , @d_EffectiveDate   DATETIME
   , @c_itrnkey         NVARCHAR(10)   OUTPUT
   , @b_Success         int        OUTPUT
   , @n_err             int        OUTPUT
   , @c_errmsg          NVARCHAR(250)  OUTPUT
   , @c_Channel         NVARCHAR(20)   = '' -- SWT02
   , @n_Channel_ID      BIGINT         = 0  OUTPUT -- SWT02   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        ,
   @c_preprocess NVARCHAR(250) ,
   @c_pstprocess NVARCHAR(250) ,
   @n_err2       int    ,
   @c_AddWho     NVARCHAR(18), --SOS 131697
   @d_AddDate    DATETIME,     --SOS 131697
   @c_EditWho    NVARCHAR(18), --SOS 131697
   @d_EditDate   DATETIME,     --SOS 131697
   @c_authority  NVARCHAR(1),  -- tlting01 
   @c_OrderKey   NVARCHAR(10)  -- Shong01

   SET @c_AddWho = ''       --SOS 131697
   SET @d_AddDate = NULL     --SOS 131697
   SET @c_EditWho = ''       --SOS 131697
   SET @d_EditDate = NULL    --SOS 131697
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   /* #INCLUDE <SPIAW1.SQL> */
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@d_EffectiveDate)) IS NULL
   BEGIN
      SELECT @d_EffectiveDate = GETDATE()
   END

   --tlting01 S
   SET @c_authority = 0
   SELECT @b_success = 0
   EXECUTE nspGetRight Null, -- facility
                      @c_storerkey, -- Storerkey -- SOS40271
                      null,         -- Sku
                      'BackendShipDate',  -- Configkey
                      @b_success    OUTPUT,
                      @c_authority  OUTPUT,
                      @n_err        OUTPUT,
                      @c_errmsg     OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 61910
         SELECT @c_errmsg = 'nspItrnAddWithdrawal: ' + dbo.fnc_RTrim(@c_errmsg)
      END
   --tlting01 E

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
         SELECT @n_err = 61901
         SELECT @c_errmsg = 'nspItrnAddWithdrawal: ' + dbo.fnc_RTrim(@c_errmsg)
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @n_UOMQty float -- SOS# 272653
            , @c_uominout NVARCHAR(2)
      SELECT @n_UOMQty = 0, @c_uominout = '**'
      IF @c_uom not in ('1','2','3','4','5','6','7')
      OR @b_UOMCalc = 1
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
         @c_errmsg  = @c_errmsg OUTPUT,
         @c_uominout = @c_uominout OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 61902
            SELECT @c_errmsg = 'nspItrnAddWithdrawal: ' + dbo.fnc_RTrim(@c_errmsg)
         END
         ELSE
         BEGIN
            SELECT @n_qty = @n_UOMQty
            IF SUBSTRING(@c_uominout, 1, 1) = '1'  SELECT @n_casecnt = 1
            IF SUBSTRING(@c_uominout, 1, 1) = '2'  SELECT @n_innerpack = 1
            IF SUBSTRING(@c_uominout, 1, 1) = '4'  SELECT @n_pallet = 1
         END
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT    @n_casecnt     = -ABS(@n_casecnt   ),
      @n_innerpack   = -ABS(@n_innerpack ),
      @n_qty         = -ABS(@n_Qty       ),
      @n_pallet      = -ABS(@n_pallet    ),
      @f_cube        = -ABS(@f_cube      ),
      @f_grosswgt    = -ABS(@f_grosswgt  ),
      @f_netwgt      = -ABS(@f_netwgt    ),
      @f_otherunit1  = -ABS(@f_otherunit1),
      @f_otherunit2  = -ABS(@f_otherunit2)
      BEGIN TRANSACTION
         IF @n_ItrnSysId IS NULL
         BEGIN
            SELECT @n_ItrnSysId = RAND() * 2147483647
         END

         -- TLTING01  S  -- Ignore Backend
         IF @c_authority <> 1
         BEGIN
            /*SOS 131697 Start */
            IF ISNULL(RTRIM(@c_SourceType),'') = 'ntrPickDetailUpdate' AND ISNULL(RTRIM(@c_SourceKey),'') <> ''
            BEGIN
               -- Shong01
               SELECT @c_OrderKey = OrderKey 
               FROM PICKDETAIL WITH (NOLOCK) 
               WHERE PickDetailKey = @c_SourceKey
               
               SET @c_AddWho = ''
               
               SELECT TOP 1 
                    @c_AddWho   = MBOL.AddWho, 
                    @d_AddDate  = MBOL.AddDate,
                    @c_EditWho  = MBOL.EditWho, 
                    @d_EditDate = MBOL.EditDate
               FROM MBOLDETAIL WITH (NOLOCK) 
               JOIN MBOL WITH (NOLOCK) ON MBOL.MbolKey = MBOLDETAIL.MbolKey  
               WHERE MBOLDETAIL.OrderKey = @c_OrderKey 
               
            END
         END  --tlting01 E

      IF ISNULL(RTRIM(@c_AddWho),'') = ''
         SET @c_AddWho = suser_sname()
      IF ISDATE(@d_AddDate) <> 1
         SET @d_AddDate = GETDATE()
      IF ISNULL(RTRIM(@c_EditWho),'') = ''
         SET @c_EditWho = suser_sname()
      IF ISDATE(@d_EditDate) <> 1
         SET @d_EditDate = GETDATE()
      /*SOS 131697 End */

      INSERT itrn
        (
          ItrnKey
         ,ItrnSysId
         ,TranType
         ,StorerKey
         ,Sku
         ,Lot
         ,FromLoc
         ,FromID
         ,ToLoc
         ,ToID
         ,STATUS
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
         ,casecnt
         ,innerpack
         ,Qty
         ,pallet
         ,CUBE
         ,grosswgt
         ,netwgt
         ,otherunit1
         ,otherunit2
         ,SourceKey
         ,SourceType
         ,PackKey
         ,UOM
         ,UOMCalc
         ,UOMQty
         ,EffectiveDate
         ,AddWho--SOS 131697
         ,AddDate--SOS 131697
         ,EditWho--SOS 131697
         ,EditDate--SOS 131697         
         ,Channel 
         ,Channel_ID
        )
      VALUES
        (
          @c_ItrnKey
         ,@n_ItrnSysId
         ,"WD" 
         ,@c_StorerKey
         ,@c_Sku
         ,@c_Lot
         ,""
         ,""
         ,@c_ToLoc
         ,@c_ToID
         ,dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Status))
         ,@c_Lottable01
         ,@c_Lottable02
         ,@c_Lottable03
         ,@d_Lottable04
         ,@d_Lottable05
         ,@c_lottable06
         ,@c_lottable07
         ,@c_lottable08
         ,@c_lottable09
         ,@c_lottable10
         ,@c_lottable11
         ,@c_lottable12
         ,@d_lottable13
         ,@d_lottable14
         ,@d_lottable15
         ,@n_casecnt
         ,@n_innerpack
         ,@n_Qty
         ,@n_pallet
         ,@f_cube
         ,@f_grosswgt
         ,@f_netwgt
         ,@f_otherunit1
         ,@f_otherunit2
         ,@c_SourceKey
         ,@c_SourceType
         ,@c_PackKey
         ,@c_UOM
         ,@b_UOMCalc
         ,@n_UOMQty
         ,@d_EffectiveDate
         ,@c_AddWho--SOS 131697
         ,@d_AddDate--SOS 131697
         ,@c_EditWho--SOS 131697
         ,@d_EditDate--SOS 131697         
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
   END
   /* #INCLUDE <SPIAW2.SQL> */
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspItrnAddWithdrawal'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
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
END

GO