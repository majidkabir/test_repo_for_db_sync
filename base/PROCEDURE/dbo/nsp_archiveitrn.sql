SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc : nsp_ArchiveITRN                                        */  
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
/* PVCS Version: 1.15                                                   */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* 18-Aug-2005  Shong      CONVERT Bug Update to Cursor loop            */  
/* 24-Aug-2005  YokeBeen   - SQL2K Upgrading Project-V6.0.              */  
/*                           Changed double quote to single quote.      */  
/*                           Added dbo. for all the EXECUTE statement.  */  
/*                           - (YokeBeen01).                            */  
/* 13-Dec-2005  Shong      Capture proper error message when failed     */  
/* 04-May-2007  Shong      Commit Transaction by Line Level             */  
/* 07-Jan-2010  Vicky      Archive LotxLocxID should also look at       */  
/*                         PendingMoveIn QTY (Vicky01)                  */  
/* 31-May-2010  TLTING     LOT check on PendingMoveIn (tlting01)        */
/* 30-Jul-2010  TLTING     DELETE lot when lotxlocxid delete            */  
/* 12-Oct-2011  TLTING01   check pickdetail when lotxlocxid delete      */  
/* 07-Dec-2011  TLTING01   IF E1 storer delete all lli is 0             */
/* 24-Sep-2014  TLTING02   not to disable Pickdetail Constraint         */
/* 03-May-2017  TLTING03   Filter editdate                              */
/* 29-Jun-2017  TLTING04   Add parameter to skip Pickdetail check in    */
/*                          Lotxlocxid housekeep                        */
/* 21-Jul-2020  TLTING05   Add ITRNUCC                                  */
/************************************************************************/  
  
CREATE PROC    [dbo].[nsp_ArchiveITRN]  
 @c_archivekey  NVARCHAR(10),  
 @b_Success      int        OUTPUT,      
 @n_err          int        OUTPUT,     
 @c_errmsg       NVARCHAR(250)  OUTPUT,
  @c_SkipPDCheck  INT = 0      -- tlting04
AS  
/*-------------------------------------------------------------  
THIS WILL ALSO PURGE RECORDS IN THE FF TABLES IF ALL QTY = 0  
  LOT  
  LOTxLOCxID  
  SKUXLOC  
  ID  
---------------------------------------------------------------*/  
BEGIN    
   /* BEGIN 2005-Aug-18 (SOS38267) */  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   /* END 2005-Aug-18 (SOS38267) */  
     
 DECLARE @n_continue int        ,    
    @n_StartTCnt int        , -- Holds the current transaction count  
    @n_cnt int              , -- Holds @@ROWCOUNT after certain operations  
    @b_debug int             -- Debug On OR Off  
      
 /* #INCLUDE <SPARPO1.SQL> */       
 DECLARE @n_retain_days int      , -- days to hold data  
    @d_Itrndate  DATETIME     , -- Itrn Date FROM Itrn header table  
    @d_result  DATETIME     , -- date Itrn_date - (GETDATE() - noofdaystoretain  
    @c_datetype NVARCHAR(10),      -- 1=ItrnDATE, 2=EditDate, 3=AddDate  
    @n_archive_Itrn_records   int, -- # of Itrn records to be archived  
    @n_archive_ItrnUCC_records   int -- # of Itrn records to be archived  
  
 DECLARE @c_CopyFrom_DB NVARCHAR(55),  
    @c_CopyTo_DB NVARCHAR(55),  
    @c_ItrnActive NVARCHAR(2),  
    @c_ItrnStorerKeyStart NVARCHAR(15),  
    @c_ItrnStorerKeyEnd NVARCHAR(15),  
    @c_ItrnSkuStart NVARCHAR(20),  
    @c_ItrnSkuEnd NVARCHAR(20),  
    @c_ItrnLotStart NVARCHAR(10),  
    @c_ItrnLotEnd NVARCHAR(10),  
    @c_WHEREClause NVARCHAR(254),  
    @c_temp NVARCHAR(254),  
    @CopyRowsToArchiveDatabase NVARCHAR(1)  
  
 DECLARE @d_cutoffdate DATETIME,  
     @local_n_err int,  
     @local_c_errmsg NVARCHAR(254),
     @c_SQLStmt      Nvarchar(4000)  
   
 SELECT @n_StartTCnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='',  
          @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '  
  
 SELECT @c_CopyFrom_DB = dbo.fnc_RTrim(LiveDataBaseName),  
    @c_CopyTo_DB = dbo.fnc_RTrim(ArchiveDataBaseName),  
    @n_retain_days = ItrnNumberofDaysToRetain,  
    @c_datetype = Itrndatetype,  
    @c_ItrnActive = ItrnActive,  
    @c_ItrnStorerKeyStart = ItrnStorerKeyStart,  
    @c_ItrnStorerKeyEnd = ItrnStorerKeyEnd,  
    @c_ItrnSkuStart = ItrnSkuStart,  
    @c_ItrnSkuEnd = ItrnSkuEnd,  
    @c_ItrnLotStart = ItrnLotStart,  
    @c_ItrnLotEnd = ItrnLotEnd,  
    @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase  
   FROM ArchiveParameters WITH (NOLOCK)  
  WHERE archivekey = @c_archivekey  
   
 IF db_id(@c_CopyTo_DB) IS NULL OR db_id(@c_CopyTo_DB) = ''  -- (YokeBeen01)  
 BEGIN  
  SELECT @n_continue = 3  
  SELECT @local_n_err = 74001  
  SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
   + ': Target Database ' + @c_CopyTo_DB + ' Does not exist ' + ' ( ' +  
   ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')' + ' (nsp_ArchiveITRN)'  
 END  
  
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ItrnStorerKeyEnd)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ItrnStorerKeyEnd)) = ''  -- (YokeBeen01)  
 BEGIN  
  SELECT @c_ItrnStorerKeyEnd = @c_ItrnStorerKeyStart  
 END  
   
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ItrnSkuEnd)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ItrnSkuEnd)) = ''  -- (YokeBeen01)  
 BEGIN  
  SELECT @c_ItrnSkuEnd = @c_ItrnSkuStart  
 END  
   
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ItrnLotEnd)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ItrnLotEnd)) = ''  -- (YokeBeen01)  
 BEGIN  
  SELECT @c_ItrnLotEnd = @c_ItrnLotStart  
 END  
  
 DECLARE @d_today DATETIME  
 SELECT @d_today = CONVERT(DATETIME,CONVERT(CHAR(11),GETDATE(),106))  
 SELECT @d_cutoffdate = DATEADD(DAY, (-@n_retain_days + 1), @d_today)  
   
   
 IF (@b_debug =1 )  
 BEGIN  
  SELECT  '@n_retain_days = ',  @n_retain_days  
  SELECT  '@c_datetype = ', @c_datetype  
  SELECT  '@c_ItrnActive =', @c_ItrnActive  
  SELECT  'StKey =', @c_ItrnStorerKeyStart  
  SELECT  @c_ItrnStorerKeyEnd  
  SELECT  'SkuKey =', @c_ItrnSkuStart  
  SELECT  @c_ItrnSkuEnd  
  SELECT  'LotKey =', @c_ItrnLotStart  
  SELECT  @c_ItrnLotEnd  
  SELECT  'copy rows to arch database',  @CopyRowsToArchiveDatabase  
  SELECT @d_cutoffdate  
 END  
   
   WHILE @@TRANCOUNT > 0   
      COMMIT TRAN  
  
   BEGIN TRAN         
 IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'Y')  
 BEGIN  
  SELECT @b_success = 1  
  EXEC dbo.nsp_BUILD_ARCHIVE_TABLE  -- (YokeBeen01)  
   @c_CopyFrom_DB,   
   @c_CopyTo_DB,   
   'ITRN',  
   @b_success OUTPUT,   
   @n_err OUTPUT,  
   @c_errmsg OUTPUT  
     
  IF @b_success <> 1  
  BEGIN  
   SELECT @n_continue = 3  
   SELECT @local_n_err = 77303  
   SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
   SELECT @local_c_errmsg = ': Execution of nsp_BUILD_ARCHIVE_TABLE failed - (nsp_ArchiveITRN) ' + ' ( ' +  
       ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'     
  END  
 END  
   WHILE @@TRANCOUNT > 0   
      COMMIT TRAN  
  
  
  -- TLTING05
  BEGIN TRAN         
  IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'Y')  
  BEGIN  
  SELECT @b_success = 1  
  EXEC dbo.nsp_BUILD_ARCHIVE_TABLE  -- (YokeBeen01)  
   @c_CopyFrom_DB,   
   @c_CopyTo_DB,   
   'ItrnUCC',  
   @b_success OUTPUT,   
   @n_err OUTPUT,  
   @c_errmsg OUTPUT  
     
  IF @b_success <> 1  
  BEGIN  
   SELECT @n_continue = 3  
   SELECT @local_n_err = 77303  
   SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
   SELECT @local_c_errmsg = ': Execution of nsp_BUILD_ARCHIVE_TABLE failed - (nsp_ArchiveITRN) ' + ' ( ' +  
       ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'     
  END  
 END  
   WHILE @@TRANCOUNT > 0   
      COMMIT TRAN  
      
  
   BEGIN TRAN  
 IF ((@n_continue = 1 OR @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')  
 BEGIN  
  IF (@b_debug =1 )  
  BEGIN  
   PRINT 'building alter table string for ITRN...'  
  END  
  
  EXECUTE dbo.nspBuildAlterTableString  -- (YokeBeen01)  
   @c_CopyTo_DB,  
   'ITRN',  
   @b_success output,  
   @n_err output,   
   @c_errmsg output  
  
  IF NOT @b_success = 1  
  BEGIN  
   SELECT @n_continue = 3  
   SELECT @local_n_err = 77303  
   SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
   SELECT @local_c_errmsg = ': Execution of nspBuildAlterTableString failed - (nsp_ArchiveITRN) ' + ' ( ' +  
       ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'   
  END  
 END  
   WHILE @@TRANCOUNT > 0   
      COMMIT TRAN  


 -- TLTING05      
 BEGIN TRAN  
 IF ((@n_continue = 1 OR @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')  
 BEGIN  
  IF (@b_debug =1 )  
  BEGIN  
   PRINT 'building alter table string for ItrnUCC...'  
  END  
  
  EXECUTE dbo.nspBuildAlterTableString  -- (YokeBeen01)  
   @c_CopyTo_DB,  
   'ItrnUCC',  
   @b_success output,  
   @n_err output,   
   @c_errmsg output  
  
  IF NOT @b_success = 1  
  BEGIN  
   SELECT @n_continue = 3  
   SELECT @local_n_err = 77303  
   SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
   SELECT @local_c_errmsg = ': Execution of nspBuildAlterTableString failed - (nsp_ArchiveITRN) ' + ' ( ' +  
       ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'   
  END  
 END  
   WHILE @@TRANCOUNT > 0   
      COMMIT TRAN  
              
 DECLARE @cItrnKey  NVARCHAR(10)  
  SET @n_archive_Itrn_records  = 0  
  SET @n_archive_ItrnUCC_records  = 0  
 IF (@n_continue = 1 OR @n_continue = 2)  
 BEGIN  
      SET @n_archive_Itrn_records = 0   
  
    DECLARE C_ARC_ITRNKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT ItrnKey  
      FROM ITRN (NOLOCK)   
   WHERE StorerKey BETWEEN @c_ItrnStorerKeyStart AND @c_ItrnStorerKeyEnd  
     AND Sku BETWEEN @c_ItrnSkuStart AND @c_ItrnSkuEnd  
     AND Lot BETWEEN @c_ItrnLotStart AND @c_ItrnLotEnd  
     AND editdate <= @d_cutoffdate   
     AND (archivecop IS NULL OR archivecop = '' OR archivecop < '9') -- (Yokebeen01)  
     AND not EXISTS ( SELECT 1 from ITRNKey (NOLOCK) 
                  WHERE ITRNKey.ITRNKey = ITRN.ItrnKey 
                  AND ITRNKey.Adddate > DATEADD(hour, -1, getdate()) )
     
     
    OPEN C_ARC_ITRNKEY   
      
    FETCH NEXT FROM C_ARC_ITRNKEY INTO @cItrnKey  
      
    WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)  
    BEGIN  
      
      -- TLTING05
       IF exists ( Select 1 from ItrnUCC (NOLOCK) Where  ItrnKey = @cItrnKey )
       BEGIN 
      
          BEGIN TRAN   
          UPDATE ItrnUCC WITH (ROWLOCK)   
               SET ArchiveCop = '9'   
          WHERE ItrnKey = @cItrnKey   
         
           IF @@error <> 0  
           BEGIN   
            SELECT @n_continue = 3  
            SELECT @local_n_err = 77313  
            SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
            SELECT @local_c_errmsg = ': Update of Archivecop failed - ItrnUCC. (nsp_ArchiveITRN) ' + ' ( ' +  
                ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
               ROLLBACK   
               GOTO QUIT   
           END  
           ELSE   
              COMMIT TRAN  
          
           SET @n_archive_ItrnUCC_records = @n_archive_ItrnUCC_records + 1  
       END
             
       BEGIN TRAN   
            
       UPDATE ITRN WITH (ROWLOCK)   
            SET ArchiveCop = '9'   
       WHERE ItrnKey = @cItrnKey   
         
     IF @@error <> 0  
     BEGIN   
      SELECT @n_continue = 3  
      SELECT @local_n_err = 77303  
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)  
      SELECT @local_c_errmsg = ': Update of Archivecop failed - ITRN. (nsp_ArchiveITRN) ' + ' ( ' +  
          ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
         ROLLBACK   
         GOTO QUIT   
     END  
     ELSE   
        COMMIT TRAN  
          
     SET @n_archive_Itrn_records = @n_archive_Itrn_records + 1  
  
       FETCH NEXT FROM C_ARC_ITRNKEY INTO @cItrnKey  
    END  
      CLOSE C_ARC_ITRNKEY  
      DEALLOCATE C_ARC_ITRNKEY  
 END   
    
  
   if ((@n_continue = 1 or @n_continue = 2)  and @copyrowstoarchivedatabase = 'y')  
   begin  
      select @c_temp = 'attempting to archive ' + dbo.fnc_RTrim(convert(char(6),@n_archive_Itrn_records )) +  
         ' ITRN records, archive '  + RTrim(convert(nvarchar(10),@n_archive_ItrnUCC_records )) +
          ' ITRNUCC records '
      execute dbo.nsplogalert  
         @c_modulename   = 'nsp_ArchiveITRN',  
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
  
 IF (@n_continue = 1 OR @n_continue = 2)  
 BEGIN  
    DECLARE @cStorerKey NVARCHAR(15),   
            @cSKU       NVARCHAR(20),   
            @nArchiveQty int  
              
      DECLARE C_UPD_SKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
  SELECT storerkey, sku, SUM(qty) AS archiveqty  
    FROM itrn (NOLOCK)  
   WHERE archivecop = '9'  
     AND trantype <> 'MV' AND sourcetype <> 'V5_LOADING'  
   GROUP BY storerkey, sku  
  
      OPEN C_UPD_SKU  
        
      FETCH NEXT FROM C_UPD_SKU INTO @cStorerKey, @cSKU, @nArchiveQty   
        
      WHILE @@fetch_status <> -1 AND (@n_continue = 1 OR @n_continue = 2)   
      BEGIN  
     UPDATE SKU WITH (ROWLOCK)  
        SET archiveqty =  CONVERT(VARCHAR(30), (ISNULL(s.archiveqty, 0) + @nArchiveQty))  
       FROM sku s    
      WHERE s.storerkey = @cStorerKey  
        AND s.sku = @cSKU  
     
     IF @@error <> 0  
     BEGIN   
      SELECT @n_continue = 3  
      SELECT @local_n_err = 77303  
      SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
      SELECT @local_c_errmsg = ': Update of ArchiveQty failed - SKU. (nsp_ArchiveITRN) ' + ' ( ' +  
          ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
     END   
       
     FETCH NEXT FROM C_UPD_SKU INTO @cStorerKey, @cSKU, @nArchiveQty    
    END   
    CLOSE C_UPD_SKU  
    DEALLOCATE C_UPD_SKU  
 END  



 -- TLTING05
IF ((@n_continue = 1 OR @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')  
 BEGIN     
  IF (@b_debug =1 )  
  BEGIN  
   PRINT 'building insert for ITRNUCC ...'  
  END  
  
  SELECT @b_success = 1  
  EXEC dbo.nsp_build_insert  -- (YokeBeen01)  
   @c_CopyTo_DB,   
   'ITRNUCC',  
   1,  
   @b_success output ,   
   @n_err output,   
   @c_errmsg output  
  
  IF NOT @b_success = 1  
  BEGIN  
   SELECT @n_continue = 3  
   SELECT @local_n_err = 77315  
   SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
   SELECT @local_c_errmsg = ': Execution of nsp_build_insert failed - ITRNUCC. (nsp_ArchiveITRN) ' + ' ( ' +  
       ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
  END  
 END  
    
 IF ((@n_continue = 1 OR @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')  
 BEGIN     
  IF (@b_debug =1 )  
  BEGIN  
   PRINT 'building insert for ITRN...'  
  END  
  
  SELECT @b_success = 1  
  EXEC dbo.nsp_build_insert  -- (YokeBeen01)  
   @c_CopyTo_DB,   
   'ITRN',  
   1,  
   @b_success output ,   
   @n_err output,   
   @c_errmsg output  
  
  IF NOT @b_success = 1  
  BEGIN  
   SELECT @n_continue = 3  
   SELECT @local_n_err = 77303  
   SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
   SELECT @local_c_errmsg = ': Execution of nsp_build_insert failed - ITRN. (nsp_ArchiveITRN) ' + ' ( ' +  
       ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
  END  
 END  
  
 IF @n_continue = 1 OR @n_continue = 2  
 BEGIN  
  BEGIN TRAN  
            
      DECLARE @cLOT NVARCHAR(10),  
            @cLOC NVARCHAR(10),  
            @cID  NVARCHAR(18)   
  
  IF @n_continue = 1 OR @n_continue = 2  
  BEGIN  
  
  	  IF CURSOR_STATUS('global' , 'C_ARC_LOTxLOCxID') in (0 , 1)  
	  BEGIN  
		  CLOSE C_ARC_LOTxLOCxID  
		  DEALLOCATE C_ARC_LOTxLOCxID     
	  END  
       
      SET @c_SQLStmt = ''
     IF @c_SkipPDCheck = '1'
     BEGIN
     
    -- TLTING02
         ALTER TABLE PICKDETAIL NOCHECK CONSTRAINT ALL  
     
         SET @c_SQLStmt = 'DECLARE C_ARC_LOTxLOCxID CURSOR FAST_FORWARD READ_ONLY FOR ' + 
                        ' SELECT LOT, LOC, ID ' +
                        ' FROM LOTxLOCxID WITH (NOLOCK) ' +
                        ' WHERE Qty = 0 ' +  
                        ' AND QtyAllocated = 0 ' +  
                        ' AND QtyPicked = 0 ' +  
                        ' AND PendingMoveIn = 0 ' 
     END
     ELSE
     BEGIN
         SET @c_SQLStmt = 'DECLARE C_ARC_LOTxLOCxID CURSOR FAST_FORWARD READ_ONLY FOR ' + 
                        ' SELECT LOT, LOC, ID ' +
                        ' FROM LOTxLOCxID WITH (NOLOCK) ' +
                        ' WHERE Qty = 0 ' +  
                        ' AND QtyAllocated = 0 ' +  
                        ' AND QtyPicked = 0 ' +  
                        ' AND PendingMoveIn = 0 '  +  
                        ' AND NOT EXISTS ( SELECT 1 FROM PICKDETAIL PD with (NOLOCK) ' + 		-- tlting01
								' WHERE  PD.LOT =   LOTxLOCxID.LOT  ) '                           
      
     END 
        
     EXEC (@c_SQLStmt)
     
     
--     DECLARE C_ARC_LOTxLOCxID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
--       SELECT LOT, LOC, ID   
--        FROM LOTxLOCxID WITH (NOLOCK)  
--       WHERE Qty = 0  
--         AND QtyAllocated = 0  
--         AND QtyPicked = 0  
--         AND PendingMoveIn = 0 -- (Vicky01)  
----         AND NOT EXISTS ( SELECT 1 FROM PICKDETAIL PD with (NOLOCK) 		-- tlting01
----                              LEFT JOIN ( SELECT DISTINCT StorerKey FROM StorerConfig SC (NOLOCK) 
----                                 WHERE SC.ConfigKey = 'OWITF' AND SC.svalue= '1' ) As TSC ON TSC.Storerkey = PD.storerkey 
----												WHERE  PD.LOT =   LOTxLOCxID.LOT 
----												AND TSC.StorerKey IS NULL) 
---- TLTING02
--         AND NOT EXISTS ( SELECT 1 FROM PICKDETAIL PD with (NOLOCK) 		-- tlting01
--												WHERE  PD.LOT =   LOTxLOCxID.LOT  ) 
												       
     OPEN C_ARC_LOTxLOCxID    
       
     FETCH NEXT FROM C_ARC_LOTxLOCxID INTO @cLOT, @cLOC, @cID   
       
     WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 OR @n_continue = 2 )  
     BEGIN  
        BEGIN TRAN   
             
        DELETE LOTxLOCxID   
         WHERE LOT = @cLOT  
           AND LOC = @cLOC  
           AND ID  = @cID  
          
        IF @@error <> 0   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @local_n_err = 77303  
               SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
               SELECT @local_c_errmsg = ': Deleting LOTxLOCxID failed (nsp_ArchiveITRN) ' + ' ( ' +  
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
            ROLLBACK  
            GOTO QUIT  
            END   
            ELSE  
            BEGIN  
               WHILE @@TRANCOUNT > 0  
                  COMMIT TRAN   
            END   
          
        IF (@n_continue = 1 OR @n_continue = 2)  
        BEGIN  
           IF NOT EXISTS(SELECT ID FROM LOTxLOCxID (NOLOCK) WHERE LOTxLOCxID.ID = @cID)  
           BEGIN  
              BEGIN TRAN   
                   
              DELETE ID WHERE ID = @cID   
              IF @@error <> 0   
              BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @local_n_err = 77303  
                  SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
                  SELECT @local_c_errmsg = ': Deleting ID failed (nsp_ArchiveITRN) ' + ' ( ' +  
                   ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
                  ROLLBACK  
                  GOTO QUIT                   
              END   
                  ELSE  
                  BEGIN  
                     WHILE @@TRANCOUNT > 0  
                        COMMIT TRAN   
                  END                 
           END  
          END   
           
        FETCH NEXT FROM C_ARC_LOTxLOCxID INTO @cLOT, @cLOC, @cID   
     END -- WHILE  
      
     CLOSE C_ARC_LOTxLOCxID  
     DEALLOCATE C_ARC_LOTxLOCxID   
    END  
     
    ALTER TABLE PICKDETAIL CHECK CONSTRAINT ALL  
              
  IF @n_continue = 1 OR @n_continue = 2  
  BEGIN  
       
     DECLARE C_ARC_SKUxLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
     SELECT StorerKey, SKU, LOC    
       FROM SKUxLOC (NOLOCK)  
      WHERE Qty = 0  
        AND QtyAllocated = 0  
        AND QtyPicked = 0  
        AND LocationType NOT IN ('PICK','CASE')  
       
     OPEN C_ARC_SKUxLOC    
       
     FETCH NEXT FROM C_ARC_SKUxLOC INTO @cStorerKey, @cSKU, @cLOC   
       
     WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 OR @n_continue = 2 )  
     BEGIN  
        BEGIN TRAN   
             
        DELETE SKUxLOC   
         WHERE StorerKey = @cStorerKey  
           AND SKU = @cSKU  
           AND LOC = @cLOC  
          
        IF @@error <> 0   
            BEGIN   
               SELECT @n_continue = 3  
         SELECT @local_n_err = 77303  
         SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
         SELECT @local_c_errmsg = ': Deleting SKUxLOC failed (nsp_ArchiveITRN) ' + ' ( ' +  
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
            ROLLBACK  
            GOTO QUIT                   
        END   
            ELSE  
            BEGIN  
               WHILE @@TRANCOUNT > 0  
                  COMMIT TRAN   
            END                     
          
        FETCH NEXT FROM C_ARC_SKUxLOC INTO @cStorerKey, @cSKU, @cLOC   
     END -- WHILE  
     CLOSE C_ARC_SKUxLOC  
     DEALLOCATE C_ARC_SKUxLOC   
      END  
  
  IF @n_continue = 1 OR @n_continue = 2  
  BEGIN  
     DELETE LOTxBillDate  
      WHERE qtybilledbalance = 0  
  
     IF @@error <> 0   
         BEGIN   
            SELECT @n_continue = 3  
      SELECT @local_n_err = 77303  
      SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
      SELECT @local_c_errmsg = ': Deleting LOTxBillDate failed (nsp_ArchiveITRN) ' + ' ( ' +  
          ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
         ROLLBACK  
         GOTO QUIT                   
       END   
         ELSE  
         BEGIN  
            WHILE @@TRANCOUNT > 0  
               COMMIT TRAN   
         END   
      END   
  
  -- SOS33899, Remove the remark by June 31.Mar.2005  
  -- Delete Lot after LOTxLOCxID   
  IF @n_continue = 1 OR @n_continue = 2  
  BEGIN  
     DECLARE C_ARC_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
     SELECT LOT.LOT    
       FROM LOT (NOLOCK)  
      WHERE LOT.Qty = 0  
        AND LOT.QtyAllocated = 0  
        AND LOT.QtyPicked = 0  
        AND NOT EXISTS ( SELECT 1 FROM  LOTxLOCxID WITH (NOLOCK) 
               WHERE  LOTxLOCxID.LOT = LOT.LOT  ) -- tlting 
    
     OPEN C_ARC_LOT    
       
     FETCH NEXT FROM C_ARC_LOT INTO @cLOT  
       
     WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 OR @n_continue = 2 )  
     BEGIN  
        BEGIN TRAN   
             
        DELETE LOT   
        WHERE LOT = @cLOT   
          
        IF @@error <> 0   
            BEGIN   
               SELECT @n_continue = 3  
         SELECT @local_n_err = 77303  
         SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)  
         SELECT @local_c_errmsg = ': Deleting LOT failed (nsp_ArchiveITRN) ' + ' ( ' +  
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'  
            ROLLBACK  
            GOTO QUIT                   
          END   
            ELSE  
            BEGIN  
               WHILE @@TRANCOUNT > 0  
                  COMMIT TRAN   
            END  
          
        FETCH NEXT FROM C_ARC_LOT INTO @cLOT   
     END -- WHILE  
     CLOSE C_ARC_LOT  
     DEALLOCATE C_ARC_LOT      
      END   
    
  IF @n_continue = 1 OR @n_continue = 2  
  BEGIN  
   WHILE @@TRANCOUNT > 0  
     BEGIN  
      COMMIT TRAN  
     END  
  END  
  ELSE  
  BEGIN  
   ROLLBACK TRAN  
  END  
 END  
  
   if @n_continue = 1 or @n_continue = 2  
   begin  
      select @b_success = 1  
      execute dbo.nsplogalert  
         @c_modulename   = 'nsp_ArchiveITRN',  
         @c_alertmessage = 'archive of ITRN ended successfully.',  
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
         execute dbo.nsplogalert  
            @c_modulename   = 'nsp_ArchiveITRN',  
            @c_alertmessage = 'archive of ITRN failed - check this log for additional messages.',  
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
  
 /* #INCLUDE <SPARPO2.SQL> */       
QUIT:  
   
 IF @n_continue=3  -- Error Occured - Process AND Return  
 BEGIN  
  SELECT @b_success = 0  
  IF @@TRANCOUNT > 0   
  BEGIN  
   ROLLBACK TRAN  
  END  
  ELSE  
  BEGIN  
   WHILE @@TRANCOUNT > @n_StartTCnt  
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
  
  EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'nsp_ArchiveITRN'  -- (YokeBeen01)  
  RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
  RETURN  
 END  
 ELSE  
 BEGIN  
  SELECT @b_success = 1  
  WHILE @@TRANCOUNT > @n_StartTCnt  
  BEGIN  
   COMMIT TRAN  
  END  
  RETURN  
 END  
   
END -- main

GO