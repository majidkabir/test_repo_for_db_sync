SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nsparchivePls]        
		@c_archivekey	 NVARCHAR(10)
	,	@b_success      int        output    
	,  @n_err          int        output    
	,  @c_errmsg       NVARCHAR(250)  output    
as
/*-------------------------------------------------------------*/
/* 9 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters  */     
/*-------------------------------------------------------------*/
begin -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	declare @n_continue int        ,  
		@n_starttcnt int        , -- holds the current transaction count
		@n_cnt int              , -- holds @@rowcount after certain operations
		@b_debug int             -- debug on or off
	     
	/* #include <sparpo1.sql> */     
	declare @n_retain_days int      , -- days to hold data
		@d_result  datetime     , -- date po_date - (getdate() - noofdaystoretain
		@c_datetype NVARCHAR(10),      -- 1=editdate, 3=adddate
		@n_archive_pls_records   int, -- # of kit records to be archived
		@n_archive_pls_detail_records int, -- # of kitdetail records to be archived
		@n_default_id int,
		@n_strlen int,
		@local_n_err         int,
		@local_c_errmsg    NVARCHAR(254)
	
	declare @c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@c_plsactive NVARCHAR(2),
		@c_plsstart NVARCHAR(10),
 		@c_plsend NVARCHAR(10),
		@c_whereclause NVARCHAR(254),
		@c_temp NVARCHAR(254),
		@c_temp1 NVARCHAR(254),
		@copyrowstoarchivedatabase NVARCHAR(1)
	
	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	
	if @n_continue = 1 or @n_continue = 2
	begin -- 3
		select  @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
			@n_retain_days = plsnumberofdaystoretain,
			@c_plsactive = plsactive,
			@c_datetype = plsdatetype,
			@c_plsstart = isnull(plsstart,''),
			@c_plsend = isnull(plsend,'ZZZZZZZZZZ'),
			@copyrowstoarchivedatabase = copyrowstoarchivedatabase
		from archiveparameters (nolock)
		where archivekey = @c_archivekey
			
		if db_id(@c_copyto_db) is null
		begin
			select @n_continue = 3
			select @local_n_err = 77301
			select @local_c_errmsg = convert(char(5),@local_n_err)
			select @local_c_errmsg =
				": target database " + dbo.fnc_RTrim(@c_copyto_db) + " does not exist " + " ( " +
				" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nsparchivepls)'
		end

		select @d_result = dateadd(day,-@n_retain_days,getdate())
		select @d_result = dateadd(day,1,@d_result)

		select @b_success = 1
		select @c_temp = "archive of pls started with parms; datetype = " + dbo.fnc_RTrim(@c_datetype) +
			' ; active = '+ dbo.fnc_RTrim(@c_plsactive)+
			' ; Doc No = '+dbo.fnc_RTrim(@c_plsstart)+'-'+dbo.fnc_RTrim(@c_plsend)+
			' ; copy rows to archive = '+dbo.fnc_RTrim(@copyrowstoarchivedatabase) +
			' ; retain days = '+ convert(char(6),@n_retain_days)
	
		execute nsplogalert
			@c_modulename   = "nsparchivepls",
			@c_alertmessage = @c_temp ,
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end -- 3

	if (@n_continue = 1 or @n_continue = 2)
	begin -- 4
		select @c_whereclause = ' '
		select @c_temp = ' '
		
	
		select @c_temp = 'and idsstktrfdoc.stdno between '+ 'N'''+dbo.fnc_RTrim(@c_plsstart) + ''''+ ' and '+
			'N'''+dbo.fnc_RTrim(@c_plsend)+''''
	
		
		if (@b_debug =1 )
		begin
			print 'subsetting clauses'
			select 'execute clause @c_whereclause', @c_whereclause
			select 'execute clause @c_temp ', @c_temp
		end
	
		if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
		begin 
			if (@b_debug =1 )
			begin
				print 'starting table existence check for idsstktrfdoc...'
			end
			select @b_success = 1
			exec nsp_build_archive_table 
				@c_copyfrom_db, 
				@c_copyto_db,
				'idsstktrfdoc',
				@b_success output , 
				@n_err output , 
				@c_errmsg output
			if not @b_success = 1
			begin
				select @n_continue = 3
			end
		end   
			
		if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
		begin 
			if (@b_debug =1 )
			begin
				print 'starting table existence check for idsstktrfdocdetail...'
			end
			select @b_success = 1
			exec nsp_build_archive_table 
				@c_copyfrom_db, 
				@c_copyto_db,
				'idsstktrfdocdetail',
				@b_success output , 
				@n_err output , 
				@c_errmsg output
			if not @b_success = 1
			begin
				select @n_continue = 3
			end
		end   

		if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
		begin
			if (@b_debug =1 )
			begin
				print 'building alter table string for idsstktrfdoc...'
			end
			execute nspbuildaltertablestring 
				@c_copyto_db,
				'idsstktrfdoc',
				@b_success output,
				@n_err output, 
				@c_errmsg output
			if not @b_success = 1
			begin
				select @n_continue = 3
			end
		end

		if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
		begin
			if (@b_debug =1 )
			begin
				print 'building alter table string for idsstktrfdocdetail...'
			end
			execute nspbuildaltertablestring 
				@c_copyto_db,
				'idsstktrfdocdetail',
				@b_success output,
				@n_err output, 
				@c_errmsg output
			if not @b_success = 1
			begin
				select @n_continue = 3
			end
		end
	
	
		if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
		begin -- 5
			begin tran

			
			if @c_datetype = '1' -- adddate
			begin
				select @c_whereclause = "update idsstktrfdoc set archivecop = '9' where ( idsstktrfdoc.adddate <= " +'"'+ convert(char(10),@d_result,101)+'"' + " and finalized = 'Y' ) "
				execute (@c_whereclause + @c_temp )
				select @local_n_err = @@error, @n_cnt = @@rowcount
				select @n_archive_pls_records = @n_cnt
			end
		
			if @local_n_err <> 0
			begin 
				select @n_continue = 3
				select @local_n_err = 77302
				select @local_c_errmsg = convert(char(5),@local_n_err)
				select @local_c_errmsg =
				': update of archivecop failed - idsstktrfdoc (nsparchivepls) ' + ' ( ' +
				' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
			end  
		
			if (@n_continue = 1 or @n_continue = 2)
			begin 
				update idsstktrfdocdetail
				set idsstktrfdocdetail.archivecop = '9'
				from idsstktrfdoc, idsstktrfdocdetail
				where ((idsstktrfdocdetail.stdno = idsstktrfdoc.stdno) and (idsstktrfdoc.archivecop = '9'))

				select @local_n_err = @@error, @n_cnt = @@rowcount
				select @n_archive_pls_detail_records = @n_cnt
				if @local_n_err <> 0
				begin 
					select @n_continue = 3
					select @local_n_err = 77303
					select @local_c_errmsg = convert(char(5),@local_n_err)
					select @local_c_errmsg =
					": update of archivecop failed - idsstktrfdocdetail. (nsparchivepls) " + " ( " +
					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
				end  
			end 
		
		
			if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
			begin
				select @c_temp = "attempting to archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_pls_records )) +
					" idsstktrfdoc records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_pls_detail_records )) + " idsstktrfdocdetail records"
				execute nsplogalert
					@c_modulename   = "nsparchivepls",
					@c_alertmessage = @c_temp ,
					@n_severity     = 0,
					@b_success       = @b_success output,
					@n_err          = @n_err output,
					@c_errmsg       = @c_errmsg output
				if not @b_success = 1
				begin
					select @n_continue = 3
				end
			end 
		
			if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
			begin   
				if (@b_debug =1 )
				begin
					print "building insert for idsstktrfdoc..."
				end
				select @b_success = 1
				exec nsp_build_insert  
					@c_copyto_db, 
					'idsstktrfdoc',
					1,
					@b_success output , 
					@n_err output, 
					@c_errmsg output
				if not @b_success = 1
				begin
					select @n_continue = 3
				end
			end   
		
			if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
			begin   
				if (@b_debug =1 )
				begin
					print "building insert for idsstktrfdocdetail..."
				end
				select @b_success = 1
				exec nsp_build_insert  
					@c_copyto_db, 
					'idsstktrfdocdetail',
					1,
					@b_success output , 
					@n_err output, 
					@c_errmsg output
				if not @b_success = 1
				begin
					select @n_continue = 3
				end
			end   

			if @n_continue = 1 or @n_continue = 2
			begin  
				if (@b_debug =1 )
				begin
					print "delete for idsstktrfdoc..."
				end
				if (@b_debug = 0)
				begin
					delete from idsstktrfdoc
					where archivecop = '9'
					select @local_n_err = @@error, @n_cnt = @@rowcount
				end
				if (@b_debug = 1)
				begin
					select * from idsstktrfdoc (nolock)
					where archivecop = '9'
				end
				if @local_n_err <> 0
				begin  
					select @n_continue = 3
					select @n_err = 77304
					select @local_c_errmsg = convert(char(5),@local_n_err)
					select @local_c_errmsg =
					":  idsstktrfdoc delete failed. (nsparchivepls) " + " ( " +
					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
				end      
			end    
		
			if @n_continue = 1 or @n_continue = 2
			begin  
				if (@b_debug =1 )
				begin
					print "delete for idsstktrfdocdetail..."
				end
				if (@b_debug = 0)
				begin
					delete from idsstktrfdocdetail
					where archivecop = '9'
					select @local_n_err = @@error, @n_cnt = @@rowcount
				end
				if (@b_debug = 1)
				begin
					select * from idsstktrfdocdetail (nolock)
					where archivecop = '9'
				end
				if @local_n_err <> 0
				begin  
					select @n_continue = 3
					select @n_err = 77305
					select @local_c_errmsg = convert(char(5),@local_n_err)
					select @local_c_errmsg =
					":  idsstktrfdocdetail delete failed. (nsparchivepls) " + " ( " +
					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
				end      
			end    
		
			if @n_continue = 1 or @n_continue = 2
			begin
				commit tran
			end
			else
			begin
				rollback tran
			end
		end -- 5 
	end -- 4
	
	if @n_continue = 1 or @n_continue = 2
	begin
		select @b_success = 1
		execute nsplogalert
			@c_modulename   = "nsparchivepls",
			@c_alertmessage = "archive of idsstktrfdoc & idsstktrfdocdetail ended normally.",
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end
	else
	begin
		if @n_continue = 3
		begin
			select @b_success = 1
			execute nsplogalert
				@c_modulename   = "nsparchivepls",
				@c_alertmessage = "archive of idsstktrfdoc & idsstktrfdocdetail ended abnormally - check this log for additional messages.",
				@n_severity     = 0,
				@b_success       = @b_success output ,
				@n_err          = @n_err output,
				@c_errmsg       = @c_errmsg output
			if not @b_success = 1
			begin
				select @n_continue = 3
			end
		end
	end

	if @n_continue = 1 or @n_continue = 2
	begin
		select @b_success = 1
		execute nsplogalert
			@c_modulename   = "nsparchivepls",
			@c_alertmessage = "purging idsstktrfdoc & idsstktrfdocdetail tables",
			@n_severity     = 0,
			@b_success       = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end
	     
	/* #include <sparpo2.sql> */     
	if @n_continue=3  -- error occured - process and return
	begin
		select @b_success = 0
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
	
		select @n_err = @local_n_err
		select @c_errmsg = @local_c_errmsg
		if (@b_debug = 1)
		begin
			select @n_err,@c_errmsg, 'before putting in nsp_logerr at the bottom'
		end
		execute nsp_logerror @n_err, @c_errmsg, "nsparchivepls"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		return
	end
	else
	begin
		select @b_success = 1
		while @@trancount > @n_starttcnt
		begin
			commit tran
		end
		return
	end
end -- main

GO