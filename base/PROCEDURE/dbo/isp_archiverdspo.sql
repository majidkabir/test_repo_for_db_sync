SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc : isp_ArchiveRdsPO                                       */  
/* Creation Date: 13/07/2009                                            */  
/* Copyright: IDS                                                       */  
/* Written by: TING TUCK LUNG                                           */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By: /                                                         */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/*                                                                      */  
/************************************************************************/  
  
CREATE PROCEDURE    [dbo].[isp_ArchiveRdsPO]  
 @c_archivekey  NVARCHAR(10),  
 @b_Success      int        OUTPUT,  
 @n_err          int        OUTPUT,      
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
      /* #INCLUDE <SPARPO1.SQL> */       
  
 DECLARE @n_retain_days int      , -- days to hold data  
  @d_POdate  datetime     , -- RdsPO Date from PO header table  
  @d_result  datetime     , -- date POdate - (GETDATE() - noofdaystoretain  
  @c_datetype NVARCHAR(10),      -- 1=PODATE, 2=EditDate, 3=AddDate  
  @n_archive_RdsPo_records   int, -- # of rdsPO records to be archived  
  @n_archive_RdsPODetail_records   int, -- # of RdsPO_detail records to be archived  
  @n_archive_RdsPODetail_Size_records   int 
  
 DECLARE @local_n_err         int,  
  @local_c_errmsg    NVARCHAR(254)  
  
 DECLARE        @c_copyfrom_db  NVARCHAR(55),  
  @c_copyto_db    NVARCHAR(55),  
  @c_RdsPoActive NVARCHAR(2),  
  @n_RdsPoStart int,  
  @n_RdsPoEnd int,  
  @c_whereclause NVARCHAR(350),  
  @c_temp NVARCHAR(254),  
  @CopyRowsToArchiveDatabase NVARCHAR(1)  
  
   DECLARE @nRdsPoNo int       
          ,@cRdsPoLineNo NVARCHAR(10)
          ,@cSku     NVARCHAR(30)   
  
 SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',  
 @b_debug = 1, @local_n_err = 0, @local_c_errmsg = ' '  
  
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN -- 1  
  SELECT  @c_copyfrom_db = livedatabasename,  
   @c_copyto_db = archivedatabasename,  
   @n_retain_days = RdsPoNumberofDaysToRetain,  
   @c_datetype = RdsPodatetype,  
   @c_RdsPoActive = RdsPoActive,  
   @n_RdsPoStart = ISNULL(RdsPoStart,0),  
   @n_RdsPoEnd = ISNULL(RdsPoEnd,2147483647),  
   @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase  
  FROM ArchiveParameters (nolock)  
  WHERE archivekey = @c_archivekey  
  
  IF db_id(@c_copyto_db) is NULL  
  BEGIN  
   SELECT @n_continue = 3  
   SELECT @local_n_err = 74101  
   SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
   SELECT @local_c_errmsg =  
    ': Target Database ' + @c_copyto_db + ' Does not exist  ( ' +  
    ' SQLSvr MESSAGE = ' + ISNULL(@local_c_errmsg, '') + ')' +' (isp_ArchiveRdsPO) '  
  END  
  
  SELECT @d_result = DATEADD(DAY,-@n_retain_days,GETDATE())  
  SELECT @d_result = DATEADD(DAY,1,@d_result)  
 END -- 1  

 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
  SELECT @b_success = 1  
  SELECT @c_temp = 'Archive Of RdsPo Started with Parms; Datetype = ' + dbo.fnc_RTrim(@c_datetype) +  
   ' ; Active = '+ dbo.fnc_RTrim(@c_RdsPoActive)+ ' ; RdsPo = '+cast(@n_RdsPoStart as NVARCHAR(20))+'-'+Cast(@n_RdsPoEnd as NVARCHAR(20))+  
   ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) + '; Retain Days = '+ convert(char(6),@n_retain_days)  
  EXECUTE nspLogAlert  
   @c_ModuleName   = 'isp_ArchiveRdsPO',  
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
    
  SELECT @c_temp = 'AND rdsPO.rdsPoNo BETWEEN ' + Cast(@n_RdsPoStart as NVARCHAR(20)) + ' AND '+  
   ' '+Cast(@n_RdsPoEnd as NVARCHAR(20))+''  
  
  IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
  BEGIN   
   select @b_success = 1  

   EXEC nsp_BUILD_ARCHIVE_TABLE   
    @c_copyfrom_db,   
    @c_copyto_db,   
    'rdspo',  
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
    print 'starting Table Existence Check For RdsPo DETAIL...'  
   END  
   SELECT @b_success = 1  

   EXEC nsp_BUILD_ARCHIVE_TABLE   
    @c_copyfrom_db,   
    @c_copyto_db,   
    'rdsPODetail',  
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
    print 'starting Table Existence Check For rdsPODetailSize...'  
   END  
   SELECT @b_success = 1  
   EXEC nsp_BUILD_ARCHIVE_TABLE   
    @c_copyfrom_db,   
    @c_copyto_db,   
    'rdsPODetailSize',  
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
    print 'building alter table string for rdsPO...'  
   END  
   EXECUTE nspBuildAlterTableString   
    @c_copyto_db,  
    'rdsPO',  
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
    print 'building alter table string for rdsPODetail...'  
   END  
   EXECUTE nspBuildAlterTableString   
    @c_copyto_db,  
    'rdsPODetail',  
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
    print 'building alter table string for rdsPODetailSize...'  
   END  
   EXECUTE nspBuildAlterTableString   
    @c_copyto_db,  
    'rdsPODetailSize',  
    @b_success OUTPUT,  
    @n_err OUTPUT,   
    @c_errmsg OUTPUT  
   IF not @b_success = 1  
   BEGIN  
    SELECT @n_continue = 3  
   END  
  END  
  
  
  IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
  BEGIN -- 3  
   IF @c_datetype = '1' -- PODATE  
   BEGIN  
     SELECT @c_whereclause = 'WHERE rdsPO.PODate  <= '''+ convert(char(11),@d_result,106)+'''  and (rdsPO.Status = ''9'' OR rdsPO.Status = ''CANC'' ) ' +  @c_temp  
   END  
   IF @c_datetype = '2' -- EditDate  
   BEGIN  
            SELECT @c_whereclause = 'WHERE rdsPO.EditDate <= '''+ convert(char(11),@d_result,106)+''' and (rdsPO.Status = ''9'' OR rdsPO.Status = ''CANC'' ) ' + @c_temp  
   END  
   IF @c_datetype = '3' -- AddDate  
   BEGIN  
            SELECT @c_whereclause = 'WHERE rdsPO.AddDate <= '''+ convert(char(11),@d_result,106)+''' and (rdsPO.Status = ''9'' OR rdsPO.Status = ''CANC'' ) ' + @c_temp  
   END  
  
         IF (@b_debug = 1)  
         BEGIN     
         Select @c_whereclause
        PRINT 'starting Table Existence Check For rdsPO...'  
         END      
               
         SELECT @n_archive_RdsPo_records = 0  
  
         WHILE @@TRANCOUNT > @n_starttcnt   
            COMMIT TRAN   
  
         EXEC (  
         ' Declare C_RdsPO CURSOR FAST_FORWARD READ_ONLY FOR ' +   
         ' SELECT rdsPONo FROM rdsPO (NOLOCK) ' + @c_WhereClause +   
         ' ORDER BY rdsPONo ' )   
           
   
         OPEN C_RdsPO  
           
         FETCH NEXT FROM C_RdsPO INTO @nRdsPoNo  
           
         WHILE @@fetch_status <> -1  
         BEGIN  
            BEGIN TRAN   

            UPDATE rdsPO WITH (ROWLOCK)  
               SET ArchiveCop = '9'   
            WHERE rdsPONo = @nRdsPoNo    
  
            select @local_n_err = @@error   --, @n_cnt = @@rowcount              
            SELECT @n_archive_RdsPo_records = @n_archive_RdsPo_records + 1              
            IF @local_n_err <> 0  
            BEGIN   
               SELECT @n_continue = 3  
               SELECT @local_n_err = 74102  
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
               SELECT @local_c_errmsg =  
              ': Update of Archivecop failed - rdsPO. (isp_ArchiveRdsPO) ( ' +  
              ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
               ROLLBACK TRAN   
            END    
            ELSE  
            BEGIN  
               COMMIT TRAN    
            END  
  
            FETCH NEXT FROM C_RdsPO INTO @nRdsPoNo  
         END -- while rdsPONo   
  
  
         CLOSE C_RdsPO  
         DEALLOCATE C_RdsPO  
  
     
         IF (@n_continue = 1 or @n_continue = 2)  
         BEGIN   
            WHILE @@TRANCOUNT > @n_starttcnt   
               COMMIT TRAN   
  

            SELECT @n_archive_RdsPODetail_records = 0  
  
            Declare C_RdsPO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT rdsPODetail.rdsPONo, rdsPODetail.rdsPOLineNo   
            FROM rdsPO (nolock)  
            JOIN rdsPODetail (NOLOCK) ON (rdsPODetail.rdsPONo = rdsPO.rdsPONo)  
            WHERE (rdsPO.archivecop = '9')  
            ORDER BY rdsPODetail.rdsPONo, rdsPODetail.rdsPOLineNo          
      
            OPEN C_RdsPO   
              
            FETCH NEXT FROM C_RdsPO INTO @nRdsPoNo, @cRdsPoLineNo   
              
            WHILE @@fetch_status <> -1  
            BEGIN  
               BEGIN TRAN   

               UPDATE rdsPODetail with (RowLock) 
               Set Archivecop = '9'  
               WHERE rdsPONo = @nRdsPoNo    
               AND   RdsPOLineNo = @cRdsPoLineNo  
     
               select @local_n_err = @@error --, @n_cnt = @@rowcount              
                                                  
             IF @local_n_err <> 0  
             BEGIN   
              SELECT @n_continue = 3  
              SELECT @local_n_err = 74103  
              SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
              SELECT @local_c_errmsg =  
               ': Update of Archivecop failed - rdsPODetail. (isp_ArchiveRdsPO)  ( ' +  
               ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
                ROLLBACK TRAN   
               END    
               ELSE  
               BEGIN  
                  select @n_archive_RdsPODetail_records = @n_archive_RdsPODetail_records + 1   
                  COMMIT TRAN    
               END                
  
               FETCH NEXT FROM C_RdsPO INTO @nRdsPoNo, @cRdsPoLineNo  
            END -- while POkey   
     
            CLOSE C_RdsPO  
            DEALLOCATE C_RdsPO  
         END
         IF (@n_continue = 1 or @n_continue = 2)  
         BEGIN   
            WHILE @@TRANCOUNT > @n_starttcnt   
               COMMIT TRAN   
  

            SELECT @n_archive_RdsPODetail_Size_records = 0  
  
            Declare C_RdsPO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT Distinct rdsPODetail.rdsPONo, rdsPODetail.rdsPOLineNo, rdsPODetailSize.Sku   
            FROM rdsPO (nolock)  
            JOIN rdsPODetail (NOLOCK) ON (rdsPODetail.rdsPONo = rdsPO.rdsPONo)  
            JOIN rdsPODetailSize (NOLOCK) ON (rdsPODetailSize.rdsPONo = rdsPODetail.rdsPONo
                                          AND rdsPODetailSize.rdsPoLineNo = rdsPODetail.rdsPoLineNo )
            WHERE (rdsPO.archivecop = '9')  
            ORDER BY rdsPODetail.rdsPONo,  rdsPODetail.rdsPOLineNo, rdsPODetailSize.Sku            
      
            OPEN C_RdsPO   
              
            FETCH NEXT FROM C_RdsPO INTO @nRdsPoNo, @cRdsPoLineNo, @cSku   
              
            WHILE @@fetch_status <> -1  
            BEGIN  
               BEGIN TRAN   

               UPDATE rdsPODetailSize with (RowLock) 
               Set Archivecop = '9'  
               WHERE rdsPONo = @nRdsPoNo    
               AND   RdsPOLineNo = @cRdsPoLineNo  
               AND   SKU = @cSku
     
               select @local_n_err = @@error --, @n_cnt = @@rowcount              
                                                  
             IF @local_n_err <> 0  
             BEGIN   
              SELECT @n_continue = 3  
              SELECT @local_n_err = 74103  
              SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
              SELECT @local_c_errmsg =  
               ': Update of Archivecop failed - rdsPODetail_size. (isp_ArchiveRdsPO) ( ' +  
               ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
                ROLLBACK TRAN   
               END    
               ELSE  
               BEGIN  
                  select @n_archive_RdsPODetail_Size_records = @n_archive_RdsPODetail_Size_records + 1   
                  COMMIT TRAN    
               END                
  
               FETCH NEXT FROM C_RdsPO INTO @nRdsPoNo, @cRdsPoLineNo, @cSku  
            END -- while POkey   
     
            CLOSE C_RdsPO  
            DEALLOCATE C_RdsPO 
         END  

--   END   
     
   IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN  
    SELECT @c_temp = 'Attempting to Archive ' + dbo.fnc_RTrim(convert(varchar(6),@n_archive_RdsPo_records )) +  
     ' rdsPO records and ' + dbo.fnc_RTrim(convert(varchar(6),@n_archive_RdsPODetail_records )) + ' rdsPODetail records' + 
      ' and ' + ISNULL(RTRIM(cast(@n_archive_RdsPODetail_Size_records as NVARCHAR(6))), 0) + ' rdsPODetailSize records ' 
    EXECUTE nspLogAlert  
     @c_ModuleName   = 'isp_ArchiveRdsPO',  
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
     print 'Building INSERT for rdsPODetail...'  
    END  
    SELECT @b_success = 1  
    EXEC nsp_BUILD_INSERT     
     @c_copyto_db,   
     'rdsPODetail',  
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
     print 'Building INSERT for rdsPODetailSize...'  
    END  
    SELECT @b_success = 1  
    EXEC nsp_BUILD_INSERT     
     @c_copyto_db,   
     'rdsPODetailSize',  
     1 ,  
     @b_success OUTPUT,   
     @n_err OUTPUT,   
     @c_errmsg OUTPUT  
    IF not @b_success = 1  
    BEGIN  
     SELECT @n_continue = 3  
    END  
   END  
   
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN   
      WHILE @@TRANCOUNT > @n_starttcnt   
        COMMIT TRAN   
  
      IF @n_continue = 1 or @n_continue = 2  
      BEGIN     
       IF (@b_debug = 1)  
       BEGIN  
        print 'Building INSERT for rdsPO...'  
       END  
       SELECT @b_success = 1  
       EXEC nsp_BUILD_INSERT    
        @c_copyto_db,   
        'rdsPO',  
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
   @c_ModuleName   = 'isp_ArchiveRdsPO',  
   @c_AlertMessage = 'Archive Of rdsPO Ended Normally.',  
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
    @c_ModuleName   = 'isp_ArchiveRdsPO',  
    @c_AlertMessage = 'Archive Of rdsPO Ended Abnormally - Check This Log For Additional Messages.',  
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
  EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ArchiveRdsPO'  
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