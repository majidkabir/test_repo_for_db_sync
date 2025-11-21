SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : nspArchiveID 			                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Wanyt                                                    */
/*                                                                      */
/* Purpose: Housekeep ID table														*/
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
/* Called By: 					                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-Jun-15  June				Register PVCS : SOS18664 					   */
/* 2005-Aug-10  Ong 				SOS38267 : obselete sku & storerkey		   */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nspArchiveID]         
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
		@c_datetype NVARCHAR(10),      -- 1=editdate, 3=adddate
		@n_archive_id_records   int, -- # of ID records to be archived
		@n_archive_lotxlocxid_records   int, -- # of lotxlocxid records to be archived
		@n_default_id int,
		@n_strlen int,
		@local_n_err         int,
		@local_c_errmsg    NVARCHAR(254)
	
	declare @c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@c_idactive NVARCHAR(2),
		@c_idstart NVARCHAR(10),
 		@c_idend NVARCHAR(10),
		@c_whereclause NVARCHAR(1000),
		@c_temp NVARCHAR(254),
		@c_temp1 NVARCHAR(254),
		@copyrowstoarchivedatabase NVARCHAR(1)
   declare @id NVARCHAR(18), @lot NVARCHAR(10), @loc NVARCHAR(10)    -- 2005-Aug-10 (SOS38267) 

	
	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	
	if @n_continue = 1 or @n_continue = 2
	begin -- 3
		select  @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
 			@c_idactive = idactive,
			@c_idstart = isnull(idstart,''),
			@c_idend = isnull(idend,'ZZZZZZZZZZ'),
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
				" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nspArchiveID)'
		end


		select @b_success = 1
		select @c_temp = 'archive of id started with parms; active = '+ dbo.fnc_RTrim(@c_idactive)+
			' ; id = '+dbo.fnc_RTrim(@c_idstart)+'-'+dbo.fnc_RTrim(@c_idend)+
			' ; copy rows to archive = '+dbo.fnc_RTrim(@copyrowstoarchivedatabase)
	
		execute nsplogalert
			@c_modulename   = "nspArchiveID",
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
		
	
		select @c_temp = 'and id.id between '+ 'N'''+dbo.fnc_RTrim(@c_idstart) + ''''+ ' and '+
			         'N'''+dbo.fnc_RTrim(@c_idend)+''' '
		
		if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
		begin 
			if (@b_debug =1 )
			begin
				print 'starting table existence check for id...'
			end
			select @b_success = 1
			exec nsp_build_archive_table 
				@c_copyfrom_db, 
				@c_copyto_db,
				'id',
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
				print 'starting table existence check for lotxlocxid...'
			end
			select @b_success = 1
			exec nsp_build_archive_table 
				@c_copyfrom_db, 
				@c_copyto_db,
				'lotxlocxid',
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
				print 'building alter table string for id...'
			end
			execute nspbuildaltertablestring 
				@c_copyto_db,
				'id',
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
				print 'building alter table string for lotxlocxid...'
			end
			execute nspbuildaltertablestring 
				@c_copyto_db,
				'lotxlocxid',
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
/* BEGIN (SOS38267) UPDATE with rowlock*/		
      declare c_arc_id cursor local fast_forward read_only for 
         SELECT ID.ID
         FROM ID LEFT OUTER JOIN pickdetail (NOLOCK) on pickdetail.id = id.id
         WHERE ID.ID IN ( SELECT lotxlocxid.id from lotxlocxid (NOLOCK) 
                          GROUP BY lotxlocxid.id 
                          HAVING sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) = 0 and sum(lotxlocxid.qty) = 0) 
         and pickdetail.id IS NULL 
         and id.id between dbo.fnc_RTrim(@c_idstart) AND dbo.fnc_RTrim(@c_idend)
 
      open c_arc_id
      
      fetch next from c_arc_id into @id

      while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2)
      begin
   		UPDATE id WITH (ROWLOCK) 
   		set id.archivecop = '9'
   		where id.id = @id 

         select @local_n_err = @@error, @n_cnt = @@rowcount
         select @n_archive_id_records = @n_archive_id_records + 1
   		if @local_n_err <> 0
   		begin 
   			select @n_continue = 3
   			select @local_n_err = 77303
   			select @local_c_errmsg = convert(char(5),@local_n_err)
   			select @local_c_errmsg = 
   			': update of archivecop failed - id. (isp_ArchiveID) ' + ' ( ' +
   			' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
   		end  

         if @n_continue = 1 or @n_continue = 2
         begin
             declare c_arc_lotxlocxid cursor local fast_forward read_only for 
             select lot, loc
             from   lotxlocxid (nolock)
             where  id = @id 

               
            open c_arc_lotxlocxid
   
            fetch next from c_arc_lotxlocxid into @lot, @loc 
      
            while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2)
            begin
   				update lotxlocxid WITH (ROWLOCK)    -- modified WITH (ROWLOCK) by Ong sos38267
   				set lotxlocxid.archivecop = '9'
   				from id (nolock),
               lotxlocxid  
   				where (id.id = lotxlocxid.id) AND id.archivecop = '9'
   				AND lot = @lot and loc =@loc and id.id = @id
                  
   				select @local_n_err = @@error, @n_cnt = @@rowcount
   				select @n_archive_lotxlocxid_records = @n_cnt
   				if @local_n_err <> 0
   				begin 
   					select @n_continue = 3
   					select @local_n_err = 77303
   					select @local_c_errmsg = convert(char(5),@local_n_err)
   					select @local_c_errmsg =
   					": update of archivecop failed - lotxlocxid. (nspArchiveID) " + " ( " +
   					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
   				end     
               fetch next from c_arc_lotxlocxid into @lot, @loc
            end
            close c_arc_lotxlocxid
            deallocate c_arc_lotxlocxid
         end

         fetch next from c_arc_id into @id 
      end 
      close c_arc_id
      deallocate c_arc_id
	
-- 			select @c_whereclause = "update id " +
-- 											"set archivecop = '9' " +
-- 											"from id left outer join pickdetail (nolock) on pickdetail.id = id.id " +
-- 											"where id.id in ( select lotxlocxid.id from lotxlocxid (nolock) " +
-- 								         "						group by lotxlocxid.id " +
-- 											"						having sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) = 0 and sum(lotxlocxid.qty) = 0) " +
-- 											"and pickdetail.id is null "
--      		execute (@c_whereclause+ @c_temp)
-- 
-- 			select @local_n_err = @@error, @n_cnt = @@rowcount
-- 			select @n_archive_id_records = @n_cnt
-- 						
-- 			if @local_n_err <> 0
-- 			begin 
-- 				select @n_continue = 3
-- 				select @local_n_err = 77302
-- 				select @local_c_errmsg = convert(char(5),@local_n_err)
-- 				select @local_c_errmsg =
-- 				': update of archivecop failed - id (nspArchiveID) ' + ' ( ' +
-- 				' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
-- 			end  
-- 		
-- 			if (@n_continue = 1 or @n_continue = 2)
-- 			begin 
-- 				update lotxlocxid
-- 				set lotxlocxid.archivecop = '9'
-- 				from id , lotxlocxid
-- 				where id.id = lotxlocxid.id
-- 				and   id.archivecop = '9'
-- 
-- 				select @local_n_err = @@error, @n_cnt = @@rowcount
-- 				select @n_archive_lotxlocxid_records = @n_cnt
-- 				if @local_n_err <> 0
-- 				begin 
-- 					select @n_continue = 3
-- 					select @local_n_err = 77303
-- 					select @local_c_errmsg = convert(char(5),@local_n_err)
-- 					select @local_c_errmsg =
-- 					": update of archivecop failed - lotxlocxid. (nspArchiveID) " + " ( " +
-- 					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
-- 				end  
-- 			end 
		
			if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
			begin
				select @c_temp = "attempting to archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_id_records )) +
					" id records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_lotxlocxid_records )) + " lotxlocxid records"
				execute nsplogalert
					@c_modulename   = "nspArchiveID",
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
					print "building insert for id..."
				end
				select @b_success = 1
				exec nsp_build_insert  
					@c_copyto_db, 
					'id',
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
					print "building insert for lotxlocxid..."
				end
				select @b_success = 1
				exec nsp_build_insert  
					@c_copyto_db, 
					'lotxlocxid',
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
					print "delete for lotxlocxid..."
				end
				if (@b_debug = 0)
				begin
					delete from lotxlocxid
					where archivecop = '9'
					select @local_n_err = @@error, @n_cnt = @@rowcount
				end
				if (@b_debug = 1)
				begin
					select * from lotxlocxid
					where archivecop = '9'
				end
				if @local_n_err <> 0
				begin  
					select @n_continue = 3
					select @n_err = 77304
					select @local_c_errmsg = convert(char(5),@local_n_err)
					select @local_c_errmsg =
					":  id delete failed. (nspArchiveID) " + " ( " +
					" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
				end      
			end    

			if @n_continue = 1 or @n_continue = 2
			begin  
				if (@b_debug =1 )
				begin
					print "delete for id..."
				end
				if (@b_debug = 0)
				begin
					delete from id
					where archivecop = '9'
					select @local_n_err = @@error, @n_cnt = @@rowcount
				end
				if (@b_debug = 1)
				begin
					select * from id
					where archivecop = '9'
				end
				if @local_n_err <> 0
				begin  
					select @n_continue = 3
					select @n_err = 77305
					select @local_c_errmsg = convert(char(5),@local_n_err)
					select @local_c_errmsg =
					":  id delete failed. (nspArchiveID) " + " ( " +
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
			@c_modulename   = "nspArchiveID",
			@c_alertmessage = "archive of id & lotxlocxid ended normally.",
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
				@c_modulename   = "nspArchiveID",
				@c_alertmessage = "archive of id & lotxlocxid ended abnormally - check this log for additional messages.",
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
			@c_modulename   = "nspArchiveID",
			@c_alertmessage = "purging id & lotxlocxid tables",
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
		execute nsp_logerror @n_err, @c_errmsg, "nspArchiveID"
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