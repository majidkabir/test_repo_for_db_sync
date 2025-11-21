SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Proc : ispArchiveTransmitLog3                                 */      
/* Creation Date: 17-Aug-2005                                           */      
/* Copyright: IDS                                                       */      
/* Written by: MaryVong                                                 */      
/*                                                                      */      
/* Purpose: Housekeeping TransmitLog3 table                             */      
/*    Note: Duplicate from ispArchiveTransmitLog2                       */      
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
/* PVCS Version: 1.3                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author     Purposes                                     */      
/* 03-Oct-2005  YokeBeen   Modified the tablename of TransmitLog2 to    */      
/*                         TransmitLog3 - (YokeBeen01)                  */      
/* 2005-Dec-01  Shong      Revise Build Insert SP - Check Duplicate     */      
/*                         - Delete only when records inserted into     */      
/*                           Archive Table.                             */      
/* 14.Sept.2006 June       Include Transmitflag '5'                     */      
/* 14.Feb.2007  TLTING     Include Transmitflag '8'                     */      
/* 09-Nov-2010  TLTING     Commit at line level                         */      
/* 16-Mar-2012  Leong      SOS# 238611 - Include TransmitFlag 'IGNOR'   */     
/* 06-Jan-2021  kocy       remove convert date format column            */   
/* 13-Nov-2022  TLTING01   Archive all TransmitFlag 'IGNOR'             */   
/************************************************************************/      
      
CREATE PROC [dbo].[ispArchiveTransmitLog3]      
     @c_archivekey NVARCHAR(10)      
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
   DECLARE @n_retain_days        int, -- days to hold data      
           @d_result             datetime, -- date (GETDATE() - noofdaystoretain)      
           @c_datetype           NVARCHAR(10), -- 1=EditDate, 2=AddDate      
           @n_archive_TL_records int -- No. of TransmitLog3 records to be archived      
      
   DECLARE @local_n_err    int,      
           @local_c_errmsg NVARCHAR(254)      
      
   DECLARE @c_TransmitFlag              NVARCHAR(2),      
           @c_TLStart                   NVARCHAR(15),      
           @c_TLEnd                     NVARCHAR(15),      
           @c_whereclause               NVARCHAR(254),      
           @c_temp                      NVARCHAR(254),      
           @c_CopyRowsToArchiveDatabase NVARCHAR(1),      
           @c_copyfrom_db               NVARCHAR(30),      
           @c_copyto_db                 NVARCHAR(30),      
           @c_TransmitLogKey            NVARCHAR(10),      
           @d_today                     datetime,
           @c_whereclauseIgnore         NVARCHAR(254) -- TLTING01      
      
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 0,@n_err = 0,@c_errmsg = '',      
          @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ''      
      
   SELECT @n_archive_TL_records = 0      
      
   SELECT @c_copyfrom_db = livedatabasename,      
          @c_copyto_db   = archivedatabasename,      
          @n_retain_days = tranmlognumberofdaystoretain,      
          @c_datetype    = tranmlogdatetype,      
          @c_TLStart     = ISNULL (tranmlogstart,''),      
          @c_TLend       = ISNULL (tranmlogend,'ZZZZZZZZZZ'),      
          @c_CopyRowsToArchiveDatabase = copyrowstoarchivedatabase      
   FROM ArchiveParameters WITH (NOLOCK)      
   WHERE archivekey = @c_archivekey      
      
   IF db_id(@c_copyto_db) IS NULL      
   BEGIN      
      SELECT @n_continue = 3      
      SELECT @local_n_err = 77100      
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)      
      SELECT @local_c_errmsg =      
            ": Target Database " + @c_copyto_db + " Does NOT exist " + " ( " +      
            " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" +' (ispArchiveTransmitLog3) '      
   END      
      
   IF (@n_continue = 1 OR @n_continue = 2)      
   BEGIN      
      SELECT @c_TransmitFlag = '9' -- default only archive those transmitflag = '9'      
      SELECT @d_today = CONVERT(datetime,CONVERT(char(11),GETDATE(),106))      
      SELECT @d_result = DATEADD(DAY,(-@n_retain_days),@d_today)      
      SELECT @d_result = DATEADD(DAY,1,@d_result)      
   END      
      
   IF (@n_continue = 1 OR @n_continue = 2)      
   BEGIN      
      SELECT @b_success = 1      
      SELECT @c_temp = "Archive Of IDS TransmitLog3 Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +      
                        ' ; TransmitFlag = '+ dbo.fnc_RTrim(@c_TransmitFlag)+ ' ; TransmitLogKey = '+dbo.fnc_RTrim(@c_TLStart)+'-'+dbo.fnc_RTrim(@c_TLEnd)+      
                        ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@c_CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ CONVERT(char(6),@n_retain_days)      
      EXECUTE nspLogAlert      
               @c_ModuleName   = "ispArchiveTransmitLog3",      
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
      
   IF (@n_continue = 1 OR @n_continue = 2)      
   BEGIN      
      IF (dbo.fnc_RTrim(@c_TLStart) IS NOT NULL AND dbo.fnc_RTrim(@c_TLEnd) IS NOT NULL)      
      BEGIN      
         SELECT @c_temp = ' AND TransmitLog3.TransmitLogKey BETWEEN '+ '''' + dbo.fnc_RTrim(@c_TLStart) + '''' +' AND '+      
                          ''''+dbo.fnc_RTrim(@c_TLEnd)+''''      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')      
      BEGIN      
         SELECT @b_success = 1      
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'TransmitLog3',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @dummy      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')      
      BEGIN      
         SELECT @b_success = 1      
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'TransmitLog3',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT      
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
      
         EXECUTE nspBuildAlterTableString @c_copyto_db,'TransmitLog3',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')      
      BEGIN      
         IF (@b_debug = 1)      
         BEGIN      
            print "building alter table string for TransmitLog3..."      
         END      
         EXECUTE nspBuildAlterTableString @c_copyto_db,'TransmitLog3',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT      
         IF NOT @b_success = 1      
         BEGIN      
            SELECT @n_continue = 3      
         END      
      END      
      
      IF ((@n_continue = 1 OR @n_continue = 2 ) AND @c_CopyRowsToArchiveDatabase = 'Y')      
      BEGIN      
         IF (@n_continue = 1 OR @n_continue = 2 )      
         BEGIN      
            IF @c_datetype = "1" -- EditDate      
            BEGIN      
               SELECT @c_whereclause = " WHERE TransmitLog3.EditDate  <= " + ''''+ CONVERT(char(8),@d_result,112)+''''   -- kocy    
                                     + " AND (TransmitLog3.Transmitflag IN ('5', '8', '9') ) " + -- SOS# 238611      
                                     + @c_temp      
         END      
         IF @c_datetype = "2" -- AddDate      
         BEGIN      
            SELECT @c_whereclause = " WHERE TransmitLog3.AddDate  <= " + ''''+ CONVERT(char(8),@d_result,112)+''''   -- kocy    
                                  + " AND (TransmitLog3.Transmitflag IN ('5', '8', '9') ) " + -- SOS# 238611      
                                  + @c_temp      
         END      

         -- TLTING01
         SELECT @c_whereclauseIgnore = " WHERE TransmitLog3.TRANSMITFLAG = 'IGNOR' " +      
                                       +  @c_temp   
                                             
         IF (@b_debug = 1)      
         BEGIN      
            SELECT @c_whereclause '@c_whereclause'      
         END      
      
         EXEC (      
               ' DECLARE CUR_TransmitLogkey CURSOR FAST_FORWARD READ_ONLY FOR ' +      
               ' SELECT TransmitLogKey FROM TransmitLog3 (NOLOCK) ' + @c_whereclause +  
               ' UNION ALL SELECT TransmitLogKey FROM TransmitLog3 WITH (NOLOCK) ' + @c_whereclauseIgnore +      -- TLTING01    
               ' ORDER BY TransmitLogKey ' )      
      
         OPEN CUR_TransmitLogkey      
         FETCH NEXT FROM CUR_TransmitLogkey INTO @c_TransmitLogKey      
      
         WHILE @@fetch_status <> -1      
         BEGIN      
            BEGIN TRAN      
            UPDATE TransmitLog3 WITH (ROWLOCK)      
               SET ArchiveCop = '9'      
            WHERE TransmitLogKey = @c_TransmitLogKey      
      
            SELECT @local_n_err = @@error, @n_cnt = @@rowcount      
            SELECT @n_archive_TL_records = @n_archive_TL_records + 1      
      
            IF (@b_debug = 1)      
            BEGIN      
               SELECT @c_TransmitLogKey '@c_TransmitLogKey',  @n_archive_TL_records '@n_archive_TL_records'      
            END      
      
            IF @local_n_err <> 0      
            BEGIN      
               SELECT @n_continue = 3      
               SELECT @local_n_err = 77101      
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)      
               SELECT @local_c_errmsg =      
                        ": Update of Archivecop failed - CC Table. (ispArchiveTransmitLog3) " + " ( " +      
                        " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"      
               ROLLBACK TRAN      
            END      
            ELSE      
            BEGIN      
    COMMIT TRAN      
            END      
            FETCH NEXT FROM CUR_TransmitLogkey INTO @c_TransmitLogKey      
         END -- while TransmitLogKey      
         CLOSE CUR_TransmitLogkey      
         DEALLOCATE CUR_TransmitLogkey      
       END      
      
     IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')      
     BEGIN      
        SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(CONVERT(char(6),@n_archive_TL_records )) +      
        " TransmitLog3 records "      
        EXECUTE nspLogAlert      
                 @c_ModuleName   = "ispArchiveTransmitLog3",      
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
      EXEC nsp_BUILD_INSERT   @c_copyto_db, 'TransmitLog3',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT      
      IF NOT @b_success = 1      
      BEGIN      
         SELECT @n_continue = 3      
      END      
   END      
      
     IF (@b_debug = 1)      
     BEGIN      
        SELECT * FROM TransmitLog3 (NOLOCK)      
        WHERE ArchiveCop = '9'      
     END      
      END      
   END      
      
   IF (@n_continue = 1 OR @n_continue = 2)      
   BEGIN      
      SELECT @b_success = 1      
      EXECUTE nspLogAlert      
               @c_ModuleName   = "ispArchiveTransmitLog3",      
               @c_AlertMessage = "Archive Of TransmitLog3 Ended Normally.",      
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
                  @c_ModuleName   = "ispArchiveTransmitLog3",      
                  @c_AlertMessage = "Archive Of TransmitLog3 Ended Abnormally - Check This Log For Additional Messages.",      
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
   IF @n_continue = 3  -- Error Occured - Process And Return      
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispArchiveTransmitLog3"      
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