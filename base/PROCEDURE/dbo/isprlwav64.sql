SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLWAV64                                          */  
/* Creation Date: 07-SEP-2023                                            */  
/* Copyright: MAERSK                                                     */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-23573 - [KR] DW Release Wave SP                          */
/*          (convert from ispRLBLP07)                                    */
/*                                                                       */  
/* Config Key = 'ReleaseWave_SP'                                         */  
/*                                                                       */  
/* Called By: Wave                                                       */  
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

CREATE   PROCEDURE [dbo].[ispRLWAV64]      
   @c_Wavekey NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_err     INT           OUTPUT
 , @c_errmsg  NVARCHAR(250) OUTPUT
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
           @c_ProcesssFlag   NVARCHAR(1),
           @c_Loadkey        NVARCHAR(10), 
           @c_Storerkey      NVARCHAR(15)
           
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_Success = 0, @n_err = 0, @c_errmsg = '', @n_cnt = 0
   SELECT @n_debug = 0

   --Get Storerkey If @c_Storerkey = ''
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      SELECT @c_Storerkey    = ORDERS.Storerkey
            ,@c_Facility     = ORDERS.Facility
            ,@c_ProcesssFlag = MAX(ISNULL(LOADPLAN.PROCESSFLAG,''))
      FROM WAVEDETAIL (NOLOCK)
      JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
      JOIN LOADPLANDETAIL (NOLOCK) ON (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
      JOIN LOADPLAN (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.LoadKey)
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey
      GROUP BY ORDERS.Storerkey, ORDERS.Facility
   END

   -----Wave Validation-----                    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      IF @c_ProcesssFlag = 'Y'
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 67005 
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Load of the Wave Already Released. (ispRLWAV64)'                  
      END      
   END
   
   -----Main Process-----                    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      SET @c_Tablename = 'WSEXCFALC'
      
      DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT DISTINCT LOADPLANDETAIL.Loadkey
        FROM WAVEDETAIL (NOLOCK)
        JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
        JOIN LOADPLANDETAIL (NOLOCK) ON (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
        WHERE WAVEDETAIL.Wavekey = @c_Wavekey
        ORDER BY LOADPLANDETAIL.Loadkey
      
      OPEN CUR_LOAD

      FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey
                 
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) 
      BEGIN              	        	    	                   
         EXEC ispGenTransmitLog2 @c_Tablename, @c_Loadkey, '', @c_StorerKey, ''          
                               , @b_success OUTPUT          
                               , @n_err     OUTPUT          
                               , @c_errmsg  OUTPUT          
                                  
         IF @b_success <> 1          
         BEGIN          
            SET @n_continue = 3          
            SET @n_err = 67010         
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                          + ': Insert into TRANSMITLOG2 Failed. (ispRLWAV64) '
                          + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '                   
         END 
         ELSE
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
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on Loadplan Failed (ispRLWAV64)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END  
         END

         FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey
      END
      CLOSE CUR_LOAD
      DEALLOCATE CUR_LOAD
   END 
          
    -----Update Wave Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE WAVE
      SET TMReleaseFlag = 'Y'
        , TrafficCop = NULL
        , EditWho = SUSER_SNAME()
        , EditDate = GETDATE()
      WHERE WaveKey = @c_Wavekey
   	
      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on Wave Failed (ispRLWAV64)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV64"  
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