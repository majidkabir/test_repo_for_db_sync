SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_ArchiveOrderScan                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Wanyt                                                    */
/*                                                                      */
/* Purpose: Housekeep Ordersscan table                                  */
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
/* Called By: isp_archiveload                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
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

CREATE PROC [dbo].[isp_ArchiveOrderScan]
		@c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@copyrowstoarchivedatabase NVARCHAR(1),
		@b_success int output    
as
/*--------------------------------------------------------------*/
/* THIS ARCHIVE SCRIPT IS EXECUTED FROM isp_archiveload         */
/* 9 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters   */
/*--------------------------------------------------------------*/
BEGIN -- MAIN
/* BEGIN 2005-Aug-10 (SOS38267) */
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
/* END 2005-Aug-10 (SOS38267) */

	DECLARE @n_continue INT        ,  
		@n_starttcnt INT        , -- holds the current transaction count
		@n_cnt INT              , -- holds @@rowcount after certain operations
		@b_debug INT             -- debug on or off
	     
	/* #include <sparpo1.sql> */     
	DECLARE
		@n_archive_orderscan_detail_records	INT, -- # of loadplanretdetail records to be archived
		@n_err         INT,
		@c_errmsg    NVARCHAR(254),
		@local_n_err   INT,
		@local_c_errmsg    NVARCHAR(254),
		@c_whereclause     NVARCHAR(254),
		@c_temp NVARCHAR(254)
   DECLARE
      @cLoadkey NVARCHAR(10), 
      @cOrderkey NVARCHAR(10)
	
	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	
	if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
	begin  
		if (@b_debug =1 )
		begin
			print 'starting table existence check for orderscan...'
		end
		select @b_success = 1
		exec nsp_build_archive_table 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'orderscan',
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
			print 'building alter table string for orderscan...'
		end
		execute nspbuildaltertablestring 
			@c_copyto_db,
			'orderscan',
			@b_success output,
			@n_err output, 
			@c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end

	while @@trancount > @n_starttcnt 
      commit tran

	if (@n_continue = 1 or @n_continue = 2)
	begin 
      select @n_archive_orderscan_detail_records = 0

      DECLARE C_ARC_ORDERSCAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT ORDERSCAN.Loadkey, ORDERSCAN.Orderkey
      FROM ORDERSCAN (NOLOCK) 
      LEFT OUTER JOIN LOADPLAN (NOLOCK) ON LOADPLAN.LoadKey = ORDERSCAN.Loadkey
      WHERE (LOADPLAN.LoadKey IS NULL OR LOADPLAN.ArchiveCop = '9')
      AND   ORDERSCAN.Orderkey LIKE 'P%'
      UNION ALL 
      SELECT ORDERSCAN.Loadkey, ORDERSCAN.Orderkey
      FROM ORDERSCAN (NOLOCK) 
      LEFT OUTER JOIN ORDERS (NOLOCK) ON ORDERS.Orderkey = ORDERSCAN.Orderkey
      WHERE (ORDERS.Orderkey IS NULL OR ORDERS.ArchiveCop = '9')
      AND   ORDERSCAN.OrderKey NOT LIKE 'P%'

      OPEN C_ARC_ORDERSCAN

      FETCH NEXT FROM C_ARC_ORDERSCAN into @cLoadkey, @cOrderkey

      while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2) 
      begin 
         begin tran 

   		update orderscan WITH (ROWLOCK) -- 2005-Aug-10 (SOS38267)
  		   set orderscan.archivecop = '9'
   		where Loadkey = @cLoadkey and Orderkey = @cOrderkey
   		
   		select @local_n_err = @@error, @n_cnt = @@rowcount
   		select @n_archive_orderscan_detail_records = @n_archive_orderscan_detail_records + 1
   		if @local_n_err <> 0
   		begin 
   			select @n_continue = 3
   			select @local_n_err = 77301
   			select @local_c_errmsg = convert(char(5),@local_n_err)
   			select @local_c_errmsg =
   			": update of archivecop failed - loadplanretdetail. (isp_ArchiveOrderScan) " + " ( " +
   			" sqlsvr message = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
            rollback tran 
   		end  
         else
         begin
            commit tran 
         end 

         fetch next from C_ARC_ORDERSCAN into @cLoadkey, @cOrderkey 
      end
      close C_ARC_ORDERSCAN
      deallocate C_ARC_ORDERSCAN

	end

	if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
	begin
		select @c_temp = "attempting to archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_orderscan_detail_records )) +
			" orderscan records." 
		execute nsplogalert
			@c_modulename   = "isp_ArchiveOrderScan",
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
			print "building insert for orderscan..."
		end
		select @b_success = 1
		exec nsp_build_insert  
			@c_copyto_db, 
			'orderscan',
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
		select @b_success = 1
		execute nsplogalert
			@c_modulename   = "isp_ArchiveOrderScan",
			@c_alertmessage = "archive of orderscan ended successfully.",
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
				@c_modulename   = "isp_ArchiveOrderScan",
				@c_alertmessage = "archive of orderscan failed - check this log for additional messages.",
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
		execute nsp_logerror @n_err, @c_errmsg, "isp_ArchiveOrderScan"
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