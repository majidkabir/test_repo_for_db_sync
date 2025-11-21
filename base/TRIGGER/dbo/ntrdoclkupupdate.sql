SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 17-Mar-2009  TLTING     Change user_name() to SUSER_SNAME()          */
/* 28-Oct-2013  TLTING     Review Editdate column update                */

CREATE TRIGGER ntrDoclkupUpdate      
 ON  DOCLKUP      
 FOR UPDATE      
 AS      
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
 DECLARE
 @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
 ,         @n_err                int       -- Error number returned by stored procedure or this trigger
 ,         @n_err2 int              -- For Additional Error Detection
 ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
 ,         @n_continue int                 
 ,         @n_starttcnt int                -- Holds the current transaction count
 ,         @n_cnt int                  
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT


IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate) 
 BEGIN      
    UPDATE DOCLKUP with (ROWLOCK)     
       SET EditDate = GETDATE(),      
    	     EditWho = SUSER_SNAME()      
      FROM DOCLKUP, INSERTED, DELETED   
     WHERE (DOCLKUP.ConsigneeGroup = INSERTED.ConsigneeGroup AND DOCLKUP.SkuGroup = INSERTED.SkuGroup)      
           OR (DOCLKUP.ConsigneeGroup = DELETED.ConsigneeGroup AND DOCLKUP.SkuGroup = DELETED.SkuGroup)       

    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT      
    IF @n_err <> 0      
    BEGIN      
       SELECT @n_continue = 3      
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table DOCLKUP. (ntrDoclkupUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "      
    END 
    

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
    IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt  
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
     
    EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrDoclkupUpdate"  
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