SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspInsertIntoPutawayTask                           */
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

CREATE PROC [dbo].[nspInsertIntoPutawayTask]
@c_taskdetailkey NVARCHAR(10),
@c_fromloc  NVARCHAR(10),
@c_toloc  NVARCHAR(10),
@c_fromid  NVARCHAR(18),
@c_sku   NVARCHAR(20),
@c_outloc1  NVARCHAR(10) OUTPUT,
@b_isDiffFloor  int  OUTPUT
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

Declare @c_fromOutLoc NVARCHAR(10), @c_fromInLoc NVARCHAR(10)
Declare @c_toInLoc NVARCHAR(10), @c_ToOutLoc NVARCHAR(10)
DECLARE @c_newputawaytaskkey NVARCHAR(10)
Declare @b_success int, @n_err int, @c_errmsg NVARCHAR(250), @n_continue int, @n_cnt int
SELECT @b_isDiffFloor = 0
SELECT @c_outloc1 = ''
SELECT @n_continue = 1
IF EXISTS (SELECT 1 FROM NSQLCONFIG (NOLOCK) WHERE CONFIGKEY = 'PUTAWAYTASK' AND NSQLVALUE = 1)
BEGIN
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_taskdetailkey)) = ""  or @c_taskdetailkey is null
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 89000
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Taskdetailkey cannot be blank or null. (nspInsertIntoPutawayTask)"
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromloc)) = "" or @c_fromloc is null
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 89001
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": FromLoc cannot be blank or null. (nspInsertIntoPutawayTask)"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toloc)) = "" or @c_toloc is null
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 89002
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": ToLoc cannot be blank or null. (nspInsertIntoPutawayTask)"
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- not allow to delete from putawaytask if one of them with status = '9'
      IF EXISTS (SELECT 1 from putawaytask where taskdetailkey = @c_taskdetailkey and status = '9')
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 89003
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Not allow to delete from putawaytask . (nspInsertIntoPutawayTask)"
      END
   END
   -- delete from putawaytask table for the taskdetailkey
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM PUTAWAYTASK(NOLOCK) WHERE taskdetailkey = @c_taskdetailkey )
      BEGIN
         DELETE FROM putawaytask
         WHERE taskdetailkey = @c_taskdetailkey
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 89004
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to delete from PutawayTask table. (nspAddtoPutawayTask)"
         END
      END -- if exists
   END
   -- detect the INLoc & Outloc for FROMLOC
   -- detech the InLoc & OutLoc for TOLOC
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_fromInLoc = PutawayZone.Inloc,
      @c_fromOutLoc = PutawayZone.Outloc
      FROM  LOC (NOLOCK), putawayzone(nolock)
      WHERE LOC.putawayzone = putawayzone.putawayzone
      and   LOC = @c_fromloc
      SELECT @c_ToInLoc = PutawayZone.InLoc,
      @c_ToOutLoc = putawayZone.Outloc
      FROM LOC (NOLOCK), putawayzone(nolock)
      WHERE LOC.putawayzone = putawayzone.putawayzone
      AND LOC = @c_toloc
      -- check if the areas are different
      IF @c_fromInLoc <> @c_toInLoc
      BEGIN
         -- generate the key
         SELECT @b_success = 1
         EXECUTE   nspg_getkey
         "PutawayTaskKey"
         , 10
         , @c_newputawaytaskkey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
         IF @b_success = 1
         BEGIN
            -- insert 1st record (i.e. 1st path) -> from the outloc on source floor to inloc on destination floor
            INSERT INTO putawaytask(transkey, taskdetailkey, id, sku, fromloc, toloc)
            VALUES(@c_newputawaytaskkey, @c_taskdetailkey,  @c_fromid, @c_sku, @c_fromoutloc, @c_Toinloc)
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 89005
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to insert 1st record into PutawayTask table. (nspInsertIntoPutawayTask)"
            END
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @b_success = 1
               EXECUTE nspg_getkey
               "PutawayTaskKey"
               , 10
               , @c_newputawaytaskkey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
               IF @b_success = 1
               BEGIN
                  -- 2nd set -> From the InLoc in destination floor to the final destination
                  INSERT INTO PUTAWAYTASK (transkey, taskdetailkey, id, sku, fromloc, toloc)
                  VALUES ( @c_newputawaytaskkey , @c_taskdetailkey, @c_fromid, @c_sku, @c_ToInLoc, @c_ToLoc)
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 89006
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to insert 2nd record into PutawayTask table. (nspRFTPA01)"
                  END
               ELSE
                  BEGIN
                     SELECT @b_isDiffFloor = 1
                     SELECT @c_outloc1 = @c_fromoutloc
                  END
               END -- b_success
            END -- @n_continue = 1 OR @n_continue = 2
         END -- b_success
      END -- IF @c_frominloc <> @c_toinloc
   END -- @n_continue = 1 OR @n_continue = 2
END -- configkey = 'PUTAWAYTASK' AND nsqlvalue = 1


GO