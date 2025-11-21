SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/***************************************************************************************/    
/* Trigger: RDT.ntrRDTUserUpdate																			*/  
/* Updates:																										*/  
/* Date         Author        Ver   Purposes															*/  
/* 2023-08-07   kelvinongcy 1.1 WMS-23183 prevent bulk update or delete (kocy01)			*/  
/***************************************************************************************/    
  
CREATE     TRIGGER [RDT].[ntrRDTUserUpdate]   
ON [RDT].[RDTUser]   
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
  
  
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01  
        AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())  
   BEGIN    
          
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62508   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table RDT.RDTUser. Batch Update not allow! (RDT.ntrRDTUserUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "    
              
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
      execute nsp_logerror @n_err, @c_errmsg, "RDT.ntrRDTUserUpdate"    
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