SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger:  ntrPalletDetailDelete                                         */
/* Creation Date:                                                          */
/* Copyright: Maersk                                                       */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:  Trigger point upon any Delete on the Container                */
/*                                                                         */
/* Return Status:  None                                                    */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: When records Deleted                                         */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 09-Oct-2012  KHLim     1.0   Insert Delete log (KH01)                   */
/* 12-Dec-2018  NJOW01    1.1   WMS-7187 allow supervisor delete carton    */
/* 15-Jun-2020  TLTING01  1.2   bug fix archive skip check                 */
/* 07-Feb-2024  Wan01     1.3   UWP-14785-UNABLE TO DELETE PALLET MANIFEST */
/***************************************************************************/

CREATE   TRIGGER [dbo].[ntrPalletDetailDelete]
 ON [dbo].[PALLETDETAIL]
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

 DECLARE @b_Success       int,       -- Populated by calls to stored procedures - was the proc successful?
 @n_err              int,       -- Error number returned by stored procedure or this trigger
 @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
 @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
 @n_starttcnt        int,       -- Holds the current transaction count
 @n_cnt              INT,       -- Holds the number of rows affected by the DELETE statement that fired this trigger.
 @c_authority        nvarchar(1),  -- KH01
 @c_issupervisor NVARCHAR(10), --NJOW01
 @c_Username NVARCHAR(128) --NJOW01                                                 --(Wan01)

 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
 if (select count(*) from DELETED) =
 (select count(*) from DELETED where DELETED.ArchiveCop = '9')
 BEGIN
 SELECT @n_continue = 4
 END
      /* #INCLUDE <TRPALDD1.SQL> */     
 
   IF @n_continue=1 or @n_continue=2
   BEGIN
      --NJOW01
      SET @c_issupervisor = 'N'
      SET @c_username = SUSER_SNAME()
      EXEC isp_CheckSupervisorRole
           @c_username  = @c_username
          ,@c_Flag     = @c_issupervisor OUTPUT
          ,@b_Success  = @b_success      OUTPUT  
          ,@n_Err      = @n_err          OUTPUT  
          ,@c_ErrMsg   = @c_errmsg       OUTPUT
         
      IF @n_continue=1 or @n_continue=2
      BEGIN           
        IF EXISTS (SELECT * FROM PALLET, DELETED
                   WHERE PALLET.PalletKey = DELETED.PalletKey
                   AND PALLET.Status = "9")
           AND ISNULL(@c_issupervisor,'N') <> 'Y'  --NJOW01
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err=67800
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": PALLET.Status = 'SHIPPED'. DELETE rejected. (ntrPalletDetailDelete)"
        END
      END
   END 
   
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF EXISTS (SELECT * FROM DELETED
                 WHERE DELETED.Status = "9")
         AND ISNULL(@c_issupervisor,'N') <> 'Y'  --NJOW01      
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err=67800
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": PALLET.Status = 'SHIPPED'. DELETE rejected. (ntrPalletDetailDelete)"
      END
   END
 
   IF @n_continue = 1 or @n_continue = 2  --KH01 start
   BEGIN
      SELECT @b_success = 0
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
               ,@c_errmsg = 'ntrPalletDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'
      BEGIN
         INSERT INTO dbo.PALLETDETAIL_DELLOG ( PalletKey, PalletLineNumber )
         SELECT PalletKey, PalletLineNumber FROM DELETED
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 67801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PALLETDETAIL Failed. (ntrPalletDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END   --KH01 end

      /* #INCLUDE <TRPALDD2.SQL> */
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
 EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrPalletDetailDelete"
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