SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrCMSLogUpdate                                             */
/* Creation Date: 04-Mar-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: Update EditWho & EditDate in CMSLog table.                  */
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
/* 28-Oct-2013  TLTING    1.1   Review Editdate column update           */
/* dd-mmm-yyyy                                                          */
/************************************************************************/

CREATE TRIGGER ntrCMSLogUpdate
ON  CMSLOG
FOR UPDATE
AS
BEGIN 
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
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
 	
   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate) 
   BEGIN 	
      UPDATE CMSLOG WITH (ROWLOCK) 
    	   SET EditDate = GETDATE(),
     	       EditWho = SUSER_SNAME(),
     	       Trafficcop = NULL
        FROM CMSLOG, INSERTED
       WHERE CMSLOG.CMSLOGKey = INSERTED.CMSLOGKey

      SET @n_err = @@ERROR
      SET @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 68000  
    	   SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                       + ': Update Failed On Table CMSLOG. (ntrCMSLogUpdate)' 
                       + ' ( SQLSvr MESSAGE = ' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
    	END
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ntrCMSLogUpdate'
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