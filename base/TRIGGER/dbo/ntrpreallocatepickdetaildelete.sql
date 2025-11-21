SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/* 28-Jul-2017  TLTING   1.1  SET Option                       */

CREATE TRIGGER [dbo].[ntrPreAllocatePickDetailDelete]
ON  [dbo].[PreAllocatePickDetail]
FOR DELETE
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
   ,         @n_err2               int       -- For Additional Error Detection
   ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,         @n_continue int
   ,         @n_starttcnt          int       -- Holds the current transaction count
   ,         @c_preprocess         NVARCHAR(250) -- preprocess
   ,         @c_pstprocess         NVARCHAR(250) -- post process
   ,         @n_cnt                int
   ,         @n_PreAllocatePickDetailSysId    int
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   IF (select count(*) from DELETED) =  (select count(*) from DELETED where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   -- Added By SHONG - skip when nothing to update due to Qty = 0 
   IF (SELECT SUM(Qty) FROM DELETED) = 0 
   BEGIN
      SELECT @n_continue = 4
   END
   
   /* #INCLUDE <TRPAPDD1.SQL> */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      UPDATE LOT SET LOT.QtyPreAllocated =  LOT.QtyPreAllocated - (SELECT SUM(DELETED.Qty )
      FROM DELETED WHERE DELETED.lot = LOT.lot)
      FROM LOT, DELETED
      WHERE DELETED.lot =LOT.lot
      AND   DELETED.Qty > 0 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78201   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete trigger On PreAllocatePickDetail Failed. (ntrPreAllocatePickDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         UPDATE OrderDetail SET OrderDetail.QtyPreAllocated =  OrderDetail.QtyPreAllocated - 
               (SELECT SUM(DELETED.Qty ) FROM DELETED  WHERE DELETED.OrderKey =OrderDetail.OrderKey
                AND DELETED.OrderLineNumber = OrderDetail.OrderLineNumber)
         FROM OrderDetail , DELETED
         WHERE DELETED.OrderKey = OrderDetail.OrderKey
         AND   DELETED.OrderLineNumber = OrderDetail.OrderLineNumber
         AND   DELETED.Qty > 0 
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78202   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete trigger On PreAllocatePickDetail Failed. (ntrPreAllocatePickDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
   /* #INCLUDE <TRPAPDD2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "ntrPreAllocatePickDetailDelete"
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