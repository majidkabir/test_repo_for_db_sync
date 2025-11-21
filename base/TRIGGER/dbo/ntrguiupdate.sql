SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrGUIUpdate                                                */
/* Creation Date: 19-Aug-2011                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Handle trigger point of GUI table updates.                  */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  Any related Updates of table GUI.                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Date         Author     Purposes                                     */
/* 28-Oct-2013  TLTING     Review Editdate column update                */
/*                                                                      */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrGUIUpdate]
ON  [dbo].[GUI]
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

   DECLARE   
    @b_Success    int       -- Populated by calls to stored procedures - was the proc successful?
   ,@n_err        int       -- Error number returned by stored procedure or this trigger
   ,@n_err2       int       -- For Additional Error Detection
   ,@c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,@n_continue   int
   ,@n_starttcnt  int       -- Holds the current transaction count
   ,@c_preprocess NVARCHAR(250) -- preprocess
   ,@c_pstprocess NVARCHAR(250) -- post process
   ,@n_cnt int

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END

   IF ( @n_continue = 1 OR @n_continue = 2 )  AND NOT UPDATE(EditDate)
	BEGIN 	
	 	UPDATE GUI WITH (ROWLOCK) 
    	   SET EditDate   = GETDATE(), 
             EditWho    = SUser_SName() 
        FROM GUI
        JOIN INSERTED ON (GUI.InvoiceNo      = INSERTED.InvoiceNo
                      AND GUI.StorerKey      = INSERTED.StorerKey
                      AND GUI.ExternOrderKey = INSERTED.ExternOrderKey) 

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

	 	IF @n_err <> 0
    	BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68001   
    	   SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + 
                            ': Update Failed On Table GUI. (ntrGUIUpdate)' + ' ( ' + 
                            ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
    	END
	END

	/* #INCLUDE <TRRDA2.SQL> */    
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

      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ntrGUIUpdate'    
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