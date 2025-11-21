SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : nspArchiveAdjustment                                   */
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
/* Called By: All Archive Script                                        */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2005-Dec-01  Shong           Delete the Records when record          */
/*                              sucessfully inserted into Archive DB    */
/* 2009-Dec-01  Leong     1.1   SOS# 125449 - Filter by FinalizeFlag    */
/************************************************************************/
CREATE PROC [dbo].[nspArchiveAdjustment]
	@c_archivekey	 NVARCHAR(10),				
	@b_Success      int        OUTPUT,    
	@n_err          int        OUTPUT,   
	@c_errmsg       NVARCHAR(250)  OUTPUT    
AS
BEGIN  
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE @n_continue  int,  
	        @n_starttcnt int, -- Holds the current transaction count
	        @n_cnt       int, -- Holds @@ROWCOUNT after certain operations
	        @b_debug     int  -- Debug On Or Off
	     /* #INCLUDE <SPAAdj1.SQL> */     
	
	DECLARE  @c_copyfrom_db                NVARCHAR(55),
         	@c_copyto_db                  NVARCHAR(55),      
         	@n_retain_days                int     , -- days to hold data
         	@d_Adjdate                    datetime, -- Adj Date from Adj header table
         	@d_result                     datetime, -- date Adj_date - (getdate() - noofdaystoretain
         	@c_datetype                   NVARCHAR(10), -- 1=AdjDATE, 2=EditDate, 3=AddDate
         	@n_archive_Adj_records        int     , -- # of Adj records to be archived
         	@n_archive_Adj_detail_records int       -- # of Adj_detail records to be archived
	
	DECLARE  @local_n_err    int,
	         @local_c_errmsg NVARCHAR(254)
	
	DECLARE  @c_AdjActive               NVARCHAR(2),
         	@c_AdjStart                NVARCHAR(15),
         	@c_AdjEnd                  NVARCHAR(15),
         	@c_whereclause             NVARCHAR(350),
         	@c_temp                    NVARCHAR(254),
         	@CopyRowsToArchiveDatabase NVARCHAR(1)
	
	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg="",
	       @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT   @c_copyfrom_db = livedatabasename,
         		@c_copyto_db = archivedatabasename,
         		@n_retain_days = Adjnumberofdaystoretain,
         		@c_datetype = AdjustmentDateType,
         		@c_AdjActive = AdjActive,
         		@c_AdjStart = AdjStart,
         		@c_AdjEnd = AdjEnd,
         		@CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
		FROM     ArchiveParameters (nolock)
		WHERE    archivekey = @c_archivekey
	
		IF db_id(@c_copyto_db) IS NULL
		BEGIN
			SELECT @n_continue = 3
			SELECT @local_n_err = 77100
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
			": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
			" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" +' (nspArchiveAdjustment) '
		END
		
		DECLARE @d_today datetime
		SELECT  @d_today  = convert(datetime,convert(char(11),getdate(),106))
		SELECT  @d_result = dateadd(day,(-@n_retain_days + 1),@d_today)
		SELECT  @d_result = dateadd(day,1,@d_result)
	END
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		SELECT @c_temp = "Archive Of Adjustment Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
		' ; Active = '+ dbo.fnc_RTrim(@c_AdjActive)+ ' ; Adj = '+dbo.fnc_RTrim(@c_AdjStart)+'-'+dbo.fnc_RTrim(@c_AdjEnd)+
		' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ convert(char(6),@n_retain_days)
		EXECUTE nspLogAlert
			@c_ModuleName   = "nspArchiveAdjustment",
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
	
	IF  (@n_continue = 1 or @n_continue = 2)
	BEGIN
		SELECT @c_temp =  ' AND Adjustment.AdjustmentKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_AdjStart) + '''' +' AND '+
				'N'''+dbo.fnc_RTrim(@c_AdjEnd)+''''
		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN 
			select @b_success = 1
			EXEC nsp_BUILD_ARCHIVE_TABLE 
				@c_copyfrom_db, 
				@c_copyto_db, 
				'Adjustment',
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
			SELECT @b_success = 1
			EXEC nsp_BUILD_ARCHIVE_TABLE 
				@c_copyfrom_db, 
				@c_copyto_db, 
				'AdjustmentDetail',
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
				print "building alter table string for Adjustment..."
			END
			EXECUTE nspBuildAlterTableString 
				@c_copyto_db,
				"Adjustment",
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
				print "building alter table string for AdjustmentDetail..."
			END
			EXECUTE nspBuildAlterTableString 
				@c_copyto_db,
				"AdjustmentDetail",
				@b_success OUTPUT,
				@n_err OUTPUT, 
				@c_errmsg OUTPUT
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END
		IF ((@n_continue = 1 or @n_continue = 2 ) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN
			IF @c_datetype = "1" -- AdjDate
			BEGIN
				SELECT @b_success = 1
				EXECUTE nspLogAlert
					@c_ModuleName   = "nspArchiveAdjustment",
					@c_AlertMessage = "Archiving Adjustment Based on AdjDate is Not Active - Aborting...",
					@n_Severity     = 0,
					@b_success      = @b_success OUTPUT,
					@n_err          = @n_err OUTPUT,
					@c_errmsg       = @c_errmsg OUTPUT
				SELECT  @local_n_err = 77100
				SELECT  @local_c_errmsg = "Archiving Adjustment Based on AdjDate is Not Active - Aborting..."
				SELECT  @n_continue = 3
			END

			IF (@n_continue = 1 or @n_continue = 2 )
			BEGIN
				IF @c_datetype = "2" -- EditDate
				BEGIN
					-- SELECT @c_whereclause = "WHERE Adjustment.EditDate  <= " + '"'+ convert(char(11),@d_result,106)+'"' +  @c_temp -- SOS# 125449
					SELECT @c_whereclause = "WHERE FinalizedFlag = 'Y' AND Adjustment.EditDate  <= " + '"'+ convert(char(11),@d_result,106)+'"' +  @c_temp -- SOS# 125449
				END
				IF @c_datetype = "3" -- AddDate
				BEGIN
					-- SELECT @c_whereclause = "WHERE Adjustment.AddDate  <= " + '"'+ convert(char(11),@d_result,106)+'"' +  @c_temp -- SOS# 125449
					SELECT @c_whereclause = "WHERE FinalizedFlag = 'Y' AND Adjustment.AddDate  <= " + '"'+ convert(char(11),@d_result,106)+'"' +  @c_temp -- SOS# 125449
				END

-------------------
            WHILE @@TRANCOUNT > @n_starttcnt
               COMMIT TRAN 

            DECLARE @cAdjustmentKey NVARCHAR(10), 
                    @cAdjustmentLineNumber NVARCHAR(5)
   
            SELECT @n_archive_Adj_records = 0
            SELECT @n_archive_Adj_detail_records = 0 
   
            WHILE @@TRANCOUNT > @n_starttcnt 
               COMMIT TRAN 
   
            EXEC (
            ' Declare C_Arc_AdjustmentHeader CURSOR FAST_FORWARD READ_ONLY FOR ' + 
            ' SELECT AdjustmentKey FROM Adjustment (NOLOCK) ' + @c_WhereClause + 
            ' ORDER BY AdjustmentKey ' ) 
            
    
            OPEN C_Arc_AdjustmentHeader
            
            FETCH NEXT FROM C_Arc_AdjustmentHeader INTO @cAdjustmentKey
            
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               BEGIN TRAN 
   
               UPDATE Adjustment WITH (ROWLOCK)
                  SET ArchiveCop = '9' 
               WHERE AdjustmentKey = @cAdjustmentKey  
   
         		SELECT @local_n_err = @@error   --, @n_cnt = @@rowcount            
               SELECT @n_archive_Adj_records = @n_archive_Adj_records + 1            
               IF @local_n_err <> 0
            	BEGIN 
   					SELECT @n_continue = 3
   					SELECT @local_n_err = 77101
   					SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
   					SELECT @local_c_errmsg =
   						": Update of Archivecop failed - Adjustment Table. (nspArchiveAdjustment) " + " ( " +
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
                  SELECT AdjustmentLineNumber 
                  FROM   ADJUSTMENTDETAIL (NOLOCK) 
                  WHERE  AdjustmentKey = @cAdjustmentKey 
                  ORDER By AdjustmentLineNumber  
               
                  OPEN C_Arc_AdjmentLine 
                  
                  FETCH NEXT FROM C_Arc_AdjmentLine INTO @cAdjustmentLineNumber 
               
                  WHILE @@fetch_status <> -1  
                  BEGIN 
                     BEGIN TRAN 
         
                     UPDATE ADJUSTMENTDETAIL WITH (ROWLOCK) 
                        SET Archivecop = '9'
                     WHERE AdjustmentKey = @cAdjustmentKey AND AdjustmentLineNumber = @cAdjustmentLineNumber 
         
                     SELECT @local_n_err = @@error 
                     IF @local_n_err <> 0
                     BEGIN 
         					SELECT @n_continue = 3
         					SELECT @local_n_err = 77102
         					SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
         					SELECT @local_c_errmsg =
         						": Update of Archivecop failed - AdjustmentDetail. (nspArchiveAdjustment) " + " ( " +
         						" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
                        ROLLBACK TRAN 
                     END  
                     ELSE
                     BEGIN
                        SET @n_archive_Adj_detail_records = @n_archive_Adj_detail_records + 1
                        COMMIT TRAN 
                     END   
                     FETCH NEXT FROM C_Arc_AdjmentLine INTO @cAdjustmentLineNumber
                  END -- while (line)
                  CLOSE C_Arc_AdjmentLine
                  DEALLOCATE C_Arc_AdjmentLine 
               END -- (@n_continue = 1 or @n_continue = 2 )
               FETCH NEXT FROM C_Arc_AdjustmentHeader INTO @cAdjustmentKey
            END -- while AdjustmentKey 
            CLOSE C_Arc_AdjustmentHeader
            DEALLOCATE C_Arc_AdjustmentHeader
         END -- (@n_continue = 1 or @n_continue = 2 )

			IF ((@n_continue = 1 or @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'Y')
			BEGIN
				SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(CONVERT(char(6),@n_archive_Adj_records )) +
					" Adjustment records and " + dbo.fnc_RTrim(CONVERT(char(6),@n_archive_Adj_detail_records )) + " AdjustmentDetail records"
				EXECUTE nspLogAlert
					@c_ModuleName   = "nspArchiveAdjustment",
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
			
			IF @n_continue = 1 or @n_continue = 2
			BEGIN 
				SELECT @b_success = 1
				EXEC nsp_BUILD_INSERT   
					@c_copyto_db, 
					'AdjustmentDetail',
					1 ,
					@b_success OUTPUT, 
					@n_err OUTPUT, 
					@c_errmsg OUTPUT
				IF NOT @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
			END   
			IF @n_continue = 1 or @n_continue = 2
			BEGIN   
				SELECT @b_success = 1
				EXEC nsp_BUILD_INSERT  @c_copyto_db, 'Adjustment',1,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
				IF not @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
			END   
			
-- Commented By SHONG 
-- Records already deleted when execute SP nsp_BUILD_INSERT
--			IF @n_continue = 1 or @n_continue = 2
--			BEGIN  
--				IF (@b_debug = 0)
--				BEGIN
--					DELETE FROM Adjustment
--					WHERE ARCHIVECOP = '9'
--					SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
--				END
--				IF (@b_debug = 1)
--				BEGIN
--					SELECT * FROM Adjustment
--					WHERE ARCHIVECOP = '9'
--				END
--				IF @local_n_err <> 0
--				BEGIN  
--					SELECT @n_continue = 3
--					SELECT @local_n_err = 77103
--					SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
--					SELECT @local_c_errmsg =
--						":  Adjustment delete failed. (nspArchiveAdjustment) " + " ( " +
--						" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
--				END      
--			END    
--			IF @n_continue = 1 or @n_continue = 2
--			BEGIN  
--				IF (@b_debug = 0)
--				BEGIN
--					DELETE FROM AdjustmentDetail
--					WHERE ARCHIVECOP = '9'
--					SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
--				END
--				IF (@b_debug = 1)
--				BEGIN
--					SELECT * FROM AdjustmentDetail
--					WHERE ARCHIVECOP = '9'
--				END
--				IF @local_n_err <> 0
--				BEGIN
--					SELECT @n_continue = 3
--					SELECT @local_n_err = 77104
--					SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
--					SELECT @local_c_errmsg =
--						":  AdjustmentDetail delete failed. (nspArchiveAdjustment) " + " ( " +
--						" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
--				END
--			END       
		END
	END

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		EXECUTE nspLogAlert
			@c_ModuleName   = "nspArchiveAdjustment",
			@c_AlertMessage = "Archive Of Adj Ended Normally.",
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
				@c_ModuleName   = "nspArchiveAdjustment",
				@c_AlertMessage = "Archive Of Adj Ended Abnormally - Check This Log For Additional Messages.",
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
	     /* #INCLUDE <SPAAdj2.SQL> */   
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchiveAdjustment"
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