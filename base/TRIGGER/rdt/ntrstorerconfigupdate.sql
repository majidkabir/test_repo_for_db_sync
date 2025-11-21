SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/***************************************************************************************/    
/* Trigger: RDT.ntrStorerConfigUpdate																	*/  
/* Updates:																										*/  
/* Date         Author        Ver   Purposes															*/  
/* 28-Oct-2013  TLTING   1.0 Review Editdate column update										*/  
/* 2022-04-12   kelvinongcy 1.1 WMS-23183 prevent bulk update or delete (kocy01)			*/  
/***************************************************************************************/    
  
CREATE     TRIGGER [RDT].[ntrStorerConfigUpdate]   
ON [RDT].[StorerConfig]   
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
  
    DECLARE @b_Success      int       -- Populated by calls to stored procedures - was the proc successful?    
            ,@n_err        int       -- Error number returned by stored procedure or this trigger    
            ,@c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger    
            ,@n_continue   int                     
            ,@n_starttcnt  int                -- Holds the current transaction count    
            ,@n_cnt        int                      
       
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT    
  
   IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)   
 BEGIN  
  UPDATE rdt.StorerConfig WITH (ROWLOCK)  
  SET EditDate = GETDATE(),  
      EditWho = SUSER_SNAME()  
  FROM rdt.StorerConfig, INSERTED  
  WHERE rdt.StorerConfig.Function_ID = INSERTED.Function_ID  
  AND rdt.StorerConfig.StorerKey = INSERTED.StorerKey  
  AND rdt.StorerConfig.ConfigKey = INSERTED.ConfigKey  
      
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
      IF @n_err <> 0    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table RDT.StorerConfig. (RDT.ntrStorerConfigUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
      END    
 END  
  
  
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01  
        AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())  
   BEGIN    
          
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62508   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table RDT.StorerConfig. Batch Update not allow! (RDT.ntrStorerConfigUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "    
              
   END  
   
   /* #INCLUDE <TRPU_2.SQL> */    
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
      execute nsp_logerror @n_err, @c_errmsg, "ntrStorerConfigUpdate"    
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