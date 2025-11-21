SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOrderWaveZoneSim                                */
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

CREATE PROC [dbo].[nspOrderWaveZoneSim] (
@c_CartonBatch                NVARCHAR(10),
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
      @c_CartonBatch "CartonBatch"
   END
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int             , -- For Additional Error Detection
   @n_cnt int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0,@n_cnt=0
   /* #INCLUDE <SPOWZS1.SQL> */
   DECLARE
   @c_PickHeaderKey         NVARCHAR(10),
   @c_UOM           NVARCHAR(10),
   @c_OrderKey      NVARCHAR(10),
   @c_PutAwayZone   NVARCHAR(10)
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT DISTINCT
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey,
         OP_CARTONLINES.Loc,
         LOC.PutAwayZone
         FROM OP_CARTONLINES with (NOLOCK),
         LOC with (NOLOCK)
         WHERE
         OP_CARTONLINES.Loc = LOC.Loc
         AND OP_CARTONLINES.CartonBatch = @c_CartonBatch
         ORDER BY
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey,
         LOC.PutAwayZone
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         DECLARE CURSOR_ZONESIM CURSOR FOR
         SELECT DISTINCT
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey,
         LOC.PutAwayZone
         FROM OP_CARTONLINES with (NOLOCK),
         LOC with (NOLOCK)
         WHERE
         OP_CARTONLINES.Loc = LOC.Loc
         AND OP_CARTONLINES.CartonBatch = @c_CartonBatch
         ORDER BY
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey,
         LOC.PutAwayZone
         FOR READ ONLY
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 70800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Declare error CURSOR_BATCHCUBE (nspOrderWaveZoneSim)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
      IF @n_continue=1 or @n_continue=2
      BEGIN
         OPEN CURSOR_ZONESIM
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 70801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Open error CURSOR_BATCHCUBE (nspOrderWaveZoneSim)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
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
            WHILE (1=1)
            BEGIN
               FETCH NEXT
               FROM
               CURSOR_ZONESIM
               INTO
               @c_UOM,
               @c_OrderKey,
               @c_PutAwayZone
               IF @@FETCH_STATUS = -1
               BEGIN
                  BREAK
               END
            ELSE IF @@FETCH_STATUS < -1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 70802
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fetch Failed. (nspOrderWaveZoneSim)"
                  BREAK
               END
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
                  SELECT @n_err = 70803
                  SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": EXECUTE nspg_getkey failed (nspOrderWaveZoneSim)"
                  BREAK
               END
               UPDATE OP_CARTONLINES
               SET
               OP_CARTONLINES.PickHeaderKey = @c_PickHeaderKey
               FROM OP_CARTONLINES,
               LOC with (NOLOCK)
               WHERE
               OP_CARTONLINES.Loc = LOC.Loc
               AND OP_CARTONLINES.UOM = @c_UOM
               AND  OP_CARTONLINES.OrderKey = @c_OrderKey
               AND  LOC.PutAwayZone = @c_PutAwayZone
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 70804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": UPDATE OP_CARTONLINES.PickHeaderKey failed (nspOrderWaveZoneSim)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  BREAK
               END
               IF @b_debug = 1
               BEGIN
                  SELECT @c_UOM "UOM",
                  @c_OrderKey "OrderKey",
                  @c_PickHeaderKey "PickHeaderKey",
                  @c_PutAwayZone "PutAwayZone"
               END
            END
            CLOSE CURSOR_ZONESIM
         END
      END
      DEALLOCATE CURSOR_ZONESIM
      IF @b_debug = 1
      BEGIN
         SELECT
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey,
         OP_CARTONLINES.Loc,
         LOC.PutAwayZone,
         OP_CARTONLINES.PickHeaderKey
         FROM OP_CARTONLINES with (NOLOCK),
         LOC with (NOLOCK)
         WHERE
         OP_CARTONLINES.Loc = LOC.Loc
         AND OP_CARTONLINES.CartonBatch = @c_CartonBatch
         ORDER BY
         OP_CARTONLINES.UOM,
         OP_CARTONLINES.OrderKey,
         LOC.PutAwayZone
      END
   END
   /* #INCLUDE <SPOWZS2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nspOrderWaveZoneSim"
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