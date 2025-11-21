SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspArchiveInventoryQC                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: IDS                                                      */
/*                                                                      */
/* Purpose: Archive Inventory QC                                        */
/*                                                                      */
/* Input Parameters:  @c_PurgeFlag    - 'Y'                             */
/*                    @b_debug        - 0                               */
/*                    @n_FileKey      - 0                               */
/*                                                                      */
/* Output Parameters: @c_archivekey   - ArchiveKey                      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data ModIFications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 04-May-2009  Leong     1.1   SOS#135056 - Changed the archive        */
/*                              sequence to archive detail before header*/
/*                              to avoid deletion error                 */
/************************************************************************/
CREATE PROC [dbo].[nspArchiveInventoryQC]        
		@c_archivekey	 NVARCHAR(10)
	,	@b_success      int        output    
	,  @n_err          int        output    
	,  @c_errmsg       NVARCHAR(250)  output    
AS
/*-------------------------------------------------------------*/
/* 9 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters  */     
/*-------------------------------------------------------------*/
BEGIN -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE @n_continue int        ,  
		@n_starttcnt int        , -- holds the current transaction count
		@n_cnt int              , -- holds @@rowcount after certain operations
		@b_debug int             -- debug on or off
	     
	/* #include <sparpo1.sql> */     
	DECLARE @n_retain_days int      , -- days to hold data
		@d_result  datetime     , -- date po_date - (getdate() - noofdaystoretain
		@c_datetype NVARCHAR(10),      -- 1=editdate, 3=adddate
		@n_archive_invqc_records   int, -- # of InventoryQC records to be archived
		@n_archive_invqc_detail_records int, -- # of InventoryQCDetail records to be archived
		@n_default_id int,
		@n_strlen int,
		@local_n_err         int,
		@local_c_errmsg    NVARCHAR(254)
	
	DECLARE @c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@c_invqcactive NVARCHAR(2),
		@c_invqcstart NVARCHAR(10),
 		@c_invqcEND NVARCHAR(10),
		@c_whereclause NVARCHAR(254),
		@c_temp NVARCHAR(254),
		@copyrowstoarchivedatabase NVARCHAR(1)
	
	SELECT @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN -- 3
		SELECT  @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
			@n_retain_days = invqcnumberofdaystoretain,
			@c_invqcactive = invqcactive,
			@c_datetype = invqcdatetype,
			@c_invqcstart = isnull(invqcstart,''),
			@c_invqcEND = isnull(invqcEND,'ZZZZZZZZZZ'),
			@copyrowstoarchivedatabase = copyrowstoarchivedatabase
		FROM archiveparameters (nolock)
		WHERE archivekey = @c_archivekey
			
		IF db_id(@c_copyto_db) is null
		BEGIN
			SELECT @n_continue = 3
			SELECT @local_n_err = 77301
			SELECT @local_c_errmsg = convert(char(5),@local_n_err)
			SELECT @local_c_errmsg =
				": target database " + dbo.fnc_RTrim(@c_copyto_db) + " does NOT exist " + " ( " +
				" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nspArchiveInventoryQC)'
		END

		SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
		SELECT @d_result = dateadd(day,1,@d_result)

		SELECT @b_success = 1
		SELECT @c_temp = "archive of inventory qc started with parms; datetype = " + dbo.fnc_RTrim(@c_datetype) +
			' ; active = '+ dbo.fnc_RTrim(@c_invqcactive)+
			' ; QCkey = '+dbo.fnc_RTrim(@c_invqcstart)+'-'+dbo.fnc_RTrim(@c_invqcEND)+
			' ; copy rows to archive = '+dbo.fnc_RTrim(@copyrowstoarchivedatabase) +
			' ; retain days = '+ convert(char(6),@n_retain_days)
	
		EXECUTE nsplogalert
			@c_modulename   = "nspArchiveInventoryQC",
			@c_alertmessage = @c_temp ,
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END -- 3

	IF (@n_continue = 1 or @n_continue = 2)
	BEGIN -- 4
		SELECT @c_whereclause = ' '
		SELECT @c_temp = ' '
		
	
		SELECT @c_temp = 'AND InventoryQC.qc_key between '+ 'N'''+dbo.fnc_RTrim(@c_invqcstart) + ''''+ ' AND '+
			'N'''+dbo.fnc_RTrim(@c_invqcEND)+''''
	

		IF (@b_debug =1 )
		BEGIN
			PRINT 'subsetting clauses'
			SELECT 'EXECUTE clause @c_whereclause', @c_whereclause
			SELECT 'EXECUTE clause @c_temp ', @c_temp
		END

-- SOS#135056 Start
		IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
		BEGIN 
			IF (@b_debug =1 )
			BEGIN
				PRINT 'starting table existence check for InventoryQCDetail...'
			END
			SELECT @b_success = 1
			EXEC nsp_build_archive_table 
				@c_copyfrom_db, 
				@c_copyto_db,
				'InventoryQCDetail',
				@b_success output , 
				@n_err output , 
				@c_errmsg output
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END
-- SOS#135056 END
			
		IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
		BEGIN 
			IF (@b_debug =1 )
			BEGIN
				PRINT 'starting table existence check for InventoryQC...'
			END
			SELECT @b_success = 1
			EXEC nsp_build_archive_table 
				@c_copyfrom_db, 
				@c_copyto_db,
				'InventoryQC',
				@b_success output , 
				@n_err output , 
				@c_errmsg output
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END   

-- SOS#135056 Start
/*		
		IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
		BEGIN 
			IF (@b_debug =1 )
			BEGIN
				PRINT 'starting table existence check for InventoryQCDetail...'
			END
			SELECT @b_success = 1
			EXEC nsp_build_archive_table 
				@c_copyfrom_db, 
				@c_copyto_db,
				'InventoryQCDetail',
				@b_success output , 
				@n_err output , 
				@c_errmsg output
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END
*/
		IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
		BEGIN
			IF (@b_debug =1 )
			BEGIN
				PRINT 'building alter table string for InventoryQCDetail...'
			END
			EXECUTE nspbuildaltertablestring 
				@c_copyto_db,
				'InventoryQCDetail',
				@b_success output,
				@n_err output, 
				@c_errmsg output
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END
		
-- SOS#135056 END
		IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
		BEGIN
			IF (@b_debug =1 )
			BEGIN
				PRINT 'building alter table string for InventoryQC...'
			END
			EXECUTE nspbuildaltertablestring 
				@c_copyto_db,
				'InventoryQC',
				@b_success output,
				@n_err output, 
				@c_errmsg output
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END

-- SOS#135056 Start
/*
		IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
		BEGIN
			IF (@b_debug =1 )
			BEGIN
				PRINT 'building alter table string for InventoryQCDetail...'
			END
			EXECUTE nspbuildaltertablestring 
				@c_copyto_db,
				'InventoryQCDetail',
				@b_success output,
				@n_err output, 
				@c_errmsg output
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END 
*/
-- SOS#135056 End	
	
		IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
		BEGIN -- 5
			BEGIN tran
	
			IF @c_datetype = '1' -- editdate
			BEGIN
				SELECT @c_whereclause = "UPDATE InventoryQC SET ArchiveCop = '9' WHERE ( InventoryQC.editdate <= " + '"'+ convert(char(10),@d_result,101)+'"' + " ) "
            			EXECUTE (@c_whereclause+ @c_temp)
				SELECT @local_n_err = @@error, @n_cnt = @@rowcount
				SELECT @n_archive_invqc_records = @n_cnt
			END
	
			IF @c_datetype = '2' -- adddate
			BEGIN
				SELECT @c_whereclause = "UPDATE InventoryQC SET ArchiveCop = '9' WHERE ( invnentoryqc.adddate <= " +'"'+ convert(char(10),@d_result,101)+'"' + " ) "
				EXECUTE (@c_whereclause + @c_temp)
				SELECT @local_n_err = @@error, @n_cnt = @@rowcount
				SELECT @n_archive_invqc_records = @n_cnt
			END
		
			IF @local_n_err <> 0
			BEGIN 
				SELECT @n_continue = 3
				SELECT @local_n_err = 77302
				SELECT @local_c_errmsg = convert(char(5),@local_n_err)
				SELECT @local_c_errmsg =
				': UPDATE of ArchiveCop failed - InventoryQC (nspArchiveInventoryQC) ' + ' ( ' +
				' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
			END  
		
			IF (@n_continue = 1 or @n_continue = 2)
			BEGIN 
				UPDATE InventoryQCDetail
				SET InventoryQCDetail.ArchiveCop = '9'
				FROM InventoryQC, InventoryQCDetail
				WHERE ((InventoryQCDetail.qc_key = InventoryQC.qc_key) AND (InventoryQC.ArchiveCop = '9'))
				SELECT @local_n_err = @@error, @n_cnt = @@rowcount
				SELECT @n_archive_invqc_detail_records = @n_cnt
				IF @local_n_err <> 0
				BEGIN 
					SELECT @n_continue = 3
					SELECT @local_n_err = 77303
					SELECT @local_c_errmsg = convert(char(5),@local_n_err)
					SELECT @local_c_errmsg =
					": UPDATE of ArchiveCop failed - InventoryQCDetail. (nspArchiveInventoryQC) " + " ( " +
					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
				END  
			END 

			IF ((@n_continue = 1 or @n_continue = 2)  AND @copyrowstoarchivedatabase = 'y')
			BEGIN
				SELECT @c_temp = "attempting to archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_invqc_records )) +
					" InventoryQC records AND " + dbo.fnc_RTrim(convert(char(6),@n_archive_invqc_detail_records )) + " InventoryQCDetail records"
				EXECUTE nsplogalert
					@c_modulename   = "nspArchiveInventoryQC",
					@c_alertmessage = @c_temp ,
					@n_severity     = 0,
					@b_success       = @b_success output,
					@n_err          = @n_err output,
					@c_errmsg       = @c_errmsg output
				IF NOT @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
			END 

			IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
			BEGIN   
				IF (@b_debug =1 )
				BEGIN
					PRINT "building insert for InventoryQCDetail..."
				END
				SELECT @b_success = 1
				EXEC nsp_build_insert  
					@c_copyto_db, 
					'InventoryQCDetail',
					1,
					@b_success output , 
					@n_err output, 
					@c_errmsg output
				IF NOT @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
			END
		
			IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
			BEGIN   
				IF (@b_debug =1 )
				BEGIN
					PRINT "building insert for InventoryQC..."
				END
				SELECT @b_success = 1
				EXEC nsp_build_insert  
					@c_copyto_db, 
					'InventoryQC',
					1,
					@b_success output , 
					@n_err output, 
					@c_errmsg output
				IF NOT @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
			END   

-- SOS#135056 Start
/*		
			IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')
			BEGIN   
				IF (@b_debug =1 )
				BEGIN
					PRINT "building insert for InventoryQCDetail..."
				END
				SELECT @b_success = 1
				EXEC nsp_build_insert  
					@c_copyto_db, 
					'InventoryQCDetail',
					1,
					@b_success output , 
					@n_err output, 
					@c_errmsg output
				IF NOT @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
			END   
*/
-- SOS#135056 Start
	
	
			IF @n_continue = 1 or @n_continue = 2
			BEGIN  
				IF (@b_debug =1 )
				BEGIN
					PRINT "DELETE for InventoryQCDetail..."
				END
				IF (@b_debug = 0)
				BEGIN
					DELETE FROM InventoryQCDetail
					WHERE ArchiveCop = '9'
					SELECT @local_n_err = @@error, @n_cnt = @@rowcount
				END
				IF (@b_debug = 1)
				BEGIN
					SELECT * FROM InventoryQCDetail
					WHERE ArchiveCop = '9'
				END
				IF @local_n_err <> 0
				BEGIN  
					SELECT @n_continue = 3
					SELECT @n_err = 77305
					SELECT @local_c_errmsg = convert(char(5),@local_n_err)
					SELECT @local_c_errmsg =
					":  InventoryQCDetail DELETE failed. (nspArchiveInventoryQC) " + " ( " +
					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
				END      
			END    
			
			IF @n_continue = 1 or @n_continue = 2
			BEGIN  
				IF (@b_debug =1 )
				BEGIN
					PRINT "DELETE for InventoryQC..."
				END
				IF (@b_debug = 0)
				BEGIN
					DELETE FROM InventoryQC
					WHERE ArchiveCop = '9'
					SELECT @local_n_err = @@error, @n_cnt = @@rowcount
				END
				IF (@b_debug = 1)
				BEGIN
					SELECT * FROM InventoryQC
					WHERE ArchiveCop = '9'
				END
				IF @local_n_err <> 0
				BEGIN  
					SELECT @n_continue = 3
					SELECT @n_err = 77304
					SELECT @local_c_errmsg = convert(char(5),@local_n_err)
					SELECT @local_c_errmsg =
					":  InventoryQC DELETE failed. (nspArchiveInventoryQC) " + " ( " +
					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
				END      
			END   			
		
			IF @n_continue = 1 or @n_continue = 2
			BEGIN
				COMMIT TRAN
			END
			ELSE
			BEGIN
				ROLLBACK TRAN
			END
		END -- 5 
	END -- 4
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		EXECUTE nsplogalert
			@c_modulename   = "nspArchiveInventoryQC",
			@c_alertmessage = "archive of InventoryQC & InventoryQCDetail ENDed normally.",
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
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
			EXECUTE nsplogalert
				@c_modulename   = "nspArchiveInventoryQC",
				@c_alertmessage = "archive of InventoryQC & InventoryQCDetail ENDed abnormally - check this log for additional messages.",
				@n_severity     = 0,
				@b_success       = @b_success output ,
				@n_err          = @n_err output,
				@c_errmsg       = @c_errmsg output
			IF NOT @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END
	END

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		EXECUTE nsplogalert
			@c_modulename   = "nspArchiveInventoryQC",
			@c_alertmessage = "purging InventoryQC & InventoryQCDetail tables",
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
		END
	END
	     
	/* #include <sparpo2.sql> */     
	IF @n_continue=3  -- error occured - process AND return
	BEGIN
		SELECT @b_success = 0
		IF @@trancount = 1 AND @@trancount > @n_starttcnt
		BEGIN
			ROLLBACK TRAN
		END
		ELSE
		BEGIN
			while @@trancount > @n_starttcnt
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveInventoryQC"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		return
	END
	ELSE
	BEGIN
		SELECT @b_success = 1
		while @@trancount > @n_starttcnt
		BEGIN
			COMMIT TRAN
		END
		return
	END
END -- main

GO