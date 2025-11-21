SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : nspArchiveKitting                                      */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Wanyt                                                    */
/*                                                                      */
/* Purpose: Housekeep nspArchiveKitting table                           */
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
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-Jun-14  June                                                    */
/* 2005-Sep-28  Ong           Performance Tuning - cursor FAST_FORWARD  */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nspArchiveKitting]        
      @c_archivekey   NVARCHAR(10)
   ,  @b_success      int        output    
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
      @n_archive_kit_records   int, -- # of kit records to be archived
      @n_archive_kit_detail_records int, -- # of kitdetail records to be archived
      @n_default_id int,
      @n_strlen int,
      @local_n_err         int,
      @local_c_errmsg    NVARCHAR(254)
   
   declare @c_copyfrom_db  NVARCHAR(55),
      @c_copyto_db    NVARCHAR(55),
      @c_kitactive NVARCHAR(2),
      @c_kitstart NVARCHAR(10),
      @c_kitend NVARCHAR(10),
      @c_whereclause NVARCHAR(254),
      @c_temp NVARCHAR(254),
      @c_temp1 NVARCHAR(254),
      @copyrowstoarchivedatabase NVARCHAR(1)
   
   DECLARE @cKITKey NVARCHAR(10)   -- added 2005-Sep-27 (Ong)
          ,@cKITLineNumber NVARCHAR(5) 

   SELECT @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
      @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
   
   if @n_continue = 1 or @n_continue = 2
   begin -- 3
      SELECT  @c_copyfrom_db = livedatabasename,
         @c_copyto_db = archivedatabasename,
         @n_retain_days = kitnumberofdaystoretain,
         @c_kitactive = kitactive,
         @c_datetype = kitdatetype,
         @c_kitstart = isnull(kitstart,''),
         @c_kitend = isnull(kitend,'ZZZZZZZZZZ'),
         @copyrowstoarchivedatabase = copyrowstoarchivedatabase
      from archiveparameters (nolock)
      where archivekey = @c_archivekey
         
      if db_id(@c_copyto_db) is null
      begin
         SELECT @n_continue = 3
         SELECT @local_n_err = 77301
         SELECT @local_c_errmsg = convert(char(5),@local_n_err)
         SELECT @local_c_errmsg =
            ': target database ' + dbo.fnc_RTrim(@c_copyto_db) + ' does not exist ' + ' ( ' +
            ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')' + ' (nspArchiveKitting)'
      end

      SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
      SELECT @d_result = dateadd(day,1,@d_result)

      SELECT @b_success = 1
      SELECT @c_temp = 'archive of kitting started with parms; datetype = ' + dbo.fnc_RTrim(@c_datetype) +
         ' ; active = '+ dbo.fnc_RTrim(@c_kitactive)+
         ' ; Kitkey = '+dbo.fnc_RTrim(@c_kitstart)+'-'+dbo.fnc_RTrim(@c_kitend)+
         ' ; copy rows to archive = '+dbo.fnc_RTrim(@copyrowstoarchivedatabase) +
         ' ; retain days = '+ convert(char(6),@n_retain_days)
   
      execute nsplogalert
         @c_modulename   = 'nspArchiveKitting',
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
      SELECT @c_whereclause = ' '
      SELECT @c_temp = ' '
      
   
      SELECT @c_temp = 'AND KIT.KitKey BETWEEN '+ 'N'''+dbo.fnc_RTrim(@c_kitstart) + ''''+ ' AND '+
         'N'''+dbo.fnc_RTrim(@c_kitend)+''''
   
      if (@b_debug =1 )
      begin
         print 'subsetting clauses'
         SELECT 'execute clause @c_whereclause', @c_whereclause
         SELECT 'execute clause @c_temp ', @c_temp
      end
   
      if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
      begin 
         if (@b_debug =1 )
         begin
            print 'starting table existence check for kit...'
         end
         SELECT @b_success = 1
         exec nsp_build_archive_table 
            @c_copyfrom_db, 
            @c_copyto_db,
            'kit',
            @b_success output , 
            @n_err output , 
            @c_errmsg output
         if not @b_success = 1
         begin
            SELECT @n_continue = 3
         end
      end   
         
      if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
      begin 
         if (@b_debug =1 )
         begin
            print 'starting table existence check for kitdetail...'
         end
         SELECT @b_success = 1
         exec nsp_build_archive_table 
            @c_copyfrom_db, 
            @c_copyto_db,
            'kitdetail',
            @b_success output , 
            @n_err output , 
            @c_errmsg output
         if not @b_success = 1
         begin
            SELECT @n_continue = 3
         end
      end   

      if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
      begin
         if (@b_debug =1 )
         begin
            print 'building alter table string for kit...'
         end
         execute nspbuildaltertablestring 
            @c_copyto_db,
            'kit',
            @b_success output,
            @n_err output, 
            @c_errmsg output
         if not @b_success = 1
         begin
            SELECT @n_continue = 3
         end
      end

      if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
      begin
         if (@b_debug =1 )
         begin
            print 'building alter table string for kitdetail...'
         end
         execute nspbuildaltertablestring 
            @c_copyto_db,
            'kitdetail',
            @b_success output,
            @n_err output, 
            @c_errmsg output
         if not @b_success = 1
         begin
            SELECT @n_continue = 3
         end
      end
   
   
      WHILE @@TRANCOUNT > @n_starttcnt
         COMMIT TRAN 

      if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
      begin -- 5
/* BEGIN 2005-Sep-28 (Ong) */             
         if @c_datetype = '1' -- editdate
         begin
            SELECT @c_whereclause = "WHERE ( kit.editdate <= " + '"'+ convert(char(8),@d_result,112)+'"' + " ) " + @c_temp  
         end
   
         if @c_datetype = '2' -- adddate
         begin
            SELECT @c_whereclause = "WHERE ( kit.adddate <= " + '"'+ convert(char(8),@d_result,112)+'"' + " ) " + @c_temp 
         end

         SELECT @n_archive_kit_records = 0
         SELECT @n_archive_kit_detail_records  = 0
         
         EXEC (
         ' Declare C_KITKey CURSOR FAST_FORWARD READ_ONLY FOR ' + 
         ' SELECT KITKey ' +
         ' FROM KIT (NOLOCK) ' +
         ' JOIN (SELECT ExternKitKey FROM KIT (nolock) ' +
         '       WHERE ExternKitKey IS NOT NULL AND ExternKitKey <> '''' ' +
         '       GROUP BY ExternKitKey ' +
         '       HAVING COUNT(DISTINCT Status) = 1) AS ExternKit ' +
         ' ON  ExternKit.ExternKitKey = KIT.ExternKitKey ' +
          @c_WhereClause +
         ' AND KIT.ExternKitKey > '''' ' +
         ' AND (KIT.Status = ''9'')  ' + 
         ' UNION ' +
         ' SELECT KITKey ' +
         ' FROM Kit (NOLOCK) ' +
          @c_WhereClause +
         ' AND (KIT.ExternKitKey IS NULL OR KIT.ExternKitKey = '''') ' +
         ' AND (KIT.Status = ''9'')  ' + 
         ' ORDER BY KITKey' )
         
         OPEN C_KITKey
         
         FETCH NEXT FROM C_KITKey INTO @cKITKey
         
         WHILE @@fetch_status <> -1
         BEGIN
            BEGIN TRAN 

            UPDATE Kit WITH (ROWLOCK)
               SET ArchiveCop = '9' 
            WHERE KITKey = @cKITKey  

            SELECT @local_n_err = @@error   --, @n_cnt = @@rowcount            
            SELECT @n_archive_kit_records = @n_archive_kit_records + 1            
            if @local_n_err <> 0
            begin 
               SELECT @n_continue = 3
               SELECT @local_n_err = 77302
               SELECT @local_c_errmsg = convert(char(5),@local_n_err)
               SELECT @local_c_errmsg =
               ': update of archivecop failed - kit (nspArchiveKitting) ' + ' ( ' +
               ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
               ROLLBACK TRAN 
            end  
            ELSE
            BEGIN
               COMMIT TRAN 
            END 

            if (@n_continue = 1 or @n_continue = 2)
            BEGIN   
               DECLARE C_Detail_KitKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT KITLineNumber    
                 FROM KitDetail (nolock)
               WHERE KitKey = @cKitKey 
               ORDER BY KitDetail.KitKey        
    
               OPEN C_Detail_KitKey 
            
               FETCH NEXT FROM C_Detail_KitKey INTO @cKITLineNumber
            
               WHILE @@fetch_status <> -1
               BEGIN
                  BEGIN TRAN 

                  UPDATE KitDetail with (ROWLOCK) 
                     Set Archivecop = '9'
                  WHERE KitKey = @cKitKey  
                  AND   KITLineNumber = @cKITLineNumber 
     
                  SELECT @local_n_err = @@error --, @n_cnt = @@rowcount            
                  SELECT @n_archive_kit_detail_records  = @n_archive_kit_detail_records  + 1                                  
                  if @local_n_err <> 0
                  begin 
                     SELECT @n_continue = 3
                     SELECT @local_n_err = 77303
                     SELECT @local_c_errmsg = convert(char(5),@local_n_err)
                     SELECT @local_c_errmsg =
                     ': update of archivecop failed - kitdetail. (nspArchiveKitting) ' + ' ( ' +
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                     ROLLBACK TRAN 
                  end  
                  ELSE
                  BEGIN
                     COMMIT TRAN 
                  END 
 
      
                  FETCH NEXT FROM C_Detail_KitKey INTO @cKITLineNumber
               END -- while Receiptkey 
      
               CLOSE C_Detail_KitKey 
               DEALLOCATE C_Detail_KitKey               
            END -- (@n_continue = 1 or @n_continue = 2) Detail 
          
            FETCH NEXT FROM C_KITKey INTO @cKITKey
         END -- while KITKey 

         CLOSE C_KITKey
         DEALLOCATE C_KITKey

/* END 2005-Sep-28 (Ong) */
      
         if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
         begin
            SELECT @c_temp = 'attempting to archive ' + dbo.fnc_RTrim(convert(char(6),@n_archive_kit_records )) +
               ' kit records and ' + dbo.fnc_RTrim(convert(char(6),@n_archive_kit_detail_records )) + ' kitdetail records'
            execute nsplogalert
               @c_modulename   = 'nspArchiveKitting',
               @c_alertmessage = @c_temp ,
               @n_severity     = 0,
               @b_success       = @b_success output,
               @n_err          = @n_err output,
               @c_errmsg       = @c_errmsg output
            if not @b_success = 1
            begin
               SELECT @n_continue = 3
            end
         end 

         if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
         begin   
            if (@b_debug =1 )
            begin
               print 'building insert for kitdetail...'
            end
            SELECT @b_success = 1
            exec nsp_build_insert  
               @c_copyto_db, 
               'kitdetail',
               1,
               @b_success output , 
               @n_err output, 
               @c_errmsg output
            if not @b_success = 1
            begin
               SELECT @n_continue = 3
            end
         end   
      
         if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
         begin   
            if (@b_debug =1 )
            begin
               print 'building insert for kit...'
            end
            SELECT @b_success = 1
            exec nsp_build_insert  
               @c_copyto_db, 
               'kit',
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
         @c_modulename   = 'nspArchiveKitting',
         @c_alertmessage = 'archive of kit & kitdetail ended normally.',
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
            @c_modulename   = 'nspArchiveKitting',
            @c_alertmessage = 'archive of kit & kitdetail ended abnormally - check this log for additional messages.',
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
      execute nsp_logerror @n_err, @c_errmsg, 'nspArchiveKitting'
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