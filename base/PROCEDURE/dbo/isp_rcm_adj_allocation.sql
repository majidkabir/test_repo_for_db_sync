SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_ADJ_Allocation                             */
/* Creation Date: 30-Jun-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17314 MY Adjustment Allocation                          */
/*                                                                      */
/* Called By: ADJ Dymaic RCM configure at listname 'RCMConfig'          */ 
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

CREATE PROCEDURE [dbo].[isp_RCM_ADJ_Allocation]
   @c_AdjustmentKey NVARCHAR(10),   
   @b_success       INT OUTPUT,
   @n_err           INT OUTPUT,
   @c_errmsg        NVARCHAR(225) OUTPUT,
   @c_code          NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int
           
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   EXEC isp_AdjustmentProcessing                       
       @c_AdjustmentKey = @c_Adjustmentkey              
      ,@b_Success       = @b_Success OUTPUT            
      ,@n_err           = @n_Err     OUTPUT            
      ,@c_errmsg        = @c_ErrMsg  OUTPUT            
        
   IF @b_success = 0
       SELECT @n_continue = 3, @n_err = 60100, @c_errmsg = 'isp_RCM_ADJ_Allocation: ' + rtrim(@c_errmsg)
     
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_ADJ_Allocation'
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