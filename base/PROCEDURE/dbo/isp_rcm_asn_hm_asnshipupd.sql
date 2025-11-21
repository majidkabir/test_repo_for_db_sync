SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_ASN_HM_ASNSHIPUPD                          */
/* Creation Date: 08-Jun-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-5074 HM ASN Shipment Update Interface                   */
/*                                                                      */
/* Called By: ASN Dymaic RCM configure at listname 'RCMConfig'          */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_RCM_ASN_HM_ASNSHIPUPD]
   @c_Receiptkey NVARCHAR(10),   
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
           @n_starttcnt int,
           @c_key2 NVARCHAR(30)
           
   DECLARE @c_storerkey NVARCHAR(15),
           @c_doctype NCHAR(1)
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   SELECT TOP 1 @c_Storerkey = Storerkey,
                @c_doctype = Doctype
   FROM RECEIPT (NOLOCK)
   WHERE Receiptkey = @c_Receiptkey    

   --IF @c_DocType <> 'A'
   --   GOTO ENDPROC
   
   DECLARE cur_RECEIPTUDF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Userdefine09
      FROM RECEIPTDETAIL (NOLOCK)
      WHERE Receiptkey = @c_Receiptkey
      AND ISNULL(Userdefine09,'') <> ''
      UNION ALL
      SELECT DISTINCT Userdefine10
      FROM RECEIPTDETAIL (NOLOCK)
      WHERE Receiptkey = @c_Receiptkey
      AND ISNULL(Userdefine10,'') <> ''

   OPEN cur_RECEIPTUDF  
          
   FETCH NEXT FROM cur_RECEIPTUDF INTO @c_key2
          
   WHILE @@FETCH_STATUS = 0 
   BEGIN   
      IF EXISTS (SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = 'RCPTHNM9L'
                         AND Key1 = @c_Receiptkey AND Key2 = @c_key2 AND Key3 = @c_Storerkey)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Interface was transmitted (isp_RCM_ASN_HM_ASNSHIPUPD)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      END
      
      IF @n_continue IN(1,2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'RCPTHNM9L', @c_Receiptkey, @c_key2, @c_StorerKey, ''  
              , @b_success OUTPUT  
              , @n_err OUTPUT  
              , @c_errmsg OUTPUT  
              
         IF @b_success = 0
             SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'isp_RCM_ASN_HM_ASNSHIPUPD: ' + rtrim(@c_errmsg)
      END   	
   	  
      FETCH NEXT FROM cur_RECEIPTUDF INTO @c_key2
   END         
   CLOSE cur_RECEIPTUDF
   DEALLOCATE cur_RECEIPTUDF	  
        
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_ASN_HM_ASNSHIPUPD'
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