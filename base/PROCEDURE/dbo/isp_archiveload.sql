SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : isp_ArchiveLoad                                        */
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
/* Called By: nspArchiveShippingOrder                                   */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 15-Jun-2005  June          Script merging : SOS18664 done by Wanyt   */
/* 10-Aug-2005  Ong           SOS38267 : obselete sku & storerkey       */
/* 28-Nov-2005  Shong         Change Commit transaction strategy to row */
/*                            Level to Reduce Blocking.                 */
/* 08-Dec-2005  MaryVong      SOS43920 Archive Loadplan with Status='C',*/
/*                            ie. cancelled loadplan                    */ 
/* 09-May-2006  June          Bug fixed - Delete Loadplandetail before  */
/*                            Loadplan record                           */
/* 22-SEP-2008  Leong         SOS#116967 - Pass in @d_result From main  */
/*                            scripts nspArchiveShippingOrder           */
/* 29-Apr-2010  TLTING   1.2  LoadPLanLaneDetail                        */     
/* 05-Mar-2012  TLTING        Pack Archive fail. Merge pack archive to  */ 
/*                            Archive Pick script                       */ 
/* 22-Jul-2015  TLTING        Add table LoadPlanRetDetail               */
/* 25-Oct-2016  JayLim   1.3  Add table LoadPlan_SUP_Detail             */
/* 20-Sep-2021  TLTING   1.4  Perfromance tune - LoadPlan_SUP_Detail    */
/************************************************************************/

CREATE PROC [dbo].[isp_ArchiveLoad]
		@c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@copyrowstoarchivedatabase NVARCHAR(1),
		@d_result datetime, -- SOS#116967
		@b_success int output    
as
/*--------------------------------------------------------------*/
-- THIS ARCHIVE SCRIPT IS EXECUTED FROM nsparchiveshippingorder
/*--------------------------------------------------------------*/
begin -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
	set nocount on
	declare @n_continue int        ,  
		@n_starttcnt int        , -- holds the current transaction count
		@n_cnt int              , -- holds @@rowcount after certain operations
		@b_debug int             -- debug on or off
	     
	/* #include <sparpo1.sql> */     
	declare
		@n_archive_load_records	int, -- # of loadplan records to be archived
		@n_archive_load_detail_records	int, -- # of loadplandetail records to be archived
		@n_err             int,
		@c_errmsg          NVARCHAR(254),
		@local_n_err       int,
		@local_c_errmsg    NVARCHAR(254),
		@c_temp            NVARCHAR(254), 
      @cLoadKey          NVARCHAR(10),
      @cLoadLine         NVARCHAR(5),
      @c_SKU             NVARCHAR(20), --(Jay01)
      @n_LP_SUP_RowRefNo INT	

	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '

   Declare @cExternOrderKey NVARCHAR(20)
   , @cConsigneeKey  NVARCHAR(15)
   , @cLP_LaneNumber NVARCHAR(5)
   , @n_archive_loadlane_detail_records int
   , @n_archive_loadRetdetail_records int
   , @n_archive_loadplan_sup_detail_records int --(Jay01)
   
   SET @n_archive_loadlane_detail_records = 0
   SET @n_archive_loadRetdetail_records = 0
   SET @n_archive_loadplan_sup_detail_records = 0 --(Jay01)

	begin tran
	
	if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
	begin  
		if (@b_debug =1 )
		begin
			print 'starting table existence check for loadplan...'
		end
		select @b_success = 1
		exec nsp_build_archive_table 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'loadplan',
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
			print 'starting table existence check for loadplandetail...'
		end
		select @b_success = 1
		exec nsp_build_archive_table 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'loadplandetail',
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
			print 'starting table existence check for loadplandetail...'
		end
		select @b_success = 1
		exec nsp_build_archive_table 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'LoadPlanLaneDetail',
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
			print 'starting table existence check for LoadPlanRetDetail...'
		end
		select @b_success = 1
		exec nsp_build_archive_table 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'LoadPlanRetDetail',
			@b_success output , 
			@n_err output, 
			@c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end	
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y') -- (Jay01)
	begin  
		if (@b_debug =1 )
		begin
			print 'starting table existence check for LoadPlan_SUP_Detail...'
		end
		select @b_success = 1
		exec nsp_build_archive_table 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'LoadPlan_SUP_Detail',
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
			print 'building alter table string for loadplan...'
		end
		execute nspbuildaltertablestring 
			@c_copyto_db,
			'loadplan',
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
			print 'building alter table string for loadplandetail...'
		end
		execute nspbuildaltertablestring 
			@c_copyto_db,
			'loadplandetail',
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
			print 'building alter table string for loadplandetail...'
		end
		execute nspbuildaltertablestring 
			@c_copyto_db,
			'LoadPlanLaneDetail',
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
			print 'building alter table string for LoadPlanRetDetail...'
		end
		execute nspbuildaltertablestring 
			@c_copyto_db,
			'LoadPlanRetDetail',
			@b_success output,
			@n_err output, 
			@c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end

   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y') --(Jay01)
	begin
		if (@b_debug =1 )
		begin
			print 'building alter table string for LoadPlan_SUP_Detail...'
		end
		execute nspbuildaltertablestring 
			@c_copyto_db,
			'LoadPlan_SUP_Detail',
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
      select @n_archive_load_records = 0 
      select @n_archive_load_detail_records = 0 

      DECLARE c_arc_loadplan CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT ORDERDETAIL.LOADKEY 
         FROM  ORDERDETAIL (NOLOCK) 
   		JOIN  ORDERS (NOLOCK) ON ORDERDETAIL.OrderKey = ORDERS.OrderKey  -- Add by June 11.Feb.04	(SOS19875)
   		-- SOS44265
   		-- WHERE ORDERS.Status <> 'CANC'  -- Add by June 11.Feb.04	(SOS19875)
         GROUP BY ORDERDETAIL.LOADKEY 
         HAVING COUNT(DISTINCT ISNULL(OrderDetail.archivecop, '')) = 1 
         AND MAX(ISNULL(OrderDetail.ArchiveCop, '')) = '9'
      UNION ALL
         SELECT LOADPLAN.LOADKEY  
         FROM   LOADPLAN (NOLOCK)
         LEFT OUTER JOIN (SELECT LOADPLANDETAIL.LOADKEY FROM LOADPLANDETAIL (NOLOCK) 
                          JOIN ORDERS (NOLOCK) ON  ORDERS.OrderKey = LOADPLANDETAIL.OrderKey) AS LP 
                     ON LP.LOADKEY = LOADPLAN.LOADKEY 
         WHERE (LOADPLAN.Status = '9' OR LOADPLAN.Status = 'C' OR LOADPLAN.Status = 'CANC') -- SOS43920
         AND   LP.LOADKEY IS NULL 
      UNION ALL 
         SELECT LOADKEY 
         FROM  ORDERS (NOLOCK) 
         WHERE (ORDERS.UserDefine08 = '2' OR TYPE = 'M') 
         AND   LOADKEY > '' 
         GROUP BY LOADKEY
         HAVING COUNT(DISTINCT ISNULL(ORDERS.archivecop, '')) = 1 
         AND MAX(ISNULL(ORDERS.ArchiveCop, '')) = '9' 

      open c_arc_loadplan
      
      FETCH NEXT FROM C_ARC_LOADPLAN INTO @cLoadKey 

      while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2)
      begin
         IF NOT EXISTS(SELECT 1 FROM LOADPLANDETAIL L (NOLOCK) 
                                JOIN ORDERS O (NOLOCK) ON O.OrderKey = L.OrderKey 
                                WHERE O.Status < '9'
                                AND   L.LoadKey = @cLoadKey) 
         BEGIN 
            begin tran 
   
            UPDATE loadplan WITH (ROWLOCK) 
            set loadplan.archivecop = '9'
            where loadplan.loadkey = @cLoadKey 
            
            select @local_n_err = @@error, @n_cnt = @@rowcount
            select @n_archive_load_records = @n_archive_load_records + 1
            if @local_n_err <> 0
            begin 
               select @n_continue = 3
               select @local_n_err = 77303
               select @local_c_errmsg = convert(char(5),@local_n_err)
               select @local_c_errmsg = 
               ': update of archivecop failed - loadplandetail. (isp_ArchiveLoad) ' + ' ( ' +
               ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
               rollback tran 
            end  
            else
            begin
               commit tran 
            end 
   
            if @n_continue = 1 or @n_continue = 2
            begin
               declare c_arc_loadplandetail cursor local fast_forward read_only for 
                select LoadLineNumber 
                from   LoadplanDetail (nolock)
                where  LoadKey = @cLoadKey 
                order by LoadLineNumber
               
               open c_arc_loadplandetail
      
               FETCH NEXT FROM c_arc_loadplandetail into @cLoadLine 
         
               while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2)
               begin
                  begin tran 
   
                  update loadplandetail with (rowlock) 
                  set loadplandetail.archivecop = '9'
                  where loadkey = @cLoadKey and LoadLineNumber = @cLoadLine
                  select @local_n_err = @@error, @n_cnt = @@rowcount
                  select @n_archive_load_detail_records = @n_archive_load_detail_records + 1
                  if @local_n_err <> 0
                  begin 
                     select @n_continue = 3
                     select @local_n_err = 77303
                     select @local_c_errmsg = convert(char(5),@local_n_err)
                     select @local_c_errmsg =
                     ': update of archivecop failed - loadplandetail. (isp_ArchiveLoad) ' + ' ( ' +
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                     rollback tran 
                  end  
                  else
                  begin
                     commit tran 
                  end  
      
                  FETCH NEXT FROM c_arc_loadplandetail into @cLoadLine 
               end
               close c_arc_loadplandetail 
               deallocate c_arc_loadplandetail
            end
            
            -- ttl 29 April 2010
            if @n_continue = 1 or @n_continue = 2  
            begin  
               declare c_arc_loadplanlanedetail cursor local fast_forward read_only for   
                select ExternOrderKey, ConsigneeKey, LP_LaneNumber   
                from   LoadPlanLaneDetail (nolock)  
                where  LoadKey = @cLoadKey   
                 
               open c_arc_loadplanlanedetail  
        
               FETCH NEXT FROM c_arc_loadplanlanedetail into @cExternOrderKey, @cConsigneeKey , @cLP_LaneNumber  
           
               while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2)  
               begin  
                  begin tran   
     
                  update LoadPlanLaneDetail with (rowlock)   
                  set archivecop = '9'  
                  where loadkey = @cLoadKey 
                  and ExternOrderKey = @cExternOrderKey  
                  and ConsigneeKey   = @cConsigneeKey
                  and LP_LaneNumber  = @cLP_LaneNumber
                  select @local_n_err = @@error, @n_cnt = @@rowcount  
                  select @n_archive_loadlane_detail_records = @n_archive_loadlane_detail_records + 1  
                  if @local_n_err <> 0  
                  begin   
                     select @n_continue = 3  
                     select @local_n_err = 77303  
                     select @local_c_errmsg = convert(char(5),@local_n_err)  
                     select @local_c_errmsg =  
                     ': update of archivecop failed - LoadPlanLaneDetail. (isp_ArchiveLoad) ' + ' ( ' +  
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
                     rollback tran   
                  end    
                else  
                  begin  
                     commit tran   
                  end    
        
                  FETCH NEXT FROM c_arc_loadplanlanedetail into @cExternOrderKey, @cConsigneeKey , @cLP_LaneNumber    
               end  
               close c_arc_loadplanlanedetail   
               deallocate c_arc_loadplanlanedetail  
            end  


            if @n_continue = 1 or @n_continue = 2
            begin
               declare c_arc_LoadPlanRetDetail cursor local fast_forward read_only for 
                select LoadLineNumber 
                from   LoadPlanRetDetail (nolock)
                where  LoadKey = @cLoadKey 
                order by LoadLineNumber
               
               open c_arc_LoadPlanRetDetail
      
               FETCH NEXT FROM c_arc_LoadPlanRetDetail into @cLoadLine 
         
               while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2)
               begin
                  begin tran 
   
                  update LoadPlanRetDetail with (rowlock) 
                  set archivecop = '9'
                  where loadkey = @cLoadKey and LoadLineNumber = @cLoadLine
                  select @local_n_err = @@error, @n_cnt = @@rowcount
                  select @n_archive_loadRetdetail_records = @n_archive_loadRetdetail_records + 1
                  if @local_n_err <> 0
                  begin 
                     select @n_continue = 3
                     select @local_n_err = 77303
                     select @local_c_errmsg = convert(char(5),@local_n_err)
                     select @local_c_errmsg =
                     ': update of archivecop failed - LoadPlanRetDetail. (isp_ArchiveLoad) ' + ' ( ' +
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                     rollback tran 
                  end  
                  else
                  begin
                     commit tran 
                  end  
      
                  FETCH NEXT FROM c_arc_LoadPlanRetDetail into @cLoadLine 
               end
               close c_arc_LoadPlanRetDetail 
               deallocate c_arc_LoadPlanRetDetail
            end   
                
           if @n_continue = 1 or @n_continue = 2 --(Jay01)
            begin
               declare c_arc_LoadPlan_SUP_Detail cursor local fast_forward read_only for 
                select RowRefNo 
                from   LoadPlan_SUP_Detail (nolock)
                where  LoadKey = @cLoadKey  
               
               open c_arc_LoadPlan_SUP_Detail
      
               FETCH NEXT FROM c_arc_LoadPlan_SUP_Detail into @n_LP_SUP_RowRefNo 
         
               while @@fetch_status <> -1 and (@n_continue = 1 or @n_continue = 2)
               begin
                  begin tran 
   
                  update LoadPlan_SUP_Detail with (rowlock) 
                  set archivecop = '9'
                  WHERE RowRefNo = @n_LP_SUP_RowRefNo
                  select @local_n_err = @@error, @n_cnt = @@rowcount
                  select @n_archive_loadplan_sup_detail_records = @n_archive_loadplan_sup_detail_records + 1
                  if @local_n_err <> 0
                  begin 
                     select @n_continue = 3
                     select @local_n_err = 77303
                     select @local_c_errmsg = convert(char(5),@local_n_err)
                     select @local_c_errmsg =
                     ': update of archivecop failed - LoadPlan_SUP_Detail. (isp_ArchiveLoad) ' + ' ( ' +
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                     rollback tran 
                  end  
                  else
                  begin
                     commit tran 
                  end  
      
                  FETCH NEXT FROM c_arc_LoadPlan_SUP_Detail into @n_LP_SUP_RowRefNo 
               end
               close c_arc_LoadPlan_SUP_Detail 
               deallocate c_arc_LoadPlan_SUP_Detail
            end      
                    
         END -- Not Order Found With status < '9'

         FETCH NEXT FROM C_ARC_LOADPLAN INTO @cLoadKey 
      end 
      close c_arc_loadplan
      deallocate c_arc_loadplan 
   end      

   if (@n_continue = 1 or @n_continue = 2)  
   begin  
   if (@b_debug =1 )  
   begin  
   print 'archiving PicknPack...'  
   end  
   select @b_success = 1  
   execute isp_ArchivePicknPack   --isp_archivepicklist  
   @c_copyfrom_db,  
   @c_copyto_db,  
   @copyrowstoarchivedatabase,  
   @d_result, -- SOS#116967  
   @b_success output  
   if not @b_success = 1  
   begin  
   select @n_continue = 3  
   select @local_n_err = 77305  
   select @local_c_errmsg = convert(char(5),@local_n_err)  
   select @local_c_errmsg =  
   ': archiving of picklist failed - (nsparchiveshippingorder) ' + ' ( ' +  
   ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
   end  
   end    

	if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
	begin
		select @c_temp = 'attempting to archive ' + dbo.fnc_RTrim(convert(char(6),@n_archive_load_records )) +
			' loadplan records, ' + dbo.fnc_RTrim(convert(char(6),@n_archive_load_detail_records )) + ' loadplandetail records ' +
			' and ' + RTRIM(convert(nvarchar(10),@n_archive_loadRetdetail_records) ) + ' LoadRetdetail_records ' +
         ' and ' + RTRIM(convert(nvarchar(10),@n_archive_loadplan_sup_detail_records) ) + ' LoadPlan_SUP_detail_records ' --(Jay01)
			
		execute nsplogalert
			@c_modulename   = 'isp_ArchiveLoad',
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
			print 'building insert for loadplandetail...'
		end
		select @b_success = 1
		exec nsp_build_insert  
			@c_copyto_db, 
			'LoadPlanLaneDetail',
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
			print 'building insert for LoadPlanRetDetail...'
		end
		select @b_success = 1
		exec nsp_build_insert  
			@c_copyto_db, 
			'LoadPlanRetDetail',
			1,
			@b_success output , 
			@n_err output, 
			@c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end

   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y') --(Jay01)
	begin   
		if (@b_debug =1 )
		begin
			print 'building insert for LoadPlan_SUP_Detail...'
		end
		select @b_success = 1
		exec nsp_build_insert  
			@c_copyto_db, 
			'LoadPlan_SUP_Detail',
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
			print 'building insert for loadplandetail...'
		end
		select @b_success = 1
		exec nsp_build_insert  
			@c_copyto_db, 
			'loadplandetail',
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
			print 'building insert for loadplan...'
		end
		select @b_success = 1
		exec nsp_build_insert  
			@c_copyto_db, 
			'loadplan',
			1,
			@b_success output , 
			@n_err output, 
			@c_errmsg output
		if not @b_success = 1
		begin
			select @n_continue = 3
		end
	end

   while @@trancount > @n_starttcnt 
      commit tran

	
	if @n_continue = 1 or @n_continue = 2
	begin
		select @b_success = 1
		execute nsplogalert
			@c_modulename   = "isp_ArchiveLoad",
			@c_alertmessage = "archive of load ended successfully.",
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
				@c_modulename   = "isp_ArchiveLoad",
				@c_alertmessage = "archive of load failed - check this log for additional messages.",
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
		execute nsp_logerror @n_err, @c_errmsg, 'isp_ArchiveLoad'
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