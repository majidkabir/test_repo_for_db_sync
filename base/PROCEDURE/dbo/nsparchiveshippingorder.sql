SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************************************/      
/* Stored Proc : nspArchiveShippingOrder                                                                 */      
/* Creation Date:                                                                                        */      
/* Copyright: IDS                                                                                        */      
/* Written by:                                                                                           */      
/*                                                                                                       */      
/* Purpose: THIS ARCHIVE SCRIPT WILL PURGE THE FOLLOWING TABLES:                                         */      
/*          Orders, OrderDetail, PickDetail, LOADPLAN, LOADPLANDETAIL,                                   */      
/*          MBOL, MBOLDetail, PICKINGINFO, PICKHEADER, REFKEYLOOKUP                                      */      
/*          OrderDetailRef, OrderInfo                                                                    */      
/*                                                                                                       */       
/* Data Modifications:                                                                                   */      
/*                                                                                                       */      
/* Updates:                                                                                              */      
/* Date         Author        Purposes                                                                   */      
/* 15-Aug-2005  Shong         Add nolock when building the insert  statement.                            */      
/* 2005-Nov-28  Shong         Change COMMIT transaction strategy to row Level to Reduce Blocking.        */      
/* 2005-Dec-9   Shong         Delete live records when sucessfully inserted into Archive DB              */       
/*                            AND Calling Archive Pack                                                   */      
/* 13-APR-2006  June          Add refkeylookup table                                                     */      
/* 22-SEP-2008  Leong         SOS#116967 - Add Orders.SOStatus check AND pass in @d_result               */      
/*                            to sub scripts isp_ArchiveLoad & isp_ArchivePickList                       */      
/* 12-FEB-2009  Leong         SOS#128677 - Filter Orders.SOStatus = '9' AND Orders.Status <> '9'         */      
/*                            (for ConfigKey 'WTS-ITF' is turn on)                                       */        
/* 04-MAY-2010  Leong         SOS#171555 - Bug Fix                                                       */      
/* 22-JUL-2011  KHLim01       SOS#216562 - convert date format(yyyymmdd)                                 */      
/* 05-Mar-2012  TLTING        Pack Archive fail. Merge pack archive to Archive Pick script               */      
/* 25-JUL-2013  KHLim         SOS#284236 - check PICKDETAIL.Status(KH02)                                 */      
/* 07-Feb-2014  TLTING        Archive OrderDetailRef                                                     */      
/* 07-Feb-2014  TLTING        Archive OrderInfo                                                          */      
/* 15-Apr-2014  TLTING        SQL2012 Bug fix                                                            */      
/* 21-Aug-2014  TLTING        remove Orders.Type filtering                                               */      
/* 20-Jul-2015  TLTING        Delete Preallocatepickdetail                                               */      
/* 02-Aug-2018  TLTING        Archive Caretontrack                                                       */      
/* 22-Apr-2020 kelvinongcy    WMS-12986 Change Archive CartonTrack not during Orders archive task,       */      
/*                            but when POD archive (kocy01)                                              */      
/* 12-Oct-2020  TLTING01      Archive Orders_PI_Encrypted                                                */      
/* 01-Oct-2022  TLTING02      Archive PickingVoice                                                       */      
/* 10-03-2023  kelvinongcy    WMS-21896 Delay Mbol Archive with validate orders days retention (kocy02)  */    
/*                                                                                                       */    
/*********************************************************************************************************/      
      
CREATE   PROC [dbo].[nspArchiveShippingOrder]      
      @c_archivekey   NVARCHAR(10)      
   ,  @b_success      int        OUTPUT      
   ,  @n_err          int        OUTPUT      
   ,  @c_errmsg       NVARCHAR(250)  OUTPUT      
AS      
BEGIN -- main      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @n_continue                    int      
         , @n_starttcnt                   int      -- holds the current transaction count      
         , @n_cnt                         int      -- holds @@rowcount after certain operations      
         , @b_debug                       int      -- debug on OR off      
         , @n_retain_days                 int      -- days to hold data      
         , @d_podate                      datetime -- shipord date FROM po header table      
         , @d_result                      datetime -- date po_date - (getdate() - noofdaystoretain      
         , @c_datetype                    NVARCHAR(10) -- 1=shiporddate, 2=editdate, 3=adddate      
         , @n_archive_ship_records        int      -- # of order records to be archived      
         , @n_archive_ship_detail_records int      -- # of order_detail records to be archived      
         , @n_archive_pick_detail_records int      -- # of PickDetail records to archived      
         , @n_archive_load_records        int      -- # of loadplan records to be archived      
         , @n_archive_load_detail_records int      -- # of loadplandetail records to be archived      
         , @n_archive_mbol_records        int      -- # of MBOL records to be archived      
         , @n_archive_mbol_detail_records int -- # of MBOLDetail records to be archived      
         , @n_archive_carton_track_records   int =0-- khlim01      
         , @n_archivePickingVoice_records   int =0-- tlting02      
         , @n_default_id                  int      
         , @n_strlen                      int      
         , @local_n_err                   int      
         , @local_c_errmsg                NVARCHAR(254)      
      
   DECLARE @c_copyfrom_db                 NVARCHAR(55)      
         , @c_copyto_db                   NVARCHAR(55)      
         , @c_shipactive                  NVARCHAR(2)      
         , @c_shipstorerkeystart          NVARCHAR(15)      
         , @c_shipstorerkeyend            NVARCHAR(15)      
         , @c_shipsysordstart             NVARCHAR(10)      
         , @c_shipsysordend               NVARCHAR(10)      
         , @c_shipyourordstart            NVARCHAR(30)      
         , @c_shipyourordend              NVARCHAR(30)      
         , @c_shipordtypstart             NVARCHAR(10)      
         , @c_shipordtypend               NVARCHAR(10)      
         , @c_shipordgrpstart             NVARCHAR(20)      
         , @c_shipordgrpend               NVARCHAR(20)      
         , @c_shiptostart                 NVARCHAR(15)      
         , @c_shiptoend                   NVARCHAR(15)      
         , @c_shipbilltostart             NVARCHAR(15)      
         , @c_shipbilltoend               NVARCHAR(15)      
         , @c_def_shipstorerkeystart      NVARCHAR(254)      
         , @c_def_shipstorerkeyend        NVARCHAR(254)      
         , @c_def_shipsysordstart         NVARCHAR(254)      
         , @c_def_shipsysordend           NVARCHAR(254)      
         , @c_def_shipyourordstart        NVARCHAR(254)      
         , @c_def_shipyourordend          NVARCHAR(254)      
         , @c_def_shipordtypstart         NVARCHAR(254)      
         , @c_def_shipordtypend           NVARCHAR(254)      
         , @c_def_shipordgrpstart         NVARCHAR(254)      
         , @c_def_shipordgrpend           NVARCHAR(254)      
         , @c_def_shiptostart             NVARCHAR(254)      
         , @c_def_shiptoend               NVARCHAR(254)      
         , @c_def_shipbilltostart         NVARCHAR(254)      
         , @c_def_shipbilltoend           NVARCHAR(254)      
         , @c_WhereClause                 NVARCHAR(2048)      
         , @c_temp                        NVARCHAR(2048)      
         , @c_temp1                       NVARCHAR(2048)      
         , @CopyRowsToArchiveDatabase     NVARCHAR(1)      
         , @cOrderKey                     NVARCHAR(10)      
         , @cOrderLineNumber              NVARCHAR(5)      
         , @cMBOLKey                      NVARCHAR(10)      
         , @cLoadKey                      NVARCHAR(10)      
         , @cPrevLoadKey                  NVARCHAR(10)      
         , @cPrevWaveKey                  NVARCHAR(10)      
         , @cPickDetailKey                NVARCHAR(10)      
         , @cMBOLLineNumber               NVARCHAR(5)      
         , @cWaveDetailKey                NVARCHAR(10)      
         , @cLoadLineNumber               NVARCHAR(5)      
      
  DECLARE  @n_DelayArchiveCT_Exist        INT = 0        --kocy01          
         , @c_StorerKey                   NVARCHAR(15) =''  --kocy01      
         , @c_PrevStorerKey               NVARCHAR(15) =''  --kocy01      
         , @nPickingVoiceKey              INT      
      
   SELECT @n_starttcnt=@@trancount , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='',      
          @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '      
      
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN -- 3      
           
      
      SELECT @c_copyfrom_db             = livedatabasename,      
             @c_copyto_db               = archivedatabasename,      
             @n_retain_days             = shipnumberofdaystoretain,      
             @c_datetype                = shipmentorderdatetype,      
             @c_shipactive              = shipactive,      
             @c_shipstorerkeystart      = ISNULL(shipstorerkeystart,''),      
             @c_shipstorerkeyend        = ISNULL(shipstorerkeyend,'ZZZZZZZZZZ'),      
             @c_shipsysordstart         = ISNULL(shipsysordstart,''),      
             @c_shipsysordend           = ISNULL(shipsysordend,'ZZZZZZZZZZ'),      
             @c_shipyourordstart        = ISNULL(shipexternorderkeystart,''),      
             @c_shipyourordend          = ISNULL(shipexternorderkeyend,'ZZZZZZZZZZ'),      
             @c_shipordtypstart         = ISNULL(shipordtypstart,''),      
             @c_shipordtypend           = ISNULL(shipordtypend,'ZZZZZZZZZZ'),      
             @c_shipordgrpstart         = ISNULL(shipordgrpstart,''),      
             @c_shipordgrpend           = ISNULL(shipordgrpend,'ZZZZZZZZZZ'),      
             @c_shiptostart             = ISNULL(shiptostart,''),      
             @c_shiptoend               = ISNULL(shiptoend,'ZZZZZZZZZZ'),      
             @c_shipbilltostart         = ISNULL(shipbilltostart,''),      
             @c_shipbilltoend           = ISNULL(shipbilltoend,'ZZZZZZZZZZ'),      
             @CopyRowsToArchiveDatabase = copyrowstoarchivedatabase      
      FROM ArchiveParameters (nolock)      
      WHERE ArchiveKey = @c_archivekey      
      
      IF db_id(@c_copyto_db) IS NULL      
      BEGIN      
         SELECT @n_continue = 3      
         SELECT @local_n_err = 77301      
         SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
         SELECT @local_c_errmsg =      
            ': target database ' + @c_copyto_db + ' does NOT exist ' + ' ( ' +      
            ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')' + ' (nspArchiveShippingOrder)'      
      END      
      
      SELECT @d_result = dateadd(day,-@n_retain_days,getdate())      
      SELECT @d_result = dateadd(day,1,@d_result)      
      
      SELECT @b_success = 1      
      SELECT @c_temp = 'archive of shipment Orders started with parms; datetype = ' + dbo.fnc_RTrim(@c_datetype) +      
         ' ; active = '+ dbo.fnc_RTrim(@c_shipactive)+ ' ; storer = '+ dbo.fnc_RTrim(@c_shipstorerkeystart)+'-'+ dbo.fnc_RTrim(@c_shipstorerkeyend) +      
         ' ; system order = '+dbo.fnc_RTrim(@c_shipsysordstart)+'-'+dbo.fnc_RTrim(@c_shipsysordend)+      
         ' ; your order = '+dbo.fnc_RTrim(@c_shipyourordstart)+'-'+dbo.fnc_RTrim(@c_shipyourordend)+      
         ' ; order Type = '+dbo.fnc_RTrim(@c_shipordtypstart)+'-'+dbo.fnc_RTrim(@c_shipordtypend)+      
         ' ; order grp = '+dbo.fnc_RTrim(@c_shipordgrpstart)+'-'+dbo.fnc_RTrim(@c_shipordgrpend)+      
         ' ; ship to = '+dbo.fnc_RTrim(@c_shiptostart)+'-'+dbo.fnc_RTrim(@c_shiptoend)+      
         ' ; bill to = '+dbo.fnc_RTrim(@c_shipbilltostart)+'-'+dbo.fnc_RTrim(@c_shipbilltoend)+      
         ' ; copy rows to archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) +      
         ' ; retain days = '+ convert(char(6),@n_retain_days)      
      
      EXECUTE dbo.nspLogAlert      
               @c_modulename   = 'nspArchiveShippingOrder',      
               @c_alertmessage = @c_temp ,      
               @n_severity     = 0,      
               @b_success      = @b_success OUTPUT,      
               @n_err          = @n_err OUTPUT,      
               @c_errmsg       = @c_errmsg OUTPUT      
      IF NOT @b_success = 1      
      BEGIN      
         SELECT @n_continue = 3      
      END      
   END -- 3      
      
   IF (@n_continue = 1 OR @n_continue = 2)      
   BEGIN -- 4      
      
      SELECT @c_WhereClause = ' '      
      SELECT @c_temp = ' '      
      SELECT @c_temp1 = ' '      
      
      SELECT @c_temp = 'AND Orders.storerkey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_shipstorerkeystart) + '''' + ' AND '+      
         'N''' + dbo.fnc_RTrim(@c_shipstorerkeyend)+ ''''      
      
      SELECT @c_temp = @c_temp + ' AND Orders.OrderKey BETWEEN ' + 'N''' + dbo.fnc_RTrim(@c_shipsysordstart) + '''' + ' AND '+      
         'N''' + dbo.fnc_RTrim(@c_shipsysordend)+ ''''      
      
      SELECT @c_temp = @c_temp + ' AND Orders.externorderkey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_shipyourordstart) + '''' +' AND '+      
         'N'''+dbo.fnc_RTrim(@c_shipyourordend)+''''      
      
   --   SELECT @c_temp = @c_temp + ' AND Orders.Type BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_shipordtypstart) + '''' +' AND '+      
   --      'N'''+dbo.fnc_RTrim(@c_shipordtypend)+''''      
      
      SELECT @c_temp1 =  ' AND Orders.OrderGroup  BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_shipordgrpstart) + '''' +' AND '+      
         'N'''+dbo.fnc_RTrim(@c_shipordgrpend)+''''      
      
     SELECT @c_temp1 = @c_temp1 + ' AND Orders.ConsigneeKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_shiptostart) + '''' +' AND '+      
         'N'''+dbo.fnc_RTrim(@c_shiptoend)+''''      
      
      SELECT @c_temp1 = @c_temp1 + ' AND Orders.BillToKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_shipbilltostart) + '''' +' AND '+      
         'N'''+dbo.fnc_RTrim(@c_shipbilltoend)+''''      
      
      IF @b_debug = 1      
      BEGIN      
         PRINT 'subsetting clauses'      
         SELECT 'EXECUTE clause @c_WhereClause', @c_WhereClause      
         SELECT 'EXECUTE clause @c_temp ', @c_temp      
         SELECT 'EXECUTE clause @c_temp1 ', @c_temp1      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'starting table existence check for Orders...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_build_archive_table      
               @c_copyfrom_db,      
               @c_copyto_db,      
               'Orders',      
               @b_success OUTPUT,      
               @n_err     OUTPUT,      
               @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'starting table existence check for OrderDetailRef...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_build_archive_table      
            @c_copyfrom_db,      
            @c_copyto_db,      
            'OrderDetailRef',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'starting table existence check for OrderInfo...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_build_archive_table      
            @c_copyfrom_db,      
            @c_copyto_db,      
            'OrderInfo',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'starting table existence check for OrderDetail...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_build_archive_table      
            @c_copyfrom_db,      
            @c_copyto_db,      
            'OrderDetail',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF @b_debug = 1      
      BEGIN      
         PRINT 'starting table existence check for PickDetail...'      
         SELECT @n_continue , 'value of n_continue after OrderDetail creation'      
         SELECT @c_errmsg      
         SELECT 'b_sucess',@b_success, 'n_err', @n_err      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         SELECT @b_success = 1      
         EXEC dbo.nsp_build_archive_table      
            @c_copyfrom_db,      
            @c_copyto_db,      
            'PickDetail',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            IF @b_debug = 1      
            BEGIN      
               PRINT 'after IF error for table existence check for PickDetail...'      
               SELECT * FROM PickDetail      
            END      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'starting table existence check for MBOL...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_build_archive_table      
            @c_copyfrom_db,      
            @c_copyto_db,      
            'MBOL',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END   
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'starting table existence check for MBOLDetail...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_build_archive_table      
            @c_copyfrom_db,      
            @c_copyto_db,      
            'MBOLDetail',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      -- Start : June01      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'starting table existence check for RefKeyLookup...'      
         END      
         SELECT @b_success = 1      
         EXEC nsp_build_archive_table      
            @c_copyfrom_db,      
            @c_copyto_db,      
            'RefKeyLookup',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      -- END : June01      
      if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')        
      begin          
         if (@b_debug =1 )        
         begin        
            print 'starting table existence check for CartonTrack...'        
         end        
         select @b_success = 1        
         exec nsp_build_archive_table         
            @c_copyfrom_db,         
            @c_copyto_db,         
            'CartonTrack',        
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
            print 'starting table existence check for PickingVoice...'        
         end        
         select @b_success = 1        
         exec nsp_build_archive_table         
            @c_copyfrom_db,         
            @c_copyto_db,         
            'PickingVoice',        
            @b_success output ,         
            @n_err output,         
            @c_errmsg output        
         if not @b_success = 1        
         begin        
            select @n_continue = 3        
         end        
      end       
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building alter table string for Orders...'      
         END      
         EXECUTE dbo.nspBuildAlterTableString      
            @c_copyto_db,      
            'Orders',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building alter table string for OrderDetail...'      
         END      
         EXECUTE dbo.nspBuildAlterTableString      
            @c_copyto_db,      
            'OrderDetail',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building alter table string for OrderDetailRef...'      
         END      
         EXECUTE dbo.nspBuildAlterTableString      
            @c_copyto_db,      
            'OrderDetailRef',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building alter table string for OrderInfo...'      
         END      
         EXECUTE dbo.nspBuildAlterTableString      
            @c_copyto_db,      
            'OrderInfo',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building alter table string for PickDetail...'      
         END      
         EXECUTE dbo.nspBuildAlterTableString      
            @c_copyto_db,      
            'PickDetail',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      -- Start : June01      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building alter table string for RefKeyLookup...'      
         END      
         EXECUTE dbo.nspbuildaltertablestring      
            @c_copyto_db,      
            'RefKeyLookup',      
            @b_success OUTPUT,      
            @n_err     OUTPUT,      
            @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      -- END : June01      
      IF ((@n_continue=1 OR @n_continue=2)      
         AND @copyrowstoarchivedatabase='y')      
      BEGIN      
          IF (@b_debug=1)      
          BEGIN      
              PRINT 'building alter table string for CartonTrack...'      
          END      
             
          EXECUTE nspbuildaltertablestring       
          @c_copyto_db,       
          'CartonTrack',       
          @b_success OUTPUT,       
          @n_err OUTPUT,       
          @c_errmsg OUTPUT       
          IF NOT @b_success=1      
          BEGIN      
              SELECT @n_continue = 3      
          END      
      END       
      IF ((@n_continue=1 OR @n_continue=2)      
         AND @copyrowstoarchivedatabase='y')      
      BEGIN      
          IF (@b_debug=1)      
          BEGIN      
              PRINT 'building alter table string for PickingVoice...'      
          END      
             
          EXECUTE nspbuildaltertablestring       
          @c_copyto_db,       
          'PickingVoice',       
          @b_success OUTPUT,       
          @n_err OUTPUT,       
          @c_errmsg OUTPUT       
          IF NOT @b_success=1      
          BEGIN      
              SELECT @n_continue = 3      
          END      
      END       
      
      -- DECLARE Cursor      
      IF @c_datetype = '1' -- ordersdate      
      BEGIN      
         SELECT @c_WhereClause = ' WHERE ( Orders.orderdate  <= '      
                  + ''''+ convert(char(8),@d_result,112)+''''      
                  -- + ''''+ convert(char(11),@d_result,106)+'''' -- KHLim01      
                  -- + ' AND ( Orders.status = ''9'' OR Orders.status = ''CANC'' OR Orders.archivecop = ''9'' )) ' -- SOS#116967      
                  -- + ' AND ( Orders.status = ''9'' OR Orders.status = ''CANC'' OR Orders.sostatus = ''CANC'' OR Orders.archivecop = ''9'' )) ' -- SOS#116967      
                  + ' AND ( (Orders.status = ''9'' OR Orders.status = ''CANC'' OR Orders.sostatus = ''CANC'') OR (Orders.status <> ''9'' AND Orders.sostatus = ''9'') OR Orders.archivecop = ''9'' ) ) '-- SOS#128677, SOS#171555      
         SET @c_WhereClause = (dbo.fnc_RTrim(@c_WhereClause) + dbo.fnc_RTrim(@c_temp) + dbo.fnc_RTrim(@c_temp1))      
      END      
      
      IF @c_datetype = '2' -- editdate      
      BEGIN      
         SELECT @c_WhereClause = ' WHERE ( Orders.editdate <= '      
               + ''''+ convert(char(8),@d_result,112)+''''      
               -- + ''''+ convert(char(11),@d_result,106)+'''' -- KHLim01      
               -- + ' AND ( Orders.status = ''9'' OR Orders.status = ''CANC'' OR Orders.archivecop = ''9'' )) ' -- SOS#116967      
               -- + ' AND ( Orders.status = ''9'' OR Orders.status = ''CANC'' OR Orders.sostatus = ''CANC'' OR Orders.archivecop = ''9'' )) ' -- SOS#116967      
               + ' AND ( (Orders.status = ''9'' OR Orders.status = ''CANC'' OR Orders.sostatus = ''CANC'') OR (Orders.status <> ''9'' AND Orders.sostatus = ''9'') OR Orders.archivecop = ''9'' ) ) '-- SOS#128677, SOS#171555      
         SET @c_WhereClause = (dbo.fnc_RTrim(@c_WhereClause) + dbo.fnc_RTrim(@c_temp) + dbo.fnc_RTrim(@c_temp1))      
      END      
      
      IF @c_datetype = '3' -- adddate      
      BEGIN      
         SELECT @c_WhereClause = ' WHERE ( Orders.adddate <= '      
                        +''''+ convert(char(8),@d_result,112)+''''      
                        -- +''''+ convert(char(11),@d_result,106)+'''' -- KHLim01      
                        -- + ' AND ( Orders.status = ''9'' OR Orders.status = ''CANC'' OR Orders.archivecop = ''9''  ) ) ' -- SOS#116967      
                        -- + ' AND ( Orders.status = ''9'' OR Orders.status = ''CANC'' OR Orders.sostatus = ''CANC'' OR Orders.archivecop = ''9''  ) ) ' -- SOS#116967      
                        + ' AND ( (Orders.status = ''9'' OR Orders.status = ''CANC'' OR Orders.sostatus = ''CANC'') OR (Orders.status <> ''9'' AND Orders.sostatus = ''9'') OR Orders.archivecop = ''9'' ) ) '-- SOS#128677, SOS#171555      
         SET @c_WhereClause = (dbo.fnc_RTrim(@c_WhereClause) + dbo.fnc_RTrim(@c_temp) + dbo.fnc_RTrim(@c_temp1))      
      END      
      
      SET @c_WhereClause = @c_WhereClause + ' AND NOT EXISTS (SELECT 1      
                                                             FROM PICKDETAIL  AS pd with (nolock)      
                                                             JOIN ORDERDETAIL AS od with (nolock)      
                                                             ON   pd.OrderKey        = od.OrderKey      
                                                             AND  pd.OrderLineNumber = od.OrderLineNumber      
                                                             AND  pd.Status          <> ''9''      
                                                             WHERE od.OrderKey   = ORDERS.OrderKey) '            --KH02      
      
      SET @n_archive_ship_records = 0      
      SET @n_archive_ship_detail_records = 0      
      SET @n_archive_pick_detail_records = 0      
      
      DECLARE @nStartTranCount int      
      SET @nStartTranCount = @@TRANCOUNT      
      
      WHILE @@TRANCOUNT > 0      
         COMMIT TRAN      
    
      EXEC (      
      ' DECLARE C_Orderkey CURSOR FAST_FORWARD READ_ONLY FOR ' +      
      ' SELECT OrderKey, StorerKey FROM Orders (NOLOCK) ' + @c_WhereClause +  --kocy01 add StorerKey      
      ' ORDER BY StorerKey, OrderKey ' )      
          
      OPEN C_Orderkey      
      
      FETCH NEXT FROM C_Orderkey INTO @cOrderKey,  @c_StorerKey    -- kocy01 add @cStorerKey      
      
      WHILE @@fetch_status <> -1      
      BEGIN      
       
         IF(@n_continue= 1 OR @n_continue =2)                      
         BEGIN                 
            IF @c_StorerKey <> @c_PrevStorerKey      
            BEGIN        
               SET @c_PrevStorerKey = @c_StorerKey       
               SELECT @n_DelayArchiveCT_Exist = 0      
               SELECT @b_success = 1      
               EXECUTE nspGetRight         
                  NULL,          -- facility        
                  @c_StorerKey, -- StorerKey        
                  NULL,          -- Sku        
                  'DelayArchiveCT', -- Configkey for CartonTrack delay archive       
                  @b_Success OUTPUT,       
                  @n_DelayArchiveCT_Exist OUTPUT,     -- this is return result      
                  @n_err OUTPUT,        
                  @c_errmsg OUTPUT      
          
               IF (@n_err <> 0)      
               BEGIN      
                  SELECT @n_continue = 3      
                  SELECT @c_errmsg = N' FAIL Retrieved.  ConfigKey ''DelayArchive'' for storerkey ''' +@c_StorerKey      
                                    +'''.  Refer StorerConfig Table'      
               END         
               IF (@b_debug=1)      
               BEGIN      
                  PRINT 'Storerkey...' + @c_StorerKey + ' , DelayArchiveCT -' + Cast(@n_DelayArchiveCT_Exist as nvarchar)      
               END      
            END--END @c_StorerKey <> @c_PrevStorerKey       
         END        
      
         DECLARE C_OrderLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT MBOLKey, LoadKey, OrderLineNumber      
         FROM   OrderDetail (NOLOCK)      
         WHERE  OrderKey = @cOrderKey      
         ORDER By MBOLKey, LoadKey, OrderLineNumber      
      
         OPEN C_OrderLine      
      
         SET @cMBOLKey = ''      
         SET @cLoadKey = ''      
      
         FETCH NEXT FROM C_OrderLine INTO @cMBOLKey, @cLoadKey, @cOrderLineNumber      
      
         WHILE @@fetch_status <> -1      
         BEGIN      
            BEGIN TRAN      
                   
            UPDATE OrderDetail WITH (ROWLOCK)      
               SET Archivecop = '9'      
            WHERE OrderKey = @cOrderKey AND OrderLineNumber = @cOrderLineNumber      
      
            SELECT @local_n_err = @@error      
            IF @local_n_err <> 0      
            BEGIN      
               SELECT @n_continue = 3      
               SELECT @local_n_err = 77303      
               SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
               SELECT @local_c_errmsg =      
               ': UPDATE of archivecop failed - OrderDetail. (nspArchiveShippingOrder) ' + ' ( ' +      
               ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
               ROLLBACK TRAN      
            END      
            ELSE      
            BEGIN      
               COMMIT TRAN      
            END      
      
            IF EXISTS ( SELECT 1 FROM OrderDetailRef WITH (NOLOCK)      
                     WHERE OrderKey = @cOrderKey AND OrderLineNumber = @cOrderLineNumber )      
            BEGIN      
               BEGIN TRAN      
      
               UPDATE OrderDetailRef WITH (ROWLOCK)      
                  SET Archivecop = '9'      
               WHERE OrderKey = @cOrderKey AND OrderLineNumber = @cOrderLineNumber      
      
               SELECT @local_n_err = @@error      
               IF @local_n_err <> 0      
               BEGIN      
                  SELECT @n_continue = 3      
                  SELECT @local_n_err = 77305      
                  SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
                  SELECT @local_c_errmsg =      
                  ': UPDATE of archivecop failed - OrderDetailRef. (nspArchiveShippingOrder) ' + ' ( ' +      
                  ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
                  ROLLBACK TRAN      
               END      
               ELSE      
               BEGIN      
                  COMMIT TRAN      
               END      
            END      
      
            IF EXISTS ( SELECT 1 FROM Preallocatepickdetail WITH (NOLOCK)      
                  WHERE OrderKey = @cOrderKey AND OrderLineNumber = @cOrderLineNumber      
                  AND NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP CL (NOLOCK)      
                                    WHERE CL.LISTNAME = 'ITXPREPICK' AND  CL.Storerkey = Preallocatepickdetail.Storerkey )  )      
            BEGIN      
               BEGIN TRAN      
      
               DELETE FROM  Preallocatepickdetail      
               WHERE OrderKey = @cOrderKey AND OrderLineNumber = @cOrderLineNumber      
      
               SELECT @local_n_err = @@error      
               IF @local_n_err <> 0      
               BEGIN      
                  SELECT @n_continue = 3      
                  SELECT @local_n_err = 77335      
                  SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
                  SELECT @local_c_errmsg =      
                  ': DELETE failed - Preallocatepickdetail. (nspArchiveShippingOrder) ' + ' ( ' +      
                  ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
                  ROLLBACK TRAN      
               END      
               ELSE      
               BEGIN      
                  COMMIT TRAN      
               END      
            END      
      
            IF @@ERROR = 0      
    BEGIN      
               SET @n_archive_ship_detail_records = @n_archive_ship_detail_records + 1      
      
               DECLARE C_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
               SELECT PickDetailKey      
               FROM   PickDetail (NOLOCK)      
               WHERE  OrderKey = @cOrderKey AND OrderLineNumber = @cOrderLineNumber      
               AND    Status = '9'      
      
               OPEN C_PickDetailKey      
      
               FETCH NEXT FROM C_PickDetailKey INTO @cPickDetailKey      
      
               WHILE @@fetch_status <> -1      
               BEGIN      
                  BEGIN TRAN      
      
                  UPDATE PickDetail with (rowlock)      
                     SET PickDetail.archivecop = '9'      
                  WHERE PickDetailKey = @cPickDetailKey      
                  SELECT @local_n_err = @@error      
                  IF @local_n_err <> 0      
                  BEGIN      
                     SELECT @n_continue = 3      
                     SELECT @local_n_err = 77303      
                     SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
                     SELECT @local_c_errmsg =      
                     ': UPDATE of archivecop failed - PickDetail. (nspArchiveShippingOrder) ' + ' ( ' +      
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
                     ROLLBACK TRAN      
                  END      
                  ELSE      
                  BEGIN      
                     COMMIT TRAN      
                  END      
      
                  -- Start : June01      
                  -- SET @n_archive_pick_detail_records = @n_archive_pick_detail_records + 1      
                  IF @@ERROR = 0      
                  BEGIN      
                     SET @n_archive_pick_detail_records = @n_archive_pick_detail_records + 1      
      
                     IF EXISTS (SELECT 1 FROM REFKEYLOOKUP (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)      
                     BEGIN      
                        BEGIN TRAN      
      
                        UPDATE refkeylookup with (rowlock)      
                           SET ArchiveCop = '9'      
                        WHERE PickDetailKey = @cPickDetailKey      
                        SELECT @local_n_err = @@error      
                        IF @local_n_err <> 0      
                        BEGIN      
                           SELECT @n_continue = 3      
                           SELECT @local_n_err = 77303      
                           SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
                           SELECT @local_c_errmsg =      
                           ': UPDATE of archivecop failed - refkeylookup. (nspArchiveShippingOrder) ' + ' ( ' +      
                           ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
                           ROLLBACK TRAN      
                        END      
                        ELSE      
                        BEGIN      
                           COMMIT TRAN      
                        END      
                     END      
                  END      
                  -- END : June01      
      
                  --TLTING02      
                  IF @@ERROR = 0      
                  BEGIN      
                     SET @n_archivePickingVoice_records = @n_archivePickingVoice_records + 1      
      
                     IF EXISTS (SELECT 1 FROM PickingVoice (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)      
                     BEGIN      
                        BEGIN TRAN      
      
                        UPDATE PickingVoice with (rowlock)      
                           SET ArchiveCop = '9'      
                        WHERE PickDetailKey = @cPickDetailKey      
                        SELECT @local_n_err = @@error      
                        IF @local_n_err <> 0      
                        BEGIN      
              SELECT @n_continue = 3      
                           SELECT @local_n_err = 77363      
                           SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
         SELECT @local_c_errmsg =      
                           ': UPDATE of archivecop failed - PickingVoice. (nspArchiveShippingOrder) ' + ' ( ' +      
                           ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
                           ROLLBACK TRAN      
                        END      
                        ELSE      
                        BEGIN      
                           COMMIT TRAN      
                        END      
                     END      
                  END      
                  FETCH NEXT FROM C_PickDetailKey INTO @cPickDetailKey      
               END -- While PickDetailKey      
               CLOSE C_PickDetailKey      
               DEALLOCATE C_PickDetailKey      
            END      
      
            FETCH NEXT FROM C_OrderLine INTO @cMBOLKey, @cLoadKey, @cOrderLineNumber      
         END -- While Order Line      
         CLOSE C_OrderLine      
         DEALLOCATE C_OrderLine      
      
      
         -- TLTING01      
         IF EXISTS (SELECT 1 FROM Orders_PI_Encrypted WITH (NOLOCK) WHERE OrderKey = @cOrderKey )      
         BEGIN      
            BEGIN TRAN      
      
            UPDATE Orders_PI_Encrypted WITH (ROWLOCK)      
               SET ArchiveCop = '9'      
            WHERE OrderKey = @cOrderKey      
      
            SELECT @local_n_err = @@error, @n_cnt = @@rowcount      
            IF @local_n_err <> 0      
            BEGIN      
               SELECT @n_continue = 3      
               SELECT @local_n_err = 77303      
               SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
               SELECT @local_c_errmsg =      
               ': UPDATE of archivecop failed - Orders. (Orders_PI_Encrypted) ' + ' ( ' +      
               ' sqlsvr message = ' + Trim(@local_c_errmsg) + ')'      
               ROLLBACK TRAN      
            END      
            ELSE      
            BEGIN      
               COMMIT TRAN      
            END      
         END      
      
         BEGIN TRAN      
      
         UPDATE Orders WITH (ROWLOCK)      
            SET ArchiveCop = '9'      
         WHERE OrderKey = @cOrderKey      
      
         SELECT @local_n_err = @@error, @n_cnt = @@rowcount      
         IF @local_n_err <> 0      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @local_n_err = 77303      
            SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
            SELECT @local_c_errmsg =      
            ': UPDATE of archivecop failed - Orders. (nspArchiveShippingOrder) ' + ' ( ' +      
            ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
            ROLLBACK TRAN      
         END      
         ELSE      
         BEGIN      
            COMMIT TRAN      
         END      
      
         SELECT @n_archive_ship_records = @n_archive_ship_records + 1      
      
         BEGIN TRAN      
      
         UPDATE OrderInfo WITH (ROWLOCK)      
            SET ArchiveCop = '9'      
         WHERE OrderKey = @cOrderKey      
      
         SELECT @local_n_err = @@error, @n_cnt = @@rowcount      
         IF @local_n_err <> 0      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @local_n_err = 77393      
            SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
            SELECT @local_c_errmsg =      
            ': UPDATE of archivecop failed - OrderInfo. (nspArchiveShippingOrder) ' + ' ( ' +      
            ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
            ROLLBACK TRAN      
         END      
         ELSE      
         BEGIN      
            COMMIT TRAN      
         END      
      
         IF @n_DelayArchiveCT_Exist <> 1   -- kocy01        
         BEGIN      
            IF EXISTS ( Select 1 from CartonTrack (NOLOCK) WHERE  archivecop IS NULL AND    LabelNo<>''      
                        AND    LabelNo = @cOrderKey   )          
            BEGIN                           
               UPDATE CartonTrack WITH (ROWLOCK) -- (KHLim01)      
               SET    CartonTrack.archivecop = '9'      
               WHERE  archivecop IS NULL      
               AND    LabelNo<>''      
             AND    LabelNo = @cOrderKey      
                            
               SELECT @local_n_err = @@error      
                     ,@n_cnt = @@rowcount      
                            
               SELECT @n_archive_carton_track_records = @n_archive_carton_track_records + @n_cnt       
                            
               IF @local_n_err<>0      
               BEGIN      
                  SELECT @n_continue = 3       
                  SELECT @local_n_err = 77307       
                  SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)       
                  SELECT @local_c_errmsg =       
                        ': update of archivecop failed - CartonTrack. (nspArchiveShippingOrder) '       
                        +' ( '+      
                        ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+      
                        ')'      
               END       
            END       
         END-- END @n_DelayArchiveCT_Exist <> 1        
                 
         IF @n_continue = 3      
         BEGIN      
            IF @@TRANCOUNT > 0      
               ROLLBACK TRAN      
         END      
         ELSE      
         BEGIN      
            WHILE @@TRANCOUNT > 0      
            BEGIN      
               COMMIT TRAN      
            END      
         END      
         FETCH NEXT FROM C_Orderkey INTO @cOrderKey, @c_StorerKey     -- kocy01 add @cStorerKey      
      END -- while OrderKey      
      CLOSE C_Orderkey      
      DEALLOCATE C_Orderkey      
      
      IF ((@n_continue = 1 OR @n_continue = 2)  AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         SELECT @c_temp = 'attempting to archive ' + rtrim(convert(char(6),@n_archive_ship_records )) +      
            ' Orders records AND ' + rtrim(convert(char(6),@n_archive_ship_detail_records )) + ' OrderDetail records'      
            + ' AND ' +  rtrim(convert(char(6),@n_archive_pick_detail_records )) + ' of PickDetail records'       
            + ' AND ' + rtrim(convert(varchar(6),@n_archive_carton_track_records )) +' of cartontrack records '      
  + ' AND ' + rtrim(convert(varchar(6),@n_archivePickingVoice_records )) +' of PickingVoice records '      
      
         EXECUTE dbo.nspLogAlert      
                  @c_modulename   = 'nspArchiveShippingOrder',      
                  @c_alertmessage = @c_temp ,      
                  @n_severity     = 0,      
                  @b_success      = @b_success OUTPUT,      
                  @n_err          = @n_err OUTPUT,      
                  @c_errmsg       = @c_errmsg OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF (@n_continue = 1 OR @n_continue = 2)      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'archiving wave...'      
         END      
         SELECT @b_success = 1      
         EXECUTE dbo.isp_ArchiveWave      
                  @c_copyfrom_db,      
                  @c_copyto_db,      
                  @CopyRowsToArchiveDatabase,      
                  @b_success OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @local_n_err = 77305      
            SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
            SELECT @local_c_errmsg =      
            ': archiving of wave failed - (nspArchiveShippingOrder) ' + ' ( ' +      
            ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
         END      
      END      
      
      IF (@n_continue = 1 OR @n_continue = 2)      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'archiving load...'      
         END      
         SELECT @b_success = 1      
         EXECUTE dbo.isp_ArchiveLoad      
                  @c_copyfrom_db,      
                  @c_copyto_db,      
                  @CopyRowsToArchiveDatabase,      
                  @d_result, -- SOS#116967      
                  @b_success OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
     SELECT @local_n_err = 77305      
            SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
            SELECT @local_c_errmsg =      
            ': archiving of load failed - (nspArchiveShippingOrder) ' + ' ( ' +      
            ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
         END      
      END      
      
      IF (@n_continue = 1 OR @n_continue = 2)      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'archiving MBOL...'      
         END      
         SELECT @b_success = 1      
         EXECUTE dbo.isp_ArchiveMBOL      
                  @c_copyfrom_db,      
                  @c_copyto_db,      
                  @CopyRowsToArchiveDatabase,    
                  @n_retain_days,                  --kocy02    
                  @b_success OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @local_n_err = 77306      
            SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
            SELECT @local_c_errmsg =      
            ': archiving of MBOL failed - (nspArchiveShippingOrder) ' + ' ( ' +      
            ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
         END      
      END      
      
      --TLTING01      
      IF (@n_continue = 1 OR @n_continue = 2)      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'archiving Orders_PI_Encrypted ...'      
         END      
         SELECT @b_success = 1      
         EXECUTE dbo.isp_Archive_Order_PI_Encrypted      
                  @c_copyfrom_db,      
                  @c_copyto_db,      
                  @CopyRowsToArchiveDatabase,      
                  @b_success OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @local_n_err = 77306      
            SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
            SELECT @local_c_errmsg =      
            ': archiving of MBOL failed - (nspArchiveShippingOrder) ' + ' ( ' +      
            ' sqlsvr message = ' + TRIM(@local_c_errmsg) + ')'      
         END      
      END      
      
-- isp_ArchivePack      
-- Merge Pick and Pack archive script      
/*      
       IF (@n_continue = 1 OR @n_continue = 2)      
       BEGIN      
          IF @b_debug = 1      
          BEGIN      
             PRINT 'archiving MBOL...'      
          END      
          SELECT @b_success = 1      
            EXECUTE dbo.isp_ArchivePack      
                     @c_copyfrom_db,      
                     @c_copyto_db,      
                     @CopyRowsToArchiveDatabase,      
                     @b_success OUTPUT      
          IF NOT @b_success = 1      
          BEGIN      
             SELECT @n_continue = 3      
             SELECT @local_n_err = 77306      
             SELECT @local_c_errmsg = convert(char(5),@local_n_err)      
             SELECT @local_c_errmsg =      
             ': archiving of MBOL failed - (isp_ArchivePack) ' + ' ( ' +      
             ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'      
          END      
       END      
       */      
---      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building insert for PickDetail...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_Build_Insert      
               @c_copyto_db,      
               'PickDetail',      
               1 ,      
               @b_success OUTPUT,      
               @n_err     OUTPUT,      
               @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      -- Start : June01      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building insert for RefKeyLookup...'      
         END      
         SELECT @b_success = 1      
    EXEC nsp_build_insert      
               @c_copyto_db,      
               'RefKeyLookup',      
               1,      
               @b_success OUTPUT,      
               @n_err     OUTPUT,      
               @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      -- END : June01      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building insert for OrderDetailRef...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_Build_Insert      
               @c_copyto_db,      
               'OrderDetailRef',      
               1 ,      
               @b_success OUTPUT,      
               @n_err     OUTPUT,      
               @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building insert for OrderInfo...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_Build_Insert      
               @c_copyto_db,      
               'OrderInfo',      
               1 ,      
               @b_success OUTPUT,      
               @n_err     OUTPUT,      
               @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END     
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building insert for PickingVoice...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_Build_Insert      
               @c_copyto_db,      
               'PickingVoice',      
               1 ,      
               @b_success OUTPUT,      
               @n_err     OUTPUT,      
               @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')      
      begin         
         if (@b_debug =1 )      
         begin      
            print 'building insert for CartonTrack...'      
         end      
         select @b_success = 1      
         exec nsp_build_insert        
            @c_copyto_db,       
            'CartonTrack',      
            1,      
            @b_success output ,       
            @n_err output,       
            @c_errmsg output      
         if not @b_success = 1      
         begin      
            select @n_continue = 3      
         end      
      end      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building insert for OrderDetail...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_Build_Insert      
               @c_copyto_db,      
               'OrderDetail',      
               1 ,      
               @b_success OUTPUT,      
               @n_err     OUTPUT,      
               @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')      
      BEGIN      
         IF @b_debug = 1      
         BEGIN      
            PRINT 'building insert for order...'      
         END      
         SELECT @b_success = 1      
         EXEC dbo.nsp_Build_Insert      
               @c_copyto_db,      
               'Orders',      
               1,      
               @b_success OUTPUT,      
               @n_err     OUTPUT,      
               @c_errmsg  OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
   END -- 4      
      
   IF @n_continue = 1 OR @n_continue = 2      
   BEGIN      
      SELECT @b_success = 1      
      EXECUTE dbo.nspLogAlert      
               @c_modulename   = 'nspArchiveShippingOrder',      
               @c_alertmessage = 'archive of shipping Orders ended normally.',      
               @n_severity     = 0,      
               @b_success      = @b_success OUTPUT,      
               @n_err          = @n_err OUTPUT,      
               @c_errmsg       = @c_errmsg OUTPUT      
      IF NOT @b_success = 1      
      BEGIN      
         SELECT @n_continue = 3      
   END      
   END      
   ELSE      
   BEGIN      
      IF @n_continue = 3      
      BEGIN      
         SELECT @b_success = 1      
         EXECUTE dbo.nspLogAlert      
                  @c_modulename   = 'nspArchiveShippingOrder',      
                  @c_alertmessage = 'archive of shipping Orders ended abnormally - check this log for additional messages.',      
                  @n_severity     = 0,      
                  @b_success      = @b_success OUTPUT ,      
                  @n_err          = @n_err OUTPUT,      
                  @c_errmsg       = @c_errmsg OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
   END      
      
      
   /* #include <sparpo2.sql> */      
   IF @n_continue=3  -- error occured - process AND return      
   BEGIN      
      SELECT @b_success = 0      
      IF @@trancount > 0      
      BEGIN      
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         while @@trancount > 0      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      
      SELECT @n_err = @local_n_err      
      SELECT @c_errmsg = @local_c_errmsg      
      IF (@b_debug = 1)      
      BEGIN      
         SELECT @n_err,@c_errmsg, 'before putting in nsp_logerr at the bottom'      
      END      
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'nspArchiveShippingOrder'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_success = 1      
      while @@trancount > 0      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END      
      
END -- main      

GO