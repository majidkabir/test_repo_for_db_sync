SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRVWAV03                                          */  
/* Creation Date: 08-Jul-2015                                            */  
/* Copyright: LF                                                         */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: SOS#342639 - CN - UA Reverse released replenishment By Wave  */  
/*          Work together with ispRLWAV03                                */          
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 27/10/2017   NJOW01   1.0  WMS-3290 - Add optional logic to send conso*/
/*                            carton to temporary sorting loc            */
/*************************************************************************/   
/*
declare @b_Success      int          
 ,@n_err          int          
 ,@c_errmsg       NVARCHAR(250)
exec ispRVWAV03    
  '0000003572'  
 ,@b_Success OUTPUT  
 ,@n_err  OUTPUT  
 ,@c_errmsg  OUTPUT
select @b_success, @n_err, @c_errmsg*/

CREATE PROCEDURE [dbo].[ispRVWAV03]      
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
                   
    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT @n_debug = 0
    
    ----reject if wave not yet release      
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN    	
        IF NOT EXISTS (SELECT 1 FROM REPLENISHMENT (NOLOCK) 
                       WHERE Wavekey = @c_Wavekey
                       AND OriginalFromLoc = 'ispRLWAV03')
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81010  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The Replenishment has not been released for this Wave. (ispRVWAV03)'         
        END                 
    END

    ----reject if any replenishment was started
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
	     IF EXISTS (SELECT 1 
                  FROM  REPLENISHMENT WITH (NOLOCK)
                  WHERE Wavekey = @c_WaveKey 
                  AND Confirmed <> 'N'
                  AND OriginalFromLoc = 'ispRLWAV03')
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Replenishment have been started. Not allow to Reverse Replenishment Released.(ispRVWAV03)'  
       END
    END
    
    BEGIN TRAN
    
    ----delete replenishment
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       --Remove qtyreplen for pending replenishment
       UPDATE LOTXLOCXID WITH (ROWLOCK)
   	   SET LOTXLOCXID.QtyReplen = LOTXLOCXID.QtyReplen - CASE WHEN LOTXLOCXID.QtyReplen > 0 THEN RP.Qty ELSE 0 END,
   	       LOTXLOCXID.TrafficCop = NULL
   	   FROM (SELECT Storerkey, Sku, Lot, FromLoc, ID, SUM(QTY) AS Qty 
   	         FROM REPLENISHMENT (NOLOCK)
   	         WHERE Wavekey = @c_Wavekey
   	         AND Confirmed = 'N'
   	         AND OriginalFromLoc = 'ispRLWAV03'
   	         AND ReplenNo NOT IN('FCP','FCS') --NJOW01
   	         GROUP BY Storerkey, Sku, Lot, FromLoc, ID) AS RP
   	   JOIN LOTXLOCXID ON RP.Storerkey = LOTXLOCXID.Storerkey AND RP.Sku = LOTXLOCXID.Sku AND
   	                      RP.Lot = LOTXLOCXID.Lot AND RP.FromLoc = LOTXLOCXID.Loc AND RP.Id = LOTXLOCXID.Id
       
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LotxLocxID Failed. (ispRVWAV03)' 
           GOTO RETURN_SP
       END
       BEGIN
       	  --remove replenishment
       	  DELETE Replenishment
          WHERE Wavekey = @c_WaveKey
          AND Confirmed = 'N'           
   	      AND OriginalFromLoc = 'ispRLWAV03'
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV03"  
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