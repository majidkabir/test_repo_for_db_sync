SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO



CREATE TRIGGER [dbo].[ntrJReportFolderUpdate] ON [dbo].[JReportFolder]
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

   DECLARE @b_debug INT
   SELECT @b_debug = 0
   
   DECLARE @n_err       INT       -- Error number returned by stored procedure or this trigger
         , @n_continue  INT
         , @n_starttcnt INT       -- Holds the current transaction count
         , @c_errmsg    NVARCHAR(250)

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT

   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE JReportFolder
         SET EditDate = GETDATE(),
             EditWho  = SUSER_SNAME()
      FROM JReportFolder WITH (NOLOCK), INSERTED WITH (NOLOCK)
      WHERE JReportFolder.StorerKey = INSERTED.StorerKey
      AND   JReportFolder.SecondLvl = INSERTED.SecondLvl
		SELECT @n_err = @@ERROR

		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67890
			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ConfigFlow. (ntrConfigFlowUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
		END
   END


	IF @n_continue = 3  -- Error Occured - Process And Return
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
		RAISERROR (@c_errmsg, 16, 1) WITH LOG
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