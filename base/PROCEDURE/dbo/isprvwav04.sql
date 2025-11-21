SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: ispRVWAV04                                          */
/* Creation Date: 11-Jan-2016                                            */
/* Copyright: LF                                                         */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: SOS#358768 - LULU HK Reverse Released Pick Task              */
/*                                                                       */
/* Called By: wave                                                       */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */ 
/* 01-04-2020  Wan01    1.1   Sync Exceed & SCE                          */
/*************************************************************************/

CREATE PROCEDURE [dbo].[ispRVWAV04]
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

   DECLARE @n_continue  int
         , @n_starttcnt int         -- Holds the current transaction count
         , @n_debug     int
         , @n_cnt       int


   DECLARE @c_Storerkey      NVARCHAR(15)
         , @c_Taskdetailkey  NVARCHAR(10)
         , @c_Loadkey        NVARCHAR(10)   
         , @c_PickSlipNo     NVARCHAR(10)   
         , @c_Transmitflag   NVARCHAR(10)   

   SET @n_starttcnt=@@TRANCOUNT
   SET @n_continue=1
   SET @b_success=0
   SET @n_err=0
   SET @c_errmsg=''
   SET @n_cnt=0
   SET @n_debug = 0

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

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
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PICKCFGLOG is being / had processed. (ispRVWAV04)' 
         GOTO RETURN_SP
      END


      IF EXISTS ( SELECT 1
                  FROM PICKDETAIL WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND Status > 0 )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81006
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders is picked/ pick in progress. (ispRVWAV04)'
         GOTO RETURN_SP
      END

      SET @c_Loadkey = ''
      SELECT @c_Loadkey = Loadkey FROM LOADPLANDETAIL WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey

      SET @c_StorerKey = ''
      SELECT TOP 1 @c_StorerKey = StorerKey FROM ORDERS WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey

      IF EXISTS ( SELECT 1
                  FROM PACKHEADER WITH (NOLOCK)
                  WHERE StorerKey = @c_StorerKey
                  AND ( ( LoadKey = @c_Loadkey AND ISNULL(RTRIM(LoadKey),'') <> '' AND ISNULL(RTRIM(OrderKey),'') = '')
                          OR (OrderKey = @c_Orderkey AND ISNULL(RTRIM(OrderKey),'') <> '') )
                )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81007
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders is packing/packed. (ispRVWAV04)'
         GOTO RETURN_SP
      END
   END

   IF NOT EXISTS (  SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK)
                    WHERE TD.Wavekey = @c_Wavekey
                    AND TD.Sourcetype IN('ispRLWAV04-RETAIL','ispRLWAV04-ECOM')
                    AND TD.Tasktype IN ('SPK', 'PK')
                    AND EXISTS ( SELECT 1 FROM PICKDETAIL WITH (NOLOCK)                               
                                 WHERE TaskDetailKey = TD.TaskDetailKey                               
                                 AND   Orderkey = CASE WHEN @c_Orderkey = '' OR @c_Orderkey IS NULL   
                                                       THEN PICKDETAIL.Orderkey ELSE @c_Orderkey END )
                  )
   BEGIN
      IF RTRIM(@c_Orderkey) = '' OR @c_Orderkey IS NULL
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81010
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave/SO has not been released. (ispRVWAV04)'
         GOTO RETURN_SP
      END
   END

   IF EXISTS ( SELECT 1 FROM TASKDETAIL TD (NOLOCK)
               WHERE TD.Wavekey = @c_Wavekey
               AND TD.Sourcetype IN('ispRLWAV04-RETAIL','ispRLWAV04-ECOM')
               AND TD.Status NOT IN('0','N')
               AND TD.Tasktype IN ('SPK', 'PK')
               AND EXISTS ( SELECT 1 FROM PICKDETAIL WITH (NOLOCK)                               
                            WHERE TaskDetailKey = TD.TaskDetailKey                               
                            AND   Orderkey = CASE WHEN @c_Orderkey = '' OR @c_Orderkey IS NULL   
                                                  THEN PICKDETAIL.Orderkey ELSE @c_Orderkey END )
             )
   BEGIN
      IF RTRIM(@c_Orderkey) = '' OR @c_Orderkey IS NULL
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81020
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)
                      +': Some Tasks have been started. Not allow to Reverse Wave/SO Released (ispRVWAV04)' 
         GOTO RETURN_SP
      END
   END

   BEGIN TRAN

   ----delete replenishment pick tasks
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE TASKDETAIL WITH (ROWLOCK)
      WHERE TASKDETAIL.Wavekey = @c_Wavekey
      AND TASKDETAIL.Sourcetype IN ('ispRLWAV04-RETAIL','ispRLWAV04-ECOM')
      AND TASKDETAIL.Tasktype IN ('SPK', 'PK')
      AND EXISTS ( SELECT 1 FROM PICKDETAIL WITH (NOLOCK)                                    
                   WHERE TaskDetailKey = TASKDETAIL.TaskDetailKey                            
                   AND   Orderkey = CASE WHEN RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL 
                                         THEN PICKDETAIL.Orderkey ELSE @c_Orderkey END       
                 )
      AND TASKDETAIL.Status <> '9' 

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END
   END

   ----Remove taskdetailkey from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET PICKDETAIL.TaskdetailKey = ''
         ,TrafficCop = NULL
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
      FROM WAVEDETAIL WITH (NOLOCK)
      JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey
      AND WAVEDETAIL.Orderkey = CASE WHEN RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL    
                                     THEN WAVEDETAIL.Orderkey ELSE @c_Orderkey END          

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END
   END

   --Delete PickingInfo
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
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

      -- Remove PickingInfo that Create at Release Wave - Both Retail & ECOM
      DELETE PICKINGINFO WITH (ROWLOCK)
      FROM WAVEDETAIL  WITH (NOLOCK)
      JOIN PICKDETAIL  WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey)
      JOIN PICKINGINFO               ON (PICKDETAIL.PickSlipNo = PICKINGINFO.PickSlipNo)
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey
      AND   WAVEDETAIL.Orderkey = CASE WHEN RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL   
                                       THEN WAVEDETAIL.Orderkey ELSE @c_Orderkey END         

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PickingInfo Table Failed. (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END

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
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickheader Table Failed. (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END

         -- Discrete PickslipNo - Dynamic Pick Process
         DELETE FROM PICKHEADER WITH (ROWLOCK)
         WHERE Orderkey = @c_Orderkey
         AND   RTRIM(Orderkey) <> '' AND Orderkey IS NOT NULL
         --AND   Zone IN ('7', '8')

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81052   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickheader Table Failed. (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END
      END

      DEL_REFKEYLOOKUP:

      IF EXISTS ( SELECT 1 FROM REFKEYLOOKUP RFLK
                  JOIN WAVEDETAIL WD WITH (NOLOCK) ON (RFLK.Orderkey = WD.Orderkey)
                  WHERE WD.Wavekey = @c_Wavekey
                  AND WD.Orderkey = CASE WHEN RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL 
                                         THEN WD.Orderkey ELSE @c_Orderkey END               

                )
      BEGIN
         DELETE RFLK WITH (ROWLOCK) FROM REFKEYLOOKUP RFLK
         JOIN WAVEDETAIL WD WITH (NOLOCK) ON (RFLK.Orderkey = WD.Orderkey)
         WHERE WD.Wavekey = @c_Wavekey
         AND WD.Orderkey = CASE WHEN RTRIM(@c_Orderkey) = '' OR @c_ORderkey IS NULL          
                                THEN WD.Orderkey ELSE @c_Orderkey END                        
      END

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete RefKeyLookUp Table Failed. (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END
   END

   -----Reverse wave status------
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
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

      UPDATE WAVE
          --SET STATUS = '0' -- Normal          --(Wan01)
          --   ,EditWho = SUSER_NAME()          --(Wan01)
          SET TMReleaseFlag = 'N'               --(Wan01) 
           ,  TrafficCop = NULL                 --(Wan01) 
           ,  EditWho = SUSER_SNAME()           --(Wan01)
           ,  EditDate= GETDATE()               
      WHERE WAVEKEY = @c_wavekey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END
   END

   --Unallocation  
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
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete TRANSMITLOG3 Failed (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
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
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unallocate Orders Failed (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
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
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Remove Orders from LOADPLANDETAIL Failed (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
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
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Remove Orders from WAVEDETAIL Failed (ispRVWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END
   END

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
      execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV04"
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