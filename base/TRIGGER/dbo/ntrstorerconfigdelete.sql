SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************************/
/* Trigger: ntrStorerConfigDelete                                                	*/
/* Creation Date:                                                                	*/
/* Copyright: LFL                                                                	*/
/* Written by:                                                                   	*/
/*                                                                               	*/
/* Purpose:  Delete StorerConfig                                                 	*/
/*                                                                               	*/
/* Return Status:                                                                	*/
/*                                                                               	*/
/* Usage:                                                                        	*/
/*                                                                               	*/
/* Called By: When records Deleted                                               	*/
/*                                                                               	*/
/* PVCS Version: 1.1                                                             	*/
/*                                                                               	*/
/* Version: 5.4                                                                  	*/
/*                                                                               	*/
/* Modifications:                                                                	*/
/* Date         Author        Ver   Purposes                                     	*/
/* 28-Dec-2011  KHLim01       1.0   Initial creation                             	*/
/* 26-Nov-2021  Wan01         1.1   WMS-18410 - [RG] Logitech Tote ID Packing    	*/
/*                                  Change Request                               	*/
/* 26-Nov-2021  Wan01         1.2   DevOps Conbine Script                        	*/
/* 04-Mar-2022  TLTING   		1.3   WMS-19029 prevent bulk update or delete      	*/
/* 2022-04-12   kelvinongcy	1.4   amend way for control user run batch (kocy01)	*/
/************************************************************************************/
  
CREATE   TRIGGER [dbo].[ntrStorerConfigDelete] 
ON [dbo].[StorerConfig]  
FOR DELETE  
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
  
   DECLARE  @b_Success     int,       -- Populated by calls to stored procedures - was the proc successful?  
            @n_err         int,       -- Error number returned by stored procedure or this trigger  
            @c_errmsg      NVARCHAR(250), -- Error message returned by stored procedure or this trigger  
            @n_continue    int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing  
            @n_starttcnt   int,       -- Holds the current transaction count  
            @n_cnt         int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.  
           ,@c_authority   NVARCHAR(1)  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
  
      /* #INCLUDE <TRCONHD1.SQL> */    
   --(Wan01)  - START  
  
   --IF ( (Select count(1) FROM   Deleted  ) > 100 ) 
   --    AND Suser_sname() not in ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM Deleted WITH (NOLOCK) ) > 100 )    --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME()) 
   BEGIN  
        
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62508   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table StorerConfig. Batch delete not allow! (ntrStorerConfigDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
            
   END  
  
  
   IF @n_continue=1 OR @n_continue=2   
   BEGIN  
      IF EXISTS ( SELECT 1 FROM DELETED   
                  WHERE DELETED.Configkey = 'AdvancePackGenCartonNo'  
                  AND DELETED.SValue NOT IN ('0','')  
                  AND DELETED.Facility = ''  
              AND EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK)   
                              WHERE ph.Storerkey = DELETED.Storerkey  
                              AND ph.[Status] < '9' )   
                  UNION    
                  SELECT 1 FROM DELETED   
                  WHERE DELETED.Configkey = 'AdvancePackGenCartonNo'  
                  AND DELETED.SValue NOT IN ('0','')  
                  AND DELETED.Facility <> ''  
                  AND EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK)   
                              JOIN dbo.ORDERS AS o WITH (NOLOCK) ON ph.OrderKey = o.OrderKey AND ph.OrderKey <> ''  
                              WHERE ph.Storerkey = DELETED.Storerkey  
                              AND o.Facility = DELETED.Facility  
                              AND ph.[Status] < '9')  
                  UNION    
                  SELECT 1 FROM DELETED   
                  WHERE DELETED.Configkey = 'AdvancePackGenCartonNo'  
                  AND DELETED.SValue NOT IN ('0','')  
                  AND DELETED.Facility <> ''  
                  AND EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK)   
                              JOIN dbo.LoadPlan AS lp WITH (NOLOCK) ON ph.Loadkey = lp.LoadKey AND ph.OrderKey = ''  
                              WHERE ph.Storerkey = DELETED.Storerkey  
                              AND lp.Facility = DELETED.Facility  
                              AND ph.[Status] < '9')   )  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err=62501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Disallow to change ''AdvancePackGenCartonNo'' setting. Pack Not confirm found. (ntrStorerConfigDelete).'  
      END  
   END  
   --(Wan01) - END  
   --     
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @b_success = 0  
      EXECUTE nspGetRight  NULL,             -- facility    
                           NULL,             -- Storerkey    
                           NULL,             -- Sku    
                           'DataMartDELLOG', -- Configkey    
                           @b_success     OUTPUT,   
                           @c_authority   OUTPUT,   
                           @n_err         OUTPUT,   
                           @c_errmsg      OUTPUT    
      IF @b_success <> 1  
      BEGIN  
         SELECT @n_continue = 3  
               ,@c_errmsg = 'ntrStorerConfigDelete' + dbo.fnc_RTrim(@c_errmsg)  
      END  
      ELSE   
      IF @c_authority = '1'  
      BEGIN  
         INSERT INTO dbo.StorerConfig_DELLOG ( Storerkey, Facility, ConfigKey )  
         SELECT Storerkey, Facility, ConfigKey FROM DELETED  
  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table StorerConfig Failed. (ntrStorerConfigDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
         END  
      END  
   END  
  
      /* #INCLUDE <TRCOND2.SQL> */  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrStorerConfigDelete'  
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