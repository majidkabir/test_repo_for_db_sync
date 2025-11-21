SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE TRIGGER [dbo].[ntrExecDebugUpdate]
ON  [dbo].[ExecDebug]
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

   DECLARE @b_debug int
   SELECT @b_debug = 0
   DECLARE   
     @b_Success            int       
   , @n_err                int       
   , @n_err2               int       
   , @c_errmsg             NVARCHAR(250) 
   , @n_continue           int
   , @n_starttcnt          int
   , @c_preprocess         NVARCHAR(250) 
   , @c_pstprocess         NVARCHAR(250) 
   , @n_cnt                int      

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
	BEGIN 	
	 	UPDATE ExecDebug with (ROWLOCK)
    	   SET EditDate = GETDATE(),
     	       EditWho  = SUSER_SNAME()
        FROM ExecDebug, INSERTED
       WHERE ExecDebug.UserName = INSERTED.UserName

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

	 	IF @n_err <> 0
	    	BEGIN
      	   SELECT @n_continue = 3
       	   SELECT @c_errmsg=CAST(@n_err AS varchar)+': Update ExecDebug Failed (ntrExecDebugUpdate). ERROR_MESSAGE()=' + @c_errmsg
	    	END
	END
END

/*
INSERT dbo.ExecDebug (UserName, Debug, Remark) VALUES ('jimmylim', 1, 'BoonLeongLim@lflogistics.com')

UPDATE dbo.ExecDebug SET Debug = CASE WHEN Debug=1 THEN 0 ELSE 1 END WHERE UserName = SUSER_SNAME()

SELECT * FROM dbo.ExecDebug
*/

GO