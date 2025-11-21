SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*********************************************************************************/    
/* Trigger:  ntrDeviceProfileLogUpdate                                           */  
/* Creation Date:                                                                */  
/* Copyright: IDS                                                                */  
/* Written by:                                                                   */  
/*                                                                               */  
/* Purpose:  Trigger point upon any Update on the DeviceProfileLog               */  
/*                                                                               */  
/* Return Status:  None                                                          */  
/*                                                                               */  
/* Usage:                                                                        */  
/*                                                                               */  
/* Local Variables:                                                              */  
/*                                                                               */  
/* Called By: When records updated                                               */  
/*                                                                               */  
/* PVCS Version: 1.0                                                             */  
/*                                                                               */  
/* Version: 5.4                                                                  */  
/*                                                                               */  
/* Data Modifications:                                                           */  
/*                                                                               */  
/* Updates:                                                                      */  
/* Date         Author    Ver.  Purposes                                         */ 
/* 28-Oct-2013  TLTING    1.1  Review Editdate column update                     */ 
/*********************************************************************************/    
  
CREATE TRIGGER [dbo].[ntrDeviceProfileLogUpdate]  
ON  [dbo].[DeviceProfileLog]  
FOR UPDATE  
AS  
BEGIN -- main  
   IF @@ROWCOUNT = 0    
   BEGIN    
      RETURN    
   END       
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err                int       -- Error number returned by stored procedure or this trigger  
         , @c_errmsg             nvarchar(250) -- Error message returned by stored procedure or this trigger  
         , @n_continue           int                   
         , @n_starttcnt          int       -- Holds the current transaction count  
         , @n_cnt                int  
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT, @n_cnt = 0  
  
   IF UPDATE(TrafficCop)  
   BEGIN  
      SELECT @n_continue = 4   
   END  
  
   IF (@n_continue = 1 or @n_continue = 2) AND NOT UPDATE(EditDate)   
   BEGIN  
     UPDATE DeviceProfileLog WITH (ROWLOCK)  
     SET DeviceProfileLog.EditWho = SUSER_SNAME(),  
         DeviceProfileLog.EditDate = GETDATE()  
     FROM DeviceProfileLog JOIN INSERTED ON DeviceProfileLog.DeviceProfileKey = INSERTED.DeviceProfileKey  
                                          AND DeviceProfileLog.OrderKey = INSERTED.OrderKey  
                                          AND DeviceProfileLog.DropID = INSERTED.DropID  
       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 82202   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On Table DeviceProfileLog Failed. (ntrDeviceProfileLogDelete)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "  
       END  
   END  
  
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrDeviceProfileLogUpdate'  
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
END -- main  

GO