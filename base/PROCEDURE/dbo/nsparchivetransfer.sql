SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : nspArchiveTransfer                                     */
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
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 2005-Dec-01  Shong     Revise Build Insert SP - Check Duplicate      */
/*                        - Delete only when records inserted into      */
/*                        Archive Table.                                */
/* 2014-JUL-30  YTWan     Add New RCM to Cancel Transfer in Exceed      */
/*                        Front end. (Wan01)                            */
/************************************************************************/
CREATE PROC    [dbo].[nspArchiveTransfer]
@c_archivekey NVARCHAR(10),
@b_Success      int        OUTPUT,
@n_err          int        OUTPUT,
@c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue int         ,
            @n_starttcnt int        , -- Holds the current Transaction count
            @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
            @b_debug int              -- Debug On Or Off
   /* #INCLUDE <SPATran1.SQL> */
   DECLARE  @n_retain_days int        , -- days to hold data
            @d_Trandate  datetime     , -- Tran Date from Tran header table
            @d_result  datetime       , -- date Tran_date - (getdate() - noofdaystoretain
            @c_datetype NVARCHAR(10),       -- 1=TranDATE, 2=EditDate, 3=AddDate
            @n_archive_Tran_records   int, -- # of Tran records to be archived
            @n_archive_Tran_detail_records   int -- # of Tran_detail records to be archived

   DECLARE  @local_n_err         int,
            @local_c_errmsg    NVARCHAR(254)
   DECLARE  @c_copyfrom_db  NVARCHAR(55),
            @c_copyto_db    NVARCHAR(55),
            @c_tranActive NVARCHAR(2),
            @c_tranStart NVARCHAR(10),
            @c_tranEnd NVARCHAR(10),
            @c_whereclause NVARCHAR(350),
            @c_temp NVARCHAR(254),
            @CopyRowsToArchiveDatabase NVARCHAR(1)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
          @b_debug = 0 , @local_n_err = 0, @local_c_errmsg = ' '

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = "Archive Of Transfer Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
      ' ; Active = '+ dbo.fnc_RTrim(@c_TranActive)+' ; Tran = '+dbo.fnc_RTrim(@c_TranStart)+'-'+dbo.fnc_RTrim(@c_TranEnd)+
      ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) + ' ; Retain Days = '+ convert(char(6),@n_retain_days)
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspArchiveTransfer",
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
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT  @c_copyfrom_db = livedatabasename,
      @c_copyto_db = archivedatabasename,
      @n_retain_days = Trannumberofdaystoretain,
      @c_datetype = Transferdatetype,
      @c_TranActive = TranActive,
      @c_TranStart = TranStart,
      @c_TranEnd = TranEnd,
      @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
      FROM ArchiveParameters (nolock)
      WHERE archivekey = @c_archivekey
      SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
      SELECT @d_result = dateadd(day,1,@d_result)
      IF db_id(@c_copyto_db) is NULL
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err = 73701
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
         SELECT @local_c_errmsg =
         ": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
         " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + " (nspArchiveTransfer)"
      END
   END
   IF  (@n_continue = 1 or @n_continue = 2)
   BEGIN
      SELECT @c_temp =  ' AND Transfer.TransferKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_TranStart) + '''' +' AND '+
      'N'''+dbo.fnc_RTrim(@c_TranEnd)+''''
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         select @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'Transfer',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'TransferDetail',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for Transfer..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"Transfer",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print "building alter table string for TransferDetail..."
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,"TransferDetail",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END

      IF ((@n_continue = 1 or @n_continue = 2 ) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         BEGIN TRAN
            IF @c_datetype = "1" --
            BEGIN
               SELECT @b_success = 1
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveTransfer",
               @c_AlertMessage = "Archiving Transfer Based on TranDate is Not Active - Aborting...",
               @n_Severity     = 0,
               @b_success       = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT
               SELECT @n_continue = 3
               SELECT @local_n_err =  77200
               SELECT @local_c_errmsg = "Archiving Transfer Based on TranDate is Not Active - Aborting..."
            END
            IF (@n_continue = 1 or @n_continue = 2 )
            BEGIN
               --(Wan01) - Add to archive CANC status as well - START 
               IF @c_datetype = "2" -- EditDate
               BEGIN
                  SELECT @c_whereclause = "WHERE Transfer.EditDate  <= " + '"'+ convert(char(11),@d_result,106)+'"' + " and Transfer.Status IN( '9', 'CANC') " + @c_temp
               END
               IF @c_datetype = "3" -- AddDate
               BEGIN
                  SELECT @c_whereclause = "WHERE Transfer.AddDate  <= " + '"'+ convert(char(11),@d_result,106)+'"' +  " and Transfer.Status IN( '9', 'CANC') " +  @c_temp
               END
               --(Wan01) - Add to archive CANC status as well - END
---------------------
               WHILE @@TRANCOUNT > @n_starttcnt
                  COMMIT TRAN 
   
               DECLARE @cTransferKey NVARCHAR(10), 
                       @cTransferLineNumber NVARCHAR(5)
      
               SELECT @n_archive_Tran_records = 0
               SELECT @n_archive_Tran_detail_records = 0 
      
               WHILE @@TRANCOUNT > @n_starttcnt 
                  COMMIT TRAN 
   
               EXEC (
               ' Declare C_Arc_TransferHeader CURSOR FAST_FORWARD READ_ONLY FOR ' + 
               ' SELECT TransferKey FROM Transfer (NOLOCK) ' + @c_WhereClause + 
               ' ORDER BY TransferKey ' ) 
               
               OPEN C_Arc_TransferHeader
               
               FETCH NEXT FROM C_Arc_TransferHeader INTO @cTransferKey
               
               WHILE @@fetch_status <> -1
               BEGIN
                  BEGIN TRAN 
      
                  UPDATE Transfer WITH (ROWLOCK)
                     SET ArchiveCop = '9' 
                  WHERE TransferKey = @cTransferKey  
      
            		select @local_n_err = @@error   --, @n_cnt = @@rowcount            
                  SELECT @n_archive_Tran_records = @n_archive_Tran_records + 1            
                  IF @local_n_err <> 0
               	BEGIN 
                     SELECT @n_continue = 3
                     SELECT @local_n_err = 77201
                     SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                     SELECT @local_c_errmsg =
                     ": Update of Archivecop failed - Transfer. (nspArchiveTransfer) " + " ( " +
                     " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
                     ROLLBACK TRAN 
               	END  
                  ELSE
                  BEGIN
                     COMMIT TRAN  
                  END
         			IF (@n_continue = 1 or @n_continue = 2 )
         			BEGIN
                     DECLARE C_Arc_AdjmentLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                     SELECT TransferLineNumber 
                     FROM   TransferDetail (NOLOCK) 
                     WHERE  TransferKey = @cTransferKey 
                     ORDER By TransferLineNumber  
                  
                     OPEN C_Arc_AdjmentLine 
                     
                     FETCH NEXT FROM C_Arc_AdjmentLine INTO @cTransferLineNumber 
                  
                     WHILE @@fetch_status <> -1  
                     BEGIN 
                        begin tran 
            
                        UPDATE TransferDetail WITH (ROWLOCK) 
                           SET Archivecop = '9'
                        WHERE TransferKey = @cTransferKey AND TransferLineNumber = @cTransferLineNumber 
            
                        select @local_n_err = @@error 
                        if @local_n_err <> 0
                        begin 
                           SELECT @n_continue = 3
                           SELECT @local_n_err = 77202
                           SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                           SELECT @local_c_errmsg =
                           ": Update of Archivecop failed - TransferDetail. (nspArchiveTransfer) " + " ( " +
                           " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
                           rollback tran 
                        end  
                        else
                        begin
                           set @n_archive_Tran_detail_records = @n_archive_Tran_detail_records + 1
                           commit tran 
                        end   
                        FETCH NEXT FROM C_Arc_AdjmentLine INTO @cTransferLineNumber
                     END -- while (line)
                     CLOSE C_Arc_AdjmentLine
                     DEALLOCATE C_Arc_AdjmentLine 
                  END -- (@n_continue = 1 or @n_continue = 2 )
                  FETCH NEXT FROM C_Arc_TransferHeader INTO @cTransferKey
               END -- while TransferKey 
               CLOSE C_Arc_TransferHeader
               DEALLOCATE C_Arc_TransferHeader
----------------------
            END
            IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
            BEGIN
               SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_Tran_records )) +
               " Transfer records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_Tran_detail_records )) + " TransferDetail records"
               EXECUTE nspLogAlert
               @c_ModuleName   = "nspArchiveTransfer",
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
               EXEC nsp_BUILD_INSERT   @c_copyto_db, 'TransferDetail',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END

            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 1
               EXEC nsp_BUILD_INSERT  @c_copyto_db, 'Transfer',1,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
               IF not @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
         END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspLogAlert
         @c_ModuleName   = "nspArchiveTransfer",
         @c_AlertMessage = "Archive Of Transfer Ended Normally.",
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
            @c_ModuleName   = "nspArchiveTransfer",
            @c_AlertMessage = "Archive Of Transfer Ended Abnormally - Check This Log For Additional Messages.",
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
      /* #INCLUDE <SPATran2.SQL> */
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveTransfer"
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