SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 08-Oct-2012  KHLim      Insert Delete log (KH01)                          */
/* 22-Aug-2016  TLTING     add NOLOCK - deadlock                             */
/* 20-May-2020  TLTING02   Cursor loop by row - deadlock                     */

CREATE TRIGGER [dbo].[ntrContainerDetailDelete]
 ON [dbo].[CONTAINERDETAIL]
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
 @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
,@c_authority        nvarchar(1)  -- KH01

DECLARE @c_MbolKey NVARCHAR(10) = ''
, @c_MbolLineNumber NVARCHAR(5) = ''

 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
 if (select count(*) from DELETED) =
 (select count(*) from DELETED where DELETED.ArchiveCop = '9')
 BEGIN
 SELECT @n_continue = 4
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
               ,@c_errmsg = 'ntrContainerDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'
      BEGIN
         INSERT INTO dbo.CONTAINERDETAIL_DELLOG ( ContainerKey, ContainerLineNumber )
         SELECT ContainerKey, ContainerLineNumber FROM DELETED
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68403   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table CONTAINER Failed. (ntrContainerDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END   --KH01 end

   
 /* #INCLUDE <TRCONDD1.SQL> */     
 IF @n_continue=1 or @n_continue=2
 BEGIN
 IF EXISTS (SELECT * FROM CONTAINER with (NOLOCK), DELETED
 WHERE CONTAINER.ContainerKey = DELETED.ContainerKey
 AND CONTAINER.Status = "9")
 BEGIN
 SELECT @n_continue = 3
 SELECT @n_err=68400
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": CONTAINER.Status = 'SHIPPED'. DELETE rejected. (ntrContainerDetailDelete)"
 END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
   -- TLTING02
   IF EXISTS (	SELECT 1   FROM MbolDetail  with (NOLOCK), Mbol with (NOLOCK), DELETED
             WHERE MbolDetail.ContainerKey = DELETED.ContainerKey
             AND Mbol.MbolKey = MbolDetail.MbolKey
             AND Mbol.Status <> '9'	 )
   Begin 
	   DECLARE MBOLItem_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		   Select MbolDetail.MbolKey, MbolDetail.MbolLineNumber
		   FROM MbolDetail  with (NOLOCK), Mbol with (NOLOCK), DELETED
         WHERE MbolDetail.ContainerKey = DELETED.ContainerKey
         AND Mbol.MbolKey = MbolDetail.MbolKey
         AND Mbol.Status <> '9'	 

	   OPEN MBOLItem_cur 
	   FETCH NEXT FROM MBOLItem_cur INTO @c_MbolKey, @c_MbolLineNumber
	   WHILE @@FETCH_STATUS = 0 
	   BEGIN 

		   DELETE MbolDetail
         WHERE MbolKey = @c_MbolKey
         AND MbolLineNumber = @c_MbolLineNumber
          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
          IF @n_err <> 0
          BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68402   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cascade Delete ON Table MbolDetail Failed. (ntrContainerDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
          END		
		   FETCH NEXT FROM MBOLItem_cur INTO @c_MbolKey, @c_MbolLineNumber
	   END
	   CLOSE MBOLItem_cur 
	   DEALLOCATE MBOLItem_cur
   End
 END
      /* #INCLUDE <TRCONDD2.SQL> */
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
 EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrContainerDetailDelete"
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