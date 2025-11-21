SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_ORD_YVESR_PARTALLOC                        */
/* Creation Date: 28-Apr-2020                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-13149 TH YVESR Partial Allocation Integration           */
/*                                                                      */
/* Called By: Order Dymaic RCM configure at listname 'RCMConfig'        */ 
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

CREATE PROCEDURE [dbo].[isp_RCM_ORD_YVESR_PARTALLOC]
   @c_Orderkey NVARCHAR(10),   
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
           
   DECLARE @c_storerkey NVARCHAR(15),
           @c_doctype NCHAR(1),
           @c_Status NVARCHAR(10)
                         
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   SELECT TOP 1 @c_Storerkey = Storerkey,
                @c_doctype = Doctype,
                @c_Status = Status
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey
   
   IF @c_DocType <> 'E'
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Only allow doctype E to send interface (isp_RCM_ORD_YVESR_PARTALLOC)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
      GOTO ENDPROC       
   END   
      
   IF @c_Status <> '1'
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Only allow partial allocated order to send interface (isp_RCM_ORD_YVESR_PARTALLOC)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
      GOTO ENDPROC       
   END   
 
   IF EXISTS (SELECT 1 FROM TransmitLog2 (NOLOCK) WHERE TableName = 'WSRCMSHORT'
                      AND Key1 = @c_Orderkey AND Key2 = @c_Doctype AND Key3 = @c_Storerkey)
   BEGIN
   	  UPDATE TRANSMITLOG2 WITH (ROWLOCK)
   	  SET transmitflag = '0'
   	  WHERE Tablename = 'WSRCMSHORT'
   	  AND key1 = @c_Orderkey
   	  AND key2 = @c_DocType
   	  AND key3 = @c_Storerkey
   END

   IF @n_continue IN(1,2)
   BEGIN
      EXEC dbo.ispGenTransmitLog2 'WSRCMSHORT', @c_Orderkey, @c_doctype, @c_StorerKey, ''  
           , @b_success OUTPUT  
           , @n_err OUTPUT  
           , @c_errmsg OUTPUT  
           
      IF @b_success = 0
          SELECT @n_continue = 3, @n_err = 38020, @c_errmsg = 'isp_RCM_ORD_YVESR_PARTALLOC: ' + rtrim(@c_errmsg)
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_ORD_YVESR_PARTALLOC'
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