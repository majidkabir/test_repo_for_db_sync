SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure ispArchiveDelPickslip : 
--

/************************************************************************/
/* Stored Proc : ispArchiveDelPickslip                              		*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: Housekeeping DEL_PickSlip table                             */
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
/* Called By:                                             					*/
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC  [dbo].[ispArchiveDelPickslip]
					@c_archivekey  NVARCHAR(10)             
,              @b_Success      int        OUTPUT    
,              @n_err          int        OUTPUT    
,              @c_errmsg       NVARCHAR(250)  OUTPUT    
AS
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 

	DECLARE  @n_continue 	int,  
			   @n_starttcnt	int, -- Holds the current transaction count
			   @n_cnt 			int, -- Holds @@ROWCOUNT after certain operations
			   @b_debug 		int -- Debug On OR Off

	/* #INCLUDE <SPACC1.SQL> */     
	DECLARE  @n_retain_days 		int, -- days to hold data
			   @d_result  				datetime, -- date (GETDATE() - noofdaystoretain)
			   @c_datetype 		 NVARCHAR(10), -- 1=EditDate, 2=AddDate
			   @n_archive_records	int, -- No. of records to be archived
				@local_n_err 			int,
		      @local_c_errmsg	 NVARCHAR(254)

	DECLARE  @c_PickslipStart 			 NVARCHAR(10),
			   @c_PickslipEnd 			 NVARCHAR(10),
			   @c_whereclause 			 NVARCHAR(254),
			   @c_temp 						 NVARCHAR(254),
			   @c_CopyRowsToArchiveDatabase NVARCHAR(1),
			   @c_copyfrom_db 			 NVARCHAR(30),
			   @c_copyto_db 				 NVARCHAR(30),
				@c_pickslipno				 NVARCHAR(10)


	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",
		    @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '

   SELECT   @c_copyfrom_db = livedatabasename,
				@c_copyto_db = archivedatabasename,
				@n_retain_days = DelPickSlipNoofDaysToRetain,
				@c_datetype = DelPickSlipDateType,
				@c_PickslipStart= ISNULL (DelPickSlipStart,''),
				@c_PickslipEnd= ISNULL (DelPickSlipEnd,'ZZZZZZZZZZ'),
				@c_CopyRowsToArchiveDatabase = copyrowstoarchivedatabase
   FROM  ArchiveParameters (NOLOCK)
   WHERE Archivekey = @c_archivekey

	IF db_id(@c_copyto_db) IS NULL
	BEGIN
	   SELECT @n_continue = 3
	   SELECT @local_n_err = 77100
	   SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
	   SELECT @local_c_errmsg =
	   ": Target Database " + @c_copyto_db + " Does NOT exist " + " ( " +
	   " SQLSvr MESSAGE = " + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@local_c_errmsg)) + ")" +' (ispArchiveDelPickslip) '
	END

	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
	   DECLARE @d_today datetime
	   SELECT @d_today = CONVERT(datetime,CONVERT(char(11),GETDATE(),106))
	   SELECT @d_result = DATEADD(DAY,(-@n_retain_days),@d_today)
	   SELECT @d_result = DATEADD(DAY,1,@d_result)
	END

	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
	   SELECT @b_success = 1
	   SELECT @c_temp = "Archive Of IDS DEL_PickSlip Started with Parms; Datetype = " + dbo.fnc_RTRIM(@c_datetype) +
	   ' ; PickSlipNo = '+dbo.fnc_RTRIM(@c_PickslipStart)+'-'+dbo.fnc_RTRIM(@c_PickslipEnd)+
	   ' ; Copy Rows to Archive = '+dbo.fnc_RTRIM(@c_CopyRowsToArchiveDatabase)+ ' ; Retain Days = '+ CONVERT(char(6),@n_retain_days)
	   EXECUTE nspLogAlert
	   @c_ModuleName   = "ispArchiveDelPickslip",
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

	IF  (@n_continue = 1 OR @n_continue = 2)
	BEGIN
		SET @c_temp = ''

	   IF (dbo.fnc_RTRIM(@c_PickslipStart) IS NOT NULL and dbo.fnc_RTRIM(@c_PickslipEnd) IS NOT NULL)
	   BEGIN
	      SELECT @c_temp =  ' AND PickSlipNo BETWEEN '+ 'N''' + dbo.fnc_RTRIM(@c_PickslipStart) + '''' +' AND '+
	            'N'''+dbo.fnc_RTRIM(@c_PickslipEnd)+''''
	   END

	   IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
	   BEGIN 
	      SELECT @b_success = 1
	      EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db, @c_copyto_db, 'DEL_PickSlip',@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
	      IF NOT @b_success = 1
      	BEGIN
      		SELECT @n_continue = 3
      	END
		END   

		IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
		BEGIN
		   EXECUTE nspBuildAlterTableString @c_copyto_db,'DEL_PickSlip',@b_success OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
		   IF NOT @b_success = 1
	   	BEGIN
	   		SELECT @n_continue = 3
	   	END
		END

	   IF ((@n_continue = 1 OR @n_continue = 2 ) AND @c_CopyRowsToArchiveDatabase = 'Y')
	   BEGIN
	      BEGIN TRAN
	      IF (@n_continue = 1 OR @n_continue = 2 )
	      BEGIN
		      IF @c_datetype = "1" -- EditDate
		      BEGIN
		         SELECT @c_whereclause = "WHERE EditDate  <= " + 'N'+ CONVERT(char(20),@d_result,106)+'"'
		                                 +  @c_temp
		      END
		      IF @c_datetype = "2" -- AddDate
		      BEGIN
		         SELECT @c_whereclause = "WHERE AddDate  <= " + 'N'+ CONVERT(char(20),@d_result,106) +'"' 
		                                 +  @c_temp
		      END

            SELECT @n_archive_records = 0

	         EXEC (
	         ' DECLARE CUR_Pickslip CURSOR FAST_FORWARD READ_ONLY FOR ' + 
	         ' SELECT PickslipNo FROM DEL_PickSlip (NOLOCK) ' + @c_whereclause + 
	         ' ORDER BY PickslipNo ' ) 

				IF @b_debug = 1 
				BEGIN
					PRINT ' SELECT PickslipNo FROM DEL_PickSlip (NOLOCK) ' + @c_whereclause + ' ORDER BY PickslipNo ' 
				END
	         
	         OPEN CUR_Pickslip 
	         
	         FETCH NEXT FROM CUR_Pickslip INTO @c_PickslipNo
	         
	         WHILE @@fetch_status <> -1
	         BEGIN
	            UPDATE DEL_PickSlip WITH (ROWLOCK)
	               SET ArchiveCop = '9' 
	            WHERE PickslipNo = @c_PickslipNo  
	
	      		SELECT @local_n_err = @@error, @n_cnt = @@rowcount            
	            SELECT @n_archive_records = @n_archive_records + 1                                  
	            
	            IF @local_n_err <> 0
	         	BEGIN 
	               SELECT @n_continue = 3
	               SELECT @local_n_err = 77101
	               SELECT @local_c_errmsg = CONVERT(char(5),@local_n_err)
	               SELECT @local_c_errmsg =
	               ": Update of Archivecop failed - CC Table. (ispArchiveDelPickslip) " + " ( " +
	               " SQLSvr MESSAGE = " + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@local_c_errmsg)) + ")"
					END

					FETCH NEXT FROM CUR_Pickslip INTO @c_PickslipNo
				END -- while 

	         CLOSE CUR_Pickslip
	         DEALLOCATE CUR_Pickslip
				/* END (SOS38267) UPDATE*/
      	END 

		   IF ((@n_continue = 1 OR @n_continue = 2) AND @c_CopyRowsToArchiveDatabase = 'Y')
		   BEGIN
		      SELECT @c_temp = "Attempting to Archive " + dbo.fnc_RTRIM(CONVERT(char(6),@n_archive_records )) +
		      " DEL_PickSlip records and " + dbo.fnc_RTRIM(CONVERT(char(6),@n_archive_records )) + " DEL_PickSlip records"
		      EXECUTE nspLogAlert
		      @c_ModuleName   = "ispArchiveDelPickslip",
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

			IF (@n_continue = 1 OR @n_continue = 2)
			BEGIN 
			   SELECT @b_success = 1
			   EXEC nsp_BUILD_INSERT   @c_copyto_db, 'DEL_PickSlip',1 ,@b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
			   IF NOT @b_success = 1
			   BEGIN
			      SELECT @n_continue = 3
			   END
			END   
		END
	END

	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
		SELECT @b_success = 1
		EXECUTE nspLogAlert
		@c_ModuleName   = "ispArchiveDelPickslip",
		@c_AlertMessage = "Archive Of DEL_PickSlip Ended Normally.",
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
			@c_ModuleName   = "ispArchiveDelPickslip",
			@c_AlertMessage = "Archive Of DEL_PickSlip Ended Abnormally - Check This Log For Additional Messages.",
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, "ispArchiveDelPickslip"
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