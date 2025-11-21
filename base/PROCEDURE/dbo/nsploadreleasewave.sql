SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspLoadReleaseWave                                 */
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
/* Date         Author   Ver  Purposes                                  */
/* 14-09-2009   TLTING   1.1  ID field length	(tlting01)                */
/************************************************************************/

CREATE PROC    [dbo].[nspLoadReleaseWave] @c_loadkey      NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE      @n_continue int,
   @n_err int,
   @c_errmsg NVARCHAR(250),
   @c_pickdetailkey NVARCHAR(10),
   @c_taskdetailkey NVARCHAR(10),
   @c_pickloc NVARCHAR(10),
   @b_success int
   DECLARE 	@n_cnt int
   -- CCLAW 08/08/2001
   -- FBR28d (IDSHK) - Declaration for Pick & Drop
   DECLARE @c_sku NVARCHAR(20), @c_id NVARCHAR(18), @c_fromloc NVARCHAR(10), @c_toloc NVARCHAR(10)   --tlting01
   SELECT @n_continue = 1, @n_err = 0, @c_errmsg = ""
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM LoadPlan (NOLOCK) WHERE LoadKey = @c_loadkey AND ProcessFlag = 'L')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": This Load is Currently Being Processed!" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF EXISTS(SELECT 1 FROM LoadPlan (NOLOCK) WHERE LoadKey = @c_loadkey AND ProcessFlag = 'Y')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81006   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Picks Have Been Released!" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   ELSE IF EXISTS( SELECT 1 FROM PICKHEADER (NOLOCK) WHERE ExternOrderkey = @c_loadkey AND Zone IN ('7', '8') )
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81007   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": NON-RF TM Pick Slip has been printed!" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
ELSE
   BEGIN
      BEGIN TRAN
         UPDATE 	LoadPlan
         SET 	PROCESSFLAG = "L"
         WHERE 	loadkey = @c_loadkey
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Update of LoadPlan Failed (nspLoadReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            ROLLBACK TRAN
         END
      ELSE
         BEGIN
            COMMIT TRAN
         END
      END
      -- Modified for PICK N DROP - Pallet Picks
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         DECLARE @c_updateflag NVARCHAR(1), @c_trfroom NVARCHAR(15)
         SELECT @c_updateflag = '0'
         IF EXISTS (SELECT 1 FROM NSQLCONFIG (NOLOCK) WHERE NSQLVALUE = '1' AND CONFIGKEY = 'PUTAWAYTASK' )
         BEGIN
            -- obtain the toloc - final drop location
            SELECT @c_trfroom = TRFROOM
            FROM LOADPLAN (NOLOCK)
            WHERE LOADKEY = @c_loadkey

            -- set the updateflag
            SELECT @c_updateflag = '1'
            -- compare the
         END
      END
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN

         SELECT @c_pickdetailkey = ''
         SELECT @c_pickloc = ''

         WHILE (1=1)
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_pickdetailkey = PickDetailKey, @c_pickloc = Pickdetail.Loc,
            @c_sku = PICKDETAIL.SKU , @c_id = PICKDETAIL.ID ,
            @c_fromloc = PICKDETAIL.Loc, @c_toloc = PICKDETAIL.toLoc
            FROM 	LoadPlanDetail (NOLOCK), PickDetail (NOLOCK), SKUxLOC (NOLOCK)
            WHERE LoadPlanDetail.OrderKey = PickDetail.OrderKey
            AND 	LoadPlanDetail.LoadKey = @c_loadkey
            AND 	PickDetail.PickDetailKey > @c_pickdetailkey
            AND 	PickDetail.storerkey = SKUxLOC.storerkey
            AND 	PickDetail.sku = SKUxLOC.sku
            AND 	PickDetail.Loc = SKUxLOC.Loc
            AND 	SKUxLOC.LocationType NOT IN ('PICK', 'CASE')
            ORDER BY PickDetailKey

            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0
            /* 07/17/2001 CS IDSHK FBR03 Do not update wavekey with loadkey - start */
            /*
            BEGIN TRAN
            UPDATE PickDetail
            SET WaveKey = @c_loadkey,
            Trafficcop = NULL
            WHERE PickDetailKey = @c_pickdetailkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Update Failed on PICKDETAIL (nspLoadReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            ROLLBACK TRAN
            END
            ELSE
            BEGIN
            COMMIT TRAN
            END
            */
            /* 07/17/2001 CS IDSHK FBR03 Do not update wavekey with loadkey - end */
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN  -- Insert into taskdetail Main
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
                  SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Unable to Get TaskDetailKey (nspLoadReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               END
            ELSE
               BEGIN  -- Insert into taskdetail
                  BEGIN TRAN

                     IF @c_updateflag = '1'
                     BEGIN
                        -- if PICK N DRop required, then the drop location should be the one determined in the LOADPLAN.TRFROOM
                        SELECT @c_toloc = @c_trfroom
                     END

                     INSERT TASKDETAIL(
                     TaskDetailKey,
                     TaskType,
                     Storerkey,
                     Sku,
                     Lot,
                     UOM,
                     UOMQty,
                     Qty,
                     FromLoc,
                     FromID,
                     ToLoc,
                     ToId,
                     SourceType,
                     SourceKey,
                     --WaveKey,
                     Caseid,
                     Priority,
                     SourcePriority,
                     OrderKey,
                     OrderLineNumber,
                     PickDetailKey,
                     PickMethod)
                     SELECT	@c_taskdetailkey,
                     "PK",
                     PickDetail.Storerkey,
                     PickDetail.Sku,
                     PickDetail.Lot,
                     PickDetail.UOM,
                     PickDetail.UOMQty,
                     PickDetail.Qty,
                     PickDetail.Loc,
                     PickDetail.ID,
                     @c_toloc,
                     PickDetail.DropId,
                     "PICKDETAIL",
                     PickDetail.pickdetailkey,
                     --@c_loadkey,
                     PickDetail.Caseid,
                     Orders.Priority,
                     Orders.Priority,
                     PickDetail.Orderkey,
                     PickDetail.OrderLineNumber,
                     PickDetail.PickDetailkey,
                     PickDetail.PickMethod
                     FROM 	PICKDETAIL (NOLOCK), ORDERS (NOLOCK)
                     WHERE 	PickDetail.Orderkey = Orders.Orderkey
                     AND 	PickDetailKey = @c_pickdetailkey
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81012   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err) + ": Insert Into TaskDetail Failed (nspLoadReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                        ROLLBACK TRAN
                     END
                  ELSE
                     BEGIN
                        COMMIT TRAN
                     END

                     IF @n_continue = 1 OR @n_continue = 2
                     BEGIN
                        IF @c_updateflag = '1'  -- we need to call the insert putaway process.
                        BEGIN
                           DECLARE @c_outloc1 NVARCHAR(10), @b_isDiffFloor int
                           EXEC nspInsertIntoPutawayTask
                           @c_taskdetailkey,
                           @c_fromloc,
                           @c_toloc,
                           @c_id,
                           @c_sku,
                           @c_outloc1 OUTPUT,
                           @b_isDiffFloor OUTPUT

                           IF @b_isDiffFloor = 1
                           BEGIN
                              -- We need to update the logicaltoloc in taskdetail to location setup in putaway zone for different floor.
                              UPDATE TASKDETAIL
                              SET	LogicalToLoc = @c_outloc1, TrafficCop = NULL
                              WHERE	taskdetailkey = @c_taskdetailkey
                              IF @n_err <> 0
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 81012   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                                 SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err) + ": Update TaskDetail LogicalToLoc Failed (nspLoadReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                              END
                           END
                        END -- @c_updateflag
                     END  -- @n_continue...

                  END -- insert into taskdetail
               END -- Insert into taskdetail Main
            END -- WHILE 1=1
         END --**
         IF @n_continue = 3
         BEGIN
            EXECUTE nsp_logerror @n_err, @c_errmsg, "nspLoadReleaseWave"
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         END
      ELSE
         BEGIN
            BEGIN TRAN
               UPDATE LoadPlan
               SET PROCESSFLAG = "Y"
               WHERE loadkey = @c_loadkey
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250), @n_err), @n_err = 81002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Update of LoadPlan Failed (nspLoadReleaseWave)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  ROLLBACK TRAN
               END
            ELSE
               BEGIN
                  COMMIT TRAN
               END
            END
         END


GO