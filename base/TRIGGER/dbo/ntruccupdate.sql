SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger: ntrUCCUpdate                                                */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  Update UCC.                                                */  
/*                                                                      */  
/* Return Status:                                                       */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: When records Updated                                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Modifications:                                                       */  
/* Date         Author   Ver  Purposes                                  */  
/* 07-Jun-2012 KHLim01   1.1  prefix rdt. if come from RDT              */
/* 24-08-2012  ChewKP    1.2  SOS#253989 Update UCC information to      */  
/*                            Traceinfo (ChewKP01)                      */
/* 28-Oct-2013 TLTING    1.3  Review Editdate column update             */
/* 01-11-2013  Shong     1.3  Remove TraceInfo and Do not update        */
/*                            EditDate if already update                */  
/* 16-05-2014  TLTING    1.3  New primary key UCC_RowRef                */  
/* 19-08-2014  TLTING    1.4  Add ArchiveCop & TrrafficCop              */  
/************************************************************************/  
CREATE TRIGGER [dbo].[ntrUCCUpdate]  
ON  [dbo].[UCC]   
FOR UPDATE  
AS  
BEGIN  
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET ANSI_WARNINGS OFF  
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
         , @n_IsRDT INT            -- KHLim01
         , @c_PreUN varchar(5)     -- KHLim01
           
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  

   IF UPDATE(ArchiveCop)      --KH01
   BEGIN
      SELECT @n_continue = 4
   END

   IF UPDATE(TrafficCop)      --KH01
   BEGIN
      SELECT @n_continue = 4
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND NOT UPDATE(EditDate)  
   BEGIN 
      -- KHLim01 start
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
      IF @n_IsRDT = 1 
      BEGIN
         SET @c_PreUN = 'rdt.' 
      END
      ELSE
      BEGIN
         SET @c_PreUN = ''
      END
      -- KHLim01 end
             
      UPDATE UCC  with (RowLock)
         SET EditDate = GETDATE(),  
             EditWho = @c_PreUN + SUSER_SNAME() -- KHLim01
        FROM UCC, INSERTED  
       WHERE UCC.UCC_RowRef = INSERTED.UCC_RowRef
 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85803   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))  
                         +': Update Failed On Table UCC. (ntrUCCUpdate)' + ' ( '   
                         +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
      END  
   END  
   /* END Added */
  
 
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
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrUCCUpdate'  
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