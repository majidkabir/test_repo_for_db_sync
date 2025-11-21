SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 /***********************************************************************************/    
/* Trigger:  ntrStorerDelete                                                        */  
/* Creation Date:                                                                   */  
/* Copyright: IDS                                                                   */  
/* Written by:                                                                      */  
/*                                                                                  */  
/* Purpose:  Trigger point upon any Delete on the Storer                            */  
/*                                                                                  */  
/* Return Status:  None                                                             */  
/*                                                                                  */  
/* Usage:                                                                           */  
/*                                                                                  */  
/* Local Variables:                                                                 */  
/*                                                                                  */  
/* Called By: When records Deleted                                                  */  
/*                                                                                  */  
/* PVCS Version: 1.0                                                                */  
/*                                                                                  */  
/* Version: 5.4                                                                     */  
/*                                                                                  */  
/* Data Modifications:                                                              */  
/*                                                                                  */  
/* Updates:                                                                         */  
/* Date         Author        Ver.  Purposes                                        */  
/* 14-Jan-2003  YokeBeen      1.1   SOS#8859                                        */   
/* 14-Jul-2011  KHLim02       1.2   for GetRight for Delete log                     */  
/* 04-Mar-2022  TLTING        1.3   prevent bulk Delete                             */
/* 2022-04-12   kelvinongcy	1.8   amend way for control user run batch (kocy01)   */
/************************************************************************************/    
    
CREATE   TRIGGER [dbo].[ntrStorerDelete]  
ON [dbo].[STORER]  
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
  
   DECLARE @b_Success  int,       -- Populated by calls to stored procedures - was the proc successful?  
   @n_err              int,       -- Error number returned by stored procedure or this trigger  
   @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger  
   @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing  
   @n_starttcnt        int,       -- Holds the current transaction count  
   @n_cnt              int,        -- Holds the number of rows affected by the DELETE statement that fired this trigger.  
   @c_authority       NVARCHAR(1)  -- KHLim02  
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
     /* #INCLUDE <TRRHD1.SQL> */       
  
   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN  
      SELECT @n_continue = 4  
   END  
  
   --IF ( (Select count(1) FROM   Deleted  ) > 100 ) 
   --    AND Suser_sname() not in ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM Deleted WITH (NOLOCK) ) > 100 )    --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME()) 
   BEGIN        
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63908   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Failed On Table Storer. Batch Delete not allow! (ntrStorerDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "  
   END  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      DELETE STORERBILLING FROM STORERBILLING, DELETED  
      WHERE STORERBILLING.StorerKey = DELETED.StorerKey  
    
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
      IF @n_err <> 0  
      BEGIN  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63901   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table STORERBILLING Failed. (ntrStorerDelete) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      END  
  
      DELETE STORERSODEFAULT FROM STORERSODEFAULT, DELETED  
      WHERE STORERSODEFAULT.StorerKey = DELETED.StorerKey  
 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
      IF @n_err <> 0  
      BEGIN  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table STORERSODEFAULT Failed. (ntrStorerDelete) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      END  
  
      DELETE STORERConfig FROM STORERConfig, DELETED  
      WHERE STORERConfig.StorerKey = DELETED.StorerKey   
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
      IF @n_err <> 0  
      BEGIN  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table STORERCONFIG Failed. (ntrStorerDelete) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      END  
   END  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @b_success = 0         --    Start (KHLim02)  
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
               ,@c_errmsg = 'ntrStorerDelete' + dbo.fnc_RTrim(@c_errmsg)  
      END  
      ELSE   
      IF @c_authority = '1'         --    End   (KHLim02)  
      BEGIN  
         INSERT INTO dbo.STORER_DELLOG ( StorerKey )  
         SELECT StorerKey FROM DELETED  
  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0  
         BEGIN  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table STORER Failed. (ntrStorerDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
         END  
      END  
   END  
  
     /* #INCLUDE <TRRHD2.SQL> */  
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
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrStorerDelete'  
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