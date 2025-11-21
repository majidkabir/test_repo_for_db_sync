SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Trigger: ntrRouteMasterUpdate                                           				*/
/* Creation Date: 18-Dec-2015                                              				*/
/* Copyright: IDS                                                          				*/
/* Written by:    JayLim                                                   				*/
/*                                                                         				*/
/* Purpose:  Update RouteMaster                                            				*/
/*                                                                         				*/
/* Return Status:                                                          				*/
/*                                                                         				*/
/* Usage:                                                                  				*/
/*                                                                         				*/
/* Called By: When records Updated                                         				*/
/*                                                                         				*/
/* PVCS Version: 1.0                                                       				*/
/*                                                                         				*/
/* Version: 5.4                                                            				*/
/*                                                                         				*/
/* Modifications:                                                          				*/
/* Date         Author   		Ver  	Purposes                                     		*/
/*18-Dec-2015   JayLim   		1.0  	Initial version                                    */
/* 2022-05-17   kelvinongcy	1.1	WMS-19673 prevent bulk update or delete (kocy01)	*/
/***************************************************************************************/
  
CREATE   TRIGGER [dbo].[ntrRouteMasterUpdate]  
ON  [dbo].[RouteMaster]   
FOR UPDATE  
AS  
BEGIN  
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END
	
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF 
	
   DECLARE @b_Success int          -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err int              -- Error number returned by stored procedure or this trigger  
         , @n_err2 int             -- For Additional Error Detection  
         , @c_errmsg NVARCHAR(250)     -- Error message returned by stored procedure or this trigger  
         , @n_continue int                   
         , @n_starttcnt int        -- Holds the current transaction count  
         , @c_preprocess NVARCHAR(250) -- preprocess  
         , @c_pstprocess NVARCHAR(250) -- post process  
         , @n_cnt int                    
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  

   IF ( @n_continue = 1 OR @n_continue = 2  ) AND NOT UPDATE(EditDate) 
   BEGIN  
      UPDATE RouteMaster WITH (ROWLOCK)
         SET EditDate = GETDATE(),  
             EditWho = SUSER_SNAME()
        FROM RouteMaster, INSERTED
       WHERE RouteMaster.Route = INSERTED.Route

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
		
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85803   -- Should Be Set To The SQL Err message but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))  
                         +': Update Failed On Table RouteMaster. (ntrRouteMasterUpdate)' + ' ( '   
                         +' SQLSvr MESSAGE=' + ISNULL(LTrim(RTrim(@c_errmsg)),'') + ' ) '  
      END  
   END 
   
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85804   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table RouteMaster. Batch Update not allow! (ntrRouteMasterUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END

   /* #INCLUDE <TRPU_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrRouteMasterUpdate'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  

END  

GO