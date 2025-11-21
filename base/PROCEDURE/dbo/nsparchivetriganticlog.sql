SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : nspArchiveTriganticLog                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters: NONE                                               */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-Nov-28  Shong         Change Commit transaction strategy to row */
/*                            Level to Reduce Blocking.                 */
/* 2006-Apr-10  June          Change nsp_build_Insert 'Packdetail' to   */
/*                            'TriganticLog'.                           */
/* 2015-Mar-14  TLTING        Trigantic retired. Purge without status   */
/************************************************************************/

CREATE PROC [dbo].[nspArchiveTriganticLog]      
		@c_archivekey	 NVARCHAR(10)
	,	@b_success      int        output    
	,  @n_err          int        output    
	,  @c_errmsg       NVARCHAR(250)  output    
as
/*-------------------------------------------------------------*/
/* THIS ARCHIVE SCRIPT IS EXECUTED FROM nsparchivelogs         */
/* 9 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters  */     
/*-------------------------------------------------------------*/
begin -- main
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	declare @n_continue int    ,  
		@n_starttcnt int        , -- holds the current transaction count
		@n_cnt int              , -- holds @@rowcount after certain operations
		@b_debug int             -- debug on or off
	     
   declare @cTriganticLogKey NVARCHAR(10)

	/* #include <sparpo1.sql> */     
	declare @n_retain_days int      , -- days to hold data
		@d_result  datetime     , -- date po_date - (getdate() - noofdaystoretain
		@c_datetype NVARCHAR(10),      -- 1=editdate, 2=adddate
		@n_archive_TriganticLog_records   int, -- # of ID records to be archived
		@n_default_id int,
		@n_strlen int,
		@local_n_err         int,
		@local_c_errmsg    NVARCHAR(254)
	
	declare @c_copyfrom_db   NVARCHAR(55),
		@c_copyto_db          NVARCHAR(55),
		@c_TriganticLogActive NVARCHAR(2),
		@c_TriganticLogstart  NVARCHAR(10),
		@c_TriganticLogend    NVARCHAR(10),
		@c_executestatement   NVARCHAR(254),
		@c_WhereClause        NVARCHAR(254),
		@c_temp               NVARCHAR(254),
		@CopyRowsToArchiveDatabase NVARCHAR(1)
	
	SELECT @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	
	if @n_continue = 1 or @n_continue = 2
	begin -- 3
		SELECT  @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
			@n_retain_days = triglognumberofdaystoretain,
			@c_TriganticLogactive = triglogactive,
			@c_datetype = triglogdatetype,
			@c_TriganticLogstart = isnull(triglogstart,''),
			@c_TriganticLogend = isnull(triglogend,'ZZZZZZZZZZ'),
			@CopyRowsToArchiveDatabase = copyrowstoarchivedatabase
		from archiveparameters (nolock)
		where archivekey = @c_archivekey
			
		if db_id(@c_copyto_db) is null
		begin
			SELECT @n_continue = 3
			SELECT @local_n_err = 77301
			SELECT @local_c_errmsg = convert(char(5),@local_n_err)
			SELECT @local_c_errmsg =
				": target database " + dbo.fnc_RTrim(@c_copyto_db) + " does not exist " + " ( " +
				" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nsparchiveeTriganticLog)'
		end

		SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
		SELECT @d_result = dateadd(day,1,@d_result)

		SELECT @b_success = 1
		SELECT @c_temp = 'archive of TriganticLog with parms; active = '+ dbo.fnc_RTrim(@c_TriganticLogactive)+
			' ; log Trigantic key = '+dbo.fnc_RTrim(@c_TriganticLogstart)+'-'+dbo.fnc_RTrim(@c_TriganticLogend)+
			' ; copy rows to archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+
			' ; retain days = '+ convert(char(6),@n_retain_days)
	
		execute nsplogalert
			@c_modulename   = "nspArchiveTriganticLog",
			@c_alertmessage = @c_temp ,
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
		if not @b_success = 1
		begin
			SELECT @n_continue = 3
		end
	end -- 3

	if (@n_continue = 1 or @n_continue = 2)
	begin -- 4
      SELECT @c_executestatement = ' '
		SELECT @c_WhereClause = ' '
		SELECT @c_temp = ' '		

		if ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'y')
		begin 
			if (@b_debug =1 )
			begin
				print 'starting table existence check for TriganticLog...'
			end
			SELECT @b_success = 1
			exec nsp_build_archive_table 
				@c_copyfrom_db, 
				@c_copyto_db,
				'TriganticLog',
				@b_success output , 
				@n_err output , 
				@c_errmsg output
			if not @b_success = 1
			begin
				SELECT @n_continue = 3
			end
		end   
			
		if ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'y')
		begin
			if (@b_debug =1 )
			begin
				print 'building alter table string for TriganticLog...'
			end
			execute nspbuildaltertablestring 
				@c_copyto_db,
				'TriganticLog',
				@b_success output,
				@n_err output, 
				@c_errmsg output
			if not @b_success = 1
			begin
				SELECT @n_continue = 3
			end
		end
	
	
		if ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'y')
		begin -- 5


			if @c_datetype = '1' -- editdate
			begin
				--SELECT @c_WhereClause = "where editdate <= " + '"'+ convert(char(10),@d_result,101)+'" and transmitflag = "9" '
            SELECT @c_WhereClause = "where editdate <= " + '"'+ convert(char(10),@d_result,101)+'"  '
			end

			if @c_datetype = '2' -- editdate
			begin
				--SELECT @c_WhereClause = "where adddate <= " + '"'+ convert(char(10),@d_result,101)+'" and transmitflag = "9" '
				SELECT @c_WhereClause = "where adddate <= " + '"'+ convert(char(10),@d_result,101)+'" '
			end

			SELECT @c_temp = 'and TriganticLog.TriganticLogkey between '+ 'N'''+dbo.fnc_RTrim(@c_TriganticLogstart) + ''''+ ' and '+
					 'N'''+dbo.fnc_RTrim(@c_TriganticLogend)+''' '


          SET @n_archive_TriganticLog_records = 0 

         EXEC ('DECLARE C_ARC_TriganticLog CURSOR FAST_FORWARD READ_ONLY FOR ' + 
               'SELECT TriganticLogKey FROM TriganticLog (NOLOCK) ' + 
               @c_WhereClause )

         OPEN C_ARC_TriganticLog 

         FETCH NEXT FROM C_ARC_TriganticLog INTO @cTriganticLogKey 

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRAN

            UPDATE TriganticLog WITH (ROWLOCK)
               SET ArchiveCop = '9' 
            WHERE TriganticLogkey = @cTriganticLogKey 
				
            SELECT @local_n_err = @@error, @n_cnt = @@rowcount
				
				IF @local_n_err <> 0
				BEGIN  
					SELECT @n_continue = 3
					SELECT @n_err = 77303
					SELECT @local_c_errmsg = convert(char(5),@local_n_err)
					SELECT @local_c_errmsg =
					":  dynamic delete TriganticLog failed. (nspArchiveTriganticLog) " + " ( " +
					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               ROLLBACK TRAN 
				END      
            ELSE
            BEGIN
               SET @n_archive_TriganticLog_records = @n_archive_TriganticLog_records + 1
               COMMIT TRAN  
            END 

            FETCH NEXT FROM C_ARC_TriganticLog INTO @cTriganticLogKey 
         END 
         CLOSE C_ARC_TriganticLog
         DEALLOCATE C_ARC_TriganticLog 

			IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'y')
			BEGIN
				SELECT @c_temp = "attempting to archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_TriganticLog_records )) +
					" TriganticLog records."
				EXECUTE nsplogalert
					@c_modulename   = "nspArchiveTriganticLog",
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
		
		
			if ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'y')
			begin   
				if (@b_debug =1 )
				begin
					print "building insert for TriganticLog..."
				end
				SELECT @b_success = 1
				
				-- June, 10APR2006
				/*
					exec nsp_build_insert  
      			@c_copyto_db, 
      			'packdetail',
      			1,
      			@b_success output , 
      			@n_err output, 
      			@c_errmsg output
      		*/      						
      		exec nsp_build_insert  
      			@c_copyto_db, 
      			'TriganticLog',
      			1,
      			@b_success output , 
      			@n_err output, 
      			@c_errmsg output
				if not @b_success = 1
				begin
					SELECT @n_continue = 3
				end
			end   
		end -- 5 
	end -- 4
	
	if @n_continue = 1 or @n_continue = 2
	begin
		SELECT @b_success = 1
		execute nsplogalert
			@c_modulename   = "nspArchiveTriganticLog",
			@c_alertmessage = "archive of TriganticLog ended normally.",
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
		if not @b_success = 1
		begin
			SELECT @n_continue = 3
		end
	end
	else
	begin
		if @n_continue = 3
		begin
			SELECT @b_success = 1
			execute nsplogalert
				@c_modulename   = "nspArchiveTriganticLog",
				@c_alertmessage = "archive of TriganticLog ended abnormally - check this log for additional messages.",
				@n_severity     = 0,
				@b_success       = @b_success output ,
				@n_err          = @n_err output,
				@c_errmsg       = @c_errmsg output
			if not @b_success = 1
			begin
				SELECT @n_continue = 3
			end
		end
	end

	/* #include <sparpo2.sql> */     
	if @n_continue=3  -- error occured - process and return
	begin
		SELECT @b_success = 0
		if @@trancount = 1 and @@trancount > @n_starttcnt
		begin
			rollback tran
		end
		else
		begin
			while @@trancount > @n_starttcnt
			begin
				commit tran
			end
		end
	
		SELECT @n_err = @local_n_err
		SELECT @c_errmsg = @local_c_errmsg
		if (@b_debug = 1)
		begin
			SELECT @n_err,@c_errmsg, 'before putting in nsp_logerr at the bottom'
		end
		execute nsp_logerror @n_err, @c_errmsg, "nspArchiveTriganticLog"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		return
	end
	else
	begin
		SELECT @b_success = 1
		while @@trancount > @n_starttcnt
		begin
			commit tran
		end
		return
	end
end -- main

GO