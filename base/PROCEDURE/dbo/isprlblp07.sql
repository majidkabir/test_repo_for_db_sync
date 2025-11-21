SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLBLP07                                          */  
/* Creation Date: 01-Apr-2021                                            */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-16729 - [KR] DW BuildLoad ReleaseTask SP (Exceed - NEW)  */
/*                                                                       */  
/* Config Key = 'BuildLoadReleaseTask_SP'                                */  
/*                                                                       */  
/* Called By: isp_BuildLoadReleaseTask_Wrapper                           */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLBLP07]      
  @c_Loadkey      NVARCHAR(10)  
 ,@b_Success      INT            OUTPUT  
 ,@n_err          INT            OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT
 ,@c_Storerkey    NVARCHAR(15) = '' 

 AS  
 BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue       INT,    
           @n_starttcnt      INT,         -- Holds the current transaction count  
           @n_debug          INT,
           @n_cnt            INT,
           @c_Facility       NVARCHAR(5),
           @c_Tablename      NVARCHAR(50),
           @c_ProcesssFlag   NVARCHAR(1)
           
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_Success = 0, @n_err = 0, @c_errmsg = '', @n_cnt = 0
   SELECT @n_debug = 0

   --Get Storerkey If @c_Storerkey = ''
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      SELECT TOP 1 @c_Storerkey    = ORDERS.Storerkey
                 , @c_Facility     = ORDERS.Facility
                 , @c_ProcesssFlag = ISNULL(LOADPLAN.PROCESSFLAG,'')
      FROM LOADPLANDETAIL (NOLOCK)
      JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
      JOIN LOADPLAN (NOLOCK) ON (LOADPLAN.LoadKey = LoadPlanDetail.LoadKey)
      WHERE LOADPLANDETAIL.Loadkey = @c_LoadKey   
   END

   -----Load Validation-----                    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      IF @c_ProcesssFlag = 'Y'
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 67005 
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load Task Already Released. (ispRLBLP07)'                  
      END      
   END
   
   -----Main Process-----                    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      SET @c_Tablename = 'WSEXCFALC'
      EXEC ispGenTransmitLog2 @c_Tablename, @c_Loadkey, '', @c_StorerKey, ''          
                            , @b_success OUTPUT          
                            , @n_err     OUTPUT          
                            , @c_errmsg  OUTPUT          
                               
      IF @b_success <> 1          
      BEGIN          
         SET @n_continue = 3          
         SET @n_err = 67010         
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                       + ': Insert into TRANSMITLOG2 Failed. (ispRLBLP07) '
                       + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '                   
      END 
   END 
          
    -----Update LoadPlan Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE LoadPlan
      SET   [Status] = '3'
          , PROCESSFLAG = 'Y'
          , TrafficCop = NULL
          , EditWho = SUSER_SNAME()
          , EditDate = GETDATE()
      WHERE  LoadKey = @c_Loadkey

      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on Load Failed (ispRLBLP07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  
   
QUIT_SP:
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRLBLP07"  
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