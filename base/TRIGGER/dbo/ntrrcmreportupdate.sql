SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************************/  
/* Trigger: ntrRCMReportUpdate                                                      */  
/* Creation Date: 04.May.2006                                                       */  
/* Copyright: IDS                                                                   */  
/* Written by: June                                                                 */  
/*                                                                                  */  
/* Purpose:  RCM Report Update Transaction                                          */  
/*                                                                                  */  
/* Usage:                                                                           */  
/*                                                                                  */  
/* Local Variables:                                                                 */  
/*                                                                                  */  
/* Called By: When update records                                                   */  
/*                                                                                  */  
/* PVCS Version: 1.0                                                                */  
/*                                                                                  */  
/* Version: 6.0                                                                     */  
/*                                                                                  */  
/* Data Modifications:                                                              */  
/*                                                                                  */  
/* Updates:                                                                         */  
/* Date         Author        Ver   Purposes                                        */  
/* 17-Mar-2009  TLTING        1.0   Change user_name() to SUSER_SNAME()             */  
/* 28-Oct-2013  TLTING        1.2   Review Editdate column update                   */  
/* 04-Mar-2022  TLTING   		1.3   WMS-19029 prevent bulk update or delete      	*/ 
/* 2022-04-12   kelvinongcy	1.4   amend way for control user run batch (kocy01)	*/  
/************************************************************************************/  
  
CREATE   TRIGGER [dbo].[ntrRCMReportUpdate]   
ON [dbo].[RCMReport]  
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
 
   DECLARE @b_success   int       -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err       int       -- Error number returned by stored procedure or this trigger    
         , @c_errmsg    NVARCHAR(250) -- Error message returned by stored procedure or this trigger   
         , @n_continue  int           --continuation flag 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing  
         , @n_starttcnt int                -- Holds the current transaction count                                                 
         , @n_cnt       int                      /* variable to hold @@ROWCOUNT */   
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
  
   IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)  
   BEGIN  
      UPDATE dbo.RCMReport WITH (ROWLOCK) 
      SET EditDate = GETDATE(),  
          EditWho = SUSER_SNAME()  
      FROM  RCMReport,INSERTED  
      WHERE RCMReport.ComputerName = INSERTED.ComputerName  
      AND   RCMReport.StorerKey = INSERTED.StorerKey  
      AND   RCMReport.ReportType = INSERTED.ReportType  
      
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90205   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Editdate/User Failed On Table RCMReport. (ntrRCMReportUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      END  
   END  
  
   --IF ( (SELECT COUNT(1) FROM   INSERTED  ) > 100 ) 
   --    AND SUSER_SNAME() NOT IN ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
        AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN        
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90208   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table RCMReport. Batch Update not allow! (ntrRCMReportUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
   END  
  
   /* Return Statement */  
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
      Execute nsp_logerror @n_err, @c_errmsg, 'ntrRCMReportUpdate'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012            
      RETURN  
   END  
   ELSE  
   BEGIN  
       /* Error Did Not Occur , Return Normally */  
       WHILE @@TRANCOUNT > @n_starttcnt   
       BEGIN  
            COMMIT TRAN  
       END  
       RETURN  
   END  
   /* End Return Statement */ 
   
END  

GO