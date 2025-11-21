SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE  TRIGGER ntrBatchPickUpdate  
 ON  BatchPick  
 FOR UPDATE    
 AS    
 BEGIN 
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
 ,         @c_preprocess NVARCHAR(250)         -- preprocess    
 ,         @c_pstprocess NVARCHAR(250)         -- post process    
 ,         @n_cnt int   
 ,    @c_loadkey NVARCHAR(10)                     
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT    
      /* #INCLUDE <TRMBOA1.SQL> */      
 declare @b_debug int    
 select @b_debug = 0    
 BEGIN TRANSACTION    
 IF @n_continue = 1 OR @n_continue = 2  
 BEGIN  
  IF UPDATE (QtyScanned)  
  BEGIN  
   SELECT @c_loadkey = LOADKEY FROM INSERTED  
   IF EXISTS (SELECT 1 FROM INSERTED WHERE QtyScanned = QtyAllocated AND Loadkey = @c_loadkey)  
   BEGIN  
    -- update pickdetails to = '5'  
    UPDATE PICKDETAIL  
    SET STATUS = '5',
        EditDate = GETDATE(),       --tlting
        EditWho = SUSER_SNAME()  
    FROM PICKDETAIL (NOLOCK), LOADPLANDETAIL (NOLOCK)  
    WHERE PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey  
    AND LOADPLANDETAIL.Loadkey = @c_loadkey  
    AND PICKDETAIL.Status  < '5'  
    AND PICKDETAIL.PickMethod = '1' -- RF Directed only.  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
      IF @n_err <> 0    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=22809   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table PICKDETAIL. (ntrBatchPickUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
      END    
   END  
  END  
 END  
      /* #INCLUDE <TRMBOHA2.SQL> */    
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
    execute nsp_logerror @n_err, @c_errmsg, "ntrBatchPickUpdate"    
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