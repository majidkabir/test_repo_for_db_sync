SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc : isp_ArchiveRdsOrders                                    */  
/* Creation Date: 16/07/2009                                            */  
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
  
CREATE PROCEDURE    [dbo].[isp_ArchiveRdsOrders]  
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
  @d_Ordersdate  datetime     , -- RdsPO Date from PO header table  
  @d_result  datetime     , -- date POdate - (GETDATE() - noofdaystoretain  
  @c_datetype NVARCHAR(10),      -- 1=PODATE, 2=EditDate, 3=AddDate  
  @n_archive_RdsOrders_records   int, -- # of rdsPO records to be archived  
  @n_archive_RdsOrderDetail_records   int, -- # of RdsPO_detail records to be archived  
  @n_archive_RdsOrderDetail_Size_records   int 
  
 DECLARE @local_n_err         int,  
  @local_c_errmsg    NVARCHAR(254)  
  
 DECLARE        @c_copyfrom_db  NVARCHAR(55),  
  @c_copyto_db    NVARCHAR(55),  
  @c_RdsOrdersActive NVARCHAR(2),  
  @n_RdsOrdersStart int,  
  @n_RdsOrdersEnd int,  
  @c_whereclause NVARCHAR(350),  
  @c_temp NVARCHAR(254),  
  @CopyRowsToArchiveDatabase NVARCHAR(1)  
  
   DECLARE @nRdsOrderNo int       
          ,@cRdsOrderLineNo NVARCHAR(10)
          ,@cSku     NVARCHAR(30)   
  
 SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',  
 @b_debug = 1, @local_n_err = 0, @local_c_errmsg = ' '  
  
 IF @n_continue = 1 or @n_continue = 2  
 BEGIN -- 1  
  SELECT  @c_copyfrom_db = livedatabasename,  
   @c_copyto_db = archivedatabasename,  
   @n_retain_days = RdsOrdersNumberofDaysToRetain,  
   @c_datetype = RdsOrdersdatetype,  
   @c_RdsOrdersActive = RdsOrdersActive,  
   @n_RdsOrdersStart = ISNULL(RdsOrdersStart,0),  
   @n_RdsOrdersEnd = ISNULL(RdsOrdersEnd,2147483647),  
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
    ' SQLSvr MESSAGE = ' + ISNULL(@local_c_errmsg, '') + ')' +' (isp_ArchiveRdsOrders) '  
  END  
  
  SELECT @d_result = DATEADD(DAY,-@n_retain_days,GETDATE())  
  SELECT @d_result = DATEADD(DAY,1,@d_result)  
 END -- 1  

 IF @n_continue = 1 or @n_continue = 2  
 BEGIN  
  SELECT @b_success = 1  
  SELECT @c_temp = 'Archive Of RdsOrders Started with Parms; Datetype = ' + dbo.fnc_RTrim(@c_datetype) +  
   ' ; Active = '+ dbo.fnc_RTrim(@c_RdsOrdersActive)+ ' ; RdsOrders = '+cast(@n_RdsOrdersStart as NVARCHAR(20))+'-'+Cast(@n_RdsOrdersEnd as NVARCHAR(20))+  
   ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) + '; Retain Days = '+ convert(char(6),@n_retain_days)  
  EXECUTE nspLogAlert  
   @c_ModuleName   = 'isp_ArchiveRdsOrders',  
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
    
  SELECT @c_temp = 'AND rdsOrders.rdsOrderNo BETWEEN ' + Cast(@n_RdsOrdersStart as NVARCHAR(20)) + ' AND '+  
   ' '+Cast(@n_RdsOrdersEnd as NVARCHAR(20))+''  
  
  IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')  
  BEGIN   
   select @b_success = 1  

   EXEC nsp_BUILD_ARCHIVE_TABLE   
    @c_copyfrom_db,   
    @c_copyto_db,   
    'rdsOrders',  
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
    print 'starting Table Existence Check For rdsOrders DETAIL...'  
   END  
   SELECT @b_success = 1  

   EXEC nsp_BUILD_ARCHIVE_TABLE   
    @c_copyfrom_db,   
    @c_copyto_db,   
    'rdsOrderDetail',  
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
    print 'starting Table Existence Check For rdsOrderDetailSize...'  
   END  
   SELECT @b_success = 1  
   EXEC nsp_BUILD_ARCHIVE_TABLE   
    @c_copyfrom_db,   
    @c_copyto_db,   
    'rdsOrderDetailSize',  
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
    print 'building alter table string for rdsOrders...'  
   END  
   EXECUTE nspBuildAlterTableString   
    @c_copyto_db,  
    'rdsOrders',  
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
    print 'building alter table string for rdsOrderDetail...'  
   END  
   EXECUTE nspBuildAlterTableString   
    @c_copyto_db,  
    'rdsOrderDetail',  
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
    print 'building alter table string for rdsOrderDetailSize...'  
   END  
   EXECUTE nspBuildAlterTableString   
    @c_copyto_db,  
    'rdsOrderDetailSize',  
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
     SELECT @c_whereclause = 'WHERE rdsOrders.OrderDate  <= '''+ convert(char(11),@d_result,106)+'''  and (rdsOrders.Status = ''9'' OR rdsOrders.Status = ''CANC'' ) ' +  @c_temp  
   END  
   IF @c_datetype = '2' -- EditDate  
   BEGIN  
            SELECT @c_whereclause = 'WHERE rdsOrders.EditDate <= '''+ convert(char(11),@d_result,106)+''' and (rdsOrders.Status = ''9'' OR rdsOrders.Status = ''CANC'' ) ' + @c_temp  
   END  
   IF @c_datetype = '3' -- AddDate  
   BEGIN  
            SELECT @c_whereclause = 'WHERE rdsOrders.AddDate <= '''+ convert(char(11),@d_result,106)+''' and (rdsOrders.Status = ''9'' OR rdsOrders.Status = ''CANC'' ) ' + @c_temp  
   END  
  
         IF (@b_debug = 1)  
         BEGIN     
         Select @c_whereclause
        PRINT 'starting Table Existence Check For rdsOrders...'  
         END      
               
         SELECT @n_archive_RdsOrders_records = 0  
  
         WHILE @@TRANCOUNT > @n_starttcnt   
            COMMIT TRAN   
  
         EXEC (  
         ' Declare C_RdsOrders CURSOR FAST_FORWARD READ_ONLY FOR ' +   
         ' SELECT rdsOrderNo FROM rdsOrders (NOLOCK) ' + @c_WhereClause +   
         ' ORDER BY rdsOrderNo ' )   
           
   
         OPEN C_RdsOrders  
           
         FETCH NEXT FROM C_RdsOrders INTO @nRdsOrderNo  
           
         WHILE @@fetch_status <> -1  
         BEGIN  
            BEGIN TRAN   

            UPDATE rdsOrders WITH (ROWLOCK)  
               SET ArchiveCop = '9'   
            WHERE rdsOrderNo = @nRdsOrderNo    
  
            select @local_n_err = @@error   --, @n_cnt = @@rowcount              
            SELECT @n_archive_RdsOrders_records = @n_archive_RdsOrders_records + 1              
            IF @local_n_err <> 0  
            BEGIN   
               SELECT @n_continue = 3  
               SELECT @local_n_err = 74102  
               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
               SELECT @local_c_errmsg =  
              ': Update of Archivecop failed - rdsOrders. (isp_ArchiveRdsOrders) ( ' +  
              ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
               ROLLBACK TRAN   
            END    
            ELSE  
            BEGIN  
               COMMIT TRAN    
            END  
  
            FETCH NEXT FROM C_RdsOrders INTO @nRdsOrderNo  
         END -- while rdsPONo   
  
  
         CLOSE C_RdsOrders  
         DEALLOCATE C_RdsOrders  
  
     
         IF (@n_continue = 1 or @n_continue = 2)  
         BEGIN   
            WHILE @@TRANCOUNT > @n_starttcnt   
               COMMIT TRAN   
  

            SELECT @n_archive_RdsOrderDetail_records = 0  
  
            Declare C_RdsOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT rdsOrderDetail.rdsOrderNo, rdsOrderDetail.rdsOrderLineNo   
            FROM rdsOrders (nolock)  
            JOIN rdsOrderDetail (NOLOCK) ON (rdsOrderDetail.rdsOrderNo = rdsOrders.rdsOrderNo)  
            WHERE (rdsOrders.archivecop = '9')  
            ORDER BY rdsOrderDetail.rdsOrderNo, rdsOrderDetail.rdsOrderLineNo          
      
            OPEN C_RdsOrders   
              
            FETCH NEXT FROM C_RdsOrders INTO @nRdsOrderNo, @cRdsOrderLineNo   
              
            WHILE @@fetch_status <> -1  
            BEGIN  
               BEGIN TRAN   

               UPDATE rdsOrderDetail with (RowLock) 
               Set Archivecop = '9'  
               WHERE rdsOrderNo = @nRdsOrderNo    
               AND   rdsOrderLineNo = @cRdsOrderLineNo  
     
               select @local_n_err = @@error --, @n_cnt = @@rowcount              
                                                  
             IF @local_n_err <> 0  
             BEGIN   
              SELECT @n_continue = 3  
              SELECT @local_n_err = 74103  
              SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
              SELECT @local_c_errmsg =  
               ': Update of Archivecop failed - rdsOrderDetail. (isp_ArchiveRdsOrders)  ( ' +  
               ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
                ROLLBACK TRAN   
               END    
               ELSE  
               BEGIN  
                  select @n_archive_RdsOrderDetail_records = @n_archive_RdsOrderDetail_records + 1   
                  COMMIT TRAN    
               END                
  
               FETCH NEXT FROM C_RdsOrders INTO @nRdsOrderNo, @cRdsOrderLineNo  
            END -- while OrderNo   
     
            CLOSE C_RdsOrders  
            DEALLOCATE C_RdsOrders  
         END
         IF (@n_continue = 1 or @n_continue = 2)  
         BEGIN   
            WHILE @@TRANCOUNT > @n_starttcnt   
               COMMIT TRAN   
  

            SELECT @n_archive_RdsOrderDetail_Size_records = 0  
  
            Declare C_RdsOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT Distinct rdsOrderDetail.rdsOrderNo, rdsOrderDetail.rdsOrderLineNo, rdsOrderDetailSize.Sku   
            FROM rdsOrders (nolock)  
            JOIN rdsOrderDetail (NOLOCK) ON (rdsOrderDetail.rdsOrderNo = rdsOrders.rdsOrderNo)  
            JOIN rdsOrderDetailSize (NOLOCK) ON (rdsOrderDetail.rdsOrderNo = rdsOrderDetailSize.rdsOrderNo
                                 AND rdsOrderDetailSize.rdsOrderLineNo = rdsOrderDetail.rdsOrderLineNo )
            WHERE (rdsOrders.archivecop = '9')  
            ORDER BY rdsOrderDetail.rdsOrderNo,  rdsOrderDetail.rdsOrderLineNo, rdsOrderDetailSize.Sku            
      
            OPEN C_RdsOrders   
              
            FETCH NEXT FROM C_RdsOrders INTO @nRdsOrderNo, @cRdsOrderLineNo, @cSku   
              
            WHILE @@fetch_status <> -1  
            BEGIN  
               BEGIN TRAN   

               UPDATE rdsOrderDetailSize with (RowLock) 
               Set Archivecop = '9'  
               WHERE rdsOrderNo = @nRdsOrderNo    
               AND   rdsOrderLineNo = @cRdsOrderLineNo  
               AND   SKU = @cSku
     
               select @local_n_err = @@error --, @n_cnt = @@rowcount              
                                                  
             IF @local_n_err <> 0  
             BEGIN   
              SELECT @n_continue = 3  
              SELECT @local_n_err = 74103  
              SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
              SELECT @local_c_errmsg =  
               ': Update of Archivecop failed - rdsOrderDetailSize. (isp_ArchiveRdsOrders) ( ' +  
               ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
                ROLLBACK TRAN   
               END    
               ELSE  
               BEGIN  
                  select @n_archive_RdsOrderDetail_Size_records = @n_archive_RdsOrderDetail_Size_records + 1   
                  COMMIT TRAN    
               END                
  
               FETCH NEXT FROM C_RdsOrders INTO @nRdsOrderNo, @cRdsOrderLineNo, @cSku  
            END -- while POkey   
     
            CLOSE C_RdsOrders  
            DEALLOCATE C_RdsOrders 
         END  

--   END   
     
   IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')  
   BEGIN  
    SELECT @c_temp = 'Attempting to Archive ' + dbo.fnc_RTrim(convert(varchar(6),@n_archive_RdsOrders_records )) +  
     ' rdsOrders records and ' + dbo.fnc_RTrim(convert(varchar(6),@n_archive_RdsOrderDetail_records )) + ' rdsOrderDetail records' + 
      ' and ' + ISNULL(RTRIM(cast(@n_archive_RdsOrderDetail_Size_records as NVARCHAR(6))), 0) + ' rdsOrderDetailSize records ' 
    EXECUTE nspLogAlert  
     @c_ModuleName   = 'isp_ArchiveRdsOrders',  
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
     print 'Building INSERT for rdsOrderDetail...'  
    END  
    SELECT @b_success = 1  
    EXEC nsp_BUILD_INSERT     
     @c_copyto_db,   
     'rdsOrderDetail',  
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
     print 'Building INSERT for rdsOrderDetailSize...'  
    END  
    SELECT @b_success = 1  
    EXEC nsp_BUILD_INSERT     
     @c_copyto_db,   
     'rdsOrderDetailSize',  
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
        print 'Building INSERT for rdsOrders...'  
       END  
       SELECT @b_success = 1  
       EXEC nsp_BUILD_INSERT    
        @c_copyto_db,   
        'rdsOrders',  
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
   @c_ModuleName   = 'isp_ArchiveRdsOrders',  
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
    @c_ModuleName   = 'isp_ArchiveRdsOrders',  
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
  EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ArchiveRdsOrders'  
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