SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Trigger: ntrGWPTrackUpdate                                              */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:  trace modified log                                            */  
/* Called By: When update records                                          */  
/*                                                                         */   
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver.  Purposes                                     */  
/* 31-03-21     kocy  1.0    Updates EditDate & EditWho                    */
/*                            On GWPTrack Table                            */ 
/***************************************************************************/ 

CREATE TRIGGER [dbo].[ntrGWPTrackUpdate]
ON [dbo].[GWPTrack] FOR UPDATE
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
         , @c_errmsg     char(250) -- Error message returned by stored procedure or this trigger  
         , @n_continue   int                   
         , @n_starttcnt  int       -- Holds the current transaction count  
         , @c_preprocess char(250) -- preprocess  
         , @c_pstprocess char(250) -- post process  
         , @n_cnt        int

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  

   --IF UPDATE(ArchiveCop)    
   --BEGIN    
   --   SELECT @n_continue = 4     
   --END    
  
   IF ( @n_continue = 1 or @n_continue=2 )
   BEGIN  
      UPDATE [dbo].[GWPTrack]  
      SET EditDate = GETDATE(),  
          EditWho = SUSER_SNAME()  
      FROM [dbo].[GWPTrack] WITH (NOLOCK), INSERTED (NOLOCK)  
      WHERE [dbo].[GWPTrack].RefNo = INSERTED.RefNo 
      AND [dbo].[GWPTrack].GiftCode = INSERTED.GiftCode
      AND [dbo].[GWPTrack].GiftFlag = INSERTED.GiftFlag

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

       IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table GWPTrack. (ntrGWPTrackUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      END
   END

 --  IF UPDATE(TrafficCop)
	--BEGIN
	--	SELECT @n_continue = 4 
	--END

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
      execute nsp_logerror @n_err, @c_errmsg, 'ntrGWPTrackUpdate'  
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