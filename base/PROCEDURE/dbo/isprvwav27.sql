SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

    
/*************************************************************************/      
/* Stored Procedure: ispRVWAV27                                          */      
/* Creation Date: 21-JUN-2019                                            */      
/* Copyright: LFL                                                        */      
/* Written by:                                                           */      
/*                                                                       */      
/* Purpose: WMS-9242 - SG THGSG Release Wave                             */    
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
/* 2019-07-26  JihHaur  1.1   Fix delete other storer Pickheader (JH01)  */  
/* 01-04-2020  Wan01    1.2   Sync Exceed & SCE                          */   
/*************************************************************************/       
    
CREATE PROCEDURE [dbo].[ispRVWAV27]          
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
    
    DECLARE @c_Storerkey       NVARCHAR(15)    
           ,@c_Sku             NVARCHAR(20)    
           ,@c_Lot             NVARCHAR(10)    
           ,@c_ToLoc           NVARCHAR(10)    
           ,@c_ToID            NVARCHAR(18)    
           ,@n_Qty             INT    
           ,@c_Taskdetailkey   NVARCHAR(10)    
           ,@c_UserDefine02    NVARCHAR(20)    
           ,@c_Loadkey         NVARCHAR(10)    
           ,@c_OrderGroup      NVARCHAR(30)    
    
    SELECT TOP 1 @c_UserDefine02 = W.UserDefine02    
    FROM  WAVE W (NOLOCK)    
    WHERE W.Wavekey = @c_Wavekey    
    
    SELECT TOP 1 @c_OrderGroup = LTRIM(RTRIM(ISNULL(O.ORDERGROUP,''))), @c_Storerkey = LTRIM(RTRIM(ISNULL(O.STORERKEY,'')))  --(JH01)  
    FROM WAVEDETAIL WD (NOLOCK)    
    JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey    
    JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey    
    WHERE WD.Wavekey = @c_Wavekey    
    
    ----reject if wave not yet release -- Multi          
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderGroup = 'MULTI'    
    BEGIN    
        IF NOT EXISTS (SELECT 1 FROM OrderToLocDetail OTLD (NOLOCK)     
                   WHERE OTLD.Wavekey = @c_Wavekey    
                   AND OTLD.StoreGroup = 'THGSG'    
                   AND OTLD.PTSZone = @c_UserDefine02 )     
        BEGIN    
           SELECT @n_continue = 3      
           SELECT @n_err = 81010      
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV27)'        
        END                     
    END    
    
    ----reject if wave not yet release -- Single    
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderGroup = 'SINGLE'    
    BEGIN    
        IF EXISTS (SELECT 1 FROM Wave W (NOLOCK)     
                   WHERE W.Wavekey = @c_Wavekey    
                   AND W.[Status] = '0')    
        BEGIN    
           SELECT @n_continue = 3      
           SELECT @n_err = 81015     
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (ispRVWAV27)'        
        END                     
    END    
    
    ----reject if any task was started    
    IF @n_continue = 1 OR @n_continue = 2    
    BEGIN    
       IF EXISTS (SELECT 1 FROM OrderToLocDetail OTLD (NOLOCK)     
                   WHERE OTLD.Wavekey = @c_Wavekey    
                   AND OTLD.StoreGroup = 'THGSG'    
                   AND OTLD.Status <> '0'    
                   AND OTLD.PTSZone = @c_UserDefine02 )     
       BEGIN    
          SELECT @n_continue = 3      
          SELECT @n_err = 81020      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (ispRVWAV27)'           
       END                     
    END    
    
    --Delete from OrderToLocDetail table and Pickheader table (Discrete)    
    IF @n_continue = 1 or @n_continue = 2      
    BEGIN    
       DECLARE Cur_OTLD CURSOR FAST_FORWARD READ_ONLY FOR    
       SELECT DISTINCT Orderkey    
       FROM WAVEDETAIL (NOLOCK)    
       WHERE Wavekey = @c_wavekey    
    
       OPEN Cur_OTLD    
    
       FETCH NEXT FROM Cur_OTLD INTO @c_Orderkey    
    
       WHILE @@FETCH_STATUS <> -1    
       BEGIN    
          DELETE FROM OrderToLocDetail    
          WHERE Wavekey = @c_wavekey AND Orderkey = @c_Orderkey    
    
          SELECT @n_err = @@ERROR    
          IF @n_err <> 0        
          BEGIN        
             SELECT @n_continue = 3        
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete From OrderToLocDetail Failed (ispRVWAV27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
          END    
    
          DELETE FROM Pickheader    
          WHERE Orderkey = @c_Orderkey AND Storerkey = @c_Storerkey  --(JH01)  
    
          SELECT @n_err = @@ERROR    
          IF @n_err <> 0        
          BEGIN        
             SELECT @n_continue = 3        
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete From PickHeader Failed (ispRVWAV27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
          END    
    
          FETCH NEXT FROM Cur_OTLD INTO @c_Orderkey    
       END    
       CLOSE Cur_OTLD    
       DEALLOCATE Cur_OTLD    
    END    
        
    --Delete from Pickheader and RefKeyLookup Table    
    IF @n_continue = 1 or @n_continue = 2      
    BEGIN    
       DECLARE Cur_PHeader CURSOR FAST_FORWARD READ_ONLY FOR    
       --SELECT DISTINCT Loadkey  --(JH01) comment start  
       --FROM WAVEDETAIL (NOLOCK)    
       --JOIN ORDERS (NOLOCK) ON WAVEDETAIL.ORDERKEY = ORDERS.ORDERKEY  
       --WHERE Wavekey = @c_wavekey  --(JH01) comment end  
    
       SELECT DISTINCT LOADPLANDETAIL.Loadkey  --(JH01) Ow script start  
       FROM WAVEDETAIL (NOLOCK)  
       JOIN ORDERS (NOLOCK) ON WAVEDETAIL.ORDERKEY = ORDERS.ORDERKEY  
       JOIN LOADPLANDETAIL (NOLOCK) ON ORDERS.Orderkey = LOADPLANDETAIL.Orderkey  
       WHERE WAVEDETAIL.Wavekey = @c_wavekey   --(JH01) Ow script end  
  
       OPEN Cur_PHeader    
    
       FETCH NEXT FROM Cur_PHeader INTO @c_Loadkey    
    
       WHILE @@FETCH_STATUS <> -1    
       BEGIN    
          --DELETE FROM Pickheader             --(JH01) comment  
          --WHERE ExternOrderkey = @c_Loadkey  --(JH01) comment  
  --(JH01) Ow script start  
          DELETE P FROM Pickheader P JOIN LoadPlan LP ON P.ExternOrderKey = LP.Loadkey  
          WHERE P.ExternOrderkey = @c_Loadkey   --(JH01) Ow script end  
  
          SELECT @n_err = @@ERROR    
          IF @n_err <> 0        
          BEGIN        
             SELECT @n_continue = 3        
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete From PickHeader Failed (ispRVWAV27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
          END    
    
          --DECLARE Cur_RFKL CURSOR FAST_FORWARD READ_ONLY FOR    
          --SELECT DISTINCT Orderkey    
          --FROM Loadplandetail (NOLOCK)    
          --WHERE Loadkey = @c_Loadkey    
              
          --OPEN Cur_RFKL    
              
          --FETCH NEXT FROM Cur_RFKL INTO @c_Orderkey    
              
          --WHILE @@FETCH_STATUS <> -1    
          --BEGIN    
          --   DELETE FROM REFKEYLOOKUP    
          --   WHERE Orderkey = @c_Orderkey    
    
          --   FETCH NEXT FROM Cur_RFKL INTO @c_Orderkey    
          --END    
       --CLOSE Cur_RFKL    
          --DEALLOCATE Cur_RFKL    
    
          FETCH NEXT FROM Cur_PHeader INTO @c_Loadkey    
       END    
       CLOSE Cur_PHeader    
       DEALLOCATE Cur_PHeader    
    END    
    
    -----Reverse wave status------    
    IF @n_continue = 1 or @n_continue = 2      
    BEGIN      
       UPDATE WAVE   
         --SET STATUS = '0' -- Normal        --(Wan01)   
         SET TMReleaseFlag = 'N'             --(Wan01) 
         ,  TrafficCop = NULL                --(Wan01) 
         ,  EditWho = SUSER_SNAME()          --(Wan01) 
         ,  EditDate= GETDATE()              --(Wan01)    
       WHERE WAVEKEY = @c_wavekey      
       SELECT @n_err = @@ERROR      
       IF @n_err <> 0      
       BEGIN      
          SELECT @n_continue = 3      
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV27"      
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