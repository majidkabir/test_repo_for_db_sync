SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: ntrCheckUpKPIUpdate                                         */  
/* Creation Date: 21-Oct-2013                                           */  
/* Copyright: LFL                                                       */  
/* Written by: KHLim                                                    */  
/*                                                                      */  
/* Purpose:  CheckUpKPI Update Transaction                              */  
/* Called By: When update records                                       */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */
/* 2017-May-04  KHLim       Skip EditWho/Date when update RunDate (KH01)*/
/************************************************************************/  
  
CREATE TRIGGER [dbo].[ntrCheckUpKPIUpdate]  
ON  [dbo].[CheckUpKPI] FOR UPDATE  
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
  
 DECLARE @b_Success    int       -- Populated by calls to stored procedures - was the proc successful?  
   , @n_err        int       -- Error number returned by stored procedure or this trigger  
   , @n_err2       int       -- For Additional Error Detection  
   , @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
   , @n_continue   int                   
   , @n_starttcnt  int       -- Holds the current transaction count  
   , @c_preprocess NVARCHAR(250) -- preprocess  
   , @c_pstprocess NVARCHAR(250) -- post process  
   , @n_cnt        int                    
  
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
  
 IF UPDATE(LastRunDate) --KH01
 BEGIN          
   SELECT @n_continue = 4          
 END

    /* #INCLUDE <TRTHU1.SQL> */       
 IF @n_continue = 1 or @n_continue=2  
 BEGIN  
  UPDATE CheckUpKPI  
  SET EditDate = GETDATE(),  
      EditWho = SUSER_SNAME()  
  FROM CheckUpKPI (NOLOCK), INSERTED (NOLOCK)  
      WHERE CheckUpKPI.KPI = INSERTED.KPI  
  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
  IF @n_err <> 0  
  BEGIN  
   SELECT @n_continue = 3  
   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table CheckUpKPI. (ntrCheckUpKPIUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
  END  
 END  
  
      /* #INCLUDE <TRTHU2.SQL> */  
 IF @n_continue=3  -- Error Occured - Process And Return  
 BEGIN  
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
  execute nsp_logerror @n_err, @c_errmsg, 'ntrCheckUpKPIUpdate'  
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
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