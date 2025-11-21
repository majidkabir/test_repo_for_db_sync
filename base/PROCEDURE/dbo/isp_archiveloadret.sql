SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_ArchiveLoadRet		                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Wanyt                                                    */
/*                                                                      */
/* Purpose: Housekeep LoadplanRetDetail table                           */
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
/* Called By: isp_archiveload                                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-Jun-15  June         Register PVCS : SOS18664                   */
/* 2005-Aug-10  Ong           SOS38267 : obselete sku & storerkey	    */
/* 2014-Mar-21  TLTING        SQL20112 Bug                              */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[isp_ArchiveLoadRet]
		@c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@copyrowstoarchivedatabase NVARCHAR(1),
		@b_success int output    
as
/*--------------------------------------------------------------*/
/* THIS ARCHIVE SCRIPT IS EXECUTED FROM isp_archiveload         */
/* 9 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters   */
/*--------------------------------------------------------------*/
begin -- main
/* BEGIN 2005-Aug-10 (SOS38267) */
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   

/* END 2005-Aug-10 (SOS38267) */

	declare @n_continue int        ,  
		@n_starttcnt int        , -- holds the current transaction count
		@n_cnt int              , -- holds @@rowcount after certain operations
		@b_debug int             -- debug on or off
	     
	/* #include <sparpo1.sql> */     
	declare
		@n_archive_loadret_detail_records	int, -- # of LoadplanRetDetail records to be archived
		@n_err         int,
		@c_errmsg    NVARCHAR(254),
		@local_n_err   int,
		@local_c_errmsg    NVARCHAR(254),
		@c_temp NVARCHAR(254)
	
	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	
	if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
	begin  
		if (@b_debug =1 )
		begin
			print 'starting table existence check for LoadplanRetDetail...'
		end
		select @b_success = 1
		exec nsp_build_archive_table 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'LoadplanRetDetail',
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
			print 'building alter table string for loadplandetail...'
		end
		execute nspbuildaltertablestring 
			@c_copyto_db,
			'LoadplanRetDetail',
			@b_success output,
			@n_err output, 
			@c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end

	begin tran
	if (@n_continue = 1 or @n_continue = 2)
	begin 
      declare @cLoadKey    NVARCHAR(10),
              @cLineLineNo NVARCHAR(5) 

		select lret.loadkey ret_loadkey,l.loadkey , l.archivecop 
		into #temp1
		from loadplan l (nolock)
		LEFT OUTER JOIN LoadplanRetDetail lret (nolock) ON lret.loadkey = l.loadkey	  --sql2012
		group by lret.loadkey, l.loadkey, l.archivecop

      select @n_archive_loadret_detail_records = 0 
      
      declare c_arc_LoadplanRetDetail cursor local read_only fast_forward for 
      select LoadplanRetDetail.LoadKey, LoadplanRetDetail.LoadLineNumber 
      from   LoadplanRetDetail (NOLOCK)
      join   #temp1 on LoadplanRetDetail.loadkey = #temp1.ret_loadkey 
		where ( (#temp1.loadkey is null) or ( #temp1.loadkey is not null and #temp1.archivecop = '9'))

      open c_arc_LoadplanRetDetail 

      fetch next from c_arc_LoadplanRetDetail into @cLoadKey, @cLineLineNo 
      while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2)
      begin
         update LoadplanRetDetail with (rowlock) 
            set archivecop = '9'
         where LoadplanRetDetail.loadkey = @cLoadKey 
         and   LoadplanRetDetail.LoadLineNumber = @cLineLineNo

   		select @local_n_err = @@error, @n_cnt = @@rowcount
   		select @n_archive_loadret_detail_records = @n_archive_loadret_detail_records + 1
   		if @local_n_err <> 0
   		begin 
   			select @n_continue = 3
   			select @local_n_err = 77301
   			select @local_c_errmsg = convert(char(5),@local_n_err)
   			select @local_c_errmsg =
   			': update of archivecop failed - LoadplanRetDetail. (isp_ArchiveLoadRet) ' + ' ( ' +
   			' sqlsvr message = ' + ltrim(rtrim(@local_c_errmsg)) + ')'
   		end 
         
         fetch next from c_arc_LoadplanRetDetail into @cLoadKey, @cLineLineNo 
      end
      close c_arc_LoadplanRetDetail 
      deallocate c_arc_LoadplanRetDetail

-- 		update LoadplanRetDetail
-- 		set LoadplanRetDetail.archivecop = '9'
-- 		from LoadplanRetDetail , #temp1 
-- 		where ( (#temp1.loadkey is null) or ( #temp1.loadkey is not null and #temp1.archivecop = '9'))
-- 		and LoadplanRetDetail.loadkey = #temp1.ret_loadkey 
-- 		
-- 		select @local_n_err = @@error, @n_cnt = @@rowcount
-- 		select @n_archive_loadret_detail_records = @n_cnt
-- 		if @local_n_err <> 0
-- 		begin 
-- 			select @n_continue = 3
-- 			select @local_n_err = 77301
-- 			select @local_c_errmsg = convert(char(5),@local_n_err)
-- 			select @local_c_errmsg =
-- 			': update of archivecop failed - LoadplanRetDetail. (isp_ArchiveLoadRet) ' + ' ( ' +
-- 			' sqlsvr message = ' + ltrim(rtrim(@local_c_errmsg)) + ')'
-- 		end 

		drop table #temp1 
	end


	if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
	begin
		select @c_temp = 'attempting to archive ' + rtrim(convert(char(6),@n_archive_loadret_detail_records )) +
			' LoadplanRetDetail records.' 
		execute nsplogalert
			@c_modulename   = 'isp_ArchiveLoadRet',
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
			print 'building insert for LoadplanRetDetail...'
		end
		select @b_success = 1
		exec nsp_build_insert  
			@c_copyto_db, 
			'LoadplanRetDetail',
			1,
			@b_success output , 
			@n_err output, 
			@c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end

	if (@n_continue = 1 or @n_continue = 2)
	begin 
      select @n_archive_loadret_detail_records = 0 
      
      declare c_arc_LoadplanRetDetail cursor local read_only fast_forward for 
      select LoadplanRetDetail.LoadKey, LoadplanRetDetail.LoadLineNumber 
      from   LoadplanRetDetail (NOLOCK)
		where archivecop = '9' 

      open c_arc_LoadplanRetDetail 

      fetch next from c_arc_LoadplanRetDetail into @cLoadKey, @cLineLineNo 
      while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2)
      begin
         delete LoadplanRetDetail
         where LoadplanRetDetail.loadkey = @cLoadKey 
         and   LoadplanRetDetail.LoadLineNumber = @cLineLineNo

   		select @local_n_err = @@error, @n_cnt = @@rowcount
   		select @n_archive_loadret_detail_records = @n_archive_loadret_detail_records + 1
   		if @local_n_err <> 0
   		begin 
   			select @n_continue = 3
   			select @local_n_err = 77301
   			select @local_c_errmsg = convert(char(5),@local_n_err)
   			select @local_c_errmsg =
   			': delete failed - LoadplanRetDetail. (isp_ArchiveLoadRet) ' + ' ( ' +
   			' sqlsvr message = ' + ltrim(rtrim(@local_c_errmsg)) + ')'
   		end 
         
         fetch next from c_arc_LoadplanRetDetail into @cLoadKey, @cLineLineNo 
      end
      close c_arc_LoadplanRetDetail 
      deallocate c_arc_LoadplanRetDetail
   end 
-- 	if @n_continue = 1 or @n_continue = 2
-- 	begin  
-- 		if (@b_debug =1 )
-- 		begin
-- 			print 'delete for LoadplanRetDetail...'
-- 		end
-- 		if (@b_debug = 0)
-- 		begin
-- 			delete from LoadplanRetDetail
-- 			where archivecop = '9'
-- 			select @local_n_err = @@error, @n_cnt = @@rowcount
-- 		end
-- 		if (@b_debug = 1)
-- 		begin
-- 			select * from LoadplanRetDetail (nolock)
-- 			where archivecop = '9'
-- 		end
-- 		if @local_n_err <> 0
-- 		begin  
-- 			select @n_continue = 3
-- 			select @n_err = 77302
-- 			select @local_c_errmsg = convert(char(5),@local_n_err)
-- 			select @local_c_errmsg =
-- 			':  LoadplanRetDetail delete failed. (isp_ArchiveLoadRet) ' + ' ( ' +
-- 			' sqlsvr message = ' + ltrim(rtrim(@local_c_errmsg)) + ')'
-- 		end      
-- 	end

	if @n_continue = 1 or @n_continue = 2
	begin
		commit tran
	end
	else
	begin
		rollback tran
	end
	
	if @n_continue = 1 or @n_continue = 2
	begin
		select @b_success = 1
		execute nsplogalert
			@c_modulename   = 'isp_ArchiveLoadRet',
			@c_alertmessage = 'archive of loadret ended successfully.',
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
				@c_modulename   = 'isp_ArchiveLoadRet',
				@c_alertmessage = 'archive of loadret failed - check this log for additional messages.',
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
		execute nsp_logerror @n_err, @c_errmsg, 'isp_ArchiveLoadRet'
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