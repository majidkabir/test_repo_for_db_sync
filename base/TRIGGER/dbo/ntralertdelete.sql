SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/  
/* Trigger:  ntrAlertDelete                                                      */
/* Creation Date:                                                                */
/* Copyright: IDS                                                                */
/* Written by:                                                                   */
/*                                                                               */
/* Purpose:  Trigger point upon any delete on the Alert (SOS#257259)             */
/*                                                                               */
/* Return Status:  None                                                          */
/*                                                                               */
/* Usage:                                                                        */
/*                                                                               */
/* Local Variables:                                                              */
/*                                                                               */
/* Called By: When records deleted                                               */
/*                                                                               */
/* PVCS Version: 1.0                                                             */
/*                                                                               */
/* Version: 5.4                                                                  */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date         Author    Ver.  Purposes                                         */
/*********************************************************************************/  

CREATE TRIGGER [dbo].[ntrAlertDelete]
ON  [dbo].[ALERT]
FOR DELETE
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
         
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4 
   END

   IF (@n_continue = 1 or @n_continue = 2) 
   BEGIN
   	  DELETE TASKDETAIL 
   	  FROM TASKDETAIL 
   	  JOIN DELETED ON DELETED.Taskdetailkey2 = TASKDETAIL.Taskdetailkey
   	  WHERE TASKDETAIL.Listkey = 'ALERT' 
   	  AND TASKDETAIL.Sourcetype = 'TMCCRLSE'
   	  AND TASKDETAIL.Status NOT IN('9','X')
   	  AND NOT EXISTS (SELECT 1 FROM ALERT (NOLOCK) 
   	                  JOIN DELETED ON ALERT.Taskdetailkey2 = DELETED.Taskdetailkey2 
   	                                   AND ALERT.Alertkey <> DELETED.Alertkey
   	                  WHERE ALERT.Status <> '9' 
   	                  AND ISNULL(ALERT.Taskdetailkey2,'') <> '')
                      
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrAlertDelete'
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