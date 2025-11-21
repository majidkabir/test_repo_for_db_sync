SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : nspArchivePO                                           */
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
/* PVCS Version: 1.12                                                   */
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
/************************************************************************/
CREATE PROC    [dbo].[nspArchivePO]
	@c_archivekey	 NVARCHAR(10),
	@b_Success      int        OUTPUT,    
	@n_err          int        OUTPUT,    
	@c_errmsg       NVARCHAR(250)  OUTPUT    
AS
BEGIN  
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE        @n_continue int        ,  
		@n_starttcnt int        , -- Holds the current transaction count
		@n_cnt int              , -- Holds @@ROWCOUNT after certain operations
		@b_debug int             -- Debug On Or Off
   /* #INCLUDE <SPARPO1.SQL> */     
   DECLARE @cPOkey NVARCHAR(10),
           @cPOLineNumber NVARCHAR(5) 
           
	DECLARE        @n_retain_days int      , -- days to hold data
		@d_podate  datetime     , -- PO Date from PO header table
		@d_result  datetime     , -- date po_date - (getdate() - noofdaystoretain
		@c_datetype NVARCHAR(10),      -- 1=PODATE, 2=EditDate, 3=AddDate
		@n_archive_po_records   int, -- # of po records to be archived
		@n_archive_po_detail_records   int -- # of po_detail records to be archived
	DECLARE        @local_n_err         int,
		@local_c_errmsg    NVARCHAR(254)
	DECLARE  @c_copyfrom_db  NVARCHAR(55),
		@c_copyto_db    NVARCHAR(55),
		@c_POActive NVARCHAR(2),
		@c_POStorerKeyStart NVARCHAR(15),
		@c_POStorerKeyEnd NVARCHAR(15),
		@c_POStart NVARCHAR(18),
		@c_POEnd NVARCHAR(18),
		@c_whereclause NVARCHAR(4000),
		@c_temp NVARCHAR(254),
		@CopyRowsToArchiveDatabase NVARCHAR(1)

	SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
			@n_retain_days = PONumberofDaysToRetain,
			@c_datetype = podatetype,
			@c_POActive = POActive,
			@c_POStorerKeyStart = POStorerKeyStart,
			@c_POStorerKeyEnd = POStorerKeyEnd,
			@c_POStart = POStart,
			@c_POEnd = POEnd,
			@CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
		FROM ArchiveParameters (nolock)
		WHERE archivekey = @c_archivekey
		IF db_id(@c_copyto_db) is NULL
		BEGIN
			SELECT @n_continue = 3
			SELECT @local_n_err = 73701
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
			": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
			" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + '(nspArchivePO)'
		END
		SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
		SELECT @d_result = dateadd(day,1,@d_result)
	END
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		SELECT @c_temp = "Archive Of PO Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
			' ; Active = '+ dbo.fnc_RTrim(@c_POActive)+ ' ; Storer = '+ dbo.fnc_RTrim(@c_POStorerKeyStart)+'-'+
			dbo.fnc_RTrim(@c_POStorerKeyEnd) + ' ; PO = '+dbo.fnc_RTrim(@c_POStart)+'-'+dbo.fnc_RTrim(@c_POEnd)+
			' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) + '; Retain Days = '+ convert(char(6),@n_retain_days)
		EXECUTE nspLogAlert
			@c_ModuleName   = "nspArchivePO",
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
		SELECT @c_temp = 'AND PO.StorerKey BETWEEN '+ 'N'''+dbo.fnc_RTrim(@c_POStorerKeyStart) + ''''+ ' AND '+
			'N'''+dbo.fnc_RTrim(@c_POStorerKeyEnd)+''''
		SELECT @c_temp = @c_temp + ' AND PO.POKey BETWEEN '+ 'N''' + dbo.fnc_RTrim(@c_POStart) + '''' +' AND '+
			'N'''+dbo.fnc_RTrim(@c_POEnd)+''''
		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN 
			IF (@b_debug = 1)
			BEGIN
				print "starting Table Existence Check For PO..."
			END
			select @b_success = 1
			EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'PO',@b_success OUTPUT , @n_err OUTPUT , @c_errmsg OUTPUT
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END   
		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN  
			IF (@b_debug = 1)
			BEGIN
				print "starting Table Existence Check For PODETAIL..."
			END
			SELECT @b_success = 1
			EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'PODetail',@b_success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END     
		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN
			IF (@b_debug = 1)
			BEGIN
				print "building alter table string for po..."
			END
			EXECUTE nspBuildAlterTableString @c_copyto_db,"PO",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END
		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN
			IF (@b_debug = 1)
			BEGIN
				print "building alter table string for podetail..."
			END
			EXECUTE nspBuildAlterTableString @c_copyto_db,"PODETAIL",@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
			IF not @b_success = 1
			BEGIN
				SELECT @n_continue = 3
			END
		END

		IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
		BEGIN 
			BEGIN TRAN

			IF @c_datetype = "1" -- PODATE
			BEGIN
            SELECT @c_whereclause = " WHERE PO.PODate  <= " + '"'+ convert(char(11),@d_result,106)+'"' 
               + " and (PO.Status = '9' or PO.externstatus = 'CANCEL' or PO.externstatus = 'CLOSE' or PO.externstatus = 'CANC' or PO.externstatus = '9' or PO.ArchiveCop = '9') " +  dbo.fnc_RTrim(@c_temp)
			END
			IF @c_datetype = "2" -- EditDate
			BEGIN
            SELECT @c_whereclause = " WHERE PO.EditDate <= " + '"'+ convert(char(11),@d_result,106)+'"' 
               + " and (PO.Status = '9' or PO.externstatus = 'CANCEL' or PO.externstatus = 'CLOSE' or PO.externstatus = 'CANC' or PO.externstatus = '9' or PO.ArchiveCop = '9') " + dbo.fnc_RTrim(@c_temp)
			END
			IF @c_datetype = "3" -- AddDate
			BEGIN
            SELECT @c_whereclause = " WHERE PO.AddDate <= " +'"'+ convert(char(11),@d_result,106)+'"' 
               + " and (PO.Status = '9' or PO.externstatus = 'CANCEL' or PO.externstatus = 'CLOSE'  or PO.externstatus = 'CANC' or PO.externstatus = '9' or PO.ArchiveCop = '9') " + dbo.fnc_RTrim(@c_temp)
			END


         WHILE @@TranCount > @n_starttcnt			
            COMMIT TRAN 

			SET @n_archive_po_records = 0 
         SET @n_archive_po_detail_records = 0

			SELECT @c_whereclause = 
			  ' DECLARE C_Archive_POKey CURSOR FAST_FORWARD READ_ONLY FOR ' + 
			  ' SELECT POKey FROM PO (NOLOCK) ' + 
			  dbo.fnc_RTrim( @c_whereclause ) 
			
			EXECUTE (@c_whereclause)
			  
			OPEN C_Archive_POKey
			
			FETCH NEXT FROM C_Archive_POKey INTO @cPOkey 
			WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
			BEGIN
            BEGIN TRAN 

			   UPDATE PO WITH (ROWLOCK)
			      SET ArchiveCop = '9' 
			   WHERE POKEY = @cPOkey 
			   
			   SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   			IF @local_n_err <> 0
   			BEGIN 
   				SELECT @n_continue = 3
   				SELECT @local_n_err = 73702
   				SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
   				SELECT @local_c_errmsg =
   				": Update of Archivecop failed - PO. (nspArchivePO) " + " ( " +
   				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               ROLLBACK TRAN 
   			END  
   		   ELSE
   		   BEGIN
   			   SELECT @n_archive_po_records = @n_archive_po_records + 1 
               COMMIT TRAN 
   			END

   			IF (@n_continue = 1 or @n_continue = 2)
   			BEGIN 
   			   DECLARE C_ArchivePODetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   			   SELECT POLineNumber  
   			   FROM   PODetail (NOLOCK)
   			   WHERE  POkey = @cPOKey 
   			   
   			   OPEN C_ArchivePODetail
   			   
   			   FETCH NEXT FROM C_ArchivePODetail INTO @cPOLineNumber 
   			   
   			   WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
   			   BEGIN
                  BEGIN TRAN 

      				UPDATE PODetail WITH (ROWLOCK) 
      				   Set PODetail.Archivecop = '9' 
      				Where (PODetail.pokey = @cPOKey AND POLineNumber = @cPOLineNumber) 
      				
      				SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      				IF @local_n_err <> 0
      				BEGIN 
      					SELECT @n_continue = 3
      					SELECT @local_n_err = 73703
      					SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
      					SELECT @local_c_errmsg =
      					": Update of Archivecop failed - PODetail. (nspArchivePO) " + " ( " +
      					" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
                     ROLLBACK TRAN
      				END  
                  ELSE
                  BEGIN
                     SET @n_archive_po_detail_records = @n_archive_po_detail_records + 1 
                     COMMIT TRAN 
                  END

      				FETCH NEXT FROM C_ArchivePODetail INTO @cPOLineNumber
      			END -- while
      			CLOSE C_ArchivePODetail
      			DEALLOCATE C_ArchivePODetail
   			END 
   			
   			FETCH NEXT FROM C_Archive_POKey INTO @cPOkey 
			END
			CLOSE C_Archive_POKey
			DEALLOCATE C_Archive_POKey

			IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
			BEGIN
				SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_po_records )) +
				" PO records and " + dbo.fnc_RTrim(convert(char(6),@n_archive_po_detail_records )) + " PODetail records"
				EXECUTE nspLogAlert
				@c_ModuleName   = "nspArchivePO",
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
					print "Building INSERT for PODETAIL..."
				END
				SELECT @b_success = 1
				EXEC nsp_BUILD_INSERT   @c_copyto_db, 'PODetail',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
				IF not @b_success = 1
				BEGIN
					SELECT @n_continue = 3
				END
			END   

			IF @n_continue = 1 or @n_continue = 2
			BEGIN   
				IF (@b_debug = 1)
				BEGIN
					print "Building INSERT for PO..."
				END
				SELECT @b_success = 1
				EXEC nsp_BUILD_INSERT  @c_copyto_db, 'PO',1,@b_success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT

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
		@c_ModuleName   = "nspArchivePO",
		@c_AlertMessage = "Archive Of PO Ended Normally.",
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
			@c_ModuleName   = "nspArchivePO",
			@c_AlertMessage = "Archive Of PO Ended Abnormally - Check This Log For Additional Messages.",
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
	     /* #INCLUDE <SPARPO2.SQL> */     
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, "nspArchivePO"
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