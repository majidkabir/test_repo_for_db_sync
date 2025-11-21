SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  /**********************************************************************************/  
/* Trigger: ntrStorerConfigUpdate                                                   */  
/* Creation Date:                                                                   */  
/* Copyright: LF                                                                    */  
/* Written by:                                                                      */  
/*                                                                                  */  
/* Purpose:                                                                         */  
/*                                                                                  */     
/* Usage:                                                                           */  
/*                                                                                  */  
/* Local Variables:                                                                 */  
/*                                                                                  */  
/* Called By: When records updated                                                  */  
/*                                                                                  */  
/* PVCS Version: 1.4                                                                */  
/*                                                                                  */  
/* Version: 5.4                                                                     */  
/*                                                                                  */  
/* Data Modifications:                                                              */  
/*                                                                                  */  
/* Updates:                                                                         */  
/* Date         Author        Ver   Purposes                                        */  
/* 12-Dec-2008  TLTING        1.0   Revise Promary key - add facility               */  
/* 17-Mar-2009  TLTING        1.1   Change user_name() to SUSER_SNAME()             */  
/* 28-Oct-2013  TLTING        1.2   Review Editdate column update                   */  
/* 05-Feb-2015  NJOW01        1.3   330996-update log                               */  
/* 2021-Nov-26  Wan01         1.4   WMS-18410 - [RG] Logitech Tote ID Packing       */  
/*                                  Change Request                                  */  
/* 2021-Nov-26  Wan01         1.5   DevOps Conbine Script                           */  
/* 04-Mar-2022  TLTING   		1.6   WMS-19029 prevent bulk update or delete       	*/ 
/* 2022-04-12   kelvinongcy	1.7   amend way for control user run batch (kocy01)	*/
/************************************************************************************/  
  
CREATE   TRIGGER [dbo].[ntrStorerConfigUpdate]  
ON  [dbo].[StorerConfig]  
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
            ,@n_err2       int              -- For Additional Error Detection  
            ,@c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
            ,@n_continue   int                   
            ,@n_starttcnt  int                -- Holds the current transaction count  
            ,@c_preprocess NVARCHAR(250)         -- preprocess  
            ,@c_pstprocess NVARCHAR(250)         -- post process  
            ,@n_cnt        int                    
     
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
     
   /* #INCLUDE <TRPU_1.SQL> */    
   IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)  
   BEGIN  
      UPDATE StorerConfig WITH (ROWLOCK)  
      SET EditDate = GETDATE(),  
         EditWho = SUSER_SNAME()  
      FROM StorerConfig, INSERTED  
      WHERE StorerConfig.Storerkey = INSERTED.Storerkey  
         AND StorerConfig.Facility = INSERTED.Facility         -- tlting01  
         AND StorerConfig.ConfigKey = INSERTED.ConfigKey  
    
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table StorerConfig. (ntrStorerConfigUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
      END  
   END  
  
   --IF ( (SELECT COUNT(1) FROM   INSERTED  ) > 100 ) 
   --    AND SUSER_SNAME() NOT IN ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
        AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN  
        
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62508   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table StorerConfig. Batch Update not allow! (ntrStorerConfigUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
            
   END  
  
  
   --NJOW01  
   IF ( @n_continue = 1 or @n_continue = 2 ) AND UPDATE(Svalue)  
   BEGIN      
      --(Wan01)  - START  
      IF EXISTS ( SELECT 1 FROM INSERTED   
                                    JOIN DELETED ON  INSERTED.Storerkey = DELETED.Storerkey  
                               AND INSERTED.Facility = DELETED.Facility  
                               AND INSERTED.SValue <> DELETED.SValue  
                  WHERE INSERTED.Configkey = 'AdvancePackGenCartonNo'  
                  AND DELETED.Facility = ''  
                  AND EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK)   
                              WHERE ph.Storerkey = INSERTED.Storerkey  
                              AND ph.[Status] < '9' )   
                  UNION    
                  SELECT 1 FROM INSERTED   
                  JOIN DELETED ON  INSERTED.Storerkey = DELETED.Storerkey  
                               AND INSERTED.Facility = DELETED.Facility  
                               AND INSERTED.SValue <> DELETED.SValue  
                  WHERE INSERTED.Configkey = 'AdvancePackGenCartonNo'  
                  AND DELETED.Facility <> ''  
                  AND EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK)   
                              JOIN dbo.ORDERS AS o WITH (NOLOCK) ON ph.OrderKey = o.OrderKey AND ph.OrderKey <> ''  
                              WHERE ph.Storerkey = INSERTED.Storerkey  
                              AND o.Facility = INSERTED.Facility  
                              AND ph.[Status] < '9')  
                  UNION    
                  SELECT 1 FROM INSERTED   
                  JOIN DELETED ON  INSERTED.Storerkey = DELETED.Storerkey  
                               AND INSERTED.Facility = DELETED.Facility  
                               AND INSERTED.SValue <> DELETED.SValue  
                  WHERE INSERTED.Configkey = 'AdvancePackGenCartonNo'  
                  AND INSERTED.Facility <> ''  
                  AND EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK)   
                              JOIN dbo.LoadPlan AS lp WITH (NOLOCK) ON ph.Loadkey = lp.LoadKey AND ph.OrderKey = ''  
                              WHERE ph.Storerkey = INSERTED.Storerkey  
                              AND lp.Facility = INSERTED.Facility  
                              AND ph.[Status] < '9')   )  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err=62503   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Disallow to change ''AdvancePackGenCartonNo'' setting. Pack Not confirm found. (ntrStorerConfigUpdate).'  
      END  
      --(Wan01)  - END  
  
      IF @n_continue IN ( 1, 2 )          --(Wan01)  
      BEGIN  
         INSERT INTO TableActionLog (TableName, Action, Description, Userdefine01, Userdefine02, SourceType)  
         SELECT 'STORERCONFIG','UPDATE',   
               'Configkey:'+RTRIM(ISNULL(INSERTED.Configkey,'')) +   
               '  Field:SValue  Old Value:' + RTRIM(ISNULL(DELETED.Svalue,'')) +   
               '  New Value:' + RTRIM(ISNULL(INSERTED.Svalue,'')),  
               'SValue',  
               INSERTED.Configkey,  
               'ntrStorerConfigUpdate'  
         FROM INSERTED (NOLOCK)  
         JOIN DELETED (NOLOCK) ON INSERTED.Configkey = DELETED.Configkey AND INSERTED.Storerkey = DELETED.Storerkey  
                              AND INSERTED.Facility = DELETED.Facility   
      END                                 --(Wan01)  
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