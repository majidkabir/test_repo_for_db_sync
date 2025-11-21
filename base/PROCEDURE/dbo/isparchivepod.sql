SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc : ispArchivePOD                                           */
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
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 2005-Dec-01  Shong     Revise Build Insert SP - Check Duplicate      */
/*                        - Delete only when records inserted into      */
/*                          Archive Table.                              */
/* 27-Oct-2006	 June      SOS60885 - Include Storerkey, Orderkey &      */
/*                        ExternOrderkey archive parameter in           */
/*	                       retrieval criteria (June01).                  */		
/* 03-Sep-2014	 TLTING    Archive ALL data older than 150 days          */	
/* 13-Jan-2016	 TLTING    Add parameter MaxPODRetain                    */				
/************************************************************************/
CREATE PROC    [dbo].[ispArchivePOD]
	@c_archivekey NVARCHAR(10),
	@n_MaxPODRetain INT = 120,
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
		@n_starttcnt int        , -- Holds the current Transaction count
		@n_cnt int              , -- Holds @@ROWCOUNT after certain operations
		@b_debug int              -- Debug On Or Off
   /* #INCLUDE <SPATran1.SQL> */     
   DECLARE @cMBOLKey        NVARCHAR(10), 
           @cMBOLLineNumber NVARCHAR(5) 
   
	DECLARE  @n_retain_days int          , -- days to hold data
		      @d_PODdate     datetime     , -- Tran Date from Tran header table
		      @d_result      datetime     , -- date Tran_date - (getdate() - noofdaystoretain
		      @d_result2      datetime     , -- date Tran_date - (getdate() - noofdaystoretain
		      @c_datetype    NVARCHAR(10)     , -- 1=TranDATE, 2=EditDate, 3=AddDate
		      @n_archive_POD_records   int -- # of POD records to be archived
		      
	DECLARE  @local_n_err       int,
		      @local_c_errmsg    NVARCHAR(254)
	DECLARE  @c_copyfrom_db     NVARCHAR(55),
		      @c_copyto_db       NVARCHAR(55), 
      		@c_PODactive       NVARCHAR(2),
      		@c_whereclause     NVARCHAR(2048), -- June01
      		@c_temp            NVARCHAR(2048), -- June01
      		@CopyRowsToArchiveDatabase NVARCHAR(1),
				@c_shipstorerkeystart NVARCHAR(15), -- June01
				@c_shipstorerkeyend NVARCHAR(15), -- June01
				@c_shipsysordstart NVARCHAR(10), 	-- June01
				@c_shipsysordend NVARCHAR(10), 	-- June01
				@c_shipyourordstart NVARCHAR(30), -- June01
				@c_shipyourordend NVARCHAR(30) 	-- June01
   		
	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		@b_debug = 0 , @local_n_err = 0, @local_c_errmsg = ' '
	
	IF @n_MaxPODRetain IS NULL OR @n_MaxPODRetain <= 0
	   SET @n_MaxPODRetain = 120
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT  @c_copyfrom_db = livedatabasename,
			@c_copyto_db = archivedatabasename,
			@n_retain_days = ShipNumberofDaysToRetain,
			@c_datetype = ShipmentOrderDateType,
			@c_PODactive = ShipActive,
			@CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase,
			-- Start : June01			
         @c_shipstorerkeystart = isnull(shipstorerkeystart,''),
         @c_shipstorerkeyend = isnull(shipstorerkeyend,'ZZZZZZZZZZ'),
         @c_shipsysordstart = isnull(shipsysordstart,''),
         @c_shipsysordend = isnull(shipsysordend,'ZZZZZZZZZZ'),
         @c_shipyourordstart  = isnull(shipexternorderkeystart,''),
         @c_shipyourordend  = isnull(shipexternorderkeyend,'ZZZZZZZZZZ')
			-- End : June01
		FROM ArchiveParameters (nolock)
		WHERE archivekey = @c_archivekey
		SELECT @d_result = dateadd(day,-@n_retain_days,getdate())
		SELECT @d_result = dateadd(day,1,@d_result)
		SELECT @d_result2 = dateadd(day,-@n_MaxPODRetain,getdate())
		SELECT @d_result2 = dateadd(day,1,@d_result2)
		
		IF db_id(@c_copyto_db) is NULL
		BEGIN
			SELECT @n_continue = 3
			SELECT @local_n_err = 73701
			SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
			SELECT @local_c_errmsg =
				": Target Database " + @c_copyto_db + " Does not exist " + " ( " +
				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")" + " (ispArchivePOD)"
		END
	END
	
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT @b_success = 1
		SELECT @c_temp = "Archive Of POD Started with Parms; Datetype = " + dbo.fnc_RTrim(@c_datetype) +
			' ; Active = '+ dbo.fnc_RTrim(@c_PODactive) +
			' ; Copy Rows to Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) + ' ; Retain Days = '+ convert(char(6),@n_retain_days)
		EXECUTE nspLogAlert
			@c_ModuleName   = "ispArchivePOD",
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

	-- Start : June01
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN  
		select @c_WhereClause = ' ' 
      select @c_temp = ' '   
      select @c_temp = 'and POD.storerkey between '+ 'N''' + dbo.fnc_RTrim(@c_shipstorerkeystart) + '''' + ' and '+
         'N''' + dbo.fnc_RTrim(@c_shipstorerkeyend)+ ''''
   
      select @c_temp = @c_temp + ' and POD.orderkey between ' + 'N''' + dbo.fnc_RTrim(@c_shipsysordstart) + '''' + ' and '+
         'N''' + dbo.fnc_RTrim(@c_shipsysordend)+ ''''

      select @c_temp = @c_temp + ' and POD.externorderkey between '+ 'N''' + dbo.fnc_RTrim(@c_shipyourordstart) + '''' +' and '+
         'N'''+dbo.fnc_RTrim(@c_shipyourordend)+''''

      if (@b_debug =1 )
      begin
         print 'subsetting clauses'
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
			'POD',
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
			print 'building alter table string for POD...'
		END
		EXECUTE nspBuildAlterTableString 
			@c_copyto_db,
			'POD',
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
		-- Changed by June 14.Oct.2004 SOS28345
		-- SELECT @c_whereclause = "UPDATE POD SET Archivecop = '9' WHERE POD.editdate  <= " + '"'+ convert(char(11),@d_result,106)+'"' +  " and POD.finalizeflag = '8' "
		SELECT @c_whereclause = " WHERE ( POD.editdate  <= " + '"'+ convert(char(11),@d_result,106)+'"' +  " and POD.finalizeflag = 'Y' " + Char(13) +
		                         RTrim(@c_temp) + ' ) ' + CHAR(13) +
		                         " OR ( POD.editdate  <= " + '"'+ convert(char(11),@d_result2,106)+'" ) ' 
		-- tlting	
		-- Start : June01
	--   SET @c_WhereClause = (dbo.fnc_RTrim(@c_WhereClause) + dbo.fnc_RTrim(@c_temp)) 
		-- End : June01

      if (@b_debug =1 )
      begin
         print 'Full clauses'
         select 'execute clause @c_WhereClause', @c_WhereClause
      END
      
      WHILE @@TranCount > 0			
         COMMIT TRAN 

			SET @n_archive_POD_records = 0 

			SELECT @c_whereclause = 
			  ' DECLARE C_Archive_POD_PK CURSOR FAST_FORWARD READ_ONLY FOR ' + 
			  ' SELECT MBOLkey, MBOLLineNumber FROM POD (NOLOCK) ' + 
			  dbo.fnc_RTrim( @c_whereclause ) 
			
			EXECUTE (@c_whereclause)
			  
			OPEN C_Archive_POD_PK
			
			FETCH NEXT FROM C_Archive_POD_PK INTO @cMBOLKey, @cMBOLLineNumber  
			WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
			BEGIN
            BEGIN TRAN 

			   UPDATE POD WITH (ROWLOCK)
			      SET ArchiveCop = '9' 
			   WHERE MBOLKEY = @cMBOLkey 
			   AND   MBOLLineNumber = @cMBOLLineNumber 
			   
			   SELECT @local_n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   			IF @local_n_err <> 0
   			BEGIN 
   				SELECT @n_continue = 3
   				SELECT @local_n_err = 73702
   				SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
   				SELECT @local_c_errmsg =
   				": Update of Archivecop failed - POD. (nspArchivePO) " + " ( " +
   				" SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ")"
               ROLLBACK TRAN 
   			END  
   		   ELSE
   		   BEGIN
   			   SELECT @n_archive_POD_records = @n_archive_POD_records + 1 
               COMMIT TRAN 
   			END
   		   FETCH NEXT FROM C_Archive_POD_PK INTO @cMBOLKey, @cMBOLLineNumber  
			END
		   CLOSE C_Archive_POD_PK
			DEALLOCATE C_Archive_POD_PK
	END 
	
	IF ((@n_continue = 1 or @n_continue = 2)  and @CopyRowsToArchiveDatabase = 'Y')
	BEGIN
		SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTrim(convert(char(6),@n_archive_POD_records )) + " POD records"
		EXECUTE nspLogAlert
			@c_ModuleName   = "ispArchivePOD",
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
			'POD',
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
			@c_ModuleName   = "ispArchivePOD",
			@c_AlertMessage = "Archive Of POD Ended Normally.",
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
				@c_ModuleName   = "ispArchivePOD",
				@c_AlertMessage = "Archive Of POD Ended Abnormally - Check This Log For Additional Messages.",
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


	WHILE @@TRANCOUNT < @n_starttcnt
	BEGIN
		BEGIN TRAN
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
	
	EXECUTE nsp_logerror @n_err, @c_errmsg, "ispArchivePOD"
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