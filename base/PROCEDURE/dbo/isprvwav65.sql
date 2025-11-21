SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Stored Procedure: ispRVWAV65                                             */
/* Creation Date: 15-Sep-2023                                               */
/* Copyright: Maersk                                                        */
/* Written by: WLChooi                                                      */
/*                                                                          */
/* Purpose: WMS-23615 - [AU] LEVIS RELEASE WAVE (REPLENISHMENT) CR - Reverse*/
/*                                                                          */
/* Called By: wave                                                          */
/*                                                                          */
/* PVCS Version: 1.0                                                        */
/*                                                                          */
/* Version: 7.0                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date        Author   Ver  Purposes                                       */
/* 15-Sep-2023 WLChooi  1.0  DevOps Combine Script                          */
/****************************************************************************/
CREATE   PROCEDURE [dbo].[ispRVWAV65]
   @c_Wavekey  NVARCHAR(10)
 , @c_Orderkey NVARCHAR(10) = ''
 , @b_Success  INT           OUTPUT
 , @n_err      INT           OUTPUT
 , @c_errmsg   NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue         INT
         , @n_starttcnt        INT
         , @n_debug            INT
         , @n_cnt              INT
         , @c_Replenishmentkey NVARCHAR(10)
         , @c_Pickdetailkey    NVARCHAR(10)
         , @c_DropID           NVARCHAR(20)
         , @c_authority        NVARCHAR(30)

   SELECT @n_starttcnt = @@TRANCOUNT
        , @n_continue = 1
        , @b_Success = 0
        , @n_err = 0
        , @c_errmsg = ''
        , @n_cnt = 0
   SELECT @n_debug = 0

   DECLARE @c_Storerkey NVARCHAR(15)
         , @c_facility  NVARCHAR(5)
         , @c_WaveType  NVARCHAR(10)

   SELECT TOP 1 @c_Storerkey = O.StorerKey
              , @c_facility = O.Facility
              , @c_WaveType = W.WaveType
   FROM WAVE W (NOLOCK)
   JOIN WAVEDETAIL WD (NOLOCK) ON W.WaveKey = WD.WaveKey
   JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey AND W.WaveKey = @c_Wavekey

   ----reject if wave not yet release   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF NOT EXISTS (  SELECT 1
                       FROM REPLENISHMENT RP (NOLOCK)
                       WHERE RP.Wavekey = @c_Wavekey AND RP.OriginalFromLoc = 'ispRLWAV65')
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81010
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Nothing to reverse. (ispRVWAV65)'
      END
   END

   ----reject if any task was started  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM REPLENISHMENT RP (NOLOCK)
                   WHERE RP.Wavekey = @c_Wavekey AND RP.OriginalFromLoc = 'ispRLWAV65' AND RP.Confirmed <> 'N')
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 81020
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + ': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV65)'
      END
   END

   BEGIN TRAN

   ----delete replenishment for 1=DPP picking
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      DECLARE CUR_REPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ReplenishmentKey
           , RefNo --DropID
      FROM REPLENISHMENT (NOLOCK)
      WHERE Wavekey = @c_Wavekey AND OriginalFromLoc = 'ispRLWAV65' AND Confirmed = 'N'

      OPEN CUR_REPL

      FETCH NEXT FROM CUR_REPL
      INTO @c_Replenishmentkey
         , @c_DropID

      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN ( 1, 2 )
      BEGIN
         DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON WD.OrderKey = PD.OrderKey
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         WHERE WD.WaveKey = @c_Wavekey AND PD.DropID = @c_DropID AND PD.DropID <> '' AND PD.DropID IS NOT NULL

         OPEN CUR_PICK

         FETCH NEXT FROM CUR_PICK
         INTO @c_Pickdetailkey

         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN ( 1, 2 )
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET ToLoc = ''
              , TrafficCop = NULL
            WHERE PickDetailKey = @c_Pickdetailkey

            SELECT @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                    , @n_err = 81030 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                                  + ': Update Pickdetail Table Failed. Pickdetailkey:' + RTRIM(@c_Pickdetailkey)
                                  + ' (ispRVWAV65)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END

            FETCH NEXT FROM CUR_PICK
            INTO @c_Pickdetailkey
         END
         CLOSE CUR_PICK
         DEALLOCATE CUR_PICK

         DELETE FROM REPLENISHMENT
         WHERE ReplenishmentKey = @c_Replenishmentkey

         SELECT @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
                 , @n_err = 81040 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + ': Delete Replenishment Table Failed. (ispRVWAV65)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_errmsg) + ' ) '
         END

         FETCH NEXT FROM CUR_REPL
         INTO @c_Replenishmentkey
            , @c_DropID
      END
      CLOSE CUR_REPL
      DEALLOCATE CUR_REPL
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      DELETE PackTask
      FROM PackTask (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON PackTask.TaskBatchNo = WD.WaveKey AND PackTask.Orderkey = WD.OrderKey
      WHERE WD.WaveKey = @c_Wavekey

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 81070 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Delete PACKTASK Table Failed. (ispRVWAV65)'
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      END
   END

   -----Reverse wave status------  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE WAVE
      SET TMReleaseFlag = 'N'
        , TrafficCop = NULL
        , EditWho = SUSER_SNAME()
        , EditDate = GETDATE()
      WHERE WaveKey = @c_Wavekey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250), @n_err)
              , @n_err = 81080 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_err) + ': Update on wave Failed (ispRVWAV65)' + ' ( '
                            + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      END
   END

   -----Reverse SOStatus---------  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXECUTE nspGetRight @c_facility
                        , @c_Storerkey
                        , '' --sku  
                        , 'UpdateSOReleaseTaskStatus' -- Configkey  
                        , @b_Success OUTPUT
                        , @c_authority OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

      IF @b_Success = 1 AND @c_authority = '1'
      BEGIN
         UPDATE ORDERS WITH (ROWLOCK)
         SET SOStatus = '0'
           , TrafficCop = NULL
           , EditWho = SUSER_SNAME()
           , EditDate = GETDATE()
         WHERE UserDefine09 = @c_Wavekey AND SOStatus = 'TSRELEASED'
      END
   END

   RETURN_SP:

   IF @n_continue = 3 -- Error Occured - Process And Return    
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRVWAV65'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END --sp end  

GO