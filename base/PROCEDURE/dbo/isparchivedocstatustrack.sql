SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc : ispArchiveDocStatusTrack                               */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Housekeeping dbo.DocStatusTrack table                       */
/*          Note: Duplicate from ispArchiveTransmitLog                  */
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
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

 

CREATE   PROC [dbo].[ispArchiveDocStatusTrack]
     @c_ArchiveKey NVARCHAR(10)
   , @b_Success    int       OUTPUT
   , @n_err        int       OUTPUT
   , @c_errmsg     NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @dummy       NVARCHAR(1),
           @n_continue  int,
           @n_starttcnt int, -- Holds the current transaction count
           @n_cnt       int, -- Holds @@ROWCOUNT after certain operations
           @b_debug     int -- Debug On OR Off

   /* #INCLUDE <SPACC1.SQL> */
   DECLARE @n_retain_days         int, -- days to hold data
            @d_result             datetime, -- date (GETDATE() - noofdaystoretain)
            @c_datetype           NVARCHAR(10), -- 1=EditDate, 2=AddDate
            @n_archive_TL_records int -- No. of dbo.DocStatusTrack records to be archived

   DECLARE @local_n_err    int,
           @local_c_errmsg NVARCHAR(254)

   DECLARE @c_DocStatus                 NVARCHAR(2),
           @n_RowRefStart               BIGINT,
           @n_RowRefEnd                 BIGINT,
           @c_whereclause               NVARCHAR(254),
           @c_temp                      NVARCHAR(254),
           @c_CopyRowsToArchiveDatabase NVARCHAR(1),
           @c_CopyFrom_DB               NVARCHAR(30),
           @c_CopyTo_DB                 NVARCHAR(30),
           @c_TableName                 NVARCHAR(30),
           @c_DocumentNo                NVARCHAR(20)

   DECLARE @n_RowRef BIGINT   

   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = '',
          @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ''

   SELECT @n_archive_TL_records = 0

   SELECT @c_CopyFrom_DB = livedatabasename,
          @c_CopyTo_DB = archivedatabasename,
          @n_retain_days = tranmlognumberofdaystoretain,
          @c_datetype = tranmlogdatetype,
          --@n_RowRefStart= ISNULL (tranmlogstart,''),
          --@n_RowRefEnd= ISNULL (tranmlogend,'ZZZZZZZZZZ'),
          @c_CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
   FROM dbo.ArchiveParameters WITH (NOLOCK)
   WHERE ArchiveKey = @c_ArchiveKey

   IF db_id(@c_CopyTo_DB) IS NULL
   BEGIN
      SELECT @n_continue = 3
      SELECT @local_n_err = 77100
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      SELECT @local_c_errmsg =
            ': Target Database ' + @c_CopyTo_DB + ' Does NOT exist ' + ' ( ' +
            ' SQLSvr MESSAGE = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')' +' (ispArchiveDocStatusTrack) '
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @c_DocStatus = '9' -- default only archive those DocStatus = '9'

      DECLARE @d_today datetime
      SELECT @d_today = CONVERT(datetime,CONVERT(char(11),GETDATE(),106))
      SELECT @d_result = DATEADD(DAY,(-@n_retain_days),@d_today)
      SELECT @d_result = DATEADD(DAY,1,@d_result)
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = 'Archive Of IDS dbo.DocStatusTrack Started with Parms; Datetype = ' + RTRIM(@c_datetype) +
                        ' ; DocStatus = '+ RTRIM(@c_DocStatus)+ ' ; RowRef = ' + CONVERT(VARCHAR(10), @n_RowRefStart) + '-'
                        + CONVERT(VARCHAR(10), @n_RowRefEnd) +
                        ' ; Copy Rows to Archive = '+RTRIM(@c_CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ CONVERT(char(6),@n_retain_days)
      EXECUTE nspLogAlert
               @c_ModuleName   = 'ispArchiveDocStatusTrack',
               @c_AlertMessage = @c_temp,
               @n_Severity     = 0,
               @b_success      = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF  (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SET @c_temp = ''

      --IF (@n_RowRefStart IS NOT NULL AND @n_RowRefEnd IS NOT NULL)
      --BEGIN
      --   SELECT @c_temp = ' AND dbo.DocStatusTrack.RowRef BETWEEN '+ CONVERT(VARCHAR(10), @n_RowRefStart) + ' AND '+
      --   RTRIM(@n_RowRefEnd)
      --END

      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_CopyFrom_DB, @c_CopyTo_DB, 'DocStatusTrack',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @dummy
            SELECT @n_continue = 3
         END
      END

      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_CopyFrom_DB, @c_CopyTo_DB, 'DocStatusTrack',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END

      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            SELECT @dummy
         END

         EXECUTE dbo.nspBuildAlterTableString @c_CopyTo_DB,'DocStatusTrack',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END

      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print 'building alter table string for dbo.DocStatusTrack...'
         END
         EXECUTE dbo.nspBuildAlterTableString @c_CopyTo_DB,'DocStatusTrack',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END

      IF ((@n_continue = 1 OR @n_continue = 2 ) AND @c_CopyRowsToArchiveDatabase = 'Y')
      BEGIN

         IF (@n_continue = 1 OR @n_continue = 2 )
         BEGIN
            IF @c_datetype = '1' -- EditDate
            BEGIN
               SELECT @c_whereclause = ' WHERE dbo.DocStatusTrack.EditDate  <= ' + ''''+ CONVERT(char(8),@d_result,112)+''''  
                                     --  + ' AND (DocStatusTrack.DocStatus = ''9'' OR dbo.DocStatusTrack.DocStatus = ''5'' OR dbo.DocStatusTrack.DocStatus = ''CANC'') ' + 
                                     --  +  @c_temp
            END   
            IF @c_datetype = '2' -- AddDate
            BEGIN
               SELECT @c_whereclause = ' WHERE dbo.DocStatusTrack.AddDate  <= ' + ''''+ CONVERT(char(8),@d_result,112) +''''    
                                    --   + ' AND (DocStatusTrack.DocStatus = ''9'' OR dbo.DocStatusTrack.DocStatus = ''5'' OR dbo.DocStatusTrack.DocStatus = ''CANC'') ' + 
                                     --  +  @c_temp
            END

            IF (@b_debug = 1)
            BEGIN
               PRINT ' SELECT RowRef, TableName, DocumentNo FROM dbo.DocStatusTrack WITH (NOLOCK) ' + CHAR(13) + 
               @c_whereclause + ' ORDER BY RowRef '
            END

            EXEC (
            ' DECLARE CUR_RowRef CURSOR FAST_FORWARD READ_ONLY FOR ' +
            ' SELECT RowRef, TableName, DocumentNo FROM dbo.DocStatusTrack WITH (NOLOCK) ' + @c_whereclause +
            ' ORDER BY RowRef ' )

            OPEN CUR_RowRef

            FETCH NEXT FROM CUR_RowRef INTO @n_RowRef, @c_TableName, @c_DocumentNo

            WHILE @@fetch_status <> -1
            BEGIN

               IF @c_TableName IN ('ASNSTS','STSASN','STSRECEIPT')
               BEGIN
                  IF EXISTS(SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK) 
                            WHERE R.ReceiptKey = @c_DocumentNo)
                  BEGIN
                     --CONTINUE
                     GOTO NEXT_DOC
                  END
               END

               IF @c_TableName IN ('STSORDERS','STSPACK')
               BEGIN
                  IF EXISTS(SELECT 1 FROM dbo.ORDERS O WITH (NOLOCK) 
                            WHERE O.OrderKey = @c_DocumentNo)
                  BEGIN
                     GOTO NEXT_DOC
                  END
               END

               IF @c_TableName IN ('STSPOD')
               BEGIN
                  IF EXISTS(SELECT 1 FROM dbo.POD P WITH (NOLOCK) 
                            WHERE P.OrderKey = @c_DocumentNo)
                  BEGIN
                     GOTO NEXT_DOC
                  END
               END

               BEGIN TRAN

               UPDATE dbo.DocStatusTrack WITH (ROWLOCK)
                  SET ArchiveCop = '9'
               WHERE RowRef = @n_RowRef

               SELECT @local_n_err = @@error, @n_cnt = @@rowcount
               SELECT @n_archive_TL_records = @n_archive_TL_records + 1

               IF @local_n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 77101
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                        ': Update of Archivecop failed - DocStatusTrack Table. (ispArchiveDocStatusTrack) ' + ' ( ' +
                        ' SQLSvr MESSAGE = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')'
                  ROLLBACK TRAN
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END

               NEXT_DOC:

               FETCH NEXT FROM CUR_RowRef INTO @n_RowRef, @c_TableName, @c_DocumentNo
            END -- while RowRef

            IF (@b_debug = 1)
            BEGIN
               SELECT    @n_archive_TL_records '@n_archive_TL_records'
            END
            CLOSE CUR_RowRef
            DEALLOCATE CUR_RowRef
            /* END (SOS38267) UPDATE*/
         END

         IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
         BEGIN
            SELECT @c_temp = 'Attempting to Archive ' + RTRIM(CONVERT(char(6),@n_archive_TL_records )) +
                             ' dbo.DocStatusTrack records '
            EXECUTE nspLogAlert
                     @c_ModuleName   = 'ispArchiveDocStatusTrack',
                     @c_AlertMessage = @c_Temp ,
                     @n_Severity     = 0,
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
            SELECT @b_success = 1
            EXEC dbo.nsp_BUILD_INSERT @c_copyto_db = @c_CopyTo_DB
                 , @c_tablename='DocStatusTrack'
                 , @b_archive=1 
                 , @b_Success=@b_success OUTPUT
                 , @n_err=@n_err OUTPUT
                 , @c_errmsg=@c_errmsg OUTPUT

            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END

         IF (@b_debug = 1)
         BEGIN
            SELECT 'ArchiveCop', COUNT(*)
            FROM dbo.DocStatusTrack (NOLOCK)
            WHERE ArchiveCop = '9'
         END
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @b_success = 1
      EXECUTE nspLogAlert
               @c_ModuleName   = 'ispArchiveDocStatusTrack',
               @c_AlertMessage = 'Archive Of dbo.DocStatusTrack Ended Normally.',
               @n_Severity     = 0,
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
         EXECUTE nspLogAlert
                  @c_ModuleName   = 'ispArchiveDocStatusTrack',
                  @c_AlertMessage = 'Archive Of dbo.DocStatusTrack Ended Abnormally - Check This Log For Additional Messages.',
                  @n_Severity     = 0,
                  @b_success      = @b_success OUTPUT,
                  @n_err          = @n_err OUTPUT,
                  @c_errmsg       = @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
   END

   /* #INCLUDE <SPACC2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispArchiveDocStatusTrack'
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