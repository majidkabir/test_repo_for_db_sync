SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_ArchivePack                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Wanyt                                                    */
/*                                                                      */
/* Purpose: Housekeep Packheader & Packdetail table                     */
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
/* Called By:    isparchiveload                                         */
/*                                                                      */
/* PVCS Version: 1.3                                                    */ 
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 15-Jun-2005  June     1.0  Register PVCS : SOS18664                  */
/* 10-Aug-2005  Ong      1.0  SOS38267 : obselete sku & storerkey       */
/* 02-Nov-2005  TLTING   1.1  SQL2005 ISNULL check (tlting01)           */
/* 17-Jul-2009  TLTING   1.2  SQL2005 ISNULL check (tlting02)           */
/* 10-Oct-2010  KHLim    1.3  SOS191295 Archiving CartonTrack table     */
/*                            (KHLim01)                                 */
/* 30-Jan-2012  Shong    1.4  Adding PickSlip Type DX,LP,LB             */
/* 09-Feb-2012  KHLim02  1.5  Remove alias to fix syntax error          */
/************************************************************************/

CREATE PROC [dbo].[isp_ArchivePack]
      @c_copyfrom_db  NVARCHAR(55),
      @c_copyto_db    NVARCHAR(55),
      @copyrowstoarchivedatabase NVARCHAR(1),
      @b_success int output    
as
/*--------------------------------------------------------------*/
/* THIS ARCHIVE SCRIPT IS EXECUTED FROM nsparchiveshippingorder */
/* 9 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters   */
/*--------------------------------------------------------------*/
begin -- main
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @n_continue int        ,  
      @n_starttcnt int        , -- holds the current transaction count
      @n_cnt int              , -- holds @@rowcount after certain operations
      @b_debug int             -- debug on or off
        
   /* #include <sparpo1.sql> */     
   declare
      @n_archive_pack_header_records   int, -- # of packheader records to be archived
      @n_archive_pack_detail_records   int, -- # of packdetail records to be archived
      @n_archive_pack_info_records int,  -- tlting01
      @n_archive_carton_track_records   int, -- khlim01
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
         print 'starting table existence check for packheader...'
      end
      select @b_success = 1
      exec nsp_build_archive_table 
         @c_copyfrom_db, 
         @c_copyto_db, 
         'packheader',
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
         print 'starting table existence check for packdetail...'
      end
      select @b_success = 1
      exec nsp_build_archive_table 
         @c_copyfrom_db, 
         @c_copyto_db, 
         'packdetail',
         @b_success output , 
         @n_err output, 
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end

 -- KHLim01
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

 -- tlting01
   IF ((@n_continue=1 OR @n_continue=2)   AND 
        @copyrowstoarchivedatabase='y'
      )
   BEGIN
       IF (@b_debug=1)
       BEGIN
           PRINT 'starting table existence check for packinfo...'
       END
       
       SELECT @b_success = 1   
       EXEC nsp_build_archive_table 
            @c_copyfrom_db
           ,@c_copyto_db
           ,'packinfo'
           ,@b_success OUTPUT
           ,@n_err OUTPUT
           ,@c_errmsg OUTPUT
       
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
           PRINT 'building alter table string for packheader...'
       END
       
       EXECUTE nspbuildaltertablestring 
       @c_copyto_db, 
       'packheader', 
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
           PRINT 'building alter table string for packdetail...'
       END
       
       EXECUTE nspbuildaltertablestring 
       @c_copyto_db, 
       'packdetail', 
       @b_success OUTPUT, 
       @n_err OUTPUT, 
       @c_errmsg OUTPUT 
       IF NOT @b_success=1
       BEGIN
           SELECT @n_continue = 3
       END
   END 
 
   -- KHLim01 
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
 
   -- tlting01 
   IF ((@n_continue=1 OR @n_continue=2)
      AND @copyrowstoarchivedatabase='y')
   BEGIN
       IF (@b_debug=1)
       BEGIN
           PRINT 'building alter table string for packinfo...'
       END
       
       EXECUTE nspbuildaltertablestring 
       @c_copyto_db, 
       'packinfo', 
       @b_success OUTPUT, 
       @n_err OUTPUT, 
       @c_errmsg OUTPUT 
       IF NOT @b_success=1
       BEGIN
           SELECT @n_continue = 3
       END
   END

   DECLARE @cPickSlipNo NVARCHAR(10)
          ,@nCartonNo INT
          ,@cLabelNo NVARCHAR(20)
          ,@cLabelLine NVARCHAR(5) 
       
   IF (@n_continue=1 OR @n_continue=2)
   BEGIN
       SELECT @n_archive_pack_header_records = 0 
       SELECT @n_archive_pack_detail_records = 0  
       
       SELECT p.PickSlipNo 
         INTO #temp1 
       FROM   PACKHEADER p (NOLOCK)  
       JOIN ORDERS O (NOLOCK) ON p.OrderKey = O.OrderKey 
       JOIN PICKHEADER PH (NOLOCK) ON P.PickSlipNo = PH.PickHeaderKey
       WHERE O.ArchiveCop = '9'
       AND  PH.Zone NOT IN ('XD','LB','LP')

       INSERT INTO #temp1 (PickSlipNo)
       SELECT DISTINCT P.PickSlipNo
       FROM   PACKHEADER P (NOLOCK) 
       JOIN   PICKHEADER PH (NOLOCK) ON P.PickSlipNo = PH.PickHeaderKey  
       JOIN LOADPLAN L (NOLOCK) ON P.LoadKey = L.LoadKey  
       WHERE (P.OrderKey = '' OR P.OrderKey IS NULL)  
         AND  L.ArchiveCop = '9' 
         AND  PH.Zone NOT IN ('XD','LB','LP')
       
       INSERT INTO #temp1 (PickSlipNo)
       SELECT DISTINCT P.PickSlipNo 
       FROM   PACKHEADER P (NOLOCK) 
       JOIN   PICKHEADER PH (NOLOCK) ON P.PickSlipNo = PH.PickHeaderKey   
       JOIN   (SELECT DISTINCT R.PickSlipNo, R.OrderKey 
               FROM RefKeyLookUp R WITH (NOLOCK) 
               JOIN ORDERS OD WITH (NOLOCK) ON OD.OrderKey = R.OrderKey AND OD.ArchiveCop = '9') AS O
               ON O.PickSlipNo = P.PickSlipNo   
       WHERE  PH.Zone IN ('XD','LB','LP')
       
       DECLARE c_arc_packheader CURSOR LOCAL FAST_FORWARD READ_ONLY 
       FOR
           SELECT PickSlipNo   -- KHLim02
           FROM   #temp1 t

       OPEN c_arc_packheader 
       
       FETCH NEXT FROM c_arc_packheader INTO @cPickSlipNo 
       
       WHILE @@fetch_status<>-1 AND (@n_continue=1 OR @n_continue=2)
       BEGIN
           UPDATE packheader WITH (ROWLOCK) -- 10-Aug-2005 (SOS38267)
           SET    packheader.archivecop = '9'
           WHERE  PickSlipNo = @cPickSlipNo  
           
           SELECT @local_n_err = @@error
                 ,@n_cnt = @@rowcount
           
           SELECT @n_archive_pack_header_records = @n_archive_pack_header_records+1 
           IF @local_n_err<>0
           BEGIN
               SELECT @n_continue = 3 
               SELECT @local_n_err = 77301 
               SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err) 
               SELECT @local_c_errmsg = 
                      ': update of archivecop failed - packheader. (isp_ArchivePack) ' 
                     +' ( '+
                      ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+')'
           END
           
           IF @n_continue=1
           OR @n_continue=2
           BEGIN
               DECLARE c_arc_packdetail CURSOR LOCAL FAST_FORWARD READ_ONLY 
               FOR
                   SELECT CartonNo
                         ,LabelNo
                         ,LabelLine
                   FROM   packdetail(NOLOCK)
                   WHERE  PickSlipNo = @cPickSlipNo 
               
               OPEN c_arc_packdetail 
               
               FETCH NEXT FROM c_arc_packdetail INTO @nCartonNo, @cLabelNo, @cLabelLine 
               
               WHILE @@fetch_status<>-1
               AND   (@n_continue=1 OR @n_continue=2)
               BEGIN
                   UPDATE packdetail WITH (ROWLOCK) -- 10-Aug-2005 (SOS38267)
                   SET    packdetail.archivecop = '9'
                   WHERE  pickslipno = @cPickSlipNo
                   AND    CartonNo = @nCartonNo
                   AND    LabelNo = @cLabelNo
                   AND    LabelLine = @cLabelLine
                   
                   SELECT @local_n_err = @@error
                         ,@n_cnt = @@rowcount
                   
                   SELECT @n_archive_pack_detail_records = @n_archive_pack_detail_records 
                         +1
                   
                   IF @local_n_err<>0
                   BEGIN
                       SELECT @n_continue = 3 
                       SELECT @local_n_err = 77303 
                       SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err) 
                       SELECT @local_c_errmsg = 
                              ': update of archivecop failed - packdetail. (isp_ArchivePack) ' 
                             +' ( '+
                              ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+
                              ')'
                   END   
                   
                   UPDATE CartonTrack WITH (ROWLOCK) -- (KHLim01)
                   SET    CartonTrack.archivecop = '9'
                   WHERE  archivecop IS NULL
                   AND    LabelNo<>''
                   AND    LabelNo = @cLabelNo
                   
                   SELECT @local_n_err = @@error
                         ,@n_cnt = @@rowcount
                   
                   SELECT @n_archive_carton_track_records = @n_archive_carton_track_records 
                         +1
                   
                   IF @local_n_err<>0
                   BEGIN
                       SELECT @n_continue = 3 
                       SELECT @local_n_err = 77303 
                       SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err) 
                       SELECT @local_c_errmsg = 
                              ': update of archivecop failed - CartonTrack. (isp_ArchivePack) ' 
                             +' ( '+
                              ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+
                              ')'
                   END 
                   
                   FETCH NEXT FROM c_arc_packdetail INTO @nCartonNo, @cLabelNo, @cLabelLine
               END 
               CLOSE c_arc_packdetail 
               DEALLOCATE c_arc_packdetail
           END 
           
           -- tlting01 
           IF @n_continue=1
           OR @n_continue=2
           BEGIN
               DECLARE c_arc_packinfo CURSOR LOCAL FAST_FORWARD READ_ONLY 
               FOR
                   SELECT CartonNo
                   FROM   packinfo(NOLOCK)
                   WHERE  PickSlipNo = @cPickSlipNo 
               
               OPEN c_arc_packinfo 
               
               FETCH NEXT FROM c_arc_packinfo INTO @nCartonNo 
               
               WHILE @@fetch_status<>-1
               AND   (@n_continue=1 OR @n_continue=2)
               BEGIN
                   UPDATE packinfo WITH (ROWLOCK)
                   SET    packinfo.archivecop = '9'
                   WHERE  pickslipno = @cPickSlipNo
                   AND    CartonNo = @nCartonNo
                   
                   SELECT @local_n_err = @@error
                         ,@n_cnt = @@rowcount
                   
                   SELECT @n_archive_pack_info_records = @n_archive_pack_info_records 
                         +1
                   
                   IF @local_n_err<>0
                   BEGIN
                       SELECT @n_continue = 3 
                       SELECT @local_n_err = 77303 
                       SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err) 
                       SELECT @local_c_errmsg = 
                              ': update of archivecop failed - packinfo. (isp_ArchivePack) ' 
                             +' ( '+
                              ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+
                              ')'
                   END 
                   
                   FETCH NEXT FROM c_arc_packinfo INTO @nCartonNo
               END 
               CLOSE c_arc_packinfo 
               DEALLOCATE c_arc_packinfo
           END 
           -- end tlting01          
           FETCH NEXT FROM c_arc_packheader INTO @cPickSlipNo
       END 
       CLOSE c_arc_packheader 
       DEALLOCATE c_arc_packheader 
       
       DROP TABLE #temp1
   END
   if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
   begin
      select @c_temp = 'attempting to archive ' + rtrim(convert(char(6),@n_archive_pack_header_records )) +
                  ' packheader records and ' + rtrim(convert(char(6),@n_archive_pack_detail_records )) + 
                  ' packdetail records and ' + rtrim(convert(char(6),@n_archive_carton_track_records ))-- khlim01

      execute nsplogalert
         @c_modulename   = 'isp_ArchivePack',
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
         print 'building insert for packdetail...'
      end
      select @b_success = 1
      exec nsp_build_insert  
         @c_copyto_db, 
         'packdetail',
         1,
         @b_success output , 
         @n_err output, 
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end

   -- khlim01
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

   -- tlting01
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin   
      if (@b_debug =1 )
      begin
         print 'building insert for packinfo...'
      end
      select @b_success = 1
      exec nsp_build_insert  
         @c_copyto_db, 
         'packinfo',
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
         print 'building insert for packheader...'
      end
      select @b_success = 1
      exec nsp_build_insert  
         @c_copyto_db, 
         'packheader',
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
         @c_modulename   = 'isp_ArchivePack',
         @c_alertmessage = 'archive of pack ended successfully.',
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
            @c_modulename   = 'isp_ArchivePack',
            @c_alertmessage = 'archive of pack failed - check this log for additional messages.',
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_ArchivePack'
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