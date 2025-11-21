SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRVWAV00                                          */  
/* Creation Date: 02-Jul-2014                                            */  
/* Copyright: LF                                                         */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: SOS#313157 - Reverse Task Relased By Wave (Standard)         */            
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.3                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 04-AUG-2014  YTWan    1.1  SOS#313850-Passin orderkey parameter (Wan01)*/
/* 31-OCT-2016  Shong    1.2  WMS-249 - Replenishment enhancements       */
/* 01-APR-2020  Wan02    1.3  Sync Exceed & SCE                          */
/*************************************************************************/   
CREATE PROCEDURE [dbo].[ispRVWAV00]      
@c_wavekey      NVARCHAR(10)  
,@c_Orderkey     NVARCHAR(10) = ''                 --(Wan01)
,@b_Success      int        OUTPUT  
,@n_err          int        OUTPUT  
,@c_errmsg       NVARCHAR(250)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE      @n_continue int,    
                @n_starttcnt int,         -- Holds the current transaction count  
                @n_debug int,
                @n_cnt int
                
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
   SELECT @n_debug = 0

   DECLARE @c_Storerkey NVARCHAR(15)
        ,@c_Sku NVARCHAR(20)
        ,@c_Lot NVARCHAR(10)
        ,@c_ToLoc NVARCHAR(10)
        ,@c_ToID NVARCHAR(18)
        ,@n_Qty INT
        ,@c_Taskdetailkey NVARCHAR(10)
        ,@c_facility NVARCHAR(5)  
        ,@c_authority NVARCHAR(10)

   SELECT TOP 1 @c_StorerKey = O.Storerkey,
              @c_Facility = O.Facility 
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey  

   ----reject if wave not yet release      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                WHERE TD.Wavekey = @c_Wavekey AND (TD.SourceType LIKE 'ispRLWAV%' OR TD.SourceType LIKE 'ispWRTSK%'))
     BEGIN
       SELECT @n_continue = 3  
       SELECT @n_err = 81010  
       SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV00)'         
     END                 
   END

   ----reject if any task was started
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
     IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                WHERE TD.Wavekey = @c_Wavekey
                AND (TD.Sourcetype LIKE 'ispRLWAV%' OR TD.SourceType LIKE 'ispWRTSK%')
                AND TD.Status <> '0')
     BEGIN
       SELECT @n_continue = 3  
       SELECT @n_err = 81020  
       SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV00)'       
     END                 
   END

   BEGIN TRAN

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
    DECLARE @c_FromLoc nvarchar(10)
          , @c_FromID  nvarchar(18) 
            
    
    DECLARE CUR_REPLENTASKS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    SELECT TD.Lot, TD.FromLoc, TD.FromID, TD.Qty
    FROM TaskDetail TD WITH (NOLOCK) 
    WHERE TD.Wavekey = @c_Wavekey 
      AND (TD.Sourcetype LIKE 'ispRLWAV%' OR TD.SourceType LIKE 'ispWRTSK%')
      AND TD.[Status] IN ('0','1','2','3') 
      AND TD.TaskType = 'RPF'
    
    OPEN CUR_REPLENTASKS
    
    FETCH FROM CUR_REPLENTASKS INTO @c_Lot, @c_FromLoc, @c_FromID, @n_Qty
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
      UPDATE LOTxLOCxID WITH (ROWLOCK)
         SET QtyReplen = QtyReplen - CASE WHEN QtyReplen < @n_Qty THEN QtyReplen ELSE @n_Qty END, 
             TrafficCop = NULL,
             EditWho = SUSER_SNAME(),
             EditDate = GETDATE() 
      WHERE Lot = @c_Lot
      AND   LOC = @c_FromLoc 
      AND   ID  = @c_FromID  
    
      FETCH FROM CUR_REPLENTASKS INTO @c_Lot, @c_FromLoc, @c_FromID, @n_Qty
    END
    
    CLOSE CUR_REPLENTASKS
    DEALLOCATE CUR_REPLENTASKS
    
     
   END     

   ----delete tasks
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE TASKDETAIL
      WHERE TASKDETAIL.Wavekey = @c_Wavekey 
      AND (TASKDETAIL.Sourcetype LIKE 'ispRLWAV%' OR TASKDETAIL.SourceType LIKE 'ispWRTSK%')
      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV00)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END

   ----Remove taskdetailkey from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK) 
       SET PICKDETAIL.TaskdetailKey = '',
          TrafficCop = NULL
      FROM WAVEDETAIL (NOLOCK)  
      JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV00)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END          
   END        

   -----Reverse wave status------
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
    UPDATE WAVE 
       --SET STATUS = '0' -- Normal          --(Wan02)
       SET TMReleaseFlag = 'N'               --(Wan02) 
        ,  TrafficCop = NULL                 --(Wan02) 
        ,  EditWho = SUSER_SNAME()           --(Wan02) 
        ,  EditDate= GETDATE()               --(Wan02)   
    WHERE WAVEKEY = @c_wavekey  
    SELECT @n_err = @@ERROR  
    IF @n_err <> 0  
    BEGIN  
       SELECT @n_continue = 3  
       SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV00)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
   END  
   END  

   -----Reverse SOStatus---------
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
    EXECUTE nspGetRight 
       @c_facility,  
       @c_StorerKey,              
       '', --sku
       'UpdateSOReleaseTaskStatus', -- Configkey
       @b_success    OUTPUT,
       @c_authority  OUTPUT,
       @n_err        OUTPUT,
       @c_errmsg     OUTPUT      

    IF @b_success = 1 AND @c_authority = '1' 
    BEGIN
        UPDATE ORDERS WITH (ROWLOCK)
        SET SOStatus = '0',
            TrafficCop = NULL,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
        WHERE Userdefine09 = @c_Wavekey
        AND SOStatus = 'TSRELEASED'
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV00"  
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