SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspUOMCONV                                         */
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
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspUOMCONV]
@n_fromqty         float --int,  Ziyi, May23 2002
,              @c_fromuom          NVARCHAR(10)
,              @c_touom            NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
,              @n_toqty            float output--int            OUTPUT, Ziyi, May23 2002
,              @b_Success          int            OUTPUT
,              @n_err              int            OUTPUT
,              @c_errmsg           NVARCHAR(250)      OUTPUT
,              @c_uominout         NVARCHAR(2) = "__" OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int,              -- For Additional Error Detection
   @n_cnt int                -- Holds @@ROWCOUNT
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT @n_fromqty "@n_fromqty", @c_fromuom "@c_fromuom", @c_touom "@c_touom", @c_packkey "@c_packkey"
   END
   /* #INCLUDE <SPUOM1.SQL> */
   DECLARE @c_uomin NVARCHAR(1), @c_uomout NVARCHAR(1)
   SELECT @c_uomin = '0', @c_uomout = '0'
   IF IsNull(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_uominout)), '') = '' SELECT @c_uominout = '__'
   SELECT @n_toqty = 0
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_packkey)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_packkey))  = ''
      BEGIN
         SELECT @n_toqty = @n_fromqty
         SELECT @c_uomin = '_', @c_uomout = '_'
      END
   ELSE
      BEGIN
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromuom)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromuom)) = ''
         BEGIN
            SELECT @n_toqty = @n_fromqty
         END
      ELSE
         BEGIN
            DECLARE
            @c_PackUOM1   NVARCHAR(10),
            @n_CaseCnt    float,
            @c_ISWHQty1   NVARCHAR(1),
            @c_PackUOM2   NVARCHAR(10),
            @n_InnerPack  int,
            @c_ISWHQty2   NVARCHAR(1),
            @c_PackUOM3   NVARCHAR(10),
            @n_PackQty    float,
            @c_ISWHQty3   NVARCHAR(1),
            @c_PackUOM4   NVARCHAR(10),
            @n_Pallet     int,
            @c_ISWHQty4   NVARCHAR(1),
            @c_PackUOM5   NVARCHAR(10),
            @n_Cube       float,
            @c_ISWHQty5   NVARCHAR(1),
            @c_PackUOM6   NVARCHAR(10),
            @n_GrossWgt   float,
            @c_ISWHQty6   NVARCHAR(1),
            @c_PackUOM7   NVARCHAR(10),
            @n_NetWgt     float,
            @c_ISWHQty7   NVARCHAR(1),
            @c_PackUOM8   NVARCHAR(10),
            @n_OtherUnit1 float,
            @c_ISWHQty8   NVARCHAR(1),
            @c_PackUOM9   NVARCHAR(10),
            @n_OtherUnit2 float,
            @c_ISWHQty9   NVARCHAR(1)
            SELECT
            @c_PackUOM1   = PackUOM1  ,
            @n_CaseCnt    = CaseCnt   ,
            @c_ISWHQty1   = ISWHQty1  ,
            @c_PackUOM2   = PackUOM2  ,
            @n_InnerPack  = InnerPack ,
            @c_ISWHQty2   = ISWHQty2  ,
            @c_PackUOM3   = PackUOM3  ,
            @n_PackQty    = Qty       ,
            @c_ISWHQty3   = ISWHQty3  ,
            @c_PackUOM4   = PackUOM4  ,
            @n_Pallet     = Pallet    ,
            @c_ISWHQty4   = ISWHQty4  ,
            @c_PackUOM5   = PackUOM5  ,
            @n_Cube       = Cube      ,
            @c_ISWHQty5   = ISWHQty5  ,
            @c_PackUOM6   = PackUOM6  ,
            @n_GrossWgt   = GrossWgt  ,
            @c_ISWHQty6   = ISWHQty6  ,
            @c_PackUOM7   = PackUOM7  ,
            @n_NetWgt     = NetWgt    ,
            @c_ISWHQty7   = ISWHQty7  ,
            @c_PackUOM8   = PackUOM8  ,
            @n_OtherUnit1 = OtherUnit1,
            @c_ISWHQty8   = ISWHQty8  ,
            @c_PackUOM9   = PackUOM9  ,
            @n_OtherUnit2 = OtherUnit2,
            @c_ISWHQty9   = ISWHQty9
            FROM Pack (nolock)
            WHERE PackKey = @c_packkey
            SELECT @n_cnt = @@ROWCOUNT
            IF @n_cnt = 0
            BEGIN
               SELECT @n_continue=3
               SELECT @n_err=66500
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Pack (nspUOMCONV)"
               GOTO SPUOM_ERROR
            END
            IF @b_debug = 1
            BEGIN
               SELECT
               @c_PackUOM1   "@c_PackUOM1",
               @n_CaseCnt    "@n_CaseCnt",
               @c_ISWHQty1   "@c_ISWHQty1",
               @c_PackUOM2   "@c_PackUOM2",
               @n_InnerPack  "@n_InnerPack",
               @c_ISWHQty2   "@c_ISWHQty2",
               @c_PackUOM3   "@c_PackUOM3",
               @n_PackQty    "@n_Qty",
               @c_ISWHQty3   "@c_ISWHQty3",
               @c_PackUOM4   "@c_PackUOM4",
               @n_Pallet     "@n_Pallet",
               @c_ISWHQty4   "@c_ISWHQty4",
               @c_PackUOM5   "@c_PackUOM5",
               @n_Cube       "@n_Cube",
               @c_ISWHQty5   "@c_ISWHQty5",
               @c_PackUOM6   "@c_PackUOM6",
               @n_GrossWgt   "@n_GrossWgt",
               @c_ISWHQty6   "@c_ISWHQty6",
               @c_PackUOM7   "@c_PackUOM7",
               @n_NetWgt     "@n_NetWgt",
               @c_ISWHQty7   "@c_ISWHQty7",
               @c_PackUOM8   "@c_PackUOM8",
               @n_OtherUnit1 "@n_OtherUnit1",
               @c_ISWHQty8   "@c_ISWHQty8",
               @c_PackUOM9   "@c_PackUOM9",
               @n_OtherUnit2 "@n_OtherUnit2",
               @c_ISWHQty9   "@c_ISWHQty9"
            END
            IF ISNULL(@c_fromuom,'') = ISNULL(@c_PackUOM1,'')
            BEGIN
               SELECT @n_fromqty = @n_fromqty * @n_CaseCnt
               SELECT @c_uomin = '1'
            END
         ELSE IF ISNULL(@c_fromuom,'') =ISNULL( @c_PackUOM2,'')
            BEGIN
               SELECT @n_fromqty = @n_fromqty * @n_InnerPack
               SELECT @c_uomin = '2'
            END
         ELSE IF ISNULL(@c_fromuom,'') = ISNULL(@c_PackUOM3,'')
            BEGIN
               SELECT @n_fromqty = @n_fromqty
               SELECT @c_uomin = '3'
            END
         ELSE IF ISNULL(@c_fromuom,'') = ISNULL(@c_PackUOM4,'')
            BEGIN
               SELECT @n_fromqty = @n_fromqty * @n_pallet
               SELECT @c_uomin = '4'
            END
         ELSE IF ISNULL(@c_fromuom,'') = ISNULL(@c_PackUOM5,'')
            BEGIN
               SELECT @n_fromqty = @n_fromqty * @n_Cube
               SELECT @c_uomin = '5'
            END
         ELSE IF ISNULL(@c_fromuom,'') = ISNULL(@c_PackUOM6,'')
            BEGIN
               SELECT @n_fromqty = @n_fromqty * @n_GrossWgt
               SELECT @c_uomin = '6'
            END
         ELSE IF ISNULL(@c_fromuom,'') = ISNULL(@c_PackUOM7,'')
            BEGIN
               SELECT @n_fromqty = @n_fromqty * @n_NetWgt
               SELECT @c_uomin = '7'
            END
         ELSE IF ISNULL(@c_fromuom,'') = ISNULL( @c_PackUOM8,'')
            BEGIN
               SELECT @n_fromqty = @n_fromqty * @n_OtherUnit1
               SELECT @c_uomin = '8'
            END
         ELSE IF ISNULL(@c_fromuom,'') =ISNULL( @c_PackUOM9,'')
            BEGIN
               SELECT @n_fromqty = @n_fromqty * @n_OtherUnit2
               SELECT @c_uomin = '9'
            END
         ELSE
            BEGIN
               SELECT @n_continue=3
               SELECT @n_err=66501
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad 'From' UOM (nspUOMCONV)"
               GOTO SPUOM_ERROR
            END
            IF @b_debug = 1
            BEGIN
               SELECT @n_fromqty "@n_fromqty", @c_uomout "@c_uomout"
            END
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_touom)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_touom)) = ''
            BEGIN
               SELECT @n_toqty = @n_fromqty
            END
         ELSE
            BEGIN
               IF ISNULL(@c_touom,'') = ISNULL(@c_PackUOM1,'')
               BEGIN
                  SELECT @n_toqty = @n_fromqty / @n_CaseCnt
                  SELECT @c_uomout = '1'
               END
            ELSE IF ISNULL(@c_touom,'') = ISNULL(@c_PackUOM2,'')
               BEGIN
                  SELECT @n_toqty = @n_fromqty / @n_InnerPack
                  SELECT @c_uomout = '2'
               END
            ELSE IF ISNULL(@c_touom,'') = ISNULL(@c_PackUOM3,'')
               BEGIN
                  SELECT @n_toqty = @n_fromqty
                  SELECT @c_uomout = '3'
               END
            ELSE IF ISNULL(@c_touom,'') = ISNULL(@c_PackUOM4,'')
               BEGIN
                  SELECT @n_toqty = @n_fromqty / @n_pallet
                  SELECT @c_uomout = '4'
               END
            ELSE IF ISNULL(@c_touom,'') = ISNULL(@c_PackUOM5,'')
               BEGIN
                  SELECT @n_toqty = @n_fromqty / @n_Cube
                  SELECT @c_uomout = '5'
               END
            ELSE IF ISNULL(@c_touom,'') = ISNULL(@c_PackUOM6,'')
               BEGIN
                  SELECT @n_toqty = @n_fromqty / @n_GrossWgt
                  SELECT @c_uomout = '6'
               END
            ELSE IF ISNULL(@c_touom,'') = ISNULL(@c_PackUOM7,'')
               BEGIN
                  SELECT @n_toqty = @n_fromqty / @n_NetWgt
                  SELECT @c_uomout = '7'
               END
            ELSE IF ISNULL(@c_touom,'') = ISNULL(@c_PackUOM8,'')
               BEGIN
                  SELECT @n_toqty = @n_fromqty / @n_OtherUnit1
                  SELECT @c_uomout = '8'
               END
            ELSE IF ISNULL(@c_touom,'') = ISNULL(@c_PackUOM9,'')
               BEGIN
                  SELECT @n_toqty = @n_fromqty / @n_OtherUnit2
                  SELECT @c_uomout = '9'
               END
            ELSE
               BEGIN
                  SELECT @n_continue=3
                  SELECT @n_err=66502
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad 'To' UOM (nspUOMCONV)"
                  GOTO SPUOM_ERROR
               END
               IF @b_debug = 1
               BEGIN
                  SELECT @n_toqty "@n_toqty", @c_uomout "@c_uomout"
               END
            END
         END
      END
   END
   IF @b_debug = 1
   BEGIN
      SELECT @n_fromqty "@n_fromqty", @c_uomin "@c_uomin", @n_toqty "@n_toqty", @c_uomout "@c_uomout"
   END
   SPUOM_ERROR:
   /* #INCLUDE <SPUOM2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspUOMCONV"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
ELSE
   BEGIN
      SELECT @b_success = 1
      SELECT @c_uominout = @c_uomin + @c_uomout
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO