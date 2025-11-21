SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : IspArchiveInventoryQC                                  */
/* Creation Date: 28.01.2008                                            */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
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
/* PVCS Version: 1.12                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 1/10/2013    TLTING01  Bug fix                                       */
/************************************************************************/

CREATE PROC    [dbo].[IspArchiveInventoryQC]
	@c_archivekey	 NVARCHAR(10),
	@b_Success      int        OUTPUT,    
	@n_err          int        OUTPUT,    
	@c_errmsg       NVARCHAR(250)  OUTPUT    
AS
BEGIN  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE        @n_continue int        ,  
		@n_starttcnt int        , -- Holds the current transaction count
		@n_cnt int              , -- Holds @@ROWCOUNT after certain operations
		@b_debug int             -- Debug On Or Off

   /* #INCLUDE <SPARPO1.SQL> */     
   DECLARE @cQCKey NVARCHAR(10),
           @cQCLineNo NVARCHAR(5) 
           
	DECLARE        @n_retain_days int      , -- days to hold data
		@d_result  datetime , 
		@c_datetype NVARCHAR(10),      -- 1=EditDate, 2=AddDate
		@n_archive_QC_records   int, -- # of QC records to be archived
		@n_archive_QC_detail_records   int, -- # of QC_detail records to be archived
		@local_n_err         int,
		@local_c_errmsg    NVARCHAR(254)

	DECLARE  @c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@c_QCActive NVARCHAR(2),
		@c_QCStart NVARCHAR(18),
		@c_QCEnd NVARCHAR(18),
		@c_whereclause NVARCHAR(4000),
		@c_temp NVARCHAR(254),
		@CopyRowsToArchiveDatabase NVARCHAR(1)

	SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
			@n_retain_days = InvQCNumberofDaysToRetain,
			@c_datetype = InvQCDateType,
			@c_QCActive = InvQCActive,
			@c_QCStart = InvQCStart,
			@c_QCEnd = InvQCEnd,
			@CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
		FROM  ArchiveParameters (nolock)
		WHERE archivekey = @c_archivekey

		IF db_id(@c_copyto_db) is NULL
		BEGIN
			SELECT @n_continue = 3
			SELECT @local_n_err = 73701
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
			": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
			" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + '(IspArchiveInventoryQC)'
		END
		SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
		SELECT @d_result = dateadd(day,1,@d_result)
	END
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		SELECT @c_temp = "Archive Of InventoryQC Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
			' ; Active = '+ dbo.fnc_RTrim(@c_QCActive)+ ' ; QCKey = '+dbo.fnc_RTrim(@c_QCStart)+'-'+dbo.fnc_RTrim(@c_QCEnd)+
			' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) + '; Retain Days = '+ convert(char(6),@n_retain_days)

		EXECUTE nspLogAlert
			@c_ModuleName   = "IspArchiveInventoryQC",
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
	BEGIN
		SELECT @c_whereclause = ' '
		SELECT @c_temp = ''
		SELECT @c_temp = @c_temp + ' AND InventoryQC.QC_Key BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_QCStart) + '''' +' AND '+
			'N'''+dbo.fnc_RTrim(@c_QCEnd)+''''

		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN 
			IF (@b_debug = 1)
			BEGIN
				print "starting Table Existence Check For InventoryQC..."
			END
			select @b_success = 1
			EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'InventoryQC',@b_success OUTPUT , @n_err OUTPUT , @c_errmsg OUTPUT
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END   
		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN  
			IF (@b_debug = 1)
			BEGIN
				print "starting Table Existence Check For InventoryQCDETAIL..."
			END
			SELECT @b_success = 1
			EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'InventoryQCDetail',@b_success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END     
		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN
			IF (@b_debug = 1)
			BEGIN
				print "building alter table string for InventoryQC..."
			END
			EXECUTE nspBuildAlterTableString @c_copyto_db,"InventoryQC",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END
		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN
			IF (@b_debug = 1)
			BEGIN
				print "building alter table string for InventoryQCDetail..."
			END
			EXECUTE nspBuildAlterTableString @c_copyto_db,"InventoryQCDETAIL",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END

		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN 
			BEGIN TRAN

			IF @c_datetype = "1" -- EditDate
			BEGIN
            SELECT @c_whereclause = " WHERE InventoryQC.EditDate <= " + '"'+ convert(char(11),@d_result,106)+'"' 
               + " and (InventoryQC.ArchiveCop is  NULL ) "
               + " and (InventoryQCDetail.Status = '9') " + dbo.fnc_RTrim(@c_temp)
			END
			IF @c_datetype = "2" -- AddDate
			BEGIN
            SELECT @c_whereclause = " WHERE InventoryQC.AddDate <= " +'"'+ convert(char(11),@d_result,106)+'"' 
               + " and (InventoryQC.ArchiveCop is  NULL ) "
               + " and (InventoryQCDetail.Status = '9') " + dbo.fnc_RTrim(@c_temp)
			END


         WHILE @@TranCount > @n_starttcnt			
            COMMIT TRAN 

			SET @n_archive_QC_records = 0 
         SET @n_archive_QC_detail_records = 0


         CREATE TABLE #InventoryQCTemp
         (  Rowref INT NOT NULL Identity(1,1) Primary Key,
            QC_Key NVARCHAR(10) NOT NULL          
         )

			SELECT @c_whereclause = 
           ' INSERT INTO  #InventoryQCTemp ( QC_Key ) ' +
			  ' SELECT DISTINCT InventoryQC.QC_Key ' + 
			  ' FROM InventoryQC WITH (NOLOCK) ' + 
			  ' JOIN InventoryQCDetail WITH (NOLOCK) ON InventoryQC.QC_Key = InventoryQCDetail.QC_Key ' + 
			  dbo.fnc_RTrim( @c_whereclause ) 
		
			EXECUTE (@c_whereclause)
		   SELECT @local_n_err = @@ERROR
			IF @local_n_err <> 0
			BEGIN 
				SELECT @n_continue = 3
				SELECT @local_n_err = 73722
				SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
				SELECT @local_c_errmsg =
				": INSERT Temp Table failed - InventoryQC. (IspArchiveInventoryQC) " + " ( " +
				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"

			END  

		   DECLARE C_ArchiveQC CURSOR FAST_FORWARD READ_ONLY FOR  
		   SELECT QC_Key 
		   FROM #InventoryQCTemp WITH (NOLOCK) 
			  
			OPEN C_ArchiveQC
			
			FETCH NEXT FROM C_ArchiveQC INTO @cQCKey 
			WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
			BEGIN
            BEGIN TRAN 

			   UPDATE InventoryQC WITH (ROWLOCK)
			      SET ArchiveCop = '9' 
			    WHERE QC_Key = @cQCKey 
			   
			   SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   			IF @local_n_err <> 0
   			BEGIN 
   				SELECT @n_continue = 3
   				SELECT @local_n_err = 73702
   				SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
   				SELECT @local_c_errmsg =
   				": Update of Archivecop failed - InventoryQC. (IspArchiveInventoryQC) " + " ( " +
   				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               ROLLBACK TRAN 
   			END  
   		   ELSE
   		   BEGIN
   			   SELECT @n_archive_QC_records = @n_archive_QC_records + 1 
               COMMIT TRAN 
   			END

   			IF (@n_continue = 1 or @n_continue = 2)
   			BEGIN 
   			   DECLARE C_ArchiveQCDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   			   SELECT QCLineNo  
   			   FROM   InventoryQCDetail (NOLOCK)
   			   WHERE  QC_Key = @cQCKey 
   			   
   			   OPEN C_ArchiveQCDetail
   			   
   			   FETCH NEXT FROM C_ArchiveQCDetail INTO @cQCLineNo 
   			   
   			   WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
   			   BEGIN
                  BEGIN TRAN 
                  
                  IF  @b_debug = '2'
                  BEGIN
                     PRINT '@cQCKey - ' + @cQCKey + ' , @cQCLineNo - ' + @cQCLineNo
                  END

      				UPDATE InventoryQCDetail WITH (ROWLOCK) 
      				   Set InventoryQCDetail.Archivecop = '9' 
      				Where (InventoryQCDetail.QC_Key = @cQCKey AND QCLineNo = @cQCLineNo) 
      				
      				SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      				IF @local_n_err <> 0
      				BEGIN 
      					SELECT @n_continue = 3
      					SELECT @local_n_err = 73703
      					SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      					SELECT @local_c_errmsg =
      					": Update of Archivecop failed - InventoryQCDetail. (IspArchiveInventoryQC) " + " ( " +
      					" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
                     ROLLBACK TRAN
      				END  
                  ELSE
                  BEGIN
                     SET @n_archive_QC_detail_records = @n_archive_QC_detail_records + 1 
                     COMMIT TRAN 
                  END

      				FETCH NEXT FROM C_ArchiveQCDetail INTO @cQCLineNo
      			END -- while
      			CLOSE C_ArchiveQCDetail
      			DEALLOCATE C_ArchiveQCDetail
   			END 
   			
   			FETCH NEXT FROM C_ArchiveQC INTO @cQCKey 
			END
			CLOSE C_ArchiveQC
			DEALLOCATE C_ArchiveQC

			IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
			BEGIN
				SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_QC_records )) +
				" InventoryQC records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_QC_detail_records )) + " InventoryQC Detail records"
				EXECUTE nspLogAlert
				@c_ModuleName   = "IspArchiveInventoryQC",
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
					print "Building INSERT for InventoryQC DETAIL..."
				END
				SELECT @b_success = 1
				EXEC nsp_BUILD_INSERT   @c_copyto_db, 'InventoryQCDetail',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
				IF not @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
			END   

			IF @n_continue = 1 or @n_continue = 2
			BEGIN   
				IF (@b_debug = 1)
				BEGIN
					print "Building INSERT for InventoryQC..."
				END
				SELECT @b_success = 1
				EXEC nsp_BUILD_INSERT  @c_copyto_db, 'InventoryQC',1,@b_success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT

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
		@c_ModuleName   = "IspArchiveInventoryQC",
		@c_AlertMessage = "Archive Of InventoryQC Ended Normally.",
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
			@c_ModuleName   = "IspArchiveInventoryQC",
			@c_AlertMessage = "Archive Of InventoryQC Ended Abnormally - Check This Log For Additional Messages.",
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, "IspArchiveInventoryQC"
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