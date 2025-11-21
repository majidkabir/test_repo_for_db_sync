SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrWITRONLogUpdate                                          */
/* Creation Date: 03-Nov-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: Update EditWho & EditDate in WITRONLog table.               */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  Exceed                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications: Made a copy from ntrTransmitLogUpdate.           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* DD-MMM-YYYY                                                          */
/************************************************************************/

CREATE TRIGGER ntrWITRONLogUpdate
ON  WITRONLOG
FOR UPDATE
AS
BEGIN 
 	IF @@ROWCOUNT = 0
 	BEGIN
 		RETURN
 	END

	SET NOCOUNT ON          -- SQL 2005 Standard
	SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SET @b_debug = 0

   DECLARE   
     @b_Success            int       
   , @n_err                int       
   , @c_errmsg             NVARCHAR(250) 
   , @n_continue           int
   , @n_starttcnt          int
   , @n_cnt                int      

   SET @n_continue = 1 
   SET @n_starttcnt = @@TRANCOUNT
   SET @b_success = 0 

   IF UPDATE(ArchiveCop)
   BEGIN
   	SET @n_continue = 4 
   END
 	
   IF @n_continue = 1 OR @n_continue = 2 
	BEGIN 	
	 	UPDATE WITRONLOG WITH (ROWLOCK) 
    	   SET EditDate = GETDATE(),
     	       EditWho = SUSER_SNAME(),
     	       Trafficcop = NULL
        FROM WITRONLOG, INSERTED
       WHERE WITRONLOG.WITRONLOGKey = INSERTED.WITRONLOGKey

      SET @n_err = @@ERROR
      SET @n_cnt = @@ROWCOUNT

	 	IF @n_err <> 0
    	BEGIN
   	   SET @n_continue = 3
   	   SET @n_err = 68000  
    	   SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) + 
                         ': Update Failed On Table WITRONLOG. (ntrWITRONLogUpdate) ( SQLSvr MESSAGE = ' + 
                         ISNULL(LTrim(RTrim(@c_errmsg)),'') + ' ) '
    	END
	END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ntrWITRONLogUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO