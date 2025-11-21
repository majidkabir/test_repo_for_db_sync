SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Proc : nspArchiveReceipt                                            */
/* Creation Date:                                                             */
/* Copyright: IDS                                                             */
/* Written by:                                                                */
/*                                                                            */
/* Purpose:                                                                   */
/*                                                                            */
/* Called By: /                                                               */
/*                                                                            */
/* PVCS Version: 1.9                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author        Purposes                                        */
/* 10-Aug-2005  Ong     SOS38267 Obselete sku & storerkey                     */
/* 21-Oct-2005  June      SOS42269 Include condition ASNStatus = '9'          */
/* 15-Nov-2005  MaryVong      Print statement only when debug turn on         */
/* 28-Nov-2005  Shong         Change Commit Level and Fixing some             */
/*                            Performance Issues.                             */
/* 04-Sep-2018  TLTING        Add archive ReceiptSerialno                     */
/* 15-Aug-2019  kocy          Add archive ReceiptInfo (kocy01)                */
/* 28-Jan-2022  kocy          extend @c_whereclause from length nvarchar(350) */
/*                            to nvarchar(4000) (kocy02)                      */
/******************************************************************************/ 
CREATE PROCEDURE [dbo].[nspArchiveReceipt]  
   @c_archivekey   NVARCHAR(10),  
   @b_Success      int           OUTPUT,  
   @n_err          int           OUTPUT,      
   @c_errmsg       NVARCHAR(250)  OUTPUT      
AS  
BEGIN  -- main  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
 DECLARE @n_continue int        ,    
         @n_starttcnt int        , -- Holds the current transaction count  
         @n_cnt int              , -- Holds @@ROWCOUNT after certain operations  
         @b_debug int             -- Debug On Or Off  
  
 DECLARE @n_retain_days int      , -- days to hold data  
         @d_Receiptdate  datetime     , -- Receipt Date from Receipt header table  
         @d_result  datetime     , -- date Receipt_date - (GETDATE() - noofdaystoretain  
         @c_datetype NVARCHAR(10),      -- 1=ReceiptDATE, 2=EditDate, 3=AddDate  
         @n_archive_Receipt_records   int, -- # of Receipt records to be archived  
         @n_archive_Rcpt_detail_records   int -- # of Receipt_detail records to be archived  
  
 DECLARE @local_n_err         int,  
         @local_c_errmsg    NVARCHAR(254)  
  
 DECLARE @c_copyfrom_db                      NVARCHAR(55),  
         @c_copyto_db                        NVARCHAR(55),  
         @c_ReceiptActive                    NVARCHAR(2),  
         @c_ReceiptStorerKeyStart            NVARCHAR(15),  
         @c_ReceiptStorerKeyEnd              NVARCHAR(15),  
         @c_ReceiptStart                     NVARCHAR(10),  
         @c_ReceiptEnd                       NVARCHAR(10),  
         @c_whereclause                      NVARCHAR(4000),   --kocy02  
         @c_temp                             NVARCHAR(254),  
         @CopyRowsToArchiveDatabase          NVARCHAR(1),  
         @n_archive_ReceiptSerialno_records  INT,  
         @n_archive_ReceiptInfo_records      INT  
  
 DECLARE @cReceiptKey          NVARCHAR(10)   -- added by Ong (SOS38267) 2005-Aug-10    
        ,@cReceiptLineNumber   NVARCHAR(5) -- Added by SHONG (SHONG20051128)  
  
 SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",  
         @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '  
  
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN -- 1  
   SELECT @c_copyfrom_db = livedatabasename,  
          @c_copyto_db = archivedatabasename,  
          @n_retain_days = ReceiptNumberofDaysToRetain,  
          @c_datetype = Receiptdatetype,  
          @c_ReceiptActive = ReceiptActive,  
          @c_ReceiptStorerKeyStart = ISNULL(ReceiptStorerKeyStart,'0'),  
          @c_ReceiptStorerKeyEnd = ISNULL(ReceiptStorerKeyEnd,'ZZZZZZZZZZ'),  
          @c_ReceiptStart = ISNULL(ReceiptStart,'0'),  
          @c_ReceiptEnd = ISNULL(ReceiptEnd,'ZZZZZZZZZZ'),  
          @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase  
   FROM ArchiveParameters (nolock)  
   WHERE archivekey = @c_archivekey  
  
   IF db_id(@c_copyto_db) is NULL  
   BEGIN  
       SELECT @n_continue = 3  
       SELECT @local_n_err = 74101  
       SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
       SELECT @local_c_errmsg = ": Target Database " + @c_copyto_db + " Does not exist " + " ( " +  
                                " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" +' (nspArchiveReceipt) '  
   END  
  
  SELECT @d_result = DATEADD(DAY,-@n_retain_days,GETDATE())  
  SELECT @d_result = DATEADD(DAY,1,@d_result)  
 END -- 1  
  
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
   SELECT @b_success = 1  
   SELECT @c_temp = "Archive Of Receipt Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +  
                     ' ; Active = '+ dbo.fnc_RTrim(@c_ReceiptActive)+ ' ; Storer = '+ dbo.fnc_RTrim(@c_ReceiptStorerKeyStart)+'-'+  
                     dbo.fnc_RTrim(@c_ReceiptStorerKeyEnd) + ' ; Receipt = '+dbo.fnc_RTrim(@c_ReceiptStart)+'-'+dbo.fnc_RTrim(@c_ReceiptEnd)+  
                     ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) + '; Retain Days = '+ convert(char(6),@n_retain_days)  
   EXECUTE nspLogAlert  
            @c_ModuleName   = "nspArchiveReceipt",  
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
   
 IF (@n_continue = 1 or @n_continue = 2)  
 BEGIN -- 2  
   SELECT @c_whereclause = ' '  
   SELECT @c_temp = ' '  
    
    SELECT @c_temp = 'AND Receipt.StorerKey BETWEEN '+ 'N'''+dbo.fnc_RTrim(@c_ReceiptStorerKeyStart) + ''''+ ' AND '+  
                     'N'''+dbo.fnc_RTrim(@c_ReceiptStorerKeyEnd)+''''  
  
   SELECT @c_temp = @c_temp + ' AND Receipt.ReceiptKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_ReceiptStart) + '''' +' AND '+  
                     'N'''+dbo.fnc_RTrim(@c_ReceiptEnd)+''''  
  
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN   
      select @b_success = 1  
      EXEC nsp_BUILD_ARCHIVE_TABLE   
           @c_copyfrom_db,   
           @c_copyto_db,   
           'Receipt',  
           @b_success OUTPUT ,   
           @n_err OUTPUT ,   
           @c_errmsg OUTPUT
           
      IF not @b_success = 1  
      BEGIN  
       SELECT @n_continue = 3  
      END  
   END     
   
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN    
      IF (@b_debug = 1)  
      BEGIN  
       print "starting Table Existence Check For ReceiptDETAIL..."  
      END  
      SELECT @b_success = 1  
      EXEC nsp_BUILD_ARCHIVE_TABLE   
            @c_copyfrom_db,   
            @c_copyto_db,   
            'ReceiptDetail',  
            @b_success OUTPUT ,   
            @n_err OUTPUT,   
            @c_errmsg OUTPUT  
      
      IF not @b_success = 1  
      BEGIN  
       SELECT @n_continue = 3  
      END  
  END       
  
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN    
      IF (@b_debug = 1)  
      BEGIN  
       print "starting Table Existence Check For ReceiptSerialno..."  
      END  
      SELECT @b_success = 1  
      EXEC nsp_BUILD_ARCHIVE_TABLE   
            @c_copyfrom_db,   
            @c_copyto_db,   
            'ReceiptSerialno',  
            @b_success OUTPUT ,   
            @n_err OUTPUT,   
            @c_errmsg OUTPUT  
      
      IF not @b_success = 1  
      BEGIN  
       SELECT @n_continue = 3  
      END  
   END  

   -- kocy01  
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN    
      IF (@b_debug = 1)  
      BEGIN  
       print "starting Table Existence Check For ReceiptInfo..."  
      END  
      SELECT @b_success = 1  
      EXEC nsp_BUILD_ARCHIVE_TABLE   
            @c_copyfrom_db,   
            @c_copyto_db,   
            'ReceiptInfo',  
            @b_success OUTPUT ,   
            @n_err OUTPUT,   
            @c_errmsg OUTPUT  
      
      IF not @b_success = 1  
      BEGIN  
       SELECT @n_continue = 3  
      END  
   END  
   -- kocy01  
         
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN  
      IF (@b_debug = 1)  
      BEGIN  
       print "building alter table string for Receipt..."  
      END  
      EXECUTE nspBuildAlterTableString   
               @c_copyto_db,  
               'Receipt',  
               @b_success OUTPUT,  
               @n_err OUTPUT,   
               @c_errmsg OUTPUT  
      
      IF not @b_success = 1  
      BEGIN  
       SELECT @n_continue = 3  
      END  
   END  
  
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN  
      IF (@b_debug = 1)  
      BEGIN  
       print "building alter table string for Receiptdetail..."  
      END  
      EXECUTE nspBuildAlterTableString   
               @c_copyto_db,  
               'ReceiptDETAIL',  
               @b_success OUTPUT,  
               @n_err OUTPUT,   
               @c_errmsg OUTPUT  
      IF not @b_success = 1  
      BEGIN  
       SELECT @n_continue = 3  
      END  
   END  
  
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN  
      IF (@b_debug = 1)  
      BEGIN  
         print "building alter table string for ReceiptSerialno..."  
      END  
      EXECUTE nspBuildAlterTableString   
               @c_copyto_db,  
               'ReceiptSerialno',  
               @b_success OUTPUT,  
               @n_err OUTPUT,   
               @c_errmsg OUTPUT  
      IF not @b_success = 1  
      BEGIN  
       SELECT @n_continue = 3  
      END  
  END  
  
  --kocy01  
  IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
  BEGIN  
      IF (@b_debug = 1)  
      BEGIN  
       print "building alter table string for ReceiptInfo..."  
      END  
      EXECUTE nspBuildAlterTableString   
               @c_copyto_db,  
               'ReceiptInfo',  
               @b_success OUTPUT,  
               @n_err OUTPUT,   
               @c_errmsg OUTPUT  
      IF not @b_success = 1  
      BEGIN  
       SELECT @n_continue = 3  
      END  
  END  
  --kocy01  
  
  IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
  BEGIN -- 3  
      IF @c_datetype = "1" -- ReceiptDATE  
      BEGIN  
        -- Start : SOS42269  
        -- SELECT @c_whereclause = "WHERE Receipt.ReceiptDate  <= " + '"'+ convert(char(11),@d_result,106)+'"' + " and (Receipt.Status = '9' OR ASNStatus = 'CANC') " +  @c_temp       
        SELECT @c_whereclause = "WHERE Receipt.ReceiptDate  <= " + '"'+ convert(char(10),@d_result,120)+'"' + " and (Receipt.Status = '9' OR ASNStatus = 'CANC' OR ASNStatus = '9') " +  @c_temp  
        -- End : SOS42269  
      END  
      IF @c_datetype = "2" -- EditDate  
      BEGIN  
               -- Start : SOS42269  
               -- SELECT @c_whereclause = "WHERE Receipt.EditDate <= " + '"'+ convert(char(11),@d_result,106)+'"' + " and (Receipt.Status = '9' OR ASNStatus = 'CANC') " + @c_temp  
               SELECT @c_whereclause = "WHERE Receipt.EditDate <= " + '"'+ convert(char(10),@d_result,120)+'"' + " and (Receipt.Status = '9' OR ASNStatus = 'CANC' OR ASNStatus = '9') " + @c_temp  
               -- End : SOS42269  
      END  
      IF @c_datetype = "3" -- AddDate  
      BEGIN  
       -- Start : SOS42269  
               -- SELECT @c_whereclause = "WHERE Receipt.AddDate <= " +'"'+ convert(char(11),@d_result,106)+'"' + " and (Receipt.Status = '9' OR ASNStatus = 'CANC') " + @c_temp  
               SELECT @c_whereclause = "WHERE Receipt.AddDate <= " +'"'+ convert(char(10),@d_result,120)+'"' + " and (Receipt.Status = '9' OR ASNStatus = 'CANC' OR ASNStatus = '9') " + @c_temp  
               -- End : SOS42269  
   END  
  
/* BEGIN (SOS38267) UPDATE*/  
   -- Modified by MaryVong on 15-Nov-2005  
   IF (@b_debug = 1)  
   BEGIN     
      PRINT "starting Table Existence Check For Receipt..."  
   END      
         
   SELECT @n_archive_Receipt_records = 0  
   
   WHILE @@TRANCOUNT > @n_starttcnt   
      COMMIT TRAN   
   
   EXEC (  
   ' Declare C_ReceiptKey CURSOR FAST_FORWARD READ_ONLY FOR ' +   
   ' SELECT ReceiptKey FROM Receipt (NOLOCK) ' + @c_WhereClause +   
   ' ORDER BY ReceiptKey ' )   
     
   
   OPEN C_ReceiptKey  
     
   FETCH NEXT FROM C_ReceiptKey INTO @cReceiptKey  
     
   WHILE @@fetch_status <> -1  
   BEGIN  
      BEGIN TRAN   
   
      UPDATE Receipt WITH (ROWLOCK)  
         SET ArchiveCop = '9'   
      WHERE ReceiptKey = @cReceiptKey    
   
      select @local_n_err = @@error   --, @n_cnt = @@rowcount              
      SELECT @n_archive_Receipt_records = @n_archive_Receipt_records + 1              
      IF @local_n_err <> 0  
      BEGIN   
         SELECT @n_continue = 3  
         SELECT @local_n_err = 74102  
         SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
         SELECT @local_c_errmsg = ": Update of Archivecop failed - Receipt. (nspArchiveReceipt) " + " ( " +  
                                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"  
         ROLLBACK TRAN   
    END    
      ELSE  
      BEGIN  
         COMMIT TRAN    
      END  
   
      FETCH NEXT FROM C_ReceiptKey INTO @cReceiptKey  
   END -- while ReceiptKey   
   
   
   CLOSE C_ReceiptKey  
   DEALLOCATE C_ReceiptKey  
  
     
   IF (@n_continue = 1 or @n_continue = 2)  
   BEGIN   
      WHILE @@TRANCOUNT > @n_starttcnt   
         COMMIT TRAN   
  
      /* BEGIN (SOS38267) UPDATE*/  
            SELECT @n_archive_Rcpt_detail_records = 0  
  
            Declare C_Receiptkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT ReceiptDetail.Receiptkey, ReceiptDetail.ReceiptLineNumber   
            FROM Receipt (nolock)  
            JOIN ReceiptDetail (NOLOCK) ON (ReceiptDetail.Receiptkey = Receipt.Receiptkey)  
            WHERE (Receipt.archivecop = '9')  
            ORDER BY ReceiptDetail.Receiptkey          
      
            OPEN C_Receiptkey   
              
            FETCH NEXT FROM C_Receiptkey INTO @cReceiptkey, @cReceiptLineNumber   
              
            WHILE @@fetch_status <> -1  
            BEGIN  
               BEGIN TRAN   
  
               UPDATE ReceiptDetail  WITH (ROWLOCK)
               Set Archivecop = '9'  
               WHERE Receiptkey = @cReceiptkey    
               AND   ReceiptLineNumber = @cReceiptLineNumber  
     
               select @local_n_err = @@error --, @n_cnt = @@rowcount              
                                                  
               IF @local_n_err <> 0  
               BEGIN   
                  SELECT @n_continue = 3  
                  SELECT @local_n_err = 74103  
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
                  SELECT @local_c_errmsg =  
                   ": Update of Archivecop failed - ReceiptDetail. (nspArchiveReceipt) " + " ( " +  
                   " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"  
                  ROLLBACK TRAN   
               END    
               ELSE  
               BEGIN  
                  select @n_archive_Rcpt_detail_records = @n_archive_Rcpt_detail_records + 1   
                  COMMIT TRAN    
               END        
                    
               BEGIN TRAN  
  
               UPDATE ReceiptSerialno WITH (ROWLOCK) 
                  Set Archivecop = '9'  
               WHERE Receiptkey = @cReceiptkey    
               AND   ReceiptLineNumber = @cReceiptLineNumber  
     
               select @local_n_err = @@error --, @n_cnt = @@rowcount              
                                                  
               IF @local_n_err <> 0  
               BEGIN   
                  SELECT @n_continue = 3  
                  SELECT @local_n_err = 74113  
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
                  SELECT @local_c_errmsg = ": Update of Archivecop failed - ReceiptSerialno. (nspArchiveReceipt) " + " ( " +  
                                           " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"  
                  ROLLBACK TRAN   
               END    
               ELSE  
               BEGIN  
                  select @n_archive_ReceiptSerialno_records = @n_archive_ReceiptSerialno_records + 1   
                  COMMIT TRAN    
               END   
                 
               -- kocy01  
               BEGIN TRAN  
 
               UPDATE ReceiptInfo WITH (ROWLOCK)  
                  Set Archivecop = '9'  
               WHERE Receiptkey = @cReceiptkey    
                        
               select @local_n_err = @@error --, @n_cnt = @@rowcount              
                                                      
                IF @local_n_err <> 0  
                BEGIN   
                   SELECT @n_continue = 3  
                   SELECT @local_n_err = 74113  
                   SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
                   SELECT @local_c_errmsg = ": Update of Archivecop failed - Receipt. (nspArchiveReceipt) " + " ( " +  
                                            " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"  
                   ROLLBACK TRAN   
                END    
                ELSE  
                BEGIN  
                   select @n_archive_ReceiptInfo_records = @n_archive_ReceiptInfo_records + 1   
                   COMMIT TRAN    
                END 
               --kocy01  
  
  
               FETCH NEXT FROM C_Receiptkey INTO @cReceiptkey, @cReceiptLineNumber  
            END -- while Receiptkey   
     
            CLOSE C_Receiptkey  
            DEALLOCATE C_Receiptkey  
  
            /* END (SOS38267) UPDATE*/  
   END   
     
   IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN  
    SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_Receipt_records )) +  
                     " Receipt records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_Rcpt_detail_records )) + " ReceiptDetail records" +  
                     " and " + + dbo.fnc_RTrim(convert(char(6),@n_archive_ReceiptSerialno_records )) + "  ReceiptSerialno records " +  
                     " and " + + dbo.fnc_RTrim(convert(char(6),@n_archive_ReceiptInfo_records )) + "  ReceiptInfo records "  
    EXECUTE nspLogAlert  
            @c_ModuleName   = "nspArchiveReceipt",  
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
  
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN   
    IF (@b_debug = 1)  
    BEGIN  
     print "Building INSERT for ReceiptDETAIL..."  
    END  
    SELECT @b_success = 1  
    EXEC nsp_BUILD_INSERT     
         @c_copyto_db,   
         'RECEIPTDETAIL',  
         1 ,  
         @b_success OUTPUT,   
         @n_err OUTPUT,   
         @c_errmsg OUTPUT  

    IF not @b_success = 1  
    BEGIN  
     SELECT @n_continue = 3  
    END  
   END  
   
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN   
    IF (@b_debug = 1)  
    BEGIN  
     print "Building INSERT for ReceiptSerialno..."  
    END  
    SELECT @b_success = 1  
    EXEC nsp_BUILD_INSERT     
         @c_copyto_db,   
         'ReceiptSerialno',  
         1 ,  
         @b_success OUTPUT,   
         @n_err OUTPUT,   
         @c_errmsg OUTPUT
         
    IF not @b_success = 1  
    BEGIN  
     SELECT @n_continue = 3  
    END  
   END  
  
    --kocy01  
   IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN   
    IF (@b_debug = 1)  
    BEGIN  
     print "Building INSERT for ReceiptInfo..."  
    END  
    SELECT @b_success = 1  
    EXEC nsp_BUILD_INSERT     
         @c_copyto_db,   
         'ReceiptInfo',  
         1 ,  
         @b_success OUTPUT,   
         @n_err OUTPUT,   
         @c_errmsg OUTPUT
         
    IF not @b_success = 1  
    BEGIN  
     SELECT @n_continue = 3  
    END  
   END  
   --kocy01  
  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN   
      WHILE @@TRANCOUNT > @n_starttcnt   
         COMMIT TRAN   
  
      IF @n_continue = 1 or @n_continue = 2  
      BEGIN     
       IF (@b_debug = 1)  
       BEGIN  
         print "Building INSERT for Receipt..."  
       END  
       SELECT @b_success = 1  
       EXEC nsp_BUILD_INSERT    
            @c_copyto_db,   
            'RECEIPT',  
            1,  
            @b_success OUTPUT ,   
            @n_err OUTPUT,   
            @c_errmsg OUTPUT  

       IF not @b_success = 1  
       BEGIN  
        SELECT @n_continue = 3  
       END  
      END         
   END 
   
  END -- 3  
 END -- 2  
   
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
   SELECT @b_success = 1  
   EXECUTE nspLogAlert  
            @c_ModuleName   = "nspArchiveReceipt",  
            @c_AlertMessage = "Archive Of Receipt Ended Normally.",  
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
                 @c_ModuleName   = "nspArchiveReceipt",  
                 @c_AlertMessage = "Archive Of Receipt Ended Abnormally - Check This Log For Additional Messages.",  
                 @n_Severity     = 0,  
                 @b_success       = @b_success OUTPUT ,  
                 @n_err          = @n_err OUTPUT,  
                 @c_errmsg       = @c_errmsg OUTPUT  
      
      IF NOT @b_success = 1  
      BEGIN  
         SELECT @n_continue = 3  
      END  
   END  
 END  
  
      /* #INCLUDE <SPARReceipt2.SQL> */       
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveReceipt"  
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
END -- main  

GO