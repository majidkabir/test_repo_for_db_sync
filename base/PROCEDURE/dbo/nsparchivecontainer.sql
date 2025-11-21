SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: NspArchiveContainer                                */
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
/************************************************************************/

CREATE PROC    [dbo].[NspArchiveContainer]
@c_copyfrom_db  NVARCHAR(55)
,              @c_copyto_db    NVARCHAR(55)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @b_debug int            , -- Debug On Or Off
   @n_retain_days int      , -- days to hold data
   @d_result  datetime     , -- date  - (getdate() - noofdaystoretain
   @c_datetype NVARCHAR(10),     -- 1=ContainerDATE, 2=EditDate, 3=AddDate, 4=EffectiveDate
   @n_archive_cont_records   int, -- # of cont records to be archived
   @n_archive_cont_detail_records   int -- # of cont_detail records to be archived
   DECLARE        @local_n_err         int,
   @local_c_errmsg    NVARCHAR(254)
   DECLARE   @ContainerNumberofDaysToRetain  int ,
   @c_containerActive NVARCHAR(2),
   @c_containerStart NVARCHAR(20),
   @c_containerEnd   NVARCHAR(20),
   @c_containerDateType  NVARCHAR(10),
   @c_whereclause NVARCHAR(254),
   @c_temp NVARCHAR(254),
   @CopyRowsToArchiveDatabase NVARCHAR(2)
   /* #INCLUDE <SPARCON1.SQL> */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
   @b_debug = 0  ,@local_n_err = 0, @local_c_errmsg = ' '
   IF db_id(@c_copyto_db) is NULL
   BEGIN
      SELECT @n_continue = 3
      SELECT @local_n_err = 73701
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      SELECT @local_c_errmsg =
      ": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
      " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + ' (nspArchiveContainer)'
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @n_retain_days = Containernumberofdaystoretain,
      @c_containerActive = ContainerActive ,
      @c_containerStart = ContainerStart ,
      @c_containerEnd = ContainerEnd ,
      @c_containerDateType =  ContainerDateType,
      @c_datetype = Containerdatetype,
      @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
      FROM ArchiveParameters
      SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
      SELECT @d_result = dateadd(day,1,@d_result)
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = "Archive Of Container Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
      ' ; Active = '+ dbo.fnc_RTrim(@c_ContainerActive)+ ' ; Adj = '+dbo.fnc_RTrim(@c_ContainerStart)+'-'+dbo.fnc_RTrim(@c_ContainerEnd)+
      ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ convert(char(6),@n_retain_days)
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspArchiveContainer",
      @c_AlertMessage = @c_temp,
      @n_Severity     = 0,
      @b_success       = @b_success OUTPUT,
      @n_err          = @n_err OUTPUT,
      @c_errmsg       = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      SELECT @c_temp = ' '
      IF (dbo.fnc_RTrim(@c_ContainerStart) IS NOT NULL and dbo.fnc_RTrim(@c_ContainerEnd) IS NOT NULL)
      BEGIN
         SELECT @c_temp =  ' AND Container.ContainerKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_ContainerStart) + '''' +' AND '+
         'N'''+dbo.fnc_RTrim(@c_ContainerEnd)+''''
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         select @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'CONTAINER',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'CONTAINERDetail',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for Container..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"Container",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for ContainerDetail..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"ContainerDetail",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         BEGIN TRAN
            IF @c_datetype = "1" --ContainerDate
            BEGIN
               SELECT @b_success = 1
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveContainer",
               @c_AlertMessage = "Archiveing Container Based on ContainerDATE is Not Active - Aborting...",
               @n_Severity     = 0,
               @b_success       = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT
               SELECT @local_n_err = 74200
               SELECT @local_c_errmsg = "Archiveing Container Based on ContainerDATE is Not Active - Aborting..."
               SELECT @n_continue = 3
            END
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               IF @c_datetype = "2" --EditDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE CONTAINER SET Archivecop = '9' WHERE CONTAINER.EditDate <= "+ '"'+ convert(char(10),@d_result,101)+ '"'+" and CONTAINER.Status = '9' " + @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_cont_records = @n_cnt
               END
               IF @c_datetype = "3" --AddDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE CONTAINER SET Archivecop = '9' WHERE CONTAINER.AddDate <= "+ '"'+convert(char(10),@d_result,101)+ '"'+ " and CONTAINER.Status = '9' " + @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_cont_records = @n_cnt
               END
               IF @c_datetype = "4" --EffectiveDate
               BEGIN
                  SELECT @c_whereclause = "UPDATE CONTAINER SET Archivecop = '9' WHERE CONTAINER.EffectiveDate <="+ '"'+convert(char(10),@d_result,101)+'"'+ " and CONTAINER.Status = '9'" + @c_temp
                  EXECUTE (@c_whereclause)
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  SELECT @n_archive_cont_records = @n_cnt
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT @c_whereclause
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74201
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ": Update of Archivecop failed - CONTAINER. (NspArchiveContainer) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               UPDATE CONTAINERDetail
               Set CONTAINERDetail.Archivecop = '9'
               FROM CONTAINER
               Where ((CONTAINERDetail.containerkey = CONTAINER.containerkey) and (CONTAINER.archivecop = '9'))
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               SELECT @n_archive_cont_detail_records = @n_cnt
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74202
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ": Update of Archivecop failed - CONTAINERDetail. (NspArchiveContainer) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
            BEGIN
               SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_cont_records )) +
               " Container records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_cont_detail_records )) + " ContainerDetail records"
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveContainer",
               @c_AlertMessage = @c_Temp ,
               @n_Severity     = 0,
               @b_success       = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT
               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT  @c_copyto_db, 'CONTAINER',1,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT   @c_copyto_db, 'CONTAINERDetail',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM CONTAINER
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT * FROM CONTAINER
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74203
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  Container delete failed. (NspArchiveContainer) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               IF (@b_debug = 0)
               BEGIN
                  DELETE FROM CONTAINERDetail
                  WHERE ARCHIVECOP = '9'
                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               END
               IF (@b_debug = 1)
               BEGIN
                  SELECT * FROM CONTAINERDetail
                  WHERE ARCHIVECOP = '9'
               END
               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 74204
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ":  ContainerDetail delete failed. (NspArchiveContainer) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               END
            END
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               COMMIT TRAN
            END
         ELSE
            BEGIN
               ROLLBACK TRAN
            END
         END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspLogAlert
         @c_ModuleName   = "nspArchiveContainer",
         @c_AlertMessage = "Archive Of Container Ended Normally.",
         @n_Severity     = 0,
         @b_success       = @b_success OUTPUT,
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
            EXECUTE nspLogAlert
            @c_ModuleName   = "nspArchiveContainer",
            @c_AlertMessage = "Archive Of Container Ended Abnormally - Check This Log For Additional Messages.",
            @n_Severity     = 0,
            @b_success       = @b_success OUTPUT,
            @n_err          = @n_err OUTPUT,
            @c_errmsg       = @c_errmsg OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END
      END
      /* #INCLUDE <SPARCON2.SQL> */
      IF @n_continue=3  -- Error Occured - Process And Return
      BEGIN
         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
      ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, "NspArchiveContainer"
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   ELSE
      BEGIN
         SELECT @b_success = 1
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
         RETURN
      END
   END


GO