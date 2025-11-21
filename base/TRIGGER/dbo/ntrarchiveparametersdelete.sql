SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/
/* Trigger:  ntrARCHIVEPARAMETERSDelete                                          */
/* Creation Date:                                                                */
/* Copyright: IDS                                                                */
/* Written by: kelvinongcy                                                       */
/*                                                                               */
/* Purpose:  Trigger point upon any Delete on the ARCHIVEPARAMETERS              */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date         Author        Ver.  Purposes                                     */
/* 2022-08-18   kelvinongcy   1.0   Capture deletion to archiveparameters_log    */
/*                                  and not dellog due could reused same table   */
/*********************************************************************************/
 
CREATE   TRIGGER [dbo].[ntrARCHIVEPARAMETERSDelete]
 ON [dbo].[ARCHIVEPARAMETERS]
 FOR DELETE
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

   DECLARE @b_Success         int,       -- Populated by calls to stored procedures - was the proc successful?
           @n_err             int,       -- Error number returned by stored procedure or this trigger
           @c_errmsg          NVARCHAR(250), -- Error message returned by stored procedure or this trigger
           @n_continue        int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
           @n_starttcnt       int,       -- Holds the current transaction count
           @n_cnt             int,        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
           @c_authority       NVARCHAR(1)  -- KHLim02
           
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

      /* #INCLUDE <TRTHD1.SQL> */      
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrARCHIVEPARAMETERSDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.ARCHIVEPARAMETERS_LOG (ArchiveKey)
         SELECT ArchiveKey
         FROM DELETED WITH (NOLOCK)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Err message but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table ARCHIVEPARAMETERS Failed. (ntrARCHIVEPARAMETERSDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END

      /* #INCLUDE <TRTHD2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrARCHIVEPARAMETERSDelete"
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