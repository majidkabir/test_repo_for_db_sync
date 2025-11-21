SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspLOTLOCIDUniqueRow                               */
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
/* 15-Dec-2018  TLTING01  1.1 Missing nolock                            */
/************************************************************************/

CREATE PROC    [dbo].[nspLOTLOCIDUniqueRow]
@c_storerkey    NVARCHAR(15)   OUTPUT
,              @c_sku          NVARCHAR(20)   OUTPUT
,              @c_lot          NVARCHAR(10)   OUTPUT
,              @c_Loc          NVARCHAR(10)   OUTPUT
,              @c_ID           NVARCHAR(18)   OUTPUT
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
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
   @n_cnt int              ,
   @n_err2 int              -- For Additional Error Detection
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   DECLARE @c_work_storerkey NVARCHAR(15), @c_work_sku NVARCHAR(20), @c_work_lot NVARCHAR(10),
   @c_work_id NVARCHAR(18), @c_work_loc NVARCHAR(10)
   /* #INCLUDE <SPCMQ1.SQL> */
   SELECT @c_work_storerkey = @c_storerkey, @c_work_sku = @c_sku, @c_work_lot = @c_lot,
   @c_work_id = @c_id, @c_work_loc = @c_loc
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_id)) IS NOT NULL
      BEGIN
         SELECT @c_work_loc=Loc, @c_work_id=id,@c_work_lot=lot, @c_work_storerkey = Storerkey, @c_work_sku=Sku
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_id AND QTY > 0
         SELECT @n_cnt = @@ROWCOUNT
         IF @n_cnt > 0
         BEGIN
            SELECT @c_work_loc = LOC FROM LOTxLOCxID (NOLOCK)
            WHERE ID = @c_id AND QTY > 0
            GROUP BY LOC
            DECLARE @id_count int, @id_qty int
            SELECT @id_count = count(*) FROM lotxlocxid (NOLOCK) WHERE ID = @c_id and qty > 0
            IF @id_count > 1
            BEGIN
               SELECT @id_count = count(*) FROM lotxlocxid (NOLOCK) WHERE ID = @c_id and loc = @c_loc and qty > 0
            END
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL and (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NULL or @c_lot = "NOLOT")
            BEGIN
               SELECT @c_work_lot = LOT FROM LOTxLOCxID (NOLOCK)
               WHERE ID = @c_id
               AND LOC = @c_loc
               AND QTY > 0
               AND SKU = @c_sku
               GROUP BY LOT
               IF @@ROWCOUNT = 1
               BEGIN
                  SELECT @c_lot = @c_work_lot
               END
            ELSE
               BEGIN
                  SELECT @n_continue = 3 , @n_err = 84301
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Find Unique From ROW - SKU Is Not Qualified (nspLOTLOCIDUniqueRow)"
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF @n_cnt > 1
               BEGIN
                  SELECT @c_work_loc=Loc, @c_work_id=id,@c_work_lot=lot, @c_work_storerkey = Storerkey, @c_work_sku=Sku
                  FROM LOTxLOCxID (NOLOCK)
                  WHERE ID = @c_id AND LOC=@c_loc AND QTY > 0
                  SELECT @n_cnt = @@ROWCOUNT
                  IF @n_cnt > 1
                  BEGIN
                     SELECT @c_work_loc=Loc, @c_work_id=id,@c_work_lot=lot, @c_work_storerkey = Storerkey, @c_work_sku=Sku FROM
                     LOTxLOCxID  (NOLOCK) WHERE ID = @c_id AND QTY > 0 AND LOC=@c_loc AND LOT=@c_lot
                     SELECT @n_cnt = @@ROWCOUNT
                     IF @n_cnt > 1
                     BEGIN
                        SELECT @n_continue = 3 , @n_err = 84302
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Find Unique From ROW. (nspLOTLOCIDUniqueRow)"
                     END
                  ELSE IF @n_cnt = 1
                     BEGIN
                        GOTO ENDOFSEARCH
                     END
                  ELSE
                     BEGIN
                        SELECT @n_continue = 3 , @n_err = 84303
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Find Unique From ROW. (nspLOTLOCIDUniqueRow)"
                     END
                  END
               ELSE IF @n_cnt = 1
                  BEGIN
                     GOTO ENDOFSEARCH
                  END
               ELSE IF @n_cnt = 0
                  BEGIN
                     SELECT @n_continue = 3 , @n_err = 84304
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Find Unique From ROW. (nspLOTLOCIDUniqueRow)"
                  END
               END
            ELSE IF @n_cnt = 1
               BEGIN
                  GOTO ENDOFSEARCH
               END
            ELSE IF @n_cnt = 0
               BEGIN
                  SELECT @n_continue = 3 , @n_err = 84305
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Find Unique From ROW. (nspLOTLOCIDUniqueRow)"
               END
            END
         END
      ELSE
         BEGIN
            SELECT @n_continue = 3 , @n_err = 84306
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Find Unique From ROW. (nspLOTLOCIDUniqueRow)"
         END
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_lot)) IS NOT NULL
         BEGIN
            SELECT @c_id = Space(18)
            SELECT @c_work_lot=lot, @c_work_loc=Loc, @c_work_id=id, @c_work_storerkey=Storerkey, @c_work_sku=Sku
            FROM LOTxLOCxID (NOLOCK)
            WHERE LOT=@c_lot AND LOC=@c_loc AND QTY > 0
            AND ID = @c_id
            SELECT @n_cnt = @@ROWCOUNT
            IF @n_cnt <> 1
            BEGIN
               SELECT @n_continue = 3 , @n_err = 84307
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Find Unique From ROW. (nspLOTLOCIDUniqueRow)"
            END
         ELSE IF @n_cnt = 1
            BEGIN
               GOTO ENDOFSEARCH
            END
         END
      ELSE
         BEGIN
            SELECT @c_id = Space(18)
            SELECT @c_work_loc=Loc, @c_work_id=id,@c_work_lot=lot, @c_work_storerkey = Storerkey, @c_work_sku=Sku
            FROM LOTxLOCxID (NOLOCK)
            WHERE LOC=@c_loc AND STORERKEY = @c_storerkey AND SKU=@c_sku AND QTY > 0
            AND ID = @c_id
            SELECT @n_cnt = @@ROWCOUNT
            IF @n_cnt <> 1
            BEGIN
               SELECT @n_continue = 3 , @n_err = 84308
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Find Unique From ROW. (nspLOTLOCIDUniqueRow)"
            END
         ELSE IF @n_cnt = 1
            BEGIN
               GOTO ENDOFSEARCH
            END
         END
      END
   END
   ENDOFSEARCH:
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_storerkey = @c_work_storerkey, @c_sku = @c_work_sku, @c_lot = @c_work_lot,
      @c_id = @c_work_id, @c_loc = @c_work_loc
   END
   /* #INCLUDE <SPCMQ2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspLOTLOCIDUniqueRow"
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
END


GO