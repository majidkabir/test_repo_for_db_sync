SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_ArchivePickList                                    */
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
/* Date         Author    Purposes                                      */
/* 2005-Aug_09  Shong     Performance Tuning                            */
/* 2005-Aug-10  Ong       SOS38267 : obselete sku & storerkey           */
/* 2005-Dec-01  Shong     Revise Build Insert SP - Check Duplicate      */
/*                        - Delete only when records inserted into      */
/*                        Archive Table.                                */
/* 13-APR-2006  June      Remove refkeylookup table                     */
/* 22-SEP-2008  Leong     SOS#116967 - Remove Hard Code 90 days for     */
/*                        archive and Pass in @d_result From scripts    */
/*                        isp_ArchiveLoad                               */
/* 22-JUL-2011  KHLim01   SOS#216562 - convert date format(yyyymmdd)    */
/************************************************************************/

CREATE PROC [dbo].[isp_ArchivePickList]
      @c_copyfrom_db  NVARCHAR(55),
      @c_copyto_db    NVARCHAR(55),
      @copyrowstoarchivedatabase NVARCHAR(1),
      @d_result datetime, -- SOS#116967
      @b_success                 int output    
as
/*--------------------------------------------------------------*/
-- THIS ARCHIVE SCRIPT IS EXECUTED FROM isp_archiveload
/*--------------------------------------------------------------*/
begin -- main
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @n_continue  int        ,  
      @n_starttcnt      int        , -- holds the current transaction count
      @n_cnt            int        , -- holds @@rowcount after certain operations
      @b_debug          int          -- debug on or off
        
   /* #include <sparpo1.sql> */     
   declare
      @n_archive_pick_header_records   int, -- # of pickheader records to be archived
      @n_err               int,
      @c_errmsg            NVARCHAR(254),
      @local_n_err         int,
      @local_c_errmsg      NVARCHAR(254),
      @c_temp              NVARCHAR(254),
      @n_archive_pickinginfo_records   int
      -- June01
      -- ,@n_archive_RefKeyLookup_records  int
   
   select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
      @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '

   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin  
      if (@b_debug =1 )
      begin
         print 'starting table existence check for pickheader...'
      end
      select @b_success = 1
      exec nsp_build_archive_table 
         @c_copyfrom_db, 
         @c_copyto_db, 
         'pickheader',
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
         print 'starting table existence check for pickinginfo...'
      end
      select @b_success = 1
      exec nsp_build_archive_table 
         @c_copyfrom_db, 
         @c_copyto_db, 
         'pickinginfo',
         @b_success output , 
         @n_err output, 
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end

   -- Start : June01
   /*
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin  
      if (@b_debug =1 )
      begin
         print 'starting table existence check for pickinginfo...'
      end
      select @b_success = 1
      exec nsp_build_archive_table 
         @c_copyfrom_db, 
         @c_copyto_db, 
         'RefKeyLookup',
         @b_success output , 
         @n_err output, 
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end
   */
   -- End : June01
   
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'building alter table string for pickheader...'
      end
      execute dbo.nspbuildaltertablestring 
         @c_copyto_db,
         'pickheader',
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
         print 'building alter table string for pickinginfo...'
      end
      execute dbo.nspbuildaltertablestring 
         @c_copyto_db,
         'pickinginfo',
         @b_success output,
         @n_err output, 
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end

   -- Start : June01
   /*
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'building alter table string for RefKeyLookup...'
      end
      execute dbo.nspbuildaltertablestring 
         @c_copyto_db,
         'RefKeyLookup',
         @b_success output,
         @n_err output, 
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end
   */
   -- End : June01
   
   while @@trancount > 0
      commit tran 

   declare @cPickHeaderKey NVARCHAR(10),
           @c_OrderKey     NVARCHAR(10),
           @nArchive       int, 
           @cType          NVARCHAR(10), 
           @cArchiveCop    NVARCHAR(1), 
           @cLoadKey       NVARCHAR(10) 
           

   if (@n_continue = 1 or @n_continue = 2)
   begin
      declare c_arc_pickheader cursor local fast_forward read_only for
      select pickheaderkey, orderkey, externorderkey, zone  
      from pickheader (nolock) 
      -- where adddate < dateadd(day, -90, getdate()) -- SOS#116967
      where adddate <= convert(char(8),@d_result,112) -- SOS#116967  -- KHLim01
      order by pickheaderkey 
   
      select @n_archive_pick_header_records = 0 
      select @n_archive_pickinginfo_records = 0 
      -- June01
      -- select @n_archive_RefKeyLookup_records = 0 
      open c_arc_pickheader 
   
      fetch next from c_arc_pickheader into @cPickHeaderKey, @c_OrderKey, @cLoadKey, @cType 
   
      while @@fetch_status <> -1 and ((@n_continue = 1 or @n_continue = 2))
      begin
         SET @nArchive = 0 

         IF @cType <> 'XD' AND @cType <> 'LB' AND @cType <> 'LP'          
         BEGIN 
            IF dbo.fnc_RTrim(@c_OrderKey) IS NULL OR dbo.fnc_RTrim(@c_OrderKey) = '' 
            BEGIN 
               SET ROWCOUNT 1 
               SELECT @cArchiveCop = ArchiveCop 
               FROM Loadplan (NOLOCK) WHERE LoadKey = @cLoadKey

               IF @cArchiveCop = '9' OR @@ROWCOUNT = 0 
               BEGIN
                  SET @nArchive = 1 
               END 

               SET ROWCOUNT 0 
            END 
            ELSE
            BEGIN
               SET ROWCOUNT 1 

               SELECT @cArchiveCop = ArchiveCop 
               FROM ORDERS (NOLOCK) WHERE OrderKey = @c_OrderKey

               IF @cArchiveCop = '9' OR @@ROWCOUNT = 0 
               BEGIN 
                  SET @nArchive = 1 
               END 

               SET ROWCOUNT 0 
            END 
         END 
         -- Start : June01
         /*
         ELSE
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM RefKeyLookup (NOLOCK)
                          JOIN  ORDERS (NOLOCK) ON ORDERS.OrderKey = RefKeyLookup.OrderKey 
                          WHERE PickslipNo = @cPickHeaderKey)
            BEGIN
               SET @nArchive = 1 
            END
            ELSE
            BEGIN
               SELECT @cArchiveCop = MAX(ORDERS.ArchiveCop)
               FROM RefKeyLookup (NOLOCK)
               JOIN  ORDERS (NOLOCK) ON ORDERS.OrderKey = RefKeyLookup.OrderKey 
               WHERE PickslipNo = @cPickHeaderKey 
   
               IF (@cArchiveCop = '9' )  
               BEGIN 
                  SET @nArchive = 1 
               END 
            END 
         END
         */
         ELSE
         BEGIN
            IF NOT EXISTS(SELECT 1 FROM RefKeyLookup (NOLOCK) WHERE PickslipNo = @cPickHeaderKey)
            BEGIN
               SET @nArchive = 1 
            END
         END
         -- End : June01
         
         IF @nArchive = 1
         BEGIN
            begin tran 

            update PickingInfo with (rowlock)
               set PickingInfo.archivecop = '9'
            where  PickSlipNo = @cPickHeaderKey 
            select @local_n_err = @@error, @n_cnt = @@rowcount
            select @n_archive_pickinginfo_records = @n_archive_pickinginfo_records + 1 
            if @local_n_err <> 0
            begin 
               select @n_continue = 3
               select @local_n_err = 77303
               select @local_c_errmsg = convert(char(5),@local_n_err)
               select @local_c_errmsg =
               ': update of archivecop failed - PickingInfo. (isp_ArchivePickList) ' + ' ( ' +
               ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
               rollback tran 
            end     
            else
            begin
               commit tran 
            end 
            
            begin tran 

            update pickheader with (rowlock)
               set pickheader.archivecop = '9'
            where  pickheaderkey = @cPickHeaderKey 
            select @local_n_err = @@error, @n_cnt = @@rowcount
            select @n_archive_pick_header_records = @n_archive_pick_header_records + 1 
            if @local_n_err <> 0
            begin 
               select @n_continue = 3
               select @local_n_err = 77303
               select @local_c_errmsg = convert(char(5),@local_n_err)
               select @local_c_errmsg =
               ': update of archivecop failed - pickheader. (isp_ArchivePickList) ' + ' ( ' +
               ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
               rollback tran 
            end     
            else
            begin
               commit tran 
            end 

            -- Start : June01
            /*
            IF @cType = 'XD' OR @cType = 'LB' OR @cType = 'LP'          
		      BEGIN
               begin tran

               update RefKeyLookup 
                  set archivecop = '9' 
               WHERE PickslipNo = @cPickHeaderKey 
               
               select @local_n_err = @@error, @n_cnt = @@rowcount
               select @n_archive_RefKeyLookup_records = @n_archive_RefKeyLookup_records + 1 
               if @local_n_err <> 0
               begin 
                  select @n_continue = 3
                  select @local_n_err = 77303
                  select @local_c_errmsg = convert(char(5),@local_n_err)
                  select @local_c_errmsg =
                  ': update of archivecop failed - PickingInfo. (isp_ArchivePickList) ' + ' ( ' +
                  ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                  rollback tran 
               end     
               else
               begin
                  commit tran 
               end   
            END 
            */
            -- End  : June01
         end 
         
         fetch next from c_arc_pickheader into @cPickHeaderKey, @c_OrderKey, @cLoadKey, @cType   
      end
      close c_arc_pickheader
      deallocate c_arc_pickheader
   end
   

   if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
   begin
      select @c_temp = 'attempting to archive ' + dbo.fnc_RTrim(convert(char(6),@n_archive_pick_header_records )) +
         ' pickheader records and ' + dbo.fnc_RTrim(convert(char(6),@n_archive_pickinginfo_records )) 
         -- June01         
         -- + 
         -- ' pickinginfo records and ' + dbo.fnc_RTrim(convert(char(6),@n_archive_RefKeyLookup_records )) + 
         -- ' RefKeyLookup records. ' 
      execute dbo.nsplogalert
         @c_modulename   = 'isp_ArchivePickList',
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

   -- Start : June01
   /*
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin   
      if (@b_debug =1 )
      begin
         print 'building insert for RefKeyLookup...'
      end
      select @b_success = 1
      exec nsp_build_insert  
         @c_copyto_db, 
         'RefKeyLookup',
         1,
         @b_success output , 
         @n_err output, 
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end
   */
   -- End : June01

   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin   
      if (@b_debug =1 )
      begin
         print 'building insert for pickinginfo...'
      end
      select @b_success = 1
      exec nsp_build_insert  
         @c_copyto_db, 
         'pickinginfo',
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
         print 'building insert for pickheader...'
      end
      select @b_success = 1
      exec nsp_build_insert  
         @c_copyto_db, 
         'pickheader',
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
      execute dbo.nsplogalert
         @c_modulename   = 'isp_ArchivePickList',
         @c_alertmessage = 'archive of pickheader ended successfully.',
         @n_severity     = 0,
         @b_success       = @b_success output,
         @n_err   = @n_err output,
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
         execute dbo.nsplogalert
            @c_modulename   = 'isp_ArchivePickList',
            @c_alertmessage = 'archive of pickheader failed - check this log for additional messages.',
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
      execute dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ArchivePickList'
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