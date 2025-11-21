SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[ispArchiveKitting]
	@c_archivekey NVARCHAR(10),
	@b_Success      int        OUTPUT,    
	@n_err          int        OUTPUT,    
	@c_errmsg       NVARCHAR(250)  OUTPUT    
AS
BEGIN  
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE        @n_continue int        ,  
		@n_starttcnt int        , -- Holds the current Transaction count
		@n_cnt int              , -- Holds @@ROWCOUNT after certain operations
		@b_debug int              -- Debug On Or Off
		   /* #INCLUDE <SPATran1.SQL> */     
	DECLARE        @n_retain_days int      , -- days to hold data
		@d_Trandate  datetime     , -- Tran Date from Tran header table
		@d_result  datetime     , -- date Tran_date - (getdate() - noofdaystoretain
		@c_datetype NVARCHAR(10),      -- 1=TranDATE, 2=EditDate, 3=AddDate
		@n_archive_Kit_records   int, -- # of Tran records to be archived
		@n_archive_Kit_detail_records   int -- # of Kit_detail records to be archived
	DECLARE        @local_n_err         int,
		@local_c_errmsg    NVARCHAR(254)
	DECLARE        @c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55), 
		@c_tranActive NVARCHAR(2),
		@c_whereclause NVARCHAR(254),
		@c_temp NVARCHAR(254),
		@CopyRowsToArchiveDatabase NVARCHAR(1)
	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0 , @local_n_err = 0, @local_c_errmsg = ' '
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		SELECT @c_temp = "Archive Of Kit Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
			' ; Active = '+ dbo.fnc_RTrim(@c_TranActive) +
			' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) + ' ; Retain Days = '+ convert(char(6),@n_retain_days)
		EXECUTE nspLogAlert
			@c_ModuleName   = "ispArchiveKitting",
			@c_AlertMessage = @c_temp,
			@n_Severity     = 0,
			@b_success       = @b_success OUTPUT,
			@n_err          = @n_err OUTPUT,
			@c_errmsg       = @c_errmsg OUTPUT
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT  @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
			@n_retain_days = Trannumberofdaystoretain,
			@c_datetype = Transferdatetype,
			@c_TranActive = TranActive,
			@CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
		FROM ArchiveParameters (nolock)
		WHERE archivekey = @c_archivekey
		SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
		SELECT @d_result = dateadd(day,1,@d_result)
		IF db_id(@c_copyto_db) is NULL
		BEGIN
			SELECT @n_continue = 3
			SELECT @local_n_err = 73701
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
				": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + " (ispArchiveKitting)"
		END
	END
	
	IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
	BEGIN 
		select @b_success = 1
		EXEC nsp_BUILD_ARCHIVE_TABLE 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'Kit',
			@b_success OUTPUT, 
			@n_err OUTPUT, 
			@c_errmsg OUTPUT
		IF not @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END   
	
	IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
	BEGIN  
		SELECT @b_success = 1
		EXEC nsp_BUILD_ARCHIVE_TABLE 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'KitDetail',
			@b_success OUTPUT, 
			@n_err OUTPUT, 
			@c_errmsg OUTPUT
		IF not @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END     
	
	IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
	BEGIN
		IF (@b_debug = 1)
		BEGIN
			print 'building alter table string for Kit...'
		END
		EXECUTE nspBuildAlterTableString 
			@c_copyto_db,
			'Kit',
			@b_success OUTPUT,
			@n_err OUTPUT, 
			@c_errmsg OUTPUT
		IF not @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END
	
	IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
	BEGIN
		IF (@b_debug = 1)
		BEGIN
			print 'building alter table string for KitDetail...'
		END
		EXECUTE nspBuildAlterTableString 
			@c_copyto_db,
			'KitDetail',
			@b_success OUTPUT,
			@n_err OUTPUT, 
			@c_errmsg OUTPUT
		IF not @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END
	
	IF ((@n_continue = 1 or @n_continue = 2 ) and @CopyRowsToArchiveDatabase = 'Y')
	BEGIN
		BEGIN TRAN
		SELECT @c_whereclause = "UPDATE Kit SET Archivecop = '9' WHERE Kit.AddDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' +  " and Kit.Status = '9' "
		EXECUTE (@c_whereclause)
		SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		SELECT @n_archive_Kit_records = @n_cnt
		IF @local_n_err <> 0
		BEGIN 
			SELECT @n_continue = 3
			SELECT @local_n_err = 77201
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
				": Update of Archivecop failed - Kit. (ispArchiveKitting) " + " ( " +
				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		END  
	END 
	
	IF (@n_continue = 1 or @n_continue = 2)
	BEGIN 
		UPDATE KitDetail
		Set KitDetail.Archivecop = '9'
		FROM KitDetail , Kit
		Where ((KitDetail.KitKey = Kit.KitKey) and (Kit.archivecop = '9'))
		SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		SELECT @n_archive_Kit_detail_records = @n_cnt
		IF @local_n_err <> 0
		BEGIN 
			SELECT @n_continue = 3
			SELECT @local_n_err = 77202
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
				": Update of Archivecop failed - KitDetail. (ispArchiveKitting) " + " ( " +
				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		END  
	END 
	
	IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
	BEGIN
		SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_Kit_records )) +
			" Kit records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_Kit_detail_records )) + " KitDetail records"
		EXECUTE nspLogAlert
			@c_ModuleName   = "ispArchiveKitting",
			@c_AlertMessage = @c_Temp ,
			@n_Severity     = 0,
			@b_success       = @b_success OUTPUT,
			@n_err          = @n_err OUTPUT,
			@c_errmsg       = @c_errmsg OUTPUT
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN   
		SELECT @b_success = 1
		EXEC nsp_BUILD_INSERT  
			@c_copyto_db, 
			'Kit',
			1,
			@b_success OUTPUT, 
			@n_err OUTPUT, 
			@c_errmsg OUTPUT
		IF not @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END   
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN 
		SELECT @b_success = 1
		EXEC nsp_BUILD_INSERT   
			@c_copyto_db, 
			'KitDetail',
			1,
			@b_success OUTPUT, 
			@n_err OUTPUT, 
			@c_errmsg OUTPUT
		IF not @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END   
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN  
		IF (@b_debug = 0)
		BEGIN
			DELETE FROM Kit
			WHERE ARCHIVECOP = '9'
			SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		END
		IF (@b_debug = 1)
		BEGIN
			SELECT * FROM Kit (nolock)
			WHERE ARCHIVECOP = '9'
		END
		IF @local_n_err <> 0
		BEGIN  
			SELECT @n_continue = 3
			SELECT @local_n_err = 77203
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
				":  Kit delete failed. (ispArchiveKitting) " + " ( " +
				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		END      
	END    
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN  
		IF (@b_debug = 0)
		BEGIN
			DELETE FROM KitDetail
			WHERE ARCHIVECOP = '9'
			SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		END
		IF (@b_debug = 1)
		BEGIN
			SELECT * FROM KitDetail (nolock)
			WHERE ARCHIVECOP = '9'
		END
		IF @local_n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @local_n_err = 77204
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
				":  KitDetail delete failed. (ispArchiveKitting) " + " ( " +
				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		END
	END       
	
	IF @n_continue = 3
	BEGIN
		ROLLBACK TRAN
	END
	ELSE
	BEGIN
		COMMIT TRAN
	END
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		EXECUTE nspLogAlert
			@c_ModuleName   = "ispArchiveKitting",
			@c_AlertMessage = "Archive Of Kit Ended Normally.",
			@n_Severity     = 0,
			@b_success       = @b_success OUTPUT,
			@n_err          = @n_err OUTPUT,
			@c_errmsg       = @c_errmsg OUTPUT
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END
	ELSE
	BEGIN
		IF @n_continue = 3
		BEGIN
			SELECT @b_success = 1
			EXECUTE nspLogAlert
				@c_ModuleName   = "ispArchiveKitting",
				@c_AlertMessage = "Archive Of Kit Ended Abnormally - Check This Log For Additional Messages.",
				@n_Severity     = 0,
				@b_success       = @b_success OUTPUT,
				@n_err          = @n_err OUTPUT,
				@c_errmsg       = @c_errmsg OUTPUT
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END
	END
	   
		/* #INCLUDE <SPATran2.SQL> */     
	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		SELECT @b_success = 0
		IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
	SELECT @n_err = @local_n_err
	SELECT @c_errmsg = @local_c_errmsg
	IF (@b_debug = 1)
	BEGIN
		SELECT @n_err,@c_errmsg, 'before putting in nsp_logerr at the bottom'
	END
	EXECUTE nsp_logerror @n_err, @c_errmsg, "ispArchiveKitting"
	RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	RETURN
	END
	ELSE
	BEGIN
		SELECT @b_success = 1
		WHILE @@TRANCOUNT > @n_starttcnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END
END


GO