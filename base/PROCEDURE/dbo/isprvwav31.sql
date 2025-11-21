SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRVWAV31                                          */  
/* Creation Date: 30-OCT-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-10647 - CN PVH QHW Reverse Wave                          */  
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
/* 04-01-2021  NJOW01   1.2   WMS-15891 add logic cater for new brand    */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRVWAV31]      
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
            @n_cnt int,
            @c_Wavetype NVARCHAR(10),
            @c_Pickslipno NVARCHAR(10)
            
    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0, @n_debug = 0

    DECLARE @c_Pickdetailkey NVARCHAR(10)
    
    SELECT @c_WaveType = W.WaveType
    FROM WAVE W (NOLOCK)
    JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey
    WHERE W.Wavekey = @c_Wavekey
                      
    ----reject if wave not yet release      
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN       
        IF NOT EXISTS(SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey            
                      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
                      WHERE WD.Wavekey = @c_Wavekey    
                      AND ISNULL(PD.Notes,'') <> '' --NJOW01
                      )
        BEGIN
           SELECT @n_continue = 3  
           SELECT @n_err = 81010  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV31)'

           UPDATE WAVE 
            --SET STATUS = '0' -- Normal        --(Wan01)
            SET TMReleaseFlag = 'N'             --(Wan01) 
            ,  TrafficCop = NULL                --(Wan01) 
            ,  EditWho = SUSER_SNAME()          --(Wan01) 
            ,  EditDate= GETDATE()              --(Wan01) 
           WHERE WAVEKEY = @c_wavekey
           --AND STATUS = '1'                   --(Wan01) 
           AND TMReleaseFlag = 'Y'              --(Wan01)     
        END                 
    END

    ----reject if any pick was started
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 
                   FROM WAVEDETAIL WD (NOLOCK)
                   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey            
                   JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
                   WHERE WD.Wavekey = @c_Wavekey    
                   AND PD.Status >= '5'
                  )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some pick have been started. Not allow to Reverse Wave Released (ispRVWAV31)'          
       END                 
    END
    
    BEGIN TRAN
                                    
    ----Remove caseid and notes from pickdetail of the wave
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PICKDETAIL.Pickdetailkey
          FROM WAVEDETAIL (NOLOCK)  
          JOIN PICKDETAIL ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
          WHERE WAVEDETAIL.Wavekey = @c_Wavekey
       
       OPEN cur_pick  
          
       FETCH NEXT FROM cur_pick INTO @c_Pickdetailkey
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
           UPDATE PICKDETAIL WITH (ROWLOCK)
           SET Notes = '', --NJOW01
               CaseID = '',  --NJOW01
               Trafficcop = NULL
           WHERE Pickdetailkey = @c_Pickdetailkey    
       
          SELECT @n_err = @@ERROR
          
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRVWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END          
               
          FETCH NEXT FROM cur_pick INTO @c_Pickdetailkey
       END             
       CLOSE cur_pick
       DEALLOCATE cur_pick       
    END        
    
    --NJOW01
    -----Remove PTS   
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveType = 'PTS'
    BEGIN
       DELETE FROM RDT.rdtPTLStationLog
       WHERE Wavekey = @c_Wavekey
       AND SourceType = 'ispRLWAV31'

       SELECT @n_err = @@ERROR
       
       IF @n_err <> 0 
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete RDT.rdtPTLStationLog Table Failed. (ispRVWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END          
    END
    
    --NJOW01
    -----Remove Pre-cartonize   
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveType = 'PC'
    BEGIN
       DECLARE CUR_PICKSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT DISTINCT PD.Pickslipno
          FROM PICKDETAIL PD (NOLOCK)
          JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey
          JOIN PACKHEADER PH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
          WHERE WD.Wavekey = @c_Wavekey
          AND PH.Status <> '9'
       
       OPEN CUR_PICKSLIP                                                  
                                                           
       FETCH NEXT FROM CUR_PICKSLIP INTO @c_Pickslipno      
                                                                         
       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)          
       BEGIN                
       	  DELETE FROM PACKDETAIL WHERE Pickslipno = @c_Pickslipno

          SELECT @n_err = @@ERROR
         
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKDETAIL Table Failed. (ispRVWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          END
          ELSE
          BEGIN                 	  
       	     DELETE FROM PACKINFO WHERE Pickslipno = @c_Pickslipno

             SELECT @n_err = @@ERROR
             
             IF @n_err <> 0 
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKINFO Table Failed. (ispRVWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END
             ELSE
             BEGIN       	  
       	        DELETE FROM PACKHEADER WHERE Pickslipno = @c_Pickslipno

                SELECT @n_err = @@ERROR
                
                IF @n_err <> 0 
                BEGIN
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKHEADER Table Failed. (ispRVWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                END                  
       	     END
       	  END       	       	         	
       	  
          FETCH NEXT FROM CUR_PICKSLIP INTO @c_Pickslipno      
       END                                                        
       CLOSE CUR_PICKSLIP
       DEALLOCATE CUR_PICKSLIP                     
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV31)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV31"  
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