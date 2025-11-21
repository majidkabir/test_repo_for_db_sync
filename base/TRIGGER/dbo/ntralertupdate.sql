SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/  
/* Trigger:  ntrAlertUpdate                                                      */
/* Creation Date:                                                                */
/* Copyright: IDS                                                                */
/* Written by:                                                                   */
/*                                                                               */
/* Purpose:  Trigger point upon any Update on the Alert (SOS#240877)             */
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
/* 07-Nov-2012  NJOW01    1.0   257259-Auto delete releted TM CC task when       */
/*                              manually close alert.                            */
/*********************************************************************************/  

CREATE TRIGGER [dbo].[ntrAlertUpdate]
ON  [dbo].[ALERT]
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
         , @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         , @n_continue           int                 
         , @n_starttcnt          int       -- Holds the current transaction count
         , @c_TrafficCop         NCHAR(1)
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT      

   SELECT @c_TrafficCop = TrafficCop
   FROM INSERTED
   
   IF UPDATE(TrafficCop) AND @c_TrafficCop <> 'T'
   BEGIN
      SELECT @n_continue = 4 
   END

   IF (@n_continue = 1 or @n_continue = 2) AND UPDATE(Status)
   BEGIN
   	  IF EXISTS(SELECT * FROM INSERTED JOIN DELETED ON INSERTED.Alertkey = DELETED.Alertkey 
   	            WHERE INSERTED.Status <> DELETED.Status
   	            AND INSERTED.Status = '9')
   	  BEGIN
   	  	 UPDATE ALERT WITH (ROWLOCK)
   	  	 SET ALERT.Notifyid = SUSER_SNAME(),
   	  	     ALERT.Resolvedate = GETDATE(),
   	  	     ALERT.TrafficCop = NULL
   	  	 FROM ALERT JOIN INSERTED ON ALERT.Alertkey = INSERTED.Alertkey

         --NJOW01
         IF @c_TrafficCop <> 'T'
         BEGIN         	          	
   	  	   DELETE TASKDETAIL
   	  	   FROM TASKDETAIL 
   	  	   JOIN INSERTED ON INSERTED.Taskdetailkey2 = TASKDETAIL.Taskdetailkey
   	  	   WHERE TASKDETAIL.Listkey = 'ALERT' 
   	  	   AND TASKDETAIL.Sourcetype = 'TMCCRLSE'
   	  	   AND TASKDETAIL.Status NOT IN('9','X')
   	  	   AND NOT EXISTS (SELECT 1 FROM ALERT (NOLOCK) 
   	  	                   JOIN INSERTED ON ALERT.Taskdetailkey2 = INSERTED.Taskdetailkey2 
   	  	                                    AND ALERT.Alertkey <> INSERTED.Alertkey
   	  	                   WHERE ALERT.Status <> '9' 
   	  	                   AND ISNULL(ALERT.Taskdetailkey2,'') <> '')
   	  	 END
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrAlertUpdate'
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