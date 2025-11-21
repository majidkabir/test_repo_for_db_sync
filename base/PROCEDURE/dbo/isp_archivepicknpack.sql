SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc : isp_ArchivePicknPack                                   */
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
/* 05-Mar-2012  TLTING    Pack Archive fail. Merge pack archive to      */
/*                        Archive Pick script                           */
/* 13-Jun-2012  TLTING    Exclude pickslip with partly order item not   */
/*                        archive                                       */
/* 05-Aug-2017  TLTING02  add archive PackSerialNo                      */
/* 02-Aug-2018  TLTING    remove Cartontrack from here                  */
/* 27-Dec-2020  TLTING03  Archive old Packing items                     */
/* 27-Dec-2020  TLTING03  Archive old Packing items                     */
/* 20-Oct-2021  TLTING04  add PackDetailInfo                            */
/* 28-May-2022  TLTING05  add PackQRF, PackdetailLabel                  */
/* 02-Jun-2022  TLTING06  archive more for Packdeader                   */
/************************************************************************/

CREATE PROC [dbo].[isp_ArchivePicknPack]
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
   SET ANSI_NULLS OFF
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
      @c_temp NVARCHAR(254),
      @n_archive_pickinginfo_records   int,
      -- June01
      -- ,@n_archive_RefKeyLookup_records  int
      @n_archive_pack_header_records   int, -- # of packheader records to be archived
      @n_archive_pack_detail_records   int, -- # of packdetail records to be archived
      @n_archive_pack_info_records int,  -- tlting01
      @n_archive_packserial_records int,
      @n_archive_PackDetailInfo_records INT,  --TLTING04
      @n_archive_PackQRF_records INT,  --TLTING05
      @n_archive_PackdetailLabel_records INT
      
   DECLARE @cPickSlipNo NVARCHAR(10)
          ,@nCartonNo INT
          ,@cLabelNo NVARCHAR(20)
          ,@cLabelLine NVARCHAR(5)

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

   -- Pack
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

   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'starting table existence check for PackSerialNo...'
      end
      select @b_success = 1
      exec nsp_build_archive_table
         @c_copyfrom_db,
         @c_copyto_db,
         'PackSerialNo',
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
         print 'starting table existence check for packinfo...'
      end
      select @b_success = 1
      exec nsp_build_archive_table
         @c_copyfrom_db,
         @c_copyto_db,
         'packinfo',
         @b_success output ,
         @n_err output,
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end

   --TLTING04
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'starting table existence check for PackDetailInfo...'
      end
      select @b_success = 1
      exec nsp_build_archive_table
         @c_copyfrom_db,
         @c_copyto_db,
         'PackDetailInfo',
         @b_success output ,
         @n_err output,
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end

   --TLTING05
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'starting table existence check for PackQRF...'
      end
      select @b_success = 1
      exec nsp_build_archive_table
         @c_copyfrom_db,
         @c_copyto_db,
         'PackQRF',
         @b_success output ,
         @n_err output,
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   END
    
   --TLTING05
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'starting table existence check for PackdetailLabel...'
      end
      select @b_success = 1
      exec nsp_build_archive_table
         @c_copyfrom_db,
         @c_copyto_db,
         'PackdetailLabel',
         @b_success output ,
         @n_err output,
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   END
    
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

    IF ((@n_continue=1 OR @n_continue=2)
      AND @copyrowstoarchivedatabase='y')
   BEGIN
       IF (@b_debug=1)
       BEGIN
           PRINT 'building alter table string for Packserialno...'
       END

       EXECUTE nspbuildaltertablestring
       @c_copyto_db,
       'Packserialno',
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

   --TLTING04
   IF ((@n_continue=1 OR @n_continue=2)
      AND @copyrowstoarchivedatabase='y')
   BEGIN
       IF (@b_debug=1)
       BEGIN
           PRINT 'building alter table string for PackDetailInfo...'
       END

       EXECUTE nspbuildaltertablestring
       @c_copyto_db,
       'PackDetailInfo',
       @b_success OUTPUT,
       @n_err OUTPUT,
       @c_errmsg OUTPUT
       IF NOT @b_success=1
       BEGIN
           SELECT @n_continue = 3
       END
   END

   --TLTING05
   IF ((@n_continue=1 OR @n_continue=2)
      AND @copyrowstoarchivedatabase='y')
   BEGIN
       IF (@b_debug=1)
       BEGIN
           PRINT 'building alter table string for PackQRF...'
       END

       EXECUTE nspbuildaltertablestring
       @c_copyto_db,
       'PackQRF',
       @b_success OUTPUT,
       @n_err OUTPUT,
       @c_errmsg OUTPUT
       IF NOT @b_success=1
       BEGIN
           SELECT @n_continue = 3
       END
   END
   --TLTING05
   IF ((@n_continue=1 OR @n_continue=2)
      AND @copyrowstoarchivedatabase='y')
   BEGIN
       IF (@b_debug=1)
       BEGIN
           PRINT 'building alter table string for PackdetailLabel...'
       END

       EXECUTE nspbuildaltertablestring
       @c_copyto_db,
       'PackdetailLabel',
       @b_success OUTPUT,
       @n_err OUTPUT,
       @c_errmsg OUTPUT
       IF NOT @b_success=1
       BEGIN
           SELECT @n_continue = 3
       END
   END

   WHILE @@trancount > 0
      commit tran

   declare @cPickHeaderKey NVARCHAR(10),
           @c_OrderKey     NVARCHAR(10),
           @nArchive       int,
           @cType          NVARCHAR(10),
           @cArchiveCop    NVARCHAR(1),
           @cLoadKey       NVARCHAR(10)


   if (@n_continue = 1 or @n_continue = 2)
   begin

       SELECT PickSlipNo = p.PickHeaderKey
         INTO #temp1
       FROM   PICKHEADER p (NOLOCK)
       JOIN ORDERS O (NOLOCK) ON p.OrderKey = O.OrderKey
       WHERE O.ArchiveCop = '9'
       AND  P.Zone NOT IN ('XD','LB','LP')

       INSERT INTO #temp1 (PickSlipNo)
       SELECT DISTINCT PH.PickHeaderKey
       FROM   PICKHEADER PH (NOLOCK)
       JOIN LOADPLAN L (NOLOCK) ON PH.ExternOrderKey = L.LoadKey
       WHERE (PH.OrderKey = '' OR PH.OrderKey IS NULL)
         AND  L.ArchiveCop = '9'
         AND  PH.Zone NOT IN ('XD','LB','LP')

       INSERT INTO #temp1 (PickSlipNo)
       SELECT DISTINCT PH.PickHeaderKey
       FROM   PICKHEADER PH (NOLOCK)
       JOIN   (SELECT DISTINCT R.PickSlipNo  --, R.OrderKey
               FROM RefKeyLookUp R WITH (NOLOCK)
               JOIN ORDERS OD WITH (NOLOCK) ON OD.OrderKey = R.OrderKey AND OD.ArchiveCop = '9') AS O
               ON O.PickSlipNo = PH.PickHeaderKey
       WHERE  PH.Zone IN ('XD','LB','LP')
       AND NOT EXISTS ( SELECT 1                      -- exclude pickslip with partly order item not archive
               FROM RefKeyLookUp R1 WITH (NOLOCK)
               JOIN ORDERS OD1 WITH (NOLOCK) ON OD1.OrderKey = R1.OrderKey
               JOIN PICKHEADER PH1 WITH (NOLOCK) ON PH1.PickHeaderKey = R1.PickSlipNo
               WHERE PH1.Zone IN ('XD','LB','LP')
                 AND ( OD1.ArchiveCop <> '9' OR  OD1.ArchiveCop is NULL )
               AND R1.PickSlipNo = PH.PickHeaderKey   )

       -- TLTING06
       INSERT INTO #temp1 (PickSlipNo)
       SELECT DISTINCT PH.PickSlipNo
       FROM   PACKHEADER PH (NOLOCK) 
       WHERE PH.STATUS = '9'
       AND   NOT EXISTS (SELECT TOP 1 1 FROM #temp1 L (NOLOCK) WHERE L.PickSlipNo = PH.PICKSLIPNO)
       AND   EXISTS ( SELECT TOP 1 1
               FROM   ORDERS O WITH (NOLOCK) 
               WHERE O.OrderKey =  PH.OrderKey AND O.ArchiveCop = '9'   )    
       AND   PH.OrderKey IS NOT NULL AND PH.OrderKey <> ''
         
         
         -- TLTING03
       INSERT INTO #temp1 (PickSlipNo)
       SELECT PH.pickslipno
       FROM   PaCKHEADER PH (NOLOCK)
       WHERE (PH.OrderKey = '' OR PH.OrderKey IS NULL)
       AND   NOT EXISTS ( SELECT 1 from LOADPLAN L (NOLOCK) WHERE PH.LoadKey = L.LoadKey  )
       AND   NOT EXISTS ( SELECT 1 from #temp1 L (NOLOCK)   WHERE PH.PickSlipNo = L.PickSlipNo  )
       AND  PH.Editdate < getdate() - 45


         -- TLTING04
       INSERT INTO #temp1 (PickSlipNo)
        SELECT PH.PickHeaderKey
       FROM   PICKHEADER PH (NOLOCK)
       WHERE (PH.OrderKey = '' OR PH.OrderKey IS NULL)
       AND   NOT EXISTS ( SELECT 1 from LOADPLAN L (NOLOCK) WHERE PH.ExternOrderKey = L.LoadKey  )
       AND   NOT EXISTS ( SELECT 1 from #temp1 L (NOLOCK)   WHERE PH.PickHeaderKey = L.PickSlipNo  )
       AND  PH.Editdate < getdate() - 45

      declare c_arc_pickheader cursor local fast_forward read_only for
      SELECT DISTINCT PickSlipNo   -- KHLim02
      FROM   #temp1 t


       SELECT @n_archive_pack_header_records = 0
       SELECT @n_archive_pack_detail_records = 0
       select @n_archive_pack_info_records = 0
      select @n_archive_pack_detail_records = 0

      select @n_archive_pick_header_records = 0
      select @n_archive_pickinginfo_records = 0
      select @n_archive_packserial_records = 0

      -- June01
      -- select @n_archive_RefKeyLookup_records = 0
      open c_arc_pickheader

      fetch next from c_arc_pickheader into @cPickSlipNo

      while @@fetch_status <> -1 and ((@n_continue = 1 or @n_continue = 2))
      begin
         begin tran

         update PickingInfo with (rowlock)
            set PickingInfo.archivecop = '9'
         where  PickSlipNo = @cPickSlipNo
         select @local_n_err = @@error, @n_cnt = @@rowcount
         select @n_archive_pickinginfo_records = @n_archive_pickinginfo_records + 1
         if @local_n_err <> 0
         begin
            select @n_continue = 3
            select @local_n_err = 77303
            select @local_c_errmsg = convert(char(5),@local_n_err)
            select @local_c_errmsg =
            ': update of archivecop failed - PickingInfo. (isp_ArchivePicknPack) ' + ' ( ' +
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
         where  pickheaderkey = @cPickSlipNo
         select @local_n_err = @@error, @n_cnt = @@rowcount
         select @n_archive_pick_header_records = @n_archive_pick_header_records + 1
         if @local_n_err <> 0
         begin
            select @n_continue = 3
            select @local_n_err = 77304
            select @local_c_errmsg = convert(char(5),@local_n_err)
            select @local_c_errmsg =
            ': update of archivecop failed - pickheader. (isp_ArchivePicknPack) ' + ' ( ' +
            ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
            rollback tran
         end
         else
         begin
            commit tran
         end

         begin tran

         UPDATE packheader WITH (ROWLOCK) -- 10-Aug-2005 (SOS38267)
         SET    packheader.archivecop = '9'
         WHERE  PickSlipNo = @cPickSlipNo

         SELECT @local_n_err = @@error,@n_cnt = @@rowcount

         SELECT @n_archive_pack_header_records = @n_archive_pack_header_records + 1
         IF @local_n_err<>0
         BEGIN
            SELECT @n_continue = 3
            SELECT @local_n_err = 77305
            SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
            SELECT @local_c_errmsg =
                   ': update of archivecop failed - packheader. (isp_ArchivePack) '
                  +' ( '+
                   ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+')'
         END
         else
         begin
            commit tran
         end


         IF @n_continue=1 OR @n_continue=2
         BEGIN
            begin tran
            DECLARE c_arc_packdetail CURSOR LOCAL FAST_FORWARD READ_ONLY
            FOR
                SELECT CartonNo
                      ,LabelNo
                      ,LabelLine
                FROM   packdetail (NOLOCK)
                WHERE  PickSlipNo = @cPickSlipNo

            OPEN c_arc_packdetail

            FETCH NEXT FROM c_arc_packdetail INTO @nCartonNo, @cLabelNo, @cLabelLine

            WHILE @@fetch_status<>-1
            AND   (@n_continue=1 OR @n_continue=2)
            BEGIN

                IF EXISTS ( SELECT 1 FROM PackSerialNo (NOLOCK) WHERE pickslipno = @cPickSlipNo
                                     AND    CartonNo = @nCartonNo
                                     AND    LabelNo = @cLabelNo
                                     AND    LabelLine = @cLabelLine )
                BEGIN
                   UPDATE PackSerialNo WITH (ROWLOCK)
                   SET    PackSerialNo.archivecop = '9'
                   WHERE  pickslipno = @cPickSlipNo
                   AND    CartonNo = @nCartonNo
                   AND    LabelNo = @cLabelNo
                   AND    LabelLine = @cLabelLine

                   SELECT @local_n_err = @@error
                         ,@n_cnt = @@rowcount

                   SELECT @n_archive_packserial_records = @n_archive_packserial_records + @n_cnt

                   IF @local_n_err<>0
                   BEGIN
                       SELECT @n_continue = 3
                       SELECT @local_n_err = 77306
                       SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                       SELECT @local_c_errmsg =
                              ': update of archivecop failed - PackSerialNo. (isp_ArchivePack) '
                             +' ( '+
                              ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+
                              ')'
                   END
                END

               IF EXISTS ( SELECT 1 FROM PackDetailInfo (NOLOCK) WHERE pickslipno = @cPickSlipNo
                                     AND    CartonNo = @nCartonNo
                                     AND    LabelNo = @cLabelNo
                                     AND    LabelLine = @cLabelLine )
                BEGIN
                   UPDATE PackDetailInfo WITH (ROWLOCK)
                   SET    PackDetailInfo.archivecop = '9'
                   WHERE  pickslipno = @cPickSlipNo
                   AND    CartonNo = @nCartonNo
                   AND    LabelNo = @cLabelNo
                   AND    LabelLine = @cLabelLine

                   SELECT @local_n_err = @@error
                         ,@n_cnt = @@rowcount

                   SELECT @n_archive_PackDetailInfo_records = @n_archive_PackDetailInfo_records + @n_cnt

                   IF @local_n_err<>0
                   BEGIN
                       SELECT @n_continue = 3
                       SELECT @local_n_err = 77306
                       SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                       SELECT @local_c_errmsg =
                              ': update of archivecop failed - PackDetailInfo. (isp_ArchivePack) '
                             +' ( '+
                              ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+
                              ')'
                   END
                END
                -- TLTING05
                IF EXISTS ( SELECT 1 FROM PackQRF (NOLOCK) WHERE pickslipno = @cPickSlipNo
                                     AND    CartonNo = @nCartonNo
                                     AND    LabelLine = @cLabelLine )
                BEGIN
                   UPDATE PackQRF WITH (ROWLOCK)
                   SET    archivecop = '9'
                   WHERE  pickslipno = @cPickSlipNo
                   AND    CartonNo = @nCartonNo
                   AND    LabelLine = @cLabelLine

                   SELECT @local_n_err = @@error
                         ,@n_cnt = @@rowcount

                   SELECT @n_archive_PackQRF_records = @n_archive_PackQRF_records + @n_cnt

                   IF @local_n_err<>0
                   BEGIN
                       SELECT @n_continue = 3
                       SELECT @local_n_err = 77325
                       SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                       SELECT @local_c_errmsg =
                              ': update of archivecop failed - PackQRF. (isp_ArchivePack) '
                             +' ( '+
                              ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+
                              ')'
                   END
                END
                -- TLTING05
                IF EXISTS ( SELECT 1 FROM PackdetailLabel (NOLOCK) WHERE pickslipno = @cPickSlipNo
                                     AND    CartonNo = @nCartonNo
                                     AND    LabelNo = @cLabelNo )
                BEGIN
                   UPDATE PackdetailLabel WITH (ROWLOCK)
                   SET    archivecop = '9'
                   WHERE  pickslipno = @cPickSlipNo
                   AND    CartonNo = @nCartonNo
                   AND    LabelNo = @cLabelNo

                   SELECT @local_n_err = @@error
                         ,@n_cnt = @@rowcount

                   SELECT @n_archive_PackdetailLabel_records = @n_archive_PackdetailLabel_records + @n_cnt

                   IF @local_n_err<>0
                   BEGIN
                       SELECT @n_continue = 3
                       SELECT @local_n_err = 77327
                       SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                       SELECT @local_c_errmsg =
                              ': update of archivecop failed - PackdetailLabel. (isp_ArchivePack) '
                             +' ( '+
                              ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+
                              ')'
                   END
                END
 

                UPDATE packdetail WITH (ROWLOCK) -- 10-Aug-2005 (SOS38267)
                SET    packdetail.archivecop = '9'
                WHERE  pickslipno = @cPickSlipNo
                AND    CartonNo = @nCartonNo
                AND    LabelNo = @cLabelNo
                AND    LabelLine = @cLabelLine

                SELECT @local_n_err = @@error
                      ,@n_cnt = @@rowcount

                SELECT @n_archive_pack_detail_records = @n_archive_pack_detail_records + @n_cnt

                IF @local_n_err<>0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @local_n_err = 77306
                    SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                    SELECT @local_c_errmsg =
                           ': update of archivecop failed - packdetail. (isp_ArchivePack) '
                          +' ( '+
                           ' sqlsvr message = '+LTRIM(RTRIM(@local_c_errmsg))+
                           ')'
                END

                FETCH NEXT FROM c_arc_packdetail INTO @nCartonNo, @cLabelNo, @cLabelLine
            END
            CLOSE c_arc_packdetail
            DEALLOCATE c_arc_packdetail
            IF @local_n_err=0
            BEGIN
               COMMIT TRAN
            END
         END

         -- tlting01
         IF @n_continue=1 OR @n_continue=2
         BEGIN
            BEGIN TRAN
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

                SELECT @n_archive_pack_info_records = @n_archive_pack_info_records + @n_cnt

                IF @local_n_err<>0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @local_n_err = 77308
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
            IF @local_n_err=0
            BEGIN
               COMMIT TRAN
            END
         END
         -- end tlting01

         fetch next from c_arc_pickheader into @cPickSlipNo
      end
      close c_arc_pickheader
      deallocate c_arc_pickheader
      DROP TABLE #temp1
   end


   if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')
   begin
      select @c_temp = 'attempting to archive ' + RTrim(convert(varchar(6),@n_archive_pick_header_records )) +
         ' pickheader records and ' + RTrim(convert(varchar(6),@n_archive_pickinginfo_records ))   +
         ' pickinginfo records and ' + rtrim(convert(varchar(6),@n_archive_pack_header_records )) +
         ' packheader records and ' + rtrim(convert(varchar(6),@n_archive_pack_detail_records )) +
         ' packdetail records and ' + rtrim(convert(varchar(6),@n_archive_pack_info_records )) +
         ' packinfo records ' + rtrim(convert(varchar(6),@n_archive_packserial_records )) +
         ' PackSerialNo records ' + rtrim(convert(varchar(6),@n_archive_PackDetailInfo_records )) + 
         ' PackDetailInfo records ' + rtrim(convert(varchar(6),@n_archive_PackQRF_records )) +
         ' PackQRF records '

      execute dbo.nsplogalert
         @c_modulename   = 'isp_ArchivePicknPack',
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

   -- Pack
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

   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'building insert for PackSerialNo...'
      end
      select @b_success = 1
      exec nsp_build_insert
         @c_copyto_db,
         'PackSerialNo',
         1,
         @b_success output ,
         @n_err output,
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end


   --TLTING04
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'building insert for PackDetailInfo...'
      end
      select @b_success = 1
      exec nsp_build_insert
         @c_copyto_db,
         'PackDetailInfo',
         1,
         @b_success output ,
         @n_err output,
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end

   --TLTING05
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'building insert for PackQRF...'
      end
      select @b_success = 1
      exec nsp_build_insert
         @c_copyto_db,
         'PackQRF',
         1,
         @b_success output ,
         @n_err output,
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   end
   --TLTING05
   if ((@n_continue = 1 or @n_continue = 2) and @copyrowstoarchivedatabase = 'y')
   begin
      if (@b_debug =1 )
      begin
         print 'building insert for PackdetailLabel...'
      end
      select @b_success = 1
      exec nsp_build_insert
         @c_copyto_db,
         'PackdetailLabel',
         1,
         @b_success output ,
         @n_err output,
         @c_errmsg output
      if not @b_success = 1
      begin
         select @n_continue = 3
      end
   END
   
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
         @c_modulename   = 'isp_ArchivePicknPack',
         @c_alertmessage = 'archive of pick & pack ended successfully.',
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
            @c_modulename   = 'isp_ArchivePicknPack',
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
      execute dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ArchivePicknPack'
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