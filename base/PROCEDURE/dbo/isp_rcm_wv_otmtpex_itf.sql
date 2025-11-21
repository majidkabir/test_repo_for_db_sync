SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_WV_OTMTPEX_ITF                             */
/* Creation Date: 02-MAY-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-4895-WAVE RCM trigger OTM TPEX Interface                */
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

CREATE PROCEDURE [dbo].[isp_RCM_WV_OTMTPEX_ITF]
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

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int
           
   DECLARE @c_Facility NVARCHAR(5),
           @c_storerkey NVARCHAR(15),
           @c_Orderkey  NVARCHAR(10),
           @c_Status    NVARCHAR(10)
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   SELECT TOP 1 @c_Facility = Facility,
                @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE Userdefine09 = @c_Wavekey       
   
   DECLARE cur_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Storerkey, Orderkey, Status
      FROM ORDERS(NOLOCK)
      WHERE Userdefine09 = @c_Wavekey
      ORDER BY Orderkey

   OPEN cur_Order  
       
   FETCH NEXT FROM cur_Order INTO @c_Storerkey, @c_Orderkey, @c_Status
       
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN          	 
   	  EXEC isp_OTM_TPEX_Interface
   	     @c_tablename = 'SORCMOTM',
   	     @c_Key1 = @c_Orderkey,
   	     @c_Key2 = @c_Status,
   	     @c_Key3 = @c_Storerkey,
   	     @c_transmitflag = '0',
   	     @c_transmitbatch = '',
   	     @c_resendflag = '1',
   	     @b_Success = @b_Success OUTPUT,
   	     @n_err = @n_Err OUTPUT,
   	     @c_Errmsg = @c_Errmsg OUTPUT   	        	     
   	    
      IF @b_success = 0
          SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'isp_RCM_WV_OTMTPEX_ITF: ' + RTRIM(@c_errmsg)
   	       	     
      FETCH NEXT FROM cur_Order INTO @c_Storerkey, @c_Orderkey, @c_Status
   END
   CLOSE cur_Order
   DEALLOCATE cur_Order
        
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_WV_OTMTPEX_ITF'
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