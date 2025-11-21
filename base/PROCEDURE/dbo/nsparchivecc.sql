SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc : nspArchiveCC                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Housekeep CCDetail Table												*/
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
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-Jun-15  June				Script merging : SOS18664 done by Wanyt	*/
/* 2005-Aug-10  Ong 				SOS38267 : obselete sku & storerkey		   */
/* 2005-Dec-12  Shong         Added Table StockTakeSheetParamaters      */
/* 2006-Jan-06	 June		      SOS44194 - Add Status Checking				*/
/* 2006-Aug-01	 June          SOS54859 - Use StocktakeSheetParameters   */
/*	                           'Posted' check Instead of CCDetail.Status */
/* 2008-Jan-29  June				SOS66279 - Add StocktakeParm2 table			*/
/* 2008-Sep-04  Leong         SOS# 110599 - Conso TW version with others*/
/*                                          sites using @c_ConfigKey    */
/* 09-Nov-2010  TLTING  1.2   Commit at line level                      */
/* 25-Feb-2011  TLTING  1.2   Archive StocktakeParm2 (tlting01)         */
/* 02-Sep-2014  TLTING  1.3   Force archive after 150 days              */
/************************************************************************/


/* Created for IDS by DLIM for FBR27 20010622 */
CREATE PROC    [dbo].[nspArchiveCC]
@c_archivekey   NVARCHAR(10)
,  @c_ConfigKey NVARCHAR(1) -- 1 = Check with StockTakeSheetParameters, 0 = Check with CCDetail  --SOS# 110599 
,  @b_Success   int        OUTPUT
,  @n_err       int        OUTPUT
,  @c_errmsg    NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET CONCAT_NULL_YIELDS_NULL OFF
/* BEGIN 2005-Aug-10 (SOS38267) */
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 
/* END 2005-Aug-10 (SOS38267) */
   DECLARE
   @dummy	      NVARCHAR(1),
   @n_continue    int,
   @n_starttcnt   int, -- Holds the current transaction count
   @n_cnt         int, -- Holds @@ROWCOUNT after certain operations
   @b_debug       int -- Debug On Or Off
   /* #INCLUDE <SPACC1.SQL> */
   DECLARE @n_retain_days              int, -- days to hold data
      @d_CCdate                        datetime, -- CC Date from CC header table
      @d_result                        datetime, -- date CC_date - (getdate() - noofdaystoretain
      @d_result2                       datetime, -- date CC_date - (getdate() - noofdaystoretain
      @c_datetype                      NVARCHAR(10), -- 1=CCDATE, 2=EditDate, 3=AddDate
      @n_archive_CC_records            int, -- # of CC records to be archived
      @n_archive_CC_detail_records     int, -- # of CC_detail records to be archived
      @local_n_err                     int,
      @local_c_errmsg                  NVARCHAR(254),
      @c_CCActive                      NVARCHAR(2),
      @c_CCStart                       NVARCHAR(15),
      @c_CCEnd                         NVARCHAR(15),
      @c_whereclause                   NVARCHAR(254),
      @c_temp                          NVARCHAR(254),
      @CopyRowsToArchiveDatabase       NVARCHAR(1),
      @c_CopyFrom_db                   NVARCHAR(30),
      @c_Copyto_db                     NVARCHAR(30),
      @c_CCkey                         NVARCHAR(10), 
      @c_PrevCCkey                     NVARCHAR(10), 
      @n_archive_StkTakeParm_records   int 

   DECLARE
      @cCCDETAILKey NVARCHAR(10)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@b_debug = 1, @local_n_err = 0, @local_c_errmsg = ' '
    
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
		SELECT @c_CopyFrom_db = livedatabasename,
			@c_Copyto_db = archivedatabasename,
			@n_retain_days = CCnumberofdaystoretain,
			@c_CCActive = CCActive,
			@c_datetype = CCDateType,
			@c_CCStart = ISNULL(CCStart,''),
			@c_CCEnd = ISNULL(CCEnd,'ZZZZZZZZZZ'),
			@CopyRowsToArchiveDatabase = Copyrowstoarchivedatabase
		FROM ARCHIVEPARAMETERS (NOLOCK)
		WHERE Archivekey = @c_archivekey
		        
      SELECT @d_result = DATEADD(DAY,-@n_retain_days,GETDATE())
		SELECT @d_result = DATEADD(DAY,1,@d_result)  
		
      SELECT @d_result2 = DATEADD(DAY,-150,GETDATE())  -- Archive All 150 days
		SELECT @d_result2 = DATEADD(DAY,1,@d_result2) 		    
   END
   
   IF db_id(@c_copyto_db) IS NULL
   BEGIN
      SELECT @n_continue = 3
      SELECT @local_n_err = 77100
      SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      SELECT @local_c_errmsg =
      ": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
      " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" +' (nspArchiveCC) '
   END   

   IF @b_debug = 1
   BEGIN
      Select @c_CCActive '@c_CCActive', @c_CCStart '@c_CCStart', @c_CCEnd '@c_CCEnd', @n_retain_days '@n_retain_days', @c_datetype '@c_datetype'
   END
      
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      SELECT @c_temp = "Archive Of IDS CC Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
      ' ; Active = '+ dbo.fnc_RTrim(@c_CCActive)+ ' ; CC = '+dbo.fnc_RTrim(@c_CCStart)+'-'+dbo.fnc_RTrim(@c_CCEnd)+
      ' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ convert(char(6),@n_retain_days)
      EXECUTE nspLogAlert
      @c_ModuleName   = "nspArchiveCC",
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
   IF  (@n_continue = 1 or @n_continue = 2)
   BEGIN
      IF (dbo.fnc_RTrim(@c_CCStart) IS NOT NULL and dbo.fnc_RTrim(@c_CCEnd) IS NOT NULL)
      BEGIN
			-- SOS44194 - Add Status checking
         -- DLIM - Originally was CC.CCKey
         -- SELECT @c_temp =  ' AND CCdetail.CCKey BETWEEN '+ '"' + dbo.fnc_RTrim(@c_CCStart) + '"' +' AND '+
         -- '"'+dbo.fnc_RTrim(@c_CCEnd)+'"'
         -- SELECT @c_temp =  ' AND CCdetail.CCKey BETWEEN '+ '"' + dbo.fnc_RTrim(@c_CCStart) + '"' +' AND '+
         -- '"'+dbo.fnc_RTrim(@c_CCEnd)+'" AND CCdetail.Status = "9"'

-- Start : SOS54859
         IF dbo.fnc_RTrim(@c_ConfigKey) = '1' -- SOS# 110599
            BEGIN
      			SELECT @c_temp =  ' AND StockTakeSheetParameters.StockTakeKey BETWEEN '+ 'N''' + ISNULL(dbo.fnc_RTrim(@c_CCStart),'') + '''' +' AND '+
--             'N'''+ ISNULL(dbo.fnc_RTrim(@c_CCEnd),'') +''' AND Password = "POSTED"' -- SOS# 110599
               'N'''+ ISNULL(dbo.fnc_RTrim(@c_CCEnd),'') +''' AND (Password <> "" OR Password = "POSTED")' -- SOS# 110599               
            END
         IF dbo.fnc_RTrim(@c_ConfigKey) = '0' -- SOS# 110599
            BEGIN
               SELECT @c_temp =  ' AND CCdetail.CCKey BETWEEN '+ 'N''' + ISNULL(dbo.fnc_RTrim(@c_CCStart),'') + '''' +' AND '+
               'N'''+ ISNULL(dbo.fnc_RTrim(@c_CCEnd),'') +''' AND CCdetail.Status = "9"'
            END         
-- End : SOS54859

      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'CCDetail',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         SELECT @b_success = 1
         EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'StockTakeSheetParameters',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print 'building alter table string for CCDetail...'
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,'CCDetail',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            print 'building alter table string for StockTakeSheetParameters...'
         END
         EXECUTE nspBuildAlterTableString @c_copyto_db,'StockTakeSheetParameters',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END

      IF ((@n_continue = 1 or @n_continue = 2 ) and @CopyRowsToArchiveDatabase = 'Y')
      BEGIN

         IF @c_datetype = '1' -- CCDate
         BEGIN
            SELECT @b_success = 1
            EXECUTE nspLogAlert
            @c_ModuleName   = "nspArchiveCC",
            @c_AlertMessage = "Archiving IDS CC Based on CCDate is Not Active - Aborting...",
            @n_Severity     = 0,
            @b_success       = @b_success OUTPUT,
            @n_err          = @n_err OUTPUT,
            @c_errmsg       = @c_errmsg OUTPUT
            SELECT  @local_n_err  = 77100
            SELECT  @local_c_errmsg = "Archiving IDS CC Based on OrderDate is Not Active - Aborting..."
            SELECT @n_continue = 3
         END

         IF (@n_continue = 1 or @n_continue = 2 )
         BEGIN
            IF @c_datetype = "2" -- EditDate
            BEGIN
               -- DLIM - Originally was UPDATE CC SET Archivecop = '9' WHERE CC.EditDate.............   
               -- BEGIN (SOS38267) 2005-Aug-10  Ong
               -- SELECT @c_whereclause = "WHERE CCDETAIL.EditDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' +  @c_temp
					-- Start : SOS54859
					
   				IF dbo.fnc_RTrim(@c_ConfigKey) = '1' -- SOS# 110599
   				BEGIN
				   SELECT @c_whereclause = "WHERE ( STOCKTAKESHEETPARAMETERS.EditDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' +  @c_temp + " ) " + Char(13) + 
				                           "  OR ( STOCKTAKESHEETPARAMETERS.EditDate  <= "+ '"'+ convert(char(10),@d_result2,101)+'"' + ' ) '
				   END

				   IF dbo.fnc_RTrim(@c_ConfigKey) = '0' -- SOS# 110599
				   BEGIN 
                  SELECT @c_whereclause = "WHERE ( CCDETAIL.EditDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' +  @c_temp + " ) " + Char(13) +
                                          " OR ( CCDETAIL.EditDate  <= " + '"'+ convert(char(10),@d_result2,101)+'"' + ' ) '
                END
					
					-- End : SOS54859  
               -- END (SOS38267) 2005-Aug-10  Ong
            END
            IF @c_datetype = "3" -- AddDate
            BEGIN
   				IF dbo.fnc_RTrim(@c_ConfigKey) = '1' -- SOS# 110599
   				BEGIN
				      SELECT @c_whereclause = "WHERE ( STOCKTAKESHEETPARAMETERS.AddDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' +  @c_temp + " ) " + Char(13) +
				                              " OR ( STOCKTAKESHEETPARAMETERS.AddDate  <= " + '"'+ convert(char(10),@d_result2,101)+'"' + ' ) '
               END
  				   IF dbo.fnc_RTrim(@c_ConfigKey) = '0' -- SOS# 110599
				   BEGIN 
                  SELECT @c_whereclause = "WHERE ( CCDETAIL.AddDate  <= " + '"'+ convert(char(10),@d_result,101)+'"' +  @c_temp + " ) " + Char(13) +
                                          " OR ( CCDETAIL.AddDate  <= " + '"'+ convert(char(10),@d_result2,101)+'"'
               END					
					-- End : SOS54859
					             
            END
            -- END (SOS38267) 2005-Aug-10  Ong

            IF @b_debug = 1
            BEGIN
               Select @c_WhereClause '@c_whereclause'
               Select @c_temp '@c_temp'
            END
            
            /* BEGIN (SOS38267) UPDATE*/
				-- Start : SOS54859
            -- EXEC (
            -- ' Declare C_CCDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' + 
            -- ' SELECT CCKey, CCDetailKey FROM CCDETAIL (NOLOCK) ' + @c_WhereClause + 
            -- ' ORDER BY CCKEY, CCDetailKey' ) 
                                 
            IF dbo.fnc_RTrim(@c_ConfigKey) = '1'
            BEGIN 
               EXEC (
               ' Declare C_CCDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' + 
               ' SELECT CCKey, CCDetailKey ' + 
   			   ' FROM CCDETAIL (NOLOCK) ' +
   			   ' JOIN STOCKTAKESHEETPARAMETERS (NOLOCK) ON STOCKTAKESHEETPARAMETERS.StocktakeKey = CCDETAIL.CCkey ' + @c_WhereClause + 
               ' ORDER BY CCKEY, CCDetailKey' ) 
            END
            
            IF dbo.fnc_RTrim(@c_ConfigKey) = '0'
            BEGIN            
            EXEC (
            ' Declare C_CCDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' + 
            ' SELECT CCKey, CCDetailKey FROM CCDETAIL (NOLOCK) ' + @c_WhereClause + 
            ' ORDER BY CCKEY, CCDetailKey' ) 
            END            
	         -- End : SOS54859        
            SET @c_PrevCCkey = ''
            SET @n_archive_StkTakeParm_records = 0
            SET @n_archive_CC_Detail_records = 0 

            OPEN C_CCDetailKey
            
            FETCH NEXT FROM C_CCDetailKey INTO @c_CCkey, @cCCDetailKey
            
            WHILE @@fetch_status <> -1
            BEGIN
               IF @c_PrevCCkey <> @c_CCkey 
               BEGIN
                  BEGIN TRAN
                  UPDATE StockTakeSheetParameters WITH (ROWLOCK)
                     SET ArchiveCop = '9' 
                  WHERE StockTakeKey = @c_CCkey         

                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  select @n_archive_StkTakeParm_records = @n_archive_StkTakeParm_records + 1
                  
                  IF @local_n_err <> 0 
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @local_n_err = 77102
                     SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                     SELECT @local_c_errmsg =
                     ": Update of Archivecop failed - StockTakeSheetParameters. (nspArchiveCC) " + " ( " +
                     " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
                     ROLLBACK TRAN
                  END
   
						-- Start : SOS66279
				      IF (@n_continue = 1 or @n_continue = 2 )
						BEGIN						
				         UPDATE StockTakeParm2 WITH (ROWLOCK)
	                     SET ArchiveCop = '9' 
	                   WHERE StockTakeKey = @c_CCkey         
	
	                  SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT	                  
                  	SELECT @n_archive_StkTakeParm_records = @n_archive_StkTakeParm_records + 1
	
	                  IF @local_n_err <> 0 
	                  BEGIN
	                     SELECT @n_continue = 3
	                     SELECT @local_n_err = 77102
	                     SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
	                     SELECT @local_c_errmsg =
	                     ": Update of Archivecop failed - StockTakeParm2. (nspArchiveCC) " + " ( " +
	                     " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
	                     ROLLBACK TRAN
	                  END
						END
						-- End : SOS66279
                  COMMIT TRAN
                  SET @c_PrevCCkey = @c_CCkey   
               END
               BEGIN TRAN
               UPDATE CCDETAIL WITH (ROWLOCK)
                  SET ArchiveCop = '9' 
               WHERE CCDetailKey = @cCCDetailKey  
   
               SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               select @n_archive_CC_Detail_records = @n_archive_CC_Detail_records + 1
               
               IF @local_n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @local_n_err = 77102
                  SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
                  SELECT @local_c_errmsg =
                  ": Update of Archivecop failed - CCDetail. (nspArchiveCC) " + " ( " +
                  " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
                  ROLLBACK TRAN
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
               FETCH NEXT FROM C_CCDETAILkey INTO @c_CCkey, @cCCDETAILKey
            END -- while TransmitLogKey 
            CLOSE C_CCDETAILkey
            DEALLOCATE C_CCDETAILkey
            /* END (SOS38267) UPDATE*/
         END --(@n_continue = 1 or @n_continue = 2)

         IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
         BEGIN
            SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_StkTakeParm_records )) +
            " StockTakeParamaters records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_CC_detail_records )) + " CCDetail records"
            EXECUTE nspLogAlert
            @c_ModuleName   = "nspArchiveCC",
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
            EXEC nsp_BUILD_INSERT   @c_copyto_db, 'CCDetail',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
            IF not @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SELECT @b_success = 1
            EXEC nsp_BUILD_INSERT   @c_copyto_db, 'StockTakeSheetParameters',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
            IF not @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END
         -- tlting01
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SELECT @b_success = 1
            EXEC nsp_BUILD_INSERT   @c_copyto_db, 'stocktakeparm2',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
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
      @c_ModuleName   = "nspArchiveCC",
      @c_AlertMessage = "Archive Of CC Ended Normally.",
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
         @c_ModuleName   = "nspArchiveCC",
         @c_AlertMessage = "Archive Of CC Ended Abnormally - Check This Log For Additional Messages.",
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
   /* #INCLUDE <SPACC2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveCC"
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