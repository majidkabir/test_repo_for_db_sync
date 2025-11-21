SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRVWAV18                                          */  
/* Creation Date: 30-JUL-2018                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-5651 - CN Livi's B2B Reverse task                        */  
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.2                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2020-02-18  Wan01    1.1   WMS-12056 - [CN]Levis Exceed Release Wave(CR)*/
/* 01-04-2020  Wan02    1.2   Sync Exceed & SCE                          */  
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRVWAV18]      
      @c_wavekey      NVARCHAR(10)  
   ,  @c_Orderkey     NVARCHAR(10) = ''
   ,  @b_Success      int        OUTPUT  
   ,  @n_err          int        OUTPUT  
   ,  @c_errmsg       NVARCHAR(250)  OUTPUT  
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

   DECLARE @n_UCC_RowRef        INT          = 0         --(Wan01)
         , @c_UCCNo             NVARCHAR(20) = ''        --(Wan01)
         , @c_WaveType          NVARCHAR(10) = ''        --(Wan01)
         , @c_ReplenishmentKey  NVARCHAR(10) = ''        --(Wan01)  
         , @c_PickdetailKey     NVARCHAR(10) = ''        --(Wan01) 
         , @c_Loc               NVARCHAR(10) = ''        --(Wan01) 
         , @c_ID                NVARCHAR(18) = ''        --(Wan01)                  
         , @CUR_REPL            CURSOR                   --(Wan01)
         , @CUR_TASK            CURSOR                   --(Wan01)
         , @CUR_PICK            CURSOR                   --(Wan01)

   --(Wan01) - START
   SET @c_WaveType = ''
   SET @c_Storerkey= ''
   SELECT TOP 1 @c_WaveType = W.WaveType
         , @c_Storerkey = OH.Storerkey
   FROM WAVE W WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON W.Wavekey = WD.Wavekey
   JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
   WHERE W.Wavekey = @c_wavekey

   ----reject if wave not yet release      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_WaveType = 'B2B-P'
      BEGIN
         IF NOT EXISTS (SELECT 1
                        FROM REPLENISHMENT R WITH (NOLOCK)
                        WHERE R.Wavekey = @c_Wavekey
                        AND R.Storerkey = @c_Storerkey
                        )
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 81008  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not released for manual replenishment. (ispRVWAV18)' 
            GOTO RETURN_SP   
         END
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                     WHERE TD.Wavekey = @c_Wavekey
                     AND TD.Sourcetype IN ('ispRLWAV18') 
                     AND TD.Tasktype IN ('RPF')) 
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 81010  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV18)'    
         END 
      END
      --(Wan01) - END                              
   END

   ----reject if any task was started

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan01) - START
      IF @c_WaveType = 'B2B-P'
      BEGIN
         IF EXISTS (SELECT 1
                        FROM REPLENISHMENT R WITH (NOLOCK)
                        WHERE R.Wavekey = @c_Wavekey
                        AND R.Storerkey = @c_Storerkey
                        AND   R.Confirmed <> 'N'
                        )
         BEGIN
            SET @n_continue = 3  
            SET @n_err = 81018  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some replenishment have started. (ispRVWAV18)' 
            GOTO RETURN_SP   
         END
      END
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                     WHERE TD.Wavekey = @c_Wavekey
                     AND TD.Sourcetype IN ('ispRLWAV18')
                     AND TD.Status <> '0'
                     AND TD.Tasktype IN ('RPF'))
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 81020  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV18)'       
         END
      END     
      --(Wan01) - END     
   END
    
   BEGIN TRAN
                
   ----delete replenishment
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan01) - START
      IF @c_WaveType = 'B2B-P'
      BEGIN
         SET @CUR_REPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT R.Replenishmentkey
               ,R.Sku
               ,R.Lot
               ,R.FromLoc
               ,R.ID
         FROM REPLENISHMENT R (NOLOCK) 
         WHERE R.Wavekey = @c_Wavekey
         AND R.Storerkey = @c_Storerkey
         AND R.Confirmed = 'N'
         ORDER BY R.Replenishmentkey          

         OPEN @CUR_REPL 
          
         FETCH NEXT FROM @CUR_REPL INTO @c_Replenishmentkey, @c_Sku, @c_Lot, @c_Loc, @c_ID
          
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
            SET @n_UCC_RowRef = 0
            SELECT @n_UCC_RowRef = UCC_RowRef
            FROM UCC WITH (NOLOCK)
            WHERE Storerkey = @c_Storerkey 
            AND Sku = @c_Sku
            AND Lot = @c_Lot
            AND Loc = @c_Loc
            AND ID  = @c_ID 
            AND Userdefined10 = @c_Replenishmentkey

            IF @n_UCC_RowRef > 0
            BEGIN
               UPDATE UCC  
               SET Status = '1' 
                  ,userdefined10 = ''
               WHERE UCC_RowRef = @n_UCC_RowRef

               SELECT @n_err = @@ERROR
               IF @n_err <> 0 
               BEGIN
                  SET @n_continue = 3  
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 81025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispRVWAV18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END 
            END
             
            DELETE REPLENISHMENT 
            WHERE Replenishmentkey = @c_Replenishmentkey
            
            SET @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
               SET @n_continue = 3  
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81027   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Replenishment Table Failed. (ispRVWAV18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END 

            FETCH NEXT FROM @CUR_REPL INTO @c_Replenishmentkey, @c_Sku, @c_Lot, @c_Loc, @c_ID               
         END
         CLOSE @CUR_REPL
         DEALLOCATE @CUR_REPL
      END
      ELSE
      BEGIN 
         SET @CUR_TASK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TD.Taskdetailkey
         FROM TASKDETAIL TD WITH (NOLOCK)
         WHERE TD.Wavekey = @c_Wavekey 
         AND TD.Sourcetype IN ('ispRLWAV18')
         AND TD.Tasktype IN ('RPF') 
         ORDER BY TD.Taskdetailkey       

         OPEN @CUR_TASK
          
         FETCH NEXT FROM @CUR_TASK INTO @c_Taskdetailkey
          
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
            DELETE TASKDETAIL
            WHERE Taskdetailkey = @c_Taskdetailkey
            --WHERE TASKDETAIL.Wavekey = @c_Wavekey 
            --AND TASKDETAIL.Sourcetype IN ('ispRLWAV18')
            --AND TASKDETAIL.Tasktype IN ('RPF') 
       
            SELECT @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END

            FETCH NEXT FROM @CUR_TASK INTO @c_Taskdetailkey
         END
         CLOSE @CUR_TASK
         DEALLOCATE @CUR_TASK
      END  
      --(Wan01) - END           
   END

   ----Remove taskdetailkey from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan01) - START
      SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.Pickdetailkey, UCC.UccNo
      FROM PICKDETAIL PD (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey
      LEFT JOIN UCC (NOLOCK) ON PD.Lot = UCC.Lot AND PD.Loc = UCC.Loc AND PD.Id = UCC.Id AND UCC.UCCNo = PD.DropID      
      WHERE WD.Wavekey = @c_Wavekey
      ORDER BY PD.Pickdetailkey
         
      OPEN @CUR_PICK
          
      FETCH NEXT FROM @CUR_PICK INTO @c_Pickdetailkey, @c_UCCNo
          
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK) 
            SET PICKDETAIL.TaskdetailKey = ''
            ,  PICKDETAIL.DropID = CASE WHEN @c_UCCNo IS NOT NULL THEN '' ELSE PICKDETAIL.DropID END  
            ,  MoveRefKey = ''           
            ,  TrafficCop = NULL
         WHERE Pickdetailkey = @c_Pickdetailkey 
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END

         IF @c_UCCNo IS NOT NULL
         BEGIN
            SET @n_UCC_RowRef = 0
            SELECT @n_UCC_RowRef = UCC_RowRef
            FROM UCC WITH (NOLOCK)
            WHERE Storerkey = @c_Storerkey 
            AND UCCNo = @c_UCCNo

            IF @n_UCC_RowRef > 0
            BEGIN
               UPDATE UCC  
               SET [Status] = '1' 
               WHERE UCC_RowRef = @n_UCC_RowRef

               SELECT @n_err = @@ERROR
               IF @n_err <> 0 
               BEGIN
                  SET @n_continue = 3  
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 81045   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispRVWAV18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END 
            END
         END
         FETCH NEXT FROM @CUR_PICK INTO @c_Pickdetailkey, @c_UCCNo
      END
      CLOSE @CUR_PICK
      DEALLOCATE @CUR_PICK
      --(Wan01) - END
   END        
    
   -----Reverse wave status------
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE WAVE 
         --SET STATUS = '0' -- Normal        --(Wan02)   
         SET TMReleaseFlag = 'N'             --(Wan02) 
         ,  TrafficCop = NULL                --(Wan02) 
         ,  EditWho = SUSER_SNAME()          --(Wan02) 
         ,  EditDate= GETDATE()              --(Wan02) 
      WHERE WAVEKEY = @c_wavekey  
      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV18"  
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