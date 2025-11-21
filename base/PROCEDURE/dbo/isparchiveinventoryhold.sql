SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : ispArchiveInventoryHold                                */
/* Creation Date: 28.01.2008                                            */
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
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/
CREATE PROC    [dbo].[ispArchiveInventoryHold]
	@c_archivekey NVARCHAR(10),
	@b_Success      int        OUTPUT,    
	@n_err          int        OUTPUT,    
	@c_errmsg       NVARCHAR(250)  OUTPUT    
AS
BEGIN  
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE        @n_continue int        ,  
		@n_starttcnt int        , -- Holds the current Transaction count
		@n_cnt int              , -- Holds @@ROWCOUNT after certain operations
		@b_debug int              -- Debug On Or Off

   /* #INCLUDE <SPATran1.SQL> */     
   DECLARE  @cInventoryHoldKey        NVARCHAR(10),    
				@n_retain_days int          , -- days to hold data
		      @d_result      datetime     , -- date Tran_date - (getdate() - noofdaystoretain
		      @c_datetype    NVARCHAR(10)     , -- 1=DateOn, 2=DateOff
		      @n_archive_InvHold_records   int -- # of InvHold records to be archived
		      
	DECLARE  @local_n_err       int,
		      @local_c_errmsg    NVARCHAR(254)
	DECLARE  @c_copyfrom_db     NVARCHAR(55),
		      @c_copyto_db       NVARCHAR(55), 
      		@c_InvHoldactive       NVARCHAR(2),
      		@c_whereclause     NVARCHAR(2048), 
      		@c_temp            NVARCHAR(2048), 
      		@CopyRowsToArchiveDatabase NVARCHAR(1),
				@c_InvHoldStart NVARCHAR(10), 	
				@c_InvHoldEnd NVARCHAR(10)
   		
	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		    @b_debug = 0 , @local_n_err = 0, @local_c_errmsg = ' '	
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
			@n_retain_days = InvHoldNumberofDaysToRetain,
			@c_datetype = InvHoldDateType,
			@c_InvHoldactive = InvHoldActive,
			@CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase,
         @c_InvHoldStart = isnull(InvHoldStart,''),
         @c_InvHoldEnd = isnull(InvHoldEnd,'ZZZZZZZZZZ')
		FROM  ArchiveParameters (nolock)
		WHERE archivekey = @c_archivekey

		SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
		SELECT @d_result = dateadd(day,1,@d_result)

		IF db_id(@c_copyto_db) is NULL
		BEGIN
			SELECT @n_continue = 3
			SELECT @local_n_err = 73701
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
				": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + " (ispArchiveInventoryHold)"
		END
	END
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		SELECT @c_temp = "Archive Of InventoryHold Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
			' ; Active = '+ dbo.fnc_RTrim(@c_InvHoldactive) +
			' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) + ' ; Retain Days = '+ convert(char(6),@n_retain_days)
		EXECUTE nspLogAlert
			@c_ModuleName   = "ispArchiveInventoryHold",
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

   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN  
		select @c_WhereClause = ' ' 
      select @c_temp = ' '   
      select @c_temp = @c_temp + ' and InventoryHold.InventoryHoldKey between ' + '''' + dbo.fnc_RTrim(@c_InvHoldStart) + '''' + ' and '+
         '''' + dbo.fnc_RTrim(@c_InvHoldEnd)+ ''' '

		IF @c_datetype = "1" -- DateOn
		BEGIN
         SELECT @c_whereclause = " WHERE InventoryHold.DateOn <= " + '"'+ convert(char(11),@d_result,106)+'"' 
            + " and (InventoryHold.Hold = '0') " + dbo.fnc_RTrim(@c_temp)
		END
		IF @c_datetype = "2" -- DateOff
		BEGIN
         SELECT @c_whereclause = " WHERE InventoryHold.DateOff <= " +'"'+ convert(char(11),@d_result,106)+'"' 
            + " and (InventoryHold.Hold = '0') " + dbo.fnc_RTrim(@c_temp)
		END

      if (@b_debug =1 )
      begin
         print 'subsetting clauses'
         select 'execute clause @c_WhereClause', @c_WhereClause
         select 'execute clause @c_temp ', @c_temp
      end
	END   
	-- End : June01
	
	IF ((@n_continue = 1 or @n_continue = 2) and @CopyRowsToArchiveDatabase = 'Y')
	BEGIN 
		select @b_success = 1
		EXEC nsp_BUILD_ARCHIVE_TABLE 
			@c_copyfrom_db, 
			@c_copyto_db, 
			'InventoryHold',
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
			print 'building alter table string for InventoryHold...'
		END
		EXECUTE nspBuildAlterTableString 
			@c_copyto_db,
			'InventoryHold',
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
         WHILE @@TranCount > @n_starttcnt			
            COMMIT TRAN 

			SET @n_archive_InvHold_records = 0 

			SELECT @c_whereclause = 
			  ' DECLARE C_Archive_InvHold_PK CURSOR FAST_FORWARD READ_ONLY FOR ' + 
			  ' SELECT InventoryHoldkey FROM InventoryHold (NOLOCK) ' + 
			  dbo.fnc_RTrim( @c_whereclause ) 
			
			EXECUTE (@c_whereclause)
			  
			OPEN C_Archive_InvHold_PK
			
			FETCH NEXT FROM C_Archive_InvHold_PK INTO @cInventoryHoldkey
			WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
			BEGIN
            BEGIN TRAN 

			   UPDATE InventoryHold WITH (ROWLOCK)
			      SET ArchiveCop = '9' 
			   WHERE InventoryHoldKey = @cInventoryHoldkey
			   
			   SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   			IF @local_n_err <> 0
   			BEGIN 
   				SELECT @n_continue = 3
   				SELECT @local_n_err = 73702
   				SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
   				SELECT @local_c_errmsg =
   				": Update of Archivecop failed - InventoryHold. (nspArchivePO) " + " ( " +
   				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               ROLLBACK TRAN 
   			END  
   		   ELSE
   		   BEGIN
   			   SELECT @n_archive_InvHold_records = @n_archive_InvHold_records + 1 
               COMMIT TRAN 
   			END
   		   FETCH NEXT FROM C_Archive_InvHold_PK INTO @cInventoryHoldkey
			END
		   CLOSE C_Archive_InvHold_PK
			DEALLOCATE C_Archive_InvHold_PK
	END 
	
	IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
	BEGIN
		SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_InvHold_records )) + " InventoryHold records"
		EXECUTE nspLogAlert
			@c_ModuleName   = "ispArchiveInventoryHold",
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
		EXEC nsp_BUILD_INSERT  
			@c_copyto_db, 
			'InventoryHold',
			1,
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
		SELECT @b_success = 1
		EXECUTE nspLogAlert
			@c_ModuleName   = "ispArchiveInventoryHold",
			@c_AlertMessage = "Archive Of InventoryHold Ended Normally.",
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
				@c_ModuleName   = "ispArchiveInventoryHold",
				@c_AlertMessage = "Archive Of InventoryHold Ended Abnormally - Check This Log For Additional Messages.",
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
	   
		/* #INCLUDE <SPATran2.SQL> */     
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
	
	EXECUTE nsp_logerror @n_err, @c_errmsg, "ispArchiveInventoryHold"
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