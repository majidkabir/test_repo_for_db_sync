SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspArchiveReplenishment										*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* 12-APR-2006	 June				June01 : Change to Cursor Loop				*/
/************************************************************************/

CREATE PROC [dbo].[nsparchiveReplenishment]         
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
		@n_archive_replenish_records   int, -- # of replenishment records to be archived
		@n_default_id int,
		@n_strlen int,
		@local_n_err         int,
		@local_c_errmsg    NVARCHAR(254)
	
   declare @cReplenishmentKey NVARCHAR(10) -- June01
			 ,@n_archive_Replenishment_records int -- June01
	declare @c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@c_replenishactive NVARCHAR(2),
		@c_replenishstart NVARCHAR(10),
 		@c_replenishend NVARCHAR(10),
		@c_whereclause NVARCHAR(254),
		@c_temp NVARCHAR(254),
		@copyrowstoarchivedatabase NVARCHAR(1)
	
	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	
	if @n_continue = 1 or @n_continue = 2
	begin -- 3
		select  @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
			@n_retain_days = replenishnumberofdaystoretain,
			@c_replenishactive = replenishactive,
			@c_datetype = replenishdatetype,
			@c_replenishstart = isnull(replenishstart,''),
			@c_replenishend = isnull(replenishend,'ZZZZZZZZZZ'),
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
				" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nsparchivereplenishment)'
		end

		select @d_result = dateadd(day,-@n_retain_days,getdate())
		select @d_result = dateadd(day,1,@d_result)

		select @b_success = 1
		select @c_temp = "archive of replenishment started with parms; datetype = " + dbo.fnc_RTrim(@c_datetype) +
			' ; active = '+ dbo.fnc_RTrim(@c_replenishactive)+
			' ; replenishmentkey = '+dbo.fnc_RTrim(@c_replenishstart)+'-'+dbo.fnc_RTrim(@c_replenishend)+
			' ; copy rows to archive = '+dbo.fnc_RTrim(@copyrowstoarchivedatabase) +
			' ; retain days = '+ convert(char(6),@n_retain_days)
	
		execute nsplogalert
			@c_modulename   = "nsparchivereplenishment",
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
	
		select @c_temp = 'and replenishment.replenishmentkey between '+ 'N'''+dbo.fnc_RTrim(@c_replenishstart) + ''''+ ' and '+
			'N'''+dbo.fnc_RTrim(@c_replenishend)+''''	

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
				print 'starting table existence check for replenishment...'
			end
			select @b_success = 1
			exec nsp_build_archive_table 
				@c_copyfrom_db, 
				@c_copyto_db,
				'replenishment',
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
				print 'building alter table string for Replenishment...'
			end
			execute nspbuildaltertablestring 
				@c_copyto_db,
				'replenishment',
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
			-- Start : June01
			/*
			begin tran
	
			if @c_datetype = '1' -- editdate
			begin
				select @c_whereclause = "update replenishment set archivecop = '9' where ( replenishment.editdate <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and replenishment.confirmed = 'Y' ) "
            			execute (@c_whereclause+ @c_temp)
				select @local_n_err = @@error, @n_cnt = @@rowcount
				select @n_archive_replenish_records = @n_cnt
			end
	
			if @c_datetype = '2' -- adddate
			begin
				select @c_whereclause = "update replenishment set archivecop = '9' where ( replenishment.adddate <= " +'"'+ convert(char(10),@d_result,101)+'"' + " and replenishment.confirmed = 'Y' ) "
				execute (@c_whereclause + @c_temp)
				select @local_n_err = @@error, @n_cnt = @@rowcount
				select @n_archive_replenish_records = @n_cnt
			end
		
			if @local_n_err <> 0
			begin 
				select @n_continue = 3
				select @local_n_err = 77302
				select @local_c_errmsg = convert(char(5),@local_n_err)
				select @local_c_errmsg =
				': update of archivecop failed - replenishment (nsparchivereplenishment) ' + ' ( ' +
				' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
			end  
			*/

			if @c_datetype = '1' -- editdate
			begin
				select @c_whereclause = "where ( replenishment.editdate <= " + '"'+ convert(char(10),@d_result,101)+'"' + " and replenishment.confirmed = 'Y' ) "
			end
	
			if @c_datetype = '2' -- adddate
			begin
				select @c_whereclause = "where ( replenishment.adddate <= " +'"'+ convert(char(10),@d_result,101)+'"' + " and replenishment.confirmed = 'Y' ) "
			end
			
			IF @c_temp <> ''
			begin
				select @c_whereclause = @c_whereclause + " " + @c_temp
			end

			SET @n_archive_Replenishment_records = 0 
		
		   EXEC ('DECLARE C_ARC_Replenishment CURSOR FAST_FORWARD READ_ONLY FOR ' + 
               'SELECT Replenishmentkey FROM Replenishment (NOLOCK) ' + 
               @c_WhereClause )

         OPEN C_ARC_Replenishment 

         FETCH NEXT FROM C_ARC_Replenishment INTO @cReplenishmentkey 

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRAN

            UPDATE Replenishment WITH (ROWLOCK)
               SET ArchiveCop = '9' 
            WHERE Replenishmentkey = @cReplenishmentkey 
				
            SELECT @local_n_err = @@error, @n_cnt = @@rowcount				
				IF @local_n_err <> 0
				BEGIN  
					SELECT @n_continue = 3
					SELECT @n_err = 77303
					SELECT @local_c_errmsg = convert(char(5),@local_n_err)
					SELECT @local_c_errmsg =
					":  dynamic delete Replenishment failed. (nspArchiveReplenishment) " + " ( " +
					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               ROLLBACK TRAN 
				END      
            ELSE
            BEGIN
               SET @n_archive_Replenishment_records = @n_archive_Replenishment_records + 1
               COMMIT TRAN  
            END 

            FETCH NEXT FROM C_ARC_Replenishment INTO @cReplenishmentkey 
         END 
         CLOSE C_ARC_Replenishment
         DEALLOCATE C_ARC_Replenishment 
			-- End : June01

			if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
			begin
				select @c_temp = "attempting to archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_replenish_records )) +
					" replenishment records."
				execute nsplogalert
					@c_modulename   = "nsparchivereplenishment",
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
					print "building insert for replenishment..."
				end
				select @b_success = 1
				exec nsp_build_insert  
					@c_copyto_db, 
					'replenishment',
					1,
					@b_success output , 
					@n_err output, 
					@c_errmsg output
				if not @b_success = 1
				begin
					select @n_continue = 3
				end
			end   
		
			-- Start : June01
			-- Remark this, already handled in nsp_build_insert
			/*
			if @n_continue = 1 or @n_continue = 2
			begin  
				if (@b_debug =1 )
				begin
					print "delete for replenishment..."
				end
				if (@b_debug = 0)
				begin
					delete from replenishment
					where archivecop = '9'
					select @local_n_err = @@error, @n_cnt = @@rowcount
				end
				if (@b_debug = 1)
				begin
					select * from replenishment
					where archivecop = '9'
				end
				if @local_n_err <> 0
				begin  
					select @n_continue = 3
					select @n_err = 77303
					select @local_c_errmsg = convert(char(5),@local_n_err)
					select @local_c_errmsg =
					":  replenishment delete failed. (nsparchivereplenishment) " + " ( " +
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
			*/
			-- End : June01
		end -- 5 
	end -- 4
	
	if @n_continue = 1 or @n_continue = 2
	begin
		select @b_success = 1
		execute nsplogalert
			@c_modulename   = "nsparchivereplenishment",
			@c_alertmessage = "archive of replenishment ended normally.",
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
				@c_modulename   = "nsparchivereplenishment",
				@c_alertmessage = "archive of replenishment ended abnormally - check this log for additional messages.",
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
			@c_modulename   = "nsparchivereplenishment",
			@c_alertmessage = "purging replenishment tables with confirmed = 'Y'",
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
		execute nsp_logerror @n_err, @c_errmsg, "nsparchivereplenishment"
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