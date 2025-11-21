SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Store Procedure: ntrCCUpdate                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version:                                                        */
/*                                                                      */
/* Version:                                                             */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Ver.  Purposes                               */
/* 17-Mar-2009  TLTING           Change user_name() to SUSER_SNAME()    */
/* 28-Oct-2013  TLTING           Review Editdate column update          */
/* 15-Dec-2018  TLTING01  1.1    Missing nolock & dynamic SQL cache     */                         
/************************************************************************/



CREATE TRIGGER [dbo].[ntrCCUpdate]
ON  [dbo].[CC]
FOR UPDATE
AS
BEGIN
IF @@ROWCOUNT = 0
BEGIN
RETURN
END

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err                int       -- Error number returned by stored procedure or this trigger
   ,         @n_err2 int              -- For Additional Error Detection
   ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,         @n_continue int
   ,         @n_starttcnt int                -- Holds the current transaction count
   ,         @c_preprocess NVARCHAR(250)         -- preprocess
   ,         @c_pstprocess NVARCHAR(250)         -- post process
   ,         @n_cnt int
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END
   /* #INCLUDE <TRCCU1.SQL> */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF EXISTS (SELECT * FROM DELETED, INSERTED
      WHERE DELETED.CCKey= INSERTED.CCKey
      AND DELETED.Status = "9")
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err=82300
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": CC.Status = '9' (Processed). UPDATE rejected. (ntrCCUpdate)"
      END
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF EXISTS (SELECT * FROM INSERTED,CCDETAIL (NOLOCK) 
      WHERE INSERTED.CCKey= CCDETAIL.CCKey
      AND CCDETAIL.Status <> "9")
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err=82301
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": CCDETAIL.STATUS = '0'(Not Processed) on Some Records. UPDATE rejected. (ntrCCUpdate)"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @b_statusgoingto9 int
      SELECT @b_statusgoingto9 = 0
      IF UPDATE(STATUS)
      BEGIN
         IF EXISTS(SELECT * FROM INSERTED WHERE STATUS="9")
         BEGIN
            SELECT @b_statusgoingto9 = 1
         END
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @b_statusgoingto9 = 1
      BEGIN
         DECLARE @c_lot NVARCHAR(10), @c_loc NVARCHAR(10), @c_id NVARCHAR(18), @c_cckey NVARCHAR(10),
         @c_requestedstorerkey NVARCHAR(15), @c_requestedsku NVARCHAR(20), @c_requestedloc NVARCHAR(10),
         @b_cursor_lotlocid_open int, @c_cursorstmt NVARCHAR(1000),
         @c_cursorlot NVARCHAR(10),
         @c_cursorloc NVARCHAR(10),
         @c_cursorid  NVARCHAR(18),
         @c_cursorstorerkey NVARCHAR(15),
         @c_cursorsku NVARCHAR(20),
         @n_cursorqty int,
         @n_cursorqtyallocated int,
         @n_cursorqtypicked int,
         @n_qtytoadjust int,
         @n_newqty int,
         @d_effectivedate datetime,
         @c_itrnkey NVARCHAR(10),
         @c_ExecArgument nvarchar(500)

         SELECT @b_cursor_lotlocid_open = 0
         SELECT @c_cckey = SPACE(10)
         WHILE (1=1)
         BEGIN
            SELECT @c_cckey = cckey ,
            @c_requestedstorerkey = storerkey,
            @c_requestedsku = sku,
            @c_requestedloc = loc
            from inserted
            WHERE cckey > @c_cckey
            ORDER BY cckey
            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_requestedstorerkey)) IS NOT NULL
            AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_requestedsku)) IS NOT NULL
            AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_requestedloc)) IS NOT NULL
            BEGIN
               SELECT @c_cursorstmt =
               "DECLARE CURSOR_LOTLOCID CURSOR FAST_FORWARD READ_ONLY FOR SELECT STORERKEY,SKU, LOT, LOC,ID,QTY,QTYALLOCATED,QTYPICKED FROM LOTxLOCxID (NOLOCK) WHERE
               STORERKEY= @c_requestedstorerkey "
               + " AND SKU =  @c_requestedsku  "
               + " AND LOC =   @c_requestedloc "
               + " AND QTY > 0 "
            END
            ELSE
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_requestedstorerkey)) IS NOT NULL
            AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_requestedsku)) IS NOT NULL
            BEGIN
               SELECT @c_cursorstmt =
               "DECLARE CURSOR_LOTLOCID CURSOR FAST_FORWARD READ_ONLY FOR SELECT STORERKEY,SKU, LOT, LOC,ID,QTY,QTYALLOCATED,QTYPICKED FROM LOTxLOCxID (NOLOCK) WHERE
               STORERKEY=  @c_requestedstorerkey  "
               + " AND SKU =  @c_requestedsku  "
               + " AND QTY > 0 "
            END
            ELSE
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_requestedloc)) IS NOT NULL
            BEGIN
               SELECT @c_cursorstmt =
               "DECLARE CURSOR_LOTLOCID CURSOR FAST_FORWARD READ_ONLY FOR SELECT STORERKEY,SKU, LOT, LOC,ID,QTY,QTYALLOCATED,QTYPICKED FROM LOTxLOCxID (NOLOCK) WHERE
               LOC=  @c_requestedloc  "
               + " AND QTY > 0 "
            END
            DECLARECURSOR_LOTLOCID:
            DECLARE @c_command NVARCHAR(254)
            SELECT @c_command = "DUMP TRANSACTION " + DB_NAME() + " WITH NO_LOG"

            SET @c_ExecArgument = '@c_requestedstorerkey nvarchar(15), @c_requestedsku nvarchar(20), ' 
                  +' @c_requestedloc Nvarchar(10) '
            EXEC sp_executesql @c_cursorstmt, @c_ExecArgument, 
                  @c_requestedstorerkey, @c_requestedsku, @c_requestedloc

            --EXECUTE (@c_cursorstmt)
            IF @n_err = 16915
            BEGIN
               CLOSE CURSOR_LOTLOCID
               DEALLOCATE CURSOR_LOTLOCID
               GOTO DECLARECURSOR_LOTLOCID
            END
            OPEN CURSOR_LOTLOCID
            SELECT @n_err = @@ERROR
            IF @n_err = 16905
            BEGIN
               CLOSE CURSOR_LOTLOCID
               DEALLOCATE CURSOR_LOTLOCID
               GOTO DECLARECURSOR_LOTLOCID
            END
            IF @n_err = 0
            BEGIN
               SELECT @b_cursor_lotlocid_open = 1
            END
            IF @b_cursor_lotlocid_open = 1
            BEGIN
               WHILE (1=1)
               BEGIN
                  FETCH NEXT FROM cursor_lotlocid INTO @c_cursorstorerkey, @c_cursorsku, @c_cursorlot, @c_cursorloc, @c_cursorid,@n_cursorqty,@n_cursorqtyallocated,@n_cursorqtypicked
                  IF NOT @@FETCH_STATUS = 0
                  BEGIN
                     BREAK
                  END
                  IF NOT EXISTS(SELECT * FROM CCDETAIL (NOLOCK) WHERE CCKEY = @c_cckey
                  AND LOT = @c_cursorlot
                  AND LOC = @c_cursorloc
                  AND ID  = @c_cursorid
                  )
                  BEGIN
                     IF @n_cursorqtyallocated > 0 or @n_cursorqtypicked > 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err=82302
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": QTY Allocated or Picked On Lot/Loc/Id Record " + "Lot:"+@c_cursorlot+" LOC:"+@c_cursorloc+ " ID:" +@c_cursorid + "(ntrCCUpdate)"
                        BREAK
                     END
                     ELSE
                     BEGIN
                        SELECT @b_success = 0, @d_effectivedate = getdate()
                        SELECT @n_qtytoadjust = @n_cursorqty * -1
                        EXECUTE   nspItrnAddAdjustment
                        @n_ItrnSysId  = NULL,
                        @c_StorerKey  = @c_cursorstorerkey,
                        @c_Sku        = @c_cursorSku,
                        @c_Lot        = @c_cursorLot,
                        @c_ToLoc      = @c_cursorLoc,
                        @c_ToID       = @c_cursorId,
                        @c_Status     = "",
                        @c_lottable01 = "",
                        @c_lottable02 = "",
                        @c_lottable03 = "",
                        @d_lottable04 = NULL,
                        @d_lottable05 = NULL,
                        @n_casecnt    = 0,
                        @n_innerpack  = 0,
                        @n_qty        = @n_qtytoadjust,
                        @n_pallet     = 0,
                        @f_cube       = 0,
                        @f_grosswgt   = 0,
                        @f_netwgt     = 0,
                        @f_otherunit1 = 0,
                        @f_otherunit2 = 0,
                        @c_SourceKey  = @c_cckey,
                        @c_SourceType = "ntrCCAdd",
                        @c_PackKey    = "",
                        @c_UOM        = "",
                        @b_UOMCalc    = 0,
                        @d_EffectiveDate = @d_effectivedate,
                        @c_itrnkey    = @c_ItrnKey OUTPUT,
                        @b_Success    = @b_Success OUTPUT,
                        @n_err        = @n_err     OUTPUT,
                        @c_errmsg     = @c_errmsg  OUTPUT
                        IF NOT @b_success = 1
                        BEGIN
                           BREAK
                        END
                     END
                  END
               END -- WHILE (1=1)
            END
            IF @b_cursor_lotlocid_open = 1
            BEGIN
               CLOSE cursor_lotlocid
               DEALLOCATE cursor_lotlocid
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               UPDATE SKU with (ROWLOCK)
               SET LASTCYCLECOUNT = GETDATE(),
                  EditDate = GETDATE(),      --tlting
                  EditWho = SUSER_SNAME()
               WHERE STORERKEY = @c_requestedstorerkey
               AND   SKU = @c_requestedsku
               AND   CYCLECOUNTFREQUENCY IS NOT NULL
               AND   CYCLECOUNTFREQUENCY > 0
               AND   CYCLECOUNTFREQUENCY < 366
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=82303   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table SKU. (ntrCCUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
            END
         END
         SET ROWCOUNT 0
      END -- IF @b_statusgoingto9 = 1
   END -- IF @n_continue = 1 or @n_continue = 2
   IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate) 
   BEGIN
      UPDATE CC with (ROWLOCK)
      SET  EditDate = GETDATE(),
      EditWho = SUSER_SNAME()
      FROM CC, INSERTED
      WHERE CC.CCKey= INSERTED.CCKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=82302   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table CC. (ntrCCUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   /* #INCLUDE <TRCCU2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, "ntrCCUpdate"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END


GO