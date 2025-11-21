SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrPreAllocatePickDetailUpdate                                 */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Input Parameters: NONE                                                  */
/*                                                                         */
/* Output Parameters: NONE                                                 */
/*                                                                         */
/* Return Status: NONE                                                     */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: When records updated                                         */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 17-Mar-2009  TLTING        Change user_name() to SUSER_SNAME()          */
/* 28-Oct-2013  TLTING        Review Editdate column update                */
/* 24-Jul-2015  LEONG         Revise Update Lot.QtyPreAllocated (Copy logic*/
/*                            from ntrPickDetaipUpdate. (Leong01)          */
/***************************************************************************/

CREATE TRIGGER [dbo].[ntrPreAllocatePickDetailUpdate]
ON  [dbo].[PreAllocatePickDetail]
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
   
   DECLARE @b_debug INT
   SELECT @b_debug = 0

   DECLARE
        @b_Success            INT       -- Populated by calls to stored procedures - was the proc successful?
      , @n_err                INT       -- Error number returned by stored procedure OR this trigger
      , @n_err2               INT       -- For Additional Error Detection
      , @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
      , @n_continue           INT
      , @n_starttcnt          INT       -- Holds the current transaction count
      , @c_preprocess         NVARCHAR(250) -- preprocess
      , @c_pstprocess         NVARCHAR(250) -- post process
      , @n_cnt                INT
      , @n_PreAllocatePickDetailSysId INT

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END
   
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END

   IF @b_debug = 1
   BEGIN
      SELECT "Reduce PreAllocated QTY in All tables"
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Leong01 (Start)
      CREATE TABLE #tLOT  (
         LOT             NVARCHAR(10) NOT NULL,
         QtyPreAllocated INT
         PRIMARY KEY CLUSTERED (LOT)
         )
   
      INSERT INTO #tLOT ( LOT, QtyPreAllocated )
      SELECT LOT,
             SUM (Qty) AS QtyPreAllocated
      FROM INSERTED
      GROUP BY LOT
   
      UPDATE tLOT
         SET QtyPreAllocated = tLOT.QtyPreAllocated + DEL_LOT.QtyPreAllocated
      FROM  #tLOT tLOT
      JOIN (SELECT LOT,
             SUM (Qty * -1) AS QtyPreAllocated
            FROM DELETED
            GROUP BY LOT) AS DEL_LOT ON DEL_LOT.LOT = tLOT.LOT
   
      INSERT INTO #tLOT  ( LOT, QtyPreAllocated )
      SELECT DELETED.LOT,
             SUM (Qty * -1) AS QtyPreAllocated
      FROM DELETED
      LEFT OUTER JOIN #tLOT LOT ON LOT.LOT = DELETED.LOT
      WHERE LOT.LOT IS NULL
      GROUP BY DELETED.LOT
   
      UPDATE LOT WITH (ROWLOCK)
      SET  LOT.QtyPreAllocated = (LOT.QtyPreAllocated + tL.QtyPreAllocated),
           LOT.EditDate = GETDATE(),   --tlting
           LOT.EditWho = SUSER_SNAME()
      FROM LOT
      JOIN #tLOT tL ON tL.LOT = LOT.LOT
   
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78101
        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update trigger On LOT Failed. (ntrPreAllocatePickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
   
      -- UPDATE LOT with (ROWLOCK)
      -- SET  LOT.QtyPreAllocated = LOT.QtyPreAllocated - (SELECT SUM(DELETED.Qty )
      --                                                   FROM DELETED WHERE DELETED.lot = LOT.lot)
      --                                                + (SELECT SUM(INSERTED.Qty )
      --                                                   FROM INSERTED WHERE INSERTED.lot = LOT.lot),
      --      EditDate = GETDATE(),   --tlting
      --      EditWho = SUSER_SNAME()
      -- FROM LOT join DELETED on lot.lot = DELETED.lot
      --          join INSERTED on lot.lot = INSERTED.lot
      -- SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      -- IF @n_err <> 0
      -- BEGIN
      --    SELECT @n_continue = 3
      --    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      --    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update trigger On PreAllocatePickDetail Failed. (ntrPreAllocatePickDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      -- END
      -- Leong01 (End)
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         UPDATE ORDERDETAIL with (ROWLOCK)
            SET ORDERDETAIL.QtyPreAllocated = ORDERDETAIL.QtyPreAllocated - ( SELECT SUM(DELETED.Qty )
                                                                              FROM DELETED
                                                                              WHERE DELETED.OrderKey =ORDERDETAIL.OrderKey
                                                                              AND DELETED.OrderLineNumber = ORDERDETAIL.OrderLineNumber )
                                            + ( SELECT SUM(INSERTED.Qty )
                                                FROM INSERTED
                                                WHERE INSERTED.OrderKey =ORDERDETAIL.OrderKey
                                                AND INSERTED.OrderLineNumber = ORDERDETAIL.OrderLineNumber ),
                ORDERDETAIL.Trafficcop = NULL,
                ORDERDETAIL.EditDate   = GETDATE(),   --tlting
                ORDERDETAIL.EditWho    = SUSER_SNAME()
         FROM ORDERDETAIL
         JOIN DELETED ON DELETED.OrderKey = ORDERDETAIL.OrderKey
              AND DELETED.OrderLineNumber = ORDERDETAIL.OrderLineNumber
         JOIN INSERTED ON INSERTED.OrderKey = ORDERDETAIL.OrderKey
          AND INSERTED.OrderLineNumber = ORDERDETAIL.OrderLineNumber
   
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 78102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update trigger On PreAllocatePickDetail Failed. (ntrPreAllocatePickDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
 
   IF @b_debug = 1
   BEGIN
      SELECT "If OK To Continue, Update The EditDate and EditWho On The Order Headers"
   END
 
   IF ( @n_continue = 1 OR @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE PreAllocatePickDetail
         SET EditDate   = GETDATE(),
             EditWho    = SUSER_SNAME(),
             Trafficcop = NULL
      FROM PreAllocatePickDetail, INSERTED
      WHERE PreAllocatePickDetail.PreAllocatePickDetailKey = INSERTED.PreAllocatePickDetailKey
   
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=78105   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On PreAllocatePickDetail. (ntrPreAllocatePickDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrPreAllocatePickDetailUpdate"
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