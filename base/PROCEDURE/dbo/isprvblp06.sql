SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRVBLP06                                          */  
/* Creation Date: 24-Aug-2020                                            */   
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-14842 NIKE ECOM Replenishment generation on Build Load   */          
/*                                                                       */
/* Config Key = 'ReversePickTaskCode_SP'                                 */  
/*                                                                       */
/* Called By: Build load RCM                                             */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */ 
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRVBLP06]      
  @c_loadkey      NVARCHAR(10)  
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
          ,@c_otherloadkey NVARCHAR(10)        
          ,@c_GetOrderkey NVARCHAR(10)
          ,@c_GetORDLineNumber NVARCHAR(5)
          ,@c_GetLoadkey NVARCHAR(10)
          ,@c_GetStorerkey NVARCHAR(15)   

   SELECT TOP 1 @c_StorerKey = O.Storerkey,
                @c_Facility = O.Facility 
   FROM LOADPLANDETAIL LD (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON (LD.Orderkey = O.Orderkey)
   WHERE LD.Loadkey = @c_Loadkey  
    
   BEGIN TRAN
   
   --Delete From Replenishment
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DELETE FROM REPLENISHMENT
      WHERE OriginalFromLoc = 'ispRLBLP06' AND Loadkey = @c_loadkey
      AND Storerkey = @c_StorerKey
         
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 71050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_loadkey) + ' Delete from Replenishment Table Failed. (ispRVBLP06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END          
   END  
    
   -----Reverse load status------
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE LOADPLAN 
      SET ProcessFlag = 'N',
          Status = CASE WHEN Status = '3' THEN '2' ELSE Status END,
          TrafficCop = NULL       
      WHERE Loadkey = @c_Loadkey  
      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load# ' + RTRIM(@c_loadkey) + ' Update on LOADPLAN Failed (ispRVBLP06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
         WHERE Loadkey = @c_Loadkey
         AND SOStatus = 'TSRELEASED'
      END          
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_Load') IN (0 , 1)
   BEGIN
      CLOSE CUR_Load
      DEALLOCATE CUR_Load    
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRVBLP06"  
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