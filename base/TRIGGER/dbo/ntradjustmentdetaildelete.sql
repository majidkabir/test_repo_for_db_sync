SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Trigger: ntrAdjustmentDetailDelete                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: When records delete from AdjustmentDetail                 */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 15-Jul-2004  June          SOS25237 Not allow deletion if finalized  */
/* 06-Jun-2005  Shong         Reindent codes                            */
/* 19-Oct-2006  MaryVong      Add in RDT compatible error messages      */
/* 27-Apr-2011  KHLim01       Insert Delete log                         */
/* 14-Jul-2011  KHLim02       GetRight for Delete log                   */
/* 22-May-2012  TLTING02      DM Data integrity - insert dellog 4       */
/*                            status < '9'                              */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrAdjustmentDetailDelete]
ON [dbo].[ADJUSTMENTDETAIL]
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
   
   DECLARE @b_Success  int,       -- Populated by calls to stored procedures - was the proc successful?
   @n_err              int,       -- Error number returned by stored procedure or this trigger
   @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
   @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
   @n_starttcnt        int,       -- Holds the current transaction count
   @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
  ,@c_authority        NVARCHAR(1)  -- KHLim02


   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   if (select count(*) from DELETED) =
      (select count(*) from DELETED where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END
   
   -- tlting02
   IF EXISTS ( SELECT 1 FROM DELETED WHERE  FinalizedFlag <> 'Y') AND ( @n_continue = 1 or @n_continue = 2 )
   BEGIN
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
                  ,@c_errmsg = 'ntrAdjustmentDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
         END
         ELSE 
         IF @c_authority = '1'         --    End   (KHLim02)
         BEGIN
            INSERT INTO dbo.ADJUSTMENTDETAIL_DELLOG ( AdjustmentKey, AdjustmentLineNumber )
            SELECT AdjustmentKey, AdjustmentLineNumber FROM DELETED
            WHERE  FinalizedFlag <> 'Y'

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table ADJUSTMENTDETAIL Failed. (ntrAdjustmentDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
            END
         END
      END
   END

   /* #INCLUDE <TRADD1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- SELECT @n_continue = 3
      SELECT @n_err = 62726 --67201
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': DELETE not allowed. (ntrAdjustmentDetailDelete)'
   END

   -- Start : Add by June 15.Jul.2004 (SOS25237)
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF EXISTS ( SELECT *
      FROM  DELETED
      WHERE FinalizedFlag = "Y" )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62727 --70101
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Posted rows may not be deleted. (ntrAdjustmentDetailDelete)'
      END
   END
   -- End : SOS25237

   /* #INCLUDE <TRADD2.SQL> */   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide
   
         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN
   
         -- Raise error with severity = 10, instead of the default severity 16. 
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR 
   
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrAdjustmentDetailDelete'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
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