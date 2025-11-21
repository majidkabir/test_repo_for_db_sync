SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: ispRVWAV24                                          */
/* Creation Date: 16-Jan-2018                                            */
/* Copyright: LFL                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-8050 - CN MAST Reverse tasks                             */
/*                                                                       */
/* Called By: wave                                                       */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */
/* 01-12-2020  Wan02    1.2   Add (NOLOCK)                               */
/* 17-03-2022  SYChua   1.4   JSM-48082 - Fix reverse taskdetail.qty, to */
/*                            deduct correctly (SY01)                    */
/*************************************************************************/

CREATE PROCEDURE [dbo].[ispRVWAV24]
  @c_wavekey      NVARCHAR(10)
 ,@c_Orderkey     NVARCHAR(10) = ''
 ,@b_Success      int        OUTPUT
 ,@n_err          int        OUTPUT
 ,@c_errmsg       NVARCHAR(250)  OUTPUT
 AS
 BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @n_continue int,
            @n_starttcnt int,         -- Holds the current transaction count
            @n_debug int,
            @n_cnt int

    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0, @n_debug = 0

    DECLARE @c_Storerkey NVARCHAR(15)
           ,@c_Sku NVARCHAR(20)
           ,@c_Lot NVARCHAR(10)
           ,@c_ToLoc NVARCHAR(10)
           ,@c_ToID NVARCHAR(18)
           ,@n_Qty INT
           ,@c_Taskdetailkey NVARCHAR(10)
           ,@c_otherwavekey NVARCHAR(10)
           ,@c_Tasktype NVARCHAR(10)
           ,@c_DocType NVARCHAR(1)
           ,@c_Pickdetailkey NVARCHAR(10)
           ,@n_QtyBal INT
           ,@n_ShortQty INT

    SELECT TOP 1 @c_DocType = O.DocType
    FROM WAVE W (NOLOCK)
    JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
    JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
    AND W.Wavekey = @c_Wavekey

    ----reject if wave not yet release
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        --IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)
        --           WHERE TD.Wavekey = @c_Wavekey
        --           AND TD.Sourcetype IN ('ispRLWAV24')
        --           AND TD.Tasktype IN ('RPF'))

        IF NOT EXISTS(SELECT 1
                      FROM PICKDETAIL PD (NOLOCK)
                        JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey
                      WHERE WD.Wavekey = @c_Wavekey
                      AND TD.TaskType IN('RPF','RPT')
                      OR (ISNULL(PD.notes,'') <> '' AND ISNULL(PD.Pickslipno,'') <> '' AND @c_Doctype <> 'E')
                      )
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 81010
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV24)'

            UPDATE WAVE
            --SET STATUS = '0' -- Normal        --(Wan01)
            SET TMReleaseFlag = 'N'             --(Wan01)
            ,  TrafficCop = NULL                --(Wan01)
            ,  EditWho = SUSER_SNAME()          --(Wan01)
            ,  EditDate= GETDATE()              --(Wan01)
            WHERE WAVEKEY = @c_wavekey          --(Wan01)
            --AND STATUS = '1'
            AND TMReleaseFlag = 'Y'             --(Wan01)
        END
    END

    ----reject if any task was started
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)
                  WHERE TD.Wavekey = @c_Wavekey
                  AND TD.Sourcetype IN ('ispRLWAV24')
                  AND TD.Status <> '0'
                  AND TD.Tasktype IN ('RPF'))
       BEGIN
          SELECT @n_continue = 3
          SELECT @n_err = 81020
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV24)'
       END
    END

    BEGIN TRAN

    ----delete tasks
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
          DECLARE cur_task CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT TD.Taskdetailkey, SUM(PD.Qty), TD.TaskType
             FROM WAVEDETAIL WD (NOLOCK)
             JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
             JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey
            LEFT JOIN TASKDETAIL PND (NOLOCK) ON TD.Taskdetailkey = PND.Sourcekey AND TD.Storerkey = PND.Storerkey AND TD.Sku = PND.Sku AND PND.TaskType = 'RPT'  --(Wan02)
                                        AND PND.Status <> 'X'
             WHERE WD.Wavekey = @c_Wavekey
             --AND TD.Sourcetype = 'ispRLWAV14'
             AND PND.Taskdetailkey IS NULL
             AND TD.TaskType IN('RPF','RPT')
             GROUP BY TD.Taskdetailkey, TD.Tasktype
             UNION ALL
             SELECT DISTINCT TD.Taskdetailkey, 0, ''
             FROM TASKDETAIL TD (NOLOCK)
             LEFT JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey
             WHERE TD.Wavekey = @c_Wavekey
             AND PD.Taskdetailkey IS NULL
             AND TD.Sourcetype = 'ispRLWAV24'

         OPEN cur_task

         FETCH NEXT FROM cur_task INTO @c_Taskdetailkey, @n_Qty, @c_TaskType

         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
              SET @c_otherwavekey = ''

              IF @c_TaskType = 'RPT'
              BEGIN
                 SELECT TOP 1 @c_otherwavekey = TD.Wavekey
                 FROM TASKDETAIL TD (NOLOCK)
                 WHERE TD.Taskdetailkey = @c_Taskdetailkey
                 AND TD.Wavekey <> @c_Wavekey
              END
              ELSE
              BEGIN
                 SELECT TOP 1 @c_otherwavekey = WD.Wavekey
                 FROM PICKDETAIL PD (NOLOCK)
                 JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                 JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey
                 WHERE TD.Taskdetailkey = @c_Taskdetailkey
                 AND WD.Wavekey <> @c_Wavekey
              END

              IF ISNULL(@c_otherwavekey,'') <> ''
              BEGIN
                IF @c_TaskType = 'RPT'
                BEGIN
                    --Update RPT task
                   UPDATE TASKDETAIL WITH (ROWLOCK)
                   SET Message03 = CASE WHEN Message03 = 'WV:' + @c_Wavekey THEN '' ELSE Message03 END,
                       Message02 = 'RVWV:' + @c_Wavekey,
                       trafficcop = NULL
                   WHERE Taskdetailkey = @c_Taskdetailkey

                  --Update RPT reference task
                   UPDATE TASKDETAIL WITH (ROWLOCK)
                   SET TASKDETAIL.SystemQty = TASKDETAIL.SystemQty - @n_Qty,
                       TASKDETAIL.Message03 = CASE WHEN TASKDETAIL.Message03 = 'WV:' + @c_Wavekey THEN '' ELSE TASKDETAIL.Message03 END,
                       TASKDETAIL.Message02 = 'RVWV:' + @c_Wavekey,
                       TASKDETAIL.trafficcop = NULL
                   FROM TASKDETAIL
                   JOIN TASKDETAIL PND (NOLOCK) ON TASKDETAIL.Taskdetailkey = PND.Sourcekey AND TASKDETAIL.Storerkey = PND.Storerkey AND TASKDETAIL.Sku = PND.Sku
                   WHERE PND.Taskdetailkey = @c_Taskdetailkey
                END
                ELSE
                BEGIN
                    --Update RPF task

                    /*-- SY01 START
                    SELECT @n_QtyBal = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen
                    FROM TASKDETAIL TD (NOLOCK)
                    JOIN LOTXLOCXID LLI (NOLOCK) ON TD.Lot = LLI.Lot AND TD.FromLoc = LLI.Loc AND TD.FromID = LLI.Id
                    WHERE TD.Taskdetailkey = @c_Taskdetailkey

                    IF @n_QtyBal < @n_Qty --check whether the available qty enough for reverse task's pick qty.
                       SET @n_ShortQty = @n_Qty - @n_QtyBal
                    ELSE
                       SET @n_ShortQty = 0
                    SY01 END --*/

                    --SY01 START
                    SELECT @n_ShortQty = TD.Qty - TD.SystemQty + @n_Qty
                    FROM TASKDETAIL TD (NOLOCK)
                    WHERE Taskdetailkey = @c_Taskdetailkey
                    --SY01 END

                    UPDATE TASKDETAIL WITH (ROWLOCK)
                    SET SystemQty = SystemQty - @n_Qty,
                       QtyReplen = (QtyReplen + @n_Qty) - @n_ShortQty,
                       Qty = Qty - @n_ShortQty,
                       Message03 = CASE WHEN Message03 = 'WV:' + @c_Wavekey THEN '' ELSE Message03 END,
                       Message02 = 'RVWV:' + @c_Wavekey,
                       Wavekey = CASE WHEN Wavekey = @c_Wavekey THEN @c_OtherWavekey ELSE Wavekey END
                       --trafficcop = NULL
                    WHERE Taskdetailkey = @c_Taskdetailkey

                END

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                 SELECT @n_continue = 3
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetail Table Failed. (ispRVWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               END

              END
              ELSE
              BEGIN
               DELETE TASKDETAIL
               WHERE Taskdetailkey = @c_Taskdetailkey

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                 SELECT @n_continue = 3
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               END
              END

            FETCH NEXT FROM cur_task INTO @c_Taskdetailkey, @n_Qty, @c_TaskType
         END
         CLOSE cur_task
         DEALLOCATE  cur_task


         /*
        UPDATE TASKDETAIL WITH (ROWLOCK)
         SET TASKDETAIL.Message03 = '',
             TASKDETAIL.Message02 = 'RVWV:' + @c_Wavekey,
             TASKDETAIL.trafficcop = NULL
         FROM TASKDETAIL
          LEFT JOIN TASKDETAIL PND ON TASKDETAIL.Taskdetailkey = PND.Sourcekey AND TASKDETAIL.Storerkey = PND.Storerkey AND TASKDETAIL.Sku = PND.Sku AND PND.TaskType = 'RPT'
                                     AND PND.Status <> 'X'
         WHERE TASKDETAIL.SourceType = 'ispRLWAV24'
         AND LEFT(TASKDETAIL.Message03,13) = 'WV:' + @c_Wavekey
         AND PND.Taskdetailkey IS NULL
         */

       /*
       DELETE TASKDETAIL
       WHERE TASKDETAIL.Wavekey = @c_Wavekey
       AND TASKDETAIL.Sourcetype IN ('ispRLWAV14')
       AND TASKDETAIL.Tasktype IN ('RPF')

       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
       END
       */
    END

    ----remove from task of other wave
    /*
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
          DECLARE cur_othertask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              SELECT DISTINCT TD.Taskdetailkey
              FROM PICKDETAIL PD (NOLOCK)
              JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = PD.Orderkey
              JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey
              JOIN PICKDETAIL PD2 (NOLOCK) ON TD.Taskdetailkey = PD2.Taskdetailkey
              JOIN WAVEDETAIL WD2 (NOLOCK) ON WD2.Orderkey = PD2.Orderkey
              WHERE WD.Wavekey = @c_Wavekey
              AND WD.Wavekey <> WD2.Wavekey
              AND TD.Wavekey <> @c_Wavekey
              AND TD.Sourcetype = 'ispRLWAV14'

         OPEN cur_othertask

         FETCH NEXT FROM cur_othertask INTO @c_Taskdetailkey

         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
              SELECT @n_Qty = SUM(PD.Qty)
              FROM PICKDETAIL PD (NOLOCK)
              JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = PD.Orderkey
              WHERE PD.Taskdetailkey = @c_Taskdetailkey
              AND WD.Wavekey = @c_Wavekey

              UPDATE TASKDETAIL WITH (ROWLOCK)
              SET SystemQty = SystemQty - @n_Qty,
                  QtyReplen = QtyReplen + @n_Qty,
                  Message03 = CASE WHEN Message03 = 'WV:' + @c_Wavekey THEN '' ELSE Message03 END,
                  Message02 = 'RVWV:' + @c_Wavekey
              WHERE Taskdetailkey = @c_Taskdetailkey

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
              SELECT @n_continue = 3
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Taskdetail Table Failed. (ispRVWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END

            FETCH NEXT FROM cur_othertask INTO @c_Taskdetailkey
         END
         CLOSE cur_othertask
         DEALLOCATE cur_othertask
    END
    */

    ----Remove taskdetailkey from pickdetail of the wave
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PICKDETAIL.Pickdetailkey
          FROM WAVEDETAIL (NOLOCK)
          JOIN PICKDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey     --(Wan02)
          LEFT JOIN TASKDETAIL PND (NOLOCK) ON PICKDETAIL.Taskdetailkey = PND.Sourcekey AND PICKDETAIL.Storerkey = PND.Storerkey AND PICKDETAIL.Sku = PND.Sku AND PND.TaskType = 'RPT' --(Wan02)
           AND PND.Status <> 'X'
          WHERE WAVEDETAIL.Wavekey = @c_Wavekey
          AND PND.Taskdetailkey IS NULL
       OPEN cur_pick

       FETCH NEXT FROM cur_pick INTO @c_Pickdetailkey

       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
           UPDATE PICKDETAIL WITH (ROWLOCK)
           SET Taskdetailkey = '',
               Pickslipno = CASE WHEN @c_DocType <> 'E' THEN '' ELSE Pickslipno END,
               Notes = CASE WHEN @c_DocType <> 'E' THEN '' ELSE Notes END,
               Trafficcop = NULL
           WHERE Pickdetailkey = @c_PIckdetailkey

          SELECT @n_err = @@ERROR
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          END

          FETCH NEXT FROM cur_pick INTO @c_Pickdetailkey
       END
       CLOSE cur_pick
       DEALLOCATE cur_pick
    END

    -----Reverse wave status------
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       UPDATE WAVE
          --SET STATUS = '0' -- Normal          --(Wan01)
            SET TMReleaseFlag = 'N'             --(Wan01)
            ,  TrafficCop = NULL                --(Wan01)
            ,  EditWho = SUSER_SNAME()          --(Wan01)
            ,  EditDate= GETDATE()              --(Wan01)
       WHERE WAVEKEY = @c_wavekey
       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
       END
    END

RETURN_SP:

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV24"
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
 END --sp end

GO