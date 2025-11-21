SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_WV_VoicePicking                            */
/* Creation Date: 04-JUN-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17197-WAVE RCM Update Voice Pick(VP) flag for Interface */
/*                                                                      */
/* Called By: WAVE Dymaic RCM configure at listname 'RCMConfig'         */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_RCM_WV_VoicePicking]
   @c_Wavekey  NVARCHAR(10),   
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT,
           @n_cnt       INT,
           @n_starttcnt INT,
           @c_Loadkey   NVARCHAR(10)
                         
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
  
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE cur_Load CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT LPD.Loadkey
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON WD.Orderkey = LPD.Orderkey
         WHERE WD.Wavekey = @c_Wavekey
      
      OPEN cur_Load
        
      FETCH NEXT FROM cur_Load INTO @c_Loadkey
          
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN          	 
      	  UPDATE LOADPLAN WITH (ROWLOCK)
      	  SET Userdefine10 = 'VP',
      	      Trafficcop = NULL
      	  WHERE Loadkey = @c_Loadkey
      	  
      	  SET @n_err = @@ERROR
      	  
      	 IF @n_err <> 0
      	 BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table LOADPLAN. (isp_RCM_WV_VoicePicking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         END
      	     	     	 
         FETCH NEXT FROM cur_Load INTO @c_Loadkey
      END
      CLOSE cur_Load
      DEALLOCATE cur_Load
   END
   
   IF @n_continue IN(1,2)
   BEGIN
      UPDATE WAVE WITH (ROWLOCK)
      SET WaveType = 'VP'
      WHERE Wavekey = @c_Wavekey

      SET @n_err = @@ERROR
      
      IF @n_err <> 0
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table WAVE. (isp_RCM_WV_VoicePicking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      END
   END
           
ENDPROC: 
 
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_WV_VoicePicking'
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
END -- End PROC

GO