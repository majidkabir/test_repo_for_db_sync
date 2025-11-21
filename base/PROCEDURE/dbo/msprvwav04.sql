SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
      
/*************************************************************************/          
/* Stored Procedure: mspRVWAV04                                          */      
/* Creation Date: 2024-10-31                                             */      
/* Copyright: Maersk                                                     */      
/* Written by: USH022                                                    */      
/*                                                                       */      
/* Purpose: UWP-24680 - HUSQ Reverse Wave Release                        */      
/*                                                                       */      
/*                                                                       */      
/* Called By: Reverse Wave Release                                       */      
/*                                                                       */      
/* PVCS Version: 1.0                                                     */      
/*                                                                       */      
/* Version: 7.0                                                          */      
/*                                                                       */      
/* Data Modifications:                                                   */      
/*                                                                       */      
/* Updates:                                                              */      
/* Date        Author   Ver   Purposes                                   */      
/*************************************************************************/      
CREATE      PROCEDURE [dbo].[mspRVWAV04]      
 @c_wavekey      NVARCHAR(10)      
,@c_Orderkey     NVARCHAR(10) = ''      
,@b_Success      int             OUTPUT      
,@n_err          int             OUTPUT      
,@c_errmsg       NVARCHAR(250)   OUTPUT      
AS      
BEGIN      
  SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @n_continue       int = 1      
         , @n_starttcnt      int = @@TRANCOUNT        -- Holds the current transaction count      
         , @n_debug          int = 0      
         , @n_cnt            INT = 0      
         , @c_otherwavekey   NVARCHAR(10) = ''      
         , @c_TaskType       NVARCHAR(10) = ''      
         , @n_AllowToRev     INT          = 0      
         , @c_Storerkey      NVARCHAR(15) = ''      
         , @c_facility       NVARCHAR(5)  = ''      
         , @c_Taskdetailkey  NVARCHAR(10) = ''      
         , @c_PickDetailKey  NVARCHAR(10) = ''      
         , @c_authority      NVARCHAR(10) = ''      
         , @c_SourceType     NVARCHAR(30) = 'mspRLWAV04'      
         , @c_OrderLineNumber NVARCHAR(20) = ''      
         , @c_PickHeaderKey   NVARCHAR(20) = ''      
         , @c_LoadKey NVARCHAR(20) = ''      
         , @CUR_DELTASK      CURSOR      
         , @CUR_DELPICK      CURSOR      
         , @CUR_DELPICKHEADER CURSOR      
      
   SET @b_success=0      
   SET @n_err=0      
   SET @c_errmsg=''      
   SET @n_cnt=0      
      
   -----Get Storerkey and facility      
   SELECT TOP 1 @c_StorerKey = O.Storerkey,      
               @c_Facility = O.Facility      
   FROM WAVEDETAIL WD (NOLOCK)      
   JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)      
   WHERE WD.Wavekey = @c_Wavekey      
      
   ----reject if wave not yet release      
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN      
      IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)      
                     WHERE TD.Wavekey = @c_Wavekey AND TD.SourceType = @c_SourceType)      
      BEGIN      
	  PRINT 'line validation-1'
         SET @n_continue = 3      
         SET @n_err = 85080      
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err)))+': This Wave has not been released. (mspRVWAV04)'      
      END      
   END      
      
   ----reject if any task was started      
      IF @n_continue = 1 OR @n_continue = 2      
      BEGIN      
       IF EXISTS (      
          SELECT TOP 1 TD.TaskType FROM Taskdetail TD (NOLOCK)      
          WHERE TD.Wavekey = @c_Wavekey      
          AND  TD.Sourcetype = @c_SourceType      
          AND  TD.TaskType IN('FPK', 'ASTCPK')      
          AND  TD.[Status] NOT IN ('0', 'S', 'X')      
          ORDER BY 1 DESC      
         )      
         BEGIN      
            SET @n_continue = 3      
             SET @n_err = 85090      
             SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (mspRVWAV04)'      
         END      
      END      
      
  BEGIN TRAN      
   ----delete tasks      
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN      
      SET @CUR_DELTASK = CURSOR FAST_FORWARD READ_ONLY FOR      
      SELECT TD.TaskDetailKey, TD.PickDetailKey      
      FROM TASKDETAIL TD (NOLOCK)      
      WHERE TD.Wavekey = @c_Wavekey      
      AND  TD.Sourcetype = @c_SourceType      
      AND  TD.TaskType IN ('FPK', 'ASTCPK')      
      AND  TD.[Status] IN ('0', 'S')      
      ORDER BY 1 DESC      
      
      OPEN @CUR_DELTASK      
      
      FETCH NEXT FROM @CUR_DELTASK INTO @c_TaskDetailKey, @c_PickDetailKey      
      
      WHILE @@FETCH_STATUS = 0 AND @c_TaskDetailKey <> '' AND @n_Continue = 1      
      BEGIN      
        -- Updating the PICKDETAIL      
         UPDATE PICKDETAIL WITH (ROWLOCK)      
         SET PICKDETAIL.TaskdetailKey = ''      
         ,PICKDETAIL.PickSlipNo = ''      
         ,TrafficCop = NULL      
         WHERE PICKDETAIL.PickDetailKey = @c_PickDetailKey      
      
         -- Deleting RefKeyLookup record      
         DELETE RefKeyLookup WITH (ROWLOCK)      
         WHERE RefKeyLookup.PickDetailkey = @c_PickDetailkey      
      
         DELETE TASKDETAIL WITH (ROWLOCK)      
         WHERE TASKDETAIL.TaskDetailKey = @c_TaskDetailKey      
         AND TASKDETAIL.Sourcetype = @c_SourceType      
         AND TASKDETAIL.TaskType IN ('FPK', 'ASTCPK')      
         AND TASKDETAIL.Status IN ('0','S')      
      
         SET @n_err = @@ERROR      
         IF @n_err <> 0      
         BEGIN      
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)      
            SET @n_err = 85100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err)))+': Delete Taskdetail Table Failed. (mspRVWAV04)'      
            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
         END      
         FETCH NEXT FROM @CUR_DELTASK INTO @c_TaskDetailKey, @c_PickDetailKey      
      END      
      CLOSE @CUR_DELTASK      
      DEALLOCATE @CUR_DELTASK      
   END      
      
   -----Reverse wave status------      
   IF @n_continue = 1 or @n_continue = 2      
   BEGIN      
      UPDATE WAVE      
         SET TMReleaseFlag = 'N'      
          ,  TrafficCop = NULL      
          ,  EditWho = SUSER_SNAME()      
          ,  EditDate= GETDATE()      
      WHERE WAVEKEY = @c_wavekey      
      SELECT @n_err = @@ERROR      
      IF @n_err <> 0      
      BEGIN      
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)      
         SET @n_err = 85120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+LTRIM(RTRIM(CONVERT(NVARCHAR(5),@n_err)))+': Update on wave Failed (mspRVWAV04)'      
         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
      END      
   END      
      
RETURN_SP:      
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_success = 0      
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
      execute nsp_logerror @n_err, @c_errmsg, "mspRVWAV04"      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
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