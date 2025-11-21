SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: ispRVWAV02                                          */
/* Creation Date: 01-Nov-2013                                            */
/* Copyright: IDS                                                        */
/* Written by: YYWan                                                     */
/*                                                                       */
/* Purpose: SOS#293386 Release Pick Task                                 */
/*                                                                       */
/* Called By: wave                                                       */
/*                                                                       */
/* PVCS Version: 1.5                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */
/* 04-AUG-2014 YTWan    1.1   SOS#313850 - Wave Enhancement - Delete     */
/*                            Orders. (Wan01)                            */
/* 07-NOV-2014 SPChin   1.2   SOS324703 - Bug Fixed                      */
/* 20-Jan-2015 Leong    1.3   SOS# 328962 - Revise logic on delete task. */
/* 24-Apr-2019 TLTING01 1.4   Deadlock Tune                              */
/* 01-04-2020  Wan02    1.5   Sync Exceed & SCE                          */
/*************************************************************************/

CREATE PROCEDURE [dbo].[ispRVWAV02]
       @c_wavekey      NVARCHAR(10)
      ,@c_Orderkey     NVARCHAR(10) = ''  --(Wan01)
      ,@b_Success      int        OUTPUT
      ,@n_err          int        OUTPUT
      ,@c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  int
         , @n_starttcnt int         -- Holds the current transaction count
         , @n_debug     int
         , @n_cnt       int


   DECLARE @c_Storerkey      NVARCHAR(15)
         , @c_Sku            NVARCHAR(20)
         , @c_Lot            NVARCHAR(10)
         , @c_ToLoc          NVARCHAR(10)
         , @c_ToID           NVARCHAR(18)
         , @n_Qty            INT
         , @c_Taskdetailkey  NVARCHAR(10)
         , @c_Loadkey        NVARCHAR(10)   --(Wan01)
         , @c_PickSlipNo     NVARCHAR(10)   --(Wan01)
         , @c_Transmitflag   NVARCHAR(10)   --(Wan01)
         , @c_Pickdetailkey   Nvarchar(10)

   SET @n_starttcnt=@@TRANCOUNT
   SET @n_continue=1
   SET @b_success=0
   SET @n_err=0
   SET @c_errmsg=''
   SET @n_cnt=0
   SET @n_debug = 0

    ----reject if wave not yet release

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   --(Wan01) - START
   -- 1) Task Released but Sort & pack RDT module to Pick Confirm, 2) Manual Pick Confirm
   IF RTRIM(@c_Orderkey) <> '' AND @c_Orderkey IS NOT NULL
   BEGIN
      SET @c_Transmitflag = '0'
      SELECT @c_Transmitflag =  ISNULL(MAX(TL3.Transmitflag),'0')
      FROM TRANSMITLOG3 TL3  WITH (NOLOCK)
      JOIN ORDERS       OH   WITH (NOLOCK) ON (TL3.Key1 = OH.Orderkey)
                                           AND(TL3.Key3 = OH.Storerkey)
      WHERE TL3.TABLENAME = 'PICKCFMLOG'
      AND   OH.Orderkey = @c_Orderkey

      IF @c_Transmitflag <> '0'
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81005
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PICKCFGLOG is being / had processed. (ispRVWAV02)' --(Wan01)
         GOTO RETURN_SP
      END


      IF EXISTS ( SELECT 1
                  FROM PICKDETAIL WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND Status > 0 )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81006
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders is picked/ pick in progress. (ispRVWAV02)'
         GOTO RETURN_SP
      END

      SET @c_Loadkey = ''
      SELECT @c_Loadkey = Loadkey FROM LOADPLANDETAIL WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey

      --SOS324703 Start
      SET @c_StorerKey = ''
      SELECT TOP 1 @c_StorerKey = StorerKey FROM ORDERS WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey

      --IF EXISTS ( SELECT 1
      --            FROM PACKHEADER WITH (NOLOCK)
      --            WHERE (Loadkey = @c_Loadkey OR Orderkey = @c_Orderkey)
      --          )
      IF EXISTS ( SELECT 1
                  FROM PACKHEADER WITH (NOLOCK)
                  WHERE StorerKey = @c_StorerKey
                  AND ( ( LoadKey = @c_Loadkey AND ISNULL(RTRIM(LoadKey),'') <> '' AND ISNULL(RTRIM(OrderKey),'') = '')
                          OR (OrderKey = @c_Orderkey AND ISNULL(RTRIM(OrderKey),'') <> '') )
                )
      --SOS324703 End
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81007
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders is packing/packed. (ispRVWAV02)'
         GOTO RETURN_SP
      END
   END
   --(Wan01) - END

   IF NOT EXISTS (  SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK)
                    WHERE TD.Wavekey = @c_Wavekey
                    AND TD.Sourcetype IN('ispRLWAV02-RETAIL','ispRLWAV02-ECOM')
                    AND TD.Tasktype IN ('RPF', 'SPK', 'PK')
                    AND EXISTS ( SELECT 1 FROM PICKDETAIL WITH (NOLOCK)                               --(Wan01)
                                 WHERE TaskDetailKey = TD.TaskDetailKey                               --(Wan01)
                                 AND   Orderkey = CASE WHEN @c_Orderkey = '' OR @c_Orderkey IS NULL   --(Wan01)
                                                       THEN PICKDETAIL.Orderkey ELSE @c_Orderkey END )--(Wan01)
                  )
   BEGIN
      --(Wan01) - START
      IF RTRIM(@c_Orderkey) = '' OR @c_Orderkey IS NULL
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81010
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave/SO has not been released. (ispRVWAV02)' --(Wan01)
         GOTO RETURN_SP
      END
      --(Wan01) - END
   END

   ----reject if any task was started

   IF EXISTS ( SELECT 1 FROM TASKDETAIL TD (NOLOCK)
               WHERE TD.Wavekey = @c_Wavekey
               AND TD.Sourcetype IN('ispRLWAV02-RETAIL','ispRLWAV02-ECOM')
               AND TD.Status <> '0'
               AND TD.Tasktype IN ('RPF', 'SPK', 'PK')
               AND EXISTS ( SELECT 1 FROM PICKDETAIL WITH (NOLOCK)                               --(Wan01)
                            WHERE TaskDetailKey = TD.TaskDetailKey                               --(Wan01)
                            AND   Orderkey = CASE WHEN @c_Orderkey = '' OR @c_Orderkey IS NULL   --(Wan01)
                                                  THEN PICKDETAIL.Orderkey ELSE @c_Orderkey END )--(Wan01)
             )
   BEGIN
      --(Wan01) - START
      IF RTRIM(@c_Orderkey) = '' OR @c_Orderkey IS NULL
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81020
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)
                      +': Some Tasks have been started. Not allow to Reverse Wave/SO Released (ispRVWAV02)' --(Wan01)
         GOTO RETURN_SP
      END
      --(Wan01) - END
   END

   BEGIN TRAN

   ----delete replenishment pick tasks
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE TASKDETAIL WITH (ROWLOCK)
      WHERE TASKDETAIL.Wavekey = @c_Wavekey
      AND TASKDETAIL.Sourcetype IN ('ispRLWAV02-RETAIL','ispRLWAV02-ECOM')
      AND TASKDETAIL.Tasktype IN ('RPF', 'SPK', 'PK')
      AND EXISTS ( SELECT 1 FROM PICKDETAIL WITH (NOLOCK)                                    --(Wan01)
                   WHERE TaskDetailKey = TASKDETAIL.TaskDetailKey                            --(Wan01)
                   AND   Orderkey = CASE WHEN RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL --(Wan01)
                                         THEN PICKDETAIL.Orderkey ELSE @c_Orderkey END       --(Wan01)
                 )
      --AND TASKDETAIL.Status = '0'                                                            --(Wan01)
      AND TASKDETAIL.Status <> '9' -- SOS# 328962

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END
   END

   ----Remove taskdetailkey from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   -- tlting01
      IF RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL
      BEGIN
         DECLARE PickItem_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PICKDETAIL.Pickdetailkey
         FROM WAVEDETAIL WITH (NOLOCK)
         JOIN PICKDETAIL WITH (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey
          
      END 
      ELSE
      BEGIN
         DECLARE PickItem_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PICKDETAIL.Pickdetailkey
         FROM WAVEDETAIL WITH (NOLOCK)
         JOIN PICKDETAIL WITH (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
         AND WAVEDETAIL.Orderkey = @c_Orderkey  -- tlting01

      END


      OPEN PickItem_cur 
      FETCH NEXT FROM PickItem_cur INTO @c_Pickdetailkey 
      WHILE @@FETCH_STATUS = 0 
      BEGIN 

         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET PICKDETAIL.TaskdetailKey = ''
         ,TrafficCop = NULL
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
         Where Pickdetailkey = @c_Pickdetailkey
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END      
         FETCH NEXT FROM PickItem_cur INTO @c_Pickdetailkey
      END
      CLOSE PickItem_cur 
      DEALLOCATE PickItem_cur

   END

   --Delete PickingInfo
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan01) - START

      IF RTRIM(@c_Orderkey) <> '' AND @c_Orderkey IS NOT NULL
      BEGIN
         SET @c_PickSlipNo = ''
         SELECT @c_PickSlipNo = PickSlipNo FROM PICKDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey

         IF EXISTS ( SELECT 1 FROM PICKDETAIL WITH (NOLOCK)
                     WHERE PickSlipNo = @c_PickSlipNo
                     AND PickSlipNo <> '' AND PickSlipNo IS NOT NULL
                     GROUP BY PickSlipNo
                     HAVING COUNT(DISTINCT Orderkey) > 1 )
         BEGIN
            GOTO DEL_REFKEYLOOKUP
         END
      END
      --(Wan01) - END

      IF RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL
      BEGIN
         -- TLTING01
         -- Remove PickingInfo that Create at Release Wave - Both Retail & DTC
         DELETE PICKINGINFO WITH (ROWLOCK)
         FROM WAVEDETAIL  WITH (NOLOCK)
         JOIN PICKDETAIL  WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey)
         JOIN PICKINGINFO               ON (PICKDETAIL.PickSlipNo = PICKINGINFO.PickSlipNo)
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey

      END
      ELSE
      BEGIN
         -- Remove PickingInfo that Create at Release Wave - Both Retail & DTC
         DELETE PICKINGINFO WITH (ROWLOCK)
         FROM WAVEDETAIL  WITH (NOLOCK)
         JOIN PICKDETAIL  WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey)
         JOIN PICKINGINFO               ON (PICKDETAIL.PickSlipNo = PICKINGINFO.PickSlipNo)
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey
         AND   PICKDETAIL.Orderkey = @c_Orderkey 
      END      
      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PickingInfo Table Failed. (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END

      ----(Wan01) - START
      -- Remove PickHeader that Create at Print Conso Pickslip At Wave Screen
      IF RTRIM(@c_Orderkey) <> '' AND @c_Orderkey IS NOT NULL
      BEGIN
         DELETE PICKHEADER WITH (ROWLOCK)
         FROM PICKHEADER PH
         JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PH.Wavekey = WD.Wavekey)
         JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey)
                                          AND(PH.ExternOrderkey = OH.Loadkey)
         WHERE WD.Wavekey = @c_Wavekey
         AND   WD.Orderkey = @c_Orderkey
         AND   Zone IN ( 'LP', '7')

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81051   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickheader Table Failed. (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END

         -- CN DTC Discrete PickslipNo - Dynamic Pick Process
         DELETE FROM PICKHEADER WITH (ROWLOCK)
         WHERE Orderkey = @c_Orderkey
         AND   RTRIM(Orderkey) <> '' AND Orderkey IS NOT NULL
         --AND   Zone IN ('7', '8')

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81052   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickheader Table Failed. (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END
      END

      DEL_REFKEYLOOKUP:
      --(Wan01) - END

      IF EXISTS ( SELECT 1 FROM REFKEYLOOKUP RFLK
                  JOIN WAVEDETAIL WD WITH (NOLOCK) ON (RFLK.Orderkey = WD.Orderkey)
                  WHERE WD.Wavekey = @c_Wavekey
                  AND WD.Orderkey = CASE WHEN RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL --(Wan01)
                                         THEN WD.Orderkey ELSE @c_Orderkey END               --(Wan01)

                )
      BEGIN
         DELETE RFLK WITH (ROWLOCK) FROM REFKEYLOOKUP RFLK
         JOIN WAVEDETAIL WD WITH (NOLOCK) ON (RFLK.Orderkey = WD.Orderkey)
         WHERE WD.Wavekey = @c_Wavekey
         AND WD.Orderkey = CASE WHEN RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL          --(Wan01)
                                THEN WD.Orderkey ELSE @c_Orderkey END                        --(Wan01)
      END

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete RefKeyLookUp Table Failed. (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END
   END

   -----Reverse wave status------
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      --(Wan01) - START
      IF RTRIM(@c_Orderkey) <> '' AND @c_Orderkey IS NOT NULL
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM TASKDETAIL TD  WITH (NOLOCK)
                     JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TD.Taskdetailkey = PD.Taskdetailkey)
                     WHERE TD.Wavekey = @c_Wavekey )
         BEGIN
            GOTO DEL_ORDERS
         END
      END
      --(Wan01) - END

      UPDATE WAVE
       --SET STATUS = '0' -- Normal          --(Wan02)
       --          ,EditWho = SUSER_NAME()   --(Wan02)
       SET TMReleaseFlag = 'N'               --(Wan02) 
        ,  TrafficCop = NULL                 --(Wan02) 
        ,  EditWho = SUSER_SNAME()           --(Wan02)
				,  EditDate= GETDATE()
 
      WHERE WAVEKEY = @c_wavekey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END
   END


   --(Wan01) - Unallocation  (START)
   DEL_ORDERS:
   IF RTRIM(@c_Orderkey) <> '' AND @c_Orderkey IS NOT NULL
   BEGIN
      DELETE FROM TRANSMITLOG3 WITH (ROWLOCK)
      FROM TRANSMITLOG3 TL3
      JOIN ORDERS       OH   WITH (NOLOCK) ON (TL3.Key1 = OH.Orderkey)
                                           AND(TL3.Key3 = OH.Storerkey)
      WHERE TL3.TABLENAME = 'PICKCFMLOG'
      AND   TL3.TransmitFlag = '0'
      AND   OH.Orderkey = @c_Orderkey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81075   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete TRANSMITLOG3 Failed (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END

      DELETE FROM PICKDETAIL WITH (ROWLOCK)
      WHERE Orderkey = @c_Orderkey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unallocate Orders Failed (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END

      DELETE FROM LOADPLANDETAIL WITH (ROWLOCK)
      WHERE Orderkey = @c_Orderkey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81085   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Remove Orders from LOADPLANDETAIL Failed (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END

      DELETE FROM WAVEDETAIL WITH (ROWLOCK)
      WHERE Orderkey = @c_Orderkey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Remove Orders from WAVEDETAIL Failed (ispRVWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END
   END
   --(Wan01) - Unallocation  (END)

RETURN_SP:
   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV02"
--      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
 END --sp end

GO