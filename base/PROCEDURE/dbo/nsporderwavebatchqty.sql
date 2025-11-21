SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOrderWaveBatchQty                               */
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
/* 12-Jul-2017  TLTING  1.1   missing (NOLOCK)                          */ 
/************************************************************************/

CREATE PROC [dbo].[nspOrderWaveBatchQty] (
@c_CartonBatch                NVARCHAR(10),
@n_BatchPickMaxCount      int,
@b_Success    int   OUTPUT,
@n_err     int   OUTPUT,
@c_errmsg     NVARCHAR(250)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT
      @c_CartonBatch "CartonBatch",
      @n_BatchPickMaxCount "BatchPickMaxCount"
   END
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int             , -- For Additional Error Detection
   @n_cnt int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0,@n_cnt=0
   /* #INCLUDE <SPOWBQ1.SQL> */
   DECLARE
   @c_PickHeaderKey   NVARCHAR(10),
   @c_UOM             NVARCHAR(10),
   @c_PutAwayZone     NVARCHAR(10),
   @n_StdCube         float,
   @n_Qty             int,
   @c_UOMPrevious     NVARCHAR(10),
   @c_UOMZonePrevious NVARCHAR(20),
   @n_CubeTotal       float,
   @n_QtyTotal        int,
   @c_PickDetailKey   NVARCHAR(10)
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey,
         OP_CARTONLINES.Qty,
         OP_CARTONLINES.CartonBatch,
         OP_CARTONLINES.PickDetailKey
         FROM OP_CARTONLINES with (NOLOCK)
         WHERE
         OP_CARTONLINES.CartonBatch = @c_CartonBatch
         ORDER BY
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         DECLARE CURSOR_BATCHCOUNT CURSOR FOR
         SELECT
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.Qty,
         OP_CARTONLINES.PickDetailKey
         FROM OP_CARTONLINES with (NOLOCK)
         WHERE
         OP_CARTONLINES.CartonBatch = @c_CartonBatch
         ORDER BY
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey
         FOR READ ONLY
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 71200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Declare error CURSOR_BATCHCUBE (nspOrderWaveBatchQty)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         OPEN CURSOR_BATCHCOUNT
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 71201   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Open error CURSOR_BATCHCUBE (nspOrderWaveBatchQty)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      ELSE IF @b_debug = 1
         BEGIN
            SELECT @@CURSOR_ROWS "@@CURSOR_ROWS"
         END
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         IF NOT @@CURSOR_ROWS = 0
         BEGIN
            SELECT
            @c_UOMPrevious = SPACE(10),
            @n_QtyTotal = 0
            WHILE (1=1)
            BEGIN
               FETCH NEXT
               FROM
               CURSOR_BATCHCOUNT
               INTO
               @c_UOM,
               @n_Qty,
               @c_PickDetailKey
               IF @@FETCH_STATUS = -1
               BEGIN
                  BREAK
               END
            ELSE IF @@FETCH_STATUS < -1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 71202
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fetch Failed. (nspOrderWaveBatchQty)"
                  BREAK
               END
               IF NOT @c_UOM = @c_UOMPrevious
               OR @n_QtyTotal + @n_Qty > @n_BatchPickMaxCount
               BEGIN
                  SELECT @b_success = 0
                  EXECUTE   nspg_getkey
                  "PickHeader"
                  , 10
                  , @c_PickHeaderKey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 71203
                     SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": EXECUTE nspg_getkey failed (nspOrderWaveBatchQty)"
                     BREAK
                  END
                  SELECT @c_UOMPrevious = @c_UOM
                  SELECT @n_QtyTotal = 0
               END
               SELECT @n_QtyTotal = @n_QtyTotal + @n_Qty
               UPDATE OP_CARTONLINES
               SET
               PickHeaderKey = @c_PickHeaderKey
               WHERE
               CartonBatch = @c_CartonBatch
               AND PickDetailKey = @c_PickDetailKey
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 71204   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": UPDATE OP_CARTONLINES.PickHeaderKey failed (nspOrderWaveBatchQty)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  BREAK
               END
               IF @b_debug = 1
               BEGIN
                  SELECT
                  @c_UOM "UOM",
                  @n_Qty "Qty",
                  @c_PickHeaderKey "PickHeaderKey",
                  @n_QtyTotal "QtyTotal"
               END
            END
            CLOSE CURSOR_BATCHCOUNT
         END
      END
      DEALLOCATE CURSOR_BATCHCOUNT
      IF @b_debug = 1
      BEGIN
         SELECT
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey,
         OP_CARTONLINES.Qty,
         OP_CARTONLINES.PickHeaderKey,
         OP_CARTONLINES.CartonBatch,
         OP_CARTONLINES.PickDetailKey
         FROM OP_CARTONLINES with (NOLOCK)
         WHERE
         OP_CARTONLINES.CartonBatch = @c_CartonBatch
         ORDER BY
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey
      END
   END
   /* #INCLUDE <SPOWBQ2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nspOrderWaveBatchQty"
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