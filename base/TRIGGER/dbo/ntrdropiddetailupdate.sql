SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Trigger: ntrDropidDetailUpdate                                             */  
/* Creation Date: 24 May 2012                                                 */  
/* Copyright: IDS                                                             */  
/* Written by: KHLim                                                          */  
/*                                                                            */  
/* Purpose:  Update DropidDetail.                                             */  
/*                                                                            */  
/* Return Status:                                                             */  
/*                                                                            */  
/* Usage:                                                                     */  
/*                                                                            */  
/* Called By: When records Updated                                            */  
/*                                                                            */  
/* PVCS Version: 1.3                                                          */  
/*                                                                            */  
/* Version: 5.4                                                               */  
/*                                                                            */  
/* Modifications:                                                             */  
/* Date         Author   Ver  Purposes                                        */  
/* 06-Sep-2012  KHLim    1.1  Move up ArchiveCop (KH01)                       */
/* 28-Oct-2013  TLTING   1.2  Review Editdate column update                   */
/* 03-Dec-2014  KHLim    1.3  Remove SET ANSI_WARNINGS OFF to avoid recompile */
/******************************************************************************/  
  
CREATE TRIGGER [dbo].[ntrDropidDetailUpdate]  
ON  [dbo].[DropidDetail]   
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
   IF UPDATE(ArchiveCop)      --KH01
   BEGIN          
      SELECT @n_continue = 4          
   END

   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN  
      UPDATE DropidDetail with (ROWLOCK) 
         SET EditDate = GETDATE(),  
             EditWho = SUSER_SNAME(),  
             TrafficCop = NULL  
        FROM DropidDetail, INSERTED  
       WHERE DropidDetail.Dropid    = INSERTED.Dropid
         AND DropidDetail.ChildId   = INSERTED.ChildId

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))  
                         +': Update Failed On Table DropidDetail. (ntrDropidDetailUpdate)' + ' ( '   
                         +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
      END  
   END  
  
   IF UPDATE(TrafficCop)  
   BEGIN  
      SELECT @n_continue = 4   
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
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrDropidDetailUpdate'  
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