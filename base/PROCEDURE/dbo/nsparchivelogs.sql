SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nsparchivelogs]
	       @c_archivekey  NVARCHAR(10)             
,              @b_Success      int        OUTPUT    
,              @n_err          int        OUTPUT    
,              @c_errmsg       NVARCHAR(250)  OUTPUT  
as
/*--------------------------------------------------------------*/
/* 9 Feb 2004 WANYT FBR:SO#18664 Archive Loadplanretdetail      */
/*--------------------------------------------------------------*/
begin -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	declare @n_continue int        ,  
		@n_starttcnt int        , -- holds the current transaction count
		@n_cnt int              , -- holds @@rowcount after certain operations
		@b_debug int             -- debug on or off
	     
	/* #include <sparpo1.sql> */     
	declare
		@local_n_err   int,
		@local_c_errmsg    NVARCHAR(254),
		@c_temp NVARCHAR(254)
	
	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	

	if (@n_continue = 1 or @n_continue = 2)
	begin
		if (@b_debug =1 )
		begin
			print 'archiving alert...'
		end
		select @b_success = 1
		execute nsparchivealert
			@c_archivekey,         
			@b_Success,   
                        @n_err,    
                        @c_errmsg

		if not @b_success = 1
		begin
			select @n_continue = 3
			select @local_n_err = 77301
			select @local_c_errmsg = convert(char(5),@n_err)
			select @local_c_errmsg =
			": archiving of alert failed - (nsparchivelogs) " + " ( " +
			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		end
	end

	if (@n_continue = 1 or @n_continue = 2)
	begin
		if (@b_debug =1 )
		begin
			print 'archiving packing...'
		end
		select @b_success = 1
		execute nsparchivepacklog
			@c_archivekey,         
			@b_Success,   
                        @n_err,    
                        @c_errmsg

		if not @b_success = 1
		begin
			select @n_continue = 3
			select @local_n_err = 77302
			select @local_c_errmsg = convert(char(5),@n_err)
			select @local_c_errmsg =
			": archiving of packing failed - (nsparchivelogs) " + " ( " +
			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		end
	end

	if (@n_continue = 1 or @n_continue = 2)
	begin
		if (@b_debug =1 )
		begin
			print 'archiving orderslog...'
		end
		select @b_success = 1
		execute nsparchiveorderslog
			@c_archivekey,         
			@b_Success,   
                        @n_err,    
                        @c_errmsg

		if not @b_success = 1
		begin
			select @n_continue = 3
			select @local_n_err = 77303
			select @local_c_errmsg = convert(char(5),@n_err)
			select @local_c_errmsg =
			": archiving of orderslog failed - (nsparchivelogs) " + " ( " +
			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		end
	end

	if (@n_continue = 1 or @n_continue = 2)
	begin
		if (@b_debug =1 )
		begin
			print 'archiving invrptlog...'
		end
		select @b_success = 1
		execute nsparchiveinvrptlog
			@c_archivekey,         
			@b_Success,   
                        @n_err,    
                        @c_errmsg

		if not @b_success = 1
		begin
			select @n_continue = 3
			select @local_n_err = 77304
			select @local_c_errmsg = convert(char(5),@n_err)
			select @local_c_errmsg =
			": archiving of orderslog failed - (nsparchivelogs) " + " ( " +
			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		end
	end

	if (@n_continue = 1 or @n_continue = 2)
	begin
		if (@b_debug =1 )
		begin
			print 'archiving trigantic...'
		end
		select @b_success = 1
		execute nsparchivetriganticlog
			@c_archivekey,         
			@b_Success,   
                        @n_err,    
                        @c_errmsg

		if not @b_success = 1
		begin
			select @n_continue = 3
			select @local_n_err = 77305
			select @local_c_errmsg = convert(char(5),@n_err)
			select @local_c_errmsg =
			": archiving of trigantic failed - (nsparchivelogs) " + " ( " +
			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		end
	end

	if (@n_continue = 1 or @n_continue = 2)
	begin
		if (@b_debug =1 )
		begin
			print 'archiving ptrace...'
		end
		select @b_success = 1
		execute nsparchiveptrace
			@c_archivekey,         
			@b_Success,   
                        @n_err,    
                        @c_errmsg

		if not @b_success = 1
		begin
			select @n_continue = 3
			select @local_n_err = 77306
			select @local_c_errmsg = convert(char(5),@n_err)
			select @local_c_errmsg =
			": archiving of ptrace failed - (nsparchivelogs) " + " ( " +
			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		end
	end

	if (@n_continue = 1 or @n_continue = 2)
	begin
		if (@b_debug =1 )
		begin
			print 'archiving rfdb_log...'
		end
		select @b_success = 1
		execute nsparchiverfdblog
			@c_archivekey,         
			@b_Success,   
                        @n_err,    
                        @c_errmsg

		if not @b_success = 1
		begin
			select @n_continue = 3
			select @local_n_err = 77307
			select @local_c_errmsg = convert(char(5),@n_err)
			select @local_c_errmsg =
			": archiving of rfdblog failed - (nsparchivelogs) " + " ( " +
			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		end
	end

	if (@n_continue = 1 or @n_continue = 2)
	begin
		if (@b_debug =1 )
		begin
			print 'archiving errlog...'
		end
		select @b_success = 1
		execute nsparchiveerrlog
			@c_archivekey,         
			@b_Success,   
                        @n_err,    
                        @c_errmsg

		if not @b_success = 1
		begin
			select @n_continue = 3
			select @local_n_err = 77308
			select @local_c_errmsg = convert(char(5),@n_err)
			select @local_c_errmsg =
			": archiving of errlog failed - (nsparchivelogs) " + " ( " +
			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		end
	end
	if (@n_continue = 1 or @n_continue = 2)
	begin
		if (@b_debug =1 )
		begin
			print 'archiving skulog...'
		end
		select @b_success = 1
		execute nsparchiveskulog
			@c_archivekey,         
			@b_Success,   
                        @n_err,    
                        @c_errmsg

		if not @b_success = 1
		begin
			select @n_continue = 3
			select @local_n_err = 77309
			select @local_c_errmsg = convert(char(5),@n_err)
			select @local_c_errmsg =
			": archiving of skulog failed - (nsparchivelogs) " + " ( " +
			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
		end
	end

	if @n_continue = 1 or @n_continue = 2
	begin
		select @b_success = 1
		execute nsplogalert
			@c_modulename   = "nsparchivelogs",
			@c_alertmessage = "archive of logs ended successfully.",
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
				@c_modulename   = "nsparchivelogs",
				@c_alertmessage = "archive of logs failed - check this log for additional messages.",
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
     
	/* #include <sparpo2.sql> */     
	if @n_continue=3  -- error occured - process and return
	begin
		select @b_success = 0

		select @n_err = @local_n_err
		select @c_errmsg = @local_c_errmsg
		execute nsp_logerror @n_err, @c_errmsg, "nsparchivelogs"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		return
	end
	else
	begin
		select @b_success = 1
		return
	end
end -- main

GO