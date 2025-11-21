SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc : ispArchiveLotAttribute                                 */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: Wanyt                                                    */  
/*                                                                      */  
/* Purpose: Housekeeping LotAttribute table                             */  
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
/* 11Nov 2015   TLTING        Date filter bug                           */
/************************************************************************/  
  
CREATE PROC [dbo].[ispArchiveLotAttribute]  
     @c_archivekey NVARCHAR(10)  
   , @n_retain_days  INT = 30    
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
   DECLARE @d_result             datetime, -- date (GETDATE() - noofdaystoretain)  
           @c_datetype           NVARCHAR(10), -- 1=EditDate, 2=AddDate  
           @n_archive_TL_records int -- No. of LotAttribute records to be archived  
     
   DECLARE @d_today        datetime             
     
   DECLARE @local_n_err    int,  
           @local_c_errmsg NVARCHAR(254)  
     
   DECLARE @c_TransmitFlag              NVARCHAR(2),  
           @c_TLStart                   NVARCHAR(15),  
           @c_TLEnd                     NVARCHAR(15),  
           @c_whereclause               NVARCHAR(2000),  
           @c_temp                      NVARCHAR(254),  
           @c_CopyRowsToArchiveDatabase NVARCHAR(1),  
           @c_copyfrom_db               NVARCHAR(60),  
           @c_copyto_db                 NVARCHAR(60),  
           @c_whereclause2              NVARCHAR(2000)  
  
   DECLARE @cLotAttributeKey NVARCHAR(10)   -- added by Ong (SOS38267) 10-Aug-2005  
  
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = '',  
          @b_debug = 1, @local_n_err = 0, @local_c_errmsg = ''  
  
   IF @n_retain_days IS NULL OR @n_retain_days < 30  
   BEGIN  
      PRINT 'Please make sure the date cut off is correct! Data retain days must more then 30.'  
      SET @n_continue = 4   
   END   
   /*---------------------------------------------------------------------*/  
   /* 9 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters - START  */  
   /*                  Get parameters FROM archiveparameters instead of   */  
   /*                  hardcode value                                     */  
   /*---------------------------------------------------------------------*/  
  
   SELECT @c_copyfrom_db = ISNULL(RTRIM(livedatabasename),''),  
          @c_copyto_db = ISNULL(RTRIM(archivedatabasename),''),  
          @c_CopyRowsToArchiveDatabase = ISNULL(RTRIM(copyrowstoarchivedatabase),'')   
   FROM ArchiveParameters WITH (NOLOCK)  
   WHERE archivekey = @c_archivekey  
  
   IF db_id(@c_copyto_db) IS NULL  
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @local_n_err = 77100  
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
      SELECT @local_c_errmsg =  
            ': Target Database ' + @c_copyto_db + ' Does NOT exist ' + ' ( ' +  
            ' SQLSvr MESSAGE = ' + ISNULL(RTRIM(@local_c_errmsg),'') + ')' +' (ispArchiveLotAttribute) '  
   END  
  
  
   IF (@n_continue = 1 OR @n_continue = 2)  
   BEGIN  
      SELECT @b_success = 1  
      SELECT @c_temp = 'Archive Of LotAttribute Started with Parms; Copy Rows to Archive = '+  
                       RTRIM(@c_CopyRowsToArchiveDatabase)   
      EXECUTE nspLogAlert  
               @c_ModuleName   = 'ispArchiveLotAttribute',  
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
      IF (RTRIM(@c_TLStart) IS NOT NULL and RTRIM(@c_TLEnd) IS NOT NULL)  
      BEGIN  
         SELECT @c_temp =  ' AND LotAttribute.LotAttributeKey BETWEEN '+ '''' + RTRIM(@c_TLStart) + '''' +' AND '+  
                        ''''+RTRIM(@c_TLEnd)+''''  
      END  
  
      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')  
      BEGIN  
         SELECT @b_success = 1  
         EXEC nsp_Build_Archive_Table @c_copyfrom_db, @c_copyto_db, 'LotAttribute',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @dummy  
            SELECT @n_continue = 3  
         END  
      END  
  
      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')  
      BEGIN  
         SELECT @b_success = 1  
         EXEC nsp_Build_Archive_Table @c_copyfrom_db, @c_copyto_db, 'LotAttribute',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT  
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
  
         EXECUTE nspBuildAlterTableString @c_copyto_db,'LotAttribute',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END  
  
      IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')  
      BEGIN  
         IF (@b_debug = 1)  
         BEGIN  
            PRINT 'building alter table string for LotAttribute...'  
         END  
         EXECUTE nspBuildAlterTableString @c_copyto_db,'LotAttribute',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END  
  
      IF ((@n_continue = 1 OR @n_continue = 2 ) AND @c_CopyRowsToArchiveDatabase = 'Y')  
      BEGIN  
         IF (@n_continue = 1 OR @n_continue = 2 )  
         BEGIN  
             
            SELECT @d_today = CONVERT(datetime,CONVERT(char(11),GETDATE(),112))  
            SELECT @d_result = DATEADD(DAY,(-@n_retain_days),@d_today)  
            SELECT @d_result = DATEADD(DAY,1,@d_result)  
                    
            SELECT @c_whereclause = 'AND LA.Adddate  <= ' + ''''+ CONVERT(nvarchar(11),@d_result,112) +''''  
            SELECT @c_whereclause2 = 'AND I.Adddate  >= ' + ''''+ CONVERT(nvarchar(11),@d_result,112) +''''              
            
            SELECT @n_archive_TL_records = 0  
  
  
         IF (@b_debug = 1)  
         BEGIN  
            PRINT  ' SELECT DISTINCT LA.LOT ' +   
            ' FROM LOTATTRIBUTE AS LA WITH (NOLOCK) ' +  
            ' WHERE LA.ArchiveCop IS NULL ' + 
            ' AND   NOT EXISTS (SELECT 1 FROM LOT AS L WITH (NOLOCK) WHERE L.LOT = LA.Lot) ' +   
            ' AND   NOT EXISTS (SELECT 1 FROM PICKDETAIL AS P WITH (NOLOCK) WHERE P.LOT = LA.Lot) ' +   
            ' AND   NOT EXISTS (SELECT 1 FROM ITRN AS I WITH (NOLOCK) WHERE I.Lot = LA.LOT) ' +                          
            ' AND   NOT EXISTS (SELECT 1 FROM ' + @c_copyto_db + '.dbo.ITRN AS I WITH (NOLOCK) WHERE I.Lot = LA.LOT ' + @c_whereclause2 + ') ' +                 
            ' AND   LA.Editdate < Convert(datetime, Convert(char(10), ( getdate()- 14), 112) ) ' +  
             @c_whereclause +  
            ' ORDER BY LOT '   
         END  
           
           
            EXEC (  
            ' DECLARE CUR_LotAttributekey CURSOR FAST_FORWARD READ_ONLY FOR ' +   
            ' SELECT DISTINCT LA.LOT ' +   
            ' FROM LOTATTRIBUTE AS LA WITH (NOLOCK) ' +  
            ' WHERE LA.ArchiveCop IS NULL ' + 
            ' AND   NOT EXISTS (SELECT 1 FROM LOT AS L WITH (NOLOCK) WHERE L.LOT = LA.Lot) ' +   
            ' AND   NOT EXISTS (SELECT 1 FROM PICKDETAIL AS P WITH (NOLOCK) WHERE P.LOT = LA.Lot) ' +   
            ' AND   NOT EXISTS (SELECT 1 FROM ITRN AS I WITH (NOLOCK) WHERE I.Lot = LA.LOT) ' +                          
            ' AND   NOT EXISTS (SELECT 1 FROM ' + @c_copyto_db + '.dbo.ITRN AS I WITH (NOLOCK) WHERE I.Lot = LA.LOT ' + @c_whereclause2 + ') ' +                 
            ' AND   LA.Editdate < Convert(datetime, Convert(char(10), ( getdate()- 14), 112) ) ' +  
            @c_whereclause +  
            ' ORDER BY LOT ' )  
  
            OPEN CUR_LotAttributekey  
  
            FETCH NEXT FROM CUR_LotAttributekey INTO @cLotAttributeKey  
  
            WHILE @@fetch_status <> -1  
            BEGIN  
               BEGIN TRAN  
               UPDATE LotAttribute WITH (ROWLOCK)  
                  SET ArchiveCop = '9'  
               WHERE LOT = @cLotAttributeKey  
  
               SELECT @local_n_err = @@error, @n_cnt = @@rowcount  
               SELECT @n_archive_TL_records = @n_archive_TL_records + 1  
  
               IF @local_n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @local_n_err = 77101  
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
                  SELECT @local_c_errmsg =  
                  ': Update of Archivecop failed - LotAttribute Table. (ispArchiveLotAttribute) ' + ' ( ' +  
                  ' SQLSvr MESSAGE = ' + ISNULL(RTRIM(@local_c_errmsg),'') + ')'  
                  ROLLBACK TRAN  
               END  
               ELSE  
               BEGIN  
                  COMMIT TRAN  
               END  
  
               FETCH NEXT FROM CUR_LotAttributekey INTO @cLotAttributeKey  
            END -- while LotAttributeKey  
  
            CLOSE CUR_LotAttributekey  
            DEALLOCATE CUR_LotAttributekey  
            /* END (SOS38267) UPDATE*/  
         END  
  
         IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')  
         BEGIN  
            SELECT @c_temp = 'Attempting to Archive ' + RTRIM(CONVERT(varchar(20),@n_archive_TL_records )) +  
                             ' LotAttribute records and ' + RTRIM(CONVERT(varchar(20),@n_archive_TL_records )) + ' LotAttribute records'  
            EXECUTE nspLogAlert  
                     @c_ModuleName   = 'ispArchiveLotAttribute',  
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
         
         ALTER TABLE [dbo].[PICKDETAIL]   NOCHECK CONSTRAINT [FK_PICKDETAIL_LOT_01]
      
         IF (@n_continue = 1 OR @n_continue = 2)  
         BEGIN  
            SELECT @b_success = 1  
            EXEC nsp_Build_Insert  @c_copyto_db, 'LotAttribute',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT  
            IF NOT @b_success = 1  
            BEGIN  
               SELECT @n_continue = 3  
            END  
         END  
         ALTER TABLE [dbo].[PICKDETAIL]   CHECK CONSTRAINT [FK_PICKDETAIL_LOT_01]
      END  
   END  
  
   IF (@n_continue = 1 OR @n_continue = 2)  
   BEGIN  
      SELECT @b_success = 1  
      EXECUTE nspLogAlert  
               @c_ModuleName   = 'ispArchiveLotAttribute',  
               @c_AlertMessage = 'Archive Of LotAttribute Ended Normally.',  
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
                  @c_ModuleName   = 'ispArchiveLotAttribute',  
                  @c_AlertMessage = 'Archive Of LotAttribute Ended Abnormally - Check This Log For Additional Messages.',  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispArchiveLotAttribute'  
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