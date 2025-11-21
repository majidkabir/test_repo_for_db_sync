SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_release                                        */
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
/* Date         Author   ver  Purposes                                  */
/* 14-09-2009   TLTING   1.1  ID field length	(tlting01)                */
/************************************************************************/

CREATE PROC [dbo].[nsp_release] (@c_loadkey NVARCHAR(10), @n_taskdetailcheck int OUTPUT)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pickheaderkey NVARCHAR(10),
   @n_continue  int,
   @c_errmsg  NVARCHAR(255),
   @b_success  int,
   @n_err  int,
   @c_sku  NVARCHAR(20),
   @n_qty  float,
   @c_loc  NVARCHAR(10),
   @c_storer  NVARCHAR(15),
   @c_orderkey  NVARCHAR(10),
   @c_TrfRoom           NVARCHAR(5), -- LoadPlan.TrfRoom
   @c_UOM               NVARCHAR(10),
   @c_Lot               NVARCHAR(10),
   @c_StorerKey         NVARCHAR(15),
   @n_RowNo             int,
   @n_PalletCnt         int,
   @c_pickdetailkey NVARCHAR(10),
   @c_id NVARCHAR(18),				-- tlting01
   @n_packconfig float,
   @b_debug int,
   @c_taskdetailkey NVARCHAR(10) ,
   @c_packkey NVARCHAR(10),
   @n_pallet int,
   @n_sumloadqty int
   , @n_starttcnt int
   select @b_debug = 0, @n_continue = 1
   DECLARE @n_PrevGroup        int,
   @n_RowCount         int,
   @n_TotCases         int,
   @c_PrevOrderKey     NVARCHAR(10),
   @c_Transporter      NVARCHAR(60),
   @c_VehicleNo        NVARCHAR(10),
   @c_firsttime        NVARCHAR(1)
   -- Find out if tasks has been generated for that load before....
   IF EXISTS (SELECT 1 FROM TASKDETAIL (NOLOCK) WHERE LISTKEY = @c_loadkey)
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Tasks have been generated previously. (nsp_release)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   -- Generate TM RF Pick tasks based on Pickdetail's Pick Method.
   IF @b_debug = 1 SELECT '@n_continue ' + convert(char(1), @n_continue)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN -- @n_continue tag 01
      SELECT @n_taskdetailcheck = 0 -- reset counter, we want to count the number of tasks released.
      -- get the total quantity in pickdetail for that particular load
      SELECT @n_sumloadqty = SUM(OD.QtyAllocated)
      FROM ORDERDETAIL OD (NOLOCK), LOADPLANDETAIL LP (NOLOCK), ORDERS O1 (NOLOCK)
      WHERE LP.ORDERKEY = OD.Orderkey
      AND O1.Orderkey = OD.Orderkey
      AND O1.Orderkey = LP.Orderkey
      AND O1.Type NOT IN ('M', 'I') -- manual orders does not count.
      AND O1.UserDefine08 = 'N' -- Only orders that are allocated in Load Plan should be included, the rest are in waveplan
      AND LP.Loadkey = @c_loadkey
      IF EXISTS (SELECT 1 FROM BATCHPICK WHERE LOADKEY = @c_loadkey)
      BEGIN -- IF EXISTS
         UPDATE BATCHPICK
         SET QtyAllocated = @n_sumloadqty
         WHERE LOADKEY = @c_loadkey
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Updating BATCHPICK table Failed (nsp_release)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
         IF @b_debug = 1 SELECT '@n_continue ' + convert(char(1), @n_continue)
      END
   ELSE
      BEGIN
         INSERT INTO BATCHPICK (LOADKEY, QTYALLOCATED)
         VALUES (@c_loadkey, @n_sumloadqty)
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Insert into BATCHPICK table Failed (nsp_release)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END -- IF EXISTS

      IF @b_debug = 1 SELECT 'Calculating Pickdetails' + '  @n_continue ' + convert(char(1), @n_continue)
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN --@n_continue  tag 02
         -- calculate taskdetail
         DECLARE CURSOR_PICK CURSOR fast_forward read_only FOR
         SELECT P1.Pickdetailkey, P1.STORERKEY, P1.SKU, P1.LOT, P1.LOC, P1.ID, P1.UOM,  'PACKCONFIG' = SUM(P1.qty/(CASE WHEN P2.Pallet = 0
         THEN 1
      ELSE P2.Pallet
      END)),
      'QTY' = SUM(P1.QTY)
      FROM PICKDETAIL P1 (NOLOCK), LOADPLANDETAIL L1(NOLOCK), PACK P2 (NOLOCK), ORDERS O1 (NOLOCK)
      WHERE L1.ORDERKEY = P1.ORDERKEY
      AND P1.ORDERKEY = O1.ORDERKEY
      AND L1.ORDERKEY = O1.ORDERKEY
      AND P1.PACKKEY = P2.PACKKEY
      AND L1.LOADKEY = @c_loadkey
      AND P1.STATUS < '3'
      AND O1.USERDEFINE08 = 'N' -- FOR NON-ALLOCATED ORDERS ONLY.
      AND P1.PICKMETHOD = '1' -- RF DIRECTED TASKS
      AND O1.Type NOT IN ('M', 'I') -- exclude manual orders
      GROUP BY P1.Pickdetailkey, P1.STORERKEY,SKU, LOT, LOC, ID , UOM
      ORDER BY P1.Pickdetailkey, P1.Storerkey, P1.SKU
      OPEN CURSOR_PICK
      WHILE ( 1 = 1)-- while tag 01
      BEGIN
         -- SELECT @c_storerkey = '', @c_sku = '', @c_lot = '', @c_loc = '', @c_id = '', @c_uom = '', @n_packconfig = 0, @n_qty = 0
         FETCH NEXT FROM CURSOR_PICK INTO @c_storerkey, @c_sku, @c_lot, @c_loc, @c_id, @c_uom, @n_packconfig, @n_qty
         IF @b_debug = 1 SELECT 'FETCH_STATUS' , @@FETCH_STATUS
         IF @@FETCH_STATUS = -1 BREAK

         IF @b_debug = 1
         BEGIN
            SELECT '@c_storerkey' = @c_storerkey, '@c_sku' = @c_sku, '@c_lot' = @c_lot,
            '@c_loc' = @c_loc, '@c_id' = @c_id, '@n_packconfig' = @n_packconfig, '@n_qty' = @n_qty  , '@c_uom' = @c_uom
         END

         IF EXISTS (SELECT 1 FROM TASKDETAIL (NOLOCK) WHERE LOT = @c_lot AND FROMLOC = @c_loc AND FROMID = @c_id
         AND Storerkey = @c_storerkey AND SKU = @c_sku AND SOURCEKEY = @c_loadkey)
         BEGIN
            -- 	do not generate task for existing records
            CONTINUE
         END
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN -- @n_continue tag 03
            SELECT @c_trfroom = TRFROOM
            FROM LOADPLAN (NOLOCK)
            WHERE LOADKEY = @c_loadkey
            IF @n_packconfig > 1 -- if more than 1 pallets, need to loop and insert a pallet at a time into RF task. This can happen in the drop id locations.
            BEGIN -- @n_packconfig > 1
               IF @b_debug = 1 SELECT 'entering packconfig > 1'
               SELECT @c_packkey = Packkey FROM SKU (NOLOCK)
               WHERE SKU = @c_sku and STORERKEY = @c_storerkey
               SELECT @n_pallet = pallet FROM PACK (NOLOCK)
               WHERE PACKKEY = @c_packkey
               WHILE @n_qty > 0
               BEGIN -- WHILE tag 02
                  IF @b_debug = 1 SELECT '@n_qty', @n_qty, '@n_pallet', @n_pallet
                  IF @n_qty > @n_pallet
                  BEGIN -- @n_qty > @n_pallet

                     EXECUTE nspg_getkey
                     "TaskDetailKey",
                     10,
                     @c_taskdetailkey OUTPUT,
                     @b_success OUTPUT,
                     @n_err OUTPUT,
                     @c_errmsg OUTPUT

                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Unable to Get TaskDetailKey (nsp_release)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                     IF @n_continue = 1 OR @n_continue = 2
                     BEGIN -- @n_continue tag 04
                        IF @b_debug = 1 SELECT 'INSERTING taskdetail record'
                        INSERT INTO TASKDETAIL (taskdetailkey, tasktype, storerkey, sku, lot, UOM, UOMQTY,
                        qty, FromLoc, FromID, ToLoc, TOID, PickMethod, Status, Sourcetype,
                        sourcekey , priority)
                        VALUES (@c_taskdetailkey, 'PK', @c_storerkey, @c_sku, @c_lot, @c_uom, @n_pallet,
                        @n_pallet, @c_loc, @c_id, @c_trfroom, @c_id, '1', '0', 'BATCHPICK',
                        @c_loadkey , '3')
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Insert into Taskdetail Failed (nsp_release)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                        END
                     ELSE
                        BEGIN
                           SELECT @n_qty = @n_qty - @n_pallet -- still got more pallets, therefore, reduce one at a time
                           IF @b_debug = 1 SELECT '@n_qty after reducing a pallet', @n_qty
                           SELECT @n_taskdetailcheck = @n_taskdetailcheck + 1
                        END
                     END -- @n_continue tag 04
                  END  -- @n_qty > @n_pallet
               ELSE
                  BEGIN -- @n_qty < @n_pallet
                     EXECUTE nspg_getkey
                     "TaskDetailKey",
                     10,
                     @c_taskdetailkey OUTPUT,
                     @b_success OUTPUT,
                     @n_err OUTPUT,
                     @c_errmsg OUTPUT
                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Unable to Get TaskDetailKey (nsp_release)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                     IF @n_continue = 1 OR @n_continue = 2
                     BEGIN -- @n_continue tag 05
                        INSERT INTO TASKDETAIL (taskdetailkey, tasktype, storerkey, sku, lot, UOM, UOMQTY,
                        qty, FromLoc, FromID, ToLoc, TOID, PickMethod, Status, Sourcetype,
                        sourcekey, priority )
                        VALUES (@c_taskdetailkey, 'PK', @c_storerkey, @c_sku, @c_lot, @c_uom, @n_qty,
                        @n_qty, @c_loc, @c_id, @c_trfroom, @c_id, '1', '0', 'BATCHPICK',
                        @c_loadkey, '3')
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Insert into Taskdetail Failed (nsp_release)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                        END
                     ELSE
                        BEGIN
                           SELECT @n_qty = 0 -- last pallet...
                           SELECT @n_taskdetailcheck = @n_taskdetailcheck + 1
                        END
                     END -- @n_continue tag 05
                  END -- @n_qty < @n_pallet
                  IF @b_debug = 1
                  BEGIN
                     SELECT 'Looping'
                     SELECT 'Balance - Qty' , @n_qty
                  END
               END -- WHILE tag 02
               IF @b_debug = 1 SELECT 'OUT of Loop'
            END  -- @n_packconfig > 1
         ELSE
            BEGIN-- packconfig <= 1
               IF @b_debug = 1
               BEGIN
                  select 'packconfig <= 1'
               END
               EXECUTE nspg_getkey
               "TaskDetailKey",
               10,
               @c_taskdetailkey OUTPUT,
               @b_success OUTPUT,
               @n_err OUTPUT,
               @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Unable to Get TaskDetailKey (nsp_release)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END

               IF @n_continue = 1 OR @n_continue = 2
               BEGIN -- @n_continue tag 06
                  INSERT INTO TASKDETAIL (taskdetailkey, tasktype, storerkey, sku, lot, UOM, UOMQty,
                  qty, FromLoc, FromID, ToLoc, TOID, PickMethod, Status, Sourcetype,
                  sourcekey , priority)
                  VALUES (@c_taskdetailkey, 'PK', @c_storerkey, @c_sku, @c_lot, @c_uom, @n_qty,
                  @n_qty, @c_loc, @c_id, @c_trfroom, @c_id, '1', '0', 'BATCHPICK',
                  @c_loadkey, '3')
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Insert into Taskdetail Failed (nsp_release)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  END
               ELSE
                  BEGIN
                     SELECT @n_taskdetailcheck = @n_taskdetailcheck + 1
                  END
               END-- @n_continue tag 06
            END -- @n_packconfig <= 1
         END -- @n_continue tag 03
      END -- WHILE tag 01
      CLOSE CURSOR_PICK
      DEALLOCATE CURSOR_PICK
   END --@n_continue  tag 02
END -- @n_continue tag 01
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
   execute nsp_logerror @n_err, @c_errmsg, "nsp_release"
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
END -- End of procedure...

GO